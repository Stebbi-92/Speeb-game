// A snowflake, a fleck of ash or a raindrop: round, soft, and gone near the eye, so none ever
// fills the view as it falls past.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// (glow is done by premultiplying: dark where faint, so a mix blend acts much as an added one)

uniform bool streak = false;   // rain: stands upright, a long thin drop
uniform float near = 1.2;      // fully gone this close to the eye, metres
uniform float clear = 3.5;     // fully shown from here out
uniform bool glow = false;     // added to the light behind it (embers, spores, salt glints)

void vertex() {
	vec3 pos = MODEL_MATRIX[3].xyz;
	float k = length(MODEL_MATRIX[0].xyz);   // the particle's own size
	if (streak) {
		vec3 to_eye = INV_VIEW_MATRIX[3].xyz - pos;
		vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), to_eye) + vec3(1e-4, 0.0, 0.0));
		vec3 fwd = cross(side, vec3(0.0, 1.0, 0.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side * k, 0.0), vec4(0.0, k, 0.0, 0.0), vec4(fwd * k, 0.0), vec4(pos, 1.0));
	} else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * k, INV_VIEW_MATRIX[1] * k, INV_VIEW_MATRIX[2] * k, vec4(pos, 1.0));
	}
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float shape = streak ? (1.0 - smoothstep(0.25, 0.5, abs(c.x))) : (1.0 - smoothstep(0.2, 0.5, length(c)));
	float a = COLOR.a * shape * smoothstep(near, clear, length(VERTEX));
	ALBEDO = glow ? COLOR.rgb * 1.4 : COLOR.rgb;
	ALPHA = glow ? a * 0.8 : a;
}
