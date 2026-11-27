extends Node
## Testing aid: steps one's own arms (FPHands) through every gun and blade and every motion (idle, walk, run,
## aim, fire, reload from empty, inspect, switch, a quick blow, a grenade, the dressing; for a blade: idle,
## walk, guard, light and heavy swings, sheathing) and measures the arm skeleton every frame:
##   len    the worst change of any bone's length from its rest, in % (a stretched or squashed bone)
##   miss   how far the palm stops short of where the pose wants it, cm (a target out of reach)
##   elbow  the elbow's inner angle, least and most (180 straight; under ~35 folded past what an arm can)
##   up     how far the elbow points above level, degrees (a raised "chicken wing"); flip: the elbow's
##          own direction jumping between frames, degrees per 1/30 s
##   flex   the wrist's bend toward the palm (+) or the back of the hand (-), side the bend toward the thumb
##          (+) or the little finger (-), and pro the forearm's turn from thumb-up (+ palm down), degrees
##   gap    how far the nearest skin of the hand is from the gun's surface, cm (over 1 the hand floats)
##   pen    how deep the hand's skin goes inside the gun, cm; fing how deep one finger goes into another
## Only hands in sight are judged. Prints one HANDCHECK line per item, motion and hand, and a HANDFIT
## summary of the failures.
## Run by tools/probe_hands.tscn (alone, with a stand-in world) or by the level's debug_handfit.

const LIMITS := {"len": 1.0, "miss": 1.0, "elbow_lo": 35.0, "up": 35.0, "flip": 40.0, "flex": 70.0, "side": 30.0,
	"pro": 95.0, "gap": 1.0, "pen": 0.6, "fing": 0.35}
const FAR := ["carbine", "hand_cannon"]
const STRAIGHT := 165.0   ## an elbow this open is all but straight: which way it points is not seen
const REACH := 0.015   ## how far from the skin the gun's surface is looked for (a gap beyond reads as this)

var w: Arms
var hands: FPHands
var label := ""
var item := ""
var active := false
var rows := {}           ## "item|motion|side" -> worst numbers
var _parts := {}         ## held model's instance id -> [parts]
var _skin := {}          ## "R"/"L" -> [[bone, local point]] for the hand's skin
var _fcaps := {}         ## "R"/"L" -> {finger: [[b0, b1, radius]]}
var _prev_elbow := {}
var _dt := 1.0 / 30.0
var _rest_len := {}
var _seg_done := false
var only_seen := true
var on_frame := Callable()   ## called each measured frame with (this, seconds into the motion)
var _t := 0.0
var verbose := false
var trace := OS.get_environment("TRACE")
var _nframe := 0


func run(arms: Arms, gun_list: Array = [], motions: Array = []) -> Dictionary:
	w = arms
	hands = arms.hands
	process_priority = 50   # after the arms are posed
	while hands == null or hands._sk == null or hands._side.is_empty():
		await get_tree().process_frame
		hands = arms.hands
	hands.debug_pose = "check"
	hands.explain = verbose
	_learn_skin()
	Game.plevel = ArmsDB.MAX_LEVEL
	var gl: Array = gun_list
	if gl.is_empty():
		for g in ArmsDB.GUNS:
			if not g in FAR:
				gl.append(g)
	if OS.get_environment("LINE") != "":
		for g in gl:
			await _equip(g)
			var parts := _held_parts()
			var gr: Dictionary = Arms.GRIP.get(ArmsDB.look(g), Arms.GRIP[""])
			var mt := w._model.global_transform
			var line := []
			for i in 25:
				var x := -0.06 + i * 0.005
				var p := mt * ((gr.R as Vector3) + Vector3(x, 0, 0))
				line.append("%.3f:%.2f" % [x, _signed(parts, p, 0.03) * 100.0])
			print("LINE %s x %s" % [g, " ".join(line)])
		return {}
	for g in gl:
		if ArmsDB.GUNS.has(g):
			await _gun(g, motions)
		elif ArmsDB.MELEE.has(g):
			await _blade(g, motions)
	return _summary()


# ------------------------------------------------------------------ the motions

func _frames(secs: float, f := Callable()) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		if f.is_valid():
			f.call()
		t += get_process_delta_time()


func _equip(g: String) -> void:
	active = false
	w._reloading = false
	w._swing = 0.0
	w.debug_aim = false
	if w.blade_out:
		w._sheathe()
	Game.loadout.primary = g if ArmsDB.GUNS[g].slot == "primary" else "shotgun"
	Game.loadout.secondary = g if ArmsDB.GUNS[g].slot == "secondary" else "pistol"
	Game.loadout.mounts = {}
	w.equip_loadout()
	if w.gun() != g:
		w._switch = 0.0
		w.swap()
	await _frames(0.6)
	w.refill()


func _want(motions: Array, m: String) -> bool:
	return motions.is_empty() or m in motions


func _go(m: String) -> void:
	label = m
	active = true
	_t = 0.0
	if verbose:
		print("HANDCHECK go %s %s at %d ms" % [item, m, Time.get_ticks_msec()])


func _gun(g: String, motions: Array) -> void:
	item = g
	await _equip(g)
	var s := w.spec()
	if _want(motions, "idle"):
		_go("idle")
		await _frames(0.8)
	if _want(motions, "walk"):
		_go("walk")
		await _frames(1.0, func(): w.player.cur_speed = 3.0)
	if _want(motions, "run"):
		_go("run")
		await _frames(1.0, func(): w.player.cur_speed = 6.0)
	w.player.cur_speed = 0.0
	if _want(motions, "aim"):
		_go("aim")
		w.debug_aim = true
		await _frames(1.0)
		w.debug_aim = false
		await _frames(0.5)
	if _want(motions, "fire"):
		_go("fire")
		await _frames(1.2, func(): _shot(s))
		await _frames(0.6)
	if _want(motions, "aimfire"):
		_go("aimfire")
		w.debug_aim = true
		await _frames(0.5)
		await _frames(1.0, func(): _shot(s))
		w.debug_aim = false
		await _frames(0.5)
	if _want(motions, "reload"):
		active = false
		await _frames(0.3)
		_go("reload")
		w.shells = 0
		w._st[w.gun()].reserve = 400
		w._start_reload()
		var t := 0.0
		while w._reloading and t < 10.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		await _frames(0.4)
	if _want(motions, "inspect"):
		_go("inspect")
		w.inspect()
		await _frames(Arms.INSPECT_LEN + 0.3)
	if _want(motions, "switch"):
		_go("switch")
		w._switch = 0.0
		w.swap()
		await _frames(0.5)
		w.swap()
		await _frames(0.6)
	if _want(motions, "blow"):
		_go("blow")
		w.player.stamina = w.player.stamina_max
		w._melee_cool = 0.0
		w.strike(false)
		await _frames(0.6)
	if _want(motions, "throw"):
		_go("throw")
		w.grenades = 2
		w.throw_grenade()
		await _frames(0.6)
	if _want(motions, "gadget"):
		_go("gadget")
		w.gadget = "bandages"
		w.charges = 2
		w.player.health = 50.0
		w.use_gadget()
		await _frames(0.6)
	active = false


## A shot as the gun's own firing would make it, for the hands: the kick, the pump or bolt worked, the
## round gone; nothing flies.
func _shot(s: Dictionary) -> void:
	if s.mode == "spin":
		w._spin = 1.0
	if w._cool > 0.0 or w._reloading:
		return
	if w.shells <= 0:
		w.shells = w.capacity()
	w.shells -= 1
	w._quiet = 0.0
	w._cool = float(s.rate)
	w._kick = minf(1.0, w._kick + float(s.kick) * (0.35 if s.mode in ["auto", "spin"] else 1.0))


func _blade(m: String, motions: Array) -> void:
	item = m
	await _equip("shotgun")
	w.melee = m
	w.draw_blade()
	await _frames(0.4)
	if _want(motions, "idle"):
		_go("idle")
		await _frames(0.6)
	if _want(motions, "walk"):
		_go("walk")
		await _frames(0.8, func(): w.player.cur_speed = 3.0)
	w.player.cur_speed = 0.0
	if _want(motions, "guard"):
		_go("guard")
		await _frames(0.8, func(): w.guarding = true)
		await _frames(0.3)
	for heavy in [false, true]:
		if _want(motions, "heavy" if heavy else "swing"):
			_go("heavy" if heavy else "swing")
			w.player.stamina = w.player.stamina_max
			w._melee_cool = 0.0
			w.strike(heavy)
			await _frames(0.8)
	if _want(motions, "sheathe"):
		_go("sheathe")
		w._sheathe()
		await _frames(0.4)
	active = false


# ------------------------------------------------------------------ measuring

func _process(delta: float) -> void:
	if active:
		_dt = delta
		sample()
		_t += delta
		if on_frame.is_valid():
			on_frame.call(self, _t)


func _learn_skin() -> void:
	var sk: Skeleton3D = hands._sk
	for i in sk.get_bone_count():
		var p := sk.get_bone_parent(i)
		if p >= 0:
			_rest_len[i] = sk.get_bone_global_rest(i).origin.distance_to(sk.get_bone_global_rest(p).origin)
	var mi: MeshInstance3D = null
	for c in hands._model.find_children("*", "MeshInstance3D", true, false):
		if (c as MeshInstance3D).skin != null:
			mi = c
	if mi == null:
		return
	var skin: Skin = mi.skin
	var bind_bone := []
	for i in skin.get_bind_count():
		var b := skin.get_bind_bone(i)
		if b < 0:
			b = sk.find_bone(skin.get_bind_name(i))
		bind_bone.append(b)
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones = arr[Mesh.ARRAY_BONES]
	var wts = arr[Mesh.ARRAY_WEIGHTS]
	var per: int = wts.size() / maxi(verts.size(), 1)
	var hand_bones := {}
	for s in ["R", "L"]:
		_skin[s] = []
		var d: Dictionary = hands._side[s]
		hand_bones[d.wrist] = s
		for fb in d.fingers:
			hand_bones[fb[0]] = s
		for fn in d.chains:
			hand_bones[d.chains[fn][3]] = s
	var by_bone := {}
	for v in verts.size():
		var best := 0
		for j in per:
			if wts[v * per + j] > wts[v * per + best]:
				best = j
		var bi: int = bones[v * per + best]
		var b: int = bind_bone[bi]
		if not hand_bones.has(b) or wts[v * per + best] < 0.5:
			continue
		var u: Vector3 = skin.get_bind_pose(bi) * verts[v]
		if not by_bone.has(b):
			by_bone[b] = []
		by_bone[b].append(u)
		if v % 8 == 0:
			_skin[hand_bones[b]].append([b, u])
	if verbose:
		print("HANDCHECK skin points R=%d L=%d" % [(_skin.R as Array).size(), (_skin.L as Array).size()])
	# Each finger bone as a capsule, its radius the skin's middling distance from the bone's line
	for s in ["R", "L"]:
		var d: Dictionary = hands._side[s]
		_fcaps[s] = {}
		for fn in d.chains:
			var ch: Array = d.chains[fn]
			var caps := []
			for k in 3:
				var b0: int = ch[k]
				var b1: int = ch[k + 1]
				var r := 0.8
				if by_bone.has(b0):
					var len: float = sk.get_bone_rest(b1).origin.length()
					var ds := []
					for u in by_bone[b0]:
						# in the bone's rest space: the bone runs from its origin toward the child's rest origin
						var a: Vector3 = Vector3.ZERO
						var e: Vector3 = sk.get_bone_rest(b1).origin
						ds.append(_seg_dist(u, a, e))
					ds.sort()
					if not ds.is_empty():
						r = ds[ds.size() / 2]
					if len <= 0.0:
						r = 0.8
				caps.append([b0, b1, r])
			_fcaps[s][fn] = caps


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _seg_seg(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	# The closest points of two segments (Ericson, Real-Time Collision Detection 5.1.9)
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-9 and e <= 1e-9:
		return r.length()
	if a <= 1e-9:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 1e-9:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-9 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return (p1 + d1 * s).distance_to(p2 + d2 * t)


## The finger pairs that can touch: side by side, and the thumb against each
const PAIRS := [["point", "middle"], ["middle", "ring"], ["ring", "pink"], ["thumb", "point"], ["thumb", "middle"],
	["thumb", "ring"], ["thumb", "pink"]]


func _row(side: String) -> Dictionary:
	var key := "%s|%s|%s" % [item, label, side]
	if not rows.has(key):
		rows[key] = {"n": 0, "seen": 0, "len": 0.0, "miss": 0.0, "elbow_lo": 180.0, "elbow_hi": 0.0, "up": -90.0, "flip": 0.0,
			"flex": 0.0, "side": 0.0, "pro": 0.0, "pro_lo": 999.0, "pro_hi": -999.0, "gap": 0.0, "gap_n": 0, "pen": 0.0, "pen_at": "",
			"fing": 0.0, "fing_at": "", "miss_k": -1.0, "gap_k": -1.0, "pen_k": -1.0}
	return rows[key]


func sample() -> void:
	if not hands.visible or hands.last_pose.is_empty():
		return
	var sk: Skeleton3D = hands._sk
	var cam: Camera3D = w.player.cam
	var ct := cam.global_transform
	var ci := ct.affine_inverse()
	var skg := sk.global_transform
	var sc := hands.SCALE
	var held := _held_parts()
	var k := w._hand_k if w._reloading else -1.0
	_nframe += 1
	for s in ["R", "L"]:
		if not hands.last_pose.has(s):
			continue
		var d: Dictionary = hands._side[s]
		var p: Dictionary = hands.last_pose[s]
		var r := _row(s)
		var gp := func(b: int) -> Transform3D: return skg * sk.get_bone_global_pose(b)
		var S: Vector3 = (gp.call(d.arm) as Transform3D).origin
		var E: Vector3 = (gp.call(d.elbow) as Transform3D).origin
		var Wt: Transform3D = gp.call(d.wrist)
		var W := Wt.origin
		var palm: Vector3 = skg * (sk.get_bone_global_pose(d.wrist) * (d.palm as Vector3))
		var mid: Vector3 = (gp.call(d.chains.middle[0]) as Transform3D).origin
		var seen := _seen(cam, palm) or _seen(cam, mid)
		r.n += 1
		if only_seen and not seen:
			continue
		r.seen += 1
		# Bone lengths, the arm's and every finger's
		var worst := 0.0
		var chain := [d.elbow, d.wrist]   # (the arm bone itself is set where the shoulder goes, off its root)
		for fn in d.chains:
			chain.append_array(d.chains[fn])
		for b in chain:
			var par := sk.get_bone_parent(b)
			if par < 0 or not _rest_len.has(b) or float(_rest_len[b]) < 0.01:
				continue
			var now := sk.get_bone_global_pose(b).origin.distance_to(sk.get_bone_global_pose(par).origin)
			worst = maxf(worst, absf(now / float(_rest_len[b]) - 1.0) * 100.0)
			var scl := sk.get_bone_global_pose(b).basis.get_scale()
			worst = maxf(worst, maxf(absf(scl.x - 1.0), maxf(absf(scl.y - 1.0), absf(scl.z - 1.0))) * 100.0)
		r.len = maxf(r.len, worst)
		var miss := palm.distance_to(p.at) * 100.0
		if miss > r.miss:
			r.miss = miss
			r.miss_k = k
		# The elbow
		var a1 := (S - E).normalized()
		var a2 := (W - E).normalized()
		var inner := rad_to_deg(a1.angle_to(a2))
		r.elbow_lo = minf(r.elbow_lo, inner)
		r.elbow_hi = maxf(r.elbow_hi, inner)
		var line := (W - S).normalized()
		var out := E - S - line * (E - S).dot(line)
		if out.length() > 0.005 and inner < STRAIGHT:   # (a near-straight arm has no side to bend to)
			var oc := (ci.basis * out).normalized()
			r.up = maxf(r.up, rad_to_deg(asin(clampf(oc.y, -1.0, 1.0))))
			var pk: String = item + s
			# (not across the frame a switch puts a new thing in hand: the grip itself jumps then)
			var in_hand := "%s/%s" % [w.guns[w.cur] if w.cur < w.guns.size() else "", w.blade_out]
			if _prev_elbow.has(pk) and _prev_elbow[pk][1] == label and _prev_elbow[pk][2] == in_hand:
				# (as a speed, per thirtieth of a second, so a slow frame rate does not read as a snap)
				var per := (1.0 / 30.0) / clampf(_dt, 1.0 / 120.0, 0.25)
				r.flip = maxf(r.flip, rad_to_deg((_prev_elbow[pk][0] as Vector3).angle_to(oc)) * per)
			_prev_elbow[pk] = [oc, label, in_hand]
		# The wrist: the forearm's line seen in the hand's own frame
		var f: Vector3 = mid - W
		var aa: Vector3 = (gp.call(d.chains.point[0]) as Transform3D).origin - (gp.call(d.chains.pink[0]) as Transform3D).origin
		var H := FPHands._frame(f, aa, s)
		var u := H.inverse() * (W - E).normalized()
		var flex := rad_to_deg(atan2(-u.z, u.x))
		var side := rad_to_deg(atan2(-u.y, u.x))
		r.flex = flex if absf(flex) > absf(r.flex) else r.flex
		r.side = side if absf(side) > absf(r.side) else r.side
		# The forearm's turn: 0 with the thumb up and the palm facing in, + toward palm down
		var fa := (W - E).normalized()
		var kx := (E - S).normalized().cross(fa)
		if kx.length() > 0.05:
			kx = kx.normalized()
			var n0 := -kx if s == "R" else kx
			var n := H.z - fa * H.z.dot(fa)
			var ang := rad_to_deg(n0.signed_angle_to(n.normalized(), fa))
			var pro := -ang if s == "R" else ang
			if trace != "" and trace == "%s|%s|%s" % [item, label, s]:
				var ex: Dictionary = hands.explained.get(s, {})
				var ex_s := []
				for kk in ex:
					if ex[kk] is float:
						ex_s.append("%s=%.0f" % [kk, ex[kk]])
				print("TRACE k=%.2f pro=%.0f inner=%.0f up=%.0f E=%s %s" % [k, pro, inner, r.up, str(E - S).substr(0, 40), " ".join(ex_s)])
			r.pro_lo = minf(r.pro_lo, pro)
			r.pro_hi = maxf(r.pro_hi, pro)
			if absf(pro) > absf(r.pro):
				r.pro = pro
				if verbose and hands.explained.has(s):
					r.why = hands.explained[s].duplicate()
		# Fingers into each other
		var fw := 0.0
		var fat := ""
		var gpos := {}
		for pr in PAIRS:
			if not _fcaps[s].has(pr[0]) or not _fcaps[s].has(pr[1]):
				continue
			var ca: Array = _fcaps[s][pr[0]]
			var cb: Array = _fcaps[s][pr[1]]
			for i1 in ca.size():
				for i2 in cb.size():
					if i1 == 0 and i2 == 0:
						continue   # the knuckles themselves sit side by side
					var c1: Array = ca[i1]
					var c2: Array = cb[i2]
					for bb in [c1[0], c1[1], c2[0], c2[1]]:
						if not gpos.has(bb):
							gpos[bb] = sk.get_bone_global_pose(bb).origin
					var dd := _seg_seg(gpos[c1[0]], gpos[c1[1]], gpos[c2[0]], gpos[c2[1]])
					var pen := (float(c1[2]) + float(c2[2])) * 0.8 - dd   # skins may press a little
					if pen * sc * 100.0 > fw:
						fw = pen * sc * 100.0
						fat = "%s%d/%s%d" % [pr[0], i1 + 1, pr[1], i2 + 1]
		if fw > r.fing:
			r.fing = fw
			r.fing_at = fat
		# The skin against the gun (every third frame: it is the slow part)
		if not held.is_empty() and (_nframe % 3 == 0 or k >= 0.0 and _nframe % 2 == 0):
			var near := INF
			var deep := 0.0
			var deep_at := ""
			var pts: Array = _skin[s]
			for e in pts:
				var wp: Vector3 = skg * (sk.get_bone_global_pose(e[0]) * (e[1] as Vector3))
				var sd := _signed(held, wp, REACH)
				if sd < near:
					near = sd
				if -sd > deep:
					deep = -sd
					deep_at = sk.get_bone_name(e[0])
			var gap := maxf(near, 0.0) * 100.0
			if gap > r.gap:
				r.gap = gap
				r.gap_k = k
			r.gap_n += 1
			if deep * 100.0 > r.pen:
				r.pen = deep * 100.0
				r.pen_at = deep_at
				r.pen_k = k


static func _seen(cam: Camera3D, at: Vector3) -> bool:
	if cam.is_position_behind(at):
		return false
	var sp := cam.unproject_position(at)
	var vs := cam.get_viewport().get_visible_rect().size
	return sp.x >= 0.0 and sp.y >= 0.0 and sp.x <= vs.x and sp.y <= vs.y


# ------------------------------------------------------------------ the held thing's surface

## The surfaces of what is in hand: each mesh (or each bone's share of a skinned one) with its triangles in a
## grid, in its own space.
func _held_parts() -> Array:
	var obj: Node3D = null
	if w.blade_out or w._swing > 0.0:
		obj = w._melee_models.get(w.melee)
	else:
		obj = w._model
	if obj == null:
		return []
	var id := obj.get_instance_id()
	if not _parts.has(id):
		var t0 := Time.get_ticks_msec()
		_parts[id] = _build_parts(obj)
		if verbose:
			var nt := 0
			for pt in _parts[id]:
				nt += (pt.tris as Array).size()
			print("HANDCHECK parts %s: %d parts %d tris in %d ms" % [obj.name, (_parts[id] as Array).size(), nt, Time.get_ticks_msec() - t0])
	var out := []
	for pt in _parts[id]:
		var mi: MeshInstance3D = pt.mi
		if not is_instance_valid(mi) or not mi.is_visible_in_tree():
			continue
		if pt.has("sk"):
			var sk: Skeleton3D = pt.sk
			if mi.get_parent() is Node3D and absf((mi.global_transform.basis.get_scale() - Vector3.ONE).x) < 0.0 :
				pass
			var g := sk.global_transform * sk.get_bone_global_pose(pt.bone)
			# a bone scaled to nothing (a magazine taken out) is not there
			if g.basis.get_scale().x < 0.01 * sk.global_transform.basis.get_scale().x:
				continue
			pt.tr = g
		else:
			pt.tr = mi.global_transform
		pt.inv = (pt.tr as Transform3D).affine_inverse()
		out.append(pt)
	return out


func _build_parts(obj: Node3D) -> Array:
	var parts := []
	for c in obj.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() and not mi.get_parent().has_meta("mid"):
			pass
		if mi.mesh == null:
			continue
		var sk: Skeleton3D = null
		if mi.skin != null:
			sk = mi.get_node_or_null(mi.skeleton) as Skeleton3D
		var buckets := {}
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			if arr.is_empty():
				continue
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns = arr[Mesh.ARRAY_NORMAL]
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx == null or (idx as PackedInt32Array).is_empty():
				idx = PackedInt32Array(range(vs.size()))
			var bones = arr[Mesh.ARRAY_BONES] if sk else null
			var wts = arr[Mesh.ARRAY_WEIGHTS] if sk else null
			var per: int = (wts as PackedFloat32Array).size() / maxi(vs.size(), 1) if sk and wts != null else 0
			for t in range(0, (idx as PackedInt32Array).size() - 2, 3):
				var ia: int = idx[t]
				var ib: int = idx[t + 1]
				var ic: int = idx[t + 2]
				var key := -1
				var a := vs[ia]
				var b := vs[ib]
				var cc := vs[ic]
				var n := Vector3.ZERO
				if ns != null and (ns as PackedVector3Array).size() == vs.size():
					n = (ns[ia] + ns[ib] + ns[ic]).normalized()
				if sk and per > 0:
					var best := 0
					for j in per:
						if wts[ia * per + j] > wts[ia * per + best]:
							best = j
					var bi: int = bones[ia * per + best]
					var bb := mi.skin.get_bind_bone(bi)
					if bb < 0:
						bb = sk.find_bone(mi.skin.get_bind_name(bi))
					key = bb
					var bp := mi.skin.get_bind_pose(bi)
					a = bp * a
					b = bp * b
					cc = bp * cc
					n = (bp.basis * n).normalized()
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append([a, b, cc, n])
		for key in buckets:
			var sc := 1.0
			if sk and key >= 0:
				sc = (sk.global_transform * sk.get_bone_global_pose(key)).basis.get_scale().x
			else:
				sc = mi.global_transform.basis.get_scale().x
			var pt := {"mi": mi, "tris": _weld(buckets[key], WELD / maxf(sc, 1e-6))}
			if (pt.tris as Array).is_empty():
				continue
			if sk and key >= 0:
				pt.sk = sk
				pt.bone = key
			pt.cell = REACH / maxf(sc, 1e-6)
			var lo: Vector3 = pt.tris[0][0]
			var hi: Vector3 = lo
			for t in pt.tris:
				for q in 3:
					lo = lo.min(t[q])
					hi = hi.max(t[q])
			pt.box = AABB(lo, hi - lo).grow(pt.cell)
			pt.grid = _grid(pt.tris, pt.cell)
			parts.append(pt)
	return parts


## Fewer, larger triangles: every corner moved to the middle of its little cube (q across), and what then
## folds to nothing or repeats left out. The surface stays within q of where it was.
const WELD := 0.002

static func _weld(tris: Array, q: float) -> Array:
	var out := []
	var seen := {}
	for t in tris:
		var k0 := Vector3i(((t[0] as Vector3) / q).round())
		var k1 := Vector3i(((t[1] as Vector3) / q).round())
		var k2 := Vector3i(((t[2] as Vector3) / q).round())
		if k0 == k1 or k1 == k2 or k0 == k2:
			continue
		var ks := [k0, k1, k2]
		ks.sort()
		var key := "%s%s%s" % ks
		if seen.has(key):
			continue
		seen[key] = true
		out.append([Vector3(k0) * q, Vector3(k1) * q, Vector3(k2) * q, t[3]])
	return out


static func _grid(tris: Array, cell: float) -> Dictionary:
	var g := {}
	for i in tris.size():
		var t: Array = tris[i]
		var lo: Vector3 = (t[0] as Vector3).min(t[1]).min(t[2])
		var hi: Vector3 = (t[0] as Vector3).max(t[1]).max(t[2])
		var a := Vector3i((lo / cell).floor())
		var b := Vector3i((hi / cell).floor())
		if (b - a).x > 6 or (b - a).y > 6 or (b - a).z > 6:
			# a big triangle: in every cell it spans is too many; keep it in a list of its own
			if not g.has("big"):
				g["big"] = []
			g["big"].append(i)
			continue
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				for z in range(a.z, b.z + 1):
					var key := Vector3i(x, y, z)
					if not g.has(key):
						g[key] = PackedInt32Array()
					g[key].append(i)
	return g


## The signed distance from p (in the world) to the nearest surface within reach (m): below 0 inside.
static func _signed(parts: Array, p: Vector3, reach: float) -> float:
	var best := reach
	var sign := 1.0
	for pt in parts:
		var tr: Transform3D = pt.tr
		var lp: Vector3 = pt.inv * p
		if not (pt.box as AABB).has_point(lp):
			continue
		var cell: float = pt.cell
		var c := Vector3i((lp / cell).floor())
		var g: Dictionary = pt.grid
		var tris: Array = pt.tris
		var cand := PackedInt32Array()
		for x in range(c.x - 1, c.x + 2):
			for y in range(c.y - 1, c.y + 2):
				for z in range(c.z - 1, c.z + 2):
					var key := Vector3i(x, y, z)
					if g.has(key):
						cand.append_array(g[key])
		if g.has("big"):
			cand.append_array(PackedInt32Array(g["big"]))
		for i in cand:
			var t: Array = tris[i]
			var q := _closest(lp, t[0], t[1], t[2])
			var wq := tr * q
			var dd := wq.distance_to(p)
			if dd < best:
				best = dd
				var n: Vector3 = t[3]
				if n == Vector3.ZERO:
					n = ((t[1] as Vector3) - t[0]).cross((t[2] as Vector3) - t[0])
				sign = -1.0 if (lp - q).dot(n) < 0.0 else 1.0
	return best * sign


static func _closest(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var den := 1.0 / (va + vb + vc)
	return a + ab * (vb * den) + ac * (vc * den)


# ------------------------------------------------------------------ the verdict

func _fails(r: Dictionary) -> Array:
	var f := []
	if r.seen == 0:
		return f
	if r.len > LIMITS.len: f.append("len")
	if r.miss > LIMITS.miss: f.append("miss")
	if r.elbow_lo < LIMITS.elbow_lo: f.append("elbow")
	if r.up > LIMITS.up: f.append("up")
	if r.flip > LIMITS.flip: f.append("flip")
	if absf(r.flex) > LIMITS.flex: f.append("flex")
	if absf(r.side) > LIMITS.side: f.append("side")
	if absf(r.pro) > LIMITS.pro: f.append("pro")
	if r.gap_n > 0 and r.gap > LIMITS.gap: f.append("gap")
	if r.pen > LIMITS.pen: f.append("pen")
	if r.fing > LIMITS.fing: f.append("fing")
	return f


func _summary() -> Dictionary:
	var bad := []
	for key in rows:
		var r: Dictionary = rows[key]
		var f := _fails(r)
		print("HANDCHECK %s seen=%d/%d len=%.2f miss=%.1f@%.2f elbow=%.0f..%.0f up=%.0f flip=%.0f flex=%.0f side=%.0f pro=%.0f(%.0f..%.0f) gap=%.1f@%.2f pen=%.1f@%.2f:%s fing=%.2f:%s %s" % [key, r.seen, r.n,
			r.len, r.miss, r.miss_k, r.elbow_lo, r.elbow_hi, r.up, r.flip, r.flex, r.side, r.pro, r.pro_lo if r.pro_lo < 999 else 0.0, r.pro_hi if r.pro_hi > -999 else 0.0,
			r.gap, r.gap_k, r.pen, r.pen_k, r.pen_at, r.fing, r.fing_at, ("FAIL " + ",".join(f)) if not f.is_empty() else "ok"])
		if verbose and r.has("why"):
			var ws := []
			for kk in r.why:
				ws.append("%s=%s" % [kk, (("%.0f" % r.why[kk]) if r.why[kk] is float else str(r.why[kk]))])
			print("   why ", " ".join(ws))
		if not f.is_empty():
			bad.append("%s:%s" % [key, ",".join(f)])
	# The hard faults (a bone stretched, a hand short of its place, a joint past what it can do) apart from
	# the skin's touch, which is judged by eye as well
	var hard := 0
	for b in bad:
		for f in str(b).get_slice(":", 1).split(","):
			if not f in ["pen", "gap", "fing"]:
				hard += 1
				break
	print("HANDFIT rows=%d failing=%d hard=%d %s" % [rows.size(), bad.size(), hard, " ".join(bad)])
	return {"rows": rows, "bad": bad}
