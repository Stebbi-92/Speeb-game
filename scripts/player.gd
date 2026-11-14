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


func place(pos: Vector3, facing_yaw: float) -> void:
	# In a fellowship each pilgrim stands a little apart, by their place in it
	if Net.online and not Net.dedicated:
		var k := Net.slot_of(Net.me())
		pos += Vector3([0.0, 0.9, -0.9, 0.0][k % 4], 0, [0.0, 0.0, 0.0, 0.9][k % 4]).rotated(Vector3.UP, facing_yaw)
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
			yaw -= e.relative.x * Game.sensitivity
			pitch = clampf(pitch - e.relative.y * Game.sensitivity * (-1.0 if Game.invert_y else 1.0), -1.45, 1.45)
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused and not input_locked:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e.is_action_pressed("interact"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused and not input_locked:
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


func _physics_process(delta: float) -> void:
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
	var input := Vector2.ZERO
	if not input_locked and not Game.main.hud.pause_panel.visible:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sp := walk_speed
	if can_run and Input.is_action_pressed("run"):
		sp = run_speed
	if Input.is_action_pressed("soft"):
		sp = soft_speed
	if Game.blessed("floofspeeb"):
		sp *= 1.12
	sp *= carry_slow
	if speed_cap > 0.0:
		sp = minf(sp, speed_cap)
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	if dir.length() > 1.0:
		dir = dir.normalized()
	var on_floor := is_on_floor()
	if flung:
		velocity.y -= gravity * 0.5 * delta
	else:
		var accel := 9.0 if on_floor else 2.5
		velocity.x = lerpf(velocity.x, dir.x * sp, minf(1.0, accel * delta))
		velocity.z = lerpf(velocity.z, dir.z * sp, minf(1.0, accel * delta))
		if not on_floor:
			velocity.y -= gravity * delta
		elif Input.is_action_just_pressed("jump") and can_jump and not input_locked:
			velocity.y = jump_velocity
	_blessings(delta, dir)
	move_and_slide()
	cur_speed = Vector2(velocity.x, velocity.z).length()

	if on_floor and cur_speed > 0.3:
		_bob_t += delta * cur_speed * 2.2
		_step_t += delta * cur_speed
		if _step_t > 1.9:
			_step_t = 0.0
			_step.pitch_scale = randf_range(0.85, 1.1)
			_step.play()
	if on_floor and not _was_floor:
		_step.play()
	_was_floor = on_floor
	var bob := bob_amount if Game.head_bob else 0.0
	cam.position.y = sin(_bob_t) * 0.04 * bob
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
	if Game.wasteland and not Game.blessed("speebyeet") and Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and is_on_floor():
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
