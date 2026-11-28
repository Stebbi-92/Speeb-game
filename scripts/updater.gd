extends Node
## Keeps Brelm current without reinstalling.
##
## On start it asks the lobby worker (or GitHub directly, if the worker is silent) for the newest release.
## A release carries the game's data as one pack per platform, named for the engine it was built with:
##   Brelm-Windows-godot4.3-rtc1.pck, Brelm-macOS-godot4.3-rtc1.pck
## ("rtc1": the builds that carry the WebRTC plugin, a library beside the game that a pack cannot bring;
## a build from before it finds no pack of its name, and is pointed to the full download.)
## The player chooses to fetch it; it is kept in user://update/ and the game restarts onto it with
## --main-pack. The installed files are never touched, so a failed download can never break the game.
## If the engine changed between releases there is no pack for this build, and the player is pointed
## to the release page for the full download instead.
##
## Split updates (tools/split_pack.py): a release also carries a small code pack and the game's data cut
## into parts (arms, foes, world models, textures, sound), each named for its sources, with a list of them
## (Brelm-<OS>-godot4.3-rtc1-parts.json). An update fetches the code pack and only the parts it has not
## got: kept in user://update/parts/, or still inside the installed game when that holds the same part.
## A code pack has res://.code_pack in it; starting from one, the parts it names are loaded at once, in
## _init, before any other script or asset is read.

signal checked
signal progress(done: int, total: int)
signal finished(ok: bool, message: String)
signal check_failed(message: String)   ## the look for a new version found no answer
signal files_checked(ok: bool, message: String)   ## "Check game files" is done (ok: nothing left to mend)

const REPO := "Stebbi-92/Speeb-game"
## What the installed build carries beside its pack (see the top). Raised when a plugin's library changes.
const LIBS := "rtc1"
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
## Split updates: the parts fetched, and which parts the installed game holds inside itself
const PARTS_DIR := DIR + "parts/"
const INSTALL := DIR + "install.json"
## The list of parts for the version waiting (kept so a clean-up never takes what it needs)
const NEXT_PARTS := DIR + "next-parts.json"
## ...and for the version running, with each part's hash, for "Check game files"
const LIVE_PARTS := DIR + "live-parts.json"
## A part fetched again by "Check game files" waits as <name>.fix and replaces <name> on the next start
const FIX := ".fix"
## A whole new game (when a pack cannot bring it): fetched as the release's zip, unpacked here, and put
## over the installed game by a little script once the game has closed
const INSTALL_ZIP := DIR + "install.zip"
const INSTALL_DIR := DIR + "install/"
const INSTALL_VERSION := DIR + "install-version.txt"

var failed := ""          ## a version whose pack would not start here; not offered as a patch again

var current := ""
var latest := {}          ## {version, name, notes, page, news, pack_url, pack_size}
var available := false    ## a newer release exists
var can_reinstall := false   ## ...with no pack for this build (a new engine or plugin), but its whole
                             ## game can be fetched and put over this one (Windows, Linux, a folder we may write)
var reinstall_ready := ""    ## the version unpacked in user://update/install, to be put in place on restart
var can_patch := false    ## ...and it has a pack this build can run
var staged := ""          ## version waiting in user://update, if any
var busy := false

var _http: HTTPRequest
var _dl: HTTPRequest
var _man: HTTPRequest
var _tried_github := false
var _assets := {}            ## the newest release's files: {name: {url, size, digest}}
var _queue: Array = []       ## files still to fetch: [{url, dest, size, sha}]
var _q_total := 0            ## bytes in the whole fetch
var _q_done := 0             ## bytes of the files already fetched
var _next_plan := {}         ## the parts list of the version being fetched
var _repairing := false      ## the fetch is "Check game files", not an update
var on_code_pack := false    ## this run started from a code pack, with its parts loaded beside it
var parts_missing := PackedStringArray()   ## parts a code pack named that were nowhere to be found
var parts_from := {}         ## part name -> where it was loaded from (a file, or "install")


func _init() -> void:
	_load_parts()


## A code pack carries no models, textures or sound: load the parts it names, before anything is read.
## The installed game is loaded first and without replacing files, for the parts it still holds; fetched
## parts go over it.
func _load_parts() -> void:
	if not FileAccess.file_exists("res://.code_pack"):
		return
	on_code_pack = true
	var mine := my_plan()
	var inst := _install_record()
	var from_install := false
	for p in mine.get("parts", []):
		var n := str(p.get("name", ""))
		if FileAccess.file_exists(PARTS_DIR + n + FIX):
			DirAccess.remove_absolute(PARTS_DIR + n)
			DirAccess.rename_absolute(PARTS_DIR + n + FIX, PARTS_DIR + n)
		if not FileAccess.file_exists(PARTS_DIR + n) and n in inst.get("parts", []):
			from_install = true
	if from_install and not _load_install():
		from_install = false
	for p in mine.get("parts", []):
		var n := str(p.get("name", ""))
		if FileAccess.file_exists(PARTS_DIR + n) and ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(PARTS_DIR + n), true):
			parts_from[n] = PARTS_DIR + n
		elif from_install and n in inst.get("parts", []):
			parts_from[n] = "install"
		else:
			parts_missing.append(n)


## Loads the installed game's own pack beside the code pack, adding only what the code pack lacks.
func _load_install() -> bool:
	for c in install_pack_paths():
		if FileAccess.file_exists(c) and ProjectSettings.load_resource_pack(c, false):
			return true
	return false


## Where the installed game keeps its pack: inside the program (Windows, Linux), beside it, or in a Mac app.
static func install_pack_paths() -> PackedStringArray:
	var exe := OS.get_executable_path()
	var d := exe.get_base_dir()
	var base := exe.get_file().get_basename()
	return PackedStringArray([exe, d.path_join(base + ".pck"), d.path_join("Brelm.pck"), d.path_join("../Resources/Brelm.pck").simplify_path(), d.path_join("../Resources/" + base + ".pck").simplify_path()])


## This platform's parts, from res://parts.json (in every pack since split updates came in).
static func my_plan() -> Dictionary:
	if not FileAccess.file_exists("res://parts.json"):
		return {}
	var all = JSON.parse_string(FileAccess.get_file_as_string("res://parts.json"))
	return all.get(os_name(), {}) if all is Dictionary and all.get(os_name()) is Dictionary else {}


static func os_name() -> String:
	return "macOS" if OS.get_name() == "macOS" else "Windows" if OS.get_name() == "Windows" else OS.get_name()


func _install_record() -> Dictionary:
	if not FileAccess.file_exists(INSTALL):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(INSTALL))
	return d if d is Dictionary else {}


func _enter_tree() -> void:
	current = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	failed = _read(FAILED) if FileAccess.file_exists(FAILED) else ""
	if FileAccess.file_exists(DIR + "installing.txt"):
		# A whole new game was put in place before this start: the copy it came from is no longer needed
		var want := _read(DIR + "installing.txt")
		DirAccess.remove_absolute(DIR + "installing.txt")
		if compare(current, want) < 0:
			push_warning("Updater: version %s was not put in place; still %s." % [want, current])
			failed = want
			DirAccess.make_dir_recursive_absolute(DIR)
			_write(FAILED, want)
		_clear_install()
	reinstall_ready = _read_or(INSTALL_VERSION) if DirAccess.dir_exists_absolute(INSTALL_DIR) else ""
	if reinstall_ready != "" and compare(reinstall_ready, current) <= 0:
		_clear_install()
		reinstall_ready = ""
	if on_code_pack and not parts_missing.is_empty():
		# The update's data is not all here: never run half a game. Back onto the installed one.
		push_warning("Updater: parts missing for %s: %s" % [current, ", ".join(parts_missing)])
		failed = current
		DirAccess.make_dir_recursive_absolute(DIR)
		_write(FAILED, current)
		DirAccess.remove_absolute(STARTED)
		_clear_next()
		_clear()
		_relaunch(true, false)
		return
	if not on_code_pack and not (FileAccess.file_exists(PACK) and _read_or(VERSION_FILE) == current):
		# Running the installed game: note which parts it holds, so an update need not fetch them again
		var mine := my_plan()
		var names := []
		for p in mine.get("parts", []):
			names.append(str(p.get("name", "")))
		if names.is_empty():
			DirAccess.remove_absolute(INSTALL)
		elif _install_record().get("version", "") != current or _install_record().get("parts", []) != names:
			DirAccess.make_dir_recursive_absolute(DIR)
			_write(INSTALL, JSON.stringify({"version": current, "parts": names}))
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
	_man = HTTPRequest.new()
	_man.timeout = 20.0
	_man.request_completed.connect(_on_manifest)
	add_child(_man)
	# A dedicated server looks when its own settings say (scripts/server_admin.gd)
	if DisplayServer.get_name() != "headless" and not OS.has_feature("editor") and "server" not in OS.get_cmdline_user_args():
		check.call_deferred()


func _process(_delta: float) -> void:
	if busy and _dl.get_body_size() > 0:
		if _q_total > 0:
			progress.emit(_q_done + _dl.get_downloaded_bytes(), _q_total)
		else:
			progress.emit(_dl.get_downloaded_bytes(), _dl.get_body_size())


# ------------------------------------------------------------------ asking

func check() -> void:
	_tried_github = false
	var u: String = Net.lobby_url() if Net.has_method("lobby_url") else ""
	if OS.is_debug_build() and OS.get_environment("BRELM_RELEASES") != "":
		u = ""
	if u == "" or _http.request(u + "/latest") != OK:
		_ask_github()


func _ask_github() -> void:
	_tried_github = true
	_http.cancel_request()
	var test := OS.get_environment("BRELM_RELEASES") if OS.is_debug_build() else ""
	_http.request(test if test != "" else "https://api.github.com/repos/%s/releases?per_page=10" % REPO,
		["User-Agent: Brelm-updater", "Accept: application/vnd.github+json"])


func _on_latest(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var data = null
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		if not _tried_github:
			_ask_github()
		else:
			check_failed.emit("No answer came from the release list. Try again later.")
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
		check_failed.emit("The release list gave an answer this version cannot read.")
		return
	var assets: Dictionary = data.get("assets", {}) if data.get("assets") is Dictionary else {}
	var pack: Dictionary = assets.get(pack_name(), {}) if assets.get(pack_name()) is Dictionary else {}
	latest = {"version": str(data.get("version", "")), "name": str(data.get("name", "")),
		"notes": str(data.get("notes", "")), "page": str(data.get("page", "")), "news": str(data.get("news", "")),
		"pack_url": str(pack.get("url", "")), "pack_size": int(pack.get("size", 0)), "pack_sha": _sha_of(pack.get("digest", ""))}
	# A pack holds scripts: only one from this game's own releases is ever taken
	if not str(latest.pack_url).begins_with(pack_home()):
		latest.pack_url = ""
	available = latest.version != "" and compare(latest.version, current) > 0
	can_patch = available and latest.pack_url != "" and latest.version != failed   # a pack that would not start here is not offered again
	if available and staged == latest.version:
		can_patch = false    # already fetched; it waits for a restart
	reinstall_ready = _read_or(INSTALL_VERSION) if DirAccess.dir_exists_absolute(INSTALL_DIR) else ""
	if reinstall_ready != "" and compare(reinstall_ready, current) <= 0:
		_clear_install()
		reinstall_ready = ""
	var zip: Dictionary = assets.get(zip_name(), {}) if assets.get(zip_name()) is Dictionary else {}
	can_reinstall = available and not can_patch and reinstall_ready != latest.version and latest.version != failed \
		and str(zip.get("url", "")).begins_with(pack_home()) and install_dir_writable()
	if can_reinstall:
		latest.zip_url = str(zip.url)
		latest.zip_size = int(zip.get("size", 0))
		latest.zip_sha = _sha_of(zip.get("digest", ""))
	_assets = assets
	_queue = []
	_q_total = 0
	_next_plan = {}
	# A split release: read its list of parts, to fetch only what is not here
	var man: Dictionary = assets.get(manifest_name(), {}) if assets.get(manifest_name()) is Dictionary else {}
	var mu := str(man.get("url", ""))
	if available and latest.version != failed and staged != latest.version and mu.begins_with(pack_home()):
		_man.cancel_request()
		if _man.request(mu, ["User-Agent: Brelm-updater"]) == OK:
			return
	checked.emit()


static func manifest_name() -> String:
	var v := Engine.get_version_info()
	return "Brelm-%s-godot%d.%d-%s-parts.json" % [os_name(), v.major, v.minor, LIBS]


func _on_manifest(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var m = null
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		m = JSON.parse_string(body.get_string_from_utf8())
	var q := plan_fetch(m, _assets, _install_record(), PARTS_DIR) if m is Dictionary else []
	if not q.is_empty():
		_queue = q
		_next_plan = m
		var total := 0
		for it in q:
			total += int(it.size)
		latest.pack_size = total     # what the update costs: the code pack and the changed parts only
		can_patch = true
		can_reinstall = false
	checked.emit()   # else the whole pack, as before


## What a split update must fetch: its code pack, and each part not already in parts_dir (of the right
## size) nor held by the installed game. Empty if the list cannot be used (then the whole pack is taken).
static func plan_fetch(m: Dictionary, assets: Dictionary, inst: Dictionary, parts_dir: String) -> Array:
	var q := []
	var code = m.get("code")
	if not (code is Dictionary) or str(m.get("libs", "")) != LIBS:
		return []
	var cu := _asset_url(code, assets)
	if cu == "":
		return []
	q.append({"url": cu, "dest": NEXT, "size": int(code.get("size", 0)), "sha": str(code.get("sha256", ""))})
	for p in m.get("parts", []):
		if not (p is Dictionary):
			return []
		var n := str(p.get("name", ""))
		if n == "" or "/" in n or ".." in n:
			return []
		var have := FileAccess.file_exists(parts_dir + n)
		if have:
			var f := FileAccess.open(parts_dir + n, FileAccess.READ)
			have = f != null and f.get_length() == int(p.get("size", -1))
		if have or n in inst.get("parts", []):
			continue
		var u := _asset_url(p, assets)
		if u == "":
			return []
		q.append({"url": u, "dest": parts_dir + n, "size": int(p.get("size", 0)), "sha": str(p.get("sha256", ""))})
	return q


## A file of the list: from this release's own files, or (a part left as it was) from an earlier
## release of the game. Never from anywhere else.
static func _asset_url(e: Dictionary, assets: Dictionary) -> String:
	var n := str(e.get("name", ""))
	var u := ""
	if assets.get(n) is Dictionary:
		u = str(assets[n].get("url", ""))
	if u == "":
		u = str(e.get("url", ""))
	return u if u.begins_with(pack_home()) else ""


const PACK_HOME := "https://github.com/" + REPO + "/releases/download/"


## Where this game's own release files are; a test (a debug build only) may point it at a local server.
static func pack_home() -> String:
	if OS.is_debug_build() and OS.get_environment("BRELM_PACK_HOME") != "":
		return OS.get_environment("BRELM_PACK_HOME")
	return PACK_HOME


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
	return "Brelm-%s-godot%d.%d-%s.pck" % [os, v.major, v.minor, LIBS]


# ------------------------------------------------------------------ checking the game's files

var _check_thread: Thread


## Reads every fetched part this game runs on and sets it beside the hash it was published with; any
## that differ are fetched again (they go in place on the next start). Answers with files_checked.
func check_files() -> void:
	if busy or (_check_thread != null and _check_thread.is_alive()):
		return
	if not on_code_pack:
		files_checked.emit(true, "This game runs as it was installed. If something in it is broken, install it again from the release page; your saves stay.")
		return
	var live = JSON.parse_string(_read_or(LIVE_PARTS)) if FileAccess.file_exists(LIVE_PARTS) else null
	if not (live is Dictionary):
		files_checked.emit(true, "There is no list to check this version's files against. Next update, there will be.")
		return
	var todo := []
	for p in live.get("parts", []):
		if p is Dictionary and parts_from.get(str(p.get("name", ""))) is String and parts_from[str(p.name)] != "install":
			todo.append(p)
	busy = true
	_check_thread = Thread.new()
	_check_thread.start(_hash_parts.bind(todo))


func _hash_parts(todo: Array) -> void:
	var bad := []
	for p in todo:
		var path := PARTS_DIR + str(p.name)
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null or f.get_length() != int(p.get("size", -1)) or file_sha256(path) != str(p.get("sha256", "")):
			bad.append(p)
	_checked_parts.call_deferred(bad)


func _checked_parts(bad: Array) -> void:
	_check_thread.wait_to_finish()
	busy = false
	if bad.is_empty():
		files_checked.emit(true, "All the game's files are whole.")
		return
	_queue = []
	for p in bad:
		var u := str(p.get("url", ""))
		if not u.begins_with(pack_home()):
			u = pack_home() + "v%s/%s" % [current, str(p.name)]
		_queue.append({"url": u, "dest": PARTS_DIR + str(p.name), "size": int(p.get("size", 0)), "sha": str(p.get("sha256", ""))})
	_q_total = 0
	for it in _queue:
		_q_total += int(it.size)
	_q_done = 0
	_repairing = true
	busy = true
	files_checked.emit(false, "%d of the game's files were damaged. Fetching them again..." % bad.size())
	_fetch_next()


# ------------------------------------------------------------------ a whole new game

## The release's zip for this platform; none for macOS (an app may not be rewritten from inside).
static func zip_name() -> String:
	match os_name():
		"Windows": return "Brelm-Windows.zip"
		"Linux": return "Brelm-Linux.zip"
	return ""


## The installed game's folder may be written to (the installer puts it in the player's own programs).
static func install_dir_writable() -> bool:
	var testing := OS.is_debug_build() and OS.get_environment("BRELM_PACK_HOME") != ""
	if zip_name() == "" or (OS.has_feature("editor") and not testing):
		return false
	var t := OS.get_executable_path().get_base_dir().path_join(".brelm-write-test")
	var f := FileAccess.open(t, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(t)
	return true


## Fetches the whole game (a new engine or plugin came in) and unpacks it beside the saves.
func download_install() -> void:
	if busy or not can_reinstall:
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	_clear_install()
	_queue = [{"url": latest.zip_url, "dest": INSTALL_ZIP, "size": int(latest.zip_size), "sha": str(latest.get("zip_sha", "")), "zip": true}]
	_q_total = int(latest.zip_size)
	_q_done = 0
	_repairing = false
	busy = true
	_fetch_next()


## Unpacks the fetched zip into INSTALL_DIR. False if it would not open or held a path out of it.
func _unpack_install() -> bool:
	var z := ZIPReader.new()
	if z.open(ProjectSettings.globalize_path(INSTALL_ZIP)) != OK:
		return false
	var root := ProjectSettings.globalize_path(INSTALL_DIR)
	var ok := true
	for name in z.get_files():
		if name.ends_with("/"):
			continue
		if name.begins_with("/") or ".." in name.split("/") or ":" in name:
			ok = false
			break
		var out := root.path_join(name)
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			ok = false
			break
		f.store_buffer(z.read_file(name))
		f.close()
	z.close()
	DirAccess.remove_absolute(INSTALL_ZIP)
	return ok and FileAccess.file_exists(root.path_join(OS.get_executable_path().get_file()))


## Starts the little script that waits for this game to close, copies the new one over it and starts
## it, then ends this game. False if it could not be started.
func _run_install() -> bool:
	var src := ProjectSettings.globalize_path(INSTALL_DIR).trim_suffix("/")
	var exe := OS.get_executable_path()
	var dst := exe.get_base_dir()
	var pid := str(OS.get_process_id())
	var args := restart_args(false)
	var script := ProjectSettings.globalize_path(DIR)
	var started := 0
	if os_name() == "Windows":
		script = script.path_join("put-in-place.bat")
		_write(script, "\r\n".join(PackedStringArray([
			"@echo off",
			"rem Brelm's updater: puts the new version in place once the game has closed, then starts it.",
			"set n=0",
			":wait",
			"tasklist /FI \"PID eq %s\" 2>nul | find \" %s \" >nul || goto copy" % [pid, pid],
			"set /a n+=1",
			"if %n% GEQ 60 goto copy",
			"timeout /t 1 /nobreak >nul",
			"goto wait",
			":copy",
			"xcopy \"%s\\*\" \"%s\\\" /E /Y /Q /R >nul" % [src.replace("/", "\\"), dst.replace("/", "\\")],
			"start \"\" \"%s\" %s" % [exe.replace("/", "\\"), " ".join(Array(args).map(func(a): return "\"%s\"" % str(a).replace("\"", "")))],
			""])))
		started = OS.create_process("cmd.exe", ["/c", script.replace("/", "\\")])
	else:
		script = script.path_join("put-in-place.sh")
		_write(script, "\n".join(PackedStringArray([
			"#!/bin/sh",
			"# Brelm's updater: puts the new version in place once the game has closed, then starts it.",
			"n=0",
			"while kill -0 %s 2>/dev/null && [ $n -lt 60 ]; do sleep 1; n=$((n+1)); done" % pid,
			"cp -rf '%s'/. '%s'/" % [src, dst],
			"chmod +x '%s'; chmod +x '%s'/*.sh 2>/dev/null" % [exe, dst],
			"exec '%s' %s" % [exe, " ".join(Array(args).map(func(a): return "'%s'" % str(a).replace("'", "'\\''")))],
			""])))
		started = OS.create_process("/bin/sh", [script])
	if started <= 0:
		return false
	_write(DIR + "installing.txt", reinstall_ready)
	if FileAccess.file_exists("user://running"):
		DirAccess.remove_absolute("user://running")
	get_tree().quit()
	return true


func _clear_install() -> void:
	if DirAccess.dir_exists_absolute(INSTALL_DIR):
		_rm_tree(ProjectSettings.globalize_path(INSTALL_DIR))
	DirAccess.remove_absolute(INSTALL_ZIP)
	DirAccess.remove_absolute(INSTALL_ZIP + ".part")
	DirAccess.remove_absolute(INSTALL_VERSION)


static func _rm_tree(path: String) -> void:
	for d in DirAccess.get_directories_at(path):
		_rm_tree(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


# ------------------------------------------------------------------ fetching

func download() -> void:
	if busy or not can_patch:
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.make_dir_recursive_absolute(PARTS_DIR)
	if _queue.is_empty():
		_queue = [{"url": latest.pack_url, "dest": NEXT, "size": int(latest.pack_size), "sha": str(latest.get("pack_sha", ""))}]
		_next_plan = {}
	_q_total = 0
	for it in _queue:
		_q_total += int(it.size)
	_q_done = 0
	_repairing = false
	busy = true
	_fetch_next()


## Starts the next file of the fetch.
func _fetch_next() -> void:
	var it: Dictionary = _queue[0]
	_dl.download_file = str(it.dest) + ".part"
	if _dl.request(str(it.url), ["User-Agent: Brelm-updater"]) != OK:
		busy = false
		finished.emit(false, "The road to the new version could not be opened.")


func cancel() -> void:
	if busy:
		_dl.cancel_request()
		busy = false
		if not _queue.is_empty():
			DirAccess.remove_absolute(str(_queue[0].dest) + ".part")


func _on_download(result: int, code: int, _h: PackedStringArray, _body: PackedByteArray) -> void:
	if _queue.is_empty():
		busy = false
		return
	var it: Dictionary = _queue[0]
	var dest := str(it.dest)
	var part := dest + ".part"
	var size := 0
	if FileAccess.file_exists(part):
		var f := FileAccess.open(part, FileAccess.READ)
		size = f.get_length()
		f.close()
	var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200 and size > 0
	if ok and int(it.size) > 0 and size != int(it.size):
		ok = false
	if ok and str(it.get("sha", "")) != "" and file_sha256(part) != str(it.sha):
		ok = false   # not the file that was published
	if not ok or not (_looks_like_zip(part) if it.get("zip", false) else _looks_like_pack(part)):
		busy = false
		DirAccess.remove_absolute(part)
		finished.emit(false, "The download failed. Try again later.")
		return
	# A part in use (repaired while the game runs on it) waits beside it; anything else goes in place
	var to := dest + FIX if _repairing and FileAccess.file_exists(dest) else dest
	DirAccess.remove_absolute(to)
	DirAccess.rename_absolute(part, to)
	_q_done += size
	_queue.pop_front()
	if not _queue.is_empty():
		_fetch_next()
		return
	busy = false
	if it.get("zip", false):
		if not _unpack_install():
			_clear_install()
			finished.emit(false, "The new version would not unpack. Try again later.")
			return
		_write(INSTALL_VERSION, latest.version)
		reinstall_ready = latest.version
		can_reinstall = false
		finished.emit(true, "Version %s is ready. Restart to walk it." % latest.version)
		return
	if _repairing:
		_repairing = false
		finished.emit(true, "Game files mended. Restart to use them.")
		return
	if _next_plan.is_empty():
		DirAccess.remove_absolute(NEXT_PARTS)
	else:
		_write(NEXT_PARTS, JSON.stringify(_next_plan))
	_write(NEXT_VERSION, latest.version)
	staged = latest.version
	can_patch = false
	finished.emit(true, "Version %s is ready. Restart to walk it." % latest.version)


func _looks_like_zip(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var magic := f.get_32()
	f.close()
	return magic == 0x04034b50    # "PK\3\4"


func _looks_like_pack(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var magic := f.get_32()
	f.close()
	return magic == 0x43504447    # "GDPC"


## Saves, then starts the game again on the staged pack.
func restart() -> void:
	if reinstall_ready != "" and staged == "":
		if Game.has_method("save"):
			Game.save()
		if not _run_install():
			finished.emit(false, "The new version could not be put in place. Download it from the release page.")
		return
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
	DirAccess.remove_absolute(LIVE_PARTS)
	if FileAccess.file_exists(NEXT_PARTS):
		DirAccess.rename_absolute(NEXT_PARTS, LIVE_PARTS)
	_relaunch(true)


## Starts this program again and ends this one: on the fetched version if one waits, else as it runs now.
## For the dedicated server's Restart. False if the new start could not be made.
func relaunch() -> bool:
	if staged != "" and FileAccess.file_exists(NEXT):
		_swap_and_go()   # ends this process, unless the new version could not be put in place
	return _relaunch(false, FileAccess.file_exists(PACK))


func _relaunch(hard: bool, on_pack := true) -> bool:
	var to := _read(VERSION_FILE) if FileAccess.file_exists(VERSION_FILE) else ""
	if to != "" and to != _read_or(BOOTED):
		_write(STARTED, to)   # cleared, or found unanswered, on the next start
	var args := restart_args(on_pack)
	# This is a planned stop, not a crash: take down the "still running" flag (scripts/report.gd) first,
	# or the new start finds it and offers to send a crash report for the update
	if FileAccess.file_exists("user://running"):
		DirAccess.remove_absolute("user://running")
	if OS.create_process(OS.get_executable_path(), args) > 0:
		if hard:
			OS.kill(OS.get_process_id())
		get_tree().quit.call_deferred()
		return true
	else:
		var f := FileAccess.open("user://running", FileAccess.WRITE)   # still running after all
		if f:
			f.store_string(str(ProjectSettings.get_setting("application/config/version", "")))
		push_warning("Updater: could not restart onto the new version; running the installed one.")
		return false


## What this game was started with, for starting it again (on the fetched pack if on_pack).
static func restart_args(on_pack: bool) -> PackedStringArray:
	var args := PackedStringArray(["--main-pack", ProjectSettings.globalize_path(PACK)] if on_pack else [])
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
	return args


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
	_tidy_parts()
	if failed != "" and compare(current, failed) >= 0:
		failed = ""
		DirAccess.remove_absolute(FAILED)


## Takes away fetched parts that neither this version nor the one waiting needs.
func _tidy_parts() -> void:
	if not DirAccess.dir_exists_absolute(PARTS_DIR):
		return
	var keep := {}
	for p in my_plan().get("parts", []):
		keep[str(p.get("name", ""))] = true
	if FileAccess.file_exists(NEXT_PARTS) and FileAccess.file_exists(NEXT):
		var nx = JSON.parse_string(_read(NEXT_PARTS))
		if nx is Dictionary:
			for p in nx.get("parts", []):
				if p is Dictionary:
					keep[str(p.get("name", ""))] = true
	if busy:
		for it in _queue:
			keep[str(it.dest).get_file()] = true
	for f in DirAccess.get_files_at(PARTS_DIR):
		var n := f.trim_suffix(FIX).trim_suffix(".part")
		if not keep.has(n):
			DirAccess.remove_absolute(PARTS_DIR + f)


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
