extends Node
## Looks after a dedicated server: its settings file, the orders its window and console give,
## and updates that come in by themselves. The window (scripts/server_panel.gd) only shows what this holds.
##
## Orders go to Net's server calls. A build whose Net lacks one says "not available in this build".

signal changed   ## something the window shows has changed
signal logged(line: String)   ## a log line, with its time

const LOG_KEEP := 3000

const DEFAULT_CONFIG := "user://server.cfg"
const RECHECK_S := 6 * 3600.0   ## how often to look for updates when updating by itself
const SETTINGS := ["name", "port", "password", "max_players", "difficulty", "listed", "lobby", "autosave_min", "pause_when_empty"]
const UPDATE_SETTINGS := ["check_on_start", "auto_update"]
const COMMANDS := "status, list, save, say <text>, kick <name|id>, ban <name|id>, pause, resume, auto, worlds, load <world>, new <world> [seed], update, restart, quit, help"

var config_path := DEFAULT_CONFIG
var conf := {}            ## the settings in use: SETTINGS and UPDATE_SETTINGS
var api: Object           ## Net, or a stand-in for tests
var pause_mode := 0       ## 0 pause when empty, 1 always run, 2 paused
var started_ms := 0
var update_note := ""     ## what the last look for updates found
var restart_waiting := false   ## an update is fetched, and the server restarts onto it once no one is here

var log_lines: Array = []   ## the log since the server started, newest last

var _stdin: Thread
var _stdin_lines: Array[String] = []
var _stdin_lock := Mutex.new()
var _tick := 0.0
var _recheck := RECHECK_S


## The settings a new server starts with.
static func defaults() -> Dictionary:
	return {"name": "A fellowship of Brelm", "port": 24600, "password": "", "max_players": 8, "difficulty": 1,
		"listed": false, "lobby": "", "autosave_min": 5, "pause_when_empty": true,
		"check_on_start": true, "auto_update": false}


## Reads a settings file over the defaults. A missing or broken file gives the defaults.
static func load_config(path: String) -> Dictionary:
	var d := defaults()
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return d
	for k in SETTINGS:
		d[k] = _as(d[k], cf.get_value("server", k, d[k]))
	for k in UPDATE_SETTINGS:
		d[k] = _as(d[k], cf.get_value("updates", k, d[k]))
	return d


## Writes the settings to the file, with a short note on each.
static func save_config(path: String, d: Dictionary) -> Error:
	var cf := ConfigFile.new()
	for k in SETTINGS:
		cf.set_value("server", k, d.get(k))
	for k in UPDATE_SETTINGS:
		cf.set_value("updates", k, d.get(k))
	if path.get_base_dir() != "":
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return cf.save(path)


## A value read from the file or the command line, made the same kind as its default.
static func _as(def, v):
	if def is bool:
		return v if v is bool else str(v).to_lower() in ["1", "true", "yes", "on"]
	if def is int:
		return int(v)
	return str(v)


## The settings for this start: the file (config=<path>, or user://server.cfg), then the command line over it.
static func from_args(args: PackedStringArray) -> Dictionary:
	var path := DEFAULT_CONFIG
	for a in args:
		if a.begins_with("config="):
			path = a.substr(7)
	var d := load_config(path)
	if not FileAccess.file_exists(path):
		save_config(path, d)   # made on the first start, so there is a file to change
	for a in args:
		var kv := a.split("=", true, 1)
		var k := kv[0]
		var v := kv[1] if kv.size() > 1 else ""
		match k:
			"public":
				d.listed = v == "" or _as(true, v)
			"autosave":
				d.autosave_min = int(v)
			"max", "max_players":
				d.max_players = int(v)
			_:
				if v != "" and k in d and k != "config":
					d[k] = _as(d[k], v)
	d.port = clampi(int(d.port), 1, 65535)
	d.difficulty = clampi(int(d.difficulty), 0, 2)
	d.max_players = clampi(int(d.max_players), 1, 8)
	d.autosave_min = clampi(int(d.autosave_min), 0, 240)
	d["_path"] = path
	return d


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	started_ms = Time.get_ticks_msec()
	if api == null:
		api = Net
	for a in OS.get_cmdline_user_args():
		if a.begins_with("netstub="):   # testing aid: a stand-in for Net's server calls
			api = load(a.substr(8)).new()
			add_child(api)
	if api.has_signal("server_state_changed"):
		api.connect("server_state_changed", func(): changed.emit())
	Net.roster_changed.connect(func(): changed.emit())
	Net.status_changed.connect(_on_log)
	_on_log("Hosting \"%s\" on port %d." % [Net.server_name, Net.port])
	Updater.checked.connect(_on_checked)
	Updater.finished.connect(_on_fetched)
	if Updater.has_signal("check_failed"):
		Updater.check_failed.connect(func(m: String): update_note = m; changed.emit())
	if conf.get("check_on_start", true) or conf.get("auto_update", false):
		get_tree().create_timer(5.0).timeout.connect(check_updates)


## Puts the settings in place once the server has opened: those Net.host does not take.
func apply_start() -> void:
	for k in ["max_players", "autosave_min", "pause_when_empty"]:
		_set_option(k, conf[k], true)


# ------------------------------------------------------------------ what the window and console ask

func has(method: String) -> bool:
	return api != null and api.has_method(method)


func _on_log(text: String) -> void:
	var line := "[%s] %s" % [Time.get_time_string_from_system(), text]
	log_lines.append(line)
	if log_lines.size() > LOG_KEEP:
		log_lines = log_lines.slice(log_lines.size() - LOG_KEEP)
	logged.emit(line)


## Tells the log, the window and the console.
func note(text: String) -> void:
	Net._log(text)


func _missing(what: String) -> bool:
	note("%s is not available in this build." % what)
	return false


## The server as it stands. Net's own answer, filled out from what this build knows if it has none.
func status() -> Dictionary:
	var s := {"name": Net.server_name, "port": Net.port, "players": [], "max_players": conf.get("max_players", 8),
		"paused": false, "world": "", "level": Net.in_level, "uptime_s": (Time.get_ticks_msec() - started_ms) / 1000,
		"last_save_unix": 0, "listed": Net.listed_public, "version": str(ProjectSettings.get_setting("application/config/version", "")),
		"difficulty": Game.difficulty}
	for id in Net.players:
		s.players.append({"id": id, "name": str(Net.players[id].get("name", "")), "ping": _ping(id)})
	if has("server_status"):
		var got = api.call("server_status")
		if got is Dictionary:
			s.merge(got, true)
	s["known"] = has("server_status")
	return s


func _ping(id: int) -> int:
	if Net.peer == null:
		return -1
	var p = Net.peer.get_peer(id)
	return int(p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if p else -1


## Why the world is running or still, in a few words.
func run_state(s: Dictionary) -> String:
	if not s.paused:
		return "Running"
	if pause_mode == 2:
		return "Paused by you"
	return "Paused, no one here" if s.players.is_empty() else "Paused"


func save_now() -> bool:
	if not has("server_save_now"):
		return _missing("Saving the world")
	var ok: bool = api.call("server_save_now")
	note("The world is saved." if ok else "The world could not be saved.")
	changed.emit()
	return ok


func kick(id: int, reason := "") -> bool:
	if has("server_kick"):
		api.call("server_kick", id, reason)
	elif Net.players.has(id):
		Net.kick(id)
	else:
		return false
	changed.emit()
	return true


func ban(id: int) -> bool:
	if not has("server_ban"):
		return _missing("Banning")
	api.call("server_ban", id)
	changed.emit()
	return true


func say(text: String) -> bool:
	text = text.strip_edges()
	if text == "":
		return false
	if not has("server_say"):
		return _missing("Sending a message")
	api.call("server_say", text)
	return true


## 0 pause when empty, 1 always run, 2 paused.
func set_pause_mode(mode: int) -> bool:
	if not has("server_set_paused_override"):
		return _missing("Pausing")
	pause_mode = clampi(mode, 0, 2)
	api.call("server_set_paused_override", pause_mode)
	note(["The world pauses when no one is here.", "The world always runs.", "The world is paused."][pause_mode])
	changed.emit()
	return true


func list_worlds() -> Array:
	if not has("server_list_worlds"):
		return []
	var got = api.call("server_list_worlds")
	return got if got is Array else []


func load_world(wname: String) -> bool:
	if not has("server_load_world"):
		return _missing("Loading a world")
	api.call("server_load_world", wname)
	changed.emit()
	return true


func new_world(wname: String, world_seed := 0) -> bool:
	if not has("server_new_world"):
		return _missing("Making a world")
	api.call("server_new_world", wname.strip_edges(), world_seed)
	changed.emit()
	return true


func restart_world() -> bool:
	if not has("server_restart_world"):
		return _missing("Restarting the world")
	api.call("server_restart_world")
	changed.emit()
	return true


## Takes new settings: puts what it can in place now, and writes them all to the settings file.
## Says which need a restart.
func apply_settings(d: Dictionary) -> void:
	var old := conf.duplicate()
	for k in d:
		if k in conf:
			conf[k] = d[k]
	for k in ["name", "listed", "password", "max_players", "difficulty", "autosave_min", "pause_when_empty"]:
		if conf[k] != old.get(k):
			_set_option(k, conf[k])
	if save_config(config_path, conf) == OK:
		note("Settings saved to %s." % ProjectSettings.globalize_path(config_path))
	else:
		note("The settings could not be saved to %s." % config_path)
	if conf.port != old.get("port") or conf.lobby != old.get("lobby"):
		note("The new port or list address is used after a restart.")
	changed.emit()


## Saves the update choices alone.
func set_update_option(k: String, v: bool) -> void:
	conf[k] = v
	save_config(config_path, conf)
	changed.emit()


func _set_option(k: String, v, quiet := false) -> void:
	if has("server_set_option"):
		api.call("server_set_option", k, v)
		return
	# Older builds: what Net and Game hold themselves
	match k:
		"name":
			Net.server_name = str(v)
		"listed":
			Net.listed_public = bool(v)
		"password":
			Net.password = str(v).strip_edges()
		"difficulty":
			Game.difficulty = int(v)
		_:
			if not quiet:
				_missing("Setting %s" % k.replace("_", " "))


## Saves the world, then ends the server.
func stop() -> void:
	if has("server_save_now"):
		api.call("server_save_now")
	note("The server stops.")
	_join_console()
	Net.leave("The server has stopped.")
	get_tree().quit()


## Saves the world, then starts the server again, on a fetched update if one waits.
func restart_server() -> void:
	if has("server_save_now"):
		api.call("server_save_now")
	note("The server restarts%s." % ((" onto version %s" % Updater.staged) if Updater.staged != "" else ""))
	if has("server_say"):
		api.call("server_say", "The server restarts. Join again in a minute.")
	await get_tree().create_timer(0.5).timeout
	Net.leave("The server is restarting. Join again in a minute.")
	if Updater.has_method("relaunch") and Updater.relaunch():
		return
	# Could not start again: open once more as we were
	note("The server could not restart itself. It runs on.")
	Net.host(conf.port, conf.name, conf.listed, true, false, conf.password)
	apply_start()


# ------------------------------------------------------------------ updates

func check_updates() -> void:
	update_note = "Looking for a new version..."
	changed.emit()
	Updater.check()


func _on_checked() -> void:
	if Updater.staged != "":
		update_note = "Version %s is fetched. Restart the server to finish." % Updater.staged
	elif Updater.can_patch:
		update_note = "Version %s is out." % Updater.latest.get("version", "")
		if conf.get("auto_update", false):
			note("Version %s is out. Fetching it." % Updater.latest.get("version", ""))
			Updater.download()
	elif Updater.available:
		update_note = "Version %s is out, but must be downloaded whole." % Updater.latest.get("version", "")
	else:
		update_note = "This is the newest version."
	if Updater.available:
		note(update_note)
	changed.emit()


func _on_fetched(ok: bool, message: String) -> void:
	update_note = "Version %s is fetched. Restart the server to finish." % Updater.staged if ok else message
	note(update_note)
	if ok and conf.get("auto_update", false):
		restart_waiting = true
	changed.emit()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 5.0
		if restart_waiting and Net.players.is_empty() and not Updater.busy:
			restart_waiting = false
			restart_server()
	if conf.get("auto_update", false):
		_recheck -= delta
		if _recheck <= 0.0:
			_recheck = RECHECK_S
			if Updater.staged == "" and not Updater.busy:
				check_updates()
	_drain_console()


# ------------------------------------------------------------------ the console

## Reads orders typed into the terminal a server without a window runs in.
## Reading waits for a line, so it runs on a thread of its own.
func start_console() -> void:
	_stdin = Thread.new()
	_stdin.start(_read_stdin)
	print("Type help for the server's commands.")


func _read_stdin() -> void:
	while true:
		var s := OS.read_string_from_stdin()
		if s == "":
			return    # no terminal, or it closed
		s = s.strip_edges()
		_stdin_lock.lock()
		_stdin_lines.append(s)
		_stdin_lock.unlock()
		if s == "quit" or s == "stop":
			return


func _drain_console() -> void:
	if _stdin == null:
		return
	_stdin_lock.lock()
	var lines := _stdin_lines.duplicate()
	_stdin_lines.clear()
	_stdin_lock.unlock()
	for l in lines:
		if l != "":
			run_command(l)


func _join_console() -> void:
	if _stdin and _stdin.is_started() and not _stdin.is_alive():
		_stdin.wait_to_finish()


func _exit_tree() -> void:
	_join_console()


## The player a console order names, by id or name; 0 if none.
func find_player(who: String) -> int:
	who = who.strip_edges()
	if who.is_valid_int() and Net.players.has(int(who)):
		return int(who)
	for p in status().players:
		if str(p.name).to_lower() == who.to_lower():
			return int(p.id)
	return 0


## Carries out one console order and prints what came of it.
func run_command(line: String) -> void:
	var parts := line.strip_edges().split(" ", false, 1)
	if parts.is_empty():
		return
	var cmd := parts[0].to_lower()
	var rest := parts[1] if parts.size() > 1 else ""
	match cmd:
		"help", "?":
			print("Commands: " + COMMANDS)
		"status":
			var s := status()
			print("%s  version %s  port %d  players %d/%d  world %s  %s  up %s  saved %s  internet list %s" % [s.name, s.version,
				int(s.port), s.players.size(), int(s.max_players), s.world if str(s.world) != "" else "-", run_state(s).to_lower(),
				span(int(s.uptime_s)), saved_text(int(s.last_save_unix)), "yes" if s.listed else "no"])
			for ip in Net.local_addresses():
				print("  join at %s:%d" % [ip, int(s.port)])
		"list", "players":
			var ps: Array = status().players
			if ps.is_empty():
				print("No one is here.")
			for p in ps:
				print("  %-20s id %-12d ping %s" % [p.name, int(p.id), ping_text(int(p.get("ping", -1)))])
		"save":
			save_now()
		"say":
			say(rest)
		"kick", "ban":
			var id := find_player(rest)
			if id == 0:
				print("No one called %s is here." % rest)
			elif cmd == "kick":
				kick(id)
			else:
				ban(id)
		"pause":
			set_pause_mode(2)
		"resume", "run":
			set_pause_mode(1)
		"auto":
			set_pause_mode(0)
		"worlds":
			for w in list_worlds():
				print("  " + world_label(w))
		"load":
			load_world(rest)
		"new":
			var bits := rest.split(" ", false)
			if bits.is_empty():
				print("Give the new world a name.")
			else:
				new_world(bits[0], int(bits[1]) if bits.size() > 1 else 0)
		"update":
			check_updates()
		"restart":
			restart_server()
		"quit", "stop", "exit":
			stop()
		_:
			print("Unknown command. Commands: " + COMMANDS)


# ------------------------------------------------------------------ words for numbers

static func span(s: int) -> String:
	if s < 3600:
		return "%dm %02ds" % [s / 60, s % 60]
	if s < 86400:
		return "%dh %02dm" % [s / 3600, (s / 60) % 60]
	return "%dd %dh" % [s / 86400, (s / 3600) % 24]


static func saved_text(unix: int) -> String:
	if unix <= 0:
		return "not yet"
	var ago := int(Time.get_unix_time_from_system()) - unix
	var at := Time.get_time_string_from_unix_time(unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60).left(5)
	return "%s (%s ago)" % [at, span(maxi(ago, 0)).split(" ")[0]]


static func ping_text(ms: int) -> String:
	return "-" if ms < 0 else "%d ms" % ms


## A saved world as a line: its name, and what else the list tells of it.
static func world_label(w) -> String:
	if w is Dictionary:
		var out := str(w.get("name", "?"))
		var extra := []
		for k in w:
			if k != "name" and k != "current":
				var v = w[k]
				if str(k).ends_with("_unix") and int(v) > 0:
					v = Time.get_datetime_string_from_unix_time(int(v)).replace("T", " ").left(16)
				extra.append("%s %s" % [str(k).trim_suffix("_unix").replace("_", " "), v])
		return out + ("   " + ", ".join(extra) if not extra.is_empty() else "")
	return str(w)


static func world_name_of(w) -> String:
	return str(w.get("name", "")) if w is Dictionary else str(w)
