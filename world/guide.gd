class_name WGuide
extends Control
## The first steps in the waste: one short task at a time, each done by doing it. Shown to a new
## survivor until the last step, and kept with the character. Turned off in Settings.

var w
var step := -1          ## which step is shown; -1 when the guide is done or was never wanted
var _from := Vector3.ZERO
var _base := 0
var _t := 0.0
var _seen := {}         ## things that happened: make, build, settlement, step_main, map, dawn
var _head: Label
var _text: Label
var _box: PanelContainer

## [id, what to do]. Keys are written as {action}.
const STEPS := [
	["walk", "Walk with {move_forward} {move_left} {move_back} {move_right}. Look around with the mouse."],
	["dodge", "Press {dash} to dodge. When a form's head swells and glows, it is about to bite: step aside."],
	["gather", "Hit a dead tree or a rock with {fire} to gather wood and stone."],
	["pack", "Open your pack with {pack}."],
	["make", "In your pack, open Make and make a bandage."],
	["build", "Press {build} to build. Place a campfire: you can rest by it, and it keeps the dark back."],
	["town", "Follow the gold diamond on the compass to Cinderwick."],
	["talk", "Speak with the elder of Cinderwick ({interact})."],
	["map", "Open the map with {map}. Right click marks a spot."],
	["night", "Live through the night. Rest by a fire or a bedroll to sleep through it."],
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(36, 142)
	size = Vector2(440, 90)
	_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.04, 0.55)
	sb.border_color = Color(0.86, 0.80, 0.66, 0.7)
	sb.border_width_left = 3
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	_box.add_theme_stylebox_override("panel", sb)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.custom_minimum_size.x = 440
	add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(v)
	_head = _lab(15, Color(0.86, 0.80, 0.66))
	v.add_child(_head)
	_text = _lab(19, Color(0.93, 0.92, 0.88))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 410
	v.add_child(_text)
	visible = false


func _lab(px: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func begin(at: int) -> void:
	step = at
	_enter()


func event(kind: String) -> void:
	_seen[kind] = true


func _enter() -> void:
	if step < 0 or step >= STEPS.size() or not Game.guide:
		visible = false
		return
	_from = Vector3.INF
	_base = w.inv.count("wood") + w.inv.count("stone")
	_seen.clear()
	_head.text = "First steps   %d of %d" % [step + 1, STEPS.size()]
	_text.text = _keys(STEPS[step][1])
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _keys(t: String) -> String:
	var re := RegEx.create_from_string("\\{([a-z_]+)\\}")
	for m in re.search_all(t):
		t = t.replace(m.get_string(0), "[%s]" % Game.key_text(m.get_string(1)))
	return t


func _done() -> bool:
	match STEPS[step][0]:
		"walk":
			return Vector2(w.player.global_position.x - _from.x, w.player.global_position.z - _from.z).length() > 12.0
		"dodge":
			return w.player.dodge_t > 0.0
		"gather":
			return w.inv.count("wood") + w.inv.count("stone") >= _base + 5
		"pack":
			return w.ui._panel_name == "pack"
		"make":
			return _seen.has("make")
		"build":
			return _seen.has("build")
		"town":
			return w.visited.has("cinderwick") or _seen.has("settlement")
		"talk":
			return w.quests.main_stage() > 0 or _seen.has("step_main")
		"map":
			return w.ui._panel_name == "map"
		"night":
			return _seen.has("dawn")
	return true


func _process(delta: float) -> void:
	if step < 0 or w == null or w.player == null:
		return
	if not Game.guide:
		visible = false
		return
	if not visible:
		_enter()
	# Kept out of the way of open screens
	_box.visible = w.ui == null or not w.ui.is_open() or STEPS[step][0] in ["make", "pack"]
	_t -= delta
	if _t > 0.0:
		return
	if _from == Vector3.INF:
		_from = w.player.global_position
		_base = w.inv.count("wood") + w.inv.count("stone")
		return
	_t = 0.4
	if _done():
		w.sfx("tick", -4, null, 1.4)
		step += 1
		if step >= STEPS.size():
			step = -1
			visible = false
			w.hud.notify("That is the way of it. The waste is yours to walk.")
		else:
			_enter()
		w.autosave_soon(5.0)
