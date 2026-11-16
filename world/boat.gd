class_name WBoat
extends Node3D
## A boat on the Grey Sea: a raft to paddle, or a sloop that runs before the wind. Whoever takes the
## helm steers it on their own machine and tells the fellowship where it is; the rest ride along.

const KINDS := {
	"raft": {"name": "Raft", "seats": 2, "hp": 160.0, "row": 4.2, "sail": 0.0, "turn": 0.9,
		"text": "Logs lashed together. Paddle it with the walking keys. Slow, and the waves come over it."},
	"sloop": {"name": "Sloop", "seats": 4, "hp": 420.0, "row": 1.8, "sail": 12.0, "turn": 0.55,
		"text": "A small boat with a mast. Raise the sail and run before the wind; steer with the walking keys."},
}
## Where each seat is, on the deck: the helm first
const SEATS := {
	"raft": [Vector3(0, 0.45, -0.9), Vector3(0, 0.45, 0.9)],
	"sloop": [Vector3(0, 0.9, -2.4), Vector3(-0.7, 0.9, 0.2), Vector3(0.7, 0.9, 0.2), Vector3(0, 0.9, 2.0)],
}

var id := 0
var kind := "raft"
var spec: Dictionary
var hp := 100.0
var w   ## the wasteland
var yaw := 0.0
var speed := 0.0
var sail := 0             ## 0 furled, 1 half, 2 full
var riders := {}          ## peer -> seat
var _deck: Node3D
var _sail_n: Node3D
var _body: StaticBody3D
var _net_to := Vector3.ZERO
var _net_yaw := 0.0
var _send_t := 0.0
var _beached := false
var _wake: GPUParticles3D


func setup(lvl, bid: int, k: String) -> WBoat:
	w = lvl
	id = bid
	kind = k
	spec = KINDS[k]
	hp = float(spec.hp)
	return self


func _ready() -> void:
	process_physics_priority = -10   # moves before those aboard read their seats
	_net_to = global_position
	_net_yaw = yaw
	_deck = Node3D.new()
	add_child(_deck)
	if kind == "raft":
		for i in 6:
			var lg = w.cyl(Vector3.ZERO, 0.24, 3.6, w._m.wood, false, -1.0, 8)
			lg.reparent(_deck, false)
			lg.position = Vector3(-1.2 + i * 0.48, 0.15, 0)
			lg.rotation.x = PI * 0.5
		for z in [-1.3, 1.3]:
			var bar = w.box(Vector3.ZERO, Vector3(3.0, 0.12, 0.25), w._m.darkwood, false)
			bar.reparent(_deck, false)
			bar.position = Vector3(0, 0.42, z)
		var oar = w.box(Vector3.ZERO, Vector3(0.1, 0.1, 2.4), w._m.darkwood, false)
		oar.reparent(_deck, false)
		oar.position = Vector3(1.5, 0.5, -0.6)
		oar.rotation.y = 0.2
	else:
		var hull = w.box(Vector3.ZERO, Vector3(2.4, 1.0, 5.4), w._m.darkwood, false)
		hull.reparent(_deck, false)
		hull.position = Vector3(0, 0.1, 0)
		var bow := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(2.4, 1.6, 1.0)
		bow.mesh = pm
		bow.material_override = w._m.darkwood
		_deck.add_child(bow)
		bow.position = Vector3(0, 0.1, 3.2)
		bow.rotation = Vector3(PI * 0.5, 0, 0)
		var deck = w.box(Vector3.ZERO, Vector3(2.2, 0.1, 5.2), w._m.wood, false)
		deck.reparent(_deck, false)
		deck.position = Vector3(0, 0.62, 0)
		for side in [-1.0, 1.0]:
			var rail = w.box(Vector3.ZERO, Vector3(0.12, 0.35, 5.2), w._m.wood, false)
			rail.reparent(_deck, false)
			rail.position = Vector3(side * 1.15, 0.85, 0)
		var mast = w.cyl(Vector3.ZERO, 0.12, 6.5, w._m.darkwood, false, 0.09, 8)
		mast.reparent(_deck, false)
		mast.position = Vector3(0, 3.8, 0.6)
		_sail_n = Node3D.new()
		_deck.add_child(_sail_n)
		_sail_n.position = Vector3(0, 0, 0.6)
		var cloth = w.box(Vector3.ZERO, Vector3(0.04, 4.6, 2.8), w._m.cloth, false)
		cloth.reparent(_sail_n, false)
		cloth.position = Vector3(0, 4.0, -1.4)
		var boom = w.cyl(Vector3.ZERO, 0.07, 3.0, w._m.darkwood, false, -1.0, 6)
		boom.reparent(_sail_n, false)
		boom.position = Vector3(0, 1.6, -1.4)
		boom.rotation.x = PI * 0.5
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.75, 0.45)
		lamp.light_energy = 1.2
		lamp.omni_range = 8.0
		lamp.position = Vector3(0, 2.0, -2.6)
		_deck.add_child(lamp)
	# Something to look at and step aboard by
	_body = StaticBody3D.new()
	_body.collision_layer = 16
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.0, 1.4, 3.8) if kind == "raft" else Vector3(2.6, 1.8, 6.4)
	cs.shape = bs
	cs.position.y = 0.4
	_body.add_child(cs)
	_deck.add_child(_body)
	w.personal_interactable(_body, "", func(): w.boat_used(self), 0.0)
	_refresh_prompt()


## The seat this pilgrim holds aboard, in the world.
func seat_pos(pl: Node3D) -> Vector3:
	var seat := int(riders.get(Net.me(), 0))
	if pl != w.player:
		for p in riders:
			if w.avatars.get(p) == pl:
				seat = int(riders[p])
	var seats: Array = SEATS[kind]
	return _deck.to_global(seats[clampi(seat, 0, seats.size() - 1)]) + Vector3(0, 0.1, 0)


func pilot() -> int:
	for p in riders:
		if int(riders[p]) == 0:
			return int(p)
	return 0


func free_seat() -> int:
	var taken := riders.values()
	for s in int(spec.seats):
		if not s in taken:
			return s
	return -1


func _refresh_prompt() -> void:
	if not is_instance_valid(_body):
		return
	var t := ""
	if riders.has(Net.me()):
		t = "Step off the %s" % str(spec.name).to_lower()
	elif free_seat() == 0:
		t = "Take the helm of the %s" % str(spec.name).to_lower()
	elif free_seat() > 0:
		t = "Climb aboard the %s" % str(spec.name).to_lower()
	_body.set_meta("prompt", t)
	if hp < float(spec.hp) - 1.0 and not riders.has(Net.me()) and t != "":
		_body.set_meta("on_hold", func(): w.mend_boat(self))
		_body.set_meta("hold_prompt", "Mend (4 wood)")
	elif _body.has_meta("on_hold"):
		_body.remove_meta("on_hold")


func set_riders(r: Dictionary) -> void:
	riders = r
	_refresh_prompt()


func _physics_process(delta: float) -> void:
	var sea: WSea = w.sea
	if sea == null:
		return
	if riders.has(Net.me()) and int(riders[Net.me()]) == 0:
		_steer(delta)
		_send_t -= delta
		if _send_t <= 0.0:
			_send_t = 0.12
			w.shared("_w_boat_move", [id, global_position, yaw, speed, sail])
	else:
		# Carried along where its pilot says it is
		global_position = global_position.lerp(_net_to, minf(1.0, delta * 8.0))
		yaw = lerp_angle(yaw, _net_yaw, minf(1.0, delta * 8.0))
	rotation.y = yaw
	# Riding the waves: up and down with them, and tipped by their slope
	var x := global_position.x
	var z := global_position.z
	var h := sea.wave(x, z)
	var f := Vector3(sin(yaw), 0, cos(yaw))
	var r := Vector3(f.z, 0, -f.x)
	var ahead := sea.wave(x + f.x * 2.0, z + f.z * 2.0) - sea.wave(x - f.x * 2.0, z - f.z * 2.0)
	var side := sea.wave(x + r.x * 1.2, z + r.z * 1.2) - sea.wave(x - r.x * 1.2, z - r.z * 1.2)
	_deck.position.y = h - (0.15 if kind == "raft" else 0.35) - global_position.y + WIsles.SEA_Y
	_deck.rotation = Vector3(-atan(ahead / 4.0), 0, atan(side / 2.4) * 0.8)
	if _sail_n:
		# The sail swings to take the wind, and is drawn up when furled
		var rel := wrapf(sea.wind_ang - (PI * 0.5 - yaw), -PI, PI)
		_sail_n.rotation.y = lerp_angle(_sail_n.rotation.y, clampf(-rel * 0.5, -1.2, 1.2), minf(1.0, delta * 2.0))
		_sail_n.scale.y = lerpf(_sail_n.scale.y, [0.15, 0.6, 1.0][sail], minf(1.0, delta * 3.0))


## The helm: forward and back paddle (or raise and lower the sail), left and right turn.
func _steer(delta: float) -> void:
	var sea: WSea = w.sea
	var pl = w.player
	var input := Vector2.ZERO
	if not pl.input_locked and not w.hud.pause_panel.visible:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var want := 0.0
	if float(spec.sail) > 0.0:
		if Input.is_action_just_pressed("move_forward") and not pl.input_locked:
			sail = mini(2, sail + 1)
			w.hud.notify(["The sail is furled.", "Half sail.", "Full sail."][sail])
		if Input.is_action_just_pressed("move_back") and not pl.input_locked:
			sail = maxi(0, sail - 1)
			w.hud.notify(["The sail is furled.", "Half sail.", "Full sail."][sail])
		# Before the wind is fastest; across it, good; into it, barely at all
		var heading := Vector2(sin(yaw), cos(yaw))
		var wind_v := Vector2(cos(sea.wind_ang), sin(sea.wind_ang))
		var catch_k := 0.2 + 0.8 * maxf(0.0, (heading.dot(wind_v) + 0.4) / 1.4)
		want = float(spec.sail) * sail / 2.0 * catch_k * (0.4 + 0.6 * sea.wind) * w.boat_speed_mult()
		if sail == 0:
			want = -input.y * float(spec.row)
	else:
		want = -input.y * float(spec.row) * w.boat_speed_mult()
	speed = lerpf(speed, want, minf(1.0, delta * (0.6 if float(spec.sail) > 0.0 else 1.5)))
	yaw -= input.x * float(spec.turn) * delta * clampf(absf(speed) / 3.0 + 0.4, 0.4, 1.2)
	var f := Vector3(sin(yaw), 0, cos(yaw))
	var next := global_position + f * speed * delta
	# Run aground in the shallows: it stops, and must be backed off or pushed round
	var probe := next + f * signf(speed) * (2.0 if kind == "raft" else 3.2)
	if w.terrain.height_at(probe.x, probe.z) > WIsles.SEA_Y - (0.4 if kind == "raft" else 0.9):
		if not _beached and absf(speed) > 1.5:
			w.hud.notify("You run aground.")
			w.sfx("thud", -6, global_position)
		_beached = true
		speed = 0.0
		return
	_beached = false
	global_position = Vector3(next.x, WIsles.SEA_Y, next.z)


## Where its pilot says it is.
func net_set(p: Vector3, y: float, sp: float, sl: int) -> void:
	_net_to = p
	_net_yaw = y
	speed = sp
	sail = sl
