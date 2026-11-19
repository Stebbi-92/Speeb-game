class_name Player
extends CharacterBody3D
## Brelm. Walks slowly, as the faithful do.

signal interact_pressed

var head: Node3D
var cam: Camera3D
var ray: RayCast3D
var yaw := 0.0
var pitch := 0.0
var input_locked := false
var look_locked := false
var walk_speed := 3.4
var run_speed := 5.8
var soft_speed := 1.3
var speed_cap := -1.0
var mount = null           ## the cat being ridden (the waste), or null on foot
var vessel = null          ## the boat the pilgrim is aboard (the waste); it carries them, and they look and shoot
var water_y := -INF        ## the sea's surface here when the ground is well under it (set by the land), else -INF
var swimming := false
var carry_slow := 1.0      ## a heavy gun in hand slows the step
var can_run := true
var can_jump := true
var gravity := 14.0
var jump_velocity := 5.0
var flung := false
var cur_speed := 0.0
var look_motion := 0.0
var target: Node = null
var hold_time := 0.0
var _alt_pending := false   ## interact is down on a thing with a second, held use (a satchel: hold to take all)
var bob_amount := 1.0
var health := 100.0
var max_health := 100.0
var dash_cd := 0.0
## Stamina, in the waste only: running, dodging and heavy blows spend it; it comes back after a breath.
## At empty you are winded and cannot run or dodge until it is a quarter full again.
const STAMINA_MAX := 100.0
var stamina_max := STAMINA_MAX   ## meals add to it
var stamina := STAMINA_MAX
var winded := false
var _breath := 0.0            ## seconds until stamina starts to come back
var stamina_mult := 1.0       ## how fast it comes back (food, rest and gear change it)
var _breath_note := -10000
var dodge_t := 0.0   ## a dodge in the waste: for this long, bites and blows pass by
var rift_cd := 0.0
var ward_ready := true
var ward_cd := 0.0
var weapon: Arms
var relics: Relics
var armed := false
var grappling := false
var _grapple_to := Vector3.ZERO
var _grapple_t := 0.0
var _trauma := 0.0

var _bob_t := 0.0
var _step_t := 0.0
var _step: AudioStreamPlayer
var _was_floor := true


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	shape.shape = cap
	shape.position.y = 0.875
	add_child(shape)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = Game.fov
	cam.near = 0.05
	cam.far = 900
	head.add_child(cam)
	cam.current = true
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -3.0)
	ray.collide_with_areas = true
	ray.collision_mask = 1 | 16
	ray.add_exception(self)
	cam.add_child(ray)
	_step = AudioStreamPlayer.new()
	_step.stream = load("res://assets/audio/step.wav")
	_step.volume_db = -14
	_step.bus = "World"
	add_child(_step)
	floor_snap_length = 0.3
	collision_mask = 1 | 2
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_armed(on: bool) -> void:
	armed = on
	if on and weapon == null:
		weapon = Arms.new()
		weapon.player = self
		cam.add_child(weapon)
	if relics == null:
		relics = Relics.new()
		relics.player = self
		cam.add_child(relics)
	relics.refresh()


## Shakes the view; strength fades over a moment.
func shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


## The Claw of Ascent draws Brelm through the air to a ring of iron.
func grapple(to: Vector3) -> void:
	grappling = true
	_grapple_to = to
	_grapple_t = 0.0


func weapon_reset() -> void:
	if weapon:
		weapon.refill()


## Whether a menu is open over the world (in a fellowship the world does not pause for it).
func _menu_up() -> bool:
	var h = Game.main.hud if Game.main else null
	return h != null and ((h.pause_panel and h.pause_panel.visible) or (h.options_panel and h.options_panel.visible) or (h.codex_panel and h.codex_panel.visible))


func place(pos: Vector3, facing_yaw: float) -> void:
	# In a fellowship each pilgrim stands a little apart, by their place in it
	if Net.online and not Net.dedicated:
		var k := Net.slot_of(Net.me())
		pos += Vector3([0.0, 0.9, -0.9, 0.0, 1.8, -1.8, 0.9, -0.9][k % 8], 0, [0.0, 0.0, 0.0, 0.9, 0.0, 0.0, 0.9, 0.9][k % 8]).rotated(Vector3.UP, facing_yaw)
	global_position = pos
	velocity = Vector3.ZERO
	yaw = facing_yaw
	pitch = 0.0
	rotation.y = yaw
	head.rotation.x = 0
	flung = false
	grappling = false


## Turns Brelm's gaze toward a point over time.
func look_toward(p: Vector3, dur := 1.5) -> void:
	var to := p - head.global_position
	var want_yaw := atan2(-to.x, -to.z)
	var want_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	want_yaw = yaw + wrapf(want_yaw - yaw, -PI, PI)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "yaw", want_yaw, dur)
	tw.tween_property(self, "pitch", clampf(want_pitch, -1.3, 1.3), dur)


func face(p: Vector3) -> void:
	var to := p - head.global_position
	yaw = atan2(-to.x, -to.z)
	pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.4, 1.4)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_motion += e.relative.length()
		if weapon:
			weapon.sway(e.relative)
		if not look_locked:
			# Looking down a sight turns as much of the view per hand's width as at the hip
			var sens := Game.sensitivity * (weapon.look_scale() if weapon else 1.0)
			yaw -= e.relative.x * sens
			pitch = clampf(pitch - e.relative.y * sens * (-1.0 if Game.invert_y else 1.0), -1.45, 1.45)
			if Game.main and Game.main.hud:
				Game.main.hud.scope_nudge(e.relative)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and not get_tree().paused and not input_locked and not _menu_up():
		# A click back into the world takes the mouse again; a scroll, or a click while a menu is up, does not
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e.is_action_pressed("interact"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused and not input_locked and not _menu_up():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		interact_pressed.emit()
		if not input_locked and target and target.has_meta("on_interact") and target.get_meta("hold", 0.0) <= 0.0:
			if target.has_meta("on_hold"):
				# Tap opens it; holding does the second thing. Which one is known on release, or when the bar fills.
				_alt_pending = true
				hold_time = 0.0
			else:
				var cb: Callable = target.get_meta("on_interact")
				cb.call()


## A footstep that sounds like the ground under it: boards, stone, gravel, sand, grass or salt crust.
func _footfall(hard: bool) -> void:
	var takes := Level.takes_of("step_" + _ground())
	if takes.is_empty():
		_step.pitch_scale = randf_range(0.85, 1.1)
		_step.play()
		return
	_step.stream = takes[randi() % takes.size()]
	_step.pitch_scale = randf_range(0.93, 1.07)
	_step.volume_db = (-12.0 if hard else -15.0) + randf_range(-1.5, 0.5)
	if speed_cap > 0.0:
		# Held by the tar: a slow, deep, sucking step
		_step.pitch_scale = randf_range(0.5, 0.58)
		_step.volume_db += 4.0
	_step.play()


func _ground() -> String:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < 0.6:
			continue
		var b = c.get_collider()
		if b is CollisionObject3D and (b.collision_layer & 16):
			return "wood"
		if b is StaticBody3D and not b.has_meta("ground"):
			return "stone"
		break
	var lvl = get_parent()
	var tr = lvl.get("terrain") if lvl else null
	if tr and tr.has_method("biome_name"):
		var b: String = tr.biome_name(global_position.x, global_position.z)
		if b == "salt":
			return "snow"   # the crust of the flats crunches like snow
		if b in ["forest", "marsh"]:
			return "grass"
		if b == "basalt":
			return "gravel"
	return "sand"


func _physics_process(delta: float) -> void:
	# The right stick looks about, gently near the middle and quickly at the edge
	if not input_locked and not get_tree().paused:
		var st := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if st.length() > 0.15:
			st = st.normalized() * pow((st.length() - 0.15) / 0.85, 1.6)
			var aimk := 0.45 if Input.is_action_pressed("aim") else 1.0
			yaw -= st.x * Game.pad_look * aimk * delta
			pitch = clampf(pitch - st.y * Game.pad_look * 0.75 * aimk * delta * (-1.0 if Game.invert_y else 1.0), -1.45, 1.45)
	rotation.y = yaw
	head.rotation.x = pitch
	if grappling:
		_grapple_t += delta
		var d := _grapple_to - global_position
		if d.length() < 0.6 or _grapple_t > 3.5:
			grappling = false
			velocity = d.normalized() * 1.5
		else:
			velocity = d.normalized() * minf(22.0, d.length() * 4.0 + 6.0)
		move_and_slide()
		_update_target(delta)
		return
	if vessel != null and is_instance_valid(vessel):
		# Aboard: the boat carries you; you look about and shoot from it
		global_position = vessel.seat_pos(self)
		velocity = Vector3.ZERO
		cur_speed = 0.0
		swimming = false
		_stamina_tick(delta, false)
		head.position.y = lerpf(head.position.y, 1.6, minf(1.0, delta * 6.0))
		_update_target(delta)
		return
	var input := Vector2.ZERO
	if not input_locked and not Game.main.hud.pause_panel.visible:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sp := walk_speed
	var running := can_run and Input.is_action_pressed("run") and not (Game.wasteland and winded) and not (weapon and weapon.scoped_now)
	if mount:
		# Riding: the cat's pace, and its own breath for a sprint; the rider's is spared
		sp = mount.pace(running and input.length() > 0.1, delta)
		running = false
	elif running:
		sp = run_speed
	if Input.is_action_pressed("soft") and not mount:
		sp = soft_speed
	if Game.blessed("floofspeeb"):
		sp *= 1.12
	sp *= carry_slow
	if speed_cap > 0.0:
		# A cat's broad paws ride over the tar; it is only slowed a little
		sp = minf(sp, speed_cap) if not mount else sp * 0.85
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	if dir.length() > 1.0:
		dir = dir.normalized()
	var on_floor := is_on_floor()
	swimming = water_y > -1.0e8 and global_position.y < water_y - 1.05 and mount == null
	if swimming:
		# In the sea: slow strokes, a hard pull to keep the head up, and it tires you
		var stroke := walk_speed * (0.8 if running and not winded else 0.5)
		velocity.x = lerpf(velocity.x, dir.x * stroke, minf(1.0, 3.0 * delta))
		velocity.z = lerpf(velocity.z, dir.z * stroke, minf(1.0, 3.0 * delta))
		var float_y := water_y - 1.3 + (0.7 if Input.is_action_pressed("jump") and not input_locked else 0.0)
		velocity.y = lerpf(velocity.y, clampf((float_y - global_position.y) * 2.5, -4.0, 3.0), minf(1.0, 4.0 * delta))
		if Input.is_action_pressed("soft") and not input_locked:
			velocity.y = -2.5
		if not _power("tar"):
			stamina = maxf(0.0, stamina - (10.0 if running else 2.0) * delta * (0.5 if _power("white") else 1.0) * (0.5 if _boon("deep_diver") else 1.0))
		_breath = 0.6
		if stamina <= 0.0:
			winded = true
		running = false
	elif flung:
		velocity.y -= gravity * 0.5 * delta
	else:
		var accel := 9.0 if on_floor else 2.5
		velocity.x = lerpf(velocity.x, dir.x * sp, minf(1.0, accel * delta))
		velocity.z = lerpf(velocity.z, dir.z * sp, minf(1.0, accel * delta))
		if not on_floor:
			velocity.y -= gravity * delta
		elif Input.is_action_just_pressed("jump") and can_jump and not input_locked and (mount != null or spend(10.0)):
			velocity.y = jump_velocity
	_blessings(delta, dir)
	move_and_slide()
	cur_speed = Vector2(velocity.x, velocity.z).length()
	_stamina_tick(delta, running and cur_speed > walk_speed * 0.8)

	if on_floor and cur_speed > 0.3:
		_bob_t += delta * cur_speed * 2.2
		_step_t += delta * cur_speed
		if _step_t > (2.1 if running else 1.7):
			_step_t = 0.0
			if not mount:
				_footfall(running)
	if on_floor and not _was_floor:
		_footfall(true)
	_was_floor = on_floor
	var bob := bob_amount if Game.head_bob else 0.0
	head.position.y = lerpf(head.position.y, 1.6 + (0.75 if mount else 0.0), minf(1.0, delta * 6.0))
	cam.position.y = sin(_bob_t) * 0.04 * bob * (0.5 if mount else 1.0)
	cam.position.x = cos(_bob_t * 0.5) * 0.025 * bob
	_trauma = maxf(0.0, _trauma - delta * 1.8)
	var tr := _trauma * _trauma
	var tt := Time.get_ticks_msec() * 0.001
	cam.h_offset = sin(tt * 37.0) * 0.06 * tr
	cam.v_offset = sin(tt * 41.0 + 1.3) * 0.06 * tr
	cam.rotation.z = sin(tt * 29.0 + 0.7) * 0.03 * tr
	_update_target(delta)


func _blessings(delta: float, dir: Vector3) -> void:
	dash_cd = maxf(0.0, dash_cd - delta)
	dodge_t = maxf(0.0, dodge_t - delta)
	rift_cd = maxf(0.0, rift_cd - delta)
	if not ward_ready and Game.blessed("runespeeb"):
		ward_cd -= delta
		if ward_cd <= 0.0:
			ward_ready = true
	if input_locked or not armed:
		return
	if Game.wasteland and not Game.blessed("speebyeet") and Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and is_on_floor() and spend(22.0):
		# A quick step aside, the way you are moving (or back, standing still); a bite in that moment misses
		dash_cd = 1.1
		dodge_t = 0.3
		var dd := dir if dir.length() > 0.1 else transform.basis.z
		dd.y = 0
		velocity += dd.normalized() * 10.0 + Vector3(0, 1.0, 0)
		get_parent().sfx("whoosh", -12, null, 1.3)
	elif Game.blessed("speebyeet") and Input.is_action_just_pressed("dash") and dash_cd <= 0.0:
		dash_cd = 2.5
		var d := dir if dir.length() > 0.1 else -transform.basis.z
		d.y = 0
		velocity += d.normalized() * 13.0 + Vector3(0, 1.5, 0)
		get_parent().sfx("whoosh", -10)
	if Game.blessed("glitchspeeb") and Input.is_action_just_pressed("riftwalk") and rift_cd <= 0.0:
		rift_cd = 18.0
		get_parent().riftwalk()


## Spends stamina. Outside the waste there is none to spend, so everything is free.
## Returns false, and spends nothing, when winded or when there is not enough.
func spend(n: float) -> bool:
	if not Game.wasteland:
		return true
	if _power("white"):
		n *= 0.5
	if winded or stamina < n * 0.5:
		if Game.main and Game.main.hud and Time.get_ticks_msec() - _breath_note > 3000:
			_breath_note = Time.get_ticks_msec()
			Game.main.hud.notify("You are out of breath.")
		return false
	stamina = maxf(0.0, stamina - n)
	_breath = 0.9
	if stamina <= 0.0:
		winded = true
	return true


func _stamina_tick(delta: float, running: bool) -> void:
	if not Game.wasteland:
		return
	if running and is_on_floor():
		stamina = maxf(0.0, stamina - 14.0 * delta * (0.5 if _power("white") else 1.0))
		_breath = 0.6
		if stamina <= 0.0:
			winded = true
	else:
		_breath = maxf(0.0, _breath - delta)
		if _breath <= 0.0:
			stamina = minf(stamina_max, stamina + 24.0 * stamina_mult * delta)
	if winded and stamina >= stamina_max * 0.25:
		winded = false
	if Game.main and Game.main.hud:
		if mount:
			Game.main.hud.set_stamina(mount.breath / mount.BREATH_MAX, true, mount.winded)   # the cat's breath while riding
		else:
			Game.main.hud.set_stamina(stamina / stamina_max, true, winded)


func reset_max_health() -> void:
	max_health = 125.0 if Game.blessed("speebbang") else 100.0
	health = max_health
	ward_ready = true


func _update_target(delta: float) -> void:
	var t: Node = null
	if not input_locked and ray.is_colliding():
		var c := ray.get_collider()
		if c and c.has_meta("prompt") and c.get_meta("prompt") != "":
			t = c
	if t != target:
		hold_time = 0.0
		_alt_pending = false
	target = t
	var hud = Game.main.hud
	if target == null:
		hud.set_prompt("", 0.0)
		return
	if target.has_meta("on_hold") and target.get_meta("hold", 0.0) <= 0.0:
		const ALT := 0.45
		if _alt_pending:
			if Input.is_action_pressed("interact"):
				hold_time += delta
				if hold_time >= ALT:
					_alt_pending = false
					hold_time = 0.0
					var hcb: Callable = target.get_meta("on_hold")
					hcb.call()
			else:
				_alt_pending = false
				hold_time = 0.0
				var tcb: Callable = target.get_meta("on_interact")
				tcb.call()
				return
		var k := Game.key_text("interact")
		hud.set_prompt("[%s]  %s      Hold [%s]  %s" % [k, target.get_meta("prompt"), k, target.get_meta("hold_prompt", "")], hold_time / ALT if _alt_pending else 0.0)
		return
	var hold: float = target.get_meta("hold", 0.0)
	if hold > 0.0:
		if Input.is_action_pressed("interact"):
			hold_time += delta
			if hold_time >= hold:
				hold_time = 0.0
				var cb: Callable = target.get_meta("on_interact")
				target = null
				hud.set_prompt("", 0.0)
				cb.call()
				return
		else:
			hold_time = maxf(0.0, hold_time - delta * 2.0)
		hud.set_prompt("Hold [%s]  " % Game.key_text("interact") + target.get_meta("prompt"), hold_time / hold)
	else:
		hud.set_prompt("[%s]  " % Game.key_text("interact") + target.get_meta("prompt"), 0.0)


## Whether this pilgrim carries a great one's power (see the waste's POWERS).
func _boon(k: String) -> bool:
	var sk = get_parent().get("skills") if get_parent() else null
	return sk != null and sk.has_method("has_boon") and sk.has_boon(k)


func _power(k: String) -> bool:
	var lvl = get_parent()   # the powers are the waste's, which this pilgrim walks in
	return lvl != null and lvl.has_method("power_is") and lvl.power_is(k)
