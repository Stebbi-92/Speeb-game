class_name AppearanceUI
extends PanelContainer
## How this pilgrim appears to the fellowship: a figure turning slowly in lamplight, and a choice
## for each part of them.

var hud
var _fig: Figure
var _rows: VBoxContainer
var _pivot: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.035, 0.96)
	sb.set_content_margin_all(40)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	center.add_child(row)
	# The figure, in a little world of its own
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(460, 640)
	svc.stretch = true
	row.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = false
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.055)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.48, 0.45)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	sv.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.5, 0)
	key.light_energy = 1.2
	key.light_color = Color(1.0, 0.92, 0.82)
	sv.add_child(key)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-1.0, 1.4, 1.2)
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.light_energy = 1.4
	lamp.omni_range = 4.0
	sv.add_child(lamp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 4.3)
	cam.fov = 30.0
	sv.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))
	var ground := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 0.9
	cm.height = 0.04
	ground.mesh = cm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.12, 0.11, 0.1)
	ground.material_override = gm
	ground.position.y = -0.02
	sv.add_child(ground)
	_pivot = Node3D.new()
	sv.add_child(_pivot)
	_fig = Figure.new().setup(Game.look)
	_fig.arms_forward = false
	_pivot.add_child(_fig)
	# The choices
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size.x = 560
	row.add_child(col)
	var t: Label = hud._label("Appearance", 46, hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	t.add_theme_font_override("font", hud.title_font)
	col.add_child(t)
	col.add_child(hud._label("How the fellowship and the people of the waste will see you.", 17, hud.DIM, HORIZONTAL_ALIGNMENT_LEFT))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	col.add_child(_rows)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 24)
	col.add_child(btns)
	btns.add_child(_btn("Chance", _random, 22, hud.PALE))
	var done := _btn("Done", _finish, 30, hud.GOLD)
	btns.add_child(done)
	_rebuild()


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.0004) * 0.9


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_finish()


func _btn(text: String, cb: Callable, size := 20, color: Color = Color(0.93, 0.92, 0.88)) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", hud.GOLD)
	b.pressed.connect(cb)
	return b


func _rebuild() -> void:
	for c in _rows.get_children():
		c.queue_free()
	for k in Figure.ORDER:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		_rows.add_child(r)
		var head: Label = hud._label(Figure.LABELS[k], 20, hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		head.custom_minimum_size.x = 170
		r.add_child(head)
		r.add_child(_btn("‹", _step.bind(k, -1), 26))
		var v: Label = hud._label(Figure.OPTIONS[k][int(Game.look[k])], 20, hud.PALE, HORIZONTAL_ALIGNMENT_CENTER)
		v.custom_minimum_size.x = 240
		r.add_child(v)
		r.add_child(_btn("›", _step.bind(k, 1), 26))


func _step(k: String, d: int) -> void:
	Game.look[k] = posmod(int(Game.look[k]) + d, Figure.OPTIONS[k].size())
	_refresh()


func _random() -> void:
	Game.look = Figure.seeded(randi())
	_refresh()


func _refresh() -> void:
	_fig.look = Figure.clean(Game.look)
	_fig.rebuild()
	_rebuild()


func _finish() -> void:
	Game.look = Figure.clean(Game.look)
	Game.save()
	Net.send_look()
	queue_free()
