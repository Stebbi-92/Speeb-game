class_name Companion
extends Node3D
## Another pilgrim of the fellowship, as seen from here: a figure dressed as they chose, lit faintly in their colour,
## their name carried above them. When fallen they lie still, and may be raised by holding [E] over them.

var peer_id := 0
var downed := false
var hp := 1.0
var _to := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _has_pose := false
var _body: Node3D
var _gun: Node3D
var _gun_model: Node3D
var _gun_key := ""
var _gun_id := ""
var _cat: WCat = null       ## the cat a friend rides, under them
var _ride_key := ""
var _tip := Vector3(0, -0.2, 1.2)
var _label: Label3D
var _lamp: OmniLight3D
var _flash: OmniLight3D
var _area: Area3D
var _fig: Figure
var _look := {}
var _walk := 0.0
var _last := Vector3.ZERO


func setup(id: int) -> Companion:
	peer_id = id
	return self


func _ready() -> void:
	var col: Color = Net.color_of(peer_id)
	_body = Node3D.new()
	add_child(_body)
	# Dressed as they chose to be
	_fig = Figure.new().setup(Net.look_of(peer_id))
	_look = _fig.look.duplicate()
	_body.add_child(_fig)
	Net.roster_changed.connect(_relook)
	# What they carry, held in both hands and raised with their eye
	_gun = Node3D.new()
	_gun.position = Vector3(0, Figure.SHOULDER_Y, 0)
	_body.add_child(_gun)
	_fig.hold = true
	_show_gun("shotgun")
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.75, 0.4)
	_flash.light_energy = 0.0
	_flash.omni_range = 6.0
	_gun.add_child(_flash)
	_place_flash()
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.78, 0.5)
	_lamp.light_energy = 0.0
	_lamp.omni_range = 12.0
	_lamp.position = Vector3(-0.35, 1.0, 0.2)
	_body.add_child(_lamp)
	# A faint light of their own colour, so a companion is never lost in the dark
	var glow := OmniLight3D.new()
	glow.light_color = col
	glow.light_energy = 0.35
	glow.omni_range = 2.5
	glow.position = Vector3(0, 1.9, 0.6)
	_body.add_child(glow)
	for c in find_children("*", "MeshInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_label = Label3D.new()
	_label.text = Net.name_of(peer_id)
	_label.font = load("res://assets/fonts/Marcellus-Regular.ttf")
	_label.font_size = 48
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.modulate = col.lightened(0.3)
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	_label.position.y = 2.25
	add_child(_label)
	# Where a companion may be raised when fallen
	_area = Area3D.new()
	_area.collision_layer = 16
	_area.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.6
	_area.add_child(cs)
	add_child(_area)
	_area.set_meta("prompt", "")
	_area.set_meta("hold", 2.0)
	_area.set_meta("on_interact", func():
		if downed:
			# A land may ask something of the one who raises (smelling salts in the waste)
			var lvl = Game.main.level
			var strength := 0.5
			if lvl and lvl.has_method("raise_strength"):
				strength = lvl.raise_strength(true)
			Net.revive(peer_id, strength)
			Game.main.hud.notify("You raise %s." % Net.name_of(peer_id)))
	visible = false


## data: [position, yaw, pitch, downed, health, relic in hand, armed, lantern lit]
func pose(data: Array) -> void:
	if data.size() < 8:
		return
	_to = data[0]
	_yaw = data[1]
	_pitch = data[2]
	downed = data[3]
	hp = data[4]
	var armed: bool = data[6] and data[5] == "shotgun"
	_gun.visible = armed
	_fig.hold = armed
	_fig.arms_forward = armed or data[5] != ""
	if data.size() > 8:
		# What they have fitted shows too: the same gun with the same sights, grips and magazine
		var mn: Array = (data[9] as Array).slice(0, 8) if data.size() > 9 and data[9] is Array else []
		var key := str(data[8]) + "|" + ",".join(mn)
		if key != _gun_key:
			_gun_key = key
			_show_gun(str(data[8]), mn)
	# Riding: their cat under them, with its face and barding
	# Not riding, their cat waits where they left it, and friends see it there too
	var ride := str(data[10]) if data.size() > 10 else ""
	var bits := ride.split("|")
	var parked := bits.size() >= 7 and bits[2] == "@"
	var key := "|".join(bits.slice(0, 3))
	if key != _ride_key:
		_ride_key = key
		if _cat:
			_cat.queue_free()
			_cat = null
		if ride != "" and bits[0] in WCat.FACES and WCat.BARDING.has(bits[1] if bits.size() > 1 else ""):
			_cat = WCat.new().setup(null, bits[0], false)
			_cat.barding = bits[1] if bits.size() > 1 else ""
			_cat.ridden = not parked
			_cat.puppet = true
			if parked:
				get_parent().add_child(_cat)
			else:
				add_child(_cat)
	if _cat and parked:
		var at := Vector3(float(bits[3]), float(bits[4]), float(bits[5]))
		_cat.global_position = _cat.global_position.lerp(at, 0.5) if _cat.global_position.distance_to(at) < 6.0 else at
		_cat.rotation.y = float(bits[6])
	if _cat and not parked:
		_body.position.y = 0.38
	elif _body.position.y != 0.0:
		_body.position.y = 0.0
	_fig.seated = _cat != null and not parked
	_lamp.light_energy = 2.0 if data[7] else 0.0
	if not _has_pose or global_position.distance_to(_to) > 6.0:
		global_position = _to
		_last = _to
	_has_pose = true
	visible = true
	if downed:
		var lvl = Game.main.level
		if lvl and lvl.has_method("raise_hold"):
			_area.set_meta("hold", lvl.raise_hold())
	# Checked every pose, not only on a change: word of the fall may come before the pose that shows it
	var want := "Raise %s" % Net.name_of(peer_id) if downed else ""
	if str(_area.get_meta("prompt", "")) != want:
		_area.set_meta("prompt", want)
		_label.text = Net.name_of(peer_id) + ("\nfallen" if downed else "")


## Builds the gun they hold, the same shape the holder sees, turned to face the way they face.
func _show_gun(g: String, mn: Array = []) -> void:
	if not ArmsDB.GUNS.has(g):
		return
	_gun_id = g
	if _gun_model:
		_gun_model.queue_free()
	var maker := Arms.new()
	_gun_model = maker._build(g, mn.duplicate())
	maker.free()
	_gun_model.rotation.y = PI
	_gun_model.position = Figure.GRIP - Vector3(0, Figure.SHOULDER_Y, 0) + Vector3(0, 0.06, 0.02)
	_gun.add_child(_gun_model)
	_tip = _gun_model.position + (_gun_model.get_meta("tip") as Vector3) * Vector3(-1, 1, -1)
	for c in _gun_model.find_children("*", "MeshInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_place_flash()


func _place_flash() -> void:
	if _flash:
		_flash.position = _tip


func muzzle() -> void:
	_flash.light_energy = 4.0
	var tw := create_tween()
	tw.tween_property(_flash, "light_energy", 0.0, 0.12)


func muzzle_point() -> Vector3:
	return _flash.global_position


func _process(delta: float) -> void:
	if not _has_pose:
		return
	global_position = global_position.lerp(_to, minf(1.0, delta * 14.0))
	rotation.y = lerp_angle(rotation.y, _yaw + PI, minf(1.0, delta * 14.0))
	_gun.rotation.x = lerpf(_gun.rotation.x, -_pitch, minf(1.0, delta * 10.0))
	_fig.aim = _gun.rotation.x
	var speed := (global_position - _last).length() / maxf(delta, 0.001)
	_last = global_position
	_walk += delta * minf(speed, 6.0) * 2.2
	var lie := 1.0 if downed else 0.0
	_body.rotation.x = lerpf(_body.rotation.x, -PI / 2 * lie, minf(1.0, delta * 5.0))
	_body.position.y = lerpf(_body.position.y, 0.25 * lie, minf(1.0, delta * 5.0))
	if not downed:
		# Riding, they sit up in the saddle, not down inside the cat
		var lift := 0.75 if _cat and _cat.ridden else 0.0
		_body.position.y = lift + absf(sin(_walk)) * 0.04 * clampf(speed / 3.0, 0.0, 1.0) * (0.0 if lift > 0.0 else 1.0)
		_body.rotation.z = sin(_walk * 0.5) * 0.03 * clampf(speed / 3.0, 0.0, 1.0)
	_fig.walk = _walk
	_fig.stride = 0.0 if downed else clampf(speed / 3.0, 0.0, 1.0)


func _relook() -> void:
	var l := Net.look_of(peer_id)
	if l != _look:
		_look = l.duplicate()
		_fig.look = Figure.clean(l)
		_fig.rebuild()


func _exit_tree() -> void:
	# A friend's waiting cat goes with them when they leave
	if _cat and is_instance_valid(_cat) and _cat.get_parent() != self:
		_cat.queue_free()
