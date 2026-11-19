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
var bays: Array = []   ## [centre, radius]: deep inlets of the sea, cut where nothing stands
var natural_coast := false   ## worlds begun from 0.12 on: the coast is ragged and the corners rounded, not a square
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
	if natural_coast and e > 1650.0:
		# The corners drawn in, and the line of the shore wandering inward by up to a long bowshot.
		# Only past 1650 paces, so nothing laid out in the land is put under the sea.
		var round_in := clampf(Vector2(x, z).length() * 0.82 - e, 0.0, 260.0) * smoothstep(1650.0, 1800.0, e)
		var n := _a.get_noise_2d(x * 0.11 + 500.0, z * 0.11) * 0.6 + sin(atan2(z, x) * 5.0 + _coast_turn) * 0.4
		e += round_in + (n + 1.0) * 0.5 * 200.0 * smoothstep(1730.0, 1850.0, e)
	for b in bays:
		var d := Vector2(x, z).distance_to(b[0])
		if d < b[1]:
			e += 700.0 * (1.0 - smoothstep(float(b[1]) * 0.3, float(b[1]), d))
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


var steps := false   ## when true, generate() and build() give up a frame now and then so the window keeps drawing


var on_progress := Callable()   ## told how far generate() or build() has got, 0 to 1

func _breathe(f := -1.0) -> void:
	if steps:
		if f >= 0.0 and on_progress.is_valid():
			on_progress.call(f)
		await (Engine.get_main_loop() as SceneTree).process_frame


func generate() -> void:
	var w := N + 1
	h.resize(w * w)
	var half := N * CELL * 0.5
	for j in w:
		if j % 64 == 63:
			await _breathe(float(j) / w)
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
		var ce: float = il.get("cell", WIsles.CELL)
		var fx := (x - o.x) / ce
		var fz := (z - o.y) / ce
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
		# By the same two triangles the ground is drawn and stood on, so a sharp ridge lies where it is felt
		if tx + tz <= 1.0:
			return a + (b - a) * tx + (c - a) * tz
		return d + (c - d) * (1.0 - tx) + (b - d) * (1.0 - tz)
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
const SEA_NAME := "The Grey Sea"


func region_name(x: float, z: float) -> String:
	if maxf(absf(x), absf(z)) > N * CELL * 0.5 - 40.0 or is_water(x, z, 0.5):
		var il := isle_at(x, z, 1.4)
		if not il.is_empty() and not is_water(x, z, 0.5):
			return il.name
		if is_water(x, z, 0.5):
			return SEA_NAME
	return BIOME_NAMES[biome_name(x, z)]


## An isle's height at a point: a warped round shore, then its own hills; a level clearing at its heart.
func _isle_raw(il: Dictionary, x: float, z: float) -> float:
	var th: Dictionary = WIsles.THEMES[il.key]
	if th.get("shore", false):
		return _shore_raw(il, th, x, z)
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
	y = lerpf(y, WIsles.SEA_Y + 3.0 + float(th.relief) * 0.12, flat)
	if th.get("far", false):
		# A far isle's great one has its own level ground
		var lf := 1.0 - smoothstep(26.0, 60.0, Vector2(x, z).distance_to(WIsles.lair_spot(il)))
		y = lerpf(y, WIsles.SEA_Y + 3.5 + float(th.relief) * 0.12, lf)
	return y


## A Far Shore's height: broad shapes for a land 2 km across, each in its own way. The Frostmark rises
## to a ridged spine with snow on it; the Sunward Reach steps up in flat-topped mesas cut by dry
## canyons; the Pale Steppe rolls low and long, with slow rivers through it.
func _shore_raw(il: Dictionary, th: Dictionary, x: float, z: float) -> float:
	var c: Vector2 = il.c
	var rad: float = il.r
	var d := Vector2(x, z).distance_to(c) / rad
	var warp := _d.get_noise_2d(x * 0.11, z * 0.11) * 0.22 + _a.get_noise_2d(x * 0.9, z * 0.9) * 0.08
	var land := 1.0 - smoothstep(0.72, 1.0, d + warp)
	var inland := smoothstep(0.0, 0.45, 1.0 - d)
	var relief: float = th.relief
	var lump := (_a.get_noise_2d(x * 0.6, z * 0.6) + 1.0) * 0.5
	var fine := _d.get_noise_2d(x * 0.5, z * 0.5) * 0.04
	var hill := 0.0
	match str(il.key):
		"frost":
			var ridge := pow((_r.get_noise_2d(x * 0.42, z * 0.42) + 1.0) * 0.5, 2.4)
			# The lava fields lie low and level between the heights
			hill = (ridge * 1.0 + lump * 0.25 + fine) * relief * inland
		"sun":
			var base := (lump * 0.8 + (_r.get_noise_2d(x * 0.3, z * 0.3) + 1.0) * 0.2) * relief * inland
			var step := 16.0
			var k := floorf(base / step)
			var t := base / step - k
			hill = (k + smoothstep(0.78, 1.0, t)) * step   # flat tops, sheer sides
			var cut := 1.0 - smoothstep(0.0, 0.07, absf(_d.get_noise_2d(x * 0.07 + 40.0, z * 0.07)))
			hill = maxf(0.6, hill - cut * 30.0 * inland)
		_:
			hill = (lump * 0.8 + fine * 3.0) * relief * inland
			var river := 1.0 - smoothstep(0.012, 0.03, absf(_d.get_noise_2d(x * 0.06 - 70.0, z * 0.06)))
			hill = lerpf(hill, -2.4, river * smoothstep(0.1, 0.3, 1.0 - d))
	var top := WIsles.SEA_Y + 1.8 + hill
	var y := lerpf(WIsles.FLOOR_Y, top, land)
	var heart := Vector2(x, z).distance_to(isle_heart(il))
	var flat := 1.0 - smoothstep(22.0, 46.0, heart)
	y = lerpf(y, WIsles.SEA_Y + 4.0 + relief * 0.08, flat)
	# The shore's town: a wide level clearing, its ground eased down to it
	var town := Vector2(x, z).distance_to(WIsles.town_spot(il))
	var tf := 1.0 - smoothstep(48.0, 110.0, town)
	y = lerpf(y, WIsles.SEA_Y + 5.0 + relief * 0.1, tf)
	var lf := 1.0 - smoothstep(28.0, 80.0, Vector2(x, z).distance_to(WIsles.lair_spot(il)))
	return lerpf(y, WIsles.SEA_Y + 4.5 + relief * 0.12, lf)


## The level clearing on an isle, a little off its middle.
func isle_heart(il: Dictionary) -> Vector2:
	var c: Vector2 = il.c
	return c - c.normalized() * float(il.r) * 0.2


## Raises the isles: a height grid for each, then their ground and a shape to stand on.
## An isle with its own photographed ground (Hrafnsey's moss and black gravel, Kalaja's dry limestone
## hills) wears its own maps; the rest share the waste's.
func isle_ground(il: Dictionary, m: Material) -> Material:
	var dir := "res://assets/textures/ground/isles/%s/" % str(il.get("key", ""))
	if not (m is ShaderMaterial) or not ResourceLoader.exists(dir + "ground_a.png"):
		return m
	var own := (m as ShaderMaterial).duplicate() as ShaderMaterial
	for k in ["ground_a", "ground_b", "ground_n1", "ground_n2", "ground_n3", "ground_n4"]:
		if ResourceLoader.exists(dir + k + ".png"):
			own.set_shader_parameter(k, load(dir + k + ".png"))
	return own


func make_isles(m: Material) -> void:
	for il in isles:
		var rad: float = il.r
		var reach := rad * 1.2
		var ce: float = il.get("cell", WIsles.CELL)
		var n := int(ceil(reach * 2.0 / ce)) + 1
		var o: Vector2 = il.c - Vector2(reach, reach)
		var hh := PackedFloat32Array()
		hh.resize(n * n)
		for j in n:
			for i in n:
				hh[j * n + i] = _isle_raw(il, o.x + i * ce, o.y + j * ce)
		il.o = o
		il.n = n
		il.h = hh
	if m == null:
		return
	for il in isles:
		_build_isle(il, isle_ground(il, m))
	# The sea bed, out past every isle, so nothing falls for ever
	var floor_b := StaticBody3D.new()
	floor_b.collision_layer = 1
	floor_b.set_meta("ground", true)
	var fcs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIsles.MAP_HALF * 2.0 + 1000.0, 2, WIsles.MAP_HALF * 2.0 + 1000.0)   # under the whole sea, the far shores too
	fcs.shape = box
	fcs.position = Vector3(0, WIsles.FLOOR_Y - 1.0, 0)
	floor_b.add_child(fcs)
	add_child(floor_b)


## Which lands an isle's ground is like at a height: sand by the water, its own land above.
func _isle_weights(il: Dictionary, y: float) -> PackedFloat32Array:
	var w := PackedFloat32Array([0, 0, 0, 0, 0, 0])
	var up := smoothstep(1.5, 5.0, y - WIsles.SEA_Y)
	var base := maxi(0, BIOMES.find(str(il.get("base", "ash"))))
	w[1] += 1.0 - up
	w[base] += up
	return w


## The lands at a point, as the ground shader reads them: two sets of four, each 0..255.
##   CUSTOM0 ash, dunes, salt, forest     CUSTOM1 basalt, marsh, (slope rock, found by the shader), road
const LAND_FORMAT := (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)


func _land_bytes(c0: PackedByteArray, c1: PackedByteArray, w: PackedFloat32Array, rd: float) -> void:
	var keep := 1.0 - rd * 0.85
	for i in 4:
		c0.append(int(clampf(w[i] * keep, 0.0, 1.0) * 255.0))
	c1.append(int(clampf(w[4] * keep, 0.0, 1.0) * 255.0))
	c1.append(int(clampf(w[5] * keep, 0.0, 1.0) * 255.0))
	c1.append(0)
	c1.append(int(clampf(rd * 0.85, 0.0, 1.0) * 255.0))


func _isle_color(il: Dictionary, x: float, z: float, y: float, n: Vector3) -> Color:
	var th: Dictionary = WIsles.THEMES[il.key]
	var up := y - WIsles.SEA_Y
	var c: Color = (th.sand as Color).lerp(th.green, smoothstep(1.5, 5.0, up))
	c = c.lerp(th.rock, smoothstep(0.85, 0.65, n.y) * 0.85)
	if th.has("snow"):
		c = c.lerp(Color(0.9, 0.93, 0.96), smoothstep(float(th.snow), float(th.snow) + 14.0, up) * smoothstep(0.5, 0.75, n.y))
	if up < -0.5:
		c = c.darkened(0.35)
	var speck := _d.get_noise_2d(x * 7.0, z * 7.0) * 0.05
	return Color(c.r + speck, c.g + speck, c.b + speck)


func _build_isle(il: Dictionary, m: Material) -> void:
	var n: int = il.n
	var o: Vector2 = il.o
	var hh: PackedFloat32Array = il.h
	var ce: float = il.get("cell", WIsles.CELL)
	var size := 64   # chunks of 64 cells keep each mesh small enough to cull
	for cj in range(0, n - 1, size):
		for ci in range(0, n - 1, size):
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			var c0 := PackedByteArray()
			var c1 := PackedByteArray()
			var idx := PackedInt32Array()
			var wi := mini(size, n - 1 - ci) + 1
			var wj := mini(size, n - 1 - cj) + 1
			for j in wj:
				for i in wi:
					var gi := ci + i
					var gj := cj + j
					var x := o.x + gi * ce
					var z := o.y + gj * ce
					var y := hh[gj * n + gi]
					var l := hh[gj * n + maxi(gi - 1, 0)]
					var r := hh[gj * n + mini(gi + 1, n - 1)]
					var u := hh[maxi(gj - 1, 0) * n + gi]
					var d := hh[mini(gj + 1, n - 1) * n + gi]
					var nn := Vector3(l - r, 2.0 * ce, u - d).normalized()
					verts.append(Vector3(x, y, z))
					norms.append(nn)
					cols.append(_isle_color(il, x, z, y, nn))
					_land_bytes(c0, c1, _isle_weights(il, y), 0.0)
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
			arr[Mesh.ARRAY_CUSTOM0] = c0
			arr[Mesh.ARRAY_CUSTOM1] = c1
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, LAND_FORMAT)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			mi.material_override = m
			mi.visibility_range_end = 2200.0 if ce <= WIsles.CELL else 4200.0   # a Far Shore's heights are seen from far out
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
		scaled[k] = hh[k] / ce
	_mend_holes(scaled)
	hs.map_data = scaled
	cs.shape = hs
	cs.scale = Vector3.ONE * ce
	sb.add_child(cs)
	# A height map shape is centred on its body
	var half := (n - 1) * ce * 0.5
	sb.position = Vector3(o.x + half, 0, o.y + half)
	add_child(sb)


func normal_at(x: float, z: float) -> Vector3:
	var e := CELL
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()


func _vcolor(x: float, z: float, y: float, n: Vector3, w := PackedFloat32Array()) -> Color:
	if w.is_empty():
		w = weights(x, z)
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


## Makes the one shape to stand on (the visible ground is laid by stream_to()).
func build(m: Material) -> void:
	# The ground is no longer drawn all at once: stream_to() lays tiles about the eye, fine near and coarse far
	_ground_m = m
	var w := N + 1
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
	_mend_holes(scaled)
	hs.map_data = scaled
	cs.shape = hs
	cs.scale = Vector3.ONE * CELL
	sb.add_child(cs)
	add_child(sb)


# ------------------------------------------------------------------ the ground, streamed

const TILE_CELLS := 64                ## a tile of ground is 64 cells (256 m) square
const NEAR_R := 420.0                 ## within this the ground is drawn in full
const FAR_R := 1250.0                 ## out to this, in one cell in four; past it, not at all
const COARSE := 4
var _ground_m: Material
var _tiles := {}       ## Vector2i -> {"lod": int, "node": MeshInstance3D}
var _jobs := {}        ## Vector2i -> {"lod": int, "task": int, "out": Array}
static var tiles_built := 0


## Lays the ground about p: tiles near in full, further ones coarse, the furthest let go. With now,
## all at once (at the start); else a few at a time, made on worker threads.
func stream_to(p: Vector3, now := false) -> void:
	if _ground_m == null:
		return
	var size := TILE_CELLS * CELL
	var half := N * CELL * 0.5
	var tn := N / TILE_CELLS
	var want := {}
	var r := int(ceil(FAR_R / size)) + 1
	var pi := int((p.x + half) / size)
	var pj := int((p.z + half) / size)
	for tj in range(maxi(0, pj - r), mini(tn, pj + r + 1)):
		for ti in range(maxi(0, pi - r), mini(tn, pi + r + 1)):
			var x0 := -half + ti * size
			var z0 := -half + tj * size
			var cx := clampf(p.x, x0, x0 + size)
			var cz := clampf(p.z, z0, z0 + size)
			var d := Vector2(p.x - cx, p.z - cz).length()
			if d < NEAR_R:
				want[Vector2i(ti, tj)] = 0
			elif d < FAR_R:
				want[Vector2i(ti, tj)] = 1
	# Let go what is too far
	for k in _tiles.keys():
		if not want.has(k):
			(_tiles[k].node as Node).queue_free()
			_tiles.erase(k)
	# Finish what the workers have made
	for k in _jobs.keys():
		var jb: Dictionary = _jobs[k]
		if now or WorkerThreadPool.is_task_completed(jb.task):
			WorkerThreadPool.wait_for_task_completion(jb.task)
			_jobs.erase(k)
			if want.get(k, -1) == jb.lod:
				_place_tile(k, jb.lod, jb.out)
	# Ask for what is missing, nearest first
	var need: Array = []
	for k in want:
		var have: int = _tiles[k].lod if _tiles.has(k) else -1
		if have != want[k] and not _jobs.has(k):
			need.append(k)
	var at := Vector2(pi, pj)
	need.sort_custom(func(a, b): return Vector2(a).distance_squared_to(at) < Vector2(b).distance_squared_to(at))
	var budget := need.size() if now else 2
	for k in need.slice(0, budget):
		var lod: int = want[k]
		if now:
			var out: Array = []
			_tile_arrays(k, lod, out)
			_place_tile(k, lod, out)
		else:
			var out: Array = []
			var task := WorkerThreadPool.add_task(_tile_arrays.bind(k, lod, out))
			_jobs[k] = {"lod": lod, "task": task, "out": out}


func _place_tile(k: Vector2i, lod: int, out: Array) -> void:
	if out.is_empty():
		return
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out[0], [], {}, LAND_FORMAT)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = _ground_m
	add_child(mi)
	if _tiles.has(k):
		(_tiles[k].node as Node).queue_free()
	_tiles[k] = {"lod": lod, "node": mi}
	tiles_built += 1


## One tile's ground as mesh arrays (safe on a worker: it only reads). A skirt hangs from its edges
## so a coarse tile beside a fine one shows no crack.
func _tile_arrays(k: Vector2i, lod: int, out: Array) -> void:
	var step := 1 if lod == 0 else COARSE
	var w := N + 1
	var half := N * CELL * 0.5
	var n := TILE_CELLS / step
	var cw := n + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var c0 := PackedByteArray()
	var c1 := PackedByteArray()
	var idx := PackedInt32Array()
	for j in cw:
		for i in cw:
			var gi := k.x * TILE_CELLS + i * step
			var gj := k.y * TILE_CELLS + j * step
			var x := -half + gi * CELL
			var z := -half + gj * CELL
			var y := h[gj * w + gi]
			var l := h[gj * w + maxi(gi - step, 0)]
			var r := h[gj * w + mini(gi + step, N)]
			var u := h[maxi(gj - step, 0) * w + gi]
			var d := h[mini(gj + step, N) * w + gi]
			var nn := Vector3(l - r, 2.0 * CELL * step, u - d).normalized()
			verts.append(Vector3(x, y, z))
			norms.append(nn)
			var wt := weights(x, z)
			cols.append(_vcolor(x, z, y, nn, wt))
			_land_bytes(c0, c1, wt, road_at(x, z))
	for j in n:
		for i in n:
			var a := j * cw + i
			idx.append_array([a, a + 1, a + cw, a + 1, a + cw + 1, a + cw])
	# The skirt: each edge's points again, a little below, joined down
	var edges := [[], [], [], []]
	for t in cw:
		edges[0].append(t)                    # north, west to east
		edges[1].append(n * cw + (n - t))     # south, east to west
		edges[2].append((n - t) * cw)         # west, south to north
		edges[3].append(t * cw + n)           # east, north to south
	var drop := 3.0 * step
	for e in edges:
		var base := verts.size()
		for vi in e:
			verts.append(verts[vi] - Vector3(0, drop, 0))
			norms.append(norms[vi])
			cols.append(cols[vi])
			c0.append_array(c0.slice(vi * 4, vi * 4 + 4))
			c1.append_array(c1.slice(vi * 4, vi * 4 + 4))
		for t in e.size() - 1:
			var a: int = e[t]
			var b: int = e[t + 1]
			# Both faces, so it shows from either side whichever way the edge runs
			idx.append_array([a, base + t, b, b, base + t, base + t + 1, a, b, base + t, b, base + t + 1, base + t])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	arr[Mesh.ARRAY_CUSTOM0] = c0
	arr[Mesh.ARRAY_CUSTOM1] = c1
	out.append(arr)


func tiles_now() -> Dictionary:
	var c := {0: 0, 1: 0}
	for k in _tiles:
		c[_tiles[k].lod] += 1
	return c


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


## A height that is not a number makes a hole in the ground's collision that a pilgrim can fall
## through: each such cell takes the height of the cell before it (or sea level).
static func _mend_holes(a: PackedFloat32Array) -> int:
	var mended := 0
	for k in a.size():
		if is_nan(a[k]) or is_inf(a[k]):
			a[k] = a[k - 1] if k > 0 else 0.0
			mended += 1
	if mended > 0:
		push_warning("Terrain: mended %d cells with no height" % mended)
	return mended
