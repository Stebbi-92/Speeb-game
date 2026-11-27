class_name LegStepper
extends SkeletonModifier3D
## Many legs that step, for a body whose clip came with no walk (the Tar Mother, a spider of eight legs posed on
## a rock): each foot is set on a mark on the ground about the body, spread as a spider spreads them, and the leg
## reaches it, its knee kept high. While down a foot's mark goes back under the body exactly as fast as the body
## goes on, so it stays where it was set; up, it swings ahead again, lifted. The legs go in two sets of alternate
## legs (one side's first and third with the other's second and fourth), as spiders walk. Standing, the feet
## stay on their marks. Its owner sets pace (metres a second) and face (what it faces by, +Z ahead).
## (Like the Stepper, Godot puts the bones back as the clip left them once the skin is drawn: posed, with keep,
## is for readers after the frame.)

var pace := 0.0
var face: Node3D
var ground_at := Callable()  ## (x, z) -> the ground's height in the world there; unset, the lowest foot at rest
var keep := false         ## (testing aid) keep the stepped pose in posed
var posed_n := 0
var posed := {}
var _legs := []           ## [[bones from the hip down to the tip], the knee's place in it, side (+1 left), set (0/1),
                          ##  home (left, ahead) in the skeleton's units, its reach]
var _ground := 0.0        ## the ground under the body, along up, in the skeleton's units
var _ph := 0.0
var _w := 0.0
var _T := 1.0
var _S := 0.0
var _ready_legs := false
const DUTY := 0.55


## The legs: the low far ends of chains that branch from the body, n of them (the farthest from the middle).
## Returns false when it has fewer.
func find_legs(n := 8) -> bool:
	var sk := get_skeleton()
	if sk == null:
		return false
	# (called once it is in the tree, so its up is known)
	var up := (sk.global_basis.inverse() * Vector3.UP).normalized() if sk.is_inside_tree() else Vector3.UP
	var lo := 1e9
	var hi := -1e9
	var mid := Vector3.ZERO
	for i in sk.get_bone_count():
		var p := sk.get_bone_global_rest(i).origin
		lo = minf(lo, p.dot(up))
		hi = maxf(hi, p.dot(up))
		mid += p
	mid /= maxf(1.0, sk.get_bone_count())
	var H := hi - lo
	var ends := []
	for i in sk.get_bone_count():
		if not sk.get_bone_children(i).is_empty():
			continue
		var p := sk.get_bone_global_rest(i).origin - mid
		var far := (p - up * p.dot(up)).length()
		# up the chain to where it branches: a leg has at least three bones of its own
		var chain := [i]
		var b := sk.get_bone_parent(i)
		while b >= 0 and sk.get_bone_children(b).size() == 1:
			chain.push_front(b)
			b = sk.get_bone_parent(b)
		if chain.size() >= 3 and far > H * 0.3:
			ends.append([far, chain])
	if ends.size() < n:
		return false
	ends.sort_custom(func(a, b): return a[0] > b[0])
	_legs.clear()
	for e in ends.slice(0, n):
		var chain: Array = e[1]
		_legs.append([chain, 1, 1.0, 0, Vector2.ZERO, 0.0])
	_ground = 1e9
	for l in _legs:
		_ground = minf(_ground, sk.get_bone_global_rest(l[0][l[0].size() - 1]).origin.dot(up))
	_ready_legs = false
	return true


func _frame(sk: Skeleton3D) -> Basis:
	var up := (sk.global_basis.inverse() * Vector3.UP).normalized()
	var f := Vector3(0, 0, 1)
	if face:
		f = face.global_basis.z
	var fw := sk.global_basis.inverse() * f
	fw = (fw - up * fw.dot(up)).normalized()
	return Basis(up.cross(fw).normalized(), up, fw)


func _hub(sk: Skeleton3D) -> Vector3:
	var c := Vector3.ZERO
	for l in _legs:
		c += sk.get_bone_global_pose(l[0][0]).origin
	return c / _legs.size()


## Sides, order front to back and the two sets; each foot's mark, spread about the body at 40 to 140 degrees from
## ahead, as far out as its leg reaches comfortably from the height its hip stands at.
func _tell_legs(sk: Skeleton3D, fr: Basis) -> void:
	var c := _hub(sk)
	var sides := {1.0: [], -1.0: []}
	for l in _legs:
		var r: Vector3 = sk.get_bone_global_pose(l[0][0]).origin - c
		var t: Vector3 = sk.get_bone_global_pose(l[0][l[0].size() - 1]).origin - c
		l[2] = 1.0 if (r + t * 0.25).dot(fr.x) > 0.0 else -1.0
		sides[l[2]].append(l)
		# the knee: the joint that stands farthest off the line from the hip to the tip
		var ch: Array = l[0]
		var P := sk.get_bone_global_pose(ch[1]).origin
		var E := sk.get_bone_global_pose(ch[ch.size() - 1]).origin
		var best := 2
		var bd := -1.0
		for k in range(2, ch.size() - 1):
			var K := sk.get_bone_global_pose(ch[k]).origin
			var u := (E - P).normalized()
			var off := (K - P) - u * (K - P).dot(u)
			if off.length() > bd:
				bd = off.length()
				best = k
		l[1] = best
		var a := P.distance_to(sk.get_bone_global_pose(ch[best]).origin)
		var b := sk.get_bone_global_pose(ch[best]).origin.distance_to(E)
		l[5] = a + b
	for s in sides:
		var legs: Array = sides[s]
		legs.sort_custom(func(a, b): return sk.get_bone_global_pose(a[0][0]).origin.dot(fr.z) > sk.get_bone_global_pose(b[0][0]).origin.dot(fr.z))
		for i in legs.size():
			var l: Array = legs[i]
			l[3] = (i + (0 if s > 0 else 1)) % 2
			var ang := deg_to_rad(lerpf(40.0, 140.0, float(i) / maxf(1.0, legs.size() - 1)))
			l[4] = Vector2(sin(ang) * s, cos(ang))
	_ready_legs = true


var _last_us := 0


## (kept by its own clock, at each modification: the modification runs every drawn frame)
func _advance(sk: Skeleton3D) -> void:
	var now := Time.get_ticks_usec()
	var delta := clampf((now - _last_us) / 1e6, 0.0, 0.1) if _last_us > 0 else 0.0
	_last_us = now
	if delta <= 0.0:
		return
	var m := sk.global_basis.get_scale().x
	var L := 0.0
	for l in _legs:
		L += float(l[5])
	L = L / _legs.size() * m
	var v := pace
	_w = move_toward(_w, 1.0 if v > 0.2 else 0.0, delta * 3.0)
	if v > 0.05:
		# a stride of about half a leg at a walk, longer as it hurries, quicker steps the faster it goes
		var S := L * clampf(0.35 + 0.08 * v / maxf(L, 0.1), 0.35, 0.8)
		_T = clampf(S / (v * DUTY), 0.2, 1.4)
		_S = v * DUTY * _T
		_ph = fmod(_ph + delta / _T, 1.0)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _legs.is_empty():
		return
	_advance(sk)
	var fr := _frame(sk)
	if not _ready_legs:
		_tell_legs(sk, fr)
	var m := sk.global_basis.get_scale().x
	var c := _hub(sk)
	var L := 0.0
	for l in _legs:
		L += float(l[5])
	L /= _legs.size()
	for l in _legs:
		var p := fmod(_ph + 0.5 * float(l[3]), 1.0)
		var x := 0.0
		var y := 0.0
		if p < DUTY:
			x = _S * (0.5 - p / DUTY)
		else:
			var s := (p - DUTY) / (1.0 - DUTY)
			x = _S * (-0.5 + (3.0 * s * s - 2.0 * s * s * s))
			y = sin(s * PI) * L * m * 0.18
		x *= _w
		y *= _w
		# its mark: out from its hip the way it is spread, as far as the leg reaches comfortably down to the ground
		var P := sk.get_bone_global_pose(l[0][1]).origin
		var g := _ground_under(sk, fr, P)
		var h := P.dot(fr.y) - g
		var reach := float(l[5]) * 0.92
		var flat := clampf(sqrt(maxf(reach * reach - h * h, 0.0)) * 0.8, float(l[5]) * 0.25, float(l[5]) * 0.85)
		var hip := P - c
		var dir: Vector2 = l[4]
		var T := c + fr.x * (hip.dot(fr.x) + dir.x * flat) + fr.z * (hip.dot(fr.z) + dir.y * flat + x / m)
		T += fr.y * (_ground_under(sk, fr, T) - T.dot(fr.y) + y / m)
		_reach(sk, fr, l, T)
	if keep:
		posed_n += 1
		for i in sk.get_bone_count():
			posed[i] = sk.get_bone_global_pose(i)


## The ground under a point (in the skeleton's frame), along up
func _ground_under(sk: Skeleton3D, fr: Basis, p: Vector3) -> float:
	if not ground_at.is_valid():
		return _ground
	var w := sk.global_transform * p
	var gy := float(ground_at.call(w.x, w.z))
	return (sk.global_transform.affine_inverse() * Vector3(w.x, gy, w.z)).dot(fr.y)


## The hip turns so the knee stands up over the line to the mark, and the knee turns so the tip comes onto it
## (what lies between keeps its own bend).
func _reach(sk: Skeleton3D, fr: Basis, l: Array, T: Vector3) -> void:
	var ch: Array = l[0]
	var hb: int = ch[1]
	var kb: int = ch[int(l[1])]
	var eb: int = ch[ch.size() - 1]
	var P := sk.get_bone_global_pose(hb).origin
	var K := sk.get_bone_global_pose(kb).origin
	var E := sk.get_bone_global_pose(eb).origin
	var a := P.distance_to(K)
	var b := K.distance_to(E)
	if a < 1e-5 or b < 1e-5:
		return
	var d := clampf(P.distance_to(T), absf(a - b) + 1e-4, (a + b) * 0.999)
	var u := (T - P).normalized()
	var v := fr.y - u * fr.y.dot(u)
	if v.length() < 1e-4:
		v = fr.z - u * fr.z.dot(u)
	v = v.normalized()
	var ca := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var Kd := P + a * (u * ca + v * sqrt(1.0 - ca * ca))
	_aim(sk, hb, K - P, Kd - P)
	E = sk.get_bone_global_pose(eb).origin
	_aim(sk, kb, E - Kd, T - Kd)


## Turns a bone (and all it carries) so the way from it that was `from` is `to`, in the skeleton's frame
static func _aim(sk: Skeleton3D, b: int, from: Vector3, to: Vector3) -> void:
	if from.length() < 1e-6 or to.length() < 1e-6:
		return
	var q := Quaternion(from.normalized(), to.normalized())
	var g := sk.get_bone_global_pose(b)
	var par := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
	sk.set_bone_pose_rotation(b, (pg.basis.orthonormalized().inverse() * (Basis(q) * g.basis.orthonormalized())).get_rotation_quaternion())
