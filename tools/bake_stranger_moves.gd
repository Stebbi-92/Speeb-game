extends SceneTree
## Bakes walk, run, idle and aiming clips for the man in the coat (Saitam's rig; its own clip is not used)
## from Nerd Survivor's animations. Made from bake_dweller_moves.gd, with the Harrow's bone map (both are
## the same kind of rig). CLIPS=Name=Source clip,... picks what is baked.
## Only the source's bones are read; its mesh is never used. Run:
##   godot --headless --path . -s tools/bake_draugr_moves.gd   (env SRC=<nerd_survivor.glb>, OUT=res://...res)
## How: each limb bone of the draugr is turned so it points where the donor's matching bone points (in a
## shared character frame), keeping the draugr's own bone twist; spine, hips, head and feet take the donor's
## world rotation away from its rest; the draugr's hands and feet are IK targets (not children of its arms
## and legs), so they are carried to the end of the baked forearm and shin.

const TGT_COAT := "res://assets/models/foes/stranger/man_in_coat.glb"
## TGT=<scene> bakes for another Mixamo-named body (PREFIX: its bones' prefix, "mixamorig_" by default). The PS2
## people (tools/make_people.gd) are baked with ONLY_MAPPED=1: only the bones the donor moves get tracks, and the
## rest (their faces' many bones, their fingers) keep their own rest under them
var TGT := OS.get_environment("TGT") if OS.get_environment("TGT") != "" else TGT_COAT
var R := OS.get_environment("PREFIX").strip_edges() if OS.has_environment("PREFIX") else "mixamorig_"
var only_mapped := OS.get_environment("ONLY_MAPPED") != ""
## USE_REST=1: the body's rest is the pose it is drawn in (its binds are in other units and turned about), so
## that is what the donor's moves are laid over
var use_rest := OS.get_environment("USE_REST") != ""
var ALIAS := {}
const OWN := ""
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
	# ALIAS=Hips=hips,Spine1=-,...: a rig that names its bones its own way (the Unlit's soldier); "-" it lacks
	var key := n.substr(R.length()) if R != "" and n.begins_with(R) else n
	if ALIAS.has(key):
		if str(ALIAS[key]) == "-":
			return -1
		n = str(ALIAS[key])
	var i := tsk.find_bone(n)
	if i < 0:
		# by the start of its name (the glb adds a number: mixamorig_LeftArm_40)
		for k in tsk.get_bone_count():
			var bn := tsk.get_bone_name(k)
			if bn.begins_with(n + "_") and bn.substr(n.length() + 1).is_valid_int():
				return k
		# (some of the PS2 people keep the "mixamorig_" their rigging gave their bones)
		if R == "" and not n.begins_with("mixamorig_"):
			for k in tsk.get_bone_count():
				var bn := tsk.get_bone_name(k)
				if bn.begins_with("mixamorig_" + n + "_") and bn.substr(n.length() + 11).is_valid_int():
					return k
	assert(i >= 0, "no target bone " + n)
	return i


func sb(n: String) -> int:
	var i := ssk.find_bone(n)
	assert(i >= 0, "no source bone " + n)
	return i


func _initialize() -> void:
	for kv in OS.get_environment("ALIAS").split(",", false):
		ALIAS[kv.get_slice("=", 0)] = kv.get_slice("=", 1)
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
			if b >= 0 and not bindG.has(b) and not use_rest:
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
	HIPS = tsk.get_bone_name(tb(R + "Hips"))
	FOOT_L = tsk.get_bone_name(tb(R + "LeftFoot"))
	FOOT_R = tsk.get_bone_name(tb(R + "RightFoot"))
	var tap0: AnimationPlayer = _player()
	own = Animation.new()
	# OWN_CLIP=<its own clip>: every bone not baked from the donor keeps its own clip's motion (the Unseen's arms,
	# back, head and tail sway as drawn while its legs walk)
	var own_clip := OS.get_environment("OWN_CLIP")
	if own_clip != "" and tap0.has_animation(own_clip):
		own = tap0.get_animation(own_clip)
	for ti in own.get_track_count():
		var bn := str(own.track_get_path(ti).get_concatenated_subnames())
		if bn.begins_with("Bone") or (own_clip != "" and not MAP.has(bn)):
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
	var clips := OS.get_environment("CLIPS") if OS.get_environment("CLIPS") != "" else "Walk=Walk Forward,Run=Run Forward,Idle=Melee Idle"
	for c in clips.split(","):
		lib.add_animation(c.get_slice("=", 0), _bake(c.get_slice("=", 1)))
	if OS.get_environment("DEBUG") != "":
		for nm in ["Bind", "Rest"]:
			var a := Animation.new()
			a.length = 1.0
			var tap: AnimationPlayer = _player()
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
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "res://assets/models/foes/stranger/stranger_moves.res"
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
	MAP = {}
	for pair in [["Hips", "Spine_1_02"], ["Spine", "Spine_3_04"], ["Spine1", "Spine_3_04"], ["Spine2", "Spine_4_05"], ["Neck", "Spine_5_06"], ["Head", "Head_07"]]:
		if tb(R + pair[0]) < 0:
			continue
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
	# MAP_ONLY=Hips,LeftUpLeg,...: only these of the donor's bones are followed (the rest keep their own clip, see
	# OWN_CLIP). LEG_ROT=1: thigh and shin turn as the donor's do from their rest, not pointed along the donor's
	# limbs, so a leg of another shape (the Unseen's bent-back deer's legs) keeps its shape while it swings
	if OS.get_environment("LEG_ROT") != "":
		for sd in [["Left", "L", "042", "043"], ["Right", "R", "038", "039"]]:
			MAP[tsk.get_bone_name(tb(R + str(sd[0]) + "UpLeg"))] = ["rot", "Leg_1_%s_%s" % [sd[1], sd[2]]]
			MAP[tsk.get_bone_name(tb(R + str(sd[0]) + "Leg"))] = ["rot", "Leg_2_%s_%s" % [sd[1], sd[3]]]
	if OS.get_environment("LEG_IK") != "":
		# LEG_IK=1: thigh and shin bent (as they are bent at rest) to set the ankle where the donor's ankle is,
		# carried over at the body's size: a leg of another shape steps where the donor's foot steps
		for sd in [["Left", "L", "044"], ["Right", "R", "040"]]:
			var S := str(sd[0])
			MAP[tsk.get_bone_name(tb(R + S + "UpLeg"))] = ["ik", "Leg_3_%s_%s" % [sd[1], sd[2]], tsk.get_bone_name(tb(R + S + "Leg")), tsk.get_bone_name(tb(R + S + "Foot"))]
			MAP[tsk.get_bone_name(tb(R + S + "Leg"))] = ["ikshin", tsk.get_bone_name(tb(R + S + "Foot"))]
			if OS.get_environment("FOOT_HOLD") != "":
				# FOOT_HOLD=1: the foot keeps the lie it has at rest, flat as it was drawn standing
				MAP[tsk.get_bone_name(tb(R + S + "Foot"))] = ["hold"]
	if OS.get_environment("MAP_ONLY") != "":
		var keep := {}
		for role in OS.get_environment("MAP_ONLY").split(","):
			if tb(R + role) >= 0:
				keep[tsk.get_bone_name(tb(R + role))] = true
		for k in MAP.keys():
			if not keep.has(k):
				MAP.erase(k)
	print("MAP ", MAP)
	# The shared frame: left (from right hip to left hip) and up (hips to head), each at rest
	var sf := _frame(_sglob(sb("Leg_1_L_042"), true).origin - _sglob(sb("Leg_1_R_038"), true).origin,
		_sglob(sb("Head_07"), true).origin - _sglob(sb("Spine_1_02"), true).origin)
	var tf := _frame(bindG[tb(R + "LeftUpLeg")].origin - bindG[tb(R + "RightUpLeg")].origin,
		bindG[tb(R + "Head")].origin - bindG[tb(R + "Hips")].origin)
	if OS.get_environment("UP_Y") != "":
		# a body bent over (its head ahead of its hips, not over them): its up is the model's
		tf = _frame(bindG[tb(R + "LeftUpLeg")].origin - bindG[tb(R + "RightUpLeg")].origin, Vector3.UP)
	M = tf * sf.inverse()
	# Hip heights over the feet, for the hips' bob and sway
	var sh := _sglob(sb("Leg_1_L_042"), true).origin.y - _sglob(sb("Leg_3_L_044"), true).origin.y
	var th := (bindG[tb(R + "LeftUpLeg")] as Transform3D).origin.y - (bindG[tb(R + "LeftFoot")] as Transform3D).origin.y
	scale_k = th / sh
	print("FRAME src=", sf, " tgt=", tf, " M=", M, " k=", scale_k)


func _player() -> AnimationPlayer:
	var aps := troot.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		return aps[0]
	var ap := AnimationPlayer.new()
	troot.add_child(ap)
	return ap


func _bake(clip: String) -> Animation:
	var ap: AnimationPlayer = sroot.find_children("*", "AnimationPlayer", true, false)[0]
	assert(ap.has_animation(clip), "no clip " + clip)
	var src := ap.get_animation(clip)
	var tap: AnimationPlayer = _player()
	var base := str(tap.get_node(tap.root_node).get_path_to(tsk))
	var a := Animation.new()
	a.length = src.length
	a.loop_mode = Animation.LOOP_LINEAR
	var pt := {}
	var rt := {}
	for b in order:
		if not skinned.has(b) or (only_mapped and not MAP.has(tsk.get_bone_name(b)) and not own_tracks.has(b)):
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
		var ik_at := {}   ## foot bone -> where its ankle is set (LEG_IK)
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
					"hold":
						g.basis = (bindG[b] as Transform3D).basis
					"ik":
						var kb := tb(mp[2])
						var fb := tb(mp[3])
						var Pb: Vector3 = (bindG[b] as Transform3D).origin
						var Kb: Vector3 = (bindG[kb] as Transform3D).origin
						var Ab: Vector3 = (bindG[fb] as Transform3D).origin
						var l1 := Pb.distance_to(Kb)
						var l2 := Kb.distance_to(Ab)
						var sa := sb(mp[1])
						var A: Vector3 = Ab + M * (_sglob(sa, false).origin - drift * t - _sglob(sa, true).origin) * scale_k
						var P := g.origin
						var dd := clampf(P.distance_to(A), absf(l1 - l2) + 1e-4, (l1 + l2) * 0.999)
						var u := (A - P).normalized()
						# the knee bends the way it is bent at rest, turned as the hips are turned
						var ub := (Ab - Pb).normalized()
						var bend := (Kb - Pb) - ub * (Kb - Pb).dot(ub)
						bend = (pg.basis.orthonormalized() * pb.basis.orthonormalized().inverse()) * bend
						var v := (bend - u * bend.dot(u)).normalized()
						var ca := clampf((l1 * l1 + dd * dd - l2 * l2) / (2.0 * l1 * dd), -1.0, 1.0)
						var K := P + l1 * (u * ca + v * sqrt(1.0 - ca * ca))
						A = P + u * dd
						var j: Vector3 = (bindG[b] as Transform3D).affine_inverse() * Kb
						var have := g.basis * j
						g.basis = Basis(Quaternion(have.normalized(), (K - P).normalized())) * g.basis
						ik_at[mp[3]] = A
					"ikshin":
						if ik_at.has(mp[1]):
							var j: Vector3 = (bindG[b] as Transform3D).affine_inverse() * (bindG[tb(mp[1])] as Transform3D).origin
							var have := g.basis * j
							g.basis = Basis(Quaternion(have.normalized(), ((ik_at[mp[1]] as Vector3) - g.origin).normalized())) * g.basis
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
			if not pt.has(b):
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
