shader_type spatial;
render_mode unshaded, cull_back;
// The face of a hostile form: its emoji, whole and unlit, in a round frame edged with red.
uniform sampler2D face_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float frames = 1.0;
uniform float frame = 0.0;
uniform float flash = 0.0;
uniform float shade = 0.0;

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	if (r > 0.5) {
		discard;
	}
	vec4 t = texture(face_tex, vec2((UV.x + frame) / frames, UV.y));
	vec3 c = mix(vec3(0.03, 0.02, 0.02), t.rgb, t.a);
	float edge = smoothstep(0.43, 0.46, r);
	c = mix(c, vec3(0.75, 0.05, 0.03), edge);
	c = mix(c, vec3(1.0, 0.5, 0.45), flash * 0.6);
	ALBEDO = c * (1.0 - shade * 0.5);
}
