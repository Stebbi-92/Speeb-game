class_name WBuilder
extends Node3D
## Shelter against the night. Floors and roofs sit on a grid of three paces; walls stand on its edges.
## [B] takes up the work. Click to set a piece, [R] or the wheel to turn or choose it, right click to take one down.

const GRID := 3.0
const REACH := 9.0

var w
var active := false
var sel := 0
var rot := 0
var ghost: Node3D
var ghost_kind := ""
var _plan := {}
var _ok_m: StandardMaterial3D
var _bad_m: StandardMaterial3D
var _hp_send := {}


func _ready() -> void:
	_ok_m = StandardMaterial3D.new()
	_ok_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ok_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ok_m.albedo_color = Color(0.75, 0.9, 0.7, 0.35)
	_bad_m = _ok_m.duplicate()
	_bad_m.albedo_color = Color(1.0, 0.35, 0.3, 0.35)


func kind() -> String:
	return Items.PIECE_ORDER[sel]


func toggle() -> void:
	active = not active
	if not active and ghost:
		ghost.queue_free()
		ghost = null
		ghost_kind = ""
	_hint()


func choose(d: int) -> void:
	sel = posmod(sel + d, Items.PIECE_ORDER.size())
	_hint()


func turn() -> void:
	rot = (rot + 1) % 4


func _hint() -> void:
	if not w.ui:
		return
	if active:
		w.ui.set_build_bar(kind(), sel)
	else:
		w.ui.set_build_bar("", -1)


func _process(_delta: float) -> void:
	if not active or w.player == null:
		return
	var k := kind()
	if ghost_kind != k:
		if ghost:
			ghost.queue_free()
		ghost = _make(k, true)
		add_child(ghost)
		ghost_kind = k
	_plan = _placement(k)
	ghost.visible = not _plan.is_empty()
	if _plan.is_empty():
		return
	ghost.global_position = _plan.pos
	ghost.rotation.y = _plan.yaw
	var ok: bool = _plan.ok and w.stock_has_all(w.skills.cost(Items.PIECES[k].cost))
	for mi in ghost.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _ok_m if ok else _bad_m


## Where a piece would go, if set now.
func _placement(k: String) -> Dictionary:
	var cam: Camera3D = w.player.cam
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [w.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var at: Vector3 = to if hit.is_empty() else hit.position
	if hit.is_empty():
		at.y = w.terrain.height_at(at.x, at.z)
	var ci := floori(at.x / GRID)
	var cj := floori(at.z / GRID)
	var cell_c := Vector3((ci + 0.5) * GRID, 0, (cj + 0.5) * GRID)
	var out := {"ok": true, "kind": k}
	match k:
		"floor", "roof":
			var base := _cell_base(ci, cj)
			if base == INF:
				return {}
			out.pos = Vector3(cell_c.x, base + (3.0 if k == "roof" else 0.0), cell_c.z)
			out.yaw = 0.0
			out.key = "%s:%d:%d" % ["roof" if k == "roof" else "floor", ci, cj]
			if k == "floor" and _floor_top(ci, cj) == INF:
				var hs: Array = []
				for c in [[0, 0], [1, 0], [0, 1], [1, 1]]:
					hs.append(w.terrain.height_at((ci + c[0]) * GRID, (cj + c[1]) * GRID))
				if base < hs.max() - 0.3 or base - hs.min() > 3.0:
					out.ok = false
		"wall", "stonewall", "doorway", "window", "palisade":
			var lx := at.x - cell_c.x
			var lz := at.z - cell_c.z
			var e := Vector3.ZERO
			var yaw := 0.0
			var ek := ""
			if absf(lx) > absf(lz):
				e = cell_c + Vector3(signf(lx) * GRID * 0.5, 0, 0)
				yaw = PI * 0.5
				ek = "v:%d:%d" % [ci + (1 if lx > 0 else 0), cj]
			else:
				e = cell_c + Vector3(0, 0, signf(lz) * GRID * 0.5)
				ek = "h:%d:%d" % [ci, cj + (1 if lz > 0 else 0)]
			var base := _edge_base(e)
			out.pos = Vector3(e.x, base, e.z)
			out.yaw = yaw
			out.key = "edge:" + ek
		"door":
			var pid := _piece_from(hit)
			if pid < 0 or w.pieces[pid].kind != "doorway":
				out.pos = at
				out.yaw = 0.0
				out.ok = false
				out.key = ""
			else:
				out.pos = w.pieces[pid].pos
				out.yaw = w.pieces[pid].yaw
				out.key = "door:%d" % pid
		_:
			var base := at.y
			out.pos = Vector3(snappedf(at.x, 0.5), base, snappedf(at.z, 0.5))
			out.yaw = w.player.yaw + rot * PI * 0.5
			out.key = "free:%d:%d:%s" % [roundi(at.x * 2.0), roundi(at.z * 2.0), k]
	if out.key != "" and _occupied(out.key):
		out.ok = false
	if w.player.global_position.distance_to(out.pos) > REACH + 2.0:
		out.ok = false
	if w.settlement_at(out.pos, 6.0) != "":
		out.ok = false
	for bp in WPlaces.beacon_points():
		if Vector2(out.pos.x, out.pos.z).distance_to(bp) < 14.0:
			out.ok = false
	return out


## A floor held level above falling ground stands on posts down to it.
func _stilts(n: Node3D, p: Vector3) -> void:
	var under := p.y - 1.05
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var x: float = p.x + c.x * (GRID * 0.5 - 0.2)
		var z: float = p.z + c.y * (GRID * 0.5 - 0.2)
		var g: float = w.terrain.height_at(x, z)
		var h := under - g
		if h > 0.05:
			_part(n, null, Vector3(0.22, h + 0.1, 0.22), Vector3(c.x * (GRID * 0.5 - 0.2), -1.05 - h * 0.5, c.y * (GRID * 0.5 - 0.2)), w._m.darkwood, false)


func _cell_base(ci: int, cj: int) -> float:
	var hs: Array = []
	for c in [[0, 0], [1, 0], [0, 1], [1, 1]]:
		hs.append(w.terrain.height_at((ci + c[0]) * GRID, (cj + c[1]) * GRID))
	var fl := _floor_top(ci, cj)
	if fl != INF:
		return fl
	# A floor beside another lies level with it when the ground lets it: it may stand on posts up to
	# three metres over falling ground, and the ground may rise a little above it before it shows
	var top: float = hs.max()
	var low: float = hs.min()
	var best := INF
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]:
		var nb := _floor_top(ci + d[0], cj + d[1])
		if nb != INF and top <= nb + 0.3 and nb - low <= 3.0 and (best == INF or absf(nb - top) < absf(best - top)):
			best = nb
	if best != INF:
		return best
	# Alone, it is raised to the next quarter metre, so floors laid apart still tend to meet level
	return ceilf(top * 4.0) / 4.0


func _slope(ci: int, cj: int) -> float:
	var hs: Array = []
	for c in [[0, 0], [1, 0], [0, 1], [1, 1]]:
		hs.append(w.terrain.height_at((ci + c[0]) * GRID, (cj + c[1]) * GRID))
	return hs.max() - hs.min()


func _floor_top(ci: int, cj: int) -> float:
	for pid in w.pieces:
		var pc: Dictionary = w.pieces[pid]
		if pc.key == "floor:%d:%d" % [ci, cj]:
			return pc.pos.y
	return INF


## A wall stands on the floor beside it if there is one, otherwise on the ground.
func _edge_base(e: Vector3) -> float:
	var best := -INF
	for off in [Vector3(0.75, 0, 0), Vector3(-0.75, 0, 0), Vector3(0, 0, 0.75), Vector3(0, 0, -0.75)]:
		var p: Vector3 = e + off
		var f := _floor_top(floori(p.x / GRID), floori(p.z / GRID))
		if f != INF:
			best = maxf(best, f)
	if best > -INF:
		return best
	return w.terrain.height_at(e.x, e.z)


func _occupied(key: String) -> bool:
	for pid in w.pieces:
		if w.pieces[pid].key == key:
			return true
	return false


func _piece_from(hit: Dictionary) -> int:
	if hit.is_empty():
		return -1
	var c = hit.collider
	if c is Node and c.has_meta("piece"):
		return int(c.get_meta("piece"))
	return -1


func place() -> void:
	if _plan.is_empty() or not _plan.ok:
		w.sfx("deny", -10)
		return
	var k: String = _plan.kind
	var cost: Dictionary = w.skills.cost(Items.PIECES[k].cost)
	if not w.stock_pay(cost):
		w.hud.notify("You lack the makings: %s." % Items.cost_text(cost))
		w.sfx("deny", -10)
		return
	w.sfx("carve", -4, _plan.pos)
	_hint.call_deferred()
	w.shared("_rq_build", [Net.me(), k, _plan.pos, _plan.yaw, w.skills.build_hp_mult()])
	w.award("build")
	if k == "bedroll":
		w.bedroll = _plan.pos
		w.hud.notify("You will wake at this bedroll if you fall.")
		w.autosave_soon(2.0)


func dismantle() -> void:
	var cam: Camera3D = w.player.cam
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_transform.basis.z * REACH, 1 | 16)
	q.exclude = [w.player.get_rid()]
	var pid := _piece_from(get_world_3d().direct_space_state.intersect_ray(q))
	if pid < 0:
		return
	w.shared("_rq_unbuild", [Net.me(), pid])


# ------------------------------------------------------------------ the host decides what stands

func key_of(k: String, p: Vector3, yaw: float) -> String:
	var ci := floori(p.x / GRID)
	var cj := floori(p.z / GRID)
	match k:
		"floor", "roof":
			return "%s:%d:%d" % [k, ci, cj]
		"wall", "stonewall", "doorway", "window", "palisade":
			if absf(sin(yaw)) > 0.5:
				return "edge:v:%d:%d" % [roundi(p.x / GRID), floori(p.z / GRID)]
			return "edge:h:%d:%d" % [floori(p.x / GRID), roundi(p.z / GRID)]
		"door":
			for pid in w.pieces:
				var pc: Dictionary = w.pieces[pid]
				if pc.kind == "doorway" and pc.pos.distance_to(p) < 0.1:
					return "door:%d" % pid
			return "door:?"
	return "free:%d:%d:%s" % [roundi(p.x * 2.0), roundi(p.z * 2.0), k]


func _rq_build(by: int, k: String, p: Vector3, yaw: float, hm := 1.0) -> void:
	if not Net.authority():
		return
	var key := key_of(k, p, yaw)
	if _occupied(key) or key == "door:?" or not Items.PIECES.has(k):
		Net.call_peer(by, "_w_give", [_cost_items(k, 1.0)])
		return
	var pid: int = w.piece_next
	w.piece_next += 1
	w.shared("_w_piece", [pid, k, p, yaw, float(Items.PIECES[k].hp) * clampf(hm, 1.0, 1.6)])
	if k in Wasteland.FIRE_KINDS:
		w.shared("_w_fuel", [pid, w.world_hours() + Wasteland.FUEL_START])
	if k == "chest":
		w.shared("_w_cont", ["p%d" % pid, Inventory.new(16).to_data()])


func _cost_items(k: String, frac: float) -> Array:
	var out: Array = []
	var cost: Dictionary = Items.PIECES[k].cost
	for it in cost:
		var n := int(floor(cost[it] * frac))
		if n > 0:
			out.append([it, n])
	return out


func _rq_unbuild(by: int, pid: int) -> void:
	if not Net.authority() or not w.pieces.has(pid):
		return
	var k: String = w.pieces[pid].kind
	_gone(pid)
	Net.call_peer(by, "_w_give", [_cost_items(k, 0.5)])


func hit_piece(pid: int, dmg: float) -> void:
	if not Net.authority() or not w.pieces.has(pid):
		return
	var pc: Dictionary = w.pieces[pid]
	pc.hp -= dmg
	if pc.hp <= 0.0:
		_gone(pid)
	elif Net.online and Time.get_ticks_msec() - int(_hp_send.get(pid, 0)) > 1000:
		_hp_send[pid] = Time.get_ticks_msec()
		w.shared("_w_piece_hp", [pid, pc.hp])


func _gone(pid: int) -> void:
	var pc: Dictionary = w.pieces[pid]
	var cid := "p%d" % pid
	if w.containers.has(cid):
		var items: Array = []
		for s in w.containers[cid]:
			if s != null:
				items.append(s)
		if not items.is_empty():
			w._rq_satchel(0, pc.pos + Vector3(0, 0.3, 0), items, false)
		w.shared("_w_satchel_gone", [cid])
	# A door goes with its doorway
	for other in w.pieces.keys():
		if w.pieces[other].key == "door:%d" % pid:
			w.shared("_w_piece_gone", [other])
	w.shared("_w_piece_gone", [pid])


# ------------------------------------------------------------------ what everyone sees

func _w_piece(pid: int, k: String, p: Vector3, yaw: float, hp: float) -> void:
	if w.pieces.has(pid):
		return
	var n := _make(k, false)
	add_child(n)
	n.global_position = p
	n.rotation.y = yaw
	w.pieces[pid] = {"kind": k, "pos": p, "yaw": yaw, "hp": hp, "node": n, "key": key_of(k, p, yaw), "open": false, "name": "", "crop": "", "sown": 0.0}
	w.piece_next = maxi(w.piece_next, pid + 1)
	if k == "floor":
		_stilts(n, p)
	for b in n.find_children("*", "StaticBody3D", true, false):
		b.set_meta("piece", pid)
	var body: StaticBody3D = n.get_meta("body")
	match k:
		"door":
			w.personal_interactable(body, "Open the door", func(): w.shared("_rq_door", [pid]))
		"chest":
			w.personal_interactable(body, "Open the chest", func(): w.shared("_rq_open", [Net.me(), "p%d" % pid]))
		"bedroll":
			w.personal_interactable(body, "Lie down (you wake here if you fall)", func():
				w.bedroll = p
				w.ui.ask_rest("bed"))
		"bench":
			w.personal_interactable(body, "Work at the bench", func(): w.ui.open_inventory("arms"))
		"campfire":
			w.personal_interactable(body, "Sit by the fire", func(): w.ui.ask_rest("fire", pid))
		"cookpot":
			w.personal_interactable(body, "Cook", func(): w.ui.open_inventory("craft"))
		"torch":
			w.personal_interactable(body, "Add wood to the torch", func(): w.add_wood(pid))
		"planter":
			w.personal_interactable(body, "Tend the planter", func(): w.ui.open_planter(pid))
		"portal":
			w.personal_interactable(body, "Use the waystone", func(): w.ui.open_portal(pid))


func _w_piece_hp(pid: int, hp: float) -> void:
	if w.pieces.has(pid):
		w.pieces[pid].hp = hp


func _w_piece_gone(pid: int) -> void:
	if not w.pieces.has(pid):
		return
	var pc: Dictionary = w.pieces[pid]
	w.burst(pc.pos + Vector3(0, 1.0, 0), Color(0.45, 0.35, 0.25))
	w.sfx("crumble", -4, pc.pos)
	pc.node.queue_free()
	w.pieces.erase(pid)


func _rq_door(pid: int) -> void:
	if Net.authority() and w.pieces.has(pid):
		w.shared("_w_door", [pid, not w.pieces[pid].open])


func _w_door(pid: int, open: bool) -> void:
	if not w.pieces.has(pid):
		return
	var pc: Dictionary = w.pieces[pid]
	pc.open = open
	var hinge: Node3D = pc.node.get_meta("hinge")
	create_tween().tween_property(hinge, "rotation:y", 1.7 if open else 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	var body: StaticBody3D = pc.node.get_meta("body")
	body.collision_layer = 16 if open else (1 | 16)
	body.set_meta("prompt", "Close the door" if open else "Open the door")
	w.sfx("carve", -10, pc.pos, 0.7)


## The nearest piece of a kind within reach, or -1.
func near_pid(p: Vector3, k: String, r: float) -> int:
	var best := -1
	var bd := r
	for pid in w.pieces:
		var pc: Dictionary = w.pieces[pid]
		if pc.kind == k and pc.pos.distance_to(p) < bd:
			bd = pc.pos.distance_to(p)
			best = pid
	return best


func near_kind(p, k: String, r: float) -> bool:
	if not p is Vector3:
		return false
	for pid in w.pieces:
		var pc: Dictionary = w.pieces[pid]
		if pc.kind == k and pc.pos.distance_to(p) < r:
			return true
	return false


# ------------------------------------------------------------------ the pieces themselves

func _make(k: String, is_ghost: bool) -> Node3D:
	var n := Node3D.new()
	var body := StaticBody3D.new()
	body.collision_layer = 0 if is_ghost else (1 | 16)
	body.collision_mask = 0
	n.add_child(body)
	n.set_meta("body", body)
	var m: Dictionary = w._m
	match k:
		"floor":
			_part(n, body, Vector3(GRID, 1.2, GRID), Vector3(0, -0.45, 0), m.wood, is_ghost)
		"roof":
			_part(n, body, Vector3(GRID + 0.2, 0.25, GRID + 0.2), Vector3(0, 0.12, 0), m.thatch, is_ghost)
		"wall":
			_part(n, body, Vector3(GRID, 4.0, 0.3), Vector3(0, 1.0, 0), m.wood, is_ghost)
			for x in [-1.3, 0.0, 1.3]:
				_part(n, null, Vector3(0.18, 4.0, 0.36), Vector3(x, 1.0, 0), m.darkwood, is_ghost)
		"stonewall":
			_part(n, body, Vector3(GRID, 4.0, 0.5), Vector3(0, 1.0, 0), m.stone, is_ghost)
		"doorway":
			_part(n, body, Vector3(0.9, 4.0, 0.3), Vector3(-1.05, 1.0, 0), m.wood, is_ghost)
			_part(n, body, Vector3(0.9, 4.0, 0.3), Vector3(1.05, 1.0, 0), m.wood, is_ghost)
			_part(n, body, Vector3(1.2, 0.8, 0.3), Vector3(0, 2.6, 0), m.wood, is_ghost)
		"door":
			var hinge := Node3D.new()
			hinge.position = Vector3(-0.6, 0, 0)
			n.add_child(hinge)
			n.set_meta("hinge", hinge)
			body.reparent(hinge, false)
			_part(hinge, body, Vector3(1.2, 2.2, 0.12), Vector3(0.6, 1.1, 0), m.darkwood, is_ghost)
			_part(hinge, null, Vector3(0.1, 0.1, 0.2), Vector3(1.05, 1.1, 0.08), m.iron, is_ghost)
		"spikes":
			_part(n, body, Vector3(2.8, 1.4, 0.8), Vector3(0, 0.7, 0), null, is_ghost)
			for i in 6:
				var s := _part(n, null, Vector3(0.12, 2.0, 0.12), Vector3(-1.25 + i * 0.5, 0.7, 0), m.wood, is_ghost)
				s.rotation.x = 0.7 if i % 2 == 0 else -0.7
		"campfire":
			_part(n, body, Vector3(1.2, 0.3, 1.2), Vector3(0, 0.15, 0), m.stone, is_ghost)
			if not is_ghost:
				var e := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.35
				sm.height = 0.5
				e.mesh = sm
				e.material_override = m.ember
				e.position.y = 0.45
				n.add_child(e)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.6, 0.3)
				l.light_energy = 2.2
				l.omni_range = 14.0
				l.shadow_enabled = true
				l.position.y = 1.3
				n.add_child(l)
				n.set_meta("fire", [e, l])
		"cookpot":
			_part(n, body, Vector3(1.4, 0.3, 1.4), Vector3(0, 0.15, 0), m.stone, is_ghost)
			for li in 3:
				var a := li * TAU / 3.0
				var leg := _part(n, null, Vector3(0.08, 1.7, 0.08), Vector3(cos(a) * 0.55, 0.85, sin(a) * 0.55), m.darkwood, is_ghost)
				leg.rotation = Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3)
			_part(n, null, Vector3(0.7, 0.5, 0.7), Vector3(0, 0.85, 0), m.iron, is_ghost)
			_part(n, null, Vector3(0.75, 0.06, 0.75), Vector3(0, 1.12, 0), m.iron, is_ghost)
			if not is_ghost:
				var e := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.3
				sm.height = 0.3
				e.mesh = sm
				e.material_override = m.ember
				e.position.y = 0.38
				n.add_child(e)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.6, 0.3)
				l.light_energy = 1.6
				l.omni_range = 9.0
				l.position.y = 1.0
				n.add_child(l)
				n.set_meta("fire", [e, l])
		"bedroll":
			_part(n, body, Vector3(0.9, 0.18, 2.0), Vector3(0, 0.09, 0), m.cloth, is_ghost)
			_part(n, null, Vector3(0.6, 0.2, 0.35), Vector3(0, 0.2, -0.75), m.cloth, is_ghost)
		"chest":
			_part(n, body, Vector3(1.2, 0.75, 0.75), Vector3(0, 0.38, 0), m.wood, is_ghost)
			_part(n, null, Vector3(1.25, 0.1, 0.8), Vector3(0, 0.78, 0), m.darkwood, is_ghost)
		"bench":
			_part(n, body, Vector3(2.0, 0.15, 1.0), Vector3(0, 0.95, 0), m.wood, is_ghost)
			for x in [-0.85, 0.85]:
				for z in [-0.4, 0.4]:
					_part(n, null, Vector3(0.12, 0.9, 0.12), Vector3(x, 0.45, z), m.darkwood, is_ghost)
			_part(n, null, Vector3(0.4, 0.25, 0.3), Vector3(0.5, 1.15, 0), m.iron, is_ghost)
		"window":
			_part(n, body, Vector3(GRID, 1.3, 0.3), Vector3(0, -0.35, 0), m.wood, is_ghost)
			_part(n, body, Vector3(GRID, 1.3, 0.3), Vector3(0, 2.35, 0), m.wood, is_ghost)
			_part(n, body, Vector3(0.7, 1.4, 0.3), Vector3(-1.15, 1.0, 0), m.wood, is_ghost)
			_part(n, body, Vector3(0.7, 1.4, 0.3), Vector3(1.15, 1.0, 0), m.wood, is_ghost)
			for x in [-1.3, 1.3]:
				_part(n, null, Vector3(0.18, 4.0, 0.36), Vector3(x, 1.0, 0), m.darkwood, is_ghost)
			_part(n, null, Vector3(1.6, 0.1, 0.4), Vector3(0, 0.32, 0), m.darkwood, is_ghost)
		"palisade":
			_part(n, body, Vector3(GRID, 3.6, 0.45), Vector3(0, 1.8, 0), null, is_ghost)
			for i in 7:
				var x := -1.29 + i * 0.43
				var h := 3.6 + (0.25 if i % 2 == 0 else 0.0)
				var post := _cyl(n, 0.2, h, Vector3(x, h * 0.5, 0), m.darkwood if i % 2 else m.wood, is_ghost)
				var tip := _cone(n, 0.2, 0.45, Vector3(x, h + 0.22, 0), m.wood, is_ghost)
				post.rotation.y = i
				tip.rotation.y = i
			_part(n, null, Vector3(GRID, 0.16, 0.12), Vector3(0, 2.6, 0.2), m.iron, is_ghost)
		"stairs":
			var ramp := _part(n, null, Vector3(1.4, 0.2, 4.2), Vector3(0, 1.5, 0), null, is_ghost)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.4, 0.2, 4.4)
			cs.shape = bs
			cs.position = Vector3(0, 1.45, 0)
			cs.rotation.x = atan2(3.0, 3.6)
			if not is_ghost:
				body.add_child(cs)
			if ramp:
				ramp.rotation.x = atan2(3.0, 3.6)
				ramp.visible = is_ghost
			for i in 10:
				_part(n, null, Vector3(1.4, 0.3, 0.38), Vector3(0, 0.15 + i * 0.3, 1.62 - i * 0.36), m.wood, is_ghost)
			for x in [-0.72, 0.72]:
				var rail := _part(n, null, Vector3(0.1, 0.25, 4.6), Vector3(x, 1.6, 0), m.darkwood, is_ghost)
				if rail:
					rail.rotation.x = atan2(3.0, 3.6)
		"torch":
			_part(n, body, Vector3(0.12, 1.7, 0.12), Vector3(0, 0.85, 0), m.darkwood, is_ghost)
			_part(n, null, Vector3(0.2, 0.25, 0.2), Vector3(0, 1.75, 0), m.cloth, is_ghost)
			if not is_ghost:
				var e := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.14
				sm.height = 0.34
				e.mesh = sm
				e.material_override = m.ember
				e.position.y = 1.98
				n.add_child(e)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.62, 0.32)
				l.light_energy = 1.5
				l.omni_range = 9.0
				l.position.y = 2.1
				n.add_child(l)
				n.set_meta("flicker", l)
				n.set_meta("fire", [e, l])
		"planter":
			_part(n, body, Vector3(2.0, 0.5, 1.2), Vector3(0, 0.25, 0), m.darkwood, is_ghost)
			_part(n, null, Vector3(1.8, 0.08, 1.0), Vector3(0, 0.5, 0), m.soil if m.has("soil") else m.darkwood, is_ghost)
			if not is_ghost:
				var crop := Node3D.new()
				crop.position.y = 0.52
				n.add_child(crop)
				n.set_meta("crop", crop)
		"portal":
			for x in [-1.1, 1.1]:
				_part(n, body, Vector3(0.6, 3.6, 0.6), Vector3(x, 1.8, 0), m.stone, is_ghost)
			_part(n, body, Vector3(3.0, 0.6, 0.7), Vector3(0, 3.9, 0), m.stone, is_ghost)
			_part(n, null, Vector3(3.2, 0.3, 1.6), Vector3(0, 0.15, 0), m.stone, is_ghost)
			if not is_ghost:
				var veil := MeshInstance3D.new()
				var qm := QuadMesh.new()
				qm.size = Vector2(1.6, 3.3)
				veil.mesh = qm
				var vm := StandardMaterial3D.new()
				vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				vm.cull_mode = BaseMaterial3D.CULL_DISABLED
				vm.albedo_color = Color(0.55, 0.75, 1.0, 0.0)
				veil.material_override = vm
				veil.position.y = 1.95
				n.add_child(veil)
				n.set_meta("veil", vm)
				var lab := Label3D.new()
				lab.font = load("res://assets/fonts/Marcellus-Regular.ttf")
				lab.font_size = 40
				lab.pixel_size = 0.006
				lab.position = Vector3(0, 4.45, 0)
				lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lab.modulate = Color(0.85, 0.9, 1.0)
				lab.outline_size = 6
				lab.visibility_range_end = 24.0
				n.add_child(lab)
				n.set_meta("label", lab)
				var l := OmniLight3D.new()
				l.light_color = Color(0.6, 0.75, 1.0)
				l.light_energy = 0.0
				l.omni_range = 7.0
				l.position.y = 2.0
				n.add_child(l)
				n.set_meta("light", l)
		"lamp":
			_part(n, body, Vector3(0.2, 3.0, 0.2), Vector3(0, 1.5, 0), m.iron, is_ghost)
			_part(n, null, Vector3(0.35, 0.4, 0.35), Vector3(0, 3.1, 0), m.ember, is_ghost)
			if not is_ghost:
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.75, 0.45)
				l.light_energy = 2.0
				l.omni_range = 16.0
				l.position.y = 3.0
				n.add_child(l)
	return n


func _cyl(n: Node3D, r: float, h: float, pos: Vector3, m: Material, is_ghost: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = m if not is_ghost else _ok_m
	mi.position = pos
	n.add_child(mi)
	return mi


func _cone(n: Node3D, r: float, h: float, pos: Vector3, m: Material, is_ghost: bool) -> MeshInstance3D:
	var mi := _cyl(n, r, h, pos, m, is_ghost)
	(mi.mesh as CylinderMesh).top_radius = 0.0
	return mi


func _part(n: Node3D, body: StaticBody3D, size: Vector3, pos: Vector3, m: Material, is_ghost: bool) -> MeshInstance3D:
	var mi: MeshInstance3D = null
	if m != null or is_ghost:
		mi = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = m if not is_ghost else _ok_m
		mi.position = pos
		if is_ghost:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	if body != null and not is_ghost:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		body.add_child(cs)
	return mi
