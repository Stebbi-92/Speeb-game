extends Node3D
## The opening: the White Cat in the dark, unblinking.

var hud
var cam: Camera3D
var speeb: Emoji3D
var _t := 0.0
var _menu: VBoxContainer
var _chapters: VBoxContainer
var _together: VBoxContainer
var _lobby: VBoxContainer
var _filter: LineEdit
var _hide_full: CheckBox
var _hide_other: CheckBox
var _status: Label
var _found: VBoxContainer
var _roster: VBoxContainer
var _lobby_info: Label
var _choose: Control
var _col: VBoxContainer
var _spacer: Control
var _hint: Label
var _sub: Label
var _quote: Label
var _cam_off := 0.0

const PLACES := [
	"Prologue: The Plateau of Mirrors", "I. The Cliffs of Echoing Cries", "II. The Ruins of the Fallen Kings",
	"III. The Verdant Wastes", "IV. The Heights of Sorrows", "V. The Fields of Forgetting", "VI. The Mirror Caves",
	"VII. The Hollow of False Comfort", "VIII. The Sealed Stone", "IX. The Silent Lake", "The Forgotten Cave",
]


func _ready() -> void:
	hud = Game.main.hud
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.06)
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.035)
	env.fog_density = 0.04
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.8, 0.8, 0.85)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	speeb = Emoji3D.new().setup("_speeb", 3.2, 0.4)
	speeb.position = Vector3(0, 2.6, 0)
	speeb.glow = 0.15
	add_child(speeb)
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.4
	cm.bottom_radius = 1.6
	cm.height = 0.9
	ped.mesh = cm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.85, 0.85, 0.82)
	pm.roughness = 0.6
	ped.material_override = pm
	ped.position.y = 0.45
	add_child(ped)
	var floor_m := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(80, 80)
	floor_m.mesh = pl
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.05, 0.05, 0.055)
	fm.roughness = 0.15
	fm.metallic = 0.4
	floor_m.material_override = fm
	add_child(floor_m)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 9, 2)
	spot.rotation_degrees = Vector3(-80, 0, 0)
	spot.spot_angle = 22
	spot.light_energy = 6
	spot.spot_range = 20
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 3.0
	add_child(spot)
	cam = Camera3D.new()
	cam.position = Vector3(0, 2.4, 8.5)
	cam.fov = 50
	add_child(cam)
	cam.current = true
	var drone := AudioStreamPlayer.new()
	var s = load("res://assets/audio/drone.ogg")
	s.loop = true
	drone.stream = s
	drone.volume_db = -10
	drone.autoplay = true
	add_child(drone)
	_build_menu()


func _build_menu() -> void:
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.menu_box.add_child(box)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(110, -330)
	v.size = Vector2(620, 500)
	v.grow_vertical = Control.GROW_DIRECTION_END
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	var t: Label = hud._label("BRELM", 96, hud.PALE, HORIZONTAL_ALIGNMENT_LEFT)
	t.add_theme_font_override("font", hud.title_font)
	v.add_child(t)
	var st: Label = hud._label("The Hermit of Nine Visions", 34, hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	st.add_theme_font_override("font", hud.title_font)
	v.add_child(st)
	var sp := Control.new()
	sp.custom_minimum_size.y = 18
	v.add_child(sp)
	_col = v
	_spacer = sp
	_sub = st
	_menu = VBoxContainer.new()
	v.add_child(_menu)
	# The waste first: it is where the game is now. The trials and the pilgrim's own things wait one step in.
	var last := _last_world()
	if last != "":
		_menu.add_child(_btn("Continue", func(): _play_world(last)))
		_menu.add_child(_note("World %s   ·   %s" % [_roman(last), Wasteland.describe(last).split(", seed")[0]]))
	_menu.add_child(_btn("The Ashen Waste", _show_waste))
	_menu.add_child(_btn("Walk Together", _show_together))
	_menu.add_child(_btn("The Trials", func(): _open_sub(_trials)))
	_menu.add_child(_btn("Arms and Appearance", func(): _open_sub(_pilgrim)))
	_menu.add_child(_btn("Settings", func(): hud.show_options()))
	_menu.add_child(_btn("Leave", func(): hud.ask("Leave the game?", "Leave", func(): get_tree().quit())))
	_trials = _submenu(v, "The Trials")
	_trials.add_child(_btn("Begin the Pilgrimage", func(): Game.main.begin_pilgrimage(), 24))
	if Game.reached > 0:
		_trials.add_child(_btn("Return to a Trial", func(): _trials.visible = false; _show_chapters(), 24))
	if Game.tenth_unlocked():
		_trials.add_child(_btn("The Tenth Trial", func(): Game.main.start_level(11), 24))
	_trials.add_child(_btn("The Book of Emojis", func(): hud.toggle_codex(), 24))
	_trials.add_child(_back(_trials))
	_pilgrim = _submenu(v, "Arms and Appearance")
	_pilgrim.add_child(_btn("Arms", func(): hud.show_loadout(), 24))
	_pilgrim.add_child(_btn("Appearance", func():
		var a := AppearanceUI.new()
		a.hud = hud
		hud.root.add_child(a), 24))
	_pilgrim.add_child(_back(_pilgrim))
	_build_update(box)
	_chapters = VBoxContainer.new()
	_chapters.visible = false
	v.add_child(_chapters)
	for i in range(Game.reached + 1):
		var idx := i
		_chapters.add_child(_btn(PLACES[i], func(): Game.main.start_level(idx), 22))
	_chapters.add_child(_btn("Back", func(): _chapters.visible = false; _trials.visible = true, 22))
	_waste = VBoxContainer.new()
	_waste.visible = false
	_waste.add_theme_constant_override("separation", 4)
	v.add_child(_waste)
	_together = VBoxContainer.new()
	_together.visible = false
	_together.add_theme_constant_override("separation", 6)
	v.add_child(_together)
	_build_together()
	# The gathering place can grow long (four pilgrims, many trials): it scrolls within the screen
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	v.add_child(scroll)
	_lobby = VBoxContainer.new()
	_lobby.visible = false
	_lobby.add_theme_constant_override("separation", 4)
	_lobby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lobby)
	_lobby.visibility_changed.connect(func(): scroll.visible = _lobby.visible)
	Net.roster_changed.connect(_on_roster)
	Net.status_changed.connect(func(t): if _status: _status.text = t)
	Net.servers_changed.connect(_list_servers)
	if Net.online:
		_show_lobby.call_deferred()
	elif Net._joining or "together" in OS.get_cmdline_user_args():
		_show_together.call_deferred()
	elif "worlds" in OS.get_cmdline_user_args():
		_show_waste.call_deferred()

	var q: Label = hud._label("\"Speeb sees. Speeb is. Do not try to please him. Only survive him.\"\n— scratched in claw-marks upon a cave wall", 20, hud.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	q.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	q.position = Vector2(-900, -130)
	q.size = Vector2(860, 70)
	box.add_child(q)
	_quote = q
	var ver: Label = hud._label("v" + str(ProjectSettings.get_setting("application/config/version", "")), 14, hud.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	ver.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ver.position = Vector2(-140, 20)
	ver.size = Vector2(110, 24)
	box.add_child(ver)
	_hint = hud._label("", 15, hud.DIM, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_hint)


var _trials: VBoxContainer
var _pilgrim: VBoxContainer


func _submenu(parent: Control, title: String) -> VBoxContainer:
	var sub := VBoxContainer.new()
	sub.visible = false
	sub.add_theme_constant_override("separation", 2)
	parent.add_child(sub)
	sub.add_child(_heading(title))
	return sub


func _open_sub(sub: Control) -> void:
	_menu.visible = false
	sub.visible = true


func _back(sub: Control) -> Button:
	return _btn("Back", func(): sub.visible = false; _menu.visible = true, 20)


func _note(text: String) -> Label:
	var l := _small("     " + text, hud.DIM, 15)
	return l


static func _roman(slot: String) -> String:
	return ["I", "II", "III"][clampi(int(slot) - 1, 0, 2)]


## The world walked most lately, if any.
func _last_world() -> String:
	var best := ""
	var bt := 0
	for i in 3:
		var slot := str(i + 1)
		var path := ProjectSettings.globalize_path(Wasteland.world_path(slot))
		if FileAccess.file_exists(Wasteland.world_path(slot)):
			var t := FileAccess.get_modified_time(path)
			if t > bt:
				bt = t
				best = slot
	return best


func _play_world(slot: String, seed_text := "") -> void:
	Game.world_slot = slot
	Game.new_world_seed = 0
	var t := seed_text.strip_edges()
	if t.is_valid_int():
		Game.new_world_seed = absi(int(t))
	elif t != "":
		Game.new_world_seed = absi(t.hash()) % 99999999 + 1
	Game.main.start_level(Game.WASTELAND)


func _btn(text: String, cb: Callable, size := 27) -> Button:
	var b: Button = hud.button(text, cb, size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


var _waste: VBoxContainer


## The open waste: three worlds may be kept, each with its own days, beacons and shelters.
## Each can be walked, set aside as a file (export), or forgotten (deleted, after asking).
func _show_waste() -> void:
	_menu.visible = false
	_waste.visible = true
	for c in _waste.get_children():
		c.queue_free()
	_waste.add_child(_heading("The Ashen Waste"))
	_waste.add_child(_small("Gather, build and live through the nights,\nwhile nine dead beacons wait to be kindled."))
	var sp := Control.new()
	sp.custom_minimum_size.y = 8
	_waste.add_child(sp)
	for i in 3:
		_waste.add_child(_world_card(str(i + 1)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.add_child(_btn("Open the saves folder", func(): OS.shell_open(ProjectSettings.globalize_path("user://wasteland")), 18))
	row.add_child(_btn("Back", func(): _waste.visible = false; _menu.visible = true, 20))
	_waste.add_child(row)


func _world_card(slot: String) -> Control:
	var d := Wasteland.describe(slot)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.02, 0.7)
	sb.border_color = Color(hud.GOLD, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(540, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var name := _small("World %s" % _roman(slot), hud.PALE, 24)
	name.add_theme_font_override("font", hud.title_font)
	v.add_child(name)
	v.add_child(_small(d if d != "" else "Not yet walked", hud.DIM, 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	v.add_child(row)
	if d == "":
		var seed_e := _field("", "Seed (optional)", 200)
		row.add_child(_btn("Begin", func(): _play_world(slot, seed_e.text), 20))
		row.add_child(seed_e)
	else:
		row.add_child(_btn("Walk", func(): _play_world(slot), 20))
		row.add_child(_btn("Export", func(): _export_world(slot), 18))
		row.add_child(_btn("Delete", func():
			hud.ask("Delete World %s for good?" % _roman(slot), "Delete", func(): _delete_world(slot); _show_waste()), 18))
	return card


## Copies a world (and the pilgrims kept in it) into a zip in Documents/Brelm, and shows where.
func _export_world(slot: String) -> void:
	var d = Game.read_var_safe(Wasteland.world_path(slot))
	var uid: String = str(d.get("uid", "")) if d is Dictionary else ""
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("Brelm")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", " ")
	var out := dir.path_join("Brelm World %s %s.zip" % [_roman(slot), stamp])
	var zip := ZIPPacker.new()
	if zip.open(out) != OK:
		_hint_text("Could not write to %s." % dir)
		return
	var files := [Wasteland.world_path(slot)]
	if uid != "":
		for f in DirAccess.get_files_at("user://wasteland"):
			if f.begins_with("char_%s" % uid):
				files.append("user://wasteland/" + f)
	for f in files:
		zip.start_file(f.get_file())
		zip.write_file(FileAccess.get_file_as_bytes(f))
		zip.close_file()
	zip.close()
	_hint_text("Saved to %s" % out)
	OS.shell_show_in_file_manager(out)


func _delete_world(slot: String) -> void:
	for ext in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(Wasteland.world_path(slot) + ext)


func _hint_text(t: String) -> void:
	if _status:
		_status.text = t
	hud.notify(t)


func _show_chapters() -> void:
	_menu.visible = false
	_chapters.visible = true


# ------------------------------------------------------------------ a newer version

var _upd: VBoxContainer
var _upd_text: Label
var _upd_btn: Button


func _build_update(box: Control) -> void:
	_upd = VBoxContainer.new()
	_upd.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_upd.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_upd.position = Vector2(-470, 50)
	_upd.custom_minimum_size = Vector2(440, 0)
	_upd.add_theme_constant_override("separation", 6)
	box.add_child(_upd)
	_upd_text = _small("", hud.GOLD, 17)
	_upd_text.custom_minimum_size.x = 440
	_upd_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_upd_text.visible = false
	_upd.add_child(_upd_text)
	_upd_btn = _btn("", _update_pressed, 20)
	_upd_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_upd_btn.visible = false
	_upd.add_child(_upd_btn)
	Updater.checked.connect(_update_shown)
	Updater.progress.connect(_update_progress)
	Updater.finished.connect(_update_done)
	_update_shown()


func _update_shown() -> void:
	if not is_instance_valid(_upd_text):
		return
	if Updater.staged != "":
		_upd_text.text = "Version %s waits. Restart to walk it." % Updater.staged
		_upd_btn.text = "Restart now"
	elif Updater.can_patch:
		var mb := int(Updater.latest.pack_size) / 1048576.0
		_upd_text.text = "%s has come.%s" % [_vname(), (" (%.0f MB)" % mb) if mb > 0 else ""]
		_upd_btn.text = "Update"
	elif Updater.available:
		_upd_text.text = "%s has come. This one must be downloaded whole." % _vname()
		_upd_btn.text = "Open the download page"
	else:
		_upd_text.visible = false
		_upd_btn.visible = false
		return
	_upd_text.visible = true
	_upd_btn.visible = true
	_upd_btn.disabled = false


func _vname() -> String:
	var n: String = Updater.latest.get("name", "")
	return n if n != "" else "Version " + str(Updater.latest.get("version", ""))


func _update_pressed() -> void:
	if Updater.staged != "":
		Updater.restart()
	elif Updater.can_patch:
		_upd_btn.disabled = true
		_upd_text.text = "Fetching..."
		Updater.download()
	elif Updater.available and Updater.latest.get("page", "") != "":
		OS.shell_open(Updater.latest.page)


func _update_progress(done: int, total: int) -> void:
	if is_instance_valid(_upd_text):
		_upd_text.text = "Fetching... %d%%" % int(100.0 * done / maxi(total, 1))


func _update_done(ok: bool, message: String) -> void:
	if not is_instance_valid(_upd_text):
		return
	_upd_text.text = message
	_upd_btn.disabled = false
	if ok:
		_upd_btn.text = "Restart now"
	else:
		_upd_btn.text = "Try again"


func _process(delta: float) -> void:
	_t += delta
	speeb.rotation.y = sin(_t * 0.15) * 0.35
	# Speeb steps aside when a wide panel opens beside him
	var aside: bool = (_col and _col.position.y < _col.get_parent().size.y * 0.5 - 380.0) or (_waste and _waste.visible)
	_cam_off = lerpf(_cam_off, -4.2 if aside else 0.0, minf(1.0, delta * 3.0))
	cam.position.x = sin(_t * 0.07) * 1.2 + _cam_off
	cam.look_at(Vector3(_cam_off, 2.6, 0))


# ------------------------------------------------------------------ walking together

func _small(text: String, color := Color(0.62, 0.60, 0.56), size := 18) -> Label:
	var l: Label = hud._label(text, size, color, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 520
	return l


func _field(value: String, hint: String, width := 260) -> LineEdit:
	var e := LineEdit.new()
	e.text = value
	e.placeholder_text = hint
	e.custom_minimum_size = Vector2(width, 36)
	e.add_theme_font_size_override("font_size", 19)
	return e


func _heading(text: String) -> Label:
	var l: Label = hud._label(text, 24, hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	l.add_theme_font_override("font", hud.title_font)
	return l


func _build_together() -> void:
	_together.add_child(_heading("Walk Together"))
	_together.add_child(_small("Up to four can play together, in the Ashen Waste or the trials. One hosts; the others join."))
	var nh := HBoxContainer.new()
	nh.add_child(_small("Your name", hud.PALE, 19))
	nh.get_child(0).custom_minimum_size.x = 150
	var name_e := _field(Game.player_name, "Pilgrim", 260)
	name_e.text_changed.connect(func(t): Game.player_name = t.strip_edges().left(20); Game.save())
	nh.add_child(name_e)
	_together.add_child(nh)
	# Hosting
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	var sname := _field("", "Name of the fellowship", 250)
	var port := _field(str(Net.DEFAULT_PORT), "Port", 90)
	hh.add_child(sname)
	hh.add_child(port)
	_together.add_child(hh)
	# Who may find it: one plain choice, and a line that says what it means
	var vis := ["public" if Net.lobby_url() != "" else "network"]
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 6)
	vrow.add_child(_small("Who can find it", hud.PALE, 17))
	vrow.get_child(0).custom_minimum_size.x = 150
	var vnote := _small("", hud.DIM, 16)
	var group := ButtonGroup.new()
	var notes := {"public": "Shown in the server list on the internet. Anyone can join, or use the code.",
		"network": "Shown to players on your own network. Friends elsewhere join with the code.",
		"private": "Not shown anywhere. Friends join with the code or your address."}
	for opt in [["public", "Everyone"], ["network", "My network"], ["private", "Only with the code"]]:
		var b := Button.new()
		b.text = opt[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", hud.DIM)
		b.add_theme_color_override("font_pressed_color", hud.GOLD)
		b.add_theme_color_override("font_hover_pressed_color", hud.GOLD)
		b.add_theme_color_override("font_hover_color", hud.PALE)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sb := StyleBoxFlat.new()
			var on: bool = st in ["pressed", "hover_pressed"]
			sb.bg_color = Color(hud.GOLD, 0.16) if on else Color(1, 1, 1, 0.08 if st == "hover" else 0.03)
			sb.border_color = Color(hud.GOLD, 0.7) if on else Color(1, 1, 1, 0.12)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(12)
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			sb.content_margin_top = 3
			sb.content_margin_bottom = 3
			b.add_theme_stylebox_override(st, sb)
		var key: String = opt[0]
		if key == "public" and Net.lobby_url() == "":
			b.disabled = true
			b.tooltip_text = "Set an internet list address in Settings to list games publicly."
		b.button_pressed = key == vis[0]
		b.toggled.connect(func(on): if on: vis[0] = key; vnote.text = notes[key])
		vrow.add_child(b)
	vnote.text = notes[vis[0]]
	_together.add_child(vrow)
	_together.add_child(vnote)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 8)
	var word := _field("", "A word to join (optional)", 250)
	word.secret = true
	ph.add_child(word)
	_together.add_child(ph)
	_together.add_child(_btn("Host a fellowship", func():
		var n: String = sname.text.strip_edges()
		if n == "":
			n = "%s's fellowship" % Net.my_name()
		var p := int(port.text) if port.text.is_valid_int() else Net.DEFAULT_PORT
		if Net.host(p, n, vis[0] == "public", false, vis[0] == "private", word.text) == OK:
			_show_lobby()
		else:
			_status.text = Net.last_error, 24))
	# Joining by address
	var jh := HBoxContainer.new()
	jh.add_theme_constant_override("separation", 8)
	var addr := _field("", "Join code, or address:port", 300)
	var jword := _field("", "Its word, if closed", 200)
	jword.secret = true
	jh.add_child(addr)
	jh.add_child(jword)
	jh.add_child(_btn("Join", func():
		Net.join_word = jword.text.strip_edges()
		var t: String = addr.text.strip_edges()
		if t == "":
			_status.text = "Give the host's join code or address. They will find both in their gathering place."
			return
		if Net.is_code(t):
			Net.join_code_lookup(t)
			return
		var hp := Net.split_address(t)
		Net.join(hp[0], hp[1]), 24))
	_together.add_child(jh)
	# The list of fellowships
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 10)
	lh.add_child(_heading("Fellowships found"))
	lh.add_child(_btn("Look again", func(): Net.refresh_servers(), 20))
	_together.add_child(lh)
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 10)
	_filter = _field("", "Search by name", 220)
	_filter.text_changed.connect(func(_t): _list_servers())
	fh.add_child(_filter)
	_hide_full = CheckBox.new()
	_hide_full.text = "Hide full"
	_hide_full.add_theme_font_size_override("font_size", 16)
	_hide_full.toggled.connect(func(_on): _list_servers())
	fh.add_child(_hide_full)
	_hide_other = CheckBox.new()
	_hide_other.text = "Only my version"
	_hide_other.button_pressed = true
	_hide_other.add_theme_font_size_override("font_size", 16)
	_hide_other.toggled.connect(func(_on): _list_servers())
	fh.add_child(_hide_other)
	_together.add_child(fh)
	_found = VBoxContainer.new()
	_found.add_theme_constant_override("separation", 0)
	_together.add_child(_found)
	_status = _small("")
	_status.add_theme_color_override("font_color", hud.GOLD)
	_together.add_child(_status)
	_together.add_child(_btn("Back", func(): _together.visible = false; _menu.visible = true; _raise_column(false), 22))


## The fellowship's pages are long: the column rises to make room for them.
func _raise_column(up: bool) -> void:
	_col.position.y = _col.get_parent().size.y * 0.5 + (-430.0 if up else -330.0)
	_spacer.visible = not up
	_sub.visible = not up
	_hint.visible = not up
	_quote.visible = not up


func _show_together() -> void:
	_raise_column(true)
	_menu.visible = false
	_chapters.visible = false
	_lobby.visible = false
	_together.visible = true
	if Net.last_error != "" and not Net._joining:
		_status.text = Net.last_error
	Net.refresh_servers()
	_list_servers()


func _list_servers() -> void:
	if _found == null:
		return
	for c in _found.get_children():
		c.queue_free()
	if Net.servers.is_empty():
		_found.add_child(_small("None yet. Fellowships on this network appear here, and public ones from the internet list. A private fellowship is joined by its code."))
		return
	var keys: Array = Net.servers.keys()
	# The fullest open fellowships first, then the nearest
	keys.sort_custom(func(a, b):
		var da: Dictionary = Net.servers[a]
		var db: Dictionary = Net.servers[b]
		if int(da.get("players", 0)) != int(db.get("players", 0)):
			return int(da.get("players", 0)) > int(db.get("players", 0))
		return int(da.get("ping", 9999)) < int(db.get("ping", 9999)))
	var shown := 0
	for key in keys:
		var d: Dictionary = Net.servers[key]
		var q: String = _filter.text.strip_edges().to_lower() if _filter else ""
		if q != "" and not str(d.get("name", "")).to_lower().contains(q):
			continue
		if _hide_full and _hide_full.button_pressed and int(d.get("players", 0)) >= int(d.get("max", 4)):
			continue
		if _hide_other and _hide_other.button_pressed and d.get("proto", Net.PROTOCOL) != Net.PROTOCOL:
			continue
		shown += 1
		var lvl := int(d.get("level", -1))
		var where: String = "gathering" if lvl < 0 or lvl >= PLACES.size() else PLACES[lvl].get_slice(":", 0).get_slice(".", 0)
		if lvl >= 0 and lvl < PLACES.size():
			where = PLACES[lvl]
		var full := int(d.get("players", 0)) >= int(d.get("max", 4))
		var src: String = d.get("source", "")
		if d.has("ping"):
			src += " %d ms" % int(d.ping)
		var text := "%s%s   ·   %d of %d   ·   %s   ·   %s" % [str(d.get("name", "?")).left(28), "  (closed)" if d.get("locked", false) else "", int(d.get("players", 0)), int(d.get("max", 4)), where, src]
		if d.get("proto", Net.PROTOCOL) != Net.PROTOCOL:
			text += "   ·   version %s" % d.get("version", "?")
		var ip: String = d.ip
		var p := int(d.port)
		var b := _btn(text, func(): Net.join(ip, p), 19)
		b.disabled = full or d.get("proto", Net.PROTOCOL) != Net.PROTOCOL
		_found.add_child(b)
	if shown == 0:
		_found.add_child(_small("None match what you seek."))


func _show_lobby() -> void:
	_raise_column(true)
	_menu.visible = false
	_chapters.visible = false
	_together.visible = false
	_lobby.visible = true
	_on_roster()


func _on_roster() -> void:
	if not Net.online:
		if _lobby.visible:
			_lobby.visible = false
			_menu.visible = true
			_raise_column(false)
		return
	if not _lobby.visible:
		_show_lobby()
		return
	for c in _lobby.get_children():
		c.queue_free()
	_lobby.add_child(_heading(Net.server_name))
	var info := ""
	if Net.is_host():
		info = "You are hosting on port %d." % Net.port
		var locals := Net.local_addresses()
		if not locals.is_empty():
			info += "\nOn this network, others join at: %s" % ", ".join(locals.map(func(a): return "%s:%d" % [a, Net.port]))
		if Net.external_ip != "":
			info += "\nFrom the internet: %s:%d" % [Net.external_ip, Net.port]
		if Net.upnp_state != "":
			info += "\n" + Net.upnp_state
		if Net.password != "":
			info += "\nClosed: those who join must give its word."
	else:
		info = "You walk with this fellowship. The host decides the way."
	if Net.is_host() and Net.join_code != "" and Net.lobby_url() != "":
		var cl: Label = hud._label("Join code   %s" % Net.join_code, 26, hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		cl.add_theme_font_override("font", hud.title_font)
		cl.tooltip_text = "Friends type this into Walk Together to join, from anywhere."
		_lobby.add_child(cl)
		var cb := _btn("Copy the code", func(): DisplayServer.clipboard_set(Net.join_code), 17)
		_lobby.add_child(cb)
	_lobby.add_child(_small(info))
	_lobby.add_child(_heading("The fellowship  (%d of %d)" % [Net.players.size(), Net.MAX_PLAYERS]))
	for id in Net.players:
		var mark := ""
		if id == 1:
			mark = "  · host"
		elif id == Net.leader and Net.leader != 1:
			mark = "  · chooses the way"
		if id == Net.me():
			mark += "  · you"
		var l := _small(Net.name_of(id) + mark, Net.color_of(id).lightened(0.25), 21)
		l.add_theme_font_override("font", hud.title_font)
		_lobby.add_child(l)
	if Net.may_choose():
		_lobby.add_child(_heading("Choose the trial"))
		if Net.is_host():
			var o := OptionButton.new()
			for d in Game.DIFFICULTIES:
				o.add_item(d)
			o.selected = Game.difficulty
			o.custom_minimum_size.x = 220
			o.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			o.add_theme_font_size_override("font_size", 18)
			o.item_selected.connect(func(i): Game.difficulty = i; Game.save())
			_lobby.add_child(o)
			var ua := CheckBox.new()
			ua.text = "Unlimited ammunition"
			ua.button_pressed = Game.unlimited_ammo
			ua.add_theme_font_size_override("font_size", 18)
			ua.tooltip_text = "Guns are still reloaded, but never spend their reserve. For everyone in the fellowship."
			ua.toggled.connect(func(on): Game.unlimited_ammo = on; Game.save(); Net.send_rules())
			_lobby.add_child(ua)
		var grid := GridContainer.new()
		grid.columns = 2
		_lobby.add_child(grid)
		for i in range(mini(Game.reached, 10) + 1):
			var idx := i
			grid.add_child(_btn(PLACES[i], func(): Net.begin(idx), 17))
		if Game.tenth_unlocked():
			grid.add_child(_btn("The Tenth Trial", func(): Net.begin(11), 18))
		if Net.is_host():
			_lobby.add_child(_heading("Or walk the open waste"))
			var wh := HBoxContainer.new()
			wh.add_theme_constant_override("separation", 10)
			var ws := OptionButton.new()
			for i in 3:
				var d := Wasteland.describe(str(i + 1))
				ws.add_item("World %s  (%s)" % [["I", "II", "III"][i], d if d != "" else "unwalked"])
			ws.selected = int(Game.world_slot) - 1
			ws.add_theme_font_size_override("font_size", 17)
			ws.item_selected.connect(func(i): Game.world_slot = str(i + 1))
			wh.add_child(ws)
			wh.add_child(_btn("The Ashen Waste", func(): Net.begin(Game.WASTELAND), 18))
			_lobby.add_child(wh)
	else:
		_lobby.add_child(_small("Waiting for the host to choose a trial.", hud.PALE, 19))
	_lobby.add_child(_btn("Leave the fellowship", func(): Net.leave(""); _lobby.visible = false; _menu.visible = true; _raise_column(false), 22))
