extends SceneTree
## Splits each of Humans of the World's PS2-style pairs (CC-BY 4.0, see CREDITS.md) into its man and its woman,
## each a scene of its own (res://assets/models/people/<pair>_m.scn and _f.scn), with their own clips taken off
## (they walk on moves baked from Nerd Survivor's: tools/bake_stranger_moves.gd, see tools/make_people.sh).
## The men's bodies came out of their FBX in other units and turned about: a mesh whose vertices sit far off the
## bones they are bound to is moved, turned and scaled (one scale, never squeezed) to sit on them, by a least
## squares fit of each vertex to the middle of its main bone. Run:
##   godot --headless --path . -s tools/make_people.gd

const DIR := "res://assets/models/people/"
const PAIRS := ["nordic", "amerindian", "senegalese", "tamil"]


func _initialize() -> void:
	for n in PAIRS:
		for side in ["f", "m"]:
			var m: Node3D = (load(DIR + "ps2_%s_pair.glb" % n) as PackedScene).instantiate()
			root.add_child(m)
			for sk in m.find_children("*", "Skeleton3D", true, false):
				var arm: Node = sk.get_parent().get_parent()
				var female := str(arm.name).ends_with("_F")
				if female != (side == "f"):
					arm.get_parent().remove_child(arm)
					arm.free()
			for ap in m.find_children("*", "AnimationPlayer", true, false):
				ap.get_parent().remove_child(ap)
				ap.free()
			for mi in m.find_children("*", "MeshInstance3D", true, false):
				if mi.mesh and mi.skin:
					_fix(mi)
			_own(m, m)
			var ps := PackedScene.new()
			ps.pack(m)
			var out := DIR + "%s_%s.scn" % [n, side]
			print("SAVE ", out, " ", ResourceSaver.save(ps, out, ResourceSaver.FLAG_COMPRESS))
			m.queue_free()
	quit()


func _own(n: Node, top: Node) -> void:
	for c in n.get_children():
		c.owner = top
		_own(c, top)


static func _solve(A: Array, b: Array) -> Array:
	var n := b.size()
	for i in n:
		var p := i
		for r in range(i + 1, n):
			if absf(A[r][i]) > absf(A[p][i]):
				p = r
		var tmp = A[i]
		A[i] = A[p]
		A[p] = tmp
		var tb = b[i]
		b[i] = b[p]
		b[p] = tb
		for r in range(i + 1, n):
			var f: float = A[r][i] / A[i][i]
			for c in range(i, n):
				A[r][c] -= f * A[i][c]
			b[r] -= f * b[i]
	var x := []
	x.resize(n)
	for i in range(n - 1, -1, -1):
		var s: float = b[i]
		for c in range(i + 1, n):
			s -= A[i][c] * x[c]
		x[i] = s / A[i][i]
	return x


func _fix(mm: MeshInstance3D) -> void:
	var sk := mm.get_node(mm.skeleton) as Skeleton3D
	var arr := mm.mesh.surface_get_arrays(0)
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var B = arr[Mesh.ARRAY_BONES]
	var W = arr[Mesh.ARRAY_WEIGHTS]
	var per: int = B.size() / V.size()
	var X := []
	var mid := []
	for i in mm.skin.get_bind_count():
		var b := sk.find_bone(mm.skin.get_bind_name(i))
		X.append(sk.get_bone_global_rest(b) * mm.skin.get_bind_pose(i))
		var h := sk.get_bone_global_rest(b).origin
		var kids := sk.get_bone_children(b)
		var tail := h
		if kids.size() > 0:
			tail = Vector3.ZERO
			for k in kids:
				tail += sk.get_bone_global_rest(k).origin
			tail /= kids.size()
		mid.append((h + tail) * 0.5)
	var dom := []
	var err0 := 0.0
	for vi in V.size():
		var best := 0
		var bw := -1.0
		for j in per:
			if W[vi * per + j] > bw:
				bw = W[vi * per + j]
				best = B[vi * per + j]
		dom.append(best)
		err0 += ((X[best] as Transform3D) * V[vi] - mid[best]).length()
	err0 /= V.size()
	if err0 < 1.0 or mm.mesh.get_surface_count() != 1:
		return
	# Unknowns: M (row by row) and t, for v' = M v + t; each vertex's place is R (M v + t) + o
	var A := []
	for i in 12:
		A.append([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var rhs := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for vi in V.size():
		var T: Transform3D = X[dom[vi]]
		var R := T.basis
		var cols := [R.x, R.y, R.z]
		var tgt: Vector3 = mid[dom[vi]] - T.origin
		var v := V[vi]
		var J := []
		for r in 3:
			for c in 3:
				J.append(cols[r] * v[c])
		for r in 3:
			J.append(cols[r])
		for a in 12:
			for c in 12:
				A[a][c] += (J[a] as Vector3).dot(J[c])
			rhs[a] += (J[a] as Vector3).dot(tgt)
	var u := _solve(A, rhs)
	var M := Basis(Vector3(u[0], u[3], u[6]), Vector3(u[1], u[4], u[7]), Vector3(u[2], u[5], u[8]))
	# Moved, turned and scaled, never squeezed: M's turn (its polar part) and its longest scale
	var Q := M
	for it in 30:
		var qi := Q.inverse().transposed()
		Q = Basis((Q.x + qi.x) * 0.5, (Q.y + qi.y) * 0.5, (Q.z + qi.z) * 0.5)
	var sc := M.get_scale()
	var s := maxf(absf(sc.x), maxf(absf(sc.y), absf(sc.z)))
	M = Basis(Q.x * s, Q.y * s, Q.z * s)
	var acc := Vector3.ZERO
	for vi in V.size():
		acc += (X[dom[vi]] as Transform3D).affine_inverse() * mid[dom[vi]] - M * V[vi]
	var t := acc / V.size()
	var NV := PackedVector3Array()
	NV.resize(V.size())
	var err1 := 0.0
	for vi in V.size():
		NV[vi] = M * V[vi] + t
		err1 += ((X[dom[vi]] as Transform3D) * NV[vi] - mid[dom[vi]]).length()
	print("FIX ", mm.name, " off ", snappedf(err0, 0.01), " m -> ", snappedf(err1 / V.size(), 0.01), " m, scale ", snappedf(s, 0.0001))
	arr[Mesh.ARRAY_VERTEX] = NV
	var nm := M.inverse().transposed()
	if arr[Mesh.ARRAY_NORMAL] != null:
		var N: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in N.size():
			N[i] = (nm * N[i]).normalized()
		arr[Mesh.ARRAY_NORMAL] = N
	if arr[Mesh.ARRAY_TANGENT] != null:
		var Tg: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
		for i in Tg.size() / 4:
			var tv := (M * Vector3(Tg[i * 4], Tg[i * 4 + 1], Tg[i * 4 + 2])).normalized()
			Tg[i * 4] = tv.x
			Tg[i * 4 + 1] = tv.y
			Tg[i * 4 + 2] = tv.z
		arr[Mesh.ARRAY_TANGENT] = Tg
	var mat := mm.mesh.surface_get_material(0)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, _flags(mm.mesh))
	am.surface_set_material(0, mat)
	mm.mesh = am


static func _flags(m: Mesh) -> int:
	# Keeps 8 bone weights where the source had them
	return Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if (m.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) else 0
