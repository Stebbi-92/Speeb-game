extends Node3D
## Testing aid: every piece of the accessories pack, side on, each with its name; saves a picture.

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 60, 0)
	add_child(sun)
	var inst: Node3D = (load("res://assets/models/arms/accessories/accessories.glb") as PackedScene).instantiate()
	add_child(inst)
	var root := inst.find_child("RootNode", true, false)
	var i := 0
	for p in root.get_children():
		var bb := AABB()
		var first := true
		for mi in p.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bb = a if first else bb.merge(a)
			first = false
		print("PIECE ", p.name, " size=", bb.size, " center=", bb.get_center(), " kids=", p.find_children("*", "MeshInstance3D", true, false).map(func(x): return x.name))
		var holder := Node3D.new()
		add_child(holder)
		var s := 0.8 / maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
		p.reparent(holder, true)
		holder.scale = Vector3.ONE * s
		holder.position = Vector3(0, -(i / 6) * 1.1, -(i % 6) * 1.1) - bb.get_center() * s
		var l := Label3D.new()
		l.text = p.name
		l.font_size = 48
		l.pixel_size = 0.004
		l.rotation_degrees = Vector3(0, 90, 0)
		l.position = Vector3(0.5, -(i / 6) * 1.1 - 0.48, -(i % 6) * 1.1)
		add_child(l)
		i += 1
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.6
	cam.rotation_degrees = Vector3(0, 90, 0)
	cam.position = Vector3(5, -1.65, -2.75)
	add_child(cam)
	cam.current = true
	for f in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/acc_view.png")
	get_tree().quit()
