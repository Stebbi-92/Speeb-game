extends Node
## Keeps Brelm current without reinstalling.
##
## On start it asks the lobby worker (or GitHub directly, if the worker is silent) for the newest release.
## A release carries the game's data as one pack per platform, named for the engine it was built with:
##   Brelm-Windows-godot4.3.pck, Brelm-macOS-godot4.3.pck
## The player chooses to fetch it; it is kept in user://update/ and the game restarts onto it with
## --main-pack. The installed files are never touched, so a failed download can never break the game.
## If the engine changed between releases there is no pack for this build, and the player is pointed
## to the release page for the full download instead.

signal checked
signal progress(done: int, total: int)
signal finished(ok: bool, message: String)

const REPO := "Stebbi-92/Speeb-game"
const DIR := "user://update/"
const PACK := DIR + "Brelm.pck"
const VERSION_FILE := DIR + "version.txt"
## A pack fetched while the game may be running on Brelm.pck. Godot reads a pack afresh for each file,
## so Brelm.pck must never change under a running game: the new one waits here and is moved into place
## only in the moment before this process restarts and ends.
const NEXT := DIR + "Brelm.next.pck"
const NEXT_VERSION := DIR + "next.txt"
## A pack is tried once: STARTED names the version a restart went onto, BOOTED the one that then reached
## the title screen. A start that finds STARTED without its BOOTED skips that pack, so a broken update
## can never lock the game in a loop of crashing starts.
const STARTED := DIR + "started.txt"
const BOOTED := DIR + "booted.txt"
const FAILED := DIR + "failed.txt"

var failed := ""          ## a version whose pack would not start here; not offered as a patch again

var current := ""
var latest := {}          ## {version, name, notes, page, news, pack_url, pack_size}
var available := false    ## a newer release exists
var can_patch := false    ## ...and it has a pack this build can run
var staged := ""          ## version waiting in user://update, if any
var busy := false

var _http: HTTPRequest
var _dl: HTTPRequest
var _tried_github := false


func _enter_tree() -> void:
	current = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	failed = _read(FAILED) if FileAccess.file_exists(FAILED) else ""
	var tried := _read(STARTED) if FileAccess.file_exists(STARTED) else ""
	var booted := _read(BOOTED) if FileAccess.file_exists(BOOTED) else ""
	if tried != "" and tried != current and tried != booted:
		# The last restart went onto a pack that never reached the title: leave it, run the installed game
		failed = tried
		_write(FAILED, tried)
		DirAccess.remove_absolute(STARTED)
		_clear_next()
		_clear()
		return
	var held := "noupdate" in OS.get_cmdline_user_args() or (OS.has_feature("editor") and "updtest" not in OS.get_cmdline_user_args())
	var nxt := _read(NEXT_VERSION) if FileAccess.file_exists(NEXT) else ""
	var live := _read(VERSION_FILE) if FileAccess.file_exists(PACK) else ""
	if nxt != "" and compare(nxt, current) > 0 and (live == "" or compare(nxt, live) > 0):
		# Fetched last time but never restarted onto: put it in place now, before anything else loads
		staged = nxt
		if not held:
			_swap_and_go()
		return
	if nxt != "":
		_clear_next()
	if live == "":
		return
	staged = live
	var c := compare(staged, current)
	if c <= 0:
		# Never clear a pack of this very version: we may be running on it. Godot keeps --main-pack out of
		# get_cmdline_args(), so that cannot tell us, and deleting the pack under a running game leaves
		# a blank white window. Only an older pack (a newer full install) is cleared.
		if c < 0:
			_clear()
		staged = ""
		return
	if held:
		return
	_relaunch(false)


func _ready() -> void:
	# Half a minute up (a dedicated server shows no title) also counts as having started
	get_tree().create_timer(30.0).timeout.connect(mark_booted)
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	_http.request_completed.connect(_on_latest)
	add_child(_http)
	_dl = HTTPRequest.new()
	_dl.request_completed.connect(_on_download)
	add_child(_dl)
	if DisplayServer.get_name() != "headless" and not OS.has_feature("editor"):
		check.call_deferred()


func _process(_delta: float) -> void:
	if busy and _dl.get_body_size() > 0:
		progress.emit(_dl.get_downloaded_bytes(), _dl.get_body_size())


# ------------------------------------------------------------------ asking

func check() -> void:
	_tried_github = false
	var u: String = Net.lobby_url() if Net.has_method("lobby_url") else ""
	if u == "" or _http.request(u + "/latest") != OK:
		_ask_github()


func _ask_github() -> void:
	_tried_github = true
	_http.cancel_request()
	_http.request("https://api.github.com/repos/%s/releases?per_page=10" % REPO,
		["User-Agent: Brelm-updater", "Accept: application/vnd.github+json"])


func _on_latest(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var data = null
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		if not _tried_github:
			_ask_github()
		return
	if data is Array:    # straight from GitHub: shape it like the worker's answer
		var rel := {}
		for r in data:
			if r is Dictionary and not r.get("draft", false):
				rel = r
				break
		var assets := {}
		for a in rel.get("assets", []):
			assets[str(a.get("name", ""))] = {"url": str(a.get("browser_download_url", "")), "size": int(a.get("size", 0)), "digest": str(a.get("digest", ""))}
		data = {"version": str(rel.get("tag_name", "")).trim_prefix("v"), "name": str(rel.get("name", "")),
			"notes": str(rel.get("body", "")), "page": str(rel.get("html_url", "")), "assets": assets, "news": ""}
	if not (data is Dictionary):
		return
	var assets: Dictionary = data.get("assets", {}) if data.get("assets") is Dictionary else {}
	var pack: Dictionary = assets.get(pack_name(), {}) if assets.get(pack_name()) is Dictionary else {}
	latest = {"version": str(data.get("version", "")), "name": str(data.get("name", "")),
		"notes": str(data.get("notes", "")), "page": str(data.get("page", "")), "news": str(data.get("news", "")),
		"pack_url": str(pack.get("url", "")), "pack_size": int(pack.get("size", 0)), "pack_sha": _sha_of(pack.get("digest", ""))}
	# A pack holds scripts: only one from this game's own releases is ever taken
	if not str(latest.pack_url).begins_with(PACK_HOME):
		latest.pack_url = ""
	available = latest.version != "" and compare(latest.version, current) > 0
	can_patch = available and latest.pack_url != "" and latest.version != failed   # a pack that would not start here is not offered again
	if available and staged == latest.version:
		can_patch = false    # already fetched; it waits for a restart
	checked.emit()


const PACK_HOME := "https://github.com/" + REPO + "/releases/download/"


## The SHA-256 GitHub gives a release asset ("sha256:<hex>"), as plain hex; empty if none.
static func _sha_of(digest) -> String:
	var d := str(digest) if digest != null else ""
	return d.trim_prefix("sha256:").to_lower() if d.begins_with("sha256:") else ""


## The SHA-256 of a file, read in pieces.
static func file_sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(1 << 20))
	f.close()
	return ctx.finish().hex_encode()


## The release asset this build can run.
static func pack_name() -> String:
	var os := "macOS" if OS.get_name() == "macOS" else "Windows" if OS.get_name() == "Windows" else OS.get_name()
	var v := Engine.get_version_info()
	return "Brelm-%s-godot%d.%d.pck" % [os, v.major, v.minor]


# ------------------------------------------------------------------ fetching

func download() -> void:
	if busy or not can_patch:
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	busy = true
	_dl.download_file = NEXT + ".part"
	if _dl.request(latest.pack_url, ["User-Agent: Brelm-updater"]) != OK:
		busy = false
		finished.emit(false, "The road to the new version could not be opened.")


func cancel() -> void:
	if busy:
		_dl.cancel_request()
		busy = false
		DirAccess.remove_absolute(NEXT + ".part")


func _on_download(result: int, code: int, _h: PackedStringArray, _body: PackedByteArray) -> void:
	busy = false
	var part := NEXT + ".part"
	var size := 0
	if FileAccess.file_exists(part):
		var f := FileAccess.open(part, FileAccess.READ)
		size = f.get_length()
		f.close()
	var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200 and size > 0
	if ok and int(latest.pack_size) > 0 and size != int(latest.pack_size):
		ok = false
	if ok and str(latest.get("pack_sha", "")) != "" and file_sha256(part) != str(latest.pack_sha):
		ok = false   # not the pack that was published
	if not ok or not _looks_like_pack(part):
		DirAccess.remove_absolute(part)
		finished.emit(false, "The download failed. Try again later.")
		return
	DirAccess.remove_absolute(NEXT)
	DirAccess.rename_absolute(part, NEXT)
	_write(NEXT_VERSION, latest.version)
	staged = latest.version
	can_patch = false
	finished.emit(true, "Version %s is ready. Restart to walk it." % latest.version)


func _looks_like_pack(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var magic := f.get_32()
	f.close()
	return magic == 0x43504447    # "GDPC"


## Saves, then starts the game again on the staged pack.
func restart() -> void:
	if staged == "":
		return
	if Game.has_method("save"):
		Game.save()
	if FileAccess.file_exists(NEXT):
		_swap_and_go()
	else:
		_relaunch(false)


## Moves the fetched pack into place and restarts onto it. From the swap on, this process must load
## nothing more from Brelm.pck, so it ends at once instead of quitting gracefully.
func _swap_and_go() -> void:
	var v := _read(NEXT_VERSION)
	DirAccess.remove_absolute(PACK)
	if DirAccess.rename_absolute(NEXT, PACK) != OK:
		push_warning("Updater: could not put the new version in place.")
		return
	_write(VERSION_FILE, v)
	DirAccess.remove_absolute(NEXT_VERSION)
	_relaunch(true)


func _relaunch(hard: bool) -> void:
	var to := _read(VERSION_FILE) if FileAccess.file_exists(VERSION_FILE) else ""
	if to != "" and to != _read_or(BOOTED):
		_write(STARTED, to)   # cleared, or found unanswered, on the next start
	var args := PackedStringArray(["--main-pack", ProjectSettings.globalize_path(PACK)])
	if DisplayServer.get_name() == "headless":    # a dedicated server keeps running without a window
		args.append("--headless")
	# Godot hides its own options from get_cmdline_args(), so carry the renderer over by hand
	# (compatibility mode starts on OpenGL, and must restart on it too)
	if DisplayServer.get_name() != "headless" and RenderingServer.get_rendering_device() == null:
		args.append_array(["--rendering-driver", "opengl3"])
	args.append_array(OS.get_cmdline_args())
	var user := OS.get_cmdline_user_args()
	if user.size() > 0:
		args.append("--")
		args.append_array(user)
	# This is a planned stop, not a crash: take down the "still running" flag (scripts/report.gd) first,
	# or the new start finds it and offers to send a crash report for the update
	if FileAccess.file_exists("user://running"):
		DirAccess.remove_absolute("user://running")
	if OS.create_process(OS.get_executable_path(), args) > 0:
		if hard:
			OS.kill(OS.get_process_id())
		get_tree().quit.call_deferred()
	else:
		var f := FileAccess.open("user://running", FileAccess.WRITE)   # still running after all
		if f:
			f.store_string(str(ProjectSettings.get_setting("application/config/version", "")))
		push_warning("Updater: could not restart onto the new version; running the installed one.")


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path).strip_edges()


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()


## The game came up on this version: the pack it runs on (if any) is good.
func mark_booted() -> void:
	if FileAccess.file_exists(STARTED) and _read(STARTED) == current:
		_write(BOOTED, current)
		DirAccess.remove_absolute(STARTED)
	if failed != "" and compare(current, failed) >= 0:
		failed = ""
		DirAccess.remove_absolute(FAILED)


func _read_or(path: String) -> String:
	return _read(path) if FileAccess.file_exists(path) else ""


func _clear() -> void:
	DirAccess.remove_absolute(PACK)
	DirAccess.remove_absolute(VERSION_FILE)


func _clear_next() -> void:
	DirAccess.remove_absolute(NEXT)
	DirAccess.remove_absolute(NEXT_VERSION)


## Compares versions like 0.3.0-alpha: numbers first, then a release outranks its pre-releases.
static func compare(a: String, b: String) -> int:
	var pa := a.split("-", true, 1)
	var pb := b.split("-", true, 1)
	var na := pa[0].split(".")
	var nb := pb[0].split(".")
	for i in maxi(na.size(), nb.size()):
		var x := int(na[i]) if i < na.size() else 0
		var y := int(nb[i]) if i < nb.size() else 0
		if x != y:
			return 1 if x > y else -1
	var ta := pa[1] if pa.size() > 1 else ""
	var tb := pb[1] if pb.size() > 1 else ""
	if ta == tb:
		return 0
	if ta == "":
		return 1
	if tb == "":
		return -1
	return 1 if ta > tb else -1
