class_name WDress
## What gives each place its own look, from the free Kenney kits: the ruins built of real pieces,
## each land's own leavings on the ground and about its ruins, and each town's own things in its
## square and along its wall (sacks at the salt camp, lamps at the oil well, graves at the mourners').
## Everything is placed from the world's seed, so it stands the same on every machine.

const NEAR := 220.0   ## small things are not drawn past this


static func kp(parent: Node3D, kit: String, model: String, local: Vector3, yaw := 0.0, s := 1.0, solid := false, tilt := Vector3.ZERO, far := NEAR) -> Node3D:
	var n := WIsleLife.put(parent, kit, model, local, yaw, s, solid, tilt, null, far)
	if model == "fire-basket" and tilt == Vector3.ZERO:
		# A basket of coals still burning, as if someone left a moment ago
		var bb := WIsleLife.bounds(kit + "/" + model, n)
		var f := WFire.make(0.35, true, false)
		f.position = Vector3(bb.get_center().x, bb.end.y * 0.85, bb.get_center().z)
		n.add_child(f)
	return n


## A local spot under n, set down on the ground (n turns only about its upright).
static func ground(w, n: Node3D, off: Vector3) -> Vector3:
	var g := n.position + off.rotated(Vector3.UP, n.rotation.y)
	return Vector3(off.x, w.terrain.height_at(g.x, g.z) - n.position.y, off.z)


# ------------------------------------------------------------------ the lands

## What each land leaves lying about its ruins and camps: [kit, model, smallest, largest, solid].
## The "scan" kit is the photographed trees and stones (Poly Haven, CC0); the rest are Kenney's kits.
const LAND_PROPS := {
	"ash": [["scan", "dead_tree_trunk_02", 0.6, 0.9, true], ["scan", "dead_quiver_branch_01", 2.5, 3.5, false], ["grave", "debris", 2.5, 3.5, false],
		["scan", "rock_07", 5.0, 8.0, true], ["grave", "fire-basket", 2.2, 2.6, false], ["scan", "dead_quiver_trunk", 1.2, 1.8, true]],
	"dunes": [["scan", "moon_rock_02", 3.0, 5.0, true], ["town", "cart", 2.0, 2.4, true], ["food", "bag", 1.6, 2.2, false],
		["pirate", "bottle-large", 0.7, 0.9, false], ["town", "wheel", 2.0, 2.4, false], ["castle", "siege-ram-demolished", 1.6, 2.0, true]],
	"salt": [["scan", "rock_07", 6.0, 10.0, true], ["pirate", "crate-bottles", 0.8, 0.9, true], ["food", "bag-flat", 1.8, 2.4, false],
		["pirate", "barrel", 0.6, 0.7, true], ["pirate", "cannon-ball", 0.5, 0.7, false]],
	"forest": [["scan", "dead_tree_trunk_02", 0.7, 1.0, true], ["scan", "dead_quiver_trunk", 2.0, 3.2, true], ["grave", "hay-bale", 1.6, 2.0, true],
		["food", "mushroom", 6.0, 10.0, false], ["scan", "dead_quiver_branch_01", 2.5, 3.5, false], ["scan", "dead_quiver_trunk", 1.6, 2.6, true]],
	"basalt": [["scan", "namaqualand_boulder_03", 0.5, 0.9, true], ["castle", "wall-half", 2.4, 3.0, true], ["grave", "column-large", 2.4, 3.0, true],
		["castle", "siege-catapult-demolished", 2.0, 2.4, true], ["castle", "siege-ballista-demolished", 1.8, 2.2, true]],
	"marsh": [["grave", "gravestone-broken", 2.2, 2.8, false], ["grave", "coffin-old", 2.0, 2.4, false], ["grave", "cross-wood", 2.0, 2.6, false],
		["grave", "iron-fence-damaged", 2.2, 2.6, false], ["grave", "lantern-candle", 1.8, 2.2, false], ["scan", "dead_tree_trunk_02", 0.6, 0.9, false]],
}

## What grows or lies across each land, far and wide, drawn in batches: [kit, model, count, smallest, largest].
const LAND_COVER := {
	"ash": [["scan", "dead_quiver_trunk", 220, 1.8, 3.2], ["scan", "dead_quiver_branch_01", 200, 2.2, 3.6], ["scan", "rock_07", 160, 3.0, 7.0]],
	"dunes": [["scan", "moon_rock_02", 140, 3.0, 8.0], ["scan", "rock_07", 100, 2.5, 6.0], ["pirate", "patch-sand", 0, 1.0, 1.0]],
	"salt": [["scan", "rock_07", 240, 4.0, 12.0], ["scan", "moon_rock_02", 200, 5.0, 11.0]],
	"forest": [["scan", "dead_quiver_trunk", 600, 2.2, 3.8], ["scan", "dead_quiver_branch_01", 220, 2.5, 4.0], ["scan", "dead_tree_trunk_02", 120, 0.7, 1.1]],
	"basalt": [["scan", "moon_rock_02", 280, 8.0, 16.0], ["scan", "rock_07", 240, 6.0, 12.0]],
	"marsh": [["grave", "pine-fall-crooked", 0, 1.0, 1.0], ["scan", "dead_quiver_trunk", 220, 1.4, 2.6], ["scan", "dead_tree_trunk_02", 120, 0.6, 1.0], ["grave", "gravestone-broken", 60, 2.0, 2.6]],
}


## A few of the land's leavings about a place, between rmin and rmax from its middle.
static func scatter(w, n: Node3D, land: String, rr: RandomNumberGenerator, count: int, rmin: float, rmax: float) -> void:
	var list: Array = LAND_PROPS.get(land, LAND_PROPS.ash)
	for i in count:
		var it: Array = list[rr.randi() % list.size()]
		var a := rr.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * rr.randf_range(rmin, rmax)
		kp(n, it[0], it[1], ground(w, n, off), rr.randf() * TAU, rr.randf_range(it[2], it[3]), it[4])


static func _mesh_of(kit: String, model: String) -> Array:
	var inst := WIsleLife.make(kit, model)
	var mis := inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		mis.append(inst)
	var out: Array = []
	if not mis.is_empty():
		var mi: MeshInstance3D = mis[0]
		var tr: Transform3D = Transform3D.IDENTITY if mi == inst else mi.transform
		var p: Node = mi.get_parent() if mi != inst else null
		while p and p != inst:
			tr = (p as Node3D).transform * tr
			p = p.get_parent()
		out = [mi.mesh, tr]
	inst.free()
	return out


## Each land's own cover, over the near waste: tiles of batched models, drawn only near.
static func cover(w) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = w.world_seed + 9191
	var tile := 128.0   # small tiles, so the far ones are drawn plainer (each tile picks its own detail)
	var half := 950.0
	for land in LAND_COVER:
		for spec in LAND_COVER[land]:
			if int(spec[2]) <= 0:
				continue
			var mt := _mesh_of(spec[0], spec[1])
			if mt.is_empty():
				continue
			var tiles := {}
			var placed := 0
			var tries := 0
			while placed < int(spec[2]) and tries < int(spec[2]) * 40:
				tries += 1
				var x := r.randf_range(-half, half)
				var z := r.randf_range(-half, half)
				if w.terrain.biome_name(x, z) != land or w.terrain.is_water(x, z, 0.5):
					continue
				if not w._clear_of_places(Vector2(x, z), 40.0, 14.0):
					continue
				var key := Vector2i(int(floor(x / tile)), int(floor(z / tile)))
				var s := r.randf_range(spec[3], spec[4])
				var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * s)
				var t := Transform3D(b, Vector3(x, w.terrain.height_at(x, z) - 0.05, z)) * (mt[1] as Transform3D)
				if not tiles.has(key):
					tiles[key] = []
				tiles[key].append(t)
				placed += 1
			for key in tiles:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mt[0]
				var ts: Array = tiles[key]
				mm.instance_count = ts.size()
				# Each tile sits at its own middle, so it is drawn by how near that is
				var mid := Vector3((key.x + 0.5) * tile, 0.0, (key.y + 0.5) * tile)
				for i in ts.size():
					mm.set_instance_transform(i, (ts[i] as Transform3D).translated(-mid))
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.position = mid
				mmi.visibility_range_end = 420.0
				mmi.visibility_range_end_margin = 30.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				w.add_child(mmi)


# ------------------------------------------------------------------ ruins

## A ruin of the kits, in the ruin's own node n (at its middle, turned). Its crates are set apart.
static func ruin(w, kind: String, n: Node3D, rr: RandomNumberGenerator, land: String) -> void:
	match kind:
		"wreck":
			# A caravan overturned: its wagons on their sides, a wheel off, what it carried spilled
			for k in 2:
				var at := ground(w, n, Vector3(k * 5.5 - 2.75, 0, rr.randf_range(-2, 2)))
				kp(n, "town", "cart-high" if k == 0 else "cart", at, rr.randf() * TAU, 2.4, true, Vector3(0, 0, rr.randf_range(0.5, 1.4)))
			kp(n, "town", "wheel", ground(w, n, Vector3(1.0, 0.0, 3.2)), rr.randf() * TAU, 2.2, false, Vector3(PI * 0.5, 0, 0))
			for k in 3:
				var off := Vector3(rr.randf_range(-4, 4), 0, rr.randf_range(2.5, 5.0) * (1.0 if k % 2 == 0 else -1.0))
				var pick: Array = [["pirate", "barrel", 0.6], ["pirate", "crate", 0.7], ["food", "bag", 1.8]][k]
				kp(n, pick[0], pick[1], ground(w, n, off), rr.randf() * TAU, pick[2], false, Vector3(0, 0, rr.randf_range(0.0, 1.5)))
			kp(n, "grave", "character-skeleton", ground(w, n, Vector3(1.5, 0.05, -3.5)), rr.randf() * TAU, 2.0)
		"shrine":
			# An altar under the sky, in a ring of broken pillars, its candles long out
			kp(n, "grave", "altar-stone", ground(w, n, Vector3.ZERO), 0.0, 3.0, true)
			kp(n, "grave", "candle-multiple", Vector3(-0.8, ground(w, n, Vector3.ZERO).y + 1.45, 0.1), 0.0, 2.0)
			kp(n, "grave", "detail-chalice", Vector3(0.7, ground(w, n, Vector3.ZERO).y + 1.45, 0.0), 0.0, 2.2)
			for k in 6:
				var a := TAU * k / 6
				var off := Vector3(cos(a) * 5.0, 0, sin(a) * 5.0)
				var pick: Array = [["grave", "pillar-obelisk", rr.randf_range(3.0, 4.5)], ["grave", "column-large", rr.randf_range(2.6, 3.6)], ["grave", "gravestone-debris", 2.6]][k % 3]
				kp(n, pick[0], pick[1], ground(w, n, off), rr.randf() * TAU, pick[2], true, Vector3(rr.randf_range(-0.08, 0.08), 0, rr.randf_range(-0.08, 0.08)))
		"tower":
			# A keep's tower, its top fallen, its stones about its foot
			var base := ground(w, n, Vector3.ZERO)
			kp(n, "castle", "tower-hexagon-base", base, rr.randf() * TAU, 5.0, true)
			if rr.randf() < 0.6:
				kp(n, "castle", "tower-hexagon-mid", base + Vector3(0, 6.55, 0), rr.randf() * TAU, 5.0, false)
			for k in 7:
				var a := rr.randf() * TAU
				var off := Vector3(cos(a), 0, sin(a)) * rr.randf_range(4.5, 8.5)
				kp(n, "castle", "rocks-small" if k % 2 == 0 else "rocks-large", ground(w, n, off), rr.randf() * TAU, rr.randf_range(0.9, 1.6), k % 3 == 0)
			kp(n, "castle", "wall-half", ground(w, n, Vector3(5.5, 0, -1.5)), rr.randf() * TAU, 3.0, true, Vector3(0, 0, 0.12))
		"camp":
			# Tents about a cold fire, the camp's things left as they were
			for k in 3:
				var a := TAU * k / 3 + 0.4
				var tent := MeshInstance3D.new()
				var pm := PrismMesh.new()
				pm.size = Vector3(2.6, 1.8, 3.0)
				tent.mesh = pm
				tent.material_override = w._m.cloth
				n.add_child(tent)
				tent.position = ground(w, n, Vector3(cos(a) * 4, 0, sin(a) * 4)) + Vector3(0, 0.9, 0)
				tent.rotation.y = -a
			kp(n, "grave", "fire-basket", ground(w, n, Vector3.ZERO), 0.0, 2.6)
			kp(n, "food", "pot", ground(w, n, Vector3(0.9, 0, 0.3)), rr.randf() * TAU, 1.5)
			kp(n, "grave", "bench-damaged", ground(w, n, Vector3(0, 0, -2.0)), 0.0, 2.2, true)
			kp(n, "grave", "hay-bale-bundled", ground(w, n, Vector3(2.2, 0, 1.6)), rr.randf() * TAU, 1.8, true)
			kp(n, "pirate", "barrel", ground(w, n, Vector3(-2.4, 0, 1.4)), rr.randf() * TAU, 0.6, true)
			kp(n, "food", "bag-flat", ground(w, n, Vector3(-1.4, 0, 2.4)), rr.randf() * TAU, 2.0)
		"vault":
			# A tomb of the Order sunk in the ground, its door to the front
			kp(n, "grave", "crypt-large", ground(w, n, Vector3(0, -0.2, -4.0)), PI, 4.0, true)
			for side in [-1.0, 1.0]:
				kp(n, "grave", "pillar-obelisk", ground(w, n, Vector3(side * 2.6, 0, 1.6)), 0.0, 4.0, true)
				kp(n, "grave", "lantern-candle", ground(w, n, Vector3(side * 1.4, 0, 2.4)), 0.0, 1.8)
		"stones":
			# A ring of standing stones, some leaning, some fallen
			for k in 9:
				var a := TAU * k / 9
				var off := Vector3(cos(a) * 7, 0, sin(a) * 7)
				if rr.randf() < 0.75:
					kp(n, "grave", "pillar-obelisk", ground(w, n, off) + Vector3(0, -0.3, 0), -a, rr.randf_range(3.0, 5.2), true, Vector3(rr.randf_range(-0.12, 0.12), 0, rr.randf_range(-0.12, 0.12)))
				else:
					kp(n, "grave", "pillar-obelisk", ground(w, n, off) + Vector3(0, 0.5, 0), -a, 3.6, true, Vector3(PI * 0.5, 0, 0))
			kp(n, "grave", "altar-stone", ground(w, n, Vector3.ZERO), rr.randf() * TAU, 2.4, true)
	scatter(w, n, land, rr, 4, 7.0, 12.0)


## Crate or iron chest: the kit's own, with a loose board for a lid that is pushed off when searched.
static func crate(n: Node3D, sealed: bool) -> void:
	if sealed:
		kp(n, "pirate", "chest", Vector3.ZERO, 0.0, 0.62, false, Vector3.ZERO, 160.0)
	else:
		kp(n, "pirate", "crate", Vector3.ZERO, 0.0, 0.78, false, Vector3.ZERO, 160.0)


# ------------------------------------------------------------------ towns

## Each town's own things: [kit, model, scale, solid], first for its square, then along its wall.
const TOWN_LOOK := {
	"cinderwick": {"square": [["food", "bag-flat", 2.2, false], ["food", "bag-flat", 2.2, false], ["grave", "shovel-dirt", 2.2, false], ["town", "cart", 2.2, true], ["food", "bag", 1.8, false]],
		"wall": [["food", "bag-flat", 2.2, false], ["pirate", "crate", 0.8, true], ["pirate", "barrel", 0.65, true], ["grave", "hay-bale", 1.8, true]]},
	"lanternwell": {"square": [["town", "lantern", 2.0, true], ["town", "lantern", 2.0, true], ["food", "barrel", 1.4, true], ["food", "bottle-oil", 2.4, false], ["food", "bottle-oil", 2.4, false]],
		"wall": [["pirate", "barrel", 0.65, true], ["food", "barrel", 1.4, true], ["town", "lantern", 2.0, true], ["grave", "lightpost-single", 2.6, true]]},
	"hesk": {"square": [["town", "stall-red", 2.4, true], ["town", "stall-green", 2.4, true], ["town", "cart-high", 2.2, true], ["town", "banner-red", 2.6, false], ["town", "stall-bench", 2.4, false]],
		"wall": [["pirate", "crate", 0.8, true], ["town", "cart", 2.2, true], ["pirate", "crate-bottles", 0.8, true], ["food", "barrel", 1.4, true]]},
	"kiln": {"square": [["food", "pot", 2.2, false], ["food", "bowl", 2.0, false], ["food", "plate", 1.6, false], ["grave", "fire-basket", 3.0, false], ["pirate", "cannon-ball", 0.6, false]],
		"wall": [["castle", "rocks-small", 1.4, true], ["castle", "tree-log", 2.6, true], ["food", "pot", 2.2, false], ["pirate", "crate", 0.8, true]]},
	"mourners": {"square": [["grave", "candle-multiple", 2.4, false], ["grave", "altar-wood", 2.4, true], ["grave", "urn-round", 2.6, false], ["grave", "lantern-candle", 2.0, false]],
		"wall": [["grave", "gravestone-round", 2.4, false], ["grave", "gravestone-cross", 2.4, false], ["grave", "cross-wood", 2.4, false], ["grave", "coffin-old", 2.2, false], ["grave", "gravestone-wide", 2.2, false]]},
	"gallowmere": {"square": [["pirate", "boat-row-small", 0.9, true], ["food", "fish", 2.4, false], ["pirate", "tool-paddle", 0.8, false], ["food", "barrel", 1.4, true]],
		"wall": [["pirate", "crate", 0.8, true], ["pirate", "barrel", 0.65, true], ["pirate", "crate-bottles", 0.8, true], ["grave", "lantern-candle", 2.0, false]]},
	"saltreach": {"square": [["food", "bag", 2.0, false], ["food", "bag-flat", 2.2, false], ["pirate", "crate-bottles", 0.8, true], ["pirate", "flag-pirate-high", 0.9, false]],
		"wall": [["food", "bag-flat", 2.2, false], ["pirate", "barrel", 0.65, true], ["pirate", "crate", 0.8, true], ["grave", "rocks-tall", 1.6, true]]},
	"emberhollow": {"square": [["grave", "fire-basket", 3.0, false], ["grave", "fire-basket", 3.0, false], ["town", "cart", 2.2, true], ["grave", "shovel-dirt", 2.2, false]],
		"wall": [["castle", "rocks-large", 1.4, true], ["castle", "tree-log", 2.6, true], ["grave", "debris", 3.0, false], ["pirate", "barrel", 0.65, true]]},
	"lastlight": {"square": [["grave", "lightpost-single", 2.8, true], ["grave", "lightpost-single", 2.8, true], ["castle", "flag-banner-long", 2.0, false], ["town", "fountain-round", 1.6, true]],
		"wall": [["castle", "wall-half", 2.2, true], ["castle", "rocks-small", 1.2, true], ["castle", "stairs-stone", 2.4, true], ["pirate", "barrel", 0.65, true]]},
}


## A town's own things about its square and along the inside of its wall, clear of its roads,
## buildings and people. Lamps and fire-baskets give light; banners hang from the gate posts.
static func town(w, k: String, c: Vector3, r: float, plan: Array, folk: Array) -> void:
	var look: Dictionary = TOWN_LOOK.get(k, TOWN_LOOK.cinderwick)
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(k + "dress")
	var n := Node3D.new()
	n.position = c
	w.add_child(n)
	var taken: Array = []
	var clear := func(off: Vector2, fr: float) -> bool:
		if absf(off.x) < 2.8 + fr:
			return false   # the road from gate to gate
		for f in folk:
			if (f as Vector2).distance_to(off) < fr + 1.6:
				return false
		for b in plan:
			if (b.off as Vector2).distance_to(off) < float(b.fr) + fr + 0.8:
				return false
		for t in taken:
			if (t as Vector2).distance_to(off) < fr + 1.2:
				return false
		return true
	for ring in [["square", 3.4, 5.4, 7], ["wall", r - 2.4, r - 1.5, 16]]:
		var list: Array = look[ring[0]]
		var want: int = ring[3]
		var put := 0
		for t in want * 8:
			if put >= want:
				break
			var a := rr.randf() * TAU
			var off := Vector2(cos(a), sin(a)) * rr.randf_range(ring[1], ring[2])
			var it: Array = list[put % list.size()]
			var fr := 1.2 if it[3] else 0.7
			if not clear.call(off, fr):
				continue
			taken.append(off)
			put += 1
			var at := Vector3(off.x, w.terrain.height_at(c.x + off.x, c.z + off.y) - c.y, off.y)
			var face := atan2(-off.x, -off.y)
			kp(n, it[0], it[1], at, face + rr.randf_range(-0.4, 0.4), it[2], it[3])
			if it[1] in ["lantern", "lightpost-single", "fire-basket"]:
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.66, 0.36)
				l.light_energy = 0.9
				l.omni_range = 7.0
				l.position = at + Vector3(0, 3.2 if it[1] != "fire-basket" else 1.0, 0)
				l.distance_fade_enabled = true
				l.distance_fade_begin = 80.0
				n.add_child(l)
	# Benches about the fire, for sitting at the end of the day
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var off := Vector2(cos(a), sin(a)) * 3.0
		if absf(off.x) < 1.6:
			continue
		kp(n, "town", "stall-bench", Vector3(off.x, w.terrain.height_at(c.x + off.x, c.z + off.y) - c.y, off.y), atan2(off.x, off.y) + PI * 0.5, 2.4)
	# Banners on the gate posts
	var banner: String = "banner-red" if absi(hash(k)) % 2 == 0 else "banner-green"
	for g in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var a: float = PI * 0.5 * g + side * 0.14
			var p := Vector3(cos(a) * r, 0, sin(a) * r)
			p.y = w.terrain.height_at(c.x + p.x, c.z + p.z) - c.y + 1.6
			kp(n, "town", banner, p + Vector3(0, 0, -g * 0.35), PI * 0.5, 2.6)


## What a house keeps in its yard, from its town's own things.
static func yard(n: Node3D, k: String, at: Vector3, rr: RandomNumberGenerator) -> void:
	var look: Dictionary = TOWN_LOOK.get(k, TOWN_LOOK.cinderwick)
	var list: Array = look.wall + [["pirate", "barrel", 0.65, true], ["pirate", "crate", 0.8, true]]
	var it: Array = list[rr.randi() % list.size()]
	if it[1] in ["cart", "cart-high", "boat-row-small", "wall-half", "stairs-stone", "lightpost-single", "rocks-large"]:
		it = ["pirate", "barrel", 0.65, true]
	kp(n, it[0], it[1], at, rr.randf() * TAU, it[2], it[3])


## A meal or a day's work on a table top (y is the top), different on each.
const TABLE_SETS := [
	[["food", "plate", 1.2, Vector2(-0.3, 0)], ["food", "loaf", 1.0, Vector2(0.3, 0.1)], ["food", "mug", 1.0, Vector2(0.1, -0.25)]],
	[["food", "pot-stew", 1.0, Vector2(0, 0)], ["food", "bowl", 0.9, Vector2(0.5, 0.15)], ["food", "bowl", 0.9, Vector2(-0.5, 0.15)]],
	[["food", "cheese", 0.8, Vector2(-0.25, 0)], ["food", "wine-red", 1.0, Vector2(0.35, 0.1)], ["food", "glass-wine", 1.0, Vector2(0.15, -0.2)]],
	[["furn", "books", 0.5, Vector2(0, 0)], ["grave", "candle", 2.0, Vector2(0.45, 0.1)]],
	[["food", "cutting-board", 1.1, Vector2(0, 0)], ["food", "fish", 1.2, Vector2(0, 0.05)], ["food", "cooking-knife", 0.8, Vector2(0.2, -0.2)]],
	[["food", "frying-pan", 0.8, Vector2(0, 0)], ["food", "onion", 1.2, Vector2(0.4, 0.2)], ["food", "carrot", 0.8, Vector2(-0.4, 0.2)]],
	[["food", "loaf-round", 0.8, Vector2(0, 0)], ["food", "apple", 1.2, Vector2(0.4, 0.15)], ["food", "apple", 1.2, Vector2(0.3, -0.2)]],
]


static func table_top(n: Node3D, top: Vector3, yaw: float, rr: RandomNumberGenerator, set_i := -1) -> void:
	var set: Array = TABLE_SETS[set_i if set_i >= 0 else rr.randi() % TABLE_SETS.size()]
	for it in set:
		var o: Vector2 = (it[3] as Vector2).rotated(-yaw)
		kp(n, it[0], it[1], top + Vector3(o.x, 0, o.y), yaw + rr.randf_range(-0.5, 0.5), it[2], false, Vector3.ZERO, 60.0)


## A market stall's wares on its counter: what the town trades in.
const WARES := {
	"hesk": [["food", "cheese", 0.8], ["food", "fish", 1.4], ["food", "loaf", 1.0], ["food", "cabbage", 1.4], ["food", "apple", 1.6], ["food", "wine-red", 1.2]],
	"lanternwell": [["food", "bottle-oil", 1.4], ["food", "bottle-oil", 1.4], ["grave", "lantern-glass", 1.4], ["grave", "candle-multiple", 1.6]],
	"kiln": [["food", "pot", 1.0], ["food", "bowl", 1.2], ["food", "plate", 0.9], ["food", "mug", 1.2]],
	"mourners": [["grave", "candle", 2.0], ["grave", "urn-round", 1.6], ["grave", "detail-chalice", 2.0], ["grave", "lantern-candle", 1.4]],
	"gallowmere": [["food", "fish", 1.4], ["food", "fish", 1.4], ["food", "barrel", 0.5], ["food", "loaf", 1.0]],
	"_": [["food", "meat-ribs", 1.2], ["food", "beet", 2.0], ["food", "bag", 1.0], ["food", "loaf", 1.0], ["food", "mushroom", 3.0], ["food", "onion", 1.6]],
}


static func wares(n: Node3D, k: String, top: Vector3, rr: RandomNumberGenerator) -> void:
	var list: Array = WARES.get(k, WARES["_"])
	for i in 4:
		var it: Array = list[rr.randi() % list.size()]
		kp(n, it[0], it[1], top + Vector3(-0.9 + i * 0.6, 0, rr.randf_range(-0.12, 0.12)), rr.randf() * TAU, it[2], false, Vector3.ZERO, 80.0)
