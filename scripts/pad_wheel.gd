class_name PadWheel
extends Control
## The controller's quick wheel: hold Back, point a stick at what you want, let go to use it.
## It carries what has no button of its own on a pad: healing, the whistle, smelling salts,
## the relics and the fellowship list. On a keyboard every one of these has its own key.

const HOLD := 0.2   ## held this long before the wheel shows (a quick tap shows it too, on release)
const ENTRIES := [
	["quick_heal", "Best healing"], ["whistle", "Whistle"], ["revive", "Smelling salts"], ["fellowship", "Fellowship"],
	["slot_1", "Relic 1"], ["slot_2", "Relic 2"], ["slot_3", "Relic 3"], ["slot_4", "Relic 4"], ["slot_5", "Relic 5"],
	["slot_6", "Relic 6"], ["slot_7", "Relic 7"], ["slot_8", "Claw"], ["slot_9", "Censer"],
]
## Read by polling (Input.is_action_just_pressed), so pressed for a frame; the rest are read as input events.
const POLLED := ["quick_heal", "whistle", "revive"]

var held := false
var _t := 0.0
var choice := -1
var _font: Font
var _release: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_font = load("res://assets/fonts/SourceSerif4.ttf")


func _usable() -> bool:
	return Game.main != null and Game.main.in_game() and not get_tree().paused


func _process(delta: float) -> void:
	# What was pressed last frame is let go now
	for a in _release:
		if a in POLLED:
			Input.action_release(a)
		else:
			var ev := InputEventAction.new()
			ev.action = a
			ev.pressed = false
			Input.parse_input_event(ev)
	_release.clear()
	var down := Input.is_action_pressed("pad_wheel") and _usable()
	if down:
		_t += delta
		held = true
		visible = _t >= HOLD
		var v := Vector2.ZERO
		for pad in Input.get_connected_joypads():
			for ax in [[JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y], [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]]:
				var s := Vector2(Input.get_joy_axis(pad, ax[0]), Input.get_joy_axis(pad, ax[1]))
				if s.length() > v.length():
					v = s
		if v.length() >= 0.5:
			choice = pick(v)
		queue_redraw()
	elif held:
		held = false
		visible = false
		_t = 0.0
		if choice >= 0 and _usable():
			use(choice)
		choice = -1


## Which entry a stick pointing this way chooses: the first sits at the top, and they go round clockwise.
static func pick(v: Vector2) -> int:
	var a := fposmod(atan2(v.x, -v.y), TAU)
	var step := TAU / ENTRIES.size()
	return int(round(a / step)) % ENTRIES.size()


## Uses an entry, as if its own key were pressed.
func use(i: int) -> void:
	var a: String = ENTRIES[i][0]
	if a in POLLED:
		Input.action_press(a)
	else:
		var ev := InputEventAction.new()
		ev.action = a
		ev.pressed = true
		Input.parse_input_event(ev)
	_release.append(a)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.22
	draw_circle(c, r * 1.35, Color(0, 0, 0, 0.45))
	for i in ENTRIES.size():
		var a := TAU * i / ENTRIES.size()
		var p := c + Vector2(sin(a), -cos(a)) * r
		var on := i == choice
		draw_circle(p, 34.0, Color(0.86, 0.80, 0.66, 0.85) if on else Color(0.1, 0.1, 0.1, 0.75))
		var t: String = ENTRIES[i][1]
		var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
		draw_string(_font, p + Vector2(-w * 0.5, 5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.1, 0.08, 0.05) if on else Color(0.93, 0.92, 0.88))
	var hint := "Point, then let go"
	var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
	draw_string(_font, c + Vector2(-hw * 0.5, 6), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.93, 0.92, 0.88, 0.8))
