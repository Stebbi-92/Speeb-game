class_name WShells
## Whole buildings that stand outside the towns' walls and alone in the open waste: farmsteads, barns and
## log houses from free packs (CC-BY 4.0, see CREDITS.md). You cannot go into them; their walls are solid.
## The houses inside the towns stay the kit-built ones you can walk into.
## Each building's parts are joined into one mesh with one surface for each material, so it draws cheaply.

## pack: [file, height of its tallest building in metres, how its buildings are found, parts to leave out]
## "one": the whole file is one building. "top": each part under the top node is a building of its own.
## "split": the file's parts are cut by material, not by building (one mesh holds the walls of half a
## hamlet), so its buildings are found as the islands of triangles standing apart on the ground.
const PACKS := {
	"barn": ["res://assets/models/buildings/abandoned_barn.glb", 9.5, "one", []],
	"izba": ["res://assets/models/buildings/russian_izba.glb", 7.0, "one", ["cobwebs", "ground_plane"]],
	"village": ["res://assets/models/buildings/belarusian_village.glb", 15.0, "split", []],   # its windmill: drawn true to size
	"logs": ["res://assets/models/buildings/medieval_log_buildings.glb", 7.5, "top", ["Wall_tip", "Object005", "Object006"]],
	"saloon": ["res://assets/models/buildings/western_bar.glb", 8.0, "one", []],
	"frame": ["res://assets/models/buildings/western_house.glb", 6.5, "one", []],
}

## Which packs stand about the towns of each land.
const BY_LAND := {
	"ash": ["izba", "logs", "village"], "dunes": ["saloon", "frame", "village"], "salt": ["frame", "village", "izba"],
	"forest": ["logs", "izba", "village"], "basalt": ["logs", "village"], "marsh": ["izba", "village", "logs"],
}

## How each land greys or browns what stands in it.
const TINT := {"ash": Color(0.72, 0.7, 0.68), "dunes": Color(0.95, 0.88, 0.76), "salt": Color(0.9, 0.9, 0.88),
	"forest": Color(0.78, 0.76, 0.7), "basalt": Color(0.66, 0.66, 0.68), "marsh": Color(0.68, 0.7, 0.64)}

const FAR := 650.0

static var _kinds := {}   ## pack -> [[mesh, bounds], ...] (feet at the origin, true size)


static func kinds(pack: String) -> Array:
	if _kinds.has(pack):
		return _kinds[pack]
	var spec: Array = PACKS[pack]
	var out: Array = []
	_kinds[pack] = out
	if not ResourceLoader.exists(spec[0]):
		return out
	var m: Node3D = (load(spec[0]) as PackedScene).instantiate()
	# The parts of each building
	var groups: Array = []
	var made: Array = []   ## meshes cut out for "split", freed with the model
	if spec[2] == "split":
		groups = _islands(_parts(m, m, spec[3]), made)
	elif spec[2] == "top":
		var top: Node = m
		while top.get_child_count() == 1:
			top = top.get_child(0)
		for c in top.get_children():
			groups.append(_parts(c, m, spec[3]))
	else:
		groups.append(_parts(m, m, spec[3]))
	var built: Array = []
	var tallest := 0.0
	for g in groups:
		if g.is_empty():
			continue
		var box := AABB()
		var first := true
		for p in g:
			var b: AABB = (p[1] as Transform3D) * _box_of(p[0])
			box = b if first else box.merge(b)
			first = false
		built.append([g, box])
		tallest = maxf(tallest, box.size.y)
	var k: float = float(spec[1]) / maxf(tallest, 0.001)
	for bg in built:
		var box: AABB = bg[1]
		if box.size.y * k < 2.0:
			continue   # a fence or a heap, not a building
		# Its foot: where most of it stands, by the ground each part covers. A stray part that hangs below
		# must not sink it, and a row of small parts higher up (shutters, hinges) must not either
		var bottoms: Array = []
		for p in bg[0]:
			var pb: AABB = (p[1] as Transform3D) * _box_of(p[0])
			bottoms.append([pb.position.y, maxf(pb.size.x * pb.size.z, 0.01)])
		var best_y := box.position.y
		var best_n := -1.0
		for b in bottoms:
			var n := 0.0
			for b2 in bottoms:
				if absf(float(b2[0]) - float(b[0])) < box.size.y * 0.05:
					n += float(b2[1])
			if n > best_n + 0.001 or (absf(n - best_n) <= 0.001 and float(b[0]) < best_y):
				best_n = n
				best_y = b[0]
		var foot := Vector3(box.get_center().x, best_y, box.get_center().z)
		var place := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), -foot * k)
		out.append([_join(bg[0], place), AABB((box.position - foot) * k, box.size * k)])
	m.free()
	for mi in made:
		(mi as Node).free()
	return out


## The parts' triangles gathered into islands: triangles over the same patch of ground (a cell of
## ISLAND_CELL metres) belong together. Each island comes back as parts of its own, [mesh, transform].
const ISLAND_CELL := 1.0

static func _islands(parts: Array, made: Array) -> Array:
	var tris: Array = []   # [part, surface, face]
	var mdts := {}
	var parent: Array[int] = []   # union-find over the triangles (an Array: it is shared, not copied, when passed)
	var cell_of := {}
	for pi in parts.size():
		var mi: MeshInstance3D = parts[pi][0]
		var t: Transform3D = parts[pi][1]
		for si in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var mdt := MeshDataTool.new()
			if mdt.create_from_surface(mi.mesh as ArrayMesh, si) != OK:
				continue
			mdts[Vector2i(pi, si)] = mdt
			for f in mdt.get_face_count():
				var ti := tris.size()
				tris.append(Vector3i(pi, si, f))
				parent.append(ti)
				var lo := Vector2(INF, INF)
				var hi := Vector2(-INF, -INF)
				for k in 3:
					var v: Vector3 = t * mdt.get_vertex(mdt.get_face_vertex(f, k))
					lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.z))
					hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.z))
				for cx in range(floori(lo.x / ISLAND_CELL), floori(hi.x / ISLAND_CELL) + 1):
					for cz in range(floori(lo.y / ISLAND_CELL), floori(hi.y / ISLAND_CELL) + 1):
						var key := Vector2i(cx, cz)
						if cell_of.has(key):
							_union(parent, ti, cell_of[key])
						else:
							cell_of[key] = ti
	var by_root := {}
	for ti in tris.size():
		var r := _find(parent, ti)
		if not by_root.has(r):
			by_root[r] = {}
		var tr: Vector3i = tris[ti]
		var key := Vector2i(tr.x, tr.y)
		if not by_root[r].has(key):
			by_root[r][key] = []
		(by_root[r][key] as Array).append(tr.z)
	var out: Array = []
	for r in by_root:
		var group: Array = []
		for key in by_root[r]:
			var mdt: MeshDataTool = mdts[key]
			var src: MeshInstance3D = parts[key.x][0]
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var box := AABB(mdt.get_vertex(mdt.get_face_vertex(by_root[r][key][0], 0)), Vector3.ZERO)
			for f in by_root[r][key]:
				for k in 3:
					var vi := mdt.get_face_vertex(f, k)
					box = box.expand(mdt.get_vertex(vi))
					st.set_normal(mdt.get_vertex_normal(vi))
					st.set_uv(mdt.get_vertex_uv(vi))
					st.set_color(mdt.get_vertex_color(vi))
					st.add_vertex(mdt.get_vertex(vi))
			var mat: Material = src.get_surface_override_material(key.y)
			st.set_material(mat if mat else src.mesh.surface_get_material(key.y))
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.set_meta("box", box)   # its bounds, known without asking the renderer
			made.append(mi)
			group.append([mi, parts[key.x][1]])
		out.append(group)
	return out


## A part's bounds in its own space.
static func _box_of(mi: MeshInstance3D) -> AABB:
	return mi.get_meta("box") if mi.has_meta("box") else mi.mesh.get_aabb()


static func _find(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: Array[int], a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb


static func _parts(n: Node, top: Node, skip: Array) -> Array:
	var out: Array = []
	var all := n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		all.append(n)
	for mi in all:
		var mm := mi as MeshInstance3D
		if mm.mesh == null:
			continue
		var bad := false
		for s in skip:
			var up: Node = mm
			while up and up != top:
				if str(s) in str(up.name):
					bad = true
				up = up.get_parent()
		if not bad:
			out.append([mm, WTrees._chain(mm, top)])
	return out


## The parts as one mesh: one surface for each material.
static func _join(parts: Array, place: Transform3D) -> ArrayMesh:
	var by_mat := {}
	for p in parts:
		var mi: MeshInstance3D = p[0]
		for s in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if not by_mat.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_mat[mat] = st
			(by_mat[mat] as SurfaceTool).append_from(mi.mesh, s, place * (p[1] as Transform3D))
	var mesh := ArrayMesh.new()
	for mat in by_mat:
		var st: SurfaceTool = by_mat[mat]
		st.set_material(mat)
		st.commit(mesh)
	return mesh


## One building, standing at local `at` under parent, with solid walls (a box a little inside its bounds).
static func put(parent: Node3D, pack: String, i: int, at: Vector3, yaw: float, s := 1.0, tint := Color(1, 1, 1)) -> Node3D:
	var ks := kinds(pack)
	if ks.is_empty():
		return null
	var kd: Array = ks[i % ks.size()]
	var n := Node3D.new()
	n.position = at
	n.rotation.y = yaw
	parent.add_child(n)
	var mi := MeshInstance3D.new()
	mi.mesh = kd[0]
	mi.scale = Vector3.ONE * s
	mi.visibility_range_end = FAR
	mi.visibility_range_end_margin = 40.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if tint != Color(1, 1, 1):
		var mesh: ArrayMesh = kd[0]
		for si in mesh.get_surface_count():
			var sm := mesh.surface_get_material(si)
			if sm is StandardMaterial3D:
				var t: StandardMaterial3D = _tinted(sm, tint)
				mi.set_surface_override_material(si, t)
	n.add_child(mi)
	var bb: AABB = kd[1]
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(bb.size.x * 0.92, bb.size.y * 0.8, bb.size.z * 0.92) * s
	cs.shape = box
	cs.position = Vector3(bb.get_center().x, bb.size.y * 0.4, bb.get_center().z) * s
	body.add_child(cs)
	n.add_child(body)
	return n


static var _tints := {}

static func _tinted(m: StandardMaterial3D, tint: Color) -> StandardMaterial3D:
	var key := [m, tint]
	if _tints.has(key):
		return _tints[key]
	var t: StandardMaterial3D = m.duplicate()
	t.albedo_color = m.albedo_color * tint
	_tints[key] = t
	return t


## How far the land may fall across a building's footprint before it is not put there (metres).
const MAX_FALL := 1.0


## The lowest and highest ground under a building's walls (its bounds' corners, edges and middle), at g turned yaw.
static func ground_under(w, pack: String, i: int, g: Vector2, yaw: float, s := 1.0) -> Vector2:
	var ks := kinds(pack)
	if ks.is_empty():
		return Vector2(w.terrain.height_at(g.x, g.y), w.terrain.height_at(g.x, g.y))
	var bb: AABB = ks[i % ks.size()][1]
	var lo := INF
	var hi := -INF
	for tx in [0.0, 0.5, 1.0]:
		for tz in [0.0, 0.5, 1.0]:
			var l := Vector3(bb.position.x + bb.size.x * tx, 0, bb.position.z + bb.size.z * tz).rotated(Vector3.UP, yaw) * s
			var h: float = w.terrain.height_at(g.x + l.x, g.y + l.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi)


## The radius a building needs on the ground.
static func reach(pack: String, i: int, s := 1.0) -> float:
	var ks := kinds(pack)
	if ks.is_empty():
		return 0.0
	var bb: AABB = ks[i % ks.size()][1]
	return 0.5 * Vector2(bb.size.x, bb.size.z).length() * s


## Farmsteads about each town, outside its wall: a few buildings of its land's kinds, off the gate roads.
static func outskirts(w) -> int:
	var placed := 0
	for k in WPlaces.SETTLEMENTS:
		var c: Vector3 = w.gpos(WPlaces.spos(k))
		var land: String = w.terrain.biome_name(c.x, c.z)
		var packs: Array = BY_LAND.get(land, BY_LAND.ash)
		var rr := RandomNumberGenerator.new()
		rr.seed = hash(k + "outskirts")
		var holder := Node3D.new()
		holder.name = "Outskirts"
		holder.position = c
		w.add_child(holder)
		var taken: Array = []
		var want := rr.randi_range(3, 5)
		for t in 80:
			if taken.size() >= want:
				break
			var a := rr.randf() * TAU
			# Not across a gate road
			if minf(absf(wrapf(a - PI * 0.5, -PI, PI)), absf(wrapf(a + PI * 0.5, -PI, PI))) < 0.55:
				continue
			var pack: String = packs[rr.randi() % packs.size()]
			var i := rr.randi() % maxi(1, kinds(pack).size())
			var fr := reach(pack, i)
			if fr <= 0.0:
				continue
			var off: Vector2 = Vector2(cos(a), sin(a)) * (w.town_wall_r(k, a) + fr + rr.randf_range(4.0, 12.0))
			var g: Vector2 = Vector2(c.x, c.z) + off
			if w.terrain.is_water(g.x, g.y, 1.0) or w.terrain.normal_at(g.x, g.y).y < 0.88:
				continue
			var clash := false
			for o in taken:
				if (o[0] as Vector2).distance_to(off) < fr + float(o[1]) + 3.0:
					clash = true
			for bp in WPlaces.beacon_points():
				if bp.distance_to(g) < 20.0:
					clash = true
			if clash:
				continue
			var face := atan2(-off.x, -off.y) + rr.randf_range(-0.4, 0.4)
			# Set on the lowest ground under its walls, so no corner hangs in the air; where the land falls
			# too far across it, its high side (and its door) would be sunk deep, so it is put elsewhere
			var under := ground_under(w, pack, i, g, face)
			if under.y - under.x > MAX_FALL:
				continue
			taken.append([off, fr])
			put(holder, pack, i, Vector3(off.x, under.x - c.y - 0.15, off.y), face, 1.0, TINT.get(land, Color(1, 1, 1)))
			# What a farm leaves about its door
			for j in 2:
				var po: Vector2 = off + Vector2(cos(a + 0.6 * (j * 2 - 1)), sin(a + 0.6 * (j * 2 - 1))) * -(fr + 1.5)
				var pick: Array = [["barrel_03", 1.0, true], ["cement_bag", 1.2, false], ["old_military_crate", 1.2, true], ["wooden_bucket_01", 1.0, false]][rr.randi() % 4]
				WDress.kp(holder, "scan", pick[0], Vector3(po.x, w.terrain.height_at(c.x + po.x, c.z + po.y) - c.y, po.y), rr.randf() * TAU, pick[1], pick[2])
			placed += 1
	w.set_meta("shells_out", placed)
	return placed


## Barns left standing alone in the open waste, a landmark seen from afar, with what was left about them.
static func lone_barns(w, count := 7) -> int:
	var rr := RandomNumberGenerator.new()
	rr.seed = w.world_seed + 4417
	var placed := 0
	var spots: Array = []
	for t in 600:
		if placed >= count:
			break
		var p := Vector2(rr.randf_range(-900, 900), rr.randf_range(-900, 900))
		if w.terrain.is_water(p.x, p.y, 2.0) or w.terrain.normal_at(p.x, p.y).y < 0.92:
			continue
		if not w._clear_of_places(p, 90.0, 40.0):
			continue
		var far_enough := true
		for s in spots:
			if (s as Vector2).distance_to(p) < 220.0:
				far_enough = false
		if not far_enough:
			continue
		var land: String = w.terrain.biome_name(p.x, p.y)
		var pack := "barn" if placed % 2 == 0 else ("izba" if land != "dunes" else "saloon")
		var yaw := rr.randf() * TAU
		# On the lowest ground under its walls, as the farmsteads are, and not where the land falls too far across it
		var under := ground_under(w, pack, 0, p, yaw)
		if under.y - under.x > MAX_FALL:
			continue
		spots.append(p)
		var holder := Node3D.new()
		holder.name = "LoneBarn"
		holder.position = Vector3(p.x, w.terrain.height_at(p.x, p.y), p.y)
		w.add_child(holder)
		put(holder, pack, 0, Vector3(0, under.x - holder.position.y - 0.15, 0), yaw, 1.0, TINT.get(land, Color(1, 1, 1)))
		var fr := reach(pack, 0)
		for j in 4:
			var a := rr.randf() * TAU
			var po := Vector2(cos(a), sin(a)) * (fr + rr.randf_range(1.5, 5.0))
			var pick: Array = [["old_tyre", 1.1, false], ["barrel_stove", 1.0, true], ["rusted_wheel_rim_02", 1.6, false], ["cement_bag", 1.2, false], ["tree_stump_01", 1.0, true]][rr.randi() % 5]
			WDress.kp(holder, "scan", pick[0], Vector3(po.x, w.terrain.height_at(p.x + po.x, p.y + po.y) - holder.position.y, po.y), rr.randf() * TAU, pick[1], pick[2])
		placed += 1
	w.set_meta("shells_barns", placed)
	w.set_meta("barn_spots", spots)
	return placed
