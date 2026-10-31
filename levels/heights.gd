extends Level
## IV. The Heights of Sorrows. Brelm climbs the broken peak, and at its summit is cast down by unseen hands.

const PEAK := Vector3(0, 0, -30)
const STEPS := 26
const RADIUS := 9.5
## Where the stair has fallen away. Only the Claw of Ascent crosses it.
const BROKEN := [12, 13, 14]

var steps: Array = []
var summit_y := 0.0
var flung := false
var summit_reached := false


func build() -> void:
	spiders = false
	numeral = "IV"
	max_alive = 3
	spitter_chance = 0.6
	place = "The Heights of Sorrows"
	verse = "Fourth, he climbed the Heights of Sorrows, carrying every betrayal he had ever hidden, even from himself."
	setup_env(Color(0.28, 0.34, 0.45), Color(0.7, 0.72, 0.76), Color(0.4, 0.42, 0.45), Color(0.66, 0.7, 0.76), 0.012, 0.85)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	add_sun(Vector3(-25, -120, 0), Color(1.0, 0.93, 0.85), 1.5)
	kill_y = -12.0
	var rock := mat(Color(0.42, 0.42, 0.44), 0.95, 0.45, 0.12)
	var pale := mat(Color(0.6, 0.6, 0.62), 0.9, 0.35, 0.2)
	# The starting ledge
	cyl(Vector3(0, -2, 0), 5.0, 4.0, rock)
	# The peak itself
	summit_y = 0.6 + STEPS * 0.55
	cyl(PEAK + Vector3(0, summit_y * 0.5 - 30, 0), 6.0, summit_y + 60, rock, true, 3.6, 10)
	# The broken stair around it
	var start_angle := PI * 0.5
	for k in STEPS:
		var a := start_angle + k * 0.4
		var p := PEAK + Vector3(cos(a) * RADIUS, 0.6 + k * 0.55, sin(a) * RADIUS)
		steps.append(p)
		if k in BROKEN:
			continue
		box(p, Vector3(2.6, 0.5, 2.6), pale, true, Vector3(0, -rad_to_deg(a), 0))
		cyl(p + Vector3(0, -3.5, 0), 0.7, 6.5, rock, false, 0.9, 6)
	# A bridge from the ledge to the first step
	var first: Vector3 = steps[0]
	var mid := (Vector3(0, 0, 0) + first) * 0.5
	var br := box(mid + Vector3(0, -0.05, 0), Vector3(1.8, 0.4, Vector2(first.x, first.z).length() - 1.0), pale)
	br.look_at_from_position(mid + Vector3(0, -0.05, 0), first + Vector3(0, -0.05, 0), Vector3.UP)
	# The summit
	cyl(PEAK + Vector3(0, summit_y, 0), 4.2, 0.6, pale)
	var last: Vector3 = steps[STEPS - 1]
	var to := PEAK + Vector3(0, summit_y + 0.3, 0)
	var mid2 := (last + to) * 0.5
	var br2 := box(mid2, Vector3(1.6, 0.4, last.distance_to(to)), pale)
	br2.look_at_from_position(mid2, to, Vector3.UP)
	for k in 6:
		var a := k * TAU / 6.0
		cyl(PEAK + Vector3(cos(a) * 3.6, summit_y + 1.0, sin(a) * 3.6), 0.25, 1.4, rock, true, 0.1, 5)
	# The mist below and the valley of obscurity far beneath
	box(Vector3(0, -60, -30), Vector3(600, 2, 600), mat(Color(0.3, 0.32, 0.35), 1.0, 0.3, 0.02))
	for i in 30:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(40, 140)
		cyl(Vector3(cos(a) * d, -40 + _rng.randf_range(0, 30), -30 + sin(a) * d), _rng.randf_range(3, 9), 60, rock, false, _rng.randf_range(0.5, 3), 7)
	trigger_area(PEAK + Vector3(0, summit_y + 1.5, 0), Vector3(7, 3, 7), _summit)
	var far: Vector3 = steps[15]
	anchor(far + Vector3(0, 3.4, 0), far + Vector3(0, 0.9, 0))
	relic_pickup("claw", Vector3(2.4, 0.5, 0.8))
	trigger_area(steps[11] + Vector3(0, 1.2, 0), Vector3(2.6, 2.4, 2.6), func():
		if not Game.relics.has("claw"):
			hud.say("The stair is broken here. Far above the gap hangs a ring of old iron. He had passed the Claw of Ascent at the foot of the climb.", 7.0)
		else:
			hud.say("The stair is broken. Above the far side hangs a ring of old iron. Take the Claw [4] and cast it.", 6.0))

	lesser("thunderspeebii", steps[9] + Vector3(0, 1.4, 0))
	lesser("vikingspeeb", steps[17] + Vector3(0, 1.4, 0))
	lesser("astrospeeb", Vector3(-3.5, 1.4, 1.5))
	ambient("wind", -4)
	spawn_pos = Vector3(0, 0.1, 2.5)
	spawn_yaw = yaw_to(Vector3(0, 0, 2.5), steps[0])


func intro() -> void:
	player.jump_velocity = 5.8
	hud.set_objective("Climb the Heights of Sorrows   (Space to leap, the Claw of Ascent where the stair is broken)")
	await super.intro()


func trial_tick(_d: float) -> void:
	# Every sixth step is a resting place: if he falls, he rises there.
	var p := player.global_position
	for k in range(5, STEPS, 6):
		var s: Vector3 = steps[k]
		if p.distance_to(s + Vector3(0, 0.4, 0)) < 1.6 and spawn_pos.y < s.y:
			checkpoint(s + Vector3(0, 0.4, 0), yaw_to(s, steps[mini(k + 1, STEPS - 1)]))
			hud.notify("He rests a moment upon the stair.")


func on_fall() -> void:
	if flung:
		return
	fail("He fell, and was not destroyed. He rose, and climbed again.", "")


func _summit() -> void:
	if summit_reached:
		return
	summit_reached = true
	combat_frozen = true
	clear_enemies()
	hud.say("At the summit he knelt, and confessed nothing, for there was no one to hear. Yet he was heard.", 6.0)
	await get_tree().create_timer(5.0, false).timeout
	await survive("speebyeet", PEAK + Vector3(0, summit_y + 4.5, 0), "rain", 30.0, summit_y)
	reveal("speebyeet", PEAK + Vector3(0, summit_y + 3.2, 0), 3.0, true, _cast_down)


func _cast_down(e: Emoji3D) -> void:
	await get_tree().create_timer(5.0, false).timeout
	flung = true
	kill_y = -500
	sfx("whoosh", 0)
	hud.set_fx("flash", 0.6)
	create_tween().tween_method(func(v): hud.set_fx("flash", v), 0.6, 0.0, 1.0)
	var away := player.global_position - PEAK
	away.y = 0
	away = away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)
	player.flung = true
	player.velocity = away * 16.0 + Vector3(0, 9, 0)
	create_tween().tween_property(e, "scale", Vector3.ONE * 7.0, 5.0).set_trans(Tween.TRANS_SINE)
	await get_tree().physics_frame
	while not player.is_on_floor() or player.velocity.y > 0.0:
		await get_tree().physics_frame
		player.face(e.global_position)
	player.flung = false
	player.velocity = Vector3.ZERO
	sfx("crumble", -6)
	hud.set_fx("dark", 0.2)
	# The Swift Cast follows him down into obscurity, and waits before him.
	var fwd := -player.global_transform.basis.z
	fwd.y = 0
	e.scale = Vector3.ONE * 0.01
	e.global_position = player.global_position + fwd.normalized() * 9.0 + Vector3(0, 3.2, 0)
	e.rebase()
	omni(e.global_position + Vector3(0, 0, 0), Color(1, 0.97, 0.9), 1.4, 14)
	create_tween().tween_property(e, "scale", Vector3.ONE * 1.4, 3.0).set_trans(Tween.TRANS_SINE)
	player.look_toward(e.global_position, 2.0)
