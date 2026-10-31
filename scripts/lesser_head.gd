class_name LesserHead
extends Node3D
## The head of a hostile lesser form. Its emoji is worn as a bright mask, shown whole and unlit so it is
## always readable; behind it a gaunt cat skull of shadow, and a ring of red thorns where a halo would be.

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
	if frames > 1:
		_mask_mat.set_shader_parameter("frame", float(int(_t * fps) % frames))
	_thorns.rotation.z += delta * 0.6
	_mask_mat.set_shader_parameter("flash", _flash)


func set_flash(v: float) -> void:
	_flash = v
	if _skull_mat:
		_skull_mat.emission_energy_multiplier = 0.35 + v * 3.0


## The gilded idols: a skull of gold metal, and a mask that turns shot aside.
func set_gild(v: float) -> void:
	if _skull_mat and v > 0.0:
		_skull_mat.albedo_color = Color(0.85, 0.66, 0.3)
		_skull_mat.metallic = 0.9
		_skull_mat.roughness = 0.3


func set_menace(_v: float) -> void:
	pass
