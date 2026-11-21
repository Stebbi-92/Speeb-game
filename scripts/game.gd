extends Node
## Global state for the pilgrimage: progress, the Book of Emojis, settings and input.

const LEVELS := ["prologue", "cliffs", "ruins", "wastes", "heights", "fields", "caves", "hollow", "stone", "lake", "epilogue", "tenth", "wasteland"]
const WASTELAND := 12
const NINE := ["speebbang", "emospeeb", "speebchef", "speebyeet", "glitchspeeb", "speebsnek", "floofspeeb", "runespeeb", "chillspeeb"]
const NAMES := {
	"speebbang": "Speebbang", "emospeeb": "Emospeeb", "speebchef": "Speebchef", "speebyeet": "Speebyeet",
	"glitchspeeb": "Glitchspeeb", "speebsnek": "Speebsnek", "floofspeeb": "Floofspeeb", "runespeeb": "Runespeeb", "chillspeeb": "Chillspeeb",
}
## Each Meowifestation survived leaves a blessing upon Brelm.
const BLESSINGS := {
	"speebbang": ["Restraint", "Your body endures more. Health rises to 125."],
	"emospeeb": ["Humility", "Each hostile form you undo restores a little health."],
	"speebchef": ["Bounty", "Health returns swiftly, and shells load faster."],
	"speebyeet": ["The Swift Cast", "Press Q to cast yourself forward."],
	"glitchspeeb": ["Riftwalk", "Press V to slow the lesser forms in time."],
	"speebsnek": ["Discernment", "Your shot strikes truer and harder."],
	"floofspeeb": ["Wakefulness", "You move more quickly than before."],
	"runespeeb": ["The Oath Ward", "A ward absorbs one blow, then slowly returns."],
}
const SAVE_PATH := "user://brelm.save"
## The hotbar. The shotgun and the Praying Hands are given at the vow; the rest are found on the road.
const RELICS := ["shotgun", "hands", "lantern", "claw", "censer", "milk"]
const RELIC_NAMES := {"shotgun": "Arms", "hands": "Praying Hands", "lantern": "Lantern of Vigil", "claw": "Claw of Ascent", "censer": "Censer", "milk": "Bowl of Milk"}
const RELIC_TEXT := {
	"lantern": "Its flame parts the dark that the eye cannot. Use it to light or quench it.",
	"claw": "Cast it at a ring of old iron and it will draw you up to it.",
	"censer": "Light it and swing it. Its smoke shows what Speeb has left unseen.",
	"milk": "Drink to restore health. Brelm can carry three bowls.",
}
const MILK_MAX := 3

var level_index := 0
var reached := 0
var found := {}
var sensitivity := 0.0025
var aim_sens := 1.0   ## looking while aiming, against what the zoom alone would give (1 = the same feel at every zoom)
var volume := 0.8
## The mixer: each kind of sound on its own line, with its own volume.
const BUSES := ["Guns", "Creatures", "World", "Interface", "Music"]
var bus_vol := {"Guns": 1.0, "Creatures": 1.0, "World": 1.0, "Interface": 1.0, "Music": 0.8}
var difficulty := 1
var judgments := {}
var relics := {}
var milk := 1
var milk_bag = null     ## the pack the waste keeps its milk in
# Options
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const DISPLAY_MODES := ["Windowed", "Fullscreen", "Exclusive fullscreen"]
const FPS_CAPS := [30, 60, 120, 144, 0]
const AA_MODES := ["Off", "MSAA 2x", "MSAA 4x"]
var display_mode := 0
var resolution := 1
var vsync := true
var fps_cap := 4
var aa := 1
var fov := 72.0
var blood := true   ## foes bleed where they are struck
var embers_on := true   ## in the waste, embers now and then drift toward the goal being followed
var head_bob := true
var invert_y := false
var pad_invert := false   ## the right stick's up and down turned over (apart from the mouse)
var brightness := 1.0   ## the whole picture lighter or darker, 0.7 to 1.4
var voice_lines := true
var subtitles := false   ## spoken lines are also written out on screen
var toggles := {"run": false, "soft": false, "aim": false}   ## press once to start, again to stop (not hold)
var _toggled := {}
var reports := 0   ## error reports: 0 ask, 1 always send, 2 never
const ErrorReport := preload("res://scripts/report.gd")
var report: Node
var colorblind := false  ## colours that tell things apart are chosen to read with red-green colour blindness
## Road safety colours, Dangerous to Peaceful: the usual red-to-green, or blue-to-orange that reads for all.
const SAFETY_TINTS := [Color(0.85, 0.2, 0.15), Color(0.9, 0.6, 0.2), Color(0.35, 0.75, 0.35), Color(0.95, 0.85, 0.5)]
const SAFETY_TINTS_CB := [Color(0.84, 0.37, 0.0), Color(0.94, 0.89, 0.26), Color(0.0, 0.45, 0.7), Color(0.34, 0.71, 0.91)]


## The colour of a town's road safety (0 to 100), in the palette chosen in Settings.
func safety_tint(sv: float) -> Color:
	var i := 0 if sv < 25 else (1 if sv < 60 else (2 if sv < 90 else 3))
	return (SAFETY_TINTS_CB if colorblind else SAFETY_TINTS)[i]
var guide := true   ## the first-steps guide in the waste
var quality := 1          ## 0 Low, 1 Standard, 2 High
const RENDER_SCALES := [1.0, 0.85, 0.7, 0.5]
var render_scale := 0     ## how sharply the world is drawn, sharpened back up when below full
const UI_SCALES := [0.9, 1.0, 1.1, 1.2]
var ui_scale := 1         ## how large menus, words and the HUD are drawn
var gilded := false
var player_name := ""
var lobby_url := ""
var forms_style := 0      ## the lesser forms: 0 flesh (cat heads), 1 masks (their emojis)
var look := Figure.DEFAULT.duplicate()   ## how this pilgrim appears to others
var wrules := {}   ## the rules of the world of the waste now walked; empty outside it
var unlimited_ammo := false   ## a hosting choice: guns never spend their reserve
var pxp := 0                 ## profile experience, earned in every mode; unlocks arms
var plevel := 1
var loadout := ArmsDB.DEFAULT.duplicate(true)
var autosave_min := 2          ## minutes between autosaves in the waste
## The open waste: which world is walked, and whether we are walking it now.
var world_slot := "1"
var new_world_seed := 0
var new_world_rules := {}   ## settings chosen for a world about to begin
var wasteland := false
## Revelations: deeds the pilgrimage remembers.
const REVELATIONS := {
	"first_blood": ["The First Undoing", "Undo a lesser form."],
	"hundred": ["A Hundred Undone", "Undo one hundred lesser forms. The gilded finish is yours: turn it on in Settings."],
	"five_hundred": ["Five Hundred Undone", "Undo five hundred lesser forms."],
	"streak5": ["Litany of Five", "Undo five forms in one unbroken litany."],
	"streak10": ["Litany of Ten", "Undo ten forms in one unbroken litany."],
	"streak20": ["The Unbroken Litany", "Undo twenty forms in one unbroken litany."],
	"saucer": ["The Fallen Vessel", "Bring down a saucer."],
	"saucer5": ["Breaker of Vessels", "Bring down five saucers."],
	"elite": ["Crown Unmade", "Undo a crowned greater form."],
	"pray": ["Hands Lifted", "Pray with the Praying Hands."],
	"pray5": ["A Multitude Answered", "Undo five forms with a single prayer."],
	"milk": ["Sustained", "Drink a bowl of milk."],
	"lantern": ["The Dark Was a Door", "Part the darkness in the Mirror Caves."],
	"claw": ["Ascent", "Cross the broken stair with the Claw."],
	"censer": ["What the Smoke Shows", "Find the way out of the Fields of Forgetting."],
	"first_trial": ["Changed", "Survive a Meowifestation."],
	"all_nine": ["Speeb Stares Back", "Witness all Nine Meowifestations."],
	"balanced": ["In Balance", "Have three trials judged Balanced."],
	"flawless": ["Unblemished", "Survive a Meowifestation's judgment without being struck."],
	"scribe": ["Scribe of Forms", "Record thirty lesser forms in the Book of Emojis."],
	"unblinking": ["Unblinking", "Complete a trial on Unblinking difficulty."],
	"tenth": ["The Hall of Emojis", "Complete the Tenth Trial."],
	"leaves": ["The Hermit's Hand", "Gather all ten Leaves of Brelm's journal."],
	"shades": ["Listener", "Hear every wayfarer shade to the end."],
	"stillness": ["Beneath the Eye", "Stay perfectly still while the Unblinking Eye watches."],
	"velm": ["The Pen Set Down", "Face Velm in the Forgotten Cave, having read every Leaf."],
}
var leaves := {}
var shades_heard := {}
var revealed := {}
var stats := {"kills": 0, "saucers": 0, "best_streak": 0}
const TENTH_NEEDS := 60
const LEVEL_NAMES := ["The Plateau of Mirrors", "The Cliffs of Echoing Cries", "The Ruins of the Fallen Kings", "The Verdant Wastes",
	"The Heights of Sorrows", "The Fields of Forgetting", "The Mirror Caves", "The Hollow of False Comfort", "The Sealed Stone", "The Silent Lake"]
const DIFFICULTIES := ["Pilgrim", "Hermit", "Unblinking"]
const DIFF_SCALE := {
	"hp": [0.75, 1.0, 1.3], "speed": [0.85, 1.0, 1.12], "damage": [0.55, 1.0, 1.4], "alive": [-1.0, 0.0, 2.0], "regen": [1.6, 1.0, 0.35],
}
var nine := {}
var lesser := {}
var meta := {}
var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	nine = _json("res://assets/nine.json")
	meta = _json("res://assets/emoji/meta.json")
	for e in _json("res://assets/lesser.json"):
		lesser[e.code] = e
	load_save()
	report = ErrorReport.new()
	add_child(report)
	if not OS.get_cmdline_user_args().size() > 0:
		apply_display.call_deferred()


func _json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


## Every control that may be changed: [action, what it is called, its keys]. A key is its physical keycode;
## a mouse button is written as a negative number (-1 left, -2 right, -3 middle, -8 and -9 the side buttons).
const CONTROLS := [
	["move_forward", "Walk forward", [KEY_W, KEY_UP]], ["move_back", "Walk back", [KEY_S, KEY_DOWN]],
	["move_left", "Step left", [KEY_A, KEY_LEFT]], ["move_right", "Step right", [KEY_D, KEY_RIGHT]],
	["jump", "Jump", [KEY_SPACE]], ["run", "Sprint", [KEY_SHIFT]], ["soft", "Sneak", [KEY_CTRL, KEY_C]],
	["interact", "Interact", [KEY_E]],
	["fire", "Fire, use, or build", [-1]], ["aim", "Aim, or take down a built piece", [-2]],
	["reload", "Reload, or turn a piece", [KEY_R]], ["swap_gun", "Change gun", [KEY_X]],
	["melee", "Melee", [KEY_Z]], ["grenade", "Grenade", [KEY_G]], ["gadget", "Gadget", [KEY_T]], ["streak", "Call a kill streak", [KEY_H]],
	["dash", "Dodge (the waste), Swift Cast", [KEY_Q]], ["riftwalk", "Riftwalk", [KEY_V]], ["whistle", "Whistle for your cat (the waste)", [KEY_N]],
	["revive", "Use smelling salts on a fallen friend", [KEY_Y]], ["quick_heal", "Use your best healing (the waste)", [KEY_F]],
	["slot_1", "Relic 1 (arms)", [KEY_1]], ["slot_2", "Relic 2", [KEY_2]], ["slot_3", "Relic 3", [KEY_3]],
	["slot_4", "Relic 4", [KEY_4]], ["slot_5", "Relic 5", [KEY_5]], ["slot_6", "Relic 6", [KEY_6]],
	["slot_7", "Relic 7 (milk in the waste)", [KEY_7]], ["slot_8", "Claw (the waste)", [KEY_8]], ["slot_9", "Censer (the waste)", [KEY_9]],
	["codex", "The Book of Emojis", [KEY_TAB]], ["fellowship", "Player list (together)", [KEY_L]],
	["pack", "Pack (the waste)", [KEY_I]], ["map", "Map (the waste)", [KEY_M]], ["journal", "Journal (the waste)", [KEY_J]],
	["skills", "Skills (the waste)", [KEY_K]], ["build", "Build (the waste)", [KEY_B]],
	["pause", "Menu", [KEY_ESCAPE, KEY_P]],
]
var binds := {}   ## action -> [codes], only for those the player has changed


## A controller's buttons and sticks, fixed. A number is a button; [axis, direction] is a stick or trigger.
const PAD := {
	"move_forward": [[JOY_AXIS_LEFT_Y, -1.0]], "move_back": [[JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [[JOY_AXIS_LEFT_X, -1.0]], "move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	"jump": [JOY_BUTTON_A], "dash": [JOY_BUTTON_B], "interact": [JOY_BUTTON_X], "reload": [JOY_BUTTON_Y],
	"fire": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], "aim": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"swap_gun": [JOY_BUTTON_RIGHT_SHOULDER], "grenade": [JOY_BUTTON_LEFT_SHOULDER],
	"run": [JOY_BUTTON_LEFT_STICK], "melee": [JOY_BUTTON_RIGHT_STICK],
	"map": [JOY_BUTTON_DPAD_UP], "pack": [JOY_BUTTON_DPAD_DOWN], "journal": [JOY_BUTTON_DPAD_LEFT], "build": [JOY_BUTTON_DPAD_RIGHT],
	"pause": [JOY_BUTTON_START],
}
## Held on a controller, the quick wheel (see PadWheel): healing, whistle, salts, relics, the fellowship list.
const PAD_WHEEL := JOY_BUTTON_BACK
var pad_look := 3.2   ## how fast the right stick turns you, in radians a second at full tilt


## Controller buttons the player has changed: action -> [button, or [axis, direction]]. The rest follow PAD.
var pad_binds := {}


## Where a node stands in the world, even after it has left the tree (saves made on quit run then,
## and global_position would read as the world's middle).
static func world_pos(n: Node3D) -> Vector3:
	if n.is_inside_tree():
		return n.global_position
	var t := n.transform
	var up := n.get_parent()
	while up is Node3D and not n.top_level:
		t = (up as Node3D).transform * t
		up = up.get_parent()
	return t.origin


func pad_of(action: String) -> Array:
	return pad_binds.get(action, PAD.get(action, []))


## A controller button or trigger as words, Xbox style: "A", "RB", "LT", "D-pad up".
static func pad_name(p) -> String:
	if p is Array:
		var names := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}
		if names.has(int(p[0])):
			return names[int(p[0])]
		return "%s stick %s" % ["Left" if int(p[0]) < 2 else "Right", ["left", "right", "up", "down"][(int(p[0]) % 2) * 2 + (1 if float(p[1]) > 0.0 else 0)]]
	return {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "Left stick press",
		JOY_BUTTON_RIGHT_STICK: "Right stick press", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back",
		JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left",
		JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_GUIDE: "Guide"}.get(int(p), "Button %d" % int(p))


## Sets an action's controller button, taking it away from any other action that had it.
func rebind_pad(action: String, p) -> void:
	for c in CONTROLS:
		if c[0] != action and pad_of(c[0]).has(p):
			var other: Array = pad_of(c[0]).duplicate()
			other.erase(p)
			pad_binds[c[0]] = other
	pad_binds[action] = [p]
	_setup_input()
	save()


func _setup_input() -> void:
	for c in CONTROLS:
		_bind(c[0], binds.get(c[0], c[2]))
		for p in pad_of(c[0]):
			if p is Array:
				var m := InputEventJoypadMotion.new()
				m.axis = p[0]
				m.axis_value = p[1]
				InputMap.action_add_event(c[0], m)
			else:
				var b := InputEventJoypadButton.new()
				b.button_index = p
				InputMap.action_add_event(c[0], b)
		InputMap.action_set_deadzone(c[0], 0.3)
	if not InputMap.has_action("pad_wheel"):
		InputMap.add_action("pad_wheel")
		var wb := InputEventJoypadButton.new()
		wb.button_index = PAD_WHEEL
		InputMap.action_add_event("pad_wheel", wb)


## The keys now set for an action.
func keys_of(action: String) -> Array:
	for c in CONTROLS:
		if c[0] == action:
			return binds.get(action, c[2])
	return []


static func key_name(code: int) -> String:
	if code < 0:
		return {-1: "Left mouse", -2: "Right mouse", -3: "Middle mouse", -8: "Mouse 4", -9: "Mouse 5"}.get(code, "Mouse %d" % -code)
	return OS.get_keycode_string(code)


## What to press, as words: "E", or "E or F".
func key_text(action: String, all := false) -> String:
	# Playing with a controller, prompts name its buttons
	if using_pad and not pad_of(action).is_empty():
		var ps := pad_of(action)
		return " or ".join(ps.map(func(p): return pad_name(p))) if all else pad_name(ps[0])
	var ks := keys_of(action)
	if ks.is_empty():
		return "unset"
	if all:
		return " or ".join(ks.map(func(k): return key_name(int(k))))
	return key_name(int(ks[0]))


## Sets one of an action's two keys, taking that key away from any other action that held it.
func rebind(action: String, slot: int, code: int) -> void:
	for c in CONTROLS:
		if c[0] == action:
			continue
		var other: Array = keys_of(c[0]).duplicate()
		if code in other and c[0] != "pause":
			other.erase(code)
			binds[c[0]] = other
	var ks: Array = keys_of(action).duplicate()
	while ks.size() <= slot:
		ks.append(code)
	ks[slot] = code
	var uniq := []
	for k in ks:
		if not k in uniq:
			uniq.append(k)
	binds[action] = uniq
	_setup_input()
	save()


func reset_binds() -> void:
	binds.clear()
	pad_binds.clear()
	_setup_input()
	save()


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for k in keys:
		if int(k) < 0:
			var mb := InputEventMouseButton.new()
			mb.button_index = -int(k)
			InputMap.action_add_event(action, mb)
		else:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(k)
			InputMap.action_add_event(action, ev)


## Replaces :code: tokens in scripture with the spoken name of the form.
func scripture(text: String) -> String:
	var re := RegEx.new()
	re.compile(":([a-z0-9]+):")
	var out := text
	for m in re.search_all(text):
		var code := m.get_string(1)
		out = out.replace(m.get_string(), NAMES.get(code, code))
	return out


func find_emoji(code: String) -> bool:
	if found.has(code):
		return false
	found[code] = true
	save()
	return true


func difficulty_scale(key: String) -> float:
	return DIFF_SCALE[key][int(wrules.get("difficulty", difficulty)) if wasteland else difficulty]


## How a trial was walked: the Balance between excess and apathy, and how often Brelm fell.
func judge(level_i: int, kills: int, falls: int, witnessed: int) -> String:
	var verdict := "Balanced"
	if falls >= 3:
		verdict = "Found Wanting"
	elif kills > 70:
		verdict = "Tilted toward Excess"
	elif kills < 6:
		verdict = "Tilted toward Apathy"
	elif witnessed == 0:
		verdict = "Blind to the Lesser"
	judgments[str(level_i)] = verdict
	save()
	return verdict


func balanced_count() -> int:
	var n := 0
	for k in judgments:
		if judgments[k] == "Balanced":
			n += 1
	return n


func tenth_unlocked() -> bool:
	return lesser_count() >= TENTH_NEEDS


## Marks a deed as revealed, once, and announces it.
func reveal_deed(id: String) -> void:
	if revealed.has(id) or not REVELATIONS.has(id):
		return
	revealed[id] = true
	save()
	if main and main.hud:
		main.hud.revelation(REVELATIONS[id][0], REVELATIONS[id][1])


func add_kill(kind: String) -> void:
	stats.kills += 1
	gain_pxp(60 if kind in ["elite", "saucer"] else 10)
	reveal_deed("first_blood")
	if stats.kills >= 100:
		reveal_deed("hundred")
	if stats.kills >= 500:
		reveal_deed("five_hundred")
	if kind == "saucer":
		stats.saucers += 1
		reveal_deed("saucer")
		if stats.saucers >= 5:
			reveal_deed("saucer5")
	if kind == "elite":
		reveal_deed("elite")
	if lesser_count() >= 30:
		reveal_deed("scribe")


func has_relic(id: String) -> bool:
	if wasteland:
		return id in ["shotgun", "hands", "lantern"] or (id == "milk" and milk_count() > 0) or id in warms.get("relics", [])
	return id in ["shotgun", "hands"] or (id == "milk" and milk > 0) or relics.has(id)


## Milk on hand. In the waste it is carried in the pack like anything else.
func milk_count() -> int:
	if wasteland and milk_bag != null:
		return milk_bag.count("milk")
	return milk


func spend_milk() -> void:
	if wasteland and milk_bag != null:
		milk_bag.take("milk", 1)
	else:
		milk -= 1
		save()


func gain_relic(id: String) -> void:
	relics[id] = true
	save()


func blessed(code: String) -> bool:
	return found.has(code) and BLESSINGS.has(code)


func lesser_count() -> int:
	var n := 0
	for c in found:
		if lesser.has(c):
			n += 1
	return n


## Writes a save so that a crash or power cut mid-write can never ruin it: the text goes to a
## .tmp file first, the old save is kept as .bak, and only then is the new one moved into place.
static func write_safe(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	if FileAccess.get_file_as_string(tmp).length() != text.length():
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path) == OK


## The texts a save might be read from, newest first: the save itself, then its backup.
static func save_texts(path: String) -> Array[String]:
	var out: Array[String] = []
	# A finished .tmp is newer than the .bak: it is only left when the game stopped between the two renames
	for p in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(p):
			var t := FileAccess.get_file_as_string(p)
			if t.strip_edges() != "":
				out.append(t)
	return out


## Reads a var_to_str save, falling back to the backup if the newest is damaged.
static func read_var_safe(path: String) -> Variant:
	for t in save_texts(path):
		var d = str_to_var(t)
		if d is Dictionary:
			return d
	return null


# ------------------------------------------------------------------ the pilgrim's arms and their growing

## Adds profile experience; returns the levels gained. Every mode feeds it.
func add_pxp(n: int) -> int:
	if n <= 0 or plevel >= ArmsDB.MAX_LEVEL:
		return 0
	pxp += n
	var ups := 0
	while plevel < ArmsDB.MAX_LEVEL and pxp >= ArmsDB.need(plevel):
		pxp -= ArmsDB.need(plevel)
		plevel += 1
		ups += 1
	return ups


## Profile experience with a word on screen when a new rank is reached.
func gain_pxp(n: int) -> void:
	var ups := add_pxp(n)
	if ups <= 0 or main == null or main.hud == null:
		return
	var got: Array = []
	for lv in range(plevel - ups + 1, plevel + 1):
		got.append_array(ArmsDB.unlocked_at(lv))
	main.hud.notify("Rank %d.%s" % [plevel, (" Now yours: " + ", ".join(got) + ". Choose it before the next trial.") if not got.is_empty() else ""])
	save()


func unlocked(t: Dictionary, id: String) -> bool:
	return t.has(id) and int(t[id].unlock) <= plevel


## Puts anything not yet earned (or no longer known) back to the defaults.
func _fix_loadout() -> void:
	for k in ["primary", "secondary", "melee", "grenade", "gadget"]:
		var t := ArmsDB.table(k)
		if not unlocked(t, str(loadout.get(k, ""))) or (k in ["primary", "secondary"] and t[loadout[k]].slot != k):
			loadout[k] = ArmsDB.DEFAULT[k]
	if not loadout.get("mounts") is Dictionary:
		loadout.mounts = {}
	for g in loadout.mounts.keys():
		var keep: Array = []
		var slots := {}
		var v = loadout.mounts[g]
		for m in (v if v is Array else [str(v)]):
			if ArmsDB.GUNS.has(g) and m in ArmsDB.GUNS[g].mounts and unlocked(ArmsDB.ATTACHMENTS, m) and not slots.has(ArmsDB.ATTACHMENTS[m].slot):
				slots[ArmsDB.ATTACHMENTS[m].slot] = true
				keep.append(m)
		if keep.is_empty():
			loadout.mounts.erase(g)
		else:
			loadout.mounts[g] = keep


## The arms in use: the waste keeps its own, apart from the loadout of the trials.
var warms := {}


## How this pilgrim appears to others: as dressed, with what is worn in the waste over it.
func shown_look() -> Dictionary:
	var l: Dictionary = look.duplicate()
	if wasteland and warms.get("wear") is Dictionary:
		for slot in warms.wear:
			var it: Dictionary = WArms.WEAR.get(str(warms.wear[slot]), {})
			for k in it.get("look", {}):
				l[k] = it.look[k]
	return l


func arms_now() -> Dictionary:
	return warms if wasteland and not warms.is_empty() else loadout


## Everything fitted to a gun.
func mounts_of(gun: String) -> Array:
	var m = arms_now().get("mounts", {})
	var v = m.get(gun, []) if m is Dictionary else []
	if v is Array:
		return v
	return [str(v)] if str(v) != "" else []


func has_mount(gun: String, id: String) -> bool:
	return id in mounts_of(gun)


## The sight on a gun; "" is iron sights.
func mount_of(gun: String) -> String:
	for m in mounts_of(gun):
		if ArmsDB.ATTACHMENTS.has(m) and ArmsDB.ATTACHMENTS[m].slot == "sight":
			return m
	return ""


## How far a gun has been worked on in the waste (0 to 3).
## What the parts and their traits do to a gun, in the waste. Elsewhere nothing changes.
func gun_mods(gun: String) -> Dictionary:
	if wasteland and not warms.is_empty():
		return WArms.mods(warms, gun)
	var out := {}
	for k in WArms.MOD_KEYS:
		out[k] = 1.0
	return out


func tier_of(gun: String) -> int:
	if not wasteland:
		return 0
	var t = warms.get("tier", {})
	return int(t.get(gun, 0)) if t is Dictionary else 0



func save() -> void:
	write_safe(SAVE_PATH, JSON.stringify({"reached": reached, "found": found.keys(), "sensitivity": sensitivity, "aim_sens": aim_sens, "volume": volume, "bus_vol": bus_vol, "difficulty": Net._own_difficulty if Net._own_difficulty >= 0 else difficulty, "judgments": judgments, "relics": relics.keys(), "milk": milk,
			"display_mode": display_mode, "resolution": resolution, "vsync": vsync, "fps_cap": fps_cap, "aa": aa,
			"fov": fov, "blood": blood, "embers": embers_on, "head_bob": head_bob, "invert_y": invert_y, "pad_invert": pad_invert, "pad_look": pad_look, "brightness": brightness, "voice_lines": voice_lines, "subtitles": subtitles, "colorblind": colorblind, "reports": reports, "toggles": toggles, "guide": guide,
			"quality": maxi(quality - 1, 0), "gfx": quality, "render_scale": render_scale, "ui_scale": ui_scale, "gilded": gilded, "revealed": revealed.keys(), "stats": stats,
			"leaves": leaves.keys(), "shades": shades_heard.keys(),
			"player_name": player_name, "lobby_url": lobby_url, "autosave_min": autosave_min, "binds": binds, "pad_binds": pad_binds,
			"pxp": pxp, "plevel": plevel, "loadout": loadout, "unlimited_ammo": unlimited_ammo, "look": look, "forms_style": forms_style}))


func load_save() -> void:
	var d = null
	for t in save_texts(SAVE_PATH):
		d = JSON.parse_string(t)
		if d is Dictionary:
			break
	if not d is Dictionary:
		apply_volume()
		return
	if d is Dictionary:
		autosave_min = clampi(int(d.get("autosave_min", autosave_min)), 0, 10)
		pxp = maxi(0, int(d.get("pxp", 0)))
		unlimited_ammo = bool(d.get("unlimited_ammo", false))
		look = Figure.clean(d.get("look", {}))
		forms_style = clampi(int(d.get("forms_style", 0)), 0, 1)
		plevel = clampi(int(d.get("plevel", 1)), 1, ArmsDB.MAX_LEVEL)
		var lo = d.get("loadout", {})
		if lo is Dictionary:
			for k in ArmsDB.DEFAULT:
				if lo.has(k) and typeof(lo[k]) == typeof(ArmsDB.DEFAULT[k]):
					loadout[k] = lo[k]
		_fix_loadout()
		reached = int(d.get("reached", 0))
		for c in d.get("found", []):
			found[c] = true
		sensitivity = clampf(float(d.get("sensitivity", sensitivity)), 0.0005, 0.006)
		aim_sens = clampf(float(d.get("aim_sens", aim_sens)), 0.2, 2.0)
		volume = clampf(float(d.get("volume", volume)), 0.0, 1.0)
		var bv = d.get("bus_vol", {})
		if bv is Dictionary:
			for k in BUSES:
				bus_vol[k] = clampf(float(bv.get(k, bus_vol[k])), 0.0, 1.0)
		difficulty = clampi(int(d.get("difficulty", difficulty)), 0, 2)
		judgments = d.get("judgments", {}) if d.get("judgments", {}) is Dictionary else {}
		for r in d.get("relics", []):
			relics[r] = true
		milk = int(d.get("milk", milk))
		display_mode = int(d.get("display_mode", display_mode))
		resolution = clampi(int(d.get("resolution", resolution)), 0, RESOLUTIONS.size() - 1)
		vsync = bool(d.get("vsync", vsync))
		fps_cap = clampi(int(d.get("fps_cap", fps_cap)), 0, FPS_CAPS.size() - 1)
		aa = clampi(int(d.get("aa", aa)), 0, 2)
		fov = clampf(float(d.get("fov", fov)), 60.0, 100.0)
		blood = bool(d.get("blood", blood))
		embers_on = bool(d.get("embers", embers_on))
		head_bob = bool(d.get("head_bob", head_bob))
		invert_y = bool(d.get("invert_y", invert_y))
		pad_invert = bool(d.get("pad_invert", invert_y))   # before, one switch turned both over
		pad_look = clampf(float(d.get("pad_look", pad_look)), 1.0, 6.0)
		brightness = clampf(float(d.get("brightness", brightness)), 0.7, 1.4)
		voice_lines = bool(d.get("voice_lines", voice_lines))
		subtitles = bool(d.get("subtitles", subtitles))
		colorblind = bool(d.get("colorblind", colorblind))
		reports = clampi(int(d.get("reports", reports)), 0, 2)
		var tg = d.get("toggles", {})
		if tg is Dictionary:
			for k in toggles:
				toggles[k] = bool(tg.get(k, false))
		guide = bool(d.get("guide", guide))
		quality = clampi(int(d.get("gfx", int(d.get("quality", 0)) + 1)), 0, 2)
		render_scale = clampi(int(d.get("render_scale", render_scale)), 0, RENDER_SCALES.size() - 1)
		ui_scale = clampi(int(d.get("ui_scale", ui_scale)), 0, UI_SCALES.size() - 1)
		gilded = bool(d.get("gilded", gilded))
		player_name = str(d.get("player_name", player_name)).left(20)
		lobby_url = str(d.get("lobby_url", lobby_url))
		if d.get("binds") is Dictionary:
			binds.clear()
			for a in d.binds:
				if d.binds[a] is Array:
					binds[str(a)] = d.binds[a].map(func(k): return int(k))
			_setup_input()
		if d.get("pad_binds") is Dictionary:
			pad_binds.clear()
			for a in d.pad_binds:
				if d.pad_binds[a] is Array:
					pad_binds[str(a)] = d.pad_binds[a].map(func(k): return [int(k[0]), float(k[1])] if k is Array else int(k))
			_setup_input()
		for r in d.get("revealed", []):
			revealed[r] = true
		for r in d.get("leaves", []):
			leaves[r] = true
		for r in d.get("shades", []):
			shades_heard[r] = true
		var st = d.get("stats", {})
		if st is Dictionary:
			for k in st:
				stats[k] = int(st[k])
	apply_volume()


## Window mode, resolution, frame pacing and anti-aliasing. In fullscreen the chosen resolution
## becomes the 3D render resolution, scaled to fill the screen.
func apply_display() -> void:
	var win := get_window()
	var res: Vector2i = RESOLUTIONS[resolution]
	match display_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var screen := DisplayServer.screen_get_usable_rect(win.current_screen)
			var size := Vector2i(mini(res.x, screen.size.x), mini(res.y, screen.size.y))
			win.size = size
			win.position = screen.position + (screen.size - size) / 2
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	var vp := get_viewport()
	var sc := 1.0
	if display_mode != 0:
		var screen_h := DisplayServer.screen_get_size(win.current_screen).y
		sc = clampf(float(res.y) / float(maxi(screen_h, 1)), 0.25, 1.0)
	sc = clampf(sc * float(RENDER_SCALES[render_scale]), 0.25, 1.0)
	vp.scaling_3d_scale = sc
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if sc < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	win.content_scale_factor = float(UI_SCALES[ui_scale])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_CAPS[fps_cap]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][aa]


func toggle_fullscreen() -> void:
	display_mode = 0 if display_mode != 0 else 1
	apply_display()
	save()


## With a controller in hand and a menu showing, the first button takes the focus so the pad can move
## through the menu.
## Whether an action is held: by the key itself, or, when it is set to toggle, since it was last pressed.
func held(action: String) -> bool:
	if toggles.get(action, false):
		return bool(_toggled.get(action, false))
	return Input.is_action_pressed(action)


## A toggled action stops (the run ends when the walking does, aim when the gun is put away).
func untoggle(action: String) -> void:
	_toggled[action] = false


func _input(e: InputEvent) -> void:
	for a in toggles:
		if toggles[a] and e.is_action_pressed(a) and not e.is_echo():
			_toggled[a] = not bool(_toggled.get(a, false))
	if (e is InputEventJoypadButton and e.pressed) or (e is InputEventJoypadMotion and absf(e.axis_value) > 0.6):
		using_pad = true
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and get_viewport().gui_get_focus_owner() == null:
			var b := _first_button(get_tree().root)
			if b:
				b.grab_focus()
	elif e is InputEventMouseMotion and e.relative.length() > 2.0:
		using_pad = false


var using_pad := false


func _first_button(n: Node) -> Control:
	if n is CanvasItem and not n.visible:
		return null
	if n is BaseButton and n.focus_mode != Control.FOCUS_NONE and not n.disabled and n.is_visible_in_tree():
		return n
	for c in n.get_children():
		var f := _first_button(c)
		if f:
			return f
	return null


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_F11 or (e.keycode == KEY_ENTER and e.alt_pressed) or (e.keycode == KEY_F and e.meta_pressed and e.ctrl_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	if AudioServer.get_bus_effect_count(0) == 0:
		# A last guard on everything heard together
		var guard := AudioEffectHardLimiter.new()
		guard.ceiling_db = -0.3
		AudioServer.add_bus_effect(0, guard)
	for k in BUSES:
		var i := AudioServer.get_bus_index(k)
		if i < 0:
			AudioServer.add_bus()
			i = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, k)
			AudioServer.set_bus_send(i, "Master")
			if k == "Guns":
				# Shots are played hot so they stand above the world; this catches their crack before it clips
				var lim := AudioEffectHardLimiter.new()
				lim.ceiling_db = -0.5
				lim.release = 0.06
				AudioServer.add_bus_effect(i, lim)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(bus_vol[k]), 0.001)))


## Which line of the mixer a sound plays on, by its name.
static func bus_of(sound: String) -> String:
	for g in ["shotgun", "mg", "rifle", "sniper", "pistol", "revolver", "minigun", "rocket", "supp", "pump", "shell", "mag_", "brrt", "jet", "flame", "rotor", "boom", "hit_", "swing", "chop", "parry", "draw", "tick"]:
		if sound.begins_with(g):
			return "Guns"
	for c in ["growl", "shriek", "roar", "great_roar", "troll", "bite", "spit", "hiss", "screech", "chitter", "skitter", "critter", "spider", "unseen", "saucer", "fall", "heavy_step", "dissolve", "whispers"]:
		if sound.begins_with(c):
			return "Creatures"
	for u in ["deny", "carve", "bell", "choir", "relic", "beam", "ui_", "page", "cloth", "jingle"]:
		if sound.begins_with(u):
			return "Interface"
	return "World"
