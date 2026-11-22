class_name WKraken
extends RefCounted
## The Kraken-Bell. Out past the Sunk Fen the old chapel's bell still rings, under the water. Follow the
## sound and there is a whirlpool, and a drowned tower in the middle of it, and something very large
## wound about the tower. It pulls boats in. When it falls, the tower top can be climbed to, and what
## the chapel kept is there. It comes back after three days.

const PULL_R := 90.0     ## the whirlpool's reach
const WAKE_R := 45.0     ## how close a boat comes before it rises
const BACK := 3          ## days before it is wound about the tower again

var w
var spot := Vector3.INF
var root: Node3D
var _spin: Node3D
var _bell: AudioStreamPlayer3D
var _bell_t := 4.0
var _hurt_t := 0.0
var _t := 2.0
var next_day := 0        ## host: the day it may rise again
var beast = null         ## host: the thing, while it is up
var _hinted := false


func _init(world) -> void:
	w = world


## Where the whirlpool turns: out from the Sunk Fen, in open water.
func find_spot() -> Vector3:
	for il in w.terrain.isles:
		if il.key != "fen":
			continue
		var c: Vector2 = il.c
		var out := c.normalized()
		# Round the isle from its seaward side, a little way off its shore
		for k in 24:
			var a := (k / 2) * 0.26 * (1 if k % 2 == 0 else -1)
			for far in [140.0, 190.0, 240.0]:
				var q: Vector2 = c + out.rotated(a) * (float(il.r) + far)
				var p := Vector3(q.x, WIsles.SEA_Y, q.y)
				if w.terrain.is_water(q.x, q.y, 8.0) and w.sea.open_water(p, 100.0) >= 70.0:
					return p
	return Vector3.INF


## Every machine: the tower, the turning water and the bell.
func build() -> void:
	spot = find_spot()
	if spot == Vector3.INF or Net.dedicated:
		return
	root = Node3D.new()
	w.add_child(root)
	root.global_position = spot
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.3, 0.31, 0.29)
	stone.roughness = 0.95
	# The drowned tower, leaning, its top above the water
	var tower := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.6
	cm.bottom_radius = 3.2
	cm.height = 22.0
	tower.mesh = cm
	tower.material_override = stone
	tower.position = Vector3(0, -7.0, 0)
	tower.rotation = Vector3(0.12, 0, 0.08)
	root.add_child(tower)
	var cap := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.2
	cc.bottom_radius = 3.0
	cc.height = 3.0
	cap.mesh = cc
	cap.material_override = stone
	cap.position = Vector3(0.9, 5.4, -1.3)
	cap.rotation = tower.rotation
	root.add_child(cap)
	var top := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 2.6
	cy.height = 22.0
	cs.shape = cy
	cs.position = tower.position
	cs.rotation = tower.rotation
	top.add_child(cs)
	root.add_child(top)
	# The bell, green with the sea, hung in the open top
	var bell := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.35
	bm.bottom_radius = 0.7
	bm.height = 0.9
	bell.mesh = bm
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.3, 0.45, 0.38)
	bronze.metallic = 0.7
	bronze.roughness = 0.45
	bell.material_override = bronze
	bell.position = Vector3(0.5, 3.6, -0.8)
	root.add_child(bell)
	# The turning water: rings of dark water and foam, spun about the tower
	_spin = Node3D.new()
	root.add_child(_spin)
	for k in 4:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 6.0 + k * 9.0
		tm.outer_radius = 7.5 + k * 9.0
		tm.rings = 48
		ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.82, 0.86, 0.85, 0.35 - k * 0.06)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = m
		ring.scale = Vector3(1, 0.05, 1)
		ring.position.y = 0.25 - k * 0.15
		ring.rotation.y = k * 0.7
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spin.add_child(ring)
	var dark := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 34.0
	dm.bottom_radius = 4.0
	dm.height = 6.0
	dark.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.03, 0.05, 0.06, 0.75)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	dark.material_override = dmat
	dark.position.y = -2.9
	dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dark)
	_bell = AudioStreamPlayer3D.new()
	_bell.stream = load("res://assets/audio/bell.ogg")
	_bell.unit_size = 60.0
	_bell.max_distance = 900.0
	_bell.volume_db = -4.0
	_bell.pitch_scale = 0.62
	_bell.position.y = 3.6
	root.add_child(_bell)
	# A ledge at the top, and a way up from a boat alongside
	var ledge := StaticBody3D.new()
	var ls := CollisionShape3D.new()
	var lb := BoxShape3D.new()
	lb.size = Vector3(4.6, 0.4, 4.6)
	ls.shape = lb
	ledge.add_child(ls)
	root.add_child(ledge)
	ledge.global_position = top() - Vector3(0, 0.6, 0)
	var climb: Area3D = w.interact_area(spot + Vector3(4.2, 0.4, 0), 3.5, "Climb the tower", func():
		if w.player.vessel != null and is_instance_valid(w.player.vessel):
			w._leave_boat(w.player.vessel)
		w.player.place(top() + Vector3(0, 0.3, 0), w.player.yaw), 0.0, false)
	climb.set_meta("prompt", "Climb the tower")
	climb.reparent(root)
	var lbl: Label3D = w.label3d("The Kraken-Bell", spot + Vector3(0, 11.0, 0), 0.9, Color(0.7, 0.82, 0.85), 0.0, true)
	lbl.visibility_range_end = 220.0
	lbl.reparent(root)


## Where the chapel's things are kept, at the tower's top.
func top() -> Vector3:
	return spot + Vector3(0.6, 4.1, -0.9)


## Every machine, each frame: the water turns, the bell rings under it, and a boat is drawn in.
func local_tick(delta: float) -> void:
	if spot == Vector3.INF or w.player == null:
		return
	if _spin:
		_spin.rotation.y += delta * 0.6
	_bell_t -= delta
	if _bell_t <= 0.0 and _bell:
		_bell_t = randf_range(18.0, 30.0)
		_bell.play()
	var b = w.player.vessel
	if b == null or not is_instance_valid(b) or int(b.riders.get(Net.me(), -1)) != 0:
		return
	var to: Vector3 = spot - b.global_position
	to.y = 0.0
	var d := to.length()
	if d > PULL_R or d < 0.1:
		return
	if not _hinted:
		_hinted = true
		w.hud.notify("The water turns under you. It is pulling you in toward the tower.")
	var pull := lerpf(5.0, 1.2, d / PULL_R)
	b.global_position += (to / d) * pull * delta + to.normalized().cross(Vector3.UP) * pull * 0.6 * delta
	b.yaw += delta * 0.25 * (1.0 - d / PULL_R)
	if d < 9.0:
		_hurt_t -= delta
		if _hurt_t <= 0.0:
			_hurt_t = 1.5
			w.hurt_boat(b, 12.0)


## The host, once a second: a boat close enough wakes it.
func host_tick() -> void:
	if spot == Vector3.INF or not Net.authority():
		return
	if beast != null and (not is_instance_valid(beast) or not beast.is_alive()):
		beast = null
	if beast != null or w.day < next_day:
		return
	for t in w.targets():
		var p: Vector3 = t.global_position
		if Vector2(p.x, p.z).distance_to(Vector2(spot.x, spot.z)) < WAKE_R:
			var at := spot + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
			at.y = WIsles.SEA_Y + 0.3
			beast = w.spawn_at("bellwound", at)
			if beast:
				w.crowd_great(beast)
				beast.set_meta("raid", true)
				w.shared("_w_note", ["The bell rings once, under you. Something lets go of the tower."])
				w.sfx("horror_deep", 0, at, 0.6)
			return


## Everyone: it has fallen. The tower's top holds what the chapel kept.
func fallen(d: int) -> void:
	next_day = d + BACK
	if spot == Vector3.INF:
		return
	w._crate("kraken_%d" % d, top(), "vault", 0.0, false)
	if not Net.dedicated and w.player.global_position.distance_to(spot) < 160.0:
		w.inv.add("t_kraken", 1)
		w.inv.add("bell_ichor", 1)   # for Deep Oil, the key to the sixth fire
		w.inv.add("fit_kraken", 1)   # its own named fittings
		if w.inv.count("spirit_grave") < 1:
			w.inv.add("spirit_grave", 1)
		w.hud.title_card("The Bell-Wound", "It sinks, and lets the tower go")
		w.hud.notify("Something is caught in the bell at the top of the tower. A cold relic floats up beside you.")
