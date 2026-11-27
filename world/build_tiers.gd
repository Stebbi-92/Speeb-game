class_name WBuildTiers
## What may be built, and when. A new world builds only a camp: a fire, a torch, a bedroll, a chest, a bench
## and a timber shelter. Each fire lit opens the next rung of building, and the rarer stuff of the harder
## lands pays for it (gameplay bible: "every milestone pays with a new verb"; "locked recipes show what
## they need"). Everything here goes by the world, so the whole fellowship climbs together.
##
## Unlock rules, all in one place. A rung's "need" holds any of:
##   fires: the most beacons that have ever burned in this world (Wasteland.most_lit)
##   great: how many great ones have fallen in this world (any land; their lair flags)
##   flag:  a world flag, such as a book read

const RUNGS := [
	{"name": "Cast out", "need": {}, "hour": 0,
		"pieces": ["campfire", "torch", "bedroll", "chest", "bench", "floor", "wall", "doorway", "door", "roof", "spikes"]},
	{"name": "Restraint", "need": {"fires": 1}, "hour": 1,
		"pieces": ["cookpot", "tent", "barrel", "window", "stairs", "stonewall", "table", "chair", "rug"]},
	{"name": "Humility", "need": {"fires": 2}, "hour": 5,
		"pieces": ["bed", "shelf", "lamp", "floorlamp", "stove", "palisade", "brazier", "strongbox", "watchtower"]},
	{"name": "Bounty", "need": {"fires": 3}, "hour": 12,
		"pieces": ["planter", "anvil", "banner", "barricade"]},
	{"name": "The Swift Cast", "need": {"fires": 4}, "hour": 22,
		"pieces": ["portal", "lamppost"]},
	{"name": "A great one's trophy", "need": {"great": 1}, "hour": 8,
		"pieces": ["shrine"]},
	{"name": "Three great ones", "need": {"great": 3}, "hour": 25,
		"pieces": ["trophy_hall"]},
]

## Building walls, windows, doorways and floors up: [name, health x, cost, need]. Each step wants the
## stuff of a harder land and a fire further down the road.
const MATERIALS := [
	{"name": "Timber", "hp": 1.0, "cost": {}, "need": {}},
	{"name": "Stone", "hp": 2.2, "cost": {"stone": 12, "wood": 2}, "need": {"fires": 1}},
	{"name": "Iron", "hp": 3.5, "cost": {"scrap": 8, "red_iron": 3, "stone": 2}, "need": {"fires": 3}},
	{"name": "Blackglass", "hp": 5.0, "cost": {"obsidian": 3, "tar": 2, "stone": 4}, "need": {"fires": 5}},
]

const ORDINAL := ["", "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth"]


## The rung a piece sits on, or -1 for a piece outside the rungs (always open).
static func rung_of(k: String) -> int:
	for i in RUNGS.size():
		if k in RUNGS[i].pieces:
			return i
	return -1


## How many great ones have fallen in this world: each leaves its lair's day in the world's flags.
static func great_felled(w) -> int:
	var n := 0
	for f in w.flags:
		if str(f).begins_with("lair_"):
			n += 1
	return n


## Whether a need is met in this world.
static func met(w, need: Dictionary) -> bool:
	if need.has("fires") and not w.has_verb(int(need.fires)):
		return false
	if need.has("great") and great_felled(w) < int(need.great):
		return false
	if need.has("flag") and not w.flags.has(str(need.flag)):
		return false
	return true


## A need in a few plain words: "Light the second fire".
static func need_text(need: Dictionary) -> String:
	var parts: Array = []
	if need.has("fires"):
		parts.append("Light the %s fire" % ORDINAL[clampi(int(need.fires), 0, 9)])
	if need.has("great"):
		var g := int(need.great)
		parts.append("Fell a great one" if g == 1 else "Fell %d great ones" % g)
	if need.has("flag"):
		parts.append("Read %s" % Items.iname(str(need.flag)))
	return " and ".join(parts) if not parts.is_empty() else ""


static func open(w, k: String) -> bool:
	var r := rung_of(k)
	return r < 0 or met(w, RUNGS[r].need)


## What still bars a piece, in a short line ("Light the second fire"), or "" if it can be built.
static func why(w, k: String) -> String:
	var r := rung_of(k)
	if r < 0 or met(w, RUNGS[r].need):
		return ""
	return need_text(RUNGS[r].need)


## The pieces this world may build now, in the build order.
static func open_pieces(w) -> Array:
	return Items.PIECE_ORDER.filter(func(k): return open(w, k))


## What bars building a piece up to material t, or "" if nothing does.
static func material_why(w, t: int) -> String:
	if t <= 0 or t >= MATERIALS.size():
		return ""
	var need: Dictionary = MATERIALS[t].need
	return "" if met(w, need) else need_text(need)


## Every check of the rungs and the materials, for the wiki and the report: [rung, pieces, need, hour].
static func table() -> Array:
	var out: Array = []
	for r in RUNGS:
		out.append([r.name, r.pieces, need_text(r.need), int(r.hour)])
	return out
