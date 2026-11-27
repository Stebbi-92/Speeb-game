extends SceneTree
## Writes the wiki pages that come straight from the game's own tables (items, making, building,
## creatures, skills, controls, places), so the wiki never drifts from the game.
## Run: godot --headless --path . -s tools/wiki.gd      Pages land in docs/wiki/.

const OUT := "res://docs/wiki/"
const NOTE := "_This page is made from the game's own data by `tools/wiki.gd`. Edit the game, not this page._\n\n"


func _init() -> void:
	_items()
	_making()
	_building()
	_creatures()
	_skills()
	_controls()
	_places()
	_sea()
	_seasons()
	_tales()
	print("wiki pages written")
	quit()


func _write(name: String, text: String) -> void:
	var f := FileAccess.open(OUT + name + ".md", FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _cost(c: Dictionary) -> String:
	var parts: Array = []
	for k in c:
		parts.append("%d %s" % [int(c[k]), Items.iname(k)])
	return ", ".join(parts)


const KIND_ORDER := [["food", "Food"], ["medicine", "Medicine"], ["aid", "Aid"], ["seed", "Seeds"], ["material", "Materials"],
	["ammo", "Ammunition"], ["tool", "Tools"], ["wear", "Clothing"], ["trinket", "Trinkets"], ["trophy", "Trophies"], ["quest", "Errand items"]]


func _items() -> void:
	var t := "# Items\n\n" + NOTE + "Everything that can be carried in the Ashen Waste. Worth is in salt, the coin of the waste.\n"
	for ko in KIND_ORDER:
		var rows: Array = []
		for id in Items.DB:
			var d: Dictionary = Items.DB[id]
			if d.kind == ko[0]:
				rows.append(id)
		if rows.is_empty():
			continue
		t += "\n## %s\n\n| Item | Stack | Worth | Notes |\n|---|---|---|---|\n" % ko[1]
		for id in rows:
			var d: Dictionary = Items.DB[id]
			var extra: Array = []
			if d.has("heal") and float(d.heal) > 0.0:
				extra.append("heals %d" % int(d.heal))
			if d.has("food"):
				extra.append("feeds %d" % int(d.food))
			t += "| **%s** | %d | %d | %s%s |\n" % [d.name, int(d.stack), int(d.value), d.text, (" (" + ", ".join(extra) + ")") if not extra.is_empty() else ""]
	_write("Items", t)


func _making() -> void:
	var t := "# Making\n\n" + NOTE
	t += "Open your pack (**I**) and choose **Make**. Inside a base, the chests of that base count as part of your pack, so there is no need to fetch things first. Some things need a **workbench** or a **cooking station** close by.\n"
	for g in [["By hand", false, false], ["At a cooking station", false, true], ["At a workbench", true, false]]:
		t += "\n## %s\n\n| Makes | From | Note |\n|---|---|---|\n" % g[0]
		for r in Items.RECIPES:
			if bool(r.bench) == g[1] and bool(r.get("fire", false)) == g[2]:
				var note := ""
				if r.has("needs"):
					note = "Learned during the main story"
				t += "| %d %s | %s | %s |\n" % [int(r.n), Items.iname(r.id), _cost(r.cost), note]
	_write("Making", t)


func _building() -> void:
	var t := "# Building\n\n" + NOTE
	t += "Press **B** to build. Scroll to choose a piece, left click to place it, **R** to turn it, right click to take a built piece down (you get most of it back). A campfire makes a base: chests within it are used when you make or build there.\n"
	t += _build_rungs()
	for g in Items.GROUPS:
		t += "\n## %s\n\n| Piece | Cost | Strength | Notes |\n|---|---|---|---|\n" % g
		for id in Items.PIECE_ORDER:
			var p: Dictionary = Items.PIECES[id]
			if p.group == g:
				t += "| **%s** | %s | %d | %s |\n" % [p.name, _cost(p.cost), int(p.hp), p.text]
	_write("Building", t)


## What opens when: the rungs of building and the steps of building up (WBuildTiers).
func _build_rungs() -> String:
	var t := "\n## What opens when\n\nA new world builds only a camp. Each fire lit opens more, for the whole fellowship, and the later pieces want the stuff of the harder lands. Pieces not yet open show greyed in the build menu with what opens them.\n\n| Opens with | Pieces |\n|---|---|\n"
	for r in WBuildTiers.RUNGS:
		var names: Array = []
		for k in r.pieces:
			names.append(Items.PIECES[k].name)
		t += "| %s | %s |\n" % [WBuildTiers.need_text(r.need) if not r.need.is_empty() else "The start", ", ".join(names)]
	t += "\n## Building up\n\nLook at a wall, window, doorway or floor and press **E** to build it up a step.\n\n| Step | Strength | Cost | Opens with |\n|---|---|---|---|\n"
	for m in WBuildTiers.MATERIALS:
		t += "| %s | x%s | %s | %s |\n" % [m.name, str(m.hp), _cost(m.cost) if not m.cost.is_empty() else "", WBuildTiers.need_text(m.need) if not m.need.is_empty() else "The start"]
	return t


func _creatures() -> void:
	var t := "# Creatures\n\n" + NOTE
	t += "The forms of the waste. Most bite: watch for the head swelling and glowing, then dodge (**Q**) or step back. Heavy harm at once, or a blade, makes them reel. A shot to the head does more.\n\n"
	t += "Foes of the waste that walk like people (the Unlit, the Hollowed and the rest) keep to their camps and ruins until they see or hear you. Gunfire carries far; a suppressed shot hardly at all. One that spots you calls the others.\n\n"
	t += "| Creature | Health | Bite | Weak to | Hard against | How to fight it |\n|---|---|---|---|---|---|\n"
	var harms := {"shot": "shotgun spread", "bullet": "bullets", "blast": "blasts", "blade": "blades", "fire": "fire"}
	for k in LesserSpeeb.KINDS:
		var s: Dictionary = LesserSpeeb.KINDS[k]
		var weak: Array = []
		for h in s.weak:
			weak.append(harms.get(h, h))
		var tough: Array = []
		for h in s.tough:
			tough.append(harms.get(h, h))
		var how: String = s.text
		if float(s.get("plate", 0.0)) > 0.0:
			how += " Wears plate (%d): aim for the head, or use piercing rounds." % int(s.plate)
		t += "| **%s** | %d | %s | %s | %s | %s |\n" % [s.name, int(s.hp), str(int(s.bite)) if float(s.bite) > 0.0 else "none", ", ".join(weak), ", ".join(tough), how]
	t += "\n## The great ones\n\nEach land has one, in its lair. When its lair is ready it shows on the map as a red mark. It sleeps until you call it out at the stone before its lair. Bring friends.\n\n| Great one | Land | Health | Its ways |\n|---|---|---|---|\n"
	var ways := {"slam": "breaks the ground around it", "brood": "brings forth lesser forms", "volley": "a fan of bolts", "blink": "watched too long, it is suddenly elsewhere", "charge": "charges in a straight line", "rain": "rains fire in circles"}
	for b in LesserSpeeb.BOSSES:
		var s: Dictionary = LesserSpeeb.BOSSES[b]
		var w: Array = []
		for x in s.ways:
			w.append(ways.get(x, x))
		t += "| **%s** | %s | %d | %s |\n" % [s.name, str(s.land).capitalize(), int(s.hp), "; ".join(w)]
	_write("Creatures", t)


func _skills() -> void:
	var t := "# Skills\n\n" + NOTE
	t += "Everything you do earns experience. Each level gives a point to spend; press **K** to see the skills. Deeper skills open as you level (the tier is the level at which they open).\n"
	for tr in WSkills.TREES:
		var tree: Dictionary = WSkills.TREES[tr]
		t += "\n## %s\n\n_%s_\n\n| Skill | Ranks | Opens at | Does |\n|---|---|---|---|\n" % [tree.name, tree.text]
		for id in tree.skills:
			var s: Dictionary = WSkills.SKILLS[id]
			t += "| **%s** | %d | %s | %s |\n" % [s.name, int(s.ranks), "start" if int(s.tier) == 0 else "level %d" % (int(s.tier) + 1), s.text]
	t += "\n## Experience\n\n| Deed | Experience |\n|---|---|\n"
	var deeds := {"kill": "Undo a form", "kill_elite": "Undo a great beast", "kill_boss": "Undo a great one", "assist": "Help undo a form",
		"gather": "Gather", "make": "Make something", "build": "Build a piece", "step": "A step of a task", "step_main": "A step of the main story",
		"quest": "Finish a task", "beacon": "Kindle a beacon", "dawn": "Live through a night", "settlement": "Find a settlement", "ruin": "Find a ruin", "biome": "Enter a new land"}
	for k in WSkills.XP:
		t += "| %s | %d |\n" % [deeds.get(k, k), int(WSkills.XP[k])]
	_write("Skills", t)


func _controls() -> void:
	var t := "# Controls\n\n" + NOTE + "Every control can be changed in **Settings**. These are the defaults.\n\n| Action | Keys |\n|---|---|\n"
	var G = load("res://scripts/game.gd")
	for c in G.CONTROLS:
		var ks: Array = []
		for k in c[2]:
			ks.append(G.key_name(int(k)))
		t += "| %s | %s |\n" % [c[1], " or ".join(ks)]
	t += "\n## Controller\n\nA controller works too: the left stick walks, the right stick looks.\n\n| Action | Button |\n|---|---|\n"
	var pad_names := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
		JOY_BUTTON_LEFT_STICK: "Left stick press", JOY_BUTTON_RIGHT_STICK: "Right stick press", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
		JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back"}
	for c in G.CONTROLS:
		for p in G.PAD.get(c[0], []):
			if p is Array:
				if int(p[0]) == JOY_AXIS_TRIGGER_RIGHT:
					t += "| %s | RT |\n" % c[1]
				elif int(p[0]) == JOY_AXIS_TRIGGER_LEFT:
					t += "| %s | LT |\n" % c[1]
			else:
				t += "| %s | %s |\n" % [c[1], pad_names.get(p, str(p))]
	t += "\nIn menus: **Esc** closes. In a chest, **R** takes everything. Holding **E** on a dropped satchel takes everything without opening it. **Enter** makes the chosen thing at the workbench.\n"
	_write("Controls", t)


func _places() -> void:
	var t := "# Places\n\n" + NOTE + "## Settlements\n\nWalled places where people live, trade and give work. Inside their walls, no form rises.\n\n"
	for k in WPlaces.SETTLEMENTS:
		var s: Dictionary = WPlaces.SETTLEMENTS[k]
		t += "- **%s**: %s\n" % [s.name, s.blurb]
	t += "\n## Lands\n\nThe waste is made of six lands, each with its own ground, its own weather and its own great one: %s.\n" % ", ".join(Array(WTerrain.BIOMES).map(func(b): return str(b).capitalize()))
	_write("Places", t)


func _sea() -> void:
	var t := "# The Grey Sea\n\n" + NOTE + "Past the coast of the waste lies the Grey Sea, and four isles. Each isle is its own land, with its own foes, and a ruin at its heart that keeps a lost book.\n\n## The isles\n\n"
	for k in WIsles.ORDER:
		var th: Dictionary = WIsles.THEMES[k]
		t += "- **%s**: %s Its ruin is %s.\n" % [th.name, th.text, th.ruin[0]]
	t += "\nEach isle has a pier facing the waste, a hut by it, and two wrecks with something left aboard.\n"
	t += "\n## Swimming\n\nSwimming costs breath, and running in the water costs much more. Out of breath in deep water, you drown. Something lives in the open sea, far from land: keep moving, or keep near the shore.\n"
	t += "\n## Boats\n\n| Boat | Seats | Strength | How it moves |\n|---|---|---|---|\n"
	for k in WBoat.KINDS:
		var b: Dictionary = WBoat.KINDS[k]
		t += "| %s | %d | %d | %s |\n" % [b.name, int(b.seats), int(b.hp), b.text]
	t += "\nMake a boat at a workbench, then use it from your pack at the shore to launch it. The first aboard takes the helm. Boats run aground in the shallows. Hold the use key on a hurt boat to mend it with 4 wood.\n"
	t += "\n## Lost books\n\nRead a lost book and the whole fellowship learns what it teaches.\n\n"
	for id in Items.LAND_BOOKS + Items.ISLE_BOOKS.values():
		var info: Dictionary = Items.info(id)
		t += "- **%s**: %s\n" % [info.name, info.text]
	_write("The-Grey-Sea", t)


func _seasons() -> void:
	var t := "# Seasons and Weather\n\n" + NOTE + "A season lasts %d days. The nights grow longer or shorter with it.\n\n| Season | Night falls | Dawn |\n|---|---|---|\n" % WWeather.SEASON_DAYS
	for se in WWeather.SEASONS:
		t += "| %s | %s | %s |\n" % [se.name, _hour(float(se.dusk)), _hour(float(se.dawn))]
	t += "\n## Weather\n\n"
	for k in WWeather.KINDS:
		if k != "clear":
			t += "- **%s**: %s\n" % [WWeather.KINDS[k].name, WWeather.COMING[k]]
	t += "\nAn ash storm chokes anyone whose face is not covered. Salt frost bites at night unless you dress warm (a fur coat, or two warm things) or keep near a fire. In your camp or in a town, the weather does not reach you.\n"
	t += "\n## The seventh night\n\nEvery seventh night the great raid comes, in three waves, for the camp you keep or for you. You are warned two nights ahead. Beat it back, and the forms leave what they carried.\n"
	t += "\n## Trophy powers\n\nBuild a Trophy Shrine at your camp. Lay a great one's trophy on it once; from then on, kneel at any shrine to take up its power for half an hour. One power at a time.\n\n"
	for k in Items.POWERS:
		t += "- **%s** (%s): %s\n" % [Items.POWERS[k].name, Items.iname(k), Items.POWERS[k].text]
	_write("Seasons-and-Weather", t)


func _hour(h: float) -> String:
	return "%d:%02d" % [int(h), int(round((h - floor(h)) * 60.0))]


func _tales() -> void:
	var t := "# Tales\n\n" + NOTE + "The people of the towns have their own stories. Each tale is offered by one person; some open only when an earlier tale is done.\n\n| Tale | Who | Where | Opens after |\n|---|---|---|---|\n"
	for sid in WQuests.STORIES:
		var st: Dictionary = WQuests.STORIES[sid]
		var after := ""
		if str(st.get("after", "")).begins_with("done_"):
			after = WQuests.STORIES[str(st.after).substr(5)].title
		t += "| %s | %s | %s | %s |\n" % [st.title, WPlaces.PEOPLE[st.giver].name, WPlaces.SETTLEMENTS[st.at].name, after]
	_write("Tales", t)
