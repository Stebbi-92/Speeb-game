shader_type spatial;
// Fur for the lesser forms: a coat colour broken by stripes or patches, fine noise for the hairs,
// and a soft sheen at the edges where light catches them.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.5, 0.4, 0.3);
uniform vec3 mark_color : source_color = vec3(0.15, 0.1, 0.08);
uniform vec3 belly_color : source_color = vec3(0.8, 0.75, 0.7);
uniform float pattern = 1.0;     // 0 solid, 1 tabby stripes, 2 patches
uniform float seed = 0.0;
uniform float flash = 0.0;
uniform float gild = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; } return v; }

varying vec3 lp;
void vertex() { lp = VERTEX; }

void fragment() {
	vec3 c = base_color;
	float n = fbm(lp.xy * 9.0 + lp.z * 3.0);
	if (pattern > 0.5 && pattern < 1.5) {
		float s = sin((lp.y * 26.0 + abs(lp.x) * 9.0) + n * 4.0);
		c = mix(c, mark_color, smoothstep(0.35, 0.8, s));
	} else if (pattern > 1.5) {
		float pch = fbm(lp.xz * 3.0 + vec2(seed));
		c = mix(c, mark_color, smoothstep(0.48, 0.55, pch));
		c = mix(c, belly_color, smoothstep(0.62, 0.7, fbm(lp.xy * 2.5 + 7.0)));
	}
	// lighter muzzle and chin
	c = mix(c, belly_color, smoothstep(0.05, -0.2, lp.y) * smoothstep(0.15, 0.3, lp.z) * 0.8);
	float hairs = noise(lp.xy * 140.0 + lp.z * 60.0);
	c *= 0.82 + 0.3 * hairs;
	ALBEDO = mix(c, vec3(0.85, 0.66, 0.3), gild);
	METALLIC = gild * 0.9;
	ROUGHNESS = mix(0.92, 0.3, gild);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = c * fres * 0.06 + vec3(0.9, 0.08, 0.04) * flash * 0.8;
	BACKLIGHT = c * 0.3;
}
