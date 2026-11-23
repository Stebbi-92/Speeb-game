class_name WSmoke
extends Node3D
## A cigarette, lit and left to burn while you keep at whatever you are doing: building, fighting, walking.
## It sits at the corner of your mouth, its lit end just in sight below; smoke rises off it, and now and
## then you draw on it (the end glows) and let the smoke go. It burns down on its own.
## "Cigarette packs" (Noah, CC-BY 4.0) gives the cigarette.

const PATH := "res://assets/models/items/cigarettes/cigarettes.glb"
const BURN := 180.0      ## seconds one lasts
const DRAW_EVERY := 11.0 ## seconds between draws on it
const LENGTH := 0.084    ## a cigarette's length, in metres
## Where it sits, from the eye: the filter at the corner of the mouth, the lit end before it and to the right,
## just peeking in at the foot of the view
const MOUTH := Vector3(0.025, -0.1, -0.06)
const TIP := Vector3(0.06, -0.08, -0.15)

var lit := false
var left := 0.0
var player: Node3D
var _cig: Node3D        ## the cigarette, turned so its own length runs along -Z from the filter
var _len_node: Node3D
var _ember: MeshInstance3D
var _ember_mat: StandardMaterial3D
var _glow: OmniLight3D
var _rise: GPUParticles3D
var _breath: GPUParticles3D
var _draw_t := 0.0
var _drawing := 0.0     ## 0..1 while drawing on it


func _ready() -> void:
	visible = false
	_len_node = Node3D.new()
	add_child(_len_node)
	_cig = _make_cig()
	_len_node.add_child(_cig)
	_ember_mat = StandardMaterial3D.new()
	_ember_mat.albedo_color = Color(0.25, 0.08, 0.03)
	_ember_mat.emission_enabled = true
	_ember_mat.emission = Color(1.0, 0.35, 0.08)
	_ember_mat.emission_energy_multiplier = 1.5
	_ember = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.0042
	s.height = 0.006
	_ember.mesh = s
	_ember.material_override = _ember_mat
	_ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ember)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.45, 0.15)
	_glow.omni_range = 0.5
	_glow.light_energy = 0.15
	_glow.shadow_enabled = false
	add_child(_glow)
	_rise = _smoke(18, 4.0, 0.022, false)
	add_child(_rise)
	_breath = _smoke(26, 2.6, 0.045, true)
	add_child(_breath)


## The cigarette from the pack's model, its filter at the origin and its length along -Z, a cigarette's size.
func _make_cig() -> Node3D:
	var holder := Node3D.new()
	if not ResourceLoader.exists(PATH):
		return holder
	var inst: Node3D = (load(PATH) as PackedScene).instantiate()
	var cig: Node3D = null
	for c in inst.find_children("*", "Node3D", true, false):
		if String(c.name).begins_with("cigarette"):
			cig = c
			break
	if cig == null:
		inst.free()
		return holder
	# Its pieces, where they sit in the model, and which end the filter is
	var parts := []
	var bb := AABB()
	var first := true
	var filt := Vector3.ZERO
	for mi in cig.find_children("*", "MeshInstance3D", true, false):
		var tr := Arms._chain(mi, inst)
		var a: AABB = tr * (mi as MeshInstance3D).get_aabb()
		bb = a if first else bb.merge(a)
		first = false
		if String(mi.name).contains("filter"):
			filt = a.get_center()
		parts.append([(mi as MeshInstance3D).mesh, tr, (mi as MeshInstance3D).get_active_material(0)])
	var axis := 0
	for i in 3:
		if bb.size[i] > bb.size[axis]:
			axis = i
	var along := Vector3.ZERO
	along[axis] = 1.0
	var c := bb.get_center()
	if (filt - c).dot(along) > 0.0:
		along = -along   # from the filter toward the lit end
	var filter_end: Vector3 = c - along * bb.size[axis] * 0.5
	var sc := LENGTH / maxf(bb.size[axis], 0.0001)
	var turn := Basis(Quaternion(along, Vector3(0, 0, -1)))
	for p in parts:
		var m := MeshInstance3D.new()
		m.mesh = p[0]
		m.material_override = p[2]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tr: Transform3D = p[1]
		m.transform = Transform3D(turn.scaled(Vector3.ONE * sc) * tr.basis, turn * ((tr.origin - filter_end) * sc))
		holder.add_child(m)
	inst.free()
	return holder


## Soft grey smoke: a slow rising thread, or a breath let out (a short burst, forward and up).
func _smoke(n: int, life: float, size: float, breath: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.local_coords = false   # it stays where it was let out as you walk on
	p.one_shot = breath
	p.explosiveness = 0.85 if breath else 0.0
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0.4, -1) if breath else Vector3(0, 1, 0)
	m.spread = 22.0 if breath else 8.0
	m.initial_velocity_min = 0.35 if breath else 0.03
	m.initial_velocity_max = 0.6 if breath else 0.08
	m.gravity = Vector3(0, 0.12, 0)
	m.damping_min = 0.4
	m.damping_max = 0.8
	m.scale_min = 0.8
	m.scale_max = 1.3
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.3))
	grow.add_point(Vector2(1, 3.0 if breath else 4.0))
	var gt := CurveTexture.new()
	gt.curve = grow
	m.scale_curve = gt
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.8, 0.8, 0.82, 0.0))
	ramp.set_color(1, Color(0.75, 0.75, 0.78, 0.0))
	ramp.add_point(0.12, Color(0.82, 0.82, 0.85, 0.32 if breath else 0.22))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	m.color_ramp = rt
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 2.0
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var soft := GradientTexture2D.new()
	soft.gradient = g
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	soft.width = 64
	soft.height = 64
	mat.albedo_texture = soft
	q.material = mat
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Lights one: it burns for BURN seconds.
func light(who: Node3D = null) -> void:
	player = who
	lit = true
	left = BURN
	_draw_t = 2.0
	visible = true
	_rise.emitting = true


## Puts it out at once (its end flicked away).
func put_out() -> void:
	lit = false
	_rise.emitting = false
	visible = false


func _process(delta: float) -> void:
	if not lit:
		return
	left -= delta
	if left <= 0.0:
		put_out()
		return
	# It burns down: the lit end comes back toward the mouth
	var burnt := 1.0 - left / BURN
	var length := lerpf(1.0, 0.45, burnt)
	var dir := (TIP - MOUTH).normalized()
	_len_node.transform = Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis.from_scale(Vector3(1, 1, length)), MOUTH)
	var tip := MOUTH + dir * LENGTH * length
	_ember.position = tip
	_glow.position = tip
	_rise.position = tip
	_breath.position = MOUTH + Vector3(0, 0.0, -0.03)
	# Now and then a draw on it: the end glows, and a moment later the smoke is let go
	_draw_t -= delta
	if _draw_t <= 0.0:
		_draw_t = DRAW_EVERY + randf_range(-2.0, 2.0)
		_drawing = 1.0
	if _drawing > 0.0:
		var was := _drawing
		_drawing = maxf(0.0, _drawing - delta / 2.2)
		if was > 0.25 and _drawing <= 0.25:
			_breath.restart()
			_breath.emitting = true
	var glow := 1.0 + 2.5 * sin(clampf(1.0 - _drawing, 0.0, 1.0) * PI) * float(_drawing > 0.0)
	_ember_mat.emission_energy_multiplier = 1.5 * glow
	_glow.light_energy = 0.12 * glow
	# Out of the way down the sights
	var arms = player.get("weapon") if player else null
	var aiming: bool = arms != null and float(arms.get("_aim")) > 0.3
	_len_node.visible = not aiming
	_ember.visible = not aiming
