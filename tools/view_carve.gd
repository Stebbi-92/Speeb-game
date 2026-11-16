extends Node3D
## Testing aid: one gun from the right side with a 5 cm grid (lines every 10 cm are darker), to find where
## its parts are for carving. Each mesh piece is tinted its own colour. Saves /tmp/claude-0/carve_<gun>.png.
## xvfb-run godot --path . res://tools/view_carve.tscn -- only=shotgun

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.85, 0.87, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 80, 0)
	add_child(sun)
	var guns: Array = ["shotgun"]
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("only="):
			guns = Array(a2.substr(5).split(","))
	var a := Arms.new()
	Game.gilded = false
	for g in guns:
		var n: Node3D = a._build(g, [])
		add_child(n)
		var k := 0
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var tint := StandardMaterial3D.new()
			tint.albedo_color = Color.from_hsv(fmod(k * 0.27, 1.0), 0.6, 0.9, 0.35)
			tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			(mi as MeshInstance3D).material_overlay = tint
			k += 1
		if "split" in OS.get_cmdline_user_args():
			# The moving parts pulled out of place: the pump back, the magazine down
			if n.has_meta("pump"):
				(n.get_meta("pump") as Node3D).position.z += 0.1
			if n.has_meta("mag"):
				(n.get_meta("mag") as Node3D).position.y -= 0.1
		var lines := Node3D.new()
		add_child(lines)
		for i in range(-24, 13):
			var z := i * 0.05
			var b := MeshInstance3D.new()
			b.mesh = BoxMesh.new()
			(b.mesh as BoxMesh).size = Vector3(0.001, 0.6, 0.0015 if i % 2 else 0.003)
			b.position = Vector3(0.2, 0.0, z)
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.2, 0.2, 0.8) if i % 2 == 0 else Color(0.5, 0.5, 0.9)
			if i == 0:
				m.albedo_color = Color.RED
			b.material_override = m
			lines.add_child(b)
		for i in range(-6, 7):
			var y := i * 0.05
			var b := MeshInstance3D.new()
			b.mesh = BoxMesh.new()
			(b.mesh as BoxMesh).size = Vector3(0.001, 0.0015 if i % 2 else 0.003, 2.0)
			b.position = Vector3(0.2, y, -0.4)
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.2, 0.6, 0.2) if i % 2 == 0 else Color(0.5, 0.8, 0.5)
			if i == 0:
				m.albedo_color = Color.RED
			b.material_override = m
			lines.add_child(b)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 0.7
		cam.rotation_degrees = Vector3(0, 90, 0)
		cam.position = Vector3(1.0, 0.0, -0.25)
		add_child(cam)
		cam.current = true
		for f in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/carve_%s.png" % g)
		n.free()
		lines.free()
		cam.free()
	get_tree().quit()
