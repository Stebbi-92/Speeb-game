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
var _build_hint: Label
var _keys: Label
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
	_build_hint = _label("", 17, DIM)
	_pin(_build_hint, 0.5, 1.0, Rect2(-500, -116, 1000, 28))
	_build_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_build_hint)
	_keys = _label("[I] Pack    [M] Map    [J] Journal    [B] Build", 15, Color(DIM, 0.7))
	_pin(_keys, 0.0, 1.0, Rect2(36, -100, 600, 24))
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
		match k:
			KEY_I, KEY_TAB:
				if _panel != null and _panel_name == "pack":
					close_all()
				else:
					open_inventory("pack")
				accept_event()
			KEY_M:
				if _panel_name == "map":
					close_all()
				else:
					open_map()
				accept_event()
			KEY_J:
				if _panel_name == "journal":
					close_all()
				else:
					open_journal()
				accept_event()
			KEY_B:
				if _panel == null:
					w.builder.toggle()
					w.player.set_armed(not w.builder.active)
				accept_event()
			KEY_R:
				if w.builder.active and _panel == null:
					w.builder.turn()
					accept_event()
	if e is InputEventMouseButton and e.pressed and w.builder.active and _panel == null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		match e.button_index:
			MOUSE_BUTTON_LEFT:
				w.builder.place()
			MOUSE_BUTTON_RIGHT:
				w.builder.dismantle()
			MOUSE_BUTTON_WHEEL_UP:
				w.builder.choose(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
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
	if _panel_name == "journal" and journal_dirty:
		journal_dirty = false
		_draw_journal()
	if _panel_name == "map" and _map_draw:
		_map_draw.queue_redraw()
		if map_dirty:
			_update_fog()


func set_build_bar(t: String, hint: String) -> void:
	_build_title.text = t
	_build_hint.text = hint


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
	var info := _label("Shells on the belt: %d     Salt: %d" % [w.player.weapon.reserve + w.player.weapon.shells, w.inv.count("salt")], 18, DIM)
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
	_body.add_child(_label("Click to use or look closer. Right click to drop.", 16, DIM))
	_body.add_child(_slot_grid(w.inv, func(i, right): _pack_click(i, right)))
	_desc = _wrap("", 18, DIM)
	_body.add_child(_desc)


func _slot_grid(bag: Inventory, cb: Callable, cols := 6) -> GridContainer:
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
		return
	if right:
		var it = w.inv.take_slot(i)
		var fwd: Vector3 = -w.player.global_transform.basis.z
		w.shared("_rq_satchel", [Net.me(), w.player.global_position + fwd * 1.2, [[it.id, int(it.n)]], false])
		w.hud.notify("Dropped %s." % Items.iname(it.id))
		return
	var info: Dictionary = Items.info(s.id)
	if info.kind in ["food", "medicine"]:
		if w.player.health >= w.player.max_health - 0.5:
			_desc.text = "You are not hurt."
			return
		w.inv.take(s.id, 1)
		w.player.health = minf(w.player.max_health, w.player.health + float(info.heal))
		w.hud.set_health(w.player.health / w.player.max_health, true)
		w.sfx("drink", -6)
		return
	_desc.text = "%s. %s  (Worth %d salt.)" % [info.name, info.text, int(info.value)]


func _draw_craft() -> void:
	var bench: bool = w.builder.near_kind(w.player.global_position, "bench", 5.0)
	_body.add_child(_label("At a workbench" if bench else "With your hands. A workbench close by lets you make more.", 16, DIM))
	var v := _scroll(520)
	for r in Items.RECIPES:
		if r.has("needs") and not w.flags.has(r.needs):
			continue
		var ok: bool = w.inv.has_all(r.cost) and (bench or not r.bench)
		var t := "Make %d %s      %s%s" % [r.n, Items.iname(r.id), Items.cost_text(r.cost), "      (workbench)" if r.bench else ""]
		var b := _btn(t, func(): _make(r), 20, PALE if ok else DIM)
		b.disabled = not ok
		b.tooltip_text = Items.info(r.id).text
		v.add_child(b)


func _make(r: Dictionary) -> void:
	if not w.inv.pay(r.cost):
		return
	w.sfx("carve", -6)
	w.give([[r.id, int(r.n)]])
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
	var say := _wrap(text, 21, PALE)
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
	var home: Vector2 = WPlaces.SETTLEMENTS[pd.at].pos
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
		v.add_child(_wrap("\"%s\"" % o.pitch, 20, PALE))
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
	return maxi(1, ceili(Items.info(id).value * 2.0 * (1.0 - _discount(at))))


func sell_price(id: String) -> int:
	var info: Dictionary = Items.info(id)
	if info.kind == "quest" or id == "salt":
		return 0
	return maxi(1, int(info.value * (1.0 if info.kind == "trinket" else 0.6)))


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
		var price := buy_price(id, pd.at) * (1 if id != "shells" else 1)
		var n := 10 if id == "shells" else 1
		var ok: bool = w.inv.count("salt") >= price * (n if id == "shells" else 1)
		var cost := price * n if id == "shells" else price
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
		_map_tex = ImageTexture.create_from_image(w.terrain.map_image(512))
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
	side.add_child(_wrap("Day %d. %d of 9 beacons burn.\n\n◆ your task    ● settlement    ▲ beacon (bright when burning)    ■ ruin    + your bed    ✕ what you left when you fell" % [w.day, w.lit.size()], 17, DIM))
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


func ask_rest() -> void:
	_open("rest")
	_clear()
	_body.add_child(_title("The Fire"))
	if Net.online:
		_body.add_child(_wrap("You warm your hands. The fellowship cannot all sleep at once; someone must keep watch.", 20, PALE))
	elif not w.night:
		_body.add_child(_wrap("You warm your hands by the fire. It is not yet night; there is work to do while the light holds.", 20, PALE))
	else:
		var near := 0
		for e in w.enemies:
			if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(w.player.global_position) < 50.0:
				near += 1
		if near > 0:
			_body.add_child(_wrap("You cannot rest with forms so close.", 20, PALE))
		else:
			_body.add_child(_wrap("Sleep by the fire until dawn? What is built around you will have to hold on its own.", 20, PALE))
			_body.add_child(_btn("Sleep until dawn", func(): _sleep(), 22, PALE))
	_body.add_child(_btn("Not now", close_all, 20))


func _sleep() -> void:
	close_all()
	w.player.input_locked = true
	await w.hud.fade_to(1.0, 1.5)
	w.clock = Wasteland.DAWN - 0.02
	await get_tree().create_timer(1.5).timeout
	w.player.health = w.player.max_health
	w.hud.set_health(1.0, true)
	await w.hud.fade_to(0.0, 2.0)
	w.player.input_locked = false


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
			marks.append([w.gpos(WPlaces.SETTLEMENTS[k].pos), Color(0.8, 0.6, 0.4, 0.7), 4.0])
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
			if r > 5.0:
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
		for k in WPlaces.SETTLEMENTS:
			var s: Dictionary = WPlaces.SETTLEMENTS[k]
			var p3: Vector3 = w.gpos(s.pos)
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
				draw_circle(_to(a.global_position), 5.0, Net.color_of(id))
		var me := _to(w.player.global_position)
		var f: Vector3 = -w.player.global_transform.basis.z
		var dir := Vector2(f.x, f.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([me + dir * 10.0, me - dir * 6.0 + side * 6.0, me - dir * 6.0 - side * 6.0]), Color(1, 1, 1))
