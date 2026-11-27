class_name WBuilder
extends Node3D
## Shelter against the night. Floors and roofs sit on a grid of three paces; walls stand on its edges.
## [B] takes up the work. Click to set a piece, [R] or the wheel to turn or choose it, right click to take one down.

const GRID := 3.0
const REACH := 9.0
const KIT := "res://assets/models/build/"
## Walls from Kenney's Fantasy Town Kit: [timber, stone]. Iron is the stone wall bound in iron.
const KIT_WALLS := {"wall": ["wall-wood", "wall"], "window": ["wall-wood-window-shutters", "wall-window-shutters"],
	"doorway": ["wall-wood-doorway-square", "wall-doorway-square"]}
## Furniture from Kenney's Furniture Kit: [model, scale]
const KIT_HOME := {"bed": ["fu-bedSingle", 1.3], "table": ["fu-table", 2.3], "chair": ["fu-chair", 2.1], "shelf": ["fu-bookcaseOpen", 2.3],
	"stove": ["fu-kitchenStove", 2.2], "rug": ["fu-rugRectangle", 1.9], "floorlamp": ["fu-lampRoundFloor", 2.1],
	# Camp pieces from Kenney's Survival Kit ("sv-" is that kit's folder)
	"chest": ["sv-chest", 3.1], "bench": ["sv-workbench", 4.5], "bedroll": ["sv-bedroll", 3.3],
	"tent": ["sv-tent-canvas", 5.4], "barrel": ["sv-barrel", 3.5], "anvil": ["sv-workbench-anvil", 4.0],
	# Later pieces: the Survival Kit's iron-bound box, the Castle Kit's long banner, the Pirate Kit's lookout ("is-" is isles/)
	"strongbox": ["sv-box-large", 3.2], "banner": ["is-castle/flag-banner-long", 1.5], "watchtower": ["is-pirate/tower-watch", 1.5]}
const KIT_SV := "res://assets/models/survival/"
const KIT_IS := "res://assets/models/isles/"
## Building up: timber, then stone, iron and blackglass (see WBuildTiers.MATERIALS for costs and what opens each).
const UPGRADES := ["wall", "window", "doorway", "floor"]
## Furniture that does the work of a camp piece
const ACTS := {"bed": "bedroll", "stove": "cookpot", "shelf": "chest", "floorlamp": "lamp", "tent": "bedroll", "barrel": "chest", "anvil": "bench",
	"strongbox": "chest", "brazier": "lamp", "lamppost": "lamp", "banner": "table"}
## A watchtower marks the foes within this reach of it for anyone near its foot; a barricade cuts what presses on it.
const WATCH_REACH := 60.0
const WATCH_NEAR := 40.0
const BARRICADE_BITE := 30.0


static func acts(k: String) -> String:
	return ACTS.get(k, k)

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
	if not active and w.ui:
		w.ui.set_upgrade_tip("", 0)
	_hint()


func choose(d: int) -> void:
	sel = step(sel, d)
	_hint()


## The next piece along that this world may build (the wheel passes over what is still barred).
func step(from: int, d: int) -> int:
	var n: int = Items.PIECE_ORDER.size()
	var i := from
	for _k in n:
		i = posmod(i + (1 if d >= 0 else -1), n)
		if WBuildTiers.open(w, Items.PIECE_ORDER[i]):
			return i
	return from


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
	# Aimed at a wall or floor: what building it up gives and costs, under the crosshair
	var ap := aimed()
	if ap >= 0 and w.pieces[ap].kind in UPGRADES:
		w.ui.set_upgrade_tip(w.pieces[ap].kind, int(w.pieces[ap].get("tier", 0)))
	else:
		w.ui.set_upgrade_tip("", 0)
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


## The later pieces at work, twice a second: a watchtower marks the foes about it for anyone near its
## foot (each player's own sight), and the host's barricades cut what presses on them.
var _work_t := 0.0

func _physics_process(delta: float) -> void:
	_work_t -= delta
	if _work_t > 0.0 or w == null or w.get("pieces") == null:
		return
	_work_t = 0.5
	var me: Vector3 = w.player.global_position if w.player and not Net.dedicated else Vector3.INF
	for pid in w.pieces:
		var pc: Dictionary = w.pieces[pid]
		if pc.kind == "watchtower" and me != Vector3.INF and me.distance_to(pc.pos) < WATCH_NEAR:
			for e in w.enemies:
				if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(pc.pos) < WATCH_REACH:
					e.reveal(0.8)
		elif pc.kind == "barricade" and Net.authority():
			var along := Vector3(cos(pc.yaw), 0, -sin(pc.yaw))
			for e in w.enemies:
				if not is_instance_valid(e) or not e.is_alive():
					continue
				var d: Vector3 = e.global_position - pc.pos
				d.y = 0.0
				if absf(d.dot(along)) < GRID * 0.5 + 0.4 and (d - along * d.dot(along)).length() < 1.6:
					e.hurt(BARRICADE_BITE * 0.5, Vector3.ZERO)


## Whether a station of one of these kinds stands within a few steps (measured flat, as a bench is).
func at_station(p: Vector3, kinds: Array) -> bool:
	for pid in w.pieces:
		var q: Vector3 = w.pieces[pid].pos
		if w.pieces[pid].kind in kinds and Vector2(q.x - p.x, q.z - p.z).length() < 6.5 and absf(q.y - p.y) < 4.0:
			return true
	return false


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
		"wall", "stonewall", "doorway", "window", "palisade", "barricade":
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
	var barred := WBuildTiers.why(w, k)
	if barred != "":
		w.hud.notify("The %s is not yet yours to build. %s." % [Items.PIECES[k].name, barred])
		w.sfx("deny", -10)
		return
	var cost: Dictionary = w.skills.cost(Items.PIECES[k].cost)
	# Quick Camp: once a night a campfire is laid for nothing
	if acts(k) == "campfire" and w.skills.has_boon("quick_camp") and not w.quick_camp_spent:
		cost = {}
		w.quick_camp_spent = true
		w.hud.notify("Quick Camp: a fire laid in a breath. Again tomorrow night.")
	if not w.stock_pay(cost):
		w.hud.notify("You lack the makings: %s." % Items.cost_text(cost))
		w.sfx("deny", -10)
		return
	w.sfx("carve", -4, _plan.pos)
	_hint.call_deferred()
	w.shared("_rq_build", [Net.me(), k, _plan.pos, _plan.yaw, w.skills.build_hp_mult(), cost])
	w.award("build")
	if acts(k) == "bedroll":
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


## The built piece in sight and within reach, or -1.
func aimed() -> int:
	var cam: Camera3D = w.player.cam
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_transform.basis.z * REACH, 1 | 16)
	q.exclude = [w.player.get_rid()]
	var pid := _piece_from(get_world_3d().direct_space_state.intersect_ray(q))
	return pid if w.pieces.has(pid) else -1


## Builds the wall or floor in sight up a tier: timber to stone, stone to iron. False if nothing is in sight.
func upgrade() -> bool:
	var pid := aimed()
	if pid < 0:
		return false
	upgrade_pid(pid)
	return true


## Builds one piece up a step, if the world has opened that step and the makings are carried. True if it was paid for.
func upgrade_pid(pid: int) -> bool:
	var pc: Dictionary = w.pieces[pid]
	var mats: Array = WBuildTiers.MATERIALS
	if not pc.kind in UPGRADES:
		w.hud.notify("Only walls, windows, doorways and floors can be built up.")
		return false
	var t := int(pc.get("tier", 0))
	if t >= mats.size() - 1:
		w.hud.notify("It is %s already: it can be built up no further." % str(mats[t].name).to_lower())
		return false
	var barred := WBuildTiers.material_why(w, t + 1)
	if barred != "":
		w.hud.notify("%s comes later. %s." % [mats[t + 1].name, barred])
		w.sfx("deny", -10)
		return false
	var cost: Dictionary = w.skills.cost(mats[t + 1].cost)
	if not w.stock_pay(cost):
		w.hud.notify("To build it up to %s: %s." % [str(mats[t + 1].name).to_lower(), Items.cost_text(cost)])
		w.sfx("deny", -10)
		return false
	w.sfx("crumble" if t == 0 else "mag_in", -4, pc.pos)
	w.shared("_rq_tier", [Net.me(), pid, t + 1, cost])
	w.award("build")
	return true


func _rq_tier(by: int, pid: int, t: int, paid = null) -> void:
	if not Net.authority():
		return
	var mats: Array = WBuildTiers.MATERIALS
	if not w.pieces.has(pid) or int(w.pieces[pid].get("tier", 0)) != t - 1 or t >= mats.size():
		Net.call_peer(by, "_w_give", [_refund(mats[clampi(t, 1, mats.size() - 1)].cost, paid)])
		return
	var k: String = w.pieces[pid].kind
	w.shared("_w_tier", [pid, t, float(Items.PIECES[k].hp) * float(mats[t].hp)])


## A piece rebuilt in its new tier, where it stood.
func _w_tier(pid: int, t: int, hp: float) -> void:
	if not w.pieces.has(pid):
		return
	var pc: Dictionary = w.pieces[pid]
	pc.tier = t
	pc.hp = hp
	var old: Node3D = pc.node
	var n := _make(pc.kind, false, t)
	add_child(n)
	n.global_position = pc.pos
	n.rotation.y = pc.yaw
	pc.node = n
	if pc.kind == "floor":
		_stilts(n, pc.pos)
	for b in n.find_children("*", "StaticBody3D", true, false):
		b.set_meta("piece", pid)
	old.queue_free()


# ------------------------------------------------------------------ the host decides what stands

func key_of(k: String, p: Vector3, yaw: float) -> String:
	var ci := floori(p.x / GRID)
	var cj := floori(p.z / GRID)
	match k:
		"floor", "roof":
			return "%s:%d:%d" % [k, ci, cj]
		"wall", "stonewall", "doorway", "window", "palisade", "barricade":
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


func _rq_build(by: int, k: String, p: Vector3, yaw: float, hm := 1.0, paid = null) -> void:
	if not Net.authority():
		return
	var key := key_of(k, p, yaw)
	if _occupied(key) or key == "door:?" or not Items.PIECES.has(k):
		if Items.PIECES.has(k):
			Net.call_peer(by, "_w_give", [_refund(Items.PIECES[k].cost, paid)])
		return
	var pid: int = w.piece_next
	w.piece_next += 1
	w.shared("_w_piece", [pid, k, p, yaw, float(Items.PIECES[k].hp) * clampf(hm, 1.0, 1.6)])
	if k in Wasteland.FIRE_KINDS:
		w.shared("_w_fuel", [pid, w.world_hours() + Wasteland.FUEL_START])
	if acts(k) == "chest":
		w.shared("_w_cont", ["p%d" % pid, Inventory.new(int(Items.PIECES[k].get("slots", 16))).to_data()])


## What goes back for a build the host turned down: what was paid (a skill may have made it less), never more than it costs.
func _refund(cost: Dictionary, paid) -> Array:
	var out: Array = []
	for it in cost:
		var n := int(cost[it])
		if paid is Dictionary:
			n = mini(n, int((paid as Dictionary).get(it, 0)))
		if n > 0:
			out.append([it, n])
	return out


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
			w._rq_satchel(0, pc.pos + Vector3(0, 0.3, 0), items, false, "", true)   # a chest's goods are never blown away
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
	match acts(k):
		"door":
			w.personal_interactable(body, "Open the door", func(): w.shared("_rq_door", [pid]))
		"chest":
			w.personal_interactable(body, "Open the shelf" if k == "shelf" else "Open the chest", func(): w.shared("_rq_open", [Net.me(), "p%d" % pid]))
		"bedroll":
			w.personal_interactable(body, "Lie down in the bed" if k == "bed" else "Lie down", func():
				# One owned by another may be rested in, but it is not yours to wake in
				if w.bed_mine_or_free(pid):
					w.bedroll = p
				w.ui.ask_rest("bed", pid))
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
		"shrine":
			w.personal_interactable(body, "Kneel at the shrine", func(): w.ui.open_shrine(pid))
		"trophy_hall":
			w.personal_interactable(body, "Look at the trophies", func(): w.ui.open_hall(pid))


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
		if acts(pc.kind) == k and pc.pos.distance_to(p) < bd:
			bd = pc.pos.distance_to(p)
			best = pid
	return best


func near_kind(p, k: String, r: float) -> bool:
	if not p is Vector3:
		return false
	for pid in w.pieces:
		var pc: Dictionary = w.pieces[pid]
		if (pc.kind == k or acts(pc.kind) == k) and pc.pos.distance_to(p) < r:
			return true
	return false


# ------------------------------------------------------------------ the pieces themselves

## footing: walls carry a footing below their line, for the ground; an upper storey's walls stand on a floor and have none.
func _make(k: String, is_ghost: bool, tier := 0, footing := true) -> Node3D:
	var n := Node3D.new()
	var body := StaticBody3D.new()
	body.collision_layer = 0 if is_ghost else (1 | 16)
	body.collision_mask = 0
	n.add_child(body)
	n.set_meta("body", body)
	var m: Dictionary = w._m
	if KIT_WALLS.has(k):
		_kit_wall(n, body, k, tier, is_ghost, footing)
		return n
	if KIT_HOME.has(k):
		_kit_home(n, body, k, is_ghost)
		return n
	match k:
		"floor":
			var fm: Material = [m.wood, m.stone, m.iron, _bound(3)][clampi(tier, 0, 3)]
			_part(n, body, Vector3(GRID, 1.2, GRID), Vector3(0, -0.45, 0), fm if tier > 0 or is_ghost else m.darkwood, is_ghost)
			if tier == 0 and not is_ghost:
				_kit(n, "planks", Vector3(GRID, 1.0, GRID), Vector3(0, 0.12, 0), 0.0)
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
			# Sized to the kit doorway's own opening (1.2 wide, 2.25 high), with a finger's gap round it
			hinge.position = Vector3(-0.59, 0, 0)
			n.add_child(hinge)
			n.set_meta("hinge", hinge)
			body.reparent(hinge, false)
			_part(hinge, body, Vector3(1.18, 2.23, 0.12), Vector3(0.59, 1.115, 0), m.darkwood, is_ghost)
			_part(hinge, null, Vector3(0.1, 0.1, 0.2), Vector3(1.03, 1.05, 0.08), m.iron, is_ghost)
		"spikes":
			_part(n, body, Vector3(2.8, 1.4, 0.8), Vector3(0, 0.7, 0), null, is_ghost)
			for i in 6:
				var s := _part(n, null, Vector3(0.12, 2.0, 0.12), Vector3(-1.25 + i * 0.5, 0.7, 0), m.wood, is_ghost)
				s.rotation.x = 0.7 if i % 2 == 0 else -0.7
		"campfire":
			_part(n, body, Vector3(1.2, 0.3, 1.2), Vector3(0, 0.15, 0), null if not is_ghost else m.stone, is_ghost)
			if not is_ghost:
				var pit := _kit(n, "sv-campfire-pit", Vector3.ONE * 4.3, Vector3.ZERO, 0.0)
				var pab := _local_aabb(pit)
				pit.position = Vector3(-pab.get_center().x, -pab.position.y, -pab.get_center().z)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.6, 0.3)
				l.light_energy = 2.2
				l.omni_range = 14.0
				l.shadow_enabled = true
				l.position.y = 1.3
				n.add_child(l)
				var e := WFire.make(1.1, true, true).with_light(l)
				e.position.y = 0.25
				n.add_child(e)
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
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.6, 0.3)
				l.light_energy = 1.6
				l.omni_range = 9.0
				l.position.y = 1.0
				n.add_child(l)
				var e := WFire.make(0.6, true, false).with_light(l)
				e.position.y = 0.28
				n.add_child(e)
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
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.62, 0.32)
				l.light_energy = 1.5
				l.omni_range = 9.0
				l.position.y = 2.1
				n.add_child(l)
				var e := WFire.make(0.55, true, false).with_light(l)
				e.position.y = 1.82
				n.add_child(e)
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
		"trophy_hall":
			# A timber back wall under a little roof, with five plaques; the hung trophies glow on them
			_part(n, body, Vector3(4.2, 3.0, 0.4), Vector3(0, 1.5, -0.6), m.wood if not is_ghost else null, is_ghost)
			_part(n, null, Vector3(4.6, 0.2, 1.4), Vector3(0, 3.1, -0.2), m.wood if not is_ghost else null, is_ghost)
			_part(n, null, Vector3(4.4, 0.3, 1.2), Vector3(0, 0.15, -0.2), m.stone if not is_ghost else null, is_ghost)
			if not is_ghost:
				var marks: Array = []
				for i in 5:
					var x := -1.6 + i * 0.8
					_part(n, null, Vector3(0.6, 0.7, 0.08), Vector3(x, 1.8, -0.38), m.stone, false)
					var gem := MeshInstance3D.new()
					var sm := SphereMesh.new()
					sm.radius = 0.16
					sm.height = 0.32
					gem.mesh = sm
					gem.position = Vector3(x, 1.8, -0.28)
					gem.visible = false
					n.add_child(gem)
					marks.append(gem)
				n.set_meta("marks", marks)
				var hl := OmniLight3D.new()
				hl.light_color = Color(0.95, 0.75, 0.45)
				hl.light_energy = 0.0
				hl.omni_range = 5.0
				hl.position = Vector3(0, 2.4, 0.4)
				n.add_child(hl)
				n.set_meta("light", hl)
		"brazier":
			# Coals in an iron basket on a stone plinth: no wood wanted, and a ward like a torch's
			_part(n, body, Vector3(0.9, 1.0, 0.9), Vector3(0, 0.5, 0), m.stone, is_ghost)
			if not is_ghost:
				_kit(n, "is-grave/fire-basket", Vector3.ONE * 2.6, Vector3(0, 1.0, 0), 0.0)
				_fire(n, Vector3(0, 1.3, 0), 1.8, 12.0)
		"lamppost":
			_part(n, body, Vector3(0.3, 3.0, 0.3), Vector3(0, 1.5, 0), null, is_ghost)
			if is_ghost:
				_part(n, null, Vector3(0.2, 3.0, 0.2), Vector3(0, 1.5, 0), m.iron, true)
			else:
				_kit(n, "is-grave/lightpost-single", Vector3.ONE * 2.4, Vector3.ZERO, 0.0)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.78, 0.5)
				l.light_energy = 2.2
				l.omni_range = 18.0
				l.position = Vector3(0, 2.7, 0.55)
				n.add_child(l)
		"barricade":
			# Kenney's fortified fence: three paces of stakes bound in iron, on a floor's edge
			_part(n, body, Vector3(GRID, 3.0, 0.45), Vector3(0, 1.5, 0), null, is_ghost)
			if is_ghost:
				_part(n, null, Vector3(GRID, 3.0, 0.3), Vector3(0, 1.5, 0), m.wood, true)
			else:
				_kit(n, "sv-fence-fortified", Vector3(GRID / 0.5, 5.8, 6.0), Vector3.ZERO, 0.0)
				_part(n, null, Vector3(GRID, 1.0, 0.4), Vector3(0, -0.5, 0), m.darkwood, false)
		"shrine":
			_part(n, body, Vector3(2.2, 1.2, 1.4), Vector3(0, 0.6, 0), null, is_ghost)
			if is_ghost:
				_part(n, null, Vector3(2.2, 1.0, 1.4), Vector3(0, 0.5, 0), m.stone, true)
				_part(n, null, Vector3(0.6, 2.6, 0.6), Vector3(0, 1.3, -0.9), m.stone, true)
			else:
				var alt: Node3D = load("res://assets/models/isles/grave/altar-stone.glb").instantiate()
				alt.scale = Vector3.ONE * 2.1
				n.add_child(alt)
				var ob: Node3D = load("res://assets/models/isles/grave/pillar-obelisk.glb").instantiate()
				ob.scale = Vector3.ONE * 2.6
				ob.position = Vector3(0, 0, -1.0)
				n.add_child(ob)
				var l := OmniLight3D.new()
				l.light_color = Color(0.95, 0.7, 0.4)
				l.light_energy = 1.2
				l.omni_range = 6.0
				l.position.y = 1.6
				n.add_child(l)
	return n


## A kit model set into a piece: scaled, turned and placed. From iron up (tier 2 and over), the
## material it is built up in binds it all over.
func _kit(n: Node3D, model: String, scale: Vector3, pos: Vector3, yaw: float, tier := 0) -> Node3D:
	var path := KIT + model
	if model.begins_with("sv-"):
		path = KIT_SV + model.substr(3)
	elif model.begins_with("is-"):
		path = KIT_IS + model.substr(3)
	var sc: PackedScene = load(path + ".glb")
	var inst: Node3D = sc.instantiate()
	inst.scale = scale
	inst.rotation.y = yaw
	inst.position = pos
	n.add_child(inst)
	if model.begins_with("sv-") or model.begins_with("is-"):
		_weather_kit(inst)
	if tier >= 2:
		var im := _bound(tier)
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = im
	return inst


## One shared material for each binding (iron, blackglass), so every piece built up draws with it.
var _bound_m := {}
func _bound(tier: int) -> Material:
	if not _bound_m.has(tier):
		var im: StandardMaterial3D = (w._m.iron as StandardMaterial3D).duplicate()
		im.metallic = 0.7
		im.roughness = 0.45
		if tier >= 3:
			# Blackglass: basalt glass set in the stone, dark and glossy, with a faint ember in it
			im.albedo_color = Color(0.09, 0.08, 0.1)
			im.metallic = 0.35
			im.roughness = 0.12
			im.emission_enabled = true
			im.emission = Color(0.35, 0.12, 0.05)
			im.emission_energy_multiplier = 0.15
		_bound_m[tier] = im
	return _bound_m[tier]


## The Survival Kit is painted bright; out in the waste its wood and canvas are worn grey-brown.
static var _worn := {}
static func _weather_kit(inst: Node3D) -> void:
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var m := mesh.surface_get_material(si)
			if not m is StandardMaterial3D:
				continue
			if not _worn.has(m):
				var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_color = d.albedo_color * Color(0.62, 0.56, 0.5)
				d.roughness = 0.95
				_worn[m] = d
			(mi as MeshInstance3D).set_surface_override_material(si, _worn[m])


## A wall, window or doorway of the kit: three paces wide and three high on its footing, timber or stone.
## The kit's wall stands along the edge of its square, so it is turned to lie along x and drawn in to the middle.
func _kit_wall(n: Node3D, body: StaticBody3D, k: String, tier: int, is_ghost: bool, footing := true) -> void:
	var m: Dictionary = w._m
	var model: String = KIT_WALLS[k][0 if tier == 0 else 1]
	_kit(n, model, Vector3.ONE * GRID, Vector3(0, 0, GRID * 0.45), PI * 0.5, tier)
	# A footing below the ground line, for walls on a slope
	var foot: Material = [m.darkwood, m.stone, m.iron, _bound(3)][clampi(tier, 0, 3)]
	if not is_ghost:
		if footing:
			_part(n, null, Vector3(GRID, 1.0, 0.34), Vector3(0, -0.5, 0), foot, false)
		match k:
			"wall":
				_part(n, body, Vector3(GRID, 4.0, 0.3), Vector3(0, 1.0, 0), null, false)
			# The openings match the kit's: a door 1.05 wide and 2.05 high, a window at chest height
			"doorway":
				_part(n, body, Vector3(0.975, 4.0, 0.3), Vector3(-1.0125, 1.0, 0), null, false)
				_part(n, body, Vector3(0.975, 4.0, 0.3), Vector3(1.0125, 1.0, 0), null, false)
				_part(n, body, Vector3(1.05, 0.95, 0.3), Vector3(0, 2.525, 0), null, false)
			"window":
				_part(n, body, Vector3(GRID, 1.84, 0.3), Vector3(0, -0.08, 0), null, false)
				_part(n, body, Vector3(GRID, 0.96, 0.3), Vector3(0, 2.52, 0), null, false)
				_part(n, body, Vector3(1.12, 1.2, 0.3), Vector3(-0.94, 1.44, 0), null, false)
				_part(n, body, Vector3(1.12, 1.2, 0.3), Vector3(0.94, 1.44, 0), null, false)


## Furniture of the kit, set in the middle of where it is placed, with a box to bump into.
func _kit_home(n: Node3D, body: StaticBody3D, k: String, is_ghost: bool) -> void:
	var s: float = KIT_HOME[k][1]
	var inst := _kit(n, KIT_HOME[k][0], Vector3.ONE * s, Vector3.ZERO, 0.0)
	var ab := _local_aabb(inst)
	inst.position = Vector3(-ab.get_center().x, -ab.position.y, -ab.get_center().z)
	if not is_ghost:
		# A rug's box stays flat: a ledge a hand high in the middle of a floor stops a pilgrim dead
		var tall := 0.02 if k == "rug" else maxf(ab.size.y, 0.12)
		_part(n, body, Vector3(maxf(ab.size.x, 0.3), tall, maxf(ab.size.z, 0.3)), Vector3(0, tall * 0.5, 0), null, false)
		if k == "stove":
			_fire(n, Vector3(0, ab.size.y * 0.75, 0), 1.3, 8.0)
		elif k == "floorlamp":
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.78, 0.5)
			l.light_energy = 1.6
			l.omni_range = 10.0
			l.position.y = ab.size.y * 0.9
			n.add_child(l)


## The glow of a stove: an ember and a light, lit while wood burns (see Wasteland.burning).
func _fire(n: Node3D, at: Vector3, energy: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = energy
	l.omni_range = reach
	l.position = at + Vector3(0, 0.3, 0)
	n.add_child(l)
	var e := WFire.make(0.3, false, false).with_light(l)
	e.position = at - Vector3(0, 0.1, 0)
	n.add_child(e)
	n.set_meta("fire", [e, l])


## The bounds of a model's meshes, in its parent's space.
func _local_aabb(inst: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var nd: Node = mi
		while nd != inst.get_parent() and nd is Node3D:
			t = (nd as Node3D).transform * t
			nd = nd.get_parent()
		var b: AABB = t * (mi as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


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


# ------------------------------------------------------------------ testing aid

## Testing aid (call=builder.debug_tiers): a new world builds only the first rung; each rung opens with its
## fire or great ones; costs are paid; barred pieces and steps are refused and cost nothing; the new pieces
## stand, do their work and come back through a save.
func debug_tiers() -> void:
	while not w.ready_world:
		await get_tree().create_timer(1.0).timeout
	w.clock = 12.0
	w.lit = []
	w.flags.erase("most_lit")
	for f in w.flags.keys():
		if str(f).begins_with("lair_"):
			w.flags.erase(f)
	w.inv.from_data([])
	var first: Array = WBuildTiers.open_pieces(w)
	var start_ok: bool = first.size() == WBuildTiers.RUNGS[0].pieces.size() and first.all(func(k): return k in WBuildTiers.RUNGS[0].pieces)
	var f: Vector3 = -w.player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var side: Vector3 = f.cross(Vector3.UP)
	var spot := func(i: int, j := 0.0) -> Vector3:
		var p: Vector3 = w.player.global_position + f * (5.0 + j) + side * (i - 4) * 4.2
		p.y = w.terrain.height_at(p.x, p.z)
		return p
	var try := func(k: String, p: Vector3) -> bool:
		var before: int = w.pieces.size()
		_plan = {"ok": true, "kind": k, "pos": p, "yaw": 0.0, "key": key_of(k, p, 0.0)}
		place()
		await get_tree().create_timer(0.2).timeout
		return w.pieces.size() == before + 1
	var pid_of := func(k: String) -> int:   # the newest of a kind
		var best := -1
		for pid in w.pieces:
			if w.pieces[pid].kind == k:
				best = maxi(best, int(pid))
		return best
	# Barred: an anvil on a new world, with all its makings carried, is refused and nothing is taken
	w.give([["scrap", 40], ["red_iron", 20], ["stone", 120], ["wood", 120], ["oil", 6], ["cloth", 20], ["tar", 6], ["salt_crystal", 4], ["obsidian", 8]])
	var scrap0: int = w.inv.count("scrap")
	var refused: bool = not await try.call("anvil", spot.call(0)) and w.inv.count("scrap") == scrap0
	# Open: a chest is built and paid for
	var wood0: int = w.inv.count("wood")
	var built: bool = await try.call("chest", spot.call(1))
	var paid: bool = wood0 - w.inv.count("wood") == int(w.skills.cost(Items.PIECES.chest.cost).wood)
	# A timber wall cannot go up to stone before the first fire
	var ws: Vector3 = spot.call(2, 8.0)
	_rq_build(1, "wall", Vector3(ws.x, ws.y, roundf(ws.z / GRID) * GRID), 0.0)
	await get_tree().create_timer(0.2).timeout
	var wp: int = pid_of.call("wall")
	var stone0: int = w.inv.count("stone")
	var stone_barred: bool = not upgrade_pid(wp) and w.inv.count("stone") == stone0
	# Each fire opens its rung, and with it the next step of building up
	var opened := []
	var made := []
	for fire in [1, 2, 3, 4]:
		w.flags["most_lit"] = fire
		var r: int = fire
		var rung_ok: bool = WBuildTiers.RUNGS[r].pieces.all(func(k): return WBuildTiers.open(w, k))
		var next_shut: bool = r + 1 >= 5 or not WBuildTiers.open(w, WBuildTiers.RUNGS[r + 1].pieces[0])
		opened.append(rung_ok and next_shut)
	w.flags["most_lit"] = 1
	var stone_up: bool = upgrade_pid(wp)
	await get_tree().create_timer(0.2).timeout
	stone_up = stone_up and int(w.pieces[wp].get("tier", 0)) == 1 and w.inv.count("stone") < stone0
	var iron_barred: bool = not upgrade_pid(wp)
	w.flags["most_lit"] = 3
	var iron_up: bool = upgrade_pid(wp)
	await get_tree().create_timer(0.2).timeout
	iron_up = iron_up and int(w.pieces[wp].get("tier", 0)) == 2
	var glass_barred: bool = not upgrade_pid(wp)
	w.flags["most_lit"] = 5
	var obs0: int = w.inv.count("obsidian")
	var glass_up: bool = upgrade_pid(wp)
	await get_tree().create_timer(0.2).timeout
	glass_up = glass_up and int(w.pieces[wp].get("tier", 0)) == 3 and w.inv.count("obsidian") < obs0 and float(w.pieces[wp].hp) > float(Items.PIECES.wall.hp) * 4.0
	# The new pieces, built the way a player builds them
	var news := ["brazier", "strongbox", "watchtower", "banner", "lamppost", "anvil"]
	for i in news.size():
		if await try.call(news[i], spot.call(i, 16.0)):
			made.append(news[i])
	var bs: Vector3 = spot.call(7, 8.0)
	_rq_build(1, "barricade", Vector3(bs.x, bs.y, roundf(bs.z / GRID) * GRID), 0.0)
	await get_tree().create_timer(0.3).timeout
	if pid_of.call("barricade") >= 0:
		made.append("barricade")
	# Their work: a brazier wards spawns, a strongbox holds twenty, an anvil works as a bench
	var bz: int = pid_of.call("brazier")
	var ward: bool = bz >= 0 and w.base_at(w.pieces[bz].pos + Vector3(10, 0, 0)) == bz and w.base_at(w.pieces[bz].pos + Vector3(20, 0, 0)) != bz
	var sb: int = pid_of.call("strongbox")
	var strong: int = w.containers["p%d" % sb].size() if sb >= 0 and w.containers.has("p%d" % sb) else 0
	var anvil: bool = near_kind(w.pieces[pid_of.call("anvil")].pos, "bench", 0.5) if pid_of.call("anvil") >= 0 else false
	# Great ones open the shrine, then the hall
	var great_shut: bool = not WBuildTiers.open(w, "shrine")
	w.flags["lair_ash"] = 1
	var shrine: bool = WBuildTiers.open(w, "shrine") and not WBuildTiers.open(w, "trophy_hall")
	w.flags["lair_dunes"] = 1
	w.flags["lair_salt"] = 1
	var hall: bool = WBuildTiers.open(w, "trophy_hall")
	# Through a save: each new piece comes back where it was, the wall still blackglass
	var d: Dictionary = w.world_data()
	var kinds_before := {}
	for pid in w.pieces:
		kinds_before[pid] = w.pieces[pid].kind
	for pid in w.pieces.keys():
		_w_piece_gone(pid)
	await get_tree().create_timer(0.3).timeout
	for pid in d.pieces:
		var p: Array = d.pieces[pid]
		_w_piece(int(pid), p[0], p[1], p[2], p[3])
		if int(p[5].get("tier", 0)) > 0:
			_w_tier(int(pid), int(p[5].tier), float(p[3]))
	var saved: bool = w.pieces.size() == kinds_before.size() and int(w.pieces[wp].get("tier", 0)) == 3
	for pid in kinds_before:
		saved = saved and w.pieces.has(pid) and w.pieces[pid].kind == kinds_before[pid]
	print("TIERS start=%s first=%d refused=%s built=%s paid=%s stone_barred=%s rungs=%s stone=%s iron_barred=%s iron=%s glass_barred=%s glass=%s made=%d/7 ward=%s strong=%d anvil=%s great=%s shrine=%s hall=%s saved=%s" % [
		start_ok, first.size(), refused, built, paid, stone_barred, opened, stone_up, iron_barred, iron_up, glass_barred, glass_up, made.size(), ward, strong, anvil, great_shut, shrine, hall, saved])
	get_tree().quit()


## Testing aid for screenshots: call=builder.debug_view_menu (a new world's build menu, later rungs greyed),
## builder.debug_view_open (the same after five fires and three great ones), builder.debug_view_pieces (the
## later pieces built in a row before you, with a wall built up in each material).
func debug_view_menu(fires := 0, cat := "Defence") -> void:
	while not w.ready_world:
		await get_tree().create_timer(0.5).timeout
	w.clock = 12.0
	w.flags["most_lit"] = fires
	if fires >= 5:
		for l in ["lair_ash", "lair_dunes", "lair_salt"]:
			w.flags[l] = 1
	w.give([["wood", 60], ["stone", 40], ["scrap", 12], ["cloth", 8]])
	sel = Items.PIECE_ORDER.find("watchtower")
	await get_tree().create_timer(8.0).timeout
	w.ui.open_inventory("build")
	w.ui._bcat = cat
	w.ui._redraw()
	await _snap(0)
	w.ui._bcat = "Camp" if cat != "Camp" else "Defence"
	w.ui._redraw()
	await _snap(1)
	get_tree().quit()


## Testing aid: saves what is on screen as user://shot_<i>.png, after a moment to settle.
func _snap(i: int) -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_%d.png" % i)
	print("snap %d" % i)


func debug_view_open() -> void:
	debug_view_menu(5, "Camp")


func debug_view_pieces() -> void:
	while not w.ready_world:
		await get_tree().create_timer(0.5).timeout
	w.clock = 10.0
	w.flags["most_lit"] = 5
	var f: Vector3 = -w.player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var side: Vector3 = f.cross(Vector3.UP)
	var at := func(a: float, b: float) -> Vector3:
		var p: Vector3 = w.player.global_position + f * b + side * a
		p.y = w.terrain.height_at(p.x, p.z)
		return p
	var row := [["brazier", -6.0, 9.0], ["lamppost", -3.5, 10.0], ["strongbox", -1.0, 8.5], ["banner", 1.0, 9.5], ["anvil", 3.0, 8.5], ["watchtower", 8.0, 15.0]]
	for r in row:
		_rq_build(1, r[0], at.call(r[1], r[2]), atan2(f.x, f.z) + PI)
	# Four timber walls along a line, built up to stone, iron and blackglass, with a barricade beside them
	var yaw := 0.0 if absf(f.z) > absf(f.x) else PI * 0.5
	var wc: Vector3 = at.call(-6.0, 17.0)
	var along := Vector3(1, 0, 0) if yaw == 0.0 else Vector3(0, 0, 1)
	var ci := floori(wc.x / GRID)
	var cj := floori(wc.z / GRID)
	for i in 5:
		var p := Vector3((ci + 0.5) * GRID, 0, cj * GRID) + along * GRID * i if yaw == 0.0 else Vector3(ci * GRID, 0, (cj + 0.5) * GRID) + along * GRID * i
		p.y = w.terrain.height_at(p.x, p.z)
		_rq_build(1, "barricade" if i == 4 else "wall", p, yaw)
	await get_tree().create_timer(0.3).timeout
	var t := 0
	var ids: Array = w.pieces.keys()
	ids.sort()
	for pid in ids:
		if w.pieces[pid].kind == "wall":
			if t > 0:
				_w_tier(pid, t, 900.0)
			t += 1
	for e in w.enemies:
		if is_instance_valid(e):
			e.queue_free()
	await get_tree().create_timer(8.0).timeout
	var c: Vector3 = at.call(0.0, 11.0)
	w.player.place(w.player.global_position - f * 3.0 + Vector3(0, 0.0, 0), atan2(f.x, f.z) + PI)
	w.player.pitch = -0.12
	await _snap(0)
	var eye: Vector3 = c + side * 13.0 - f * 3.0
	eye.y = w.terrain.height_at(eye.x, eye.z) + 0.3
	w.player.place(eye, atan2(-(c - eye).x, -(c - eye).z))
	w.player.pitch = -0.1
	await _snap(1)
	get_tree().quit()
