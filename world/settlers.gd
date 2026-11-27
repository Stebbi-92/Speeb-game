class_name WSettlers
extends RefCounted
## Wanderers who settle at your fire. A base that is snug (a lit fire, walls, a roof, a light) and has a
## spare bed draws one at dawn, now and then, up to three a fire. Each keeps to a trade and leaves what it
## brings in the base's chest each dawn; the keeper feeds the fires instead. Let the fire die and they go.

const MAX_AT := 3
const GROUND := 40.0      ## a fire's ground, as Wasteland.BASE_SAFE
const SNUG := 4          ## the comfort a base needs before anyone will stay
const CHANCE := 0.5      ## of a wanderer coming, each dawn, to a base with room
const BANNER_DRAW := 0.3  ## more, with a Fellowship Banner up at the fire
const JOBS := {
	"woodcutter": {"name": "woodcutter", "goods": {"wood": 8}, "line": "There's still good timber, if you know where to cut."},
	"salter": {"name": "salt-digger", "goods": {"salt": 12}, "line": "Salt keeps. Salt pays. I dig."},
	"scavenger": {"name": "scavenger", "goods": {"scrap": 4, "cloth": 2}, "line": "The old roads still give, a little at a time."},
	"hunter": {"name": "hunter", "goods": {"hide": 1, "raw_meat": 2}, "line": "Hide and meat. The beasts are thinner every year."},
	"keeper": {"name": "fire-keeper", "goods": {}, "line": "I'll keep the fire. Go on, I've got it."},
}
## What each trade teaches the fellowship when one of its kind settles (a recipe's "needs").
const TEACHES := {"woodcutter": "book_rigging", "salter": "book_salter", "scavenger": "book_gunwright", "hunter": "book_herbal", "keeper": "book_lamp"}
## What each asks for, now and then: [item, how many]. Leave it in the base's chest; at dawn it is taken
## and paid for.
const WANTS := {
	"woodcutter": [["cloth", 4], ["scrap", 3], ["meat", 3]],
	"salter": [["wood", 12], ["cloth", 3], ["bandage", 2]],
	"scavenger": [["oil", 2], ["meat", 4], ["shells", 20]],
	"hunter": [["salt", 20], ["rounds", 30], ["bandage", 2]],
	"keeper": [["wood", 20], ["oil", 2], ["tar", 3]],
}
const PAYS := [["fittings_fine", 1], ["coin", 4], ["tempered", 1], ["clockwork", 1], ["salve", 2]]
const NAMES := ["Oda", "Brann", "Mira", "Tobben", "Selk", "Ivo", "Hesse", "Rook", "Anwen", "Dagny", "Petr", "Ulla", "Corran", "Fenn", "Yrsa", "Malin"]

var w
var list: Array = []     ## {id, fire, job, name, seed}
var _next := 1
var _nodes := {}         ## id -> the figure walking about the base


func _init(world) -> void:
	w = world


## Beds within a fire's ground.
func beds_at(fire: int) -> int:
	var fp: Vector3 = w.pieces[fire].pos
	var n := 0
	for pid in w.pieces:
		var pc: Dictionary = w.pieces[pid]
		if WBuilder.acts(pc.kind) == "bedroll" and Vector2(pc.pos.x, pc.pos.z).distance_to(Vector2(fp.x, fp.z)) < GROUND:
			n += 1
	return n


func at_fire(fire: int) -> Array:
	return list.filter(func(s): return int(s.fire) == fire)


## The chests within a fire's ground.
func chests_at(fire: int) -> Array:
	var fp: Vector3 = w.pieces[fire].pos
	var out: Array = []
	for pid in w.pieces:
		var pc: Dictionary = w.pieces[pid]
		if WBuilder.acts(pc.kind) == "chest" and Vector2(pc.pos.x, pc.pos.z).distance_to(Vector2(fp.x, fp.z)) < GROUND and w.containers.has("p%d" % pid):
			out.append("p%d" % pid)
	return out


## Room for one more at this fire: a bed spare beyond the pilgrim's own, and a snug enough place.
func room_at(fire: int) -> bool:
	if not w.pieces.has(fire) or w.pieces[fire].kind != "campfire" or not w.burning(fire):
		return false
	var n := at_fire(fire).size()
	return n < MAX_AT and beds_at(fire) - 1 > n and w.comfort(w.pieces[fire].pos) >= SNUG


## The host, each dawn: the settled go about their trades, and a wanderer may come.
func host_dawn(chance := CHANCE) -> void:
	if not Net.authority():
		return
	for s in list.duplicate():
		var fire := int(s.fire)
		if not w.pieces.has(fire) or not w.burning(fire):
			w.shared("_w_settler_gone", [int(s.id), "%s has gone. The fire was cold." % s.name])
			continue
		_work(s)
		_want_dawn(s)
	for pid in w.pieces.keys():
		# A banner within the fire's ground is seen from far off: a wanderer is likelier to come
		if room_at(pid) and randf() < (chance + BANNER_DRAW if w.builder.near_kind(w.pieces[pid].pos, "banner", GROUND) else chance):
			var job: String = JOBS.keys()[randi() % JOBS.size()]
			var nm: String = NAMES[randi() % NAMES.size()]
			var wl: Array = WANTS[job]
			w.shared("_w_settler", [{"id": _next, "fire": pid, "job": job, "name": nm, "seed": randi(), "want": wl[randi() % wl.size()]}])


## A settler's want: if what they asked for is in the base's chests at dawn, they take it and pay,
## and ask for something else.
func _want_dawn(s: Dictionary) -> void:
	var want = s.get("want")
	if not want is Array or want.size() < 2:
		# One who came before settlers asked for things: give them something to ask for
		var wl0: Array = WANTS[s.job]
		w.shared("_w_settler_paid", [int(s.id), "", 0, wl0[randi() % wl0.size()]])
		return
	var cids := chests_at(int(s.fire))
	var id := str(want[0])
	var n := int(want[1])
	var have := 0
	for cid in cids:
		for it in w.containers[cid]:
			if it != null and it[0] == id:
				have += int(it[1])
	if have < n:
		return
	for cid in cids:
		var data: Array = w.containers[cid]
		for i in data.size():
			if n > 0 and data[i] != null and data[i][0] == id:
				var t := mini(n, int(data[i][1]))
				data[i][1] = int(data[i][1]) - t
				n -= t
				if int(data[i][1]) <= 0:
					data[i] = null
		w.shared("_w_cont", [cid, data])
	var pay: Array = PAYS[randi() % PAYS.size()]
	_put(cids, str(pay[0]), int(pay[1]))
	var wl: Array = WANTS[s.job]
	var next: Array = wl[randi() % wl.size()]
	w.shared("_w_settler_paid", [int(s.id), str(pay[0]), int(pay[1]), next])


## What this settler asks for now, in words, or "".
static func want_text(s: Dictionary) -> String:
	var want = s.get("want")
	if not want is Array or want.size() < 2:
		return ""
	return "%s the %s asks for %d %s. Leave it in your base's chest; it is taken and paid for at dawn." % [s.name, JOBS[s.job].name, int(want[1]), Items.iname(str(want[0])).to_lower()]


func _work(s: Dictionary) -> void:
	var fire := int(s.fire)
	if s.job == "keeper":
		for pid in w.pieces:
			var pc: Dictionary = w.pieces[pid]
			if pc.kind in ["campfire", "cookpot", "stove"] and pc.pos.distance_to(w.pieces[fire].pos) < GROUND and w.fuel_left(pid) < 48.0:
				w._rq_fuel(pid, 2)
		return
	var cids := chests_at(fire)
	if cids.is_empty():
		return
	var goods: Dictionary = JOBS[s.job].goods
	for id in goods:
		_put(cids, id, int(goods[id]))


## Into the first chest with room.
func _put(cids: Array, id: String, n: int) -> void:
	var stack := Items.stack_of(id)
	for cid in cids:
		var data: Array = w.containers[cid]
		for i in data.size():
			if n <= 0:
				break
			if data[i] != null and data[i][0] == id and int(data[i][1]) < stack:
				var t := mini(n, stack - int(data[i][1]))
				data[i][1] = int(data[i][1]) + t
				n -= t
		for i in data.size():
			if n <= 0:
				break
			if data[i] == null:
				var t := mini(n, stack)
				data[i] = [id, t]
				n -= t
		w.shared("_w_cont", [cid, data])
		if n <= 0:
			return


## Everyone: one more at the fire.
func add(s: Dictionary) -> void:
	for o in list:
		if int(o.id) == int(s.id):
			return
	list.append(s)
	_next = maxi(_next, int(s.id) + 1)
	_show(s)


func remove(id: int) -> void:
	list = list.filter(func(s): return int(s.id) != id)
	if _nodes.has(id) and is_instance_valid(_nodes[id]):
		_nodes[id].queue_free()
	_nodes.erase(id)


func _show(s: Dictionary) -> void:
	if Net.dedicated or not w.pieces.has(int(s.fire)):
		return
	var fp: Vector3 = w.pieces[int(s.fire)].pos
	var f := WTownsfolk.new().setup(w, fp + Vector3(2.5, 0, 2.5), 7.0, int(s.seed))
	f.lines = ["I'm %s. I'm the %s here now." % [s.name, JOBS[s.job].name], JOBS[s.job].line]
	var want = s.get("want")
	if want is Array and want.size() >= 2:
		f.lines.append("If you've %d %s to spare, leave it in the chest. I'll make it worth your while." % [int(want[1]), Items.iname(str(want[0])).to_lower()])
	w.add_child(f)
	f.global_position = Vector3(fp.x + 2.5, w.terrain.height_at(fp.x + 2.5, fp.z + 2.5), fp.z + 2.5)
	_nodes[int(s.id)] = f


func to_data() -> Array:
	return list


func from_data(d) -> void:
	for id in _nodes.keys():
		remove(id)
	list = []
	if not d is Array:
		return
	for s in d:
		if s is Dictionary and JOBS.has(str(s.get("job", ""))):
			var one := {"id": int(s.id), "fire": int(s.fire), "job": str(s.job), "name": str(s.name), "seed": int(s.get("seed", 0))}
			if s.get("want") is Array:
				one["want"] = (s.want as Array).duplicate()   # what they asked for is kept, and joiners see it too
			add(one)
