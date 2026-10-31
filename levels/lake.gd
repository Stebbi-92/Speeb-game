extends Level
## IX. The Silent Lake. No ripple may disturb the mirrored surface. Brelm treads softly toward the last of the Nine.

const SEAT := Vector3(0, 0, -72)

var stillness := 1.0
var ripple_t := 0.0
var chill: Emoji3D
var ring_mat: StandardMaterial3D
var reached := false


func build() -> void:
	numeral = "IX"
	max_alive = 3
	spitter_chance = 0.7
	place = "The Silent Lake"
	verse = "Ninth and last, at the end of all strength, Brelm came upon the Silent Lake, where no ripple disturbed the mirrored surface."
	setup_env(Color(0.04, 0.06, 0.14), Color(0.36, 0.38, 0.5), Color(0.02, 0.03, 0.05), Color(0.3, 0.33, 0.45), 0.01, 0.6)
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	set_sky_stars(0.8)
	add_sun(Vector3(-6, 10, 0), Color(0.75, 0.7, 0.85), 0.6)
	kill_y = -10
	var shore := mat(Color(0.22, 0.22, 0.24), 1.0, 0.4, 0.1)
	box(Vector3(0, -0.5, 14), Vector3(120, 1, 24), shore)
	# The lake: a mirror, and beneath it a floor that bears only the patient
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	water.mesh = pm
	water.material_override = water_mat(Color(0.02, 0.025, 0.04))
	water.position = Vector3(0, 0.0, -198)
	add_child(water)
	box(Vector3(0, -0.5, -98), Vector3(400, 1, 196), shore, true)
	water.position.y = 0.01
	# The flat stone where Chillspeeb reclines
	cyl(SEAT + Vector3(0, 0.15, 0), 3.0, 0.3, mat(Color(0.5, 0.5, 0.52), 0.6, 0.2))
	chill = Emoji3D.new().setup("chillspeeb", 3.0, 0.36)
	chill.position = SEAT + Vector3(0, 1.85, 0)
	chill.glow = 0.3
	add_child(chill)
	omni(SEAT + Vector3(0, 3, 2), Color(0.9, 0.92, 1.0), 1.5, 10)
	# Distant mountains ringing the lake
	var far := mat(Color(0.08, 0.09, 0.14), 1.0, 0.3, 0.02)
	for i in 24:
		var a := PI + i * PI / 23.0
		var d := _rng.randf_range(150, 190)
		cyl(Vector3(cos(a) * d, 10, -60 + sin(a) * d), _rng.randf_range(20, 40), _rng.randf_range(30, 70), far, false, 2.0, 7)
	# Reeds along the shore
	var reed := mat(Color(0.16, 0.18, 0.14), 1.0, 0.1)
	for i in 60:
		var p := Vector3(_rng.randf_range(-50, 50), 0.6, _rng.randf_range(1, 4))
		if absf(p.x) < 3:
			continue
		cyl(p, 0.03, 1.2 + _rng.randf() * 0.8, reed, false, 0.01, 4)
	ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.8, 0.85, 1.0, 0.6)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lesser("starespeeb", Vector3(-6, 1.2, 8))
	lesser("galaxyspeeb", Vector3(9, 1.8, -36))
	lesser("snowspeeb", SEAT + Vector3(-4.5, 1.4, 1))
	ambient("drone", -18)
	spawn_pos = Vector3(0, 0.1, 10)
	spawn_yaw = 0.0


func intro() -> void:
	hud.set_objective("Cross the still water. Tread softly: hold Ctrl.")
	await super.intro()


func trial_tick(delta: float) -> void:
	var p := player.global_position
	var on_lake := p.z < 2.0
	if on_lake:
		hud.set_meter("Stillness", stillness)
		ripple_t -= delta
		var hasty := player.cur_speed > 1.7 or not player.is_on_floor()
		if hasty:
			stillness -= delta * 0.32
			if ripple_t <= 0.0:
				ripple_t = 0.45
				_ripple(Vector3(p.x, 0.03, p.z))
		else:
			stillness = minf(1.0, stillness + delta * 0.05)
		if stillness <= 0.0:
			fail("The lake will not bear the hasty. He found himself again upon the shore.", "ripple")
	else:
		hud.set_meter("", 0)
	if not reached and p.distance_to(SEAT) < 6.0:
		reached = true
		_final()


func reset_trial() -> void:
	stillness = 1.0


func _ripple(p: Vector3) -> void:
	sfx("ripple", -12)
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.48
	tm.outer_radius = 0.5
	tm.rings = 32
	mi.mesh = tm
	var m := ring_mat.duplicate()
	mi.material_override = m
	mi.position = p
	mi.scale = Vector3(1, 0.05, 1)
	add_child(mi)
	var tw := create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(9, 0.05, 9), 3.0)
	tw.tween_property(m, "albedo_color:a", 0.0, 3.0)
	tw.chain().tween_callback(mi.queue_free)


func _final() -> void:
	hud.set_meter("", 0)
	reveal("chillspeeb", chill.position, 3.0, false, _kneel, chill)


func _kneel(_e: Emoji3D) -> void:
	await get_tree().create_timer(4.0, false).timeout
	create_tween().tween_property(player.head, "position:y", 0.8, 2.5).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(3.0, false).timeout
	player.look_toward(chill.global_position, 2.0)
