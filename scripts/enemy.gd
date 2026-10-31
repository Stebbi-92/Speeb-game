class_name LesserSpeeb
extends CharacterBody3D
## A lesser form of Speeb, hostile to the seeker.
## rusher: closes in to bite.  spitter: keeps its distance and casts bolts.
## idol: gilded, slow, its face proof against shot; strike it from the side or behind.
## swarm: small and quick, comes in numbers.  elite: a great form, one to a land.
## spider: a cat head on eight legs; it skitters along the ground and leaps.
## saucer: a disc of the lesser that hovers out of reach and lets down mites, small forms that swarm.

signal died

const KINDS := {
	"rusher": {"hp": 52.0, "size": 1.0, "speed": 5.6, "bite": 18.0, "radius": 0.45},
	"spitter": {"hp": 38.0, "size": 0.85, "speed": 3.2, "bite": 0.0, "radius": 0.4},
	"idol": {"hp": 90.0, "size": 1.25, "speed": 2.6, "bite": 26.0, "radius": 0.55},
	"swarm": {"hp": 12.0, "size": 0.5, "speed": 7.0, "bite": 7.0, "radius": 0.25},
	"elite": {"hp": 320.0, "size": 2.0, "speed": 4.0, "bite": 30.0, "radius": 0.9},
	"saucer": {"hp": 150.0, "size": 1.0, "speed": 4.5, "bite": 0.0, "radius": 1.6},
	"mite": {"hp": 9.0, "size": 0.42, "speed": 7.6, "bite": 5.0, "radius": 0.22},
	"spider": {"hp": 44.0, "size": 0.8, "speed": 7.2, "bite": 15.0, "radius": 0.55},
}
const IDOL_CODES := ["goldspeeb", "marblespeeb", "jadespeeb", "obsidianspeeb", "fossilspeeb"]

var code := ""
var kind := "rusher"
var hp := 40.0
var level: Level
var head: LesserHead
var _legs: Array = []
var _leap_cd := 2.0
var spec: Dictionary
var _attack_cd := 1.0
var _flash := 0.0
var _alive := true
var _t := 0.0
var _knock := Vector3.ZERO
var _strafe := 1.0
var _disc: Node3D
var _beam: MeshInstance3D
var _mites: Array = []
var _cry_cd := 0.0
# In a fellowship the host runs every form; the others see puppets that follow what the host tells them
var net_id := 0
var puppet := false
var credit := false
var last_hitter := 1
var heard_at := 0
var _net_to := Vector3.ZERO
var _net_body_y := 0.0
var _net_head := Vector2.ZERO
var _net_v := Vector3.ZERO


func setup(c: String, k: String, lvl: Level) -> LesserSpeeb:
	kind = k
	code = IDOL_CODES[randi() % IDOL_CODES.size()] if k == "idol" else c
	level = lvl
	spec = KINDS[k]
	hp = spec.hp * Game.difficulty_scale("hp")
	return self


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0 if puppet else (1 | 2)
	_net_to = position
	heard_at = Time.get_ticks_msec()
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED if kind == "spider" else CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	if kind == "saucer":
		var cy := CylinderShape3D.new()
		cy.radius = spec.radius
		cy.height = 1.5
		cs.shape = cy
		cs.position.y = 0.15
	else:
		var s := SphereShape3D.new()
		s.radius = spec.radius
		cs.shape = s
	add_child(cs)
	head = LesserHead.new().setup(code, spec.size)
	head.position.y = 0.42 if kind == "saucer" else -0.05 * spec.size
	add_child(head)
	if kind == "idol":
		head.set_gild(1.0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.15, 0.08)
	l.light_energy = 2.5 if kind == "elite" else 1.2
	l.omni_range = 3.5 * spec.size
	l.position = Vector3(0, 0.2, 0.9) * spec.size
	add_child(l)
	if kind == "spider":
		_build_spider()
	if kind == "elite":
		var crown := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.5
		tm.outer_radius = 0.58
		crown.mesh = tm
		var cm := StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.albedo_color = Color(1.0, 0.15, 0.08)
		crown.material_override = cm
		crown.position.y = 1.45
		add_child(crown)
	if kind == "saucer":
		_build_saucer()
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_attack_cd = randf_range(1.0, 2.5)
	_cry_cd = randf_range(0.5, 2.0)
	if kind == "elite":
		level.sfx("roar", 2, global_position, 0.9)
	elif kind == "saucer":
		var hum := AudioStreamPlayer3D.new()
		var st = load("res://assets/audio/saucer_hum.ogg")
		st.loop = true
		hum.stream = st
		hum.unit_size = 14
		hum.volume_db = -2
		hum.autoplay = true
		add_child(hum)
	elif kind == "spider":
		_cry("critter_%d" % (randi() % 3), -2)
	elif kind != "mite":
		_cry("growl_%d" % (randi() % 3), -4)


## A cry from the lesser form, pitched by its size: the small shriek high, the great ones low.
func _cry(sound: String, vol := 0.0) -> void:
	var pitch: float = clampf(1.0 / spec.size, 0.6, 1.7) * randf_range(0.85, 1.15)
	level.sfx(sound, vol, global_position, pitch)



func _physics_process(delta: float) -> void:
	if not _alive or level.player == null:
		return
	if puppet:
		_puppet_tick(delta)
		return
	delta *= level.enemy_time
	_t += delta
	# It hunts the nearest pilgrim still standing; with none, it waits
	var p: Node3D = level.nearest_target(global_position)
	var idle := p == null
	if idle:
		p = level.player
	# A form that falls from the world, or strays too far from it, is simply unmade
	if global_position.y < level.kill_y or (not idle and global_position.distance_to(p.global_position) > 90.0):
		die(false)
		return
	var target := p.global_position + Vector3(0, 1.3, 0)
	var to := target - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	var turn := 1.5 if kind == "idol" else 12.0
	head.rotation.y = lerp_angle(head.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * turn))
	head.rotation.x = -asin(clampf(dir.y, -0.6, 0.6)) * 0.6
	var want := Vector3.ZERO
	var frozen: bool = level.combat_frozen or idle
	if kind == "spider":
		_spider_move(delta, p, dist, frozen)
		return
	var speed: float = spec.speed * Game.difficulty_scale("speed")
	if not frozen:
		match kind:
			"spitter":
				var side := dir.cross(Vector3.UP) * _strafe * 2.2
				if dist > 14.0:
					want = dir * speed + side
				elif dist < 8.0:
					want = -dir * speed * 0.9 + side
				else:
					want = side
				want.y += (target.y + 1.5 - global_position.y) * 1.2
			"saucer":
				var ang := _t * 0.3 * _strafe
				var hover := p.global_position + Vector3(cos(ang) * 11.0, 7.5, sin(ang) * 11.0)
				want = (hover - global_position).limit_length(speed)
			"elite":
				want = dir * speed if dist > 4.0 else dir.cross(Vector3.UP) * _strafe * 3.0
				want.y += (target.y + 0.8 - global_position.y) * 1.0
			_:
				want = dir * speed
				want += dir.cross(Vector3.UP) * sin(_t * 2.0 + _strafe) * (2.5 if kind == "swarm" else 1.2)
	want.y += sin(_t * 2.6) * 0.4
	velocity = velocity.lerp(want, minf(1.0, delta * 3.0)) + _knock
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	var real_v := velocity
	velocity *= level.enemy_time
	move_and_slide()
	velocity = real_v
	if is_on_wall():
		velocity.y += 6.0 * delta * 10.0
	_flash = maxf(0.0, _flash - delta * 5.0)
	head.set_flash(_flash)
	if frozen or level.completed or level.failing:
		return
	_attack_cd -= delta
	_cry_cd -= delta
	# The forms scream as they close on him
	if _cry_cd <= 0.0 and dist < 16.0:
		match kind:
			"rusher", "swarm", "idol":
				_cry("shriek_%d" % (randi() % 4), 0 if kind != "swarm" else -6)
				_cry_cd = randf_range(3.5, 7.0)
			"mite":
				_cry("chitter", -4)
				_cry_cd = randf_range(1.5, 3.5)
			"elite":
				level.sfx("roar", 0, global_position, randf_range(0.85, 1.05))
				_cry_cd = randf_range(7.0, 11.0)
			"spitter":
				_cry("growl_%d" % (randi() % 3), -2)
				_cry_cd = randf_range(5.0, 9.0)
	var reach: float = 1.0 + spec.radius
	if spec.bite > 0.0 and dist < reach and _attack_cd <= 0.0:
		_attack_cd = 1.3 if kind == "idol" else 0.9
		level.sfx("bite", -2, global_position)
		if randf() < 0.5:
			_cry("growl_%d" % (randi() % 3), 0)
		level.hurt_target(p, spec.bite, global_position)
		_knock = -dir * 6.0
	if kind == "saucer":
		_disc.rotation.y += delta * 2.5
		_mites = _mites.filter(func(m): return is_instance_valid(m) and m.is_alive())
		if _attack_cd <= 0.0:
			_attack_cd = randf_range(5.0, 6.5)
			if _mites.size() < 6:
				_let_down()
		return
	if (kind == "spitter" or kind == "elite") and _attack_cd <= 0.0 and dist < 26.0 and _can_see(target):
		_attack_cd = randf_range(1.5, 2.3)
		if kind == "elite":
			for k in [-0.2, 0.0, 0.2]:
				_spit(global_position + (target - global_position).rotated(Vector3.UP, k))
		else:
			_spit(target)


## Eight legs about a dark abdomen, the head carried low in front.
func _build_spider() -> void:
	head.position = Vector3(0, 0.1, 0.25)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = head.fur.darkened(0.85)
	dark.roughness = 0.5
	dark.metallic = 0.2
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.8
	body.mesh = sm
	body.material_override = dark
	body.position = Vector3(0, 0.15, -0.5)
	body.scale = Vector3(1.0, 0.8, 1.25)
	add_child(body)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.08, 0.04)
	var mark := MeshInstance3D.new()
	var mm := PrismMesh.new()
	mm.size = Vector3(0.22, 0.2, 0.05)
	mark.mesh = mm
	mark.material_override = red
	mark.position = Vector3(0, 0.5, -0.55)
	mark.rotation.x = -PI / 2
	add_child(mark)
	for side in [-1.0, 1.0]:
		for i in 4:
			var hip := Node3D.new()
			hip.position = Vector3(side * 0.22, 0.15, 0.05 - i * 0.22)
			add_child(hip)
			var knee := Vector3(side * 0.55, 0.38, 0.28 - i * 0.18)
			var foot := knee + Vector3(side * 0.35, -1.05, 0.16 - i * 0.1)
			_segment(hip, Vector3.ZERO, knee, 0.05, dark)
			_segment(hip, knee, foot, 0.035, dark)
			_legs.append({"pivot": hip, "phase": i * 1.6 + (0.0 if side > 0 else PI)})


func _segment(parent: Node3D, from: Vector3, to: Vector3, r: float, m: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r * 0.7
	c.bottom_radius = r
	c.height = from.distance_to(to)
	c.radial_segments = 6
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	var y := (to - from).normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	if x.length() < 0.1:
		x = Vector3.RIGHT
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), (from + to) * 0.5)
	parent.add_child(mi)


## The spider runs the ground, legs rippling, and springs when near.
func _spider_move(delta: float, p: Node3D, dist: float, frozen: bool) -> void:
	var flat := p.global_position - global_position
	flat.y = 0
	var fd := flat.length()
	var dir := flat / maxf(fd, 0.01)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 10.0))
	var speed: float = spec.speed * Game.difficulty_scale("speed")
	var on_floor := is_on_floor()
	if not frozen:
		var want := dir * speed + dir.cross(Vector3.UP) * sin(_t * 3.0 + _strafe) * 2.5
		if on_floor:
			velocity.x = lerpf(velocity.x, want.x, minf(1.0, delta * 8.0))
			velocity.z = lerpf(velocity.z, want.z, minf(1.0, delta * 8.0))
		_leap_cd -= delta
		if on_floor and fd < 7.5 and fd > 2.0 and _leap_cd <= 0.0:
			_leap_cd = randf_range(2.0, 3.5)
			velocity = dir * 11.0 + Vector3(0, 6.5, 0)
			_cry("spider_hiss", 0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
	velocity.y -= 22.0 * delta
	velocity += _knock
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	var real_v := velocity
	velocity *= level.enemy_time
	move_and_slide()
	velocity = real_v
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	# Spiders climb what stands in their way
	if is_on_wall() and not frozen:
		velocity.y = 4.5
	# The legs ripple with its pace
	var pace := Vector2(velocity.x, velocity.z).length()
	for leg in _legs:
		var ph: float = _t * (6.0 + pace * 2.0) + leg.phase
		var amp := minf(0.4, 0.08 + pace * 0.05)
		leg.pivot.rotation.y = sin(ph) * amp
		leg.pivot.rotation.x = maxf(0.0, cos(ph)) * amp * -0.6
	head.rotation.y = 0.0
	head.rotation.x = -asin(clampf((p.global_position.y + 1.3 - global_position.y) / maxf(dist, 0.1), -0.6, 0.6)) * 0.5
	_flash = maxf(0.0, _flash - delta * 5.0)
	head.set_flash(_flash)
	if frozen or level.completed or level.failing:
		return
	_attack_cd -= delta
	_cry_cd -= delta
	if _cry_cd <= 0.0 and dist < 18.0:
		_cry_cd = randf_range(1.2, 3.0)
		_cry("skitter" if randf() < 0.5 else "critter_%d" % (randi() % 3), -2)
	if dist < 1.6 and _attack_cd <= 0.0:
		_attack_cd = 0.8
		level.sfx("bite", -2, global_position)
		level.hurt_target(p, spec.bite, global_position)
		_knock = -dir * 5.0


## The hull of a saucer: a spinning disc ringed with red lights, a glass dome over its head.
func _build_saucer() -> void:
	_disc = Node3D.new()
	add_child(_disc)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.32, 0.31, 0.33)
	steel.metallic = 0.85
	steel.roughness = 0.3
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.95
	tm.bottom_radius = 1.75
	tm.height = 0.32
	top.mesh = tm
	top.material_override = steel
	top.position.y = 0.0
	_disc.add_child(top)
	var under := MeshInstance3D.new()
	var um := CylinderMesh.new()
	um.top_radius = 1.75
	um.bottom_radius = 0.8
	um.height = 0.28
	under.mesh = um
	under.material_override = steel
	under.position.y = -0.3
	_disc.add_child(under)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.12, 0.06)
	for i in 10:
		var a := TAU * i / 10.0
		var lamp := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.09
		lm.height = 0.18
		lamp.mesh = lm
		lamp.material_override = red
		lamp.position = Vector3(cos(a) * 1.68, -0.16, sin(a) * 1.68)
		_disc.add_child(lamp)
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.78
	dm.height = 1.56
	dome.mesh = dm
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.2, 0.18, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.4
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	dome.material_override = glass
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.position.y = 0.4
	add_child(dome)
	_beam = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.6
	bm.bottom_radius = 2.2
	bm.height = 7.0
	_beam.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(1.0, 0.2, 0.12, 0.0)
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = bmat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = -3.9
	add_child(_beam)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.2, 0.1)
	spot.light_energy = 3.0
	spot.spot_range = 14.0
	spot.spot_angle = 28.0
	spot.rotation_degrees.x = -90
	add_child(spot)


## A red beam falls, and three mites are let down to swarm the seeker.
func _let_down() -> void:
	level.sfx("beam", 0, global_position)
	var m: StandardMaterial3D = _beam.material_override
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.35, 0.3)
	tw.tween_interval(0.9)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	for i in 3:
		var at := global_position + Vector3(randf_range(-0.8, 0.8), -1.2 - i * 0.6, randf_range(-0.8, 0.8))
		_mites.append(level.spawn_at("mite", at))


func _can_see(target: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, target, 1)
	q.exclude = [get_rid(), level.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _spit(target: Vector3) -> void:
	level.sfx("spit", -6, global_position)
	if randf() < 0.6:
		_cry("screech", -2)
	var b := Bolt.new()
	b.level = level
	b.velocity = (target - global_position).normalized() * 14.0
	level.add_child(b)
	b.global_position = global_position + (target - global_position).normalized() * (spec.radius + 0.2)
	if Net.online:
		Net.bolt(b.global_position, b.velocity, b.damage)


## Returns true if the blow landed with force (false when a gilded face turned it aside).
func hurt(amount: float, from_dir: Vector3) -> bool:
	if not _alive:
		return false
	var full := true
	if kind == "idol":
		var facing := Vector3(sin(head.rotation.y), 0, cos(head.rotation.y))
		var incoming := -from_dir
		incoming.y = 0
		if facing.dot(incoming.normalized()) > 0.35:
			full = false
	if puppet:
		# The blow is sent to the host, who alone decides whether the form is undone
		Net.hit(net_id, amount, from_dir)
		_flash = 1.0 if full else 0.3
		return full
	if not full:
		amount *= 0.12
	hp -= amount
	_flash = 1.0 if full else 0.3
	_knock += from_dir.normalized() * amount * (0.08 if kind == "elite" else 0.25)
	if hp <= 0.0:
		die(true)
	return full


func is_alive() -> bool:
	return _alive


func die(slain: bool) -> void:
	if not _alive:
		return
	_alive = false
	collision_layer = 0
	level.sfx("dissolve", -4, global_position)
	var mine := credit if puppet else last_hitter == Net.me()
	if Net.is_host() and not puppet:
		level.foes.erase(net_id)
		Net.foe_died(net_id, slain, last_hitter)
	if slain:
		level.burst(global_position, head.fur)
		if mine:
			level.on_enemy_slain(self)
			if Game.find_emoji(code) and Game.lesser.has(code):
				var e: Dictionary = Game.lesser[code]
				level.hud.notify("Recorded in the Book of Emojis\n%s: %s" % [e.name, e.decree])
		elif not puppet:
			level.team_kill(self)
	died.emit()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.4, 0.05, 1.4) if slain else Vector3.ONE * 0.01, 0.35)
	tw.tween_callback(queue_free)


## What the host tells the others of this form, fifteen times a second.
func net_state() -> Array:
	return [net_id, kind, code, global_position, rotation.y, head.rotation.y, head.rotation.x, _flash]


func net_apply(st: Array) -> void:
	var to: Vector3 = st[3]
	_net_v = (to - _net_to) * 15.0
	_net_to = to
	_net_body_y = st[4]
	_net_head = Vector2(st[5], st[6])
	_flash = maxf(_flash, st[7])
	if global_position.distance_to(to) > 6.0:
		global_position = to


## A puppet glides toward where the host says the form is, and keeps its cries and its legs.
func _puppet_tick(delta: float) -> void:
	_t += delta
	global_position = global_position.lerp(_net_to + _net_v * 0.03, minf(1.0, delta * 12.0))
	rotation.y = lerp_angle(rotation.y, _net_body_y, minf(1.0, delta * 12.0))
	head.rotation.y = lerp_angle(head.rotation.y, _net_head.x, minf(1.0, delta * 12.0))
	head.rotation.x = lerpf(head.rotation.x, _net_head.y, minf(1.0, delta * 12.0))
	_flash = maxf(0.0, _flash - delta * 5.0)
	head.set_flash(_flash)
	if kind == "saucer" and _disc:
		_disc.rotation.y += delta * 2.5
	if kind == "spider":
		var pace := Vector2(_net_v.x, _net_v.z).length()
		for leg in _legs:
			var ph: float = _t * (6.0 + pace * 2.0) + leg.phase
			var amp := minf(0.4, 0.08 + pace * 0.05)
			leg.pivot.rotation.y = sin(ph) * amp
			leg.pivot.rotation.x = maxf(0.0, cos(ph)) * amp * -0.6
	_cry_cd -= delta
	var dist := global_position.distance_to(level.player.global_position)
	if _cry_cd <= 0.0 and dist < 16.0 and not level.combat_frozen:
		_cry_cd = randf_range(3.5, 7.0)
		match kind:
			"rusher", "swarm", "idol":
				_cry("shriek_%d" % (randi() % 4), 0 if kind != "swarm" else -6)
			"mite":
				_cry("chitter", -4)
			"elite":
				level.sfx("roar", 0, global_position, randf_range(0.85, 1.05))
			"spitter":
				_cry("growl_%d" % (randi() % 3), -2)
			"spider":
				_cry("skitter" if randf() < 0.5 else "critter_%d" % (randi() % 3), -2)


## A spat bolt of burning light.
class Bolt extends Area3D:
	var velocity := Vector3.ZERO
	var damage := 13.0
	var level: Level
	var life := 4.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.22
		cs.shape = s
		add_child(cs)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.35, 0.2)
		mi.material_override = m
		add_child(mi)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.3, 0.15)
		l.light_energy = 1.2
		l.omni_range = 3.5
		add_child(l)
		body_entered.connect(_hit)

	func _physics_process(delta: float) -> void:
		global_position += velocity * delta * level.enemy_time
		life -= delta * level.enemy_time
		if life <= 0.0:
			queue_free()

	func _hit(b: Node) -> void:
		if b is Player:
			level.damage_player(damage, global_position)
		queue_free()
