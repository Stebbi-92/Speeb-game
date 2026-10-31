extends Level
## The Forgotten Cave. Brelm scratches his testament upon the wall. Survive all, and Speeb stares back.

const WALL := Vector3(0, 0, -34)
const LINES := ["They are not blessings.", "They are trials.", "Survive one, you are changed.", "Survive all..."]

var stage := 0
var wall_body: StaticBody3D
var big: Emoji3D
var torch: OmniLight3D
var _velm_done := false


func build() -> void:
	numeral = ""
	combat = false
	armed = false
	place = "The Forgotten Cave"
	verse = "Brelm fell to his knees. He wept without sound. He understood, at last, the full weight of Balance, and the price of seeking beyond mortal bounds."
	setup_env(Color(0, 0, 0), Color(0, 0, 0), Color(0, 0, 0), Color(0.01, 0.01, 0.01), 0.05, 0.0)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.02, 0.02, 0.025)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	var rock := mat(Color(0.24, 0.22, 0.2), 0.95, 0.55, 0.2)
	# A narrow winding passage, then the chamber
	box(Vector3(0, -0.5, -14), Vector3(10, 1, 48), rock)
	box(Vector3(0, 4.5, -14), Vector3(10, 1, 48), rock)
	for z in range(10, -26, -4):
		var w := 2.4 + sin(z * 0.4) * 0.6
		box(Vector3(-w - 1.5 + sin(z * 0.2) * 0.6, 2, z), Vector3(3, 6, 4.4), rock, true, Vector3(0, _rng.randf_range(-6, 6), _rng.randf_range(-4, 4)))
		box(Vector3(w + 1.5 + sin(z * 0.2) * 0.6, 2, z), Vector3(3, 6, 4.4), rock, true, Vector3(0, _rng.randf_range(-6, 6), _rng.randf_range(-4, 4)))
	box(Vector3(0, 2, 12.5), Vector3(10, 6, 1), rock)
	box(Vector3(-5.5, 2, -31), Vector3(1.5, 6, 12), rock)
	box(Vector3(5.5, 2, -31), Vector3(1.5, 6, 12), rock)
	var wall := box(WALL + Vector3(0, 2, -0.5), Vector3(8, 6, 1), rock)
	wall_body = wall.get_child(0)
	make_interactable(wall_body, "Scratch your testament into the stone", _carve, 2.0)
	# Old claw-marks of other seekers
	for i in 10:
		var l := label3d("/ / /", Vector3(_rng.randf_range(-3, 3), _rng.randf_range(0.6, 3.5), -33.98), 0.25, Color(0.15, 0.14, 0.13))
		l.rotation.z = _rng.randf_range(-0.6, 0.6)
	torch = omni(WALL + Vector3(2.4, 2.6, 2.0), Color(1.0, 0.62, 0.32), 2.0, 9, true)
	cyl(WALL + Vector3(2.4, 1.2, 1.6), 0.06, 2.4, mat(Color(0.2, 0.15, 0.1), 1.0, 0.0), false)
	sphere(WALL + Vector3(2.4, 2.5, 1.6), 0.12, glow_mat(Color(1.0, 0.6, 0.25), 6.0))
	lesser("blinkspeeb", Vector3(-1.5, 1.2, -6))
	lesser("voidspeeb", Vector3(1.8, 3.0, -20))
	lesser("hallowspeeb", WALL + Vector3(-3, 3.6, 0.8))
	ambient("cave", -8)
	# Velm, kneeling at the wall, writing the last page before Brelm can reach it
	velm = Velm.new()
	add_child(velm)
	velm.position = WALL + Vector3(-2.2, 0, 1.4)
	velm.rotation.y = PI * 0.85
	velm.visible = false
	var book := box(WALL + Vector3(-1.6, 0.06, 1.7), Vector3(0.45, 0.08, 0.32), mat(Color(0.3, 0.2, 0.12), 0.9, 0.0), false)
	book.rotation.y = 0.3
	trigger_area(Vector3(0, 1, -26), Vector3(10, 3, 2), _velm_scene)
	spawn_pos = Vector3(0, 0.1, 9)
	spawn_yaw = 0.0


func intro() -> void:
	lantern(1.4)
	hud.set_objective("Go deeper")
	await super.intro()


func _process(delta: float) -> void:
	if torch:
		torch.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.011) * 0.25 + randf() * 0.15


func _velm_scene() -> void:
	if _velm_done:
		return
	_velm_done = true
	velm.appear(2.5)
	sfx("carve", -10)
	await get_tree().create_timer(2.5, false).timeout
	var n := Game.leaves.size()
	var lines := [
		"Velm:\n\"You are early. I have not finished your last page.\"",
		"Velm:\n\"I have walked ahead of every hermit since the first pawprint. I write what they will do, and they do it, and I am never weighed.\"",
	]
	if n >= 7:
		lines.append("Velm:\n\"But you read the Leaves. All the way to the place where my hand stops. No one has read that far.\"")
		lines.append("He set the pen down on the stone, and did not pick it up again.")
	else:
		lines.append("Velm:\n\"You did not read my Leaves. Good. It is easier to write a man who does not look.\"")
		lines.append("He bent again to the page. The pen did not stop.")
	for l in lines:
		hud.say(l, 6.0)
		await get_tree().create_timer(6.5, false).timeout
	if n >= 7:
		velm.vanish()
		sfx("ripple", -6, null, 0.5)
		if n >= 10:
			Game.reveal_deed("velm")
	hud.set_objective("Scratch your testament into the stone")


func _carve() -> void:
	if stage != 0:
		return
	stage = 1
	wall_body.set_meta("prompt", "")
	hud.set_objective("")
	player.input_locked = true
	player.look_toward(WALL + Vector3(0, 2.4, 0), 1.5)
	for i in LINES.size():
		sfx("carve", -2)
		var l := label3d(LINES[i], WALL + Vector3(0, 3.0 - i * 0.45, 0.02), 0.26, Color(0.75, 0.7, 0.62))
		l.modulate.a = 0.0
		create_tween().tween_property(l, "modulate:a", 1.0, 1.2)
		await get_tree().create_timer(3.2, false).timeout
	await get_tree().create_timer(2.0, false).timeout
	fade_ambient(-60, 3.0)
	create_tween().tween_property(torch, "light_energy", 0.3, 3.0)
	set_process(false)
	await get_tree().create_timer(3.0, false).timeout
	# Behind him, in the dark, something has been watching the whole time.
	big = Emoji3D.new().setup("_speeb_big", 4.2, 0.5)
	big.position = Vector3(0, 2.2, -22)
	big.glow = 0.0
	big.face_target = player
	add_child(big)
	var eye := omni(Vector3(0, 2.4, -19.5), Color(0.95, 0.95, 1.0), 0.0, 6)
	player.input_locked = false
	player.can_run = false
	player.speed_cap = 0.6
	hud.say("...and Speeb stares back.", 6.0)
	hud.set_objective("")
	create_tween().tween_property(eye, "light_energy", 1.4, 6.0)
	create_tween().tween_method(big.set_glow, 0.0, 0.25, 6.0)
	sfx("drone", -6)
	var t := 0.0
	var seen := 0.0
	while t < 30.0 and seen < 6.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var fwd := -player.cam.global_transform.basis.z
		var to := (big.global_position - player.cam.global_position).normalized()
		if fwd.dot(to) > 0.92:
			seen += dt
	player.input_locked = true
	await get_tree().create_timer(2.0, false).timeout
	if Game.balanced_count() >= 6:
		# He walked in Balance. The White Cat blinks, once, and releases him.
		var blink := Emoji3D.new().setup("blinkspeeb", 4.2)
		blink.position = big.position
		blink.face_target = player
		blink.glow = 0.25
		add_child(blink)
		big.queue_free()
		sfx("bell", -6)
		hud.say("Speeb blinked. Once. And the hermit was released into the Stillness.", 6.0)
		await get_tree().create_timer(6.5, false).timeout
	if Game.leaves.size() >= 7:
		hud.say("Beside him the journal lay open. Its last page was blank. For the first time, no one had written what came next.", 6.0)
	else:
		hud.say("Behind him, in the dark, a pen began to scratch again. Somewhere, another hermit's journal had begun.", 6.0)
	await get_tree().create_timer(6.5, false).timeout
	var last := label3d("Speeb sees. Speeb is.\nDo not try to please him. Only survive him.", WALL + Vector3(0, 0.8, 0.02), 0.2, Color(0.6, 0.15, 0.1))
	last.modulate.a = 0.0
	create_tween().tween_property(last, "modulate:a", 1.0, 4.0)
	await hud.fade_to(1.0, 5.0)
	Game.main.show_credits()
