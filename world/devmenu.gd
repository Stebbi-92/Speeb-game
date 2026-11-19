class_name WDev
extends RefCounted
## The hidden playtest menu (Ctrl + F8): jump to any land, town or isle, set the hour and the weather,
## and the tools a tester wants: no harm, a fast stride, a full kit, every weapon, foes of each danger.
## Moving yourself works for anyone; what changes the world is for the host only.

const LANDS := [["ash", "Ash Plains"], ["dunes", "Rust Dunes"], ["forest", "Dead Forest"], ["salt", "Salt Flats"], ["marsh", "Tar Marsh"], ["basalt", "Basalt Heights"]]
const KIT := {"scrap": 200, "wood": 200, "cloth": 100, "bone": 100, "stone": 100, "salt": 200, "oil": 60, "hide": 60, "herb": 60,
	"red_iron": 40, "heartwood": 40, "salt_crystal": 40, "tar": 40, "obsidian": 40, "coin": 100,
	"fittings_fine": 10, "fittings_rare": 6, "fittings_storied": 3, "tempered": 20, "clockwork": 20, "spirit_ember": 1, "spirit_ash": 1, "spirit_grave": 1}
const AMMO := {"shells": 200, "rounds": 300, "rifle": 400, "rockets": 20, "fuel": 400}

var w
var god := false
var fast := false
var meter := false
var _meter: Label = null
var _times: Array = []     ## the last two seconds or so of frame times, in ms
var _meter_t := 0.0


func _init(world) -> void:
	w = world


func host() -> bool:
	return Net.authority()


## Every frame while no harm is on: whole, fed and rested.
func tick() -> void:
	if meter:
		_tick_meter()
	if field_until > 0:
		_tick_field()
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
		var sp := WPlaces.spos(id)
		out.append([s.name, Vector3(sp.x, 0, sp.y) + Vector3(0, 0, s.radius + 6.0)])
	for il in w.terrain.isles:
		out.append(["Isle: %s" % il.name, Vector3(il.c.x, 0, il.c.y)])
	if w.kraken and w.kraken.spot != Vector3.INF:
		out.append(["The Kraken-Bell", w.kraken.spot + Vector3(30, 0, 0)])
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


## The frame meter, top right: frame rate, the slowest frames, and what the GPU is asked to draw.
func toggle_meter() -> void:
	meter = not meter
	if meter and _meter == null:
		var cl := CanvasLayer.new()
		cl.layer = 90
		w.add_child(cl)
		_meter = Label.new()
		_meter.add_theme_font_size_override("font_size", 15)
		_meter.add_theme_color_override("font_outline_color", Color.BLACK)
		_meter.add_theme_constant_override("outline_size", 5)
		_meter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_meter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_meter.position = Vector2(-420, 8)
		_meter.size = Vector2(410, 80)
		cl.add_child(_meter)
	if _meter:
		_meter.visible = meter
	_times.clear()


func _tick_meter() -> void:
	var dt: float = w.get_process_delta_time() * 1000.0
	_times.append(dt)
	if _times.size() > 240:
		_times.pop_front()
	_meter_t -= dt / 1000.0
	if _meter_t > 0.0 or _meter == null:
		return
	_meter_t = 0.25
	var s := _times.duplicate()
	s.sort()
	var worst: float = s[s.size() - 1]
	var low1: float = s[int(s.size() * 0.99) - 1] if s.size() >= 100 else worst
	var foes := 0
	for e in w.enemies:
		if is_instance_valid(e) and e.is_alive():
			foes += 1
	_meter.text = "%d fps   1%% low %d fps   worst %.1f ms\n%d draw calls   %dk triangles   %d foes   %s" % [
		Engine.get_frames_per_second(), int(1000.0 / maxf(low1, 0.001)), worst,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		foes, _land_name(w.land_at(w.player.global_position)) if w.player else ""]


func toggle_fast() -> void:
	fast = not fast
	w.dev_fast = 2.5 if fast else 1.0


func heal() -> void:
	w.player.health = w.player.max_health
	w.player.stamina = 100.0
	w.food = 100.0
	w.rest = 100.0
	w.spirits.rekindle()


func give_kit() -> void:
	for id in KIT:
		if Items.DB.has(id) and not (id.begins_with("spirit_") and w.inv.count(id) > 0):
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


## Pretend a bigger fellowship, to try how the waste meets one: off, 2, 4, 6, 8.
func cycle_crowd() -> void:
	var steps := [0, 2, 4, 6, 8]
	WCrowd.fake = steps[(steps.find(WCrowd.fake) + 1) % steps.size()]
	w.hud.notify("The waste reckons %s." % ("the fellowship as it is" if WCrowd.fake == 0 else "%d pilgrims" % WCrowd.fake))


## The forms of the far lands (sent by the far isles and Far Shores since 0.16): called up here, to try them.
const NEW_FORMS := ["flicker", "archivist_hand", "tunnel_unlit", "kelp_drowner", "rime_walker", "geyser_wight", "raven_mask",
	"canyon_strider", "dust_choir", "glass_husk", "grass_stalker", "mound_guard", "herd_ghost"]


## One of the new forms (and its band, if it comes in one), a little way off.
func spawn_form(k: String) -> bool:
	if not host() or not LesserSpeeb.VARIANTS.has(k):
		return false
	return w._spawn_near(k, w.player.global_position, 10.0, 16.0, true) != null


## A foe of each kind first met at this danger, a little way off.
func spawn_tier(t: int) -> int:
	if not host():
		return 0
	var n := 0
	for k in LesserSpeeb.FORM_TIER:
		if int(LesserSpeeb.FORM_TIER[k]) != t or not (LesserSpeeb.KINDS.has(k) or LesserSpeeb.VARIANTS.has(k)) or k in ["saucer", "unseen", "bellwound"] or k in NEW_FORMS:
			continue
		if w._spawn_near(k, w.player.global_position, 10.0, 16.0, true):
			n += 1
	return n


## The empty-field test (gameplay bible, section 10): open ground at noon, a tree close by, a shotgun and
## the hatchet, and three forms of the near lands. When the three fall, three more come, for five minutes.
## If those five minutes are not fun, that comes before anything else.
const FIELD_SECS := 300
var field_until := 0        ## when the test ends (ticks, ms), or 0
var field_at := Vector3.ZERO
var field_kills := 0
var _field_foes: Array = []


func field_test() -> void:
	if not host():
		return
	var best := Vector3.INF
	var p: Vector3 = w.player.global_position
	for nd in w.nodes:
		if nd.kind != "tree" or int(nd.charges) <= 0:
			continue
		var np: Vector3 = nd.pos
		if w.land_at(np) != "ash" or w.safe_at(np) or w.settlement_at(np, 120.0) != "" or w.tier_at(np) != 1:
			continue
		if best == Vector3.INF or np.distance_to(p) < best.distance_to(p):
			best = np
	if best == Vector3.INF:
		w.hud.notify("No open ground with a tree near enough.")
		return
	kill_near()
	go(best + Vector3(5.0, 0, 0))
	set_hour(12.0)
	var a: Dictionary = w.arms
	if not "shotgun" in a.owned:
		a.owned.append("shotgun")
	WArms.carry(a, "shotgun", "primary")
	a.melee = "hatchet"
	w.rearm()
	w.inv.add("shells", 120)
	field_at = best
	field_kills = 0
	_field_foes.clear()
	field_until = Time.get_ticks_msec() + FIELD_SECS * 1000
	w.hud.notify("The empty field: five minutes, one gun, one blade, a tree and three forms. Is it fun?")
	WPlaylog.note("Empty-field test begun")


func _tick_field() -> void:
	var left := _field_foes.filter(func(e): return is_instance_valid(e) and e.is_alive())
	field_kills += _field_foes.size() - left.size()
	_field_foes = left
	if Time.get_ticks_msec() >= field_until:
		field_until = 0
		for e in _field_foes:
			e.die(false)
		_field_foes.clear()
		var msg := "Five minutes in the empty field: %d forms felled." % field_kills
		w.hud.notify(msg + " Was it fun? Note it in the playtest log.")
		WPlaylog.note("Empty-field test ended: %d felled" % field_kills)
		return
	if _field_foes.is_empty() and w.player.global_position.distance_to(field_at) < 80.0:
		for i in 8:
			if _field_foes.size() >= 3:
				break
			var k: String = ["rusher", "rusher", "spider", "spitter", "swarm"][randi() % 5]
			var e = w._spawn_near(k, field_at, 12.0, 24.0, true)
			if e:
				e.set_meta("raid", true)   # not unmade by the ground's own rules while the test runs
				if e.has_method("seek"):
					e.seek(w.player.global_position, 40.0)
				_field_foes.append(e)

