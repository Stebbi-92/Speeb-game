class_name WTerrain
extends Node3D
## The ground of the Ashen Waste: ash plains, rust dunes, salt pans and dark ridges, walled at its edges by mountains.
## The shape is the same every time; the waste is one place, and it is learned.

const CELL := 4.0
const N := 512
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
var shade := PackedFloat32Array()
var flats: Array = []
var _a := FastNoiseLite.new()
var _r := FastNoiseLite.new()
var _d := FastNoiseLite.new()
var _t := FastNoiseLite.new()
var _m := FastNoiseLite.new()
var _centres: Array = []


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
	return w


func biome_name(x: float, z: float) -> String:
	var w := weights(x, z)
	var best := 0
	for i in 6:
		if w[i] > w[best]:
			best = i
	return BIOMES[best]


func biome_at(x: float, z: float) -> float:
	return _t.get_noise_2d(x, z)


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
	var edge := smoothstep(840.0, 1000.0, e) * (110.0 + ridge * 90.0)
	return y + edge


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


func height_at(x: float, z: float) -> float:
	var half := N * CELL * 0.5
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


func normal_at(x: float, z: float) -> Vector3:
	var e := CELL
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()


func _vcolor(x: float, z: float, y: float, n: Vector3) -> Color:
	var w := weights(x, z)
	var c := Color(0, 0, 0)
	for i in 6:
		c += BIOME_COLORS[BIOMES[i]] * w[i]
	var rock := Color(0.24, 0.22, 0.21)
	c = c.lerp(rock, smoothstep(0.86, 0.68, n.y) * 0.8)
	c = c.lerp(rock.darkened(0.2), smoothstep(60.0, 110.0, y))
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
	var half := N * CELL * 0.5
	var step := N * CELL / px
	var light := Vector3(-0.6, 0.7, -0.4).normalized()
	for j in px:
		for i in px:
			var x := -half + (i + 0.5) * step
			var z := -half + (j + 0.5) * step
			var y := height_at(x, z)
			var n := normal_at(x, z)
			var c := _vcolor(x, z, y, n)
			var s := clampf(n.dot(light) * 1.3, 0.35, 1.15)
			img.set_pixel(i, j, Color(c.r * s, c.g * s, c.b * s))
	return img
