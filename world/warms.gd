class_name WArms
extends RefCounted
## The arms of a survivor in the Ashen Waste. Nothing here is unlocked by rank: guns, blades and
## kit are made at a workbench, fitted with parts, and worked on to make them better.

const START := {
	"owned": ["shotgun", "pistol"], "blades": ["hatchet"], "thrown": ["frag"], "kits": ["bandages"],
	"parts": {}, "mounts": {}, "tier": {},
	"primary": "shotgun", "secondary": "pistol", "melee": "hatchet", "grenade": "frag", "gadget": "bandages",
}

## What each thing costs to make.
const MAKE := {
	"revolver": {"scrap": 14, "wood": 4},
	"machine_gun": {"scrap": 30, "wood": 6, "oil": 2},
	"sniper": {"scrap": 26, "wood": 12, "cloth": 4},
	"rocket": {"scrap": 40, "oil": 6, "coin": 10},
	"minigun": {"scrap": 40, "oil": 8, "coin": 20},
	"machete": {"scrap": 6, "wood": 2},
	"sledge": {"scrap": 12, "stone": 8, "wood": 4},
	"incendiary": {"oil": 2, "cloth": 2, "scrap": 2},
	"flare": {"oil": 1, "cloth": 2, "scrap": 2},
	"mine": {"scrap": 6, "salt": 10},
}

const PARTS := {
	"red_dot": {"scrap": 6, "oil": 1},
	"foregrip": {"scrap": 4, "wood": 2},
	"suppressor": {"scrap": 8, "cloth": 2},
	"ext_mag": {"scrap": 8},
	"scope": {"scrap": 10, "oil": 2},
}

const TIERS := ["Worn", "Cleaned", "Tempered", "Master-worked"]
const KINDS := [["blades", "melee", "Blade"], ["thrown", "grenade", "Thrown"], ["kits", "gadget", "Kit"]]


static func tier_cost(t: int) -> Dictionary:
	var c := {"scrap": 8 * t, "salt": 20 * t}
	if t >= 3:
		c["oil"] = 2
	return c


static func table(list: String) -> Dictionary:
	return {"blades": ArmsDB.MELEE, "thrown": ArmsDB.GRENADES, "kits": ArmsDB.GADGETS}[list]


## Makes saved arms whole again: nothing unknown, nothing carried that is not owned.
static func clean(d) -> Dictionary:
	var a: Dictionary = START.duplicate(true)
	if not d is Dictionary:
		return a
	for g in d.get("owned", []):
		if ArmsDB.GUNS.has(g) and not g in a.owned:
			a.owned.append(g)
	for k in KINDS:
		for id in d.get(k[0], []):
			if table(k[0]).has(id) and not id in a[k[0]]:
				a[k[0]].append(id)
		if str(d.get(k[1], "")) in a[k[0]]:
			a[k[1]] = str(d[k[1]])
	for slot in ["primary", "secondary"]:
		var g := str(d.get(slot, ""))
		if g in a.owned and ArmsDB.GUNS[g].slot == slot:
			a[slot] = g
	for key in ["parts", "mounts"]:
		var src = d.get(key, {})
		if src is Dictionary:
			for g in src:
				if not ArmsDB.GUNS.has(g) or not src[g] is Array:
					continue
				var keep: Array = []
				for m in src[g]:
					if m in ArmsDB.GUNS[g].mounts and not m in keep and (key == "parts" or m in a.parts.get(g, [])):
						keep.append(m)
				if not keep.is_empty():
					a[key][g] = keep
	var t = d.get("tier", {})
	if t is Dictionary:
		for g in t:
			if ArmsDB.GUNS.has(g):
				a.tier[g] = clampi(int(t[g]), 0, 3)
	return a
