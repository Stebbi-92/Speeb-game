class_name WIsles
extends RefCounted
## The isles of the Grey Sea, out past the coast of the waste. Each is its own land, with its own
## ground, weather and foes, and each keeps something worth the crossing.

const SEA_Y := -20.0          ## the sea's surface
const FLOOR_Y := -36.0        ## the sea bed, out where nothing stands
const INLAND := 1760.0        ## no sea lies this near the middle (by the square measure)
const CELL := 4.0
const MAP_HALF := 6600.0      ## the map shows the waste, the sea and the far shores out to here
const SEA_COLOR := Color(0.2, 0.25, 0.28)

## base: which land of the waste it is like, for its hardship, what it yields and what rises there.
## relief: how high its hills go. sand / green / rock: the colours of its shore, its slopes and its stone.
const THEMES := {
	"hrafn": {
		"name": "Hrafnsey", "base": "basalt", "ruin": ["The Saga Stones", "stones"], "relief": 46.0, "rough": 1.0,
		"sand": Color(0.1, 0.1, 0.11), "green": Color(0.26, 0.34, 0.2), "rock": Color(0.16, 0.16, 0.17),
		"text": "Black sand, green moss and smoking ground. The springs here are hot enough to heal, or to scald.",
		"nodes": [["rock", 6], ["herb", 3], ["salt", 1], ["bone", 1]],
		"forms": ["knight", "wisp", "vigil", "saltbone", "brute", "idol", "draugr", "draugr", "nykur"],
	},
	"fen": {
		"name": "The Sunk Fen", "base": "marsh", "ruin": ["The Drowned Chapel", "shrine"], "relief": 6.0, "rough": 0.3,
		"sand": Color(0.2, 0.18, 0.13), "green": Color(0.2, 0.22, 0.14), "rock": Color(0.18, 0.17, 0.14),
		"text": "A drowned forest on a low isle. The water is black and the trees still stand in it.",
		"nodes": [["tree", 6], ["herb", 4], ["bone", 2]],
		"forms": ["drowned", "drowned", "lurker", "spider", "swarm", "colossus", "hollow"],
	},
	"kala": {
		"name": "Kalaja", "base": "dunes", "ruin": ["The Old Keep", "tower"], "relief": 58.0, "rough": 0.8,
		"sand": Color(0.74, 0.68, 0.56), "green": Color(0.42, 0.44, 0.28), "rock": Color(0.6, 0.57, 0.5),
		"text": "Pale stone hills, old olive trees and grey domes dug into every slope. Someone feared an enemy that never came.",
		"nodes": [["rock", 4], ["tree", 3], ["herb", 2], ["scrap", 2]],
		"forms": ["unlit_gun", "unlit_mark", "unlit_blade", "saltrifle", "howler", "rusher", "shtriga", "shtriga", "kulshedra"],
	},
	"cog": {
		"name": "Cogwright", "base": "salt", "ruin": ["The Engine Vault", "vault"], "relief": 16.0, "rough": 0.5,
		"sand": Color(0.36, 0.26, 0.18), "green": Color(0.45, 0.32, 0.2), "rock": Color(0.3, 0.27, 0.24),
		"text": "An isle of iron. Pipes and wheels and chimneys, still turning for no one.",
		"nodes": [["scrap", 7], ["rock", 2], ["salt", 2]],
		"forms": ["unlit_gun", "unlit_brute", "unlit_flame", "saucer", "bloater", "knight"],
	},
	# The far sea (0.16): two isles past the near ones, then the three Far Shores, each a land of its own.
	# far: shown when five beacons burn. size: its radius, low to high. at: how far out its middle lies.
	# cell: its ground grid (a shore's is coarser, to keep it light). land: its own hardship, if any.
	"quiet": {
		"words": [["Glass", "Lens", "Still", "White", "Pale", "Sleeping"], ["Hall", "Tower", "Stair", "Archive", "Works", "Court"]],
		"name": "Quietglass", "base": "salt", "ruin": ["The Lantern Crown", "tower"], "relief": 40.0, "rough": 0.6,
		"sand": Color(0.62, 0.66, 0.68), "green": Color(0.5, 0.56, 0.58), "rock": Color(0.7, 0.74, 0.78),
		"text": "Glass towers in the fog. Signs flicker on and off across the city, and the doors open only where they burn.",
		"nodes": [["salt", 4], ["scrap", 4], ["rock", 2], ["bone", 1]],
		"forms": ["flicker", "flicker", "flicker", "archivist_hand", "archivist_hand", "wisp", "vigil", "glass_crawler"],
		"far": true, "size": [520.0, 600.0], "at": 3900.0, "cell": 4.0,
	},
	"domes": {
		"words": [["Grey", "Low", "Pine", "Sea", "Varda", "Sunk"], ["Dome", "Bunker", "Post", "Battery", "Trench", "Hatch"]],
		"name": "The Thousand Domes", "base": "dunes", "ruin": ["The Dark Light", "tower"], "relief": 34.0, "rough": 0.7,
		"sand": Color(0.6, 0.58, 0.5), "green": Color(0.3, 0.34, 0.22), "rock": Color(0.5, 0.5, 0.47),
		"text": "A long grey coast with domes in every dune and under every road. The Unlit come up out of them and go down again.",
		"nodes": [["rock", 4], ["tree", 3], ["scrap", 3], ["herb", 1]],
		"forms": ["tunnel_unlit", "tunnel_unlit", "tunnel_unlit", "unlit_gun", "unlit_blade", "unlit_mark", "unlit_brute"],
		"far": true, "size": [540.0, 620.0], "at": 3900.0, "cell": 4.0,
	},
	"frost": {
		"words": [["Rime", "Raven", "Black", "Old", "Frost", "Ember", "Moss", "Turf"], ["Hall", "Cairn", "Steading", "Barrow", "Byre", "Croft", "Shieling", "Fold"]],
		"name": "The Frostmark", "base": "basalt", "ruin": ["The Ice Hall", "vault"], "relief": 120.0, "rough": 1.1,
		"sand": Color(0.12, 0.12, 0.13), "green": Color(0.3, 0.38, 0.26), "rock": Color(0.78, 0.82, 0.86),
		"text": "Black lava under green moss, glaciers in the high valleys, and steam out of the ground. Very old, and very cold.",
		"nodes": [["rock", 6], ["herb", 2], ["bone", 2], ["tree", 1]],
		"forms": ["rime_walker", "rime_walker", "geyser_wight", "geyser_wight", "raven_mask", "draugr", "rime_bones", "nykur"],
		"far": true, "shore": true, "size": [1050.0, 1150.0], "at": 5000.0, "cell": 8.0, "land": "frost", "snow": 60.0,
	},
	"sun": {
		"words": [["Red", "Dry", "Sun", "Long", "Bone", "Thirst", "Mesa", "Dust"], ["Well", "Arch", "Camp", "Cistern", "Post", "Shelf", "Ledge", "Gate"]],
		"name": "The Sunward Reach", "base": "dunes", "ruin": ["The Sun Clock", "stones"], "relief": 90.0, "rough": 1.3,
		"sand": Color(0.72, 0.42, 0.26), "green": Color(0.62, 0.36, 0.22), "rock": Color(0.55, 0.28, 0.18),
		"text": "Red canyons and flat-topped mesas under an enormous sky. Hot by day, bitter by night, and short of water.",
		"nodes": [["scrap", 4], ["rock", 4], ["bone", 2], ["herb", 1]],
		"forms": ["canyon_strider", "canyon_strider", "dust_choir", "dust_choir", "glass_husk", "saltrifle", "gaunt", "sand_maw"],
		"far": true, "shore": true, "size": [1050.0, 1150.0], "at": 5000.0, "cell": 8.0, "land": "sun",
	},
	"steppe": {
		"words": [["Grey", "Grass", "Horn", "Nine", "Pale", "Low", "Wind", "Lone"], ["Mound", "Stone", "Ford", "Ring", "Barrow", "Post", "Bell", "Tree"]],
		"name": "The Pale Steppe", "base": "ash", "ruin": ["The Spine", "stones"], "relief": 22.0, "rough": 0.4,
		"sand": Color(0.5, 0.48, 0.4), "green": Color(0.56, 0.56, 0.46), "rock": Color(0.45, 0.44, 0.4),
		"text": "Grey grass taller than a pilgrim, slow rivers and standing stones. You can walk an hour and see only sky.",
		"nodes": [["herb", 4], ["bone", 3], ["tree", 2], ["rock", 1]],
		"forms": ["grass_stalker", "grass_stalker", "herd_ghost", "mound_guard", "mound_guard", "howler", "harrow"],
		"far": true, "shore": true, "size": [1050.0, 1150.0], "at": 5000.0, "cell": 8.0, "land": "steppe",
	},
}
const ORDER := ["hrafn", "fen", "kala", "cog"]
const FAR_ORDER := ["quiet", "domes", "frost", "sun", "steppe"]


## Lays the isles out for a world's seed: one off each face of the waste, turned a little by the seed.
static func plan(seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed + 7070
	var turn := r.randf() * TAU
	var out: Array = []
	for i in ORDER.size():
		var key: String = ORDER[i]
		var a := turn + i * TAU / ORDER.size() + r.randf_range(-0.25, 0.25)
		var d := Vector2(cos(a), sin(a))
		d /= maxf(absf(d.x), absf(d.y))   # out to the square edge, so it lies wholly past the land
		var rad := r.randf_range(260.0, 340.0)
		var reach := 2150.0 + rad + r.randf_range(40.0, 240.0)
		out.append({"key": key, "name": THEMES[key].name, "base": THEMES[key].base, "c": d * reach, "r": rad, "cell": CELL})
	# The far sea and the shores past it: each where it keeps clear of the rest, by the seed's turn
	for k in FAR_ORDER.size():
		var key: String = FAR_ORDER[k]
		var th: Dictionary = THEMES[key]
		var rad := r.randf_range(float(th.size[0]), float(th.size[1]))
		var a0 := turn + TAU / 8.0 + k * TAU / FAR_ORDER.size()
		var placed := {}
		for tries in 48:
			var a := a0 + (tries / 2) * 0.11 * (1 if tries % 2 == 0 else -1)
			var reach: float = float(th.at) + r.randf_range(-120.0, 120.0)
			var c := Vector2(cos(a), sin(a)) * reach
			var clear := true
			for o in out:
				if c.distance_to(o.c) < rad + float(o.r) + 260.0:
					clear = false
					break
			if clear:
				placed = {"key": key, "name": th.name, "base": th.base, "c": c, "r": rad, "cell": float(th.cell)}
				break
		if not placed.is_empty():
			out.append(placed)
	return out


## Where a Far Shore's town stands: partway in from its shore, off to one side of its heart.
static func town_spot(il: Dictionary) -> Vector2:
	var c: Vector2 = il.c
	return c + (-c.normalized()).rotated(1.9) * float(il.r) * 0.42


## Where a far isle's great one sleeps: partway in, to the other side of its heart from the town.
static func lair_spot(il: Dictionary) -> Vector2:
	var c: Vector2 = il.c
	return c + (-c.normalized()).rotated(-1.9) * float(il.r) * 0.45


## Whether an isle lies out on the far sea (or is a Far Shore), past the near isles.
static func far(il: Dictionary) -> bool:
	return bool(THEMES.get(str(il.get("key", "")), {}).get("far", false))
