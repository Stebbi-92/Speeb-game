class_name Wasteland
extends Level
## The Ashen Waste. A survivor cast out into it gathers, builds, and lives through its nights,
## while nine dead beacons wait across the land to be kindled again.

const DAY_SECONDS := 2400.0   ## a whole day and night in forty minutes: twenty-five of light, fifteen of dark
const DUSK := 20.0
const DAWN := 5.0
const RUINS_N := 44
const NODES_N := 900
const RUINS_FAR := 140      ## ruins in the far reaches, beyond the old rim
const NODES_FAR := 2700
const FIRE_KINDS := ["campfire", "cookpot", "torch"]
const WOOD_HOURS := 24.0     ## one piece of wood keeps a fire for a whole day
const FUEL_MAX := 240.0      ## a fire holds ten days of wood at most
const FUEL_START := 72.0     ## a new fire is laid with three days' wood
const REVEAL_N := 256

var terrain: WTerrain
var inv := Inventory.new()
var cat: WCat = null      ## this survivor's own riding cat, once one is tamed
var _cat_saved := {}      ## the cat as saved, until the world is ready to place it
var _stray: WCat = null   ## a stray near a town that could be won over
var _stray_t := 5.0
var arms: Dictionary = WArms.clean(null)   ## this survivor's guns, parts and kit
var skills := WSkills.new()
var seen_biomes := {}
var ui: WUI
var builder: WBuilder
var quests: WQuests
var slot := "1"
var _owns_world := false   ## set once at build: only the host (or a lone survivor) ever writes the world file
var world_uid := ""
var clock := 7.0
var day := 1
var night := false
var nights := 0
var lit: Array = []
var flags := {}
var rep := {}
var nodes: Array = []
var ruins: Array = []
var crates := {}
var containers := {}
var pieces := {}
var satchels := {}
var guide: WGuide
var rules := {}   ## this world's settings (see WRules)
var map_marks: Array = []   ## spots marked on the map by the fellowship: [position, who marked it]
const MAX_MARKS := 16
var people := {}
var settle_nodes := {}
var beacon_nodes: Array = []
var lairs: Array = []           ## one to a land: {id, land, boss, name, pos}
var _lair_boss := {}            ## lair id -> the great one now awake there
const LAIR_RETURN_DAYS := 3
var vigils := {}
var bedroll = null
var revealed := PackedByteArray()
var visited := {}
var known_ruins := {}
var piece_next := 1
var satchel_next := 1
var ready_world := false
var _sun_mat: ProceduralSkyMaterial
var _stars: MultiMeshInstance3D
var _sync_t := 0.0
var _wave_t := 20.0
var _safe_t := 2.0
var _crop_t := 0.0
var _day_t := 30.0
var _save_t := 120.0
var _save_soon := -1.0     ## counts down to a save asked for by an event; -1 when none
var _last_save := 0
var _reveal_t := 0.0
var _bleed_t := 0.0
var _give_up_t := 0.0
var _banner_on := false
var _vigil_t := 0.0
var _gen := RandomNumberGenerator.new()
var _m := {}


# ================================================================== the land

func build() -> void:
	Game.wasteland = true
	Game.warms = arms
	numeral = ""
	place = "The Ashen Waste"
	kill_y = -400.0
	max_alive = 0
	spiders = true
	_gen.randomize()
	revealed.resize(REVEAL_N * REVEAL_N)
	revealed.fill(0)
	setup_env(Color(0.42, 0.44, 0.48), Color(0.72, 0.62, 0.5), Color(0.22, 0.2, 0.18), Color(0.62, 0.55, 0.46), 0.0035, 0.7)
	_sun_mat = env.sky.sky_material
	env.fog_aerial_perspective = 0.5
	add_sun(Vector3(-40, 30, 0), Color(1.0, 0.86, 0.68), 1.4)
	sun.directional_shadow_max_distance = 90
	_make_stars()
	_materials()
	builder = WBuilder.new()
	builder.w = self
	add_child(builder)
	quests = WQuests.new()
	quests.w = self
	add_child(quests)
	if Net.authority():
		_owns_world = true
		slot = Game.world_slot
		DirAccess.make_dir_recursive_absolute("user://wasteland")
		var d = Game.read_var_safe(world_path(slot))
		if d is Dictionary:
			_pending = d
		var sd := int(_pending.get("seed", 0)) if not _pending.is_empty() else Game.new_world_seed
		if sd == 0:
			sd = randi_range(10000, 99999999)
		_make_world(sd)
	else:
		spawn_pos = Vector3(0, 400, 0)
	ambient("wind", -10)
	_beds = {"night": ambient("amb_desert_night", -60), "town": ambient("amb_town", -60), "cave": ambient("amb_cave", -60)}


var world_seed := 0
var _pending := {}


## Raises the whole waste from its seed: the land and its six biomes, then the places upon it.
func _make_world(sd: int) -> void:
	world_seed = sd
	terrain = WTerrain.new()
	terrain.setup(sd)
	WPlaces.lay_out(sd, func(p: Vector2) -> Vector2: return Vector2(terrain.legacy_raw(p.x, p.y), terrain_probe(p)))
	WPlaces.lay_out_far(sd, func(p: Vector2) -> Vector2: return Vector2(terrain._raw(p.x, p.y), terrain_probe(p)))
	for k in WPlaces.SETTLEMENTS:
		terrain.add_flat(WPlaces.spos(k), WPlaces.SETTLEMENTS[k].radius + 8.0)
	for bp in WPlaces.beacon_points():
		terrain.add_flat(bp, 16.0)
	terrain.add_flat(WPlaces.start, 6.0)
	_plan_ruins()
	for r in ruins:
		terrain.add_flat(Vector2(r.pos.x, r.pos.z), 9.0)
	_plan_lairs()
	WPlaces.plan_roads(sd, func(p: Vector2) -> Vector2: return Vector2(terrain._raw(p.x, p.y), terrain_probe(p)))
	for rd in WPlaces.roads:
		terrain.add_road(rd[2])
	terrain.generate()
	for r in ruins:
		r.pos.y = terrain.height_at(r.pos.x, r.pos.z)
	for l in lairs:
		l.pos.y = terrain.height_at(l.pos.x, l.pos.z)
	terrain.build(_m.ground)
	add_child(terrain)
	for k in WPlaces.SETTLEMENTS:
		_build_settlement(k)
	for i in WPlaces.BEACONS.size():
		_build_beacon(i)
	var before := get_child_count()
	for r in ruins:
		_build_ruin(r)
	for i in range(before, get_child_count()):
		_fade_far(get_child(i), 700.0)
	for l in lairs:
		_build_lair(l)
	_scatter_nodes()
	for nd in nodes:
		_off_the_road(nd)
		_fade_far(nd.node, 420.0)
	_build_signposts()
	_scatter_decor()
	_scatter_landmarks()
	spawn_pos = gpos(WPlaces.start) + Vector3(0, 0.2, 0)
	spawn_yaw = yaw_to(spawn_pos, gpos(WPlaces.spos("cinderwick")))


func intro() -> void:
	hud.name_label.text = "Survivor"
	ui = WUI.new()
	ui.w = self
	hud.root.add_child(ui)
	guide = WGuide.new()
	guide.w = self
	hud.root.add_child(guide)
	inv.changed.connect(func(): if ready_world: autosave_soon(20.0))
	skills.changed.connect(_apply_skills)
	player.weapon.reserve_max = 400
	player.weapon.pack = inv
	Game.milk_bag = inv
	player.max_health = 100.0
	if Net.authority():
		_load_world()
		ready_world = true
		_world_ready()
		for by in _waiting_hello:
			_rq_hello(by)
		_waiting_hello.clear()
	else:
		hud.say("The waste is taking shape around you...", 4.0)
		player.set_physics_process(false)
		shared("_rq_hello", [Net.me()])
	_load_character()
	_apply_time(true)
	if not flags.has("intro_seen_" + str(Net.me())) and quests.main_stage() == 0:
		flags["intro_seen_" + str(Net.me())] = true
		await hud.title_card("", "The Ashen Waste")
		hud.say(WPlaces.words("You were cast out with nothing but a gun and the clothes on your back. There is smoke on the horizon, to the <dir:S:cinderwick:start>."), 9.0)
	else:
		await hud.title_card("Day %d" % day, "The Ashen Waste")


func _exit_tree() -> void:
	super._exit_tree()
	if ready_world:
		save_all()
	Game.wasteland = false
	Game.milk_bag = null
	# The waste's own strip, panels and keys live on the HUD, which outlasts the level: take them away
	if is_instance_valid(ui):
		ui.close_all()
		ui.queue_free()
	ui = null
	if is_instance_valid(guide):
		guide.queue_free()
	guide = null
	Game.wrules = {}
	if hud:
		hud.boss_bar("", -1.0)
		hud.hotbar.arms = null


func gpos(p: Vector2) -> Vector3:
	return Vector3(p.x, terrain.height_at(p.x, p.y), p.y)


func _materials() -> void:
	_m.ground = mat(Color(1, 1, 1), 1.0, 0.3, 0.12)
	_m.ground.vertex_color_use_as_albedo = true
	_m.wood = mat(Color(0.33, 0.26, 0.2), 1.0, 0.35, 0.6)
	_m.darkwood = mat(Color(0.2, 0.16, 0.13), 1.0, 0.3, 0.6)
	_m.stone = mat(Color(0.42, 0.4, 0.38), 0.95, 0.4, 0.3)
	_m.darkstone = mat(Color(0.24, 0.23, 0.22), 0.95, 0.4, 0.3)
	_m.rust = mat(Color(0.42, 0.24, 0.15), 0.8, 0.5, 0.5, 0.4)
	_m.iron = mat(Color(0.2, 0.2, 0.21), 0.5, 0.3, 0.5, 0.7)
	_m.cloth = mat(Color(0.5, 0.44, 0.36), 1.0, 0.3, 1.0)
	_m.salt = mat(Color(0.9, 0.9, 0.88), 0.4, 0.15, 1.0)
	_m.bone = mat(Color(0.82, 0.78, 0.68), 0.8, 0.2, 1.0)
	_m.herb = mat(Color(0.74, 0.76, 0.66), 1.0, 0.1, 1.0)
	_m.thatch = mat(Color(0.48, 0.4, 0.26), 1.0, 0.4, 0.8)
	_m.soil = mat(Color(0.17, 0.13, 0.1), 1.0, 0.2, 1.0)
	_m.leaf = mat(Color(0.32, 0.4, 0.22), 1.0, 0.25, 0.8)
	_m.ember = glow_mat(Color(1.0, 0.45, 0.15), 3.0)
	_m.flame = glow_mat(Color(1.0, 0.95, 0.8), 6.0)
	_m.cold = mat(Color(0.12, 0.11, 0.1), 1.0, 0.2, 0.5)


func _make_stars() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 1.4)
	mm.mesh = q
	mm.instance_count = 1100
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in mm.instance_count:
		var d := Vector3(r.randf_range(-1, 1), r.randf_range(0.04, 1), r.randf_range(-1, 1)).normalized() * 800.0
		var t := Transform3D(Basis.looking_at(-d), d)
		mm.set_instance_transform(i, t.scaled_local(Vector3.ONE * r.randf_range(0.4, 1.7)))
	_stars = MultiMeshInstance3D.new()
	_stars.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 0.95)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_stars.material_override = m
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stars)


var _beds := {}   ## the sound of places: night, town and cave, faded in and out by where you are
var _bed_t := 0.0


func _process(delta: float) -> void:
	if _stars and player:
		_stars.global_position = player.global_position
	if player and hud and not Net.dedicated:
		_boss_watch()
		_bed_t -= delta
		if _bed_t <= 0.0:
			_bed_t = 0.5
			_place_sounds()
		_cat_tick(delta)


## Fades the sound of each place toward how near it is: a town's bustle by day, the night's insects
## after dark, the wind in a hollow among ruins and lairs.
func _place_sounds() -> void:
	if _beds.is_empty():
		return
	var p := player.global_position
	var town := 0.0
	for k in WPlaces.SETTLEMENTS:
		var d := Vector2(p.x, p.z).distance_to(WPlaces.spos(k)) - float(WPlaces.SETTLEMENTS[k].radius)
		town = maxf(town, clampf(1.0 - d / 60.0, 0.0, 1.0))
	var cave := 0.0
	for r in ruins:
		cave = maxf(cave, clampf(1.0 - (Vector2(p.x, p.z).distance_to(Vector2(r.pos.x, r.pos.z)) - 10.0) / 30.0, 0.0, 1.0))
	for l in lairs:
		cave = maxf(cave, clampf(1.0 - (Vector2(p.x, p.z).distance_to(Vector2(l.pos.x, l.pos.z)) - 15.0) / 35.0, 0.0, 1.0))
	var want := {"night": (1.0 if night else 0.0) * (1.0 - town * 0.5), "town": town * (0.35 if night else 1.0), "cave": cave * 0.8}
	for k in _beds:
		var pl: AudioStreamPlayer = _beds[k]
		if not is_instance_valid(pl):
			continue
		var db := linear_to_db(maxf(float(want[k]), 0.001)) - 14.0
		create_tween().tween_property(pl, "volume_db", maxf(db, -60.0), 0.5)


## Ruins are scattered where the land is level enough to have once been lived on.
func _plan_ruins() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 4401
	ruins.clear()
	for k in WPlaces.NAMED_RUINS:
		var d: Dictionary = WPlaces.NAMED_RUINS[k]
		var rp := WPlaces.rpos(k)
		ruins.append({"id": k, "name": d.name, "kind": d.kind, "pos": Vector3(rp.x, 0, rp.y), "guard_day": 0})
	var kinds := WPlaces.RUIN_KINDS.keys()
	var tries := 0
	while ruins.size() < RUINS_N + WPlaces.NAMED_RUINS.size() and tries < 4000:
		tries += 1
		var p := Vector2(r.randf_range(-880, 880), r.randf_range(-880, 880))
		if not _clear_of_places(p, 110.0, 70.0):
			continue
		var t := terrain_probe(p)
		if t > 0.22:
			continue
		var nm: String = WPlaces.RUIN_WORDS_A[r.randi() % WPlaces.RUIN_WORDS_A.size()] + " " + WPlaces.RUIN_WORDS_B[r.randi() % WPlaces.RUIN_WORDS_B.size()]
		if ruins.any(func(o): return o.name == nm):
			continue
		ruins.append({"id": "r%d" % ruins.size(), "name": nm, "kind": kinds[r.randi() % kinds.size()], "pos": Vector3(p.x, 0, p.y), "guard_day": 0})
	# The far reaches: more ruins, picked over by no one. Their own dice, so older worlds keep theirs.
	var fr := RandomNumberGenerator.new()
	fr.seed = world_seed + 5503
	var far := 0
	tries = 0
	while far < RUINS_FAR and tries < 8000:
		tries += 1
		var p := far_point(fr)
		if not _clear_of_places(p, 110.0, 70.0) or terrain_probe(p) > 0.22:
			continue
		var nm: String = WPlaces.RUIN_WORDS_A[fr.randi() % WPlaces.RUIN_WORDS_A.size()] + " " + WPlaces.RUIN_WORDS_B[fr.randi() % WPlaces.RUIN_WORDS_B.size()]
		if ruins.any(func(o): return o.name == nm):
			nm = "Far " + nm
			if ruins.any(func(o): return o.name == nm):
				continue
		ruins.append({"id": "r%d" % ruins.size(), "name": nm, "kind": kinds[fr.randi() % kinds.size()], "pos": Vector3(p.x, 0, p.y), "guard_day": 0})
		far += 1


## A tree or a rock that fell on a road is moved to its verge.
func _off_the_road(nd: Dictionary) -> void:
	var p: Vector3 = nd.pos
	if terrain.road_at(p.x, p.z) < 0.2:
		return
	for k in 8:
		var a := k * TAU / 8.0
		var q := p + Vector3(cos(a), 0, sin(a)) * 7.0
		if terrain.road_at(q.x, q.z) < 0.05:
			q.y = terrain.height_at(q.x, q.z)
			nd.pos = q
			nd.node.position = q
			return


## Where a road leaves a town, a post names where it goes.
func _build_signposts() -> void:
	for rd in WPlaces.roads:
		var pts: PackedVector2Array = rd[2]
		for end in [0, 1]:
			var here: String = rd[end]
			var there: String = rd[1 - end]
			var k := 6 if end == 0 else pts.size() - 7
			var nxt := k + (1 if end == 0 else -1)
			if k < 0 or k >= pts.size() or nxt < 0 or nxt >= pts.size():
				continue
			var at: Vector2 = pts[k]
			var dir: Vector2 = (pts[nxt] - at).normalized()
			var side := Vector2(-dir.y, dir.x) * 4.5
			var n := Node3D.new()
			n.position = gpos(at + side)
			add_child(n)
			_add(n, box(Vector3.ZERO, Vector3(0.18, 2.6, 0.18), _m.darkwood, true), Vector3(0, 1.3, 0))
			var arm := Node3D.new()
			arm.rotation.y = atan2(-dir.y, dir.x)
			_add(n, arm, Vector3(0, 2.1, 0))
			_add(arm, box(Vector3.ZERO, Vector3(1.6, 0.34, 0.06), _m.wood, false), Vector3(0.7, 0, 0))
			for face in [1.0, -1.0]:
				var l := Label3D.new()
				l.text = WPlaces.SETTLEMENTS[there].name
				l.font_size = 40
				l.pixel_size = 0.004
				l.modulate = Color(0.95, 0.9, 0.8)
				l.outline_size = 6
				l.position = Vector3(0.7, 0, 0.04 * face)
				l.rotation.y = 0.0 if face > 0 else PI
				l.width = 380.0
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.visibility_range_end = 60.0
				arm.add_child(l)


## Small things are not drawn from far off: the waste is wide, and the eye cannot hold it all.
func _fade_far(n: Node, dist: float) -> void:
	if n is GeometryInstance3D and n.visibility_range_end <= 0.0:
		n.visibility_range_end = dist
	for c in n.get_children():
		_fade_far(c, dist)


## A point in the far reaches: beyond the old rim, inside the new one.
static func far_point(r: RandomNumberGenerator, inner := 1010.0, outer := 1860.0) -> Vector2:
	while true:
		var p := Vector2(r.randf_range(-outer, outer), r.randf_range(-outer, outer))
		if maxf(absf(p.x), absf(p.y)) > inner:
			return p
	return Vector2.ZERO


## How steep the raw land is at a point, before any flattening.
func terrain_probe(p: Vector2) -> float:
	var a := terrain.legacy_raw(p.x - 6, p.y)
	var b := terrain.legacy_raw(p.x + 6, p.y)
	var c := terrain.legacy_raw(p.x, p.y - 6)
	var d := terrain.legacy_raw(p.x, p.y + 6)
	return maxf(absf(a - b), absf(c - d)) / 12.0


func _clear_of_places(p: Vector2, settle_r: float, other_r: float) -> bool:
	for k in WPlaces.SETTLEMENTS:
		if p.distance_to(WPlaces.spos(k)) < settle_r:
			return false
	for bp in WPlaces.beacon_points():
		if p.distance_to(bp) < other_r:
			return false
	for ru in ruins:
		if p.distance_to(Vector2(ru.pos.x, ru.pos.z)) < other_r:
			return false
	if p.distance_to(WPlaces.start) < 40.0:
		return false
	return true


# ------------------------------------------------------------------ settlements

func _build_settlement(k: String) -> void:
	var s: Dictionary = WPlaces.SETTLEMENTS[k]
	var c := gpos(WPlaces.spos(k))
	var r: float = s.radius
	var wall := mat(s.wall, 1.0, 0.35, 0.5)
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(k)
	# A palisade of stakes, broken by two gates
	var n := int(TAU * r / 0.9)
	for i in n:
		var a := TAU * i / n
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.12 or absf(wrapf(a + PI * 0.5, -PI, PI)) < 0.12:
			continue
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = terrain.height_at(p.x, p.z)
		var hgt := rr.randf_range(3.2, 4.2)
		cyl(p + Vector3(0, hgt * 0.5 - 0.4, 0), 0.22, hgt, wall, true, 0.14, 6)
	# Gate posts with lanterns
	for g in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var a: float = PI * 0.5 * g + side * 0.14
			var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
			p.y = terrain.height_at(p.x, p.z)
			cyl(p + Vector3(0, 2.4, 0), 0.3, 5.2, _m.darkwood, true, -1.0, 8)
			sphere(p + Vector3(0, 4.9, 0), 0.18, _m.ember)
			omni(p + Vector3(0, 4.6, 0), Color(1.0, 0.65, 0.35), 1.2, 9.0)
	# Huts about the edge, a fire at the heart
	var huts := 5 + rr.randi() % 3
	for i in huts:
		var a := TAU * (i + 0.5) / huts + rr.randf_range(-0.2, 0.2)
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.45 or absf(wrapf(a + PI * 0.5, -PI, PI)) < 0.45:
			continue
		var d := r * rr.randf_range(0.55, 0.7)
		var p := c + Vector3(cos(a) * d, 0, sin(a) * d)
		p.y = terrain.height_at(p.x, p.z)
		_hut(p, -a + PI * 0.5, rr)
	cyl(c + Vector3(0, 0.15, 0), 1.3, 0.3, _m.stone, true, -1.0, 10)
	for i in 5:
		var lg := box(c + Vector3(0, 0.35, 0), Vector3(0.22, 0.22, 1.6), _m.darkwood, false)
		lg.rotation.y = i * TAU / 5.0
		lg.rotation.x = 0.3
	var fire := sphere(c + Vector3(0, 0.7, 0), 0.55, _m.ember, false, 1.4)
	var fl := omni(c + Vector3(0, 2.0, 0), Color(1.0, 0.6, 0.3), 2.6, 22.0, true)
	settle_nodes[k] = {"center": c, "fire": fire, "light": fl}
	_smoke(c + Vector3(0, 1.0, 0))
	var lbl := label3d(s.name, c + Vector3(0, 6.5, 0), 1.2, Color(0.95, 0.85, 0.65), 0.0, true)
	lbl.visibility_range_end = 70.0
	# Its people
	for pid in WPlaces.PEOPLE:
		var pd: Dictionary = WPlaces.PEOPLE[pid]
		if pd.at != k:
			continue
		var p := c + Vector3(pd.off.x, 0, pd.off.y)
		p.y = terrain.height_at(p.x, p.z)
		_person(pid, p, yaw_to(p, c))
	# And the folk who live there, about their day
	for i in (3 if s.get("far", false) else 5):
		var f := WTownsfolk.new().setup(self, c, r * 0.6, hash(k) + i * 101)
		add_child(f)
		var a := i * TAU / 5.0 + 0.4
		f.global_position = c + Vector3(cos(a), 0, sin(a)) * r * 0.35
		f.global_position.y = terrain.height_at(f.global_position.x, f.global_position.z)


## A column of smoke over a hearth, seen from far across the waste.
func _smoke(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 22.0
	p.preprocess = 22.0
	var q := QuadMesh.new()
	q.size = Vector2(7, 7)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Relics._soft_dot()
	p.material_override = m
	p.direction = Vector3.UP
	p.spread = 6.0
	p.gravity = Vector3(0.35, 0.5, 0.1)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(1, 4.0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(0.2, 0.19, 0.18, 0.75))
	g.set_color(1, Color(0.35, 0.33, 0.31, 0.0))
	p.color_ramp = g
	p.visibility_aabb = AABB(Vector3(-60, 0, -60), Vector3(120, 160, 120))
	m.disable_fog = false
	p.position = at
	add_child(p)


func _hut(p: Vector3, yaw: float, rr: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	add_child(n)
	var w := rr.randf_range(4.0, 5.5)
	var d := rr.randf_range(3.5, 4.5)
	var hut := box(Vector3.ZERO, Vector3(w, 2.6, d), _m.wood)
	hut.reparent(n, false)
	hut.position = Vector3(0, 1.1, 0)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(w + 0.8, 1.6, d + 0.8)
	roof.mesh = pm
	roof.material_override = _m.thatch
	roof.position = Vector3(0, 3.2, 0)
	n.add_child(roof)
	var door := box(Vector3.ZERO, Vector3(1.1, 1.9, 0.1), _m.darkwood, false)
	door.reparent(n, false)
	door.position = Vector3(0, 0.95, d * 0.5 + 0.05)
	var win := box(Vector3.ZERO, Vector3(0.6, 0.5, 0.1), _m.ember, false)
	win.reparent(n, false)
	win.position = Vector3(w * 0.3, 1.6, d * 0.5 + 0.05)


## A soul of the waste, who may be spoken with.
func _person(pid: String, p: Vector3, yaw: float) -> void:
	var pd: Dictionary = WPlaces.PEOPLE[pid]
	var f := figure(p, yaw, pd.robe)
	# The people of the waste are dressed each in their own way; the robed shape only keeps their place
	for c in f.get_children():
		if c is MeshInstance3D:
			c.queue_free()
	var dressed := Figure.new().setup(Figure.seeded(pid.hash()))
	dressed.arms_forward = false
	f.add_child(dressed)
	var body: StaticBody3D = f.get_meta("body")
	body.collision_layer = 1 | 16
	personal_interactable(body, "Speak with %s" % pd.name, func(): ui.open_dialogue(pid))
	var lbl := label3d("%s\n%s" % [pd.name, pd.title], p + Vector3(0, 2.25, 0), 0.32, Color(0.92, 0.88, 0.78), 0.0, true)
	lbl.visibility_range_end = 18.0
	people[pid] = {"node": f, "pos": p, "fig": dressed, "yaw": yaw}


## Someone speaking to the pilgrim turns to face them, and their mouth moves while the words come.
func speaker_says(pid: String, secs: float) -> void:
	var e: Dictionary = people.get(pid, {})
	if e.is_empty() or not is_instance_valid(e.node) or player == null:
		return
	var f: Node3D = e.node
	var to := player.global_position - f.global_position
	_turn(f, atan2(to.x, to.z))
	var fig: Figure = e.fig
	if is_instance_valid(fig):
		fig.talk_t = secs


## When the talk ends they go back to how they stood, after a moment.
func speaker_done(pid: String) -> void:
	var e: Dictionary = people.get(pid, {})
	if e.is_empty() or not is_instance_valid(e.node):
		return
	if is_instance_valid(e.fig):
		e.fig.talk_t = 0.0
	_turn(e.node, float(e.yaw), 2.5)


func _turn(n: Node3D, yaw: float, wait := 0.0) -> void:
	if n.has_meta("turn"):
		var old: Tween = n.get_meta("turn")
		if old and old.is_valid():
			old.kill()
	var from := n.rotation.y
	var tw := n.create_tween()
	if wait > 0.0:
		tw.tween_interval(wait)
	tw.tween_method(func(t: float): n.rotation.y = lerp_angle(from, yaw, t), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	n.set_meta("turn", tw)


func settlement_at(p: Vector3, extra := 0.0) -> String:
	for k in WPlaces.SETTLEMENTS:
		var s: Dictionary = WPlaces.SETTLEMENTS[k]
		if Vector2(p.x, p.z).distance_to(WPlaces.spos(k)) < s.radius + extra:
			return k
	return ""


# ------------------------------------------------------------------ beacons

func _build_beacon(i: int) -> void:
	var b: Dictionary = WPlaces.BEACONS[i]
	var c := gpos(WPlaces.bpos(i))
	var n := Node3D.new()
	n.position = c
	add_child(n)
	for k in 3:
		var step := cyl(Vector3.ZERO, 5.0 - k * 1.2, 0.6, _m.darkstone, true, -1.0, 12)
		step.reparent(n, false)
		step.position = Vector3(0, 0.3 + k * 0.6, 0)
	var col := cyl(Vector3.ZERO, 1.0, 9.0, _m.stone, true, 0.75, 10)
	col.reparent(n, false)
	col.position = Vector3(0, 6.3, 0)
	var bowl := cyl(Vector3.ZERO, 1.9, 0.9, _m.iron, true, 1.0, 14)
	bowl.reparent(n, false)
	bowl.position = Vector3(0, 11.2, 0)
	var coals := sphere(Vector3.ZERO, 1.2, _m.cold, false, 0.35)
	coals.reparent(n, false)
	coals.position = Vector3(0, 11.7, 0)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 1.3
	fm.height = 4.2
	flame.mesh = fm
	flame.material_override = _m.flame
	flame.position = Vector3(0, 13.4, 0)
	flame.visible = false
	n.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.92, 0.75)
	light.light_energy = 0.0
	light.omni_range = 60.0
	light.omni_attenuation = 0.6
	light.position = Vector3(0, 13, 0)
	n.add_child(light)
	# A pale pillar of light, seen across the waste once kindled
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.6
	bm.bottom_radius = 1.2
	bm.height = 260.0
	beam.mesh = bm
	var beam_m := StandardMaterial3D.new()
	beam_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_m.albedo_color = Color(1.0, 0.95, 0.8, 0.22)
	beam_m.disable_fog = true
	beam_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = beam_m
	beam.position = Vector3(0, 144, 0)
	beam.visible = false
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(beam)
	var lbl := label3d(b.name, c + Vector3(0, 3.6, 5.4), 0.6, Color(0.85, 0.82, 0.75), 0.0, true)
	lbl.visibility_range_end = 40.0
	var a := Area3D.new()
	a.collision_layer = 16
	a.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 1.5
	sh.height = 3.0
	cs.shape = sh
	a.add_child(cs)
	a.position = Vector3(0, 2.4, 0)
	n.add_child(a)
	personal_interactable(a, "", func(): _beacon_touched(i))
	beacon_nodes.append({"node": n, "flame": flame, "light": light, "beam": beam, "area": a, "pos": c})
	_beacon_prompt(i)


func _beacon_prompt(i: int) -> void:
	if beacon_nodes.size() <= i:
		return
	var a: Area3D = beacon_nodes[i].area
	if i in lit:
		a.set_meta("prompt", "Walk the beacon road")
	elif vigils.has(i):
		a.set_meta("prompt", "")
	else:
		a.set_meta("prompt", "Kindle the beacon (Beacon Oil)")


func _beacon_touched(i: int) -> void:
	if i in lit:
		ui.open_travel()
		return
	if vigils.has(i):
		return
	if i == 8 and lit.size() < 8:
		hud.say("The ninth bowl is choked with black earth. It will not take a flame while any other beacon stands dark.", 5.0)
		return
	if inv.count("beacon_oil") <= 0:
		hud.say("The bowl is cold and dry. It wants beacon oil, rendered in the old measure.", 4.5)
		return
	inv.take("beacon_oil", 1)
	shared("_rq_kindle", [Net.me(), i, skills.vigil_mult()])


func _rq_kindle(_by: int, i: int, vm := 1.0) -> void:
	if not Net.authority() or i in lit or vigils.has(i):
		return
	shared("_w_vigil", [i, (90.0 if i < 8 else 150.0) * clampf(vm, 0.7, 1.0)])


## The oil is poured and the flame taken; now the night comes for it, and the flame must be kept.
func _w_vigil(i: int, t: float) -> void:
	vigils[i] = t
	var b: Dictionary = beacon_nodes[i]
	b.flame.visible = true
	b.flame.scale = Vector3.ONE * 0.3
	b.light.light_energy = 1.0
	_beacon_prompt(i)
	sfx("bell", -2, b.pos)
	if player.global_position.distance_to(b.pos) < 120.0:
		hud.say("The oil takes. A small white flame stands in the bowl, and the dark leans toward it. Keep it until it holds.", 6.0)
	if i == 8:
		hud.say("The ninth flame takes, and the ground beneath it groans. Something is climbing out of the mouth to put it out.", 7.0)


func _w_vigil_end(i: int, ok: bool) -> void:
	vigils.erase(i)
	if ok:
		award("beacon")
	var b: Dictionary = beacon_nodes[i]
	if ok:
		if not i in lit:
			lit.append(i)
		_light_beacon(i, true)
		sfx("choir", 0, b.pos)
		if player.global_position.distance_to(b.pos) < 200.0:
			hud.say("%s burns again. The night will not come within sight of it." % WPlaces.BEACONS[i].name, 6.0)
		else:
			hud.notify("%s has been kindled." % WPlaces.BEACONS[i].name)
		quests.on_event("lit", {"beacon": i})
		if Net.authority():
			_clear_near(b.pos, WPlaces.BEACON_SAFE)
	else:
		b.flame.visible = false
		b.light.light_energy = 0.0
		hud.notify("The flame at %s guttered out. The oil is spent." % WPlaces.BEACONS[i].name)
	_beacon_prompt(i)


func _light_beacon(i: int, on: bool) -> void:
	if on and ready_world:
		autosave_soon(1.0)
	var b: Dictionary = beacon_nodes[i]
	b.flame.visible = on
	b.flame.scale = Vector3.ONE
	b.beam.visible = on
	b.light.light_energy = 3.0 if on else 0.0
	_beacon_prompt(i)


const BASE_SAFE := 40.0    ## the ground a campfire keeps: forms do not rise within it
const TOWN_SAFE := 30.0    ## beyond a settlement's wall, how far its watch reaches
const RAID_CHANCE := 0.07  ## each night, the chance a camp with someone near it is raided

var raiding := {}          ## campfire piece id -> seconds the raid has left


func safe_at(p: Vector3) -> bool:
	for i in lit:
		if Vector2(p.x, p.z).distance_to(WPlaces.bpos(i)) < WPlaces.BEACON_SAFE:
			return true
	return settlement_at(p, TOWN_SAFE) != "" or base_at(p) >= 0


const TORCH_SAFE := 15.0

## The campfire or torch whose ground this is, or -1. A campfire is what makes a camp.
func base_at(p: Vector3, extra := 0.0, fires_only := false) -> int:
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		var r := BASE_SAFE if pc.kind == "campfire" else (TORCH_SAFE if pc.kind == "torch" and not fires_only else -1.0)
		if r > 0.0 and not burning(pid):
			continue
		if r > 0.0 and Vector2(p.x, p.z).distance_to(Vector2(pc.pos.x, pc.pos.z)) < r + extra:
			return pid
	return -1


# ------------------------------------------------------------------ a base's stores

## Inside a base (near a lit campfire), what lies in its chests counts as carried for making and
## building, so a pilgrim need not run from chest to chest. Chests within the fire's reach count.
func base_chests() -> Array:
	if player == null:
		return []
	var fire := base_at(player.global_position, 0.0, true)
	if fire < 0:
		return []
	var fp: Vector3 = pieces[fire].pos
	var out: Array = []
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		if pc.kind == "chest" and Vector2(pc.pos.x, pc.pos.z).distance_to(Vector2(fp.x, fp.z)) < BASE_SAFE and containers.has("p%d" % pid):
			out.append("p%d" % pid)
	return out


func stock_count(id: String) -> int:
	var n := inv.count(id)
	for cid in base_chests():
		n += _cont_count(cid, id)
	return n


func stock_has_all(cost: Dictionary) -> bool:
	if inv.has_all(cost):
		return true
	for k in cost:
		if stock_count(k) < int(cost[k]):
			return false
	return true


## Pays from the pack first, then from the base's chests (the host takes those).
func stock_pay(cost: Dictionary) -> bool:
	if not stock_has_all(cost):
		return false
	var cids := base_chests()
	for k in cost:
		var need := int(cost[k])
		var from_pack := mini(need, inv.count(k))
		if from_pack > 0:
			inv.take(k, from_pack)
		if need - from_pack > 0:
			shared("_rq_spend", [Net.me(), cids, k, need - from_pack])
			# Seen at once here too, so the menus count right until the host's word arrives
			if not Net.authority():
				_spend_local(cids, k, need - from_pack)
	return true


func _rq_spend(_by: int, cids: Array, item: String, n: int) -> void:
	if not Net.authority():
		return
	for cid in cids:
		if n <= 0:
			break
		if not containers.has(cid):
			continue
		var data: Array = containers[cid]
		for i in data.size():
			if n <= 0:
				break
			if data[i] != null and data[i][0] == item:
				var t := mini(n, int(data[i][1]))
				n -= t
				data[i][1] = int(data[i][1]) - t
				if int(data[i][1]) <= 0:
					data[i] = null
		shared("_w_cont", [cid, data])


func _spend_local(cids: Array, item: String, n: int) -> void:
	for cid in cids:
		var data: Array = containers.get(cid, [])
		for i in data.size():
			if n > 0 and data[i] != null and data[i][0] == item:
				var t := mini(n, int(data[i][1]))
				n -= t
				data[i][1] = int(data[i][1]) - t
				if int(data[i][1]) <= 0:
					data[i] = null


# ------------------------------------------------------------------ food and rest

var food := 100.0
var rest := 100.0
const FOOD_SECONDS := 3000.0   ## a full belly empties in fifty minutes
const REST_SECONDS := 3600.0   ## a rested body tires in an hour awake


func _needs_tick(delta: float) -> void:
	if Net.dedicated or _pfail or downed:
		return
	var work := 1.6 if player.cur_speed > 4.5 else 1.0
	var wn := WArms.worn(arms)
	var nm := WRules.needs_mult()
	food = maxf(0.0, food - delta * 100.0 / FOOD_SECONDS * work * float(wn.hunger) * nm)
	rest = maxf(0.0, rest - delta * 100.0 / REST_SECONDS * float(wn.weary) * nm)
	var slow := (0.85 if rest <= 0.0 else (0.93 if rest < 20.0 else 1.0)) * float(wn.speed)
	player.walk_speed = 3.4 * skills.speed_mult() * slow
	player.run_speed = 5.8 * skills.speed_mult() * slow
	# Breath comes back slower when weary or starving, and slower still under heavy plate
	player.stamina_mult = (0.6 if rest < 20.0 else 1.0) * (0.7 if food <= 0.0 else 1.0) / maxf(0.8, float(wn.weary))
	if food <= 0.0:
		_starve_t -= delta
		if _starve_t <= 0.0:
			_starve_t = 6.0
			player.health = maxf(1.0, player.health - 3.0)
			hud.set_health(player.health / player.max_health, true)
	if is_instance_valid(ui):
		ui.set_needs(food, rest)
	_need_warn(delta)


var _starve_t := 6.0
var _warned := {}


func _need_warn(_delta: float) -> void:
	for k in [["food", food, "You are hungry. Eat something."], ["rest", rest, "You are weary. Sleep at a bedroll or by a fire."]]:
		var low: bool = k[1] < 20.0
		if low and not _warned.get(k[0], false):
			hud.notify(k[2])
		_warned[k[0]] = low


## Eating fills the belly; the healer's things only close wounds.
func eat(id: String) -> bool:
	var info: Dictionary = Items.info(id)
	var f := float(info.get("food", 0.0))
	var h := float(info.get("heal", 0.0))
	if f <= 0.0 and player.health >= player.max_health - 0.5:
		hud.notify("You are not hurt.")
		return false
	if f > 0.0 and food >= 99.0 and player.health >= player.max_health - 0.5:
		hud.notify("You are not hungry.")
		return false
	if inv.take(id, 1) < 1:
		return false
	food = minf(100.0, food + f)
	player.health = clampf(player.health + h, 1.0, player.max_health)
	hud.set_health(player.health / player.max_health, true)
	sfx("drink", -6)
	if h < 0.0:
		hud.notify("Raw meat turns your stomach. Cook it first.")
	return true


## The censer's smoke: forms in it are shown, choke and slow, and lurkers cannot stay under the sand.
func cense(at: Vector3, reach: float) -> void:
	super(at, reach)
	for e in enemies:
		if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(at) < reach:
			e.reveal(1.2, true)


# ------------------------------------------------------------------ beasts to hunt

var beasts := {}          ## id -> WBeast
var _beast_next := 1
var _beast_t := 3.0
var _beast_sync := 0.0


## The host keeps a few beasts grazing near each pilgrim, out in the open, and lets the far ones go.
func _beast_tick(delta: float) -> void:
	_beast_sync -= delta
	if Net.online and _beast_sync <= 0.0 and not beasts.is_empty():
		_beast_sync = 0.25
		var batch: Array = []
		for id in beasts:
			var b: WBeast = beasts[id]
			if is_instance_valid(b) and b.is_alive():
				batch.append([id, b.kind, b.global_position, b.rotation.y])
		shared("_w_beasts", [batch])
	_beast_t -= delta
	if _beast_t > 0.0:
		return
	_beast_t = 4.0
	var tg := targets()
	for id in beasts.keys():
		var b = beasts[id]
		if not is_instance_valid(b):
			beasts.erase(id)
			continue
		if b.is_alive() and not tg.any(func(t): return t.global_position.distance_to(b.global_position) < 280.0):
			shared("_w_beast_gone", [id])
	for t in tg:
		var p: Vector3 = t.global_position
		var near := beasts.values().filter(func(b): return is_instance_valid(b) and b.is_alive() and b.global_position.distance_to(p) < 170.0).size()
		if near >= 5 or randf() > 0.45:
			continue
		var a := randf() * TAU
		var at := p + Vector3(cos(a), 0, sin(a)) * randf_range(70.0, 130.0)
		if absf(at.x) > 1900.0 or absf(at.z) > 1900.0:
			continue
		at.y = terrain.height_at(at.x, at.z)
		if safe_at(at) or settlement_at(at, 60.0) != "" or terrain.normal_at(at.x, at.z).y < 0.8:
			continue
		var land := terrain.biome_name(at.x, at.z)
		var kinds: Array = WBeast.KINDS.keys().filter(func(k): return land in WBeast.KINDS[k].lands)
		if kinds.is_empty():
			continue
		var k: String = kinds[randi() % kinds.size()]
		if k == "tusker" and randf() < 0.5:
			k = kinds[randi() % kinds.size()]
		var herd := 1 if k == "tusker" else randi_range(1, 3)
		for i in herd:
			var q := at + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			q.y = terrain.height_at(q.x, q.z) + 0.4
			_w_beast(_beast_next, k, q)
			if Net.online:
				shared("_w_beasts", [[[_beast_next, k, q, 0.0]]])
			_beast_next += 1


func _w_beast(id: int, k: String, at: Vector3) -> WBeast:
	if beasts.has(id) and is_instance_valid(beasts[id]):
		return beasts[id]
	var b := WBeast.new().setup(self, id, k)
	add_child(b)
	b.global_position = at
	b.rotation.y = randf() * TAU
	beasts[id] = b
	return b


func _w_beasts(batch: Array) -> void:
	if Net.authority():
		return
	for e in batch:
		var b := _w_beast(int(e[0]), str(e[1]), e[2])
		b.net_set(e[2], float(e[3]))


func _w_beast_gone(id: int) -> void:
	if beasts.has(id):
		if is_instance_valid(beasts[id]):
			beasts[id].queue_free()
		beasts.erase(id)


func _rq_beast_hit(id: int, amount: float, by: int) -> void:
	if Net.authority() and beasts.has(id) and is_instance_valid(beasts[id]):
		beasts[id].take(amount, by)


## The host has a beast fall: everyone sees it drop, and what can be taken from it lies by the body.
func beast_died(b: WBeast, by: int) -> void:
	var items: Array = []
	for d in b.spec.drops:
		var n := randi_range(int(d[1]), int(d[2]))
		if n > 0:
			items.append([d[0], n])
	shared("_w_beast_die", [b.id, b.global_position])
	_rq_satchel(by, b.global_position + Vector3(0, 0.3, 0), items, false)


func _w_beast_die(id: int, at: Vector3) -> void:
	if not beasts.has(id) or not is_instance_valid(beasts[id]):
		return
	var b: WBeast = beasts[id]
	beasts.erase(id)
	b.global_position = at
	b.die()
	sfx("thud", -6, at)


# ------------------------------------------------------------------ fires that burn wood

## Whether a campfire, cooking station or torch still has wood burning in it.
func burning(pid: int) -> bool:
	var pc: Dictionary = pieces.get(pid, {})
	return not pc.is_empty() and world_hours() < float(pc.get("fuel", world_hours() + 1.0))


## Hours of wood left in a fire.
func fuel_left(pid: int) -> float:
	return maxf(0.0, float(pieces.get(pid, {}).get("fuel", 0.0)) - world_hours())


## Puts wood from the pack on a fire: as much as it will take, up to what is carried.
func add_wood(pid: int, n := -1) -> void:
	if not pieces.has(pid):
		return
	var room := int(floor((FUEL_MAX - fuel_left(pid)) / WOOD_HOURS))
	var want := room if n < 0 else mini(n, room)
	want = mini(want, inv.count("wood"))
	if room <= 0:
		hud.notify("It is full of wood. It will burn for %d days." % int(fuel_left(pid) / 24.0))
		return
	if want <= 0:
		hud.notify("You have no wood.")
		return
	inv.take("wood", want)
	sfx("carve", -8)
	shared("_rq_fuel", [pid, want])
	hud.notify("+%d wood. It will burn for %s." % [want, _days_text(fuel_left(pid) + want * WOOD_HOURS)])


func _days_text(hours: float) -> String:
	if hours >= 36.0:
		return "%d days" % int(round(hours / 24.0))
	return "%d hours" % int(ceil(hours))


func _rq_fuel(pid: int, n: int) -> void:
	if not Net.authority() or not pieces.has(pid):
		return
	var start := maxf(world_hours(), float(pieces[pid].get("fuel", 0.0)))
	shared("_w_fuel", [pid, minf(start + n * WOOD_HOURS, world_hours() + FUEL_MAX)])


func _w_fuel(pid: int, until: float) -> void:
	if not pieces.has(pid):
		return
	pieces[pid].fuel = until
	_fire_look(pid)
	autosave_soon(10.0)


## A fire with no wood left goes dark.
func _fire_look(pid: int) -> void:
	var pc: Dictionary = pieces[pid]
	if not pc.node.has_meta("fire"):
		return
	var lit := burning(pid)
	for nd in pc.node.get_meta("fire"):
		if is_instance_valid(nd):
			nd.visible = lit


# ------------------------------------------------------------------ planters

func world_hours() -> float:
	return day * 24.0 + clock


func crop_left(pid: int) -> float:
	var pc: Dictionary = pieces.get(pid, {})
	if pc.is_empty() or pc.get("crop", "") == "":
		return -1.0
	return maxf(0.0, float(Items.info(pc.crop).hours) - (world_hours() - float(pc.sown)))


func _rq_plant(by: int, pid: int, seed: String) -> void:
	if not Net.authority():
		return
	if not pieces.has(pid) or pieces[pid].kind != "planter" or pieces[pid].crop != "":
		Net.call_peer(by, "_w_give", [[[seed, 1]]])
		return
	shared("_w_plant", [pid, seed, world_hours()])


func _rq_harvest(by: int, pid: int) -> void:
	if not Net.authority() or not pieces.has(pid) or pieces[pid].crop == "" or crop_left(pid) > 0.0:
		return
	var info: Dictionary = Items.info(pieces[pid].crop)
	var n := randi_range(int(info["yield"][0]), int(info["yield"][1]))
	var give := [[info.grows, n]]
	if randf() < 0.5:
		give.append([pieces[pid].crop, 1])
	shared("_w_plant", [pid, "", 0.0])
	Net.call_peer(by, "_w_give", [give])


func _w_plant(pid: int, seed: String, sown: float) -> void:
	if not pieces.has(pid):
		return
	pieces[pid].crop = seed
	pieces[pid].sown = sown
	_crop_look(pid)
	if is_instance_valid(ui):
		ui.planter_changed(pid)
	autosave_soon(10.0)


## Draws the crop in a planter at its present growth.
func _crop_look(pid: int) -> void:
	var pc: Dictionary = pieces[pid]
	if pc.kind != "planter" or not pc.node.has_meta("crop"):
		return
	var crop: Node3D = pc.node.get_meta("crop")
	var want := 0.0 if pc.crop == "" else 1.0 - crop_left(pid) / float(Items.info(pc.crop).hours)
	if crop.has_meta("grown") and absf(float(crop.get_meta("grown")) - want) < 0.05:
		return
	crop.set_meta("grown", want)
	for c in crop.get_children():
		c.queue_free()
	if pc.crop == "":
		return
	var m: Material = _m.leaf if pc.crop == "tuber_seed" else _m.herb
	for i in 6:
		var x := -0.6 + (i % 3) * 0.6
		var z := -0.25 + (i / 3) * 0.5
		var h := 0.08 + want * 0.5
		var leaf := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18 + want * 0.15, h, 0.18 + want * 0.15)
		leaf.mesh = bm
		leaf.material_override = m
		leaf.position = Vector3(x, h * 0.5, z)
		leaf.rotation.y = i * 0.7
		crop.add_child(leaf)
		if want >= 1.0:
			var bloom := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.07
			sm.height = 0.14
			bloom.mesh = sm
			bloom.material_override = _m.bone if pc.crop == "herb_seed" else _m.wood
			bloom.position = Vector3(x, h + 0.04, z)
			crop.add_child(bloom)


# ------------------------------------------------------------------ waystones

func _rq_portal_name(pid: int, name: String) -> void:
	if Net.authority() and pieces.has(pid) and pieces[pid].kind in ["portal", "chest"]:
		shared("_w_portal_name", [pid, name.strip_edges().left(24)])


func _w_portal_name(pid: int, name: String) -> void:
	if not pieces.has(pid) or not pieces[pid].kind in ["portal", "chest"]:
		return
	pieces[pid].name = name
	if pieces[pid].kind == "chest":
		_chest_label(pid)
		if is_instance_valid(ui):
			ui.container_changed("p%d" % pid)
		autosave_soon(5.0)
		return
	for q in pieces:
		_portal_look(q)
	if is_instance_valid(ui):
		ui.planter_changed(pid)
	autosave_soon(5.0)


## The waystone that answers this one: another of the same name.
func portal_pair(pid: int) -> int:
	var pc: Dictionary = pieces.get(pid, {})
	if pc.is_empty() or str(pc.get("name", "")) == "":
		return -1
	for q in pieces:
		if q != pid and pieces[q].kind == "portal" and str(pieces[q].get("name", "")).to_lower() == str(pc.name).to_lower():
			return q
	return -1


## A named chest shows its name above it, so a base's stores can be told apart.
func _chest_label(pid: int) -> void:
	var pc: Dictionary = pieces[pid]
	if not is_instance_valid(pc.node):
		return
	var lab: Label3D = pc.node.get_meta("label") if pc.node.has_meta("label") else null
	if lab == null:
		lab = Label3D.new()
		lab.font_size = 34
		lab.pixel_size = 0.005
		lab.position = Vector3(0, 1.25, 0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.modulate = Color(0.95, 0.88, 0.7)
		lab.outline_size = 6
		lab.visibility_range_end = 12.0
		pc.node.add_child(lab)
		pc.node.set_meta("label", lab)
	lab.text = str(pc.name)


func _portal_look(pid: int) -> void:
	var pc: Dictionary = pieces[pid]
	if pc.kind != "portal" or not pc.node.has_meta("veil"):
		return
	var on := portal_pair(pid) >= 0
	(pc.node.get_meta("veil") as StandardMaterial3D).albedo_color.a = 0.45 if on else 0.0
	(pc.node.get_meta("light") as OmniLight3D).light_energy = 1.4 if on else 0.0
	(pc.node.get_meta("label") as Label3D).text = str(pc.name)


func step_through(pid: int) -> void:
	var to := portal_pair(pid)
	if to < 0:
		return
	var pc: Dictionary = pieces[to]
	var fwd := Vector3(sin(pc.yaw), 0, cos(pc.yaw))
	sfx("choir", -8)
	player.input_locked = true
	await hud.fade_to(1.0, 0.35)
	player.place(pc.pos + fwd * 2.2 + Vector3(0, 0.5, 0), pc.yaw + PI)
	await get_tree().create_timer(0.3, false).timeout
	await hud.fade_to(0.0, 0.6)
	player.input_locked = false


# ------------------------------------------------------------------ sleeping through the night

var sleep_votes := {}       ## peer id -> true, kept by the host
var _my_vote := false
var _vote_spot := Vector3.ZERO


func vote_sleep(on: bool) -> void:
	_my_vote = on
	_vote_spot = player.global_position
	shared("_rq_sleep", [Net.me(), on])


func _rq_sleep(by: int, on: bool) -> void:
	if not Net.authority():
		return
	if on:
		sleep_votes[by] = true
	else:
		sleep_votes.erase(by)
	var need: Array = Net.pilgrims() if Net.online else [Net.me()]
	var have := 0
	for id in need:
		if sleep_votes.has(id):
			have += 1
	shared("_w_sleep_count", [have, need.size()])
	if have >= need.size() and need.size() > 0 and night:
		sleep_votes.clear()
		shared("_w_sleep_through", [])


func _w_sleep_count(have: int, of: int) -> void:
	if is_instance_valid(ui):
		ui.sleep_count(have, of)


func _w_sleep_through() -> void:
	_my_vote = false
	if is_instance_valid(ui):
		ui.close_all()
	player.input_locked = true
	await hud.fade_to(1.0, 1.5)
	if Net.authority():
		clock = DAWN - 0.02
	rest = 100.0
	food = maxf(0.0, food - 15.0)
	player.health = player.max_health
	hud.set_health(1.0, true)
	await get_tree().create_timer(1.5, false).timeout
	await hud.fade_to(0.0, 2.0)
	player.input_locked = false


## A short sleep by day: the body rests, the world does not wait.
func nap() -> void:
	player.input_locked = true
	await hud.fade_to(1.0, 1.0)
	rest = 100.0
	if not Net.online:
		clock = fmod(clock + 2.0, 24.0)
	await get_tree().create_timer(1.0, false).timeout
	await hud.fade_to(0.0, 1.5)
	player.input_locked = false
	hud.notify("You wake rested.")


## Forms that stray onto safe ground at night are taken by it, unless they came to raid.
func _keep_safe() -> void:
	for e in enemies:
		if not is_instance_valid(e) or not e.is_alive() or e.has_meta("raid") or e.boss != "":
			continue
		var p: Vector3 = e.global_position
		if settlement_at(p, TOWN_SAFE - 6.0) != "" or base_at(p, -4.0) >= 0:
			e.die(false)


## Rarely, a camp is found in the night. The fellowship is told with a bell and a banner.
func _maybe_raid() -> void:
	if nights < 2 or randf() > RAID_CHANCE:
		return
	var camps: Array = []
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		if pc.kind != "campfire" or raiding.has(pid):
			continue
		for t in targets():
			if t.global_position.distance_to(pc.pos) < 80.0:
				camps.append(pid)
				break
	if camps.is_empty():
		return
	var pid: int = camps[randi() % camps.size()]
	raiding[pid] = 90.0
	shared("_w_raid", [pieces[pid].pos])
	var c: Vector3 = pieces[pid].pos
	var n := 5 + mini(nights, 8) + targets().size() * 2
	var roster: Array = BIOME_FORMS[terrain.biome_name(c.x, c.z)]
	for k in n:
		get_tree().create_timer(randf_range(2.0, 20.0), false).timeout.connect(func():
			if is_instance_valid(self) and night:
				var e = _spawn_near(roster[randi() % roster.size()], c, BASE_SAFE - 12.0, BASE_SAFE + 6.0, true)
				if e:
					e.set_meta("raid", true))


func _w_raid(at: Vector3) -> void:
	sfx("bell", 0)
	get_tree().create_timer(0.7, false).timeout.connect(func(): sfx("bell", -3, null, 0.8))
	var d := int(player.global_position.distance_to(at))
	hud.alert_banner("Your camp is under attack", "%d m away. Hold the fire until dawn." % d if d > 30 else "Hold the fire until dawn.")


func _vigil_tick(delta: float) -> void:
	for i in vigils.keys():
		var b: Dictionary = beacon_nodes[i]
		vigils[i] -= delta
		var near := false
		for t in targets():
			if t.global_position.distance_to(b.pos) < 50.0:
				near = true
		if not near:
			vigils[i] -= delta * 4.0
		b.flame.scale = Vector3.ONE * clampf(1.0 - vigils[i] / 150.0, 0.3, 1.0)
		_vigil_t -= delta
		if _vigil_t <= 0.0 and alive_count() < 6 + targets().size() * 3:
			_vigil_t = 7.0 if i < 8 else 5.0
			var roster := ["rusher", "rusher", "spitter", "swarm", "swarm", "spider"]
			for k in 2 + int(nights * 0.3) + targets().size():
				_spawn_near(roster[randi() % roster.size()], b.pos, 26.0, 40.0)
			if i == 8 and randf() < 0.35:
				_spawn_near("elite", b.pos, 30.0, 40.0)
		if vigils[i] <= 0.0:
			shared("_w_vigil_end", [i, near])


# ------------------------------------------------------------------ ruins

func _build_ruin(r: Dictionary) -> void:
	var c: Vector3 = r.pos
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(r.id)
	var n := Node3D.new()
	n.position = c
	n.rotation.y = rr.randf() * TAU
	add_child(n)
	match r.kind:
		"wreck":
			for k in 2:
				var wg := Node3D.new()
				wg.position = Vector3(k * 5.0 - 2.5, 0, rr.randf_range(-2, 2))
				wg.rotation = Vector3(0, rr.randf() * TAU, rr.randf_range(-0.4, 0.4))
				n.add_child(wg)
				_add(wg, box(Vector3.ZERO, Vector3(2.2, 1.0, 4.2), _m.darkwood), Vector3(0, 0.8, 0))
				for wx in [-1.2, 1.2]:
					for wz in [-1.4, 1.4]:
						var wh := cyl(Vector3.ZERO, 0.6, 0.15, _m.darkwood, false, -1.0, 10)
						_add(wg, wh, Vector3(wx, 0.5, wz))
						wh.rotation.z = PI * 0.5
				if rr.randf() < 0.6:
					_add(wg, box(Vector3.ZERO, Vector3(2.2, 0.08, 4.0), _m.cloth, false), Vector3(0, 2.2, 0))
			_bones(n, Vector3(1, 0, 3), rr)
		"shrine":
			_add(n, box(Vector3.ZERO, Vector3(3, 1.0, 1.6), _m.stone), Vector3(0, 0.5, 0))
			for k in 6:
				var a := TAU * k / 6
				var hgt := rr.randf_range(1.0, 4.5)
				_add(n, cyl(Vector3.ZERO, 0.4, hgt, _m.stone, true, 0.35, 8), Vector3(cos(a) * 5, hgt * 0.5, sin(a) * 5))
			_add(n, box(Vector3.ZERO, Vector3(0.9, 0.9, 0.1), _m.bone, false), Vector3(0, 1.45, 0))
		"tower":
			var hgt := rr.randf_range(8.0, 14.0)
			_add(n, cyl(Vector3.ZERO, 3.2, hgt, _m.stone, true, 3.0, 12), Vector3(0, hgt * 0.5, 0))
			for k in 8:
				_add(n, box(Vector3.ZERO, Vector3(rr.randf_range(0.6, 1.4), 0.6, rr.randf_range(0.6, 1.4)), _m.stone, true, Vector3(rr.randf(), rr.randf(), rr.randf())), Vector3(rr.randf_range(-7, 7), 0.3, rr.randf_range(-7, 7)))
			_add(n, box(Vector3.ZERO, Vector3(1.4, 2.4, 0.4), _m.darkwood, false), Vector3(0, 1.2, 3.2))
		"camp":
			for k in 3:
				var a := TAU * k / 3 + 0.4
				var tent := MeshInstance3D.new()
				var pm := PrismMesh.new()
				pm.size = Vector3(2.6, 1.8, 3.0)
				tent.mesh = pm
				tent.material_override = _m.cloth
				_add(n, tent, Vector3(cos(a) * 4, 0.9, sin(a) * 4))
				tent.rotation.y = -a
			_add(n, cyl(Vector3.ZERO, 0.8, 0.2, _m.cold, false, -1.0, 10), Vector3(0, 0.1, 0))
			_bones(n, Vector3(-2, 0, -1), rr)
		"vault":
			_add(n, box(Vector3.ZERO, Vector3(8, 5, 6), _m.darkstone), Vector3(0, 2.0, -2))
			_add(n, box(Vector3.ZERO, Vector3(2.0, 3.0, 0.3), _m.iron, false), Vector3(0, 1.5, 1.05))
			for side in [-1.0, 1.0]:
				_add(n, cyl(Vector3.ZERO, 0.45, 5.0, _m.stone, true, -1.0, 8), Vector3(side * 2.0, 2.5, 1.2))
		"stones":
			for k in 9:
				var a := TAU * k / 9
				var hgt := rr.randf_range(2.5, 5.0)
				_add(n, box(Vector3.ZERO, Vector3(1.1, hgt, 0.7), _m.darkstone, true, Vector3(rr.randf_range(-0.1, 0.1), -a, rr.randf_range(-0.1, 0.1))), Vector3(cos(a) * 7, hgt * 0.5 - 0.3, sin(a) * 7))
	# What may be searched
	var kind: Dictionary = WPlaces.RUIN_KINDS[r.kind]
	for k in int(kind.crates):
		var off := Vector3(rr.randf_range(-4, 4), 0, rr.randf_range(-4, 4))
		if r.kind == "vault":
			off = Vector3((k - 1) * 2.0, 0, 3.5)
		var p := n.to_global(off)
		p.y = terrain.height_at(p.x, p.z)
		_crate("%s_%d" % [r.id, k], p, kind.loot, rr.randf() * TAU, r.kind == "vault" and k == 1)


func _add(parent: Node3D, mi: Node3D, local: Vector3) -> Node3D:
	if mi.get_parent():
		mi.reparent(parent, false)
	else:
		parent.add_child(mi)
	mi.position = local
	return mi


func _bones(parent: Node3D, at: Vector3, rr: RandomNumberGenerator) -> void:
	for k in 5:
		var b := box(Vector3.ZERO, Vector3(0.08, 0.08, rr.randf_range(0.3, 0.6)), _m.bone, false)
		_add(parent, b, at + Vector3(rr.randf_range(-0.5, 0.5), 0.05, rr.randf_range(-0.5, 0.5)))
		b.rotation.y = rr.randf() * TAU
	_add(parent, sphere(Vector3.ZERO, 0.13, _m.bone), at + Vector3(0.3, 0.12, 0.2))


func _crate(id: String, p: Vector3, table: String, yaw: float, sealed := false) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	add_child(n)
	var body := StaticBody3D.new()
	body.collision_layer = 1 | 16
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.1, 0.8, 0.8)
	cs.shape = bs
	cs.position.y = 0.4
	body.add_child(cs)
	n.add_child(body)
	_add(n, box(Vector3.ZERO, Vector3(1.1, 0.7, 0.8), _m.iron if sealed else _m.wood, false), Vector3(0, 0.35, 0))
	var lid := box(Vector3.ZERO, Vector3(1.15, 0.1, 0.85), _m.darkwood if not sealed else _m.rust, false)
	_add(n, lid, Vector3(0, 0.75, 0))
	crates[id] = {"pos": p, "table": table, "lid": lid, "body": body, "sealed": sealed, "day": -99}
	var prompt := "Force the iron chest (Pry Bar)" if sealed else "Search"
	personal_interactable(body, prompt, func(): _search(id), 0.6)


func _search(id: String) -> void:
	var c: Dictionary = crates[id]
	if c.sealed and inv.count("prybar") <= 0 and not containers.has(id):
		hud.say("The iron is sealed with lead. It wants a pry bar.", 3.5)
		return
	sfx("carve", -8, c.pos)
	shared("_rq_open", [Net.me(), id])


# ------------------------------------------------------------------ containers (the host keeps what is in them)

func _rq_open(by: int, id: String) -> void:
	if not Net.authority():
		return
	if crates.has(id):
		var c: Dictionary = crates[id]
		# A searched place fills again, slowly, as the waste moves things about
		if day - int(c.day) >= 3 or not containers.has(id):
			var rr := RandomNumberGenerator.new()
			rr.randomize()
			var bag := Inventory.new(12)
			for it in Items.roll(c.table, maxi(1, int(round((rr.randi_range(2, 4) + (2 if c.sealed else 0)) * WRules.yield_mult()))), rr):
				bag.add(it[0], it[1])
			containers[id] = bag.to_data()
			shared("_w_crate_day", [id, day])
		var cache := quests.cache_items(id)
		if not cache.is_empty():
			var bag := Inventory.new(14)
			bag.from_data(containers[id])
			for it in cache:
				bag.add(it[0], it[1])
			containers[id] = bag.to_data()
		shared("_w_cont", [id, containers[id]])
	if not containers.has(id):
		shared("_w_cont", [id, Inventory.new(12).to_data()])
	Net.call_peer(by, "_w_opened", [id])


func _w_crate_day(id: String, d: int) -> void:
	if crates.has(id):
		crates[id].day = d
		crates[id].lid.rotation.x = -1.2
		crates[id].lid.position = Vector3(0, 1.0, -0.35)


func _w_cont(id: String, data: Array) -> void:
	containers[id] = data
	if ui:
		ui.container_changed(id)


func _w_opened(id: String) -> void:
	ui.open_container(id)


## Takes one slot of a container into the asker's pack.
func _rq_take(by: int, id: String, i: int) -> void:
	if not Net.authority() or not containers.has(id):
		return
	var data: Array = containers[id]
	if i < 0 or i >= data.size() or data[i] == null:
		return
	var it: Array = data[i]
	data[i] = null
	shared("_w_cont", [id, data])
	Net.call_peer(by, "_w_give", [[it]])
	_check_satchel(id)


## Takes as much of a container as the pack has room for, in one ask. Returns how many stacks were asked for.
func take_all(id: String) -> int:
	var data: Array = containers.get(id, [])
	var room := Inventory.new(inv.slots.size())
	room.from_data(inv.to_data())
	var idxs: Array = []
	var left_behind := false
	for i in data.size():
		var it = data[i]
		if it == null:
			continue
		if room.room_for(str(it[0]), int(it[1])):
			room.add(str(it[0]), int(it[1]))
			idxs.append(i)
		else:
			left_behind = true
	if not idxs.is_empty():
		shared("_rq_take_many", [Net.me(), id, idxs])
		sfx("step", -4, null, 0.7)
	if left_behind:
		hud.notify("Your pack is full. Some is left behind.")
	elif idxs.is_empty() and data.is_empty():
		hud.notify("Nothing here.")
	return idxs.size()


## The host changes the world's settings; everyone takes them up.
func set_rules(r: Dictionary) -> void:
	if Net.authority():
		shared("_w_rules", [WRules.clean(r)])


func _w_rules(r: Dictionary) -> void:
	rules = WRules.clean(r)
	Game.wrules = rules
	autosave_soon(2.0)


## A spot marked on the map, shown to everyone on the map and the compass. Marking near a mark takes it away.
func toggle_mark(p: Vector3, near := 60.0) -> void:
	shared("_w_mark", [Vector3(p.x, 0, p.z), Net.me(), near])


func _w_mark(p: Vector3, by: int, near := 60.0) -> void:
	for i in map_marks.size():
		var q: Vector3 = map_marks[i][0]
		if Vector2(q.x - p.x, q.z - p.z).length() < near:
			map_marks.remove_at(i)
			autosave_soon(5.0)
			return
	map_marks.append([p, by])
	while map_marks.size() > MAX_MARKS:
		map_marks.pop_front()
	autosave_soon(5.0)


func clear_marks() -> void:
	shared("_w_clear_marks", [])


func _w_clear_marks() -> void:
	map_marks.clear()
	autosave_soon(5.0)


func _rq_take_many(by: int, id: String, idxs: Array) -> void:
	if not Net.authority() or not containers.has(id):
		return
	var data: Array = containers[id]
	var got: Array = []
	for i in idxs:
		i = int(i)
		if i >= 0 and i < data.size() and data[i] != null:
			got.append(data[i])
			data[i] = null
	if got.is_empty():
		return
	shared("_w_cont", [id, data])
	Net.call_peer(by, "_w_give", [got])
	_check_satchel(id)


func _rq_put(by: int, id: String, item: String, n: int) -> void:
	# Every pilgrim hears this; only the host acts on it. (The others giving the item back is what
	# once let a joiner keep what they had just put away.)
	if not Net.authority():
		return
	if not containers.has(id):
		Net.call_peer(by, "_w_give", [[[item, n]]])
		return
	var bag := Inventory.new(containers[id].size())
	bag.from_data(containers[id])
	var left := bag.add(item, n)
	shared("_w_cont", [id, bag.to_data()])
	if left > 0:
		Net.call_peer(by, "_w_give", [[[item, left]]])


## Things given into this pilgrim's hands. What does not fit is left at their feet.
func _w_give(items: Array) -> void:
	var spill: Array = []
	for it in items:
		var id: String = it[0]
		var n: int = it[1]
		var left := inv.add(id, n)
		if n - left > 0:
			hud.notify("+%d %s" % [n - left, Items.iname(id)])
		if left > 0:
			spill.append([id, left])
	if not spill.is_empty():
		hud.notify("Your pack is full. The rest is left on the ground.")
		shared("_rq_satchel", [Net.me(), player.global_position, spill, false])
	quests.refresh_hud()


func give(items: Array) -> void:
	_w_give(items)


## Takes up the arms now chosen, without refilling what is thrown or used.
func rearm() -> void:
	Net.send_look()
	var wp: Arms = player.weapon
	var had := [wp.grenade, wp.grenades, wp.gadget, wp.charges, wp.gun()]
	wp.equip_loadout()
	if wp.grenade == had[0]:
		wp.grenades = had[1]
	if wp.gadget == had[2]:
		wp.charges = had[3]
	if wp.gun() != had[4] and wp.guns[1] == had[4]:
		wp.cur = 1
		wp._show_model()
	wp._show_melee()
	wp._ui()
	autosave_soon(5.0)


## One survivor hands things to another close by. The host carries it across.
func _rq_gift(by: int, to: int, items: Array) -> void:
	if Net.authority():
		Net.call_peer(to, "_w_gift", [items, by])


func _w_gift(items: Array, by: int) -> void:
	hud.notify("%s hands you something." % Net.name_of(by))
	_w_give(items)


# ------------------------------------------------------------------ satchels: what is dropped, or left by the fallen

func _rq_satchel(_by: int, p: Vector3, items: Array, grave: bool) -> void:
	if not Net.authority():
		return
	var sid := "s%d" % satchel_next
	satchel_next += 1
	var bag := Inventory.new(maxi(12, items.size()))
	for it in items:
		bag.add(it[0], it[1])
	shared("_w_cont", [sid, bag.to_data()])
	shared("_w_satchel", [sid, p, grave])


func _w_satchel(sid: String, p: Vector3, grave: bool) -> void:
	if satchels.has(sid):
		return
	var n := Node3D.new()
	add_child(n)
	n.global_position = ground_below(p)
	var body := StaticBody3D.new()
	body.collision_layer = 16
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.6
	cs.shape = sh
	cs.position.y = 0.3
	body.add_child(cs)
	n.add_child(body)
	var bag := sphere(Vector3.ZERO, 0.35, _m.cloth, false, 0.7)
	_add(n, bag, Vector3(0, 0.25, 0))
	var neck := cyl(Vector3.ZERO, 0.09, 0.16, _m.cloth, false, 0.14, 8)
	_add(n, neck, Vector3(0, 0.55, 0))
	_loot_glow(n, sid, grave)
	if grave:
		var l := OmniLight3D.new()
		l.light_color = Color(0.7, 0.8, 1.0)
		l.light_energy = 1.2
		l.omni_range = 4.0
		l.position.y = 1.0
		n.add_child(l)
	personal_interactable(body, "Your belongings" if grave else "Satchel", func(): shared("_rq_open", [Net.me(), sid]))
	body.set_meta("on_hold", func(): take_all(sid))
	body.set_meta("hold_prompt", "Take all")
	satchels[sid] = {"node": n, "pos": p, "grave": grave}


## A soft column of light over something left on the ground, and motes rising from it, so a drop is seen
## from afar. Its colour says what is inside: blue for your belongings, gold for the common, amber for the rare.
func _loot_glow(n: Node3D, sid: String, grave: bool) -> void:
	var best := 0
	for it in containers.get(sid, []):
		if it != null:
			var info: Dictionary = Items.info(str(it[0]))
			best = maxi(best, int(info.get("value", 0)) if not info.kind in ["trophy", "quest"] else 999)
	var c := Color(0.55, 0.75, 1.0) if grave else (Color(1.0, 0.55, 0.2) if best >= 40 else Color(1.0, 0.85, 0.5))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _beam_tex()
	mat.texture_repeat = false
	mat.albedo_color = Color(c, 0.8)
	var beam := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 5.0)
	beam.mesh = q
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = 2.6
	n.add_child(beam)
	var motes := CPUParticles3D.new()
	motes.amount = 6
	motes.lifetime = 2.4
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 0.3
	motes.direction = Vector3.UP
	motes.spread = 12.0
	motes.gravity = Vector3(0, 0.25, 0)
	motes.initial_velocity_min = 0.5
	motes.initial_velocity_max = 0.9
	motes.scale_amount_min = 0.6
	motes.scale_amount_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.2))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 0.0))
	motes.scale_amount_curve = sc
	var pm := QuadMesh.new()
	pm.size = Vector2(0.12, 0.12)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.albedo_color = c.lightened(0.3)
	var dot := GradientTexture2D.new()
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = dg
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.width = 16
	dot.height = 16
	mm.albedo_texture = dot
	pm.material = mm
	motes.mesh = pm
	motes.position.y = 0.4
	n.add_child(motes)
	var t := create_tween().set_loops()
	t.bind_node(beam)
	t.tween_property(beam, "transparency", 0.35, 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(beam, "transparency", 0.0, 1.2).set_trans(Tween.TRANS_SINE)


var _beam_cache: ImageTexture


## White, bright in the middle and at the foot, fading to nothing at the sides and the top.
func _beam_tex() -> ImageTexture:
	if _beam_cache == null:
		var img := Image.create(16, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			var v := pow(float(y) / 63.0, 1.6)   # 0 at the top, 1 at the foot
			for x in 16:
				var u := 1.0 - absf((x + 0.5) / 8.0 - 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(u * u * v, 0.0, 1.0)))
		_beam_cache = ImageTexture.create_from_image(img)
	return _beam_cache


## The first solid ground under a point: a floor, a roof, a rock, or the land itself.
func ground_below(p: Vector3) -> Vector3:
	var g := terrain.height_at(p.x, p.z)
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), Vector3(p.x, g - 1.0, p.z), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() and r.position.y > g:
		return r.position
	return Vector3(p.x, g, p.z)


func _check_satchel(id: String) -> void:
	if not satchels.has(id):
		return
	for s in containers[id]:
		if s != null:
			return
	shared("_w_satchel_gone", [id])


func _w_satchel_gone(id: String) -> void:
	if satchels.has(id):
		satchels[id].node.queue_free()
		satchels.erase(id)
	containers.erase(id)
	if ui:
		ui.container_changed(id)


# ------------------------------------------------------------------ what may be gathered

const NODE_KINDS := {
	"tree": {"prompt": "Cut deadwood", "tool": "hatchet", "charges": 4},
	"rock": {"prompt": "Break stone", "tool": "pick", "charges": 4},
	"scrap": {"prompt": "Pick through the scrap", "tool": "", "charges": 3},
	"salt": {"prompt": "Chip salt", "tool": "pick", "charges": 4},
	"herb": {"prompt": "Gather ash-bloom", "tool": "", "charges": 2},
	"bone": {"prompt": "Gather bones", "tool": "", "charges": 2},
}


func _scatter_nodes() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 9090
	var tries := 0
	while nodes.size() < NODES_N and tries < NODES_N * 6:
		tries += 1
		var p2 := Vector2(r.randf_range(-900, 900), r.randf_range(-900, 900))
		var kinds := _node_kind(p2, r)
		if kinds == "":
			continue
		var near_settle := false
		for k in WPlaces.SETTLEMENTS:
			if p2.distance_to(WPlaces.spos(k)) < WPlaces.SETTLEMENTS[k].radius + 8.0:
				near_settle = true
		for bp in WPlaces.beacon_points():
			if p2.distance_to(bp) < 12.0:
				near_settle = true
		if near_settle:
			continue
		var p := gpos(p2)
		if _legacy_normal(p2).y < 0.8:
			continue
		_make_node(nodes.size(), kinds, p, r)
	# A few of each close by the first camp, so the cast-out are not lost entirely
	var start := WPlaces.spos("cinderwick")
	for kk in ["tree", "tree", "rock", "rock", "scrap", "scrap", "herb", "bone", "salt"]:
		for t in 30:
			var p2: Vector2 = start + Vector2(r.randf_range(-120, 120), r.randf_range(-20, 200))
			if p2.distance_to(start) > 50.0:
				_make_node(nodes.size(), kk, gpos(p2), r)
				break
	# The far reaches, with their own dice: what is gathered there is added after all the rest
	var fr := RandomNumberGenerator.new()
	fr.seed = world_seed + 9191
	var far := 0
	tries = 0
	while far < NODES_FAR and tries < NODES_FAR * 6:
		tries += 1
		var p2 := far_point(fr)
		var kinds := _node_kind(p2, fr)
		if kinds == "" or not _clear_of_places(p2, 45.0, 12.0):
			continue
		var p := gpos(p2)
		if terrain.normal_at(p.x, p.z).y < 0.8:
			continue
		_make_node(nodes.size(), kinds, p, fr)
		far += 1


## The lie of the land as it was before the waste grew, so that the old middle is gathered from as it was.
func _legacy_normal(p2: Vector2) -> Vector3:
	if maxf(absf(p2.x), absf(p2.y)) < 800.0:
		var p := gpos(p2)
		return terrain.normal_at(p.x, p.z)
	var e := WTerrain.CELL
	var lr := func(x: float, z: float) -> float: return terrain.legacy_raw(x, z)
	return Vector3(lr.call(p2.x - e, p2.y) - lr.call(p2.x + e, p2.y), 2.0 * e, lr.call(p2.x, p2.y - e) - lr.call(p2.x, p2.y + e)).normalized()


## What each land yields, by weight.
const BIOME_NODES := {
	"ash": [["tree", 4], ["rock", 3], ["scrap", 2], ["herb", 1], ["bone", 1]],
	"dunes": [["scrap", 5], ["bone", 2], ["rock", 1], ["herb", 1]],
	"salt": [["salt", 6], ["scrap", 2], ["bone", 2]],
	"forest": [["tree", 8], ["rock", 1], ["herb", 2], ["bone", 1]],
	"basalt": [["rock", 7], ["scrap", 1], ["salt", 1], ["herb", 1]],
	"marsh": [["herb", 4], ["bone", 3], ["tree", 2], ["scrap", 1]],
}
const BIOME_TEXT := {
	"ash": "Gray dust to the horizon. Deadwood and old iron lie half buried in it.",
	"dunes": "Red sand over red iron. The caravans died here, and their wreckage is everywhere.",
	"salt": "White crust that cracks underfoot. Nothing hides here, and nothing can hide you.",
	"forest": "Trees that died standing, close as a crowd. Good timber. Poor sight lines.",
	"basalt": "Black stone, high and broken. The quarries of the waste, and the hardest walking.",
	"marsh": "Black tar under a skin of water. It drags at your boots, and things live in it.",
}
## What the night sends, by land.
const BIOME_FORMS := {
	"ash": ["rusher", "rusher", "spitter", "spider", "swarm", "idol", "bloater", "howler", "hollow", "hollow", "vigil"],
	"dunes": ["spitter", "spitter", "rusher", "swarm", "spider", "lurker", "lurker", "saltbone"],
	"salt": ["rusher", "spitter", "swarm", "swarm", "rusher", "howler", "bloater", "saltbone", "saltbone", "vigil"],
	"forest": ["rusher", "rusher", "spider", "spider", "idol", "brute", "howler", "hollow", "hollow"],
	"basalt": ["idol", "idol", "rusher", "spitter", "spider", "brute", "bloater", "saltbone", "vigil"],
	"marsh": ["spider", "spider", "swarm", "swarm", "swarm", "rusher", "bloater", "lurker", "hollow", "hollow"],
}


func _node_kind(p: Vector2, r: RandomNumberGenerator) -> String:
	var t: Array = BIOME_NODES[terrain.biome_name(p.x, p.y)]
	var total := 0
	for row in t:
		total += int(row[1])
	var roll := r.randi_range(1, total + 2)
	for row in t:
		roll -= int(row[1])
		if roll <= 0:
			return row[0]
	return ""


func _make_node(id: int, kind: String, p: Vector3, r: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = r.randf() * TAU
	add_child(n)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	n.add_child(body)
	var cs := CollisionShape3D.new()
	body.add_child(cs)
	match kind:
		"tree":
			var h := r.randf_range(4.0, 7.5)
			_add(n, cyl(Vector3.ZERO, 0.25, h, _m.wood, false, 0.1, 6), Vector3(0, h * 0.5, 0))
			for b in 4:
				var br := box(Vector3.ZERO, Vector3(0.12, r.randf_range(1.2, 2.4), 0.12), _m.wood, false)
				_add(n, br, Vector3(0, h * r.randf_range(0.45, 0.9), 0))
				br.rotation = Vector3(r.randf_range(-1.0, 1.0), r.randf() * TAU, r.randf_range(-1.0, 1.0))
			var cap := CapsuleShape3D.new()
			cap.radius = 0.35
			cap.height = h
			cs.shape = cap
			cs.position.y = h * 0.5
		"rock":
			var s := r.randf_range(1.0, 1.8)
			var rk := sphere(Vector3.ZERO, s, _m.stone, false, 0.65)
			_add(n, rk, Vector3(0, s * 0.35, 0))
			rk.scale = Vector3(1.0, 0.65, r.randf_range(0.8, 1.3))
			_add(n, sphere(Vector3.ZERO, s * 0.5, _m.darkstone, false, 0.8), Vector3(s * 0.7, s * 0.2, 0))
			var sp := SphereShape3D.new()
			sp.radius = s * 0.85
			cs.shape = sp
			cs.position.y = s * 0.2
		"scrap":
			for k in 5:
				var b := box(Vector3.ZERO, Vector3(r.randf_range(0.4, 1.4), r.randf_range(0.1, 0.5), r.randf_range(0.4, 1.4)), _m.rust if k % 2 == 0 else _m.iron, false)
				_add(n, b, Vector3(r.randf_range(-0.6, 0.6), 0.15 + k * 0.12, r.randf_range(-0.6, 0.6)))
				b.rotation = Vector3(r.randf_range(-0.5, 0.5), r.randf() * TAU, r.randf_range(-0.5, 0.5))
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.6, 0.9, 1.6)
			cs.shape = bs
			cs.position.y = 0.45
		"salt":
			for k in 5:
				var hgt := r.randf_range(0.6, 1.6)
				var cr := MeshInstance3D.new()
				var pm := PrismMesh.new()
				pm.size = Vector3(0.4, hgt, 0.4)
				cr.mesh = pm
				cr.material_override = _m.salt
				_add(n, cr, Vector3(r.randf_range(-0.5, 0.5), hgt * 0.5, r.randf_range(-0.5, 0.5)))
				cr.rotation = Vector3(r.randf_range(-0.4, 0.4), r.randf() * TAU, r.randf_range(-0.4, 0.4))
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.4, 1.2, 1.4)
			cs.shape = bs
			cs.position.y = 0.6
		"herb":
			for k in 7:
				var st := cyl(Vector3.ZERO, 0.02, 0.5, _m.herb, false, -1.0, 4)
				_add(n, st, Vector3(r.randf_range(-0.4, 0.4), 0.25, r.randf_range(-0.4, 0.4)))
				_add(n, sphere(Vector3.ZERO, 0.09, glow_mat(Color(0.9, 0.92, 0.82), 0.4), false), st.position + Vector3(0, 0.27, 0))
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.0, 0.6, 1.0)
			cs.shape = bs
			cs.position.y = 0.3
			body.collision_layer = 16
		"bone":
			_bones(n, Vector3.ZERO, r)
			_add(n, cyl(Vector3.ZERO, 0.12, 1.6, _m.bone, false, 0.05, 6), Vector3(0.4, 0.2, 0)).rotation.z = 1.2
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.2, 0.5, 1.2)
			cs.shape = bs
			cs.position.y = 0.25
			body.collision_layer = 16
	body.collision_layer |= 16
	var nk: Dictionary = NODE_KINDS[kind]
	nodes.append({"id": id, "kind": kind, "pos": p, "node": n, "body": body, "charges": int(nk.charges), "back": 0})
	personal_interactable(body, nk.prompt, func(): _gather(id), 1.6)
	body.set_meta("node", id)


func _gather(id: int) -> void:
	var nd: Dictionary = nodes[id]
	if nd.charges <= 0:
		return
	shared("_rq_gather", [Net.me(), id])
	var nk: Dictionary = NODE_KINDS[nd.kind]
	sfx("crumble" if nd.kind in ["rock", "salt"] else "carve", -6, nd.pos, randf_range(0.9, 1.15))
	player.shake(0.12)


func _rq_gather(by: int, id: int) -> void:
	if not Net.authority() or id < 0 or id >= nodes.size():
		return
	var nd: Dictionary = nodes[id]
	if nd.charges <= 0:
		return
	var out: Array = []
	var rr := RandomNumberGenerator.new()
	rr.randomize()
	match nd.kind:
		"tree":
			out.append(["wood", rr.randi_range(3, 5)])
		"rock":
			out.append(["stone", rr.randi_range(3, 5)])
			if rr.randf() < 0.25:
				out.append(["salt", rr.randi_range(2, 5)])
		"scrap":
			out.append(["scrap", rr.randi_range(1, 3)])
			if rr.randf() < 0.4:
				out.append(["cloth", rr.randi_range(1, 2)])
			if rr.randf() < 0.3:
				var kind: String = ["shells", "shells", "rounds", "rounds", "rifle"][rr.randi_range(0, 4)]
				out.append([kind, rr.randi_range(2, 6) * (3 if kind == "rifle" else 1)])
			if rr.randf() < 0.08:
				out.append(["coin", 1])
		"salt":
			out.append(["salt", rr.randi_range(6, 12)])
		"herb":
			out.append(["herb", rr.randi_range(1, 3)])
		"bone":
			out.append(["bone", rr.randi_range(2, 4)])
			if rr.randf() < 0.2:
				out.append(["cloth", 1])
	shared("_w_node", [id, nd.charges - 1, day + 2])
	Net.call_peer(by, "_w_gathered", [id, out])


## A pilgrim's own hands, with the right tool, take twice as much.
func _w_gathered(id: int, out: Array) -> void:
	var nk: Dictionary = NODE_KINDS[nodes[id].kind]
	if nk.tool != "" and inv.count(nk.tool) > 0:
		for it in out:
			if it[0] in ["wood", "stone", "salt"]:
				it[1] = int(it[1]) * 2
	var gm: float = skills.gather_mult() * WRules.yield_mult()
	if gm != 1.0:
		for it in out:
			if it[0] != "coin":
				it[1] = maxi(1, int(ceil(int(it[1]) * gm)))
	_w_give(out)
	award("gather")
	quests.on_event("gathered", {})


func _w_node(id: int, charges: int, back: int) -> void:
	var nd: Dictionary = nodes[id]
	nd.charges = charges
	nd.back = back
	nd.node.visible = charges > 0
	nd.body.collision_layer = (1 | 16) if charges > 0 and not nd.kind in ["herb", "bone"] else (16 if charges > 0 else 0)
	if charges > 0 and charges < int(NODE_KINDS[nd.kind].charges):
		nd.node.scale = Vector3.ONE * (0.6 + 0.4 * charges / float(NODE_KINDS[nd.kind].charges))
	elif charges > 0:
		nd.node.scale = Vector3.ONE


## Small stones and dry scrub, for the look of the land only.
func _scatter_decor() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 3131
	var specs := [
		[SphereMesh.new(), _m.darkstone, 5000, Vector2(0.15, 0.6)],
		[CylinderMesh.new(), _m.darkwood, 2500, Vector2(0.4, 1.2)],
	]
	specs[0][0].radius = 0.5
	specs[0][0].height = 0.6
	specs[0][0].radial_segments = 6
	specs[0][0].rings = 3
	specs[1][0].top_radius = 0.0
	specs[1][0].bottom_radius = 0.04
	specs[1][0].height = 1.0
	specs[1][0].radial_segments = 3
	var tar := StandardMaterial3D.new()
	tar.albedo_color = Color(0.03, 0.025, 0.02)
	tar.metallic = 0.6
	tar.roughness = 0.08
	var pools := MultiMesh.new()
	pools.transform_format = MultiMesh.TRANSFORM_3D
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.05
	disc.radial_segments = 14
	pools.mesh = disc
	var spots: Array = []
	for i in 6000:
		var x := r.randf_range(-950, 950)
		var z := r.randf_range(-950, 950)
		if terrain.biome_name(x, z) == "marsh":
			spots.append(Vector3(x, terrain.height_at(x, z) + 0.03, z))
		if spots.size() >= 900:
			break
	pools.instance_count = spots.size()
	for i in spots.size():
		var sc := r.randf_range(1.5, 5.0)
		pools.set_instance_transform(i, Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(sc, 1, sc * r.randf_range(0.5, 1.0))), spots[i]))
	var pmi := MultiMeshInstance3D.new()
	pmi.multimesh = pools
	pmi.material_override = tar
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pmi)
	for sp in specs:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = sp[0]
		mm.instance_count = sp[2]
		for i in mm.instance_count:
			var x := r.randf_range(-950, 950)
			var z := r.randf_range(-950, 950)
			var s := r.randf_range(sp[3].x, sp[3].y)
			var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.5, 1.0), s))
			if sp[1] == _m.darkwood:
				b = Basis.from_euler(Vector3(r.randf_range(-0.6, 0.6), r.randf() * TAU, r.randf_range(-0.6, 0.6))).scaled(Vector3.ONE * s)
			mm.set_instance_transform(i, Transform3D(b, Vector3(x, terrain.height_at(x, z), z)))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = sp[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	# The far reaches, a tile at a time so that only the near ones are drawn
	var fr := RandomNumberGenerator.new()
	fr.seed = world_seed + 3737
	var tile := 512.0
	var tn := int(WPlaces.SIZE / tile)
	for tj in tn:
		for ti in tn:
			var x0 := -WPlaces.HALF + ti * tile
			var z0 := -WPlaces.HALF + tj * tile
			for sp in specs:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = sp[0]
				var pts: Array = []
				for i in int(sp[2] * 0.07):
					var x := x0 + fr.randf() * tile
					var z := z0 + fr.randf() * tile
					if maxf(absf(x), absf(z)) > 955.0 and maxf(absf(x), absf(z)) < 1900.0:
						pts.append(Vector2(x, z))
				if pts.is_empty():
					continue
				mm.instance_count = pts.size()
				for i in pts.size():
					var q: Vector2 = pts[i]
					var sc := fr.randf_range(sp[3].x, sp[3].y)
					var b := Basis(Vector3.UP, fr.randf() * TAU).scaled(Vector3(sc, sc * fr.randf_range(0.5, 1.0), sc))
					if sp[1] == _m.darkwood:
						b = Basis.from_euler(Vector3(fr.randf_range(-0.6, 0.6), fr.randf() * TAU, fr.randf_range(-0.6, 0.6))).scaled(Vector3.ONE * sc)
					mm.set_instance_transform(i, Transform3D(b, Vector3(q.x, terrain.height_at(q.x, q.y), q.y)))
				var mi := MultiMeshInstance3D.new()
				mi.multimesh = mm
				mi.material_override = sp[1]
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.visibility_range_end = 900.0
				add_child(mi)


# ================================================================== time, and the night

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if player == null or not ready_world:
		return
	clock += delta * 24.0 / DAY_SECONDS
	if clock >= 24.0:
		clock -= 24.0
		if Net.authority():
			day += 1
	_apply_time(false)
	if Net.authority():
		_world_tick(delta)
	_needs_tick(delta)
	_reveal_t -= delta
	if _reveal_t <= 0.0 and not Net.dedicated:
		_reveal_t = 0.5
		_reveal_around(player.global_position, 90.0)
		_visit_check()
		quests.refresh_hud()
		if _my_vote and player.global_position.distance_to(_vote_spot) > 8.0:
			vote_sleep(false)
			hud.notify("You left the fire. Your wish to sleep is withdrawn.")
		_crop_t -= 0.5
		if _crop_t <= 0.0:
			_crop_t = 5.0
			for pid in pieces:
				if pieces[pid].kind == "planter" and pieces[pid].crop != "":
					_crop_look(pid)
				elif pieces[pid].kind in FIRE_KINDS:
					_fire_look(pid)
	if downed and Net.online and not failing and not _pfail:
		_bleed_t -= delta
		# Holding jump gives up the wait and wakes at camp
		_give_up_t = _give_up_t + delta if Input.is_action_pressed("jump") else 0.0
		hud.set_banner("Unconscious   %d" % ceili(maxf(_bleed_t, 0.0)),
			"A companion can raise you.   Hold [Space] to wake at camp" + (" (%d)" % ceili(1.5 - _give_up_t) if _give_up_t > 0.0 else ""))
		if _bleed_t <= 0.0:
			hud.set_banner("", "")
			_perish("You bled out in the dust before anyone could raise you.")
		elif _give_up_t >= 1.5:
			hud.set_banner("", "")
			_perish("You let go, and the dust took you.")
	elif _banner_on and not _pfail:
		hud.set_banner("", "")
	_banner_on = downed or _pfail
	_save_t -= delta
	if _save_soon >= 0.0:
		_save_soon -= delta
	if _save_t <= 0.0 or (_save_soon >= 0.0 and _save_soon <= 0.0):
		save_all()


func _world_tick(delta: float) -> void:
	_sync_t -= delta
	if _sync_t <= 0.0 and Net.online:
		_sync_t = 10.0
		shared("_w_clock", [clock, day, nights])
	var is_night := clock >= DUSK or clock < DAWN
	if is_night != night:
		shared("_w_nightfall" if is_night else "_w_dawn", [day])
	if not vigils.is_empty():
		_vigil_tick(delta)
	if night:
		_wave_t -= delta
		if _wave_t <= 0.0:
			_wave_t = maxf(16.0, 34.0 - nights * 1.5)
			_night_wave()
	else:
		_day_t -= delta
		if _day_t <= 0.0:
			_day_t = 6.0
			_day_watch()
	_safe_t -= delta
	if _safe_t <= 0.0:
		_safe_t = 2.0
		_keep_safe()
	_spikes(delta)
	_lair_tick()
	_beast_tick(delta)


func _w_clock(c: float, d: int, n: int) -> void:
	if Net.authority():
		return
	if absf(c - clock) > 0.05:
		clock = c
	day = d
	nights = n


func _w_nightfall(_d: int) -> void:
	night = true
	_wave_t = 25.0
	if Net.authority():
		get_tree().create_timer(randf_range(40.0, 160.0), false).timeout.connect(func():
			if is_instance_valid(self) and night:
				_maybe_raid())
	sfx("drone", -6)
	hud.say("The sun goes down behind the ridges. Night comes to the waste, and the forms come with it.", 6.0)
	quests.on_event("nightfall", {})


func _w_dawn(d: int) -> void:
	night = false
	day = d
	nights += 1
	raiding.clear()
	sleep_votes.clear()
	_my_vote = false
	sfx("choir", -10)
	hud.say("Dawn. You have lived through %s." % _nth_night(nights), 5.0)
	if Net.authority():
		for e in enemies:
			if is_instance_valid(e) and e.is_alive():
				e.die(false)
		_dawn_world()
	quests.on_event("dawn", {})
	award("dawn")
	save_all()


func _nth_night(n: int) -> String:
	var words := ["", "the first night", "the second night", "the third night", "the fourth night", "the fifth night", "the sixth night", "the seventh night"]
	return words[n] if n < words.size() else "%d nights" % n


## At dawn what was taken from the land begins to come back, and the people have new work.
func _dawn_world() -> void:
	for nd in nodes:
		if nd.charges <= 0 and day >= int(nd.back):
			shared("_w_node", [nd.id, int(NODE_KINDS[nd.kind].charges), 0])
	quests.refresh_offers()


# ================================================================== growing

## Gives this survivor experience for a deed (see WSkills.XP).
func award(kind: String, mult := 1.0) -> void:
	if guide:
		guide.event(kind)
	if Net.dedicated or _pfail or not WSkills.XP.has(kind):
		return
	var amount := int(round(WSkills.XP[kind] * mult))
	var ups := skills.gain(amount)
	Game.gain_pxp(maxi(1, amount / 2))
	if ui:
		ui.xp_gained(amount)
	if ups > 0:
		sfx("choir", -4)
		hud.title_card("Level %d" % skills.level, "You have learned something of the waste")
		hud.notify("A point to spend. Press K to see what you might learn.")
		autosave_soon(2.0)


func _apply_skills() -> void:
	if player == null or player.weapon == null:
		return
	var full := player.health >= player.max_health - 0.01
	player.max_health = skills.health_max()
	player.health = player.max_health if full else minf(player.health, player.max_health)
	player.walk_speed = 3.4 * skills.speed_mult()
	player.run_speed = 5.8 * skills.speed_mult()
	player.weapon.reserve_max = skills.reserve_max()
	player.weapon.damage_mult = skills.damage_mult()
	player.weapon.reload_mult = skills.reload_mult()
	inv.grow(skills.pack_size())
	if not Net.dedicated:
		hud.set_health(player.health / player.max_health, true)
	if ui:
		ui.skills_changed()


func _apply_time(force: bool) -> void:
	# The sun rises at six and sets at eighteen; the moon has the rest
	var t := clock / 24.0
	var sun_ang := (t - 0.25) * TAU
	var day_k := clampf(sin(sun_ang) * 3.0 + 0.3, 0.0, 1.0)
	var dusk_k := clampf(1.0 - absf(sin(sun_ang)) * 4.0, 0.0, 1.0) * clampf(day_k * 2.0, 0.0, 1.0)
	if day_k > 0.01:
		sun.rotation = Vector3(-maxf(sin(sun_ang), 0.08) * PI * 0.45 - 0.05, 0.6, 0)
		sun.light_color = Color(1.0, 0.86, 0.68).lerp(Color(1.0, 0.55, 0.3), dusk_k)
		sun.light_energy = 1.45 * day_k
	else:
		sun.rotation = Vector3(-0.9, 2.2, 0)
		sun.light_color = Color(0.5, 0.56, 0.75)
		sun.light_energy = 0.07
	var night_k := 1.0 - day_k
	_sun_mat.sky_top_color = Color(0.4, 0.43, 0.48).lerp(Color(0.01, 0.012, 0.025), night_k)
	_sun_mat.sky_horizon_color = Color(0.72, 0.62, 0.5).lerp(Color(0.85, 0.42, 0.22), dusk_k * 0.8).lerp(Color(0.03, 0.035, 0.05), night_k)
	_sun_mat.ground_horizon_color = _sun_mat.sky_horizon_color
	env.fog_light_color = Color(0.62, 0.55, 0.46).lerp(Color(0.025, 0.03, 0.04), night_k)
	env.fog_density = lerpf(0.0035, 0.011, night_k)
	env.ambient_light_energy = lerpf(0.7, 0.07, night_k)
	if _stars:
		_stars.material_override.albedo_color.a = clampf(night_k * 1.5 - 0.3, 0.0, 1.0)
		_stars.visible = night_k > 0.2


## How many forms the night sends, and of what kind, grows with the nights survived.
func _night_wave() -> void:
	var tg := targets()
	if tg.is_empty():
		return
	var cap := 7 + tg.size() * 3 + mini(nights, 10)
	for t in tg:
		if safe_at(t.global_position):
			continue
		if alive_count() >= cap:
			return
		var n := 2 + int(nights * 0.5) + randi() % 2
		var roster: Array = BIOME_FORMS[terrain.biome_name(t.global_position.x, t.global_position.z)]
		for k in n:
			var e = _spawn_near(roster[randi() % roster.size()], t.global_position, 30.0, 48.0)
			# The night's walkers come looking for the living; they need not see you yet
			if e and e.has_method("seek"):
				e.seek(t.global_position, 40.0)
		if nights >= 2 and randf() < 0.12 + nights * 0.02:
			_spawn_near("saucer", t.global_position, 30.0, 40.0)
		if nights >= 4 and randf() < 0.06 + nights * 0.01:
			_spawn_near("elite", t.global_position, 35.0, 45.0)
			hud.notify("Something greater walks tonight.")
		# Some nights, in the dark country, something follows that is hardly there at all
		var bio: String = terrain.biome_name(t.global_position.x, t.global_position.z)
		var dark := 0.1 if bio in ["forest", "marsh", "basalt"] else 0.04
		if nights >= 1 and randf() < dark + nights * 0.01 and _unseen_count() < tg.size():
			_spawn_near("unseen", t.global_position, 34.0, 46.0)
		if randf() < 0.25:
			sfx("horror_deep", -10, t.global_position + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)), randf_range(0.8, 1.0))


func _unseen_count() -> int:
	var n := 0
	for e in foes.values():
		if is_instance_valid(e) and e.kind == "unseen" and e.is_alive():
			n += 1
	return n


## By day the waste is quieter, but the ruins are not empty, and the roads are not always clear.
func _day_watch() -> void:
	_road_tick(6.0)
	var tg := targets()
	for t in tg:
		var p: Vector3 = t.global_position
		if safe_at(p) or settlement_at(p, 40.0) != "":
			continue
		for r in ruins:
			if int(r.guard_day) != day and p.distance_to(r.pos) < 55.0:
				r.guard_day = day
				var n := 2 + randi() % 3
				for k in n:
					_spawn_near(["rusher", "spitter", "spider", "idol", "brute", "howler", "hollow", "saltbone", "hollow", "warden"][randi() % 10], r.pos, 6.0, 14.0, true)
		if alive_count() < 2 and randf() < 0.08:
			_spawn_near(["rusher", "spider", "swarm"][randi() % 3], p, 40.0, 60.0)


func _spawn_near(kind: String, c: Vector3, rmin: float, rmax: float, anywhere := false) -> LesserSpeeb:
	# The world's rule on numbers: fewer skips some, more brings a second now and then
	var m := WRules.spawn_mult()
	if randf() >= m:
		return null
	if m > 1.0 and randf() < m - 1.0 and kind != "saucer" and kind != "elite":
		_spawn_one(kind, c, rmin, rmax, anywhere)
	return _spawn_one(kind, c, rmin, rmax, anywhere)


func _spawn_one(kind: String, c: Vector3, rmin: float, rmax: float, anywhere := false) -> LesserSpeeb:
	var space := get_world_3d().direct_space_state
	for attempt in 12:
		var a := randf() * TAU
		var d := randf_range(rmin, rmax)
		var x := c.x + cos(a) * d
		var z := c.z + sin(a) * d
		var gy := terrain.height_at(x, z)
		var p := Vector3(x, gy + (randf_range(7.0, 9.0) if kind == "saucer" else (0.6 if kind == "spider" else randf_range(1.2, 2.2))), z)
		if safe_at(p) and not anywhere:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.7
		q.shape = s
		q.transform = Transform3D(Basis(), p)
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			continue
		var e := spawn_at(kind, p)
		if e and kind == "saucer":
			hud.notify("A saucer descends out of the dark.")
		return e
	return null


func _clear_near(p: Vector3, r: float) -> void:
	for e in enemies:
		if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(p) < r:
			e.die(false)


func _haunted() -> bool:
	return false


func _combat_tick(delta: float) -> void:
	_regen_wait -= delta
	if _regen_wait <= 0.0 and player.health < player.max_health and not downed and not Net.dedicated:
		var rate := 0.6
		var by_fire: bool = builder.near_kind(player.global_position, "campfire", 6.0) or settlement_at(player.global_position) != ""
		if by_fire:
			rate = 3.0
		rate *= skills.regen_mult(by_fire)
		player.health = minf(player.max_health, player.health + rate * Game.difficulty_scale("regen") * delta)
		hud.set_health(player.health / player.max_health, true)
	enemies = enemies.filter(func(e): return is_instance_valid(e))
	if _music:
		var near := 0
		for e in enemies:
			if e.global_position.distance_to(player.global_position) < 26.0:
				near += 1
		_music.volume_db = move_toward(_music.volume_db, -10.0 if near > 0 else -60.0, delta * (30.0 if near > 0 else 8.0))


## Spikes bite whatever presses against them.
func _spikes(delta: float) -> void:
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		if pc.kind != "spikes":
			continue
		for e in enemies:
			if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(pc.pos + Vector3(0, 0.8, 0)) < 2.2:
				e.hurt(22.0 * delta, Vector3.ZERO)
				builder.hit_piece(pid, 4.0 * delta)


## A form held back by a wall tears at it instead.
func on_blocked(_e: LesserSpeeb, col: Object, dmg: float) -> bool:
	if col is Node and col.has_meta("piece") and Net.authority():
		builder.hit_piece(int(col.get_meta("piece")), dmg)
		return true
	return false


func on_enemy_slain(e: LesserSpeeb) -> void:
	life_kill()
	kills += 1
	kill_line()
	Game.add_kill(e.kind)
	streak += 1
	_streak_t = 3.5
	hud.set_streak(streak)
	if player.relics:
		player.relics.add_faith(0.04 if e.kind in ["swarm", "mite"] else 0.1)
	shared("_w_slain", [e.global_position, e.kind, Net.me()])
	if e.boss != "":
		shared("_w_boss_down", [e.boss, e.global_position])
		return
	award("kill_elite" if e.kind in ["elite", "saucer"] else "kill")
	if randf() < (0.5 if e.kind in ["elite", "saucer"] else 0.12) + skills.drop_bonus():
		var drop: Array = Items.roll("corpse", 2 if e.kind in ["elite", "saucer"] else 1, _gen)
		if e.kind in ["elite", "saucer"] and _gen.randf() < 0.3:
			drop.append(["fittings_fine" if _gen.randf() < 0.75 else "fittings_rare", 1])
		shared("_rq_satchel", [Net.me(), e.global_position, drop, false])


func team_kill(e: LesserSpeeb) -> void:
	team_kills += 1


func _w_slain(p: Vector3, kind: String, by := 0) -> void:
	quests.on_event("kill", {"pos": p, "kind": kind})
	# A fellow's kill close by teaches a little too
	if by != 0 and by != Net.me() and not Net.dedicated and player.global_position.distance_to(p) < 40.0:
		award("assist")


# ================================================================== falling, and rising again

# ================================================================== the riding cat

## Places a saved cat once the world is there; now and then sets a stray near a town while you have none.
func _cat_tick(delta: float) -> void:
	if not ready_world:
		return
	if not player.interact_pressed.is_connected(_on_interact_pressed):
		player.interact_pressed.connect(_on_interact_pressed)
	if cat == null and not _cat_saved.is_empty():
		var s := _cat_saved
		_cat_saved = {}
		var face := str(s.get("face", "_speeb"))
		if not face in WCat.FACES:
			face = "_speeb"
		cat = WCat.new().setup(self, face, false)
		cat.cat_name = str(s.get("name", "Ember")).left(20)
		cat.barding = str(s.get("barding", "")) if WCat.BARDING.has(str(s.get("barding", ""))) else ""
		cat.hp = clampf(float(s.get("hp", WCat.HP_MAX)), 1.0, WCat.HP_MAX)
		add_child(cat)
		var pos = s.get("pos", [])
		var at := Vector2(player.global_position.x + 4.0, player.global_position.z) if not (pos is Array and pos.size() == 2) else Vector2(float(pos[0]), float(pos[1]))
		cat.global_position = gpos(at)
	if Input.is_action_just_pressed("whistle") and not player.input_locked and cat:
		sfx("bell", -14, null, 2.2)
		cat.call_to(player)
		hud.notify("You whistle for %s." % cat.cat_name)
	_stray_t -= delta
	if _stray_t > 0.0:
		return
	_stray_t = 4.0
	if cat != null:
		if _stray:
			_stray.queue_free()
			_stray = null
		return
	if _stray and is_instance_valid(_stray):
		if _stray.global_position.distance_to(player.global_position) > 160.0:
			_stray.queue_free()
			_stray = null
		return
	# By day, near a town, a stray cat may be about
	var town := settlement_at(player.global_position, 120.0)
	if town == "" or night or randf() > 0.25:
		return
	var a := randf() * TAU
	var at := player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(22.0, 35.0)
	_stray = WCat.new().setup(self, WCat.FACES[randi() % WCat.FACES.size()], true)
	add_child(_stray)
	_stray.global_position = gpos(Vector2(at.x, at.z))


## Interact on a cat: a stray is fed (three meals win it over); your own is mounted.
func cat_used(c: WCat) -> void:
	if c.wild:
		var food := ""
		for f in ["raw_meat", "meat", "roast"]:
			if inv.count(f) > 0:
				food = f
				break
		if food == "":
			hud.notify("The cat sniffs your hands and finds nothing. It would take meat.")
			return
		inv.take(food, 1)
		c.fed += 1
		c._shy = 0.0
		sfx("carve", -12, c.global_position, 1.4)
		if c.fed < 3:
			hud.notify("The cat eats, and watches you. (%d of 3)" % c.fed)
			c._refresh()
			return
		c.wild = false
		c.cat_name = WCat.NAMES[randi() % WCat.NAMES.size()]
		cat = c
		_stray = null
		c._refresh()
		sfx("choir", -10, null, 1.4)
		hud.say("The cat is yours. Its name is %s, unless you give it another. Hold [%s] on it to name it and fit its barding." % [c.cat_name, Game.key_text("interact")], 6.0)
		return
	if c != cat:
		return
	if not c.can_ride():
		hud.notify("%s is hurt and will not carry you yet." % c.cat_name)
		return
	ride()


func cat_menu(c: WCat) -> void:
	if c == cat:
		ui.open_cat()


func ride() -> void:
	if cat == null or player.mount:
		return
	player.global_position = cat.global_position + Vector3(0, 0.3, 0)
	player.yaw = cat.rotation.y - PI
	player.mount = cat
	cat.ridden = true
	cat._refresh()
	sfx("carve", -12, null, 0.8)


func dismount() -> void:
	if cat == null or player.mount == null:
		return
	player.mount = null
	cat.ridden = false
	var side := player.global_transform.basis.x * 1.4
	cat.global_position = gpos(Vector2(player.global_position.x, player.global_position.z))
	player.global_position += side
	cat._refresh()


func _on_interact_pressed() -> void:
	# Riding, with nothing in front to use: get down
	if player.mount and player.target == null and not player.input_locked:
		dismount()


func damage_player(amount: float, from: Vector3) -> void:
	if failing or downed or _pfail or Net.dedicated:
		return
	if player.dodge_t > 0.0 and from.distance_to(player.global_position) < 6.0:
		# Stepped aside in time
		hud.hitmarker(false, true)
		return
	amount *= Game.difficulty_scale("damage") * skills.harm_mult() * (1.0 - WArms.worn(arms).guard)
	var wpn = player.weapon
	if wpn and wpn.guarding and wpn.enabled:
		# The blade is raised: a blow from the front is turned, and it costs breath
		var to := from - player.global_position
		to.y = 0
		var fwd := -player.global_transform.basis.z
		if to.length() < 0.1 or fwd.dot(to.normalized()) > 0.3:
			if player.spend(minf(40.0, 6.0 + amount * 0.6)):
				amount *= 0.25
				sfx("parry", -4)
				player.shake(0.15)
				hud.hitmarker(false, true)
				if amount < 1.0:
					return
	# Riding, the cat takes half of the blow; hurt out, it throws its rider and runs off a while
	if player.mount and cat:
		if cat.take(amount * 0.5):
			dismount()
			hud.say("%s throws you and bolts. It will be back when it has licked its wounds." % cat.cat_name, 4.0)
			cat.call_to(player)
			cat._call = false
		amount *= 0.5
	# Plate worn on the body (or the helm, now and then) soaks part of the blow and wears down
	var pt := WArms.plate_take(arms, amount, randf() < 0.25)
	if pt[0] < amount:
		amount = pt[0]
		sfx("hit_metal", -10)
		_armour_hud()
		if pt[1]:
			hud.say("Your armour has broken. Mend it at a workbench.", 4.0)
			sfx("hit_metal", 0)
	player.shake(0.45)
	if skills.rank("last_light") > 0:
		for i in lit:
			if player.global_position.distance_to(beacon_nodes[i].pos) < 150.0:
				amount *= 0.5
				break
	player.health -= amount
	if player.health <= 0.0 and skills.rank("second_wind") > 0 and skills.second_wind_day != day:
		skills.second_wind_day = day
		player.health = player.max_health / 3.0
		sfx("bell", -6)
		hud.say("The blow should have ended you. Something in you refuses.", 4.0)
	_regen_wait = 7.0
	var local := player.global_transform.basis.inverse() * (from - player.global_position)
	hud.damage_from(atan2(local.x, -local.z))
	sfx("hurt", -2)
	hud.set_health(maxf(player.health, 0.0) / player.max_health, true)
	hud.hurt_flash()
	var push := player.global_position - from
	push.y = 0
	player.velocity += push.normalized() * 3.0
	if player.health <= 0.0:
		if Net.online and targets().size() > 0:
			_bleed_t = 45.0
			_give_up_t = 0.0
			dismount()
			_go_down()
		else:
			_perish("You fell in the dust, and the forms went on without you.")


## How whole the worn plate is, shown as a thin bar over health (hidden when none is worn).
func _armour_hud() -> void:
	var have := 0.0
	var whole := 0.0
	for slot in ["head", "body"]:
		var left := WArms.plate_left(arms, slot)
		if left >= 0.0:
			have += left
			whole += float(WArms.WEAR[str(arms.wear[slot])].plate)
	hud.set_armour(have / whole if whole > 0.0 else -1.0)


func fail(message: String, _sound := "deny") -> void:
	_perish(message)


func on_fall() -> void:
	player.place(gpos(Vector2(player.global_position.x, player.global_position.z)) + Vector3(0, 1, 0), player.yaw)


func net_wipe() -> void:
	if downed:
		_perish("Every one of you fell. The night closed over the place where you stood.")


func _check_wipe() -> void:
	pass


## Death in the waste: what was carried is left where you fell, and you wake where you last slept.
func _perish(message: String) -> void:
	if _pfail:
		return
	dismount()
	life_kills = 0
	_pfail = true
	player.input_locked = true
	if ui:
		ui.close_all()
	var drop: Array = []
	var keep := WRules.get_rule("death") == 1
	for i in inv.slots.size():
		var s = inv.slots[i]
		if not keep and s != null and Items.info(s.id).kind != "tool" and Items.info(s.id).kind != "quest":
			drop.append([s.id, int(s.n)])
			inv.slots[i] = null
	inv.changed.emit()
	if not drop.is_empty():
		shared("_rq_satchel", [Net.me(), player.global_position, drop, true])
	await hud.fade_to(1.0, 1.4)
	hud.clear_say()
	hud.raise_text(true)
	hud.say(message + ("" if keep else "\nWhat you carried lies where you fell."), 5.0)
	var where := "your bedroll" if bedroll != null and builder.near_kind(bedroll, "bedroll", 1.0) else "the nearest town"
	for left in range(5, 0, -1):
		hud.set_banner("", "You will wake at %s in %d" % [where, left])
		await get_tree().create_timer(1.1, false).timeout
	hud.set_banner("", "")
	hud.raise_text(false)
	if downed:
		_rise(1.0)
	player.place(respawn_point(), player.yaw)
	player.health = player.max_health
	player.weapon.shells = player.weapon.capacity()
	player.weapon.add_shells(12)
	food = maxf(food, 40.0)
	rest = maxf(rest, 40.0)
	hud.set_health(1.0, true)
	player.input_locked = false
	_pfail = false
	hud.fade_to(0.0, 1.5)


## Raising a fallen companion: smelling salts make it quick and leave them stronger.
func raise_hold() -> float:
	return 1.5 if inv.count("salts") > 0 else 5.0


func raise_strength(spend: bool) -> float:
	if inv.count("salts") > 0:
		if spend:
			inv.take("salts", 1)
			hud.notify("The salts are spent.")
		return 0.75
	return 0.3


func respawn_point() -> Vector3:
	if bedroll != null and builder.near_kind(bedroll, "bedroll", 1.0):
		return bedroll + Vector3(0, 0.6, 1.2)
	var best := gpos(WPlaces.spos("cinderwick"))
	var bd := INF
	for k in visited:
		var c := gpos(WPlaces.spos(k))
		var d := c.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = c
	return best + Vector3(4, 0.5, 4)


# ================================================================== the map

func _reveal_around(p: Vector3, radius: float) -> void:
	var cell := WPlaces.SIZE / REVEAL_N
	var ci := int((p.x + WPlaces.HALF) / cell)
	var cj := int((p.z + WPlaces.HALF) / cell)
	var rc := int(ceil(radius / cell))
	var changed := false
	for j in range(cj - rc, cj + rc + 1):
		for i in range(ci - rc, ci + rc + 1):
			if i < 0 or j < 0 or i >= REVEAL_N or j >= REVEAL_N:
				continue
			if Vector2(i - ci, j - cj).length() * cell <= radius and revealed[j * REVEAL_N + i] == 0:
				revealed[j * REVEAL_N + i] = 1
				changed = true
	if changed and ui:
		ui.map_dirty = true


func reveal_place(p: Vector2, radius: float) -> void:
	_reveal_around(Vector3(p.x, 0, p.y), radius)


func is_revealed(p: Vector3) -> bool:
	var cell := WPlaces.SIZE / REVEAL_N
	var i := clampi(int((p.x + WPlaces.HALF) / cell), 0, REVEAL_N - 1)
	var j := clampi(int((p.z + WPlaces.HALF) / cell), 0, REVEAL_N - 1)
	return revealed[j * REVEAL_N + i] != 0


var _biome := ""


func _visit_check() -> void:
	var bn := terrain.biome_name(player.global_position.x, player.global_position.z)
	if bn != _biome:
		if _biome != "":
			hud.notify("%s\n%s" % [WTerrain.BIOME_NAMES[bn], BIOME_TEXT[bn]])
		_biome = bn
		if not seen_biomes.has(bn):
			seen_biomes[bn] = true
			if seen_biomes.size() > 1:
				award("biome")
	player.speed_cap = 3.6 if bn == "marsh" and settlement_at(player.global_position, 4.0) == "" else -1.0
	var k := settlement_at(player.global_position, 10.0)
	if k != "" and not visited.has(k):
		visited[k] = true
		hud.title_card("", WPlaces.SETTLEMENTS[k].name)
		hud.notify(WPlaces.SETTLEMENTS[k].blurb)
		award("settlement")
		quests.on_event("reach", {})
	for r in ruins:
		if not known_ruins.has(r.id) and player.global_position.distance_to(r.pos) < 40.0:
			known_ruins[r.id] = true
			hud.notify(r.name)
			award("ruin")
	quests.on_event("move", {"pos": player.global_position})


# ================================================================== the fellowship

var _waiting_hello: Array = []


func _rq_hello(by: int) -> void:
	if not Net.authority() or by == Net.me():
		return
	if not ready_world or world_uid == "":
		_waiting_hello.append(by)
		return
	Net.call_peer(by, "_w_snapshot", [world_data()])


func _w_snapshot(d: Dictionary) -> void:
	if terrain == null:
		_make_world(int(d.get("seed", 1771)))
		player.place(spawn_pos, spawn_yaw)
	apply_world(d)
	ready_world = true
	_world_ready()
	player.set_physics_process(true)
	hud.notify("You stand in the same waste as the fellowship. Day %d." % day)


func net_left(id: int) -> void:
	super.net_left(id)
	autosave_soon(1.0)


# ================================================================== keeping it

func world_data() -> Dictionary:
	var mined := {}
	for nd in nodes:
		if nd.charges < int(NODE_KINDS[nd.kind].charges):
			mined[nd.id] = [nd.charges, nd.back]
	var pcs := {}
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		pcs[pid] = [pc.kind, pc.pos, pc.yaw, pc.hp, pc.get("open", false), {"name": pc.get("name", ""), "crop": pc.get("crop", ""), "sown": pc.get("sown", 0.0), "fuel": pc.get("fuel", -1.0)}]
	var crate_days := {}
	for id in crates:
		if int(crates[id].day) > -99:
			crate_days[id] = crates[id].day
	var sat := {}
	for sid in satchels:
		sat[sid] = [satchels[sid].pos, satchels[sid].grave]
	return {
		"v": 2, "uid": world_uid, "seed": world_seed, "day": day, "clock": clock, "nights": nights, "night": night, "lit": lit, "flags": flags, "rep": rep,
		"mined": mined, "pieces": pcs, "piece_next": piece_next, "containers": containers, "crates": crate_days,
		"satchels": sat, "satchel_next": satchel_next, "quests": quests.to_data(), "tracked": quests.tracked,
		"marks": map_marks, "rules": rules,
	}


func apply_world(d: Dictionary) -> void:
	world_uid = str(d.get("uid", world_uid))
	day = int(d.get("day", 1))
	clock = float(d.get("clock", 7.0))
	nights = int(d.get("nights", 0))
	night = bool(d.get("night", false))
	lit = d.get("lit", [])
	flags = d.get("flags", {})
	rep = d.get("rep", {})
	for id in d.get("mined", {}):
		var m: Array = d.mined[id]
		_w_node(int(id), int(m[0]), int(m[1]))
	for pid in d.get("pieces", {}):
		var p: Array = d.pieces[pid]
		builder._w_piece(int(pid), p[0], p[1], p[2], p[3])
		if p[4]:
			builder._w_door(int(pid), true)
		if p.size() > 5 and p[5] is Dictionary:
			_w_portal_name(int(pid), str(p[5].get("name", "")))
			_w_plant(int(pid), str(p[5].get("crop", "")), float(p[5].get("sown", 0.0)))
		# Fires laid before they burned wood start with a full three days
		if str(p[0]) in FIRE_KINDS:
			var f := float(p[5].get("fuel", -1.0)) if p.size() > 5 and p[5] is Dictionary else -1.0
			_w_fuel(int(pid), f if f >= 0.0 else world_hours() + FUEL_START)
	piece_next = int(d.get("piece_next", 1))
	containers = d.get("containers", {})
	for id in d.get("crates", {}):
		_w_crate_day(id, int(d.crates[id]))
	for sid in d.get("satchels", {}):
		_w_satchel(sid, d.satchels[sid][0], d.satchels[sid][1])
	satchel_next = int(d.get("satchel_next", 1))
	rules = WRules.clean(d.get("rules"))
	Game.wrules = rules
	map_marks = []
	for m in d.get("marks", []):
		if m is Array and m.size() >= 2 and m[0] is Vector3:
			map_marks.append([m[0], int(m[1])])
	quests.from_data(d.get("quests", {}))
	# One coming in late follows what the fellowship follows
	if not Net.authority() and quests.quests.has(str(d.get("tracked", ""))):
		quests.tracked = str(d.tracked)
		quests.refresh_hud()
	for i in lit:
		_light_beacon(i, true)
	_apply_time(true)


func char_data() -> Dictionary:
	return {
		"v": 2, "inv": inv.to_data(), "shells": player.weapon.shells, "reserve": player.weapon.reserve, "arms": player.weapon.ammo_state(), "hp": player.health,
		"pos": player.global_position if player.is_inside_tree() else player.position, "yaw": player.yaw, "revealed": Marshalls.raw_to_base64(revealed),
		"visited": visited, "known": known_ruins, "skills": skills.to_data(), "biomes": seen_biomes, "bedroll": bedroll, "warms": arms, "food": food, "rest": rest,
		"guide": guide.step if guide else -1, "cat": cat.to_data() if cat else _cat_saved,
	}


func apply_char(d: Dictionary) -> void:
	if guide:
		guide.begin(int(d.get("guide", -1)))
	skills.from_data(d.get("skills", {}))
	_apply_skills()
	seen_biomes = d.get("biomes", {}) if d.get("biomes") is Dictionary else {}
	inv.from_data(d.get("inv", []))
	arms = WArms.clean(d.get("warms"))
	_cat_saved = d.get("cat", {}) if d.get("cat") is Dictionary else {}
	if cat:
		dismount()
		cat.queue_free()
		cat = null
	food = clampf(float(d.get("food", 100.0)), 0.0, 100.0)
	rest = clampf(float(d.get("rest", 100.0)), 0.0, 100.0)
	Game.warms = arms
	player.weapon.equip_loadout()
	player.weapon.shells = int(d.get("shells", player.weapon.capacity()))
	if int(d.get("v", 1)) < 2:
		inv.add("shells", int(d.get("reserve", 18)))
	player.weapon.set_ammo_state(d.get("arms"))
	player.health = clampf(float(d.get("hp", 100.0)), 20.0, player.max_health)
	hud.set_health(player.health / player.max_health, true)
	_armour_hud()
	var p = d.get("pos")
	if p is Vector3:
		player.place(p + Vector3(0, 0.3, 0), float(d.get("yaw", 0.0)))
	var rv = d.get("revealed", "")
	if rv is String and rv != "":
		var raw := Marshalls.base64_to_raw(rv)
		if raw.size() == revealed.size():
			revealed = raw
		elif raw.size() == 128 * 128:
			# Drawn before the waste grew: the old map is the middle of the new one, cell for cell
			for j in 128:
				for i in 128:
					revealed[(j + 64) * REVEAL_N + i + 64] = raw[j * 128 + i]
	visited = d.get("visited", {})
	known_ruins = d.get("known", {})
	bedroll = d.get("bedroll", null)
	player.weapon._ui()


static func world_path(s: String) -> String:
	return "user://wasteland/world_%s.dat" % s


func _char_path() -> String:
	return "user://wasteland/char_%s.dat" % world_uid


func _load_world() -> void:
	if not _pending.is_empty():
		apply_world(_pending)
		_pending = {}
	if world_uid == "":
		world_uid = "%d%d" % [Time.get_unix_time_from_system(), randi() % 100000]
		rules = WRules.clean(Game.new_world_rules)
		Game.wrules = rules
		quests.start_new()
		quests.refresh_offers()


func _load_character() -> void:
	if world_uid == "":
		while world_uid == "" and is_inside_tree():
			await get_tree().process_frame
	var d = Game.read_var_safe(_char_path())
	# New to a fellowship already on the road: come in beside the others. A returning pilgrim
	# takes up where they left off.
	if Net.online and not Net.authority() and not d is Dictionary:
		shared("_rq_near", [Net.me()])
	if d is Dictionary:
		apply_char(d)
		return
	# Cast out with almost nothing, and shown the first steps
	if guide:
		guide.begin(0)
	inv.from_data([])
	inv.add("bandage", 2)
	inv.add("meat", 2)
	inv.add("salt", 12)
	inv.add("shells", 18)
	inv.add("rounds", 24)
	inv.add("milk", 1)
	player.weapon.equip_loadout()
	player.weapon.shells = player.weapon.capacity()
	player.weapon._ui()


## Keeps the world (if this is the host) and this survivor's own character.
## Both are written crash-safe, with the previous save kept as a backup.
func save_all() -> void:
	# This also runs from _exit_tree, after the player has already left the tree; its data is still good
	if world_uid == "" or not is_instance_valid(player):
		return
	DirAccess.make_dir_recursive_absolute("user://wasteland")
	var ok := true
	if _owns_world:
		ok = Game.write_safe(world_path(slot), var_to_str(world_data())) and ok
	if not Net.dedicated and not _pfail:
		ok = Game.write_safe(_char_path(), var_to_str(char_data())) and ok
	_save_t = _save_every()
	_save_soon = -1.0
	_last_save = Time.get_ticks_msec()
	if is_instance_valid(ui) and ui.is_inside_tree() and not Net.dedicated:
		ui.saved_mark(ok)
	if not ok:
		push_warning("Wasteland: a save could not be written")


func _save_every() -> float:
	return 60.0 * Game.autosave_min if Game.autosave_min > 0 else 1e9


## Asks for a save a few seconds from now: something worth keeping just happened. Several such
## moments close together make one save.
func autosave_soon(delay := 3.0) -> void:
	if _save_soon < 0.0 or delay < _save_soon:
		_save_soon = delay


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_CRASH:
			if ready_world:
				save_all()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Alt-tabbing away: keep things, but not more than once every 20 seconds
			if ready_world and Time.get_ticks_msec() - _last_save > 20000:
				save_all()


## A short line for the title screen's list of worlds.
static func describe(s: String) -> String:
	var d = Game.read_var_safe(world_path(s))
	if not d is Dictionary:
		return ""
	return "Day %d, %d of 9 beacons burning, seed %d" % [int(d.get("day", 1)), d.get("lit", []).size(), int(d.get("seed", 1771))]


# ================================================================== calls the fellowship shares, passed on to their keepers

func _rq_build(by: int, k: String, p: Vector3, yaw: float, hm := 1.0) -> void:
	builder._rq_build(by, k, p, yaw, hm)


func _rq_unbuild(by: int, pid: int) -> void:
	builder._rq_unbuild(by, pid)


func _w_piece(pid: int, k: String, p: Vector3, yaw: float, hp: float) -> void:
	builder._w_piece(pid, k, p, yaw, hp)
	if ready_world:
		autosave_soon(5.0)


func _w_piece_hp(pid: int, hp: float) -> void:
	builder._w_piece_hp(pid, hp)


func _w_piece_gone(pid: int) -> void:
	builder._w_piece_gone(pid)
	if ready_world:
		autosave_soon(5.0)


func _rq_door(pid: int) -> void:
	builder._rq_door(pid)


func _w_door(pid: int, open: bool) -> void:
	builder._w_door(pid, open)


func _rq_qadvance(qid: String, stage: int) -> void:
	quests.advance(qid, stage)


func _w_quest(qid: String, q: Dictionary) -> void:
	quests.quests[qid] = q
	if qid == "main":
		q.steps = WQuests.MAIN
	quests._place_things(qid)
	quests.refresh_hud()
	if ui:
		ui.journal_dirty = true
	autosave_soon(2.0)


func _w_qstep(qid: String, stage: int) -> void:
	quests.step_done(qid, stage)
	if ui:
		ui.journal_dirty = true
	award("step_main" if qid == "main" else "step")
	autosave_soon(2.0)


func _w_offers(o: Dictionary) -> void:
	quests.offers = o


func _rq_accept(by: int, k: String, key: String) -> void:
	quests.rq_accept(by, k, key)


## The host answers a pilgrim who has just come in: where the rest of the fellowship stands.
func _rq_near(by: int) -> void:
	if not Net.authority() or by == Net.me():
		return
	var at = null
	if not Net.dedicated and player.is_inside_tree():
		at = player.global_position
	else:
		for id in avatars:
			var a = avatars[id]
			if id != by and is_instance_valid(a) and a.visible:
				at = a.global_position
				break
	if at == null:
		return
	var off := Vector3(2.5, 0, 0).rotated(Vector3.UP, randf() * TAU)
	Net.call_peer(by, "_w_near", [at + off, randf() * TAU])


func _w_near(at: Vector3, yaw: float) -> void:
	# Wait until this pilgrim's own things are loaded, so nothing moves them back afterwards
	for i in 30:
		if ready_world:
			break
		await get_tree().create_timer(0.2, false).timeout
	await get_tree().create_timer(0.3, false).timeout
	player.place(ground_below(at) + Vector3(0, 0.3, 0), yaw)
	hud.notify("You join the others.")


## A quest taken up by anyone in the fellowship: all of them follow it on the compass.
func _w_taken(by: int, qid: String) -> void:
	if not quests.quests.has(qid):
		return
	if by == Net.me() or not Net.online:
		_w_track(qid)
		return
	quests.tracked = qid
	quests.refresh_hud()
	sfx("bell", -8, null, 1.3)
	hud.notify("%s took up: %s\n%s" % [Net.name_of(by), quests.quests[qid].title, quests.step_text(quests.quests[qid])])
	if ui:
		ui.journal_dirty = true


func _w_track(qid: String) -> void:
	quests.tracked = qid
	quests.refresh_hud()
	if quests.quests.has(qid):
		hud.notify("Taken up: %s\n%s" % [quests.quests[qid].title, quests.step_text(quests.quests[qid])])


func _w_note(text: String) -> void:
	hud.notify(text)


# ------------------------------------------------------------------ nests, and the lost

class Nest extends StaticBody3D:
	var w
	var qid := ""
	var hp := 260.0
	var _alive := true
	var _t := 0.0
	var _guard_t := 3.0
	var _mesh: MeshInstance3D

	func is_alive() -> bool:
		return _alive

	func hurt(amount: float, _dir: Vector3) -> bool:
		if not _alive:
			return false
		_mesh.scale = Vector3.ONE * 1.15
		w.shared("_rq_nest_hit", [qid, amount])
		return true

	func _process(delta: float) -> void:
		_t += delta
		_mesh.scale = _mesh.scale.lerp(Vector3.ONE * (1.0 + sin(_t * 2.4) * 0.06), minf(1.0, delta * 6.0))
		if not Net.authority() or not _alive:
			return
		_guard_t -= delta
		if _guard_t <= 0.0:
			_guard_t = 14.0
			for t in w.targets():
				if t.global_position.distance_to(global_position) < 45.0 and w.alive_count() < 10:
					for k in 3:
						w._spawn_near(["swarm", "rusher", "spider"][randi() % 3], global_position, 4.0, 9.0, true)
					w.sfx("screech", -2, global_position, 0.8)
					break


func make_nest(qid: String, p: Vector3) -> Node3D:
	var n := Nest.new()
	n.w = self
	n.qid = qid
	n.collision_layer = 2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.6
	cs.shape = sh
	cs.position.y = 1.2
	n.add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.7
	sm.height = 2.6
	mi.mesh = sm
	var m := mat(Color(0.28, 0.06, 0.07), 0.4, 0.6, 1.5)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.05, 0.03)
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	mi.position.y = 1.2
	n._mesh = mi
	n.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.15, 0.08)
	l.light_energy = 1.5
	l.omni_range = 9.0
	l.position.y = 2.0
	n.add_child(l)
	add_child(n)
	p.y = terrain.height_at(p.x, p.z)
	n.global_position = p
	return n


func _rq_nest_hit(qid: String, amount: float) -> void:
	if not Net.authority() or not quests.nests.has(qid):
		return
	var n = quests.nests[qid]
	if not is_instance_valid(n) or not n._alive:
		return
	n.hp -= amount
	if n.hp <= 0.0:
		n._alive = false
		shared("_w_nest_burst", [qid])
		quests.advance(qid, int(quests.quests[qid].stage))


func _w_nest_burst(qid: String) -> void:
	if quests.nests.has(qid) and is_instance_valid(quests.nests[qid]):
		var n: Node3D = quests.nests[qid]
		burst(n.global_position + Vector3(0, 1.2, 0), Color(0.5, 0.05, 0.05))
		sfx("dissolve", 0, n.global_position, 0.6)
		n._alive = false
		n.visible = false


func make_lost(qid: String, p: Vector3, nm: String) -> Node3D:
	p.y = terrain.height_at(p.x, p.z)
	var f := figure(p, randf() * TAU, Color(0.4, 0.36, 0.32), true)
	var body: StaticBody3D = f.get_meta("body")
	body.collision_layer = 1 | 16
	personal_interactable(body, "Speak with %s" % nm, func():
		hud.say("%s: \"I thought no one would come. I have been hiding here since the night before last. Tell them... no. I will tell them myself. I am going home.\"" % nm, 6.0)
		quests.ask_advance(qid))
	return f


## Testing aid: says what the waste holds, then leaves.
func debug_report() -> void:
	print("WASTE nodes=%d ruins=%d crates=%d people=%d quests=%d offers=%d pos=%s y=%.1f clock=%.2f" % [nodes.size(), ruins.size(), crates.size(), people.size(), quests.quests.size(), quests.offers.size(), str(player.global_position), terrain.height_at(player.global_position.x, player.global_position.z), clock])
	print("WASTE objective: ", hud.objective.text.replace("\n", " | "))
	save_all()
	get_tree().quit()


## Testing aid: walks the survivor through a day's work and prints what came of each step.
func debug_play() -> void:
	var c := gpos(WPlaces.spos("cinderwick"))
	player.place(c + Vector3(0, 0.5, 6), 0.0)
	await get_tree().create_timer(1.5).timeout
	print("PLAY at cinderwick, main stage ", quests.main_stage(), " visited ", visited.keys())
	for o in quests.talk_options("maud"):
		print("PLAY maud option: ", o[0])
		o[1].call()
	await get_tree().create_timer(0.5).timeout
	print("PLAY main stage ", quests.main_stage(), " beacon oil ", inv.count("beacon_oil"))
	var offer: Array = quests.offers.get("cinderwick", [])
	if not offer.is_empty():
		quests.accept(offer[0])
		await get_tree().create_timer(0.3).timeout
		print("PLAY accepted: ", offer[0].title, " / active ", quests.active().size())
	var nd: Dictionary = nodes[nodes.size() - 1]
	_gather(nd.id)
	await get_tree().create_timer(0.3).timeout
	print("PLAY gathered from ", nd.kind, ": pack ", inv.to_data().filter(func(x): return x != null))
	inv.add("wood", 40)
	inv.add("cloth", 5)
	var spot := gpos(Vector2(c.x + 70, c.z + 30))
	player.place(spot + Vector3(0, 0.5, 0), 0.0)
	await get_tree().create_timer(0.5).timeout
	builder._rq_build(1, "floor", Vector3(floorf(spot.x / 3) * 3 + 1.5, spot.y + 0.2, floorf(spot.z / 3) * 3 + 1.5), 0.0)
	builder._rq_build(1, "wall", Vector3(floorf(spot.x / 3) * 3 + 1.5, spot.y, floorf(spot.z / 3) * 3), 0.0)
	builder._rq_build(1, "chest", spot + Vector3(4, 0, 4), 0.0)
	await get_tree().create_timer(0.3).timeout
	print("PLAY pieces ", pieces.size(), " containers ", containers.keys())
	var cid: String = crates.keys()[0]
	_rq_open(1, cid)
	await get_tree().create_timer(0.3).timeout
	print("PLAY crate ", cid, " holds ", containers.get(cid))
	_rq_take(1, cid, 0)
	await get_tree().create_timer(0.3).timeout
	clock = 19.99
	await get_tree().create_timer(1.0).timeout
	_wave_t = 0.0
	await get_tree().create_timer(2.0).timeout
	print("PLAY night=", night, " forms=", alive_count())
	_w_vigil(0, 3.0)
	await get_tree().create_timer(5.0).timeout
	print("PLAY lit ", lit, " main stage ", quests.main_stage())
	save_all()
	print("PLAY saved; world file ", FileAccess.file_exists(world_path(slot)))
	get_tree().quit()


## Testing aid: keeps a vigil at the first beacon, then reports what was kept from the last visit.
func debug_vigil() -> void:
	print("VIGIL loaded: day %d clock %.1f pieces %d main stage %d pack %s" % [day, clock, pieces.size(), quests.main_stage(), inv.to_data().filter(func(x): return x != null)])
	player.place(beacon_nodes[0].pos + Vector3(0, 2.5, 8), 0.0)
	await get_tree().create_timer(1.0).timeout
	_beacon_touched(0)
	await get_tree().create_timer(0.5).timeout
	vigils[0] = 2.0
	await get_tree().create_timer(4.0).timeout
	print("VIGIL lit ", lit, " main stage ", quests.main_stage(), " forms ", alive_count(), " safe ", safe_at(player.global_position))
	get_tree().quit()


## Testing aid: stands at the south gate of Cinderwick, then opens the map, then the talk of its elder.
func debug_show() -> void:
	print("UI size ", ui.size, " compass ", ui._compass.get_global_rect(), " clock ", ui._clock.get_global_rect(), " root ", hud.root.size)
	var c := gpos(WPlaces.spos("cinderwick"))
	player.place(c + Vector3(0, 0.5, 44), 0.0)
	reveal_place(WPlaces.spos("cinderwick"), 260.0)
	await get_tree().create_timer(7.0).timeout
	ui.open_map()
	await get_tree().create_timer(5.0).timeout
	ui.close_all()
	ui.open_dialogue("maud")
	await get_tree().create_timer(5.0).timeout
	ui.close_all()
	clock = 22.0
	player.place(beacon_nodes[0].pos + Vector3(0, 1.0, 30), 0.0)
	lit.append(0)
	_light_beacon(0, true)


func debug_mapshot() -> void:
	reveal_place(WPlaces.spos("cinderwick"), 300.0)
	reveal_place(WPlaces.bpos(0), 120.0)
	visited["cinderwick"] = true
	ui.open_map()


func debug_talkshot() -> void:
	player.place(people.maud.pos + Vector3(0, 0.5, 3), 0.0)
	ui.open_dialogue("maud")


func debug_facetalk() -> void:
	var m: Vector3 = people.maud.pos
	var e: Dictionary = people.maud
	var off := Vector3(1.6, 0, 0).rotated(Vector3.UP, float(e.yaw) + 1.2)
	player.place(m + off + Vector3(0, 0.3, 0), atan2(off.x, off.z))
	player.pitch = -0.05
	await get_tree().create_timer(0.5).timeout
	ui.open_dialogue("maud")
	await get_tree().create_timer(0.3).timeout
	ui._frame.visible = false
	await get_tree().create_timer(0.6).timeout
	var to: Vector3 = player.global_position - e.node.global_position
	print("FACE yaw0 %.2f now %.2f want %.2f mouth %.2f" % [e.yaw, e.node.rotation.y, atan2(to.x, to.z), e.fig._mouth.scale.y])
	ui.close_all()
	await get_tree().create_timer(3.5).timeout
	print("BACK now %.2f yaw0 %.2f mouth %.2f" % [e.node.rotation.y, e.yaw, e.fig._mouth.scale.y])


func debug_nightshot() -> void:
	clock = 22.0
	night = true
	lit.append(0)
	_light_beacon(0, true)
	player.place(beacon_nodes[0].pos + Vector3(0, 1.0, 34), 0.0)
	player.pitch = 0.15


func debug_coop_host() -> void:
	var am: Dictionary = Game.arms_now()
	if not am.has("mounts") or not (am.mounts is Dictionary):
		am["mounts"] = {}
	am.mounts[player.weapon.gun()] = ["red_dot", "ext_mag"]
	var p := gpos(WPlaces.spos("cinderwick")) + Vector3(80, 0, 20)
	builder._rq_build(1, "chest", p, 0.0)
	_w_vigil_end(0, true)
	await get_tree().create_timer(12.0).timeout
	print("HOST pieces %d lit %s avatars %d foes %d quests %d" % [pieces.size(), lit, avatars.size(), foes.size(), quests.active().size()])


func debug_coop_join() -> void:
	await get_tree().create_timer(8.0).timeout
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	print("JOIN ready %s uid %s day %d pieces %d lit %s main %d offers %d" % [ready_world, world_uid, day, pieces.size(), lit, quests.main_stage(), quests.offers.size()])
	var cid: String = crates.keys()[3]
	_search(cid)
	await get_tree().create_timer(3.0).timeout
	print("JOIN crate ", containers.get(cid))
	shared("_rq_take", [Net.me(), cid, 0])
	await get_tree().create_timer(3.0).timeout
	print("JOIN pack ", inv.to_data().filter(func(x): return x != null), " shells ", player.weapon.reserve)
	var nd: Dictionary = nodes[5]
	_gather(nd.id)
	await get_tree().create_timer(3.0).timeout
	print("JOIN node charges ", nodes[5].charges, " pack ", inv.to_data().filter(func(x): return x != null))
	# Putting something into a crate must take it out of the pack, once
	var slot := -1
	for i in inv.slots.size():
		if inv.slots[i] != null:
			slot = i
			break
	if slot >= 0:
		var it = inv.slots[slot]
		var before := inv.count(it.id)
		ui._cont_id = cid
		ui._put(slot)
		await get_tree().create_timer(3.0).timeout
		print("JOIN put %s: pack %d -> %d, crate has %d" % [it.id, before, inv.count(it.id), _cont_count(cid, it.id)])
	for a in avatars.values():
		print("JOIN sees host gun ", a._gun_key)


func _cont_count(cid: String, item: String) -> int:
	var n := 0
	for x in containers.get(cid, []):
		if x != null and x[0] == item:
			n += int(x[1])
	return n



func _world_ready() -> void:
	if ui:
		ui.map_dirty = true


func debug_fullmap() -> void:
	revealed.fill(1)
	for k in WPlaces.SETTLEMENTS:
		visited[k] = true
	for r in ruins:
		known_ruins[r.id] = true
	ui.open_map()
	var counts := {}
	for nd in nodes:
		counts[nd.kind] = counts.get(nd.kind, 0) + 1
	print("SEED ", world_seed, " nodes ", counts)


## Testing aid: earns a few levels, learns some skills, and checks that they take hold and are kept.
func debug_skills() -> void:
	await get_tree().create_timer(1.0).timeout
	print("SKILLS start level %d xp %d points %d hp %.0f pack %d" % [skills.level, skills.xp, skills.points, player.max_health, inv.slots.size()])
	if skills.level == 1:
		award("beacon", 4.0)
		print("SKILLS after 1000 xp: level %d xp %d points %d" % [skills.level, skills.xp, skills.points])
		for id in ["hardy", "hardy", "scavenger", "light_step", "steady_hand", "thrift", "deep_pockets"]:
			print("SKILLS learn %s: %s (%s)" % [id, skills.learn(id), skills.blocked(id)])
		print("SKILLS hp %.0f speed %.2f pack %d dmg %.2f cost floor %s" % [player.max_health, player.walk_speed, inv.slots.size(), player.weapon.damage_mult, skills.cost(Items.PIECES["floor"].cost)])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


## Test: the Arms page of the pack, with a bench at hand and enough to make things.
func debug_armsshot() -> void:
	await get_tree().create_timer(2.0).timeout
	for it in [["scrap", 40], ["scrap", 30], ["wood", 30], ["oil", 6], ["cloth", 8], ["salt", 120], ["coin", 12], ["bandage", 3], ["bone", 14], ["boots", 1]]:
		inv.add(it[0], it[1])
	ui.debug_bench = true
	arms.owned.append("machine_gun")
	arms.primary = "machine_gun"
	arms.parts["machine_gun"] = ["red_dot", "foregrip"]
	arms.mounts["machine_gun"] = ["red_dot", "foregrip"]
	arms.tier["machine_gun"] = 1
	arms.wear = {"body": "padded_coat", "head": "hood"}
	arms.relics = ["claw"]
	rearm()
	_save_t = 9999.0
	ready_world = false
	if "pack" in OS.get_cmdline_user_args():
		ui._sel = 0
		ui.open_inventory("pack")
	elif not "hud" in OS.get_cmdline_user_args():
		ui.open_inventory("arms")


## Test: a camp is raided; forms near it otherwise are taken by the safe ground.
func debug_raid() -> void:
	await get_tree().create_timer(2.0).timeout
	var c := player.global_position + Vector3(4, 0, 0)
	builder._rq_build(1, "campfire", c, 0.0)
	await get_tree().create_timer(0.5).timeout
	print("RAID safe at camp ", safe_at(c), " base ", base_at(c), " safe 100 m off ", safe_at(c + Vector3(100, 0, 0)))
	var stray := spawn_at("rusher", c + Vector3(10, 1.5, 0))
	clock = 21.0
	night = true
	nights = 3
	await get_tree().create_timer(3.0).timeout
	print("RAID stray taken: ", not is_instance_valid(stray) or not stray.is_alive())
	var before := alive_count()
	_night_wave()
	await get_tree().create_timer(0.5).timeout
	print("RAID night wave near camp spawned ", alive_count() - before)
	var keep := RAID_CHANCE
	nights = 3
	for i in 40:
		_maybe_raid()
		if not raiding.is_empty():
			break
	await get_tree().create_timer(24.0).timeout
	var raiders := enemies.filter(func(e): return is_instance_valid(e) and e.is_alive() and e.has_meta("raid")).size()
	print("RAID raiding ", raiding.keys(), " raiders alive ", raiders)
	if DisplayServer.get_name() == "headless":
		get_tree().quit()


## Test: the new pieces of a camp, a planter grown and lifted, two waystones paired.
func debug_camp() -> void:
	await get_tree().create_timer(2.0).timeout
	var c := player.global_position
	var fwd := -player.global_transform.basis.z
	var side := player.global_transform.basis.x
	inv.add("tuber_seed", 3)
	inv.add("wood", 30)
	var at := func(f: float, sd: float) -> Vector3:
		var p: Vector3 = c + fwd * f + side * sd
		return Vector3(p.x, terrain.height_at(p.x, p.z), p.z)
	builder._rq_build(1, "campfire", at.call(6.0, 0.0), 0.0)
	builder._rq_build(1, "torch", at.call(5.0, -3.0), 0.0)
	builder._rq_build(1, "planter", at.call(6.0, 3.5), player.yaw)
	builder._rq_build(1, "portal", at.call(11.0, -1.5), player.yaw)
	builder._rq_build(1, "portal", at.call(60.0, 30.0), player.yaw)
	builder._rq_build(1, "stairs", at.call(9.0, 5.0), player.yaw)
	builder._rq_build(1, "bedroll", at.call(4.0, 2.0), player.yaw)
	await get_tree().create_timer(0.5).timeout
	var planter := -1
	var portals: Array = []
	for pid in pieces:
		if pieces[pid].kind == "planter":
			planter = pid
		if pieces[pid].kind == "portal":
			portals.append(pid)
	inv.take("tuber_seed", 1)
	_rq_plant(1, planter, "tuber_seed")
	print("CAMP planted, left %.1f h" % crop_left(planter))
	pieces[planter].sown -= 13.0
	_crop_look(planter)
	print("CAMP after 13 h, left %.1f h" % crop_left(planter))
	pieces[planter].sown -= 2.0
	var before := inv.count("tuber")
	_rq_harvest(1, planter)
	print("CAMP harvested tubers ", inv.count("tuber") - before, " crop now '", pieces[planter].crop, "'")
	_rq_plant(1, planter, "tuber_seed")
	pieces[planter].sown -= 9.0
	_crop_look(planter)
	_rq_portal_name(portals[0], "Ember Hill")
	print("CAMP pair before ", portal_pair(portals[0]))
	_rq_portal_name(portals[1], "ember hill")
	print("CAMP pair after ", portal_pair(portals[0]), " ", portal_pair(portals[1]))
	print("CAMP safe by torch ", base_at(at.call(5.0, -3.0)), " food ", food, " rest ", rest)
	food = 15.0
	rest = 10.0
	var hp := player.health
	eat("meat")
	print("CAMP ate meat: food ", food, " hp ", hp, " -> ", player.health)
	clock = 22.0
	night = true
	vote_sleep(true)
	await get_tree().create_timer(5.0).timeout
	print("CAMP after sleep vote clock %.2f rest %.0f" % [clock, rest])
	if "guide" in OS.get_cmdline_user_args():
		ui.open_inventory("build")
	elif "bar" in OS.get_cmdline_user_args():
		builder.toggle()
		builder.sel = Items.PIECE_ORDER.find("portal")
		builder._hint()
	elif "portal" in OS.get_cmdline_user_args():
		ui.open_portal(portals[0])
	if DisplayServer.get_name() == "headless":
		get_tree().quit()


## Test: one of every kind of form, frozen in a row before the eye.
func debug_formshot() -> void:
	await get_tree().create_timer(2.0).timeout
	combat_frozen = true
	var c := player.global_position
	var fwd := -player.global_transform.basis.z
	var side := player.global_transform.basis.x
	var ks: Array = ["rusher", "idol", "elite", "brute", "howler", "lurker", "spider", "bloater", "spitter", "swarm"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("kinds="):
			ks = Array(a.substr(6).split(","))
	for i in ks.size():
		var p := c + fwd * 7.0 + side * (i - (ks.size() - 1) * 0.5) * 2.2
		p.y = terrain.height_at(p.x, p.z) + 1.5
		var e := spawn_at(ks[i], p)
		e._buried = 0.0
		e.rotation.y = player.yaw + PI + 0.5
		e._bar_t = 99.0
	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(3.0).timeout
		for e in enemies:
			if is_instance_valid(e):
				print("FORM ", e.kind, " ", e.spec.name, " at y %.2f over ground %.2f" % [e.global_position.y, terrain.height_at(e.global_position.x, e.global_position.z)])
		get_tree().quit()


func debug_chest() -> void:
	await get_tree().create_timer(2.0).timeout
	inv.add("wood", 40)
	var spot := player.global_position + Vector3(3, 0, 0)
	builder._rq_build(1, "chest", spot, 0.0)
	await get_tree().create_timer(0.5).timeout
	for pid in pieces:
		print("CHEST piece ", pid, " ", pieces[pid].kind, " holds ", containers.get("p%d" % pid))
		_rq_open(1, "p%d" % pid)
	await get_tree().create_timer(0.5).timeout
	for pid in pieces:
		print("CHEST after open ", containers.get("p%d" % pid))
	if DisplayServer.get_name() == "headless":
		get_tree().quit()


## Testing aid: typing a chest's name with letters that are also hotkeys.
func debug_chestname() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	inv.add("wood", 40)
	builder._rq_build(1, "chest", player.global_position + Vector3(3, 0, 0), 0.0)
	await get_tree().create_timer(0.5).timeout
	var pid := -1
	for k in pieces:
		if pieces[k].kind == "chest":
			pid = k
	_rq_open(1, "p%d" % pid)
	await get_tree().create_timer(0.5).timeout
	var field: LineEdit = null
	for n in ui.find_children("*", "LineEdit", true, false):
		field = n
	field.grab_focus()
	await get_tree().process_frame
	for k in [KEY_M, KEY_J, KEY_I, KEY_K, KEY_B, KEY_R]:
		for down in [true, false]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			ev.keycode = k
			ev.unicode = k + 32
			ev.pressed = down
			Input.parse_input_event(ev)
			await get_tree().process_frame
	var ent := InputEventKey.new()
	ent.physical_keycode = KEY_ENTER
	ent.keycode = KEY_ENTER
	ent.pressed = true
	Input.parse_input_event(ent)
	await get_tree().create_timer(1.5).timeout
	print("CHESTNAME text=%s panel=%s saved=%s" % [field.text if is_instance_valid(field) else "?", ui._panel_name, pieces[pid].get("name", "")])
	get_tree().quit()


func debug_skillshot() -> void:
	award("beacon", 6.0)
	for id in ["hardy", "hardy", "steady_hand"]:
		skills.learn(id)
	ui.open_skills()


## Testing aid: many nights' waves far from shelter, counting what comes that can hardly be seen.
func debug_unseen_nights() -> void:
	await get_tree().create_timer(1.0).timeout
	var at := player.global_position + Vector3(300, 0, 300)
	at.y = terrain.height_at(at.x, at.z) + 2.0
	player.place(at, 0.0)
	await get_tree().create_timer(1.0).timeout
	nights = 6
	print("UNSEEN pre targets=%d safe=%s pos=%s" % [targets().size(), safe_at(player.global_position), player.global_position])
	for k in 40:
		_night_wave()
		await get_tree().process_frame
		for e in foes.values():
			if is_instance_valid(e) and e.kind != "unseen":
				e.die(false)
	await get_tree().create_timer(1.0).timeout
	print("UNSEEN NIGHTS count=%d alive=%d" % [_unseen_count(), alive_count()])
	get_tree().quit()



# ================================================================== lairs of the great ones

## In each land, somewhere level and far from any village, a great one sleeps in a ring of black stones.
func _plan_lairs() -> void:
	lairs.clear()
	var bosses := {}
	for b in LesserSpeeb.BOSSES:
		bosses[LesserSpeeb.BOSSES[b].land] = b
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 7707
	for land in WTerrain.BIOMES:
		if not bosses.has(land):
			continue
		for attempt in 4000:
			var p := Vector2(r.randf_range(-860, 860), r.randf_range(-860, 860))
			if terrain.biome_name(p.x, p.y) != land or terrain_probe(p) > 0.2:
				continue
			if not _clear_of_places(p, 170.0, 90.0) or lairs.any(func(o): return Vector2(o.pos.x, o.pos.z).distance_to(p) < 250.0):
				continue
			var b: String = bosses[land]
			lairs.append({"id": land, "land": land, "boss": b, "name": "Lair of " + LesserSpeeb.BOSSES[b].name.trim_prefix("The "), "pos": Vector3(p.x, 0, p.y)})
			terrain.add_flat(p, 24.0)
			break


func lair_ready(l: Dictionary) -> bool:
	return day >= int(flags.get("lair_" + str(l.id), -99)) + LAIR_RETURN_DAYS


func _build_lair(l: Dictionary) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(str(l.id)) + world_seed
	var n := Node3D.new()
	n.position = l.pos
	add_child(n)
	# The ring: tall black stones, leaning inward
	for k in 11:
		var a := TAU * k / 11 + rr.randf_range(-0.1, 0.1)
		var hgt := rr.randf_range(4.0, 8.0)
		var st := _add(n, box(Vector3.ZERO, Vector3(1.5, hgt, 0.9), _m.darkstone, true), Vector3(cos(a) * 17, hgt * 0.5 - 0.4, sin(a) * 17))
		st.rotation = Vector3(0, -a, rr.randf_range(-0.18, -0.05))
	# The bed of the great one: a sunken black slab ringed with bone
	_add(n, cyl(Vector3.ZERO, 5.5, 0.5, _m.darkstone, false, -1.0, 18), Vector3(0, 0.05, 0))
	for k in 6:
		var a := TAU * k / 6 + 0.3
		_bones(n, Vector3(cos(a) * 9, 0, sin(a) * 9), rr)
	for k in 4:
		var a := TAU * k / 4 + 0.8
		_add(n, sphere(Vector3.ZERO, 0.28, _m.bone), Vector3(cos(a) * 6.2, 0.25, sin(a) * 6.2))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.9, 0.2, 0.08)
	glow.light_energy = 1.6
	glow.omni_range = 16.0
	glow.position = Vector3(0, 1.0, 0)
	n.add_child(glow)
	l["glow"] = glow


## The host wakes a great one when a pilgrim comes into its ring.
func _lair_tick() -> void:
	for l in lairs:
		var e = _lair_boss.get(l.id)
		if e != null and (not is_instance_valid(e) or not e.is_alive()):
			_lair_boss.erase(l.id)
			e = null
		if e != null or not lair_ready(l):
			continue
		for t in targets():
			if t.global_position.distance_to(l.pos) < 30.0:
				var b := spawn_at(l.boss, l.pos + Vector3(0, 3.0, 0))
				if b:
					_lair_boss[l.id] = b
					shared("_w_lair_wake", [l.boss])
				break


func _w_lair_wake(b: String) -> void:
	hud.notify("%s wakes." % LesserSpeeb.BOSSES[b].name)
	hud.say("The stones remember what sleeps among them.", 4.0)


func _w_boss_down(b: String, at: Vector3) -> void:
	var land: String = LesserSpeeb.BOSSES[b].land
	flags["lair_" + land] = day
	for l in lairs:
		if l.id == land and l.has("glow") and is_instance_valid(l.glow):
			l.glow.light_energy = 0.2
	if Net.authority():
		# A great one always leaves fittings: rare ones, and now and then storied
		var fit := "fittings_storied" if _gen.randf() < 0.35 else "fittings_rare"
		_rq_satchel(1, at, Items.roll("corpse", 6, _gen) + [["t_" + land, 1], [fit, 1]], false)
		autosave_soon(2.0)
	if not Net.dedicated and player.global_position.distance_to(at) < 120.0:
		award("kill_boss")
		skills.points += 1
		Game.gain_pxp(300)
		ui.skills_changed()
		hud.notify("%s is undone.\nA point of skill is yours to spend [%s]." % [LesserSpeeb.BOSSES[b].name, Game.key_text("skills")])
		player.health = player.max_health
		hud.set_health(1.0, true)
		autosave_soon(4.0)


func debug_boss() -> void:
	await get_tree().create_timer(1.0).timeout
	print("BOSS lairs: ", lairs.map(func(l): return [l.id, Vector2i(int(l.pos.x), int(l.pos.z))]))
	var l: Dictionary = lairs[0]
	var at: Vector3 = l.pos + Vector3(0, 2.0, 24)
	player.place(at, 0.0)
	await get_tree().create_timer(1.5).timeout
	player.place(l.pos + Vector3(0, 2.0, 20), 0.0)
	await get_tree().create_timer(2.0).timeout
	var b = _lair_boss.get(l.id)
	print("BOSS awake=%s hp=%s" % [b != null, b.hp if b else 0])
	if b:
		player.health = 99999.0
		for k in 30:
			b.last_hitter = Net.me()
			b.hurt(200.0, Vector3.FORWARD)
			await get_tree().create_timer(0.2).timeout
			if not b.is_alive():
				break
	await get_tree().create_timer(1.0).timeout
	print("BOSS after: flags=%s ready=%s points=%d satchels=%d" % [flags.get("lair_" + str(l.id)), lair_ready(l), skills.points, satchels.size()])
	get_tree().quit()


func debug_bossshot() -> void:
	await get_tree().create_timer(1.0).timeout
	var l: Dictionary = lairs[int(Game.get_meta("lair", 0)) if Game.has_meta("lair") else 0]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lair="):
			for x in lairs:
				if x.id == a.substr(5):
					l = x
	clock = 17.0
	player.place(l.pos + Vector3(0, 2.0, 26), 0.0)
	await get_tree().create_timer(3.0).timeout
	combat_frozen = true
	var b = _lair_boss.get(l.id)
	if b:
		b.global_position = l.pos + Vector3(0, 3.5, 6)
	_debug_aim(l.pos + Vector3(0, 3.0, 0))


## Testing aid: a great one shows its ways with warnings, stands spent after a charge, and grows wroth.
func debug_greatones() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0   # midday, so that no dawn unmakes the test's foes
	player.health = 999999.0
	player.max_health = 999999.0
	var names := ["boss_ash", "boss_dunes"]
	for b in names:
		marks_seen = {}
		var e := spawn_at(b, player.global_position + Vector3(0, 2, -18))
		e.set_meta("raid", true)
		var spent := false
		for i in 20 * 60:
			await get_tree().physics_frame
			if not is_instance_valid(e):
				break
			if e._spent > 0.0:
				spent = true
		if e.spec.ways.has("charge"):
			player.global_position = e.global_position + Vector3(0, 0, 16)
			e._busy = 0.0
			e._spent = 0.0
			e._start_charge(player)
			for i in 4 * 60:
				await get_tree().physics_frame
				if e._spent > 0.0:
					spent = true
		var w0: bool = e._wroth
		e.hurt(e.max_hp * 0.55, Vector3(0, 0, -1))
		e._spent = 0.5
		var h0: float = e.hp
		e.hurt(100.0, Vector3(0, 0, -1))
		await get_tree().physics_frame
		await get_tree().physics_frame
		print("GREAT %s ring=%d lane=%d fire=%d spent=%s wroth %s->%s spent_harm=%.0f" % [b, marks_seen.get(0, 0), marks_seen.get(1, 0), marks_seen.get(2, 0), spent, w0, e._wroth, h0 - e.hp])
		e.die(false)
	get_tree().quit()


func debug_allbosses() -> void:
	await get_tree().create_timer(1.0).timeout
	player.health = 999999.0
	player.max_health = 999999.0
	var i := 0
	for b in LesserSpeeb.BOSSES:
		var e := spawn_at(b, player.global_position + Vector3(cos(i) * 14, 3, sin(i) * 14))
		i += 1
	await get_tree().create_timer(14.0).timeout
	var alive := 0
	for e in enemies:
		if is_instance_valid(e) and e.is_alive() and e.boss != "":
			alive += 1
	print("ALLBOSS alive=%d foes=%d" % [alive, alive_count()])
	get_tree().quit()


## Test: the relics and kit of the waste. The claw bites rock, the censer's smoke and a flare show forms.
func debug_gadgets() -> void:
	await get_tree().create_timer(2.0).timeout
	var r: Relics = player.relics
	print("GADGETS has claw before ", Game.has_relic("claw"), " milk ", Game.milk_count())
	arms.relics.append("claw")
	arms.relics.append("censer")
	print("GADGETS has claw after ", Game.has_relic("claw"), " censer ", Game.has_relic("censer"))
	# Face the ground a few metres ahead: the claw should find something to bite
	player.pitch = -0.5
	player.head.rotation.x = -0.5
	await get_tree().physics_frame
	var a = r._find_anchor()
	print("GADGETS claw anchor ", a != null, " landing ", a.get_meta("landing") if a else null)
	var lk = spawn_at("lurker", player.global_position + Vector3(8, 1.5, 0))
	await get_tree().create_timer(1.0).timeout
	print("GADGETS lurker buried ", lk._buried)
	cense(player.global_position, 12.0)
	await get_tree().create_timer(0.6).timeout
	print("GADGETS smoked ", lk.smoke_t > 0.0, " seen ", lk.seen_t > 0.0, " buried ", snappedf(lk._buried, 0.01))
	var far = spawn_at("rusher", player.global_position + Vector3(-15, 1.5, 0))
	var fl := Arms.Thrown.make(self, "flare", player.global_position + Vector3(-12, 1, 0), Vector3.ZERO)
	fl.fuse = 10.0
	await get_tree().create_timer(1.5).timeout
	print("GADGETS flare shows ", far.seen_t > 0.0)
	player.health = 40.0
	r.select(5)
	r._use(self)
	print("GADGETS milk after drink ", Game.milk_count(), " hp ", player.health)
	if DisplayServer.get_name() == "headless":
		get_tree().quit()


## Test (co-op): the joiner takes up a quest; the host should hear of it and follow it.
func debug_qshare() -> void:
	await get_tree().create_timer(14.0).timeout
	if not Net.authority():
		for k in quests.offers:
			if not quests.offers[k].is_empty():
				var o: Dictionary = quests.offers[k][0]
				print("QSHARE joiner takes ", o.title)
				quests.accept(o)
				break
	await get_tree().create_timer(4.0).timeout
	print("QSHARE ", "host" if Net.authority() else "joiner", " tracked ", quests.tracked, " title ", quests.quests.get(quests.tracked, {}).get("title", ""))


## Test (co-op): the host walks off from the start; a joiner should come in beside them.
func debug_joinnear() -> void:
	if Net.authority():
		await get_tree().create_timer(6.0).timeout
		player.place(ground_below(spawn_pos + Vector3(70, 0, 50)) + Vector3(0, 0.3, 0), 0.0)
		await get_tree().create_timer(45.0).timeout
		print("JOINNEAR host at ", player.global_position)
		return
	await get_tree().create_timer(20.0).timeout
	for id in avatars:
		print("JOINNEAR joiner at ", player.global_position, " other at ", avatars[id].global_position, " apart ", snappedf(player.global_position.distance_to(avatars[id].global_position), 0.1))


## Test (co-op): a pilgrim joining late sees the fellowship's quest progress; leaving keeps where they stood and what they carried.
func debug_latesync() -> void:
	if Net.authority():
		await get_tree().create_timer(4.0).timeout
		for k in quests.offers:
			if not quests.offers[k].is_empty():
				quests.accept(quests.offers[k][0])
				break
		await get_tree().create_timer(1.0).timeout
		for qid in quests.quests:
			if qid != "main":
				quests.quests[qid].have = 1
				shared("_w_quest", [qid, quests.quests[qid]])
				print("LATESYNC host quest ", qid, " have 1")
		return
	await get_tree().create_timer(15.0).timeout
	var q: Dictionary = quests.quests.get(quests.tracked, {})
	print("LATESYNC joiner tracked ", quests.tracked, " have ", q.get("have", -1), " quests ", quests.quests.keys())
	var spot := player.global_position + Vector3(12, 0, 7)
	player.place(ground_below(spot) + Vector3(0, 0.3, 0), 1.0)
	inv.add("scrap", 7)
	await get_tree().create_timer(1.0).timeout
	var path := _char_path()
	var want := player.global_position
	print("LATESYNC joiner leaves at ", want, " scrap ", inv.count("scrap"))
	Net.leave()
	await Engine.get_main_loop().create_timer(3.0).timeout
	var d = Game.read_var_safe(path)
	var bag := Inventory.new(40)
	bag.from_data(d.get("inv", []))
	print("LATESYNC saved pos ", d.get("pos"), " scrap ", bag.count("scrap"), " level ", d.get("skills", {}).get("level", "?"))
	Engine.get_main_loop().quit()



# ================================================================== the road between: landmarks and what is met on the way

## Great shapes on the skyline, seen from far off: the bones of something huge, spires of rock,
## the stumps of old towers. They give the eye somewhere to walk toward. Their own dice; nothing saved.
func _scatter_landmarks() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 6161
	var placed: Array = []
	var tries := 0
	while placed.size() < 70 and tries < 3000:
		tries += 1
		var p := Vector2(r.randf_range(-1850, 1850), r.randf_range(-1850, 1850))
		if not _clear_of_places(p, 160.0, 60.0) or placed.any(func(q): return q.distance_to(p) < 260.0):
			continue
		if lairs.any(func(l): return Vector2(l.pos.x, l.pos.z).distance_to(p) < 120.0):
			continue
		placed.append(p)
		var n := Node3D.new()
		n.position = gpos(p) + Vector3(0, -0.4, 0)
		n.rotation.y = r.randf() * TAU
		add_child(n)
		match ["bones", "spire", "tower", "arch", "bones", "spire"][r.randi() % 6]:
			"bones":
				# A ribcage half sunk in the ground, and the long spine running from it
				var len := r.randf_range(18.0, 30.0)
				_add(n, box(Vector3.ZERO, Vector3(1.4, 1.4, len), _m.bone, true, Vector3(0.05, 0, 0)), Vector3(0, 1.2, 0))
				for k in int(len / 3.0):
					var z := -len * 0.5 + 1.5 + k * 3.0
					var hgt := 7.0 * sin(PI * (k + 0.5) / (len / 3.0)) + 3.0
					for side in [-1.0, 1.0]:
						var rib := box(Vector3.ZERO, Vector3(0.7, hgt, 0.7), _m.bone, true, Vector3(0, 0, side * 0.35))
						_add(n, rib, Vector3(side * (hgt * 0.17 + 0.6), hgt * 0.5, z))
				_add(n, box(Vector3.ZERO, Vector3(4.0, 3.0, 5.0), _m.bone, true, Vector3(0.3, 0.2, 0)), Vector3(0, 1.2, len * 0.5 + 2.0))
			"spire":
				var hgt := r.randf_range(28.0, 52.0)
				for k in 4:
					var w := (1.0 - k * 0.22) * r.randf_range(5.0, 8.0)
					_add(n, box(Vector3.ZERO, Vector3(w, hgt * 0.27, w * 0.8), _m.darkstone, true, Vector3(r.randf_range(-0.06, 0.06), r.randf() * TAU, r.randf_range(-0.06, 0.06))), Vector3(r.randf_range(-0.6, 0.6), hgt * 0.27 * (k + 0.5), r.randf_range(-0.6, 0.6)))
			"tower":
				var hgt := r.randf_range(14.0, 26.0)
				_add(n, cyl(Vector3.ZERO, 4.0, hgt, _m.stone, true, 3.4, 10), Vector3(0, hgt * 0.5, 0))
				_add(n, box(Vector3.ZERO, Vector3(2.0, 2.6, 0.6), _m.cold, false), Vector3(0, hgt * 0.6, 3.6))
				for k in 5:
					var a := k * TAU / 5.0 + r.randf()
					_add(n, box(Vector3.ZERO, Vector3(1.6, 1.0, 1.2), _m.stone, true, Vector3(r.randf(), r.randf(), r.randf())), Vector3(cos(a) * 7.0, 0.4, sin(a) * 7.0))
			"arch":
				var hgt := r.randf_range(10.0, 16.0)
				for side in [-1.0, 1.0]:
					_add(n, box(Vector3.ZERO, Vector3(2.4, hgt, 2.4), _m.stone, true), Vector3(side * 5.0, hgt * 0.5, 0))
				_add(n, box(Vector3.ZERO, Vector3(13.0, 2.2, 2.6), _m.stone, true), Vector3(0, hgt + 1.0, 0))


var _road_t := 50.0


## Out on the open road, now and then, something is met: smoke from a camp left cold, a traveler who
## did not make it, a pack of forms crossing, a cairn over something buried. The host decides; all see it.
func _road_tick(step: float) -> void:
	_road_t -= step
	if _road_t > 0.0:
		return
	_road_t = randf_range(70.0, 130.0)
	var tg := targets()
	tg.shuffle()
	for t in tg:
		var p: Vector3 = t.global_position
		if safe_at(p) or settlement_at(p, 150.0) != "" or base_at(p, 80.0) >= 0:
			continue
		if ruins.any(func(ru): return p.distance_to(ru.pos) < 60.0):
			continue
		var fwd: Vector3 = -t.global_transform.basis.z
		fwd.y = 0
		fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
		var at := p + fwd.rotated(Vector3.UP, randf_range(-0.7, 0.7)) * randf_range(55.0, 95.0)
		at = ground_below(Vector3(at.x, terrain.height_at(at.x, at.z) + 2.0, at.z))
		if terrain.normal_at(at.x, at.z).y < 0.75 or safe_at(at):
			continue
		_road_event(at, p)
		return


func _road_event(at: Vector3, seen_from: Vector3) -> void:
	var rr := RandomNumberGenerator.new()
	rr.randomize()
	var roll := rr.randf()
	var kind := "camp"
	if roll < 0.24:
		kind = "camp"
	elif roll < 0.42:
		kind = "fallen"
	elif roll < 0.6:
		kind = "pack"
	elif roll < 0.72:
		kind = "attack"
	elif roll < 0.9:
		kind = "unlit"
	else:
		kind = "cairn"
	match kind:
		"camp":
			shared("_rq_satchel", [0, at + Vector3(1.5, 0, 0), Items.roll("camp", 3, rr), false])
		"fallen":
			shared("_rq_satchel", [0, at, Items.roll("corpse", 3, rr) + Items.roll("caravan", 1, rr), false])
		"pack":
			for k in 3 + rr.randi() % 3:
				_spawn_near(["rusher", "spider", "howler", "lurker"][rr.randi() % 4], at, 2.0, 8.0, true)
		"attack":
			shared("_rq_satchel", [0, at, Items.roll("caravan", 3, rr), false])
			for k in 2 + rr.randi() % 3:
				_spawn_near(["rusher", "spitter", "brute", "bloater"][rr.randi() % 4], at, 4.0, 10.0, true)
		"cairn":
			shared("_rq_satchel", [0, at, Items.roll("vault", 3, rr), false])
		"unlit":
			# A band of the Unlit at their fire: gunmen and blades, and now and then a breaker
			shared("_rq_satchel", [0, at + Vector3(1.5, 0, 0), Items.roll("camp", 2, rr) + Items.roll("caravan", 2, rr), false])
			var band := ["unlit_gun", "unlit_gun", "unlit_blade"]
			if rr.randf() < 0.5:
				band.append("unlit_blade")
			if rr.randf() < 0.3 or maxf(absf(at.x), absf(at.z)) > 900.0:
				band.append("unlit_brute")
			for k in band:
				_spawn_near(k, at, 2.0, 6.0, true)
	shared("_w_road_sign", [at, kind, Vector2(seen_from.x, seen_from.z)])


## What marks the spot, seen from afar, and a word to those near enough to notice.
func _w_road_sign(at: Vector3, kind: String, from: Vector2) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = at
	var smoke := CPUParticles3D.new()
	smoke.amount = 40
	smoke.lifetime = 7.0
	smoke.direction = Vector3.UP
	smoke.spread = 8.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 3.5
	smoke.gravity = Vector3(0.4, 0.3, 0)
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 5.0
	var q := QuadMesh.new()
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_texture = LesserSpeeb.smoke_tex()
	sm.albedo_color = Color(0.25, 0.23, 0.22, 0.55) if kind != "cairn" else Color(0.75, 0.7, 0.6, 0.4)
	q.material = sm
	smoke.mesh = q
	smoke.position.y = 1.0
	n.add_child(smoke)
	match kind:
		"camp", "attack", "unlit":
			_add(n, cyl(Vector3.ZERO, 0.9, 0.25, _m.cold, false), Vector3(0, 0.12, 0))
			var e := cyl(Vector3.ZERO, 0.45, 0.2, _m.ember, false)
			_add(n, e, Vector3(0, 0.25, 0))
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.55, 0.25)
			l.light_energy = 2.0
			l.omni_range = 12.0
			l.position.y = 1.0
			n.add_child(l)
		"cairn":
			for k in 5:
				_add(n, box(Vector3.ZERO, Vector3(1.0 - k * 0.15, 0.5, 0.9 - k * 0.12), _m.stone, k == 0, Vector3(0, k * 0.7, 0)), Vector3(1.6, 0.25 + k * 0.45, 0))
		"pack":
			smoke.emitting = false
	if kind != "pack":
		var tw := n.create_tween()
		tw.tween_interval(240.0)
		tw.tween_callback(n.queue_free)
	else:
		n.queue_free()
	if player.global_position.distance_to(at) < 160.0 and not Net.dedicated:
		var dir := WPlaces.dir_word(Vector2(player.global_position.x, player.global_position.z), Vector2(at.x, at.z))
		hud.notify({
			"camp": "Smoke to the %s. Someone made camp there.",
			"fallen": "Smoke to the %s. A traveler lies still beside it.",
			"pack": "Forms crossing to the %s.",
			"attack": "Shouting to the %s, then silence. Smoke rises.",
			"cairn": "A cairn of stones to the %s. Something is buried there.",
			"unlit": "Masks by a fire to the %s. The Unlit are camped there.",
		}[kind] % dir)


## Test: the far reaches, and something met on the road.
func debug_far() -> void:
	await get_tree().create_timer(2.0).timeout
	var far_ruins := ruins.filter(func(ru): return maxf(absf(ru.pos.x), absf(ru.pos.z)) > 1000.0).size()
	var far_nodes := nodes.filter(func(nd): return maxf(absf(nd.pos.x), absf(nd.pos.z)) > 1000.0).size()
	print("FAR ruins ", ruins.size(), " far ", far_ruins, " nodes ", nodes.size(), " far ", far_nodes)
	for k in WPlaces.SETTLEMENTS:
		print("FAR town ", k, " at ", WPlaces.spos(k), " h ", snappedf(terrain.height_at(WPlaces.spos(k).x, WPlaces.spos(k).y), 0.1))
	print("FAR start ", WPlaces.start, " cinderwick ", WPlaces.spos("cinderwick"), " beacon0 ", WPlaces.bpos(0))
	print("FAR roads ", WPlaces.roads.map(func(rd): return "%s-%s %d" % [rd[0], rd[1], rd[2].size()]))
	for kind in ["camp", "fallen", "pack", "attack", "cairn"]:
		_road_event(player.global_position + Vector3(60, 0, 0), player.global_position)
	await get_tree().create_timer(1.0).timeout
	print("FAR satchels ", satchels.size(), " alive ", alive_count())
	if DisplayServer.get_name() == "headless":
		get_tree().quit()



## Test: beasts graze and run, one is brought down and leaves meat; a cooking station burns wood and cooks.
func debug_hunt() -> void:
	await get_tree().create_timer(2.0).timeout
	var b := _w_beast(900, "goat", player.global_position + Vector3(10, 1, 0))
	var t := _w_beast(901, "tusker", player.global_position + Vector3(-12, 1, 0))
	await get_tree().create_timer(3.0).timeout
	print("HUNT goat fled to ", snappedf(b.global_position.distance_to(player.global_position), 0.1), " tusker at ", snappedf(t.global_position.distance_to(player.global_position), 0.1))
	var sat := satchels.size()
	b.hurt(60.0, Vector3.FORWARD)
	t.hurt(10.0, Vector3.FORWARD)
	var hp0 := player.health
	await get_tree().create_timer(4.0).timeout
	print("HUNT goat dead ", not b.is_alive(), " satchels +", satchels.size() - sat, " tusker charged hp ", hp0, " -> ", player.health)
	var c := player.global_position + Vector3(3, 0, 3)
	inv.add("wood", 5)
	inv.add("raw_meat", 2)
	builder._rq_build(1, "cookpot", c, 0.0)
	builder._rq_build(1, "campfire", c + Vector3(6, 0, 0), 0.0)
	await get_tree().create_timer(0.5).timeout
	var pot := builder.near_pid(c, "cookpot", 2.0)
	var fire := builder.near_pid(c + Vector3(6, 0, 0), "campfire", 2.0)
	print("HUNT pot burning ", burning(pot), " left ", fuel_left(pot), " base ", base_at(c + Vector3(6, 0, 0)) >= 0)
	add_wood(pot, 2)
	await get_tree().create_timer(0.3).timeout
	print("HUNT after wood left ", fuel_left(pot), " wood ", inv.count("wood"))
	clock += 0.0
	day += 6
	await get_tree().create_timer(0.3).timeout
	print("HUNT six days on: pot burning ", burning(pot), " fire burning ", burning(fire), " base ", base_at(c + Vector3(6, 0, 0)) >= 0)
	if DisplayServer.get_name() == "headless":
		get_tree().quit()


func debug_beastshot() -> void:
	await get_tree().create_timer(2.0).timeout
	_beast_t = 9999.0
	var f := -player.global_transform.basis.z
	var side := f.cross(Vector3.UP)
	var base := player.global_position + f * 7.0
	var i := 0
	for k in ["hare", "goat", "tusker"]:
		var q := base + side * (i - 1) * 2.6
		q.y = terrain.height_at(q.x, q.z) + 0.3
		var b := _w_beast(950 + i, k, q)
		b.set_physics_process(false)
		b.global_position = Vector3(q.x, terrain.height_at(q.x, q.z), q.z)
		b.rotation.y = atan2(side.x, side.z)
		i += 1
	var c := base + side * 5.5
	builder._rq_build(1, "cookpot", Vector3(c.x, terrain.height_at(c.x, c.z), c.z), 0.0)
	clock = 19.5


func debug_townshot() -> void:
	await get_tree().create_timer(1.0).timeout
	var c := gpos(WPlaces.spos("cinderwick"))
	var at := c + Vector3(0, 0, 22)
	at.y = terrain.height_at(at.x, at.z) + 0.3
	player.place(at, 0.0)
	player.face(c + Vector3(0, 1.5, 0))
	clock = 11.0


## Test (co-op): beasts the host keeps are seen by a joiner, and a joiner's shot reaches the host's beast.
func debug_coopbeasts() -> void:
	await get_tree().create_timer(10.0).timeout
	if Net.authority():
		for k in 40:
			await get_tree().create_timer(1.0).timeout
			if k % 10 == 0:
				var g := _w_beast(_beast_next, "goat", player.global_position + Vector3(14, 1, 0))
				_beast_next += 1
		print("COOPB host beasts ", beasts.size(), " satchels ", satchels.size())
		return
	for k in 40:
		await get_tree().create_timer(1.0).timeout
		for id in beasts:
			var b = beasts[id]
			if is_instance_valid(b) and b.is_alive() and b.kind == "goat":
				print("COOPB joiner sees ", beasts.size(), " beasts; shoots goat ", id)
				var before := satchels.size()
				b.hurt(80.0, Vector3.FORWARD)
				await get_tree().create_timer(3.0).timeout
				print("COOPB joiner goat dead ", not b.is_alive(), " satchels +", satchels.size() - before)
				return
	print("COOPB joiner saw no goat; beasts ", beasts.size())


func debug_askshot() -> void:
	await get_tree().create_timer(1.0).timeout
	hud.ask("Leave the game?", "Leave", func(): pass)
	await get_tree().create_timer(1.0).timeout
	print("ASK root vis ", hud.root.visible, " kids ", hud.root.get_child_count(), " last ", hud.root.get_child(hud.root.get_child_count() - 1))


func debug_loadshot() -> void:
	hud.show_loading("The Ashen Waste", "The waste is raised")


func debug_deathshot() -> void:
	damage_player(9999.0, player.global_position + Vector3(1, 0, 0))


func debug_downed_join() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(4.0).timeout
	damage_player(9999.0, player.global_position + Vector3(1, 0, 0))
	print("DOWN downed=%s bleed=%.0f" % [downed, _bleed_t])
	await get_tree().create_timer(5.0).timeout
	print("DOWN bleed now %.0f" % _bleed_t)
	print("DOWN after raise: downed=%s health=%.0f" % [downed, player.health])


func debug_downed_host() -> void:
	inv.add("salts", 1)
	for t in 60:
		await get_tree().create_timer(1.0).timeout
		var any := false
		for id in avatars:
			any = any or avatars[id].downed
		if any:
			break
	for id in avatars:
		var a = avatars[id]
		print("HOST sees %s downed=%s hold=%.1f" % [Net.name_of(id), a.downed, a._area.get_meta("hold")])
		if a.downed:
			a._area.get_meta("on_interact").call()
	await get_tree().create_timer(1.0).timeout
	print("HOST salts left %d" % inv.count("salts"))


func debug_bannershot() -> void:
	hud.set_fx("desat", 0.85)
	hud.set_fx("dark", 0.35)
	hud.set_banner("Unconscious   34", "A companion can raise you.   Hold [Space] to wake at camp")


func debug_basestock() -> void:
	var p := player.global_position + Vector3(3, 0, 0)
	builder._rq_build(1, "campfire", gpos(Vector2(p.x, p.z)), 0.0)
	var c := player.global_position + Vector3(0, 0, 4)
	builder._rq_build(1, "chest", gpos(Vector2(c.x, c.z)), 0.0)
	await get_tree().create_timer(1.0).timeout
	var cid: String = base_chests()[0] if not base_chests().is_empty() else ""
	print("STOCK chests ", base_chests())
	inv.take("scrap", inv.count("scrap"))
	inv.add("scrap", 2)
	if cid != "":
		_rq_put(1, cid, "scrap", 10)
	print("STOCK scrap pack %d total %d" % [inv.count("scrap"), stock_count("scrap")])
	var ok := stock_pay({"scrap": 7})
	print("STOCK paid %s: pack %d chest %d" % [ok, inv.count("scrap"), _cont_count(cid, "scrap")])
	get_tree().quit()


func debug_floors() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var o := player.global_position + Vector3(30, 0, 30)
	var ci0 := floori(o.x / WBuilder.GRID)
	var cj0 := floori(o.z / WBuilder.GRID)
	var hs := {}
	for i in 4:
		for j in 4:
			var b: float = builder._cell_base(ci0 + i, cj0 + j)
			var p := Vector3((ci0 + i + 0.5) * WBuilder.GRID, b, (cj0 + j + 0.5) * WBuilder.GRID)
			builder._rq_build(1, "floor", p, 0.0)
			hs[snappedf(b, 0.01)] = true
	print("FLOORS distinct heights %d: %s slope %.2f" % [hs.size(), hs.keys(), builder._slope(ci0, cj0)])
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
		return
	var c := Vector3((ci0 + 2) * WBuilder.GRID, 0, (cj0 + 2) * WBuilder.GRID)
	player.place(c + Vector3(-9, terrain.height_at(c.x - 9, c.z - 9) + 2.0 - c.y, -9), 0.0)
	player.face(c + Vector3(0, 6, 0))


## Testing aid: fills the pack and opens the pack, the making screen and a satchel in turn, for screenshots.
func debug_packshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	for it in [["wood", 34], ["stone", 20], ["roast", 3], ["bandage", 4], ["salts", 1], ["shells", 40], ["herb", 9], ["cloth", 7],
			["coin", 5], ["hatchet", 1], ["tuber_seed", 6], ["scrap", 12], ["wood", 50], ["salt", 60], ["bone", 4]]:
		inv.add(it[0], it[1])
	ui.open_inventory("pack")
	ui._sel = 2
	ui._redraw()
	await get_tree().create_timer(6.0).timeout
	ui.open_inventory("craft")
	await get_tree().create_timer(6.0).timeout
	ui.close_all()
	shared("_rq_satchel", [Net.me(), player.global_position + Vector3(0, 0, -2), [["hide", 3], ["raw_meat", 2], ["bone", 6]], false])
	await get_tree().create_timer(1.0).timeout
	var sid: String = satchels.keys()[-1]
	ui.open_container(sid)


## Testing aid: holding interact on a satchel takes everything that fits; tidy merges stacks.
func debug_takeall() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	shared("_rq_satchel", [Net.me(), player.global_position + Vector3(0, 0, -2), [["hide", 3], ["raw_meat", 2], ["bone", 6]], false])
	await get_tree().create_timer(1.0).timeout
	var sid: String = satchels.keys()[-1]
	var n0 := satchels.size()
	var asked := take_all(sid)
	await get_tree().create_timer(1.0).timeout
	print("TAKEALL asked=%d hide=%d meat=%d bone=%d satchel_gone=%s" % [asked, inv.count("hide"), inv.count("raw_meat"), inv.count("bone"), satchels.size() < n0])
	# A full pack takes only what fits
	for i in inv.slots.size():
		if inv.slots[i] == null:
			inv.slots[i] = {"id": "stone", "n": 60}
	inv.add("bone", 100)
	shared("_rq_satchel", [Net.me(), player.global_position + Vector3(0, 0, -2), [["hide", 2], ["oil", 1]], false])
	await get_tree().create_timer(1.0).timeout
	sid = satchels.keys()[-1]
	asked = take_all(sid)
	await get_tree().create_timer(1.0).timeout
	print("TAKEALL full asked=%d still_there=%s" % [asked, satchels.has(sid)])
	inv.slots[0] = {"id": "wood", "n": 5}
	inv.slots[5] = {"id": "wood", "n": 7}
	ui._tidy(inv)
	print("TIDY wood=%d first=%s" % [inv.count("wood"), inv.slots[0]])
	get_tree().quit()


## Testing aid (co-op): reports the join notice, the closed and opened fellowship list.
func debug_feed_host() -> void:
	for t in 12:
		await get_tree().create_timer(4.0).timeout
		var seen: Array = []
		if hud._feed:
			for l in hud._feed.get_children():
				seen.append(l.text)
		print("FEED t=%d lines=%s" % [(t + 1) * 4, seen])
	await get_tree().create_timer(9.0).timeout
	var lines: Array = []
	if hud._feed:
		for l in hud._feed.get_children():
			lines.append(l.text)
	print("FEED host lines=", lines, " rows_closed=", hud._fellowship.get_child_count() - 1)
	hud.fellowship_open = true
	await get_tree().create_timer(1.0).timeout
	var rows: Array = []
	for i in range(1, hud._fellowship.get_child_count()):
		var h = hud._fellowship.get_child(i)
		rows.append([h.get_child(1).text, h.get_child(0).text])
	print("FEED host open rows=", rows)
	get_tree().quit()


func debug_feed_join() -> void:
	await get_tree().create_timer(15.0).timeout
	get_tree().quit()


## Testing aid: marks two spots, opens the map zoomed in on the player.
func debug_markshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	reveal_place(WPlaces.spos("cinderwick"), 300.0)
	visited["cinderwick"] = true
	map_marks.clear()
	toggle_mark(player.global_position + Vector3(120, 0, -80))
	toggle_mark(player.global_position + Vector3(-200, 0, 150))
	toggle_mark(player.global_position + Vector3(-210, 0, 150))   # close to the last: takes it away
	toggle_mark(player.global_position + Vector3(-60, 0, 260))
	print("MARKS ", map_marks.size())
	ui._map_zoom = 3.0
	ui.open_map()


## Testing aid: drops three satchels before the player and looks at them.
func debug_lootshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var f: Vector3 = -player.global_transform.basis.z
	var r := Vector3(f.z, 0, -f.x)
	shared("_rq_satchel", [Net.me(), player.global_position + f * 6.0 - r * 2.5, [["wood", 3]], false])
	shared("_rq_satchel", [Net.me(), player.global_position + f * 8.0, [["t_ash", 1]], false])
	shared("_rq_satchel", [Net.me(), player.global_position + f * 6.0 + r * 2.5, [["bone", 3]], true])


## Testing aid: walks the guide through its steps by doing each thing, and shows it on screen.
func debug_guide() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	guide.begin(0)
	await get_tree().create_timer(1.5).timeout
	print("GUIDE start step=%d text=%s" % [guide.step, guide._text.text])
	player.global_position += Vector3(15, 0, 0)
	await get_tree().create_timer(1.5).timeout
	inv.add("wood", 6)
	await get_tree().create_timer(1.5).timeout
	ui.open_inventory("pack")
	await get_tree().create_timer(1.5).timeout
	award("make")
	await get_tree().create_timer(1.5).timeout
	ui.close_all()
	award("build")
	await get_tree().create_timer(1.5).timeout
	print("GUIDE after five step=%d text=%s" % [guide.step, guide._text.text])
	var d := char_data()
	print("GUIDE saved step=", d.guide)
	get_tree().quit()


func debug_guideshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	guide.begin(1)


## Testing aid (combat): a stalker gathers before it bites; a dodge in that moment makes it miss;
## a heavy blow staggers it; a shot to the head does more.
func debug_combat() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	player.health = 100.0
	var e := spawn_at("rusher", player.global_position + Vector3(0, 0.5, -2.5))
	e._attack_cd = 0.0
	var winds := 0
	var hp0 := player.health
	for i in 40:
		await get_tree().physics_frame
		if e._wind > 0.0:
			winds += 1
	print("COMBAT wind frames=%d hp %.0f -> %.0f" % [winds, hp0, player.health])
	# Dodge through the next one
	e._attack_cd = 0.0
	while e._wind <= 0.0 and e.is_alive():
		await get_tree().physics_frame
	player.dodge_t = 0.5
	var hp1 := player.health
	while e._wind > 0.0:
		await get_tree().physics_frame
	print("COMBAT dodged hp %.0f -> %.0f" % [hp1, player.health])
	e._attack_cd = 0.0
	while e._wind <= 0.0 and e.is_alive():
		await get_tree().physics_frame
	e.hurt(e.max_hp * 0.35, Vector3(0, 0, -1))
	print("COMBAT staggered=%s wind_cancelled=%s" % [e._stagger > 0.0, e._wind <= 0.0])
	var wp: Array = e.weak_point()
	var o: Vector3 = wp[0] + Vector3(0, 0, 5)
	print("COMBAT head ray hits=%s body ray hits=%s" % [Arms._ray_near(o, Vector3(0, 0, -1), wp[0], wp[1]), Arms._ray_near(o + Vector3(0, -1.0, 0), Vector3(0, 0, -1), wp[0], wp[1])])
	get_tree().quit()


## Testing aid: practice with a gun grows by using it, gives its bonus, and is kept in the save.
func debug_practice() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var wpn = player.weapon
	var g: String = wpn.gun()
	var d0: float = wpn.spec().dmg
	var e := spawn_at("rusher", player.global_position + Vector3(0, 0.5, -3))
	e.hp = 10000.0
	e.set_meta("raid", true)
	var lv0: int = skills.use_level(g)
	for i in 200:
		wpn._practise(g, {e: 1})
	var lv1: int = skills.use_level(g)
	var d1: float = wpn.spec().dmg
	var back := WSkills.new()
	back.from_data(skills.to_data())
	print("PRACTICE level %d -> %d dmg %.1f -> %.1f kept=%s" % [lv0, lv1, d0, d1, back.use_level(g) == lv1])
	get_tree().quit()


## Testing aid: the kick pattern repeats, the view settles back, and the sights hold tighter than the hip.
func debug_recoil() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var wpn = player.weapon
	wpn.shells = 99
	var runs: Array = []
	for run in 2:
		player.yaw = 0.0
		player.pitch = 0.0
		var ys: Array = []
		for i in 4:
			wpn._cool = 0.0
			wpn._try_fire()
			ys.append(snappedf(player.yaw, 0.0001))
			await get_tree().create_timer(0.05).timeout
		var top: float = player.pitch
		await get_tree().create_timer(1.2).timeout
		runs.append([ys, top, player.pitch])
	var hip: float = wpn.shot_spread()
	wpn._aim = 1.0
	var ads: float = wpn.shot_spread()
	print("RECOIL same=%s lifted=%.3f settled=%.3f hip=%.4f ads=%.4f" % [runs[0][0] == runs[1][0], runs[0][1], runs[0][2], hip, ads])
	get_tree().quit()


## Testing aid: the blade in hand, heavy blows, the guard and stamina.
func debug_blade() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var wpn = player.weapon
	wpn.draw_blade()
	await get_tree().create_timer(0.4).timeout
	var e := spawn_at("rusher", player.global_position - player.global_transform.basis.z * 2.0 + Vector3(0, 0.5, 0))
	e._attack_cd = 99.0
	e.hp = 1000.0
	e.set_meta("raid", true)
	await get_tree().create_timer(0.3).timeout
	var hp0: float = e.hp
	var st0: float = player.stamina
	wpn.strike(false)
	await get_tree().create_timer(0.8).timeout
	var light: float = hp0 - e.hp
	var st1: float = player.stamina
	wpn._melee_cool = 0.0
	e.die(false)
	e = spawn_at("rusher", player.global_position - player.global_transform.basis.z * 2.0 + Vector3(0, 0.5, 0))
	e._attack_cd = 99.0
	e.hp = 1000.0
	e.set_meta("raid", true)
	await get_tree().create_timer(0.3).timeout
	hp0 = e.hp
	wpn.strike(true)
	await get_tree().create_timer(0.9).timeout
	var heavy: float = hp0 - e.hp
	print("BLADE out=%s light=%.0f heavy=%.0f stamina %.0f -> %.0f" % [wpn.blade_out, light, heavy, st0, st1])
	# A guarded blow from the front
	player.stamina = 100.0
	player.health = 100.0
	wpn.guarding = true
	var front: Vector3 = player.global_position - player.global_transform.basis.z * 2.0
	damage_player(20.0, front)
	var guarded: float = 100.0 - player.health
	wpn.guarding = false
	player.health = 100.0
	damage_player(20.0, front)
	var open_hit: float = 100.0 - player.health
	print("BLADE guarded=%.1f open=%.1f stamina_after_guard<100=%s" % [guarded, open_hit, player.stamina < 100.0])
	# Spending to empty leaves you winded
	player.stamina = 10.0
	player.spend(20.0)
	var w1: bool = player.winded
	var can: bool = player.spend(5.0)
	print("BLADE winded=%s refused=%s" % [w1, not can])
	wpn.draw_gun(0)
	print("BLADE sheathed=%s" % (not wpn.blade_out))
	get_tree().quit()


## Testing aid: shot at steadily, a gilded form keeps coming, slower; a rusher is pushed back a little.
## Testing aid: the new foes. A gunman fires on you from range; an Unlit Blade's blow is turned by
## a raised guard and it reels; its own guard turns shots from the front; the dead fall and are gone.
func debug_foes() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0   # midday, so that no dawn unmakes the test's foes and sight is at its full
	player.max_health = 100000.0
	player.health = 100000.0
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var g := spawn_at("unlit_gun", player.global_position + f * 16.0 + Vector3(0, 1.0, 0))
	g.set_meta("raid", true)
	var hp0 := player.health
	await get_tree().create_timer(9.0).timeout
	print("FOES gunman shot=%s alive=%s" % [player.health < hp0, g.is_alive()])
	g.die(false)
	var b := spawn_at("unlit_blade", player.global_position + f * 2.0 + Vector3(0, 1.0, 0))
	b.set_meta("raid", true)
	player.weapon.draw_blade()
	player.weapon.guarding = true
	player.stamina = 100.0
	var parried := false
	for i in 6 * 60:
		await get_tree().physics_frame
		player.weapon.guarding = true
		player.stamina = 100.0
		if b._stagger > 0.5:
			parried = true
			break
	player.weapon.guarding = false
	b._guard = true
	b._stagger = 0.0
	b.rotation.y = atan2(-f.x, -f.z)
	var h1: float = b.hp
	LesserSpeeb.harm_kind = "bullet"
	b.hurt(20.0, f)
	LesserSpeeb.harm_kind = ""
	print("FOES parried=%s guarded_harm=%.1f" % [parried, h1 - b.hp])
	b.die(false)
	var n0 := enemies.filter(func(e): return is_instance_valid(e)).size()
	for k in ["hollow", "saltbone", "vigil", "warden", "unlit_brute"]:
		var e := spawn_at(k, player.global_position + f * 8.0 + Vector3(0, 1.5, 0))
		e.set_meta("raid", true)
		await get_tree().create_timer(0.5).timeout
		e.hurt(9999.0, f)
	await get_tree().create_timer(3.0).timeout
	print("FOES dead_gone=%s" % (enemies.filter(func(e): return is_instance_valid(e) and e.is_alive()).size() <= n0))
	get_tree().quit()


## Testing aid: plate on both sides. A body shot on a Breaker is mostly soaked, a head shot and a
## piercing round are not, the plate breaks in the end; the survivor's own plate wears and is mended.
func debug_armour() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var e := spawn_at("unlit_brute", player.global_position + Vector3(0, 1.0, -8))
	e.set_meta("raid", true)
	e.hp = 5000.0
	var p0: float = e.plate
	LesserSpeeb.harm_kind = "bullet"
	var h := e.hp
	e.hurt(40.0, Vector3(0, 0, -1))
	var body := h - e.hp
	h = e.hp
	LesserSpeeb.harm_head = true
	e.hurt(40.0, Vector3(0, 0, -1))
	LesserSpeeb.harm_head = false
	var head := h - e.hp
	h = e.hp
	LesserSpeeb.harm_pierce = 2.0
	e.hurt(40.0, Vector3(0, 0, -1))
	LesserSpeeb.harm_pierce = 1.0
	var pierce := h - e.hp
	for i in 20:
		e.hurt(40.0, Vector3(0, 0, -1))
	LesserSpeeb.harm_kind = ""
	print("ARMOUR foe plate=%d body=%.0f head=%.0f pierce=%.0f broken=%s" % [int(p0), body, head, pierce, e.plate <= 0.0])
	e.die(false)
	# The survivor's own
	arms.wear["body"] = "scrap_plate"
	player.max_health = 1000.0
	player.health = 1000.0
	var hp0 := player.health
	for i in 12:
		damage_player(30.0, player.global_position + Vector3(0, 0, -3))
		player.dodge_t = 0.0
	var left := WArms.plate_left(arms, "body")
	var cost := WArms.mend_cost(arms, "body")
	WArms.mend(arms, "body")
	var back := WArms.clean(JSON.parse_string(JSON.stringify(arms)))
	arms.plate = {"scrap_plate": 7.0}
	var kept := WArms.clean(JSON.parse_string(JSON.stringify(arms)))
	print("ARMOUR worn left=%d took=%d mend=%s whole=%d kept=%d" % [int(left), int(hp0 - player.health), cost, int(WArms.plate_left(back, "body")), int(WArms.plate_left(kept, "body"))])
	get_tree().quit()


## Testing aid: foes of the waste keep calm until they see or hear you. A suppressed shot is not heard
## from afar; a bare one is. One that sees you calls its band. A badly hurt Unlit runs, then returns.
func debug_minds() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0   # midday, so that no dawn unmakes the test's foes and sight is at its full
	player.max_health = 100000.0
	player.health = 100000.0
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var at := player.global_position - f * 60.0 + Vector3(0, 1.0, 0)
	var a := spawn_at("unlit_gun", at)
	a.rotation.y = atan2(-f.x, -f.z)   # looking away
	var b := spawn_at("unlit_blade", at + player.global_transform.basis.x * 3.0)
	b.rotation.y = a.rotation.y
	await get_tree().create_timer(1.0).timeout
	var calm: String = a.mind
	noise(player.global_position, 20.0)
	await get_tree().create_timer(0.5).timeout
	var after_quiet: String = a.mind
	noise(player.global_position, 110.0)
	await get_tree().create_timer(0.5).timeout
	var after_loud: String = a.mind
	var band: String = b.mind
	a.die(false)
	b.die(false)
	# Somewhere about the pilgrim out of any town's or camp's bounds (where foes are unmade)
	var spot := player.global_position + f * 20.0
	var found := false
	for rr in [20.0, 30.0, 40.0]:
		for i in 16:
			var a2 := i * TAU / 16.0
			var q: Vector3 = player.global_position + Vector3(cos(a2), 0, sin(a2)) * rr
			if not found and settlement_at(q, TOWN_SAFE + 4.0) == "" and base_at(q, 6.0) < 0 and absf(gpos(Vector2(q.x, q.z)).y - player.global_position.y) < 3.0:
				spot = q
				found = true
	var c := spawn_at("unlit_gun", Vector3(spot.x, gpos(Vector2(spot.x, spot.z)).y + 1.0, spot.z))
	var back_to := player.global_position - c.global_position
	c.rotation.y = atan2(back_to.x, back_to.z)   # facing the pilgrim
	c.max_hp = 3000.0   # so that a town's watch, if one is near, cannot end it before the test does
	c.hp = 3000.0
	await get_tree().create_timer(1.5).timeout
	var saw: String = c.mind
	c.hp = c.max_hp * 0.25
	for i in 4:
		await get_tree().physics_frame
	var ran: String = c.mind
	c._flee_t = minf(c._flee_t, 0.2)   # a short run, so the test stays clear of any town's bounds
	var back := ""
	for i in 30:
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(c):
			back = "gone"
			break
		back = c.mind
		if back == "hunt":
			break
	print("MINDS calm=%s quiet=%s loud=%s band=%s saw=%s hurt=%s back=%s" % [calm, after_quiet, after_loud, band, saw, ran, back])
	get_tree().quit()


## Testing aid: a sniper from an old save keeps its glass as a fitted scope; a new one has iron sights.
func debug_glass() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var old := WArms.clean({"owned": ["shotgun", "pistol", "sniper"], "primary": "sniper"})
	var fresh := WArms.clean(null)
	fresh.owned.append("sniper")
	var again := WArms.clean(JSON.parse_string(JSON.stringify(fresh)))
	print("GLASS old=%s new=%s" % ["scope" in old.mounts.get("sniper", []), "scope" in again.mounts.get("sniper", [])])
	get_tree().quit()


## Testing aid: a stray is won over with three meals, carries you faster, sprints on its breath,
## shares the harm, gets down, and comes back from a save.
func debug_cat() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	inv.add("raw_meat", 3)
	var c := WCat.new().setup(self, "floofspeeb", true)
	add_child(c)
	c.global_position = gpos(Vector2(player.global_position.x + 3.0, player.global_position.z))
	for i in 3:
		cat_used(c)
	var tamed := cat == c and not c.wild
	cat_used(c)
	var riding: bool = player.mount == c
	var walk: float = c.pace(false, 0.016)
	var sprint: float = c.pace(true, 0.016)
	var b0 := c.breath
	for i in 60:
		c.pace(true, 0.1)
	var spent := c.breath < b0
	player.max_health = 1000.0
	player.health = 1000.0
	var h0 := player.health
	var c0 := c.hp
	damage_player(40.0, player.global_position + Vector3(0, 0, -3))
	var shared := c.hp < c0 and h0 - player.health < 40.0
	await get_tree().create_timer(0.3).timeout
	var followed := c.global_position.distance_to(player.global_position) < 0.5
	dismount()
	var off: bool = player.mount == null and not c.ridden
	var saved := c.to_data()
	saved.name = "Biscuit"
	c.queue_free()
	cat = null
	_cat_saved = saved
	await get_tree().create_timer(0.5).timeout
	print("CAT tamed=%s riding=%s faster=%s sprint=%s spent=%s shared=%s followed=%s off=%s back=%s" % [tamed, riding, walk > player.walk_speed, sprint > walk * 1.5, spent, shared, followed, off, cat != null and cat.cat_name == "Biscuit"])
	get_tree().quit()


## Testing aid: a struck form bleeds, and does not when blood is turned off.
func debug_blood() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var e := spawn_at("rusher", player.global_position + Vector3(0, 0.5, -4))
	e.hp = 1000.0
	e.set_meta("raid", true)
	Game.blood = true
	var b0 := LesserSpeeb.blood_shown
	e.hurt(20.0, Vector3(0, 0, -1))
	var on := LesserSpeeb.blood_shown - b0
	Game.blood = false
	e.hurt(20.0, Vector3(0, 0, -1))
	var off := LesserSpeeb.blood_shown - b0 - on
	Game.blood = true
	print("BLOOD on=%d off=%d" % [on, off])
	get_tree().quit()


func debug_knock() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	for k in ["idol", "rusher"]:
		var fwd: Vector3 = -player.global_transform.basis.z
		var e := spawn_at(k, player.global_position + fwd * 12.0 + Vector3(0, 0.5, 0))
		e.set_meta("raid", true)
		e.hp = 5000.0
		e._attack_cd = 99.0
		await get_tree().create_timer(0.5).timeout
		var d0: float = e.global_position.distance_to(player.global_position)
		var far := 0.0
		for i in 12:
			LesserSpeeb.harm_kind = "bullet"
			e.hurt(24.0, fwd)
			LesserSpeeb.harm_kind = ""
			await get_tree().create_timer(0.16).timeout
			far = maxf(far, e.global_position.distance_to(player.global_position))
		var d1: float = e.global_position.distance_to(player.global_position)
		print("KNOCK %s start=%.1f furthest=%.1f end=%.1f player=%s foe=%s" % [k, d0, far, d1, player.global_position, e.global_position])
		e.die(false)
	get_tree().quit()


## Testing aid: parts change a gun, grades add traits, and saved arms come back the same.
func debug_parts() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var base: Dictionary = Arms.spec_of("shotgun")
	arms.parts["shotgun"] = ["long_barrel", "padded_stock", "heavy_receiver"]
	arms.mounts["shotgun"] = ["long_barrel", "padded_stock", "heavy_receiver"]
	arms.grade["shotgun/long_barrel"] = WArms.roll_grade(3)
	rearm()
	var now: Dictionary = Arms.spec_of("shotgun")
	print("PARTS range %.0f -> %.0f dmg %.1f -> %.1f kick %.2f -> %.2f" % [base.range, now.range, base.dmg, now.dmg, base.kick, now.kick])
	print("PARTS grade traits=%d name=%s text=%s" % [arms.grade["shotgun/long_barrel"].t.size(), WArms.part_name(arms, "shotgun", "long_barrel"), WArms.mods_text(WArms.mods(arms, "shotgun"))])
	var back := WArms.clean(JSON.parse_string(JSON.stringify(arms)))
	print("PARTS saved same=%s" % [back.mounts.get("shotgun", []) == arms.mounts["shotgun"] and back.grade.get("shotgun/long_barrel", {}).get("t", []) == arms.grade["shotgun/long_barrel"].t])
	get_tree().quit()


## Testing aid: the blade held, for a picture.
func debug_bladeshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	player.weapon.draw_blade()
	player.stamina = 55.0
	player._breath = 99.0


## Testing aid: the world's settings take hold, are saved, and show in their dialog.
func debug_rules() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	set_rules({"difficulty": 2, "enemies": 0, "death": 1, "air": 0, "ammo": 1, "skill": 0})
	await get_tree().create_timer(0.5).timeout
	var e = _spawn_near("rusher", player.global_position, 10.0, 14.0, true)
	print("RULES diff_scale=%.2f spawn_none=%s unlimited=%s windup=%.2f saved=%s" % [Game.difficulty_scale("damage"), e == null, Net.unlimited_ammo(), WRules.windup(), world_data().rules])
	inv.add("wood", 5)
	var before := inv.count("wood")
	_perish("Test.")
	await get_tree().create_timer(0.5).timeout
	print("RULES kept wood=%d of %d" % [inv.count("wood"), before])
	get_tree().quit()


func debug_rulesshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	hud.show_rules(rules, true, func(_r): pass)


## Testing aid: opens talk, trade, journal and skills in turn for screenshots.
func debug_menushot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	inv.add("coin", 6)
	inv.add("bell", 1)
	skills.points = 2
	var pid: String = WPlaces.PEOPLE.keys()[0]
	for k in WPlaces.PEOPLE:
		if Items.STOCK.has(WPlaces.PEOPLE[k].role):
			pid = k
			break
	ui.open_dialogue(pid)
	await get_tree().create_timer(5.0).timeout
	ui._tsel = "bandage"
	ui._tside = "buy"
	ui._trade()
	await get_tree().create_timer(5.0).timeout
	ui.close_all()
	ui.open_journal()
	await get_tree().create_timer(5.0).timeout
	ui.close_all()
	ui.open_skills()


func debug_menushot2() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	skills.points = 2
	ui.open_journal()
	await get_tree().create_timer(4.0).timeout
	ui.close_all()
	ui.open_skills()


## Testing aid: every screen in turn, four seconds each, for pictures.
## pack, making, arms, chest, talk, trade, journal, skills, map, rest
func debug_tour() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	for it in [["wood", 30], ["scrap", 20], ["cloth", 8], ["stone", 20], ["meat", 3], ["shells", 30], ["bandage", 2], ["coin", 6], ["herb", 5], ["fittings_fine", 1]]:
		inv.add(it[0], it[1])
	skills.points = 2
	ui.debug_bench = true
	var steps := [
		func(): ui.open_inventory("pack"),
		func(): ui.open_inventory("craft"),
		func(): ui.open_inventory("arms"),
		func():
			builder._rq_build(1, "chest", player.global_position + Vector3(3, 0, 0), 0.0)
			await get_tree().create_timer(0.3).timeout
			_rq_open(1, "p%d" % pieces.keys()[0]),
		func():
			var pid: String = WPlaces.PEOPLE.keys()[0]
			for k in WPlaces.PEOPLE:
				if Items.STOCK.has(WPlaces.PEOPLE[k].role):
					pid = k
					break
			ui.open_dialogue(pid),
		func():
			ui._tsel = "bandage"
			ui._tside = "buy"
			ui._trade(),
		func(): ui.open_journal(),
		func(): ui.open_skills(),
		func(): ui.open_map(),
		func(): ui.ask_rest("bed"),
	]
	for f in steps:
		ui.close_all()
		await get_tree().process_frame
		await f.call()
		await get_tree().create_timer(4.0).timeout


## Testing aid: the making screen at a bench, then the pack.
func debug_craftshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	for it in [["wood", 30], ["scrap", 20], ["cloth", 8], ["stone", 20], ["meat", 3], ["shells", 30], ["bandage", 2], ["coin", 6], ["herb", 5], ["bone", 6]]:
		inv.add(it[0], it[1])
	ui.debug_bench = true
	ui.open_inventory("craft" if not "pack" in OS.get_cmdline_user_args() else "pack")


## Testing aid: one screen, named by screen=NAME, for a picture.
func debug_screen() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var which := "pack"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("screen="):
			which = a.substr(7)
	for it in [["wood", 30], ["scrap", 20], ["cloth", 8], ["stone", 20], ["meat", 3], ["shells", 30], ["bandage", 2], ["coin", 6], ["herb", 5], ["bone", 6]]:
		inv.add(it[0], it[1])
	skills.points = 2
	ui.debug_bench = true
	if which == "arms":
		inv.add("fittings_rare", 2)
		var g: String = arms.primary if arms.primary != "" else arms.owned[0]
		arms.parts[g] = WArms.mounts_for(g).slice(0, 3)
		arms.grade["%s/%s" % [g, arms.parts[g][0]]] = WArms.roll_grade(3)
		arms.grade["%s/%s" % [g, arms.parts[g][1]]] = WArms.roll_grade(1)
		arms.mounts[g] = [arms.parts[g][0], arms.parts[g][1]]
		rearm()
		ui._acat = "guns"
		ui._asel = g
	match which:
		"pack", "craft", "arms", "build":
			ui.open_inventory(which)
		"chest":
			builder._rq_build(1, "chest", player.global_position + Vector3(3, 0, 0), 0.0)
			await get_tree().create_timer(0.3).timeout
			_rq_open(1, "p%d" % pieces.keys()[0])
		"talk", "trade":
			var pid: String = WPlaces.PEOPLE.keys()[0]
			for k in WPlaces.PEOPLE:
				if Items.STOCK.has(WPlaces.PEOPLE[k].role):
					pid = k
					break
			ui.open_dialogue(pid)
			if which == "trade":
				await get_tree().create_timer(1.0).timeout
				ui._tsel = "bandage"
				ui._tside = "buy"
				ui._trade()
		"journal":
			ui.open_journal()
		"skills":
			ui.open_skills()
		"map":
			ui.open_map()
		"rest":
			ui.ask_rest("bed")
		"blood":
			var f := -player.global_transform.basis.z
			f.y = 0.0
			var e := spawn_at("rusher", player.global_position + f.normalized() * 4.0 + Vector3(0, 0.5, 0))
			e.hp = 5000.0
			e.set_meta("raid", true)
			e._attack_cd = 999.0
			for i in 150:
				e.hurt(25.0, f.normalized())
				e.hp = 5000.0
				await get_tree().create_timer(0.15).timeout
		"foes":
			var f := -player.global_transform.basis.z
			f.y = 0.0
			f = f.normalized()
			var x := player.global_transform.basis.x
			var ks := ["unlit_gun", "unlit_blade", "unlit_brute", "hollow", "saltbone", "vigil", "warden"]
			for i in ks.size():
				var e := spawn_at(ks[i], player.global_position + f * (5.0 + (i % 2) * 2.5) + x * (i - 3) * 1.6 + Vector3(0, 1.0, 0))
				e.set_meta("raid", true)
				e._attack_cd = 999.0
				e.spec = e.spec.duplicate()
				e.spec.speed = 0.0
				e.rotation.y = atan2(-f.x, -f.z)
				if ks[i] == "unlit_gun":
					e._fb.play("holding-both")
				if ks[i] == "unlit_blade":
					e._fb.act("attack-melee-right", 0.3)
		"scope":
			if not "sniper" in arms.owned:
				arms.owned.append("sniper")
			arms.primary = "sniper"
			arms.parts["sniper"] = ["scope"]
			arms.mounts["sniper"] = ["scope"]
			rearm()
			player.weapon.debug_aim = true
			var f := -player.global_transform.basis.z
			f.y = 0.0
			var e := spawn_at("unlit_gun", player.global_position + f.normalized() * 30.0 + Vector3(0, 1.0, 0))
			e.set_meta("raid", true)
			e._attack_cd = 999.0
		"cat", "ride":
			var c := WCat.new().setup(self, "floofspeeb", false)
			c.cat_name = "Biscuit"
			c.barding = "bone_barding"
			cat = c
			add_child(c)
			var f := -player.global_transform.basis.z
			f.y = 0.0
			var at := player.global_position + f.normalized() * 4.0
			c.global_position = gpos(Vector2(at.x, at.z))
			c.rotation.y = player.yaw + PI * 0.6
			c._refresh()
			if which == "ride":
				ride()
		"reload":
			# A reload held still at one moment (k=0..1), on the gun named by gun=
			var g := "machine_gun"
			var k := 0.3
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("gun="):
					g = a2.substr(4)
				if a2.begins_with("k="):
					k = float(a2.substr(2))
			if not g in arms.owned:
				arms.owned.append(g)
			arms[ArmsDB.GUNS[g].slot] = g
			rearm()
			var w = player.weapon
			if ArmsDB.GUNS[g].slot == "secondary" and w.cur == 0:
				w.cur = 1
				w.equip_loadout()
			inv.add(Items.AMMO[g], 99)
			w.shells = 0
			w._start_reload()
			w._reload_len = 10000.0
			w._reload_t = 10000.0 * (1.0 - k)
			w._ui()
		"warn":
			var f := -player.global_transform.basis.z
			f.y = 0.0
			f = f.normalized()
			_w_warn(player.global_position + f * 9.0, 7.0, 18.0, 0)
			_w_warn(player.global_position + f * 14.0 + player.global_transform.basis.x * 6.0, 2.6, 18.0, 2)
			_w_warn(player.global_position + f * 12.0 - player.global_transform.basis.x * 7.0, 8.0, 18.0, 1, atan2(f.x, f.z), 2.2)


func debug_restshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	ui.ask_rest("bed")



## Shoots each foe of the waste with a body at its feet, chest and head: every shot should strike it and
## harm it, and the one at the head should count as a head shot.
func debug_hitbox() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var all := true
	var heads := true
	for k in ["unlit_gun", "unlit_blade", "unlit_brute", "hollow", "saltbone", "vigil", "warden"]:
		var e = spawn_at(k, player.global_position + f * 8.0 + Vector3(0, 1.0, 0))
		e.set_meta("raid", true)
		e.set_physics_process(false)
		e.set_process(false)
		for i in 20:
			await get_tree().physics_frame
		var base: Vector3 = e.global_position
		var lo := 1e9
		var hi := -1e9
		for mi in e._fb.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			lo = minf(lo, ab.position.y)
			hi = maxf(hi, ab.end.y)
		var line := ""
		var space := get_world_3d().direct_space_state
		for frac in [0.2, 0.5, 0.85]:
			var o := Vector3(base.x, lerpf(lo, hi, frac), base.z) - f * 3.0
			var q := PhysicsRayQueryParameters3D.create(o, o + f * 6.0, 2)
			var r := space.intersect_ray(q)
			var struck: bool = not r.is_empty() and r.collider == e
			line += "X" if struck else "."
			all = all and struck
			if frac == 0.85 and k != "vigil":
				var wp: Array = e.weak_point()
				var head_hit := not wp.is_empty() and Arms._ray_near(o, f, wp[0], wp[1])
				heads = heads and head_hit
		var hp0: float = e.hp
		e.hurt(10.0, f)
		all = all and e.hp < hp0
		print("HIT %s %.2f..%.2f %s" % [k, lo - base.y, hi - base.y, line])
		e.queue_free()
	print("HITBOX all=%s heads=%s" % [all, heads])
	get_tree().quit()
