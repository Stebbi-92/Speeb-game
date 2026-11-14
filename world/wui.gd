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
	_frame = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = Color(GOLD, 0.35)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(26)
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
	_saved = _label("", 16, DIM)
	_pin(_saved, 1.0, 1.0, Rect2(-330, -64, 300, 26))
	_saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saved.modulate.a = 0.0
	add_child(_saved)


var _saved: Label
var _needs := {}


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
	_body.add_child(_title("What You Have Learned"))
	var head := "Level %d.   %d of %d toward the next.   " % [s.level, s.xp, WSkills.need(s.level)] if s.level < WSkills.MAX_LEVEL else "Level %d, the most there is.   " % s.level
	head += ("%d point%s to spend." % [s.points, "" if s.points == 1 else "s"]) if s.points > 0 else "Nothing to spend. Experience comes from the forms you fell, the work you do, the places you find and the beacons you light."
	var hl := _label(head, 17, GOLD if s.points > 0 else DIM)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(hl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_body.add_child(row)
	for t in WSkills.TREES:
		var tr: Dictionary = WSkills.TREES[t]
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 250
		col.add_theme_constant_override("separation", 6)
		row.add_child(col)
		col.add_child(_label("%s   %d" % [tr.name, s.spent_in(t)], 24, GOLD))
		var tl := _label(tr.text, 14, DIM)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size.x = 250
		col.add_child(tl)
		col.add_child(HSeparator.new())
		for id in tr.skills:
			var sk: Dictionary = WSkills.SKILLS[id]
			var r := s.rank(id)
			var why := s.blocked(id)
			var pips := ""
			for i in int(sk.ranks):
				pips += "●" if i < r else "○"
			var b := _btn("%s  %s" % [sk.name, pips], func(): _learn(id), 19, PALE if why == "" else (GOLD if r > 0 else DIM))
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = sk.text + ("" if why == "" else "\n" + why)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			col.add_child(b)
			var line := _label(sk.text if why == "" or why == "Mastered" or why == "No points to spend" else why, 13, Color(DIM, 0.85))
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size.x = 250
			col.add_child(line)


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
		_redraw.call_deferred()


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


func _wrap(t: String, size := 20, c := PALE) -> Label:
	var l := _label(t, size, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 400
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
	if not (e is InputEventKey or e is InputEventMouseButton) or w.player == null:
		return
	if get_tree().paused or w.hud.pause_panel.visible or w.hud.options_panel.visible:
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
		if w.player.input_locked and _panel == null:
			return
	if w.player.input_locked and _panel == null:
		return
	if e.is_action_pressed("pack") or (e.is_action_pressed("codex") and not e.is_echo()):
		if _panel != null and _panel_name == "pack":
			close_all()
		else:
			open_inventory("pack")
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
	if w.builder.active and _panel == null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if e.is_action_pressed("fire"):
			w.builder.place()
			accept_event()
		elif e.is_action_pressed("aim"):
			w.builder.dismantle()
			accept_event()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			w.builder.choose(-1)
			accept_event()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			w.builder.choose(1)
			accept_event()


var _panel_name := ""


func _open(name: String) -> void:
	_panel_name = name
	_panel = _frame
	_frame.visible = true
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
	_talking = ""
	_frame.visible = false
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


func _redraw() -> void:
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
		"planter":
			_draw_planter()
		"portal":
			_draw_portal()


# ------------------------------------------------------------------ the strip along the top

func _process(_delta: float) -> void:
	if w.player == null:
		return
	var h := int(w.clock)
	var mn := int((w.clock - h) * 60.0)
	var part := "Night" if w.night else ("Dawn" if w.clock < 7.0 else ("Dusk" if w.clock >= 18.0 else "Day"))
	_clock.text = "Day %d   %02d:%02d   %s" % [w.day, h, mn, part]
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
	_build_hint.text = "[center]%s\n[color=#8d877b]‹ %s      %s      %s ›[/color][/center]" % [cost_bb(w.skills.cost(pc.cost)), prev, pc.text, next]


# ------------------------------------------------------------------ the pack, and making things

func open_inventory(tab := "pack") -> void:
	_tab = tab
	_open("pack")


func _pack_header() -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	hb.add_child(_title("Pack"))
	hb.add_child(_btn("Carried", func(): _tab = "pack"; _redraw(), 22, GOLD if _tab == "pack" else DIM))
	hb.add_child(_btn("Make", func(): _tab = "craft"; _redraw(), 22, GOLD if _tab == "craft" else DIM))
	hb.add_child(_btn("Arms", func(): _tab = "arms"; _redraw(), 22, GOLD if _tab == "arms" else DIM))
	hb.add_child(_btn("Build", func(): _tab = "build"; _redraw(), 22, GOLD if _tab == "build" else DIM))
	var info := _label("Salt: %d" % w.inv.count("salt"), 18, DIM)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(info)
	_body.add_child(hb)


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
	_body.add_child(_label("Click a thing to choose it. Right click drops the whole stack.", 16, DIM))
	_body.add_child(_slot_grid(w.inv, func(i, right): _pack_click(i, right), 6, _sel))
	_desc = _wrap("", 18, DIM)
	_body.add_child(_desc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_body.add_child(row)
	var near := _near_players()
	var s = w.inv.slots[_sel] if _sel >= 0 and _sel < w.inv.slots.size() else null
	if s != null:
		var info: Dictionary = Items.info(s.id)
		var n := int(s.n)
		_desc.text = "%s. %s  Worth %d salt." % [info.name, info.text, int(info.value)]
		if info.kind in ["food", "medicine"]:
			row.add_child(_btn("Eat" if info.kind == "food" else "Use", func(): _use_item(_sel), 19, PALE))
		if info.kind == "wear":
			var sid: String = s.id
			row.add_child(_btn("Wear", func(): _wear(sid); _sel = -1; _redraw(), 19, PALE))
		row.add_child(_btn("Drop one", func(): _drop(_sel, 1), 19, PALE))
		if n > 2:
			row.add_child(_btn("Drop half", func(): _drop(_sel, n / 2), 19, PALE))
		if n > 1:
			row.add_child(_btn("Drop all", func(): _drop(_sel, n), 19, PALE))
		for id in near:
			row.add_child(_btn("Give to %s" % Net.name_of(id), func(): _give_to(id, _sel, n), 19, GOLD))
			if n > 1:
				row.add_child(_btn("Give half", func(): _give_to(id, _sel, maxi(1, n / 2)), 19, GOLD))


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
	if w.eat(s.id):
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
	w.hud.notify("Gave %d %s to %s." % [it[1], Items.iname(it[0]), Net.name_of(id)])


# ------------------------------------------------------------------ arms: what is carried, fitted and made

func _arms_pay(cost: Dictionary, done: Callable) -> void:
	if not w.inv.pay(w.skills.cost(cost)):
		return
	done.call()
	w.sfx("carve", -6)
	w.rearm()
	_redraw()


func _arms_btn(text: String, cost: Dictionary, bench: bool, done: Callable) -> Button:
	var c: Dictionary = w.skills.cost(cost)
	var ok: bool = bench and w.inv.has_all(c)
	var b := _btn("%s   %s" % [text, Items.cost_text(c)], func(): _arms_pay(cost, done), 17, PALE if ok else DIM)
	b.disabled = not ok
	return b


func _draw_arms() -> void:
	var a: Dictionary = w.arms
	var bench: bool = debug_bench or w.builder.near_kind(w.player.global_position, "bench", 5.0)
	_body.add_child(_label("At a workbench." if bench else "Choose what to carry anywhere. Making and fitting need a workbench close by.", 16, DIM))
	var v := _scroll(540)
	var sc: ScrollContainer = v.get_parent()
	sc.scroll_vertical = _arms_scroll
	sc.set_deferred("scroll_vertical", _arms_scroll)
	sc.get_v_scroll_bar().value_changed.connect(func(x): _arms_scroll = int(x))
	for g in ArmsDB.GUNS:
		if not g in a.owned:
			continue
		var sp: Dictionary = ArmsDB.GUNS[g]
		var slot: String = sp.slot
		var carried: bool = a[slot] == g
		var t: int = int(a.tier.get(g, 0))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 18)
		v.add_child(hb)
		var nm := _label("%s%s" % ["◆ " if carried else "", sp.name], 22, GOLD if carried else PALE)
		nm.custom_minimum_size.x = 250
		hb.add_child(nm)
		var dmg := float(sp.dmg) * (1.0 + 0.12 * t)
		hb.add_child(_label("%s    Harm %d%s    Holds %d" % [WArms.TIERS[t], int(round(dmg)), " ×%d" % int(sp.pellets) if int(sp.pellets) > 1 else "", Arms.mag_of(g)], 16, DIM))
		if not carried:
			hb.add_child(_btn("Carry", func(): a[slot] = g; w.rearm(); _redraw(), 17, PALE))
		if t < 3:
			hb.add_child(_arms_btn("Work on it", WArms.tier_cost(t + 1), bench, func(): a.tier[g] = t + 1))
		if not sp.mounts.is_empty():
			var mr := HBoxContainer.new()
			mr.add_theme_constant_override("separation", 18)
			v.add_child(mr)
			var pad := Control.new()
			pad.custom_minimum_size.x = 24
			mr.add_child(pad)
			var have: Array = a.parts.get(g, [])
			var on: Array = a.mounts.get(g, [])
			for m in sp.mounts:
				var at: Dictionary = ArmsDB.ATTACHMENTS[m]
				var b: Button
				if m in have:
					b = _btn(("◆ " if m in on else "") + at.name, func(): _fit(g, m), 16, GOLD if m in on else PALE)
				else:
					b = _arms_btn("Make %s" % at.name, WArms.PARTS[m], bench, func():
						if not a.parts.has(g):
							a.parts[g] = []
						a.parts[g].append(m)
						_fit(g, m, false))
					b.add_theme_font_size_override("font_size", 16)
				b.tooltip_text = "%s: %s" % [ArmsDB.SLOT_NAMES[at.slot], at.text]
				mr.add_child(b)
		v.add_child(HSeparator.new())
	for k in WArms.KINDS:
		var tb := WArms.table(k[0])
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 18)
		v.add_child(hb)
		var head := _label(k[2], 20, GOLD)
		head.custom_minimum_size.x = 90
		hb.add_child(head)
		for id in tb:
			var b: Button
			if id in a[k[0]]:
				var on: bool = a[k[1]] == id
				b = _btn(("◆ " if on else "") + tb[id].name, func(): a[k[1]] = id; w.rearm(); _redraw(), 17, GOLD if on else PALE)
			else:
				b = _arms_btn("Make %s" % tb[id].name, WArms.MAKE[id], bench, func(): a[k[0]].append(id); a[k[1]] = id)
			b.tooltip_text = _waste_text(tb[id].text)
			hb.add_child(b)
	var rb := HBoxContainer.new()
	rb.add_theme_constant_override("separation", 18)
	v.add_child(rb)
	var rhead := _label("Relics", 20, GOLD)
	rhead.custom_minimum_size.x = 90
	rb.add_child(rhead)
	for id in WArms.RELICS:
		var it: Dictionary = WArms.RELICS[id]
		var key := Game.key_text("slot_%d" % (7 if id == "claw" else 8))
		var b: Button
		if id in a.relics:
			b = _btn("◆ %s  [%s]" % [it.name, key], func(): pass, 17, GOLD)
		else:
			b = _arms_btn("Make %s" % it.name, it.cost, bench, func(): a.relics.append(id); w.player.relics.refresh())
		b.tooltip_text = it.text
		rb.add_child(b)
	v.add_child(HSeparator.new())
	var wn := WArms.worn(a)
	v.add_child(_label("Worn      turns aside %d%% of harm%s" % [int(round(wn.guard * 100.0)), "" if is_equal_approx(wn.speed, 1.0) else ",  stride ×%.2f" % wn.speed], 20, GOLD))
	for sl in WArms.WEAR_SLOTS:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 18)
		v.add_child(hb)
		var head := _label(sl[1], 18, GOLD)
		head.custom_minimum_size.x = 90
		hb.add_child(head)
		var on := str(a.wear.get(sl[0], ""))
		for id in WArms.WEAR:
			var it: Dictionary = WArms.WEAR[id]
			if it.slot != sl[0]:
				continue
			var b: Button
			if id == on:
				b = _btn("◆ " + it.name, func(): _unwear(sl[0]), 17, GOLD)
			elif w.inv.count(id) > 0:
				b = _btn(it.name, func(): _wear(id), 17, PALE)
			else:
				b = _arms_btn("Make %s" % it.name, it.cost, bench, func(): w.give([[id, 1]]))
				b.add_theme_font_size_override("font_size", 16)
			b.tooltip_text = "%s  Turns aside %d%% of harm." % [it.text, int(round(float(it.guard) * 100.0))]
			hb.add_child(b)
	v.add_child(HSeparator.new())
	var any := false
	for g in ArmsDB.GUNS:
		if g in a.owned:
			continue
		if not any:
			v.add_child(_label("Guns to make", 20, GOLD))
			any = true
		var b := _arms_btn("Make %s" % ArmsDB.GUNS[g].name, WArms.MAKE[g], bench, func(): a.owned.append(g); a[ArmsDB.GUNS[g].slot] = g)
		b.tooltip_text = _waste_text(ArmsDB.GUNS[g].text)
		v.add_child(b)


## Puts a thing on from the pack; what was worn there goes back into the pack.
func _wear(id: String) -> void:
	var slot: String = WArms.WEAR[id].slot
	if w.inv.take(id, 1) < 1:
		return
	var old := str(w.arms.wear.get(slot, ""))
	w.arms.wear[slot] = id
	if old != "":
		w.give([[old, 1]])
	w.sfx("cloth" if false else "carve", -10)
	w.rearm()
	_redraw()


func _unwear(slot: String) -> void:
	var old := str(w.arms.wear.get(slot, ""))
	if old == "" or not w.inv.room_for(old, 1):
		return
	w.arms.wear.erase(slot)
	w.give([[old, 1]])
	w.rearm()
	_redraw()


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


func _slot_grid(bag: Inventory, cb: Callable, cols := 6, sel := -1) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for i in bag.slots.size():
		var s = bag.slots[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(170 if cols == 6 else 128, 58)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 16)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.04)
		sb.border_color = Color(1, 1, 1, 0.08)
		sb.set_border_width_all(1)
		if s != null:
			var c: Color = Items.info(s.id).color
			sb.border_color = Color(c, 0.6)
			sb.border_width_left = 4
			b.text = "%s\n× %d" % [Items.iname(s.id), int(s.n)]
			b.tooltip_text = Items.info(s.id).text
		if i == sel and s != null:
			sb.bg_color = Color(GOLD, 0.14)
			sb.border_color = GOLD
		b.add_theme_stylebox_override("normal", sb)
		var hs := sb.duplicate()
		hs.bg_color = Color(1, 1, 1, 0.1)
		b.add_theme_stylebox_override("hover", hs)
		b.add_theme_color_override("font_color", PALE)
		var idx := i
		b.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				cb.call(idx, ev.button_index == MOUSE_BUTTON_RIGHT))
		g.add_child(b)
	return g


func _pack_click(i: int, right: bool) -> void:
	var s = w.inv.slots[i]
	if s == null:
		_sel = -1
		_redraw()
		return
	if right:
		_drop(i, int(s.n))
		return
	_sel = i
	_redraw()


func _draw_craft() -> void:
	var bench: bool = debug_bench or w.builder.near_kind(w.player.global_position, "bench", 5.0)
	var pot: int = w.builder.near_pid(w.player.global_position, "cookpot", 5.0)
	var fire: bool = (pot >= 0 and w.burning(pot)) or w.settlement_at(w.player.global_position) != ""
	var where: Array = []
	if bench:
		where.append("a workbench")
	if fire:
		where.append("a cooking station")
	_body.add_child(_label(("At " + " and ".join(where) + ".") if not where.is_empty() else "With your hands. A workbench or a cooking station close by lets you make more.", 16, DIM))
	if pot >= 0:
		_body.add_child(_fuel_row(pot))
	var v := _scroll(520)
	for r in Items.RECIPES:
		if r.has("needs") and not w.flags.has(r.needs):
			continue
		var cost: Dictionary = w.skills.cost(r.cost)
		var ok: bool = w.inv.has_all(cost) and (bench or not r.bench) and (fire or not r.get("fire", false))
		var t := "Make %d %s      %s%s" % [r.n + w.skills.make_bonus(r.id), Items.iname(r.id), Items.cost_text(cost), "      (workbench)" if r.bench else ("      (cooking station)" if r.get("fire", false) else "")]
		var b := _btn(t, func(): _make(r), 20, PALE if ok else DIM)
		b.disabled = not ok
		b.tooltip_text = Items.info(r.id).text
		v.add_child(b)


func _make(r: Dictionary) -> void:
	if not w.inv.pay(w.skills.cost(r.cost)):
		return
	w.sfx("carve", -6)
	w.give([[r.id, int(r.n) + w.skills.make_bonus(r.id)]])
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
		else:
			_redraw()


func _draw_container() -> void:
	_clear()
	if not w.containers.has(_cont_id):
		_body.add_child(_label("...", 20, DIM))
		return
	var name := "Chest" if _cont_id.begins_with("p") else ("Satchel" if _cont_id.begins_with("s") else "Searched")
	_body.add_child(_title(name))
	_body.add_child(_label("Click on either side to move a thing across.", 16, DIM))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	var bag := Inventory.new(w.containers[_cont_id].size())
	bag.from_data(w.containers[_cont_id])
	var left := VBoxContainer.new()
	left.add_child(_label("Here", 20, GOLD))
	left.add_child(_slot_grid(bag, func(i, _r): w.shared("_rq_take", [Net.me(), _cont_id, i]), 4))
	hb.add_child(left)
	var right := VBoxContainer.new()
	right.add_child(_label("Your pack", 20, GOLD))
	right.add_child(_slot_grid(w.inv, func(i, _r): _put(i), 4))
	hb.add_child(right)
	_body.add_child(hb)
	_body.add_child(_btn("Take everything", func(): _take_all(), 20, PALE))


func _put(i: int) -> void:
	if _cont_id.begins_with("c") or not (_cont_id.begins_with("p") or _cont_id.begins_with("s")):
		pass
	var it = w.inv.take_slot(i)
	if it == null:
		return
	w.shared("_rq_put", [Net.me(), _cont_id, it.id, int(it.n)])


func _take_all() -> void:
	var data: Array = w.containers.get(_cont_id, [])
	for i in data.size():
		if data[i] != null:
			w.shared("_rq_take", [Net.me(), _cont_id, i])


# ------------------------------------------------------------------ talk and trade

func open_dialogue(pid: String) -> void:
	_talking = pid
	_panel_name = "talk"
	_open("talk")
	var pd: Dictionary = WPlaces.PEOPLE[pid]
	_talk(pd.greet)


func _talk(text: String) -> void:
	_clear()
	var pd: Dictionary = WPlaces.PEOPLE[_talking]
	_body.add_child(_title(pd.name))
	_body.add_child(_label(pd.title + ("   ·   Standing: %d" % int(w.rep.get(pd.at, 0)) if int(w.rep.get(pd.at, 0)) > 0 else ""), 18, DIM))
	var say := _wrap(WPlaces.words(text), 21, PALE)
	say.custom_minimum_size = Vector2(1060, 0)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 330)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(say)
	_body.add_child(sc)
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 2)
	for o in w.quests.talk_options(_talking):
		var cb: Callable = o[1]
		opts.add_child(_btn("» " + o[0], func(): _talk(cb.call()), 20, GOLD))
	opts.add_child(_btn("Have you any work for me?", func(): _offers(), 20))
	opts.add_child(_btn("Tell me about yourself.", func(): _talk(pd.about), 20))
	opts.add_child(_btn("What news on the road?", func(): _rumor(), 20))
	if Items.STOCK.has(pd.role):
		opts.add_child(_btn("Let us trade.", func(): _trade(), 20))
	opts.add_child(_btn("Farewell.", close_all, 20))
	_body.add_child(opts)


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
	_body.add_child(_title(pd.name))
	var list: Array = w.quests.offers_from(_talking)
	var v := _scroll(470)
	if list.is_empty():
		v.add_child(_wrap("\"Nothing today. Come back after the dawn; there is always something after the dawn.\"", 21, PALE))
	for o in list:
		v.add_child(_label(o.title, 24, GOLD))
		v.add_child(_wrap("\"%s\"" % WPlaces.words(o.pitch), 20, PALE))
		var r: Dictionary = o.reward
		var rw := "%d salt" % int(r.salt)
		for it in r.get("items", []):
			rw += ", %d %s" % [int(it[1]), Items.iname(it[0])]
		v.add_child(_label("Reward: " + rw, 17, DIM))
		v.add_child(_btn("I will do it.", func(): w.quests.accept(o); _talk("\"Go carefully. Come back.\""), 20, PALE))
		v.add_child(HSeparator.new())
	_body.add_child(_btn("Back", func(): _talk(pd.greet), 20))


func _discount(at: String) -> float:
	return minf(0.3, int(w.rep.get(at, 0)) / 3 * 0.1)


func buy_price(id: String, at: String) -> int:
	return maxi(1, ceili(Items.info(id).value * 2.0 * (1.0 - _discount(at)) * w.skills.buy_mult()))


func sell_price(id: String) -> int:
	var info: Dictionary = Items.info(id)
	if info.kind == "quest" or id == "salt":
		return 0
	return maxi(1, int(info.value * (1.0 if info.kind == "trinket" else 0.6) * w.skills.sell_mult()))


func _trade() -> void:
	_clear()
	var pd: Dictionary = WPlaces.PEOPLE[_talking]
	_body.add_child(_title("Trade with %s" % pd.name))
	_body.add_child(_label("You carry %d salt. Better standing with %s brings better prices." % [w.inv.count("salt"), WPlaces.SETTLEMENTS[pd.at].name], 17, DIM))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 40)
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_label("Buy", 22, GOLD))
	for id in Items.STOCK[pd.role]:
		if id == "beacon_oil" and not w.flags.has("oilcraft"):
			continue
		var price := buy_price(id, pd.at)
		var n := 10 if id in ["shells", "rounds", "rifle"] else 1
		var ok: bool = w.inv.count("salt") >= price * n
		var cost := price * n
		var b := _btn("%s%s   %d salt" % [Items.iname(id), " ×10" if n > 1 else "", cost], func(): _buy(id, n, cost), 19, PALE if ok else DIM)
		b.disabled = w.inv.count("salt") < cost
		b.tooltip_text = Items.info(id).text
		left.add_child(b)
	hb.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_label("Sell (one at a time)", 22, GOLD))
	var seen := {}
	for s in w.inv.slots:
		if s == null or seen.has(s.id) or sell_price(s.id) <= 0:
			continue
		seen[s.id] = true
		var id: String = s.id
		right.add_child(_btn("%s ×%d   %d salt each" % [Items.iname(id), w.inv.count(id), sell_price(id)], func(): _sell(id), 19, PALE))
	hb.add_child(right)
	_body.add_child(hb)
	_body.add_child(_btn("Back", func(): _talk(pd.greet), 20))


func _buy(id: String, n: int, cost: int) -> void:
	if w.inv.count("salt") < cost:
		return
	w.inv.take("salt", cost)
	w.give([[id, n]])
	w.sfx("shell", -8)
	_trade()


func _sell(id: String) -> void:
	if w.inv.take(id, 1) < 1:
		return
	w.give([["salt", sell_price(id)]])
	w.sfx("shell", -8)
	_trade()


# ------------------------------------------------------------------ the journal

func open_journal() -> void:
	_open("journal")


func _draw_journal() -> void:
	_clear()
	_body.add_child(_title("Journal"))
	_body.add_child(_label("Click a task to follow it on the compass. %d beacons of 9 burn. %d nights survived." % [w.lit.size(), w.nights], 16, DIM))
	var v := _scroll(560)
	var list: Array = w.quests.active()
	if list.is_empty():
		v.add_child(_wrap("Nothing is asked of you. Ask in the settlements; there is always work.", 20, DIM))
	for q in list:
		var tracked: bool = w.quests.tracked == q.id
		var head: String = ("◆ " if tracked else "") + q.title + ("   (the beacon road)" if q.get("main", false) else "")
		v.add_child(_btn(head, func(): w.quests.tracked = q.id; w.quests.refresh_hud(); journal_dirty = true, 23, GOLD if tracked else PALE))
		v.add_child(_wrap(w.quests.step_text(q), 19, PALE if tracked else DIM))
		var r: Dictionary = q.get("reward", {})
		if int(r.get("salt", 0)) > 0:
			var rw := "%d salt" % int(r.salt)
			for it in r.get("items", []):
				rw += ", %d %s" % [int(it[1]), Items.iname(it[0])]
			v.add_child(_label("Reward: " + rw, 15, DIM))
		v.add_child(HSeparator.new())


# ------------------------------------------------------------------ the map

func open_map() -> void:
	_open("map")


func _draw_map() -> void:
	_clear()
	if _map_tex == null:
		_map_tex = ImageTexture.create_from_image(w.terrain.map_image(640))
		_fog_img = Image.create(Wasteland.REVEAL_N, Wasteland.REVEAL_N, false, Image.FORMAT_RGBA8)
		_fog_tex = ImageTexture.create_from_image(_fog_img)
		map_dirty = true
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(640, 640)
	var tr := TextureRect.new()
	tr.texture = _map_tex
	tr.size = Vector2(640, 640)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	holder.add_child(tr)
	var fog := TextureRect.new()
	fog.texture = _fog_tex
	fog.size = Vector2(640, 640)
	fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog.stretch_mode = TextureRect.STRETCH_SCALE
	fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	holder.add_child(fog)
	_map_draw = MapDraw.new()
	_map_draw.w = w
	_map_draw.size = Vector2(640, 640)
	holder.add_child(_map_draw)
	hb.add_child(holder)
	var side := VBoxContainer.new()
	side.add_child(_title("The Ashen Waste"))
	side.add_child(_wrap("Seed %d. Day %d. %d of 9 beacons burn.\n\n◆ your task    ● settlement    ▲ beacon (bright when burning)    ■ ruin    ✶ lair of a great one    + your bed    ✕ what you left when you fell" % [w.world_seed, w.day, w.lit.size()], 17, DIM))
	if not w.quests.tracked.is_empty() and w.quests.quests.has(w.quests.tracked):
		var q: Dictionary = w.quests.quests[w.quests.tracked]
		side.add_child(_label("", 10, DIM))
		side.add_child(_label(q.title, 22, GOLD))
		side.add_child(_wrap(w.quests.step_text(q), 18, PALE))
	hb.add_child(side)
	_body.add_child(hb)
	_update_fog()


func _update_fog() -> void:
	if _fog_img == null:
		return
	map_dirty = false
	var n: int = Wasteland.REVEAL_N
	for j in n:
		for i in n:
			_fog_img.set_pixel(i, j, Color(0.03, 0.028, 0.025, 0.0 if w.revealed[j * n + i] != 0 else 0.93))
	_fog_tex.update(_fog_img)


# ------------------------------------------------------------------ the beacon road, and rest

func open_travel() -> void:
	_open("travel")


func _draw_travel() -> void:
	_clear()
	_body.add_child(_title("The Beacon Road"))
	_body.add_child(_wrap("The burning beacons see one another across the waste. Walk the road of their light to any of them.", 19, DIM))
	for i in w.lit:
		var b: Dictionary = WPlaces.BEACONS[i]
		_body.add_child(_btn(b.name, func(): _travel(i), 22, PALE))
	_body.add_child(_btn("Stay here", close_all, 20))


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
	var b := _btn("Add wood (have %d)" % w.inv.count("wood"), func(): w.add_wood(pid); _redraw(), 18, PALE)
	b.disabled = w.inv.count("wood") <= 0 or left > Wasteland.FUEL_MAX - Wasteland.WOOD_HOURS
	b.tooltip_text = "Each piece of wood burns for a day."
	hb.add_child(b)
	return hb


func ask_rest(kind := "fire", pid := -1) -> void:
	_rest_kind = kind
	_rest_pid = pid
	_open("rest")
	_draw_rest()


func _draw_rest() -> void:
	_clear()
	_body.add_child(_title("The Fire" if _rest_kind == "fire" else "The Bedroll"))
	_body.add_child(_label("Food %d     Rest %d" % [int(w.food), int(w.rest)], 18, DIM))
	if _rest_kind == "bed":
		_body.add_child(_wrap("You will wake here if you fall.", 18, DIM))
	if _rest_kind == "fire" and _rest_pid >= 0:
		_body.add_child(_fuel_row(_rest_pid))
		if not w.burning(_rest_pid):
			_body.add_child(_wrap("Light it with wood before you rest. A cold camp keeps nothing away.", 20, PALE))
			_body.add_child(_btn("Not now", close_all, 20))
			return
	var near := 0
	for e in w.enemies:
		if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(w.player.global_position) < 40.0:
			near += 1
	if near > 0:
		_body.add_child(_wrap("You cannot rest with forms so close.", 20, PALE))
	elif w.night:
		var t := "Sleep until dawn?" if not Net.online else "Sleep until dawn? Everyone must lie down by a fire or a bedroll before the night passes."
		_body.add_child(_wrap(t, 20, PALE))
		if w._my_vote:
			_body.add_child(_btn("Get up", func(): w.vote_sleep(false); _draw_rest(), 22, PALE))
		else:
			_body.add_child(_btn("Sleep until dawn", func(): w.vote_sleep(true); _draw_rest(), 22, PALE))
		_vote_label = _label("", 18, GOLD)
		_body.add_child(_vote_label)
	else:
		_body.add_child(_wrap("It is day. A short sleep will leave you rested.", 20, PALE))
		_body.add_child(_btn("Sleep a while", func(): close_all(); w.nap(), 22, PALE))
	_body.add_child(_btn("Not now", close_all, 20))


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
	_body.add_child(_title("Planter Box"))
	var pc: Dictionary = w.pieces.get(_pid, {})
	if pc.is_empty():
		return
	if pc.crop == "":
		_body.add_child(_wrap("The soil is turned and waiting. What will you plant?", 20, PALE))
		var any := false
		for id in Items.DB:
			if Items.info(id).kind == "seed" and w.inv.count(id) > 0:
				any = true
				var b := _btn("Plant %s  (you have %d)" % [Items.iname(id), w.inv.count(id)], func():
					if w.inv.take(id, 1) == 1:
						w.shared("_rq_plant", [Net.me(), _pid, id]), 20, PALE)
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
			_body.add_child(_btn("Harvest", func(): w.shared("_rq_harvest", [Net.me(), _pid]), 22, GOLD))
	_body.add_child(_btn("Close", close_all, 20))


# ------------------------------------------------------------------ the waystone

func open_portal(pid: int) -> void:
	_pid = pid
	_open("portal")


func _draw_portal() -> void:
	_clear()
	_body.add_child(_title("Waystone"))
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
	hb.add_child(_btn("Name it", save, 20, PALE))
	_body.add_child(hb)
	var to: int = w.portal_pair(_pid)
	if to >= 0:
		var d := int(pc.pos.distance_to(w.pieces[to].pos))
		_body.add_child(_btn("Step through  (%d m)" % d, func(): close_all(); w.step_through(_pid), 22, GOLD))
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
	_body.add_child(_btn("Close", close_all, 20))


# ------------------------------------------------------------------ the build guide

func _draw_build_guide() -> void:
	_body.add_child(_label("Press %s to build. The wheel chooses a piece, %s turns it, the aim key takes one down for half its cost." % [Game.key_text("build"), Game.key_text("reload")], 16, DIM))
	var v := _scroll(540)
	for g in Items.GROUPS:
		v.add_child(_label(g, 22, GOLD))
		for k in Items.PIECE_ORDER:
			var pc: Dictionary = Items.PIECES[k]
			if pc.group != g:
				continue
			var cost: Dictionary = w.skills.cost(pc.cost)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 16)
			var nm := _label(pc.name, 19, PALE if w.inv.has_all(cost) else DIM)
			nm.custom_minimum_size.x = 190
			hb.add_child(nm)
			var rt := RichTextLabel.new()
			rt.bbcode_enabled = true
			rt.fit_content = true
			rt.scroll_active = false
			rt.autowrap_mode = TextServer.AUTOWRAP_OFF
			rt.custom_minimum_size = Vector2(330, 24)
			rt.add_theme_font_size_override("normal_font_size", 16)
			rt.text = cost_bb(cost)
			hb.add_child(rt)
			var t := _label(pc.text, 15, DIM)
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(t)
			v.add_child(hb)


## A cost with what is carried beside each part: pale when there is enough, red when not.
func cost_bb(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		var have: int = w.inv.count(k)
		var need := int(cost[k])
		var c := "#e9e4d6" if have >= need else "#d0665a"
		parts.append("[color=%s]%s %d/%d[/color]" % [c, Items.iname(k), have, need])
	return "   ".join(parts)


# ================================================================== drawn things

class Compass extends Control:
	var w

	func _draw() -> void:
		if w == null or w.player == null:
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

	func _to(p: Vector3) -> Vector2:
		return Vector2((p.x + WPlaces.HALF) / WPlaces.SIZE, (p.z + WPlaces.HALF) / WPlaces.SIZE) * size

	func _draw() -> void:
		if w == null or w.player == null:
			return
		var font := ThemeDB.fallback_font
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
		var me := _to(w.player.global_position)
		var f: Vector3 = -w.player.global_transform.basis.z
		var dir := Vector2(f.x, f.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([me + dir * 10.0, me - dir * 6.0 + side * 6.0, me - dir * 6.0 - side * 6.0]), Color(1, 1, 1))
