class_name WRules
extends RefCounted
## A world's own settings, chosen when it begins and changed later by its host. Kept in the world's
## save and given to everyone who joins.

## [key, label, choices, default, what it does]
const ALL := [
	["difficulty", "Difficulty", ["Easy", "Normal", "Hard"], 1, "How hard creatures hit and how much they take."],
	["skill", "Enemy skill", ["Forgiving", "Normal", "Ruthless"], 1, "How long a bite is shown before it lands, how easily creatures stagger, and whether they come from the sides."],
	["enemies", "Enemy numbers", ["None", "Fewer", "Normal", "More"], 2, "How many creatures rise. None: the waste is quiet, but for its beasts and great ones."],
	["resources", "Resources", ["Scarce", "Normal", "Plenty"], 1, "How much gathering and searching gives."],
	["needs", "Hunger and tiredness", ["Off", "Gentle", "Normal"], 2, "How fast food and rest run down."],
	["air", "Air support", ["Off", "On"], 1, "Calling the sky down after a run of kills."],
	["ammo", "Ammunition", ["Counted", "Unlimited"], 0, "Unlimited: guns never spend their reserve."],
	["pace", "Night pace", ["Steady", "Normal", "Chaos"], 1, "Nights come in rounds, with a breath between. Steady: smaller rounds, longer breaks, fewer named nights. Chaos: bigger rounds, shorter breaks, most nights named."],
	["death", "On falling", ["Drop your pack", "Keep your pack"], 0, "What happens to what you carried when you fall."],
	# Vows: sworn when a world begins and kept for its life. Each makes the road harder, and pays for it.
	["vow_glass", "Vow of Glass", ["Not sworn", "Sworn"], 0, "You take half again as much harm. Every weapon learns twice as fast."],
	["vow_hunted", "Vow of the Hunted", ["Not sworn", "Sworn"], 0, "Every night from the third is a named night. Their dawn gifts are doubled."],
	["vow_tithe", "Vow of the Tithe", ["Not sworn", "Sworn"], 0, "Traders pay half for what you sell. Each lit beacon gives twice the gift."],
]


## A vow is sworn when the world begins, and cannot be changed after.
static func is_vow(key: String) -> bool:
	return key.begins_with("vow_")


static func sworn(key: String) -> bool:
	return get_rule(key) == 1


## The vows a world was begun under, by name; empty if none.
static func vows_text() -> String:
	var out: Array = []
	for r in ALL:
		if is_vow(r[0]) and sworn(r[0]):
			out.append(r[1])
	return ", ".join(out)


static func defaults() -> Dictionary:
	var d := {}
	for r in ALL:
		d[r[0]] = r[3]
	return d


static func clean(d) -> Dictionary:
	var out := defaults()
	if d is Dictionary:
		for r in ALL:
			if d.has(r[0]):
				out[r[0]] = clampi(int(d[r[0]]), 0, r[2].size() - 1)
	return out


static func row(key: String) -> Array:
	for r in ALL:
		if r[0] == key:
			return r
	return []


## The rule now in force, from the world being walked (or the default outside one).
static func get_rule(key: String) -> int:
	var r := row(key)
	return int(Game.wrules.get(key, r[3] if not r.is_empty() else 0))


## Each rule's effect, as a number to multiply by.
static func windup() -> float:
	return [1.5, 1.0, 0.75][get_rule("skill")]


static func stagger_at() -> float:
	return [0.22, 0.3, 0.42][get_rule("skill")]


static func flanks() -> bool:
	return get_rule("skill") >= 1


static func spawn_mult() -> float:
	return [0.0, 0.6, 1.0, 1.5][get_rule("enemies")]


## How hard the nights press: [wave size, time between waves, chance a night is plain].
static func pace() -> Array:
	return [[0.65, 1.4, 0.7], [1.0, 1.0, 0.45], [1.4, 0.75, 0.2]][get_rule("pace")]


static func yield_mult() -> float:
	return [0.6, 1.0, 1.6][get_rule("resources")]


static func needs_mult() -> float:
	return [0.0, 0.5, 1.0][get_rule("needs")]
