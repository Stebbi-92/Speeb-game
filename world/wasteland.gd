class_name Wasteland
extends Level
## The Ashen Waste. A survivor cast out into it gathers, builds, and lives through its nights,
## while nine dead beacons wait across the land to be kindled again.

const DAY_SECONDS := 1440.0
const DUSK := 20.0
const DAWN := 5.0
const RUINS_N := 44
const NODES_N := 900
const REVEAL_N := 128

var terrain: WTerrain
var inv := Inventory.new()
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
var people := {}
var settle_nodes := {}
var beacon_nodes: Array = []
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
var _day_t := 30.0
var _save_t := 120.0
var _save_soon := -1.0     ## counts down to a save asked for by an event; -1 when none
var _last_save := 0
var _reveal_t := 0.0
var _bleed_t := 0.0
var _vigil_t := 0.0
var _gen := RandomNumberGenerator.new()
var _m := {}


# ================================================================== the land

func build() -> void:
	Game.wasteland = true
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


var world_seed := 0
var _pending := {}


## Raises the whole waste from its seed: the land and its six biomes, then the places upon it.
func _make_world(sd: int) -> void:
	world_seed = sd
	terrain = WTerrain.new()
	terrain.setup(sd)
	WPlaces.lay_out(sd, func(p: Vector2) -> Vector2: return Vector2(terrain._raw(p.x, p.y), terrain_probe(p)))
	for k in WPlaces.SETTLEMENTS:
		terrain.add_flat(WPlaces.spos(k), WPlaces.SETTLEMENTS[k].radius + 8.0)
	for bp in WPlaces.beacon_points():
		terrain.add_flat(bp, 16.0)
	terrain.add_flat(WPlaces.start, 6.0)
	_plan_ruins()
	for r in ruins:
		terrain.add_flat(Vector2(r.pos.x, r.pos.z), 9.0)
	terrain.generate()
	for r in ruins:
		r.pos.y = terrain.height_at(r.pos.x, r.pos.z)
	terrain.build(_m.ground)
	add_child(terrain)
	for k in WPlaces.SETTLEMENTS:
		_build_settlement(k)
	for i in WPlaces.BEACONS.size():
		_build_beacon(i)
	for r in ruins:
		_build_ruin(r)
	_scatter_nodes()
	_scatter_decor()
	spawn_pos = gpos(WPlaces.start) + Vector3(0, 0.2, 0)
	spawn_yaw = yaw_to(spawn_pos, gpos(WPlaces.spos("cinderwick")))


func intro() -> void:
	hud.name_label.text = "Survivor"
	ui = WUI.new()
	ui.w = self
	hud.root.add_child(ui)
	inv.changed.connect(func(): if ready_world: autosave_soon(20.0))
	skills.changed.connect(_apply_skills)
	player.weapon.reserve_max = 400
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


func _process(_delta: float) -> void:
	if _stars and player:
		_stars.global_position = player.global_position


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


## How steep the raw land is at a point, before any flattening.
func terrain_probe(p: Vector2) -> float:
	var a := terrain._raw(p.x - 6, p.y)
	var b := terrain._raw(p.x + 6, p.y)
	var c := terrain._raw(p.x, p.y - 6)
	var d := terrain._raw(p.x, p.y + 6)
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
	var body: StaticBody3D = f.get_meta("body")
	body.collision_layer = 1 | 16
	personal_interactable(body, "Speak with %s" % pd.name, func(): ui.open_dialogue(pid))
	var lbl := label3d("%s\n%s" % [pd.name, pd.title], p + Vector3(0, 2.25, 0), 0.32, Color(0.92, 0.88, 0.78), 0.0, true)
	lbl.visibility_range_end = 18.0
	people[pid] = {"node": f, "pos": p}


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


func safe_at(p: Vector3) -> bool:
	for i in lit:
		if Vector2(p.x, p.z).distance_to(WPlaces.bpos(i)) < WPlaces.BEACON_SAFE:
			return true
	return settlement_at(p, 6.0) == "mourners"


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
			for it in Items.roll(c.table, rr.randi_range(2, 4) + (2 if c.sealed else 0), rr):
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


func _rq_put(by: int, id: String, item: String, n: int) -> void:
	if not Net.authority() or not containers.has(id):
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
		if id == "shells":
			player.weapon.add_shells(n)
			hud.notify("+%d shells" % n)
			continue
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
	p.y = terrain.height_at(p.x, p.z) if absf(p.y - terrain.height_at(p.x, p.z)) < 2.0 else p.y
	n.global_position = p
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
	if grave:
		var l := OmniLight3D.new()
		l.light_color = Color(0.7, 0.8, 1.0)
		l.light_energy = 1.2
		l.omni_range = 4.0
		l.position.y = 1.0
		n.add_child(l)
	personal_interactable(body, "Your belongings" if grave else "Satchel", func(): shared("_rq_open", [Net.me(), sid]))
	satchels[sid] = {"node": n, "pos": p, "grave": grave}


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
		if terrain.normal_at(p.x, p.z).y < 0.8:
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
	"ash": ["rusher", "rusher", "spitter", "spider", "swarm", "idol"],
	"dunes": ["spitter", "spitter", "rusher", "swarm", "spider"],
	"salt": ["rusher", "spitter", "swarm", "swarm", "rusher"],
	"forest": ["rusher", "rusher", "spider", "spider", "idol"],
	"basalt": ["idol", "idol", "rusher", "spitter", "spider"],
	"marsh": ["spider", "spider", "swarm", "swarm", "swarm", "rusher"],
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
				out.append(["shells", rr.randi_range(2, 6)])
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
	if skills.gather_mult() > 1.0:
		for it in out:
			if it[0] != "coin":
				it[1] = int(ceil(int(it[1]) * skills.gather_mult()))
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
	_reveal_t -= delta
	if _reveal_t <= 0.0 and not Net.dedicated:
		_reveal_t = 0.5
		_reveal_around(player.global_position, 90.0)
		_visit_check()
	if downed and Net.online and not failing:
		_bleed_t -= delta
		if _bleed_t <= 0.0:
			_perish("You bled out in the dust before anyone could raise you.")
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
	_spikes(delta)


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
	sfx("drone", -6)
	hud.say("The sun goes down behind the ridges. Night comes to the waste, and the forms come with it.", 6.0)
	quests.on_event("nightfall", {})


func _w_dawn(d: int) -> void:
	night = false
	day = d
	nights += 1
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
			_spawn_near(roster[randi() % roster.size()], t.global_position, 30.0, 48.0)
		if nights >= 2 and randf() < 0.12 + nights * 0.02:
			_spawn_near("saucer", t.global_position, 30.0, 40.0)
		if nights >= 4 and randf() < 0.06 + nights * 0.01:
			_spawn_near("elite", t.global_position, 35.0, 45.0)
			hud.notify("Something greater walks tonight.")


## By day the waste is quieter, but the ruins are not empty, and the roads are not always clear.
func _day_watch() -> void:
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
					_spawn_near(["rusher", "spitter", "spider", "idol"][randi() % 4], r.pos, 6.0, 14.0, true)
		if alive_count() < 2 and randf() < 0.08:
			_spawn_near(["rusher", "spider", "swarm"][randi() % 3], p, 40.0, 60.0)


func _spawn_near(kind: String, c: Vector3, rmin: float, rmax: float, anywhere := false) -> void:
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
		return


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
	kills += 1
	kill_line()
	Game.add_kill(e.kind)
	streak += 1
	_streak_t = 3.5
	hud.set_streak(streak)
	if player.relics:
		player.relics.add_faith(0.04 if e.kind in ["swarm", "mite"] else 0.1)
	shared("_w_slain", [e.global_position, e.kind, Net.me()])
	award("kill_elite" if e.kind in ["elite", "saucer"] else "kill")
	if randf() < (0.5 if e.kind in ["elite", "saucer"] else 0.12) + skills.drop_bonus():
		shared("_rq_satchel", [Net.me(), e.global_position, Items.roll("corpse", 2 if e.kind in ["elite", "saucer"] else 1, _gen), false])


func team_kill(e: LesserSpeeb) -> void:
	team_kills += 1


func _w_slain(p: Vector3, kind: String, by := 0) -> void:
	quests.on_event("kill", {"pos": p, "kind": kind})
	# A fellow's kill close by teaches a little too
	if by != 0 and by != Net.me() and not Net.dedicated and player.global_position.distance_to(p) < 40.0:
		award("assist")


# ================================================================== falling, and rising again

func damage_player(amount: float, from: Vector3) -> void:
	if failing or downed or _pfail or Net.dedicated:
		return
	player.shake(0.45)
	amount *= Game.difficulty_scale("damage") * skills.harm_mult()
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
			_bleed_t = 40.0
			_go_down()
		else:
			_perish("You fell in the dust, and the forms went on without you.")


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
	_pfail = true
	player.input_locked = true
	if ui:
		ui.close_all()
	var drop: Array = []
	for i in inv.slots.size():
		var s = inv.slots[i]
		if s != null and Items.info(s.id).kind != "tool" and Items.info(s.id).kind != "quest":
			drop.append([s.id, int(s.n)])
			inv.slots[i] = null
	inv.changed.emit()
	if player.weapon.reserve > 0:
		drop.append(["shells", player.weapon.reserve])
		player.weapon.reserve = 0
	if not drop.is_empty():
		shared("_rq_satchel", [Net.me(), player.global_position, drop, true])
	await hud.fade_to(1.0, 1.4)
	hud.clear_say()
	hud.raise_text(true)
	hud.say(message + "\nWhat you carried lies where you fell.", 5.0)
	await get_tree().create_timer(5.5, false).timeout
	hud.raise_text(false)
	if downed:
		_rise(1.0)
	player.place(respawn_point(), player.yaw)
	player.health = player.max_health
	player.weapon.shells = player.weapon.capacity()
	player.weapon.add_shells(12)
	hud.set_health(1.0, true)
	player.input_locked = false
	_pfail = false
	hud.fade_to(0.0, 1.5)


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
		pcs[pid] = [pc.kind, pc.pos, pc.yaw, pc.hp, pc.get("open", false)]
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
		"satchels": sat, "satchel_next": satchel_next, "quests": quests.to_data(),
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
	piece_next = int(d.get("piece_next", 1))
	containers = d.get("containers", {})
	for id in d.get("crates", {}):
		_w_crate_day(id, int(d.crates[id]))
	for sid in d.get("satchels", {}):
		_w_satchel(sid, d.satchels[sid][0], d.satchels[sid][1])
	satchel_next = int(d.get("satchel_next", 1))
	quests.from_data(d.get("quests", {}))
	for i in lit:
		_light_beacon(i, true)
	_apply_time(true)


func char_data() -> Dictionary:
	return {
		"v": 1, "inv": inv.to_data(), "shells": player.weapon.shells, "reserve": player.weapon.reserve, "arms": player.weapon.ammo_state(), "hp": player.health,
		"pos": player.global_position if player.is_inside_tree() else player.position, "yaw": player.yaw, "revealed": Marshalls.raw_to_base64(revealed),
		"visited": visited, "known": known_ruins, "skills": skills.to_data(), "biomes": seen_biomes, "bedroll": bedroll, "milk": Game.milk,
	}


func apply_char(d: Dictionary) -> void:
	skills.from_data(d.get("skills", {}))
	_apply_skills()
	seen_biomes = d.get("biomes", {}) if d.get("biomes") is Dictionary else {}
	inv.from_data(d.get("inv", []))
	player.weapon.shells = int(d.get("shells", player.weapon.capacity()))
	player.weapon.reserve = int(d.get("reserve", 18))
	player.weapon.set_ammo_state(d.get("arms"))
	player.health = clampf(float(d.get("hp", 100.0)), 20.0, player.max_health)
	hud.set_health(player.health / player.max_health, true)
	var p = d.get("pos")
	if p is Vector3:
		player.place(p + Vector3(0, 0.3, 0), float(d.get("yaw", 0.0)))
	var rv = d.get("revealed", "")
	if rv is String and rv != "":
		var raw := Marshalls.base64_to_raw(rv)
		if raw.size() == revealed.size():
			revealed = raw
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
		quests.start_new()
		quests.refresh_offers()


func _load_character() -> void:
	if world_uid == "":
		while world_uid == "" and is_inside_tree():
			await get_tree().process_frame
	var d = Game.read_var_safe(_char_path())
	if d is Dictionary:
		apply_char(d)
		return
	# Cast out with almost nothing
	inv.from_data([])
	inv.add("bandage", 2)
	inv.add("meat", 2)
	inv.add("salt", 12)
	player.weapon.shells = player.weapon.capacity()
	player.weapon.reserve = 18
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


func debug_nightshot() -> void:
	clock = 22.0
	night = true
	lit.append(0)
	_light_beacon(0, true)
	player.place(beacon_nodes[0].pos + Vector3(0, 1.0, 34), 0.0)
	player.pitch = 0.15


func debug_coop_host() -> void:
	var p := gpos(WPlaces.spos("cinderwick")) + Vector3(80, 0, 20)
	builder._rq_build(1, "chest", p, 0.0)
	_w_vigil_end(0, true)
	await get_tree().create_timer(12.0).timeout
	print("HOST pieces %d lit %s avatars %d foes %d quests %d" % [pieces.size(), lit, avatars.size(), foes.size(), quests.active().size()])


func debug_coop_join() -> void:
	await get_tree().create_timer(8.0).timeout
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


func debug_skillshot() -> void:
	award("beacon", 6.0)
	for id in ["hardy", "hardy", "steady_hand"]:
		skills.learn(id)
	ui.open_skills()
