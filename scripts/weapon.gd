class_name Shotgun
extends Node3D
## Brelm's pump shotgun. Eight pellets, a pump between each shot, shells loaded one at a time.

const PELLETS := 8
const SPREAD := 0.075
const RANGE := 45.0
const DAMAGE := 11.0
const CAPACITY := 6
const PUMP_TIME := 0.7
const SHELL_TIME := 0.45

var player: Player
var shells := CAPACITY
var reserve := 24
var _cool := 0.0
var _reloading := false
var _reload_t := 0.0
var _kick := 0.0
var _pump: Node3D
var _model: Node3D
var _flash: OmniLight3D
var _flash_mesh: MeshInstance3D
var _sway := Vector2.ZERO
var enabled := true


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.12, 0.13)
	metal.metallic = 0.8
	metal.roughness = 0.35
	if Game.gilded:
		metal.albedo_color = Color(0.85, 0.66, 0.3)
		metal.metallic = 1.0
		metal.roughness = 0.22
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.2, 0.12)
	wood.roughness = 0.6
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.7, 0.55, 0.3)
	brass.metallic = 0.9
	brass.roughness = 0.3
	_part(BoxMesh, Vector3(0.07, 0.09, 0.32), Vector3(0, 0, 0.05), metal, _model)
	_tube(0.022, 0.62, Vector3(0, 0.025, -0.4), metal, _model)
	_tube(0.018, 0.5, Vector3(0, -0.025, -0.34), metal, _model)
	_part(BoxMesh, Vector3(0.055, 0.09, 0.2), Vector3(0, -0.035, 0.29), wood, _model).rotation.x = -0.18
	_part(BoxMesh, Vector3(0.012, 0.014, 0.012), Vector3(0, 0.044, -0.7), brass, _model)
	_part(BoxMesh, Vector3(0.074, 0.03, 0.12), Vector3(0, -0.035, 0.12), brass, _model)
	_pump = Node3D.new()
	_model.add_child(_pump)
	_part(BoxMesh, Vector3(0.06, 0.06, 0.17), Vector3(0, -0.03, -0.3), wood, _pump)
	# A paw-glyph burned into the stock
	var glyph := StandardMaterial3D.new()
	glyph.albedo_color = Color(0.1, 0.06, 0.04)
	for p in [[Vector3(0.031, -0.03, 0.34), 0.018], [Vector3(0.031, 0.0, 0.31), 0.007], [Vector3(0.031, 0.006, 0.33), 0.007], [Vector3(0.031, 0.006, 0.35), 0.007], [Vector3(0.031, 0.0, 0.37), 0.007]]:
		var m := _part(CylinderMesh, Vector3.ZERO, p[0], glyph, _model)
		(m.mesh as CylinderMesh).top_radius = p[1]
		(m.mesh as CylinderMesh).bottom_radius = p[1]
		(m.mesh as CylinderMesh).height = 0.004
		m.rotation.z = PI / 2
	_flash = OmniLight3D.new()
	_flash.position = Vector3(0, 0.03, -0.8)
	_flash.light_color = Color(1.0, 0.8, 0.5)
	_flash.light_energy = 0.0
	_flash.omni_range = 7
	_model.add_child(_flash)
	_flash_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	_flash_mesh.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.85, 0.5)
	_flash_mesh.material_override = fm
	_flash_mesh.position = Vector3(0, 0.03, -0.75)
	_flash_mesh.visible = false
	_model.add_child(_flash_mesh)
	for c in _model.find_children("*", "MeshInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(0.16, -0.19, -0.5)
	rotation = Vector3(0.02, 0.05, 0)
	_ui()


func _part(kind, size: Vector3, pos: Vector3, m: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh = kind.new()
	if mesh is BoxMesh:
		mesh.size = size
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _tube(r: float, length: float, pos: Vector3, m: Material, parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = length
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation.x = PI / 2
	parent.add_child(mi)


func _unhandled_input(e: InputEvent) -> void:
	if not enabled or player.input_locked or get_tree().paused:
		return
	if e.is_action_pressed("reload") and shells < CAPACITY and reserve > 0:
		_reloading = true
		_reload_t = SHELL_TIME


func _process(delta: float) -> void:
	visible = enabled and not (player.input_locked and player.get_parent().completed)
	if not enabled:
		return
	_cool = maxf(0.0, _cool - delta)
	_kick = move_toward(_kick, 0.0, delta * 4.0)
	# Pump travel follows the cooldown after a shot
	var pump_phase := 0.0
	if _cool > 0.0:
		pump_phase = sin(clampf(1.0 - _cool / PUMP_TIME, 0.0, 1.0) * PI)
	_pump.position.z = pump_phase * 0.1
	var bob := sin(Time.get_ticks_msec() * 0.008) * 0.006 * clampf(player.cur_speed / 3.0, 0.0, 1.5)
	_sway = _sway.lerp(Vector2.ZERO, delta * 8.0)
	_model.position = Vector3(_sway.x, bob - _kick * 0.04 + _sway.y, _kick * 0.12)
	_model.rotation.x = _kick * 0.35
	if _reloading:
		_model.rotation.z = lerpf(_model.rotation.z, 0.5, delta * 8.0)
		_reload_t -= delta
		if _reload_t <= 0.0 and reserve <= 0:
			_reloading = false
		elif _reload_t <= 0.0:
			shells += 1
			reserve -= 1
			_ui()
			player.get_parent().sfx("shell", -6)
			_reload_t = SHELL_TIME * (0.65 if Game.blessed("speebchef") else 1.0)
			if shells >= CAPACITY:
				_reloading = false
				player.get_parent().sfx("pump", -4)
	else:
		_model.rotation.z = lerpf(_model.rotation.z, 0.0, delta * 8.0)
	if Input.is_action_pressed("fire") and not player.input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		_try_fire()


func _ui() -> void:
	if enabled:
		Game.main.hud.set_ammo(shells, CAPACITY, reserve)


func add_shells(n: int) -> void:
	reserve = mini(reserve + n, 48)
	_ui()


func sway(rel: Vector2) -> void:
	_sway += Vector2(-rel.x, rel.y) * 0.00012


func _try_fire() -> void:
	if _cool > 0.0:
		return
	if shells <= 0:
		if reserve <= 0:
			if _cool <= 0.0:
				_cool = 0.5
				player.get_parent().sfx("shell", -14)
			return
		if not _reloading:
			_reloading = true
			_reload_t = SHELL_TIME
		return
	if _reloading:
		_reloading = false
		_cool = 0.25
		return
	shells -= 1
	_ui()
	player.shake(0.18)
	_cool = PUMP_TIME
	_kick = 1.0
	player.pitch = minf(player.pitch + 0.045, 1.45)
	var lvl = player.get_parent()
	lvl.sfx("shotgun", -2)
	get_tree().create_timer(0.3, false).timeout.connect(func(): lvl.sfx("pump", -8))
	_flash.light_energy = 4.0
	_flash_mesh.visible = true
	_flash_mesh.rotation.z = randf() * TAU
	get_tree().create_timer(0.05, false).timeout.connect(func():
		_flash.light_energy = 0.0
		_flash_mesh.visible = false)
	var cam := player.cam
	var space := get_world_3d().direct_space_state
	var origin := cam.global_position
	var hits := {}
	for i in PELLETS:
		var dir := -cam.global_transform.basis.z
		dir = dir.rotated(cam.global_transform.basis.x, randf_range(-SPREAD, SPREAD) * 0.7)
		dir = dir.rotated(cam.global_transform.basis.y, randf_range(-SPREAD, SPREAD))
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * RANGE, 1 | 2)
		q.exclude = [player.get_rid()]
		q.collide_with_areas = false
		var r := space.intersect_ray(q)
		if r.is_empty():
			continue
		var target = r.collider
		var dist := origin.distance_to(r.position)
		var dmg := DAMAGE * clampf(1.4 - dist / 25.0, 0.35, 1.0) * (1.3 if Game.blessed("speebsnek") else 1.0)
		if target and target.has_method("hurt"):
			hits[target] = hits.get(target, 0.0) + dmg
		else:
			lvl.puff(r.position, r.normal)
	var marked := 0
	for t in hits:
		if is_instance_valid(t):
			var full: bool = t.hurt(hits[t], -cam.global_transform.basis.z)
			var killed: bool = not t.is_alive()
			marked = maxi(marked, 2 if killed else (1 if full else 0))
			if not full and not killed:
				Game.main.hud.notify("The gilded face turns the shot aside. Strike it from the side.")
	lvl.shots += 1
	if not hits.is_empty():
		lvl.hits += 1
	if marked > 0:
		Game.main.hud.hitmarker(marked == 2)
