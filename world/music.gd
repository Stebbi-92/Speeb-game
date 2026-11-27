class_name WMusic
extends Node
## The waste's one music director. It picks a piece for the moment, crossfades into it, and keeps
## quiet for a while between the gentle pieces, so the music is felt more than heard. Fights, great ones
## and the seventh night loop for as long as they last. A beacon catching swells over all of it.
## Every piece is a file in assets/music; one that is missing is skipped.

const FADE := 3.0          ## seconds to cross from one piece to the next
const REST := [60.0, 150.0]   ## quiet between gentle pieces
const LOOPS := ["fight", "great", "seventh", "vigil"]
## slot: [file, loudness in dB]
const PIECES := {
	"swell": ["swell", -4.0], "great": ["great", -5.0], "vigil": ["seventh", -3.0], "seventh": ["seventh", -5.0], "fight": ["fight", -6.0],
	"sea": ["sea", -8.0], "town": ["town", -8.0], "night": ["night", -8.0], "dawn": ["dawn", -6.0],
}

var w
var now := ""             ## the slot playing, or "" in a quiet stretch
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _rest := 20.0         ## quiet left before a gentle piece may start
var _swell := 0.0         ## the beacon's swell holds over everything this long
var _t := 0.0
static var _streams := {}


func _init(world) -> void:
	w = world


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _player()
	_b = _player()


func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


static func stream_of(slot: String) -> AudioStream:
	if _streams.has(slot):
		return _streams[slot]
	if not PIECES.has(slot):
		return null
	var s: AudioStream = null
	var f: String = PIECES[slot][0]
	for ext in ["ogg", "mp3"]:
		var path := "res://assets/music/%s.%s" % [f, ext]
		if ResourceLoader.exists(path):
			s = load(path)
			break
	if s and slot in LOOPS:
		if s is AudioStreamOggVorbis or s is AudioStreamMP3:
			s.loop = true
	_streams[slot] = s
	return s


## A beacon caught: the swell plays over whatever was playing.
func beacon_swell() -> void:
	if stream_of("swell") == null:
		return
	_swell = 14.0
	_play("swell")


## What the moment asks for: the strongest first.
func want() -> String:
	if w.player == null or w.terrain == null:
		return ""
	var p: Vector3 = w.player.global_position
	var great := false
	var fight := 0
	for e in w.enemies:
		if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(p) < 45.0:
			if str(e.get("boss")) != "":
				great = true
			fight += 1
	if great:
		return "great"
	# Keeping a beacon's vigil: the driving piece, loud, for as long as the flame must be held
	for i in w.vigils:
		if int(i) < w.beacon_nodes.size() and (w.beacon_nodes[i].pos as Vector3).distance_to(p) < 120.0:
			return "vigil"
	if w.night and Wasteland.great_night(w.nights):
		return "seventh"
	if fight >= 3:
		return "fight"
	if w.player.get("vessel") != null or w.terrain.is_water(p.x, p.z, 0.5):
		return "sea"
	if w.settlement_at(p, 20.0) != "":
		return "town"
	if w.night:
		return "night"
	if w.clock >= 5.0 and w.clock < 8.5:
		return "dawn"
	return ""


func _process(delta: float) -> void:
	if w == null or Net.dedicated:
		return
	_t -= delta
	_swell -= delta
	_rest -= delta
	_fade(delta)
	if _t > 0.0:
		return
	_t = 1.0
	if _swell > 0.0:
		return
	var k := want()
	if k in LOOPS or now in LOOPS or now == "swell":
		if k != now:
			_play(k if stream_of(k) != null else "")
		return
	# Gentle pieces: one at a time, with quiet between
	if now != "":
		var cur := _cur()
		if cur and not cur.playing:
			now = ""
			_rest = randf_range(REST[0], REST[1])
		elif k != now and k != "":
			_play(k if stream_of(k) != null else "")
		return
	if k != "" and _rest <= 0.0 and stream_of(k) != null:
		_play(k)


var _on_a := true


func _cur() -> AudioStreamPlayer:
	return _a if _on_a else _b


func _play(slot: String) -> void:
	now = slot
	if slot == "":
		_rest = maxf(_rest, 20.0)
		return
	_on_a = not _on_a
	var p := _cur()
	p.stream = stream_of(slot)
	p.volume_db = -40.0
	p.play()


## The playing piece rises to its loudness; the other falls away.
func _fade(delta: float) -> void:
	var step := 40.0 / FADE * delta
	var cur := _cur()
	var other := _b if _on_a else _a
	var target: float = PIECES[now][1] if now != "" else -80.0
	if now == "" or not cur.playing:
		target = -80.0
	cur.volume_db = move_toward(cur.volume_db, target, step)
	other.volume_db = move_toward(other.volume_db, -80.0, step)
	if other.playing and other.volume_db <= -79.0:
		other.stop()
	if now == "" and cur.playing and cur.volume_db <= -79.0:
		cur.stop()
