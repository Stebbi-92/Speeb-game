// A wild boar's coat, for a body that came without a picture of its own: coarse grey-brown bristles,
// darker and sparser in patches, drawn from noise over its own UVs.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D bristle : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D patch : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 base : source_color = vec3(0.24, 0.19, 0.15);
uniform vec3 dark : source_color = vec3(0.09, 0.075, 0.065);
uniform vec3 tip : source_color = vec3(0.42, 0.37, 0.31);

void fragment() {
	float b = texture(bristle, UV * vec2(9.0, 22.0)).r;
	float p = texture(patch, UV * 2.5).r;
	vec3 c = mix(dark, base, smoothstep(0.25, 0.75, p));
	c = mix(c, tip, smoothstep(0.62, 0.9, b) * 0.6);
	c *= 0.8 + 0.35 * b;
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
