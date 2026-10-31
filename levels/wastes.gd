extends Level
## III. The Verdant Wastes. Brelm begs alms of the keeper and plants the grain with strangers. Every gift turns the dust green.

const STRANGERS := [Vector3(-24, 0, -18), Vector3(18, 0, -26), Vector3(-10, 0, -50), Vector3(28, 0, -58), Vector3(-34, 0, -66)]
const KEEPER := Vector3(0, 0, -6)

var carrying := false
var planted := 0
var ground_mat: StandardMaterial3D
var stranger_bodies: Array = []
var keeper_body: StaticBody3D
var dust_color := Color(0.52, 0.47, 0.38)
var green_color := Color(0.3, 0.42, 0.2)


func build() -> void:
	numeral = "III"
	place = "The Verdant Wastes"
	verse = "Third, he laboured in the Verdant Wastes, planting seeds with strangers, begging for alms."
	setup_env(Color(0.55, 0.5, 0.42), Color(0.78, 0.7, 0.56), Color(0.3, 0.27, 0.22), Color(0.72, 0.64, 0.5), 0.016, 0.8)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_albedo = Color(0.9, 0.8, 0.65)
	add_sun(Vector3(-40, 60, 0), Color(1.0, 0.88, 0.7), 1.6)
	ground_mat = mat(dust_color, 1.0, 0.4, 0.05)
	box(Vector3(0, -0.5, -30), Vector3(260, 1, 260), ground_mat)
	var wood := mat(Color(0.25, 0.2, 0.16), 1.0, 0.3, 0.6)
	# Dead trees
	for i in 40:
		var p := Vector3(_rng.randf_range(-70, 70), 0, _rng.randf_range(-100, 30))
		if p.distance_to(KEEPER) < 8:
			continue
		var h := _rng.randf_range(2.5, 6.0)
		cyl(p + Vector3(0, h * 0.5, 0), 0.18, h, wood, true, 0.08, 6)
		for b in 3:
			var br := box(p + Vector3(0, h * _rng.randf_range(0.5, 0.9), 0), Vector3(0.1, _rng.randf_range(1.0, 2.0), 0.1), wood, false)
			br.rotation = Vector3(_rng.randf_range(-0.9, 0.9), _rng.randf() * TAU, _rng.randf_range(-0.9, 0.9))
	# Dry riverbed
	for i in 12:
		box(Vector3(-60 + i * 11, -0.45, 12 + sin(i) * 4), Vector3(12, 0.2, 4), mat(Color(0.35, 0.33, 0.3), 1.0, 0.3), false, Vector3(0, sin(i * 0.7) * 20, 0))
	# The keeper's granary: a low hut of mud and reed
	var mud := mat(Color(0.48, 0.4, 0.3), 1.0, 0.35, 0.3)
	box(KEEPER + Vector3(0, 1.4, -3), Vector3(6, 2.8, 4), mud)
	cyl(KEEPER + Vector3(0, 3.4, -3), 3.8, 1.4, mat(Color(0.6, 0.5, 0.3), 1.0, 0.3, 0.5), false, 0.4, 8)
	for k in 4:
		sphere(KEEPER + Vector3(-2.2 + k * 0.6, 0.4, -0.6), 0.4, mat(Color(0.7, 0.6, 0.42), 1.0, 0.2), true, 1.1)
	var keeper := figure(KEEPER + Vector3(1.6, 0, -0.3), PI, Color(0.4, 0.33, 0.26))
	keeper_body = keeper.get_meta("body")
	make_interactable(keeper_body, "Beg the keeper for alms", _beg)
	# The strangers, kneeling in the dust
	for p in STRANGERS:
		var f := figure(p, yaw_to(p, KEEPER), Color(0.32, 0.29, 0.25), true)
		var sb: StaticBody3D = f.get_meta("body")
		sb.set_meta("pos", p)
		stranger_bodies.append(sb)
		make_interactable(sb, "", func(): _plant(sb), 2.0)
		cyl(p + Vector3(0.9, 0.05, 0.3), 0.6, 0.1, mat(Color(0.3, 0.26, 0.2), 1.0, 0.2), false)

	lesser("chefspeeb", KEEPER + Vector3(-2.6, 1.3, 0.6))
	lesser("autumnspeeb", Vector3(40, 1.2, -30))
	lesser("shroomspeeb", Vector3(-48, 1.0, -40))
	lesser("blossomspeeb", Vector3(6, 1.2, -78))
	ambient("wind", -12)
	spawn_pos = Vector3(0, 0.1, 10)
	spawn_yaw = 0.0


func intro() -> void:
	hud.set_objective("Beg alms of the keeper, then plant the grain with the strangers   0 / 5")
	await super.intro()


func _beg() -> void:
	if carrying:
		hud.say("The keeper waits. Your hands are already full.", 3.0)
		return
	carrying = true
	sfx("step", 0)
	keeper_body.set_meta("prompt", "")
	hud.say(["The keeper looks long at the hermit, then fills his open hands with grain.",
		"Again the keeper gives. He asks nothing.", "The keeper's sacks grow lighter. He does not hesitate.",
		"The keeper gives from what little remains.", "The last measure. The keeper's hands are empty, and he is content."][planted], 5.0)
	_update()


func _plant(sb: StaticBody3D) -> void:
	if not carrying:
		return
	carrying = false
	sb.set_meta("prompt", "")
	sb.set_meta("done", true)
	planted += 1
	sfx("carve", -10)
	var p: Vector3 = sb.get_meta("pos")
	var grass := cyl(p + Vector3(0, 0.03, 0), 1.0, 0.06, mat(green_color, 1.0, 0.3, 0.2), false)
	grass.scale = Vector3(0.01, 1, 0.01)
	create_tween().tween_property(grass, "scale", Vector3(9, 1, 9), 6.0).set_trans(Tween.TRANS_SINE)
	_grow_wheat(p)
	if planted == 5:
		_bounty()
	else:
		hud.say(["Where hands were open, the fields bore grain.", "The dust remembers what it was.",
			"The stranger does not thank him. Nor does Brelm wait for thanks.", "One more remains, kneeling in the dust."][planted - 1], 4.0)
	_update()


func _grow_wheat(p: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 1.0, 0.04)
	mm.mesh = bm
	mm.instance_count = 260
	for i in mm.instance_count:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 8.0
		var t := Transform3D(Basis().rotated(Vector3(1, 0, 0), _rng.randf_range(-0.15, 0.15)).scaled(Vector3(1, _rng.randf_range(0.6, 1.2), 1)), p + Vector3(cos(a) * r, 0.5, sin(a) * r))
		mm.set_instance_transform(i, t)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat(Color(0.85, 0.72, 0.38), 0.9, 0.1)
	mi.scale = Vector3(1, 0.01, 1)
	add_child(mi)
	create_tween().tween_property(mi, "scale", Vector3.ONE, 8.0).set_delay(1.5).set_trans(Tween.TRANS_SINE)


func _update() -> void:
	for sb in stranger_bodies:
		if not sb.get_meta("done", false):
			sb.set_meta("prompt", "Plant the grain with the stranger" if carrying else "")
	keeper_body.set_meta("prompt", "" if carrying or planted >= 5 else "Beg the keeper for alms")
	hud.set_objective(("Carry the grain to a stranger" if carrying else "Beg alms of the keeper") + "   %d / 5 planted" % planted)


func _bounty() -> void:
	completed = true
	hud.say("And the whole of the waste remembered that it had once been green.", 7.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(ground_mat, "albedo_color", green_color, 10.0)
	tw.tween_property(env, "fog_light_color", Color(0.62, 0.7, 0.58), 10.0)
	tw.tween_property(env, "volumetric_fog_albedo", Color(0.85, 0.9, 0.8), 10.0)
	await get_tree().create_timer(8.0, false).timeout
	completed = false
	await survive("speebchef", Vector3(0, 3.5, -38), "pulse")
	reveal("speebchef", Vector3(0, 3.5, -38), 3.2)
