class_name WIsleLife
extends Node3D
## What makes the isles more than ground: landings and wrecks, each isle's own buildings and leavings
## (from the free Kenney kits), and things that move: gulls over the water, lights over the fen,
## sails turning on Cogwright. Built the same on every machine from the world's seed.

const KITS := "res://assets/models/isles/"
const FAR := 650.0        ## past this the pieces are not drawn

var w   ## the wasteland
static var _scenes := {}
static var _boxes := {}
var gulls: Array = []     ## [node, centre, radius, height, speed, phase]
var wisps: Array = []     ## [node, home, phase]
var spinners: Array = []  ## [node, axis, speed]
var t := 0.0
var _pine: StandardMaterial3D
var _dead: StandardMaterial3D


func setup(world) -> WIsleLife:
	w = world
	return self


func build() -> void:
	_pine = StandardMaterial3D.new()
	_pine.albedo_color = Color(0.16, 0.24, 0.16)
	_pine.roughness = 0.95
	_dead = StandardMaterial3D.new()
	_dead.albedo_color = Color(0.17, 0.15, 0.12)
	_dead.roughness = 1.0
	for il in w.terrain.isles:
		var rr := RandomNumberGenerator.new()
		rr.seed = w.world_seed + hash(str(il.key) + "life")
		_landing(il, rr)
		for k in 2:
			_wreck(il, rr, k)
		match str(il.key):
			"hrafn":
				_hrafn(il, rr)
			"fen":
				_fen(il, rr)
			"kala":
				_kala(il, rr)
			"cog":
				_cog(il, rr)
		for k in 7:
			_gull(Vector2(il.c) + Vector2(rr.randf_range(-1, 1), rr.randf_range(-1, 1)) * float(il.r) * 0.6, rr)
	# Landings on the waste's own shore, one facing each isle, and gulls along it
	var rr := RandomNumberGenerator.new()
	rr.seed = w.world_seed + 4411
	for il in w.terrain.isles:
		_coast_landing(il, rr)
	for k in 10:
		var a := rr.randf() * TAU
		var d := Vector2(cos(a), sin(a))
		d /= maxf(absf(d.x), absf(d.y))
		_gull(d * rr.randf_range(1900.0, 2100.0), rr)


# ------------------------------------------------------------------ pieces

## A kit model, set on the ground at p: scaled, turned, and solid if asked (a box about its bounds).
func piece(kit: String, model: String, p: Vector3, yaw := 0.0, s := 1.0, solid := false, tilt := Vector3.ZERO, mat: Material = null) -> Node3D:
	var n := put(self, kit, model, Vector3.ZERO, yaw, s, solid, tilt, mat)
	n.global_position = p
	return n


## A kit model under parent at a local spot. Anything in the world may use this (ruins, camps, crates).
static func put(parent: Node3D, kit: String, model: String, local: Vector3, yaw := 0.0, s := 1.0, solid := false, tilt := Vector3.ZERO, mat: Material = null, far := FAR) -> Node3D:
	var n := make(kit, model)
	parent.add_child(n)
	n.position = local
	n.rotation = Vector3(tilt.x, yaw, tilt.z)
	n.scale = Vector3.ONE * s
	for mi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		(mi as GeometryInstance3D).visibility_range_end = far
		if mat:
			(mi as GeometryInstance3D).material_override = mat
	if solid:
		var bb := bounds(kit + "/" + model, n)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bb.size * 0.9
		cs.shape = bs
		cs.position = bb.get_center()
		body.add_child(cs)
		n.add_child(body)
	return n


## A fresh copy of a kit model (a .glb scene, or an .obj mesh).
static func make(kit: String, model: String) -> Node3D:
	var key := kit + "/" + model
	if not _scenes.has(key):
		var path := KITS + key + ".glb"
		if kit == "scan":
			# The scanned shapes of the land (CC0, Poly Haven), each in its own folder
			path = "res://assets/models/nature/%s/%s.gltf" % [model, model]
		elif not ResourceLoader.exists(path):
			path = KITS + key + ".obj"
		_scenes[key] = load(path)
	var res = _scenes[key]
	if res is PackedScene:
		return (res as PackedScene).instantiate()
	var mi := MeshInstance3D.new()
	mi.mesh = res
	return mi


static func bounds(key: String, n: Node3D) -> AABB:
	if _boxes.has(key):
		return _boxes[key]
	var bb := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var a: AABB = (mi as MeshInstance3D).get_aabb()
		var tr: Transform3D = Transform3D.IDENTITY if mi == n else (mi as Node3D).transform
		var p: Node = mi.get_parent() if mi != n else null
		while p and p != n:
			tr = (p as Node3D).transform * tr
			p = p.get_parent()
		a = tr * a
		bb = a if first else bb.merge(a)
		first = false
	_boxes[key] = bb
	return bb


func _ground(q: Vector2) -> Vector3:
	return Vector3(q.x, w.terrain.height_at(q.x, q.y), q.y)


## A dry, gentle spot on the isle, between lo and hi of its reach from the heart; INF if none.
func spot(il: Dictionary, rr: RandomNumberGenerator, lo: float, hi: float, slope := 0.8) -> Vector3:
	var heart: Vector2 = w.terrain.isle_heart(il)
	for tries in 24:
		var a := rr.randf() * TAU
		var q := heart + Vector2(cos(a), sin(a)) * float(il.r) * rr.randf_range(lo, hi)
		var y: float = w.terrain.height_at(q.x, q.y)
		if y < WIsles.SEA_Y + 0.8 or w.terrain.normal_at(q.x, q.y).y < slope:
			continue
		return Vector3(q.x, y, q.y)
	return Vector3.INF


## Where the land meets the sea, walking out from a point in a direction: the last dry ground.
func _shore(from: Vector2, dir: Vector2, reach: float) -> Vector2:
	var last := from
	var k := 0.0
	while k < reach:
		var q := from + dir * k
		if w.terrain.height_at(q.x, q.y) < WIsles.SEA_Y - 0.3:
			return last
		last = q
		k += 2.0
	return Vector2.INF


## A pier out from the shore, with a moored rowing boat and the stores of whoever kept it.
func _pier(shore: Vector2, out: Vector2, rr: RandomNumberGenerator, keep := true) -> void:
	var yaw := atan2(out.x, out.y)
	var deck_y := WIsles.SEA_Y + 0.9
	for i in 7:
		var q := shore + out * (i * 3.0 - 3.0)
		piece("pirate", "structure-platform-dock", Vector3(q.x, deck_y - 1.6, q.y), yaw, 1.2, true)
	var end := shore + out * 18.0
	var side := Vector2(out.y, -out.x)
	var bq := end + side * 3.2
	piece("pirate", "boat-row-small", Vector3(bq.x, WIsles.SEA_Y - 0.25, bq.y), yaw + 0.2, 1.1)
	var lq := shore + out * 15.0 + side * 1.2
	_lamp(Vector3(lq.x, deck_y + 0.2, lq.y))
	if not keep:
		return
	var g := _ground(shore - out * 5.0)
	piece("pirate", "barrel", g + Vector3(side.x, 0, side.y) * 2.0, rr.randf() * TAU, 0.8, true)
	piece("pirate", "barrel", g + Vector3(side.x, 0, side.y) * 3.1, rr.randf() * TAU, 0.8, true)
	piece("pirate", "crate", g - Vector3(side.x, 0, side.y) * 2.4, yaw, 0.9, true)
	piece("pirate", "tool-paddle", g - Vector3(side.x, 0, side.y) * 3.2, yaw, 0.9, false, Vector3(0.3, 0, 0))


func _lamp(p: Vector3) -> void:
	piece("town", "lantern", p, 0.0, 1.6)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.4)
	l.light_energy = 1.4
	l.omni_range = 9.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 120.0
	add_child(l)
	l.global_position = p + Vector3(0, 2.3, 0)


## Each isle's landing faces the waste, so the first crossing ends at a pier.
func _landing(il: Dictionary, rr: RandomNumberGenerator) -> void:
	var c: Vector2 = il.c
	var toward := -c.normalized()
	var s := _shore(c, toward, float(il.r) * 1.6)
	if s == Vector2.INF:
		return
	_pier(s, toward, rr)
	# A hut by the landing, roofed, to wait out a storm in
	var hq := s - toward * 9.0 + Vector2(toward.y, -toward.x) * 6.0
	var g := _ground(hq)
	if g.y > WIsles.SEA_Y + 0.5:
		piece("pirate", "structure", g, atan2(toward.x, toward.y), 1.6, false)
		piece("pirate", "structure-roof", g + Vector3(0, 3.4, 0), atan2(toward.x, toward.y), 1.6, true)
		piece("pirate", "flag-pirate-high", g + Vector3(2.4, 0, 2.4), 0.0, 1.4)


func _coast_landing(il: Dictionary, rr: RandomNumberGenerator) -> void:
	var c: Vector2 = il.c
	var d := c / maxf(absf(c.x), absf(c.y))
	var s := _shore(d * 1700.0, d.normalized(), 600.0)
	if s == Vector2.INF:
		return
	_pier(s, d.normalized(), rr)


## A ship that did not make it: on the strand, heeled over, with what it carried still aboard.
func _wreck(il: Dictionary, rr: RandomNumberGenerator, k: int) -> void:
	var c: Vector2 = w.terrain.isle_heart(il)
	var dir := Vector2.RIGHT
	var s := Vector2.INF
	# Round the isle until a strand is found with dry ground to leave the cargo on
	var a0 := rr.randf() * TAU + k * PI
	for tries in 16:
		var a := a0 + tries * TAU / 16.0
		dir = Vector2(cos(a), sin(a))
		s = _shore(c, dir, float(il.r) * 1.8)
		if s != Vector2.INF and s != c and w.terrain.height_at((s - dir * 4.0).x, (s - dir * 4.0).y) > WIsles.SEA_Y + 0.2:
			break
		s = Vector2.INF
	if s == Vector2.INF:
		return
	var q := s + dir * 6.0
	var p := Vector3(q.x, WIsles.SEA_Y - 2.2, q.y)
	var yaw := atan2(dir.y, -dir.x) + rr.randf_range(-0.4, 0.4)
	piece("pirate", "ship-wreck" if k == 0 else "ship-small", p, yaw, 1.5, true, Vector3(rr.randf_range(-0.08, 0.08), 0, rr.randf_range(0.18, 0.32)))
	var cq := s - dir * 4.0
	var cg := _ground(cq)
	WPlaces.ruin_at["wreck_%s_%d" % [il.key, k]] = cq
	if cg.y > WIsles.SEA_Y + 0.2:
		w._crate("wreck_%s_%d" % [il.key, k], cg, "caravan", rr.randf() * TAU)
		piece("pirate", "barrel", cg + Vector3(1.6, 0, 0.8), rr.randf() * TAU, 0.8, false, Vector3(PI * 0.5, 0, 0))
		piece("pirate", "bottle-large", cg + Vector3(-1.2, 0, 1.0), rr.randf() * TAU, 0.7)


# ------------------------------------------------------------------ each isle's own

## Hrafnsey: dark pine groves on the slopes, cairns on the heights, and the fishers' turf huts.
func _hrafn(il: Dictionary, rr: RandomNumberGenerator) -> void:
	for g in 9:
		var p := spot(il, rr, 0.25, 0.8)
		if p == Vector3.INF:
			continue
		for k in rr.randi_range(5, 10):
			var q := Vector2(p.x, p.z) + Vector2(rr.randf_range(-14, 14), rr.randf_range(-14, 14))
			var gq := _ground(q)
			if gq.y > WIsles.SEA_Y + 0.6:
				piece("grave", ["pine", "pine", "pine-crooked"][rr.randi() % 3], gq, rr.randf() * TAU, rr.randf_range(4.0, 6.5), true, Vector3.ZERO, _pine)
	for k in 6:
		var p := spot(il, rr, 0.3, 0.7, 0.7)
		if p != Vector3.INF:
			piece("grave", "pillar-obelisk", p, rr.randf() * TAU, rr.randf_range(3.0, 4.5), true)
			piece("grave", "rocks-tall", p + Vector3(1.6, 0, 0.4), rr.randf() * TAU, 2.6)
	for k in 3:
		var p := spot(il, rr, 0.4, 0.75)
		if p == Vector3.INF:
			continue
		var yaw := rr.randf() * TAU
		piece("pirate", "structure", p, yaw, 1.6, false)
		piece("pirate", "structure-roof", p + Vector3(0, 3.4, 0), yaw, 1.6, true)
		piece("pirate", "barrel", p + Vector3(3.2, 0, 1.0), rr.randf() * TAU, 0.8, true)
		piece("castle", "tree-small", p + Vector3(-4.0, 0, 2.0), 0.0, 3.0)


## The Sunk Fen: a drowned graveyard about the chapel, crooked iron, and lights over the water.
func _fen(il: Dictionary, rr: RandomNumberGenerator) -> void:
	var heart: Vector2 = w.terrain.isle_heart(il)
	for k in 46:
		var a := rr.randf() * TAU
		var q := heart + Vector2(cos(a), sin(a)) * rr.randf_range(14.0, 60.0)
		var g := _ground(q)
		if g.y < WIsles.SEA_Y - 0.6:
			continue
		var m: String = ["gravestone-round", "gravestone-cross", "gravestone-broken", "gravestone-wide", "cross-wood"][rr.randi() % 5]
		piece("grave", m, g - Vector3(0, 0.15, 0), a + PI * 0.5, 3.2, false, Vector3(rr.randf_range(-0.2, 0.2), 0, rr.randf_range(-0.2, 0.2)))
	for k in 5:
		var a := TAU * k / 5.0 + rr.randf_range(-0.3, 0.3)
		var q := heart + Vector2(cos(a), sin(a)) * rr.randf_range(24.0, 48.0)
		piece("grave", ["crypt-small", "crypt-large", "crypt"][k % 3], _ground(q) - Vector3(0, 0.3, 0), -a, 4.6, true)
	for k in 22:
		var a := TAU * k / 22.0
		var q := heart + Vector2(cos(a), sin(a)) * 66.0
		var g := _ground(q)
		if g.y > WIsles.SEA_Y - 0.8:
			piece("grave", "iron-fence-damaged" if rr.randf() < 0.4 else "iron-fence", g, -a + PI * 0.5, 2.6, false, Vector3(0, 0, rr.randf_range(-0.15, 0.15)))
	for k in 18:
		var p := spot(il, rr, 0.3, 0.9, 0.6)
		if p != Vector3.INF:
			piece("grave", "pine-fall", p, rr.randf() * TAU, rr.randf_range(3.5, 5.0), false, Vector3.ZERO, _dead)
	for k in 8:
		var p := spot(il, rr, 0.2, 0.7, 0.6)
		if p != Vector3.INF:
			piece("grave", "coffin-old", p + Vector3(0, -0.1, 0), rr.randf() * TAU, 2.2, false, Vector3(0.12, 0, 0.1))
	for k in 6:
		var p := spot(il, rr, 0.15, 0.5, 0.6)
		if p != Vector3.INF:
			piece("grave", "lightpost-single", p, rr.randf() * TAU, 2.6)
	for k in 14:
		_wisp(Vector2(il.c) + Vector2(rr.randf_range(-1, 1), rr.randf_range(-1, 1)) * float(il.r) * 0.7, rr)


## Kalaja: the keep's towers and walls, and siege engines drawn up against an enemy that never came.
func _kala(il: Dictionary, rr: RandomNumberGenerator) -> void:
	var heart: Vector2 = w.terrain.isle_heart(il)
	var c: Vector2 = il.c
	var toward := -c.normalized()
	# Four towers about the keep, joined by a curtain wall, all in the old kit's stone
	var corners: Array = []
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25 + atan2(toward.y, toward.x)
		corners.append(heart + Vector2(cos(a), sin(a)) * 22.0)
	for k in 4:
		var q: Vector2 = corners[k]
		var g := _ground(q) - Vector3(0, 1.0, 0)
		var s := 5.0
		piece("castle", "tower-square-base", g, 0.0, s, true)
		piece("castle", "tower-square-mid", g + Vector3(0, s, 0), 0.0, s, true)
		piece("castle", "tower-square-mid-windows", g + Vector3(0, s * 2.0, 0), 0.0, s, true)
		piece("castle", "tower-square-top-roof", g + Vector3(0, s * 3.0, 0), 0.0, s)
		piece("castle", "flag-banner-long", g + Vector3(2.6, s * 2.2, 0), 0.0, 3.0)
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var run := a.distance_to(b)
		var dir := (b - a) / run
		var n := int(run / 5.0)
		for i in range(1, n):
			if k == 0 and i == n / 2:
				continue   # the gate gap, toward the sea and the waste
			var q := a + dir * (i * 5.0)
			piece("castle", "wall", _ground(q) - Vector3(0, 0.8, 0), atan2(dir.x, dir.y) + PI * 0.5, 5.0, true)
	# Siege engines on the slopes, all facing out to sea; most fell to weather, not war
	for k in 10:
		var p := spot(il, rr, 0.35, 0.8)
		if p == Vector3.INF:
			continue
		var out := Vector2(p.x, p.z) - c
		var yaw := atan2(out.x, out.y)
		var m: String = ["siege-ballista", "siege-catapult", "siege-ballista-demolished", "siege-catapult-demolished", "siege-trebuchet-demolished", "siege-tower-demolished", "siege-ram-demolished"][k % 7]
		piece("castle", m, p, yaw, 4.0, true)
	for k in 5:
		var p := spot(il, rr, 0.3, 0.8)
		if p != Vector3.INF:
			for i in 3:
				piece("castle", "rocks-large", p + Vector3(rr.randf_range(-5, 5), -0.3, rr.randf_range(-5, 5)), rr.randf() * TAU, rr.randf_range(3.0, 5.0), true)
	for k in 12:
		var p := spot(il, rr, 0.2, 0.85)
		if p != Vector3.INF:
			piece("castle", "tree-large" if rr.randf() < 0.5 else "tree-small", p, rr.randf() * TAU, rr.randf_range(3.5, 5.0), true)


## Cogwright: mills that still turn, scaffolds and wagons rusting, cannon on the shore.
func _cog(il: Dictionary, rr: RandomNumberGenerator) -> void:
	var c: Vector2 = il.c
	for k in 3:
		var p := spot(il, rr, 0.3, 0.7)
		if p == Vector3.INF:
			continue
		_mill(p, rr.randf() * TAU)
	for k in 6:
		var p := spot(il, rr, 0.25, 0.8)
		if p == Vector3.INF:
			continue
		var yaw := rr.randf() * TAU
		for i in rr.randi_range(2, 4):
			piece("urban", "scaffolding-structure", p + Vector3(0, i * 5.0, 0), yaw, 5.0, i == 0)
		piece("urban", "detail-light-single", p + Vector3(4.0, 0, 0), yaw, 5.0)
	for k in 8:
		var p := spot(il, rr, 0.2, 0.85)
		if p == Vector3.INF:
			continue
		var m: String = ["truck-grey-cargo", "detail-dumpster-open", "pallet", "detail-barrier-strong-damaged", "wall-broken-type-a", "roof-metal-poles"][k % 6]
		piece("urban", m, p, rr.randf() * TAU, 6.0, m != "pallet", Vector3(0, 0, rr.randf_range(-0.08, 0.08)))
	for k in 6:
		var a := rr.randf() * TAU
		var dir := Vector2(cos(a), sin(a))
		var s := _shore(c, dir, float(il.r) * 1.6)
		if s == Vector2.INF:
			continue
		var g := _ground(s - dir * 6.0)
		piece("pirate", "cannon", g, atan2(dir.x, dir.y), 1.6, true)
		piece("pirate", "cannon-ball", g + Vector3(1.4, 0.3, -0.6), 0.0, 0.8)
	for k in 5:
		var p := spot(il, rr, 0.3, 0.8)
		if p != Vector3.INF:
			piece("town", "cart-high" if k % 2 == 0 else "cart", p, rr.randf() * TAU, 2.4, true)


## A mill tower of plank and stone, with four sails that turn in the wind.
func _mill(p: Vector3, yaw: float) -> void:
	var base = w.cyl(Vector3.ZERO, 2.6, 9.0, w._m.darkwood, true, 1.6, 8)
	base.reparent(self, false)
	base.global_position = p + Vector3(0, 4.5, 0)
	var hub := Node3D.new()
	add_child(hub)
	hub.global_position = p + Vector3(0, 8.2, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 2.2
	hub.rotation.y = yaw
	var spin := Node3D.new()
	hub.add_child(spin)
	for k in 4:
		var arm = w.box(Vector3.ZERO, Vector3(0.3, 6.5, 0.15), w._m.wood, false)
		arm.reparent(spin, false)
		arm.rotation.z = TAU * k / 4.0
		arm.position = Vector3(sin(TAU * k / 4.0) * -3.3, cos(TAU * k / 4.0) * 3.3, 0)
		var sail = w.box(Vector3.ZERO, Vector3(1.4, 5.0, 0.05), w._m.cloth, false)
		sail.reparent(arm, false)
		sail.position = Vector3(0.8, 0.4, 0)
	spinners.append([spin, Vector3(0, 0, 1), 0.6])


# ------------------------------------------------------------------ life

func _gull(at: Vector2, rr: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	add_child(n)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.86, 0.84)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.12
	bm.height = 0.6
	body.mesh = bm
	body.material_override = m
	body.rotation.x = PI * 0.5
	n.add_child(body)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		n.add_child(pivot)
		var wing := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.75, 0.28)
		wing.mesh = q
		wing.material_override = m
		wing.rotation.x = -PI * 0.5
		wing.position.x = side * 0.38
		pivot.add_child(wing)
		pivot.set_meta("side", side)
	gulls.append([n, at, rr.randf_range(25.0, 70.0), rr.randf_range(12.0, 30.0), rr.randf_range(0.12, 0.25) * (1.0 if rr.randf() < 0.5 else -1.0), rr.randf() * TAU])


func _wisp(at: Vector2, rr: RandomNumberGenerator) -> void:
	var g := _ground(at)
	var y := maxf(g.y, WIsles.SEA_Y) + 1.4
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(at.x, y, at.y)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.6, 0.95, 0.8)
	m.emission_enabled = true
	m.emission = Color(0.5, 1.0, 0.75)
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	s.mesh = sm
	s.material_override = m
	s.visibility_range_end = 300.0
	n.add_child(s)
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 1.0, 0.75)
	l.light_energy = 0.9
	l.omni_range = 6.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 90.0
	n.add_child(l)
	wisps.append([n, n.global_position, rr.randf() * TAU])


func _process(delta: float) -> void:
	if Net.dedicated or w.player == null:
		return
	t += delta
	var me: Vector3 = w.player.global_position
	for g in gulls:
		var n: Node3D = g[0]
		var c: Vector2 = g[1]
		if Vector2(me.x, me.z).distance_to(c) > 700.0:
			n.visible = false
			continue
		n.visible = true
		var a: float = g[5] + t * float(g[4])
		var r: float = g[2]
		var h: float = WIsles.SEA_Y + float(g[3]) + sin(t * 0.3 + float(g[5])) * 3.0
		n.global_position = Vector3(c.x + cos(a) * r, h, c.y + sin(a) * r)
		var fwd := Vector3(-sin(a), 0, cos(a)) * signf(float(g[4]))
		n.look_at(n.global_position + fwd, Vector3.UP)
		n.rotation.z = -0.35 * signf(float(g[4]))
		var flap := sin(t * 7.0 + float(g[5])) * 0.5 if fmod(t + float(g[5]), 6.0) < 2.0 else 0.08
		for pv in n.get_children():
			if pv.has_meta("side"):
				pv.rotation.z = flap * float(pv.get_meta("side"))
	var night: bool = w.night
	for wp in wisps:
		var n: Node3D = wp[0]
		var home: Vector3 = wp[1]
		var ph: float = wp[2]
		n.visible = night or w.weather == null or w.weather.kind != "clear"
		if not n.visible:
			continue
		n.global_position = home + Vector3(sin(t * 0.21 + ph) * 6.0, sin(t * 0.9 + ph) * 0.5, cos(t * 0.17 + ph * 1.3) * 6.0)
	var gust: float = w.sea.wind if w.sea else 0.5
	for sp in spinners:
		(sp[0] as Node3D).rotate(sp[1], float(sp[2]) * (0.4 + gust) * delta)
