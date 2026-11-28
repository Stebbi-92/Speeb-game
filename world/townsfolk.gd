class_name WTownsfolk
extends Node3D
## The ordinary people of a settlement: they walk about their business, stop to rest, and mutter a word
## to whoever stops them. Seen by each pilgrim alone; they are the life of the place, not its story.

const LINES := [
	"Mind the well. It's deeper than it looks.", "Salt's dear this week.", "Were you out past the rim? Mad.",
	"Keep your fire fed. A cold camp draws them.", "The roads are safer by day. Mostly.", "Seen my goat? Brown, bad-tempered.",
	"Trader's in. Bring something worth selling.", "My brother went for wood. Two days now.", "Hush. Listen. No. Just the wind.",
	"Cook your meat. Trust me.", "There's work if you ask the right people.", "Another one from the dust. Welcome, I suppose.",
	"Hunting's good past the dunes.", "Don't sleep where you can't see the sky.", "They say the beacons can be lit again.",
]

var w
var home := Vector3.ZERO
var radius := 20.0
var fig: Figure
var who := ""
var lines: Array = []   ## their own words, if they have any; else the town's talk
var on_talk: Callable   ## or someone with more to say: returns the line
var _to := Vector3.ZERO
var _wait := 0.0
var _speed := 1.3
var _voice: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func setup(lvl, at: Vector3, r: float, seed: int) -> WTownsfolk:
	w = lvl
	home = at
	radius = r
	who = "folk%d" % seed
	_rng.seed = seed
	_speed = _rng.randf_range(1.0, 1.6)
	return self


func _ready() -> void:
	fig = Figure.new().setup(Figure.townsman(who.hash(), w.settlement_at(home) if w.has_method("settlement_at") else ""))
	fig.arms_forward = false
	add_child(fig)
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 4.0
	_voice.max_distance = 30.0
	_voice.volume_db = -6.0
	_voice.position.y = 1.6
	add_child(_voice)
	var body := StaticBody3D.new()
	body.collision_layer = 16
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	body.add_child(cs)
	add_child(body)
	w.personal_interactable(body, "Talk", _chat)
	_pick()


func _chat() -> void:
	var pool: Array = lines if not lines.is_empty() else LINES
	var line: String = on_talk.call() if on_talk.is_valid() else pool[_rng.randi() % pool.size()]
	w.hud.notify(line)
	_voice.stream = WBabble.make(who, line, clampf(line.length() / 55.0, 0.5, 2.0))
	fig.talk_t = clampf(line.length() / 15.0, 1.5, 4.0)
	_voice.play()
	_wait = 3.0
	look_at(Vector3(w.player.global_position.x, global_position.y, w.player.global_position.z), Vector3.UP, true)


func _pick() -> void:
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(2.0, radius)
	_to = home + Vector3(cos(a) * d, 0, sin(a) * d)
	_to.y = w.terrain.height_at(_to.x, _to.z)


func _process(delta: float) -> void:
	# Only those near enough to be seen go about their day
	if w.player == null or global_position.distance_to(w.player.global_position) > 90.0:
		return
	if _wait > 0.0:
		_wait -= delta
		fig.stride = move_toward(fig.stride, 0.0, delta * 4.0)
		return
	var to := _to - global_position
	to.y = 0
	if to.length() < 0.5:
		_wait = _rng.randf_range(2.0, 9.0)
		_pick()
		return
	var step := to.normalized() * _speed * delta
	global_position += step
	global_position.y = w.terrain.height_at(global_position.x, global_position.z)
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 6.0))
	fig.stride = move_toward(fig.stride, 1.0, delta * 4.0)
	fig.walk += delta * _speed * 5.5
