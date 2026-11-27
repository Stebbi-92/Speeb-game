class_name Tunnel
extends Node
## Co-op through any router. A host behind a router that will not open its port (no UPnP, carrier-grade
## NAT on mobile and some home networks, a router behind a router) cannot be reached straight away. So a
## pilgrim coming by the internet list or a join code meets the host through the lobby (its /meet place),
## and the two make a WebRTC link: it goes straight between them when it can, and by the Cloudflare TURN
## relay when nothing else gets through.
##
## The game itself still speaks ENet, unchanged: the link only carries its packets. On the pilgrim's side
## ENet connects to a port on this machine (127.0.0.1), and its packets go over the link; on the host's side
## each link hands them to the host's own ENet port, from a port of its own. So timeouts, ping and the rest
## of the fellowship's code work as they do on a direct connection.
##
## The data channel is unordered and never resent, as UDP is: ENet keeps its own order and resends.

signal opened(port: int)          ## the pilgrim's link is open: connect ENet to 127.0.0.1:port
signal failed(why: String)        ## the pilgrim's link could not be made
signal log_line(text: String)

const CHANNEL := {"negotiated": true, "id": 1, "ordered": false, "maxRetransmits": 0}
const JOIN_WAIT := 20.0           ## seconds a pilgrim waits for the link before giving up
const HOST_RETRY := 10.0          ## seconds between a host's tries to reach the meeting place again
const STUN_ONLY := [{"urls": ["stun:stun.cloudflare.com:3478"]}]

var role := ""                    ## "host", "join" or "" (idle)
var relay_ready := false          ## the meeting place answered with TURN relay logins (else STUN only)
var _lobby := ""
var _code := ""
var _key := ""
var _ws: WebSocketPeer
var _ws_open := false
var _ws_retry := 0.0
var _ice: Array = []
var _http: HTTPRequest
var _enet_port := 0
## Host: pilgrim id -> {pc, ch, udp, t (seconds since it was made), open}
var _links := {}
## Pilgrim: the one link, and the local port ENet speaks to
var _pc: WebRTCPeerConnection
var _ch: WebRTCDataChannel
var _udp: PacketPeerUDP
var _dest_port := 0
var _join_t := 0.0
var _opened := false
var bytes_up := 0                 ## pilgrim: bytes sent to the host over the link
var bytes_down := 0               ## and received from it
var _queued: Array = []           ## messages to the meeting place written before its socket opened

static var _avail := -1


## Whether WebRTC can be used here (the webrtc_native plugin loaded for this platform).
static func available() -> bool:
	if _avail < 0:
		var pc := WebRTCPeerConnection.new()
		_avail = 1 if pc.initialize({}) == OK else 0
		pc.close()
	return _avail == 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 6.0
	add_child(_http)


func _say(t: String) -> void:
	log_line.emit(t)


# ------------------------------------------------------------------ host

## Waits at the meeting place for pilgrims coming by this fellowship's code. key: a secret of this
## fellowship, so no one else can take its code there. enet_port: the host's own ENet port.
func host_start(lobby: String, code: String, key: String, enet_port: int) -> void:
	stop()
	if not available() or lobby == "" or code == "":
		return
	role = "host"
	_lobby = lobby
	_code = code
	_key = key
	_enet_port = enet_port
	await _fetch_ice()
	if role != "host":
		return
	_connect_ws("/meet/%s/host?key=%s" % [code, key.uri_encode()])


# ------------------------------------------------------------------ pilgrim

## Makes a link to the fellowship with this code; opened(port) or failed(why) follows.
func join_start(lobby: String, code: String) -> void:
	stop()
	if not available():
		failed.emit("WebRTC is not in this build.")
		return
	role = "join"
	_lobby = lobby
	_code = code
	_join_t = JOIN_WAIT
	_opened = false
	await _fetch_ice()
	if role != "join":
		return
	_connect_ws("/meet/%s/join" % code)


## Ends every link and leaves the meeting place.
func stop() -> void:
	role = ""
	if _ws:
		_ws.close()
	_ws = null
	_ws_open = false
	_queued.clear()
	for id in _links:
		_close_link(_links[id])
	_links.clear()
	if _pc:
		_pc.close()
	_pc = null
	_ch = null
	if _udp:
		_udp.close()
	_udp = null
	_dest_port = 0
	_opened = false


# ------------------------------------------------------------------ the meeting place

func _fetch_ice() -> void:
	_ice = STUN_ONLY.duplicate(true)
	relay_ready = false
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	if _http.request(_lobby + "/turn") != OK:
		return
	var r: Array = await _http.request_completed
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		return
	var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if d is Dictionary and d.get("iceServers") is Array and not d.iceServers.is_empty():
		_ice = d.iceServers
		relay_ready = bool(d.get("relay", false))


func _connect_ws(path: String) -> void:
	_ws = WebSocketPeer.new()
	_ws_open = false
	var u := _lobby.replace("https://", "wss://").replace("http://", "ws://") + path
	if _ws.connect_to_url(u) != OK:
		_ws = null
		_ws_retry = HOST_RETRY
		if role == "join":
			_fail("The meeting place could not be reached.")


func _send(m: Dictionary) -> void:
	var t := JSON.stringify(m)
	if _ws and _ws_open:
		_ws.send_text(t)
	else:
		_queued.append(t)


func _poll_ws(delta: float) -> void:
	if _ws == null:
		if role == "host":
			_ws_retry -= delta
			if _ws_retry <= 0.0:
				_connect_ws("/meet/%s/host?key=%s" % [_code, _key.uri_encode()])
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _ws_open:
			_ws_open = true
			for t in _queued:
				_ws.send_text(t)
			_queued.clear()
		while _ws and _ws.get_available_packet_count() > 0:
			var m = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
			if m is Dictionary:
				_on_meet(m)
	elif st == WebSocketPeer.STATE_CLOSED:
		_ws = null
		_ws_open = false
		_ws_retry = HOST_RETRY
		if role == "join" and not _opened:
			_fail("The meeting place closed before the host answered.")


func _on_meet(m: Dictionary) -> void:
	var t := str(m.get("t", ""))
	if role == "host":
		var id := int(m.get("from", 0))
		if id <= 0:
			return
		if t == "offer":
			_host_offer(id, str(m.get("sdp", "")))
		elif t == "cand" and _links.has(id):
			_links[id].pc.add_ice_candidate(str(m.get("m", "")), int(m.get("i", 0)), str(m.get("n", "")))
		elif t == "bye" and _links.has(id) and not _links[id].open:
			# The pilgrim left the meeting. Most often because its end of the link just opened, a moment
			# before this end hears so; if it does not open within ten seconds, it is let go
			_links[id].t = maxf(_links[id].t, 30.0)
	elif role == "join":
		if t == "id":
			if not bool(m.get("host", false)):
				_fail("The host is not at the meeting place.")
				return
			_join_offer()
		elif t == "answer" and _pc:
			_pc.set_remote_description("answer", str(m.get("sdp", "")))
		elif t == "cand" and _pc:
			_pc.add_ice_candidate(str(m.get("m", "")), int(m.get("i", 0)), str(m.get("n", "")))
		elif t == "gone" and not _opened:
			_fail("The host left the meeting place.")


func _new_pc(to: int) -> WebRTCPeerConnection:
	var pc := WebRTCPeerConnection.new()
	if pc.initialize({"iceServers": _ice}) != OK:
		return null
	pc.session_description_created.connect(func(type: String, sdp: String):
		pc.set_local_description(type, sdp)
		var m := {"t": type, "sdp": sdp}
		if to > 0:
			m["to"] = to
		_send(m))
	pc.ice_candidate_created.connect(func(media: String, index: int, cname: String):
		var m := {"t": "cand", "m": media, "i": index, "n": cname}
		if to > 0:
			m["to"] = to
		_send(m))
	return pc


func _host_offer(id: int, sdp: String) -> void:
	if _links.has(id) or _links.size() >= 16 or sdp == "":
		return
	var pc := _new_pc(id)
	if pc == null:
		return
	var ch := pc.create_data_channel("enet", CHANNEL)
	if ch == null:
		pc.close()
		return
	ch.write_mode = WebRTCDataChannel.WRITE_MODE_BINARY
	_links[id] = {"pc": pc, "ch": ch, "udp": null, "t": 0.0, "open": false}
	pc.set_remote_description("offer", sdp)   # the answer is made at once, and sent by _new_pc
	_say("A pilgrim is coming in by the meeting place.")


func _join_offer() -> void:
	_pc = _new_pc(0)
	if _pc == null:
		_fail("WebRTC could not start.")
		return
	_ch = _pc.create_data_channel("enet", CHANNEL)
	if _ch == null:
		_fail("WebRTC could not start.")
		return
	_ch.write_mode = WebRTCDataChannel.WRITE_MODE_BINARY
	_pc.create_offer()


func _fail(why: String) -> void:
	var was := role == "join"
	stop()
	if was:
		failed.emit(why)


func _close_link(l: Dictionary) -> void:
	if l.udp:
		l.udp.close()
	if l.pc:
		l.pc.close()


# ------------------------------------------------------------------ carrying the packets

func _process(delta: float) -> void:
	if role == "":
		return
	_poll_ws(delta)
	_pump()
	if role == "host":
		for id in _links.keys():
			var l: Dictionary = _links[id]
			l.t += delta
			var st: int = l.pc.get_connection_state()
			if st == WebRTCPeerConnection.STATE_FAILED or st == WebRTCPeerConnection.STATE_CLOSED or (not l.open and l.t > 40.0):
				_close_link(l)
				_links.erase(id)
	elif role == "join":
		if not _opened:
			_join_t -= delta
			if _join_t <= 0.0:
				_fail("No way through to the host was found.")
				return
		elif _pc and _pc.get_connection_state() == WebRTCPeerConnection.STATE_FAILED:
			_say("The link to the host broke.")


func _physics_process(_delta: float) -> void:
	# Twice a frame at most: packets wait less between the link and ENet
	if role != "":
		_pump()


func _pump() -> void:
	if role == "host":
		for id in _links:
			var l: Dictionary = _links[id]
			l.pc.poll()
			if l.ch.get_ready_state() != WebRTCDataChannel.STATE_OPEN:
				continue
			if not l.open:
				l.open = true
				var u := PacketPeerUDP.new()
				u.bind(0, "127.0.0.1")
				u.set_dest_address("127.0.0.1", _enet_port)
				l.udp = u
				_say("A pilgrim's link opened.")
			while l.ch.get_available_packet_count() > 0:
				l.udp.put_packet(l.ch.get_packet())
			while l.udp.get_available_packet_count() > 0:
				l.ch.put_packet(l.udp.get_packet())
	elif role == "join" and _pc:
		_pc.poll()
		if _ch == null or _ch.get_ready_state() != WebRTCDataChannel.STATE_OPEN:
			return
		if not _opened:
			_opened = true
			_udp = PacketPeerUDP.new()
			if _udp.bind(0, "127.0.0.1") != OK:
				_fail("No port on this machine was free.")
				return
			# The meeting is over once the link is open
			if _ws:
				_ws.close()
			_ws = null
			_say("The link to the host opened.")
			opened.emit(_udp.get_local_port())
		while _udp and _udp.get_available_packet_count() > 0:
			var p := _udp.get_packet()
			bytes_up += p.size()
			if _dest_port == 0:
				_dest_port = _udp.get_packet_port()
				_udp.set_dest_address("127.0.0.1", _dest_port)
			_ch.put_packet(p)
		while _ch and _ch.get_available_packet_count() > 0:
			var p := _ch.get_packet()
			bytes_down += p.size()
			if _dest_port != 0:
				_udp.put_packet(p)


## Testing aid: how many links a host holds open.
func open_links() -> int:
	var n := 0
	for id in _links:
		n += 1 if _links[id].open else 0
	return n
