class_name WTerrain
extends Node3D
## The ground of the Ashen Waste: ash plains, rust dunes, salt pans and dark ridges, walled at its edges by mountains.
## The shape is the same every time; the waste is one place, and it is learned.

const CELL := 4.0
const N := 1024
const CHUNK := 16
var seed := 1771

## The six lands of the waste. Each has its own shape, colour, and what grows or lies in it.
const BIOMES := ["ash", "dunes", "salt", "forest", "basalt", "marsh"]
const BIOME_NAMES := {"ash": "The Ash Plains", "dunes": "The Rust Dunes", "salt": "The Salt Flats", "forest": "The Dead Forest", "basalt": "The Basalt Heights", "marsh": "The Tar Marsh"}
const BIOME_COLORS := {
	"ash": Color(0.43, 0.41, 0.38), "dunes": Color(0.58, 0.4, 0.27), "salt": Color(0.82, 0.8, 0.74),
	"forest": Color(0.3, 0.27, 0.22), "basalt": Color(0.2, 0.19, 0.19), "marsh": Color(0.17, 0.16, 0.13),
}

var h := PackedFloat32Array()
var _bcols: Array = BIOMES.map(func(b): return BIOME_COLORS[b])   ## the lands' colours in order (safe to read from the map's thread)
var road := PackedFloat32Array()   ## how much of a worn road lies on each point of the grid, 0 to 1
var shade := PackedFloat32Array()
var flats: Array = []
var _a := FastNoiseLite.new()
var _r := FastNoiseLite.new()
var _d := FastNoiseLite.new()
var _t := FastNoiseLite.new()
var _m := FastNoiseLite.new()
var _centres: Array = []
## Where the cast-out wake: around it the land is always the Ash Plains, the gentlest, fading into
## whatever the seed made further out (worlds made before 0.9 keep their old land: home is INF)
var home := Vector2.INF
const HOME_R := 640.0
var _coast_turn := 0.0
## The isles out in the Grey Sea: {key, name, base, c, r, o (grid corner), n (grid points a side), h (heights)}
var isles: Array = []


func setup(world_seed: int) -> void:
	seed = world_seed
	_a.seed = seed
	_a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_a.frequency = 0.0016
	_a.fractal_octaves = 4
	_r.seed = seed + 1
	_r.frequency = 0.0035
	_r.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_r.fractal_octaves = 3
	_d.seed = seed + 2
	_d.frequency = 0.018
	_d.fractal_octaves = 2
	_t.seed = seed + 3
	_t.frequency = 0.0011
	_t.fractal_octaves = 2
	_m.seed = seed + 4
	_m.frequency = 0.0011
	_m.fractal_octaves = 2
	# Ash at the middle of the climate; the others about it, turned by the seed so each world mixes them differently
	var rr := RandomNumberGenerator.new()
	rr.seed = seed
	var turn := rr.randf() * TAU
	_centres = [Vector2.ZERO]
	for i in 5:
		_centres.append(Vector2(cos(turn + i * TAU / 5.0), sin(turn + i * TAU / 5.0)) * 0.36)
	_coast_turn = rr.randf() * TAU
	isles = WIsles.plan(seed)


func _init() -> void:
	setup(seed)


## How much each land holds sway at a point: six weights that sum to one.
func weights(x: float, z: float) -> PackedFloat32Array:
	var c := Vector2(_t.get_noise_2d(x, z), _m.get_noise_2d(x, z))
	var w := PackedFloat32Array()
	w.resize(6)
	var total := 0.0
	for i in 6:
		var d := c.distance_squared_to(_centres[i]) * (1.6 if i == 0 else 1.0)
		var k := exp(-d / 0.03)
		w[i] = k
		total += k
	for i in 6:
		w[i] /= maxf(total, 0.000001)
	if home != Vector2.INF:
		var k := smoothstep(HOME_R, HOME_R * 0.55, Vector2(x, z).distance_to(home))
		if k > 0.0:
			for i in 6:
				w[i] = lerpf(w[i], 1.0 if i == 0 else 0.0, k)
	return w


func biome_name(x: float, z: float) -> String:
	if (absf(x) > N * CELL * 0.5 or absf(z) > N * CELL * 0.5) and not isles.is_empty():
		# Out at sea, the nearest isle's kind
		var best: Dictionary = isles[0]
		for il in isles:
			if Vector2(x, z).distance_to(il.c) < Vector2(x, z).distance_to(best.c):
				best = il
		return best.base
	var w := weights(x, z)
	var best := 0
	for i in 6:
		if w[i] > w[best]:
			best = i
	return BIOMES[best]


func biome_at(x: float, z: float) -> float:
	return _t.get_noise_2d(x, z)


## Wears a road into the land along a line of points: it is drawn in dust, and the ground under it is eased.
func add_road(pts: PackedVector2Array, width := 5.0) -> void:
	var w := N + 1
	if road.size() != w * w:
		road.resize(w * w)
		road.fill(0.0)
	var half := N * CELL * 0.5
	var reach := width * 0.5 + 3.0
	var cr := int(ceil(reach / CELL))
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var steps := maxi(1, int(a.distance_to(b) / 2.0))
		for st in steps + 1:
			var p := a.lerp(b, float(st) / steps)
			var ci := int(round((p.x + half) / CELL))
			var cj := int(round((p.y + half) / CELL))
			for j in range(cj - cr, cj + cr + 1):
				for i in range(ci - cr, ci + cr + 1):
					if i < 0 or j < 0 or i > N or j > N:
						continue
					var d := Vector2(-half + i * CELL, -half + j * CELL).distance_to(p)
					var v := 1.0 - smoothstep(width * 0.5, reach, d)
					if v > road[j * w + i]:
						road[j * w + i] = v


func road_at(x: float, z: float) -> float:
	if road.is_empty():
		return 0.0
	var half := N * CELL * 0.5
	var i := clampi(int(round((x + half) / CELL)), 0, N)
	var j := clampi(int(round((z + half) / CELL)), 0, N)
	return road[j * (N + 1) + i]


## A flat place: [centre, radius]. Its height is the land's own at the centre.
func add_flat(c: Vector2, radius: float) -> void:
	flats.append([c, radius])


func _raw(x: float, z: float) -> float:
	var w := weights(x, z)
	var base := _a.get_noise_2d(x, z)
	var ridge := pow((_r.get_noise_2d(x, z) + 1.0) * 0.5, 2.2)
	var dn := _d.get_noise_2d(x, z)
	var hs := [
		base * 26.0 + ridge * 8.0,
		base * 14.0 + absf(sin(x * 0.045 + dn * 2.5)) * 5.0 + dn * 2.5,
		-14.0 + base * 2.0 + dn * 0.3,
		base * 30.0 + ridge * 14.0 + dn * 1.2,
		base * 30.0 + ridge * 72.0 + 12.0,
		-7.0 + base * 3.0 + dn * 1.2,
	]
	var y := 0.0
	for i in 6:
		y += hs[i] * w[i]
	var e := maxf(absf(x), absf(z))
	if e <= 1840.0:
		return y
	# The old rim: high cliffs on a few headlands, and elsewhere a shore running down into the Grey Sea.
	# Past 1990 every face falls away under the water, so the sea runs on all round.
	var ck := coast_cliff(x, z)
	var cliff := smoothstep(1840.0, 1950.0, e) * (110.0 + ridge * 90.0) * ck
	return lerpf(y + cliff, WIsles.FLOOR_Y, smoothstep(lerpf(1850.0, 1975.0, ck), 2040.0, e))


## How much the rim here stands as a cliff (1) rather than running down as a shore (0).
func coast_cliff(x: float, z: float) -> float:
	var ang := atan2(z, x)
	var m := sin(ang * 3.0 + _coast_turn) * 0.8 + _a.get_noise_2d(x * 0.5, z * 0.5) * 0.5
	return smoothstep(0.45, 0.75, m)


## The land as it was laid out before the waste grew: the old rim of mountains at a thousand paces.
## Places in the old middle are still chosen by it, so worlds begun before keep their towns and ruins.
func legacy_raw(x: float, z: float) -> float:
	var e := maxf(absf(x), absf(z))
	if e > 1000.0:
		return _raw(x, z)
	var ridge := pow((_r.get_noise_2d(x, z) + 1.0) * 0.5, 2.2)
	return _raw(x, z) + smoothstep(840.0, 1000.0, e) * (110.0 + ridge * 90.0)


func generate() -> void:
	var w := N + 1
	h.resize(w * w)
	var half := N * CELL * 0.5
	for j in w:
		var z := -half + j * CELL
		for i in w:
			h[j * w + i] = _raw(-half + i * CELL, z)
	for f in flats:
		var c: Vector2 = f[0]
		var radius: float = f[1]
		var target := _raw(c.x, c.y)
		var outer := radius * 2.4
		var i0 := clampi(int((c.x - outer + half) / CELL), 0, N)
		var i1 := clampi(int((c.x + outer + half) / CELL) + 1, 0, N)
		var j0 := clampi(int((c.y - outer + half) / CELL), 0, N)
		var j1 := clampi(int((c.y + outer + half) / CELL) + 1, 0, N)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var d := Vector2(-half + i * CELL, -half + j * CELL).distance_to(c)
				var k := 1.0 - smoothstep(radius, outer, d)
				if k > 0.0:
					h[j * w + i] = lerpf(h[j * w + i], target, k)
	# Roads ease the ground under them: a little of the lumps and hollows worn away
	if road.size() == h.size():
		var src := h.duplicate()
		for j in range(2, N - 1):
			for i in range(2, N - 1):
				var v := road[j * w + i]
				if v <= 0.05:
					continue
				var sum := 0.0
				for dj in range(-2, 3):
					for di in range(-2, 3):
						sum += src[(j + dj) * w + i + di]
				h[j * w + i] = lerpf(src[j * w + i], sum / 25.0, v * 0.8)


func height_at(x: float, z: float) -> float:
	var half := N * CELL * 0.5
	if absf(x) > half or absf(z) > half:
		return outer_height(x, z)
	var fx := clampf((x + half) / CELL, 0.0, N - 0.001)
	var fz := clampf((z + half) / CELL, 0.0, N - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var w := N + 1
	var a := h[j * w + i]
	var b := h[j * w + i + 1]
	var c := h[(j + 1) * w + i]
	var d := h[(j + 1) * w + i + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


# ------------------------------------------------------------------ the sea and its isles

## Ground height beyond the waste's own grid: an isle, or the sea bed.
func outer_height(x: float, z: float) -> float:
	for il in isles:
		var o: Vector2 = il.o
		var n: int = il.n
		var fx := (x - o.x) / WIsles.CELL
		var fz := (z - o.y) / WIsles.CELL
		if fx < 0.0 or fz < 0.0 or fx >= n - 1 or fz >= n - 1:
			continue
		var i := int(fx)
		var j := int(fz)
		var tx := fx - i
		var tz := fz - j
		var hh: PackedFloat32Array = il.h
		var a := hh[j * n + i]
		var b := hh[j * n + i + 1]
		var c := hh[(j + 1) * n + i]
		var d := hh[(j + 1) * n + i + 1]
		return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)
	return WIsles.FLOOR_Y


## The isle a point lies on or near (within its reach times k), or {}.
func isle_at(x: float, z: float, k := 1.25) -> Dictionary:
	for il in isles:
		if Vector2(x, z).distance_to(il.c) < float(il.r) * k:
			return il
	return {}


## Whether a point is open sea (or a flooded shore): out past the middle, with the ground under the water.
func is_water(x: float, z: float, depth := 0.0) -> bool:
	if maxf(absf(x), absf(z)) < WIsles.INLAND:
		return false
	return height_at(x, z) < WIsles.SEA_Y - depth


## The name of the place underfoot: a land of the waste, an isle, or the sea itself.
func region_name(x: float, z: float) -> String:
	if maxf(absf(x), absf(z)) > N * CELL * 0.5 - 40.0 or is_water(x, z, 0.5):
		var il := isle_at(x, z, 1.4)
		if not il.is_empty() and not is_water(x, z, 0.5):
			return il.name
		if is_water(x, z, 0.5):
			return "The Grey Sea"
	return BIOME_NAMES[biome_name(x, z)]


## An isle's height at a point: a warped round shore, then its own hills; a level clearing at its heart.
func _isle_raw(il: Dictionary, x: float, z: float) -> float:
	var th: Dictionary = WIsles.THEMES[il.key]
	var c: Vector2 = il.c
	var rad: float = il.r
	var d := Vector2(x, z).distance_to(c) / rad
	var warp := _d.get_noise_2d(x * 0.35, z * 0.35) * 0.22 + _a.get_noise_2d(x * 2.0, z * 2.0) * 0.12
	var land := 1.0 - smoothstep(0.62, 1.0, d + warp)
	var ridge := pow((_r.get_noise_2d(x * 1.3, z * 1.3) + 1.0) * 0.5, 2.0)
	var lump := (_a.get_noise_2d(x * 3.0, z * 3.0) + 1.0) * 0.5
	var hill := (lump * 0.45 + ridge * float(th.rough)) * float(th.relief) * smoothstep(0.0, 0.7, 1.0 - d)
	var top := WIsles.SEA_Y + 1.6 + hill
	if il.key == "fen":
		# Low, with black pools between the trees
		top = WIsles.SEA_Y + 0.9 + hill + (_d.get_noise_2d(x * 2.5, z * 2.5)) * 1.6
	var y := lerpf(WIsles.FLOOR_Y, top, land)
	# The heart: a level clearing where those before left something
	var heart := Vector2(x, z).distance_to(isle_heart(il))
	var flat := 1.0 - smoothstep(16.0, 34.0, heart)
	return lerpf(y, WIsles.SEA_Y + 3.0 + float(th.relief) * 0.12, flat)


## The level clearing on an isle, a little off its middle.
func isle_heart(il: Dictionary) -> Vector2:
	var c: Vector2 = il.c
	return c - c.normalized() * float(il.r) * 0.2


## Raises the isles: a height grid for each, then their ground and a shape to stand on.
func make_isles(m: Material) -> void:
	for il in isles:
		var rad: float = il.r
		var reach := rad * 1.2
		var n := int(ceil(reach * 2.0 / WIsles.CELL)) + 1
		var o: Vector2 = il.c - Vector2(reach, reach)
		var hh := PackedFloat32Array()
		hh.resize(n * n)
		for j in n:
			for i in n:
				hh[j * n + i] = _isle_raw(il, o.x + i * WIsles.CELL, o.y + j * WIsles.CELL)
		il.o = o
		il.n = n
		il.h = hh
	if m == null:
		return
	for il in isles:
		_build_isle(il, m)
	# The sea bed, out past every isle, so nothing falls for ever
	var floor_b := StaticBody3D.new()
	floor_b.collision_layer = 1
	floor_b.set_meta("ground", true)
	var fcs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12000, 2, 12000)
	fcs.shape = box
	fcs.position = Vector3(0, WIsles.FLOOR_Y - 1.0, 0)
	floor_b.add_child(fcs)
	add_child(floor_b)


func _isle_color(il: Dictionary, x: float, z: float, y: float, n: Vector3) -> Color:
	var th: Dictionary = WIsles.THEMES[il.key]
	var up := y - WIsles.SEA_Y
	var c: Color = (th.sand as Color).lerp(th.green, smoothstep(1.5, 5.0, up))
	c = c.lerp(th.rock, smoothstep(0.85, 0.65, n.y) * 0.85)
	if up < -0.5:
		c = c.darkened(0.35)
	var speck := _d.get_noise_2d(x * 7.0, z * 7.0) * 0.05
	return Color(c.r + speck, c.g + speck, c.b + speck)


func _build_isle(il: Dictionary, m: Material) -> void:
	var n: int = il.n
	var o: Vector2 = il.o
	var hh: PackedFloat32Array = il.h
	var size := 64   # chunks of 64 cells keep each mesh small enough to cull
	for cj in range(0, n - 1, size):
		for ci in range(0, n - 1, size):
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			var wi := mini(size, n - 1 - ci) + 1
			var wj := mini(size, n - 1 - cj) + 1
			for j in wj:
				for i in wi:
					var gi := ci + i
					var gj := cj + j
					var x := o.x + gi * WIsles.CELL
					var z := o.y + gj * WIsles.CELL
					var y := hh[gj * n + gi]
					var l := hh[gj * n + maxi(gi - 1, 0)]
					var r := hh[gj * n + mini(gi + 1, n - 1)]
					var u := hh[maxi(gj - 1, 0) * n + gi]
					var d := hh[mini(gj + 1, n - 1) * n + gi]
					var nn := Vector3(l - r, 2.0 * WIsles.CELL, u - d).normalized()
					verts.append(Vector3(x, y, z))
					norms.append(nn)
					cols.append(_isle_color(il, x, z, y, nn))
			for j in wj - 1:
				for i in wi - 1:
					var a := j * wi + i
					idx.append_array([a, a + 1, a + wi, a + 1, a + wi + 1, a + wi])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = idx
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			mi.material_override = m
			mi.visibility_range_end = 2200.0
			add_child(mi)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.set_meta("ground", true)
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = n
	hs.map_depth = n
	var scaled := PackedFloat32Array()
	scaled.resize(hh.size())
	for k in hh.size():
		scaled[k] = hh[k] / WIsles.CELL
	hs.map_data = scaled
	cs.shape = hs
	cs.scale = Vector3.ONE * WIsles.CELL
	sb.add_child(cs)
	# A height map shape is centred on its body
	var half := (n - 1) * WIsles.CELL * 0.5
	sb.position = Vector3(o.x + half, 0, o.y + half)
	add_child(sb)


func normal_at(x: float, z: float) -> Vector3:
	var e := CELL
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()


func _vcolor(x: float, z: float, y: float, n: Vector3) -> Color:
	var w := weights(x, z)
	var c := Color(0, 0, 0)
	for i in 6:
		c += _bcols[i] * w[i]
	var rock := Color(0.24, 0.22, 0.21)
	c = c.lerp(rock, smoothstep(0.86, 0.68, n.y) * 0.8)
	c = c.lerp(rock.darkened(0.2), smoothstep(60.0, 110.0, y))
	var rd := road_at(x, z)
	if rd > 0.0:
		var dirt := Color(0.38, 0.32, 0.25) if c.get_luminance() < 0.6 else Color(0.62, 0.58, 0.5)
		c = c.lerp(dirt, rd * 0.8)
	var speck := _d.get_noise_2d(x * 7.0, z * 7.0) * 0.06
	return Color(c.r + speck, c.g + speck, c.b + speck)


## Builds the visible ground in chunks, and one shape to stand on.
func build(m: Material) -> void:
	var w := N + 1
	var half := N * CELL * 0.5
	var chunks := N / CHUNK
	for cj in chunks:
		for ci in chunks:
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			var cw := CHUNK + 1
			for j in cw:
				for i in cw:
					var gi := ci * CHUNK + i
					var gj := cj * CHUNK + j
					var x := -half + gi * CELL
					var z := -half + gj * CELL
					var y := h[gj * w + gi]
					var l := h[gj * w + maxi(gi - 1, 0)]
					var r := h[gj * w + mini(gi + 1, N)]
					var u := h[maxi(gj - 1, 0) * w + gi]
					var d := h[mini(gj + 1, N) * w + gi]
					var n := Vector3(l - r, 2.0 * CELL, u - d).normalized()
					verts.append(Vector3(x, y, z))
					norms.append(n)
					cols.append(_vcolor(x, z, y, n))
			for j in CHUNK:
				for i in CHUNK:
					var a := j * cw + i
					idx.append_array([a, a + 1, a + cw, a + 1, a + cw + 1, a + cw])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = idx
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			mi.material_override = m
			mi.visibility_range_end = 1100.0
			add_child(mi)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.set_meta("ground", true)
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = w
	hs.map_depth = w
	var scaled := PackedFloat32Array()
	scaled.resize(h.size())
	for k in h.size():
		scaled[k] = h[k] / CELL
	hs.map_data = scaled
	cs.shape = hs
	cs.scale = Vector3.ONE * CELL
	sb.add_child(cs)
	add_child(sb)


## The whole waste drawn from above, for the map: shaded relief in the land's own colours.
func map_image(px := 512) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	map_rows(img, 0, px)
	return img


## Draws rows j0..j1 of the map picture into img.
func map_rows(img: Image, j0: int, j1: int) -> void:
	var px := img.get_width()
	var half := WIsles.MAP_HALF
	var step := half * 2.0 / px
	var inner := N * CELL * 0.5
	var light := Vector3(-0.6, 0.7, -0.4).normalized()
	for j in range(j0, j1):
		for i in px:
			var x := -half + (i + 0.5) * step
			var z := -half + (j + 0.5) * step
			var y := height_at(x, z)
			if is_water(x, z):
				# The sea: darker where it is deep
				var deep := clampf((WIsles.SEA_Y - y) / 14.0, 0.0, 1.0)
				img.set_pixel(i, j, WIsles.SEA_COLOR.lerp(Color(0.32, 0.36, 0.36), 1.0 - deep))
				continue
			var n := normal_at(x, z)
			var c: Color
			if absf(x) > inner or absf(z) > inner:
				var il := isle_at(x, z, 1.3)
				c = _isle_color(il, x, z, y, n) if not il.is_empty() else WIsles.SEA_COLOR
			else:
				c = _vcolor(x, z, y, n)
			var s := clampf(n.dot(light) * 1.3, 0.35, 1.15)
			c = Color(c.r * s, c.g * s, c.b * s)
			# Roads stand out on the map as pale worn lines
			var rd := maxf(road_at(x, z), maxf(road_at(x + step * 0.5, z), road_at(x, z + step * 0.5)))
			if rd > 0.3:
				c = c.lerp(Color(0.86, 0.74, 0.52), 0.8)
			img.set_pixel(i, j, c)
