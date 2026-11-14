extends CanvasLayer
## Everything drawn over the world: fades, title cards, scripture, prompts, meters, the pause menu and the Book of Emojis.

const GOLD := Color(0.86, 0.80, 0.66)
const PALE := Color(0.93, 0.92, 0.88)
const DIM := Color(0.62, 0.60, 0.56)

var serif: FontFile
var title_font: FontFile
var root: Control
var overlay: ColorRect
var fade: ColorRect
var card_num: Label
var card_place: Label
var card_box: VBoxContainer
var narration: Label
var prompt: Label
var prompt_bar: ProgressBar
var objective: Label
var meter_box: VBoxContainer
var meter_label: Label
var meter: ProgressBar
var toast: Label
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var crosshair: ColorRect
var reveal_box: VBoxContainer
var reveal_num: Label
var reveal_epithet: Label
var reveal_decree: Label
var reveal_text: Label
var reveal_hint: Label
var name_label: Label
var pause_panel: Control
var options_panel: Control
var _options_list: VBoxContainer
var codex_panel: Control
var codex_list: VBoxContainer
var codex_count: Label
var menu_box: Control
var ammo_label: Label
var kit_label: Label
var scope_view: Control
var health_bar: ProgressBar
var hotbar: Hotbar
var streak_label: Label
var _deed_box: PanelContainer
var _deed_title: Label
var _deed_text: Label
var _deed_queue: Array = []
var _deed_busy := false
var results_panel: ColorRect
var relic_hint: Label
var _hurt := 0.0

var _narr_id := 0
var _toast_id := 0
var overlay_mat: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	serif = load("res://assets/fonts/SourceSerif4.ttf")
	title_font = load("res://assets/fonts/Marcellus-Regular.ttf")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = serif
	th.default_font_size = 24
	root.theme = th
	add_child(root)

	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = load("res://scripts/overlay.gdshader")
	overlay.material = overlay_mat
	root.add_child(overlay)

	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.45)
	crosshair.size = Vector2(4, 4)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-2, -2)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	prompt = _label("", 22, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.position = Vector2(-400, 60)
	prompt.size = Vector2(800, 40)
	prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	prompt.add_theme_constant_override("shadow_offset_x", 1)
	prompt.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(prompt)
	prompt_bar = ProgressBar.new()
	prompt_bar.show_percentage = false
	prompt_bar.set_anchors_preset(Control.PRESET_CENTER)
	prompt_bar.position = Vector2(-120, 104)
	prompt_bar.size = Vector2(240, 6)
	prompt_bar.max_value = 1.0
	prompt_bar.add_theme_stylebox_override("background", _flat(Color(1, 1, 1, 0.15)))
	prompt_bar.add_theme_stylebox_override("fill", _flat(GOLD))
	prompt_bar.visible = false
	root.add_child(prompt_bar)

	narration = _label("", 26, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narration.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	narration.position = Vector2(-560, -190)
	narration.size = Vector2(1120, 150)
	narration.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	narration.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	narration.add_theme_constant_override("shadow_offset_x", 2)
	narration.add_theme_constant_override("shadow_offset_y", 2)
	narration.modulate.a = 0
	root.add_child(narration)

	objective = _label("", 20, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	objective.position = Vector2(36, 30)
	objective.size = Vector2(700, 80)
	objective.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	objective.add_theme_constant_override("shadow_offset_x", 1)
	objective.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(objective)

	name_label = _label("", 18, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	name_label.add_theme_font_override("font", title_font)
	name_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	name_label.position = Vector2(-436, 30)
	name_label.size = Vector2(400, 30)
	root.add_child(name_label)

	meter_box = VBoxContainer.new()
	meter_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	meter_box.position = Vector2(-160, 34)
	meter_box.size = Vector2(320, 40)
	meter_box.visible = false
	root.add_child(meter_box)
	meter_label = _label("", 18, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	meter_label.add_theme_font_override("font", title_font)
	meter_box.add_child(meter_label)
	meter = ProgressBar.new()
	meter.show_percentage = false
	meter.custom_minimum_size = Vector2(320, 5)
	meter.max_value = 1.0
	meter.add_theme_stylebox_override("background", _flat(Color(1, 1, 1, 0.12)))
	meter.add_theme_stylebox_override("fill", _flat(PALE))
	meter_box.add_child(meter)

	toast = _label("", 20, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toast.position = Vector2(-536, 96)
	toast.size = Vector2(500, 120)
	toast.modulate.a = 0
	root.add_child(toast)
	_build_boss_bar()

	card_box = VBoxContainer.new()
	card_box.set_anchors_preset(Control.PRESET_CENTER)
	card_box.position = Vector2(-600, -120)
	card_box.size = Vector2(1200, 200)
	card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card_box.modulate.a = 0
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card_box)
	card_num = _label("", 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	card_num.add_theme_font_override("font", title_font)
	card_box.add_child(card_num)
	card_place = _label("", 56, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	card_place.add_theme_font_override("font", title_font)
	card_box.add_child(card_place)

	reveal_box = VBoxContainer.new()
	reveal_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	reveal_box.position = Vector2(-620, -330)
	reveal_box.size = Vector2(1240, 310)
	reveal_box.alignment = BoxContainer.ALIGNMENT_END
	reveal_box.add_theme_constant_override("separation", 6)
	reveal_box.modulate.a = 0
	reveal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reveal_box)
	reveal_num = _label("", 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	reveal_num.add_theme_font_override("font", title_font)
	reveal_box.add_child(reveal_num)
	reveal_epithet = _label("", 42, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	reveal_epithet.add_theme_font_override("font", title_font)
	reveal_box.add_child(reveal_epithet)
	reveal_decree = _label("", 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	reveal_decree.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reveal_box.add_child(reveal_decree)
	reveal_text = _label("", 20, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	reveal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reveal_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	reveal_text.add_theme_constant_override("shadow_offset_x", 2)
	reveal_text.add_theme_constant_override("shadow_offset_y", 2)
	reveal_box.add_child(reveal_text)
	reveal_hint = _label("", 18, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	reveal_box.add_child(reveal_hint)
	for l in [reveal_decree, reveal_text, reveal_epithet, reveal_num]:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)

	ammo_label = _label("", 30, PALE, HORIZONTAL_ALIGNMENT_RIGHT)
	ammo_label.add_theme_font_override("font", title_font)
	ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.position = Vector2(-336, -76)
	ammo_label.size = Vector2(300, 44)
	ammo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	ammo_label.add_theme_constant_override("shadow_offset_x", 2)
	ammo_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(ammo_label)
	kit_label = _label("", 15, Color(PALE, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
	kit_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	kit_label.position = Vector2(-636, -30)
	kit_label.size = Vector2(600, 24)
	root.add_child(kit_label)
	scope_view = ScopeView.new()
	scope_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_view.visible = false
	root.add_child(scope_view)
	root.move_child(scope_view, 0)
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_bar.position = Vector2(36, -50)
	health_bar.size = Vector2(260, 7)
	health_bar.max_value = 1.0
	health_bar.value = 1.0
	health_bar.add_theme_stylebox_override("background", _flat(Color(1, 1, 1, 0.15)))
	health_bar.add_theme_stylebox_override("fill", _flat(Color(0.75, 0.2, 0.15)))
	health_bar.visible = false
	root.add_child(health_bar)
	hotbar = Hotbar.new()
	hotbar.font = title_font
	hotbar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hotbar.position = Vector2(-36 - Hotbar.W * 6, -182)
	hotbar.size = Vector2(Hotbar.W * 6, Hotbar.W + 24)
	hotbar.visible = false
	root.add_child(hotbar)
	relic_hint = _label("", 18, PALE, HORIZONTAL_ALIGNMENT_RIGHT)
	relic_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	relic_hint.position = Vector2(-736, -216)
	relic_hint.size = Vector2(700, 30)
	relic_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	relic_hint.add_theme_constant_override("shadow_offset_x", 1)
	relic_hint.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(relic_hint)
	streak_label = _label("", 34, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	streak_label.add_theme_font_override("font", title_font)
	streak_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	streak_label.position = Vector2(-460, -150)
	streak_label.size = Vector2(420, 90)
	streak_label.pivot_offset = Vector2(420, 45)
	streak_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	streak_label.add_theme_constant_override("shadow_offset_x", 2)
	streak_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(streak_label)
	_build_deed()

	menu_box = Control.new()
	menu_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu_box)

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	_build_loading()

	_build_pause()
	_build_codex()
	_build_options()
	_build_results()


func _label(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _flat(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	return s


func button(text: String, cb: Callable, size := 28) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_override("font", title_font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", PALE)
	b.add_theme_color_override("font_focus_color", PALE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	# One look for every menu button: a quiet line of words that, under the pointer, gains a gold
	# mark at its left and a faint ground. The same margins in every state, so nothing jumps.
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = 14
	plain.content_margin_right = 14
	plain.content_margin_top = 2
	plain.content_margin_bottom = 2
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(GOLD, 0.07)
	lit.border_color = GOLD
	lit.border_width_left = 3
	lit.content_margin_left = 14
	lit.content_margin_right = 14
	lit.content_margin_top = 2
	lit.content_margin_bottom = 2
	var down := lit.duplicate()
	down.bg_color = Color(GOLD, 0.14)
	b.flat = false
	b.add_theme_stylebox_override("normal", plain)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("focus", lit)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("disabled", plain)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.45))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------- fades and text

func fade_to(alpha: float, dur := 1.0, color := Color.BLACK) -> void:
	fade.color = Color(color.r, color.g, color.b, fade.color.a)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, dur)
	await tw.finished


func title_card(num: String, place: String) -> void:
	card_num.text = num
	card_place.text = place
	var tw := create_tween()
	tw.tween_property(card_box, "modulate:a", 1.0, 2.0)
	tw.tween_interval(3.0)
	tw.tween_property(card_box, "modulate:a", 0.0, 2.0)
	await tw.finished


## A banner across the middle of the screen, for what must not be missed: a camp under attack.
func alert_banner(title: String, sub := "") -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(900, 0)
	box.position = Vector2(-450, -150)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.02, 0.02, 0.72)
	sb.border_color = Color(0.85, 0.3, 0.22, 0.8)
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.set_content_margin_all(14)
	band.add_theme_stylebox_override("panel", sb)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	band.add_child(v)
	var t := _label(title, 40, Color(1.0, 0.82, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", title_font)
	v.add_child(t)
	if sub != "":
		v.add_child(_label(sub, 18, Color(0.9, 0.82, 0.76), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(band)
	root.add_child(box)
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.4)
	tw.tween_interval(4.0)
	tw.tween_property(box, "modulate:a", 0.0, 1.2)
	tw.tween_callback(box.queue_free)


func say(text: String, dur := 6.0) -> void:
	if reveal_box.modulate.a > 0.05:
		return
	_narr_id += 1
	var id := _narr_id
	narration.text = text
	var tw := create_tween()
	tw.tween_property(narration, "modulate:a", 1.0, 0.8)
	await get_tree().create_timer(dur, false).timeout
	if id != _narr_id:
		return
	tw = create_tween()
	tw.tween_property(narration, "modulate:a", 0.0, 1.2)
	await tw.finished


func clear_say() -> void:
	_narr_id += 1
	narration.modulate.a = 0


func notify(text: String) -> void:
	_toast_id += 1
	var id := _toast_id
	toast.text = text
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.5)
	await get_tree().create_timer(5.0, false).timeout
	if id == _toast_id:
		create_tween().tween_property(toast, "modulate:a", 0.0, 1.5)


func set_prompt(text: String, progress: float) -> void:
	prompt.text = text
	prompt_bar.visible = text != "" and progress > 0.0
	prompt_bar.value = progress


func set_objective(text: String) -> void:
	objective.text = text


func set_meter(label: String, value: float) -> void:
	meter_box.visible = label != ""
	meter_label.text = label
	meter.value = value


func set_ammo(n: int, cap: int, reserve := 0) -> void:
	if n < 0:
		ammo_label.text = ""
		kit_label.text = ""
		return
	var s := ""
	if cap <= 12:
		for i in cap:
			s += "|" if i < n else "·"
		s += "   "
	ammo_label.text = s + "%d  /  %s" % [n, "∞" if reserve == -2 else str(reserve)]
	ammo_label.add_theme_color_override("font_color", PALE if reserve > 0 or n > 0 else Color(0.8, 0.3, 0.25))


var _marks: Marks


func _ensure_marks() -> void:
	if _marks == null:
		_marks = Marks.new()
		_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
		_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_marks)
		root.move_child(_marks, fade.get_index())


## Opens the choosing of arms over everything else.
func show_loadout() -> LoadoutUI:
	var ui := LoadoutUI.new()
	ui.hud = self
	root.add_child(ui)
	return ui


## The line beneath the ammunition: the gun, its sight, grenades and the gadget.
func set_kit(text: String) -> void:
	kit_label.text = text


func set_scope(on: bool) -> void:
	if scope_view.visible != on:
		scope_view.visible = on


## Looking through glass: a dark ring around a clear circle, and fine crosshairs.
class ScopeView extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		var dark := Color(0, 0, 0, 0.96)
		var pts := PackedVector2Array()
		for i in 65:
			var a := i * TAU / 64.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		# Everything outside the circle is dark: four rectangles and the corners between circle and box
		draw_rect(Rect2(0, 0, c.x - r, size.y), dark)
		draw_rect(Rect2(c.x + r, 0, size.x - c.x - r, size.y), dark)
		for i in 64:
			var a0 := i * TAU / 64.0
			var a1 := (i + 1) * TAU / 64.0
			var p0 := c + Vector2(cos(a0), sin(a0)) * r
			var p1 := c + Vector2(cos(a1), sin(a1)) * r
			var edge := Vector2(p0.x, 0.0 if p0.y < c.y else size.y)
			var edge1 := Vector2(p1.x, 0.0 if p1.y < c.y else size.y)
			draw_colored_polygon(PackedVector2Array([p0, p1, edge1, edge]), dark)
		draw_polyline(pts, Color(0, 0, 0, 1), 6.0)
		var ln := Color(0, 0, 0, 0.85)
		draw_line(c - Vector2(r, 0), c - Vector2(14, 0), ln, 2.0)
		draw_line(c + Vector2(14, 0), c + Vector2(r, 0), ln, 2.0)
		draw_line(c - Vector2(0, r), c - Vector2(0, 14), ln, 2.0)
		draw_line(c + Vector2(0, 14), c + Vector2(0, r), ln, 2.0)
		draw_circle(c, 1.6, Color(0.8, 0.1, 0.1, 0.9))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


func hitmarker(kill: bool, turned := false, crit := false) -> void:
	_ensure_marks()
	_marks.hit = 1.0
	_marks.kill = kill
	_marks.turned = turned
	_marks.crit = crit


func damage_from(angle: float) -> void:
	_ensure_marks()
	_marks.arcs.append([angle, 1.0])


## Hit markers at the centre and red arcs showing where harm came from.
class Marks extends Control:
	var hit := 0.0
	var kill := false
	var turned := false
	var crit := false
	var arcs: Array = []

	func _process(d: float) -> void:
		hit = maxf(0.0, hit - d * 4.0)
		for a in arcs:
			a[1] -= d * 0.9
		arcs = arcs.filter(func(a): return a[1] > 0.0)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		if hit > 0.0:
			var col := Color(1.0, 0.25, 0.15, hit) if kill else (Color(1.0, 0.8, 0.3, hit) if crit else Color(1, 1, 1, hit))
			var r := 14.0 if kill else (13.0 if crit else 10.0)
			if turned:
				# A shot turned aside: a small grey ring, not the cross of a true hit
				draw_arc(c, 9.0, 0.0, TAU, 20, Color(0.6, 0.6, 0.62, hit), 2.0)
			else:
				for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
					draw_line(c + s * 5.0, c + s * r, col, 2.5)
		for a in arcs:
			var ang: float = a[0] - PI / 2
			draw_arc(c, 130.0, ang - 0.35, ang + 0.35, 24, Color(0.85, 0.12, 0.08, a[1] * 0.85), 7.0)


var _fellowship: VBoxContainer
var fellowship_open := false   ## the full list, shown with its key; otherwise only the fallen are shown


## The fellowship in the top right: each pilgrim's name in their colour, how much life is left, and how far.
## Closed, it shows only those who have fallen, so the screen stays clear until someone needs help.
## rows: [name, health 0..1, fallen, colour, distance text]
func set_fellowship(rows: Array) -> void:
	if _fellowship == null:
		_fellowship = VBoxContainer.new()
		_fellowship.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_fellowship.position = Vector2(-366, 92)
		_fellowship.size = Vector2(330, 10)
		_fellowship.add_theme_constant_override("separation", 4)
		_fellowship.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_fellowship)
		var head := _label("", 15, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		head.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		head.add_theme_constant_override("shadow_offset_x", 1)
		head.add_theme_constant_override("shadow_offset_y", 1)
		_fellowship.add_child(head)
	var shown: Array = []
	for r in rows:
		if fellowship_open or r[2]:
			shown.append(r)
	var head: Label = _fellowship.get_child(0)
	head.visible = fellowship_open and not rows.is_empty()
	head.text = "Fellowship, %d   [%s] to hide" % [rows.size(), Game.key_text("fellowship")]
	while _fellowship.get_child_count() - 1 > shown.size():
		var c := _fellowship.get_child(_fellowship.get_child_count() - 1)
		_fellowship.remove_child(c)
		c.queue_free()
	while _fellowship.get_child_count() - 1 < shown.size():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.alignment = BoxContainer.ALIGNMENT_END
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var d := _label("", 14, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		d.custom_minimum_size.x = 60
		h.add_child(d)
		var l := _label("", 17, PALE, HORIZONTAL_ALIGNMENT_RIGHT)
		l.add_theme_font_override("font", title_font)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("outline_size", 4)
		l.custom_minimum_size.x = 150
		h.add_child(l)
		var b := ProgressBar.new()
		b.show_percentage = false
		b.max_value = 1.0
		b.custom_minimum_size = Vector2(90, 5)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_stylebox_override("background", _flat(Color(1, 1, 1, 0.12)))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(b)
		_fellowship.add_child(h)
	for i in shown.size():
		var r: Array = shown[i]
		var h := _fellowship.get_child(i + 1)
		var d: Label = h.get_child(0)
		var l: Label = h.get_child(1)
		var b: ProgressBar = h.get_child(2)
		d.text = str(r[4]) if r.size() > 4 else ""
		l.text = r[0] + ("  (fallen)" if r[2] else "")
		l.add_theme_color_override("font_color", (r[3] as Color).lightened(0.25) if not r[2] else Color(0.95, 0.4, 0.3))
		b.value = r[1]
		b.add_theme_stylebox_override("fill", _flat(r[3]))


var _feed: VBoxContainer


## A short line under the compass that fades: who joined, who left.
func feed(text: String, c := Color(0.86, 0.80, 0.66)) -> void:
	if _feed == null:
		_feed = VBoxContainer.new()
		_feed.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_feed.position = Vector2(-300, 84)
		_feed.size = Vector2(600, 10)
		_feed.add_theme_constant_override("separation", 2)
		_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_feed)
	var l := _label(text, 18, c, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 5)
	_feed.add_child(l)
	while _feed.get_child_count() > 4:
		_feed.get_child(0).queue_free()
		_feed.remove_child(_feed.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.5)
	tw.tween_callback(l.queue_free)


func set_health(v: float, show: bool) -> void:
	health_bar.visible = show
	health_bar.value = v


var blessing_label: Label


func set_blessings(p) -> void:
	if blessing_label == null:
		blessing_label = _label("", 16, DIM, HORIZONTAL_ALIGNMENT_LEFT)
		blessing_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		blessing_label.position = Vector2(36, -84)
		blessing_label.size = Vector2(700, 30)
		blessing_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		blessing_label.add_theme_constant_override("shadow_offset_x", 1)
		blessing_label.add_theme_constant_override("shadow_offset_y", 1)
		root.add_child(blessing_label)
		root.move_child(blessing_label, fade.get_index())
	var parts := []
	if Game.blessed("speebyeet"):
		parts.append("Cast [%s] " % Game.key_text("dash") + ("ready" if p.dash_cd <= 0.0 else "%.0f" % ceil(p.dash_cd)))
	if Game.blessed("glitchspeeb"):
		parts.append("Riftwalk [V] " + ("ready" if p.rift_cd <= 0.0 else "%.0f" % ceil(p.rift_cd)))
	if Game.blessed("runespeeb"):
		parts.append("Ward " + ("held" if p.ward_ready else "returning"))
	blessing_label.text = "    ·    ".join(parts)


func hurt_flash() -> void:
	_hurt = 1.0


func set_fx(param: String, value: float) -> void:
	overlay_mat.set_shader_parameter(param, value)


func reset_fx() -> void:
	for p in ["vignette", "glitch", "desat", "dark", "flash", "blur", "hurt"]:
		set_fx(p, 0.0)
	set_fx("vignette", 0.35)


func show_reveal(code: String) -> void:
	var d: Dictionary = Game.nine[code]
	reveal_num.text = "The %s Meowifestation" % ["First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth"][Game.NINE.find(code)]
	reveal_epithet.text = "%s  ·  %s" % [Game.NAMES[code], d.epithet]
	reveal_decree.text = d.decree
	reveal_text.text = Game.scripture(d.text)
	reveal_hint.text = ""
	create_tween().tween_property(reveal_box, "modulate:a", 1.0, 2.5)


func hide_reveal() -> void:
	create_tween().tween_property(reveal_box, "modulate:a", 0.0, 1.0)


## Lifts scripture above the black veil, for the prologue and the closing words.
func raise_text(up: bool) -> void:
	if up:
		root.move_child(card_box, root.get_child_count() - 1)
		root.move_child(narration, root.get_child_count() - 1)
		narration.position.y = -560
		narration.size.y = 300
		narration.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		root.move_child(narration, fade.get_index())
		root.move_child(card_box, fade.get_index())
		narration.position.y = -190
		narration.size.y = 150
		narration.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


# ------------------------------------------------------------------ banner

var _banner: VBoxContainer
var _banner_big: Label
var _banner_small: Label


## A large line and a small one, low in the middle of the screen: a count while fallen, or before waking.
func set_banner(big: String, small: String) -> void:
	if _banner == null:
		_banner = VBoxContainer.new()
		_banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_banner.position.y -= 150
		_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner.add_theme_constant_override("separation", 6)
		_banner_big = _label("", 44, PALE, HORIZONTAL_ALIGNMENT_CENTER)
		_banner_big.add_theme_font_override("font", title_font)
		_banner_small = _label("", 20, DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_banner_small.add_theme_font_override("font", serif)
		for l in [_banner_big, _banner_small]:
			l.add_theme_constant_override("outline_size", 8)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_banner_small.add_theme_color_override("font_color", PALE)
		_banner.add_child(_banner_big)
		_banner.add_child(_banner_small)
		var top := CanvasLayer.new()
		top.layer = 90
		add_child(top)
		top.add_child(_banner)
	_banner_big.text = big
	_banner_small.text = small
	_banner_big.visible = big != ""
	_banner_small.visible = small != ""


# ------------------------------------------------------------------ loading

var loading: Control
var _load_title: Label
var _load_tip: Label
var _load_dots: Label
var _load_t := 0.0

## Things worth knowing, shown while a land is raised. Short and plain.
const TIPS := [
	"A lit campfire makes a base. No forms rise near it.",
	"Fires burn wood. One piece lasts a day.",
	"Hunt hares, goats and tuskers for meat and hide. Cook meat before you eat it.",
	"Make, fit and improve guns at a workbench.",
	"Aim down the sights. Firing from the hip is less sure.",
	"Flares show what moves. The Censer's smoke shows and slows forms.",
	"The Claw of Ascent grips any wall or rock.",
	"Roads join the towns. Follow the signposts.",
	"Two waystones with the same name are joined.",
	"A bell rings before a camp is raided at night.",
	"Talk to the people of the towns. They have work, and news of the road.",
	"Eat and sleep at camp, or hunger and weariness wear you down.",
	"Lie down by a fire together to skip the night.",
	"Name your chests to tell your stores apart.",
]


func _build_loading() -> void:
	loading = ColorRect.new()
	(loading as ColorRect).color = Color(0.03, 0.028, 0.025)
	loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.mouse_filter = Control.MOUSE_FILTER_STOP
	loading.visible = false
	# Its own layer, above everything a land may add to the screen while it is raised
	var top := CanvasLayer.new()
	top.layer = 100
	add_child(top)
	top.add_child(loading)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	loading.add_child(v)
	_load_title = _label("", 64, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	_load_title.add_theme_font_override("font", title_font)
	v.add_child(_load_title)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.35)
	rule.custom_minimum_size = Vector2(220, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(rule)
	_load_tip = _label("", 22, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_load_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_load_tip.custom_minimum_size = Vector2(760, 0)
	_load_tip.add_theme_font_override("font", serif)
	_load_tip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_load_tip)
	_load_dots = _label("", 18, Color(GOLD, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	_load_dots.add_theme_font_override("font", serif)
	_load_dots.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_load_dots.position.y -= 70
	_load_dots.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loading.add_child(_load_dots)


## Shows the loading screen and waits until it is really on the screen, so the work that follows
## (which may hold the game still for a while) happens behind it rather than behind a black window.
func show_loading(title: String, what := "The land is raised") -> void:
	_load_title.text = title
	_load_tip.text = TIPS[randi() % TIPS.size()]
	_load_dots.text = what + "..."
	_load_dots.set_meta("what", what)
	loading.visible = true
	loading.modulate.a = 1.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func set_loading(what: String) -> void:
	if loading.visible:
		_load_dots.text = what + "..."
		_load_dots.set_meta("what", what)


func hide_loading() -> void:
	if not loading.visible:
		return
	var tw := create_tween()
	tw.tween_property(loading, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): loading.visible = false)


func clear_all() -> void:
	clear_say()
	set_prompt("", 0)
	set_objective("")
	set_meter("", 0)
	reveal_box.modulate.a = 0
	card_box.modulate.a = 0
	results_panel.visible = false
	pause_panel.visible = false
	set_fellowship([])
	name_label.text = ""
	ammo_label.text = ""
	health_bar.visible = false
	hotbar.visible = false
	relic_hint.text = ""
	streak_label.text = ""
	if blessing_label:
		blessing_label.text = ""
	reset_fx()
	for c in menu_box.get_children():
		c.queue_free()


# ---------------------------------------------------------------- pause and codex

var _save_btn: Button
var _restart_btn: Button
var _rules_btn: Button


## Writes everything down at once: the pilgrim's own record, and in the waste the world and what is carried.
func _save_now() -> void:
	Game.save()
	var lvl = Game.main.level
	if lvl and lvl.has_method("save_all"):
		lvl.save_all()
	_save_btn.text = "Saved"
	get_tree().create_timer(1.5, true, false, true).timeout.connect(func(): _save_btn.text = "Save")


func _build_pause() -> void:
	pause_panel = ColorRect.new()
	pause_panel.color = Color(0, 0, 0, 0.82)
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-260, -260)
	v.size = Vector2(520, 520)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	pause_panel.add_child(v)
	var t := _label("Stillness", 48, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", title_font)
	v.add_child(t)
	v.add_child(_label("\"Speeb sees. Speeb is.\"", 20, DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Control.new())
	v.add_child(button("Resume", toggle_pause))
	v.add_child(button("The Book of Emojis", func(): toggle_codex()))
	_save_btn = button("Save", _save_now)
	v.add_child(_save_btn)
	v.add_child(button("Settings", func(): show_options()))
	_rules_btn = button("World settings", func():
		var lvl = Game.main.level
		if lvl and lvl.has_method("set_rules"):
			show_rules(lvl.rules, Net.authority(), func(r): lvl.set_rules(r)))
	v.add_child(_rules_btn)
	_restart_btn = button("Restart this trial", func(): toggle_pause(); Game.main.restart_level())
	v.add_child(_restart_btn)
	v.add_child(button("Return to the beginning", func(): toggle_pause(); Game.main.show_title()))
	v.add_child(button("Leave", func(): ask("Leave the game?", "Leave", func(): get_tree().quit())))


## A question over everything else, answered yes or no. Escape or "Stay" closes it.
func ask(question: String, yes: String, on_yes: Callable, no := "Stay") -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.055, 0.05, 0.96)
	sb.border_color = Color(GOLD, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 28
	sb.content_margin_bottom = 24
	box.add_theme_stylebox_override("panel", sb)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	shade.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	box.add_child(v)
	var q := _label(question, 30, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	q.add_theme_font_override("font", title_font)
	v.add_child(q)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	v.add_child(row)
	var stay := button(no, func(): shade.queue_free(), 24)
	row.add_child(stay)
	var go := button(yes, func(): shade.queue_free(); on_yes.call(), 24)
	go.add_theme_color_override("font_color", GOLD)
	row.add_child(go)
	shade.gui_input.connect(func(e): if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE: shade.queue_free())
	stay.grab_focus.call_deferred()


## A world's settings in a dialog: one row of choices for each, with a line on what the chosen
## one does. Read-only for someone who is not the host.
func show_rules(current: Dictionary, editable: bool, on_done: Callable) -> void:
	var r: Dictionary = WRules.clean(current)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.055, 0.05, 0.97)
	sb.border_color = Color(GOLD, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(30)
	box.add_theme_stylebox_override("panel", sb)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	shade.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var t := _label("World settings", 30, PALE, HORIZONTAL_ALIGNMENT_LEFT)
	t.add_theme_font_override("font", title_font)
	v.add_child(t)
	if not editable:
		v.add_child(_label("Only the host can change these.", 16, DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var note := _label("", 16, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(760, 44)
	for row in WRules.ALL:
		var key: String = row[0]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var l := _label(row[1], 19, PALE, HORIZONTAL_ALIGNMENT_LEFT)
		l.custom_minimum_size.x = 230
		h.add_child(l)
		var group := ButtonGroup.new()
		for i in row[2].size():
			var b := Button.new()
			b.text = row[2][i]
			b.toggle_mode = true
			b.button_group = group
			b.disabled = not editable
			b.button_pressed = int(r[key]) == i
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.add_theme_font_size_override("font_size", 16)
			b.add_theme_color_override("font_color", DIM)
			b.add_theme_color_override("font_pressed_color", GOLD)
			b.add_theme_color_override("font_hover_pressed_color", GOLD)
			b.add_theme_color_override("font_disabled_color", Color(DIM, 0.5))
			b.add_theme_color_override("font_hover_color", PALE)
			b.add_theme_color_override("font_focus_color", PALE)
			for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
				var cb := StyleBoxFlat.new()
				var on: bool = st in ["pressed", "hover_pressed"] or (st == "disabled" and int(r[key]) == i)
				cb.bg_color = Color(GOLD, 0.16) if on else Color(1, 1, 1, 0.08 if st in ["hover", "focus"] else 0.03)
				cb.border_color = Color(GOLD, 0.7) if on else Color(1, 1, 1, 0.3 if st == "focus" else 0.12)
				cb.set_border_width_all(1)
				cb.set_corner_radius_all(12)
				cb.content_margin_left = 12
				cb.content_margin_right = 12
				cb.content_margin_top = 3
				cb.content_margin_bottom = 3
				b.add_theme_stylebox_override(st, cb)
			var idx: int = i
			b.toggled.connect(func(on): if on: r[key] = idx; note.text = "%s: %s" % [row[1], row[4]])
			b.mouse_entered.connect(func(): note.text = "%s: %s" % [row[1], row[4]])
			h.add_child(b)
		v.add_child(h)
	v.add_child(note)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 30)
	v.add_child(btns)
	if editable:
		btns.add_child(button("Back", func(): shade.queue_free(), 22))
		var keep := button("Keep these", func(): shade.queue_free(); on_done.call(r), 22)
		keep.add_theme_color_override("font_color", GOLD)
		btns.add_child(keep)
		btns.add_child(button("Defaults", func(): shade.queue_free(); show_rules({}, true, on_done), 18))
	else:
		btns.add_child(button("Close", func(): shade.queue_free(), 22))
	shade.gui_input.connect(func(e): if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE: shade.queue_free())


func toggle_pause() -> void:
	if _rules_btn:
		_rules_btn.visible = Game.wasteland
	if options_panel.visible:
		hide_options()
		return
	if codex_panel.visible:
		toggle_codex()
		return
	if not Game.main.in_game():
		return
	# The world does not stop for one pilgrim of a fellowship
	if Net.online:
		var show := not pause_panel.visible
		pause_panel.visible = show
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show else Input.MOUSE_MODE_CAPTURED
		return
	var p := not get_tree().paused
	get_tree().paused = p
	pause_panel.visible = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


func _build_codex() -> void:
	codex_panel = ColorRect.new()
	codex_panel.color = Color(0.02, 0.02, 0.025, 0.95)
	codex_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	codex_panel.visible = false
	root.add_child(codex_panel)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 120
	outer.offset_right = -120
	outer.offset_top = 50
	outer.offset_bottom = -40
	codex_panel.add_child(outer)
	var t := _label("The Book of Emojis", 46, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", title_font)
	outer.add_child(t)
	codex_count = _label("", 18, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	outer.add_child(codex_count)
	outer.add_child(_label("Interpret not in haste. Interpret through silence. Interpret as mirror, not as lens.", 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	codex_list = VBoxContainer.new()
	codex_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_list.add_theme_constant_override("separation", 10)
	sc.add_child(codex_list)
	var close := button("Close  [Tab]", func(): toggle_codex(), 22)
	outer.add_child(close)


func _codex_row(code: String, title: String, text: String, known: bool) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if known:
		var tex: Texture2D = load("res://assets/emoji/%s.png" % code)
		var at := AtlasTexture.new()
		at.atlas = tex
		var n := int(Game.meta.get(code, {"frames": 1}).frames)
		at.region = Rect2(0, 0, tex.get_width() / n, tex.get_height())
		icon.texture = at
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var a := _label(title if known else "Unseen", 24, PALE if known else DIM, HORIZONTAL_ALIGNMENT_LEFT)
	a.add_theme_font_override("font", title_font)
	v.add_child(a)
	var b := _label(text if known else "This form has not yet revealed itself to you.", 18, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	h.add_child(v)
	return h


func toggle_codex() -> void:
	var show := not codex_panel.visible
	if show:
		for c in codex_list.get_children():
			c.queue_free()
		var sec := _label("The Nine Meowifestations", 28, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		sec.add_theme_font_override("font", title_font)
		codex_list.add_child(sec)
		for code in Game.NINE:
			var d: Dictionary = Game.nine[code]
			var txt: String = d.decree
			if Game.BLESSINGS.has(code):
				txt += "\nBlessing: %s. %s" % Game.BLESSINGS[code]
			codex_list.add_child(_codex_row(code, "%s. %s, %s" % [d.num, Game.NAMES[code], d.epithet], txt, Game.found.has(code)))
		var sec2 := _label("The Lesser Forms", 28, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		sec2.add_theme_font_override("font", title_font)
		codex_list.add_child(sec2)
		var shown := 0
		for code in Game.lesser:
			if Game.found.has(code):
				var e: Dictionary = Game.lesser[code]
				codex_list.add_child(_codex_row(code, ":%s:  %s" % [code, e.name], e.decree, true))
				shown += 1
		if shown == 0:
			codex_list.add_child(_label("No lesser form has yet been witnessed. They hide in every land Brelm walks.", 18, DIM, HORIZONTAL_ALIGNMENT_LEFT))
		var sec3 := _label("Leaves of the Hermit", 28, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		sec3.add_theme_font_override("font", title_font)
		codex_list.add_child(sec3)
		var Story = load("res://scripts/story.gd")
		for k in Story.LEAVES:
			var lf: Array = Story.LEAVES[k]
			if Game.leaves.has(k):
				codex_list.add_child(_text_row(lf[0], lf[1], true))
			else:
				codex_list.add_child(_text_row(lf[0], "Not yet found. It lies somewhere in %s." % Game.LEVEL_NAMES[Game.LEVELS.find(k)], false))
		var sec4 := _label("Revelations  (%d of %d)" % [Game.revealed.size(), Game.REVELATIONS.size()], 28, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		sec4.add_theme_font_override("font", title_font)
		codex_list.add_child(sec4)
		for id in Game.REVELATIONS:
			var rv: Array = Game.REVELATIONS[id]
			codex_list.add_child(_text_row(rv[0], rv[1], Game.revealed.has(id)))
		codex_list.add_child(_label("Undone in all: %d    ·    Longest litany: %d    ·    Saucers brought down: %d" % [Game.stats.kills, Game.stats.best_streak, Game.stats.saucers], 18, DIM, HORIZONTAL_ALIGNMENT_LEFT))
		var nine_found := 0
		for c in Game.NINE:
			if Game.found.has(c):
				nine_found += 1
		codex_count.text = "Meowifestations witnessed: %d of 9    ·    Lesser forms recorded: %d of %d    ·    %s" % [nine_found, shown, Game.lesser.size(),
			"The Tenth Trial is open" if Game.tenth_unlocked() else "The Tenth Trial opens at %d" % Game.TENTH_NEEDS]
	codex_panel.visible = show
	if Game.main.in_game():
		if show:
			if not get_tree().paused and not Net.online:
				get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif not pause_panel.visible:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(d: float) -> void:
	crosshair.visible = Game.main != null and Game.main.in_game() and not get_tree().paused
	if _hurt > 0.0:
		_hurt = maxf(0.0, _hurt - d * 2.0)
		set_fx("hurt", _hurt)


var _rebinding: Array = []
var _from_pause := false


## While a control waits for its new key, the next key or mouse button pressed becomes it.
func _input(e: InputEvent) -> void:
	if _streak_keys(e):
		get_viewport().set_input_as_handled()
		return
	if _rebinding.is_empty():
		return
	var code := 0
	if e is InputEventKey and e.pressed and not e.echo:
		code = e.physical_keycode
	elif e is InputEventMouseButton and e.pressed and not e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		code = -e.button_index
	else:
		return
	get_viewport().set_input_as_handled()
	var rb := _rebinding
	_rebinding = []
	if code != KEY_ESCAPE:
		Game.rebind(rb[0], rb[1], code)
	show_options.call_deferred()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("fellowship") and Net.online and Game.main.in_game():
		fellowship_open = not fellowship_open
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("codex"):
		if Game.main.in_game() or codex_panel.visible:
			toggle_codex()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- air support

signal _streak_chosen(k)
var _streak_menu: PanelContainer


func streak_menu_open() -> bool:
	return is_instance_valid(_streak_menu)


func close_streak_menu() -> void:
	if is_instance_valid(_streak_menu):
		_streak_menu.queue_free()
		_streak_menu = null
		_streak_chosen.emit(null)


## The kill streaks that are ready, to pick one from. Returns the chosen kind, or null.
func open_streak_menu(kinds: Array, counts: Dictionary):
	close_streak_menu()
	var p := PanelContainer.new()
	_streak_menu = p
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.035, 0.9)
	sb.border_color = Color(GOLD, 0.45)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(520, 0)
	p.position = Vector2(-260, -140)
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var t := _label("Air support", 30, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	t.add_theme_font_override("font", title_font)
	v.add_child(t)
	v.add_child(_label("Choose what comes. It strikes where you are looking.", 16, DIM, HORIZONTAL_ALIGNMENT_LEFT))
	for i in kinds.size():
		var k: String = kinds[i]
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%d   %s%s" % [i + 1, Streaks.KINDS[k].name, "  ×%d" % counts[k] if counts.get(k, 1) > 1 else ""]
		b.tooltip_text = Streaks.KINDS[k].text
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", PALE)
		b.add_theme_color_override("font_hover_color", GOLD)
		b.pressed.connect(func(): _pick_streak(k))
		v.add_child(b)
		v.add_child(_label("     " + Streaks.KINDS[k].text, 15, DIM, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(_label("%s or Esc to close" % Game.key_text("streak"), 14, Color(DIM, 0.7), HORIZONTAL_ALIGNMENT_LEFT))
	p.set_meta("kinds", kinds)
	return await _streak_chosen


func _pick_streak(k) -> void:
	if is_instance_valid(_streak_menu):
		_streak_menu.queue_free()
		_streak_menu = null
	_streak_chosen.emit(k)


func _streak_keys(e: InputEvent) -> bool:
	if not is_instance_valid(_streak_menu) or not (e is InputEventKey and e.pressed and not e.echo):
		return false
	var kinds: Array = _streak_menu.get_meta("kinds")
	if e.physical_keycode == KEY_ESCAPE or e.is_action("streak"):
		close_streak_menu()
		return true
	var n: int = e.physical_keycode - KEY_1
	if n >= 0 and n < kinds.size():
		_pick_streak(kinds[n])
		return true
	return false


func set_hotbar(slot: int, faith: float, milk: int) -> void:
	hotbar.visible = slot >= 0
	var cells := 10 if Game.wasteland else 6
	hotbar.position = Vector2(-36 - Hotbar.W * cells, -182)
	hotbar.size = Vector2(Hotbar.W * cells, Hotbar.W + 24)
	hotbar.slot = slot
	hotbar.faith = faith
	hotbar.milk = milk
	hotbar.queue_redraw()


func set_relic_hint(text: String) -> void:
	if relic_hint.text != text:
		relic_hint.text = text


## Six slots, numbered, each with a small drawn sign of its relic.
class Hotbar extends Control:
	const W := 58.0
	var slot := 0
	var faith := 1.0
	var milk := 0
	var font: Font

	var arms   ## the weapon in the pilgrim's hands; the waste draws its bar from it

	## The waste's bar: both guns, the blade, prayer, lantern and milk, then what is thrown and the kit.
	func _draw_waste() -> void:
		var gold := Color(0.86, 0.80, 0.66)
		var cells := [
			["1", "shotgun" if arms.guns[0] != "minigun" else "shotgun", ArmsDB.GUNS[arms.guns[0]].name, slot == 0 and arms.cur == 0, ""],
			["2", "pistol", ArmsDB.GUNS[arms.guns[1]].name, slot == 0 and arms.cur == 1, ""],
			["3", "blade", ArmsDB.MELEE[arms.melee].name, false, ""],
			["4", "hands", "Prayer", slot == 1, ""],
			["5", "lantern", "Lantern", slot == 2, ""],
			["6", "milk", "Milk", slot == 5, str(milk)],
			["7", "claw", "Claw of Ascent", slot == 3, "" if Game.has_relic("claw") else "-"],
			["8", "censer", "Censer", slot == 4, "" if Game.has_relic("censer") else "-"],
			[Game.key_text("grenade"), "thrown", ArmsDB.GRENADES[arms.grenade].name, false, str(arms.grenades)],
			[Game.key_text("gadget"), "kit", ArmsDB.GADGETS[arms.gadget].name, false, str(arms.charges)],
		]
		var name := ""
		for i in cells.size():
			var c: Array = cells[i]
			var x := i * W + (8.0 if i >= 8 else 0.0)
			var r := Rect2(x + 3, 0, W - 6, W - 6)
			var on: bool = c[3]
			var empty: bool = c[4] == "0" or c[4] == "-"
			draw_rect(r, Color(0.03, 0.03, 0.035, 0.6))
			draw_rect(r, gold if on else Color(1, 1, 1, 0.16), false, 2.0 if on else 1.0)
			if on:
				draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), gold)
				name = c[2]
			draw_string(font, r.position + Vector2(4, 13), Game.key_text("slot_%d" % (i + 1)) if i < 8 else c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55))
			_icon(c[1], r.get_center() + Vector2(0, 3), Color(0.93, 0.92, 0.88, 0.25 if empty else 0.95))
			if c[1] == "hands":
				draw_rect(Rect2(r.position.x + 4, r.end.y - 6, (r.size.x - 8) * faith, 3), Color(1.0, 0.85, 0.45) if faith >= 1.0 else Color(0.7, 0.62, 0.45))
			if c[4] != "" and c[4] != "-":
				draw_string(font, r.end - Vector2(15, 5), c[4], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.93, 0.92, 0.88, 0.4 if empty else 1.0))
		draw_string(font, Vector2(0, W + 14), name, HORIZONTAL_ALIGNMENT_RIGHT, W * 10 - 4, 16, gold)

	func _draw() -> void:
		if Game.wasteland and is_instance_valid(arms):
			_draw_waste()
			return
		var gold := Color(0.86, 0.80, 0.66)
		for i in Game.RELICS.size():
			var id: String = Game.RELICS[i]
			var owned := Game.has_relic(id) or id == "milk"
			var r := Rect2(i * W + 3, 0, W - 6, W - 6)
			draw_rect(r, Color(0, 0, 0, 0.45 if owned else 0.2))
			draw_rect(r, gold if i == slot else Color(1, 1, 1, 0.18), false, 2.0 if i == slot else 1.0)
			draw_string(font, r.position + Vector2(4, 14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
			var c := r.get_center() + Vector2(0, 3)
			var col := Color(0.93, 0.92, 0.88, 0.95 if owned else 0.15)
			if id == "milk" and milk <= 0:
				col.a = 0.2
			_icon(id, c, col)
			if id == "hands":
				var fr := Rect2(r.position.x + 4, r.end.y - 6, (r.size.x - 8) * faith, 3)
				draw_rect(fr, Color(1.0, 0.85, 0.45) if faith >= 1.0 else Color(0.7, 0.62, 0.45))
			if id == "milk":
				draw_string(font, r.end - Vector2(14, 4), str(milk), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		if slot >= 0:
			var name: String = Game.RELIC_NAMES[Game.RELICS[slot]]
			draw_string(font, Vector2(0, W + 14), name, HORIZONTAL_ALIGNMENT_RIGHT, W * 6 - 4, 16, gold)

	func _icon(id: String, c: Vector2, col: Color) -> void:
		match id:
			"shotgun":
				draw_line(c + Vector2(-18, -2), c + Vector2(16, -8), col, 4)
				draw_line(c + Vector2(-18, -2), c + Vector2(-20, 8), col, 5)
				draw_line(c + Vector2(-4, -2), c + Vector2(6, -4), col, 6)
			"pistol":
				draw_line(c + Vector2(-12, -6), c + Vector2(14, -6), col, 6)
				draw_line(c + Vector2(-9, -6), c + Vector2(-12, 10), col, 6)
				draw_arc(c + Vector2(-2, 0), 4, 0, PI, 8, col, 1.5)
			"blade":
				draw_line(c + Vector2(-12, 13), c + Vector2(6, -10), col, 3)
				draw_colored_polygon(PackedVector2Array([c + Vector2(2, -14), c + Vector2(16, -8), c + Vector2(10, 2), c + Vector2(4, -6)]), col)
			"thrown":
				draw_circle(c + Vector2(0, 3), 9, col)
				draw_rect(Rect2(c + Vector2(-3, -12), Vector2(6, 6)), col)
				draw_arc(c + Vector2(6, -11), 4, 0, TAU, 10, col, 1.5)
			"kit":
				draw_rect(Rect2(c + Vector2(-12, -8), Vector2(24, 18)), col, false, 2)
				draw_rect(Rect2(c + Vector2(-2, -4), Vector2(4, 10)), col)
				draw_rect(Rect2(c + Vector2(-5, -1), Vector2(10, 4)), col)
			"hands":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14), c + Vector2(-7, 2), c + Vector2(-5, 12), c + Vector2(5, 12), c + Vector2(7, 2)]), col)
				draw_arc(c + Vector2(0, -18), 7, 0, TAU, 20, Color(1.0, 0.85, 0.45, col.a), 2)
			"lantern":
				draw_rect(Rect2(c + Vector2(-7, -8), Vector2(14, 18)), col, false, 2)
				draw_circle(c + Vector2(0, 1), 3.5, Color(1.0, 0.75, 0.35, col.a))
				draw_arc(c + Vector2(0, -12), 4, PI, TAU, 10, col, 2)
			"claw":
				draw_line(c + Vector2(0, 14), c + Vector2(0, -4), col, 3)
				for a in [-0.9, 0.0, 0.9]:
					var d := Vector2(sin(a), -cos(a))
					draw_line(c + Vector2(0, -4), c + Vector2(0, -4) + d * 10, col, 2.5)
			"censer":
				draw_line(c + Vector2(0, -16), c + Vector2(0, 2), col, 1.5)
				draw_circle(c + Vector2(0, 7), 7, col)
				draw_arc(c + Vector2(6, -6), 5, -PI / 2, PI / 2, 8, Color(col, col.a * 0.5), 2)
			"milk":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -2), c + Vector2(12, -2), c + Vector2(7, 9), c + Vector2(-7, 9)]), Color(0.6, 0.42, 0.3, col.a))
				draw_line(c + Vector2(-11, -2), c + Vector2(11, -2), col, 3)


# ---------------------------------------------------------------- options

func _build_options() -> void:
	options_panel = ColorRect.new()
	options_panel.color = Color(0.01, 0.01, 0.012, 0.94)
	options_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_panel.visible = false
	root.add_child(options_panel)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 0
	outer.offset_right = 0
	outer.offset_top = 50
	outer.offset_bottom = -40
	outer.add_theme_constant_override("separation", 12)
	options_panel.add_child(outer)
	var t := _label("Settings", 46, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", title_font)
	outer.add_child(t)
	outer.add_child(_label("F11 or Alt+Enter toggles fullscreen at any time", 16, DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(center)
	_options_list = VBoxContainer.new()
	_options_list.custom_minimum_size.x = 760
	_options_list.add_theme_constant_override("separation", 8)
	center.add_child(_options_list)
	var back := button("Back  [Esc]", func(): hide_options(), 24)
	outer.add_child(back)


func show_options() -> void:
	for c in _options_list.get_children():
		c.queue_free()
	_section("Display")
	_choice("Display mode", Game.DISPLAY_MODES, Game.display_mode, func(i): Game.display_mode = i; _apply_display())
	var res_names := []
	for r in Game.RESOLUTIONS:
		res_names.append("%d x %d" % [r.x, r.y])
	_choice("Resolution", res_names, Game.resolution, func(i): Game.resolution = i; _apply_display())
	_options_list.add_child(_label("In fullscreen, the resolution sets how sharply the world is drawn; the screen is always filled.", 15, DIM, HORIZONTAL_ALIGNMENT_LEFT))
	_toggle("Vertical sync", Game.vsync, func(on): Game.vsync = on; _apply_display())
	var caps := []
	for f in Game.FPS_CAPS:
		caps.append("Unlimited" if f == 0 else "%d" % f)
	_choice("Frame rate limit", caps, Game.fps_cap, func(i): Game.fps_cap = i; _apply_display())
	_choice("Anti-aliasing", Game.AA_MODES, Game.aa, func(i): Game.aa = i; _apply_display())
	_slider("Field of view", 60.0, 100.0, 1.0, Game.fov, _set_fov, "%d")
	_toggle("Head bob", Game.head_bob, func(on): Game.head_bob = on; Game.save())
	_choice("Graphics quality", ["Standard", "High (occlusion, bounce light, bloom)"], Game.quality, func(i):
		Game.quality = i
		Game.save()
		if Game.main.level and Game.main.level.has_method("apply_quality"):
			Game.main.level.apply_quality())
	if Game.revealed.has("hundred"):
		_choice("Gun finish", ["Iron", "Gilded"], 1 if Game.gilded else 0, func(i): Game.gilded = i == 1; Game.save())
	else:
		_options_list.add_child(_label("Undo one hundred lesser forms to earn the gilded shotgun.", 15, DIM, HORIZONTAL_ALIGNMENT_LEFT))
	_section("Controls")
	_slider("Mouse sensitivity", 0.0005, 0.006, 0.0001, Game.sensitivity, func(x): Game.sensitivity = x; Game.save(), "")
	_toggle("Invert mouse Y", Game.invert_y, func(on): Game.invert_y = on; Game.save())
	_options_list.add_child(_label("Click a key to change it, then press the new key or mouse button. Esc leaves it as it was.", 15, DIM, HORIZONTAL_ALIGNMENT_LEFT))
	for c in Game.CONTROLS:
		var action: String = c[0]
		var h := _row(c[1])
		var ks: Array = Game.keys_of(action)
		for slot in 2:
			var b := Button.new()
			b.text = Game.key_name(int(ks[slot])) if slot < ks.size() else "—"
			b.custom_minimum_size.x = 170
			b.add_theme_font_size_override("font_size", 18)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func():
				_rebinding = [action, slot]
				b.text = "Press a key...")
			h.add_child(b)
	_options_list.add_child(_label("While building: the wheel chooses a piece.", 15, DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var rb := button("Restore the default controls", func(): Game.reset_binds(); show_options(), 18)
	rb.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_options_list.add_child(rb)
	_section("Sound")
	_slider("Volume", 0.0, 1.0, 0.01, Game.volume, func(x): Game.volume = x; Game.apply_volume(); Game.save(), "%d%%", 100.0)
	_toggle("Brelm speaks over the fallen", Game.voice_lines, func(on): Game.voice_lines = on; Game.save())
	_section("The Ashen Waste")
	_toggle("Show the first-steps guide", Game.guide, func(on): Game.guide = on; Game.save())
	var every := [0, 1, 2, 5, 10]
	_choice("Autosave", ["Only at key moments", "Every minute", "Every 2 minutes", "Every 5 minutes", "Every 10 minutes"],
		maxi(every.find(Game.autosave_min), 0), func(i): Game.autosave_min = every[i]; Game.save())
	_section("Trial")
	if Net.online and not Net.is_host():
		_options_list.add_child(_label("In a fellowship the host's difficulty holds for everyone.", 15, DIM, HORIZONTAL_ALIGNMENT_LEFT))
	else:
		_choice("Difficulty", Game.DIFFICULTIES, Game.difficulty, func(i): Game.difficulty = i; Game.save())
	_choice("Lesser forms", ["Flesh: cat heads", "Masks: their emojis"], Game.forms_style, func(i): Game.forms_style = i; Game.save())
	_section("Fellowship")
	_line("Your name among the fellowship", Game.player_name, "Pilgrim", func(t): Game.player_name = t.strip_edges().left(20); Game.save())
	_line("Internet list address", Game.lobby_url, Net.DEFAULT_LOBBY if Net.DEFAULT_LOBBY != "" else "https://... (optional)", func(t): Game.lobby_url = t.strip_edges(); Game.save())
	if pause_panel.visible:
		_from_pause = true
	options_panel.visible = true
	pause_panel.visible = false
	root.move_child(options_panel, root.get_child_count() - 1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_fov(x: float) -> void:
	Game.fov = x
	Game.save()
	if Game.main.level and Game.main.level.get("player"):
		Game.main.level.player.cam.fov = x


func hide_options() -> void:
	options_panel.visible = false
	_rebinding = []
	if Game.main.in_game() and (get_tree().paused or _from_pause):
		pause_panel.visible = true
	_from_pause = false


func _apply_display() -> void:
	Game.apply_display()
	Game.save()


func _section(text: String) -> void:
	var l := _label(text, 26, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	l.add_theme_font_override("font", title_font)
	_options_list.add_child(l)


func _row(text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l := _label(text, 20, PALE, HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size.x = 340
	h.add_child(l)
	_options_list.add_child(h)
	return h


func _choice(text: String, items: Array, sel: int, cb: Callable) -> void:
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = sel
	o.custom_minimum_size.x = 360
	o.add_theme_font_size_override("font_size", 20)
	o.item_selected.connect(cb)
	_row(text).add_child(o)


func _line(text: String, value: String, hint: String, cb: Callable) -> void:
	var e := LineEdit.new()
	e.text = value
	e.placeholder_text = hint
	e.custom_minimum_size.x = 360
	e.add_theme_font_size_override("font_size", 20)
	e.text_changed.connect(cb)
	_row(text).add_child(e)


func _toggle(text: String, on: bool, cb: Callable) -> void:
	var c := CheckButton.new()
	c.button_pressed = on
	c.toggled.connect(cb)
	_row(text).add_child(c)


func _slider(text: String, lo: float, hi: float, step: float, value: float, cb: Callable, fmt := "", mul := 1.0) -> void:
	var h := _row(text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size.x = 300
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var v := _label("", 18, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	h.add_child(v)
	var show := func(x):
		v.text = fmt % (x * mul) if fmt != "" else ""
	show.call(value)
	s.value_changed.connect(func(x):
		show.call(x)
		cb.call(x))


func _text_row(title: String, text: String, known: bool) -> Control:
	var v := VBoxContainer.new()
	var t := _label(title, 22, PALE if known else DIM, HORIZONTAL_ALIGNMENT_LEFT)
	t.add_theme_font_override("font", title_font)
	v.add_child(t)
	var b := _label(text, 17, Color(0.8, 0.78, 0.72) if known else Color(0.45, 0.44, 0.42), HORIZONTAL_ALIGNMENT_LEFT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	return v


# ---------------------------------------------------------------- litany and revelations

const LITANY := ["", "", "Twofold", "Threefold", "Fourfold", "Fivefold", "Sixfold", "Sevenfold", "Eightfold", "Ninefold"]


func set_streak(n: int) -> void:
	if n < 2:
		if streak_label.text != "":
			var tw := create_tween()
			tw.tween_property(streak_label, "modulate:a", 0.0, 0.6)
			tw.tween_callback(func(): streak_label.text = "")
		return
	var word: String = LITANY[n] if n < LITANY.size() else "Unbroken"
	streak_label.text = "Litany  %d\n%s" % [n, word]
	streak_label.modulate = Color(1.0, 1.0, 1.0, 1.0) if n < 5 else Color(1.25, 1.1, 0.8, 1.0)
	streak_label.scale = Vector2.ONE * (1.35 + minf(n, 20) * 0.01)
	create_tween().tween_property(streak_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_deed() -> void:
	_deed_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.03, 0.92)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_content_margin_all(16)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.shadow_color = Color(1.0, 0.8, 0.4, 0.25)
	sb.shadow_size = 18
	_deed_box.add_theme_stylebox_override("panel", sb)
	_deed_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_deed_box.position = Vector2(-300, 70)
	_deed_box.custom_minimum_size = Vector2(600, 0)
	_deed_box.modulate.a = 0.0
	_deed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_deed_box)
	var v := VBoxContainer.new()
	_deed_box.add_child(v)
	v.add_child(_label("A Revelation", 15, DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_deed_title = _label("", 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_deed_title.add_theme_font_override("font", title_font)
	v.add_child(_deed_title)
	_deed_text = _label("", 17, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	_deed_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_deed_text)


func revelation(title: String, text: String) -> void:
	_deed_queue.append([title, text])
	if _deed_busy:
		return
	_deed_busy = true
	while not _deed_queue.is_empty():
		var d: Array = _deed_queue.pop_front()
		_deed_title.text = d[0]
		_deed_text.text = d[1]
		root.move_child(_deed_box, root.get_child_count() - 1)
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/relic.wav")
		p.volume_db = -4
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		_deed_box.scale = Vector2(0.9, 0.9)
		_deed_box.pivot_offset = Vector2(300, 40)
		var tw := create_tween().set_parallel()
		tw.tween_property(_deed_box, "modulate:a", 1.0, 0.4)
		tw.tween_property(_deed_box, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(4.0, true, false, true).timeout
		var tw2 := create_tween()
		tw2.tween_property(_deed_box, "modulate:a", 0.0, 0.6)
		await tw2.finished
	_deed_busy = false


# ---------------------------------------------------------------- results

var _results_rows: VBoxContainer
var _results_title: Label
var _results_grade: Label


func _build_results() -> void:
	results_panel = ColorRect.new()
	results_panel.color = Color(0.0, 0.0, 0.0, 0.86)
	results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_panel.visible = false
	root.add_child(results_panel)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_panel.add_child(c)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 640
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	_results_title = _label("", 44, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	_results_title.add_theme_font_override("font", title_font)
	v.add_child(_results_title)
	v.add_child(_label("Speeb sees. Speeb is.", 18, DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_results_rows = VBoxContainer.new()
	_results_rows.add_theme_constant_override("separation", 6)
	v.add_child(_results_rows)
	_results_grade = _label("", 52, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_results_grade.add_theme_font_override("font", title_font)
	v.add_child(_results_grade)
	v.add_child(_label("[%s]  Continue" % Game.key_text("interact"), 20, DIM, HORIZONTAL_ALIGNMENT_CENTER))


## Shows the account of a trial, row by row, then the grade; returns when the player continues.
func show_results(title: String, rows: Array, grade: String) -> void:
	for ch in _results_rows.get_children():
		ch.queue_free()
	_results_title.text = title
	_results_grade.text = ""
	results_panel.modulate.a = 0.0
	results_panel.visible = true
	root.move_child(results_panel, fade.get_index())
	create_tween().tween_property(results_panel, "modulate:a", 1.0, 0.8)
	await get_tree().create_timer(0.8, false).timeout
	for r in rows:
		var h := HBoxContainer.new()
		var a := _label(r[0], 22, DIM, HORIZONTAL_ALIGNMENT_LEFT)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(_label(r[1], 22, PALE, HORIZONTAL_ALIGNMENT_RIGHT))
		h.modulate.a = 0.0
		_results_rows.add_child(h)
		create_tween().tween_property(h, "modulate:a", 1.0, 0.3)
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/shell.wav")
		p.volume_db = -12
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		await get_tree().create_timer(0.35, false).timeout
	await get_tree().create_timer(0.4, false).timeout
	_results_grade.text = "Weighed: %s" % grade
	_results_grade.scale = Vector2(1.3, 1.3)
	_results_grade.pivot_offset = _results_grade.size * 0.5
	create_tween().tween_property(_results_grade, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bell := AudioStreamPlayer.new()
	bell.stream = load("res://assets/audio/bell.ogg")
	bell.volume_db = -6
	add_child(bell)
	bell.play()
	var waited := 0.0
	while waited < 20.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > 1.0 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("fire")):
			break
	var tw := create_tween()
	tw.tween_property(results_panel, "modulate:a", 0.0, 0.6)
	await tw.finished
	results_panel.visible = false
	bell.queue_free()


## The name and the waning life of a great one, across the top of the sight while it is near.
func _build_boss_bar() -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.position = Vector2(-360, 92)
	_boss_box.size = Vector2(720, 40)
	_boss_box.add_theme_constant_override("separation", 4)
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_boss_box)
	_boss_name = _label("", 24, Color(0.92, 0.82, 0.74), HORIZONTAL_ALIGNMENT_CENTER)
	_boss_name.add_theme_font_override("font", title_font)
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(720, 8)
	_boss_bar.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.62, 0.1, 0.07, 0.95)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fg)
	_boss_box.add_child(_boss_bar)


func boss_bar(title: String, frac: float) -> void:
	if title == "":
		_boss_box.visible = false
		return
	_boss_box.visible = true
	_boss_name.text = title
	_boss_bar.value = clampf(frac, 0.0, 1.0)
