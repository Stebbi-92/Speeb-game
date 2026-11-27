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

var arms: Arms
var _model: Node3D
var _sk: Skeleton3D
var _side := {}   ## "R"/"L" -> {arm, elbow, wrist, fingers: [[bone, joint, finger]], rest frames}
var debug_pose := ""   ## the probe's own pose, when no one holds the weapon
var last_pose := {}
var _held := ""    ## the pose the hands were last brought to (for tools/hand_check.gd)


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
	last_pose = p
	# A new thing in hand (it comes up from below as the last one went): its arms are found afresh, not
	# bent over from the last one's, which may have been a worse fit for it
	var held := "%s/%s" % [arms.guns[arms.cur] if arms.cur < arms.guns.size() else "", arms.blade_out]
	if held != _held:
		_held = held
		_solved.clear()
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
		if (p[sd] as Dictionary).has("thumb_dir"):
			_lay_thumb(sd, p[sd].thumb_dir)


## Brings one hand to its place: p.at is where the palm's middle goes, p.f and p.a the hand's frame
## (all in the world). The arm is then found from the hand back, as a real one is held: the forearm
## leaves the wrist near the hand's own line (the wrist bent only so far, p.wflex toward the palm and
## p.wside toward the thumb, in degrees, being where it rests easiest), and the elbow and shoulder go where
## the forearm's turn stays within what an arm can do, the elbow hangs down and out, the shoulder's cut end
## is out of sight and as near a real shoulder (or p.S, a reference's) as it can be. Both bones keep
## their length: nothing is stretched. The answer is kept and searched about the next frame, so the
## elbow never jumps from one side to the other.
func _reach(s: String, p: Dictionary) -> void:
	var d: Dictionary = _side[s]
	var skg := _sk.global_transform
	var inv := skg.affine_inverse()
	var rot := inv.basis.orthonormalized()
	var H: Basis = _frame(rot * (p.f as Vector3), rot * (p.a as Vector3), s)
	var Wt: Basis = H * (d.H as Basis).inverse() * (d.Wb as Basis)
	var T: Vector3 = inv * (p.at as Vector3) - Wt * (d.palm as Vector3)
	var cam: Transform3D = (get_parent() as Node3D).global_transform if get_parent() is Node3D else Transform3D()
	var to_c := cam.affine_inverse() * skg   # the skeleton's space into the eye's
	var k := to_c.basis.get_scale().x
	var Wc := to_c * T
	var Hc: Basis = to_c.basis.orthonormalized() * H
	var L1: float = float(d.l1) * k
	var L2: float = float(d.l2) * k
	var side := 1.0 if s == "R" else -1.0
	var pref: Vector3 = SHOULDER_REAL[s]
	if p.has("S"):
		pref = cam.affine_inverse() * (p.S as Vector3)
	var fl0: float = deg_to_rad(float(p.get("wflex", WRIST_EASE.x)))
	var sd0: float = deg_to_rad(float(p.get("wside", WRIST_EASE.y)))
	var n_palm := Hc.z
	var last: Dictionary = _solved.get(s, {})
	var full := last.is_empty()
	var best := {"cost": INF}
	if full:
		for fi in 7:
			for si in 3:
				var fl := clampf(fl0 + deg_to_rad(-45.0 + fi * 15.0), -deg_to_rad(WRIST_MAX.x), deg_to_rad(WRIST_MAX.x))
				var sd := clampf(sd0 + deg_to_rad(-14.0 + si * 14.0), -deg_to_rad(WRIST_MAX.y), deg_to_rad(WRIST_MAX.y))
				for dir in _SPHERE:
					_try(best, s, side, Wc, Hc, L1, L2, fl, sd, dir, fl0, sd0, pref, last)
	else:
		for fi in 3:
			for si in 3:
				var fl := clampf(float(last.fl) + deg_to_rad(-5.0 + fi * 5.0), -deg_to_rad(WRIST_MAX.x), deg_to_rad(WRIST_MAX.x))
				var sd := clampf(float(last.sd) + deg_to_rad(-5.0 + si * 5.0), -deg_to_rad(WRIST_MAX.y), deg_to_rad(WRIST_MAX.y))
				for j in _NEAR.size():
					var dir: Vector3 = (_turn_to(last.dir) * (_NEAR[j] as Vector3)).normalized()
					_try(best, s, side, Wc, Hc, L1, L2, fl, sd, dir, fl0, sd0, pref, last)
		if float(best.cost) > STUCK:
			# Stuck where no near arm will do (a shoulder in sight, a forearm wrung): look everywhere, and
			# take what is found only if it is much the better
			var wide := {"cost": INF}
			for fi in 7:
				for si in 3:
					var fl := clampf(fl0 + deg_to_rad(-45.0 + fi * 15.0), -deg_to_rad(WRIST_MAX.x), deg_to_rad(WRIST_MAX.x))
					var sd := clampf(sd0 + deg_to_rad(-14.0 + si * 14.0), -deg_to_rad(WRIST_MAX.y), deg_to_rad(WRIST_MAX.y))
					for dir in _SPHERE:
						_try(wide, s, side, Wc, Hc, L1, L2, fl, sd, dir, fl0, sd0, pref, last)
			if float(wide.cost) < float(best.cost) - STUCK * 0.5:
				best = wide
	best.W = Wc
	best.n = n_palm
	if explain:
		var why := {}
		_try({"cost": INF}, s, side, Wc, Hc, L1, L2, best.fl, best.sd, best.dir, fl0, sd0, pref, last, why)
		why["full"] = full
		why["W"] = Wc
		why["fl"] = rad_to_deg(best.fl)
		why["sd"] = rad_to_deg(best.sd)
		# and what an arm from the true shoulder, the wrist easy, would have cost
		var u0 := (Hc * Vector3(1.0, -tan(sd0), -tan(fl0))).normalized()
		var E0 := Wc - u0 * L2
		var alt := {}
		_try({"cost": INF}, s, side, Wc, Hc, L1, L2, fl0, sd0, (pref - E0).normalized(), fl0, sd0, pref, last, alt)
		for kk in alt:
			why["alt_" + kk] = alt[kk]
		explained[s] = why
	_solved[s] = best
	var c2s := to_c.affine_inverse()
	var S: Vector3 = c2s * (best.S as Vector3)
	var E: Vector3 = c2s * (best.E as Vector3)
	var Wp: Vector3 = T
	var root := _sk.get_bone_parent(d.arm)
	var Pt: Transform3D = _sk.get_bone_global_pose(root) if root >= 0 else Transform3D()
	_sk.set_bone_pose_position(d.arm, Pt.affine_inverse() * S)
	# Rest frames of each bone: along it, and toward the bend
	var r_up: Vector3 = (d.E - d.S).normalized()
	var r_lo: Vector3 = (d.W - d.E).normalized()
	var r_bend := r_up.cross(r_lo)
	if r_bend.length() < 0.001:
		r_bend = Vector3.UP.cross(r_up)
	var n_up := (E - S).normalized()
	var n_lo := (Wp - E).normalized()
	var n_bend := n_up.cross(n_lo)
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


## Where a shoulder truly is, from the eye: a hand far out before the eye pulls it forward, as far as it
## must (see _reach).
const SHOULDER_REAL := {"R": Vector3(0.18, -0.26, 0.08), "L": Vector3(-0.18, -0.26, 0.08)}
## How the wrist rests easiest on a grip (toward the palm, toward the thumb, degrees), and how far it may go
const WRIST_EASE := Vector2(-12.0, -6.0)
const WRIST_MAX := Vector2(65.0, 28.0)
## How far the forearm may turn from thumb-up (palm down +, palm up -), degrees
const PRONATE_MAX := 80.0
const PRONATE_COST := 0.6   ## and how much each degree of it costs: a forearm turned less is kinder
## The elbow's inner angle, at its most open (180 is locked straight)
const INNER_MAX := 168.0
## What an arm may cost before the search looks beyond the last answer
const STUCK := 200.0
## What each degree the elbow swings round from the frame before costs
const ELBOW_STEADY := 4.0
var explain := false   ## keep, in explained, what the arm found last cost and why (for the probe)
var explained := {}
var _solved := {}   ## "R"/"L" -> the last arm found: S, E (in the eye's space), the wrist's bend, the shoulder's direction


## One trial arm: the forearm leaving the wrist bent (fl, sd), the upper arm along dir from the elbow to the
## shoulder. Kept in best if it costs less (see _reach for what is wanted of it).
static func _try(best: Dictionary, s: String, side: float, Wc: Vector3, Hc: Basis, L1: float, L2: float, fl: float,
		sd: float, dir: Vector3, fl0: float, sd0: float, pref: Vector3, last: Dictionary, why = null) -> void:
	var u := (Hc * Vector3(1.0, -tan(sd), -tan(fl))).normalized()   # elbow to wrist
	var E := Wc - u * L2
	var S := E + dir * L1
	var cost := 0.0
	# The elbow's inner angle: neither folded shut nor locked straight
	var inner := rad_to_deg(dir.angle_to(u))
	if inner < 50.0:
		var c_1 := (50.0 - inner) * 4.0
		cost += c_1
		if why != null: why["inner"] = why.get("inner", 0.0) + c_1
	elif inner > INNER_MAX:
		var c_2 := (inner - INNER_MAX) * 4.0
		cost += c_2
		if why != null: why["inner"] = why.get("inner", 0.0) + c_2
	# The forearm's turn
	var kx := (-dir).cross(u)
	if kx.length_squared() < 1e-6:
		return
	kx = kx.normalized()
	var n0 := -kx if s == "R" else kx
	var n := Hc.z - u * Hc.z.dot(u)
	var pro := rad_to_deg(n0.signed_angle_to(n.normalized(), u)) * (-1.0 if s == "R" else 1.0)
	if absf(pro) > PRONATE_MAX:
		var c_3 := (absf(pro) - PRONATE_MAX) * 4.0
		cost += c_3
		if why != null: why["pro_over"] = why.get("pro_over", 0.0) + c_3
	var c_4 := absf(pro) * PRONATE_COST
	cost += c_4
	if why != null: why["pro"] = why.get("pro", 0.0) + c_4
	# The elbow down and out, not raised nor turned in across the body
	var line := (Wc - S).normalized()
	var out := (E - S) - line * (E - S).dot(line)
	if out.length() > 0.01:
		out = out.normalized()
		var up := rad_to_deg(asin(clampf(out.y, -1.0, 1.0)))
		if up > 5.0:
			var c_5 := (up - 5.0) * 2.0
			cost += c_5
			if why != null: why["elbow_up"] = why.get("elbow_up", 0.0) + c_5
		if out.x * side < -0.35:
			var c_6 := (-out.x * side - 0.35) * 80.0
			cost += c_6
			if why != null: why["elbow_in"] = why.get("elbow_in", 0.0) + c_6
	# The shoulder's cut end out of sight, the arm clear of the eye, the shoulder near a real one's place
	if not _hidden(S):
		var c_7 := 2000.0 + (S.y + 0.2) * 100.0
		cost += c_7
		if why != null: why["seen"] = why.get("seen", 0.0) + c_7
	var eye := _seg_point(S, E, Vector3.ZERO)
	if eye < 0.14:
		var c_8 := (0.14 - eye) * 1000.0
		cost += c_8
		if why != null: why["eye"] = why.get("eye", 0.0) + c_8
	if S.x * side < 0.06:
		var c_9 := (0.06 - S.x * side) * 400.0
		cost += c_9
		if why != null: why["across"] = why.get("across", 0.0) + c_9
	elif S.x * side > 0.32:
		var c_10 := (S.x * side - 0.32) * 400.0
		cost += c_10
		if why != null: why["far_out"] = why.get("far_out", 0.0) + c_10
	var c_11 := S.distance_to(pref) * 60.0
	cost += c_11
	if why != null: why["pref"] = why.get("pref", 0.0) + c_11
	# Easy in the wrist, and steady from the frame before
	var c_12 := absf(rad_to_deg(fl - fl0)) * 0.4 + absf(rad_to_deg(sd - sd0)) * 0.8
	cost += c_12
	if why != null: why["wrist"] = why.get("wrist", 0.0) + c_12
	if not last.is_empty():
		var c_13 := S.distance_to(last.S) * 120.0
		if last.has("out") and out.length() > 0.5:
			c_13 += rad_to_deg((last.out as Vector3).angle_to(out)) * ELBOW_STEADY   # and the elbow pointing as it did
		cost += c_13
		if why != null: why["steady"] = why.get("steady", 0.0) + c_13
	if why != null:
		why["pro_deg"] = pro
		why["inner_deg"] = inner
		why["S"] = S
		why["E"] = E
	if cost < float(best.cost):
		best.cost = cost
		best.S = S
		best.E = E
		best.fl = fl
		best.sd = sd
		best.dir = dir
		best.out = out


static func _seg_point(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## The turn that carries the z axis onto dir (for the search about the last answer).
static func _turn_to(dir: Vector3) -> Basis:
	var z := dir.normalized()
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x), z)


## Directions over the whole sphere (for the full search), and a few about +z (for the near one)
static var _SPHERE: Array = _fib(80)
static var _NEAR: Array = _near()


static func _fib(n: int) -> Array:
	var out := []
	for i in n:
		var y := 1.0 - (i + 0.5) * 2.0 / n
		var r := sqrt(1.0 - y * y)
		var th := i * PI * (3.0 - sqrt(5.0))
		out.append(Vector3(cos(th) * r, y, sin(th) * r))
	return out


static func _near() -> Array:
	var out := [Vector3(0, 0, 1)]
	for ring in [0.05, 0.12, 0.22]:
		for i in 6:
			var a: float = i * TAU / 6.0 + float(ring) * 10.0
			out.append(Vector3(cos(a) * float(ring), sin(a) * float(ring), 1.0).normalized())
	return out


## How much of the hand's turn the forearm takes.
const TWIST_SHARE := 0.8


## Whether a shoulder (seen from the eye) is out of sight: behind the eye, or well below the foot of the view.
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


## Lays the thumb out straight along dir (in the world), from its root: a support hand's thumb along the
## frame, where it shows.
func _lay_thumb(s: String, dir: Vector3) -> void:
	var d: Dictionary = _side[s]
	if not d.chains.has("thumb"):
		return
	var want := (_sk.global_transform.basis.inverse() * dir).normalized()
	var ch: Array = d.chains.thumb
	for k in 3:
		var b: int = ch[k]
		var par := _sk.get_bone_parent(b)
		var Pg: Basis = _sk.get_bone_global_pose(par).basis if par >= 0 else Basis()
		var G: Basis = Pg * Basis(_sk.get_bone_pose_rotation(b))
		var u: Vector3 = G * _sk.get_bone_rest(ch[k + 1]).origin
		var to := u.normalized().slerp(want, 0.5) if k == 0 else want
		var q := Quaternion(u.normalized(), to.normalized())
		_sk.set_bone_pose_rotation(b, (Pg.inverse() * (Basis(q) * G)).get_rotation_quaternion())


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
