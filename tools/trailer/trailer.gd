extends Node
## TRAILER CAPTURE (a filming aid, not part of play).
## Started by main.gd when the game is run with `-- level=12 trailer=<shots.json>`, usually under
## Godot's Movie Maker (`--write-movie`). Walks a list of shots through the Ashen Waste: sets the hour,
## weather, lit beacons and forms for each, flies a camera along a path (or walks Brelm along one, gun
## in hand), and writes where each shot starts and ends in the movie (cuts.json in the user folder),
## so the cutting can throw away the frames spent loading between them.
## See tools/trailer/README.md for how to run it.

var w            ## the wasteland
var shots: Array = []
var cam: Camera3D
var cuts: Array = []
var _frame0 := 0
var fps := 30.0
var _hold_hp := false
var _clean_on := false
var _clean_t := 0.0
var _only := ""
var _eye_h := -1.0
var _shot := {}
var _hidden: Array = []


func _init(path: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("TRAILER cannot read %s" % path)
		return
	if data is Dictionary:
		shots = data.get("shots", [])
		if data.has("seed"):
			Game.new_world_seed = int(data.seed)
		if data.has("slot"):
			Game.world_slot = str(data.slot)
	else:
		shots = data
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			_only = a.substr(5)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frame0 = Engine.get_frames_drawn()
	fps = float(Engine.max_fps) if Engine.max_fps > 0 else 30.0
	var mf: int = ProjectSettings.get_setting("editor/movie_writer/fps", 60)
	if OS.has_feature("movie") or Engine.get_write_movie_path() != "":
		fps = float(mf)
	print("TRAILER ready shots=%d fps=%d movie=%s" % [shots.size(), int(fps), Engine.get_write_movie_path()])
	_run()


func _process(delta: float) -> void:
	if w == null or not is_instance_valid(w) or w.player == null:
		return
	if _hold_hp:
		w.player.health = w.player.max_health
		w.player.stamina = 100.0 if w.player.get("stamina") != null else 0.0
	if _clean_on:
		_clean_t -= delta
		if _clean_t <= 0.0:
			_clean_t = 0.25
			_clean(w)


func _run() -> void:
	var main = get_parent()
	while not (is_instance_valid(main.level) and main.level.get("player") and main.level.get("ready_world") != null):
		await get_tree().process_frame
	w = main.level
	while not w.ready_world:
		await get_tree().create_timer(1.0).timeout
	await get_tree().process_frame
	if Engine.get_write_movie_path() != "":
		fps = roundf(1.0 / get_process_delta_time())
	print("TRAILER world ready seed=%d frame=%d fps=%d" % [w.world_seed, _now(), int(fps)])
	w.combat_frozen = true
	_hold_hp = true
	if w.hud and w.hud.get("root"):
		w.hud.root.visible = false
	Game.quality = 1
	w.apply_quality()
	if w.sun:
		w.sun.shadow_enabled = true
	cam = Camera3D.new()
	cam.far = 1500.0
	w.add_child(cam)
	for s in shots:
		if _only != "" and not str(s.name) in _only.split(","):
			continue
		await _shoot(s)
	var f := FileAccess.open("user://trailer_cuts.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": fps, "cuts": cuts}, "\t"))
	f.close()
	print("TRAILER cuts saved to %s" % ProjectSettings.globalize_path("user://trailer_cuts.json"))
	print("TRAILER done frame=%d" % _now())
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _now() -> int:
	return Engine.get_frames_drawn() - _frame0


## Where a shot is set: a town, a beacon, a named ruin, the heart of a land, or plain x/z.
func _anchor(s: Dictionary) -> Vector2:
	var tgt := Vector2.ZERO
	var at := str(s.get("at", ""))
	if at.begins_with("town:"):
		tgt = WPlaces.spos(at.substr(5))
	elif at.begins_with("beacon:"):
		var bp: Vector3 = w.beacon_nodes[int(at.substr(7))].pos
		tgt = Vector2(bp.x, bp.z)
	elif at.begins_with("ruin:"):
		tgt = WPlaces.rpos(at.substr(5))
	elif at.begins_with("biome:"):
		var want: int = WTerrain.BIOMES.find(at.substr(6))
		var best := -1.0
		var rad := float(s.get("search", 900.0))
		var x := -rad
		while x <= rad:
			var z := -rad
			while z <= rad:
				var wt = w.terrain.weights(x, z)
				var sc: float = wt[want] - Vector2(x, z).length() * 0.00008
				if sc > best:
					best = sc
					tgt = Vector2(x, z)
				z += 48.0
			x += 48.0
	elif s.has("xz"):
		tgt = Vector2(s.xz[0], s.xz[1])
	var sh: Array = s.get("shift", [0, 0])
	return tgt + Vector2(float(sh[0]), float(sh[1]))


## A point given as [x, up, z] about the anchor, or {"ang": deg, "dist": m, "up": m}: up is metres
## above the ground under it (or above the sea, where the ground is under water).
func _pt(a: Vector2, p, sea := true) -> Vector3:
	var x := 0.0
	var z := 0.0
	var up := 0.0
	if p is Dictionary:
		var ang := deg_to_rad(float(p.get("ang", 0.0)))
		var d := float(p.get("dist", 0.0))
		x = sin(ang) * d
		z = cos(ang) * d
		up = float(p.get("up", 0.0))
	else:
		x = float(p[0])
		up = float(p[1])
		z = float(p[2])
	var gx := a.x + x
	var gz := a.y + z
	var gy: float = w.terrain.height_at(gx, gz)
	if sea:
		gy = maxf(gy, 0.0)
	return Vector3(gx, gy + up, gz)


## Catmull-Rom through the keys; t from 0 to 1 across them, evenly in key count.
static func _spline(pts: Array, t: float) -> Vector3:
	if pts.size() == 1:
		return pts[0]
	var segs := pts.size() - 1
	var f := clampf(t, 0.0, 1.0) * segs
	var i := mini(int(f), segs - 1)
	var u := f - i
	var p0: Vector3 = pts[maxi(i - 1, 0)]
	var p1: Vector3 = pts[i]
	var p2: Vector3 = pts[i + 1]
	var p3: Vector3 = pts[mini(i + 2, segs)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)


static func _ease(k: float, how: String) -> float:
	match how:
		"linear":
			return k
		"in":
			return k * k
		"out":
			return 1.0 - (1.0 - k) * (1.0 - k)
		_:
			return k * k * (3.0 - 2.0 * k)


func _set_hour(h: float) -> void:
	w.clock = fposmod(h, 24.0)
	w.night = w.clock < 5.5 or w.clock > 20.5
	w._apply_time(true)


func _shoot(s: Dictionary) -> void:
	var name := str(s.get("name", "shot"))
	_shot = s
	if s.get("columns", false):
		for c in _hidden:
			if is_instance_valid(c):
				c.layers = 1
		_hidden.clear()
	var a := _anchor(s)
	var dur := float(s.get("dur", 6.0))
	var fp := str(s.get("mode", "cine")) == "fp"
	var path: Array = []
	for p in s.get("path", [[0, 3, 30]]):
		path.append(_pt(a, p))
	var look: Array = []
	var lk = s.get("look", [0, 2, 0])
	if lk is Array and lk.size() > 0 and (lk[0] is Array or lk[0] is Dictionary):
		for p in lk:
			look.append(_pt(a, p))
	else:
		look.append(_pt(a, lk))
	print("TRAILER shot %s anchor=%s cam0=%s" % [name, a, path[0]])
	# Clear the board: no forms left from the last shot, the hour and sky set
	for e in w.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	w.enemies.clear()
	w.weather.set_kind(str(s.get("weather", "clear")), 99999.0, float(s.get("wind", 0.6)))
	w.weather.k = 1.0 if str(s.get("weather", "clear")) != "clear" else 0.0
	for i in w.beacon_nodes.size():
		var on: bool = i in s.get("lit", [])
		if on and not i in w.lit:
			w.lit.append(i)
		elif not on and i in w.lit:
			w.lit.erase(i)
		w._light_beacon(i, on)
	var clock0 := float(s.get("clock", 12.0))
	var rate := float(s.get("hours_per_sec", 0.0))
	_set_hour(clock0)
	# Brelm stands under the eye so the land about it is raised and peopled
	var pl = w.player
	pl.set_physics_process(false)
	var bait = s.get("bait", null)
	var feet: Vector3 = path[0] if fp else (_pt(a, bait) if bait != null else Vector3(path[0].x, w.terrain.height_at(path[0].x, path[0].z) + 0.1, path[0].z))
	pl.global_position = feet
	pl.velocity = Vector3.ZERO
	var wpn = pl.weapon
	if fp:
		cam.current = false
		pl.cam.make_current()
		pl.cam.far = 1500.0
		pl.cam.fov = float(s.get("fov", 75.0))
		wpn.enabled = true
		wpn.visible = true
		_arm(wpn, str(s.get("gun", "")))
	else:
		cam.make_current()
		cam.fov = float(s.get("fov", 55.0))
		wpn.enabled = false
		wpn.visible = false
	_place_cam(path, look, 0.0, fp, s)
	# Let the ground, the trees and the towns come in around the eye before the shot begins
	_clean_on = true
	var pre := float(s.get("preroll", 4.0))
	var t := 0.0
	while t < pre:
		await get_tree().process_frame
		t += _dt()
		_set_hour(clock0)
		_place_cam(path, look, 0.0, fp, s)
	# The forms, set where the shot wants them
	var forms: Array = []
	for f in s.get("forms", []):
		var fpnt := _pt(a, f.get("p", [0, 0, 0]), false)
		fpnt.y += 1.5
		var e = w.spawn_at(str(f.get("kind", "rusher")), fpnt)
		if e == null:
			continue
		e._buried = 0.0
		var face = f.get("face", "cam")
		var tgt: Vector3 = path[0] if str(face) == "cam" else _pt(a, face)
		e.rotation.y = atan2(fpnt.x - tgt.x, fpnt.z - tgt.z)
		if e.get("_bar_t") != null:
			e._bar_t = 0.0
		if f.get("still", false):
			e.set_physics_process(false)
		forms.append(e)
	w.combat_frozen = not s.get("live", false)
	if s.has("forms"):
		var settle := float(s.get("form_settle", 1.0))
		t = 0.0
		while t < settle:
			await get_tree().process_frame
			t += _dt()
			_set_hour(clock0)
			_place_cam(path, look, 0.0, fp, s)
	# Rolling
	var start := _now()
	var kindled := false
	t = 0.0
	while t < dur:
		var k := t / dur
		_set_hour(clock0 + rate * t)
		_place_cam(path, look, k, fp, s)
		if fp:
			_guns(wpn, s, t)
		var kd = s.get("kindle", null)
		if kd != null and not kindled and t >= float(kd.get("t", 1.0)):
			kindled = true
			_kindle(int(kd.get("beacon", 0)), float(kd.get("grow", 3.0)))
		await get_tree().process_frame
		t += _dt()
	var end := _now()
	cuts.append({"name": name, "start": start, "end": end, "dur": dur})
	print("TRAILER cut %s frames %d-%d" % [name, start, end])
	wpn.debug_aim = false
	w.combat_frozen = true
	for e in forms:
		if is_instance_valid(e):
			e.set_physics_process(true)


func _dt() -> float:
	return get_process_delta_time()


func _place_cam(path: Array, look: Array, k: float, fp: bool, s: Dictionary) -> void:
	var e := _ease(k, str(s.get("ease", "smooth")))
	var p := _spline(path, e)
	var l := _spline(look, e)
	var roll := deg_to_rad(float(s.get("roll", 0.0)))
	if fp:
		var pl = w.player
		# The path is the eye; Brelm's feet are below it
		if _eye_h < 0.0:
			_eye_h = pl.head.position.y
		var eye_h := _eye_h
		pl.global_position = p - Vector3(0, eye_h, 0)
		var to := l - p
		pl.yaw = atan2(-to.x, -to.z)
		pl.pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.4, 1.4)
		pl.rotation.y = pl.yaw
		pl.head.rotation.x = pl.pitch
		# A walking eye sways a little
		if s.get("walk", false):
			pl.head.position.y = eye_h + sin(k * float(s.get("dur", 6.0)) * 11.0) * 0.03
		pl.cam.rotation.z = roll
	else:
		cam.global_position = p
		if p.distance_to(l) > 0.01:
			cam.look_at(l, Vector3.UP)
		cam.rotate_object_local(Vector3.FORWARD, roll)
		if s.get("bait", null) == null:
			w.player.global_position = Vector3(p.x, w.terrain.height_at(p.x, p.z) + 0.1, p.z)


## Takes up the gun the shot asks for, full.
func _arm(wpn, g: String) -> void:
	if g != "" and ArmsDB.GUNS.has(g):
		if not g in wpn.guns:
			wpn.guns[0] = g
		if not wpn._st.has(g):
			wpn._st[g] = {"mag": Arms.mag_of(g), "reserve": Arms.mag_of(g) * 8}
		wpn._spec_cache.clear()
		wpn.cur = wpn.guns.find(g)
		wpn._show_model()
	wpn.refill()


## Fire and aim in the windows the shot gives: "fire": [[from, to], ...], "aim": [[from, to], ...].
func _guns(wpn, s: Dictionary, t: float) -> void:
	var aiming := false
	for win in s.get("aim", []):
		if t >= float(win[0]) and t < float(win[1]):
			aiming = true
	wpn.debug_aim = aiming
	for win in s.get("fire", []):
		if t >= float(win[0]) and t < float(win[1]):
			if wpn.shells <= 1:
				wpn.refill()
			wpn._try_fire()


## A beacon taking: a small flame, a bell, then the full fire, the beam and the choir.
func _kindle(i: int, grow: float) -> void:
	var b: Dictionary = w.beacon_nodes[i]
	b.flame.visible = true
	b.flame.scale = Vector3.ONE * 0.3
	b.light.light_energy = 1.0
	b.beam.visible = false
	w.sfx("bell", -2, b.pos)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(b.flame, "scale", Vector3.ONE, grow)
	tw.parallel().tween_property(b.light, "light_energy", 3.0, grow)
	tw.tween_callback(func():
		b.beam.visible = true
		w.sfx("choir", 0, b.pos))


## No floating names, prompts, markers or health bars in the picture.
func _clean(n: Node) -> void:
	for c in n.get_children():
		if c is Label3D:
			c.visible = false
		elif c is MeshInstance3D and c.layers != 0 and c.mesh is CylinderMesh and (((c.mesh as CylinderMesh).height >= 150.0 and (c.mesh as CylinderMesh).height < 250.0) or (not (c.mesh as CylinderMesh).cap_top and (c.mesh as CylinderMesh).radial_segments == 10)) and not _shot.get("columns", false):
			_hidden.append(c)
			c.layers = 0   # the map's guide columns (the game sets their visibility itself, so hide them from the camera instead)
		if c.get("_bar") is MeshInstance3D:
			c._bar.visible = false
		_clean(c)
