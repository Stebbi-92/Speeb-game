class_name WSettlers
extends RefCounted
## Wanderers who settle at your fire. A base that is snug (a lit fire, walls, a roof, a light) and has a
## spare bed draws one at dawn, now and then, up to three a fire. Each keeps to a trade and leaves what it
## brings in the base's chest each dawn; the keeper feeds the fires instead. Let the fire die and they go.

const MAX_AT := 3
const GROUND := 40.0      ## a fire's ground, as Wasteland.BASE_SAFE
const SNUG := 4          ## the comfort a base needs before anyone will stay
const CHANCE := 0.5      ## of a wanderer coming, each dawn, to a base with room
const JOBS := {
	"woodcutter": {"name": "woodcutter", "goods": {"wood": 8}, "line": "There's still good timber, if you know where to cut."},
	"salter": {"name": "salt-digger", "goods": {"salt": 12}, "line": "Salt keeps. Salt pays. I dig."},
	"scavenger": {"name": "scavenger", "goods": {"scrap": 4, "cloth": 2}, "line": "The old roads still give, a little at a time."},
	"hunter": {"name": "hunter", "goods": {"hide": 1, "raw_meat": 2}, "line": "Hide and meat. The beasts are thinner every year."},
	"keeper": {"name": "fire-keeper", "goods": {}, "line": "I'll keep the fire. Go on, I've got it."},
}
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
	for pid in w.pieces.keys():
		if room_at(pid) and randf() < chance:
			var job: String = JOBS.keys()[randi() % JOBS.size()]
			var nm: String = NAMES[randi() % NAMES.size()]
			w.shared("_w_settler", [{"id": _next, "fire": pid, "job": job, "name": nm, "seed": randi()}])


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
			add({"id": int(s.id), "fire": int(s.fire), "job": str(s.job), "name": str(s.name), "seed": int(s.get("seed", 0))})
