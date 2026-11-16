class_name WVaults
extends RefCounted
## The deep vaults: under every sealed vault in the waste, a stair goes down to a few rooms the Order
## cut for its dead, and a keeper at the end. For a fellowship: each room wakes when the living walk in,
## its gate opens when it is quiet again, and the keeper's fall gives every pilgrim below their own share.
## A vault empties for three days, then fills again.

const DEPTH := WHall.DEPTH   ## as deep as the Tenth Hall: the dark, the quiet and the light are the same
const REFILL := 3            ## days before a cleared vault has something in it again
const KEEPERS := ["knight", "colossus", "warden"]

var w
var built := {}      ## ruin id -> {rooms, gates, stair, holder}
var state := {}      ## host: ruin id -> {room (next to wake), foes [], woke}
var _t := 1.0


func _init(world) -> void:
	w = world


func _ruin(id: String) -> Dictionary:
	for r in w.ruins:
		if r.id == id:
			return r
	return {}


## Each sealed vault on the waste gets its stair (far enough from the Tenth Hall to have room below).
func place_stairs() -> void:
	var b8: Vector2 = WPlaces.bpos(8)
	for r in w.ruins:
		if r.kind != "vault" or r.has("isle"):
			continue
		if Vector2(r.pos.x, r.pos.z).distance_to(b8) < 200.0:
			continue
		var id: String = r.id
		var at: Vector3 = r.pos + Vector3(0, 1.4, 0)
		var a: Area3D = w.interact_area(at, 3.2, "Go down into the vault", func(): go_down(id), 0.0, false)
		a.set_meta("prompt", "Go down into the vault")


## The rooms of one vault, in a line from the stair: [middle z, half width, half length]. From its id.
func plan(id: String) -> Array:
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(id) + 77
	var out: Array = []
	var z := 0.0
	var n := 3 + rr.randi() % 2
	for i in n + 1:
		var hw := 7.0 if i == 0 else (13.0 if i == n else rr.randf_range(8.0, 11.0))
		var hl := 6.0 if i == 0 else (13.0 if i == n else rr.randf_range(8.0, 11.0))
		if i > 0:
			z += hl + 6.0   # a corridor of six paces between
		out.append([z, hw, hl])
		z += hl
	return out


func origin(id: String) -> Vector3:
	var r := _ruin(id)
	return Vector3(r.pos.x, DEPTH, r.pos.z)


func at(id: String, x: float, y: float, z: float) -> Vector3:
	return origin(id) + Vector3(x, y, z)


## Everyone builds a vault's rooms the first time someone goes down into it.
func build(id: String) -> void:
	if built.has(id) or _ruin(id).is_empty():
		return
	var holder := Node3D.new()
	holder.position = origin(id)
	w.add_child(holder)
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.13, 0.12, 0.12)
	rock.roughness = 1.0
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.24, 0.22, 0.21)
	stone.roughness = 1.0
	var rooms := plan(id)
	var gates: Array = []
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(id) + 78
	var slab := func(c: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
		var mi: MeshInstance3D = w.box(holder.position + c, size, m, true)
		mi.reparent(holder)
		return mi
	for i in rooms.size():
		var rm: Array = rooms[i]
		var z: float = rm[0]
		var hw: float = rm[1]
		var hl: float = rm[2]
		slab.call(Vector3(0, -0.5, z), Vector3(hw * 2.0, 1, hl * 2.0), rock)
		slab.call(Vector3(0, 7.5, z), Vector3(hw * 2.0 + 2.0, 1, hl * 2.0 + 2.0), rock)
		for sx in [-1.0, 1.0]:
			slab.call(Vector3(sx * (hw + 0.5), 3.5, z), Vector3(1, 8, hl * 2.0 + 2.0), rock)
		# End walls, with a doorway of four paces where a corridor goes on
		for sz in [-1.0, 1.0]:
			var open: bool = (sz < 0 and i > 0) or (sz > 0 and i < rooms.size() - 1)
			var ez: float = z + sz * (hl + 0.5)
			if open:
				for sx in [-1.0, 1.0]:
					var wdt: float = hw - 2.0
					slab.call(Vector3(sx * (2.0 + wdt * 0.5), 3.5, ez), Vector3(wdt + 1.0, 8, 1), rock)
				slab.call(Vector3(0, 5.5, ez), Vector3(4, 4, 1), rock)
			else:
				slab.call(Vector3(0, 3.5, ez), Vector3(hw * 2.0 + 2.0, 8, 1), rock)
		# The corridor on to the next room, and its gate (shut until this room is quiet)
		if i < rooms.size() - 1:
			var cz: float = z + hl + 3.0
			slab.call(Vector3(0, -0.5, cz), Vector3(4, 1, 6), rock)
			slab.call(Vector3(0, 4.0, cz), Vector3(6, 1, 6), rock)
			for sx in [-1.0, 1.0]:
				slab.call(Vector3(sx * 2.5, 1.75, cz), Vector3(1, 4.5, 6), rock)
			var gate: MeshInstance3D = slab.call(Vector3(0, 1.75, z + hl + 1.0), Vector3(4, 3.5, 0.3), stone)
			gate.material_override = _iron()
			gates.append(gate)
		# What the Order left: pillars, coffins, urns, candles
		for k in 4:
			var px := (hw - 2.0) * (1.0 if k % 2 == 0 else -1.0)
			var pz: float = z + (hl - 2.5) * (1.0 if k < 2 else -1.0)
			WIsleLife.put(holder, "grave", "pillar-large", Vector3(px, 0, pz), 0.0, 2.6, true, Vector3.ZERO, stone, 80.0)
		for k in 2 + rr.randi() % 3:
			var kind: String = ["coffin-old", "coffin", "urn-round", "gravestone-broken", "debris"][rr.randi() % 5]
			WDress.kp(holder, "grave", kind, Vector3(rr.randf_range(-hw + 2.5, hw - 2.5), 0, z + rr.randf_range(-hl + 2.5, hl - 2.5)), rr.randf() * TAU, 2.2)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.5)
		l.light_energy = 1.3
		l.omni_range = maxf(hw, hl) * 1.6
		l.position = Vector3(0, 5.0, z)
		holder.add_child(l)
		WDress.kp(holder, "grave", "candle-multiple", Vector3(hw - 1.5, 0, z), 0.0, 2.0)
		WDress.kp(holder, "grave", "candle-multiple", Vector3(-hw + 1.5, 0, z), 0.0, 2.0)
	# The stair up, at the back of the first room; the keeper's altar at the far end
	var first: Array = rooms[0]
	for k in 3:
		WIsleLife.put(holder, "castle", "stairs-stone", Vector3(0, k * 1.5 - 1.0, first[0] - first[2] + 1.2), PI, 2.2, false, Vector3.ZERO, stone, 80.0)
	var up: Area3D = w.interact_area(holder.position + Vector3(0, 1.4, first[0] - first[2] + 2.0), 2.4, "Climb out of the vault", func(): go_up(id), 0.0, false)
	up.set_meta("prompt", "Climb out of the vault")
	var last: Array = rooms[rooms.size() - 1]
	WDress.kp(holder, "grave", "altar-stone", Vector3(0, 0, last[0] + last[2] - 3.0), PI, 2.8, true)
	built[id] = {"rooms": rooms, "gates": gates, "holder": holder}
	# Gates already opened stay open for one coming down late
	var opened := int(w.flags.get("vault_open_" + id, 0))
	for g in mini(opened, gates.size()):
		(gates[g] as Node3D).queue_free()
		gates[g] = null


func _iron() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.2, 0.22)
	m.metallic = 0.8
	m.roughness = 0.5
	return m


func inside(id: String, p: Vector3) -> bool:
	if not built.has(id) or p.y > DEPTH + 60.0:
		return false
	var o := origin(id)
	var rooms: Array = built[id].rooms
	var last: Array = rooms[rooms.size() - 1]
	return absf(p.x - o.x) < 16.0 and p.z > o.z + rooms[0][0] - rooms[0][2] - 2.0 and p.z < o.z + last[0] + last[2] + 2.0


## Which room of the vault this spot is in, or -1.
func room_at(id: String, p: Vector3) -> int:
	if not inside(id, p):
		return -1
	var o := origin(id)
	var rooms: Array = built[id].rooms
	for i in rooms.size():
		var rm: Array = rooms[i]
		if absf(p.z - (o.z + rm[0])) < rm[2] and absf(p.x - o.x) < rm[1]:
			return i
	return -1


# ------------------------------------------------------------------ going down and up

func go_down(id: String) -> void:
	var d := int(w.flags.get("vault_done_" + id, -99))
	if w.day - d < REFILL:
		w.hud.say("The vault is quiet now. Come back in a few days; the dark fills it again.", 4.0)
		return
	w.shared("_w_vault_build", [id])
	var first: Array = plan(id)[0]
	w.player.place(at(id, 0, 0.8, first[0] - first[2] + 4.0), PI)
	w.sfx("whoosh", -10)
	w.hud.say("Stone steps, worn hollow. Below, the Order kept its dead, and something keeps them still.", 4.5)


func go_up(id: String) -> void:
	var r := _ruin(id)
	w.player.place(r.pos + Vector3(4.0, 1.0, 4.0), 0.0)
	w.sfx("whoosh", -10)


# ------------------------------------------------------------------ the host keeps each vault

func host_tick(delta: float) -> void:
	if not Net.authority():
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	for id in built:
		var down: Array = []
		for t in w.targets():
			if inside(id, t.global_position):
				down.append(t)
		if down.is_empty():
			continue
		if not state.has(id):
			state[id] = {"room": 1 if int(w.flags.get("vault_open_" + id, 0)) == 0 else int(w.flags.get("vault_open_" + id, 0)) + 1, "foes": [], "woke": false}
		var st: Dictionary = state[id]
		var rooms: Array = built[id].rooms
		if int(st.room) >= rooms.size():
			continue
		if not st.woke:
			for t in down:
				if room_at(id, t.global_position) == int(st.room):
					_wake(id, st, int(st.room) == rooms.size() - 1)
					break
			continue
		var left := 0
		for e in st.foes:
			if is_instance_valid(e) and e.is_alive():
				left += 1
		if left > 0:
			continue
		# The room is quiet
		st.woke = false
		st.foes = []
		if int(st.room) == rooms.size() - 1:
			st.room = rooms.size()
			var shares: Array = []
			for t in down:
				for pid in w.avatars:
					if w.avatars[pid] == t:
						shares.append(int(pid))
				if t == w.player:
					shares.append(Net.me())
			w.shared("_w_vault_done", [id, w.day, shares])
		else:
			w.shared("_w_vault_gate", [id, int(st.room)])
			st.room = int(st.room) + 1


func _wake(id: String, st: Dictionary, last: bool) -> void:
	st.woke = true
	var rm: Array = built[id].rooms[int(st.room)]
	var roster: Array = w.forms_at(_ruin(id).pos)
	var n: int = WCrowd.scale_near(w, _ruin(id).pos, 3 + int(st.room), 120.0)
	var foes: Array = []
	for k in (2 if last else n):
		var p := at(id, randf_range(-rm[1] + 2.0, rm[1] - 2.0), 1.4, rm[0] + randf_range(0.0, rm[2] - 2.0))
		var e = w.spawn_at(roster[randi() % roster.size()], p)
		if e:
			foes.append(e)
	if last:
		var kind: String = KEEPERS[hash(id) % KEEPERS.size()]
		var e = w.spawn_at(kind, at(id, 0, 1.6, rm[0] + rm[2] - 5.0))
		if e:
			e.hp *= 6.0
			e.max_hp *= 6.0
			w.crowd_great(e)
			foes.append(e)
		w.shared("_w_note", ["The vault's keeper stands up from the altar."])
	st.foes = foes


# ------------------------------------------------------------------ everyone

func open_gate(id: String, room: int) -> void:
	w.flags["vault_open_" + id] = maxi(int(w.flags.get("vault_open_" + id, 0)), room)
	if built.has(id):
		var gates: Array = built[id].gates
		if room - 1 < gates.size() and gates[room - 1] != null and is_instance_valid(gates[room - 1]):
			(gates[room - 1] as Node3D).queue_free()
			gates[room - 1] = null
	if w.player and inside(id, w.player.global_position):
		w.sfx("crumble", -6, w.player.global_position)
		w.hud.notify("The room is quiet. A gate grinds open.")


## The keeper is down: every pilgrim below takes their own share, and the vault sleeps.
func done(id: String, d: int, shares: Array) -> void:
	w.flags["vault_done_" + id] = d
	w.flags.erase("vault_open_" + id)
	state.erase(id)
	if built.has(id):
		var holder: Node3D = built[id].holder
		built.erase(id)
		# Freed once those below have climbed out
		holder.get_tree().create_timer(1.0).timeout.connect(holder.queue_free)
	if Net.me() in shares:
		var rr := RandomNumberGenerator.new()
		rr.randomize()
		var items: Array = Items.roll("vault", 3, rr)
		items.append(["coin", rr.randi_range(3, 7)])
		if rr.randf() < 0.5:
			items.append(["fittings_rare", 1])
		w.give(items)
		w.hud.title_card("The vault is quiet", "Your share of what the Order kept")
		w.award("ruin", 6.0)
		if w.player:
			go_up(id)
