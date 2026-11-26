class_name Slump
extends Node
## A body with bones that came with no fall of its own goes down by them when it dies: the knees give, the
## trunk folds, the head drops and the arms go loose or fly out, the way the last blow drove it. It works on
## any rig whose bones can be told apart by name (Mixamo's, Rigify's, and the waste's other bodies); the
## turns are made in the body's own frame (up from the hips to the head, left from hip to hip), so each rig's
## own bone axes do not matter. Its owner topples the whole body meanwhile (see LesserSpeeb._topple).

## How it falls: "crumple" (the knees go and it folds forward), "back" (thrown back, arms out: a head shot
## or a heavy blow), "twist" (turned by a blow from the side, one knee going first)
const WAYS := ["crumple", "back", "twist"]

var sk: Skeleton3D
var way := "crumple"
var dur := 0.75
var _roles := {}
var _base := {}       ## bone -> its local pose when it died
var _turns := []      ## [bone, axis in the body's frame, full angle]
var _frame := Basis()  ## the body's frame (x left, y up, z forward) in the skeleton's space
var _t := 0.0
var _order := []      ## the bones turned, parents first
var _sink := Vector3.ZERO   ## how far the hips go down, in the skeleton's space
var _hips := -1
var _hips_base := Vector3.ZERO
static var _cache := {}


## The bones of a rig by what they are, or {} when it has no legs and trunk to fall by.
static func roles_of(s: Skeleton3D) -> Dictionary:
	var key := "%d:%s:%s" % [s.get_bone_count(), s.get_bone_name(0), s.get_bone_name(s.get_bone_count() - 1)]
	if _cache.has(key):
		return _cache[key]
	var by := {}
	for i in s.get_bone_count():
		var n := s.get_bone_name(i).to_lower()
		for pre in ["mixamorig_", "mixamorig:", "def-", "org-", "bip001 ", "bip01 "]:
			if n.begins_with(pre):
				n = n.substr(pre.length())
		var re := RegEx.create_from_string("_[0-9]+$")
		while re.search(n):
			n = re.sub(n, "")
		n = n.replace("_rig", "").replace(".x", "")
		n = n.replace(".", "").replace("_", "").replace("-", "").replace(" ", "")
		if not by.has(n):
			by[n] = i
	var want := {
		"hips": ["hips", "pelvis", "hip", "rootm", "cintura", "root"],
		"spine": ["spine", "spine01", "spine1", "spine1m", "barriga"],
		"chest": ["spine2", "chest", "spine03", "upperchest", "spine02", "chestm", "torso", "peito"],
		"head": ["head", "headm", "cabeca"],
		"thigh_l": ["leftupleg", "thighl", "upperlegl", "lthigh", "thighstretchl", "hipl", "legl", "lupperleg"],
		"thigh_r": ["rightupleg", "thighr", "upperlegr", "rthigh", "thighstretchr", "hipr", "legr", "rupperleg"],
		"shin_l": ["leftleg", "shinl", "calfl", "lowerlegl", "lcalf", "legstretchl", "kneel", "leg2l", "legl"],
		"shin_r": ["rightleg", "shinr", "calfr", "lowerlegr", "rcalf", "legstretchr", "kneer", "leg2r", "legr"],
		"arm_l": ["leftarm", "upperarml", "uparml", "lupperarm", "armstretchl", "arm1l", "shoulderl", "braco1l"],
		"arm_r": ["rightarm", "upperarmr", "uparmr", "rupperarm", "armstretchr", "arm1r", "shoulderr", "braco1r"],
		"fore_l": ["leftforearm", "forearml", "lowerarml", "lowarml", "lforearm", "forearmstretchl", "arm2l", "elbowl", "braco2l"],
		"fore_r": ["rightforearm", "forearmr", "lowerarmr", "lowarmr", "rforearm", "forearmstretchr", "arm2r", "elbowr", "braco2r"],
	}
	var out := {}
	for r in want:
		for c in want[r]:
			if by.has(c):
				out[r] = by[c]
				break
	for sd in ["l", "r"]:
		if out.get("thigh_" + sd, -1) == out.get("shin_" + sd, -2):
			out.erase("shin_" + sd)
	for need in ["hips", "head", "thigh_l", "thigh_r", "shin_l", "shin_r"]:
		if not out.has(need):
			out = {}
			break
	_cache[key] = out
	return out


## Starts the fall of this skeleton's body, or returns null when its bones cannot be told apart.
static func start(s: Skeleton3D, how: String, seed: int) -> Slump:
	var r := roles_of(s)
	if r.is_empty():
		return null
	# Only what stands upright on two legs folds this way (not the she-dragon, nor a beast)
	var up := s.get_bone_global_pose(r.head).origin - s.get_bone_global_pose(r.hips).origin
	var world_up := s.global_basis.inverse() * Vector3.UP if s.is_inside_tree() else Vector3.UP
	if up.length() < 1e-5 or up.normalized().dot(world_up.normalized()) < 0.6:
		return null
	# Whatever moved it stops where it was: from here its bones are the fall's
	var top: Node = s.owner if s.owner else s.get_parent()
	for ap in top.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).pause()
	var sl := Slump.new()
	sl.sk = s
	sl.way = how
	sl._roles = r
	s.add_child(sl)
	sl._begin(seed)
	return sl


func _g(b: int) -> Vector3:
	return sk.get_bone_global_pose(b).origin


func _begin(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var R := _roles
	var up := _g(R.head) - _g(R.hips)
	var left := _g(R.thigh_l) - _g(R.thigh_r)
	if up.length() < 1e-5 or left.length() < 1e-5:
		queue_free()
		return
	up = up.normalized()
	left = (left - up * left.dot(up)).normalized()
	_frame = Basis(left, up, left.cross(up))
	# About the body's left: positive pitches what points up forward, and what hangs down back (so a thigh
	# swings forward by a negative turn, and a shin bends back by a positive one)
	var X := Vector3(1, 0, 0)
	var Z := Vector3(0, 0, 1)   # about its forward: positive swings what hangs down out to its left
	var Y := Vector3(0, 1, 0)
	var j := func(a: float) -> float: return a * rng.randf_range(0.8, 1.2)
	var sd := 1.0 if rng.randf() < 0.5 else -1.0
	match way:
		"back":
			dur = 0.6
			_add("thigh_l", X, j.call(-0.25))
			_add("thigh_r", X, j.call(-0.1))
			_add("shin_l", X, j.call(0.5))
			_add("shin_r", X, j.call(0.3))
			_add("spine", X, j.call(-0.35))
			_add("chest", X, j.call(-0.3))
			_add("head", X, j.call(-0.6))
			_add("arm_l", Z, j.call(1.3))
			_add("arm_r", Z, j.call(-1.3))
			_add("arm_l", X, j.call(-0.6))
			_add("arm_r", X, j.call(-0.5))
			_add("fore_l", X, j.call(0.5))
			_add("fore_r", X, j.call(0.7))
		"twist":
			dur = 0.85
			var near := "l" if sd > 0.0 else "r"
			var far := "r" if sd > 0.0 else "l"
			_add("thigh_" + near, X, j.call(-1.1))
			_add("shin_" + near, X, j.call(1.7))
			_add("thigh_" + far, X, j.call(-0.35))
			_add("shin_" + far, X, j.call(0.5))
			_add("spine", Y, j.call(0.45) * sd)
			_add("chest", Y, j.call(0.35) * sd)
			_add("chest", X, j.call(0.3))
			_add("head", Z, j.call(0.5) * sd)
			_add("arm_" + far, Z, j.call(0.9) * (-1.0 if far == "r" else 1.0))
			_add("arm_" + near, X, j.call(-0.5))
			_add("fore_" + far, X, j.call(-0.8))
		_:
			dur = 0.75
			_add("thigh_l", X, j.call(-1.25))
			_add("thigh_r", X, j.call(-1.15))
			_add("shin_l", X, j.call(1.9))
			_add("shin_r", X, j.call(1.8))
			_add("spine", X, j.call(0.35))
			_add("chest", X, j.call(0.3))
			_add("head", X, j.call(0.55))
			_add("head", Z, j.call(0.25) * sd)
			_add("arm_l", X, j.call(-0.5))
			_add("arm_r", X, j.call(-0.6))
			_add("fore_l", X, j.call(-0.6))
			_add("fore_r", X, j.call(-0.5))
	# The hips sink as the knees give: by a share of their height over the lowest foot
	var drop := {"crumple": 0.42, "back": 0.12, "twist": 0.3}.get(way, 0.3) as float
	var foot := minf(_g(R.shin_l).dot(up), _g(R.shin_r).dot(up))
	var shin_len := (_g(R.shin_l) - _g(R.thigh_l)).length()
	_sink = up * -((_g(R.hips).dot(up) - foot) + shin_len) * drop * rng.randf_range(0.85, 1.1)
	_hips = int(R.hips)
	_hips_base = sk.get_bone_pose_position(_hips)
	# Each turned bone's ancestors too, so a parent's new pose reaches its children; parents first
	var seen := {}
	for e in _turns:
		var b: int = e[0]
		while b >= 0 and not seen.has(b):
			seen[b] = true
			_base[b] = sk.get_bone_pose(b)
			b = sk.get_bone_parent(b)
	_order = seen.keys()
	_order.sort_custom(func(a, b): return _depth(a) < _depth(b))


func _depth(b: int) -> int:
	var d := 0
	while b >= 0:
		b = sk.get_bone_parent(b)
		d += 1
	return d


func _add(role: String, axis: Vector3, angle: float) -> void:
	if _roles.has(role):
		_turns.append([int(_roles[role]), axis, angle])


func _process(delta: float) -> void:
	if sk == null or not is_instance_valid(sk):
		queue_free()
		return
	_t = minf(_t + delta, dur)
	var u := _t / dur
	# Fast at first, then settling, a little past and back (the body's weight)
	var e := 1.0 - pow(1.0 - u, 3.0)
	e += sin(u * PI) * 0.08
	var want := {}
	for t in _turns:
		var b: int = t[0]
		var q := Quaternion(_frame * (t[1] as Vector3), float(t[2]) * e)
		want[b] = q * (want.get(b, Quaternion()) as Quaternion)
	# New globals top-down: each turned bone keeps its place under its parent, its trunk-frame turn added
	var G := {}
	for b in _order:
		var p := sk.get_bone_parent(b)
		var pg: Transform3D = G[p] if G.has(p) else (sk.get_bone_global_pose(p) if p >= 0 else Transform3D.IDENTITY)
		var loc: Transform3D = _base[b]
		var g := pg * loc
		if want.has(b):
			g.basis = Basis(want[b]) * g.basis
			# set the local rotation so the global turn holds under the parent's new pose
			var lb := pg.basis.inverse() * g.basis
			sk.set_bone_pose_rotation(b, lb.get_rotation_quaternion())
		else:
			sk.set_bone_pose_rotation(b, loc.basis.get_rotation_quaternion())
		G[b] = g
	if _hips >= 0:
		var p := sk.get_bone_parent(_hips)
		var pb := sk.get_bone_global_pose(p).basis if p >= 0 else Basis()
		sk.set_bone_pose_position(_hips, _hips_base + pb.inverse() * (_sink * e))
	if _t >= dur:
		set_process(false)
