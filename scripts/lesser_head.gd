class_name LesserHead
extends Node3D
## The head of a hostile lesser form. By default it is flesh: a cat's head in its own coat, with lit eyes,
## bared fangs and whiskers. In the older style (Options: Lesser forms, Masks) its emoji is worn as a bright
## mask over a gaunt skull of shadow. Either way a ring of red thorns hangs where a halo would be.

static var _skull: ArrayMesh

var code := ""
var size := 1.0
var fur := Color(0.8, 0.8, 0.8)
var frames := 1
var fps := 10.0
var _t := 0.0
var _mask_mat: ShaderMaterial
var _skull_mat: StandardMaterial3D
var _thorns: Node3D
var _flash := 0.0
var _fur_mat: ShaderMaterial
var _jaw: Node3D


func setup(c: String, s := 1.0) -> LesserHead:
	code = c
	size = s
	return self


func _ready() -> void:
	var tex: Texture2D = load("res://assets/emoji/%s.png" % code)
	var m: Dictionary = Game.meta.get(code, {"frames": 1, "fps": 10})
	frames = int(m.frames)
	fps = float(m.fps)
	fur = Emoji3D._fur(code, tex)
	if _skull == null:
		_skull = Emoji3D._build_head()
	if Game.forms_style == 0:
		_build_flesh()
	else:
		_build_mask(tex)
	_build_thorns()


## A cat's head, as near to living as plain shapes allow. Its coat follows the colours of its emoji.
func _build_flesh() -> void:
	var h := absi(code.hash())
	var s := size
	_fur_mat = ShaderMaterial.new()
	_fur_mat.shader = preload("res://scripts/fur.gdshader")
	var coat := fur
	# A coat a cat could have: the emoji's colour, pulled toward the browns, greys and blacks of real fur
	var real_coats := [Color(0.55, 0.36, 0.2), Color(0.42, 0.4, 0.38), Color(0.12, 0.11, 0.1), Color(0.78, 0.74, 0.68), Color(0.6, 0.45, 0.3)]
	coat = coat.lerp(real_coats[h % real_coats.size()], 0.85)
	coat = Color.from_hsv(coat.h, coat.s * 0.55, coat.v * 0.8)
	_fur_mat.set_shader_parameter("base_color", coat)
	_fur_mat.set_shader_parameter("mark_color", coat.darkened(0.6))
	_fur_mat.set_shader_parameter("belly_color", coat.lightened(0.5))
	_fur_mat.set_shader_parameter("pattern", float(h % 3))
	_fur_mat.set_shader_parameter("seed", float(h % 997))
	var skull := MeshInstance3D.new()
	skull.mesh = _skull
	skull.material_override = _fur_mat
	skull.scale = Vector3.ONE * s * Vector3(1.0, 1.0, 0.92)
	add_child(skull)
	var pink := _m(Color(0.62, 0.36, 0.36), 0.6)
	var dark := _m(Color(0.04, 0.03, 0.03), 0.5)
	var bone := _m(Color(0.92, 0.9, 0.82), 0.3)
	# Muzzle pads and chin, in the same coat
	for sx in [-1.0, 1.0]:
		_ball(0.085 * s, Vector3(sx * 0.065, -0.13, 0.28) * s, _fur_mat, Vector3(1.0, 0.8, 0.9))
	_ball(0.07 * s, Vector3(0, -0.2, 0.24) * s, _fur_mat, Vector3(1.1, 0.7, 1.0))
	# Nose
	_ball(0.035 * s, Vector3(0, -0.075, 0.345) * s, pink, Vector3(1.3, 0.8, 0.8))
	# Eyes: lit from within, with a slit of black
	var eye_col: Color = [Color(1.0, 0.75, 0.15), Color(0.6, 0.9, 0.2), Color(1.0, 0.35, 0.1)][h % 3]
	var eye := StandardMaterial3D.new()
	eye.albedo_color = eye_col
	eye.emission_enabled = true
	eye.emission = eye_col
	eye.emission_energy_multiplier = 1.4
	eye.roughness = 0.05
	eye.metallic_specular = 1.0
	for sx in [-1.0, 1.0]:
		var e := _ball(0.05 * s, Vector3(sx * 0.125, 0.03, 0.275) * s, eye, Vector3(1.3, 0.62, 0.6))
		e.rotation.z = sx * 0.3
		var pupil := _ball(0.05 * s, Vector3(sx * 0.125, 0.03, 0.292) * s, dark, Vector3(0.16, 0.66, 0.5))
		pupil.rotation.z = sx * 0.3
		# A heavy brow, drawn down over each eye
		var brow := _ball(0.085 * s, Vector3(sx * 0.115, 0.085, 0.25) * s, _fur_mat, Vector3(1.25, 0.42, 0.7))
		brow.rotation.z = -sx * 0.5
		# The inside of the ear
		var ear := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.11 * s
		cm.height = 0.24 * s
		cm.radial_segments = 8
		ear.mesh = cm
		ear.material_override = pink
		ear.position = Vector3(sx * 0.25, 0.4, 0.06) * s
		ear.rotation.z = -sx * 0.38
		ear.scale = Vector3(1, 1, 0.3)
		add_child(ear)
		# Whiskers
		for k in 3:
			var wk := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.32 * s, 0.004 * s, 0.004 * s)
			wk.mesh = bm
			wk.material_override = bone
			wk.position = Vector3(sx * 0.2, -0.13 - k * 0.025, 0.3) * s
			wk.rotation = Vector3(0, -sx * 0.25, sx * (0.1 - k * 0.12))
			wk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(wk)
	# The jaw, half open, and the fangs
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.18, 0.22) * s
	add_child(_jaw)
	var maw := MeshInstance3D.new()
	var mbm := BoxMesh.new()
	mbm.size = Vector3(0.12, 0.03, 0.08) * s
	maw.mesh = mbm
	maw.material_override = _m(Color(0.25, 0.03, 0.04), 0.6)
	maw.position = Vector3(0, 0, 0.05) * s
	_jaw.add_child(maw)
	for sx in [-1.0, 1.0]:
		var f := MeshInstance3D.new()
		var fc := CylinderMesh.new()
		fc.top_radius = 0.012 * s
		fc.bottom_radius = 0.0
		fc.height = 0.07 * s
		fc.radial_segments = 6
		f.mesh = fc
		f.material_override = bone
		f.position = Vector3(sx * 0.04, 0.0, 0.1) * s
		_jaw.add_child(f)


func _m(c: Color, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _ball(r: float, pos: Vector3, m: Material, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = sc
	add_child(mi)
	return mi


func _build_mask(tex: Texture2D) -> void:
	# The skull: dark fur touched by the form's own colour, rimmed in red
	var skull := MeshInstance3D.new()
	skull.mesh = _skull
	_skull_mat = StandardMaterial3D.new()
	_skull_mat.albedo_color = fur.darkened(0.82)
	_skull_mat.roughness = 0.85
	_skull_mat.rim_enabled = true
	_skull_mat.rim = 1.0
	_skull_mat.rim_tint = 0.0
	_skull_mat.emission_enabled = true
	_skull_mat.emission = Color(0.5, 0.03, 0.02)
	_skull_mat.emission_energy_multiplier = 0.35
	skull.material_override = _skull_mat
	skull.scale = Vector3.ONE * size * Vector3(1.0, 1.0, 0.85)
	add_child(skull)
	# The mask: the emoji itself, whole and unlit, a little proud of the face
	var mask := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * 0.9 * size
	mask.mesh = qm
	_mask_mat = ShaderMaterial.new()
	_mask_mat.shader = preload("res://scripts/mask.gdshader")
	_mask_mat.set_shader_parameter("face_tex", tex)
	_mask_mat.set_shader_parameter("frames", float(frames))
	mask.material_override = _mask_mat
	mask.position = Vector3(0, 0.0, 0.37) * size
	mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mask)


func _build_thorns() -> void:
	# The thorn ring, behind the head where the collected forms wear gold
	_thorns = Node3D.new()
	_thorns.position = Vector3(0, 0.0, 0.3) * size
	add_child(_thorns)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.1, 0.05)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.44 * size
	tm.outer_radius = 0.49 * size
	ring.mesh = tm
	ring.material_override = red
	ring.rotation.x = PI / 2
	_thorns.add_child(ring)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.035 * size
	cone.height = 0.16 * size
	cone.radial_segments = 6
	cone.rings = 1
	for i in 12:
		var a := TAU * i / 12.0
		var th := MeshInstance3D.new()
		th.mesh = cone
		th.material_override = red
		th.position = Vector3(cos(a), sin(a), 0) * 0.54 * size
		th.rotation.z = a - PI / 2
		th.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_thorns.add_child(th)


func _process(delta: float) -> void:
	_t += delta
	if _mask_mat:
		if frames > 1:
			_mask_mat.set_shader_parameter("frame", float(int(_t * fps) % frames))
		_mask_mat.set_shader_parameter("flash", _flash)
	_thorns.rotation.z += delta * 0.6
	if _jaw:
		_jaw.rotation.x = 0.25 + sin(_t * 3.0) * 0.12 + _flash * 0.4


func set_flash(v: float) -> void:
	_flash = v
	if _fur_mat:
		_fur_mat.set_shader_parameter("flash", v)
	if _skull_mat:
		_skull_mat.emission_energy_multiplier = 0.35 + v * 3.0


## The gilded idols: a skull of gold metal, and a mask that turns shot aside.
func set_gild(v: float) -> void:
	if _fur_mat:
		_fur_mat.set_shader_parameter("gild", v)
	if _skull_mat and v > 0.0:
		_skull_mat.albedo_color = Color(0.85, 0.66, 0.3)
		_skull_mat.metallic = 0.9
		_skull_mat.roughness = 0.3


func set_menace(_v: float) -> void:
	pass
