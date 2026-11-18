class_name WBoat
extends Node3D
## A boat on the Grey Sea: a raft to paddle, or a sloop that runs before the wind. Whoever takes the
## helm steers it on their own machine and tells the fellowship where it is; the rest ride along.

const KINDS := {
	"raft": {"name": "Raft", "seats": 2, "hp": 160.0, "row": 4.2, "sail": 0.0, "turn": 0.9,
		"text": "Logs lashed together. Paddle it with the walking keys. Slow, and the waves come over it."},
	"sloop": {"name": "Sloop", "seats": 4, "hp": 420.0, "row": 1.8, "sail": 12.0, "turn": 0.55,
		"text": "A small boat with a mast. Raise the sail and run before the wind; steer with the walking keys."},
	"longboat": {"name": "Longboat", "seats": 8, "hp": 640.0, "row": 2.4, "sail": 10.5, "turn": 0.42,
		"text": "A long boat with oars and a mast, for a whole fellowship. Slower to turn than a sloop."},
}
## Where each seat is, on the deck: the helm first
const SEATS := {
	"raft": [Vector3(0, 0.45, -0.9), Vector3(0, 0.45, 0.9)],
	"sloop": [Vector3(0, 0.9, -2.4), Vector3(-0.7, 0.9, 0.2), Vector3(0.7, 0.9, 0.2), Vector3(0, 0.9, 2.0)],
	"longboat": [Vector3(0, 0.9, -3.9), Vector3(-0.7, 0.9, -2.2), Vector3(0.7, 0.9, -2.2), Vector3(-0.7, 0.9, -0.6),
		Vector3(0.7, 0.9, -0.6), Vector3(-0.7, 0.9, 1.6), Vector3(0.7, 0.9, 1.6), Vector3(0, 0.9, 3.3)],
}

## What each seat is for. The helm steers; the sail-hand works the sail and trims it to run faster;
## the lookout calls what moves on the water; the gunner shoots harder from the swivel; each oar adds
## to the rowing. One pilgrim can sail a boat alone, but a full crew sails it best.
const STATIONS := {
	"raft": ["helm", "paddle"],
	"sloop": ["helm", "sail", "lookout", "gun"],
	"longboat": ["helm", "sail", "lookout", "gun", "oar", "oar", "oar", "oar"],
}
const STATION_TEXT := {
	"sail": "You work the sail: [%s] raises it, [%s] lowers it. Trimmed by your hand it runs a quarter faster.",
	"lookout": "You keep the lookout. You will see what moves on the water long before the others, and call it.",
	"gun": "You hold the swivel. Your shots strike a third harder from here.",
	"oar": "You take an oar. Each oar manned makes the rowing faster.",
	"paddle": "You take the second paddle. Two paddle faster than one.",
}
const TRIM := 1.25          ## sail speed with a sail-hand at it
const GUN_MULT := 1.33      ## the gunner's harm at the swivel
const OAR_ADD := 0.22       ## rowing speed added by each manned oar (or second paddle)

var id := 0
var kind := "raft"
const RAFT := "res://assets/models/boats/raft.glb"
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
var lamp_lit := true      ## a lit lamp at sea by night draws the Lamp-Eater up from the deep
var _lamp: OmniLight3D


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
	if kind == "raft" and ResourceLoader.exists(RAFT):
		# "Wooden Raft - Low Poly" by Le Moustick (CC-BY 4.0), its mast and sail left ashore: this raft is paddled
		var m: Node3D = (load(RAFT) as PackedScene).instantiate()
		for n in m.find_children("*", "", true, false):
			if n.name.begins_with("Mast") or n.name.begins_with("Sail"):
				n.get_parent().remove_child(n)
				n.queue_free()
		var bb := AABB()
		var first := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = WTrees._chain(mi, m) * (mi as MeshInstance3D).get_aabb()
			bb = a if first else bb.merge(a)
			first = false
		var long := maxf(bb.size.x, bb.size.z)
		var k := 3.8 / maxf(long, 0.001)
		var turn := 0.0 if bb.size.z >= bb.size.x else PI * 0.5
		var c := bb.get_center()
		m.transform = Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * k), Basis(Vector3.UP, turn) * Vector3(-c.x * k, -bb.end.y * k + 0.45, -c.z * k))
		_deck.add_child(m)
		var oar = w.box(Vector3.ZERO, Vector3(0.1, 0.1, 2.4), w._m.darkwood, false)
		oar.reparent(_deck, false)
		oar.position = Vector3(1.5, 0.5, -0.6)
		oar.rotation.y = 0.2
	elif kind == "raft":
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
		var k := 1.6 if kind == "longboat" else 1.0   # the longboat is the sloop drawn out
		var hull = w.box(Vector3.ZERO, Vector3(2.4, 1.0, 5.4 * k), w._m.darkwood, false)
		hull.reparent(_deck, false)
		hull.position = Vector3(0, 0.1, 0)
		var bow := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(2.4, 1.6, 1.0)
		bow.mesh = pm
		bow.material_override = w._m.darkwood
		_deck.add_child(bow)
		bow.position = Vector3(0, 0.1, 2.7 * k + 0.5)
		bow.rotation = Vector3(PI * 0.5, 0, 0)
		var deck = w.box(Vector3.ZERO, Vector3(2.2, 0.1, 5.2 * k), w._m.wood, false)
		deck.reparent(_deck, false)
		deck.position = Vector3(0, 0.62, 0)
		for side in [-1.0, 1.0]:
			var rail = w.box(Vector3.ZERO, Vector3(0.12, 0.35, 5.2 * k), w._m.wood, false)
			rail.reparent(_deck, false)
			rail.position = Vector3(side * 1.15, 0.85, 0)
			if kind == "longboat":
				for i in 4:
					var oar = w.box(Vector3.ZERO, Vector3(2.2, 0.08, 0.1), w._m.darkwood, false)
					oar.reparent(_deck, false)
					oar.position = Vector3(side * 2.0, 0.55, -2.6 + i * 1.6)
					oar.rotation.z = side * 0.35
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
		_lamp = OmniLight3D.new()
		_lamp.light_color = Color(1.0, 0.75, 0.45)
		_lamp.light_energy = 1.2
		_lamp.omni_range = 8.0
		_lamp.position = Vector3(0, 2.0, -2.6 * k)
		_deck.add_child(_lamp)
		_lamp.visible = lamp_lit
	# Something to look at and step aboard by
	_body = StaticBody3D.new()
	_body.collision_layer = 16
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.0, 1.4, 3.8) if kind == "raft" else Vector3(2.6, 1.8, 10.0 if kind == "longboat" else 6.4)
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


## The station a pilgrim holds aboard ("" if not aboard).
func station_of(peer: int) -> String:
	if not riders.has(peer):
		return ""
	var st: Array = STATIONS.get(kind, ["helm"])
	var seat := int(riders[peer])
	return str(st[seat]) if seat < st.size() else "seat"


## How many pilgrims hold this station.
func manned(station: String) -> int:
	var n := 0
	for p in riders:
		if station_of(int(p)) == station:
			n += 1
	return n


## The next free seat after this pilgrim's own, round the boat (never the helm), or -1.
func next_free_after(seat: int) -> int:
	var taken := riders.values()
	var n := int(spec.seats)
	for k in range(1, n):
		var s := (seat + k) % n
		if s != 0 and not s in taken:
			return s
	return -1


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
	elif riders.has(Net.me()) and int(riders[Net.me()]) != 0 and next_free_after(int(riders[Net.me()])) > 0:
		var to := next_free_after(int(riders[Net.me()]))
		_body.set_meta("on_hold", func(): w.shared("_rq_station", [id, Net.me(), to]))
		_body.set_meta("hold_prompt", "Move to the %s" % str(STATIONS[kind][to]))
	elif riders.has(Net.me()) and _lamp != null:
		_body.set_meta("on_hold", func(): w.shared("_w_boat_lamp", [id, not lamp_lit]))
		_body.set_meta("hold_prompt", "Douse the lamp" if lamp_lit else "Light the lamp")
	elif _body.has_meta("on_hold"):
		_body.remove_meta("on_hold")


func set_lamp(on: bool) -> void:
	lamp_lit = on
	if _lamp:
		_lamp.visible = on
	_refresh_prompt()


## Whether this boat shows a light on the water.
func shows_light() -> bool:
	return _lamp != null and lamp_lit


func set_riders(r: Dictionary) -> void:
	riders = r
	_refresh_prompt()


func _physics_process(delta: float) -> void:
	var sea: WSea = w.sea
	if sea == null:
		return
	if station_of(Net.me()) == "sail":
		_work_sail()
	elif station_of(Net.me()) == "lookout":
		_look_out(delta)
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
	var hand := manned("sail") > 0     # a sail-hand has the sail: the helm only steers
	var rowing := 1.0 + OAR_ADD * (manned("oar") + manned("paddle"))
	if float(spec.sail) > 0.0:
		if Input.is_action_just_pressed("move_forward") and not pl.input_locked and not hand:
			sail = mini(2, sail + 1)
			w.hud.notify(["The sail is furled.", "Half sail.", "Full sail."][sail])
		if Input.is_action_just_pressed("move_back") and not pl.input_locked and not hand:
			sail = maxi(0, sail - 1)
			w.hud.notify(["The sail is furled.", "Half sail.", "Full sail."][sail])
		# Before the wind is fastest; across it, good; into it, barely at all
		var heading := Vector2(sin(yaw), cos(yaw))
		var wind_v := Vector2(cos(sea.wind_ang), sin(sea.wind_ang))
		var catch_k := 0.2 + 0.8 * maxf(0.0, (heading.dot(wind_v) + 0.4) / 1.4)
		want = float(spec.sail) * sail / 2.0 * catch_k * (0.4 + 0.6 * sea.wind) * w.boat_speed_mult() * (TRIM if hand else 1.0)
		if sail == 0:
			want = -input.y * float(spec.row) * rowing
	else:
		want = -input.y * float(spec.row) * w.boat_speed_mult() * rowing
	speed = lerpf(speed, want, minf(1.0, delta * (0.6 if float(spec.sail) > 0.0 else 1.5)))
	yaw -= input.x * float(spec.turn) * delta * clampf(absf(speed) / 3.0 + 0.4, 0.4, 1.2)
	var f := Vector3(sin(yaw), 0, cos(yaw))
	var next := global_position + f * speed * delta
	# Run aground in the shallows: it stops, and must be backed off or pushed round
	var probe := next + f * signf(speed) * (2.0 if kind == "raft" else (5.0 if kind == "longboat" else 3.2))
	if w.terrain.height_at(probe.x, probe.z) > WIsles.SEA_Y - (0.4 if kind == "raft" else 0.9):
		if not _beached and absf(speed) > 1.5:
			w.hud.notify("You run aground.")
			w.sfx("thud", -6, global_position)
		_beached = true
		speed = 0.0
		return
	_beached = false
	global_position = Vector3(next.x, WIsles.SEA_Y, next.z)


## The sail-hand raises and lowers the sail and tells the fellowship (the helm takes it up).
func _work_sail() -> void:
	if float(spec.sail) <= 0.0 or w.player.input_locked or w.hud.pause_panel.visible:
		return
	var to := sail
	if Input.is_action_just_pressed("move_forward"):
		to = mini(2, sail + 1)
	if Input.is_action_just_pressed("move_back"):
		to = maxi(0, sail - 1)
	if to != sail:
		w.shared("_w_boat_sail", [id, to])


func sail_set(to: int) -> void:
	sail = clampi(to, 0, 2)
	if riders.has(Net.me()) and station_of(Net.me()) in ["helm", "sail"]:
		w.hud.notify(["The sail is furled.", "Half sail.", "Full sail."][sail])


var _look_t := 0.0
var _called := {}
const LOOK_FAR := 280.0    ## how far the lookout sees what moves on the water

## The lookout sees every form near the boat long before the others, and calls it with where it lies.
func _look_out(delta: float) -> void:
	_look_t -= delta
	if _look_t > 0.0:
		return
	_look_t = 2.0
	var f := Vector3(sin(yaw), 0, cos(yaw))
	for e in w.enemies:
		if not is_instance_valid(e) or not e.is_alive() or _called.has(e.get_instance_id()):
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		if d.length() > LOOK_FAR or d.length() < 25.0:
			continue
		_called[e.get_instance_id()] = true
		w.shared("_w_lookout", [id, e.global_position, str(e.spec.name), bearing(f, d)])
		return


## Where a thing lies from the boat, in a sailor's words.
static func bearing(f: Vector3, d: Vector3) -> String:
	var a := rad_to_deg(Vector2(f.x, f.z).angle_to(Vector2(d.x, d.z)))
	if absf(a) < 30.0:
		return "dead ahead"
	if absf(a) > 150.0:
		return "astern"
	var side := "starboard" if a > 0.0 else "port"   # facing +z, starboard lies toward -x
	return ("off the %s bow" if absf(a) < 90.0 else "off the %s quarter") % side


## Where its pilot says it is.
func net_set(p: Vector3, y: float, sp: float, sl: int) -> void:
	_net_to = p
	_net_yaw = y
	speed = sp
	if manned("sail") == 0 or station_of(Net.me()) != "sail":
		sail = sl
