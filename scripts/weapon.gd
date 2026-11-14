class_name Arms
extends Node3D
## What the pilgrim carries into each trial: a primary and a secondary gun, a melee weapon,
## grenades and a gadget, as chosen on the loadout screen (ArmsDB holds the numbers).
##
##   Left mouse   fire                    Right mouse   aim down the sight
##   R            reload                  1 or X        switch primary and secondary
##   Z            strike with the melee   G             throw a grenade
##   T            use the gadget
##
## Ammunition never runs dry for long: a gun left quiet for a few seconds draws its reserve back
## up to two magazines by itself. A host may also choose that reserves are never spent at all.

const SHELL_RESERVE := 48.0   ## the shotgun's reserve that "reserve_max" is measured against

var player: Player
var enabled := true
var reserve_max := 48          ## raised in the waste and by Bandolier; scales every gun's reserve
var damage_mult := 1.0         ## raised by skills in the waste
var reload_mult := 1.0

var guns: Array = ["shotgun", "pistol"]
var cur := 0
var melee := "hatchet"
var grenade := "frag"
var gadget := "bandages"
var grenades := 2
var charges := 2
var _st := {}                  ## gun id -> {mag, reserve}

var shells: int:
	get:
		return int(_st[gun()].mag)
	set(v):
		_st[gun()].mag = v
var reserve: int:
	get:
		return int(_st[gun()].reserve)
	set(v):
		_st[gun()].reserve = v

var _cool := 0.0
var _reloading := false
var _reload_t := 0.0
var _kick := 0.0
var _spin := 0.0
var _quiet := 0.0              ## seconds since the last shot, for the reserve's slow return
var _trickle := 0.0
var _gren_t := 0.0
var _gadget_t := 0.0
var _melee_cool := 0.0
var _swing := 0.0
var _switch := 0.0
var _aim := 0.0
var _climb := 0.0
var _heal_left := 0.0
var _sway := Vector2.ZERO
var _models := {}
var _melee_models := {}
var _model: Node3D
var _pump: Node3D
var _flash: OmniLight3D
var _flash_mesh: MeshInstance3D
var _holder: Node3D
var _melee_holder: Node3D


func _ready() -> void:
	_holder = Node3D.new()
	add_child(_holder)
	_melee_holder = Node3D.new()
	_melee_holder.position = Vector3(-0.05, 0.0, 0.1)
	add_child(_melee_holder)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.5)
	_flash.light_energy = 0.0
	_flash.omni_range = 7
	_holder.add_child(_flash)
	_flash_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	_flash_mesh.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.85, 0.5)
	_flash_mesh.material_override = fm
	_flash_mesh.visible = false
	_holder.add_child(_flash_mesh)
	position = Vector3(0.16, -0.19, -0.5)
	rotation = Vector3(0.02, 0.05, 0)
	equip_loadout()


## Takes up whatever the loadout says, full of ammunition.
func equip_loadout() -> void:
	var lo: Dictionary = Game.loadout
	guns = [str(lo.get("primary", "shotgun")), str(lo.get("secondary", "pistol"))]
	for g in guns:
		if not ArmsDB.GUNS.has(g):
			guns = ["shotgun", "pistol"]
			break
	melee = str(lo.get("melee", "hatchet")) if ArmsDB.MELEE.has(lo.get("melee", "")) else "hatchet"
	grenade = str(lo.get("grenade", "frag")) if ArmsDB.GRENADES.has(lo.get("grenade", "")) else "frag"
	gadget = str(lo.get("gadget", "bandages")) if ArmsDB.GADGETS.has(lo.get("gadget", "")) else "bandages"
	for g in guns:
		if not _st.has(g):
			_st[g] = {"mag": int(ArmsDB.GUNS[g].mag), "reserve": int(ArmsDB.GUNS[g].mag) * 4}
	cur = 0
	grenades = int(ArmsDB.GRENADES[grenade].carry)
	charges = int(ArmsDB.GADGETS[gadget].charges)
	_show_model()


func gun() -> String:
	return guns[cur]


func spec() -> Dictionary:
	return ArmsDB.GUNS[gun()]


func capacity() -> int:
	return int(spec().mag)


func mount() -> String:
	return Game.mount_of(gun())


## The most reserve a gun can carry: eight magazines, or more where the waste allows.
func reserve_cap(g := "") -> int:
	if g == "":
		g = gun()
	var m: int = ArmsDB.GUNS[g].mag
	return maxi(m * 2, int(round(m * 8 * reserve_max / SHELL_RESERVE)))


func low_ammo() -> bool:
	return reserve < capacity() * 2


## Fills every carried gun to the brim, as at the start of a trial.
func refill() -> void:
	for g in guns:
		_st[g] = {"mag": int(ArmsDB.GUNS[g].mag), "reserve": int(ArmsDB.GUNS[g].mag) * 4}
	grenades = int(ArmsDB.GRENADES[grenade].carry)
	charges = int(ArmsDB.GADGETS[gadget].charges)
	_ui()


## Ammunition found or bought: n is counted in shotgun shells, and each gun takes its share.
func add_shells(n: int) -> void:
	for g in guns:
		var m: int = ArmsDB.GUNS[g].mag
		var add := maxi(1, int(ceil(n * m / 6.0))) if g == gun() else maxi(1, int(ceil(n * m / 12.0)))
		_st[g].reserve = mini(int(_st[g].reserve) + add, reserve_cap(g))
	_ui()


## What the waste keeps of the guns between sessions.
func ammo_state() -> Dictionary:
	return {"st": _st.duplicate(true), "gren": grenades, "gad": charges}


func set_ammo_state(d) -> void:
	if not d is Dictionary:
		return
	var st = d.get("st", {})
	if st is Dictionary:
		for g in st:
			if ArmsDB.GUNS.has(g) and st[g] is Dictionary:
				_st[g] = {"mag": clampi(int(st[g].get("mag", 0)), 0, int(ArmsDB.GUNS[g].mag)), "reserve": maxi(0, int(st[g].get("reserve", 0)))}
	grenades = clampi(int(d.get("gren", grenades)), 0, int(ArmsDB.GRENADES[grenade].carry))
	charges = clampi(int(d.get("gad", charges)), 0, int(ArmsDB.GADGETS[gadget].charges))
	_ui()


# ------------------------------------------------------------------ input

func _unhandled_input(e: InputEvent) -> void:
	if not enabled or player.input_locked or get_tree().paused:
		return
	if e.is_action_pressed("reload"):
		_start_reload()
	elif e.is_action_pressed("swap_gun"):
		swap()
	elif e.is_action_pressed("melee"):
		strike()
	elif e.is_action_pressed("grenade"):
		throw_grenade()
	elif e.is_action_pressed("gadget"):
		use_gadget()
	elif e.is_action_pressed("streak"):
		player.get_parent().call_streak()


func swap() -> void:
	if _switch > 0.0:
		return
	_reloading = false
	cur = 1 - cur
	_switch = 0.35
	_spin = 0.0
	_show_model()
	player.get_parent().sfx("shell", -12)
	_ui()


func _start_reload() -> void:
	if shells >= capacity() or reserve <= 0 or _reloading:
		return
	_reloading = true
	_reload_t = float(spec().reload_t) * reload_mult


# ------------------------------------------------------------------ each frame

func _process(delta: float) -> void:
	visible = enabled and not (player.input_locked and player.get_parent().completed)
	_cool = maxf(0.0, _cool - delta)
	_melee_cool = maxf(0.0, _melee_cool - delta)
	_switch = maxf(0.0, _switch - delta)
	_kick = move_toward(_kick, 0.0, delta * 4.0)
	_climb = move_toward(_climb, 0.0, delta * 1.5)
	_quiet += delta
	_recharge(delta)
	_heal(delta)
	if not enabled:
		_set_aim(0.0, delta)
		_spin = 0.0
		player.carry_slow = 1.0
		return
	var s := spec()
	# The pump or bolt travels after a shot
	if _pump:
		var phase := 0.0
		if _cool > 0.0 and s.mode in ["pump", "bolt"]:
			phase = sin(clampf(1.0 - _cool / float(s.rate), 0.0, 1.0) * PI)
		_pump.position.z = phase * (0.1 if s.mode == "pump" else 0.06)
	var bob := sin(Time.get_ticks_msec() * 0.008) * 0.006 * clampf(player.cur_speed / 3.0, 0.0, 1.5)
	_sway = _sway.lerp(Vector2.ZERO, delta * 8.0)
	var aiming := Input.is_action_pressed("aim") and not player.input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _reloading and _swing <= 0.0
	_set_aim(1.0 if aiming else 0.0, delta)
	var aim_off := Vector3(-0.16, 0.115 if mount() == "" else 0.1, 0.12) * _aim
	_holder.position = Vector3(_sway.x, bob - _kick * 0.04 + _sway.y - _switch * 0.5, _kick * 0.12 * (1.0 - _aim * 0.6)) + aim_off
	_holder.rotation.x = _kick * 0.35 * (1.0 - _aim * 0.7) - _switch * 1.4
	if _swing > 0.0:
		_swing = maxf(0.0, _swing - delta)
		var k := 1.0 - _swing / 0.35
		_melee_holder.visible = true
		_melee_holder.rotation = Vector3(-1.4 + k * 2.4, 0.5 - k * 1.2, 0.3)
		_holder.position.y -= 0.25
	else:
		_melee_holder.visible = false
	# Minigun: it must spin before it speaks, and it weighs on the one who carries it
	var holding := Input.is_action_pressed("fire") and not player.input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused
	if s.mode == "spin":
		_spin = move_toward(_spin, 1.0 if holding and shells > 0 and not _reloading else 0.0, delta / float(s.spin))
		if _pump:
			_pump.rotation.z += delta * 40.0 * _spin
		player.carry_slow = float(s.get("slow", 1.0))
	else:
		player.carry_slow = 1.0
	if _reloading:
		_holder.rotation.z = lerpf(_holder.rotation.z, 0.5, delta * 8.0)
		_reload_t -= delta
		if _reload_t <= 0.0:
			_reload_step()
	else:
		_holder.rotation.z = lerpf(_holder.rotation.z, 0.0, delta * 8.0)
	if holding and _switch <= 0.0 and _swing <= 0.0 and (s.mode != "semi" or Input.is_action_just_pressed("fire")):
		_try_fire()
	_trickle_back(delta)


func _reload_step() -> void:
	var s := spec()
	if reserve <= 0:
		_reloading = false
		return
	var lvl = player.get_parent()
	if s.reload == "shell":
		shells += 1
		if not Net.unlimited_ammo():
			reserve -= 1
		lvl.sfx("shell", -6)
		_reload_t = float(s.reload_t) * reload_mult * (0.65 if Game.blessed("speebchef") else 1.0)
		if shells >= capacity():
			_reloading = false
			lvl.sfx("pump", -4)
	else:
		var n := mini(capacity() - shells, reserve)
		shells += n
		if not Net.unlimited_ammo():
			reserve -= n
		_reloading = false
		lvl.sfx("pump", -6, null, 1.3)
	_ui()


## A quiet gun draws its reserve back toward two magazines, so a pilgrim is never left with nothing.
func _trickle_back(delta: float) -> void:
	if _quiet < 4.0:
		return
	for g in guns:
		var m: int = ArmsDB.GUNS[g].mag
		var floor_n := maxi(m * 2, 2)
		if int(_st[g].reserve) + int(_st[g].mag) >= floor_n:
			continue
		_trickle += delta * m / 10.0      # a magazine every ten seconds
		if _trickle >= 1.0:
			var n := int(_trickle)
			_trickle -= n
			_st[g].reserve = mini(int(_st[g].reserve) + n, floor_n)
			if g == gun():
				_ui()


func _recharge(delta: float) -> void:
	var gc: int = ArmsDB.GRENADES[grenade].carry
	if grenades < gc:
		_gren_t += delta
		if _gren_t >= 45.0:
			_gren_t = 0.0
			grenades += 1
			_ui()
	var gd: Dictionary = ArmsDB.GADGETS[gadget]
	if charges < int(gd.charges):
		_gadget_t += delta
		if _gadget_t >= float(gd.recharge):
			_gadget_t = 0.0
			charges += 1
			_ui()


func _heal(delta: float) -> void:
	if _heal_left <= 0.0:
		return
	var n := minf(_heal_left, 10.0 * delta)
	_heal_left -= n
	player.health = minf(player.max_health, player.health + n)
	Game.main.hud.set_health(player.health / player.max_health, true)


## Looking down the sight narrows the view; a scope narrows it far, and darkens the edges.
func _set_aim(target: float, delta: float) -> void:
	_aim = move_toward(_aim, target, delta * 6.0)
	var zoom := float(ArmsDB.SIGHTS.get(mount(), ArmsDB.SIGHTS[""]).zoom) if enabled else 1.0
	if enabled and gun() == "sniper":
		zoom = maxf(zoom, float(spec().zoom))
	var f: float = Game.fov / lerpf(1.0, zoom, _aim)
	if absf(player.cam.fov - f) > 0.01:
		player.cam.fov = f
	var scoped := enabled and _aim > 0.85 and zoom >= 2.4
	Game.main.hud.set_scope(scoped)
	_holder.visible = not scoped


func _ui() -> void:
	if not enabled:
		return
	var hud = Game.main.hud
	hud.set_ammo(shells, capacity(), reserve if not Net.unlimited_ammo() else -2)
	var line := "%s" % spec().name
	if mount() != "":
		line += " · " + ArmsDB.ATTACHMENTS[mount()].name
	line += "     %s %d     %s %d" % [ArmsDB.GRENADES[grenade].name.split(" ")[0], grenades, ArmsDB.GADGETS[gadget].name, charges]
	var ready = player.get_parent().get("streaks_ready")
	if ready is Array and not ready.is_empty():
		line += "     [H] " + Streaks.KINDS[ready[0]].name + (" +%d" % (ready.size() - 1) if ready.size() > 1 else "")
	hud.set_kit(line)


func sway(rel: Vector2) -> void:
	_sway += Vector2(-rel.x, rel.y) * 0.00012 * (1.0 - _aim * 0.7)


# ------------------------------------------------------------------ firing

func _try_fire() -> void:
	var s := spec()
	if _cool > 0.0:
		return
	if shells <= 0:
		if reserve <= 0:
			_cool = 0.5
			player.get_parent().sfx("shell", -14)
			return
		_start_reload()
		return
	if _reloading:
		if s.reload == "shell":
			_reloading = false
			_cool = 0.25
		return
	if s.mode == "spin" and _spin < 1.0:
		return
	shells -= 1
	_quiet = 0.0
	_ui()
	_cool = float(s.rate)
	_kick = minf(1.0, _kick + float(s.kick) * (0.35 if s.mode in ["auto", "spin"] else 1.0))
	player.shake(0.18 * float(s.kick) * (1.0 - 0.5 * _aim))
	var climb := 0.045 * float(s.kick) * (1.0 - 0.5 * _aim)
	if s.mode in ["auto", "spin"]:
		_climb += 0.1
		climb = 0.008 + 0.006 * _climb
	player.pitch = minf(player.pitch + climb, 1.45)
	var lvl = player.get_parent()
	var quiet := mount() == "suppressor"
	lvl.sfx("supp" if quiet else str(s.sound), -10 if quiet else -2)
	if s.mode == "pump":
		get_tree().create_timer(0.3, false).timeout.connect(func(): lvl.sfx("pump", -8))
	elif s.mode == "bolt":
		get_tree().create_timer(0.45, false).timeout.connect(func(): lvl.sfx("pump", -8, null, 1.25))
	if not quiet:
		_flash.light_energy = 4.0 if s.mode != "spin" else 2.5
		_flash_mesh.visible = true
		_flash_mesh.rotation.z = randf() * TAU
		get_tree().create_timer(0.04, false).timeout.connect(func():
			_flash.light_energy = 0.0
			_flash_mesh.visible = false)
	var cam := player.cam
	var origin := cam.global_position
	var fwd := -cam.global_transform.basis.z
	Net.fx("gun:%s%s" % [gun(), ":s" if quiet else ""], origin, fwd)
	lvl.shots += 1
	if s.mode == "rocket":
		var r := Rocket.new()
		r.owner_player = player
		r.dmg = float(s.dmg) * damage_mult
		r.radius = float(s.radius)
		r.vel = fwd * float(s.speed)
		lvl.add_child(r)
		r.global_position = origin + fwd * 0.9 + cam.global_transform.basis.x * 0.15 - cam.global_transform.basis.y * 0.1
		return
	var space := get_world_3d().direct_space_state
	var spread := float(s.spread)
	spread *= lerpf(1.0, float(ArmsDB.SIGHTS.get(mount(), ArmsDB.SIGHTS[""]).spread), _aim)
	if mount() == "red_dot":
		spread *= 0.85
	if player.cur_speed > 3.0:
		spread *= 1.4
	if s.mode in ["auto", "spin"]:
		spread *= 1.0 + _climb * 0.6
	var hits := {}
	var dmg_m := damage_mult * (1.3 if Game.blessed("speebsnek") else 1.0) * (0.92 if quiet else 1.0)
	for i in int(s.pellets):
		var dir := fwd
		if spread > 0.0:
			dir = dir.rotated(cam.global_transform.basis.x, randf_range(-spread, spread) * 0.7)
			dir = dir.rotated(cam.global_transform.basis.y, randf_range(-spread, spread))
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * float(s.range), 1 | 2)
		q.exclude = [player.get_rid()]
		q.collide_with_areas = false
		var r := space.intersect_ray(q)
		if r.is_empty():
			continue
		var target = r.collider
		var dist := origin.distance_to(r.position)
		var fall := 1.0
		if float(s.falloff) > 0.0:
			fall = clampf(1.4 - dist / float(s.falloff), 0.35, 1.0)
		var dmg := float(s.dmg) * fall * dmg_m
		if target and target.has_method("hurt"):
			hits[target] = hits.get(target, 0.0) + dmg
		else:
			lvl.puff(r.position, r.normal)
	if not hits.is_empty():
		lvl.hits += 1
	Arms.deal(hits, fwd)


## Applies harm to each struck thing and shows the hit marker once.
static var _told_deflect := -100000


static func deal(hits: Dictionary, dir: Vector3) -> void:
	var marked := 0
	for t in hits:
		if is_instance_valid(t) and t.has_method("hurt"):
			var full: bool = t.hurt(hits[t], dir)
			var killed: bool = t.has_method("is_alive") and not t.is_alive()
			if killed:
				marked = 2
			elif full:
				marked = maxi(marked, 1)
			elif marked == 0:
				marked = -1
			if not full and not killed and t.get("kind") == "idol" and Time.get_ticks_msec() - _told_deflect > 20000:
				_told_deflect = Time.get_ticks_msec()
				Game.main.hud.notify("The gilded face turns the shot aside. Strike it from the side or behind.")
	if marked > 0:
		Game.main.hud.hitmarker(marked == 2)
		if Game.main.level:
			Game.main.level.sfx("tick", -6 if marked == 1 else -2, null, 1.0 if marked == 1 else 0.7)
	elif marked < 0:
		# Struck, but turned aside: a grey ring and a hard high note, so it is plain the shot did little
		Game.main.hud.hitmarker(false, true)
		if Game.main.level:
			Game.main.level.sfx("tick", -4, null, 1.9)


## Harms everything near a point, less at the edge. The thrower is hurt too if they stand in it.
static func blast(lvl: Node, at: Vector3, radius: float, dmg: float, thrower: Node = null) -> void:
	var space: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	q.shape = sh
	q.transform = Transform3D(Basis(), at)
	q.collision_mask = 1 | 2
	var hits := {}
	for r in space.intersect_shape(q, 64):
		var c = r.collider
		if c is Player or not (c is Node and c.has_method("hurt")) or hits.has(c):
			continue
		var d: float = (c.global_position + Vector3(0, 0.6, 0)).distance_to(at)
		hits[c] = dmg * clampf(1.15 - d / radius, 0.25, 1.0)
	deal(hits, Vector3.UP)
	if thrower and is_instance_valid(thrower) and thrower.global_position.distance_to(at) < radius * 0.8 and lvl.has_method("damage_player"):
		lvl.damage_player(dmg * 0.3 * clampf(1.0 - thrower.global_position.distance_to(at) / radius, 0.2, 1.0), at)
	blast_fx(lvl, at, radius)
	Net.fx("blast", at, Vector3(radius, 0, 0))


## What a burst looks and sounds like, for everyone.
static func blast_fx(lvl: Node, at: Vector3, radius: float) -> void:
	lvl.sfx("boom", 0, at, randf_range(0.9, 1.1))
	var root := Node3D.new()
	lvl.add_child(root)
	root.global_position = at
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 9.0
	l.omni_range = radius * 3.0
	root.add_child(l)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	ball.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.7, 0.35, 0.9)
	ball.material_override = m
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ball)
	var smoke := CPUParticles3D.new()
	smoke.amount = 40
	smoke.one_shot = true
	smoke.explosiveness = 0.95
	smoke.lifetime = 2.2
	smoke.direction = Vector3.UP
	smoke.spread = 90.0
	smoke.initial_velocity_min = radius * 0.6
	smoke.initial_velocity_max = radius * 1.4
	smoke.gravity = Vector3(0, 1.2, 0)
	smoke.damping_min = 3.0
	smoke.damping_max = 5.0
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.4
	var pm := SphereMesh.new()
	pm.radius = 0.4
	pm.height = 0.8
	var sm2 := StandardMaterial3D.new()
	sm2.albedo_color = Color(0.22, 0.2, 0.18, 0.7)
	sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.material = sm2
	smoke.mesh = pm
	smoke.emitting = true
	root.add_child(smoke)
	var tw := root.create_tween().set_parallel()
	tw.tween_property(ball, "scale", Vector3.ONE * radius * 1.6, 0.25)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.chain().tween_interval(2.0)
	tw.chain().tween_callback(root.queue_free)
	var pl = lvl.get("player")
	if pl and is_instance_valid(pl) and pl.global_position.distance_to(at) < radius * 6.0:
		pl.shake(clampf(1.2 - pl.global_position.distance_to(at) / (radius * 6.0), 0.1, 0.9))


# ------------------------------------------------------------------ melee, grenades, gadgets

func strike() -> void:
	if _melee_cool > 0.0 or _swing > 0.0:
		return
	var m: Dictionary = ArmsDB.MELEE[melee]
	_melee_cool = float(m.rate)
	_swing = 0.35
	_reloading = false
	_show_melee()
	var lvl = player.get_parent()
	lvl.sfx("swing", -6, null, randf_range(0.9, 1.1) * (0.8 if melee == "sledge" else 1.0))
	get_tree().create_timer(0.12, false).timeout.connect(func(): _melee_hit(m))


func _melee_hit(m: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	var lvl = player.get_parent()
	var cam := player.cam
	var origin := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var hits := {}
	var q := PhysicsRayQueryParameters3D.create(origin, origin + fwd * float(m.reach), 1 | 2)
	q.exclude = [player.get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() and r.collider is Node and r.collider.has_method("hurt"):
		hits[r.collider] = float(m.dmg) * damage_mult
	for e in lvl.get("enemies") if lvl.get("enemies") != null else []:
		if not is_instance_valid(e) or hits.has(e) or not e.is_alive():
			continue
		var to: Vector3 = e.global_position + Vector3(0, 0.6, 0) - origin
		if to.length() < float(m.reach) + 0.6 and fwd.dot(to.normalized()) > 0.6:
			hits[e] = float(m.dmg) * damage_mult
	if not hits.is_empty():
		lvl.sfx("chop", -4, null, randf_range(0.85, 1.1))
		player.shake(0.15)
		Arms.deal(hits, fwd)
	elif not r.is_empty():
		lvl.puff(r.position, r.normal)
		lvl.sfx("thud", -10)


func throw_grenade() -> void:
	if grenades <= 0:
		player.get_parent().sfx("deny", -14)
		return
	grenades -= 1
	_ui()
	var g: Dictionary = ArmsDB.GRENADES[grenade]
	var cam := player.cam
	var fwd := -cam.global_transform.basis.z
	var vel := (fwd + Vector3.UP * 0.25).normalized() * 16.0 + player.velocity * 0.5
	var at := cam.global_position + fwd * 0.6
	var b := Thrown.make(player.get_parent(), "grenade" if grenade == "frag" else "fire", at, vel)
	b.thrower = player
	b.fuse = float(g.fuse)
	b.on_burst = func(p: Vector3):
		if grenade == "incendiary":
			Thrown.burn(player.get_parent(), p, float(g.radius), float(g.dmg) * damage_mult, float(g.burn), true)
		else:
			Arms.blast(player.get_parent(), p, float(g.radius), float(g.dmg) * damage_mult, player)
	Net.fx("throw:%s" % ("grenade" if grenade == "frag" else "fire"), at, vel)
	player.get_parent().sfx("swing", -10, null, 1.4)


func use_gadget() -> void:
	if charges <= 0:
		player.get_parent().sfx("deny", -14)
		return
	var lvl = player.get_parent()
	match gadget:
		"bandages":
			if player.health >= player.max_health - 0.5:
				Game.main.hud.notify("You are whole. The dressing can wait.")
				return
			_heal_left += 40.0
			lvl.sfx("carve", -10, null, 1.3)
		"flare":
			var cam := player.cam
			var fwd := -cam.global_transform.basis.z
			var vel := (fwd + Vector3.UP * 0.4).normalized() * 13.0
			var at := cam.global_position + fwd * 0.6
			var b := Thrown.make(lvl, "flare", at, vel)
			b.fuse = 45.0
			Net.fx("throw:flare", at, vel)
		"mine":
			var p: Vector3 = player.global_position - player.global_transform.basis.z * 1.4
			var b := Thrown.make(lvl, "mine", p + Vector3(0, 0.5, 0), Vector3.ZERO)
			b.thrower = player
			b.fuse = 600.0
			b.armed_after = 1.5
			b.on_burst = func(at: Vector3): Arms.blast(lvl, at, 4.5, 140.0 * damage_mult, null)
			Net.fx("throw:mine", p + Vector3(0, 0.5, 0), Vector3.ZERO)
	charges -= 1
	_ui()


# ------------------------------------------------------------------ the guns, made of plain parts

func _show_model() -> void:
	for k in _models:
		_models[k].visible = false
	var g := gun()
	if not _models.has(g):
		_models[g] = _build(g)
		_holder.add_child(_models[g])
	_model = _models[g]
	_model.visible = true
	_pump = _model.get_meta("pump") if _model.has_meta("pump") else null
	var tip: Vector3 = _model.get_meta("tip")
	_flash.position = tip
	_flash_mesh.position = tip
	_ui()


func _show_melee() -> void:
	for k in _melee_models:
		_melee_models[k].visible = false
	if not _melee_models.has(melee):
		_melee_models[melee] = _build_melee(melee)
		_melee_holder.add_child(_melee_models[melee])
	_melee_models[melee].visible = true


func _mat(c: Color, metal := 0.0, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _metal() -> StandardMaterial3D:
	if Game.gilded:
		return _mat(Color(0.85, 0.66, 0.3), 1.0, 0.22)
	return _mat(Color(0.12, 0.12, 0.13), 0.8, 0.35)


func _box(size: Vector3, pos: Vector3, m: Material, parent: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _tube(r: float, length: float, pos: Vector3, m: Material, parent: Node3D, r2 := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r if r2 < 0.0 else r2
	cm.height = length
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation.x = PI / 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build(g: String) -> Node3D:
	var n := Node3D.new()
	var metal := _metal()
	var dark := _mat(Color(0.07, 0.07, 0.075), 0.5, 0.5)
	var wood := _mat(Color(0.32, 0.2, 0.12))
	var brass := _mat(Color(0.7, 0.55, 0.3), 0.9, 0.3)
	var olive := _mat(Color(0.2, 0.22, 0.16), 0.2, 0.7)
	var pump := Node3D.new()
	n.add_child(pump)
	n.set_meta("pump", pump)
	var top := 0.05      # where a sight sits
	var tip := Vector3(0, 0.03, -0.8)
	match g:
		"shotgun":
			_box(Vector3(0.07, 0.09, 0.32), Vector3(0, 0, 0.05), metal, n)
			_tube(0.022, 0.62, Vector3(0, 0.025, -0.4), metal, n)
			_tube(0.018, 0.5, Vector3(0, -0.025, -0.34), metal, n)
			_box(Vector3(0.055, 0.09, 0.2), Vector3(0, -0.035, 0.29), wood, n, Vector3(-0.18, 0, 0))
			_box(Vector3(0.074, 0.03, 0.12), Vector3(0, -0.035, 0.12), brass, n)
			_box(Vector3(0.06, 0.06, 0.17), Vector3(0, -0.03, -0.3), wood, pump)
			tip = Vector3(0, 0.03, -0.75)
		"machine_gun":
			_box(Vector3(0.07, 0.1, 0.42), Vector3(0, 0, 0.0), metal, n)
			_tube(0.016, 0.42, Vector3(0, 0.02, -0.42), dark, n)
			_box(Vector3(0.06, 0.07, 0.22), Vector3(0, 0.0, -0.3), olive, n)
			_box(Vector3(0.04, 0.16, 0.07), Vector3(0, -0.11, -0.06), dark, n, Vector3(0.25, 0, 0))
			_box(Vector3(0.045, 0.1, 0.05), Vector3(0, -0.08, 0.12), olive, n, Vector3(-0.3, 0, 0))
			_box(Vector3(0.05, 0.08, 0.2), Vector3(0, -0.02, 0.32), olive, n)
			_box(Vector3(0.012, 0.03, 0.05), Vector3(0.03, 0.03, 0.05), dark, pump)
			tip = Vector3(0, 0.02, -0.66)
			top = 0.06
		"sniper":
			_box(Vector3(0.065, 0.085, 0.4), Vector3(0, 0, 0.02), metal, n)
			_tube(0.014, 0.78, Vector3(0, 0.02, -0.56), dark, n)
			_box(Vector3(0.06, 0.07, 0.42), Vector3(0, -0.03, -0.12), wood, n)
			_box(Vector3(0.055, 0.11, 0.24), Vector3(0, -0.05, 0.32), wood, n, Vector3(-0.12, 0, 0))
			_tube(0.024, 0.3, Vector3(0, 0.085, -0.02), dark, n)
			_box(Vector3(0.012, 0.012, 0.06), Vector3(0.05, 0.03, 0.12), brass, pump)
			tip = Vector3(0, 0.02, -0.96)
			top = 0.11
		"rocket":
			_tube(0.06, 0.95, Vector3(0, 0.0, -0.1), olive, n)
			_tube(0.068, 0.08, Vector3(0, 0.0, -0.58), dark, n)
			_tube(0.068, 0.1, Vector3(0, 0.0, 0.38), dark, n)
			_box(Vector3(0.04, 0.12, 0.06), Vector3(0, -0.1, 0.0), dark, n, Vector3(0.2, 0, 0))
			_box(Vector3(0.04, 0.1, 0.05), Vector3(0, -0.09, -0.22), dark, n)
			var head := _tube(0.045, 0.14, Vector3(0, 0, -0.6), _mat(Color(0.35, 0.33, 0.28), 0.4, 0.5), pump, 0.02)
			head.rotation.x = -PI / 2
			tip = Vector3(0, 0.0, -0.66)
			top = 0.09
		"minigun":
			_box(Vector3(0.14, 0.14, 0.26), Vector3(0, -0.02, 0.12), dark, n)
			_box(Vector3(0.05, 0.12, 0.1), Vector3(0, 0.1, 0.1), metal, n)
			for i in 6:
				var a := i * TAU / 6.0
				_tube(0.012, 0.62, Vector3(cos(a) * 0.035, sin(a) * 0.035, -0.34), metal, pump)
			_tube(0.05, 0.03, Vector3(0, 0, -0.2), dark, pump)
			_tube(0.05, 0.03, Vector3(0, 0, -0.6), dark, pump)
			pump.position = Vector3(0, 0, 0)
			tip = Vector3(0, 0.0, -0.68)
			top = 0.12
		"pistol":
			_box(Vector3(0.04, 0.05, 0.2), Vector3(0, 0.02, -0.08), metal, n)
			_box(Vector3(0.036, 0.11, 0.05), Vector3(0, -0.05, 0.0), dark, n, Vector3(-0.22, 0, 0))
			_box(Vector3(0.042, 0.035, 0.2), Vector3(0, 0.045, -0.08), dark, pump)
			tip = Vector3(0, 0.03, -0.2)
			top = 0.065
		"revolver":
			_tube(0.016, 0.22, Vector3(0, 0.03, -0.17), metal, n)
			_tube(0.03, 0.05, Vector3(0, 0.01, -0.03), metal, n)
			_box(Vector3(0.04, 0.05, 0.08), Vector3(0, 0.02, 0.02), metal, n)
			_box(Vector3(0.036, 0.11, 0.05), Vector3(0, -0.05, 0.05), wood, n, Vector3(-0.3, 0, 0))
			tip = Vector3(0, 0.03, -0.29)
			top = 0.05
	# The chosen sight, suppressor or scope
	match Game.mount_of(g):
		"red_dot":
			_box(Vector3(0.03, 0.035, 0.05), Vector3(0, top + 0.015, -0.02), dark, n)
			var glass := _mat(Color(0.6, 0.1, 0.1, 0.5))
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.emission_enabled = true
			glass.emission = Color(1, 0.1, 0.1)
			glass.emission_energy_multiplier = 0.4
			_box(Vector3(0.024, 0.024, 0.004), Vector3(0, top + 0.02, -0.044), glass, n)
		"scope":
			if g != "sniper":
				_tube(0.022, 0.24, Vector3(0, top + 0.03, -0.02), dark, n)
		"suppressor":
			_tube(0.024, 0.18, tip + Vector3(0, 0, -0.08), dark, n)
			tip += Vector3(0, 0, -0.17)
	n.set_meta("tip", tip)
	return n


func _build_melee(id: String) -> Node3D:
	var n := Node3D.new()
	var wood := _mat(Color(0.3, 0.19, 0.11))
	var steel := _mat(Color(0.45, 0.45, 0.47), 0.85, 0.35)
	match id:
		"hatchet":
			_box(Vector3(0.03, 0.42, 0.035), Vector3(0, 0.12, 0), wood, n)
			_box(Vector3(0.012, 0.09, 0.14), Vector3(0, 0.3, -0.05), steel, n)
		"machete":
			_box(Vector3(0.03, 0.12, 0.035), Vector3(0, 0.0, 0), wood, n)
			_box(Vector3(0.006, 0.5, 0.05), Vector3(0, 0.3, -0.01), steel, n)
		"sledge":
			_box(Vector3(0.035, 0.6, 0.035), Vector3(0, 0.2, 0), wood, n)
			_box(Vector3(0.09, 0.09, 0.2), Vector3(0, 0.5, 0), steel, n)
	return n


# ================================================================== things that fly

## A rocket: flies straight, bursts on whatever it meets. Only the shooter's rocket does harm;
## the copies the fellowship sees are only shown.
class Rocket extends Node3D:
	var vel := Vector3.ZERO
	var dmg := 0.0
	var radius := 5.0
	var owner_player: Node = null
	var shown_only := false
	var _life := 8.0

	func _ready() -> void:
		var body := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.045
		cm.height = 0.35
		body.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.3, 0.27)
		body.material_override = m
		body.rotation.x = -PI / 2
		add_child(body)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.3)
		l.light_energy = 2.5
		l.omni_range = 5.0
		l.position = Vector3(0, 0, 0.25)
		add_child(l)
		var trail := CPUParticles3D.new()
		trail.amount = 60
		trail.lifetime = 1.2
		trail.local_coords = false
		trail.position = Vector3(0, 0, 0.2)
		trail.direction = Vector3(0, 0, 1)
		trail.spread = 8.0
		trail.initial_velocity_min = 0.5
		trail.initial_velocity_max = 1.0
		trail.gravity = Vector3(0, 0.6, 0)
		trail.scale_amount_min = 0.5
		trail.scale_amount_max = 1.2
		var pm := SphereMesh.new()
		pm.radius = 0.12
		pm.height = 0.24
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.55, 0.52, 0.48, 0.5)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.material = sm
		trail.mesh = pm
		add_child(trail)
		if vel.length() > 0.01:
			look_at(global_position + vel, Vector3.UP if absf(vel.normalized().y) < 0.99 else Vector3.RIGHT)

	func _physics_process(delta: float) -> void:
		_life -= delta
		var from := global_position
		var to := from + vel * delta
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
		if owner_player and is_instance_valid(owner_player):
			q.exclude = [owner_player.get_rid()]
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty() or _life <= 0.0:
			var at: Vector3 = r.position if not r.is_empty() else to
			if not shown_only:
				Arms.blast(get_parent(), at, radius, dmg, owner_player)
			queue_free()
			return
		global_position = to


## A grenade, a flare or a mine: a small body that bounces and settles, and bursts when its time
## comes (or, for a mine, when a form steps near).
class Thrown extends RigidBody3D:
	var kind := "grenade"
	var fuse := 2.0
	var thrower: Node = null
	var shown_only := false
	var armed_after := -1.0
	var on_burst: Callable
	var _light: OmniLight3D

	static func make(lvl: Node, k: String, at: Vector3, v: Vector3, only_shown := false) -> Thrown:
		var t := Thrown.new()
		t.kind = k
		t.shown_only = only_shown
		t.linear_velocity = v
		t.collision_layer = 0
		t.collision_mask = 1
		t.mass = 0.4
		t.continuous_cd = true
		t.angular_damp = 2.0
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.3
		pm.friction = 0.9
		t.physics_material_override = pm
		if k == "mine":
			t.freeze = false
			t.lock_rotation = true
		lvl.add_child(t)
		t.global_position = at
		return t

	func _ready() -> void:
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.08 if kind != "mine" else 0.14
		cs.shape = sh
		add_child(cs)
		var mi := MeshInstance3D.new()
		var m := StandardMaterial3D.new()
		match kind:
			"grenade":
				var s := SphereMesh.new()
				s.radius = 0.06
				s.height = 0.12
				mi.mesh = s
				m.albedo_color = Color(0.2, 0.24, 0.16)
			"fire":
				var c := CylinderMesh.new()
				c.top_radius = 0.04
				c.bottom_radius = 0.04
				c.height = 0.16
				mi.mesh = c
				m.albedo_color = Color(0.45, 0.12, 0.08)
			"flare":
				var c := CylinderMesh.new()
				c.top_radius = 0.025
				c.bottom_radius = 0.025
				c.height = 0.2
				mi.mesh = c
				m.albedo_color = Color(0.9, 0.2, 0.15)
				m.emission_enabled = true
				m.emission = Color(1.0, 0.15, 0.1)
				m.emission_energy_multiplier = 3.0
				_light = OmniLight3D.new()
				_light.light_color = Color(1.0, 0.25, 0.15)
				_light.light_energy = 3.5
				_light.omni_range = 22.0
				_light.shadow_enabled = false
				add_child(_light)
			"mine":
				var c := CylinderMesh.new()
				c.top_radius = 0.16
				c.bottom_radius = 0.18
				c.height = 0.06
				mi.mesh = c
				m.albedo_color = Color(0.85, 0.83, 0.78)
		mi.material_override = m
		add_child(mi)

	func _physics_process(delta: float) -> void:
		fuse -= delta
		if _light:
			_light.light_energy = 3.0 + randf() * 1.2
		if kind == "mine" and not shown_only:
			armed_after -= delta
			if armed_after <= 0.0:
				var lvl = get_parent()
				for e in lvl.get("enemies") if lvl.get("enemies") != null else []:
					if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(global_position) < 2.6:
						fuse = 0.0
						break
		if fuse <= 0.0:
			var at := global_position + Vector3(0, 0.2, 0)
			if not shown_only and on_burst.is_valid():
				on_burst.call(at)
			elif shown_only and kind == "fire":
				Thrown.burn(get_parent(), at, 5.0, 0.0, 7.0, false)
			queue_free()

	## Ground that burns for a while: harms the forms that stand in it.
	static func burn(lvl: Node, at: Vector3, radius: float, dps: float, secs: float, real: bool) -> void:
		var root := Node3D.new()
		lvl.add_child(root)
		root.global_position = at
		lvl.sfx("boom", -8, at, 1.4)
		var fire := CPUParticles3D.new()
		fire.amount = 90
		fire.lifetime = 0.9
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.emission_sphere_radius = radius * 0.8
		fire.direction = Vector3.UP
		fire.spread = 15.0
		fire.initial_velocity_min = 1.0
		fire.initial_velocity_max = 2.5
		fire.gravity = Vector3(0, 1.0, 0)
		fire.scale_amount_min = 0.6
		fire.scale_amount_max = 1.4
		var pm := SphereMesh.new()
		pm.radius = 0.18
		pm.height = 0.36
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(1.0, 0.5, 0.15, 0.8)
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.material = fm
		fire.mesh = pm
		root.add_child(fire)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.5, 0.2)
		l.light_energy = 3.0
		l.omni_range = radius * 2.5
		l.position.y = 0.8
		root.add_child(l)
		var t := 0.0
		while t < secs and is_instance_valid(root):
			await root.get_tree().create_timer(0.5, false).timeout
			t += 0.5
			if not real or not is_instance_valid(lvl):
				continue
			var hits := {}
			for e in lvl.get("enemies") if lvl.get("enemies") != null else []:
				if is_instance_valid(e) and e.is_alive() and e.global_position.distance_to(at) < radius:
					hits[e] = dps
			if not hits.is_empty():
				Arms.deal(hits, Vector3.UP)
		if is_instance_valid(root):
			fire.emitting = false
			var tw := root.create_tween()
			tw.tween_property(l, "light_energy", 0.0, 1.0)
			tw.tween_callback(root.queue_free)
