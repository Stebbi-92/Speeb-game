extends Node
## Shows what is being played in Discord ("Playing Brelm"), through Discord's local pipe.
## Only on Windows, where the pipe can be opened as a file; elsewhere, and when Discord is
## not running, it does nothing. Nothing leaves the machine but what Discord itself sends on.

const CLIENT_ID := "1571133506690748490"

var _pipe: FileAccess
var _started := 0
var _last := ""
var _t := 0.0
var _retry := 0.0


func _ready() -> void:
	_started = int(Time.get_unix_time_from_system())
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		set_process(false)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 5.0
	var a := _activity()
	var key := JSON.stringify(a)
	if key == _last and _pipe != null:
		return
	if _pipe == null:
		_retry -= 5.0
		if _retry > 0.0 or not _connect():
			return
	if _send(1, {"cmd": "SET_ACTIVITY", "args": {"pid": OS.get_process_id(), "activity": a}, "nonce": str(Time.get_ticks_usec())}):
		_last = key


## What to show: where the pilgrim is and with whom.
func _activity() -> Dictionary:
	var details := "In the main menu"
	var state := ""
	var lvl = Game.main.level if Game.main and "level" in Game.main and is_instance_valid(Game.main.level) else null
	if lvl:
		if Game.wasteland:
			details = "The Ashen Waste, day %d" % int(lvl.get("day"))
			state = "Night" if lvl.get("night") else "Day"
		else:
			details = str(lvl.get("place"))
	if Net.online:
		state = ("%s · " % state if state != "" else "") + "Fellowship of %d" % Net.pilgrims().size()
	elif lvl:
		state = ("%s · " % state if state != "" else "") + "Alone"
	var a := {"details": details, "timestamps": {"start": _started}}
	if state != "":
		a["state"] = state
	return a


func _connect() -> bool:
	for i in 10:
		var f := FileAccess.open("\\\\.\\pipe\\discord-ipc-%d" % i, FileAccess.READ_WRITE)
		if f != null:
			_pipe = f
			if _send(0, {"v": 1, "client_id": CLIENT_ID}):
				return true
	_pipe = null
	_retry = 60.0
	return false


func _send(op: int, body: Dictionary) -> bool:
	if _pipe == null:
		return false
	var data := JSON.stringify(body).to_utf8_buffer()
	var head := PackedByteArray()
	head.resize(8)
	head.encode_s32(0, op)
	head.encode_s32(4, data.size())
	_pipe.store_buffer(head + data)
	_pipe.flush()
	if _pipe.get_error() != OK:
		_pipe = null
		_retry = 30.0
		return false
	return true


func _exit_tree() -> void:
	if _pipe:
		_pipe.close()
