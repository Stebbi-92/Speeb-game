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

## Stills of the waste behind the menu (title_backdrop.gd); false shows the White Cat on his stone instead.
const BACKDROP := true

const PLACES := [
	"Prologue: The Plateau of Mirrors", "I. The Cliffs of Echoing Cries", "II. The Ruins of the Fallen Kings",
	"III. The Verdant Wastes", "IV. The Heights of Sorrows", "V. The Fields of Forgetting", "VI. The Mirror Caves",
	"VII. The Hollow of False Comfort", "VIII. The Sealed Stone", "IX. The Silent Lake", "The Forgotten Cave",
]


func _ready() -> void:
	Updater.mark_booted()   # the game reached its title: the version it runs on starts here
	hud = Game.main.hud
	Game.report.offer.call_deferred(hud)
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
	# A looping copy: the loaded file is shared, and nightfall plays the same drone once
	var s = load("res://assets/audio/drone.ogg").duplicate()
	s.loop = true
	drone.stream = s
	drone.volume_db = -10
	drone.autoplay = true
	add_child(drone)
	# Quiet music under the drone, on the Music slider
	var tune := AudioStreamPlayer.new()
	var ts = load("res://assets/music/dawn.ogg")
	if ts:
		ts.loop = true
		tune.stream = ts
		tune.bus = "Music"
		tune.volume_db = -19
		tune.autoplay = true
		add_child(tune)
	_candles()
	_build_menu()


## Around the White Cat's stone, one small flame for each beacon burning in the last world walked.
func _candles() -> void:
	var last := _last_world()
	if last == "":
		return
	var d = Game.read_var_safe(Wasteland.world_path(last))
	var n: int = d.get("lit", []).size() if d is Dictionary else 0
	for i in mini(n, 9):
		var a := TAU * (float(i) / 9.0) + PI * 0.5
		var c := Node3D.new()
		c.position = Vector3(cos(a) * 2.3, 0.0, sin(a) * 2.3)
		add_child(c)
		var wax := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.08
		cm.height = 0.32
		wax.mesh = cm
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(0.85, 0.82, 0.74)
		wax.material_override = wm
		wax.position.y = 0.16
		c.add_child(wax)
		var flame := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.14
		flame.mesh = sm
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(1.0, 0.75, 0.35)
		fm.emission_enabled = true
		fm.emission = Color(1.0, 0.6, 0.2)
		fm.emission_energy_multiplier = 3.0
		flame.material_override = fm
		flame.position.y = 0.39
		c.add_child(flame)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.65, 0.3)
		l.light_energy = 0.5
		l.omni_range = 1.6
		l.position.y = 0.45
		c.add_child(l)


func _build_menu() -> void:
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.menu_box.add_child(box)
	if BACKDROP:
		box.add_child(load("res://scripts/title_backdrop.gd").new())
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
		_menu.add_child(_said(_btn("Continue", func(): _play_world(last), 32), "Back to World %s, where you left it." % _roman(last)))
		_menu.add_child(_note("World %s   ·   %s" % [_roman(last), Wasteland.describe(last).split(", seed")[0]]))
	_menu.add_child(_said(_btn("The Ashen Waste", _show_waste), "The open world. Start a new world or go back to one of your three."))
	_menu.add_child(_said(_btn("Walk Together", _show_together), "Play with friends: host a game, join with a code, or find one."))
	_menu.add_child(_said(_btn("The Trials", func(): _open_sub(_trials)), "The nine story trials, one after another."))
	_menu.add_child(_said(_btn("Appearance", _open_look), "Choose how you look: face, colours and clothes."))
	_menu.add_child(_said(_btn("Settings", func(): hud.show_options()), "Controls, sound, graphics and more."))
	_menu.add_child(_said(_btn("Leave", func(): hud.ask("Leave the game?", "Leave", func(): get_tree().quit())), "Close the game."))
	_desc = _small("", Color(0.78, 0.74, 0.66), 18)
	_desc.custom_minimum_size.y = 30
	_menu.add_child(_desc)
	_trials = _submenu(v, "The Trials")
	_trials.add_child(_btn("Begin the Pilgrimage", func(): Game.main.begin_pilgrimage(), 24))
	if Game.reached > 0:
		_trials.add_child(_btn("Return to a Trial", func(): _trials.visible = false; _show_chapters(), 24))
	if Game.tenth_unlocked():
		_trials.add_child(_btn("The Tenth Trial", func(): Game.main.start_level(11), 24))
	_trials.add_child(_btn("Arms for the trials", func(): hud.show_loadout(), 24))
	_trials.add_child(_btn("The Book of Emojis", func(): hud.toggle_codex(), 24))
	_trials.add_child(_back(_trials))
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
	# With a controller, each page opens with its first line chosen
	for c in [_menu, _trials, _chapters, _waste, _together, _lobby]:
		var page: Control = c
		page.visibility_changed.connect(func(): if page.visible: hud._focus_first.call_deferred(page))
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


var _desc: Label


## A menu line that says what it does, under the menu, while it is pointed at or chosen
func _said(b: Button, what: String) -> Button:
	var show := func(): if is_instance_valid(_desc): _desc.text = what
	b.mouse_entered.connect(show)
	b.focus_entered.connect(show)
	b.mouse_exited.connect(func(): if is_instance_valid(_desc) and _desc.text == what and not b.has_focus(): _desc.text = "")
	return b


func _open_look() -> void:
	var a := AppearanceUI.new()
	a.hud = hud
	hud.root.add_child(a)


## Escape or B: one page back toward the main menu. A gathering is left only with its own Leave.
func back() -> bool:
	if _lobby.visible:
		return false
	if _chapters.visible:
		_chapters.visible = false
		_trials.visible = true
		return true
	if _together.visible:
		_together.visible = false
		_menu.visible = true
		_raise_column(false)
		return true
	for sub in [_trials, _waste]:
		if sub.visible:
			sub.visible = false
			_menu.visible = true
			return true
	return false


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
	row.add_child(_btn("Open the saves folder (in a new window)", func(): OS.shell_open(ProjectSettings.globalize_path("user://wasteland")), 18))
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
		var rules := [{}]
		row.add_child(_btn("Begin", func(): Game.new_world_rules = rules[0]; _play_world(slot, seed_e.text), 20))
		row.add_child(seed_e)
		row.add_child(_btn("Settings", func(): hud.show_rules(rules[0], true, func(r): rules[0] = r, true), 18))
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
	for ext in ["", ".bak", ".tmp", ".damaged", ".bak.damaged", ".tmp.damaged"]:
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
	var aside: bool = (is_instance_valid(_col) and _col.get_parent() and _col.position.y < _col.get_parent().size.y * 0.5 - 380.0) or (is_instance_valid(_waste) and _waste.visible)
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
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 16)
	th.add_child(_heading("Walk Together"))
	var intro := _plain("Up to eight in the Ashen Waste, four in the trials. One hosts; the others join.", hud.DIM, 16)
	intro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(intro)
	_together.add_child(th)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 10)
	var nl := _plain("Your name", hud.PALE, 18)
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nh.add_child(nl)
	var name_e := _field(Game.player_name, "Pilgrim", 260)
	name_e.text_changed.connect(func(t): Game.player_name = t.strip_edges().left(20); Game.save())
	nh.add_child(name_e)
	_together.add_child(nh)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	cards.custom_minimum_size.x = BROWSER_W
	_together.add_child(cards)
	# Hosting
	var hc := _side_card("Host a game", 470)
	cards.add_child(hc[0])
	var hv: VBoxContainer = hc[1]
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	var sname := _field("", "Name of the game", 430)
	var port := _field(str(Net.DEFAULT_PORT), "Port", 90)
	for f in [sname, port]:
		f.custom_minimum_size.y = 32
		f.add_theme_font_size_override("font_size", 16)
	hh.add_child(sname)
	hv.add_child(hh)
	# Who may find it: one plain choice, and a line that says what it means
	var vis := ["public" if Net.lobby_url() != "" else "network"]
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 6)
	var vnote := _small("", hud.DIM, 14)
	vnote.custom_minimum_size.x = 430
	var group := ButtonGroup.new()
	var notes := {"public": "Shown in the list on the internet. Anyone can join, or use the code.",
		"network": "Shown on your own network. Friends elsewhere join with the code.",
		"private": "Not shown anywhere. Friends join with the code or your address."}
	for opt in [["public", "Everyone"], ["network", "My network"], ["private", "Only with the code"]]:
		var b := Button.new()
		b.text = opt[1]
		b.toggle_mode = true
		b.button_group = group
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", hud.DIM)
		b.add_theme_color_override("font_pressed_color", hud.GOLD)
		b.add_theme_color_override("font_hover_pressed_color", hud.GOLD)
		b.add_theme_color_override("font_hover_color", hud.PALE)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var on: bool = st in ["pressed", "hover_pressed"]
			b.add_theme_stylebox_override(st, _box(Color(hud.GOLD, 0.16) if on else Color(1, 1, 1, 0.08 if st == "hover" else 0.03), Color(hud.GOLD, 0.7) if on else Color(1, 1, 1, 0.12), 12, 12, 3))
		var key: String = opt[0]
		if key == "public" and Net.lobby_url() == "":
			b.disabled = true
			b.tooltip_text = "Set an internet list address in Settings to list games publicly."
		b.button_pressed = key == vis[0]
		b.toggled.connect(func(on): if on: vis[0] = key; vnote.text = notes[key])
		vrow.add_child(b)
	vnote.text = notes[vis[0]]
	hv.add_child(vrow)
	hv.add_child(vnote)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	var word := _field("", "A word to join (optional)", 250)
	word.secret = true
	word.custom_minimum_size.y = 32
	word.add_theme_font_size_override("font_size", 16)
	ph.add_child(word)
	ph.add_child(_pill("Host", func():
		var n: String = sname.text.strip_edges()
		if n == "":
			n = "%s's fellowship" % Net.my_name()
		var p := int(port.text) if port.text.is_valid_int() else Net.DEFAULT_PORT
		if Net.host(p, n, vis[0] == "public", false, vis[0] == "private", word.text) == OK:
			_show_lobby()
		else:
			_status.text = Net.last_error, hud.GOLD, 17))
	hv.add_child(ph)
	# Rarely needed: the port, behind "Advanced"
	var adv := HBoxContainer.new()
	adv.add_theme_constant_override("separation", 8)
	adv.visible = false
	var pl := _plain("Port (only if your router needs a set one)", hud.DIM, 14)
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	adv.add_child(pl)
	adv.add_child(port)
	var more := _pill("Advanced", func(): pass, hud.DIM, 14)
	more.pressed.connect(func(): adv.visible = not adv.visible; more.text = "Fewer options" if adv.visible else "Advanced")
	more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hv.add_child(more)
	hv.add_child(adv)
	# Joining by code or address
	var jc := _side_card("Join by code", 336)
	jc[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(jc[0])
	var jv: VBoxContainer = jc[1]
	var addr := _field("", "Join code, or address:port", 300)
	var jword := _field("", "Its word, if closed", 300)
	jword.secret = true
	_jword = jword
	addr.custom_minimum_size.y = 46
	addr.add_theme_font_size_override("font_size", 22)
	jword.custom_minimum_size.y = 32
	jword.add_theme_font_size_override("font_size", 16)
	jv.add_child(addr)
	jv.add_child(jword)
	var jl := _small("The host finds the six-letter code in their gathering place.", hud.DIM, 14)
	jl.custom_minimum_size.x = 300
	jv.add_child(jl)
	jv.add_child(_pill("Join", func():
		Net.join_word = jword.text.strip_edges()
		var t: String = addr.text.strip_edges()
		if t == "":
			_status.text = "Give the host's join code or address. They will find both in their gathering place."
			return
		if Net.is_code(t):
			Net.join_code_lookup(t)
			return
		var hp := Net.split_address(t)
		Net.join(hp[0], hp[1]), hud.GOLD, 17))
	jv.get_child(jv.get_child_count() - 1).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cards.move_child(jc[0], 0)   # joining a friend is what most come here for: it comes first
	# The list of fellowships: a framed browser, one card to each, with how full it is at a glance
	_together.add_child(_browser())
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
	_looked_t = Time.get_ticks_msec()
	Net.refresh_servers()
	_list_servers()


## The browser's frame: a heading with the count, the filters and the sort, the column names, and
## a scrolling list beneath. Filled by _list_servers each time the list changes.
func _browser() -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color(0.03, 0.025, 0.02, 0.82), Color(hud.GOLD, 0.28), 6, 16, 12))
	frame.custom_minimum_size.x = BROWSER_W
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	frame.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var h := _heading("Games")
	top.add_child(h)
	_count = _plain("", hud.DIM, 15)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_count)
	_looked = _plain("", hud.DIM, 13)
	_looked.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_looked)
	top.add_child(_pill("Look again", func(): _looked_t = Time.get_ticks_msec(); Net.refresh_servers(), hud.GOLD))
	v.add_child(top)
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 8)
	_filter = _field("", "Search by name", 220)
	_filter.custom_minimum_size.y = 32
	_filter.add_theme_font_size_override("font_size", 16)
	_filter.text_changed.connect(func(_t): _list_servers())
	fh.add_child(_filter)
	_hide_full = _toggle("Hide full", false)
	fh.add_child(_hide_full)
	_hide_other = _toggle("Only my version", true)
	fh.add_child(_hide_other)
	_hide_closed = _toggle("Hide closed", false)
	fh.add_child(_hide_closed)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(sp)
	_sort = OptionButton.new()
	for t in ["Most players", "Name", "Nearest"]:
		_sort.add_item(t)
	_sort.add_theme_font_size_override("font_size", 15)
	_sort.item_selected.connect(func(_i): _list_servers())
	fh.add_child(_sort)
	v.add_child(fh)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	for c in [["GAME", 320], ["WHERE", 170], ["PLAYERS", 150]]:
		var l := _plain(c[0], Color(hud.GOLD, 0.6), 12)
		l.custom_minimum_size.x = c[1]
		cols.add_child(l)
	v.add_child(cols)
	var rule := ColorRect.new()
	rule.color = Color(hud.GOLD, 0.18)
	rule.custom_minimum_size.y = 1
	v.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 228
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(func():
		if _looked and _together.visible:
			var ago := (Time.get_ticks_msec() - _looked_t) / 1000
			_looked.text = "looked just now" if ago < 5 else ("looked %ds ago" % ago if ago < 120 else "looked a while ago"))
	frame.add_child(tick)
	_found = VBoxContainer.new()
	_found.add_theme_constant_override("separation", 6)
	_found.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_found)
	return frame


const BROWSER_W := 980.0
var _count: Label
var _looked: Label
var _looked_t := 0
var _hide_closed: CheckBox
var _sort: OptionButton
var _jword: LineEdit


func _box(bg: Color, border: Color, radius := 6, mx := 12, my := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


## A label that keeps to one line.
func _plain(text: String, col: Color, size := 16) -> Label:
	return hud._label(text, size, col, HORIZONTAL_ALIGNMENT_LEFT)


## One of the two cards above the list: a framed box with a small heading. Returns [card, its column].
func _side_card(title: String, width: float) -> Array:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color(0.03, 0.025, 0.02, 0.7), Color(hud.GOLD, 0.2), 6, 14, 10))
	card.custom_minimum_size.x = width
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	card.add_child(v)
	var h: Label = hud._label(title, 19, hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	h.add_theme_font_override("font", hud.title_font)
	v.add_child(h)
	return [card, v]


func _toggle(text: String, on: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_size_override("font_size", 15)
	c.add_theme_color_override("font_color", hud.DIM)
	c.add_theme_color_override("font_pressed_color", hud.PALE)
	c.toggled.connect(func(_on): _list_servers())
	return c


func _pill(text: String, cb: Callable, col: Color, size := 15) -> Button:
	var b := Button.new()
	b.text = text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.3))
	b.add_theme_color_override("font_disabled_color", Color(hud.DIM, 0.6))
	b.add_theme_stylebox_override("normal", _box(Color(col, 0.08), Color(col, 0.55), 12, 12, 4))
	b.add_theme_stylebox_override("hover", _box(Color(col, 0.18), Color(col, 0.85), 12, 12, 4))
	b.add_theme_stylebox_override("pressed", _box(Color(col, 0.26), Color(col, 0.95), 12, 12, 4))
	b.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.08), 12, 12, 4))
	b.pressed.connect(cb)
	return b


## A small rounded mark beside a fellowship's name: closed, its network, its version.
func _tag(text: String, col: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(col, 0.1), Color(col, 0.45), 8, 7, 1))
	var l: Label = hud._label(text, 12, col, HORIZONTAL_ALIGNMENT_LEFT)
	p.add_child(l)
	return p


## How full it is: one dot for each place, lit in the fellowship's colours.
func _pips(have: int, most: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	for i in most:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(11, 11)
		var on: bool = i < have
		var col: Color = Net.SLOT_COLORS[i % Net.SLOT_COLORS.size()] if on else Color(1, 1, 1, 0.12)
		var pip := _box(col, Color(col.lightened(0.2), 0.9), 6, 0, 0)
		if not on:
			pip.set_border_width_all(0)
		d.add_theme_stylebox_override("panel", pip)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(d)
	var l := _plain("  %d/%d" % [have, most], hud.PALE if have < most else Color(0.9, 0.55, 0.4), 14)
	h.add_child(l)
	return h


func _list_servers() -> void:
	if _found == null:
		return
	for c in _found.get_children():
		c.queue_free()
	if _looked:
		var ago := (Time.get_ticks_msec() - _looked_t) / 1000
		_looked.text = "looked just now" if ago < 5 else ("looked %ds ago" % ago if ago < 120 else "looked a while ago")
	var keys: Array = Net.servers.keys()
	var by := _sort.selected if _sort else 0
	keys.sort_custom(func(a, b):
		var da: Dictionary = Net.servers[a]
		var db: Dictionary = Net.servers[b]
		match by:
			1:
				return str(da.get("name", "")).to_lower() < str(db.get("name", "")).to_lower()
			2:
				return int(da.get("ping", 9999)) < int(db.get("ping", 9999))
		if int(da.get("players", 0)) != int(db.get("players", 0)):
			return int(da.get("players", 0)) > int(db.get("players", 0))
		return int(da.get("ping", 9999)) < int(db.get("ping", 9999)))
	var shown := 0
	var walking := 0
	for key in keys:
		var d: Dictionary = Net.servers[key]
		walking += int(d.get("players", 0))
		var q: String = _filter.text.strip_edges().to_lower() if _filter else ""
		if q != "" and not str(d.get("name", "")).to_lower().contains(q):
			continue
		var most := int(d.get("max", 4))
		var full := int(d.get("players", 0)) >= most
		if _hide_full and _hide_full.button_pressed and full:
			continue
		var other: bool = d.get("proto", Net.PROTOCOL) != Net.PROTOCOL
		if _hide_other and _hide_other.button_pressed and other:
			continue
		if _hide_closed and _hide_closed.button_pressed and d.get("locked", false):
			continue
		shown += 1
		_found.add_child(_server_card(d, full, other))
	if _count:
		_count.text = "" if Net.servers.is_empty() else "%d found  ·  %d players" % [Net.servers.size(), walking]
	if Net.servers.is_empty():
		_found.add_child(_empty("No games yet.", "Games on your network appear here, and public ones from the internet. A private one is joined by its code."))
	elif shown == 0:
		_found.add_child(_empty("None match.", "Clear the search, or show full and closed fellowships."))


func _empty(head: String, text: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var sp := Control.new()
	sp.custom_minimum_size.y = 30
	v.add_child(sp)
	var h: Label = hud._label(head, 20, hud.PALE, HORIZONTAL_ALIGNMENT_CENTER)
	h.add_theme_font_override("font", hud.title_font)
	v.add_child(h)
	var l: Label = hud._label(text, 15, hud.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 760
	v.add_child(l)
	return v


## One fellowship: its name and marks, where it walks, how full, how near, and the way in.
func _server_card(d: Dictionary, full: bool, other: bool) -> Control:
	var card := PanelContainer.new()
	var idle := _box(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.07), 6, 12, 8)
	var lit := _box(Color(hud.GOLD, 0.07), Color(hud.GOLD, 0.35), 6, 12, 8)
	card.add_theme_stylebox_override("panel", idle)
	card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", lit))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", idle))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(row)
	# Name, and its marks beneath
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	left.custom_minimum_size.x = 320
	var nm: Label = hud._label(str(d.get("name", "?")).left(34), 20, hud.PALE if not other else hud.DIM, HORIZONTAL_ALIGNMENT_LEFT)
	nm.add_theme_font_override("font", hud.title_font)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size.x = 320
	left.add_child(nm)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 5)
	var lan: bool = str(d.get("source", "")) == "LAN" or d.get("same", false)
	tags.add_child(_tag("Your network" if lan else "Internet", Color(0.5, 0.75, 0.55) if lan else Color(0.55, 0.7, 0.9)))
	if d.get("locked", false):
		tags.add_child(_tag("Closed", Color(0.9, 0.65, 0.4)))
	if other:
		tags.add_child(_tag("Version %s" % d.get("version", "?"), Color(0.9, 0.45, 0.4)))
	var det := str(d.get("detail", ""))
	if det != "":
		var dl := _plain("  " + det, hud.DIM, 13)
		tags.add_child(dl)
	left.add_child(tags)
	row.add_child(left)
	# Where it walks
	var lvl := int(d.get("level", -1))
	var where := "The gathering"
	if lvl == Game.WASTELAND:
		where = "The Ashen Waste"
	elif lvl >= 0 and lvl < PLACES.size():
		where = PLACES[lvl]
	var wl := _plain(where, Color(0.85, 0.7, 0.45) if lvl == Game.WASTELAND else hud.PALE, 16)
	wl.custom_minimum_size.x = 170
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(wl)
	# How full
	var pv := _pips(int(d.get("players", 0)), int(d.get("max", 4)))
	pv.custom_minimum_size.x = 150
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pv)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	# How near, and the way in
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	right.custom_minimum_size.x = 110
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var locked: bool = d.get("locked", false)
	var label := "Full" if full else ("Other version" if other else "Join")
	var b := _pill(label, func():
		if locked and (_jword == null or _jword.text.strip_edges() == ""):
			_status.text = "This fellowship is closed. Give its word in the field above, then Join again."
			if _jword:
				_jword.grab_focus()
			return
		Net.join_word = _jword.text.strip_edges() if _jword else ""
		Net.join_listed(d), hud.GOLD, 16)
	b.disabled = full or other
	b.custom_minimum_size.x = 104
	right.add_child(b)
	if d.has("ping"):
		var ms := int(d.ping)
		var pc := Color(0.55, 0.8, 0.5) if ms < 60 else (Color(0.9, 0.75, 0.4) if ms < 150 else Color(0.9, 0.45, 0.4))
		var pl: Label = hud._label("%d ms" % ms, 13, pc, HORIZONTAL_ALIGNMENT_CENTER)
		right.add_child(pl)
	row.add_child(right)
	return card


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
	_lobby.add_child(_heading("The fellowship  (%d of %d)" % [Net.players.size(), Net.cap()]))
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
		var many := Net.players.size() > Net.MAX_TRIALS
		if many:
			_lobby.add_child(_small("The trials take four at most. With %d, walk the Ashen Waste." % Net.players.size(), hud.DIM, 16))
		for i in range(mini(Game.reached, 10) + 1):
			var idx := i
			var tb := _btn(PLACES[i], func(): Net.begin(idx), 17)
			tb.disabled = many
			grid.add_child(tb)
		if Game.tenth_unlocked():
			var tt := _btn("The Tenth Trial", func(): Net.begin(11), 18)
			tt.disabled = many
			grid.add_child(tt)
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
