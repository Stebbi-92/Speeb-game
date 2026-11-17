class_name WPlaylog
extends RefCounted
## A local playtest log: when each goal was reached, and how long it took since the last one.
## Kept on this machine only, in user://playtest/, one file per sitting. Nothing is sent anywhere.

static var _file := ""
static var _t0 := 0
static var _last_goal := 0
static var _firsts := {}


static func begin(world_name: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://playtest")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	_file = "user://playtest/%s.log" % stamp
	_t0 = Time.get_ticks_msec()
	_last_goal = _t0
	_firsts.clear()
	_write("Sitting begun in %s (version %s)" % [world_name, ProjectSettings.get_setting("application/config/version", "?")])


static func _clock(ms: int) -> String:
	var s := int(ms / 1000)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


static func _write(line: String) -> void:
	if _file == "":
		return
	var f := FileAccess.open(_file, FileAccess.READ_WRITE if FileAccess.file_exists(_file) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("[%s] %s" % [_clock(Time.get_ticks_msec() - _t0), line])
	f.close()


## Something happened worth noting, but it is not a goal.
static func note(what: String) -> void:
	_write(what)


## A goal was reached: logged with the time since the last goal, and the first of each kind marked.
static func goal(kind: String, what: String) -> void:
	if _file == "":
		return
	var now := Time.get_ticks_msec()
	var gap := _clock(now - _last_goal)
	_last_goal = now
	var first := ""
	if not _firsts.has(kind):
		_firsts[kind] = now - _t0
		first = " (first %s)" % kind
	_write("GOAL %s%s, %s since the last goal" % [what, first, gap])


## The time from the start of the sitting to the first goal of a kind, in seconds; -1 if not yet.
static func first_at(kind: String) -> float:
	return float(_firsts.get(kind, -1000)) / 1000.0


static func end() -> void:
	if _file == "":
		return
	var parts: Array = []
	for k in _firsts:
		parts.append("first %s at %s" % [k, _clock(int(_firsts[k]))])
	_write("Sitting ended. " + (", ".join(parts) if not parts.is_empty() else "No goals reached."))
	_file = ""


static func path() -> String:
	return _file
