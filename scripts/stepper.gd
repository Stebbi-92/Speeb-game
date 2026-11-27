class_name Stepper
extends SkeletonModifier3D
## Four legs that step, for a body whose clips came with no walk of its own (the lesser forms' panther, the
## goat): on top of whatever its clip is doing (a breath, a turn of the head), each foot is set on a mark and
## the leg reaches it (hip, knee and wrist or hock turning about the body's left, the shoulder blade swinging
## with a fore leg). While down a foot's mark goes back under the body exactly as fast as the body goes on, so
## it stays where it was set; up, it swings ahead again, lifted. A walk with the feet in turn, and past a trot a
## bound with the hind legs and the fore legs each nearly together. Its owner sets pace (metres a second) and
## face (what it faces by, +Z ahead unless back is set).
##
## (Godot 4.3 puts the bones back as the clip left them once the skin is drawn: whatever reads a bone after the
## frame sees the clip, not the step. sink, and posed when keep is set, are for such readers.)

var pace := 0.0
var face: Node3D
var back := false         ## the body faces -Z
var _legs := []           ## [upper, lower, end, hind?, left?, length in the skeleton's units, knee sign, reach straight
                          ## (1e9 for a fore leg on its blade),
                          ## the bone below the lower (wrist, hock), its joint's sign, the shoulder blade (or -1),
                          ## the ground under it (the end's lowest), how far the end hangs below the hip]
var _ph := 0.0            ## the gait's phase, 0..1 over one full stride
var _w := 0.0             ## how much of the stepping shows (none at a stand)
var _run := 0.0           ## from walk (0) to bound (1)
var _ready_legs := false
var _hub := -1            ## the bone all four legs hang from
var _sink_to := 0.0
var sink := 0.0           ## how far the body is let down so straight legs can stride (metres); read it to follow
var _T := 1.0             ## a stride's time
var _S := 0.0             ## how far the body goes while a foot is down (metres)
var _duty := 0.62         ## the share of a stride each foot is down
var keep := false         ## (testing aid) keep the stepped pose in posed: Godot puts the bones back as the clip
var posed_n := 0          ## (testing aid) how many times it has been kept
var posed := {}           ## left them once the skin is drawn, so a reader after the frame sees no step
const BLADE := 0.55       ## how much of a fore leg's swing its shoulder blade takes
const SKIP := ["clavicle", "shoulder", "scapula", "twist", "horselink", "xtra", "finger_bone"]


## The legs of a four-legged rig, found by its bones: each ends low near the ground, and runs up to where the
## trunk branches. Returns false when it does not have four.
func find_legs() -> bool:
	var sk := get_skeleton()
	if sk == null:
		return false
	var up := Vector3.UP
	var low := 1e9
	var top := -1e9
	for i in sk.get_bone_count():
		var y := sk.get_bone_global_rest(i).origin.dot(up)
		low = minf(low, y)
		top = maxf(top, y)
	var H := top - low
	# The low ends: bones with no children of their own (or only twist bones) near the ground
	var ends := []
	for i in sk.get_bone_count():
		var y := sk.get_bone_global_rest(i).origin.dot(up)
		if y > low + H * 0.15:
			continue
		var kids := Array(sk.get_bone_children(i)).filter(func(c): return not _skip(sk, c))
		if not kids.is_empty():
			continue
		if _skip(sk, i) or "tail" in sk.get_bone_name(i).to_lower():
			continue
		ends.append(i)
	# One end for each leg: the lowest bone of each chain (toes over the foot)
	var chains := {}
	for e in ends:
		var chain := []
		var b: int = e
		while b >= 0:
			chain.append(b)
			b = sk.get_bone_parent(b)
		chains[e] = chain
	# Each end's upper bone: the topmost of its chain that no other end shares, past the shoulder blade
	var legs := []
	for e in ends:
		var chain: Array = chains[e]
		var own := []
		for b in chain:
			var shared := false
			for e2 in ends:
				if e2 != e and b in chains[e2] and not (_same_leg(sk, e, e2)):
					shared = true
					break
			if shared:
				break
			own.append(b)
		own = own.filter(func(b): return not _skip(sk, b))
		if own.size() < 3:
			continue
		var upper: int = own[own.size() - 1]
		var lower: int = own[own.size() - 2]
		var dup := false
		for l in legs:
			if l[0] == upper:
				dup = true
		if dup:
			continue
		# the bone the lower one carries on the way to the end (a wrist, a hock), skipped names or not
		var mid: int = e
		for b in chain:
			if sk.get_bone_parent(b) == lower:
				mid = b
		legs.append([upper, lower, e, mid])
	if legs.size() > 4:
		# a tail hanging low, or a dew-claw: the four that reach lowest are the legs
		legs.sort_custom(func(a, b): return sk.get_bone_global_rest(a[2]).origin.y < sk.get_bone_global_rest(b[2]).origin.y)
		legs = legs.slice(0, 4)
	if legs.size() != 4:
		return false
	_legs.clear()
	for l in legs:
		var u: int = l[0]
		var length := (sk.get_bone_global_rest(l[2]).origin - sk.get_bone_global_rest(u).origin).length()
		# a fore leg hangs from its shoulder blade, which swings with it (a cat's reach is half in the blade)
		var blade := sk.get_bone_parent(u)
		if blade < 0 or not (_skip(sk, blade) and ("clavicle" in sk.get_bone_name(blade).to_lower() or "scapula" in sk.get_bone_name(blade).to_lower() or "shoulder" in sk.get_bone_name(blade).to_lower())):
			blade = -1
		_legs.append([u, l[1], l[2], false, false, length, 1.0, length, l[3], 1.0, blade, 1e9, 0.0])
	# the bone all four hang from (the pelvis): it sinks a little when the legs stand too straight to stride
	_hub = _legs[0][0]
	while _hub >= 0 and not _legs.all(func(l): return _under(sk, l[0], _hub) and l[0] != _hub):
		_hub = sk.get_bone_parent(_hub)
	_ready_legs = false   # front and back, left and right, are told on the first frame, by the way it faces
	return true


static func _skip(sk: Skeleton3D, b: int) -> bool:
	var n := sk.get_bone_name(b).to_lower()
	for s in SKIP:
		if s in n:
			return true
	return false


static func _under(sk: Skeleton3D, b: int, top: int) -> bool:
	while b >= 0:
		if b == top:
			return true
		b = sk.get_bone_parent(b)
	return false


## Two ends of one leg (the toe and a dew-claw of one foot)
static func _same_leg(sk: Skeleton3D, a: int, b: int) -> bool:
	return sk.get_bone_parent(a) == sk.get_bone_parent(b) or sk.get_bone_parent(a) == b or sk.get_bone_parent(b) == a


func _frame(sk: Skeleton3D) -> Basis:
	var up := (sk.global_basis.inverse() * Vector3.UP).normalized()
	var f := Vector3(0, 0, -1 if back else 1)
	if face:
		f = face.global_basis.z * (-1.0 if back else 1.0)
	var fw := (sk.global_basis.inverse() * f)
	fw = (fw - up * fw.dot(up)).normalized()
	var left := up.cross(fw).normalized()
	return Basis(left, up, fw)


func _tell_legs(sk: Skeleton3D, fr: Basis) -> void:
	var mid := Vector3.ZERO
	for l in _legs:
		mid += sk.get_bone_global_pose(l[2]).origin
	mid /= _legs.size()
	for l in _legs:
		var p: Vector3 = sk.get_bone_global_pose(l[2]).origin - mid
		l[3] = p.dot(fr.z) < 0.0
		l[4] = p.dot(fr.x) > 0.0
		# The knee keeps the way it bends in the clip; how far the foot can reach ahead and behind on the ground
		var h: Vector3 = sk.get_bone_global_pose(l[0]).origin
		var k: Vector3 = sk.get_bone_global_pose(l[1]).origin
		var e: Vector3 = sk.get_bone_global_pose(l[2]).origin
		var u := Vector2((k - h).dot(fr.y), (k - h).dot(fr.z))
		var w := Vector2((e - k).dot(fr.y), (e - k).dot(fr.z))
		var phi := u.angle_to(w)
		l[6] = 1.0 if phi >= 0.0 else -1.0
		var j: Vector3 = sk.get_bone_global_pose(l[8]).origin
		var c := Vector2((j - k).dot(fr.y), (j - k).dot(fr.z))
		var f := Vector2((e - j).dot(fr.y), (e - j).dot(fr.z))
		l[9] = 1.0 if c.angle_to(f) >= 0.0 else -1.0
		# reach: the leg straight (its own joints only); a fore leg on a blade reaches further than that shows
		l[7] = (u.length() + c.length() + f.length()) * 0.97 if int(l[10]) < 0 else 1e9
		l[12] = (h - e).dot(fr.y)
	_ready_legs = true


func _leg_len(sk: Skeleton3D) -> float:
	var L := 0.0
	for l in _legs:
		L += float(l[5])
	return L / _legs.size() * sk.global_basis.get_scale().x


## The stride for this pace: long and slow at a walk, quick at a bound, never more than the legs can reach.
func _gait(L: float, m: float) -> void:
	var v := maxf(pace, 0.05)
	_duty = lerpf(0.62, 0.36, _run)
	var S := L * clampf(0.5 + 0.12 * v / maxf(L, 0.1), 0.5, 1.6)
	_T = clampf(S / (v * _duty), 0.24, 1.6)
	_S = v * _duty * _T
	# A leg standing straight cannot reach half a stride ahead and behind on the ground: the body comes down
	# as far as it must for the straightest of them, by a seventh of their length at most (and the stride is
	# cut to what that allows)
	var need := 0.0
	for l in _legs:
		var R := float(l[7]) * m
		var dr := float(l[12]) * m
		if R > 1e8 or dr <= 0.0:
			continue
		var cap := dr * 0.14
		var half := minf(_S * 0.5, sqrt(maxf(R * R - (dr - cap) * (dr - cap), 0.0)))
		if half < _S * 0.5:
			_S = 2.0 * half
			_T = _S / (v * _duty)
		need = maxf(need, dr - sqrt(maxf(R * R - half * half, 0.0)))
	_sink_to = need


func _process(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _legs.is_empty():
		return
	var L := _leg_len(sk)
	var v := pace
	_w = move_toward(_w, 1.0 if v > 0.25 else 0.0, delta * 3.0)
	_run = move_toward(_run, 1.0 if v > L * 4.5 else 0.0, delta * 2.0)
	if v > 0.05:
		_gait(L, sk.global_basis.get_scale().x)
		_ph = fmod(_ph + delta / _T, 1.0)
	sink = move_toward(sink, _sink_to * _w, delta * 0.5)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _legs.is_empty():
		return
	if _w <= 0.001:
		_keep(sk)
		return
	var fr := _frame(sk)
	if not _ready_legs:
		_tell_legs(sk, fr)
	var m := sk.global_basis.get_scale().x
	var L := _leg_len(sk)
	var duty := _duty
	if sink > 0.0005 and _hub >= 0:
		var hp := sk.get_bone_parent(_hub)
		var hb := sk.get_bone_global_pose(hp).basis if hp >= 0 else Basis()
		sk.set_bone_pose_position(_hub, sk.get_bone_pose_position(_hub) + hb.inverse() * (-fr.y * sink / m))
	for l in _legs:
		var hind: bool = l[3]
		var left: bool = l[4]
		var off := 0.0
		if hind:
			off = 0.0 if left else lerpf(0.5, 0.1, _run)
		else:
			off = lerpf(0.25, 0.5, _run) if left else lerpf(0.75, 0.6, _run)
		var p := fmod(_ph + off, 1.0)
		# Where the foot goes, ahead (x) and up (y) of where the clip has it, in metres: down, it goes back under
		# the body as fast as the body goes on; up, it swings ahead again, lifted
		var x := 0.0
		var y := 0.0
		if p < duty:
			x = _S * (0.5 - p / duty)
		else:
			var s := (p - duty) / (1.0 - duty)
			# leaving and meeting the ground at the ground's speed: a foot lifts going on back, and reaches past
			# its mark to come down onto it
			var r := _S * (1.0 - duty) / duty
			x = _S * (-0.5 * (2.0 * s * s * s - 3.0 * s * s + 1.0) + 0.5 * (-2.0 * s * s * s + 3.0 * s * s)) - r * s * (2.0 * s - 1.0) * (s - 1.0)
			y = sin(s * PI) * L * lerpf(0.16, 0.26, _run)
		# about the point under its hip (or shoulder blade), on the ground the clip's foot stands on at its lowest
		var E := sk.get_bone_global_pose(l[2]).origin
		var top := sk.get_bone_global_pose(l[10] if int(l[10]) >= 0 else l[0]).origin
		var under := (top - E).dot(fr.z)
		var ey := E.dot(fr.y)
		if ey + sink / m < float(l[11]):
			l[11] = ey + sink / m
		var T := E + (fr.z * (under + x / m) + fr.y * (float(l[11]) - ey + y / m)) * _w
		_reach(sk, fr, l, T)
	_keep(sk)


## Turns the leg's three joints about the body's left so its end is on T: the wrist (or hock) opens only when the
## hip and knee alone cannot reach so far; the knee then opens or folds so the end is as far from the hip as T is,
## and the hip turns the end onto it.
func _reach(sk: Skeleton3D, fr: Basis, l: Array, T: Vector3) -> void:
	var up_b: int = l[0]
	var lo_b: int = l[1]
	var mid_b: int = l[8]
	if int(l[10]) >= 0:
		var R := sk.get_bone_global_pose(l[10]).origin
		var e0 := _flat(sk.get_bone_global_pose(l[2]).origin - R, fr)
		_turn(sk, l[10], fr.x, BLADE * e0.angle_to(_flat(T - R, fr)))
	var H := sk.get_bone_global_pose(up_b).origin
	var K := sk.get_bone_global_pose(lo_b).origin
	var E := sk.get_bone_global_pose(l[2]).origin
	if int(l[10]) >= 0:
		# and the blade slides down the ribs as far as the leg, straight, still falls short
		var J0 := sk.get_bone_global_pose(mid_b).origin
		var full := ((K - H).length() + (J0 - K).length() + (E - J0).length()) * 0.99
		var t0 := _flat(T - H, fr)
		var short := absf(t0.x) - sqrt(maxf(full * full - t0.y * t0.y, 0.0))
		if short > 0.0:
			var par := sk.get_bone_parent(up_b)
			var pb := sk.get_bone_global_pose(par).basis if par >= 0 else Basis()
			var by := minf(short, full * 0.12)
			sk.set_bone_pose_position(up_b, sk.get_bone_pose_position(up_b) + pb.inverse() * (-fr.y * by))
			H = sk.get_bone_global_pose(up_b).origin
			K = sk.get_bone_global_pose(lo_b).origin
			E = sk.get_bone_global_pose(l[2]).origin
	var u := _flat(K - H, fr)
	var w := _flat(E - K, fr)
	var t := _flat(T - H, fr)
	var a := u.length()
	var b := w.length()
	if a < 1e-5 or b < 1e-5:
		return
	var d := t.length()
	if d > (a + b) * 0.995 and mid_b != l[2]:
		var J := sk.get_bone_global_pose(mid_b).origin
		var c := _flat(J - K, fr)
		var f := _flat(E - J, fr)
		var cl := c.length()
		var fl := f.length()
		if cl > 1e-5 and fl > 1e-5:
			var want_b := minf(d * 1.003 - a, (cl + fl) * 0.995)
			if want_b > b:
				var psi := c.angle_to(f)
				var want := acos(clampf((want_b * want_b - cl * cl - fl * fl) / (2.0 * cl * fl), -1.0, 1.0)) * float(l[9])
				_turn(sk, mid_b, fr.x, want - psi)
				E = sk.get_bone_global_pose(l[2]).origin
				w = _flat(E - K, fr)
				b = w.length()
	d = clampf(d, absf(a - b) + 1e-4, (a + b) * 0.999)
	var phi := u.angle_to(w)
	var want := acos(clampf((d * d - a * a - b * b) / (2.0 * a * b), -1.0, 1.0)) * float(l[6])
	var beta := want - phi
	var alpha := (u + w.rotated(beta)).angle_to(t)
	_turn(sk, up_b, fr.x, alpha)
	_turn(sk, lo_b, fr.x, beta)


## A bone's in-plane part: up and ahead
static func _flat(v: Vector3, fr: Basis) -> Vector2:
	return Vector2(v.dot(fr.y), v.dot(fr.z))


## Turns a bone (and all it carries) by ang about the axis, in the skeleton's frame
static func _turn(sk: Skeleton3D, b: int, axis: Vector3, ang: float) -> void:
	if absf(ang) < 1e-6:
		return
	var g := sk.get_bone_global_pose(b)
	var par := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
	var nb := Basis(Quaternion(axis, ang)) * g.basis
	sk.set_bone_pose_rotation(b, (pg.basis.inverse() * nb).get_rotation_quaternion())


func _keep(sk: Skeleton3D) -> void:
	if keep:
		posed_n += 1
		for i in sk.get_bone_count():
			posed[i] = sk.get_bone_global_pose(i)
