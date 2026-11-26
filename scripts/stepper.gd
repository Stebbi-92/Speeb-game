class_name Stepper
extends SkeletonModifier3D
## Four legs that step, for a body whose clips came with no walk of its own (the lesser forms' panther, the
## goat): on top of whatever its clip is doing (a breath, a turn of the head), each leg swings from the hip and
## folds at the knee to lift its foot through the air. The swing is timed to the pace, so a foot set down stays
## where it was set while the body passes over it: a walk with the feet in turn, and past a trot a bound with
## the hind legs and the fore legs each together. Its owner sets pace (metres a second) and face (what it faces
## by, +Z ahead unless back is set).

var pace := 0.0
var face: Node3D
var back := false         ## the body faces -Z
var _legs := []           ## [upper, lower, end, hind?, left?, length in the skeleton's units, knee sign]
var _ph := 0.0            ## the gait's phase, 0..1 over one full stride
var _w := 0.0             ## how much of the stepping shows (none at a stand)
var _run := 0.0           ## from walk (0) to bound (1)
var _ready_legs := false
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
		legs.append([upper, lower, e])
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
		_legs.append([u, l[1], l[2], false, false, length, 1.0])
	_ready_legs = false   # front and back, left and right, are told on the first frame, by the way it faces
	return true


static func _skip(sk: Skeleton3D, b: int) -> bool:
	var n := sk.get_bone_name(b).to_lower()
	for s in SKIP:
		if s in n:
			return true
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
		# The knee folds the way that lifts the foot
		var lo: Vector3 = sk.get_bone_global_pose(l[1]).origin
		var d: Vector3 = sk.get_bone_global_pose(l[2]).origin - lo
		var a := Quaternion(fr.x, 0.4) * d
		var b := Quaternion(fr.x, -0.4) * d
		l[6] = 1.0 if a.dot(fr.y) > b.dot(fr.y) else -1.0
	_ready_legs = true


func _process(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _legs.is_empty():
		return
	var m := sk.global_basis.get_scale().x
	var L := 0.0
	for l in _legs:
		L += float(l[5]) * m
	L /= _legs.size()
	var v := pace
	_w = move_toward(_w, 1.0 if v > 0.25 else 0.0, delta * 3.0)
	_run = move_toward(_run, 1.0 if v > L * 4.5 else 0.0, delta * 2.0)
	if v > 0.05:
		# A stride's time: quicker steps the faster it goes, slower for long legs
		var T := clampf(0.95 - 0.05 * v / maxf(L, 0.1), 0.32, 1.0) * sqrt(L / 0.45)
		_ph = fmod(_ph + delta / T, 1.0)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _legs.is_empty() or _w <= 0.001:
		return
	var fr := _frame(sk)
	if not _ready_legs:
		_tell_legs(sk, fr)
	var m := sk.global_basis.get_scale().x
	var L := 0.0
	for l in _legs:
		L += float(l[5]) * m
	L /= _legs.size()
	var T := clampf(0.95 - 0.05 * pace / maxf(L, 0.1), 0.32, 1.0) * sqrt(L / 0.45)
	var duty := lerpf(0.62, 0.4, _run)
	# How far the body goes while a foot is down: each leg's swing is sized to it
	var S := pace * duty * T
	for l in _legs:
		var hind: bool = l[3]
		var left: bool = l[4]
		var off := 0.0
		if hind:
			off = 0.0 if left else lerpf(0.5, 0.1, _run)
		else:
			off = lerpf(0.25, 0.5, _run) if left else lerpf(0.75, 0.6, _run)
		var p := fmod(_ph + off, 1.0)
		var len_m := float(l[5]) * m
		var A := asin(clampf(S / maxf(2.0 * len_m, 0.01), 0.0, 0.75))
		var th := 0.0
		var bend := 0.0
		if p < duty:
			th = A * (1.0 - 2.0 * p / duty)
		else:
			var s := (p - duty) / (1.0 - duty)
			th = A * (-1.0 + 2.0 * smoothstep(0.0, 1.0, s))
			bend = sin(s * PI) * lerpf(0.55, 0.85, _run) * clampf(A / 0.25, 0.4, 1.2)
		th *= _w
		bend *= _w
		var up_b: int = l[0]
		var lo_b: int = l[1]
		var par := sk.get_bone_parent(up_b)
		var pg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
		var ug := sk.get_bone_global_pose(up_b)
		# forward is a turn by minus the angle about its left (see Slump)
		var nb := Basis(Quaternion(fr.x, -th)) * ug.basis
		sk.set_bone_pose_rotation(up_b, (pg.basis.inverse() * nb).get_rotation_quaternion())
		if bend > 0.0:
			var ug2 := sk.get_bone_global_pose(up_b)
			var lg := sk.get_bone_global_pose(lo_b)
			var nl := Basis(Quaternion(fr.x, bend * float(l[6]))) * lg.basis
			var lp := sk.get_bone_parent(lo_b)
			var lpg := ug2 if lp == up_b else sk.get_bone_global_pose(lp)
			sk.set_bone_pose_rotation(lo_b, (lpg.basis.inverse() * nl).get_rotation_quaternion())
