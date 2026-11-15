class_name WArms
extends RefCounted
## The arms of a survivor in the Ashen Waste. Nothing here is unlocked by rank: guns, blades and
## kit are made at a workbench, fitted with parts, and worked on to make them better.

const START := {
	"owned": ["shotgun", "pistol"], "blades": ["hatchet"], "thrown": ["frag"], "kits": ["bandages"],
	"parts": {}, "mounts": {}, "tier": {}, "grade": {},
	"primary": "shotgun", "secondary": "pistol", "melee": "hatchet", "grenade": "frag", "gadget": "bandages",
	"wear": {}, "relics": [],
}

## Relics a survivor can make at a workbench. The lantern and the praying hands are carried from the start.
const RELICS := {
	"claw": {"name": "Claw of Ascent", "cost": {"scrap": 14, "cloth": 4, "oil": 1}, "text": "Cast it at a wall, rock or roof to pull yourself up."},
	"censer": {"name": "Censer", "cost": {"scrap": 8, "salt": 12, "oil": 2}, "text": "Its smoke shows nearby forms, slows them and draws lurkers out."},
}

## What may be worn: head, body and feet. "guard" is the share of harm it turns aside.
## "speed" changes the stride, "hunger" how fast the belly empties, "weary" how fast the body tires.
const WEAR := {
	"hood": {"name": "Pilgrim's Hood", "slot": "head", "guard": 0.03, "cost": {"cloth": 3}, "look": {"head": 1}, "text": "Keeps the ash out of your eyes."},
	"wide_hat": {"name": "Wide-brim Hat", "slot": "head", "guard": 0.03, "weary": 0.85, "cost": {"cloth": 3, "bone": 1}, "look": {"head": 2}, "text": "Shade from the sun. You tire more slowly."},
	"iron_helm": {"name": "Iron Helm", "slot": "head", "guard": 0.12, "plate": 50, "cost": {"scrap": 10, "cloth": 1}, "look": {"head": 4}, "text": "Heavy, and it rings when struck. Dents, and can be beaten out at the bench."},
	"gas_mask": {"name": "Gas Mask", "slot": "head", "guard": 0.06, "hunger": 0.9, "cost": {"scrap": 6, "cloth": 2, "oil": 1}, "look": {"head": 5}, "text": "Old rubber and glass. The air tastes of nothing."},
	"padded_coat": {"name": "Padded Coat", "slot": "body", "guard": 0.08, "cost": {"cloth": 6}, "look": {"coat": 2}, "text": "Quilted cloth. Turns a claw, now and then."},
	"duster": {"name": "Oilcloth Duster", "slot": "body", "guard": 0.06, "hunger": 0.85, "cost": {"cloth": 8, "oil": 1}, "look": {"coat": 3}, "text": "Long and waxed. Keeps the body's warmth in."},
	"bone_mail": {"name": "Bone Mail", "slot": "body", "guard": 0.15, "speed": 0.97, "plate": 70, "cost": {"bone": 12, "cloth": 4}, "look": {"coat": 4}, "text": "Plates of bone sewn on leather. Clatters as you walk."},
	"scrap_plate": {"name": "Scrap Plate", "slot": "body", "guard": 0.24, "speed": 0.92, "weary": 1.15, "plate": 120, "cost": {"scrap": 18, "cloth": 4}, "look": {"coat": 1}, "text": "Iron from before the fall, hammered to fit. It weighs on you."},
	"salt_plate": {"name": "Salt-crust Plate", "slot": "body", "guard": 0.3, "speed": 0.94, "weary": 1.1, "plate": 200, "cost": {"scrap": 24, "stone": 8, "hide": 4}, "look": {"coat": 1}, "text": "Iron plates cured in salt until they turn a blade. The best the waste can make."},
	"wraps": {"name": "Foot Wraps", "slot": "feet", "guard": 0.01, "speed": 1.03, "cost": {"cloth": 2}, "text": "Better than bare feet on hot ash."},
	"boots": {"name": "Hobnail Boots", "slot": "feet", "guard": 0.04, "speed": 1.05, "cost": {"cloth": 2, "bone": 2, "scrap": 3}, "text": "Sure footing. You walk faster."},
}
const WEAR_SLOTS := [["head", "Head"], ["body", "Body"], ["feet", "Feet"]]


## The sum of what is worn: guard, and the speed, hunger and weariness it brings.
static func worn(a: Dictionary) -> Dictionary:
	var out := {"guard": 0.0, "speed": 1.0, "hunger": 1.0, "weary": 1.0}
	for slot in a.get("wear", {}):
		var it: Dictionary = WEAR.get(str(a.wear[slot]), {})
		# Broken plate still covers a little, but not much
		out.guard += float(it.get("guard", 0.0)) * (0.35 if plate_left(a, slot) == 0.0 else 1.0)
		for k in ["speed", "hunger", "weary"]:
			out[k] *= float(it.get(k, 1.0))
	out.guard = minf(out.guard, 0.45)
	return out

## What is left of the plate worn in a slot: -1 if it has none, else the points it can still soak.
static func plate_left(a: Dictionary, slot: String) -> float:
	# Kept by the piece, not the slot, so taking it off and on mends nothing
	var id := str(a.get("wear", {}).get(slot, ""))
	var it: Dictionary = WEAR.get(id, {})
	if not it.has("plate"):
		return -1.0
	return float(a.get("plate", {}).get(id, it.plate))


## A blow on worn plate: it soaks part of the harm and is worn down. Returns the harm that gets
## through, and whether a plate broke. A blow to the head lands on the helm, the rest on the body.
static func plate_take(a: Dictionary, amount: float, head: bool) -> Array:
	var slot := "head" if head else "body"
	var left := plate_left(a, slot)
	if left <= 0.0:
		return [amount, false]
	var soak := amount * 0.5
	if not a.has("plate"):
		a["plate"] = {}
	var id := str(a.wear[slot])
	a.plate[id] = maxf(0.0, left - soak)
	return [amount - soak * 0.6, a.plate[id] <= 0.0]


## Beats the plate in a slot back to whole.
static func mend(a: Dictionary, slot: String) -> void:
	if a.has("plate"):
		a.plate.erase(str(a.get("wear", {}).get(slot, "")))


## What mending a slot's plate back to whole costs: scrap by the damage done.
static func mend_cost(a: Dictionary, slot: String) -> Dictionary:
	var it: Dictionary = WEAR.get(str(a.get("wear", {}).get(slot, "")), {})
	if not it.has("plate"):
		return {}
	var missing := float(it.plate) - plate_left(a, slot)
	if missing < 1.0:
		return {}
	return {"scrap": maxi(1, int(ceil(missing / 12.0)))}


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
	"long_barrel": {"scrap": 12, "oil": 1},
	"sawn_barrel": {"scrap": 6},
	"heavy_barrel": {"scrap": 16, "stone": 4},
	"light_stock": {"scrap": 8, "cloth": 1},
	"padded_stock": {"wood": 6, "hide": 2},
	"heavy_stock": {"wood": 12, "scrap": 2},
	"rapid_receiver": {"scrap": 14, "oil": 2},
	"heavy_receiver": {"scrap": 18, "bone": 4},
	"smooth_receiver": {"scrap": 10, "oil": 3},
	"piercing_rounds": {"scrap": 12, "stone": 4},
	"hollow_rounds": {"scrap": 6, "bone": 3},
}

## Which of the waste's own parts each gun can take.
const FRAME := {
	"shotgun": ["long_barrel", "sawn_barrel", "heavy_barrel", "light_stock", "padded_stock", "heavy_stock", "rapid_receiver", "heavy_receiver", "smooth_receiver", "piercing_rounds", "hollow_rounds"],
	"machine_gun": ["long_barrel", "heavy_barrel", "light_stock", "padded_stock", "heavy_stock", "rapid_receiver", "heavy_receiver", "smooth_receiver", "piercing_rounds", "hollow_rounds"],
	"sniper": ["long_barrel", "heavy_barrel", "light_stock", "padded_stock", "heavy_stock", "heavy_receiver", "smooth_receiver", "piercing_rounds", "hollow_rounds"],
	"rocket": ["smooth_receiver"],
	"minigun": ["heavy_barrel", "rapid_receiver", "heavy_receiver", "piercing_rounds", "hollow_rounds"],
	"pistol": ["long_barrel", "heavy_barrel", "rapid_receiver", "heavy_receiver", "smooth_receiver", "piercing_rounds", "hollow_rounds"],
	"revolver": ["long_barrel", "sawn_barrel", "heavy_receiver", "smooth_receiver", "piercing_rounds", "hollow_rounds"],
}

## Grades of a part. A part made plainly at the bench is Plain; fittings found in the waste rework it
## into a better grade, each with more traits, drawn at random.
const GRADES := [
	{"name": "Plain", "color": Color(0.85, 0.83, 0.78), "traits": 0, "power": 0.0},
	{"name": "Fine", "color": Color(0.45, 0.8, 0.4), "traits": 1, "power": 1.0},
	{"name": "Rare", "color": Color(0.4, 0.62, 0.95), "traits": 2, "power": 1.3},
	{"name": "Storied", "color": Color(0.95, 0.75, 0.3), "traits": 3, "power": 1.6},
]
## The fittings that rework a part into each grade (by grade index).
const FITTINGS := {1: "fittings_fine", 2: "fittings_rare", 3: "fittings_storied"}

## Traits a graded part may carry. Each pushes one thing a little; a higher grade pushes it further.
const TRAITS := {
	"keen": {"name": "Keen", "mods": {"dmg": 1.07}, "text": "harm"},
	"swift": {"name": "Swift", "mods": {"rate": 0.94}, "text": "fire rate"},
	"steady": {"name": "Steady", "mods": {"kick": 0.85}, "text": "less kick"},
	"true": {"name": "True", "mods": {"spread": 0.88}, "text": "tighter spread"},
	"far": {"name": "Far-reaching", "mods": {"range": 1.15}, "text": "range"},
	"nimble": {"name": "Nimble", "mods": {"reload": 0.88}, "text": "faster loading"},
	"ready": {"name": "Ready", "mods": {"aim": 1.15}, "text": "faster aim"},
	"deadeye": {"name": "Deadeye", "mods": {"crit": 1.12}, "text": "head shots"},
	"deep": {"name": "Deep", "mods": {"mag": 1.15}, "text": "rounds held"},
}
## Storied parts take a name of their own.
const STORIED := ["Ashwalker's", "Cinder-wife's", "The Hermit's", "Saltborn", "Last Light", "Ninth Vision", "Old Iron", "Dawnkeeper's", "Graveborn", "Wellspring"]
const MOD_KEYS := ["dmg", "rate", "spread", "range", "reload", "kick", "aim", "crit", "mag", "pierce"]


## Every part a gun can take here: its trial mounts and the waste's own.
static func mounts_for(g: String) -> Array:
	var out: Array = ArmsDB.GUNS[g].mounts.duplicate()
	out.append_array(FRAME.get(g, []))
	return out


## The grade of one part on one gun: {"r": grade, "t": [traits], "n": storied name}.
static func grade_of(a: Dictionary, g: String, m: String) -> Dictionary:
	var gr = a.get("grade", {}).get("%s/%s" % [g, m], {})
	return gr if gr is Dictionary else {}


static func part_name(a: Dictionary, g: String, m: String) -> String:
	var gr := grade_of(a, g, m)
	var nm: String = ArmsDB.ATTACHMENTS[m].name
	return "%s %s" % [gr.n, nm] if str(gr.get("n", "")) != "" else nm


## Draws a new grade for a part: its traits, and a name if it is storied.
static func roll_grade(r: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var pool: Array = TRAITS.keys()
	var t: Array = []
	for i in int(GRADES[r].traits):
		var k: String = pool[rng.randi() % pool.size()]
		pool.erase(k)
		t.append(k)
	var out := {"r": r, "t": t}
	if r >= 3:
		out["n"] = STORIED[rng.randi() % STORIED.size()]
	return out


## What everything fitted to a gun does to it, as multipliers (1.0 is unchanged).
static func mods(a: Dictionary, g: String) -> Dictionary:
	var out := {}
	for k in MOD_KEYS:
		out[k] = 1.0
	if not ArmsDB.GUNS.has(g):
		return out
	for m in a.get("mounts", {}).get(g, []):
		var at: Dictionary = ArmsDB.ATTACHMENTS.get(m, {})
		var md: Dictionary = at.get("mods", {})
		for k in md:
			out[k] *= float(md[k])
		var gr := grade_of(a, g, m)
		var pw: float = GRADES[clampi(int(gr.get("r", 0)), 0, 3)].power
		for tid in gr.get("t", []):
			var tm: Dictionary = TRAITS.get(tid, {}).get("mods", {})
			for k in tm:
				out[k] *= 1.0 + (float(tm[k]) - 1.0) * pw
	return out


## Plain words for a set of mods, e.g. "+8% harm, -15% kick".
static func mods_text(md: Dictionary) -> String:
	var words := {"dmg": "harm", "rate": "fire rate", "spread": "spread", "range": "range", "reload": "loading", "kick": "kick", "aim": "aim speed", "crit": "head shots", "mag": "rounds", "pierce": "through plate"}
	var parts: Array = []
	for k in MOD_KEYS:
		var v := float(md.get(k, 1.0))
		if is_equal_approx(v, 1.0):
			continue
		var pct := (v - 1.0) * 100.0
		if k in ["rate", "reload"]:
			pct = (1.0 / v - 1.0) * 100.0   # less time is more speed
		parts.append("%+d%% %s" % [int(round(pct)), words[k]])
	return ", ".join(parts)

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
					if m in mounts_for(g) and not m in keep and (key == "parts" or m in a.parts.get(g, [])):
						keep.append(m)
				if not keep.is_empty():
					a[key][g] = keep
	for r in d.get("relics", []):
		if RELICS.has(r) and not r in a.relics:
			a.relics.append(r)
	var wr = d.get("wear", {})
	if wr is Dictionary:
		for slot in wr:
			if WEAR.has(str(wr[slot])) and WEAR[str(wr[slot])].slot == slot:
				a.wear[slot] = str(wr[slot])
	var gd = d.get("grade", {})
	if gd is Dictionary:
		for key in gd:
			var bits := str(key).split("/")
			var v = gd[key]
			if bits.size() == 2 and bits[1] in a.parts.get(bits[0], []) and v is Dictionary:
				var r := clampi(int(v.get("r", 0)), 0, 3)
				var tr: Array = []
				for x in v.get("t", []):
					if TRAITS.has(str(x)) and not str(x) in tr:
						tr.append(str(x))
				var keep := {"r": r, "t": tr}
				if str(v.get("n", "")) != "":
					keep["n"] = str(v.n)
				a.grade[str(key)] = keep
	var t = d.get("tier", {})
	if t is Dictionary:
		for g in t:
			if ArmsDB.GUNS.has(g):
				a.tier[g] = clampi(int(t[g]), 0, 3)
	var pl = d.get("plate", {})
	if pl is Dictionary:
		a["plate"] = {}
		for slot in pl:
			if WEAR.has(str(slot)):
				a.plate[str(slot)] = maxf(0.0, float(pl[slot]))
	return a
