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
	if not FileAccess.file_exists(PACK) or not FileAccess.file_exists(VERSION_FILE):
		return
	staged = FileAccess.get_file_as_string(VERSION_FILE).strip_edges()
	if compare(staged, current) <= 0:
		# This build is as new as the staged pack (a fresh install, or we are already running on it)
		if "--main-pack" not in OS.get_cmdline_args():
			_clear()
		staged = ""
		return
	if (OS.has_feature("editor") and "updtest" not in OS.get_cmdline_user_args()) or "--main-pack" in OS.get_cmdline_args() or "noupdate" in OS.get_cmdline_user_args():
		return
	_relaunch()


func _ready() -> void:
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
			assets[str(a.get("name", ""))] = {"url": str(a.get("browser_download_url", "")), "size": int(a.get("size", 0))}
		data = {"version": str(rel.get("tag_name", "")).trim_prefix("v"), "name": str(rel.get("name", "")),
			"notes": str(rel.get("body", "")), "page": str(rel.get("html_url", "")), "assets": assets, "news": ""}
	if not (data is Dictionary):
		return
	var assets: Dictionary = data.get("assets", {}) if data.get("assets") is Dictionary else {}
	var pack: Dictionary = assets.get(pack_name(), {}) if assets.get(pack_name()) is Dictionary else {}
	latest = {"version": str(data.get("version", "")), "name": str(data.get("name", "")),
		"notes": str(data.get("notes", "")), "page": str(data.get("page", "")), "news": str(data.get("news", "")),
		"pack_url": str(pack.get("url", "")), "pack_size": int(pack.get("size", 0))}
	available = latest.version != "" and compare(latest.version, current) > 0
	can_patch = available and latest.pack_url != ""
	if available and staged == latest.version:
		can_patch = false    # already fetched; it waits for a restart
	checked.emit()


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
	_dl.download_file = DIR + "Brelm.pck.part"
	if _dl.request(latest.pack_url, ["User-Agent: Brelm-updater"]) != OK:
		busy = false
		finished.emit(false, "The road to the new version could not be opened.")


func cancel() -> void:
	if busy:
		_dl.cancel_request()
		busy = false
		DirAccess.remove_absolute(DIR + "Brelm.pck.part")


func _on_download(result: int, code: int, _h: PackedStringArray, _body: PackedByteArray) -> void:
	busy = false
	var part := DIR + "Brelm.pck.part"
	var size := 0
	if FileAccess.file_exists(part):
		var f := FileAccess.open(part, FileAccess.READ)
		size = f.get_length()
		f.close()
	var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200 and size > 0
	if ok and int(latest.pack_size) > 0 and size != int(latest.pack_size):
		ok = false
	if not ok or not _looks_like_pack(part):
		DirAccess.remove_absolute(part)
		finished.emit(false, "The download failed. Try again later.")
		return
	DirAccess.remove_absolute(PACK)
	DirAccess.rename_absolute(part, PACK)
	var vf := FileAccess.open(VERSION_FILE, FileAccess.WRITE)
	vf.store_string(latest.version)
	vf.close()
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
	_relaunch()


func _relaunch() -> void:
	var args := PackedStringArray(["--main-pack", ProjectSettings.globalize_path(PACK)])
	if DisplayServer.get_name() == "headless":    # a dedicated server keeps running without a window
		args.append("--headless")
	var old := OS.get_cmdline_args()
	var i := 0
	while i < old.size():
		if old[i] == "--main-pack":
			i += 2
			continue
		args.append(old[i])
		i += 1
	var user := OS.get_cmdline_user_args()
	if user.size() > 0:
		args.append("--")
		args.append_array(user)
	if OS.create_process(OS.get_executable_path(), args) > 0:
		get_tree().quit.call_deferred()
	else:
		push_warning("Updater: could not restart onto the new version; running the installed one.")


func _clear() -> void:
	DirAccess.remove_absolute(PACK)
	DirAccess.remove_absolute(VERSION_FILE)


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
