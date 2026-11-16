extends Node3D
## Testing aid: each gun as the eye sees it aiming down its sights; saves one picture each.
## xvfb-run godot --path . res://tools/view_sights.tscn -- [mods=a,b]

func _ready() -> void:
	var root3 := self
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 60, 0)
	root3.add_child(sun)
	var mods: Array = []
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("mods="):
			mods = Array(a2.substr(5).split(","))
	Game.gilded = "gilded" in OS.get_cmdline_user_args()
	var a := Arms.new()
	var cam := Camera3D.new()
	cam.fov = 70
	cam.near = 0.01
	root3.add_child(cam)
	cam.current = true
	for g in ArmsDB.GUNS:
		var fit: Array = []
		for m in mods:
			if m in ArmsDB.GUNS[g].get("mounts", []):
				fit.append(m)
		var n: Node3D = a._build(g, fit)
		root3.add_child(n)
		cam.position = Vector3(0, float(n.get_meta("eye", 0.07)), 0.6)
		for f in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/sv/%s.png" % g)
		n.free()
	get_tree().quit()
