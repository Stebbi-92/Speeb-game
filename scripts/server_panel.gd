extends Control
## The dedicated server's window: how it stands, who is here, its worlds, its settings, updates and log.
## It shows and orders through scripts/server_admin.gd; it holds nothing of its own.

const UiTheme := preload("res://scripts/ui_theme.gd")
const GOLD := Color(0.86, 0.80, 0.66)
const PALE := Color(0.93, 0.92, 0.88)
const DIM := Color(0.62, 0.60, 0.56)
const GOOD := Color(0.58, 0.78, 0.55)
const WARN := Color(0.92, 0.66, 0.36)
const BG := Color(0.035, 0.033, 0.03)
const TABS := ["Players", "World", "Settings", "Updates", "Log"]
const SIZE := 16   ## the body text size

var admin: Node
var serif: Font
var title_font: Font

var tabs: TabContainer
var _name_lbl: Label
var _chips := {}          ## chip key -> its value Label
var _foot: Label
var _confirm: Control
var _confirm_text: Label
var _confirm_yes: Button
var _confirm_cb := Callable()

# Players
var _rows: VBoxContainer
var _row_ids := []
var _ping_lbls := {}
var _nobody: Label
var _say: LineEdit

# World
var _world_lbl: Label
var _mode_btns: Array[Button] = []
var _mode_note: Label
var _worlds: VBoxContainer
var _new_name: LineEdit
var _new_seed: LineEdit

# Settings
var _set := {}            ## setting key -> its control
var _set_note: Label

# Updates
var _upd_status: Label
var _upd_title: Label
var _upd_notes: Label
var _upd_bar: ProgressBar
var _upd_get: Button
var _upd_page: Button
var _upd_restart_note: Label
var _upd_checks := {}

# Log
var _log: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	serif = load("res://assets/fonts/SourceSerif4.ttf")
	title_font = load("res://assets/fonts/Marcellus-Regular.ttf")
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 22)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 10)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	v.add_child(_build_header())
	v.add_child(_build_status())
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_changed.connect(_on_tab)
	v.add_child(tabs)
	_add_tab("Players", _build_players())
	_add_tab("World", _build_world())
	_add_tab("Settings", _build_settings())
	_add_tab("Updates", _build_updates())
	_add_tab("Log", _build_log())
	_foot = _lbl("", 15, DIM)
	_foot.clip_text = true
	_foot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(_foot)
	_build_confirm()
	if admin:
		admin.changed.connect(_refresh_soon)
		admin.logged.connect(_on_logged)
		for l in admin.log_lines:
			_log.add_text(str(l) + "\n")
	Updater.progress.connect(_on_progress)
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(refresh)
	add_child(t)
	refresh()
	_refresh_worlds()
	_refresh_updates()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and admin:
		admin.stop()


# ------------------------------------------------------------------ the look

func _make_theme() -> Theme:
	var th: Theme = UiTheme.make(serif)
	th.default_font_size = SIZE
	th.set_color("font_color", "Label", PALE)
	var tab_on := UiTheme.box(Color(GOLD, 0.14), Color(GOLD, 0.7))
	var tab_off := UiTheme.box(Color(0.07, 0.065, 0.06, 0.9), Color(GOLD, 0.18))
	var tab_hover := UiTheme.box(Color(0.11, 0.10, 0.09, 0.95), Color(GOLD, 0.45))
	for s in [tab_on, tab_off, tab_hover]:
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 7
		s.content_margin_bottom = 7
	th.set_stylebox("tab_selected", "TabContainer", tab_on)
	th.set_stylebox("tab_unselected", "TabContainer", tab_off)
	th.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	th.set_stylebox("tab_focus", "TabContainer", UiTheme.focus_box())
	var pane := UiTheme.box(Color(0.06, 0.056, 0.05, 0.96), Color(GOLD, 0.22))
	pane.set_content_margin_all(16)
	th.set_stylebox("panel", "TabContainer", pane)
	th.set_color("font_selected_color", "TabContainer", GOLD)
	th.set_color("font_unselected_color", "TabContainer", DIM)
	th.set_color("font_hovered_color", "TabContainer", PALE)
	th.set_font_size("font_size", "TabContainer", 17)
	th.set_constant("side_margin", "TabContainer", 0)
	var chip := UiTheme.box(Color(0.07, 0.065, 0.06, 0.95), Color(GOLD, 0.2))
	chip.content_margin_left = 10
	chip.content_margin_right = 10
	chip.content_margin_top = 4
	chip.content_margin_bottom = 4
	th.set_stylebox("panel", "PanelContainer", chip)
	for t in ["Button", "OptionButton"]:
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var b: StyleBox = th.get_stylebox(s, t).duplicate()
			b.content_margin_left = 14
			b.content_margin_right = 14
			b.content_margin_top = 5
			b.content_margin_bottom = 5
			th.set_stylebox(s, t, b)
	var edit: StyleBox = th.get_stylebox("normal", "LineEdit").duplicate()
	edit.content_margin_left = 10
	edit.content_margin_top = 5
	edit.content_margin_bottom = 5
	th.set_stylebox("normal", "LineEdit", edit)
	th.set_color("default_color", "RichTextLabel", PALE)
	th.set_color("selection_color", "RichTextLabel", Color(GOLD, 0.3))
	th.set_stylebox("separator", "HSeparator", _line())
	th.set_constant("separation", "HSeparator", 14)
	return th


func _line() -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = Color(GOLD, 0.16)
	return s


func _lbl(text: String, fsize := SIZE, color := PALE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	return l


## A line of words that wraps within its box.
func _para(text: String, color := DIM, fsize := 15) -> Label:
	var l := _lbl(text, fsize, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _heading(text: String) -> Label:
	var l := _lbl(text, 20, GOLD)
	l.add_theme_font_override("font", title_font)
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _vbox(sep := 10) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


func _edit(hint: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = hint
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return e


## A page that scrolls when the window is small.
func _scroller(inner: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_right", 12)   # room for the scroll bar
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(inner)
	s.add_child(pad)
	return s


func _add_tab(title: String, page: Control) -> void:
	page.name = title
	tabs.add_child(page)


# ------------------------------------------------------------------ header and status

func _build_header() -> Control:
	var h := _hbox(16)
	var t := _lbl("Brelm server", 28, GOLD)
	t.add_theme_font_override("font", title_font)
	h.add_child(t)
	_name_lbl = _lbl("", 20, PALE)
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.clip_text = true
	_name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_lbl.size_flags_vertical = Control.SIZE_FILL
	h.add_child(_name_lbl)
	var stop := _btn("Stop server", func(): _ask("Stop the server? The world is saved first, and everyone here is sent home.", "Stop", func(): admin.stop()))
	stop.add_theme_color_override("font_color", WARN)
	h.add_child(stop)
	return h


func _build_status() -> Control:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	for pair in [["state", ""], ["players", "Players"], ["world", "World"], ["uptime", "Up"], ["saved", "Saved"],
			["listed", "Internet list"], ["port", "Port"], ["version", "Version"], ["join", "Join at"]]:
		var chip := PanelContainer.new()
		var h := _hbox(6)
		chip.add_child(h)
		if pair[1] != "":
			h.add_child(_lbl(pair[1], 15, DIM))
		var val := _lbl("", 15, PALE)
		h.add_child(val)
		_chips[pair[0]] = val
		f.add_child(chip)
	return f


## Brings everything shown up to date. Called each second, and when the server says something changed.
func refresh() -> void:
	if admin == null:
		return
	var s: Dictionary = admin.status()
	_name_lbl.text = str(s.name)
	var state: String = admin.run_state(s)
	_chips.state.text = state
	_chips.state.add_theme_color_override("font_color", GOOD if state == "Running" else WARN)
	_chips.players.text = "%d/%d" % [s.players.size(), int(s.max_players)]
	_chips.world.text = str(s.world) if str(s.world) != "" else ("none" if s.known else "-")
	_chips.uptime.text = admin.span(int(s.uptime_s))
	_chips.saved.text = admin.saved_text(int(s.last_save_unix)) if s.known else "-"
	_chips.listed.text = "yes" if s.listed else "no"
	_chips.port.text = str(s.port)
	_chips.version.text = str(s.version)
	var ips := Net.local_addresses()
	_chips.join.text = ", ".join(ips.map(func(ip): return "%s:%d" % [ip, int(s.port)])) if not ips.is_empty() else "no network"
	_refresh_players(s)
	_refresh_world_info(s)


var _soon := false


func _refresh_soon() -> void:
	if _soon or not is_inside_tree():
		return
	_soon = true
	await get_tree().process_frame
	_soon = false
	if not is_inside_tree():
		return
	refresh()
	if tabs.current_tab == 1:
		_refresh_worlds()
	_refresh_updates()


func _on_tab(i: int) -> void:
	if i == 1:
		_refresh_worlds()
	elif i == 3:
		_refresh_updates()


## A word at the foot of the window, and in the log.
func _tell(text: String) -> void:
	_foot.text = text


func _on_logged(line: String) -> void:
	_log.add_text(line + "\n")
	_foot.text = line
	if _log.get_paragraph_count() > 3000:
		_log.remove_paragraph(0)


# ------------------------------------------------------------------ asking first

func _build_confirm() -> void:
	_confirm = ColorRect.new()
	(_confirm as ColorRect).color = Color(0, 0, 0, 0.6)
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	add_child(_confirm)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(c)
	var p := PanelContainer.new()
	var box := UiTheme.box(Color(0.07, 0.065, 0.06, 0.99), Color(GOLD, 0.6))
	box.set_content_margin_all(24)
	p.add_theme_stylebox_override("panel", box)
	c.add_child(p)
	var v := _vbox(18)
	p.add_child(v)
	_confirm_text = _lbl("", 18, PALE)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.custom_minimum_size.x = 420
	v.add_child(_confirm_text)
	var h := _hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(h)
	h.add_child(_btn("Cancel", func(): _confirm.visible = false))
	_confirm_yes = _btn("", func():
		_confirm.visible = false
		if _confirm_cb.is_valid():
			_confirm_cb.call())
	_confirm_yes.add_theme_color_override("font_color", GOLD)
	h.add_child(_confirm_yes)


## Asks in the window before doing something that cannot be undone.
func _ask(question: String, yes: String, cb: Callable) -> void:
	_confirm_text.text = question
	_confirm_yes.text = yes
	_confirm_cb = cb
	_confirm.visible = true
	_confirm_yes.grab_focus()


# ------------------------------------------------------------------ players

func _build_players() -> Control:
	var v := _vbox(8)
	var head := _hbox(10)
	head.add_child(_col("Name", 0, true))
	head.add_child(_col("Id", 120))
	head.add_child(_col("Ping", 80))
	head.add_child(_col("", 170))
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_right", 12)   # as the rows, beside their scroll bar
	hm.add_child(head)
	v.add_child(hm)
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", 2)
	v.add_child(line)
	_nobody = _para("No one is here yet. Friends join at the addresses above, or by the join code the internet list gives.", DIM, 16)
	v.add_child(_nobody)
	_rows = _vbox(6)
	var sc := _scroller(_rows)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	v.add_child(HSeparator.new())
	v.add_child(_lbl("Message to everyone", 15, DIM))
	var h := _hbox(10)
	_say = _edit("Type a message and press Enter")
	_say.max_length = 200
	_say.text_submitted.connect(func(_t): _send_say())
	h.add_child(_say)
	h.add_child(_btn("Send", _send_say))
	v.add_child(h)
	return v


func _col(text: String, width: int, grow := false) -> Label:
	var l := _lbl(text, 15, DIM)
	l.custom_minimum_size.x = width
	if grow:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	return l


func _send_say() -> void:
	if admin.say(_say.text):
		_say.text = ""


func _refresh_players(s: Dictionary) -> void:
	var ps: Array = s.players
	var ids := ps.map(func(p): return [int(p.id), str(p.name)])
	_nobody.visible = ps.is_empty()
	if ids != _row_ids:
		_row_ids = ids
		for c in _rows.get_children():
			c.queue_free()
		_ping_lbls.clear()
		for p in ps:
			var id := int(p.id)
			var pname := str(p.name)
			var h := _hbox(10)
			var n := _lbl(pname, 17, PALE)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.clip_text = true
			n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			h.add_child(n)
			h.add_child(_col(str(id), 120))
			var ping := _col("", 80)
			ping.add_theme_color_override("font_color", PALE)
			_ping_lbls[id] = ping
			h.add_child(ping)
			var acts := _hbox(8)
			acts.custom_minimum_size.x = 170
			acts.add_child(_btn("Kick", func(): admin.kick(id)))
			acts.add_child(_btn("Ban", func(): _ask("Ban %s? They cannot come back under that name." % pname, "Ban", func(): admin.ban(id))))
			h.add_child(acts)
			_rows.add_child(h)
	for p in ps:
		var l: Label = _ping_lbls.get(int(p.id))
		if l:
			l.text = admin.ping_text(int(p.get("ping", -1)))


# ------------------------------------------------------------------ world

func _build_world() -> Control:
	var v := _vbox(10)
	v.add_child(_heading("This world"))
	_world_lbl = _para("", PALE, 16)
	v.add_child(_world_lbl)
	var h := _hbox(10)
	h.add_child(_btn("Save now", func(): admin.save_now()))
	h.add_child(_btn("Restart world", func(): _ask("Restart this world? It is saved first, then raised again, and everyone here comes back to it.", "Restart", func(): admin.restart_world())))
	v.add_child(h)
	v.add_child(HSeparator.new())
	v.add_child(_heading("When the world runs"))
	var modes := _hbox(10)
	var group := ButtonGroup.new()
	for i in 3:
		var b := Button.new()
		b.text = ["Pause when empty", "Always run", "Paused"][i]
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(func():
			admin.set_pause_mode(i)
			_show_mode())
		_mode_btns.append(b)
		modes.add_child(b)
	v.add_child(modes)
	_mode_note = _para("", DIM, 15)
	v.add_child(_mode_note)
	v.add_child(HSeparator.new())
	var wh := _hbox(10)
	var wt := _heading("Saved worlds")
	wt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(wt)
	wh.add_child(_btn("Refresh", _refresh_worlds))
	v.add_child(wh)
	_worlds = _vbox(6)
	v.add_child(_worlds)
	v.add_child(HSeparator.new())
	v.add_child(_heading("New world"))
	var nh := _hbox(10)
	_new_name = _edit("Name")
	_new_name.max_length = 40
	nh.add_child(_new_name)
	_new_seed = _edit("Seed (empty for any)")
	_new_seed.custom_minimum_size.x = 200
	_new_seed.size_flags_horizontal = Control.SIZE_FILL
	nh.add_child(_new_seed)
	nh.add_child(_btn("Make it", _make_world))
	v.add_child(nh)
	v.add_child(_para("The world in use is saved first. Everyone here moves to the new world.", DIM, 15))
	_show_mode()
	return _scroller(v)


func _show_mode() -> void:
	var m: int = admin.pause_mode if admin else 0
	for i in _mode_btns.size():
		_mode_btns[i].set_pressed_no_signal(i == m)
	var known: bool = admin != null and admin.has("server_set_paused_override")
	_mode_note.text = ["The world stands still while no one is here, and wakes when someone joins.",
		"The world runs even with no one here: nights fall and crops grow.",
		"The world stands still until you choose otherwise."][m] + ("" if known else " (Not available in this build.)")


func _refresh_world_info(s: Dictionary) -> void:
	if not s.known:
		_world_lbl.text = "This build keeps no world of its own on the server. World tools are not available in this build."
		return
	var lvl := int(s.get("level", -1))
	var land := ""
	if lvl >= 0 and lvl < Game.LEVEL_NAMES.size():
		land = Game.LEVEL_NAMES[lvl]
	elif lvl >= 10:
		land = ["The Forgotten Cave", "The Tenth Trial", "The Ashen Waste"][mini(lvl - 10, 2)]
	_world_lbl.text = "%s%s.  Difficulty %s.  Last saved %s." % [str(s.world) if str(s.world) != "" else "No world loaded",
		(", in " + land) if land != "" else "", Game.DIFFICULTIES[clampi(int(s.get("difficulty", 1)), 0, 2)], admin.saved_text(int(s.last_save_unix))]


func _refresh_worlds() -> void:
	if admin == null or _worlds == null:
		return
	for c in _worlds.get_children():
		c.queue_free()
	if not admin.has("server_list_worlds"):
		_worlds.add_child(_para("Listing worlds is not available in this build.", DIM, 15))
		return
	var cur := str(admin.status().world)
	var list: Array = admin.list_worlds()
	if list.is_empty():
		_worlds.add_child(_para("No saved worlds yet.", DIM, 15))
	for w in list:
		var wname: String = admin.world_name_of(w)
		var h := _hbox(10)
		var l := _lbl(admin.world_label(w), 16, GOLD if wname == cur else PALE)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(l)
		if wname == cur:
			var here := _lbl("in use", 15, DIM)
			here.custom_minimum_size.x = 80
			here.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.add_child(here)
		else:
			var b := _btn("Load", func(): _ask("Load %s? The world in use is saved first, and everyone here moves to %s." % [wname, wname], "Load", func(): admin.load_world(wname)))
			b.custom_minimum_size.x = 80
			h.add_child(b)
		_worlds.add_child(h)


func _make_world() -> void:
	var n := _new_name.text.strip_edges()
	if n == "":
		_tell("Give the new world a name.")
		_new_name.grab_focus()
		return
	var sd := _new_seed.text.strip_edges()
	if sd != "" and not sd.is_valid_int():
		_tell("The seed must be a whole number, or empty.")
		return
	_ask("Make a new world called %s? The world in use is saved first." % n, "Make it", func():
		if admin.new_world(n, int(sd) if sd != "" else 0):
			_new_name.text = ""
			_new_seed.text = ""
		_refresh_worlds())


# ------------------------------------------------------------------ settings

func _build_settings() -> Control:
	var v := _vbox(12)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 10)
	v.add_child(g)
	_setting(g, "name", "Server name", _edit("A fellowship of Brelm"))
	var pw := _edit("None: anyone may join")
	pw.secret = true
	var pw_row := _hbox(8)
	pw_row.add_child(pw)
	var show := CheckBox.new()
	show.text = "Show"
	show.toggled.connect(func(on): pw.secret = not on)
	pw_row.add_child(show)
	_set["password"] = pw
	_row(g, "Password", pw_row)
	_setting(g, "max_players", "Most players", _spin(1, 8))
	var diff := OptionButton.new()
	diff.custom_minimum_size.x = 200
	for d in Game.DIFFICULTIES:
		diff.add_item(d)
	_setting(g, "difficulty", "Difficulty", diff)
	_setting(g, "listed", "List on the internet", _switch())
	_setting(g, "autosave_min", "Save every (minutes, 0 for never)", _spin(0, 240))
	_setting(g, "pause_when_empty", "Pause when no one is here", _switch())
	_setting(g, "port", "Port (UDP, after a restart)", _spin(1024, 65535))
	_setting(g, "lobby", "Internet list address (after a restart)", _edit("https://game.speeb.org"))
	_set_note = _para("", DIM, 15)
	v.add_child(_set_note)
	# The buttons stay in sight below the list, however small the window
	var page := _vbox(10)
	var sc := _scroller(v)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(sc)
	var h := _hbox(10)
	h.add_child(_btn("Apply", _apply_settings))
	h.add_child(_btn("Undo changes", _fill_settings))
	h.add_child(_btn("Open settings folder", func(): OS.shell_open(ProjectSettings.globalize_path(admin.config_path.get_base_dir()))))
	page.add_child(h)
	_fill_settings()
	return page


func _row(g: GridContainer, label: String, c: Control) -> void:
	var l := _lbl(label, 16, DIM)
	l.custom_minimum_size.x = 250
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL if c is LineEdit or c is HBoxContainer else Control.SIZE_SHRINK_BEGIN
	g.add_child(c)


func _setting(g: GridContainer, key: String, label: String, c: Control) -> void:
	_set[key] = c
	_row(g, label, c)


func _spin(lo: int, hi: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.rounded = true
	s.custom_minimum_size.x = 160
	return s


func _switch() -> CheckButton:
	var c := CheckButton.new()
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return c


## Shows the settings in use.
func _fill_settings() -> void:
	if admin == null:
		return
	var c: Dictionary = admin.conf
	for k in _set:
		var w: Control = _set[k]
		var val = c.get(k)
		if w is LineEdit:
			w.text = str(val)
		elif w is SpinBox:
			w.value = int(val)
		elif w is OptionButton:
			w.select(int(val))
		elif w is CheckButton:
			w.button_pressed = bool(val)
	_set_note.text = "Kept in %s. The command line can override these when the server starts." % ProjectSettings.globalize_path(admin.config_path)


func _apply_settings() -> void:
	var d := {}
	for k in _set:
		var w: Control = _set[k]
		if w is LineEdit:
			d[k] = w.text.strip_edges()
		elif w is SpinBox:
			d[k] = int(w.value)
		elif w is OptionButton:
			d[k] = w.selected
		elif w is CheckButton:
			d[k] = w.button_pressed
	if d.name == "":
		d.name = "A fellowship of Brelm"
	admin.apply_settings(d)
	get_window().title = "Brelm server: %s" % d.name
	_fill_settings()
	refresh()


# ------------------------------------------------------------------ updates

func _build_updates() -> Control:
	var v := _vbox(10)
	var h := _hbox(14)
	var cur := _lbl("This version: %s" % Updater.current, 18, PALE)
	cur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(cur)
	h.add_child(_btn("Check for updates", func(): admin.check_updates()))
	v.add_child(h)
	_upd_status = _para("", GOLD, 16)
	v.add_child(_upd_status)
	_upd_title = _heading("")
	v.add_child(_upd_title)
	_upd_notes = _para("", PALE, 15)
	var notes := _scroller(_upd_notes)
	notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes.custom_minimum_size.y = 60
	v.add_child(notes)
	_upd_bar = ProgressBar.new()
	_upd_bar.custom_minimum_size.y = 8
	_upd_bar.show_percentage = false
	_upd_bar.visible = false
	v.add_child(_upd_bar)
	var b := _hbox(10)
	_upd_get = _btn("Download and apply", _get_update)
	b.add_child(_upd_get)
	_upd_page = _btn("Open release page", func(): OS.shell_open(str(Updater.latest.get("page", ""))))
	b.add_child(_upd_page)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_child(gap)
	_upd_restart_note = _lbl("Restart the server to finish.", 16, GOLD)
	_upd_restart_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_child(_upd_restart_note)
	b.add_child(_btn("Restart server", func(): _ask("Restart the server? The world is saved first. Players are sent home and can join again in a minute.", "Restart", func(): admin.restart_server())))
	v.add_child(b)
	v.add_child(HSeparator.new())
	for pair in [["check_on_start", "Check for updates when the server starts"], ["auto_update", "Update by itself when no one is here"]]:
		var c := CheckBox.new()
		c.text = pair[1]
		var key: String = pair[0]
		c.toggled.connect(func(on): admin.set_update_option(key, on))
		_upd_checks[key] = c
		v.add_child(c)
	return v


func _refresh_updates() -> void:
	if admin == null or _upd_status == null:
		return
	var note: String = admin.update_note
	if note == "":
		note = "Not checked yet." if Updater.latest.is_empty() else ""
	_upd_status.text = note
	var has_news := not Updater.latest.is_empty() and str(Updater.latest.get("version", "")) != ""
	_upd_title.visible = has_news
	_upd_notes.get_parent().get_parent().visible = has_news
	if has_news:
		var n := str(Updater.latest.get("name", ""))
		_upd_title.text = "Newest: %s" % (n if n != "" else "version " + str(Updater.latest.version))
		var text := str(Updater.latest.get("notes", "")).strip_edges()
		_upd_notes.text = text if text != "" else "This release has no notes."
	_upd_get.visible = Updater.can_patch or Updater.busy
	_upd_get.disabled = Updater.busy
	_upd_get.text = "Fetching..." if Updater.busy else "Download and apply"
	_upd_page.visible = has_news and str(Updater.latest.get("page", "")) != ""
	_upd_restart_note.visible = Updater.staged != ""
	_upd_bar.visible = Updater.busy
	for k in _upd_checks:
		_upd_checks[k].set_pressed_no_signal(bool(admin.conf.get(k, false)))


func _get_update() -> void:
	Updater.download()
	_refresh_updates()


func _on_progress(done: int, total: int) -> void:
	_upd_bar.visible = true
	_upd_bar.max_value = maxi(total, 1)
	_upd_bar.value = done
	_upd_status.text = "Fetching... %d of %d MB" % [done / 1048576, total / 1048576]


# ------------------------------------------------------------------ log

func _build_log() -> Control:
	var v := _vbox(10)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = false
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.context_menu_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 15)
	v.add_child(_log)
	var h := _hbox(10)
	h.add_child(_btn("Copy log", func():
		DisplayServer.clipboard_set("\n".join(admin.log_lines))
		_tell("The log is copied.")))
	h.add_child(_btn("Open log folder", _open_logs))
	h.add_child(_btn("Clear view", func(): _log.clear()))
	v.add_child(h)
	return v


func _open_logs() -> void:
	var dir := "user://logs" if DirAccess.dir_exists_absolute("user://logs") else "user://"
	OS.shell_open(ProjectSettings.globalize_path(dir))


# ------------------------------------------------------------------ testing aids

## Testing aid: builds every page, shows each, and says so; then quits.
func debug_check() -> void:
	await get_tree().process_frame
	var names := []
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		await get_tree().process_frame
		names.append(tabs.get_tab_title(i))
	refresh()
	_refresh_worlds()
	_refresh_updates()
	_fill_settings()
	admin.run_command("status")
	admin.run_command("help")
	var saved: Dictionary = admin.load_config(admin.config_path)
	# The file gives the settings, and the command line overrides them
	var t: Dictionary = admin.defaults()
	t.name = "From the file"
	t.port = 25000
	admin.save_config("user://panel_check.cfg", t)
	var got: Dictionary = admin.from_args(PackedStringArray(["server", "config=user://panel_check.cfg", "port=25001", "public"]))
	DirAccess.remove_absolute("user://panel_check.cfg")
	var order: bool = got.name == "From the file" and got.port == 25001 and got.listed
	print("PANEL tabs=%s chips=%d settings=%d cfg=%s order=%s log=%d" % [",".join(names), _chips.size(), _set.size(),
		FileAccess.file_exists(admin.config_path) and saved.name == admin.conf.name, order, admin.log_lines.size()])
	get_tree().quit()


## Testing aid: saves a picture of each page at each size ("1280x720,900x600"), then quits.
func debug_shots(spec: String) -> void:
	await get_tree().create_timer(1.5).timeout
	for sz in spec.split(","):
		var wh := sz.split("x")
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		for i in tabs.get_tab_count():
			tabs.current_tab = i
			for k in 6:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("user://panel_%s_%s.png" % [sz, TABS[i].to_lower()])
		_ask("Stop the server? The world is saved first, and everyone here is sent home.", "Stop", func(): pass)
		for k in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://panel_%s_confirm.png" % sz)
		_confirm.visible = false
	print("PANELSHOTS done")
	get_tree().quit()
