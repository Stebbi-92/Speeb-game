extends SceneTree
## Renders each item's kit model (Items.MODELS) to a small picture in assets/icons, for the pack.
## Run with a real renderer (not --headless), e.g. under xvfb:
##   xvfb-run -a godot --path . -s tools/icons.gd
## then `godot --headless --path . --import` and commit the pngs with their .import files.

const PX := 128

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D
var _todo: Array = []


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(PX, PX)
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.72, 0.68)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	_vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.45
	_vp.add_child(fill)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_todo = Items.MODELS.keys()
	_next()


func _next() -> void:
	if _todo.is_empty():
		print("ICONS done")
		quit()
		return
	var item: String = _todo.pop_front()
	for ch in _holder.get_children():
		ch.free()
	var m: Array = Items.MODELS[item]
	var piece := WIsleLife.make(m[0], m[1])
	_holder.add_child(piece)
	if m.size() > 2 and m[2]:
		var tint := StandardMaterial3D.new()
		tint.albedo_color = Items.info(item).color.lightened(0.15)
		tint.roughness = 0.8
		for mi in piece.find_children("*", "MeshInstance3D", true, false) + ([piece] if piece is MeshInstance3D else []):
			(mi as GeometryInstance3D).material_override = tint
	var bb := WIsleLife.bounds(m[0] + "/" + m[1], piece)
	piece.position = -bb.get_center()
	_holder.rotation = Vector3(0, deg_to_rad(-35), 0)
	var r := maxf(bb.size.y * 1.1, Vector2(bb.size.x, bb.size.z).length()) * 0.5
	_cam.size = r * 2.25
	_cam.position = Vector3(0, r * 1.1, r * 2.2)
	_cam.look_at(Vector3.ZERO)
	_cam.near = 0.01
	_cam.far = r * 10.0
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.save_png("res://assets/icons/%s.png" % item)
	print("ICON ", item)
	_next()
