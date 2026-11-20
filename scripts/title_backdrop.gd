extends Control
## Behind the title menu: stills of the waste, taken in the game, drifting slowly and fading one into
## the next, with embers rising and a dark side for the words to sit on. The look is set by the
## constants below, so it can be tuned without touching the menu itself.

## [picture, the place's name shown small at the bottom]
const SCENES := [
	["riders", "The rust dunes at dusk"],
	["town-cinderwick", "Cinderwick"],
	["beacon-night", "A beacon, kindled"],
	["region-rust-dunes", "The rust dunes"],
	["ruin-standing-stones", "The standing stones"],
	["great-one-lair", "A great one's lair"],
	["lighthouse", "The grey sea"],
]
const HOLD := 9.0        ## seconds each picture stays
const FADE := 2.5        ## seconds of cross-fade
const ZOOM := 0.07       ## how far each picture drifts in while it is shown
const SCRIM := 0.88      ## how dark the menu's side is (0 none, 1 black)
const SCRIM_REACH := 0.62  ## how far across the screen the dark side reaches
const DIM := 0.82        ## the pictures' brightness under the menu
const EMBERS := 46

var _a: TextureRect
var _b: TextureRect
var _i := 0
var _t := 0.0
var _caption: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_i = randi() % SCENES.size()
	_a = _pic(_i)
	_b = _pic((_i + 1) % SCENES.size())
	_b.modulate.a = 0.0
	# The dark side, left to right, and a soft dark at top and bottom
	add_child(_shade(GradientTexture2D.FILL_LINEAR, Vector2(0, 0.5), Vector2(1, 0.5),
		[Color(0, 0, 0, SCRIM), Color(0, 0, 0, SCRIM * 0.55), Color(0, 0, 0, 0)], [0.0, SCRIM_REACH * 0.55, SCRIM_REACH]))
	add_child(_shade(GradientTexture2D.FILL_LINEAR, Vector2(0.5, 0), Vector2(0.5, 1),
		[Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.7)], [0.0, 0.18, 0.75, 1.0]))
	_embers()
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 15)
	_caption.add_theme_color_override("font_color", Color(0.75, 0.70, 0.62, 0.75))
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_caption.position = Vector2(-640, -46)
	_caption.size = Vector2(600, 24)
	_caption.text = SCENES[_i][1]
	add_child(_caption)


func _pic(i: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://assets/title/%s.jpg" % SCENES[i][0])
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.self_modulate = Color(DIM, DIM, DIM)
	add_child(r)
	return r


func _shade(fill: int, from: Vector2, to: Vector2, colors: Array, offsets: Array) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = fill
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 256
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _embers() -> void:
	var p := CPUParticles2D.new()
	p.amount = EMBERS
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0.15, -1)
	p.spread = 18.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 46.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 3.2
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.55, 0.2, 0.0), Color(1.0, 0.6, 0.25, 0.9), Color(1.0, 0.35, 0.1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	p.color_ramp = g
	add_child(p)
	_place_embers.call_deferred(p)
	resized.connect(func(): _place_embers(p))


func _place_embers(p: CPUParticles2D) -> void:
	p.position = Vector2(size.x * 0.5, size.y + 10)
	p.emission_rect_extents = Vector2(size.x * 0.55, 10)


func _process(delta: float) -> void:
	_t += delta
	var into := clampf((_t - HOLD) / FADE, 0.0, 1.0)
	_drift(_a, _t / (HOLD + FADE), _i)
	_drift(_b, maxf(_t - HOLD, 0.0) / (HOLD + FADE), _i + 1)
	_b.modulate.a = into
	_caption.modulate.a = absf(into * 2.0 - 1.0) if into > 0.0 else 1.0
	if into >= 0.5 and _caption.text != SCENES[(_i + 1) % SCENES.size()][1]:
		_caption.text = SCENES[(_i + 1) % SCENES.size()][1]
	if _t >= HOLD + FADE:
		# The faded-in picture becomes the one shown; the other takes the next place
		_t = FADE
		_i = (_i + 1) % SCENES.size()
		var old := _a
		_a = _b
		_b = old
		_b.texture = load("res://assets/title/%s.jpg" % SCENES[(_i + 1) % SCENES.size()][0])
		_b.modulate.a = 0.0
		move_child(_b, _a.get_index())   # the next one waits behind


## A slow push in, each picture leaning a different way
func _drift(r: TextureRect, k: float, i: int) -> void:
	var s := 1.0 + ZOOM * clampf(k, 0.0, 1.2)
	r.pivot_offset = r.size * Vector2(0.5 + (0.12 if i % 2 == 0 else -0.12), 0.5)
	r.scale = Vector2(s, s)
