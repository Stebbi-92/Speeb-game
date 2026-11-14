class_name WSkills
extends RefCounted
## What a survivor learns in the waste: experience, levels, and four trees of skills.
##
## Experience comes from the work of the waste: forms slain, tasks done, beacons lit, places found,
## nights lived through. Each level brings one point to spend. A skill has ranks; the deeper skills
## of a tree open only once enough points are spent in that tree. Everything here belongs to the
## character, so in a fellowship each survivor grows on their own.

signal changed

const MAX_LEVEL := 30

## Each tree: its name, a line about it, and its skills in order. "tier" is how many points must
## already be spent in the tree before the skill can be learned.
const TREES := {
	"survival": {"name": "Survival", "text": "The body's stubbornness. To live another day.", "skills": ["hardy", "mending", "light_step", "deep_pockets", "second_wind"]},
	"arms": {"name": "Arms", "text": "The gun and the hand that holds it.", "skills": ["steady_hand", "quick_hands", "bandolier", "grim_harvest", "ward"]},
	"craft": {"name": "Craft", "text": "Hands that make something of the ruin.", "skills": ["scavenger", "thrift", "haggler", "mason", "tinker"]},
	"faith": {"name": "Faith", "text": "What the beacons ask of those who keep them.", "skills": ["vigil_keeper", "grace", "pilgrim", "witness", "last_light"]},
}

const SKILLS := {
	# Survival
	"hardy": {"name": "Hardy", "ranks": 3, "tier": 0, "text": "+10 most health for each rank."},
	"mending": {"name": "Mending", "ranks": 3, "tier": 0, "text": "Wounds close 35% faster for each rank."},
	"light_step": {"name": "Light Step", "ranks": 2, "tier": 2, "text": "Walk and run 5% faster for each rank."},
	"deep_pockets": {"name": "Deep Pockets", "ranks": 2, "tier": 4, "text": "Four more places in your pack for each rank."},
	"second_wind": {"name": "Second Wind", "ranks": 1, "tier": 7, "text": "Once a day, a blow that would fell you leaves you standing with a third of your health."},
	# Arms
	"steady_hand": {"name": "Steady Hand", "ranks": 3, "tier": 0, "text": "Your shots strike 8% harder for each rank."},
	"quick_hands": {"name": "Quick Hands", "ranks": 2, "tier": 0, "text": "Load shells 15% faster for each rank."},
	"bandolier": {"name": "Bandolier", "ranks": 2, "tier": 2, "text": "Carry 100 more shells for each rank."},
	"grim_harvest": {"name": "Grim Harvest", "ranks": 2, "tier": 4, "text": "The fallen leave something behind more often."},
	"ward": {"name": "Ward", "ranks": 3, "tier": 7, "text": "Take 6% less harm for each rank."},
	# Craft
	"scavenger": {"name": "Scavenger", "ranks": 3, "tier": 0, "text": "Take 20% more from every rock, tree and heap for each rank."},
	"thrift": {"name": "Thrift", "ranks": 3, "tier": 0, "text": "Making and building cost 12% less for each rank."},
	"haggler": {"name": "Haggler", "ranks": 3, "tier": 2, "text": "Buy 6% cheaper and sell 10% dearer for each rank."},
	"mason": {"name": "Mason", "ranks": 2, "tier": 4, "text": "What you build stands 30% stronger for each rank."},
	"tinker": {"name": "Tinker", "ranks": 1, "tier": 7, "text": "Bandages, shells and oil come out of the making one more at a time."},
	# Faith
	"vigil_keeper": {"name": "Vigil Keeper", "ranks": 2, "tier": 0, "text": "A new flame holds 15% sooner for each rank."},
	"grace": {"name": "Grace of the Flame", "ranks": 2, "tier": 0, "text": "By fires and in settlements, wounds close twice as fast again for each rank."},
	"pilgrim": {"name": "Pilgrim", "ranks": 2, "tier": 2, "text": "10% more experience from everything for each rank."},
	"witness": {"name": "Witness", "ranks": 1, "tier": 4, "text": "Forms within 40 metres show on your compass at night."},
	"last_light": {"name": "Last Light", "ranks": 1, "tier": 7, "text": "Within sight of a burning beacon, the forms' blows are halved."},
}

## Experience for each deed.
const XP := {
	"kill": 6, "kill_elite": 30, "kill_boss": 400, "assist": 2, "gather": 1, "make": 3, "build": 2,
	"step": 30, "step_main": 60, "quest": 80, "beacon": 250, "dawn": 60,
	"settlement": 50, "ruin": 25, "biome": 20,
}

var xp := 0
var level := 1
var points := 0
var ranks := {}
var second_wind_day := -1


static func need(lv: int) -> int:
	## Experience to go from this level to the next.
	return int(round(90.0 * pow(lv, 1.35)))


func rank(id: String) -> int:
	return int(ranks.get(id, 0))


func spent_in(tree: String) -> int:
	var n := 0
	for s in TREES[tree].skills:
		n += rank(s)
	return n


func tree_of(id: String) -> String:
	for t in TREES:
		if id in TREES[t].skills:
			return t
	return ""


## Why a skill cannot be learned now, or "" if it can.
func blocked(id: String) -> String:
	var s: Dictionary = SKILLS[id]
	if rank(id) >= int(s.ranks):
		return "Mastered"
	var t := tree_of(id)
	if spent_in(t) < int(s.tier):
		return "Needs %d points in %s" % [int(s.tier), TREES[t].name]
	if points <= 0:
		return "No points to spend"
	return ""


func learn(id: String) -> bool:
	if not SKILLS.has(id) or blocked(id) != "":
		return false
	ranks[id] = rank(id) + 1
	points -= 1
	changed.emit()
	return true


## Adds experience. Returns how many levels were gained.
func gain(amount: int) -> int:
	if level >= MAX_LEVEL or amount <= 0:
		return 0
	xp += int(round(amount * (1.0 + 0.1 * rank("pilgrim"))))
	var ups := 0
	while level < MAX_LEVEL and xp >= need(level):
		xp -= need(level)
		level += 1
		points += 1
		ups += 1
	if level >= MAX_LEVEL:
		xp = 0
	changed.emit()
	return ups


# ------------------------------------------------------------------ what the skills do

func health_max() -> float:
	return 100.0 + 10.0 * rank("hardy")


func regen_mult(by_fire: bool) -> float:
	var m := 1.0 + 0.35 * rank("mending")
	if by_fire:
		m *= 1.0 + rank("grace")
	return m


func speed_mult() -> float:
	return 1.0 + 0.05 * rank("light_step")


func pack_size() -> int:
	return 24 + 4 * rank("deep_pockets")


func damage_mult() -> float:
	return 1.0 + 0.08 * rank("steady_hand")


func reload_mult() -> float:
	return 1.0 - 0.15 * rank("quick_hands")


func reserve_max() -> int:
	return 400 + 100 * rank("bandolier")


func harm_mult() -> float:
	return 1.0 - 0.06 * rank("ward")


func drop_bonus() -> float:
	return 0.08 * rank("grim_harvest")


func gather_mult() -> float:
	return 1.0 + 0.2 * rank("scavenger")


## A recipe or building cost, lightened by Thrift. Nothing ever costs less than one of each.
func cost(c: Dictionary) -> Dictionary:
	var r := rank("thrift")
	if r == 0:
		return c
	var out := {}
	for k in c:
		out[k] = maxi(1, int(ceil(int(c[k]) * (1.0 - 0.12 * r))))
	return out


func buy_mult() -> float:
	return 1.0 - 0.06 * rank("haggler")


func sell_mult() -> float:
	return 1.0 + 0.1 * rank("haggler")


func build_hp_mult() -> float:
	return 1.0 + 0.3 * rank("mason")


func make_bonus(id: String) -> int:
	return 1 if rank("tinker") > 0 and id in ["bandage", "shells", "beacon_oil"] else 0


func vigil_mult() -> float:
	return 1.0 - 0.15 * rank("vigil_keeper")


# ------------------------------------------------------------------ keeping

func to_data() -> Dictionary:
	return {"xp": xp, "level": level, "points": points, "ranks": ranks, "sw": second_wind_day}


func from_data(d) -> void:
	if not d is Dictionary:
		return
	xp = int(d.get("xp", 0))
	level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	points = maxi(0, int(d.get("points", 0)))
	ranks = {}
	var r = d.get("ranks", {})
	if r is Dictionary:
		for k in r:
			if SKILLS.has(k):
				ranks[k] = clampi(int(r[k]), 0, int(SKILLS[k].ranks))
	second_wind_day = int(d.get("sw", -1))
	changed.emit()
