class_name WAlchemy
extends RefCounted
## Brewing by a fire. Six things of the waste each hold two hidden virtues. Taste one to learn its
## first; brew two that share a virtue and the draught carries it, and you learn it in both.
## A draught works for a few minutes. Each virtue lies in exactly two things, round in a ring:
## ash-bloom, tuber, salt crystal, bone, tar, heartwood, and back to ash-bloom.

const INGREDIENTS := {
	"herb": ["mend", "breath"],
	"tuber": ["breath", "swift"],
	"salt_crystal": ["swift", "ward"],
	"bone": ["ward", "keen"],
	"tar": ["keen", "fireskin"],
	"heartwood": ["fireskin", "mend"],
}
const EFFECTS := {
	"mend": {"name": "Mending", "text": "wounds close", "mins": 4},
	"breath": {"name": "Long Breath", "text": "breath comes back fast", "mins": 5},
	"swift": {"name": "Swiftness", "text": "a faster stride", "mins": 4},
	"ward": {"name": "Warding", "text": "a quarter less harm", "mins": 4},
	"keen": {"name": "Keenness", "text": "harder blows and shots", "mins": 4},
	"fireskin": {"name": "Fireskin", "text": "fire does not take you", "mins": 5},
}
const BASE := {"salt": 2}   ## the brine every draught is steeped in

var w
var known := {}    ## ingredient -> [virtues learned]
var active := {}   ## virtue -> seconds left


func _init(world) -> void:
	w = world


func knows(ing: String, eff: String) -> bool:
	return eff in known.get(ing, [])


func _learn(ing: String, eff: String) -> bool:
	var k: Array = known.get(ing, [])
	if eff in k:
		return false
	k.append(eff)
	known[ing] = k
	return true


## What the pilgrim knows of a thing, in words: "Mending, ?" until both are learned.
func known_text(ing: String) -> String:
	var bits := []
	for e in INGREDIENTS[ing]:
		bits.append(EFFECTS[e].name if knows(ing, e) else "?")
	return ", ".join(bits)


## Eats one to learn its first unknown virtue. Returns the virtue learned, or "".
func taste(ing: String) -> String:
	if not INGREDIENTS.has(ing) or w.inv.count(ing) < 1:
		return ""
	for e in INGREDIENTS[ing]:
		if not knows(ing, e):
			w.inv.take(ing, 1)
			_learn(ing, e)
			w.hud.notify("You taste the %s. %s." % [Items.iname(ing).to_lower(), EFFECTS[e].name])
			return e
	w.hud.notify("You already know what the %s holds." % Items.iname(ing).to_lower())
	return ""


## The virtues two things share.
static func shared(a: String, b: String) -> Array:
	var out := []
	if a == b or not INGREDIENTS.has(a) or not INGREDIENTS.has(b):
		return out
	for e in INGREDIENTS[a]:
		if e in INGREDIENTS[b]:
			out.append(e)
	return out


func can_brew(a: String, b: String) -> bool:
	return a != b and w.inv.count(a) >= 1 and w.inv.count(b) >= 1 and w.inv.count("salt") >= int(BASE.salt)


## Steeps two things together. Returns the virtue brewed, or "" if they share none (both are spent).
func brew(a: String, b: String) -> String:
	if not can_brew(a, b):
		return ""
	w.inv.take(a, 1)
	w.inv.take(b, 1)
	w.inv.take("salt", int(BASE.salt))
	var sh := shared(a, b)
	if sh.is_empty():
		w.hud.notify("It turns grey and sour. They share nothing.")
		return ""
	var e: String = sh[0]
	_learn(a, e)
	_learn(b, e)
	w.inv.add("brew_" + e, 1)
	w.hud.notify("A draught of %s." % EFFECTS[e].name)
	w.sfx("drink", -8, null, 0.8)
	return e


func drink(id: String) -> bool:
	var e := id.trim_prefix("brew_")
	if not EFFECTS.has(e) or w.inv.take(id, 1) < 1:
		return false
	active[e] = float(EFFECTS[e].mins) * 60.0
	w.hud.notify("%s: %s for %d minutes." % [EFFECTS[e].name, EFFECTS[e].text, int(EFFECTS[e].mins)])
	w.sfx("drink", -6)
	if e == "keen" or e == "swift":
		w._apply_skills()
	return true


func on(e: String) -> bool:
	return float(active.get(e, 0.0)) > 0.0


func tick(delta: float) -> void:
	if active.is_empty():
		return
	var gone := []
	for e in active:
		active[e] = float(active[e]) - delta
		if float(active[e]) <= 0.0:
			gone.append(e)
	for e in gone:
		active.erase(e)
		w.hud.notify("The %s wears off." % EFFECTS[e].name.to_lower())
		if e == "keen" or e == "swift":
			w._apply_skills()
	if w.player == null or w.downed:
		return
	if on("mend"):
		w.player.health = minf(w.player.max_health, w.player.health + 1.5 * delta)
	if on("breath"):
		w.player.stamina = minf(w.player.stamina_max, w.player.stamina + 8.0 * delta)


func harm_mult() -> float:
	return 0.75 if on("ward") else 1.0


func damage_mult() -> float:
	return 1.15 if on("keen") else 1.0


func speed_mult() -> float:
	return 1.2 if on("swift") else 1.0


func to_data() -> Dictionary:
	return {"known": known, "active": active}


func from_data(d) -> void:
	known = {}
	active = {}
	if not d is Dictionary:
		return
	var k = d.get("known", {})
	if k is Dictionary:
		for ing in k:
			if INGREDIENTS.has(ing) and k[ing] is Array:
				for e in k[ing]:
					if str(e) in INGREDIENTS[ing]:
						_learn(ing, str(e))
	var a = d.get("active", {})
	if a is Dictionary:
		for e in a:
			if EFFECTS.has(e):
				active[e] = float(a[e])
