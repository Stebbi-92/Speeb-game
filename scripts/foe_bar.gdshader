shader_type spatial;
// A lesser form's life, held over it once it has been struck: a thin bar that always faces the eye.
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled, blend_mix;

instance uniform float frac = 1.0;
instance uniform float shown = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 px = fwidth(UV) * 1.5;
	bool edge = UV.x < px.x || UV.x > 1.0 - px.x || UV.y < px.y * 1.0 || UV.y > 1.0 - px.y;
	vec3 fill = mix(vec3(0.75, 0.08, 0.05), vec3(0.95, 0.55, 0.15), step(0.5, frac) * 0.0);
	vec3 col = edge ? vec3(0.02) : (UV.x <= frac ? fill : vec3(0.12, 0.1, 0.1));
	ALBEDO = col;
	ALPHA = shown * (edge ? 0.9 : 0.85);
}
