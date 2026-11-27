extends Node
## The fellowship: up to eight pilgrims in the Ashen Waste, or four in the trials.
## One of them hosts (or a dedicated server does, with no pilgrim of its own), and the host is the authority:
## it runs the lesser forms, orders every shared step of a trial, and decides when a land begins.
## Others join by address or from the list of fellowships (found on the local network, or on the internet list).

signal roster_changed
signal status_changed(text: String)
signal servers_changed
signal session_ended(reason: String)
## The dedicated server's state changed: paused or running, saved, a player came or went, a world was loaded.
signal server_state_changed

const DEFAULT_PORT := 24600
const DISCOVERY_PORT := 24601
const MAX_PLAYERS := 8        ## the Ashen Waste
const MAX_TRIALS := 4         ## the trials were made for four
const PROTOCOL := "brelm-fellowship-5"
const ANNOUNCE_EVERY := 50.0
## The internet list of fellowships: a small Cloudflare Worker (see tools/lobby-worker.js).
## Leave empty to use only the local network and joining by address; it can also be set in Options.
const DEFAULT_LOBBY := "https://game.speeb.org"
const SLOT_COLORS := [Color(0.82, 0.78, 0.7), Color(0.85, 0.62, 0.3), Color(0.45, 0.6, 0.85), Color(0.5, 0.75, 0.5),
	Color(0.8, 0.42, 0.4), Color(0.7, 0.55, 0.85), Color(0.4, 0.78, 0.78), Color(0.9, 0.8, 0.4)]
const SLOT_NAMES := ["Ash", "Ochre", "Slate", "Moss", "Rust", "Heather", "Tide", "Straw"]

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
## The way through any router (scripts/tunnel.gd): a host waits at the lobby's meeting place, and a pilgrim
## from the internet list or a join code comes in by a WebRTC link when one can be made.
var tunnel: Tunnel
var _host_key := ""         ## this fellowship's secret at the meeting place
var _relay_to := {}         ## the listed fellowship a pilgrim is linking to (joined straight if the link fails)
var _keep_tunnel := false
var via_link := false       ## this pilgrim came in by a WebRTC link (not straight to the host's address)
var debug_code := ""        ## (for the tests: the join code a host takes, instead of a random one)
var debug_link := "linkonly" in OS.get_cmdline_user_args()   ## (for the tests: link even to a host on this network)

## The dedicated server's persistent world (see "the dedicated server's world" below).
var persist := false          ## the server keeps one open world running, instead of waiting in the gathering
var world_paused := false     ## the world is stopped because no one is here (or the server was told to stop it)
var world_name := ""          ## the save slot of the server's world
var world_seed := 0           ## the seed for a world not yet made (0: chosen at random)
var autosave_min := 5         ## minutes between the server's saves while the world runs (0: only on leaving and quitting)
var pause_when_empty := true
var pause_override := 0       ## 0 pause when empty, 1 always run, 2 always paused
var max_players := MAX_PLAYERS
var last_save_unix := 0
var server_stopping := false  ## the server's window or console saved the world and is ending it: no more saves
var _world_up := false        ## the server's world is raised and ready
var _started_unix := 0
var _old_level := 0           ## the land being left when the server's world is raised again
var _run_fps := 60            ## the frame cap while the world runs; kept low while it is paused
const PAUSED_FPS := 5             ## the frame cap while paused, headless (joins are still heard at once)
const PAUSED_FPS_WINDOW := 10     ## and with the server's window open, so it still answers the hand
const BANS_PATH := "user://server_bans.json"
var bans := {"names": [], "ips": []}
var _saves := 0               ## how many saves have been written (to tell whether one just was)
var _save_ok := false


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
	tunnel = Tunnel.new()
	add_child(tunnel)
	tunnel.opened.connect(_on_tunnel_open)
	tunnel.failed.connect(_on_tunnel_failed)
	tunnel.log_line.connect(_log)
	if "status_log" in OS.get_cmdline_user_args():   # (for the tests: the server says its state each time it changes)
		server_state_changed.connect(func(): print("STATUS ", JSON.stringify(server_status())))
	if "api_test" in OS.get_cmdline_user_args():
		_debug_api.call_deferred()


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
	return players[id].name if players.has(id) else "A player"


## How many may walk now: eight in the waste and the gathering, four in a trial.
func cap() -> int:
	var n := MAX_TRIALS if in_level >= 0 and in_level != Game.WASTELAND else MAX_PLAYERS
	return mini(n, max_players) if dedicated else n


func slot_of(id: int) -> int:
	return int(players[id].slot) if players.has(id) else 0


func color_of(id: int) -> Color:
	return SLOT_COLORS[slot_of(id) % SLOT_COLORS.size()]


## Everyone who walks the land, by peer id. The dedicated server is not among them.
func pilgrims() -> Array:
	return players.keys()


func _log(t: String) -> void:
	if dedicated or Engine.is_editor_hint() or debug_link:
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
	if debug_code != "":
		join_code = debug_code
	seq = 0
	in_level = -1
	players.clear()
	if not headless:
		players[1] = {"name": my_name(), "slot": 0, "look": Game.look.duplicate()}
	leader = 0 if headless else 1
	_open_discovery()
	_open_port_upnp()
	if public:
		_host_key = "%x%x" % [randi(), randi()]
		tunnel.host_start(lobby_url(), join_code, _host_key, p)
	_announce_t = 2.0
	if headless:
		_started_unix = int(Time.get_unix_time_from_system())
		_load_bans()
	roster_changed.emit()
	_log("Hosting \"%s\" on port %d." % [sname, p])
	return OK


func join(address: String, p: int, by_link := false) -> Error:
	_keep_tunnel = by_link
	leave("")
	_keep_tunnel = false
	via_link = by_link
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, p)
	if err != OK:
		last_error = "Could not reach %s:%d." % [address, p]
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	_joining = true
	_join_t = 8.0
	_log("Seeking the fellowship at %s:%d..." % [address, p] if not by_link else "Seeking the fellowship over the link...")
	return OK


## Joins a fellowship from the internet list or found by its code: by a WebRTC link through the lobby's
## meeting place when the host waits there (this gets through any router), else straight to its address.
func join_listed(d: Dictionary) -> void:
	if not _should_link(d):
		join(str(d.get("ip", "")), int(d.get("port", DEFAULT_PORT)))
		return
	leave("")
	_relay_to = d.duplicate()
	tunnel.join_start(lobby_url(), str(d.code))
	_joining = true
	_join_t = Tunnel.JOIN_WAIT + 12.0
	_log("Finding a way through to %s..." % str(d.get("name", "the fellowship")))


func _should_link(d: Dictionary) -> bool:
	return bool(d.get("relay", false)) and str(d.get("code", "")) != "" and lobby_url() != "" \
		and str(d.get("source", "Internet")) != "LAN" and (debug_link or not bool(d.get("same", false))) and Tunnel.available()


func _on_tunnel_open(local_port: int) -> void:
	_relay_to = {}
	join("127.0.0.1", local_port, true)


func _on_tunnel_failed(why: String) -> void:
	var d := _relay_to
	_relay_to = {}
	if d.is_empty() or not _joining:
		return
	_log("%s Trying its address instead." % why)
	join(best_address(d), int(d.get("port", DEFAULT_PORT)))


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
	var was := online or _joining or peer != null   # refused while still knocking counts too, so the reason is shown
	if is_host():
		_announce_remove()
	_close_port_upnp()
	if not _keep_tunnel:
		tunnel.stop()
		_relay_to = {}
		via_link = false
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
	if persist:
		_set_paused(false)
		persist = false
		_world_up = false
	if was:
		roster_changed.emit()
		session_ended.emit(reason)
	if debug_end_quit and was:
		print("NETENDED %s" % reason)
		get_tree().quit()


var debug_end_quit := "call=debug_kickclient" in OS.get_cmdline_user_args()   ## (for the tests: a joiner that is sent away says why, and stops)


## The land takes a while to raise when a pilgrim first walks into it, and nothing else moves meanwhile.
## Give each link a long patience so a fellowship is not broken while the waste is being made.
func _patient(id: int) -> void:
	if peer and peer.get_peer(id):
		peer.get_peer(id).set_timeout(32, 90000, 180000)
		brisk_links.erase(id)


## Once the land is raised on both ends, a link that goes quiet is a crash: drop it in seconds, not minutes.
var brisk_links := {}   ## the links made brisk (for the tests)
func _brisk(id: int) -> void:
	if peer and peer.get_peer(id):
		peer.get_peer(id).set_timeout(32, 8000, 20000)
		brisk_links[id] = true



## A new land is being raised: every link waits patiently again until the land is ready.
func loading() -> void:
	if not online or peer == null:
		return
	if is_host():
		for id in multiplayer.get_peers():
			_patient(id)
	else:
		_patient(1)


## This machine's land is ready. A joiner tells the host, and both ends of its link grow brisk.
func settled() -> void:
	if not online or peer == null or is_host():
		return
	_brisk(1)
	_settled_peer.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _settled_peer() -> void:
	if is_host():
		_brisk(multiplayer.get_remote_sender_id())


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
		if persist:
			server_state_changed.emit()
			if players.is_empty():
				# The last one has gone: keep the world as it is now, then let it rest
				if server_save_now():
					_log("The last player left. The world is saved.")
				_apply_pause()
	# A dedicated server with no one left returns to waiting (a persistent world only rests)
	if dedicated and not persist and players.is_empty() and in_level >= 0:
		in_level = -1
		seq += 1
		Game.main.server_idle()


@rpc("any_peer", "call_remote", "reliable")
func _hello(pname: String, proto: String, version: String, word := "") -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	var mine := str(ProjectSettings.get_setting("application/config/version", ""))
	if proto != PROTOCOL or (version != mine and version != "" and mine != ""):
		# Builds that differ disagree on items, foes and the world, even when the wire looks the same
		_refused.rpc_id(id, "This fellowship walks Brelm %s, and you have %s. Update to join (the menu offers it)." % [mine, version])
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
	if slot >= cap() or players.size() >= cap():   # count heads, not the first free place: one may have left from the middle
		_refused.rpc_id(id, "The fellowship is full." if slot >= MAX_PLAYERS else "This fellowship walks a trial, and the trials take four at most. Join when they are back in the waste or the gathering.")
		get_tree().create_timer(0.5).timeout.connect(func(): if peer: peer.disconnect_peer(id))
		return
	pname = pname.strip_edges().left(20)
	if pname == "":
		pname = "Pilgrim"
	if dedicated:
		_load_bans()   # read again at each knock, so the file may be edited by hand while the server runs
	if sent_away.has(pname.to_lower()) or (dedicated and is_banned(pname, _address_of(id))):
		_refused.rpc_id(id, "The host has sent you away from this fellowship.")
		get_tree().create_timer(0.5).timeout.connect(func(): if peer: peer.disconnect_peer(id))
		return
	players[id] = {"name": pname, "slot": slot}
	if leader == 0:
		leader = id
	_log("%s has joined the fellowship." % pname)
	if persist:
		_apply_pause()   # someone is here: the world wakes before their world is sent them
		server_state_changed.emit()
	_roster.rpc(players, leader)
	roster_changed.emit()
	_welcome.rpc_id(id, server_name, Game.difficulty)
	_rules.rpc_id(id, Game.unlimited_ammo)
	if in_level >= 0:
		_begin.rpc_id(id, in_level, seq, Game.difficulty)
	var lvl = _level()
	if lvl:
		lvl.net_joined(id)


## Names the host has sent away, kept until the host's game closes: they cannot come back under it.
var sent_away := {}

## Host: sends a pilgrim out of the fellowship, and keeps them out for this session.
func kick(id: int) -> void:
	_send_away(id, "The host has sent you away from this fellowship.", true)


## Sends a pilgrim out with the reason given; kept out for this session if keep_out.
func _send_away(id: int, reason: String, keep_out: bool) -> void:
	if not is_host() or id == 1 or not players.has(id):
		return
	var nm := str(players[id].name)
	if keep_out:
		sent_away[nm.to_lower()] = true
	_log("%s was sent away by the host." % nm)
	_refused.rpc_id(id, reason)
	_on_peer_disconnected(id)   # out of the fellowship now: nothing more they ask is heard
	# The word goes behind whatever is still being sent them, so give it time to arrive before the link is cut
	get_tree().create_timer(3.0).timeout.connect(func(): if peer and peer.get_peer(id): peer.disconnect_peer(id))


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
	if Game.wasteland and Game.wrules.has("ammo"):
		return int(Game.wrules.ammo) == 1
	return host_unlimited if online and not multiplayer.is_server() else Game.unlimited_ammo


func send_rules() -> void:
	if online and multiplayer.is_server():
		_rules.rpc(Game.unlimited_ammo)


@rpc("authority", "call_remote", "reliable")
func _rules(unlimited: bool) -> void:
	host_unlimited = unlimited


@rpc("authority", "call_remote", "reliable")
func _roster(p: Dictionary, lead: int) -> void:
	# One who has left is taken out of the world here too, not left standing until they fall silent
	var lvl = _level()
	if lvl and lvl.has_method("net_left"):
		for id in players.keys():
			if not p.has(id) and id != me():
				lvl.net_left(id)
	players = p
	leader = lead
	roster_changed.emit()


## May this pilgrim choose the trial? The host may, and on a dedicated server the first to arrive.
func may_choose() -> bool:
	return online and (multiplayer.is_server() or leader == me())


# ------------------------------------------------------------------ lands

## The host begins a land for the whole fellowship.
func begin(i: int) -> void:
	if online and i != Game.WASTELAND and players.size() > MAX_TRIALS:
		_log("The trials take four at most. With more, walk the Ashen Waste.")
		return
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
		if persist:
			return   # the server's world goes on; no one may begin another land in its place
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
	if not is_host() or not _here(s) or not method.begins_with("_"):
		return
	var from := multiplayer.get_remote_sender_id()
	if not players.has(from):
		return   # not yet one of the fellowship (it has not said hello, or was refused)
	if not CALL_PREFIXES.any(func(p): return method.begins_with(p)):
		return   # only the land's shared doings, never its inner workings
	if method in HOST_ONLY:
		return   # what only the host may say: the world itself, its rules, its ending, and gifts to one pilgrim
	# A request names who asks ("by"): it is always the one who sent it, whatever it says
	if args.size() > 0 and args[0] is int and _takes_by(_here(s), method):
		args[0] = from
	_call.rpc(s, method, args)


## The shared doings a joiner may ask of the land, by the start of their names.
const CALL_PREFIXES := ["_rq_", "_w_", "_drop", "_sworn", "_part_", "_final", "_broken"]
## Shared doings that only ever come from the host. A joiner asking for one (a changed or hostile copy of
## the game) is refused, so it cannot replace the world, change its rules, end it, or hand out goods.
const HOST_ONLY := ["_w_snapshot", "_w_snap_part", "_w_rules", "_w_ending", "_w_end_votes", "_w_give", "_w_gift", "_w_parried"]
static var _by_cache := {}

## Whether a land's method takes the asker's id as its first word.
func _takes_by(lvl, method: String) -> bool:
	if lvl == null:
		return false
	var key := "%s:%s" % [lvl.get_script().resource_path if lvl.get_script() else "", method]
	if not _by_cache.has(key):
		var yes := false
		for m in lvl.get_method_list():
			if m.name == method:
				yes = not m.args.is_empty() and str(m.args[0].name) == "by"
				break
		_by_cache[key] = yes
	return _by_cache[key]


@rpc("authority", "call_local", "reliable")
func _call(s: int, method: String, args: Array) -> void:
	var lvl = _here(s)
	if lvl and lvl.has_method(method) and not _held(lvl, method, args):
		lvl.callv(method, args)


## While a newcomer's world is still arriving, what happens in it waits, and is played after.
func _held(lvl, method: String, args: Array) -> bool:
	if lvl.get("snap_wait") == true and method != "_rq_hello":
		lvl.snap_queue.append([method, args])
		return true
	return false


## The whole world for one newcomer: packed small, and sent in parts on a lane of its own, so the
## fellowship's own doings are not held up behind it.
const SNAP_PART := 32768
const SNAP_LANE := 2


func send_snapshot(id: int, d: Dictionary) -> void:
	var raw := var_to_bytes(d)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var n := maxi(1, ceili(packed.size() / float(SNAP_PART)))
	if not online or id == me():
		var lvl = _level()
		for i in n:
			lvl._w_snap_part(i, n, raw.size(), packed.slice(i * SNAP_PART, mini((i + 1) * SNAP_PART, packed.size())))
		return
	for i in n:
		_snap_part.rpc_id(id, seq, i, n, raw.size(), packed.slice(i * SNAP_PART, mini((i + 1) * SNAP_PART, packed.size())))


@rpc("authority", "call_remote", "reliable", 2)
func _snap_part(s: int, i: int, n: int, raw: int, part: PackedByteArray) -> void:
	var lvl = _here(s)
	if lvl and lvl.has_method("_w_snap_part"):
		lvl._w_snap_part(i, n, raw, part)


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
	if lvl and method.begins_with("_") and lvl.has_method(method) and not _held(lvl, method, args):
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


var heard := {}   ## peer id -> when (msec) we last heard anything from them: a pose or a beat


## The host's pulse, once a second, so the others can tell a quiet host from a gone one.
func beat() -> void:
	_beat.rpc()


@rpc("authority", "call_remote", "unreliable")
func _beat() -> void:
	heard[1] = Time.get_ticks_msec()


## How long since this peer was last heard from, in seconds (0 if never asked about).
func silent_for(id: int) -> float:
	return (Time.get_ticks_msec() - int(heard.get(id, Time.get_ticks_msec()))) / 1000.0


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _pose(s: int, data: Array) -> void:
	heard[multiplayer.get_remote_sender_id()] = Time.get_ticks_msec()
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


func send_foes_to(peer_id: int, batch: Array) -> void:
	if multiplayer.multiplayer_peer and peer_id in multiplayer.get_peers():
		_foes.rpc_id(peer_id, seq, batch)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _foes(s: int, batch: Array) -> void:
	heard[1] = Time.get_ticks_msec()
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


func hit(id: int, amount: float, dir: Vector3, kind := "", head := false, pierce := 1.0, heavy := false) -> void:
	_hit.rpc_id(1, seq, id, amount, dir, kind, head, pierce, heavy)


## A pilgrim's blow on a form, with what kind of harm it was, so the host weighs plate, guard,
## weakness and stagger just as it would for its own.
@rpc("any_peer", "call_remote", "reliable")
func _hit(s: int, id: int, amount: float, dir: Vector3, kind := "", head := false, pierce := 1.0, heavy := false) -> void:
	var lvl = _here(s)
	if lvl and is_host() and players.has(multiplayer.get_remote_sender_id()):
		lvl.net_hit(multiplayer.get_remote_sender_id(), id, clampf(amount, 0.0, 5000.0), dir, kind, head, clampf(pierce, 0.0, 3.0), heavy)


func bolt(from: Vector3, vel: Vector3, dmg: float, look := "") -> void:
	_bolt.rpc(seq, from, vel, dmg, look)


@rpc("authority", "call_remote", "reliable")
func _bolt(s: int, from: Vector3, vel: Vector3, dmg: float, look: String) -> void:
	var lvl = _here(s)
	if lvl:
		lvl.net_bolt(from, vel, dmg, look)


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
	return {"name": server_name, "port": port, "players": players.size(), "max": cap(),
		"level": in_level, "proto": PROTOCOL, "version": str(ProjectSettings.get_setting("application/config/version", "")),
		"code": join_code, "private": not listed_public, "locked": password != "", "detail": _detail(),
		"ip4": external_ip, "lan": local_addresses(), "relay": tunnel.role == "host"}


## A line on how far the fellowship has come, for the list (the waste: its day and its fires).
func _detail() -> String:
	var lvl = _level()
	if lvl and lvl.has_method("lobby_detail"):
		return str(lvl.lobby_detail()).left(60)
	return ""


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
	var mine := str(ProjectSettings.get_setting("application/config/version", ""))
	if str(data.get("proto", PROTOCOL)) != PROTOCOL or (str(data.get("version", mine)) != mine and str(data.get("version", "")) != ""):
		last_error = "That fellowship walks Brelm %s, and you have %s. Update to join." % [data.get("version", "?"), mine]
		_log(last_error)
		return
	data["source"] = "Internet"
	data["ip"] = best_address(data)
	join_listed(data)


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
	if _upnp_thread:
		_upnp_thread.wait_to_finish()   # an earlier ask, left running when that fellowship ended
		_upnp_thread = null
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
	if _upnp_thread and _upnp_thread.is_alive():
		# Still asking the router (it can take seconds): do not wait for it here. When it answers,
		# _upnp_done sees we are no longer hosting and closes what it opened.
		return
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


# ------------------------------------------------------------------ the dedicated server's world

## A world name made safe for a file name: letters, digits, - and _ only.
static func clean_world_name(n: String) -> String:
	var out := ""
	for c in n.strip_edges().left(32):
		out += c if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "-" or c == "_" else "_"
	return out if out != "" else "1"


## Where a world of the waste is kept (as Wasteland.world_path; named here so this autoload need not load the waste).
static func world_file(wname: String) -> String:
	return "user://wasteland/world_%s.dat" % wname


## Dedicated server: raises its own world at once and keeps it running, whoever is here.
func world_start(wname: String, sd := 0) -> void:
	persist = true
	world_name = clean_world_name(wname)
	world_seed = sd
	_begin_world()


## Raises (or raises again) the server's world from its save. Everyone here comes along.
func _begin_world() -> void:
	if not dedicated or not persist:
		return
	_set_paused(false)   # a land is raised only while the tree runs
	_world_up = false
	_old_level = Game.main.level.get_instance_id() if Game.main and is_instance_valid(Game.main.level) else 0
	Game.world_slot = world_name
	Game.new_world_seed = world_seed
	var had := FileAccess.file_exists(world_file(world_name))
	_log(("Loading the world \"%s\"..." if had else "Making a new world \"%s\"...") % world_name)
	begin(Game.WASTELAND)
	server_state_changed.emit()


## Watches for the server's world being ready, then keeps it (a new one is written at once) and
## lets it rest if no one is here.
func _world_watch() -> void:
	if not persist or _world_up:
		return
	var lvl = _level()
	if lvl == null or lvl.get("ready_world") != true or lvl.get_instance_id() == _old_level:
		return   # not raised yet (the world being left still stands until the new one takes its place)
	_world_up = true
	lvl._save_t = lvl._save_every()
	server_save_now()
	_log("The world \"%s\" is ready. %s" % [world_name, _when()])
	_apply_pause()
	server_state_changed.emit()


## The day and hour of the server's world, for the log.
func _when() -> String:
	var lvl = _level()
	if lvl == null or lvl.get("clock") == null:
		return ""
	var c: float = lvl.clock
	return "Day %d, %02d:%02d." % [int(lvl.day), int(c), int(fmod(c, 1.0) * 60.0)]


## Whether the world should stand still now.
func _want_pause() -> bool:
	if pause_override == 2:
		return true
	return pause_override == 0 and pause_when_empty and players.is_empty()


## Stops or starts the world to match who is here and what the server was told.
func _apply_pause() -> void:
	if not persist or not _world_up:
		return
	var want := _want_pause()
	if want == world_paused:
		return
	_set_paused(want)
	if want:
		_log("The world is paused%s. %s" % [" (no players)" if players.is_empty() else "", _when()])
	else:
		_log("The world runs again. %s" % _when())
	server_state_changed.emit()


## The whole scene stops (time, foes, the watch, growth, nights, timers that belong to it); this node
## and the network go on, so joins are heard and the internet list still hears from the server.
func _set_paused(on: bool) -> void:
	if on == world_paused:
		return
	world_paused = on
	if on:
		_run_fps = Engine.max_fps
		Engine.max_fps = PAUSED_FPS if DisplayServer.get_name() == "headless" else PAUSED_FPS_WINDOW
	else:
		Engine.max_fps = _run_fps
	get_tree().paused = on


## A save was written by the world (called from the waste on the server).
func world_saved(ok: bool) -> void:
	_saves += 1
	_save_ok = ok
	if ok:
		last_save_unix = int(Time.get_unix_time_from_system())
	else:
		_log("The world could not be saved. Is the disk full?")
	server_state_changed.emit()


func _address_of(id: int) -> String:
	if peer and peer.get_peer(id):
		var a := peer.get_peer(id).get_remote_address()
		# One come in by a link shows as this machine: no address of theirs to keep (or ban)
		return "" if a == "127.0.0.1" or a == "::1" else a
	return ""


func _load_bans() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(BANS_PATH)) if FileAccess.file_exists(BANS_PATH) else null
	bans = {"names": [], "ips": []}
	if d is Dictionary:
		for k in ["names", "ips"]:
			if d.get(k) is Array:
				for v in d[k]:
					bans[k].append(str(v))


func _save_bans() -> void:
	Game.write_safe(ProjectSettings.globalize_path(BANS_PATH), JSON.stringify(bans, "\t"))


func is_banned(pname: String, ip: String) -> bool:
	return pname.to_lower() in bans.names or (ip != "" and ip in bans.ips)


# ------------------------------------------------------------------ the server's window and its commands

## All the server window shows, in one place.
func server_status() -> Dictionary:
	var list := []
	for id in players:
		var row := {"id": int(id), "name": str(players[id].name)}
		if peer and peer.get_peer(id):
			row["ping"] = int(peer.get_peer(id).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		list.append(row)
	var lvl = _level()
	return {"name": server_name, "port": port, "players": list, "max_players": cap(), "paused": world_paused,
		"world": world_name if persist else "", "level": in_level,
		"uptime_s": int(Time.get_unix_time_from_system()) - _started_unix if _started_unix > 0 else 0,
		"last_save_unix": last_save_unix, "listed": listed_public,
		"version": str(ProjectSettings.get_setting("application/config/version", "")), "difficulty": Game.difficulty,
		"persist": persist, "ready": _world_up, "pause_override": pause_override, "pause_when_empty": pause_when_empty,
		"autosave_min": autosave_min, "code": join_code, "locked": password != "", "detail": _detail() if lvl else ""}


## Writes the world now. True if it was written.
func server_save_now() -> bool:
	var lvl = _level()
	if lvl == null or not lvl.has_method("save_all") or lvl.get("ready_world") != true:
		return false
	var n := _saves
	lvl.save_all()
	return _saves > n and _save_ok


func server_kick(id: int, reason := "") -> void:
	if not players.has(id):
		return
	_send_away(id, reason if reason != "" else "The server has sent you away. You may come back.", false)


## Sends a player away and keeps them out, by name and by address, for good (user://server_bans.json).
func server_ban(id: int) -> void:
	if not players.has(id):
		return
	var nm := str(players[id].name).to_lower()
	var ip := _address_of(id)
	if not nm in bans.names:
		bans.names.append(nm)
	if ip != "" and not ip in bans.ips:
		bans.ips.append(ip)
	_save_bans()
	_log("%s is banned from this server%s." % [players[id].name, " (address %s)" % ip if ip != "" else ""])
	_send_away(id, "The host has sent you away from this fellowship.", true)


## A word from the server, shown to every player.
func server_say(text: String) -> void:
	text = text.strip_edges().left(200)
	if text == "" or not is_host():
		return
	_server_word.rpc(text)
	_log("Server: %s" % text)


@rpc("authority", "call_remote", "reliable")
func _server_word(text: String) -> void:
	if Game.main and Game.main.hud:
		Game.main.hud.notify("%s: %s" % [server_name if server_name != "" else "The server", text])


## 0: pause when no one is here, 1: always run, 2: stay paused.
func server_set_paused_override(mode: int) -> void:
	pause_override = clampi(mode, 0, 2)
	_log(["The world pauses when no one is here.", "The world runs even with no one here.", "The world is held paused."][pause_override])
	_apply_pause()
	server_state_changed.emit()


## Makes a new world under a new name and moves everyone into it. The world now running is saved first.
func server_new_world(wname: String, sd := 0) -> void:
	var n := clean_world_name(wname)
	if FileAccess.file_exists(world_file(n)):
		_log("A world named \"%s\" is already kept. Load it, or choose another name." % n)
		return
	server_save_now()
	world_name = n
	world_seed = sd
	persist = true
	_begin_world()


## Loads a kept world and moves everyone into it. The world now running is saved first.
func server_load_world(wname: String) -> void:
	var n := clean_world_name(wname)
	if not FileAccess.file_exists(world_file(n)):
		_log("No world named \"%s\" is kept here." % n)
		return
	server_save_now()
	world_name = n
	persist = true
	_begin_world()


## The names of the worlds kept on this server, by name.
func server_list_worlds() -> Array:
	var out := []
	for f in DirAccess.get_files_at("user://wasteland"):
		if f.begins_with("world_") and f.ends_with(".dat"):
			out.append(f.trim_prefix("world_").trim_suffix(".dat"))
	out.sort()
	return out


## A short line about a kept world (its day, its fires, its seed), or "" if there is none.
func server_world_detail(wname: String) -> String:
	return load("res://world/wasteland.gd").describe(clean_world_name(wname))


## Saves the world and raises it again from its save (players are brought back into it).
func server_restart_world() -> void:
	if not persist:
		world_start(Game.world_slot)
		return
	server_save_now()
	_log("Restarting the world...")
	_begin_world()


## Changes a setting of the server while it runs. Returns a line saying what was done.
func server_set_option(key: String, value) -> String:
	var said := ""
	match key:
		"name":
			server_name = str(value).strip_edges().left(40)
			_announce_t = 0.5
			said = "The server is now called \"%s\"." % server_name
		"listed":
			listed_public = bool(value)
			private = false
			_announce_t = 0.5
			said = "The server is %s the internet list." % ("shown in" if listed_public else "hidden from")
		"password":
			password = str(value).strip_edges()
			said = "Joining now needs a word." if password != "" else "Joining needs no word now."
		"max_players":
			max_players = clampi(int(value), 1, MAX_PLAYERS)
			said = "At most %d players may join (those here now stay)." % max_players
		"difficulty":
			Game.difficulty = clampi(int(value), 0, 2)
			_difficulty.rpc(Game.difficulty)
			said = "Difficulty is now %s." % ["Pilgrim", "Hermit", "Unblinking"][Game.difficulty]
		"autosave_min":
			autosave_min = maxi(0, int(value))
			var lvl = _level()
			if lvl and lvl.get("_save_t") != null:
				lvl._save_t = lvl._save_every()
			said = "The world is saved every %d minutes." % autosave_min if autosave_min > 0 else "The world is saved only when the last player leaves and when the server stops."
		"pause_when_empty":
			pause_when_empty = bool(value)
			_apply_pause()
			said = "The world pauses when no one is here." if pause_when_empty else "The world runs even with no one here."
		_:
			said = "There is no server setting called \"%s\"." % key
	_log(said)
	server_state_changed.emit()
	return said


## Testing aid: the server window's commands, each tried on a running server, then it stops.
func _debug_api() -> void:
	var wait_up := func():
		var t0 := Time.get_ticks_msec()
		while not _world_up and Time.get_ticks_msec() - t0 < 120000:
			await get_tree().process_frame
	while not _world_up:
		await get_tree().process_frame
	var first := world_name
	var paused0 := world_paused
	server_set_paused_override(1)
	var ran := not world_paused
	server_set_paused_override(2)
	var held := world_paused
	server_set_paused_override(0)
	var back := world_paused == paused0
	server_set_option("name", "Renamed hall")
	server_set_option("max_players", 3)
	server_set_option("listed", false)
	server_set_option("password", "ash")
	server_set_option("difficulty", 2)
	server_set_option("autosave_min", 7)
	server_set_option("pause_when_empty", true)
	var st := server_status()
	var opts: bool = st.name == "Renamed hall" and st.max_players == 3 and not st.listed and st.difficulty == 2 and st.autosave_min == 7 and password == "ash"
	server_set_option("password", "")
	var saved := server_save_now()
	server_say("Hello, waste.")
	server_new_world("second", 99)
	await get_tree().process_frame
	await wait_up.call()
	var made: bool = world_name == "second" and FileAccess.file_exists(world_file("second")) and world_paused
	var listed := server_list_worlds()
	server_new_world(first)   # already kept: refused
	var refused := world_name == "second"
	server_load_world(first)
	await get_tree().process_frame
	await wait_up.call()
	var loaded := world_name == first and world_paused
	server_restart_world()
	await get_tree().process_frame
	await wait_up.call()
	var restarted := world_name == first and _world_up
	print("SERVERAPI override=%s,%s,%s options=%s saved=%s made=%s worlds=%s refused=%s loaded=%s restarted=%s detail=%s" % [ran, held, back, opts, saved, made,
		",".join(listed), refused, loaded, restarted, server_world_detail("second") != ""])
	get_tree().quit()


@rpc("authority", "call_remote", "reliable")
func _difficulty(d: int) -> void:
	Game.difficulty = d


func _notification(what: int) -> void:
	# A server with its window (scripts/server_admin.gd) saves once as it stops; this is for one without
	if what == NOTIFICATION_WM_CLOSE_REQUEST and persist and not server_stopping and not (Game.main and Game.main.get("admin")) and server_save_now():
		_log("The world is saved. The server stops.")


# ------------------------------------------------------------------ upkeep

func _process(delta: float) -> void:
	_world_watch()
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
	if _upnp_thread:
		_upnp_thread.wait_to_finish()   # quitting: a thread must be waited for, however long the router takes
		_upnp_thread = null
