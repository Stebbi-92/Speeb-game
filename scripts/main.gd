extends Node
## Holds the HUD and swaps the land Brelm walks in.

const Hud := preload("res://scripts/hud.gd")

var hud
var level: Node = null
var music: AudioStreamPlayer
var _busy := false
var _state := "title"


func _ready() -> void:
	Game.main = self
	hud = Hud.new()
	add_child(hud)
	music = AudioStreamPlayer.new()
	music.volume_db = -8
	add_child(music)
	var args := OS.get_cmdline_user_args()
	var lvl := -1
	for a in args:
		if a.begins_with("level="):
			lvl = int(a.substr(6))
		elif a.begins_with("pos="):
			_debug_pos = a.substr(4).split_floats(",")
	for a in args:
		if a.begins_with("call="):
			_debug_call(a.substr(5))
		if a.begins_with("shots="):
			_debug_shots(a.substr(6).split(","))
	if lvl >= 0:
		start_level(lvl)
	else:
		show_title()
	if "options" in args:
		hud.show_options.call_deferred()


var _debug_pos := PackedFloat64Array()


## Testing aid: calls a method on the level once it has loaded.
func _debug_call(method: String) -> void:
	while not (level and level.get("player")):
		await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	level.call(method)


## Testing aid: saves screenshots at the given seconds, then quits.
func _debug_shots(times: PackedStringArray) -> void:
	var t0 := 0.0
	while _debug_pos.size() >= 4:
		await get_tree().process_frame
		t0 += get_process_delta_time()
		if level and level.get("player") and level.player.is_inside_tree():
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


func start_level(i: int) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	Game.level_index = i
	if i > Game.reached and i <= 10:
		Game.reached = i
		Game.save()
	await hud.fade_to(1.0, 1.2)
	hud.clear_all()
	_state = "game"
	var script: GDScript = load("res://levels/%s.gd" % Game.LEVELS[i])
	await _swap(script.new())
	_busy = false


func next_level() -> void:
	if Game.LEVELS[Game.level_index] in ["epilogue", "tenth"]:
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
	show_title()
