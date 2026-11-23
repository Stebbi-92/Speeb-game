class_name FPHands
extends Node3D
## One's own two arms on the weapon in hand: the right on the grip with a finger on the trigger, the left
## under the fore-end (or cupping the right on a side arm), and on the magazine, the shell or the pump through
## a reload. "fps arms" (DJMaesen, CC-BY 4.0), posed by hand here: it comes with no motions of its own.
## Each arm is bent by a simple two-bone reach (shoulder, elbow, wrist); the fingers are curled about the
## hand's own knuckle line.

const PATH := "res://assets/models/hands/fps_arms.glb"
const SCALE := 0.0108   ## the model is in centimetres; near life size
## Where the model sits under the eye
const OFFSET := Vector3(0.0, -0.37, -0.02)
## Where each shoulder sits by default, from the eye (a pose may move one: "sh"). They are well forward and
## low, out of sight, as a gun held out before the eye needs: life-length arms would not reach its fore-end.
const SHOULDER := {"R": Vector3(0.19, -0.28, -0.02), "L": Vector3(-0.15, -0.28, -0.08)}

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
	if _sk == null:
		return
	var p := arms.hand_pose() if debug_pose == "" else arms.hand_pose(debug_pose)
	visible = not p.is_empty()
	if not visible:
		return
	_reach("R", p.R)
	_reach("L", p.L)
	_curl("R", p.R)
	_curl("L", p.L)


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
	var root := _sk.get_bone_parent(d.arm)
	var Pt: Transform3D = _sk.get_bone_global_pose(root) if root >= 0 else Transform3D()
	_sk.set_bone_pose_position(d.arm, Pt.affine_inverse() * S)
	var l1: float = d.l1
	var l2: float = d.l2
	var to := T - S
	var dist := clampf(to.length(), absf(l1 - l2) + 0.01, (l1 + l2) * 0.999)
	var dir := to.normalized()
	var pole: Vector3 = rot * (p.pole as Vector3)
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
	var n_bend := n_up.cross(n_lo)
	if n_bend.length() < 0.001:
		n_bend = pole.cross(n_up)
	var A: Basis = _turn(r_up, r_bend, n_up, n_bend) * (d.A as Basis)
	var El: Basis = _turn(r_lo, r_bend, n_lo, n_bend) * (d.El as Basis)
	var Pb: Basis = Pt.basis.orthonormalized()
	_sk.set_bone_pose_rotation(d.arm, (Pb.inverse() * A).get_rotation_quaternion())
	_sk.set_bone_pose_rotation(d.elbow, (A.inverse() * El).get_rotation_quaternion())
	_sk.set_bone_pose_rotation(d.wrist, (El.inverse() * Wt).get_rotation_quaternion())


## The turn that carries the frame (u, v) onto (u2, v2).
static func _turn(u: Vector3, v: Vector3, u2: Vector3, v2: Vector3) -> Basis:
	var a := _ortho(u, v)
	var b := _ortho(u2, v2)
	return b * a.inverse()


static func _ortho(u: Vector3, v: Vector3) -> Basis:
	u = u.normalized()
	v = (v - u * v.dot(u)).normalized()
	return Basis(u, v, u.cross(v))


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
