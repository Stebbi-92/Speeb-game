class_name WTrees
## Living trees for the woods and the isles, from four free packs (CC-BY 4.0): "Mountain Trees" by Jagobo,
## "Conifer (medium-Poly)" by Sereib, "Scots Pine Trees Set" by Maksim Batyrev and "Coniferous Forest Assets
## Pack" by Dari. Each pack holds several trees; each tree is found by where its parts stand, its parts made
## into one mesh standing on its own foot, brought to a true height, and drawn in batches. Their trunks are solid.

## pack: [file, height of its tallest tree in metres, names of parts to leave out]
const PACKS := {
	"mountain": ["res://assets/models/trees/mountain_trees.glb", 17.0, ["Plane"]],
	"conifer": ["res://assets/models/trees/conifer.glb", 13.0, []],
	"scots": ["res://assets/models/trees/scots_pines.glb", 19.0, ["Box001"]],
	"coniferous": ["res://assets/models/trees/coniferous_pack.glb", 18.0, ["Boulder"]],
}

static var _kinds := {}   ## pack -> [[mesh, trunk radius, height], ...]


## The trees of a pack, each [ArrayMesh with its foot at the origin, trunk radius, height].
static func kinds(pack: String) -> Array:
	if _kinds.has(pack):
		return _kinds[pack]
	var spec: Array = PACKS[pack]
	var out: Array = []
	if not ResourceLoader.exists(spec[0]):
		_kinds[pack] = out
		return out
	var m: Node3D = (load(spec[0]) as PackedScene).instantiate()
	# Every part, with its place in the pack and its bounds there
	var parts: Array = []
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var skip := false
		for bad in spec[2]:
			if str(bad) in str(mi.name) or str(bad) in str(mi.get_parent().name):
				skip = true
		var mm := mi as MeshInstance3D
		if skip or mm.mesh == null:
			continue
		var tr := _chain(mm, m)
		parts.append([mm, tr, tr * mm.get_aabb()])
	# One tree: the parts that share a number in their names (the pines), or whose bounds overlap
	# seen from above (the others), joined until no two groups overlap
	var groups: Array = []
	var num := RegEx.create_from_string("^(\\d+)_")
	for p in parts:
		var key := ""
		if pack == "coniferous":
			var up: Node = p[0]
			while up.get_parent() and up.get_parent().name != "GLTF_SceneRootNode":
				up = up.get_parent()
			key = str(up.name)
		elif pack == "scots":
			for nm in [str(p[0].name), str(p[0].get_parent().name), str((p[0] as MeshInstance3D).mesh.resource_name)]:
				var hit := num.search(nm)
				if hit:
					key = hit.get_string(1)
					break
		groups.append({"parts": [p], "box": p[2], "key": key})
	var joined := true
	while joined:
		joined = false
		for i in groups.size():
			for j in range(i + 1, groups.size()):
				var gi: Dictionary = groups[i]
				var gj: Dictionary = groups[j]
				var same := false
				if pack in ["scots", "coniferous"]:
					same = gi.key != "" and gi.key == gj.key
				else:
					same = _overlap(gi.box, gj.box) > 0.3
				if same:
					gi.parts.append_array(gj.parts)
					gi.box = (gi.box as AABB).merge(gj.box)
					groups.remove_at(j)
					joined = true
					break
			if joined:
				break
	var tallest := 0.0
	for g in groups:
		tallest = maxf(tallest, (g.box as AABB).size.y)
	var k: float = float(spec[1]) / maxf(tallest, 0.001)
	for g in groups:
		var box: AABB = g.box
		if box.size.y * k < 0.8:
			continue
		# The foot: the middle of its lowest tenth, where the trunk meets the ground
		var foot := Vector3(box.get_center().x, box.position.y, box.get_center().z)
		var low := box.position.y + box.size.y * 0.1
		var fsum := Vector3.ZERO
		var fn := 0
		var trunk := 0.0
		for p in g.parts:
			var b: AABB = p[2]
			if b.position.y <= low:
				fsum += Vector3(b.get_center().x, 0, b.get_center().z)
				fn += 1
				trunk = maxf(trunk, minf(b.size.x, b.size.z))
		if fn > 0:
			foot = Vector3(fsum.x / fn, box.position.y, fsum.z / fn)
		var place := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), -foot * k)
		var mesh := ArrayMesh.new()
		for p in g.parts:
			_add(mesh, p[0], place * (p[1] as Transform3D))
		# A trunk's girth: a fifth of the spread of its lowest parts, kept within reason
		var r := clampf(trunk * k * 0.2, 0.18, 0.7) if trunk > 0.0 else 0.3
		out.append([mesh, r, box.size.y * k])
	m.free()
	_kinds[pack] = out
	return out


## How much of the smaller of two bounds lies over the other, seen from above (0 to 1).
static func _overlap(a: AABB, b: AABB) -> float:
	var x := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var z := minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
	if x <= 0.0 or z <= 0.0:
		return 0.0
	return x * z / maxf(minf(a.size.x * a.size.z, b.size.x * b.size.z), 0.0001)


static func _chain(mi: Node, top: Node) -> Transform3D:
	var tr: Transform3D = (mi as Node3D).transform
	var p: Node = mi.get_parent()
	while p and p != top:
		tr = (p as Node3D).transform * tr
		p = p.get_parent()
	return tr


static func _add(mesh: ArrayMesh, mi: MeshInstance3D, tr: Transform3D) -> void:
	var nb := tr.basis.inverse().transposed()
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in v.size():
			v[i] = tr * v[i]
		arr[Mesh.ARRAY_VERTEX] = v
		if arr[Mesh.ARRAY_NORMAL] != null:
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in n.size():
				n[i] = (nb * n[i]).normalized()
			arr[Mesh.ARRAY_NORMAL] = n
		if arr[Mesh.ARRAY_TANGENT] != null:
			var t: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
			for i in range(0, t.size(), 4):
				var tv := (tr.basis * Vector3(t[i], t[i + 1], t[i + 2])).normalized()
				t[i] = tv.x
				t[i + 1] = tv.y
				t[i + 2] = tv.z
			arr[Mesh.ARRAY_TANGENT] = t
		# Skinning and blend shapes have no place on a still tree
		arr[Mesh.ARRAY_BONES] = null
		arr[Mesh.ARRAY_WEIGHTS] = null
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat: Material = mi.get_surface_override_material(s)
		if mat == null:
			mat = mi.mesh.surface_get_material(s)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


## Every tree of every pack, for scattering: [pack, index, mesh, trunk radius, height].
static func all() -> Array:
	var out: Array = []
	for pack in PACKS:
		var ks := kinds(pack)
		for i in ks.size():
			out.append([pack, i, ks[i][0], ks[i][1], ks[i][2]])
	return out


## How often each pack is picked: the light pines most, the heavy mountain trees least.
const MIX := {"scots": 0.45, "coniferous": 0.25, "conifer": 0.12, "mountain": 0.18}
const FAR := 520.0   ## past this a tree is not drawn


static func _pick(rr: RandomNumberGenerator, mix: Dictionary) -> Array:
	var all_w := 0.0
	for k in mix:
		if not kinds(k).is_empty():
			all_w += float(mix[k])
	var x := rr.randf() * all_w
	for k in mix:
		var ks := kinds(k)
		if ks.is_empty():
			continue
		x -= float(mix[k])
		if x <= 0.0:
			var i := rr.randi() % ks.size()
			return [k, i]
	return []


## Trees at the given feet (world places), under one holder: drawn in a batch for each kind, each
## trunk an upright cylinder you cannot walk through. Each gets its own turn, size and lean.
static func plant(w, feet: Array, rr: RandomNumberGenerator, mix := MIX, size_lo := 0.75, size_hi := 1.15) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Trees"
	w.add_child(holder)
	if feet.is_empty():
		return holder
	var mid := Vector3.ZERO
	for f in feet:
		mid += f
	mid /= feet.size()
	holder.global_position = mid
	var by_kind := {}
	var cuts: Array = []   # each tree, to be cut down: [kind, place in its batch, trunk, foot, height, girth, its place there]
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	holder.add_child(body)
	for f in feet:
		var pick := _pick(rr, mix)
		if pick.is_empty():
			continue
		var k: Array = kinds(pick[0])[pick[1]]
		var s := rr.randf_range(size_lo, size_hi)
		var b := Basis(Vector3.UP, rr.randf() * TAU).scaled(Vector3.ONE * s)
		b = Basis(Vector3(1, 0, 0), rr.randf_range(-0.03, 0.03)) * b
		var t := Transform3D(b, (f as Vector3) - mid - Vector3(0, 0.15, 0))
		var key := "%s/%d" % pick
		if not by_kind.has(key):
			by_kind[key] = [k[0], []]
		by_kind[key][1].append(t)
		var cs := CollisionShape3D.new()
		cuts.append([key, by_kind[key][1].size() - 1, cs, f, float(k[2]) * s, float(k[1]) * s, t])
		var cyl := CylinderShape3D.new()
		cyl.radius = float(k[1]) * s
		cyl.height = minf(float(k[2]) * s, 6.0)
		cs.shape = cyl
		cs.position = (f as Vector3) - mid + Vector3(0, cyl.height * 0.5, 0)
		body.add_child(cs)
	for key in by_kind:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = by_kind[key][0]
		var ts: Array = by_kind[key][1]
		mm.instance_count = ts.size()
		for i in ts.size():
			mm.set_instance_transform(i, ts[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = FAR
		mmi.visibility_range_end_margin = 40.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		holder.add_child(mmi)
		by_kind[key].append(mmi)
	# Every tree can be cut down (see WFell): nothing more is made for it until it is struck
	if w.get("woodcut") is WFell:
		for c in cuts:
			c[0] = by_kind[c[0]][2]
		w.woodcut.add_stand("t", body, cuts)
	return holder


## The living woods: stands of trees across the forest land, in clumps with glades between, in tiles
## small enough that the far ones are left out. Kept off places, roads and water.
static func woods(w) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = w.world_seed + 7731
	var half := 950.0
	var tile := 160.0
	var tiles := {}
	var stands := 0
	var tries := 0
	while stands < 70 and tries < 4000:
		tries += 1
		var c := Vector2(rr.randf_range(-half, half), rr.randf_range(-half, half))
		if w.terrain.biome_name(c.x, c.y) != "forest" or w.terrain.is_water(c.x, c.y, 0.5):
			continue
		stands += 1
		# A clump: a dozen or so trees within thirty metres
		for i in rr.randi_range(8, 16):
			var q := c + Vector2(rr.randf_range(-1, 1), rr.randf_range(-1, 1)) * 30.0
			if w.terrain.biome_name(q.x, q.y) != "forest" or w.terrain.is_water(q.x, q.y, 0.5):
				continue
			if not w._clear_of_places(q, 40.0, 14.0):
				continue
			if w.terrain.normal_at(q.x, q.y).y < 0.8:
				continue
			var key := Vector2i(int(floor(q.x / tile)), int(floor(q.y / tile)))
			if not tiles.has(key):
				tiles[key] = []
			tiles[key].append(Vector3(q.x, w.terrain.height_at(q.x, q.y), q.y))
	for key in tiles:
		plant(w, tiles[key], rr)
