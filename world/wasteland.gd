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
const FIRE_KINDS := ["campfire", "cookpot", "torch", "stove"]
const WOOD_HOURS := 24.0     ## one piece of wood keeps a fire for a whole day
const FUEL_MAX := 240.0      ## a fire holds ten days of wood at most
const FUEL_START := 72.0     ## a new fire is laid with three days' wood
const REVEAL_N := 256

var terrain: WTerrain
var sea: WSea
var boats := {}          ## boat id -> WBoat, on the Grey Sea
var life: WIsleLife   ## landings, wrecks and what lives on the isles
var weather: WWeather
var air: WAir   ## each land's own haze, and what drifts in it
var boat_next := 1
var inv := Inventory.new()
var cat: WCat = null      ## this survivor's own riding cat, once one is tamed
var _cat_saved := {}      ## the cat as saved, until the world is ready to place it
var _stray: WCat = null   ## a stray near a town that could be won over
var _stray_t := 5.0
var arms: Dictionary = WArms.clean(null)   ## this survivor's guns, parts and kit
var dev: WDev            ## the hidden playtest menu's tools
var alchemy: WAlchemy    ## what the pilgrim knows of brewing, and the draughts working now
var dread: WDread        ## fear of the open dark, and what it draws
var settlers: WSettlers  ## wanderers who have settled at a base
var kraken: WKraken      ## the whirlpool out past the Sunk Fen
var events: WEvents      ## roaming events: short goals between the long ones
var spirits: WSpirits    ## spirit-cat relics, and the one running with you
var trades: WTrades      ## the pilgrim's trade: smith, cook, alchemist or tinker
var endings: WEndings    ## Mother Ruth, and the leaves of Brelm's journal
var dev_fast := 1.0      ## the stride, sped up from the playtest menu
var skills := WSkills.new()
var seen_biomes := {}
var ui: WUI
var builder: WBuilder
var quests: WQuests
var hall: WHall   ## the Tenth Hall, under the ninth beacon
var deep: WDeep   ## the Lamp-Eater and the Drowned Fleet, far out on the Grey Sea
var vaults: WVaults   ## the rooms under the sealed vaults, and their keepers
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
	weather = WWeather.new().setup(self)
	add_child(weather)
	air = WAir.new().setup(self)
	dev = WDev.new(self)
	alchemy = WAlchemy.new(self)
	dread = WDread.new(self)
	settlers = WSettlers.new(self)
	kraken = WKraken.new(self)
	events = WEvents.new().setup(self)
	add_child(events)
	spirits = WSpirits.new(self)
	trades = WTrades.new(self)
	endings = WEndings.new(self)
	add_child(air)
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
		# Worlds made before 0.9 keep their land as it was; new ones begin on the Ash Plains
		_make_world(sd, int(_pending.get("gen", 1)) if not _pending.is_empty() else GEN)
	else:
		spawn_pos = Vector3(0, 400, 0)
	ambient("wind", -10)
	_beds = {"night": ambient("amb_desert_night", -60), "town": ambient("amb_town", -60), "cave": ambient("amb_cave", -60),
		"forest": ambient("amb_forest", -60), "birds": ambient("amb_birds", -60), "crickets": ambient("amb_crickets", -60),
		"lake": ambient("amb_lake", -60), "river": ambient("amb_river", -60)}


var world_seed := 0
var _pending := {}
const GEN := 2          ## how the land is raised: 2 keeps the Ash Plains about where the cast-out wake
var world_gen := GEN


## Raises the whole waste from its seed: the land and its six biomes, then the places upon it.
func _make_world(sd: int, gen := GEN) -> void:
	world_seed = sd
	world_gen = gen
	terrain = WTerrain.new()
	terrain.setup(sd)
	WPlaces.lay_out(sd, func(p: Vector2) -> Vector2: return Vector2(terrain.legacy_raw(p.x, p.y), terrain_probe(p)))
	if gen >= 2:
		terrain.home = WPlaces.start
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
	for k in WPlaces.SETTLEMENTS:
		_town_paths(k)
	terrain.generate()
	for r in ruins:
		r.pos.y = terrain.height_at(r.pos.x, r.pos.z)
	for l in lairs:
		l.pos.y = terrain.height_at(l.pos.x, l.pos.z)
	terrain.build(_m.ground)
	terrain.make_isles(_m.ground)
	add_child(terrain)
	# The isles' hearts: a ruin on each, keeping a lost book (their own ids, after all the rest)
	for il in terrain.isles:
		var hp: Vector2 = terrain.isle_heart(il)
		var th: Dictionary = WIsles.THEMES[il.key]
		ruins.append({"id": "isle_" + str(il.key), "name": th.ruin[0], "kind": th.ruin[1], "pos": Vector3(hp.x, terrain.height_at(hp.x, hp.y), hp.y), "guard_day": 0, "isle": il.key})
		WPlaces.ruin_at["isle_" + str(il.key)] = hp
	sea = WSea.new().setup(self)
	add_child(sea)
	for k in WPlaces.SETTLEMENTS:
		var s0 := get_child_count()
		_build_settlement(k)
		_batch_since(s0)
	for i in WPlaces.BEACONS.size():
		_build_beacon(i)
	var before := get_child_count()
	for r in ruins:
		var r0 := get_child_count()
		_build_ruin(r)
		_batch_since(r0)
	for i in range(before, get_child_count()):
		_fade_far(get_child(i), 700.0)
	for l in lairs:
		_build_lair(l)
	_scatter_nodes()
	_scatter_isle_nodes()
	_scatter_ammo()
	sea.build_isles()
	life = WIsleLife.new().setup(self)
	add_child(life)
	life.build()
	for nd in nodes:
		_off_the_road(nd)
		_fade_far(nd.node, 420.0)
	_build_signposts()
	_scatter_decor()
	WDress.cover(self)
	hall = WHall.new(self)
	hall.build()
	deep = WDeep.new(self)
	vaults = WVaults.new(self)
	kraken.build()
	endings.build()
	vaults.place_stairs()
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


## The ground's own shader: the land's colour with photographed grain and relief (assets/textures/ground).
static func ground_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://world/ground.gdshader")
	for k in ["ground_a", "ground_b", "ground_n1", "ground_n2", "ground_n3", "ground_n4"]:
		m.set_shader_parameter(k, load("res://assets/textures/ground/%s.png" % k))
	return m


func _materials() -> void:
	_m.ground = ground_mat()
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
		_stuck_tick(delta)
		_boss_watch()
		_bed_t -= delta
		if _bed_t <= 0.0:
			_bed_t = 0.5
			_place_sounds()
			_landmarks_tick()
		_cat_tick(delta)
		_power_tick(delta)
		if hall:
			hall.local_tick(delta)
		if deep:
			deep.local_tick()
		if dread and ready_world:
			dread.local_tick(delta)
		if kraken and ready_world:
			kraken.local_tick(delta)


## Fades the sound of each place toward how near it is: a town's bustle by day, the night's insects
## after dark, the wind in a hollow among ruins and lairs.
func _place_sounds() -> void:
	if _beds.is_empty() or terrain == null:   # a joiner has no land until the host's snapshot comes
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
	# Each land has its own sound under the wind: the forest's leaves, the marsh's water, birds on the
	# green isles, insects in the wet places after dark
	var land := str(terrain.biome_name(p.x, p.z))
	var il: Dictionary = terrain.isle_at(p.x, p.z, 1.2)
	var isle: String = str(il.get("key", ""))
	var day_k := 0.0 if night else 1.0
	var open := (1.0 - town) * (1.0 - cave * 0.6)
	var wet := land == "marsh" or isle == "fen"
	var want := {"night": (1.0 if night else 0.0) * (1.0 - town * 0.5) * (0.4 if wet or land == "forest" else 1.0), "town": town * (0.35 if night else 1.0), "cave": cave * 0.8,
		"forest": (0.9 if land == "forest" and isle == "" else 0.0) * day_k * open,
		"birds": (0.8 if isle in ["hrafn", "kala"] else 0.0) * day_k * open,
		"crickets": (0.9 if wet or land == "forest" or isle == "kala" else 0.0) * (1.0 - day_k) * open,
		"lake": (0.8 if wet else 0.0) * open,
		"river": (0.7 if isle == "cog" else 0.0) * open}
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
## Gathers the still pieces of what was just built (children from i0 on) into a few meshes (see WBatch).
func _batch_since(i0: int) -> void:
	var roots: Array = []
	for i in range(i0, get_child_count()):
		roots.append(get_child(i))
	var keep := {}
	for id in crates:
		if crates[id].get("lid") != null:
			keep[crates[id].lid] = true
	WBatch.merge(self, roots, keep)


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
	# Houses you can walk into about the edge, an inn, and a fire at the heart
	for b in _town_plan(k):
		_town_house(k, c, b)
	var folk: Array = []
	for pid in WPlaces.PEOPLE:
		if WPlaces.PEOPLE[pid].at == k:
			folk.append(WPlaces.PEOPLE[pid].off)
	WDress.town(self, k, c, r, _town_plan(k), folk)
	cyl(c + Vector3(0, 0.15, 0), 1.3, 0.3, _m.stone, true, -1.0, 10)
	for i in 5:
		var lg := box(c + Vector3(0, 0.35, 0), Vector3(0.22, 0.22, 1.6), _m.darkwood, false)
		lg.rotation.y = i * TAU / 5.0
		lg.rotation.x = 0.3
	var fl := omni(c + Vector3(0, 2.0, 0), Color(1.0, 0.6, 0.3), 2.6, 22.0, true)
	var fire := WFire.make(1.9, true, false).with_light(fl)
	fire.position = c + Vector3(0, 0.2, 0)
	add_child(fire)
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


# ------------------------------------------------------------------ the towns' houses and inns

const INN_NAMES := ["The Banked Ember", "The Last Lamp", "The Dry Cup", "The Crooked Kettle", "The Bone and Bowl",
	"The Sleeping Cat", "The White Hearth", "The Salt Cellar", "The Long Night"]
const INN_MEALS := ["stew", "broth", "tea", "pie", "roast"]
var inn_beds: Array = []      ## where the inns' beds stand: a night there is the snuggest rest in the waste
var _rumoured := {}           ## ruins already told of at an inn, this session


## Where a town's buildings stand, the same every time. Each town has its own way of being laid out:
## a ring about the fire, a street between the gates, or houses clustered as they were put up.
## Each: {kind, off, yaw, w, d} (w, d in cells for houses and the inn; a few metres for the rest).
const TOWN_STYLES := ["ring", "street", "cluster"]


func town_style(k: String) -> String:
	return TOWN_STYLES[absi(hash(k + "style")) % TOWN_STYLES.size()]


func _town_plan(k: String) -> Array:
	var s: Dictionary = WPlaces.SETTLEMENTS[k]
	var r: float = s.radius
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(k) + 77
	var G := WBuilder.GRID
	var style := town_style(k)
	var folk: Array = []
	for pid in WPlaces.PEOPLE:
		if WPlaces.PEOPLE[pid].at == k:
			folk.append(WPlaces.PEOPLE[pid].off)
	var out: Array = []
	# Whether a footprint of radius fr fits at off: inside the wall, off the gate road and the hearth,
	# clear of the people who stand there and of what is built already
	var fits := func(off: Vector2, fr: float) -> bool:
		if off.length() + fr > r - 2.5 or off.length() - fr < 5.5:
			return false
		if absf(off.x) < fr + 2.2 and absf(off.y) > r * 0.45:
			return false   # the gate road, north to south
		for f in folk:
			if (f as Vector2).distance_to(off) < fr + 2.0:
				return false
		for o in out:
			if (o.off as Vector2).distance_to(off) < fr + float(o.fr) + 1.2:
				return false
		return true
	var foot := func(w: float, d: float) -> float:
		return 0.5 * Vector2(w, d).length()
	var face_c := func(off: Vector2) -> float:
		return atan2(-off.x, -off.y)
	# The inn first, toward the middle
	var inn_fr: float = foot.call(3 * G, 2 * G)
	for a in [0.0, PI, 0.5, PI - 0.5, -0.5, PI + 0.5, 1.0, PI - 1.0]:
		var off := Vector2(cos(a), sin(a)) * r * 0.5
		if fits.call(off, inn_fr - 1.0):
			out.append({"kind": "inn", "off": off, "yaw": face_c.call(off), "w": 3, "d": 2, "fr": inn_fr - 1.0})
			break
	# Then the houses, of a few sizes
	var want := 8 + rr.randi() % 4
	var tries := 0
	while tries < 400 and out.size() < want + 1:
		tries += 1
		var w: int = [2, 2, 2, 3][rr.randi() % 4]
		var d: int = [2, 2, 3][rr.randi() % 3]
		var fr: float = foot.call(w * G, d * G) - 0.6
		var off := Vector2.ZERO
		var yaw := 0.0
		match style:
			"ring":
				var a := rr.randf() * TAU
				off = Vector2(cos(a), sin(a)) * r * rr.randf_range(0.58, 0.7)
				yaw = face_c.call(off) + rr.randf_range(-0.12, 0.12)
			"street":
				# Two rows facing each other across the road from gate to gate
				var side := -1.0 if rr.randf() < 0.5 else 1.0
				off = Vector2(side * rr.randf_range(7.5, 9.5), rr.randf_range(-r * 0.75, r * 0.75))
				if absf(off.y) < 7.0:
					continue   # the square about the fire
				yaw = -PI * 0.5 * side + rr.randf_range(-0.06, 0.06)
			_:
				var a := rr.randf() * TAU
				off = Vector2(cos(a), sin(a)) * r * rr.randf_range(0.32, 0.72)
				yaw = face_c.call(off) + rr.randf_range(-0.7, 0.7)
		if style == "street" and absf(off.x) < fr + 2.2:
			continue
		if not fits.call(off, fr):
			continue
		out.append({"kind": "house", "off": off, "yaw": yaw, "w": w, "d": d, "fr": fr})
	# And what a town has besides: a smithy, a well, market stalls, a watchtower by the wall
	var extras := [["smithy", 3.2], ["well", 1.6], ["stall", 1.8], ["stall", 1.8], ["tower", 1.8]]
	if s.get("far", false):
		extras = [["well", 1.6], ["stall", 1.8], ["tower", 1.8]]
	for ex in extras:
		for t in 60:
			var a := rr.randf() * TAU
			var dist: float = r * (rr.randf_range(0.82, 0.88) if ex[0] == "tower" else rr.randf_range(0.25, 0.6))
			var off := Vector2(cos(a), sin(a)) * dist
			if ex[0] == "tower" and off.length() + float(ex[1]) > r - 1.0:
				off = off.normalized() * (r - float(ex[1]) - 1.2)
			var ok := true
			if ex[0] == "tower":
				for o in out:
					if (o.off as Vector2).distance_to(off) < float(o.fr) + float(ex[1]) + 1.0:
						ok = false
				if absf(off.x) < 6.0 and absf(off.y) > r * 0.45:
					ok = false
			else:
				ok = fits.call(off, float(ex[1]))
			if ok:
				out.append({"kind": ex[0], "off": off, "yaw": face_c.call(off) + rr.randf_range(-0.3, 0.3), "w": 1, "d": 1, "fr": float(ex[1])})
				break
	return out


## Footpaths worn from the gates through the middle, and from each door to the fire.
func _town_paths(k: String) -> void:
	var c := WPlaces.spos(k)
	var r: float = WPlaces.SETTLEMENTS[k].radius
	terrain.add_road(PackedVector2Array([c + Vector2(0, -r - 4.0), c, c + Vector2(0, r + 4.0)]), 3.2)
	for b in _town_plan(k):
		if not b.kind in ["house", "inn"]:
			continue
		# From the door (on the house's front) out and on toward the fire
		var front := Vector2(sin(float(b.yaw)), cos(float(b.yaw)))
		var door: Vector2 = c + b.off + front * (float(b.d) * WBuilder.GRID * 0.5 + 1.0)
		var mid: Vector2 = door + front * 2.5
		terrain.add_road(PackedVector2Array([door, mid, c + (mid - c).normalized() * 3.0]), 2.0)


## A house of the kit, its door toward the fire: floor, walls, a roof, and what people keep inside.
## An inn is larger, with tables, a counter for hot meals and talk, and beds to rent.
var town_doors: Array = []   ## [a step outside a house's door, a step inside it], for the walk test

func _town_house(k: String, c: Vector3, b: Dictionary) -> void:
	if not b.kind in ["house", "inn"]:
		_town_extra(k, c, b)
		return
	var G := WBuilder.GRID
	var W: float = float(b.w) * G
	var D: float = float(b.d) * G
	var n := Node3D.new()
	add_child(n)
	var at := c + Vector3(b.off.x, 0, b.off.y)
	# The floor sits on the highest ground under the house, so no corner of the land pokes through it
	var hi := terrain.height_at(at.x, at.z)
	for cx in [-0.5, 0.5]:
		for cz in [-0.5, 0.5]:
			var q := at + Vector3(cx * W, 0, cz * D).rotated(Vector3.UP, b.yaw)
			hi = maxf(hi, terrain.height_at(q.x, q.z))
	n.position = Vector3(at.x, hi + 0.05, at.z)
	n.rotation.y = b.yaw
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(k) + int(b.off.x * 13.0) + int(b.off.y * 7.0)
	# Each house its own: timber or stone, one storey or two, its roof, a porch, a chimney, its yard
	var stony: float = 0.7 if k in ["kiln", "hesk", "gallowmere", "lastlight"] else 0.25
	var tier := 1 if rr.randf() < stony else 0
	var inn: bool = b.kind == "inn"
	var tall: bool = inn or (rr.randf() < 0.3 and int(b.w) >= 2)
	var roof_kind := rr.randi() % 4   # 0 thatch, 1 plank, 2 flat with a parapet, 3 iron lean-to
	if inn:
		roof_kind = 1
	# The floor: one slab, its top at the house's ground
	var fb := StaticBody3D.new()
	fb.collision_layer = 1
	n.add_child(fb)
	builder._part(n, fb, Vector3(W, 1.0, D), Vector3(0, -0.5, 0), _m.stone if tier else _m.darkwood, false)
	builder._kit(n, "planks", Vector3(W, 1.0, D), Vector3(0, -0.02, 0), 0.0)
	# The walls, cell by cell; the door in the middle of the front, toward the fire
	var door_i := int(b.w) / 2
	# A ramp up to the door where the ground falls away below the floor
	var door_x := -W * 0.5 + (door_i + 0.5) * G
	var ramp_len := 1.8
	var outside := n.position + Vector3(door_x, 0, D * 0.5 + ramp_len).rotated(Vector3.UP, b.yaw)
	var lip := n.position.y - terrain.height_at(outside.x, outside.z)
	town_doors.append([outside, n.position + Vector3(door_x, 0.2, D * 0.5 - G * 0.6).rotated(Vector3.UP, b.yaw)])
	if lip > 0.12:
		var run := sqrt(ramp_len * ramp_len + lip * lip)
		var ramp := builder._part(n, fb, Vector3(G * 0.8, 0.2, run), Vector3(door_x, -lip * 0.5 - 0.1, D * 0.5 + ramp_len * 0.5), _m.darkwood, false)
		var tilt := atan2(lip, ramp_len)
		if ramp is Node3D:
			(ramp as Node3D).rotation.x = tilt
		var rcs := fb.get_child(fb.get_child_count() - 1)
		if rcs is CollisionShape3D:
			(rcs as CollisionShape3D).rotation.x = tilt
	for i in int(b.w):
		var x := -W * 0.5 + (i + 0.5) * G
		_town_wall(n, "doorway" if i == door_i else ("window" if rr.randf() < 0.6 else "wall"), Vector3(x, 0, D * 0.5), 0.0, tier)
		_town_wall(n, "window" if rr.randf() < 0.4 else "wall", Vector3(x, 0, -D * 0.5), 0.0, tier)
	for j in int(b.d):
		var z := -D * 0.5 + (j + 0.5) * G
		for side in [-1.0, 1.0]:
			_town_wall(n, "window" if rr.randf() < 0.35 else "wall", Vector3(side * W * 0.5, 0, z), PI * 0.5, tier)
	# A ceiling; a second storey for some (seen from without, a loft within)
	builder._part(n, fb, Vector3(W + 0.3, 0.12, D + 0.3), Vector3(0, 3.06, 0), _m.darkwood, false)
	var top := 3.12
	if tall:
		for i in int(b.w):
			var x := -W * 0.5 + (i + 0.5) * G
			_town_wall(n, "window" if rr.randf() < 0.5 else "wall", Vector3(x, top, D * 0.5), 0.0, tier)
			_town_wall(n, "window" if rr.randf() < 0.4 else "wall", Vector3(x, top, -D * 0.5), 0.0, tier)
		for j in int(b.d):
			var z := -D * 0.5 + (j + 0.5) * G
			for side in [-1.0, 1.0]:
				_town_wall(n, "wall", Vector3(side * W * 0.5, top, z), PI * 0.5, tier)
		builder._part(n, fb, Vector3(W + 0.3, 0.12, D + 0.3), Vector3(0, top + 3.06, 0), _m.darkwood, false)
		top += 3.12
	_town_roof(n, fb, roof_kind, W, D, top, rr)
	# A porch over the door, a chimney with its smoke, a lantern, and what is left out in the yard
	var front := D * 0.5
	if rr.randf() < (1.0 if inn else 0.45):
		var pw: float = minf(W - 0.4, 4.2)
		for side in [-1.0, 1.0]:
			builder._part(n, fb, Vector3(0.16, 2.5, 0.16), Vector3(side * pw * 0.5, 1.25, front + 1.6), _m.darkwood, false)
		var aw := builder._part(n, null, Vector3(pw + 0.5, 0.1, 1.9), Vector3(0, 2.62, front + 0.9), _m.thatch if roof_kind == 0 else _m.darkwood, false)
		aw.rotation.x = -0.18
	if rr.randf() < 0.4 or inn:
		var cx := rr.randf_range(-W * 0.3, W * 0.3)
		builder._part(n, fb, Vector3(0.7, 2.2, 0.7), Vector3(cx, top + 0.9, -D * 0.25), _m.stone, false)
		if _town_smokes < 3:
			_town_smokes += 1
			_smoke(n.to_global(Vector3(cx, top + 2.2, -D * 0.25)) if n.is_inside_tree() else n.position + Vector3(0, top + 2.2, 0))
	var lan := builder._part(n, null, Vector3(0.18, 0.26, 0.18), Vector3(G * 0.5 + 0.2 - W * 0.5 + int(b.w) / 2 * G + 0.75, 2.2, front + 0.18), _m.ember, false)
	lan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in rr.randi() % 4:
		var at2 := Vector3(rr.randf_range(-W * 0.5, W * 0.5), 0, rr.randf_range(-D * 0.5, D * 0.5))
		at2 += (Vector3(W * 0.5 + 0.7, 0, 0) if rr.randf() < 0.5 else Vector3(-W * 0.5 - 0.7, 0, 0)) * Vector3(1, 0, 0)
		at2.x = clampf(at2.x, -W * 0.5 - 0.9, W * 0.5 + 0.9)
		if absf(at2.x) < W * 0.5 + 0.4:
			at2.x = signf(at2.x if at2.x != 0.0 else 1.0) * (W * 0.5 + 0.7)
		WDress.yard(n, k, at2, rr)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.72, 0.42) if rr.randf() < 0.7 else Color(1.0, 0.82, 0.6)
	lamp.light_energy = 1.4 if inn else 0.9
	lamp.omni_range = 8.0 if inn else 5.5
	lamp.position = Vector3(0, 2.4, 0)
	n.add_child(lamp)
	if inn:
		_inn_inside(k, n, W, D)
	else:
		# Furnished a little differently in each house: which side the bed is, what else is kept
		var flip := -1.0 if rr.randf() < 0.5 else 1.0
		_furnish(n, "bed", Vector3(flip * (W * 0.5 - 1.1), 0, -D * 0.5 + 1.3), 0.0)
		_furnish(n, "table", Vector3(-flip * (W * 0.5 - 1.4), 0, -0.3), PI * 0.5)
		WDress.table_top(n, Vector3(-flip * (W * 0.5 - 1.4), 0.76, -0.3), PI * 0.5, rr)
		_furnish(n, "chair", Vector3(-flip * (W * 0.5 - 1.4), 0, 0.8), PI)
		if rr.randf() < 0.7:
			_furnish(n, "shelf", Vector3(-flip * (W * 0.5 - 0.6), 0, -D * 0.5 + 0.5), PI * 0.5 * flip)
		if rr.randf() < 0.6:
			_furnish(n, "rug", Vector3(0.3, 0.02, 0.6), rr.randf() * 0.3)
		if rr.randf() < 0.4:
			var sv := Vector3(flip * (W * 0.5 - 0.6), 0, D * 0.5 - 1.6 if D > 6.5 else 0.6)
			_furnish(n, "stove", sv, -PI * 0.5 * flip)
			WDress.kp(n, "food", "pot-stew" if rr.randf() < 0.6 else "frying-pan", sv + Vector3(0, 0.99, 0), rr.randf() * TAU, 0.8, false, Vector3.ZERO, 60.0)
		if rr.randf() < 0.35:
			_furnish(n, "floorlamp", Vector3(flip * (W * 0.5 - 0.5), 0, -D * 0.5 + 2.6), 0.0)
	_fade_far(n, 260.0)


var _town_smokes := 0


## A house's roof: thatch or planks pitched over it, a flat top behind a low parapet, or a rusted lean-to.
func _town_roof(n: Node3D, fb: StaticBody3D, kind: int, W: float, D: float, top: float, rr: RandomNumberGenerator) -> void:
	match kind:
		0, 1:
			var roof := MeshInstance3D.new()
			var pm := PrismMesh.new()
			var pitch := rr.randf_range(1.3, 2.3)
			# Ridge along the longer side
			var along_x := W >= D
			pm.size = Vector3(W + 1.0, pitch, D + 1.0) if along_x else Vector3(D + 1.0, pitch, W + 1.0)
			roof.mesh = pm
			roof.material_override = _m.thatch if kind == 0 else _m.darkwood
			roof.position = Vector3(0, top + pitch * 0.5, 0)
			if not along_x:
				roof.rotation.y = PI * 0.5
			# A prism's ridge runs along z; turn it so the ridge runs along the long side
			roof.rotation.y += PI * 0.5
			n.add_child(roof)
		2:
			builder._part(n, fb, Vector3(W + 0.3, 0.2, D + 0.3), Vector3(0, top + 0.1, 0), _m.stone, false)
			for side in [-1.0, 1.0]:
				builder._part(n, fb, Vector3(W + 0.3, 0.6, 0.25), Vector3(0, top + 0.5, side * (D * 0.5 + 0.03)), _m.stone, false)
				builder._part(n, fb, Vector3(0.25, 0.6, D + 0.3), Vector3(side * (W * 0.5 + 0.03), top + 0.5, 0), _m.stone, false)
		3:
			var sheet := builder._part(n, null, Vector3(W + 0.8, 0.12, D + 1.0), Vector3(0, top + 0.55, 0), _m.rust, false)
			sheet.rotation.x = 0.28 * (1.0 if rr.randf() < 0.5 else -1.0)


## What a town has besides houses: a smithy with its glowing forge, a well, market stalls under
## cloth, a watchtower by the wall.
func _town_extra(k: String, c: Vector3, b: Dictionary) -> void:
	var n := Node3D.new()
	add_child(n)
	var at := c + Vector3(b.off.x, 0, b.off.y)
	n.position = Vector3(at.x, terrain.height_at(at.x, at.z), at.z)
	n.rotation.y = b.yaw
	var fb := StaticBody3D.new()
	fb.collision_layer = 1
	n.add_child(fb)
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(k) + int(b.off.x * 17.0) + int(b.off.y * 3.0)
	match str(b.kind):
		"smithy":
			# An open shed: four posts and a roof, the forge at the back, the anvil before it
			for p in [Vector2(-2.2, -1.8), Vector2(2.2, -1.8), Vector2(-2.2, 1.8), Vector2(2.2, 1.8)]:
				builder._part(n, fb, Vector3(0.2, 3.0, 0.2), Vector3(p.x, 1.5, p.y), _m.darkwood, false)
			var rf := builder._part(n, null, Vector3(5.2, 0.14, 4.4), Vector3(0, 3.1, 0), _m.rust, false)
			rf.rotation.x = 0.15
			builder._part(n, fb, Vector3(1.6, 1.0, 1.2), Vector3(0, 0.5, -1.4), _m.stone, false)
			var coals := builder._part(n, null, Vector3(1.1, 0.12, 0.8), Vector3(0, 1.04, -1.4), _m.ember, false)
			coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			builder._part(n, fb, Vector3(0.5, 2.6, 0.5), Vector3(0, 2.3, -1.6), _m.darkstone, false)
			var fl := OmniLight3D.new()
			fl.light_color = Color(1.0, 0.5, 0.2)
			fl.light_energy = 1.6
			fl.omni_range = 7.0
			fl.position = Vector3(0, 1.4, -1.0)
			n.add_child(fl)
			builder._part(n, fb, Vector3(0.35, 0.6, 0.35), Vector3(0.4, 0.3, 0.4), _m.darkwood, false)
			builder._part(n, fb, Vector3(0.7, 0.22, 0.3), Vector3(0.4, 0.71, 0.4), _m.iron, false)
			WDress.kp(n, "pirate", "barrel", Vector3(-1.7, 0, 1.2), rr.randf(), 0.6, true)
			WDress.kp(n, "castle", "tree-log", Vector3(1.8, 0, 1.0), 0.2, 2.4)
			WDress.kp(n, "castle", "tree-log", Vector3(1.8, 0.6, 1.0), -0.1, 2.4)
			WDress.kp(n, "pirate", "cannon-ball", Vector3(-1.2, 0, -0.4), 0.0, 0.5)
		"well":
			var ring := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 1.0
			cm.bottom_radius = 1.05
			cm.height = 0.9
			ring.mesh = cm
			ring.material_override = _m.stone
			ring.position = Vector3(0, 0.45, 0)
			n.add_child(ring)
			builder._part(n, fb, Vector3(2.0, 0.9, 2.0), Vector3(0, 0.45, 0), null, false)
			builder._part(n, null, Vector3(1.6, 0.05, 1.6), Vector3(0, 0.8, 0), _m.cold, false)
			for side in [-1.0, 1.0]:
				builder._part(n, fb, Vector3(0.15, 2.2, 0.15), Vector3(side * 0.9, 1.1, 0), _m.darkwood, false)
			builder._part(n, null, Vector3(2.1, 0.14, 0.14), Vector3(0, 2.15, 0), _m.darkwood, false)
			var rf := builder._part(n, null, Vector3(2.4, 0.08, 1.6), Vector3(0, 2.5, 0), _m.thatch, false)
			rf.rotation.z = 0.0
		"stall":
			var cloths := [Color(0.5, 0.18, 0.12), Color(0.55, 0.45, 0.2), Color(0.25, 0.32, 0.36), Color(0.4, 0.38, 0.3)]
			var cm := mat(cloths[rr.randi() % cloths.size()], 1.0, 0.3, 1.0)
			for p in [Vector2(-1.3, -0.8), Vector2(1.3, -0.8), Vector2(-1.3, 0.8), Vector2(1.3, 0.8)]:
				builder._part(n, fb, Vector3(0.12, 2.3, 0.12), Vector3(p.x, 1.15, p.y), _m.darkwood, false)
			var awn := builder._part(n, null, Vector3(3.0, 0.06, 2.1), Vector3(0, 2.35, 0), cm, false)
			awn.rotation.x = -0.12
			builder._part(n, fb, Vector3(2.6, 0.9, 0.9), Vector3(0, 0.45, 0.3), _m.wood, false)
			WDress.wares(n, k, Vector3(0, 0.9, 0.3), rr)
			WDress.kp(n, "town", "stall-stool", Vector3(0.6, 0, -0.5), rr.randf(), 2.4)
		"tower":
			for p in [Vector2(-1.1, -1.1), Vector2(1.1, -1.1), Vector2(-1.1, 1.1), Vector2(1.1, 1.1)]:
				builder._part(n, fb, Vector3(0.24, 6.4, 0.24), Vector3(p.x, 3.2, p.y), _m.darkwood, false)
			builder._part(n, fb, Vector3(2.8, 0.18, 2.8), Vector3(0, 5.2, 0), _m.wood, false)
			for side in [-1.0, 1.0]:
				builder._part(n, fb, Vector3(2.8, 0.8, 0.1), Vector3(0, 5.7, side * 1.35), _m.wood, false)
				builder._part(n, fb, Vector3(0.1, 0.8, 2.8), Vector3(side * 1.35, 5.7, 0), _m.wood, false)
			var tr := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(3.2, 1.2, 3.2)
			tr.mesh = pm
			tr.material_override = _m.thatch
			tr.position = Vector3(0, 7.0, 0)
			n.add_child(tr)
			WDress.kp(n, "castle", "flag-banner-long", Vector3(1.3, 6.1, 1.3), 0.8, 1.6, false, Vector3.ZERO, 400.0)
			var lt := OmniLight3D.new()
			lt.light_color = Color(1.0, 0.65, 0.35)
			lt.light_energy = 1.0
			lt.omni_range = 8.0
			lt.position = Vector3(0, 6.0, 0)
			n.add_child(lt)
	_fade_far(n, 260.0)


func _town_wall(n: Node3D, kind: String, pos: Vector3, yaw: float, tier: int) -> void:
	var wl := builder._make(kind, false, tier)
	wl.position = pos
	wl.rotation.y = yaw
	n.add_child(wl)


func _furnish(n: Node3D, kind: String, pos: Vector3, yaw: float) -> StaticBody3D:
	var f := builder._make(kind, false)
	f.position = pos
	f.rotation.y = yaw
	n.add_child(f)
	return f.get_meta("body")


## The inn's room: tables and chairs before the door, a counter at one end, and beds at the back.
func _inn_inside(k: String, n: Node3D, W: float, D: float) -> void:
	var name: String = INN_NAMES[absi(hash(k)) % INN_NAMES.size()]
	var sign_l := label3d(name, Vector3.ZERO, 0.7, Color(0.95, 0.82, 0.55))
	sign_l.reparent(n, false)
	sign_l.position = Vector3(0, 3.9, D * 0.5 + 0.7)
	sign_l.rotation = Vector3.ZERO
	sign_l.visibility_range_end = 60.0
	var ir := RandomNumberGenerator.new()
	ir.seed = hash(k + "inn")
	for x in [-2.3, 0.8]:
		_furnish(n, "table", Vector3(x, 0, 0.9), 0.0)
		WDress.table_top(n, Vector3(x, 0.76, 0.9), 0.0, ir)
		_furnish(n, "chair", Vector3(x - 0.2, 0, 0.1), PI)
		_furnish(n, "chair", Vector3(x + 0.6, 0, 1.8), 0.0)
	_furnish(n, "stove", Vector3(W * 0.5 - 0.7, 0, 1.6), -PI * 0.5)
	_furnish(n, "rug", Vector3(-0.8, 0.02, -0.6), 0.0)
	# The counter: hot meals and the talk of the road
	var counter := _furnish(n, "table", Vector3(W * 0.5 - 1.2, 0, -0.2), PI * 0.5)
	WDress.table_top(n, Vector3(W * 0.5 - 1.2, 0.76, -0.2), PI * 0.5, ir, 1)
	WDress.kp(n, "food", "barrel", Vector3(W * 0.5 - 0.45, 0, -1.6), 0.0, 1.2, true, Vector3.ZERO, 60.0)
	WDress.kp(n, "food", "barrel", Vector3(W * 0.5 - 0.45, 0, -0.7), 0.4, 1.2, true, Vector3.ZERO, 60.0)
	personal_interactable(counter, "Buy a hot meal (6 salt)", func(): inn_meal())
	var talk := _furnish(n, "table", Vector3(-2.3, 0, 0.9), 0.0)
	personal_interactable(talk, "Listen to the talk", func(): inn_talk(k))
	for x in [-W * 0.5 + 1.0, -W * 0.5 + 3.2]:
		var bed := _furnish(n, "bed", Vector3(x, 0, -D * 0.5 + 1.2), 0.0)
		personal_interactable(bed, "Rent a bed (4 salt)", func(): inn_bed())
		inn_beds.append(n.to_global(Vector3(x, 0, -D * 0.5 + 1.2)) if n.is_inside_tree() else n.position)


## A hot meal from the inn's pot, for salt.
func inn_meal() -> void:
	if inv.count("salt") < 6:
		hud.notify("A hot meal costs 6 salt.")
		return
	var id: String = INN_MEALS[randi() % INN_MEALS.size()]
	if inv.add(id, 1) > 0:
		hud.notify("Your pack is full.")
		return
	inv.take("salt", 6)
	sfx("drink", -6)
	hud.notify("You buy %s. Eat it while it is hot." % String(Items.info(id).name).to_lower())


## What people say over their cups: where a ruin lies that you have not found, marked on your map.
func inn_talk(k: String) -> void:
	var c := WPlaces.spos(k)
	var best = null
	var bd := INF
	for r in ruins:
		if known_ruins.has(r.id) or _rumoured.has(r.id):
			continue
		var d := Vector2(r.pos.x, r.pos.z).distance_to(c)
		if d < bd:
			bd = d
			best = r
	if best == null:
		hud.notify("The talk is of nothing you do not already know.")
		return
	_rumoured[best.id] = true
	known_ruins[best.id] = true
	var dir := WPlaces.dir_word(c, Vector2(best.pos.x, best.pos.z))
	hud.notify("They say %s lies about %d paces to the %s. It is marked on your map." % [best.name, int(bd / 10.0) * 10, dir])
	award("rumour")


## A night in an inn's bed: the snuggest rest in the waste. You do not wake here if you fall.
func inn_bed() -> void:
	if inv.count("salt") < 4:
		hud.notify("A bed costs 4 salt.")
		return
	inv.take("salt", 4)
	ui.ask_rest("inn")


## A soul of the waste, who may be spoken with.
func _person(pid: String, p: Vector3, yaw: float) -> void:
	var pd: Dictionary = WPlaces.PEOPLE[pid]
	var f := figure(p, yaw, pd.robe)
	# The people of the waste are dressed each in their own way; the robed shape only keeps their place
	for c in f.get_children():
		if c is MeshInstance3D:
			c.queue_free()
	var dressed := Figure.new().setup(Figure.townsman(pid.hash(), str(pd.at)))
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
	# The beacon's fire burns white, as the old oil did
	var flame := WFire.make(4.8, true, false, Color(1.0, 0.78, 0.42))
	flame.position = Vector3(0, 11.4, 0)
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
	# A dead beacon is a goal on the horizon: a thin column of red smoke that stands over the waste
	var dark := landmark_column(Color(0.75, 0.22, 0.12, 0.16), 220.0, 0.9)
	dark.position = Vector3(0, 122, 0)
	n.add_child(dark)
	beacon_nodes.append({"node": n, "flame": flame, "light": light, "beam": beam, "area": a, "pos": c, "dark": dark})
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
		if not skills.boon_offer.is_empty():
			ui.open_boons(WPlaces.BEACONS[i].name)
			return
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
		_beacon_payoff(i)
	else:
		b.flame.visible = false
		b.light.light_energy = 0.0
		hud.notify("The flame at %s guttered out. The oil is spent." % WPlaces.BEACONS[i].name)
	_beacon_prompt(i)


## What a kindled beacon gives every pilgrim: a gift from its bowl, a boon to choose, and the way
## to the next dark beacon shown on the map.
const BEACON_GIFT := [["tempered", 1], ["clockwork", 1], ["fittings_fine", 2], ["salt", 40]]

func _beacon_payoff(i: int) -> void:
	if Net.dedicated or _pfail:
		return
	var n := lit.size()
	var gift: Array = []
	for g in BEACON_GIFT:
		gift.append([g[0], int(g[1]) * (1 + n / 3) * (2 if WRules.sworn("vow_tithe") else 1)])
	if i == 8:
		gift.append(["fittings_storied", 1])
	give(gift)
	var rr := RandomNumberGenerator.new()
	rr.seed = hash([i, n, skills.boons.size(), Net.me(), Time.get_ticks_usec()])
	if skills.boon_offer.is_empty():
		skills.boon_offer = skills.roll_boons(rr)
	var next := next_dark_beacon(beacon_nodes[i].pos)
	if next >= 0:
		reveal_place(WPlaces.bpos(next), 60.0)
		hud.notify("From the bowl you can see the next dark beacon: %s. It is on your map." % WPlaces.BEACONS[next].name)
	hud.title_card("%d of 9" % n, "%s burns again" % WPlaces.BEACONS[i].name)
	autosave_soon(1.0)
	if not skills.boon_offer.is_empty():
		get_tree().create_timer(3.5, false).timeout.connect(func():
			if is_instance_valid(ui) and not skills.boon_offer.is_empty():
				ui.open_boons(WPlaces.BEACONS[i].name))


## The unlit beacon nearest a place (never the ninth while others stand dark), or -1.
func next_dark_beacon(from: Vector3) -> int:
	var best := -1
	var bd := INF
	for k in WPlaces.BEACONS.size():
		if k in lit or (k == 8 and lit.size() < 8):
			continue
		var d := Vector2(from.x, from.z).distance_to(WPlaces.bpos(k))
		if d < bd:
			bd = d
			best = k
	return best


## A tall, faint column seen from far across the waste, through the haze: a goal on the horizon.
static func landmark_column(c: Color, height: float, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 2.5
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 10
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.disable_fog = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 6.0
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 25.0
	m.distance_fade_max_distance = 90.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The goals on the horizon follow the world: a dead beacon's smoke until it burns, a lair's while
## its great one waits there.
func _landmarks_tick() -> void:
	for i in beacon_nodes.size():
		var b: Dictionary = beacon_nodes[i]
		if b.has("dark"):
			(b.dark as Node3D).visible = not (i in lit) and not vigils.has(i) and (i != 8 or lit.size() >= 8)
	for l in lairs:
		if l.has("smoke") and is_instance_valid(l.smoke):
			(l.smoke as Node3D).visible = lair_ready(l)
	_embers_tick()


var _embers: CPUParticles3D = null

## Embers drift off the ash toward the goal being followed: a hint in the world, not on the screen.
## They show only now and then, when the goal is far and the pilgrim is on foot and not fighting.
func _embers_tick() -> void:
	if Net.dedicated or not is_instance_valid(player) or not Game.embers_on:
		return
	if _embers == null:
		_embers = CPUParticles3D.new()
		_embers.amount = 10
		_embers.lifetime = 2.6
		_embers.local_coords = false
		_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_embers.emission_sphere_radius = 2.2
		_embers.gravity = Vector3(0, 0.25, 0)
		_embers.initial_velocity_min = 2.0
		_embers.initial_velocity_max = 3.2
		_embers.spread = 9.0
		_embers.scale_amount_min = 0.6
		_embers.scale_amount_max = 1.1
		var q := QuadMesh.new()
		q.size = Vector2(0.05, 0.05)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1.0, 0.62, 0.25, 0.9)
		q.material = m
		_embers.mesh = q
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0))
		fade.add_point(0.2, Color(1, 1, 1, 1))
		fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
		_embers.color_ramp = fade
		_embers.emitting = false
		add_child(_embers)
	var t = null
	if quests and quests.quests.has(quests.tracked) and quests.quests[quests.tracked].state == "active":
		t = quests.target_of(quests.quests[quests.tracked])
	var me: Vector3 = player.global_position
	var far: bool = t is Vector3 and Vector2(t.x - me.x, t.z - me.z).length() > 45.0
	# A short drift every half minute or so, and while standing still and lost
	var calm: bool = player.cur_speed < 0.5 or fmod(clock * 60.0, 30.0) < 4.0
	var on: bool = far and calm and not player.input_locked and (player.weapon == null or player.weapon._quiet > 6.0)
	if on:
		var d := Vector3(t.x - me.x, 0, t.z - me.z).normalized()
		_embers.global_position = me + Vector3(0, 1.1, 0) + d * 1.5
		_embers.direction = d
	_embers.emitting = on


## Testing aid: embers drift toward the tracked goal when it is far, and stop near it.
func debug_embers() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	quests.tracked = "main"
	var q: Dictionary = quests.quests["main"]
	var t = quests.target_of(q)
	player.weapon._quiet = 99.0   # long since the last shot
	player.global_position = t + Vector3(200, 0, 0)
	player.global_position.y = terrain.height_at(player.global_position.x, player.global_position.z) + 1.0
	await get_tree().create_timer(1.2).timeout
	var far_on: bool = _embers != null and _embers.emitting
	var toward: bool = _embers != null and _embers.direction.dot(Vector3(-1, 0, 0)) > 0.95
	player.global_position = t + Vector3(10, 0, 0)
	player.global_position.y = terrain.height_at(player.global_position.x, player.global_position.z) + 1.0
	await get_tree().create_timer(1.2).timeout
	print("EMBERS far=%s toward=%s near_off=%s" % [far_on, toward, not _embers.emitting])
	get_tree().quit()


func debug_dream() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var before := 0
	for v in revealed:
		before += int(v != 0)
	var seen := _dream_reveal(player.global_position)
	var after := 0
	for v in revealed:
		after += int(v != 0)
	var again := _dream_reveal(player.global_position)
	print("DREAM seen=%s grew=%s next_differs=%s" % [seen, after > before, again != seen])
	get_tree().quit()


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
## The great ones' powers: a trophy laid at a shrine once, and then taken up there for a while.
const POWERS := Items.POWERS
const POWER_SECS := 1800.0  ## how long a power lasts once taken up
var power := ""             ## the trophy whose power this pilgrim carries now
var power_left := 0.0
const GREAT_EVERY := 7       ## every seventh night the great raid comes
var great := {}             ## the great raid tonight (host): spawned, and where it falls


func safe_at(p: Vector3) -> bool:
	if hall and hall.inside(p):
		return true   # the night does not come down the Lake Stair: only the hall's own answer
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
		if WBuilder.acts(pc.kind) == "chest" and Vector2(pc.pos.x, pc.pos.z).distance_to(Vector2(fp.x, fp.z)) < BASE_SAFE and containers.has("p%d" % pid):
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
	player.walk_speed = 3.4 * skills.speed_mult() * slow * dev_fast * alchemy.speed_mult()
	player.run_speed = 5.8 * skills.speed_mult() * slow * dev_fast * alchemy.speed_mult()
	if dev:
		dev.tick()
	# Breath comes back slower when weary or starving, and slower still under heavy plate
	player.stamina_mult = (0.6 if rest < 20.0 else 1.0) * (0.7 if food <= 0.0 else 1.0) / maxf(0.8, float(wn.weary))
	player.stamina_mult *= (1.0 + meal_sum("breath")) * (1.3 if rested > 0.0 else 1.0) * skills.breath_mult()
	_meals_tick(delta)
	alchemy.tick(delta)
	_land_tick(delta)
	_afflict_tick(delta)
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
	var meal: Dictionary = info.get("meal", {})
	var as_meal := not meal.is_empty() and meal_room(id) >= 0
	if not meal.is_empty() and not as_meal and food >= 99.0:
		hud.notify("You are too full. Wait until a meal wears thin.")
		return false
	if not as_meal and f <= 0.0 and player.health >= player.max_health - 0.5:
		hud.notify("You are not hurt.")
		return false
	if not as_meal and f > 0.0 and food >= 99.0 and player.health >= player.max_health - 0.5:
		hud.notify("You are not hungry.")
		return false
	if inv.take(id, 1) < 1:
		return false
	if id == "elixir":
		_burn = 0.0
		_slow = 0.0
		hud.notify("Warmth runs through you. The burning and the tar are gone.")
	if as_meal:
		_take_meal(id, meal)
	elif not meal.is_empty():
		hud.notify("No room for another meal. It only fills you.")
	food = minf(100.0, food + f)
	player.health = clampf(player.health + h, 1.0, player.max_health)
	hud.set_health(player.health / player.max_health, true)
	sfx("drink", -6)
	if h < 0.0:
		hud.notify("Raw meat turns your stomach. Cook it first.")
	return true


# ------------------------------------------------------------------ lands that ask for gear

## Each land is harder than the one before, and has a hardship that only gear made from the land
## before it keeps out (Valheim's lands). The Ash Plains are where everyone starts.
const LAND_TIER := {"ash": 1, "dunes": 2, "forest": 2, "salt": 3, "marsh": 3, "basalt": 4}
const TIER_HP := [1.0, 1.35, 1.8, 2.4]       ## a foe's health in a land of each danger
const TIER_HARM := [1.0, 1.25, 1.55, 1.9]    ## and the harm it does
## land: [ward carried against it, the hardship in a few words]
const LAND_WARD := {
	"dunes": ["veil", "The heat: your breath comes back slowly."],
	"forest": ["spore_mask", "The spores eat at your health."],
	"salt": ["goggles", "The glare burns you by day."],
	"marsh": ["tar_boots", "The tar holds your feet."],
	"basalt": ["ember_cloak", "The stone's heat burns you."],
}
## What each land yields besides the common stuff: [node kind, item, chance]
const LAND_STUFF := {
	"dunes": ["scrap", "red_iron", 0.4], "forest": ["tree", "heartwood", 0.35], "salt": ["salt", "salt_crystal", 0.35],
	"marsh": ["herb", "tar", 0.5], "basalt": ["rock", "obsidian", 0.35],
}
var _land_t := 0.0


func land_tier(bn: String) -> int:
	return int(LAND_TIER.get(bn, 1))


const GENTLE := 500.0   ## near where the cast-out wake, every land is gentle: no hardship, the weakest forms


## A great one of the waste (a vault's keeper, the Bell-Wound, the Lamp-Eater) is met by a whole
## fellowship, so it grows as a lord of a land does, not only as a common form.
func crowd_great(e) -> void:
	if e == null or not is_instance_valid(e):
		return
	var m := WCrowd.boss(self) / WCrowd.hp(self)
	e.hp *= m
	e.max_hp *= m


## How dangerous the waste is here: it grows with the distance from where you woke, a ring each
## 600 m, and the hard lands (salt, marsh, basalt) are a step worse once you are past the first ring.
func tier_at(p: Vector3) -> int:
	var d := Vector2(p.x, p.z).distance_to(WPlaces.start)
	if d < GENTLE:
		return 1
	var ring := 1 + int(d / 600.0)
	return clampi(ring + (1 if land_tier(land_at(p)) >= 3 else 0), 1, 4)


func gentle_at(p: Vector3) -> bool:
	if hall and hall.inside(p):
		return true
	return Vector2(p.x, p.z).distance_to(WPlaces.start) < GENTLE


func land_at(p: Vector3) -> String:
	if terrain and terrain.is_water(p.x, p.z, 0.8):
		return "sea"   # no land's hardship out on the water
	return terrain.biome_name(p.x, p.z) if terrain else "ash"


## Whether this pilgrim carries the ward against a land's hardship (or the land has none).
func warded(bn: String) -> bool:
	return not LAND_WARD.has(bn) or bn in WArms.worn(arms).wards


func land_warning(bn: String) -> String:
	if warded(bn):
		return ""
	return "\n%s Wear %s." % [LAND_WARD[bn][1], Items.info(LAND_WARD[bn][0]).name]


## How far the fellowship's arms have come: upgraded guns, fitted parts and experience. The forms
## grow to meet it, so the near lands stay worth fearing once a gun is improved.
func foe_power() -> float:
	var best := 0
	var tiers = Game.warms.get("tier", {}) if Game.warms is Dictionary else {}
	if tiers is Dictionary:
		for g in tiers:
			best = maxi(best, int(tiers[g]))
	var fitted := 0
	if arms and arms.primary != "" and arms.parts.has(arms.primary):
		fitted = (arms.parts[arms.primary] as Array).size()
	var lv: int = skills.level if skills else 1
	return clampf(1.0 + 0.15 * best + 0.04 * mini(fitted, 5) + 0.02 * (lv - 1), 1.0, 2.2)


## A foe is as strong as the land it rises in, and as the arms it will face.
func spawn_at(kind: String, p: Vector3) -> LesserSpeeb:
	var e := super(kind, p)
	if e and Game.wasteland and terrain:
		var m: float = TIER_HP[tier_at(p) - 1] * foe_power() * (1.3 if flags.has("second_vow") else 1.0) * (WCrowd.hp(self) if e.boss == "" else 1.0)
		e.hp *= m
		e.max_hp *= m
	return e


## The hardship of the land underfoot, for one without its ward.
func _land_tick(delta: float) -> void:
	var bn := land_at(player.global_position)
	if warded(bn) or gentle_at(player.global_position) or settlement_at(player.global_position, 4.0) != "" or base_at(player.global_position, 0.0, true) >= 0 or not LAND_WARD.has(bn) or (bn == "salt" and night):
		if ui:
			# The weather may still ask something, out in the open
			var why := weather.hardship(player.global_position) if not gentle_at(player.global_position) and base_at(player.global_position, 0.0) < 0 and settlement_at(player.global_position, 0.0) == "" and not weather.sheltered else ""
			ui.set_hazard(why)
		return
	if ui:
		ui.set_hazard("%s  Wear %s." % [LAND_WARD[bn][1], Items.info(LAND_WARD[bn][0]).name])
	match bn:
		"dunes":
			player.stamina_mult *= 0.5
		"forest", "salt", "basalt":
			if bn == "salt" and night:
				return
			_land_t -= delta
			if _land_t <= 0.0:
				_land_t = 5.0
				var loss := {"forest": 2.0, "salt": 2.5, "basalt": 4.0}[bn] as float
				player.health = maxf(1.0, player.health - loss)
				hud.set_health(player.health / player.max_health, true)
				_regen_wait = maxf(_regen_wait, 4.0)


# ------------------------------------------------------------------ what foes leave on you

var _burn := 0.0
var _slow := 0.0


## Fire on you (it burns until it goes out) or tar on your legs (you are slow while it lasts).
func afflict(what: String, secs: float) -> void:
	match what:
		"burn":
			if alchemy.on("fireskin"):
				return
			if _burn <= 0.0:
				hud.notify("You are burning.")
			_burn = maxf(_burn, secs)
		"slow":
			if _slow <= 0.0:
				hud.notify("Tar clings to your legs.")
			_slow = maxf(_slow, secs)
		"freeze":
			if _freeze <= 0.0:
				hud.notify("The cold locks your legs.")
			_freeze = maxf(_freeze, secs)
		"blind":
			if _blind <= 0.0:
				hud.notify("Ravens in your face!")
			_blind = maxf(_blind, secs)
		"rob":
			# A thief's grip: a quarter of the rounds for the gun in hand, gone with it
			var w = player.weapon
			if w == null or not Items.AMMO.has(w.gun()):
				return
			var id: String = Items.AMMO[w.gun()]
			var n := int(inv.count(id) * 0.25)
			if n <= 0:
				return
			inv.take(id, n)
			_robbed[id] = int(_robbed.get(id, 0)) + n
			hud.notify("It tore %d rounds from you. Slay it to get them back." % n)
		"unrob":
			if _robbed.is_empty():
				return
			for id in _robbed:
				inv.add(id, int(_robbed[id]))
			_robbed = {}
			hud.notify("You take back what the thief stole.")


## A form's blow lands on this pilgrim, from the host or from a foe on another machine.
func _w_afflict(what: String, secs: float) -> void:
	afflict(what, secs)


var _freeze := 0.0
var _blind := 0.0
var _robbed := {}   ## ammunition a thief has taken: id -> rounds
var _blind_rect: ColorRect


func _afflict_tick(delta: float) -> void:
	if _freeze > 0.0:
		_freeze -= delta
		player.walk_speed *= 0.25
		player.run_speed *= 0.25
	if _blind > 0.0 or (_blind_rect and _blind_rect.visible):
		if _blind_rect == null:
			_blind_rect = ColorRect.new()
			_blind_rect.color = Color(0.03, 0.02, 0.04, 0.0)
			_blind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_blind_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			hud.add_child(_blind_rect)
		_blind = maxf(0.0, _blind - delta)
		var a := clampf(_blind / 0.6, 0.0, 0.88)
		_blind_rect.color.a = a
		_blind_rect.visible = a > 0.01
	if _burn > 0.0:
		_burn -= delta
		player.health = maxf(1.0, player.health - 3.0 * delta)
		hud.set_health(player.health / player.max_health, true)
		_regen_wait = maxf(_regen_wait, 2.0)
	if _slow > 0.0:
		_slow -= delta
		player.walk_speed *= 0.6
		player.run_speed *= 0.6


# ------------------------------------------------------------------ meals and comfort

## Up to three meals at once, each adding health, breath or healing for a while (Valheim's food).
## The same meal again only freshens it once it wears thin; a fourth waits until one does.
const MEALS_MAX := 3
const THIN := 0.3            ## a meal this far gone can be eaten again or replaced
var meals := {}              ## item id -> [seconds left, seconds in all]
var rested := 0.0            ## seconds of rest bonus left: more experience, faster breath
var _meal_hp := 0.0


## Which meal slot this food may take: 0 a free one, 1 to freshen or replace a thin one, -1 none.
func meal_room(id: String) -> int:
	if meals.has(id):
		return 1 if float(meals[id][0]) <= float(meals[id][1]) * THIN else -1
	if meals.size() < MEALS_MAX:
		return 0
	for k in meals:
		if float(meals[k][0]) <= float(meals[k][1]) * THIN:
			return 1
	return -1


func _take_meal(id: String, meal: Dictionary) -> void:
	if not meals.has(id) and meals.size() >= MEALS_MAX:
		# The thinnest meal makes way
		var worst := ""
		for k in meals:
			if worst == "" or float(meals[k][0]) < float(meals[worst][0]):
				worst = k
		meals.erase(worst)
	var secs := float(meal.get("mins", 15)) * 60.0
	meals[id] = [secs, secs]
	_meal_stats()
	player.stamina = minf(player.stamina_max, player.stamina + float(meal.get("stam", 0)))
	hud.notify("%s: %s for %d minutes." % [Items.info(id).get("name", id), meal_text(meal), int(meal.get("mins", 15))])


## What a meal gives, in a few plain words.
static func meal_text(meal: Dictionary) -> String:
	var bits := []
	if float(meal.get("hp", 0)) > 0.0:
		bits.append("+%d health" % int(meal.hp))
	if float(meal.get("stam", 0)) > 0.0:
		bits.append("+%d breath" % int(meal.stam))
	if float(meal.get("breath", 0)) > 0.0:
		bits.append("breath back faster")
	if float(meal.get("regen", 0)) > 0.0:
		bits.append("wounds close faster")
	return ", ".join(bits)


func meal_sum(key: String) -> float:
	var t := 0.0
	for k in meals:
		t += float(Items.info(k).get("meal", {}).get(key, 0.0))
	return t


func _meals_tick(delta: float) -> void:
	var gone := []
	for k in meals:
		meals[k][0] = float(meals[k][0]) - delta
		if float(meals[k][0]) <= 0.0:
			gone.append(k)
	for k in gone:
		meals.erase(k)
		hud.notify("Your %s has worn off." % String(Items.info(k).get("name", k)).to_lower())
	if not gone.is_empty():
		_meal_stats()
	var rg := meal_sum("regen")
	if rg > 0.0 and player.health < player.max_health and not downed:
		player.health = minf(player.max_health, player.health + rg * delta)
		hud.set_health(player.health / player.max_health, true)
	if rested > 0.0:
		rested = maxf(0.0, rested - delta)
		if rested <= 0.0:
			hud.notify("You are no longer rested.")
	if is_instance_valid(ui):
		ui.set_boons(meals, rested)


## Health and breath from the meals now eaten.
func _meal_stats() -> void:
	var hp := meal_sum("hp")
	if absf(hp - _meal_hp) > 0.01:
		_meal_hp = hp
		_apply_skills()
	player.stamina_max = player.STAMINA_MAX + meal_sum("stam")
	player.stamina = minf(player.stamina, player.stamina_max)


## How snug the place you sleep is, 1 to 8: a lit fire, a bed, a roof, walls, a light, furniture,
## walls of stone or iron, or a town's inn.
func comfort(at: Vector3) -> int:
	var c := 1
	if settlement_at(at) != "":
		for ib in inn_beds:
			if (ib as Vector3).distance_to(at) < 4.0:
				return 8
		return 5
	var fire := false
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		if pc.kind in ["campfire", "cookpot", "stove"] and pc.pos.distance_to(at) < 10.0 and burning(pid):
			fire = true
	if fire:
		c += 1
	if builder.near_kind(at, "bedroll", 5.0):
		c += 1
	if builder.near_kind(at, "roof", 5.0):
		c += 1
	var walls := 0
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		if pc.kind in ["wall", "window", "doorway", "stonewall", "palisade"] and pc.pos.distance_to(at) < 8.0:
			walls += 1
	if walls >= 3:
		c += 1
	if builder.near_kind(at, "lamp", 10.0) or builder.near_kind(at, "torch", 10.0):
		c += 1
	for k in ["table", "chair", "rug"]:
		if builder.near_kind(at, k, 8.0):
			c += 1
			break
	for pid in pieces:
		if pieces[pid].kind in ["wall", "window", "doorway"] and int(pieces[pid].get("tier", 0)) > 0 and pieces[pid].pos.distance_to(at) < 8.0:
			c += 1
			break
	return mini(c, 8)


## Waking from a sleep: the snugger the place, the longer you are rested.
func _wake_rested() -> void:
	var c := comfort(player.global_position)
	var mins := 5 + 5 * c
	rested = mins * 60.0
	hud.notify("Rested (comfort %d of 8): more experience and breath for %d minutes." % [c, mins])


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
		at.y = terrain.height_at(at.x, at.z)
		if at.y < WIsles.SEA_Y + 0.6:
			continue   # not in the sea; the isles have their own herds
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


## For the list of fellowships: how far this world has come.
func lobby_detail() -> String:
	return "Day %d  ·  %d of 9 fires lit" % [day, lit.size()]


# ------------------------------------------------------------------ beds and their owners

## The name a bed is kept for: the pilgrim's own name, the same from one night to the next.
func bed_name(peer := 0) -> String:
	if not Net.online:
		return Net.my_name()
	return Net.name_of(peer if peer != 0 else Net.me())


## The bed or bedroll at a place, or -1.
func bed_at(p) -> int:
	if not (p is Vector3):
		return -1
	for pid in pieces:
		if WBuilder.acts(pieces[pid].kind) == "bedroll" and (pieces[pid].pos as Vector3).distance_to(p) < 1.0:
			return pid
	return -1


func bed_owner(pid: int) -> String:
	return str(pieces.get(pid, {}).get("owner", ""))


## A bed this pilgrim may wake in: no one's, or their own.
func bed_mine_or_free(pid: int) -> bool:
	var o := bed_owner(pid)
	return o == "" or o == bed_name()


## Asked by a pilgrim: a bed is given to someone (by name), or freed (""). Only one whose bed it is,
## anyone while it is no one's, or the host, may give it.
func _rq_bed_owner(pid: int, to: String, by: int) -> void:
	if not Net.authority() or not pieces.has(pid) or WBuilder.acts(pieces[pid].kind) != "bedroll":
		return
	var o := bed_owner(pid)
	if o != "" and o != bed_name(by) and by != 1 and Net.online:
		return
	shared("_w_bed_owner", [pid, to.strip_edges().left(20), false])


func _w_bed_owner(pid: int, to: String, quiet := false) -> void:
	if not pieces.has(pid):
		return
	var was := bed_owner(pid)
	pieces[pid].owner = to
	_bed_label(pid)
	if quiet:
		return
	var p: Vector3 = pieces[pid].pos
	if to != "" and to == bed_name():
		bedroll = p
		hud.notify("This bed is yours now. You will wake here.")
	elif was == bed_name() and to != was:
		if bedroll is Vector3 and (bedroll as Vector3).distance_to(p) < 1.0:
			bedroll = null
		hud.notify("Your bed is %s now." % ("no one's" if to == "" else to + "'s"))
	if is_instance_valid(ui):
		ui.bed_changed(pid)
	autosave_soon(5.0)


## Whose bed it is, in the colour of the one who keeps it, over it.
func _bed_label(pid: int) -> void:
	var pc: Dictionary = pieces[pid]
	if not is_instance_valid(pc.get("node")):
		return
	var lab: Label3D = pc.node.get_meta("bed_label") if pc.node.has_meta("bed_label") else null
	if lab == null:
		lab = Label3D.new()
		lab.font_size = 30
		lab.pixel_size = 0.005
		lab.position = Vector3(0, 1.1, 0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.outline_size = 6
		lab.visibility_range_end = 10.0
		pc.node.add_child(lab)
		pc.node.set_meta("bed_label", lab)
	var o := str(pc.get("owner", ""))
	lab.text = "" if o == "" else "%s's bed" % o
	lab.modulate = Color(0.95, 0.88, 0.7)
	for id in Net.players:
		if Net.name_of(id) == o:
			lab.modulate = Net.color_of(id).lightened(0.3)


# ------------------------------------------------------------------ waystones

func _rq_portal_name(pid: int, name: String) -> void:
	if Net.authority() and pieces.has(pid) and WBuilder.acts(pieces[pid].kind) in ["portal", "chest"]:
		shared("_w_portal_name", [pid, name.strip_edges().left(24)])


func _w_portal_name(pid: int, name: String) -> void:
	if not pieces.has(pid) or not WBuilder.acts(pieces[pid].kind) in ["portal", "chest"]:
		return
	pieces[pid].name = name
	if WBuilder.acts(pieces[pid].kind) == "chest":
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
	# In a great fellowship one or two may be far off on their own: three in four lying down is enough
	var enough := need.size() if need.size() <= 4 else int(ceil(need.size() * 0.75))
	shared("_w_sleep_count", [have, enough])
	if have >= enough and need.size() > 0 and night:
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
		clock = weather.dawn() - 0.02
	rest = 100.0
	food = maxf(0.0, food - 15.0)
	player.health = player.max_health
	_wake_rested()
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
	_wake_rested()


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
	var n := WCrowd.scale(self, 7 + mini(nights, 8))
	var roster: Array = forms_at(c)
	for k in n:
		get_tree().create_timer(randf_range(2.0, 20.0), false).timeout.connect(func():
			if is_instance_valid(self) and night:
				var e = _spawn_near(roster[randi() % roster.size()], c, BASE_SAFE - 12.0, BASE_SAFE + 6.0, true)
				if e:
					e.set_meta("raid", true))


## Whether this pilgrim carries the power with this key (see POWERS) now.
func power_is(k: String) -> bool:
	return power != "" and power_left > 0.0 and str(POWERS.get(power, {}).get("key", "")) == k


## Lays a trophy on a shrine: from now on the fellowship may take its power at any shrine.
func lay_trophy(t: String) -> void:
	if inv.take(t, 1) < 1:
		return
	shared("_w_flag", ["shrine_" + t])
	sfx("choir", -6)
	hud.notify("You lay %s on the shrine. Its power is yours to take up now." % Items.iname(t))


func _w_flag(f: String) -> void:
	flags[f] = true
	autosave_soon(3.0)


func take_power(t: String) -> void:
	if not flags.has("shrine_" + t):
		return
	power = t
	power_left = POWER_SECS
	_apply_skills()
	sfx("choir", -8)
	hud.title_card("", POWERS[t].name)
	hud.notify(POWERS[t].text)


func _power_tick(delta: float) -> void:
	if power_left <= 0.0:
		return
	power_left -= delta
	if power_left <= 0.0:
		power_left = 0.0
		hud.notify("The %s leaves you." % POWERS.get(power, {"name": "power"}).name)
		power = ""
		_apply_skills()


## Whether the night with this number (the first night is 1) brings the great raid.
static func great_night(n: int) -> bool:
	return n > 0 and n % GREAT_EVERY == 0


## How many nights until the great raid: 0 is tonight.
func nights_to_great() -> int:
	return (GREAT_EVERY - (nights + 1) % GREAT_EVERY) % GREAT_EVERY


## Said at dawn, and when a pilgrim wakes: the great raid is coming, and when.
func _great_warning() -> void:
	if flags.get("ending", "") in ["writer", "unlit"]:
		return   # the Mouth is closed, or has what it wanted: no great raid comes again
	match nights_to_great():
		0:
			hud.alert_banner("The seventh night", "The great raid comes at dusk. Hold your camp, or find a wall.")
		1:
			hud.notify("The great raid comes tomorrow night. Mend your walls and lay in shells.")
		2:
			hud.notify("Two nights to the great raid. The forms are gathering.")


## The seventh night: three waves fall on every camp a pilgrim is keeping, or on the pilgrims themselves.
func _great_raid() -> void:
	var spots: Array = []
	for t in targets():
		var at: Vector3 = t.global_position
		var best := -1
		var bd := 150.0
		for pid in pieces:
			var pc: Dictionary = pieces[pid]
			if pc.kind == "campfire" and pc.pos.distance_to(at) < bd:
				bd = pc.pos.distance_to(at)
				best = pid
		var c: Vector3 = pieces[best].pos if best >= 0 else at
		var dup := false
		for o in spots:
			if o.distance_to(c) < 60.0:
				dup = true
		if not dup:
			spots.append(c)
	if spots.is_empty():
		return
	great = {"spawned": 0, "spots": spots}
	for c in spots:
		shared("_w_great", [c])
	var per := WCrowd.scale(self, 8 + mini(nights / 2, 8))
	for wave in 3:
		get_tree().create_timer(wave * 100.0 + 1.0, false).timeout.connect(func():
			if not is_instance_valid(self) or not night:
				return
			for c in spots:
				var roster: Array = forms_at(c)
				for k in per + wave * 2:
					get_tree().create_timer(randf_range(0.0, 25.0), false).timeout.connect(func():
						if is_instance_valid(self) and night:
							var kind: String = "elite" if randf() < 0.06 + wave * 0.04 else roster[randi() % roster.size()]
							var e = _spawn_near(kind, c, 38.0, 55.0, true)
							if e:
								e.set_meta("raid", true)
								e.set_meta("great", true)
								great.spawned = int(great.get("spawned", 0)) + 1))


func _w_great(at: Vector3) -> void:
	sfx("bell", 0)
	for k in 3:
		get_tree().create_timer(0.8 * (k + 1), false).timeout.connect(func(): sfx("bell", -3, null, 0.75))
	var d := int(player.global_position.distance_to(at))
	hud.alert_banner("The great raid", ("They are coming for your camp, %d m away." % d) if d > 40 else "Three waves. Hold until dawn.")


## Dawn after the seventh night: if the raid was beaten back, the fellowship shares what it carried.
func _great_dawn() -> void:
	if great.is_empty():
		return
	var spawned := int(great.get("spawned", 0))
	var alive := 0
	for e in enemies:
		if is_instance_valid(e) and e.is_alive() and e.has_meta("great"):
			alive += 1
	great = {}
	if spawned < 4 or alive > spawned / 2:
		return
	var r := RandomNumberGenerator.new()
	r.randomize()
	var spoils: Array = Items.roll("vault", 3, r)
	spoils.append(["salt", 40 + nights * 4])
	if r.randf() < 0.5:
		spoils.append(["fittings_rare", 1])
	shared("_w_great_spoils", [spoils])


func _w_great_spoils(spoils: Array) -> void:
	hud.title_card("", "The raid is broken")
	hud.notify("The forms leave what they carried. The fellowship shares it.")
	give(spoils)
	award("beacon", 0.6)


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
		if _vigil_t <= 0.0 and alive_count() < WCrowd.scale(self, 9):
			_vigil_t = 7.0 if i < 8 else 5.0
			var roster := ["rusher", "rusher", "spitter", "swarm", "swarm", "spider"]
			for k in WCrowd.scale(self, 3 + int(nights * 0.3)):
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
	var rd := RandomNumberGenerator.new()
	rd.seed = hash(r.id) + 5
	WDress.ruin(self, r.kind, n, rd, land_at(c))
	# What may be searched
	var kind: Dictionary = WPlaces.RUIN_KINDS[r.kind]
	for k in int(kind.crates):
		var ca := rr.randf() * TAU
		var off := Vector3(cos(ca), 0, sin(ca)) * rr.randf_range(4.2, 5.8)
		if r.kind == "vault":
			off = Vector3((k - 1) * 2.0, 0, 3.5)
		var p := n.to_global(off)
		p.y = terrain.height_at(p.x, p.z)
		_crate("%s_%d" % [r.id, k], p, kind.loot, rr.randf() * TAU, r.kind == "vault" and k == 1)


## The scanned shapes of the land (CC0, Poly Haven), under assets/models/nature/<name>/.
var _scans := {}


var _cut_wood: StandardMaterial3D
var _cut_notch: StandardMaterial3D

func _cut_wood_mat() -> StandardMaterial3D:
	if _cut_wood == null:
		_cut_wood = StandardMaterial3D.new()
		_cut_wood.albedo_color = Color(0.85, 0.5, 0.22, 0.32)
		_cut_wood.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cut_wood.roughness = 0.9
	return _cut_wood


var _cut_rag: StandardMaterial3D

func _cut_rag_mat() -> StandardMaterial3D:
	if _cut_rag == null:
		_cut_rag = StandardMaterial3D.new()
		_cut_rag.albedo_color = Color(0.72, 0.16, 0.1)
		_cut_rag.roughness = 1.0
	return _cut_rag


func _cut_notch_mat() -> StandardMaterial3D:
	if _cut_notch == null:
		_cut_notch = StandardMaterial3D.new()
		_cut_notch.albedo_color = Color(0.93, 0.8, 0.58)
		_cut_notch.roughness = 0.8
	return _cut_notch


func _add_scan(parent: Node3D, key: String, size: float, at := Vector3.ZERO, turn := 0.0, reach := 420.0) -> Node3D:
	if not _scans.has(key):
		_scans[key] = load("res://assets/models/nature/%s/%s.gltf" % [key, key])
	var inst: Node3D = (_scans[key] as PackedScene).instantiate()
	inst.scale = Vector3.ONE * size
	inst.rotation.y = turn
	parent.add_child(inst)
	inst.position = at
	for g in inst.find_children("*", "GeometryInstance3D", true, false):
		g.visibility_range_end = reach
		g.visibility_range_end_margin = 20.0
	return inst


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
	WDress.crate(n, sealed)
	var lid := box(Vector3.ZERO, Vector3(0.95, 0.06, 1.0) if not sealed else Vector3(0.7, 0.05, 0.7), _m.darkwood if not sealed else _m.rust, false)
	_add(n, lid, Vector3(0, 0.63 if not sealed else 0.74, 0))
	crates[id] = {"pos": p, "table": table, "lid": lid, "body": body, "sealed": sealed, "day": -99}
	var prompt := "Force the iron chest (Pry Bar)" if sealed else "Search"
	personal_interactable(body, prompt, func(): _search(id), 0.6)


## What a quest seeks, set on its crate so it is seen from a way off: the thing's own model (or a
## satchel), turning slowly in a pale light. Taken away when the quest moves on.
func crate_mark(id: String, item: String) -> void:
	if not crates.has(id) or crates[id].has("mark"):
		return
	var c: Dictionary = crates[id]
	var holder := Node3D.new()
	add_child(holder)
	holder.position = c.pos + Vector3(0, 1.05, 0)
	var m: Array = Items.MODELS.get(item, ["food", "bag"])
	var piece := WIsleLife.make(m[0], m[1])
	holder.add_child(piece)
	var bb := WIsleLife.bounds(m[0] + "/" + m[1], piece)
	var s := 0.55 / maxf(0.05, maxf(bb.size.x, maxf(bb.size.y, bb.size.z)))
	piece.scale = Vector3.ONE * s
	piece.position = -bb.get_center() * s
	if m.size() > 2 and m[2]:
		var tint := StandardMaterial3D.new()
		tint.albedo_color = Items.info(item).color
		for mi in piece.find_children("*", "MeshInstance3D", true, false) + ([piece] if piece is MeshInstance3D else []):
			(mi as GeometryInstance3D).material_override = tint
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.9, 0.65)
	l.light_energy = 1.2
	l.omni_range = 3.5
	holder.add_child(l)
	var tw := holder.create_tween().set_loops()
	tw.tween_property(holder, "rotation:y", TAU, 6.0).from(0.0)
	c["mark"] = holder


func crate_unmark(id: String) -> void:
	if crates.has(id) and crates[id].has("mark"):
		if is_instance_valid(crates[id].mark):
			crates[id].mark.queue_free()
		crates[id].erase("mark")


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
			var book := _book_for(id, rr)
			if book != "":
				bag.add(book, 1)
				flags["found_" + book] = true
			# A spirit-cat relic, once, in a shrine's offerings or a sealed vault
			# A leaf of Brelm's journal, now and then, in the waste's ruins
			var leaf := endings.next_leaf()
			if leaf != "" and not id.begins_with("isle_") and not id.begins_with("kraken") and rr.randf() < 0.18:
				bag.add(leaf, 1)
				shared("_w_flag", ["found_" + leaf])
			var relic: String = {"shrine": "spirit_ember", "vault": "spirit_ash"}.get(c.table, "")
			if relic != "" and not flags.has("found_" + relic) and rr.randf() < 0.35:
				bag.add(relic, 1)
				shared("_w_flag", ["found_" + relic])
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


## A lost book in a searched place, if one is to be found there: each isle's heart keeps its own,
## and now and then a ruin of the waste turns up the next of the waste's books.
func _book_for(crate_id: String, rr: RandomNumberGenerator) -> String:
	# The Tenth Page was torn up and carried off by those who fled: its leaves lie in sealed chests
	if crates.has(crate_id) and crates[crate_id].sealed:
		for k in 6:
			var pg := "page_%d" % (k + 1)
			if not flags.has("found_" + pg) and not flags.has(pg):
				return pg
	if crate_id.begins_with("isle_"):
		var bits := crate_id.split("_")
		var bk := str(Items.ISLE_BOOKS.get(bits[1], ""))
		if bk != "" and bits[bits.size() - 1] == "0" and not flags.has("found_" + bk):
			return bk
		return ""
	if rr.randf() > 0.15:
		return ""
	for bk in Items.LAND_BOOKS:
		if not flags.has("found_" + bk) and not flags.has(bk):
			return bk
	return ""


## Reading a lost book teaches the whole fellowship what is in it.
func read_book(id: String) -> bool:
	if flags.has(id):
		hud.notify("The fellowship knows this one already. It may be sold.")
		return false
	if inv.take(id, 1) < 1:
		return false
	shared("_w_book", [id, Net.me()])
	return true


func _w_book(id: String, by: int) -> void:
	flags[id] = true
	flags["found_" + id] = true
	var info: Dictionary = Items.info(id)
	hud.title_card(info.name, "A leaf of the Tenth Page" if id.begins_with("page_") else ("Brelm's journal, %d of %d" % [endings.leaves_read(), WEndings.LEAVES] if id.begins_with("jpage_") else "A lost book"))
	var who := "You read" if by == Net.me() else "%s reads" % Net.name_of(by)
	hud.notify("%s %s.\n%s" % [who, info.name, info.text])
	sfx("bell", -12, null, 1.2)
	if by == Net.me():
		award("ruin", 2.0)
	if ready_world:
		autosave_soon(3.0)


## The page at the head of the table: the host settles what is done with it, once for the world.
func _rq_dread(at: Vector3, tier: int) -> void:
	dread.host_spawn(at, tier)


func _rq_ending(by: int, kind: String) -> void:
	if not Net.authority() or flags.has("ending") or hall == null:
		return
	var q: Dictionary = quests.quests.get("story_ferryway", {})
	if q.is_empty() or q.state != "active" or quests.step_of(q).get("t", "") != "page":
		return
	if kind == "writer" and hall.pages_read() < 6:
		return
	if kind == "unlit" and not flags.has("unlit_pact"):
		return
	if kind == "pilgrim" and not endings.can_pilgrim():
		return
	if not kind in ["writer", "unlit", "pilgrim"]:
		kind = "keeper"
	shared("_w_ending", [kind, by])
	quests.advance(q.id, int(q.stage))


const ENDINGS := {
	"keeper": ["The Keeper", "You leave the page white. The pen stays where it lay.\n\nUp in the waste the nine fires burn. The Mouth is held for as long as someone keeps them.\n\nThe waste is not saved. It is kept. And now you keep it."],
	"unlit": ["The Unlit", "You leave the page. Behind the table there is a stair, and Ruth's people are waiting on it with their lamps put out.\n\nYou go down into the Mouth, and you are not seen again.\n\nUp in the waste the forms stop coming at night. The fires burn on. No one can quite remember your name."],
	"pilgrim": ["The Pilgrim", "A thin man stands at the end of the table. He has no face you can keep hold of. He holds out a book, worn soft, its last page blank.\n\n\"He walked it once,\" he says. \"Now you.\"\n\nYou take Brelm's journal, and the vow with it. The road begins again: the same waste, harder, and you are its hermit now. This is the Second Vow."],
	"writer": ["The Writer", "You take up the pen, and write what the five could not: that you were seen, and it was enough.\n\nThe page stays written. The Mouth closes, and does not open again. The nights grow quiet, and no great raid comes.\n\nBut the stars are gone. The waste is safe, and very empty, as if no one is looking any more."],
}


func _w_ending(kind: String, by: int) -> void:
	flags["ending"] = kind
	if kind == "pilgrim":
		flags["second_vow"] = true
	sfx("choir", -4)
	var e: Array = ENDINGS.get(kind, ENDINGS.keeper)
	hud.title_card(e[0], "The end of the road")
	if ui:
		ui.open_ending(e[0], e[1], "" if by == Net.me() else "%s stood at the page." % Net.name_of(by))
	if ready_world:
		autosave_soon(3.0)


func _w_crate_day(id: String, d: int) -> void:
	if crates.has(id):
		crates[id].day = d
		crates[id].lid.rotation = Vector3(0.0, 0.5, 1.3)
		crates[id].lid.position = Vector3(0.75, 0.35, 0.0)


func _w_cont(id: String, data: Array) -> void:
	containers[id] = data
	if _owns_world:
		autosave_soon(1.5)   # what a chest holds is kept with the world: write it soon
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
		var c := WRules.clean(r)
		for row in WRules.ALL:
			if WRules.is_vow(row[0]):
				c[row[0]] = int(rules.get(row[0], 0))   # a vow is kept for the life of the world
		shared("_w_rules", [c])


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
	char_save_soon()


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
	"ammo": {"prompt": "Gather spilled rounds", "tool": "", "charges": 1},
}
const AMMO_PILE_KINDS := ["shells", "rounds", "rifle"]


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


## Spilled rounds, after everything else (so nothing before them moves): one by most ruins, a few near the first camp.
func _scatter_ammo() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 9393
	var spots: Array = []
	for ru in ruins:
		if ru.has("isle") or r.randf() < 0.3:
			continue
		var rp: Vector3 = ru.pos
		var a := r.randf() * TAU
		spots.append(Vector2(rp.x, rp.z) + Vector2(cos(a), sin(a)) * r.randf_range(7.0, 15.0))
	var start := WPlaces.spos("cinderwick")
	for i in 6:
		var a := r.randf() * TAU
		spots.append(start + Vector2(cos(a), sin(a)) * r.randf_range(35.0, 80.0))
	for p2 in spots:
		var p := gpos(p2)
		if terrain.normal_at(p.x, p.z).y < 0.8 or p.y < -0.5:
			continue
		_make_node(nodes.size(), "ammo", p, r)


## What grows and lies on the isles, by their own dice, after everything on the mainland.
func _scatter_isle_nodes() -> void:
	for il in terrain.isles:
		var th: Dictionary = WIsles.THEMES[il.key]
		var r := RandomNumberGenerator.new()
		r.seed = world_seed + 6060 + hash(il.key)
		var heart: Vector2 = terrain.isle_heart(il)
		var made := 0
		for tries in 600:
			if made >= 70:
				break
			var a := r.randf() * TAU
			var p2: Vector2 = il.c + Vector2(cos(a), sin(a)) * sqrt(r.randf()) * float(il.r) * 0.85
			if p2.distance_to(heart) < 30.0:
				continue
			var p := gpos(p2)
			if p.y < WIsles.SEA_Y + 0.6 or terrain.normal_at(p.x, p.z).y < 0.8:
				continue
			var t: Array = th.nodes
			var total := 0
			for row in t:
				total += int(row[1])
			var roll := r.randi_range(1, total)
			var kind := ""
			for row in t:
				roll -= int(row[1])
				if roll <= 0:
					kind = row[0]
					break
			_make_node(nodes.size(), kind, p, r)
			made += 1


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
	"ash": ["rusher", "rusher", "spitter", "spider", "swarm", "idol", "bloater", "howler", "hollow", "hollow", "vigil", "deacon", "cinder_hound", "bile_elder", "dirge_howler"],
	"dunes": ["spitter", "spitter", "rusher", "swarm", "spider", "lurker", "lurker", "saltbone", "saltrifle", "wisp", "rust_stalker", "rust_stalker", "sand_maw"],
	"salt": ["rusher", "spitter", "swarm", "swarm", "rusher", "howler", "bloater", "saltbone", "saltbone", "vigil", "saltrifle", "saltrifle", "rime_bones", "rime_bones", "iron_idol"],
	"forest": ["rusher", "rusher", "spider", "spider", "idol", "brute", "howler", "hollow", "hollow", "deacon", "colossus", "mourner", "mourner", "dirge_howler"],
	"basalt": ["idol", "idol", "rusher", "spitter", "spider", "brute", "bloater", "saltbone", "vigil", "wisp", "wisp", "knight", "glass_crawler", "pyre_sack", "cinder_hauler", "cinder_hound"],
	"marsh": ["spider", "spider", "swarm", "swarm", "swarm", "rusher", "bloater", "lurker", "hollow", "drowned", "drowned", "colossus", "bog_crawler", "bog_crawler", "tar_giant"],
}


## What rises at a place: an isle's own foes, or its land's.
## Near where the cast-out wake only the weakest come, wherever the land would send worse.
const GENTLE_FORMS := ["rusher", "rusher", "spitter", "swarm", "spider", "howler"]




func forms_at(p: Vector3) -> Array:
	if gentle_at(p):
		return GENTLE_FORMS
	var il := terrain.isle_at(p.x, p.z, 1.3)
	var all: Array = WIsles.THEMES[il.key].forms if not il.is_empty() else BIOME_FORMS[terrain.biome_name(p.x, p.z)]
	var t := tier_at(p)
	var out: Array = all.filter(func(k): return int(LesserSpeeb.FORM_TIER.get(k, 1)) <= t)
	return out if not out.is_empty() else GENTLE_FORMS


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
			# A dead quiver trunk, scanned (CC0, Poly Haven), stood up as a dead tree of the waste
			var h := r.randf_range(4.0, 7.5)
			var tr := _add_scan(n, "dead_quiver_trunk", h / 2.0, Vector3(0, -0.15, 0), r.randf() * TAU)
			tr.rotation.x = r.randf_range(-0.08, 0.08)
			if r.randf() < 0.5:
				_add_scan(n, "dead_quiver_branch_01", r.randf_range(2.0, 3.0), Vector3(r.randf_range(-1.0, 1.0), 0, r.randf_range(-1.0, 1.0)), r.randf() * TAU)
			# Wood you can cut stands out from the dead trees you cannot: warm, sound wood, with a
			# pale axe-notch at the base and a band of rag tied round it by whoever marked it
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = _cut_wood_mat()
			_add(n, box(Vector3.ZERO, Vector3(0.42, 0.28, 0.2), _cut_notch_mat(), false), Vector3(0, 0.55, 0.22)).rotation.y = tr.rotation.y
			_add(n, cyl(Vector3.ZERO, 0.4, 0.14, _cut_rag_mat(), false, -1.0, 10), Vector3(0, 1.5, 0))
			var cap := CapsuleShape3D.new()
			cap.radius = 0.35
			cap.height = h
			cs.shape = cap
			cs.position.y = h * 0.5
		"rock":
			# A scanned stone (CC0, Poly Haven): a boulder, or a smaller rock grown to size
			var s := r.randf_range(1.0, 1.8)
			match r.randi_range(0, 2):
				0:
					_add_scan(n, "namaqualand_boulder_03", s * 0.62, Vector3(0, -0.12, 0), r.randf() * TAU)
				1:
					_add_scan(n, "rock_07", s * 7.5, Vector3(0, -0.1, 0), r.randf() * TAU)
				_:
					_add_scan(n, "moon_rock_02", s * 8.0, Vector3(0, -0.15, 0), r.randf() * TAU)
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
		"ammo":
			# Rounds spilled from a split box (the ammo set, CC-BY, Rotten Design)
			var item: String = AMMO_PILE_KINDS[id % AMMO_PILE_KINDS.size()]
			var heap := AmmoLook.pile(item, r, r.randi_range(16, 28))
			heap.set_meta("keep_apart", true)
			n.add_child(heap)
			var lid := box(Vector3.ZERO, Vector3(0.42, 0.04, 0.26), _m.darkwood, false)
			_add(n, lid, Vector3(0.35, 0.03, -0.2))
			lid.rotation = Vector3(0.12, r.randf() * TAU, 0.05)
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.9, 0.3, 0.9)
			cs.shape = bs
			cs.position.y = 0.15
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
	if player.mount:
		hud.notify("Get down from your cat to gather.")
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
		"ammo":
			var item: String = AMMO_PILE_KINDS[id % AMMO_PILE_KINDS.size()]
			out.append([item, rr.randi_range(8, 16) * (2 if item == "rifle" else 1)])
		"bone":
			out.append(["bone", rr.randi_range(2, 4)])
			if rr.randf() < 0.2:
				out.append(["cloth", 1])
	var np: Vector3 = nd.pos if nd.pos is Vector3 else Vector3(nd.pos.x, 0, nd.pos.y)
	var ls: Array = LAND_STUFF.get(land_at(np), [])
	if not ls.is_empty() and ls[0] == nd.kind and rr.randf() < float(ls[2]):
		out.append([ls[1], rr.randi_range(1, 2)])
	shared("_w_node", [id, nd.charges - 1, day + 2])
	Net.call_peer(by, "_w_gathered", [id, out])


## A pilgrim's own hands, with the right tool, take twice as much.
func _w_gathered(id: int, out: Array) -> void:
	var nk: Dictionary = NODE_KINDS[nodes[id].kind]
	if nk.tool != "" and inv.count(nk.tool) > 0:
		for it in out:
			if it[0] in ["wood", "stone", "salt"]:
				it[1] = int(it[1]) * 2
	var gm: float = skills.gather_mult() * WRules.yield_mult() * float(WArms.worn(arms).gather)
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
	nd.body.collision_layer = (1 | 16) if charges > 0 and not nd.kind in ["herb", "bone", "ammo"] else (16 if charges > 0 else 0)
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
	_sea_tick(delta)
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
	if _char_soon >= 0.0:
		_char_soon -= delta
		if _char_soon < 0.0:
			save_char_now()


var _char_soon := -1.0

var _safe_spots: Array = []   ## where this pilgrim last stood on open ground, every few seconds, newest last
var _footing_t := 0.0
var _under_t := 0.0

## Fallen through the ground (or out of the world): set back on top of it. Also keeps a short trail
## of good footing, for "I'm stuck" in the pause menu.
func _stuck_tick(delta: float) -> void:
	if not ready_world or not is_instance_valid(player) or not player.is_inside_tree() or terrain == null:
		return
	var p: Vector3 = player.global_position
	var ground: float = terrain.height_at(p.x, p.z)
	var below: bool = (p.y < ground - 3.0 and not (hall and hall.inside(p))) or p.y < -400.0
	if below and player.vessel == null and player.mount == null:
		_under_t += delta
		if _under_t > 1.5:
			_under_t = 0.0
			unstick(true)
		return
	_under_t = 0.0
	_footing_t -= delta
	if _footing_t <= 0.0 and player.is_on_floor() and absf(p.y - ground) < 2.5 and not terrain.is_water(p.x, p.z, 0.3) and not (hall and hall.inside(p)):
		_footing_t = 3.0
		_safe_spots.append(p)
		if _safe_spots.size() > 6:
			_safe_spots.pop_front()


## Where this pilgrim may honestly be kept: never a spot under the ground.
func safe_keep_pos() -> Vector3:
	var p: Vector3 = player.global_position if player.is_inside_tree() else player.position
	if terrain and p.y < terrain.height_at(p.x, p.z) - 3.0 and not (hall and hall.inside(p)) and not _safe_spots.is_empty():
		return _safe_spots[-1]
	return p


## Sets the pilgrim back on good ground: straight up onto the surface when under it, or else back to
## where they last stood freely (a few seconds ago), or the nearest town if there is no such place.
func unstick(fell_through := false) -> void:
	var p: Vector3 = player.global_position
	var to := Vector3.INF
	if fell_through and p.y > -400.0:
		to = Vector3(p.x, terrain.height_at(p.x, p.z) + 1.5, p.z)
	else:
		for i in range(_safe_spots.size() - 1, -1, -1):
			if (_safe_spots[i] as Vector3).distance_to(p) > 4.0:
				to = _safe_spots[i] + Vector3(0, 1.0, 0)
				break
	if to == Vector3.INF:
		var best := "cinderwick"
		var bd := INF
		for k in WPlaces.SETTLEMENTS:
			var d := Vector2(p.x, p.z).distance_to(WPlaces.spos(k))
			if d < bd:
				bd = d
				best = k
		var c := gpos(WPlaces.spos(best))
		to = c + Vector3(6, 1.5, 6)
	player.place(to, player.yaw)
	hud.notify("You climb back onto firm ground.")

## Things moved between this pilgrim's pack and the world (a chest, a gift): the pack is written at
## once, so a crash on either side cannot lose them or leave a copy behind.
func char_save_soon() -> void:
	if _char_soon < 0.0:
		_char_soon = 0.3


func save_char_now() -> void:
	_char_soon = -1.0
	if world_uid == "" or not is_instance_valid(player) or Net.dedicated or _pfail:
		return
	DirAccess.make_dir_recursive_absolute("user://wasteland")
	Game.write_safe(_char_path(), var_to_str(char_data()))


var _drown_t := 0.0
var _foe_sea_t := 1.0



var _serpent_t := 10.0


## Far out on open water, something may come up after a boat (or a swimmer).
func _serpent_watch() -> void:
	if enemies.any(func(e): return is_instance_valid(e) and e.is_alive() and e.kind == "serpent"):
		return
	for t in targets():
		var p: Vector3 = t.global_position
		if not terrain.is_water(p.x, p.z, 4.0) or sea.open_water(p, 240.0) < 160.0:
			continue
		if randf() > 0.15:
			continue
		var a := randf() * TAU
		var at := p + Vector3(cos(a), 0, sin(a)) * randf_range(28.0, 40.0)
		at.y = WIsles.SEA_Y + 0.3
		if not terrain.is_water(at.x, at.z, 3.0):
			continue
		var e := spawn_at("serpent", at)
		if e:
			e.set_meta("raid", true)
			shared("_w_note", ["Something moves under the water."])
			sfx("horror_deep", -4, at, 0.7)
		return


## The sea: where its surface lies under you, a swimmer who has spent their breath, and foes
## that follow too far into deep water.
func _sea_tick(delta: float) -> void:
	var p := player.global_position
	player.water_y = sea.surface(p.x, p.z) if terrain.is_water(p.x, p.z, 1.0) else -INF
	if player.swimming and player.stamina <= 0.0 and not downed and not Net.dedicated and not power_is("tar"):
		_drown_t -= delta
		if _drown_t <= 0.0:
			_drown_t = 1.0
			hud.notify("You are drowning. Get to shore.")
		player.health = maxf(1.0, player.health - 7.0 * delta)
		hud.set_health(player.health / player.max_health, true)
		_regen_wait = maxf(_regen_wait, 3.0)
		if player.health <= 1.0:
			player.dodge_t = 0.0
			damage_player(9999.0, p)
	if Net.authority():
		_foe_sea_t -= delta
		if _foe_sea_t <= 0.0:
			_foe_sea_t = 1.0
			for e in enemies:
				if not is_instance_valid(e) or not e.is_alive():
					continue
				if e.walks() and e.global_position.y < WIsles.SEA_Y - 2.0 and terrain.is_water(e.global_position.x, e.global_position.z, 2.0):
					e.die(false)
				elif e.kind in ["serpent", "lampeater"] and not terrain.is_water(e.global_position.x, e.global_position.z, 1.5):
					e.die(false)   # it will not follow onto land; it sinks back
			if deep:
				deep.host_tick(1.0)
			if kraken:
				kraken.host_tick()
			if events:
				events.host_tick(1.0)
			_serpent_t -= 1.0
			if _serpent_t <= 0.0:
				_serpent_t = 10.0
				_serpent_watch()


func _world_tick(delta: float) -> void:
	_sync_t -= delta
	if _sync_t <= 0.0 and Net.online:
		_sync_t = 10.0
		shared("_w_clock", [clock, day, nights])
	var is_night := clock >= weather.dusk() or clock < weather.dawn()
	if sea:
		weather.host_tick(delta)
	if is_night != night:
		shared("_w_nightfall" if is_night else "_w_dawn", [day])
	if not vigils.is_empty():
		_vigil_tick(delta)
	if night:
		_wave_t -= delta
		if _wave_t <= 0.0:
			_wave_t = maxf(16.0, 34.0 - nights * 1.5) * float(WRules.pace()[1])
			_night_wave()
	else:
		_day_t -= delta
		if _day_t <= 0.0:
			_day_t = 6.0
			_day_watch()
	_regrow_tick(delta)
	if hall:
		hall.host_tick(delta)
	if vaults:
		vaults.host_tick(delta)
	_quest_t -= delta
	if _quest_t <= 0.0:
		_quest_t = 5.0
		_quest_foes()
	_safe_t -= delta
	if _safe_t <= 0.0:
		_safe_t = 2.0
		_keep_safe()
	_spikes(delta)
	_lair_tick()
	_beast_tick(delta)


func _w_weather(k: String, secs: float, ang: float) -> void:
	weather.set_kind(k, secs, ang)


func _w_wind(ang: float) -> void:
	if sea:
		sea.wind_ang = ang


## A fire burning close by: a lit campfire, stove, cooking station or torch, or a town's hearths.
func near_fire(at: Vector3, reach := 8.0) -> bool:
	if settlement_at(at, 0.0) != "":
		return true
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		if pc.kind in FIRE_KINDS and burning(pid) and pc.pos.distance_to(at) < reach:
			return true
	return false


func _w_clock(c: float, d: int, n: int) -> void:
	if Net.authority():
		return
	if absf(c - clock) > 0.05:
		clock = c
	day = d
	nights = n


## Some nights have a name and a nature of their own. Hold until dawn without falling, and the
## morning gives something for it. Every pilgrim works out the same night from the world and its count.
const NIGHT_THEMES := {
	"screaming": {"name": "The Screaming Night", "text": "Box cats run in packs tonight. Hold until dawn.", "many": 1.0, "gives": [["fittings_fine", 2], ["meat", 3]]},
	"long": {"name": "The Long Dark", "text": "More forms walk tonight than any night before. Hold until dawn.", "many": 1.4, "gives": [["fittings_rare", 1], ["salt", 40]]},
	"hunt": {"name": "The Hunter's Moon", "text": "Greater forms walk among the rest tonight. Hold until dawn.", "many": 1.0, "gives": [["tempered", 2], ["clockwork", 1]]},
	"quiet": {"name": "A Quiet Night", "text": "Few walk tonight. Rest, or build.", "many": 0.5, "gives": []},
}
var night_theme := ""
var _fell_tonight := false

func night_theme_for(n: int) -> String:
	if n < 3 or great_night(n):
		return ""   # the first nights are plain, and the great raid is its own
	var rr := RandomNumberGenerator.new()
	rr.seed = hash([world_seed, n, "night"])
	if rr.randf() < float(WRules.pace()[2]) and not WRules.sworn("vow_hunted"):
		return ""
	var ks := NIGHT_THEMES.keys()
	return ks[rr.randi_range(0, ks.size() - 1)]


func _w_nightfall(_d: int) -> void:
	night = true
	_wave_t = 25.0
	night_theme = night_theme_for(nights + 1)
	_fell_tonight = false
	if night_theme != "":
		var nt: Dictionary = NIGHT_THEMES[night_theme]
		get_tree().create_timer(3.0, false).timeout.connect(func():
			if is_instance_valid(self) and night:
				hud.title_card("", nt.name)
				hud.notify(nt.text))
	if Net.authority():
		if great_night(nights + 1) and not flags.get("ending", "") in ["writer", "unlit"]:
			get_tree().create_timer(20.0, false).timeout.connect(func():
				if is_instance_valid(self) and night:
					_great_raid())
		else:
			get_tree().create_timer(randf_range(40.0, 160.0), false).timeout.connect(func():
				if is_instance_valid(self) and night:
					_maybe_raid())
	sfx("drone", -6)
	hud.say("The sun goes down behind the ridges. Night comes to the waste, and the forms come with it.", 6.0)
	if WCrowd.describe(self) != "":
		hud.notify(WCrowd.describe(self))
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
	if night_theme != "" and not Net.dedicated:
		var nt: Dictionary = NIGHT_THEMES[night_theme]
		if not _fell_tonight and not nt.gives.is_empty():
			give(nt.gives)
			if WRules.sworn("vow_hunted"):
				give(nt.gives)   # the Vow of the Hunted: its dawn gives twice
			hud.notify("You held through %s." % nt.name)
		elif _fell_tonight and not nt.gives.is_empty():
			hud.notify("%s is over. You fell in it, so it gives you nothing." % nt.name)
	night_theme = ""
	if d > 1 and WWeather.season_of(d) != WWeather.season_of(d - 1):
		var se: Dictionary = WWeather.SEASONS[WWeather.season_of(d)]
		hud.title_card("", se.name)
		hud.notify(se.text)
	if Net.authority():
		_great_dawn()
		for e in enemies:
			if is_instance_valid(e) and e.is_alive():
				e.die(false)
		_dawn_world()
	_great_warning()
	quests.on_event("dawn", {})
	award("dawn")
	save_all()


func _nth_night(n: int) -> String:
	var words := ["", "the first night", "the second night", "the third night", "the fourth night", "the fifth night", "the sixth night", "the seventh night"]
	return words[n] if n < words.size() else "%d nights" % n


var _regrow_t := 20.0
const REGROW_CHANCE := 0.04   ## each 20 s, the chance a gathered tree, rock or heap gets one share back


## What is taken from the land slowly comes back, here and there, a share at a time: never under
## someone's nose, so a picked-over place fills again while you are away.
func _regrow_tick(delta: float) -> void:
	_regrow_t -= delta
	if _regrow_t > 0.0 or not Net.authority():
		return
	_regrow_t = 20.0
	var tg := targets()
	for nd in nodes:
		var full := int(NODE_KINDS[nd.kind].charges)
		if int(nd.charges) >= full or randf() >= REGROW_CHANCE:
			continue
		var np: Vector3 = nd.pos if nd.pos is Vector3 else Vector3(nd.pos.x, 0, nd.pos.y)
		var seen := false
		for t in tg:
			if t.global_position.distance_squared_to(np) < 400.0:
				seen = true
				break
		if not seen:
			shared("_w_node", [nd.id, int(nd.charges) + 1, int(nd.back)])


## At dawn what was taken from the land begins to come back, and the people have new work.
func _dawn_world() -> void:
	for nd in nodes:
		if nd.charges <= 0 and day >= int(nd.back):
			shared("_w_node", [nd.id, int(NODE_KINDS[nd.kind].charges), 0])
	quests.refresh_offers()
	settlers.host_dawn()


func _w_kraken_down(d: int) -> void:
	kraken.fallen(d)


## Put out for Ruth: the beacon goes dark, and the pact is made.
func _w_beacon_out(i: int) -> void:
	lit.erase(i)
	_light_beacon(i, false)
	flags["unlit_pact"] = true
	if not Net.dedicated and player.global_position.distance_to(beacon_nodes[i].pos) < 200.0:
		hud.say("%s goes dark. Somewhere in the Dead Forest, someone lets out a breath." % WPlaces.BEACONS[i].name, 6.0)
	if ready_world:
		autosave_soon(2.0)


func _w_spirit(peer: int, id: String, on: bool) -> void:
	spirits.show(peer, id, on)


func _w_settler(s: Dictionary) -> void:
	settlers.add(s)
	if not Net.dedicated and pieces.has(int(s.fire)) and player and player.global_position.distance_to(pieces[int(s.fire)].pos) < 200.0:
		hud.notify("A wanderer, %s, has come to stay at your fire. A %s." % [s.name, WSettlers.JOBS[s.job].name])


func _w_settler_gone(id: int, why: String) -> void:
	settlers.remove(id)
	if not Net.dedicated:
		hud.notify(why)


# ================================================================== growing

## Gives this survivor experience for a deed (see WSkills.XP).
func award(kind: String, mult := 1.0) -> void:
	if guide:
		guide.event(kind)
	if Net.dedicated or _pfail or not WSkills.XP.has(kind):
		return
	var amount := int(round(WSkills.XP[kind] * mult * (1.25 if rested > 0.0 else 1.0)))
	var ups := skills.gain(amount)
	Game.gain_pxp(maxi(1, amount / 2))
	if ui:
		ui.xp_gained(amount)
	if ups > 0:
		sfx("choir", -8)
		sfx("jingle_up", -6)
		hud.title_card("Level %d" % skills.level, "You have learned something of the waste")
		hud.notify("A point to spend. Press K to see what you might learn.")
		autosave_soon(2.0)


func _apply_skills() -> void:
	if player == null or player.weapon == null:
		return
	var full := player.health >= player.max_health - 0.01
	player.max_health = skills.health_max() + _meal_hp
	player.health = player.max_health if full else minf(player.health, player.max_health)
	player.walk_speed = 3.4 * skills.speed_mult()
	player.run_speed = 5.8 * skills.speed_mult()
	player.weapon.reserve_max = skills.reserve_max()
	player.weapon.damage_mult = skills.damage_mult() * (1.2 if power_is("eye") else 1.0) * (alchemy.damage_mult() if alchemy else 1.0)
	player.weapon.reload_mult = skills.reload_mult()
	inv.grow(skills.pack_size())
	if not Net.dedicated:
		hud.set_health(player.health / player.max_health, true)
	if ui:
		ui.skills_changed()


func _apply_time(force: bool) -> void:
	# The sun rises at six and sets at eighteen; the moon has the rest
	# The season sets the length of the day: the sun is up an hour after dawn and down two before dusk
	var rise := weather.dawn() + 1.0
	var down := weather.dusk() - 2.0
	var sun_ang: float
	if clock >= rise and clock < down:
		sun_ang = (clock - rise) / (down - rise) * PI
	else:
		sun_ang = PI + wrapf(clock - down, 0.0, 24.0) / (24.0 - (down - rise)) * PI
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
	if air:
		air.apply_env(env, day_k)
	weather.apply_env(env, night_k)
	if _stars:
		_stars.material_override.albedo_color.a = clampf(night_k * 1.5 - 0.3, 0.0, 1.0)
		# Once the page is written, Speeb's gaze has left the waste: no stars
		_stars.visible = night_k > 0.2 and flags.get("ending", "") != "writer"
	var under: bool = hall != null and player != null and hall.inside(player.global_position)
	env.fog_aerial_perspective = 0.0 if under else 0.5
	if under:
		# Under the waste no sun, no sky: only what light was carried down
		sun.light_energy = 0.0
		env.ambient_light_energy = 0.05
		env.fog_light_color = Color(0.01, 0.01, 0.015)
		env.fog_density = 0.03


## How many forms the night sends, and of what kind, grows with the nights survived.
func _night_wave() -> void:
	var tg := targets()
	if tg.is_empty():
		return
	var cap := mini(int(WCrowd.scale(self, 10 + mini(nights, 10)) * (1.25 if night_theme == "long" else 1.0) * float(WRules.pace()[0])), WCrowd.ALIVE_CAP)
	if flags.get("ending", "") == "writer":
		cap = int(cap / 2)   # the Mouth is closed; what walks now is only what was left
	if flags.get("ending", "") == "unlit":
		return   # it has what it wanted: nothing comes at night
	for t in tg:
		if safe_at(t.global_position):
			continue
		if alive_count() >= cap:
			return
		# Fewer come near home, more in the far lands
		var tier := tier_at(t.global_position)
		var n := maxi(1, int(round((2 + int(nights * 0.5) + randi() % 2) * [0.6, 0.85, 1.0, 1.15][tier - 1] * WCrowd.share(self, t.global_position) * float(NIGHT_THEMES.get(night_theme, {}).get("many", 1.0)) * float(WRules.pace()[0]))))
		var roster: Array = forms_at(t.global_position)
		# Near where the cast-out wake, the box cats run in packs some nights
		if (tier == 1 and randf() < (0.8 if night_theme == "screaming" else 0.35)) or (night_theme == "screaming" and randf() < 0.3):
			var pack := mini(int(WCrowd.scale(self, randi_range(8, 14) + mini(nights, 6)) * float(WRules.pace()[0])), WCrowd.ALIVE_CAP - alive_count())
			var from: Vector3 = t.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 40.0
			for k in pack:
				var bc = _spawn_near("box_cat", from, 2.0, 8.0)
				if bc and bc.has_method("seek"):
					bc.seek(t.global_position, 60.0)
			if pack > 0:
				sfx("shriek_%d" % (randi() % 4), 0, from, 2.1)
			continue
		for k in n:
			var e = _spawn_near(roster[randi() % roster.size()], t.global_position, 30.0, 48.0)
			# The night's walkers come looking for the living; they need not see you yet
			if e and e.has_method("seek"):
				e.seek(t.global_position, 40.0)
		if nights >= 2 and tier >= 2 and randf() < 0.12 + nights * 0.02:
			_spawn_near("saucer", t.global_position, 30.0, 40.0)
		if (nights >= 4 and tier >= 3 and randf() < 0.06 + nights * 0.01) or (night_theme == "hunt" and randf() < 0.35):
			_spawn_near("elite", t.global_position, 35.0, 45.0)
			hud.notify("Something greater walks tonight.")
		# Some nights, in the dark country, something follows that is hardly there at all
		var bio: String = terrain.biome_name(t.global_position.x, t.global_position.z)
		var dark := 0.1 if bio in ["forest", "marsh", "basalt"] else 0.04
		if nights >= 1 and tier >= 2 and randf() < dark + nights * 0.01 and _unseen_count() < tg.size():
			_spawn_near("unseen", t.global_position, 34.0, 46.0)
		if randf() < 0.25:
			sfx("horror_deep", -10, t.global_position + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)), randf_range(0.8, 1.0))


func _unseen_count() -> int:
	var n := 0
	for e in foes.values():
		if is_instance_valid(e) and e.kind == "unseen" and e.is_alive():
			n += 1
	return n


var _quest_t := 5.0


## A place a quest sends you to clear keeps its forms coming while you are there, day or night,
## until the count is made: never a few on the first visit and then nothing.
func _quest_foes() -> void:
	if not Net.authority() or quests == null:
		return
	var tg := targets()
	for q in quests.active():
		var st: Dictionary = quests.step_of(q)
		if st.get("t", "") != "kill" or st.get("ruin", "") == "tenth_hall":
			continue   # the hall sends its own
		var c = quests.target_of(q)
		if not (c is Vector3):
			continue
		var near := false
		for t in tg:
			if t.global_position.distance_to(c) < 65.0:
				near = true
		if not near:
			continue
		var left := int(st.n) - int(q.get("have", 0))
		var here := 0
		for e in enemies:
			if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(c) < 45.0:
				here += 1
		var roster: Array = forms_at(c)
		for k in mini(WCrowd.scale_near(self, c, 2), mini(WCrowd.scale_near(self, c, 3), left) - here):
			_spawn_one(roster[randi() % roster.size()], c, 6.0, 16.0, true)


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
				var n := WCrowd.scale_near(self, r.pos, 2 + randi() % 3)
				if r.has("isle"):
					# An isle's heart is kept more fiercely, by its own kind
					var roster: Array = forms_at(r.pos)
					for k in n + 2:
						_spawn_near(roster[randi() % roster.size()], r.pos, 8.0, 18.0, true)
					continue
				var tr := tier_at(r.pos)
				var guards: Array = ["rusher", "spitter", "spider", "idol", "brute", "howler", "hollow", "saltbone", "hollow", "warden"].filter(func(k): return int(LesserSpeeb.FORM_TIER.get(k, 1)) <= tr)
				for k in n:
					_spawn_near(guards[randi() % guards.size()], r.pos, 6.0, 14.0, true)
		if alive_count() < 2 and randf() < 0.08:
			var isle := not terrain.isle_at(p.x, p.z, 1.3).is_empty()
			var roster: Array = forms_at(p) if isle else ["rusher", "spider", "swarm"]
			_spawn_near(roster[randi() % roster.size()], p, 40.0, 60.0)


func _spawn_near(kind: String, c: Vector3, rmin: float, rmax: float, anywhere := false) -> LesserSpeeb:
	# However many walk, the waste never wakes more than the machine can carry
	if alive_count() >= WCrowd.ALIVE_CAP and not kind in ["elite", "saucer"]:
		return null
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
		if terrain.is_water(x, z, 0.3):
			continue   # nothing rises out of the open sea (save what lives in it)
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
	if e.variant == "bellwound":
		shared("_w_kraken_down", [day])
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

# ================================================================== boats

## Puts a boat from the pack into the water at the shore before you.
func launch_boat(item: String) -> bool:
	var k := {"raft": "raft", "sloop": "sloop", "longboat": "longboat"}.get(item, "") as String
	if k == "":
		return false
	if player.vessel != null or player.mount != null:
		hud.notify("Get down first.")
		return false
	var at := player.global_position
	var best := Vector3.INF
	for ring in range(1, 8):
		var r := ring * 2.5
		for j in 16:
			var a := TAU * j / 16.0
			var q := at + Vector3(cos(a), 0, sin(a)) * r
			if terrain.is_water(q.x, q.z, 1.2 if k == "raft" else 1.8):
				best = Vector3(q.x, WIsles.SEA_Y, q.z)
				break
		if best != Vector3.INF:
			break
	if best == Vector3.INF:
		hud.notify("Launch it from the shore: stand at the water's edge.")
		return false
	if inv.take(item, 1) < 1:
		return false
	var to := best - at
	shared("_rq_launch", [Net.me(), k, best, atan2(to.x, to.z)])
	hud.notify("You push the %s into the water." % str(WBoat.KINDS[k].name).to_lower())
	sfx("carve", -8, best, 0.7)
	return true


func _rq_launch(_by: int, k: String, p: Vector3, yaw: float) -> void:
	if not Net.authority():
		return
	var bid := boat_next
	boat_next += 1
	shared("_w_boat", [bid, k, p, yaw, float(WBoat.KINDS[k].hp)])


func _w_vault_build(id: String) -> void:
	if vaults:
		vaults.build(id)


func _w_vault_gate(id: String, room: int) -> void:
	if vaults:
		vaults.open_gate(id, room)


func _w_vault_done(id: String, d: int, shares: Array) -> void:
	if vaults:
		vaults.done(id, d, shares)


func _w_boat_lamp(bid: int, on: bool) -> void:
	if boats.has(bid) and is_instance_valid(boats[bid]):
		boats[bid].set_lamp(on)


func _w_fleet(at: Vector3, yaw: float, d: int) -> void:
	if deep:
		deep.build_fleet(at, yaw, d)


func _w_fleet_gone() -> void:
	if deep:
		deep.clear_fleet()
		hud.notify("With the dawn the grey ship is gone, as if it had never been.")


func _w_boat(bid: int, k: String, p: Vector3, yaw: float, hp: float) -> void:
	if boats.has(bid) and is_instance_valid(boats[bid]):
		return
	boat_next = maxi(boat_next, bid + 1)
	var b := WBoat.new().setup(self, bid, k)
	b.yaw = yaw
	b.hp = hp
	add_child(b)
	b.global_position = p
	b.net_set(p, yaw, 0.0, 0)
	boats[bid] = b
	if ready_world:
		autosave_soon(5.0)


## Interact on a boat: board it (the helm first), step off it. Holding it mends a hurt one (mend_boat).
func boat_used(b: WBoat) -> void:
	if b.riders.has(Net.me()):
		_leave_boat(b)
		return
	if player.mount:
		hud.notify("Get down from your cat first.")
		return
	if player.vessel != null:
		return
	if b.free_seat() < 0:
		hud.notify("There is no room aboard.")
		return
	shared("_rq_board", [b.id, Net.me()])


## Hold interact on a hurt boat: 4 wood mends a good part of it.
func mend_boat(b: WBoat) -> void:
	if b.hp >= float(b.spec.hp) - 1.0:
		return
	if inv.count("wood") < 4:
		hud.notify("You need 4 wood to mend it.")
		return
	inv.take("wood", 4)
	shared("_rq_boat_hp", [b.id, minf(float(b.spec.hp), b.hp + float(b.spec.hp) * 0.4)])
	hud.notify("You mend the %s." % str(b.spec.name).to_lower())
	sfx("carve", -6, b.global_position)


func _rq_board(bid: int, by: int) -> void:
	if not Net.authority() or not boats.has(bid):
		return
	var b: WBoat = boats[bid]
	if b.riders.has(by):
		return
	var seat := b.free_seat()
	if seat < 0:
		return
	var r := b.riders.duplicate()
	r[by] = seat
	shared("_w_riders", [bid, r])


func _rq_leave(bid: int, by: int) -> void:
	if not Net.authority() or not boats.has(bid):
		return
	var r: Dictionary = boats[bid].riders.duplicate()
	r.erase(by)
	shared("_w_riders", [bid, r])


func _w_riders(bid: int, r: Dictionary) -> void:
	if not boats.has(bid):
		return
	var b: WBoat = boats[bid]
	var was: bool = b.riders.has(Net.me())
	b.set_riders(r)
	if r.has(Net.me()) and not was:
		player.vessel = b
		player.velocity = Vector3.ZERO
		if int(r[Net.me()]) == 0:
			var how := "Steer with [%s] and [%s]. " % [Game.key_text("move_left"), Game.key_text("move_right")]
			if float(b.spec.sail) > 0.0:
				how += "[%s] raises the sail, [%s] lowers it; it runs best before the wind." % [Game.key_text("move_forward"), Game.key_text("move_back")]
			else:
				how += "[%s] and [%s] paddle." % [Game.key_text("move_forward"), Game.key_text("move_back")]
			hud.notify(how)
		else:
			hud.notify("You sit aboard. Shoot from here; [%s] on the boat to step off." % Game.key_text("interact"))
	elif not r.has(Net.me()) and was and player.vessel == b:
		player.vessel = null


## Off the boat: onto dry ground near it if there is any, or into the water beside it.
func _leave_boat(b: WBoat) -> void:
	shared("_rq_leave", [b.id, Net.me()])
	player.vessel = null
	var at := b.global_position
	var spot := at + Vector3(b.global_transform.basis.x) * 2.5
	for ring in range(1, 6):
		var found := false
		for j in 12:
			var a := TAU * j / 12.0
			var q := at + Vector3(cos(a), 0, sin(a)) * ring * 2.5
			if not terrain.is_water(q.x, q.z, -0.2):
				spot = q
				found = true
				break
		if found:
			break
	spot.y = maxf(terrain.height_at(spot.x, spot.z), WIsles.SEA_Y - 1.0) + 0.3
	player.global_position = spot
	player.velocity = Vector3.ZERO


func _w_boat_move(bid: int, p: Vector3, yaw: float, sp: float, sl: int) -> void:
	if not boats.has(bid):
		return
	var b: WBoat = boats[bid]
	if b.riders.has(Net.me()) and int(b.riders[Net.me()]) == 0:
		return   # it is ours to steer
	b.net_set(p, yaw, sp, sl)


func _rq_boat_hp(bid: int, hp: float) -> void:
	if Net.authority() and boats.has(bid):
		shared("_w_boat_hp", [bid, hp])


func _w_boat_hp(bid: int, hp: float) -> void:
	if not boats.has(bid):
		return
	var b: WBoat = boats[bid]
	b.hp = hp
	b._refresh_prompt()
	if hp <= 0.0 and Net.authority():
		shared("_w_boat_gone", [bid, true])


## Harm to a boat (only the host's count of it matters).
func hurt_boat(b: WBoat, amount: float) -> void:
	shared("_rq_boat_hp", [b.id, b.hp - amount])
	if b.riders.has(Net.me()):
		player.shake(0.3)
		hud.notify("The %s shudders." % str(b.spec.name).to_lower())


func _w_boat_gone(bid: int, wrecked: bool) -> void:
	if not boats.has(bid):
		return
	var b: WBoat = boats[bid]
	boats.erase(bid)
	if player.vessel == b:
		player.vessel = null
		player.global_position = b.global_position + Vector3(0, -0.5, 0)
		if wrecked:
			hud.notify("The %s breaks up under you. Swim for it." % str(b.spec.name).to_lower())
	if wrecked:
		sfx("crumble", -2, b.global_position)
	b.queue_free()
	if ready_world:
		autosave_soon(5.0)


## Lost books may teach a better rig.
func boat_speed_mult() -> float:
	return 1.2 if flags.has("book_rigging") else 1.0


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
	_salts_tick()
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
		# Meat soothes a hurt cat at once
		for f in ["roast", "meat", "raw_meat"]:
			if inv.count(f) > 0:
				inv.take(f, 1)
				c._rest = 0.0
				c.hp = minf(WCat.HP_MAX, c.hp + 40.0)
				c._refresh()
				hud.notify("%s eats, and lets you up again." % c.cat_name)
				ride()
				return
		hud.notify("%s is hurt and will not carry you for %d seconds. Meat would soothe it." % [c.cat_name, ceili(c._rest)])
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
	if failing or downed or _pfail or Net.dedicated or (dev and dev.god):
		return
	if player.dodge_t > 0.0 and from.distance_to(player.global_position) < 6.0:
		# Stepped aside in time
		hud.hitmarker(false, true)
		return
	amount *= Game.difficulty_scale("damage") * skills.harm_mult() * (1.0 - WArms.worn(arms).guard) * alchemy.harm_mult()
	if WRules.sworn("vow_glass"):
		amount *= 1.5
	amount *= TIER_HARM[tier_at(from) - 1] * sqrt(foe_power()) * (1.25 if flags.has("second_vow") else 1.0)
	if power_is("gilt"):
		amount *= 0.8
	if night and skills.has_boon("night_eyes"):
		amount *= 0.85
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
	# Aboard, a heavy blow lands on the boat as well
	if player.vessel != null and is_instance_valid(player.vessel) and amount >= 10.0:
		hurt_boat(player.vessel, amount * 0.6)
	# Riding, the cat takes half of the blow; hurt out, it throws its rider and runs off a while
	if player.mount and cat:
		if cat.take(amount * 0.5):
			dismount()
			hud.notify("%s throws you and will not carry you for %d seconds. Meat would soothe it." % [cat.cat_name, int(WCat.REST_HURT)])
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
	_burn = 0.0
	_slow = 0.0
	_freeze = 0.0
	_blind = 0.0
	meals.clear()
	_meal_stats()
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
	var where := "your bedroll" if bedroll != null and builder.near_kind(bedroll, "bedroll", 1.0) and bed_mine_or_free(bed_at(bedroll)) else "the nearest town"
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
	var seen := _dream_reveal(player.global_position)
	if seen != "":
		hud.notify("In the dark you glimpsed %s. It is now on your map." % seen)


## Failure still pays: waking from a fall shows the nearest unknown lair or ruin.
func _dream_reveal(from: Vector3) -> String:
	var best := ""
	var bp := Vector3.ZERO
	var bd := 900.0
	for list in [lairs, ruins]:
		for r in list:
			var p: Vector3 = r.pos
			if is_revealed(p):
				continue
			var d := Vector2(p.x - from.x, p.z - from.z).length()
			if d < bd:
				bd = d
				bp = p
				best = str(r.get("name", "a ruin"))
	if best != "":
		_reveal_around(bp, 60.0)
	return best


## The fallen companion within reach, if any.
func _downed_near(reach := 3.0) -> Variant:
	var best = null
	var bd := reach
	for id in avatars:
		var av = avatars[id]
		if is_instance_valid(av) and av.downed:
			var d: float = av.global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = av
	return best


var _salts_hint := -1   ## the companion last told about the salts key, so it is said once


## Smelling salts at a fallen companion: walk up and press the revive key.
func _salts_tick() -> void:
	if Net.dedicated or downed or player.input_locked:
		return
	var av = _downed_near()
	if av == null:
		_salts_hint = -1
		return
	var has := inv.count("salts") > 0
	if _salts_hint != av.peer_id:
		_salts_hint = av.peer_id
		if has:
			hud.notify("%s is down. Press [%s] to use smelling salts." % [Net.name_of(av.peer_id), Game.key_text("revive")])
		else:
			hud.notify("%s is down. Hold [%s] on them to raise them." % [Net.name_of(av.peer_id), Game.key_text("interact")])
	if Input.is_action_just_pressed("revive"):
		if not has:
			hud.notify("You have no smelling salts.")
			return
		Net.revive(av.peer_id, raise_strength(true))
		hud.notify("You raise %s with the salts." % Net.name_of(av.peer_id))
		sfx("carve", -10, null, 1.6)


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
	if bedroll != null and builder.near_kind(bedroll, "bedroll", 1.0) and bed_mine_or_free(bed_at(bedroll)):
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
	if maxf(absf(p.x), absf(p.z)) > WPlaces.HALF:
		return true   # the sea and its isles are on the old charts
	var cell := WPlaces.SIZE / REVEAL_N
	var i := clampi(int((p.x + WPlaces.HALF) / cell), 0, REVEAL_N - 1)
	var j := clampi(int((p.z + WPlaces.HALF) / cell), 0, REVEAL_N - 1)
	return revealed[j * REVEAL_N + i] != 0


var _biome := ""


var _region := ""


func _visit_check() -> void:
	var bn := land_at(player.global_position)
	var region := terrain.region_name(player.global_position.x, player.global_position.z)
	if region != _region:
		var il := terrain.isle_at(player.global_position.x, player.global_position.z, 1.4)
		if _region != "":
			if region == "The Grey Sea":
				hud.notify("The Grey Sea\nOpen water. Keep to a boat: a swimmer tires, and things live under it.")
			elif not il.is_empty() and region == il.name:
				if not visited.has("isle_" + str(il.key)):
					visited["isle_" + str(il.key)] = true
					sfx("jingle_find", -8)
					hud.title_card("", il.name)
					award("settlement")
				hud.notify("%s (danger %d of 4)\n%s%s" % [il.name, tier_at(player.global_position), WIsles.THEMES[il.key].text, land_warning(bn)])
			else:
				hud.notify("%s (danger %d of 4)\n%s%s" % [WTerrain.BIOME_NAMES[bn], tier_at(player.global_position), BIOME_TEXT[bn], "" if gentle_at(player.global_position) else land_warning(bn)])
		_region = region
	if bn != _biome:
		_biome = bn
		if not seen_biomes.has(bn):
			seen_biomes[bn] = true
			if seen_biomes.size() > 1:
				award("biome")
	# The tar drags at you: you can still hurry, but not run full out
	player.speed_cap = 4.4 if bn == "marsh" and not warded("marsh") and not gentle_at(player.global_position) and settlement_at(player.global_position, 4.0) == "" else -1.0
	var k := settlement_at(player.global_position, 10.0)
	if k != "" and not visited.has(k):
		visited[k] = true
		sfx("jingle_find", -8)
		hud.title_card("", WPlaces.SETTLEMENTS[k].name)
		hud.notify(WPlaces.SETTLEMENTS[k].blurb)
		award("settlement")
		quests.on_event("reach", {})
	for r in ruins:
		if not known_ruins.has(r.id) and player.global_position.distance_to(r.pos) < 40.0:
			known_ruins[r.id] = true
			var tale := WPlaces.ruin_story(str(r.id), str(r.kind))
			if tale == "":
				hud.notify(r.name)
			elif str(r.id).begins_with("isle_"):
				hud.notify(tale)
			else:
				hud.notify("%s\n%s" % [r.name, tale])
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
	# Who is aboard what, so the newcomer sees them seated
	for bid in boats:
		if is_instance_valid(boats[bid]) and not boats[bid].riders.is_empty():
			Net.call_peer(by, "_w_riders", [bid, boats[bid].riders])


func _w_snapshot(d: Dictionary) -> void:
	if terrain == null:
		_make_world(int(d.get("seed", 1771)), int(d.get("gen", 1)))
		player.place(spawn_pos, spawn_yaw)
	apply_world(d)
	ready_world = true
	_world_ready()
	player.set_physics_process(true)
	hud.notify("You stand in the same waste as the fellowship. Day %d." % day)


func net_left(id: int) -> void:
	super.net_left(id)
	# One who leaves is off any boat they were on
	if Net.authority():
		for bid in boats:
			if boats[bid].riders.has(id):
				_rq_leave(bid, id)
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
		pcs[pid] = [pc.kind, pc.pos, pc.yaw, pc.hp, pc.get("open", false), {"name": pc.get("name", ""), "crop": pc.get("crop", ""), "sown": pc.get("sown", 0.0), "fuel": pc.get("fuel", -1.0), "tier": pc.get("tier", 0), "owner": pc.get("owner", "")}]
	var crate_days := {}
	for id in crates:
		if int(crates[id].day) > -99:
			crate_days[id] = crates[id].day
	var sat := {}
	for sid in satchels:
		sat[sid] = [satchels[sid].pos, satchels[sid].grave]
	return {
		"v": 2, "gen": world_gen, "uid": world_uid, "seed": world_seed, "day": day, "clock": clock, "nights": nights, "night": night, "lit": lit, "flags": flags, "rep": rep,
		"mined": mined, "pieces": pcs, "piece_next": piece_next, "containers": containers, "crates": crate_days, "settlers": settlers.to_data(),
		"satchels": sat, "satchel_next": satchel_next, "quests": quests.to_data(), "tracked": quests.tracked,
		"marks": map_marks, "rules": rules, "boats": _boats_data(), "boat_next": boat_next,
		"weather": [weather.kind, weather.left, sea.wind_ang if sea else 0.0],
	}


func _boats_data() -> Dictionary:
	var out := {}
	for bid in boats:
		var b: WBoat = boats[bid]
		if is_instance_valid(b):
			out[bid] = [b.kind, b.global_position, b.yaw, b.hp]
	return out


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
			if int(p[5].get("tier", 0)) > 0:
				builder._w_tier(int(pid), int(p[5].tier), float(p[3]))
			_w_portal_name(int(pid), str(p[5].get("name", "")))
			_w_plant(int(pid), str(p[5].get("crop", "")), float(p[5].get("sown", 0.0)))
			if str(p[5].get("owner", "")) != "":
				_w_bed_owner(int(pid), str(p[5].owner), true)
		# Fires laid before they burned wood start with a full three days
		if str(p[0]) in FIRE_KINDS:
			var f := float(p[5].get("fuel", -1.0)) if p.size() > 5 and p[5] is Dictionary else -1.0
			_w_fuel(int(pid), f if f >= 0.0 else world_hours() + FUEL_START)
	piece_next = int(d.get("piece_next", 1))
	containers = d.get("containers", {})
	settlers.from_data(d.get("settlers", []))
	for id in d.get("crates", {}):
		_w_crate_day(id, int(d.crates[id]))
	for sid in d.get("satchels", {}):
		_w_satchel(sid, d.satchels[sid][0], d.satchels[sid][1])
	satchel_next = int(d.get("satchel_next", 1))
	var wd = d.get("weather", [])
	if wd is Array and wd.size() >= 3:
		weather.set_kind(str(wd[0]), float(wd[1]), float(wd[2]))
		weather.k = 0.0 if str(wd[0]) == "clear" else 1.0
	boat_next = maxi(boat_next, int(d.get("boat_next", 1)))
	var bd = d.get("boats", {})
	if bd is Dictionary:
		for bid in bd:
			var e = bd[bid]
			if e is Array and e.size() >= 4 and WBoat.KINDS.has(str(e[0])) and e[1] is Vector3:
				_w_boat(int(bid), str(e[0]), e[1], float(e[2]), float(e[3]))
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
		"pos": safe_keep_pos(), "yaw": player.yaw, "revealed": Marshalls.raw_to_base64(revealed),
		"visited": visited, "known": known_ruins, "skills": skills.to_data(), "biomes": seen_biomes, "bedroll": bedroll, "warms": arms, "food": food, "rest": rest,
		"guide": guide.step if guide else -1, "cat": cat.to_data() if cat else _cat_saved,
		"meals": meals, "rested": rested, "power": power, "power_left": power_left, "brews": alchemy.to_data(), "spirits": spirits.to_data(), "trade": trades.to_data(),
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
	meals = {}
	if d.get("meals") is Dictionary:
		for k in d.meals:
			var m = d.meals[k]
			if Items.info(k).has("meal") and m is Array and m.size() == 2:
				meals[k] = [float(m[0]), float(m[1])]
	rested = float(d.get("rested", 0.0))
	alchemy.from_data(d.get("brews", {}))
	spirits.from_data(d.get("spirits", {}))
	trades.from_data(d.get("trade", ""))
	power = str(d.get("power", ""))
	power_left = float(d.get("power_left", 0.0))
	_meal_stats()
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
		if weather and is_instance_valid(player) and p.distance_to(player.global_position) < 40.0:
			weather.roofs_changed()


func _w_piece_hp(pid: int, hp: float) -> void:
	builder._w_piece_hp(pid, hp)


func _w_piece_gone(pid: int) -> void:
	builder._w_piece_gone(pid)
	if ready_world:
		autosave_soon(5.0)
		if weather:
			weather.roofs_changed()


func _rq_door(pid: int) -> void:
	builder._rq_door(pid)


func _rq_tier(by: int, pid: int, t: int) -> void:
	builder._rq_tier(by, pid, t)


func _w_tier(pid: int, t: int, hp: float) -> void:
	builder._w_tier(pid, t, hp)
	if ready_world:
		autosave_soon(5.0)


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
	WDress.kp(n, "grave", "debris", Vector3(1.6, 0, 0.8), 0.3, 3.0)
	WDress.kp(n, "grave", "character-skeleton", Vector3(-1.8, 0.05, 1.2), 2.0, 2.0)
	WDress.kp(n, "grave", "debris-wood", Vector3(0.4, 0, -2.0), 1.1, 3.0)
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
	# A real person, dressed as the waste's people are, sitting on a crate where they hid
	for ch in f.get_children():
		if ch is MeshInstance3D:
			ch.queue_free()
	var dressed := Figure.new().setup(Figure.seeded(qid.hash()))
	dressed.arms_forward = true
	dressed.seated = true
	dressed.position.y = -0.32
	f.add_child(dressed)
	WDress.kp(f, "pirate", "crate", Vector3(0, 0, -0.1), PI * 0.5, 0.75, false, Vector3.ZERO, 120.0)
	WDress.kp(f, "food", "bag", Vector3(0.7, 0, 0.4), 0.4, 1.6, false, Vector3.ZERO, 120.0)
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
		ui.prepare_map()
	var vows := WRules.vows_text()
	if vows != "" and hud and not Net.dedicated:
		get_tree().create_timer(6.0, false).timeout.connect(func():
			if is_instance_valid(hud):
				hud.notify("This world was begun under oath: %s." % vows))


## Testing aid: vows are kept once sworn, and each one bites and pays.
func debug_pace() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var out := []
	for v in 3:
		var r := rules.duplicate()
		r["pace"] = v
		set_rules(r)
		var named := 0
		for n in range(3, 60):
			if night_theme_for(n) != "":
				named += 1
		out.append("%d/%.2f" % [named, float(WRules.pace()[0])])
	print("PACE " + " ".join(out))
	get_tree().quit()


func debug_vows() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var sell0: float = skills.sell_mult()
	skills.use["pistol"] = 0
	skills.practise("pistol", 3)
	var p0: int = int(skills.use["pistol"])
	var named0 := 0
	for n in range(3, 40):
		if night_theme_for(n) != "":
			named0 += 1
	var r := rules.duplicate()
	r["vow_glass"] = 1
	r["vow_hunted"] = 1
	r["vow_tithe"] = 1
	set_rules(r)   # sworn only when a world begins: this must not take
	var locked: bool = not WRules.sworn("vow_glass")
	_w_rules(r)    # as if the world had begun under them
	skills.use["pistol"] = 0
	skills.practise("pistol", 3)
	var p1: int = int(skills.use["pistol"])
	var named1 := 0
	for n in range(3, 40):
		if night_theme_for(n) != "":
			named1 += 1
	print("VOWS locked=%s learn=%d->%d sell=%.2f->%.2f named=%d->%d text=%s" % [locked, p0, p1, sell0, skills.sell_mult(), named0, named1, WRules.vows_text()])
	get_tree().quit()


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
	# The stone at the heart: hold to call the great one out
	var lid = l.id
	var call_stone := cyl(l.pos + Vector3(0, 0.6, 0), 0.5, 1.2, _m.stone, false, 0.35, 6)
	call_stone.material_override = _m.stone
	interact_area(l.pos + Vector3(0, 0.8, 0), 2.2, "Call out the great one", func():
		if not lair_ready(l):
			hud.notify("Nothing answers. It has not come back yet.")
			return
		hud.notify("You strike the stone. Something stirs. Get back.")
		shared("_rq_lair_call", [lid]), 1.0, false)
	# Its smoke rises over the land while the great one waits: dark, with a bruise of purple
	var smoke := landmark_column(Color(0.25, 0.12, 0.3, 0.2), 180.0, 1.6)
	smoke.position = Vector3(0, 90, 0)
	n.add_child(smoke)
	l["smoke"] = smoke


## A great one sleeps until someone calls it out at the heart of its ring: walking near does not wake it.
var _lair_called := {}
var _lair_told := {}


## The host wakes a great one once a pilgrim has called it out and is still near.
func _lair_tick() -> void:
	for l in lairs:
		var e = _lair_boss.get(l.id)
		if e != null and (not is_instance_valid(e) or not e.is_alive()):
			_lair_boss.erase(l.id)
			e = null
		# Coming near a sleeping great one for the first time, you are told how to wake it
		if e == null and lair_ready(l) and not _lair_told.has(l.id) and not Net.dedicated and player.global_position.distance_to(l.pos) < 40.0:
			_lair_told[l.id] = true
			hud.notify("%s sleeps here. Hold %s at the stone in the middle to call it out, when you are ready." % [LesserSpeeb.BOSSES[l.boss].name, Game.key_text("interact")])
		if e != null or not lair_ready(l) or not _lair_called.has(l.id):
			continue
		_lair_called.erase(l.id)
		for t in targets():
			if t.global_position.distance_to(l.pos) < 45.0:
				var b := spawn_at(l.boss, l.pos + Vector3(0, 3.0, 0))
				if b:
					_lair_boss[l.id] = b
					shared("_w_lair_wake", [l.boss])
				break


func _rq_lair_call(id) -> void:
	if not Net.authority():
		return
	for l in lairs:
		if str(l.id) == str(id) and lair_ready(l) and _lair_boss.get(l.id) == null:
			_lair_called[l.id] = true


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
			for k in WCrowd.scale_near(self, seen_from, 3 + rr.randi() % 3):
				_spawn_near(["rusher", "spider", "howler", "lurker"][rr.randi() % 4], at, 2.0, 8.0, true)
		"attack":
			shared("_rq_satchel", [0, at, Items.roll("caravan", 3, rr), false])
			for k in WCrowd.scale_near(self, seen_from, 2 + rr.randi() % 3):
				_spawn_near(["rusher", "spitter", "brute", "bloater"][rr.randi() % 4], at, 4.0, 10.0, true)
		"cairn":
			shared("_rq_satchel", [0, at, Items.roll("vault", 3, rr), false])
		"unlit":
			# A band of the Unlit at their fire: gunmen and blades, and now and then a breaker
			shared("_rq_satchel", [0, at + Vector3(1.5, 0, 0), Items.roll("camp", 2, rr) + Items.roll("caravan", 2, rr), false])
			var band := ["unlit_gun", "unlit_gun", "unlit_blade"]
			if rr.randf() < 0.5:
				band.append("unlit_blade")
			if rr.randf() < 0.45:
				band.append("unlit_mark")
			if rr.randf() < 0.4:
				band.append("unlit_flame")
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
	LesserSpeeb.soften(sm, 1.0, 6.0)
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
			# Walk up beside them and press the revive key
			player.global_position = a.global_position + Vector3(1.2, 0.2, 0)
			await get_tree().process_frame
			await get_tree().process_frame
			Input.action_press("revive")
			await get_tree().process_frame
			await get_tree().process_frame
			Input.action_release("revive")
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


## Testing aid: the scans that came as one piece have their moving parts cut out (pump, slide, magazine).
func debug_gunparts() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var wpn = player.weapon
	var out: Array = []
	for g in Arms.CARVE:
		var n: Node3D = wpn._build(g, [])
		var parts := 0
		for role in ["pump", "mag"]:
			if n.has_meta(role):
				parts += (n.get_meta(role) as Node3D).find_children("*", "MeshInstance3D", true, false).size()
		out.append("%s=%d" % [g, parts])
		n.free()
	print("GUNPARTS ", " ".join(out))
	get_tree().quit()


## Testing aid: sway down the sights shrinks with practice, and moves the aim itself.
func debug_sway() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var wpn = player.weapon
	var g: String = wpn.gun()
	skills.use[g] = 0
	var raw: float = wpn.sway_amp(false)
	var sc: float = wpn.sway_amp(true)
	skills.use[g] = skills.use_need(WSkills.USE_MAX)
	var pro: float = wpn.sway_amp(false)
	wpn.debug_aim = true
	player.yaw = 0.0
	var ys: Array = []
	for i in 6:
		await get_tree().create_timer(0.3).timeout
		ys.append(player.yaw)
	var moved: bool = float(ys.max()) - float(ys.min()) > 0.00005
	print("SWAY gun=%s raw=%.5f pro=%.5f scoped=%.5f less=%s moved=%s" % [g, raw, pro, sc, pro < raw * 0.6, moved])
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


## Testing aid: each new foe comes to life with a body you can hit; fire burns, tar slows, the deacon drinks.
func debug_newfoes() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var made := 0
	var hit := 0
	for k in ["unlit_mark", "unlit_flame", "deacon", "drowned", "colossus", "wisp", "knight", "saltrifle"]:
		var e := spawn_at(k, player.global_position + f * 10.0 + Vector3(0, 1.5, 0))
		e.set_meta("raid", true)
		await get_tree().create_timer(0.4).timeout
		if e.is_alive() and e.find_children("*", "CollisionShape3D", true, false).size() > 0:
			made += 1
		var h0: float = e.hp
		LesserSpeeb.harm_pierce = 3.0
		e.hurt(10.0, f)
		LesserSpeeb.harm_pierce = 1.0
		if e.hp < h0:
			hit += 1
		if k == "unlit_flame":
			e._afflict(player)
		elif k == "drowned":
			e._afflict(player)
		elif k == "deacon":
			e.hp = 50.0
			e._afflict(player)
			print("NEWFOES drank=%s" % (e.hp > 50.0))
		e.die(false)
	var burning := _burn > 0.0
	var slowed := _slow > 0.0
	afflict("slow", 3.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var slow_speed := player.walk_speed < 3.0
	var h1 := player.health
	await get_tree().create_timer(1.0).timeout
	print("NEWFOES made=%d hit=%d burning=%s slowed=%s hurts=%s slow_speed=%s" % [made, hit, burning, slowed, player.health < h1, slow_speed])
	get_tree().quit()

## Testing aid: a clearing quest at a ruin keeps sending forms until the count is made, by day.
func debug_questfoes() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var q := quests._story_offer("caravans")
	q.state = "active"
	quests.quests[q.id] = q
	var c: Vector3 = quests.target_of(q)
	player.place(c + Vector3(0, 2.0, 20.0), 0.0)
	var killed := 0
	for i in 60:
		await get_tree().create_timer(1.0).timeout
		for e in enemies.duplicate():
			if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(c) < 70.0:
				e.hurt(99999.0, Vector3.FORWARD)
				killed += 1
		if q.stage > 0:
			break
	print("QUESTFOES cleared=%s killed=%d" % [int(q.stage) > 0, killed])
	get_tree().quit()

## Testing aid: a quest's find shows over its crate, two quests can share one, and a reload takes the marks away.
func debug_questmarks() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var cid: String = crates.keys()[0]
	var mk := func(qid: String) -> Dictionary:
		var q := {"id": qid, "title": "T", "state": "active", "stage": 0, "have": 0,
			"steps": [{"t": "recover", "crate": cid, "item": "keepsake", "text": "x"}, {"t": "reach", "text": "y"}]}
		quests.quests[qid] = q
		quests._place_things(qid)
		return q
	var a: Dictionary = mk.call("qa")
	var b: Dictionary = mk.call("qb")
	var shown: bool = crates[cid].has("mark")
	a.stage = 1
	quests._place_things("qa")
	var kept: bool = crates[cid].has("mark")
	b.stage = 1
	quests._place_things("qb")
	var gone: bool = not crates[cid].has("mark")
	mk.call("qc")
	quests.from_data(quests.to_data().duplicate(true).merged({"quests": {}}, true))
	var reload: bool = not crates[cid].has("mark") and quests.marks.is_empty()
	print("QUESTMARKS shown=%s kept=%s gone=%s reload=%s" % [shown, kept, gone, reload])
	get_tree().quit()

## Testing aid: the end of the road. The main road done opens Lena's crossing; the stair, the boat, the
## hall's answer and the page; the writer's ending is barred until the six leaves are read.
func debug_ending() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var sealed := 0
	for id in crates:
		if crates[id].sealed:
			sealed += 1
	quests.quests.main.stage = quests.quests.main.steps.size()
	quests.quests.main.state = "done"
	quests._finish(quests.quests.main)
	quests.refresh_offers()
	var k := quests._find_offer("gallowmere", "story_ferryway")
	var offered := k >= 0
	if offered:
		quests.rq_accept(Net.me(), "gallowmere", quests.offers.gallowmere[k].id)
	var q: Dictionary = quests.quests.get("story_ferryway", {})
	var barred := not hall.open()
	for o in quests.talk_options("ash_lena"):
		o[1].call()
	await get_tree().create_timer(0.3).timeout
	player.place(hall.stair_top + Vector3(0, 0.5, 0), 0.0)
	await get_tree().create_timer(0.6).timeout
	quests.on_event("move", {"pos": player.global_position})
	await get_tree().create_timer(0.3).timeout
	var at_stair := int(q.stage) == 2
	hall.go_down()
	await get_tree().create_timer(0.8).timeout
	var down := hall.inside(player.global_position) and player.global_position.y > WHall.DEPTH - 1.0
	hall.cross(true)
	await get_tree().create_timer(0.8).timeout
	quests.on_event("move", {"pos": player.global_position})
	await get_tree().create_timer(0.3).timeout
	var crossed := int(q.stage) == 3
	var dark := sun.light_energy == 0.0
	var killed := 0
	for i in 90:
		await get_tree().create_timer(1.0).timeout
		for e in enemies.duplicate():
			if is_instance_valid(e) and e.is_alive() and hall.inside(e.global_position):
				e.hurt(999999.0, Vector3.FORWARD)
				killed += 1
		if int(q.stage) >= 4:
			break
	var held := int(q.stage) == 4
	player.place(hall.page_pos + Vector3(0, 0.6, -2.0), 0.0)
	hall.touch_page()
	await get_tree().create_timer(0.3).timeout
	var leaf7 := flags.has("page_7")
	_rq_ending(Net.me(), "writer")
	var barred_writer := not flags.has("ending")
	ui.close_all()
	_rq_ending(Net.me(), "keeper")
	await get_tree().create_timer(0.5).timeout
	print("ENDING sealed=%d offered=%s barred=%s stair=%s down=%s crossed=%s dark=%s held=%s killed=%d leaf7=%s nowriter=%s ending=%s done=%s" % [sealed, offered, barred, at_stair, down, crossed, dark, held, killed, leaf7, barred_writer, flags.get("ending", ""), flags.has("done_ferryway")])
	hall.go_up()
	await get_tree().create_timer(0.5).timeout
	print("ENDING up=%s" % [not hall.inside(player.global_position)])
	get_tree().quit()

## Testing aid: a far shot takes time to land, and still lands, and a moving foe would have walked on.
func debug_slug() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var at: Vector3 = player.global_position + f * 120.0
	at.y = terrain.height_at(at.x, at.z) + 1.5
	var e := spawn_at("hollow", at)
	e.set_meta("raid", true)
	e.hp = 5000.0
	e.set_physics_process(false)
	await get_tree().create_timer(1.0).timeout
	# From up in the air, so no dune stands between
	var o: Vector3 = e.global_position + Vector3(0, 0.8, 0) - f * 90.0 + Vector3(0, 4.0, 0)
	var aim: Vector3 = (e.global_position + Vector3(0, 0.8, 0) - o).normalized()
	var b := Arms.Slug.new()
	b.arms = player.weapon
	b.gun_id = "pistol"
	b.origin = o
	b.dir = aim
	b.speed = 280.0
	b.left = 200.0
	b.dmg = 20.0
	b.shooter = player
	add_child(b)
	b.global_position = o + aim * Arms.NEAR
	var h0: float = e.hp
	await get_tree().physics_frame
	await get_tree().physics_frame
	var early: bool = e.hp < h0
	# Counted in physics steps: 65 m at 280 m/s is about fourteen of them
	var steps := 0
	while e.hp >= h0 and steps < 120:
		await get_tree().physics_frame
		steps += 1
	print("SLUG early=%s landed=%s flight_ms=%s" % [early, e.hp < h0, steps >= 8])
	get_tree().quit()

## Testing aid: the pack screen fits, whatever is chosen and however big the pack, so its tabs stay in reach.
func debug_packfit() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	for it in ["wood", "scrap", "cloth", "stone", "meat", "shells", "bandage", "coin", "herb", "bone", "roast", "stew", "veil", "bed", "tea", "pie"]:
		inv.add(it, 3)
	var worst := 0.0
	var top := 1e9
	var vp := get_viewport().get_visible_rect().size
	for grow in [0, 12, 24]:
		inv.slots.resize(inv.slots.size() + grow)
		for i in inv.slots.size():
			ui.close_all()
			ui._sel = i
			ui.open_inventory("pack")
			await get_tree().process_frame
			await get_tree().process_frame
			var r: Rect2 = ui._frame.get_global_rect()
			worst = maxf(worst, r.size.y)
			top = minf(top, r.position.y)
	print("PACKFIT fits=%s" % (worst <= 701.0))
	get_tree().quit()

## Testing aid: a picked-clean node far off comes back a share at a time; one beside you does not.
func debug_regrow() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 10.0   # well clear of dawn, which clears foes and refills the land
	var nd0: Dictionary = nodes[0]
	var np0: Vector3 = nd0.pos if nd0.pos is Vector3 else Vector3(nd0.pos.x, 0, nd0.pos.y)
	player.place(np0 + Vector3(5, 1.5, 0), 0.0)
	await get_tree().create_timer(0.5).timeout
	var near_id := 0
	var far_id := -1
	for nd in nodes:
		var np: Vector3 = nd.pos if nd.pos is Vector3 else Vector3(nd.pos.x, 0, nd.pos.y)
		if Vector2(np.x, np.z).distance_to(Vector2(np0.x, np0.z)) > 200.0:
			far_id = nd.id
			break
	_w_node(far_id, 0, day + 5)
	_w_node(near_id, 0, day + 5)
	for i in 200:
		_regrow_t = 0.0
		_regrow_tick(0.0)
		await get_tree().process_frame
	print("REGROW far=%s near_kept=%s seen=%s" % [int(nodes[far_id].charges) > 0, int(nodes[near_id].charges) == 0, nodes[far_id].node.visible])
	get_tree().quit()

## Testing aid: the forms grow with the arms they face.
func debug_power() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var p0 := foe_power()
	var e0 := spawn_at("rusher", player.global_position + Vector3(0, 1.5, -20))
	var h0: float = e0.max_hp
	e0.die(false)
	Game.warms["tier"] = {"shotgun": 3}
	var p1 := foe_power()
	var e1 := spawn_at("rusher", player.global_position + Vector3(0, 1.5, -20))
	var h1: float = e1.max_hp
	e1.die(false)
	Game.warms["tier"] = {}
	print("POWER base=%s grows=%s hp_grows=%s" % [is_equal_approx(p0, 1.0) or p0 < 1.1, p1 > p0 + 0.4, h1 > h0 * 1.3])
	get_tree().quit()

## Testing aid: a ward is worn in its slot and wards its land; taken off it no longer does; an old
## save's gas mask moves from the head to the face.
func debug_wear() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	# Whatever earlier runs left: one veil in the pack, nothing at the neck
	arms.wear.erase("neck")
	inv.take("veil", inv.count("veil"))
	inv.add("veil", 1)
	var before := warded("dunes")
	ui.open_inventory("wear")
	ui._wear("veil")
	var on := warded("dunes") and inv.count("veil") == 0 and str(arms.wear.get("neck", "")) == "veil"
	ui._unwear("neck")
	var off := not warded("dunes") and inv.count("veil") == 1
	var moved := str(WArms.clean({"wear": {"head": "gas_mask"}}).wear.get("face", "")) == "gas_mask"
	ui.close_all()
	print("WEAR before=%s on=%s off=%s moved=%s" % [before, on, off, moved])
	get_tree().quit()

## Testing aid: holding Hasten out in the waste runs faster than walking, and spends breath.
func debug_sprint() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	await get_tree().create_timer(1.0).timeout
	Input.action_press("move_forward")
	await get_tree().create_timer(1.5).timeout
	var walk: float = player.cur_speed
	Input.action_press("run")
	await get_tree().create_timer(1.5).timeout
	var run: float = player.cur_speed
	var st: float = player.stamina
	Input.action_release("run")
	Input.action_release("move_forward")
	print("SPRINT faster=%s spends=%s" % [run > walk * 1.5, st < 100.0])
	get_tree().quit()

## Testing aid: every tab of the pack fits its frame, whatever is chosen.
func debug_tabsfit() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	for it in ["wood", "scrap", "cloth", "stone", "herb", "bone", "hide", "salt", "red_iron", "heartwood"]:
		inv.add(it, 30)
	ui.debug_bench = true
	var worst := {}
	for tab in ["craft", "arms", "wear", "build"]:
		for i in 40:
			ui.close_all()
			ui._rsel = i
			ui.open_inventory(tab)
			await get_tree().process_frame
			await get_tree().process_frame
			var hgt: float = ui._frame.get_global_rect().size.y
			if hgt > float(worst.get(tab, 0.0)):
				worst[tab] = hgt
				if hgt > 701.0:
					print("TALL %s rail=%d sub=%s" % [tab, i, ui._body.get_children().map(func(c): return [c.get_class(), c.get_combined_minimum_size().y])])
	print("TABSFIT %s" % [worst])
	get_tree().quit()

## Testing aid: from every tab of the pack, a click on each other tab goes there.
func debug_tabclick() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	for it in ["wood", "scrap", "cloth", "stone", "herb", "bone", "hide", "salt"]:
		inv.add(it, 30)
	ui.debug_bench = true
	var names := {"pack": "Carried", "wear": "Wear", "craft": "Make", "arms": "Arms", "build": "Build"}
	var bad: Array = []
	for from in names:
		for to in names:
			if to == from:
				continue
			ui.close_all()
			ui.open_inventory(from)
			for i in 3:
				await get_tree().process_frame
			var btn: Button = null
			for b in ui._body.get_child(0).get_children():
				if b is Button and (b as Button).text == names[to]:
					btn = b
			if btn == null:
				bad.append("%s>%s nobutton" % [from, to])
				continue
			var at: Vector2 = get_viewport().get_final_transform() * btn.get_global_rect().get_center()
			var mv := InputEventMouseMotion.new()
			mv.position = at
			mv.global_position = at
			Input.parse_input_event(mv)
			await get_tree().process_frame
			await get_tree().process_frame
			var hov = get_viewport().gui_get_hovered_control()
			for pressed in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = pressed
				ev.position = at
				ev.global_position = at
				Input.parse_input_event(ev)
				await get_tree().process_frame
			await get_tree().process_frame
			if ui._tab != to:
				bad.append("%s>%s" % [from, to])
	print("TABCLICK bad=%s" % [bad])
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
	# Sprinting slowly (a heavy gun, the tar) must still spend breath, not refill it
	var b1 := c.breath
	for i in 10:
		c.pace(true, 0.1)
		c._process(0.1)
	var drains := c.breath < b1
	# A foe running at the cat is stopped by its body
	c.global_position = player.global_position
	var ax := c.global_basis.z.normalized()
	var e := spawn_at("rusher", player.global_position + ax * 4.0 + Vector3(0, 0.5, 0))
	e.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i in 40:
		e.velocity = -ax * 6.0
		e.move_and_slide()
		await get_tree().physics_frame
	var blocked: bool = (e.global_position - player.global_position).dot(ax) > 1.0
	e.queue_free()
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
	print("CAT drains=%s blocked=%s tamed=%s riding=%s faster=%s sprint=%s spent=%s shared=%s followed=%s off=%s back=%s" % [drains, blocked, tamed, riding, walk > player.walk_speed, sprint > walk * 1.5, spent, shared, followed, off, cat != null and cat.cat_name == "Biscuit"])
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
	clock = 10.0   # well clear of dawn, which clears foes and refills the land
	for k in ["idol", "rusher"]:
		var fwd: Vector3 = -player.global_transform.basis.z
		var at := player.global_position + fwd * 12.0
		at.y = terrain.height_at(at.x, at.z) + 0.5
		var e := spawn_at(k, at)
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
	if which == "wear":
		arms.wear["neck"] = "veil"
		arms.wear["eyes"] = "goggles"
		arms.wear["cloak"] = "ember_cloak"
		arms.wear["hands"] = "hide_gloves"
		inv.add("spore_mask", 1)
		ui._wslot = "face"
		rearm()
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
	if which == "fires":
		# A camp at dusk: campfire, cooking station and torches, and the hearth of the start town beyond
		var f := -player.global_transform.basis.z
		f.y = 0.0
		f = f.normalized()
		var r := f.cross(Vector3.UP)
		var base := player.global_position + f * 30.0
		for it in [["campfire", Vector3.ZERO], ["cookpot", r * 3.5], ["torch", -r * 3.0 + f * 1.5], ["torch", r * 2.0 + f * 3.0]]:
			var p: Vector3 = base + it[1]
			p.y = terrain.height_at(p.x, p.z)
			builder._rq_build(1, it[0], p, 0.0)
		var eye: Vector3 = base - f * 6.0 + r * 1.0
		eye.y = terrain.height_at(eye.x, eye.z) + 1.7
		player.place(eye, 0.0)
		var to: Vector3 = base + Vector3(0, terrain.height_at(base.x, base.z) - base.y + 0.6, 0) - eye
		player.yaw = atan2(-to.x, -to.z)
		player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
		player.rotation.y = player.yaw
		player.head.rotation.x = player.pitch
		player.set_physics_process(false)
		clock = 19.6
		hud.visible = false
	if which == "kraken":
		# The whirlpool and the drowned tower, from a boat at its edge
		clock = 16.0
		var at: Vector3 = kraken.spot + Vector3(38, 0, 12)
		_w_boat(77, "sloop", at, 0.0, 420.0)
		player.place(at + Vector3(0, 1.5, 0), 0.0)
		await get_tree().create_timer(4.0).timeout
		player.place(at + Vector3(0, 1.5, 0), 0.0)
		var to: Vector3 = kraken.spot + Vector3(0, 2, 0) - (at + Vector3(0, 2.5, 0))
		player.yaw = atan2(-to.x, -to.z)
		player.rotation.y = player.yaw
		player.pitch = -0.05
		player.head.rotation.x = player.pitch
		player.set_physics_process(false)
		hud.visible = false
	if which == "kin":
		# The kin of the common forms, in a row at noon, standing still
		clock = 12.0
		var f := -player.global_transform.basis.z
		f.y = 0.0
		f = f.normalized()
		var r := f.cross(Vector3.UP)
		var vs: Array = LesserSpeeb.VARIANTS.keys().slice(0, 7)
		for i in vs.size():
			var at: Vector3 = player.global_position + f * 9.0 + r * (i - 3) * 2.6
			at.y = terrain.height_at(at.x, at.z) + 1.0
			var e := spawn_at(vs[i], at)
			e.set_meta("raid", true)
			e.set_physics_process(false)
			e.look_at(player.global_position, Vector3.UP, true)
		player.set_physics_process(false)
		hud.visible = false
	if which == "vault":
		# The first room of a deep vault, looking on toward its gate
		var b8: Vector2 = WPlaces.bpos(8)
		for r in ruins:
			if r.kind == "vault" and not r.has("isle") and Vector2(r.pos.x, r.pos.z).distance_to(b8) >= 200.0:
				vaults.build(r.id)
				var rm: Array = vaults.built[r.id].rooms[1]
				var eye: Vector3 = vaults.at(r.id, -4.0, 1.7, rm[0] - rm[2] + 1.0)
				var look: Vector3 = vaults.at(r.id, 2.0, 1.2, rm[0] + rm[2])
				player.place(eye, 0.0)
				var to := look - eye
				player.yaw = atan2(-to.x, -to.z)
				player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
				player.rotation.y = player.yaw
				player.head.rotation.x = player.pitch
				player.set_physics_process(false)
				clock = 15.0
				hud.visible = false
				break
	if which in ["fleet", "lampeater"]:
		# Far out on open water: the grey ship, or the pale thing risen beside a sloop
		var spot := Vector3.INF
		for k in 72:
			var a := TAU * k / 72.0
			var d := Vector2(cos(a), sin(a))
			d /= maxf(absf(d.x), absf(d.y))
			var q := d * 2700.0
			if terrain.is_water(q.x, q.y, 6.0) and sea.open_water(Vector3(q.x, 0, q.y), 240.0) >= 160.0:
				spot = Vector3(q.x, WIsles.SEA_Y, q.y)
				break
		var look := spot
		deep.paused = true
		if which == "fleet":
			_w_fleet(spot, 0.6, day)
			look = deep.fleet_deck
		else:
			_w_boat(79, "sloop", spot + Vector3(-6, 0, 3), 0.4, 420.0)
			var e = spawn_at("lampeater", spot + Vector3(0, 1.5, 0))
			if e:
				e.set_physics_process(false)
			look = spot + Vector3(0, 1.5, 0)
		var eye := look + Vector3(26, 6, 18) if which == "fleet" else look + Vector3(12, 3.5, 9)
		player.place(eye, 0.0)
		var to := look - eye
		player.yaw = atan2(-to.x, -to.z)
		player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
		player.rotation.y = player.yaw
		player.head.rotation.x = player.pitch
		player.set_physics_process(false)
		clock = 17.0
		hud.visible = false
	if which in ["hall", "hall_shore", "stair"]:
		# The Tenth Hall from where Lena sets you down, its far shore, or the stair-head up in the waste
		var eye: Vector3 = {"hall": hall.at(2.5, 1.7, 16), "hall_shore": hall.at(-6, 1.7, -50), "stair": hall.stair_top + (hall.stair_top - hall.at(0, 0, 0)) * Vector3(1, 0, 1).normalized() * 0.0}[which]
		var look: Vector3 = {"hall": hall.at(0, 1.2, 44), "hall_shore": hall.at(3, 0.5, -30), "stair": hall.stair_top}[which]
		if which == "stair":
			var away := Vector3(look.x - hall.at(0, 0, 0).x, 0, look.z - hall.at(0, 0, 0).z).normalized()
			eye = look + away * 12.0 + Vector3(4, 0, 0)
			eye.y = terrain.height_at(eye.x, eye.z) + 2.5
			look.y += 2.0
		player.place(eye, 0.0)
		var to := look - eye
		player.yaw = atan2(-to.x, -to.z)
		player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
		player.rotation.y = player.yaw
		player.head.rotation.x = player.pitch
		player.set_physics_process(false)
		clock = 15.0
		hud.visible = false
	if which.begins_with("ruin_") or which.begins_with("square_") or which.begins_with("land_"):
		# A close look at a ruin of a kind, a town's square, or a land's own ground cover
		var eye := Vector3.ZERO
		var look := Vector3.ZERO
		if which.begins_with("ruin_"):
			for r in ruins:
				if r.kind == which.substr(5):
					look = r.pos + Vector3(0, 2.0, 0)
					eye = r.pos + Vector3(13, 0, 9)
					break
		elif which.begins_with("square_"):
			var c := gpos(WPlaces.spos(which.substr(7)))
			look = c + Vector3(0, 1.0, 0)
			eye = c + Vector3(7, 0, 12)
		else:
			var rr := RandomNumberGenerator.new()
			rr.seed = 5
			for t in 4000:
				var q := Vector2(rr.randf_range(-900, 900), rr.randf_range(-900, 900))
				if terrain.biome_name(q.x, q.y) == which.substr(5) and terrain.weights(q.x, q.y)[WTerrain.BIOMES.find(which.substr(5))] > 0.9 and _clear_of_places(q, 80.0, 30.0):
					eye = gpos(q)
					look = gpos(q + Vector2(30, 20)) + Vector3(0, 1.0, 0)
					break
		eye.y = terrain.height_at(eye.x, eye.z) + (6.0 if which.begins_with("ruin_") else 3.0)
		player.place(eye, 0.0)
		var to := look - eye
		player.yaw = atan2(-to.x, -to.z)
		player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
		player.rotation.y = player.yaw
		player.head.rotation.x = player.pitch
		player.set_physics_process(false)
		clock = 15.0
		hud.visible = false
	match which:
		"pack", "craft", "arms", "build", "wear":
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
		"say":
			hud.say("There is smoke to the east. Find shelter before nightfall.", 60.0)
			player.weapon.debug_aim = true
		"town", "inn":
			var tk := "cinderwick"
			var c := gpos(WPlaces.spos(tk))
			var inn_b: Dictionary = _town_plan(tk)[0]
			var ib := c + Vector3(inn_b.off.x, 0, inn_b.off.y)
			var eye := c + (ib - c) * (-0.25) if which == "town" else ib + (c - ib).normalized() * 1.5
			if which == "inn":
				eye = ib + (c - ib).normalized() * 0.8
			eye.y = terrain.height_at(eye.x, eye.z) + 0.5
			var to := ib - eye
			if which == "inn":
				to = -to
				eye = ib + (c - ib).normalized() * 1.6
				eye.y = terrain.height_at(eye.x, eye.z) + 0.5
				to = ib - eye
			player.place(eye, atan2(-to.x, -to.z))
		"coast", "hrafn", "fen", "kala", "cog":
			var il: Dictionary = terrain.isles[0]
			for i2 in terrain.isles:
				if i2.key == which:
					il = i2
			var c2: Vector2 = il.c
			var eye: Vector3
			var look: Vector3
			if which == "coast":
				# Walk out from the middle toward the isle until the ground meets the sea
				var dir2 := c2 / maxf(absf(c2.x), absf(c2.y))
				var at2 := dir2 * 1700.0
				for k2 in 400:
					at2 = dir2 * (1700.0 + k2 * 2.0)
					if terrain.height_at(at2.x, at2.y) < WIsles.SEA_Y + 2.0:
						break
				eye = Vector3(at2.x, terrain.height_at(at2.x, at2.y) + 6.0, at2.y) - Vector3(dir2.x, 0, dir2.y) * 30.0
				look = Vector3(c2.x, WIsles.SEA_Y + 20.0, c2.y)
			else:
				var hp2: Vector2 = terrain.isle_heart(il)
				var out2 := (hp2 - c2).normalized() if hp2 != c2 else Vector2(1, 0)
				var at3: Vector2 = c2 + out2 * float(il.r) * 1.6
				eye = Vector3(at3.x, WIsles.SEA_Y + 45.0, at3.y)
				look = Vector3(c2.x, terrain.height_at(c2.x, c2.y), c2.y)
			player.place(eye, 0.0)
			var to3 := look - eye
			player.yaw = atan2(-to3.x, -to3.z)
			player.pitch = atan2(to3.y, Vector2(to3.x, to3.z).length())
			player.rotation.y = player.yaw
			player.head.rotation.x = player.pitch
			player.set_physics_process(false)
		"hrafn_in", "fen_in", "kala_in", "cog_in", "pier_in":
			# Close over an isle, from its landing side, without the HUD
			var key2 := which.substr(0, which.length() - 3)
			var il: Dictionary = terrain.isles[0]
			for i2 in terrain.isles:
				if i2.key == key2:
					il = i2
			var hp2: Vector2 = terrain.isle_heart(il)
			var toward2: Vector2 = -Vector2(il.c).normalized()
			var at4: Vector2 = hp2 + toward2 * 80.0 + Vector2(toward2.y, -toward2.x) * 30.0
			var look2 := Vector3(hp2.x, terrain.height_at(hp2.x, hp2.y) + 4.0, hp2.y)
			if key2 == "pier":
				var s2: Vector2 = Vector2(il.c)
				for k2 in 400:
					s2 = Vector2(il.c) + toward2 * k2 * 2.0
					if terrain.height_at(s2.x, s2.y) < WIsles.SEA_Y - 0.3:
						break
				at4 = s2 + toward2 * 30.0 + Vector2(toward2.y, -toward2.x) * 25.0
				look2 = Vector3(s2.x, WIsles.SEA_Y + 2.0, s2.y) + Vector3(toward2.x, 0, toward2.y) * 8.0
			var eye2 := Vector3(at4.x, maxf(terrain.height_at(at4.x, at4.y), WIsles.SEA_Y) + (8.0 if key2 == "pier" else 28.0), at4.y)
			player.place(eye2, 0.0)
			var to4 := look2 - eye2
			player.yaw = atan2(-to4.x, -to4.z)
			player.pitch = atan2(to4.y, Vector2(to4.x, to4.z).length())
			player.rotation.y = player.yaw
			player.head.rotation.x = player.pitch
			player.set_physics_process(false)
			clock = 16.5
			hud.visible = false
		"over_cinderwick", "over_hesk", "over_kiln", "over_lanternwell":
			var c := gpos(WPlaces.spos(which.substr(5)))
			var eye := c + Vector3(34, 0, 34)
			eye.y = terrain.height_at(eye.x, eye.z) + 22.0
			player.place(eye, atan2(-(c.x - eye.x), -(c.z - eye.z)))
			player.pitch = -0.5
			player.head.rotation.x = -0.5
			player.rotation.y = player.yaw
			player.set_physics_process(false)
		"house", "house_in":
			_debug_house(which == "house_in")
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
		"rider":
			# A friend astride their cat, as others see them
			var c := WCat.new().setup(null, "floofspeeb", false)
			c.barding = "bone_barding"
			c.ridden = true
			c.puppet = true
			var holder := Node3D.new()
			add_child(holder)
			holder.add_child(c)
			var fig := Figure.new().setup(Figure.seeded(7))
			fig.seated = true
			fig.position.y = 0.38
			holder.add_child(fig)
			var f := -player.global_transform.basis.z
			f.y = 0.0
			var at := player.global_position + f.normalized() * 3.5
			holder.global_position = gpos(Vector2(at.x, at.z))
			holder.rotation.y = player.yaw + PI * 0.55
			c._refresh()
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
		for i in 40:
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


## Meals and rest: three meals add health and breath, a fourth waits, they wear off; a snug sleep rests you.
func debug_meals() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	inv.from_data([])
	meals.clear()
	_meal_stats()
	food = 30.0
	var hp0 := player.max_health
	var st0: float = player.stamina_max
	for id in ["roast", "tea", "stew", "broth", "pie"]:
		inv.add(id, 2)
	eat("roast")
	var hp_up := player.max_health >= hp0 + 19.0
	eat("tea")
	var st_up: bool = player.stamina_max >= st0 + 29.0
	eat("stew")
	var three := meals.size() == 3
	food = 30.0
	eat("pie")
	var held := meals.size() == 3 and not meals.has("pie")
	meals["tea"][0] = 10.0
	eat("pie")
	var swapped := meals.has("pie") and not meals.has("tea") and meals.size() == 3
	for k in meals:
		meals[k][0] = 0.5
	await get_tree().create_timer(1.5).timeout
	var worn := meals.is_empty() and absf(player.max_health - hp0) < 0.5 and absf(player.stamina_max - st0) < 0.5
	var c_open := comfort(player.global_position + Vector3(400, 0, 400))
	rested = 0.0
	var xp0 := skills.xp + skills.level * 100000
	award("kill")
	var plain := skills.xp + skills.level * 100000 - xp0
	nap()
	await get_tree().create_timer(5.0).timeout
	var rest_on := rested > 0.0
	xp0 = skills.xp + skills.level * 100000
	award("kill")
	var more := skills.xp + skills.level * 100000 - xp0 > plain
	var d := char_data()
	rested = 0.0
	apply_char(d)
	print("MEALS hp=%s stam=%s three=%s held=%s swapped=%s worn=%s comfort=%d rested=%s xp=%s saved=%s" % [hp_up, st_up, three, held, swapped, worn, c_open, rest_on, more, rested > 0.0])
	get_tree().quit()


## Lands that ask for gear: foes are stronger in harder lands, a land's hardship bites until its ward is
## carried, and its own stuff comes from its nodes.
func debug_lands() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	inv.from_data([])
	var home := player.global_position
	var spot := {}
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 6000:
		var p := Vector3(r.randf_range(-1800, 1800), 0, r.randf_range(-1800, 1800))
		var bn := land_at(p)
		if not spot.has(bn) and not gentle_at(p) and Vector2(p.x, p.z).distance_to(WPlaces.start) > 1300.0 and settlement_at(p, 30.0) == "" and base_at(p, 0.0, true) < 0 and terrain.biome_name(p.x + 30, p.z + 30) == bn:
			spot[bn] = gpos(Vector2(p.x, p.z))
	var a = spawn_at("rusher", gpos(WPlaces.start) + Vector3(0, 2, 0))
	var b = spawn_at("rusher", spot["basalt"] + Vector3(0, 2, 0))
	var harder: bool = b.max_hp > a.max_hp * 2.0
	a.die(false)
	b.die(false)
	player.place(spot["forest"] + Vector3(0, 0.5, 0), 0.0)
	await get_tree().create_timer(1.0).timeout
	arms.wear.erase("face")
	var h0 := player.health
	await get_tree().create_timer(6.0).timeout
	var bites := player.health < h0
	arms.wear["face"] = "spore_mask"
	h0 = player.health
	await get_tree().create_timer(6.0).timeout
	var warded_ok := player.health >= h0
	var stuff := 0
	for nd in nodes:
		if nd.kind == "scrap" and land_at(nd.pos) == "dunes":
			var before := inv.count("red_iron")
			for k in 30:
				nodes[nd.id].charges = 3
				_rq_gather(Net.me(), nd.id)
			await get_tree().create_timer(0.5).timeout
			stuff = inv.count("red_iron") - before
			break
	player.place(home, 0.0)
	await get_tree().create_timer(1.0).timeout
	autosave_soon(0.1)
	await get_tree().create_timer(1.0).timeout
	print("LANDS tiers=%d harder=%s bites=%s warded=%s stuff=%s" % [spot.size(), harder, bites, warded_ok, stuff > 0])
	get_tree().quit()



## A small house ahead of the player, for pictures and the house check: two floors' worth of cells, timber,
## stone and iron walls, a doorway with a door, a window, and furniture inside. Returns the piece ids by role.
func _debug_house(inside := false) -> Dictionary:
	var G := WBuilder.GRID
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var c0 := player.global_position + f * 11.0
	var ci := floori(c0.x / G)
	var cj := floori(c0.z / G)
	var out := {}
	for d in [[0, 0], [1, 0]]:
		var b := builder._cell_base(ci + d[0], cj + d[1])
		builder._rq_build(1, "floor", Vector3((ci + d[0] + 0.5) * G, b, (cj + 0.5) * G), 0.0)
	var base: float = builder._floor_top(ci, cj)
	# Edges: the far side (z = cj), the near side (z = cj + 1), and the two ends
	var walls := [
		["wall", Vector3((ci + 0.5) * G, base, cj * G), 0.0, 0], ["window", Vector3((ci + 1.5) * G, base, cj * G), 0.0, 1],
		["doorway", Vector3((ci + 0.5) * G, base, (cj + 1) * G), 0.0, 0], ["window", Vector3((ci + 1.5) * G, base, (cj + 1) * G), 0.0, 0],
		["wall", Vector3(ci * G, base, (cj + 0.5) * G), PI * 0.5, 1], ["wall", Vector3((ci + 2) * G, base, (cj + 0.5) * G), PI * 0.5, 2],
	]
	for wl in walls:
		builder._rq_build(1, wl[0], wl[1], wl[2])
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		for wl in walls:
			if pc.kind == wl[0] and pc.pos.distance_to(wl[1]) < 0.1 and wl[3] > 0:
				builder._w_tier(pid, wl[3], 500.0)
		if pc.kind == "doorway":
			out.doorway = pid
		if pc.kind == "wall" and pc.pos.distance_to(walls[0][1]) < 0.1:
			out.wall = pid
	builder._rq_build(1, "door", pieces[out.doorway].pos, 0.0)
	var mid := Vector3((ci + 1) * G, base, (cj + 0.5) * G)
	builder._rq_build(1, "bed", mid + Vector3(1.6, 0, -0.6), 0.0)
	builder._rq_build(1, "table", mid + Vector3(-1.0, 0, -0.5), 0.0)
	builder._rq_build(1, "chair", mid + Vector3(-1.0, 0, 0.4), PI)
	builder._rq_build(1, "shelf", mid + Vector3(-2.4, 0, -0.9), 0.0)
	builder._rq_build(1, "stove", mid + Vector3(0.4, 0, -1.0), 0.0)
	builder._rq_build(1, "rug", mid + Vector3(0.0, 0.02, 0.4), 0.0)
	builder._rq_build(1, "floorlamp", mid + Vector3(2.5, 0, 1.0), 0.0)
	var eye := mid + Vector3(-2.2, 0.4, 1.0) if inside else mid + Vector3(1.5, 0, G * 3.0)
	if not inside:
		eye.y = maxf(terrain.height_at(eye.x, eye.z), base) + 0.4
	var to := mid + (Vector3(1.6, 0, -0.6) if inside else Vector3.ZERO) - eye
	player.place(eye, atan2(-to.x, -to.z))
	return out


## Building up and furniture: a wall goes timber to stone to iron and keeps it through a save; a bed is a
## bedroll, a stove a cooking station that burns, a shelf a chest; a furnished house is snug.
func debug_build() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	var ids := _debug_house(true)
	await get_tree().create_timer(0.5).timeout
	var wp: int = ids.wall
	var hp0: float = pieces[wp].hp
	var t0 := int(pieces[wp].get("tier", 0))
	builder._rq_tier(1, wp, t0 + 1)
	await get_tree().create_timer(0.3).timeout
	var up := int(pieces[wp].get("tier", 0)) == t0 + 1 and float(pieces[wp].hp) > hp0
	var d := world_data()
	builder._w_piece_gone(wp)
	builder._w_piece(wp, d.pieces[wp][0], d.pieces[wp][1], d.pieces[wp][2], d.pieces[wp][3])
	if int(d.pieces[wp][5].get("tier", 0)) > 0:
		builder._w_tier(wp, int(d.pieces[wp][5].tier), float(d.pieces[wp][3]))
	var kept := int(pieces[wp].get("tier", 0)) == t0 + 1
	var bed := builder.near_kind(player.global_position, "bedroll", 8.0)
	var pot := builder.near_pid(player.global_position, "cookpot", 8.0)
	var stove: bool = pot >= 0 and pieces[pot].kind == "stove" and burning(pot)
	var shelf := false
	for pid in pieces:
		if pieces[pid].kind == "shelf" and containers.has("p%d" % pid):
			shelf = true
	var snug := comfort(player.global_position)
	print("BUILD up=%s kept=%s bed=%s stove=%s shelf=%s snug=%s" % [up, kept, bed, stove, shelf, snug >= 4])
	get_tree().quit()


## Towns: every town has an inn and houses; the inn sells a meal, tells of a ruin, and rents its snug beds;
## a house's wall stops you, and its doorway lets you in.
func debug_inn() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	inv.from_data([])
	var inns := 0
	var houses := 0
	for k in WPlaces.SETTLEMENTS:
		for b in _town_plan(k):
			if b.kind == "inn":
				inns += 1
			else:
				houses += 1
	var all_inns := inns == WPlaces.SETTLEMENTS.size() and houses >= WPlaces.SETTLEMENTS.size() * 3
	inv.add("salt", 20)
	inn_meal()
	var meal := false
	for id in INN_MEALS:
		if inv.count(id) > 0:
			meal = true
	meal = meal and inv.count("salt") == 14
	var known0 := known_ruins.size()
	inn_talk("cinderwick")
	var talk := known_ruins.size() == known0 + 1
	var snug := false
	for ib in inn_beds:
		if comfort(ib) == 8:
			snug = true
	# A ray across a house from its front, at chest height: it meets the wall, unless through the doorway
	var c := gpos(WPlaces.spos("cinderwick"))
	var plan := _town_plan("cinderwick")
	var hb: Dictionary = {}
	for b in plan:
		if b.kind == "house":
			hb = b
	var hc := c + Vector3(hb.off.x, 0, hb.off.y)
	var bas := Basis(Vector3.UP, float(hb.yaw))
	var front := bas * Vector3(0, 0, 1)
	var side := bas * Vector3(1, 0, 0)
	var G := WBuilder.GRID
	var W := float(hb.w) * G
	var door_x := -W * 0.5 + (int(hb.w) / 2 + 0.5) * G
	var wall_x := -W * 0.5 + 0.5 * G
	var space := get_world_3d().direct_space_state
	var y := terrain.height_at(hc.x, hc.z) + 1.2
	var hc2 := Vector3(hc.x, y, hc.z)
	var door_r := PhysicsRayQueryParameters3D.create(hc2 + front * 8.0 + side * door_x, hc2 + side * door_x, 1)
	var wall_r := PhysicsRayQueryParameters3D.create(hc2 + Vector3(0, 1.5, 0) + front * 8.0 + side * wall_x, hc2 + Vector3(0, 1.5, 0) + side * wall_x, 1)
	var dh := space.intersect_ray(door_r)
	var wh := space.intersect_ray(wall_r)
	var walls := dh.is_empty() and not wh.is_empty()
	print("INN towns=%s meal=%s talk=%s snug=%s walls=%s" % [all_inns, meal, talk, snug, walls])
	get_tree().quit()


## Playtest fixes: the map's picture is ready before the map is first opened; a great one does not rise
## when a pilgrim walks into its ring, only when called out at its stone.
func debug_fixes() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var t0 := Time.get_ticks_msec()
	while ui._map_img == null and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().create_timer(0.2).timeout
	var t1 := Time.get_ticks_msec()
	ui.open_map()
	var open_ms := Time.get_ticks_msec() - t1
	ui.close_all()
	var l: Dictionary = lairs[0]
	flags.erase("lair_" + str(l.id))
	player.place(l.pos + Vector3(8, 1.0, 0), 0.0)
	for i in 6:
		_lair_tick()
		await get_tree().create_timer(0.3).timeout
	var slept: bool = _lair_boss.get(l.id) == null
	_rq_lair_call(l.id)
	_lair_tick()
	var woke: bool = _lair_boss.get(l.id) != null
	print("FIXES map_ready=%s map_open_fast=%s slept=%s woke=%s" % [ui._map_tex != null, open_ms < 400, slept, woke])
	get_tree().quit()


## Testing aid: the Grey Sea and its isles are there, the sea holds a swimmer up and tires them,
## and nothing rises out of open water.
func debug_sea() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	var dry := 0
	for il in terrain.isles:
		var hp: Vector2 = terrain.isle_heart(il)
		if terrain.height_at(hp.x, hp.y) > WIsles.SEA_Y + 1.0:
			dry += 1
	var isle_nodes := nodes.filter(func(nd): return maxf(absf(nd.node.position.x), absf(nd.node.position.z)) > WPlaces.HALF).size()
	var isle_ruins := ruins.filter(func(r): return r.has("isle")).size()
	# Out between the coast and the first isle
	var il0: Dictionary = terrain.isles[0]
	var c0: Vector2 = il0.c
	var mid := c0 / maxf(absf(c0.x), absf(c0.y)) * (WPlaces.HALF + 60.0)
	var open := terrain.is_water(mid.x, mid.y, 5.0)
	print("SEA isles=%d dry=%d nodes=%d ruins=%d open=%s name=%s isle_name=%s" % [terrain.isles.size(), dry, isle_nodes, isle_ruins, open, terrain.region_name(mid.x, mid.y), terrain.region_name(terrain.isle_heart(il0).x, terrain.isle_heart(il0).y)])
	player.place(Vector3(mid.x, WIsles.SEA_Y + 0.5, mid.y), 0.0)
	await get_tree().create_timer(4.0).timeout
	var y: float = player.global_position.y
	var st0: float = player.stamina
	print("SEA swimming=%s afloat=%s y=%.1f" % [player.swimming, absf(y - (WIsles.SEA_Y - 1.3)) < 1.2, y])
	await get_tree().create_timer(3.0).timeout
	print("SEA tires=%s" % [player.stamina < st0])
	var e := _spawn_one("rusher", player.global_position, 4.0, 20.0)
	print("SEA spawn_in_water=%s" % [e != null])
	get_tree().quit()


## Testing aid: a raft is launched from the shore, boarded, paddled out and stepped off; a sloop
## with the book runs under sail; a wrecked boat throws its crew in the water.
func debug_boat() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var il0: Dictionary = terrain.isles[0]
	var c0: Vector2 = il0.c
	var dir2 := c0 / maxf(absf(c0.x), absf(c0.y))
	var shore := dir2 * 1700.0
	for k in 600:
		shore = dir2 * (1700.0 + k * 1.0)
		if terrain.height_at(shore.x, shore.y) < WIsles.SEA_Y + 0.6:
			break
	player.place(gpos(shore - dir2 * 3.0) + Vector3(0, 0.3, 0), 0.0)
	await get_tree().create_timer(1.0).timeout
	inv.add("raft", 1)
	var launched := launch_boat("raft")
	await get_tree().create_timer(0.5).timeout
	var b: WBoat = boats.values()[0] if not boats.is_empty() else null
	print("BOAT launched=%s boats=%d left_pack=%d" % [launched, boats.size(), inv.count("raft")])
	if b == null:
		get_tree().quit()
		return
	boat_used(b)
	await get_tree().create_timer(0.5).timeout
	print("BOAT aboard=%s helm=%s" % [player.vessel == b, b.pilot() == Net.me()])
	# Face out to sea and paddle
	b.yaw = atan2(dir2.x, dir2.y)
	var p0 := b.global_position
	Input.action_press("move_forward")
	await get_tree().create_timer(4.0).timeout
	Input.action_release("move_forward")
	var moved := b.global_position.distance_to(p0)
	print("BOAT moved=%.1f carried=%s" % [moved, player.global_position.distance_to(b.global_position) < 3.0])
	boat_used(b)
	await get_tree().create_timer(0.5).timeout
	print("BOAT off=%s riders=%d" % [player.vessel == null, b.riders.size()])
	# A sloop wants its book; under full sail before the wind it runs fast
	var known_before := flags.has("book_ship")
	flags["book_ship"] = true
	_w_boat(99, "sloop", b.global_position + Vector3(dir2.x, 0, dir2.y) * 12.0, atan2(dir2.x, dir2.y), 420.0)
	var s: WBoat = boats[99]
	boat_used(s)
	await get_tree().create_timer(0.3).timeout
	sea.wind = 1.0
	sea.wind_ang = atan2(dir2.y, dir2.x)
	Input.action_press("move_forward")
	await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame
	Input.action_press("move_forward")
	await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().create_timer(6.0).timeout
	print("BOAT sail=%d sloop_speed=%.1f book_gated=%s" % [s.sail, s.speed, not known_before])
	hurt_boat(s, 9999.0)
	await get_tree().create_timer(0.5).timeout
	print("BOAT wrecked=%s thrown=%s" % [not boats.has(99), player.vessel == null])
	get_tree().quit()



## Testing aid: the seasons set the length of the night; salt frost bites the thinly dressed by
## night away from a fire, and an ash storm chokes one with an uncovered face.
func debug_weather() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var frost_day := 1 + WWeather.SEASON_DAYS * 3
	day = frost_day
	var long_night := weather.dusk() < 19.0 and weather.dawn() > 6.0
	day = 1
	var thaw := weather.dusk() == 20.0
	day = frost_day
	clock = 23.0
	night = true
	# Out in the open, well past the gentle lands about the start
	for r in ruins:
		if Vector2(r.pos.x, r.pos.z).distance_to(WPlaces.start) > 700.0 and not r.has("isle") and settlement_at(r.pos, 60.0) == "":
			player.global_position = r.pos + Vector3(20, 0.5, 0)
			player.global_position.y = terrain.height_at(player.global_position.x, player.global_position.z) + 0.5
			break
	await get_tree().create_timer(0.5).timeout
	arms.wear = {}
	_w_weather("frost", 600.0, 0.0)
	weather.k = 1.0
	var cold := weather.hardship(player.global_position) != ""
	arms.wear = {"body": "fur_coat"}
	var warm := weather.hardship(player.global_position) == ""
	arms.wear = {}
	_w_weather("ashstorm", 600.0, 0.0)
	weather.k = 1.0
	var choke := weather.hardship(player.global_position) != ""
	arms.wear = {"neck": "scarf"}
	var covered := weather.hardship(player.global_position) == ""
	arms.wear = {}
	player.health = 100.0
	weather._hurt_t = 0.0
	await get_tree().create_timer(0.3).timeout
	var hurt := player.health < 100.0
	var swell := sea.swell
	print("WEATHER long_night=%s thaw=%s cold=%s warm=%s choke=%s covered=%s hurt=%s label=%s" % [long_night, thaw, cold, warm, choke, covered, hurt, weather.label()])
	_w_weather("gale", 600.0, 0.0)
	weather.k = 1.0
	await get_tree().create_timer(0.2).timeout
	print("WEATHER gale_swell=%s" % [sea.swell > swell])
	get_tree().quit()


## Testing aid: an isle's heart keeps its book; the waste's ruins turn up the Shipwright's Folio
## first; reading teaches a recipe; a known book cannot be read twice.
func debug_books() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	# Start from a fellowship that has read nothing (earlier checks may have read some)
	for bk in Items.LAND_BOOKS + Items.ISLE_BOOKS.values():
		flags.erase(bk)
		flags.erase("found_" + bk)
	var cid := "isle_hrafn_0"
	containers.erase(cid)
	_rq_open(Net.me(), cid)
	await get_tree().create_timer(0.3).timeout
	var bag := Inventory.new(14)
	bag.from_data(containers.get(cid, {}))
	var isle_book := bag.count("book_saga") == 1
	var rr := RandomNumberGenerator.new()
	rr.seed = 5
	var first := ""
	for i in 200:
		first = _book_for("r3_0", rr)
		if first != "":
			break
	var hidden := not _recipe_shown("sloop")
	inv.add("book_ship", 1)
	var read := read_book("book_ship")
	await get_tree().create_timer(0.2).timeout
	var shown := _recipe_shown("sloop")
	inv.add("book_ship", 1)
	var again := read_book("book_ship")
	print("BOOKS isle=%s first=%s hidden=%s read=%s shown=%s again=%s" % [isle_book, first, hidden, read, shown, again])
	get_tree().quit()


func _recipe_shown(id: String) -> bool:
	for r in Items.RECIPES:
		if r.id == id and (not r.has("needs") or flags.has(r.needs)):
			return true
	return false


## Testing aid: far out on open water a Grey Wyrm comes up after a boat, and its bites hurt the boat.
## Testing aid: the deep. A lit sloop far out at night draws the Lamp-Eater; a doused one does not;
## the grey ship comes, can be boarded, its watch stands up, and it is gone at dawn.
func debug_deep() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	player.max_health = 100000.0
	player.health = 100000.0
	var spot := Vector3.INF
	for k in 72:
		var a := TAU * k / 72.0
		var d := Vector2(cos(a), sin(a))
		d /= maxf(absf(d.x), absf(d.y))
		var q := d * 2700.0
		var p := Vector3(q.x, WIsles.SEA_Y, q.y)
		if terrain.is_water(p.x, p.z, 6.0) and sea.open_water(p, 240.0) >= 160.0:
			spot = p
			break
	if spot == Vector3.INF:
		print("DEEP no open water")
		get_tree().quit()
		return
	_w_boat(78, "sloop", spot, 0.0, 420.0)
	var b: WBoat = boats[78]
	player.place(spot + Vector3(0, 1, 0), 0.0)
	boat_used(b)
	await get_tree().create_timer(0.5).timeout
	night = true
	nights = 3
	weather.kind = "clear"
	# Doused: nothing comes
	_w_boat_lamp(78, false)
	for i in 40:
		deep._lamp_watch()
	var dark_safe := not enemies.any(func(x): return is_instance_valid(x) and x.is_alive() and x.kind == "lampeater")
	_w_boat_lamp(78, true)
	var rose := false
	for i in 80:
		deep._lamp_watch()
		if enemies.any(func(x): return is_instance_valid(x) and x.is_alive() and x.kind == "lampeater"):
			rose = true
			break
	for i in 200:
		deep._fleet_watch()
		if is_instance_valid(deep.fleet):
			break
		deep._fleet_night = -1
	await get_tree().create_timer(1.0).timeout
	var sailed := is_instance_valid(deep.fleet)
	var crate := sailed and crates.has(deep.fleet_crate)
	if sailed:
		deep.board()
	await get_tree().create_timer(1.0).timeout
	var aboard := sailed and player.global_position.distance_to(deep.fleet_deck) < 3.0 and player.vessel == null
	deep._crew_watch()
	var crew := enemies.filter(func(x): return is_instance_valid(x) and x.is_alive() and x.kind in ["vigil", "saltbone", "warden"] and x.global_position.distance_to(deep.fleet_deck) < 15.0).size()
	await get_tree().create_timer(2.0).timeout
	var stood := player.global_position.y > deep.fleet_deck.y - 2.0 if sailed else false
	night = false
	deep._t = 0.0
	deep.host_tick(0.1)
	await get_tree().create_timer(0.5).timeout
	var gone := not is_instance_valid(deep.fleet) and not crates.has("fleet_%d" % day)
	var eater_gone := not enemies.any(func(x): return is_instance_valid(x) and x.is_alive() and x.kind == "lampeater")
	print("DEEP dark_safe=%s rose=%s sailed=%s crate=%s aboard=%s crew=%d stood=%s gone=%s eater_gone=%s" % [dark_safe, rose, sailed, crate, aboard, crew, stood, gone, eater_gone])
	get_tree().quit()


## Testing aid: a deep vault. Down the stair, each room wakes and its gate opens when quiet; the keeper's
## fall gives a share, brings you up, and the vault sleeps for days.
func debug_vault() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var id := ""
	var count := 0
	var b8: Vector2 = WPlaces.bpos(8)
	for r in ruins:
		if r.kind == "vault" and not r.has("isle") and Vector2(r.pos.x, r.pos.z).distance_to(b8) >= 200.0:
			count += 1
			if id == "":
				id = r.id
	vaults.go_down(id)
	await get_tree().create_timer(1.0).timeout
	var down := vaults.inside(id, player.global_position)
	var rooms: int = vaults.built[id].rooms.size() if vaults.built.has(id) else 0
	var coins := inv.count("coin")
	var gates := 0
	for i in 240:
		await get_tree().create_timer(0.5).timeout
		var st: Dictionary = vaults.state.get(id, {})
		if vaults.built.has(id) and not st.is_empty():
			# Walk on to the next room once its gate is open
			var rm: Array = vaults.built[id].rooms[mini(int(st.room), rooms - 1)]
			if player.global_position.distance_to(vaults.at(id, 0, 1.0, rm[0])) > 4.0:
				player.place(vaults.at(id, 0, 1.0, rm[0]), 0.0)
			gates = int(flags.get("vault_open_" + id, gates))
		for e in enemies.duplicate():
			if is_instance_valid(e) and e.is_alive() and vaults.inside(id, e.global_position) and i % 4 == 3:
				e.hurt(999999.0, Vector3.FORWARD)
		if flags.has("vault_done_" + id):
			break
	await get_tree().create_timer(1.5).timeout
	var cleared := flags.has("vault_done_" + id)
	var share := inv.count("coin") > coins
	var up := not hall.inside(player.global_position)
	vaults.go_down(id)
	await get_tree().create_timer(0.5).timeout
	var sleeps := not hall.inside(player.global_position)
	print("VAULT count=%d down=%s rooms=%d gates=%d cleared=%s share=%s up=%s sleeps=%s" % [count, down, rooms, gates, cleared, share, up, sleeps])
	get_tree().quit()


## Testing aid: where the cast-out wake is always the Ash Plains and the gentlest, and it grows harder going out.
func debug_home() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var st: Vector2 = WPlaces.start
	var ash := 0
	var n := 0
	for k in 64:
		var a := k * TAU / 64.0
		for rd in [0.0, 120.0, 250.0, 330.0]:
			var q: Vector2 = st + Vector2(cos(a), sin(a)) * rd
			n += 1
			if terrain.biome_name(q.x, q.y) == "ash":
				ash += 1
	var forms_ok := true
	for k in 20:
		var q := st + Vector2(randf_range(-300, 300), randf_range(-300, 300))
		for f in forms_at(Vector3(q.x, 0, q.y)):
			if not f in GENTLE_FORMS:
				forms_ok = false
	var tiers := []
	for rd in [100.0, 700.0, 1300.0, 1900.0]:
		var q: Vector2 = st + (Vector2.ZERO - st).normalized() * rd if st.length() > 1.0 else Vector2(rd, 0)
		tiers.append(tier_at(Vector3(q.x, 0, q.y)))
	var kinds := {}
	for k in 400:
		var q := Vector2(randf_range(-1700, 1700), randf_range(-1700, 1700))
		kinds[terrain.biome_name(q.x, q.y)] = true
	# No land sends a form beyond its danger; the worst only far out
	var tiered := true
	var worst := {}
	for k in 600:
		var q := Vector3(randf_range(-2600, 2600), 0, randf_range(-2600, 2600))
		var t := tier_at(q)
		for f in forms_at(q):
			if int(LesserSpeeb.FORM_TIER.get(f, 1)) > t:
				tiered = false
			worst[f] = mini(int(worst.get(f, 9)), t)
	print("HOME gen=%d ash=%d/%d gentle_forms=%s tiers=%s lands=%d tiered=%s knight_from=%d" % [world_gen, ash, n, forms_ok, tiers, kinds.size(), tiered, int(worst.get("knight", 0))])
	get_tree().quit()


## Testing aid: the new blades strike as they should, and the flamethrower burns a crowd.
func debug_newarms() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var wpn: Arms = player.weapon
	var out := {}
	for id in ["knife", "sword", "battle_axe", "glaive"]:
		arms.blades.append(id)
		arms.melee = id
		rearm()
		wpn.draw_blade()
		await get_tree().create_timer(0.3).timeout
		# Three in a row before the pilgrim: the wide swing takes them all, the narrow one fewer
		var foes := []
		var f: Vector3 = -player.global_transform.basis.z
		var side: Vector3 = player.global_transform.basis.x
		for k in 3:
			var e := spawn_at("rusher", player.global_position + f * 2.0 + side * (k - 1) * 1.3 + Vector3(0, 0.5, 0))
			e._attack_cd = 99.0
			e.hp = 2000.0
			e.set_meta("raid", true)
			foes.append(e)
		await get_tree().create_timer(0.3).timeout
		player.stamina = 100.0
		wpn._melee_cool = 0.0
		wpn._swing = 0.0
		wpn.strike(false)
		await get_tree().create_timer(0.8).timeout
		var hit := 0
		var most := 0.0
		for e in foes:
			if not is_instance_valid(e):
				continue
			if 2000.0 - e.hp > 0.5:
				hit += 1
			most = maxf(most, 2000.0 - e.hp)
			e.die(false)
		out[id] = [hit, int(most)]
	# The flamethrower: a crowd before it burns, and the ground is left alight
	arms.owned.append("flamer")
	arms.primary = "flamer"
	rearm()
	wpn.draw_gun(0)
	await get_tree().create_timer(0.6).timeout
	var crowd := []
	var fw: Vector3 = -player.global_transform.basis.z
	for k in 4:
		var e := spawn_at("rusher", player.global_position + fw * (4.0 + k * 1.2) + player.global_transform.basis.x * (k % 2 - 0.5) + Vector3(0, 0.5, 0))
		e._attack_cd = 99.0
		e.hp = 2000.0
		e.set_meta("raid", true)
		crowd.append(e)
	await get_tree().create_timer(0.3).timeout
	player.pitch = -0.05
	for k in 30:
		wpn._cool = 0.0
		wpn._try_fire()
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	var burnt := 0
	for e in crowd:
		if is_instance_valid(e) and 2000.0 - e.hp > 20.0:
			burnt += 1
	var jets := 0
	for c in get_children():
		if c is CPUParticles3D and c.one_shot:
			jets += 1
	var fuel_ok: bool = Items.AMMO.get("flamer", "") == "fuel" and Items.DB.has("fuel")
	print("NEWARMS knife=%s sword=%s axe=%s glaive=%s flamer_burnt=%d/4 jets=%s fuel=%s" % [out.knife, out.sword, out.battle_axe, out.glaive, burnt, jets > 0, fuel_ok])
	get_tree().quit()


## Testing aid: the playtest menu opens, jumps to each land, and its tools work.
func debug_dev() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	ui.open_dev()
	await get_tree().process_frame
	var opened: bool = ui._panel_name == "dev"
	var buttons: int = ui._body.find_children("*", "Button", true, false).size()
	ui.close_all()
	var reached := 0
	for l in WDev.LANDS:
		var at: Vector3 = dev.spot_in(l[0])
		if at == Vector3.INF:
			continue
		dev.go(at)
		await get_tree().create_timer(0.3).timeout
		if land_at(player.global_position) == l[0]:
			reached += 1
	dev.god = true
	var hp: float = player.health
	damage_player(50.0, player.global_position + Vector3(2, 0, 0))
	var unharmed: bool = player.health >= hp
	dev.god = false
	var spawned := dev.spawn_tier(4)
	await get_tree().create_timer(0.5).timeout
	var killed := dev.kill_near()
	dev.give_arms()
	var all_arms: bool = arms.owned.size() == ArmsDB.GUNS.size() and arms.blades.size() == ArmsDB.MELEE.size()
	dev.toggle_fast()
	_needs_tick(0.01)
	var fast: bool = player.run_speed > 9.0
	dev.toggle_fast()
	dev.set_hour(0.5)
	print("DEV opened=%s buttons=%d lands=%d/6 unharmed=%s spawned=%d killed=%d all_arms=%s fast=%s where=%s" % [opened, buttons, reached, unharmed, spawned, killed, all_arms, fast, dev.where()])
	get_tree().quit()


## Testing aid: tasting, brewing and drinking, and the draughts' effects.
func debug_brew() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	for id in WAlchemy.INGREDIENTS:
		inv.add(id, 4)
	inv.add("salt", 20)
	var first := alchemy.taste("herb")
	var again := alchemy.taste("herb")
	var third := alchemy.taste("herb")
	var sour := alchemy.brew("herb", "bone")
	var got := alchemy.brew("bone", "tar")
	var have: int = inv.count("brew_keen")
	var learned: bool = alchemy.knows("tar", "keen") and alchemy.knows("bone", "keen")
	var dm0: float = player.weapon.damage_mult
	alchemy.drink("brew_keen")
	var dm1: float = player.weapon.damage_mult
	alchemy.brew("salt_crystal", "bone")
	alchemy.drink("brew_ward")
	player.health = player.max_health
	var h0: float = player.health
	damage_player(40.0, player.global_position + Vector3(3, 0, 0))
	var warded: float = h0 - player.health
	alchemy.active.erase("ward")
	player.health = player.max_health
	damage_player(40.0, player.global_position + Vector3(3, 0, 0))
	var bare: float = player.max_health - player.health
	alchemy.brew("tar", "heartwood")
	alchemy.drink("brew_fireskin")
	_burn = 0.0
	afflict("burn", 5.0)
	var fireproof: bool = _burn <= 0.0
	var kept: Dictionary = char_data().brews
	alchemy.from_data(JSON.parse_string(JSON.stringify(kept)))
	ui.open_brew()
	await get_tree().process_frame
	var panel_ok: bool = ui._panel_name == "brew"
	ui.close_all()
	print("BREW first=%s again=%s third=%s sour=%s got=%s have=%d learned=%s keener=%s ward=%s fireproof=%s kept=%s panel=%s" % [first, again, third, sour == "", got, have, learned, dm1 > dm0 * 1.1, warded < bare * 0.85, fireproof, alchemy.knows("tar", "keen") and alchemy.on("keen"), panel_ok])
	get_tree().quit()


## Testing aid: dread rises in the open dark, slower by lantern, falls by a fire, and draws things.
func debug_dread() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	player.max_health = 100000.0
	player.health = 100000.0
	var spot: Vector3 = dev.spot_in("salt")
	dev.go(spot)
	await get_tree().create_timer(0.5).timeout
	dev.set_hour(0.5)
	await get_tree().create_timer(2.0).timeout
	dread.level = 0.0
	dread.local_tick(30.0)
	var dark: float = dread.level
	player.relics.lantern_lit = true
	dread.level = 0.0
	dread.local_tick(30.0)
	var lamp: float = dread.level
	player.relics.lantern_lit = false
	var before := enemies.size()
	dread.level = 90.0
	dread._t = 0.0
	dread.local_tick(0.1)
	await get_tree().create_timer(0.5).timeout
	var drawn: bool = enemies.size() > before
	builder._rq_build(1, "campfire", gpos(Vector2(player.global_position.x + 2.0, player.global_position.z)), 0.0)
	await get_tree().create_timer(0.3).timeout
	for pid in pieces:
		if pieces[pid].kind == "campfire":
			add_wood(pid)
	dread.level = 80.0
	dread.local_tick(10.0)
	var fire: float = dread.level
	night = false
	dread.local_tick(30.0)
	print("DREAD dark=%.0f lamp=%.0f drawn=%s by_fire=%.0f day=%.0f" % [dark, lamp, drawn, fire, dread.level])
	get_tree().quit()


## Testing aid: a snug base with spare beds draws settlers, who bring goods and keep fires.
## Testing aid: the frame meter shows numbers.
func debug_meter() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	dev.toggle_meter()
	await get_tree().create_timer(2.0).timeout
	print("METER shown=%s text=%s" % [dev._meter.visible, dev._meter.text.replace("\n", " | ")])
	get_tree().quit()


## Testing aid: the thirteen forms of the far lands. Each stands up with its name and way; then the ways
## themselves: a band comes with its singer, a Flicker goes and comes back, a vent wakes when near, a husk
## splits, a thief robs and gives back, ravens blind, rime freezes, a heavy blow breaks glass, the hidden
## cannot be struck, and a stampede fades.
func debug_newforms() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	dev.god = true
	dev.go(dev.spot_in("ash"))
	await get_tree().create_timer(0.5).timeout
	var pp: Vector3 = player.global_position
	var made := 0
	var named := 0
	for i in WDev.NEW_FORMS.size():
		var k: String = WDev.NEW_FORMS[i]
		var a := TAU * i / WDev.NEW_FORMS.size()
		var e = spawn_at(k, gpos(Vector2(pp.x + cos(a) * 60.0, pp.z + sin(a) * 60.0)) + Vector3(0, 1, 0))
		if e and is_instance_valid(e) and e.is_alive():
			made += 1
			if e._name_l == null or e._name_l.text.contains(str(LesserSpeeb.VARIANTS[k].name)):
				named += 1
	await get_tree().create_timer(0.6).timeout
	var choirs := 0
	for e in enemies:
		if is_instance_valid(e) and e.is_alive() and e.variant == "dust_choir":
			choirs += 1
	dev.kill_near()
	await get_tree().create_timer(0.3).timeout
	# The Flicker: hunting, it goes out of the world and comes back
	var f = spawn_at("flicker", pp + Vector3(6, 1, 0))
	await get_tree().create_timer(0.2).timeout
	f.mind = "hunt"
	f.set_meta("trait_t", 0.05)
	await get_tree().create_timer(0.3).timeout
	var went: bool = f.hidden
	var struck_hidden: bool = f.hurt(10.0, Vector3.FORWARD)
	await get_tree().create_timer(2.6).timeout
	var back: bool = not f.hidden and f.is_alive()
	f.die(false)
	# The Geyser Wight: in the ground until you are near, then steam
	var g = spawn_at("geyser_wight", pp + Vector3(20, 1, 0))
	await get_tree().create_timer(0.3).timeout
	var vent_hid: bool = g.hidden
	g.global_position = pp + Vector3(5, 1, 0)
	await get_tree().create_timer(0.3).timeout
	var vent_up: bool = not g.hidden
	g.die(false)
	# The Glass Husk: slain, two more; a blunt blow bites harder than a blade
	var h = spawn_at("glass_husk", pp + Vector3(0, 1, 12))
	await get_tree().create_timer(0.2).timeout
	h.max_hp = 100000.0
	h.hp = h.max_hp
	LesserSpeeb.harm_kind = "blade"
	h.hurt(100.0, Vector3.FORWARD)
	var by_blade: float = h.max_hp - h.hp
	h.hp = h.max_hp
	LesserSpeeb.harm_kind = "blunt"
	h.hurt(100.0, Vector3.FORWARD)
	var by_blunt: float = h.max_hp - h.hp
	LesserSpeeb.harm_kind = ""
	var before := enemies.filter(func(o): return is_instance_valid(o) and o.is_alive() and o.variant == "glass_husk").size()
	h.die(true)
	await get_tree().create_timer(0.5).timeout
	var shards := enemies.filter(func(o): return is_instance_valid(o) and o.is_alive() and o.variant == "glass_husk" and o.has_meta("shard")).size()
	dev.kill_near()
	# The Archivist's Hand: a quarter of the rounds, back when it falls
	var gun: String = player.weapon.gun()
	var ammo_id: String = Items.AMMO.get(gun, "")
	var robbed := 0
	var returned := false
	if ammo_id != "":
		inv.add(ammo_id, 40)
		var had := inv.count(ammo_id)
		var t = spawn_at("archivist_hand", pp + Vector3(3, 1, 0))
		await get_tree().create_timer(0.2).timeout
		FoeTraits.on_bite(t, player)
		robbed = had - inv.count(ammo_id)
		var fled: bool = t.mind == "flee"
		t.die(true)
		returned = fled and inv.count(ammo_id) == had
	# Ravens and rime
	_w_afflict("blind", 1.0)
	_w_afflict("freeze", 1.0)
	var blinded := _blind > 0.0
	var frozen := _freeze > 0.0
	# The Herd Ghost: it fades when its time is out
	var hg = spawn_at("herd_ghost", pp + Vector3(30, 1, 0))
	await get_tree().create_timer(0.3).timeout
	hg.mind = "hunt"
	hg.set_meta("life", 0.1)
	await get_tree().create_timer(0.5).timeout
	var faded: bool = not is_instance_valid(hg) or not hg.is_alive()
	dev.kill_near()
	print("NEWFORMS made=%d/13 named=%d choir_band=%d" % [made, named, choirs])
	print("NEWFORMS flicker went=%s struck_hidden=%s back=%s vent_hid=%s vent_up=%s" % [went, struck_hidden, back, vent_hid, vent_up])
	print("NEWFORMS husk blunt>blade=%s shards=%d before=%d robbed=%d returned=%s blinded=%s frozen=%s faded=%s" % [by_blunt > by_blade * 1.5, shards, before, robbed, returned, blinded, frozen, faded])
	get_tree().quit()


## Testing aid: a fellowship of one to eight. The waste sends more and harder forms for more pilgrims,
## and never more than it can carry; a bed is given, kept and freed; the longboat seats eight.
func debug_crowd() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	dev.god = true
	WCrowd.fake = 1
	var one := WCrowd.scale(self, 10)
	var hp1 := WCrowd.hp(self)
	dev.go(dev.spot_in("ash"))
	await get_tree().create_timer(0.5).timeout
	var a = spawn_at("rusher", player.global_position + Vector3(25, 1, 0))
	var a_hp: float = a.max_hp
	a.die(false)
	WCrowd.fake = 4
	var four := WCrowd.scale(self, 10)
	WCrowd.fake = 8
	var eight := WCrowd.scale(self, 10)
	var b = spawn_at("rusher", player.global_position + Vector3(25, 1, 0))
	var b_hp: float = b.max_hp
	b.die(false)
	var boss8 := WCrowd.boss(self)
	# The cap: past it, nothing more is woken
	for k in WCrowd.ALIVE_CAP + 5:
		var e = spawn_at("mite", player.global_position + Vector3(randf_range(30, 50), 1, randf_range(30, 50)))
		e.process_mode = Node.PROCESS_MODE_DISABLED
	var capped := _spawn_near("rusher", player.global_position, 30.0, 40.0, true) == null
	dev.kill_near()
	WCrowd.fake = 0
	await get_tree().create_timer(0.3).timeout
	# A bed: given to me, then to another, then freed
	var bp := player.global_position + Vector3(4, 0, 0)
	builder._w_piece(900, "bed", bp, 0.0, 160.0)
	var me := bed_name()
	_rq_bed_owner(900, me, Net.me())
	var mine := bed_owner(900) == me and bedroll is Vector3 and respawn_point().distance_to(bp) < 3.0
	var saved: bool = str(world_data().pieces[900][5].get("owner", "")) == me
	_rq_bed_owner(900, "Wren", Net.me())
	var given := bed_owner(900) == "Wren" and not bed_mine_or_free(900) and respawn_point().distance_to(bp) > 5.0
	pieces[900].owner = "Wren"
	_rq_bed_owner(900, "", 99)   # not Wren's, and not the host's own call: refused when online, so try as host
	_rq_bed_owner(900, "", Net.me())
	var freed := bed_owner(900) == ""
	var label: String = (pieces[900].node.get_meta("bed_label") as Label3D).text if pieces[900].node.has_meta("bed_label") else "?"
	# The longboat
	var lb_seats := int(WBoat.KINDS.longboat.seats) == 8 and WBoat.SEATS.longboat.size() == 8
	var recipe := Items.RECIPES.any(func(r): return r.id == "longboat")
	print("CROWD one=%d four=%d eight=%d hp1=%.2f hp_up=%s boss8=%.2f capped=%s" % [one, four, eight, hp1, b_hp > a_hp * 1.3, boss8, capped])
	print("CROWD bed mine=%s saved=%s given=%s freed=%s label='%s'" % [mine, saved, given, freed, label])
	print("CROWD longboat seats=%s recipe=%s max=%d trials=%d" % [lb_seats, recipe, Net.MAX_PLAYERS, Net.MAX_TRIALS])
	get_tree().quit()


## Testing aid: the last two endings. Ruth found and talked to, a beacon put out for her; the journal's
## leaves; the Second Vow's harder forms; and no night wave after the Unlit ending.
func debug_endings() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	dev.god = true
	var found := endings.ruth != null and is_instance_valid(endings.ruth)
	var biome: String = terrain.biome_name(endings.ruth_at.x, endings.ruth_at.z) if found else ""
	var early := endings.talk()
	var asked_early := flags.has("ruth_met")
	if not 0 in lit:
		lit.append(0)
	_light_beacon(0, true)
	endings.talk()
	var met := flags.has("ruth_met")
	player.place(beacon_nodes[0].pos + Vector3(0, 2, 6), 0.0)
	await get_tree().create_timer(0.5).timeout
	var out := endings.put_out_near()
	var pact := flags.has("unlit_pact") and not 0 in lit
	var first := endings.next_leaf()
	for k in 9:
		flags["jpage_%d" % (k + 1)] = true
	for k in 6:
		flags["page_%d" % (k + 1)] = true
	var pilgrim_open := endings.can_pilgrim()
	dev.go(dev.spot_in("ash"))
	await get_tree().create_timer(0.5).timeout
	var a = spawn_at("rusher", player.global_position + Vector3(20, 0, 0))
	var hp_a: float = a.max_hp
	a.die(false)
	_w_ending("pilgrim", Net.me())
	var b = spawn_at("rusher", player.global_position + Vector3(20, 0, 0))
	var ratio: float = b.max_hp / hp_a
	b.die(false)
	flags["ending"] = "unlit"
	dev.kill_near()
	await get_tree().create_timer(0.5).timeout
	night = true
	var n0 := alive_count()
	for i in 5:
		_night_wave()
	var quiet := alive_count() == n0
	print("ENDINGS ruth=%s forest=%s early_refused=%s met=%s out=%d pact=%s first=%s pilgrim_open=%s vow=%s harder=%.2f unlit_quiet=%s" % [found, biome == "forest", not asked_early and early != "", met, out, pact, first, pilgrim_open, flags.has("second_vow"), ratio, quiet])
	get_tree().quit()


## Testing aid: trades. Only a smith makes tempered steel; changing trade wants a town and coin;
## the cook's extra, the tinker's ammunition, the alchemist's double draught and the smith's cheaper arms.
func debug_trades() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	for it in [["scrap", 40], ["red_iron", 6], ["coin", 40], ["salt", 30], ["herb", 4], ["heartwood", 4]]:
		inv.add(it[0], it[1])
	var rec := func(id: String) -> Dictionary:
		for r in Items.RECIPES:
			if r.id == id and r.has("trade"):
				return r
		return {}
	var tm: Dictionary = rec.call("tempered")
	var before := inv.count("tempered")
	ui._make(tm)
	var untrained := inv.count("tempered") - before
	var first := trades.choose("smith")
	ui._make(tm)
	var smithed := inv.count("tempered") - before
	var sword_full: int = int(WArms.MAKE.sword.scrap)
	var sword_smith: int = int(ui._acost(WArms.MAKE.sword).scrap)
	dev.go(dev.spot_in("ash"))
	await get_tree().create_timer(0.5).timeout
	var away := trades.refusal("tinker") != ""
	var sk: String = WPlaces.SETTLEMENTS.keys()[0]
	dev.go(Vector3(WPlaces.spos(sk).x, 0, WPlaces.spos(sk).y))
	await get_tree().create_timer(0.5).timeout
	var coin0 := inv.count("coin")
	var changed := trades.choose("tinker")
	var paid := coin0 - inv.count("coin")
	var r0 := inv.count("rounds")
	for r in Items.RECIPES:
		if r.id == "rounds" and not r.bench:
			ui._make(r)
	var tink := inv.count("rounds") - r0
	trades.trade = "alchemist"
	var m0 := inv.count("brew_mend")
	alchemy.brew("herb", "heartwood")
	var two := inv.count("brew_mend") - m0
	var kept = char_data().trade
	trades.from_data(kept)
	print("TRADES untrained=%d first=%s smithed=%d sword=%d/%d away_refused=%s changed=%s paid=%d tinker_rounds=%d alch_brews=%d kept=%s" % [untrained, first, smithed, sword_smith, sword_full, away, changed, paid, tink, two, trades.trade])
	get_tree().quit()


## Testing aid: calling a spirit-cat, its bites, the relic going cold and kindling again.
func debug_spirit() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	dev.god = true
	dev.set_hour(12.0)
	dev.go(dev.spot_in("ash"))
	await get_tree().create_timer(1.0).timeout
	inv.add("spirit_ember", 1)
	var came := spirits.summon("spirit_ember")
	var again := spirits.refusal("spirit_ember") != ""
	var e = _spawn_near("rusher", player.global_position, 8.0, 10.0, true)
	await get_tree().process_frame
	var hp0: float = e.hp if e and is_instance_valid(e) else 0.0
	await get_tree().create_timer(6.0).timeout
	var bitten: bool = hp0 > 0.0 and (not is_instance_valid(e) or not e.is_alive() or e.hp < hp0)
	var left := spirits.time_left()
	spirits.cat.life = 0.0
	await get_tree().create_timer(2.0).timeout
	var faded := spirits.cat == null or not is_instance_valid(spirits.cat)
	var kept: Dictionary = char_data().spirits
	spirits.from_data(JSON.parse_string(JSON.stringify(kept)))
	var cold := spirits.is_spent("spirit_ember")
	spirits.rekindle()
	var warm := not spirits.is_spent("spirit_ember")
	var sk: String = WPlaces.SETTLEMENTS.keys()[0]
	dev.go(Vector3(WPlaces.spos(sk).x, 0, WPlaces.spos(sk).y))
	await get_tree().create_timer(0.5).timeout
	var town := spirits.refusal("spirit_ember") != ""
	print("SPIRIT came=%s again_refused=%s bitten=%s left=%d faded=%s cold=%s warm=%s town_refused=%s" % [came, again, bitten, int(left), faded, cold, warm, town])
	get_tree().quit()


func debug_settlers() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var c: Vector3 = player.global_position + Vector3(12, 0, 0)
	var put := func(kind: String, off: Vector3):
		builder._rq_build(1, kind, gpos(Vector2(c.x + off.x, c.z + off.z)), 0.0)
	put.call("campfire", Vector3.ZERO)
	put.call("bedroll", Vector3(2.5, 0, 0))
	put.call("bedroll", Vector3(-2.5, 0, 0))
	put.call("bedroll", Vector3(0, 0, 2.5))
	put.call("torch", Vector3(0, 0, -3))
	put.call("chest", Vector3(3, 0, 3))
	await get_tree().create_timer(0.5).timeout
	var fire := -1
	for pid in pieces:
		if pieces[pid].kind == "campfire":
			fire = pid
	inv.add("wood", 10)
	add_wood(fire)
	var snug := comfort(pieces[fire].pos)
	var room := settlers.room_at(fire)
	settlers.host_dawn(1.0)
	settlers.host_dawn(1.0)
	settlers.host_dawn(1.0)
	var n := settlers.at_fire(fire).size()
	var shown := settlers._nodes.size()
	# Make sure one brings goods, then a dawn of work
	settlers.list[0].job = "salter"
	var cid: String = settlers.chests_at(fire)[0]
	var before := _cont_count(cid, "salt")
	settlers.host_dawn(0.0)
	var brought := _cont_count(cid, "salt") - before
	var kept: Array = world_data().settlers
	settlers.from_data(JSON.parse_string(JSON.stringify(kept)))
	var reloaded := settlers.list.size() == n and settlers._nodes.size() == n
	pieces[fire].fuel = world_hours() - 1.0
	settlers.host_dawn(0.0)
	print("SETTLERS snug=%d room=%s came=%d shown=%d brought=%d reloaded=%s gone=%s" % [snug, room, n, shown, brought, reloaded, settlers.list.is_empty()])
	get_tree().quit()


## Testing aid: every kin of the common forms rises with its own name, numbers and colour, and
## a joiner's copy of it is the same kin.
func debug_kin() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var ok := 0
	var bad := []
	var copies := 0
	for v in LesserSpeeb.VARIANTS.keys().filter(func(x): return LesserSpeeb.VARIANTS[x].base != "serpent"):
		var at := player.global_position + Vector3(randf_range(-15, 15), 0, randf_range(20, 30))
		at.y = terrain.height_at(at.x, at.z) + 1.0
		var e := spawn_at(v, at)
		await get_tree().process_frame
		var spec_ok: bool = e.variant == v and e.spec.name == LesserSpeeb.VARIANTS[v].name and e.kind == LesserSpeeb.VARIANTS[v].base
		var tinted := false
		for g in e.find_children("*", "GeometryInstance3D", true, false):
			if (g as GeometryInstance3D).material_overlay != null:
				tinted = true
		var st: Array = e.net_state()
		var copy := LesserSpeeb.new().setup(st[2], st[1], self)
		if copy.variant == v:
			copies += 1
		copy.free()
		if spec_ok and tinted and int(LesserSpeeb.FORM_TIER.get(v, 0)) > 0:
			ok += 1
		else:
			bad.append(v)
		e.die(false)
	var in_lands := 0
	for v in LesserSpeeb.VARIANTS.keys().filter(func(x): return LesserSpeeb.VARIANTS[x].base != "serpent"):
		for b in BIOME_FORMS:
			if v in BIOME_FORMS[b]:
				in_lands += 1
				break
	print("KIN made=%d/%d copies=%d in_lands=%d bad=%s kinds=%d" % [ok, LesserSpeeb.VARIANTS.size() - 1, copies, in_lands, bad, LesserSpeeb.KINDS.size() - 2 + LesserSpeeb.VARIANTS.size()])
	get_tree().quit()


## Testing aid: the Kraken-Bell's whirlpool draws a boat in, the Bell-Wound rises, and its fall
## leaves the tower's chest and a trophy.
func debug_kraken() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	player.max_health = 100000.0
	player.health = 100000.0
	var found := kraken.spot != Vector3.INF
	if not found:
		print("KRAKEN found=false")
		get_tree().quit()
		return
	var start: Vector3 = kraken.spot + Vector3(70, 0, 0)
	_w_boat(79, "sloop", start, 0.0, 420.0)
	var b: WBoat = boats[79]
	player.place(start + Vector3(0, 1, 0), 0.0)
	boat_used(b)
	await get_tree().create_timer(0.5).timeout
	var d0: float = Vector2(b.global_position.x, b.global_position.z).distance_to(Vector2(kraken.spot.x, kraken.spot.z))
	for i in 60:
		kraken.local_tick(0.1)
	var d1: float = Vector2(b.global_position.x, b.global_position.z).distance_to(Vector2(kraken.spot.x, kraken.spot.z))
	b.global_position = kraken.spot + Vector3(25, 0, 0)
	await get_tree().create_timer(0.3).timeout
	kraken.host_tick()
	var rose: bool = kraken.beast != null and is_instance_valid(kraken.beast) and kraken.beast.variant == "bellwound"
	var hp: float = kraken.beast.max_hp if rose else 0.0
	if rose:
		var e = kraken.beast
		e.hurt(99999.0, Vector3.FORWARD)
	await get_tree().create_timer(0.5).timeout
	var chest: bool = crates.has("kraken_%d" % day)
	var trophy: int = inv.count("t_kraken")
	kraken.host_tick()
	var again: bool = kraken.beast != null
	print("KRAKEN found=%s pulled=%s rose=%s hp=%d chest=%s trophy=%d stays_down=%s" % [found, d1 < d0 - 5.0, rose, int(hp), chest, trophy, not again])
	get_tree().quit()


func debug_serpent() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var spot := Vector3.INF
	for k in 72:
		var a := TAU * k / 72.0
		var d := Vector2(cos(a), sin(a))
		d /= maxf(absf(d.x), absf(d.y))
		var q := d * 2700.0
		var p := Vector3(q.x, WIsles.SEA_Y, q.y)
		if terrain.is_water(p.x, p.z, 6.0) and sea.open_water(p, 240.0) >= 160.0:
			spot = p
			break
	print("SERPENT open_water_found=%s" % [spot != Vector3.INF])
	if spot == Vector3.INF:
		get_tree().quit()
		return
	_w_boat(77, "sloop", spot, 0.0, 420.0)
	var b: WBoat = boats[77]
	player.place(spot + Vector3(0, 1, 0), 0.0)
	boat_used(b)
	await get_tree().create_timer(0.5).timeout
	var e = null
	for i in 80:
		_serpent_watch()
		var found := enemies.filter(func(x): return is_instance_valid(x) and x.is_alive() and x.kind == "serpent")
		if not found.is_empty():
			e = found[0]
			break
	print("SERPENT rose=%s" % [e != null])
	var t0 := Time.get_ticks_msec()
	while b.hp >= 420.0 and Time.get_ticks_msec() - t0 < 25000 and is_instance_valid(b):
		await get_tree().create_timer(0.5).timeout
	print("SERPENT boat_hurt=%s" % [not is_instance_valid(b) or b.hp < 420.0])
	get_tree().quit()


## Testing aid (two machines): the host launches a raft and takes the helm, a friend climbs aboard,
## and the friend is carried as the host paddles.
func debug_boat_host() -> void:
	while not ready_world or avatars.is_empty():
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	var il0: Dictionary = terrain.isles[0]
	var c0: Vector2 = il0.c
	var dir2 := c0 / maxf(absf(c0.x), absf(c0.y))
	var shore := dir2 * 1700.0
	for k in 600:
		shore = dir2 * (1700.0 + k * 1.0)
		if terrain.height_at(shore.x, shore.y) < WIsles.SEA_Y + 0.6:
			break
	player.place(gpos(shore - dir2 * 3.0) + Vector3(0, 0.3, 0), 0.0)
	await get_tree().create_timer(1.0).timeout
	inv.add("raft", 1)
	launch_boat("raft")
	await get_tree().create_timer(0.5).timeout
	var b: WBoat = boats.values()[0]
	b.yaw = atan2(dir2.x, dir2.y)
	boat_used(b)
	var t0 := Time.get_ticks_msec()
	while b.riders.size() < 2 and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().create_timer(0.5).timeout
	print("HOSTBOAT riders=%d" % b.riders.size())
	await get_tree().create_timer(1.0).timeout
	Input.action_press("move_forward")
	await get_tree().create_timer(5.0).timeout
	Input.action_release("move_forward")
	await get_tree().create_timer(10.0).timeout
	print("HOSTBOAT done")
	get_tree().quit()


func debug_boat_join() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var t0 := Time.get_ticks_msec()
	while boats.is_empty() and Time.get_ticks_msec() - t0 < 40000:
		await get_tree().create_timer(0.5).timeout
	if boats.is_empty():
		print("JOINBOAT no boat")
		get_tree().quit()
		return
	var b: WBoat = boats.values()[0]
	await get_tree().create_timer(1.5).timeout
	player.global_position = b.global_position + Vector3(0, 1.0, 0)
	boat_used(b)
	var t1 := Time.get_ticks_msec()
	while player.vessel != b and Time.get_ticks_msec() - t1 < 10000:
		await get_tree().create_timer(0.25).timeout
	var p0 := b.global_position
	print("JOINBOAT aboard=%s seat=%s same=%s vessel=%s riders=%s me=%s" % [player.vessel == b, b.riders.get(Net.me(), -1), boats.values()[0] == b, player.vessel, b.riders, Net.me()])
	await get_tree().create_timer(5.0).timeout
	print("JOINBOAT carried=%s moved=%.1f" % [player.global_position.distance_to(b.global_position) < 3.0, b.global_position.distance_to(p0)])
	get_tree().quit()


func debug_great() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	nights = 5
	var warn2 := nights_to_great()
	nights = 6
	print("GREAT seventh=%s warn=%d tonight=%d" % [great_night(7) and not great_night(6), warn2, nights_to_great()])
	clock = 22.0
	night = true
	player.place(gpos(WPlaces.spos("cinderwick") + Vector2(300, 0)), 0.0)
	await get_tree().create_timer(1.0).timeout
	_great_raid()
	await get_tree().create_timer(30.0).timeout
	var n := enemies.filter(func(e): return is_instance_valid(e) and e.is_alive() and e.has_meta("great")).size()
	print("GREAT spawned=%d alive=%d" % [int(great.get("spawned", 0)), n])
	for e in enemies:
		if is_instance_valid(e) and e.is_alive() and e.has_meta("great"):
			e.die(false)
	await get_tree().create_timer(0.5).timeout
	var salt0 := inv.count("salt")
	_great_dawn()
	await get_tree().create_timer(0.5).timeout
	print("GREAT spoils=%s" % [inv.count("salt") > salt0])
	get_tree().quit()


func debug_powers() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	flags.erase("shrine_t_basalt")
	power = ""
	power_left = 0.0
	var at := player.global_position + Vector3(4, 0, 0)
	builder._rq_build(1, "shrine", at, 0.0)
	await get_tree().create_timer(0.5).timeout
	var built := false
	var spid := -1
	for pid in pieces:
		if pieces[pid].kind == "shrine":
			built = true
			spid = pid
	inv.add("t_basalt", 1)
	ui.open_shrine(spid)
	await get_tree().create_timer(0.3).timeout
	ui.close_all()
	take_power("t_basalt")
	var refused := not power_is("gilt")
	lay_trophy("t_basalt")
	await get_tree().create_timer(0.3).timeout
	take_power("t_basalt")
	ui.open_shrine(spid)
	await get_tree().create_timer(0.3).timeout
	ui.close_all()
	var hp0 := player.health
	damage_player(20.0, player.global_position + Vector3(8, 0, 0))
	var with := hp0 - player.health
	player.health = hp0
	power_left = 0.01
	await get_tree().create_timer(0.3).timeout
	damage_player(20.0, player.global_position + Vector3(8, 0, 0))
	var without := hp0 - player.health
	player.health = player.max_health
	print("POWERS built=%s refused=%s laid=%s lighter=%s ended=%s" % [built, refused, flags.has("shrine_t_basalt"), with < without - 0.1, power == ""])
	get_tree().quit()


## Every tale's places, chests, people and rewards are real, and its words read cleanly.
func debug_tales() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var bad: Array = []
	var ruin_ids := {}
	for r in ruins:
		ruin_ids[r.id] = true
	for sid in WQuests.STORIES:
		var st: Dictionary = WQuests.STORIES[sid]
		if not WPlaces.PEOPLE.has(st.giver):
			bad.append("%s giver" % sid)
		if "<dir" in WPlaces.words(st.pitch):
			bad.append("%s pitch" % sid)
		if st.has("after") and not (str(st.after).begins_with("done_") or str(st.after) in ["oilcraft"]):
			bad.append("%s after" % sid)
		if str(st.get("after", "")).begins_with("done_") and str(st.after) != "done_main" and not WQuests.STORIES.has(str(st.after).substr(5)):
			bad.append("%s after-tale" % sid)
		for s in st.steps:
			if "<dir" in WPlaces.words(s.text) or (s.has("say") and "<dir" in WPlaces.words(s.say)):
				bad.append("%s words" % sid)
			if s.has("crate") and not crates.has(s.crate):
				bad.append("%s crate %s" % [sid, s.crate])
			if s.has("ruin") and not ruin_ids.has(s.ruin) and not str(s.ruin) in ["lake_stair", "tenth_shore", "tenth_hall", "tenth_page"]:
				bad.append("%s ruin %s" % [sid, s.ruin])
			if s.has("who") and not WPlaces.PEOPLE.has(s.who):
				bad.append("%s who %s" % [sid, s.who])
			if s.has("item") and not (Items.DB.has(s.item) or WArms.WEAR.has(s.item)):
				bad.append("%s item %s" % [sid, s.item])
		for it in st.reward.get("items", []):
			if not (Items.DB.has(it[0]) or WArms.WEAR.has(it[0])):
				bad.append("%s reward %s" % [sid, it[0]])
	var told := 0
	for r in ruins:
		if WPlaces.ruin_story(str(r.id), str(r.kind)) != "":
			told += 1
	print("TALES bad=%s told=%d/%d" % [bad, told, ruins.size()])
	get_tree().quit()


## Testing aid: walks the whole world and works every system a while, so script errors show up.
## Run it twice on one save to check loading what it saved.
func debug_soak() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var t0 := Time.get_ticks_msec()
	var step := func(name: String): print("SOAK %s %.0fs" % [name, (Time.get_ticks_msec() - t0) / 1000.0])
	for it in [["wood", 60], ["scrap", 40], ["cloth", 20], ["stone", 40], ["shells", 60], ["bandage", 4], ["raft", 1], ["sloop", 1], ["t_ash", 1], ["t_salt", 1]]:
		inv.add(it[0], it[1])
	flags["book_ship"] = true
	ui.debug_bench = true
	# Every panel, here at the start
	for tab in ["pack", "wear", "craft", "arms", "build"]:
		ui.open_inventory(tab)
		await get_tree().process_frame
	for f in [ui.open_map, ui.open_journal, ui.open_skills, ui.open_travel]:
		ui.close_all()
		f.call()
		await get_tree().create_timer(0.3).timeout
	ui.close_all()
	step.call("panels")
	# Talk to everyone, and take what work is offered
	quests.refresh_offers()
	await get_tree().create_timer(0.5).timeout
	for pid in WPlaces.PEOPLE:
		ui.open_dialogue(pid)
		await get_tree().process_frame
		ui.close_all()
	for k in quests.offers:
		for o in quests.offers[k]:
			if quests.active().size() < WQuests.MAX_ACTIVE:
				quests.accept(o)
	await get_tree().create_timer(0.5).timeout
	step.call("people active=%d" % quests.active().size())
	# Every town, every isle, the coast and the open sea, a little while each, by day
	clock = 11.0
	var spots: Array = []
	for k in WPlaces.SETTLEMENTS:
		spots.append(WPlaces.spos(k) + Vector2(50, 0))
	for r in ruins.slice(0, 12):
		spots.append(Vector2(r.pos.x, r.pos.z) + Vector2(6, 0))
	for il in terrain.isles:
		spots.append(terrain.isle_heart(il) + Vector2(20, 0))
		spots.append(Vector2(il.c) * 0.92)
	for q in spots:
		player.place(gpos(q) + Vector3(0, 0.4, 0), randf() * TAU)
		player.velocity = Vector3.ZERO
		await get_tree().create_timer(2.5).timeout
	step.call("walked %d places" % spots.size())
	# The weather, all of it
	for kk in WWeather.KINDS:
		shared("_w_weather", [kk, 60.0, randf() * TAU])
		weather.k = 1.0
		await get_tree().create_timer(5.5).timeout
	shared("_w_weather", ["clear", 600.0, 0.0])
	step.call("weather")
	# Boats: launch, board, row, sail, wreck
	var il0: Dictionary = terrain.isles[0]
	var dir2: Vector2 = Vector2(il0.c) / maxf(absf(il0.c.x), absf(il0.c.y))
	var shore := dir2 * 1700.0
	for k in 600:
		shore = dir2 * (1700.0 + k)
		if terrain.height_at(shore.x, shore.y) < WIsles.SEA_Y + 0.6:
			break
	player.place(gpos(shore - dir2 * 3.0) + Vector3(0, 0.3, 0), atan2(-dir2.x, -dir2.y))
	await get_tree().create_timer(1.0).timeout
	for bk in ["raft", "sloop"]:
		launch_boat(bk)
		await get_tree().create_timer(0.6).timeout
		var b: WBoat = boats.values()[boats.size() - 1]
		b.yaw = atan2(dir2.x, dir2.y)
		boat_used(b)
		await get_tree().create_timer(0.5).timeout
		Input.action_press("move_forward")
		await get_tree().create_timer(4.0).timeout
		Input.action_release("move_forward")
		Input.action_press("move_left")
		await get_tree().create_timer(2.0).timeout
		Input.action_release("move_left")
		boat_used(b)
		await get_tree().create_timer(0.5).timeout
	hurt_boat(boats.values()[0], 9999.0)
	await get_tree().create_timer(1.0).timeout
	step.call("boats left=%d" % boats.size())
	# A swim far out, until the deep finds you
	player.place(Vector3(dir2.x * 2700.0, WIsles.SEA_Y, dir2.y * 2700.0), 0.0)
	await get_tree().create_timer(12.0).timeout
	if downed or player.health <= 0.0:
		await get_tree().create_timer(1.0).timeout
	player.health = player.max_health
	player.stamina = 100.0
	player.place(gpos(WPlaces.spos("cinderwick") + Vector2(60, 0)), 0.0)
	step.call("swim")
	# A shrine and its powers
	builder._rq_build(1, "shrine", player.global_position + Vector3(3, 0, 0), 0.0)
	builder._rq_build(1, "campfire", player.global_position + Vector3(-4, 0, 2), 0.0)
	await get_tree().create_timer(0.5).timeout
	for t in ["t_ash", "t_salt"]:
		lay_trophy(t)
		take_power(t)
		await get_tree().create_timer(2.0).timeout
	step.call("powers")
	# Night: the seventh, with its raid, and every foe there is
	nights = 6
	clock = weather.dusk() - 0.01
	await get_tree().create_timer(30.0).timeout
	for kk in LesserSpeeb.KINDS:
		var at := player.global_position + Vector3(randf_range(-20, 20), 0, randf_range(15, 25))
		at.y = terrain.height_at(at.x, at.z) + 0.5
		var e = spawn_at(kk, at)
		if e:
			e.hurt(9999.0, Vector3.FORWARD)
		await get_tree().process_frame
	await get_tree().create_timer(20.0).timeout
	player.health = player.max_health
	step.call("night foes=%d great=%s" % [enemies.size(), not great.is_empty()])
	clock = weather.dawn() - 0.01
	await get_tree().create_timer(5.0).timeout
	step.call("dawn day=%d nights=%d" % [day, nights])
	# Through a whole season in a hurry
	for d in 6:
		day += 1
		_w_dawn(day)
		await get_tree().create_timer(0.5).timeout
	step.call("days season=%s" % weather.season().name)
	save_all()
	await get_tree().create_timer(2.0).timeout
	print("SOAK done %.0fs" % [(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit()


## Testing aid: a second pilgrim who joins, follows the host about and opens things, for the co-op soak.
func debug_soak_join() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 150000:
		var host = avatars.get(1)
		if host and is_instance_valid(host):
			player.place(host.global_position + Vector3(3, 1.0, 3), 0.0)
		for tab in ["pack", "craft"]:
			ui.open_inventory(tab)
			await get_tree().process_frame
		ui.close_all()
		await get_tree().create_timer(4.0).timeout
	print("SOAKJOIN done day=%d boats=%d quests=%d weather=%s" % [day, boats.size(), quests.active().size(), weather.kind])
	get_tree().quit()


## Testing aid: how many things are drawn about a town, and of what kind (for draw calls).
func debug_drawcount() -> void:
	await get_tree().create_timer(2.0).timeout
	for k in ["cinderwick", WPlaces.SETTLEMENTS.keys()[3]]:
		var c := gpos(WPlaces.spos(k))
		var by := {}
		var total := 0
		var surf := 0
		for g in find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			if not gi.is_visible_in_tree() or gi.global_position.distance_to(c) > 150.0:
				continue
			if gi.visibility_range_end > 0.0 and gi.global_position.distance_to(c) > gi.visibility_range_end:
				continue
			var top: Node = gi
			while top.get_parent() != self and top.get_parent() != null:
				top = top.get_parent()
			var key := "%s/%s" % [top.get_class(), str(top.name).left(14)]
			if gi is MultiMeshInstance3D:
				key = "MULTI " + key
			by[key] = by.get(key, 0) + 1
			total += 1
			if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
				surf += (gi as MeshInstance3D).mesh.get_surface_count()
			else:
				surf += 1
		var keys := by.keys()
		keys.sort_custom(func(a, b): return by[a] > by[b])
		print("DRAW %s instances=%d surfaces=%d" % [k, total, surf])
		for kk in keys.slice(0, 14):
			print("DRAW   %s %d" % [kk, by[kk]])
		for t in get_children():
			if t is Node3D and t.get_class() == "Node3D" and t.global_position.distance_to(c) < 150.0 and t.get_child_count() > 20:
				var kinds := {}
				for ch in t.get_children():
					var kk2 := "%s %s %s" % [ch.get_class(), ch.get_script().resource_path.get_file() if ch.get_script() else "", ch.get_meta_list()]
					kinds[kk2] = kinds.get(kk2, 0) + 1
				print("DRAW  sample %s script=%s meta=%s kids=%s" % [t.name, t.get_script(), t.get_meta_list(), kinds])
				for mi in t.find_children("*", "MeshInstance3D", true, false).slice(0, 4):
					var chain := []
					var q: Node = mi
					while q != t:
						chain.append("%s%s%s" % [q.get_class(), q.get_meta_list(), "S" if q.get_script() else ""])
						q = q.get_parent()
					print("DRAW   mesh vr=%s tr=%s vis=%s chain=%s" % [mi.visibility_range_end, mi.transparency, mi.visible, chain])
				break
	get_tree().quit()


## Testing aid: spilled rounds lie about the waste and can be gathered; a fired gun throws its cases.
func debug_ammo() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var piles: Array = nodes.filter(func(nd): return nd.kind == "ammo")
	var shown := 0
	for nd in piles:
		if (nd.node as Node3D).find_children("*", "MeshInstance3D", true, false).size() > 10:
			shown += 1
	var id: int = piles[0].id
	var item: String = AMMO_PILE_KINDS[id % AMMO_PILE_KINDS.size()]
	var before: int = inv.count(item)
	_rq_gather(Net.me(), id)
	await get_tree().create_timer(0.5).timeout
	var wpn = player.weapon
	wpn.shells = 99
	for i in 5:
		wpn._cool = 0.0
		wpn._try_fire()
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.6).timeout
	var cases: int = wpn._cases.filter(func(c): return is_instance_valid(c)).size()
	# A friend's shots throw their cases too
	for i in 3:
		net_fx(2, "gun:pistol9", player.global_position + Vector3(2, 1.5, 0), Vector3(0, 0, -1))
	await get_tree().create_timer(0.2).timeout
	var theirs: int = wpn._cases.filter(func(c): return is_instance_valid(c)).size() - cases
	print("AMMO piles=%d shown=%d gathered=%s cases=%d theirs=%d gun=%s" % [piles.size(), shown, inv.count(item) > before, cases, theirs, wpn.gun()])
	get_tree().quit()


## Testing aid: a pack of box cats comes at the pilgrim, screaming, and dies to a few pellets.
func debug_boxcat() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var cats: Array = []
	for i in 6:
		var c = _spawn_near("box_cat", player.global_position + Vector3(0, 0, -20), 1.0, 4.0, true)
		if c:
			cats.append(c)
	var d0: float = cats[0].global_position.distance_to(player.global_position)
	await get_tree().create_timer(2.0).timeout
	var d1: float = cats[0].global_position.distance_to(player.global_position) if is_instance_valid(cats[0]) else 0.0
	print("BOXCAT made=%d name=%s boxed=%s closed=%s hp=%.0f" % [cats.size(), cats[0].spec.name, cats[0]._box != null, d1 < d0, cats[0].hp])
	get_tree().quit()


## Testing aid: at a workbench, the Arms tab opens and the Make tab can be entered from it.
func debug_benchtabs() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	ui.debug_bench = true
	var start_tab := "arms"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tab="):
			start_tab = a.substr(4)
	ui.open_inventory(start_tab)
	for f in 5:
		await get_tree().process_frame
	var arms_n: int = ui._body.get_child_count() if ui._body else -1
	var r0: int = ui.redraws
	await get_tree().create_timer(3.0).timeout
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/bench_shot.png")
	print("BENCHREDRAW in3s=%d" % (ui.redraws - r0))
	# Click the Make tab as a mouse would
	var btn: Button = null
	for b in ui.find_children("*", "Button", true, false):
		if (b as Button).text == "Make" and b.is_visible_in_tree():
			btn = b
			break
	var at := btn.get_global_rect().get_center() if btn else Vector2.ZERO
	var over: Array = []
	for c in get_tree().root.find_children("*", "Control", true, false):
		var cc := c as Control
		if cc.is_visible_in_tree() and cc.mouse_filter != Control.MOUSE_FILTER_IGNORE and cc.get_global_rect().has_point(at) and cc != btn:
			over.append("%s(%s)" % [cc.get_class(), cc.name])
	print("BENCHCLICK button=%s at=%s over=%s" % [btn != null, at, over])
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)
		await get_tree().process_frame
	await get_tree().process_frame
	var craft_n: int = ui._body.get_child_count() if ui._body else -1
	print("BENCHTABS arms=%d craft=%d tab=%s open=%s" % [arms_n, craft_n, ui._tab, ui._panel_name])
	get_tree().quit()


## Testing aid: a kindled beacon gives its gift, offers three boons, one is taken and works, and it is kept.
func debug_boons() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var t0: int = inv.count("tempered")
	var sp0: float = skills.speed_mult()
	var pk0: int = skills.pack_size()
	_w_vigil(0, 1.0)
	_w_vigil_end(0, true)
	var gift: bool = inv.count("tempered") > t0
	var offered: int = skills.boon_offer.size()
	var next_shown: bool = is_revealed(gpos(WPlaces.bpos(next_dark_beacon(beacon_nodes[0].pos))))
	await get_tree().create_timer(4.0).timeout
	var opened: bool = ui._panel_name == "boons"
	# Choose Fleet Foot and Packrat by force, to see them work
	skills.boon_offer = ["fleet"]
	var took := skills.take_boon("fleet")
	skills.boon_offer = ["packrat"]
	skills.take_boon("packrat")
	var faster: bool = skills.speed_mult() > sp0
	var bigger: bool = skills.pack_size() == pk0 + 6
	var back := WSkills.new()
	back.from_data(skills.to_data())
	ui.close_all()
	print("BOONS gift=%s offered=%d opened=%s took=%s faster=%s bigger=%s kept=%s next=%s" % [gift, offered, opened, took, faster, bigger, back.boons.size() == 2, next_shown])
	get_tree().quit()


## Testing aid: from Cinderwick, looking toward the first dark beacon; saves what is seen.
func debug_horizonshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var c := gpos(WPlaces.spos("cinderwick"))
	var at := c + Vector3(0, 0, 0)
	at.y = terrain.height_at(at.x, at.z) + 0.3
	player.place(at, 0.0)
	var b: Vector3 = beacon_nodes[0].pos
	player.face(b + Vector3(0, 30, 0))
	clock = 15.0
	for k in 40:
		await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/horizon.png")
	print("HORIZON dist=%d" % int(at.distance_to(b)))
	get_tree().quit()


# ================================================================== what now

## Three goals, always: the next step on the beacon road, the nearest thing worth doing, and
## something to grow toward. Each is {kind, title, text, at (Vector3 or null)}.
func what_now() -> Array:
	var out: Array = []
	var me := player.global_position
	# 1. The beacon road
	var main_q: Dictionary = {}
	for q in quests.active():
		if q.get("main", false):
			main_q = q
	if not main_q.is_empty():
		var s: Dictionary = quests.step_of(main_q)
		var t = quests.target_of(main_q)
		var txt: String = quests.step_text(main_q)
		if str(s.get("t", "")) in ["count", "kindle"]:
			var oil := inv.count("beacon_oil")
			txt += " You carry %d beacon oil." % oil
			if oil == 0:
				txt += " Render more at a workbench: 2 lamp oil, 10 salt, 4 ash-bloom." if flags.has("oilcraft") else ""
		out.append({"kind": "road", "title": "The beacon road", "text": txt, "at": t})
	elif lit.size() < 9:
		var nb := next_dark_beacon(me)
		if nb >= 0:
			out.append({"kind": "road", "title": "The beacon road", "text": "Kindle %s." % WPlaces.BEACONS[nb].name, "at": beacon_nodes[nb].pos})
	# 2. The nearest thing worth doing: a task taken up, a great one waiting, a town not yet seen
	var near: Dictionary = {}
	var nd := INF
	for q in quests.active():
		if q.get("main", false):
			continue
		var t = quests.target_of(q)
		if t is Vector3 and t.distance_to(me) < nd:
			nd = t.distance_to(me)
			near = {"kind": "near", "title": str(q.get("title", "A task")), "text": quests.step_text(q), "at": t}
	if near.is_empty():
		for k in WPlaces.SETTLEMENTS:
			if visited.has(k):
				continue
			var p := gpos(WPlaces.spos(k))
			if p.distance_to(me) < nd:
				nd = p.distance_to(me)
				near = {"kind": "near", "title": WPlaces.SETTLEMENTS[k].name, "text": "A settlement you have not seen. Its people will have work, and things to trade.", "at": p}
	if events:
		var ev: Dictionary = events.nearest(me)
		if not ev.is_empty() and ev.pos.distance_to(me) < 500.0:   # it will not wait: it comes first
			nd = ev.pos.distance_to(me)
			near = {"kind": "near", "title": WEvents.KINDS[ev.kind].name, "text": "Go now: it will not wait long.", "at": ev.pos}
	for l in lairs:
		if lair_ready(l) and l.pos.distance_to(me) < minf(nd, 700.0):
			nd = l.pos.distance_to(me)
			near = {"kind": "near", "title": l.name, "text": "%s waits here, under the dark smoke. Bring friends." % LesserSpeeb.BOSSES[l.boss].name, "at": l.pos}
	if near.is_empty():
		near = {"kind": "near", "title": "Work", "text": "Ask in the settlements: there is always work.", "at": null}
	out.append(near)
	# 3. Something to grow toward
	var grow: Dictionary
	if not skills.boon_offer.is_empty():
		grow = {"kind": "grow", "title": "A beacon boon waits", "text": "Touch any lit beacon to choose it.", "at": null}
	elif skills.points > 0:
		grow = {"kind": "grow", "title": "%d skill point%s to spend" % [skills.points, "" if skills.points == 1 else "s"], "text": "Press %s to learn something." % Game.key_text("skills"), "at": null}
	else:
		var best := ""
		var lv := 999
		for g in ArmsDB.GUNS:
			var u := int(ArmsDB.GUNS[g].get("unlock", 1))
			if u > skills.level and u < lv:
				lv = u
				best = g
		if best != "":
			grow = {"kind": "grow", "title": "Level %d: the %s" % [lv, ArmsDB.GUNS[best].name], "text": "%d experience to the next level. Kindle beacons, finish tasks and undo forms." % maxi(0, WSkills.need(skills.level) - skills.xp), "at": null}
		else:
			grow = {"kind": "grow", "title": "Grow strong", "text": "Rework your arms with better fittings at a workbench.", "at": null}
	out.append(grow)
	return out


## Testing aid: What now always has three goals, the road first with a place to go, and shows in the journal.
func debug_whatnow() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var g := what_now()
	var kinds: Array = g.map(func(x): return x.kind)
	ui.open_journal() if ui.has_method("open_journal") else ui._open("journal")
	await get_tree().process_frame
	var shown: bool = ui._panel_name == "journal"
	skills.boon_offer = ["fleet", "packrat", "salvager"]
	var boon_first: bool = what_now()[2].title == "A beacon boon waits"
	print("WHATNOW n=%d kinds=%s road_at=%s shown=%s boon=%s first=%s" % [g.size(), ",".join(kinds), g[0].at is Vector3, shown, boon_first, g[0].text.left(40)])
	get_tree().quit()


## Testing aid: a long beacon step names the small next thing, and points the way to it.
func debug_subgoal() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var q: Dictionary = quests.quests["main"]
	q.stage = 5
	for id in ["beacon_oil", "oil", "herb", "salt"]:
		inv.take(id, inv.count(id))
	var a: String = quests.next_hint(q)
	var to_well: bool = quests.target_of(q).distance_to(gpos(WPlaces.spos("lanternwell"))) < 1.0
	inv.add("oil", 2)
	inv.add("herb", 4)
	inv.add("salt", 10)
	var b: String = quests.next_hint(q)
	inv.add("beacon_oil", 1)
	var c: String = quests.next_hint(q)
	print("SUBGOAL well=%s to_well=%s make=%s carry=%s" % ["Lantern Well" in a, to_well, "workbench" in b, "carry" in c and "Beacon" in c])
	get_tree().quit()


func _w_event_start(id: int, kind: String, p: Vector3) -> void:
	if events:
		events.start(id, kind, p)


func _w_event_end(id: int, won: bool, by: int) -> void:
	if events:
		events.end(id, won, by)


## Testing aid: a roaming event starts near, shows on What now, ends when its foes fall, and gives.
func debug_events() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	events._t = 0.0
	events.host_tick(0.1)
	var started := events.active.size()
	var id: int = events.active.keys()[0] if started > 0 else -1
	var kind: String = events.active[id].kind if id >= 0 else ""
	var shown: bool = what_now()[1].title == WEvents.KINDS.get(kind, {}).get("name", "?")
	var salt0 := inv.count("salt")
	var have0 := 0
	for g in WEvents.GIVES.get(kind, []):
		have0 += inv.count(g[0])
	player.place(events.active[id].pos + Vector3(3, 1, 0), 0.0)
	await get_tree().create_timer(0.5).timeout
	if kind in ["star", "cache"]:
		_w_event_end(id, true, Net.me())
	else:
		for f in events.active[id].foes:
			if is_instance_valid(f):
				f.die(false)
		events.host_tick(0.1)
	await get_tree().create_timer(0.5).timeout
	var have1 := 0
	for g in WEvents.GIVES.get(kind, []):
		have1 += inv.count(g[0])
	# Every kind can be made
	var made := 0
	for k in WEvents.KINDS:
		_w_event_start(900 + made, k, player.global_position + Vector3(30 + made * 10, 0, 0))
		made += 1
	await get_tree().process_frame
	print("EVENTS started=%d kind=%s shown=%s ended=%s gave=%s made=%d" % [started, kind, shown, not events.active.has(id), have1 > have0, events.active.size()])
	get_tree().quit()


## Testing aid: walk in at the doors of houses near the start, from a step outside.
func debug_doorwalk() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var me: Vector3 = player.global_position
	var doors := town_doors.duplicate()
	doors.sort_custom(func(a, b): return (a[0] as Vector3).distance_to(me) < (b[0] as Vector3).distance_to(me))
	var tried := 0
	var inside := 0
	for d in doors.slice(0, 8):
		var from: Vector3 = d[0]
		var to: Vector3 = d[1]
		player.place(Vector3(from.x, terrain.height_at(from.x, from.z) + 1.0, from.z), 0.0)
		var dir := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
		player.yaw = atan2(-dir.x, -dir.z)
		player.rotation.y = player.yaw
		await get_tree().create_timer(0.4).timeout
		Input.action_press("move_forward")
		var t := 0.0
		var ok := false
		while t < 4.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			var p: Vector3 = player.global_position
			if Vector2(p.x - to.x, p.z - to.z).length() < 1.2:
				ok = true
				break
		Input.action_release("move_forward")
		tried += 1
		if ok:
			inside += 1
	print("DOORWALK tried=%d inside=%d" % [tried, inside])
	get_tree().quit()


## Testing aid: trees and rocks of the cover are solid now; fallen branches are not.
func debug_treebody() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var bodies := 0
	var shapes := 0
	var probe := Vector3.INF
	for c in get_children():
		if c is StaticBody3D and c.get_child_count() > 0 and c.get_child(0) is CollisionShape3D and (c.get_child(0) as CollisionShape3D).shape is CylinderShape3D:
			bodies += 1
			shapes += c.get_child_count()
			if probe == Vector3.INF:
				probe = (c.get_child(0) as CollisionShape3D).global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	var q := PhysicsPointQueryParameters3D.new()
	q.position = probe
	q.collision_mask = 1
	var hit: bool = probe != Vector3.INF and not get_world_3d().direct_space_state.intersect_point(q, 1).is_empty()
	print("TREEBODY bodies=%d shapes=%d solid=%s" % [bodies, shapes, hit])
	get_tree().quit()


## Testing aid: Escape closes the topmost layer only: a dialog over the menu, then the menu.
func debug_escape() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	hud.toggle_pause()
	await get_tree().process_frame
	hud.show_rules(rules, true, func(_r): pass)
	await get_tree().process_frame
	var dlg: Array = get_tree().get_nodes_in_group("hud_dialog")
	# A button in the dialog has the focus, as after a click
	for b in (dlg[0] as Node).find_children("*", "Button", true, false):
		(b as Button).grab_focus()
		break
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = KEY_ESCAPE
	up.physical_keycode = KEY_ESCAPE
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame
	var left: int = get_tree().get_nodes_in_group("hud_dialog").filter(func(d): return is_instance_valid(d) and not d.is_queued_for_deletion()).size()
	var menu_after_one: bool = hud.pause_panel.visible
	Input.parse_input_event(esc)
	await get_tree().process_frame
	Input.parse_input_event(up)
	await get_tree().process_frame
	print("ESCAPE dialogs=%d->%d menu_kept=%s menu_closed=%s" % [dlg.size(), left, menu_after_one, not hud.pause_panel.visible])
	get_tree().quit()


## Testing aid: a pilgrim fallen through the ground is set back on top, and never kept below it.
func debug_stuck() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(8.0).timeout   # a few good spots to fall back on
	var spots := _safe_spots.size()
	var p: Vector3 = player.global_position
	var g: float = terrain.height_at(p.x, p.z)
	player.global_position = Vector3(p.x, g - 12.0, p.z)
	player.set_physics_process(false)
	var kept: Vector3 = char_data().pos
	var kept_ok: bool = kept.y > g - 3.0
	player.set_physics_process(true)
	await get_tree().create_timer(2.5).timeout
	var back: bool = player.global_position.y > terrain.height_at(player.global_position.x, player.global_position.z) - 1.0
	player.place(p + Vector3(40, 0, 0), 0.0)
	unstick(false)
	var to_spot: bool = player.global_position.distance_to(p) < 30.0
	print("STUCK spots=%d kept_ok=%s back=%s menu=%s" % [spots, kept_ok, back, to_spot])
	get_tree().quit()


## Testing aid: a swarm left alone digs in as a raid camp, and breaking the camp pays.
func debug_raidcamp() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	var p: Vector3 = player.global_position + Vector3(60, 0, 0)
	p.y = terrain.height_at(p.x, p.z)
	shared("_w_event_start", [50, "swarm", p])
	var e: Dictionary = events.active[50]
	var f0 = null
	for k in 6:
		f0 = _spawn_one("rusher", p, 3.0, 14.0, true)
		if f0:
			break
	e["foes"] = [f0]
	e.left = 0.05
	events.host_tick(0.1)
	var camp_id := -1
	for id in events.active:
		if events.active[id].kind == "camp":
			camp_id = id
	var dug: bool = camp_id >= 0 and not events.active.has(50)
	var foes: int = events._alive(events.active[camp_id]) if dug else 0
	var salt0 := inv.count("salt")
	player.place(p + Vector3(3, 1, 0), 0.0)
	await get_tree().create_timer(0.5).timeout
	for f in events.active[camp_id].foes:
		if is_instance_valid(f):
			f.die(false)
	events.host_tick(0.1)
	await get_tree().create_timer(0.5).timeout
	print("CAMP dug=%s foes=%d broken=%s paid=%s" % [dug, foes, not events.active.has(camp_id), inv.count("salt") > salt0])
	get_tree().quit()


## Testing aid: a tree that can be cut beside the dead trees that cannot; saves what is seen.
func debug_treeshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	var best = null
	var bd := INF
	for nd in nodes:
		if nd.kind == "tree" and nd.pos.distance_to(player.global_position) < bd:
			bd = nd.pos.distance_to(player.global_position)
			best = nd
	var at: Vector3 = best.pos + Vector3(6, 0, 6)
	at.y = terrain.height_at(at.x, at.z) + 0.3
	player.place(at, 0.0)
	player.face(best.pos + Vector3(0, 2.0, 0))
	for k in 30:
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/tree.png")
	print("TREESHOT at=%s" % best.pos)
	get_tree().quit()


## Testing aid: a tomb's door lets you in, its walls do not, and it has a roof.
func debug_tomb() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var r: Dictionary = {}
	for x in ruins:
		if x.kind == "vault":
			r = x
			break
	player.place(r.pos + Vector3(0, 30, 30), 0.0)
	await get_tree().create_timer(2.0).timeout
	var n: Node3D = null
	for c in get_children():
		if c is Node3D and c.position.distance_to(r.pos) < 0.5 and c.get_child_count() > 3:
			n = c
	var space := get_world_3d().direct_space_state
	var gy: float = terrain.height_at(n.to_global(Vector3(0, 0, -4)).x, n.to_global(Vector3(0, 0, -4)).z)
	var mid := n.to_global(Vector3(0, 0, -4))
	mid.y = gy + 1.2
	var door := PhysicsRayQueryParameters3D.create(n.to_global(Vector3(0, 0, 3.0)) * Vector3(1, 0, 1) + Vector3(0, gy + 1.2, 0), mid, 1)
	door.exclude = [player.get_rid()]
	var side := PhysicsRayQueryParameters3D.create(n.to_global(Vector3(8, 0, -4)) * Vector3(1, 0, 1) + Vector3(0, gy + 1.2, 0), mid, 1)
	side.exclude = [player.get_rid()]
	var roof := PhysicsRayQueryParameters3D.create(mid + Vector3(0, 12, 0), mid, 1)
	roof.exclude = [player.get_rid()]
	print("TOMB door_open=%s wall=%s roof=%s" % [space.intersect_ray(door).is_empty(), not space.intersect_ray(side).is_empty(), not space.intersect_ray(roof).is_empty()])
	get_tree().quit()


## Testing aid: named nights come after the first few, are the same for everyone, and pay at dawn if held.
func debug_nights() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var seen := {}
	for n in range(1, 40):
		seen[night_theme_for(n)] = true
	var early := night_theme_for(1) == "" and night_theme_for(2) == ""
	var same := night_theme_for(9) == night_theme_for(9)
	var n0 := -1
	for n in range(3, 40):
		if night_theme_for(n) == "long":
			n0 = n
			break
	nights = n0 - 1
	_w_nightfall(day)
	var themed := night_theme == "long"
	var r0 := inv.count("fittings_rare")
	_w_dawn(day + 1)
	var paid := inv.count("fittings_rare") > r0
	print("NIGHTS kinds=%d early_plain=%s same=%s themed=%s paid=%s" % [seen.size(), early, same, themed, paid])
	get_tree().quit()
