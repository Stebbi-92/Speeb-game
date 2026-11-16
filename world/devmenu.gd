class_name WDev
extends RefCounted
## The hidden playtest menu (Ctrl + F8): jump to any land, town or isle, set the hour and the weather,
## and the tools a tester wants: no harm, a fast stride, a full kit, every weapon, foes of each danger.
## Moving yourself works for anyone; what changes the world is for the host only.

const LANDS := [["ash", "Ash Plains"], ["dunes", "Rust Dunes"], ["forest", "Dead Forest"], ["salt", "Salt Flats"], ["marsh", "Tar Marsh"], ["basalt", "Basalt Heights"]]
const KIT := {"scrap": 200, "wood": 200, "cloth": 100, "bone": 100, "stone": 100, "salt": 200, "oil": 60, "hide": 60, "herb": 60,
	"red_iron": 40, "heartwood": 40, "salt_crystal": 40, "tar": 40, "obsidian": 40, "coin": 100,
	"fittings_fine": 10, "fittings_rare": 6, "fittings_storied": 3}
const AMMO := {"shells": 200, "rounds": 300, "rifle": 400, "rockets": 20, "fuel": 400}

var w
var god := false
var fast := false


func _init(world) -> void:
	w = world


func host() -> bool:
	return Net.authority()


## Every frame while no harm is on: whole, fed and rested.
func tick() -> void:
	if not god or w.player == null:
		return
	w.player.health = w.player.max_health
	w.player.stamina = 100.0
	w.food = 100.0
	w.rest = 100.0


## Where the pilgrim stands, in a line: the land, its danger, the hour and the place.
func where() -> String:
	var p: Vector3 = w.player.global_position
	return "%s, danger %d  ·  day %d, %02d:%02d, %d nights  ·  %s  ·  (%d, %d, %d)" % [
		_land_name(w.land_at(p)), w.tier_at(p), w.day, int(w.clock), int(fmod(w.clock, 1.0) * 60.0),
		w.nights, w.weather.label(), int(p.x), int(p.y), int(p.z)]


func _land_name(k: String) -> String:
	for l in LANDS:
		if l[0] == k:
			return l[1]
	return k if k != "" else "Under the waste"


## The nearest open ground of a land, searched outward from the pilgrim in rings.
func spot_in(land: String) -> Vector3:
	var p: Vector3 = w.player.global_position
	for ring in range(0, 70):
		var r := ring * 40.0
		var n := maxi(1, int(r / 30.0))
		var off := randf() * TAU
		for k in n:
			var a := off + k * TAU / n
			var q := Vector2(p.x + cos(a) * r, p.z + sin(a) * r)
			if absf(q.x) > WPlaces.HALF - 30.0 or absf(q.y) > WPlaces.HALF - 30.0:
				continue
			if w.terrain.biome_name(q.x, q.y) != land or w.terrain.is_water(q.x, q.y, 2.0):
				continue
			# Well inside the land, not on its edge
			if w.terrain.biome_name(q.x + 40.0, q.y) != land or w.terrain.biome_name(q.x - 40.0, q.y) != land:
				continue
			if w.settlement_at(Vector3(q.x, 0, q.y), 20.0) != "":
				continue
			return Vector3(q.x, 0, q.y)
	return Vector3.INF


## The named places to jump to: [label, position].
func places() -> Array:
	var out: Array = [["The first town", Vector3(WPlaces.start.x, 0, WPlaces.start.y)]]
	for id in WPlaces.SETTLEMENTS:
		var s: Dictionary = WPlaces.SETTLEMENTS[id]
		out.append([s.name, Vector3(s.pos.x, 0, s.pos.y) + Vector3(0, 0, s.radius + 6.0)])
	for il in w.terrain.isles:
		out.append(["Isle: %s" % il.name, Vector3(il.c.x, 0, il.c.y)])
	if w.hall and w.hall.stair_top != Vector3.ZERO:
		out.append(["The Lake Stair", w.hall.stair_top + Vector3(0, 0, 6.0)])
	var p: Vector3 = w.player.global_position
	for kind in ["vault", ""]:
		var best: Dictionary = {}
		for r in w.ruins:
			if r.has("isle") or (kind != "" and r.kind != kind):
				continue
			if best.is_empty() or p.distance_to(r.pos) < p.distance_to(best.pos):
				best = r
		if not best.is_empty():
			out.append(["Nearest %s" % ("sealed vault" if kind == "vault" else "ruin"), best.pos + Vector3(0, 0, 10.0)])
	return out


func go(at: Vector3) -> void:
	if at == Vector3.INF:
		w.hud.notify("No such ground near enough.")
		return
	if w.player.vessel != null and is_instance_valid(w.player.vessel):
		w._leave_boat(w.player.vessel)
	var y: float = w.terrain.height_at(at.x, at.z) if at.y > -200.0 else at.y
	w.player.place(Vector3(at.x, maxf(y, WIsles.SEA_Y) + 1.5, at.z), w.player.yaw)


func set_hour(h: float) -> void:
	if not host():
		return
	w.clock = h
	w.shared("_w_clock", [w.clock, w.day, w.nights])


## The eve of a seventh night: the great raid comes at dusk.
func seventh() -> void:
	if not host():
		return
	var n: int = w.nights
	while not w.great_night(n + 1):
		n += 1
	w.nights = n
	set_hour(w.weather.dusk() - 0.15)


func set_weather(k: String) -> void:
	if host():
		w.shared("_w_weather", [k, 600.0, randf() * TAU])


func toggle_fast() -> void:
	fast = not fast
	w.dev_fast = 2.5 if fast else 1.0


func heal() -> void:
	w.player.health = w.player.max_health
	w.player.stamina = 100.0
	w.food = 100.0
	w.rest = 100.0


func give_kit() -> void:
	for id in KIT:
		if Items.DB.has(id):
			w.inv.add(id, int(KIT[id]))
	give_ammo()


func give_ammo() -> void:
	for id in AMMO:
		if Items.DB.has(id):
			w.inv.add(id, int(AMMO[id]))


func give_arms() -> void:
	var a: Dictionary = w.arms
	for g in ArmsDB.GUNS:
		if not g in a.owned:
			a.owned.append(g)
	for k in WArms.KINDS:
		for id in WArms.table(k[0]):
			if not id in a[k[0]]:
				a[k[0]].append(id)
	for r in WArms.RELICS:
		if not r in a.relics:
			a.relics.append(r)
	w.rearm()
	give_ammo()


func kill_near() -> int:
	if not host():
		return 0
	var n := 0
	for e in w.enemies.duplicate():
		if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(w.player.global_position) < 90.0:
			e.die(false)
			n += 1
	return n


## A foe of each kind first met at this danger, a little way off.
func spawn_tier(t: int) -> int:
	if not host():
		return 0
	var n := 0
	for k in LesserSpeeb.FORM_TIER:
		if int(LesserSpeeb.FORM_TIER[k]) != t or not LesserSpeeb.KINDS.has(k) or k in ["saucer", "unseen"]:
			continue
		if w._spawn_near(k, w.player.global_position, 10.0, 16.0, true):
			n += 1
	return n
