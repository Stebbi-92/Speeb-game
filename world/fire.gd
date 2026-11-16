class_name WFire
extends Node3D
## A living flame: tongues of fire drawn by a shader (no pictures needed), sparks going up, a thread of
## smoke if asked, and a light that flickers with it. One make() for every fire in the waste: camp,
## cooking station, torch, stove, the town hearths and the beacons.

static var _shader: Shader
static var _spark_m: StandardMaterial3D
static var _smoke_m: StandardMaterial3D

var light: OmniLight3D   ## flickered while the fire is seen
var _base := 1.0
var _t := 0.0


## A fire about `size` paces tall, its foot at this node's origin.
static func make(size := 1.0, sparks := true, smoke := false, tint := Color(1.0, 0.5, 0.12)) -> WFire:
	var f := WFire.new()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	for k in 3:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		var wdt := size * (0.75 - k * 0.15)
		var hgt := size * (1.0 - k * 0.12)
		qm.size = Vector2(wdt, hgt)
		qm.center_offset = Vector3(0, hgt * 0.5, 0)
		q.mesh = qm
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("seed", randf() * 50.0)
		m.set_shader_parameter("warm", tint)
		m.set_shader_parameter("speed", 1.4 + k * 0.35)
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = Vector3((k - 1) * size * 0.08, 0, (k % 2) * size * 0.05)
		q.visibility_range_end = 160.0 + size * 40.0
		f.add_child(q)
	if sparks:
		f.add_child(_sparks(size))
	if smoke:
		f.add_child(_smoke(size))
	return f


## Gives the fire its light, to flicker with it.
func with_light(l: OmniLight3D) -> WFire:
	light = l
	_base = l.light_energy
	return self


func _process(delta: float) -> void:
	if light == null or not is_instance_valid(light) or not is_visible_in_tree():
		return
	_t += delta
	light.light_energy = _base * (0.86 + 0.09 * sin(_t * 11.0) + 0.05 * sin(_t * 23.0 + 1.3) + 0.04 * sin(_t * 5.1))


static func _sparks(size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = int(clampf(8.0 * size, 4.0, 40.0))
	p.lifetime = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05) * clampf(size, 0.6, 3.0)
	p.mesh = q
	if _spark_m == null:
		_spark_m = StandardMaterial3D.new()
		_spark_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_spark_m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spark_m.vertex_color_use_as_albedo = true
		_spark_m.albedo_color = Color(1.0, 0.6, 0.2)
	p.material_override = _spark_m
	p.position.y = size * 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.2
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0.2, 0.6, 0)
	p.initial_velocity_min = 0.9 * size + 0.4
	p.initial_velocity_max = 1.8 * size + 0.6
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	g.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = 80.0
	return p


static func _smoke(size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 4.0
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9) * size
	p.mesh = q
	if _smoke_m == null:
		_smoke_m = StandardMaterial3D.new()
		_smoke_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_smoke_m.vertex_color_use_as_albedo = true
		_smoke_m.albedo_texture = LesserSpeeb.smoke_tex()
	p.material_override = _smoke_m
	p.position.y = size * 0.9
	p.direction = Vector3.UP
	p.spread = 10.0
	p.gravity = Vector3(0.25, 0.35, 0.05)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.1
	var g := Gradient.new()
	g.set_color(0, Color(0.25, 0.23, 0.22, 0.35))
	g.set_color(1, Color(0.4, 0.38, 0.36, 0.0))
	p.color_ramp = g
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = c
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = 120.0
	return p


const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float seed = 0.0;
uniform float speed = 1.6;
uniform vec4 hot : source_color = vec4(1.0, 0.93, 0.68, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.5, 0.12, 1.0);
uniform vec4 cool : source_color = vec4(0.6, 0.1, 0.02, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	// Turned always to face the eye, upright
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);   // 0 at the foot
	float t = TIME * speed + seed;
	float n = fbm(vec2(uv.x * 3.2 + seed, uv.y * 2.6 - t * 1.9));
	float sway = (fbm(vec2(uv.y * 1.5 - t * 0.7, seed)) - 0.5) * 0.35 * uv.y;
	float x = (uv.x - 0.5 + sway) * 2.0;
	float width = (1.0 - uv.y) * 0.85 + 0.12;
	float shape = 1.0 - abs(x) / width;
	shape *= smoothstep(0.0, 0.1, uv.y);
	float f = shape * 1.25 - uv.y * 0.75 + (n - 0.5) * 1.1;
	f = clamp(f * 1.9, 0.0, 1.0);
	vec3 c = mix(cool.rgb, warm.rgb, smoothstep(0.05, 0.45, f));
	c = mix(c, hot.rgb, smoothstep(0.55, 0.95, f));
	ALBEDO = c * f * 1.5;
	ALPHA = f;
}
"""
