class_name WDread
extends RefCounted
## Dread: out in the dark by night, away from fire and walls, fear grows. The further out, the faster.
## A lit lantern slows it; a fire, a town or the day takes it away. Past half the edges of sight go dark
## and grey and the whispers start; near the top, stranger things come to find whoever is afraid.

const RISE := 1.0 / 3.0                      ## a point every three seconds, in the open dark
const TIER_RATE := [0.5, 0.8, 1.0, 1.3, 1.5]      ## by the danger of the land
const DRAWN := 75.0                          ## from here, things come for the frightened
const FORMS := [["hollow", "howler"], ["wisp", "unseen", "vigil"], ["unseen", "deacon", "wisp"], ["unseen", "deacon", "wisp"]]

var w
var level := 0.0
var _t := 20.0
var _whisper := 0.0
var _said := 0
var _fx := false


func _init(world) -> void:
	w = world


## What keeps the dark off here: a fire close by, a town's walls, the Hall's quiet below.
func sheltered(p: Vector3) -> bool:
	if w.hall and w.hall.inside(p):
		return true
	return w.near_fire(p, 10.0) or w.settlement_at(p, 6.0) != ""


func rate(p: Vector3) -> float:
	if not w.night or sheltered(p) or w.power_is("hook"):
		return -2.0 if w.night else -1.0
	if w.near_bearer(p):
		return -0.5   # a Lantern-bearer walks with you: the dark keeps back
	var r: float = RISE * TIER_RATE[clampi(w.tier_at(p), 1, TIER_RATE.size()) - 1]
	var rl = w.player.get("relics")
	if rl and rl.lantern_lit:
		r *= 0.5
	return r


## Every machine, for its own pilgrim.
func local_tick(delta: float) -> void:
	if w.player == null or w.terrain == null or w.downed:
		return
	var p: Vector3 = w.player.global_position
	level = clampf(level + rate(p) * delta, 0.0, 100.0)
	_show()
	if level >= 50.0 and _said < 1:
		_said = 1
		w.hud.notify("The dark is pressing in. Find a fire, or light your lantern.")
	if level >= DRAWN and _said < 2:
		_said = 2
		w.hud.notify("Your fear draws things out of the dark.")
	if level < 30.0:
		_said = 0
	if level >= 50.0:
		_whisper -= delta
		if _whisper <= 0.0:
			_whisper = randf_range(14.0, 28.0) * (1.5 - level / 100.0)
			w.sfx("whispers", -20.0 + level * 0.1)
	if level >= DRAWN:
		_t -= delta
		if _t <= 0.0:
			_t = randf_range(28.0, 45.0) * (1.4 - level / 200.0)
			w.shared("_rq_dread", [p, w.tier_at(p)])


## The edges of sight darken and lose their colour as fear grows.
func _show() -> void:
	var k := clampf((level - 30.0) / 70.0, 0.0, 1.0)
	if k <= 0.0:
		if _fx:
			_fx = false
			w.hud.set_fx("vignette", 0.35)
			w.hud.set_fx("desat", 0.0)
		return
	_fx = true
	w.hud.set_fx("vignette", 0.35 + 0.5 * k)
	w.hud.set_fx("desat", 0.45 * k)


## The host: a stranger thing for the frightened one, if not too many are about already.
func host_spawn(at: Vector3, tier: int) -> void:
	if not Net.authority():
		return
	var near := 0
	for e in w.enemies:
		if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(at) < 40.0:
			near += 1
	if near >= 4:
		return
	var pool: Array = FORMS[clampi(tier, 1, 4) - 1].duplicate()
	if w._unseen_count() >= 1:
		pool.erase("unseen")
	var e = w._spawn_near(pool[randi() % pool.size()], at, 18.0, 28.0, true)
	if e:
		e.set_meta("raid", true)
