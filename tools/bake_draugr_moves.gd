extends SceneTree
## Bakes walk, run and idle clips for the draugr (Cursed Undead Soldier Rig) from Nerd Survivor's animations.
## Only the source's bones are read; its mesh is never used. Run:
##   godot --headless --path . -s tools/bake_draugr_moves.gd   (env SRC=<nerd_survivor.glb>, OUT=res://...res)
## How: each limb bone of the draugr is turned so it points where the donor's matching bone points (in a
## shared character frame), keeping the draugr's own bone twist; spine, hips, head and feet take the donor's
## world rotation away from its rest; the draugr's hands and feet are IK targets (not children of its arms
## and legs), so they are carried to the end of the baked forearm and shin.

const TGT := "res://assets/models/foes/draugr/draugr_cursedsoldier.glb"
const FPS := 30.0
const PELVIS_UP := 9.0   # the hips raised, in the glb's own units (about 6 cm in the game), so a planted foot stands on its ground

# target bone -> [mode, source bone(s)]
# "dir": point the bone from its head toward the joint J (target) as the donor points from a to b
# "rot": world rotation delta of the donor bone from its rest
var MAP := {}

var tsk: Skeleton3D
var ssk: Skeleton3D
var troot: Node3D
var sroot: Node3D
var Ct: Transform3D   # target skeleton -> target model
var Cs: Transform3D   # source skeleton -> source model
var M := Basis()      # source model frame -> target model frame
var scale_k := 1.0
var bindG := {}       # target bone -> model-space bind transform
var order: Array = []
var skinned := {}     # bones the skin binds; the rest (the sword's and cloth's holders) keep their own pose


static func chain(n: Node, top: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != top and n != null:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func tb(n: String) -> int:
	var i := tsk.find_bone(n)
	assert(i >= 0, "no target bone " + n)
	return i


func sb(n: String) -> int:
	var i := ssk.find_bone(n)
	assert(i >= 0, "no source bone " + n)
	return i


func _initialize() -> void:
	troot = (load(TGT) as PackedScene).instantiate()
	root.add_child(troot)
	tsk = troot.find_children("*", "Skeleton3D", true, false)[0]
	Ct = chain(tsk, troot)
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(OS.get_environment("SRC"), st)
	sroot = doc.generate_scene(st)
	root.add_child(sroot)
	ssk = sroot.find_children("*", "Skeleton3D", true, false)[0]
	Cs = chain(ssk, sroot)
	# The draugr's bind pose (its rest as skinned), in model space
	for mi in troot.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if mm.skin == null:
			continue
		for i in mm.skin.get_bind_count():
			var b := mm.skin.get_bind_bone(i)
			if b < 0:
				b = tsk.find_bone(mm.skin.get_bind_name(i))
			if b >= 0:
				skinned[b] = true
			if b >= 0 and not bindG.has(b):
				# Its binds carry the armature's scale: taken out, so they are in the skeleton's own units
				var bi := mm.skin.get_bind_pose(i).affine_inverse()
				var sc := bi.basis.x.length()
				bindG[b] = Ct * Transform3D(bi.basis / sc, bi.origin / sc)
	var todo := []
	for i in tsk.get_bone_count():
		if tsk.get_bone_parent(i) < 0:
			todo.append(i)
	while not todo.is_empty():
		var b: int = todo.pop_front()
		order.append(b)
		if not bindG.has(b):
			var p := tsk.get_bone_parent(b)
			bindG[b] = (bindG[p] if p >= 0 else Ct) * tsk.get_bone_rest(b)
		for c in tsk.get_bone_children(b):
			todo.append(c)
	# The IK-driven hands and feet (and what hangs from them) after the arms and legs they follow
	var late := []
	for b in order.duplicate():
		var x: int = b
		while x >= 0:
			if tsk.get_bone_name(x).begins_with("ArmIK") or tsk.get_bone_name(x).begins_with("LegIK"):
				late.append(b)
				order.erase(b)
				break
			x = tsk.get_bone_parent(x)
	order.append_array(late)
	_setup_map()
	var lib := AnimationLibrary.new()
	for pair in [["Walk", "Walk Forward"], ["Run", "Run Forward"], ["Idle", OS.get_environment("IDLE") if OS.get_environment("IDLE") != "" else "Melee Idle"]]:
		lib.add_animation(pair[0], _bake(pair[1]))
	if OS.get_environment("DEBUG") != "":
		for nm in ["Bind", "Rest"]:
			var a := Animation.new()
			a.length = 1.0
			var tap: AnimationPlayer = troot.find_children("*", "AnimationPlayer", true, false)[0]
			var base := str(tap.get_node(tap.root_node).get_path_to(tsk))
			for b in order:
				if not skinned.has(b):
					continue
				var p := tsk.get_bone_parent(b)
				var loc: Transform3D = tsk.get_bone_rest(b) if nm == "Rest" else (bindG[p] if p >= 0 else Ct).affine_inverse() * (bindG[b] as Transform3D)
				var t1 := a.add_track(Animation.TYPE_POSITION_3D)
				a.track_set_path(t1, NodePath("%s:%s" % [base, tsk.get_bone_name(b)]))
				a.position_track_insert_key(t1, 0.0, loc.origin)
				var t2 := a.add_track(Animation.TYPE_ROTATION_3D)
				a.track_set_path(t2, NodePath("%s:%s" % [base, tsk.get_bone_name(b)]))
				a.rotation_track_insert_key(t2, 0.0, loc.basis.get_rotation_quaternion())
			lib.add_animation(nm, a)
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "res://assets/models/foes/draugr/draugr_moves.res"
	print("SAVE ", ResourceSaver.save(lib, out, ResourceSaver.FLAG_COMPRESS))
	quit()


func _trest(b: int) -> Transform3D:
	var t := Transform3D.IDENTITY
	while b >= 0:
		t = tsk.get_bone_rest(b) * t
		b = tsk.get_bone_parent(b)
	return Ct * t


func _frame(lft: Vector3, up: Vector3) -> Basis:
	var u := up.normalized()
	var l := (lft - u * lft.dot(u)).normalized()
	return Basis(l, u, l.cross(u))   # x = left, y = up, z = forward (left x up = forward for a body facing +z)


func _sglob(b: int, rest: bool) -> Transform3D:
	# (built from the local poses: the skeleton's cached global poses lag a seek made off the main loop)
	var t := Transform3D.IDENTITY
	while b >= 0:
		t = (ssk.get_bone_rest(b) if rest else ssk.get_bone_pose(b)) * t
		b = ssk.get_bone_parent(b)
	return Cs * t


func _setup_map() -> void:
	MAP = {
		"Pelvis_52": ["rot", "Spine_1_02"],
		"Spine_13": ["rot", "Spine_3_04"],
		"Torso IK_50": ["rot", "Spine_4_05"],
		"Neck_31": ["rot", "Spine_5_06"],
		"Head IK_48": ["rot", "Head_07"],
		"Shoulder.L_38": ["dir", "Arm_1_L_021", "Arm_2_L_022", "Upper Arm.L_34"],
		"Upper Arm.L_34": ["dir", "Arm_2_L_022", "Arm_3_L_023", "Elbow.L_33"],
		"Elbow.L_33": ["dir", "Arm_3_L_023", "Hand_1_L_024", "Hand.L_68"],
		"Shoulder.R_45": ["dir", "Arm_1_R_08", "Arm_2_R_09", "Upper Arm.R_41"],
		"Upper Arm.R_41": ["dir", "Arm_2_R_09", "Arm_3_R_010", "Elbow.R_40"],
		"Elbow.R_40": ["dir", "Arm_3_R_010", "Hand_1_R_011", "Hand.R_86"],
		"Thigh.L_17": ["dir", "Leg_1_L_042", "Leg_2_L_043", "Knee.L_15"],
		"Knee.L_15": ["dir", "Leg_2_L_043", "Leg_3_L_044", "Foot.L_92"],
		"Thigh.R_25": ["dir", "Leg_1_R_038", "Leg_2_R_039", "Knee.R_23"],
		"Knee.R_23": ["dir", "Leg_2_R_039", "Leg_3_R_040", "Foot.R_89"],
		"ArmIK.l_69": ["follow", "Forearm.L_32"],
		"ArmIK.r_87": ["follow", "Forearm.R_39"],
		"LegIK.l_93": ["foot", "Leg_3_L_044", "Lower Leg.L_14"],
		"LegIK.r_90": ["foot", "Leg_3_R_040", "Lower Leg.R_22"],
		"Toes.L_91": ["rot", "Leg_4_L_045"],
		"Toes.R_88": ["rot", "Leg_4_R_041"],
	}
	# The shared frame: left (from right hip to left hip) and up (hips to head), each at rest
	var sf := _frame(_sglob(sb("Leg_1_L_042"), true).origin - _sglob(sb("Leg_1_R_038"), true).origin,
		_sglob(sb("Head_07"), true).origin - _sglob(sb("Spine_1_02"), true).origin)
	var tf := _frame(bindG[tb("Thigh.L_17")].origin - bindG[tb("Thigh.R_25")].origin,
		bindG[tb("Head IK_48")].origin - bindG[tb("Pelvis_52")].origin)
	M = tf * sf.inverse()
	# Hip heights over the feet, for the hips' bob and sway
	var sh := _sglob(sb("Leg_1_L_042"), true).origin.y - _sglob(sb("Leg_3_L_044"), true).origin.y
	var th := (bindG[tb("Thigh.L_17")] as Transform3D).origin.y - (bindG[tb("Foot.L_92")] as Transform3D).origin.y
	scale_k = th / sh
	print("FRAME src=", sf, " tgt=", tf, " M=", M, " k=", scale_k)


func _bake(clip: String) -> Animation:
	var ap: AnimationPlayer = sroot.find_children("*", "AnimationPlayer", true, false)[0]
	assert(ap.has_animation(clip), "no clip " + clip)
	var src := ap.get_animation(clip)
	var tap: AnimationPlayer = troot.find_children("*", "AnimationPlayer", true, false)[0]
	var base := str(tap.get_node(tap.root_node).get_path_to(tsk))
	var a := Animation.new()
	a.length = src.length
	a.loop_mode = Animation.LOOP_LINEAR
	var pt := {}
	var rt := {}
	for b in order:
		if not skinned.has(b):
			continue
		pt[b] = a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(pt[b], NodePath("%s:%s" % [base, tsk.get_bone_name(b)]))
		rt[b] = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(rt[b], NodePath("%s:%s" % [base, tsk.get_bone_name(b)]))
	# The donor walks in place? Its hips' drift over the clip is taken out
	ap.play(clip)
	ap.seek(0.0, true)
	var h0 := _sglob(sb("Spine_1_02"), false).origin
	ap.seek(src.length, true)
	var h1 := _sglob(sb("Spine_1_02"), false).origin
	var drift := (h1 - h0) / maxf(src.length, 0.001)
	drift.y = 0.0
	print("CLIP ", clip, " len=", src.length, " drift/s=", drift)
	var hips_rest := _sglob(sb("Spine_1_02"), true).origin
	var n := int(ceil(src.length * FPS))
	var feet := []
	for f in n + 1:
		var t := minf(f / FPS, src.length)
		ap.seek(t, true)

		var G := {}
		for b in order:
			var nm := tsk.get_bone_name(b)
			var p := tsk.get_bone_parent(b)
			var pg: Transform3D = G[p] if p >= 0 else Ct
			var pb: Transform3D = bindG[p] if p >= 0 else Ct
			var g: Transform3D = pg * (pb.affine_inverse() * (bindG[b] as Transform3D))
			if MAP.has(nm):
				var mp: Array = MAP[nm]
				match str(mp[0]):
					"rot":
						var s := sb(mp[1])
						var d := M * (_sglob(s, false).basis.orthonormalized() * _sglob(s, true).basis.orthonormalized().inverse()) * M.inverse()
						g.basis = d * (bindG[b] as Transform3D).basis
						if nm == "Pelvis_52":
							var off := _sglob(s, false).origin - hips_rest - drift * t
							# raised a little, so the planted foot stands on the ground the game sets under its rest
							g.origin = (bindG[b] as Transform3D).origin + M * off * scale_k + Vector3(0, PELVIS_UP, 0)
					"dir":
						var want := M * (_sglob(sb(mp[2]), false).origin - _sglob(sb(mp[1]), false).origin)
						var j: Vector3 = (bindG[b] as Transform3D).affine_inverse() * (bindG[tb(mp[3])] as Transform3D).origin
						var have := g.basis * j
						if want.length() > 1e-6 and have.length() > 1e-6:
							g.basis = Basis(Quaternion(have.normalized(), want.normalized())) * g.basis
					"follow":
						var fb := tb(mp[1])
						# The wrist as it is set in the draugr's own standing pose (its rest): the sword held low and forward
						g = G[fb] * (_trest(fb).affine_inverse() * _trest(b))
					"foot":
						var s := sb(mp[1])
						var lb := tb(mp[2])
						var at: Vector3 = (G[lb] as Transform3D) * ((bindG[lb] as Transform3D).affine_inverse() * (bindG[b] as Transform3D).origin)
						var d := M * (_sglob(s, false).basis.orthonormalized() * _sglob(s, true).basis.orthonormalized().inverse()) * M.inverse()
						g = Transform3D(d * (bindG[b] as Transform3D).basis, at)
			G[b] = g
			if not skinned.has(b):
				continue
			var loc: Transform3D = pg.affine_inverse() * g
			if nm == "Foot.L_92" or nm == "Foot.R_89":
				feet.append([t, nm, g.origin])
			a.position_track_insert_key(pt[b], t, loc.origin)
			a.rotation_track_insert_key(rt[b], t, loc.basis.get_rotation_quaternion())
	# The pace its feet keep on the ground: how fast the lower foot slides back, in model units a second
	var by := {}
	for e in feet:
		if not by.has(e[0]):
			by[e[0]] = {}
		by[e[0]][e[1]] = e[2]
	var ts := by.keys()
	ts.sort()
	var vs := []
	for i in range(1, ts.size()):
		var lo := "Foot.L_92" if (by[ts[i]]["Foot.L_92"] as Vector3).y < (by[ts[i]]["Foot.R_89"] as Vector3).y else "Foot.R_89"
		vs.append(-((by[ts[i]][lo] as Vector3).z - (by[ts[i - 1]][lo] as Vector3).z) / (ts[i] - ts[i - 1]))
	vs.sort()
	print("PACE ", clip, " median back-slide=", vs[vs.size() / 2] if not vs.is_empty() else 0.0, " units/s")
	return a
