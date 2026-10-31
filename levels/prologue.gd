extends Level
## The Plateau of Mirrors. The first Temple of Silence, where Brelm lays down his office and takes the Vow of Severance.

var stage := 0
var door: MeshInstance3D
var mantle: MeshInstance3D
var stone_body: StaticBody3D


func build() -> void:
	numeral = "Prologue"
	combat = false
	armed = false
	place = "The Plateau of Mirrors"
	verse = "Among the Silent Clerics, there arose one whose hunger for understanding outstripped all restraint: Brelm, a keeper of riddles, a scribe of glyphs so subtle that even the Elders paused to decipher his meaning."
	setup_env(Color(0.55, 0.62, 0.72), Color(0.86, 0.86, 0.84), Color(0.3, 0.3, 0.3), Color(0.85, 0.86, 0.88), 0.006, 1.2)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.95, 0.95, 0.95)
	env.ssr_enabled = true
	add_sun(Vector3(-62, 25, 0), Color(1.0, 0.97, 0.9), 2.2)

	var white := mat(Color(0.9, 0.89, 0.86), 0.7, 0.12, 0.15)
	var floor_m := mat(Color(0.8, 0.79, 0.76), 0.35, 0.15, 0.1)
	var glyph := mat(Color(0.55, 0.52, 0.48), 1.0, 0.0)

	# The outer plateau, bare and bright.
	box(Vector3(0, -0.5, 0), Vector3(240, 1, 240), mat(Color(0.72, 0.71, 0.68), 0.9, 0.3, 0.05))
	for i in 40:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(45, 110)
		box(Vector3(cos(a) * d, 0.2, sin(a) * d), Vector3(_rng.randf_range(1, 5), _rng.randf_range(0.4, 2.5), _rng.randf_range(1, 5)), white, true, Vector3(0, _rng.randf() * 90, 0))

	# The Path of Still Steps: the long hall.
	box(Vector3(0, 0.05, 0), Vector3(14, 0.1, 48), floor_m)
	box(Vector3(-7.5, 4, 0), Vector3(1, 8, 48), white)
	box(Vector3(7.5, 4, 0), Vector3(1, 8, 48), white)
	box(Vector3(-4.5, 4, 24.5), Vector3(5, 8, 1), white)
	box(Vector3(4.5, 4, 24.5), Vector3(5, 8, 1), white)
	box(Vector3(0, 7, 24.5), Vector3(4, 2, 1), white)
	for z in range(-21, 24, 6):
		box(Vector3(0, 8.25, z), Vector3(16, 0.5, 3.4), white)
		cyl(Vector3(-5, 4, z), 0.45, 8, white)
		cyl(Vector3(5, 4, z), 0.45, 8, white)
	# Pool of still water down the centre
	box(Vector3(0, 0.15, 0), Vector3(4.4, 0.3, 36.4), white)
	box(Vector3(0, 0.22, 0), Vector3(4, 0.2, 36), water_mat(Color(0.05, 0.07, 0.09)))
	# Silent Clerics seated along the hall, facing the water
	for z in [-15.0, -6.0, 3.0, 12.0]:
		figure(Vector3(-3.4, 0.1, z), PI / 2, Color(0.82, 0.8, 0.76), true)
		figure(Vector3(3.4, 0.1, z + 3), -PI / 2, Color(0.82, 0.8, 0.76), true)
	# Paw-glyphs carved into the walls
	for z in range(-20, 22, 4):
		pawprint(Vector3(-6.98, 2.2, z), PI / 2, 0.5, glyph, true)
		pawprint(Vector3(6.98, 2.2, z), -PI / 2, 0.5, glyph, true)
	label3d("He who seeks to know all mysteries must beware,\nfor in seeking, one invites the gaze of the White Cat\nmore fully upon oneself.", Vector3(-6.95, 3.6, 18), 0.32, Color(0.35, 0.33, 0.3), PI / 2)

	# The Hall of Waiting
	box(Vector3(0, 0.05, -34), Vector3(20, 0.1, 20), floor_m)
	box(Vector3(-10.5, 5, -34), Vector3(1, 10, 21), white)
	box(Vector3(10.5, 5, -38.5), Vector3(1, 10, 11), white)
	box(Vector3(10.5, 5, -26.25), Vector3(1, 10, 4.5), white)
	box(Vector3(10.5, 7.5, -31.5), Vector3(1, 5, 6), white)
	box(Vector3(0, 5, -44.5), Vector3(22, 10, 1), white)
	box(Vector3(-8.75, 5, -24), Vector3(2.5, 10, 1), white)
	box(Vector3(8.75, 5, -24), Vector3(2.5, 10, 1), white)
	box(Vector3(0, 9, -24), Vector3(15, 2, 1), white)
	box(Vector3(0, 10.25, -40), Vector3(22, 0.5, 9), white)
	box(Vector3(0, 10.25, -28), Vector3(22, 0.5, 7), white)
	# The obsidian mirror of the Vigil of the Unblinking
	box(Vector3(0, 3.5, -43.9), Vector3(5, 6, 0.2), mat(Color(0.02, 0.02, 0.025), 0.04, 0.0, 1.0, 1.0))
	box(Vector3(0, 3.5, -43.95), Vector3(5.6, 6.6, 0.1), mat(Color(0.3, 0.29, 0.27), 0.6, 0.1))
	# The great door, sealed
	door = box(Vector3(10.5, 2.5, -31.5), Vector3(0.8, 5, 6), mat(Color(0.75, 0.73, 0.69), 0.8, 0.2, 0.2))

	# The mantle upon its stand
	cyl(Vector3(-6, 0.9, -32), 0.08, 1.8, glyph)
	box(Vector3(-6, 1.8, -32), Vector3(1.2, 0.08, 0.08), glyph)
	mantle = box(Vector3(-6, 1.25, -32), Vector3(1.0, 1.1, 0.25), mat(Color(0.86, 0.84, 0.8), 1.0, 0.2, 0.5), false)
	# The Stone of Weighing
	var stone := box(Vector3(0, 0.55, -36), Vector3(1.6, 1.1, 1.6), mat(Color(0.45, 0.44, 0.42), 0.9, 0.3, 0.3))
	stone_body = stone.get_child(0)
	pawprint(Vector3(0, 1.1, -36), 0, 0.6, glyph)

	var mantle_area := interact_area(Vector3(-6, 1.3, -32), 0.8, "", _lay_mantle)
	mantle_area.name = "MantleArea"

	lesser("clericspeeb", Vector3(-3.4, 1.4, -20.5))
	lesser("marblespeeb", Vector3(8.5, 1.3, -42.5))
	lesser("obsidianspeeb", Vector3(-9.2, 1.2, -43))
	lesser("candlespeeb", Vector3(6.2, 1.0, 22.8))
	omni(Vector3(0, 7, -34), Color(1, 0.98, 0.94), 3.0, 22)
	omni(Vector3(0, 6, -10), Color(1, 0.98, 0.94), 1.5, 16)
	omni(Vector3(0, 6, 10), Color(1, 0.98, 0.94), 1.5, 16)

	trigger_area(Vector3(0, 2, -25), Vector3(14, 4, 2), _enter_hall)
	ambient("wind", -24)
	ambient("drone", -20)
	spawn_pos = Vector3(0, 0.2, 21)
	spawn_yaw = 0.0


func intro() -> void:
	hud.set_objective("Walk the Path of Still Steps to the Hall of Waiting")
	await super.intro()


func _enter_hall() -> void:
	if stage != 0:
		return
	stage = 1
	hud.say("At the centre of each temple lay the Hall of Waiting, a vast empty room where no images adorned the walls. It was said that in this Hall, one could feel Speeb's unblinking gaze settle fully upon the soul.", 9.0)
	hud.set_objective("Lay down the mantle of clerical office")
	get_node("MantleArea").set_meta("prompt", "Lay down the mantle of clerical office")


func _lay_mantle() -> void:
	if stage != 1:
		return
	stage = 2
	var a: Area3D = get_node("MantleArea")
	a.set_meta("prompt", "")
	var tw := create_tween()
	tw.tween_property(mantle, "position:y", 0.15, 1.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(mantle, "rotation_degrees:x", 80.0, 1.5)
	hud.say("Yet deep within him stirred a relentless yearning: to behold, not just in part but in full, the Nine Meowifestations of Speeb.", 7.0)
	hud.set_objective("Take the Vow of Severance at the Stone of Weighing")
	make_interactable(stone_body, "Place your hand upon the Stone and take the Vow of Severance", _vow, 3.0)


func _vow() -> void:
	if stage != 2:
		return
	stage = 3
	stone_body.set_meta("prompt", "")
	sfx("crumble", -6)
	var tw := create_tween()
	tw.tween_property(door, "position:y", -2.6, 6.0).set_trans(Tween.TRANS_SINE)
	hud.say("Casting aside his mantle, Brelm took the Vow of Severance. Without word or ceremony, he departed the Plateau of Mirrors, wandering into the wild and desolate places where the threads of Balance tremble most fiercely.", 10.0)
	hud.set_objective("Depart the Plateau of Mirrors")
	await get_tree().create_timer(3.0, false).timeout
	player.set_armed(true)
	sfx("pump", -2)
	hud.notify("Upon the Stone of Weighing lay the instrument of his severance.\nLeft click to fire. R to load shells.")
	trigger_area(Vector3(14, 2, -31.5), Vector3(2, 4, 8), func(): Game.main.next_level())
