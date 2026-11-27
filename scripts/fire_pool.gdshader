shader_type spatial;
// Tongues of fire for a burning pool or a burning body, many in one draw. Each one stands upright and
// turns to face the eye. Its own numbers come in INSTANCE_CUSTOM: x a seed, y how fast it licks,
// z when it goes out (0..1 of the fire's life), w when it catches (seconds after the burst).
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

instance uniform float age = 100.0;     // seconds since the burst
instance uniform float life = 1.0;      // 1 burning hard, 0 gone out
uniform float bright = 1.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 hot : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.48, 0.1, 1.0);
uniform vec4 cool : source_color = vec4(0.55, 0.07, 0.02, 1.0);

varying float lit;
varying float seed;
varying float spd;

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
	seed = INSTANCE_CUSTOM.x * 50.0;
	spd = 1.2 + INSTANCE_CUSTOM.y * 1.2;
	// It catches a moment after the burst (flaring tall for a breath), and dies down as the fire's life runs out
	float since = age - INSTANCE_CUSTOM.w * 4.0;
	float grow = clamp(since / 0.35, 0.0, 1.0);
	float flare = 1.0 + 0.6 * exp(-max(since, 0.0) * 2.5) * step(0.0, since);
	float k = clamp((life - INSTANCE_CUSTOM.z * 0.7) / 0.3, 0.0, 1.0);
	lit = grow * k;
	float tall = lit * flare;
	VERTEX.y *= tall;
	VERTEX.x *= mix(0.45, 1.0, lit);
	// Turned always to face the eye, upright
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	if (lit <= 0.001) {
		discard;
	}
	vec2 uv = vec2(UV.x, 1.0 - UV.y);   // 0 at the foot
	float t = TIME * spd + seed;
	float n = fbm(vec2(uv.x * 3.4 + seed, uv.y * 2.4 - t * 2.1));
	float n2 = fbm(vec2(uv.x * 7.0 - seed, uv.y * 5.0 - t * 3.3));
	float sway = (fbm(vec2(uv.y * 1.5 - t * 0.7, seed)) - 0.5) * 0.5 * uv.y;
	float x = (uv.x - 0.5 + sway + (n2 - 0.5) * 0.25 * uv.y) * 2.0;
	float width = sqrt(max(1.0 - uv.y, 0.0)) * 0.85 + 0.05;
	float shape = 1.0 - abs(x) / width;
	shape *= smoothstep(0.0, 0.15, uv.y);
	float f = shape * 1.15 - uv.y * 0.85 + (n - 0.5) * 1.4 + (n2 - 0.5) * 0.4;
	f = clamp(f * 1.6, 0.0, 1.0);
	// Hottest low in the middle, cooling to orange and dark red toward the tips and edges
	float heat = f * (1.0 - uv.y * 0.55);
	float fl = 0.85 + 0.15 * sin(TIME * 13.0 + seed * 3.1) * sin(TIME * 7.3 + seed);
	vec3 c = mix(cool.rgb, warm.rgb, smoothstep(0.08, 0.5, heat));
	c = mix(c, hot.rgb, smoothstep(0.7, 0.98, heat));
	vec3 col = c * 1.05 * bright * fl * mix(0.6, 1.0, lit);
	// Soft where it meets the ground, so no hard line shows at its foot
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	float soft = clamp((-up.z / up.w + VERTEX.z) / 0.35, 0.0, 1.0);
	// Light added as fire adds it, and a little of what lies behind hidden, so it keeps its colour by day
	float a = smoothstep(0.0, 0.7, f) * soft;
	ALBEDO = col * a;
	ALPHA = a * 0.5;
}
