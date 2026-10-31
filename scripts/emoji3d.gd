class_name Emoji3D
extends Node3D
## A form of Speeb given body: a 3D cat head, its face the emoji itself, its fur the emoji's own colour.
## Animated emojis (frame strips) play across the face.

static var _mesh: ArrayMesh
static var _fur_cache := {}

var code := ""
var size := 1.0
var spin := 0.0
var bob := 0.0
var glow := 0.08
var face_target: Node3D

var frames := 1
var fps := 10.0
var _t := 0.0
var _frame := -1
var _mat: ShaderMaterial
var _base_y := 0.0
var _head: MeshInstance3D


func setup(c: String, s := 1.0, _d := -1.0) -> Emoji3D:
	code = c
	size = s
	return self


func _ready() -> void:
	var tex: Texture2D = load("res://assets/emoji/%s.png" % code)
	var m: Dictionary = Game.meta.get(code, {"frames": 1, "fps": 10})
	frames = int(m.frames)
	fps = float(m.fps)
	if _mesh == null:
		_mesh = _build_head()
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://scripts/cathead.gdshader")
	_mat.set_shader_parameter("face_tex", tex)
	_mat.set_shader_parameter("frames", float(frames))
	_mat.set_shader_parameter("fur", _fur(code, tex))
	_mat.set_shader_parameter("glow", glow)
	_head = MeshInstance3D.new()
	_head.mesh = _mesh
	_head.material_override = _mat
	_head.scale = Vector3.ONE * size
	add_child(_head)
	_base_y = position.y
	_set_frame(0)


func set_glow(v: float) -> void:
	glow = v
	if _mat:
		_mat.set_shader_parameter("glow", v)


func set_gild(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("gild", v)


func set_menace(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("menace", v)


func set_flash(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("hit_flash", v)


func _set_frame(f: int) -> void:
	if f == _frame:
		return
	_frame = f
	_mat.set_shader_parameter("frame", float(f))


func _process(delta: float) -> void:
	_t += delta
	if frames > 1:
		_set_frame(int(_t * fps) % frames)
	if spin != 0.0:
		rotate_y(spin * delta)
	elif face_target and is_instance_valid(face_target):
		var to := face_target.global_position - global_position
		to.y = 0
		if to.length() > 0.01:
			var want := atan2(to.x, to.z)
			rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 3.0))
	if bob != 0.0:
		position.y = _base_y + sin(_t * 1.3) * bob


func rebase() -> void:
	_base_y = position.y


## The average colour of the opaque pixels: the fur of this form.
static func _fur(c: String, tex: Texture2D) -> Color:
	if _fur_cache.has(c):
		return _fur_cache[c]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var acc := Vector3.ZERO
	var n := 0
	var w := img.get_width() / maxi(1, int(Game.meta.get(c, {"frames": 1}).frames))
	for y in range(0, img.get_height(), 3):
		for x in range(0, w, 3):
			var p := img.get_pixel(x, y)
			if p.a > 0.6:
				acc += Vector3(p.r, p.g, p.b)
				n += 1
	var col := Color(0.85, 0.83, 0.8) if n == 0 else Color(acc.x / n, acc.y / n, acc.z / n)
	_fur_cache[c] = col
	return col


## A unit cat head, about one unit tall from chin to ear tip, facing +Z.
static func _build_head() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skull := SphereMesh.new()
	skull.radius = 0.4
	skull.height = 0.8
	skull.radial_segments = 40
	skull.rings = 24
	st.append_from(skull, 0, Transform3D(Basis.from_scale(Vector3(1.08, 0.92, 0.8)), Vector3(0, 0, 0)))
	var cheek := SphereMesh.new()
	cheek.radius = 0.2
	cheek.height = 0.4
	cheek.radial_segments = 20
	cheek.rings = 12
	st.append_from(cheek, 0, Transform3D(Basis.from_scale(Vector3(1.2, 0.62, 0.5)), Vector3(0, -0.15, 0.17)))
	var ear := CylinderMesh.new()
	ear.top_radius = 0.0
	ear.bottom_radius = 0.16
	ear.height = 0.32
	ear.radial_segments = 12
	ear.rings = 1
	for sx in [-1.0, 1.0]:
		var b := Basis().rotated(Vector3(0, 0, 1), -sx * 0.38).scaled(Vector3(1.0, 1.0, 0.45))
		st.append_from(ear, 0, Transform3D(b, Vector3(sx * 0.25, 0.42, 0.02)))
	st.generate_normals()
	return st.commit()
