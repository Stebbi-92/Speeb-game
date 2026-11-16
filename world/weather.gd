class_name WWeather
extends Node3D
## Seasons and weather over the waste and its sea. Four seasons turn every few days; each brings its
## own run of weather. Ash storms blind and choke, salt frost bites through thin clothes at night,
## rain and gales raise the sea. The host decides the weather and tells the fellowship.

const SEASON_DAYS := 5
## name, [dusk, dawn], weather odds {kind: weight}, a few words when it comes
const SEASONS := [
	{"name": "The Thaw", "dusk": 20.0, "dawn": 5.0, "odds": {"clear": 5, "rain": 4, "gale": 1},
		"text": "The Thaw. Rain comes in off the sea, and the ash turns to mud."},
	{"name": "High Ember", "dusk": 21.0, "dawn": 4.5, "odds": {"clear": 6, "ashstorm": 2, "gale": 1},
		"text": "High Ember. Long days and short nights; the dunes are hotter, and the ash blows."},
	{"name": "Ashfall", "dusk": 19.5, "dawn": 5.5, "odds": {"clear": 3, "ashstorm": 4, "rain": 2, "gale": 2},
		"text": "Ashfall. The great storms come. Cover your face and keep to shelter."},
	{"name": "Salt Frost", "dusk": 18.0, "dawn": 7.0, "odds": {"clear": 3, "frost": 5, "gale": 2},
		"text": "Salt Frost. Long nights, and a cold that kills. Dress warm, and keep a fire."},
]
const KINDS := {
	"clear": {"name": "Clear", "fog": 0.0, "swell": 0.4, "wind": 0.4},
	"rain": {"name": "Rain", "fog": 0.006, "swell": 0.8, "wind": 0.6},
	"ashstorm": {"name": "Ash storm", "fog": 0.035, "swell": 0.9, "wind": 0.9},
	"frost": {"name": "Salt frost", "fog": 0.01, "swell": 0.5, "wind": 0.5},
	"gale": {"name": "Gale", "fog": 0.004, "swell": 1.6, "wind": 1.0},
}
const COMING := {
	"clear": "The sky clears.",
	"rain": "Rain is coming in off the sea.",
	"ashstorm": "An ash storm is coming. Cover your face, or find shelter.",
	"frost": "The air turns bitter. Salt frost tonight: dress warm and keep near a fire.",
	"gale": "A gale is rising. The sea will run high.",
}

var w   ## the wasteland
var kind := "clear"
var left := 600.0          ## seconds this weather has left (host only)
var k := 0.0               ## how far it has set in, 0 to 1, eased on each machine
var _rain: GPUParticles3D
var _ash: GPUParticles3D
var _rain_snd: AudioStreamPlayer
var _storm_snd: AudioStreamPlayer
var _hurt_t := 5.0
var _wind_turn := 0.0


func setup(world) -> WWeather:
	w = world
	return self


func _ready() -> void:
	if Net.dedicated:
		return
	_rain = _particles(Color(0.7, 0.75, 0.8, 0.5), Vector2(0.03, 0.7), 900, 14.0, 1.0)
	_ash = _particles(Color(0.45, 0.4, 0.36, 0.7), Vector2(0.12, 0.12), 1200, 3.0, 2.5)
	_rain_snd = w.ambient("amb_rain", -60)
	_storm_snd = w.ambient("amb_storm", -60)


func _particles(c: Color, sz: Vector2, n: int, fall: float, life: float) -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.amount = n
	ps.lifetime = life
	ps.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 1, 22)
	pm.direction = Vector3(0.2, -1, 0)
	pm.spread = 8.0
	pm.initial_velocity_min = fall * 0.8
	pm.initial_velocity_max = fall * 1.2
	pm.gravity = Vector3(0, -2.0, 0)
	pm.color = c
	ps.process_material = pm
	var q := QuadMesh.new()
	q.size = sz
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if sz.y > sz.x * 2.0 else BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	q.material = m
	ps.draw_pass_1 = q
	ps.emitting = false
	add_child(ps)
	return ps


static func season_of(day: int) -> int:
	return int(floor((maxi(day, 1) - 1) / float(SEASON_DAYS))) % SEASONS.size()


func season() -> Dictionary:
	return SEASONS[season_of(w.day)]


func dusk() -> float:
	return float(season().dusk)


func dawn() -> float:
	return float(season().dawn)


## The host's turn of the weather: when one runs out, the season picks the next.
func host_tick(delta: float) -> void:
	left -= delta
	_wind_turn += delta
	if left <= 0.0:
		var odds: Dictionary = season().odds
		var total := 0
		for kk in odds:
			total += int(odds[kk])
		var roll := randi_range(1, total)
		var next := "clear"
		for kk in odds:
			roll -= int(odds[kk])
			if roll <= 0:
				next = kk
				break
		# Frost comes by night; by day it is only a cold clear sky
		var secs := randf_range(420.0, 900.0) if next != "clear" else randf_range(600.0, 1200.0)
		w.shared("_w_weather", [next, secs, randf() * TAU])
	elif _wind_turn > 90.0 and w.sea:
		_wind_turn = 0.0
		w.shared("_w_wind", [wrapf(w.sea.wind_ang + randf_range(-0.6, 0.6), -PI, PI)])


func set_kind(next: String, secs: float, wind_ang: float) -> void:
	var was := kind
	kind = next if KINDS.has(next) else "clear"
	left = secs
	if w.sea:
		w.sea.wind_ang = wind_ang
	if was != kind and w.ready_world and not Net.dedicated:
		w.hud.notify(COMING[kind])


## How the weather looks and sounds here, and what it does to one out in it.
func _process(delta: float) -> void:
	if w.player == null or not w.ready_world:
		return
	var target := 0.0 if kind == "clear" else 1.0
	k = move_toward(k, target, delta / 25.0)
	var spec: Dictionary = KINDS[kind]
	if w.sea:
		var calm: Dictionary = KINDS.clear
		w.sea.swell = lerpf(float(calm.swell), float(spec.swell), k)
		w.sea.wind = lerpf(float(calm.wind), float(spec.wind), k)
	if Net.dedicated:
		return
	var at: Vector3 = w.player.global_position
	for ps in [_rain, _ash]:
		ps.global_position = at + Vector3(0, 12, 0)
	var under: bool = w.base_at(at, 0.0) >= 0 or w.settlement_at(at, 0.0) != ""
	_rain.emitting = k > 0.3 and kind in ["rain", "gale"]
	_ash.emitting = k > 0.3 and kind in ["ashstorm", "frost"]
	_ash.process_material.color = Color(0.45, 0.4, 0.36, 0.7) if kind == "ashstorm" else Color(0.92, 0.94, 0.96, 0.8)
	_ash.process_material.initial_velocity_min = 2.0 if kind == "ashstorm" else 1.0
	var wa: float = w.sea.wind_ang if w.sea else 0.0
	_ash.process_material.direction = Vector3(cos(wa) * 2.0, -1.0, sin(wa) * 2.0) if kind == "ashstorm" else Vector3(0.1, -1, 0)
	_rain_snd.volume_db = move_toward(_rain_snd.volume_db, -14.0 if kind == "rain" and k > 0.2 else -60.0, delta * 15.0)
	_storm_snd.volume_db = move_toward(_storm_snd.volume_db, -10.0 if kind in ["gale", "ashstorm"] and k > 0.2 else -60.0, delta * 15.0)
	_hurt_t -= delta
	if _hurt_t <= 0.0:
		_hurt_t = 5.0
		_harm(at, under)


## Fog and colour laid over the time of day: called after the sun is set for the hour.
func apply_env(env: Environment, night_k: float) -> void:
	if k <= 0.0:
		return
	var spec: Dictionary = KINDS[kind]
	env.fog_density = lerpf(env.fog_density, maxf(env.fog_density, float(spec.fog)), k)
	var tint := Color(0.42, 0.36, 0.3) if kind == "ashstorm" else (Color(0.62, 0.66, 0.7) if kind in ["frost", "rain", "gale"] else env.fog_light_color)
	env.fog_light_color = env.fog_light_color.lerp(tint.lerp(Color(0.03, 0.03, 0.04), night_k), k * 0.7)
	env.ambient_light_energy *= lerpf(1.0, 0.7 if kind == "ashstorm" else 0.85, k)


## Whether the weather now asks something of one standing here.
func hardship(at: Vector3) -> String:
	if k < 0.6:
		return ""
	var wn: Dictionary = WArms.worn(w.arms)
	match kind:
		"ashstorm":
			if not wn.covered:
				return "The ash chokes you.  Cover your face, or get under a roof."
		"frost":
			if w.night and float(wn.warm) < 2.0 and not w.near_fire(at):
				return "The frost bites.  Dress warm, or keep near a fire."
	return ""


func _harm(at: Vector3, under: bool) -> void:
	if w.downed or under or w.gentle_at(at):
		return
	var why := hardship(at)
	if why == "":
		return
	var pl = w.player
	pl.health = maxf(1.0, pl.health - (2.5 if kind == "ashstorm" else 3.0))
	w.hud.set_health(pl.health / pl.max_health, true)
	if kind == "frost":
		pl.stamina = maxf(0.0, pl.stamina - 15.0)


## What the fellowship sees on the clock: the season, and the weather if any.
func label() -> String:
	var t := str(season().name)
	if kind != "clear" and k > 0.3:
		t += ",  " + str(KINDS[kind].name).to_lower()
	return t
