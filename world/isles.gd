class_name WIsles
extends RefCounted
## The isles of the Grey Sea, out past the coast of the waste. Each is its own land, with its own
## ground, weather and foes, and each keeps something worth the crossing.

const SEA_Y := -20.0          ## the sea's surface
const FLOOR_Y := -36.0        ## the sea bed, out where nothing stands
const INLAND := 1760.0        ## no sea lies this near the middle (by the square measure)
const CELL := 4.0
const MAP_HALF := 3200.0      ## the map shows the waste and the sea about it out to here
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
}
const ORDER := ["hrafn", "fen", "kala", "cog"]


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
		out.append({"key": key, "name": THEMES[key].name, "base": THEMES[key].base, "c": d * reach, "r": rad})
	return out
