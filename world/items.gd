class_name Items
extends RefCounted
## Everything that may be carried in the Ashen Waste: what it is, how much of it a pack will hold, and its worth in salt.

## kind: material, food, medicine, tool, ammo, trinket, trophy, quest
const DB := {
	"wood": {"name": "Deadwood", "kind": "material", "stack": 60, "value": 1, "color": Color(0.45, 0.33, 0.22), "text": "Gray timber from trees that died standing."},
	"stone": {"name": "Stone", "kind": "material", "stack": 60, "value": 1, "color": Color(0.5, 0.48, 0.45), "text": "Broken rock. Heavy, and patient."},
	"scrap": {"name": "Scrap Iron", "kind": "material", "stack": 40, "value": 2, "color": Color(0.45, 0.3, 0.22), "text": "Iron from before the fall. Better than anything dug since."},
	"salt": {"name": "Salt", "kind": "material", "stack": 200, "value": 1, "color": Color(0.92, 0.9, 0.86), "text": "The coin of the waste. It also cleanses oil and keeps meat."},
	"cloth": {"name": "Cloth", "kind": "material", "stack": 40, "value": 2, "color": Color(0.6, 0.55, 0.45), "text": "Rags, sacking and old vestments."},
	"herb": {"name": "Ash-bloom", "kind": "material", "stack": 40, "value": 3, "color": Color(0.7, 0.72, 0.6), "text": "A pale flower of the lee slopes. Bitter, and it heals."},
	"bone": {"name": "Bone", "kind": "material", "stack": 40, "value": 1, "color": Color(0.85, 0.82, 0.72), "text": "There is no shortage of it."},
	"oil": {"name": "Lamp Oil", "kind": "material", "stack": 20, "value": 6, "color": Color(0.75, 0.55, 0.2), "text": "Drawn from the Well. It burns yellow and smoky."},
	"beacon_oil": {"name": "Beacon Oil", "kind": "quest", "stack": 5, "value": 40, "color": Color(1.0, 0.95, 0.75), "text": "Oil rendered in the old measure. It burns white, and the night draws back from it."},
	"meat": {"name": "Salted Meat", "kind": "food", "stack": 10, "value": 4, "color": Color(0.55, 0.25, 0.2), "heal": 15.0, "text": "Do not ask from what. Restores a little health."},
	"bandage": {"name": "Bandage", "kind": "medicine", "stack": 10, "value": 5, "color": Color(0.85, 0.82, 0.75), "heal": 35.0, "text": "Clean cloth, boiled. Restores health."},
	"salve": {"name": "Ash-bloom Salve", "kind": "medicine", "stack": 5, "value": 14, "color": Color(0.6, 0.7, 0.55), "heal": 80.0, "text": "Closes what a bandage cannot. Restores much health."},
	"shells": {"name": "Shotgun Shells", "kind": "ammo", "stack": 120, "value": 1, "color": Color(0.75, 0.2, 0.12), "text": "Paper and brass, packed with shot. For the pump shotgun."},
	"rounds": {"name": "Pistol Rounds", "kind": "ammo", "stack": 150, "value": 1, "color": Color(0.8, 0.65, 0.3), "text": "Short brass rounds. For the pistol and the revolver."},
	"rifle": {"name": "Rifle Rounds", "kind": "ammo", "stack": 300, "value": 1, "color": Color(0.6, 0.55, 0.35), "text": "Long brass rounds. For the machine gun, the sniper rifle and the minigun."},
	"rockets": {"name": "Rocket", "kind": "ammo", "stack": 10, "value": 12, "color": Color(0.35, 0.4, 0.28), "text": "A finned warhead. For the rocket launcher."},
	"pick": {"name": "Pick", "kind": "tool", "stack": 1, "value": 25, "color": Color(0.4, 0.4, 0.42), "text": "Stone and salt come away twice as fast."},
	"hatchet": {"name": "Hatchet", "kind": "tool", "stack": 1, "value": 20, "color": Color(0.4, 0.4, 0.42), "text": "Deadwood comes away twice as fast."},
	"prybar": {"name": "Pry Bar", "kind": "tool", "stack": 1, "value": 30, "color": Color(0.35, 0.35, 0.38), "text": "Opens what was sealed: iron chests and vault doors."},
	"coin": {"name": "Order Coin", "kind": "trinket", "stack": 50, "value": 8, "color": Color(0.85, 0.7, 0.3), "text": "Struck by the Order of the Silent Clerics. Worth salt at the Crossing."},
	"icon": {"name": "Painted Icon", "kind": "trinket", "stack": 10, "value": 30, "color": Color(0.75, 0.55, 0.35), "text": "A white cat, painted on wood. Its eyes are open."},
	"bell": {"name": "Silver Bell", "kind": "trinket", "stack": 10, "value": 45, "color": Color(0.8, 0.82, 0.85), "text": "It rings very clearly. Too clearly, at night."},
	"ledger": {"name": "Order Ledger", "kind": "trinket", "stack": 10, "value": 25, "color": Color(0.4, 0.3, 0.22), "text": "Lists of names, and what was owed by each."},
	"letter": {"name": "Sealed Letter", "kind": "quest", "stack": 5, "value": 0, "color": Color(0.85, 0.8, 0.65), "text": "Not yours to open."},
	"goods": {"name": "Bundle of Goods", "kind": "quest", "stack": 5, "value": 0, "color": Color(0.55, 0.45, 0.3), "text": "Wrapped and corded. Promised to someone."},
	"keepsake": {"name": "Keepsake", "kind": "quest", "stack": 5, "value": 0, "color": Color(0.7, 0.6, 0.5), "text": "Something lost, that someone wants back."},
	"piet_ring": {"name": "Piet's Ring", "kind": "quest", "stack": 1, "value": 0, "color": Color(0.8, 0.7, 0.4), "text": "A potter's ring, thumb-worn. Ysolde will know it."},
	"t_ash": {"name": "Matron's Ember", "kind": "trophy", "stack": 5, "value": 220, "color": Color(1.0, 0.45, 0.2), "text": "A coal from the Cinder Matron. It has not cooled, and does not burn the hand."},
	"t_dunes": {"name": "Choir Tongue", "kind": "trophy", "stack": 5, "value": 200, "color": Color(0.85, 0.6, 0.35), "text": "Dried and cracked. Some nights it still hums the note it knew."},
	"t_salt": {"name": "White Shard", "kind": "trophy", "stack": 5, "value": 240, "color": Color(0.9, 0.92, 0.95), "text": "A piece of the White Disc. Light passes through it, and comes out colder."},
	"t_forest": {"name": "Watcher's Eye", "kind": "trophy", "stack": 5, "value": 260, "color": Color(0.5, 0.55, 0.6), "text": "Glass, or something like it. Do not look into it for long."},
	"t_basalt": {"name": "Idol's Gilt", "kind": "trophy", "stack": 5, "value": 280, "color": Color(0.95, 0.78, 0.3), "text": "Gold leaf from the Basalt Idol's face. The face beneath was not stone."},
	"t_marsh": {"name": "Tar Pearl", "kind": "trophy", "stack": 5, "value": 220, "color": Color(0.15, 0.12, 0.1), "text": "Black, smooth, warm. Found where the Tar Mother's heart was."},
	"order_seal": {"name": "Seal of the Inward Vault", "kind": "quest", "stack": 1, "value": 0, "color": Color(0.6, 0.6, 0.65), "text": "Cold to the touch. It was pressed from the inside of a door."},
}

## What may be made, and from what. "bench" recipes need a workbench close by.
const RECIPES := [
	{"id": "bandage", "n": 1, "cost": {"cloth": 2}, "bench": false},
	{"id": "salve", "n": 1, "cost": {"cloth": 1, "herb": 3}, "bench": false},
	{"id": "meat", "n": 2, "cost": {"bone": 2, "salt": 4}, "bench": false},
	{"id": "shells", "n": 8, "cost": {"scrap": 1, "salt": 3}, "bench": false},
	{"id": "shells", "n": 30, "cost": {"scrap": 3, "salt": 8}, "bench": true},
	{"id": "rounds", "n": 10, "cost": {"scrap": 1, "salt": 3}, "bench": false},
	{"id": "rounds", "n": 40, "cost": {"scrap": 3, "salt": 8}, "bench": true},
	{"id": "rifle", "n": 60, "cost": {"scrap": 4, "salt": 10}, "bench": true},
	{"id": "rockets", "n": 2, "cost": {"scrap": 6, "oil": 2, "salt": 10}, "bench": true},
	{"id": "pick", "n": 1, "cost": {"wood": 4, "scrap": 4}, "bench": true},
	{"id": "hatchet", "n": 1, "cost": {"wood": 3, "scrap": 3}, "bench": true},
	{"id": "prybar", "n": 1, "cost": {"scrap": 8}, "bench": true},
	{"id": "beacon_oil", "n": 1, "cost": {"oil": 2, "salt": 10, "herb": 4}, "bench": true, "needs": "oilcraft"},
]

## The pieces of a shelter. Size and cost; hp is how long it holds against the night.
const PIECES := {
	"floor": {"name": "Floor", "cost": {"wood": 4}, "hp": 400.0},
	"wall": {"name": "Timber Wall", "cost": {"wood": 6}, "hp": 350.0},
	"stonewall": {"name": "Stone Wall", "cost": {"stone": 10}, "hp": 900.0},
	"doorway": {"name": "Doorway", "cost": {"wood": 5}, "hp": 300.0},
	"door": {"name": "Door", "cost": {"wood": 4, "scrap": 1}, "hp": 300.0},
	"roof": {"name": "Roof", "cost": {"wood": 4}, "hp": 300.0},
	"spikes": {"name": "Spike Barricade", "cost": {"wood": 4}, "hp": 220.0},
	"campfire": {"name": "Campfire", "cost": {"wood": 3, "stone": 3}, "hp": 200.0},
	"bedroll": {"name": "Bedroll", "cost": {"cloth": 3}, "hp": 120.0},
	"chest": {"name": "Storage Chest", "cost": {"wood": 8}, "hp": 250.0},
	"bench": {"name": "Workbench", "cost": {"wood": 6, "scrap": 4}, "hp": 300.0},
	"lamp": {"name": "Oil Lamp", "cost": {"scrap": 2, "oil": 1}, "hp": 150.0},
}
const PIECE_ORDER := ["floor", "wall", "stonewall", "doorway", "door", "roof", "spikes", "campfire", "bedroll", "chest", "bench", "lamp"]

## Loot tables: [item, weight, min, max]
const LOOT := {
	"caravan": [["rounds", 3, 8, 20], ["rifle", 2, 15, 40], ["scrap", 5, 2, 5], ["cloth", 4, 2, 4], ["salt", 4, 6, 18], ["shells", 4, 6, 14], ["meat", 2, 1, 2], ["oil", 1, 1, 1], ["coin", 2, 1, 4], ["bandage", 2, 1, 2]],
	"shrine": [["coin", 4, 1, 5], ["icon", 2, 1, 1], ["herb", 3, 2, 4], ["bell", 1, 1, 1], ["cloth", 2, 1, 3], ["salve", 1, 1, 1]],
	"order": [["rifle", 2, 20, 50], ["rounds", 2, 10, 24], ["ledger", 3, 1, 1], ["coin", 4, 2, 6], ["scrap", 3, 2, 4], ["icon", 1, 1, 1], ["shells", 3, 8, 16], ["oil", 1, 1, 2], ["bandage", 2, 1, 3]],
	"camp": [["rounds", 3, 6, 16], ["meat", 3, 1, 3], ["cloth", 3, 1, 3], ["wood", 2, 3, 8], ["shells", 4, 4, 12], ["bandage", 3, 1, 2], ["salt", 3, 4, 12], ["bone", 2, 2, 5]],
	"vault": [["rockets", 1, 1, 2], ["rifle", 3, 30, 60], ["coin", 4, 4, 10], ["bell", 2, 1, 2], ["icon", 2, 1, 2], ["salve", 2, 1, 2], ["ledger", 2, 1, 2], ["oil", 2, 1, 2], ["shells", 3, 12, 24]],
	"corpse": [["rounds", 3, 4, 10], ["shells", 5, 3, 8], ["bone", 3, 1, 3], ["cloth", 3, 1, 2], ["salt", 3, 2, 8], ["coin", 1, 1, 2], ["meat", 1, 1, 1]],
}

## What each trader keeps for sale, beyond what reputation opens.
const STOCK := {
	"trader": ["shells", "rounds", "bandage", "meat", "cloth", "scrap", "oil"],
	"oilwright": ["oil", "herb", "beacon_oil"],
	"smith": ["pick", "hatchet", "prybar", "scrap", "shells", "rounds", "rifle", "rockets"],
	"healer": ["bandage", "salve", "herb"],
	"quartermaster": ["shells", "rounds", "rifle", "meat", "cloth", "bandage", "scrap"],
}


## Which ammunition each gun takes.
const AMMO := {"shotgun": "shells", "pistol": "rounds", "revolver": "rounds", "machine_gun": "rifle", "sniper": "rifle", "minigun": "rifle", "rocket": "rockets"}


static func info(id: String) -> Dictionary:
	return DB.get(id, {"name": id, "kind": "material", "stack": 99, "value": 0, "color": Color.GRAY, "text": ""})


static func iname(id: String) -> String:
	return info(id).name


static func stack_of(id: String) -> int:
	return int(info(id).stack)


static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		parts.append("%d %s" % [cost[k], iname(k)])
	return ", ".join(parts)


## Rolls a table: n draws, each an [item, count].
static func roll(table: String, draws: int, rng: RandomNumberGenerator) -> Array:
	var t: Array = LOOT.get(table, LOOT.camp)
	var total := 0
	for row in t:
		total += int(row[1])
	var out: Array = []
	for i in draws:
		var r := rng.randi_range(1, total)
		for row in t:
			r -= int(row[1])
			if r <= 0:
				out.append([row[0], rng.randi_range(int(row[2]), int(row[3]))])
				break
	return out
