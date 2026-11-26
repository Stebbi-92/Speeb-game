class_name Person
extends Node3D
## A real body for the people of the waste, in place of a Figure's plain shapes: one of Humans of the World's
## PS2-style men and women (CC-BY 4.0, see CREDITS.md), split and mended by tools/make_people.gd. They stand,
## walk, run, talk, wave and work by Nerd Survivor's moves, baked onto their bones (tools/make_people.sh).
## Faces +Z, feet at 0, like a Figure. Its owner sets pace (metres a second over the ground) and talking.

const DIR := "res://assets/models/people/"
## [pair, the skins of a look it suits (Figure.SKINS)]
const PAIRS := [["nordic", [0, 1]], ["amerindian", [2, 3]], ["tamil", [3, 4]], ["senegalese", [4, 5]]]
const TALL := {"m": 1.78, "f": 1.66}
const WALK_PACE := 1.15   ## metres a second the baked walk covers at its own speed, at full height
const RUN_PACE := 3.0
const NEAR := 70.0        ## beyond this it holds still: no one sees a stride that far off

var key := ""             ## "<pair>_<m|f>"
var pace := 0.0
var seated := false
var talking := false
var hand_r: Node3D        ## where a held thing hangs, kept at the right hand

var _m: Node3D
var _sk: Skeleton3D
var _ap: AnimationPlayer
var _hand := -1
var _clip := ""
var _k := 1.0
var _far_t := 0.0
var _far := false
var _gesture_t := 0.0
var _rng := RandomNumberGenerator.new()
static var _fit := {}     ## key -> [scale, turn, lift, {way: lift}], measured once from the rest and its moves
var _s := 1.0             ## its scale


## The body that suits a look: its skin picks the people, and the seed whether a man or a woman.
static func pick(look: Dictionary, seed: int) -> String:
	var skin := int(look.get("skin", 1))
	var fits := []
	for p in PAIRS:
		if skin in p[1]:
			fits.append(p[0])
	if fits.is_empty():
		fits = [PAIRS[0][0]]
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return "%s_%s" % [fits[r.randi() % fits.size()], "m" if r.randf() < 0.55 else "f"]


static func can(k: String) -> bool:
	return ResourceLoader.exists(DIR + k + ".scn") and ResourceLoader.exists(DIR + k + "_moves.res")


func setup(k: String, seed: int, build := 1) -> Person:
	key = k
	_rng.seed = seed
	_k = [0.96, 1.0, 1.04][clampi(build, 0, 2)] * _rng.randf_range(0.97, 1.03)
	return self


## Built only once someone comes near: a town's people far off cost nothing, and the land loads sooner
const BUILD_AT := 170.0
var _built := false
var _wait_t := 0.0


func _ready() -> void:
	hand_r = Node3D.new()
	add_child(hand_r)
	hand_r.position.y = 0.8
	if _cam_dist() > BUILD_AT:
		return
	_build()


func _cam_dist() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position.distance_to(global_position) if cam else 0.0


func _build() -> void:
	_built = true
	_m = (load(DIR + key + ".scn") as PackedScene).instantiate()
	add_child(_m)
	_sk = _m.find_children("*", "Skeleton3D", true, false)[0]
	_ap = AnimationPlayer.new()
	_m.add_child(_ap)
	_ap.add_animation_library("moves", load(DIR + key + "_moves.res"))
	for a in ["Talk", "Wave"]:
		_ap.get_animation("moves/" + a).loop_mode = Animation.LOOP_NONE
	for mi in _m.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		_dust(mm)
		mm.visibility_range_end = 160.0
		mm.visibility_range_end_margin = 10.0
		mm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if not _fit.has(key):
		_fit[key] = _measure()
	var f: Array = _fit[key]
	var s: float = float(f[0]) * TALL[key.right(1)] * _k
	_m.scale = Vector3.ONE * s
	_m.rotation.y = float(f[1])
	_m.position.y = float(f[2]) * s
	_s = s
	_hand = _bone("RightHand")
	_play("Idle", 0.0)
	_ap.seek(_rng.randf() * 3.0, true)
	if seated:
		_sit()


## The waste's ash on their clothes and skin: a little duller and rougher than they were made (shared by all).
static var _dusted := {}


func _dust(mm: MeshInstance3D) -> void:
	if mm.mesh == null:
		return
	for i in mm.mesh.get_surface_count():
		var m := mm.get_active_material(i)
		if not m is StandardMaterial3D:
			continue
		var id := m.get_rid()
		if not _dusted.has(id):
			var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
			d.albedo_color = d.albedo_color * Color(0.84, 0.8, 0.74)
			d.roughness = maxf(d.roughness, 0.85)
			d.metallic = 0.0
			_dusted[id] = d
		mm.set_surface_override_material(i, _dusted[id])


## Its height and its turn to face +Z, from its rest, and how far its soles sit under its middle as it stands
## and walks (the baked moves do not carry the hips where the rest has them), at scale 1.
func _measure() -> Array:
	var rel := _m.global_transform.affine_inverse() * _sk.global_transform
	var at := func(n: String) -> Vector3: return rel * _sk.get_bone_global_rest(_bone(n)).origin
	var lo := INF
	for i in _sk.get_bone_count():
		lo = minf(lo, (rel * _sk.get_bone_global_rest(i).origin).y)
	var top: float = (at.call("HeadTop_End") as Vector3).y
	var left: Vector3 = at.call("LeftUpLeg") - at.call("RightUpLeg")
	var up: Vector3 = at.call("Head") - at.call("Hips")
	var fwd := left.cross(up)
	fwd.y = 0.0
	# Its soles in each of its ways: the lowest point of its skin, the middle of a few moments of each (the
	# baked moves hold the hips higher or lower than one another, a run's well up off a stance's)
	var pts := LesserSpeeb._sole_points(_m)
	var to := _m.global_transform.affine_inverse()
	var lifts := {}
	for c in ["Idle", "Walk", "Run", "Stand", "Talk", "Wave"]:
		if pts.is_empty() or not _ap.has_animation("moves/" + c):
			continue
		_ap.play("moves/" + c, 0.0)
		var lows := []
		for i in 6:
			_ap.seek(_ap.get_animation("moves/" + c).length * i / 6.0, true)
			lows.append(LesserSpeeb._sole_low(pts, to))
		lows.sort()
		if lows[3] < INF:
			lifts[c] = -float(lows[3])
	_ap.stop()
	return [1.0 / maxf(top - lo, 0.01), -atan2(fwd.x, fwd.z), float(lifts.get("Idle", -lo)), lifts]


func _bone(n: String) -> int:
	var i := _sk.find_bone(n)
	if i >= 0:
		return i
	for pre in ["", "mixamorig_"]:
		for k in _sk.get_bone_count():
			var bn := _sk.get_bone_name(k)
			if bn.begins_with(pre + n + "_") and bn.substr(pre.length() + n.length() + 1).is_valid_int():
				return k
	return 0


func _play(c: String, blend := 0.3) -> void:
	if c == _clip:
		return
	_clip = c
	_ap.play("moves/" + c, blend)


## Sitting: the walk stops and the legs fold, thighs forward and shins down.
func _sit() -> void:
	_ap.play("moves/Idle")
	_ap.seek(0.5, true)
	_ap.pause()
	for sd in ["Left", "Right"]:
		var th := _bone(sd + "UpLeg")
		var sh := _bone(sd + "Leg")
		_sk.set_bone_pose_rotation(th, _sk.get_bone_pose_rotation(th) * Quaternion(Vector3.RIGHT, -1.45))
		_sk.set_bone_pose_rotation(sh, _sk.get_bone_pose_rotation(sh) * Quaternion(Vector3.RIGHT, 1.5))


func _process(delta: float) -> void:
	if not _built:
		_wait_t -= delta
		if _wait_t <= 0.0:
			_wait_t = 1.0 + _rng.randf() * 0.5
			if _cam_dist() < BUILD_AT:
				_build()
		return
	if seated:
		return
	_far_t -= delta
	if _far_t <= 0.0:
		_far_t = 0.5 + _rng.randf() * 0.2
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		var far := cam != null and cam.global_position.distance_to(global_position) > NEAR
		if far != _far:
			_far = far
			if far:
				_ap.pause()
			else:
				_ap.play()
	if _far:
		return
	# Each step as long as the body's own: the walk (or run) is played as fast as its feet carry it
	var tall: float = TALL[key.right(1)] * _k / 1.75
	var ws := Stride.of(_sk, _ap, "moves/Walk")
	var rs := Stride.of(_sk, _ap, "moves/Run")
	if ws < 0.05:
		ws = WALK_PACE * tall
	if rs < 0.05:
		rs = RUN_PACE * tall
	if pace > ws * 1.7:
		_play("Run")
		_ap.speed_scale = clampf(pace / rs, 0.5, 1.8)
	elif pace > 0.15:
		_play("Walk")
		_ap.speed_scale = clampf(pace / ws, 0.4, 2.2)
	else:
		_ap.speed_scale = 1.0
		_gesture_t -= delta
		if talking and _gesture_t <= 0.0:
			_gesture_t = _rng.randf_range(2.5, 4.0)
			_clip = ""
			_play("Talk" if _rng.randf() < 0.75 else "Wave", 0.25)
		elif _clip in ["Talk", "Wave"] and not _ap.is_playing():
			_play("Idle")
		elif _clip in ["Walk", "Run"]:
			_play("Stand" if _rng.randf() < 0.3 else "Idle")
	# Its soles kept on the ground as it goes from one way to another
	var lifts: Dictionary = _fit[key][3]
	_m.position.y = lerpf(_m.position.y, float(lifts.get(_clip, _fit[key][2])) * _s, minf(1.0, delta * 6.0))
	if hand_r and _hand >= 0:
		hand_r.global_position = _sk.global_transform * _sk.get_bone_global_pose(_hand).origin
