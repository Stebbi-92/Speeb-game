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
const REVEAL_N := 660
const REVEAL_HALF := WIsles.MAP_HALF   ## the fog lies over the whole map, the sea and its isles too: 20 m to a cell
const BEACON_SIGHT := 520.0            ## a lit beacon shows the land about it on the map, this far

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
var lights: WLights      ## the Lighthouse chain over the far sea, its lanes, and the Kelp Forest
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
var music: WMusic = null       ## the one music director
var lairs: Array = []           ## one to a land: {id, land, boss, name, pos}
var _lair_boss := {}            ## lair id -> the great one now awake there
const LAIR_RETURN_DAYS := 3
var vigils := {}
var bedroll = null
var revealed := PackedByteArray()
var visited := {}
var known_ruins := {}
var traces_seen := {}   ## the isles' small scenes this player has looked at (see WIsleLife.TRACES)
var slain_kinds := {}   ## the forms this player has slain at least once: the first of each opens its bestiary page
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
		elif Game.set_aside_damaged(world_path(slot)):
			_damaged = true
		var sd := int(_pending.get("seed", 0)) if not _pending.is_empty() else Game.new_world_seed
		if sd == 0:
			sd = randi_range(10000, 99999999)
		# Worlds made before 0.9 keep their land as it was; new ones begin on the Ash Plains
		await _make_world(sd, int(_pending.get("gen", 1)) if not _pending.is_empty() else GEN, true)
	else:
		spawn_pos = Vector3(0, 400, 0)
		snap_wait = true   # the host's world is still to come
	ambient("wind", -10)
	_beds = {"night": ambient("amb_desert_night", -60), "town": ambient("amb_town", -60), "cave": ambient("amb_cave", -60),
		"forest": ambient("amb_forest", -60), "birds": ambient("amb_birds", -60), "crickets": ambient("amb_crickets", -60),
		"lake": ambient("amb_lake", -60), "river": ambient("amb_river", -60)}


var world_seed := 0
var _pending := {}
var _damaged := false   ## a save was there but could not be read, and was kept aside
const GEN := 3          ## how the land is raised: 2 keeps the Ash Plains about where the cast-out wake; 3 gives the waste a ragged, rounded coast
var world_gen := GEN


## Raises the whole waste from its seed: the land and its six biomes, then the places upon it.
func _make_world(sd: int, gen := GEN, steps := false) -> void:
	_steps = steps
	world_seed = sd
	world_gen = gen
	terrain = WTerrain.new()
	terrain.setup(sd)
	terrain.natural_coast = gen >= 3
	WPlaces.lay_out(sd, func(p: Vector2) -> Vector2: return Vector2(terrain.legacy_raw(p.x, p.y), terrain_probe(p)))
	if gen >= 2:
		terrain.home = WPlaces.start
	WPlaces.lay_out_far(sd, func(p: Vector2) -> Vector2: return Vector2(terrain._raw(p.x, p.y), terrain_probe(p)))
	WPlaces.lay_out_shores(terrain.isles)
	for k in WPlaces.SETTLEMENTS:
		terrain.add_flat(WPlaces.spos(k), WPlaces.SETTLEMENTS[k].radius + 8.0)
	for bp in WPlaces.beacon_points():
		terrain.add_flat(bp, 16.0)
	terrain.add_flat(WPlaces.start, 6.0)
	_plan_ruins()
	for r in ruins:
		terrain.add_flat(Vector2(r.pos.x, r.pos.z), 9.0)
	_plan_lairs()
	if terrain.natural_coast:
		_plan_bays(sd)
	WPlaces.plan_roads(sd, func(p: Vector2) -> Vector2: return Vector2(terrain._raw(p.x, p.y), terrain_probe(p)))
	for rd in WPlaces.roads:
		terrain.add_road(rd[2])
	for k in WPlaces.SETTLEMENTS:
		_town_paths(k)
	await _step("The land is raised", 0.01)
	terrain.steps = steps
	terrain.on_progress = func(f: float): _progress(0.01 + 0.22 * f)
	await terrain.generate()
	for r in ruins:
		r.pos.y = terrain.height_at(r.pos.x, r.pos.z)
	for l in lairs:
		l.pos.y = terrain.height_at(l.pos.x, l.pos.z)
	await _step("The ground is laid", 0.23)
	terrain.on_progress = func(f: float): _progress(0.23 + 0.03 * f)
	await terrain.build(_m.ground)
	terrain.on_progress = Callable()
	terrain.steps = false
	terrain.make_isles(_m.ground)
	add_child(terrain)
	# The isles' hearts: a ruin on each, keeping a lost book (their own ids, after all the rest)
	for il in terrain.isles:
		var hp: Vector2 = terrain.isle_heart(il)
		var th: Dictionary = WIsles.THEMES[il.key]
		ruins.append({"id": "isle_" + str(il.key), "name": th.ruin[0], "kind": th.ruin[1], "pos": Vector3(hp.x, terrain.height_at(hp.x, hp.y), hp.y), "guard_day": 0, "isle": il.key})
		WPlaces.ruin_at["isle_" + str(il.key)] = hp
	_plan_far_lairs()
	_plan_far_ruins()
	await _step("The sea is poured", 0.27)
	sea = WSea.new().setup(self)
	add_child(sea)
	for k in WPlaces.SETTLEMENTS:
		await _step("The towns are built", 0.27 + 0.15 * WPlaces.SETTLEMENTS.keys().find(k) / WPlaces.SETTLEMENTS.size())
		var s0 := get_child_count()
		_build_settlement(k)
		_batch_since(s0)
	await _step("The ruins are set", 0.42)
	for i in WPlaces.BEACONS.size():
		_build_beacon(i)
	var before := get_child_count()
	for r in ruins:
		if ruins.find(r) % 6 == 5:
			await _step("The ruins are set", 0.43 + 0.24 * ruins.find(r) / ruins.size())
		var r0 := get_child_count()
		_build_ruin(r)
		_batch_since(r0)
	for i in range(before, get_child_count()):
		_fade_far(get_child(i), 700.0)
	await _step("The lairs are dug", 0.67)
	for l in lairs:
		_build_lair(l)
	_build_shrine_bowls()
	await _step("Stores are hidden", 0.67)
	_scatter_nodes()
	await _step("Stores are hidden", 0.82)
	_scatter_isle_nodes(false)
	await _step("Stores are hidden", 0.84)
	_scatter_ammo()
	_scatter_isle_nodes(true)   # the far lands last, so older saves keep their node ids
	await _step("The isles wake", 0.85)
	sea.build_isles()
	life = WIsleLife.new().setup(self)
	add_child(life)
	life.build()
	for nd in nodes:
		_off_the_road(nd)
		_fade_far(nd.node, 420.0)
	await _step("The waste is dressed", 0.87)
	_build_signposts()
	await _step("The waste is dressed", 0.98)
	_scatter_decor()
	await _step("The waste is dressed", 0.985)
	WDress.cover(self)
	WTrees.woods(self)
	WShells.outskirts(self)
	WShells.lone_barns(self)
	await _step("The halls are opened", 0.995)
	hall = WHall.new(self)
	hall.build()
	deep = WDeep.new(self)
	lights = WLights.new(self)
	lights.plan()
	lights.build()
	vaults = WVaults.new(self)
	kraken.build()
	endings.build()
	vaults.place_stairs()
	_scatter_landmarks()
	spawn_pos = gpos(WPlaces.start) + Vector3(0, 0.2, 0)
	spawn_yaw = yaw_to(spawn_pos, gpos(WPlaces.spos("cinderwick")))
	_progress(1.0)
	_steps = false


var _steps := false
## Between the great works of raising the waste: the loading words move on and a frame is drawn,
## so the window never hangs still. Only on the host's own raising (the level waits for it).
func _step(what: String, at := -1.0) -> void:
	if not _steps:
		return
	if hud:
		hud.set_loading(what)
	_progress(at)
	await get_tree().process_frame


## How far the raising has got, 0 to 1, for the loading screen's bar.
var _prog_from := 0.0   ## a newcomer's bar has already come this far while the world was sent

func _progress(f: float) -> void:
	if _steps and f >= 0.0 and hud:
		hud.set_loading_progress(_prog_from + (1.0 - _prog_from) * f)


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
		snap_wait = true
		shared("_rq_hello", [Net.me()])
		_hello_again()
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
	WPlaylog.end()
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


var _ground_laid := false

func _process(delta: float) -> void:
	if _stars and player:
		_stars.global_position = player.global_position
	if terrain and player and not Net.dedicated and not _steps:
		# The ground about the eye: all at once the first time, then a little at a time as it moves
		var cam := get_viewport().get_camera_3d()
		terrain.stream_to(cam.global_position if cam else player.global_position, not _ground_laid)
		_ground_laid = true
	if Net.dedicated and ready_world:
		# No one plays here, but the towns' watch still walks and shoots
		_gate_t -= delta
		if _gate_t <= 0.0:
			_gate_t = 1.0
			_militia_tick(1.0)
	if player and hud and not Net.dedicated:
		_stuck_tick(delta)
		_boss_watch()
		_bed_t -= delta
		if _bed_t <= 0.0:
			_bed_t = 0.5
			_place_sounds()
			_landmarks_tick()
			_lair_hint()
		_cat_tick(delta)
		_trade_tell_tick(delta)
		_gate_t -= delta
		if _gate_t <= 0.0:
			_gate_t = 1.0
			_gates_tick(1.0)
			_militia_tick(1.0)
		_radio_tick(delta)
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
		var db := linear_to_db(maxf(float(want[k]), 0.001)) - 11.0
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
		if terrain.natural_coast and terrain._raw(p.x, p.y) < WIsles.SEA_Y + 8.0:
			continue   # the ragged coast took this spot: not a ruin under the sea
		var nm: String = WPlaces.RUIN_WORDS_A[fr.randi() % WPlaces.RUIN_WORDS_A.size()] + " " + WPlaces.RUIN_WORDS_B[fr.randi() % WPlaces.RUIN_WORDS_B.size()]
		if ruins.any(func(o): return o.name == nm):
			nm = "Far " + nm
			if ruins.any(func(o): return o.name == nm):
				continue
		ruins.append({"id": "r%d" % ruins.size(), "name": nm, "kind": kinds[fr.randi() % kinds.size()], "pos": Vector3(p.x, 0, p.y), "guard_day": 0})
		far += 1


# ------------------------------------------------------------------ the Lighthouse chain (see WLights)

func _rq_house(by: int, i: int) -> void:
	if lights:
		lights.start(by, i)


func _w_house_hold(i: int, by: int) -> void:
	if lights:
		lights.holding(i, by)


func _w_house(i: int, ok: bool) -> void:
	if lights:
		lights.done(i, ok)


## The far isles and the Far Shores: nameless ruins over the whole of each, about one every 300 m,
## so there is always something to walk to (gameplay bible, rule 4). Their own dice and ids.
const FAR_RUINS := {"quiet": 8, "domes": 9, "frost": 40, "sun": 40, "steppe": 42}

func _plan_far_ruins() -> void:
	var kinds := ["wreck", "shrine", "tower", "camp", "stones", "camp", "shrine"]
	for il in terrain.isles:
		if not FAR_RUINS.has(il.key):
			continue
		var r := RandomNumberGenerator.new()
		r.seed = world_seed + 8808 + hash(str(il.key))
		var want: int = FAR_RUINS[il.key]
		var made := 0
		for tries in want * 40:
			if made >= want:
				break
			var a := r.randf() * TAU
			var q: Vector2 = il.c + Vector2(cos(a), sin(a)) * sqrt(r.randf()) * float(il.r) * 0.82
			var y: float = terrain.height_at(q.x, q.y)
			if y < WIsles.SEA_Y + 1.5 or terrain.normal_at(q.x, q.y).y < 0.86:
				continue
			if not _clear_of_places(q, 110.0, 190.0 if float(il.r) > 800.0 else 120.0):
				continue
			if lairs.any(func(l): return q.distance_to(Vector2(l.pos.x, l.pos.z)) < 60.0):
				continue
			var wd: Array = WIsles.THEMES[il.key].words
			var nm: String = str(wd[0][r.randi() % wd[0].size()]) + " " + str(wd[1][r.randi() % wd[1].size()])
			if ruins.any(func(o): return o.name == nm):
				continue
			ruins.append({"id": "fs_%s_%d" % [il.key, made], "name": nm, "kind": kinds[r.randi() % kinds.size()], "pos": Vector3(q.x, y, q.y), "guard_day": 0, "far": il.key})
			made += 1


## Shader warm-up: under the opening fade, the first fire, blast, burst and muzzle flash are drawn once
## out of sight of the player's eye, so the first real one in a fight does not hitch while it compiles.
func _warm_up(force := false) -> void:
	# Only while the opening fade still hides it: on this machine's own world, not a joiner's late one
	if not force and (Net.dedicated or DisplayServer.get_name() == "headless" or not Net.authority()):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	hush = true
	var fwd := -cam.global_transform.basis.z
	var at := cam.global_position + fwd * 5.0
	burst(at, Color(0.6, 0.05, 0.03))
	Arms.flame_jet(self, at, fwd, true)
	Arms.blast_fx(self, at + fwd * 3.0, 1.5)
	_w_slam_fx(at, 2.0)
	var wpn = player.weapon
	if wpn and wpn._flash_mesh:
		wpn._flash_mesh.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	if wpn and wpn._flash_mesh:
		wpn._flash_mesh.visible = false
	hush = false


## A few deep bays where the sea comes into the land, each well clear of every place laid out.
func _plan_bays(sd: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = sd + 9191
	var spots: Array = [WPlaces.start]
	for k in WPlaces.SETTLEMENTS:
		spots.append(WPlaces.spos(k))
	spots.append_array(WPlaces.beacon_points())
	for ru in ruins:
		if not ru.has("isle"):
			spots.append(Vector2(ru.pos.x, ru.pos.z))
	for l in lairs:
		spots.append(Vector2(l.pos.x, l.pos.z))
	var want := 6
	for t in 200:
		if terrain.bays.size() >= want:
			break
		var a := r.randf() * TAU
		var d := Vector2(cos(a), sin(a))
		var c := d / maxf(absf(d.x), absf(d.y)) * 1980.0
		var rad := r.randf_range(420.0, 720.0)
		var clear := true
		for sp in spots:
			if (sp as Vector2).distance_to(c) < rad * 0.82 + 50.0:   # past that the sea hardly reaches
				clear = false
				break
		for b in terrain.bays:
			if (b[0] as Vector2).distance_to(c) < (rad + float(b[1])) * 0.8:
				clear = false
		if clear:
			terrain.bays.append([c, rad])


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
		var wr := town_wall_r(k, a)
		var p := c + Vector3(cos(a) * wr, 0, sin(a) * wr)
		p.y = terrain.height_at(p.x, p.z)
		var hgt := rr.randf_range(3.2, 4.2)
		cyl(p + Vector3(0, hgt * 0.5 - 0.4, 0), 0.22, hgt, wall, true, 0.14, 6)
	# The gates themselves: two heavy leaves in each gap, open by day; barred at night when the roads are dangerous
	var leaves: Array = []
	for g in [-1.0, 1.0]:
		var ga: float = PI * 0.5 * g
		var gp := c + Vector3(cos(ga) * r, 0, sin(ga) * r)
		gp.y = terrain.height_at(gp.x, gp.z)
		var gw := 2.0 * r * sin(0.12)
		var leaf: MeshInstance3D = box(gp + Vector3(0, 1.8, 0), Vector3(gw, 3.6, 0.3), _m.darkwood, true)
		leaf.rotation.y = -ga + PI * 0.5
		leaf.visible = false
		var lb = leaf.get_child(0) if leaf.get_child_count() > 0 else null
		if lb is CollisionObject3D:
			lb.collision_layer = 0
		var gi := leaves.size()
		var ka := k
		var knock: Area3D = interact_area(gp + Vector3(cos(ga), 0, sin(ga)) * 1.8 + Vector3(0, 1.0, 0), 2.2, "", func(): _knock(ka, gi), 0.0, false)
		leaves.append({"leaf": leaf, "body": lb, "knock": knock})
	gates[k] = leaves
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
	for i in (3 if s.get("far", false) or s.has("shore") else 5):
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
## No two towns are laid out alike: each has its own way, its own lean to one side, and its own wall.
## ring: about the fire. street: two rows from gate to gate. cluster: put up as they came.
## crescent: crowded to one side, a yard left open on the other. terrace: rows set square to a line of
## its own, not to the fire. lane: houses along a crooked lane from gate to gate. quarters: two knots of
## houses with open ground between.
const TOWN_STYLES := ["ring", "street", "cluster", "crescent", "terrace", "lane", "quarters"]
const TOWN_STYLE_OF := {"cinderwick": "cluster", "lanternwell": "crescent", "hesk": "street", "kiln": "terrace",
	"mourners": "ring", "gallowmere": "lane", "saltreach": "terrace", "emberhollow": "quarters", "lastlight": "crescent",
	"maud": "cluster", "tobin": "lane", "wren": "quarters"}


func town_style(k: String) -> String:
	return TOWN_STYLE_OF.get(k, TOWN_STYLES[absi(hash(k + "style")) % TOWN_STYLES.size()])


## Which way a town leans: the bearing its houses crowd toward (or its terrace is squared to).
func town_lean(k: String) -> float:
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(k + "lean")
	# Kept off the gate road, so the crowded side is to one hand of it
	return (PI if rr.randf() < 0.5 else 0.0) + rr.randf_range(-0.9, 0.9)


## How far out a town's wall stands at bearing a: no wall is a true ring. It runs in and out as the
## ground and the builders had it, full out only at its two gates.
func town_wall_r(k: String, a: float) -> float:
	var r: float = WPlaces.SETTLEMENTS[k].radius
	var h := absi(hash(k + "wall"))
	var p1 := float(h % 628) / 100.0
	var p2 := float((h / 628) % 628) / 100.0
	var p3 := float((h / 394384) % 628) / 100.0
	var bump := 0.5 + 0.25 * sin(a * 2.0 + p1) + 0.15 * sin(a * 3.0 + p2) + 0.1 * sin(a * 5.0 + p3)
	var lean := town_lean(k)
	bump = clampf(bump + 0.25 * cos(a - (lean + PI)), 0.0, 1.0)   # the open side is pulled in least
	var to_gate := minf(absf(wrapf(a - PI * 0.5, -PI, PI)), absf(wrapf(a + PI * 0.5, -PI, PI)))
	var g := smoothstep(0.12, 0.5, to_gate)
	return r * (1.0 - 0.2 * (1.0 - bump) * g)


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
		if off.length() + fr > town_wall_r(k, atan2(off.y, off.x)) - 2.5 or off.length() - fr < 5.5:
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
	# The inn first, toward the middle, on the side the town leans to (or across from it)
	var inn_a := town_lean(k) + (0.0 if style in ["crescent", "quarters", "lane"] else rr.randf_range(-1.2, 1.2))
	var inn_d := r * rr.randf_range(0.42, 0.55)
	for a0 in [0.0, 0.5, -0.5, 1.0, -1.0, PI, PI - 0.5, PI + 0.5, 1.5, -1.5]:
		var a: float = inn_a + a0
		var off := Vector2(cos(a), sin(a)) * inn_d
		if fits.call(off, inn_fr - 1.0):
			out.append({"kind": "inn", "off": off, "yaw": face_c.call(off), "w": 3, "d": 2, "fr": inn_fr - 1.0})
			break
	# Then the houses, of a few sizes
	var want := 8 + rr.randi() % 4
	if style in ["crescent", "quarters"]:
		want -= 1   # room left for the yard
	elif style == "terrace":
		want += 1
	var tries := 0
	while tries < 600 and out.size() < want + 1:
		tries += 1
		var w: int = [2, 2, 2, 3][rr.randi() % 4]
		var d: int = [2, 2, 3][rr.randi() % 3]
		var fr: float = foot.call(w * G, d * G) - 0.6
		var off := Vector2.ZERO
		var yaw := 0.0
		var lean := town_lean(k)
		match style:
			"crescent":
				# Crowded on one side; the other left open for a yard
				var a := lean + rr.randf_range(-1.8, 1.8)
				off = Vector2(cos(a), sin(a)) * r * rr.randf_range(0.3, 0.78)
				yaw = face_c.call(off) + rr.randf_range(-0.25, 0.25)
			"terrace":
				# Rows on a line of the town's own, each house square to it, back to back across a lane
				var ax := Vector2(cos(lean), sin(lean))
				var nx := Vector2(-ax.y, ax.x)
				var row := rr.randi_range(-2, 2)
				var col := rr.randi_range(-3, 3)
				off = ax * (col * (G * 2.0 + 2.5) + (row % 2) * 2.0) + nx * (row * (G * 2.0 + 3.5))
				yaw = atan2(nx.x, nx.y) + (PI if row % 2 == 0 else 0.0)
			"lane":
				# Along a crooked lane from the south gate to the north, bent to one side and back
				var t := rr.randf_range(-0.82, 0.82)
				var bend := (1.0 if lean < PI * 0.5 or lean > PI * 1.5 else -1.0) * r * 0.32
				var lane := Vector2(sin(t * PI) * bend, t * r)
				var tng := Vector2(cos(t * PI) * bend * PI / r, 1.0).normalized()
				var nrm := Vector2(-tng.y, tng.x) * (-1.0 if rr.randf() < 0.5 else 1.0)
				if absf(t) < 0.2:
					continue   # the square about the fire
				off = lane + nrm * rr.randf_range(6.5, 9.5)
				yaw = atan2(-nrm.x, -nrm.y) + rr.randf_range(-0.08, 0.08)
			"quarters":
				# Two knots of houses, open ground between
				var q := lean + (0.0 if rr.randf() < 0.6 else 2.3)
				var mid := Vector2(cos(q), sin(q)) * r * 0.52
				off = mid + Vector2(rr.randf_range(-1, 1), rr.randf_range(-1, 1)) * r * 0.32
				yaw = atan2(-(off - mid).x, -(off - mid).y) + rr.randf_range(-0.4, 0.4) if (off - mid).length() > 2.0 else rr.randf() * TAU
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
	# A town too tight for its way still has its homes: the rest put up wherever they fit
	var homes := out.filter(func(o): return o.kind == "house").size()
	tries = 0
	while homes < 7 and tries < 400:
		tries += 1
		var w: int = [2, 2, 3][rr.randi() % 3]
		var d: int = 2
		var fr: float = foot.call(w * G, d * G) - 0.6
		var a := rr.randf() * TAU
		var off := Vector2(cos(a), sin(a)) * r * rr.randf_range(0.3, 0.75)
		if fits.call(off, fr):
			out.append({"kind": "house", "off": off, "yaw": face_c.call(off) + rr.randf_range(-0.5, 0.5), "w": w, "d": d, "fr": fr})
			homes += 1
	# And what a town has besides: a smithy, a well, market stalls, a watchtower by the wall
	var extras := [["smithy", 3.2], ["well", 1.6], ["stall", 1.8], ["stall", 1.8], ["tower", 1.8]]
	if s.get("far", false) or s.has("shore"):
		extras = [["well", 1.6], ["stall", 1.8], ["tower", 1.8]]
	# A yard on the open side: a pen, a patch of ground worked for what will grow, the town's stores
	if style in ["crescent", "quarters", "terrace"]:
		var ya := town_lean(k) + PI + (1.15 if style == "quarters" else 0.0)
		for t in 8:
			var off := Vector2(cos(ya), sin(ya)) * r * (0.5 - t * 0.03)
			if fits.call(off, 4.0):
				out.append({"kind": "yard", "off": off, "yaw": face_c.call(off), "w": 1, "d": 1, "fr": 4.0})
				break
			ya += 0.25 * (1.0 if t % 2 == 0 else -1.0) * (t + 1)
	for ex in extras:
		for t in 60:
			var a := rr.randf() * TAU
			var dist: float = r * (rr.randf_range(0.82, 0.88) if ex[0] == "tower" else rr.randf_range(0.25, 0.6))
			var off := Vector2(cos(a), sin(a)) * dist
			var wr := town_wall_r(k, a)
			if ex[0] == "tower":
				off = off.normalized() * minf(off.length(), wr - float(ex[1]) - 1.2)
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
	if town_style(k) == "lane":
		# The crooked lane, gate to gate
		var bend := (1.0 if town_lean(k) < PI * 0.5 or town_lean(k) > PI * 1.5 else -1.0) * r * 0.32
		var pts := PackedVector2Array([c + Vector2(0, -r - 4.0)])
		for i in 11:
			var t := -0.9 + i * 0.18
			pts.append(c + Vector2(sin(t * PI) * bend, t * r))
		pts.append(c + Vector2(0, r + 4.0))
		terrain.add_road(pts, 3.2)
	else:
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
			# A prism's slope spans its x and its ridge runs along its z: the slope over the short side,
			# the ridge along the long one (turned a quarter when that long side is the house's x)
			pm.size = Vector3(D + 1.0, pitch, W + 1.0) if along_x else Vector3(W + 1.0, pitch, D + 1.0)
			roof.mesh = pm
			roof.material_override = _m.thatch if kind == 0 else _m.darkwood
			roof.position = Vector3(0, top + pitch * 0.5, 0)
			if along_x:
				roof.rotation.y = PI * 0.5
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
			WDress.kp(n, "scan", "barrel_03", Vector3(-1.7, 0, 1.2), rr.randf(), 1.0, true)
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
		"yard":
			# The open side of the town: a rail fence about worked ground, its gap toward the fire, and stores
			var half := 3.6
			for i in 9:
				var t := -half + i * half * 2.0 / 8.0
				for post in [Vector2(t, -half), Vector2(-half, t), Vector2(half, t)]:
					builder._part(n, fb, Vector3(0.14, 1.1, 0.14), Vector3(post.x, 0.5, post.y), _m.darkwood, false)
				if absf(t) > 1.2:
					builder._part(n, fb, Vector3(0.14, 1.1, 0.14), Vector3(t, 0.5, half), _m.darkwood, false)
			for h in [0.45, 0.9]:
				builder._part(n, fb, Vector3(half * 2.0, 0.08, 0.06), Vector3(0, h, -half), _m.wood, false)
				for side in [-1.0, 1.0]:
					builder._part(n, fb, Vector3(0.06, 0.08, half * 2.0), Vector3(side * half, h, 0), _m.wood, false)
					builder._part(n, fb, Vector3(half - 1.2, 0.08, 0.06), Vector3(side * (half + 1.2) * 0.5, h, half), _m.wood, false)
			for row in 5:
				var furrow := box(Vector3.ZERO, Vector3(half * 1.6, 0.12, 0.45), _m.darkwood, false)
				_add(n, furrow, Vector3(0, 0.02, -2.4 + row * 1.0))
			WDress.kp(n, "scan", "cement_bag", Vector3(half + 1.0, 0, -1.5), rr.randf() * TAU, 1.2)
			WDress.kp(n, "scan", "cement_bag", Vector3(half + 1.3, 0, -0.8), rr.randf() * TAU, 1.2)
			WDress.kp(n, "scan", "wooden_bucket_01", Vector3(-half - 0.8, 0, 1.0), 0.0, 1.0)
			WDress.kp(n, "scan", "barrel_03", Vector3(-half - 1.0, 0, -1.6), rr.randf() * TAU, 1.0, true)
			WDress.kp(n, "scan", "old_military_crate", Vector3(-half - 1.1, 0, -0.4), rr.randf() * TAU, 1.2, true)
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
		personal_interactable(bed, "Rent a bed (4 salt)", func(): inn_bed(k))
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
func inn_bed(k := "") -> void:
	if k != "" and int(rep.get(k, 0)) >= HONOUR_BED:
		hud.notify("\"No salt from you, %s. The bed is yours.\"" % honour_title(k))
		ui.ask_rest("inn")
		return
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
	var beam := landmark_column(Color(1.0, 0.86, 0.6, 0.3), 260.0, 1.3, true)
	beam.position = Vector3(0, 142, 0)
	beam.visible = false
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
	# A second place at the bowl's foot: an ember to carry, for a fellowship of two or more
	var ea := Area3D.new()
	ea.collision_layer = 16
	ea.collision_mask = 0
	var ecs := CollisionShape3D.new()
	var esh := SphereShape3D.new()
	esh.radius = 0.8
	ecs.shape = esh
	ea.add_child(ecs)
	ea.position = Vector3(2.2, 0.8, 0)
	n.add_child(ea)
	personal_interactable(ea, "", func(): _ember_take(i))
	# A dead beacon is a goal on the horizon: a thin column of red smoke that stands over the waste
	var dark := landmark_column(Color(0.75, 0.22, 0.12, 0.16), 220.0, 0.9)
	dark.position = Vector3(0, 122, 0)
	n.add_child(dark)
	beacon_nodes.append({"node": n, "flame": flame, "light": light, "beam": beam, "area": a, "pos": c, "dark": dark, "ember_area": ea})
	_beacon_prompt(i)


func _beacon_prompt(i: int) -> void:
	if beacon_nodes.size() <= i:
		return
	var a: Area3D = beacon_nodes[i].area
	var ea: Area3D = beacon_nodes[i].get("ember_area")
	if ea:
		ea.set_meta("prompt", "Take an ember to a dark beacon (needs an escort)" if i in lit and ember_by == 0 and next_dark_beacon(beacon_nodes[i].pos) >= 0 else "")
	if ember_by == Net.me() and not i in lit and not vigils.has(i):
		a.set_meta("prompt", "Kindle the beacon with the ember")
		return
	if i in lit and flame_of(i) < 0.95 and i in my_kindled():
		a.set_meta("prompt", "Tend the flame (lamp oil): it burns low")
	elif i in lit:
		a.set_meta("prompt", "Walk the beacon road" if i in my_kindled() else "Keep a vigil here (its boon is yours)")
	elif vigils.has(i):
		a.set_meta("prompt", "")
	elif not key_for(i).is_empty():
		a.set_meta("prompt", "The bowl is fouled: it wants %s" % ["Deep Oil", "the Fleet Log", "a far great one's heart", "three far coals"][fire_for(i) - 6])
	else:
		a.set_meta("prompt", "Kindle the beacon (Beacon Oil)")


func _beacon_touched(i: int) -> void:
	if i in lit:
		if not i in my_kindled():
			# Lit by the fellowship while this pilgrim was elsewhere: a vigil here keeps its credit
			_keep_credit(i)
			award("beacon", 0.5)
			hud.notify("You keep a vigil at %s. Its credit is yours now." % WPlaces.BEACONS[i].name)
			char_save_soon()
			_beacon_prompt(i)
			return
		if not skills.boon_offer.is_empty():
			ui.open_boons(WPlaces.BEACONS[i].name)
			return
		if flame_of(i) < 0.95:
			tend_beacon(i)   # the Second Vow: a guttering fire is fed, not kindled again
			return
		ui.open_travel()
		return
	if vigils.has(i):
		return
	if i == 8 and lit.size() < 8:
		hud.say("The ninth bowl will not take even an ember while any other beacon stands dark." if ember_by == Net.me() else "The ninth bowl is choked with black earth. It will not take a flame while any other beacon stands dark.", 5.0)
		return
	# After the turn the Mouth's breath fouls the dark bowls: each wants a key from beyond the shore
	var key := key_for(i)
	if not key.is_empty() and not _has_key(key):
		hud.say("The Mouth has breathed on this bowl. It is fouled, and will not take %s until %s goes in first." % ["an ember" if ember_by == Net.me() else "oil", key_text(i)], 6.0)
		return
	var paid: Array = _pay_key(key)
	if ember_by == Net.me():
		shared("_rq_ember_kindle", [Net.me(), i, paid])
		return
	if inv.count("beacon_oil") <= 0:
		give(paid)
		hud.say("The bowl is cold and dry. It wants beacon oil, rendered in the old measure.", 4.5)
		return
	inv.take("beacon_oil", 1)
	shared("_rq_kindle", [Net.me(), i, skills.vigil_mult(), paid])


func _rq_kindle(by: int, i: int, vm := 1.0, key: Array = []) -> void:
	if not Net.authority():
		return
	var paid: Array = [["beacon_oil", 1]] + key
	if i in lit or vigils.has(i) or not _key_fits(i, key):
		Net.call_peer(by, "_w_give", [paid])   # someone was there first, or the key is not the one: it all goes back
		return
	var t := (90.0 if i < 8 else 150.0) * clampf(vm, 0.7, 1.0)
	vigil_paid[i] = {"by": by, "items": paid}
	if second_front(beacon_nodes[i].pos, false, i) != null:
		t = maxf(t, FRONT_VIGIL)   # both halves need time: the defenders to ride back, the bowl to hold
	shared("_w_vigil", [i, t])


const FRONT_AT := 5
const FRONT_VIGIL := 240.0   ## a vigil with a second front lasts at least this long
const FRONT_CAP := 480.0     ## and a front is held after this long whatever is left of it
var fronts := {}             ## host: vigil (beacon) -> {at, t, want, came, fought}
var vigil_paid := {}         ## host: vigil (beacon) -> {by, items}: given back if the flame gutters

## Host: which pilgrim a target is (the host's own player, or a friend's avatar).
func pid_of(t: Node3D) -> int:
	if t == player:
		return Net.me()
	for id in avatars:
		if avatars[id] == t:
			return int(id)
	return 0


## Host: a front is held once its raid has all come and no raider stands in the camp's ground, or at the cap.
func _front_held(i: int) -> bool:
	if not fronts.has(i):
		return true
	var f: Dictionary = fronts[i]
	if float(f.t) >= FRONT_CAP:
		return true
	if int(f.came) < int(f.want):
		return false
	for e in enemies:
		if is_instance_valid(e) and e.is_alive() and e.has_meta("raid") and e.global_position.distance_to(f.at) < BASE_SAFE + 30.0:
			return false
	return true


## Host: those in the camp's ground while its front is fought share in the beacon's credit.
func _front_tick(i: int, delta: float) -> void:
	if not fronts.has(i):
		return
	var f: Dictionary = fronts[i]
	f.t = float(f.t) + delta
	if _front_held(i):
		if not f.get("held", false):
			f.held = true
			shared("_w_note", ["The camp is held. Back to the beacon."])
		return
	for t in targets():
		if t.global_position.distance_to(f.at) < BASE_SAFE + 30.0:
			var id := pid_of(t)
			if id != 0:
				f.fought[id] = true   ## pilgrims in the fellowship before a vigil opens a second front

## A fellowship of five or more is big enough to split: while the vigil burns, the forms fall on the
## camp nearest it as well, so some must ride back to hold it. Returns the camp's place, or null.
func second_front(vigil_at: Vector3, force := false, vi := -1):
	if not Net.authority() or (Net.pilgrims().size() < FRONT_AT and not force):
		return null
	var best := -1
	var bd := 1500.0
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		if pc.kind != "campfire" or raiding.has(pid):
			continue
		var d: float = pc.pos.distance_to(vigil_at)
		if d > 120.0 and d < bd:
			bd = d
			best = pid
	if best < 0:
		return null
	var c: Vector3 = pieces[best].pos
	raiding[best] = 120.0
	shared("_w_front", [c])
	var roster: Array = forms_at(c)
	var want: int = WCrowd.scale(self, 6 + mini(nights, 6))
	var f := {"at": c, "t": 0.0, "want": want, "came": 0, "fought": {}}
	if vi >= 0:
		fronts[vi] = f
	for k in want:
		get_tree().create_timer(randf_range(8.0, 40.0), false).timeout.connect(func():
			if is_instance_valid(self):
				f.came = int(f.came) + 1
				var e = _spawn_near(roster[randi() % roster.size()], c, BASE_SAFE - 12.0, BASE_SAFE + 6.0, true)
				if e:
					e.set_meta("raid", true))
	return c


func _w_front(at: Vector3) -> void:
	sfx("bell", -2)
	var d := int(player.global_position.distance_to(at))
	hud.alert_banner("A second front", "While the beacon burns, your camp %d m away is attacked. Send some back to hold it." % d if d > 40 else "Your camp is attacked. Hold it while the others keep the vigil.")


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


## who: the pilgrims the host credits (near the bowl as it caught, or fought at its front); null for the old reckoning.
func _w_vigil_end(i: int, ok: bool, who = null) -> void:
	vigils.erase(i)
	if ok:
		award("beacon")
		if music:
			music.beacon_swell()
	var b: Dictionary = beacon_nodes[i]
	if ok:
		var most0 := most_lit()
		if not i in lit:
			lit.append(i)
		flags["clean_%d" % i] = true   # its key went in: it stays clean, even if the fire goes out
		flags["most_lit"] = maxi(int(flags.get("most_lit", 0)), lit.size())
		if most_lit() > most0:
			_verb_gained(most_lit())
		_light_beacon(i, true)
		sfx("choir", 0, b.pos)
		if player.global_position.distance_to(b.pos) < 200.0:
			hud.say("%s burns again. The night will not come within sight of it." % WPlaces.BEACONS[i].name, 6.0)
		else:
			hud.notify("%s has been kindled." % WPlaces.BEACONS[i].name)
		quests.on_event("lit", {"beacon": i})
		if Net.authority():
			_clear_near(b.pos, WPlaces.BEACON_SAFE)
		_beacon_payoff(i, who)
		if lit.size() >= TURN_AT and not flags.has("turned"):
			get_tree().create_timer(9.0, false).timeout.connect(_the_turn)
	else:
		b.flame.visible = false
		b.light.light_energy = 0.0
		hud.notify("The flame at %s guttered out. What was poured goes back to the one who poured it." % WPlaces.BEACONS[i].name)
	_beacon_prompt(i)


# ------------------------------------------------------------------ what each fire lets you do

## Each fire, counted by the most that have ever burned in the world, opens a new thing to do (gameplay
## bible: "every milestone pays with a new verb"). World things go by the world's count; boons stay personal.
const FIRE_VERBS := {
	1: ["Ride", "Strays come near the towns. Feed one meat three times and it is yours to ride."],
	2: ["Survey", "From a high place you see ruins and lairs far off, and they go on your map."],
	3: ["Grow", "Planter boxes can be built: seeds, and fields of your own."],
	4: ["Travel", "Waystones can be built: two of one name lead to each other."],
	5: ["Sail", "The Sloop-wright's book: the sloop can be made at a bench."],
	6: ["Voyage", "The Longboat-wright's book: eight seats, for long voyages."],
	7: ["Discern", "Hidden and unseen enemies near you show on your compass."],
	8: ["Bulwark", "Each night, the beacons' blessing takes the first blow that would land on you."],
	9: ["Choose", "The Ferryman's Way is open: go down to the Tenth Hall."],
}
const VERB_BOOKS := {5: "book_ship", 6: "book_longboat"}
var bulwark_spent := false
var quick_camp_spent := false


func has_verb(fire: int) -> bool:
	return most_lit() >= fire


# ------------------------------------------------------------------ the Second Vow and the Keeping

## Under the Second Vow the lit fires gutter: each burns down over three days to a third, never lower, and
## its ground shrinks with it. A pilgrim tends it with lamp oil: no vigil, no gift, no key.
const TEND_HOURS := 72.0

func flame_of(i: int) -> float:
	if not flags.has("second_vow") or not i in lit:
		return 1.0
	var since: float = world_hours() - float(flags.get("tended_%d" % i, flags.get("vow_at", world_hours())))
	return clampf(1.0 - since / TEND_HOURS * (2.0 / 3.0), 1.0 / 3.0, 1.0)


## The vow's weight: lighter on the Far Shores, which are already hard enough.
func vow_mult(p: Vector3, m: float) -> float:
	if not flags.has("second_vow"):
		return 1.0
	return 1.15 if land_at(p) in FAR_SHORE_LANDS else m


func tend_beacon(i: int) -> void:
	if inv.count("oil") <= 0:
		hud.notify("The flame wants lamp oil.")
		return
	inv.take("oil", 1)
	shared("_w_tended", [i, world_hours(), Net.me()])


func _w_tended(i: int, at: float, by: int) -> void:
	flags["tended_%d" % i] = at
	if i < beacon_nodes.size():
		sfx("choir", -10, beacon_nodes[i].pos, 1.3)
		_beacon_prompt(i)
	if by == Net.me():
		hud.notify("You tend %s. It burns high again." % WPlaces.BEACONS[i].name)
		award("beacon", 0.1)
	autosave_soon(3.0)


## After an ending, or under the Second Vow, the waste is kept, not finished: now and then at dawn a great
## one leaves its ring and walks abroad in its own land, and the fellowship hears of it.
const ROAM_CHANCE := 0.35

func keeping() -> bool:
	return flags.has("ending") or flags.has("second_vow")


func _roam_great() -> void:
	if not Net.authority() or not keeping() or randf() > ROAM_CHANCE:
		return
	var ready: Array = lairs.filter(func(l): return lair_ready(l) and _lair_boss.get(l.id) == null)
	if ready.is_empty():
		return
	var l: Dictionary = ready[randi() % ready.size()]
	var land := land_at(l.pos)
	for tries in 30:
		var a := randf() * TAU
		var q: Vector3 = l.pos + Vector3(cos(a), 0, sin(a)) * randf_range(200.0, 350.0)
		q = gpos(Vector2(q.x, q.z))
		if terrain.is_water(q.x, q.z, 0.3) or land_at(q) != land or gentle_at(q) or settlement_at(q, 120.0) != "" or base_at(q, 60.0) >= 0:
			continue
		var b := spawn_at(l.boss, q + Vector3(0, 2.0, 0))
		if b:
			_lair_boss[l.id] = b
			shared("_w_roam_great", [l.boss, q])
		return


func _w_roam_great(b: String, at: Vector3) -> void:
	reveal_place(Vector2(at.x, at.z), 60.0)
	if Net.dedicated:
		return
	hud.alert_banner("%s walks abroad" % LesserSpeeb.BOSSES[b].name, "It has left its ring and walks its own land. It is on your map.")


# ------------------------------------------------------------------ completion: the bestiary and the map

## Every quarter of the bestiary filled, and of the map walked, pays (the Keeping: something to finish).
const COMPLETE_GIFTS := {25: [["fittings_rare", 1], ["salt", 100]], 50: [["fittings_storied", 1], ["salt", 200]],
	75: [["fittings_storied", 2], ["salt", 300]], 100: [["fittings_storied", 3], ["tempered", 4], ["clockwork", 4]]}
var _bestiary_total := 0

func bestiary_total() -> int:
	if _bestiary_total == 0:
		var all := {}
		for b in BIOME_FORMS:
			for k in BIOME_FORMS[b]:
				all[k] = true
		for il in WIsles.THEMES:
			for k in WIsles.THEMES[il].get("forms", []):
				all[k] = true
		_bestiary_total = all.size()
	return maxi(1, _bestiary_total)


func bestiary_pct() -> int:
	return mini(100, int(100.0 * slain_kinds.size() / bestiary_total()))


## The share of the map walked or seen, as a percentage of the land (the sea is most of it, so it is
## counted against the land the waste and its isles hold: about a third of the whole).
func map_pct() -> int:
	if revealed.is_empty():
		return 0
	var seen := revealed.size() - revealed.count(0)
	return mini(100, int(100.0 * seen / (revealed.size() * 0.33)))


func _completion_check() -> void:
	if Net.dedicated or not ready_world:
		return
	for what in [["beast", bestiary_pct(), "the bestiary"], ["map", map_pct(), "the map"]]:
		for q in COMPLETE_GIFTS:
			var key := "%s_%d" % [what[0], q]
			if int(what[1]) >= int(q) and not rewards_had.has(key):
				rewards_had[key] = true
				give(COMPLETE_GIFTS[q])
				hud.alert_banner("%d%% of %s" % [q, what[2]], "A reward for it is in your pack.")
				char_save_soon()


var rewards_had := {}   ## the completion rewards this pilgrim has had


## A fire beyond any before it: what it opens, for everyone.
func _verb_gained(n: int) -> void:
	_verb_books()
	if not FIRE_VERBS.has(n) or Net.dedicated:
		return
	var v: Array = FIRE_VERBS[n]
	get_tree().create_timer(7.0, false).timeout.connect(func():
		if is_instance_valid(hud):
			hud.alert_banner("A new way: %s" % v[0], v[1]))


## The books the fires bring are known to the world, also in a world lit before they were.
func _verb_books() -> void:
	for f in VERB_BOOKS:
		if has_verb(f) and not flags.has(VERB_BOOKS[f]):
			flags[VERB_BOOKS[f]] = true
			flags["found_" + VERB_BOOKS[f]] = true


## The Rallying Cry: those near get their breath back and a burst of speed.
var _rally_cd := 0.0
const RALLY_REACH := 20.0
const RALLY_CD := 60.0

func rally() -> void:
	if _rally_cd > 0.0:
		hud.notify("Your voice is spent. Again in %d seconds." % ceili(_rally_cd))
		return
	_rally_cd = RALLY_CD
	shared("_w_rally", [Net.me(), player.global_position])


var rally_burst := 0.0   ## seconds of the rally's speed left
func _w_rally(by: int, at: Vector3) -> void:
	if Net.dedicated or player.global_position.distance_to(at) > RALLY_REACH:
		return
	sfx("choir", -8, at, 1.6)
	player.stamina = player.stamina_max
	rally_burst = 6.0
	player.walk_speed = 3.4 * skills.speed_mult() * 1.25
	player.run_speed = 5.8 * skills.speed_mult() * 1.25
	hud.notify("You rally to %s." % ("the cry" if by == Net.me() else Net.name_of(by)))


## The Lantern-bearer: who carries a lit lantern and the boon (peer -> true); the dread does not rise near them.
var bearers := {}
var _bearing := false
const BEARER_REACH := 15.0

func _w_bearer(by: int, on: bool) -> void:
	if on:
		bearers[by] = true
	else:
		bearers.erase(by)


func near_bearer(p: Vector3) -> bool:
	for id in bearers:
		var who: Node3D = player if id == Net.me() else avatars.get(id)
		if who and is_instance_valid(who) and who.global_position.distance_to(p) < BEARER_REACH:
			return true
	return false


## Survey (the second fire): from a high place, ruins and lairs within sight go on the map.
var _renown_t := 0.0
var _renown_sent := -1
var _hall_t := 0.0
var _hall_keys := {}   ## the powers the trophy halls about you give, key -> true


# ------------------------------------------------------------------ the trophy hall

## Up to three trophies hang in a hall (five with renown), one of each kind; each gives a third of its
## power to anyone at that base. Never both: a pilgrim who takes up the power at the shrine has that
## instead (the stronger), not the two together. Gilded Skin and the Watcher's Eye are weaker still here.
const HALL_REACH := 60.0
const HALL_K := {"eye": 0.25, "gilt": 0.25}
const HALL_FORMS := {
	"ember": "The frost bites less: a coat is warm enough.",
	"hush": "Enemies see you a little less far.",
	"white": "Running and swinging cost a sixth less breath.",
	"eye": "Your blows strike a twentieth harder.",
	"gilt": "Blows on you are a twentieth lighter.",
	"tar": "You drown more slowly.",
	"lens": "Enemies within 20 m show on your compass.",
	"hook": "The dread rises a third more slowly.",
	"rime": "A third of your blows freeze weaker enemies a moment.",
	"dry": "Heat harms you half as much.",
	"horn": "Your cat tires a third more slowly.",
	"bell": "Every twenty-fourth blow you land rings, twice as hard.",
}

## The powers the halls near a point give, as key -> true.
func halls_here(p: Vector3) -> Dictionary:
	var out := {}
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		if pc.kind != "trophy_hall" or pc.pos.distance_to(p) > HALL_REACH:
			continue
		for t in pc.get("hung", []):
			if POWERS.has(t):
				out[str(POWERS[t].key)] = true
	return out


## How strongly a power works on this pilgrim: 1 with it taken up at the shrine, a third (or less) from a
## hall nearby, else 0. The stronger, never the sum.
func power_k(k: String) -> float:
	if power_is(k):
		return 1.0
	return float(HALL_K.get(k, 1.0 / 3.0)) if _hall_keys.has(k) else 0.0


## A pilgrim hangs a trophy from their pack (on), or takes one down into it.
func hang_trophy(pid: int, t: String, on: bool) -> void:
	if on:
		if inv.take(t, 1) < 1:
			return
	shared("_rq_hang", [Net.me(), pid, t, on, skills.hall_places()])


func _rq_hang(by: int, pid: int, t: String, on: bool, places: int) -> void:
	if not Net.authority():
		return
	var pc: Dictionary = pieces.get(pid, {})
	if pc.is_empty() or pc.kind != "trophy_hall" or not POWERS.has(t):
		if on:
			Net.call_peer(by, "_w_give", [[[t, 1]]])
		return
	var hung: Array = pc.get("hung", []).duplicate()
	if on:
		if t in hung or hung.size() >= clampi(places, 3, 5):
			Net.call_peer(by, "_w_give", [[[t, 1]]])   # one of each, and only so many places
			return
		hung.append(t)
	else:
		if not t in hung:
			return
		hung.erase(t)
		Net.call_peer(by, "_w_give", [[[t, 1]]])
	shared("_w_hang", [pid, hung])


func _w_hang(pid: int, hung: Array) -> void:
	if not pieces.has(pid):
		return
	pieces[pid]["hung"] = hung.duplicate()
	var n: Node3D = pieces[pid].node
	if is_instance_valid(n) and n.has_meta("marks"):
		var marks: Array = n.get_meta("marks")
		for i in marks.size():
			var g: MeshInstance3D = marks[i]
			g.visible = i < hung.size()
			if g.visible:
				var gm := StandardMaterial3D.new()
				gm.albedo_color = Items.info(hung[i]).color
				gm.emission_enabled = true
				gm.emission = Items.info(hung[i]).color
				gm.emission_energy_multiplier = 0.6
				g.material_override = gm
		(n.get_meta("light") as OmniLight3D).light_energy = 0.8 if not hung.is_empty() else 0.0
	_hall_keys = halls_here(player.global_position) if player else {}
	if is_instance_valid(ui):
		ui.planter_changed(pid)
	autosave_soon(3.0)


var _survey_t := 0.0
var _surveyed := {}
var _books_checked := false
var _map_t := 30.0
const SURVEY_SIGHT := 600.0

func _verbs_tick(delta: float) -> void:
	if rally_burst > 0.0:
		rally_burst -= delta
		if rally_burst <= 0.0:
			_apply_skills()
	_rally_cd = maxf(0.0, _rally_cd - delta)
	_renown_t -= delta
	if _renown_t <= 0.0 or _renown_sent != skills.renown:
		_renown_t = 30.0   # now and then, for those who joined since
		_renown_sent = skills.renown
		if Net.online:
			shared("_w_renown", [Net.me(), skills.renown])
	_hall_t -= delta
	if _hall_t <= 0.0:
		_hall_t = 1.0
		_hall_keys = halls_here(player.global_position)
	if ready_world and not _books_checked:
		_books_checked = true
		_verb_books()   # a world lit before the books came with the fires
	var bear: bool = skills.has_boon("lantern") and player.relics != null and player.relics.lantern_lit
	if bear != _bearing:
		_bearing = bear
		shared("_w_bearer", [Net.me(), bear])
	_survey_t -= delta
	if _survey_t > 0.0:
		return
	_survey_t = 3.0
	_feast_tick()
	_map_t -= 3.0
	if _map_t <= 0.0:
		_map_t = 60.0
		_completion_check()
	if not has_verb(2) or Net.dedicated or player.vessel != null:
		return
	for pid in pieces:
		if pieces[pid].kind == "portal":
			_portal_look(pid)   # a link wakes or dims as beacons and lanes are lit or go dark
	var p := player.global_position
	var cell := Vector2i(int(p.x / 250.0), int(p.z / 250.0))
	if _surveyed.has(cell) or not high_point(p):
		return
	_surveyed[cell] = true
	var n := 0
	for r in ruins:
		var q: Vector3 = r.pos
		if q.distance_to(p) < SURVEY_SIGHT and not is_revealed(q):
			reveal_place(Vector2(q.x, q.z), 40.0)
			n += 1
	for l in lairs:
		if l.pos.distance_to(p) < SURVEY_SIGHT and not is_revealed(l.pos):
			reveal_place(Vector2(l.pos.x, l.pos.z), 50.0)
			n += 1
	if n > 0:
		sfx("bell", -16, null, 1.8)
		hud.notify("From the height you survey the land: %d place%s marked on your map." % [n, "" if n == 1 else "s"])


## A high place: well above the ground all round, 150 m out.
func high_point(p: Vector3) -> bool:
	if terrain == null:
		return false
	var h: float = terrain.height_at(p.x, p.z)
	var sum := 0.0
	for k in 8:
		var a := k * TAU / 8.0
		sum += terrain.height_at(p.x + cos(a) * 150.0, p.z + sin(a) * 150.0)
	return h - sum / 8.0 >= 16.0


# ------------------------------------------------------------------ the turn

## The fifth beacon is the turn of the game (Terraria's Hardmode): the sea opens. The whirlpool of the
## Kraken-Bell stands on the horizon, the far isles show through the fog, the seventh night comes up out
## of the water, and the waste's own forms grow bolder (champions in every land past the first ring).
const TURN_AT := 5
var _turn_col: MeshInstance3D = null

func turned() -> bool:
	return flags.has("turned")


func _the_turn() -> void:
	if not is_instance_valid(self) or turned():
		return
	flags["turned"] = true
	sfx("choir", 0)
	hud.alert_banner("The sea opens", "Five fires burn, and the dark has turned to face the sea. The whirlpool and the far isles show on the horizon. From now on the seventh night comes up out of the water.")
	_turn_marks()
	autosave_soon(1.0)


## The fouled bowls. After the turn the Mouth breathes on every bowl that has never burned; each takes oil only
## once its key goes in. Keys go by the most fires that have ever burned in the world, never by which beacon.
const HEARTS := ["heart_quiet", "heart_domes", "heart_frost", "heart_sun", "heart_steppe"]
const COALS := ["coal_frost", "coal_sun", "coal_steppe"]

func most_lit() -> int:
	return maxi(int(flags.get("most_lit", 0)), lit.size())


func fouled(i: int) -> bool:
	return turned() and not i in lit and not flags.has("clean_%d" % i)


## The fire a fouled bowl would be: the next after the most that ever burned (six to nine).
func fire_for(i: int) -> int:
	return 9 if i == 8 else clampi(most_lit() + 1, TURN_AT + 1, 8)


## What a bowl wants before its oil: [] for none, else a list of [item, n] (a heart is any one of five).
func key_for(i: int) -> Array:
	if not fouled(i):
		return []
	match fire_for(i):
		6:
			return [["deep_oil", 1]]
		7:
			return [["fleet_log", 1]]
		8:
			return [["heart", 1]]
	return COALS.map(func(c): return [c, 1])


func key_text(i: int) -> String:
	match fire_for(i):
		6:
			return "Deep Oil (lamp oil and the Bell-Wound's ichor, rendered at a bench)"
		7:
			return "the Fleet Log from Quietglass"
		8:
			return "the heart of a far great one"
	return "three far coals, one from the shrine-bowl of each Far Shore"


func _has_key(key: Array) -> bool:
	for k in key:
		if k[0] == "heart":
			if not HEARTS.any(func(h): return inv.count(h) > 0):
				return false
		elif inv.count(k[0]) < int(k[1]):
			return false
	return true


## Takes the key from the pack; returns what was taken, to be given back if the vigil fails.
func _pay_key(key: Array) -> Array:
	var out: Array = []
	for k in key:
		var id: String = k[0]
		if id == "heart":
			for h in HEARTS:
				if inv.count(h) > 0:
					id = h
					break
		inv.take(id, int(k[1]))
		out.append([id, int(k[1])])
	return out


## Host: whether what was paid is the key this bowl wants.
func _key_fits(i: int, paid: Array) -> bool:
	var want := key_for(i)
	if want.is_empty():
		return true
	for k in want:
		var ok := false
		for p in paid:
			if (k[0] == "heart" and p[0] in HEARTS) or p[0] == k[0]:
				ok = int(p[1]) >= int(k[1])
		if not ok:
			return false
	return true


## What a pilgrim holding nothing for it is told to fetch, and where (for What now and the compass).
func key_hint(i: int) -> Array:
	match fire_for(i):
		6:
			if inv.count("bell_ichor") > 0:
				return ["Render Deep Oil at a workbench: two lamp oil and the Bell-Wound's ichor.", null]
			return ["Bring down the Bell-Wound at the Kraken-Bell for its ichor.", kraken.spot if kraken and kraken.spot != Vector3.INF else null]
		7:
			for il in terrain.isles:
				if il.key == "quiet":
					return ["Light the lane to Quietglass and search it for the Fleet Log." if lights == null or not lights.lane_lit("quiet") else "Search the ruins of Quietglass for the Fleet Log.", gpos(il.c)]
		8:
			var best = null
			for l in lairs:
				if l.land in ["quiet", "domes", "frost", "sun", "steppe"] and (best == null or player.global_position.distance_to(l.pos) < player.global_position.distance_to(best)):
					best = l.pos
			return ["Bring down a far great one for its heart.", best]
	for c in COALS:
		if inv.count(c) <= 0:
			for sb in shrine_bowls:
				if sb.coal == c:
					return ["Carry a coal home from the shrine-bowl of %s." % sb.name, sb.pos]
	return ["", null]


## The shrine-bowls of the Far Shores: lit once with lamp oil, each gives a coal to carry home (one of each is the
## ninth fire's key). Taking one again later is free, so the key can always be had again.
var shrine_bowls: Array = []   ## {land, coal, name, pos, flame}

func _build_shrine_bowls() -> void:
	for il in terrain.isles:
		var coal := "coal_" + str(il.key)
		if not coal in COALS:
			continue
		var h: Vector2 = terrain.isle_heart(il)
		var q: Vector2 = h + (Vector2(il.c) - h).normalized().rotated(1.2) * 22.0 if Vector2(il.c).distance_to(h) > 1.0 else h + Vector2(22, 0)
		var at := gpos(q)
		var n := Node3D.new()
		add_child(n)
		n.global_position = at
		var stone := mat(Color(0.42, 0.4, 0.38), 0.9)
		_add(n, cyl(Vector3.ZERO, 0.7, 1.0, stone), Vector3(0, 0.5, 0))
		_add(n, cyl(Vector3.ZERO, 1.1, 0.25, stone, false), Vector3(0, 1.1, 0))
		var flame := OmniLight3D.new()
		flame.light_color = Color(1.0, 0.6, 0.3)
		flame.omni_range = 9.0
		flame.position = Vector3(0, 1.8, 0)
		n.add_child(flame)
		var a := Area3D.new()
		a.collision_layer = 16
		a.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 2.0
		cs.shape = sh
		a.add_child(cs)
		n.add_child(a)
		a.position = Vector3(0, 1.0, 0)
		var sb := {"land": str(il.key), "coal": coal, "name": str(il.name), "pos": at, "flame": flame, "area": a}
		shrine_bowls.append(sb)
		personal_interactable(a, "", func(): _shrine_bowl_used(sb))
		_shrine_bowl_show(sb)


func _shrine_bowl_show(sb: Dictionary) -> void:
	var on := flags.has("shrine_" + str(sb.land))
	(sb.flame as OmniLight3D).light_energy = 2.5 if on else 0.0
	(sb.area as Area3D).set_meta("prompt", "Take a coal from the shrine-bowl" if on else "Light the shrine-bowl (1 lamp oil)")


func _shrine_bowl_used(sb: Dictionary) -> void:
	if not flags.has("shrine_" + str(sb.land)):
		if inv.count("oil") < 1:
			hud.notify("The shrine-bowl is cold. It wants lamp oil.")
			return
		inv.take("oil", 1)
		shared("_w_flag", ["shrine_" + str(sb.land)])
		sfx("bell", -4, sb.pos)
		hud.say("The old bowl takes the oil, and a white coal wakes in the ash.", 4.0)
		for b in shrine_bowls:
			_shrine_bowl_show(b)
	if inv.count(sb.coal) > 0:
		hud.notify("You carry one of its coals already.")
		return
	give([[sb.coal, 1]])
	hud.notify("You take a coal from the shrine-bowl of %s. Carry it home across the sea." % sb.name)


## What the turn shows: the whirlpool's spray on the horizon, and the far sea on the map.
func _turn_marks() -> void:
	if not turned() or Net.dedicated:
		return
	if kraken and kraken.spot != Vector3.INF:
		reveal_place(Vector2(kraken.spot.x, kraken.spot.z), 120.0)
		if _turn_col == null:
			_turn_col = landmark_column(Color(0.55, 0.62, 0.66, 0.18), 240.0, 1.8)
			add_child(_turn_col)
			_turn_col.global_position = kraken.spot + Vector3(0, 110.0, 0)
	for il in terrain.isles:
		if WIsles.THEMES.has(il.key) and bool(WIsles.THEMES[il.key].get("far", false)):
			reveal_place(il.c, float(il.r) * 0.6)


## What a kindled beacon gives every pilgrim: a gift from its bowl, a boon to choose, and the way
## to the next dark beacon shown on the map.
const BEACON_GIFT := [["tempered", 1], ["clockwork", 1], ["fittings_fine", 2], ["salt", 40]]

func _beacon_payoff(i: int, who = null) -> void:
	if Net.dedicated or _pfail:
		return
	var n := lit.size()
	# World credit and personal credit: the beacon burns for everyone, but its boon and full gift
	# are for those who stood near when it caught
	var there: bool = (Net.me() in (who as Array)) if who is Array else player.global_position.distance_to(beacon_nodes[i].pos) < BEACON_THERE
	var gift: Array = []
	for g in BEACON_GIFT:
		gift.append([g[0], maxi(1, int(int(g[1]) * (1 + n / 3) * (2 if WRules.sworn("vow_tithe") else 1) * (1.0 if there else 0.5)))])
	if i == 8 and there:
		gift.append(["fittings_storied", 1])
	give(gift)
	if there:
		_keep_credit(i)
	else:
		get_tree().create_timer(4.0, false).timeout.connect(func():
			if is_instance_valid(hud):
				hud.notify("You were not there when it caught. Stand at %s yourself to keep its boon." % WPlaces.BEACONS[i].name))
	_reveal_around(beacon_nodes[i].pos, BEACON_SIGHT)   # from the bowl you see the land about, and it is on your map
	var next := next_dark_beacon(beacon_nodes[i].pos)
	if next >= 0:
		reveal_place(WPlaces.bpos(next), 60.0)
		hud.notify("From the bowl you can see the next dark beacon: %s. It is on your map." % WPlaces.BEACONS[next].name)
		# Beyond it, the land's great one: its lair's smoke stands on the horizon
		var lair := lair_seen_from(WPlaces.bpos(next))
		if not lair.is_empty():
			reveal_place(Vector2(lair.pos.x, lair.pos.z), 50.0)
			get_tree().create_timer(6.0, false).timeout.connect(func():
				if is_instance_valid(hud):
					hud.notify("Past it, purple smoke on the horizon: the %s. It is on your map too." % str(lair.name)))
	hud.title_card("%d of 9" % n, "%s burns again" % WPlaces.BEACONS[i].name)
	autosave_soon(1.0)
	char_save_soon()


# ------------------------------------------------------------------ the ember run (two or more)
## One of the fellowship carries an ember from a lit beacon to a dark one: no oil is needed and the
## vigil is short, but the carrier cannot shoot and walks slower, and the waste comes for the ember.
## The others are the escort.
var ember_by := 0          ## the peer carrying an ember, or 0
var ember_from := -1
var _ember_light: OmniLight3D
var _ember_t := 0.0
const EMBER_VIGIL := 45.0


func _ember_take(i: int) -> void:
	if not i in lit or ember_by != 0:
		return
	if avatars.is_empty():
		hud.notify("An ember needs an escort. Bring someone with you.")
		return
	shared("_rq_ember", [Net.me(), i])


func _rq_ember(by: int, i: int) -> void:
	if not Net.authority() or ember_by != 0 or not i in lit:
		return
	shared("_w_ember", [by, i])


func _w_ember(by: int, i: int) -> void:
	ember_by = by
	ember_from = i
	_ember_t = 0.0
	var carrier: Node3D = player if by == Net.me() else avatars.get(by)
	if is_instance_valid(_ember_light):
		_ember_light.queue_free()
	if is_instance_valid(carrier):
		_ember_light = OmniLight3D.new()
		_ember_light.light_color = Color(1.0, 0.55, 0.2)
		_ember_light.light_energy = 2.5
		_ember_light.omni_range = 7.0
		_ember_light.position = Vector3(0, 1.2, 0)
		carrier.add_child(_ember_light)
	if by == Net.me():
		player.weapon.hands_full = true
		hud.notify("You carry an ember from %s. You cannot shoot with it in your hands. Get it to a dark beacon; your escort must keep you alive." % WPlaces.BEACONS[i].name)
	else:
		hud.notify("%s carries an ember from %s. Keep them alive to the next dark beacon." % [Net.name_of(by), WPlaces.BEACONS[i].name])
	for k in beacon_nodes.size():
		_beacon_prompt(k)


func _rq_ember_kindle(by: int, i: int, key: Array = []) -> void:
	if not Net.authority():
		return
	if by != ember_by or i in lit or vigils.has(i) or not _key_fits(i, key):
		if not key.is_empty():
			Net.call_peer(by, "_w_give", [key])
		return
	if not key.is_empty():
		vigil_paid[i] = {"by": by, "items": key}
	shared("_w_ember_end", [true])
	var t := EMBER_VIGIL
	if second_front(beacon_nodes[i].pos, false, i) != null:
		t = FRONT_VIGIL
	shared("_w_vigil", [i, t])


func _w_ember_end(delivered: bool) -> void:
	if ember_by == Net.me():
		player.weapon.hands_full = false
	if not delivered and ember_by != 0:
		hud.notify("The ember is out. It has to be carried again from a lit beacon.")
	elif delivered:
		hud.notify("The ember catches. Hold the beacon while it takes.")
	ember_by = 0
	ember_from = -1
	if is_instance_valid(_ember_light):
		_ember_light.queue_free()
	for k in beacon_nodes.size():
		_beacon_prompt(k)


## Host: the waste comes for the ember while it is carried; the carrier falling or leaving puts it out.
func _ember_tick(delta: float) -> void:
	if ember_by == 0 or not Net.authority():
		return
	var carrier: Node3D = player if ember_by == Net.me() else avatars.get(ember_by)
	if not is_instance_valid(carrier) or (carrier == player and (downed or _pfail)) or (carrier != player and carrier.downed):
		shared("_w_ember_end", [false])
		return
	_ember_t -= delta
	if _ember_t <= 0.0:
		_ember_t = 18.0 if night else 26.0
		if alive_count() < WCrowd.ALIVE_CAP:
			var roster: Array = forms_at(carrier.global_position)
			for k in randi_range(2, 3):
				var e = _spawn_near(roster[randi() % roster.size()], carrier.global_position, 30.0, 45.0)
				if e and e.has_method("seek"):
					e.seek(carrier.global_position, 40.0)


const BEACON_THERE := 250.0   ## near enough to a beacon as it catches to share in its credit
var kindled = null              ## the beacons this pilgrim has credit for (null: not yet known)


## The beacons this pilgrim keeps credit for. A character from before credit was kept has every lit one.
func my_kindled() -> Array:
	if kindled == null:
		kindled = lit.duplicate()
	return kindled


## This pilgrim's own credit for a beacon: its place in their tally, and a boon to choose.
func _keep_credit(i: int) -> void:
	if not i in my_kindled():
		kindled.append(i)
	var rr := RandomNumberGenerator.new()
	rr.seed = hash([i, kindled.size(), skills.boons.size(), Net.me(), Time.get_ticks_usec()])
	if skills.boon_offer.is_empty():
		skills.boon_offer = skills.roll_boons(rr)
	if is_instance_valid(ui) and not skills.boon_offer.is_empty():
		get_tree().create_timer(3.5, false).timeout.connect(func():
			if is_instance_valid(ui) and not skills.boon_offer.is_empty():
				ui.open_boons(WPlaces.BEACONS[i].name))


## Beacon sightlines: the lair nearest a place whose ground has not yet been seen.
func lair_seen_from(p: Vector2) -> Dictionary:
	var best := {}
	var bd := INF
	for l in lairs:
		if is_revealed(l.pos):
			continue
		var d := p.distance_to(Vector2(l.pos.x, l.pos.z))
		if d < bd:
			bd = d
			best = l
	return best


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
## A column of smoke (or light) standing over a place, seen from far across the waste: soft-edged,
## with wisps climbing it, thinning to nothing at the top, bent a little by the wind.
static func landmark_column(c: Color, height: float, radius: float, light := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * (1.6 if light else 7.0)
	cm.bottom_radius = radius * (1.0 if light else 1.8)
	cm.height = height
	cm.radial_segments = 24
	cm.rings = 12
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := ShaderMaterial.new()
	m.shader = load("res://world/column_light.gdshader" if light else "res://world/column_smoke.gdshader")
	# Seen through its middle the column is thicker than its colour alone gave before: a little more of it
	m.set_shader_parameter("tint", Color(c.r, c.g, c.b, minf(1.0, c.a * (1.6 if light else 2.4))))
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("wisp", 0.35 if light else 0.75)
	m.set_shader_parameter("rise", 6.0 if light else 2.2)
	m.set_shader_parameter("sway", 0.0 if light else height * 0.06)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = height * 0.1
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


## Test: the map is black till walked, the sea and its isles too; a lit beacon shows the land about it;
## an older map's known ground carries over.
func debug_fog() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var il: Dictionary = terrain.isles[0]
	var isle_dark := not is_revealed(Vector3(il.c.x, 0, il.c.y))
	var known := 0
	for v in revealed:
		known += int(v != 0)
	var little := known < revealed.size() / 10
	var bp: Vector3 = beacon_nodes[3].pos
	var far_side := bp + Vector3(400, 0, 0)
	var before := is_revealed(far_side)
	if not 3 in lit:
		lit.append(3)
	reveal_lit()
	var after := is_revealed(far_side)
	revealed.fill(0)
	var old := PackedByteArray()
	old.resize(256 * 256)
	old.fill(1)
	_reveal_from(old, 256, WPlaces.HALF)
	var carried := is_revealed(Vector3(1500, 0, -1500)) and not is_revealed(Vector3(3000, 0, 3000))
	print("FOG isle_dark=%s little=%s beacon=%s carried=%s" % [isle_dark, little, (not before) and after, carried])
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
		if Vector2(p.x, p.z).distance_to(WPlaces.bpos(i)) < WPlaces.BEACON_SAFE * flame_of(i):
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
	if n > 0:
		if _by == Net.me():
			_w_spend_short(item, n)
		else:
			Net.call_peer(_by, "_w_spend_short", [item, n])


## The host found the chests short: two spent the same things at once. The spender pays the rest from
## the pack if they can, and is told.
func _w_spend_short(item: String, n: int) -> void:
	var t := mini(n, inv.count(item))
	if t > 0:
		inv.take(item, t)
	if n - t > 0 and hud:
		hud.notify("Someone took the last %s from the chests first." % Items.iname(item))


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
	if ember_by == Net.me():
		slow *= 0.85   # an ember in both hands
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
	if lit.size() != _lit_seen:
		_lit_seen = lit.size()
		_apply_skills()
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


## The best healing carried, used at a key: the one that heals most first; burning or in tar,
## the elixir that ends them.
func best_heal() -> String:
	var best := ""
	var most := 0.0
	for id in Items.DB:
		var info: Dictionary = Items.DB[id]
		if str(info.get("kind", "")) != "medicine" or float(info.get("heal", 0.0)) <= 0.0 or inv.count(id) < 1:
			continue
		var h := float(info.heal) + (1000.0 if id == "elixir" and (_burn > 0.0 or _slow > 0.0) else 0.0)
		if h > most:
			most = h
			best = id
	return best


func quick_heal() -> void:
	var id := best_heal()
	if id == "":
		hud.notify("You carry nothing that heals.")
	elif eat(id):
		hud.notify("%s used. %d left." % [Items.info(id).name, inv.count(id)])


## Lights a cigarette: it burns down on its own while you keep at whatever you are doing.
var smoking: WSmoke
func smoke(id: String) -> bool:
	if smoking and smoking.lit:
		hud.notify("You have one lit already.")
		return false
	if inv.take(id, 1) < 1:
		return false
	if smoking == null:
		smoking = WSmoke.new()
		player.cam.add_child(smoking)
	smoking.light(player)
	sfx("whoosh", -26, null, 2.2)
	hud.notify("You light a cigarette.")
	return true


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
const TIER_HP := [1.0, 1.5, 2.2, 3.0, 3.6]       ## a foe's health in a land of each danger (5: the Far Shores)
const TIER_HARM := [1.0, 1.3, 1.6, 1.9, 2.1]    ## and the harm it does
const TIER_XP := [1.0, 1.15, 1.3, 1.5, 1.8]     ## a kill there teaches more
## land: [ward carried against it, the hardship in a few words]
const LAND_WARD := {
	"dunes": ["veil", "The heat: your breath comes back slowly."],
	"forest": ["spore_mask", "The spores eat at your health."],
	"salt": ["goggles", "The glare burns you by day."],
	"marsh": ["tar_boots", "The tar holds your feet."],
	"basalt": ["ember_cloak", "The stone's heat burns you."],
	"frost": ["sheepskin", "The cold bites: it eats at your health."],
	"sun": ["water_gourd", "Thirst: by day your water runs out, and your health with it."],
	"steppe": ["bone_compass", "You are lost: the compass wanders, and the map cannot find you."],
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
	# Danger 5 is set by place, never by distance: the Far Shores, once the sea has opened
	if turned() and d > WTerrain.N * WTerrain.CELL * 0.5 and land_at(p) in FAR_SHORE_LANDS:
		return 5
	return clampi(ring + (1 if land_tier(land_at(p)) >= 3 else 0), 1, 4)


const FAR_SHORE_LANDS := ["frost", "sun", "steppe"]
## The stuff each far land yields, gathered there or found in its ruins (see WArms.FAR_STUFF).
const FAR_FINDS := {"quiet": "lens_glass", "domes": "dome_steel", "frost": "ice_iron", "sun": "sunglass", "steppe": "steppe_horn"}

## The far land's own stuff at this spot, or "" in the waste and on the near isles.
func far_find(p: Vector3) -> String:
	if terrain == null:
		return ""
	var il := terrain.isle_at(p.x, p.z, 1.0)
	return str(FAR_FINDS.get(str(il.get("key", "")), "")) if not il.is_empty() else ""


## The same, for a far ruin's or an isle's crate by its id.
static func far_find_id(id: String) -> String:
	for k in FAR_FINDS:
		if id.begins_with("fs_%s_" % k) or id.begins_with("isle_%s" % k):
			return FAR_FINDS[k]
	return ""

## How many dangers there are, as the pilgrim knows it: the fifth shows only after the turn.
func tiers_known() -> int:
	return 5 if turned() else 4


func gentle_at(p: Vector3) -> bool:
	if hall and hall.inside(p):
		return true
	return Vector2(p.x, p.z).distance_to(WPlaces.start) < GENTLE


func land_at(p: Vector3) -> String:
	if terrain and terrain.is_water(p.x, p.z, 0.8):
		return "sea"   # no land's hardship out on the water
	if terrain and maxf(absf(p.x), absf(p.z)) > WTerrain.N * WTerrain.CELL * 0.5:
		# A Far Shore is a land of its own, with its own hardship
		var il := terrain.isle_at(p.x, p.z, 1.2)
		if not il.is_empty() and WIsles.THEMES[il.key].has("land"):
			return str(WIsles.THEMES[il.key].land)
	return terrain.biome_name(p.x, p.z) if terrain else "ash"


## Whether this pilgrim carries the ward against a land's hardship (or the land has none).
func warded(bn: String) -> bool:
	if power_is("dry") and bn in ["sun", "dunes", "basalt"]:
		return true   # the Dry River's power: no heat touches you
	return not LAND_WARD.has(bn) or bn in WArms.worn(arms).wards


func land_warning(bn: String) -> String:
	if warded(bn):
		return ""
	return "\n%s Wear %s." % [LAND_WARD[bn][1], Items.info(LAND_WARD[bn][0]).name]


const CHAMPION_CHANCE := 1.0 / 15.0

## A foe is as strong as the land it rises in, not as the arms it will face: a better gun is felt.
func spawn_at(kind: String, p: Vector3) -> LesserSpeeb:
	var e := super(kind, p)
	if e and Game.wasteland and terrain:
		var tp := tier_at(p)
		# A great one is already made for its own land: it does not take the fifth danger again
		if LesserSpeeb.BOSSES.has(kind):
			tp = mini(tp, 4)
		var land: float = TIER_HP[tp - 1]
		var m: float = land * vow_mult(p, 1.3) * (WCrowd.hp(self) if e.boss == "" else 1.0)
		e.hp *= m
		e.max_hp *= m
		# Plate thickens with the land too, so piercing rounds and the Sledge stay worth carrying
		e.plate *= land
		# In the harder lands (every land past the first ring, after the turn), one in fifteen or so stands out
		if tier_at(p) >= (2 if turned() else 3) and e.boss == "" and not kind in ["saucer", "unseen", "elite", "box_cat"] and randf() < CHAMPION_CHANCE * (2.0 if tier_at(p) >= 5 else 1.0):
			e.become_champion(LesserSpeeb.CHAMPION.keys()[randi() % LesserSpeeb.CHAMPION.size()])
	return e


## The hardship of the land underfoot, for one without its ward.
var lost := false   ## on the Pale Steppe without a compass: the map cannot find you, the compass wanders

func _land_tick(delta: float) -> void:
	var bn := land_at(player.global_position)
	lost = bn == "steppe" and not warded(bn)
	if warded(bn) or gentle_at(player.global_position) or settlement_at(player.global_position, 4.0) != "" or base_at(player.global_position, 0.0, true) >= 0 or not LAND_WARD.has(bn) or (bn in ["salt", "sun"] and night):
		lost = false   # a town or a home knows where it is
		if ui:
			# The weather may still ask something, out in the open
			var why := weather.hardship(player.global_position) if not gentle_at(player.global_position) and base_at(player.global_position, 0.0) < 0 and settlement_at(player.global_position, 0.0) == "" and not weather.sheltered else ""
			ui.set_hazard(why)
		return
	reach_stage("wards")
	if ui:
		ui.set_hazard("%s  Wear %s." % [LAND_WARD[bn][1], Items.info(LAND_WARD[bn][0]).name])
	match bn:
		"dunes":
			player.stamina_mult *= 0.5
		"forest", "salt", "basalt", "frost", "sun":
			if bn in ["salt", "sun"] and night:
				return
			_land_t -= delta
			if _land_t <= 0.0:
				_land_t = 5.0
				var loss := {"forest": 2.0, "salt": 2.5, "basalt": 4.0, "frost": 4.0, "sun": 3.0}[bn] as float
				if bn in ["sun", "basalt"]:
					loss *= 1.0 - 0.5 * power_k("dry")
				if bn == "frost" and near_fire(player.global_position):
					return   # a fire keeps the cold off
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
		"held":
			# Gripped by a heavy one: the legs held, a moment
			_freeze = maxf(_freeze, secs)
			player.shake(0.3)
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
func _rq_bed_owner(by: int, pid: int, to: String) -> void:
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


## The waystone rules (gameplay bible): people travel fast, cargo goes by road and sea.
## Waystones wake with the fourth fire; one end must stand in a lit beacon's ground or a town; both on one
## land (the waste and each isle are lands of their own), save that a far isle links to the waste along a
## lit sea lane. A waystone whose anchor beacon goes dark dims and says why; it is never taken down.
const WAY_CARGO := ["beacon_oil", "deep_oil", "fleet_log", "bell_ichor", "red_iron", "salt_crystal", "obsidian"]

func waystone_land(p: Vector3) -> String:
	if terrain == null:
		return "waste"
	var il := terrain.isle_at(p.x, p.z, 1.2)
	return str(il.key) if not il.is_empty() else "waste"


## Whether a waystone stands where it may anchor a link: in a lit beacon's ground or a town.
func waystone_anchored(p: Vector3) -> bool:
	for i in lit:
		if Vector2(p.x, p.z).distance_to(WPlaces.bpos(i)) < WPlaces.BEACON_SAFE:
			return true
	return settlement_at(p, TOWN_SAFE) != ""


## Why two waystones of one name do not link, or "" if they do.
func waystone_why(a: int, b: int) -> String:
	if not pieces.has(a) or not pieces.has(b):
		return "?"
	if not has_verb(4):
		return "The waystones sleep until the fourth fire burns."
	var pa: Vector3 = pieces[a].pos
	var pb: Vector3 = pieces[b].pos
	if not waystone_anchored(pa) and not waystone_anchored(pb):
		for i in WPlaces.BEACONS.size():
			if not i in lit and (Vector2(pa.x, pa.z).distance_to(WPlaces.bpos(i)) < WPlaces.BEACON_SAFE or Vector2(pb.x, pb.z).distance_to(WPlaces.bpos(i)) < WPlaces.BEACON_SAFE):
				return "Dim: %s has gone dark. Light it again to wake this link." % WPlaces.BEACONS[i].name
		return "Dim: one of the pair must stand in a lit beacon's ground or a town."
	var la := waystone_land(pa)
	var lb := waystone_land(pb)
	if la == lb:
		return ""
	var far := lb if la == "waste" else (la if lb == "waste" else "")
	if far != "" and lights and lights.houses.any(func(h): return h.lane == far):
		return "" if lights.lane_lit(far) else "Dim: the waste links to that isle only when both lights on its sea lane burn."
	return "Dim: the two stand on different lands. Go by boat."


## Why this pilgrim may not step through now, or "".
func waystone_carry_why() -> String:
	if player.mount != null:
		return "Get down first: a cat will not pass a waystone."
	if ember_by == Net.me():
		return "An ember will not pass a waystone. Carry it by road."
	for slot in inv.slots:
		if slot == null:
			continue
		var id := str(slot.id) if slot is Dictionary else str(slot[0])
		if id in WAY_CARGO or id in WArms.FAR_STUFF or id.begins_with("heart_") or id.begins_with("coal_"):
			return "%s will not pass a waystone. Cargo goes by road and sea." % Items.iname(id)
	return ""


func _portal_look(pid: int) -> void:
	var pc: Dictionary = pieces[pid]
	if pc.kind != "portal" or not pc.node.has_meta("veil"):
		return
	var pair := portal_pair(pid)
	var on := pair >= 0 and waystone_why(pid, pair) == ""
	(pc.node.get_meta("veil") as StandardMaterial3D).albedo_color.a = 0.45 if on else 0.0
	(pc.node.get_meta("light") as OmniLight3D).light_energy = 1.4 if on else 0.0
	(pc.node.get_meta("label") as Label3D).text = str(pc.name)


func step_through(pid: int) -> void:
	var to := portal_pair(pid)
	if to < 0:
		return
	var why := waystone_why(pid, to)
	if why == "":
		why = waystone_carry_why()
	if why != "":
		hud.notify(why)
		sfx("deny", -10)
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


## Within a settlement's watch no foe may harm anyone, nor hunt them from outside its walls.
func sheltered(p: Vector3) -> bool:
	return settlement_at(p, TOWN_SAFE) != ""


func foe_harm() -> float:
	return NIGHT_HARM if night else 1.0


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


# ------------------------------------------------------------------ stages
## Each system is shown when its land first needs it, once in a world. What has been shown is kept in
## the world's flags, so one who joins late sees every system the world has reached, without the cards.
const STAGES := {
	"dread": ["Fear", "In the open dark your fear rises and the edges of sight darken. A fire, a town or a lit lantern eases it."],
	"wards": ["Hardships", "This land bites. Gear made from the land's own stuff wards it off. Towns and roofs are safe."],
	"trades": ["Trades", "Each player keeps one trade and makes something no one else can. Choose yours in the pack."],
	"standing": ["Road safety", "Every town knows how safe its roads are. Kill enemies near it and break nearby camps to make them safer. The map shows each as a ring."],
	"seasons": ["Seasons", "The seasons turn every five days. Each changes the night and the weather. You hear of it a day ahead."],
}


func staged(k: String) -> bool:
	return flags.has("stage_" + k)


## A system is needed here for the first time: everyone in the world is shown it.
func reach_stage(k: String) -> void:
	if not staged(k) and STAGES.has(k):
		shared("_w_stage", [k])


func _w_stage(k: String) -> void:
	if staged(k) or not STAGES.has(k):
		return
	flags["stage_" + k] = true
	if not Net.dedicated and hud:
		hud.alert_banner(STAGES[k][0], STAGES[k][1])
	autosave_soon(3.0)


## An older world has gone past some stages already: mark them, without the cards.
func _stages_catch_up() -> void:
	if nights > 0 or day > 1:
		flags["stage_dread"] = true
	if day >= WWeather.SEASON_DAYS:
		flags["stage_seasons"] = true
	for k in WPlaces.SETTLEMENTS:
		if visited.has(k):
			flags["stage_trades"] = true
		if safety_of(k) < 25:
			flags["stage_standing"] = true


func _w_flag(f: String) -> void:
	flags[f] = true
	if f.begins_with("shrine_"):
		for sb in shrine_bowls:
			_shrine_bowl_show(sb)
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
			hud.notify("The great raid comes tomorrow night: %s. Mend your walls and lay in shells." % GREAT_HOSTS[great_host()].name.to_lower())
		2:
			hud.notify("Two nights to the great raid. Enemies are gathering.")


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
	var host := great_host()
	great = {"spawned": 0, "spots": spots, "host": host}
	for c in spots:
		shared("_w_great", [c, host])
	var per := WCrowd.scale(self, 8 + mini(nights / 2, 8))
	for wave in 3:
		get_tree().create_timer(wave * 100.0 + 1.0, false).timeout.connect(func():
			if not is_instance_valid(self) or not night:
				return
			for c in spots:
				# Half of each wave is the night's own host, the rest the land's forms; the last wave brings its lead
				var roster: Array = forms_at(c)
				var band: Array = GREAT_HOSTS[host].band
				if wave == 2:
					for lead in GREAT_HOSTS[host].leads:
						var le = _spawn_near(lead, c, 40.0, 55.0, true)
						if le:
							le.set_meta("raid", true)
							le.set_meta("great", true)
							great.spawned = int(great.get("spawned", 0)) + 1
				for k in per + wave * 2:
					get_tree().create_timer(randf_range(0.0, 25.0), false).timeout.connect(func():
						if is_instance_valid(self) and night:
							var kind: String = "elite" if randf() < 0.06 + wave * 0.04 else (band[randi() % band.size()] if randf() < 0.5 else roster[randi() % roster.size()])
							var e = _spawn_near(kind, c, 38.0, 55.0, true)
							if e:
								e.set_meta("raid", true)
								e.set_meta("great", true)
								great.spawned = int(great.get("spawned", 0)) + 1))


## The seventh night's host changes as the lands are lit: the dead come first, then the Unlit march
## to put the beacons out again, then (after the turn) the sea itself, and at last the old iron of the deep lands.
const GREAT_HOSTS := {
	"far": {"name": "The Far Host", "band": ["rime_walker", "canyon_strider", "grass_stalker", "dust_choir", "geyser_wight"], "leads": ["mound_guard", "sand_maw"],
		"text": "The Far Shores have crossed the sea: rime-walkers, striders and stalkers, and the mound-guards behind them."},
	"pilgrims": {"name": "The Hollow Pilgrimage", "band": ["hollow", "hollow", "vigil", "saltbone"], "leads": ["warden"],
		"text": "The dead walk on your camp, a Gravewarden behind them."},
	"unlit": {"name": "The Unlit War Band", "band": ["unlit_gun", "unlit_gun", "unlit_blade", "unlit_mark", "unlit_flame"], "leads": ["unlit_brute", "unlit_brute"],
		"text": "The Unlit march to put out what you have lit. Mind their marksmen, and their breakers."},
	"tide": {"name": "The Drowned Tide", "band": ["drowned", "drowned", "kelp_drowner", "nykur", "lurker"], "leads": ["draugr", "draugr", "tar_giant"],
		"text": "The sea comes up the shore after you: the drowned, the kelp-wound and the grey horses of the water."},
	"iron": {"name": "The Iron Host", "band": ["deacon", "drowned", "unlit_blade", "hollow"], "leads": ["knight", "colossus"],
		"text": "Old iron comes out of the deep lands: knights, and a colossus."},
}

## Which host comes on the seventh night, by how many beacons burn.
func great_host() -> String:
	if flags.has("second_vow"):
		return "far"   # the Second Vow: what lives beyond the sea comes for the camp
	if lit.size() >= 7:
		return "iron"
	if lit.size() >= 5:
		return "tide"   # the turn: once five burn, the seventh night comes up out of the sea
	if lit.size() >= 3:
		return "unlit"
	return "pilgrims"


func _w_great(at: Vector3, host := "pilgrims") -> void:
	sfx("bell", 0)
	for k in 3:
		get_tree().create_timer(0.8 * (k + 1), false).timeout.connect(func(): sfx("bell", -3, null, 0.75))
	var d := int(player.global_position.distance_to(at))
	var gh: Dictionary = GREAT_HOSTS.get(host, GREAT_HOSTS.pilgrims)
	hud.alert_banner(gh.name, ("They are coming for your camp, %d m away. " % d if d > 40 else "Three waves. Hold until dawn. ") + gh.text)


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
	hud.notify("The enemies leave what they carried. Everyone shares it.")
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
			vigils[i] -= delta * 4.0   # with no keeper at the bowl it burns down fast
		_front_tick(i, delta)
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
			if near and not _front_held(i):
				vigils[i] = 0.0   # the bowl holds, and waits for the camp
				continue
			# Credit: everyone near the bowl as it catches, and everyone who fought at its front
			var who := {}
			for t in targets():
				if t.global_position.distance_to(b.pos) < BEACON_THERE:
					who[pid_of(t)] = true
			if fronts.has(i):
				who.merge(fronts[i].fought)
				fronts.erase(i)
			var paid: Dictionary = vigil_paid.get(i, {})
			vigil_paid.erase(i)
			if not near and not paid.is_empty():
				Net.call_peer(int(paid.by), "_w_give", [paid.items])   # nothing on the road is lost for good
			shared("_w_vigil_end", [i, near, who.keys()])


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

func _cut_wood_mat() -> StandardMaterial3D:
	if _cut_wood == null:
		_cut_wood = StandardMaterial3D.new()
		_cut_wood.albedo_color = Color(0.85, 0.5, 0.22, 0.32)
		_cut_wood.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cut_wood.roughness = 0.9
	return _cut_wood


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
			if containers.has(id):
				bag.from_data(containers[id])   # what was left or stored here stays; the new finds go in beside it
			for it in Items.roll(c.table, maxi(1, int(round((rr.randi_range(2, 4) + (2 if c.sealed else 0)) * WRules.yield_mult()))), rr):
				bag.add(it[0], it[1])
			var far_stuff := far_find_id(id)
			if far_stuff != "":
				bag.add(far_stuff, rr.randi_range(1, 3))
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
		# The keys of the road: the Bell-Wound's ichor in the tower, the Fleet Log in Quietglass once its lane is lit
		var key_find := ""
		if id.begins_with("kraken_"):
			key_find = "bell_ichor"
		elif (id.begins_with("fs_quiet_") or id.begins_with("isle_quiet")) and lights and lights.lane_lit("quiet"):
			key_find = "fleet_log"
		if key_find != "" and containers.has(id):
			var kb := Inventory.new(14)
			kb.from_data(containers[id])
			if kb.count(key_find) <= 0:
				kb.add(key_find, 1)
				containers[id] = kb.to_data()
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
	# A vote: everyone at the page chooses; the hall waits a minute for those still on the stair
	if end_votes.is_empty():
		end_t = END_WAIT
		_end_first = by
	end_votes[by] = kind
	var all_in := Net.pilgrims().all(func(id): return end_votes.has(int(id))) if Net.online else true
	if all_in or (Net.online and Net.pilgrims().size() <= 1):
		_end_settle()
	else:
		shared("_w_end_votes", [end_votes.duplicate(), end_t])


const END_WAIT := 60.0
var end_votes := {}     ## host: pilgrim -> the ending they chose at the page
var end_t := -1.0
var _end_first := 0


## Host: the page answers the most votes; a tie goes to the host (or, with no host at the page, the first to choose).
func _end_settle() -> void:
	var q: Dictionary = quests.quests.get("story_ferryway", {})
	if end_votes.is_empty() or flags.has("ending") or q.is_empty():
		end_votes.clear()
		end_t = -1.0
		return
	var breaker: int = Net.me() if end_votes.has(Net.me()) and not Net.dedicated else _end_first
	var kind := end_tally(end_votes, breaker)
	var by: int = breaker if end_votes.get(breaker, "") == kind else end_votes.keys().filter(func(id): return end_votes[id] == kind)[0]
	end_votes.clear()
	end_t = -1.0
	shared("_w_ending", [kind, by])
	quests.advance(q.id, int(q.stage))


## The most votes win; a tie goes to the breaker's choice, if theirs is among the tied.
static func end_tally(votes: Dictionary, breaker: int) -> String:
	var count := {}
	for id in votes:
		count[votes[id]] = int(count.get(votes[id], 0)) + 1
	var top := 0
	for k in count:
		top = maxi(top, int(count[k]))
	var tied: Array = count.keys().filter(func(k): return int(count[k]) == top)
	tied.sort()
	if tied.size() > 1 and votes.has(breaker) and votes[breaker] in tied:
		return votes[breaker]
	return tied[0]


func _end_vote_tick(delta: float) -> void:
	if end_t < 0.0:
		return
	end_t -= delta
	if end_t <= 0.0:
		_end_settle()


func _w_end_votes(votes: Dictionary, left: float) -> void:
	if Net.dedicated:
		return
	var names: Array = []
	for id in votes:
		names.append("%s: %s" % [Net.name_of(int(id)), ENDINGS.get(votes[id], ENDINGS.keeper)[0]])
	hud.notify("At the page. %s. The hall waits %d seconds for the rest." % [", ".join(names), int(left)])


const ENDINGS := {
	"keeper": ["The Keeper", "You leave the page white. The pen stays where it lay.\n\nUp in the waste the nine fires burn. The Mouth is held for as long as someone keeps them.\n\nThe waste is not saved. It is kept. And now you keep it."],
	"unlit": ["The Unlit", "You leave the page. Behind the table there is a stair, and Ruth's people are waiting on it with their lamps put out.\n\nYou go down into the Mouth, and you are not seen again.\n\nUp in the waste the forms stop coming at night. The fires burn on. No one can quite remember your name."],
	"pilgrim": ["The Pilgrim", "A thin man stands at the end of the table. He has no face you can keep hold of. He holds out a book, worn soft, its last page blank.\n\n\"He walked it once,\" he says. \"Now you.\"\n\nYou take Brelm's journal, and the vow with it. The road begins again: the same waste, harder, and you are its hermit now. This is the Second Vow."],
	"writer": ["The Writer", "You take up the pen, and write what the five could not: that you were seen, and it was enough.\n\nThe page stays written. The Mouth closes, and does not open again. The nights grow quiet, and no great raid comes.\n\nThe stars are gone. But the waste goes on: great ones still walk abroad, the towns still keep their feasts, and there is work for anyone who wants it."],
}


func _w_ending(kind: String, by: int) -> void:
	flags["ending"] = kind
	if kind == "pilgrim":
		flags["second_vow"] = true
		flags["vow_at"] = world_hours()   # from now the lit fires gutter, and must be tended
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
func _rq_take(by: int, id: String, i: int, n := 0) -> void:
	if not Net.authority() or not containers.has(id):
		return
	var data: Array = containers[id]
	if i < 0 or i >= data.size() or data[i] == null:
		return
	var it: Array = data[i]
	if n > 0 and n < int(it[1]):
		# Part of the stack: the rest stays
		data[i] = [it[0], int(it[1]) - n]
		it = [it[0], n]
	else:
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
	if wp.gun() != had[4] and wp.guns.has(had[4]):
		wp.cur = wp.guns.find(had[4])
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

func _rq_satchel(_by: int, p: Vector3, items: Array, grave: bool, owner := "", keep := false) -> void:
	if not Net.authority():
		return
	var sid := "s%d" % satchel_next
	satchel_next += 1
	var bag := Inventory.new(maxi(12, items.size()))
	for it in items:
		bag.add(it[0], it[1])
	shared("_w_cont", [sid, bag.to_data()])
	shared("_w_satchel", [sid, p, grave, owner, day, keep])


## Loot from a great one or an event falls for each pilgrim of the fellowship, a satchel apiece that
## only its owner sees, so no one argues over one bag. Alone, or offline, it is one satchel for all.
## `roll` makes the items afresh for each, so no two bags are the same.
func drop_for_each(at: Vector3, roll: Callable) -> int:
	if not Net.authority():
		return 0
	var names := []
	if Net.online:
		for id in Net.players:
			var nm := str(Net.players[id].name)
			if not nm in names:
				names.append(nm)
	if names.size() < 2:
		_rq_satchel(0, at, roll.call(), false)
		return 1
	for i in names.size():
		var off := Vector3(1.4, 0, 0).rotated(Vector3.UP, TAU * i / names.size())
		_rq_satchel(0, at + off, roll.call(), false, names[i])
	return names.size()


func _w_satchel(sid: String, p: Vector3, grave: bool, owner := "", made := -1, keep := false) -> void:
	if satchels.has(sid):
		return
	if made < 0:
		made = day
	var n := Node3D.new()
	add_child(n)
	n.global_position = ground_below(p)
	if owner != "" and owner != Net.my_name() and not Net.dedicated:
		# Another pilgrim's share: kept, but not seen or touched here
		n.visible = false
		satchels[sid] = {"node": n, "pos": p, "grave": grave, "owner": owner, "day": made, "keep": keep}
		return
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
	satchels[sid] = {"node": n, "pos": p, "grave": grave, "owner": owner, "day": made, "keep": keep}


## Satchels left lying (a foe's few rounds, a bag no one came back for) are blown away by the ash after
## a few days, so a long world does not fill with them. Your belongings, where you fell, are never taken,
## and nothing goes while someone stands near it.
const SATCHEL_DAYS := 4
const SATCHEL_MAX := 300

func _age_satchels() -> void:
	if not Net.authority():
		return
	var near: Array = []
	if not Net.dedicated and is_instance_valid(player):
		near.append(player.global_position)
	for id in avatars:
		if is_instance_valid(avatars[id]) and avatars[id].is_inside_tree():
			near.append(avatars[id].global_position)
	var keep: Array = []
	var gone: Array = []
	for sid in satchels:
		var s: Dictionary = satchels[sid]
		if s.grave or s.get("keep", false):
			continue
		var by_someone := false
		for q in near:
			if Vector2(q.x - s.pos.x, q.z - s.pos.z).length() < 80.0:
				by_someone = true
				break
		if by_someone:
			continue
		if day - int(s.get("day", day)) >= SATCHEL_DAYS:
			gone.append(sid)
		else:
			keep.append(sid)
	# Too many even so: the oldest go first
	if satchels.size() - gone.size() > SATCHEL_MAX:
		keep.sort_custom(func(a, b): return int(satchels[a].get("day", 0)) < int(satchels[b].get("day", 0)))
		gone.append_array(keep.slice(0, satchels.size() - gone.size() - SATCHEL_MAX))
	for sid in gone:
		shared("_w_satchel_gone", [sid])


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
		if ru.has("isle") or ru.has("far") or r.randf() < 0.3:
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


## Off the far lands' towns, lairs and ruins.
func _far_clear(p2: Vector2, il: Dictionary) -> bool:
	if p2.distance_to(WIsles.lair_spot(il)) < 30.0:
		return false
	for k in WPlaces.SETTLEMENTS:
		var st: Dictionary = WPlaces.SETTLEMENTS[k]
		if st.has("shore") and p2.distance_to(WPlaces.spos(k)) < float(st.radius) + 8.0:
			return false
	for ru in ruins:
		if ru.get("far", "") == il.key and p2.distance_to(Vector2(ru.pos.x, ru.pos.z)) < 12.0:
			return false
	return true


## What grows and lies on the isles, by their own dice, after everything on the mainland.
func _scatter_isle_nodes(far_ones: bool) -> void:
	for il in terrain.isles:
		if WIsles.far(il) != far_ones:
			continue
		var th: Dictionary = WIsles.THEMES[il.key]
		var r := RandomNumberGenerator.new()
		r.seed = world_seed + 6060 + hash(il.key)
		var heart: Vector2 = terrain.isle_heart(il)
		var made := 0
		var want := int(70.0 * clampf(pow(float(il.r) / 300.0, 2.0), 1.0, 4.0)) if far_ones else 70   # the far shores are wide, but each node costs
		for tries in (want * 9 if far_ones else 600):   # the near isles roll as they always did, for old saves
			if made >= want:
				break
			var a := r.randf() * TAU
			var p2: Vector2 = il.c + Vector2(cos(a), sin(a)) * sqrt(r.randf()) * float(il.r) * 0.85
			if p2.distance_to(heart) < 30.0:
				continue
			if far_ones and not _far_clear(p2, il):
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
	"ash": ["harrow", "rusher", "rusher", "spitter", "spider", "swarm", "idol", "bloater", "howler", "hollow", "hollow", "vigil", "deacon", "cinder_hound", "bile_elder", "dirge_howler"],
	"dunes": ["gaunt", "gaunt", "spitter", "spitter", "rusher", "swarm", "spider", "lurker", "lurker", "saltbone", "saltrifle", "wisp", "rust_stalker", "rust_stalker", "sand_maw"],
	"salt": ["rusher", "spitter", "swarm", "swarm", "rusher", "howler", "bloater", "saltbone", "saltbone", "vigil", "saltrifle", "saltrifle", "rime_bones", "rime_bones", "iron_idol"],
	"forest": ["ash_weaver", "harrow", "rusher", "rusher", "spider", "spider", "idol", "brute", "howler", "hollow", "hollow", "deacon", "colossus", "mourner", "mourner", "dirge_howler"],
	"basalt": ["gaunt", "idol", "idol", "rusher", "spitter", "spider", "brute", "bloater", "saltbone", "vigil", "wisp", "wisp", "knight", "glass_crawler", "pyre_sack", "cinder_hauler", "cinder_hound"],
	"marsh": ["ash_weaver", "spider", "spider", "swarm", "swarm", "swarm", "rusher", "bloater", "lurker", "hollow", "drowned", "drowned", "colossus", "bog_crawler", "bog_crawler", "tar_giant"],
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
	# The Second Vow: the Far Shores' forms walk the waste too (never in the gentle ground, or a town)
	if flags.has("second_vow") and il.is_empty() and t >= 2 and settlement_at(p, 40.0) == "":
		out += far_forms().filter(func(k): return int(LesserSpeeb.FORM_TIER.get(k, 1)) <= t + 1)
	return out if not out.is_empty() else GENTLE_FORMS


## The forms of the Far Shores, once each.
func far_forms() -> Array:
	var out: Array = []
	for land in FAR_SHORE_LANDS:
		for k in WIsles.THEMES[land].forms:
			if not k in out:
				out.append(k)
	return out


static func _form_spec(k: String) -> Dictionary:
	return LesserSpeeb.KINDS.get(k, LesserSpeeb.VARIANTS.get(k, {}))


## A mixed pack of what this land breeds: one that leads it (a heavy, a caster or a howler), two to four
## lesser ones, and now and then one that strikes from afar. Fewer when the land has little to choose from.
func pack_at(p: Vector3, fodder := -1) -> Array:
	var roster := forms_at(p)
	var leads: Array = roster.filter(func(k): var sp := _form_spec(k); return float(sp.get("hp", 0.0)) >= 120.0 or k in ["howler", "idol", "deacon", "warden", "choir", "dust_choir"])
	var far: Array = roster.filter(func(k): var sp := _form_spec(k); return str(sp.get("role", "")) == "gun" or k in ["spitter", "saltrifle", "unlit_mark"])
	var low: Array = roster.filter(func(k): return not k in leads and not k in far)
	if low.is_empty():
		low = roster
	var out: Array = []
	if not leads.is_empty():
		out.append(leads[randi() % leads.size()])
	for i in (fodder if fodder >= 0 else randi_range(2, 4)):
		out.append(low[randi() % low.size()])
	if not far.is_empty() and randf() < 0.35:
		out.append(far[randi() % far.size()])
	return out


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
			# Wood you can cut stands out from the dead trees you cannot: warm, sound wood
			# (A red rag band and a pale axe-notch box once marked it too: on the thin, leaning trunks they
			# stood off the wood as a floating red disc and a yellow box, so they are gone)
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = _cut_wood_mat()
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
	# All its pieces drawn as a few meshes, one for each look: a pile of rounds is otherwise fifty
	WBatch.flatten(n)
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
	var last: bool = int(nd.charges) <= 1
	# The swing, then the blow lands a beat later: struck wood, stone, iron or leaf each sound of themselves
	sfx("swing", -10, null, randf_range(0.95, 1.1))
	if player.cam:
		var cam := player.cam
		var tw := create_tween()
		tw.tween_property(cam, "rotation:x", cam.rotation.x - 0.035, 0.08).set_ease(Tween.EASE_OUT)
		tw.tween_property(cam, "rotation:x", cam.rotation.x, 0.16).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(0.1, false).timeout.connect(func():
		if not is_instance_valid(self):
			return
		_gather_sound(str(nd.kind), nd.pos, last)
		player.shake(0.24 if last else 0.13)
		_gather_fx(nd, last))


## What a blow at each kind of node sounds like (and the last blow, heavier and lower).
const GATHER_SOUNDS := {"tree": [["chop", -3.0], ["carve", -9.0]], "rock": [["crumble", -3.0], ["thud", -8.0]], "salt": [["crumble", -4.0], ["hit_metal", -16.0]],
	"scrap": [["hit_metal", -6.0], ["thud", -12.0]], "ammo": [["hit_metal", -8.0], ["cloth", -10.0]], "herb": [["cloth", -6.0]], "bone": [["crumble", -6.0], ["thud", -12.0]]}
var gather_heard: Array = []   ## the sounds of the last blow (for the tests)

func _gather_sound(kind: String, at: Vector3, last: bool) -> void:
	gather_heard.clear()
	for snd in GATHER_SOUNDS.get(kind, [["carve", -6.0]]):
		gather_heard.append(snd[0])
		sfx(snd[0], float(snd[1]) + (3.0 if last else 0.0), at, randf_range(0.9, 1.1) * (0.82 if last else 1.0) * (1.35 if kind == "bone" else 1.0))


const CHIP_COLOURS := {"tree": Color(0.55, 0.4, 0.26), "rock": Color(0.5, 0.48, 0.45), "salt": Color(0.92, 0.92, 0.9),
	"scrap": Color(0.45, 0.3, 0.2), "herb": Color(0.6, 0.7, 0.45), "bone": Color(0.88, 0.85, 0.76), "ammo": Color(0.75, 0.6, 0.3)}
static var _chip_mats := {}
var gather_chips := 0   ## chips thrown so far (for the tests)

## What a blow at a node looks like: it shivers, and bits of it fly; the last blow throws more.
func _gather_fx(nd: Dictionary, last: bool) -> void:
	if Net.dedicated or not nd.node is Node3D or not is_instance_valid(nd.node):
		return
	var n: Node3D = nd.node
	var tw := create_tween()
	var r0 := n.rotation
	tw.tween_property(n, "rotation", r0 + Vector3(0.06, 0, -0.05), 0.05)
	tw.tween_property(n, "rotation", r0 + Vector3(-0.04, 0, 0.04), 0.06)
	tw.tween_property(n, "rotation", r0, 0.08)
	var kind := str(nd.kind)
	if not _chip_mats.has(kind):
		var m := StandardMaterial3D.new()
		m.albedo_color = CHIP_COLOURS.get(kind, Color(0.5, 0.5, 0.5))
		m.roughness = 1.0
		_chip_mats[kind] = m
	var to_me := player.global_position - n.global_position
	to_me.y = 0.0
	to_me = to_me.normalized() if to_me.length() > 0.1 else Vector3.FORWARD
	var from := n.global_position + Vector3(0, 0.9 if kind == "tree" else 0.4, 0) + to_me * 0.4
	for i in (14 if last else 6):
		var c := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var sz := randf_range(0.05, 0.12)
		bm.size = Vector3(sz, sz * 0.6, sz * 1.3)
		c.mesh = bm
		c.material_override = _chip_mats[kind]
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(c)
		c.global_position = from
		gather_chips += 1
		var out := (to_me + Vector3(randf_range(-0.9, 0.9), 0, randf_range(-0.9, 0.9))).normalized() * randf_range(0.6, 1.6)
		var land := from + out
		land.y = terrain.height_at(land.x, land.z) + 0.03 if terrain else from.y - 0.4
		var up := from.lerp(land, 0.5) + Vector3(0, randf_range(0.3, 0.7), 0)
		var ct := create_tween()
		ct.tween_property(c, "global_position", up, 0.12).set_ease(Tween.EASE_OUT)
		ct.parallel().tween_property(c, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.3)
		ct.tween_property(c, "global_position", land, 0.16).set_ease(Tween.EASE_IN)
		ct.tween_interval(1.2)
		ct.tween_property(c, "scale", Vector3.ONE * 0.01, 0.3)
		ct.tween_callback(c.queue_free)


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
	# Out past the sea, the land's own stuff comes up with whatever else is taken
	var ff := far_find(np)
	if ff != "" and nd.kind != "herb" and rr.randf() < 0.3:
		out.append([ff, rr.randi_range(1, 2)])
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
	_gather_float(nodes[id], out)
	award("gather")
	quests.on_event("gathered", {})


## What was taken rises off the node for a moment: "+4 Wood".
var gather_floats := 0   ## (for the tests)
func _gather_float(nd: Dictionary, out: Array) -> void:
	if Net.dedicated or out.is_empty() or not nd.node is Node3D or not is_instance_valid(nd.node):
		return
	var parts: Array = []
	for it in out:
		parts.append("+%d %s" % [int(it[1]), Items.iname(str(it[0]))])
	var l := Label3D.new()
	l.text = "  ".join(parts)
	l.font = load("res://assets/fonts/Marcellus-Regular.ttf")
	l.font_size = 30
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color(1.0, 0.9, 0.7)
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.8)
	add_child(l)
	gather_floats += 1
	var at: Vector3 = (nd.node as Node3D).global_position + Vector3(0, 1.8 if nd.kind == "tree" else 1.0, 0)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", at + Vector3(0, 0.7, 0), 1.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.3).set_delay(0.5)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 1.3).set_delay(0.5)
	tw.tween_callback(l.queue_free)


## The last blow brings a node down before it is gone: a tree topples away from you, a rock sinks apart.
var gather_falls := 0   ## (for the tests)
func _node_fall(nd: Dictionary) -> void:
	var n: Node3D = nd.node
	if not n.has_meta("rest"):
		n.set_meta("rest", [n.rotation, n.scale, n.position])
	if Net.dedicated or not n.is_inside_tree() or player.global_position.distance_to(n.global_position) > 80.0:
		n.visible = false
		return
	gather_falls += 1
	var tw := n.create_tween()
	if nd.kind == "tree":
		var away := n.global_position - player.global_position
		away.y = 0
		away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
		var axis := Vector3.UP.cross(away).normalized()
		var r0 := n.global_basis
		tw.tween_method(func(t: float):
			if is_instance_valid(n):
				n.global_basis = Basis(axis, t * t * 1.45) * r0, 0.0, 1.0, 0.9)
		tw.tween_callback(func(): sfx("fall_heavy", -6, n.global_position))
		tw.tween_property(n, "scale", n.scale * 0.01, 0.35).set_delay(0.6)
	else:
		tw.tween_property(n, "scale", n.scale * Vector3(1.15, 0.2, 1.15), 0.4).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(n, "position", n.position - Vector3(0, 0.2, 0), 0.4)
		tw.tween_property(n, "scale", n.scale * 0.01, 0.25)
	tw.tween_callback(func():
		if is_instance_valid(n) and int(nd.charges) <= 0:
			n.visible = false)


func _w_node(id: int, charges: int, back: int) -> void:
	var nd: Dictionary = nodes[id]
	var was := int(nd.charges)
	nd.charges = charges
	nd.back = back
	if charges <= 0 and was > 0 and nd.node.visible:
		_node_fall(nd)
	else:
		if charges > 0 and nd.node.has_meta("rest"):
			var rest: Array = nd.node.get_meta("rest")
			nd.node.rotation = rest[0]
			nd.node.position = rest[2]
			nd.node.remove_meta("rest")
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
	if _save_task >= 0 and WorkerThreadPool.is_task_completed(_save_task):
		_save_wait()
	if _save_t <= 0.0 or (_save_soon >= 0.0 and _save_soon <= 0.0):
		save_all(true)
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
	_save_wait()
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
		if not terrain.is_water(p.x, p.z, 4.0) or sea.open_water(p, 240.0) < 160.0 or (lights and lights.lane_safe(p)):
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
	if player.swimming and player.stamina <= 0.0 and not downed and not Net.dedicated and power_k("tar") < 1.0:
		_drown_t -= delta
		if _drown_t <= 0.0:
			_drown_t = 1.0
			hud.notify("You are drowning. Get to shore.")
		player.health = maxf(1.0, player.health - 7.0 * delta * (1.0 - 0.5 * power_k("tar")))
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
			if lights:
				lights.host_tick()
			if events:
				events.host_tick(1.0)
			_ember_tick(1.0)
			_serpent_t -= 1.0
			if _serpent_t <= 0.0:
				_serpent_t = 10.0
				_serpent_watch()


func _world_tick(delta: float) -> void:
	_end_vote_tick(delta)
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
		_round_tick(delta)
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
	_band_t -= delta
	if _band_t <= 0.0:
		_band_t = 10.0
		_bands_tick()
	_squad_t -= delta
	if _squad_t <= 0.0 and Net.online:
		_squad_t = SQUAD_STEP
		var pos := {}
		if not Net.dedicated and is_instance_valid(player):
			pos[Net.me()] = player.global_position
		for id in avatars:
			if is_instance_valid(avatars[id]) and Net.players.has(id):
				pos[id] = avatars[id].global_position
		if squads_step(pos, SQUAD_STEP):
			shared("_w_squads", [squads])
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
	if absf(wrapf(c - clock, -12.0, 12.0)) > 0.05:   # across midnight, the two clocks are a moment apart, not a day
		clock = c
	day = d
	nights = n


## Some nights have a name and a nature of their own. Hold until dawn without falling, and the
## morning gives something for it. Every pilgrim works out the same night from the world and its count.
const NIGHT_THEMES := {
	"screaming": {"name": "The Screaming Night", "text": "Box cats run in packs tonight. Hold until dawn.", "many": 1.0, "gives": [["fittings_fine", 2], ["meat", 3]]},
	"long": {"name": "The Long Dark", "text": "More enemies come tonight than any night before. Hold until dawn.", "many": 1.4, "gives": [["fittings_rare", 1], ["salt", 40]]},
	"hunt": {"name": "The Hunter's Moon", "text": "Stronger enemies walk among the rest tonight. Hold until dawn.", "many": 1.0, "gives": [["tempered", 2], ["clockwork", 1]]},
	"quiet": {"name": "A Quiet Night", "text": "Few walk tonight. Rest, or build.", "many": 0.5, "gives": []},
}
var night_theme := ""
var _fell_tonight := false
var _falls_tonight := 0   ## host: how many of the fellowship fell this night


func _w_fell(_by: int) -> void:
	if night:
		_falls_tonight += 1


## The night director: how hard the waves press, from the beacons lit (each makes the dark angrier)
## and how the fellowship has been faring (falls ease the next nights; nights held build it back up).
func night_press() -> float:
	return (1.0 + 0.05 * lit.size()) * (1.0 - float(flags.get("ease", 0.0)))


func _director_dawn() -> void:
	var e := float(flags.get("ease", 0.0))
	e = e + 0.12 if _falls_tonight > 0 else e - 0.05
	flags["ease"] = clampf(e, 0.0, 0.3)
	_falls_tonight = 0

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
	_round_n = 0
	_round_live = false
	_round_foes.clear()
	night_theme = night_theme_for(nights + 1)
	_fell_tonight = false
	_falls_tonight = 0
	WPlaylog.note("Night %d falls%s" % [nights + 1, (" (" + str(NIGHT_THEMES[night_theme].name) + ")") if night_theme != "" else ""])
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
	_w_stage("dread")
	if WCrowd.describe(self) != "":
		hud.notify(WCrowd.describe(self))
	quests.on_event("nightfall", {})


func _w_dawn(d: int) -> void:
	night = false
	if Net.authority():
		_roam_great.call_deferred()
	bulwark_spent = false
	quick_camp_spent = false
	day = d
	nights += 1
	raiding.clear()
	sleep_votes.clear()
	_my_vote = false
	sfx("choir", -10)
	hud.say("Dawn. You have lived through %s." % _nth_night(nights), 5.0)
	if feast_town(d) != "":
		var ft := feast_town(d)
		reveal_place(WPlaces.spos(ft), 80.0)
		get_tree().create_timer(6.0, false).timeout.connect(func():
			if is_instance_valid(hud):
				hud.notify("Today is a feast day in %s. Come by day: food, salt and cheap trade." % WPlaces.SETTLEMENTS[ft].name))
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
	elif season_ahead(d) != "":
		hud.notify(season_ahead(d))
	if d >= WWeather.SEASON_DAYS:
		_w_stage("seasons")
	if Net.authority():
		_director_dawn()
		_great_dawn()
		for e in enemies:
			if is_instance_valid(e) and e.is_alive():
				e.die(false)
		_dawn_world()
	_safety_dawn()
	_rivals_dawn()
	_great_warning()
	quests.on_event("dawn", {})
	award("dawn")
	save_all()


## Said at dawn on the last day of a season: what the next one brings, so there is a day to prepare.
func season_ahead(d: int) -> String:
	if WWeather.season_of(d + 1) == WWeather.season_of(d):
		return ""
	return str(WWeather.SEASONS[WWeather.season_of(d + 1)].get("ahead", ""))


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
	_age_satchels()


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
	# Each trade brings its know-how: the fellowship learns a recipe the first time one of its kind settles
	var book: String = WSettlers.TEACHES.get(str(s.job), "")
	var taught := book != "" and not flags.has(book)
	if taught:
		flags[book] = true
	if not Net.dedicated and pieces.has(int(s.fire)) and player and player.global_position.distance_to(pieces[int(s.fire)].pos) < 200.0:
		hud.notify("A wanderer, %s, has come to stay at your fire. A %s." % [s.name, WSettlers.JOBS[s.job].name])
		if taught:
			hud.notify("%s teaches you what is in %s." % [s.name, Items.iname(book)])


func _w_settler_paid(id: int, pay: String, n: int, next: Array) -> void:
	for s in settlers.list:
		if int(s.id) == id:
			if pay != "" and not Net.dedicated and pieces.has(int(s.fire)) and player and player.global_position.distance_to(pieces[int(s.fire)].pos) < 200.0:
				hud.notify("%s took what they asked for and left %d %s in the chest." % [s.name, n, Items.iname(pay).to_lower()])
			s.want = next
			return


func _w_settler_gone(id: int, why: String) -> void:
	settlers.remove(id)
	if not Net.dedicated:
		hud.notify(why)


# ================================================================== growing

## Gives this survivor experience for a deed (see WSkills.XP).
const LOG_GOALS := {"kill_elite": "an elite felled", "kill_boss": "a great one felled", "step": "a quest step done",
	"step_main": "a step of the main road done", "quest": "a quest finished", "beacon": "a beacon lit", "dawn": "a night lived through",
	"settlement": "a settlement found", "ruin": "a ruin found", "biome": "a new land seen"}


## A trace on an isle looked at: its line, and the first time, a little learning and a count.
func _trace_seen(id: String, isle: String, line: String) -> void:
	hud.say(line, 6.0)
	if traces_seen.has(id):
		return
	traces_seen[id] = true
	award("ruin", 0.6)
	var key := id.get_slice("_", 0)
	var n := 0
	for k in traces_seen:
		if str(k).begins_with(key + "_"):
			n += 1
	var all: int = WIsleLife.TRACES.get(key, []).size()
	hud.notify("Traces found on %s: %d of %d" % [isle, n, all])
	if n == all:
		give([["coin", 25]])
		hud.notify("You have found every trace on %s." % isle)


func award(kind: String, mult := 1.0) -> void:
	if guide:
		guide.event(kind)
	if LOG_GOALS.has(kind) and not _pfail:
		WPlaylog.goal(kind, LOG_GOALS[kind])
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


var _lit_seen := -1   ## how many beacons burned when most health was last reckoned


func _apply_skills() -> void:
	if player == null or player.weapon == null:
		return
	var full := player.health >= player.max_health - 0.01
	# Each lit beacon steadies the fellowship a little more: +10 most health, up to +60
	player.max_health = skills.health_max() + _meal_hp + 10.0 * mini(lit.size(), 6)
	player.health = player.max_health if full else minf(player.health, player.max_health)
	player.walk_speed = 3.4 * skills.speed_mult()
	player.run_speed = 5.8 * skills.speed_mult()
	player.weapon.reserve_max = skills.reserve_max()
	player.weapon.damage_mult = skills.damage_mult() * (1.0 + 0.2 * power_k("eye")) * (alchemy.damage_mult() if alchemy else 1.0)
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
	# The hour, the land and the weather each thicken the haze; together they may not white it out
	env.fog_density = minf(env.fog_density, FOG_CAP)
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


const FOG_CAP := 0.028   ## the thickest the haze may get above ground (about 35 paces of sight)


## How many forms the night sends, and of what kind, grows with the nights survived.
## The night comes in rounds: each waits until the last is cleared (or has had its time), then a breath,
## then the next, a little larger. The round nearest dawn is the largest, and after it the night is quiet.
const ROUNDS_MAX := 6
const ROUND_TIMEOUT := 90.0      ## a round's stragglers cannot hold the next one off longer than this
const NIGHT_HP := 1.25           ## what walks at night is tougher than what walks by day
const NIGHT_HARM := 1.2          ## and bites harder
var _round_n := 0
var _round_live := false
var _round_age := 0.0
var _round_foes: Array = []


func _round_tick(delta: float) -> void:
	if _round_n >= ROUNDS_MAX:
		return
	if _round_live:
		_round_age += delta
		_round_foes = _round_foes.filter(func(e): return is_instance_valid(e) and e.is_alive())
		if _round_foes.is_empty() or _round_age > ROUND_TIMEOUT:
			_round_live = false
			_wave_t = randf_range(30.0, 45.0) * float(WRules.pace()[1])
		return
	_wave_t -= delta
	if _wave_t > 0.0:
		return
	var to_dawn := fposmod(weather.dawn() - clock, 24.0) * DAY_SECONDS / 24.0
	var last := _round_n + 1 >= ROUNDS_MAX or to_dawn < 200.0
	var made := _night_wave((0.75 + 0.12 * _round_n) * (1.4 if last else 1.0))
	if made.is_empty():
		_wave_t = 12.0   # no one out in the open: it waits for them
		return
	_round_n = ROUNDS_MAX if last else _round_n + 1
	_round_foes = made
	_round_live = true
	_round_age = 0.0


## Toughens one of the night's walkers.
func _night_grit(e) -> void:
	if e and is_instance_valid(e) and e is LesserSpeeb:
		e.hp *= NIGHT_HP
		e.max_hp *= NIGHT_HP


## One round of the night's walkers, k times the usual size. Returns those it brought.
func _night_wave(k := 1.0) -> Array:
	var made: Array = []
	var tg := targets()
	if tg.is_empty():
		return made
	var cap := mini(int(WCrowd.scale(self, 10 + mini(nights, 10)) * (1.25 if night_theme == "long" else 1.0) * float(WRules.pace()[0])), WCrowd.ALIVE_CAP)
	if flags.get("ending", "") == "writer":
		cap = int(cap / 2)   # the Mouth is closed; what walks now is only what was left
	if flags.get("ending", "") == "unlit":
		return made   # it has what it wanted: nothing comes at night
	for t in tg:
		if safe_at(t.global_position):
			continue
		if alive_count() >= cap:
			return made
		# Fewer come near home, more in the far lands
		var tier := tier_at(t.global_position)
		var n := maxi(1, int(round((2 + int(nights * 0.5) + randi() % 2) * [0.6, 0.85, 1.0, 1.15, 1.25][tier - 1] * WCrowd.share(self, t.global_position) * float(NIGHT_THEMES.get(night_theme, {}).get("many", 1.0)) * float(WRules.pace()[0]) * night_press() * k)))
		var roster: Array = forms_at(t.global_position)
		# The night leans on the heavy and on those that strike from afar
		var hard: Array = roster.filter(func(f): var sp: Dictionary = LesserSpeeb.KINDS.get(f, {}); return str(sp.get("role", "")) == "gun" or f == "spitter" or float(sp.get("hp", 0.0)) >= 150.0)
		# Near where the cast-out wake, the box cats run in packs some nights
		# (rare and small on the first nights; a pack is sized for those near, not for the whole group)
		var screaming := night_theme == "screaming"
		if (tier == 1 and nights >= 1 and randf() < (0.8 if screaming else 0.08 + 0.02 * mini(nights, 6))) or (screaming and randf() < 0.3):
			var base := (randi_range(6, 9) + mini(nights, 5)) if screaming else (randi_range(3, 4) + mini(nights, 4))
			var pack := mini(int(base * WCrowd.share(self, t.global_position) * float(WRules.pace()[0])), WCrowd.ALIVE_CAP - alive_count())
			var from: Vector3 = t.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 40.0
			for i in pack:
				var bc = _spawn_near("box_cat", from, 2.0, 8.0)
				if bc and bc.has_method("seek"):
					bc.seek(t.global_position, 60.0)
				if bc:
					made.append(bc)
			if pack > 0:
				sfx("shriek_%d" % (randi() % 4), 0, from, 2.1)
			continue
		# The night's walkers come in mixed packs, each from its own side
		var picks: Array = []
		while picks.size() < n:
			var band := pack_at(t.global_position)
			if not hard.is_empty() and randf() < 0.35:
				band[randi() % band.size()] = hard[randi() % hard.size()]
			picks.append_array(band)
		picks.resize(n)
		var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 38.0
		for i in n:
			var pick: String = picks[i]
			if i > 0 and i % 4 == 0:
				side = side.rotated(Vector3.UP, randf_range(1.2, 2.4))
			var e = _spawn_near(pick, t.global_position + side, 2.0, 10.0)
			# The night's walkers come looking for the living; they need not see you yet
			if e and e.has_method("seek"):
				e.seek(t.global_position, 40.0)
			if e:
				_night_grit(e)
				made.append(e)
		if nights >= 2 and tier >= 2 and randf() < 0.12 + nights * 0.02:
			var sc = _spawn_near("saucer", t.global_position, 30.0, 40.0)
			if sc:
				made.append(sc)
		if (nights >= 4 and tier >= 3 and randf() < 0.06 + nights * 0.01) or (night_theme == "hunt" and randf() < 0.35):
			var el = _spawn_near("elite", t.global_position, 35.0, 45.0)
			if el:
				_night_grit(el)
				made.append(el)
			hud.notify("Something greater walks tonight.")
		# Some nights, in the dark country, something follows that is hardly there at all
		var bio: String = terrain.biome_name(t.global_position.x, t.global_position.z)
		var dark := 0.1 if bio in ["forest", "marsh", "basalt"] else 0.04
		if nights >= 1 and tier >= 2 and randf() < dark + nights * 0.01 and _unseen_count() < tg.size():
			_spawn_near("unseen", t.global_position, 34.0, 46.0)
		if randf() < 0.25:
			sfx("horror_deep", -10, t.global_position + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)), randf_range(0.8, 1.0))
	return made


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


## After a fight by day the waste lets you breathe: while a foe is near, and for a while after the
## last one falls, no stray comes and no road ahead turns to a fight.
const CALM := 90.0          ## the breather after a fight, in seconds
const CALM_NEAR := 120.0    ## longer in the near lands, while one is still learning
var breather := 0.0
var _roam_t := 200.0


## By day the waste is quieter, but the ruins are not empty, and the roads are not always clear.
func _day_watch() -> void:
	var tg := targets()
	var fighting := false
	for e in enemies:
		if is_instance_valid(e) and e.is_alive() and e.boss == "" and tg.any(func(t): return t.global_position.distance_to(e.global_position) < 60.0):
			fighting = true
			break
	if fighting:
		var near := tg.any(func(t): return tier_at(t.global_position) == 1)
		breather = CALM_NEAR if near else CALM
	else:
		breather = maxf(0.0, breather - 6.0)
	_road_tick(6.0)
	_roam_t -= 6.0
	if _roam_t <= 0.0:
		_roam_t = 30.0 if breather > 0.0 else randf_range(180.0, 240.0)
		if breather <= 0.0:
			_roam()
	for t in tg:
		var p: Vector3 = t.global_position
		if safe_at(p) or settlement_at(p, 40.0) != "":
			continue
		for r in ruins:
			if int(r.guard_day) != day and p.distance_to(r.pos) < 55.0:
				r.guard_day = day
				var n := WCrowd.scale_near(self, r.pos, 2 + randi() % 3)
				if r.has("isle") or r.has("far"):
					# An isle's heart is kept more fiercely, by its own kind (and the far ruins by theirs)
					var roster: Array = forms_at(r.pos)
					for k in n + (2 if r.has("isle") else 0):
						_spawn_near(roster[randi() % roster.size()], r.pos, 8.0, 18.0, true)
					continue
				var tr := tier_at(r.pos)
				var guards: Array = ["rusher", "spitter", "spider", "idol", "brute", "howler", "hollow", "saltbone", "hollow", "warden"].filter(func(k): return int(LesserSpeeb.FORM_TIER.get(k, 1)) <= tr)
				if gentle_at(r.pos):
					guards = GENTLE_FORMS   # the ground about the start is gentle, its ruins too
				for k in n:
					_spawn_near(guards[randi() % guards.size()], r.pos, 6.0, 14.0, true)


## A stray by day, or a pair: what that land breeds, come upon one of the fellowship in the open.
func _roam() -> void:
	if alive_count() >= 2:
		return
	var tg := targets()
	tg.shuffle()
	for t in tg:
		var p: Vector3 = t.global_position
		if safe_at(p) or settlement_at(p, 40.0) != "":
			continue
		var roster: Array = forms_at(p)
		for i in (2 if randf() < 0.4 else 1):
			_spawn_near(roster[randi() % roster.size()], p, 40.0, 60.0)
		return


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
		# The waste's music director plays the fight loop in its place
		_music.queue_free()
		_music = null
	if music == null and not Net.dedicated:
		music = WMusic.new(self)
		add_child(music)


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
	_bestiary(e)
	if e.boss != "":
		shared("_w_boss_down", [e.boss, e.global_position])
		return
	if e.variant == "bellwound":
		shared("_w_kraken_down", [day])
		return
	award("kill_elite" if e.kind in ["elite", "saucer"] else "kill", TIER_XP[clampi(tier_at(e.global_position), 1, TIER_XP.size()) - 1])
	var near_town := town_near(e.global_position, SAFETY_REACH)
	if near_town != "":
		shared("_w_safety", [near_town, SAFETY_ELITE if e.kind in ["elite", "saucer"] or e.has_meta("champion") or e.max_hp >= 150.0 else SAFETY_KILL, Net.my_name()])
	if not squadmates().is_empty():
		shared("_w_squad_kill", [Net.me(), "kill_elite" if e.kind in ["elite", "saucer"] else "kill", e.global_position])
	_ammo_drop(e)
	if randf() < (0.5 if e.kind in ["elite", "saucer"] else 0.12) + skills.drop_bonus():
		var drop: Array = Items.roll("corpse", 2 if e.kind in ["elite", "saucer"] else 1, _gen)
		if e.kind in ["elite", "saucer"] and _gen.randf() < 0.3:
			drop.append(["fittings_fine" if _gen.randf() < 0.75 else "fittings_rare", 1])
		shared("_rq_satchel", [Net.me(), e.global_position, drop, false])
	# A champion's pickings: more, and a fitting more often than not
	if e.has_meta("champion"):
		var cd: Array = Items.roll("corpse", 3, _gen) + Items.roll("caravan", 1, _gen)
		if _gen.randf() < 0.6:
			cd.append(["fittings_fine" if _gen.randf() < 0.7 else "fittings_rare", 1])
		shared("_rq_satchel", [Net.me(), e.global_position + Vector3(0.6, 0, 0), cd, false])


## A slain foe now and then leaves a few rounds where it fell: for one of the guns you carry, more often
## than not. Never health: that is found and made, not shaken out of the dead.
const AMMO_DROP := 0.45
const AMMO_DROP_N := {"shells": [2, 5], "rounds": [4, 10], "rifle": [5, 12], "rockets": [1, 1], "fuel": [10, 20]}
var ammo_drops := 0   ## (for the tests)

func _ammo_drop(e: LesserSpeeb) -> void:
	if randf() >= AMMO_DROP * (1.0 + (1.0 if e.has_meta("champion") else 0.0)):
		return
	var kinds: Array = []
	for g in [arms.primary, arms.get("primary2", ""), arms.secondary]:
		if str(g) != "" and Items.AMMO.has(str(g)):
			kinds.append(Items.AMMO[str(g)])
	if kinds.is_empty() or randf() < 0.25:
		kinds = ["shells", "rounds", "rifle"]
	var id: String = kinds[randi() % kinds.size()]
	var r: Array = AMMO_DROP_N.get(id, [2, 6])
	ammo_drops += 1
	# Foes of the harder lands take more to bring down, and carry more: a drop is the same share of a kill
	var k: float = TIER_HP[clampi(tier_at(e.global_position), 1, TIER_HP.size()) - 1]
	var n := maxi(1, int(round(randi_range(int(r[0]), int(r[1])) * (k if id != "rockets" else 1.0))))
	shared("_rq_satchel", [Net.me(), e.global_position, [[id, n]], false])


const HARM_WORDS := {"shot": "shotgun spread", "bullet": "bullets", "blade": "blades", "blast": "blasts", "fire": "fire", "blunt": "heavy blows"}

## The first time a form falls to you, its page: what it is, and what it fears.
func _bestiary(e: LesserSpeeb) -> void:
	var key: String = e.variant if e.variant != "" else e.kind
	if slain_kinds.has(key) or _pfail:
		return
	slain_kinds[key] = true
	var weak: Array = []
	for h in e.spec.get("weak", {}):
		if float(e.spec.weak[h]) > 1.0:
			weak.append(HARM_WORDS.get(h, h))
	var hard: Array = []
	for h in e.spec.get("tough", {}):
		if float(e.spec.tough[h]) < 1.0:
			hard.append(HARM_WORDS.get(h, h))
	var text := str(e.spec.get("text", ""))
	if not weak.is_empty():
		text += " Weak to %s." % ", ".join(weak)
	if not hard.is_empty():
		text += " Hard against %s." % ", ".join(hard)
	hud.revelation("Bestiary: %s (%d of %d known)" % [str(e.spec.name), slain_kinds.size(), bestiary_total()], text)
	_completion_check()
	WPlaylog.note("First %s slain" % str(e.spec.name))


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


func _w_vault_wind(id: String, frac: float, manned: int) -> void:
	if vaults:
		vaults.wind_shown(id, frac, manned)


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
	shared("_rq_boat_hp", [b.id, float(b.spec.hp) * 0.4])
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
			_station_told(b)
	elif r.has(Net.me()) and was and player.vessel == b:
		_station_told(b)
	elif not r.has(Net.me()) and was and player.vessel == b:
		player.vessel = null


var _station_said := ""

## A rider is told what their station does, when they take it or move to another.
func _station_told(b: WBoat) -> void:
	var st := b.station_of(Net.me())
	if st == _station_said:
		return
	_station_said = st
	var t: String = WBoat.STATION_TEXT.get(st, "You sit aboard. Shoot from here.")
	if st == "sail":
		t = t % [Game.key_text("move_forward"), Game.key_text("move_back")]
	hud.notify(t + " Hold [%s] on the boat to change station, press it to step off." % Game.key_text("interact"))


## A rider moves to a free station aboard.
func _rq_station(bid: int, by: int, to: int) -> void:
	if not Net.authority() or not boats.has(bid):
		return
	var b: WBoat = boats[bid]
	if not b.riders.has(by) or int(b.riders[by]) == 0 or to <= 0 or to >= int(b.spec.seats) or to in b.riders.values():
		return
	var r := b.riders.duplicate()
	r[by] = to
	shared("_w_riders", [bid, r])


func _w_boat_sail(bid: int, to: int) -> void:
	if boats.has(bid) and is_instance_valid(boats[bid]):
		boats[bid].sail_set(to)


## The lookout's call: everyone aboard hears what it is, where it lies and how far.
func _w_lookout(bid: int, at: Vector3, what: String, where: String) -> void:
	if not boats.has(bid) or not is_instance_valid(boats[bid]):
		return
	var b: WBoat = boats[bid]
	if not b.riders.has(Net.me()) or Net.dedicated:
		return
	var d := int(at.distance_to(b.global_position))
	hud.notify("Lookout: %s, %s, %d paces." % [what, where, d])
	sfx("bell", -14, null, 1.4)


## Off the boat: onto dry ground near it if there is any, or into the water beside it.
func _leave_boat(b: WBoat) -> void:
	shared("_rq_leave", [b.id, Net.me()])
	player.vessel = null
	_station_said = ""
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


## A change to a boat's hull, by how much: the host adds up several at once (two serpents in one breath) rightly.
func _rq_boat_hp(bid: int, change: float) -> void:
	if Net.authority() and boats.has(bid):
		var b: WBoat = boats[bid]
		shared("_w_boat_hp", [bid, minf(float(b.spec.hp), b.hp + change)])


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
	shared("_rq_boat_hp", [b.id, -amount])
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
	if Input.is_action_just_pressed("quick_heal") and not player.input_locked and not get_tree().paused:
		quick_heal()
	if Input.is_action_just_pressed("whistle") and not player.input_locked and skills.has_boon("rally"):
		rally()
	if Input.is_action_just_pressed("whistle") and not player.input_locked and cat:
		sfx("bell", -14, null, 2.2)
		cat.call_to(player)
		hud.notify("You whistle for %s." % cat.cat_name)
	_verbs_tick(delta)
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
	if town == "" or night or randf() > 0.25 or not has_verb(1):
		return   # strays come near the towns once the first fire burns
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
		_apply_skills()   # a Pack-Cat carries from now on
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
	var lethal := amount >= 9000.0   # drowned or fallen: no armour, guard, mount or boat takes any of that
	if not lethal and player.dodge_t > 0.0 and from.distance_to(player.global_position) < 6.0:
		# Stepped aside in time
		hud.hitmarker(false, true)
		return
	# Bulwark (the eighth fire): the beacons' blessing takes the first blow of each night
	if night and not lethal and not bulwark_spent and has_verb(8) and amount > 0.5:
		bulwark_spent = true
		sfx("bell", -6, null, 1.3)
		hud.hitmarker(false, true)
		hud.notify("The beacons' blessing takes the blow. It will not again until tomorrow night.")
		return
	amount *= Game.difficulty_scale("damage") * skills.harm_mult() * (1.0 - WArms.worn(arms).guard) * alchemy.harm_mult()
	if WRules.sworn("vow_glass"):
		amount *= 1.5
	amount *= TIER_HARM[tier_at(from) - 1] * vow_mult(from, 1.25)
	amount *= 1.0 - 0.2 * power_k("gilt")
	var wpn = player.weapon
	if wpn and wpn.guarding and wpn.enabled and not lethal:
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
	if not lethal and player.vessel != null and is_instance_valid(player.vessel) and amount >= 10.0:
		hurt_boat(player.vessel, amount * 0.6)
	# Riding, the cat takes half of the blow; hurt out, it throws its rider and runs off a while
	if player.mount and cat and not lethal:
		if cat.take(amount * 0.5):
			dismount()
			hud.notify("%s throws you and will not carry you for %d seconds. Meat would soothe it." % [cat.cat_name, int(WCat.REST_HURT)])
			hud.say("%s throws you and bolts. It will be back when it has licked its wounds." % cat.cat_name, 4.0)
			cat.call_to(player)
			cat._call = false
		amount *= 0.5
	# Plate worn on the body (or the helm, now and then) soaks part of the blow and wears down
	var pt := WArms.plate_take(arms, amount, randf() < 0.25) if not lethal else [amount, false]
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
	if player.vessel != null and is_instance_valid(player.vessel):
		_leave_boat(player.vessel)   # or the boat would carry them on, and they would wake aboard it
	_burn = 0.0
	_slow = 0.0
	_freeze = 0.0
	_blind = 0.0
	meals.clear()
	_meal_stats()
	life_kills = 0
	_pfail = true
	if night:
		_fell_tonight = true   # a named night gives nothing at dawn to one who fell in it
	shared("_w_fell", [Net.me()])
	WPlaylog.note("Fell: " + message.replace("\n", " "))
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
		# Kept at once, empty-handed, so leaving the game before waking cannot keep both the pack and the satchel
		if not Net.dedicated and world_uid != "":
			var cd := char_data().duplicate(true)
			cd["pos"] = respawn_point()
			cd["hp"] = player.max_health
			_save_wait()
			Game.write_safe(_char_path(), var_to_str(cd))
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


var _radio_t := 240.0
var _radio_warned := -1


## The ash-radio, carried: now and then a call for help nearby, and at dusk word of the night to come.
func _radio_tick(delta: float) -> void:
	if not ready_world or _pfail or inv.count("ash_radio") <= 0:
		return
	_radio_t -= delta
	if _radio_t <= 0.0:
		_radio_t = randf_range(240.0, 360.0)
		shared("_rq_broadcast", [Net.me(), player.global_position])
	# An hour before dusk, what the night will be
	if not night and clock >= weather.dusk() - 1.0 and clock < weather.dusk() and _radio_warned != day:
		_radio_warned = day
		var n := nights + 1
		var theme := night_theme_for(n)
		var word := "The great raid comes tonight. Be near a fire." if great_night(n) \
			else ("Tonight: %s. %s" % [NIGHT_THEMES[theme].name, NIGHT_THEMES[theme].text] if theme != "" else "A plain night, they say. Keep your fire lit anyway.")
		hud.notify("The ash-radio crackles: " + word)
		sfx("bell", -16, null, 0.7)


func _rq_broadcast(by: int, near: Vector3) -> void:
	if not Net.authority() or events == null:
		return
	if not events.broadcast(near):
		Net.call_peer(by, "_w_radio_quiet", [])


func _w_radio_quiet() -> void:
	hud.notify("The ash-radio hisses. Nobody out there is calling just now.")


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
	var cell := REVEAL_HALF * 2.0 / REVEAL_N
	var ci := int((p.x + REVEAL_HALF) / cell)
	var cj := int((p.z + REVEAL_HALF) / cell)
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
	var cell := REVEAL_HALF * 2.0 / REVEAL_N
	var i := clampi(int((p.x + REVEAL_HALF) / cell), 0, REVEAL_N - 1)
	var j := clampi(int((p.z + REVEAL_HALF) / cell), 0, REVEAL_N - 1)
	return revealed[j * REVEAL_N + i] != 0


var _biome := ""


var _region := ""


func _visit_check() -> void:
	if lights:
		lights.local_tick()
	var bn := land_at(player.global_position)
	var region := terrain.region_name(player.global_position.x, player.global_position.z)
	if region != _region:
		var il := terrain.isle_at(player.global_position.x, player.global_position.z, 1.4)
		if _region != "":
			if region == WTerrain.SEA_NAME:
				hud.notify("The Grey Sea\nOpen water. Keep to a boat: a swimmer tires, and things live under it.")
			elif not il.is_empty() and region == il.name:
				if not visited.has("isle_" + str(il.key)):
					visited["isle_" + str(il.key)] = true
					sfx("jingle_find", -8)
					hud.title_card("", il.name)
					award("settlement")
				hud.notify("%s (danger %d of %d)\n%s%s" % [il.name, tier_at(player.global_position), tiers_known(), WIsles.THEMES[il.key].text, land_warning(bn) if LAND_WARD.has(bn) else ""])
			else:
				hud.notify("%s (danger %d of %d)\n%s%s" % [WTerrain.BIOME_NAMES.get(bn, region), tier_at(player.global_position), tiers_known(), BIOME_TEXT.get(bn, ""), "" if gentle_at(player.global_position) else land_warning(bn)])
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
		reach_stage("trades")
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
	Net.send_snapshot(by, world_data())
	# Who is aboard what, so the newcomer sees them seated
	for bid in boats:
		if is_instance_valid(boats[bid]) and not boats[bid].riders.is_empty():
			Net.call_peer(by, "_w_riders", [bid, boats[bid].riders])
	# The events now under way, so the newcomer sees their smoke and can share what they give
	if events:
		for id in events.active:
			var ev: Dictionary = events.active[id]
			if not ev.get("done", false):
				Net.call_peer(by, "_w_event_start", [id, ev.kind, ev.pos])


## A newcomer asks again now and then while nothing of the world has come (a first word may be lost).
func _hello_again() -> void:
	var t := 0.0
	while is_inside_tree() and snap_wait and Net.online:
		await get_tree().create_timer(1.0).timeout
		t += 1.0
		if _snap_parts.is_empty() and terrain == null and int(t) % 12 == 0:
			shared("_rq_hello", [Net.me()])


var snap_wait := false        ## a newcomer whose world is still arriving
var snap_queue: Array = []    ## what happened meanwhile, to be played once it has
var _snap_parts: Array = []


func _w_snap_part(i: int, n: int, raw: int, part: PackedByteArray) -> void:
	if n <= 0 or n > 4096 or raw <= 0 or raw > 512 * 1024 * 1024:
		return   # no world is this big: a damaged or hostile message, not to be unpacked
	if i == 0 or _snap_parts.size() != n:
		_snap_parts = []
		_snap_parts.resize(n)
	if i < 0 or i >= n:
		return
	_snap_parts[i] = part
	if hud and hud.loading.visible:
		# The newcomer's loading screen stays up: first the world comes over, then it is raised here
		hud.set_loading("The world is sent")
		hud.set_loading_progress(0.25 * (i + 1) / n)
	elif hud and n > 4:
		hud.set_banner("", "The waste is taking shape  %d%%" % int(100.0 * (i + 1) / n))
	for p in _snap_parts:
		if p == null:
			return
	var all := PackedByteArray()
	for p in _snap_parts:
		all.append_array(p)
	_snap_parts = []
	if hud and n > 4:
		hud.set_banner("", "")
	var d = bytes_to_var(all.decompress(raw, FileAccess.COMPRESSION_ZSTD))
	if not (d is Dictionary):
		push_warning("Wasteland: the world sent could not be read")
		return
	await _w_snapshot(d)
	snap_wait = false
	var q := snap_queue
	snap_queue = []
	for c in q:
		if has_method(c[0]):
			callv(c[0], c[1])


func _w_snapshot(d: Dictionary) -> void:
	if terrain == null:
		# Raised a step at a time, as the host's was, so the window never hangs and the bar moves on
		_prog_from = 0.25
		await _make_world(int(d.get("seed", 1771)), int(d.get("gen", 1)), not Net.dedicated)
		_prog_from = 0.0
		player.place(spawn_pos, spawn_yaw)
	apply_world(d)
	ready_world = true
	_world_ready()
	Net.settled()
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
		pcs[pid] = [pc.kind, pc.pos, pc.yaw, pc.hp, pc.get("open", false), {"name": pc.get("name", ""), "crop": pc.get("crop", ""), "sown": pc.get("sown", 0.0), "fuel": pc.get("fuel", -1.0), "tier": pc.get("tier", 0), "owner": pc.get("owner", ""), "hung": pc.get("hung", [])}]
	var crate_days := {}
	for id in crates:
		if int(crates[id].day) > -99:
			crate_days[id] = crates[id].day
	var sat := {}
	for sid in satchels:
		sat[sid] = [satchels[sid].pos, satchels[sid].grave, str(satchels[sid].get("owner", "")), int(satchels[sid].get("day", day)), bool(satchels[sid].get("keep", false))]
	return {
		"v": 2, "gen": world_gen, "uid": world_uid, "seed": world_seed, "day": day, "clock": clock, "nights": nights, "night": night, "lit": lit, "flags": flags, "rep": rep, "safety": safety, "deeds": deeds,
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
			out[bid] = [b.kind, Game.world_pos(b), b.yaw, b.hp]
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
	safety = d.get("safety", {}) if d.get("safety") is Dictionary else {}
	deeds = d.get("deeds", {}) if d.get("deeds") is Dictionary else {}
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
			if p[5].get("hung") is Array and not p[5].hung.is_empty():
				_w_hang(int(pid), p[5].hung.filter(func(t): return POWERS.has(str(t))))
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
		var sd: Array = d.satchels[sid]
		_w_satchel(sid, sd[0], sd[1], str(sd[2]) if sd.size() > 2 else "", int(sd[3]) if sd.size() > 3 else int(d.get("day", 1)), bool(sd[4]) if sd.size() > 4 else false)
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
		"visited": visited, "known": known_ruins, "skills": skills.to_data(), "biomes": seen_biomes, "bedroll": bedroll, "warms": arms, "food": food, "rest": rest, "kindled": my_kindled() if ready_world else (kindled if kindled != null else []), "traces": traces_seen, "slain": slain_kinds, "completed": rewards_had,
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
	kindled = null
	if d.get("kindled") is Array:
		kindled = []
		for k in d.kindled:
			kindled.append(int(k))
	traces_seen = d.get("traces", {}) if d.get("traces") is Dictionary else {}
	slain_kinds = d.get("slain", {}) if d.get("slain") is Dictionary else {}
	rewards_had = d.get("completed", {}) if d.get("completed") is Dictionary else {}
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
		elif raw.size() == 320 * 320:
			_reveal_from(raw, 320, 3200.0)   # drawn before the far sea was added
		elif raw.size() == 256 * 256:
			_reveal_from(raw, 256, WPlaces.HALF)   # drawn before the fog lay over the sea too
		elif raw.size() == 128 * 128:
			_reveal_from(raw, 128, WPlaces.HALF * 0.5)   # drawn before the waste grew
	visited = d.get("visited", {})
	known_ruins = d.get("known", {})
	bedroll = d.get("bedroll", null)
	player.weapon._ui()


## An older map's known ground, laid onto the fog as it is now.
func _reveal_from(raw: PackedByteArray, n: int, half: float) -> void:
	var cell := REVEAL_HALF * 2.0 / REVEAL_N
	for j in REVEAL_N:
		for i in REVEAL_N:
			var x := -REVEAL_HALF + (i + 0.5) * cell
			var z := -REVEAL_HALF + (j + 0.5) * cell
			var oi := int((x + half) / (half * 2.0) * n)
			var oj := int((z + half) / (half * 2.0) * n)
			if oi >= 0 and oj >= 0 and oi < n and oj < n and raw[oj * n + oi] != 0:
				revealed[j * REVEAL_N + i] = 1


## Every lit beacon shows the land about it.
func reveal_lit() -> void:
	for i in lit:
		if i < beacon_nodes.size():
			_reveal_around(beacon_nodes[i].pos, BEACON_SIGHT)


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
	if not d is Dictionary and Game.set_aside_damaged(_char_path()):
		_damaged = true
	if _damaged:
		hud.say("Your save could not be read. It was kept aside, and a new one begun.", 10.0)
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
	kindled = []   # a new pilgrim has lit nothing yet, whatever the fellowship has
	inv.from_data([])
	inv.add("bandage", 2)
	inv.add("cloth", 2)   # enough for the first bandage the first steps ask for, wherever the cast-out wake
	inv.add("meat", 2)
	inv.add("salt", 12)
	inv.add("shells", 18)
	inv.add("rounds", 24)
	inv.add("milk", 1)
	drop_in_kit()
	player.weapon.equip_loadout()
	player.weapon.shells = player.weapon.capacity()
	player.weapon._ui()


## A pilgrim new to a fellowship that is already far along the road should be of use within minutes,
## not hours: they come with what the fellowship can spare, more for each beacon it has lit.
## Returns how many beacons the kit was made for (0: the plain start).
func drop_in_kit() -> int:
	var n := mini(lit.size(), 6)
	if n <= 0:
		return 0
	var t := clampi((n + 1) / 2, 1, 2)
	for g in ["shotgun", "pistol", "hatchet"]:
		arms.tier[g] = maxi(int(arms.tier.get(g, 0)), t)
	if not "revolver" in arms.owned:
		arms.owned.append("revolver")
	if n >= 2 and not "machete" in arms.blades:
		arms.blades.append("machete")
	if n >= 3 and not "machine_gun" in arms.owned:
		arms.owned.append("machine_gun")
		arms.primary2 = "machine_gun"
	inv.add("shells", 12 * n)
	inv.add("rounds", 20 * n)
	inv.add("bandage", 2 + n)
	inv.add("meat", 2 + n)
	inv.add("scrap", 10 * n)
	if n >= 2:
		inv.add("fittings_fine", 1)
	Game.warms = arms
	if hud:
		hud.notify("The fellowship has lit %d %s. You come with what it can spare." % [n, "beacon" if n == 1 else "beacons"])
	return n


## Keeps the world (if this is the host) and this survivor's own character.
## Both are written crash-safe, with the previous save kept as a backup.
## Keeps the world and this pilgrim. In the background (an autosave), what is kept is gathered
## now, and turned to text and written on a worker thread, so play does not stop for it. Leaving
## and closing save at once, after any save still being written has finished.
func save_all(background := false) -> void:
	# This also runs from _exit_tree, after the player has already left the tree; its data is still good
	if world_uid == "" or not is_instance_valid(player):
		return
	_save_wait()
	DirAccess.make_dir_recursive_absolute("user://wasteland")
	var jobs: Array = []
	if _owns_world:
		jobs.append([world_path(slot), world_data().duplicate(true)])
	if not Net.dedicated and not _pfail:
		jobs.append([_char_path(), char_data().duplicate(true)])
	_save_t = _save_every()
	_save_soon = -1.0
	_last_save = Time.get_ticks_msec()
	if background:
		_save_task = WorkerThreadPool.add_task(_write_jobs.bind(jobs, true), false, "Brelm autosave")
	else:
		_write_jobs(jobs, false)


var _save_task := -1


## Waits for a save being written in the background, if there is one.
func _save_wait() -> void:
	if _save_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_save_task)
		_save_task = -1


func _write_jobs(jobs: Array, threaded: bool) -> void:
	var ok := true
	for j in jobs:
		ok = Game.write_safe(j[0], var_to_str(j[1])) and ok
	if threaded:
		_saved.call_deferred(ok)
	else:
		_saved(ok)


func _saved(ok: bool) -> void:
	if not is_instance_valid(self):
		return
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
				save_all(true)


## A short line for the title screen's list of worlds.
static func describe(s: String) -> String:
	var d = Game.read_var_safe(world_path(s))
	if not d is Dictionary:
		return ""
	return "Day %d, %d of 9 beacons burning, seed %d" % [int(d.get("day", 1)), d.get("lit", []).size(), int(d.get("seed", 1771))]


# ================================================================== calls the fellowship shares, passed on to their keepers

func _rq_build(by: int, k: String, p: Vector3, yaw: float, hm := 1.0, paid = null) -> void:
	builder._rq_build(by, k, p, yaw, hm, paid)


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


func _rq_tier(by: int, pid: int, t: int, paid = null) -> void:
	builder._rq_tier(by, pid, t, paid)


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



## Testing aid: cuttable dead trees wear nothing stuck on (no red band, no notch box), the fire hound
## wears its own head, and a red dot shows only down the sight.
func debug_glitchfix() -> void:
	while not ready_world:
		await get_tree().create_timer(0.5).timeout
	var trees := 0
	var stray := 0
	for nd in nodes:
		if nd.kind != "tree" or not is_instance_valid(nd.node):
			continue
		trees += 1
		for mi in nd.node.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh is BoxMesh or (mi as MeshInstance3D).mesh is CylinderMesh:
				stray += 1
	var e := LesserSpeeb.new().setup(Game.lesser.keys()[3], "boss_ash", self)
	add_child(e)
	e.global_position = player.global_position + Vector3(0, 0, -14)
	await get_tree().create_timer(0.5).timeout
	var own: bool = e._sk == "boss_ash" and not e.head.visible
	e.queue_free()
	var g: String = player.weapon.gun()
	var am: Dictionary = Game.arms_now()
	if not am.has("mounts") or not (am.mounts is Dictionary):
		am["mounts"] = {}
	am.mounts[g] = ["holo"]
	player.weapon.refinish()
	player.weapon._aim = 0.0
	player.weapon._show_dots()
	var dots: Array = player.weapon._dots
	var hip := dots.any(func(q): return q.visible)
	player.weapon._aim = 1.0
	player.weapon._show_dots()
	var aimed := not dots.is_empty() and dots.all(func(q): return q.visible)
	player.weapon._aim = 0.0
	# A wall right ahead draws the gun back; with it gone the gun comes forward again
	var cam: Camera3D = player.cam
	var wall := StaticBody3D.new()
	var wcs := CollisionShape3D.new()
	var wb := BoxShape3D.new()
	wb.size = Vector3(3, 3, 0.2)
	wcs.shape = wb
	wall.add_child(wcs)
	add_child(wall)
	wall.global_transform = Transform3D(cam.global_transform.basis, cam.global_position - cam.global_transform.basis.z * 0.45)
	await get_tree().create_timer(0.8).timeout
	var tucked: bool = player.weapon._tuck > 0.6
	wall.queue_free()
	await get_tree().create_timer(0.8).timeout
	var back: bool = player.weapon._tuck < 0.05
	print("GLITCHFIX trees=%s stray=%d hound_own_head=%s dots=%s hip=%s aimed=%s tucked=%s back=%s" % [trees > 0, stray, own, not dots.is_empty(), hip, aimed, tucked, back])
	get_tree().quit()


## Testing aid: one's own arms reach each gun's grip and fore-end (or its magazine, mid-reload), the SMG's
## cocking handle goes back and up and is slapped home, and a cigarette lights and burns while the gun is held.
func debug_hands() -> void:
	while not ready_world:
		await get_tree().create_timer(0.5).timeout
	var arms: Arms = player.weapon
	var h: FPHands = arms.hands
	var far := []
	var n := 0
	for g in ArmsDB.GUNS:
		if not arms._st.has(g):
			arms._st[g] = {"mag": 5, "reserve": 10}
		arms.guns = [g, arms.guns[1]]
		arms.cur = 0
		arms._show_model()
		for k in [-1.0, 0.3]:
			arms._reloading = k >= 0.0
			if k >= 0.0:
				arms._reload_pose(k, 1.0)
			for i in 3:
				await get_tree().process_frame
			var p := arms.hand_pose()
			if not FPHands.SHOWN:
				h.debug_pose = "hip"   # drawn only for this check while the arms are off
				await get_tree().process_frame
				h.debug_pose = ""
			if p.is_empty():
				far.append(g + ":none")
				continue
			for sd in ["R", "L"]:
				var d: Dictionary = h._side[sd]
				var w: Vector3 = h._sk.global_transform * h._sk.get_bone_global_pose(d.wrist).origin
				var palm: Vector3 = w + h._sk.global_transform.basis * (h._sk.get_bone_global_pose(d.wrist).basis.orthonormalized() * (d.palm as Vector3))
				# The palm's middle within a few centimetres of where it was sent (the magazine may drop out of reach)
				if palm.distance_to(p[sd].at) > (0.04 if k < 0.0 else 0.12):
					far.append("%s:%s%s:%.2f" % [g, sd, "" if k < 0.0 else "@rl", palm.distance_to(p[sd].at)])
		arms._reloading = false
		arms._reload_rest(1.0)
		n += 1
	# The SMG worked as its makers meant: back and up, the magazine changed, slapped home
	arms.guns = ["smg", arms.guns[1]]
	arms._show_model()
	var rig: bool = arms._model.has_meta("rig")
	arms._reload_pose(0.3, 1.0)
	var locked: bool = arms._handle_back > 0.95 and arms._handle_up > 0.95
	arms._reload_pose(0.9, 1.0)
	var home: bool = arms._handle_back < 0.05 and arms._handle_up < 0.05
	arms._reload_rest(1.0)
	# The belt gun moves as it was made to, our arms following its own; the revolver's crane swings out
	arms.guns = ["lmg", arms.guns[1]]
	arms._show_model()
	var lp := arms.hand_pose()
	var anim: bool = arms._model.has_meta("anim") and lp.has("R") and (lp.R as Dictionary).has("S")
	arms.guns = ["revolver", arms.guns[1]]
	arms._show_model()
	arms._reloading = true
	arms._reload_pose(0.4, 1.0)
	arms.hand_pose()
	var rsk: Skeleton3D = arms._model.get_meta("anim_sk") if arms._model.has_meta("anim_sk") else null
	var crane := false
	if rsk:
		var cb := rsk.find_bone("Extractor_03")
		crane = cb >= 0 and rsk.get_bone_pose_rotation(cb).angle_to(rsk.get_bone_rest(cb).basis.get_rotation_quaternion()) > 1.0
	arms._reloading = false
	arms._reload_rest(1.0)
	# A cigarette, lit with the gun in hand
	inv.add("cigarettes", 3)
	var lit := smoke("cigarettes")
	var twice := smoke("cigarettes")
	await get_tree().create_timer(1.0).timeout
	var burning: bool = smoking != null and smoking.lit and smoking.left < WSmoke.BURN and inv.count("cigarettes") == 2
	print("HANDS guns=%d far=%s smg_rig=%s locked=%s home=%s anim=%s crane=%s cig=%s once=%s burning=%s seen=%s" % [n, far, rig, locked, home, anim, crane, lit, not twice, burning, _smoking_now()])
	get_tree().quit()


## Testing aid: the bodies Steve fetched stand, move and are their right size: the Hollow, Saltbone,
## Salt Rifle and Deacon on their new bodies, the Ash Weaver's spider and the Tusker's boar in its own coat.
func debug_newbodies() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await _debug_home()
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var out: Array = []
	var i := 0
	for k in ["hollow", "saltbone", "saltrifle", "deacon", "ash_weaver"]:
		var at: Vector3 = player.global_position + f * 14.0 + f.cross(Vector3.UP) * (i - 2) * 4.0
		at.y = terrain.height_at(at.x, at.z) + 1.0
		i += 1
		var e := spawn_at(k, at)
		e.set_physics_process(false)
		await get_tree().create_timer(0.6).timeout
		var root: Node3D = e._fb if e._fb else e._scan
		var tall := 0.0
		var low := 1e9
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			if not (mi as MeshInstance3D).is_visible_in_tree():
				continue
			var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			tall = maxf(tall, ab.end.y)
		var ap: AnimationPlayer = e._fb.anim if e._fb else e._scan_anim
		var moving: bool = ap != null and ap.is_playing() and ap.current_animation != ""
		var weapons := 0
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh and "Weapons" in (mi as MeshInstance3D).mesh.resource_name:
				weapons += 1
		out.append("%s=%s,%s%s" % [k, "moves" if moving else "still", "ok" if tall > e.global_position.y else "flat", ",own_arms" if weapons > 0 else ""])
		e.queue_free()
	var b := _w_beast(990001, "tusker", player.global_position + f * 10.0)
	await get_tree().create_timer(0.5).timeout
	var fur := false
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).get_surface_override_material(0) is ShaderMaterial:
			fur = true
	var g0: String = b._gait
	b._clips = b._clips   # (the gait follows the pace each frame)
	var gaits := {}
	for pace in [0.0, 1.5, 4.0, 8.0]:
		var gg: String = b._clips.idle if pace < 0.3 else (b._clips.walk if pace < 2.5 else (b._clips.trot if pace < 5.5 else b._clips.run))
		gaits[gg] = true
	var long := 0.0
	var ab2 := AABB()
	var first := true
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		var a2: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		ab2 = a2 if first else ab2.merge(a2)
		first = false
	print("NEWBODIES %s tusker fur=%s gait=%s gaits=%d" % [" ".join(out), fur, g0.get_slice("|", 1), gaits.size()])
	get_tree().quit()


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
	_warm_up()
	reveal_lit()
	for i in lit:
		flags["clean_%d" % i] = true
	flags["most_lit"] = maxi(int(flags.get("most_lit", 0)), lit.size())
	_stages_catch_up()
	if lit.size() >= TURN_AT and not turned():
		flags["turned"] = true   # a world from before the turn was kept, already five fires along
	_turn_marks()
	if lights:
		lights.refresh()
	for sb in shrine_bowls:
		_shrine_bowl_show(sb)
	if not Net.dedicated:
		WPlaylog.begin("world %s, %d in company, day %d" % [slot, maxi(1, avatars.size() + 1), day])
	if ui:
		ui.map_dirty = true
		ui.prepare_map()
	var vows := WRules.vows_text()
	if vows != "" and hud and not Net.dedicated:
		get_tree().create_timer(6.0, false).timeout.connect(func():
			if is_instance_valid(hud):
				hud.notify("This world was begun under oath: %s." % vows))


## Testing aid (with a screen): pictures of Hrafnsey's and Kalaja's own ground, and a check that
## those isles wear their own maps.
func debug_isleshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 13.0
	_apply_time(true)
	var own := 0
	for il in terrain.isles:
		if not str(il.key) in ["hrafn", "kala"]:
			continue
		var c: Vector2 = il.c
		var d := (c.normalized() * -1.0)
		var at := c + d * float(il.r) * 0.35
		player.place(Vector3(at.x, terrain.height_at(at.x, at.y) + 1.0, at.y), atan2(-d.x, -d.y) + PI)
		player.pitch = -0.25
		await get_tree().create_timer(4.0).timeout
		for ch in terrain.get_children():
			if ch is MeshInstance3D and ch.material_override != _m.ground and ch.global_position.distance_to(Vector3(c.x, 0, c.y)) < 1.0e9:
				own += 1
				break
		if DisplayServer.get_name() != "headless":
			get_viewport().get_texture().get_image().save_png("user://isle_%s.png" % il.key)
	print("ISLESHOT own=%d" % own)
	get_tree().quit()


## Making aid (with a screen): views of the waste with no hud and no gun, for the loading screen's pictures.
## Saves user://vista_<n>.png.
func debug_vistas() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var spots := [
		["town", "cinderwick", 7.2, Vector2(38, 26), 2.0],
		["town", "hesk", 17.6, Vector2(-44, 30), 2.5],
		["beacon", "0", 22.5, Vector2(26, 22), 1.5],
		["ruin", "stone_field", 9.5, Vector2(30, -18), 1.8],
		["ruin", "order_tower", 16.4, Vector2(-36, -40), 1.6],
		["town", "kiln", 19.2, Vector2(40, -30), 2.0],
		["ruin", "sealed_vault", 6.4, Vector2(-30, 28), 1.8],
		["town", "mourners", 13.0, Vector2(46, 18), 3.0],
		["far", "1", 15.5, Vector2(160, 120), 3.0],
		["far", "0", 22.5, Vector2(150, 110), 3.0],
	]
	hud.visible = false
	player.weapon.visible = false
	player.weapon.set_process(false)
	player.weapon.set_physics_process(false)
	player.weapon._holder.visible = false
	var from := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("from="):
			from = int(arg.substr(5))
	for i in range(from, spots.size()):
		var sp: Array = spots[i]
		var c: Vector2
		match sp[0]:
			"town":
				c = WPlaces.spos(sp[1])
			"ruin":
				c = WPlaces.rpos(sp[1])
			"far":
				c = WPlaces.bpos(int(sp[1]))
			"beacon":
				c = WPlaces.bpos(int(sp[1]))
				if not int(sp[1]) in lit:
					lit.append(int(sp[1]))
					_light_beacon(int(sp[1]), true)
		var at: Vector2 = c + sp[3]
		clock = sp[2]
		night = clock > 20.5 or clock < 5.0
		_apply_time(true)
		player.place(Vector3(at.x, terrain.height_at(at.x, at.y) + sp[4], at.y), 0.0)
		player.face(Vector3(c.x, terrain.height_at(c.x, c.y) + (40.0 if sp[0] == "far" else 3.0), c.y))
		await get_tree().create_timer(6.0).timeout
		if DisplayServer.get_name() != "headless":
			get_viewport().get_texture().get_image().save_png("user://vista_%d.png" % i)
	print("VISTAS done")
	get_tree().quit()


## Testing aid (with a screen): a picture of the flamethrower going.
func debug_flameshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 20.5
	_apply_time(true)
	var wpn: Arms = player.weapon
	arms.owned.append("flamer")
	arms.primary = "flamer"
	rearm()
	wpn.draw_gun(0)
	await get_tree().create_timer(1.5).timeout
	for k in 40:
		wpn._cool = 0.0
		wpn._try_fire()
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://flame.png")
	get_tree().quit()


## Testing aid: the warm-up makes no sound, leaves nothing lit, and puts the muzzle flash away again.
func debug_warmup() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var voices := _voices.size()
	await _warm_up(true)
	await get_tree().create_timer(2.5).timeout
	var left := 0
	for c in get_children():
		if c is CPUParticles3D:
			left += 1
	print("WARMUP quiet=%s hush_off=%s flash_off=%s" % [_voices.size() == voices, not hush, not player.weapon._flash_mesh.visible])
	get_tree().quit()


## Testing aid: the coast of a new world is not a square, and no place laid out on the land is drowned.
func debug_coast() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var wet: Array = []
	var spots: Array = []
	for k in WPlaces.SETTLEMENTS:
		spots.append([k, WPlaces.spos(k)])
	for b in WPlaces.beacon_points():
		spots.append(["beacon", b])
	for r in ruins:
		if not r.has("isle"):
			spots.append([r.name, Vector2(r.pos.x, r.pos.z)])
	for l in lairs:
		spots.append([l.name, Vector2(l.pos.x, l.pos.z)])
	for sp in spots:
		var p: Vector2 = sp[1]
		if maxf(absf(p.x), absf(p.y)) < 2048.0 and terrain.height_at(p.x, p.y) < WIsles.SEA_Y + 0.5:
			wet.append(sp[0])
	# Along each side, how far in the sea comes: a square has it the same everywhere
	var reach: Array = []
	for t in range(-1600, 1601, 100):
		var x := 2040.0
		while x > 1500.0 and terrain.height_at(x, float(t)) < WIsles.SEA_Y:
			x -= 10.0
		reach.append(x)
	var lo: float = reach.min()
	var hi: float = reach.max()
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for j in 256:
		for i in 256:
			var x := -2300.0 + i * 18.0
			var z := -2300.0 + j * 18.0
			var y := terrain.height_at(x, z)
			img.set_pixel(i, j, Color(0.1, 0.2, 0.4) if y < WIsles.SEA_Y else Color(0.6, 0.55, 0.4).lerp(Color.WHITE, clampf(y / 200.0, 0.0, 1.0)))
	img.save_png("user://coast.png")
	print("COAST gen=%d bays=%d wet=%s shore_varies=%s (%d..%d) png=%s" % [world_gen, terrain.bays.size(), wet, hi - lo > 60.0, int(lo), int(hi), ProjectSettings.globalize_path("user://coast.png")])
	get_tree().quit()


## Testing aid: the flamethrower roars while held and falls quiet when let go; its smoke rolls up.
func debug_flamer() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var wpn: Arms = player.weapon
	arms.owned.append("flamer")
	arms.primary = "flamer"
	rearm()
	await _debug_home()
	wpn.draw_gun(0)
	player.pitch = -0.35   # at the ground before it, so the fire takes wherever the check stands
	await get_tree().create_timer(0.6).timeout
	var smoke0 := find_children("*", "CPUParticles3D", false, false).size()
	for k in 12:
		wpn._cool = 0.0
		wpn._try_fire()
		await get_tree().process_frame
	var roaring: bool = wpn._flame_snd != null and wpn._flame_snd.playing and (wpn._flame_snd.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
	var parts := find_children("*", "CPUParticles3D", false, false).size() - smoke0
	await get_tree().create_timer(0.4).timeout
	print("FLAMER roaring=%s quiet_after=%s particles=%s" % [roaring, not wpn._flame_snd.playing, parts >= 8])   # twelve jets and their smoke, less any other fire that burns out meanwhile
	get_tree().quit()


## Testing aid: with the mouse, a click on a chest slot moves it to the pack, and a drag from the
## pack onto the chest moves it back.
func debug_slotdrag() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	_debug_room()
	ui._move_n = 0   # an earlier check may have left the chest moving one at a time
	var cid := "ptest"
	containers[cid] = [["salt", 40], null, null, null]
	for i in inv.slots.size():
		if inv.slots[i] != null and inv.slots[i].id == "salt":
			inv.slots[i] = null
	inv.changed.emit()
	ui.open_container(cid)
	await get_tree().process_frame
	await get_tree().process_frame
	var grids: Array = ui._body.find_children("*", "GridContainer", true, false)
	var chest_g: GridContainer = grids[0]
	var pack_g: GridContainer = grids[1]
	var vp := get_viewport()
	var press := func(at: Vector2, down: bool):
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		ev.position = at
		ev.global_position = at
		vp.push_input(ev, true)
	var move := func(at: Vector2, held: bool):
		var ev := InputEventMouseMotion.new()
		ev.position = at
		ev.global_position = at
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
		vp.push_input(ev, true)
	var c0: Vector2 = (chest_g.get_child(0) as Control).get_global_rect().get_center()
	move.call(c0, false)
	await get_tree().process_frame
	press.call(c0, true)
	await get_tree().process_frame
	press.call(c0, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var clicked: bool = inv.count("salt") == 40 and containers[cid][0] == null
	await get_tree().process_frame
	grids = ui._body.find_children("*", "GridContainer", true, false)
	chest_g = grids[0]
	pack_g = grids[1]
	var from := -1
	for i in inv.slots.size():
		if inv.slots[i] != null and inv.slots[i].id == "salt":
			from = i
	var p0: Vector2 = (pack_g.get_child(from) as Control).get_global_rect().get_center()
	var t0: Vector2 = (chest_g.get_child(2) as Control).get_global_rect().get_center()
	move.call(p0, false)
	await get_tree().process_frame
	press.call(p0, true)
	await get_tree().process_frame
	for k in 8:
		move.call(p0.lerp(t0, (k + 1) / 8.0), true)
		await get_tree().process_frame
	press.call(t0, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var back := 0
	for it in containers[cid]:
		if it != null and it[0] == "salt":
			back += int(it[1])
	print("SLOTDRAG clicked=%s dragged=%s" % [clicked, back == 40 and inv.count("salt") == 0])
	get_tree().quit()


## Testing aid: while building, the pack key opens the pieces at the group of the piece in hand.
func debug_buildmenu() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	builder.sel = Items.PIECE_ORDER.size() - 1
	if not builder.active:
		builder.toggle()
	var ev: InputEvent = null
	for k in InputMap.action_get_events("pack"):
		if k is InputEventKey:
			ev = k.duplicate()
			break
	ev.pressed = true
	ui._input(ev)
	await get_tree().process_frame
	print("BUILDMENU open=%s tab=%s group=%s" % [ui._panel_name == "pack", ui._tab, ui._bcat == str(Items.PIECES[builder.kind()].group)])
	get_tree().quit()


## Testing aid: a right click moves half a stack between chest and pack; "1" moves one; "All" the rest.
func debug_split() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var cid := "ptest"
	containers[cid] = [["salt", 40], null, null, null]
	ui._cont_id = cid
	var s0 := inv.count("salt")
	var bag := Inventory.new(4)
	bag.from_data(containers[cid])
	ui._take(bag, 0, true)
	await get_tree().process_frame
	var half: bool = inv.count("salt") - s0 == 20 and int(containers[cid][0][1]) == 20
	var slot := -1
	for i in inv.slots.size():
		if inv.slots[i] != null and inv.slots[i].id == "salt":
			slot = i
	ui._move_n = 1
	var before := inv.count("salt")
	ui._put(slot)
	await get_tree().process_frame
	var one: bool = inv.count("salt") == before - 1 and int(containers[cid][0][1]) == 21
	ui._move_n = 0
	bag.from_data(containers[cid])
	ui._take(bag, 0, false)
	await get_tree().process_frame
	print("SPLIT half=%s one=%s all=%s" % [half, one, containers[cid][0] == null])
	get_tree().quit()


## Testing aid: at a cooking station only what is cooked is listed; at a workbench, everything.
func debug_cooklist() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var at_pot := 0
	var at_bench := 0
	var odd := 0
	for r in Items.RECIPES:
		if WUI.station_shows(r, false, true):
			at_pot += 1
			if not r.get("fire", false):
				odd += 1
		if WUI.station_shows(r, true, true):
			at_bench += 1
	print("COOKLIST pot=%d bench=%d odd=%d all=%d" % [at_pot, at_bench, odd, Items.RECIPES.size()])
	get_tree().quit()


## Testing aid: an ember is taken from a lit beacon (only with company), its carrier cannot shoot,
## it kindles a dark beacon with a short vigil, and it goes out if the carrier falls.
func debug_ember() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	if not 0 in lit:
		lit.append(0)
	_ember_take(0)
	var alone_refused := ember_by == 0
	var fake := Node3D.new()
	fake.set("name", "fake")
	avatars[999] = fake
	add_child(fake)
	_ember_take(0)
	var carrying := ember_by == Net.me() and player.weapon.hands_full
	var nxt := next_dark_beacon(beacon_nodes[0].pos)
	_beacon_touched(nxt)
	var kindling: bool = vigils.has(nxt) and absf(float(vigils[nxt]) - EMBER_VIGIL) < 0.1 and ember_by == 0 and not player.weapon.hands_full
	vigils.erase(nxt)
	_ember_take(0)
	downed = true
	_ember_tick(1.0)
	var out := ember_by == 0
	downed = false
	avatars.erase(999)
	fake.queue_free()
	print("EMBER alone_refused=%s carrying=%s kindling=%s out=%s" % [alone_refused, carrying, kindling, out])
	get_tree().quit()


## Testing aid: a beacon lit while far away gives half and no boon; a vigil at it later keeps its credit.
func debug_credit() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	kindled = []
	skills.boon_offer.clear()
	lit.append(2)
	player.global_position = beacon_nodes[2].pos + Vector3(600, 0, 0)
	var s0 := inv.count(BEACON_GIFT[0][0])
	_beacon_payoff(2)
	var far_gift := inv.count(BEACON_GIFT[0][0]) - s0
	var far_boon := not skills.boon_offer.is_empty()
	var far_credit: bool = 2 in kindled
	_beacon_touched(2)
	var vigil: bool = 2 in kindled and not skills.boon_offer.is_empty()
	skills.boon_offer.clear()
	lit.append(3)
	player.global_position = beacon_nodes[3].pos + Vector3(20, 0, 0)
	s0 = inv.count(BEACON_GIFT[0][0])
	_beacon_payoff(3)
	var near_gift := inv.count(BEACON_GIFT[0][0]) - s0
	var near_ok: bool = 3 in kindled and not skills.boon_offer.is_empty()
	# Far from the bowl, but named by the host (fought at its front): the full gift and the boon
	skills.boon_offer.clear()
	lit.append(4)
	player.global_position = beacon_nodes[4].pos + Vector3(900, 0, 0)
	s0 = inv.count(BEACON_GIFT[0][0])
	_beacon_payoff(4, [Net.me()])
	var named: bool = 4 in kindled and not skills.boon_offer.is_empty() and inv.count(BEACON_GIFT[0][0]) - s0 >= near_gift
	var back := char_data()
	print("CREDIT far_half=%s far_boon=%s far_credit=%s vigil=%s near=%s saved=%s named=%s" % [far_gift * 2 <= near_gift + 1 and far_gift > 0, far_boon, far_credit, vigil, near_ok, back.kindled.has(2) and back.kindled.has(3), named])
	get_tree().quit()


## Testing aid: from a kindled beacon, the next land's lair is seen and marked.
func debug_sightline() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	# Earlier checks in the same world may have lit beacons and seen lairs: begin from none
	lit = []
	revealed.fill(0)
	var nxt := next_dark_beacon(beacon_nodes[0].pos)
	var l := lair_seen_from(WPlaces.bpos(nxt))
	if l.is_empty():
		print("SIGHTLINE found=false")
		get_tree().quit()
		return
	var before: bool = is_revealed(l.pos)
	_beacon_payoff(0)
	print("SIGHTLINE found=%s before=%s marked=%s" % [not l.is_empty(), before, is_revealed(l.pos)])
	get_tree().quit()


## Testing aid: the night director eases after a fall, builds back after nights held, and lit beacons press harder.
func debug_director() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	flags["ease"] = 0.0
	lit.clear()
	var p0 := night_press()
	night = true
	_w_fell(Net.me())
	_director_dawn()
	var p1 := night_press()
	_director_dawn()
	var p2 := night_press()
	lit.append(0)
	lit.append(1)
	var p3 := night_press()
	print("DIRECTOR base=%.2f after_fall=%.2f held=%.2f beacons=%.2f" % [p0, p1, p2, p3])
	get_tree().quit()


## Testing aid: a carried ash-radio brings a call for help near, and word of the night at dusk.
func debug_radio() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	for id in events.active.keys():
		events.active.erase(id)
	inv.add("ash_radio", 1)
	night = false
	clock = weather.dusk() - 3.0
	_radio_t = 0.0
	_radio_tick(0.1)
	var called := events.active.size()
	clock = weather.dusk() - 0.5
	_radio_tick(0.1)
	print("RADIO called=%d warned=%s" % [called, _radio_warned == day])
	get_tree().quit()


## Testing aid (host): a big world for a newcomer, sent in parts. Run with debug_snapclient joining.
func debug_snaphost() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	day = 42
	for i in 6000:
		flags["pad_%d" % i] = str(randi()) + "-" + str(randi()) + "-" + str(randi())
	print("SNAPHOST ready")
	await get_tree().create_timer(150.0).timeout
	get_tree().quit()


## Testing aid (host): sends the first joiner away once their world has arrived, then waits for them
## to try again under the same name.
func debug_kickhost() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	print("KICKHOST ready")
	var seen := {}
	var done := false
	for t in 150:
		await get_tree().create_timer(1.0).timeout
		for id in Net.players:
			if int(id) == 1:
				continue
			seen[id] = int(seen.get(id, 0)) + 1
			if Net.brisk_links.has(int(id)) and seen[id] >= 3:   # their world has arrived
				Net.kick(int(id))
				print("KICKHOST sent=true away=%s" % Net.sent_away.keys())
				done = true
				break
		if done:
			break
	await get_tree().create_timer(60.0).timeout
	print("KICKHOST after players=%d" % Net.players.size())
	get_tree().quit()


## Testing aid (joiner): waits to be sent away and says why.
func debug_kickclient() -> void:
	var t := 0
	while not ready_world and t < 120:
		await get_tree().create_timer(1.0).timeout
		t += 1
	print("KICKCLIENT in=%s" % ready_world)


## Testing aid (newcomer): the world arrived whole, and what happened meanwhile was played after.
func debug_snapclient() -> void:
	var t := 0
	while not ready_world and t < 120:
		await get_tree().create_timer(1.0).timeout
		t += 1
	var pads := 0
	for k in flags:
		if str(k).begins_with("pad_"):
			pads += 1
	print("SNAPCLIENT ready=%s day=%d pads=%d waiting=%s brisk=%s" % [ready_world, day, pads, snap_wait, Net.brisk_links.has(1)])
	get_tree().quit()


## Testing aid: a doorway wall is solid where it is drawn, but its door can be walked through.
func debug_gatewalk() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var at := Vector3(0, 600, 0)
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = at
	WIsleLife.put(holder, "castle", "wall-doorway", Vector3.ZERO, 0.0, 4.0, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var through := false
	var solid := false
	for dir in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		for h in [0.6, 1.2, 2.0]:
			var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, h, 0) - dir * 30.0, at + Vector3(0, h, 0) + dir * 30.0)
			q.collision_mask = 1
			if space.intersect_ray(q).is_empty():
				through = true
			else:
				solid = true
	print("GATEWALK through=%s solid=%s" % [through, solid])
	get_tree().quit()


## Testing aid: on every isle the ground can be stood on where it is drawn: no holes, no cells
## where the solid ground lies far from the drawn one.
## Testing aid: each isle has its traces, on dry land with something to look at; finding them all pays.
func debug_traces() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	_debug_room()
	traces_seen.clear()
	var dry := 0
	for t in life.traces:
		if terrain.height_at(t[1].x, t[1].z) > WIsles.SEA_Y + 0.3:
			dry += 1
	var coins := inv.count("coin")
	for t in life.traces:
		if str(t[0]).begins_with("hrafn_"):
			_trace_seen(t[0], "Hrafnsey", t[2])
	_trace_seen("hrafn_0", "Hrafnsey", "again")
	var paid := inv.count("coin") - coins
	var kept: int = char_data().get("traces", {}).size()
	print("TRACES count=%d dry=%d paid=%d kept=%d" % [life.traces.size(), dry, paid, kept])
	get_tree().quit()


## Testing aid: rain stops falling under a roof (it came through the boards), and starts again outside.
func debug_roofrain() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var at := player.global_position
	var roof := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(8, 0.3, 8)
	cs.shape = bs
	roof.add_child(cs)
	add_child(roof)
	roof.global_position = at + Vector3(0, 4.0, 0)
	weather.kind = "rain"
	weather.k = 1.0
	set_physics_process(true)
	await get_tree().create_timer(3.0).timeout
	var dry_under: bool = not weather._rain.emitting and weather.sheltered
	roof.queue_free()
	await get_tree().create_timer(3.0).timeout
	var wet_out: bool = weather._rain.emitting and not weather.sheltered
	print("ROOFRAIN under=%s out=%s" % [dry_under, wet_out])
	get_tree().quit()


## Testing aid: the combat rework. Poise breaks under heavy blows but not under a trickle; a gunman's rounds
## fly where they can be seen; a champion is gilded and tougher; packs are mixed; heavy foes sweep.
func debug_rework() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	# Poise
	var w := spawn_at("warden", player.global_position + f * 12.0 + Vector3(0, 1.0, 0))
	w.set_meta("raid", true)
	w.set_physics_process(false)
	var pm: float = w.poise_max()
	LesserSpeeb.harm_kind = "bullet"
	w.hurt(pm * 0.3, f)
	var held: bool = w._broken <= 0.0
	LesserSpeeb.harm_kind = "blade"
	LesserSpeeb.harm_heavy = true
	w.hurt(pm * 0.3, f)
	LesserSpeeb.harm_heavy = false
	var broke: bool = w._broken > 0.0
	var h0: float = w.hp
	LesserSpeeb.harm_kind = ""
	w.hurt(10.0, f)
	var open: bool = h0 - w.hp > 12.0
	LesserSpeeb.harm_kind = ""
	w.die(false)
	# Champion
	var c := spawn_at("rusher", player.global_position + f * 14.0 + Vector3(0, 1.0, 0))
	c.set_meta("raid", true)
	c.set_physics_process(false)
	var hp1: float = c.max_hp
	c.become_champion("warded")
	var gilded: bool = c.max_hp > hp1 * 1.9 and str(c._name_l.text).begins_with("Warded")
	var ch0: float = c.hp
	LesserSpeeb.harm_kind = "bullet"
	c.hurt(10.0, f)
	LesserSpeeb.harm_kind = ""
	var warded: bool = absf((ch0 - c.hp) - 5.0) < 0.5
	c.die(false)
	# Packs
	var pk := pack_at(player.global_position + f * 400.0)
	# Rounds
	var g := spawn_at("unlit_gun", player.global_position + f * 16.0 + Vector3(0, 1.0, 0))
	g.set_meta("raid", true)
	var rounds := 0
	for i in 8 * 60:
		await get_tree().physics_frame
		for n in get_children():
			if n is LesserSpeeb.Bolt and n.look == "round":
				rounds += 1
		if rounds > 0:
			break
	g.die(false)
	# A heavy one's sweep reaches all round it
	var k := spawn_at("knight", player.global_position + f * 2.0 + Vector3(0, 1.0, 0))
	k.set_meta("raid", true)
	await get_tree().create_timer(0.5).timeout
	var ph := player.health
	k._attack_cd = 9.0
	k._begin_move("sweep", 1.3, f, 1.3 + k.spec.radius)
	await get_tree().create_timer(2.5).timeout
	var swept := player.health < ph
	k.die(false)
	print("REWORK poise_held=%s broke=%s open=%s champion=%s warded=%s pack=%d rounds=%s swept=%s" % [held, broke, open, gilded, warded, pk.size(), rounds > 0, swept])
	get_tree().quit()


## Testing aid: the empty-field test sets the ground, the arms and three forms, and sends three more when they fall.
func debug_field() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	dev.god = true
	dev.field_test()
	await get_tree().create_timer(1.0).timeout
	var first: int = dev._field_foes.size()
	var armed: bool = player.weapon.gun() == "shotgun" and arms.melee == "hatchet"
	var open: bool = not safe_at(player.global_position) and land_at(player.global_position) == "ash"
	for e in dev._field_foes.duplicate():
		e.die(false)
	await get_tree().create_timer(0.5).timeout
	print("FIELD first=%d armed=%s open=%s kills=%d again=%d" % [first, armed, open, dev.field_kills, dev._field_foes.size()])
	get_tree().quit()


## Testing aid: a blow at a node throws chips (more on the last), and they clear away after.
func debug_chips() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await _debug_home()
	_debug_room(8)
	var best := -1
	for nd in nodes:
		if nd.kind == "rock" and int(nd.charges) == int(NODE_KINDS.rock.charges) and (best < 0 or nd.pos.distance_to(player.global_position) < nodes[best].pos.distance_to(player.global_position)):
			best = nd.id
	var nd: Dictionary = nodes[best]
	player.place(nd.pos + Vector3(2.0, 0.5, 0), 0.0)
	await get_tree().create_timer(0.3).timeout
	_gather(best)
	await get_tree().create_timer(0.2).timeout
	var first := gather_chips
	nd.charges = 1
	_gather(best)
	await get_tree().create_timer(0.2).timeout
	var last := gather_chips - first
	var heard := ",".join(gather_heard)
	await get_tree().create_timer(2.5).timeout
	var left := 0
	for c in get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh and _chip_mats.values().has((c as MeshInstance3D).material_override):
			left += 1
	print("CHIPS first=%d last=%d left=%d heard=%s floats=%d fell=%d gone=%s" % [first, last, left, heard, gather_floats, gather_falls, not nd.node.visible])
	get_tree().quit()


## Testing aid: the first kill of a form opens its bestiary page (once), and the page is kept.
func debug_bestiary() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	slain_kinds.clear()
	var e := spawn_at("draugr", player.global_position + Vector3(20, 1, 20))
	on_enemy_slain(e)
	await get_tree().create_timer(0.3).timeout
	var page := str(hud._deed_title.text)
	var told := str(hud._deed_text.text)
	for d in hud._deed_queue:   # other deeds (first blood) may be shown before it
		page += str(d[0])
		told += str(d[1])
	var f := spawn_at("draugr", player.global_position + Vector3(-20, 1, 20))
	_bestiary(f)
	var once := slain_kinds.size() == 1
	var kept: bool = char_data().get("slain", {}).has("draugr")
	print("BESTIARY page=%s fire=%s once=%s kept=%s" % [page.contains("Draugr"), told.contains("Weak to fire"), once, kept])
	get_tree().quit()


## Testing aid: leaving right after hosting does not wait on the router's answer.
func debug_hostleave() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	Net.host(24611, "leave test", false)
	var t0 := Time.get_ticks_msec()
	Net.leave("")
	var took := Time.get_ticks_msec() - t0
	# Leaving takes the game back to the title, so this check ends here
	print("HOSTLEAVE took=%d quick=%s offline=%s" % [took, took < 500, not Net.online])
	get_tree().quit()


## Testing aid: the old-tale forms roam their own isles, and fight as their kin do (the Shtriga drinks).
## Test (0.13 feel): a struck form rocks away and comes back; each sounds of what it is made of;
## the far forms warn before their ways.
func debug_feel() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await _debug_home()
	player.max_health = 999999.0
	player.health = 999999.0
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var rocked := true
	var back := true
	Arms.heard_matter.clear()
	for k in ["hollow", "saltbone", "glass_crawler"]:
		var at: Vector3 = player.global_position + f * 10.0
		at.y = terrain.height_at(at.x, at.z) + 1.0
		var e := spawn_at(k, at)
		e.set_physics_process(true)
		await get_tree().physics_frame
		e.hp = 99999.0
		e.max_hp = 99999.0
		e.hurt(30.0, f)
		player.weapon._impact_sounds({e: 30.0})
		rocked = rocked and e._flinch.length() > 0.02
		for i in 40:
			await get_tree().physics_frame
		back = back and e._flinch.length() < 0.01
		e.queue_free()
	var heard := ",".join(PackedStringArray(Arms.heard_matter.keys()))
	tells_seen.clear()
	for k in ["flicker", "tunnel_unlit", "geyser_wight", "raven_mask", "dust_choir", "grass_stalker"]:
		var at: Vector3 = player.global_position + f * 12.0 + f.cross(Vector3.UP) * randf_range(-6.0, 6.0)
		at.y = terrain.height_at(at.x, at.z) + 1.0
		var e := spawn_at(k, at)
		if e:
			e.mind = "hunt"
			e.set_meta("trait_t", 0.5)
	for i in 14 * 60:
		await get_tree().physics_frame
		player.health = 999999.0
	var told := tells_seen.keys()
	told.sort()
	print("FEEL rocked=%s back=%s heard=%s told=%s" % [rocked, back, heard, ",".join(PackedStringArray(told))])
	get_tree().quit()


## Test: the scanned forms stand on the ground at their height, walk by their own animation and can be struck high.
func debug_scanfoes() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await _debug_home()
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var ok := 0
	var out := []
	var kin: Array = LesserSpeeb.SCANS.keys().filter(func(x): return LesserSpeeb.VARIANTS.has(x))
	for k in kin:
		var at: Vector3 = player.global_position + f * 14.0 + f.cross(Vector3.UP) * (ok - 1) * 4.0
		at.y = terrain.height_at(at.x, at.z) + 1.0
		var e := spawn_at(k, at)
		if e == null:
			out.append(k + "=none")
			continue
		e.set_physics_process(false)
		await get_tree().create_timer(0.6).timeout
		var body_ok: bool = e._scan != null and e._scan.get_child_count() > 0
		var moving: bool = e._scan_anim != null and e._scan_anim.is_playing()
		var tall := 0.0
		for mi in e._scan.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			tall = maxf(tall, ab.end.y - e.global_position.y)
		var head_up: bool = e.weak_point()[0].y > e.global_position.y
		if body_ok and moving and head_up and e.spec.name == LesserSpeeb.VARIANTS[k].name:
			ok += 1
		out.append("%s=%.1f" % [k, tall])
		e.queue_free()
	print("SCANFOES ok=%d/%d %s" % [ok, kin.size(), " ".join(out)])
	get_tree().quit()


func debug_folk() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 23.0
	var seen := {}
	for il in terrain.isles:
		if WIsles.far(il):
			continue   # the Frostmark has its own draugr: only the near isles' tales here
		var c: Vector2 = il.c
		var roster: Array = forms_at(Vector3(c.x, terrain.height_at(c.x, c.y), c.y))
		for k in ["draugr", "nykur", "shtriga", "kulshedra"]:
			if k in roster:
				seen[k] = il.key
	var named := 0
	var pp := player.global_position
	for k in ["draugr", "nykur", "shtriga", "kulshedra"]:
		var e := spawn_at(k, pp + Vector3(30, 1, 30))
		if e and e.spec.name == LesserSpeeb.VARIANTS[k].name and e.is_alive():
			named += 1
		if e:
			e.queue_free()
	var sh := spawn_at("shtriga", pp + Vector3(-30, 1, -30))
	var drinks := false
	if sh:
		sh.hp = sh.max_hp * 0.5
		var before: float = sh.hp
		sh._afflict(player)
		drinks = sh.hp >= before + 25.0
		sh.queue_free()
	print("FOLK hrafn=%s kala=%s named=%d drinks=%s" % [seen.get("draugr", "") == "hrafn" and seen.get("nykur", "") == "hrafn",
		seen.get("shtriga", "") == "kala" and seen.get("kulshedra", "") == "kala", named, drinks])
	get_tree().quit()


func debug_isleground() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var holes := 0
	var off := 0
	var tried := 0
	var worst := ""
	for il in terrain.isles:
		var c: Vector2 = il.c
		var r: float = il.r
		var step := r / 14.0
		for j in range(-14, 15):
			for i in range(-14, 15):
				var x := c.x + i * step
				var z := c.y + j * step
				var y := terrain.height_at(x, z)
				if y < 1.0 or is_nan(y):
					continue
				tried += 1
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, y + 60.0, z), Vector3(x, y - 60.0, z))
				q.collision_mask = 1
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					holes += 1
					worst = "%s hole at %d,%d" % [il.name, int(x), int(z)]
				elif absf(hit.position.y - y) > 1.5 and hit.collider.has_meta("ground"):
					off += 1
					worst = "%s off by %.1f" % [il.name, hit.position.y - y]
	print("ISLEGROUND tried=%d holes=%d off=%d %s" % [tried, holes, off, worst])
	get_tree().quit()


## Testing aid: the marsh at night in an ash storm, the thickest haze there is, stays under the cap.
func debug_fogcap() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var worst := 0.0
	for c in [12.0, 23.0]:
		clock = c
		air.thick = 2.3
		weather.kind = "ashstorm"
		weather.k = 1.0
		_apply_time(true)
		worst = maxf(worst, env.fog_density)
	print("FOGCAP worst=%.4f capped=%s" % [worst, worst <= FOG_CAP + 0.0001])
	get_tree().quit()


## Testing aid: nothing on screen that cannot be seen catches the mouse.
func debug_ghosts() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	# Everything that shows for a moment and fades: once faded it must not still catch clicks
	hud.notify("A test.")
	hud.title_card("Test", "A test")
	hud.say("A test.", 1.0)
	ui.xp_gained(5)
	ui.saved_mark(true)
	await get_tree().create_timer(14.0).timeout
	var found: Array = []
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Control and n.is_visible_in_tree() and n.mouse_filter == Control.MOUSE_FILTER_STOP:
			var a := 1.0
			var c: Node = n
			while c is CanvasItem:
				a *= c.modulate.a * c.self_modulate.a if c == n else c.modulate.a
				c = c.get_parent()
			if n is ColorRect:
				a *= n.color.a
			if a < 0.05 and n.size.x * n.size.y > 400.0:
				found.append("%s %s a=%.2f size=%s" % [n.get_path(), n.get_class(), a, n.size])
	print("GHOSTS n=%d" % found.size())
	for f in found:
		print("  " + f)
	get_tree().quit()


## Testing aid: an autosave is written in the background, and the save it leaves reads back whole.
func debug_bgsave() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	day = 77
	var t0 := Time.get_ticks_usec()
	save_all(true)
	var bg_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	_save_wait()
	var wr_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var d = Game.read_var_safe(world_path(slot))
	var back: bool = d is Dictionary and int(d.get("day", -1)) == 77
	day = 78
	save_all(true)
	save_all()   # a save at once waits for the one in the background
	d = Game.read_var_safe(world_path(slot))
	print("BGSAVE back=%s after=%s call_ms=%.1f write_ms=%.1f" % [back, d is Dictionary and int(d.get("day", -1)) == 78, bg_ms, wr_ms])
	get_tree().quit()


## Testing aid: a swarm of spat bolts shares one look, and only a few carry a light.
func debug_bolts() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var bs: Array = []
	for i in 20:
		var b := LesserSpeeb.Bolt.new()
		b.level = self
		b.life = 30.0
		add_child(b)
		b.global_position = player.global_position + Vector3(i, 40, 0)
		bs.append(b)
	var lights := 0
	for b in bs:
		for c in b.get_children():
			if c is OmniLight3D:
				lights += 1
	var one_mat: bool = bs[0].get_child(1).material_override == bs[19].get_child(1).material_override
	for b in bs:
		b.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("BOLTS lights=%d shared=%s freed=%s" % [lights, one_mat, LesserSpeeb.Bolt.lit == 0])
	get_tree().quit()


## Testing aid: no more than MAX_VOICES sounds play in the world, and a loud one near takes a faint one's place.
func debug_voices() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var cam := get_viewport().get_camera_3d()
	var at: Vector3 = cam.global_position if cam else player.global_position
	for i in 60:
		sfx("horror_deep", -20, at + Vector3(150, 0, 0))
	var faint: int = _voices.filter(func(v): return is_instance_valid(v) and not v.is_queued_for_deletion()).size()
	sfx("horror_deep", 0, at + Vector3(2, 0, 0))
	var near_in: bool = _voices.any(func(v): return is_instance_valid(v) and v.volume_db == 0.0)
	print("VOICES capped=%s n=%d near_in=%s" % [faint <= MAX_VOICES, faint, near_in])
	get_tree().quit()


## Testing aid: the playtest log notes goals, the first of each kind, and the gap between them.
func debug_playlog() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	award("ruin")
	await get_tree().create_timer(1.1).timeout
	award("beacon")
	award("ruin")
	var path := WPlaylog.path()
	WPlaylog.end()
	var text := FileAccess.get_file_as_string(path)
	print("PLAYLOG begun=%s first_beacon=%s two_ruins=%s gap=%s ended=%s" % [text.contains("Sitting begun"), text.contains("beacon lit (first beacon)"),
		text.count("ruin found") == 2, text.contains("0:00:01 since the last goal"), text.contains("first beacon at")])
	get_tree().quit()


## Testing aid: night pace sets how many nights are named and how big the waves are.
func debug_pace() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var out := []
	for v in 3:
		var r := rules.duplicate()
		r["pace"] = v
		# An earlier check may have sworn the Hunted vow (it names every night), and set_rules keeps vows
		rules["vow_hunted"] = 0
		set_rules(r)
		Game.wrules["vow_hunted"] = 0
		var named := 0
		for n in range(3, 60):
			if night_theme_for(n) != "":
				named += 1
		out.append("%d/%.2f" % [named, float(WRules.pace()[0])])
	var ns: Array = out.map(func(x): return int(str(x).get_slice("/", 0)))
	print("PACE " + " ".join(out) + " rising=%s" % [ns[0] < ns[1] and ns[1] < ns[2] and ns[0] >= 8 and ns[2] <= 50])
	get_tree().quit()


## Testing aid: vows are kept once sworn, and each one bites and pays.
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


## The great ones of the far sea and the Far Shores, each on its own isle (their ids after the rest).
func _plan_far_lairs() -> void:
	for b in LesserSpeeb.BOSSES:
		var land: String = LesserSpeeb.BOSSES[b].land
		if WTerrain.BIOMES.has(land):
			continue
		for il in terrain.isles:
			if il.key != land:
				continue
			var q := WIsles.lair_spot(il)
			lairs.append({"id": land, "land": land, "boss": b, "name": "Lair of " + LesserSpeeb.BOSSES[b].name.trim_prefix("The "), "pos": Vector3(q.x, terrain.height_at(q.x, q.y), q.y)})


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


## Coming near a sleeping great one for the first time, you are told how to wake it (on every pilgrim's own machine).
func _lair_hint() -> void:
	for l in lairs:
		if lair_ready(l) and not _lair_told.has(l.id) and player.global_position.distance_to(l.pos) < 40.0 and (not Net.authority() or _lair_boss.get(l.id) == null):
			_lair_told[l.id] = true
			hud.notify("%s sleeps here. Hold %s at the stone in the middle to call it out, when you are ready." % [LesserSpeeb.BOSSES[l.boss].name, Game.key_text("interact")])


## The host wakes a great one once a pilgrim has called it out and is still near.
func _lair_tick() -> void:
	for l in lairs:
		var e = _lair_boss.get(l.id)
		if e != null and (not is_instance_valid(e) or not e.is_alive()):
			_lair_boss.erase(l.id)
			e = null
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
		# ...and its own named fittings each time, and the first time it falls in a world, a book
		var book := great_book(land)
		if book != "":
			shared("_w_flag", ["felled_" + land])
		var first := [book]
		drop_for_each(at, func():
			var fit := "fittings_storied" if _gen.randf() < 0.35 else "fittings_rare"
			var heart: Array = [["heart_" + land, 1]] if Items.DB.has("heart_" + land) else []   # the key to the eighth fire
			var bk: Array = [[first[0], 1]] if first[0] != "" else []
			first[0] = ""
			return Items.roll("corpse", 6, _gen) + [["t_" + land, 1], [fit, 1], ["fit_" + land, 1]] + heart + bk)
		autosave_soon(2.0)
	if not Net.dedicated and player.global_position.distance_to(at) < 120.0:
		award("kill_boss")
		skills.points += 1
		Game.gain_pxp(300)
		ui.skills_changed()
		hud.notify("%s is slain.\nA point of skill is yours to spend [%s]." % [LesserSpeeb.BOSSES[b].name, Game.key_text("skills")])
		player.health = player.max_health
		hud.set_health(1.0, true)
		autosave_soon(4.0)


## The book a great one leaves the first time it falls in a world: a far one's own, or a lost book of the
## waste not yet found. Never again after (a lair that returns every three days is not a library).
func great_book(land: String) -> String:
	if flags.has("felled_" + land):
		return ""
	var own := str(Items.GREAT_BOOKS.get(land, ""))
	if own != "":
		return own
	for bk in Items.LAND_BOOKS:
		if not flags.has("found_" + bk) and not flags.has(bk):
			return bk
	return ""


## Testing aid: shares of loot that belong to another pilgrim are kept but not seen, and stay theirs through a save.
## Testing aid: old satchels far from anyone blow away at dawn; fresh ones, your belongings and ones
## near you stay, and the day they were left is saved.
func debug_satchelage() -> void:
	await get_tree().create_timer(1.0).timeout
	var far := player.global_position + Vector3(400, 0, 0)
	day = 10
	var before := satchels.keys()
	_rq_satchel(0, far, [["bone", 1]], false)
	_rq_satchel(0, far + Vector3(0, 0, 4), [["bone", 1]], true)
	_rq_satchel(0, player.global_position + Vector3(3, 0, 0), [["bone", 1]], false)
	day = 12
	_rq_satchel(0, far + Vector3(0, 0, 8), [["bone", 1]], false)
	day = 10
	_rq_satchel(0, far + Vector3(0, 0, 12), [["bone", 1]], false, "", true)
	day = 12
	await get_tree().process_frame
	var made: Array = satchels.keys().filter(func(k): return not k in before)
	var saved_day: bool = made.size() == 5 and int(world_data().satchels[made[0]][3]) == 10
	day = 14
	_age_satchels()
	await get_tree().process_frame
	var left: Array = made.filter(func(k): return satchels.has(k))
	print("SATCHELAGE made=%d saved_day=%s old_gone=%s grave=%s near=%s fresh=%s" % [made.size(), saved_day,
		not satchels.has(made[0]), satchels.has(made[1]), satchels.has(made[2]), satchels.has(made[3]) and satchels.has(made[4])])
	get_tree().quit()


## Testing aid: a damaged save is kept aside, not written over; a finished .tmp is read before the .bak.
func debug_damaged() -> void:
	await get_tree().create_timer(1.0).timeout
	var p := world_path("zz_test")
	for e in ["", ".tmp", ".bak", ".damaged", ".bak.damaged", ".tmp.damaged"]:
		DirAccess.remove_absolute(p + e)
	Game.write_safe(p, var_to_str({"n": 1}))
	Game.write_safe(p, var_to_str({"n": 2}))   # now n=2 is the save and n=1 the .bak
	DirAccess.rename_absolute(p, p + ".tmp")   # as if stopped between the renames
	var from_tmp = Game.read_var_safe(p)
	var tmp_first: bool = from_tmp is Dictionary and int(from_tmp.n) == 2
	for e in ["", ".tmp", ".bak"]:
		var f := FileAccess.open(p + e, FileAccess.WRITE)
		f.store_string("garbage {{{")
		f.close()
	var unread: bool = Game.read_var_safe(p) == null
	var moved := Game.set_aside_damaged(p)
	var kept: bool = FileAccess.file_exists(p + ".damaged") and FileAccess.file_exists(p + ".bak.damaged") and not FileAccess.file_exists(p)
	for e in ["", ".tmp", ".bak", ".damaged", ".bak.damaged", ".tmp.damaged"]:
		DirAccess.remove_absolute(p + e)
	print("DAMAGED tmp_first=%s unread=%s moved=%s kept=%s" % [tmp_first, unread, moved, kept])
	get_tree().quit()


## Testing aid: at the best prices a pilgrim can ever get (full standing, three ranks of Haggler, a feast
## day), nothing bought can be sold back, or made into something sold, for more salt than it cost.
func debug_arbitrage() -> void:
	await get_tree().create_timer(1.0).timeout
	skills.ranks["haggler"] = 3
	var at := "cinderwick"
	rep[at] = 99
	while feast_town(day) != at and day < 400:
		day += 1
	var sold := {}
	for role in Items.STOCK:
		for id in stock_at(role, at) + SAFE_STOCK.get(role, []):
			sold[id] = true
	var bad: Array = []
	for id in sold:
		if not Items.DB.has(id) and not WArms.WEAR.has(id):
			continue
		var each_buy: float = float(ui.buy_price(id, at)) / (ui._lot(id) if ui.AMMO_PRICE.has(id) else 1)
		var each_sell: float = float(ui.sell_price(id)) / (ui._lot(id) if ui.AMMO_PRICE.has(id) else 1)
		if each_sell >= each_buy:
			bad.append("%s %.2f>=%.2f" % [id, each_sell, each_buy])
	for r in Items.RECIPES:
		var cost := 0.0
		var all_bought := true
		for k in r.cost:
			if k == "salt":
				cost += float(r.cost[k])
			elif sold.has(k):
				cost += float(ui.buy_price(k, at)) / (ui._lot(k) if ui.AMMO_PRICE.has(k) else 1) * float(r.cost[k])
			else:
				all_bought = false
		if not all_bought:
			continue
		var out: float = float(ui.sell_price(r.id)) / (ui._lot(r.id) if ui.AMMO_PRICE.has(r.id) else 1) * float(r.n)
		if out > cost:
			bad.append("make %s %.1f>%.1f" % [r.id, out, cost])
	print("ARBITRAGE none=%s %s" % [bad.is_empty(), bad])
	get_tree().quit()


## Testing aid: a month in the waste in a hurry. Each day foes fall and leave their satchels, the pilgrim
## goes somewhere else, and dawn comes; what the world holds is counted as it goes, so anything that only
## ever grows shows.
func debug_longrun() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(2.0).timeout
	var kinds: Array = ["rusher", "spitter", "idol"]
	var places: Array = WPlaces.SETTLEMENTS.keys()
	var first := {}
	for d in 30:
		var k: String = places[d % places.size()]
		player.place(gpos(WPlaces.spos(k) + Vector2(120, 40)) + Vector3(0, 0.4, 0), 0.0)
		await get_tree().create_timer(0.6).timeout
		for i in 8:
			var at := player.global_position + Vector3(randf_range(-15, 15), 0, randf_range(10, 20))
			at.y = terrain.height_at(at.x, at.z) + 0.5
			var e = spawn_at(kinds[i % kinds.size()], at)
			if e:
				e.hurt(9999.0, Vector3.FORWARD)
			await get_tree().process_frame
		await get_tree().create_timer(0.8).timeout
		day += 1
		_w_dawn(day)
		await get_tree().create_timer(0.4).timeout
		var now := {"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "objs": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), "satchels": satchels.size(), "foes": enemies.size(), "containers": containers.size()}
		if d == 4:
			first = now
		if d % 5 == 4:
			print("LONG day=%d %s" % [day, now])
	var last := {"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "satchels": satchels.size(), "containers": containers.size()}
	print("LONGRUN nodes_grew=%d satchels=%d containers=%d" % [last.nodes - int(first.nodes), last.satchels, last.containers])
	get_tree().quit()


func debug_ownloot() -> void:
	await get_tree().create_timer(1.0).timeout
	var at := player.global_position + Vector3(3, 0, 0)
	var before := satchels.size()
	var n := drop_for_each(at, func(): return [["bone", 2]])
	_rq_satchel(0, at + Vector3(0, 0, 3), [["bone", 1]], false, "Someone Else")
	_rq_satchel(0, at + Vector3(0, 0, -3), [["bone", 1]], false, Net.my_name())
	await get_tree().process_frame
	var theirs := ""
	var mine := ""
	for sid in satchels:
		if str(satchels[sid].get("owner", "")) == "Someone Else":
			theirs = sid
		elif str(satchels[sid].get("owner", "")) == Net.my_name():
			mine = sid
	var hidden: bool = theirs != "" and not satchels[theirs].node.visible
	var seen: bool = mine != "" and satchels[mine].node.visible
	var kept: bool = theirs != "" and str(world_data().satchels[theirs][2]) == "Someone Else"
	print("OWNLOOT alone=%d made=%d hidden=%s seen=%s kept=%s" % [n, satchels.size() - before, hidden, seen, kept])
	get_tree().quit()


## Testing aid: a new pilgrim in a world with beacons lit starts with better kit; in a fresh world, the plain start.
func debug_dropin() -> void:
	await get_tree().create_timer(1.0).timeout
	var was := lit.duplicate()
	lit = []
	arms.owned.erase("machine_gun")
	arms.primary2 = ""
	arms.blades.erase("machete")
	var none := drop_in_kit()
	lit = ["a", "b", "c", "d"]
	var shells0 := inv.count("shells")
	var four := drop_in_kit()
	print("DROPIN plain=%d four=%d tier=%d revolver=%s mg=%s machete=%s shells=%d" % [none, four, int(arms.tier.get("shotgun", 0)),
		"revolver" in arms.owned, arms.primary2 == "machine_gun", "machete" in arms.blades, inv.count("shells") - shells0])
	lit = was
	get_tree().quit()


## Testing aid: a friend's trade, once told, shows in What now as someone to ask; not once they leave.
func debug_tradeask() -> void:
	await get_tree().create_timer(1.0).timeout
	trades.trade = "cook"
	inv.take("tempered", inv.count("tempered"))
	inv.take("clockwork", inv.count("clockwork"))
	skills.boon_offer = []
	skills.points = 0
	var plain := trade_ask().is_empty()
	Net.players[77] = {"name": "Dana", "slot": 1}
	Net.players[1] = {"name": Net.my_name(), "slot": 0}
	_w_trade_of(77, "Dana", "smith")
	var g: Dictionary = what_now()[2]
	var asked := str(g.title) == "Ask Dana for tempered steel"
	inv.add("tempered", 1)
	var had := trade_ask().is_empty()
	inv.take("tempered", 1)
	Net.players.erase(77)
	var gone := trade_ask().is_empty()
	print("TRADEASK plain=%s asked=%s had=%s gone=%s title=%s" % [plain, asked, had, gone, g.title])
	get_tree().quit()


## Testing aid: a second front falls on the camp nearest a vigil, not on one beside it, and only for five or more.
func debug_front() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var b: Vector3 = beacon_nodes[0].pos
	var nc := ground_below(b + Vector3(30, 20, 0))
	var fc := ground_below(b + Vector3(130, 40, 0))
	# Camps earlier checks left about the beacon would be nearer: take them away
	for pid in pieces.keys():
		if pieces[pid].kind == "campfire" and pieces[pid].pos.distance_to(b) < 400.0:
			_w_piece_gone(pid)
	_w_piece(piece_next, "campfire", nc, 0.0, 100.0)
	_w_piece(piece_next, "campfire", fc, 0.0, 100.0)
	var few = second_front(b)
	var at = second_front(b, true, 0)
	var right: bool = at != null and (at as Vector3).distance_to(fc) < 20.0
	player.max_health = 100000.0
	player.health = 100000.0
	player.place(fc + Vector3(3, 1, 0), 0.0)
	await get_tree().create_timer(42.0).timeout
	var raiders := enemies.filter(func(e): return is_instance_valid(e) and e.is_alive() and e.has_meta("raid") and e.global_position.distance_to(fc) < 80.0).size()
	_front_tick(0, 1.0)
	var fought: bool = fronts.has(0) and fronts[0].fought.has(Net.me())
	var open_while: bool = not _front_held(0)
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.has_meta("raid"):
			e.die(false)
	await get_tree().process_frame
	var held := _front_held(0)
	print("FRONT few=%s right=%s raiders=%s fought=%s open=%s held=%s" % [few == null, right, raiders > 0, fought, open_while, held])
	get_tree().quit()


## Testing aid: a boat's seats are stations; a sail-hand trims, oars add, the gunner shoots harder,
## a rider can move to a free station, and the lookout's bearings read right.
func debug_boatcrew() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var me := Net.me()
	_w_boat(97, "sloop", player.global_position + Vector3(8, 0, 0), 0.0, 420.0)
	var b: WBoat = boats[97]
	b.set_riders({me: 0, 77: 1, 78: 2, 79: 3})
	var names := []
	for pid in [me, 77, 78, 79]:
		names.append(b.station_of(pid))
	var trim := b.manned("sail") == 1
	_w_boat(98, "longboat", player.global_position + Vector3(-12, 0, 0), 0.0, 640.0)
	var lb: WBoat = boats[98]
	lb.set_riders({me: 0, 71: 4, 72: 5, 73: 6, 74: 7})
	var oars := lb.manned("oar") == 4
	b.set_riders({me: 3, 77: 0})
	player.vessel = b
	var gun := is_equal_approx(player.weapon.station_mult(), WBoat.GUN_MULT)
	_rq_station(97, me, b.next_free_after(3))
	await get_tree().process_frame
	var moved := b.station_of(me) == "sail"
	player.vessel = null
	var bearing := WBoat.bearing(Vector3(0, 0, 1), Vector3(-1, 0, 0.3)) == "off the starboard bow" and WBoat.bearing(Vector3(0, 0, 1), Vector3(0, 0, -5)) == "astern"
	print("BOATCREW stations=%s trim=%s oars=%s gun=%s moved=%s bearing=%s" % [",".join(names), trim, oars, gun, moved, bearing])
	get_tree().quit()


## Testing aid: two who keep together fall into a squad; a third and fourth join; a fifth cannot;
## one who strays leaves after a while, and a squad left with one is none.
func debug_squads() -> void:
	await get_tree().create_timer(1.0).timeout
	var o := Vector3(5000, 0, 5000)
	var pos := {1: o, 2: o + Vector3(5, 0, 0)}
	for k in 14:
		squads_step(pos, 2.0)
	var early := squads.is_empty()
	squads_step(pos, 2.0)
	squads_step(pos, 2.0)
	var pair: bool = squads.get(1, 0) != 0 and squads.get(1) == squads.get(2)
	pos[3] = o + Vector3(0, 0, 6)
	pos[4] = o + Vector3(0, 0, -6)
	pos[5] = o + Vector3(6, 0, 6)
	for k in 17:
		squads_step(pos, 2.0)
	var four := _squad_size(int(squads.get(1, 0))) == 4
	var fifth := not squads.has(5)
	pos[2] = o + Vector3(900, 0, 0)
	for k in 91:
		squads_step(pos, 2.0)
	var left := not squads.has(2)
	pos.erase(3)
	pos.erase(4)
	pos.erase(5)
	squads_step(pos, 2.0)
	var none := not squads.has(1)
	print("SQUADS early=%s pair=%s four=%s fifth=%s left=%s none=%s" % [early, pair, four, fifth, left, none])
	get_tree().quit()


## Testing aid: ammunition bought costs more than making it, sold fetches less than making it, and
## a drop in the harder lands carries more.
func debug_ammoprice() -> void:
	await get_tree().create_timer(1.0).timeout
	var ok_buy := true
	var ok_sell := true
	var scrap_v: float = ui.buy_price("scrap", "")
	for r in Items.RECIPES:
		if not r.bench or not r.id in ["shells", "rounds", "rifle"]:
			continue
		var make: float = (float(r.cost.get("salt", 0)) + float(r.cost.get("scrap", 0)) * scrap_v) / float(r.n) * 10.0
		var buy: float = ui.buy_price(r.id, "")
		var sell: float = ui.sell_price(r.id)
		ok_buy = ok_buy and buy > make
		ok_sell = ok_sell and sell * float(r.n) / 10.0 < float(r.cost.get("salt", 0)) + float(r.cost.get("scrap", 0)) * 2.0
	# Shells cost most of the three by the ten
	var dearest: bool = ui.buy_price("shells", "") > ui.buy_price("rounds", "")
	print("AMMOPRICE buy_over_make=%s sell_under_make=%s shells_dearest=%s" % [ok_buy, ok_sell, dearest])
	get_tree().quit()


## Testing aid: deeds near a town make its roads safer and raise standing there; days of neglect and a
## camp standing near lower it; a band left alone digs in and costs the town.
func debug_safety() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var t := "cinderwick"
	safety.erase(t)
	deeds.erase(t)
	var start := safety_of(t)
	var rep0 := int(rep.get(t, 0))
	for k in 12:
		_w_safety(t, SAFETY_KILL, Net.my_name())
	var up: bool = safety_of(t) == start + 12 and int(rep.get(t, 0)) == rep0 + 1
	var nearest: bool = town_near(gpos(WPlaces.spos(t) + Vector2(100, 0)), SAFETY_REACH) == t
	var s1 := safety_of(t)
	_safety_dawn()
	var slipped := safety_of(t) == s1 - SAFETY_DECAY
	# A band left alone, far from anyone, digs in and costs the town
	var at := gpos(WPlaces.spos(t) + Vector2(260, 0))
	var f = spawn_at("rusher", at + Vector3(0, 1.5, 0))
	_track_band(at, [f])
	var s2 := safety_of(t)
	var camps0 := events.active.values().filter(func(x): return x.kind == "camp").size()
	player.place(at + Vector3(600, 2, 0), 0.0)
	await get_tree().create_timer(0.5).timeout
	_bands_tick(BAND_DIG + 1.0)
	await get_tree().process_frame
	var dug: bool = events.active.values().filter(func(x): return x.kind == "camp").size() == camps0 + 1 and safety_of(t) == s2 - SAFETY_FLED
	var s3 := safety_of(t)
	_safety_dawn()
	var camp_hurts := safety_of(t) <= s3 - SAFETY_DECAY - SAFETY_CAMP_DECAY
	print("SAFETY up=%s nearest=%s slipped=%s dug=%s camp_hurts=%s word=%s" % [up, nearest, slipped, dug, camp_hurts, safety_word(safety_of(t))])
	get_tree().quit()


## Testing aid: what safe and dangerous roads bring: stock, prices, barred gates and the knock, the
## plea, a bounty, honours and the town's gift, rivals' grumbling, the watch, and caravans to rob.
func debug_roads() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	_debug_room(6)
	var a := "cinderwick"
	var ks := WPlaces.SETTLEMENTS.keys()
	ks.sort_custom(func(x, y): return WPlaces.spos(x).distance_to(WPlaces.spos(a)) < WPlaces.spos(y).distance_to(WPlaces.spos(a)))
	var b: String = ks[1]
	visited[a] = true
	safety[a] = 70
	var stock_safe := stock_at("smith", a).has("tempered")
	safety[a] = 40
	var stock_plain := not stock_at("smith", a).has("tempered")
	safety[a] = 10
	var dear := price_mult_at(a) > 1.0
	# Gates barred at night, and the knock
	night = true
	rep[a] = 0
	_gates_tick(1.0)
	var shut: bool = gates_shut.get(a, false) and (gates[a][0].body as CollisionObject3D).collision_layer == 1
	_knock(a, 0)
	_gates_tick(0.1)
	var stranger_kept: bool = (gates[a][0].body as CollisionObject3D).collision_layer == 1
	rep[a] = 3
	_knock(a, 0)
	_gates_tick(0.1)
	var known_in: bool = (gates[a][0].body as CollisionObject3D).collision_layer == 0
	night = false
	_gates_tick(0.1)
	var plea: Dictionary = town_plea(gpos(WPlaces.spos(a)) + Vector3(50, 0, 0))
	# Honours, and the gift once
	rep[a] = 4
	flags.erase("honour_gift_" + a)
	var fr0 := inv.count("fittings_rare")
	_bounty(a, player.global_position, Net.me())
	var friend := honour_title(a).begins_with("Friend")
	rep[a] = 7
	_bounty(a, player.global_position, Net.me())
	var gift := inv.count("fittings_rare") == fr0 + 1
	_bounty(a, player.global_position, Net.me())
	var once := inv.count("fittings_rare") == fr0 + 1
	# Rivals: a dangerous town beside a safe one grumbles
	safety[a] = 10
	safety[b] = 80
	rep[a] = 3
	flags.erase("grumble_" + a)
	_rivals_dawn()
	var grumble := int(rep[a]) == 2
	# The watch walks the roads of a peaceful town
	safety[b] = 95
	_militia_tick(1.0)
	var watch := militia.filter(func(m): return m.town == b).size() == MILITIA_N
	# A caravan between safe towns, robbed
	safety[a] = 70
	safety[b] = 70
	var mid: Vector2 = (WPlaces.spos(a) + WPlaces.spos(b)) * 0.5
	var route := convoy_route(gpos(mid)).size() == 2
	rep[a] = 5
	var s0 := safety_of(a)
	_w_robbed(Net.me(), gpos(mid))
	var robbed: bool = safety_of(a) == s0 - 10 and int(rep[a]) == 2
	print("ROADS stock=%s plain=%s dear=%s shut=%s stranger=%s known=%s plea=%s friend=%s gift=%s once=%s grumble=%s watch=%s route=%s robbed=%s" % [stock_safe, stock_plain, dear, shut, stranger_kept, known_in, not plea.is_empty(), friend, gift, once, grumble, watch, route, robbed])
	get_tree().quit()


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
	await _debug_home()
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


## Test: the great ones fight in learnable loops; their worst tricks (the Idol's rings, the Disc's line,
## the Watcher's ambush) are each shown before they land.
func debug_patterns() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await _debug_home()
	clock = 12.0
	player.health = 999999.0
	player.max_health = 999999.0
	var out := []
	for spec in [["boss_basalt", "quake", 0], ["boss_salt", "line", 2], ["boss_forest", "ambush", 1]]:
		marks_seen = {}
		var e := spawn_at(spec[0], player.global_position + Vector3(0, 2, -14))
		e.set_meta("raid", true)
		e.hurt(e.max_hp * 0.55, Vector3(0, 0, -1))
		await get_tree().physics_frame
		var before: Vector3 = e.global_position
		e._busy = 0.0
		e._spent = 0.0
		e._combo = []
		e._do_way(spec[1], player)
		for i in 5 * 60:
			await get_tree().physics_frame
		var moved: bool = e.global_position.distance_to(before) > 5.0
		out.append("%s=%d%s" % [spec[1], marks_seen.get(spec[2], 0), " moved" if moved else ""])
		# Its loop: the wroth loop is the one it now walks
		out.append("%s_wroth=%s" % [spec[0], e._wroth])
		e.die(false)
	print("PATTERNS " + " ".join(out))
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
	# About a third of what lies ahead on the road is a fight, and none while the fellowship catches its breath
	var roll := rr.randf() * (0.66 if breather > 0.0 else 1.0)
	# Near a town whose roads are kept safe, fewer of them are fights; near a dangerous one, more
	var tn := town_near(at, SAFETY_REACH + 200.0)
	if tn != "" and roll >= 0.66:
		var sf := safety_of(tn)
		if sf >= 60 and rr.randf() < 0.5:
			roll = rr.randf() * 0.66
		elif sf < 25 and rr.randf() < 0.3:
			roll = 0.88 + rr.randf() * 0.12
	var kind := "camp"
	if roll < 0.26:
		kind = "camp"
	elif roll < 0.46:
		kind = "fallen"
	elif roll < 0.66:
		kind = "cairn"
	elif roll < 0.78:
		kind = "pack"
	elif roll < 0.88:
		kind = "attack"
	else:
		kind = "unlit"
	match kind:
		"camp":
			drop_for_each(at + Vector3(1.5, 0, 0), func(): return Items.roll("camp", 3, rr))
		"fallen":
			drop_for_each(at, func(): return Items.roll("corpse", 3, rr) + Items.roll("caravan", 1, rr))
		"pack":
			var band := pack_at(at, WCrowd.scale_near(self, seen_from, 2 + rr.randi() % 3))
			var made := []
			for k in band:
				made.append(_spawn_near(k, at, 2.0, 8.0, true))
			_track_band(at, made)
		"attack":
			drop_for_each(at, func(): return Items.roll("caravan", 3, rr))
			var band := pack_at(at, WCrowd.scale_near(self, seen_from, 1 + rr.randi() % 3))
			var made := []
			for k in band:
				made.append(_spawn_near(k, at, 4.0, 10.0, true))
			_track_band(at, made)
		"cairn":
			drop_for_each(at, func(): return Items.roll("vault", 3, rr))
		"unlit":
			# A band of the Unlit at their fire: gunmen and blades, and now and then a breaker
			drop_for_each(at + Vector3(1.5, 0, 0), func(): return Items.roll("camp", 2, rr) + Items.roll("caravan", 2, rr))
			var band := ["unlit_gun", "unlit_gun", "unlit_blade"]
			if rr.randf() < 0.5:
				band.append("unlit_blade")
			if rr.randf() < 0.45:
				band.append("unlit_mark")
			if rr.randf() < 0.4:
				band.append("unlit_flame")
			if rr.randf() < 0.3 or maxf(absf(at.x), absf(at.z)) > 900.0:
				band.append("unlit_brute")
			var made := []
			for k in band:
				made.append(_spawn_near(k, at, 2.0, 6.0, true))
			_track_band(at, made)
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
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
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
	clock = 12.0 if OS.get_environment("SHOT_OUT") != "" else 19.5
	if OS.get_environment("HITS") != "":
		for b in beasts.values():
			if is_instance_valid(b):
				debug_show_hits(b)
	if OS.get_environment("SHOT_OUT") != "":
		_debug_aim(base + Vector3(0, 0.4, 0))
		for k in 40:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
		get_tree().quit()


## Picture aid: forms (FOES=a,b,c) standing still side-on, then head-on, their hit shapes drawn over them.
func debug_hitshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var side := f.cross(Vector3.UP)
	var kinds := OS.get_environment("FOES").split(",", false)
	var dist := float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else 9.0
	var gap := float(OS.get_environment("GAP")) if OS.get_environment("GAP") != "" else 4.0
	var made := []
	for i in kinds.size():
		var q := player.global_position + f * dist + side * (i - (kinds.size() - 1) * 0.5) * gap
		var e := spawn_at(kinds[i], Vector3(q.x, terrain.height_at(q.x, q.z) + 1.5, q.z))
		e.set_meta("raid", true)
		e._buried = 0.0   # not still climbing out of the ground
		made.append(e)
	await get_tree().create_timer(1.5).timeout
	for i in made.size():
		if not is_instance_valid(made[i]):
			print("HITSHOT %s gone" % kinds[i])
			continue
		var e: LesserSpeeb = made[i]
		e.set_physics_process(false)
		# Back where it was set, standing on the ground, whatever it did in the meantime
		var q := player.global_position + f * dist + side * (i - (made.size() - 1) * 0.5) * gap
		e.global_position = Vector3(q.x, terrain.height_at(q.x, q.z) + float(e.spec.radius), q.z)
		e.visible = true
		debug_show_hits(e)
	made = made.filter(func(e): return is_instance_valid(e))
	for view in ["side", "front"]:
		for e in made:
			var to := side if view == "side" else -f
			e.rotation.y = atan2(to.x, to.z)
			var gp: Vector3 = e.global_position
			print("HITSHOT %s %s at %s hits=%d ground=%.2f hidden=%s" % [view, e.variant if e.variant != "" else e.kind, gp, e.find_children("*", "CollisionShape3D", true, false).size(), terrain.height_at(gp.x, gp.z), e.hidden])
		_debug_aim(player.global_position + f * dist + Vector3(0, float(OS.get_environment("AIM_Y")) if OS.get_environment("AIM_Y") != "" else 0.5, 0))
		for k in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT") + "_" + view + ".png")
	get_tree().quit()


## Testing aid: which drawn thing makes the screen bright at px? Each candidate is hidden in turn.
func _debug_find_bright(px: Vector2i) -> void:
	var cam := get_viewport().get_camera_3d()
	var base := get_viewport().get_texture().get_image().get_pixelv(px)
	print("BRIGHT at %s base=%s" % [px, base])
	var cands := []
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		if g is CPUParticles3D or g is GPUParticles3D or cam.global_position.distance_to(g.global_position) < 6.0:
			cands.append(g)
	print("BRIGHT %d candidates" % cands.size())
	for g in cands:
		g.visible = false
		await get_tree().process_frame
		await get_tree().process_frame
		var now := get_viewport().get_texture().get_image().get_pixelv(px)
		g.visible = true
		if absf(now.get_luminance() - base.get_luminance()) > 0.04:
			print("BRIGHT FOUND %s %s d=%.2f lum %.2f->%.2f path=%s" % [g.name, g.get_class(), cam.global_position.distance_to(g.global_position), base.get_luminance(), now.get_luminance(), str(g.get_path()).right(120)])
			if g is CPUParticles3D:
				var cp := g as CPUParticles3D
				print("   amount=%d life=%.1f mesh=%s mat=%s" % [cp.amount, cp.lifetime, cp.mesh, cp.material_override])
			if g is MeshInstance3D:
				print("   mesh=%s mat=%s" % [(g as MeshInstance3D).mesh, g.material_override])
	await get_tree().process_frame


## Testing aid: what is drawn near the eye, and what lands where on the screen (to find stray squares)
func _debug_whats_drawn() -> void:
	var cam := get_viewport().get_camera_3d()
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var p := g.global_position
		var d := cam.global_position.distance_to(p)
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		if d < 3.0 or (d < 60.0 and sp.x > 560 and sp.x < 760 and sp.y > 150 and sp.y < 560):
			var mesh := ""
			if g is MeshInstance3D and (g as MeshInstance3D).mesh:
				mesh = (g as MeshInstance3D).mesh.get_class()
			print("DRAWN %s %s mesh=%s d=%.2f screen=%s path=%s" % [g.name, g.get_class(), mesh, d, Vector2i(sp), str(g.get_path()).right(90)])
	for n in get_tree().root.find_children("*", "Control", true, false):
		var c := n as Control
		if c.is_visible_in_tree() and (c is ColorRect or c is TextureRect or c is Panel) and c.get_global_rect().size.x < 40 and c.get_global_rect().size.y < 40 and c.get_global_rect().size.x > 4:
			print("UI %s %s rect=%s path=%s" % [c.name, c.get_class(), c.get_global_rect(), str(c.get_path()).right(90)])


## Picture aid: forms walking past, side on, pictured three times a little apart: do their bodies move?
func debug_animshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var side := f.cross(Vector3.UP)
	var kinds := OS.get_environment("FOES").split(",", false)
	var dist := float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else 12.0
	var gap := float(OS.get_environment("GAP")) if OS.get_environment("GAP") != "" else 7.0
	var made := []
	for i in kinds.size():
		var q := player.global_position + f * dist + side * (i - (kinds.size() - 1) * 0.5) * gap
		var e := spawn_at(kinds[i], Vector3(q.x, terrain.height_at(q.x, q.z) + 1.5, q.z))
		e.set_meta("raid", true)
		e._buried = 0.0
		made.append(e)
	await get_tree().create_timer(1.0).timeout
	_debug_aim(player.global_position + f * dist + Vector3(0, 1.0, 0))
	for k in 3:
		# Each held side on to the eye and set walking along its own line, back where it began
		for i in made.size():
			var e = made[i]
			if not is_instance_valid(e):
				continue
			var q := player.global_position + f * dist + side * (i - (made.size() - 1) * 0.5) * gap
			e.global_position = Vector3(q.x, terrain.height_at(q.x, q.z) + float(e.spec.radius), q.z)
			e.rotation.y = atan2(side.x, side.z)
			print("ANIMSHOT %d %s clip=%s at=%.2f" % [k, e.variant if e.variant != "" else e.kind, e._scan_anim.current_animation if e._scan_anim else "-", e._scan_anim.current_animation_position if e._scan_anim else -1.0])
		for j in 3:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT") + "_%d.png" % k)
		await get_tree().create_timer(0.5).timeout
	get_tree().quit()


## Picture aid: a form struck from the side three times, pictured as the blood flies and again once it has landed.
func debug_bloodshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	Game.blood = true
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var side := f.cross(Vector3.UP)
	var q := player.global_position + f * 5.0
	var e := spawn_at("rusher", Vector3(q.x, terrain.height_at(q.x, q.z) + 1.0, q.z))
	await get_tree().create_timer(0.8).timeout
	e.set_physics_process(false)
	e.global_position = Vector3(q.x, terrain.height_at(q.x, q.z) + float(e.spec.radius), q.z)
	_debug_aim(q + Vector3(0, 0.3, 0))
	for k in 10:
		await get_tree().process_frame
	# Slowed right down: drawn here a frame takes about half a second, longer than the spray lives
	Engine.time_scale = 0.03
	for k in 3:
		e.bleed(side.rotated(Vector3.UP, (k - 1) * 0.3), 22.0)
	# A gunman's shot at the eye from ahead and a round going away, seen end on: lines, no squares
	_w_tracer(q + Vector3(0, 1.2, 0) + f * 10.0, player.global_position + Vector3(0, 1.5, 0))
	for k in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT") + "_fly.png")
	Engine.time_scale = 1.0
	await get_tree().create_timer(1.5).timeout
	e.queue_free()
	for k in 3:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT") + "_land.png")
	print("BLOODSHOT shown=%d" % LesserSpeeb.blood_shown)
	for n in get_tree().root.find_children("*", "CanvasItem", true, false):
		var ci := n as CanvasItem
		if not ci.is_visible_in_tree() or ci is Node3D:
			continue
		var r := Rect2()
		if ci is Control:
			r = (ci as Control).get_global_rect()
		elif ci is Node2D:
			r = Rect2((ci as Node2D).global_position, Vector2(1, 1))
		if r.has_point(Vector2(1000, 560)) and r.size.x < 1200:
			print("CANVAS %s %s rect=%s mod=%s path=%s" % [ci.name, ci.get_class(), r, ci.modulate, str(ci.get_path()).right(120)])
	get_tree().quit()


## Picture aid: a broken tower and a shrine (RUINS=tower,shrine) set before the eye, their solid shapes drawn red.
func debug_ruinshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var side := f.cross(Vector3.UP)
	var kinds := OS.get_environment("RUINS").split(",", false)
	for i in kinds.size():
		var c := player.global_position + f * 24.0 + side * (i - (kinds.size() - 1) * 0.5) * 22.0
		c.y = terrain.height_at(c.x, c.z)
		var n := Node3D.new()
		n.position = c
		n.rotation.y = atan2(f.x, f.z)
		add_child(n)
		var rd := RandomNumberGenerator.new()
		rd.seed = 77 + i
		WDress.ruin(self, kinds[i], n, rd, land_at(c))
		if OS.get_environment("HITS") != "":
			for b in n.find_children("*", "StaticBody3D", true, false):
				debug_show_hits(b)
	_debug_aim(player.global_position + f * 24.0 + Vector3(0, 1.0, 0))
	for k in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	get_tree().quit()


## Picture aid: a body's hit shapes drawn over it, see-through red, to check them against the model.
func debug_show_hits(body: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.1, 0.1, 0.35)
	mat.no_depth_test = true
	for cs in body.find_children("*", "CollisionShape3D", true, false):
		var sh: Shape3D = (cs as CollisionShape3D).shape
		var mi := MeshInstance3D.new()
		if sh is CapsuleShape3D:
			var m := CapsuleMesh.new()
			m.radius = (sh as CapsuleShape3D).radius
			m.height = (sh as CapsuleShape3D).height
			mi.mesh = m
		elif sh is SphereShape3D:
			var m := SphereMesh.new()
			m.radius = (sh as SphereShape3D).radius
			m.height = m.radius * 2.0
			mi.mesh = m
		elif sh is BoxShape3D:
			var m := BoxMesh.new()
			m.size = (sh as BoxShape3D).size
			mi.mesh = m
		elif sh is ConcavePolygonShape3D:
			var am := ArrayMesh.new()
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = (sh as ConcavePolygonShape3D).get_faces()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mi.mesh = am
		elif sh is CylinderShape3D:
			var m := CylinderMesh.new()
			m.top_radius = (sh as CylinderShape3D).radius
			m.bottom_radius = m.top_radius
			m.height = (sh as CylinderShape3D).height
			mi.mesh = m
		else:
			continue
		mi.material_override = mat
		cs.add_child(mi)


## Picture aid: the land's scanned leavings in two rows before the eye.
func debug_propshot() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 11.0
	var f := -player.global_transform.basis.z
	f.y = 0
	f = f.normalized()
	var side := f.cross(Vector3.UP)
	var keys := ["barrel_03", "old_military_crate", "cement_bag", "metal_jerrycan", "old_tyre", "barrel_stove", "wooden_crate_02", "wooden_bucket_01",
		"tree_stump_01", "root_cluster_01", "namaqualand_boulder_02", "namaqualand_boulder_05", "dry_branches_medium_01", "rusted_wheel_rim_02", "wicker_basket_01", "wooden_lantern_01"]
	var n := Node3D.new()
	add_child(n)
	n.global_position = player.global_position
	for i in keys.size():
		var row := i / 8
		var off := f * (5.0 + row * 4.5) + side * ((i % 8) - 3.5) * 1.6 * (1.0 + row * 0.6)
		var at := n.global_position + off
		WDress.kp(n, "scan", keys[i], Vector3(off.x, terrain.height_at(at.x, at.z) - n.global_position.y, off.z), 0.4, 1.0 if row == 0 else 0.8)
	_debug_aim(n.global_position + f * 7.0 + Vector3(0, -0.3, 0))
	for k in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/props.png")
	print("PROPS placed ", n.get_child_count())
	get_tree().quit()


## Testing aid: every town's plan and wall, for drawing; and that each keeps its houses and is unlike the others.
func debug_townplans() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var shapes := {}
	for k in WPlaces.SETTLEMENTS:
		var plan := _town_plan(k)
		var houses := 0
		var wall := []
		for i in 48:
			wall.append(snappedf(town_wall_r(k, TAU * i / 48.0), 0.1))
		var parts := []
		for b in plan:
			if b.kind == "house":
				houses += 1
			parts.append([b.kind, snappedf(b.off.x, 0.1), snappedf(b.off.y, 0.1), snappedf(float(b.yaw), 0.01), b.w, b.d])
		print("TOWNPLAN ", JSON.stringify({"k": k, "style": town_style(k), "r": WPlaces.SETTLEMENTS[k].radius, "wall": wall, "parts": parts}))
		shapes[town_style(k)] = shapes.get(town_style(k), 0) + 1
		if houses < 6:
			print("TOWNPLANS few houses at ", k, " ", houses)
	var outs: int = get_meta("shells_out", 0)
	var barns: int = get_meta("shells_barns", 0)
	var kinds := 0
	for pk in WShells.PACKS:
		kinds += WShells.kinds(pk).size()
	print("TOWNPLANS towns=%d styles=%d shells=%d barns=%d kinds=%d" % [WPlaces.SETTLEMENTS.size(), shapes.size(), outs, barns, kinds])
	get_tree().quit()


## Picture aid: each town from high above, to see how it is laid out.
## Testing aid: what stands to be drawn near a town, by what holds it (no renderer needed).
var _tops := {}
func debug_townparts() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var k: String = OS.get_environment("TOWNS") if OS.get_environment("TOWNS") != "" else "cinderwick"
	var c := gpos(WPlaces.spos(k))
	var r: float = WPlaces.SETTLEMENTS[k].radius
	var eye := c + Vector3(0, 2, r * 0.8)
	player.place(eye, 0.0)
	for i in 120:
		await get_tree().process_frame
	var by := {}
	var shadow := 0
	var total := 0
	for g in find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var d := gi.global_position.distance_to(eye)
		if gi.visibility_range_end > 0.0 and d > gi.visibility_range_end + gi.visibility_range_end_margin:
			continue
		if d > 400.0 and not gi is MultiMeshInstance3D:
			continue
		var surf := 1
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			surf = (gi as MeshInstance3D).mesh.get_surface_count()
		var top: Node = gi
		while top.get_parent() and top.get_parent() != self:
			top = top.get_parent()
		var key := "%s:%s" % [top.get_class(), str(top.name).rstrip("0123456789@")]
		if OS.get_environment("DEEP") != "":
			var mname := str((gi as MeshInstance3D).mesh.resource_name) if gi is MeshInstance3D and (gi as MeshInstance3D).mesh else gi.get_class()
			var par := str(gi.get_parent().name).rstrip("0123456789@")
			key = "%s / %s / %s" % [key, par, mname.left(30)]
		if gi.get_script() != null or top.get_script() != null:
			key += "*" + str((top.get_script() as Script).resource_path.get_file() if top.get_script() else "")
		if OS.get_environment("DEEP") == "2" and key.ends_with("/ ") and randf() < 0.03:
			var chain := ""
			var q: Node = gi
			while q and q != self:
				chain = "%s(%s)<" % [str(q.name), q.get_class()] + chain
				q = q.get_parent()
			print("PARTS eg %s mesh=%s meta=%s" % [chain, (gi as MeshInstance3D).mesh.get_class() if gi is MeshInstance3D and (gi as MeshInstance3D).mesh else "-", top.get_meta_list()])
		by[key] = int(by.get(key, 0)) + surf
		if OS.get_environment("DEEP") == "3" and key.ends_with("/ "):
			var tk := "%s|%s" % [str(top.name), str(gi.get_parent().name)]
			_tops[tk] = int(_tops.get(tk, 0)) + 1
		total += surf
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadow += surf
	var keys := by.keys()
	keys.sort_custom(func(a, b): return by[a] > by[b])
	for kk in keys.slice(0, 30):
		print("PARTS %6d %s" % [by[kk], kk])
	print("PARTS total=%d shadow=%d" % [total, shadow])
	var tks := _tops.keys()
	tks.sort_custom(func(a, b): return _tops[a] > _tops[b])
	for tk in tks.slice(0, 25):
		var nm: String = str(tk).split("|")[0]
		var tn: Node = get_node_or_null(NodePath(nm))
		var info := ""
		if tn:
			info = "pos=%s metas=%s kids=%d script=%s" % [tn.get("global_position"), tn.get_meta_list(), tn.get_child_count(), tn.get_child(0).get_class() if tn.get_child_count() > 0 else "-"]
		print("TOP %d %s %s" % [_tops[tk], tk, info])
	get_tree().quit()


## Testing aid: draw calls and objects drawn, standing in each town looking across it at eye height.
func debug_towndraw() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	var tot := 0
	var ks: Array = Array(OS.get_environment("TOWNS").split(",")) if OS.get_environment("TOWNS") != "" else WPlaces.SETTLEMENTS.keys()
	for k in ks:
		var c := gpos(WPlaces.spos(k))
		var r: float = WPlaces.SETTLEMENTS[k].radius
		player.place(c + Vector3(0, 2, r * 0.8), 0.0)
		for i in 60:
			await get_tree().process_frame
		var dc := 0
		var ob := 0
		for i in 10:
			await get_tree().process_frame
			dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			ob += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		print("TOWNDRAW %s draws=%d objects=%d" % [k, dc / 10, ob / 10])
		tot += dc / 10
	print("TOWNDRAW mean=%d" % (tot / maxi(1, ks.size())))
	get_tree().quit()


func debug_townsky() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	var cam := Camera3D.new()
	add_child(cam)
	cam.far = 600.0
	var ks: Array = Array(OS.get_environment("TOWNS").split(",")) if OS.get_environment("TOWNS") != "" else ["cinderwick", "lanternwell", "kiln"]
	if OS.get_environment("BARN") != "":
		var bp: Vector2 = get_meta("barn_spots")[int(OS.get_environment("BARN"))]
		var bc := gpos(bp)
		player.place(bc + Vector3(0, 2, 30), 0.0)
		for i in 40:
			await get_tree().process_frame
		cam.global_position = bc + Vector3(14, 6, 22)
		cam.look_at(bc + Vector3(0, 3, 0), Vector3.UP)
		cam.make_current()
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/sky_barn.png")
		ks = []
	for k in ks:
		var c := gpos(WPlaces.spos(k))
		player.place(c + Vector3(0, 2, 0), 0.0)
		for i in 40:
			await get_tree().process_frame
		cam.global_position = c + Vector3(0, 70, 95)
		cam.look_at(c, Vector3.UP)
		cam.make_current()
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/sky_%s.png" % k)
		print("TOWNSKY ", k, " ", town_style(k))
	get_tree().quit()


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
	await _debug_home()
	_debug_room(6)
	await get_tree().create_timer(1.0).timeout
	var had := [inv.count("hide"), inv.count("raw_meat"), inv.count("bone")]   # what the pack held before, picked up about the start
	shared("_rq_satchel", [Net.me(), player.global_position + Vector3(0, 0, -2), [["hide", 3], ["raw_meat", 2], ["bone", 6]], false])
	await get_tree().create_timer(1.0).timeout
	var sid: String = satchels.keys()[-1]
	var n0 := satchels.size()
	var asked := take_all(sid)
	await get_tree().create_timer(1.0).timeout
	print("TAKEALL asked=%d hide=%d meat=%d bone=%d satchel_gone=%s" % [asked, inv.count("hide") - had[0], inv.count("raw_meat") - had[1], inv.count("bone") - had[2], satchels.size() < n0])
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
## Testing aid: a new pilgrim's first hour, walked for real (at four times speed) and timed. Says what is
## near the start, how long each first step takes, what is said on screen and how long each word stays
## before the next replaces it, and when the first night falls.
func debug_firsthour() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var t0 := Time.get_ticks_msec()
	Engine.time_scale = 4.0
	var game_s := func() -> float: return (Time.get_ticks_msec() - t0) / 1000.0 * 4.0
	var start := player.global_position
	var near := {}
	for nd in nodes:
		var d := Vector2(nd.pos.x - start.x, nd.pos.z - start.z).length()
		if d < 150.0:
			near[nd.kind] = int(near.get(nd.kind, 0)) + 1
	var town := gpos(WPlaces.spos("cinderwick"))
	print("FIRST start=%s clock=%.1f to_town=%.0fm near150=%s pack=%s" % [str(start), clock, Vector2(town.x - start.x, town.z - start.z).length(), near, inv.to_data().filter(func(x): return x != null)])
	var steps := []
	var last_step := guide.step
	var mark := func(what: String): steps.append("%s@%.0fs" % [what, game_s.call()])
	# Walk, dodge
	Input.action_press("move_forward")
	await get_tree().create_timer(1.5).timeout
	Input.action_release("move_forward")
	Input.action_press("dash")
	await get_tree().physics_frame
	Input.action_release("dash")
	await get_tree().create_timer(1.0).timeout
	mark.call("walked step=%d" % guide.step)
	# Gather from the nearest tree and rock, holding the key as a player would (1.6 s each)
	var got := 0
	for kind in ["tree", "rock", "scrap"]:
		var best := -1
		var bd := INF
		for nd in nodes:
			if nd.kind == kind and nd.charges > 0:
				var d := Vector2(nd.pos.x - player.global_position.x, nd.pos.z - player.global_position.z).length()
				if d < bd:
					bd = d
					best = nd.id
		if best < 0:
			mark.call("no %s anywhere" % kind)
			continue
		var walk_s: float = bd / player.walk_speed
		mark.call("nearest %s %.0fm (%.0fs on foot)" % [kind, bd, walk_s])
		for k in 2:
			_gather(best)
			await get_tree().create_timer(1.6 / 4.0 + 0.3).timeout
		got += 1
	mark.call("gathered step=%d wood=%d stone=%d cloth=%d" % [guide.step, inv.count("wood"), inv.count("stone"), inv.count("cloth")])
	ui.open_inventory("pack")
	await get_tree().create_timer(0.6).timeout
	var can_bandage := inv.count("cloth") >= 2
	mark.call("pack step=%d can_make_bandage=%s" % [guide.step, can_bandage])
	ui.close_all()
	print("FIRST steps %s" % [steps])
	# The walk to Cinderwick, on foot at walking pace, never stopping; foes met are counted and the
	# pilgrim kept alive so the whole road is seen
	var met := {}
	var hurt := 0.0
	var walk_t0: float = game_s.call()
	Input.action_press("move_forward")
	while game_s.call() - walk_t0 < 1200.0:
		var to := town - player.global_position
		to.y = 0.0
		if to.length() < 40.0:
			break
		player.yaw = atan2(-to.x, -to.z)
		player.rotation.y = player.yaw
		if player.health < player.max_health:
			hurt += player.max_health - player.health
			player.health = player.max_health
		for e in enemies:
			if is_instance_valid(e) and e.global_position.distance_to(player.global_position) < 25.0:
				met[e.get_instance_id()] = e.kind
		await get_tree().create_timer(0.25).timeout
	Input.action_release("move_forward")
	var kinds := {}
	for k in met.values():
		kinds[k] = int(kinds.get(k, 0)) + 1
	print("FIRST town arrived=%s walk=%.0fs clock=%.1f foes_met=%s damage_taken=%.0f step=%d visited=%s" % [(town - player.global_position).length() < 60.0, game_s.call() - walk_t0, clock, kinds, hurt, guide.step, visited.has("cinderwick")])
	print("FIRST dusk_at=%.1f minutes_to_dusk=%.1f" % [weather.dusk(), (weather.dusk() - clock) * DAY_SECONDS / 24.0 / 60.0])
	# What was said, and how long each stayed before the next took its place
	var short := 0
	var lines := []
	for i in hud.text_log.size():
		var e: Array = hud.text_log[i]
		if e[1] == "note":
			continue   # asked for; what was shown is what counts
		var stay := -1.0
		var grew := false   # the next line shown is this one with more picked up added: not cut short
		for j in range(i + 1, hud.text_log.size()):
			if hud.text_log[j][1] == e[1]:
				stay = (hud.text_log[j][0] - e[0]) / 1000.0 * 4.0
				grew = str(hud.text_log[j][2]).begins_with(str(e[2]))
				break
		if stay >= 0.0 and stay < 2.5 and not grew:
			short += 1
		lines.append("[%s %.0fs stay=%s] %s" % [e[1], (e[0] - t0) / 1000.0 * 4.0, ("%.1f" % stay) if stay >= 0.0 else "-", str(e[2]).replace("\n", " / ").left(140)])
	for l in lines:
		print("FIRST said ", l)
	print("FIRST summary lines=%d cut_short=%d" % [lines.size(), short])
	Engine.time_scale = 1.0
	get_tree().quit()


## Testing aid: lines under the compass that come together each get their turn; things picked up
## together share one line, counted up by kind.
func debug_toasts() -> void:
	await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(8.0).timeout   # the start's own words have passed
	hud.text_log.clear()
	hud.notify("+3 Deadwood")
	hud.notify("+2 Stone")
	hud.notify("+4 Deadwood")
	hud.notify("First line")
	hud.notify("Second line")
	hud.notify("Third line")
	var seen := {}
	var t := 0.0
	while t < 14.0:
		seen[hud.toast.text] = true
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	var merged: bool = seen.has("+7 Deadwood,  +2 Stone")
	print("TOASTS merged=%s all_seen=%s" % [merged, seen.has("First line") and seen.has("Second line") and seen.has("Third line")])
	get_tree().quit()


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
	e.hurt(e.max_hp * 0.45, Vector3(0, 0, -1))
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
	skills.use[g] = 0   # earlier checks in the same world may have practised it already
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
	print("BLADE out=%s light=%.0f heavy=%.0f stamina %.0f -> %.0f stops=%d time=%.2f" % [wpn.blade_out, light, heavy, st0, st1, Arms.stops, Engine.time_scale])
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
		player.weapon.guard_age = 0.0   # raised just now, each time: a perfect guard
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
	var tally := [end_tally({2: "writer", 3: "writer", 1: "keeper"}, 1), end_tally({2: "writer", 1: "keeper"}, 1), end_tally({2: "unlit", 3: "pilgrim"}, 3)]
	print("ENDING up=%s vote=%s" % [not hall.inside(player.global_position), ",".join(tally)])
	get_tree().quit()

## Testing aid: a far shot takes time to land, and still lands, and a moving foe would have walked on.
func debug_slug() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	player.place(spawn_pos, spawn_yaw)   # earlier checks in the same world leave the pilgrim anywhere, maybe behind trees
	await get_tree().physics_frame
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

## Testing aid: the forms do not grow with the arms they face, only with the land.
func debug_power() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var e0 := spawn_at("rusher", player.global_position + Vector3(0, 1.5, -20))
	var h0: float = e0.max_hp
	e0.die(false)
	Game.warms["tier"] = {"shotgun": 3}
	var e1 := spawn_at("rusher", player.global_position + Vector3(0, 1.5, -20))
	var h1: float = e1.max_hp
	e1.die(false)
	Game.warms["tier"] = {}
	print("POWER flat=%s tiers=%s" % [is_equal_approx(h0, h1), TIER_HP])
	get_tree().quit()

## Testing aid: a ward is worn in its slot and wards its land; taken off it no longer does; an old
## save's gas mask moves from the head to the face.
## Testing aid: earlier checks share the world and may leave the pilgrim riding, aboard, at sea or out on
## an isle, with roaming events about: back to the start, on foot, with none.
func _debug_home() -> void:
	if player.mount:
		dismount()
	if player.vessel != null and is_instance_valid(player.vessel):
		_leave_boat(player.vessel)
	player.place(spawn_pos, spawn_yaw)
	for id in events.active.keys():
		events.active.erase(id)
	await get_tree().create_timer(0.3).timeout


## Testing aid: earlier checks share the world, so make room in the pack before a check gives things.
## Testing aid: stand on open ground, out of any town, camp or beacon's keeping, where forms may come.
func _debug_open() -> void:
	var c := player.global_position
	for ring in range(0, 12):
		for j in 8:
			var q := c + Vector3(cos(TAU * j / 8.0), 0, sin(TAU * j / 8.0)) * ring * 60.0
			q = Vector3(q.x, terrain.height_at(q.x, q.z), q.z)
			if terrain.is_water(q.x, q.z, -0.2) or safe_at(q) or settlement_at(q, 120.0) != "" or base_at(q, 80.0) >= 0:
				continue
			player.place(q + Vector3(0, 0.5, 0), 0.0)
			return


func _debug_room(n := 4) -> void:
	for i in range(inv.slots.size() - 1, maxi(-1, inv.slots.size() - 1 - n), -1):
		inv.take_slot(i)


func debug_wear() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	_debug_room()
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
	var told := WUI.made_from("A veil.", {"cloth": 2}) == "A veil. Made from 2 %s." % Items.iname("cloth")
	print("WEAR before=%s on=%s off=%s moved=%s told=%s" % [before, on, off, moved, told])
	get_tree().quit()

## Testing aid: holding Hasten out in the waste runs faster than walking, and spends breath.
func debug_sprint() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await _debug_home()
	ui.close_all()   # an earlier check may have left a screen open, which holds the pilgrim still
	player.stamina = 100.0
	rest = 100.0
	food = 100.0
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

## Testing aid: two long guns, a side arm and a blade are carried; what is carried changes only at camp,
## in a town or at a workbench; the bar's keys take up each gun; the second long gun is saved.
func debug_carry() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await _debug_home()
	for g in ["sniper", "machine_gun"]:
		if not g in arms.owned:
			arms.owned.append(g)
	var l: Dictionary = lairs[0]
	player.place(gpos(Vector2(l.pos.x, l.pos.z)) + Vector3(0, 1, 0), 0.0)
	await get_tree().create_timer(0.3).timeout
	var road: bool = not ui.can_rearm()
	player.place(gpos(WPlaces.spos("cinderwick")) + Vector3(0, 1, 0), 0.0)
	await get_tree().create_timer(0.3).timeout
	var town: bool = ui.can_rearm()
	ui._carry("sniper", "primary2")
	var wp: Arms = player.weapon
	var three: bool = wp.guns == ["shotgun", "sniper", "pistol"]
	var keys := []
	for i in 3:
		var ev := InputEventAction.new()
		ev.action = "slot_%d" % (i + 1)
		ev.pressed = true
		player.relics._unhandled_input(ev)
		wp._switch = 0.0
		keys.append(wp.gun())
	ui._carry("machine_gun", "primary")
	var traded: bool = arms.primary == "machine_gun" and arms.primary2 == "sniper"
	var kept: bool = WArms.clean(arms.duplicate(true)).primary2 == "sniper"
	WArms.put_away(arms, "sniper")
	rearm()
	print("CARRY road=%s town=%s three=%s keys=%s traded=%s kept=%s down=%d" % [road, town, three, ",".join(keys), traded, kept, wp.guns.size()])
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
func debug_quickheal() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	_debug_room(6)
	for id in Items.DB:
		if str(Items.DB[id].get("kind", "")) == "medicine":
			inv.take(id, inv.count(id))
	inv.add("bandage", 2)
	inv.add("salve", 1)
	inv.add("elixir", 1)
	player.health = 10.0
	quick_heal()
	var first := inv.count("salve") == 0 and inv.count("elixir") == 1
	_burn = 3.0
	player.health = 10.0
	quick_heal()
	var cure := inv.count("elixir") == 0 and _burn == 0.0
	player.health = 10.0
	quick_heal()
	var last := inv.count("bandage") == 1
	player.health = player.max_health
	quick_heal()
	var kept := inv.count("bandage") == 1
	print("QUICKHEAL first=%s cure=%s last=%s kept=%s key=%s" % [first, cure, last, kept, Game.key_text("quick_heal")])
	# One key for each action, and the controller's wheel reaches what has no button
	var shared_keys := 0
	for c in Game.CONTROLS:
		for d in Game.CONTROLS:
			if c[0] < d[0] and c[0] != "pause" and Game.keys_of(c[0]).any(func(k): return k in Game.keys_of(d[0])):
				shared_keys += 1
	var wheel: bool = InputMap.has_action("pad_wheel") and PadWheel.pick(Vector2(0, -1)) == 0 and PadWheel.pick(Vector2(1, 0)) == 3 and hud.root.find_children("*", "PadWheel", true, false).size() == 1
	print("WHEEL shared_keys=%d wheel=%s" % [shared_keys, wheel])


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
	# Stood behind it and to the side: it looks round only as far as a neck goes, and the right way
	c.rotation.y = 0.0
	player.global_position = c.global_position + Vector3(-2.5, 0, -2.0)
	await get_tree().create_timer(2.5).timeout
	var hy: float = c._head.rotation.y
	var neck := absf(hy) <= 1.11 and hy < -0.5
	var saved := c.to_data()
	saved.name = "Biscuit"
	c.queue_free()
	cat = null
	_cat_saved = saved
	await get_tree().create_timer(0.5).timeout
	print("CAT drains=%s blocked=%s tamed=%s riding=%s faster=%s sprint=%s spent=%s shared=%s followed=%s off=%s back=%s" % [drains, blocked, tamed, riding, walk > player.walk_speed, sprint > walk * 1.5, spent, shared, followed, off, cat != null and cat.cat_name == "Biscuit"])
	print("CAT neck=%s head=%.2f" % [neck, hy])
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
			if w.gun() != g and w.guns.has(g):
				w.cur = w.guns.find(g)
				w._show_model()
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
		# From its feet to the top of what it shows (a skinned part's room box, turned into the world, is
		# far larger than the body and is no measure of it)
		var lo: float = e._fb.global_position.y
		var hi: float = lo + e._fb.top() * e._fb.global_basis.get_scale().y
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
				# A shot at the head, wherever the body's pose holds it, strikes the foe and finds the head
				var wp: Array = e.weak_point()
				var head_hit := not wp.is_empty() and (wp[0] as Vector3).y > lerpf(lo, hi, 0.45)
				if head_hit:
					var ho := Vector3(base.x, (wp[0] as Vector3).y, base.z) - f * 3.0
					var hr := space.intersect_ray(PhysicsRayQueryParameters3D.create(ho, ho + f * 6.0, 2))
					head_hit = not hr.is_empty() and hr.collider == e and Arms._ray_near(ho, f, wp[0], wp[1])
				heads = heads and head_hit
				if not head_hit:
					print("HIT %s head missed: rel=%s r=%s" % [k, (wp[0] as Vector3) - base if not wp.is_empty() else Vector3.ZERO, wp[1] if not wp.is_empty() else 0.0])
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


## Testing aid: the camp pieces stand as real models, and the new ones do their work (tent rests, barrel
## keeps, anvil works).
func debug_campkit() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	var f := -player.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var side := f.cross(Vector3.UP)
	var kinds := ["tent", "barrel", "anvil", "chest", "bench", "bedroll", "campfire"]
	var at := {}
	for i in kinds.size():
		var p := player.global_position + f * 30.0 + side * (i - 3) * 4.0
		p.y = terrain.height_at(p.x, p.z)
		at[kinds[i]] = p
		builder._rq_build(1, kinds[i], p, 0.0)
	await get_tree().create_timer(0.5).timeout
	var modelled := 0
	var barrel_keeps := false
	for pid in pieces:
		var pc: Dictionary = pieces[pid]
		if pc.kind in kinds and pc.pos.distance_to(at[pc.kind]) < 0.6:
			var mis := (pc.node as Node3D).find_children("*", "MeshInstance3D", true, false)
			for mi in mis:
				if (mi as MeshInstance3D).mesh is ArrayMesh:
					modelled += 1
					break
			if pc.kind == "barrel" and containers.has("p%d" % pid):
				barrel_keeps = true
	var tent_rests := builder.near_kind(at.tent, "bedroll", 1.0)
	var anvil_works := builder.near_kind(at.anvil, "bench", 1.0)
	print("CAMPKIT modelled=%d/%d tent=%s barrel=%s anvil=%s" % [modelled, kinds.size(), tent_rests, barrel_keeps, anvil_works])
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
	var walls := false
	var space := get_world_3d().direct_space_state
	var G := WBuilder.GRID
	# A house's open door lets a ray through and its wall does not (any house whose front is clear)
	for hb in plan:
		if hb.kind != "house" or walls:
			continue
		var hc := c + Vector3(hb.off.x, 0, hb.off.y)
		var bas := Basis(Vector3.UP, float(hb.yaw))
		var front := bas * Vector3(0, 0, 1)
		var side := bas * Vector3(1, 0, 0)
		var W := float(hb.w) * G
		var door_x := -W * 0.5 + (int(hb.w) / 2 + 0.5) * G
		var wall_x := -W * 0.5 + 0.5 * G
		var y := terrain.height_at(hc.x, hc.z) + 1.2
		var hc2 := Vector3(hc.x, y, hc.z)
		var door_r := PhysicsRayQueryParameters3D.create(hc2 + front * 8.0 + side * door_x, hc2 + side * door_x, 1)
		var wall_r := PhysicsRayQueryParameters3D.create(hc2 + Vector3(0, 1.5, 0) + front * 8.0 + side * wall_x, hc2 + Vector3(0, 1.5, 0) + side * wall_x, 1)
		var dh := space.intersect_ray(door_r)
		var wh := space.intersect_ray(wall_r)
		walls = dh.is_empty() and not wh.is_empty()
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


## Test: the far sea (0.16). Five far places stand clear of each other and of the near isles, each
## dry in the middle; every far shore has its own hardship, and something worth walking to lies
## within 150 m of nearly every dry spot (the gameplay bible's "something every 200 to 300 m").
func debug_farsea() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var far: Array = terrain.isles.filter(func(il): return WIsles.far(il))
	var clear := true
	for a in terrain.isles:
		for b in terrain.isles:
			if a != b and Vector2(a.c).distance_to(b.c) < float(a.r) + float(b.r) + 200.0:
				clear = false
	var dry := 0
	var lands := []
	var worst := 1.0
	for il in far:
		var hc: Vector2 = terrain.isle_heart(il)
		if not terrain.is_water(hc.x, hc.y):
			dry += 1
		lands.append(land_at(gpos(hc)))
		# How full it is: dry spots with a ruin, a heart, a lair or a town within 150 m
		var pois: Array = []
		for ru in ruins:
			if Vector2(ru.pos.x, ru.pos.z).distance_to(il.c) < float(il.r) * 1.2:
				pois.append(Vector2(ru.pos.x, ru.pos.z))
		for l in lairs:
			pois.append(Vector2(l.pos.x, l.pos.z))
		for k in WPlaces.SETTLEMENTS:
			pois.append(WPlaces.spos(k))
		var r := RandomNumberGenerator.new()
		r.seed = 77
		var n := 0
		var near := 0
		for k in 400:
			var a := r.randf() * TAU
			var q: Vector2 = il.c + Vector2(cos(a), sin(a)) * sqrt(r.randf()) * float(il.r) * 0.8
			if terrain.height_at(q.x, q.y) < WIsles.SEA_Y + 1.0:
				continue
			n += 1
			if pois.any(func(pp): return pp.distance_to(q) < 150.0):
				near += 1
		var share := float(near) / maxf(1.0, float(n))
		worst = minf(worst, share)
		print("FARSEA %s at %d r=%d pois=%d full=%.2f" % [il.key, int(Vector2(il.c).length()), int(il.r), pois.size(), share])
	if OS.get_environment("FARMAP") != "":
		terrain.map_image(1024).save_png(OS.get_environment("FARMAP"))
	print("FARSEA far=%d clear=%s dry=%d lands=%s" % [far.size(), clear, dry, ",".join(lands)])
	print("FARSEA full=%s" % (worst >= 0.6))
	var towns := 0
	for k in WPlaces.SETTLEMENTS:
		if WPlaces.on_shore(k):
			var c := WPlaces.spos(k)
			var ok := terrain.height_at(c.x, c.y) > WIsles.SEA_Y + 2.0 and terrain.normal_at(c.x + 20.0, c.y).y > 0.97 and terrain.normal_at(c.x, c.y - 20.0).y > 0.97
			ok = ok and not WPlaces.roads.any(func(rd): return rd[0] == k or rd[1] == k)
			if ok:
				towns += 1
	print("FARSEA towns=%d" % towns)
	get_tree().quit()


## Test: the turn (the fifth beacon) and the Far Shores' hardships. The turn marks the world once,
## shows the whirlpool, and the seventh night comes from the sea. On the Frostmark the cold bites
## until the sheepskin is worn; on the Pale Steppe a pilgrim is lost until the compass is carried.
## Testing aid: after the turn the dark bowls are fouled; each takes oil only with its key, a failed vigil gives
## the key back, a lit bowl stays clean, and the ninth wants a coal from each Far Shore.
func debug_fouled() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	lit = [0, 1, 2, 3, 4]
	flags["turned"] = true
	for i in 5:
		flags["clean_%d" % i] = true
	flags["most_lit"] = 5
	var b: Vector3 = beacon_nodes[5].pos
	player.max_health = 100000.0
	player.health = 100000.0
	player.place(b + Vector3(4, 1, 0), 0.0)
	await get_tree().create_timer(0.5).timeout
	var want6: bool = key_for(5) == [["deep_oil", 1]] and fouled(5)
	inv.add("beacon_oil", 2)
	_beacon_touched(5)
	var barred := not vigils.has(5)
	inv.add("deep_oil", 1)
	_beacon_touched(5)
	var took: bool = vigils.has(5) and inv.count("deep_oil") == 0
	# Leave the bowl and let it gutter: the key and the oil come back
	player.place(b + Vector3(300, 1, 0), 0.0)
	await get_tree().create_timer(0.3).timeout
	vigils[5] = 0.01
	_vigil_tick(0.1)
	var back: bool = not vigils.has(5) and inv.count("deep_oil") == 1 and inv.count("beacon_oil") == 2
	player.place(b + Vector3(4, 1, 0), 0.0)
	await get_tree().create_timer(0.3).timeout
	_beacon_touched(5)
	vigils[5] = 0.01
	_vigil_tick(0.1)
	var lit6: bool = 5 in lit and flags.has("clean_5") and most_lit() == 6
	var want7: bool = key_for(6) == [["fleet_log", 1]]
	lit.erase(5)
	var stays_clean: bool = not fouled(5) and key_for(5).is_empty()
	var ninth: bool = key_for(8).size() == 3
	inv.add("heart_frost", 1)
	var heart_ok: bool = _key_fits(6, [["heart_frost", 1]]) == false and _has_key([["heart", 1]])
	print("FOULED want6=%s barred=%s took=%s back=%s lit6=%s want7=%s clean=%s ninth=%s heart=%s bowls=%d" % [want6, barred, took, back, lit6, want7, stays_clean, ninth, heart_ok, shrine_bowls.size()])
	get_tree().quit()


## Testing aid: danger 5 lies on the Far Shores only after the turn, nowhere in the waste; foes there take
## the fifth tier but their great one does not; kills there teach more.
func debug_danger5() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var shore: Vector3 = Vector3.INF
	for il in terrain.isles:
		if il.key == "frost":
			var h: Vector2 = terrain.isle_heart(il)
			shore = gpos(h)
	flags.erase("turned")
	var before := tier_at(shore)
	flags["turned"] = true
	var after := tier_at(shore)
	var waste_max := 0
	for k in 400:
		var a := k * 0.7
		var q := Vector3(cos(a), 0, sin(a)) * (k * 9.0)
		waste_max = maxi(waste_max, tier_at(q))
	var e := spawn_at("rusher", shore + Vector3(0, 2, 0))
	var foe_ok: bool = e != null and is_equal_approx(e.max_hp, float(LesserSpeeb.KINDS.rusher.hp) * TIER_HP[4] * WCrowd.hp(self))
	var b := spawn_at("boss_frost", shore + Vector3(5, 2, 0))
	var boss_ok: bool = b != null and b.max_hp < float(LesserSpeeb.BOSSES.boss_frost.get("hp", b.max_hp)) * TIER_HP[4] * 0.99
	print("DANGER5 before=%d after=%d waste_max=%d foe=%s boss=%s lists=%s" % [before, after, waste_max, foe_ok, boss_ok, TIER_HP.size() == 5 and TIER_HARM.size() == 5 and WDread.TIER_RATE.size() == 5 and WSpirits.TIER_BITE.size() == 5])
	get_tree().quit()


## Testing aid: the Second Vow's rules, the world after an ending (roaming great ones, feast days), completion.
func debug_keeping() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var vow0 := flags.has("second_vow")
	var lit0 := lit.duplicate()
	if not 0 in lit:
		lit.append(0)
	flags["second_vow"] = true
	flags["vow_at"] = world_hours() - TEND_HOURS * 2.0
	var low := flame_of(0)
	inv.add("oil", 1)
	tend_beacon(0)
	await get_tree().create_timer(0.2).timeout
	var high := flame_of(0)
	var shore := Vector3.INF
	for il in terrain.isles:
		if il.key == "sun":
			shore = gpos(terrain.isle_heart(il))
	var mults: bool = is_equal_approx(vow_mult(shore, 1.3), 1.15) and is_equal_approx(vow_mult(Vector3(300, 0, 300), 1.3), 1.3)
	var host := great_host()
	var far_in_waste := false
	for k in 60:
		var q := Vector3(cos(k * 0.5), 0, sin(k * 0.5)) * (900.0 + k * 20.0)
		if tier_at(q) >= 3 and land_at(q) != "sea" and terrain.isle_at(q.x, q.z, 1.3).is_empty():
			far_in_waste = forms_at(q).any(func(f): return f in far_forms())
			if far_in_waste:
				break
	# Roaming great ones, once the world is in the keeping
	flags["ending"] = "keeper"
	for k in 30:
		_roam_great()
		if not _lair_boss.is_empty():
			break
	var roamed: bool = not _lair_boss.is_empty()
	for id in _lair_boss.keys():
		if is_instance_valid(_lair_boss[id]):
			_lair_boss[id].die(false)
	_lair_boss.clear()
	# Feast days
	var ft := feast_town(7)
	var d0 := day
	day = 7
	var cheaper: bool = ft != "" and price_mult_at(ft) < price_mult_at("__none__") and feast_town(8) == ""
	day = d0
	# Completion
	var slain0 := slain_kinds.duplicate()
	for b in BIOME_FORMS:
		for k in BIOME_FORMS[b]:
			slain_kinds[k] = true
	for il in WIsles.THEMES:
		for k in WIsles.THEMES[il].get("forms", []):
			slain_kinds[k] = true
	rewards_had.clear()
	var st0 := inv.count("fittings_storied")
	_completion_check()
	var done: bool = rewards_had.has("beast_100") and inv.count("fittings_storied") > st0
	slain_kinds = slain0
	flags.erase("ending")
	if not vow0:
		flags.erase("second_vow")
	lit = lit0
	print("KEEPING low=%.2f high=%.2f mults=%s host=%s far_in_waste=%s roamed=%s feast=%s total=%d done=%s writer=%s" % [low, high, mults, host, far_in_waste, roamed, cheaper, bestiary_total(), done, ENDINGS.writer[1].contains("goes on")])
	get_tree().quit()


## Testing aid: the trophy hall (a third of a power at the base, never summed with the shrine's) and renown.
func debug_hall() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var at := player.global_position + Vector3(5, 0, 0)
	builder._rq_build(1, "trophy_hall", at, 0.0)
	await get_tree().create_timer(0.3).timeout
	var hp := -1
	for pid in pieces:
		if pieces[pid].kind == "trophy_hall":
			hp = pid
	for t in ["t_forest", "t_basalt", "t_salt", "t_dunes"]:
		inv.add(t, 2)
	power = ""
	power_left = 0.0
	hang_trophy(hp, "t_forest", true)
	hang_trophy(hp, "t_forest", true)   # one of each
	hang_trophy(hp, "t_basalt", true)
	hang_trophy(hp, "t_salt", true)
	hang_trophy(hp, "t_dunes", true)    # a fourth: no place for it
	await get_tree().create_timer(0.3).timeout
	var hung: Array = pieces[hp].get("hung", [])
	_hall_keys = halls_here(player.global_position)
	var eye_hall := power_k("eye")
	var saved: bool = world_data().pieces[hp][5].hung.size() == 3
	flags["shrine_t_forest"] = true
	take_power("t_forest")
	var eye_full := power_k("eye")
	power = ""
	power_left = 0.0
	var far_off := halls_here(player.global_position + Vector3(500, 0, 0)).is_empty()
	var back_in_pack: int = inv.count("t_forest")
	hang_trophy(hp, "t_salt", false)
	await get_tree().create_timer(0.3).timeout
	var down: bool = not "t_salt" in pieces[hp].hung and inv.count("t_salt") == 2
	# Renown
	var sk := WSkills.new()
	sk.level = WSkills.MAX_LEVEL
	sk.ranks = {"hardy": 2}
	sk.gain(9500)
	var step: bool = sk.renown == 1 and sk.renown_picks == 1
	var placed: bool = sk.take_reward("hall") and sk.hall_places() == 4 and not sk.take_reward("hall")
	sk.gain(9000)
	var points0 := sk.points
	var respec: bool = sk.take_reward("respec") and sk.ranks.is_empty() and sk.points == points0 + 2
	var back := WSkills.new()
	back.from_data(sk.to_data())
	var kept: bool = back.renown == 2 and back.rewards.size() == 2
	print("HALL hung=%d eye_hall=%.2f eye_full=%.2f far=%s saved=%s kept_one=%d down=%s" % [hung.size(), eye_hall, eye_full, far_off, saved, back_in_pack, down])
	print("RENOWN step=%s placed=%s respec=%s kept=%s" % [step, placed, respec, kept])
	get_tree().quit()


## Testing aid: the fires' verbs (by the world's most lit) and the boons that are verbs.
func debug_verbs() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var was_lit := lit.duplicate()
	lit = []
	flags.erase("most_lit")
	for b in ["book_ship", "book_longboat"]:
		flags.erase(b)
	var none: bool = not has_verb(1) and not has_verb(4)
	flags["most_lit"] = 6
	_verb_books()
	var books: bool = flags.has("book_ship") and flags.has("book_longboat") and _recipe_shown("longboat")
	var travel: bool = has_verb(4) and not has_verb(7)
	flags["most_lit"] = 9
	lit = was_lit
	# Bulwark: the first blow of the night is taken
	night = true
	bulwark_spent = false
	player.max_health = 1000.0
	player.health = 1000.0
	var foe_at := player.global_position + Vector3(3, 0, 0)
	damage_player(20.0, foe_at)
	var first_taken: bool = is_equal_approx(player.health, 1000.0) and bulwark_spent
	damage_player(20.0, foe_at)
	var second_lands: bool = player.health < 1000.0
	# Rallying Cry
	skills.boons.append("rally")
	player.stamina = 0.0
	var w0: float = player.walk_speed
	_w_rally(Net.me(), player.global_position)
	var rallied: bool = player.stamina >= player.stamina_max - 0.1 and player.walk_speed > w0
	# Lantern-bearer
	_w_bearer(Net.me(), true)
	var bearer: bool = near_bearer(player.global_position) and dread.rate(player.global_position + Vector3(0, 0, 5)) <= 0.0
	_w_bearer(Net.me(), false)
	# Second Relic: two spirits at once
	skills.boons.append("second_relic")
	skills.boons.append("deep_diver")
	var away := gpos(WPlaces.bpos(3))
	player.global_position = away + Vector3(0, 1, 0)
	await get_tree().create_timer(0.3).timeout
	spirits.spent.clear()
	var s1: bool = spirits.summon("spirit_ember")
	var s2: bool = spirits.summon("spirit_ash")
	await get_tree().create_timer(0.3).timeout
	var two: int = spirits.running()
	var diver: bool = player._boon("deep_diver")
	# Survey: there is a high place to survey from
	var high := false
	for k in 600:
		var a := k * 0.9
		var q := Vector3(cos(a), 0, sin(a)) * (200.0 + k * 4.0)
		if high_point(q):
			high = true
			break
	# Waystones: one end in a town; the waste and an isle do not link; cargo and riding are refused
	var town_p := gpos(WPlaces.spos("cinderwick")) + Vector3(4, 0, 4)
	var isle_p := Vector3.INF
	for il in terrain.isles:
		if not lights.houses.any(func(h): return h.lane == il.key):
			isle_p = gpos(terrain.isle_heart(il))
			break
	builder._rq_build(1, "portal", town_p, 0.0)
	builder._rq_build(1, "portal", town_p + Vector3(220, 0, 90), 0.0)
	builder._rq_build(1, "portal", town_p + Vector3(300, 0, -300), 0.0)
	builder._rq_build(1, "portal", isle_p, 0.0)
	await get_tree().create_timer(0.3).timeout
	var ws: Array = []
	for pid in pieces:
		if pieces[pid].kind == "portal":
			ws.append(pid)
	var n := ws.size()
	var linked: bool = waystone_why(ws[n - 4], ws[n - 3]) == ""
	var unanchored: bool = waystone_why(ws[n - 3], ws[n - 2]) != ""
	var cross: bool = waystone_why(ws[n - 4], ws[n - 1]) != ""
	inv.add("red_iron", 1)
	var ore: bool = waystone_carry_why() != ""
	inv.take("red_iron", inv.count("red_iron"))
	for f in WArms.FAR_STUFF + WAY_CARGO:
		inv.take(f, inv.count(f))
	var free: bool = waystone_carry_why() == ""
	print("VERBS none=%s books=%s travel=%s bulwark=%s second=%s rally=%s bearer=%s relics=%s/%s/%d diver=%s high=%s" % [none, books, travel, first_taken, second_lands, rallied, bearer, s1, s2, two, diver, high])
	for b in ["rally", "second_relic", "deep_diver"]:
		skills.boons.erase(b)   # leave the character as it was for the checks after
	spirits.spent.clear()
	print("WAYSTONES linked=%s unanchored=%s cross=%s ore=%s free=%s" % [linked, unanchored, cross, ore, free])
	get_tree().quit()


## Testing aid: a great one leaves something lasting: its named fittings every time, a book the first time only,
## and the Bell-Wound's trophy now has a power.
func debug_greatdrops() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var at := player.global_position + Vector3(4, 0, 0)
	var got := func() -> Dictionary:
		var out := {}
		for sid in containers:
			if str(sid).begins_with("s"):
				var bag := Inventory.new(30)
				bag.from_data(containers[sid])
				for it in ["fit_frost", "book_frost", "t_frost", "heart_frost"]:
					out[it] = int(out.get(it, 0)) + bag.count(it)
		return out
	flags.erase("felled_frost")
	_w_boss_down("boss_frost", at)
	await get_tree().create_timer(0.3).timeout
	var one: Dictionary = got.call()
	_w_boss_down("boss_frost", at)
	await get_tree().create_timer(0.3).timeout
	var two: Dictionary = got.call()
	var waste_book := great_book("ash")
	var g := WArms.roll_grade(1, null, "salt")
	var named: bool = int(g.r) == 3 and str(g.n) == "White Disc's" and "far" in g.t and g.t.size() == 3
	var gated: bool = not ui._arm_known("carbine") and ui._arm_known("shotgun") and not ui._tier_known(4) and ui._tier_known(3)
	flags["book_sun"] = true
	flags["book_quiet"] = true
	gated = gated and ui._arm_known("carbine") and ui._tier_known(4)
	# The Bell's Toll: the eighth blow that lands strikes twice as hard
	var e := spawn_at("rusher", player.global_position + Vector3(0, 1, 6))
	power = "t_kraken"
	power_left = 120.0
	Arms._toll = 0
	var drops: Array = []
	for i in 8:
		var h0: float = e.hp
		Arms.deal({e: 2.0}, Vector3.FORWARD)
		drops.append(h0 - e.hp)
	power = ""
	var toll: bool = is_equal_approx(float(drops[7]), float(drops[0]) * 2.0) and is_equal_approx(float(drops[6]), float(drops[0]))
	print("GREATDROPS fit=%d book=%d trophy=%d books_after_two=%d waste_book=%s named=%s gated=%s toll=%s power=%s" % [int(one.get("fit_frost", 0)), int(one.get("book_frost", 0)), int(one.get("t_frost", 0)), int(two.get("book_frost", 0)), waste_book.begins_with("book_"), named, gated, toll, Items.POWERS.has("t_kraken")])
	get_tree().quit()


## Testing aid: the far lands' stuff, Far-forged work, far plate and the three far arms.
func debug_farforged() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var shore: Vector3 = Vector3.INF
	for il in terrain.isles:
		if il.key == "steppe":
			shore = gpos(terrain.isle_heart(il))
	var finds: bool = far_find(shore) == "steppe_horn" and far_find(Vector3(40, 0, 40)) == "" and far_find_id("fs_frost_3") == "ice_iron" and far_find_id("isle_quiet") == "lens_glass" and far_find_id("vault_2") == ""
	var forged: bool = is_equal_approx(WArms.tier_mult(4), 1.6) and WArms.TIERS[4] == "Far-forged"
	var gc := WArms.tier_cost(4, "shotgun")
	var bc := WArms.tier_cost(4, "hatchet")
	var costs: bool = int(gc.get("dome_steel", 0)) == 3 and int(gc.get("lens_glass", 0)) == 2 and int(bc.get("ice_iron", 0)) == 3 and not gc.has("obsidian") and not WArms.tier_cost(3, "shotgun").has("dome_steel")
	var kept: int = int(WArms.clean({"tier": {"shotgun": 4, "pistol": 9}}).tier.get("shotgun", 0))
	var capped: int = int(WArms.clean({"tier": {"pistol": 9}}).tier.get("pistol", 0))
	var plate := WArms.worn({"wear": {"body": "far_plate"}})
	var plate_ok: bool = plate.speed == 1.0 and plate.weary == 1.0 and plate.warm >= 1.5 and float(WArms.WEAR.far_plate.plate) > float(WArms.WEAR.obsidian_plate.plate)
	var arms_ok := true
	for id in ["carbine", "hand_cannon", "war_pick"]:
		arms_ok = arms_ok and ArmsDB.far(id) and WArms.MAKE.has(id) and WArms.craft_k(id) == 2.5
		for kind in ["primary", "secondary", "melee"]:
			arms_ok = arms_ok and not id in ArmsDB.choices(kind)
	arms_ok = arms_ok and ArmsDB.look("carbine") == "machine_gun" and ArmsDB.look("shotgun") == "shotgun" and Items.AMMO.carbine == "rifle" and Items.AMMO.hand_cannon == "shells"
	var w: Arms = player.weapon
	var models := 0
	for g in ["carbine", "hand_cannon"]:
		var m := w._build(g, [])
		models += 1 if m.get_child_count() > 0 else 0
		m.free()
	var pick := w._build_melee("war_pick")
	models += 1 if pick != null else 0
	if pick:
		pick.free()
	var glyphs := 0
	for it in WArms.FAR_STUFF:
		glyphs += 1 if Items.DB.has(it) and int(Items.DB[it].stack) == 40 else 0
	print("FARFORGED finds=%s forged=%s costs=%s kept=%d capped=%d plate=%s arms=%s models=%d glyphs=%d" % [finds, forged, costs, kept, capped, plate_ok, arms_ok, models, glyphs])
	get_tree().quit()


func debug_turn() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var was_lit: Array = lit.duplicate()
	lit = range(5)
	flags.erase("turned")
	var before := turned()
	_the_turn()
	var col := _turn_col != null or kraken.spot == Vector3.INF
	var host := great_host()
	lit = was_lit
	print("TURN before=%s after=%s col=%s host=%s" % [before, turned(), col, host])
	var home := player.global_position
	var out := {}
	for il in terrain.isles:
		if not WIsles.THEMES[il.key].has("land"):
			continue
		var land: String = WIsles.THEMES[il.key].land
		var hc: Vector2 = terrain.isle_heart(il)
		player.place(gpos(hc + Vector2(60, 0)) + Vector3(0, 0.5, 0), 0.0)
		await get_tree().create_timer(1.0).timeout
		var at := land_at(player.global_position)
		arms.wear.erase("cloak")
		arms.wear.erase("hands")
		var h0 := player.health
		await get_tree().create_timer(6.0).timeout
		var bites := player.health < h0
		var was_lost := lost
		arms.wear[WARMS_SLOT.get(land, "cloak")] = LAND_WARD[land][0]
		h0 = player.health
		await get_tree().create_timer(6.0).timeout
		out[land] = [at == land, bites if land == "frost" else was_lost if land == "steppe" else true, player.health >= h0 and not lost]
		arms.wear.erase(WARMS_SLOT.get(land, "cloak"))
	player.place(home, 0.0)
	print("TURN lands frost=%s steppe=%s" % [out.get("frost", []), out.get("steppe", [])])
	get_tree().quit()

const WARMS_SLOT := {"frost": "cloak", "sun": "neck", "steppe": "hands"}


## Test: the Lighthouse chain. Two lights on each lane to a far place, on open water; a pilgrim can
## stand on the rock; oil poured and the hold kept lights one; both on a lane make it safe from the
## deep; the Kelp Forest slows a boat's way.
func debug_lights() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var wet := lights.houses.filter(func(h): return terrain.is_water(h.pos.x, h.pos.z, 6.0)).size()
	print("LIGHTS houses=%d lanes=%d wet=%d kelp=%s" % [lights.houses.size(), lights.lanes.size(), wet, lights.kelp != Vector3.INF])
	var h0: Dictionary = lights.houses[0]
	player.place(h0.pos + Vector3(0, 2.0, 3.5), 0.0)
	await get_tree().create_timer(2.0).timeout
	var stands: bool = player.global_position.y > WIsles.SEA_Y + 0.2
	inv.add("oil", WLights.OIL)
	lights._touched(0)
	await get_tree().create_timer(0.5).timeout
	var poured := inv.count("oil") == 0 and lights._holding.has(0)
	lights._holding[0] = 1.0
	lights.host_tick()
	await get_tree().create_timer(0.5).timeout
	var one := lights.lit(0)
	var lane: String = h0.lane
	var mid: Vector2 = lights.lanes[lane][0].lerp(lights.lanes[lane][1], 0.5)
	var half_safe := lights.lane_safe(Vector3(mid.x, 0, mid.y))
	for i in lights.houses.size():
		if lights.houses[i].lane == lane and i != 0:
			_w_house(i, true)
	await get_tree().create_timer(0.3).timeout
	var safe := lights.lane_safe(Vector3(mid.x, 0, mid.y))
	var kelp_in := lights.in_kelp(lights.kelp)
	for i in lights.houses.size():
		flags.erase("house_%d" % i)
	print("LIGHTS stands=%s poured=%s one=%s half_safe=%s safe=%s kelp_in=%s" % [stands, poured, one, half_safe, safe, kelp_in])
	get_tree().quit()


## Test: the five great ones of the far lands. Each has a lair on its own isle, on level dry ground;
## each wakes with its own name and a learnable loop, and leaves its trophy, whose power is known.
func debug_farlairs() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	var far := lairs.filter(func(l): return not WTerrain.BIOMES.has(str(l.land)))
	var level_ok := 0
	for l in far:
		if l.pos.y > WIsles.SEA_Y + 1.0 and terrain.normal_at(l.pos.x + 12.0, l.pos.z).y > 0.97 and terrain.normal_at(l.pos.x, l.pos.z - 12.0).y > 0.97:
			level_ok += 1
	var named := 0
	var trophies := 0
	for l in far:
		var b: String = l.boss
		var e := spawn_at(b, player.global_position + Vector3(0, 2, -20))
		if e and e.spec.name == LesserSpeeb.BOSSES[b].name and LesserSpeeb.PATTERNS.has(b):
			named += 1
		var t0 := inv.count("t_" + str(l.land))
		if e:
			e.die(false)
			_w_boss_down(b, player.global_position)
		await get_tree().create_timer(0.6).timeout
		if Items.POWERS.has("t_" + str(l.land)) and Items.DB.has("t_" + str(l.land)):
			trophies += 1
	print("FARLAIRS lairs=%d level=%d named=%d trophies=%d" % [far.size(), level_ok, named, trophies])
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
	# The coast is ragged, with bays: walk in from the open sea to the first dry ground
	var shore := dir2 * 1700.0
	for k in 1400:
		var q := dir2 * (1000.0 + k * 1.0)
		var wet := true
		for j in 6:
			var r := q + dir2 * j * 6.0
			if terrain.height_at(r.x, r.y) >= WIsles.SEA_Y + 0.6:
				wet = false
				break
		if wet:
			shore = q
			break
	# An earlier check in the same world may have left us riding or aboard
	if player.mount:
		dismount()
	if player.vessel != null and is_instance_valid(player.vessel):
		_leave_boat(player.vessel)
	_debug_room()
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
## Testing aid: the systems are shown as their land needs them. A new world has none; the clock hides
## the season until the seasons are reached; a stage is shown once and kept; an older world catches up.
func debug_stages() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	for k in STAGES:
		flags.erase("stage_" + k)
	var none := true
	for k in STAGES:
		none = none and not staged(k)
	var hid := weather.label(false).find(str(weather.season().name)) < 0 and weather.label(true).find(str(weather.season().name)) >= 0
	reach_stage("trades")
	await get_tree().create_timer(0.3).timeout
	var once := staged("trades") and not staged("seasons")
	_w_stage("trades")
	var d0 := day
	day = WWeather.SEASON_DAYS + 1
	_stages_catch_up()
	var caught := staged("seasons") and staged("dread")
	day = d0
	for k in STAGES:
		flags.erase("stage_" + k)
	print("STAGES none=%s hid=%s once=%s caught=%s" % [none, hid, once, caught])
	get_tree().quit()


## Testing aid: one music director in the waste, on its own Music line. Night asks for the night
## piece, a town for the town's, a great one near for its loop; a beacon's swell plays over all.
func debug_music() -> void:
	while not ready_world or music == null:
		await get_tree().create_timer(1.0).timeout
	var all := true
	for k in WMusic.PIECES:
		all = all and WMusic.stream_of(k) != null
	var bus := AudioServer.get_bus_index("Music") >= 0
	player.global_position = gpos(WPlaces.spos("cinderwick")) + Vector3(150, 1, 0)
	await get_tree().create_timer(0.2).timeout
	var n0 := night
	night = true
	var at_night := music.want()
	night = n0
	player.global_position = gpos(WPlaces.spos("cinderwick")) + Vector3(0, 1, 0)
	await get_tree().create_timer(0.2).timeout
	var in_town := music.want()
	var e := spawn_at("rusher", player.global_position + Vector3(6, 0.5, 0))
	e.boss = "test"
	var great := music.want()
	e.boss = ""
	e.die(false)
	music.beacon_swell()
	await get_tree().create_timer(1.5).timeout
	print("MUSIC all=%s bus=%s night=%s town=%s great=%s swell=%s old_loop=%s" % [all, bus, at_night, in_town, great, music.now == "swell", _music == null])
	get_tree().quit()


## Testing aid: a friend's guard, raised just now and facing the foe, turns its blow on the host's side;
## facing away, or raised long ago, it does not.
func debug_friendparry() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var c := Companion.new()
	c.peer_id = 77
	add_child(c)
	c.global_position = player.global_position + Vector3(30, 0, 0)
	c.set("_yaw", 0.0)   # looking toward -z
	var foe := c.global_position + Vector3(0, 0, -2)
	_w_guard_up(77)
	var turned_ok := friend_guarded(c, foe)
	var behind := not friend_guarded(c, c.global_position + Vector3(0, 0, 2))
	guard_up[77] = Time.get_ticks_msec() - 2000
	var stale := not friend_guarded(c, foe)
	c.queue_free()
	print("FRIENDPARRY turned=%s behind=%s stale=%s" % [turned_ok, behind, stale])
	get_tree().quit()


## Testing aid: two spend the same chest at once; the host finds it short and the late one pays from the pack.
func debug_spendshort() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var had := inv.count("scrap")
	inv.take("scrap", had)
	inv.add("scrap", 3)
	containers["test_short"] = [["scrap", 2], null, null]
	_rq_spend(Net.me(), ["test_short"], "scrap", 5)
	var emptied: bool = containers["test_short"][0] == null
	var paid := inv.count("scrap") == 0
	containers.erase("test_short")
	inv.add("scrap", had)
	print("SPENDSHORT emptied=%s paid=%s" % [emptied, paid])
	get_tree().quit()


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
	_debug_room(8)
	# Start from a fellowship that has read nothing (earlier checks may have read some)
	for bk in Items.LAND_BOOKS + Items.ISLE_BOOKS.values() + ["book_ship", "book_longboat"]:
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
	_debug_room()
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
	var wound := false
	for i in 240:
		await get_tree().create_timer(0.5).timeout
		var st: Dictionary = vaults.state.get(id, {})
		if vaults.built.has(id) and not st.is_empty():
			# Walk on to the next room once its gate is open
			var rm: Array = vaults.built[id].rooms[mini(int(st.room), rooms - 1)]
			if st.has("wind"):
				# Alone at one winch: the keeper's gate rises, slowly
				wound = true
				var wp: Vector3 = vaults.origin(id) + vaults.built[id].winches[0]
				if player.global_position.distance_to(wp + Vector3(0, 1.0, 0)) > 1.5:
					player.place(wp + Vector3(0.8, 1.0, 0), 0.0)
			elif player.global_position.distance_to(vaults.at(id, 0, 1.0, rm[0])) > 4.0:
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
	print("VAULT count=%d down=%s rooms=%d gates=%d cleared=%s share=%s up=%s sleeps=%s wound=%s" % [count, down, rooms, gates, cleared, share, up, sleeps, wound])
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
	_debug_room(14)
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
	_rq_bed_owner(Net.me(), 900, me)
	var mine := bed_owner(900) == me and bedroll is Vector3 and respawn_point().distance_to(bp) < 3.0
	var saved: bool = str(world_data().pieces[900][5].get("owner", "")) == me
	_rq_bed_owner(Net.me(), 900, "Wren")
	var given := bed_owner(900) == "Wren" and not bed_mine_or_free(900) and respawn_point().distance_to(bp) > 5.0
	pieces[900].owner = "Wren"
	_rq_bed_owner(99, 900, "")   # not Wren's, and not the host's own call: refused when online, so try as host
	_rq_bed_owner(Net.me(), 900, "")
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
	_debug_room(10)
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
	spirits.spent.clear()
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
	seed(2026)   # who comes at dawn is chance: the same chance every run
	settlers.host_dawn(1.0)
	settlers.host_dawn(1.0)
	settlers.host_dawn(1.0)
	var n := settlers.at_fire(fire).size()
	var shown := settlers._nodes.size()
	# Make sure one brings goods, then a dawn of work
	for st in settlers.list:
		st.job = "keeper"   # only the one below brings salt (another may have been a salter too)
		st.want = ["tar", 999]   # and none takes salt for a want
	settlers.list[0].job = "salter"
	var cid: String = settlers.chests_at(fire)[0]
	var before := _cont_count(cid, "salt")
	settlers.host_dawn(0.0)
	var brought := _cont_count(cid, "salt") - before
	# A want left in the chest is taken at dawn and paid for
	var taught := WSettlers.TEACHES.values().any(func(b): return flags.has(b))
	settlers.list[0].want = ["wood", 5]
	settlers._put([cid], "wood", 5)
	var wood0 := _cont_count(cid, "wood")
	settlers.host_dawn(0.0)
	var paid: bool = _cont_count(cid, "wood") == wood0 - 5 and settlers.list[0].want != ["wood", 5]
	var kept: Array = world_data().settlers
	settlers.from_data(JSON.parse_string(JSON.stringify(kept)))
	var reloaded := settlers.list.size() == n and settlers._nodes.size() == n
	pieces[fire].fuel = world_hours() - 1.0
	settlers.host_dawn(0.0)
	print("SETTLERS snug=%d room=%s came=%d shown=%d brought=%d reloaded=%s gone=%s taught=%s paid=%s" % [snug, room, n, shown, brought, reloaded, settlers.list.is_empty(), taught, paid])
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
		if spec_ok and (tinted or not LesserSpeeb.VARIANTS[v].has("tint")) and int(LesserSpeeb.FORM_TIER.get(v, 0)) > 0:
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
	print("KIN made=%d/%d copies=%d in_lands=%d bad=%s kinds=%d" % [ok, LesserSpeeb.VARIANTS.keys().filter(func(x): return LesserSpeeb.VARIANTS[x].base != "serpent").size(), copies, in_lands, bad, LesserSpeeb.KINDS.size() - 2 + LesserSpeeb.VARIANTS.size()])
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
	var was_lit := lit.duplicate()
	var hosts := []
	for n in [0, 4, 5, 7]:
		lit = range(n)
		hosts.append(great_host())
	lit = was_lit
	print("GREAT hosts=%s" % ",".join(hosts))
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
	_debug_room(8)
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
		if boats.is_empty():
			break   # no shore found here (this world's land lies otherwise)
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
	if not boats.is_empty():
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
		if OS.get_environment("WHY") != "":
			var why := {}
			for g in find_children("*", "GeometryInstance3D", true, false):
				var gi := g as GeometryInstance3D
				if gi.get_parent() == self or not gi.is_visible_in_tree() or gi.global_position.distance_to(c) > 150.0:
					continue
				var rs := []
				if gi is MeshInstance3D:
					var mm := gi as MeshInstance3D
					if mm.get_child_count() > 0: rs.append("kids")
					if mm.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: rs.append("shadowonly")
					if mm.transparency != 0.0: rs.append("transp")
					if mm.mesh is ImmediateMesh: rs.append("immediate")
				else:
					rs.append(gi.get_class())
				var q: Node = gi
				while q != self and q != null:
					if q.get_script() != null: rs.append("script:" + q.get_script().resource_path.get_file())
					for mk in q.get_meta_list():
						if mk == "body":
							var b = q.get_meta("body")
							if b is Object and is_instance_valid(b) and (b as Object).has_meta("on_interact"): rs.append("body_interact")
						else:
							rs.append("meta:" + str(mk))
					if q is Node3D and not (q as Node3D).visible: rs.append("hidden")
					q = q.get_parent()
				var kk := ",".join(rs)
				why[kk] = why.get(kk, 0) + 1
			for kk in why:
				print("DRAWWHY %s %d" % [kk, why[kk]])
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
	_debug_open()
	await get_tree().create_timer(0.5).timeout
	var cats: Array = []
	for i in 6:
		var c = _spawn_near("box_cat", player.global_position + Vector3(0, 0, -20), 1.0, 4.0, true)
		if c:
			cats.append(c)
	var d0: float = cats[0].global_position.distance_to(player.global_position)
	await get_tree().create_timer(2.0).timeout
	var d1: float = cats[0].global_position.distance_to(player.global_position) if is_instance_valid(cats[0]) else 0.0
	# Seen at its size: about a metre tall, not shrunk away to nothing
	var tall := 0.0
	if is_instance_valid(cats[0]) and cats[0]._box != null:
		for mi in cats[0]._box.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			tall = maxf(tall, ab.size.y)
	print("BOXCAT made=%d name=%s boxed=%s closed=%s hp=%.0f tall=%.2f" % [cats.size(), cats[0].spec.name, cats[0]._box != null, d1 < d0, cats[0].hp, tall])
	get_tree().quit()


## Testing aid: at a workbench, the Arms tab opens and the Make tab can be entered from it.
func debug_benchtabs() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	ui.debug_bench = true
	var start_tab := "arms"
	var click := "Make"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tab="):
			start_tab = a.substr(4)
		if a.begins_with("click="):
			click = a.substr(6)
	if "busy" in OS.get_cmdline_user_args():
		# The screen as in play: a long quest line, a word said, news, a banner, others in company
		hud.set_objective("Hunt the raiders who have been hosting in the Salt-Pan Caravans, north-west of Cinderwick.   3 / 10")
		hud.say("A long line of words said by someone nearby, to fill the middle of the screen for a while.", 20.0)
		hud.notify("Someone joined the fellowship.")
		hud.set_banner("A banner", "and its small line")
		hud.revelation("A deed", "Remembered, and then faded")
		await get_tree().create_timer(5.5).timeout
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
		if (b as Button).text == click and b.is_visible_in_tree():
			btn = b
			break
	var at := btn.get_global_rect().get_center() if btn else Vector2.ZERO
	var over: Array = []
	for c in get_tree().root.find_children("*", "Control", true, false):
		var cc := c as Control
		if cc.is_visible_in_tree() and cc.mouse_filter != Control.MOUSE_FILTER_IGNORE and cc.get_global_rect().has_point(at) and cc != btn:
			over.append("%s(%s)" % [cc.get_class(), cc.name])
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	get_viewport().push_input(mv, true)
	await get_tree().process_frame
	var hov = get_viewport().gui_get_hovered_control()
	var fr: Rect2 = ui._frame.get_global_rect()
	print("BENCHFRAME ", fr)
	var band := Rect2(fr.position.x, 90, fr.size.x, 90)   # where the tab row sits in play (the frame centred on a 900-high screen)
	var blockers := 0
	for c in get_tree().root.find_children("*", "Control", true, false):
		var cc := c as Control
		if cc.is_visible_in_tree() and cc.mouse_filter != Control.MOUSE_FILTER_IGNORE and cc.get_global_rect().intersects(band) and not ui._frame.is_ancestor_of(cc) and cc != ui._frame:
			blockers += 1
			var cl = cc.get_canvas_layer_node()
			print("BENCHBAND %s %s rect=%s layer=%s filter=%d idx=%d texts=%s" % [cc.get_class(), cc.get_path(), cc.get_global_rect(), str(cl.layer) if cl else "none", cc.mouse_filter, cc.get_parent().get_index(), cc.find_children("*", "Label", true, false).map(func(l): return l.text.left(30))])
	print("BENCHBLOCKERS n=%d" % blockers)
	print("BENCHCLICK button=%s at=%s over=%s hovered=%s" % [btn != null, at, over, (hov.get_class() + "(" + str(hov.get_path()) + ")") if hov else "none"])
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
	player.place(gpos(Vector2(beacon_nodes[0].pos.x + 4.0, beacon_nodes[0].pos.z)) + Vector3(0, 1.0, 0), 0.0)   # stood there when it caught
	await get_tree().physics_frame
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
	if cat == null:
		cat = WCat.new().setup(self, WCat.FACES[0], false)
		add_child(cat)
	skills.boon_offer = ["pack_cat"]
	skills.take_boon("pack_cat")
	var faster: bool = skills.speed_mult() > sp0
	var bigger: bool = skills.pack_size() == pk0 + 8
	var back := WSkills.new()
	back.from_data(skills.to_data())
	ui.close_all()
	print("BOONS gift=%s offered=%d opened=%s took=%s faster=%s bigger=%s kept=%s next=%s" % [gift, offered, opened, took, faster, bigger, back.boons.size() == skills.boons.size() and "pack_cat" in back.boons, next_shown])
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
## The trades of the others in the fellowship, by name, so What now can say whom to ask.
var trades_of := {}
var _gate_t := 1.0
var _trade_tell_t := 2.0


## Every so often each pilgrim tells the others their trade, so one who joins late learns them too.
func _trade_tell_tick(delta: float) -> void:
	if not Net.online:
		return
	_trade_tell_t -= delta
	if _trade_tell_t <= 0.0:
		_trade_tell_t = 20.0
		shared("_w_trade_of", [Net.me(), Net.my_name(), trades.trade])


func _w_trade_of(by: int, who: String, trade: String) -> void:
	if by == Net.me():
		return
	var nm := Net.name_of(by) if Net.players.has(by) else who
	if WTrades.TRADES.has(trade):
		trades_of[nm] = trade
	else:
		trades_of.erase(nm)


## What a friend's trade could give this pilgrim, as a What now goal, or {} if no one has it to give.
## Those who are no longer in the fellowship are not asked.
func trade_ask() -> Dictionary:
	var here := []
	for id in Net.players:
		here.append(str(Net.players[id].name))
	var asks := [
		["smith", "tempered", "The best blades and plate need it."],
		["tinker", "clockwork", "The great guns and the finer fittings need it."],
		["cook", "feast", "The best meal there is."],
		["alchemist", "elixir", "It heals, and ends burning and tar."],
	]
	for a in asks:
		if trades.is_(a[0]) or inv.count(a[1]) > 0:
			continue
		for nm in trades_of:
			if trades_of[nm] == a[0] and nm in here:
				var item := str(Items.info(a[1]).get("name", a[1]))
				return {"kind": "grow", "title": "Ask %s for %s" % [nm, item.to_lower()],
					"text": "%s is your %s. %s" % [nm, WTrades.TRADES[a[0]].name.to_lower(), a[2]], "at": null}
	return {}


# ------------------------------------------------------------------ squads

## A fellowship of many walks as squads of two to four. Pilgrims who keep together for half a minute
## fall into a squad; one who strays far from the rest of theirs for three minutes leaves it. Squadmates
## learn from each other's kills, and are shown first in the fellowship's list. The host decides.
const SQUAD_MAX := 4
const SQUAD_NEAR := 40.0      ## paces: walking together
const SQUAD_FORM := 30.0      ## seconds together before two fall in
const SQUAD_FAR := 150.0      ## paces: apart
const SQUAD_LEAVE := 180.0    ## seconds apart before one leaves
const SQUAD_STEP := 2.0
const SQUAD_SHARE := 0.5      ## of a kill's learning that reaches each squadmate near it
var squads := {}              ## peer -> squad number
var _squad_t := SQUAD_STEP
var _together := {}           ## host: "a:b" -> seconds near each other
var _apart := {}              ## host: peer -> seconds far from every squadmate
var _squad_next := 1


## One step of the host's reckoning, from where each pilgrim stands. Returns true if any squad changed.
func squads_step(pos: Dictionary, dt: float) -> bool:
	var changed := false
	for p in squads.keys():
		if not pos.has(p):
			squads.erase(p)
			changed = true
	var ids := pos.keys()
	ids.sort()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a = ids[i]
			var b = ids[j]
			var k := "%s:%s" % [a, b]
			if (pos[a] as Vector3).distance_to(pos[b]) < SQUAD_NEAR:
				_together[k] = float(_together.get(k, 0.0)) + dt
			else:
				_together.erase(k)
				continue
			if float(_together[k]) < SQUAD_FORM:
				continue
			var sa := int(squads.get(a, 0))
			var sb := int(squads.get(b, 0))
			if sa != 0 and sa == sb:
				continue
			if sa == 0 and sb == 0:
				squads[a] = _squad_next
				squads[b] = _squad_next
				_squad_next += 1
				changed = true
			elif sa == 0 and _squad_size(sb) < SQUAD_MAX:
				squads[a] = sb
				changed = true
			elif sb == 0 and _squad_size(sa) < SQUAD_MAX:
				squads[b] = sa
				changed = true
	# Strays leave
	for p in squads.keys():
		var near_any := false
		for q in squads:
			if q != p and squads[q] == squads[p] and (pos[p] as Vector3).distance_to(pos[q]) < SQUAD_FAR:
				near_any = true
				break
		if near_any:
			_apart.erase(p)
			continue
		_apart[p] = float(_apart.get(p, 0.0)) + dt
		if float(_apart[p]) >= SQUAD_LEAVE:
			squads.erase(p)
			_apart.erase(p)
			changed = true
	# A squad of one is no squad
	for p in squads.keys():
		if _squad_size(int(squads[p])) < 2:
			squads.erase(p)
			changed = true
	return changed


func _squad_size(sq: int) -> int:
	var n := 0
	for p in squads:
		if int(squads[p]) == sq:
			n += 1
	return n


## The others in this pilgrim's squad.
func squadmates(peer := -1) -> Array:
	if peer < 0:
		peer = Net.me()
	var sq := int(squads.get(peer, 0))
	if sq == 0:
		return []
	var out := []
	for p in squads:
		if p != peer and int(squads[p]) == sq:
			out.append(p)
	return out


func _w_squads(s: Dictionary) -> void:
	var before := squadmates()
	squads = s
	var now := squadmates()
	if Net.dedicated or now == before:
		return
	var names := now.map(func(p): return Net.name_of(p))
	if now.is_empty():
		hud.notify("You walk alone now.")
	elif before.is_empty():
		hud.notify("You walk with %s now. What one of you slays, the others learn from." % " and ".join(names))
	else:
		hud.notify("Your squad: %s." % ", ".join(names))


## A squadmate's kill: those of the squad within reach learn from it too.
func _w_squad_kill(by: int, kind: String, at: Vector3) -> void:
	if by == Net.me() or Net.dedicated or not by in squadmates():
		return
	if is_instance_valid(player) and player.global_position.distance_to(at) < SQUAD_FAR:
		award(kind, SQUAD_SHARE)


## Shown after a name in the fellowship's list.
func squad_tag(id: int) -> String:
	return "squad" if id in squadmates() else ""


## What a settler at the base this pilgrim stands in asks for, or "".
func settler_ask() -> String:
	var b := base_at(player.global_position, 20.0, true) if is_instance_valid(player) else -1
	if b < 0:
		return ""
	for s in settlers.list:
		if int(s.fire) == b:
			var t := WSettlers.want_text(s)
			if t != "":
				return t
	return ""


# ------------------------------------------------------------------ the roads about each town

## Each town knows how safe its roads are, from 0 to 100. Foes slain near it, bands put down and raid
## camps broken make it safer; days pass and it slips back, faster while a raid camp stands near. Its
## folk remember who did it: every ten points a pilgrim earns there is one more step of standing (better
## prices, and they greet you warmly). Safe roads bring fewer fights near the town; dangerous ones, more.
const SAFETY_START := 40
const SAFETY_REACH := 500.0   ## paces from a town's heart that count as its roads
const SAFETY_KILL := 1
const SAFETY_ELITE := 3
const SAFETY_BAND := 5
const SAFETY_CAMP := 15
const SAFETY_DECAY := 3       ## a day: roads not kept slip back
const SAFETY_FLED := 6        ## a band left alone digs in
const SAFETY_CAMP_DECAY := 8  ## a day, for each raid camp standing near
const DEED_STEP := 10         ## safety earned for one more step of standing
var safety := {}              ## town -> 0..100
var deeds := {}               ## town -> {name: points not yet counted toward standing}
var gates := {}               ## town -> [{leaf, body, knock}]
var gates_shut := {}          ## town -> true while barred
var _gate_open_t := {}        ## "town:i" -> seconds a gate stands open for a known pilgrim
const SAFETY_WORDS := [[90, "Peaceful"], [60, "Safe"], [25, "Uneasy"], [0, "Dangerous"]]


func safety_of(town: String) -> int:
	return int(safety.get(town, SAFETY_START))


static func safety_word(v: int) -> String:
	for sw in SAFETY_WORDS:
		if v >= int(sw[0]):
			return str(sw[1])
	return "Dangerous"


## The town whose roads this place is on, or "".
func town_near(p: Vector3, reach: float) -> String:
	var best := ""
	var bd := reach
	for k in WPlaces.SETTLEMENTS:
		var d := Vector2(p.x, p.z).distance_to(WPlaces.spos(k))
		if d < bd:
			bd = d
			best = k
	return best


## A deed on a town's roads: safer roads, and the folk remember who.
func _w_safety(town: String, amount: int, who: String) -> void:
	if not WPlaces.SETTLEMENTS.has(town):
		return
	var before := safety_of(town)
	safety[town] = clampi(before + amount, 0, 100)
	if before >= 25 and safety_of(town) < 25:
		_w_stage("standing")
	if before >= 25 and safety_of(town) < 25 and not Net.dedicated and visited.has(town):
		hud.alert_banner("A plea from %s" % WPlaces.SETTLEMENTS[town].name, "Its roads have gone dangerous. Its gates will be barred at night, and its traders ask more.")
	if amount <= 0 or who == "":
		return
	var dd: Dictionary = deeds.get(town, {})
	dd[who] = int(dd.get(who, 0)) + amount
	var up := 0
	while int(dd[who]) >= DEED_STEP:
		dd[who] = int(dd[who]) - DEED_STEP
		up += 1
	deeds[town] = dd
	if up > 0:
		var rb := int(rep.get(town, 0))
		rep[town] = rb + up
		if who == Net.my_name() and not Net.dedicated:
			hud.notify("Word reaches %s of what you have done on its roads. Its folk think better of you." % WPlaces.SETTLEMENTS[town].name)
			_honour_check(town, rb)
	if not Net.dedicated and safety_word(before) != safety_word(safety_of(town)) and safety_of(town) > before:
		hud.notify("The roads about %s are %s now." % [WPlaces.SETTLEMENTS[town].name, safety_word(safety_of(town)).to_lower()])


## Each dawn the roads slip back a little, and more where raid camps stand near: keeping a town safe
## means going out and clearing its roads.
func _safety_dawn() -> void:
	if not Net.authority():
		return   # the host keeps the count, and tells everyone, so a late joiner's towns agree with it
	for k in WPlaces.SETTLEMENTS:
		var drop := SAFETY_DECAY
		if events:
			for id in events.active:
				var e: Dictionary = events.active[id]
				if e.kind == "camp" and Vector2(e.pos.x, e.pos.z).distance_to(WPlaces.spos(k)) < SAFETY_REACH + 100.0:
					drop += SAFETY_CAMP_DECAY
		safety[k] = maxi(0, safety_of(k) - drop)
	if Net.online:
		shared("_w_safety_all", [safety.duplicate()])


func _w_safety_all(d: Dictionary) -> void:
	if not Net.authority():
		safety = d.duplicate()


# ---- what safe and dangerous roads mean

const DANGER_PRICE := 1.25    ## at Dangerous, traders ask more
const HONOUR_FRIEND := 5      ## standing for a title, and a free bed at the inn
const HONOUR_BED := 5
const HONOUR_GIFT := 8        ## standing for the town's gift, once
const HONOUR_WARDEN := 12
const BOUNTY_COIN := 6
const BOUNTY_REP := 2

## What a town calls one who has done well by it, or "".
func honour_title(k: String) -> String:
	var st := int(rep.get(k, 0))
	if not WPlaces.SETTLEMENTS.has(k):
		return ""
	if st >= HONOUR_WARDEN:
		return "Warden of %s" % WPlaces.SETTLEMENTS[k].name
	if st >= HONOUR_FRIEND:
		return "Friend of %s" % WPlaces.SETTLEMENTS[k].name
	return ""


## Said when standing in a town crosses a step of honour; the gift is given once.
func _honour_check(k: String, before: int) -> void:
	var st := int(rep.get(k, 0))
	if Net.dedicated or st <= before:
		return
	var nm: String = WPlaces.SETTLEMENTS[k].name
	if before < HONOUR_FRIEND and st >= HONOUR_FRIEND:
		hud.title_card("Friend of %s" % nm, "Its inn's beds are yours, free")
	if before < HONOUR_GIFT and st >= HONOUR_GIFT and not flags.has("honour_gift_" + k):
		flags["honour_gift_" + k] = true
		shared("_w_flag", ["honour_gift_" + k])   # the whole fellowship's world keeps that it was given
		give([["fittings_rare", 1], ["coin", 10]])
		hud.notify("The folk of %s send you a gift for what you have done for them: a rare fitting and ten coin." % nm)
	if before < HONOUR_WARDEN and st >= HONOUR_WARDEN:
		hud.title_card("Warden of %s" % nm, "Its roads are yours to keep")


## Traders at a town with safe roads have more to sell: things that come only by road from far off.
const SAFE_STOCK := {
	"trader": ["salve", "fittings_fine"], "smith": ["tempered", "clockwork", "fittings_rare"],
	"quartermaster": ["rockets", "fittings_fine"], "healer": ["elixir"], "oilwright": ["tar"],
}

func stock_at(role: String, k: String) -> Array:
	var out: Array = Items.STOCK.get(role, []).duplicate()
	if WPlaces.SETTLEMENTS.has(k) and safety_of(k) >= 60:
		for id in SAFE_STOCK.get(role, []):
			if Items.DB.has(id) and not id in out:
				out.append(id)
	return out


## What a town's traders ask, against the usual, by how safe its roads are.
func price_mult_at(k: String) -> float:
	return (DANGER_PRICE if WPlaces.SETTLEMENTS.has(k) and safety_of(k) < 25 else 1.0) * (FEAST_PRICE if k == feast_town(day) else 1.0)


# ------------------------------------------------------------------ feast days

## Every fifth day one town keeps a feast: by day its traders sell cheaper, and each pilgrim who comes is
## fed and given a little salt. Feasts go on after any ending (gameplay bible: the world after stays alive).
const FEAST_EVERY := 5
const FEAST_PRICE := 0.8
var _feasted_day := -1

func feast_town(d: int) -> String:
	if d < 2 or d % FEAST_EVERY != 2:
		return ""
	var towns: Array = WPlaces.SETTLEMENTS.keys().filter(func(k): return not WPlaces.SETTLEMENTS[k].get("isle", false))
	if towns.is_empty():
		return ""
	towns.sort()
	return str(towns[absi(hash(world_seed + d * 31)) % towns.size()])


func _feast_tick() -> void:
	var t := feast_town(day)
	if t == "" or night or _feasted_day == day or Net.dedicated:
		return
	if settlement_at(player.global_position) == t:
		_feasted_day = day
		give([["feast", 1], ["salt", 30]])
		sfx("choir", -10, null, 1.2)
		hud.notify("A feast day in %s. You are fed, and given salt; the traders sell cheaper today." % WPlaces.SETTLEMENTS[t].name)


## Everyone, every couple of seconds: gates barred at night where the roads are dangerous.
func _gates_tick(delta: float) -> void:
	for key in _gate_open_t.keys():
		_gate_open_t[key] = float(_gate_open_t[key]) - delta
		if float(_gate_open_t[key]) <= 0.0:
			_gate_open_t.erase(key)
	for k in gates:
		var shut: bool = night and safety_of(k) < 25
		gates_shut[k] = shut
		for i in (gates[k] as Array).size():
			var g: Dictionary = gates[k][i]
			var closed: bool = shut and not _gate_open_t.has("%s:%d" % [k, i])
			if is_instance_valid(g.leaf):
				g.leaf.visible = closed
			if g.body is CollisionObject3D and is_instance_valid(g.body):
				g.body.collision_layer = 1 if closed else 0
			if is_instance_valid(g.knock):
				g.knock.set_meta("prompt", "Knock at the gate" if closed else "")


## Knocking at a barred gate: the watch opens to one they know (standing 2 or more), not to strangers.
func _knock(k: String, i: int) -> void:
	if not gates_shut.get(k, false):
		return
	sfx("thud", -4, null, 0.8)
	if int(rep.get(k, 0)) >= 2:
		_gate_open_t["%s:%d" % [k, i]] = 8.0
		hud.notify("\"It's you. Quick, in.\" The bar is lifted.")
	else:
		hud.notify("\"Not at night, not with the roads as they are.\" The gate stays shut. Clear the roads, or come back at dawn.")


## Rival towns: a town whose roads rot beside a neighbour's safe ones grumbles at those who keep the
## neighbour and not it, now and then.
func _rivals_dawn() -> void:
	for k in WPlaces.SETTLEMENTS:
		if safety_of(k) > 25:
			continue
		var nb := ""
		var nd := INF
		for o in WPlaces.SETTLEMENTS:
			if o != k and WPlaces.spos(o).distance_to(WPlaces.spos(k)) < nd:
				nd = WPlaces.spos(o).distance_to(WPlaces.spos(k))
				nb = o
		if nb == "" or safety_of(nb) < 60 or day - int(flags.get("grumble_" + k, -99)) < 3:
			continue
		if int(rep.get(k, 0)) <= 0:
			continue
		flags["grumble_" + k] = day
		rep[k] = int(rep.get(k, 0)) - 1
		if not Net.dedicated and int(rep.get(nb, 0)) > 0:
			hud.notify("The folk of %s grumble that you keep the roads of %s and not theirs." % [WPlaces.SETTLEMENTS[k].name, WPlaces.SETTLEMENTS[nb].name])


## Two towns with safe roads near this place, between which a trade caravan may run: [a, b] (2D), or [].
func convoy_route(from: Vector3) -> Array:
	var safe := []
	for k in WPlaces.SETTLEMENTS:
		if safety_of(k) >= 60 and not WPlaces.on_shore(k):   # a caravan does not walk over the sea
			safe.append(k)
	var best := []
	var bd := 700.0
	for i in safe.size():
		for j in range(i + 1, safe.size()):
			var a: Vector2 = WPlaces.spos(safe[i])
			var b: Vector2 = WPlaces.spos(safe[j])
			if a.distance_to(b) > 2200.0:
				continue
			var q := Geometry2D.get_closest_point_to_segment(Vector2(from.x, from.z), a, b)
			var d := q.distance_to(Vector2(from.x, from.z))
			if d < bd:
				bd = d
				best = [a, b]
	return best


## The two towns a caravan at this place runs between: the two nearest.
func convoy_towns(p: Vector3) -> Array:
	var ks := WPlaces.SETTLEMENTS.keys()
	ks.sort_custom(func(a, b): return WPlaces.spos(a).distance_to(Vector2(p.x, p.z)) < WPlaces.spos(b).distance_to(Vector2(p.x, p.z)))
	return ks.slice(0, 2)


## Robbing a trade caravan: its goods, twice over, to the robber; both its towns hear of it.
func _rq_rob(by: int, id: int) -> void:
	if not Net.authority() or not events or not events.active.has(id) or events.active[id].kind != "convoy":
		return
	var at: Vector3 = events.active[id].pos
	for f in events.active[id].get("foes", []):
		if is_instance_valid(f) and f.is_alive():
			f.die(false)
	shared("_w_robbed", [by, at])
	shared("_w_event_end", [id, false, -2])


func _w_robbed(by: int, at: Vector3) -> void:
	for tn in convoy_towns(at):
		safety[tn] = maxi(0, safety_of(tn) - 10)
		rep[tn] = maxi(0, int(rep.get(tn, 0)) - 3)
	if by == Net.me() and not Net.dedicated:
		var r := RandomNumberGenerator.new()
		r.randomize()
		give(Items.roll("caravan", 6, r) + [["coin", r.randi_range(6, 12)]])
		hud.notify("You take what the caravan carried. %s and %s will hear of it." % [WPlaces.SETTLEMENTS[convoy_towns(at)[0]].name, WPlaces.SETTLEMENTS[convoy_towns(at)[1]].name])


## The plea of a town whose roads have gone dangerous, for What now, or {}.
func town_plea(me: Vector3) -> Dictionary:
	var best := {}
	var bd := 1500.0
	for k in WPlaces.SETTLEMENTS:
		if not visited.has(k) or safety_of(k) >= 25:
			continue
		var p := gpos(WPlaces.spos(k))
		if p.distance_to(me) < bd:
			bd = p.distance_to(me)
			best = {"kind": "near", "title": "A plea from %s" % WPlaces.SETTLEMENTS[k].name, "text": "Its roads are dangerous (%d). Slay what prowls near it, and break the camps about it." % safety_of(k), "at": p}
	return best


## A raid camp broken near a town pays its bounty: coin to those who broke it, and standing.
func _bounty(tn: String, at: Vector3, by: int) -> void:
	var before := int(rep.get(tn, 0))
	rep[tn] = before + BOUNTY_REP
	if Net.dedicated:
		return
	if player.global_position.distance_to(at) < 120.0 or by == Net.me():
		give([["coin", BOUNTY_COIN]])
		hud.notify("%s's bounty on the raid camp is paid: %d coin, and its folk's thanks." % [WPlaces.SETTLEMENTS[tn].name, BOUNTY_COIN])
	_honour_check(tn, before)


## The bounty a town has posted: the raid camp standing nearest it, or {}.
func bounty_of(k: String) -> Dictionary:
	if not events:
		return {}
	var best := {}
	var bd := SAFETY_REACH + 300.0
	for id in events.active:
		var e: Dictionary = events.active[id]
		var d := Vector2(e.pos.x, e.pos.z).distance_to(WPlaces.spos(k))
		if e.kind == "camp" and d < bd:
			bd = d
			best = e
	return best


# ---- militia: at Peaceful, the town's watch walks its roads and shoots what comes near

const MILITIA_AT := 90
const MILITIA_N := 2
const MILITIA_SHOT := 16.0
const MILITIA_RANGE := 35.0
var militia: Array = []       ## everyone: {town, node, t}

func _militia_tick(delta: float) -> void:
	for m in militia.duplicate():
		if not is_instance_valid(m.node) or safety_of(m.town) < MILITIA_AT - 10:
			if is_instance_valid(m.node):
				m.node.queue_free()
			militia.erase(m)
	for k in WPlaces.SETTLEMENTS:
		if safety_of(k) < MILITIA_AT:
			continue
		var have := militia.filter(func(m): return m.town == k).size()
		for slot in range(have, MILITIA_N):
			_militia_add(k, slot)
	# The host's watch shoots
	_militia_shoot(delta)


func _militia_add(k: String, have: int) -> void:
	var a := float(hash(k + str(have))) / 1000.0
	var at := gpos(WPlaces.spos(k) + Vector2(cos(a), sin(a)) * 140.0)
	var f := WTownsfolk.new().setup(self, at, 40.0, hash(k) + have)
	f.lines = ["The watch of %s. The roads are safe while we walk them." % WPlaces.SETTLEMENTS[k].name, "We shoot what comes near. Mind you don't."]
	add_child(f)
	f.global_position = at
	militia.append({"town": k, "node": f, "t": 0.0})


func _militia_shoot(delta: float) -> void:
	if not Net.authority():
		return
	for m in militia:
		m.t = float(m.t) - delta
		if float(m.t) > 0.0 or not is_instance_valid(m.node):
			continue
		m.t = 1.3
		var mp: Vector3 = m.node.global_position + Vector3(0, 1.5, 0)
		for e in enemies:
			if is_instance_valid(e) and e.is_alive() and not e.puppet and e.global_position.distance_to(mp) < MILITIA_RANGE:
				var was := [LesserSpeeb.harm_kind, LesserSpeeb.harm_head]
				LesserSpeeb.harm_kind = "bullet"
				LesserSpeeb.harm_head = false
				e.hurt(MILITIA_SHOT, (e.global_position - mp).normalized())
				LesserSpeeb.harm_kind = was[0]
				LesserSpeeb.harm_head = was[1]
				sfx("pistol", -8, mp)
				break


## The host keeps the bands met on the roads: one put down makes the nearest town's roads safer; one
## left alone for eight minutes, with no one near, digs in as a raid camp.
const BAND_DIG := 480.0
var road_bands: Array = []    ## host: {pos, foes, age}
var _band_t := 10.0

func _track_band(at: Vector3, made: Array) -> void:
	if not Net.authority():
		return
	var foes := made.filter(func(f): return f != null and is_instance_valid(f))
	if foes.is_empty():
		return
	var b := {"pos": at, "foes": foes, "age": 0.0, "slain": 0}
	road_bands.append(b)
	# Whether each one leaves the world put down (no health left) or only faded away far from everyone
	for f in foes:
		f.tree_exiting.connect(func():
			if f.hp <= 0.0:
				b.slain = int(b.slain) + 1)


func _bands_tick(step := 10.0) -> void:
	for b in road_bands.duplicate():
		b.age = float(b.age) + step
		var alive := (b.foes as Array).filter(func(f): return is_instance_valid(f) and f.is_alive())
		var watched := false
		for t in targets():
			if t.global_position.distance_to(b.pos) < 150.0:
				watched = true
		# All gone: put down if any of them was slain; otherwise they only faded, far from everyone
		if alive.is_empty() and int(b.slain) > 0:
			road_bands.erase(b)
			var tn := town_near(b.pos, SAFETY_REACH)
			if tn != "":
				# Credited to whoever is nearest: they put it down
				var who := ""
				var wd := 400.0
				for id in Net.players if Net.online else [Net.me()]:
					var at = player.global_position if id == Net.me() and not Net.dedicated else (avatars[id].global_position if avatars.has(id) and is_instance_valid(avatars[id]) else null)
					if at != null and (at as Vector3).distance_to(b.pos) < wd:
						wd = (at as Vector3).distance_to(b.pos)
						who = Net.name_of(id) if Net.online else Net.my_name()
				shared("_w_safety", [tn, SAFETY_BAND, who])
			continue
		if watched or (float(b.age) < BAND_DIG and not alive.is_empty()):
			continue
		road_bands.erase(b)
		for f in alive:
			f.die(false)
		# Left alone (or run from), the band digs in, and the town's roads are the worse for it
		var tn2 := town_near(b.pos, SAFETY_REACH + 200.0)
		if tn2 != "":
			shared("_w_safety", [tn2, -SAFETY_FLED, ""])
		if events:
			events._dig_in(b.pos)


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
			var hint := quests.next_hint(main_q)
			if hint.begins_with(WQuests.KEY_HINT) and turned():
				txt += " The bowl is fouled: " + hint.trim_prefix(WQuests.KEY_HINT)
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
	var plea := town_plea(me)
	if not plea.is_empty() and (plea.at as Vector3).distance_to(me) < nd:
		nd = (plea.at as Vector3).distance_to(me)
		near = plea
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
	elif not trade_ask().is_empty():
		grow = trade_ask()
	elif settler_ask() != "":
		grow = {"kind": "grow", "title": "A settler asks", "text": settler_ask(), "at": null}
	elif skills.points > 0:
		grow = {"kind": "grow", "title": "%d skill point%s to spend" % [skills.points, "" if skills.points == 1 else "s"], "text": "Press %s to learn something." % Game.key_text("skills"), "at": null}
	else:
		var best := ""
		var lv := 999
		for g in ArmsDB.GUNS:
			if ArmsDB.far(g):
				continue   # the far arms come of the far lands' stuff, not of a level
			var u := int(ArmsDB.GUNS[g].get("unlock", 1))
			if u > skills.level and u < lv:
				lv = u
				best = g
		if best != "":
			grow = {"kind": "grow", "title": "Level %d: the %s" % [lv, ArmsDB.GUNS[best].name], "text": "%d experience to the next level. Kindle beacons, finish tasks and kill enemies." % maxi(0, WSkills.need(skills.level) - skills.xp), "at": null}
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
	skills.boon_offer = ["fleet", "pack_cat", "salvager"]
	var boon_first: bool = what_now()[2].title == "A beacon boon waits"
	print("WHATNOW n=%d kinds=%s road_at=%s shown=%s boon=%s first=%s" % [g.size(), ",".join(kinds), g[0].at is Vector3, shown, boon_first, g[0].text.left(40)])
	get_tree().quit()


## Testing aid: a long beacon step names the small next thing, and points the way to it.
func debug_subgoal() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	_debug_room(8)
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
	await _debug_home()
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


## Testing aid: a pilgrim walks straight over a house's rug and is not stopped by it.
func debug_rugwalk() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var base: Vector3 = player.global_position + Vector3(0, 60, 0)
	var n := Node3D.new()
	add_child(n)
	n.global_position = base
	var fb := StaticBody3D.new()
	n.add_child(fb)
	builder._part(n, fb, Vector3(12, 1.0, 12), Vector3(0, -0.5, 0), _m.stone, false)
	_furnish(n, "rug", Vector3(0, 0.02, 0), 0.0)
	player.place(base + Vector3(0, 0.3, 4.0), 0.0)
	player.yaw = 0.0
	player.rotation.y = 0.0
	await get_tree().create_timer(0.5).timeout
	Input.action_press("move_forward")
	var t := 0.0
	var crossed := false
	while t < 4.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if player.global_position.z < base.z - 2.5:
			crossed = true
			break
	Input.action_release("move_forward")
	print("RUGWALK crossed=%s z=%.1f" % [crossed, player.global_position.z - base.z])
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


## Testing aid: one Escape closes exactly one layer, whatever is open (the pack, the map, building,
## the settings over the menu, the menu).
func _esc_once() -> void:
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


func debug_escape_all() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(1.0).timeout
	var out := []
	ui.open_inventory("pack")
	await get_tree().process_frame
	await _esc_once()
	out.append("pack=%s" % [ui._panel == null and not hud.pause_panel.visible])
	ui.open_map()
	await get_tree().process_frame
	await _esc_once()
	out.append("map=%s" % [ui._panel == null and not hud.pause_panel.visible])
	builder.toggle()
	await get_tree().process_frame
	await _esc_once()
	out.append("build=%s" % [not builder.active and not hud.pause_panel.visible])
	await _esc_once()
	var menu: bool = hud.pause_panel.visible
	hud.show_options()
	await get_tree().process_frame
	await _esc_once()
	out.append("menu=%s options=%s" % [menu, not hud.options_panel.visible and hud.pause_panel.visible])
	await _esc_once()
	out.append("closed=%s" % [not hud.pause_panel.visible and not get_tree().paused])
	print("ESCAPEALL " + " ".join(out))
	get_tree().quit()


## Testing aid: a rocket falls as it flies, and points along its path.
func debug_rocketdrop() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var r := Arms.Rocket.new()
	r.shown_only = true
	r.vel = Vector3(38, 0, 0)
	add_child(r)
	var start := player.global_position + Vector3(0, 300, 0)
	r.global_position = start
	for i in Engine.physics_ticks_per_second:   # one second of its flight, however slow the machine
		await get_tree().physics_frame
	var fell: float = start.y - r.global_position.y if is_instance_valid(r) else -1.0
	var nose: float = (-r.global_transform.basis.z).y if is_instance_valid(r) else 0.0
	print("ROCKETDROP fell=%.2f nose_down=%s" % [fell, nose < -0.02])
	get_tree().quit()


## Test: rounds past the near reach fall, a light pistol round more than a heavy rifle one; and the rocket
## launcher's rear hole and front hood sit on the eye's line down the sights.
func debug_bulletdrop() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var fell := {}
	for g in ["pistol", "sniper"]:
		var b := Arms.Slug.new()
		b.gun_id = g
		b.dir = Vector3(1, 0, 0)
		b.speed = float(Arms.MUZZLE[g])
		b.grav = Arms.GRAVITY * float(Arms.CALIBER[g][1])
		b.left = 10000.0
		var start: Vector3 = player.global_position + Vector3(0, 400, 0)
		b.origin = start
		add_child(b)
		b.global_position = start
		for i in 30:
			await get_tree().physics_frame
		fell[g] = start.y - b.global_position.y
		b.queue_free()
	var n: Node3D = player.weapon._build("rocket", [])
	var tr := Transform3D(Basis.from_euler(n.get_meta("eye_rot")), Vector3(float(n.get_meta("eye_x")), -float(n.get_meta("eye")), float(n.get_meta("eye_z"))))
	var lined := true
	for pt in Arms.SIGHT_LINE["rocket"].slice(0, 2):
		var c: Vector3 = tr * (pt as Vector3)
		lined = lined and absf(c.x) < 0.0005 and absf(c.y) < 0.0005 and c.z < -0.05
	n.free()
	print("BULLETDROP pistol=%.2f sniper=%.2f heavier_holds=%s sights=%s" % [fell.pistol, fell.sniper, fell.pistol > fell.sniper and fell.sniper > 0.05, lined])
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
	await _debug_home()
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


## Testing aid: a figure is drawn in a handful of meshes, not thirty.
func debug_figjoin() -> void:
	var most := 0
	for i in 12:
		var f := Figure.new().setup(Figure.townsman(i * 977 + 5, "cinderwick") if i % 2 == 0 else Figure.seeded(i * 31 + 2))
		add_child(f)
		most = maxi(most, f.find_children("*", "MeshInstance3D", true, false).size())
		f.free()
	print("FIGJOIN few=%s" % (most <= 14))
	get_tree().quit()


## Testing aid: the Low preset shortens the shadows and drops the glow; Standard puts them back.
func debug_gfx() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	var q0: int = Game.quality
	Game.quality = 0
	apply_quality()
	var low: bool = sun.directional_shadow_max_distance <= 45.0 and not env.glow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	Game.quality = 1
	apply_quality()
	var back: bool = sun.directional_shadow_max_distance == 90.0 and env.glow_enabled and not env.ssao_enabled
	Game.quality = 2
	apply_quality()
	var high: bool = env.ssao_enabled and sun.directional_shadow_max_distance == 90.0
	Game.quality = q0
	apply_quality()
	Game.render_scale = 2
	Game.apply_display()
	var scaled: bool = get_viewport().scaling_3d_scale < 0.75 and get_viewport().scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR
	Game.render_scale = 0
	Game.apply_display()
	print("GFX low=%s back=%s high=%s scaled=%s" % [low, back, high, scaled])
	get_tree().quit()


## Testing aid: at the largest menu size, the pack and every tab still fit on the screen.
func debug_uiscale() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	Game.ui_scale = Game.UI_SCALES.size() - 1
	Game.apply_display()
	await get_tree().process_frame
	# A 16:9 screen at this size (a headless window is square, so the height is taken from the width)
	var vr := get_viewport().get_visible_rect()
	var vp := Rect2(Vector2.ZERO, Vector2(vr.size.x, vr.size.x * 9.0 / 16.0))
	var bigger: bool = vr.size.x < 1599.0
	var fit := true
	for tab in ["pack", "craft", "arms", "wear", "build"]:
		ui.close_all()
		ui.open_inventory(tab)
		await get_tree().process_frame
		await get_tree().process_frame
		var r: Rect2 = ui._frame.get_global_rect()
		if r.size.x > vp.size.x + 1.0 or r.size.y > vp.size.y + 1.0:
			fit = false
			print("UISCALE out %s %s in %s" % [tab, r, vp])
	ui.close_all()
	hud.show_options()
	await get_tree().process_frame
	Game.ui_scale = 1
	Game.apply_display()
	print("UISCALE bigger=%s fit=%s" % [bigger, fit])
	get_tree().quit()


## Testing aid: Settings for all: a press-to-switch sprint, subtitles for spoken lines, colour-blind safety colours.
func debug_access() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	Game.toggles["run"] = true
	var ev := InputEventAction.new()
	ev.action = "run"
	ev.pressed = true
	Game._input(ev)
	var on: bool = Game.held("run")
	Game._input(ev)
	var off: bool = not Game.held("run")
	Game._input(ev)
	Game.untoggle("run")
	var ended: bool = not Game.held("run")
	Game.toggles["run"] = false
	Game.subtitles = true
	Game.voice_lines = true
	kill_line()
	var sub: bool = hud.subtitle_l.text.begins_with("Brelm: ") and hud.subtitle_l.modulate.a > 0.9
	Game.subtitles = false
	var plain: Color = Game.safety_tint(10.0)
	Game.colorblind = true
	var cb: Color = Game.safety_tint(10.0)
	var cb_safe: Color = Game.safety_tint(70.0)
	Game.colorblind = false
	print("ACCESS toggle=%s/%s/%s sub=%s cb=%s" % [on, off, ended, sub, plain != cb and cb_safe.b > cb_safe.g])
	get_tree().quit()


func debug_reports() -> void:
	var p := "user://test_report.log"
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("Godot Engine v4.3\nSCRIPT ERROR: Invalid access to property 'x' on null.\n   at: _tick (res://scripts/enemy.gd:12)\nSCRIPT ERROR: Invalid access to property 'x' on null.\n   at: _tick (res://scripts/enemy.gd:12)\nERROR: Parameter \"m\" is null.\n   at: mesh_get (x.cpp:1)\nplayer Steve joined\n")
	f.close()
	var r := Game.ErrorReport.gather(p, false)
	var found: bool = r.get("kind", "") == "error" and "enemy.gd:12" in r.text
	var once: bool = r.text.count("enemy.gd:12") == 1
	var clean: bool = not "Parameter" in r.text and not "Steve" in r.text
	var c := Game.ErrorReport.gather("", true)
	var crash: bool = c.get("kind", "") == "crash"
	var none: bool = Game.ErrorReport.gather("", false).is_empty()
	var quiet: bool = not FileAccess.file_exists(Game.ErrorReport.RUNNING) and Game.report.pending.is_empty()
	DirAccess.remove_absolute(p)
	var scrubbed: String = Game.ErrorReport.scrub("at C:\\Users\\Ann Smith\\AppData\\x.gd and /home/bob/.local/x and /Users/carl/Library")
	var named := scrubbed.contains("Ann") or scrubbed.contains("bob") or scrubbed.contains("carl")
	print("REPORTS found=%s once=%s clean=%s crash=%s none=%s quiet=%s private=%s" % [found, once, clean, crash, none, quiet, not named])


func debug_polish2() -> void:
	while not ready_world:
		await get_tree().create_timer(1.0).timeout
	clock = 12.0
	player.max_health = 100000.0
	player.health = 100000.0
	# A controller button moved: Y now jumps, and reload no longer has it
	Game.rebind_pad("jump", JOY_BUTTON_Y)
	var has := func(action: String, btn: int) -> bool:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton and ev.button_index == btn:
				return true
		return false
	var pad: bool = has.call("jump", JOY_BUTTON_Y) and not has.call("reload", JOY_BUTTON_Y) and not has.call("jump", JOY_BUTTON_A)
	Game.reset_binds()
	var reset: bool = has.call("jump", JOY_BUTTON_A) and has.call("reload", JOY_BUTTON_Y)
	Game.using_pad = true
	var words: bool = Game.key_text("jump") == "A" and Game.key_text("fire") == "RT"
	Game.using_pad = false
	words = words and Game.key_text("jump") == "Space"
	# A full gun, reload pressed: it is turned over in the hands, then back at rest
	player.weapon.shells = player.weapon.capacity()
	player.weapon.inspect()
	await get_tree().create_timer(1.2).timeout
	var turned: bool = absf(player.weapon._holder.rotation.y) > 0.05
	await get_tree().create_timer(2.0).timeout
	var rest: bool = player.weapon._inspect <= 0.0 and absf(player.weapon._holder.rotation.y) < 0.01
	# A slain form falls over rather than flattening
	var f := -player.global_transform.basis.z
	f.y = 0.0
	var e := spawn_at("unlit_blade", player.global_position + f.normalized() * 8.0 + Vector3(0, 1.0, 0))
	await get_tree().create_timer(0.5).timeout
	e.flinch(30.0, f)
	e.die(true)
	await get_tree().create_timer(0.9).timeout
	var fell: bool = is_instance_valid(e) and absf(e.rotation.x) > 1.0 and e.scale.y > 0.9
	await get_tree().create_timer(3.0).timeout
	var gone: bool = not is_instance_valid(e)
	print("POLISH2 words=%s pad=%s reset=%s turned=%s rest=%s fell=%s gone=%s" % [words, pad, reset, turned, rest, fell, gone])
