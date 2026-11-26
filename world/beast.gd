class_name WBeast
extends CharacterBody3D
## The beasts of the waste: lean things that graze the ash and run from the living. Hunted, they feed you.
## The host moves them and decides what they do; everyone else sees them where the host says.

const KINDS := {
	"hare": {"name": "Ash Hare", "hp": 14.0, "speed": 9.5, "walk": 1.6, "flee": 16.0, "size": 0.45,
		"color": Color(0.5, 0.45, 0.38), "drops": [["raw_meat", 1, 1], ["hide", 0, 1]],
		"lands": ["ash", "dunes", "salt"]},
	"goat": {"name": "Dune Goat", "hp": 45.0, "speed": 7.5, "walk": 1.3, "flee": 24.0, "size": 0.9,
		"color": Color(0.62, 0.5, 0.36), "drops": [["raw_meat", 2, 3], ["hide", 1, 2], ["bone", 0, 1]],
		"lands": ["dunes", "basalt", "forest", "ash"]},
	"tusker": {"name": "Ash Tusker", "hp": 90.0, "speed": 7.0, "walk": 1.2, "flee": 0.0, "size": 1.0,
		"color": Color(0.28, 0.24, 0.22), "drops": [["raw_meat", 3, 5], ["hide", 2, 3], ["bone", 1, 2]],
		"lands": ["forest", "marsh", "ash"], "bite": 16.0},
}

var id := 0
var kind := "hare"
var spec: Dictionary
var hp := 10.0
var w   ## the wasteland
var _alive := true
var _flee := 0.0          ## seconds left running away
var _rage := 0.0          ## a tusker's charge, seconds left
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _bite_cd := 0.0
var _body: Node3D
var _legs: Array = []
var _step := 0.0
var _net_to := Vector3.ZERO
var _net_yaw := 0.0
var _label: Label3D


func setup(lvl, bid: int, k: String) -> WBeast:
	w = lvl
	id = bid
	kind = k
	spec = KINDS[k]
	hp = float(spec.hp)
	return self


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_net_to = global_position
	var s: float = spec.size
	if HITS.has(kind):
		_fit_hits(s / float(BASE[kind]))
	else:
		var cs := CollisionShape3D.new()
		var sh := CapsuleShape3D.new()
		sh.radius = 0.32 * s
		sh.height = 1.2 * s
		cs.shape = sh
		cs.rotation.x = PI / 2
		cs.position.y = 0.55 * s
		add_child(cs)
	_build()
	_label = Label3D.new()
	_label.text = spec.name
	_label.font_size = 36
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 1.3 * s + 0.3
	_label.outline_size = 6
	_label.modulate = Color(0.9, 0.88, 0.8, 0.0)
	_label.no_depth_test = false
	add_child(_label)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _box(size: Vector3, pos: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	(parent if parent else _body).add_child(mi)
	return mi


## Real bodies (CC-BY 4.0, see CREDITS.md): [file, size in metres, measured "long" or "tall"], at the kind's own size.
const MODELS := {
	"hare": ["res://assets/models/beasts/rabbit_rigged.glb", 0.62, "long"],
	"goat": ["res://assets/models/beasts/goat_gerardo.glb", 1.3, "tall"],
	"tusker": ["res://assets/models/beasts/boar_male.glb", 1.7, "long", PI / 2,
		{"idle": "Arm_Boar|Idle_1", "walk": "Arm_Boar|Walk_F_IP", "trot": "Arm_Boar|Trot_F_IP", "run": "Arm_Boar|Run_F_IP"}, "fur"],
}
## [file, size, measured "long" or "tall", turn to face ahead, clips {idle, walk, trot, run}, a coat made for it]
static var _bounds := {}
const BASE := {"hare": 0.45, "goat": 0.9, "tusker": 1.0}   ## the kind's size its body's metres are measured at
## Where shots land on a real body, measured from its skinned rest pose (tools/probe_beastfit.gd), in metres at
## the kind's base size, head ahead (+Z): ["capsule", radius, length, centre] lies along the body;
## ["sphere", radius, centre]; ["box", size, centre]. Kept clear of the ground so it doesn't catch on it.
const HITS := {
	"goat": [["capsule", 0.31, 1.22, Vector3(0, 0.77, -0.17)], ["sphere", 0.22, Vector3(0, 0.98, 0.66)],
		["box", Vector3(0.4, 0.32, 0.95), Vector3(0, 0.28, -0.17)]],
}


func _fit_hits(k: float) -> void:
	for h in HITS[kind]:
		var cs := CollisionShape3D.new()
		match h[0]:
			"capsule":
				var c := CapsuleShape3D.new()
				c.radius = float(h[1]) * k
				c.height = float(h[2]) * k
				cs.shape = c
				cs.rotation.x = PI / 2
				cs.position = h[3] * k
			"sphere":
				var sp := SphereShape3D.new()
				sp.radius = float(h[1]) * k
				cs.shape = sp
				cs.position = h[2] * k
			"box":
				var bx := BoxShape3D.new()
				bx.size = h[1] * k
				cs.shape = bx
				cs.position = h[2] * k
		add_child(cs)
var _anim: AnimationPlayer
var _clips := {}    ## the body's own gaits by name, when it has more than one
var _gait := ""
var _bob := 0.0


## A real body where there is one: sized, set on its feet, a little greyed by the waste, its gait by its pace.
func _build_real() -> bool:
	if not MODELS.has(kind) or not ResourceLoader.exists(MODELS[kind][0]):
		return false
	var spec_m: Array = MODELS[kind]
	var m: Node3D = (load(spec_m[0]) as PackedScene).instantiate()
	if not _bounds.has(kind):
		var skinned := not m.find_children("*", "Skeleton3D", true, false).is_empty()
		var bb := AABB()
		if skinned:
			bb = LesserSpeeb._skinned_bounds(m)
		else:
			var first := true
			for mi in m.find_children("*", "MeshInstance3D", true, false):
				var a: AABB = WTrees._chain(mi, m) * (mi as MeshInstance3D).get_aabb()
				bb = a if first else bb.merge(a)
				first = false
		_bounds[kind] = bb
	var turn := Basis(Vector3.UP, float(spec_m[3]) if spec_m.size() > 3 else 0.0)
	var b: AABB = Transform3D(turn, Vector3.ZERO) * (_bounds[kind] as AABB)
	var want: float = float(spec_m[1]) * (float(spec.size) / float(BASE[kind]))
	var k := want / maxf(b.size.z if spec_m[2] == "long" else b.size.y, 0.001)
	var c := b.get_center()
	m.transform = Transform3D(turn.scaled(Vector3.ONE * k), Vector3(-c.x * k, -b.position.y * k, -c.z * k))
	_clips = spec_m[4] if spec_m.size() > 4 else {}
	_body.add_child(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mm.mesh == null:
			continue
		for si in mm.mesh.get_surface_count():
			var sm := mm.mesh.surface_get_material(si)
			if spec_m.size() > 5 and spec_m[5] == "fur":
				mm.set_surface_override_material(si, _fur_mat())
				continue
			if sm is StandardMaterial3D:
				var t := (sm as StandardMaterial3D).duplicate() as StandardMaterial3D
				t.albedo_color = t.albedo_color * Color(1, 1, 1).lerp(Color(spec.color).lightened(0.35), 0.35)
				mm.set_surface_override_material(si, t)
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_anim = aps[0]
		var names := _anim.get_animation_list()
		for cn in _clips.values():
			if _anim.has_animation(cn):
				_anim.get_animation(cn).loop_mode = Animation.LOOP_LINEAR
		var first: String = str(_clips.get("idle", names[0] if not names.is_empty() else ""))
		if first != "" and _anim.has_animation(first):
			_anim.get_animation(first).loop_mode = Animation.LOOP_LINEAR
			_anim.play(first)
			_gait = first
			_anim.seek(randf(), true)
	return true


static var _fur: ShaderMaterial


## A coat for a body that came without one (see boar_fur.gdshader).
static func _fur_mat() -> ShaderMaterial:
	if _fur == null:
		_fur = ShaderMaterial.new()
		_fur.shader = load("res://world/boar_fur.gdshader")
		for k in [["bristle", 0.35, FastNoiseLite.TYPE_CELLULAR], ["patch", 0.02, FastNoiseLite.TYPE_SIMPLEX_SMOOTH]]:
			var nt := NoiseTexture2D.new()
			var fn := FastNoiseLite.new()
			fn.noise_type = k[2]
			fn.frequency = k[1]
			nt.noise = fn
			nt.seamless = true
			nt.width = 256
			nt.height = 256
			nt.generate_mipmaps = true
			_fur.set_shader_parameter(k[0], nt)
	return _fur


## Plain shapes: a body, a head, legs, and what marks the kind.
func _build() -> void:
	var s: float = spec.size
	var fur := _mat(spec.color)
	var dark := _mat(Color(spec.color).darkened(0.5))
	_body = Node3D.new()
	add_child(_body)
	if _build_real():
		return
	match kind:
		"hare":
			_box(Vector3(0.32, 0.3, 0.55), Vector3(0, 0.32, 0), fur)
			_box(Vector3(0.22, 0.22, 0.24), Vector3(0, 0.46, 0.32), fur)
			for x in [-0.05, 0.05]:
				var ear := _box(Vector3(0.05, 0.28, 0.08), Vector3(x, 0.68, 0.28), fur)
				ear.rotation.x = -0.3
			_box(Vector3(0.1, 0.1, 0.1), Vector3(0, 0.36, -0.3), _mat(Color(0.85, 0.82, 0.76)))
			for z in [0.18, -0.18]:
				for x in [-0.1, 0.1]:
					_legs.append(_box(Vector3(0.07, 0.2, 0.09), Vector3(x, 0.1, z), dark))
		"goat":
			_box(Vector3(0.5, 0.45, 1.0) * s, Vector3(0, 0.85, 0) * s, fur)
			var head := _box(Vector3(0.28, 0.3, 0.42) * s, Vector3(0, 1.18, 0.58) * s, fur)
			head.rotation.x = 0.4
			for x in [-0.1, 0.1]:
				var horn := _box(Vector3(0.06, 0.06, 0.4) * s, Vector3(x, 1.42, 0.42) * s, _mat(Color(0.82, 0.78, 0.68)))
				horn.rotation.x = 0.9
			for z in [0.36, -0.36]:
				for x in [-0.18, 0.18]:
					_legs.append(_box(Vector3(0.1, 0.62, 0.1) * s, Vector3(x, 0.31, z) * s, dark))
		"tusker":
			_box(Vector3(0.75, 0.7, 1.3) * s, Vector3(0, 0.75, 0) * s, fur)
			_box(Vector3(0.5, 0.45, 0.45) * s, Vector3(0, 0.75, 0.82) * s, fur)
			_box(Vector3(0.28, 0.22, 0.12) * s, Vector3(0, 0.66, 1.08) * s, dark)
			for x in [-0.18, 0.18]:
				var tusk := _box(Vector3(0.05, 0.05, 0.3) * s, Vector3(x, 0.62, 1.12) * s, _mat(Color(0.9, 0.88, 0.8)))
				tusk.rotation.x = -0.6
			_box(Vector3(0.12, 0.25, 0.9) * s, Vector3(0, 1.15, 0.05) * s, dark)
			for z in [0.45, -0.45]:
				for x in [-0.25, 0.25]:
					_legs.append(_box(Vector3(0.14, 0.42, 0.14) * s, Vector3(x, 0.21, z) * s, dark))


func is_alive() -> bool:
	return _alive


## Struck by a pilgrim. Here only the host's beast takes the harm; others ask the host.
func hurt(amount: float, dir: Vector3) -> bool:
	if not _alive:
		return false
	if not Net.authority():
		w.shared("_rq_beast_hit", [id, amount, Net.me()])
		_flash()
		return true
	take(amount, Net.me())
	return true


func take(amount: float, by: int) -> void:
	if not _alive:
		return
	hp -= amount
	_flash()
	if spec.has("bite"):
		_rage = 8.0
	else:
		_flee = 8.0
	if hp <= 0.0:
		w.beast_died(self, by)


func _flash() -> void:
	_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
	tw.tween_property(_body, "scale", Vector3.ONE, 0.12)


func die() -> void:
	_alive = false
	collision_layer = 0
	# A body made with its own fall (the tusker's, to one side or the other) plays it; the rest stop where they
	# were, buckle and roll onto their side, a last kick, and lie still to be butchered
	var side := 1.0 if randf() < 0.5 else -1.0
	var own := ""
	if _anim:
		for c in (["Arm_Boar|Death_L", "Arm_Boar|Death_R"] if side > 0.0 else ["Arm_Boar|Death_R", "Arm_Boar|Death_L"]):
			if _anim.has_animation(c):
				own = c
				break
	if own != "":
		_anim.get_animation(own).loop_mode = Animation.LOOP_NONE
		_anim.speed_scale = 1.0
		_anim.play(own, 0.12)
		var tw0 := create_tween()
		tw0.tween_interval(20.0)
		tw0.tween_callback(queue_free)
		return
	if _anim:
		_anim.pause()
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 0.08, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation:z", side * PI / 2, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation:z", side * PI * 0.47, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "rotation:z", side * PI / 2, 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(20.0)
	tw.tween_callback(queue_free)


## Where the host last saw it; others glide toward it.
func net_set(p: Vector3, yaw: float) -> void:
	_net_to = p
	_net_yaw = yaw


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var moving := 0.0
	if not Net.authority():
		var before := global_position
		global_position = global_position.lerp(_net_to, minf(1.0, delta * 6.0))
		rotation.y = lerp_angle(rotation.y, _net_yaw, minf(1.0, delta * 8.0))
		moving = (global_position - before).length() / maxf(delta, 0.001)
	else:
		moving = _think(delta)
	# Legs stride with the pace
	_step += delta * clampf(moving, 0.0, 10.0) * 2.2
	if _anim and not _clips.is_empty():
		# Its own gaits: standing, walking, trotting and running, each at the pace it was made for
		var g: String = _clips.idle if moving < 0.3 else (_clips.walk if moving < 2.5 else (_clips.trot if moving < 5.5 else _clips.run))
		if g != _gait and _anim.has_animation(g):
			_gait = g
			_anim.play(g, 0.25)
		_anim.speed_scale = 1.0 if moving < 0.3 else clampf(moving / (1.3 if g == _clips.walk else (3.8 if g == _clips.trot else 7.0)), 0.6, 1.6)
	elif _anim:
		# Its own gait, quick as it runs; all but still when it stands
		_anim.speed_scale = clampf(moving / maxf(float(spec.walk), 0.5), 0.05, 3.0)
	elif MODELS.has(kind) and _body.get_child_count() == 1:
		# A body without bones bobs with its stride
		_bob += delta * clampf(moving, 0.0, 10.0) * 3.0
		_body.position.y = absf(sin(_bob)) * clampf(moving * 0.02, 0.0, 0.08)
		_body.rotation.x = sin(_bob * 2.0) * clampf(moving * 0.01, 0.0, 0.05)
	for i in _legs.size():
		var lg: MeshInstance3D = _legs[i]
		lg.rotation.x = sin(_step + (PI if i % 2 == 0 else 0.0) + (PI * 0.5 if i >= 2 else 0.0)) * clampf(moving * 0.12, 0.0, 0.7)
	if w.player:
		var near: bool = global_position.distance_to(w.player.global_position) < 14.0
		_label.modulate.a = move_toward(_label.modulate.a, 0.85 if near else 0.0, delta * 2.0)


func _think(delta: float) -> float:
	_flee -= delta
	_rage -= delta
	_bite_cd -= delta
	var p: Node3D = w.nearest_target(global_position)
	var want := Vector3.ZERO
	var speed: float = spec.speed
	if p:
		var to := p.global_position - global_position
		to.y = 0
		var d := to.length()
		if spec.has("bite") and (_rage > 0.0 or d < 5.0):
			# A tusker stands its ground, and runs down what wounds it
			want = to.normalized() * speed * 1.2
			if d < 1.6 * spec.size + 0.4 and _bite_cd <= 0.0:
				_bite_cd = 1.4
				w.hurt_target(p, float(spec.bite), global_position)
		elif float(spec.flee) > 0.0 and (d < float(spec.flee) or _flee > 0.0):
			want = -to.normalized() * speed
			if _flee <= 0.0:
				_flee = 3.0
	if want == Vector3.ZERO:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(2.0, 6.0)
			_wander = Vector3.ZERO if randf() < 0.4 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * float(spec.walk)
		want = _wander
	velocity.x = lerpf(velocity.x, want.x, minf(1.0, delta * 6.0))
	velocity.z = lerpf(velocity.z, want.z, minf(1.0, delta * 6.0))
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.5
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), minf(1.0, delta * 8.0))
	move_and_slide()
	return flat.length()
