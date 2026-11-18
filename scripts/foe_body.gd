class_name FoeBody
extends Node3D
## A body for the foes that are not lesser forms: the Unlit (raiders in cat masks), the Hollowed,
## the Salt-Bones, the Lost Vigil and the Gravewarden. Each is a CC0 Kenney character with a skin of
## the waste (see tools/retexture.py), and it moves by the character's own animations.

const DIR := "res://assets/models/foes/"
## kind: [model, skin, scale, extra]
const LOOKS := {
	"unlit_gun": ["character-a.glb", "unlit_rust.png", 0.68, "rifle"],
	"unlit_blade": ["character-a.glb", "unlit_ochre.png", 0.7, "sword"],
	"unlit_brute": ["character-a.glb", "unlit_bone.png", 0.86, "maul"],
	"hollow": ["character-zombie.glb", "hollow.png", 3.3, ""],
	"saltbone": ["character-skeleton.glb", "saltbone.png", 3.2, ""],
	"vigil": ["character-ghost.glb", "vigil.png", 3.0, "glow"],
	"warden": ["character-keeper.glb", "warden.png", 3.1, ""],
	"unlit_mark": ["character-a.glb", "unlit_slate.png", 0.68, "rifle"],
	"unlit_flame": ["character-a.glb", "unlit_flame.png", 0.7, "sword"],
	"deacon": ["character-vampire.glb", "deacon.png", 3.2, ""],
	"drowned": ["character-zombie.glb", "tar.png", 3.3, ""],
	"colossus": ["character-zombie.glb", "colossus.png", 5.4, ""],
	"wisp": ["character-ghost.glb", "ember.png", 2.6, "glow"],
	"knight": ["character-keeper.glb", "knight.png", 3.3, "own"],   ## the knight keeps the flamberge it was made with
	"saltrifle": ["character-skeleton.glb", "saltrifle.png", 3.2, "rifle"],
}

## Real bodies in place of the Kenney figures (CC-BY 4.0, see CREDITS.md), by the figure they replace:
## [file, height in metres at the figure's base scale, that base scale, clips {way: clip}, head bone,
##  hand bone, chest bone, turn]. Each kind keeps its own skin's colour as a tint, and its own size.
const MODELS := {
	"character-zombie.glb": ["folk/zombie.glb", 1.85, 3.3, {"idle": "idlewalk", "walk": "idlewalk", "sprint": "idlewalk"}, "head_062", "R_wrist_041", "chest_013", 0.0],
	"character-keeper.glb": ["folk/knight.glb", 2.0, 3.1, {"idle": "ReadyUp", "walk": "Walk", "sprint": "Walk", "die": "WakeUp01"}, "Head_M_04", "Wrist_R_015", "Chest_M_03", 0.0],
	"character-vampire.glb": ["folk/lich.glb", 2.0, 3.2, {"idle": "Take 001", "walk": "Take 001", "sprint": "Take 001"}, "Head_06", "Hand_Right_040", "Neck1_05", 0.0],
	"character-ghost.glb": ["folk/ghost.glb", 1.9, 3.0, {}, "", "", "", 0.0],
	"character-skeleton.glb": ["folk/skeleton.glb", 1.8, 3.2, {"idle": "Take 001", "walk": "Take 001", "sprint": "Take 001"}, "", "", "", 0.0],
	"character-a.glb": ["folk/soldier.glb", 1.8, 0.68, {"idle": "rig|idle -loop", "walk": "rig|walk -loop", "sprint": "rig|run -loop",
		"attack-melee-right": "rig|knife_action", "holding-both": "rig|idle -loop", "holding-both-shoot": "rig|idle -loop"}, "head_05", "hand_R_022", "neck_04", 0.0],
}
const DROP := ["holster", "hand_knife", "Flamberge"]   ## parts left off: a stray holster, and blades our own arms replace
static var _bounds := {}
static var _tints := {}
static var _units := {}


## How big a unit is on a Kenney figure's arm (or torso), against the figure as a whole: what its arms were made for.
static func _kenney_unit(file: String, part: String) -> float:
	var key := file + "/" + part
	if _units.has(key):
		return _units[key]
	var m: Node3D = (load(DIR + file) as PackedScene).instantiate()
	var n: Node = m.find_child(part, true, false)
	if part == "torso" and m.find_child("head", true, false):
		n = m.find_child("head", true, false).get_parent()
	var k := 1.0
	while n and n != m:
		k *= (n as Node3D).scale.x
		n = n.get_parent()
	m.free()
	_units[key] = k
	return k

var clips := {}           ## the game's ways of moving, as this body's own clips
var metric := 1.0         ## metres to a unit of the hand's and chest's own space
var _float := false       ## a ghost with no bones: it drifts and sways instead
var _t := 0.0
var _fit: Array = []      ## [node, wanted size in the body's units, place in those units]: set once the body stands in the world
var anim: AnimationPlayer
var hand: Node3D          ## the right arm, where a weapon is held
var head_node: Node3D
var muzzle: Node3D        ## the end of a gunman's rifle
var _plate: Node3D        ## iron strapped to the chest, until it breaks
var _now := ""
var _once := 0.0          ## a one-off animation (a swing, a shot) still playing


static func make(kind: String) -> FoeBody:
	var look: Array = LOOKS[kind]
	if MODELS.has(look[0]) and ResourceLoader.exists(DIR + str(MODELS[look[0]][0])):
		return _make_real(kind, look)
	var b := FoeBody.new()
	var scene: PackedScene = load(DIR + look[0])
	var m: Node3D = scene.instantiate()
	m.scale = Vector3.ONE * float(look[2])
	b.add_child(m)
	var skin: Texture2D = load(DIR + "skins/" + look[1])
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = skin
		mat.roughness = 0.85
		if look[3] == "glow":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(1, 1, 1, 0.72)
			mat.emission_enabled = true
			mat.emission_texture = skin
			mat.emission_energy_multiplier = 0.6
		(mi as MeshInstance3D).material_override = mat
	b.anim = m.find_children("*", "AnimationPlayer", true, false)[0] if not m.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	b.hand = m.find_child("arm-right", true, false)
	b.head_node = m.find_child("head", true, false)
	match look[3]:
		"rifle":
			b._rifle()
		"sword":
			b._blade(0.95, Color(0.62, 0.6, 0.58))
		"maul":
			b._maul()
	if b.anim:
		for a in ["walk", "sprint", "idle"]:
			if b.anim.has_animation(a):
				b.anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	b.play("idle")
	return b


## The colour a Kenney skin was painted, to tint the real body the same way.
static func _skin_tint(file: String) -> Color:
	if _tints.has(file):
		return _tints[file]
	var c := Color(1, 1, 1)
	var tex: Texture2D = load(DIR + "skins/" + file)
	if tex:
		var img := tex.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			img.resize(8, 8)
			var sum := Color(0, 0, 0)
			for y in 8:
				for x in 8:
					sum += img.get_pixel(x, y)
			c = sum / 64.0
	_tints[file] = c
	return c


static func _make_real(kind: String, look: Array) -> FoeBody:
	var b := FoeBody.new()
	var spec: Array = MODELS[look[0]]
	var path := DIR + str(spec[0])
	var m: Node3D = (load(path) as PackedScene).instantiate()
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		for d in DROP:
			if look[3] == "own" and d == "Flamberge":
				continue
			if mm.mesh and d in mm.mesh.resource_name:
				mm.get_parent().remove_child(mm)
				mm.free()
				break
	if not _bounds.has(path):
		# Measured without what it holds, so a raised blade does not shrink the body
		var held: Array = []
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh and "Flamberge" in (mi as MeshInstance3D).mesh.resource_name:
				held.append([mi, mi.get_parent()])
				mi.get_parent().remove_child(mi)
		_bounds[path] = LesserSpeeb._skinned_bounds(m)
		for h in held:
			(h[1] as Node).add_child(h[0])
	var bb: AABB = _bounds[path]
	# As tall as the figure it replaces stood, so each kind keeps its size and its reach
	var kp := DIR + str(look[0])
	if not _bounds.has(kp):
		var km: Node3D = (load(kp) as PackedScene).instantiate()
		_bounds[kp] = LesserSpeeb._skinned_bounds(km)
		km.free()
	var tall := (_bounds[kp] as AABB).size.y * float(look[2])
	if tall <= 0.01:
		tall = float(spec[1]) * float(look[2]) / float(spec[2])
	var k := tall / maxf(bb.size.y, 0.001)
	# The old figures were broad and boxy; what they carried and wore is narrowed to the new body's girth
	var girth := clampf(bb.size.x * k / maxf((_bounds[kp] as AABB).size.x * float(look[2]), 0.001), 0.2, 1.0)
	var c := bb.get_center()
	var turn := Basis(Vector3.UP, float(spec[7]))
	m.transform = Transform3D(turn.scaled(Vector3.ONE * k), turn * Vector3(-c.x * k, -bb.position.y * k, -c.z * k))
	b.add_child(m)
	b.metric = k
	# Bounds as the body truly stands (with room to swing), for culling and for aim, not as the file stored them
	var w := bb.size.y * 0.15
	var room := AABB(bb.position - Vector3(w, 0, w), bb.size + Vector3(w * 2, bb.size.y * 0.04, w * 2))
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).custom_aabb = WTrees._chain(mi, m).affine_inverse() * room
	var tint := _skin_tint(look[1])
	var glow: bool = look[3] == "glow"
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si in (mm.mesh.get_surface_count() if mm.mesh else 0):
			var sm := mm.mesh.surface_get_material(si)
			var t: StandardMaterial3D = (sm as StandardMaterial3D).duplicate() if sm is StandardMaterial3D else StandardMaterial3D.new()
			# Its skin's colour over the model's own, half and half, so each kind still reads as itself
			t.albedo_color = t.albedo_color * Color(1, 1, 1).lerp(tint.lightened(0.15), 0.6)
			if glow:
				t.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				t.albedo_color = Color(tint.lightened(0.3), 0.7)
				t.emission_enabled = true
				t.emission = tint
				t.emission_energy_multiplier = 0.8
				t.cull_mode = BaseMaterial3D.CULL_DISABLED
			mm.set_surface_override_material(si, t)
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	b.anim = aps[0] if not aps.is_empty() else null
	b.clips = spec[3]
	b._float = b.anim == null
	if b.anim:
		for a in ["idle", "walk", "sprint"]:
			var cn: String = b.clips.get(a, "")
			if cn != "" and b.anim.has_animation(cn):
				b.anim.get_animation(cn).loop_mode = Animation.LOOP_LINEAR
	var sks := m.find_children("*", "Skeleton3D", true, false)
	var sk: Skeleton3D = sks[0] if not sks.is_empty() else null
	# Where shots find the head: a small unseen box on the head bone (or where a head would be)
	var hb := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * clampf(tall * 0.12, 0.25, 0.5)
	hb.mesh = box
	# Unseen, yet still there to carry what is worn on the head
	var clear := StandardMaterial3D.new()
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.albedo_color = Color(1, 1, 1, 0)
	hb.material_override = clear
	hb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head_at := _bone_node(sk, str(spec[4]))
	if head_at:
		head_at.add_child(hb)
		b._fit.append([hb, 1.0, Vector3(0, 0.08, 0)])
	else:
		b.add_child(hb)
		hb.position = Vector3(0, tall * 0.9, 0)
	b.head_node = hb
	# A hand to hold a weapon: arranged as the Kenney arm held it (down along the arm), in metres
	var hand_at := _bone_node(sk, str(spec[5]))
	if hand_at:
		var grip := Node3D.new()
		grip.rotation.x = PI   # the hand's bone runs toward the fingers; the old arm hung the other way
		hand_at.add_child(grip)
		b._fit.append([grip, float(look[2]) * girth * _kenney_unit(look[0], "arm-right"), Vector3(0, -0.8, 0)])
		b.hand = grip
	var chest_at := _bone_node(sk, str(spec[6]))
	if chest_at:
		var torso := Node3D.new()
		chest_at.add_child(torso)
		b._fit.append([torso, float(look[2]) * girth * _kenney_unit(look[0], "torso"), Vector3(0, -1.3, 0)])
		b.set_meta("torso", torso)
	match look[3]:
		"rifle":
			b._rifle()
		"sword":
			b._blade(0.95, Color(0.62, 0.6, 0.58))
		"maul":
			b._maul()
	b.play("idle")
	return b


## How high the body reaches above its feet, in its own space: the top of every part it shows.
func top() -> float:
	var y := 0.0
	for g in find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi == head_node or not gi.visible or gi is Label3D or gi is GPUParticles3D or gi is CPUParticles3D:
			continue
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh and "Flamberge" in (gi as MeshInstance3D).mesh.resource_name:
			continue   # a raised blade is not the top of the body
		# Skinned parts carry their true, posed bounds; the file's own are those of the bind pose
		var bb := gi.custom_aabb if gi.custom_aabb.size != Vector3.ZERO else gi.get_aabb()
		if bb.size == Vector3.ZERO:
			continue
		var tr := WTrees._chain(gi, self)
		for i in 8:
			y = maxf(y, (tr * bb.get_endpoint(i)).y)
	return y


func _fit_now() -> void:
	var mine := global_basis.get_scale().x
	for f in _fit:
		var n: Node3D = f[0]
		var up := (n.get_parent() as Node3D).global_basis.get_scale().x
		var k := float(f[1]) * mine / maxf(up, 0.00001)
		n.scale = Vector3.ONE * k
		n.position = (f[2] as Vector3) * k
	_fit.clear()


static func _bone_node(sk: Skeleton3D, bone: String) -> Node3D:
	if sk == null or bone == "" or sk.find_bone(bone) < 0:
		return null
	var at := BoneAttachment3D.new()
	at.bone_name = bone
	sk.add_child(at)
	return at


## Ears of bone on the hood, so the mask reads from afar: the Unlit mock the cat they put out.
func _ears(_s: float) -> void:
	if head_node == null:
		return
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.88, 0.85, 0.78)
	for side in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.16
		c.height = 0.34
		c.radial_segments = 4
		e.mesh = c
		e.material_override = bone
		e.position = Vector3(side * 0.24, 0.95, 0.0)
		e.rotation.z = -side * 0.25
		if not clips.is_empty():
			# On a real head, in metres: small, and just above the crown
			e.scale = Vector3.ONE * 0.45
			e.position = Vector3(side * 0.1, 0.24, -0.02)
		head_node.add_child(e)


func _rifle() -> void:
	if hand == null:
		return
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.11, 0.1)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.22, 0.12)
	# Laid along the arm, so it points where the arms point: down at rest, ahead when raised
	var g := Node3D.new()
	g.position = Vector3(0, -0.8, -0.12)
	hand.add_child(g)
	for part in [[Vector3(0.1, 1.1, 0.12), Vector3(0, -0.35, 0), dark], [Vector3(0.12, 0.5, 0.2), Vector3(0, 0.3, 0.04), wood], [Vector3(0.05, 0.6, 0.05), Vector3(0, -1.1, -0.03), dark]]:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = part[0]
		mi.mesh = bx
		mi.position = part[1]
		mi.material_override = part[2]
		g.add_child(mi)
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, -1.45, -0.03)
	g.add_child(muzzle)


func _blade(length: float, c: Color) -> void:
	if hand == null:
		return
	var steel := StandardMaterial3D.new()
	steel.albedo_color = c
	steel.metallic = 0.7
	steel.roughness = 0.35
	var g := Node3D.new()
	g.position = Vector3(0, -0.9, 0.1)
	g.rotation.x = -PI * 0.5
	hand.add_child(g)
	var bl := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.06, length * 1.4, 0.14)
	bl.mesh = bx
	bl.position.y = length * 0.7 + 0.15
	bl.material_override = steel
	g.add_child(bl)
	var guard := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.1, 0.06, 0.4)
	guard.mesh = gb
	guard.position.y = 0.12
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.16, 0.12)
	guard.material_override = dark
	g.add_child(guard)


func _maul() -> void:
	if hand == null:
		return
	# The scanned sledgehammer the pilgrims carry, grown to a breaker's two-handed maul
	var sl := Arms.scanned("sledgehammer_01", Vector3(0, 90, 0), -0.25, 2.1)
	if sl == null:
		_blade(0.7, Color(0.3, 0.28, 0.26))
		return
	sl.position = Vector3(0, -0.9, 0.1)
	sl.rotation.x = PI * 0.5
	hand.add_child(sl)


## Rough iron plates strapped over the chest (and the shoulders, for a heavy one).
func wear_plate(heavy: bool) -> void:
	var torso: Node3D = get_meta("torso") if has_meta("torso") else (head_node.get_parent() if head_node else null)
	if has_meta("torso") == false and not clips.is_empty():
		return
	if torso == null:
		return
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.6, 0.55, 0.48)
	iron.metallic = 0.6
	iron.roughness = 0.55
	_plate = Node3D.new()
	torso.add_child(_plate)
	var bits := [[Vector3(0.72, 0.6, 0.07), Vector3(0, 0.8, 0.34)], [Vector3(0.72, 0.6, 0.07), Vector3(0, 0.8, -0.34)]]
	if heavy:
		bits.append([Vector3(0.36, 0.1, 0.56), Vector3(0.5, 1.24, -0.05)])
		bits.append([Vector3(0.36, 0.1, 0.56), Vector3(-0.5, 1.24, -0.05)])
	for b in bits:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = b[0]
		mi.mesh = bx
		mi.position = b[1]
		mi.material_override = iron
		_plate.add_child(mi)
	# The bones of the new bodies lie every which way: the plate stands upright with the body,
	# as wide as its chest, centred on the chest bone
	if has_meta("torso"):
		_plate_k = top() * 0.21 / 0.72
		iron.albedo_color = Color(0.3, 0.28, 0.26)
		_stand_plate()


var _plate_k := 0.0   ## the plate's size against the body, when it hangs on a new body's chest bone


## Keeps the plate upright with the body as the chest bone moves under it.
func _stand_plate() -> void:
	if _plate_k <= 0.0 or not is_instance_valid(_plate) or not _plate.is_inside_tree():
		return
	var bone := _plate.get_parent().get_parent() as Node3D
	var gb := global_basis
	_plate.global_basis = gb.orthonormalized().scaled(Vector3.ONE * _plate_k * gb.get_scale().x)
	_plate.global_position = bone.global_position - gb * Vector3(0, 0.95 * _plate_k + 0.1, 0)


## The plate falls away in pieces.
func break_plate() -> void:
	if _plate == null:
		return
	for mi in _plate.get_children():
		var gt: Transform3D = (mi as Node3D).global_transform
		var at := gt.origin
		_plate.remove_child(mi)
		get_tree().current_scene.add_child(mi)
		mi.global_transform = gt
		var tw := mi.create_tween()
		tw.tween_property(mi, "global_position", at + Vector3(randf_range(-0.6, 0.6), -at.y + at.y - 0.9, randf_range(-0.6, 0.6)), 0.35)
		tw.tween_interval(3.0)
		tw.tween_callback(mi.queue_free)
	_plate.queue_free()
	_plate = null


## Plays a looping way of moving (walk, sprint, idle), unless a one-off is still playing.
func play(a: String, speed := 1.0) -> void:
	if not clips.is_empty():
		a = str(clips.get(a, clips.get("idle", "")))
	if anim == null or _once > 0.0 or not anim.has_animation(a):
		return
	anim.speed_scale = speed
	if _now != a:
		_now = a
		anim.play(a, 0.15)


## A one-off: a swing, a shot, a fall. It plays through before the walking takes up again.
func act(a: String, speed := 1.0) -> void:
	if not clips.is_empty():
		a = str(clips.get(a, ""))
	if anim == null or not anim.has_animation(a):
		return
	anim.speed_scale = speed
	_now = a
	anim.play(a, 0.08)
	_once = anim.get_animation(a).length / maxf(speed, 0.1)


func _ready() -> void:
	if not _fit.is_empty():
		_fit_now()


func _process(delta: float) -> void:
	_once = maxf(0.0, _once - delta)
	if not _fit.is_empty():
		_fit_now()
	_stand_plate()
	if _float:
		# A ghost without bones drifts: a slow sway and rise
		_t += delta
		var m: Node3D = get_child(0)
		m.rotation.z = sin(_t * 1.3) * 0.06
		m.rotation.x = sin(_t * 0.9) * 0.05
