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
var seated := false        ## astride a riding cat, legs either side of it
var arms_forward := true   ## holding something before them
var hold := false          ## both hands on a gun, at GRIP and FORE
var aim := 0.0             ## how far the gun is raised or lowered, in radians
var bends := false         ## legs that bend at the knee and ankle, so it may crouch (set before it is built: a friend's)
var crouch := 0.0          ## 0 standing, 1 crouched: the owner lowers and leans the body; the legs bend to keep the feet down
var ground: Node3D         ## crouched, the node whose level (y = 0) is the ground under the feet
var trod := 0.0            ## metres walked, for the crouched step (the owner adds to it)
var going := Vector2(0, 1) ## the way they walk, in their own frame (x to the side, y forward)
const CROUCH_DROP := 0.48  ## how far the hips come down crouched
const CROUCH_LEAN := 0.42  ## and how far the body leans forward over them, about the hips
const HIP_Y := 0.92
const THIGH := 0.44        ## hip to knee
const SHIN := 0.38         ## knee to ankle; the ankle is 0.1 off the ground
const STEP := 0.42         ## a crouched step, heel to heel
const SHOULDER_Y := 1.45
const GRIP := Vector3(0.17, 1.2, 0.44)   ## where the near hand holds a gun, with the gun level
const FORE := Vector3(0.1, 1.19, 0.52)   ## where the far hand steadies it
var grip_at := GRIP   ## where the near hand holds the gun now held (set from the gun, see Companion)
var fore_at := FORE   ## and where the far hand goes on it
var hand_r: Node3D         ## where a held thing goes
var talk_t := 0.0          ## seconds left of moving the mouth, while words are spoken
var _mouth: MeshInstance3D
var _talk_ph := 0.0
var _legs: Array = []
var _knees: Array = []
var _skirt: Node3D   ## (legs that bend) what hangs from the hips, coat tails and cloak, so it can gather up crouched
var _ankles: Array = []
var _arms: Array = []
## A real body (see Person) in place of the plain shapes, for the people of the waste; their faces, skins and
## clothes are their own, and the look picks which of them it is. Players and the appearance screen keep the shapes.
var real := false
var person: Person
var person_key := ""   ## (testing aid) which body, in place of the one the look picks
var _walk_was := 0.0


## Gear of the waste worn over the look: goggles, a mask, a veil or scarf, a cloak, gloves (0 = none).
const GEAR := {"eyes": 2, "mask": 2, "neck": 3, "cloak": 3, "hands": 2}


## The townsfolk's own dress, over the same look: a second colour at the cuffs, belt and collar,
## an apron or tabard for their work, and something of their trade in the hand (a kit model).
const TRIMS := [Color(0.0, 0.0, 0.0, 0.0), Color(0.62, 0.48, 0.22), Color(0.5, 0.16, 0.12), Color(0.25, 0.36, 0.3),
	Color(0.7, 0.66, 0.58), Color(0.3, 0.34, 0.45), Color(0.45, 0.3, 0.42), Color(0.75, 0.55, 0.3)]
const APRONS := 4   ## none, leather apron, cloth apron, tabard
const HELD := [[], ["grave", "lantern-candle", 1.3], ["food", "bag", 1.3], ["food", "mug", 0.9], ["food", "fish", 1.3],
	["food", "loaf", 0.9], ["furn", "books", 0.25], ["food", "bottle-oil", 1.1], ["grave", "shovel-dirt", 1.4],
	["food", "pot", 0.9], ["grave", "candle", 1.6], ["food", "bowl", 0.9], ["grave", "lantern-glass", 1.3], ["food", "frying-pan", 0.7]]
const DRESS := {"trim": 8, "apron": 4, "held": 14}

## What each town's people work with: [aprons], [held things], [dyes]; a town's people favour its own.
const TOWN_DRESS := {
	"cinderwick": [[0, 2], [2, 8, 3], [0, 3, 5]],
	"lanternwell": [[0, 2], [1, 7, 12], [3, 5, 7]],
	"hesk": [[0, 2, 2], [2, 5, 3, 4], [1, 3, 6]],
	"kiln": [[1, 1, 0], [9, 11, 8], [5, 0, 7]],
	"mourners": [[0, 3], [10, 1, 6], [7, 0, 4]],
	"gallowmere": [[0, 2], [4, 1, 3], [4, 2, 0]],
	"saltreach": [[0, 2], [2, 4, 3], [6, 4, 0]],
	"emberhollow": [[1, 0], [8, 1, 9], [5, 7, 1]],
	"lastlight": [[3, 0], [12, 6, 1], [4, 6, 2]],
}


static func clean(l) -> Dictionary:
	var out := DEFAULT.duplicate()
	if l is Dictionary:
		for k in OPTIONS:
			if l.has(k):
				out[k] = clampi(int(l[k]), 0, OPTIONS[k].size() - 1)
		for k in GEAR:
			if l.has(k):
				out[k] = clampi(int(l[k]), 0, int(GEAR[k]) - 1)
		for k in DRESS:
			if l.has(k):
				out[k] = clampi(int(l[k]), 0, int(DRESS[k]) - 1)
	return out


## A look for one of a town's people: the waste's own look, with the town's colours and trade,
## a trim, and some of the gear of the waste (goggles, a scarf, a cloak, gloves) now and then.
static func townsman(seed: int, town := "") -> Dictionary:
	var l := seeded(seed)
	var r := RandomNumberGenerator.new()
	r.seed = seed + 991
	var td: Array = TOWN_DRESS.get(town, [[0, 2], [0, 2, 3, 5], []])
	if not (td[2] as Array).is_empty() and r.randf() < 0.6:
		l.dye = td[2][r.randi() % td[2].size()]
	l.trim = r.randi_range(0, TRIMS.size() - 1) if r.randf() < 0.7 else 0
	l.apron = td[0][r.randi() % td[0].size()]
	l.held = td[1][r.randi() % td[1].size()] if r.randf() < 0.75 else 0
	l.eyes = 1 if r.randf() < 0.12 else 0
	l.neck = r.randi_range(1, 2) if r.randf() < 0.4 else 0
	l.cloak = r.randi_range(1, 2) if r.randf() < 0.25 else 0
	l.hands = 1 if r.randf() < 0.35 else 0
	return l


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
	_skirt = null
	_knees.clear()
	_ankles.clear()
	_arms.clear()
	person = null
	var L := look
	if real:
		var k := person_key if person_key != "" else Person.pick(L, hash(L))
		if Person.can(k):
			person = Person.new().setup(k, hash(L), int(L.build))
			person.seated = seated
			add_child(person)
			hand_r = person.hand_r
			_hold_item(L)
			return
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
	# Legs, from the hip: each a pivot so they may swing. Those that bend have a knee and an ankle too;
	# straight, they are the same one leg from hip to sole (two more parts each, so only where needed).
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(0.1 * side * w, HIP_Y, 0)
		add_child(hip)
		_legs.append(hip)
		if not bends:
			_box(hip, Vector3(0.13 * w, 0.84, 0.14), Vector3(0, -0.44, 0), trousers)
			_box(hip, Vector3(0.14 * w, 0.1, 0.24), Vector3(0, -0.87, 0.04), leather)
			continue
		_box(hip, Vector3(0.13 * w, 0.47, 0.14), Vector3(0, -0.255, 0), trousers)
		var knee := Node3D.new()
		knee.position = Vector3(0, -THIGH, 0)
		hip.add_child(knee)
		_knees.append(knee)
		_box(knee, Vector3(0.128 * w, 0.42, 0.138), Vector3(0, -0.21, 0), trousers)
		var ankle := Node3D.new()
		ankle.position = Vector3(0, -SHIN, 0)
		knee.add_child(ankle)
		_ankles.append(ankle)
		_box(ankle, Vector3(0.14 * w, 0.1, 0.24), Vector3(0, -0.05, 0.04), leather)
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
	_mouth = _box(head, Vector3(0.05, 0.008, 0.01), Vector3(0, -0.058, 0.105), _mat(SKINS[L.skin].darkened(0.55)))
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
	# Gear of the waste over the face
	if int(L.get("eyes", 0)) == 1:
		var glass := _mat(Color(0.75, 0.55, 0.3), 0.5, 0.15)
		for side in [-1, 1]:
			_cyl(head, 0.03, 0.03, Vector3(0.045 * side, 0.025, 0.115), glass, Vector3(PI / 2, 0, 0))
		var strap := _cyl(head, 0.125, 0.025, Vector3(0, 0.025, 0), leather, Vector3.ZERO)
		strap.scale = Vector3(0.95, 1, 1.0)
	if int(L.get("mask", 0)) == 1:
		_box(head, Vector3(0.15, 0.08, 0.06), Vector3(0, -0.05, 0.1), _mat(Color(0.42, 0.46, 0.34), 0.0, 0.9))
		_cyl(head, 0.035, 0.05, Vector3(0, -0.06, 0.14), _mat(Color(0.25, 0.25, 0.22), 0.4, 0.5), Vector3(PI / 2, 0, 0))
	match int(L.get("neck", 0)):
		1:
			_cyl(self, 0.09, 0.08, Vector3(0, 1.56, 0), _mat(Color(0.72, 0.6, 0.45), 0.0, 1.0), Vector3.ZERO)
			_box(head, Vector3(0.2, 0.1, 0.05), Vector3(0, -0.07, 0.1), _mat(Color(0.72, 0.6, 0.45), 0.0, 1.0))
		2:
			_cyl(self, 0.1, 0.1, Vector3(0, 1.55, 0), cloth2, Vector3.ZERO)
			_box(self, Vector3(0.07, 0.3, 0.02), Vector3(0.07, 1.36, 0.13), cloth2)
	# What hangs below the hips: on legs that bend, from a node of its own at the hips
	var lo: Node3D = self
	var lo_y := 0.0
	if bends:
		_skirt = Node3D.new()
		_skirt.position = Vector3(0, HIP_Y, 0)
		add_child(_skirt)
		lo = _skirt
		lo_y = HIP_Y
	match int(L.get("cloak", 0)):
		1, 2:
			var cc := _mat(Color(0.45, 0.14, 0.1), 0.0, 0.9) if int(L.cloak) == 1 else _mat(dye.darkened(0.5), 0.0, 0.95)
			var cl := _box(lo, Vector3(0.58 * w, 1.2, 0.04), Vector3(0, 0.88 - lo_y, -0.17), cc)
			cl.rotation.x = 0.07
			_box(self, Vector3(0.5 * w, 0.1, 0.3), Vector3(0, 1.48, -0.02), cc)
	# The coat over all
	match L.coat:
		0:
			_cyl(lo, 0.2 * w, 1.15, Vector3(0, 0.62 - lo_y, 0), cloth, Vector3.ZERO, 0.42 * w)
			_box(self, Vector3(0.44 * w, 0.5, 0.25), Vector3(0, 1.25, 0), cloth)
		1:
			_box(self, Vector3(0.44 * w, 0.62, 0.26), Vector3(0, 1.22, 0), cloth)
			_box(lo, Vector3(0.46 * w, 0.5, 0.27), Vector3(0, 0.68 - lo_y, 0), cloth)
			_box(self, Vector3(0.03, 0.9, 0.01), Vector3(0, 1.0, 0.14), cloth2)
		2:
			_box(self, Vector3(0.45 * w, 0.6, 0.27), Vector3(0, 1.2, 0), cloth)
			for side in [-1, 1]:
				_box(self, Vector3(0.1, 0.08, 0.02), Vector3(0.1 * side, 1.12, 0.14), cloth2)
		3:
			_box(self, Vector3(0.44 * w, 0.62, 0.26), Vector3(0, 1.22, 0), cloth)
			_box(lo, Vector3(0.5 * w, 0.85, 0.27), Vector3(0, 0.52 - lo_y, 0), cloth)
			_box(self, Vector3(0.52 * w, 0.22, 0.3), Vector3(0, 1.42, 0), cloth2)
		4:
			_box(self, Vector3(0.42 * w, 0.58, 0.24), Vector3(0, 1.22, 0), cloth2)
			var cape := _box(lo, Vector3(0.56 * w, 1.15, 0.04), Vector3(0, 0.88 - lo_y, -0.16), cloth)
			cape.rotation.x = 0.06
			for i in 4:
				_box(lo, Vector3(0.1, 0.12, 0.04), Vector3((i - 1.5) * 0.13 * w, 0.27 - lo_y, -0.19), cloth)
	# Arms, from the shoulder, holding forward
	for side in [-1, 1]:
		var sh := Node3D.new()
		sh.position = Vector3(0.25 * side * w, 1.45, 0)
		add_child(sh)
		_arms.append(sh)
		_box(sh, Vector3(0.11, 0.56, 0.12), Vector3(0, -0.27, 0), cloth if L.coat != 4 else cloth2)
		_sphere(sh, 0.05 if int(L.get("hands", 0)) == 0 else 0.056, Vector3(0, -0.58, 0.0), skin if int(L.get("hands", 0)) == 0 else leather)
	hand_r = Node3D.new()
	_arms[1].add_child(hand_r)
	hand_r.position = Vector3(0, -0.58, 0.05)
	# The townsfolk's dress: trim, apron or tabard, and what they carry
	var tc: Color = TRIMS[int(L.get("trim", 0))]
	if tc.a > 0.0:
		var trim := _mat(tc, 0.0, 0.85)
		_box(self, Vector3(0.47 * w, 0.06, 0.29), Vector3(0, 0.96, 0), trim)
		_box(self, Vector3(0.3 * w, 0.05, 0.27), Vector3(0, 1.5, 0.01), trim)
		for sh in _arms:
			_box(sh, Vector3(0.125, 0.06, 0.135), Vector3(0, -0.5, 0), trim)
	match int(L.get("apron", 0)):
		1:
			var la := _mat(Color(0.3, 0.19, 0.11), 0.0, 0.7)
			_box(self, Vector3(0.36 * w, 0.75, 0.02), Vector3(0, 0.82, 0.155), la)
			_box(self, Vector3(0.02, 0.32, 0.02), Vector3(0.1, 1.38, 0.15), la)
			_box(self, Vector3(0.02, 0.32, 0.02), Vector3(-0.1, 1.38, 0.15), la)
		2:
			_box(self, Vector3(0.34 * w, 0.55, 0.02), Vector3(0, 0.7, 0.155), _mat(Color(0.72, 0.68, 0.6), 0.0, 1.0))
		3:
			var tb := _mat(tc if tc.a > 0.0 else dye.lightened(0.25), 0.0, 0.9)
			_box(self, Vector3(0.3 * w, 0.95, 0.02), Vector3(0, 1.02, 0.16), tb)
			_box(self, Vector3(0.3 * w, 0.95, 0.02), Vector3(0, 1.02, -0.16), tb)
			_sphere(self, 0.05, Vector3(0, 1.22, 0.175), _mat(Color(0.85, 0.75, 0.45), 0.6, 0.4)).scale = Vector3(1, 1, 0.3)
	_hold_item(L)
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
	# Each part that moves as one (the body, the head, each leg and arm) is joined into one mesh, so
	# a figure is drawn in a handful of calls instead of thirty: a town full of folk stays light.
	for part in [self, head] + _legs + _knees + _ankles + _arms + ([_skirt] if _skirt else []):
		_join(part)
	for c in find_children("*", "MeshInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static var _matte: StandardMaterial3D
static var no_join := false   ## testing aid: leave the pieces apart


## The plain-coloured pieces right under `p` become one mesh, each keeping its colour in the mesh.
## Shining, glowing and moving pieces (metal, a lamp, the mouth) stay as they are.
func _join(p: Node3D) -> void:
	if no_join:
		return
	var parts: Array = []
	for c in p.get_children():
		if c is MeshInstance3D and c != _mouth and c.get_child_count() == 0 and c.mesh is PrimitiveMesh:
			var m = (c as MeshInstance3D).material_override
			if m is StandardMaterial3D and m.metallic == 0.0 and not m.emission_enabled:
				parts.append(c)
	if parts.size() < 2:
		return
	if _matte == null:
		_matte = StandardMaterial3D.new()
		_matte.vertex_color_use_as_albedo = true
		_matte.vertex_color_is_srgb = true
		_matte.roughness = 0.85
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for c in parts:
		var mi := c as MeshInstance3D
		var a: Array = mi.mesh.surface_get_arrays(0)
		var t: Transform3D = mi.transform
		var nb: Basis = t.basis.inverse().transposed()
		var col: Color = (mi.material_override as StandardMaterial3D).albedo_color
		var base := verts.size()
		var vv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		for i in vv.size():
			verts.append(t * vv[i])
			norms.append((nb * nn[i]).normalized())
			cols.append(col)
		var ii = a[Mesh.ARRAY_INDEX]
		if ii == null or (ii as PackedInt32Array).is_empty():
			for i in vv.size():
				idx.append(base + i)
		else:
			for i in (ii as PackedInt32Array):
				idx.append(base + i)
		p.remove_child(mi)
		mi.free()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var out := MeshInstance3D.new()
	out.mesh = am
	out.material_override = _matte
	p.add_child(out)


## What the look carries in the hand, hung from it.
func _hold_item(L: Dictionary) -> void:
	var held: Array = HELD[int(L.get("held", 0))]
	if not held.is_empty() and hand_r:
		# (a real hand is smaller than the shapes' mitten: what it holds is too)
		var k := float(held[2]) * (0.6 if person else 1.0)
		var it := WIsleLife.put(hand_r, held[0], held[1], Vector3(0, -0.04, 0.02), 0.0, k, false, Vector3.ZERO, null, 80.0)
		var bb := WIsleLife.bounds(held[0] + "/" + held[1], it)
		it.position -= Vector3(bb.get_center().x, bb.end.y, bb.get_center().z) * k - Vector3(0, 0.06 if not person else 0.02, 0)


func _process(delta: float) -> void:
	if person:
		# Its owner turns the stride's phase as it goes (5.5 a metre): that is its pace over the ground
		person.pace = (walk - _walk_was) / maxf(delta, 0.001) / 5.5 * minf(stride * 1.5, 1.0)
		_walk_was = walk
		person.talking = talk_t > 0.0
		if talk_t > 0.0:
			talk_t -= delta
		return
	if _legs.size() < 2:
		return
	if _mouth:
		# The mouth opens and closes with the murmur of the words, then rests shut
		if talk_t > 0.0:
			talk_t -= delta
			_talk_ph += delta
			var open := absf(sin(_talk_ph * 13.0)) * (0.6 + 0.4 * sin(_talk_ph * 4.3))
			_mouth.scale.y = 1.0 + maxf(open, 0.0) * 3.2
			_mouth.position.y = -0.058 - _mouth.scale.y * 0.002
		elif _mouth.scale.y != 1.0:
			_mouth.scale.y = move_toward(_mouth.scale.y, 1.0, delta * 20.0)
			_mouth.position.y = -0.058 - _mouth.scale.y * 0.002
	var s := sin(walk) * 0.55 * stride
	if seated:
		s = 0.0
		for leg in _legs:
			leg.rotation = Vector3(-0.45, 0, signf(leg.position.x) * 0.55)
	else:
		_legs[0].rotation = Vector3(s, 0, 0)
		_legs[1].rotation = Vector3(-s, 0, 0)
		if crouch > 0.001 and ground and _knees.size() == 2:
			_crouch_legs()
		elif _knees.size() == 2 and _knees[0].rotation.x != 0.0:
			for i in 2:
				_knees[i].rotation = Vector3.ZERO
				_ankles[i].basis = Basis()
			if _skirt:
				_skirt.basis = Basis()
	if hold:
		var pts := [fore_at, grip_at]
		for i in 2:
			var sh: Node3D = _arms[i]
			var t: Vector3 = pts[i] - Vector3(0, SHOULDER_Y, 0)
			t = t.rotated(Vector3.RIGHT, aim) + Vector3(0, SHOULDER_Y, 0)
			# The arm reaches just as far as the hold (0.58 is its length to the middle of the hand)
			var k := clampf((t - sh.position).length() / 0.58, 0.6, 1.25)
			sh.basis = Basis(Quaternion(Vector3.DOWN, (t - sh.position).normalized())) * Basis.from_scale(Vector3(1, k, 1))
		return
	for sh in _arms:
		if (sh as Node3D).scale != Vector3.ONE:
			(sh as Node3D).scale = Vector3.ONE
	var fwd := -1.15 if arms_forward else 0.0
	_arms[0].rotation.x = fwd * 0.85 - s * (0.2 if arms_forward else 0.6)
	_arms[1].rotation.x = fwd + s * (0.15 if arms_forward else 0.6)
	_arms[0].rotation.z = -0.35 if arms_forward else 0.05
	_arms[1].rotation.z = 0.15 if arms_forward else -0.05


## The legs crouched: each ankle is put where its foot stands (or steps, walking), and the hip and
## knee bend to reach it, the knee forward; the foot is kept flat. A stance foot goes back exactly as
## fast as the body goes on, so it stays put on the ground.
func _crouch_legs() -> void:
	var gt := global_transform.affine_inverse() * ground.global_transform   # the ground's frame, here
	var gi := gt.affine_inverse()
	var up := gt.basis.y.normalized()
	var fwd := (Vector3.BACK - up * up.dot(Vector3.BACK)).normalized()
	var flat := Basis(up.cross(fwd), up, fwd)
	if _skirt:
		# Coat tails and cloak hang straight down from the hips and gather on the ground
		var hy: float = (gi * _skirt.position).y
		_skirt.basis = Basis(flat.x, flat.y * clampf(hy / HIP_Y, 0.3, 1.0), flat.z)
	var go := Vector3(going.x, 0.0, going.y)
	var amp := clampf(stride * 6.0, 0.0, 1.0)   # full steps from half a metre a second (stride is pace / 3)
	var w := smoothstep(0.0, 0.35, crouch)
	for i in 2:
		var hip: Node3D = _legs[i]
		var hg: Vector3 = gi * hip.position
		var f := fposmod(trod / (STEP * 2.0) + 0.5 * i, 1.0)
		var off := 0.0
		var lift := 0.0
		if f < 0.5:
			off = lerpf(STEP * 0.5, -STEP * 0.5, f / 0.5)   # on the ground, going back under the body
		else:
			var u := (f - 0.5) / 0.5
			off = lerpf(-STEP * 0.5, STEP * 0.5, smoothstep(0.0, 1.0, u))   # lifted and brought through
			lift = sin(u * PI) * 0.08
		var foot := Vector3(hg.x * 1.2, 0.1 + lift * amp, hg.z + (0.12 if i == 0 else -0.04)) + go * off * amp
		var to: Vector3 = gt * foot - hip.position
		var d := clampf(to.length(), 0.08, THIGH + SHIN - 0.002)
		var dn := to.normalized()
		var sd := (Vector3.RIGHT - dn * dn.dot(Vector3.RIGHT)).normalized()
		var a := acos(clampf((THIGH * THIGH + d * d - SHIN * SHIN) / (2.0 * THIGH * d), -1.0, 1.0))
		var bend := PI - acos(clampf((THIGH * THIGH + SHIN * SHIN - d * d) / (2.0 * THIGH * SHIN), -1.0, 1.0))
		var hb := Basis(sd, -dn, sd.cross(-dn)) * Basis(Vector3.RIGHT, -a)
		var kb := Basis(Vector3.RIGHT, bend)
		hip.basis = Basis(hip.basis.get_rotation_quaternion().slerp(hb.get_rotation_quaternion(), w))
		_knees[i].basis = Basis(Vector3.RIGHT, bend * w)
		var ab := (hb * kb).inverse() * flat
		_ankles[i].basis = Basis(Quaternion.IDENTITY.slerp(ab.get_rotation_quaternion(), w))


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
