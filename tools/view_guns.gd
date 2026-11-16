extends Node3D
## Testing aid: the scanned guns under their plain-shape selves, seen from the right; saves a picture.
## xvfb-run godot --path . res://tools/view_guns.tscn

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
	var a := Arms.new()
	var i := 0
	for g in ["sniper", "pistol"]:
		for gild in [true, false]:
			Game.gilded = gild
			var n: Node3D = a._build(g, ["scope"] if g == "sniper" else [])
			n.position = Vector3(0, 0.3 if gild else 0.0, -i * 1.8)
			add_child(n)
			var tip := MeshInstance3D.new()
			tip.mesh = BoxMesh.new()
			(tip.mesh as BoxMesh).size = Vector3.ONE * 0.02
			tip.position = n.position + (n.get_meta("tip") as Vector3)
			add_child(tip)
			var hand := tip.duplicate()
			hand.position = n.position
			var red := StandardMaterial3D.new()
			red.albedo_color = Color.RED
			hand.material_override = red
			add_child(hand)
		i += 1
	Game.gilded = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.2
	cam.rotation_degrees = Vector3(0, 90, 0)
	cam.position = Vector3(3, 0.15, -0.9)
	add_child(cam)
	cam.current = true
	for f in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/guns_view.png")
	get_tree().quit()
