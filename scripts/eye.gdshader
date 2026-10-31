shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, blend_mix;
// The Unblinking Eye: a vast cat's eye, amber, its pupil a black slit. open: 0 shut, 1 wide.
uniform float open = 0.0;
uniform float pupil = 0.18;
uniform float time_off = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float lid = max(open, 0.001);
	// Almond aperture between two arcs
	float edge = (1.0 - p.x * p.x) * lid * 0.75;
	float inside = 1.0 - smoothstep(edge - 0.02, edge + 0.02, abs(p.y));
	if (inside < 0.01 || abs(p.x) > 1.0) {
		discard;
	}
	float r = length(p * vec2(1.0, 1.15));
	float ang = atan(p.y, p.x);
	vec3 iris = mix(vec3(1.0, 0.78, 0.25), vec3(0.75, 0.32, 0.05), smoothstep(0.1, 0.75, r));
	iris *= 0.8 + 0.2 * sin(ang * 40.0 + r * 18.0);
	iris = mix(iris, vec3(0.15, 0.05, 0.0), smoothstep(0.7, 0.82, r));
	float slit = smoothstep(pupil * (0.6 + 0.4 * open), pupil * (0.6 + 0.4 * open) - 0.03, abs(p.x) * (1.0 + p.y * p.y * 2.5));
	vec3 c = mix(iris, vec3(0.0), slit);
	float glint = smoothstep(0.08, 0.0, length(p - vec2(-0.22, 0.25)));
	c += vec3(1.0) * glint * 0.8;
	ALBEDO = c * 1.4;
	ALPHA = inside;
}
