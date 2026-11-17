// A snowflake, a fleck of ash or a raindrop: round, soft, and gone near the eye, so none ever
// fills the view as it falls past.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform bool streak = false;   // rain: stands upright, a long thin drop
uniform float near = 1.2;      // fully gone this close to the eye, metres
uniform float clear = 3.5;     // fully shown from here out

void vertex() {
	vec3 pos = MODEL_MATRIX[3].xyz;
	if (streak) {
		vec3 to_eye = INV_VIEW_MATRIX[3].xyz - pos;
		vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), to_eye) + vec3(1e-4, 0.0, 0.0));
		vec3 fwd = cross(side, vec3(0.0, 1.0, 0.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(fwd, 0.0), vec4(pos, 1.0));
	} else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(pos, 1.0));
	}
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float shape = streak ? (1.0 - smoothstep(0.25, 0.5, abs(c.x))) : (1.0 - smoothstep(0.2, 0.5, length(c)));
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * shape * smoothstep(near, clear, length(VERTEX));
}
