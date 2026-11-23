extends SceneTree
## Splits "City Ruins Environment" (falk lochmann, CC BY 4.0) into its five rubble heaps, each set on its own
## base at the middle, in metres (the file's tenth-metres / 10), as assets/models/isles/ruin/ruin-heap-N.glb.
## Run: godot --headless --path . -s tools/split_ruins.gd -- <path to ruins_falk.glb>
func _initialize() -> void:
	var src: String = OS.get_cmdline_user_args()[0]
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(src, st) != OK:
		print("cannot read ", src)
		quit(1)
		return
	var scene: Node3D = doc.generate_scene(st)
	root.add_child(scene)
	await process_frame
	var n := 0
	for piece in scene.find_children("ruim_*", "Node3D", true, false):
		if not piece.name.begins_with("ruim_") or piece is MeshInstance3D:
			continue
		var bb := AABB()
		var first := true
		for mi in piece.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bb = a if first else bb.merge(a)
			first = false
		var out := Node3D.new()
		out.name = "RuinHeap"
		for mi in piece.find_children("*", "MeshInstance3D", true, false):
			var m := MeshInstance3D.new()
			m.name = mi.name
			m.mesh = (mi as MeshInstance3D).mesh
			var gt: Transform3D = (mi as MeshInstance3D).global_transform
			gt.origin -= Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
			m.transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.1), Vector3.ZERO) * gt
			out.add_child(m)
			m.owner = out
		n += 1
		var d2 := GLTFDocument.new()
		var s2 := GLTFState.new()
		d2.append_from_scene(out, s2)
		var path := "res://assets/models/isles/ruin/ruin-heap-%d.glb" % n
		d2.write_to_filesystem(s2, ProjectSettings.globalize_path(path))
		print("HEAP %d %s size %s m" % [n, piece.name, bb.size * 0.1])
	quit()
