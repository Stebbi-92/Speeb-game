extends Node
## The fellowship: up to four pilgrims walking the trials together.
## One of them hosts (or a dedicated server does, with no pilgrim of its own), and the host is the authority:
## it runs the lesser forms, orders every shared step of a trial, and decides when a land begins.
## Others join by address or from the list of fellowships (found on the local network, or on the internet list).

signal roster_changed
signal status_changed(text: String)
signal servers_changed
signal session_ended(reason: String)

const DEFAULT_PORT := 24600
const DISCOVERY_PORT := 24601
const MAX_PLAYERS := 4
const PROTOCOL := "brelm-fellowship-2"
const ANNOUNCE_EVERY := 50.0
## The internet list of fellowships: a small Cloudflare Worker (see tools/lobby-worker.js).
## Leave empty to use only the local network and joining by address; it can also be set in Options.
const DEFAULT_LOBBY := "https://game.speeb.org"
const SLOT_COLORS := [Color(0.82, 0.78, 0.7), Color(0.85, 0.62, 0.3), Color(0.45, 0.6, 0.85), Color(0.5, 0.75, 0.5)]
const SLOT_NAMES := ["Ash", "Ochre", "Slate", "Moss"]

var peer: ENetMultiplayerPeer
var online := false
var dedicated := false
var server_name := ""
var public := false
var port := DEFAULT_PORT
## peer id -> {name, slot}
var players := {}
## Which land the fellowship walks. Raised by the host each time a land begins, so stale messages are ignored.
var seq := 0
var in_level := -1
var leader := 0
var upnp_state := ""
var external_ip := ""
var servers := {}
var last_error := ""
var join_code := ""      ## six letters by which the internet list finds this fellowship
var private := false     ## private fellowships are found only by their code or address
var listed_public := false  ## shown in the internet list (otherwise found there only by its code)
var password := ""       ## the word a pilgrim must give to join, if any
var join_word := ""      ## the word this pilgrim gives when joining
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
var _http_code: HTTPRequest
var _probe_sent := 0

var _joining := false
var _own_difficulty := -1
var host_unlimited := false   ## the host's rule: guns never spend their reserve
var _join_t := 0.0
var _disc: PacketPeerUDP
var _probe: PacketPeerUDP
var _probe_t := 0.0
var _announce_t := 0.0
var _http_list: HTTPRequest
var _http_post: HTTPRequest
var _upnp_thread: Thread
var _upnp: UPNP


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	_http_list = HTTPRequest.new()
	_http_list.timeout = 6.0
	_http_list.request_completed.connect(_on_list)
	add_child(_http_list)
	_http_post = HTTPRequest.new()
	_http_post.timeout = 6.0
	add_child(_http_post)
	_http_code = HTTPRequest.new()
	_http_code.timeout = 8.0
	_http_code.request_completed.connect(_on_code)
	add_child(_http_code)


func me() -> int:
	return multiplayer.get_unique_id() if online else 1


func is_host() -> bool:
	return online and multiplayer.is_server()


## True when this machine decides for the fellowship: the host, or a pilgrim walking alone.
func authority() -> bool:
	return not online or multiplayer.is_server()


func lobby_url() -> String:
	var u: String = Game.lobby_url if Game.lobby_url != "" else DEFAULT_LOBBY
	return u.strip_edges().trim_suffix("/")


func my_name() -> String:
	var n := Game.player_name.strip_edges()
	return n if n != "" else "Pilgrim"


func name_of(id: int) -> String:
	return players[id].name if players.has(id) else "A pilgrim"


func slot_of(id: int) -> int:
	return int(players[id].slot) if players.has(id) else 0


func color_of(id: int) -> Color:
	return SLOT_COLORS[slot_of(id) % SLOT_COLORS.size()]


## Everyone who walks the land, by peer id. The dedicated server is not among them.
func pilgrims() -> Array:
	return players.keys()


func _log(t: String) -> void:
	if dedicated or Engine.is_editor_hint():
		print("[%s] %s" % [Time.get_time_string_from_system(), t])
	status_changed.emit(t)


# ------------------------------------------------------------------ hosting and joining

func host(p: int, sname: String, listed: bool, headless := false, priv := false, word := "") -> Error:
	leave("")
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(p, MAX_PLAYERS if headless else MAX_PLAYERS - 1)
	if err != OK:
		last_error = "Could not open port %d. Another program may be using it." % p
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	dedicated = headless
	port = p
	server_name = sname
	private = priv and not listed
	listed_public = listed
	# Every fellowship tells the internet list its code, so its join code always works; only a listed
	# one is shown in the list itself
	public = lobby_url() != ""
	password = word.strip_edges()
	join_code = ""
	for k in 6:
		join_code += CODE_CHARS[randi() % CODE_CHARS.length()]
	seq = 0
	in_level = -1
	players.clear()
	if not headless:
		players[1] = {"name": my_name(), "slot": 0, "look": Game.look.duplicate()}
	leader = 0 if headless else 1
	_open_discovery()
	_open_port_upnp()
	_announce_t = 2.0
	roster_changed.emit()
	_log("Hosting \"%s\" on port %d." % [sname, p])
	return OK


func join(address: String, p: int) -> Error:
	leave("")
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, p)
	if err != OK:
		last_error = "Could not reach %s:%d." % [address, p]
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	_joining = true
	_join_t = 8.0
	_log("Seeking the fellowship at %s:%d..." % [address, p])
	return OK


## Parses "host", "host:port" or "[v6]:port".
static func split_address(s: String) -> Array:
	s = s.strip_edges()
	var p := DEFAULT_PORT
	if s.begins_with("["):
		var close := s.find("]")
		if close > 0:
			if s.length() > close + 2 and s[close + 1] == ":":
				p = int(s.substr(close + 2))
			s = s.substr(1, close - 1)
	elif s.count(":") == 1:
		p = int(s.get_slice(":", 1))
		s = s.get_slice(":", 0)
	return [s, p if p > 0 and p < 65536 else DEFAULT_PORT]


func leave(reason := "") -> void:
	var was := online or _joining
	if is_host():
		_announce_remove()
	_close_port_upnp()
	if _disc:
		_disc.close()
		_disc = null
	if peer:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	dedicated = false
	_joining = false
	players.clear()
	in_level = -1
	seq = 0
	leader = 0
	upnp_state = ""
	external_ip = ""
	join_code = ""
	private = false
	password = ""
	if _own_difficulty >= 0:
		Game.difficulty = _own_difficulty
		_own_difficulty = -1
	host_unlimited = false
	if was:
		roster_changed.emit()
		session_ended.emit(reason)


## The land takes a while to raise when a pilgrim first walks into it, and nothing else moves meanwhile.
## Give each link a long patience so a fellowship is not broken while the waste is being made.
func _patient(id: int) -> void:
	if peer and peer.get_peer(id):
		peer.get_peer(id).set_timeout(32, 90000, 180000)


func _on_connected() -> void:
	_patient(1)
	_joining = false
	_hello.rpc_id(1, my_name(), PROTOCOL, str(ProjectSettings.get_setting("application/config/version", "")), join_word)
	_look.rpc_id(1, Game.look)


func _on_failed() -> void:
	_joining = false
	last_error = "No answer came. The fellowship may be full, gone, or its port closed."
	_log(last_error)
	leave(last_error)


func _on_server_gone() -> void:
	leave("The host has left. The fellowship is broken.")


func _on_peer_connected(id: int) -> void:
	if is_host():
		_patient(id)


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	if players.has(id):
		_log("%s has left the fellowship." % players[id].name)
		players.erase(id)
		if leader == id:
			leader = 1 if not dedicated else (players.keys()[0] if not players.is_empty() else 0)
		_roster.rpc(players, leader)
		roster_changed.emit()
		var lvl = _level()
		if lvl:
			lvl.net_left(id)
	# A dedicated server with no one left returns to waiting
	if dedicated and players.is_empty() and in_level >= 0:
		in_level = -1
		seq += 1
		Game.main.server_idle()


@rpc("any_peer", "call_remote", "reliable")
func _hello(pname: String, proto: String, version: String, word := "") -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if proto != PROTOCOL:
		_refused.rpc_id(id, "This fellowship walks a different version of Brelm (%s)." % version)
		get_tree().create_timer(0.5).timeout.connect(func(): if peer: peer.disconnect_peer(id))
		return
	if password != "" and word.strip_edges() != password:
		_refused.rpc_id(id, "This fellowship is closed. Its host must give you its word.")
		get_tree().create_timer(0.5).timeout.connect(func(): if peer: peer.disconnect_peer(id))
		return
	var used := []
	for k in players:
		used.append(int(players[k].slot))
	var slot := 0
	while slot in used:
		slot += 1
	if slot >= MAX_PLAYERS:
		_refused.rpc_id(id, "The fellowship is full.")
		get_tree().create_timer(0.5).timeout.connect(func(): if peer: peer.disconnect_peer(id))
		return
	pname = pname.strip_edges().left(20)
	if pname == "":
		pname = "Pilgrim"
	players[id] = {"name": pname, "slot": slot}
	if leader == 0:
		leader = id
	_log("%s has joined the fellowship." % pname)
	_roster.rpc(players, leader)
	roster_changed.emit()
	_welcome.rpc_id(id, server_name, Game.difficulty)
	_rules.rpc_id(id, Game.unlimited_ammo)
	if in_level >= 0:
		_begin.rpc_id(id, in_level, seq, Game.difficulty)
	var lvl = _level()
	if lvl:
		lvl.net_joined(id)


@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	last_error = reason
	leave(reason)


@rpc("authority", "call_remote", "reliable")
func _welcome(sname: String, difficulty: int) -> void:
	online = true
	server_name = sname
	_own_difficulty = Game.difficulty
	Game.difficulty = difficulty
	_log("Joined \"%s\"." % sname)
	roster_changed.emit()


func look_of(id: int) -> Dictionary:
	return Figure.clean(players[id].get("look", {})) if players.has(id) else Figure.DEFAULT


## Tells the fellowship how this pilgrim now looks.
func send_look() -> void:
	if not online:
		return
	if multiplayer.is_server():
		if players.has(1):
			players[1].look = Game.shown_look()
			_roster.rpc(players, leader)
			roster_changed.emit()
	else:
		_look.rpc_id(1, Game.shown_look())


@rpc("any_peer", "call_remote", "reliable")
func _look(l: Dictionary) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id].look = Figure.clean(l)
		_roster.rpc(players, leader)
		roster_changed.emit()


## Whether guns spend their reserve. Offline it is the player's own choice; in a fellowship, the host's.
func unlimited_ammo() -> bool:
	return host_unlimited if online and not multiplayer.is_server() else Game.unlimited_ammo


func send_rules() -> void:
	if online and multiplayer.is_server():
		_rules.rpc(Game.unlimited_ammo)


@rpc("authority", "call_remote", "reliable")
func _rules(unlimited: bool) -> void:
	host_unlimited = unlimited


@rpc("authority", "call_remote", "reliable")
func _roster(p: Dictionary, lead: int) -> void:
	players = p
	leader = lead
	roster_changed.emit()


## May this pilgrim choose the trial? The host may, and on a dedicated server the first to arrive.
func may_choose() -> bool:
	return online and (multiplayer.is_server() or leader == me())


# ------------------------------------------------------------------ lands

## The host begins a land for the whole fellowship.
func begin(i: int) -> void:
	if not online:
		Game.main.start_level(i, true)
		return
	if not multiplayer.is_server():
		_choose.rpc_id(1, i, Game.difficulty)
		return
	seq += 1
	in_level = i
	_begin.rpc(i, seq, Game.difficulty)
	Game.main.start_level(i, true)
	_announce_t = 0.5


@rpc("any_peer", "call_remote", "reliable")
func _choose(i: int, difficulty: int) -> void:
	if is_host() and multiplayer.get_remote_sender_id() == leader:
		if dedicated:
			Game.difficulty = difficulty
		begin(i)


@rpc("authority", "call_remote", "reliable")
func _begin(i: int, s: int, difficulty: int) -> void:
	seq = s
	in_level = i
	Game.difficulty = difficulty
	Game.main.start_level(i, true)


## The host returns everyone to the gathering place.
func to_lobby() -> void:
	if is_host():
		seq += 1
		in_level = -1
		_lobby.rpc()
		Game.main.show_lobby()


@rpc("authority", "call_remote", "reliable")
func _lobby() -> void:
	in_level = -1
	Game.main.show_lobby()


func end_of_road() -> void:
	if is_host():
		seq += 1
		in_level = -1
		_credits.rpc()
	Game.main.show_credits()


@rpc("authority", "call_remote", "reliable")
func _credits() -> void:
	in_level = -1
	Game.main.show_credits()


func _level():
	if Game.main and is_instance_valid(Game.main.level) and Game.main.level is Level and Game.main.level.player != null and Game.main.level.is_inside_tree():
		return Game.main.level
	return null


func _here(s: int):
	if s != seq:
		return null
	return _level()


# ------------------------------------------------------------------ shared steps of a trial

## A shared step (an interaction or a threshold crossed) is ordered by the host and taken by everyone.
func event(id: int) -> void:
	if multiplayer.is_server():
		var lvl = _level()
		if lvl and lvl.net_event_allowed(id):
			_event.rpc(seq, id)
	else:
		_event_req.rpc_id(1, seq, id)


@rpc("any_peer", "call_remote", "reliable")
func _event_req(s: int, id: int) -> void:
	var lvl = _here(s)
	if lvl and is_host() and lvl.net_event_allowed(id):
		_event.rpc(s, id)


@rpc("authority", "call_local", "reliable")
func _event(s: int, id: int) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_run_event(id)


## A shared method of the land, taken by everyone in the order the host receives it.
func call_shared(method: String, args: Array) -> void:
	if multiplayer.is_server():
		_call.rpc(seq, method, args)
	else:
		_call_req.rpc_id(1, seq, method, args)


@rpc("any_peer", "call_remote", "reliable")
func _call_req(s: int, method: String, args: Array) -> void:
	if is_host() and _here(s) and method.begins_with("_"):
		_call.rpc(s, method, args)


@rpc("authority", "call_local", "reliable")
func _call(s: int, method: String, args: Array) -> void:
	var lvl = _here(s)
	if lvl and lvl.has_method(method):
		lvl.callv(method, args)


## A method of the land called on one pilgrim only (the host answering a single asker).
func call_peer(id: int, method: String, args: Array) -> void:
	if not online or id == me():
		var lvl = _level()
		if lvl and lvl.has_method(method):
			lvl.callv(method, args)
		return
	_call_one.rpc_id(id, seq, method, args)


@rpc("authority", "call_remote", "reliable")
func _call_one(s: int, method: String, args: Array) -> void:
	var lvl = _here(s)
	if lvl and method.begins_with("_") and lvl.has_method(method):
		lvl.callv(method, args)


# ------------------------------------------------------------------ pilgrims

## One who arrives in a land already under way asks where the fellowship last stood firm.
func ask_checkpoint() -> void:
	_ask_checkpoint.rpc_id(1, seq)


@rpc("any_peer", "call_remote", "reliable")
func _ask_checkpoint(s: int) -> void:
	var lvl = _here(s)
	if lvl and is_host() and lvl.trial_time > 8.0:
		var pos: Vector3 = lvl.spawn_pos
		if dedicated:
			for id in lvl.avatars:
				var a = lvl.avatars[id]
				if is_instance_valid(a) and a.visible and id != multiplayer.get_remote_sender_id():
					pos = a.global_position + Vector3(0, 0.3, 0)
					break
		_place.rpc_id(multiplayer.get_remote_sender_id(), s, pos, lvl.spawn_yaw)


@rpc("authority", "call_remote", "reliable")
func _place(s: int, pos: Vector3, yaw: float) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_place(pos, yaw)

func send_pose(data: Array) -> void:
	_pose.rpc(seq, data)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _pose(s: int, data: Array) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_pose(multiplayer.get_remote_sender_id(), data)


## Something a pilgrim did that the others should see and hear: a shot, a prayer.
func fx(kind: String, a: Vector3, b: Vector3) -> void:
	if online:
		_fx.rpc(seq, kind, a, b)


@rpc("any_peer", "call_remote", "unreliable", 2)
func _fx(s: int, kind: String, a: Vector3, b: Vector3) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_fx(multiplayer.get_remote_sender_id(), kind, a, b)


func hurt(id: int, amount: float, from: Vector3) -> void:
	_hurt.rpc_id(id, seq, amount, from)


@rpc("authority", "call_remote", "reliable")
func _hurt(s: int, amount: float, from: Vector3) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.damage_player(amount, from)


func downed(on: bool) -> void:
	_downed.rpc(seq, on)


@rpc("any_peer", "call_remote", "reliable")
func _downed(s: int, on: bool) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_downed(multiplayer.get_remote_sender_id(), on)


func revive(id: int, strength := 0.5) -> void:
	_revive.rpc_id(id, seq, me(), strength)


@rpc("any_peer", "call_remote", "reliable")
func _revive(s: int, by: int, strength := 0.5) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_revived(by, clampf(strength, 0.1, 1.0))


func wipe() -> void:
	_wipe.rpc(seq)


@rpc("authority", "call_local", "reliable")
func _wipe(s: int) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_wipe()


# ------------------------------------------------------------------ the lesser forms (the host runs them)

func send_foes(batch: Array) -> void:
	_foes.rpc(seq, batch)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _foes(s: int, batch: Array) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_foes(batch)


func foe_died(id: int, slain: bool, killer: int) -> void:
	_foe_died.rpc(seq, id, slain, killer)


@rpc("authority", "call_remote", "reliable")
func _foe_died(s: int, id: int, slain: bool, killer: int) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_foe_died(id, slain, killer)


func hit(id: int, amount: float, dir: Vector3) -> void:
	_hit.rpc_id(1, seq, id, amount, dir)


@rpc("any_peer", "call_remote", "reliable")
func _hit(s: int, id: int, amount: float, dir: Vector3) -> void:
	var lvl = _here(s)
	if lvl and is_host():
		lvl.net_hit(multiplayer.get_remote_sender_id(), id, amount, dir)


func bolt(from: Vector3, vel: Vector3, dmg: float) -> void:
	_bolt.rpc(seq, from, vel, dmg)


@rpc("authority", "call_remote", "reliable")
func _bolt(s: int, from: Vector3, vel: Vector3, dmg: float) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_bolt(from, vel, dmg)


func trial_state(objective: String, meter: String, value: float, done: bool) -> void:
	_trial_state.rpc(seq, objective, meter, value, done)


@rpc("authority", "call_remote", "reliable")
func _trial_state(s: int, objective: String, meter: String, value: float, done: bool) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_trial_state(objective, meter, value, done)


## The Unblinking Eye opens for the whole fellowship at once; if any one of them moves, all are seen.
func eye() -> void:
	_eye.rpc(seq)


@rpc("authority", "call_local", "reliable")
func _eye(s: int) -> void:
	var lvl = _here(s)
	if lvl:
		lvl._unblinking_eye()


func eye_seen() -> void:
	_eye_seen.rpc_id(1, seq)


@rpc("any_peer", "call_remote", "reliable")
func _eye_seen(s: int) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.eye_seen_by_any = true


func eye_result(seen: bool) -> void:
	_eye_result.rpc(seq, seen)


@rpc("authority", "call_remote", "reliable")
func _eye_result(s: int, seen: bool) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_eye_result(seen)


# ------------------------------------------------------------------ finding a fellowship

## Listens for pilgrims on the local network asking who is hosting.
func _open_discovery() -> void:
	_disc = PacketPeerUDP.new()
	if _disc.bind(DISCOVERY_PORT) != OK:
		_disc = null


func _info() -> Dictionary:
	return {"name": server_name, "port": port, "players": players.size(), "max": MAX_PLAYERS,
		"level": in_level, "proto": PROTOCOL, "version": str(ProjectSettings.get_setting("application/config/version", "")),
		"code": join_code, "private": not listed_public, "locked": password != "",
		"ip4": external_ip, "lan": local_addresses()}


## Is this text a join code rather than an address?
static func is_code(t: String) -> bool:
	t = t.strip_edges().to_upper()
	if t.length() != 6:
		return false
	for c in t:
		if not c in CODE_CHARS:
			return false
	return true


## Asks the internet list where the fellowship with this code is, then joins it.
func join_code_lookup(code: String) -> void:
	var u := lobby_url()
	if u == "":
		last_error = "Join codes need an internet list address (Options)."
		_log(last_error)
		return
	_http_code.cancel_request()
	_http_code.request(u + "/code/" + code.strip_edges().to_upper())
	_log("Asking after the fellowship %s..." % code.strip_edges().to_upper())


func _on_code(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS else null
	if code != 200 or not (data is Dictionary) or not data.has("ip"):
		last_error = "No fellowship answers to that code. It may have ended, or the host is not online." if code == 404 else "The internet list did not answer."
		_log(last_error)
		return
	if str(data.get("proto", PROTOCOL)) != PROTOCOL:
		last_error = "That fellowship walks a different version of Brelm (%s)." % data.get("version", "?")
		_log(last_error)
		return
	join(best_address(data), int(data.port))


## Where to reach a fellowship from the internet list: inside our own network if we share it with the
## host (routers seldom loop back to their own public address), else its public IPv4 if the router told
## it one (an IPv6 address only reaches pilgrims who have IPv6 too), else the address the list saw.
static func best_address(s: Dictionary) -> String:
	if s.get("same", false) and s.get("lan") is Array and not s.lan.is_empty():
		return str(s.lan[0])
	if str(s.get("ip4", "")) != "":
		return str(s.ip4)
	return str(s.get("ip", ""))


## Looks for fellowships on the local network and on the internet list.
func refresh_servers() -> void:
	servers.clear()
	servers_changed.emit()
	if _probe:
		_probe.close()
	_probe = PacketPeerUDP.new()
	_probe.set_broadcast_enabled(true)
	_probe.bind(0)
	for target in ["255.255.255.255", "127.0.0.1"]:
		_probe.set_dest_address(target, DISCOVERY_PORT)
		_probe.put_packet("BRELM?".to_utf8_buffer())
	_probe_sent = Time.get_ticks_msec()
	_probe_t = 2.0
	var u := lobby_url()
	if u != "":
		_http_list.cancel_request()
		_http_list.request(u + "/list")


func _on_list(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary) or not (data.get("servers") is Array):
		return
	for s in data.servers:
		if not (s is Dictionary) or not s.has("ip") or not s.has("port"):
			continue
		s["ip"] = best_address(s)
		var key := "%s:%d" % [s.ip, int(s.port)]
		if servers.has(key):
			continue
		# A fellowship on this very network is already listed by its local address
		var near := false
		for k in servers:
			if servers[k].source == "LAN" and servers[k].get("name") == s.get("name") and int(servers[k].port) == int(s.port):
				near = true
		if near:
			continue
		s["source"] = "Internet"
		servers[key] = s
	servers_changed.emit()


func _announce() -> void:
	var u := lobby_url()
	if u == "" or not public or not is_host():
		return
	_http_post.cancel_request()
	_http_post.request(u + "/announce", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(_info()))


func _announce_remove() -> void:
	var u := lobby_url()
	if u == "" or not public:
		return
	_http_post.cancel_request()
	_http_post.request(u + "/remove", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"port": port}))


# ------------------------------------------------------------------ opening the port

## Asks the router to open the port by UPnP, so that pilgrims beyond the local network can join.
func _open_port_upnp() -> void:
	upnp_state = "Asking the router to open port %d..." % port
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port))


func _upnp_work(p: int) -> void:
	var u := UPNP.new()
	var err := u.discover(2000, 2, "InternetGatewayDevice")
	var state := ""
	var ip := ""
	if err != UPNP.UPNP_RESULT_SUCCESS or u.get_gateway() == null or not u.get_gateway().is_valid_gateway():
		state = "The router did not answer. Forward UDP port %d to this computer by hand to be joined from the internet." % p
	else:
		var r := u.add_port_mapping(p, p, "Brelm fellowship", "UDP", 0)
		if r == UPNP.UPNP_RESULT_SUCCESS:
			ip = u.query_external_address()
			state = "The router opened UDP port %d." % p
		else:
			state = "The router refused to open UDP port %d. Forward it to this computer by hand." % p
			u = null
	call_deferred("_upnp_done", u, state, ip)


func _upnp_done(u, state: String, ip: String) -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if not online:
		if u:
			u.delete_port_mapping(port, "UDP")
		return
	_upnp = u
	upnp_state = state
	external_ip = ip
	_announce_t = minf(_announce_t, 0.5)    # tell the list the address the router gave
	_log(state + (" Internet address: %s:%d" % [ip, port] if ip != "" else ""))
	roster_changed.emit()


func _close_port_upnp() -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if _upnp:
		_upnp.delete_port_mapping(port, "UDP")
		_upnp = null


func local_addresses() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


# ------------------------------------------------------------------ upkeep

func _process(delta: float) -> void:
	if _joining:
		_join_t -= delta
		if _join_t <= 0.0:
			last_error = "No answer came. Check the address, and that the host's port is open."
			_log(last_error)
			leave(last_error)
	if _disc:
		while _disc.get_available_packet_count() > 0:
			var pkt := _disc.get_packet().get_string_from_utf8()
			if pkt == "BRELM?" and not private:
				_disc.set_dest_address(_disc.get_packet_ip(), _disc.get_packet_port())
				_disc.put_packet(JSON.stringify(_info()).to_utf8_buffer())
	if _probe:
		while _probe.get_available_packet_count() > 0:
			var raw := _probe.get_packet().get_string_from_utf8()
			var ip := _probe.get_packet_ip()
			var data = JSON.parse_string(raw)
			if data is Dictionary and data.has("port"):
				var key := "%s:%d" % [ip, int(data.port)]
				# The same host answers both the broadcast and the loopback probe; show it once
				var dup := false
				for k in servers:
					if servers[k].get("name") == data.get("name") and int(servers[k].port) == int(data.port) and servers[k].source == "LAN":
						dup = true
				if not dup:
					data["ip"] = ip
					data["source"] = "LAN"
					data["ping"] = Time.get_ticks_msec() - _probe_sent
					servers[key] = data
					servers_changed.emit()
		_probe_t -= delta
		if _probe_t <= 0.0:
			_probe.close()
			_probe = null
	if is_host() and public:
		_announce_t -= delta
		if _announce_t <= 0.0:
			_announce_t = ANNOUNCE_EVERY
			_announce()


func _exit_tree() -> void:
	leave("")
