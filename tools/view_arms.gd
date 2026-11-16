extends SceneTree
## Testing aid: draws the scanned melee arms side by side, seen from the right, and saves a picture.
## xvfb-run godot --path . -s tools/view_arms.gd

func _initialize() -> void:
	var root3 := Node3D.new()
	root.add_child(root3)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 60, 0)
	root3.add_child(sun)
	var i := 0
	for id in Arms.SCANNED_MELEE:
		var sm: Array = Arms.SCANNED_MELEE[id]
		var n := Arms.scanned(sm[0], sm[1], sm[2], sm[3], sm[4], sm[5])
		n.position = Vector3(0, 0, i * 0.7)
		root3.add_child(n)
		var hand := MeshInstance3D.new()
		hand.mesh = BoxMesh.new()
		(hand.mesh as BoxMesh).size = Vector3.ONE * 0.04
		var red := StandardMaterial3D.new()
		red.albedo_color = Color.RED
		hand.material_override = red
		hand.position = n.position
		root3.add_child(hand)
		var edge := hand.duplicate()
		var blue := StandardMaterial3D.new()
		blue.albedo_color = Color.BLUE
		edge.material_override = blue
		edge.position = n.position + Vector3(0, 0, -0.2)
		root3.add_child(edge)
		i += 1
	var thrown_only := "thrown" in OS.get_cmdline_user_args()
	if thrown_only:
		for c in root3.get_children():
			if c is Node3D and not c is Camera3D and not c is DirectionalLight3D:
				c.free()
		i = 0
	for t in [["stick_grenade", -0.13, 0.26], ["molotov", -0.13, 0.26], ["flare", -0.1, 0.2], ["landmine", -0.035, 0.07]]:
		var n2 := Arms.scanned(t[0], Arms.THROWN_TURN.get(t[0], Vector3.ZERO), t[1], t[2])
		if n2:
			n2.position = Vector3(0, -0.6 if not thrown_only else 0.0, i * (0.7 if not thrown_only else 0.35))
			root3.add_child(n2)
		i += 1
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.2 if not thrown_only else 1.6
	root3.add_child(cam)
	cam.position = Vector3(5, 0.2, (i - 1) * 0.35)
	cam.rotation_degrees = Vector3(0, 90, 0)
	cam.current = true
	for f in 12:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/claude-0/arms_view.png")
	quit()
