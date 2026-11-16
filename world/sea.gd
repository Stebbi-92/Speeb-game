class_name WSea
extends Node3D
## The Grey Sea about the waste: its water and waves, the sound of it, and what stands on its isles.
## The waves are the same sum of swells on every machine, so a boat rides the water others see.

const SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx;
uniform float t = 0.0;
uniform float swell = 0.4;
uniform vec2 wind = vec2(1.0, 0.0);
uniform float inland = 1760.0;
uniform vec3 deep : source_color = vec3(0.12, 0.16, 0.19);
uniform vec3 shallow : source_color = vec3(0.26, 0.31, 0.32);
uniform vec3 foam : source_color = vec3(0.75, 0.76, 0.74);
uniform float night = 0.0;
varying vec3 wp;
varying float crest;

float wave(vec2 p) {
	vec2 d1 = normalize(wind);
	vec2 d2 = vec2(d1.x * 0.8 - d1.y * 0.6, d1.x * 0.6 + d1.y * 0.8);
	vec2 d3 = vec2(d1.x * 0.6 + d1.y * 0.8, -d1.x * 0.8 + d1.y * 0.6);
	return swell * (0.6 * sin(dot(p, d1) * 0.09 + t * 1.1) + 0.3 * sin(dot(p, d2) * 0.17 + t * 1.7) + 0.15 * sin(dot(p, d3) * 0.31 + t * 2.3));
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = wave(w.xz);
	float hx = wave(w.xz + vec2(1.0, 0.0));
	float hz = wave(w.xz + vec2(0.0, 1.0));
	VERTEX.y += h;
	NORMAL = normalize(vec3(h - hx, 1.0, h - hz));
	wp = w + vec3(0.0, h, 0.0);
	crest = h / max(swell, 0.05);
}

void fragment() {
	if (max(abs(wp.x), abs(wp.z)) < inland) {
		discard;
	}
	vec3 c = mix(shallow, deep, clamp(1.0 - NORMAL.y * 0.9 + 0.3, 0.0, 1.0));
	c = mix(c, foam, smoothstep(0.75, 1.0, crest) * 0.45 * clamp(swell, 0.0, 1.5));
	ALBEDO = c * mix(1.0, 0.25, night);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	ALPHA = 0.9;
}
"""

var w   ## the wasteland
var water: MeshInstance3D
var _mat: ShaderMaterial
var t := 0.0
var swell := 0.4          ## how high the waves run: 0.3 calm, 1.6 in a storm
var wind_ang := 0.0       ## where the wind blows toward, in radians on the ground
var wind := 0.5           ## how hard, 0 to 1
var _sea_snd: AudioStreamPlayer
var _surf_snd: AudioStreamPlayer
var vents: Array = []     ## Hrafnsey's smoking ground: [position, seconds to the next burst]
var springs: Array = []   ## its hot springs: positions
var _vent_fx: Array = []


func setup(world) -> WSea:
	w = world
	return self


func _ready() -> void:
	water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	pm.subdivide_width = 240
	pm.subdivide_depth = 240
	water.mesh = pm
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("inland", WIsles.INLAND)
	water.material_override = _mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position.y = WIsles.SEA_Y
	add_child(water)
	if not Net.dedicated:
		_sea_snd = w.ambient("amb_sea", -60)
		_surf_snd = w.ambient("amb_surf", -60)


## The height of the waves at a point, as the shader draws them.
func wave(x: float, z: float) -> float:
	var d1 := Vector2(cos(wind_ang), sin(wind_ang))
	var d2 := Vector2(d1.x * 0.8 - d1.y * 0.6, d1.x * 0.6 + d1.y * 0.8)
	var d3 := Vector2(d1.x * 0.6 + d1.y * 0.8, -d1.x * 0.8 + d1.y * 0.6)
	var p := Vector2(x, z)
	return swell * (0.6 * sin(p.dot(d1) * 0.09 + t * 1.1) + 0.3 * sin(p.dot(d2) * 0.17 + t * 1.7) + 0.15 * sin(p.dot(d3) * 0.31 + t * 2.3))


func surface(x: float, z: float) -> float:
	return WIsles.SEA_Y + wave(x, z)


## How far a point is from dry land, looking outward in rings (up to reach).
func open_water(p: Vector3, reach := 300.0) -> float:
	var tr: WTerrain = w.terrain
	for ring in range(1, 7):
		var r := reach * ring / 6.0
		for k in 12:
			var a := TAU * k / 12.0
			if not tr.is_water(p.x + cos(a) * r, p.z + sin(a) * r, -0.5):
				return r
	return reach


func _process(delta: float) -> void:
	t += delta
	var pl = w.player
	if pl == null:
		return
	var at: Vector3 = pl.global_position
	water.global_position = Vector3(snappedf(at.x, 16.0), WIsles.SEA_Y, snappedf(at.z, 16.0))
	# The sea is only drawn near it: inland, far from any shore, it is hidden
	water.visible = maxf(absf(at.x), absf(at.z)) > WIsles.INLAND - 1500.0
	_mat.set_shader_parameter("t", t)
	_mat.set_shader_parameter("swell", swell)
	_mat.set_shader_parameter("wind", Vector2(cos(wind_ang), sin(wind_ang)))
	_mat.set_shader_parameter("night", clampf(1.0 - w.sun.light_energy / 1.2, 0.0, 0.85) if w.sun else 0.0)
	if _sea_snd:
		# The sea is heard from the shore; the surf where the waves break on it
		var near := 0.0
		var tr: WTerrain = w.terrain
		if maxf(absf(at.x), absf(at.z)) > WIsles.INLAND - 120.0:
			for k in 8:
				var a := TAU * k / 8.0
				for r in [0.0, 30.0, 70.0]:
					if tr.is_water(at.x + cos(a) * r, at.z + sin(a) * r, 0.5):
						near = maxf(near, 1.0 - r / 90.0)
		var on := near > 0.0
		_sea_snd.volume_db = move_toward(_sea_snd.volume_db, lerpf(-30.0, -8.0, near) if on else -60.0, delta * 20.0)
		var shore := on and not tr.is_water(at.x, at.z, 2.0)
		_surf_snd.volume_db = move_toward(_surf_snd.volume_db, lerpf(-22.0, -6.0, swell / 1.6) if shore else -60.0, delta * 20.0)
	_vents_tick(delta)


# ------------------------------------------------------------------ the isles' own things

## Builds what stands on each isle: domes and towers on Kalaja, smoking ground and springs on
## Hrafnsey, pipes, wheels and chimneys on Cogwright, drowned trees on the Fen.
func build_isles() -> void:
	for il in w.terrain.isles:
		var rr := RandomNumberGenerator.new()
		rr.seed = w.world_seed + hash(il.key)
		match str(il.key):
			"hrafn":
				for k in 6:
					var p := _isle_spot(il, rr, 0.7)
					if p != Vector3.INF:
						_vent(p)
				for k in 3:
					var p := _isle_spot(il, rr, 0.6)
					if p != Vector3.INF:
						_spring(p)
				for k in 12:
					var p := _isle_spot(il, rr, 0.8)
					if p != Vector3.INF:
						var hgt := rr.randf_range(3.0, 9.0)
						_put(w.cyl(Vector3.ZERO, rr.randf_range(0.6, 1.2), hgt, w._m.darkstone, true, rr.randf_range(0.3, 0.7), 6), p + Vector3(0, hgt * 0.5 - 0.5, 0))
			"fen":
				for k in 60:
					var p := _isle_spot(il, rr, 0.9, true)
					if p != Vector3.INF:
						_drowned_tree(p, rr)
			"kala":
				for k in 9:
					var p := _isle_spot(il, rr, 0.8)
					if p != Vector3.INF:
						_dome(p, rr)
				for k in 26:
					var p := _isle_spot(il, rr, 0.85)
					if p != Vector3.INF:
						_olive(p, rr)
				var heart: Vector2 = w.terrain.isle_heart(il)
				for k in 4:
					var a := TAU * k / 4.0 + 0.5
					var q := heart + Vector2(cos(a), sin(a)) * rr.randf_range(30.0, 44.0)
					_tower_house(w.gpos(q), rr)
			"cog":
				for k in 10:
					var p := _isle_spot(il, rr, 0.75)
					if p != Vector3.INF:
						_chimney(p, rr)
				for k in 8:
					var p := _isle_spot(il, rr, 0.75)
					if p != Vector3.INF:
						_wheel(p, rr)
				for k in 7:
					var p := _isle_spot(il, rr, 0.7)
					var q := _isle_spot(il, rr, 0.7)
					if p != Vector3.INF and q != Vector3.INF and p.distance_to(q) < 90.0:
						_pipe(p, q)


## A dry spot on an isle, within frac of its reach and away from its heart; INF if none was found.
func _isle_spot(il: Dictionary, rr: RandomNumberGenerator, frac: float, wet_ok := false) -> Vector3:
	var tr: WTerrain = w.terrain
	var heart: Vector2 = tr.isle_heart(il)
	for tries in 20:
		var a := rr.randf() * TAU
		var d := sqrt(rr.randf()) * float(il.r) * frac
		var q: Vector2 = il.c + Vector2(cos(a), sin(a)) * d
		if q.distance_to(heart) < 40.0:
			continue
		var y := tr.height_at(q.x, q.y)
		if y < WIsles.SEA_Y + (-0.6 if wet_ok else 0.8):
			continue
		if tr.normal_at(q.x, q.y).y < 0.75:
			continue
		return Vector3(q.x, y, q.y)
	return Vector3.INF


func _put(n: Node3D, at: Vector3) -> Node3D:
	if n.get_parent():
		n.reparent(self, false)
	else:
		add_child(n)
	n.global_position = at
	if n is GeometryInstance3D:
		n.visibility_range_end = 700.0
	return n


## Hangs a piece made by the land's helpers (which keep it at first) under another.
func _kid(parent: Node3D, n: Node3D) -> Node3D:
	if n.get_parent():
		n.reparent(parent, false)
	else:
		parent.add_child(n)
	return n


func _vent(p: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	var ring = w.cyl(Vector3.ZERO, 1.3, 0.4, w._m.darkstone, false, 1.6, 10)
	ring.reparent(n, false)
	ring.position.y = 0.1
	var fx := _steam(1.0)
	n.add_child(fx)
	vents.append([p, randf_range(4.0, 12.0)])
	_vent_fx.append(fx)


func _steam(amount: float) -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.amount = int(24 * amount)
	ps.lifetime = 3.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, 0.4, 0)
	pm.scale_min = 1.5
	pm.scale_max = 3.0
	pm.color = Color(0.9, 0.9, 0.9, 0.35)
	ps.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = LesserSpeeb.smoke_tex()
	m.vertex_color_use_as_albedo = true
	q.material = m
	ps.draw_pass_1 = q
	ps.visibility_range_end = 400.0
	return ps


func _spring(p: Vector3) -> void:
	var pool := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.0
	cm.bottom_radius = 4.0
	cm.height = 0.1
	pool.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.72, 0.75, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.emission_enabled = true
	m.emission = Color(0.2, 0.4, 0.42)
	pool.material_override = m
	_put(pool, p + Vector3(0, 0.12, 0))
	var fx := _steam(0.6)
	add_child(fx)
	fx.global_position = p
	springs.append(p)


## Smoking ground bursts now and then; one standing on it is scalded and thrown. A hot spring heals.
func _vents_tick(delta: float) -> void:
	var pl = w.player
	for i in vents.size():
		var v: Array = vents[i]
		v[1] -= delta
		if v[1] <= 0.0:
			v[1] = randf_range(8.0, 16.0)
			var p: Vector3 = v[0]
			var fx: GPUParticles3D = _vent_fx[i]
			fx.amount_ratio = 1.0
			fx.speed_scale = 3.0
			get_tree().create_timer(1.6, false).timeout.connect(func(): if is_instance_valid(fx): fx.speed_scale = 1.0)
			if pl.global_position.distance_to(p) < 60.0:
				w.sfx("hiss", -4, p, 0.6)
			if pl.global_position.distance_to(p) < 2.6 and not w.downed:
				w.damage_player(18.0, p - Vector3(0, 1, 0))
				pl.velocity.y = 9.0
				w.hud.notify("The ground bursts and scalds you.")
	for s in springs:
		if pl.global_position.distance_to(s) < 4.0 and pl.health < pl.max_health and not w.downed:
			pl.health = minf(pl.max_health, pl.health + 4.0 * delta)
			w.hud.set_health(pl.health / pl.max_health, false)


func _drowned_tree(p: Vector3, rr: RandomNumberGenerator) -> void:
	var hgt := rr.randf_range(5.0, 11.0)
	var trunk = w.cyl(Vector3.ZERO, rr.randf_range(0.2, 0.35), hgt, w._m.darkwood, true, 0.12, 6)
	_put(trunk, p + Vector3(0, hgt * 0.5 - 0.6, 0))
	trunk.rotation = Vector3(rr.randf_range(-0.12, 0.12), rr.randf() * TAU, rr.randf_range(-0.12, 0.12))
	for k in rr.randi_range(1, 3):
		var b = w.cyl(Vector3.ZERO, 0.08, rr.randf_range(1.5, 3.0), w._m.darkwood, false, 0.03, 5)
		_kid(trunk, b)
		b.position = Vector3(0, rr.randf_range(0.0, hgt * 0.4), 0)
		b.rotation = Vector3(rr.randf_range(0.6, 1.2), rr.randf() * TAU, 0)


## Kalaja's grey domes: a squat shell of poured stone with a slit to look out of.
func _dome(p: Vector3, rr: RandomNumberGenerator) -> void:
	var concrete = w.mat(Color(0.56, 0.55, 0.52), 0.95, 0.35, 0.4)
	var d = w.sphere(Vector3.ZERO, rr.randf_range(2.6, 3.6), concrete, true, 0.55)
	_put(d, p + Vector3(0, -0.2, 0))
	var slit = w.box(Vector3.ZERO, Vector3(1.6, 0.18, 0.3), w._m.cold, false)
	_kid(d, slit)
	slit.position = Vector3(0, 0.9, 2.7)


func _olive(p: Vector3, rr: RandomNumberGenerator) -> void:
	var trunk = w.cyl(Vector3.ZERO, 0.22, 2.0, w._m.darkwood, true, 0.14, 6)
	_put(trunk, p + Vector3(0, 0.9, 0))
	trunk.rotation = Vector3(rr.randf_range(-0.25, 0.25), 0, rr.randf_range(-0.25, 0.25))
	var leaves = w.mat(Color(0.38, 0.42, 0.28), 1.0, 0.3, 0.8)
	for k in 3:
		var c = w.sphere(Vector3.ZERO, rr.randf_range(1.0, 1.5), leaves, false, 0.6)
		_kid(trunk, c)
		c.position = Vector3(rr.randf_range(-0.8, 0.8), 1.3 + rr.randf_range(0.0, 0.5), rr.randf_range(-0.8, 0.8))


## A stone tower-house of the old hill clans: tall, narrow windows, a stone roof.
func _tower_house(p: Vector3, rr: RandomNumberGenerator) -> void:
	var stone = w.mat(Color(0.66, 0.63, 0.57), 0.95, 0.4, 0.35)
	var hgt := rr.randf_range(8.0, 12.0)
	var b = w.box(Vector3.ZERO, Vector3(6, hgt, 6), stone)
	_put(b, p + Vector3(0, hgt * 0.5 - 0.3, 0))
	b.rotation.y = rr.randf() * TAU
	for fl in int(hgt / 3.0):
		for side in 4:
			var win = w.box(Vector3.ZERO, Vector3(0.5, 1.0, 0.1), w._m.cold, false)
			_kid(b, win)
			var a := side * PI * 0.5
			win.position = Vector3(sin(a) * 3.02, -hgt * 0.5 + 2.2 + fl * 3.0, cos(a) * 3.02)
			win.rotation.y = a
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(6.6, 2.0, 6.6)
	roof.mesh = pm
	roof.material_override = w._m.darkstone
	b.add_child(roof)
	roof.position.y = hgt * 0.5 + 1.0


func _chimney(p: Vector3, rr: RandomNumberGenerator) -> void:
	var hgt := rr.randf_range(10.0, 18.0)
	var c = w.cyl(Vector3.ZERO, 1.1, hgt, w._m.rust, true, 0.8, 10)
	_put(c, p + Vector3(0, hgt * 0.5 - 0.3, 0))
	var brass = w.mat(Color(0.6, 0.45, 0.2), 0.4, 0.2, 0.5, 0.8)
	for k in 3:
		var band = w.cyl(Vector3.ZERO, 1.2, 0.3, brass, false, -1.0, 10)
		_kid(c, band)
		band.position.y = -hgt * 0.5 + 2.0 + k * hgt * 0.3
	if rr.randf() < 0.6:
		w._smoke(p + Vector3(0, hgt, 0))


## A great iron wheel, half sunk, that still turns.
func _wheel(p: Vector3, rr: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = p + Vector3(0, rr.randf_range(1.5, 3.0), 0)
	holder.rotation.y = rr.randf() * TAU
	var wheel := Node3D.new()
	holder.add_child(wheel)
	var r := rr.randf_range(2.5, 4.5)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.35
	tm.outer_radius = r
	rim.mesh = tm
	rim.material_override = w._m.iron
	rim.rotation.x = PI * 0.5
	wheel.add_child(rim)
	for k in 6:
		var sp = w.box(Vector3.ZERO, Vector3(0.25, r * 2.0, 0.25), w._m.rust, false)
		_kid(wheel, sp)
		sp.rotation.z = k * PI / 6.0
	var tw := wheel.create_tween().set_loops()
	tw.tween_property(wheel, "rotation:z", TAU, rr.randf_range(12.0, 30.0)).from(0.0)


func _pipe(a: Vector3, b: Vector3) -> void:
	var up := Vector3(0, 2.5, 0)
	var from := a + up
	var to := b + up
	var len := from.distance_to(to)
	var mid := (from + to) * 0.5
	var pipe = w.cyl(Vector3.ZERO, 0.45, len, w._m.rust, false, -1.0, 8)
	_put(pipe, mid)
	pipe.look_at(to, Vector3.UP)
	pipe.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	for q in [a, b]:
		_put(w.cyl(Vector3.ZERO, 0.3, 3.0, w._m.iron, true, -1.0, 6), q + Vector3(0, 1.0, 0))
