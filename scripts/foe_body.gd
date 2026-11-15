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
}

var anim: AnimationPlayer
var hand: Node3D          ## the right arm, where a weapon is held
var head_node: Node3D
var muzzle: Node3D        ## the end of a gunman's rifle
var _now := ""
var _once := 0.0          ## a one-off animation (a swing, a shot) still playing


static func make(kind: String) -> FoeBody:
	var b := FoeBody.new()
	var look: Array = LOOKS[kind]
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
	if kind.begins_with("unlit"):
		b._ears(float(look[2]))
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
	_blade(0.7, Color(0.3, 0.28, 0.26))
	if hand == null:
		return
	var head := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.4, 0.4, 0.6)
	head.mesh = bx
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.3, 0.28)
	head.material_override = m
	head.position = Vector3(0, -0.9, 1.3)
	hand.add_child(head)


## Plays a looping way of moving (walk, sprint, idle), unless a one-off is still playing.
func play(a: String, speed := 1.0) -> void:
	if anim == null or _once > 0.0 or not anim.has_animation(a):
		return
	anim.speed_scale = speed
	if _now != a:
		_now = a
		anim.play(a, 0.15)


## A one-off: a swing, a shot, a fall. It plays through before the walking takes up again.
func act(a: String, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(a):
		return
	anim.speed_scale = speed
	_now = a
	anim.play(a, 0.08)
	_once = anim.get_animation(a).length / maxf(speed, 0.1)


func _process(delta: float) -> void:
	_once = maxf(0.0, _once - delta)
