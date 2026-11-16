class_name WEvents
extends Node
## Roaming events: every few minutes something happens somewhere near the fellowship, a short goal
## between the long ones. A caravan cries for help, a star falls, a cache is found, a swarm gathers.
## The host decides where and when; everyone sees it on the compass and shares what it gives.

const EVERY := Vector2(300.0, 540.0)   ## seconds between events (host)
const LAST := 420.0                    ## an event left alone fades after this long
const KINDS := {
	"caravan": {"name": "A caravan under attack", "say": "Shots and screaming: a caravan is under attack", "color": Color(1.0, 0.75, 0.3, 0.2)},
	"star": {"name": "A fallen star", "say": "Something bright fell out of the sky", "color": Color(0.6, 0.85, 1.0, 0.22)},
	"cache": {"name": "A supply cache", "say": "A flare goes up: someone left a cache, and it will not stay hidden long", "color": Color(0.95, 0.4, 0.3, 0.2)},
	"swarm": {"name": "A box cat swarm", "say": "Screaming from the ruins: box cats are gathering", "color": Color(0.85, 0.85, 0.6, 0.2)},
	"camp": {"name": "A raid camp", "say": "Left alone, the raiders dug in: a raid camp", "color": Color(0.9, 0.2, 0.15, 0.24)},
}
const CAMP_LAST := 1200.0   ## a raid camp stays until it is broken, or for twenty minutes
## What each gives every pilgrim near when it is done: [item, low, high].
const GIVES := {
	"caravan": [["salt", 30, 60], ["rounds", 10, 24], ["fittings_fine", 1, 2]],
	"star": [["salt_crystal", 3, 6], ["tempered", 1, 2], ["clockwork", 1, 1]],
	"cache": [["rifle", 20, 40], ["shells", 8, 16], ["bandage", 2, 3], ["oil", 2, 4]],
	"swarm": [["salt", 20, 40], ["meat", 2, 4], ["fittings_fine", 1, 1]],
	"camp": [["salt", 60, 110], ["rounds", 20, 40], ["fittings_fine", 2, 3], ["tempered", 1, 2], ["bandage", 2, 4]],
}

var w
var active := {}      ## id -> {kind, pos, left, node, foes (host), done}
var _next_id := 1
var _t := 200.0       ## the first comes a few minutes in


func setup(lvl) -> WEvents:
	w = lvl
	_t = randf_range(150.0, 240.0)
	return self


## Host: counts down to the next event, keeps each one going, and ends it when it is done.
func host_tick(delta: float) -> void:
	if not w.ready_world:
		return
	_t -= delta
	var cap := 2 if w.targets().size() >= 4 else 1
	if _t <= 0.0:
		_t = randf_range(EVERY.x, EVERY.y)
		if active.values().filter(func(x): return x.kind != "camp").size() < cap:
			_start_one()
	for id in active.keys():
		var e: Dictionary = active[id]
		e.left -= delta
		if e.left <= 0.0:
			w.shared("_w_event_end", [id, false, -1])
			if e.kind in ["caravan", "swarm"] and _alive(e) > 0:
				_dig_in(e.pos)
			continue
		if e.kind in ["caravan", "swarm", "camp"] and e.has("foes") and e.foes.size() > 0:
			if _alive(e) == 0:
				w.shared("_w_event_end", [id, true, -1])


func _alive(e: Dictionary) -> int:
	var n := 0
	for f in e.get("foes", []):
		if is_instance_valid(f) and f.is_alive():
			n += 1
	return n


## Host: an event left alone grows into a raid camp where it was: more of them, an elite at its heart,
## and more to take when it is broken.
func _dig_in(p: Vector3) -> void:
	var nid := _next_id
	w.shared("_w_event_start", [nid, "camp", p])
	_next_id = maxi(_next_id, nid + 1)
	var e: Dictionary = active.get(nid, {})
	if e.is_empty():
		return
	e["foes"] = []
	var roster: Array = w.forms_at(p)
	for k in randi_range(6, 9):
		var f = w._spawn_one(roster[randi() % roster.size()], p, 4.0, 16.0, true)
		if f:
			e.foes.append(f)
	var boss = w._spawn_one("elite", p, 2.0, 6.0, true)
	if boss:
		e.foes.append(boss)


func _start_one() -> void:
	var ts: Array = w.targets()
	if ts.is_empty():
		return
	var t: Node3D = ts[randi() % ts.size()]
	var kinds := KINDS.keys()
	kinds.erase("camp")   # a camp only grows out of an event left alone
	if w.night:
		kinds.erase("star")   # a star is a day's find; the night has enough
	var kind: String = kinds[randi() % kinds.size()]
	for attempt in 30:
		var a := randf() * TAU
		var d := randf_range(140.0, 300.0)
		var x: float = t.global_position.x + cos(a) * d
		var z: float = t.global_position.z + sin(a) * d
		if w.terrain.is_water(x, z, 1.0) or absf(x) > WPlaces.HALF - 30.0 or absf(z) > WPlaces.HALF - 30.0:
			continue
		var p := Vector3(x, w.terrain.height_at(x, z), z)
		if w.safe_at(p) or w.settlement_at(p, 60.0) != "":
			continue
		var nid := _next_id
		w.shared("_w_event_start", [nid, kind, p])
		_next_id = maxi(_next_id, nid + 1)
		var e: Dictionary = active.get(nid, {})
		if e.is_empty():
			return
		e["foes"] = []
		match kind:
			"caravan":
				var roster: Array = w.forms_at(p)
				for k in randi_range(4, 7):
					var f = w._spawn_one(roster[randi() % roster.size()], p, 4.0, 14.0, true)
					if f:
						e.foes.append(f)
			"swarm":
				for k in randi_range(7, 11):
					var f = w._spawn_one("box_cat", p, 3.0, 12.0, true)
					if f:
						e.foes.append(f)
			"star", "cache":
				var roster: Array = w.forms_at(p)
				for k in randi_range(1, 3):
					var f = w._spawn_one(roster[randi() % roster.size()], p, 8.0, 16.0, true)
					if f:
						e.foes.append(f)
		return


## Everyone: the event appears, with its smoke on the horizon and word of it.
func start(id: int, kind: String, p: Vector3) -> void:
	if active.has(id) or not KINDS.has(kind):
		return
	_next_id = maxi(_next_id, id + 1)
	var k: Dictionary = KINDS[kind]
	var n := Node3D.new()
	w.add_child(n)
	n.global_position = p
	var col: MeshInstance3D = w.landmark_column(k.color, 160.0, 0.7)
	col.position = Vector3(0, 80, 0)
	n.add_child(col)
	match kind:
		"caravan":
			_part(n, w.box(Vector3.ZERO, Vector3(2.0, 1.2, 3.6), w._m.darkwood, true), Vector3(0, 1.0, 0), Vector3(0, 0, 0.25))
			for s in [-1, 1]:
				for f in [-1, 1]:
					_part(n, w.cyl(Vector3.ZERO, 0.55, 0.15, w._m.wood, false, -1.0, 10), Vector3(1.05 * s, 0.55, 1.2 * f), Vector3(0, 0, PI * 0.5))
			_part(n, w.box(Vector3.ZERO, Vector3(0.9, 0.7, 0.9), w._m.wood, true), Vector3(2.6, 0.35, 0.8), Vector3.ZERO)
			_part(n, w.box(Vector3.ZERO, Vector3(0.8, 0.6, 0.8), w._m.cloth, true), Vector3(-2.4, 0.3, -1.1), Vector3(0, 0.4, 0))
		"star":
			_part(n, w.cyl(Vector3.ZERO, 4.0, 0.3, w._m.darkstone, false, 3.2, 14), Vector3(0, 0.0, 0), Vector3.ZERO)
			var glow := StandardMaterial3D.new()
			glow.albedo_color = Color(0.7, 0.9, 1.0)
			glow.emission_enabled = true
			glow.emission = Color(0.6, 0.85, 1.0)
			glow.emission_energy_multiplier = 3.0
			_part(n, w.sphere(Vector3.ZERO, 0.9, glow, true, 0.8), Vector3(0, 0.5, 0), Vector3.ZERO)
			var l := OmniLight3D.new()
			l.light_color = Color(0.6, 0.85, 1.0)
			l.light_energy = 2.0
			l.omni_range = 14.0
			l.position = Vector3(0, 1.5, 0)
			n.add_child(l)
		"cache":
			_part(n, w.box(Vector3.ZERO, Vector3(1.2, 0.7, 0.8), w._m.rust, true), Vector3(0, 0.35, 0), Vector3.ZERO)
			_part(n, w.box(Vector3.ZERO, Vector3(1.0, 0.5, 0.7), w._m.cloth, true), Vector3(0.2, 0.95, 0.1), Vector3(0, 0.3, 0))
		"camp":
			for k2 in 3:
				var a := TAU * k2 / 3.0
				_part(n, w.box(Vector3.ZERO, Vector3(2.4, 1.6, 2.4), w._m.cloth, true), Vector3(cos(a) * 6.0, 0.8, sin(a) * 6.0), Vector3(0, a, 0.0))
			for k2 in 6:
				var a := TAU * k2 / 6.0 + 0.3
				_part(n, w.box(Vector3.ZERO, Vector3(0.25, 2.2, 0.25), w._m.darkwood, true), Vector3(cos(a) * 10.0, 1.1, sin(a) * 10.0), Vector3(0.25, a, 0))
			var fire := OmniLight3D.new()
			fire.light_color = Color(1.0, 0.5, 0.2)
			fire.light_energy = 2.5
			fire.omni_range = 16.0
			fire.position = Vector3(0, 1.2, 0)
			n.add_child(fire)
		"swarm":
			for k2 in 5:
				var a := TAU * k2 / 5.0
				_part(n, w.box(Vector3.ZERO, Vector3(0.7, 0.7, 0.7), w._m.cloth, false), Vector3(cos(a) * 3.0, 0.35, sin(a) * 3.0), Vector3(0, a, 0))
	if kind in ["star", "cache"]:
		var eid := id
		var a: Area3D = w.interact_area(p + Vector3(0, 1.0, 0), 2.4, "Take it" if kind == "star" else "Open the cache", func():
			w.shared("_w_event_end", [eid, true, Net.me()]), 0.6, false)
		n.set_meta("area", a)
	active[id] = {"kind": kind, "pos": p, "left": CAMP_LAST if kind == "camp" else LAST, "node": n, "done": false}
	var me: Vector3 = w.player.global_position
	if not Net.dedicated:
		w.hud.notify("%s, %d m %s." % [k.say, int(Vector2(p.x - me.x, p.z - me.z).length()), WPlaces.dir_word(Vector2(me.x, me.z), Vector2(p.x, p.z))])
		w.sfx("bell", -10, null, 1.3)


func _part(n: Node3D, mi: Node3D, at: Vector3, rot: Vector3) -> void:
	mi.reparent(n, false)
	mi.position = at
	mi.rotation = rot


## Everyone: it is done (or it faded). Those near when it was won share what it gives.
func end(id: int, won: bool, by: int) -> void:
	if not active.has(id):
		return
	var e: Dictionary = active[id]
	active.erase(id)
	if is_instance_valid(e.node):
		var a = e.node.get_meta("area") if e.node.has_meta("area") else null
		if a != null and is_instance_valid(a):
			a.queue_free()
		e.node.queue_free()
	if Net.dedicated or not won:
		return
	var near: bool = w.player.global_position.distance_to(e.pos) < 90.0 or by == Net.me()
	if not near:
		return
	var out: Array = []
	for g in GIVES[e.kind]:
		out.append([g[0], randi_range(int(g[1]), int(g[2]))])
	w.give(out)
	w.award("quest", 0.5)
	w.sfx("jingle_find", -6)
	w.hud.notify("%s: done." % KINDS[e.kind].name)


## The nearest event to a place, for What now and the compass; empty if none.
func nearest(p: Vector3) -> Dictionary:
	var best := {}
	var bd := INF
	for id in active:
		var d: float = active[id].pos.distance_to(p)
		if d < bd:
			bd = d
			best = active[id]
	return best
