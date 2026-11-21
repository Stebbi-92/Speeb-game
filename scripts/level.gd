class_name Level
extends Node3D
## A land of the pilgrimage. Subclasses override build(), and optionally trial_tick() and reset_trial().

var player: Player
var hud
var env: Environment
var sun: DirectionalLight3D
var spawn_pos := Vector3.ZERO
var spawn_yaw := 0.0
var kill_y := -40.0
var numeral := ""
var place := ""
var verse := ""
var completed := false
var failing := false
var lesser_codes: Array = []
var _ambient: Array = []
var _rng := RandomNumberGenerator.new()

# Combat: the lesser forms that hunt Brelm through the trial lands
var combat := true
var combat_frozen := false
var max_alive := 5
var spawn_interval := 4.0
var spitter_chance := 0.35
var spiders := true
var armed := true
var enemies: Array = []
var _spawn_t := 5.0
var _shrines: Array = []
var kills := 0
var falls := 0
var witnessed := 0
var elite_spawned := false
var elite_at := 14
var _music: AudioStreamPlayer
var enemy_time := 1.0
var wave := 0
var wave_timeout := 45.0
var _next_wave := 5.0
var _wave_queue: Array = []
var _gathering := false
var _first_wave_shown := false
var anchors: Array = []
var streak := 0
var life_kills := 0          ## forms slain since last falling: kill streaks
var streaks_ready: Array = []
var _streak_t := 0.0
var shots := 0
var hits := 0
var trial_time := 0.0
var _struck_in_judgment := false
# The Other Hermit and the Unblinking Eye walk the trial lands
var velm: Velm
var _velm_t := 25.0
var _velm_shown := 0.0
var _velm_looked := 0.0
var velm_scripted := false
var _steps_t := 20.0
var _still_t := 0.0
var _eye_t := 75.0
var eye_watching := false
var _veiled: Array = []
var _regen_wait := 0.0
# The fellowship: other pilgrims, the lesser forms as the host runs them, and the shared steps of the trial
var avatars := {}
var foes := {}
var downed := false
var eye_seen_by_any := false
var _foe_next := 1
var _net_events: Array = []
var _pose_t := 0.0
var _foes_t := 0.0
var _roster_t := 0.0
var _known: Dictionary = {}   ## who was in the fellowship when last looked, by id -> name
var _down_peers := {}
var _pfail := false
var _survive_done := false
var _eye_verdict := -1
var _trial_sent := ""
var team_kills := 0
var _gone := {}


var raising := false   ## true while build() is still at work over several frames


func _ready() -> void:
	hud = Game.main.hud
	_rng.seed = 7
	# Raising a great land may take many frames: nothing in it stirs till it is whole
	raising = true
	var mode := process_mode
	process_mode = Node.PROCESS_MODE_DISABLED
	await build()
	process_mode = mode
	raising = false
	apply_quality()
	player = Player.new()
	add_child(player)
	player.place(spawn_pos, spawn_yaw)
	player.set_armed(armed)
	player.reset_max_health()
	if Net.dedicated:
		_ghost()
	if combat:
		_music = ambient("combat", -60)
	for e in _shrines:
		e.face_target = player
	hud.set_health(1.0, combat)
	hud.reset_fx()
	hud.name_label.text = "Brelm"
	await get_tree().process_frame
	hud.fade_to(0.0, 2.5)
	_place_story()
	if Net.online and not Net.is_host():
		Net.ask_checkpoint()
	if armed and not Net.dedicated and not Game.wasteland and OS.get_cmdline_user_args().is_empty():
		_choose_arms()
	intro()


## Counts a form slain toward the kill streaks, and readies the ones earned.
func life_kill() -> void:
	life_kills += 1
	if Game.wasteland and WRules.get_rule("air") == 0:
		return
	for k in Streaks.ORDER:
		if life_kills == int(Streaks.KINDS[k].kills):
			streaks_ready.append(k)
			sfx("bell", -6)
			hud.notify("%s ready. Press %s for air support." % [Streaks.KINDS[k].name, Game.key_text("streak")])
			if player.weapon:
				player.weapon._ui()


## Calls the oldest earned streak onto the point under the crosshair.
func call_streak() -> void:
	if hud.streak_menu_open():
		hud.close_streak_menu()
		return
	if Game.wasteland and WRules.get_rule("air") == 0:
		hud.notify("Air support is off in this world.")
		return
	if streaks_ready.is_empty():
		hud.notify("Nothing answers yet. Slay %d without falling to call the sky down." % maxi(1, int(Streaks.KINDS.airstrike.kills) - life_kills))
		return
	var kinds: Array = []
	for k in Streaks.ORDER:
		if k in streaks_ready:
			kinds.append(k)
	if kinds.size() == 1:
		_call_streak(kinds[0])
		return
	# More than one is ready: the air support menu, to choose which comes
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var counts := {}
	for k in streaks_ready:
		counts[k] = counts.get(k, 0) + 1
	var k = await hud.open_streak_menu(kinds, counts)
	if not is_inside_tree():
		return
	player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player.weapon:
		player.weapon.hold_fire = true
	if k != null and k in streaks_ready:
		_call_streak(k)


func _call_streak(k: String) -> void:
	streaks_ready.erase(k)
	var cam := player.cam
	var fwd := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + fwd * 400.0, 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var at: Vector3 = r.position if not r.is_empty() else cam.global_position + fwd * 60.0
	Streaks.call_in(self, k, at, fwd, true)
	Net.fx("streak:" + k, at, fwd)
	hud.notify("%s called." % Streaks.KINDS[k].name)
	sfx("deny", -12, null, 1.6)
	if player.weapon:
		player.weapon._ui()


## Before each trial the pilgrim chooses what to carry. Alone, the world waits; in a fellowship it does not.
func _choose_arms() -> void:
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree() or player == null:
		return
	var ui: LoadoutUI = hud.show_loadout()
	var hold := not Net.online
	if hold:
		get_tree().paused = true
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await ui.done
	if hold:
		get_tree().paused = false
	if not is_inside_tree():
		return
	if player.weapon:
		player.weapon.equip_loadout()
		if not Game.wasteland:
			player.weapon.refill()
		player.relics.refresh()
	player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func build() -> void:
	pass


## The graphics presets. Low: short, coarse shadows and no glow, for slower machines. Standard: the
## world as made. High: ambient occlusion, indirect light, and a richer bloom.
func apply_quality() -> void:
	if env == null:
		return
	var high := Game.quality == 2
	var low := Game.quality == 0
	env.ssao_enabled = high
	env.ssao_intensity = 1.6
	env.ssil_enabled = high
	if not has_meta("glow0"):
		set_meta("glow0", env.glow_intensity)
	env.glow_enabled = not low
	env.glow_intensity = maxf(float(get_meta("glow0")), 0.8) if high else float(get_meta("glow0"))
	env.glow_bloom = 0.08 if high else 0.0
	env.adjustment_enabled = absf(Game.brightness - 1.0) > 0.01
	env.adjustment_brightness = Game.brightness
	RenderingServer.directional_shadow_atlas_set_size(2048 if low else 4096, true)
	if sun:
		if not sun.has_meta("reach0"):
			sun.set_meta("reach0", sun.directional_shadow_max_distance)
		sun.shadow_blur = 1.5 if high else 1.0
		sun.directional_shadow_max_distance = minf(float(sun.get_meta("reach0")), 45.0) if low else float(sun.get_meta("reach0"))
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if low else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func intro() -> void:
	if place != "":
		await hud.title_card(numeral, place)
	if verse != "" and not completed:
		hud.say(verse, 9.0)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if Net.online:
		_net_tick(delta)
	if failing:
		return
	if Net.dedicated:
		_ghost_tick()
		_combat_tick(delta)
		return
	if player.global_position.y < kill_y and not _pfail:
		on_fall()
		return
	for v in _veiled:
		if v.t > 0.0:
			v.t -= delta
			if v.t <= 0.0 and is_instance_valid(v.node):
				v.node.visible = false
	if not completed:
		trial_time += delta
		if not _pfail and not downed:
			trial_tick(delta)
		_combat_tick(delta)
		if _haunted():
			_velm_tick(delta)
			_eye_tick(delta)
	if streak > 0:
		_streak_t -= delta
		if _streak_t <= 0.0:
			streak = 0
			hud.set_streak(0)


func _combat_tick(delta: float) -> void:
	if not combat:
		return
	_regen_wait -= delta
	if _regen_wait <= 0.0 and player.health < player.max_health and not downed and not Net.dedicated:
		player.health = minf(player.max_health, player.health + (4.0 if Game.blessed("speebchef") else 1.5) * Game.difficulty_scale("regen") * delta)
		hud.set_health(player.health / player.max_health, true)
	hud.set_blessings(player)
	enemies = enemies.filter(func(e): return is_instance_valid(e))
	if _music:
		var near := 0
		for e in enemies:
			if e.global_position.distance_to(player.global_position) < 26.0:
				near += 1
		_music.volume_db = move_toward(_music.volume_db, -8.0 if near > 0 and not combat_frozen else -60.0, delta * (30.0 if near > 0 else 8.0))
	if combat_frozen or not Net.authority():
		return
	# Members of the current gathering arrive one after another, not all at once
	if not _wave_queue.is_empty():
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = 0.55
			_spawn_enemy(_wave_queue.pop_front())
	if _gathering:
		return
	# Between trials the forms come in gatherings: clear one and there is rest; tarry and another comes regardless
	_next_wave -= delta
	if _wave_queue.is_empty() and alive_count() == 0:
		_next_wave = minf(_next_wave, spawn_interval * 3.0)
	if _next_wave <= 0.0:
		if alive_count() < wave_size() * 2:
			_next_wave = wave_timeout
			wave += 1
			_begin_wave(wave_size(), wave > 1 and randf() < 0.3)
			if _first_wave_shown:
				hud.notify("More lesser forms gather." if alive_count() == 0 else "Brelm tarried. More lesser forms gather.")
			_first_wave_shown = true
		else:
			_next_wave = 5.0


func wave_size() -> int:
	return maxi(2, max_alive + int(Game.difficulty_scale("alive")))


func alive_count() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and e.is_alive():
			n += 1
	return n


## Queues a gathering of n lesser forms. A saucer, when it comes, counts as one of them.
func _begin_wave(n: int, saucer: bool) -> void:
	if not Net.authority():
		return
	var roster: Array = []
	if saucer:
		roster.append("saucer")
	if not _gathering and kills + team_kills >= elite_at and not elite_spawned:
		elite_spawned = true
		roster.append("elite")
		hud.notify("A greater form descends, crowned in red.")
		sfx("deny", -2)
	while roster.size() < n:
		var r := randf()
		if r < 0.14:
			roster.append_array(["swarm", "swarm", "swarm"])
		elif r < 0.26:
			roster.append("idol")
		elif r < 0.42:
			roster.append("spider" if spiders else "rusher")
		elif r < 0.47 and Game.level_index >= 5 and not roster.has("unseen"):
			roster.append("unseen")
		else:
			roster.append("spitter" if randf() < spitter_chance else "rusher")
	_wave_queue.append_array(roster)
	_spawn_t = minf(_spawn_t, 0.3)


## A lesser form takes shape somewhere out of reach, in open air.
func _spawn_enemy(kind: String) -> void:
	var space := get_world_3d().direct_space_state
	var high := kind == "saucer"
	var center := focus_pos()
	for attempt in 16:
		var a := randf() * TAU
		var d := randf_range(14.0, 24.0)
		var p := center + Vector3(cos(a) * d, randf_range(6.0, 8.0) if high else randf_range(1.2, 2.6), sin(a) * d)
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.7
		q.shape = s
		q.transform = Transform3D(Basis(), p)
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			continue
		var down := PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -20 if high else -12, 0), 1)
		if space.intersect_ray(down).is_empty() and not ((high and attempt > 10) or (kind != "spider" and attempt > 8)):
			continue
		# It must take shape where a pilgrim could reach it, never behind a wall
		if not reachable(p):
			continue
		spawn_at(kind, p)
		if high:
			hud.notify("A saucer descends, and smaller forms stir within it.")
		return
	# Nowhere open at that distance: it comes closer, still in plain sight, or waits for the next moment
	var spot = open_spot_near(center, 5.0, 12.0, kind == "saucer")
	if spot != null:
		spawn_at(kind, spot)
	else:
		_wave_queue.append(kind)


## Is there a clear line from where a pilgrim stands to this point? Forms that take shape behind walls never reach anyone.
func reachable(p: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for t in (targets() if not targets().is_empty() else [player]):
		var eye: Vector3 = t.global_position + Vector3(0, 1.4, 0)
		var q := PhysicsRayQueryParameters3D.create(eye, p, 1)
		if space.intersect_ray(q).is_empty():
			return true
	return false


## A free, reachable point near a pilgrim, or null.
func open_spot_near(center: Vector3, rmin: float, rmax: float, high := false):
	var space := get_world_3d().direct_space_state
	for attempt in 24:
		var a := randf() * TAU
		var d := randf_range(rmin, rmax)
		var p := center + Vector3(cos(a) * d, randf_range(4.0, 6.0) if high else randf_range(1.2, 2.2), sin(a) * d)
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.7
		q.shape = s
		q.transform = Transform3D(Basis(), p)
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			continue
		if reachable(p):
			return p
	return null


func spawn_at(kind: String, p: Vector3) -> LesserSpeeb:
	var codes: Array = Game.lesser.keys()
	var e := LesserSpeeb.new().setup(codes[randi() % codes.size()], kind, self)
	e.position = p
	e.net_id = _foe_next
	_foe_next += 1
	foes[e.net_id] = e
	add_child(e)
	enemies.append(e)
	sfx("hiss", -10, p)
	return e


## Testing aid: a lesser form hanging before Brelm, still.
func debug_enemy() -> void:
	combat_frozen = true
	var ks := ["rusher", "spider", "idol", "spitter"]
	for i in ks.size():
		var e := LesserSpeeb.new().setup(Game.lesser.keys()[randi() % 80], ks[i], self)
		add_child(e)
		enemies.append(e)
		var fwd := -player.global_transform.basis.z
		e.global_position = player.global_position + fwd * (4.0 + i * 1.5) + Vector3(-3.0 + i * 2.0, 1.5, 0)


var _voice: AudioStreamPlayer
## What each kill line says (tools/make_kill_lines.py recorded them), for subtitles.
const KILL_LINES := ["Back to the void.", "Be weighed.", "Balance is restored.", "Speeb sees you.", "Return to the stillness.",
	"You were judged.", "Not today.", "The scales tip.", "Silence.", "Survive that.",
	"Another trial.", "Do not whine.", "Unblinking.", "Begone, lesser one.", "Your form is undone.",
	"I am still standing.", "Judgment is swift.", "Into obscurity.", "Be still.", "The paw has spoken."]
var _last_line := -1


## Brelm speaks over each fallen form, his voice high and wavering.
func kill_line() -> void:
	if not Game.voice_lines:
		return
	if _voice == null:
		_voice = AudioStreamPlayer.new()
		_voice.volume_db = 0
		add_child(_voice)
	var i := randi() % 20
	if i == _last_line:
		i = (i + 1) % 20
	_last_line = i
	_voice.stream = load("res://assets/audio/kills/kill_%02d.ogg" % i)
	_voice.pitch_scale = randf_range(0.88, 1.3)
	_voice.play()
	hud.subtitle("Brelm", KILL_LINES[i])


func on_enemy_slain(e: LesserSpeeb) -> void:
	life_kill()
	kills += 1
	kill_line()
	Game.add_kill(e.kind)
	# The Litany: forms undone in quick succession
	streak += 1
	_streak_t = 3.5
	hud.set_streak(streak)
	if streak > Game.stats.best_streak:
		Game.stats.best_streak = streak
	for n in [5, 10, 20]:
		if streak == n:
			Game.reveal_deed("streak%d" % n)
	if streak % 5 == 0:
		sfx("choir", -14, null, 1.0 + minf(streak / 5 - 1, 3) * 0.06)
		if player.relics:
			player.relics.add_faith(0.15)
	if e.kind in ["saucer", "elite"]:
		player.shake(0.7)
	# The last form of a gathering falls slowly
	if _gathering and _wave_queue.is_empty() and alive_count() == 0 and not Net.online:
		slow_motion(0.25, 0.7)
	if player.relics:
		player.relics.add_faith(0.04 if e.kind in ["swarm", "mite"] else 0.125)
	if e.kind in ["saucer", "elite"] or randf() < 0.05:
		shared("_drop", ["milk", e.global_position, 1])
	if Game.blessed("emospeeb") and combat:
		player.health = minf(player.max_health, player.health + 8.0)
		hud.set_health(player.health / player.max_health, true)
	if e.kind == "elite":
		player.health = player.max_health
		hud.set_health(1.0, true)
		shared("_drop", ["shells", e.global_position, 12])
		hud.notify("The greater form is undone. Strength returns to Brelm.")
	elif e.kind == "saucer":
		shared("_drop", ["shells", e.global_position, 8])
		hud.notify("The saucer falls silent and is undone.")
	elif not e.kind in ["swarm", "mite"] or randf() < 0.3:
		var low: bool = player.weapon and player.weapon.low_ammo()
		if randf() < (0.7 if low else 0.35):
			shared("_drop", ["shells", e.global_position, 4])


## What a fallen form leaves is seen by the whole fellowship, and each pilgrim may take their own share of it.
func _drop(what: String, at: Vector3, n: int) -> void:
	if Net.dedicated:
		return
	if what == "milk":
		milk_pickup(at)
	else:
		_offering(at, n)


## A form held back by something in its way. The open waste lets it tear at what was built.
func on_blocked(_e: LesserSpeeb, _col: Object, _dmg: float) -> bool:
	return false


## A form undone by another pilgrim of the fellowship still counts toward the land's gatherings.
func team_kill(_e: LesserSpeeb) -> void:
	team_kills += 1


## A small offering of shells, left where a lesser form fell.
func _offering(at: Vector3, n: int) -> void:
	var space := get_world_3d().direct_space_state
	var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3(0, -20, 0), 1))
	var pos: Vector3 = r.position + Vector3(0, 0.35, 0) if not r.is_empty() else at
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	cs.shape = sh
	a.add_child(cs)
	var brass := glow_mat(Color(0.95, 0.7, 0.3), 1.5)
	var red := mat(Color(0.55, 0.08, 0.06), 0.6, 0.0)
	for i in mini(n, 6):
		var shell := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.045
		cm.height = 0.2
		shell.mesh = cm
		shell.material_override = red
		shell.position = Vector3((i % 3 - 1) * 0.1, 0, (i / 3) * 0.1)
		var cap := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.048
		cc.bottom_radius = 0.048
		cc.height = 0.05
		cap.mesh = cc
		cap.material_override = brass
		cap.position.y = -0.09
		shell.add_child(cap)
		a.add_child(shell)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = 0.8
	l.omni_range = 2.5
	a.add_child(l)
	add_child(a)
	a.global_position = pos
	var tw := a.create_tween().set_loops()
	tw.tween_property(a, "rotation:y", TAU, 3.0).from(0.0)
	a.body_entered.connect(func(b):
		if b is Player and b.weapon:
			b.weapon.add_shells(n)
			sfx("shell", -2)
			hud.notify("+%d shells" % n)
			a.queue_free())


## The Meowifestation comes in judgment before it is revealed. It is not fought: it is survived.
func survive(code: String, pos: Vector3, attack: String, dur := 35.0, ground_y := 0.0) -> void:
	var e := Emoji3D.new().setup(code, 2.4)
	e.position = pos
	e.glow = 0.35
	e.face_target = player
	e.scale = Vector3.ONE * 0.01
	add_child(e)
	var light := omni(pos, Color(1, 0.95, 0.85), 2.0, 12)
	create_tween().tween_property(e, "scale", Vector3.ONE, 2.0).set_trans(Tween.TRANS_SINE)
	sfx("bell", -4)
	fade_ambient(-20, 3.0)
	var heart := ambient("heartbeat", -12)
	checkpoint(player.global_position + Vector3(0, 0.2, 0), player.yaw)
	var name: String = Game.NAMES.get(code, "Speeb")
	hud.say("%s regards him, and the lesser forms gather. Undo every one of them. Do not try to please him. Only survive him." % name, 6.0)
	# A set number of gatherings. Clear one and the next comes; tarry, and the next comes anyway.
	var waves := clampi(roundi(dur / 11.0), 3, 6)
	var size := wave_size() + 2
	var tarry := 25.0
	combat_frozen = false
	_gathering = true
	_struck_in_judgment = false
	_wave_queue.clear()
	var wave_n := 0
	var clock := 0.0
	var rest := 1.5
	var slain0 := kills + team_kills
	var t := 0.0
	_survive_done = false
	# In a fellowship only the host gathers the forms; the others hold until the host says it is done
	var follower := Net.online and not Net.is_host()
	var atk := 2.0
	var home := pos
	while true:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		if failing:
			wave_n = 0
			clock = 0.0
			rest = 4.0
			slain0 = kills + team_kills
			atk = 3.0
			e.position = home
			continue
		t += dt
		clock += dt
		atk -= dt * enemy_time
		if follower:
			if _survive_done or not Net.online:
				break
		# Should the last forms linger out of reach too long, they are unmade
		if not follower and wave_n >= waves and _wave_queue.is_empty() and clock > 70.0 and alive_count() > 0:
			for x in enemies:
				if is_instance_valid(x) and x.is_alive():
					x.die(false)
		var cleared := _wave_queue.is_empty() and alive_count() == 0 and not follower
		if cleared:
			if wave_n >= waves:
				break
			rest -= dt
		if not follower and ((cleared and rest <= 0.0) or (wave_n > 0 and wave_n < waves and clock >= tarry)):
			if not cleared:
				hud.notify("Brelm tarried. The next gathering comes regardless.")
			wave_n += 1
			clock = 0.0
			rest = 2.5
			_begin_wave(size, wave_n >= 2)
		if not follower:
			var left := _wave_queue.size() + alive_count() + (waves - wave_n) * size
			var done_n := kills + team_kills - slain0
			var obj := "Undo the gathering before %s  ·  %d of %d" % [name, maxi(wave_n, 1), waves]
			var met := "Forms remaining: %d" % left
			var val := float(done_n) / float(maxi(1, done_n + left))
			hud.set_objective(obj)
			hud.set_meter(met, val)
			if Net.online and obj + met != _trial_sent:
				_trial_sent = obj + met
				Net.trial_state(obj, met, val, false)
		if Net.dedicated:
			continue
		var this_attack := attack
		if attack == "all":
			this_attack = ["volley", "rain", "blink", "pulse"][int(t / 6.0) % 4]
		if atk <= 0.0:
			match this_attack:
				"volley":
					atk = 1.6
					_judgment_bolt(e.global_position, player.global_position + Vector3(0, 1.2, 0), 11.0)
				"rain":
					atk = 0.9
					_falling_stone(player.global_position + Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5)) * Vector3(1, 0, 1) + Vector3(0, ground_y, 0))
				"blink":
					atk = 2.8
					var a := randf() * TAU
					e.position = player.global_position + Vector3(cos(a) * 9.0, 3.0, sin(a) * 9.0)
					e.rebase()
					light.position = e.position
					sfx("glitch", -4)
					hud.set_fx("glitch", 0.6)
					get_tree().create_timer(0.25, false).timeout.connect(func(): hud.set_fx("glitch", 0.0))
					for k in [-0.25, 0.0, 0.25]:
						var target := player.global_position + Vector3(0, 1.2, 0)
						var dir := (target - e.global_position).normalized().rotated(Vector3.UP, k)
						_judgment_bolt(e.global_position, e.global_position + dir * 10.0, 12.0)
				"pulse":
					atk = 3.6
					_pulse(Vector3(home.x, ground_y, home.z))
	_gathering = false
	if Net.is_host():
		Net.trial_state("", "", 0.0, true)
	if not _struck_in_judgment:
		Game.reveal_deed("flawless")
	Game.reveal_deed("first_trial")
	hud.set_meter("", 0)
	hud.set_objective("")
	combat_frozen = true
	clear_enemies()
	create_tween().tween_property(heart, "volume_db", -60.0, 2.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(e, "scale", Vector3.ONE * 0.01, 1.5)
	tw.tween_property(light, "light_energy", 0.0, 1.5)
	await tw.finished
	e.queue_free()
	await get_tree().create_timer(1.0, false).timeout


func _judgment_bolt(from: Vector3, to: Vector3, speed: float) -> void:
	var b := LesserSpeeb.Bolt.new()
	b.level = self
	b.velocity = (to - from).normalized() * speed
	b.damage = 16.0
	add_child(b)
	b.global_position = from
	sfx("spit", -8, from)


func _falling_stone(at: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 8, 0), at + Vector3(0, -20, 0), 1))
	if r.is_empty():
		return
	var ground_pt: Vector3 = r.position
	var mark := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.35
	tm.outer_radius = 1.5
	mark.mesh = tm
	mark.material_override = glow_mat(Color(1.0, 0.2, 0.1), 2.0)
	mark.position = ground_pt + Vector3(0, 0.05, 0)
	mark.scale = Vector3(1, 0.05, 1)
	add_child(mark)
	var stone := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 1.6, 1.6)
	stone.mesh = bm
	stone.material_override = mat(Color(0.45, 0.43, 0.4), 0.9, 0.3, 0.5)
	stone.position = ground_pt + Vector3(0, 22, 0)
	stone.rotation = Vector3(randf(), randf(), randf())
	add_child(stone)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(stone, "position", ground_pt + Vector3(0, 0.8, 0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		sfx("crumble", -14, ground_pt)
		var d := player.global_position - ground_pt
		if Vector2(d.x, d.z).length() < 1.7 and absf(d.y) < 2.0:
			damage_player(24.0, ground_pt)
		mark.queue_free())
	tw.tween_interval(1.0)
	tw.tween_property(stone, "scale", Vector3.ONE * 0.01, 0.6)
	tw.tween_callback(stone.queue_free)


## A ring of judgment spreading across the ground. Leap over it.
func _pulse(center: Vector3) -> void:
	sfx("bell", -14)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 64
	ring.mesh = tm
	ring.material_override = glow_mat(Color(1.0, 0.85, 0.5), 3.0)
	ring.position = center + Vector3(0, 0.3, 0)
	ring.scale = Vector3(1.0, 4.0, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var hit := [false]
	var r := 0.5
	while r < 26.0 and is_inside_tree():
		await get_tree().physics_frame
		r += get_physics_process_delta_time() * 6.5 * enemy_time
		tm.inner_radius = r - 0.22
		tm.outer_radius = r + 0.22
		var d := player.global_position - center
		var dist := Vector2(d.x, d.z).length()
		if not hit[0] and absf(dist - r) < 0.55 and player.global_position.y - center.y < 0.55 and not failing:
			hit[0] = true
			damage_player(20.0, center)
	ring.queue_free()


## The Riftwalker's gift: the lesser forms move as through deep water.
func riftwalk() -> void:
	sfx("glitch", -4)
	enemy_time = 0.3
	hud.set_fx("glitch", 0.3)
	hud.set_fx("desat", 0.5)
	await get_tree().create_timer(4.5, false).timeout
	enemy_time = 1.0
	hud.set_fx("glitch", 0.0)
	hud.set_fx("desat", 0.0)


func clear_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.die(false)
	enemies.clear()
	_wave_queue.clear()
	for b in get_children():
		if b is LesserSpeeb.Bolt:
			b.queue_free()


## The account of the trial: what was done, and how it was weighed.
func show_results(verdict: String) -> void:
	var acc := float(hits) / float(maxi(shots, 1))
	var score := 0
	score += 2 if verdict == "Balanced" else 0
	score += 1 if falls == 0 else 0
	score += 1 if acc >= 0.55 else 0
	score += 1 if Game.difficulty >= 1 else 0
	score += 1 if Game.difficulty == 2 else 0
	var grade: String = ["Dust", "Ash", "Bronze", "Silver", "Gold", "Radiant", "Unblinking"][clampi(score, 0, 6)]
	var mins := int(trial_time) / 60
	var secs := int(trial_time) % 60
	var rows := [
		["Time in the land", "%d:%02d" % [mins, secs]],
		["Lesser forms undone", str(kills)],
		["Shots that found their mark", "%d%%" % roundi(acc * 100.0) if shots > 0 else "No shot fired"],
		["Falls", str(falls)],
		["Lesser forms witnessed", str(witnessed)],
		["Judgment", verdict],
	]
	await hud.show_results("The Trial Is Weighed", rows, grade)


func slow_motion(scale: float, real_secs: float) -> void:
	Engine.time_scale = scale
	hud.set_fx("desat", 0.35)
	await get_tree().create_timer(real_secs, true, false, true).timeout
	Engine.time_scale = 1.0
	hud.set_fx("desat", 0.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func damage_player(amount: float, from: Vector3) -> void:
	if failing or completed or not combat or downed or _pfail or Net.dedicated:
		return
	_struck_in_judgment = true
	player.shake(0.45)
	if Game.blessed("runespeeb") and player.ward_ready:
		player.ward_ready = false
		player.ward_cd = 20.0
		sfx("bell", -10)
		hud.notify("The Oath Ward breaks, and holds.")
		return
	amount *= Game.difficulty_scale("damage")
	player.health -= amount
	_regen_wait = 7.0
	var local := player.global_transform.basis.inverse() * (from - player.global_position)
	hud.damage_from(atan2(local.x, -local.z))
	sfx("hurt", -2)
	hud.set_health(maxf(player.health, 0.0) / player.max_health, true)
	hud.hurt_flash()
	var push := player.global_position - from
	push.y = 0
	player.velocity += push.normalized() * 3.0
	if player.health <= 0.0:
		if Net.online:
			_go_down()
		else:
			fail("Brelm fell beneath the lesser forms. Survive one, you are changed. Fall, and you begin again.", "")


## A small cloud of dust where a pellet strikes stone.
func puff(pos: Vector3, normal: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.68, 0.64, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + normal * 0.05
	var tw := create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * 3.0, 0.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)


## Fur scattering where a lesser form is undone, and motes of gold rising from it.
func burst(pos: Vector3, color: Color) -> void:
	var gold := glow_mat(Color(1.0, 0.82, 0.4), 4.0)
	for i in 10:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.04
		sm.height = 0.08
		sm.radial_segments = 6
		sm.rings = 3
		mi.mesh = sm
		mi.material_override = gold
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = pos + Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.3), randf_range(-0.4, 0.4))
		var tw := create_tween().set_parallel()
		tw.tween_property(mi, "global_position", mi.global_position + Vector3(randf_range(-0.6, 0.6), randf_range(1.2, 2.6), randf_range(-0.6, 0.6)), 1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 1.4).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.8, 0.45)
	fl.light_energy = 3.0
	fl.omni_range = 5.0
	add_child(fl)
	fl.global_position = pos
	var ft := create_tween()
	ft.tween_property(fl, "light_energy", 0.0, 0.5)
	ft.tween_callback(fl.queue_free)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	for i in 14:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * randf_range(0.06, 0.14)
		mi.mesh = bm
		mi.material_override = m
		add_child(mi)
		mi.global_position = pos
		var to := pos + Vector3(randf_range(-1, 1), randf_range(-0.6, 1.2), randf_range(-1, 1)) * 1.4
		var tw := create_tween().set_parallel()
		tw.tween_property(mi, "global_position", to, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.9)
		tw.chain().tween_callback(mi.queue_free)


func trial_tick(_delta: float) -> void:
	pass


func on_fall() -> void:
	fail("The ground gave way beneath him, and the gaze of Speeb did not waver.")


func reset_trial() -> void:
	pass


## The trial is failed: the land resets, and Brelm stands again where he last stood firm.
func fail(message: String, sound := "deny") -> void:
	if failing or completed:
		return
	life_kills = 0
	# In a fellowship a failed step sends back only the one who failed; the others walk on
	if Net.online and not _wiping:
		_personal_fail(message, sound)
		return
	failing = true
	falls += 1
	player.input_locked = true
	if sound != "":
		sfx(sound, -4)
	await hud.fade_to(1.0, 1.4)
	clear_enemies()
	_wave_queue.clear()
	_next_wave = 8.0
	hud.clear_say()
	hud.raise_text(true)
	hud.say(message, 4.5)
	await get_tree().create_timer(5.5, false).timeout
	hud.raise_text(false)
	reset_trial()
	player.place(spawn_pos, spawn_yaw)
	player.reset_max_health()
	player.weapon_reset()
	hud.set_health(1.0, combat)
	_spawn_t = 6.0
	player.input_locked = false
	failing = false
	hud.fade_to(0.0, 1.5)


## The yaw that faces from one point toward another.
func yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


func checkpoint(pos: Vector3, yaw: float) -> void:
	spawn_pos = pos
	spawn_yaw = yaw


# ------------------------------------------------------------------ environment

func setup_env(sky_top: Color, sky_horizon: Color, ground: Color, fog_color: Color, fog_density: float, ambient := 0.6, exposure := 1.0) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = sky_top
	sm.sky_horizon_color = sky_horizon
	sm.ground_bottom_color = ground
	sm.ground_horizon_color = sky_horizon
	sm.sun_angle_max = 8
	sm.sky_curve = 0.12
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = exposure
	env.fog_enabled = fog_density > 0.0
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sky_affect = 0.6
	env.fog_aerial_perspective = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func set_sky_stars(amount := 1.0) -> void:
	# A dome of distant points, for nights without moon.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	mm.mesh = q
	mm.instance_count = int(900 * amount)
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in mm.instance_count:
		var d := Vector3(r.randf_range(-1, 1), r.randf_range(0.05, 1), r.randf_range(-1, 1)).normalized() * 700.0
		var t := Transform3D(Basis.looking_at(-d), d)
		t = t.scaled_local(Vector3.ONE * r.randf_range(0.4, 1.6))
		mm.set_instance_transform(i, t)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 0.95)
	m.disable_fog = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func add_sun(rot_deg: Vector3, color: Color, energy: float, shadows := true) -> DirectionalLight3D:
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = rot_deg
	sun.light_color = color
	sun.light_energy = energy
	sun.shadow_enabled = shadows
	sun.directional_shadow_max_distance = 120
	add_child(sun)
	return sun


func omni(pos: Vector3, color: Color, energy: float, rng := 10.0, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadows
	add_child(l)
	return l


# ------------------------------------------------------------------ materials and shapes

func mat(color: Color, rough := 0.9, noise_amt := 0.35, scale := 0.25, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if noise_amt > 0.0:
		var n := FastNoiseLite.new()
		n.seed = _rng.randi()
		n.frequency = 0.02
		n.fractal_octaves = 5
		var tex := NoiseTexture2D.new()
		tex.noise = n
		tex.seamless = true
		tex.width = 256
		tex.height = 256
		var g := Gradient.new()
		g.set_color(0, Color(1 - noise_amt, 1 - noise_amt, 1 - noise_amt))
		g.set_color(1, Color(1, 1, 1))
		tex.color_ramp = g
		m.albedo_texture = tex
		var nt := NoiseTexture2D.new()
		nt.noise = n
		nt.seamless = true
		nt.as_normal_map = true
		nt.bump_strength = 6.0
		nt.width = 256
		nt.height = 256
		m.normal_enabled = true
		m.normal_texture = nt
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
	return m


func water_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.85
	m.roughness = 0.03
	return m


## A pawprint: one pad and four toes. Laid on the ground, or carved upright into a wall when upright is true.
func pawprint(pos: Vector3, yaw: float, scale: float, m: Material, upright := false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	if upright:
		n.rotation.x = PI / 2
	add_child(n)
	var parts := [[Vector2(0, 0.1), 0.32], [Vector2(-0.3, -0.25), 0.12], [Vector2(-0.11, -0.38), 0.12], [Vector2(0.11, -0.38), 0.12], [Vector2(0.3, -0.25), 0.12]]
	for p in parts:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = p[1] * scale
		cm.bottom_radius = p[1] * scale
		cm.height = 0.02
		cm.radial_segments = 20
		mi.mesh = cm
		mi.material_override = m
		mi.position = Vector3(p[0].x * scale, 0.012, p[0].y * scale)
		if p[1] > 0.2:
			mi.scale = Vector3(1.1, 1, 0.8)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	return n


func glow_mat(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _body(mi: MeshInstance3D, shape: Shape3D, collide: bool) -> MeshInstance3D:
	add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = shape
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func box(pos: Vector3, size: Vector3, m: Material, collide := true, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	var s := BoxShape3D.new()
	s.size = size
	return _body(mi, s, collide)


func cyl(pos: Vector3, radius: float, height: float, m: Material, collide := true, top := -1.0, sides := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius if top < 0 else top
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	var s: Shape3D
	if top >= 0.0 and absf(top - radius) > 0.01:
		s = cm.create_convex_shape()
	else:
		s = CylinderShape3D.new()
		s.radius = radius
		s.height = height
	return _body(mi, s, collide)


func sphere(pos: Vector3, radius: float, m: Material, collide := false, squash := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0 * squash
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	var s := SphereShape3D.new()
	s.radius = radius * squash
	return _body(mi, s, collide)


func ground(size: float, m: Material, y := 0.0) -> MeshInstance3D:
	return box(Vector3(0, y - 0.5, 0), Vector3(size, 1, size), m)


func label3d(text: String, pos: Vector3, size := 0.5, color := Color(0.9, 0.88, 0.8), yaw := 0.0, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/Marcellus-Regular.ttf")
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation.y = yaw
	l.shaded = false
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(l)
	return l


## A hooded figure, kneeling or standing: the strangers, clerics and kings of the Book.
func figure(pos: Vector3, yaw: float, robe: Color, kneel := false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	var m := mat(robe, 1.0, 0.2, 0.6)
	var h := 0.9 if kneel else 1.5
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.45
	cm.height = h
	body.mesh = cm
	body.material_override = m
	body.position.y = h * 0.5
	n.add_child(body)
	var hood := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.5
	hood.mesh = sm
	hood.material_override = m
	hood.position = Vector3(0, h + 0.15, 0.03)
	n.add_child(hood)
	var face := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.15
	fm.height = 0.3
	face.mesh = fm
	face.material_override = mat(Color(0.02, 0.02, 0.02), 1.0, 0.0)
	face.position = Vector3(0, h + 0.12, 0.12)
	n.add_child(face)
	if kneel:
		n.rotation.x = 0.0
		body.rotation_degrees.x = 12
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = h + 0.4
	cs.shape = cap
	cs.position.y = (h + 0.4) * 0.5
	sb.add_child(cs)
	n.add_child(sb)
	n.set_meta("body", sb)
	return n


# ------------------------------------------------------------------ interaction

## A shared interaction is taken by the whole fellowship, in the order the host receives it.
## Personal ones (a leaf, a relic, a lesser form witnessed) belong to the one who reaches for them.
func make_interactable(obj: CollisionObject3D, prompt: String, cb: Callable, hold := 0.0, shared := true) -> void:
	obj.set_meta("prompt", prompt)
	obj.set_meta("hold", hold)
	if Net.online and shared:
		var id := _net_events.size()
		_net_events.append({"cb": cb, "obj": obj, "trigger": false})
		obj.set_meta("on_interact", func(): Net.event(id))
	else:
		obj.set_meta("on_interact", cb)


func personal_interactable(obj: CollisionObject3D, prompt: String, cb: Callable, hold := 0.0) -> void:
	make_interactable(obj, prompt, cb, hold, false)


func interact_area(pos: Vector3, radius: float, prompt: String, cb: Callable, hold := 0.0, shared := true) -> Area3D:
	var a := Area3D.new()
	a.position = pos
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	cs.shape = s
	a.add_child(cs)
	add_child(a)
	make_interactable(a, prompt, cb, hold, shared)
	return a


func trigger_area(pos: Vector3, size: Vector3, cb: Callable, once := true, shared := true) -> Area3D:
	var a := Area3D.new()
	a.position = pos
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	a.add_child(cs)
	add_child(a)
	var fired := [false]
	if Net.online and shared:
		# Whoever crosses first carries the whole fellowship with them
		var id := _net_events.size()
		var ev := {"cb": cb, "obj": a, "trigger": true, "once": once, "fired": fired}
		_net_events.append(ev)
		a.body_entered.connect(func(b):
			if b is Player and not (once and fired[0]):
				Net.event(id))
		return a
	a.body_entered.connect(func(b):
		if b is Player and not (once and fired[0]):
			fired[0] = true
			cb.call())
	return a


## A lesser form of Speeb, hidden in the land, waiting to be recorded in the Book of Emojis.
func lesser(code: String, pos: Vector3, size := 1.4) -> Emoji3D:
	if not Game.lesser.has(code):
		return null
	pos.y += 0.35
	var e := Emoji3D.new().setup(code, size)
	e.position = pos
	e.bob = 0.08
	e.glow = 0.3
	add_child(e)
	_shrines.append(e)
	# A golden halo marks the forms that are to be witnessed, not fought
	var halo := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.26 * size
	tm.outer_radius = 0.31 * size
	halo.mesh = tm
	halo.material_override = glow_mat(Color(1.0, 0.8, 0.35), 4.0)
	halo.position = pos + Vector3(0, size * 0.72, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	var l := omni(pos + Vector3(0, size * 0.5, 0.4), Color(1.0, 0.85, 0.55), 1.2, 4.5)
	var info: Dictionary = Game.lesser[code]
	var seen := Game.found.has(code)
	var a := interact_area(pos, size * 0.55, "Witness :%s:" % code if not seen else "%s (recorded)" % info.name, func(): pass, 0.0, false)
	if seen:
		a.set_meta("recorded", true)
	personal_interactable(a, a.get_meta("prompt"), func():
		var fresh := Game.find_emoji(code)
		if not a.has_meta("recorded"):
			a.set_meta("recorded", true)
			witnessed += 1
		hud.notify("%s\n%s" % [info.name, info.decree] if fresh else info.name)
		sfx("bell", -18 if fresh else -26)
		a.set_meta("prompt", "%s (recorded)" % info.name))
	lesser_codes.append(code)
	return e


# ------------------------------------------------------------------ the other hermit

func _haunted() -> bool:
	return combat and Game.level_index >= 1 and Game.level_index <= 9 and not failing and not _gathering and not player.input_locked


func _velm_tick(delta: float) -> void:
	if velm == null:
		velm = Velm.new()
		velm.visible = false
		add_child(velm)
	# Footsteps behind him when he stands still, which stop when he turns
	if player.cur_speed < 0.2:
		_still_t += delta
	else:
		_still_t = 0.0
	_steps_t -= delta
	if _steps_t <= 0.0 and _still_t > 1.5:
		_steps_t = randf_range(30.0, 55.0)
		var behind := player.global_position + player.global_transform.basis.z * 4.0
		for i in 3:
			get_tree().create_timer(i * 0.55, false).timeout.connect(func(): sfx("step", 2, behind - player.global_transform.basis.z * (i * 0.5), 0.8))
	if velm_scripted:
		return
	if velm.visible:
		_velm_shown += delta
		velm.rotation.y = yaw_to(velm.global_position, player.global_position) + PI
		var to := velm.global_position + Vector3(0, 1.6, 0) - player.cam.global_position
		var fwd := -player.cam.global_transform.basis.z
		if fwd.dot(to.normalized()) > 0.985:
			_velm_looked += delta
		if _velm_looked > 0.5 or to.length() < 12.0 or _velm_shown > 14.0:
			velm.vanish()
			sfx("ripple", -14, null, 0.6)
			if not Game.stats.has("velm_seen"):
				Game.stats["velm_seen"] = 1
				hud.say("A hooded figure stood in the distance, watching. When he looked again, there was no one.", 6.0)
		return
	_velm_t -= delta
	if _velm_t > 0.0:
		return
	_velm_t = randf_range(40.0, 80.0)
	var at = _velm_spot()
	if at == null:
		return
	velm.global_position = at
	velm.rotation.y = yaw_to(at, player.global_position) + PI
	_velm_shown = 0.0
	_velm_looked = 0.0
	velm.appear(2.0)


## Somewhere in sight but far off, on firm ground.
func _velm_spot():
	var space := get_world_3d().direct_space_state
	var fwd := -player.global_transform.basis.z
	fwd.y = 0
	for attempt in 24:
		var a := atan2(fwd.x, fwd.z) + randf_range(-1.0, 1.0)
		var d := randf_range(18.0, 30.0)
		var p := player.global_position + Vector3(sin(a) * d, 4.0, cos(a) * d)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -12, 0), 1))
		if hit.is_empty() or hit.normal.y < 0.7:
			continue
		var head: Vector3 = hit.position + Vector3(0, 1.8, 0)
		var los := PhysicsRayQueryParameters3D.create(player.cam.global_position, head, 1)
		los.exclude = [player.get_rid()]
		if not space.intersect_ray(los).is_empty():
			continue
		return hit.position
	return null


# ------------------------------------------------------------------ the unblinking eye

func _eye_tick(delta: float) -> void:
	if eye_watching or combat_frozen or (Net.online and not Net.is_host()):
		return
	_eye_t -= delta
	if _eye_t <= 0.0:
		_eye_t = randf_range(110.0, 170.0)
		if Net.online:
			Net.eye()
		else:
			_unblinking_eye()


## The world stops. An eye opens in the sky. Brelm must not move until it has finished judging.
func _unblinking_eye() -> void:
	if eye_watching:
		return
	eye_watching = true
	eye_seen_by_any = false
	_eye_verdict = -1
	var was_frozen := combat_frozen
	combat_frozen = true
	var eye := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(90, 90)
	eye.mesh = qm
	var em := ShaderMaterial.new()
	em.shader = preload("res://scripts/eye.gdshader")
	eye.material_override = em
	eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(eye)
	var fwd := -player.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	eye.global_position = player.global_position + fwd * 140.0 + Vector3(0, 55.0, 0)
	eye.look_at(player.global_position + Vector3(0, 1.6, 0), Vector3.UP)
	eye.rotate_object_local(Vector3.UP, PI)
	for p in _ambient:
		create_tween().tween_property(p, "volume_db", p.volume_db - 30.0, 1.0)
	var saved_db: Array = _ambient.map(func(p): return p.volume_db)
	sfx("deny", -2, null, 0.6)
	var heart := ambient("heartbeat", -6)
	hud.set_fx("desat", 0.7)
	hud.set_fx("vignette", 0.7)
	hud.say("The world stopped. Far above, something opened.\nBe still.", 4.0)
	var tw := create_tween()
	tw.tween_method(func(v): em.set_shader_parameter("open", v), 0.0, 1.0, 2.0).set_trans(Tween.TRANS_SINE)
	await tw.finished
	var seen := false
	var t := 0.0
	var start := player.global_position
	while t < 5.0:
		await get_tree().physics_frame
		if failing or completed or not is_instance_valid(eye):
			break
		t += get_physics_process_delta_time()
		em.set_shader_parameter("pupil", 0.18 + sin(t * 0.8) * 0.03)
		if not Net.dedicated and not downed and (player.cur_speed > 0.6 or player.global_position.distance_to(start) > 0.8 or Input.is_action_pressed("fire") or Input.is_action_just_pressed("jump")):
			seen = true
			break
		if eye_seen_by_any or _eye_verdict >= 0:
			break
	# In a fellowship, one who moves is seen for all
	if Net.online:
		if Net.is_host():
			var w := 0.0
			while w < 0.4 and not seen:
				await get_tree().physics_frame
				w += get_physics_process_delta_time()
				seen = seen or eye_seen_by_any
			seen = seen or eye_seen_by_any
			Net.eye_result(seen)
		else:
			if seen:
				Net.eye_seen()
			var w := 0.0
			while _eye_verdict < 0 and w < 4.0 and Net.online:
				await get_tree().physics_frame
				w += get_physics_process_delta_time()
			if _eye_verdict >= 0:
				seen = _eye_verdict == 1
	var tw2 := create_tween()
	tw2.tween_method(func(v): em.set_shader_parameter("open", v), 1.0, 0.0, 0.35 if not seen else 0.9)
	await tw2.finished
	eye.queue_free()
	heart.queue_free()
	_ambient.erase(heart)
	for i in _ambient.size():
		create_tween().tween_property(_ambient[i], "volume_db", saved_db[i] + 30.0, 2.0)
	hud.set_fx("desat", 0.0)
	hud.set_fx("vignette", 0.35)
	if not _gathering:
		combat_frozen = was_frozen
	eye_watching = false
	if failing or completed or _gathering:
		return
	if seen:
		sfx("roar", -6, null, 0.6)
		hud.set_fx("dark", 0.5)
		create_tween().tween_method(func(v): hud.set_fx("dark", v), 0.5, 0.0, 3.0)
		hud.say("Speeb saw. And the lesser forms were loosed upon him.", 5.0)
		_begin_wave(wave_size() + 2, true)
		_next_wave = wave_timeout
	else:
		sfx("bell", -8)
		hud.say("Speeb blinked. Nothing was asked of him, and he had given nothing.", 5.0)
		if player.relics:
			player.relics.add_faith(0.35)
		Game.reveal_deed("stillness")


# ------------------------------------------------------------------ the margins

const Story := preload("res://scripts/story.gd")


func _key() -> String:
	return Game.LEVELS[Game.level_index]


## A free, floored spot at roughly the given distance from where Brelm begins.
func _find_spot(rmin: float, rmax: float, seed_i: int) -> Variant:
	var space := get_world_3d().direct_space_state
	var r := RandomNumberGenerator.new()
	r.seed = 977 + seed_i
	for attempt in 60:
		var a := r.randf() * TAU
		var d := r.randf_range(rmin, rmax) * (1.0 - attempt / 90.0)
		var p := spawn_pos + Vector3(cos(a) * d, 2.5, sin(a) * d)
		var ray := PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -6, 0), 1)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or absf(hit.position.y - spawn_pos.y) > 2.5 or hit.normal.y < 0.8:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.8
		q.shape = sh
		q.transform = Transform3D(Basis(), hit.position + Vector3(0, 1.1, 0))
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			continue
		var los := PhysicsRayQueryParameters3D.create(spawn_pos + Vector3(0, 1.2, 0), hit.position + Vector3(0, 1.0, 0), 1)
		if not space.intersect_ray(los).is_empty() and seed_i == 0:
			continue
		return hit.position
	return null


func _place_story() -> void:
	var k := _key()
	if not (Story.SHADES.has(k) or Story.LEAVES.has(k)):
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if Story.SHADES.has(k):
		var at = _find_spot(3.5, 6.0, 0)
		if at != null:
			_shade(k, at)
	if Story.LEAVES.has(k) and not Game.leaves.has(k):
		var at = _find_spot(9.0, 18.0, 1)
		if at != null:
			_leaf(k, at)


## A wayfarer's shade: pale, hooded, and willing to speak to one who stops.
func _shade(k: String, at: Vector3) -> void:
	var d: Dictionary = Story.SHADES[k]
	var f := figure(at, yaw_to(at, spawn_pos), Color(0.55, 0.58, 0.64))
	for c in f.find_children("*", "MeshInstance3D", true, false):
		var m: StandardMaterial3D = c.material_override.duplicate()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.55
		m.emission_enabled = true
		m.emission = Color(0.35, 0.4, 0.5)
		m.emission_energy_multiplier = 0.4
		c.material_override = m
	omni(at + Vector3(0, 2.2, 0.4), Color(0.7, 0.78, 0.95), 0.8, 5.0)
	var body: StaticBody3D = f.get_meta("body")
	# A shade does not bar the way; only the gaze finds it
	body.collision_layer = 16
	var line := [0]
	var speaking := [false]
	personal_interactable(body, "Hear %s" % d.name.to_lower(), func():
		if speaking[0]:
			return
		speaking[0] = true
		var lines: Array = d.lines
		hud.say("%s:\n\"%s\"" % [d.name, lines[line[0]]], 7.0)
		sfx("bell", -24)
		line[0] += 1
		if line[0] >= lines.size():
			line[0] = 0
			Game.shades_heard[k] = true
			Game.save()
			if Game.shades_heard.size() >= Story.SHADES.size():
				Game.reveal_deed("shades")
		await get_tree().create_timer(1.5, false).timeout
		speaking[0] = false)


## A Leaf of the Hermit's journal, fallen where he once stood.
func _leaf(k: String, at: Vector3) -> void:
	var n := Node3D.new()
	n.position = at + Vector3(0, 1.0, 0)
	add_child(n)
	var page := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.42, 0.01)
	page.mesh = bm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.88, 0.82, 0.66)
	pm.emission_enabled = true
	pm.emission = Color(1.0, 0.85, 0.55)
	pm.emission_energy_multiplier = 0.5
	page.material_override = pm
	page.rotation.z = 0.15
	n.add_child(page)
	for i in 4:
		var ink := MeshInstance3D.new()
		var im := BoxMesh.new()
		im.size = Vector3(0.22 - (0.06 if i == 3 else 0.0), 0.012, 0.012)
		ink.mesh = im
		ink.material_override = mat(Color(0.15, 0.1, 0.08), 1.0, 0.0)
		ink.position = Vector3(0, 0.12 - i * 0.07, 0.006)
		page.add_child(ink)
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "rotation:y", TAU, 9.0).from(0.0)
	var bob := n.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bob.tween_property(n, "position:y", n.position.y + 0.15, 1.8)
	bob.tween_property(n, "position:y", n.position.y, 1.8)
	var l := omni(at + Vector3(0, 1.4, 0), Color(1.0, 0.85, 0.55), 1.0, 4.0)
	var a := interact_area(at + Vector3(0, 1.0, 0), 0.7, "Read the leaf", func(): pass, 0.0, false)
	var d: Array = Story.LEAVES[k]
	personal_interactable(a, "Read the leaf", func():
		Game.leaves[k] = true
		Game.save()
		sfx("carve", -8)
		hud.notify("%s of the Hermit's journal\n(%d of %d gathered)" % [d[0], Game.leaves.size(), Story.LEAVES.size()])
		hud.say("\"%s\"" % d[1], 11.0)
		if Game.leaves.size() >= Story.LEAVES.size():
			Game.reveal_deed("leaves")
		n.queue_free()
		l.queue_free()
		a.queue_free())


# ------------------------------------------------------------------ relics

## A ring of old iron that the Claw of Ascent can hold. Brelm is drawn to the landing beneath it.
func anchor(pos: Vector3, landing: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.55
	ring.mesh = tm
	ring.material_override = mat(Color(0.35, 0.3, 0.26), 0.5, 0.2, 0.25, 0.8)
	ring.rotation.x = PI / 2
	n.add_child(ring)
	var glow := MeshInstance3D.new()
	var gm := TorusMesh.new()
	gm.inner_radius = 0.56
	gm.outer_radius = 0.6
	glow.mesh = gm
	glow.material_override = glow_mat(Color(1.0, 0.85, 0.5), 2.0)
	glow.rotation.x = PI / 2
	n.add_child(glow)
	omni(pos, Color(1.0, 0.85, 0.55), 1.0, 5.0)
	n.set_meta("landing", landing)
	anchors.append(n)
	return n


## Hides a thing from the eye; the censer's smoke shows it for a while.
func veil(node: Node3D) -> void:
	node.visible = false
	_veiled.append({"node": node, "t": 0.0})


func cense(at: Vector3, reach: float) -> void:
	for v in _veiled:
		if is_instance_valid(v.node) and v.node.global_position.distance_to(at) < reach:
			if v.t <= 0.0:
				v.node.visible = true
			v.t = 7.0


## A relic set upon the road, glowing, to be taken up once.
func relic_pickup(id: String, pos: Vector3) -> void:
	if Game.relics.has(id):
		return
	var maker := Relics.new()
	var model: Node3D = maker.call("_build_" + id)
	maker.free()
	model.position = pos
	model.scale = Vector3.ONE * 4.0
	add_child(model)
	var tw := model.create_tween().set_loops()
	tw.tween_property(model, "rotation:y", TAU, 6.0).from(0.0)
	var halo := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.48
	halo.mesh = tm
	halo.material_override = glow_mat(Color(1.0, 0.8, 0.35), 3.0)
	halo.position = pos + Vector3(0, 1.3, 0)
	add_child(halo)
	var l := omni(pos + Vector3(0, 0.8, 0.5), Color(1.0, 0.85, 0.55), 1.6, 6.0)
	var a := interact_area(pos + Vector3(0, 0.4, 0), 0.9, "Take up the %s" % Game.RELIC_NAMES[id], func(): pass, 0.0, false)
	personal_interactable(a, a.get_meta("prompt"), func():
		Game.gain_relic(id)
		sfx("relic", -2)
		hud.notify("%s  [%d]\n%s" % [Game.RELIC_NAMES[id], Game.RELICS.find(id) + 1, Game.RELIC_TEXT[id]])
		model.queue_free()
		halo.queue_free()
		l.queue_free()
		a.queue_free()
		player.relics.select(Game.RELICS.find(id)))


## A bowl of milk left as an offering. Brelm may carry three.
func milk_pickup(at: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3(0, -20, 0), 1))
	var pos: Vector3 = r.position + Vector3(0, 0.3, 0) if not r.is_empty() else at
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	cs.shape = sh
	a.add_child(cs)
	var maker := Relics.new()
	var model: Node3D = maker._build_milk()
	maker.free()
	model.position = Vector3.ZERO
	model.scale = Vector3.ONE * 3.0
	a.add_child(model)
	var l := OmniLight3D.new()
	l.light_color = Color(0.95, 0.95, 1.0)
	l.light_energy = 0.9
	l.omni_range = 2.5
	a.add_child(l)
	add_child(a)
	a.global_position = pos
	a.body_entered.connect(func(b):
		if b is Player and Game.milk < Game.MILK_MAX:
			Game.milk += 1
			Game.save()
			sfx("relic", -10)
			hud.notify("A bowl of milk  (%d)  [6]" % Game.milk)
			if b.relics:
				b.relics.refresh()
			a.queue_free())


# ------------------------------------------------------------------ sound

## A small light carried at Brelm's side, for the dark places.
func lantern(energy := 1.2, color := Color(1.0, 0.8, 0.55)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 9
	l.shadow_enabled = true
	l.position = Vector3(0.3, -0.25, -0.2)
	player.head.add_child(l)
	return l


## A carved rune of thin glowing strokes, upon a face pointing along +Z of the given basis.
func rune(pos: Vector3, yaw: float, scale: float, m: Material) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	var strokes := 2 + _rng.randi() % 3
	for i in strokes:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07 * scale, _rng.randf_range(0.5, 1.0) * scale, 0.04)
		mi.mesh = bm
		mi.material_override = m
		mi.position = Vector3(_rng.randf_range(-0.3, 0.3) * scale, _rng.randf_range(-0.2, 0.2) * scale, 0)
		mi.rotation.z = [0.0, 0.0, 0.6, -0.6, PI / 2][_rng.randi() % 5]
		n.add_child(mi)
	return n


func ambient(name: String, vol_db := -6.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s = load("res://assets/audio/%s.ogg" % name)
	s.loop = true
	p.stream = s
	p.bus = "World"
	p.volume_db = vol_db
	p.autoplay = true
	add_child(p)
	_ambient.append(p)
	return p


static var _takes := {}   ## each sound's recorded takes: name -> [streams]


## The takes of a sound: name_1, name_2 ... if there are several, else the one file.
static func takes_of(name: String) -> Array:
	if _takes.has(name):
		return _takes[name]
	var out: Array = []
	var i := 1
	while ResourceLoader.exists("res://assets/audio/%s_%d.ogg" % [name, i]):
		out.append(load("res://assets/audio/%s_%d.ogg" % [name, i]))
		i += 1
	if out.is_empty():
		var path := "res://assets/audio/%s.wav" % name
		if not ResourceLoader.exists(path):
			path = "res://assets/audio/%s.ogg" % name
		if ResourceLoader.exists(path):
			out.append(load(path))
	_takes[name] = out
	return out


var hush := false   ## while true no sound is made (the shader warm-up under the opening fade)


func sfx(name: String, vol_db := 0.0, pos = null, pitch := 1.0) -> void:
	if hush:
		return
	# Heard from far off, a shot has its own recording: the crack gone, the roll of it left
	if pos != null and get_viewport().get_camera_3d() and get_viewport().get_camera_3d().global_position.distance_to(pos) > 35.0 \
			and not takes_of(name + "_far").is_empty():
		name += "_far"
	var all := takes_of(name)
	if all.is_empty():
		return
	var s = all[randi() % all.size()]
	if all.size() > 1:
		pitch *= randf_range(0.97, 1.03)
		vol_db += randf_range(-1.0, 0.5)
	var bus := Game.bus_of(name)
	if pos == null:
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.bus = bus
		p.volume_db = vol_db
		p.pitch_scale = pitch
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
	else:
		# No more than MAX_VOICES at once: a new sound takes the place of the faintest, or is not heard
		var loud := _heard_db(vol_db, pos)
		_voices = _voices.filter(func(v): return is_instance_valid(v) and v.playing)
		if _voices.size() >= MAX_VOICES:
			var qi := -1
			var qd := INF
			for i in _voices.size():
				var d := _heard_db(_voices[i].volume_db, _voices[i].global_position)
				if d < qd:
					qd = d
					qi = i
			if qi < 0 or qd >= loud:
				return
			_voices[qi].queue_free()
			_voices.remove_at(qi)
		var p := AudioStreamPlayer3D.new()
		p.stream = s
		p.bus = bus
		p.volume_db = vol_db
		p.position = pos
		p.pitch_scale = pitch
		p.unit_size = 8
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		_voices.append(p)


const MAX_VOICES := 32   ## sounds in the world playing at once
var _voices: Array = []


## Roughly how loud a sound is where the listener stands, for choosing which to drop.
func _heard_db(vol_db: float, at: Vector3) -> float:
	var cam := get_viewport().get_camera_3d()
	var d := cam.global_position.distance_to(at) if cam else 0.0
	return vol_db - 20.0 * log(maxf(d, 8.0) / 8.0) / log(10.0)


func fade_ambient(to_db: float, dur := 2.0) -> void:
	for p in _ambient:
		create_tween().tween_property(p, "volume_db", to_db, dur)


# ------------------------------------------------------------------ revelation

## The Meowifestation descends. Its decree is spoken. Then Brelm goes on.
func reveal(code: String, pos: Vector3, size := 3.0, descend := true, then := Callable(), present: Emoji3D = null) -> Emoji3D:
	if not completed and not Net.dedicated:
		Game.gain_pxp(400)
	completed = true
	if downed:
		_rise(1.0)
	player.input_locked = true
	clear_enemies()
	hud.set_health(1.0, false)
	hud.set_objective("")
	hud.set_meter("", 0)
	hud.clear_say()
	Game.find_emoji(code)
	var verdict := Game.judge(Game.level_index, kills, falls, witnessed)
	var nine_seen := 0
	for c in Game.NINE:
		if Game.found.has(c):
			nine_seen += 1
	if nine_seen >= 9:
		Game.reveal_deed("all_nine")
	if Game.balanced_count() >= 3:
		Game.reveal_deed("balanced")
	if Game.difficulty == 2:
		Game.reveal_deed("unblinking")
	var e := present
	if e == null:
		e = Emoji3D.new().setup(code, size, size * 0.12)
		e.position = pos + (Vector3(0, 8, 0) if descend else Vector3.ZERO)
		e.glow = 0.0
		add_child(e)
		if not descend:
			e.scale = Vector3.ONE * 0.01
	e.face_target = player
	var l := omni(pos + Vector3(0, 0, 0), Color(1, 0.97, 0.9), 0.0, size * 5.0)
	var halo := omni(pos + Vector3(0, size, 0), Color(1, 0.95, 0.85), 0.0, size * 3.0)
	player.look_toward(pos, 2.5)
	sfx("bell", -2)
	fade_ambient(-30, 4.0)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if present:
		tw.tween_interval(4.0)
	elif descend:
		tw.tween_property(e, "position", pos, 5.0)
	else:
		tw.tween_property(e, "scale", Vector3.ONE, 4.0)
	tw.tween_property(l, "light_energy", 1.4, 4.0)
	tw.tween_property(halo, "light_energy", 0.9, 4.0)
	tw.tween_method(e.set_glow, e.glow, 0.22, 4.0)
	await tw.finished
	e.rebase()
	e.bob = 0.06
	var voice := AudioStreamPlayer.new()
	voice.stream = load("res://assets/audio/voice/%s.mp3" % code)
	add_child(voice)
	voice.play()
	hud.show_reveal(code)
	if Game.BLESSINGS.has(code):
		var b: Array = Game.BLESSINGS[code]
		hud.notify("Blessing received: %s\n%s" % [b[0], b[1]])
	if then.is_valid():
		await then.call(e)
	var waited := 0.0
	var shown := false
	while true:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > 8.0 and not shown:
			shown = true
			hud.reveal_hint.text = "Judgment of this trial: %s      [%s]  Continue the pilgrimage" % [verdict, Game.key_text("interact")]
		if shown and Input.is_action_just_pressed("interact"):
			break
		if not voice.playing and waited > 8.0:
			await get_tree().create_timer(3.0, false).timeout
			break
	hud.hide_reveal()
	create_tween().tween_property(voice, "volume_db", -60.0, 2.5)
	await show_results(verdict)
	if Net.online and not Net.is_host():
		hud.say("The fellowship waits upon %s to walk on." % Net.server_name, 30.0)
	Game.main.next_level()
	return e


# ------------------------------------------------------------------ the fellowship

## Something for the other pilgrims to stand near; on a dedicated server the ghost walks with whoever is there.
func focus_pos() -> Vector3:
	var t := targets()
	if t.is_empty():
		return player.global_position
	return t[randi() % t.size()].global_position


const FOE_SYNC_NEAR := 170.0    ## a pilgrim is told of the foes within this far (a great one, further)
const FOE_SYNC_MAX := 48        ## and of at most this many, the nearest first
const FOE_SYNC_BATCH := 12      ## in packets of this many, so each fits in one network packet (about 80 bytes a foe, under 1392)

## Host: each pilgrim hears only of the foes near them, nearest first, in small packets. A foe a
## pilgrim is not told of for a while fades from their world, and comes back when it is near again.
func _send_foes_near(live: Array) -> void:
	var states := {}
	for id in avatars:
		var a = avatars[id]
		if not is_instance_valid(a):
			continue
		var at: Vector3 = a.global_position
		var near := []
		for e in live:
			var d: float = (e.global_position as Vector3).distance_to(at)
			var reach := FOE_SYNC_NEAR * (2.5 if str(e.get("boss")) != "" else 1.0)
			if d < reach:
				near.append([d, e])
		near.sort_custom(func(x, y): return x[0] < y[0])
		var batch := []
		for k in mini(near.size(), FOE_SYNC_MAX):
			var e = near[k][1]
			if not states.has(e):
				states[e] = e.net_state()
			batch.append(states[e])
			if batch.size() >= FOE_SYNC_BATCH:
				Net.send_foes_to(int(id), batch)
				batch = []
		if not batch.is_empty():
			Net.send_foes_to(int(id), batch)


## Who the lesser forms may hunt: every pilgrim still standing.
func targets() -> Array:
	var out := []
	if not Net.dedicated and not downed and not _pfail:
		out.append(player)
	for id in avatars:
		var a = avatars[id]
		if is_instance_valid(a) and a.visible and not a.downed:
			out.append(a)
	return out


## A loud thing happened at a place: every foe that listens and is near enough hears it.
func noise(at: Vector3, radius: float) -> void:
	for e in enemies:
		if is_instance_valid(e) and e.has_method("hear"):
			e.hear(at, radius)


func nearest_target(from: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for t in targets():
		if sheltered(t.global_position):
			continue
		var d: float = from.distance_squared_to(t.global_position)
		if d < bd:
			bd = d
			best = t
	return best


## Whether one standing here is beyond any foe's reach (the open world's settlements).
func sheltered(_p: Vector3) -> bool:
	return false


## How much harder the foes strike just now (the open world's nights).
func foe_harm() -> float:
	return 1.0


func hurt_target(t: Node3D, amount: float, from: Vector3) -> void:
	if sheltered(t.global_position):
		return
	amount *= foe_harm()
	if t == player:
		damage_player(amount, from)
	elif t is Companion:
		Net.hurt(t.peer_id, amount, from)


## The dedicated server's own pilgrim is a ghost: unseen, untouchable, walking with the fellowship.
func _ghost() -> void:
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.cam.current = false


func _ghost_tick() -> void:
	for id in avatars:
		var a = avatars[id]
		if is_instance_valid(a) and a.visible:
			player.global_position = a.global_position
			player.yaw = a.rotation.y - PI
			return


## Your cat as friends see it: under you while you ride ("face|barding"), or where it waits ("face|barding|@|x|y|z|turn").
func _cat_pose() -> String:
	if player.mount:
		return "%s|%s" % [player.mount.face, player.mount.barding]
	var c = get("cat")
	if c != null and is_instance_valid(c) and c.is_inside_tree():
		var p: Vector3 = c.global_position
		return "%s|%s|@|%.2f|%.2f|%.2f|%.2f" % [c.face, c.barding, p.x, p.y, p.z, c.rotation.y]
	return ""


var _beat_t := 1.0
var _host_quiet := false

## Who has gone quiet: a pilgrim not heard from for ten seconds stops standing about in the world (and
## being hunted), and the host's silence is said on screen instead of the world simply freezing.
func _silence_tick(delta: float) -> void:
	_beat_t -= delta
	if _beat_t > 0.0:
		return
	_beat_t = 1.0
	if Net.is_host():
		Net.beat()
	for id in avatars:
		var a = avatars[id]
		if is_instance_valid(a) and a.visible and Net.silent_for(int(id)) > 10.0:
			a.visible = false   # comes back with its next pose
	if not Net.is_host() and not Net.dedicated:
		var quiet: bool = Net.silent_for(1) > 4.0
		if quiet and not _host_quiet:
			hud.notify("The host is not answering. Waiting for them...")
		elif not quiet and _host_quiet:
			hud.notify("The host answers again.")
		_host_quiet = quiet


func _net_tick(delta: float) -> void:
	_silence_tick(delta)
	_pose_t -= delta
	if _pose_t <= 0.0 and not Net.dedicated:
		_pose_t = 0.05
		var r = player.relics
		Net.send_pose([player.global_position, player.yaw, player.pitch, downed, player.health / player.max_health,
			r.current() if r and player.armed else "", player.armed, r.lantern_lit if r else false,
			player.weapon.gun() if player.weapon else "shotgun",
			Game.mounts_of(player.weapon.gun()) if player.weapon else [],
			_cat_pose()])
	if Net.is_host():
		_foes_t -= delta
		if _foes_t <= 0.0:
			_foes_t = 1.0 / 15.0
			var live := []
			for id in foes.keys():
				var e = foes[id]
				if not is_instance_valid(e) or not e.is_alive():
					foes.erase(id)
					continue
				live.append(e)
			_send_foes_near(live)
	else:
		# A form the host has not spoken of for a while is gone
		var now := Time.get_ticks_msec()
		for id in foes.keys():
			var e = foes[id]
			if not is_instance_valid(e):
				foes.erase(id)
			elif now - e.heard_at > 4000:   # out of reach for a while (or packets lost): let it go
				foes.erase(id)
				e.die(false)
	_roster_t -= delta
	if _roster_t <= 0.0:
		_roster_t = 0.25
		var rows := []
		if Net.online:
			for id in Net.players:
				var nm: String = Net.name_of(id) + ("  ·  Renown %d" % int(renowns[id]) if int(renowns.get(id, 0)) > 0 else "")
				if id == Net.me():
					rows.append([nm, player.health / player.max_health, downed, Net.color_of(id), "you"])
				elif avatars.has(id) and is_instance_valid(avatars[id]):
					var a = avatars[id]
					var tag := squad_tag(id)
					rows.append([nm, a.hp, a.downed, Net.color_of(id), "%d m" % int(a.global_position.distance_to(player.global_position)) + ("  squad" if tag != "" else "")])
				else:
					rows.append([nm, 1.0, false, Net.color_of(id), ""])
		hud.set_fellowship(rows)
		_watch_roster()


## A word shown beside a companion in the fellowship's list (the waste marks squadmates).
func squad_tag(_id: int) -> String:
	return ""


## Says on screen when someone joins or leaves the fellowship.
func _watch_roster() -> void:
	if not Net.online:
		_known.clear()
		return
	var now := {}
	for id in Net.players:
		now[id] = Net.name_of(id)
	if _known.is_empty():
		_known = now
		return
	for id in now:
		if not _known.has(id):
			hud.feed("%s joined" % now[id], Net.color_of(id).lightened(0.3))
	for id in _known:
		if not now.has(id):
			hud.feed("%s left" % _known[id], Color(0.7, 0.68, 0.64))
	_known = now


func net_pose(id: int, data: Array) -> void:
	if not Net.players.has(id):
		return
	var a = avatars.get(id)
	if a == null or not is_instance_valid(a):
		a = Companion.new().setup(id)
		add_child(a)
		avatars[id] = a
	a.pose(data)
	if Net.is_host():
		var was: bool = _down_peers.get(id, false)
		_down_peers[id] = a.downed
		if a.downed and not was:
			_check_wipe()


func net_joined(_id: int) -> void:
	pass


func net_left(id: int) -> void:
	if avatars.has(id):
		if is_instance_valid(avatars[id]):
			avatars[id].queue_free()
		avatars.erase(id)
	_down_peers.erase(id)
	if Net.is_host():
		_check_wipe()


## Each pilgrim's renown, shown beside their name in the fellowship list (the waste's own; peer -> steps).
var renowns := {}
func _w_renown(by: int, n: int) -> void:
	renowns[by] = n


func net_fx(id: int, kind: String, a: Vector3, b: Vector3) -> void:
	var av = avatars.get(id)
	if kind.begins_with("gun:"):
		# Another pilgrim's shot: its sound, its flash, and where it struck
		var parts := kind.split(":")
		var g: Dictionary = ArmsDB.GUNS.get(parts[1], ArmsDB.GUNS.shotgun)
		var quiet := parts.size() > 2
		if g.mode == "flame":
			# Their flamethrower roars where they stand for as long as it keeps coming
			Arms.flame_jet(self, a + b * 0.9 - Vector3(0, 0.25, 0), b, true)
			if av and is_instance_valid(av):
				var fs: AudioStreamPlayer3D = av.get_node_or_null("FlameRoar")
				if fs == null:
					fs = AudioStreamPlayer3D.new()
					fs.name = "FlameRoar"
					fs.stream = Arms.flame_loop()
					fs.unit_size = 10
					fs.volume_db = Arms.FLAME_DB + 3.0
					fs.bus = Game.bus_of("flame")
					av.add_child(fs)
				if not fs.playing:
					fs.play()
				fs.set_meta("until", Time.get_ticks_msec() + 350)
				get_tree().create_timer(0.4, false).timeout.connect(func():
					if is_instance_valid(fs) and Time.get_ticks_msec() >= int(fs.get_meta("until", 0)):
						fs.stop())
			return
		sfx("supp" if quiet else str(g.sound), -10 if quiet else Arms.shot_db(str(g.sound)) - 6.0, a)
		if av and is_instance_valid(av) and not quiet:
			av.muzzle()
		if g.mode == "rocket":
			var r := Arms.Rocket.new()
			r.shown_only = true
			r.vel = b * float(g.speed)
			add_child(r)
			r.global_position = a + b * 0.9
			return
		# Their spent case flies out of the side of the gun, for everyone to see
		var cd := Arms.case_delay(parts[1])
		if cd >= 0.0 and player and a.distance_to(player.global_position) < 60.0:
			var fwd := b.normalized()
			var right := fwd.cross(Vector3.UP).normalized()
			if right.length() < 0.5:
				right = Vector3.RIGHT
			var gb := Basis(right, (-fwd).cross(right).normalized(), -fwd)
			var at := a + fwd * 0.45 + right * 0.18 - Vector3(0, 0.22, 0)
			var gid := parts[1]
			if cd > 0.0:
				get_tree().create_timer(cd, false).timeout.connect(func(): Arms.throw_case(self, gid, at, gb))
			else:
				Arms.throw_case(self, gid, at, gb)
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(a, a + b * minf(float(g.range), 120.0), 1)
		var r2 := space.intersect_ray(q)
		if not r2.is_empty():
			puff(r2.position, r2.normal)
		return
	if kind.begins_with("throw:"):
		var t := Arms.Thrown.make(self, kind.substr(6), a, b, true)
		t.fuse = {"grenade": 2.2, "fire": 1.4, "flare": 45.0, "mine": 600.0}.get(kind.substr(6), 3.0)
		if kind == "throw:mine":
			# A fellow's mine shows until its burst is seen
			get_tree().create_timer(120.0, false).timeout.connect(func(): if is_instance_valid(t): t.queue_free())
		return
	if kind.begins_with("streak:"):
		Streaks.call_in(self, kind.substr(7), a, b, false)
		return
	match kind:
		"shot":
			sfx("shotgun", -6, a)
			if av and is_instance_valid(av):
				av.muzzle()
			var space := get_world_3d().direct_space_state
			var q := PhysicsRayQueryParameters3D.create(a, a + b * 60.0, 1)
			var r := space.intersect_ray(q)
			if not r.is_empty():
				puff(r.position, r.normal)
		"blast":
			Arms.blast_fx(self, a, b.x)
		"pray":
			sfx("choir", -2, a)
			if player.relics:
				var gold := StandardMaterial3D.new()
				gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				gold.albedo_color = Color(1.0, 0.86, 0.45)
				var side := b.cross(Vector3.UP).normalized()
				for i in 30:
					var ang := randf() * TAU
					var rr := sqrt(randf()) * 0.55
					var dir := (b + side * cos(ang) * rr + Vector3.UP * sin(ang) * rr * 0.7).normalized()
					player.relics._cherub(self, a, dir, gold, randf() * 0.25)


func net_downed(id: int, on: bool) -> void:
	if avatars.has(id) and is_instance_valid(avatars[id]):
		avatars[id].downed = on
	if on:
		hud.notify("%s has fallen. Hold [%s] over them to raise them." % [Net.name_of(id), Game.key_text("interact")])
	if Net.is_host():
		_down_peers[id] = on
		if on:
			_check_wipe()


## When every pilgrim has fallen, the trial begins again for all of them.
func _check_wipe() -> void:
	if failing or completed or Net.players.is_empty():
		return
	for id in Net.players:
		var down: bool = downed if id == Net.me() else _down_peers.get(id, false)
		if not down:
			return
	_down_peers.clear()
	Net.wipe()


func _go_down() -> void:
	if downed:
		return
	life_kills = 0
	downed = true
	if "_fell_tonight" in self and get("night"):
		set("_fell_tonight", true)
	player.health = 0.0
	player.input_locked = true
	player.velocity = Vector3.ZERO
	create_tween().tween_property(player.head, "position:y", 0.45, 0.8).set_trans(Tween.TRANS_SINE)
	hud.set_fx("desat", 0.85)
	hud.set_fx("dark", 0.35)
	hud.set_health(0.0, true)
	sfx("hurt", 0, null, 0.7)
	hud.say("You have fallen. Your companions may yet raise you.", 6.0)
	Net.downed(true)
	_pose_t = 0.0
	if Net.is_host():
		_check_wipe()


func _rise(fraction: float) -> void:
	if not downed:
		return
	downed = false
	player.health = player.max_health * fraction
	player.input_locked = false
	create_tween().tween_property(player.head, "position:y", 1.6, 0.8).set_trans(Tween.TRANS_SINE)
	hud.set_fx("desat", 0.0)
	hud.set_fx("dark", 0.0)
	hud.set_health(player.health / player.max_health, combat)
	_regen_wait = 3.0
	Net.downed(false)
	_pose_t = 0.0


func net_revived(by: int, strength := 0.5) -> void:
	if not downed or failing:
		return
	if OS.is_debug_build() or OS.get_cmdline_user_args().size() > 0:
		print("raised by %s" % Net.name_of(by))
	_rise(strength)
	sfx("bell", -8)
	hud.clear_say()
	hud.notify("%s raised you." % Net.name_of(by))


var _wiping := false


func net_wipe() -> void:
	if failing:
		return
	if OS.get_cmdline_user_args().size() > 0:
		print("the whole fellowship fell")
	if downed:
		downed = false
		player.head.position.y = 1.6
		hud.set_fx("desat", 0.0)
		hud.set_fx("dark", 0.0)
		player.input_locked = false
	_wiping = true
	await fail("The whole fellowship fell beneath the lesser forms. Survive one, you are changed. Fall together, and together you begin again.", "")
	_wiping = false
	Net.downed(false)


## A step failed alone: only this pilgrim is sent back; the trial goes on for the others.
func _personal_fail(message: String, sound: String) -> void:
	if _pfail:
		return
	_pfail = true
	falls += 1
	player.input_locked = true
	if sound != "":
		sfx(sound, -4)
	await hud.fade_to(1.0, 1.4)
	hud.clear_say()
	hud.raise_text(true)
	hud.say(message, 4.5)
	await get_tree().create_timer(5.5, false).timeout
	hud.raise_text(false)
	reset_trial()
	if downed:
		_rise(1.0)
	player.place(spawn_pos, spawn_yaw)
	player.reset_max_health()
	hud.set_health(1.0, combat)
	player.input_locked = false
	_pfail = false
	hud.fade_to(0.0, 1.5)


## Calls a method of the land for everyone in the fellowship (or just here, when walking alone).
var guard_up := {}   ## (host) peer -> when a friend last raised their guard, in msec


func _w_guard_up(id: int) -> void:
	if Net.authority():
		guard_up[id] = Time.get_ticks_msec()


## (host) Whether a friend raised their guard just now, facing this foe: a perfect guard, across the wire.
## A little slack is given for the time the word took to come.
func friend_guarded(c: Node3D, foe: Vector3) -> bool:
	if not c is Companion:
		return false
	var at: int = int(guard_up.get(c.peer_id, -100000))
	if Time.get_ticks_msec() - at > int((Arms.PERFECT_GUARD + 0.15) * 1000.0):
		return false
	var yaw: float = float(c.get("_yaw"))
	var cf := Vector3(-sin(yaw), 0.0, -cos(yaw))   # the way the friend looks (their model is turned about)
	var to := foe - c.global_position
	to.y = 0.0
	return cf.dot(to.normalized()) > 0.3


func shared(method: String, args := []) -> void:
	if Net.online:
		Net.call_shared(method, args)
	else:
		callv(method, args)


func net_event_allowed(id: int) -> bool:
	if id < 0 or id >= _net_events.size():
		return false
	var ev: Dictionary = _net_events[id]
	if not is_instance_valid(ev.obj):
		return false
	if ev.trigger:
		return not (ev.once and ev.fired[0])
	return str(ev.obj.get_meta("prompt", "")) != ""


func net_run_event(id: int) -> void:
	if id < 0 or id >= _net_events.size():
		return
	var ev: Dictionary = _net_events[id]
	if ev.trigger:
		if ev.once and ev.fired[0]:
			return
		ev.fired[0] = true
	ev.cb.call()


func net_foes(batch: Array) -> void:
	var now := Time.get_ticks_msec()
	for st in batch:
		var id: int = st[0]
		if _gone.has(id):
			continue
		var e = foes.get(id)
		if e != null and (not is_instance_valid(e) or not e.is_alive()):
			foes.erase(id)
			e = null
		if e == null:
			e = LesserSpeeb.new().setup(st[2], st[1], self)
			e.net_id = id
			e.puppet = true
			e.position = st[3]
			foes[id] = e
			add_child(e)
			enemies.append(e)
		elif not is_instance_valid(e):
			continue
		e.heard_at = now
		e.net_apply(st)


func net_foe_died(id: int, slain: bool, killer: int) -> void:
	var e = foes.get(id)
	foes.erase(id)
	_gone[id] = true
	if e and is_instance_valid(e):
		e.credit = killer == Net.me()
		e.die(slain)


func net_hit(by: int, id: int, amount: float, dir: Vector3, kind := "", head := false, pierce := 1.0, heavy := false) -> void:
	var e = foes.get(id)
	if e == null or not is_instance_valid(e) or not e.is_alive():
		return
	e.last_hitter = by
	var was := [LesserSpeeb.harm_kind, LesserSpeeb.harm_head, LesserSpeeb.harm_pierce, LesserSpeeb.harm_heavy]
	LesserSpeeb.harm_heavy = heavy
	LesserSpeeb.harm_kind = kind
	LesserSpeeb.harm_head = head
	LesserSpeeb.harm_pierce = pierce
	e.hurt(amount, dir)
	LesserSpeeb.harm_kind = was[0]
	LesserSpeeb.harm_head = was[1]
	LesserSpeeb.harm_pierce = was[2]
	LesserSpeeb.harm_heavy = was[3]
	if e.is_alive():
		e.last_hitter = Net.me()


func net_bolt(from: Vector3, vel: Vector3, dmg: float, look := "") -> void:
	var b := LesserSpeeb.Bolt.new()
	b.level = self
	b.velocity = vel
	b.damage = dmg
	b.look = look
	if look == "round":
		b.life = 3.0
	add_child(b)
	b.global_position = from


func net_trial_state(obj: String, meter: String, value: float, done: bool) -> void:
	if done:
		_survive_done = true
		return
	hud.set_objective(obj)
	hud.set_meter(meter, value)


func net_eye_result(seen: bool) -> void:
	_eye_verdict = 1 if seen else 0


## One who joins late is brought to where the fellowship last stood firm.
func net_place(pos: Vector3, yaw: float) -> void:
	checkpoint(pos, yaw)
	player.place(pos, yaw)


# ------------------------------------------------------------------ testing aids

func _debug_grant(slot_id: String) -> void:
	for r in ["lantern", "claw", "censer"]:
		Game.relics[r] = true
	Game.milk = 3
	player.relics.select(Game.RELICS.find(slot_id))


func debug_hands() -> void:
	_debug_grant("hands")
	debug_enemy()
	await get_tree().create_timer(2.5, false).timeout
	player.relics._pray(self)


func debug_claw() -> void:
	_debug_grant("claw")
	var a: Node3D = anchors[0]
	player.place(get("steps")[11] + Vector3(0, 0.4, 0), 0.0)
	player.face(a.global_position)
	await get_tree().create_timer(1.5, false).timeout
	player.relics._use(self)


func debug_lantern() -> void:
	_debug_grant("lantern")
	player.relics.lantern_lit = true


func debug_censer() -> void:
	_debug_grant("censer")
	player.relics.censer_lit = true


func debug_gather() -> void:
	var t0 := Time.get_ticks_msec()
	var killer := func():
		while true:
			await get_tree().create_timer(1.5, false).timeout
			for e in enemies:
				if is_instance_valid(e) and e.is_alive():
					e.hurt(9999.0, Vector3.FORWARD)
					break
	killer.call()
	player.health = 99999.0
	await survive("speebchef", player.global_position + Vector3(0, 3, -8), "pulse")
	print("GATHERING DONE kills=%d secs=%.1f" % [kills, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit()


## Testing aid: where do forms take shape? Counts any that land out of every pilgrim's sight.
func debug_spawns() -> void:
	combat_frozen = true
	var bad := 0
	for i in 40:
		_spawn_enemy("elite" if i % 2 == 0 else "rusher")
	await get_tree().physics_frame
	for e in enemies:
		if is_instance_valid(e) and not reachable(e.global_position):
			bad += 1
	print("SPAWNS %d, out of sight %d" % [enemies.size(), bad])
	get_tree().quit()


func debug_bling() -> void:
	combat_frozen = true
	clear_enemies()
	Game.revealed.erase("saucer")
	Game.reveal_deed("saucer")
	hud.set_streak(7)
	await get_tree().create_timer(4.0, false).timeout
	show_results("Balanced")


func debug_spider() -> void:
	combat_frozen = true
	for i in 2:
		var e := LesserSpeeb.new().setup(Game.lesser.keys()[randi() % 80], "spider", self)
		add_child(e)
		enemies.append(e)
		var fwd := -player.global_transform.basis.z
		e.global_position = player.global_position + fwd * (3.5 + i * 2.0) + Vector3(-1.0 + i * 2.0, 0.6, 0)
		e.rotation.y = PI * 0.25 * (1 - i * 2)


func debug_eye() -> void:
	combat_frozen = true
	clear_enemies()
	_unblinking_eye()


## Testing aid for the fellowship: this pilgrim turns toward the nearest lesser form and fires.
func debug_bot() -> void:
	var k := -1
	while is_inside_tree():
		await get_tree().physics_frame
		if kills != k:
			k = kills
			print("bot: %d undone, %d foes known" % [kills, enemies.filter(func(e): return is_instance_valid(e) and e.is_alive()).size()])
		var best = null
		var bd := 40.0
		for e in enemies:
			if is_instance_valid(e) and e.is_alive():
				var d: float = e.global_position.distance_to(player.global_position)
				if d < bd:
					bd = d
					best = e
		if best and player.weapon and not player.input_locked:
			player.face(best.global_position)
			player.weapon.shells = maxi(player.weapon.shells, 2)
			player.weapon._try_fire()


## Testing aids for the fellowship: fall at once; raise every fallen companion.
func debug_fall() -> void:
	if Net.online:
		_go_down()
	else:
		damage_player(9999.0, player.global_position + Vector3(1, 0, 0))
	print("fall: downed=%s" % downed)
	while downed:
		await get_tree().physics_frame
	print("risen: health=%d" % player.health)


func debug_raise() -> void:
	await get_tree().create_timer(8.0, false).timeout
	print("raise: %d companions known" % avatars.size())
	for id in avatars:
		print("raise: %s downed=%s" % [Net.name_of(id), avatars[id].downed])
		if avatars[id].downed:
			Net.revive(id)


func debug_velm() -> void:
	combat_frozen = true
	clear_enemies()
	_velm_t = 0.0


## Testing aid: a form falls before this pilgrim; the fellowship should see what it leaves.
func debug_drop() -> void:
	shared("_drop", ["shells", player.global_position + Vector3(2, 0, 0), 4])
	await get_tree().create_timer(4.0).timeout
	var n := 0
	for c in get_children():
		if c is Area3D and c.get_child_count() > 2 and c.has_signal("body_entered") and c.get_children().any(func(k): return k is OmniLight3D and k.light_color == Color(1.0, 0.75, 0.4)):
			n += 1
	print("DROPS SEEN ", n)


## Testing aid: tries every gun, the melee, a grenade and each gadget against forms set before Brelm.
func debug_arms() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.plevel = ArmsDB.MAX_LEVEL
	var w: Arms = player.weapon
	var fwd := -player.global_transform.basis.z
	for g in ArmsDB.GUNS:
		Game.loadout.primary = g if ArmsDB.GUNS[g].slot == "primary" else "shotgun"
		Game.loadout.secondary = g if ArmsDB.GUNS[g].slot == "secondary" else "pistol"
		Game.loadout.mounts = {g: [ArmsDB.GUNS[g].mounts[0]]} if not ArmsDB.GUNS[g].mounts.is_empty() else {}
		w.equip_loadout()
		w.refill()
		if w.gun() != g:
			w.swap()
		var e := spawn_at("idol" if g == "rocket" else "rusher", player.global_position + fwd * 8.0)
		combat_frozen = true
		await get_tree().create_timer(0.3).timeout
		var hp0: float = e.hp
		for i in 12:
			if not is_instance_valid(e) or not e.is_alive():
				break
			_debug_aim(e.global_position + Vector3(0, 0.5, 0))
			w._spin = 1.0
			w._cool = 0.0
			w._try_fire()
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(1.2).timeout
		var alive: bool = is_instance_valid(e) and e.is_alive()
		print("ARMS %s (%s): mag %d reserve %d, form hp %.0f -> %s" % [g, Game.mount_of(g), w.shells, w.reserve, hp0, ("%.0f" % e.hp) if alive else "slain"])
		if is_instance_valid(e):
			e.queue_free()
	var e2 := spawn_at("idol", player.global_position + fwd * 2.0)
	combat_frozen = true
	_debug_aim(e2.global_position + Vector3(0, 0.5, 0))
	await get_tree().create_timer(0.1).timeout
	var h := e2.hp
	w.strike()
	await get_tree().create_timer(0.5).timeout
	print("ARMS melee %s: %.0f -> %s" % [w.melee, h, ("%.0f" % e2.hp) if is_instance_valid(e2) else "slain"])
	if is_instance_valid(e2):
		_debug_aim(e2.global_position + Vector3(0, -1.5, 0))
		h = e2.hp
	w.throw_grenade()
	await get_tree().create_timer(3.5).timeout
	print("ARMS grenade: %.0f -> %s, player hp %.0f, grenades left %d" % [h, ("%.0f" % e2.hp) if is_instance_valid(e2) and e2.is_alive() else "slain", player.health, w.grenades])
	for gd in ArmsDB.GADGETS:
		w.gadget = gd
		w.charges = 2
		player.health = 50.0
		w.use_gadget()
		await get_tree().create_timer(2.0).timeout
		print("ARMS gadget %s: charges %d hp %.0f" % [gd, w.charges, player.health])
	w.shells = 0
	w._st[w.gun()].reserve = 0
	w._quiet = 10.0
	await get_tree().create_timer(12.0).timeout
	print("ARMS dry %s comes back to reserve %d" % [w.gun(), w.reserve])
	get_tree().quit()


func _debug_aim(at: Vector3) -> void:
	var d := at - player.cam.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	player.rotation.y = player.yaw
	player.head.rotation.x = player.pitch


func debug_loadoutshot() -> void:
	Game.plevel = 7
	Game.loadout.primary = "machine_gun"
	Game.loadout.mounts = {"machine_gun": ["red_dot", "foregrip", "ext_mag"], "shotgun": ["foregrip"]}
	player.weapon.equip_loadout()
	player.relics.refresh()
	await get_tree().create_timer(4.0).timeout
	hud.show_loadout()


## Testing aid: earns and calls each kill streak onto forms gathered before Brelm.
func debug_streaks() -> void:
	await get_tree().create_timer(1.0).timeout
	var fwd := -player.global_transform.basis.z
	for k in Streaks.ORDER:
		var es: Array = []
		for i in 5:
			es.append(spawn_at("rusher", player.global_position + fwd * (30.0 + i * 3.0) + Vector3(randf_range(-3, 3), 0, 0)))
		combat_frozen = true
		await get_tree().create_timer(0.5).timeout
		streaks_ready.append(k)
		_debug_aim(player.global_position + fwd * 36.0)
		call_streak()
		await get_tree().create_timer(14.0 if k != "gunship" else 40.0).timeout
		var alive := es.filter(func(e): return is_instance_valid(e) and e.is_alive()).size()
		print("STREAK %s: %d of 5 forms still stand, player hp %.0f" % [k, alive, player.health])
		for e in es:
			if is_instance_valid(e):
				e.queue_free()
	get_tree().quit()


## Test: the air support menu with three kinds ready.
func debug_airshot() -> void:
	streaks_ready = ["airstrike", "gunrun", "airstrike", "gunship"]
	call_streak()


## Testing aid: one great one (BOSS=boss_ash) stood still ahead, seen from the side (ROT turns it).
func debug_bossline() -> void:
	combat_frozen = true
	var fwd := -player.global_transform.basis.z
	var e := LesserSpeeb.new().setup(Game.lesser.keys()[3], OS.get_environment("BOSS"), self)
	add_child(e)
	enemies.append(e)
	e.global_position = player.global_position + fwd * float(OS.get_environment("AWAY") if OS.get_environment("AWAY") != "" else "12") + Vector3(0, float(e.spec.radius), 0)
	e.look_at(player.global_position + Vector3(0, float(e.spec.radius), 0), Vector3.UP)
	e.rotate_y(PI + float(OS.get_environment("ROT")))
	_debug_aim(e.global_position + Vector3(0, 1.0, 0))
	await get_tree().create_timer(1.0).timeout
	e.scale = Vector3.ONE
	if e._scan:
		e._scan_tick(0.0)


func debug_streakshot() -> void:
	await get_tree().create_timer(2.0).timeout
	var fwd := -player.global_transform.basis.z
	var h := Streaks._helicopter()
	add_child(h)
	h.global_position = player.global_position + fwd * 30.0 + Vector3(-8, 12, 0)
	h.look_at(player.global_position + Vector3(0, 8, 0), Vector3.UP)
	var j := Streaks._jet(true)
	add_child(j)
	j.global_position = player.global_position + fwd * 60.0 + Vector3(18, 22, 0)
	j.look_at(j.global_position + Vector3(-1, -0.2, 0.3), Vector3.UP)
	var f := Streaks._jet(false)
	add_child(f)
	f.global_position = player.global_position + fwd * 70.0 + Vector3(-25, 30, 0)
	f.look_at(f.global_position + Vector3(1, 0.1, 0.4), Vector3.UP)
	_debug_aim(player.global_position + fwd * 30.0 + Vector3(0, 12, 0))
	await get_tree().create_timer(1.0).timeout
	Arms.blast_fx(self, player.global_position + fwd * 25.0 + Vector3(6, 0.5, 0), 7.0)


func debug_appearance() -> void:
	var a := AppearanceUI.new()
	a.hud = hud
	hud.root.add_child(a)


func debug_figures() -> void:
	var fwd := -player.global_transform.basis.z
	var side := player.global_transform.basis.x
	for i in 5:
		var f := Figure.new().setup(Figure.seeded(i * 7919 + 3))
		f.arms_forward = i % 2 == 0
		add_child(f)
		f.global_position = player.global_position + fwd * 4.5 + side * (i - 2) * 1.1
		f.look_at(player.global_position, Vector3.UP)
		f.rotate_y(PI)


## Test: fellow pilgrims holding each gun, level and raised, seen from the front and the side.
func debug_heldshot() -> void:
	combat_frozen = true
	player.weapon.enabled = false
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.5
	sun.rotation = Vector3(-0.7, player.yaw + 0.5, 0)
	add_child(sun)
	var fwd := -player.global_transform.basis.z
	var side := player.global_transform.basis.x
	var gs := ["shotgun", "machine_gun", "pistol", "sniper", "minigun"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("guns="):
			gs = Array(a.substr(5).split(","))
	for i in gs.size():
		var c := Companion.new().setup(1)
		add_child(c)
		var at := player.global_position + fwd * 2.6 + side * (i - (gs.size() - 1) * 0.5) * 1.0
		var yaw: float = player.yaw + PI + [0.0, 1.57, 0.8, 1.57, -1.57][i % 5]
		c.pose([at, yaw, [0.0, 0.0, 0.0, 0.5, -0.5][i % 5], false, 1.0, "shotgun", true, false, gs[i]])
		c._label.visible = false


## Test: every gun laid out side on, bare above and fully fitted below.
func debug_gunshot() -> void:
	combat_frozen = true
	player.weapon.enabled = false
	hud.root.visible = false
	var cam := player.cam
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.2
	add_child(sun)
	sun.global_rotation = cam.global_rotation + Vector3(-0.5, 0.5, 0)
	var maker := Arms.new()
	var gs := ArmsDB.GUNS.keys()
	var full := "fitted" in OS.get_cmdline_user_args()
	for i in gs.size():
		var m := maker._build(gs[i], ArmsDB.GUNS[gs[i]].mounts.filter(func(x): return x != "scope") if full else [])
		cam.add_child(m)
		m.position = Vector3(-0.75 + (i % 2) * 1.5, 0.55 - (i / 2) * 0.36, -1.7)
		m.rotation.y = -PI / 2 + 0.3
	maker.free()


## Test: the shotgun fed shell by shell, held at k= (0 to 1) so a picture catches the shell on its way in.
func debug_reloadshot() -> void:
	var g := "shotgun"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("gun="):
			g = a.substr(4)
	Game.loadout.primary = g if ArmsDB.GUNS[g].slot == "primary" else "shotgun"
	Game.loadout.secondary = g if ArmsDB.GUNS[g].slot == "secondary" else "pistol"
	player.weapon.equip_loadout()
	if player.weapon.gun() != g:
		player.weapon.swap()
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.0
	add_child(sun)
	sun.global_rotation = player.cam.global_rotation + Vector3(-0.6, 0.6, 0)
	var k := 0.5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("k="):
			k = float(a.substr(2))
	player.weapon.reload_mult = 10000.0
	player.weapon.shells = 0
	player.weapon.reserve = 40
	player.weapon._start_reload()
	player.weapon._reload_t = player.weapon._reload_len * (1.0 - k)


## Test: looking down the sights of the gun named by gun=, with fit= listing what is on it.
func debug_aimshot() -> void:
	combat_frozen = true
	var g := "shotgun"
	var fit: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("gun="):
			g = a.substr(4)
		if a.begins_with("fit="):
			fit = Array(a.substr(4).split(","))
		if a.begins_with("turn="):
			player.yaw += float(a.substr(5))
	Game.plevel = ArmsDB.MAX_LEVEL
	if "waste" in OS.get_cmdline_user_args():
		Game.wasteland = true   # the waste's build: a sniper rifle without its scope
	Game.loadout.primary = g if ArmsDB.GUNS[g].slot == "primary" else "shotgun"
	Game.loadout.secondary = g if ArmsDB.GUNS[g].slot == "secondary" else "pistol"
	Game.loadout.mounts = {g: fit}
	player.weapon.equip_loadout()
	if player.weapon.gun() != g:
		player.weapon.swap()
	player.weapon.debug_aim = not "hip" in OS.get_cmdline_user_args()
	if "flash" in OS.get_cmdline_user_args():
		var w = player.weapon
		w._flash_mesh.visible = true
		w._flash_mesh.scale = Vector3.ONE * float(w.FLASH_SIZE.get(g, 0.18))
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.0
	add_child(sun)
	sun.global_rotation = player.cam.global_rotation + Vector3(-0.6, 0.6, 0)


func debug_scanshot() -> void:
	combat_frozen = true
	var fwd := -player.global_transform.basis.z
	var side := player.global_transform.basis.x
	var ks: Array = LesserSpeeb.SCANS.keys()
	for i in ks.size():
		var e := LesserSpeeb.new().setup(Game.lesser.keys()[i % Game.lesser.size()], ks[i], self)
		add_child(e)
		enemies.append(e)
		e.global_position = player.global_position + fwd * (5.0 + i * 4.0) + side * (i - 1) * 1.2 + Vector3(0, 1.0, 0)
		e.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		e.rotate_y(PI)


func debug_catshot() -> void:
	combat_frozen = true
	var fwd := -player.global_transform.basis.z
	var side := player.global_transform.basis.x
	var ks: Array = ["rusher", "idol", "spitter"]
	if OS.get_environment("CATS") != "":
		ks = Array(OS.get_environment("CATS").split(","))
	for i in 3:
		var e := LesserSpeeb.new().setup(Game.lesser.keys()[(i * 17 + 5) % Game.lesser.size()], ks[i], self)
		add_child(e)
		enemies.append(e)
		var spread := float(OS.get_environment("SPREAD")) if OS.get_environment("SPREAD") != "" else 1.1
		var away := float(OS.get_environment("AWAY")) if OS.get_environment("AWAY") != "" else 2.6
		e.global_position = player.global_position + fwd * away + side * (i - 1) * spread + Vector3(0, 1.5, 0)
		e.look_at(player.global_position + Vector3(0, 1.5, 0), Vector3.UP)
		e.rotate_y(PI + float(OS.get_environment("ROT")))


## Test: an unseen form must hold still while looked upon and come on when the eye turns away.
func debug_unseen() -> void:
	await get_tree().create_timer(1.0).timeout
	var fwd := -player.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var sp = open_spot_near(player.global_position, 14.0, 20.0)
	var e := spawn_at("unseen", sp if sp != null else player.global_position + fwd * 18.0 + Vector3(0, 1.5, 0))
	fwd = (e.global_position - player.global_position) * Vector3(1, 0, 1)
	fwd = fwd.normalized()
	_debug_aim(e.global_position)
	await get_tree().create_timer(2.0).timeout
	var a := e.global_position
	await get_tree().create_timer(2.0).timeout
	var watched_move := e.global_position.distance_to(a)
	print("UNSEEN frozen=%s targets=%d watched=%s" % [combat_frozen, targets().size(), e._watched])
	_debug_aim(player.global_position - fwd * 10.0 + Vector3(0, 1.5, 0))
	await get_tree().create_timer(1.5).timeout
	var b := e.global_position
	print("UNSEEN after turn watched=%s vel=%s et=%s idle=%s" % [e._watched, e.velocity, enemy_time, nearest_target(e.global_position)])
	await get_tree().create_timer(0.8).timeout
	var away_move := e.global_position.distance_to(b) if is_instance_valid(e) else -1.0
	print("UNSEEN watched_move=%.2f away_move=%.2f dist=%.1f" % [watched_move, away_move, e.global_position.distance_to(player.global_position) if is_instance_valid(e) else -1.0])
	get_tree().quit()


func debug_unseenshot() -> void:
	combat_frozen = true
	var fwd := -player.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var e := spawn_at("unseen", player.global_position + fwd * 4.0 + player.global_transform.basis.x * 0.8 + Vector3(0, 1.4, 0))
	e.look_at(player.global_position + Vector3(0, 1.4, 0), Vector3.UP)
	e.rotate_y(PI)
	var f := spawn_at("unseen", player.global_position + fwd * 12.0 - player.global_transform.basis.x * 3.0 + Vector3(0, 1.4, 0))
	f.look_at(player.global_position + Vector3(0, 1.4, 0), Vector3.UP)
	f.rotate_y(PI)



## The ground breaking about a great one: a ring of dust running outward.
func _w_slam_fx(at: Vector3, r: float) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.55, 0.45, 0.38, 0.7)
	ring.material_override = m
	add_child(ring)
	ring.global_position = at - Vector3(0, 1.2, 0)
	ring.scale = Vector3(1, 0.3, 1)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(r, 0.6, r), 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(ring.queue_free)
	if player and player.global_position.distance_to(at) < r * 2.5:
		player.shake(0.8)


## A warning on the ground of where a great one's blow will fall. kind 0: a ring, 1: a lane
## (angle and half width given), 2: a burning circle. It fills in as the blow draws near.
var marks_seen := {}   ## warnings shown, by kind, for the tests


## The warnings of the far forms' ways (see FoeTraits): [sound, loudness, pitch, colour of the puff (none if clear)].
const TELLS := {
	"phase": ["glitch", -3.0, 0.75, Color(0.75, 0.7, 0.95, 0.7)],
	"burrow": ["crumble", 0.0, 0.6, Color(0.5, 0.44, 0.36, 0.85)],
	"vent": ["hiss", -5.0, 0.5, Color(0.92, 0.93, 0.95, 0.6)],
	"ravens": ["critter_2", 0.0, 0.6, Color(0.05, 0.05, 0.06, 0.9)],
	"choir": ["choir", -8.0, 1.4, Color(0, 0, 0, 0)],
	"stealth": ["cloth", -4.0, 0.8, Color(0, 0, 0, 0)],
}
var tells_seen := {}


## Everyone: a far form's warning, where its way is about to happen.
func _w_tell(what: String, at: Vector3) -> void:
	if not TELLS.has(what):
		return
	tells_seen[what] = int(tells_seen.get(what, 0)) + 1
	var tl: Array = TELLS[what]
	sfx(tl[0], tl[1], at, tl[2])
	var c: Color = tl[3]
	if c.a <= 0.0 or Net.dedicated:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 24
	p.lifetime = 1.4
	p.explosiveness = 0.5
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -0.6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8
	var qm := QuadMesh.new()
	qm.size = Vector2(0.35, 0.35)
	# Soft round puffs that fade near the eye (the waste's weather flecks' own shader), in the tell's colour
	var m := ShaderMaterial.new()
	m.shader = load("res://world/weather_fleck.gdshader")
	qm.material = m
	p.color = c
	p.mesh = qm
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)
	p.global_position = at
	get_tree().create_timer(2.0, false).timeout.connect(p.queue_free)


func _w_warn(at: Vector3, r: float, t: float, kind: int, angle := 0.0, half := 1.0) -> void:
	marks_seen[kind] = int(marks_seen.get(kind, 0)) + 1
	var y := at.y
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 6, 0), at - Vector3(0, 12, 0), 1))
	if not hit.is_empty():
		y = hit.position.y
	var tr = get("terrain")
	if tr != null and tr.has_method("height_at"):
		y = maxf(y, tr.height_at(at.x, at.z))
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = [Color(1.0, 0.45, 0.15, 0.2), Color(1.0, 0.2, 0.15, 0.2), Color(1.0, 0.35, 0.05, 0.2)][kind]
	if kind == 1:
		var q := PlaneMesh.new()
		q.size = Vector2(half * 2.0, r * 2.0)
		mi.mesh = q
		mi.rotation.y = angle
	else:
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = 0.6
		c.radial_segments = 40
		mi.mesh = c
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(at.x, y + (0.15 if kind == 1 else 0.0), at.z)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.6, t * 0.85).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(mi.queue_free)


## A gunman's tracer: a thin line of light from its muzzle to where the shot went.
func _w_tracer(a: Vector3, b: Vector3) -> void:
	if a.distance_to(b) < 0.1:
		return
	var mi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.025, 0.025, a.distance_to(b))
	mi.mesh = bx
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.5, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(mi.queue_free)


## A gunman takes aim: a bright glint at its muzzle, the warning before the burst.
func _w_glint(id: int) -> void:
	var e = foes.get(id)
	if not is_instance_valid(e) or e._fb == null or e._fb.muzzle == null:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.4)
	l.light_energy = 3.0
	l.omni_range = 2.0
	e._fb.muzzle.add_child(l)
	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	spark.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.95, 0.7)
	spark.material_override = m
	e._fb.muzzle.add_child(spark)
	sfx("draw", -8, e.global_position, 1.3)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.75)
	tw.tween_callback(l.queue_free)
	tw.tween_callback(spark.queue_free)


func _w_boss_wroth(b: String) -> void:
	if hud and LesserSpeeb.BOSSES.has(b):
		hud.notify("%s grows wroth. Its ways come quicker." % LesserSpeeb.BOSSES[b].name)


## The great one nearest this pilgrim, for the bar across the top of the sight.
func _boss_watch() -> void:
	var best = null
	var bd := 70.0
	for e in enemies:
		if is_instance_valid(e) and e.is_alive() and e.boss != "":
			var d: float = e.global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = e
	hud.boss_bar(LesserSpeeb.BOSSES[best.boss].name if best else "", best.hp_frac if best else 0.0)
