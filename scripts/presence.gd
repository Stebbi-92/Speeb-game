extends Node
## Shows what is being played in Discord ("Playing Brelm"), through Discord's local pipe, and lets
## friends join a fellowship from Discord: the join code (and its word, if any) rides as the join secret,
## so Discord's Join button and invites bring a friend straight in.
## Only on Windows, where the pipe can be opened as a file; elsewhere, and when Discord is not running,
## it does nothing.
##
## The pipe is used from one worker thread, one request at a time: each update is written, then frames
## are read until its answer comes back. Events Discord sends between (someone joining) are read on the way.

const CLIENT_ID := "1571133506690748490"

var _pipe: FileAccess
var _started := 0
var _last := ""
var _t := 0.0
var _retry := 0.0
var _busy := false
var _thread: Thread
var _subscribed := false


func _ready() -> void:
	_started = int(Time.get_unix_time_from_system())
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		set_process(false)


func _process(delta: float) -> void:
	_t -= delta
	_retry -= delta
	if _t > 0.0 or _busy:
		return
	_t = 4.0
	if _thread and not _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null
	var a := _activity()
	var key := JSON.stringify(a)
	if _pipe == null and _retry > 0.0:
		return
	_busy = true
	_thread = Thread.new()
	_thread.start(_work.bind(a, key))


## On the worker: connect if need be, subscribe once, then send the activity if it changed (or just
## ask Discord something small, so any waiting event is read).
func _work(a: Dictionary, key: String) -> void:
	if _pipe == null and not _connect():
		_busy = false
		return
	if not _subscribed:
		_subscribed = true
		_request({"cmd": "SUBSCRIBE", "evt": "ACTIVITY_JOIN"})
	if key != _last:
		if _request({"cmd": "SET_ACTIVITY", "args": {"pid": OS.get_process_id(), "activity": a}}):
			_last = key
	else:
		_request({"cmd": "SET_ACTIVITY", "args": {"pid": OS.get_process_id(), "activity": a}})
	_busy = false


## What to show: where the pilgrim is and with whom, and how to join them.
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
	var a := {"details": details, "timestamps": {"start": _started}, "instance": false}
	if Net.online:
		state = ("%s · " % state if state != "" else "") + "In a fellowship"
		if Net.join_code != "":
			a["party"] = {"id": "brelm-" + Net.join_code, "size": [Net.pilgrims().size(), Net.MAX_PLAYERS]}
			a["secrets"] = {"join": Net.join_code + ("|" + Net.password if Net.password != "" else "")}
	elif lvl:
		state = ("%s · " % state if state != "" else "") + "Alone"
	if state != "":
		a["state"] = state
	return a


func _connect() -> bool:
	for i in 10:
		var f := FileAccess.open("\\\\.\\pipe\\discord-ipc-%d" % i, FileAccess.READ_WRITE)
		if f != null:
			_pipe = f
			_subscribed = false
			_last = ""
			if _write(0, {"v": 1, "client_id": CLIENT_ID}) and _read_until(""):
				return true
	_drop(60.0)
	return false


func _request(body: Dictionary) -> bool:
	var nonce := str(Time.get_ticks_usec()) + str(randi())
	body["nonce"] = nonce
	return _write(1, body) and _read_until(nonce)


func _write(op: int, body: Dictionary) -> bool:
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
		_drop(30.0)
		return false
	return true


## Reads frames until the answer with this nonce (or, for the handshake, the READY event).
func _read_until(nonce: String) -> bool:
	for n in 16:
		if _pipe == null:
			return false
		var head := _pipe.get_buffer(8)
		if head.size() < 8:
			_drop(30.0)
			return false
		var op := head.decode_s32(0)
		var size := head.decode_s32(4)
		if size < 0 or size > 65536:
			_drop(30.0)
			return false
		var msg = JSON.parse_string(_pipe.get_buffer(size).get_string_from_utf8())
		if op == 2:
			_drop(60.0)
			return false
		if not msg is Dictionary:
			continue
		if str(msg.get("evt", "")) == "ACTIVITY_JOIN":
			var secret := str(msg.get("data", {}).get("secret", ""))
			if secret != "":
				_on_join.call_deferred(secret)
			continue
		if str(msg.get("evt", "")) == "ERROR" and nonce != "" and str(msg.get("nonce", "")) == nonce:
			return false
		if nonce == "" and str(msg.get("evt", "")) == "READY":
			return true
		if nonce != "" and str(msg.get("nonce", "")) == nonce:
			return true
	return false


func _drop(wait: float) -> void:
	if _pipe:
		_pipe.close()
	_pipe = null
	_retry = wait


## A friend's Join, from Discord: leave whatever this is and walk into their fellowship.
func _on_join(secret: String) -> void:
	var parts := secret.split("|", true, 1)
	var code := parts[0]
	if not Net.is_code(code) or (Net.online and Net.join_code == code):
		return
	Net.join_word = parts[1] if parts.size() > 1 else ""
	if Game.main and Game.main.get("_state") != "title":
		await Game.main.show_title()
	Net.join_code_lookup(code)


func _exit_tree() -> void:
	if _thread:
		_thread.wait_to_finish()
	if _pipe:
		_pipe.close()
