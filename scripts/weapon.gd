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
var _shell_mesh: Node3D
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
var guard_age := 99.0   ## how long the guard has been up: raised just as a blow lands, it is a perfect guard
const PERFECT_GUARD := 0.25
var _charge := -1.0          ## seconds the fire button has been held with the blade out; -1 when not held
var _heavy := false          ## the swing under way is a heavy one
var _swing := 0.0
var _switch := 0.0
var _tuck := 0.0   ## 0..1: how far the gun is drawn back from a wall or anything else right ahead
var _aim := 0.0
var _climb := 0.0
var _bloom := 0.0     ## how far shots wander from firing in a string (mostly from the hip)
var _string := 0      ## shots in the current string, for the gun's kick pattern
static var _jet_m: StandardMaterial3D
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
var _dots: Array = []   ## the red-dot reticles on the gun in hand: shown only down the sight
var _flash: OmniLight3D
var _flash_mesh: Node3D   ## the muzzle flash: a burst seen from behind, and flames along the barrel seen from the side
var _flash_sides: Array = []
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
	_flash_mesh = _make_flash()
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
	# In the waste a second long gun may be carried too: long gun, second long gun, side arm
	var g2 := str(lo.get("primary2", ""))
	if Game.wasteland and ArmsDB.GUNS.has(g2) and g2 != guns[0]:
		guns.insert(1, g2)
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
static var heard_matter := {}


func _impact_sounds(hits: Dictionary) -> void:
	var n := 0
	for t in hits:
		if n >= 2 or not is_instance_valid(t):
			break
		n += 1
		# Each thing struck sounds of what it is made of: flesh, iron, glass, bone, a ghost's cold air, a shell
		var mt: String = t.matter() if t.has_method("matter") else "flesh"
		var snd: Array = LesserSpeeb.MATTER.get(mt, ["hit_flesh", 1.0])
		player.get_parent().sfx(snd[0], -6 if mt == "metal" else -9, t.global_position + Vector3(0, 0.8, 0), float(snd[1]))
		heard_matter[mt] = int(heard_matter.get(mt, 0)) + 1


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
## At a boat's swivel the gunner's shots strike harder.
func station_mult() -> float:
	var v = player.get("vessel") if player else null
	if v != null and is_instance_valid(v) and v.has_method("station_of") and v.station_of(Net.me()) == "gun":
		return WBoat.GUN_MULT
	return 1.0


func tier_mult() -> float:
	return WArms.tier_mult(Game.tier_of(gun()))


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
		if not blade_out and not _reloading and shells >= capacity() and _inspect <= 0.0:
			inspect()
		else:
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
	if i < 0 or i >= guns.size():
		return
	if blade_out:
		_sheathe()
		if cur != i:
			cur = i
			_show_model()
		return
	if cur != i:
		swap(i)


## Takes up the carried gun named g, if it is carried.
func draw_named(g: String) -> void:
	draw_gun(guns.find(g))


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


## To the next gun carried, or to gun i.
func swap(to := -1) -> void:
	if _switch > 0.0:
		return
	if blade_out:
		_sheathe()
		return
	_reloading = false
	cur = to if to >= 0 and to < guns.size() else (cur + 1) % guns.size()
	_switch = 0.35
	_spin = 0.0
	_show_model()
	player.get_parent().sfx("shell", -12)
	_ui()


## Reload with a full gun: it is brought up and turned over in the hands, one side and then the other.
const INSPECT_LEN := 2.6
var _inspect := 0.0


func inspect() -> void:
	_inspect = INSPECT_LEN
	player.get_parent().sfx("mag_grab", -16, null, randf_range(0.9, 1.0))


func _inspect_pose(delta: float) -> void:
	var k := 1.0 - _inspect / INSPECT_LEN
	_inspect = maxf(0.0, _inspect - delta)
	var e := smoothstep(0.0, 0.16, k) * (1.0 - smoothstep(0.82, 1.0, k))
	var turn := smoothstep(0.42, 0.66, k)
	_holder.position += Vector3(-0.1, 0.07, 0.1) * e
	_holder.rotation.x += 0.18 * e
	_holder.rotation.y = lerpf(-0.55, 0.75, turn) * e
	_holder.rotation.z = lerpf(0.85, -0.3, turn) * e
	if _inspect <= 0.0:
		_holder.rotation.y = 0.0


func _start_reload() -> void:
	_stop_inspect()
	if blade_out or shells >= capacity() or reserve <= 0 or _reloading:
		return
	_reloading = true
	_reload_t = float(spec().reload_t) * reload_mult
	_reload_len = _reload_t
	_rl_out = false
	_rl_in = false



## Throws one spent case out of the side of the gun in hand; it bounces, rolls, and lies a while.
static var _cases: Array = []
const CASES_MAX := 40

func _eject() -> void:
	if not is_instance_valid(_model) or not _model.is_inside_tree():
		return
	var gt := _model.global_transform
	Arms.throw_case(player.get_parent(), gun(), gt * SIDE.get(ArmsDB.look(gun()), Vector3(0.03, 0.01, 0.0)), gt.basis, player.velocity)


## When a gun throws its spent case after a shot: a pump or a bolt when worked; a revolver keeps them (-1).
static func case_delay(g: String) -> float:
	var s: Dictionary = ArmsDB.GUNS.get(g, {})
	g = ArmsDB.look(g)
	if g == "revolver" or AmmoLook.spent_of(g) == "":
		return -1.0
	match str(s.get("mode", "")):
		"pump":
			return 0.32
		"bolt":
			return 0.5
	return 0.0


## Throws a spent case of gun g out of the side, from `at`, turned as `b` (the gun's own basis).
## Used for one's own shots and for those of the rest of the fellowship.
static func throw_case(lvl: Node, g: String, at: Vector3, b: Basis, carried := Vector3.ZERO) -> void:
	if lvl == null or not is_instance_valid(lvl) or not lvl.is_inside_tree():
		return
	var piece := AmmoLook.spent_of(g)
	if piece == "":
		return
	var look := AmmoLook.make(piece)
	if look == null:
		return
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = 1
	rb.mass = 0.02
	rb.continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.8
	rb.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.012 if g != "shotgun" else 0.022
	sh.height = 0.04 if g != "shotgun" else 0.07
	cs.shape = sh
	rb.add_child(cs)
	rb.add_child(look)
	lvl.add_child(rb)
	rb.global_position = at
	rb.global_basis = b.orthonormalized() * Basis(Vector3.RIGHT, PI * 0.5)
	var right := b.x.normalized()
	var up := b.y.normalized()
	var back := b.z.normalized()
	rb.linear_velocity = carried + right * randf_range(2.2, 3.2) + up * randf_range(1.2, 2.0) + back * randf_range(0.0, 0.6)
	rb.angular_velocity = Vector3(randf_range(-25, 25), randf_range(-25, 25), randf_range(-25, 25))
	_cases.append(rb)
	while _cases.size() > CASES_MAX:
		var old = _cases.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	# Settled, it stops costing anything; long after, it is gone
	var tree := lvl.get_tree()
	tree.create_timer(3.0, false).timeout.connect(func():
		if is_instance_valid(rb):
			rb.freeze = true)
	tree.create_timer(45.0, false).timeout.connect(func():
		if is_instance_valid(rb):
			_cases.erase(rb)
			rb.queue_free())
	if randf() < 0.5:
		tree.create_timer(0.45, false).timeout.connect(func():
			if is_instance_valid(rb) and is_instance_valid(lvl) and lvl.has_method("sfx"):
				lvl.sfx("shell" if g == "shotgun" else "tick", -22, rb.global_position, randf_range(1.6, 2.1)))


## How far a shot may wander right now: wide from the hip and wider as shots pile up, tight down the sights.
func shot_spread() -> float:
	var s := spec()
	var spread := float(s.spread)
	# From the hip a gun wanders; down the sights it holds true
	var hip := 1.3 if s.mode == "pump" else (2.6 if s.mode == "bolt" else 1.9)
	spread = maxf(spread, 0.006) * lerpf(hip, float(ArmsDB.SIGHTS.get(mount(), ArmsDB.SIGHTS[""]).spread), _aim)
	if mount() in ["red_dot", "reflex", "holo"]:
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
	if _flame_hold > 0.0:
		_flame_hold -= delta
		if _flame_hold <= 0.0 and _flame_snd and _flame_snd.playing:
			_flame_snd.stop()
			player.get_parent().sfx("whoosh", -14, null, 0.8)   # the last of it, cut off
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
		elif s.mode in ["semi", "auto"] and _quiet < 0.08:
			phase = sin(_quiet / 0.08 * PI)   # the slide or bolt blown back by the shot, and home again
		_pump.position.z = phase * (0.1 if s.mode == "pump" else (0.06 if s.mode == "bolt" else 0.03))
		if s.mode == "rocket" and not _reloading:
			_pump.visible = shells > 0   # the rocket is gone once fired, till the next goes in
	var bob := sin(Time.get_ticks_msec() * 0.008) * 0.006 * clampf(player.cur_speed / 3.0, 0.0, 1.5)
	_sway = _sway.lerp(Vector2.ZERO, delta * 8.0)
	var aiming := not blade_out and (debug_aim or Game.held("aim") and not player.input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _reloading and _swing <= 0.0)
	_set_aim(1.0 if aiming else 0.0, delta)
	if Game.main and Game.main.hud:
		Game.main.hud.ads = _aim > 0.35   # down the sights, the dot on the screen gives way to the gun's own
	# Aiming brings the sights onto the eye's own line
	var aim_off := Vector3.ZERO
	var ease_aim := smoothstep(0.0, 1.0, _aim)
	position = Vector3(0.16, -0.19, -0.5).lerp(Vector3(float(_model.get_meta("eye_x", 0.0)), -float(_model.get_meta("eye", 0.07)), float(_model.get_meta("eye_z", -0.6))), ease_aim)
	rotation = Vector3(0.02, 0.05, 0) * (1.0 - ease_aim) + (_model.get_meta("eye_rot", Vector3.ZERO) as Vector3) * ease_aim
	# Close to a wall (or a tree, a rock, a crate) the gun is drawn back and tipped up, so it does not
	# pass through it
	_tuck = move_toward(_tuck, _wall_tuck(), delta * 5.0)
	var tk := smoothstep(0.0, 1.0, _tuck)
	_holder.position = Vector3(_sway.x - tk * 0.05, bob - _kick * 0.04 + _sway.y - _switch * 0.5 - tk * 0.04, _kick * 0.12 * (1.0 - _aim * 0.6) + tk * 0.3) + aim_off
	_holder.rotation.x = _kick * 0.35 * (1.0 - _aim * 0.7) - _switch * 1.4 + tk * 0.75
	_holder.rotation.y = tk * 0.35
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
	if s.has("slow") and s.mode != "spin":
		player.carry_slow = float(s.slow)
	elif s.mode == "spin":
		_spin = move_toward(_spin, 1.0 if holding and shells > 0 and not _reloading else 0.0, delta / float(s.spin))
		if _pump:
			_pump.rotation.z += delta * 40.0 * _spin
		player.carry_slow = float(s.get("slow", 1.0))
	else:
		player.carry_slow = 1.0
	if _inspect > 0.0 and (holding or _aim > 0.05 or _reloading or blade_out or _switch > 0.0 or _swing > 0.0):
		_stop_inspect()
	if _inspect > 0.0:
		_inspect_pose(delta)
	elif _reloading:
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
			# The pack's own 12 gauge shell (see AmmoLook), crimp first into the tube; a plain one if it is missing
			_shell_mesh = AmmoLook.round_of("shell")
			if _shell_mesh != null:
				# Sized by the whole shell (its brass and its crimped body together) to a 12 gauge's length
				var bb := AABB()
				var first := true
				for mi in _shell_mesh.find_children("*", "MeshInstance3D", true, false):
					var a: AABB = Arms._chain(mi, _shell_mesh) * (mi as MeshInstance3D).mesh.get_aabb()
					bb = a if first else bb.merge(a)
					first = false
				_shell_mesh.scale = Vector3.ONE * (0.068 / maxf(bb.size.y, 0.001))
			else:
				var mi := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.009
				c.bottom_radius = 0.009
				c.height = 0.06
				mi.mesh = c
				mi.material_override = _mat(Color(0.7, 0.2, 0.15), 0.2, 0.5)
				_shell_mesh = mi
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
		# A new rocket slides in at the front
		var in_k := smoothstep(0.5, 0.82, k)
		_pump.visible = k > 0.5
		_pump.position.z = -0.45 * (1.0 - in_k)
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


func _stop_inspect() -> void:
	if _inspect > 0.0:
		_inspect = 0.0
		_holder.rotation.y = 0.0


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
	elif enabled and mount() == "" and spec().has("iron_zoom"):
		zoom = float(spec().iron_zoom)   # a long gun's own iron sights draw the eye in a little
	var f: float = Game.fov / lerpf(1.0, zoom, _aim)
	if absf(player.cam.fov - f) > 0.01:
		player.cam.fov = f
	var scoped := enabled and _aim > 0.85 and zoom >= 2.4
	scoped_now = scoped
	_scope_drift(delta, scoped, enabled and _aim > 0.85)
	_holder.visible = not scoped and not blade_out
	_show_dots()


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


## Down the sights the aim sways with the breath; more behind a scope, more with a heavy gun, more when
## moving or winded, and less the more this survivor has used this gun. Behind a scope, hold Hasten to
## stop breathing and steady it. The sway moves the view itself, so it really is where the shot goes.
func _scope_drift(delta: float, scoped: bool, aiming := false) -> void:
	var holding := scoped and Input.is_action_pressed("run") and _gasp <= 0.0 and _breath > 0.0
	if holding:
		_breath = maxf(0.0, _breath - delta / 4.0)
		if _breath <= 0.0:
			_gasp = 2.0
	else:
		_breath = minf(1.0, _breath + delta / 3.0)
		_gasp = maxf(0.0, _gasp - delta)
	var amp := 0.0
	if scoped or aiming:
		amp = 0.0 if holding else sway_amp(scoped) * (1.0 if _gasp <= 0.0 else 3.0)
	_drift_t += delta
	var want := Vector2(sin(_drift_t * 1.1) * 1.0, sin(_drift_t * 2.2) * 0.6) * amp
	var step := want - _drift
	_drift = want
	player.yaw += step.x
	player.pitch += step.y
	Game.main.hud.set_scope(scoped, _breath)


## How far the aim sways down the sights (radians): by the gun's weight, the glass, the legs and the lungs,
## and the hand that has used this gun: each rank of practice takes some off, nine ranks near halve it.
func sway_amp(scoped: bool) -> float:
	var g := ArmsDB.look(gun())
	var s := spec()
	var amp := 0.0016 if scoped else 0.0007
	if g in ["minigun", "rocket"] or s.mode == "bolt":
		amp *= 1.35
	elif s.mode == "pistol" or g in ["pistol", "pistol9", "revolver"]:
		amp *= 0.8
	if fitted("foregrip"):
		amp *= 0.85
	if player.velocity.length() > 1.0:
		amp *= 2.2
	if player.get("stamina") != null and float(player.stamina) < float(player.stamina_max) * 0.25:
		amp *= 1.6
	var sk = _skills()
	if sk:
		amp *= 1.0 - 0.055 * sk.use_level(g)
	return amp


func sway(rel: Vector2) -> void:
	_sway += Vector2(-rel.x, rel.y) * 0.00012 * (1.0 - _aim * 0.7)


# ------------------------------------------------------------------ firing

## One breath of the flamethrower: a cone of fire that burns all it reaches, and now and then
## leaves the ground alight where it falls.
func _flame(s: Dictionary, lvl) -> void:
	var cam := player.cam
	var origin := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var tip: Vector3 = _model.to_global(_model.get_meta("tip")) if _model else origin + fwd
	Arms.flame_jet(lvl, tip, fwd, _string % 3 == 0)
	# The roar of it, held while the trigger is; and the gun's mouth lit orange
	if _flame_snd == null:
		_flame_snd = AudioStreamPlayer.new()
		_flame_snd.stream = Arms.flame_loop()
		_flame_snd.bus = Game.bus_of("flame")
		_flame_snd.volume_db = FLAME_DB
		add_child(_flame_snd)
	if not _flame_snd.playing:
		_flame_snd.play()
	_flame_hold = 0.16
	if _flash:
		_flash.light_color = Color(1.0, 0.55, 0.2)
		_flash.light_energy = randf_range(2.2, 3.4)
	if _string % 3 == 0:
		Net.fx("gun:flamer", origin, fwd)
	var reach := float(s.range)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + fwd * reach, 1)
	q.exclude = [player.get_rid()]
	var wall := space.intersect_ray(q)
	if not wall.is_empty():
		reach = origin.distance_to(wall.position) + 0.8
	var hits := {}
	var dmg := float(s.dmg) * damage_mult * tier_mult()
	for e in lvl.get("enemies") if lvl.get("enemies") != null else []:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var to: Vector3 = e.global_position + Vector3(0, 0.6, 0) - origin
		if to.length() < reach + 0.5 and fwd.dot(to.normalized()) > float(s.get("cone", 0.88)):
			hits[e] = dmg
	if not hits.is_empty():
		Arms.deal(hits, fwd, "fire")
		_practise("flamer", hits)
	if _string % 7 == 0:
		var land: Vector3 = wall.position if not wall.is_empty() else origin + fwd * reach
		var dq := PhysicsRayQueryParameters3D.create(land + Vector3.UP, land + Vector3.DOWN * 6.0, 1)
		var g := space.intersect_ray(dq)
		if not g.is_empty():
			Thrown.burn(lvl, g.position, 1.6, dmg * 1.2, 3.0, true, true)


var _flame_snd: AudioStreamPlayer
var _flame_hold := 0.0
## How loud one's own shot is played: the recordings are sharp cracks, quiet beside a growl, so they go in hot
## (the Guns line has a limiter). The flamer's roar never stops while held, so it sits well under them.
const GUN_DB := 6.0
const FLAME_DB := -15.0


## How loud a gun's own shot is played. The launcher's whoosh was made full and loud already.
static func shot_db(sound: String) -> float:
	return -2.0 if sound == "rocket" else GUN_DB
static var _flame_loop: AudioStreamWAV
static var _smoke_m: StandardMaterial3D


## The flamethrower's roar, made to loop.
static func flame_loop() -> AudioStreamWAV:
	if _flame_loop == null:
		_flame_loop = (load("res://assets/audio/flame_loop.wav") as AudioStreamWAV).duplicate()
		_flame_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_flame_loop.loop_begin = 0
		_flame_loop.loop_end = _flame_loop.data.size() / 2
	return _flame_loop


## Dark smoke rolling up off a tongue of fire.
static func flame_smoke(lvl: Node, at: Vector3, dir: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 5
	p.lifetime = 1.8
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	p.mesh = q
	if _smoke_m == null:
		_smoke_m = StandardMaterial3D.new()
		_smoke_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_smoke_m.vertex_color_use_as_albedo = true
		_smoke_m.albedo_texture = Relics._soft_dot()
	p.material_override = _smoke_m
	p.local_coords = false
	p.direction = dir + Vector3(0, 0.6, 0)
	p.spread = 25.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.gravity = Vector3(0, 1.6, 0)
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(1, 3.2))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, Color(0.25, 0.2, 0.17, 0.0))
	g.add_point(0.2, Color(0.2, 0.17, 0.15, 0.45))
	g.set_color(g.get_point_count() - 1, Color(0.3, 0.28, 0.26, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lvl.add_child(p)
	p.global_position = at + dir * 5.0
	p.emitting = true
	lvl.get_tree().create_timer(2.2, false).timeout.connect(p.queue_free)


## A tongue of fire, seen by everyone: thrown from `at` along `dir`.
static func flame_jet(lvl: Node, at: Vector3, dir: Vector3, smoke := false) -> void:
	if Net.dedicated or lvl == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 12
	p.lifetime = 0.55
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	p.mesh = q
	if _jet_m == null:
		_jet_m = StandardMaterial3D.new()
		_jet_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_jet_m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_jet_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_jet_m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_jet_m.vertex_color_use_as_albedo = true
		_jet_m.albedo_texture = Relics._soft_dot()
	p.material_override = _jet_m
	p.local_coords = false
	p.direction = dir
	p.spread = 7.0
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 21.0
	p.damping_min = 14.0
	p.damping_max = 20.0
	p.gravity = Vector3(0, 2.5, 0)
	var c := Curve.new()
	c.add_point(Vector2(0, 0.25))
	c.add_point(Vector2(1, 2.6))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.92, 0.6, 1.0))
	g.add_point(0.35, Color(1.0, 0.5, 0.12, 0.9))
	g.set_color(g.get_point_count() - 1, Color(0.35, 0.08, 0.02, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lvl.add_child(p)
	p.global_position = at
	p.emitting = true
	lvl.get_tree().create_timer(0.9, false).timeout.connect(p.queue_free)
	if smoke:
		flame_smoke(lvl, at, dir)


var hands_full := false   ## carrying something in both hands (a beacon ember): no shooting


func _try_fire() -> void:
	var s := spec()
	if _cool > 0.0 or hands_full:
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
	var quiet := fitted("suppressor") or fitted("heavy_suppressor")
	if s.mode != "flame":
		lvl.sfx("supp" if quiet else str(s.sound), -6 if quiet else shot_db(str(s.sound)), null, 0.7 if s.mode == "flame" else 1.0)
	# Foes about hear it: a suppressed shot carries a short way, a bare one far across the waste
	if lvl.has_method("noise"):
		lvl.noise(player.global_position, 20.0 if quiet else (140.0 if gun() in ["sniper", "revolver"] else 110.0))
	if s.mode == "pump":
		get_tree().create_timer(0.3, false).timeout.connect(func(): lvl.sfx("pump", -8))
	elif s.mode == "bolt":
		get_tree().create_timer(0.45, false).timeout.connect(func(): lvl.sfx("pump", -8, null, 1.25))
	if s.mode == "flame":
		_flame(s, lvl)
		return
	if not quiet and not fitted("flash_hider"):
		_flash.light_color = Color(1.0, 0.8, 0.5)
		_flash.light_energy = 4.0 if s.mode != "spin" else 2.5
		_flash_mesh.visible = true
		_flash_mesh.rotation.z = randf() * TAU
		_flash_mesh.scale = Vector3.ONE * float(FLASH_SIZE.get(ArmsDB.look(gun()), 0.18)) * randf_range(0.85, 1.15)
		for q in _flash_sides:
			(q as MeshInstance3D).material_override = _flash_mats[randi() % _flash_mats.size()]
		get_tree().create_timer(0.04, false).timeout.connect(func():
			_flash.light_energy = 0.0
			_flash_mesh.visible = false)
	var cam := player.cam
	var origin := cam.global_position
	var fwd := -cam.global_transform.basis.z
	Net.fx("gun:%s%s" % [gun(), ":s" if quiet else ""], origin, fwd)
	lvl.shots += 1
	# The spent case flies out of the side (a pump or a bolt throws it when worked; a revolver keeps them)
	var cd := case_delay(gun())
	if cd > 0.0:
		get_tree().create_timer(cd, false).timeout.connect(_eject)
	elif cd == 0.0:
		_eject()
	if s.mode == "rocket":
		var r := Rocket.new()
		r.owner_player = player
		r.dmg = float(s.dmg) * damage_mult * tier_mult()
		r.radius = float(s.radius)
		r.vel = fwd * float(s.speed)
		lvl.add_child(r)
		# Down the sights it leaves along the sight line; from the hip, from the tube on the shoulder
		var side := cam.global_transform.basis.x * 0.15 * (1.0 - _aim)
		r.global_position = origin + fwd * 0.9 + side - cam.global_transform.basis.y * lerpf(0.1, 0.05, _aim)
		return
	var space := get_world_3d().direct_space_state
	var spread := 0.0
	spread = shot_spread()
	var hits := {}
	var crits := {}
	var dmg_m := damage_mult * tier_mult() * (1.3 if Game.blessed("speebsnek") else 1.0) * (0.92 if quiet else 1.0) * station_mult()
	for i in int(s.pellets):
		var dir := fwd
		if spread > 0.0:
			dir = dir.rotated(cam.global_transform.basis.x, randf_range(-spread, spread) * 0.7)
			dir = dir.rotated(cam.global_transform.basis.y, randf_range(-spread, spread))
		# Close in, a shot lands at once; further out it flies, and a moving foe must be led
		var near := minf(float(s.range), NEAR)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * near, 1 | 2)
		q.exclude = [player.get_rid()]
		q.collide_with_areas = false
		var r := space.intersect_ray(q)
		if r.is_empty():
			if float(s.range) > near:
				var b := Slug.new()
				b.arms = self
				b.gun_id = gun()
				b.origin = origin
				b.dir = dir
				b.speed = float(MUZZLE.get(gun(), MUZZLE.get(ArmsDB.look(gun()), 340.0)))
				b.grav = GRAVITY * float(CALIBER.get(ArmsDB.look(gun()), ["", 1.0])[1])
				b.left = float(s.range) - near
				b.dmg = float(s.dmg) * dmg_m
				b.falloff = float(s.falloff)
				b.crit = float(s.crit)
				b.pierce = float(s.get("pierce", 1.0))
				b.harm = "shot" if int(s.pellets) > 1 else "bullet"
				b.shooter = player
				lvl.add_child(b)
				b.global_position = origin + dir * near
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
	LesserSpeeb.harm_arm = gun()
	Arms.deal(hits, fwd, "shot" if int(s.pellets) > 1 else "bullet", crits)
	LesserSpeeb.harm_pierce = 1.0
	LesserSpeeb.harm_arm = ""
	_impact_sounds(hits)
	_practise(gun(), hits)


## Applies harm to each struck thing and shows the hit marker once.
static var _told_deflect := -100000


const HEAD_MULT := 1.6
const NEAR := 25.0           ## within this a shot lands at once; beyond it, it takes time to arrive
## How fast each gun's rounds fly, in metres a second: slow enough that a far runner must be led
## How long each gun's muzzle flame is, in metres.
const FLASH_SIZE := {"pistol": 0.1, "pistol9": 0.1, "pistol45": 0.11, "revolver": 0.13, "shotgun": 0.24, "machine_gun": 0.18,
	"rifle": 0.18, "lmg": 0.22, "minigun": 0.2, "sniper": 0.24}
static var _flash_mats: Array = []
static var _flash_star: StandardMaterial3D


static func _flash_mat(path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_texture = load(path)
	m.albedo_color = Color(1.4, 1.05, 0.55)
	return m


## The flash, made one metre long (scaled to each gun as it fires): two crossed flames from Kenney's
## Particle Pack (CC0) along the barrel, their roots at the muzzle, and a burst facing the eye.
func _make_flash() -> Node3D:
	if _flash_mats.is_empty():
		for i in range(1, 6):
			_flash_mats.append(_flash_mat("res://assets/textures/fx/muzzle_0%d.png" % i))
		_flash_star = _flash_mat("res://assets/textures/fx/flash_star.png")
		_flash_star.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_flash_star.albedo_color = Color(1.6, 1.25, 0.75)
	var root := Node3D.new()
	_flash_sides.clear()
	for k in 2:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.55, 1.0)
		q.mesh = qm
		q.material_override = _flash_mats[k]
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The picture's flame rises up its height; laid along -Z, its root (low in the picture) at the muzzle
		q.rotation = Vector3(-PI / 2, 0, 0)
		q.position = Vector3(0, 0, -0.36)
		if k == 1:
			var turn := Node3D.new()
			turn.rotation.z = PI / 2
			turn.add_child(q)
			root.add_child(turn)
		else:
			root.add_child(q)
		_flash_sides.append(q)
	var star := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(0.32, 0.32)
	star.mesh = sq
	star.material_override = _flash_star
	star.position = Vector3(0, 0, -0.04)
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(star)
	return root


const MUZZLE := {"carbine": 640.0, "shotgun": 260.0, "pistol": 280.0, "pistol9": 270.0, "revolver": 320.0, "machine_gun": 380.0, "lmg": 400.0, "minigun": 360.0, "sniper": 520.0}
## Each gun's round, and how hard it falls (times the earth's pull): light and blunt rounds lose height sooner,
## long heavy ones hold their line. Past NEAR a round drops, more the slower and further it flies.
const CALIBER := {"shotgun": ["12 gauge", 1.6], "pistol": [".45", 1.25], "pistol9": ["9mm", 1.2], "revolver": [".45 Colt", 1.15],
	"machine_gun": ["5.56", 1.0], "lmg": ["7.62", 0.9], "minigun": ["7.62", 0.9], "sniper": [".308", 0.8]}
const GRAVITY := 9.8


## Whether a ray passes within r of a point (the head's middle).
static func _ray_near(o: Vector3, d: Vector3, c: Vector3, r: float) -> bool:
	var t := maxf(0.0, (c - o).dot(d))
	return (o + d * t).distance_to(c) < r


static var _toll := 0   ## blows landed toward the Bell's Toll

static func deal(hits: Dictionary, dir: Vector3, harm := "", crits := {}) -> void:
	# The Bell-Wound's power: every eighth blow or shot that lands rings, and strikes twice as hard
	var lv = Game.main.level if Game.main else null
	var bell_k: float = lv.power_k("bell") if lv and lv.has_method("power_k") else 0.0
	if not hits.is_empty() and bell_k > 0.0:
		_toll += 1
		if _toll >= int(round(8.0 / bell_k)):
			_toll = 0
			for t in hits:
				hits[t] = float(hits[t]) * 2.0
			lv.sfx("bell", -8, null, 1.6)
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
	var was := guarding
	guarding = Game.held("aim") and not player.input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _swing <= 0.0 and not player.get("winded")
	guard_age = (0.0 if not was else guard_age + delta) if guarding else 99.0
	if guarding and not was and Net.online and not Net.authority() and Game.main and Game.main.level:
		Game.main.level.shared("_w_guard_up", [Net.me()])   # the host's foes can be turned by a friend's guard too
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
	m.dmg = float(m.dmg) * WArms.tier_mult(Game.tier_of(melee))
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
		hits[r.collider] = float(m.dmg) * damage_mult * _back_bonus(m, r.collider)
	# A wide swing sweeps more of what stands before you
	var arc := float(m.get("arc", 0.6)) - (0.1 if heavy else 0.0)
	for e in lvl.get("enemies") if lvl.get("enemies") != null else []:
		if not is_instance_valid(e) or hits.has(e) or not e.is_alive():
			continue
		var to: Vector3 = e.global_position + Vector3(0, 0.6, 0) - origin
		if to.length() < float(m.reach) + 0.6 and fwd.dot(to.normalized()) > arc:
			hits[e] = float(m.dmg) * damage_mult * _back_bonus(m, e)
	if not hits.is_empty():
		lvl.sfx("chop", -1 if heavy else -4, null, randf_range(0.85, 1.1) * (0.8 if heavy else 1.0))
		player.shake(0.3 if heavy else 0.15)
		LesserSpeeb.harm_pierce = float(m.get("pierce", 1.0))
		LesserSpeeb.harm_heavy = heavy
		LesserSpeeb.harm_arm = melee
		Arms.deal(hits, fwd, str(m.get("harm", "blade")))
		LesserSpeeb.harm_pierce = 1.0
		LesserSpeeb.harm_heavy = false
		LesserSpeeb.harm_arm = ""
		_practise("blade", hits)
		_hit_stop(0.09 if heavy else 0.05, hits.keys())
	elif not r.is_empty():
		lvl.puff(r.position, r.normal)
		lvl.sfx("thud", -10)


## A blade that lands holds the world still for a blink, so the blow is felt. With others, time is shared
## and must not stop for one: then only what was struck holds still, on this screen, and the view jolts.
static var stops := 0   ## how many hit-stops have been held (for the tests)
static var held := 0    ## how many struck foes were held still in a fellowship (for the tests)
func _hit_stop(secs: float, struck: Array = []) -> void:
	if Net.online:
		for e in struck:
			if is_instance_valid(e) and e is Node:
				held += 1
				for ap in (e as Node).find_children("*", "AnimationPlayer", true, false):
					var a := ap as AnimationPlayer
					if a.is_playing():
						a.pause()
						get_tree().create_timer(secs, false).timeout.connect(func(): if is_instance_valid(a) and not a.is_playing(): a.play())
		player.shake(0.25 if secs > 0.07 else 0.12)
		return
	if Engine.time_scale < 1.0:
		return
	stops += 1
	Engine.time_scale = 0.05
	await get_tree().create_timer(secs, true, false, true).timeout
	if Engine.time_scale <= 0.05:
		Engine.time_scale = 1.0


## A knife in the back: the blow is worth more against a foe looking elsewhere.
func _back_bonus(m: Dictionary, e) -> float:
	if not m.has("back") or not is_instance_valid(e) or not e is Node3D or e.get("head") == null:
		return 1.0
	var h: Node3D = e.head
	var facing := Vector3(sin(h.global_rotation.y), 0, cos(h.global_rotation.y))
	var to_me: Vector3 = player.global_position - e.global_position
	to_me.y = 0
	return float(m.back) if facing.dot(to_me.normalized()) < 0.2 else 1.0


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

## Makes the guns again (a new finish): the one in hand shows at once.
func refinish() -> void:
	for k in _models:
		_models[k].queue_free()
	_models.clear()
	_show_model()


func _show_model() -> void:
	for k in _models:
		_models[k].visible = false
	var g := gun()
	if not _models.has(g):
		_models[g] = _build(g)
		_holder.add_child(_models[g])
		# Only in one's own hands is the red dot drawn over all else (on the glass, past the sight's body);
		# on another's gun, or one set down, it hides behind what stands before it
		for q in _models[g].find_children("*", "MeshInstance3D", true, false):
			if q.has_meta("reticle"):
				var rt: Array = q.get_meta("reticle")
				(q as MeshInstance3D).material_override = _reticle_mat(rt[0], rt[1], true)
	_model = _models[g]
	# Drawn over all else, the dot showed through the sight's body from the hip: it is seen only down the sight
	_dots = _model.find_children("*", "MeshInstance3D", true, false).filter(func(q): return q.has_meta("reticle"))
	_show_dots()
	_model.visible = true
	_pump = _model.get_meta("pump") if _model.has_meta("pump") else null
	var tip: Vector3 = _model.transform * (_model.get_meta("tip") as Vector3)
	_flash.position = tip
	_flash_mesh.position = tip
	_ui()


## How near something solid stands ahead of the gun: 0 clear, 1 right at the muzzle's root.
func _wall_tuck() -> float:
	if player == null or player.cam == null or not is_inside_tree() or blade_out:
		return 0.0
	var reach := 0.95 if _model == null else clampf(0.35 + float((_model.get_meta("bb") as AABB).size.z if _model.has_meta("bb") else 0.6), 0.6, 1.4)
	var cam: Camera3D = player.cam
	var from := cam.global_position
	var near := reach
	var space := get_world_3d().direct_space_state
	for off in [Vector3.ZERO, Vector3(0.16, -0.19, 0.0)]:
		var a: Vector3 = from + cam.global_transform.basis * off
		var q := PhysicsRayQueryParameters3D.create(a, a - cam.global_transform.basis.z * reach, 1)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			near = minf(near, a.distance_to(hit.position))
	return clampf((reach - near) / (reach * 0.65), 0.0, 1.0)


func _show_dots() -> void:
	for q in _dots:
		if is_instance_valid(q):
			q.visible = _aim > 0.7


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
	var far_tint: Color = FAR_TINT.get(g, Color(0, 0, 0, 0))
	g = ArmsDB.look(g)   # a far arm wears the body of the gun it borrows
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
		"machine_gun", "lmg":
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
			if g == "lmg":   # longer, with a heavy barrel
				tip = Vector3(0, 0.012, -0.82)
				front = Vector3(0, 0.042, -0.62)
				fore = Vector3(0, -0.03, -0.36)
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
		"flamer":
			# A fuel tank slung under, a long nozzle, and a pilot light at the mouth
			_tube(0.03, 0.62, Vector3(0, 0.0, -0.18), metal, n)
			_tube(0.04, 0.08, Vector3(0, 0.0, -0.5), dark, n)
			_tube(0.036, 0.04, Vector3(0, 0.0, 0.08), dark, n)
			_box(Vector3(0.05, 0.06, 0.24), Vector3(0, -0.02, 0.2), dark, n)
			_tube(0.06, 0.26, Vector3(0, -0.1, -0.02), _mat(Color(0.45, 0.2, 0.12), 0.4, 0.6), _mag_node(n))
			_box(Vector3(0.036, 0.1, 0.045), Vector3(0, -0.08, 0.18), dark, n, Vector3(-0.3, 0, 0))
			_box(Vector3(0.036, 0.1, 0.045), Vector3(0, -0.07, -0.3), dark, n)
			_tube(0.008, 0.06, Vector3(0, -0.045, -0.53), brass, n)
			var pilot := OmniLight3D.new()
			pilot.light_color = Color(0.5, 0.7, 1.0)
			pilot.light_energy = 0.4
			pilot.omni_range = 0.6
			pilot.position = Vector3(0, -0.04, -0.57)
			n.add_child(pilot)
			tip = Vector3(0, 0.0, -0.56)
			top = 0.04
			front = Vector3(0, 0.035, -0.45)
			fore = Vector3(0, -0.07, -0.3)
			top = 0.11
			rear_z = 0.2
			front = Vector3(0, 0.11, 0.03)
		"pistol", "pistol9":
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
	var scan_top := _scan_gun(g, n, fit)
	if scan_top > -1.0:
		top = scan_top   # its own sights are on it; a fitted sight sits on its top
		# Its mouth and the underside of its fore-end, as the scanned body has them
		tip = SCAN_TIP.get(g, tip)
		var under := _cut_line(n, g, 1, 0.0, fore.z)
		if under.x < 8.0:
			fore.y = under.x
	_frame_parts(g, fit, n, tip)
	tip = n.get_meta("tip_after", tip)
	if scan_top <= -1.0:
		# A plain-shape gun: the sights sit on what is really its top, so the eye never looks through it
		top = maxf(top, _geo_top(n))
	var eye := top + 0.012
	var sight := ""
	for m in fit:
		if ArmsDB.ATTACHMENTS.has(m) and ArmsDB.ATTACHMENTS[m].slot == "sight":
			sight = m
	# The pack's own sight, on a rail, where it has one
	var scan_eye := -1.0
	if sight != "" and scan_top > -1.0:
		# A scanned body's top is its tallest part (a hammer, a rear sight): the sight sits on the
		# metal right under it instead, so it does not float above the gun
		var sz := rear_z - (0.12 if sight in ["scope", "combat_scope"] else 0.08)
		var tops: Array = []
		for k in 5:
			var h := _cut_line(n, g, 1, 0.0, sz - 0.03 + k * 0.015).y
			if h > -8.0:
				tops.append(h)
		tops.sort()
		if tops.size() >= 2:
			# On a rail, the tops of its ridges; on a slide or a frame, its surface (a rear sight or a
			# hammer standing up in the way is not counted)
			top = minf(top, tops[-1] if g in RAILED else tops[1])
			eye = top + 0.012
	if sight != "" and not (sight == "scope" and built_glass(g, fit)):
		scan_eye = _put_sight(n, g, sight, top, rear_z)
	if scan_eye > -1.0:
		eye = scan_eye
		sight = "-"
	match ACC_FAMILY.get(sight, sight):
		"-":
			pass
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
			eye = float(n.get_meta("glass_y", 0.082)) if built_glass(g, fit) else top + 0.034
		_:
			if built_glass(g, fit):
				eye = float(n.get_meta("glass_y", 0.082))
			else:
				# Iron sights: a notch behind and a post before (a scanned gun has its own)
				for sx in ([] if scan_top > -1.0 else [-1, 1]):
					_box(Vector3(0.005, 0.012, 0.008), Vector3(0.0075 * sx, top + 0.006, rear_z), dark, n)
				if scan_top <= -1.0:
					_box(Vector3(0.022, 0.004, 0.01), Vector3(0, top + 0.001, rear_z), dark, n)
					var h := maxf(0.008, eye - front.y)
					_box(Vector3(0.004, h, 0.006), Vector3(0, front.y + h * 0.5, front.z), dark, n)
					_box(Vector3(0.012, 0.003, 0.01), Vector3(0, front.y + 0.001, front.z), dark, n)
	for m in fit:
		if ArmsDB.ATTACHMENTS.has(m) and ArmsDB.ATTACHMENTS[m].slot in ["muzzle", "grip"]:
			var put: Variant = _put_acc(n, g, m, tip, fore)
			if put != null:
				if ArmsDB.ATTACHMENTS[m].slot == "muzzle":
					tip = put
				continue
		match ACC_FAMILY.get(m, m):
			"suppressor":
				_tube(0.022, 0.19, tip + Vector3(0, 0, -0.085), dark, n)
				_tube(0.0235, 0.012, tip + Vector3(0, 0, -0.02), metal, n)
				tip += Vector3(0, 0, -0.18)
			"foregrip":
				_box(Vector3(0.03, 0.012, 0.05), fore, dark, n)
				_box(Vector3(0.026, 0.085, 0.03), fore + Vector3(0, -0.045, 0.004), dark, n, Vector3(0.12, 0, 0))
	n.set_meta("tip", tip)
	if sight == "" and not built_glass(g, fit):
		eye -= float(IRON_DROP.get(g, 0.0))   # the scanned body's top is a hammer or slide: its own sights sit lower
		n.set_meta("eye_x", float(IRON_SIDE.get(g, 0.0)))
		if SIGHT_LINE.has(g):
			# Turned so the rear's middle and the front's middle sit on the eye's line, the rear on the eye
			var rear: Vector3 = SIGHT_LINE[g][0]
			var tb := Basis.looking_at(SIGHT_LINE[g][1] - rear).inverse()
			var at: Vector3 = tb * rear
			eye = at.y
			n.set_meta("eye_x", -at.x)
			n.set_meta("eye_rot", tb.get_euler())
			n.set_meta("eye_z", -float(SIGHT_LINE[g][2]) - at.z)
	n.set_meta("eye", eye)
	if Game.gilded:
		gild(n)
	elif far_tint.a > 0.0:
		gild(n, far_tint)
	return n


## The gilded finish: the gun keeps its own model and is washed over in gold.
## The sheen of the far lands' stuff on the arms made of it.
const FAR_TINT := {"carbine": Color(1.0, 0.72, 0.3, 0.3), "hand_cannon": Color(0.55, 0.52, 0.5, 0.45), "war_pick": Color(0.62, 0.8, 0.95, 0.45)}


static func gild(n: Node, tint := Color(0.95, 0.72, 0.28, 0.6)) -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = tint
	gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gold.metallic = 1.0
	gold.roughness = 0.25
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = gold


## Sights, muzzles and grips from "Free weapon accessories" (Rotten Design, CC-BY 4.0): each part's piece of the
## pack, or {gun: piece} where it differs by gun ("" for the rest). A sight clamps onto the rail (SIGHT_CUT).
const ACC_PATH := "res://assets/models/arms/accessories/accessories.glb"
const ACC := {
	"red_dot": "Sight 1", "reflex": "Sight 2", "holo": "Sight 3", "scope": "Scope 3_001", "combat_scope": "Scope 1",
	"suppressor": {"pistol": "Silencer Mini", "pistol9": "Silencer Mini", "shotgun": "Silencer Shotgun", "sniper": "Silencer 2", "lmg": "Silencer 3", "": "Silencer 1"},
	"heavy_suppressor": "Silencer 4",
	"compensator": {"pistol": "Compensator 1", "pistol9": "Compensator 1", "revolver": "Compensator 1", "shotgun": "Compensator 1", "sniper": "Compensator 3", "lmg": "Compensator 3", "": "Compensator 4"},
	"muzzle_brake": "Compensator 2",
	"flash_hider": {"pistol": "Flashhider", "pistol9": "Flashhider", "revolver": "Flashhider", "": "Flashhider 2"},
	"foregrip": "Cube_001", "angled_grip": "Cube", "slim_grip": "Plane",
}
## How deep the cut in each sight's foot is (the rail's height it takes in), measured from the pack.
const SIGHT_CUT := {"red_dot": 0.008, "reflex": 0.0072, "holo": 0.008, "scope": 0.0068, "combat_scope": 0.0092}
## The guns with a rail along their top.
const RAILED := ["machine_gun"]
## The pack's pieces are not all to one scale: most are a tenth, the grips and rails larger
const ACC_SCALE := {"Cube": 0.25, "Cube_001": 0.26, "Plane": 0.25, "Rail 1": 0.17, "Rail 2": 0.17, "Rail 3": 0.17}
## The height of the highest visible piece of a gun, in its own space.
func _geo_top(n: Node3D) -> float:
	var best := -1.0
	var stack: Array = [[n, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		for c in (it[0] as Node).get_children():
			if not (c is Node3D) or not (c as Node3D).visible:
				continue
			var t: Transform3D = it[1] * (c as Node3D).transform
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				best = maxf(best, (t * (c as MeshInstance3D).mesh.get_aabb()).end.y)
			stack.append([c, t])
	return best


static var _tops := {}
static var _cuts := {}


## Where a straight line through a built gun meets its metal: the line runs across (axis 0) at (y, z), up
## (axis 1) at (x, z), or along the barrel (axis 2) at (x, y). Gives back the nearest and furthest meetings along it, or (9, -9) if none.
## Cached per gun.
func _cut_line(n: Node3D, g: String, axis: int, u: float, w: float) -> Vector2:
	var key := "%s:%d:%.4f:%.4f:%s" % [g, axis, u, w, Game.gilded]
	if _cuts.has(key):
		return _cuts[key]
	var out := Vector2(9.0, -9.0)
	if DisplayServer.get_name() == "headless":
		return out   # no mesh data without a renderer (tests, a server): the drawn guns are not seen there
	var stack: Array = [[n, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		for c in (it[0] as Node).get_children():
			if not (c is Node3D) or not (c as Node3D).visible:
				continue
			var t: Transform3D = it[1] * (c as Node3D).transform
			stack.append([c, t])
			if not (c is MeshInstance3D) or not ((c as MeshInstance3D).mesh is ArrayMesh):
				continue
			var m: ArrayMesh = (c as MeshInstance3D).mesh
			for si in m.get_surface_count():
				var arr: Array = m.surface_get_arrays(si)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var count := ids.size() if ids.size() > 0 else vs.size()
				for i in range(0, count - 2, 3):
					var a := t * vs[ids[i] if ids.size() > 0 else i]
					var b := t * vs[ids[i + 1] if ids.size() > 0 else i + 1]
					var d := t * vs[ids[i + 2] if ids.size() > 0 else i + 2]
					# Into the plane across the line: (p, q) are the two coordinates the line is fixed at
					var pa := _across(a, axis)
					var pb := _across(b, axis)
					var pd := _across(d, axis)
					var q := Vector2(u, w)
					var den := (pb.y - pd.y) * (pa.x - pd.x) + (pd.x - pb.x) * (pa.y - pd.y)
					if absf(den) < 1e-12:
						continue
					var l1 := ((pb.y - pd.y) * (q.x - pd.x) + (pd.x - pb.x) * (q.y - pd.y)) / den
					var l2 := ((pd.y - pa.y) * (q.x - pd.x) + (pa.x - pd.x) * (q.y - pd.y)) / den
					var l3 := 1.0 - l1 - l2
					if l1 < 0.0 or l2 < 0.0 or l3 < 0.0:
						continue
					var h := l1 * a[axis] + l2 * b[axis] + l3 * d[axis]
					out = Vector2(minf(out.x, h), maxf(out.y, h))
	_cuts[key] = out
	return out


static func _across(v: Vector3, axis: int) -> Vector2:
	match axis:
		0:
			return Vector2(v.y, v.z)
		1:
			return Vector2(v.x, v.z)
	return Vector2(v.x, v.y)

## The highest metal of a built gun along its middle between two depths (cached per gun); -1 if none.
func _top_near(n: Node3D, g: String, z0: float, z1: float) -> float:
	var key := "%s:%.3f:%s" % [g, z0, Game.gilded]
	if _tops.has(key):
		return _tops[key]
	var best := -1.0
	var stack: Array = [[n, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		for c in (it[0] as Node).get_children():
			if not (c is Node3D) or not (c as Node3D).visible:
				continue
			var t: Transform3D = it[1] * (c as Node3D).transform
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is ArrayMesh:
				var m: ArrayMesh = (c as MeshInstance3D).mesh
				for si in m.get_surface_count():
					var vs: PackedVector3Array = m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
					for v in vs:
						var w := t * v
						if w.z >= z0 and w.z <= z1 and absf(w.x) < 0.012 and w.y > best:
							best = w.y
			stack.append([c, t])
	_tops[key] = best
	return best


## What a new part looks like when it is drawn in plain shapes (the gilded arms)
const ACC_FAMILY := {"reflex": "red_dot", "holo": "red_dot", "combat_scope": "scope", "heavy_suppressor": "suppressor",
	"compensator": "suppressor", "muzzle_brake": "suppressor", "flash_hider": "suppressor", "angled_grip": "foregrip", "slim_grip": "foregrip"}
static var _acc_inst: Node3D = null


## One piece of the accessories pack, copied into a holder of its own; the holder carries "bb" (its extent)
## and "aim_y" (the height of its reticle or lens, if it has one). Null if the pack is missing.
func _acc_piece(piece: String) -> Node3D:
	if _acc_inst == null:
		if not ResourceLoader.exists(ACC_PATH):
			return null
		_acc_inst = (load(ACC_PATH) as PackedScene).instantiate()
	var src := _acc_inst.find_child(piece, true, false)
	if src == null:
		return null
	var sc: float = ACC_SCALE.get(piece, 0.1)
	var h := Node3D.new()
	var bb := AABB()
	var aim := AABB()
	var first := true
	var has_aim := false
	var plain: StandardMaterial3D = null
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var tr: Transform3D = _chain(mi, _acc_inst)
		tr = Transform3D(tr.basis.scaled(Vector3.ONE * sc), tr.origin * sc)
		var copy := MeshInstance3D.new()
		copy.mesh = (mi as MeshInstance3D).mesh
		copy.transform = tr
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The grips and rails come with no paint; they are given the dark of the gun
		var m0 = copy.mesh.surface_get_material(0)
		if m0 is BaseMaterial3D and (m0 as BaseMaterial3D).albedo_texture == null:
			if plain == null:
				plain = _mat(Color(0.09, 0.09, 0.095), 0.4, 0.55)
			copy.material_override = plain
		h.add_child(copy)
		var a: AABB = tr * copy.mesh.get_aabb()
		if String(mi.name).contains("_Aim_") or String(mi.name).contains("_Material_"):
			aim = a if not has_aim else aim.merge(a)
			has_aim = true
			# A red-dot sight's own reticle is a broad blot: drawn instead as a small, bright dot
			# (a ring round a dot in the holo sight)
			if RETICLE.has(piece):
				copy.visible = false
				var q := MeshInstance3D.new()
				var qm := QuadMesh.new()
				var across: float = maxf(a.size.x, float(RETICLE[piece][1]) * 1.3)
				qm.size = Vector2(across, across)
				q.mesh = qm
				q.position = a.get_center()
				q.material_override = _reticle_mat(piece, across)
				q.set_meta("reticle", [piece, across])
				q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				h.add_child(q)
		bb = a if first else bb.merge(a)
		first = false
	if first:
		h.free()
		return null
	# Its middle at the holder's origin
	for c in h.get_children():
		(c as Node3D).position -= bb.get_center()
	h.set_meta("bb", AABB(bb.position - bb.get_center(), bb.size))
	h.set_meta("aim_y", aim.get_center().y - bb.get_center().y if has_aim else 0.0)
	return h


## Each red-dot sight's reticle: [dot across, ring across (0 for none)], in metres on the glass.
## (Sized for the eye where it sits when aiming, about a forearm behind the glass: a dot a few pixels across.)
const RETICLE := {"Sight 1": [0.0026, 0.0], "Sight 2": [0.0024, 0.0], "Sight 3": [0.0013, 0.012]}
static var _reticles := {}


static func _reticle_mat(piece: String, across: float, over := false) -> StandardMaterial3D:
	var key := "%s:%.5f:%s" % [piece, across, over]
	if _reticles.has(key):
		return _reticles[key]
	var size := 256
	var px := across / size   # metres to a pixel
	var dot_r: float = RETICLE[piece][0] * 0.5 / px
	var ring_r: float = RETICLE[piece][1] * 0.5 / px
	var line := (0.0003 if ring_r > 0.0 else 0.0007) / px
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
			var a := clampf(dot_r + 0.6 - d, 0.0, 1.0)                    # the hard dot
			a = maxf(a, 0.3 * clampf(1.0 - (d - dot_r) / (dot_r * 0.8), 0.0, 1.0))   # a tight glow round it
			if ring_r > 0.0:
				a = maxf(a, clampf(line * 0.5 + 0.6 - absf(d - ring_r), 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = over   # in one's own hands it is lit on the glass: nothing of the sight's own body covers it
	m.render_priority = 10 if over else 0
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.albedo_color = Color(2.4, 0.12, 0.06)
	_reticles[key] = m
	return m


func _acc_name(g: String, m: String) -> String:
	var v = ACC.get(m, "")
	if v is Dictionary:
		return str(v.get(g, v.get("", "")))
	return str(v)


## How far below the top of each scanned gun its own iron sights sit, found by looking down them.
const IRON_DROP := {"pistol": 0.012, "pistol9": 0.012, "revolver": 0.009, "minigun": -0.1}
## How far each gun sits to the side when aimed, so its sights (not its body) are on the eye's line.
const IRON_SIDE := {}
## Guns whose own rear and front sights do not sit on one line along the barrel: [the rear aperture's middle,
## the front hood's middle, how far the eye sits behind the rear], measured on the built model. Down the sights the
## gun is turned so the two line up, and brought close enough that the front shows through the rear's hole.
const SIGHT_LINE := {
	"rocket": [Vector3(0.006, 0.0876, 0.081), Vector3(0.0, 0.078, -0.144), 0.07],
	# The belt gun's battle sight: the notch at the foot of the raised ladder, and the front post's tip
	"lmg": [Vector3(0.0036, 0.0884, -0.0666), Vector3(0.0036, 0.0957, -0.695), 0.28],
	# The rifle's tangent sight: the notch's shoulders level with the top of the front post's bead
	"sniper": [Vector3(-0.0113, 0.0415, -0.2117), Vector3(-0.0112, 0.0389, -0.9428), 0.45],
}


## Sets a sight from the pack on its rail on top of the gun; gives back the height of the eye, or -1.
func _put_sight(n: Node3D, g: String, m: String, top: float, rear_z: float) -> float:
	if not ACC.has(m):
		return -1.0
	var p := _acc_piece(_acc_name(g, m))
	if p == null:
		return -1.0
	var z := rear_z - (0.12 if m in ["scope", "combat_scope"] else 0.08)
	var bb: AABB = p.get_meta("bb")
	n.add_child(p)
	# Its clamp's jaws close round the gun's rail: the cut in its foot takes the rail, so the foot
	# sits down over it (no riser). A gun with no rail has the foot flat on its top.
	var sink: float = SIGHT_CUT.get(m, 0.008) if g in RAILED else 0.0
	p.position = Vector3(0, top - sink + bb.size.y * 0.5, z)
	return p.position.y + float(p.get_meta("aim_y"))


## Fits a muzzle or a grip from the pack; for a muzzle gives back the new mouth of the gun. Null if not.
func _put_acc(n: Node3D, g: String, m: String, tip: Vector3, fore: Vector3):
	if not ACC.has(m):
		return null
	var p := _acc_piece(_acc_name(g, m))
	if p == null:
		return null
	var bb: AABB = p.get_meta("bb")
	n.add_child(p)
	if ArmsDB.ATTACHMENTS[m].slot == "muzzle":
		p.position = Vector3(0, tip.y, tip.z - bb.size.z * 0.5 + 0.02)
		return tip + Vector3(0, 0, -bb.size.z + 0.02)
	p.position = Vector3(0, fore.y - bb.size.y * 0.5 + 0.004, fore.z)
	return fore


## The guns that have a photo-scanned body (Poly Haven, CC0), in assets/models/arms/<name>/:
## [model, turn (degrees), muzzle z, butt z, height of its middle, {part: what it is}]. A part is "pump"
## (the bolt or slide, which works), "mag" (taken out on a reload), "glass" (shown only when a scope is
## fitted) or "off" (left off). The plain-shape gun is built first for where its sights and parts sit.
const SCANNED_GUNS := {
	"sniper": ["bolt_action_rifle_7_62", Vector3(0, 90, 0), -0.975, 0.503, -0.068, {
		"bolt_action_rifle_7_62_bolt_a": "pump", "bolt_action_rifle_7_62_bolt_b": "pump",
		"bolt_action_rifle_7_62_scope": "glass", "bolt_action_rifle_7_62_bullet_54mm": "off"}],
	"pistol": ["service_pistol", Vector3(0, 90, 0), -0.185, 0.045, -0.01, {
		"service_pistol_slide_a": "pump", "service_pistol_magazine_loaded": "off",
		"service_pistol_magazine_empty": "off", "service_pistol_bullet": "off", "service_pistol_pistol_b": "off",
		"service_pistol_slide_b": "off", "service_pistol_hammer_b": "off", "service_pistol_trigger_b": "off"}],
	"pistol9": ["pistol9", Vector3(0, -90, 0), -0.19, 0.04, -0.01, {}],
	"machine_gun": ["hk416", Vector3(0, 90, 0), -0.695, 0.432, -0.05, {}],
	"lmg": ["m60", Vector3(0, 90, 0), -0.82, 0.45, -0.03, {
		"Object_4": "off", "Object_5": "off", "Object_7": "off", "Object_9": "off", "Object_11": "off", "Object_12": "off",
		"Object_13": "off", "Object_15": "off", "Object_16": "off", "Object_17": "off", "Object_18": "off",
		"Object_44": "off", "Object_46": "off", "Object_48": "off", "Object_22": "pump", "Object_28": "pump"}],
	"flamer": ["flamer", Vector3(0, 180, 0), -0.5, 0.36, 0.03, {}],
	"rocket": ["rpg", Vector3(0, -90, 0), -0.66, 0.52, 0.0, {}],
	"minigun": ["minigun", Vector3(0, 180, 0), -0.68, 0.3, -0.02, {
		"barrels_minigun_0": "spin", "mag_minigun_0": "mag", "bullet_minigun_0": "off", "Object_70": "off", "arms_arms_0": "off"}],
	"shotgun": ["mossberg500", Vector3(0, -90, 0), -0.75, 0.5, -0.02, {}],
	"revolver": ["colt_saa", Vector3(0, 90, 0), -0.26, 0.09, -0.01, {}],
}


## A part's place within the model it came from, through every node between.
static func _chain(mi: Node, top: Node) -> Transform3D:
	var tr: Transform3D = (mi as Node3D).transform
	var p: Node = mi.get_parent()
	while p and p != top:
		tr = (p as Node3D).transform * tr
		p = p.get_parent()
	return (top as Node3D).transform * tr if top is Node3D else tr


## Swaps the plain shapes of a gun for its scanned body, keeping its working parts working.
## Gives back the height of its top (where a fitted sight sits), or -1 if it has no scanned body.
func _scan_gun(g: String, n: Node3D, fit: Array) -> float:
	if not SCANNED_GUNS.has(g):
		return -1.0
	var sg: Array = SCANNED_GUNS[g]
	var path := "res://assets/models/arms/%s/%s.gltf" % [sg[0], sg[0]]
	if not ResourceLoader.exists(path):
		path = path.get_basename() + ".glb"
	if not ResourceLoader.exists(path):
		return -1.0
	var pump: Node3D = n.get_meta("pump")
	var mag: Node3D = n.get_meta("mag") if n.has_meta("mag") else null
	for holder in [n, pump, mag]:
		if holder == null:
			continue
		for c in holder.get_children():
			if c is MeshInstance3D:
				c.free()
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	var roles: Dictionary = sg[5]
	var pivot := Node3D.new()
	pivot.rotation_degrees = sg[1]
	pivot.add_child(inst)
	# Its extent as the gun sees it, the glass and what is left off not counted
	var bb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var role: String = roles.get(mi.name, "")
		if role == "off":
			continue
		if role == "glass":
			continue
		var a: AABB = pivot.transform * _chain(mi, inst) * (mi as MeshInstance3D).get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	var sc := (float(sg[3]) - float(sg[2])) / maxf(bb.size.z, 0.001)
	var off := Vector3(-bb.get_center().x * sc, float(sg[4]) - bb.get_center().y * sc, float(sg[2]) - bb.position.z * sc)
	var glass: bool = built_glass(g, fit)
	var copy_mat := {}
	# The glass is lifted to where the eye looks through it
	var gbb := AABB()
	var gfirst := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if roles.get(mi.name, "") == "glass":
			var a: AABB = pivot.transform * _chain(mi, inst) * (mi as MeshInstance3D).get_aabb()
			gbb = a if gfirst else gbb.merge(a)
			gfirst = false
	if not gfirst:
		n.set_meta("glass_y", gbb.get_center().y * sc + off.y)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var role: String = roles.get(mi.name, "")
		if role == "off" or (role == "glass" and not glass):
			continue
		var tr: Transform3D = pivot.transform * _chain(mi, inst)
		tr = Transform3D(tr.basis.scaled(Vector3.ONE * sc), tr.origin * sc + off)
		if (mi as MeshInstance3D).material_override:
			copy_mat[mi] = (mi as MeshInstance3D).material_override
		var holder: Node3D = n
		if role == "pump" or role == "spin":
			holder = pump
		elif role == "mag" and mag != null:
			holder = mag
		var copy := MeshInstance3D.new()
		copy.mesh = (mi as MeshInstance3D).mesh
		copy.material_override = copy_mat.get(mi)
		copy.transform = tr
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.set_meta("src", String(mi.name))
		holder.add_child(copy)
	_carve_parts(g, n, {"pump": pump, "mag": mag})
	# What spins (a minigun's barrels) turns about its own middle: the pump is moved there
	var spun: Array = pump.get_children().filter(func(c): return c is MeshInstance3D)
	var spin_bb := AABB()
	var sfirst := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if roles.get(mi.name, "") == "spin":
			var a: AABB = pivot.transform * _chain(mi, inst) * (mi as MeshInstance3D).get_aabb()
			spin_bb = a if sfirst else spin_bb.merge(a)
			sfirst = false
	if not sfirst:
		var axis := Vector3(spin_bb.get_center().x * sc + off.x, spin_bb.get_center().y * sc + off.y, 0.0)
		pump.position = axis
		for c in spun:
			(c as Node3D).position -= axis
	inst.free()
	return bb.end.y * sc + off.y


## Parts cut out of a scan that came as one piece, so they can move: [role, min corner, max corner, from
## which piece ("" any)], in the built gun's own metres (z toward the butt, y up). A triangle goes with the
## part when its middle is in a box. A pump's forend is cut around its tube, so the tube stays whole.
const CARVE := {
	"shotgun": [["pump", Vector3(0.017, 0.0, -0.49), Vector3(0.045, 0.068, -0.24), ""],
		["pump", Vector3(-0.045, 0.0, -0.49), Vector3(-0.017, 0.068, -0.24), ""],
		["pump", Vector3(-0.017, 0.052, -0.49), Vector3(0.017, 0.066, -0.24), ""],
		["pump", Vector3(-0.017, -0.005, -0.49), Vector3(0.017, 0.018, -0.24), ""]],
	"machine_gun": [["mag", Vector3(-0.05, -0.22, -0.125), Vector3(0.05, -0.042, 0.005), ""]],
	"pistol9": [["pump", Vector3(-0.05, 0.032, -0.21), Vector3(0.05, 0.08, 0.04), "Cube_005_9m2_0"],
		["mag", Vector3(-0.05, -0.1, -0.05), Vector3(0.05, 0.031, 0.06), "Cube_005_9m2_0"]],
	"rocket": [["pump", Vector3(-0.08, -0.03, -0.72), Vector3(0.08, 0.1, -0.175), ""]],
}
static var _carved := {}


## Cuts a scan's moving parts out of its one piece and hands them to the pump or the magazine.
func _carve_parts(g: String, n: Node3D, holders: Dictionary) -> void:
	if not CARVE.has(g):
		return
	var by_role := {}
	for c in CARVE[g]:
		if not by_role.has(c[0]):
			by_role[c[0]] = []
		by_role[c[0]].append(c)
	for role in by_role:
		var holder: Node3D = holders.get(role)
		if holder == null:
			continue
		for c in n.get_children():
			if not (c is MeshInstance3D) or not c.has_meta("src"):
				continue
			var mi := c as MeshInstance3D
			var boxes: Array = by_role[role].filter(func(b): return b[3] == "" or b[3] == mi.get_meta("src"))
			if boxes.is_empty():
				continue
			var key := "%s:%s:%d" % [g, role, mi.mesh.get_instance_id()]
			if not _carved.has(key):
				_carved[key] = _split_mesh(mi.mesh, mi.transform, boxes)
			var pair: Array = _carved[key]
			if pair[0] == null:
				continue
			mi.mesh = pair[1]
			var part := MeshInstance3D.new()
			part.mesh = pair[0]
			part.transform = mi.transform
			part.material_override = mi.material_override
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(part)
		if role == "mag" and g in MAG_FILL:
			_mag_fill(holder)


## Scans whose magazine is only its two side walls (the grip hid the rest): filled in, so it is not hollow when it drops.
const MAG_FILL := ["pistol9"]

## A dark body between a carved magazine's side walls, leaning with them.
func _mag_fill(holder: Node3D) -> void:
	var pts := PackedVector3Array()
	for c in holder.get_children():
		if not (c is MeshInstance3D):
			continue
		var mi := c as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for i in idx:
				pts.append(mi.transform * vs[i])
	if pts.size() < 6:
		return
	var wide := 0.0
	for v in pts:
		wide = maxf(wide, absf(v.x))
	# The walls are what stands furthest out to each side
	var wall := PackedVector3Array()
	for v in pts:
		if absf(v.x) > wide * 0.8:
			wall.append(v)
	# Their lean: z against y, fitted
	var my := 0.0
	var mz := 0.0
	for v in wall:
		my += v.y
		mz += v.z
	my /= wall.size()
	mz /= wall.size()
	var syy := 0.0
	var syz := 0.0
	for v in wall:
		syy += (v.y - my) * (v.y - my)
		syz += (v.y - my) * (v.z - mz)
	var lean := syz / maxf(syy, 0.000001)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var zs: Array = []
	for v in wall:
		var u := Vector3(absf(v.x), v.y, v.z - lean * v.y)
		lo = lo.min(u)
		hi = hi.max(u)
		zs.append(u.z)
	# The walls curve: the body keeps to their middle, so no corner shows through the grip
	zs.sort()
	lo.z = zs[int(zs.size() * 0.2)]
	hi.z = zs[int(zs.size() * 0.8)]
	var x := lo.x - 0.0004   # just inside the walls
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corner := func(sx: float, y: float, z: float) -> Vector3: return Vector3(sx * x, y, z + lean * y)
	var c8: Array = []
	for sx in [-1.0, 1.0]:
		for y in [lo.y, hi.y]:
			for z in [lo.z, hi.z]:
				c8.append(corner.call(sx, y, z))
	# (index = sx*4 + y*2 + z)
	for q in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		for t in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			for i in t:
				st.add_vertex(c8[i])
	st.generate_normals()
	var body := MeshInstance3D.new()
	body.mesh = st.commit()
	var m := _mat(Color(0.035, 0.035, 0.04), 0.2, 0.55)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	body.material_override = m
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(body)


## A mesh split in two by boxes (seen through tr): [what is inside or null, what is left].
static func _split_mesh(mesh: Mesh, tr: Transform3D, boxes: Array) -> Array:
	var inside := ArrayMesh.new()
	var outside := ArrayMesh.new()
	var any := false
	for si in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(vs.size())
			for i in vs.size():
				idx[i] = i
		var a_in := PackedInt32Array()
		var a_out := PackedInt32Array()
		for t in range(0, idx.size() - 2, 3):
			var mid: Vector3 = tr * ((vs[idx[t]] + vs[idx[t + 1]] + vs[idx[t + 2]]) / 3.0)
			var hit := false
			for b in boxes:
				var lo: Vector3 = b[1]
				var hi: Vector3 = b[2]
				if mid.x >= lo.x and mid.x <= hi.x and mid.y >= lo.y and mid.y <= hi.y and mid.z >= lo.z and mid.z <= hi.z:
					hit = true
					break
			if hit:
				a_in.append_array([idx[t], idx[t + 1], idx[t + 2]])
			else:
				a_out.append_array([idx[t], idx[t + 1], idx[t + 2]])
		var mat := mesh.surface_get_material(si)
		for pr in [[inside, a_in], [outside, a_out]]:
			if (pr[1] as PackedInt32Array).is_empty():
				continue
			var a2 := arr.duplicate()
			a2[Mesh.ARRAY_INDEX] = pr[1]
			for ci in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
				a2[ci] = null   # what a gun scan does not use, and what will not go back in without its format
			(pr[0] as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
			(pr[0] as ArrayMesh).surface_set_material((pr[0] as ArrayMesh).get_surface_count() - 1, mat)
		if not a_in.is_empty():
			any = true
	return [inside if any else null, outside]


## Where the stock ends and where the side of the action is, per gun, for the waste's own parts.
## The middle of each gun's butt plate, and how tall it is (measured off the scanned bodies).
const BUTT := {"shotgun": Vector3(0, -0.054, 0.5), "machine_gun": Vector3(0, -0.003, 0.432), "lmg": Vector3(0, -0.029, 0.45), "sniper": Vector3(0, -0.109, 0.503)}
const BUTT_H := {"shotgun": 0.16, "machine_gun": 0.16, "lmg": 0.17, "sniper": 0.13}
## The middle of each scanned gun's mouth, read off side views of it.
const SCAN_TIP := {"shotgun": Vector3(0, 0.0725, -0.743), "machine_gun": Vector3(0, 0.056, -0.695), "lmg": Vector3(0, 0.0, -0.82),
	"sniper": Vector3(0, 0.0145, -0.975), "rocket": Vector3(0, 0.026, -0.66), "minigun": Vector3(0, -0.1, -0.68),
	"flamer": Vector3(0.009, -0.0125, -0.483), "pistol": Vector3(0, 0.04, -0.185), "pistol9": Vector3(0, 0.047, -0.19),
	"revolver": Vector3(0, 0.051, -0.26)}
## Where a receiver's side plates go (x is found from the gun's own side).
const SIDE := {"shotgun": Vector3(0.027, 0.055, -0.02), "machine_gun": Vector3(0.026, 0.05, 0.03), "lmg": Vector3(0.03, 0.02, 0.0), "sniper": Vector3(0.024, 0.006, 0.02),
	"rocket": Vector3(0.045, 0.026, -0.05), "minigun": Vector3(0.066, -0.09, 0.12), "pistol": Vector3(0.014, 0.036, -0.07), "pistol9": Vector3(0.016, 0.05, -0.08),
	"revolver": Vector3(0.02, 0.045, -0.035)}


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
				if ArmsDB.GUNS[g].slot == "secondary":
					# A side arm's heavy barrel: a thick stub out past the slide
					_tube(0.0125, 0.05, tip + Vector3(0, 0, -0.022), dark, n)
					for i in 2:
						_tube(0.0135, 0.005, tip + Vector3(0, 0, -0.012 - i * 0.022), metal, n)
					tip += Vector3(0, 0, -0.045)
					at = tip + Vector3(0, 0.012, 0.03)
				else:
					var r := 0.06 if g == "minigun" else 0.021
					_tube(r, 0.22, tip + Vector3(0, 0, 0.12), dark, n)
					for i in 4:
						_tube(r + 0.002, 0.008, tip + Vector3(0, 0, 0.05 + i * 0.045), metal, n)
					at = tip + Vector3(0, r, 0.22)
			"padded_stock", "light_stock", "heavy_stock":
				var b: Vector3 = BUTT.get(g, Vector3(0, -0.04, 0.45))
				var bh: float = BUTT_H.get(g, 0.12)
				# The stock a hand's width before the butt: its top, its bottom and its sides
				var sz := b.z - 0.05
				var ud := _cut_line(n, g, 1, 0.0, sz)
				if ud.x > 8.0:
					ud = Vector2(b.y - bh * 0.4, b.y + bh * 0.4)
				var sd := _cut_line(n, g, 0, (ud.x + ud.y) * 0.5, sz)
				var half := sd.y if sd.y > -8.0 else 0.022
				match m:
					"padded_stock":
						# A pad over the butt plate, pressed onto it
						_box(Vector3(half * 2.0 + 0.006, bh * 0.92, 0.026), b + Vector3(0, 0, 0.01), _mat(Color(0.32, 0.16, 0.1), 0.0, 0.9), n)
					"light_stock":
						# Bent rod along both sides of the stock, round a thin plate on the butt
						for sx in [-1, 1]:
							for ry in [0.25, 0.75]:
								_box(Vector3(0.006, 0.006, 0.09), Vector3(sx * (half + 0.003), lerpf(ud.x, ud.y, ry), b.z - 0.04), metal, n)
						_box(Vector3(half * 2.0 + 0.012, bh * 0.85, 0.008), b + Vector3(0, 0, 0.008), metal, n)
					"heavy_stock":
						# Solid wood: cheeks on both sides of the stock and a thick wooden heel
						var wood := _mat(Color(0.22, 0.12, 0.07), 0.0, 0.6)
						for sx in [-1, 1]:
							_box(Vector3(0.006, (ud.y - ud.x) * 0.7, 0.09), Vector3(sx * (half + 0.003), (ud.x + ud.y) * 0.5, b.z - 0.04), wood, n)
						_box(Vector3(half * 2.0 + 0.012, bh * 0.95, 0.03), b + Vector3(0, 0, 0.012), wood, n)
				at = Vector3(half + 0.002, (ud.x + ud.y) * 0.5, sz)
			"rapid_receiver", "heavy_receiver", "smooth_receiver":
				var sd: Vector3 = SIDE.get(g, Vector3(0.026, 0, 0.03))
				var c: Color = {"rapid_receiver": Color(0.12, 0.16, 0.28), "heavy_receiver": Color(0.7, 0.55, 0.3), "smooth_receiver": Color(0.8, 0.8, 0.82)}[m]
				var size := Vector3(0.003, 0.014, 0.045) if ArmsDB.GUNS[g].slot == "secondary" else Vector3(0.003, 0.026, 0.09)
				# Laid flat on the receiver's own side
				for sx in [-1, 1]:
					var w := _cut_line(n, g, 0, sd.y, sd.z)
					var x := (w.y if sx > 0 else -w.x) if w.y > -8.0 else sd.x
					_box(size, Vector3(sx * (x + 0.0015), sd.y, sd.z), _mat(c, 0.85, 0.3), n)
				at = sd + Vector3(0.003, size.y * 0.5 + 0.003, 0)
		var gr := WArms.grade_of(a, g, m) if Game.wasteland else {}
		var r := int(gr.get("r", 0))
		if r > 0:
			var glow := _mat(WArms.GRADES[r].color)
			glow.emission_enabled = true
			glow.emission = WArms.GRADES[r].color
			glow.emission_energy_multiplier = 0.6 + r * 0.3
			_box(Vector3(0.012, 0.006, 0.03), at, glow, n)
	n.set_meta("tip_after", tip)


## The melee arms as photo-scanned models (Poly Haven, CC0), in assets/models/arms/<name>/:
## [model, turn (degrees), where the grip ends, whole length, parts to leave off, haft off the middle
## (an axe's head hangs to one side, so its haft is not the middle of it)]. Handle at the
## hand (the origin), the head up along +Y, the edge to -Z, as the plain-shape arms are built.
## Thrown things whose model lies on its side: turned upright first
const THROWN_TURN := {"flare": Vector3(90, 0, 0), "molotov": Vector3.ZERO}
const SCANNED_MELEE := {
	"hatchet": ["hatchet", Vector3(0, 180, 0), -0.09, 0.44, [], -0.04],
	"machete": ["machete", Vector3(0, 180, 0), -0.08, 0.64, [], 0.0],
	"sledge": ["sledgehammer_01", Vector3(0, 90, 0), -0.1, 0.66, [], 0.0],
	"knife": ["ornate_medieval_dagger", Vector3(0, 90, 0), -0.06, 0.3, ["ornate_medieval_dagger_scabbard"], 0.0],
	"sword": ["wooden_handle_saber", Vector3(0, 180, 0), -0.1, 0.92, [], 0.0],
	"battle_axe": ["wooden_axe", Vector3(0, 180, 0), -0.14, 0.8, [], -0.1],
	"glaive": ["glaive", Vector3(0, 180, 0), -0.75, 2.0, ["Circle_003"], 0.0],
}


## A scanned model fitted to the hand: turned, then grown or shrunk to the length, its grip end at grip_y.
static func scanned(key: String, turn: Vector3, grip_y: float, length: float, leave := [], haft_z := 0.0) -> Node3D:
	var path := "res://assets/models/arms/%s/%s.gltf" % [key, key]
	if not ResourceLoader.exists(path):
		path = path.get_basename() + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	for nm in leave:
		var off := inst.find_child(nm, true, false)
		if off:
			off.free()
	var pivot := Node3D.new()
	pivot.rotation_degrees = turn
	pivot.add_child(inst)
	# Its extent, as the pivot sees it
	var bb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var tr: Transform3D = (mi as Node3D).transform
		var p: Node = mi.get_parent()
		while p and p != pivot:
			tr = (p as Node3D).transform * tr
			p = p.get_parent()
		var a: AABB = pivot.transform * (tr * (mi as MeshInstance3D).get_aabb())
		bb = a if first else bb.merge(a)
		first = false
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var n := Node3D.new()
	n.add_child(pivot)
	var sc := length / maxf(bb.size.y, 0.001)
	pivot.scale = Vector3.ONE * sc
	pivot.rotation_degrees = turn
	var c := bb.get_center()
	pivot.position = Vector3(-c.x * sc, grip_y - bb.position.y * sc, -c.z * sc + haft_z)
	return n


func _build_melee(id: String) -> Node3D:
	var far_tint: Color = FAR_TINT.get(id, Color(0, 0, 0, 0))
	id = ArmsDB.look(id)
	if SCANNED_MELEE.has(id):
		var sm: Array = SCANNED_MELEE[id]
		var sn := scanned(sm[0], sm[1], sm[2], sm[3], sm[4], sm[5])
		if sn:
			if far_tint.a > 0.0:
				gild(sn, far_tint)
			return sn
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
		"knife":
			_box(Vector3(0.026, 0.1, 0.03), Vector3(0, 0.0, 0), wood, n)
			_box(Vector3(0.04, 0.012, 0.05), Vector3(0, 0.055, 0), steel, n)
			_box(Vector3(0.005, 0.18, 0.03), Vector3(0, 0.15, -0.004), steel, n)
		"sword":
			_box(Vector3(0.028, 0.14, 0.032), Vector3(0, 0.0, 0), _mat(Color(0.22, 0.15, 0.1)), n)
			_box(Vector3(0.034, 0.03, 0.034), Vector3(0, -0.08, 0), steel, n)
			_box(Vector3(0.03, 0.02, 0.17), Vector3(0, 0.08, 0), steel, n)
			_box(Vector3(0.007, 0.72, 0.042), Vector3(0, 0.45, 0), steel, n)
		"glaive":
			var glass := _mat(Color(0.06, 0.05, 0.08), 0.6, 0.15)
			_box(Vector3(0.032, 0.95, 0.032), Vector3(0, 0.3, 0), wood, n)
			_box(Vector3(0.04, 0.03, 0.04), Vector3(0, 0.78, 0), steel, n)
			_box(Vector3(0.012, 0.32, 0.07), Vector3(0, 0.95, -0.015), glass, n)
		"battle_axe":
			_box(Vector3(0.035, 0.78, 0.035), Vector3(0, 0.25, 0), wood, n)
			_box(Vector3(0.014, 0.2, 0.2), Vector3(0, 0.55, -0.1), steel, n)
			_box(Vector3(0.014, 0.12, 0.06), Vector3(0, 0.55, 0.05), steel, n)
	return n


# ================================================================== things that fly

## A rocket: falls slowly as it flies (aim a little high far off), and bursts on whatever it meets.
## Only the shooter's rocket does harm; the copies the fellowship sees are only shown.
class Rocket extends Node3D:
	const DROP := 1.8   ## how fast it falls, m/s each second: about 1.5 m low at 50 m, 6 m at 100 m
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
		if owner_player and is_instance_valid(owner_player) and owner_player is CollisionObject3D:
			q.exclude = [owner_player.get_rid()]
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty() or _life <= 0.0:
			var at: Vector3 = r.position if not r.is_empty() else to
			if not shown_only:
				Arms.blast(get_parent(), at, radius, dmg, owner_player)
			queue_free()
			return
		global_position = to
		vel.y -= DROP * delta
		if vel.length() > 0.01:
			look_at(global_position + vel, Vector3.UP if absf(vel.normalized().y) < 0.99 else Vector3.RIGHT)


## A round in flight: beyond close range a shot is not instant. It flies straight at its gun's speed,
## shown by a faint streak, and does its harm where it lands, with the same falloff and head shots.
class Slug extends Node3D:
	var arms: Node = null
	var shooter: Node = null
	var gun_id := ""
	var origin := Vector3.ZERO
	var dir := Vector3.FORWARD
	var speed := 340.0
	var left := 100.0
	var dmg := 10.0
	var falloff := 0.0
	var crit := 1.0
	var pierce := 1.0
	var harm := "bullet"
	var grav := 0.0   ## how fast it falls (m/s each second); the shot's first NEAR metres are counted as flown
	var vel := Vector3.ZERO

	func _ready() -> void:
		var t0 := Arms.NEAR / maxf(speed, 1.0)
		vel = dir * speed + Vector3.DOWN * grav * t0
		global_position += Vector3.DOWN * 0.5 * grav * t0 * t0
		var streak := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.025, 0.025, 1.6)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.85, 0.55, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.material = m
		streak.mesh = bm
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streak.position = Vector3(0, 0, 0.8)
		add_child(streak)
		look_at(global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)

	func _physics_process(delta: float) -> void:
		if grav > 0.0:
			vel.y -= grav * delta
			dir = vel.normalized()
			look_at(global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
		var step := minf(vel.length() * delta, left)
		left -= step
		var from := global_position
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * step, 1 | 2)
		if shooter and is_instance_valid(shooter) and shooter is CollisionObject3D:
			q.exclude = [shooter.get_rid()]
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if r.is_empty():
			global_position = from + dir * step
			if left <= 0.0:
				queue_free()
			return
		_land(r)
		queue_free()

	func _land(r: Dictionary) -> void:
		var target = r.collider
		var lvl := get_parent()
		var fall := 1.0
		if falloff > 0.0:
			fall = clampf(1.4 - origin.distance_to(r.position) / falloff, 0.35, 1.0)
		var d := dmg * fall
		var crits := {}
		if target and target.has_method("weak_point"):
			var wp: Array = target.weak_point()
			if not wp.is_empty() and Arms._ray_near(global_position, dir, wp[0], wp[1] * 1.15):
				d *= Arms.HEAD_MULT * crit
				crits[target] = true
		if not (target and target.has_method("hurt")):
			if lvl.has_method("puff"):
				lvl.puff(r.position, r.normal)
			return
		var hits := {target: d}
		if "hits" in lvl:
			lvl.hits += 1
		LesserSpeeb.harm_pierce = pierce
		Arms.deal(hits, dir, harm, crits)
		LesserSpeeb.harm_pierce = 1.0
		if arms and is_instance_valid(arms):
			arms._impact_sounds(hits)
			arms._practise(gun_id, hits)


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
		# Scanned bodies: the stick grenade (Poly Haven, CC0); the molotov, flare and mine (CC-BY, see CREDITS.md)
		var look: Array = {"grenade": ["stick_grenade", -0.13, 0.26], "fire": ["molotov", -0.13, 0.26],
			"flare": ["flare", -0.1, 0.2], "mine": ["landmine", -0.035, 0.07]}.get(kind, [])
		if not look.is_empty():
			var sg := Arms.scanned(look[0], Arms.THROWN_TURN.get(look[0], Vector3.ZERO), look[1], look[2])
			if sg:
				add_child(sg)
				if kind == "flare":
					# Its burning end still glows
					var tipm := MeshInstance3D.new()
					var sp := SphereMesh.new()
					sp.radius = 0.02
					sp.height = 0.04
					tipm.mesh = sp
					tipm.material_override = m
					tipm.position.y = -0.1
					add_child(tipm)
				return
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
	static func burn(lvl: Node, at: Vector3, radius: float, dps: float, secs: float, real: bool, quiet := false) -> void:
		var root := Node3D.new()
		lvl.add_child(root)
		root.global_position = at
		if not quiet:
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
