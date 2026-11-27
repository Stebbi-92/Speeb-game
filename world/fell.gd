class_name WFell
extends RefCounted
## Every standing tree of the woods, the isles and the dead lands can be cut down with a hatchet, as the
## deadwood is: hold to cut, chips fly, and the wood is taken. A tree gives as many blows as it is big
## (a sapling one or two, a great pine twelve), and on the last it falls and leaves a stump; after some
## days it stands again. Nothing is made for a tree until it is struck: the trees stay in their batches,
## and a tree is found by the trunk the crosshair is on. A felled tree is a hidden place in its batch, and
## all the stumps are drawn in one batch of their own.

const BLOWS_MIN := 2       ## a small tree (the smallest saplings give only one)
const BLOWS_MAX := 12      ## the greatest pine
const REGROW_MIN := 3      ## days before a felled sapling stands again (deadwood is back in two)
const REGROW_MAX := 6      ## and the greatest pine
const STUMP := ["scan", "tree_stump_01"]

var w   ## the waste
var stands := {}   ## key -> {"trees": [[batch, index, trunk shape, foot, height, girth, place in batch, dead], ...]}
var cut := {}      ## key -> {i: [blows left, day it stands again]}: only the trees struck
var _hidden := {}  ## key -> {i: true}: the felled, taken from their batches
var _stumps: MultiMeshInstance3D
var _stump_mesh: Array = []
var falls := 0     ## (for the tests)


func _init(waste) -> void:
	w = waste


# ------------------------------------------------------------------ the trees

## A batch of trees under one still body, each [batch, index in it, its trunk's shape, its foot (world),
## height, trunk girth (radius), its place in the batch]. Their trunks become something to cut.
func add_stand(tag: String, body: StaticBody3D, trees: Array, dead := false) -> void:
	if trees.is_empty() or body == null:
		return
	var mid := Vector3.ZERO
	for t in trees:
		mid += t[3]
	mid /= trees.size()
	var key := "%s%d,%d" % [tag, roundi(mid.x), roundi(mid.z)]
	while stands.has(key):
		key += "+"
	for i in trees.size():
		var cs: CollisionShape3D = trees[i][2]
		if cs:
			cs.set_meta("fell_i", i)
		trees[i].append(dead)
	stands[key] = {"trees": trees}
	body.set_meta("fell", key)
	var cb := func(): chop_aimed(body)
	w.personal_interactable(body, "Cut deadwood" if dead else "Cut the tree", cb, 1.6)


## How big a tree is, 0 to 1: mostly its height, a quarter its girth.
static func size_k(h: float, r: float) -> float:
	return clampf(0.75 * clampf((h - 2.0) / 16.0, 0.0, 1.0) + 0.25 * clampf((r - 0.15) / 0.55, 0.0, 1.0), 0.0, 1.0)


## The blows a tree of this height and girth takes to fell.
static func blows_for(h: float, r: float) -> int:
	if h < 2.5:
		return 1
	return clampi(roundi(lerpf(BLOWS_MIN, BLOWS_MAX, size_k(h, r))), 1, BLOWS_MAX)


static func regrow_days(h: float, r: float) -> int:
	return roundi(lerpf(REGROW_MIN, REGROW_MAX, size_k(h, r)))


func tree(key: String, i: int) -> Array:
	if not stands.has(key) or i < 0 or i >= stands[key].trees.size():
		return []
	return stands[key].trees[i]


func full(key: String, i: int) -> int:
	var t := tree(key, i)
	return blows_for(float(t[4]), float(t[5])) if not t.is_empty() else 0


func blows(key: String, i: int) -> int:
	if cut.has(key) and cut[key].has(i):
		return int(cut[key][i][0])
	return full(key, i)


## The tree the crosshair is on in this stand, by the trunk the ray struck (or the nearest foot).
func aimed(body: StaticBody3D) -> int:
	var key := str(body.get_meta("fell", ""))
	if not stands.has(key):
		return -1
	var ray: RayCast3D = w.player.ray if is_instance_valid(w.player) else null
	if ray and ray.is_colliding() and ray.get_collider() == body:
		var owner_id := body.shape_find_owner(ray.get_collider_shape())
		var cs = body.shape_owner_get_owner(owner_id) if owner_id >= 0 else null
		if cs is Node and (cs as Node).has_meta("fell_i"):
			return int(cs.get_meta("fell_i"))
	var p: Vector3 = w.player.global_position
	var best := -1
	var bd := 16.0
	var trees: Array = stands[key].trees
	for i in trees.size():
		var d := Vector2(p.x, p.z).distance_squared_to(Vector2(trees[i][3].x, trees[i][3].z))
		if d < bd and blows(key, i) > 0:
			bd = d
			best = i
	return best


func chop_aimed(body: StaticBody3D) -> void:
	chop(str(body.get_meta("fell", "")), aimed(body))


## One's own blow at a tree: the swing, then a beat later the blow lands, as at the deadwood.
func chop(key: String, i: int) -> void:
	var t := tree(key, i)
	if t.is_empty() or blows(key, i) <= 0:
		return
	if w.player.mount:
		w.hud.notify("Get down from your cat to gather.")
		return
	w.shared("_rq_chop_tree", [Net.me(), key, i])
	var last := blows(key, i) <= 1
	w.sfx("swing", -10, null, randf_range(0.95, 1.1))
	if w.player.cam:
		var cam: Camera3D = w.player.cam
		var tw: Tween = w.create_tween()
		tw.tween_property(cam, "rotation:x", cam.rotation.x - 0.035, 0.08).set_ease(Tween.EASE_OUT)
		tw.tween_property(cam, "rotation:x", cam.rotation.x, 0.16).set_ease(Tween.EASE_IN_OUT)
	w.get_tree().create_timer(0.1, false).timeout.connect(func():
		if not is_instance_valid(w):
			return
		w._gather_sound("tree", t[3], last)
		w.player.shake(0.24 if last else 0.13)
		_blow_fx(key, i, last))


## The host takes a blow: one share of wood (and what the land gives besides), the tree a blow nearer falling.
func host_chop(by: int, key: String, i: int) -> void:
	var t := tree(key, i)
	var left := blows(key, i)
	if t.is_empty() or left <= 0:
		return
	var rr := RandomNumberGenerator.new()
	rr.randomize()
	var out: Array = [["wood", rr.randi_range(3, 5)]]
	out.append_array(w._land_finds("tree", t[3], rr))
	w.shared("_w_tree_cut", [key, i, left - 1, int(w.day) + regrow_days(float(t[4]), float(t[5]))])
	Net.call_peer(by, "_tree_take", [key, i, out])


## What one's own blow took.
func take(key: String, i: int, out: Array) -> void:
	var t := tree(key, i)
	if t.is_empty():
		return
	w._take_gathered("tree", out)
	w._gather_float({"kind": "tree", "at": (t[3] as Vector3) + Vector3(0, 1.8, 0)}, out)
	w.award("gather")
	w.quests.on_event("gathered", {})


## A tree's blows, as the host says (everyone): on the last it falls; at full it stands again.
func set_blows(key: String, i: int, left: int, back: int, show := true) -> void:
	var t := tree(key, i)
	if t.is_empty():
		return
	var whole := full(key, i)
	if left >= whole:
		if cut.has(key):
			cut[key].erase(i)
			if cut[key].is_empty():
				cut.erase(key)
		_stand(key, i)
		return
	if not cut.has(key):
		cut[key] = {}
	cut[key][i] = [left, back]
	if left <= 0 and not (_hidden.has(key) and _hidden[key].has(i)):
		_fall(key, i, show)


## At dawn the trees whose days are past stand again (only the host says so).
func dawn() -> void:
	if not Net.authority():
		return
	for key in cut.keys():
		for i in cut[key].keys():
			if cut.has(key) and cut[key].has(i) and int(w.day) >= int(cut[key][i][1]):
				w.shared("_w_tree_cut", [key, int(i), full(key, int(i)), 0])


# ------------------------------------------------------------------ keeping

## Only the trees struck, by stand: [index, blows left, day back, ...].
func to_data() -> Dictionary:
	var out := {}
	for key in cut:
		var flat: Array = []
		for i in cut[key]:
			flat.append_array([int(i), int(cut[key][i][0]), int(cut[key][i][1])])
		out[key] = flat
	return out


func from_data(d) -> void:
	for key in cut.keys():
		for i in cut[key].keys():
			set_blows(key, int(i), full(key, int(i)), 0, false)
	cut.clear()
	if not d is Dictionary:
		return
	for key in d:
		var flat = d[key]
		if not flat is Array or not stands.has(str(key)):
			continue
		for k in range(0, flat.size() - 2, 3):
			set_blows(str(key), int(flat[k]), int(flat[k + 1]), int(flat[k + 2]), false)


# ------------------------------------------------------------------ the look of it

## A blow: the tree shivers about its foot and chips fly at the one who struck.
func _blow_fx(key: String, i: int, last: bool) -> void:
	if Net.dedicated or not is_instance_valid(w.player):
		return
	var t := tree(key, i)
	var foot: Vector3 = t[3]
	var to_me: Vector3 = w.player.global_position - foot
	to_me.y = 0.0
	to_me = to_me.normalized() if to_me.length() > 0.1 else Vector3.FORWARD
	w._gather_chips("tree", foot + Vector3(0, 0.9, 0) + to_me * (float(t[5]) + 0.15), to_me, last)
	if _hidden.has(key) and _hidden[key].has(i):
		return
	var mm: MultiMesh = (t[0] as MultiMeshInstance3D).multimesh
	var idx := int(t[1])
	var t0: Transform3D = t[6]
	var axis := Vector3.UP.cross(to_me).normalized()
	var lean := 0.012 if float(t[4]) > 8.0 else 0.03
	var tw: Tween = w.create_tween()
	tw.tween_method(func(a: float):
		if not (_hidden.has(key) and _hidden[key].has(i)):
			mm.set_instance_transform(idx, Transform3D(Basis(axis, sin(a * TAU) * lean * (1.0 - a)), Vector3.ZERO) * t0), 0.0, 1.0, 0.35)
	tw.tween_callback(func():
		if not (_hidden.has(key) and _hidden[key].has(i)):
			mm.set_instance_transform(idx, t0))


## The last blow: the tree is taken from its batch, a copy of it topples away from the one who struck
## and sinks into the ground, and its stump is left.
func _fall(key: String, i: int, show: bool) -> void:
	var t := tree(key, i)
	var mmi: MultiMeshInstance3D = t[0]
	var mm := mmi.multimesh
	var idx := int(t[1])
	if not _hidden.has(key):
		_hidden[key] = {}
	var t0: Transform3D = t[6]
	_hidden[key][i] = true
	var gt := mmi.global_transform * t0
	mm.set_instance_transform(idx, Transform3D(Basis.from_scale(Vector3.ZERO), t0.origin))
	var cs: CollisionShape3D = t[2]
	if cs:
		cs.set_deferred("disabled", true)
	_redraw_stumps()
	if not show or Net.dedicated or not is_instance_valid(w.player) or not mmi.is_inside_tree() \
			or w.player.global_position.distance_to(t[3]) > 120.0:
		return
	falls += 1
	var foot: Vector3 = t[3]
	var log := MeshInstance3D.new()
	log.mesh = mm.mesh
	w.add_child(log)
	log.global_transform = gt
	var away: Vector3 = foot - w.player.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	var axis := Vector3.UP.cross(away).normalized()
	var h := float(t[4])
	var tw := log.create_tween()
	tw.tween_method(func(a: float):
		if is_instance_valid(log):
			log.global_transform = Transform3D(Basis(axis, a * a * 1.5), foot) * Transform3D(Basis.IDENTITY, -foot) * gt, 0.0, 1.0, 0.6 + 0.08 * h)
	tw.tween_callback(func():
		w.sfx("fall_heavy", -4 + minf(h, 12.0) * 0.25, foot + away * h * 0.5, 0.95 - minf(h, 18.0) * 0.012)
		if is_instance_valid(w.player) and w.player.global_position.distance_to(foot) < 30.0:
			w.player.shake(0.12 + minf(h, 18.0) * 0.012)
		w._gather_chips("tree", foot + away * h * 0.45 + Vector3(0, 0.4, 0), -away, true))
	tw.tween_interval(1.4)
	tw.tween_property(log, "position", log.position - Vector3(0, 0.6 + float(t[5]) * 2.0, 0), 1.6).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(log, "scale", log.scale * Vector3(0.9, 0.9, 0.9), 1.6)
	tw.tween_callback(log.queue_free)


## A felled tree stands again: back in its batch, solid, its stump gone.
func _stand(key: String, i: int) -> void:
	if not (_hidden.has(key) and _hidden[key].has(i)):
		return
	var t := tree(key, i)
	(t[0] as MultiMeshInstance3D).multimesh.set_instance_transform(int(t[1]), t[6])
	_hidden[key].erase(i)
	if _hidden[key].is_empty():
		_hidden.erase(key)
	var cs: CollisionShape3D = t[2]
	if cs:
		cs.set_deferred("disabled", false)
	_redraw_stumps()


## All the stumps of all the felled trees, one batch: as wide as their trees' trunks.
func _redraw_stumps() -> void:
	if Net.dedicated:
		return
	if _stump_mesh.is_empty():
		_stump_mesh = WDress._mesh_of(STUMP[0], STUMP[1])
		if _stump_mesh.is_empty():
			return
	if _stumps == null or not is_instance_valid(_stumps):
		_stumps = MultiMeshInstance3D.new()
		_stumps.name = "Stumps"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _stump_mesh[0]
		_stumps.multimesh = mm
		_stumps.custom_aabb = AABB(Vector3(-20000, -500, -20000), Vector3(40000, 1500, 40000))
		w.add_child(_stumps)
	var bb: AABB = (_stump_mesh[0] as Mesh).get_aabb()
	var tr0: Transform3D = _stump_mesh[1]
	var wide := maxf(maxf(bb.size.x, bb.size.z) * tr0.basis.get_scale().x, 0.05)
	var at: Array = []
	for key in _hidden:
		for i in _hidden[key]:
			var t := tree(key, i)
			var s := clampf(float(t[5]) * 2.6 / wide, 0.3, 3.0)
			var yaw := float(hash(key) % 628 + int(i) * 37) * 0.01
			at.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), (t[3] as Vector3) - Vector3(0, 0.05, 0)) * tr0)
	var mm := _stumps.multimesh
	mm.instance_count = at.size()
	for k in at.size():
		mm.set_instance_transform(k, at[k])
	_stumps.visible = not at.is_empty()


func felled(key: String, i: int) -> bool:
	return _hidden.has(key) and _hidden[key].has(i)


func stumps() -> int:
	return _stumps.multimesh.instance_count if _stumps and is_instance_valid(_stumps) else 0


# ------------------------------------------------------------------ testing aids

## The trees by size: [height, girth, blows] for each, and the sum of the blows.
func census() -> Dictionary:
	var by := {}
	var total := 0
	var n := 0
	for key in stands:
		for t in stands[key].trees:
			var b := blows_for(float(t[4]), float(t[5]))
			var kind := "dead" if t[7] else "living"
			if not by.has(kind):
				by[kind] = {}
			by[kind][b] = int(by[kind].get(b, 0)) + 1
			total += b
			n += 1
	return {"by": by, "blows": total, "trees": n}


## The biggest (or smallest) tree of the living woods, or of the dead: [key, index].
func pick(dead: bool, biggest := true) -> Array:
	var best: Array = []
	var bh := -INF if biggest else INF
	for key in stands:
		var trees: Array = stands[key].trees
		for i in trees.size():
			var t: Array = trees[i]
			if bool(t[7]) != dead or blows(key, i) < full(key, i) or t[2] == null:
				continue
			var h := float(t[4]) + float(t[5]) * 4.0
			if (biggest and h > bh) or (not biggest and h < bh):
				bh = h
				best = [key, i]
	return best


## Felling a great pine, as one alone and as the fellowship sees it: its blows by its size, the wood,
## the fall and the stump, a joiner's world and a reloaded save, and its standing again.
func debug_test() -> void:
	while not w.ready_world:
		await w.get_tree().create_timer(1.0).timeout
	w.clock = 10.0
	var cen := census()
	print("FELL census trees=%d blows=%d by=%s" % [cen.trees, cen.blows, cen.by])
	var big := pick(false)
	var key: String = big[0]
	var i: int = big[1]
	var t := tree(key, i)
	var whole := full(key, i)
	var small := pick(false, false)
	var dead := pick(true)
	print("FELL sizes big=h%.1f/r%.2f:%d sapling=h%.1f/r%.2f:%d dead=h%.1f/r%.2f:%d" % [t[4], t[5], whole,
		tree(small[0], small[1])[4], tree(small[0], small[1])[5], full(small[0], small[1]),
		tree(dead[0], dead[1])[4], tree(dead[0], dead[1])[5], full(dead[0], dead[1])])
	# Stand by its trunk and look at it: the crosshair finds this tree in its stand
	var foot: Vector3 = t[3]
	var body: StaticBody3D = (t[2] as CollisionShape3D).get_parent()
	var best_at := Vector3.INF
	for k in 12:
		var a := TAU * k / 12.0
		var at := foot + Vector3(cos(a), 0, sin(a)) * (float(t[5]) + 1.7)
		at.y = w.terrain.height_at(at.x, at.z) + 0.2
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.5, 0), foot + Vector3(0, at.y - foot.y + 1.5, 0), 1)
		var hit: Dictionary = w.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit.collider == body:
			best_at = at
			break
	if best_at == Vector3.INF:
		best_at = foot + Vector3(float(t[5]) + 1.7, 0.2, 0)
	w.player.place(best_at, 0.0)
	w.player.face(foot + Vector3(0, best_at.y - foot.y + 1.4, 0))
	for k in 6:
		await w.get_tree().physics_frame
	await w.get_tree().process_frame
	var aim_ok: bool = w.player.target == body and aimed(body) == i
	var prompt := str(body.get_meta("prompt", ""))
	# Cut it down with a hatchet in the pack
	w._debug_room(4)
	if w.inv.count("hatchet") <= 0:
		w.inv.add("hatchet", 1)
	var wood0: int = w.inv.count("wood")
	var heart0: int = w.inv.count("heartwood")
	var mm0: int = w.find_children("*", "MultiMeshInstance3D", true, false).size()
	var chops := 0
	while blows(key, i) > 0 and chops < 40:
		chop(key, i)
		chops += 1
		await w.get_tree().create_timer(0.15).timeout
	await w.get_tree().create_timer(0.3).timeout
	var wood: int = w.inv.count("wood") - wood0
	var gm: float = w.skills.gather_mult() * WRules.yield_mult() * float(WArms.worn(w.arms).gather)
	var wood_ok := wood >= int(chops * 6 * minf(gm, 1.0)) and wood <= int(ceil(chops * 10 * maxf(gm, 1.0)))
	var mm: MultiMesh = (t[0] as MultiMeshInstance3D).multimesh
	var gone := felled(key, i)
	await w.get_tree().physics_frame
	var solid := not (t[2] as CollisionShape3D).disabled
	var mm1: int = w.find_children("*", "MultiMeshInstance3D", true, false).size()
	await w.get_tree().create_timer(6.0).timeout
	var log_left := 0
	for c in w.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh == mm.mesh:
			log_left += 1
	print("FELL big land=%s blows=%d aimed=%s prompt='%s' chops=%d wood=%d heartwood=%d ok=%s heard=%s gone=%s solid=%s fell=%d stumps=%d batches=+%d log_left=%d" % [w.land_at(foot), whole,
		aim_ok, prompt, chops, wood, w.inv.count("heartwood") - heart0, wood_ok, ",".join(w.gather_heard), gone, solid, falls, stumps(), mm1 - mm0, log_left])
	# The fellowship: the blows went by the shared path, a joiner's world arrives with it cut, and a
	# joiner's request is let through (it names who asks); the gift back is the host's alone
	var lvl_ok: bool = Net.CALL_PREFIXES.any(func(p): return "_rq_chop_tree".begins_with(p)) and Net.CALL_PREFIXES.any(func(p): return "_w_tree_cut".begins_with(p)) \
		and not Net.CALL_PREFIXES.any(func(p): return "_tree_take".begins_with(p)) and Net._takes_by(w, "_rq_chop_tree")
	var snap = str_to_var(var_to_str(w.world_data()))
	from_data({})
	var stood := not felled(key, i) and stumps() == 0 and blows(key, i) == whole
	from_data(snap.get("fell", {}))
	var peer := lvl_ok and stood and blows(key, i) == 0 and felled(key, i) and stumps() == 1
	# Saved and loaded
	w.save_all(false)
	var d = Game.read_var_safe(w.world_path(w.slot))
	from_data({})
	from_data(d.get("fell", {}) if d is Dictionary else {})
	var saved: bool = d is Dictionary and d.has("fell") and blows(key, i) == 0 and stumps() == 1
	var days: int = int(cut[key][i][1]) - int(w.day)
	# Standing again: not at the next dawn, but once its days are past
	dawn()
	var early: bool = blows(key, i) == 0
	var day0: int = w.day
	w.day = int(cut[key][i][1])
	dawn()
	await w.get_tree().physics_frame
	await w.get_tree().physics_frame
	var regrown: bool = blows(key, i) == whole and not felled(key, i) \
		and not (t[2] as CollisionShape3D).disabled and stumps() == 0
	w.day = day0
	# A dead tree of the waste, the same way
	var dk: String = dead[0]
	var di: int = dead[1]
	var dw0: int = w.inv.count("wood")
	var dchops := 0
	while blows(dk, di) > 0 and dchops < 20:
		w.player.place(tree(dk, di)[3] + Vector3(1.5, 0.3, 0), 0.0)
		chop(dk, di)
		dchops += 1
		await w.get_tree().create_timer(0.15).timeout
	await w.get_tree().create_timer(0.3).timeout
	print("FELL peer=%s saved=%s days=%d early=%s regrown=%s dead_chops=%d dead_wood=%d dead_stumps=%d" % [peer, saved, days, early, regrown,
		dchops, w.inv.count("wood") - dw0, stumps()])
	w.get_tree().quit()


## A great pine before and after it is felled, seen from a little way off (rendered runs only).
func debug_shot(dir: String) -> void:
	while not w.ready_world:
		await w.get_tree().create_timer(1.0).timeout
	w.clock = 11.0
	var big := pick(false)
	var key: String = big[0]
	var i: int = big[1]
	var t := tree(key, i)
	var foot: Vector3 = t[3]
	var body: StaticBody3D = (t[2] as CollisionShape3D).get_parent()
	var at := foot + Vector3(9, 0, 0)
	for k in 16:
		var a := TAU * k / 16.0
		var p := foot + Vector3(cos(a), 0, sin(a)) * 9.0
		p.y = w.terrain.height_at(p.x, p.z) + 0.2
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.6, 0), foot + Vector3(0, 2.0, 0), 1)
		var hit: Dictionary = w.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit.collider == body and body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) == t[2]:
			at = p
			break
	w.player.place(at, 0.0)
	w.player.face(foot + Vector3(0, at.y - foot.y + 4.5, 0))
	for k in 40:
		await w.get_tree().process_frame
	await w.get_tree().create_timer(2.0).timeout
	w.get_viewport().get_texture().get_image().save_png(dir + "/pine_before.png")
	var n := 0
	while blows(key, i) > 0 and n < 40:
		chop(key, i)
		n += 1
		await w.get_tree().create_timer(0.2).timeout
	await w.get_tree().create_timer(0.7).timeout
	w.get_viewport().get_texture().get_image().save_png(dir + "/pine_falling.png")
	await w.get_tree().create_timer(4.5).timeout
	w.get_viewport().get_texture().get_image().save_png(dir + "/pine_after.png")
	print("FELLSHOT at=%s h=%.1f blows=%d stumps=%d" % [foot, t[4], n, stumps()])
	w.get_tree().quit()
