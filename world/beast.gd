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


## Plain shapes: a body, a head, legs, and what marks the kind.
func _build() -> void:
	var s: float = spec.size
	var fur := _mat(spec.color)
	var dark := _mat(Color(spec.color).darkened(0.5))
	_body = Node3D.new()
	add_child(_body)
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
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", PI / 2, 0.4)
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
