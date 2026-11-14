class_name WArms
extends RefCounted
## The arms of a survivor in the Ashen Waste. Nothing here is unlocked by rank: guns, blades and
## kit are made at a workbench, fitted with parts, and worked on to make them better.

const START := {
	"owned": ["shotgun", "pistol"], "blades": ["hatchet"], "thrown": ["frag"], "kits": ["bandages"],
	"parts": {}, "mounts": {}, "tier": {},
	"primary": "shotgun", "secondary": "pistol", "melee": "hatchet", "grenade": "frag", "gadget": "bandages",
	"wear": {},
}

## What may be worn: head, body and feet. "guard" is the share of harm it turns aside.
## "speed" changes the stride, "hunger" how fast the belly empties, "weary" how fast the body tires.
const WEAR := {
	"hood": {"name": "Pilgrim's Hood", "slot": "head", "guard": 0.03, "cost": {"cloth": 3}, "look": {"head": 1}, "text": "Keeps the ash out of your eyes."},
	"wide_hat": {"name": "Wide-brim Hat", "slot": "head", "guard": 0.03, "weary": 0.85, "cost": {"cloth": 3, "bone": 1}, "look": {"head": 2}, "text": "Shade from the sun. You tire more slowly."},
	"iron_helm": {"name": "Iron Helm", "slot": "head", "guard": 0.12, "cost": {"scrap": 10, "cloth": 1}, "look": {"head": 4}, "text": "Heavy, and it rings when struck."},
	"gas_mask": {"name": "Gas Mask", "slot": "head", "guard": 0.06, "hunger": 0.9, "cost": {"scrap": 6, "cloth": 2, "oil": 1}, "look": {"head": 5}, "text": "Old rubber and glass. The air tastes of nothing."},
	"padded_coat": {"name": "Padded Coat", "slot": "body", "guard": 0.08, "cost": {"cloth": 6}, "look": {"coat": 2}, "text": "Quilted cloth. Turns a claw, now and then."},
	"duster": {"name": "Oilcloth Duster", "slot": "body", "guard": 0.06, "hunger": 0.85, "cost": {"cloth": 8, "oil": 1}, "look": {"coat": 3}, "text": "Long and waxed. Keeps the body's warmth in."},
	"bone_mail": {"name": "Bone Mail", "slot": "body", "guard": 0.15, "speed": 0.97, "cost": {"bone": 12, "cloth": 4}, "look": {"coat": 4}, "text": "Plates of bone sewn on leather. Clatters as you walk."},
	"scrap_plate": {"name": "Scrap Plate", "slot": "body", "guard": 0.24, "speed": 0.92, "weary": 1.15, "cost": {"scrap": 18, "cloth": 4}, "look": {"coat": 1}, "text": "Iron from before the fall, hammered to fit. It weighs on you."},
	"wraps": {"name": "Foot Wraps", "slot": "feet", "guard": 0.01, "speed": 1.03, "cost": {"cloth": 2}, "text": "Better than bare feet on hot ash."},
	"boots": {"name": "Hobnail Boots", "slot": "feet", "guard": 0.04, "speed": 1.05, "cost": {"cloth": 2, "bone": 2, "scrap": 3}, "text": "Sure footing. You walk faster."},
}
const WEAR_SLOTS := [["head", "Head"], ["body", "Body"], ["feet", "Feet"]]


## The sum of what is worn: guard, and the speed, hunger and weariness it brings.
static func worn(a: Dictionary) -> Dictionary:
	var out := {"guard": 0.0, "speed": 1.0, "hunger": 1.0, "weary": 1.0}
	for slot in a.get("wear", {}):
		var it: Dictionary = WEAR.get(str(a.wear[slot]), {})
		out.guard += float(it.get("guard", 0.0))
		for k in ["speed", "hunger", "weary"]:
			out[k] *= float(it.get(k, 1.0))
	out.guard = minf(out.guard, 0.45)
	return out

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
	var wr = d.get("wear", {})
	if wr is Dictionary:
		for slot in wr:
			if WEAR.has(str(wr[slot])) and WEAR[str(wr[slot])].slot == slot:
				a.wear[slot] = str(wr[slot])
	var t = d.get("tier", {})
	if t is Dictionary:
		for g in t:
			if ArmsDB.GUNS.has(g):
				a.tier[g] = clampi(int(t[g]), 0, 3)
	return a
