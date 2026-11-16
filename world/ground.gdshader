shader_type spatial;
// The ground of the waste. The colour still comes from the land (the vertex colour); the photographed ground
// (CC0, Poly Haven) gives it grain and relief, chosen by which land holds sway (CUSTOM0, CUSTOM1).
//   ground_a: grain of ash, dunes, salt, forest      ground_b: basalt, marsh, slope rock, road
//   ground_n1..n4: their normals in pairs (xy of one in rg, of the next in ba), in the same order.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D ground_a : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_b : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_n1 : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_n2 : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_n3 : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_n4 : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_near = 4.0;     // metres the close grain repeats over
uniform float tile_far = 37.0;     // and the broad grain, to hide the repeat
uniform float grain = 1.0;         // how strongly the grain shows (0 = the old flat colour)
uniform float bump = 0.9;
uniform float fade_near = 90.0;    // past here the close detail fades into the broad
uniform float fade_far = 260.0;

varying vec4 wa;
varying vec4 wb;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The grain lies flat on the world (u along x, v along z), so the mesh needs no tangents of its own
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(cross(NORMAL, TANGENT));
	wa = CUSTOM0;
	wb = CUSTOM1;
	// Steep ground is rock, whatever land it is in
	float n_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	float rock = smoothstep(0.86, 0.68, n_up) * 0.9;
	wa *= 1.0 - rock;
	wb.xyw *= 1.0 - rock;
	wb.z = max(wb.z, rock);
}

vec2 nxy(vec4 t, float second) {
	return mix(t.xy, t.zw, second) * 2.0 - 1.0;
}

void fragment() {
	float total = dot(wa, vec4(1.0)) + dot(wb, vec4(1.0));
	vec4 a = wa / max(total, 0.0001);
	vec4 b = wb / max(total, 0.0001);
	vec2 uv = wpos.xz / tile_near;
	vec2 uvf = wpos.xz / tile_far;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near_k = 1.0 - smoothstep(fade_near, fade_far, dist);

	vec4 ga = texture(ground_a, uv);
	vec4 gb = texture(ground_b, uv);
	vec4 fa = texture(ground_a, uvf);
	vec4 fb = texture(ground_b, uvf);
	float g_near = dot(ga, a) + dot(gb, b);
	float g_far = dot(fa, a) + dot(fb, b);
	// Grey 0.5 is no change; the near grain over the broad, the broad alone far off
	float g = mix(g_far, mix(g_far, g_near, 0.75), near_k);
	float k = 1.0 + (g * 2.0 - 1.0) * grain * 1.25;
	ALBEDO = COLOR.rgb * clamp(k, 0.25, 1.9);

	// Relief, only near enough to see it
	vec2 n2 = vec2(0.0);
	if (near_k > 0.001) {
		vec4 t1 = texture(ground_n1, uv);
		vec4 t2 = texture(ground_n2, uv);
		vec4 t3 = texture(ground_n3, uv);
		vec4 t4 = texture(ground_n4, uv);
		n2 += nxy(t1, 0.0) * a.x + nxy(t1, 1.0) * a.y;
		n2 += nxy(t2, 0.0) * a.z + nxy(t2, 1.0) * a.w;
		n2 += nxy(t3, 0.0) * b.x + nxy(t3, 1.0) * b.y;
		n2 += nxy(t4, 0.0) * b.z + nxy(t4, 1.0) * b.w;
		n2 *= bump * near_k;
	}
	NORMAL_MAP = vec3(n2 * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
	// Wet marsh and polished salt shine a little; the rest is dull
	ROUGHNESS = clamp(0.97 - b.y * 0.25 - a.z * 0.12 - (g - 0.5) * 0.2, 0.55, 1.0);
	SPECULAR = 0.35;
}
