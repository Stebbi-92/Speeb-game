extends SceneTree
## Bakes walk, run and idle clips for the Harrow (its man's body walks; the legs on its back keep their own
## stirring, taken from the model's own clip) from Nerd Survivor's animations. Made from bake_draugr_moves.gd.
## Only the source's bones are read; its mesh is never used. Run:
##   godot --headless --path . -s tools/bake_draugr_moves.gd   (env SRC=<nerd_survivor.glb>, OUT=res://...res)
## How: each limb bone of the draugr is turned so it points where the donor's matching bone points (in a
## shared character frame), keeping the draugr's own bone twist; spine, hips, head and feet take the donor's
## world rotation away from its rest; the draugr's hands and feet are IK targets (not children of its arms
## and legs), so they are carried to the end of the baked forearm and shin.

const TGT := "res://assets/models/foes/monster_spider/monster_spider.glb"
const OWN := "Armature_001Action"   # the model's own clip: its back legs stirring
const FPS := 30.0
const PELVIS_UP := 0.0

# target bone -> [mode, source bone(s)]
# "dir": point the bone from its head toward the joint J (target) as the donor points from a to b
# "rot": world rotation delta of the donor bone from its rest
var MAP := {}
var HIPS := ""
var FOOT_L := ""
var FOOT_R := ""
var own: Animation = null   # the back legs' own stirring
var own_tracks := {}   # bone -> [position track or -1, rotation track or -1]

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
	if i < 0:
		# by the start of its name (the glb adds a number: mixamorig_LeftArm_40)
		for k in tsk.get_bone_count():
			var bn := tsk.get_bone_name(k)
			if bn.begins_with(n + "_") and bn.substr(n.length() + 1).is_valid_int():
				return k
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
			if tsk.get_bone_name(x).begins_with("ArmIK.") or tsk.get_bone_name(x).begins_with("LegIK."):
				late.append(b)
				order.erase(b)
				break
			x = tsk.get_bone_parent(x)
	order.append_array(late)
	_setup_map()
	HIPS = tsk.get_bone_name(tb("mixamorig_Hips"))
	FOOT_L = tsk.get_bone_name(tb("mixamorig_LeftFoot"))
	FOOT_R = tsk.get_bone_name(tb("mixamorig_RightFoot"))
	var tap0: AnimationPlayer = troot.find_children("*", "AnimationPlayer", true, false)[0]
	own = tap0.get_animation(OWN)
	for ti in own.get_track_count():
		var bn := str(own.track_get_path(ti).get_concatenated_subnames())
		if bn.begins_with("Bone"):
			var bi := tsk.find_bone(bn)
			if bi < 0:
				continue
			if not own_tracks.has(bi):
				own_tracks[bi] = [-1, -1]
			if own.track_get_type(ti) == Animation.TYPE_POSITION_3D:
				own_tracks[bi][0] = ti
			elif own.track_get_type(ti) == Animation.TYPE_ROTATION_3D:
				own_tracks[bi][1] = ti
	print("OWN back-leg bones ", own_tracks.size())
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
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "res://assets/models/foes/monster_spider/harrow_moves.res"
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
	var R := "mixamorig_"
	MAP = {}
	for pair in [["Hips", "Spine_1_02"], ["Spine", "Spine_3_04"], ["Spine1", "Spine_3_04"], ["Spine2", "Spine_4_05"], ["Neck", "Spine_5_06"], ["Head", "Head_07"]]:
		MAP[tsk.get_bone_name(tb(R + pair[0]))] = ["rot", pair[1]] if pair[0] != "Spine1" else ["none"]
	for sd in [["Left", "L", ["021", "022", "023", "024"], ["042", "043", "044", "045"]], ["Right", "R", ["08", "09", "010", "011"], ["038", "039", "040", "041"]]]:
		var S: String = sd[0]
		var a: Array = sd[2]
		var l: Array = sd[3]
		var t := sd[1] as String
		MAP[tsk.get_bone_name(tb(R + S + "Arm"))] = ["dir", "Arm_2_%s_%s" % [t, a[1]], "Arm_3_%s_%s" % [t, a[2]], tsk.get_bone_name(tb(R + S + "ForeArm"))]
		MAP[tsk.get_bone_name(tb(R + S + "ForeArm"))] = ["dir", "Arm_3_%s_%s" % [t, a[2]], "Hand_1_%s_%s" % [t, a[3]], tsk.get_bone_name(tb(R + S + "Hand"))]
		MAP[tsk.get_bone_name(tb(R + S + "UpLeg"))] = ["dir", "Leg_1_%s_%s" % [t, l[0]], "Leg_2_%s_%s" % [t, l[1]], tsk.get_bone_name(tb(R + S + "Leg"))]
		MAP[tsk.get_bone_name(tb(R + S + "Leg"))] = ["dir", "Leg_2_%s_%s" % [t, l[1]], "Leg_3_%s_%s" % [t, l[2]], tsk.get_bone_name(tb(R + S + "Foot"))]
		MAP[tsk.get_bone_name(tb(R + S + "Foot"))] = ["rot", "Leg_3_%s_%s" % [t, l[2]]]
		MAP[tsk.get_bone_name(tb(R + S + "ToeBase"))] = ["rot", "Leg_4_%s_%s" % [t, l[3]]]
	print("MAP ", MAP)
	# The shared frame: left (from right hip to left hip) and up (hips to head), each at rest
	var sf := _frame(_sglob(sb("Leg_1_L_042"), true).origin - _sglob(sb("Leg_1_R_038"), true).origin,
		_sglob(sb("Head_07"), true).origin - _sglob(sb("Spine_1_02"), true).origin)
	var tf := _frame(bindG[tb("mixamorig_LeftUpLeg")].origin - bindG[tb("mixamorig_RightUpLeg")].origin,
		bindG[tb("mixamorig_Head")].origin - bindG[tb("mixamorig_Hips")].origin)
	M = tf * sf.inverse()
	# Hip heights over the feet, for the hips' bob and sway
	var sh := _sglob(sb("Leg_1_L_042"), true).origin.y - _sglob(sb("Leg_3_L_044"), true).origin.y
	var th := (bindG[tb("mixamorig_LeftUpLeg")] as Transform3D).origin.y - (bindG[tb("mixamorig_LeftFoot")] as Transform3D).origin.y
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
			if own_tracks.has(b):
				var ot: Array = own_tracks[b]
				var ttt := fmod(t, own.length)
				var lp := tsk.get_bone_rest(b).origin if int(ot[0]) < 0 else own.position_track_interpolate(int(ot[0]), ttt)
				var lr := tsk.get_bone_rest(b).basis.get_rotation_quaternion() if int(ot[1]) < 0 else own.rotation_track_interpolate(int(ot[1]), ttt)
				g = pg * Transform3D(Basis(lr), lp)
			if MAP.has(nm) and str(MAP[nm][0]) == "none":
				pass
			elif MAP.has(nm):
				var mp: Array = MAP[nm]
				match str(mp[0]):
					"rot":
						var s := sb(mp[1])
						var d := M * (_sglob(s, false).basis.orthonormalized() * _sglob(s, true).basis.orthonormalized().inverse()) * M.inverse()
						g.basis = d * (bindG[b] as Transform3D).basis
						if nm == HIPS:
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
			if nm == FOOT_L or nm == FOOT_R:
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
		var lo := FOOT_L if (by[ts[i]][FOOT_L] as Vector3).y < (by[ts[i]][FOOT_R] as Vector3).y else FOOT_R
		vs.append(-((by[ts[i]][lo] as Vector3).z - (by[ts[i - 1]][lo] as Vector3).z) / (ts[i] - ts[i - 1]))
	vs.sort()
	print("PACE ", clip, " median back-slide=", vs[vs.size() / 2] if not vs.is_empty() else 0.0, " units/s")
	return a
