class_name WSpirits
extends RefCounted
## Spirit-cats. A relic holds the ghost of a cat that once kept a shrine; call it up and it runs beside
## you and bites what comes for you, for a minute or so, then fades. A relic is spent once used and
## kindles again when you rest by a fire. Only one runs with you at a time (two with the Second Relic).
## Not within town walls.

const KINDS := {
	"spirit_ember": {"name": "Ember-Cat", "face": "autumnspeeb", "color": Color(1.0, 0.55, 0.25), "size": 1.0,
		"life": 75.0, "speed": 9.0, "bite": 14.0, "rate": 0.9, "harm": "fire"},
	"spirit_ash": {"name": "Ash-Cat", "face": "snowspeeb", "color": Color(0.8, 0.85, 0.95), "size": 0.85,
		"life": 90.0, "speed": 11.0, "bite": 8.0, "rate": 0.45, "harm": "blade"},
	"spirit_grave": {"name": "Grave-Cat", "face": "moonspeeb", "color": Color(0.55, 0.75, 1.0), "size": 1.5,
		"life": 60.0, "speed": 7.5, "bite": 46.0, "rate": 1.6, "harm": "blast"},
}
const TIER_BITE := [1.0, 1.4, 1.9, 2.5, 2.9]   ## its bite grows with the danger of the land it is called in
const REACH := 26.0                       ## how far from its pilgrim it will go after a form

var w
var spent := {}       ## relic -> true, until rested by a fire
var cat: WSpiritCat = null   ## the last one called
var _mine := {}       ## relic -> its cat, while it runs
var _friends := {}    ## "peer/relic" -> the puppet cat by a friend


func _init(world) -> void:
	w = world


func is_spent(id: String) -> bool:
	return spent.has(id)


## Why it cannot be called now, or "".
func refusal(id: String) -> String:
	if not KINDS.has(id):
		return "?"
	if is_spent(id):
		return "The relic is cold. Rest by a fire to kindle it again."
	if running() >= (2 if w.skills.has_boon("second_relic") else 1):
		return "A spirit already runs with you." if running() == 1 else "Two spirits already run with you."
	if w.settlement_at(w.player.global_position) != "":
		return "The spirits will not come within town walls."
	if w.downed:
		return "?"
	return ""


## Calls the relic's cat up beside the pilgrim. Returns true if it came.
func summon(id: String) -> bool:
	var why := refusal(id)
	if why != "":
		if why != "?":
			w.hud.notify(why)
		return false
	spent[id] = true
	w.shared("_w_spirit", [Net.me(), id, true])
	w.hud.notify("%s comes out of the relic." % KINDS[id].name)
	return true


## Everyone: a pilgrim's spirit-cat comes or goes.
func show(peer: int, id: String, on: bool) -> void:
	if Net.dedicated:
		return
	var mine := peer == Net.me()
	var key := "%d/%s" % [peer, id]
	var old = _mine.get(id) if mine else _friends.get(key)
	if old != null and is_instance_valid(old):
		old.end()
	if not on or not KINDS.has(id):
		return
	var who: Node3D = w.player if mine else w.avatars.get(peer)
	if who == null or not is_instance_valid(who):
		return
	var c := WSpiritCat.new().setup(w, id, who, not mine)
	w.add_child(c)
	var back: Vector3 = who.global_basis.z * 2.0
	c.global_position = w.gpos(Vector2(who.global_position.x + back.x + 1.0, who.global_position.z + back.z))
	c.rotation.y = who.rotation.y
	w.sfx("choir", -10, c.global_position, 1.4)
	if mine:
		cat = c
		_mine[id] = c
	else:
		_friends[key] = c


## How many spirit-cats run with this pilgrim now.
func running() -> int:
	var n := 0
	for id in _mine:
		var c = _mine[id]
		if c != null and is_instance_valid(c) and c._fade <= 0.0:
			n += 1
	return n


## Resting by a fire: every relic kindles again.
func rekindle() -> void:
	if spent.is_empty():
		return
	spent = {}
	w.hud.notify("Your relics are warm again.")


func time_left() -> float:
	if cat != null and is_instance_valid(cat) and cat._fade <= 0.0:
		return cat.life
	return 0.0


func to_data() -> Dictionary:
	return {"spent": spent.keys()}


func from_data(d) -> void:
	spent = {}
	if d is Dictionary and d.get("spent") is Array:
		for id in d.spent:
			if KINDS.has(str(id)):
				spent[str(id)] = true
