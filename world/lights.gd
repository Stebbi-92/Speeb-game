class_name WLights
extends RefCounted
## The Lighthouse chain (0.16). The Lamp Fleet built lighthouses on rocks across the far sea to carry
## the beacons' light past the horizon. All are dark. Each is a small beacon: pour lamp oil, hold
## against what comes up out of the water, and it burns again. Two lit lighthouses on one way make
## a sea lane: a safe road over the water to a far isle, shown on the map, where the Grey Wyrm and
## the Lamp-Eater do not come. Out on one lane lies the Kelp Forest, where boats go slowly and the
## weed eels pull swimmers under.

const OIL := 3                 ## lamp oil poured to light one
const HOLD_SECS := 40.0        ## how long the sea comes for it before it holds
const LANE_SAFE := 260.0       ## a lit lane keeps the deep this far off either side
const KELP_R := 170.0          ## the Kelp Forest's reach
const KELP_SLOW := 0.45        ## how fast a boat goes in it

var w
var houses: Array = []         ## {pos: Vector3, lane: isle key, name, node, lamp, light, area}
var lanes := {}                ## isle key -> [from: Vector2, to: Vector2, name]
var kelp := Vector3.INF        ## the Kelp Forest's middle, on the water
var _holding := {}             ## host: house index -> seconds left
var _kelp_t := 20.0
var _kelp_told := false


func _init(world) -> void:
	w = world


func lit(i: int) -> bool:
	return w.flags.has("house_%d" % i)


## Lays the lanes out from the world's isles: one from the waste's coast to each far isle and
## Far Shore, with two lighthouses along it on open water, and the Kelp Forest off one of them.
func plan() -> void:
	houses.clear()
	lanes.clear()
	for il in w.terrain.isles:
		if not WIsles.far(il):
			continue
		var c: Vector2 = il.c
		var dir := c.normalized()
		var from := dir * 2300.0
		var to := c - dir * (float(il.r) + 160.0)
		lanes[il.key] = [from, to, il.name]
		for k in 2:
			var t := 0.33 + k * 0.34
			var q := _open_spot(from.lerp(to, t), dir)
			if q != Vector2.INF:
				houses.append({"pos": Vector3(q.x, WIsles.SEA_Y, q.y), "lane": il.key, "name": "%s Light %s" % [str(il.name).trim_prefix("The "), ["I", "II"][k]]})
	# The Kelp Forest lies off one of the lanes, to one side of it, wherever the sea is open enough
	for key in lanes:
		var ln: Array = lanes[key]
		var mid: Vector2 = ln[0].lerp(ln[1], 0.5)
		var side: Vector2 = (ln[1] - ln[0]).normalized().orthogonal()
		for k in 12:
			var q: Vector2 = mid + side * (1.0 if k % 2 == 0 else -1.0) * (330.0 + (k / 2) * 70.0)
			if _kelp_fits(q):
				kelp = Vector3(q.x, WIsles.SEA_Y, q.y)
				return


func _kelp_fits(q: Vector2) -> bool:
	for a in 8:
		var e := q + Vector2(cos(a * TAU / 8.0), sin(a * TAU / 8.0)) * KELP_R
		if not w.terrain.is_water(e.x, e.y, 6.0):
			return false
	return w.terrain.is_water(q.x, q.y, 8.0) and w.terrain.isle_at(q.x, q.y, 1.6).is_empty()


## The nearest open water to a point, walked along the lane and out to its sides.
func _open_spot(p: Vector2, dir: Vector2) -> Vector2:
	for k in 12:
		for s in [1.0, -1.0]:
			var q: Vector2 = p + dir.orthogonal() * float(s) * k * 40.0
			if w.terrain.is_water(q.x, q.y, 8.0) and w.terrain.isle_at(q.x, q.y, 1.4).is_empty():
				return q
	return Vector2.INF


## Everyone: the towers on their rocks, dark or burning as the world remembers.
func build() -> void:
	if Net.dedicated:
		return
	var stone: StandardMaterial3D = w.mat(Color(0.32, 0.32, 0.3), 0.95)
	var white: StandardMaterial3D = w.mat(Color(0.86, 0.84, 0.78), 0.8)
	var red: StandardMaterial3D = w.mat(Color(0.55, 0.16, 0.12), 0.8)
	var iron: StandardMaterial3D = w.mat(Color(0.18, 0.18, 0.2), 0.6, 0.2, 0.25, 0.5)
	for i in houses.size():
		var h: Dictionary = houses[i]
		var n := Node3D.new()
		n.position = h.pos
		w.add_child(n)
		# The rock: wide and low, so a swimmer or a boat can come up onto it
		w._add(n, w.cyl(Vector3.ZERO, 9.0, 16.0, stone, true, 7.5, 12), Vector3(0, -8.0 + 0.6, 0))
		w._add(n, w.cyl(Vector3.ZERO, 13.0, 2.0, stone, true, 9.0, 12), Vector3(0, -1.0, 0))
		# The tower, banded, and the lamp room on top
		for k in 5:
			w._add(n, w.cyl(Vector3.ZERO, 1.9 - k * 0.12, 2.6, red if k % 2 == 1 else white, k == 0, 1.9 - (k + 1) * 0.12, 14), Vector3(0, 1.4 + k * 2.6 + 1.3, 0))
		w._add(n, w.cyl(Vector3.ZERO, 1.7, 0.3, iron, false, -1.0, 14), Vector3(0, 15.2, 0))
		var lamp: MeshInstance3D = w._add(n, w.cyl(Vector3.ZERO, 0.9, 1.6, w.mat(Color(0.5, 0.5, 0.45), 0.3), false, -1.0, 10), Vector3(0, 16.2, 0))
		w._add(n, w.cyl(Vector3.ZERO, 1.6, 1.0, iron, false, 0.1, 14), Vector3(0, 17.5, 0))
		var light := OmniLight3D.new()
		light.position = Vector3(0, 16.2, 0)
		light.light_color = Color(1.0, 0.85, 0.55)
		light.omni_range = 60.0
		light.light_energy = 0.0
		n.add_child(light)
		var lbl: Label3D = w._add(n, w.label3d(h.name, Vector3.ZERO, 0.6, Color(0.85, 0.82, 0.75), 0.0, true), Vector3(0, 4.5, 2.4))
		lbl.visibility_range_end = 45.0
		var a := Area3D.new()
		a.collision_layer = 16
		a.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 1.6
		sh.height = 3.0
		cs.shape = sh
		a.add_child(cs)
		a.position = Vector3(0, 2.2, 2.0)
		n.add_child(a)
		w.personal_interactable(a, "", func(): _touched(i))
		h.node = n
		h.lamp = lamp
		h.light = light
		h.area = a
		h.beam = null
		_show(i)
	if kelp != Vector3.INF:
		_build_kelp()


## A lit lighthouse burns, with a pale beam over it seen from far off; a dark one asks for oil.
func _show(i: int) -> void:
	var h: Dictionary = houses[i]
	if not h.has("node"):
		return
	var on := lit(i)
	h.light.light_energy = 3.0 if on else 0.0
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1.0, 0.9, 0.6) if on else Color(0.4, 0.4, 0.38)
	lm.emission_enabled = on
	lm.emission = Color(1.0, 0.8, 0.45)
	lm.emission_energy_multiplier = 3.0
	h.lamp.material_override = lm
	if on and h.beam == null:
		h.beam = Wasteland.landmark_column(Color(1.0, 0.88, 0.6, 0.22), 160.0, 0.8, true)
		h.node.add_child(h.beam)
		h.beam.position = Vector3(0, 18.0 + 80.0, 0)
	h.area.set_meta("prompt", "" if on or _holding.has(i) else "Light the lighthouse (%d lamp oil)" % OIL)


## Once the world's memory is in: each lamp as it was left.
func refresh() -> void:
	for i in houses.size():
		_show(i)


func _touched(i: int) -> void:
	if lit(i) or _holding.has(i):
		return
	if w.inv.count("oil") < OIL:
		w.hud.notify("The lamp is dry. It wants %d lamp oil." % OIL)
		return
	w.shared("_rq_house", [Net.me(), i])   # the oil is taken once the host says the wick took


## Host: the oil is poured; the sea comes for the light until it holds.
func start(by: int, i: int) -> void:
	if not Net.authority() or lit(i) or _holding.has(i) or i < 0 or i >= houses.size():
		return
	_holding[i] = HOLD_SECS
	w.shared("_w_house_hold", [i, by])
	var at: Vector3 = houses[i].pos
	for wave in 2:
		w.get_tree().create_timer(2.0 + wave * 16.0, false).timeout.connect(func():
			if not is_instance_valid(w) or not _holding.has(i):
				return
			# Up out of the water onto the rock, and eels in the water about it
			for k in WCrowd.scale_near(w, at, 3 + wave):
				var a := randf() * TAU
				var kind: String = ["drowned", "kelp_drowner", "kelp_drowner", "drowned"][randi() % 4]
				var e = w.spawn_at(kind, at + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 6.5) + Vector3(0, 1.6, 0))
				if e:
					e.set_meta("raid", true)
			var b := randf() * TAU
			var eel = w.spawn_at("weed_eel", at + Vector3(cos(b), 0, sin(b)) * 22.0 + Vector3(0, 0.3, 0))
			if eel:
				eel.set_meta("raid", true))


## Everyone: the oil is poured and the lamp smokes.
func holding(i: int, by: int) -> void:
	if by == Net.me():
		w.inv.take("oil", OIL)   # the host starts each lamp only once, so this comes once
	_holding[i] = HOLD_SECS
	_show(i)
	if w.player.global_position.distance_to(houses[i].pos) < 150.0:
		w.hud.alert_banner(houses[i].name, "The wick takes. Hold the rock until the lamp burns clear. Things are coming up out of the water.")


## Host, once a second: a lamp held long enough, with a pilgrim still on the rock, burns.
func host_tick() -> void:
	for i in _holding.keys():
		_holding[i] -= 1.0
		if _holding[i] > 0.0:
			continue
		var near: bool = w.targets().any(func(t): return t.global_position.distance_to(houses[i].pos) < 45.0)
		w.shared("_w_house", [i, near])
	_kelp_tick()


## Everyone: the lamp burns, or gutters out with no one left to keep it.
func done(i: int, ok: bool) -> void:
	_holding.erase(i)
	if ok:
		w.flags["house_%d" % i] = true
		w.sfx("choir", -2, houses[i].pos)
		w.reveal_place(Vector2(houses[i].pos.x, houses[i].pos.z), 140.0)
		var lane: String = houses[i].lane
		if lane_lit(lane):
			w.hud.alert_banner("A sea lane is lit", "The way to %s is lit across the water. The deep keeps off it." % lanes[lane][2])
			w.reveal_place(lanes[lane][1], 200.0)
		else:
			w.hud.notify("%s burns again. Light the other on its lane to make a safe way across." % houses[i].name)
		w.autosave_soon(1.0)
	else:
		w.hud.notify("No one kept the rock. %s gutters out; the oil is spent." % houses[i].name)
	_show(i)
	if w.ui:
		w.ui.map_dirty = true


func lane_lit(lane: String) -> bool:
	var any := false
	for i in houses.size():
		if houses[i].lane == lane:
			any = true
			if not lit(i):
				return false
	return any


## Whether a point lies on a lit sea lane, where the deep does not come.
func lane_safe(p: Vector3) -> bool:
	for lane in lanes:
		if not lane_lit(lane):
			continue
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), lanes[lane][0], lanes[lane][1])
		if q.distance_to(Vector2(p.x, p.z)) < LANE_SAFE:
			return true
	return false


func in_kelp(p: Vector3) -> bool:
	return kelp != Vector3.INF and Vector2(p.x, p.z).distance_to(Vector2(kelp.x, kelp.z)) < KELP_R


# ------------------------------------------------------------------ the Kelp Forest

func _build_kelp() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.18
	cm.height = 1.0
	cm.radial_segments = 5
	cm.rings = 1
	mm.mesh = cm
	var r := RandomNumberGenerator.new()
	r.seed = w.world_seed + 5151
	var n := 900
	mm.instance_count = n
	for k in n:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * KELP_R
		var hgt := r.randf_range(1.5, 5.0)
		var b := Basis().rotated(Vector3.RIGHT, r.randf_range(-0.25, 0.25)).rotated(Vector3.UP, r.randf() * TAU).scaled(Vector3(1, hgt + 6.0, 1))
		mm.set_instance_transform(k, Transform3D(b, Vector3(cos(a) * d, hgt * 0.5 - 3.0, sin(a) * d)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.18, 0.26, 0.14)
	m.roughness = 0.9
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 700.0
	w.add_child(mi)
	mi.global_position = kelp


## Host: those in the kelp draw the Drowners up after them, now and then.
func _kelp_tick() -> void:
	if kelp == Vector3.INF:
		return
	_kelp_t -= 1.0
	if _kelp_t > 0.0:
		return
	_kelp_t = 18.0
	if w.enemies.filter(func(e): return is_instance_valid(e) and e.is_alive() and e.has_meta("kelp")).size() >= 6:
		return
	for t in w.targets():
		if not in_kelp(t.global_position) or randf() > 0.5:
			continue
		for k in 2 + randi() % 2:
			var a := randf() * TAU
			var at: Vector3 = t.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(12.0, 20.0)
			at.y = WIsles.SEA_Y + 0.2
			var e = w.spawn_at("weed_eel", at)
			if e:
				e.set_meta("raid", true)
				e.set_meta("kelp", true)
		w.shared("_w_note", ["Something pulls at the kelp below you."])
		return


## Everyone, now and then: told once when they first come into the kelp.
func local_tick() -> void:
	if not _kelp_told and in_kelp(w.player.global_position):
		_kelp_told = true
		w.hud.title_card("", "The Kelp Forest")
		w.hud.notify("Kelp tall as trees, just under the water. Boats go slowly here, and things move under it.")
