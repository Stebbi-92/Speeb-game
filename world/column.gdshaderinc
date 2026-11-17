// A column of light or smoke standing over the waste, seen from far off: soft at its edges (it is
// thickest seen through its middle), thin toward the top, with slow wisps drifting up it.
uniform vec4 tint : source_color = vec4(1.0, 0.95, 0.8, 0.2);
uniform float wisp = 0.5;        // how much the drifting wisps show (0 a clean beam)
uniform float rise = 3.0;        // how fast they climb, metres a second
uniform float height = 220.0;
uniform float sway = 0.0;        // how far the top drifts in the wind, metres
uniform float near_fade = 30.0;  // gone this close to the eye, so it is never a wall in the face

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(13.1, 7.7);
		a *= 0.5;
	}
	return v;
}

varying float up;   // 0 at the foot, 1 at the top

void vertex() {
	up = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
	// The top bends a little in the wind, and wanders
	float w = up * up * sway;
	VERTEX.x += w * (0.7 + 0.3 * sin(TIME * 0.11));
	VERTEX.z += w * 0.4 * sin(TIME * 0.07 + 1.3);
}

void fragment() {
	// Thick through the middle, thin at the rim
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = pow(face, 1.6);
	// Wisps: noise that climbs the column and twists slowly round it
	vec2 p = vec2(UV.x * 7.0 + TIME * 0.02, up * height / 9.0 - TIME * rise / 9.0);
	float n = fbm(p);
	a *= mix(1.0, smoothstep(0.25, 0.85, n) * 1.6, wisp);
	// Faint at the foot (it rises out of the fire), gone toward the top
	a *= smoothstep(0.0, 0.03, up) * (1.0 - smoothstep(0.45, 1.0, up));
	// Never in the eye's face
	a *= smoothstep(near_fade * 0.4, near_fade, length(VERTEX));
	ALBEDO = tint.rgb * (1.0 + 0.25 * n);
	ALPHA = clamp(a * tint.a, 0.0, 1.0);
}
