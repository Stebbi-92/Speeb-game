class_name FirePool
extends Node3D
## Burning ground: what a fire bottle leaves where it breaks (and a flamer's tongue where it falls).
## A splash of burning drops at the burst, then a pool of fire laid on the ground itself out to the
## edge of the harm, with tall tongues, dark smoke, embers, a flickering light and a shimmer in the
## air. As it dies the tongues sink and a charred patch is left a while. Forms that stand in it burn.
## Only for the eye: the harm is dealt by Arms.Thrown.burn, which makes this.

const MAX_POOLS := 8        ## past this many at once, a new fire is drawn thinner
const MAX_SCORCH := 10      ## charred patches left at once: the oldest fades first
const CHAR_HOLD := 22.0     ## how long a charred patch stays after the fire, in seconds
const GLOW := Color(1.0, 0.5, 0.18)

static var live := 0        ## fires burning now (for the tests and the caps)
static var made := 0        ## fires made in all (for the tests)
static var _scorches: Array = []
static var _claims: Array = []
static var _tongue_m: ShaderMaterial
static var _haze_shader: Shader
static var _wisp_m: StandardMaterial3D
static var _spark_m: StandardMaterial3D
static var _smoke_m: StandardMaterial3D
static var _char_tex: Texture2D
static var _glow_tex: Texture2D
static var _scorch_next := 0   ## when one's own pilgrim may next be scorched (msec)
static var scorched := 0       ## times one's own pilgrim was scorched (for the tests)

var radius := 5.0
var secs := 7.0
var age := 0.0
var feet: Array = []        ## where the tongues stand, in this node's space (for the tests)
var _tongues: MultiMeshInstance3D
var _light: OmniLight3D
var _light_base := 3.0
var _decal: Decal
var _burning: Array = []    ## particles that go on while the fire does
var _haze: MeshInstance3D
var _snd: AudioStreamPlayer3D
var _snd_db := -14.0
var _drops: Array = []      ## burning drops in flight: [node, from, vel, time to land]
var _hold := CHAR_HOLD
var _out := false


## Lays a fire about `at` (the middle of the harm), out to `radius`, burning `secs`. `splash` is the
## burst of a breaking bottle. Returns null where nothing is drawn (a server with no screen).
static func make(lvl: Node, at: Vector3, r: float, s: float, splash := true, loud := true) -> FirePool:
	if Net.dedicated or lvl == null or not lvl.is_inside_tree():
		return null
	var f := FirePool.new()
	f.radius = r
	f.secs = s
	lvl.add_child(f)
	f.global_position = at
	f._build(splash, loud)
	return f


## Where fire dropped at `p` comes to rest: on the ground below (a little above it), or `p` itself
## with no ground near.
static func settle(lvl: Node, p: Vector3) -> Vector3:
	if lvl == null or not lvl.is_inside_tree():
		return p
	var g := ground(lvl.get_world_3d().direct_space_state, p + Vector3.UP * 0.3, p + Vector3.DOWN * 8.0)
	return p if g.is_empty() else (g[0] as Vector3) + Vector3.UP * 0.25


## The first solid ground along a line from `a` down to `b`: [point, normal], or [] for none.
## Forms (pilgrims, foes) are passed through.
static func ground(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Array:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	for k in 3:
		var r := space.intersect_ray(q)
		if r.is_empty():
			return []
		if r.collider is CharacterBody3D or (r.collider is Node and r.collider.has_method("hurt")):
			var ex := q.exclude
			ex.append(r.rid)
			q.exclude = ex
			continue
		return [r.position, r.normal]
	return []


## A fellow's fire bottle broke here, by their own count. Their bottle still flying on this screen gives way.
static func claim(lvl: Node, at: Vector3) -> void:
	var best: Node3D = null
	var bd := 14.0
	for c in lvl.get_children():
		if c is Arms.Thrown and c.shown_only and c.kind == "fire" and not c.is_queued_for_deletion():
			var d: float = (c as Node3D).global_position.distance_to(at)
			if d < bd:
				bd = d
				best = c
	if best:
		best.queue_free()
		return
	_claims.append([at, Time.get_ticks_msec()])


## A fellow's bottle has burst on this screen. If their own word of where it broke has come (or comes
## soon), that fire is the one shown; if not, it burns where it fell here.
static func shown_burst(lvl: Node, at: Vector3) -> void:
	await lvl.get_tree().create_timer(0.6, false).timeout
	if not is_instance_valid(lvl):
		return
	var now := Time.get_ticks_msec()
	for i in range(_claims.size() - 1, -1, -1):
		if now - int(_claims[i][1]) > 4000:
			_claims.remove_at(i)
		elif (_claims[i][0] as Vector3).distance_to(at) < 14.0:
			_claims.remove_at(i)
			return
	Arms.Thrown.burn(lvl, at, 5.0, 0.0, 7.0, false)


## Fire is fire: this machine's own pilgrim, standing in flames whose foot is at `foot`, is scorched
## and set burning a while. `r` is how far the flames reach about (along the ground, or in all ways
## for a pool, as the harm to foes is measured), `tall` how high they stand. Beside a fire is safe.
static func touch(foot: Vector3, r: float, tall: float, ball := false) -> void:
	if Net.dedicated or Game.main == null:
		return
	var lv = Game.main.level
	if lv == null or not is_instance_valid(lv) or not lv.has_method("damage_player"):
		return
	var pl = lv.get("player")
	if pl == null or not is_instance_valid(pl) or not pl.is_inside_tree():
		return
	var d: Vector3 = (pl as Node3D).global_position - foot
	if ball:
		if d.length() >= r:
			return
	elif Vector2(d.x, d.z).length() >= r or d.y < -0.6 or d.y > tall:
		return
	scorch(lv, foot)


## One's own pilgrim is in the fire: a hiss and a blow (at most twice a second), and burning after.
static func scorch(lv: Node, from: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now < _scorch_next:
		return
	_scorch_next = now + 500
	var al = lv.get("alchemy")
	if al and al.has_method("on") and al.on("fireskin"):
		return
	scorched += 1
	var pl: Node3D = lv.player
	lv.sfx("hiss", -6, pl.global_position, 1.35)
	if lv.has_method("afflict"):
		lv.afflict("burn", 1.6)
	lv.damage_player(4.0, from)


## Sets a form burning for `s` seconds (or longer, if it already is): flames on its body.
static func ignite(e: Node3D, s := 1.4) -> void:
	if Net.dedicated or not is_instance_valid(e) or not e.is_inside_tree():
		return
	var old = e.get_meta("ablaze") if e.has_meta("ablaze") else null
	if old and is_instance_valid(old):
		old.left = maxf(old.left, s)
		return
	var a := Ablaze.new()
	a.left = s
	e.add_child(a)
	e.set_meta("ablaze", a)
	a.build(e)


func _build(splash: bool, loud: bool) -> void:
	live += 1
	made += 1
	var space := get_world_3d().direct_space_state
	var cam := get_viewport().get_camera_3d()
	var far: bool = cam != null and cam.global_position.distance_to(global_position) > 70.0
	# Thinner where it cannot be seen well, at low settings, or with many fires already burning
	var thin := 1.0
	if Game.quality <= 0 or far:
		thin = 0.5
	if live > MAX_POOLS:
		thin *= 0.5
	var big := clampf(radius / 5.0, 0.3, 1.0)
	var at := global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(at.x * 4.0), roundi(at.y * 4.0), roundi(at.z * 4.0)))
	# The roof over it, if any: the ground is looked for under it, never on top of it
	var top := 4.5
	var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.UP * 5.0, 1))
	if not up.is_empty():
		top = maxf(0.3, (up.position as Vector3).y - at.y - 0.05)
	# The tongues: in a sunflower's pattern over the whole round of the harm, each on the ground below it.
	# Only ground within reach of the harm (which is measured from the middle) is set alight.
	var n := clampi(roundi(radius * radius * 1.9), 5, 48)
	var ns := Vector3.ZERO
	var lo := 0.0
	var hi := 0.0
	var spin := rng.randf() * TAU
	var data: Array = []
	for i in n:
		var d := radius * 0.95 * sqrt((i + 0.5) / n)
		var ang := i * 2.39996 + spin + rng.randf_range(-0.25, 0.25)
		var off := Vector3(cos(ang), 0.0, sin(ang)) * d
		var from := at + off + Vector3.UP * minf(top, 1.0 + d * 0.8)
		var g := ground(space, from, from + Vector3.DOWN * (minf(top, 1.0 + d * 0.8) + 1.5 + d * 0.9))
		if g.is_empty() or (g[0] as Vector3).distance_to(at) > radius:
			continue
		var p: Vector3 = g[0] - at
		ns += g[1]
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
		var k := d / radius
		data.append({"p": p, "k": k})
	if data.is_empty():
		data.append({"p": Vector3(0, -0.25, 0), "k": 0.0})
	var nrm := ns.normalized() if ns.length() > 0.1 else Vector3.UP
	# Some of the outer patches are lit by drops thrown from the burst; the rest catch as the fire runs out
	var drops: Array = []
	if splash:
		for j in data.size():
			if data[j].k > 0.55 and drops.size() < roundi(7 * maxf(thin, 0.6)) and rng.randf() < 0.45:
				drops.append(j)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.center_offset = Vector3(0, 0.5, 0)
	mm.mesh = q
	mm.instance_count = data.size()
	for j in data.size():
		var dj: Dictionary = data[j]
		var k: float = dj.k
		var h := lerpf(1.9, 0.9, k) * big * rng.randf_range(0.75, 1.25) + 0.25
		var w := h * rng.randf_range(0.75, 1.0)
		var foot: Vector3 = dj.p + Vector3(0, -0.12, 0)
		feet.append(foot)
		mm.set_instance_transform(j, Transform3D(Basis.from_scale(Vector3(w, h, w)), foot))
		var catch := k * radius / 9.0 + rng.randf() * 0.08 if splash else rng.randf() * 0.15
		if j in drops:
			dj["fly"] = rng.randf_range(0.42, 0.62) + k * 0.15
			catch = dj.fly
		# The edge goes out first, the heart last
		var die := k * 0.45 + rng.randf() * 0.35
		mm.set_instance_custom_data(j, Color(rng.randf(), rng.randf(), die, catch / 4.0))
	_tongues = MultiMeshInstance3D.new()
	_tongues.multimesh = mm
	_tongues.material_override = tongue_mat()
	_tongues.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tongues.visibility_range_end = 220.0
	_tongues.set_instance_shader_parameter("age", 0.0)
	_tongues.set_instance_shader_parameter("life", 1.0)
	add_child(_tongues)
	_tongues.custom_aabb = AABB(Vector3(-radius, lo - 0.5, -radius), Vector3(radius * 2.0, hi - lo + 4.0, radius * 2.0))
	var pts := PackedVector3Array()
	for dj in data:
		pts.append(dj.p)
	# Small licks of flame running up off the whole pool
	var wisp := _points(pts, roundi(clampf(radius * radius * 2.4, 6.0, 60.0) * thin), 0.55, _sparks())
	wisp.mesh = _quad(0.3 * big + 0.12)
	wisp.direction = Vector3.UP
	wisp.spread = 12.0
	wisp.initial_velocity_min = 1.2
	wisp.initial_velocity_max = 2.2 * big + 0.6
	wisp.gravity = Vector3(0, 1.2, 0)
	wisp.angle_min = 0.0
	wisp.angle_max = 360.0
	wisp.scale_amount_curve = _curve([0.5, 1.15, 0.2])
	wisp.color_ramp = _ramp([Color(1.0, 0.75, 0.35, 0.8), Color(1.0, 0.42, 0.08, 0.7), Color(0.6, 0.1, 0.02, 0.4), Color(0.15, 0.03, 0.0, 0.0)])
	wisp.visibility_range_end = 120.0
	wisp.emitting = false
	# Embers going up and drifting off
	var em := _points(pts, roundi(clampf(radius * radius * 1.2, 3.0, 30.0) * thin), 2.6, _sparks())
	em.mesh = _quad(0.07)
	em.direction = Vector3.UP
	em.spread = 30.0
	em.initial_velocity_min = 1.5
	em.initial_velocity_max = 4.0 * big + 1.0
	em.gravity = Vector3(0.5, 0.9, 0.25)
	em.damping_min = 0.4
	em.damping_max = 1.2
	em.scale_amount_min = 0.6
	em.scale_amount_max = 1.6
	em.color_ramp = _ramp([Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.45, 0.1, 0.9), Color(0.7, 0.12, 0.02, 0.0)])
	em.visibility_range_end = 70.0
	# Dark smoke rolling up off it
	var sp := PackedVector3Array()
	for p in pts:
		sp.append(p + Vector3.UP * (1.2 * big + 0.3))
	var sm := _points(sp, roundi(clampf(radius * 3.2, 2.0, 16.0) * thin), 4.5, _smoke())
	sm.mesh = _quad(1.6 * big + 0.4)
	sm.direction = Vector3.UP
	sm.spread = 12.0
	sm.initial_velocity_min = 0.8
	sm.initial_velocity_max = 1.7
	sm.gravity = Vector3(0.35, 0.45, 0.12)
	sm.angle_min = 0.0
	sm.angle_max = 360.0
	sm.scale_amount_curve = _curve([0.55, 1.4, 2.4])
	sm.color_ramp = _ramp([Color(0.04, 0.035, 0.03, 0.0), Color(0.04, 0.035, 0.03, 0.7), Color(0.1, 0.095, 0.09, 0.4), Color(0.2, 0.19, 0.18, 0.0)])
	sm.visibility_range_end = 260.0
	_burning = [wisp, em, sm]
	# The light, warm on the ground and on all that stands in it
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.52, 0.2)
	_light_base = 2.2 + 1.6 * big
	_light.light_energy = _light_base
	_light.omni_range = radius * 2.6 + 2.0
	_light.omni_attenuation = 1.4
	_light.light_specular = 0.25
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.9 + 0.5 * big, 0)
	add_child(_light)
	# The ground under it: glowing with burning fuel, then charred
	_decal = Decal.new()
	var ext := maxf(hi - lo, 0.0)
	_decal.size = Vector3(radius * 2.15, ext + 2.6, radius * 2.15)
	_decal.texture_albedo = char_tex()
	_decal.texture_emission = glow_tex()
	_decal.emission_energy = 0.0
	_decal.albedo_mix = 0.0
	_decal.normal_fade = 0.45
	_decal.upper_fade = 0.15
	_decal.lower_fade = 0.15
	_decal.modulate = Color(1, 1, 1, 1)
	_decal.distance_fade_enabled = true
	_decal.distance_fade_begin = 160.0
	_decal.distance_fade_length = 40.0
	var dx := nrm.cross(Vector3.FORWARD if absf(nrm.z) < 0.9 else Vector3.RIGHT).normalized()
	_decal.basis = Basis(dx, nrm, dx.cross(nrm)).orthonormalized().rotated(nrm, rng.randf() * TAU)
	_decal.position = Vector3(0, (lo + hi) * 0.5, 0)
	add_child(_decal)
	_scorches.append(self)
	if _scorches.size() > MAX_SCORCH:
		var oldest = _scorches.pop_front()
		if is_instance_valid(oldest):
			oldest._hold = minf(oldest._hold, 0.0)
	# The air above it wavers
	if Game.quality >= 1 and not far and radius >= 2.5:
		_haze = MeshInstance3D.new()
		var hq := QuadMesh.new()
		hq.size = Vector2(radius * 1.9, 3.4 * big + 0.6)
		hq.center_offset = Vector3(0, hq.size.y * 0.5, 0)
		_haze.mesh = hq
		var hm := ShaderMaterial.new()
		if _haze_shader == null:
			_haze_shader = load("res://scripts/heat_haze.gdshader")
		hm.shader = _haze_shader
		hm.render_priority = -1   # drawn before the flames, so it bends only what lies behind them
		_haze.material_override = hm
		_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_haze.visibility_range_end = 45.0
		_haze.position = Vector3(0, 0.3 + (lo + hi) * 0.5, 0)
		add_child(_haze)
	# Its roar, low and soft under everything
	if loud and not lvl_hushed():
		_snd = AudioStreamPlayer3D.new()
		_snd.stream = Arms.flame_loop()
		_snd.bus = Game.bus_of("flame")
		_snd_db = -16.0 + 4.0 * big
		_snd.volume_db = _snd_db
		_snd.pitch_scale = 0.72
		_snd.unit_size = 4.0
		_snd.max_distance = 50.0
		_snd.position.y = 0.5
		add_child(_snd)
		_snd.play(randf() * 1.0)
	if splash:
		_splash(data, rng, thin, big)


func lvl_hushed() -> bool:
	var lv := get_parent()
	return lv != null and lv.get("hush") == true


## The bottle breaking: a white flash, a ball of flame, burning spray, and big drops flung out that
## land and burn where they fall.
func _splash(data: Array, rng: RandomNumberGenerator, thin: float, big: float) -> void:
	var ball := _one_shot(roundi(26 * maxf(thin, 0.6)), 0.65, _wisps())
	ball.mesh = _quad(1.3 * big + 0.4)
	ball.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ball.emission_sphere_radius = 0.35
	ball.direction = Vector3.UP
	ball.spread = 80.0
	ball.initial_velocity_min = 2.0
	ball.initial_velocity_max = 6.5 * big + 1.0
	ball.damping_min = 5.0
	ball.damping_max = 8.0
	ball.gravity = Vector3(0, 3.0, 0)
	ball.angle_min = 0.0
	ball.angle_max = 360.0
	ball.scale_amount_curve = _curve([0.6, 1.6, 1.9])
	ball.color_ramp = _ramp([Color(1.0, 1.0, 0.9, 1.0), Color(1.0, 0.75, 0.3, 1.0), Color(1.0, 0.4, 0.08, 0.7), Color(0.25, 0.05, 0.0, 0.0)])
	ball.position.y = 0.2
	var spray := _one_shot(roundi(44 * maxf(thin, 0.6)), 0.9, _sparks())
	spray.mesh = _quad(0.16)
	spray.direction = Vector3.UP
	spray.spread = 75.0
	spray.initial_velocity_min = 3.0
	spray.initial_velocity_max = 8.5 * big + 1.5
	spray.gravity = Vector3(0, -9.8, 0)
	spray.scale_amount_min = 0.5
	spray.scale_amount_max = 1.5
	spray.color_ramp = _ramp([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.55, 0.12, 1.0), Color(0.8, 0.2, 0.03, 0.0)])
	spray.position.y = 0.15
	var puff := _one_shot(roundi(8 * maxf(thin, 0.6)), 2.4, _smoke())
	puff.mesh = _quad(1.8 * big + 0.4)
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 0.5
	puff.direction = Vector3.UP
	puff.spread = 60.0
	puff.initial_velocity_min = 1.5
	puff.initial_velocity_max = 3.5
	puff.damping_min = 1.5
	puff.damping_max = 2.5
	puff.gravity = Vector3(0, 0.8, 0)
	puff.angle_max = 360.0
	puff.scale_amount_curve = _curve([0.5, 1.5, 2.2])
	puff.color_ramp = _ramp([Color(0.1, 0.08, 0.07, 0.0), Color(0.09, 0.08, 0.07, 0.3), Color(0.25, 0.24, 0.23, 0.0)])
	puff.position.y = 0.8
	# The big drops: each flies on its own arc to a patch at the edge, trailing fire, and sets it alight
	var from := Vector3(0, 0.3, 0)
	for dj in data:
		if not dj.has("fly"):
			continue
		var tt: float = dj.fly
		var vel: Vector3 = ((dj.p as Vector3) - from) / tt - Vector3(0, -9.8, 0) * tt * 0.5
		var dn := Node3D.new()
		var core := MeshInstance3D.new()
		core.mesh = _quad(0.42)
		core.material_override = _wisps()
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dn.add_child(core)
		if thin >= 1.0:
			var tr := CPUParticles3D.new()
			tr.amount = 10
			tr.lifetime = 0.3
			tr.local_coords = false
			tr.mesh = _quad(0.3)
			tr.material_override = _wisps()
			tr.direction = Vector3.UP
			tr.spread = 30.0
			tr.initial_velocity_min = 0.2
			tr.initial_velocity_max = 0.8
			tr.gravity = Vector3(0, 1.0, 0)
			tr.scale_amount_curve = _curve([1.0, 0.6, 0.1])
			tr.color_ramp = _ramp([Color(1.0, 0.85, 0.5, 0.9), Color(1.0, 0.45, 0.1, 0.6), Color(0.4, 0.06, 0.0, 0.0)])
			tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dn.add_child(tr)
		add_child(dn)
		dn.position = from
		_drops.append([dn, from, vel, tt])


func _process(delta: float) -> void:
	age += delta
	var life := 1.0
	var fade_at := secs - 1.0
	if age > fade_at:
		life = clampf(1.0 - (age - fade_at) / 2.2, 0.0, 1.0)
	if _tongues:
		_tongues.set_instance_shader_parameter("age", age)
		_tongues.set_instance_shader_parameter("life", life)
	# The drops in flight
	for i in range(_drops.size() - 1, -1, -1):
		var d: Array = _drops[i]
		var dn: Node3D = d[0]
		var tt: float = minf(age, d[3])
		dn.position = (d[1] as Vector3) + (d[2] as Vector3) * tt + Vector3(0, -9.8, 0) * tt * tt * 0.5
		if age >= d[3]:
			dn.queue_free()
			_drops.remove_at(i)
	# The pool catches after the burst, and the licks and embers with it
	if age > 0.25 and _burning.size() > 0 and not _out:
		for p in _burning:
			if is_instance_valid(p) and not p.emitting and life > 0.3:
				p.emitting = true
	if _light:
		var flash := 9.0 * exp(-age * 7.0)
		var flick := 0.82 + 0.1 * sin(age * 11.0) + 0.06 * sin(age * 23.0 + 1.3) + 0.05 * sin(age * 5.1) + randf() * 0.06
		_light.light_energy = _light_base * flick * life + flash
		_light.visible = _light.light_energy > 0.02
	if _decal:
		# Burning fuel glows on the ground; it darkens to char as it burns, and the glow dies with the flames
		_decal.emission_energy = 0.9 * life * (0.85 + 0.15 * sin(age * 9.0)) * smoothstep(0.0, 0.5, age)
		_decal.albedo_mix = clampf(0.35 + age / secs * 0.65, 0.0, 1.0)
	if _haze:
		(_haze.material_override as ShaderMaterial).set_shader_parameter("strength", life * smoothstep(0.2, 1.0, age))
	if _snd:
		_snd.volume_db = _snd_db + linear_to_db(maxf(life, 0.001))
	# One's own pilgrim in it burns, as the forms do
	if life > 0.3 and age > 0.3 and Engine.get_process_frames() % 6 == 0:
		touch(global_position, radius, 0.0, true)
	if life <= 0.0 and not _out:
		_go_out()
	if _out:
		_hold -= delta
		if _hold <= 0.0:
			var a := clampf(1.0 + _hold / 3.0, 0.0, 1.0)
			_decal.modulate.a = a
			if a <= 0.0:
				queue_free()


## The flames are out: what still drifts up is let finish, and the char is left.
func _go_out() -> void:
	_out = true
	live -= 1
	for p in _burning:
		if is_instance_valid(p):
			p.emitting = false
	var tw := create_tween()
	tw.tween_interval(4.6)
	tw.tween_callback(func():
		for p in _burning:
			if is_instance_valid(p):
				p.queue_free()
		_burning.clear())
	for n in [_tongues, _light, _haze, _snd]:
		if n and is_instance_valid(n):
			n.queue_free()
	_tongues = null
	_light = null
	_haze = null
	_snd = null
	if _decal:
		_decal.emission_energy = 0.0


func _exit_tree() -> void:
	if not _out:
		_out = true
		live -= 1
	_scorches.erase(self)


# ------------------------------------------------------------------ the shared makings

## The tongues' look: one for every fire, each set apart by its own age and life.
static func tongue_mat() -> ShaderMaterial:
	if _tongue_m == null:
		_tongue_m = ShaderMaterial.new()
		_tongue_m.shader = load("res://scripts/fire_pool.gdshader")
	return _tongue_m


static func _wisps() -> StandardMaterial3D:
	if _wisp_m == null:
		_wisp_m = _glow_mat()
		_wisp_m.albedo_texture = LesserSpeeb.smoke_tex()
	return _wisp_m


static func _sparks() -> StandardMaterial3D:
	if _spark_m == null:
		_spark_m = _glow_mat()
		_spark_m.albedo_texture = Relics._soft_dot()
	return _spark_m


static func _glow_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


static func _smoke() -> StandardMaterial3D:
	if _smoke_m == null:
		_smoke_m = StandardMaterial3D.new()
		_smoke_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_smoke_m.vertex_color_use_as_albedo = true
		_smoke_m.albedo_texture = LesserSpeeb.smoke_tex()
		LesserSpeeb.soften(_smoke_m)
	return _smoke_m


static func _quad(s: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	return q


static func _curve(ys: Array) -> Curve:
	var c := Curve.new()
	c.max_value = 4.0
	for i in ys.size():
		c.add_point(Vector2(float(i) / (ys.size() - 1), ys[i]))
	return c


static func _ramp(cs: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(range(cs.size()).map(func(i): return float(i) / (cs.size() - 1)))
	g.colors = PackedColorArray(cs)
	return g


## Particles that rise from the given points (in this node's space) while the fire burns.
func _points(pts: PackedVector3Array, n: int, life: float, m: Material) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(n, 1)
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	p.local_coords = false
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	add_child(p)
	return p


func _one_shot(n: int, life: float, m: Material) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(n, 1)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.local_coords = false
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## The charred ground: near black, blotched, its edge broken. Made once.
static func char_tex() -> Texture2D:
	if _char_tex == null:
		_make_ground_tex()
	return _char_tex


## The burning fuel's glow, in streaks and pools. Made once.
static func glow_tex() -> Texture2D:
	if _glow_tex == null:
		_make_ground_tex()
	return _glow_tex


static func _make_ground_tex() -> void:
	const S := 128
	var nz := FastNoiseLite.new()
	nz.seed = 7
	nz.frequency = 0.045
	nz.fractal_octaves = 4
	var cell := FastNoiseLite.new()
	cell.seed = 11
	cell.noise_type = FastNoiseLite.TYPE_CELLULAR
	cell.frequency = 0.06
	cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var ci := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var gi := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var v := Vector2(x - S * 0.5 + 0.5, y - S * 0.5 + 0.5) / (S * 0.5)
			var n := nz.get_noise_2d(x, y) * 0.5 + 0.5
			var c := cell.get_noise_2d(x, y) * 0.5 + 0.5
			# A round edge, broken by the noise
			var r := v.length() + (n - 0.5) * 0.28
			var edge := clampf((0.97 - r) / 0.2, 0.0, 1.0)
			var a := edge * clampf(0.75 + n * 0.35, 0.0, 1.0)
			var dark := 0.03 + 0.05 * n
			ci.set_pixel(x, y, Color(dark * 1.15, dark, dark * 0.85, a))
			var hot := pow(clampf(1.0 - c * 2.2, 0.0, 1.0), 2.0) * 0.9 + pow(n, 3.0) * 0.5
			hot = clampf(hot, 0.0, 1.0) * edge * clampf(1.2 - r * 0.6, 0.0, 1.0)
			gi.set_pixel(x, y, Color(0.95 * hot, 0.36 * hot * hot + 0.04 * hot, 0.04 * hot * hot * hot, a))
	ci.generate_mipmaps()
	gi.generate_mipmaps()
	_char_tex = ImageTexture.create_from_image(ci)
	_glow_tex = ImageTexture.create_from_image(gi)


## Flames on a burning body, the height of it, while its time lasts; then they sink and go.
class Ablaze extends Node3D:
	var left := 1.4
	var _age := 0.0
	var _mm: MultiMeshInstance3D

	func build(e: Node3D) -> void:
		var tall := 1.6
		var hd = e.get("head")
		if hd is Node3D and is_instance_valid(hd):
			tall = clampf((hd as Node3D).global_position.y - e.global_position.y + 0.35, 0.5, 9.0)
		var wide := clampf(tall * 0.32, 0.25, 3.0)
		var s := e.global_transform.basis.get_scale()
		scale = Vector3(1.0 / maxf(s.x, 0.01), 1.0 / maxf(s.y, 0.01), 1.0 / maxf(s.z, 0.01))
		var n := clampi(roundi(tall * 3.0), 4, 9)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		q.center_offset = Vector3(0, 0.5, 0)
		mm.mesh = q
		mm.instance_count = n
		for i in n:
			var a := randf() * TAU
			var r := wide * sqrt(randf()) * 0.6
			var y := tall * (0.1 + 0.55 * float(i) / n)
			var h := tall * randf_range(0.5, 0.8)
			var foot := Vector3(cos(a) * r, y, sin(a) * r)
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(h * 0.6, h, h * 0.6)), foot))
			mm.set_instance_custom_data(i, Color(randf(), randf(), 0.0, randf() * 0.05))
		_mm = MultiMeshInstance3D.new()
		_mm.multimesh = mm
		_mm.material_override = FirePool.tongue_mat()
		_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mm.visibility_range_end = 160.0
		_mm.custom_aabb = AABB(Vector3(-wide - 1.0, -0.5, -wide - 1.0), Vector3(wide * 2.0 + 2.0, tall * 1.5 + 1.0, wide * 2.0 + 2.0))
		add_child(_mm)
		_mm.set_instance_shader_parameter("age", 0.0)
		_mm.set_instance_shader_parameter("life", 1.0)
		var p := CPUParticles3D.new()
		p.amount = clampi(roundi(tall * 5.0), 5, 14)
		p.lifetime = 1.3
		p.local_coords = false
		p.mesh = FirePool._quad(0.45 * clampf(tall / 1.6, 0.6, 2.5))
		p.material_override = FirePool._wisps()
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(wide * 0.4, tall * 0.35, wide * 0.4)
		p.position.y = tall * 0.45
		p.direction = Vector3.UP
		p.spread = 15.0
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 2.6
		p.gravity = Vector3(0, 1.5, 0)
		p.angle_max = 360.0
		p.scale_amount_curve = FirePool._curve([0.6, 1.0, 0.15])
		p.color_ramp = FirePool._ramp([Color(1.0, 0.85, 0.5, 0.9), Color(1.0, 0.45, 0.1, 0.7), Color(0.35, 0.06, 0.02, 0.35), Color(0.1, 0.05, 0.03, 0.0)])
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_range_end = 90.0
		add_child(p)

	func _process(delta: float) -> void:
		_age += delta
		left -= delta
		if _mm:
			_mm.set_instance_shader_parameter("age", _age)
			_mm.set_instance_shader_parameter("life", clampf(left / 0.5, 0.0, 1.0))
		if left <= 0.0:
			var par := get_parent()
			if par and par.get_meta("ablaze", null) == self:
				par.remove_meta("ablaze")
			queue_free()
