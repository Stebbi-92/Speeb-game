class_name WUI
extends Control
## The survivor's screens: the pack and what can be made, chests and satchels, trade, talk, the journal, the map.
## [I] or [Tab] the pack, [M] the map, [J] the journal, [B] building. [Esc] closes whatever is open.

const GOLD := Color(0.86, 0.80, 0.66)
const PALE := Color(0.93, 0.92, 0.88)
const DIM := Color(0.62, 0.60, 0.56)
const BG := Color(0.05, 0.045, 0.04, 0.94)

var w
var map_dirty := true
var journal_dirty := true
var _panel: Control = null
var _frame: PanelContainer
var _body: VBoxContainer
var _clock: Label
var _build_title: Label
var _keys: HBoxContainer
var _build_hint: RichTextLabel
var _keys_sig := ""
var _sel := -1
var debug_bench := false
var _arms_scroll := 0
var _compass: Compass
var _cont_id := ""
var _tab := "pack"
var _desc: Label
var _map_tex: ImageTexture
var _map_task := -1           ## rows of the map's picture drawn so far (-1: not begun)
var _map_img: Image


## Draws the map's picture in the background, so the first look at the map does not stall the game.
func prepare_map() -> void:
	if _map_task >= 0 or _map_tex != null or w.terrain == null:
		return
	# Drawn a few rows a frame on the main thread: no freeze when the map first opens, and no
	# worker left reading a world that has gone (a thread here crashed hosted games)
	_map_task = 0
	var img := Image.create(1024, 1024, false, Image.FORMAT_RGB8)
	while _map_task < 1024:
		if not is_instance_valid(w) or not is_inside_tree() or w.terrain == null:
			return
		w.terrain.map_rows(img, _map_task, mini(_map_task + 16, 1024))
		_map_task += 16
		await get_tree().process_frame
	if _map_tex == null:
		_map_img = img
var _fog_img: Image
var _fog_tex: ImageTexture
var _map_draw: MapDraw
var _talking := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock = _label("", 20, DIM)
	_pin(_clock, 1.0, 0.0, Rect2(-330, 58, 300, 30))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_clock)
	_compass = Compass.new()
	_compass.w = w
	_pin(_compass, 0.5, 0.0, Rect2(-320, 14, 640, 56))
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_compass)
	_build_title = _label("", 24, GOLD)
	_pin(_build_title, 0.5, 1.0, Rect2(-500, -150, 1000, 34))
	_build_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_build_title)
	_build_hint = RichTextLabel.new()
	_build_hint.bbcode_enabled = true
	_build_hint.scroll_active = false
	_build_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hint.add_theme_font_size_override("normal_font_size", 17)
	_build_hint.add_theme_color_override("default_color", DIM)
	_pin(_build_hint, 0.5, 1.0, Rect2(-560, -118, 1120, 60))
	add_child(_build_hint)
	_keys = HBoxContainer.new()
	_keys.add_theme_constant_override("separation", 14)
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin(_keys, 0.0, 1.0, Rect2(36, -98, 700, 26))
	add_child(_keys)
	# Behind an open screen the world dims, so the eye stays on the screen
	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.0, 0.0, 0.5)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.visible = false
	add_child(_shade)
	_frame = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.065, 0.06, 0.97)
	sb.border_color = Color(GOLD, 0.28)
	sb.set_border_width_all(1)
	sb.border_width_top = 3
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 28
	sb.set_content_margin_all(26)
	sb.content_margin_top = 20
	_frame.add_theme_stylebox_override("panel", sb)
	_frame.custom_minimum_size = Vector2(1120, 700)
	_pin(_frame, 0.5, 0.5, Rect2(-560, -350, 1120, 700))
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.visible = false
	add_child(_frame)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_frame.add_child(_body)
	w.inv.changed.connect(_on_inv)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(GOLD, 0.75)
	_xp_bar.add_theme_stylebox_override("background", bg)
	_xp_bar.add_theme_stylebox_override("fill", fg)
	_pin(_xp_bar, 0.0, 1.0, Rect2(36, -108, 300, 4))
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_bar)
	_xp_text = _label("", 15, Color(DIM, 0.8))
	_pin(_xp_text, 0.0, 1.0, Rect2(36, -132, 420, 22))
	add_child(_xp_text)
	_xp_pop = _label("", 17, GOLD)
	_pin(_xp_pop, 0.0, 1.0, Rect2(344, -117, 120, 22))
	_xp_pop.modulate.a = 0.0
	add_child(_xp_pop)
	skills_changed()
	for k in [["food", Color(0.85, 0.62, 0.3), 0], ["rest", Color(0.55, 0.65, 0.8), 1]]:
		var b := ProgressBar.new()
		b.show_percentage = false
		b.max_value = 100.0
		var bb := StyleBoxFlat.new()
		bb.bg_color = Color(0, 0, 0, 0.45)
		var bf := StyleBoxFlat.new()
		bf.bg_color = Color(k[1], 0.85)
		b.add_theme_stylebox_override("background", bb)
		b.add_theme_stylebox_override("fill", bf)
		_pin(b, 0.0, 1.0, Rect2(36 + k[2] * 134, -36, 126, 4))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		var l := _label("Food" if k[0] == "food" else "Rest", 13, Color(DIM, 0.85))
		_pin(l, 0.0, 1.0, Rect2(36 + k[2] * 134, -30, 126, 18))
		add_child(l)
		_needs[k[0]] = [b, l, bf, k[1]]
	_boons = _label("", 13, Color(0.92, 0.82, 0.55, 0.9))
	_pin(_boons, 0.0, 1.0, Rect2(36, -56, 420, 18))
	add_child(_boons)
	_hazard = _label("", 15, Color(0.95, 0.45, 0.35, 0.95))
	_pin(_hazard, 0.0, 1.0, Rect2(36, -80, 520, 20))
	_hazard.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hazard.add_theme_constant_override("shadow_offset_x", 1)
	_hazard.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_hazard)
	_saved = _label("", 16, DIM)
	_pin(_saved, 1.0, 1.0, Rect2(-330, -64, 300, 26))
	_saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saved.modulate.a = 0.0
	add_child(_saved)


var _saved: Label
var _needs := {}
var _boons: Label


## The meals you have eaten and your rest, as a short line over the food and rest bars.
var _hazard: Label


## The land's hardship while it is on you, in red above the bars: what it does and what wards it.
func set_hazard(t: String) -> void:
	if _hazard == null:
		return
	_hazard.text = t
	_hazard.modulate.a = 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.003)) if t != "" else 1.0


func set_boons(meals: Dictionary, rested: float) -> void:
	if _boons == null:
		return
	var bits := []
	for k in meals:
		var m: Array = meals[k]
		var thin: bool = float(m[0]) <= float(m[1]) * 0.3
		bits.append("%s %dm%s" % [Items.info(k).get("name", k), ceili(float(m[0]) / 60.0), " (thin)" if thin else ""])
	if rested > 0.0:
		bits.append("Rested %dm" % ceili(rested / 60.0))
	_boons.text = "   ".join(bits)


func set_needs(f: float, r: float) -> void:
	for k in [["food", f], ["rest", r]]:
		var n: Array = _needs.get(k[0], [])
		if n.is_empty():
			continue
		n[0].value = k[1]
		var low: bool = k[1] < 20.0
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006) if low else 1.0
		n[2].bg_color = Color(Color(0.85, 0.3, 0.25) if low else n[3], 0.85 * pulse)
		n[1].text = ("Hungry" if k[0] == "food" else "Weary") if low else ("Food" if k[0] == "food" else "Rest")
var _saved_tw: Tween
var _xp_bar: ProgressBar
var _xp_text: Label
var _xp_pop: Label
var _xp_tw: Tween
var _xp_sum := 0


## The thin bar of experience at the lower left, and the level beside it.
func skills_changed() -> void:
	if _xp_bar == null:
		return
	var s: WSkills = w.skills
	_xp_bar.max_value = WSkills.need(s.level)
	_xp_bar.value = s.xp
	var extra := "    %d to spend  [%s]" % [s.points, Game.key_text("skills")] if s.points > 0 else ""
	_xp_text.text = ("Level %d" % s.level) + ("   (the most there is)" if s.level >= WSkills.MAX_LEVEL else "") + extra
	if _panel_name == "skills":
		_draw_skills()


func xp_gained(n: int) -> void:
	if _xp_pop == null or n <= 0:
		return
	if _xp_tw and _xp_tw.is_running():
		_xp_tw.kill()
		_xp_sum += n
	else:
		_xp_sum = n
	_xp_pop.text = "+%d" % _xp_sum
	_xp_pop.modulate.a = 1.0
	_xp_tw = create_tween()
	_xp_tw.tween_interval(1.4)
	_xp_tw.tween_property(_xp_pop, "modulate:a", 0.0, 0.8)


# ------------------------------------------------------------------ what has been learned

func open_skills() -> void:
	_open("skills")


func _draw_skills() -> void:
	_clear()
	var s: WSkills = w.skills
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	top.add_child(_title("Skills"))
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 4)
	lv.add_child(_label(("Level %d    %d of %d toward the next" % [s.level, s.xp, WSkills.need(s.level)]) if s.level < WSkills.MAX_LEVEL else "Level %d, the most there is" % s.level, 17, PALE))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.max_value = 1.0
	bar.value = float(s.xp) / maxf(1.0, WSkills.need(s.level)) if s.level < WSkills.MAX_LEVEL else 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(GOLD, 0.8)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	lv.add_child(bar)
	top.add_child(lv)
	top.add_child(_chip("Trade: %s" % (w.trades.tname(w.trades.trade) if w.trades.trade != "" else "choose one"), w.trades.trade == "", func(): open_trade()))
	top.add_child(_chip("%d point%s to spend" % [s.points, "" if s.points == 1 else "s"], s.points > 0, func(): pass))
	_body.add_child(top)
	_close_and_rule(top)
	if s.points == 0:
		_body.add_child(_label("Experience comes from what you undo, make, build and find, and from the beacons you light.", 15, DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	for t in WSkills.TREES:
		var tr: Dictionary = WSkills.TREES[t]
		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(1, 1, 1, 0.03)
		cs.border_color = Color(1, 1, 1, 0.07)
		cs.set_border_width_all(1)
		cs.set_corner_radius_all(4)
		cs.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", cs)
		card.custom_minimum_size.x = 258
		row.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 5)
		card.add_child(col)
		var hd := HBoxContainer.new()
		hd.add_child(_label(tr.name, 22, GOLD))
		var sp := _label("%d" % s.spent_in(t), 18, DIM)
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hd.add_child(sp)
		col.add_child(hd)
		var tl := _label(tr.text, 12, DIM)
		tl.clip_text = true
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tl.custom_minimum_size.x = 230
		tl.tooltip_text = tr.text
		col.add_child(tl)
		for id in tr.skills:
			col.add_child(_skill_card(id))


func _skill_card(id: String) -> Button:
	var s: WSkills = w.skills
	var sk: Dictionary = WSkills.SKILLS[id]
	var r := s.rank(id)
	var why := s.blocked(id)
	var can := why == ""
	var b := Button.new()
	b.custom_minimum_size = Vector2(232, 82)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can else Control.CURSOR_ARROW
	b.tooltip_text = sk.text + ("" if can else "\n" + why)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GOLD, 0.1) if r > 0 else Color(1, 1, 1, 0.025)
	sb.border_color = Color(GOLD, 0.8) if can else (Color(GOLD, 0.35) if r > 0 else Color(1, 1, 1, 0.06))
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	b.add_theme_stylebox_override("normal", sb)
	var hs := sb.duplicate()
	hs.bg_color = Color(GOLD, 0.2) if can else sb.bg_color
	b.add_theme_stylebox_override("hover", hs)
	b.add_theme_stylebox_override("pressed", hs)
	b.add_theme_stylebox_override("focus", hs)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -8
	v.offset_top = 6
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_label(sk.name, 17, PALE if (can or r > 0) else DIM))
	var pips := ""
	for i in int(sk.ranks):
		pips += "●" if i < r else "○"
	var pl := _label(pips, 14, GOLD if r > 0 else DIM)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pl)
	v.add_child(h)
	var tx := _label(sk.text, 12, Color(PALE, 0.8) if (can or r > 0) else Color(DIM, 0.8))
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.custom_minimum_size.x = 210
	v.add_child(tx)
	if not can and why != "Mastered" and why != "No points to spend":
		v.add_child(_label(why, 12, Color(0.85, 0.5, 0.4, 0.85)))
	b.add_child(v)
	b.pressed.connect(func(): _learn(id))
	return b


func _learn(id: String) -> void:
	if w.skills.learn(id):
		w.sfx("bell", -8)
		w.autosave_soon(1.0)


## A quiet mark in the corner that the waste has been kept.
func saved_mark(ok: bool) -> void:
	if _saved == null:
		return
	_saved.text = "Saved" if ok else "Could not save"
	_saved.add_theme_color_override("font_color", DIM if ok else Color(0.85, 0.35, 0.3))
	if _saved_tw:
		_saved_tw.kill()
	_saved_tw = create_tween()
	_saved_tw.tween_property(_saved, "modulate:a", 0.8, 0.3)
	_saved_tw.tween_interval(1.6 if ok else 5.0)
	_saved_tw.tween_property(_saved, "modulate:a", 0.0, 0.8)


## Fixes a control to a point of the screen, by anchor and offsets.
func _pin(c: Control, ax: float, ay: float, r: Rect2) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


func _on_inv() -> void:
	if _panel != null and _panel_name in ["pack", "container"]:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_redraw_on_release = true   # never pull a button out from under a press: redraw when it lets go
			return
		_redraw.call_deferred()


var _redraw_on_release := false

func _release_check(e: InputEvent) -> void:
	if _redraw_on_release and e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		_redraw_on_release = false
		if _panel != null and _panel_name in ["pack", "container"]:
			_redraw.call_deferred()


## Standing at a bench: near any bench piece (measured flat, so a bench a step up or down still counts),
## or near the one this screen was opened at.
func at_bench() -> bool:
	if debug_bench:
		return true
	var p: Vector3 = w.player.global_position
	for pid in w.pieces:
		var pc: Dictionary = w.pieces[pid]
		if pc.kind == "bench" or w.builder.acts(pc.kind) == "bench":
			var q: Vector3 = pc.pos
			if Vector2(q.x - p.x, q.z - p.z).length() < 6.5 and absf(q.y - p.y) < 4.0:
				return true
	return false


func _label(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _title(t: String) -> Label:
	var l := _label(t, 34, PALE)
	l.add_theme_font_override("font", load("res://assets/fonts/Marcellus-Regular.ttf"))
	return l


func _btn(t: String, cb: Callable, size := 20, c := DIM) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_hover_color", PALE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.35))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


func _wrap(t: String, size := 20, c := PALE, width := 400) -> Label:
	var l := _label(t, size, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


func _scroll(min_h := 420.0) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, min_h)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	sc.add_child(v)
	_body.add_child(sc)
	return v


# ------------------------------------------------------------------ keys

func _input(e: InputEvent) -> void:
	_release_check(e)
	if not (e is InputEventKey or e is InputEventMouseButton or e is InputEventJoypadButton) or w.player == null:
		return
	if e is InputEventJoypadButton and _panel != null and e.pressed:
		# With a screen open the pad moves through it; B closes it
		if e.button_index == JOY_BUTTON_B:
			close_all()
			accept_event()
		return
	if get_tree().paused or w.hud.pause_panel.visible or w.hud.options_panel.visible:
		return
	var typing = get_viewport().gui_get_focus_owner()
	if (typing is LineEdit or typing is TextEdit) and e is InputEventKey:
		# While a name is being typed, every key is a letter: only Escape and Enter leave the field
		if e.pressed and e.physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
			typing.release_focus()
			accept_event()
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if k == KEY_ESCAPE and _panel != null:
			close_all()
			accept_event()
			return
		if k == KEY_ESCAPE and w.builder.active:
			w.builder.toggle()
			w.player.set_armed(true)
			accept_event()
			return
		# The hidden playtest menu
		if k == KEY_F8 and e.ctrl_pressed:
			if _panel_name == "dev":
				close_all()
			elif _panel == null:
				open_dev()
			accept_event()
			return
		if w.player.input_locked and _panel == null:
			return
	if w.player.input_locked and _panel == null:
		return
	if e.is_action_pressed("pack") or (e.is_action_pressed("codex") and not e.is_echo()):
		if _panel != null and _panel_name == "pack":
			close_all()
		else:
			# While building, the pack key opens the pieces to choose from
			open_inventory("build" if w.builder.active else "pack")
		accept_event()
	elif e.is_action_pressed("map"):
		if _panel_name == "map":
			close_all()
		else:
			open_map()
		accept_event()
	elif e.is_action_pressed("journal"):
		if _panel_name == "journal":
			close_all()
		else:
			open_journal()
		accept_event()
	elif e.is_action_pressed("skills"):
		if _panel_name == "skills":
			close_all()
		else:
			open_skills()
		accept_event()
	elif e.is_action_pressed("build"):
		if _panel == null:
			w.builder.toggle()
			w.player.set_armed(not w.builder.active)
		accept_event()
	elif e.is_action_pressed("reload") and w.builder.active and _panel == null:
		w.builder.turn()
		accept_event()
	elif _panel_name == "talk" and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_9 \
			and is_instance_valid(_talk_keys) and _talk_keys.is_inside_tree():
		# Number keys choose what to say
		var i: int = e.physical_keycode - KEY_1
		if i < _talk_keys.get_child_count() - 1:
			(_talk_keys.get_child(i) as Button).pressed.emit()
			accept_event()
	elif not get_viewport().gui_get_focus_owner() is LineEdit and _panel_name == "container" and e.is_action_pressed("reload"):
		_take_all()
		accept_event()
	elif not get_viewport().gui_get_focus_owner() is LineEdit and _panel_name == "pack" and _tab == "craft" and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and _rsel >= 0 and _rhere:
		_make(Items.RECIPES[_rsel])
		accept_event()
	if w.builder.active and _panel == null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if e.is_action_pressed("fire"):
			w.builder.place()
			accept_event()
		elif e.is_action_pressed("aim"):
			w.builder.dismantle()
			accept_event()
		elif e.is_action_pressed("interact") and w.builder.upgrade():
			accept_event()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			w.builder.choose(-1)
			accept_event()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			w.builder.choose(1)
			accept_event()


var _shade: ColorRect
var _panel_name := ""


const SMALL := ["boons", "rest", "planter", "portal", "travel", "cat", "shrine"]


func _open(name: String) -> void:
	if name != _panel_name:
		if name == "journal":
			w.sfx("page", -10)
		elif name == "pack":
			w.sfx("cloth", -10)
	_panel_name = name
	_panel = _frame
	# The small screens sit in a smaller frame
	var sz := Vector2(640, 440) if name in SMALL else Vector2(1120, 700)
	_frame.custom_minimum_size = sz
	_pin(_frame, 0.5, 0.5, Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y))
	_frame.visible = true
	_shade.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	w.player.input_locked = true
	w.hud.set_prompt("", 0.0)
	_redraw()


func close_all() -> void:
	if _panel == null:
		return
	_panel = null
	_panel_name = ""
	_cont_id = ""
	if _talking != "":
		w.speaker_done(_talking)
	_talking = ""
	if _babble:
		_babble.hush()
	_frame.visible = false
	_shade.visible = false
	if not w._pfail:
		w.player.input_locked = false
	if w.player.weapon:
		w.player.weapon.hold_fire = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return _panel != null


func _clear() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


var _drawn_at := ""


func _redraw() -> void:
	# The lists keep where they were scrolled to: a click in one does not throw it back to the top
	var keep: Array = []
	var where := _panel_name + "/" + _tab
	if where != _drawn_at:
		_drawn_at = where
	elif is_instance_valid(_body):
		for sc in _body.find_children("*", "ScrollContainer", true, false):
			keep.append((sc as ScrollContainer).scroll_vertical)
	_redraw_now()
	if not keep.is_empty():
		_restore_scrolls.call_deferred(keep)


func _restore_scrolls(keep: Array) -> void:
	await get_tree().process_frame   # once the new lists have their size
	if not is_instance_valid(_body):
		return
	var all := _body.find_children("*", "ScrollContainer", true, false)
	if all.size() != keep.size():
		return
	for i in all.size():
		(all[i] as ScrollContainer).scroll_vertical = int(keep[i])


var redraws := 0   ## how many times a screen was drawn (a testing aid)

func _redraw_now() -> void:
	redraws += 1
	match _panel_name:
		"pack":
			_draw_pack()
		"container":
			_draw_container()
		"journal":
			_draw_journal()
		"map":
			_draw_map()
		"travel":
			_draw_travel()
		"skills":
			_draw_skills()
		"rest":
			_draw_rest()
		"boons":
			_draw_boons()
		"dev":
			_draw_dev()
		"brew":
			_draw_brew()
		"trade":
			_draw_trade()
		"planter":
			_draw_planter()
		"portal":
			_draw_portal()
		"cat":
			_draw_cat()
		"shrine":
			_draw_shrine()
		"page":
			_draw_page()
		"ending":
			_draw_ending()


# ------------------------------------------------------------------ the strip along the top

func _process(_delta: float) -> void:
	if w.player == null:
		return
	var h := int(w.clock)
	var mn := int((w.clock - h) * 60.0)
	var part := "Night" if w.night else ("Dawn" if w.clock < 7.0 else ("Dusk" if w.clock >= 18.0 else "Day"))
	_clock.text = "Day %d   %02d:%02d   %s" % [w.day, h, mn, part]
	if w.weather:
		_clock.text += "\n" + w.weather.label()
	_compass.w = w
	_compass.queue_redraw()
	_keys.visible = _panel == null and not w.builder.active
	_refresh_keys()
	if _panel_name == "journal" and journal_dirty:
		journal_dirty = false
		_draw_journal()
	if _panel_name == "map" and _map_draw:
		_map_draw.queue_redraw()
		if map_dirty:
			_update_fog()


## The row of keys under the level bar: each key in a small frame, and what it opens beside it.
func _refresh_keys() -> void:
	var rows := [["pack", "Pack"], ["map", "Map"], ["journal", "Journal"], ["skills", "Skills"], ["build", "Build"]]
	var sig := ""
	for r in rows:
		sig += Game.key_text(r[0]) + "|"
	if sig == _keys_sig:
		return
	_keys_sig = sig
	for c in _keys.get_children():
		c.queue_free()
	for r in rows:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cap := PanelContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.03, 0.035, 0.6)
		sb.border_color = Color(GOLD, 0.45)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 7
		sb.content_margin_right = 7
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		cap.add_theme_stylebox_override("panel", sb)
		cap.add_child(_label(Game.key_text(r[0]), 14, PALE))
		hb.add_child(cap)
		hb.add_child(_label(r[1], 15, Color(DIM, 0.9)))
		_keys.add_child(hb)


## The strip shown while building: the piece, what it costs against what is carried, and its neighbours.
func set_build_bar(k: String, sel: int) -> void:
	if k == "":
		_build_title.text = ""
		_build_hint.text = ""
		return
	var pc: Dictionary = Items.PIECES[k]
	var n: int = Items.PIECE_ORDER.size()
	var prev: String = Items.PIECES[Items.PIECE_ORDER[posmod(sel - 1, n)]].name
	var next: String = Items.PIECES[Items.PIECE_ORDER[posmod(sel + 1, n)]].name
	_build_title.text = "%s" % pc.name
	_build_hint.text = "[center]%s\n[color=#8d877b]‹ %s      %s      %s ›[/color]\n[color=#8d877b][%s] choose a piece    %s on a wall or floor: build it up to stone, then iron[/color][/center]" % [cost_bb(w.skills.cost(pc.cost)), prev, pc.text, next, Game.key_text("pack"), Game.key_text("interact")]


# ------------------------------------------------------------------ the pack, and making things

func open_inventory(tab := "pack") -> void:
	_tab = tab
	if tab == "build":
		_bcat = str(Items.PIECES[w.builder.kind()].group)   # open where the piece in hand is
	_open("pack")


func _pack_header() -> void:
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.add_child(WGlyph.make("salt", 22, false))
	right.add_child(_label("%d" % w.inv.count("salt"), 18, PALE))
	_header("Pack", [["pack", "Carried"], ["wear", "Wear"], ["craft", "Make"], ["arms", "Arms"], ["build", "Build"]], _tab,
		func(t): _tab = t; _redraw(), right)


## A screen's head: its name, its tabs (each underlined when chosen), something on the right,
## and a close button. A thin rule runs beneath.
func _header(title: String, tabs: Array, current: String, pick: Callable, right: Control = null) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var t := _title(title)
	t.custom_minimum_size.x = 150
	hb.add_child(t)
	for tb in tabs:
		hb.add_child(_tab_btn(tb[1], tb[0] == current, func(): pick.call(tb[0])))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(fill)
	if right:
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(right)
		hb.add_child(_gap_x(14))
	var x := _btn("✕  Esc", func(): close_all(), 15, DIM)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.focus_mode = Control.FOCUS_NONE
	hb.add_child(x)
	_body.add_child(hb)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(rule)


## Ends a screen's top row: a close button on the right and a thin rule beneath.
func _close_and_rule(top: HBoxContainer) -> void:
	var has_fill := false
	for c in top.get_children():
		if c is Control and c.size_flags_horizontal & Control.SIZE_EXPAND:
			has_fill = true
	if not has_fill:
		var fill := Control.new()
		fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(fill)
	var x := _btn("✕  Esc", func(): close_all(), 15, DIM)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.focus_mode = Control.FOCUS_NONE
	top.add_child(x)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(rule)


func _tab_btn(t: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_font_override("font", load("res://assets/fonts/Marcellus-Regular.ttf"))
	b.add_theme_color_override("font_color", GOLD if on else DIM)
	b.add_theme_color_override("font_hover_color", PALE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(GOLD, 0.08) if on else Color(1, 1, 1, 0.05 if st == "hover" else 0.0)
		sb.border_color = GOLD if on else Color(1, 1, 1, 0.25 if st == "hover" else 0.0)
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override(st, sb)
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	# Taken on the press itself, not the release: a screen drawn afresh between the two loses no click
	b.button_down.connect(cb)
	return b


func _gap_x(wd: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = wd
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c



func _draw_pack() -> void:
	_clear()
	_pack_header()
	if _tab == "craft":
		_draw_craft()
		return
	if _tab == "arms":
		_draw_arms()
		return
	if _tab == "build":
		_draw_build_guide()
		return
	if _tab == "wear":
		_draw_wear()
		return
	# Sort tools along the top, then the pack on the left and the chosen thing on the right
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	for f in FILTERS:
		var fid: String = f[0]
		bar.add_child(_chip(f[1], _filter == fid, func(): _filter = fid; _redraw()))
	var used := 0
	for s in w.inv.slots:
		if s != null:
			used += 1
	var fill := _label("%d of %d slots" % [used, w.inv.slots.size()], 16, DIM)
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(fill)
	bar.add_child(_chip("Tidy", false, func(): _tidy(w.inv); _sel = -1; _redraw()))
	_body.add_child(bar)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(split)
	# A big pack scrolls rather than pushing the screen's tabs out of reach
	var left := ScrollContainer.new()
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size.x = 6 * 86 + 5 * 6 + 14
	left.add_child(_slot_grid(w.inv, func(i, right): _pack_click(i, right), 6, _sel, _kinds_of(_filter), 86))
	split.add_child(left)
	var side := _side_panel(split)
	var s = w.inv.slots[_sel] if _sel >= 0 and _sel < w.inv.slots.size() else null
	if s == null:
		side.add_child(_label("Nothing chosen", 22, DIM))
		side.add_child(_wrap("Click a thing to see it. Right click eats, uses or wears it at once.", 17, DIM, 330))
		return
	var info: Dictionary = Items.info(s.id)
	var n := int(s.n)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_icon(s.id, 44))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.add_child(_label(info.name, 24, PALE))
	hv.add_child(_label("%s,  %d carried" % [KIND_NAMES.get(info.kind, info.kind), n], 15, DIM))
	head.add_child(hv)
	side.add_child(head)
	side.add_child(_wrap(info.text, 17, PALE, 330))
	var facts: Array = []
	if info.has("heal") and float(info.heal) > 0.0:
		facts.append("Heals %d" % int(info.heal))
	if info.has("food"):
		facts.append("Feeds %d" % int(info.food))
	if int(info.value) > 0:
		facts.append("Worth %d salt each" % int(info.value))
	if not facts.is_empty():
		side.add_child(_label(",  ".join(facts), 16, GOLD))
	side.add_child(_gap(6))
	if info.kind == "spirit":
		side.add_child(_wrap("Cold. Rest by a fire to kindle it." if w.spirits.is_spent(s.id) else "Ready to call.", 16, DIM))
	if info.kind in ["food", "medicine", "boat", "book", "brew", "spirit"]:
		side.add_child(_action({"food": "Eat", "boat": "Launch", "book": "Read", "brew": "Drink", "spirit": "Call"}.get(info.kind, "Use"), func(): _use_item(_sel), "Right click"))
	if info.kind == "wear":
		var sid: String = s.id
		side.add_child(_action("Wear", func(): _wear(sid); _sel = -1; _redraw(), "Right click"))
	side.add_child(_action("Drop one", func(): _drop(_sel, 1)))
	if n > 1:
		side.add_child(_action("Drop all %d" % n, func(): _drop(_sel, n)))
	for id in _near_players():
		side.add_child(_action("Give to %s" % Net.name_of(id), func(): _give_to(id, _sel, n), "", GOLD))
		if n > 1:
			side.add_child(_action("Give half to %s" % Net.name_of(id), func(): _give_to(id, _sel, maxi(1, n / 2)), "", GOLD))


const FILTERS := [["all", "All"], ["food", "Food and aid"], ["material", "Materials"], ["gear", "Gear and ammo"], ["keep", "Keepsakes"]]
const KIND_NAMES := {"material": "Material", "food": "Food", "medicine": "Medicine", "aid": "Aid", "seed": "Seed", "tool": "Tool",
	"ammo": "Ammunition", "wear": "Clothing", "part": "Gun fittings", "trinket": "Trinket", "trophy": "Trophy", "quest": "Errand", "boat": "Boat", "book": "Lost book", "brew": "Draught", "spirit": "Spirit relic"}
var _filter := "all"


func _kinds_of(f: String) -> Array:
	match f:
		"food":
			return ["food", "medicine", "aid", "seed", "brew", "spirit"]
		"material":
			return ["material"]
		"gear":
			return ["tool", "ammo", "wear", "part"]
		"keep":
			return ["trinket", "trophy", "quest"]
	return []


## Gathers like with like, fills each stack, and orders the pack by kind and then by name.
func _tidy(bag: Inventory) -> void:
	var totals := {}
	for s in bag.slots:
		if s != null:
			totals[s.id] = int(totals.get(s.id, 0)) + int(s.n)
	var order := ["spirit", "medicine", "brew", "aid", "food", "seed", "ammo", "tool", "wear", "material", "trinket", "trophy", "quest"]
	var ids := totals.keys()
	ids.sort_custom(func(a, b):
		var ka := order.find(Items.info(a).kind)
		var kb := order.find(Items.info(b).kind)
		return ka < kb if ka != kb else Items.iname(a) < Items.iname(b))
	bag.slots.fill(null)
	for id in ids:
		bag.add(id, int(totals[id]))
	bag.changed.emit()
	w.sfx("step", -8, null, 0.7)


## The thing's own small picture on a tile.
func _icon(id: String, px := 34) -> Control:
	return WGlyph.make(id, px)


func _chip(t: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", GOLD if on else DIM)
	b.add_theme_color_override("font_hover_color", PALE)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(GOLD, 0.16) if on else Color(1, 1, 1, 0.1 if st == "hover" else 0.04)
		sb.border_color = Color(GOLD, 0.6) if on else Color(1, 1, 1, 0.1)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	return b


## The column on the right of a screen, where the chosen thing is shown.
func _side_panel(parent: Control) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03)
	sb.border_color = Color(1, 1, 1, 0.07)
	sb.border_width_left = 1
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A long account scrolls in its own panel, never stretching the screen past its frame
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	parent.add_child(p)
	return v


## A full-width button in the side column, with an optional key hint on its right.
func _action(t: String, cb: Callable, key := "", c := PALE) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.4))
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.1 if st == "hover" else 0.05)
		sb.border_color = Color(c, 0.9 if st == "hover" else 0.35)
		sb.border_width_left = 3
		sb.content_margin_left = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override(st, sb)
	if key != "":
		var k := _label(key, 14, DIM)
		k.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		k.offset_left = -160
		k.offset_right = -12
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(k)
	b.pressed.connect(cb)
	return b


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Fellow survivors close enough to hand something to.
func _near_players() -> Array:
	var out: Array = []
	for id in w.avatars:
		var a = w.avatars[id]
		if is_instance_valid(a) and a.visible and a.global_position.distance_to(w.player.global_position) < 8.0:
			out.append(id)
	return out


func _use_item(i: int) -> void:
	var s = w.inv.slots[i]
	if s == null:
		return
	var kind: String = Items.info(s.id).kind
	var done := false
	if kind == "boat":
		done = w.launch_boat(s.id)
		if done:
			close_all()
			return
	elif kind == "book":
		done = w.read_book(s.id)
	elif kind == "brew":
		done = w.alchemy.drink(s.id)
	elif kind == "spirit":
		if w.spirits.summon(s.id):
			close_all()
		return
	else:
		done = w.eat(s.id)
	if done:
		if w.inv.slots[i] == null:
			_sel = -1
		_redraw()


## Takes n of the chosen stack out of the pack; returns [id, n] or null.
func _take_from(i: int, n: int):
	var s = w.inv.slots[i]
	if s == null:
		return null
	n = clampi(n, 1, int(s.n))
	var id: String = s.id
	s.n -= n
	if s.n <= 0:
		w.inv.slots[i] = null
		_sel = -1
	w.inv.changed.emit()
	return [id, n]


func _drop(i: int, n: int) -> void:
	var it = _take_from(i, n)
	if it == null:
		return
	var fwd: Vector3 = -w.player.global_transform.basis.z
	w.shared("_rq_satchel", [Net.me(), w.player.global_position + fwd * 1.2, [it], false])
	w.hud.notify("Dropped %d %s." % [it[1], Items.iname(it[0])])


func _give_to(id: int, i: int, n: int) -> void:
	var it = _take_from(i, n)
	if it == null:
		return
	w.shared("_rq_gift", [Net.me(), id, [it]])
	w.char_save_soon()
	w.hud.notify("Gave %d %s to %s." % [it[1], Items.iname(it[0]), Net.name_of(id)])


# ------------------------------------------------------------------ arms: what is carried, fitted and made

## What arms, parts and plate cost this pilgrim: their skills, then their trade.
func _acost(c: Dictionary) -> Dictionary:
	return w.trades.arms_cost(w.skills.cost(c))


func _arms_pay(cost: Dictionary, done: Callable) -> void:
	if not w.stock_pay(_acost(cost)):
		return
	done.call()
	w.sfx("carve", -6)
	w.rearm()
	_redraw()


func _arms_btn(text: String, cost: Dictionary, bench: bool, done: Callable) -> Button:
	var c: Dictionary = _acost(cost)
	var ok: bool = bench and w.stock_has_all(c)
	var b := _btn("%s   %s" % [text, Items.cost_text(c)], func(): _arms_pay(cost, done), 17, PALE if ok else DIM)
	b.disabled = not ok
	return b


const ARMS_GROUPS := [["guns", "Guns"], ["blades", "Blades"], ["thrown", "Thrown"], ["kits", "Kits"], ["relics", "Relics"]]
var _acat := "guns"
var _asel := ""


## A card in a grid: picture, name, a line beneath, what it costs (if anything), and one button.
func _card(pic: String, title: String, sub: String, sub_c: Color, cost: Dictionary, btn: String, cb: Callable, enabled: bool, on: bool, pick: Callable, info := "") -> PanelContainer:
	var card := PanelContainer.new()
	card.tooltip_text = title + ("\n" + info if info != "" else "")
	card.custom_minimum_size = Vector2(272, 0)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GOLD, 0.1) if on else Color(1, 1, 1, 0.045)
	sb.border_color = Color(GOLD, 0.85) if on else Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)
	card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pick.call())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(WGlyph.make(pic, 46))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := _label(title, 17, PALE)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hv.add_child(nm)
	hv.add_child(_label(sub, 13, sub_c))
	head.add_child(hv)
	v.add_child(head)
	if info != "":
		v.add_child(_wrap(info, 13, DIM, 250))
	# What it takes, by name, so it can be read without knowing every picture
	if not cost.is_empty():
		var need := HFlowContainer.new()
		need.add_theme_constant_override("h_separation", 10)
		need.add_theme_constant_override("v_separation", 2)
		need.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in cost:
			var have: int = w.stock_count(k)
			var c := HBoxContainer.new()
			c.add_theme_constant_override("separation", 3)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(WGlyph.make(k, 18, false))
			c.add_child(_label("%d %s" % [int(cost[k]), Items.iname(k)], 13, OK_C if have >= int(cost[k]) else NO_C))
			c.tooltip_text = "%s: you have %d" % [Items.iname(k), have]
			need.add_child(c)
		v.add_child(need)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.custom_minimum_size.y = 30
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(fill)
	if btn != "":
		var b := _primary(btn, cb, enabled, 15)
		b.custom_minimum_size = Vector2(72, 0)
		foot.add_child(b)
	v.add_child(foot)
	return card


func _card_grid(min_h := 470.0) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, min_h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	return grid


## Where a survivor may change what they carry: at a workbench, by a lit fire, or in a town. Out on the
## road you fight with what you brought.
func can_rearm() -> bool:
	return at_bench() or w.near_fire(w.player.global_position, 8.0)


func _draw_arms() -> void:
	var a: Dictionary = w.arms
	var bench: bool = at_bench()
	var home: bool = can_rearm()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(_pill("Workbench" if bench else "Making and fitting need a workbench", bench))
	if not home:
		top.add_child(_pill("Change what you carry at camp, in a town or at a workbench", false))
	var wn := WArms.worn(a)
	if wn.guard > 0.0:
		top.add_child(_pill("Clothing turns aside %d%% of harm" % int(round(wn.guard * 100.0)), true))
	_body.add_child(top)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(split)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 4)
	rail.custom_minimum_size.x = 170
	split.add_child(rail)
	for g in ARMS_GROUPS:
		rail.add_child(_rail_btn(g[1], 0, g[0] == _acat, func(): _acat = g[0]; _asel = ""; _redraw()))
	var grid := _card_grid()
	split.add_child(grid.get_parent())
	if _acat == "guns":
		grid.columns = 1
		grid.get_parent().custom_minimum_size.x = 284
	var side := _side_panel(split)
	side.custom_minimum_size.x = 250
	var rows: Array = []   # [id, title, sub, sub colour, cost, button, callback, enabled]
	match _acat:
		"guns":
			var order: Array = ArmsDB.GUNS.keys()
			order.sort_custom(func(x, y): return int(x in a.owned) > int(y in a.owned))
			for g in order:
				var sp: Dictionary = ArmsDB.GUNS[g]
				var owned: bool = g in a.owned
				var place: int = WArms.carried(a).find(g) if owned else -1
				var t: int = int(a.tier.get(g, 0))
				if place >= 0:
					rows.append([g, sp.name, "%s  ·  %s" % [["Carried  ·  long gun 1", "Carried  ·  long gun 2", "Carried  ·  side arm"][place], WArms.TIERS[t]], GOLD, {}, "", Callable(), false])
				elif owned:
					rows.append([g, sp.name, "%s  ·  %s" % ["Long gun" if sp.slot == "primary" else "Side arm", WArms.TIERS[t]], DIM, {}, "Carry", func(): _carry(g, _free_place(g)), home])
				else:
					var c: Dictionary = _acost(WArms.MAKE[g])
					rows.append([g, sp.name, "Not made", Color(DIM, 0.7), c, "Make", func(): _arms_pay(WArms.MAKE[g], func(): a.owned.append(g); WArms.carry(a, g, _free_place(g))), bench and w.stock_has_all(c)])
		"blades", "thrown", "kits":
			var k: Array = []
			for kk in WArms.KINDS:
				if kk[0] == _acat:
					k = kk
			var tb := WArms.table(k[0])
			for id in tb:
				if id in a[k[0]]:
					var on: bool = a[k[1]] == id
					rows.append([id, tb[id].name, "Carried" if on else "Owned", GOLD if on else DIM, {}, "" if on else "Carry", func(): a[k[1]] = id; w.rearm(); _redraw(), home])
				else:
					var c: Dictionary = _acost(WArms.MAKE[id])
					rows.append([id, tb[id].name, "Not made", Color(DIM, 0.7), c, "Make", func(): _arms_pay(WArms.MAKE[id], func(): a[k[0]].append(id); a[k[1]] = id), bench and w.stock_has_all(c)])
		"relics":
			for id in WArms.RELICS:
				var it: Dictionary = WArms.RELICS[id]
				var key := Game.key_text("slot_%d" % (8 if id == "claw" else 9))
				if id in a.relics:
					rows.append([id, it.name, "Carried  ·  key %s" % key, GOLD, {}, "", Callable(), false])
				else:
					var c: Dictionary = _acost(it.cost)
					rows.append([id, it.name, "Not made", Color(DIM, 0.7), c, "Make", func(): _arms_pay(it.cost, func(): a.relics.append(id); w.player.relics.refresh()), bench and w.stock_has_all(c)])
		"wear":
			for id in WArms.WEAR:
				var it: Dictionary = WArms.WEAR[id]
				var on: bool = str(a.wear.get(it.slot, "")) == id
				var slot_name: String = it.slot.capitalize()
				if on:
					rows.append([id, it.name, "Worn  ·  %s" % slot_name, GOLD, {}, "Take off", func(): _unwear(it.slot), true])
				elif w.inv.count(id) > 0:
					rows.append([id, it.name, "In your pack  ·  %s" % slot_name, DIM, {}, "Wear", func(): _wear(id), true])
				else:
					var c: Dictionary = _acost(it.cost)
					rows.append([id, it.name, "%s  ·  not made" % slot_name, Color(DIM, 0.7), c, "Make", func(): _arms_pay(it.cost, func(): w.give([[id, 1]])), bench and w.stock_has_all(c)])
	if _asel == "" and not rows.is_empty():
		_asel = rows[0][0]
	for r in rows:
		var id: String = r[0]
		grid.add_child(_card(id, r[1], r[2], r[3], r[4], r[5], r[6], r[7], id == _asel, func(): _asel = id; _psel = ""; _redraw()))
	_arms_side(side, a, bench)


## What is chosen in the arms screen, in full.
func _arms_side(side: VBoxContainer, a: Dictionary, bench: bool) -> void:
	var id := _asel
	if id == "":
		return
	if ArmsDB.GUNS.has(id) and id in a.owned:
		_gun_view(side, a, id, bench)
		return
	side.add_child(WGlyph.make(id, 72))
	if ArmsDB.GUNS.has(id):
		var sp: Dictionary = ArmsDB.GUNS[id]
		var t: int = int(a.tier.get(id, 0))
		side.add_child(_label(sp.name, 23, PALE))
		side.add_child(_label(WArms.TIERS[t], 15, GOLD))
		var dmg := float(sp.dmg) * WArms.tier_mult(t)
		_stat(side, "Harm", "%d%s" % [int(round(dmg)), " × %d" % int(sp.pellets) if int(sp.pellets) > 1 else ""], clampf(dmg * float(sp.pellets) / 150.0, 0.05, 1.0))
		_stat(side, "Shots a second", "%.1f" % (1.0 / float(sp.rate)), clampf((1.0 / float(sp.rate)) / 12.0, 0.05, 1.0))
		_stat(side, "Reach", "%d m" % int(sp.range), clampf(float(sp.range) / 400.0, 0.05, 1.0))
		_stat(side, "Holds", str(Arms.mag_of(id)), clampf(Arms.mag_of(id) / 60.0, 0.05, 1.0))
		side.add_child(_wrap(_waste_text(sp.text), 15, Color(PALE, 0.8), 220))
		side.add_child(_cost_line(_acost(WArms.MAKE[id])))
		return
	var info := {}
	for kk in WArms.KINDS:
		if WArms.table(kk[0]).has(id):
			info = WArms.table(kk[0])[id]
	if WArms.RELICS.has(id):
		info = WArms.RELICS[id]
	if WArms.WEAR.has(id):
		info = WArms.WEAR[id]
	if info.is_empty():
		return
	side.add_child(_label(info.name, 23, PALE))
	var bt: int = int(a.tier.get(id, 0))
	if ArmsDB.MELEE.has(id):
		side.add_child(_label(WArms.TIERS[bt], 15, GOLD))
		side.add_child(_practice_line("blade"))
	if info.has("dmg"):
		var hd := float(info.dmg) * (WArms.tier_mult(bt) if ArmsDB.MELEE.has(id) else 1.0)
		_stat(side, "Harm", str(int(round(hd))), clampf(hd / 150.0, 0.05, 1.0))
	# A blade one owns can be worked up at a bench like a gun
	if ArmsDB.MELEE.has(id) and id in a.blades and bt < 3:
		var tc: Dictionary = _acost(WArms.tier_cost(bt + 1, id))
		side.add_child(_secondary("Work on it: %s" % WArms.TIERS[bt + 1], func(): _arms_pay(WArms.tier_cost(bt + 1, id), func(): a.tier[id] = bt + 1), bench and w.stock_has_all(tc)))
		side.add_child(_cost_line(tc))
	if info.has("guard"):
		_stat(side, "Turns aside", "%d%%" % int(round(float(info.guard) * 100.0)), clampf(float(info.guard) / 0.25, 0.05, 1.0))
	if info.has("plate"):
		var slot: String = info.slot
		var on := str(a.wear.get(slot, "")) == id
		var whole := float(info.plate)
		var left := WArms.plate_left(a, slot) if on else float(a.get("plate", {}).get(id, whole))
		_stat(side, "Plate", "%d / %d" % [int(left), int(whole)] + ("  broken" if left <= 0.0 else ""), clampf(left / whole, 0.02, 1.0))
		var mc := WArms.mend_cost(a, slot) if on else {}
		if not mc.is_empty():
			var ok: bool = bench and w.stock_has_all(mc)
			var b := _btn("Mend" if bench else "Mend (at a workbench)", func(): _arms_pay(mc, func(): WArms.mend(a, slot); w._armour_hud()), 17, GOLD if ok else Color(DIM, 0.6))
			b.disabled = not ok
			side.add_child(b)
			side.add_child(_cost_line(mc))
	side.add_child(_wrap(_waste_text(str(info.get("text", ""))), 15, Color(PALE, 0.8), 220))


var _psel := ""      ## the chosen part in the gun view


## Takes up gun g into a place ("primary", "primary2" or "secondary").
func _carry(g: String, place: String) -> void:
	WArms.carry(w.arms, g, place)
	w.rearm()
	_redraw()


## Where a gun newly taken up goes: a side arm to its place; a long gun to the empty second place, or
## else in place of the long gun not in hand.
func _free_place(g: String) -> String:
	var a: Dictionary = w.arms
	if ArmsDB.GUNS[g].slot == "secondary":
		return "secondary"
	if str(a.get("primary2", "")) == "":
		return "primary2"
	var held: String = w.player.weapon.gun() if w.player and w.player.weapon else ""
	return "primary" if held == str(a.get("primary2", "")) else "primary2"


## Under the gun's name: where it is carried, and the ways to carry it or lay it down.
func _carry_line(side: VBoxContainer, a: Dictionary, g: String) -> void:
	var home := can_rearm()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	side.add_child(row)
	var lg: Array = WArms.carried(a)
	if ArmsDB.GUNS[g].slot == "secondary":
		if lg[2] != g:
			row.add_child(_secondary("Carry as side arm", func(): _carry(g, "secondary"), home, 14))
	elif g in [lg[0], lg[1]]:
		if lg[1] != "":
			row.add_child(_secondary("Lay it down", func(): WArms.put_away(a, g); w.rearm(); _redraw(), home, 14))
	else:
		for i in 2:
			var other: String = lg[i]
			var label := "Carry as long gun 2" if other == "" else "Carry instead of %s" % ArmsDB.GUNS[other].name
			row.add_child(_secondary(label, func(): _carry(g, ["primary", "primary2"][i]), home, 14))
	if not home and row.get_child_count() > 0:
		side.add_child(_label("Only at camp, in a town or at a workbench.", 13, DIM))


## The gun view: the gun turning slowly as it is now fitted, its measures, every part it can take
## by place, and the chosen part with its grade, traits and what reworking it costs.
func _gun_view(side: VBoxContainer, a: Dictionary, g: String, bench: bool) -> void:
	var sp: Dictionary = Arms.spec_of(g)
	var t: int = int(a.tier.get(g, 0))
	side.add_child(_gun_preview(g, Vector2(540, 170)))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_label(sp.name, 23, PALE))
	var tl := _label(WArms.TIERS[t], 15, GOLD)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tl)
	side.add_child(head)
	_carry_line(side, a, g)
	side.add_child(_practice_line(g))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	side.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size.x = 250
	cols.add_child(left)
	var dmg := float(sp.dmg) * WArms.tier_mult(t)
	_stat(left, "Harm", "%d%s" % [int(round(dmg)), " × %d" % int(sp.pellets) if int(sp.pellets) > 1 else ""], clampf(dmg * float(sp.pellets) / 150.0, 0.05, 1.0))
	_stat(left, "Shots a second", "%.1f" % (1.0 / float(sp.rate)), clampf((1.0 / float(sp.rate)) / 12.0, 0.05, 1.0))
	_stat(left, "Reach", "%d m" % int(sp.range), clampf(float(sp.range) / 400.0, 0.05, 1.0))
	_stat(left, "Steadiness", "%d" % int(round(100.0 / maxf(0.2, float(sp.kick)))), clampf(0.6 / maxf(0.2, float(sp.kick)), 0.05, 1.0))
	_stat(left, "Aim speed", "%d%%" % int(round(float(sp.aim) * 100.0)), clampf(float(sp.aim) / 1.6, 0.05, 1.0))
	_stat(left, "Holds", str(Arms.mag_of(g)), clampf(Arms.mag_of(g) / 60.0, 0.05, 1.0))
	if t < 3:
		var c: Dictionary = _acost(WArms.tier_cost(t + 1, g))
		var wb := _secondary("Work on it: %s" % WArms.TIERS[t + 1], func(): _arms_pay(WArms.tier_cost(t + 1, g), func(): a.tier[g] = t + 1), bench and w.stock_has_all(c))
		left.add_child(wb)
		left.add_child(_cost_line(c))
	# Every part it can take, by place on the gun
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var parts: Array = WArms.mounts_for(g)
	if parts.is_empty():
		right.add_child(_label("Takes no parts.", 15, DIM))
		return
	var have: Array = a.parts.get(g, [])
	var on: Array = a.mounts.get(g, [])
	if _psel == "" or not _psel in parts:
		_psel = on[0] if not on.is_empty() else parts[0]
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 210)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var last_slot := ""
	var order: Array = parts.duplicate()
	var slot_order := ["sight", "muzzle", "barrel", "grip", "stock", "receiver", "mag", "ammo"]
	order.sort_custom(func(x, y): return slot_order.find(ArmsDB.ATTACHMENTS[x].slot) < slot_order.find(ArmsDB.ATTACHMENTS[y].slot))
	for m in order:
		var at: Dictionary = ArmsDB.ATTACHMENTS[m]
		if at.slot != last_slot:
			last_slot = at.slot
			list.add_child(_label(ArmsDB.SLOT_NAMES[at.slot], 13, DIM))
		var gr := WArms.grade_of(a, g, m)
		var r := int(gr.get("r", 0)) if m in have else 0
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.custom_minimum_size = Vector2(0, 30)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(GOLD, 0.12) if m == _psel else Color(1, 1, 1, 0.03)
		sb.border_color = WArms.GRADES[r].color if m in on else Color(0, 0, 0, 0)
		sb.border_width_left = 3
		sb.set_corner_radius_all(3)
		row.add_theme_stylebox_override("normal", sb)
		var hs := sb.duplicate()
		hs.bg_color = Color(1, 1, 1, 0.08)
		row.add_theme_stylebox_override("hover", hs)
		row.add_theme_stylebox_override("pressed", hs)
		var hb := HBoxContainer.new()
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 8
		hb.offset_right = -8
		hb.add_theme_constant_override("separation", 6)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := _label(WArms.part_name(a, g, m), 15, WArms.GRADES[r].color if m in have else Color(DIM, 0.7))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(nm)
		var state := _label("Fitted" if m in on else ("Owned" if m in have else ""), 12, GOLD if m in on else DIM)
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(state)
		row.add_child(hb)
		row.pressed.connect(func(): _psel = m; _redraw())
		list.add_child(row)
	# The chosen part
	var m2 := _psel
	var at2: Dictionary = ArmsDB.ATTACHMENTS[m2]
	var gr2 := WArms.grade_of(a, g, m2)
	var r2 := int(gr2.get("r", 0)) if m2 in have else 0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	side.add_child(box)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(_label(WArms.part_name(a, g, m2), 18, WArms.GRADES[r2].color))
	if m2 in have:
		line.add_child(_label(WArms.GRADES[r2].name, 14, WArms.GRADES[r2].color))
	box.add_child(line)
	var md: Dictionary = at2.get("mods", {}).duplicate()
	var words := WArms.mods_text(md)
	box.add_child(_wrap(at2.text + ("  " + words + "." if words != "" else ""), 14, Color(PALE, 0.8), 540))
	if m2 in have and not gr2.get("t", []).is_empty():
		var tn: Array = []
		for tid in gr2.t:
			tn.append("%s (%s)" % [WArms.TRAITS[tid].name, WArms.TRAITS[tid].text])
		box.add_child(_wrap("Traits: " + ", ".join(tn), 14, WArms.GRADES[r2].color, 540))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	box.add_child(acts)
	if m2 in have:
		acts.add_child(_primary("Take off" if m2 in on else "Fit", func(): _fit(g, m2), true, 15))
		# Rework with fittings: to a higher grade, or the same grade again for new traits
		for rr in [1, 2, 3]:
			if rr < r2:
				continue
			var fid: String = WArms.FITTINGS[rr]
			var n: int = w.stock_count(fid)
			if n <= 0 and rr != r2 + 1:
				continue
			var b := _secondary("%s %s  (%d)" % ["Rework" if rr == r2 else "Make", WArms.GRADES[rr].name, n], func(): _rework(g, m2, rr), bench and n > 0, 14)
			b.tooltip_text = "Uses one %s." % Items.iname(fid)
			acts.add_child(b)
	else:
		var c: Dictionary = _acost(WArms.PARTS[m2])
		acts.add_child(_primary("Make", func(): _arms_pay(WArms.PARTS[m2], func():
			if not a.parts.has(g):
				a.parts[g] = []
			a.parts[g].append(m2)
			_fit(g, m2, false)), bench and w.stock_has_all(c), 15))
		acts.add_child(_cost_line(c))


## How well this survivor knows a weapon: the rank, a bar to the next, and what it gives.
func _practice_line(id: String) -> Control:
	var lv: int = w.skills.use_level(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var nm := _label(WSkills.USE_RANKS[lv], 14, GOLD if lv > 0 else DIM)
	nm.custom_minimum_size.x = 80
	row.add_child(nm)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(110, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = 1.0
	bar.value = w.skills.use_progress(id)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = GOLD
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	row.add_child(bar)
	row.add_child(_label(WSkills.use_text(lv), 13, DIM))
	row.tooltip_text = "You get better with a weapon by using it."
	return row


## Reworks a part with fittings: a new grade and fresh traits.
func _rework(g: String, m: String, r: int) -> void:
	var fid: String = WArms.FITTINGS[r]
	if not w.stock_pay({fid: 1}):
		return
	w.arms.grade["%s/%s" % [g, m]] = WArms.roll_grade(r)
	w.sfx("carve", -4, null, 1.2)
	if r >= 3:
		w.sfx("bell", -10)
	w.rearm()
	_redraw()


## The gun as it is fitted, turning slowly in a small room of its own.
func _gun_preview(g: String, sz: Vector2) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	# Only a picture: it takes no clicks or wheel, so the lists and tabs around it always get them
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.stretch = true
	box.custom_minimum_size = sz
	var vp := SubViewport.new()
	vp.gui_disable_input = true
	vp.size = Vector2i(sz)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 26
	vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, 0.6, 0)
	key.light_energy = 2.2
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.2, -2.4, 0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.85, 0.8, 1.0)
	vp.add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.48, 0.45)
	e.ambient_light_energy = 1.4
	env.environment = e
	vp.add_child(env)
	var turn := Node3D.new()
	vp.add_child(turn)
	var model: Node3D = w.player.weapon._build(g, Game.mounts_of(g))
	turn.add_child(model)
	# Frame it: the gun lies along z, so look at it from the side
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).get_aabb()
		bb = (mi as MeshInstance3D).transform * bb
		var p: Node = mi.get_parent()
		while p != model and p is Node3D:
			bb = (p as Node3D).transform * bb
			p = p.get_parent()
		aabb = bb if first else aabb.merge(bb)
		first = false
	model.position = -aabb.get_center()
	var reach := maxf(aabb.size.z, aabb.size.y * 2.5)
	cam.position = Vector3(reach * 1.2, reach * 0.3, 0)
	cam.basis = Basis.looking_at(-cam.position, Vector3.UP)
	turn.rotation.y = -0.35
	var tw := turn.create_tween().set_loops()
	tw.tween_property(turn, "rotation:y", 0.35, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(turn, "rotation:y", -0.35, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return box


## A labelled bar for one measure of a thing.
func _stat(parent: Control, name: String, value: String, frac: float) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var l := _label(name, 14, DIM)
	l.custom_minimum_size.x = 104
	hb.add_child(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = frac
	bar.custom_minimum_size = Vector2(70, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(GOLD, 0.85)
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	hb.add_child(bar)
	var v := _label(value, 14, PALE)
	v.custom_minimum_size.x = 50
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(v)
	parent.add_child(hb)


## A cost as small pictures with have-and-need counts.
func _cost_line(cost: Dictionary) -> HBoxContainer:
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	for k in cost:
		var have: int = w.stock_count(k)
		var c := HBoxContainer.new()
		c.add_theme_constant_override("separation", 3)
		c.add_child(WGlyph.make(k, 20, false))
		c.add_child(_label("%d/%d" % [mini(have, 999), int(cost[k])], 14, OK_C if have >= int(cost[k]) else NO_C))
		c.tooltip_text = Items.iname(k)
		foot.add_child(c)
	return foot


## Puts a thing on from the pack; what was worn there goes back into the pack.
func _wear(id: String) -> void:
	var slot: String = WArms.WEAR[id].slot
	if w.inv.take(id, 1) < 1:
		return
	var old := str(w.arms.wear.get(slot, ""))
	w.arms.wear[slot] = id
	if old != "":
		w.give([[old, 1]])
	w.sfx("carve", -10)
	w.rearm()
	w._armour_hud()
	_redraw()


func _unwear(slot: String) -> void:
	var old := str(w.arms.wear.get(slot, ""))
	if old == "" or not w.inv.room_for(old, 1):
		return
	w.arms.wear.erase(slot)
	w.give([[old, 1]])
	w.rearm()
	w._armour_hud()
	_redraw()


# ------------------------------------------------------------------ wear: what you have on, slot by slot

var _wslot := "head"


## The clothing screen: you as you stand, a place for each thing worn, and what can go there:
## worn, in the pack, or made here at a workbench. A land's ward goes on like any other piece.
func _draw_wear() -> void:
	var a: Dictionary = w.arms
	var bench: bool = at_bench()
	var wn := WArms.worn(a)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(_pill("Workbench" if bench else "Making clothes needs a workbench", bench))
	if wn.guard > 0.0:
		top.add_child(_pill("Turns aside %d%% of harm" % int(round(wn.guard * 100.0)), true))
	for bn in wn.wards:
		top.add_child(_pill("Warded: %s" % str(WTerrain.BIOME_NAMES.get(bn, bn)).trim_prefix("The "), true))
	_body.add_child(top)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(split)
	# You, dressed as you are
	var me := VBoxContainer.new()
	me.add_theme_constant_override("separation", 6)
	me.custom_minimum_size.x = 280
	split.add_child(me)
	me.add_child(_figure_preview(Vector2(280, 340)))
	var lines: Array = []
	if wn.speed != 1.0:
		lines.append("Pace %+d%%" % int(round((wn.speed - 1.0) * 100.0)))
	if wn.hunger != 1.0:
		lines.append("Hunger %+d%%" % int(round((wn.hunger - 1.0) * 100.0)))
	if wn.weary != 1.0:
		lines.append("Tiring %+d%%" % int(round((wn.weary - 1.0) * 100.0)))
	if wn.gather != 1.0:
		lines.append("Gathering %+d%%" % int(round((wn.gather - 1.0) * 100.0)))
	if not lines.is_empty():
		me.add_child(_wrap("   ".join(lines), 15, DIM, 280))
	# A place for each thing worn
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 4)
	rail.custom_minimum_size.x = 230
	split.add_child(rail)
	for sl in WArms.WEAR_SLOTS:
		var on := str(a.wear.get(sl[0], ""))
		var t: String = "%s:  %s" % [sl[1], WArms.WEAR[on].name if on != "" else "nothing"]
		var b := _rail_btn(t, 0, sl[0] == _wslot, func(): _wslot = sl[0]; _redraw())
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", 16)
		for st in ["normal", "hover", "pressed"]:
			var sb := b.get_theme_stylebox(st) as StyleBoxFlat
			if sb:
				sb.content_margin_top = 3
				sb.content_margin_bottom = 3
		rail.add_child(b)
	# What can go there
	var grid := _card_grid(400.0)
	split.add_child(grid.get_parent())
	for id in WArms.WEAR:
		var it: Dictionary = WArms.WEAR[id]
		if it.slot != _wslot:
			continue
		if it.has("needs") and not w.flags.has(it.needs) and w.inv.count(id) <= 0 and str(a.wear.get(_wslot, "")) != id:
			continue   # taught by a lost book not yet found
		var sub := _wear_sub(it)
		var told := made_from(str(it.get("text", "")), _acost(it.cost))
		if str(a.wear.get(_wslot, "")) == id:
			grid.add_child(_card(id, it.name, "Worn" + sub, GOLD, {}, "Take off", func(): _unwear(it.slot), true, true, func(): pass, told))
		elif w.inv.count(id) > 0:
			grid.add_child(_card(id, it.name, "In your pack" + sub, PALE, {}, "Wear", func(): _wear(id), true, false, func(): pass, told))
		else:
			var c: Dictionary = _acost(it.cost)
			grid.add_child(_card(id, it.name, "Not made" + sub, Color(DIM, 0.8), c, "Make", func(): _arms_pay(it.cost, func(): w.give([[id, 1]])), bench and w.stock_has_all(c), false, func(): pass, str(it.get("text", ""))))


## What a thing is, and what it is made from (shown on worn and carried clothes, whose card has no cost).
static func made_from(text: String, cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		parts.append("%d %s" % [int(cost[k]), Items.iname(k)])
	if parts.is_empty():
		return text
	return (text + " " if text != "" else "") + "Made from " + ", ".join(parts) + "."


## A worn thing's gifts in a few words.
func _wear_sub(it: Dictionary) -> String:
	var bits: Array = []
	if float(it.get("guard", 0.0)) > 0.0:
		bits.append("guard %d%%" % int(round(float(it.guard) * 100.0)))
	if it.has("ward"):
		bits.append("ward")
	if float(it.get("warm", 0.0)) >= 1.0:
		bits.append("warm")
	for k in [["speed", "pace"], ["hunger", "hunger"], ["weary", "tiring"], ["gather", "gathering"]]:
		if it.has(k[0]):
			bits.append("%s %+d%%" % [k[1], int(round((float(it[k[0]]) - 1.0) * 100.0))])
	return ("  ·  " + ", ".join(bits)) if not bits.is_empty() else ""


## You as you stand now, turning slowly, in what you wear.
func _figure_preview(sz: Vector2) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	# Only a picture: it takes no clicks or wheel, so the lists and tabs around it always get them
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.stretch = true
	box.custom_minimum_size = sz
	var vp := SubViewport.new()
	vp.gui_disable_input = true
	vp.size = Vector2i(sz)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, 1.05, 4.1)
	vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.5, 0)
	key.light_energy = 2.0
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.2, -2.4, 0)
	fill.light_energy = 0.6
	vp.add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.48, 0.45)
	e.ambient_light_energy = 1.3
	env.environment = e
	vp.add_child(env)
	var fig := Figure.new().setup(Game.shown_look())
	fig.rotation.y = 0.5
	vp.add_child(fig)
	var tw := fig.create_tween().set_loops()
	tw.tween_property(fig, "rotation:y", 0.5 + TAU, 14.0).from(0.5)
	return box

## The trials' own words name fixed keys; in the waste the keys are whatever was set.
func _waste_text(t: String) -> String:
	return t.replace("with G", "with [%s]" % Game.key_text("grenade")).replace("with T", "with [%s]" % Game.key_text("gadget"))


## Fits a part, or takes it off. One part to each place on the gun.
func _fit(g: String, m: String, redraw := true) -> void:
	var a: Dictionary = w.arms
	var on: Array = a.mounts.get(g, []).duplicate()
	if m in on:
		on.erase(m)
	else:
		on = on.filter(func(x): return ArmsDB.ATTACHMENTS[x].slot != ArmsDB.ATTACHMENTS[m].slot)
		on.append(m)
	a.mounts[g] = on
	if redraw:
		w.rearm()
		_redraw()


func _slot_grid(bag: Inventory, cb: Callable, cols := 6, sel := -1, kinds: Array = [], tile_w := 150) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for i in bag.slots.size():
		var s = bag.slots[i]
		var b := Button.new()
		var square := tile_w <= 96
		b.custom_minimum_size = Vector2(tile_w, tile_w if square else 54)
		b.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.035)
		sb.border_color = Color(1, 1, 1, 0.07)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6 if square else 3)
		if s != null and square:
			# A square slot: the thing's picture large, its count in the corner
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.tooltip_text = "%s\n%s" % [Items.iname(s.id), Items.info(s.id).text]
			var gl := WGlyph.make(s.id, int(tile_w * 0.78), false)
			gl.position = Vector2(tile_w * 0.11, tile_w * 0.07)
			gl.size = Vector2(tile_w * 0.78, tile_w * 0.78)
			b.add_child(gl)
			if int(s.n) > 1:
				var cnt := _label(str(int(s.n)), 15, PALE)
				cnt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
				cnt.offset_left = -50
				cnt.offset_top = -24
				cnt.offset_right = -6
				cnt.offset_bottom = -3
				cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				cnt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
				cnt.add_theme_constant_override("outline_size", 4)
				cnt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
				b.add_child(cnt)
			# A thin line of the thing's colour along the foot
			sb.border_color = Color(Items.info(s.id).color, 0.35)
			if not kinds.is_empty() and not Items.info(s.id).kind in kinds:
				b.modulate.a = 0.22
		elif s != null:
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.tooltip_text = "%s\n%s" % [Items.iname(s.id), Items.info(s.id).text]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			row.offset_left = 8
			row.offset_right = -6
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ic := _icon(s.id, 34)
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(ic)
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", -2)
			col.alignment = BoxContainer.ALIGNMENT_CENTER
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var nm := _label(Items.iname(s.id), 15, PALE)
			nm.clip_text = true
			nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			col.add_child(nm)
			col.add_child(_label("× %d" % int(s.n), 14, DIM))
			row.add_child(col)
			b.add_child(row)
			if not kinds.is_empty() and not Items.info(s.id).kind in kinds:
				b.modulate.a = 0.22
		if i == sel and s != null:
			sb.bg_color = Color(GOLD, 0.14)
			sb.border_color = GOLD
		b.add_theme_stylebox_override("normal", sb)
		var hs := sb.duplicate()
		hs.bg_color = Color(1, 1, 1, 0.1) if i != sel else Color(GOLD, 0.2)
		b.add_theme_stylebox_override("hover", hs)
		b.add_theme_stylebox_override("pressed", hs)
		var idx := i
		# A right click acts at once; a left click acts when it lets go, so a press can become a drag
		b.gui_input.connect(func(ev):
			if not ev is InputEventMouseButton:
				return
			if ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				cb.call(idx, true)
			elif ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.pressed:
					b.set_meta("down", true)
				elif b.get_meta("down", false):
					b.set_meta("down", false)
					cb.call(idx, ev.shift_pressed))
		# Drag a thing onto the other side to move it there, or onto another place in the pack to swap
		b.set_drag_forwarding(func(_at):
			if bag.slots[idx] == null:
				return null
			b.set_meta("down", false)
			var pv := WGlyph.make(bag.slots[idx].id, 56, false)
			pv.size = Vector2(56, 56)
			b.set_drag_preview(pv)
			return {"slot_drag": true, "grid": g.get_instance_id(), "i": idx, "cb": cb},
			func(_at, d): return d is Dictionary and d.has("slot_drag"),
			func(_at, d): _slot_dropped(d, g, bag, idx))
		g.add_child(b)
	return g


func _slot_dropped(d: Dictionary, g: GridContainer, bag: Inventory, to: int) -> void:
	if int(d.grid) == g.get_instance_id():
		# Within one grid: the pack's places swap
		if bag == w.inv and int(d.i) != to:
			var a = w.inv.slots[int(d.i)]
			w.inv.slots[int(d.i)] = w.inv.slots[to]
			w.inv.slots[to] = a
			w.inv.changed.emit()
		return
	(d.cb as Callable).call(int(d.i), false)


func _pack_click(i: int, right: bool) -> void:
	var s = w.inv.slots[i]
	if s == null:
		_sel = -1
		_redraw()
		return
	if right:
		# The quick use: eat it, use it, or put it on. Nothing is dropped by accident.
		var kind: String = Items.info(s.id).kind
		if kind in ["food", "medicine", "boat", "book", "brew", "spirit"]:
			_use_item(i)
			return
		if kind == "wear":
			_wear(s.id)
			_sel = -1
			_redraw()
			return
	_sel = i
	_redraw()


var _rsel := -1
var _rhere := false   ## the chosen recipe can be made where you stand


const MAKE_GROUPS := [["all", "All"], ["heal", "Healing"], ["food", "Food"], ["ammo", "Ammunition"], ["tool", "Tools"], ["material", "Materials"]]
var _rcat := "all"


func _make_group(r: Dictionary) -> String:
	match str(Items.info(r.id).kind):
		"medicine", "aid":
			return "heal"
		"food", "seed":
			return "food"
		"ammo":
			return "ammo"
		"tool", "boat":
			return "tool"
	return "material"


## At a cooking station (and no workbench near), only the station's own list: what is cooked.
static func station_shows(r: Dictionary, bench: bool, at_pot: bool) -> bool:
	return bench or not at_pot or r.get("fire", false)


func _draw_craft() -> void:
	var bench: bool = at_bench()
	var pot: int = w.builder.near_pid(w.player.global_position, "cookpot", 5.0)
	var fire: bool = (pot >= 0 and w.burning(pot)) or w.settlement_at(w.player.global_position) != ""
	var chests: int = w.base_chests().size()
	# Where you stand, at a glance
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(_pill("Workbench", bench))
	top.add_child(_pill("Cooking station", fire))
	if chests > 0:
		top.add_child(_pill("%d chest%s in reach" % [chests, "" if chests == 1 else "s"], true))
	if w.trades.trade == "":
		top.add_child(_chip("No trade yet: choose one", true, func(): open_trade()))
	_body.add_child(top)
	if pot >= 0:
		_body.add_child(_fuel_row(pot))
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(split)
	# The groups, down the left
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 4 if pot < 0 else 0)
	rail.custom_minimum_size.x = 170
	split.add_child(rail)
	var shown: Array = []
	var ready_in := {}
	for i in Items.RECIPES.size():
		var r: Dictionary = Items.RECIPES[i]
		if r.has("needs") and not w.flags.has(r.needs):
			continue
		if not station_shows(r, bench, pot >= 0):
			continue
		var here: bool = (not r.bench or bench) and (not r.get("fire", false) or fire) and w.trades.can_make(r)
		var ok: bool = here and w.stock_has_all(w.skills.cost(r.cost))
		var grp := _make_group(r)
		if ok:
			ready_in[grp] = int(ready_in.get(grp, 0)) + 1
			ready_in["all"] = int(ready_in.get("all", 0)) + 1
		if _rcat == "all" or grp == _rcat:
			shown.append([i, here, ok])
	for g in MAKE_GROUPS:
		rail.add_child(_rail_btn(g[1], int(ready_in.get(g[0], 0)), g[0] == _rcat, func(): _rcat = g[0]; _rsel = -1; _redraw()))
	# Ready to make first, then what is here but short, then what needs another place
	shown.sort_custom(func(a, b): return (2 if a[2] else (1 if a[1] else 0)) > (2 if b[2] else (1 if b[1] else 0)))
	var sc := ScrollContainer.new()
	# The fuel row of a cooking station takes its height from the list, so the frame keeps its size
	sc.custom_minimum_size = Vector2(560, 470 if pot < 0 else 412)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	var chosen = null
	for row in shown:
		if _rsel == -1:
			_rsel = row[0]
		if row[0] == _rsel:
			chosen = row
		grid.add_child(_recipe_card(row[0], row[1], row[2]))
	var side := _side_panel(split)
	side.custom_minimum_size.x = 250
	_rhere = false
	if chosen == null:
		side.add_child(_wrap("Nothing here to make." if shown.is_empty() else "Choose something to make.", 18, DIM, 220))
		return
	_rhere = chosen[1]
	var rr: Dictionary = Items.RECIPES[chosen[0]]
	var cost2: Dictionary = w.skills.cost(rr.cost)
	var n: int = int(rr.n) + w.skills.make_bonus(rr.id) + w.trades.bonus(rr)
	side.add_child(_icon(rr.id, 72))
	side.add_child(_label(Items.iname(rr.id) + ("" if n == 1 else "  × %d" % n), 23, PALE))
	side.add_child(_label("You have %d" % w.stock_count(rr.id), 15, DIM))
	side.add_child(_wrap(Items.info(rr.id).text, 16, Color(PALE, 0.85), 220))
	side.add_child(_gap(4))
	for k in cost2:
		var have: int = w.stock_count(k)
		var need := int(cost2[k])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		line.add_child(_icon(k, 26))
		var nm := _label(Items.iname(k), 16, PALE)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(nm)
		line.add_child(_label("%d / %d" % [mini(have, 9999), need], 16, OK_C if have >= need else NO_C))
		side.add_child(line)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(fill)
	if not w.trades.can_make(rr):
		side.add_child(_wrap("Only a %s can make this. Ask a friend who keeps that trade." % w.trades.tname(rr.trade).to_lower(), 17, NO_C, 220))
		return
	if not chosen[1]:
		side.add_child(_wrap("Made at a %s." % ("workbench" if rr.bench else "cooking station"), 17, NO_C, 220))
		return
	var most := 99
	for k in cost2:
		most = mini(most, w.stock_count(k) / maxi(1, int(cost2[k])))
	var b1 := _primary("Make   [Enter]", func(): _make(rr), most >= 1)
	side.add_child(b1)
	var more := HBoxContainer.new()
	more.add_theme_constant_override("separation", 8)
	var b5 := _secondary("Make 5", func(): _make(rr, 5), most >= 5)
	var ba := _secondary("Make all (%d)" % most if most >= 2 else "Make all", func(): _make(rr, most), most >= 2)
	for b in [b5, ba]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		more.add_child(b)
	side.add_child(more)


const OK_C := Color(0.6, 0.85, 0.55)
const NO_C := Color(0.9, 0.48, 0.4)


## One thing that can be made: its picture, its name, what it takes, and a button to make it.
func _recipe_card(i: int, here: bool, ok: bool) -> PanelContainer:
	var r: Dictionary = Items.RECIPES[i]
	var on := i == _rsel
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(272, 0)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GOLD, 0.1) if on else Color(1, 1, 1, 0.045)
	sb.border_color = Color(GOLD, 0.85) if on else Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)
	card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_rsel = i
			_redraw())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := WGlyph.make(r.id, 46)
	g.dim = not here
	head.add_child(g)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n: int = int(r.n) + w.skills.make_bonus(r.id) + w.trades.bonus(r)
	hv.add_child(_label(Items.iname(r.id) + ("" if n == 1 else "  × %d" % n), 17, PALE if here else DIM))
	var where := "Workbench" if r.bench else ("Cooking station" if r.get("fire", false) else "By hand")
	if r.has("trade"):
		where = "%s's work · %s" % [w.trades.tname(r.trade), where]
	hv.add_child(_label(where, 13, Color(DIM, 0.85) if here else NO_C))
	head.add_child(hv)
	v.add_child(head)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost: Dictionary = w.skills.cost(r.cost)
	for k in cost:
		var have: int = w.stock_count(k)
		var c := HBoxContainer.new()
		c.add_theme_constant_override("separation", 3)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(WGlyph.make(k, 20, false))
		c.add_child(_label(str(cost[k]), 15, OK_C if have >= int(cost[k]) else NO_C))
		c.tooltip_text = Items.iname(k)
		foot.add_child(c)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(fill)
	if here:
		var mb := _primary("Make", func(): _rsel = i; _make(r), ok, 15)
		mb.custom_minimum_size = Vector2(72, 0)
		foot.add_child(mb)
	v.add_child(foot)
	return card


## A small rounded mark of a place: lit when you are at it.
func _pill(t: String, on: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(OK_C, 0.12) if on else Color(1, 1, 1, 0.04)
	sb.border_color = Color(OK_C, 0.5) if on else Color(1, 1, 1, 0.1)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_label(("●  " if on else "○  ") + t, 15, OK_C if on else DIM))
	return p


## A group in a left-hand rail, with how many are ready in it.
func _rail_btn(t: String, n: int, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", GOLD if on else PALE)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(GOLD, 0.12) if on else Color(1, 1, 1, 0.06 if st == "hover" else 0.0)
		sb.border_color = GOLD if on else Color(0, 0, 0, 0)
		sb.border_width_left = 3
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 12
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		b.add_theme_stylebox_override(st, sb)
	if n > 0:
		var k := _label(str(n), 14, OK_C)
		k.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		k.offset_left = -40
		k.offset_right = -10
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(k)
	b.pressed.connect(cb)
	return b


## The main thing to do: a filled gold button. Greyed when it cannot be done.
func _primary(t: String, cb: Callable, enabled := true, size := 18) -> Button:
	var b := Button.new()
	b.text = t
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.04, 0.02))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.04, 0.02))
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.5))
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": GOLD, "hover": GOLD.lightened(0.15), "pressed": GOLD.darkened(0.15), "disabled": Color(1, 1, 1, 0.06)}[st]
		sb.set_corner_radius_all(5)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	return b


## A lesser thing to do: outlined.
func _secondary(t: String, cb: Callable, enabled := true, size := 16) -> Button:
	var b := Button.new()
	b.text = t
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PALE)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.4))
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.1 if st == "hover" else 0.03)
		sb.border_color = Color(GOLD, 0.6) if st != "disabled" else Color(1, 1, 1, 0.08)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(5)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	return b


func _make(r: Dictionary, times := 1) -> void:
	if not w.trades.can_make(r):
		return
	var made := 0
	for t in times:
		if not w.stock_pay(w.skills.cost(r.cost)):
			break
		made += 1
	if made == 0:
		w.sfx("deny", -8)
		return
	w.sfx("carve", -6)
	w.give([[r.id, (int(r.n) + w.skills.make_bonus(r.id) + w.trades.bonus(r)) * made]])
	for t in made:
		w.award("make")
	_redraw()


# ------------------------------------------------------------------ chests, crates and satchels

func open_container(id: String) -> void:
	_cont_id = id
	_open("container")


func container_changed(id: String) -> void:
	if _panel_name == "container" and id == _cont_id:
		if not w.containers.has(id):
			close_all()
		elif get_viewport().gui_get_focus_owner() is LineEdit:
			_redraw_after_typing = true   # do not pull the name field away mid-word
		else:
			_redraw()


var _redraw_after_typing := false


func _draw_container() -> void:
	_clear()
	if not w.containers.has(_cont_id):
		_body.add_child(_label("...", 20, DIM))
		return
	var name := "Chest" if _cont_id.begins_with("p") else ("Satchel" if _cont_id.begins_with("s") else "Searched")
	var cpid := int(_cont_id.substr(1)) if _cont_id.begins_with("p") else -1
	if cpid >= 0 and str(w.pieces.get(cpid, {}).get("name", "")) != "":
		name = str(w.pieces[cpid].name)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.add_child(_title(name))
	if cpid >= 0 and w.pieces.has(cpid) and WBuilder.acts(w.pieces[cpid].kind) == "chest":
		# A chest may be named, and the name shows above it
		var field := LineEdit.new()
		field.text = str(w.pieces[cpid].get("name", ""))
		field.placeholder_text = "Name this chest"
		field.max_length = 24
		field.custom_minimum_size = Vector2(260, 0)
		field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		field.add_theme_font_size_override("font_size", 17)
		top.add_child(field)
		var save := func(): w.shared("_rq_portal_name", [cpid, field.text])
		field.text_submitted.connect(func(_t): save.call())
		field.focus_exited.connect(func():
			save.call()
			if _redraw_after_typing:
				_redraw_after_typing = false
				_redraw.call_deferred())
	_body.add_child(top)
	_close_and_rule(top)
	# How much one click moves: the whole stack, half of it, ten or one. A right click always moves half.
	var how := HBoxContainer.new()
	how.add_theme_constant_override("separation", 6)
	how.add_child(_label("Click a thing to move it across. Move:", 16, DIM))
	for m in MOVE_CHOICES:
		var mm: int = m[0]
		how.add_child(_chip(m[1], _move_n == mm, func(): _move_n = mm; _redraw()))
	how.add_child(_label("(right click: half)", 15, DIM))
	_body.add_child(how)
	var bag := Inventory.new(w.containers[_cont_id].size())
	bag.from_data(w.containers[_cont_id])
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 28)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.add_child(_label("In the " + name.to_lower() if cpid < 0 else name, 20, GOLD))
	left.add_child(_slot_grid(bag, func(i, r): _take(bag, i, r), 4, -1, [], 80))
	left.add_child(_action("Take everything", func(): _take_all(), "[%s]" % Game.key_text("reload")))
	hb.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.add_child(_label("Your pack", 20, GOLD))
	right.add_child(_slot_grid(w.inv, func(i, r): _put(i, r), 6, -1, [], 80))
	if cpid >= 0:
		right.add_child(_action("Store what's already here", func(): _store_matching(), "Adds to stacks in the chest"))
	hb.add_child(right)
	_body.add_child(hb)


const MOVE_CHOICES := [[0, "All"], [-2, "Half"], [10, "10"], [1, "1"]]
var _move_n := 0   ## 0: the whole stack; -2: half; else that many


## How many of a stack of `total` one click moves.
func move_count(total: int, right: bool) -> int:
	var m := -2 if right else _move_n
	if m == 0:
		return total
	if m == -2:
		return maxi(1, int(ceil(total / 2.0)))
	return clampi(m, 1, total)


func _take(bag: Inventory, i: int, right: bool) -> void:
	var s = bag.slots[i]
	if s == null:
		return
	var n := move_count(int(s.n), right)
	w.shared("_rq_take", [Net.me(), _cont_id, i, 0 if n >= int(s.n) else n])


func _put(i: int, right := false) -> void:
	var s = w.inv.slots[i]
	if s == null:
		return
	var n := move_count(int(s.n), right)
	if n >= int(s.n):
		w.inv.take_slot(i)
	else:
		s.n = int(s.n) - n
		w.inv.changed.emit()
	w.shared("_rq_put", [Net.me(), _cont_id, s.id, n])
	w.char_save_soon()


func _take_all() -> void:
	w.take_all(_cont_id)


## Puts away every stack of a kind the chest already holds: the usual end of a day's gathering.
func _store_matching() -> void:
	var here := {}
	for it in w.containers.get(_cont_id, []):
		if it != null:
			here[str(it[0])] = true
	var moved := 0
	for i in w.inv.slots.size():
		var s = w.inv.slots[i]
		if s != null and here.has(s.id):
			_put(i)
			moved += 1
	if moved == 0:
		w.hud.notify("Nothing you carry is kept here yet.")


# ------------------------------------------------------------------ talk and trade

var _babble: WBabble


func open_dialogue(pid: String) -> void:
	_talking = pid
	_panel_name = "talk"
	_open("talk")
	var pd: Dictionary = WPlaces.PEOPLE[pid]
	_talk(pd.greet)


func _talk(text: String) -> void:
	_clear()
	var pd: Dictionary = WPlaces.PEOPLE[_talking]
	_speaker_head(pd)
	var line := WPlaces.words(text)
	var quote := PanelContainer.new()
	var qs := StyleBoxFlat.new()
	qs.bg_color = Color(1, 1, 1, 0.035)
	qs.border_color = Color(GOLD, 0.45)
	qs.border_width_left = 3
	qs.set_content_margin_all(18)
	quote.add_theme_stylebox_override("panel", qs)
	var say := _wrap(line, 21, PALE, 1000)
	# The words come up as they are spoken, in the speaker's own murmur
	var secs := clampf(line.length() / 55.0, 0.4, 5.0)
	say.visible_ratio = 0.0
	say.create_tween().tween_property(say, "visible_ratio", 1.0, secs)
	if _babble == null:
		_babble = WBabble.new()
		add_child(_babble)
	_babble.speak(_talking, line, secs)
	w.speaker_says(_talking, minf(secs, 2.8))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 220)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(say)
	quote.add_child(sc)
	_body.add_child(quote)
	_body.add_child(_gap(4))
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 5)
	var n := 1
	for o in w.quests.talk_options(_talking):
		var cb: Callable = o[1]
		opts.add_child(_action(o[0], func(): _talk(cb.call()), str(n), GOLD))
		n += 1
	var offers: int = w.quests.offers_from(_talking).size()
	opts.add_child(_action("Have you any work for me?" + ("  (%d)" % offers if offers > 0 else ""), func(): _offers(), str(n)))
	n += 1
	opts.add_child(_action("Tell me about yourself.", func(): _talk(pd.about), str(n)))
	n += 1
	opts.add_child(_action("What news on the road?", func(): _rumor(), str(n)))
	n += 1
	if Items.STOCK.has(pd.role):
		opts.add_child(_action("Let us trade.", func(): _tsel = ""; _trade(), str(n)))
		n += 1
	opts.add_child(_action("Farewell.", close_all, "Esc", DIM))
	_body.add_child(opts)
	_talk_keys = opts


var _talk_keys: VBoxContainer


## The speaker's name, what they are, and where you stand with their people.
func _speaker_head(pd: Dictionary) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", -2)
	nv.add_child(_title(pd.name))
	nv.add_child(_label(pd.title, 17, DIM))
	top.add_child(nv)
	var st := int(w.rep.get(pd.at, 0))
	if st > 0:
		var c := _label("Standing in %s: %d" % [WPlaces.SETTLEMENTS[pd.at].name, st], 16, GOLD)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top.add_child(c)
	_body.add_child(top)
	_close_and_rule(top)


func _rumor() -> void:
	var pd: Dictionary = WPlaces.PEOPLE[_talking]
	var lines: Array = pd.rumors
	var text: String = lines[randi() % lines.size()]
	# Each telling marks some place on the map not yet seen
	var home: Vector2 = WPlaces.spos(pd.at)
	var best = null
	var bd := INF
	for r in w.ruins:
		var d := home.distance_to(Vector2(r.pos.x, r.pos.z))
		if not w.is_revealed(r.pos) and d < bd:
			bd = d
			best = r
	if best != null:
		w.reveal_place(Vector2(best.pos.x, best.pos.z), 45.0)
		w.known_ruins[best.id] = true
		text += "\n\n(%s is marked on your map.)" % best.name
	_talk(text)


func _offers() -> void:
	_clear()
	var pd: Dictionary = WPlaces.PEOPLE[_talking]
	_speaker_head(pd)
	var list: Array = w.quests.offers_from(_talking)
	var v := _scroll(450)
	v.add_theme_constant_override("separation", 10)
	if list.is_empty():
		v.add_child(_wrap("\"Nothing today. Come back after the dawn; there is always something after the dawn.\"", 21, PALE, 1000))
	for o in list:
		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(1, 1, 1, 0.04)
		cs.border_color = Color(1, 1, 1, 0.08)
		cs.set_border_width_all(1)
		cs.set_corner_radius_all(4)
		cs.set_content_margin_all(16)
		card.add_theme_stylebox_override("panel", cs)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)
		cv.add_child(_label(o.title, 23, GOLD))
		cv.add_child(_wrap("\"%s\"" % WPlaces.words(o.pitch), 19, PALE, 980))
		var r: Dictionary = o.reward
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_label("Reward:", 17, DIM))
		row.add_child(_icon("salt", 22))
		row.add_child(_label("%d salt" % int(r.salt), 17, PALE))
		for it in r.get("items", []):
			row.add_child(_icon(it[0], 22))
			row.add_child(_label("%d %s" % [int(it[1]), Items.iname(it[0])], 17, PALE))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		var take := _action("I will do it.", func(): w.quests.accept(o); _talk("\"Go carefully. Come back.\""), "", GOLD)
		take.custom_minimum_size.x = 220
		row.add_child(take)
		cv.add_child(row)
		v.add_child(card)
	_body.add_child(_action("Back", func(): _talk(pd.greet), "", DIM))


func _discount(at: String) -> float:
	return minf(0.3, int(w.rep.get(at, 0)) / 3 * 0.1)


func buy_price(id: String, at: String) -> int:
	return maxi(1, ceili(Items.info(id).value * 2.0 * (1.0 - _discount(at)) * w.skills.buy_mult()))


func sell_price(id: String) -> int:
	var info: Dictionary = Items.info(id)
	if info.kind == "quest" or id == "salt":
		return 0
	return maxi(1, int(info.value * (1.0 if info.kind == "trinket" else 0.6) * w.skills.sell_mult()))


var _tsel := ""      ## the chosen thing in trade
var _tside := ""     ## "buy" or "sell"


func _trade() -> void:
	_clear()
	var pd: Dictionary = WPlaces.PEOPLE[_talking]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.add_child(_title("Trade with %s" % pd.name))
	var salt := _label("Salt  %d" % w.inv.count("salt"), 22, GOLD)
	salt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	salt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(salt)
	_body.add_child(top)
	_close_and_rule(top)
	var disc := int(round(_discount(pd.at) * 100.0))
	_body.add_child(_label(("Your standing in %s takes %d%% off." % [WPlaces.SETTLEMENTS[pd.at].name, disc]) if disc > 0 else "Better standing with %s brings better prices." % WPlaces.SETTLEMENTS[pd.at].name, 16, DIM))
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(split)
	# What they sell
	var buy_ids: Array = []
	for id in Items.STOCK[pd.role]:
		if id == "beacon_oil" and not w.flags.has("oilcraft"):
			continue
		buy_ids.append(id)
	var lb := _list_col(split, "%s sells" % pd.name.split(" ")[0])
	for id in buy_ids:
		var n := _lot(id)
		var cost := buy_price(id, pd.at) * n
		lb.add_child(_trade_row(id, "buy", "%d" % cost, w.inv.count("salt") >= cost, n))
	# What you can sell
	var ls := _list_col(split, "You can sell")
	var seen := {}
	for s in w.inv.slots:
		if s == null or seen.has(s.id) or sell_price(s.id) <= 0:
			continue
		seen[s.id] = true
		ls.add_child(_trade_row(s.id, "sell", "%d" % sell_price(s.id), true, w.inv.count(s.id)))
	if seen.is_empty():
		ls.add_child(_label("Nothing they would take.", 16, DIM))
	var side := _side_panel(split)
	side.custom_minimum_size.x = 330
	if _tsel == "" or (_tside == "sell" and w.inv.count(_tsel) <= 0) or (_tside == "buy" and not _tsel in buy_ids):
		_tsel = ""
		side.add_child(_label("Choose something", 22, DIM))
		side.add_child(_wrap("Click a thing on either side to buy or sell it.", 17, DIM, 300))
		var junk := _junk_value()
		if junk > 0:
			side.add_child(_gap(10))
			side.add_child(_action("Sell all trinkets  (+%d salt)" % junk, func(): _sell_junk(), "", GOLD))
	else:
		var info: Dictionary = Items.info(_tsel)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		head.add_child(_icon(_tsel, 44))
		var hv := VBoxContainer.new()
		hv.add_theme_constant_override("separation", 0)
		hv.add_child(_label(info.name, 24, PALE))
		hv.add_child(_label("You have %d" % w.inv.count(_tsel), 15, DIM))
		head.add_child(hv)
		side.add_child(head)
		side.add_child(_wrap(info.text, 17, PALE, 300))
		side.add_child(_gap(6))
		var id: String = _tsel
		if _tside == "buy":
			var lot := _lot(id)
			var price := buy_price(id, pd.at) * lot
			var can: int = w.inv.count("salt") / maxi(1, price)
			side.add_child(_label("%d salt for %d" % [price, lot], 18, GOLD))
			for k in [1, 5]:
				if k == 1 or can >= k:
					var b := _action("Buy %d" % (k * lot) if lot > 1 or k > 1 else "Buy", func(): _buy(id, lot * k, price * k))
					b.disabled = can < k
					side.add_child(b)
			if can > 5:
				side.add_child(_action("Buy %d  (%d salt)" % [can * lot, can * price], func(): _buy(id, lot * can, price * can)))
		else:
			var each := sell_price(id)
			var have: int = w.inv.count(id)
			side.add_child(_label("%d salt each" % each, 18, GOLD))
			side.add_child(_action("Sell one", func(): _sell(id, 1)))
			if have > 1:
				side.add_child(_action("Sell all %d  (+%d salt)" % [have, have * each], func(): _sell(id, have)))
	_body.add_child(_btn("Back", func(): _talk(pd.greet), 20))


## Rounds come by the ten.
func _lot(id: String) -> int:
	return 10 if id in ["shells", "rounds", "rifle"] else 1


func _list_col(parent: Control, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(_label(title, 19, GOLD))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(326, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	col.add_child(sc)
	parent.add_child(col)
	return v


func _trade_row(id: String, side: String, price: String, ok: bool, n: int) -> Button:
	var on := _tsel == id and _tside == side
	var b := Button.new()
	b.custom_minimum_size = Vector2(312, 42)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GOLD, 0.14) if on else Color(1, 1, 1, 0.03)
	sb.border_color = Color(GOLD, 0.8) if on else Color(1, 1, 1, 0.0)
	sb.border_width_left = 3
	b.add_theme_stylebox_override("normal", sb)
	var hs := sb.duplicate()
	hs.bg_color = Color(1, 1, 1, 0.09) if not on else Color(GOLD, 0.2)
	b.add_theme_stylebox_override("hover", hs)
	b.add_theme_stylebox_override("pressed", hs)
	b.add_theme_stylebox_override("focus", hs)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := _icon(id, 26)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var nm := _label(Items.iname(id) + ("  × %d" % n if n > 1 else ""), 17, PALE if ok else DIM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	row.add_child(nm)
	row.add_child(_label(price + " salt", 16, GOLD if ok else Color(DIM, 0.6)))
	b.add_child(row)
	b.pressed.connect(func(): _tsel = id; _tside = side; _trade())
	return b


func _junk_value() -> int:
	var v := 0
	for s in w.inv.slots:
		if s != null and Items.info(s.id).kind == "trinket":
			v += sell_price(s.id) * int(s.n)
	return v


func _sell_junk() -> void:
	var got := 0
	for s in w.inv.slots.duplicate():
		if s != null and Items.info(s.id).kind == "trinket":
			var n: int = w.inv.take(s.id, int(s.n))
			got += sell_price(s.id) * n
	if got > 0:
		w.give([["salt", got]])
		w.sfx("shell", -6)
	_trade()


func _buy(id: String, n: int, cost: int) -> void:
	if w.inv.count("salt") < cost:
		w.sfx("deny", -8)
		return
	if not w.inv.room_for(id, n):
		w.hud.notify("Your pack is full.")
		w.sfx("deny", -8)
		return
	w.inv.take("salt", cost)
	w.give([[id, n]])
	w.sfx("shell", -8)
	_trade()


func _sell(id: String, n := 1) -> void:
	var got: int = w.inv.take(id, n)
	if got < 1:
		return
	w.give([["salt", sell_price(id) * got]])
	w.sfx("shell", -8)
	_trade()


# ------------------------------------------------------------------ the journal

func open_journal() -> void:
	_open("journal")


var _jsel := ""


## What now: three goals side by side across the top of the journal.
func _what_now_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var me: Vector3 = w.player.global_position
	for g in w.what_now():
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.custom_minimum_size = Vector2(0, 120)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.28)
		sb.border_color = GOLD if g.kind == "road" else Color(0.5, 0.48, 0.42)
		sb.set_border_width_all(1)
		sb.set_content_margin_all(10)
		box.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		box.add_child(v)
		v.add_child(_label({"road": "NEXT", "near": "NEARBY", "grow": "GROW"}.get(g.kind, ""), 13, GOLD))
		v.add_child(_label(str(g.title), 18, PALE))
		v.add_child(_wrap(str(g.text), 15, DIM, 330))
		if g.at is Vector3:
			var t: Vector3 = g.at
			v.add_child(_label("%d m %s" % [int(Vector2(t.x - me.x, t.z - me.z).length()), WPlaces.dir_word(Vector2(me.x, me.z), Vector2(t.x, t.z))], 15, GOLD))
		row.add_child(box)
	return row


func _draw_journal() -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.add_child(_title("Journal"))
	var st := _label("Day %d    %d of 9 beacons burn    %d nights lived through" % [w.day, w.lit.size(), w.nights], 17, DIM)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(st)
	_body.add_child(top)
	_close_and_rule(top)
	_body.add_child(_what_now_row())
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 22)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(split)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, 400)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	sc.add_child(list)
	split.add_child(sc)
	var side := _side_panel(split)
	var qs: Array = w.quests.active()
	if qs.is_empty():
		list.add_child(_wrap("No tasks taken up. Ask in the settlements; there is always work.", 19, DIM, 540))
		side.add_child(_label("No tasks", 22, DIM))
		return
	if _jsel == "" or not w.quests.quests.has(_jsel) or w.quests.quests[_jsel].state != "active":
		_jsel = w.quests.tracked if w.quests.quests.has(w.quests.tracked) else qs[0].id
	for q in qs:
		list.add_child(_quest_row(q))
	var q: Dictionary = w.quests.quests[_jsel]
	var tracked: bool = w.quests.tracked == q.id
	side.add_child(_label(q.title, 25, PALE))
	if q.get("main", false):
		side.add_child(_label("The beacon road", 15, GOLD))
	side.add_child(_gap(4))
	side.add_child(_wrap(w.quests.step_text(q), 18, PALE, 380))
	var hint: String = w.quests.next_hint(q)
	if hint != "":
		side.add_child(_wrap(hint, 15, GOLD, 380))
	var t = w.quests.target_of(q)
	if t is Vector3:
		var me: Vector3 = w.player.global_position
		var d := Vector2(t.x - me.x, t.z - me.z).length()
		side.add_child(_label("%d m %s" % [int(d), WPlaces.dir_word(Vector2(me.x, me.z), Vector2(t.x, t.z))], 16, DIM))
	var r: Dictionary = q.get("reward", {})
	if int(r.get("salt", 0)) > 0:
		side.add_child(_gap(6))
		side.add_child(_label("Reward", 16, GOLD))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_icon("salt", 22))
		row.add_child(_label("%d salt" % int(r.salt), 17, PALE))
		for it in r.get("items", []):
			row.add_child(_icon(it[0], 22))
			row.add_child(_label("%d %s" % [int(it[1]), Items.iname(it[0])], 17, PALE))
		side.add_child(row)
	side.add_child(_gap(10))
	if not tracked:
		side.add_child(_action("Follow on the compass", func(): w.quests.tracked = q.id; w.quests.refresh_hud(); _draw_journal(), "", GOLD))
	else:
		side.add_child(_label("◆ Followed on the compass", 17, GOLD))
	if t is Vector3:
		var tv: Vector3 = t
		side.add_child(_action("Show on the map", func(): open_map(); _map_zoom = maxf(_map_zoom, 2.5); _map_center_on(tv)))


func _quest_row(q: Dictionary) -> Button:
	var on: bool = q.id == _jsel
	var tracked: bool = w.quests.tracked == q.id
	var b := Button.new()
	b.custom_minimum_size = Vector2(540, 58)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GOLD, 0.14) if on else Color(1, 1, 1, 0.03)
	sb.border_color = Color(GOLD, 0.85) if tracked else (Color(GOLD, 0.4) if on else Color(1, 1, 1, 0.0))
	sb.border_width_left = 3
	b.add_theme_stylebox_override("normal", sb)
	var hs := sb.duplicate()
	hs.bg_color = Color(1, 1, 1, 0.09) if not on else Color(GOLD, 0.2)
	b.add_theme_stylebox_override("hover", hs)
	b.add_theme_stylebox_override("pressed", hs)
	b.add_theme_stylebox_override("focus", hs)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_label(("◆  " if tracked else "") + q.title, 19, GOLD if tracked else PALE))
	var sub := _label(w.quests.step_text(q), 14, DIM)
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sub)
	b.add_child(v)
	b.pressed.connect(func(): _jsel = q.id; _draw_journal())
	return b


# ------------------------------------------------------------------ the map

func open_map() -> void:
	_open("map")


var _map_zoom := 1.0
var _map_off := Vector2.ZERO   ## where the map's top left sits inside its window
var _map_canvas: Control
var _map_fog: Control
var _map_drag := false
const MAP_VIEW := 640.0


func _draw_map() -> void:
	_clear()
	if _map_tex == null:
		_map_task = 1024   # whatever is left is drawn at once below; the rows above stop
		_map_tex = ImageTexture.create_from_image(_map_img if _map_img else w.terrain.map_image(1024))
		_map_img = null
		_fog_img = Image.create(Wasteland.REVEAL_N, Wasteland.REVEAL_N, false, Image.FORMAT_RGBA8)
		_fog_tex = ImageTexture.create_from_image(_fog_img)
		map_dirty = true
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(MAP_VIEW, MAP_VIEW)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.gui_input.connect(_map_input)
	_map_canvas = Control.new()
	_map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_map_canvas)
	var tr := TextureRect.new()
	tr.texture = _map_tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_canvas.add_child(tr)
	var fog := TextureRect.new()
	fog.texture = _fog_tex
	fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog.stretch_mode = TextureRect.STRETCH_SCALE
	fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_canvas.add_child(fog)
	_map_fog = fog
	_map_draw = MapDraw.new()
	_map_draw.w = w
	_map_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_canvas.add_child(_map_draw)
	hb.add_child(holder)
	_map_center_on(w.player.global_position)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.add_child(_title("The Ashen Waste"))
	side.add_child(_label("Seed %d.  Day %d.  %d of 9 beacons burn." % [w.world_seed, w.day, w.lit.size()], 17, DIM))
	side.add_child(_gap(4))
	for k in [["◆", "your task"], ["●", "settlement"], ["▲", "beacon, bright when burning"], ["■", "ruin"], ["✶", "lair of a great one"],
			["+", "your bed"], ["✕", "what you left when you fell"], ["⚑", "a marked spot"]]:
		side.add_child(_label("%s   %s" % k, 16, DIM))
	side.add_child(_gap(6))
	side.add_child(_wrap("Scroll to zoom, drag to move. Right click marks a spot for everyone, on the map and the compass. Right click a mark to take it away.", 16, PALE, 330))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_chip("Find me", false, func(): _map_center_on(w.player.global_position)))
	row.add_child(_chip("Whole map", false, func(): _map_zoom = 1.0; _map_center_on(Vector3.ZERO)))
	if not w.map_marks.is_empty():
		row.add_child(_chip("Clear marks", false, func(): w.clear_marks(); _redraw.call_deferred()))
	side.add_child(row)
	if not w.quests.tracked.is_empty() and w.quests.quests.has(w.quests.tracked):
		var q: Dictionary = w.quests.quests[w.quests.tracked]
		side.add_child(_gap(8))
		side.add_child(_label(q.title, 22, GOLD))
		side.add_child(_wrap(w.quests.step_text(q), 18, PALE, 330))
	hb.add_child(side)
	_body.add_child(hb)
	_update_fog()


func _map_layout() -> void:
	if not is_instance_valid(_map_canvas):
		return
	var full := MAP_VIEW * _map_zoom
	_map_off.x = clampf(_map_off.x, MAP_VIEW - full, 0.0)
	_map_off.y = clampf(_map_off.y, MAP_VIEW - full, 0.0)
	_map_canvas.position = _map_off
	_map_canvas.size = Vector2(full, full)
	for c in _map_canvas.get_children():
		c.position = Vector2.ZERO
		c.size = Vector2(full, full)
	# The unknown is black, the sea and its isles too, until walked or seen from a lit beacon
	_map_fog.position = Vector2.ZERO
	_map_fog.size = Vector2(full, full)
	_map_draw.zoom = _map_zoom
	_map_draw.queue_redraw()


func _map_center_on(p: Vector3) -> void:
	var full := MAP_VIEW * _map_zoom
	var m := Vector2((p.x + WIsles.MAP_HALF) / (WIsles.MAP_HALF * 2.0), (p.z + WIsles.MAP_HALF) / (WIsles.MAP_HALF * 2.0)) * full
	_map_off = Vector2(MAP_VIEW, MAP_VIEW) * 0.5 - m
	_map_layout()


## Map point (inside the window) to the world, and back.
func _map_world(v: Vector2) -> Vector3:
	var u := (v - _map_off) / (MAP_VIEW * _map_zoom)
	return Vector3(u.x * WIsles.MAP_HALF * 2.0 - WIsles.MAP_HALF, 0, u.y * WIsles.MAP_HALF * 2.0 - WIsles.MAP_HALF)


func _map_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var at: Vector2 = e.position
		var before := (at - _map_off) / _map_zoom
		_map_zoom = clampf(_map_zoom * (1.25 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 1.0, 6.0)
		_map_off = at - before * _map_zoom
		_map_layout()
		accept_event()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_map_drag = e.pressed
		accept_event()
	elif e is InputEventMouseMotion and _map_drag:
		_map_off += e.relative
		_map_layout()
		accept_event()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		# Taking away a mark is easy at any zoom: within about 12 pixels of it
		w.toggle_mark(_map_world(e.position), 12.0 / (MAP_VIEW * _map_zoom) * WIsles.MAP_HALF * 2.0)
		w.sfx("tick", -6)
		_map_draw.queue_redraw()
		accept_event()


func _update_fog() -> void:
	if _fog_img == null:
		return
	map_dirty = false
	var n: int = Wasteland.REVEAL_N
	for j in n:
		for i in n:
			_fog_img.set_pixel(i, j, Color(0, 0, 0, 0.0 if w.revealed[j * n + i] != 0 else 1.0))
	_fog_tex.update(_fog_img)


# ------------------------------------------------------------------ the beacon road, and rest

# ------------------------------------------------------------------ trades

func open_trade() -> void:
	_open("trade")


func _draw_trade() -> void:
	_clear()
	var tr: WTrades = w.trades
	var top := HBoxContainer.new()
	top.add_child(_title("Your Trade"))
	_body.add_child(top)
	_close_and_rule(top)
	var lead := "Each pilgrim keeps one trade. Each makes something no other can, so friends lean on one another."
	if tr.trade != "":
		lead += " To change it, go to a town and pay %d coin." % WTrades.CHANGE_COST
	_body.add_child(_wrap(lead, 18, DIM, 900))
	for k in WTrades.TRADES:
		var t: Dictionary = WTrades.TRADES[k]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_label(t.name + ("   (yours)" if tr.is_(k) else ""), 21, GOLD if tr.is_(k) else PALE))
		col.add_child(_wrap(t.text, 16, DIM, 680))
		row.add_child(col)
		if not tr.is_(k):
			var id: String = k
			var b := _action("Take up" if tr.trade == "" else "Change (%d coin)" % WTrades.CHANGE_COST, func(): tr.choose(id); _redraw())
			b.disabled = tr.refusal(k) != ""
			b.tooltip_text = tr.refusal(k)
			row.add_child(b)
		_body.add_child(row)
	_body.add_child(_action("Done", close_all, "Esc", DIM))


# ------------------------------------------------------------------ brewing by the fire

var _brew_pick: Array = []


func open_brew() -> void:
	_brew_pick = []
	_open("brew")


func _draw_brew() -> void:
	_clear()
	var al: WAlchemy = w.alchemy
	var top := HBoxContainer.new()
	top.add_child(_title("Brewing"))
	_body.add_child(top)
	_close_and_rule(top)
	_body.add_child(_wrap("Each of these holds two virtues. Taste one to learn the first. Brew two that share a virtue, with %d salt, and the draught carries it." % int(WAlchemy.BASE.salt), 18, DIM, 900))
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 6)
	for ing in WAlchemy.INGREDIENTS:
		var have: int = w.inv.count(ing)
		var picked: bool = ing in _brew_pick
		g.add_child(_label(Items.iname(ing), 19, GOLD if picked else PALE))
		g.add_child(_label("x%d" % have, 17, DIM))
		g.add_child(_label(al.known_text(ing), 17, PALE))
		var id: String = ing
		var t := _action("Taste", func(): al.taste(id); _redraw())
		t.disabled = have < 1 or (al.knows(ing, WAlchemy.INGREDIENTS[ing][0]) and al.knows(ing, WAlchemy.INGREDIENTS[ing][1]))
		g.add_child(t)
		var p := _action("Put back" if picked else "Choose", func():
			if id in _brew_pick:
				_brew_pick.erase(id)
			elif _brew_pick.size() < 2:
				_brew_pick.append(id)
			_redraw())
		p.disabled = have < 1 and not picked
		g.add_child(p)
	_body.add_child(g)
	_body.add_child(_gap(8))
	if _brew_pick.size() == 2:
		var a: String = _brew_pick[0]
		var b: String = _brew_pick[1]
		var bt := _action("Brew %s with %s" % [Items.iname(a), Items.iname(b).to_lower()], func():
			al.brew(a, b)
			for x in _brew_pick.duplicate():
				if w.inv.count(x) < 1:
					_brew_pick.erase(x)
			_redraw(), "", GOLD)
		bt.disabled = not al.can_brew(a, b)
		_body.add_child(bt)
	else:
		_body.add_child(_label("Choose two to brew.", 17, DIM))
	var now := []
	for e in al.active:
		now.append("%s, %d min" % [WAlchemy.EFFECTS[e].name, int(ceil(float(al.active[e]) / 60.0))])
	if not now.is_empty():
		_body.add_child(_label("Working now: " + ",  ".join(now), 17, GOLD))
	_body.add_child(_action("Done", close_all, "Esc", DIM))


# ------------------------------------------------------------------ the hidden playtest menu

func open_dev() -> void:
	_open("dev")


func _dev_grid(title: String, items: Array, cols := 3) -> void:
	_body.add_child(_label(title, 17, GOLD))
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 6)
	for it in items:
		var b := _action(it[0], it[1], "", it[2] if it.size() > 2 else PALE)
		b.custom_minimum_size.x = 340
		b.add_theme_font_size_override("font_size", 16)
		g.add_child(b)
	_body.add_child(g)


func _dev_do(f: Callable, close := false) -> void:
	f.call()
	if close:
		close_all()
	else:
		_redraw()


func _draw_dev() -> void:
	_clear()
	var d: WDev = w.dev
	var top := HBoxContainer.new()
	top.add_child(_title("Playtest"))
	_body.add_child(top)
	_close_and_rule(top)
	_body.add_child(_label(d.where(), 15, DIM))
	var list := _scroll(560)
	var keep := _body
	_body = list
	var lands: Array = []
	for l in WDev.LANDS:
		var key: String = l[0]
		lands.append([l[1], func(): _dev_do(func(): d.go(d.spot_in(key)), true)])
	_dev_grid("Go to a land (the nearest of it)", lands)
	var spots: Array = []
	for pl in d.places():
		var at: Vector3 = pl[1]
		spots.append([pl[0], func(): _dev_do(func(): d.go(at), true)])
	_dev_grid("Go to a place", spots)
	var host := d.host()
	var dim := PALE if host else Color(DIM, 0.4)
	if host:
		_dev_grid("The hour and the sky", [
			["Dawn", func(): _dev_do(func(): d.set_hour(w.weather.dawn() + 0.2))],
			["Noon", func(): _dev_do(func(): d.set_hour(12.0))],
			["Dusk", func(): _dev_do(func(): d.set_hour(w.weather.dusk() - 0.1))],
			["Midnight", func(): _dev_do(func(): d.set_hour(0.0))],
			["Eve of a seventh night", func(): _dev_do(func(): d.seventh())],
			["Clear", func(): _dev_do(func(): d.set_weather("clear"))],
			["Rain", func(): _dev_do(func(): d.set_weather("rain"))],
			["Ash storm", func(): _dev_do(func(): d.set_weather("ashstorm"))],
			["Salt frost", func(): _dev_do(func(): d.set_weather("frost"))],
			["Gale", func(): _dev_do(func(): d.set_weather("gale"))],
		])
	_dev_grid("Yourself", [
		["No harm: %s" % ("on" if d.god else "off"), func(): _dev_do(func(): d.god = not d.god), GOLD if d.god else PALE],
		["Fast stride: %s" % ("on" if d.fast else "off"), func(): _dev_do(func(): d.toggle_fast()), GOLD if d.fast else PALE],
		["Frame meter: %s" % ("on" if d.meter else "off"), func(): _dev_do(func(): d.toggle_meter()), GOLD if d.meter else PALE],
		["Heal, feed and rest", func(): _dev_do(func(): d.heal())],
		["A full kit of stuff", func(): _dev_do(func(): d.give_kit())],
		["Every weapon and kit", func(): _dev_do(func(): d.give_arms())],
		["Ammunition", func(): _dev_do(func(): d.give_ammo())],
	])
	if host:
		_dev_grid("Foes", [
			["Kill all near", func(): _dev_do(func(): w.hud.notify("%d fell." % d.kill_near()))],
			["Danger 1 foes", func(): _dev_do(func(): d.spawn_tier(1), true)],
			["Danger 2 foes", func(): _dev_do(func(): d.spawn_tier(2), true)],
			["Danger 3 foes", func(): _dev_do(func(): d.spawn_tier(3), true)],
			["Danger 4 foes", func(): _dev_do(func(): d.spawn_tier(4), true)],
			["Pretend fellowship: %s" % ("off" if WCrowd.fake == 0 else str(WCrowd.fake)), func(): _dev_do(func(): d.cycle_crowd()), GOLD if WCrowd.fake > 0 else PALE],
		])
		var forms := []
		for k in WDev.NEW_FORMS:
			forms.append([str(LesserSpeeb.VARIANTS[k].name), func(): _dev_do(func(): d.spawn_form(k), true)])
		_dev_grid("New forms (0.10)", forms)
	else:
		_body.add_child(_label("The hour, the weather and foes are for the host.", 15, dim))
	_body = keep


func open_travel() -> void:
	_open("travel")


func _draw_travel() -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_child(_title("The Beacon Road"))
	_body.add_child(top)
	_close_and_rule(top)
	_body.add_child(_wrap("Burning beacons see one another. Walk their light to any of them.", 19, DIM))
	for i in w.lit:
		var b: Dictionary = WPlaces.BEACONS[i]
		_body.add_child(_action(b.name, func(): _travel(i)))
	if w.flags.has("ruth_met") and not w.flags.has("unlit_pact"):
		_body.add_child(_action("Put this fire out, as Ruth asked", func(): w.endings.put_out_near(); close_all(), "", Color(0.75, 0.7, 0.85)))
	_body.add_child(_action("Stay here", close_all, "Esc", DIM))


func _travel(i: int) -> void:
	close_all()
	w.player.input_locked = true
	await w.hud.fade_to(1.0, 1.0)
	var c: Vector3 = w.beacon_nodes[i].pos
	w.player.place(c + Vector3(0, 2.2, 7.0), 0.0)
	w.sfx("choir", -10)
	await w.hud.fade_to(0.0, 1.2)
	w.player.input_locked = false


var _rest_kind := ""
var _vote_label: Label


var _rest_pid := -1


## How long a fire will burn, and a button to put wood on it.
func _fuel_row(pid: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	var left: float = w.fuel_left(pid)
	hb.add_child(_label(("Burns for %s more." % w._days_text(left)) if left > 0.0 else "The fire is out.", 18, PALE if left > 24.0 else GOLD))
	var b := _action("Add wood  (you have %d)" % w.inv.count("wood"), func(): w.add_wood(pid); _redraw())
	b.disabled = w.inv.count("wood") <= 0 or left > Wasteland.FUEL_MAX - Wasteland.WOOD_HOURS
	b.tooltip_text = "Each piece of wood burns for a day."
	hb.add_child(b)
	return hb


var _boon_from := ""

## A kindled beacon's boons: choose one, kept for good. Put off, it waits at any lit beacon.
func open_boons(from_name: String) -> void:
	if w.skills.boon_offer.is_empty():
		return
	_boon_from = from_name
	_open("boons")


func _draw_boons() -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_child(_title("A Beacon Boon"))
	_body.add_child(top)
	_close_and_rule(top)
	_body.add_child(_wrap("%s burns. Its light gives you one of these, for good." % _boon_from if _boon_from != "" else "The beacons' light gives you one of these, for good.", 20, PALE))
	for id in w.skills.boon_offer:
		var b: Dictionary = WSkills.BOONS[id]
		var bid: String = id
		_body.add_child(_action("%s: %s" % [b.name, b.text], func():
			if w.skills.take_boon(bid):
				w.sfx("jingle_up", -6)
				w.hud.notify("%s is yours." % WSkills.BOONS[bid].name)
				w.autosave_soon(1.0)
			close_all(), "", GOLD))
	_body.add_child(_action("Later (it waits at any lit beacon)", close_all, "Esc", DIM))


func ask_rest(kind := "fire", pid := -1) -> void:
	_rest_kind = kind
	_rest_pid = pid
	_open("rest")
	_draw_rest()


func _draw_rest() -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_child(_title({"fire": "The Fire", "inn": "The Inn"}.get(_rest_kind, "The Bedroll")))
	_body.add_child(top)
	_close_and_rule(top)
	_body.add_child(_label("Food %d     Rest %d" % [int(w.food), int(w.rest)], 18, DIM))
	if _rest_kind == "bed":
		_bed_rows()
	if _rest_kind == "fire" and _rest_pid >= 0:
		_body.add_child(_fuel_row(_rest_pid))
		if not w.burning(_rest_pid):
			_body.add_child(_wrap("Add wood before you rest.", 20, PALE))
			_body.add_child(_action("Not now", close_all, "Esc", DIM))
			return
		_body.add_child(_action("Brew draughts", func(): open_brew()))
		w.spirits.rekindle()
	var near := 0
	for e in w.enemies:
		if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(w.player.global_position) < 40.0:
			near += 1
	if near > 0:
		_body.add_child(_wrap("You cannot rest with forms so close.", 20, PALE))
	elif w.night:
		var t := "Sleep until dawn?" if not Net.online else ("Sleep until dawn? Everyone must lie down by a fire or a bedroll before the night passes." if Net.pilgrims().size() <= 4 else "Sleep until dawn? Three in four of the fellowship must lie down by a fire or a bedroll.")
		_body.add_child(_wrap(t, 20, PALE))
		if w._my_vote:
			_body.add_child(_action("Get up", func(): w.vote_sleep(false); _draw_rest()))
		else:
			_body.add_child(_action("Sleep until dawn", func(): w.vote_sleep(true); _draw_rest(), "", GOLD))
		_vote_label = _label("", 18, GOLD)
		_body.add_child(_vote_label)
	else:
		_body.add_child(_wrap("It is day. A short sleep will leave you rested.", 20, PALE))
		_body.add_child(_action("Sleep a while", func(): close_all(); w.nap(), "", GOLD))
	_body.add_child(_action("Not now", close_all, "Esc", DIM))


## Whose bed this is, and giving it: to yourself, to another of the fellowship, or to no one.
func _bed_rows() -> void:
	var pid := _rest_pid
	if pid < 0 or not w.pieces.has(pid):
		_body.add_child(_wrap("You will wake here if you fall.", 18, DIM))
		return
	var owner: String = w.bed_owner(pid)
	var me: String = w.bed_name()
	var may: bool = owner == "" or owner == me or (Net.online and Net.is_host())
	if owner == "":
		_body.add_child(_wrap("No one's bed. You will wake here if you fall. Make it yours, or give it to one of the fellowship.", 18, DIM))
	elif owner == me:
		_body.add_child(_wrap("Your bed. You will wake here if you fall.", 18, GOLD))
	else:
		_body.add_child(_wrap("%s's bed. You may rest in it, but you will not wake here." % owner, 18, PALE))
	if not may:
		return
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	if owner != me:
		row.add_child(_bed_chip("Make it mine", func(): w.shared("_rq_bed_owner", [pid, me, Net.me()]), GOLD))
	if Net.online:
		for id in Net.players:
			var nm: String = Net.name_of(id)
			if nm != owner and nm != me:
				row.add_child(_bed_chip("Give to %s" % nm, func(): w.shared("_rq_bed_owner", [pid, nm, Net.me()]), Net.color_of(id).lightened(0.3)))
	if owner != "":
		row.add_child(_bed_chip("Free it", func(): w.shared("_rq_bed_owner", [pid, "", Net.me()]), DIM))
	_body.add_child(row)


func _bed_chip(text: String, cb: Callable, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.3))
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.1 if st == "hover" else 0.04)
		sb.border_color = Color(col, 0.6)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	return b


func bed_changed(pid: int) -> void:
	if _panel_name == "rest" and _rest_kind == "bed" and _rest_pid == pid:
		_draw_rest()


func sleep_count(have: int, of: int) -> void:
	if _panel_name == "rest" and is_instance_valid(_vote_label) and of > 1:
		_vote_label.text = "%d of %d are ready to sleep." % [have, of]


# ------------------------------------------------------------------ the planter

var _pid := -1


func open_planter(pid: int) -> void:
	_pid = pid
	_open("planter")


func planter_changed(pid: int) -> void:
	if pid == _pid and _panel_name in ["planter", "portal"]:
		_redraw()


func _draw_planter() -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_child(_title("Planter Box"))
	_body.add_child(top)
	_close_and_rule(top)
	var pc: Dictionary = w.pieces.get(_pid, {})
	if pc.is_empty():
		return
	if pc.crop == "":
		_body.add_child(_wrap("The soil is turned and waiting. What will you plant?", 20, PALE))
		var any := false
		for id in Items.DB:
			if Items.info(id).kind == "seed" and w.inv.count(id) > 0:
				any = true
				var b := _action("Plant %s  (you have %d)" % [Items.iname(id), w.inv.count(id)], func():
					if w.inv.take(id, 1) == 1:
						w.shared("_rq_plant", [Net.me(), _pid, id]))
				b.tooltip_text = Items.info(id).text
				_body.add_child(b)
		if not any:
			_body.add_child(_wrap("You carry no seeds. Tuber eyes come from tubers, from camps and caravans, or from the traders.", 18, DIM))
	else:
		var left: float = w.crop_left(_pid)
		var grows: String = Items.iname(Items.info(pc.crop).grows)
		if left > 0.0:
			_body.add_child(_wrap("%s, growing. Ready in about %d hours." % [grows, ceili(left)], 20, PALE))
		else:
			_body.add_child(_wrap("%s, ready to lift." % grows, 20, PALE))
			_body.add_child(_action("Harvest", func(): w.shared("_rq_harvest", [Net.me(), _pid]), "", GOLD))
	_body.add_child(_action("Close", close_all, "Esc", DIM))


# ------------------------------------------------------------------ the trophy shrine

# ------------------------------------------------------------------ the end of the road

func open_page() -> void:
	_open("page")


func _draw_page() -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_child(_title("The Tenth Page"))
	_body.add_child(top)
	_close_and_rule(top)
	_body.add_child(_wrap("A long table, and five who never stood up. At its head, a white page, and a pen still wet.", 20, PALE, 1000))
	_body.add_child(_gap(6))
	_body.add_child(_wrap("At the foot of the page, one line, in a hand you almost know:\n\"It asked us not to look at it, and we were so tired of looking.\"", 19, DIM, 1000))
	_body.add_child(_gap(14))
	_body.add_child(_action("Leave it blank.", func():
		w.shared("_rq_ending", [Net.me(), "keeper"])
		close_all(), "1", GOLD))
	var read: int = w.hall.pages_read()
	if read >= 6:
		_body.add_child(_action("Write on it.", func():
			w.shared("_rq_ending", [Net.me(), "writer"])
			close_all(), "2", GOLD))
	else:
		_body.add_child(_wrap("You do not know what to write. The rest of the Tenth Page lies torn up across the waste, in sealed chests: %d of 6 leaves read." % read, 17, DIM, 1000))
	if w.flags.has("unlit_pact"):
		_body.add_child(_action("Take the stair down, to Ruth's people.", func():
			w.shared("_rq_ending", [Net.me(), "unlit"])
			close_all(), "3", Color(0.75, 0.7, 0.85)))
	if w.endings.can_pilgrim():
		_body.add_child(_action("Look up. Someone is standing at the end of the table.", func():
			w.shared("_rq_ending", [Net.me(), "pilgrim"])
			close_all(), "4", Color(0.85, 0.85, 0.7)))
	_body.add_child(_action("Not yet.", close_all, "Esc", DIM))


var _end_title := ""
var _end_text := ""
var _end_note := ""


func open_ending(title: String, text: String, note := "") -> void:
	_end_title = title
	_end_text = text
	_end_note = note
	_open("ending")


func _draw_ending() -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_child(_title(_end_title))
	_body.add_child(top)
	_close_and_rule(top)
	if _end_note != "":
		_body.add_child(_wrap(_end_note, 17, DIM, 1000))
	_body.add_child(_wrap(_end_text, 21, PALE, 1000))
	_body.add_child(_gap(14))
	_body.add_child(_wrap("The world goes on. The fires still need keeping, and the roads are still long.", 17, DIM, 1000))
	_body.add_child(_action("Go on", close_all, "Esc", GOLD))


func open_shrine(pid: int) -> void:
	_pid = pid
	_open("shrine")


func _draw_shrine() -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_child(_title("Trophy Shrine"))
	_body.add_child(top)
	_close_and_rule(top)
	if w.power != "" and w.power_left > 0.0:
		_body.add_child(_wrap("You carry %s for %d more minutes." % [w.POWERS[w.power].name, ceili(w.power_left / 60.0)], 20, GOLD))
	var any := false
	for t in w.POWERS:
		var pw: Dictionary = w.POWERS[t]
		if w.flags.has("shrine_" + t):
			any = true
			var b := _action("Take up %s" % pw.name, func():
				w.take_power(t)
				_redraw())
			b.tooltip_text = pw.text
			_body.add_child(b)
			_body.add_child(_wrap(pw.text, 16, DIM))
		elif w.inv.count(t) > 0:
			any = true
			var b2 := _action("Lay %s on the shrine" % Items.iname(t), func():
				w.lay_trophy(t)
				_redraw())
			b2.tooltip_text = "Once laid, %s is yours to take up here: %s" % [pw.name, pw.text.to_lower()]
			_body.add_child(b2)
	if not any:
		_body.add_child(_wrap("The shrine is bare. Bring the trophy of a great one, and lay it here.", 18, DIM))
	else:
		_body.add_child(_wrap("One power at a time. Each lasts half an hour.", 16, DIM))
	_body.add_child(_action("Close", close_all, "Esc", DIM))


# ------------------------------------------------------------------ your cat

func open_cat() -> void:
	_open("cat")


func _draw_cat() -> void:
	_clear()
	var c = w.cat
	if c == null:
		return
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.add_child(_title(c.cat_name))
	var field := LineEdit.new()
	field.text = c.cat_name
	field.placeholder_text = "Name your cat"
	field.max_length = 20
	field.custom_minimum_size = Vector2(220, 0)
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.add_theme_font_size_override("font_size", 17)
	top.add_child(field)
	var save := func():
		var t := field.text.strip_edges()
		if t != "" and t != c.cat_name:
			c.cat_name = t
			c._refresh()
	field.text_submitted.connect(func(_t): save.call(); _redraw.call_deferred())
	field.focus_exited.connect(save)
	_body.add_child(top)
	_close_and_rule(top)
	_stat(_body, "Health", "%d / %d" % [int(c.hp), int(WCat.HP_MAX)], clampf(c.hp / WCat.HP_MAX, 0.02, 1.0))
	_body.add_child(_wrap("Ride with [%s]. Hold [%s] while riding to sprint on its breath. Whistle with [%s] and it comes to you." % [Game.key_text("interact"), Game.key_text("run"), Game.key_text("whistle")], 16, DIM))
	_body.add_child(_label("Barding", 18, GOLD))
	for id in WCat.BARDING:
		if id == "":
			continue
		var b: Dictionary = WCat.BARDING[id]
		var on: bool = c.barding == id
		var cost: Dictionary = b.cost
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var nm := _label("%s  (turns aside %d%%)" % [b.name, int(b.guard * 100.0)], 17, GOLD if on else PALE)
		nm.custom_minimum_size.x = 300
		row.add_child(nm)
		if on:
			row.add_child(_label("Worn", 16, GOLD))
		else:
			row.add_child(_secondary("Make and fit", func(): _arms_pay(cost, func(): c.barding = id; c._refresh()), w.stock_has_all(_acost(cost))))
			row.add_child(_cost_line(_acost(cost)))
		_body.add_child(row)


# ------------------------------------------------------------------ the waystone

func open_portal(pid: int) -> void:
	_pid = pid
	_open("portal")


func _draw_portal() -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_child(_title("Waystone"))
	_body.add_child(top)
	_close_and_rule(top)
	var pc: Dictionary = w.pieces.get(_pid, {})
	if pc.is_empty():
		return
	_body.add_child(_wrap("Two waystones of the same name lead to each other.", 18, DIM))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var field := LineEdit.new()
	field.text = str(pc.name)
	field.placeholder_text = "A name"
	field.max_length = 24
	field.custom_minimum_size = Vector2(360, 0)
	field.add_theme_font_size_override("font_size", 20)
	hb.add_child(field)
	var save := func(): w.shared("_rq_portal_name", [_pid, field.text])
	field.text_submitted.connect(func(_t): save.call())
	hb.add_child(_chip("Name it", false, save))
	_body.add_child(hb)
	var to: int = w.portal_pair(_pid)
	if to >= 0:
		var d := int(pc.pos.distance_to(w.pieces[to].pos))
		_body.add_child(_action("Step through  (%d m)" % d, func(): close_all(); w.step_through(_pid), "", GOLD))
	elif str(pc.name) != "":
		_body.add_child(_wrap("No other waystone bears this name yet.", 18, DIM))
	var names := {}
	for q in w.pieces:
		if w.pieces[q].kind == "portal" and str(w.pieces[q].name) != "":
			names[w.pieces[q].name] = names.get(w.pieces[q].name, 0) + 1
	if not names.is_empty():
		var parts: Array = []
		for n in names:
			parts.append("%s%s" % [n, "" if names[n] > 1 else " (alone)"])
		_body.add_child(_wrap("Named waystones: " + ", ".join(parts), 16, DIM))
	_body.add_child(_action("Close", close_all, "Esc", DIM))


# ------------------------------------------------------------------ the build guide

var _bcat := "Camp"


func _draw_build_guide() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(_pill("Pick a piece and Build.    [%s] stop building    [%s] turn    wheel: next piece    aim: take down (half back)" % [Game.key_text("build"), Game.key_text("reload")], true))
	_body.add_child(top)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(split)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 4)
	rail.custom_minimum_size.x = 170
	split.add_child(rail)
	for g in Items.GROUPS:
		rail.add_child(_rail_btn(g, 0, g == _bcat, func(): _bcat = g; _redraw()))
	var grid := _card_grid()
	split.add_child(grid.get_parent())
	var side := _side_panel(split)
	side.custom_minimum_size.x = 250
	var chosen := ""
	for k in Items.PIECE_ORDER:
		var pc: Dictionary = Items.PIECES[k]
		if pc.group != _bcat:
			continue
		var cost: Dictionary = w.skills.cost(pc.cost)
		if chosen == "" or Items.PIECE_ORDER[w.builder.sel] == k:
			chosen = k
		var pick := func():
			w.builder.sel = Items.PIECE_ORDER.find(k)
			_redraw()
		var go := func():
			w.builder.sel = Items.PIECE_ORDER.find(k)
			close_all()
			if not w.builder.active:
				w.builder.toggle()
				w.player.set_armed(false)
			w.builder._hint()
		grid.add_child(_card("pc_" + k, pc.name, "Holds well" if float(pc.hp) >= 600.0 else pc.group, DIM, cost, "Build", go, w.stock_has_all(cost), Items.PIECE_ORDER[w.builder.sel] == k, pick))
	if chosen == "":
		return
	var pcs: Dictionary = Items.PIECES[chosen]
	side.add_child(WGlyph.make("pc_" + chosen, 72))
	side.add_child(_label(pcs.name, 23, PALE))
	side.add_child(_wrap(pcs.text, 16, Color(PALE, 0.85), 220))
	_stat(side, "Strength", str(int(pcs.hp)), clampf(float(pcs.hp) / 900.0, 0.05, 1.0))
	side.add_child(_cost_line(w.skills.cost(pcs.cost)))


## A cost with what is carried beside each part: pale when there is enough, red when not.
func cost_bb(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		var have: int = w.stock_count(k)
		var need := int(cost[k])
		var c := "#e9e4d6" if have >= need else "#d0665a"
		parts.append("[color=%s]%s %d/%d[/color]" % [c, Items.iname(k), have, need])
	return "   ".join(parts)


# ================================================================== drawn things

class Compass extends Control:
	var w

	func _draw() -> void:
		if w == null or w.player == null or not w.ready_world:
			return
		var wd := size.x
		var cx := wd * 0.5
		var fwd: Vector3 = -w.player.global_transform.basis.z
		var heading := atan2(fwd.x, -fwd.z)
		draw_rect(Rect2(0, 18, wd, 1), Color(1, 1, 1, 0.18))
		var font := ThemeDB.fallback_font
		for k in 8:
			var ang := k * TAU / 8.0
			var dx := wrapf(ang - heading, -PI, PI)
			if absf(dx) > 1.2:
				continue
			var x := cx + dx / 1.2 * cx
			var lab: String = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][k]
			draw_string(font, Vector2(x - 8, 14), lab, HORIZONTAL_ALIGNMENT_CENTER, -1, 14 if k % 2 == 0 else 11, Color(0.9, 0.88, 0.8, 0.8 if k % 2 == 0 else 0.45))
		var marks: Array = []
		var q = w.quests.quests.get(w.quests.tracked)
		if q != null:
			var t = w.quests.target_of(q)
			if t != null:
				marks.append([t, Color(0.95, 0.82, 0.5), 7.0])
		for i in w.lit:
			marks.append([w.beacon_nodes[i].pos, Color(1, 0.97, 0.85, 0.6), 4.0])
		if q == null:
			# Nothing tracked: the beacon road still shows the way
			var nb: int = w.next_dark_beacon(w.player.global_position)
			if nb >= 0:
				marks.append([w.beacon_nodes[nb].pos, Color(0.95, 0.5, 0.35, 0.9), 6.0])
		if w.events:
			for id in w.events.active:
				var ev: Dictionary = w.events.active[id]
				marks.append([ev.pos, Color(1.0, 0.85, 0.35), 6.5, WEvents.KINDS[ev.kind].name])
		for m in w.map_marks:
			marks.append([m[0] + Vector3(0, w.player.global_position.y, 0), Color(0.6, 0.85, 1.0, 0.95) if not Net.online else Net.color_of(int(m[1])).lightened(0.25), 6.0])
		for k in w.visited:
			marks.append([w.gpos(WPlaces.spos(k)), Color(0.8, 0.6, 0.4, 0.7), 4.0])
		var witness: bool = w.night and w.skills.rank("witness") > 0
		for e in w.enemies:
			if is_instance_valid(e) and e.is_alive() and (e.seen_t > 0.0 or (witness and e.global_position.distance_to(w.player.global_position) < 40.0)):
				marks.append([e.global_position, Color(0.85, 0.25, 0.2, 0.85), 3.5])
		for id in w.avatars:
			var a = w.avatars[id]
			if is_instance_valid(a) and a.visible:
				marks.append([a.global_position, Net.color_of(id).lightened(0.2), 6.0, Net.name_of(id)])
		var me: Vector3 = w.player.global_position
		for m in marks:
			var p: Vector3 = m[0]
			var d := p - me
			if Vector2(d.x, d.z).length() < 6.0:
				continue
			var ang := atan2(d.x, -d.z)
			var dx := wrapf(ang - heading, -PI, PI)
			var x := cx + clampf(dx / 1.2, -1.0, 1.0) * cx
			var r: float = m[2]
			draw_colored_polygon(PackedVector2Array([Vector2(x, 26 - r), Vector2(x + r, 26), Vector2(x, 26 + r), Vector2(x - r, 26)]), m[1])
			if m.size() > 3:
				draw_string(font, Vector2(x - 60, 48), "%s  %d m" % [m[3], int(Vector2(d.x, d.z).length())], HORIZONTAL_ALIGNMENT_CENTER, 120, 12, m[1])
			elif r > 5.0:
				draw_string(font, Vector2(x - 30, 48), "%d m" % int(Vector2(d.x, d.z).length()), HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(0.95, 0.85, 0.6, 0.9))


class MapDraw extends Control:
	var w
	var zoom := 1.0

	func _to(p: Vector3) -> Vector2:
		return Vector2((p.x + WIsles.MAP_HALF) / (WIsles.MAP_HALF * 2.0), (p.z + WIsles.MAP_HALF) / (WIsles.MAP_HALF * 2.0)) * size

	func _draw() -> void:
		if w == null or w.player == null:
			return
		var font := ThemeDB.fallback_font
		for il in w.terrain.isles:
			if not w.is_revealed(Vector3(il.c.x, 0, il.c.y)):
				continue
			var ip := _to(Vector3(il.c.x, 0, il.c.y))
			draw_string(font, ip + Vector2(-80, -float(il.r) / (WIsles.MAP_HALF * 2.0) * size.x - 6.0), il.name, HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(0.85, 0.9, 0.92, 0.9))
		for r in w.ruins:
			if w.known_ruins.has(r.id) or w.is_revealed(r.pos):
				var p := _to(r.pos)
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.75, 0.68, 0.58, 0.85))
				if w.known_ruins.has(r.id):
					draw_string(font, p + Vector2(6, 4), r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.8, 0.7, 0.8))
		for l in w.lairs:
			if w.is_revealed(l.pos):
				var p := _to(l.pos)
				var lc := Color(0.85, 0.2, 0.12) if w.lair_ready(l) else Color(0.4, 0.3, 0.28)
				draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), lc, 2.5)
				draw_line(p + Vector2(-6, 6), p + Vector2(6, -6), lc, 2.5)
				draw_circle(p, 3.0, lc)
				draw_string(font, p + Vector2(9, 4), l.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.6, 0.55, 0.9))
		for k in WPlaces.SETTLEMENTS:
			var s: Dictionary = WPlaces.SETTLEMENTS[k]
			var p3: Vector3 = w.gpos(WPlaces.spos(k))
			if w.visited.has(k) or w.is_revealed(p3):
				var p := _to(p3)
				draw_circle(p, 6.0, Color(0.85, 0.6, 0.35))
				draw_string(font, p + Vector2(9, 5), s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.9, 0.8))
		for i in WPlaces.BEACONS.size():
			var p3: Vector3 = w.beacon_nodes[i].pos
			if w.is_revealed(p3) or i in w.lit:
				var p := _to(p3)
				var c := Color(1, 0.97, 0.8) if i in w.lit else Color(0.45, 0.42, 0.4)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(7, 5), p + Vector2(-7, 5)]), c)
		if w.bedroll is Vector3:
			var p := _to(w.bedroll)
			draw_line(p - Vector2(5, 0), p + Vector2(5, 0), Color(0.6, 0.85, 1.0), 2.0)
			draw_line(p - Vector2(0, 5), p + Vector2(0, 5), Color(0.6, 0.85, 1.0), 2.0)
		if w.cat and not w.cat.ridden:
			# Your cat: a little head with two ears, and its name
			var p := _to(w.cat.global_position)
			var cc := Color(0.98, 0.8, 0.45)
			draw_circle(p, 5.5, cc)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -2), p + Vector2(-4, -9), p + Vector2(-1, -4)]), cc)
			draw_colored_polygon(PackedVector2Array([p + Vector2(5, -2), p + Vector2(4, -9), p + Vector2(1, -4)]), cc)
			draw_string(font, p + Vector2(9, 5), w.cat.cat_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cc)
		for sid in w.satchels:
			if w.satchels[sid].grave:
				var p := _to(w.satchels[sid].pos)
				draw_line(p - Vector2(5, 5), p + Vector2(5, 5), Color(0.7, 0.8, 1.0), 2.0)
				draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), Color(0.7, 0.8, 1.0), 2.0)
		var q = w.quests.quests.get(w.quests.tracked)
		if q != null:
			var t = w.quests.target_of(q)
			if t != null:
				var p := _to(t)
				var pulse := 7.0 + sin(Time.get_ticks_msec() * 0.006) * 2.0
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -pulse), p + Vector2(pulse, 0), p + Vector2(0, pulse), p + Vector2(-pulse, 0)]), Color(0.95, 0.82, 0.5))
		for id in w.avatars:
			var a = w.avatars[id]
			if is_instance_valid(a) and a.visible:
				var ap := _to(a.global_position)
				draw_circle(ap, 7.0, Color(0, 0, 0, 0.7))
				draw_circle(ap, 5.0, Net.color_of(id))
				draw_string(font, ap + Vector2(9, 5), Net.name_of(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Net.color_of(id).lightened(0.3))
		for m in w.map_marks:
			var mp := _to(m[0])
			var mc: Color = Net.color_of(int(m[1])).lightened(0.2) if Net.online else Color(0.95, 0.82, 0.5)
			draw_line(mp, mp + Vector2(0, -16), Color(0, 0, 0, 0.7), 3.0)
			draw_line(mp, mp + Vector2(0, -16), Color(0.95, 0.92, 0.85), 1.5)
			draw_colored_polygon(PackedVector2Array([mp + Vector2(0, -16), mp + Vector2(11, -12), mp + Vector2(0, -8)]), mc)
			draw_circle(mp, 2.5, Color(0.95, 0.92, 0.85))
			var dist := int(Vector2(m[0].x - w.player.global_position.x, m[0].z - w.player.global_position.z).length())
			draw_string(font, mp + Vector2(13, -6), "%d m" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.92, 0.85, 0.9))
		var me := _to(w.player.global_position)
		var f: Vector3 = -w.player.global_transform.basis.z
		var dir := Vector2(f.x, f.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([me + dir * 10.0, me - dir * 6.0 + side * 6.0, me - dir * 6.0 - side * 6.0]), Color(1, 1, 1))
