class_name WSpiritCat
extends Node3D
## A spirit-cat, called up from a relic: a pale, glowing cat that runs at whatever is nearest its pilgrim
## and bites until its time runs out, then fades. Forms do not see it and cannot harm it.
## On the caller's own machine it hunts; friends see a puppet that keeps close to the caller.

var w
var kind := "ember"
var spec := {}
var owner_node: Node3D        ## the pilgrim (or a friend's figure) it keeps to
var puppet := false
var life := 60.0
var _bite_t := 0.0
var _foe = null
var _look_t := 0.0
var _speed := 0.0
var _ph := 0.0
var _t := 0.0
var _fade := 0.0
var _body: Node3D
var _legs: Array = []
var _tail: Node3D
var _head: Emoji3D
var _light: OmniLight3D
var _mats: Array = []


func setup(world, k: String, who: Node3D, is_puppet: bool) -> WSpiritCat:
	w = world
	kind = k
	spec = WSpirits.KINDS[k]
	owner_node = who
	puppet = is_puppet
	life = float(spec.life)
	return self


func _ready() -> void:
	var c: Color = spec.color
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.55)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.4
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats.append(m)
	var pale := m.duplicate()
	pale.albedo_color = Color(1, 1, 1, 0.5)
	_mats.append(pale)
	_body = Node3D.new()
	_body.scale = Vector3.ONE * float(spec.size)
	add_child(_body)
	if _real_body(m):
		_head = Emoji3D.new().setup(str(spec.face), 0.6)
		_head.glow = 0.6
		_body.add_child(_head)
		_place_head()
		_lights_and_name(c)
		return
	_box(Vector3(0.62, 0.55, 1.35), Vector3(0, 0.95, 0), m)
	_box(Vector3(0.56, 0.6, 0.4), Vector3(0, 1.08, 0.62), m)
	for z in [0.48, -0.5]:
		for x in [-0.2, 0.2]:
			var leg := Node3D.new()
			leg.position = Vector3(x, 0.78, z)
			_body.add_child(leg)
			var l := _box(Vector3(0.17, 0.7, 0.19), Vector3(0, -0.35, 0), m)
			l.reparent(leg, false)
			_legs.append(leg)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.1, -0.66)
	_body.add_child(_tail)
	var t := _box(Vector3(0.12, 0.12, 0.8), Vector3(0, 0.25, -0.35), pale)
	t.rotation.x = 0.7
	t.reparent(_tail, false)
	_head = Emoji3D.new().setup(str(spec.face), 0.95)
	_head.glow = 0.6
	_head.position = Vector3(0, 1.48, 0.95)
	_body.add_child(_head)
	_lights_and_name(c)


func _lights_and_name(c: Color) -> void:
	_light = OmniLight3D.new()
	_light.light_color = c
	_light.light_energy = 1.2
	_light.omni_range = 6.0
	_light.position.y = 1.2
	add_child(_light)
	var lbl := Label3D.new()
	lbl.text = str(spec.name)
	lbl.font_size = 36
	lbl.pixel_size = 0.005
	lbl.outline_size = 8
	lbl.modulate = c.lightened(0.3)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position.y = 2.2 * float(spec.size)
	add_child(lbl)


## The riding cat's body (Animal Animator's sphynx, see WCat), small and made of the spirit's light, running
## and biting by its own clips; its own head drawn small inside the spirit's face.
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _head_bone := -1
var _gait := ""


func _real_body(m: Material) -> bool:
	if not ResourceLoader.exists(WCat.MODEL):
		return false
	var model: Node3D = (load(WCat.MODEL) as PackedScene).instantiate()
	model.scale = Vector3.ONE * WCat.MODEL_SCALE * 0.5
	_body.add_child(model)
	var sks := model.find_children("*", "Skeleton3D", true, false)
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		model.queue_free()
		return false
	_skel = sks[0]
	_anim = aps[0]
	_head_bone = _skel.find_bone(WCat.HEAD_BONE)
	var head_path := "%s:%s" % [str(_anim.get_parent().get_path_to(_skel)), WCat.HEAD_BONE]
	for a in _anim.get_animation_list():
		var an := _anim.get_animation(a)
		for t in range(an.get_track_count() - 1, -1, -1):
			if an.track_get_type(t) == Animation.TYPE_SCALE_3D and str(an.track_get_path(t)) == head_path:
				an.remove_track(t)
		if a in WCat.GAITS:
			an.loop_mode = Animation.LOOP_LINEAR
	if _head_bone >= 0:
		_skel.set_bone_pose_scale(_head_bone, Vector3.ONE * 0.08)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mm: MeshInstance3D = mi
		mm.material_override = m
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gait_to("Cat_Idle")
	return true


func _gait_to(g: String, blend := 0.25) -> void:
	if _anim and g != _gait and _anim.has_animation(g):
		_gait = g
		_anim.play(g, blend)


func _place_head() -> void:
	if _skel == null or _head_bone < 0 or _head == null:
		return
	var at: Vector3 = (_skel.global_transform * _skel.get_bone_global_pose(_head_bone)).origin
	_head.position = _body.to_local(at) + Vector3(0, 0.08, 0.12)


func _box(size: Vector3, pos: Vector3, mt: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mt
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	if _fade > 0.0:
		_fade -= delta
		var a := clampf(_fade / 1.2, 0.0, 1.0)
		for mt in _mats:
			mt.albedo_color.a = 0.55 * a
		_light.light_energy = 1.2 * a
		_body.scale = Vector3.ONE * float(spec.size) * (0.6 + 0.4 * a)
		if _fade <= 0.0:
			queue_free()
		return
	life -= delta
	if life <= 0.0 or owner_node == null or not is_instance_valid(owner_node):
		end()
		return
	var want := Vector3.ZERO
	var home: Vector3 = owner_node.global_position
	var to_home := home - global_position
	to_home.y = 0.0
	if to_home.length() > 40.0:
		# Too far behind: it is simply there again, at the pilgrim's heel
		_appear_at(home + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
		return
	if not puppet:
		_look_t -= delta
		if _look_t <= 0.0 or _foe == null or not is_instance_valid(_foe) or not _foe.is_alive():
			_look_t = 0.5
			_foe = _nearest(home)
	if _foe != null and is_instance_valid(_foe) and _foe.is_alive():
		var to: Vector3 = _foe.global_position - global_position
		to.y = 0.0
		var reach := 1.6 + float(_foe.spec.get("size", 1.0)) * 0.9
		if to.length() > reach:
			want = to.normalized() * float(spec.speed)
		else:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 8.0))
			_bite_t -= delta
			if _bite_t <= 0.0:
				_bite_t = float(spec.rate)
				_bite(_foe, to.normalized())
	elif to_home.length() > 4.0:
		want = to_home.normalized() * (float(spec.speed) if to_home.length() > 10.0 else 4.0)
	_speed = lerpf(_speed, want.length(), minf(1.0, delta * 5.0))
	if want.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(want.x, want.z), minf(1.0, delta * 6.0))
		var at := global_position + want.normalized() * _speed * delta
		global_position = w.gpos(Vector2(at.x, at.z))
	var k := clampf(_speed / 5.0, 0.0, 1.1)
	_ph += delta * (2.5 + _speed * 0.6)
	for i in _legs.size():
		_legs[i].rotation.x = sin(_ph + (PI if i in [1, 2] else 0.0)) * 0.6 * k
	if _anim:
		# Its own gaits, by its pace; a bite plays through
		if _gait != "Cat_Bite_Attack" or not _anim.is_playing():
			var g := "Cat_Idle" if _speed < 0.4 else ("Cat_Walk" if _speed < 2.5 else ("Cat_Trot" if _speed < 6.0 else "Cat_Gallop_Run"))
			_gait_to(g)
			var ref: float = {"Cat_Walk": 0.9, "Cat_Trot": 2.6, "Cat_Gallop_Run": 5.2}.get(g, 0.0)
			_anim.speed_scale = clampf(_speed / ref, 0.6, 1.8) if ref > 0.0 else 1.0
		_place_head()
		_body.position.y = sin(_t * 2.0) * 0.05
	else:
		_body.position.y = 0.15 + sin(_t * 2.0) * 0.08
	if _tail:
		_tail.rotation.y = sin(_t * 3.0) * 0.4
	_light.light_energy = 1.0 + sin(_t * 4.0) * 0.25


## The nearest living form within its reach of the pilgrim.
func _nearest(home: Vector3):
	var best = null
	var bd := float(WSpirits.REACH)
	for e in w.enemies:
		if not is_instance_valid(e) or not e.is_alive() or e.kind in ["unseen", "saucer"]:
			continue
		var d: float = e.global_position.distance_to(home)
		if d < bd:
			bd = d
			best = e
	return best


func _bite(e, dir: Vector3) -> void:
	var tier: int = clampi(w.tier_at(global_position), 1, WSpirits.TIER_BITE.size())
	var amount: float = float(spec.bite) * WSpirits.TIER_BITE[tier - 1]
	LesserSpeeb.harm_kind = str(spec.harm)
	e.hurt(amount, dir)
	LesserSpeeb.harm_kind = ""
	w.sfx("bite", -8, global_position, randf_range(1.2, 1.4))
	if _anim and _anim.has_animation("Cat_Bite_Attack"):
		_anim.get_animation("Cat_Bite_Attack").loop_mode = Animation.LOOP_NONE
		_gait = ""
		_gait_to("Cat_Bite_Attack", 0.1)
		_anim.speed_scale = 1.4
	else:
		_body.position.z = 0.25


func _appear_at(p: Vector3) -> void:
	global_position = w.gpos(Vector2(p.x, p.z))


## Its time is up: it fades.
func end() -> void:
	if _fade > 0.0:
		return
	_fade = 1.2
