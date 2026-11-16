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
	"fittings_fine": {"name": "Fine Fittings", "kind": "part", "stack": 10, "value": 25, "color": Color(0.45, 0.8, 0.4), "text": "Springs, pins and good steel. At a workbench, rework a gun part into a Fine one."},
	"fittings_rare": {"name": "Rare Fittings", "kind": "part", "stack": 10, "value": 60, "color": Color(0.4, 0.62, 0.95), "text": "Machined before the fall. At a workbench, rework a gun part into a Rare one."},
	"fittings_storied": {"name": "Storied Fittings", "kind": "part", "stack": 5, "value": 150, "color": Color(0.95, 0.75, 0.3), "text": "Fittings with a name and a past. At a workbench, rework a gun part into a Storied one."},
	"oil": {"name": "Lamp Oil", "kind": "material", "stack": 20, "value": 6, "color": Color(0.75, 0.55, 0.2), "text": "Drawn from the Well. It burns yellow and smoky."},
	"beacon_oil": {"name": "Beacon Oil", "kind": "quest", "stack": 5, "value": 40, "color": Color(1.0, 0.95, 0.75), "text": "Oil rendered in the old measure. It burns white, and the night draws back from it."},
	"raw_meat": {"name": "Raw Meat", "kind": "food", "stack": 10, "value": 3, "color": Color(0.7, 0.28, 0.26), "heal": -4.0, "food": 10.0, "text": "From a hunted beast. Cook it first."},
	"roast": {"name": "Roast Meat", "kind": "food", "stack": 10, "value": 7, "color": Color(0.5, 0.3, 0.18), "heal": 15.0, "food": 50.0, "meal": {"hp": 20, "mins": 20}, "text": "Cooked over a cooking station. A meal: more health for a while."},
	"hide": {"name": "Hide", "kind": "material", "stack": 20, "value": 3, "color": Color(0.55, 0.42, 0.3), "text": "A beast's skin. Cuts into cloth."},
	"meat": {"name": "Salted Meat", "kind": "food", "stack": 10, "value": 4, "color": Color(0.55, 0.25, 0.2), "heal": 15.0, "food": 30.0, "meal": {"hp": 8, "stam": 10, "mins": 12}, "text": "Do not ask from what. A small meal: a little more health and breath."},
	"tuber": {"name": "Ash Tuber", "kind": "food", "stack": 20, "value": 2, "color": Color(0.55, 0.45, 0.32), "heal": 4.0, "food": 18.0, "text": "Grows in poor ground. Better cooked."},
	"stew": {"name": "Tuber Stew", "kind": "food", "stack": 10, "value": 9, "color": Color(0.6, 0.38, 0.22), "heal": 30.0, "food": 70.0, "meal": {"hp": 15, "regen": 0.5, "mins": 25}, "text": "Hot, thick and filling. A meal: more health, and wounds close faster."},
	"tea": {"name": "Bloom Tea", "kind": "food", "stack": 10, "value": 8, "color": Color(0.72, 0.7, 0.45), "heal": 5.0, "food": 10.0, "meal": {"stam": 30, "breath": 0.3, "mins": 15}, "text": "Bitter and clear. A meal: more breath, and it comes back faster."},
	"broth": {"name": "Bone Broth", "kind": "food", "stack": 10, "value": 8, "color": Color(0.82, 0.72, 0.5), "heal": 10.0, "food": 35.0, "meal": {"regen": 1.2, "mins": 20}, "text": "Boiled down from bones and salt. A meal: wounds close much faster."},
	"pie": {"name": "Salt-crust Pie", "kind": "food", "stack": 10, "value": 18, "color": Color(0.78, 0.6, 0.35), "heal": 25.0, "food": 80.0, "meal": {"hp": 30, "stam": 15, "mins": 30}, "text": "Meat and tuber under a crust of salt. A great meal: much more health, and more breath."},
	"tuber_seed": {"name": "Tuber Eyes", "kind": "seed", "stack": 30, "value": 2, "color": Color(0.5, 0.42, 0.3), "grows": "tuber", "yield": [3, 5], "hours": 14.0, "text": "Plant in a planter box. A day later there are tubers."},
	"herb_seed": {"name": "Ash-bloom Seed", "kind": "seed", "stack": 30, "value": 3, "color": Color(0.65, 0.7, 0.58), "grows": "herb", "yield": [2, 4], "hours": 18.0, "text": "Plant in a planter box. The bloom heals."},
	"torchwood": {"name": "Torch", "kind": "material", "stack": 20, "value": 2, "color": Color(0.85, 0.55, 0.25), "text": "Pitch-soaked wood. Makes a torch."},
	"milk": {"name": "Bowl of Milk", "kind": "medicine", "stack": 5, "value": 14, "color": Color(0.95, 0.94, 0.9), "heal": 55.0, "text": "Speeb's own comfort. Restores much health."},
	"bandage": {"name": "Bandage", "kind": "medicine", "stack": 10, "value": 5, "color": Color(0.85, 0.82, 0.75), "heal": 35.0, "text": "Clean cloth, boiled. Restores health."},
	"salts": {"name": "Smelling Salts", "kind": "aid", "stack": 5, "value": 12, "color": Color(0.88, 0.86, 0.8), "text": "Held under the nose of a fallen companion. Raises them faster, and stronger."},
	"salve": {"name": "Ash-bloom Salve", "kind": "medicine", "stack": 5, "value": 14, "color": Color(0.6, 0.7, 0.55), "heal": 80.0, "text": "Closes what a bandage cannot. Restores much health."},
	"shells": {"name": "Shotgun Shells", "kind": "ammo", "stack": 120, "value": 1, "color": Color(0.75, 0.2, 0.12), "text": "Paper and brass, packed with shot. For the pump shotgun."},
	"rounds": {"name": "Pistol Rounds", "kind": "ammo", "stack": 150, "value": 1, "color": Color(0.8, 0.65, 0.3), "text": "Short brass rounds. For the pistol and the revolver."},
	"rifle": {"name": "Rifle Rounds", "kind": "ammo", "stack": 300, "value": 1, "color": Color(0.6, 0.55, 0.35), "text": "For the machine gun, sniper rifle and minigun."},
	"fuel": {"name": "Lamp Fuel", "kind": "ammo", "stack": 400, "value": 1, "color": Color(0.55, 0.4, 0.15), "text": "Thinned oil and tar. For the flamethrower."},
	"rockets": {"name": "Rocket", "kind": "ammo", "stack": 10, "value": 12, "color": Color(0.35, 0.4, 0.28), "text": "A finned warhead. For the rocket launcher."},
	"pick": {"name": "Pick", "kind": "tool", "stack": 1, "value": 25, "color": Color(0.4, 0.4, 0.42), "text": "Stone and salt come away twice as fast."},
	"red_iron": {"name": "Red Iron", "kind": "material", "stack": 40, "value": 6, "color": Color(0.62, 0.3, 0.2), "text": "Caravan iron, rusted red through. Found in the scrap of the Rust Dunes."},
	"heartwood": {"name": "Heartwood", "kind": "material", "stack": 40, "value": 6, "color": Color(0.36, 0.24, 0.16), "text": "The dark core of a tree of the Dead Forest. It does not rot."},
	"salt_crystal": {"name": "Salt Crystal", "kind": "material", "stack": 40, "value": 9, "color": Color(0.85, 0.92, 0.98), "text": "Clear salt from deep in the Salt Flats."},
	"tar": {"name": "Tar", "kind": "material", "stack": 40, "value": 9, "color": Color(0.12, 0.1, 0.09), "text": "Black and sticky. Gathered in the Tar Marsh."},
	"obsidian": {"name": "Obsidian", "kind": "material", "stack": 40, "value": 14, "color": Color(0.1, 0.09, 0.12), "text": "Black glass from the Basalt Heights. Sharper than iron."},
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
	"raft": {"name": "Raft", "kind": "boat", "stack": 1, "value": 30, "color": Color(0.45, 0.35, 0.24), "text": "Logs and rope, ready to lash together. Launch it from the shore. Two can ride; paddle it with the walking keys."},
	"sloop": {"name": "Sloop", "kind": "boat", "stack": 1, "value": 120, "color": Color(0.32, 0.24, 0.18), "text": "A small boat with a mast, in pieces. Launch it from the shore. Four can ride, and it runs before the wind."},
	# Lost books (0.8): found in ruins, read once to teach the whole fellowship something
	"book_ship": {"name": "The Shipwright's Folio", "kind": "book", "stack": 1, "value": 40, "color": Color(0.3, 0.38, 0.5), "text": "Drawings of hulls and masts, salt-stained. Teaches the Sloop."},
	"book_rigging": {"name": "Storm Rigging", "kind": "book", "stack": 1, "value": 40, "color": Color(0.35, 0.45, 0.55), "text": "Knots and sail plans for heavy weather. Your boats run a fifth faster."},
	"book_furrier": {"name": "The Furrier's Pattern", "kind": "book", "stack": 1, "value": 40, "color": Color(0.5, 0.38, 0.26), "text": "How to cut and sew hides fur-side in. Teaches the Fur Coat and Fur Hood."},
	"book_herbal": {"name": "The Herbwife's Notes", "kind": "book", "stack": 1, "value": 40, "color": Color(0.4, 0.5, 0.32), "text": "Pressed flowers and careful measures. Teaches a cheaper salve."},
	"book_gunwright": {"name": "The Gunwright's Ledger", "kind": "book", "stack": 1, "value": 40, "color": Color(0.42, 0.42, 0.45), "text": "Tolerances, springs and filing. Teaches rare fittings from fine ones."},
	"book_salter": {"name": "The Salter's Receipts", "kind": "book", "stack": 1, "value": 40, "color": Color(0.85, 0.82, 0.74), "text": "Brines and cures. Teaches salted meat that keeps, in plenty."},
	"book_lamp": {"name": "The Lamplighter's Primer", "kind": "book", "stack": 1, "value": 40, "color": Color(0.8, 0.6, 0.3), "text": "Wicks and pitch. Teaches five torches from a little oil."},
	"book_saga": {"name": "The Smoke Saga", "kind": "book", "stack": 1, "value": 60, "color": Color(0.2, 0.22, 0.2), "text": "A tale from Hrafnsey of fire in black glass. Teaches rockets from obsidian."},
	"book_hymnal": {"name": "The Drowned Hymnal", "kind": "book", "stack": 1, "value": 60, "color": Color(0.22, 0.24, 0.18), "text": "Its pages are still wet. Teaches a bog salve from tar."},
	"book_kanun": {"name": "The Keeper's Law", "kind": "book", "stack": 1, "value": 60, "color": Color(0.66, 0.62, 0.55), "text": "The old law of the hill keeps of Kalaja. Teaches storied fittings from red iron."},
	"book_engine": {"name": "The Engine Book", "kind": "book", "stack": 1, "value": 60, "color": Color(0.6, 0.45, 0.2), "text": "Diagrams of Cogwright's wheels. Teaches fine fittings from scrap and salt crystal."},
	"page_1": {"name": "The Tenth Page, I. The Blank", "kind": "book", "stack": 1, "value": 0, "color": Color(0.88, 0.85, 0.76), "text": "Nine pages he filled, and the tenth he left white. The High Cleric of the Oath said: a man does not carry a blank page four hundred leagues by accident. The High Cleric of Stillness said: perhaps he does. We did not listen to her."},
	"page_2": {"name": "The Tenth Page, II. The Reasoning", "kind": "book", "stack": 1, "value": 0, "color": Color(0.88, 0.85, 0.76), "text": "We reasoned that Speeb has ten faces and showed Brelm nine. We reasoned that the tenth was withheld because Brelm was one man, and we were many. I wrote this reasoning down. I am ashamed of how good it sounded."},
	"page_3": {"name": "The Tenth Page, III. The Ferry", "kind": "book", "stack": 1, "value": 0, "color": Color(0.88, 0.85, 0.76), "text": "Under Gallowmere there is a lake that has never had light on it. A ferryman took us across. He would not take coin. He said: pay me by coming back. Five of us got into the boat."},
	"page_4": {"name": "The Tenth Page, IV. The Hall", "kind": "book", "stack": 1, "value": 0, "color": Color(0.88, 0.85, 0.76), "text": "There is a hall on the far shore, cut by no hand. There are no images on its walls. We lit a lamp. The light did not reach the walls."},
	"page_5": {"name": "The Tenth Page, V. The Asking", "kind": "book", "stack": 1, "value": 0, "color": Color(0.88, 0.85, 0.76), "text": "Something asked us a question. It did not use a voice. It asked: are you not tired of being looked at? The High Cleric of Restraint wept. He had fasted for thirty years. He said yes."},
	"page_6": {"name": "The Tenth Page, VI. The Writing", "kind": "book", "stack": 1, "value": 0, "color": Color(0.88, 0.85, 0.76), "text": "They sat down to write the tenth page. Each wrote what he most wished Speeb had never seen him do. When the page was full it was white again. They kept writing. I ran. I am the only one who paid the ferryman."},
	"page_7": {"name": "The Tenth Page, VII", "kind": "book", "stack": 1, "value": 0, "color": Color(0.88, 0.85, 0.76), "text": "Blank, but for one line at the foot, in a different hand: It asked us not to look at it, and we were so tired of looking."},
	"ferry_log": {"name": "Ferryman's Log", "kind": "quest", "stack": 1, "value": 0, "color": Color(0.5, 0.4, 0.3), "text": "Salt-stained pages. Crossings, names and fares, in a careful hand."},
	"chapel_bell": {"name": "Chapel Bell", "kind": "quest", "stack": 1, "value": 0, "color": Color(0.7, 0.55, 0.3), "text": "A small bronze bell, green with the fen. It still rings true."},
	"engine_key": {"name": "Engine Key", "kind": "quest", "stack": 1, "value": 0, "color": Color(0.55, 0.5, 0.45), "text": "A heavy iron key with too many teeth. Something on Cogwright was locked with it."},
	"olive_cask": {"name": "Cask of Olives", "kind": "quest", "stack": 1, "value": 0, "color": Color(0.45, 0.5, 0.3), "text": "Sealed with pitch. Orla has not tasted one since she was a girl."},
	"keep_roll": {"name": "Muster Roll", "kind": "quest", "stack": 1, "value": 0, "color": Color(0.75, 0.7, 0.55), "text": "The names of the keep's garrison, every one marked present, every day for sixty years."},
	"sea_iron": {"name": "Sea Iron", "kind": "quest", "stack": 3, "value": 0, "color": Color(0.4, 0.4, 0.42), "text": "Good iron from a wreck, rusted only on the skin."},
	"saga_rubbing": {"name": "Stone Rubbing", "kind": "quest", "stack": 1, "value": 0, "color": Color(0.3, 0.3, 0.32), "text": "Charcoal on cloth: the names cut into one of the Saga Stones."},
	"fen_moss": {"name": "Fen Moss", "kind": "quest", "stack": 3, "value": 0, "color": Color(0.35, 0.45, 0.3), "text": "Grey-green and damp. Tamsin says it closes a wound that will not close."},
	"lamp_lens": {"name": "Lamp Lens", "kind": "quest", "stack": 1, "value": 0, "color": Color(0.85, 0.9, 0.95), "text": "A thick glass lens from the Old Keep's lamp room. Not one scratch on it."},
	"coal_chart": {"name": "Coal Chart", "kind": "quest", "stack": 1, "value": 0, "color": Color(0.25, 0.22, 0.2), "text": "A chart of the sea, with Cogwright marked in black and the words: coal here."},
	"order_seal": {"name": "Seal of the Inward Vault", "kind": "quest", "stack": 1, "value": 0, "color": Color(0.6, 0.6, 0.65), "text": "Cold to the touch. It was pressed from the inside of a door."},
}

## What may be made, and from what. "bench" recipes need a workbench close by.
const RECIPES := [
	{"id": "bandage", "n": 1, "cost": {"cloth": 2}, "bench": false},
	{"id": "salve", "n": 1, "cost": {"cloth": 1, "herb": 3}, "bench": false},
	{"id": "salts", "n": 1, "cost": {"salt": 3, "herb": 2}, "bench": false},
	{"id": "meat", "n": 2, "cost": {"bone": 2, "salt": 4}, "bench": false},
	{"id": "shells", "n": 8, "cost": {"scrap": 1, "salt": 3}, "bench": false},
	{"id": "shells", "n": 30, "cost": {"scrap": 3, "salt": 8}, "bench": true},
	{"id": "rounds", "n": 10, "cost": {"scrap": 1, "salt": 3}, "bench": false},
	{"id": "rounds", "n": 40, "cost": {"scrap": 3, "salt": 8}, "bench": true},
	{"id": "rifle", "n": 60, "cost": {"scrap": 4, "salt": 10}, "bench": true},
	{"id": "rockets", "n": 2, "cost": {"scrap": 6, "oil": 2, "salt": 10}, "bench": true},
	{"id": "fuel", "n": 60, "cost": {"oil": 1, "tar": 1}, "bench": true},
	{"id": "pick", "n": 1, "cost": {"wood": 4, "scrap": 4}, "bench": true},
	{"id": "hatchet", "n": 1, "cost": {"wood": 3, "scrap": 3}, "bench": true},
	{"id": "prybar", "n": 1, "cost": {"scrap": 8}, "bench": true},
	{"id": "roast", "n": 1, "cost": {"raw_meat": 1}, "bench": false, "fire": true},
	{"id": "stew", "n": 1, "cost": {"tuber": 2, "raw_meat": 1, "salt": 1}, "bench": false, "fire": true},
	{"id": "tea", "n": 2, "cost": {"herb": 2}, "bench": false, "fire": true},
	{"id": "broth", "n": 1, "cost": {"bone": 3, "salt": 1, "tuber": 1}, "bench": false, "fire": true},
	{"id": "pie", "n": 1, "cost": {"raw_meat": 2, "tuber": 2, "salt": 2, "herb": 1}, "bench": false, "fire": true},
	{"id": "stew", "n": 1, "cost": {"tuber": 2, "meat": 1, "salt": 2}, "bench": false, "fire": true},
	{"id": "meat", "n": 3, "cost": {"raw_meat": 2, "salt": 3}, "bench": false},
	{"id": "cloth", "n": 3, "cost": {"hide": 2}, "bench": false},
	{"id": "meat", "n": 1, "cost": {"tuber": 3}, "bench": false, "fire": true},
	{"id": "torchwood", "n": 2, "cost": {"wood": 2, "oil": 1}, "bench": false},
	{"id": "tuber_seed", "n": 2, "cost": {"tuber": 2}, "bench": false},
	{"id": "salve", "n": 3, "cost": {"herb": 4, "cloth": 1}, "bench": false, "needs": "book_herbal"},
	{"id": "fittings_rare", "n": 1, "cost": {"fittings_fine": 3, "scrap": 4}, "bench": true, "needs": "book_gunwright"},
	{"id": "meat", "n": 5, "cost": {"raw_meat": 2, "salt": 2}, "bench": false, "needs": "book_salter"},
	{"id": "torchwood", "n": 5, "cost": {"wood": 3, "oil": 1}, "bench": false, "needs": "book_lamp"},
	{"id": "rockets", "n": 3, "cost": {"scrap": 4, "obsidian": 2, "oil": 1}, "bench": true, "needs": "book_saga"},
	{"id": "salve", "n": 4, "cost": {"herb": 3, "tar": 1, "cloth": 1}, "bench": false, "needs": "book_hymnal"},
	{"id": "fittings_storied", "n": 1, "cost": {"fittings_rare": 2, "red_iron": 6}, "bench": true, "needs": "book_kanun"},
	{"id": "fittings_fine", "n": 2, "cost": {"scrap": 8, "salt_crystal": 2}, "bench": true, "needs": "book_engine"},
	{"id": "raft", "n": 1, "cost": {"wood": 16, "cloth": 4}, "bench": true},
	{"id": "sloop", "n": 1, "cost": {"wood": 30, "heartwood": 6, "cloth": 10, "scrap": 6}, "bench": true, "needs": "book_ship"},
	{"id": "beacon_oil", "n": 1, "cost": {"oil": 2, "salt": 10, "herb": 4}, "bench": true, "needs": "oilcraft"},
]

## The pieces of a shelter. Size and cost; hp is how long it holds against the night.
## The pieces a camp is built from. Size and cost; hp is how long it holds against the night.
const PIECES := {
	"floor": {"name": "Floor", "group": "Frame", "cost": {"wood": 4}, "hp": 400.0, "text": "Level ground to build on."},
	"wall": {"name": "Timber Wall", "group": "Frame", "cost": {"wood": 6}, "hp": 350.0, "text": "Stands on a floor's edge."},
	"window": {"name": "Window Wall", "group": "Frame", "cost": {"wood": 6}, "hp": 300.0, "text": "A wall you can see and shoot through."},
	"stonewall": {"name": "Stone Wall", "group": "Frame", "cost": {"stone": 10}, "hp": 900.0, "text": "Slow to build. Slow to fall."},
	"doorway": {"name": "Doorway", "group": "Frame", "cost": {"wood": 5}, "hp": 300.0, "text": "A wall with a gap. Hang a door in it."},
	"door": {"name": "Door", "group": "Frame", "cost": {"wood": 4, "scrap": 1}, "hp": 300.0, "text": "Set into a doorway."},
	"roof": {"name": "Roof", "group": "Frame", "cost": {"wood": 4}, "hp": 300.0, "text": "Sits atop the walls."},
	"stairs": {"name": "Stairs", "group": "Frame", "cost": {"wood": 6}, "hp": 300.0, "text": "Up to a roof or a second floor."},
	"campfire": {"name": "Campfire", "group": "Camp", "cost": {"wood": 3, "stone": 3}, "hp": 200.0, "text": "Makes a camp. While lit, no forms rise within 40 paces. Sleep here."},
	"cookpot": {"name": "Cooking Station", "group": "Camp", "cost": {"wood": 4, "stone": 4, "scrap": 2}, "hp": 160.0, "text": "Cook raw food here."},
	"torch": {"name": "Torch", "group": "Camp", "cost": {"torchwood": 1}, "hp": 80.0, "text": "While lit, no forms rise within 15 paces."},
	"bedroll": {"name": "Bedroll", "group": "Camp", "cost": {"cloth": 3}, "hp": 120.0, "text": "Rest here. You wake here if you fall."},
	"chest": {"name": "Storage Chest", "group": "Camp", "cost": {"wood": 8}, "hp": 250.0, "text": "Sixteen places to keep things."},
	"planter": {"name": "Planter Box", "group": "Camp", "cost": {"wood": 4, "stone": 2, "bone": 2}, "hp": 150.0, "text": "Plant seeds here. Come back in a day."},
	"bench": {"name": "Workbench", "group": "Camp", "cost": {"wood": 6, "scrap": 4}, "hp": 300.0, "text": "Make guns, parts, ammunition and tools."},
	"lamp": {"name": "Oil Lamp", "group": "Camp", "cost": {"scrap": 2, "oil": 1}, "hp": 150.0, "text": "A tall light."},
	"portal": {"name": "Waystone", "group": "Camp", "cost": {"stone": 12, "scrap": 6, "oil": 2}, "hp": 600.0, "text": "Name it. Two waystones of one name lead to each other."},
	"shrine": {"name": "Trophy Shrine", "group": "Camp", "cost": {"stone": 10, "bone": 4, "scrap": 2}, "hp": 400.0, "text": "Lay a great one's trophy here once. After that, kneel to take its power for a while."},
	"spikes": {"name": "Spike Barricade", "group": "Defence", "cost": {"wood": 4}, "hp": 220.0, "text": "Hurts what walks into it."},
	"bed": {"name": "Bed", "group": "Home", "cost": {"wood": 6, "cloth": 4}, "hp": 160.0, "text": "Sleep here. You wake here if you fall. Snugger than a bedroll."},
	"table": {"name": "Table", "group": "Home", "cost": {"wood": 5}, "hp": 140.0, "text": "A home is more than walls. Makes a place snug."},
	"chair": {"name": "Chair", "group": "Home", "cost": {"wood": 3}, "hp": 100.0, "text": "To sit and be still. Makes a place snug."},
	"shelf": {"name": "Shelf", "group": "Home", "cost": {"wood": 8, "scrap": 1}, "hp": 200.0, "text": "Sixteen places to keep things, like a chest."},
	"stove": {"name": "Iron Stove", "group": "Home", "cost": {"scrap": 6, "stone": 4}, "hp": 260.0, "text": "Cook here, like a cooking station. Burns wood and warms the room."},
	"rug": {"name": "Rug", "group": "Home", "cost": {"cloth": 4, "hide": 1}, "hp": 60.0, "text": "Soft underfoot. Makes a place snug."},
	"floorlamp": {"name": "Standing Lamp", "group": "Home", "cost": {"scrap": 2, "oil": 1, "cloth": 1}, "hp": 80.0, "text": "A warm light for indoors."},
	"palisade": {"name": "Palisade", "group": "Defence", "cost": {"wood": 8}, "hp": 650.0, "text": "Sharpened logs on a floor's edge. Tougher than a wall."},
}
const PIECE_ORDER := ["campfire", "cookpot", "torch", "bedroll", "chest", "bench", "planter", "portal", "lamp", "shrine",
	"floor", "wall", "window", "doorway", "door", "roof", "stairs", "stonewall", "spikes", "palisade",
	"bed", "table", "chair", "shelf", "stove", "rug", "floorlamp"]
const GROUPS := ["Camp", "Frame", "Home", "Defence"]

## The kit model that shows a thing: in the world (a quest's find, laid on its crate) and as its picture
## in the pack (see tools/icons.gd). [kit, model, tint]: a tint paints it the item's own colour.
const MODELS := {
	"beacon_oil": ["food", "bottle-oil"], "oil": ["food", "bottle-oil"], "goods": ["food", "bag"],
	"keepsake": ["grave", "urn-round"], "olive_cask": ["pirate", "barrel"], "tar": ["pirate", "barrel"],
	"sea_iron": ["pirate", "cannon-ball"], "lamp_lens": ["grave", "lantern-glass"],
	"ferry_log": ["furn", "books", true], "keep_roll": ["furn", "books", true], "ledger": ["furn", "books", true],
	"book_engine": ["furn", "books", true], "book_furrier": ["furn", "books", true], "book_gunwright": ["furn", "books", true],
	"book_herbal": ["furn", "books", true], "book_hymnal": ["furn", "books", true], "book_kanun": ["furn", "books", true],
	"book_lamp": ["furn", "books", true], "book_rigging": ["furn", "books", true], "book_saga": ["furn", "books", true],
	"book_salter": ["furn", "books", true], "book_ship": ["furn", "books", true],
	"meat": ["food", "meat-ribs"], "raw_meat": ["food", "meat-raw"], "roast": ["food", "whole-ham"],
	"broth": ["food", "bowl-broth"], "stew": ["food", "pot-stew"], "pie": ["food", "pie"], "tea": ["food", "cup-tea"],
	"tuber": ["food", "beet"], "milk": ["food", "bowl"], "salt": ["food", "bag-flat"],
	"wood": ["castle", "tree-log"], "stone": ["castle", "rocks-small"],
}


## The great ones' powers, taken up at a Trophy Shrine (see the waste's take_power).
const POWERS := {
	"t_ash": {"key": "ember", "name": "Ember Heart", "text": "The cold does not bite you, and ash does not choke you."},
	"t_dunes": {"key": "hush", "name": "The Choir's Hush", "text": "Forms see you at little more than half the distance."},
	"t_salt": {"key": "white", "name": "White Breath", "text": "Running, swinging and swimming cost far less breath."},
	"t_forest": {"key": "eye", "name": "The Watcher's Eye", "text": "Your blows and shots strike a fifth harder."},
	"t_basalt": {"key": "gilt", "name": "Gilded Skin", "text": "Every blow you take is a fifth lighter."},
	"t_marsh": {"key": "tar", "name": "Tar Lungs", "text": "You swim without tiring, and the sea cannot drown you."},
}

## Loot tables: [item, weight, min, max]
const LOOT := {
	"caravan": [["tuber_seed", 2, 2, 5], ["herb_seed", 1, 1, 3], ["rounds", 3, 8, 20], ["rifle", 2, 15, 40], ["scrap", 5, 2, 5], ["cloth", 4, 2, 4], ["salt", 4, 6, 18], ["shells", 4, 6, 14], ["meat", 2, 1, 2], ["oil", 1, 1, 1], ["coin", 2, 1, 4], ["bandage", 2, 1, 2], ["fittings_fine", 1, 1, 1]],
	"shrine": [["coin", 4, 1, 5], ["icon", 2, 1, 1], ["herb", 3, 2, 4], ["bell", 1, 1, 1], ["cloth", 2, 1, 3], ["salve", 1, 1, 1]],
	"order": [["rifle", 2, 20, 50], ["rounds", 2, 10, 24], ["ledger", 3, 1, 1], ["coin", 4, 2, 6], ["scrap", 3, 2, 4], ["icon", 1, 1, 1], ["shells", 3, 8, 16], ["oil", 1, 1, 2], ["bandage", 2, 1, 3], ["fittings_fine", 2, 1, 2], ["fittings_rare", 1, 1, 1]],
	"camp": [["tuber_seed", 2, 2, 4], ["rounds", 3, 6, 16], ["meat", 3, 1, 3], ["cloth", 3, 1, 3], ["wood", 2, 3, 8], ["shells", 4, 4, 12], ["bandage", 3, 1, 2], ["salt", 3, 4, 12], ["bone", 2, 2, 5], ["fittings_fine", 1, 1, 1]],
	"vault": [["rockets", 1, 1, 2], ["rifle", 3, 30, 60], ["coin", 4, 4, 10], ["bell", 2, 1, 2], ["icon", 2, 1, 2], ["salve", 2, 1, 2], ["ledger", 2, 1, 2], ["oil", 2, 1, 2], ["shells", 3, 12, 24], ["milk", 1, 1, 1], ["fittings_rare", 2, 1, 1], ["fittings_storied", 1, 1, 1]],
	"corpse": [["rounds", 3, 4, 10], ["shells", 5, 3, 8], ["bone", 3, 1, 3], ["cloth", 3, 1, 2], ["salt", 3, 2, 8], ["coin", 1, 1, 2], ["meat", 1, 1, 1]],
}

## Lost books found in the waste's ruins, in the order they turn up; and the one each isle keeps.
const LAND_BOOKS := ["book_ship", "book_furrier", "book_herbal", "book_rigging", "book_salter", "book_lamp", "book_gunwright"]
const ISLE_BOOKS := {"hrafn": "book_saga", "fen": "book_hymnal", "kala": "book_kanun", "cog": "book_engine"}

## What each trader keeps for sale, beyond what reputation opens.
const STOCK := {
	"trader": ["shells", "rounds", "tuber_seed", "tuber", "bandage", "meat", "cloth", "scrap", "oil"],
	"oilwright": ["oil", "herb", "beacon_oil"],
	"smith": ["pick", "hatchet", "prybar", "scrap", "shells", "rounds", "rifle", "rockets", "fittings_fine"],
	"healer": ["bandage", "salve", "salts", "herb", "herb_seed", "milk"],
	"quartermaster": ["shells", "rounds", "rifle", "meat", "cloth", "bandage", "scrap"],
}


## Which ammunition each gun takes.
const AMMO := {"shotgun": "shells", "pistol": "rounds", "revolver": "rounds", "machine_gun": "rifle", "sniper": "rifle", "minigun": "rifle", "rocket": "rockets", "flamer": "fuel"}


static func info(id: String) -> Dictionary:
	if WArms.WEAR.has(id):
		var wr: Dictionary = WArms.WEAR[id]
		return {"name": wr.name, "kind": "wear", "stack": 1, "value": 6 * wr.cost.values().reduce(func(a, b): return a + b, 0) / 3, "color": Color(0.55, 0.5, 0.45), "text": wr.text}
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
