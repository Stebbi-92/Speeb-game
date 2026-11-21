extends Node
## Error reports the player chooses to send. When the last session hit an error, or closed without
## quitting, the title asks once whether to send a short report to the lobby server (game.speeb.org).
## A report holds only the error lines and the game version (and the system's name, such as Windows).
## Nothing is sent unless the player says yes, or chose "Always send" in the options.

const RUNNING := "user://running"   ## written at start, removed on a clean quit: still there means a crash
const LOG_DIR := "user://logs"
const MAX_BLOCKS := 6
const MAX_TEXT := 3500
## Lines that say nothing useful about a fault (seen without a screen, or from the engine itself on quit)
const NOISE := ["Parameter \"m\" is null", "ObjectDB instances leaked", "resources still in use at exit",
	"Pages in use exist at exit", "RID allocations of type"]

var pending := {}   ## {kind, text} found from the last session, or empty
var _http: HTTPRequest


func _ready() -> void:
	if OS.get_cmdline_user_args().size() > 0 or DisplayServer.get_name() == "headless":
		return   # tests, servers and tools leave no flag and send nothing
	var crashed := FileAccess.file_exists(RUNNING)
	pending = gather(_last_log(), crashed)
	var f := FileAccess.open(RUNNING, FileAccess.WRITE)
	if f:
		f.store_string(version())


func _exit_tree() -> void:
	if FileAccess.file_exists(RUNNING):
		DirAccess.remove_absolute(RUNNING)


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## The log of the session before this one: the newest rotated godot*.log (godot.log is this session's).
static func _last_log() -> String:
	var d := DirAccess.open(LOG_DIR)
	if d == null:
		return ""
	var best := ""
	for n in d.get_files():
		if n.begins_with("godot") and n.ends_with(".log") and n != "godot.log" and n > best:
			best = n
	return LOG_DIR.path_join(best) if best != "" else ""


## The errors in a log, each with its "at:" line, without repeats. A crash also takes the backtrace.
static func gather(log_path: String, crashed: bool) -> Dictionary:
	var lines := PackedStringArray()
	if log_path != "" and FileAccess.file_exists(log_path):
		lines = FileAccess.get_file_as_string(log_path).split("\n")
	var blocks: Array[String] = []
	var trace: Array[String] = []
	var i := 0
	while i < lines.size():
		var l := lines[i].strip_edges(false, true)
		if l.begins_with("SCRIPT ERROR:") or l.begins_with("ERROR:"):
			var b := l
			if i + 1 < lines.size() and lines[i + 1].strip_edges().begins_with("at:"):
				b += "\n" + lines[i + 1].strip_edges(false, true)
				i += 1
			var noisy := false
			for n in NOISE:
				if n in b:
					noisy = true
			if not noisy and not b in blocks and blocks.size() < MAX_BLOCKS:
				blocks.append(b)
		elif crashed and ("Program crashed" in l or "CrashHandlerException" in l or l.begins_with("[") and "]" in l.substr(0, 6) or "BACKTRACE" in l):
			if trace.size() < 30:
				trace.append(l)
		i += 1
	if blocks.is_empty() and not crashed:
		return {}
	var text := "\n\n".join(blocks)
	if crashed:
		text = ("The game closed without quitting.\n" + "\n".join(trace) + ("\n\n" + text if text != "" else "")).strip_edges()
	return {"kind": "crash" if crashed else "error", "text": scrub(text).substr(0, MAX_TEXT)}


## Takes the player's name out of any file path in a report: C:\Users\Ann\ or /home/ann/ or
## /Users/ann/ become <user>, and so does the account name wherever else it shows.
static func scrub(text: String) -> String:
	var re := RegEx.create_from_string("(?i)([A-Z]:[\\\\/]Users[\\\\/]|/home/|/Users/)[^\\\\/\\s\"']+")
	text = re.sub(text, "$1<user>", true)
	for k in ["USERNAME", "USER"]:
		var u := OS.get_environment(k)
		if u.length() >= 3:
			text = text.replace(u, "<user>")
	return text


## Called by the title: asks once, or sends at once, as the player chose.
func offer(hud: Node) -> void:
	if pending.is_empty() or Game.reports == 2:
		pending = {}
		return
	if Game.reports == 1:
		send()
		return
	var what := "closed suddenly" if pending.kind == "crash" else "ran into an error"
	var found := pending
	pending = {}   # asked once: coming back to the title later does not ask again
	hud.ask("Brelm %s last time.\nSend a short report? It holds only\nthe error and the game version." % what, "Send", func(): pending = found; send(), "Not now")


func send() -> void:
	if pending.is_empty():
		return
	var body := JSON.stringify({"version": version(), "platform": OS.get_name(), "kind": pending.kind, "text": pending.text})
	pending = {}
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(func(_r, _c, _h, _b): _http.queue_free())
	_http.request(Net.lobby_url() + "/report", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
