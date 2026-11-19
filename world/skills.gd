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
	"witness": {"name": "Witness", "ranks": 1, "tier": 4, "text": "Enemies within 40 metres show on your compass at night."},
	"last_light": {"name": "Last Light", "ranks": 1, "tier": 7, "text": "Within sight of a burning beacon, enemy attacks do half harm."},
}

## Experience for each deed.
const XP := {
	"kill": 6, "kill_elite": 30, "kill_boss": 400, "assist": 2, "gather": 1, "make": 3, "build": 2,
	"step": 30, "step_main": 60, "quest": 80, "beacon": 250, "dawn": 60,
	"settlement": 50, "ruin": 25, "biome": 20, "rumour": 10,
}

var xp := 0
var level := 1
var points := 0
var ranks := {}
var second_wind_day := -1
## Beacon boons: one is chosen each time a beacon is kindled, and kept for good.
const BOONS := {
	"fleet": {"name": "Fleet Foot", "text": "You walk and run 8% faster."},
	"deep_breath": {"name": "Deep Breath", "text": "Your breath comes back 30% faster."},
	"iron_skin": {"name": "Iron Skin", "text": "You take 10% less harm."},
	"beacon_heart": {"name": "Beacon Heart", "text": "25 more health."},
	"sure_aim": {"name": "Sure Aim", "text": "Your guns and blades hit 10% harder."},
	"salvager": {"name": "Salvager", "text": "30% more from everything you gather."},
	# Boons that are new things to do, not numbers
	"rally": {"name": "Rallying Cry", "text": "Your whistle rallies the squad near you: breath back, and a burst of speed. Once a minute."},
	"second_relic": {"name": "Second Relic", "text": "Two spirit-cats may run with you at once."},
	"lantern": {"name": "Lantern-bearer", "text": "Your lit lantern keeps the dread off everyone near you."},
	"pack_cat": {"name": "Pack-Cat", "text": "With a cat of your own, it carries 8 places of your pack."},
	"quick_camp": {"name": "Quick Camp", "text": "Once a night, lay a campfire for nothing."},
	"deep_diver": {"name": "Deep Diver", "text": "Swimming costs half the breath: you stay under twice as long."},
}
var boons: Array = []        ## the boons chosen, kept for good
var boon_offer: Array = []   ## three boons offered by a kindled beacon, waiting to be chosen
var use := {}   ## practice with each gun and the blade: id -> points earned by using it

## Names for how well a survivor knows a weapon, from first use to mastery.
const USE_RANKS := ["Green", "Used", "Practised", "Seasoned", "Skilled", "Hardened", "Veteran", "Expert", "Master", "Legend"]
const USE_MAX := 9


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


const MASTERED := "Mastered"
const NO_POINTS := "No points to spend"


## Why a skill cannot be learned now, or "" if it can.
func blocked(id: String) -> String:
	var s: Dictionary = SKILLS[id]
	if rank(id) >= int(s.ranks):
		return MASTERED
	var t := tree_of(id)
	if spent_in(t) < int(s.tier):
		return "Needs %d points in %s" % [int(s.tier), TREES[t].name]
	if points <= 0:
		return NO_POINTS
	return ""


func learn(id: String) -> bool:
	if not SKILLS.has(id) or blocked(id) != "":
		return false
	ranks[id] = rank(id) + 1
	points -= 1
	changed.emit()
	return true


## Adds experience. Returns how many levels were gained.
## Renown: past the last level, experience fills a bar of renown instead (about 9,000 a step).
## Each step gives one reward to choose: a re-spec, a cosmetic, or a place in a trophy hall.
const RENOWN_STEP := 9000
const RENOWN_REWARDS := {
	"respec": {"name": "A fresh start", "text": "Unlearn every skill and have all the points back to spend again."},
	"barding": {"name": "Barding of Renown", "text": "Red and gold barding for your cat."},
	"hall": {"name": "A trophy place", "text": "One more trophy may hang in the halls you tend (up to five)."},
}
var renown := 0
var renown_xp := 0
var renown_picks := 0      ## renown steps not yet turned into a reward
var rewards: Array = []    ## the rewards chosen ("hall" may be taken twice)


func has_reward(r: String) -> bool:
	return r in rewards


## How many trophies may hang in a hall this survivor tends: three, and up to five with renown.
func hall_places() -> int:
	return 3 + mini(2, rewards.count("hall"))


func take_reward(r: String) -> bool:
	if renown_picks <= 0 or not RENOWN_REWARDS.has(r):
		return false
	if r == "barding" and has_reward("barding"):
		return false
	if r == "hall" and rewards.count("hall") >= 2:
		return false
	renown_picks -= 1
	rewards.append(r)
	if r == "respec":
		respec()
	changed.emit()
	return true


## Every skill unlearned; the points come back.
func respec() -> void:
	var n := 0
	for k in ranks:
		n += int(ranks[k])
	ranks = {}
	points += n


func gain(amount: int) -> int:
	if amount <= 0:
		return 0
	if level >= MAX_LEVEL:
		renown_xp += int(round(amount * (1.0 + 0.1 * rank("pilgrim"))))
		while renown_xp >= RENOWN_STEP:
			renown_xp -= RENOWN_STEP
			renown += 1
			renown_picks += 1
		changed.emit()
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


# ------------------------------------------------------------------ practice

## Points of practice to reach a rank with a weapon.
static func use_need(lv: int) -> int:
	return int(round(25.0 * pow(lv, 1.7)))


func use_level(id: String) -> int:
	var p := int(use.get(id, 0))
	var lv := 0
	while lv < USE_MAX and p >= use_need(lv + 1):
		lv += 1
	return lv


## How far to the next rank, 0 to 1.
func use_progress(id: String) -> float:
	var lv := use_level(id)
	if lv >= USE_MAX:
		return 1.0
	var a := use_need(lv)
	return clampf(float(int(use.get(id, 0)) - a) / float(use_need(lv + 1) - a), 0.0, 1.0)


## Practice from using a weapon. Returns true when it reaches a new rank.
func practise(id: String, n: int) -> bool:
	if n <= 0:
		return false
	var before := use_level(id)
	if WRules.sworn("vow_glass"):
		n *= 2   # the Vow of Glass: every weapon learns twice as fast
	use[id] = int(use.get(id, 0)) + n
	return use_level(id) > before


## What practice with a weapon gives: a little more harm, less kick, quicker loading and aiming.
func use_bonus(id: String) -> Dictionary:
	var lv := use_level(id)
	return {"dmg": 1.0 + 0.02 * lv, "kick": 1.0 - 0.03 * lv, "reload": 1.0 - 0.025 * lv, "aim": 1.0 + 0.03 * lv, "spread": 1.0 - 0.02 * lv}


static func use_text(lv: int) -> String:
	if lv <= 0:
		return "No bonus yet. Use it to get better with it."
	return "+%d%% harm, %d%% less kick, %d%% quicker loading" % [2 * lv, 3 * lv, int(round(2.5 * lv))]


# ------------------------------------------------------------------ what the skills do

func has_boon(id: String) -> bool:
	return id in boons


## Whether this survivor has a cat of their own (the Pack-Cat boon carries in it).
func _has_cat() -> bool:
	var lv = Game.main.level if Game.main else null
	return lv != null and lv.get("cat") != null


## Three boons not yet held, to be chosen from (fewer once nearly all are taken).
func roll_boons(rr: RandomNumberGenerator) -> Array:
	var left: Array = []
	for k in BOONS:
		if not k in boons:
			left.append(k)
	var out: Array = []
	while out.size() < 3 and not left.is_empty():
		out.append(left.pop_at(rr.randi_range(0, left.size() - 1)))
	return out


func take_boon(id: String) -> bool:
	if not id in boon_offer or id in boons:
		return false
	boons.append(id)
	boon_offer = []
	changed.emit()
	return true


func breath_mult() -> float:
	return 1.3 if has_boon("deep_breath") else 1.0


func health_max() -> float:
	return 100.0 + 10.0 * rank("hardy") + (25.0 if has_boon("beacon_heart") else 0.0)


func regen_mult(by_fire: bool) -> float:
	var m := 1.0 + 0.35 * rank("mending")
	if by_fire:
		m *= 1.0 + rank("grace")
	return m


func speed_mult() -> float:
	return (1.0 + 0.05 * rank("light_step")) * (1.08 if has_boon("fleet") else 1.0)


func pack_size() -> int:
	return 24 + 4 * rank("deep_pockets") + (8 if has_boon("pack_cat") and _has_cat() else 0)


func damage_mult() -> float:
	return (1.0 + 0.08 * rank("steady_hand")) * (1.1 if has_boon("sure_aim") else 1.0)


func reload_mult() -> float:
	return (1.0 - 0.15 * rank("quick_hands")) * 1.0


func reserve_max() -> int:
	return 400 + 100 * rank("bandolier") + 0


func harm_mult() -> float:
	return (1.0 - 0.06 * rank("ward")) * (0.9 if has_boon("iron_skin") else 1.0)


func drop_bonus() -> float:
	return 0.08 * rank("grim_harvest")


func gather_mult() -> float:
	return (1.0 + 0.2 * rank("scavenger")) * (1.3 if has_boon("salvager") else 1.0)


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
	return (1.0 - 0.06 * rank("haggler")) * 1.0


func sell_mult() -> float:
	return (1.0 + 0.1 * rank("haggler")) * 1.0 * (0.5 if WRules.sworn("vow_tithe") else 1.0)


func build_hp_mult() -> float:
	return 1.0 + 0.3 * rank("mason")


func make_bonus(id: String) -> int:
	return 1 if rank("tinker") > 0 and id in ["bandage", "shells", "rounds", "rifle", "beacon_oil"] else 0


func vigil_mult() -> float:
	return 1.0 - 0.15 * rank("vigil_keeper")


# ------------------------------------------------------------------ keeping

func to_data() -> Dictionary:
	return {"xp": xp, "level": level, "points": points, "ranks": ranks, "sw": second_wind_day, "use": use, "boons": boons, "offer": boon_offer,
		"renown": renown, "rxp": renown_xp, "picks": renown_picks, "rewards": rewards}


func from_data(d) -> void:
	if not d is Dictionary:
		return
	xp = int(d.get("xp", 0))
	level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	renown = maxi(0, int(d.get("renown", 0)))
	renown_xp = clampi(int(d.get("rxp", 0)), 0, RENOWN_STEP)
	renown_picks = clampi(int(d.get("picks", 0)), 0, renown)
	rewards = []
	for r in d.get("rewards", []):
		if RENOWN_REWARDS.has(str(r)):
			rewards.append(str(r))
	points = maxi(0, int(d.get("points", 0)))
	ranks = {}
	var r = d.get("ranks", {})
	if r is Dictionary:
		for k in r:
			if SKILLS.has(k):
				ranks[k] = clampi(int(r[k]), 0, int(SKILLS[k].ranks))
	second_wind_day = int(d.get("sw", -1))
	boons = []
	for b in d.get("boons", []):
		if BOONS.has(str(b)) and not str(b) in boons:
			boons.append(str(b))
	boon_offer = []
	for b in d.get("offer", []):
		if BOONS.has(str(b)):
			boon_offer.append(str(b))
	use = {}
	var u = d.get("use", {})
	if u is Dictionary:
		for k in u:
			use[str(k)] = maxi(0, int(u[k]))
	changed.emit()
