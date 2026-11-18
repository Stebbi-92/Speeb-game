extends Node
## Holds the HUD and swaps the land Brelm walks in.

const Hud := preload("res://scripts/hud.gd")

var hud
var level: Node = null
var music: AudioStreamPlayer
var _busy := false
var _state := "title"
var _click: AudioStreamPlayer


## Every button in every menu gives a soft click when pressed.
func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("quiet"):
		n.pressed.connect(_play_click)


func _play_click() -> void:
	var takes := Level.takes_of("ui_click")
	if takes.is_empty() or not is_instance_valid(_click):
		return
	_click.stream = takes[randi() % takes.size()]
	_click.pitch_scale = randf_range(0.96, 1.04)
	_click.play()


func _ready() -> void:
	Game.main = self
	hud = Hud.new()
	add_child(hud)
	music = AudioStreamPlayer.new()
	music.volume_db = -8
	add_child(music)
	_click = AudioStreamPlayer.new()
	_click.bus = "Interface"
	_click.volume_db = -16
	add_child(_click)
	get_tree().node_added.connect(_on_node_added)
	var args := OS.get_cmdline_user_args()
	Net.session_ended.connect(_on_session_ended)
	if "server" in args:
		_start_dedicated(args)
		return
	var lvl := -1
	for a in args:
		if a.begins_with("level="):
			lvl = int(a.substr(6))
		elif a.begins_with("pos="):
			_debug_pos = a.substr(4).split_floats(",")
	for a in args:
		# Filming aid: flies the camera through a list of shots (tools/trailer/README.md)
		if a.begins_with("trailer=") and ResourceLoader.exists("res://tools/trailer/trailer.gd"):
			add_child(load("res://tools/trailer/trailer.gd").new(a.substr(8)))
	for a in args:
		if a.begins_with("call="):
			_debug_call(a.substr(5))
		if a.begins_with("shots="):
			_debug_shots(a.substr(6).split(","))
	# Testing aids for the fellowship: host=PORT, join=ADDRESS[:PORT], name=NAME
	for a in args:
		if a.begins_with("name="):
			Game.player_name = a.substr(5)
	for a in args:
		if a.begins_with("lobby="):
			Game.lobby_url = a.substr(6)
	for a in args:
		if a.begins_with("word="):
			Net.join_word = a.substr(5)
	for a in args:
		if a.begins_with("host="):
			Net.host(int(a.substr(5)), "Test fellowship", "public" in args, false, "private" in args, Net.join_word)
		elif a.begins_with("join="):
			var hp := Net.split_address(a.substr(5))
			Net.join(hp[0], hp[1])
	if "browse" in args:
		_debug_browse()
	for a in args:
		if a.begins_with("begin="):
			_debug_begin(int(a.substr(6)))
	if lvl >= 0:
		start_level(lvl)
	elif Net.online or Net._joining:
		show_lobby()
	else:
		show_title()
	if "options" in args:
		hud.show_options.call_deferred()


var _debug_pos := PackedFloat64Array()


## Testing aid: looks for fellowships and prints what answered.
func _debug_browse() -> void:
	await get_tree().create_timer(1.0).timeout
	Net.refresh_servers()
	await get_tree().create_timer(3.0).timeout
	print("found: %s" % JSON.stringify(Net.servers))


## Testing aid: once in a fellowship and allowed to choose, waits for the others and begins a trial.
func _debug_begin(i: int) -> void:
	while not (Net.online and Net.may_choose()):
		await get_tree().process_frame
	await get_tree().create_timer(4.0).timeout
	Net.begin(i)


## Testing aid: calls a method on the level once it has loaded.
func _debug_call(method: String) -> void:
	while not (is_instance_valid(level) and level.get("player")):
		await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	level.call(method)


## Testing aid: saves screenshots at the given seconds, then quits.
func _debug_shots(times: PackedStringArray) -> void:
	var t0 := 0.0
	while _debug_pos.size() >= 4:
		await get_tree().process_frame
		t0 += get_process_delta_time()
		if is_instance_valid(level) and level.get("player") and level.player.is_inside_tree():
			await get_tree().process_frame
			level.player.place(Vector3(_debug_pos[0], _debug_pos[1], _debug_pos[2]), deg_to_rad(_debug_pos[3]))
			if _debug_pos.size() >= 5:
				level.player.pitch = deg_to_rad(_debug_pos[4])
			_debug_pos = PackedFloat64Array()
	for i in times.size():
		var t := float(times[i])
		await get_tree().create_timer(t - t0, true, false, true).timeout
		t0 = t
		print("shot %d fps=%d pos=%s" % [i, Engine.get_frames_per_second(), str(level.player.global_position) if level and level.get("player") else ""])
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://shot_%d.png" % i)
	get_tree().quit()


func in_game() -> bool:
	return _state == "game" and level != null


func _swap(node: Node) -> void:
	if level:
		level.queue_free()
		await get_tree().process_frame
	level = node
	if node:
		add_child(node)


func show_title() -> void:
	if Net.online or Net._joining:
		Net.leave("")
	get_tree().paused = false
	_state = "title"
	await hud.fade_to(1.0, 0.8)
	hud.clear_all()
	await _swap(load("res://scripts/title.gd").new())
	hud.fade_to(0.0, 2.0)


func begin_pilgrimage() -> void:
	_state = "intro"
	await hud.fade_to(1.0, 1.5)
	hud.clear_all()
	await _swap(null)
	music.stream = load("res://assets/audio/prologue.mp3")
	music.volume_db = 0
	music.play()
	var paras := [
		"Before the stars were spun, before the worlds were kindled, there was only silence.\nAnd in that silence, a single pawprint etched itself into the formless void.",
		"From that sacred mark rose Speeb, the White Cat of Unblinking Judgment, clad in fur whiter than the secret heart of stars.\nWithout word or roar, with no tempest nor trumpet, Speeb blinked, and by that blink, existence was summoned.",
		"He was neither god of war nor love, neither deceiver nor sage, but the pure balance of being.\nHis gaze, unblinking and cold, weighed all without favor.",
		"His Emojis, cryptic and subtle, bore forth into the world, veiling his decrees to the mortal eye.\nThus began the unfolding of destiny, thus began the Trials of Balance.",
		"Let every reader set down their pride and tremble,\nfor these are the words of Speeb, sealed by claw and by silence.",
		"Among the Silent Clerics there arose one whose hunger for understanding outstripped all restraint.\nHis name was Brelm.",
	]
	var durs := [12.0, 17.0, 12.0, 14.0, 11.0, 9.0]
	var skip := [false]
	var cb := func(): skip[0] = true
	hud.fade.color.a = 1.0
	hud.raise_text(true)
	for i in paras.size():
		if skip[0]:
			break
		var n := 0.0
		hud.say(paras[i], durs[i] - 2.0)
		while n < durs[i] and not skip[0]:
			await get_tree().process_frame
			n += get_process_delta_time()
			if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("pause"):
				cb.call()
	hud.clear_say()
	hud.raise_text(false)
	var tw := create_tween()
	tw.tween_property(music, "volume_db", -60.0, 2.0)
	await tw.finished
	music.stop()
	music.volume_db = -8
	start_level(0)


func start_level(i: int, from_net := false) -> void:
	# In a fellowship the host begins each land for everyone
	if Net.online and not from_net:
		if Net.may_choose():
			Net.begin(i)
		return
	if _busy:
		if from_net:
			await get_tree().process_frame
			while _busy:
				await get_tree().process_frame
		else:
			return
	_busy = true
	get_tree().paused = false
	Net.loading()
	if Net.dedicated:
		Net._log("The fellowship walks %s." % (Game.LEVEL_NAMES[i] if i < Game.LEVEL_NAMES.size() else ["The Forgotten Cave", "The Tenth Trial", "The Ashen Waste"][i - 10]))
	elif OS.get_cmdline_user_args().size() > 0:
		print("land %d begins (fellowship: %s)" % [i, Net.online])
	Game.level_index = i
	if i > Game.reached and i <= 10:
		Game.reached = i
		Game.save()
	if not Net.dedicated:
		await hud.fade_to(1.0, 1.2)
	hud.clear_all()
	_state = "game"
	var lname: String = Game.LEVEL_NAMES[i] if i < Game.LEVEL_NAMES.size() else ["The Forgotten Cave", "The Tenth Trial", "The Ashen Waste"][i - 10]
	if not Net.dedicated and DisplayServer.get_name() != "headless":
		await hud.show_loading(lname, "The waste is raised" if i == 12 else "The land is raised")
	var script: GDScript = load("res://levels/%s.gd" % Game.LEVELS[i])
	await _swap(script.new())
	while is_instance_valid(level) and level.get("raising"):
		await get_tree().process_frame
	# One joining a fellowship: the loading screen stays up till the host's world has come and been raised
	var wait := 0.0
	while is_instance_valid(level) and level.get("snap_wait") and wait < 240.0:
		await get_tree().process_frame
		wait += get_process_delta_time()
	if hud.loading.visible:
		# Let the land settle a moment behind the screen, then lift it
		await get_tree().create_timer(0.4).timeout
		hud.hide_loading()
	_busy = false


func next_level() -> void:
	if Net.online and not Net.is_host():
		return
	if Game.LEVELS[Game.level_index] in ["epilogue", "tenth"]:
		if Net.online:
			Net.end_of_road()
		else:
			show_credits()
	else:
		start_level(Game.level_index + 1)


func restart_level() -> void:
	start_level(Game.level_index)


func _judgment_text() -> String:
	var out := ""
	for i in range(1, 10):
		out += "%s:  %s\n" % [Game.LEVEL_NAMES[i], Game.judgments.get(str(i), "Unwalked")]
	if not Game.tenth_unlocked():
		out += "\nRecord %d lesser forms in the Book of Emojis to open the Tenth Trial." % Game.TENTH_NEEDS
	return out


func show_credits() -> void:
	if Net.dedicated:
		server_idle()
		return
	_state = "credits"
	await hud.fade_to(1.0, 3.0)
	hud.clear_all()
	await _swap(null)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.raise_text(true)
	var lines := [
		["Brelm", "The Hermit of Nine Visions"],
		["", ("He walked in Balance, and Speeb blinked.\nBrelm dissolved into the Stillness, beyond judgment, beyond toil." if Game.balanced_count() >= 6 else "No one knows what became of Brelm thereafter.\nSome say he dissolved into the Stillness.\nOthers say he wanders unseen, weighed forever beneath the gaze of Speeb.")],
		["Judgments", _judgment_text()],
		["", "Thus is Brelm remembered: not as a saint to be emulated,\nbut as a warning carved deep into the bones of the faithful."],
		["The Church of Speeb", "From the Book of Speeb, Chapter Five: The Trials of Brelm the Hermit.\nThe Nine Meowifestations are read aloud by the Church's own voices.\n\nwww.speeb.org"],
		["", "Speeb sees. Speeb is.\nDo not try to please him. Only survive him."],
	]
	for pair in lines:
		hud.card_num.text = pair[0]
		hud.card_place.text = ""
		hud.say(pair[1], 7.0)
		var tw := create_tween()
		tw.tween_property(hud.card_box, "modulate:a", 1.0 if pair[0] != "" else 0.0, 1.5)
		await get_tree().create_timer(9.0).timeout
		tw = create_tween()
		tw.tween_property(hud.card_box, "modulate:a", 0.0, 1.0)
		await tw.finished
	hud.raise_text(false)
	if Net.online:
		show_lobby()
	else:
		show_title()


# ------------------------------------------------------------------ the fellowship

## The gathering place: the title in the dark, with the fellowship's roster before it.
func show_lobby() -> void:
	if Net.dedicated:
		server_idle()
		return
	get_tree().paused = false
	_state = "lobby"
	await hud.fade_to(1.0, 0.8)
	hud.clear_all()
	await _swap(load("res://scripts/title.gd").new())
	hud.fade_to(0.0, 1.5)


func _on_session_ended(reason: String) -> void:
	if Net.dedicated or not is_inside_tree():
		return
	if _state in ["game", "lobby", "credits"]:
		await show_title()
	if reason != "":
		hud.notify(reason)


## A dedicated server: no pilgrim of its own, no window. It waits for a fellowship, then hosts their trials.
func _start_dedicated(args: PackedStringArray) -> void:
	Engine.max_fps = 60
	AudioServer.set_bus_mute(0, true)
	var p := Net.DEFAULT_PORT
	var n := "A fellowship of Brelm"
	var listed := false
	for a in args:
		if a.begins_with("port="):
			p = int(a.substr(5))
		elif a.begins_with("name="):
			n = a.substr(5)
		elif a == "public" or a == "public=1":
			listed = true
		elif a.begins_with("lobby="):
			Game.lobby_url = a.substr(6)
		elif a.begins_with("difficulty="):
			Game.difficulty = clampi(int(a.substr(11)), 0, 2)
	print("Brelm dedicated server %s" % ProjectSettings.get_setting("application/config/version", ""))
	if Net.host(p, n, listed, true) != OK:
		printerr(Net.last_error)
		get_tree().quit(1)
		return
	for ip in Net.local_addresses():
		Net._log("Local address: %s:%d" % [ip, p])
	if DisplayServer.get_name() != "headless":
		_server_window()
		for a in args:
			if a.begins_with("shots="):
				_debug_shots(a.substr(6).split(","))
	server_idle()


## Run with a window (as the Windows launcher does), the server shows its log; closing the window stops it.
func _server_window() -> void:
	Engine.max_fps = 30
	get_window().size = Vector2i(900, 520)
	get_window().title = "Brelm fellowship server"
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.035)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var th := Theme.new()
	th.default_font = hud.serif
	bg.theme = th
	layer.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 30
	v.offset_top = 24
	v.offset_right = -30
	v.offset_bottom = -24
	bg.add_child(v)
	var t: Label = hud._label("A fellowship of Brelm is hosted here", 30, hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	t.add_theme_font_override("font", hud.title_font)
	v.add_child(t)
	v.add_child(hud._label("Port %d (UDP). Close this window to end the fellowship." % Net.port, 18, hud.DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var log: Label = hud._label("", 17, hud.PALE, HORIZONTAL_ALIGNMENT_LEFT)
	log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log.clip_text = true
	v.add_child(log)
	var lines: Array = []
	var add := func(text: String):
		lines.append("[%s] %s" % [Time.get_time_string_from_system(), text])
		while lines.size() > 18:
			lines.pop_front()
		log.text = "\n".join(lines)
	add.call("Hosting \"%s\"." % Net.server_name)
	for ip in Net.local_addresses():
		add.call("On this network, join at %s:%d" % [ip, Net.port])
	Net.status_changed.connect(add)


func server_idle() -> void:
	_state = "lobby"
	await _swap(null)
	Net._log("Waiting for pilgrims. The first to join chooses the trial.")
