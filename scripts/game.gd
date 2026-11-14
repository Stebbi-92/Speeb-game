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
var volume := 0.8
var difficulty := 1
var judgments := {}
var relics := {}
var milk := 1
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
var head_bob := true
var invert_y := false
var voice_lines := true
var quality := 1
var gilded := false
var player_name := ""
var lobby_url := ""
var forms_style := 0      ## the lesser forms: 0 flesh (cat heads), 1 masks (their emojis)
var look := Figure.DEFAULT.duplicate()   ## how this pilgrim appears to others
var unlimited_ammo := false   ## a hosting choice: guns never spend their reserve
var pxp := 0                 ## profile experience, earned in every mode; unlocks arms
var plevel := 1
var loadout := ArmsDB.DEFAULT.duplicate(true)
var autosave_min := 2          ## minutes between autosaves in the waste
## The open waste: which world is walked, and whether we are walking it now.
var world_slot := "1"
var new_world_seed := 0
var wasteland := false
## Revelations: deeds the pilgrimage remembers.
const REVELATIONS := {
	"first_blood": ["The First Undoing", "Undo a lesser form."],
	"hundred": ["A Hundred Undone", "Undo one hundred lesser forms. The gilded shotgun is yours."],
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
	if not OS.get_cmdline_user_args().size() > 0:
		apply_display.call_deferred()


func _json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("jump", [KEY_SPACE])
	_bind("interact", [KEY_E, KEY_F])
	_bind("run", [KEY_SHIFT])
	_bind("soft", [KEY_CTRL, KEY_C])
	_bind("codex", [KEY_TAB, KEY_B])
	_bind("pause", [KEY_ESCAPE, KEY_P])
	_bind("reload", [KEY_R])
	_bind("dash", [KEY_Q])
	_bind("riftwalk", [KEY_V])
	_bind("swap_gun", [KEY_X])
	_bind("melee", [KEY_Z])
	_bind("grenade", [KEY_G])
	_bind("gadget", [KEY_T])
	_bind("streak", [KEY_H])
	for i in RELICS.size():
		_bind("slot_%d" % (i + 1), [KEY_1 + i])
	InputMap.add_action("fire")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", click)
	InputMap.add_action("aim")
	var rclick := InputEventMouseButton.new()
	rclick.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("aim", rclick)


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
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
	return DIFF_SCALE[key][difficulty]


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
		if not revealed.has("hundred"):
			gilded = true
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
		return id in ["shotgun", "hands", "lantern"] or (id == "milk" and milk > 0)
	return id in ["shotgun", "hands"] or (id == "milk" and milk > 0) or relics.has(id)


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
	for p in [path, path + ".bak", path + ".tmp"]:
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
		var m: String = loadout.mounts[g]
		if not ArmsDB.GUNS.has(g) or not m in ArmsDB.GUNS[g].mounts or not unlocked(ArmsDB.ATTACHMENTS, m):
			loadout.mounts.erase(g)


func mount_of(gun: String) -> String:
	return str(loadout.get("mounts", {}).get(gun, ""))


func save() -> void:
	write_safe(SAVE_PATH, JSON.stringify({"reached": reached, "found": found.keys(), "sensitivity": sensitivity, "volume": volume, "difficulty": difficulty, "judgments": judgments, "relics": relics.keys(), "milk": milk,
			"display_mode": display_mode, "resolution": resolution, "vsync": vsync, "fps_cap": fps_cap, "aa": aa,
			"fov": fov, "head_bob": head_bob, "invert_y": invert_y, "voice_lines": voice_lines,
			"quality": quality, "gilded": gilded, "revealed": revealed.keys(), "stats": stats,
			"leaves": leaves.keys(), "shades": shades_heard.keys(),
			"player_name": player_name, "lobby_url": lobby_url, "autosave_min": autosave_min,
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
		sensitivity = float(d.get("sensitivity", sensitivity))
		volume = float(d.get("volume", volume))
		difficulty = int(d.get("difficulty", difficulty))
		judgments = d.get("judgments", {})
		for r in d.get("relics", []):
			relics[r] = true
		milk = int(d.get("milk", milk))
		display_mode = int(d.get("display_mode", display_mode))
		resolution = clampi(int(d.get("resolution", resolution)), 0, RESOLUTIONS.size() - 1)
		vsync = bool(d.get("vsync", vsync))
		fps_cap = clampi(int(d.get("fps_cap", fps_cap)), 0, FPS_CAPS.size() - 1)
		aa = clampi(int(d.get("aa", aa)), 0, 2)
		fov = float(d.get("fov", fov))
		head_bob = bool(d.get("head_bob", head_bob))
		invert_y = bool(d.get("invert_y", invert_y))
		voice_lines = bool(d.get("voice_lines", voice_lines))
		quality = clampi(int(d.get("quality", quality)), 0, 1)
		gilded = bool(d.get("gilded", gilded))
		player_name = str(d.get("player_name", player_name)).left(20)
		lobby_url = str(d.get("lobby_url", lobby_url))
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
	if display_mode == 0:
		vp.scaling_3d_scale = 1.0
	else:
		var screen_h := DisplayServer.screen_get_size(win.current_screen).y
		vp.scaling_3d_scale = clampf(float(res.y) / float(maxi(screen_h, 1)), 0.25, 1.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_CAPS[fps_cap]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][aa]


func toggle_fullscreen() -> void:
	display_mode = 0 if display_mode != 0 else 1
	apply_display()
	save()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_F11 or (e.keycode == KEY_ENTER and e.alt_pressed) or (e.keycode == KEY_F and e.meta_pressed and e.ctrl_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
