class_name AmmoLook
extends RefCounted
## Rounds, spent cases and shotgun shells from "Free Ammo Set Ver.2 ULTRA" (Rotten Design, CC-BY 4.0), each
## gun's own: the cases a gun throws out as it fires, and the piles of spilled rounds found in the waste.

const PATH := "res://assets/models/arms/ammo/ammo.glb"
const SCALE := 0.14
## The pack's pieces for each calibre: [bullet, case]. A shotgun shell is one piece.
const CAL := {
	"9x19": ["Cube_001", "Cube_002"], "454": ["Cube_013", "Cube_014"], "556": ["Cube_015", "Cube_016"],
	"762x51": ["Cube_009", "Cube_010"], "762x54r": ["Cube_023", "Cube_024"], "shell": ["Circle", "Circle_002"],
}
const SPENT_SHELL := "Circle_008"
## What each gun fires
const GUN_CAL := {"pistol": "9x19", "smg": "9x19", "pistol9": "9x19", "revolver": "454", "machine_gun": "556", "lmg": "762x51", "minigun": "762x51",
	"sniper": "762x54r", "shotgun": "shell", "autoshotgun": "shell", "carbine": "762x51", "hand_cannon": "shell"}
## The calibres a heap of each kind of ammunition shows
const ITEM_CAL := {"shells": ["shell"], "rounds": ["9x19", "454"], "rifle": ["556", "762x51", "762x54r"]}

static var _inst: Node3D = null
static var _meshes := {}   # piece -> [[mesh, transform], ...], centred and scaled


static func _piece(name: String) -> Array:
	if _meshes.has(name):
		return _meshes[name]
	var out: Array = []
	if _inst == null and ResourceLoader.exists(PATH):
		_inst = (load(PATH) as PackedScene).instantiate()
	if _inst != null:
		var src := _inst.find_child(name, true, false)
		if src != null:
			var bb := AABB()
			var first := true
			for mi in src.find_children("*", "MeshInstance3D", true, false):
				var tr: Transform3D = Arms._chain(mi, _inst)
				tr = Transform3D(tr.basis.scaled(Vector3.ONE * SCALE), tr.origin * SCALE)
				out.append([(mi as MeshInstance3D).mesh, tr])
				var a: AABB = tr * (mi as MeshInstance3D).mesh.get_aabb()
				bb = a if first else bb.merge(a)
				first = false
			# Stood on its base, its middle at the origin
			for e in out:
				e[1] = Transform3D(Basis.IDENTITY, -bb.get_center()) * e[1]
			# The shells lie along their length in the pack; stand them up like the rest
			if not first and bb.size.z > bb.size.y * 1.5:
				for e in out:
					e[1] = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO) * e[1]
	_meshes[name] = out
	return out


## One piece as a node of its own (a holder with its meshes), or null if the pack is missing.
static func make(name: String) -> Node3D:
	var parts := _piece(name)
	if parts.is_empty():
		return null
	var h := Node3D.new()
	for e in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = e[0]
		mi.transform = e[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.add_child(mi)
	return h


## The spent case a gun throws out, or "" if it throws none.
static func spent_of(gun: String) -> String:
	var c: String = GUN_CAL.get(ArmsDB.look(gun), "")
	if c == "":
		return ""
	return SPENT_SHELL if c == "shell" else CAL[c][1]


## A whole round of a calibre: case and bullet together.
static func round_of(cal: String) -> Node3D:
	var c: Array = CAL[cal]
	var h := make(c[1])
	if h == null:
		return null
	if cal == "shell":
		var crimp := make(c[0])
		if crimp != null:
			h.add_child(crimp)
		return h
	var b := make(c[0])
	if b != null:
		# The bullet sits in the case's mouth
		var case_h := _height(c[1])
		var b_h := _height(c[0])
		b.position.y = case_h * 0.5 + b_h * 0.5 - b_h * 0.25
		h.add_child(b)
	return h


static func _height(name: String) -> float:
	var bb := AABB()
	var first := true
	for e in _piece(name):
		var a: AABB = e[1] * (e[0] as Mesh).get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	return bb.size.y


## A heap of rounds of one kind of ammunition, spilled on the ground: some standing, most lying.
static func pile(item: String, r: RandomNumberGenerator, count := 22) -> Node3D:
	var root := Node3D.new()
	var cals: Array = ITEM_CAL.get(item, ["556"])
	for i in count:
		var cal: String = cals[r.randi() % cals.size()]
		var rd := round_of(cal)
		if rd == null:
			break
		var ang := r.randf() * TAU
		var dist := sqrt(r.randf()) * 0.32
		var lying := r.randf() < 0.75
		var h := 0.03 if cal != "shell" else 0.05
		rd.position = Vector3(cos(ang) * dist, h * 0.5 if lying else h, sin(ang) * dist)
		if lying:
			rd.rotation = Vector3(PI * 0.5, r.randf() * TAU, 0)
			rd.rotate_y(r.randf() * TAU)
		else:
			rd.rotation.y = r.randf() * TAU
		root.add_child(rd)
	return root
