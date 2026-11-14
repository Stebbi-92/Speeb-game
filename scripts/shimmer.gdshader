shader_type spatial;
// The unseen: almost nothing, a bending of what lies behind it, darker at the core.
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float seen = 0.08;      // 0 gone, 1 plainly there
uniform float flash = 0.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	vec2 off = NORMAL.xy * 0.035 * (0.4 + rim) * (0.5 + seen);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + off, 1.5).rgb;
	vec3 dark = behind * mix(1.0, 0.1, seen * (1.0 - rim * 0.5));
	ALBEDO = mix(dark, vec3(0.9, 0.08, 0.04), flash * 0.6);
	ALPHA = clamp(0.35 + seen * 0.65 + rim * 0.3, 0.0, 1.0);
}
