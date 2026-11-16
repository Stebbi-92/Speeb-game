class_name WTrades
extends RefCounted
## Trades. Each pilgrim keeps one: smith, cook, alchemist or tinker. Each makes something only its own
## hands can make, and the best arms and meals want it, so a fellowship leans on one another.
## The first trade is chosen anywhere; changing it takes a town and some coin.

const TRADES := {
	"smith": {"name": "Smith", "makes": "Tempered steel", "text": "Makes tempered steel, which the best blades and plate need. Arms and plate cost a fifth less to make."},
	"cook": {"name": "Cook", "makes": "Wayfarer's Feast", "text": "Makes the Wayfarer's Feast, the best meal there is. Cooking at a fire gives one more each time."},
	"alchemist": {"name": "Alchemist", "makes": "Restoring Elixir", "text": "Makes the Restoring Elixir, which heals and ends burning and tar. Each brew gives two draughts."},
	"tinker": {"name": "Tinker", "makes": "Clockwork", "text": "Makes clockwork, which the great guns and fittings need. Ammunition comes out half again as much."},
}
const CHANGE_COST := 25   ## coin, to take up another trade

var w
var trade := ""


func _init(world) -> void:
	w = world


func is_(k: String) -> bool:
	return trade == k


func tname(k: String) -> String:
	return str(TRADES.get(k, {}).get("name", "No trade"))


## Why the pilgrim cannot take up this trade now, or "".
func refusal(k: String) -> String:
	if not TRADES.has(k) or k == trade:
		return "?"
	if trade == "":
		return ""
	if w.settlement_at(w.player.global_position) == "":
		return "You can change your trade only in a town."
	if w.inv.count("coin") < CHANGE_COST:
		return "Changing your trade costs %d coin." % CHANGE_COST
	return ""


func choose(k: String) -> bool:
	var why := refusal(k)
	if why != "":
		if why != "?":
			w.hud.notify(why)
		return false
	if trade != "":
		w.inv.take("coin", CHANGE_COST)
	trade = k
	w.hud.notify("You take up the %s's trade." % TRADES[k].name.to_lower())
	w.sfx("carve", -6)
	return true


## A recipe this pilgrim's hands can make: one without a trade, or of their own.
func can_make(r: Dictionary) -> bool:
	return not r.has("trade") or str(r.trade) == trade


## Extra made by trade, for a recipe of n: the cook's fire, the tinker's ammunition.
func bonus(r: Dictionary) -> int:
	var n := int(r.n)
	if trade == "cook" and r.get("fire", false):
		return 1
	if trade == "tinker" and Items.info(str(r.id)).kind == "ammo":
		return int(n * 0.5)
	return 0


## What arms, parts and plate cost in this pilgrim's hands.
func arms_cost(c: Dictionary) -> Dictionary:
	if trade != "smith":
		return c
	var out := {}
	for k in c:
		out[k] = int(c[k]) if k in ["tempered", "clockwork", "coin"] else maxi(1, int(ceil(int(c[k]) * 0.8)))
	return out


func to_data() -> String:
	return trade


func from_data(d) -> void:
	trade = str(d) if TRADES.has(str(d)) else ""
