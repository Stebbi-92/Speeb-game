class_name Streaks
extends RefCounted
## Kill streaks: forms slain without falling call down help from the sky. Real aircraft, played grim:
## no music, no fanfare, only the sound of them arriving and what they leave behind.
##
##   5 kills    Airstrike      two jets lay a line of bombs across the marked ground
##   9 kills    Gun Run        a ground-attack jet dives and rakes a line with its cannon
##   14 kills   Gunship        an attack helicopter circles the mark and hunts what moves
##
## H calls the oldest earned one onto the point under the crosshair. Only the caller's game deals
## harm; everyone else sees and hears the same pass.

const KINDS := {
	"airstrike": {"name": "Airstrike", "kills": 5, "text": "Two jets lay a line of bombs across the marked ground."},
	"gunrun": {"name": "Gun Run", "kills": 9, "text": "A ground-attack jet rakes a line with its cannon."},
	"gunship": {"name": "Gunship", "kills": 14, "text": "An attack helicopter circles the mark for half a minute, hunting what moves."},
}
const ORDER := ["airstrike", "gunrun", "gunship"]


## Calls one in. `real` is true only in the caller's game.
static func call_in(lvl: Node, kind: String, at: Vector3, dir: Vector3, real: bool) -> void:
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	match kind:
		"airstrike":
			_airstrike(lvl, at, dir, real)
		"gunrun":
			_gunrun(lvl, at, dir, real)
		"gunship":
			_gunship(lvl, at, real)


static func _wait(lvl: Node, t: float) -> void:
	await lvl.get_tree().create_timer(t, false).timeout


static func _ground(lvl: Node, p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 200, 0), p - Vector3(0, 200, 0), 1)
	var r: Dictionary = lvl.get_world_3d().direct_space_state.intersect_ray(q)
	return r.position if not r.is_empty() else p


static func _airstrike(lvl: Node, at: Vector3, dir: Vector3, real: bool) -> void:
	lvl.sfx("flyby", 0, at + Vector3(0, 60, 0))
	var side := dir.cross(Vector3.UP)
	var jets: Array = []
	for i in 2:
		var j := _jet(false)
		lvl.add_child(j)
		jets.append(j)
		j.global_position = at - dir * 420.0 + side * (i * 14.0 - 7.0) + Vector3(0, 110 + i * 6, 0)
		j.look_at(j.global_position + dir, Vector3.UP)
		_fly(lvl, j, dir * 140.0, 6.5)
	await _wait(lvl, 2.6)
	if not is_instance_valid(lvl):
		return
	for k in 8:
		var p := _ground(lvl, at + dir * (k * 6.0 - 21.0) + side * randf_range(-3.0, 3.0))
		if real:
			Arms.blast(lvl, p + Vector3(0, 0.5, 0), 7.0, 220.0, lvl.get("player"))
		else:
			Arms.blast_fx(lvl, p + Vector3(0, 0.5, 0), 7.0)
		await _wait(lvl, 0.12)
		if not is_instance_valid(lvl):
			return


static func _gunrun(lvl: Node, at: Vector3, dir: Vector3, real: bool) -> void:
	var j := _jet(true)
	lvl.add_child(j)
	var start := at - dir * 330.0 + Vector3(0, 140, 0)
	j.global_position = start
	var aim := at - dir * 30.0
	var v := (aim + Vector3(0, 30, 0) - start).normalized() * 120.0
	j.look_at(j.global_position + v, Vector3.UP)
	lvl.sfx("flyby", -2, at + Vector3(0, 40, 0), 1.15)
	_fly(lvl, j, v, 2.4, true)
	await _wait(lvl, 2.2)
	if not is_instance_valid(lvl):
		return
	# The cannon: shells walk down the line faster than its sound
	for k in 34:
		var p := _ground(lvl, at + dir * (k * 1.8 - 30.0) + dir.cross(Vector3.UP) * randf_range(-2.0, 2.0))
		_impact(lvl, p)
		if real and k % 2 == 0:
			var hits := {}
			for e in lvl.get("enemies") if lvl.get("enemies") != null else []:
				if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(p) < 3.2:
					hits[e] = 95.0
			Arms.deal(hits, Vector3.DOWN)
		await _wait(lvl, 0.04)
		if not is_instance_valid(lvl):
			return
	lvl.sfx("brrt", 2, at)


static func _gunship(lvl: Node, at: Vector3, real: bool) -> void:
	var h := _helicopter()
	lvl.add_child(h)
	var center := at
	var r := 26.0
	h.global_position = center + Vector3(-300, 80, 0)
	lvl.sfx("rotor", -2, h.global_position)
	# Comes in, then circles
	var t := 0.0
	var arrive := 5.0
	var hold := 32.0
	var fire_t := 0.0
	var missile_t := 3.0
	var prev: Vector3 = h.global_position
	var rotor_t := 0.0
	while t < arrive + hold + 5.0 and is_instance_valid(h) and is_instance_valid(lvl):
		var dt := 0.05
		await _wait(lvl, dt)
		if not is_instance_valid(h):
			return
		t += dt
		var ang := t * 0.22
		var orbit := center + Vector3(cos(ang) * r, 30.0, sin(ang) * r)
		var p: Vector3
		if t < arrive:
			p = (center + Vector3(-300, 80, 0)).lerp(orbit, smoothstep(0.0, 1.0, t / arrive))
		elif t < arrive + hold:
			p = orbit
		else:
			p = orbit + Vector3(300, 60, 0) * smoothstep(0.0, 1.0, (t - arrive - hold) / 5.0)
		h.global_position = p
		var vel := (p - prev) / dt
		prev = p
		var face := center if t > arrive * 0.6 and t < arrive + hold else p + vel
		if face.distance_to(p) > 0.5:
			h.look_at(Vector3(face.x, p.y - 4.0, face.z), Vector3.UP)
		h.get_node("rotor").rotation.y += dt * 40.0
		rotor_t -= dt
		if rotor_t <= 0.0:
			rotor_t = 2.4
			lvl.sfx("rotor", -4, p)
		if t < arrive or t > arrive + hold:
			continue
		# Hunts what moves near the mark
		fire_t -= dt
		missile_t -= dt
		var best = null
		var bd := 70.0
		for e in lvl.get("enemies") if lvl.get("enemies") != null else []:
			if is_instance_valid(e) and e.is_alive():
				var d: float = e.global_position.distance_to(center)
				if d < bd:
					bd = d
					best = e
		if best == null:
			continue
		var tgt: Vector3 = best.global_position + Vector3(0, 0.6, 0)
		if fire_t <= 0.0:
			fire_t = 0.22
			_tracer(lvl, p - Vector3(0, 1.5, 0), tgt)
			lvl.sfx("mg", -8, p, 0.8)
			if real:
				Arms.deal({best: 26.0}, (tgt - p).normalized())
		if missile_t <= 0.0:
			missile_t = 5.0
			lvl.sfx("rocket", -4, p)
			await _wait(lvl, 0.6)
			if is_instance_valid(lvl):
				if real:
					Arms.blast(lvl, tgt, 5.0, 160.0, lvl.get("player"))
				else:
					Arms.blast_fx(lvl, tgt, 5.0)
	if is_instance_valid(h):
		h.queue_free()


static func _fly(lvl: Node, n: Node3D, v: Vector3, secs: float, pull_up := false) -> void:
	var t := 0.0
	while t < secs and is_instance_valid(n):
		await lvl.get_tree().process_frame
		if not is_instance_valid(n):
			return
		var dt: float = lvl.get_process_delta_time()
		t += dt
		if pull_up and t > secs * 0.75:
			v = v.lerp(Vector3(v.x, absf(v.length()) * 0.5, v.z), dt * 2.0)
			n.look_at(n.global_position + v, Vector3.UP)
		n.global_position += v * dt
	if is_instance_valid(n):
		n.queue_free()


static func _impact(lvl: Node, p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.55, 0.5, 0.42, 0.85)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lvl.add_child(mi)
	mi.global_position = p + Vector3(0, 0.4, 0)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(2.2, 3.5, 2.2), 0.6)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(mi.queue_free)
	lvl.sfx("thud", -8, p, randf_range(0.8, 1.2))


static func _tracer(lvl: Node, a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, a.distance_to(b))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.8, 0.5)
	mi.material_override = m
	lvl.add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	lvl.get_tree().create_timer(0.06, false).timeout.connect(mi.queue_free)
	lvl.puff(b, Vector3.UP)


static func _mat(c: Color, metal := 0.3, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


static func _box(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


static func _cyl(p: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3(PI / 2, 0, 0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


## The aircraft are models ("Lowpoly F16 Block 70" and "Low poly A-10 Warthog" by SIpriv, "Low Poly Apache
## Gunship" by Duane's Mind, all CC-BY 4.0), brought to their true length, nose toward -Z, wheels up.
const AIR := {
	"jet": ["res://assets/models/air/f16.glb", 15.0, 0.0, "Lndg gear"],
	"attack": ["res://assets/models/air/a10.glb", 16.3, 0.0, "animation landing gear a10"],
	"heli": ["res://assets/models/air/apache.glb", 15.5, PI, "Rotor Rotation"],
}
static var _air_bounds := {}


static func _aircraft(kind: String) -> Node3D:
	var spec: Array = AIR[kind]
	var n := Node3D.new()
	var m: Node3D = (load(spec[0]) as PackedScene).instantiate()
	if not _air_bounds.has(kind):
		var bb := AABB()
		var first := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = Arms._chain(mi, m) * (mi as MeshInstance3D).get_aabb()
			bb = a if first else bb.merge(a)
			first = false
		_air_bounds[kind] = bb
	var b: AABB = _air_bounds[kind]
	var k: float = float(spec[1]) / maxf(b.size.z, 0.01)
	var c := b.get_center()
	var turn := Basis(Vector3.UP, float(spec[2]))
	m.transform = Transform3D(turn.scaled(Vector3.ONE * k), turn * (-c * k))
	n.add_child(m)
	for ap in m.find_children("*", "AnimationPlayer", true, false):
		var player := ap as AnimationPlayer
		var an := player.get_animation(spec[3])
		if kind == "heli":
			an.loop_mode = Animation.LOOP_LINEAR
			player.play(spec[3])
		else:
			player.play(spec[3])
			player.seek(an.length, true)   # its wheels folded away
			player.pause()
	return n


## A grey jet, nose toward -Z: the fighter, or the ground-attack one with straight wings and engines on its back.
static func _jet(attack: bool) -> Node3D:
	var n := _aircraft("attack" if attack else "jet")
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.3)
	glow.light_energy = 2.0
	glow.omni_range = 10.0
	glow.position = Vector3(0, 0, 8.0)
	n.add_child(glow)
	return n


## An attack helicopter, its blades turning. Its main rotor is named "rotor" (the blades spin in the model's own take).
static func _helicopter() -> Node3D:
	var n := _aircraft("heli")
	var rotor := Node3D.new()
	rotor.name = "rotor"
	n.add_child(rotor)
	var l := SpotLight3D.new()
	l.light_energy = 3.0
	l.spot_range = 60.0
	l.spot_angle = 18.0
	l.position = Vector3(0, -1.0, -3.0)
	l.rotation.x = -0.9
	n.add_child(l)
	return n
