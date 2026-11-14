extends Level
## The Tenth Trial: the Hall of Emojis. Every form Brelm has recorded hangs in the white void.
## At its centre, the one who was never a disguise: Speeb Himself.

const CENTER := Vector3(0, 0, -30)


func build() -> void:
	numeral = "X"
	place = "The Hall of Emojis"
	verse = "He who seeks to know all mysteries must beware, for in seeking, one invites the gaze of the White Cat more fully upon oneself."
	max_alive = 7
	spawn_interval = 2.5
	setup_env(Color(0.92, 0.92, 0.9), Color(0.98, 0.98, 0.97), Color(0.9, 0.9, 0.88), Color(0.95, 0.95, 0.94), 0.012, 1.4)
	env.ssr_enabled = true
	add_sun(Vector3(-70, 20, 0), Color(1, 1, 1), 1.2)
	var white := mat(Color(0.93, 0.93, 0.92), 0.08, 0.04, 0.1, 0.3)
	cyl(CENTER + Vector3(0, -0.5, 0), 40.0, 1.0, white, true, -1.0, 64)
	kill_y = -20
	# The recorded forms, in a slow spiral about the hall
	var recorded := []
	for c in Game.lesser:
		if Game.found.has(c):
			recorded.append(c)
	for i in recorded.size():
		var a := i * 0.39
		var r := 18.0 + i * 0.12
		var e := Emoji3D.new().setup(recorded[i], 1.6)
		e.position = CENTER + Vector3(cos(a) * r, 3.0 + (i % 5) * 1.6, sin(a) * r)
		e.bob = 0.15
		e.glow = 0.2
		add_child(e)
		_shrines.append(e)
	pawprint(CENTER + Vector3(0, 0.0, 0), 0.0, 6.0, mat(Color(0.75, 0.74, 0.72), 0.5, 0.0))
	ambient("drone", -14)
	spawn_pos = CENTER + Vector3(0, 0.1, 22)
	spawn_yaw = 0.0
	trigger_area(CENTER + Vector3(0, 1, 0), Vector3(10, 3, 10), _gaze)


func intro() -> void:
	hud.set_objective("Walk to the pawprint at the centre of the Hall")
	await super.intro()


func _gaze() -> void:
	if completed:
		return
	await survive("_speeb", CENTER + Vector3(0, 6.0, 0), "all", 60.0)
	completed = true
	player.input_locked = true
	clear_enemies()
	hud.set_health(1.0, false)
	var verdict := Game.judge(11, kills, falls, witnessed)
	Game.reveal_deed("tenth")
	var e := Emoji3D.new().setup("_speeb_big", 7.0)
	e.position = CENTER + Vector3(0, 9.0, -6)
	e.glow = 0.0
	e.face_target = player
	add_child(e)
	player.look_toward(e.position, 3.0)
	sfx("bell", 0)
	fade_ambient(-40, 4.0)
	create_tween().tween_method(e.set_glow, 0.0, 0.2, 6.0)
	hud.reveal_num.text = "The One Beneath Every Form"
	hud.reveal_epithet.text = "Speeb  ·  The White Cat of Unblinking Judgment"
	hud.reveal_decree.text = "Neither god of war nor love, neither deceiver nor sage, but the pure balance of being."
	hud.reveal_text.text = "In the time before time, a single pawprint etched itself into the void. From that silent mark rose Speeb. He blinked once, and galaxies were born. He blinked again, and the laws of nature knelt into place. Brelm had seen every disguise. Now there were none."
	hud.reveal_hint.text = ""
	create_tween().tween_property(hud.reveal_box, "modulate:a", 1.0, 3.0)
	await get_tree().create_timer(10.0, false).timeout
	hud.reveal_hint.text = "Judgment: %s      [E]  Be released" % verdict
	if Net.dedicated:
		await get_tree().create_timer(20.0, false).timeout
	else:
		await player.interact_pressed
	hud.hide_reveal()
	await show_results(verdict)
	Game.main.next_level()
