extends RefCounted
## One look for every control in every menu: a dark fill, a thin gold edge, and a stronger gold edge
## on whatever a controller or the keyboard has chosen. Set once on the HUD's root, so every screen
## under it (title, settings, pause, the waste's pack and map) shares it. A control that sets its own
## look keeps it; this fills in the ones that used to fall back to Godot's grey.

const GOLD := Color(0.86, 0.80, 0.66)
const PALE := Color(0.93, 0.92, 0.88)
const DIM := Color(0.62, 0.60, 0.56)
const FILL := Color(0.075, 0.07, 0.065, 0.92)
const FILL_HOVER := Color(0.11, 0.10, 0.09, 0.95)
const EDGE := Color(0.86, 0.80, 0.66, 0.32)
const EDGE_HOVER := Color(0.86, 0.80, 0.66, 0.65)


static func make(font: Font) -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 24
	var normal := box(FILL, EDGE)
	var hover := box(FILL_HOVER, EDGE_HOVER)
	var pressed := box(Color(GOLD, 0.16), GOLD)
	var disabled := box(Color(FILL, 0.5), Color(EDGE, 0.15))
	var focus := focus_box()

	for t in ["Button", "OptionButton", "MenuButton"]:
		th.set_stylebox("normal", t, normal)
		th.set_stylebox("hover", t, hover)
		th.set_stylebox("pressed", t, pressed)
		th.set_stylebox("hover_pressed", t, pressed)
		th.set_stylebox("disabled", t, disabled)
		th.set_stylebox("focus", t, focus)
		_font_colors(th, t)
	th.set_icon("arrow", "OptionButton", _chevron())
	th.set_constant("arrow_margin", "OptionButton", 10)

	# Switches and boxes: no ground of their own, only the focus mark
	for t in ["CheckButton", "CheckBox"]:
		var none := StyleBoxEmpty.new()
		none.content_margin_left = 4
		none.content_margin_right = 4
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			th.set_stylebox(s, t, none)
		th.set_stylebox("focus", t, focus)
		_font_colors(th, t)
	th.set_icon("checked", "CheckButton", _switch(true))
	th.set_icon("unchecked", "CheckButton", _switch(false))
	th.set_icon("checked_disabled", "CheckButton", _switch(true, 0.4))
	th.set_icon("unchecked_disabled", "CheckButton", _switch(false, 0.4))
	th.set_icon("checked", "CheckBox", _tick(true))
	th.set_icon("unchecked", "CheckBox", _tick(false))
	th.set_icon("checked_disabled", "CheckBox", _tick(true, 0.4))
	th.set_icon("unchecked_disabled", "CheckBox", _tick(false, 0.4))

	# Lists that drop down
	var pop := box(Color(0.06, 0.055, 0.05, 0.98), EDGE_HOVER)
	pop.set_content_margin_all(6)
	th.set_stylebox("panel", "PopupMenu", pop)
	th.set_stylebox("hover", "PopupMenu", box(Color(GOLD, 0.14), Color(0, 0, 0, 0), 0))
	th.set_color("font_color", "PopupMenu", DIM)
	th.set_color("font_hover_color", "PopupMenu", PALE)
	th.set_color("font_accelerator_color", "PopupMenu", DIM)
	th.set_constant("v_separation", "PopupMenu", 8)
	th.set_icon("radio_checked", "PopupMenu", _dot(true))
	th.set_icon("radio_unchecked", "PopupMenu", _dot(false))

	# Sliders: a thin dark track, gold where it is filled, a pale knob
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(2)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled := track.duplicate()
	filled.bg_color = Color(GOLD, 0.7)
	var filled_hi := track.duplicate()
	filled_hi.bg_color = GOLD
	for t in ["HSlider", "VSlider"]:
		th.set_stylebox("slider", t, track)
		th.set_stylebox("grabber_area", t, filled)
		th.set_stylebox("grabber_area_highlight", t, filled_hi)
		th.set_stylebox("focus", t, focus)
		th.set_icon("grabber", t, _knob(PALE))
		th.set_icon("grabber_highlight", t, _knob(GOLD))
		th.set_icon("grabber_disabled", t, _knob(DIM))

	# Words typed in
	var edit := box(Color(0.04, 0.04, 0.035, 0.92), EDGE)
	edit.content_margin_left = 10
	edit.content_margin_right = 10
	th.set_stylebox("normal", "LineEdit", edit)
	th.set_stylebox("focus", "LineEdit", focus)
	th.set_stylebox("read_only", "LineEdit", box(Color(0.04, 0.04, 0.035, 0.6), Color(EDGE, 0.15)))
	th.set_color("font_color", "LineEdit", PALE)
	th.set_color("font_placeholder_color", "LineEdit", Color(DIM, 0.6))
	th.set_color("caret_color", "LineEdit", GOLD)
	th.set_color("selection_color", "LineEdit", Color(GOLD, 0.3))

	# Scroll bars: thin, quiet, gold under the pointer
	for t in ["VScrollBar", "HScrollBar"]:
		var lane := StyleBoxFlat.new()
		lane.bg_color = Color(1, 1, 1, 0.05)
		lane.set_corner_radius_all(3)
		lane.set_content_margin_all(3)
		th.set_stylebox("scroll", t, lane)
		th.set_stylebox("scroll_focus", t, lane)
		var grab := StyleBoxFlat.new()
		grab.bg_color = Color(GOLD, 0.3)
		grab.set_corner_radius_all(3)
		grab.set_content_margin_all(3)
		th.set_stylebox("grabber", t, grab)
		var grab_hi := grab.duplicate()
		grab_hi.bg_color = Color(GOLD, 0.6)
		th.set_stylebox("grabber_highlight", t, grab_hi)
		var grab_dn := grab.duplicate()
		grab_dn.bg_color = Color(GOLD, 0.85)
		th.set_stylebox("grabber_pressed", t, grab_dn)

	# Tips that appear when the pointer rests
	var tip := box(Color(0.06, 0.055, 0.05, 0.97), EDGE_HOVER)
	tip.set_content_margin_all(10)
	th.set_stylebox("panel", "TooltipPanel", tip)
	th.set_color("font_color", "TooltipLabel", PALE)
	th.set_font_size("font_size", "TooltipLabel", 18)

	# Bars that fill (loading, progress)
	th.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0))
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(2)
	th.set_stylebox("fill", "ProgressBar", fill)
	th.set_color("font_color", "ProgressBar", PALE)
	return th


static func box(bg: Color, edge: Color, width := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


## What a controller or the keyboard has chosen: a clear gold edge, drawn just outside the control
static func focus_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	s.set_expand_margin_all(3)
	return s


static func _font_colors(th: Theme, t: String) -> void:
	th.set_color("font_color", t, DIM)
	th.set_color("font_hover_color", t, PALE)
	th.set_color("font_focus_color", t, PALE)
	th.set_color("font_pressed_color", t, GOLD)
	th.set_color("font_hover_pressed_color", t, GOLD)
	th.set_color("font_disabled_color", t, Color(DIM, 0.4))


# Small pictures drawn here, so no image files are needed

static func _img(w: int, h: int, draw: Callable) -> ImageTexture:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var c: Color = draw.call(Vector2(x + 0.5, y + 0.5))
			if c.a > 0.0:
				im.set_pixel(x, y, c)
	return ImageTexture.create_from_image(im)


## Coverage of a rounded shape at p, softened over one pixel
static func _cover(d: float) -> float:
	return clampf(0.5 - d, 0.0, 1.0)


static func _capsule(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) - r


static func _switch(on: bool, alpha := 1.0) -> ImageTexture:
	return _img(46, 26, func(p: Vector2) -> Color:
		var knob_x := 33.0 if on else 13.0
		var k := _cover(p.distance_to(Vector2(knob_x, 13)) - 8.0)
		var track := _cover(_capsule(p, Vector2(13, 13), Vector2(33, 13), 11.0))
		var edge := _cover(absf(_capsule(p, Vector2(13, 13), Vector2(33, 13), 10.5)) - 0.75)
		var base := Color(GOLD, 0.55) if on else Color(1, 1, 1, 0.08)
		var c := Color(base.r, base.g, base.b, base.a * track)
		if not on:
			c = c.blend(Color(GOLD, 0.35 * edge))
		var kc := PALE if on else DIM
		c = c.blend(Color(kc, k))
		c.a *= alpha
		return c)


static func _tick(on: bool, alpha := 1.0) -> ImageTexture:
	return _img(24, 24, func(p: Vector2) -> Color:
		var q := (p - Vector2(12, 12)).abs() - Vector2(9, 9)
		var d := Vector2(maxf(q.x, 0), maxf(q.y, 0)).length() + minf(maxf(q.x, q.y), 0.0) - 1.5
		var c := Color(0.04, 0.04, 0.035, 0.9 * _cover(d))
		c = c.blend(Color(GOLD, (0.9 if on else 0.4) * _cover(absf(d) - 0.75)))
		if on:
			var m := minf(_capsule(p, Vector2(7, 12.5), Vector2(10.5, 16), 1.4), _capsule(p, Vector2(10.5, 16), Vector2(17, 8), 1.4))
			c = c.blend(Color(PALE, _cover(m)))
		c.a *= alpha
		return c)


static func _dot(on: bool) -> ImageTexture:
	return _img(16, 16, func(p: Vector2) -> Color:
		var d := p.distance_to(Vector2(8, 8))
		var c := Color(GOLD, 0.5 * _cover(absf(d - 5.5) - 0.6))
		if on:
			c = c.blend(Color(GOLD, _cover(d - 3.0)))
		return c)


static func _knob(col: Color) -> ImageTexture:
	return _img(20, 20, func(p: Vector2) -> Color:
		var d := p.distance_to(Vector2(10, 10))
		var c := Color(0, 0, 0, 0.5 * _cover(d - 8.5))
		return c.blend(Color(col, _cover(d - 7.0))))


static func _chevron() -> ImageTexture:
	return _img(16, 16, func(p: Vector2) -> Color:
		var m := minf(_capsule(p, Vector2(3.5, 6), Vector2(8, 10.5), 1.1), _capsule(p, Vector2(8, 10.5), Vector2(12.5, 6), 1.1))
		return Color(GOLD, 0.85 * _cover(m)))
