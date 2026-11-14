class_name WPlaces
extends RefCounted
## The Ashen Waste: where its people dwell, where its beacons stand dead, and what lies broken between them.
## Positions are on the ground plane (x, z). The waste runs from -1024 to 1024 on each side.

const SIZE := 2048.0
const HALF := 1024.0

## The settlements. Each keeps a few souls worth speaking with.
const SETTLEMENTS := {
	"cinderwick": {
		"name": "Cinderwick", "pos": Vector2(60, 620), "radius": 34.0, "wall": Color(0.36, 0.3, 0.26),
		"blurb": "A walled camp of salt-diggers, the first to take in the cast-out.",
	},
	"lanternwell": {
		"name": "The Lantern Well", "pos": Vector2(-480, 300), "radius": 30.0, "wall": Color(0.42, 0.36, 0.28),
		"blurb": "A village gathered about a deep well, where the last oil of the waste is drawn and rendered.",
	},
	"hesk": {
		"name": "Saint Hesk's Crossing", "pos": Vector2(430, 190), "radius": 36.0, "wall": Color(0.4, 0.33, 0.27),
		"blurb": "A market at the meeting of the old roads. Everything has a price here, and salt pays it.",
	},
	"kiln": {
		"name": "The Quiet Kiln", "pos": Vector2(-320, -330), "radius": 30.0, "wall": Color(0.33, 0.28, 0.26),
		"blurb": "Smiths and potters working in the shell of a great kiln that has not been cold in forty years.",
	},
	"mourners": {
		"name": "Mourner's Rest", "pos": Vector2(530, -420), "radius": 30.0, "wall": Color(0.3, 0.3, 0.32),
		"blurb": "A camp among the graves, kept by those who still bury the dead in the old way.",
	},
	"gallowmere": {
		"name": "Gallowmere", "pos": Vector2(20, -720), "radius": 34.0, "wall": Color(0.28, 0.24, 0.22),
		"blurb": "A hard outpost on the dry bed of a lake. Its people put out the beacons, and they know it.",
	},
}

## The souls of the waste. "at" is a settlement; "off" places them within it.
## role: elder, trader, smith, healer, oilwright, gravekeeper, warden, scout, wanderer
const PEOPLE := {
	"maud": {
		"name": "Maud", "title": "Elder of Cinderwick", "at": "cinderwick", "off": Vector2(0, -8), "role": "elder", "robe": Color(0.42, 0.34, 0.3),
		"greet": "You walked out of the dust alive. Few do. Sit, if you can still bend.",
		"about": "I have kept this camp through thirty winters and eleven hundred nights. I buried my husband under the east wall, and my daughter under the west. I will not bury anyone else if I can help it.",
		"rumors": [
			"There is a dead beacon on the high ground <dir:B:0:cinderwick> of here. When it burned, nothing came out of the dark within a mile of it.",
			"The flats <dir:R:salt_caravans:cinderwick> of the camp are thick with scrap. The old caravans died there in a single night.",
			"Hesk's Crossing pays in salt for anything that was made before the fall. Keep what you find.",
		],
	},
	"tobin": {
		"name": "Tobin", "title": "Salt-digger", "at": "cinderwick", "off": Vector2(-12, 6), "role": "trader", "robe": Color(0.5, 0.45, 0.38),
		"greet": "Mind the pans. The crust breaks and the brine takes your boots.",
		"about": "I dig salt and I sell salt. When the night comes I pray with salt in my mouth. My mother said it keeps the voice of the forms out of your head. It has not yet failed me.",
		"rumors": [
			"A wagon went down in the gully <dir:R:tobin_wagon:cinderwick> of here. The driver is still in it, I think. I have not had the stomach to look.",
			"Dead trees burn hot and long. Cut them before the night and you will be glad of it.",
		],
	},
	"wren": {
		"name": "Wren", "title": "Watch of the Wall", "at": "cinderwick", "off": Vector2(14, 4), "role": "scout", "robe": Color(0.32, 0.36, 0.3),
		"greet": "Another mouth. Can you hold a gun, or only eat?",
		"about": "I keep the wall at night. I have counted every form I have put down since my brother died. The number is very large and it does not help.",
		"rumors": [
			"The forms come thickest in the hour before dawn. Save something for it.",
			"Build where you can see. A wall you cannot see over is a wall that something is already climbing.",
		],
	},
	"benedek": {
		"name": "Benedek", "title": "Oilwright of the Well", "at": "lanternwell", "off": Vector2(0, -6), "role": "oilwright", "robe": Color(0.48, 0.38, 0.22),
		"greet": "Do not bring a naked flame within ten paces of my vats.",
		"about": "My father rendered beacon oil for the Order before the Order failed. He taught me the measure of it: lamp oil, salt to cleanse it, and the ash-bloom to make it burn white. I have made very little of it since. There was no one left to carry it.",
		"rumors": [
			"Ash-bloom grows on the lee side of the dunes, where the wind cannot strip it.",
			"The well goes down further than any rope we have. On still nights you can hear something turning over at the bottom.",
		],
	},
	"sister_agna": {
		"name": "Sister Agna", "title": "Healer", "at": "lanternwell", "off": Vector2(-10, 8), "role": "healer", "robe": Color(0.62, 0.6, 0.56),
		"greet": "You are bleeding somewhere. You always are, out there.",
		"about": "I was a novice of the Silent Clerics when the night came down. The Order taught me to bind wounds and to keep silence. I have kept the first.",
		"rumors": [
			"Bind wounds with clean cloth and ash-bloom. A salve made of them will close what a bandage cannot.",
			"There was a hermit once who walked the nine trials. They say he came this way at the end of it. No one saw him leave.",
		],
	},
	"hesk_marro": {
		"name": "Marro", "title": "Factor of the Crossing", "at": "hesk", "off": Vector2(0, -10), "role": "trader", "robe": Color(0.5, 0.3, 0.24),
		"greet": "Welcome to the Crossing. Everything is for sale, and nothing is free.",
		"about": "My family has held the Crossing since before the beacons died. We traded with the Order, then with the raiders, then with whatever was left. We are still here. That is the whole of our wisdom.",
		"rumors": [
			"There is a tower <dir:R:order_tower:hesk> of the Crossing where the Order kept its records. The stair is gone but the vault is not.",
			"Gallowmere buys shells by the hundred. I would like to know why, and so would you.",
		],
	},
	"orla": {
		"name": "Orla", "title": "Caravan Mistress", "at": "hesk", "off": Vector2(12, 4), "role": "quartermaster", "robe": Color(0.36, 0.3, 0.4),
		"greet": "If you want work, I have work. If you want pity, try the Well.",
		"about": "I run the last caravan on the old roads. Three wagons, nine guards, a hundred miles of nothing. The guards change. The miles do not.",
		"rumors": [
			"The road to the Kiln passes near a field of standing stones. Do not camp among them.",
			"Things that were not forms have been seen on the salt at night. Taller, and quiet. They do not come close. Yet.",
		],
	},
	"hal": {
		"name": "Old Hal", "title": "Smith of the Kiln", "at": "kiln", "off": Vector2(0, -6), "role": "smith", "robe": Color(0.3, 0.26, 0.24),
		"greet": "Close the door. The heat is the only thing we own.",
		"about": "I have fed this kiln for forty years. It has never gone out, not once, not on the worst night. When it goes out I will go with it.",
		"rumors": [
			"Scrap from the old wagons is better iron than anything dug up now. Bring it to me.",
			"A workbench and a fire will let you make most of what you need. A good wall will let you live to use it.",
		],
	},
	"ysolde": {
		"name": "Ysolde", "title": "Potter", "at": "kiln", "off": Vector2(-12, 6), "role": "wanderer", "robe": Color(0.55, 0.42, 0.34),
		"greet": "Mind the jars. Each one holds someone's ashes.",
		"about": "When the dead cannot be buried, they are burned, and the ashes are given to me. I make them a jar. I write their name on it. There are four thousand jars at the Kiln.",
		"rumors": [
			"My brother went out <dir:R:piet_camp:kiln> of here to see if it could be lit. He did not come back. His name is Piet. I have not made his jar.",
		],
	},
	"ione": {
		"name": "Ione", "title": "Gravekeeper", "at": "mourners", "off": Vector2(0, -6), "role": "gravekeeper", "robe": Color(0.22, 0.22, 0.26),
		"greet": "You walk like someone who has been told they are alive and has not yet believed it.",
		"about": "I keep the graves and the names. I listen to the dead because no one else will. Lately they have had a great deal to say.",
		"rumors": [
			"The ground at Mourner's Rest is quiet at night. The forms do not walk on graves. I do not know why, and I do not ask.",
			"There are sealed vaults in the hills where the Order put its dead. Some were sealed from the inside.",
		],
	},
	"corvin": {
		"name": "Corvin", "title": "Warden of Gallowmere", "at": "gallowmere", "off": Vector2(0, -8), "role": "warden", "robe": Color(0.26, 0.2, 0.2),
		"greet": "You have the look of someone who has been lighting fires. Sit down before someone puts you out.",
		"about": "Gallowmere keeps the old bargain. We give the night what it asks, and it leaves us standing. You think that is cowardice. Come back when you have buried as many as I have.",
		"rumors": [
			"There is a mouth in the earth <dir:B:8:gallowmere> of here. The ninth beacon stands over it. That one was not put out. It was swallowed.",
		],
	},
	"ash_lena": {
		"name": "Lena", "title": "Ferryman's Widow", "at": "gallowmere", "off": Vector2(-12, 5), "role": "trader", "robe": Color(0.4, 0.34, 0.3),
		"greet": "There is no water left to ferry. I sell what the lake gave back when it died.",
		"about": "My husband carried people across this lake when it was a lake. When the water went, the boats went with it, and so did he. I stayed. Someone ought to remember it was blue.",
		"rumors": [
			"Corvin was the one who put out the eighth beacon. He wept while he did it. I was there.",
		],
	},
}

## The nine dead beacons. Each kindled pushes the night back from the land around it.
const BEACONS := [
	{"name": "The Beacon of Restraint", "pos": Vector2(-150, 430), "vision": "speebbang"},
	{"name": "The Beacon of Humility", "pos": Vector2(-720, 560), "vision": "emospeeb"},
	{"name": "The Beacon of Bounty", "pos": Vector2(730, 600), "vision": "speebchef"},
	{"name": "The Beacon of the Swift Cast", "pos": Vector2(-770, -40), "vision": "speebyeet"},
	{"name": "The Beacon of the Rift", "pos": Vector2(170, -70), "vision": "glitchspeeb"},
	{"name": "The Beacon of Discernment", "pos": Vector2(790, -110), "vision": "speebsnek"},
	{"name": "The Beacon of Wakefulness", "pos": Vector2(-650, -650), "vision": "floofspeeb"},
	{"name": "The Beacon of the Oath", "pos": Vector2(640, -770), "vision": "runespeeb"},
	{"name": "The Beacon of Stillness", "pos": Vector2(-180, -900), "vision": "chillspeeb"},
]
const BEACON_SAFE := 140.0

## Kinds of ruin, and what may be found in them.
const RUIN_KINDS := {
	"wreck": {"name": "Caravan wreck", "loot": "caravan", "crates": 2},
	"shrine": {"name": "Fallen shrine", "loot": "shrine", "crates": 1},
	"tower": {"name": "Broken tower", "loot": "order", "crates": 2},
	"camp": {"name": "Abandoned camp", "loot": "camp", "crates": 2},
	"vault": {"name": "Sealed vault", "loot": "vault", "crates": 3},
	"stones": {"name": "Standing stones", "loot": "shrine", "crates": 1},
}

## A handful of named ruins for the stories. The rest of the waste is scattered with nameless ones.
const NAMED_RUINS := {
	"tobin_wagon": {"name": "The Gully Wagon", "kind": "wreck", "pos": Vector2(260, 560)},
	"order_tower": {"name": "The Archive Tower", "kind": "tower", "pos": Vector2(640, 260)},
	"stone_field": {"name": "The Field of Standing Stones", "kind": "stones", "pos": Vector2(-60, -150)},
	"sealed_vault": {"name": "The Vault of the Inward Seal", "kind": "vault", "pos": Vector2(330, -560)},
	"piet_camp": {"name": "Piet's Last Camp", "kind": "camp", "pos": Vector2(-560, -560)},
	"salt_caravans": {"name": "The Salt-Pan Caravans", "kind": "wreck", "pos": Vector2(120, 470)},
}

## Rough names, for ruins the waste has forgotten.
const RUIN_WORDS_A := ["Ashen", "Broken", "Salt", "Hollow", "Silent", "Rust", "Gray", "Weeping", "Low", "Bitter", "Pale", "Sunken"]
const RUIN_WORDS_B := ["Rise", "Hollow", "Crossing", "Hill", "Gully", "Flat", "Pan", "Steps", "Ridge", "Cairn", "Bend", "Reach"]


# ================================================================== where things stand in this world

## Where the settlements, beacons and storied ruins stand: drawn afresh from each world's seed.
static var settle_at := {}
static var beacon_at: Array = []
static var ruin_at := {}
static var start := Vector2.ZERO


static func spos(k: String) -> Vector2:
	return settle_at.get(k, Vector2.ZERO)


static func bpos(i: int) -> Vector2:
	return beacon_at[i] if i < beacon_at.size() else Vector2.ZERO


static func beacon_points() -> Array:
	return beacon_at


static func rpos(k: String) -> Vector2:
	return ruin_at.get(k, Vector2.ZERO)


## Lays out the world. probe(p) gives the raw land's height and steepness there as Vector2(height, slope).
static func lay_out(seed: int, probe: Callable) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 7919 + 13
	settle_at.clear()
	beacon_at.clear()
	ruin_at.clear()
	var keys: Array = SETTLEMENTS.keys()
	var placed: Array = []
	# The first camp of the cast-out, toward one edge; the others spread apart from it and from each other
	var edge := r.randf() * TAU
	var first := _good(r, probe, func(): return Vector2(cos(edge), sin(edge)) * r.randf_range(480, 680) + Vector2(r.randf_range(-120, 120), r.randf_range(-120, 120)), placed, 0.0)
	placed.append(first)
	var others: Array = []
	for i in 5:
		var p := _good(r, probe, func(): return Vector2(r.randf_range(-780, 780), r.randf_range(-780, 780)), placed, 430.0)
		placed.append(p)
		others.append(p)
	# Gallowmere is the farthest from where the cast-out begin; the rest are dealt out in turn
	others.sort_custom(func(a, b): return a.distance_to(first) > b.distance_to(first))
	settle_at["cinderwick"] = first
	settle_at["gallowmere"] = others[0]
	var rest := ["lanternwell", "hesk", "mourners", "kiln"]
	others.remove_at(0)
	others.sort_custom(func(a, b): return a.distance_to(first) < b.distance_to(first))
	for i in rest.size():
		settle_at[rest[i]] = others[i]
	# Where the cast-out wake, a walk from the first camp
	start = _good(r, probe, _ring.bind(r, first, 150.0, 200.0), [], 0.0, placed, 90.0)
	# The beacons: the first near the camp, the ninth beyond Gallowmere, the rest wide apart
	var all: Array = placed.duplicate()
	var b0 := _good(r, probe, _ring.bind(r, first, 200.0, 300.0), [], 0.0, all, 120.0)
	var g: Vector2 = settle_at.gallowmere
	var away := (g - first).normalized()
	var b8 := _good(r, probe, func(): return g + away.rotated(r.randf_range(-0.9, 0.9)) * r.randf_range(170, 260), [], 0.0, all, 120.0)
	beacon_at.resize(9)
	beacon_at[0] = b0
	beacon_at[8] = b8
	all.append_array([b0, b8])
	for i in range(1, 8):
		var p := _good(r, probe, func(): return Vector2(r.randf_range(-850, 850), r.randf_range(-850, 850)), all, 300.0)
		beacon_at[i] = p
		all.append(p)
	# The ruins that have stories, near the ones who tell them
	var near := {"tobin_wagon": "cinderwick", "salt_caravans": "cinderwick", "order_tower": "hesk", "piet_camp": "kiln", "sealed_vault": "mourners", "stone_field": "lanternwell"}
	for k in near:
		var home: Vector2 = settle_at[near[k]]
		var p := _good(r, probe, _ring.bind(r, home, 170.0, 280.0), [], 0.0, all, 80.0)
		ruin_at[k] = p
		all.append(p)


## A point from make() that is level, not too high, inside the waste, and far enough from what is already placed.
static func _good(r: RandomNumberGenerator, probe: Callable, make: Callable, near: Array, apart: float, avoid: Array = [], avoid_r := 0.0) -> Vector2:
	var best := Vector2.ZERO
	var best_score := -INF
	for attempt in 300:
		var p: Vector2 = make.call()
		p = p.clamp(Vector2(-860, -860), Vector2(860, 860))
		var hs: Vector2 = probe.call(p)
		var score := -hs.y * 40.0 - maxf(hs.x - 30.0, 0.0)
		var ok := hs.y < 0.18 and hs.x < 45.0
		for q in near:
			var d: float = p.distance_to(q)
			if d < apart:
				ok = false
			score -= maxf(apart - d, 0.0)
		for q in avoid:
			var d: float = p.distance_to(q)
			if d < avoid_r:
				ok = false
			score -= maxf(avoid_r - d, 0.0)
		if ok:
			return p
		if score > best_score:
			best_score = score
			best = p
	return best


static func _ring(r: RandomNumberGenerator, c: Vector2, rmin: float, rmax: float) -> Vector2:
	var a := r.randf() * TAU
	return c + Vector2(cos(a), sin(a)) * r.randf_range(rmin, rmax)


const COMPASS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]


static func dir_word(from: Vector2, to: Vector2) -> String:
	var d := to - from
	var ang := atan2(d.x, -d.y)
	return COMPASS[posmod(roundi(ang / (TAU / 8.0)), 8)]


## Fills in the directions in a line of talk: <dir:S:place:from> for settlements, B for beacons, R for ruins.
static func words(text: String) -> String:
	if not "<dir:" in text:
		return text
	var out := text
	while "<dir:" in out:
		var i := out.find("<dir:")
		var j := out.find(">", i)
		var parts := out.substr(i + 5, j - i - 5).split(":")
		var to := _where(parts[0], parts[1])
		var from := start if parts[2] == "start" else spos(parts[2])
		out = out.substr(0, i) + dir_word(from, to) + out.substr(j + 1)
	return out


static func _where(kind: String, id: String) -> Vector2:
	match kind:
		"S":
			return start if id == "start" else spos(id)
		"B":
			return bpos(int(id))
		"R":
			return rpos(id)
	return Vector2.ZERO
