shader_type spatial;
// A cat head of Speeb: the emoji is projected onto the face from the front; the rest is fur of the emoji's own colour.
uniform sampler2D face_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 fur : source_color = vec3(0.9, 0.88, 0.85);
uniform float frames = 1.0;
uniform float frame = 0.0;
uniform float glow = 0.0;
uniform float hit_flash = 0.0;
uniform float menace = 0.0;
uniform float gild = 0.0;
uniform float half_size = 0.62;
uniform float center_y = 0.08;
varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

void fragment() {
	vec2 raw = vec2(opos.x, -(opos.y - center_y)) / (2.0 * half_size) + 0.5;
	float inside = step(0.0, raw.x) * step(raw.x, 1.0) * step(0.0, raw.y) * step(raw.y, 1.0);
	vec2 uv = vec2((clamp(raw.x, 0.002, 0.998) + frame) / frames, clamp(raw.y, 0.002, 0.998));
	vec4 t = texture(face_tex, uv);
	float front = smoothstep(0.0, 0.5, normalize(onrm).z);
	float k = t.a * front * inside;
	vec3 c = mix(fur, t.rgb, k);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(1.0, 0.78, 0.36) * (0.45 + lum * 0.8), gild * 0.85);
	c = mix(c, c * vec3(1.0, 0.45, 0.4), menace * 0.55 * (1.0 - gild * 0.6));
	ALBEDO = c;
	METALLIC = gild * 0.85;
	ROUGHNESS = mix(0.9, 0.3, gild);
	SPECULAR = 0.25;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = c * glow + vec3(1.0, 0.25, 0.15) * hit_flash + vec3(1.0, 0.06, 0.02) * rim * menace * 3.0;
	BACKLIGHT = vec3(0.15) * fur;
}
