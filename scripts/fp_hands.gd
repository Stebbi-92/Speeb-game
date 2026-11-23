class_name FPHands
extends Node3D
## One's own two arms on the weapon in hand: the right on the grip with a finger on the trigger, the left
## under the fore-end (or cupping the right on a side arm), and on the magazine, the shell or the pump through
## a reload. "fps arms" (DJMaesen, CC-BY 4.0), posed by hand here: it comes with no motions of its own.
## Each arm is bent by a simple two-bone reach (shoulder, elbow, wrist); the fingers are curled about the
## hand's own knuckle line.

const PATH := "res://assets/models/hands/fps_arms.glb"
## Whether one's own arms are drawn at all: off for now (Steve, 2026-11-23), until they hold the guns well
const SHOWN := false
const SCALE := 0.0108   ## the model is in centimetres; near life size
## Where the model sits under the eye
const OFFSET := Vector3(0.0, -0.37, -0.02)
## Where each shoulder sits by default, from the eye (a pose may move one: "sh"). They are well forward and
## low, out of sight, as a gun held out before the eye needs: life-length arms would not reach its fore-end.
const SHOULDER := {"R": Vector3(0.19, -0.28, -0.02), "L": Vector3(-0.15, -0.28, -0.08)}

## Each finger's joints (first knuckle to tip), from the wrist, in the hand's own frame (x where the fingers
## point, y the knuckle line, z out of the palm): taken from "LMG animated" (DJMaesen), whose arms grip for real.
const SHAPES := {
	"grip": {"thumb": [Vector3(0.0300, -0.0012, 0.0257), Vector3(0.0621, 0.0199, 0.0578), Vector3(0.0885, 0.0232, 0.0724), Vector3(0.1180, 0.0177, 0.0773)], "point": [Vector3(0.1193, 0.0231, 0.0130), Vector3(0.1484, 0.0247, 0.0226), Vector3(0.1679, 0.0249, 0.0333), Vector3(0.1793, 0.0210, 0.0577)], "middle": [Vector3(0.1181, 0.0000, -0.0000), Vector3(0.1222, -0.0053, 0.0323), Vector3(0.1078, -0.0080, 0.0551), Vector3(0.0759, -0.0069, 0.0576)], "ring": [Vector3(0.1125, -0.0196, 0.0017), Vector3(0.1164, -0.0268, 0.0299), Vector3(0.1047, -0.0295, 0.0520), Vector3(0.0772, -0.0280, 0.0627)], "pink": [Vector3(0.1027, -0.0473, 0.0130), Vector3(0.0981, -0.0487, 0.0316), Vector3(0.0932, -0.0496, 0.0499), Vector3(0.0768, -0.0465, 0.0607)]},
	"fore": {"thumb": [Vector3(0.0300, -0.0040, 0.0254), Vector3(0.0546, 0.0191, 0.0625), Vector3(0.0772, 0.0200, 0.0826), Vector3(0.1066, 0.0127, 0.0850)], "point": [Vector3(0.1193, 0.0215, 0.0154), Vector3(0.1392, 0.0063, 0.0331), Vector3(0.1289, 0.0038, 0.0528), Vector3(0.1069, 0.0045, 0.0686)], "middle": [Vector3(0.1181, -0.0000, -0.0000), Vector3(0.1244, -0.0105, 0.0306), Vector3(0.1109, -0.0136, 0.0539), Vector3(0.0840, -0.0100, 0.0709)], "ring": [Vector3(0.1155, -0.0286, 0.0095), Vector3(0.1146, -0.0360, 0.0379), Vector3(0.1016, -0.0387, 0.0592), Vector3(0.0831, -0.0390, 0.0822)], "pink": [Vector3(0.0983, -0.0542, 0.0154), Vector3(0.0984, -0.0589, 0.0341), Vector3(0.0940, -0.0595, 0.0525), Vector3(0.0852, -0.0583, 0.0703)]},
	"mag": {"thumb": [Vector3(0.0299, -0.0040, 0.0254), Vector3(0.0622, 0.0132, 0.0597), Vector3(0.0825, 0.0200, 0.0812), Vector3(0.0994, 0.0275, 0.1053)], "point": [Vector3(0.1193, 0.0215, 0.0154), Vector3(0.1408, 0.0144, 0.0361), Vector3(0.1476, 0.0063, 0.0557), Vector3(0.1481, -0.0059, 0.0799)], "middle": [Vector3(0.1181, 0.0000, 0.0000), Vector3(0.1446, -0.0084, 0.0177), Vector3(0.1522, -0.0169, 0.0423), Vector3(0.1511, -0.0239, 0.0735)], "ring": [Vector3(0.1155, -0.0286, 0.0095), Vector3(0.1437, -0.0346, 0.0153), Vector3(0.1511, -0.0410, 0.0384), Vector3(0.1552, -0.0467, 0.0670)], "pink": [Vector3(0.0983, -0.0542, 0.0154), Vector3(0.1165, -0.0598, 0.0185), Vector3(0.1348, -0.0634, 0.0220), Vector3(0.1532, -0.0676, 0.0280)]},
	"top": {"thumb": [Vector3(0.0300, -0.0034, 0.0255), Vector3(0.0646, 0.0246, 0.0484), Vector3(0.0897, 0.0363, 0.0608), Vector3(0.1106, 0.0527, 0.0756)], "point": [Vector3(0.1193, 0.0219, 0.0149), Vector3(0.1465, 0.0175, 0.0283), Vector3(0.1610, 0.0130, 0.0447), Vector3(0.1773, 0.0056, 0.0651)], "middle": [Vector3(0.1181, -0.0000, 0.0000), Vector3(0.1407, -0.0071, 0.0229), Vector3(0.1545, -0.0130, 0.0455), Vector3(0.1666, -0.0179, 0.0748)], "ring": [Vector3(0.1156, -0.0282, 0.0083), Vector3(0.1385, -0.0350, 0.0254), Vector3(0.1501, -0.0409, 0.0469), Vector3(0.1640, -0.0467, 0.0722)], "pink": [Vector3(0.0988, -0.0540, 0.0149), Vector3(0.1153, -0.0599, 0.0228), Vector3(0.1292, -0.0633, 0.0353), Vector3(0.1400, -0.0665, 0.0516)]}}
const PISTOL_THUMB := [Vector3(0.03, -0.001, 0.026), Vector3(0.058, 0.022, 0.042), Vector3(0.085, 0.04, 0.046), Vector3(0.112, 0.055, 0.046)]
const SUPPORT_THUMB := [Vector3(0.03, -0.001, 0.026), Vector3(0.058, 0.012, 0.04), Vector3(0.085, 0.019, 0.045), Vector3(0.112, 0.024, 0.046)]
const PISTOL_POINT := [Vector3(0.1193, 0.0231, 0.013), Vector3(0.142, 0.045, 0.02), Vector3(0.158, 0.062, 0.03), Vector3(0.168, 0.072, 0.045)]
## Where the shoulder sits from the palm, and which way the elbow points, in the gun's own frame (x right, y up,
## z back), with the hand's frame there: from the same.
const REACH := {
	"grip": {"S": Vector3(0.0311, 0.0412, 0.5740), "pole": Vector3(0.0794, -0.0591, -0.0238), "f": Vector3(0.0574, -0.0087, -0.9983), "a": Vector3(0.1373, 0.9905, -0.0008)},
	"fore": {"S": Vector3(-0.1263, -0.1095, 0.5272), "pole": Vector3(-0.0768, -0.0826, -0.0590), "f": Vector3(0.3418, 0.2206, -0.9135), "a": Vector3(-0.3455, 0.9335, 0.0962)},
	"mag": {"S": Vector3(0.1342, 0.1788, 0.4492), "pole": Vector3(-0.0495, -0.1529, 0.0480), "f": Vector3(-0.2587, -0.2757, -0.9258), "a": Vector3(-0.9614, -0.0194, 0.2744)},
	"top": {"S": Vector3(-0.1623, -0.2513, 0.4005), "pole": Vector3(-0.1384, -0.0135, -0.0828), "f": Vector3(0.6665, 0.6303, -0.3980), "a": Vector3(0.0557, 0.4904, 0.8697)},
	"lgrip": {"S": Vector3(-0.1263, -0.1095, 0.5272), "pole": Vector3(-0.0768, -0.0826, -0.0590), "f": Vector3(0.3418, 0.2206, -0.9135), "a": Vector3(-0.3455, 0.9335, 0.0962)}}

## How far out to the side of the eye a shoulder must stay (the arm would otherwise pass across the eye)
const SHOULDER_OUT := 0.2
## Places a shoulder may go, tried in turn (for the right; mirrored for the left), when the reference's own
## would leave the sleeve's cut end in sight: back and out, then lower and lower as the hand reaches further
const SHOULDER_HOMES := [Vector3(0.24, -0.28, 0.15), Vector3(0.22, -0.42, 0.0), Vector3(0.2, -0.55, -0.12),
	Vector3(0.16, -0.7, -0.25), Vector3(0.1, -0.85, -0.35)]

var arms: Arms
var _model: Node3D
var _sk: Skeleton3D
var _side := {}   ## "R"/"L" -> {arm, elbow, wrist, fingers: [[bone, joint, finger]], rest frames}
var debug_pose := ""   ## the probe's own pose, when no one holds the weapon


func _ready() -> void:
	process_priority = 10   # after the weapon has placed itself this frame
	if not ResourceLoader.exists(PATH):
		return
	_model = (load(PATH) as PackedScene).instantiate()
	add_child(_model)
	_model.rotation = Vector3(0, PI, 0)
	_model.scale = Vector3.ONE * SCALE
	_model.position = OFFSET
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.extra_cull_margin = 2.0   # the posed arms reach well past the model's own resting bounds
	var found := _model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	_sk = found[0]
	for s in ["R", "L"]:
		_side[s] = _learn(s)


## The rest pose of one arm: its bones, lengths, and the hand's own frame (forward, knuckle line, palm).
func _learn(s: String) -> Dictionary:
	var d := {}
	var names := {}
	for i in _sk.get_bone_count():
		var nm := _sk.get_bone_name(i)
		if nm.begins_with(s + "_"):
			names[nm.get_slice("_", 1)] = i
	d.arm = names["arm"]
	d.elbow = names["elbow"]
	d.wrist = names["wrist"]
	var g := func(b: int) -> Transform3D: return _sk.get_bone_global_rest(b)
	var S: Vector3 = g.call(d.arm).origin
	var E: Vector3 = g.call(d.elbow).origin
	var W: Vector3 = g.call(d.wrist).origin
	d.l1 = S.distance_to(E)
	d.l2 = E.distance_to(W)
	d.S = S
	d.E = E
	d.W = W
	d.A = g.call(d.arm).basis.orthonormalized()
	d.El = g.call(d.elbow).basis.orthonormalized()
	d.Wb = g.call(d.wrist).basis.orthonormalized()
	var mid: Vector3 = g.call(names["middle1"]).origin
	var idx: Vector3 = g.call(names["point1"]).origin
	var pin: Vector3 = g.call(names["pink1"]).origin
	var f := (mid - W).normalized()
	var a := (idx - pin).normalized()
	d.H = _frame(f, a, s)
	# The palm's middle, a little toward the palm from between the wrist and the knuckles
	var palm: Vector3 = W.lerp(mid, 0.55) + (d.H as Basis).z * 2.0
	d.palm = (d.Wb as Basis).inverse() * (palm - W)
	d.chains = {}
	for fname in ["thumb", "point", "middle", "ring", "pink"]:
		var ch := []
		for j in [1, 2, 3, 4]:
			ch.append(names.get("%s%d" % [fname, j], -1))
		if not ch.has(-1):
			d.chains[fname] = ch
	d.fingers = []
	for fname in ["thumb", "point", "middle", "ring", "pink"]:
		for j in [1, 2, 3]:
			var key := "%s%d" % [fname, j]
			if names.has(key):
				var b: int = names[key]
				d.fingers.append([b, j, fname, _sk.get_bone_rest(b).basis.get_rotation_quaternion(), g.call(b).basis.orthonormalized()])
	return d


## A hand's frame from where its fingers point (wrist to knuckles) and its knuckle line (little finger to
## first): x forward, y the knuckle line, z out of the palm.
static func _frame(f: Vector3, a: Vector3, s: String) -> Basis:
	f = f.normalized()
	a = (a - f * a.dot(f)).normalized()
	var n := a.cross(f) if s == "R" else f.cross(a)
	return Basis(f, a, n)


func _process(_delta: float) -> void:
	if arms == null:
		return
	arms._rig_sync()
	if _sk == null or not (SHOWN or debug_pose != ""):
		visible = false
		return
	var p := arms.hand_pose() if debug_pose == "" else arms.hand_pose(debug_pose)
	visible = not p.is_empty()
	if not visible:
		return
	for sd in ["R", "L"]:
		_reach(sd, p[sd])
		if (p[sd] as Dictionary).has("shape_pts"):
			_shape(sd, p[sd].shape_pts)
		elif (p[sd] as Dictionary).get("shape", "") in ["pistol", "support"]:
			# A side arm's grip, both hands: as a long gun's, but the thumbs laid forward along the frame
			var sh: Dictionary = SHAPES.grip.duplicate()
			sh.thumb = PISTOL_THUMB if p[sd].shape == "pistol" else SUPPORT_THUMB
			if p[sd].shape == "pistol":
				sh.point = PISTOL_POINT   # the trigger finger up in the guard
			_shape(sd, sh)
		elif (p[sd] as Dictionary).has("shape") and SHAPES.has(p[sd].shape):
			_shape(sd, SHAPES[p[sd].shape])
		else:
			_curl(sd, p[sd])


## Brings one hand to its place: p.at is where the palm's middle goes, p.f and p.a the hand's frame
## (all in the world), and p.pole roughly where the elbow should point.
func _reach(s: String, p: Dictionary) -> void:
	var d: Dictionary = _side[s]
	var inv := _sk.global_transform.affine_inverse()
	var rot := inv.basis.orthonormalized()
	var H: Basis = _frame(rot * (p.f as Vector3), rot * (p.a as Vector3), s)
	var Wt: Basis = H * (d.H as Basis).inverse() * (d.Wb as Basis)
	var T: Vector3 = inv * (p.at as Vector3) - Wt * (d.palm as Vector3)
	var S: Vector3 = inv * (get_parent().global_transform * (p.get("sh", SHOULDER[s]) as Vector3)) if get_parent() is Node3D else d.S
	var pole_w: Vector3 = p.get("pole", Vector3.DOWN)
	if p.has("gb") or p.has("S"):
		# Held as the reference holds it: the shoulder well back along the gun, the elbow out and down
		var rk: Dictionary = REACH.get(p.get("reach", p.get("shape", "grip")), REACH.grip)
		var gb: Basis = p.get("gb", Basis())
		var Sw: Vector3 = p.S if p.has("S") else (p.at as Vector3) + gb * (rk.S as Vector3)
		if get_parent() is Node3D:
			# Never past the eye: the arm runs back beside and below the head, as with a gun brought up to aim
			var cam: Transform3D = get_parent().global_transform
			var Sc: Vector3 = cam.affine_inverse() * Sw
			var hand_c: Vector3 = cam.affine_inverse() * (p.at as Vector3)
			var reach: float = (float(d.l1) + float(d.l2)) * SCALE * 0.97
			# The reference's shoulder if it is out of sight and in reach, else the first of a few places
			# further back, out and down that is: the sleeve's cut end must never show
			var side := 1.0 if s == "R" else -1.0
			var tries: Array = [Sc]
			for h in SHOULDER_HOMES:
				tries.append(Vector3((h as Vector3).x * side, (h as Vector3).y, (h as Vector3).z))
			var best := -INF
			for k in tries.size():
				var c: Vector3 = tries[k]
				if k == 0:
					c.x = maxf(c.x, SHOULDER_OUT) if s == "R" else minf(c.x, -SHOULDER_OUT)
				if c.distance_to(hand_c) > reach:
					c = hand_c + (c - hand_c).normalized() * reach
				if _hidden(c):
					Sc = c
					break
				# None out of sight yet: keep the one furthest below the foot of the view
				var below := -c.y - maxf(-c.z, 0.0) * 1.25
				if below > best:
					best = below
					Sc = c
			Sw = cam * Sc
		S = inv * Sw
		pole_w = p.pole if p.has("S") else gb * (rk.pole as Vector3)
	var root := _sk.get_bone_parent(d.arm)
	var Pt: Transform3D = _sk.get_bone_global_pose(root) if root >= 0 else Transform3D()
	_sk.set_bone_pose_position(d.arm, Pt.affine_inverse() * S)
	var l1: float = d.l1
	var l2: float = d.l2
	var to := T - S
	var dist := clampf(to.length(), absf(l1 - l2) + 0.01, (l1 + l2) * 0.999)
	var dir := to.normalized()
	var pole: Vector3 = rot * pole_w
	pole = (pole - dir * pole.dot(dir))
	if pole.length() < 0.001:
		pole = (d.E - d.S - dir * (d.E - d.S).dot(dir))
	pole = pole.normalized()
	var x := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var E := S + dir * x + pole * h
	var Wp := S + dir * dist
	# Rest frames of each bone: along it, and toward the bend
	var r_up: Vector3 = (d.E - d.S).normalized()
	var r_lo: Vector3 = (d.W - d.E).normalized()
	var r_bend := r_up.cross(r_lo)
	if r_bend.length() < 0.001:
		r_bend = Vector3.UP.cross(r_up)
	var n_up := (E - S).normalized()
	var n_lo := (Wp - E).normalized()
	# The bend's axis from the pole, not from the bones: steady even when the arm is all but straight
	var n_bend := pole.cross(dir)
	var A: Basis = _turn(r_up, r_bend, n_up, n_bend) * (d.A as Basis)
	var El: Basis = _turn(r_lo, r_bend, n_lo, n_bend) * (d.El as Basis)
	# The forearm turns with the hand, as a real one does: the turn is taken along the forearm, not wrung
	# out at the wrist (that pinches the wrist thin, like a sweet's wrapper)
	var q := (El.inverse() * Wt).get_rotation_quaternion()
	var ax_l := (El.inverse() * n_lo).normalized()
	var tw := 2.0 * atan2(Vector3(q.x, q.y, q.z).dot(ax_l), q.w)
	tw = wrapf(tw, -PI, PI)
	El = Basis(n_lo, tw * TWIST_SHARE) * El
	var Pb: Basis = Pt.basis.orthonormalized()
	_sk.set_bone_pose_rotation(d.arm, (Pb.inverse() * A).get_rotation_quaternion())
	_sk.set_bone_pose_rotation(d.elbow, (A.inverse() * El).get_rotation_quaternion())
	_sk.set_bone_pose_rotation(d.wrist, (El.inverse() * Wt).get_rotation_quaternion())


## Whether a shoulder (seen from the eye) is out of sight: behind the eye, or well below the foot of the view.
## How much of the hand's turn the forearm takes.
const TWIST_SHARE := 0.8


static func _hidden(c: Vector3) -> bool:
	if c.z > -0.02 and c.y < -0.15:
		return true
	return c.z < 0.0 and -c.y > -c.z * 1.25 + 0.04


## The turn that carries the frame (u, v) onto (u2, v2).
static func _turn(u: Vector3, v: Vector3, u2: Vector3, v2: Vector3) -> Basis:
	var a := _ortho(u, v)
	var b := _ortho(u2, v2)
	return b * a.inverse()


static func _ortho(u: Vector3, v: Vector3) -> Basis:
	u = u.normalized()
	v = (v - u * v.dot(u)).normalized()
	return Basis(u, v, u.cross(v))


## Bends each finger joint by joint so it runs as the reference hand's does, in the hand's own frame.
func _shape(s: String, shape: Dictionary) -> void:
	var d: Dictionary = _side[s]
	var g := func(b: int) -> Vector3: return _sk.get_bone_global_pose(b).origin
	var w: Vector3 = g.call(d.wrist)
	var f: Vector3 = (g.call(d.chains.middle[0]) as Vector3) - w
	var a: Vector3 = (g.call(d.chains.point[0]) as Vector3) - (g.call(d.chains.pink[0]) as Vector3)
	var H := _frame(f, a, s)
	for fname in d.chains:
		if not shape.has(fname):
			continue
		var ch: Array = d.chains[fname]
		var pts: Array = shape[fname]
		for k in 3:
			var b: int = ch[k]
			var child: int = ch[k + 1]
			var want: Vector3 = H * ((pts[k + 1] as Vector3) - (pts[k] as Vector3))
			var par := _sk.get_bone_parent(b)
			var Pg: Basis = _sk.get_bone_global_pose(par).basis if par >= 0 else Basis()
			var G0: Basis = Pg * _sk.get_bone_rest(b).basis
			var u: Vector3 = G0 * _sk.get_bone_rest(child).origin
			if u.length() < 0.0001 or want.length() < 0.0001:
				continue
			var q := Quaternion(u.normalized(), want.normalized())
			var G := Basis(q) * G0
			_sk.set_bone_pose_rotation(b, (Pg.inverse() * G).get_rotation_quaternion())


## Curls each finger by its joint's share of p.curl {finger: [first, second, third joint] in degrees}.
func _curl(s: String, p: Dictionary) -> void:
	var d: Dictionary = _side[s]
	var H: Basis = d.H
	var axis: Vector3 = H.x.cross(H.z)   # about the knuckle line, so the tips go toward the palm
	var thumb_axis: Vector3 = (H.x * 0.6 + axis * 0.4).normalized()   # the thumb folds across the palm
	var curl: Dictionary = p.get("curl", {})
	for fb in d.fingers:
		var b: int = fb[0]
		var j: int = fb[1]
		var fname: String = fb[2]
		var rest_q: Quaternion = fb[3]
		var rest_g: Basis = fb[4]
		var angs: Array = curl.get(fname, [0, 0, 0])
		var ang := deg_to_rad(float(angs[j - 1]))
		var ax: Vector3 = rest_g.inverse() * (thumb_axis if fname == "thumb" else axis)
		_sk.set_bone_pose_rotation(b, rest_q * Quaternion(ax.normalized(), ang))
