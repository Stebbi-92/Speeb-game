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
		if pack:
			return pack.count(Items.AMMO[gun()])
		return int(_st[gun()].reserve)
	set(v):
		if pack:
			var id: String = Items.AMMO[gun()]
			var have := pack.count(id)
			if v < have:
				pack.take(id, have - v)
			elif v > have:
				pack.add(id, v - have)
			return
		_st[gun()].reserve = v
var pack: Inventory            ## in the waste, rounds are carried in the pack, each kind to its own guns

var _cool := 0.0
var _reloading := false
var _reload_t := 0.0
var _reload_len := 1.0   ## how long this reload (or this one shell) takes, for the hands' motion
var _rl_out := false     ## the old magazine is out (its sound played)
var _rl_in := false      ## the fresh one is in
var _shell_mesh: MeshInstance3D
var _kick := 0.0
var _spin := 0.0
var _quiet := 0.0              ## seconds since the last shot, for the reserve's slow return
var _trickle := 0.0
var _gren_t := 0.0
var _gadget_t := 0.0
var _melee_cool := 0.0
var _spec_cache := {}
var blade_out := false       ## the blade is in hand: fire swings it, a long hold swings hard, aim guards
var guarding := false
var _charge := -1.0          ## seconds the fire button has been held with the blade out; -1 when not held
var _heavy := false          ## the swing under way is a heavy one
var _swing := 0.0
var _switch := 0.0
var _aim := 0.0
var _climb := 0.0
var _bloom := 0.0     ## how far shots wander from firing in a string (mostly from the hip)
var _string := 0      ## shots in the current string, for the gun's kick pattern
var _pull := 0.0      ## how far the kick has lifted the view; most comes back when you stop
var spread_now := 0.0 ## the spread a shot would have right now, for the crosshair
var _heal_left := 0.0
var _sway := Vector2.ZERO
var debug_aim := false
var hold_fire := false       ## set when a panel closes on a click, so that click does not also fire
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
	_spec_cache.clear()
	var lo: Dictionary = Game.arms_now()
	for k in _models:
		_models[k].queue_free()
	_models.clear()
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
			_st[g] = {"mag": Arms.mag_of(g), "reserve": Arms.mag_of(g) * 4}
	cur = 0
	grenades = int(ArmsDB.GRENADES[grenade].carry)
	charges = int(ArmsDB.GADGETS[gadget].charges)
	_show_model()


func gun() -> String:
	return guns[cur]


## The gun in hand, as its parts and their traits have made it.
func spec() -> Dictionary:
	var g := gun()
	if not _spec_cache.has(g):
		var sp := spec_of(g)
		var sk = _skills()
		if sk:
			var b: Dictionary = sk.use_bonus(g)
			sp.dmg = float(sp.dmg) * b.dmg
			sp.kick = float(sp.kick) * b.kick
			sp.reload_t = float(sp.reload_t) * b.reload
			sp.aim = float(sp.aim) * b.aim
			sp.spread = float(sp.spread) * b.spread
		_spec_cache[g] = sp
	return _spec_cache[g]


## The survivor's skills, in the waste only.
func _skills():
	var lvl = player.get_parent() if is_instance_valid(player) else null
	return lvl.get("skills") if lvl != null and lvl.get("skills") is WSkills else null


## Shots heard striking home: a wet thud in flesh, a ring off the gilded faces.
func _impact_sounds(hits: Dictionary) -> void:
	var n := 0
	for t in hits:
		if n >= 2 or not is_instance_valid(t):
			break
		n += 1
		var metal: bool = t.get("kind") == "idol" or t.get("kind") == "saucer"
		player.get_parent().sfx("hit_metal" if metal else "hit_flesh", -6 if metal else -9, t.global_position + Vector3(0, 0.8, 0))


## Practice with the weapon in hand from what a blow or a shot did.
func _practise(id: String, hits: Dictionary) -> void:
	var sk = _skills()
	if sk == null or hits.is_empty():
		return
	var n := 0
	for t in hits:
		n += 1
		if is_instance_valid(t) and t.has_method("is_alive") and not t.is_alive():
			n += 4
	if sk.practise(id, n):
		_spec_cache.clear()
		var lv: int = sk.use_level(id)
		var nm: String = ArmsDB.GUNS[id].name if ArmsDB.GUNS.has(id) else "the blade"
		Game.main.hud.notify("%s with %s. %s." % [WSkills.USE_RANKS[lv], nm, WSkills.use_text(lv)])
		player.get_parent().sfx("choir", -10, null, 1.3)


static func spec_of(g: String) -> Dictionary:
	var s: Dictionary = ArmsDB.GUNS[g].duplicate()
	var md: Dictionary = Game.gun_mods(g)
	s.dmg = float(s.dmg) * md.dmg
	s.rate = float(s.rate) * md.rate
	s.spread = float(s.spread) * md.spread
	s.range = float(s.range) * md.range
	s.falloff = float(s.falloff) * md.range
	s.reload_t = float(s.reload_t) * md.reload
	s.kick = float(s.kick) * md.kick
	s["aim"] = md.aim
	s["crit"] = md.crit
	s["pierce"] = float(md.get("pierce", 1.0))
	return s


func capacity() -> int:
	return Arms.mag_of(gun())


## How many rounds a gun holds: more with a longer magazine, and more again as it is worked on in the waste.
static func mag_of(g: String) -> int:
	var m := float(ArmsDB.GUNS[g].mag)
	if Game.has_mount(g, "ext_mag"):
		m *= 1.5
	m *= float(Game.gun_mods(g).mag)
	return maxi(1, int(round(m * (1.0 + 0.15 * Game.tier_of(g)))))


## The sight on the gun in hand ("" is iron sights).
func mount() -> String:
	return Game.mount_of(gun())


func fitted(id: String) -> bool:
	return Game.has_mount(gun(), id)


## What the work done on this gun adds to each shot.
func tier_mult() -> float:
	return 1.0 + 0.12 * Game.tier_of(gun())


## The most reserve a gun can carry: eight magazines, or more where the waste allows.
func reserve_cap(g := "") -> int:
	if g == "":
		g = gun()
	var m: int = Arms.mag_of(g)
	return maxi(m * 2, int(round(m * 8 * reserve_max / SHELL_RESERVE)))


func low_ammo() -> bool:
	return reserve < capacity() * 2


## Fills every carried gun to the brim, as at the start of a trial.
func refill() -> void:
	for g in guns:
		_st[g] = {"mag": Arms.mag_of(g), "reserve": Arms.mag_of(g) * 4}
	grenades = int(ArmsDB.GRENADES[grenade].carry)
	charges = int(ArmsDB.GADGETS[gadget].charges)
	_ui()


## Ammunition found or bought: n is counted in shotgun shells, and each gun takes its share.
func add_shells(n: int) -> void:
	if pack:
		pack.add(Items.AMMO[gun()], n if Items.AMMO[gun()] != "rockets" else maxi(1, n / 6))
		_ui()
		return
	for g in guns:
		var m: int = Arms.mag_of(g)
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
				_st[g] = {"mag": clampi(int(st[g].get("mag", 0)), 0, Arms.mag_of(g)), "reserve": maxi(0, int(st[g].get("reserve", 0)))}
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


## Takes the long gun (0) or the side arm (1) in hand.
func draw_gun(i: int) -> void:
	if blade_out:
		_sheathe()
		if cur != i:
			cur = i
			_show_model()
		return
	if cur != i:
		swap()


## Takes the blade in hand. Fire swings it; held a moment longer, it swings hard.
func draw_blade() -> void:
	if blade_out or _switch > 0.0:
		return
	blade_out = true
	_reloading = false
	_spin = 0.0
	_switch = 0.25
	player.get_parent().sfx("draw", -10)
	_charge = -1.0
	_show_melee()
	_holder.visible = false
	player.get_parent().sfx("swing", -16, null, 1.4)
	_ui()


func _sheathe() -> void:
	blade_out = false
	guarding = false
	_charge = -1.0
	_switch = 0.3
	_holder.visible = true
	player.get_parent().sfx("shell", -12)
	_ui()


func swap() -> void:
	if _switch > 0.0:
		return
	if blade_out:
		_sheathe()
		return
	_reloading = false
	cur = 1 - cur
	_switch = 0.35
	_spin = 0.0
	_show_model()
	player.get_parent().sfx("shell", -12)
	_ui()


func _start_reload() -> void:
	if blade_out or shells >= capacity() or reserve <= 0 or _reloading:
		return
	_reloading = true
	_reload_t = float(spec().reload_t) * reload_mult
	_reload_len = _reload_t
	_rl_out = false
	_rl_in = false



## How far a shot may wander right now: wide from the hip and wider as shots pile up, tight down the sights.
func shot_spread() -> float:
	var s := spec()
	var spread := float(s.spread)
	# From the hip a gun wanders; down the sights it holds true
	var hip := 1.3 if s.mode == "pump" else (2.6 if s.mode == "bolt" else 1.9)
	spread = maxf(spread, 0.006) * lerpf(hip, float(ArmsDB.SIGHTS.get(mount(), ArmsDB.SIGHTS[""]).spread), _aim)
	if mount() == "red_dot":
		spread *= 0.85
	if fitted("foregrip"):
		spread *= 0.85
	if player.cur_speed > 3.0:
		spread *= 1.4
	if s.mode in ["auto", "spin"]:
		spread *= 1.0 + _climb * 0.6
	spread *= 1.0 + _bloom * (1.0 - 0.8 * _aim)
	return spread


## A gun's sideways kick, shot by shot: the same every time for that gun.
static func kick_pattern(g: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(g + "kick")
	var lean := rng.randf_range(-0.6, 0.6)
	var out: Array = []
	for i in 12:
		out.append(clampf(lean + sin(i * 0.9 + rng.randf() * 0.5) * 0.7 + rng.randf_range(-0.25, 0.25), -1.0, 1.0))
	return out

# ------------------------------------------------------------------ each frame

func _process(delta: float) -> void:
	visible = enabled and not (player.input_locked and player.get_parent().completed)
	_cool = maxf(0.0, _cool - delta)
	_melee_cool = maxf(0.0, _melee_cool - delta)
	_switch = maxf(0.0, _switch - delta)
	_kick = move_toward(_kick, 0.0, delta * 4.0)
	_climb = move_toward(_climb, 0.0, delta * 1.5)
	_bloom = move_toward(_bloom, 0.0, delta * (2.2 + 2.0 * _aim))
	spread_now = shot_spread() if enabled and not blade_out and spec().mode != "rocket" else 0.0
	if Game.main and Game.main.hud:
		var glass := _aim > 0.85 and float(ArmsDB.SIGHTS.get(mount(), ArmsDB.SIGHTS[""]).zoom) >= 2.4
		Game.main.hud.set_spread(0.0 if glass else spread_now)
	if _quiet > 0.32:
		_string = 0
	if _quiet > 0.1 and _pull > 0.0:
		var back := minf(_pull, delta * maxf(0.4, _pull * 5.0))
		player.pitch -= back * 0.6
		_pull -= back
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
	var aiming := not blade_out and (debug_aim or Input.is_action_pressed("aim") and not player.input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _reloading and _swing <= 0.0)
	_set_aim(1.0 if aiming else 0.0, delta)
	# Aiming brings the sights onto the eye's own line
	var aim_off := Vector3.ZERO
	var ease_aim := smoothstep(0.0, 1.0, _aim)
	position = Vector3(0.16, -0.19, -0.5).lerp(Vector3(0, -float(_model.get_meta("eye", 0.07)), -0.6), ease_aim)
	rotation = Vector3(0.02, 0.05, 0) * (1.0 - ease_aim)
	_holder.position = Vector3(_sway.x, bob - _kick * 0.04 + _sway.y - _switch * 0.5, _kick * 0.12 * (1.0 - _aim * 0.6)) + aim_off
	_holder.rotation.x = _kick * 0.35 * (1.0 - _aim * 0.7) - _switch * 1.4
	if _swing > 0.0:
		_swing = maxf(0.0, _swing - delta)
		var len := 0.5 if _heavy else 0.35
		var k := 1.0 - _swing / len
		_melee_holder.visible = true
		if _heavy:
			# Over the shoulder and down
			_melee_holder.position = Vector3(-0.05, 0.05, 0.1)
			_melee_holder.rotation = Vector3(0.9 - k * 2.6, 0.15, 0.1 - k * 0.3)
		else:
			_melee_holder.position = Vector3(-0.05, 0.0, 0.1)
			_melee_holder.rotation = Vector3(-1.4 + k * 2.4, 0.5 - k * 1.2, 0.3)
		_holder.position.y -= 0.25
	elif blade_out:
		_melee_holder.visible = true
		var wind := clampf(_charge / HEAVY_HOLD, 0.0, 1.0) if _charge >= 0.0 else 0.0
		var g := 1.0 if guarding else 0.0
		var rest := Vector3(0.12, -0.16 + bob * 2.0 - _switch * 0.8, 0.02)
		var guard_at := Vector3(-0.02, -0.02, -0.02)
		_melee_holder.position = rest.lerp(guard_at, g) + Vector3(0.04, 0.12, 0.14) * wind + Vector3(_sway.x, _sway.y, 0)
		_melee_holder.rotation = Vector3(-0.55 + wind * 1.0, 0.45, -0.3).lerp(Vector3(0.1, 0.15, 1.35), g)
	else:
		_melee_holder.visible = false
	# Minigun: it must spin before it speaks, and it weighs on the one who carries it
	if hold_fire and not Input.is_action_pressed("fire"):
		hold_fire = false
	var holding := not hold_fire and Input.is_action_pressed("fire") and not player.input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused
	if blade_out:
		_blade_tick(delta, holding)
		_trickle_back(delta)
		return
	if s.mode == "spin":
		_spin = move_toward(_spin, 1.0 if holding and shells > 0 and not _reloading else 0.0, delta / float(s.spin))
		if _pump:
			_pump.rotation.z += delta * 40.0 * _spin
		player.carry_slow = float(s.get("slow", 1.0))
	else:
		player.carry_slow = 1.0
	if _reloading:
		_reload_pose(1.0 - _reload_t / maxf(_reload_len, 0.01), delta)
		_reload_t -= delta
		if _reload_t <= 0.0:
			_reload_step()
	else:
		_reload_rest(delta)
	if holding and _switch <= 0.0 and _swing <= 0.0 and (s.mode != "semi" or Input.is_action_just_pressed("fire")):
		_try_fire()
	_trickle_back(delta)


## The hands at work on a reload, k from 0 to 1: the gun tips toward you, the old magazine drops,
## a fresh one goes up and home with a slap, and the action is worked. A shotgun is fed shell by shell;
## a launcher takes a new rocket in at the front.
func _reload_pose(k: float, delta: float) -> void:
	var s := spec()
	var lvl = player.get_parent()
	var tilt := smoothstep(0.0, 0.18, k) * (1.0 - smoothstep(0.86, 1.0, k))
	var mag: Node3D = _model.get_meta("mag") if _model and _model.has_meta("mag") else null
	if s.reload == "shell":
		# Rolled over to show the loading port, brought up before the eye
		_holder.rotation.z = lerpf(_holder.rotation.z, 0.9, delta * 10.0)
		_holder.rotation.x += 0.25
		_holder.position += Vector3(-0.08, 0.1, 0.06) + Vector3(0, sin(k * PI) * 0.01, 0)
		if _shell_mesh == null:
			_shell_mesh = MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.009
			c.bottom_radius = 0.009
			c.height = 0.06
			_shell_mesh.mesh = c
			_shell_mesh.material_override = _mat(Color(0.7, 0.2, 0.15), 0.2, 0.5)
			_shell_mesh.rotation.x = PI / 2
		if _shell_mesh.get_parent() != _model:
			if _shell_mesh.get_parent():
				_shell_mesh.get_parent().remove_child(_shell_mesh)
			_model.add_child(_shell_mesh)
		_shell_mesh.visible = k < 0.85
		_shell_mesh.position = Vector3(0, -0.11, 0.06).lerp(Vector3(0, -0.035, -0.04), smoothstep(0.1, 0.8, k))
		return
	# Brought up and rolled over, so the eye sees the magazine well
	_holder.rotation.z = 0.75 * tilt
	_holder.rotation.x += 0.32 * tilt
	_holder.position += Vector3(-0.09, 0.11, 0.06) * tilt
	if s.mode == "rocket" and _pump:
		# The spent tube's head goes, and a new rocket slides in at the front
		var out_k := smoothstep(0.12, 0.4, k)
		var in_k := smoothstep(0.5, 0.82, k)
		_pump.visible = k < 0.4 or k > 0.5
		_pump.position.z = -0.45 * (out_k if k < 0.45 else 1.0 - in_k)
	elif mag:
		var drop := Vector3(0, -0.32, 0.06)
		if k < 0.5:
			var d := smoothstep(0.12, 0.38, k)
			mag.position = drop * d
			mag.visible = d < 0.98
		else:
			var r := 1.0 - smoothstep(0.5, 0.78, k)
			mag.position = drop * r
			mag.visible = true
	if not _rl_out and k >= 0.14:
		_rl_out = true
		lvl.sfx("mag_out", -8, null, randf_range(0.95, 1.08))
		if s.mode != "rocket":
			lvl.sfx("mag_grab", -14)
	if not _rl_in and k >= 0.78:
		_rl_in = true
		lvl.sfx("mag_in", -6, null, randf_range(0.95, 1.05))
		_kick = maxf(_kick, 0.25)
	# Working the action home after the fresh one is in
	if _pump and s.mode in ["auto", "semi", "bolt"] and k > 0.84:
		_pump.position.z = sin(clampf((k - 0.84) / 0.16, 0.0, 1.0) * PI) * (0.06 if s.mode == "bolt" else 0.04)


## Back to rest once a reload is over or broken off: the magazine in its place, the gun upright.
func _reload_rest(delta: float) -> void:
	_holder.rotation.z = lerpf(_holder.rotation.z, 0.0, delta * 8.0)
	if _shell_mesh:
		_shell_mesh.visible = false
	var mag: Node3D = _model.get_meta("mag") if _model and _model.has_meta("mag") else null
	if mag and mag.position != Vector3.ZERO:
		mag.position = Vector3.ZERO
		mag.visible = true
	if _pump and spec().mode == "rocket" and (_pump.position.z != 0.0 or not _pump.visible):
		_pump.position.z = 0.0
		_pump.visible = true


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
		_reload_len = _reload_t
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
	if _quiet < 4.0 or pack:
		return
	for g in guns:
		var m: int = Arms.mag_of(g)
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
	_aim = move_toward(_aim, target, delta * 6.0 * (float(spec().aim) if enabled else 1.0))
	var zoom := float(ArmsDB.SIGHTS.get(mount(), ArmsDB.SIGHTS[""]).zoom) if enabled else 1.0
	if enabled and built_glass(gun(), Game.mounts_of(gun())):
		zoom = maxf(zoom, float(spec().zoom))
	var f: float = Game.fov / lerpf(1.0, zoom, _aim)
	if absf(player.cam.fov - f) > 0.01:
		player.cam.fov = f
	var scoped := enabled and _aim > 0.85 and zoom >= 2.4
	scoped_now = scoped
	_scope_drift(delta, scoped)
	_holder.visible = not scoped and not blade_out


func _ui() -> void:
	if not enabled:
		return
	var hud = Game.main.hud
	var line := "%s" % spec().name
	if blade_out:
		hud.set_ammo(-1, 0)
		line = "%s   hold to swing hard, aim to guard" % ArmsDB.MELEE[melee].name
	else:
		hud.set_ammo(shells, capacity(), reserve if not Net.unlimited_ammo() else -2)
		for m in Game.mounts_of(gun()):
			line += " · " + ArmsDB.ATTACHMENTS[m].name
	line += "     %s %d     %s %d" % [ArmsDB.GRENADES[grenade].name.split(" ")[0], grenades, ArmsDB.GADGETS[gadget].name, charges]
	var ready = player.get_parent().get("streaks_ready")
	if ready is Array and not ready.is_empty():
		line += "     [H] " + Streaks.KINDS[ready[0]].name + (" +%d" % (ready.size() - 1) if ready.size() > 1 else "")
	hud.set_kit(line)
	hud.hotbar.arms = self
	hud.hotbar.queue_redraw()


## How much a turn of the mouse moves the view now: slower as the view narrows, so the crosshair
## moves across the world at the same pace on screen, times the player's own aiming setting.
func look_scale() -> float:
	if _aim <= 0.0 or not enabled or blade_out:
		return 1.0
	var zoomed := player.cam.fov / maxf(1.0, Game.fov)
	return lerpf(1.0, zoomed * Game.aim_sens, _aim)


var scoped_now := false   ## looking through a scope (Hasten then holds the breath instead)
var _breath := 1.0     ## held breath behind a scope: steadies the drift, then runs out
var _gasp := 0.0       ## out of breath: the drift grows until it is drawn back
var _drift_t := 0.0
var _drift := Vector2.ZERO


## Behind a scope the aim drifts with the breath. Hold Hasten to stop breathing and steady it.
func _scope_drift(delta: float, scoped: bool) -> void:
	var holding := scoped and Input.is_action_pressed("run") and _gasp <= 0.0 and _breath > 0.0
	if holding:
		_breath = maxf(0.0, _breath - delta / 4.0)
		if _breath <= 0.0:
			_gasp = 2.0
	else:
		_breath = minf(1.0, _breath + delta / 3.0)
		_gasp = maxf(0.0, _gasp - delta)
	var amp := 0.0
	if scoped:
		amp = 0.0 if holding else (0.0016 if _gasp <= 0.0 else 0.005)
		amp *= 1.0 if player.velocity.length() < 1.0 else 2.2
	_drift_t += delta
	var want := Vector2(sin(_drift_t * 1.1) * 1.0, sin(_drift_t * 2.2) * 0.6) * amp
	var step := want - _drift
	_drift = want
	player.yaw += step.x
	player.pitch += step.y
	Game.main.hud.set_scope(scoped, _breath)


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
	var steady := 0.65 if fitted("foregrip") else 1.0
	_kick = minf(1.0, _kick + float(s.kick) * (0.35 if s.mode in ["auto", "spin"] else 1.0))
	player.shake(0.18 * float(s.kick) * (1.0 - 0.5 * _aim) * steady)
	var climb := 0.045 * float(s.kick) * (1.0 - 0.5 * _aim) * steady
	if s.mode in ["auto", "spin"]:
		_climb += 0.1
		climb = (0.008 + 0.006 * _climb) * steady
	var was := player.pitch
	player.pitch = minf(player.pitch + climb, 1.45)
	_pull = minf(_pull + player.pitch - was, 0.4)
	# Each gun pulls sideways in its own fixed way, so the pull can be learned and held against
	var pat := kick_pattern(gun())
	player.yaw += float(pat[_string % pat.size()]) * float(s.kick) * 0.011 * (1.0 - 0.45 * _aim) * steady
	_string += 1
	_bloom = minf(1.6, _bloom + float(s.kick) * (0.12 if s.mode in ["auto", "spin"] else 0.45))
	var lvl = player.get_parent()
	var quiet := fitted("suppressor")
	lvl.sfx("supp" if quiet else str(s.sound), -10 if quiet else -2)
	# Foes about hear it: a suppressed shot carries a short way, a bare one far across the waste
	if lvl.has_method("noise"):
		lvl.noise(player.global_position, 20.0 if quiet else (140.0 if gun() in ["sniper", "revolver"] else 110.0))
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
		r.dmg = float(s.dmg) * damage_mult * tier_mult()
		r.radius = float(s.radius)
		r.vel = fwd * float(s.speed)
		lvl.add_child(r)
		r.global_position = origin + fwd * 0.9 + cam.global_transform.basis.x * 0.15 - cam.global_transform.basis.y * 0.1
		return
	var space := get_world_3d().direct_space_state
	var spread := 0.0
	spread = shot_spread()
	var hits := {}
	var crits := {}
	var dmg_m := damage_mult * tier_mult() * (1.3 if Game.blessed("speebsnek") else 1.0) * (0.92 if quiet else 1.0)
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
		if target and target.has_method("weak_point"):
			# A shot to the head does more, and is marked so
			var wp: Array = target.weak_point()
			if not wp.is_empty() and _ray_near(origin, dir, wp[0], wp[1]):
				dmg *= HEAD_MULT * float(s.crit)
				crits[target] = true
		if target and target.has_method("hurt"):
			hits[target] = hits.get(target, 0.0) + dmg
		else:
			lvl.puff(r.position, r.normal)
	if not hits.is_empty():
		lvl.hits += 1
	LesserSpeeb.harm_pierce = float(s.get("pierce", 1.0))
	Arms.deal(hits, fwd, "shot" if int(s.pellets) > 1 else "bullet", crits)
	LesserSpeeb.harm_pierce = 1.0
	_impact_sounds(hits)
	_practise(gun(), hits)


## Applies harm to each struck thing and shows the hit marker once.
static var _told_deflect := -100000


const HEAD_MULT := 1.6


## Whether a ray passes within r of a point (the head's middle).
static func _ray_near(o: Vector3, d: Vector3, c: Vector3, r: float) -> bool:
	var t := maxf(0.0, (c - o).dot(d))
	return (o + d * t).distance_to(c) < r


static func deal(hits: Dictionary, dir: Vector3, harm := "", crits := {}) -> void:
	LesserSpeeb.harm_kind = harm
	var marked := 0
	var crit := false
	for t in hits:
		if is_instance_valid(t) and t.has_method("hurt"):
			LesserSpeeb.harm_head = crits.has(t)
			var full: bool = t.hurt(hits[t], dir)
			LesserSpeeb.harm_head = false
			LesserSpeeb.harm_kind = harm
			if full and crits.has(t):
				crit = true
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
	LesserSpeeb.harm_kind = ""
	if marked > 0:
		Game.main.hud.hitmarker(marked == 2, false, crit)
		if Game.main.level:
			Game.main.level.sfx("tick", -6 if marked == 1 else -2, null, 1.0 if marked == 1 else 0.7)
			if crit:
				Game.main.level.sfx("tick", -3, null, 1.45)
	elif marked < 0:
		# Struck, but turned aside: a grey ring and a hard high note, so it is plain the shot did little
		Game.main.hud.hitmarker(false, true)
		if Game.main.level:
			Game.main.level.sfx("tick", -4, null, 1.9)


## Harms everything near a point, less at the edge. The thrower is hurt too if they stand in it.
static func blast(lvl: Node, at: Vector3, radius: float, dmg: float, thrower: Node = null, harm := "blast") -> void:
	if lvl.has_method("noise"):
		lvl.noise(at, 130.0)
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
	deal(hits, Vector3.UP, harm)
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

const HEAVY_HOLD := 0.4       ## hold fire this long with the blade out, and the swing is a heavy one
const LIGHT_COST := 8.0
const HEAVY_COST := 24.0


## The blade in hand: a short press swings, a long hold winds up and swings hard on release.
## Aim raises the blade to guard: blows are turned aside for stamina.
func _blade_tick(delta: float, holding: bool) -> void:
	guarding = Input.is_action_pressed("aim") and not player.input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _swing <= 0.0 and not player.get("winded")
	if guarding:
		_charge = -1.0
		return
	if holding and _switch <= 0.0:
		if _charge < 0.0:
			_charge = 0.0
		else:
			_charge += delta
		if _charge >= HEAVY_HOLD and _charge - delta < HEAVY_HOLD:
			player.get_parent().sfx("tick", -14, null, 0.6)
	elif _charge >= 0.0:
		strike(_charge >= HEAVY_HOLD)
		_charge = -1.0


func strike(heavy := false) -> void:
	if _melee_cool > 0.0 or _swing > 0.0:
		return
	if not player.spend(HEAVY_COST if heavy else LIGHT_COST):
		return
	var m: Dictionary = ArmsDB.MELEE[melee].duplicate()
	_heavy = heavy
	if heavy:
		m.dmg = float(m.dmg) * 2.2
		m.reach = float(m.reach) + 0.4
	_melee_cool = float(m.rate) * (1.5 if heavy else 1.0)
	_swing = 0.5 if heavy else 0.35
	_reloading = false
	_show_melee()
	var lvl = player.get_parent()
	lvl.sfx("swing", -4 if heavy else -6, null, randf_range(0.9, 1.1) * (0.8 if melee == "sledge" else 1.0) * (0.8 if heavy else 1.0))
	get_tree().create_timer(0.24 if heavy else 0.12, false).timeout.connect(func(): _melee_hit(m, heavy))


func _melee_hit(m: Dictionary, heavy := false) -> void:
	if not is_instance_valid(player):
		return
	var lvl = player.get_parent()
	var cam := player.cam
	var origin := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var hits := {}
	var sk = _skills()
	if sk:
		m = m.duplicate()
		m.dmg = float(m.dmg) * float(sk.use_bonus("blade").dmg)
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
		lvl.sfx("chop", -1 if heavy else -4, null, randf_range(0.85, 1.1) * (0.8 if heavy else 1.0))
		player.shake(0.3 if heavy else 0.15)
		Arms.deal(hits, fwd, "blade")
		_practise("blade", hits)
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


## A node for the magazine, so a reload can pull it out and put a fresh one in.
func _mag_node(n: Node3D) -> Node3D:
	var m := Node3D.new()
	n.add_child(m)
	n.set_meta("mag", m)
	return m


## The sniper's own long glass. In the trials it always has it; in the waste it is a part to make and fit.
static func built_glass(g: String, fit: Array) -> bool:
	return g == "sniper" and (not Game.wasteland or "scope" in fit)


## Builds a gun from plain shapes: barrel along -Z, the hand at the origin, the stock behind.
## mnts: what is fitted to it; null means whatever this pilgrim has chosen for the gun.
func _build(g: String, mnts = null) -> Node3D:
	var n := Node3D.new()
	var fit: Array = Game.mounts_of(g) if mnts == null else mnts
	var ext: bool = "ext_mag" in fit
	var metal := _metal()
	var dark := _mat(Color(0.07, 0.07, 0.075), 0.5, 0.5)
	var wood := _mat(Color(0.34, 0.2, 0.11), 0.0, 0.55)
	var wood2 := _mat(Color(0.25, 0.14, 0.08), 0.0, 0.6)
	var brass := _mat(Color(0.7, 0.55, 0.3), 0.9, 0.3)
	var olive := _mat(Color(0.2, 0.22, 0.16), 0.2, 0.7)
	var pump := Node3D.new()
	n.add_child(pump)
	n.set_meta("pump", pump)
	var top := 0.05                       # where a sight sits
	var tip := Vector3(0, 0.03, -0.8)     # the muzzle
	var rear_z := 0.08                    # where the rear sight sits
	var front := Vector3(0, 0.03, -0.7)   # the top of the barrel, near the muzzle
	var fore := Vector3(0, -0.04, -0.3)   # under the fore-end, where a grip hangs
	match g:
		"shotgun":
			_box(Vector3(0.05, 0.076, 0.27), Vector3(0, 0, 0.03), metal, n)
			_box(Vector3(0.052, 0.02, 0.2), Vector3(0, -0.03, 0.02), dark, n)
			_box(Vector3(0.004, 0.024, 0.075), Vector3(0.026, 0.012, 0.0), brass, n)
			_tube(0.0145, 0.64, Vector3(0, 0.02, -0.42), metal, n)
			_tube(0.0165, 0.012, Vector3(0, 0.02, -0.735), dark, n)
			var tube_len := 0.6 if ext else 0.47
			_tube(0.0125, tube_len, Vector3(0, -0.014, -0.105 - tube_len * 0.5), metal, n)
			_tube(0.015, 0.02, Vector3(0, -0.014, -0.105 - tube_len), dark, n)
			_box(Vector3(0.012, 0.05, 0.014), Vector3(0, 0.003, -0.52), dark, n)
			# The stock: wrist, comb and butt
			_box(Vector3(0.036, 0.05, 0.13), Vector3(0, -0.035, 0.215), wood, n, Vector3(-0.4, 0, 0))
			_box(Vector3(0.04, 0.085, 0.22), Vector3(0, -0.062, 0.385), wood, n, Vector3(-0.1, 0, 0))
			_box(Vector3(0.042, 0.1, 0.016), Vector3(0, -0.073, 0.5), dark, n, Vector3(-0.1, 0, 0))
			# Trigger and its guard
			_box(Vector3(0.008, 0.006, 0.075), Vector3(0, -0.07, 0.085), dark, n)
			_box(Vector3(0.008, 0.03, 0.006), Vector3(0, -0.055, 0.047), dark, n)
			_box(Vector3(0.005, 0.022, 0.005), Vector3(0, -0.052, 0.09), brass, n, Vector3(0.3, 0, 0))
			# The slide under the barrel, ribbed
			_box(Vector3(0.046, 0.048, 0.18), Vector3(0, -0.016, -0.3), wood, pump)
			for i in 5:
				_box(Vector3(0.049, 0.05, 0.008), Vector3(0, -0.016, -0.36 + i * 0.03), wood2, pump)
			_box(Vector3(0.006, 0.008, 0.2), Vector3(0.021, -0.005, -0.14), dark, pump)
			tip = Vector3(0, 0.02, -0.75)
			top = 0.038
			rear_z = 0.1
			front = Vector3(0, 0.0345, -0.7)
			fore = Vector3(0, -0.04, -0.3)
		"machine_gun":
			_box(Vector3(0.048, 0.06, 0.36), Vector3(0, 0.012, 0.0), metal, n)
			_box(Vector3(0.044, 0.04, 0.2), Vector3(0, -0.036, 0.04), dark, n)
			_box(Vector3(0.02, 0.008, 0.34), Vector3(0, 0.046, -0.01), dark, n)
			_box(Vector3(0.004, 0.02, 0.06), Vector3(0.025, 0.018, -0.02), brass, n)
			# Hand guard with its vents
			_box(Vector3(0.052, 0.058, 0.25), Vector3(0, 0.008, -0.3), olive, n)
			for i in 4:
				_box(Vector3(0.054, 0.012, 0.03), Vector3(0, 0.014, -0.39 + i * 0.055), dark, n)
			_tube(0.011, 0.26, Vector3(0, 0.012, -0.54), dark, n)
			_box(Vector3(0.02, 0.036, 0.022), Vector3(0, 0.024, -0.5), dark, n)
			_tube(0.016, 0.055, Vector3(0, 0.012, -0.665), metal, n)
			# Magazine, curved; longer when extended
			var magn := _mag_node(n)
			_box(Vector3(0.03, 0.1, 0.062), Vector3(0, -0.095, -0.055), dark, magn, Vector3(0.12, 0, 0))
			_box(Vector3(0.03, 0.09 if not ext else 0.16, 0.06), Vector3(0, -0.175 if not ext else -0.2, -0.078 if not ext else -0.09), dark, magn, Vector3(0.34, 0, 0))
			# Grip, trigger, stock
			_box(Vector3(0.034, 0.1, 0.044), Vector3(0, -0.09, 0.125), olive, n, Vector3(-0.3, 0, 0))
			_box(Vector3(0.008, 0.006, 0.07), Vector3(0, -0.066, 0.06), dark, n)
			_box(Vector3(0.005, 0.02, 0.005), Vector3(0, -0.055, 0.075), dark, n, Vector3(0.3, 0, 0))
			_tube(0.014, 0.16, Vector3(0, 0.012, 0.25), dark, n)
			_box(Vector3(0.042, 0.1, 0.13), Vector3(0, -0.012, 0.36), olive, n)
			_box(Vector3(0.044, 0.11, 0.014), Vector3(0, -0.014, 0.432), dark, n)
			_box(Vector3(0.012, 0.014, 0.04), Vector3(0.03, 0.03, 0.06), dark, pump)
			tip = Vector3(0, 0.012, -0.695)
			top = 0.05
			rear_z = 0.12
			front = Vector3(0, 0.042, -0.5)
			fore = Vector3(0, -0.022, -0.3)
		"sniper":
			_box(Vector3(0.044, 0.056, 0.3), Vector3(0, 0.006, 0.02), metal, n)
			_tube(0.0135, 0.8, Vector3(0, 0.014, -0.53), dark, n, 0.0095)
			_tube(0.014, 0.05, Vector3(0, 0.014, -0.95), metal, n)
			# One long stock of wood: fore-end, wrist, butt and cheek rest
			_box(Vector3(0.05, 0.044, 0.46), Vector3(0, -0.028, -0.17), wood, n)
			_box(Vector3(0.046, 0.03, 0.1), Vector3(0, -0.02, -0.43), wood2, n)
			_box(Vector3(0.036, 0.05, 0.13), Vector3(0, -0.04, 0.2), wood, n, Vector3(-0.42, 0, 0))
			_box(Vector3(0.042, 0.1, 0.24), Vector3(0, -0.06, 0.37), wood, n, Vector3(-0.08, 0, 0))
			_box(Vector3(0.036, 0.03, 0.14), Vector3(0, 0.0, 0.35), wood2, n)
			_box(Vector3(0.044, 0.115, 0.016), Vector3(0, -0.068, 0.495), dark, n)
			_box(Vector3(0.03, 0.05 if not ext else 0.1, 0.07), Vector3(0, -0.07 if not ext else -0.095, -0.02), dark, _mag_node(n))
			_box(Vector3(0.008, 0.006, 0.07), Vector3(0, -0.07, 0.085), dark, n)
			top = 0.034
			rear_z = 0.1
			front = Vector3(0, 0.026, -0.9)
			# The glass it was made to carry: always in the trials; in the waste, only once a scope is fitted
			if built_glass(g, fit):
				_tube(0.02, 0.26, Vector3(0, 0.082, 0.0), dark, n)
				_tube(0.028, 0.07, Vector3(0, 0.082, -0.16), dark, n, 0.021)
				_box(Vector3(0.014, 0.03, 0.016), Vector3(0, 0.055, -0.07), metal, n)
				_box(Vector3(0.014, 0.03, 0.016), Vector3(0, 0.055, 0.07), metal, n)
			_tube(0.021, 0.05, Vector3(0, 0.082, 0.15), dark, n, 0.025)
			_box(Vector3(0.016, 0.04, 0.02), Vector3(0, 0.05, -0.07), metal, n)
			_box(Vector3(0.016, 0.04, 0.02), Vector3(0, 0.05, 0.08), metal, n)
			_box(Vector3(0.016, 0.02, 0.016), Vector3(0, 0.108, 0.01), metal, n)
			# The bolt
			_box(Vector3(0.05, 0.01, 0.01), Vector3(0.045, 0.012, 0.13), metal, pump)
			_box(Vector3(0.018, 0.018, 0.018), Vector3(0.072, 0.008, 0.13), dark, pump)
			tip = Vector3(0, 0.014, -0.975)
			top = 0.108
			front = Vector3(0, 0.024, -0.9)
			fore = Vector3(0, -0.05, -0.28)
		"rocket":
			_tube(0.058, 0.95, Vector3(0, 0.0, -0.1), olive, n)
			_tube(0.068, 0.07, Vector3(0, 0.0, -0.56), dark, n)
			_tube(0.062, 0.03, Vector3(0, 0.0, -0.3), dark, n)
			_tube(0.062, 0.03, Vector3(0, 0.0, 0.12), dark, n)
			_tube(0.062, 0.16, Vector3(0, 0.0, 0.44), dark, n, 0.085)
			_box(Vector3(0.036, 0.11, 0.05), Vector3(0, -0.105, 0.0), dark, n, Vector3(0.2, 0, 0))
			_box(Vector3(0.036, 0.1, 0.045), Vector3(0, -0.1, -0.22), dark, n)
			_box(Vector3(0.008, 0.006, 0.08), Vector3(0, -0.075, -0.045), dark, n)
			_box(Vector3(0.07, 0.03, 0.12), Vector3(0, -0.065, 0.24), _mat(Color(0.25, 0.2, 0.15), 0.0, 0.9), n)
			var head := _tube(0.045, 0.14, Vector3(0, 0, -0.6), _mat(Color(0.35, 0.33, 0.28), 0.4, 0.5), pump, 0.02)
			head.rotation.x = -PI / 2
			_tube(0.046, 0.03, Vector3(0, 0, -0.535), brass, pump)
			tip = Vector3(0, 0.0, -0.66)
			top = 0.06
			rear_z = 0.05
			front = Vector3(0, 0.068, -0.5)
			fore = Vector3(0, -0.06, -0.38)
		"minigun":
			_box(Vector3(0.13, 0.13, 0.26), Vector3(0, -0.02, 0.12), dark, n)
			_box(Vector3(0.1, 0.1, 0.06), Vector3(0, -0.02, -0.03), metal, n)
			_box(Vector3(0.09, 0.14, 0.16), Vector3(-0.11, -0.07, 0.1), olive, _mag_node(n))
			_box(Vector3(0.03, 0.02, 0.1), Vector3(-0.07, 0.02, 0.02), brass, n, Vector3(0, 0, 0.5))
			# Carried by a handle above and a grip behind
			_box(Vector3(0.02, 0.05, 0.02), Vector3(0, 0.07, 0.03), metal, n)
			_box(Vector3(0.02, 0.05, 0.02), Vector3(0, 0.07, 0.2), metal, n)
			_box(Vector3(0.024, 0.02, 0.2), Vector3(0, 0.1, 0.115), dark, n)
			_box(Vector3(0.036, 0.1, 0.045), Vector3(0, -0.1, 0.28), dark, n, Vector3(-0.3, 0, 0))
			for i in 6:
				var a := i * TAU / 6.0
				_tube(0.012, 0.62, Vector3(cos(a) * 0.035, sin(a) * 0.035, -0.34), metal, pump)
			_tube(0.052, 0.03, Vector3(0, 0, -0.2), dark, pump)
			_tube(0.052, 0.03, Vector3(0, 0, -0.42), dark, pump)
			_tube(0.052, 0.03, Vector3(0, 0, -0.62), dark, pump)
			pump.position = Vector3(0, -0.02, 0)
			tip = Vector3(0, -0.02, -0.68)
			top = 0.11
			rear_z = 0.2
			front = Vector3(0, 0.11, 0.03)
		"pistol":
			_box(Vector3(0.028, 0.026, 0.17), Vector3(0, 0.01, -0.065), metal, n)
			_box(Vector3(0.03, 0.105, 0.046), Vector3(0, -0.05, 0.005), dark, n, Vector3(-0.2, 0, 0))
			_box(Vector3(0.033, 0.07, 0.03), Vector3(0, -0.05, 0.007), wood2, n, Vector3(-0.2, 0, 0))
			# The magazine sits up in the grip; only its base shows, or all of it while it is changed
			var pm := _mag_node(n)
			_box(Vector3(0.024, 0.09, 0.032), Vector3(0, -0.06, 0.006), metal, pm, Vector3(-0.2, 0, 0))
			if ext:
				_box(Vector3(0.024, 0.06, 0.036), Vector3(0, -0.125, 0.022), metal, pm, Vector3(-0.2, 0, 0))
			_box(Vector3(0.007, 0.005, 0.06), Vector3(0, -0.035, -0.05), dark, n)
			_box(Vector3(0.007, 0.03, 0.005), Vector3(0, -0.02, -0.08), dark, n)
			_box(Vector3(0.004, 0.018, 0.004), Vector3(0, -0.018, -0.04), brass, n, Vector3(0.3, 0, 0))
			# The slide, with its grooves and port
			_box(Vector3(0.031, 0.032, 0.2), Vector3(0, 0.038, -0.07), dark, pump)
			for i in 4:
				_box(Vector3(0.033, 0.024, 0.005), Vector3(0, 0.038, 0.0 + i * 0.009), metal, pump)
			_box(Vector3(0.004, 0.012, 0.04), Vector3(0.016, 0.044, -0.07), brass, pump)
			_tube(0.008, 0.02, Vector3(0, 0.036, -0.175), metal, n)
			_box(Vector3(0.008, 0.016, 0.012), Vector3(0, 0.035, 0.036), metal, n, Vector3(-0.5, 0, 0))
			tip = Vector3(0, 0.036, -0.185)
			top = 0.054
			rear_z = 0.02
			front = Vector3(0, 0.054, -0.16)
		"revolver":
			_tube(0.0115, 0.2, Vector3(0, 0.032, -0.16), metal, n)
			_box(Vector3(0.012, 0.014, 0.17), Vector3(0, 0.012, -0.145), metal, n)
			_box(Vector3(0.03, 0.062, 0.1), Vector3(0, 0.014, -0.01), metal, n)
			_tube(0.027, 0.058, Vector3(0, 0.02, -0.02), dark, n)
			for i in 6:
				var a := i * TAU / 6.0 + 0.5
				_tube(0.006, 0.06, Vector3(cos(a) * 0.024, 0.02 + sin(a) * 0.024, -0.02), metal, n)
			_box(Vector3(0.032, 0.07, 0.04), Vector3(0, -0.045, 0.04), wood, n, Vector3(-0.35, 0, 0))
			_box(Vector3(0.032, 0.05, 0.045), Vector3(0, -0.09, 0.062), wood, n, Vector3(-0.1, 0, 0))
			_box(Vector3(0.007, 0.005, 0.05), Vector3(0, -0.045, -0.02), metal, n)
			_box(Vector3(0.007, 0.028, 0.005), Vector3(0, -0.032, -0.045), metal, n)
			_box(Vector3(0.008, 0.022, 0.014), Vector3(0, 0.052, 0.04), dark, n, Vector3(-0.6, 0, 0))
			tip = Vector3(0, 0.032, -0.265)
			top = 0.046
			rear_z = 0.03
			front = Vector3(0, 0.0435, -0.24)
	_frame_parts(g, fit, n, tip)
	tip = n.get_meta("tip_after", tip)
	var eye := top + 0.012
	var sight := ""
	for m in fit:
		if ArmsDB.ATTACHMENTS.has(m) and ArmsDB.ATTACHMENTS[m].slot == "sight":
			sight = m
	match sight:
		"red_dot":
			_box(Vector3(0.026, 0.008, 0.06), Vector3(0, top + 0.004, rear_z - 0.08), dark, n)
			for sx in [-1, 1]:
				_box(Vector3(0.004, 0.034, 0.012), Vector3(0.016 * sx, top + 0.024, rear_z - 0.1), dark, n)
			_box(Vector3(0.036, 0.004, 0.012), Vector3(0, top + 0.042, rear_z - 0.1), dark, n)
			var glass := _mat(Color(0.5, 0.75, 0.8, 0.12))
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_box(Vector3(0.028, 0.03, 0.002), Vector3(0, top + 0.024, rear_z - 0.1), glass, n)
			var dot := _mat(Color(1, 0.15, 0.1))
			dot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_box(Vector3(0.003, 0.003, 0.001), Vector3(0, top + 0.024, rear_z - 0.099), dot, n)
			eye = top + 0.024
		"scope":
			if g != "sniper" or not built_glass(g, fit):
				_tube(0.018, 0.2, Vector3(0, top + 0.034, rear_z - 0.1), dark, n)
				_tube(0.025, 0.05, Vector3(0, top + 0.034, rear_z - 0.22), dark, n, 0.019)
				_tube(0.019, 0.04, Vector3(0, top + 0.034, rear_z + 0.015), dark, n, 0.022)
				_box(Vector3(0.014, 0.022, 0.016), Vector3(0, top + 0.01, rear_z - 0.15), metal, n)
				_box(Vector3(0.014, 0.022, 0.016), Vector3(0, top + 0.01, rear_z - 0.04), metal, n)
			eye = 0.082 if built_glass(g, fit) else top + 0.034
		_:
			if built_glass(g, fit):
				eye = 0.082
			else:
				# Iron sights: a notch behind and a post before
				for sx in [-1, 1]:
					_box(Vector3(0.005, 0.012, 0.008), Vector3(0.0075 * sx, top + 0.006, rear_z), dark, n)
				_box(Vector3(0.022, 0.004, 0.01), Vector3(0, top + 0.001, rear_z), dark, n)
				var h := maxf(0.008, eye - front.y)
				_box(Vector3(0.004, h, 0.006), Vector3(0, front.y + h * 0.5, front.z), dark, n)
				_box(Vector3(0.012, 0.003, 0.01), Vector3(0, front.y + 0.001, front.z), dark, n)
	for m in fit:
		match m:
			"suppressor":
				_tube(0.022, 0.19, tip + Vector3(0, 0, -0.085), dark, n)
				_tube(0.0235, 0.012, tip + Vector3(0, 0, -0.02), metal, n)
				tip += Vector3(0, 0, -0.18)
			"foregrip":
				_box(Vector3(0.03, 0.012, 0.05), fore, dark, n)
				_box(Vector3(0.026, 0.085, 0.03), fore + Vector3(0, -0.045, 0.004), dark, n, Vector3(0.12, 0, 0))
	n.set_meta("tip", tip)
	n.set_meta("eye", eye)
	return n


## Where the stock ends and where the side of the action is, per gun, for the waste's own parts.
const BUTT := {"shotgun": Vector3(0, -0.07, 0.5), "machine_gun": Vector3(0, -0.014, 0.432), "sniper": Vector3(0, -0.068, 0.495)}
const SIDE := {"shotgun": Vector3(0.027, 0.0, 0.03), "machine_gun": Vector3(0.026, 0.012, 0.0), "sniper": Vector3(0.024, 0.006, 0.02),
	"rocket": Vector3(0.06, -0.06, 0.2), "minigun": Vector3(0.066, -0.02, 0.12), "pistol": Vector3(0.016, -0.01, -0.0), "revolver": Vector3(0.016, 0.014, -0.01)}


## Barrels, stocks and receivers, each shown on the gun; a graded part carries a band of its grade's colour.
func _frame_parts(g: String, fit: Array, n: Node3D, tip: Vector3) -> void:
	var dark := _mat(Color(0.07, 0.07, 0.075), 0.5, 0.5)
	var metal := _metal()
	var a: Dictionary = Game.arms_now()
	for m in fit:
		if not ArmsDB.ATTACHMENTS.has(m) or not ArmsDB.ATTACHMENTS[m].slot in ["barrel", "stock", "receiver"]:
			continue
		var at := Vector3.ZERO
		match m:
			"long_barrel":
				_tube(0.011, 0.16, tip + Vector3(0, 0, -0.08), metal, n)
				_tube(0.014, 0.02, tip + Vector3(0, 0, -0.16), dark, n)
				tip += Vector3(0, 0, -0.16)
				at = tip + Vector3(0, 0, 0.05)
			"sawn_barrel":
				_tube(0.019, 0.035, tip + Vector3(0, 0, -0.01), dark, n)
				for i in 3:
					_box(Vector3(0.042, 0.004, 0.006), tip + Vector3(0, 0.006, -0.002 - i * 0.01), metal, n)
				tip += Vector3(0, 0, -0.03)
				at = tip + Vector3(0, 0, 0.02)
			"heavy_barrel":
				_tube(0.021, 0.22, tip + Vector3(0, 0, 0.12), dark, n)
				for i in 4:
					_tube(0.023, 0.008, tip + Vector3(0, 0, 0.05 + i * 0.045), metal, n)
				at = tip + Vector3(0, 0, 0.22)
			"padded_stock", "light_stock", "heavy_stock":
				var b: Vector3 = BUTT.get(g, Vector3(0, -0.04, 0.45))
				match m:
					"padded_stock":
						_box(Vector3(0.05, 0.115, 0.03), b + Vector3(0, 0, 0.02), _mat(Color(0.32, 0.16, 0.1), 0.0, 0.9), n)
					"light_stock":
						_box(Vector3(0.008, 0.008, 0.2), b + Vector3(0, 0.03, -0.06), metal, n)
						_box(Vector3(0.008, 0.008, 0.2), b + Vector3(0, -0.04, -0.06), metal, n)
						_box(Vector3(0.03, 0.1, 0.012), b + Vector3(0, -0.005, 0.04), dark, n)
					"heavy_stock":
						_box(Vector3(0.052, 0.13, 0.18), b + Vector3(0, -0.01, -0.06), _mat(Color(0.22, 0.12, 0.07), 0.0, 0.6), n)
				at = b + Vector3(0, 0.04, -0.06)
			"rapid_receiver", "heavy_receiver", "smooth_receiver":
				var sd: Vector3 = SIDE.get(g, Vector3(0.026, 0, 0.03))
				var c: Color = {"rapid_receiver": Color(0.12, 0.16, 0.28), "heavy_receiver": Color(0.7, 0.55, 0.3), "smooth_receiver": Color(0.8, 0.8, 0.82)}[m]
				for sx in [-1, 1]:
					_box(Vector3(0.004, 0.034, 0.11), Vector3(sd.x * sx, sd.y, sd.z), _mat(c, 0.85, 0.3), n)
				at = sd + Vector3(0.003, 0.02, 0)
		var gr := WArms.grade_of(a, g, m) if Game.wasteland else {}
		var r := int(gr.get("r", 0))
		if r > 0:
			var glow := _mat(WArms.GRADES[r].color)
			glow.emission_enabled = true
			glow.emission = WArms.GRADES[r].color
			glow.emission_energy_multiplier = 0.6 + r * 0.3
			_box(Vector3(0.012, 0.006, 0.03), at, glow, n)
	n.set_meta("tip_after", tip)


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
			# A flare's light shows every form that moves near it
			if kind == "flare" and not shown_only and Engine.get_physics_frames() % 20 == 0:
				var lv = get_parent()
				for e in lv.get("enemies") if lv.get("enemies") != null else []:
					if is_instance_valid(e) and e.is_alive() and e.has_method("reveal") and e.global_position.distance_to(global_position) < 22.0:
						e.reveal(1.5)
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
				Arms.deal(hits, Vector3.UP, "fire")
		if is_instance_valid(root):
			fire.emitting = false
			var tw := root.create_tween()
			tw.tween_property(l, "light_energy", 0.0, 1.0)
			tw.tween_callback(root.queue_free)
