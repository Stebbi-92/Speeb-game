class_name Relics
extends Node3D
## What Brelm carries: the hotbar of relics, their viewmodels, and what each does when used.
## The shotgun keeps its own script; this chooses when it is in hand.

const HANDS_RANGE := 45.0
const HANDS_CONE := 0.82
const CLAW_RANGE := 34.0
const CENSER_REACH := 10.0

var player: Player
var slot := 0
var faith := 1.0
var lantern_lit := false
var censer_lit := false
var _models := {}
var _lamp: OmniLight3D
var _smoke: CPUParticles3D
var _halo: MeshInstance3D
var _hands_glow: StandardMaterial3D
var _censer_bowl: Node3D
var _rope: MeshInstance3D
var _grapple_to = null
var _swing := 0.0
var _raise := 0.0
var _cool := 0.0


func _ready() -> void:
	_models["hands"] = _build_hands()
	_models["lantern"] = _build_lantern()
	_models["claw"] = _build_claw()
	_models["censer"] = _build_censer()
	_models["milk"] = _build_milk()
	for k in _models:
		var m: Node3D = _models[k]
		m.visible = false
		add_child(m)
		for c in m.find_children("*", "MeshInstance3D", true, false):
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.78, 0.5)
	_lamp.light_energy = 0.0
	_lamp.omni_range = 15.0
	_lamp.shadow_enabled = true
	_lamp.position = Vector3(-0.3, -0.2, -0.3)
	add_child(_lamp)
	_smoke = CPUParticles3D.new()
	_smoke.emitting = false
	_smoke.amount = 60
	_smoke.lifetime = 4.0
	_smoke.local_coords = false
	_smoke.direction = Vector3(0, 1, 0)
	_smoke.spread = 60.0
	_smoke.initial_velocity_min = 0.3
	_smoke.initial_velocity_max = 0.9
	_smoke.gravity = Vector3(0, 0.25, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.6, 2.0))
	curve.add_point(Vector2(1, 0.0))
	_smoke.scale_amount_curve = curve
	var qm := QuadMesh.new()
	qm.size = Vector2(0.6, 0.6)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_color = Color(0.86, 0.84, 0.8, 0.3)
	sm.albedo_texture = _soft_dot()
	_smoke.mesh = qm
	_smoke.material_override = sm
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.5
	_smoke.position = Vector3(0.1, -0.5, -1.4)
	add_child(_smoke)


static func _soft_dot() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	return ImageTexture.create_from_image(img)


func _mat(c: Color, metal := 0.0, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _mesh(mesh: Mesh, m: Material, pos: Vector3, parent: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _box(size: Vector3, m: Material, pos: Vector3, parent: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, m, pos, parent, rot)


func _cyl(r: float, h: float, m: Material, pos: Vector3, parent: Node3D, rot := Vector3.ZERO, top := -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = h
	return _mesh(c, m, pos, parent, rot)


## Two hands pressed together in prayer, a halo kindling above them as faith gathers.
func _build_hands() -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(0.0, -0.3, -0.55)
	n.scale = Vector3.ONE * 0.8
	var skin := _mat(Color(0.86, 0.7, 0.58), 0.0, 0.7)
	var robe := _mat(Color(0.3, 0.27, 0.24), 0.0, 0.95)
	for side in [-1.0, 1.0]:
		var palm := _box(Vector3(0.022, 0.13, 0.085), skin, Vector3(side * 0.012, 0.06, 0), n, Vector3(0, 0, -side * 0.08))
		for f in 4:
			_box(Vector3(0.02, 0.075, 0.018), skin, Vector3(0, 0.095, -0.03 + f * 0.02), palm, Vector3(0, 0, 0))
		_box(Vector3(0.018, 0.06, 0.02), skin, Vector3(side * 0.012, 0.02, 0.05), palm, Vector3(-0.5, 0, 0))
		_cyl(0.045, 0.16, robe, Vector3(side * 0.05, -0.06, 0.04), n, Vector3(0.35, 0, -side * 0.5))
	_hands_glow = StandardMaterial3D.new()
	_hands_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hands_glow.albedo_color = Color(1.0, 0.85, 0.45)
	_halo = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.04
	tm.outer_radius = 0.048
	_halo.mesh = tm
	_halo.material_override = _hands_glow
	_halo.position = Vector3(0, 0.22, 0)
	_halo.rotation.x = 0.35
	n.add_child(_halo)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.5)
	l.light_energy = 0.6
	l.omni_range = 1.2
	l.position = Vector3(0, 0.15, 0)
	l.name = "glow"
	n.add_child(l)
	return n


func _build_lantern() -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(-0.2, -0.3, -0.5)
	n.scale = Vector3.ONE * 0.6
	var iron := _mat(Color(0.14, 0.13, 0.12), 0.8, 0.4)
	_cyl(0.06, 0.02, iron, Vector3(0, 0, 0), n)
	_cyl(0.06, 0.02, iron, Vector3(0, 0.16, 0), n)
	_cyl(0.02, 0.05, iron, Vector3(0, 0.19, 0), n, Vector3.ZERO, 0.004)
	for k in 4:
		var a := k * TAU / 4.0
		_box(Vector3(0.008, 0.16, 0.008), iron, Vector3(cos(a) * 0.055, 0.08, sin(a) * 0.055), n)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.9, 0.7, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cyl(0.05, 0.14, glass, Vector3(0, 0.08, 0), n)
	var flame := StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Color(1.0, 0.7, 0.3)
	var fm := SphereMesh.new()
	fm.radius = 0.018
	fm.height = 0.05
	var f := _mesh(fm, flame, Vector3(0, 0.07, 0), n)
	f.name = "flame"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.03
	ring.outer_radius = 0.038
	_mesh(ring, iron, Vector3(0, 0.23, 0), n, Vector3(PI / 2, 0, 0))
	return n


func _build_claw() -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(0.2, -0.22, -0.5)
	var brass := _mat(Color(0.62, 0.48, 0.26), 0.9, 0.35)
	var wood := _mat(Color(0.3, 0.2, 0.12), 0.0, 0.7)
	_cyl(0.016, 0.14, wood, Vector3(0, 0, 0.0), n, Vector3(PI / 2, 0, 0))
	_cyl(0.026, 0.04, brass, Vector3(0, 0, -0.08), n, Vector3(PI / 2, 0, 0))
	for k in 3:
		var a := k * TAU / 3.0
		var prong := Node3D.new()
		prong.position = Vector3(0, 0, -0.1)
		prong.rotation = Vector3(0, 0, a)
		n.add_child(prong)
		_box(Vector3(0.012, 0.012, 0.07), brass, Vector3(0, 0.025, -0.03), prong, Vector3(-0.5, 0, 0))
		_box(Vector3(0.012, 0.012, 0.04), brass, Vector3(0, 0.035, -0.075), prong, Vector3(0.9, 0, 0))
	return n


func _build_censer() -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(0.16, -0.08, -0.48)
	var brass := _mat(Color(0.6, 0.46, 0.24), 0.9, 0.35)
	_censer_bowl = Node3D.new()
	n.add_child(_censer_bowl)
	_cyl(0.003, 0.16, brass, Vector3(0, -0.08, 0), _censer_bowl)
	var bowl := SphereMesh.new()
	bowl.radius = 0.045
	bowl.height = 0.08
	_mesh(bowl, brass, Vector3(0, -0.18, 0), _censer_bowl)
	_cyl(0.02, 0.03, brass, Vector3(0, -0.13, 0), _censer_bowl, Vector3.ZERO, 0.008)
	var ember := StandardMaterial3D.new()
	ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember.albedo_color = Color(0.3, 0.1, 0.05)
	var em := SphereMesh.new()
	em.radius = 0.02
	em.height = 0.02
	var e := _mesh(em, ember, Vector3(0, -0.15, 0), _censer_bowl)
	e.name = "ember"
	return n


func _build_milk() -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(0.0, -0.22, -0.4)
	var clay := _mat(Color(0.55, 0.38, 0.26), 0.0, 0.85)
	_cyl(0.05, 0.05, clay, Vector3.ZERO, n, Vector3.ZERO, 0.075)
	var milk := _mat(Color(0.96, 0.95, 0.92), 0.0, 0.3)
	_cyl(0.068, 0.005, milk, Vector3(0, 0.02, 0), n)
	return n


func current() -> String:
	return Game.RELICS[slot]


func select(i: int) -> void:
	if i < 0 or i >= Game.RELICS.size() or not Game.has_relic(Game.RELICS[i]):
		return
	if i == 0 and slot == 0 and player.armed and player.weapon:
		player.weapon.swap()     # pressing 1 again changes between the primary and secondary gun
		return
	if i != slot:
		_raise = 1.0
	slot = i
	refresh()


func refresh() -> void:
	var armed: bool = player.armed
	if not Game.has_relic(current()):
		slot = 0
	if player.weapon:
		player.weapon.enabled = armed and slot == 0
		if player.weapon.enabled:
			player.weapon._ui()
	if not (armed and slot == 0):
		Game.main.hud.set_ammo(-1, 0)
	for k in _models:
		_models[k].visible = armed and current() == k
	Game.main.hud.set_hotbar(slot if armed else -1, faith, Game.milk)


func _unhandled_input(e: InputEvent) -> void:
	if not player.armed or player.input_locked or get_tree().paused:
		return
	for i in Game.RELICS.size():
		if e.is_action_pressed("slot_%d" % (i + 1)):
			select(i)
			return
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var dir := 0
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dir = 1
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			dir = -1
		if dir != 0:
			var i := slot
			for n in Game.RELICS.size():
				i = posmod(i + dir, Game.RELICS.size())
				if Game.has_relic(Game.RELICS[i]):
					select(i)
					return


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	_raise = move_toward(_raise, 0.0, delta * 4.0)
	var lvl = player.get_parent()
	var hiding: bool = player.input_locked and lvl.completed
	for k in _models:
		var m: Node3D = _models[k]
		if m.visible:
			m.position.y = _base_y(k) - _raise * 0.25 - (0.4 if hiding else 0.0)
	# The lantern burns while carried lit, whatever is in hand
	_lamp.light_energy = lerpf(_lamp.light_energy, 2.6 if lantern_lit else 0.0, delta * 6.0)
	_lamp.light_energy *= 1.0 + sin(Time.get_ticks_msec() * 0.023) * 0.02
	var flame: MeshInstance3D = _models["lantern"].get_node("flame")
	flame.visible = lantern_lit
	# The halo brightens as faith gathers
	_halo.scale = Vector3.ONE * (0.3 + 0.7 * faith)
	_hands_glow.albedo_color = Color(1.0, 0.85, 0.45) * (0.4 + 0.8 * faith) if faith < 1.0 else Color(1.0, 0.92, 0.6) * (1.2 + 0.3 * sin(Time.get_ticks_msec() * 0.006))
	(_models["hands"].get_node("glow") as OmniLight3D).light_energy = 0.2 + faith * 0.8
	# The censer swings; lit, it smokes and shows the hidden
	var burning: bool = censer_lit and current() == "censer" and player.armed
	_swing += delta * (3.2 if burning else 1.4)
	_censer_bowl.rotation.x = sin(_swing) * (0.45 if burning else 0.12)
	_censer_bowl.rotation.z = cos(_swing * 0.7) * 0.08
	_smoke.emitting = burning
	var ember: MeshInstance3D = _censer_bowl.get_node("ember")
	(ember.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.45, 0.15) if burning else Color(0.3, 0.1, 0.05)
	if burning and lvl.has_method("cense"):
		lvl.cense(player.global_position, CENSER_REACH)
	_grapple_rope()
	if not player.armed or player.input_locked or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Game.main.hud.set_relic_hint("")
		return
	var hint := ""
	match current():
		"claw":
			hint = "[LMB]  Cast the claw" if _find_anchor() != null else ""
		"hands":
			hint = "[LMB]  Pray" if faith >= 1.0 else "Faith gathers as the lesser forms are undone"
		"lantern":
			hint = "[LMB]  " + ("Quench the lantern" if lantern_lit else "Light the lantern")
		"censer":
			hint = "[LMB]  " + ("Quench the censer" if censer_lit else "Light the censer")
		"milk":
			hint = "[LMB]  Drink  (%d)" % Game.milk
	Game.main.hud.set_relic_hint(hint)
	if Input.is_action_just_pressed("fire") and _cool <= 0.0:
		_use(lvl)


func _base_y(k: String) -> float:
	return {"hands": -0.3, "lantern": -0.3, "claw": -0.22, "censer": -0.08, "milk": -0.22}[k]


func _use(lvl) -> void:
	_cool = 0.3
	match current():
		"hands":
			if faith >= 1.0:
				_pray(lvl)
			else:
				lvl.sfx("shell", -14)
		"lantern":
			lantern_lit = not lantern_lit
			lvl.sfx("lantern", -4)
		"censer":
			censer_lit = not censer_lit
			lvl.sfx("censer" if censer_lit else "lantern", -4)
		"claw":
			var a = _find_anchor()
			if a == null:
				Game.main.hud.notify("The claw finds no ring of iron to hold.")
				lvl.sfx("shell", -12)
			else:
				_grapple_to = a
				lvl.sfx("grapple", -2)
				player.grapple(a.get_meta("landing"))
				Game.reveal_deed("claw")
		"milk":
			if Game.milk <= 0:
				return
			if player.health >= player.max_health:
				Game.main.hud.notify("Brelm is not wounded. He keeps the milk.")
				return
			Game.milk -= 1
			Game.save()
			player.health = minf(player.max_health, player.health + 55.0)
			Game.main.hud.set_health(player.health / player.max_health, lvl.combat)
			lvl.sfx("drink", -2)
			Game.reveal_deed("milk")
			_raise = 1.0
			if Game.milk <= 0:
				select(0)
			refresh()


## The nearest ring of iron near the line of sight, with nothing in the way.
func _find_anchor():
	var lvl = player.get_parent()
	if not "anchors" in lvl:
		return null
	var cam := player.cam
	var fwd := -cam.global_transform.basis.z
	var best = null
	var best_dot := cos(deg_to_rad(9.0))
	for a in lvl.anchors:
		var to: Vector3 = a.global_position - cam.global_position
		if to.length() > CLAW_RANGE:
			continue
		var d := fwd.dot(to.normalized())
		if d < best_dot:
			continue
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, a.global_position, 1)
		q.exclude = [player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		best = a
		best_dot = d
	return best


func _grapple_rope() -> void:
	if _grapple_to == null or not player.grappling:
		if _rope:
			_rope.visible = false
		_grapple_to = null if not player.grappling else _grapple_to
		return
	if _rope == null:
		_rope = MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.012
		c.bottom_radius = 0.012
		c.height = 1.0
		_rope.mesh = c
		_rope.material_override = _mat(Color(0.35, 0.3, 0.22), 0.6, 0.5)
		player.get_parent().add_child(_rope)
	var from: Vector3 = _models["claw"].global_position
	var to: Vector3 = _grapple_to.global_position
	_rope.visible = true
	var mid := (from + to) * 0.5
	var len := from.distance_to(to)
	_rope.global_transform = Transform3D(Basis(), mid)
	_rope.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	_rope.rotate_object_local(Vector3.RIGHT, PI / 2)
	_rope.scale = Vector3(1, len, 1)


## The Praying Hands: a blast of tiny haloed Speebs pours forth, and every hostile form before Brelm is undone.
func _pray(lvl) -> void:
	faith = 0.0
	refresh()
	Game.reveal_deed("pray")
	player.shake(0.8)
	lvl.sfx("choir", 2)
	Game.main.hud.set_fx("flash", 0.55)
	var tw := create_tween()
	tw.tween_method(func(v): Game.main.hud.set_fx("flash", v), 0.55, 0.0, 1.2)
	var cam := player.cam
	var origin: Vector3 = _models["hands"].global_position + Vector3(0, 0.15, 0)
	var fwd := -cam.global_transform.basis.z
	var basis_x := cam.global_transform.basis.x
	var basis_y := cam.global_transform.basis.y
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color(1.0, 0.86, 0.45)
	Net.fx("pray", origin, fwd)
	for i in 40:
		var a := randf() * TAU
		var r := sqrt(randf()) * 0.55
		var dir := (fwd + basis_x * cos(a) * r + basis_y * sin(a) * r * 0.7).normalized()
		_cherub(lvl, origin, dir, gold, randf() * 0.25)
	var slain := 0
	for e in lvl.enemies.duplicate():
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var to: Vector3 = e.global_position - cam.global_position
		var dist := to.length()
		if dist < 7.0 or (dist < HANDS_RANGE and fwd.dot(to / dist) > HANDS_CONE):
			var delay := 0.35 + dist / 24.0
			slain += 1
			get_tree().create_timer(delay, false).timeout.connect(func():
				if is_instance_valid(e) and e.is_alive():
					lvl.burst(e.global_position, Color(1.0, 0.9, 0.6))
					e.hurt(100000.0, fwd))
	if slain >= 5:
		Game.reveal_deed("pray5")
	if slain > 0:
		get_tree().create_timer(0.5, false).timeout.connect(func(): Game.main.hud.hitmarker(true))


func _cherub(lvl, origin: Vector3, dir: Vector3, gold: Material, delay: float) -> void:
	var c := Node3D.new()
	var head := Emoji3D.new().setup("_speeb", 0.45)
	head.glow = 0.6
	c.add_child(head)
	var halo := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.13
	tm.outer_radius = 0.16
	tm.rings = 12
	tm.ring_segments = 6
	halo.mesh = tm
	halo.material_override = gold
	halo.position.y = 0.33
	c.add_child(halo)
	c.scale = Vector3.ONE * 0.01
	lvl.add_child(c)
	origin += dir * 2.0
	c.global_position = origin
	c.look_at(origin + dir, Vector3.UP)
	var end := origin + dir * randf_range(26.0, HANDS_RANGE)
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "scale", Vector3.ONE, 0.35)
	tw.parallel().tween_property(c, "global_position", end, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(c.queue_free)


func add_faith(v: float) -> void:
	var was := faith
	faith = minf(1.0, faith + v)
	if was < 1.0 and faith >= 1.0:
		Game.main.hud.notify("The Praying Hands are ready. [2]")
		player.get_parent().sfx("bell", -12)
	Game.main.hud.set_hotbar(slot if player.armed else -1, faith, Game.milk)
