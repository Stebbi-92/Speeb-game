shader_type canvas_item;
// Full-screen veil: vignette, the Riftwalker's glitch, the drowsy dimming and the white of revelation.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette = 0.0;
uniform float glitch = 0.0;
uniform float desat = 0.0;
uniform float dark = 0.0;
uniform float flash = 0.0;
uniform float blur = 0.0;
uniform float hurt = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 12.0);
	if (glitch > 0.0) {
		float band = floor(uv.y * 24.0);
		float r = hash(vec2(band, t));
		if (r < glitch * 0.5) uv.x += (hash(vec2(t, band)) - 0.5) * 0.12 * glitch;
	}
	vec3 col;
	if (glitch > 0.0) {
		float o = 0.006 * glitch;
		col = vec3(texture(screen_tex, uv + vec2(o, 0)).r, texture(screen_tex, uv).g, texture(screen_tex, uv - vec2(o, 0)).b);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	if (blur > 0.0) {
		vec3 acc = col;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785;
			acc += texture(screen_tex, uv + vec2(cos(a), sin(a)) * 0.006 * blur).rgb;
		}
		col = acc / 9.0;
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), desat);
	vec2 d = SCREEN_UV - 0.5;
	float v = smoothstep(0.85, 0.25, length(d) * (1.0 + vignette));
	col *= mix(1.0, v, clamp(vignette, 0.0, 1.0));
	col *= 1.0 - dark;
	col = mix(col, vec3(0.55, 0.05, 0.03), hurt * 0.45 * smoothstep(0.2, 0.75, length(d)));
	col = mix(col, vec3(1.0), flash);
	if (glitch > 0.0 && hash(vec2(floor(uv.y * 200.0), t)) < 0.03 * glitch) col = vec3(hash(uv + t));
	COLOR = vec4(col, 1.0);
}
