class_name Figure
extends Node3D
## A human figure built from plain shapes, dressed by a "look": build, skin, face, hair, headwear,
## coat, dye, what is carried on the back and what hangs at the belt. Faces +Z. Used for the
## pilgrims of a fellowship, the people of the waste, and the appearance screen.

const OPTIONS := {
	"build": ["Slight", "Middling", "Broad"],
	"skin": ["Pale", "Fair", "Olive", "Tan", "Brown", "Deep brown"],
	"face": ["Clean-shaven", "Stubble", "Full beard", "Long beard", "Scarred", "Weathered"],
	"hair": ["Shorn", "Short", "Long", "Grey", "Bald"],
	"head": ["Bare", "Hood", "Wide-brim hat", "Wrapped cloth", "Iron helm", "Gas mask"],
	"coat": ["Pilgrim's robe", "Long coat", "Field jacket", "Duster", "Ragged cloak"],
	"dye": ["Ash grey", "Oxblood", "Moss", "Ochre", "Slate", "Umber", "Bone", "Black"],
	"pack": ["Nothing", "Satchel", "Pack frame", "Bedroll"],
	"trinket": ["Nothing", "Bandolier", "Prayer beads", "Lantern at the belt", "Bone charms"],
}
const LABELS := {"build": "Build", "skin": "Skin", "face": "Face", "hair": "Hair", "head": "Head", "coat": "Coat",
	"dye": "Dye", "pack": "On the back", "trinket": "At the belt"}
const ORDER := ["build", "skin", "face", "hair", "head", "coat", "dye", "pack", "trinket"]

const SKINS := [Color(0.93, 0.8, 0.72), Color(0.87, 0.7, 0.58), Color(0.74, 0.58, 0.44), Color(0.66, 0.48, 0.34), Color(0.48, 0.33, 0.23), Color(0.32, 0.22, 0.16)]
const DYES := [Color(0.36, 0.35, 0.34), Color(0.36, 0.12, 0.1), Color(0.22, 0.28, 0.18), Color(0.55, 0.42, 0.2), Color(0.26, 0.3, 0.34), Color(0.32, 0.23, 0.16), Color(0.72, 0.68, 0.6), Color(0.09, 0.09, 0.1)]
const HAIRS := [Color(0.12, 0.09, 0.07), Color(0.25, 0.17, 0.1), Color(0.42, 0.3, 0.18), Color(0.62, 0.6, 0.57)]

const DEFAULT := {"build": 1, "skin": 1, "face": 1, "hair": 1, "head": 1, "coat": 0, "dye": 0, "pack": 1, "trinket": 0}

var look := DEFAULT.duplicate()
var walk := 0.0            ## the stride's phase; the owner advances it
var stride := 0.0          ## 0 standing, 1 walking
var arms_forward := true   ## holding something before them
var hold := false          ## both hands on a gun, at GRIP and FORE
var aim := 0.0             ## how far the gun is raised or lowered, in radians
const SHOULDER_Y := 1.45
const GRIP := Vector3(0.17, 1.2, 0.44)   ## where the near hand holds a gun, with the gun level
const FORE := Vector3(0.1, 1.19, 0.52)   ## where the far hand steadies it
var hand_r: Node3D         ## where a held thing goes
var _legs: Array = []
var _arms: Array = []


static func clean(l) -> Dictionary:
	var out := DEFAULT.duplicate()
	if l is Dictionary:
		for k in OPTIONS:
			if l.has(k):
				out[k] = clampi(int(l[k]), 0, OPTIONS[k].size() - 1)
	return out


## A look chosen by a seed, for the people of the waste.
static func seeded(seed: int, dye := -1) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var l := {}
	for k in OPTIONS:
		l[k] = r.randi_range(0, OPTIONS[k].size() - 1)
	l.head = [0, 1, 1, 2, 3][r.randi_range(0, 4)]
	if dye >= 0:
		l.dye = dye
	return l


func setup(l) -> Figure:
	look = clean(l)
	return self


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_legs.clear()
	_arms.clear()
	var L := look
	var w: float = [0.88, 1.0, 1.14][L.build]
	var skin := _mat(SKINS[L.skin], 0.0, 0.75)
	var dye: Color = DYES[L.dye]
	var cloth := _mat(dye, 0.0, 0.95)
	var cloth2 := _mat(dye.darkened(0.35), 0.0, 0.95)
	var leather := _mat(Color(0.2, 0.13, 0.08), 0.0, 0.8)
	var dark := _mat(Color(0.06, 0.06, 0.06), 0.0, 0.8)
	var hair_c: Color = HAIRS[mini(L.hair, 3)]
	var hair := _mat(hair_c, 0.0, 0.9)
	var trousers := _mat(Color(0.17, 0.16, 0.14), 0.0, 0.95)
	# Legs, from the hip: each a pivot so they may swing
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(0.1 * side * w, 0.92, 0)
		add_child(hip)
		_legs.append(hip)
		_box(hip, Vector3(0.13 * w, 0.84, 0.14), Vector3(0, -0.44, 0), trousers)
		_box(hip, Vector3(0.14 * w, 0.1, 0.24), Vector3(0, -0.87, 0.04), leather)
	# Torso, neck and head
	_box(self, Vector3(0.4 * w, 0.58, 0.22), Vector3(0, 1.22, 0), cloth)
	_box(self, Vector3(0.36 * w, 0.12, 0.2), Vector3(0, 0.95, 0), leather)
	_cyl(self, 0.055, 0.1, Vector3(0, 1.55, 0), skin, Vector3.ZERO)
	var head := Node3D.new()
	head.position = Vector3(0, 1.7, 0)
	add_child(head)
	var skull := _sphere(head, 0.115, Vector3.ZERO, skin)
	skull.scale = Vector3(0.92, 1.05, 1.0)
	for side in [-1, 1]:
		_sphere(head, 0.016, Vector3(0.042 * side, 0.02, 0.1), dark)
	_box(head, Vector3(0.03, 0.05, 0.04), Vector3(0, -0.01, 0.115), skin)
	_box(head, Vector3(0.05, 0.008, 0.01), Vector3(0, -0.058, 0.105), _mat(SKINS[L.skin].darkened(0.4)))
	match L.face:
		1:
			_box(head, Vector3(0.17, 0.08, 0.1), Vector3(0, -0.07, 0.05), _mat(hair_c.lerp(SKINS[L.skin], 0.5), 0.0, 1.0))
		2:
			_box(head, Vector3(0.18, 0.11, 0.1), Vector3(0, -0.08, 0.06), hair)
		3:
			_box(head, Vector3(0.17, 0.22, 0.09), Vector3(0, -0.13, 0.07), hair)
		4:
			_box(head, Vector3(0.012, 0.09, 0.01), Vector3(0.05, 0.0, 0.112), _mat(Color(0.55, 0.3, 0.28)), Vector3(0, 0, 0.4))
		5:
			_box(head, Vector3(0.1, 0.006, 0.01), Vector3(0, 0.055, 0.108), _mat(SKINS[L.skin].darkened(0.3)))
	var bare: bool = L.head == 0
	if L.hair != 4 and (bare or L.head == 2):
		var hc := _sphere(head, 0.122, Vector3(0, 0.03, -0.012), hair)
		hc.scale = Vector3(0.95, 0.9 if L.hair == 0 else 1.0, 1.0)
		if L.hair == 2 or L.hair == 3:
			_box(head, Vector3(0.2, 0.22, 0.06), Vector3(0, -0.07, -0.09), hair)
	match L.head:
		1:
			var hood := _sphere(head, 0.15, Vector3(0, 0.03, -0.03), cloth2)
			hood.scale = Vector3(1.0, 1.1, 1.05)
			_box(head, Vector3(0.3, 0.16, 0.24), Vector3(0, -0.14, -0.05), cloth2)
		2:
			_cyl(head, 0.24, 0.02, Vector3(0, 0.08, 0), leather, Vector3.ZERO)
			_cyl(head, 0.11, 0.12, Vector3(0, 0.14, 0), leather, Vector3.ZERO)
		3:
			var wrap := _sphere(head, 0.128, Vector3(0, 0.035, -0.01), _mat(Color(0.6, 0.56, 0.48), 0.0, 1.0))
			wrap.scale = Vector3(1.0, 0.85, 1.0)
			_box(head, Vector3(0.2, 0.07, 0.04), Vector3(0, -0.075, 0.1), _mat(Color(0.6, 0.56, 0.48), 0.0, 1.0))
		4:
			var helm := _sphere(head, 0.135, Vector3(0, 0.035, 0), _mat(Color(0.3, 0.3, 0.31), 0.7, 0.45))
			helm.scale = Vector3(1, 0.8, 1.05)
			_box(head, Vector3(0.025, 0.12, 0.03), Vector3(0, -0.02, 0.125), _mat(Color(0.3, 0.3, 0.31), 0.7, 0.45))
		5:
			_box(head, Vector3(0.17, 0.12, 0.08), Vector3(0, 0.0, 0.09), dark)
			for side in [-1, 1]:
				_cyl(head, 0.03, 0.02, Vector3(0.045 * side, 0.02, 0.135), _mat(Color(0.5, 0.55, 0.5), 0.6, 0.2))
			_cyl(head, 0.04, 0.07, Vector3(0, -0.06, 0.14), dark)
			_sphere(head, 0.12, Vector3(0, 0.03, -0.01), dark).scale = Vector3(1, 0.95, 0.95)
	# The coat over all
	match L.coat:
		0:
			_cyl(self, 0.2 * w, 1.15, Vector3(0, 0.62, 0), cloth, Vector3.ZERO, 0.42 * w)
			_box(self, Vector3(0.44 * w, 0.5, 0.25), Vector3(0, 1.25, 0), cloth)
		1:
			_box(self, Vector3(0.44 * w, 0.62, 0.26), Vector3(0, 1.22, 0), cloth)
			_box(self, Vector3(0.46 * w, 0.5, 0.27), Vector3(0, 0.68, 0), cloth)
			_box(self, Vector3(0.03, 0.9, 0.01), Vector3(0, 1.0, 0.14), cloth2)
		2:
			_box(self, Vector3(0.45 * w, 0.6, 0.27), Vector3(0, 1.2, 0), cloth)
			for side in [-1, 1]:
				_box(self, Vector3(0.1, 0.08, 0.02), Vector3(0.1 * side, 1.12, 0.14), cloth2)
		3:
			_box(self, Vector3(0.44 * w, 0.62, 0.26), Vector3(0, 1.22, 0), cloth)
			_box(self, Vector3(0.5 * w, 0.85, 0.27), Vector3(0, 0.52, 0), cloth)
			_box(self, Vector3(0.52 * w, 0.22, 0.3), Vector3(0, 1.42, 0), cloth2)
		4:
			_box(self, Vector3(0.42 * w, 0.58, 0.24), Vector3(0, 1.22, 0), cloth2)
			var cape := _box(self, Vector3(0.56 * w, 1.15, 0.04), Vector3(0, 0.88, -0.16), cloth)
			cape.rotation.x = 0.06
			for i in 4:
				_box(self, Vector3(0.1, 0.12, 0.04), Vector3((i - 1.5) * 0.13 * w, 0.27, -0.19), cloth)
	# Arms, from the shoulder, holding forward
	for side in [-1, 1]:
		var sh := Node3D.new()
		sh.position = Vector3(0.25 * side * w, 1.45, 0)
		add_child(sh)
		_arms.append(sh)
		_box(sh, Vector3(0.11, 0.56, 0.12), Vector3(0, -0.27, 0), cloth if L.coat != 4 else cloth2)
		_sphere(sh, 0.05, Vector3(0, -0.58, 0.0), skin)
	hand_r = Node3D.new()
	_arms[1].add_child(hand_r)
	hand_r.position = Vector3(0, -0.58, 0.05)
	# What is carried
	match L.pack:
		1:
			_box(self, Vector3(0.18, 0.2, 0.08), Vector3(-0.24 * w, 0.92, 0.0), leather)
			_box(self, Vector3(0.03, 0.6, 0.02), Vector3(0, 1.22, 0.135), leather, Vector3(0, 0, 0.6))
		2:
			_box(self, Vector3(0.34, 0.5, 0.2), Vector3(0, 1.22, -0.23), _mat(Color(0.3, 0.27, 0.2), 0.0, 0.9))
			_box(self, Vector3(0.03, 0.72, 0.03), Vector3(0.18, 1.2, -0.34), leather)
			_box(self, Vector3(0.03, 0.72, 0.03), Vector3(-0.18, 1.2, -0.34), leather)
		3:
			var roll := _cyl(self, 0.09, 0.5, Vector3(0, 1.52, -0.18), _mat(Color(0.4, 0.36, 0.28), 0.0, 1.0), Vector3(0, 0, PI / 2))
			roll.scale = Vector3(1, 1, 1)
	match L.trinket:
		1:
			_box(self, Vector3(0.05, 0.7, 0.03), Vector3(0, 1.22, 0.14), leather, Vector3(0, 0, -0.6))
			for i in 6:
				_box(self, Vector3(0.02, 0.05, 0.02), Vector3(-0.15 + i * 0.06, 1.0 + i * 0.08, 0.16), _mat(Color(0.7, 0.55, 0.3), 0.8, 0.3))
		2:
			for i in 9:
				var a := -0.9 + i * 0.22
				_sphere(self, 0.016, Vector3(sin(a) * 0.12, 1.5 - cos(a) * 0.14, 0.135), _mat(Color(0.25, 0.15, 0.1)))
		3:
			_box(self, Vector3(0.07, 0.11, 0.07), Vector3(0.22 * w, 0.85, 0.05), _mat(Color(0.15, 0.13, 0.1), 0.6, 0.5))
			var glow := _mat(Color(1.0, 0.8, 0.5))
			glow.emission_enabled = true
			glow.emission = Color(1.0, 0.75, 0.4)
			glow.emission_energy_multiplier = 1.5
			_box(self, Vector3(0.05, 0.06, 0.05), Vector3(0.22 * w, 0.85, 0.05), glow)
		4:
			for i in 3:
				_box(self, Vector3(0.025, 0.07, 0.015), Vector3(-0.1 + i * 0.1, 0.86, 0.14), _mat(Color(0.85, 0.82, 0.74)))
	for c in find_children("*", "MeshInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _process(_delta: float) -> void:
	if _legs.size() < 2:
		return
	var s := sin(walk) * 0.55 * stride
	_legs[0].rotation.x = s
	_legs[1].rotation.x = -s
	if hold:
		var pts := [FORE, GRIP]
		for i in 2:
			var sh: Node3D = _arms[i]
			var t: Vector3 = pts[i] - Vector3(0, SHOULDER_Y, 0)
			t = t.rotated(Vector3.RIGHT, aim) + Vector3(0, SHOULDER_Y, 0)
			sh.basis = Basis(Quaternion(Vector3.DOWN, (t - sh.position).normalized()))
		return
	var fwd := -1.15 if arms_forward else 0.0
	_arms[0].rotation.x = fwd * 0.85 - s * (0.2 if arms_forward else 0.6)
	_arms[1].rotation.x = fwd + s * (0.15 if arms_forward else 0.6)
	_arms[0].rotation.z = -0.35 if arms_forward else 0.05
	_arms[1].rotation.z = 0.15 if arms_forward else -0.05


func _mat(c: Color, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _box(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


func _sphere(p: Node3D, r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	p.add_child(mi)
	return mi


func _cyl(p: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3(PI / 2, 0, 0), r_bottom := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r if r_bottom < 0.0 else r_bottom
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi
