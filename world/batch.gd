class_name WBatch
extends RefCounted
## Gathers the still pieces of a place into a few meshes, one for each material, so the whole of a town
## is sent to be drawn in a few dozen calls instead of over a thousand. Only what never moves or changes
## is gathered: anything with a script of its own, anything that works (a door on its hinge, a fire, a
## chest, a bed, a crop) and anything named in `keep` stays as it was.

const CELL := 24.0   ## things drawn only near are gathered in squares this wide
const KEEP_META := ["hinge", "fire", "crop", "light", "veil", "label", "keep_apart"]


## Gathers the pieces under `roots` (all children of `holder`) into new meshes under `holder`.
## Gives back how many pieces were gathered.
static func merge(holder: Node3D, roots: Array, keep := {}) -> int:
	var found: Array = []
	for r in roots:
		if is_instance_valid(r):
			_collect(r, found, keep)
	if found.size() < 2:
		return 0
	# Small things drawn only near (a range of their own) are kept in cells, so each cell fades on its own
	var groups := {}
	for mi in found:
		var m: MeshInstance3D = mi
		var reach := m.visibility_range_end
		var cell := Vector2i.ZERO
		if reach > 0.0:
			cell = Vector2i(int(floor(m.global_position.x / CELL)), int(floor(m.global_position.z / CELL)))
		for s in m.mesh.get_surface_count():
			var mat: Material = m.material_override
			if mat == null:
				mat = m.get_surface_override_material(s)
			if mat == null:
				mat = m.mesh.surface_get_material(s)
			var key := [mat, reach, cell]
			if not groups.has(key):
				groups[key] = {"mat": mat, "reach": reach, "parts": [], "mid": Vector3.ZERO}
			groups[key].parts.append([m, s])
			groups[key].mid += m.global_position
	var inv := holder.global_transform.affine_inverse()
	for key in groups:
		var gr: Dictionary = groups[key]
		var mid: Vector3 = gr.mid / gr.parts.size()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in gr.parts:
			var m: MeshInstance3D = part[0]
			st.append_from(m.mesh, part[1], Transform3D(Basis.IDENTITY, -mid) * m.global_transform)
		var am: ArrayMesh = st.commit()
		if am == null or am.get_surface_count() == 0:
			continue
		var out := MeshInstance3D.new()
		out.mesh = am
		out.material_override = gr.mat
		if gr.reach > 0.0:
			out.visibility_range_end = gr.reach + CELL * 0.5
		holder.add_child(out)
		out.transform = inv * Transform3D(Basis.IDENTITY, mid)
	for mi in found:
		# A plain body that only gives the piece its solidity stays where it was
		for b in (mi as Node).get_children():
			var at: Transform3D = (b as Node3D).global_transform
			mi.remove_child(b)
			holder.add_child(b)
			b.global_transform = at
		mi.free()
	return found.size()


## A piece with nothing under it but a plain solid body (no script, no marks, only its shapes).
static func _bare(m: MeshInstance3D) -> bool:
	for b in m.get_children():
		if not (b is StaticBody3D) or b.get_script() != null or not b.get_meta_list().is_empty():
			return false
		for cs in b.get_children():
			if not (cs is CollisionShape3D):
				return false
	return true


static func _collect(n: Node, found: Array, keep: Dictionary) -> void:
	if n.get_script() != null or keep.has(n):
		return
	for k in KEEP_META:
		if n.has_meta(k):
			return
	# A piece that can be used (a bed, a bench, a chest) is left whole
	if n.has_meta("body"):
		var b = n.get_meta("body")
		if b is Object and is_instance_valid(b) and (b as Object).has_meta("on_interact"):
			return
	if n is CollisionObject3D and n.has_meta("on_interact"):
		return
	if n is MeshInstance3D:
		var m := n as MeshInstance3D
		if m.mesh != null and m.visible and _bare(m) and not (m.mesh is ImmediateMesh) \
				and m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY \
				and m.transparency == 0.0:
			found.append(m)
			return
	if n is Node3D and not (n as Node3D).visible:
		return
	for c in n.get_children():
		_collect(c, found, keep)


## Joins the still meshes within one thing (a node of wood or stone, a pile of rounds) into one mesh
## for each look, kept under it, so the thing still moves, shrinks and hides as one. Gives back how
## many pieces were joined.
static func flatten(n: Node3D) -> int:
	var found: Array = []
	_collect_within(n, n, found)
	if found.size() < 2:
		return 0
	var groups := {}
	for m in found:
		var mi := m as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			var key := [mat, mi.material_overlay]
			if not groups.has(key):
				groups[key] = {"mat": mat, "over": mi.material_overlay, "parts": [], "shadow": false, "reach": 0.0}
			var g: Dictionary = groups[key]
			g.parts.append([mi, s])
			g.shadow = g.shadow or mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.reach = maxf(g.reach, mi.visibility_range_end) if mi.visibility_range_end > 0.0 and g.reach >= 0.0 else -1.0
	for key in groups:
		var g: Dictionary = groups[key]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in g.parts:
			st.append_from((part[0] as MeshInstance3D).mesh, part[1], WTrees._chain(part[0], n))
		var am: ArrayMesh = st.commit()
		if am == null or am.get_surface_count() == 0:
			continue
		var out := MeshInstance3D.new()
		out.mesh = am
		out.material_override = g.mat
		out.material_overlay = g.over
		out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if g.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if float(g.reach) > 0.0:
			out.visibility_range_end = g.reach
		n.add_child(out)
	# Deepest first: a piece's own pieces are gone before it is
	for i in range(found.size() - 1, -1, -1):
		if is_instance_valid(found[i]):
			(found[i] as Node).free()
	return found.size()


static func _collect_within(n: Node, top: Node, found: Array) -> void:
	if n != top and n.get_script() != null:
		return
	if n is MeshInstance3D:
		var m := n as MeshInstance3D
		if not m.visible:
			return
		# A piece may hold more pieces (a round with its bullet set in it): all are joined, so long as
		# nothing else hangs beneath
		for c in m.get_children():
			if not c is MeshInstance3D:
				return
		if m.mesh != null and not (m.mesh is ImmediateMesh) and m.skin == null \
				and m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and m.transparency == 0.0:
			found.append(m)
		for c in m.get_children():
			_collect_within(c, top, found)
		return
	if n != top and n is Node3D and not (n as Node3D).visible:
		return
	for c in n.get_children():
		_collect_within(c, top, found)
