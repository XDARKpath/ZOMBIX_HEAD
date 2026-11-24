// Sterrato di campagna: terra battuta chiara, due solchi scuri delle ruote, erba bassa in mezzo e ai bordi,
// sassi e pozzanghere. UV.x è la posizione di traverso (-1 bordo, 0 centro, 1 bordo: terrain.gd _road_strip).
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 dirt : source_color = vec3(0.42, 0.37, 0.29);
uniform vec3 rut : source_color = vec3(0.27, 0.22, 0.17);
uniform vec3 verge : source_color = vec3(0.36, 0.38, 0.17);
// Quanto è consumata la strada (rami del bosco più dei grandi tracciati): più erba e più pozzanghere.
uniform float crack_amount = 1.0;

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.07 + vec2(13.1, -7.3); a *= 0.5; }
	return v / 0.9375;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float across = UV.x;
	float grain = fbm(p * 2.3);
	float fine = noise(p * 11.0);
	vec3 col = dirt * (0.82 + grain * 0.3 + fine * 0.08);
	// Due solchi a metà fra centro e bordo, un po' ondulati.
	float wobble = (fbm(p * 0.25) - 0.5) * 0.18;
	float ruts = 1.0 - smoothstep(0.07, 0.2, abs(abs(across + wobble) - 0.5));
	col = mix(col, rut * (0.85 + grain * 0.3), ruts * 0.75);
	// Erba bassa sulla gobba centrale e sui bordi, a chiazze.
	float hump = 1.0 - smoothstep(0.08, 0.22, abs(across + wobble));
	float edge = smoothstep(0.72, 1.0, abs(across));
	float tufts = smoothstep(0.42, 0.7, fbm(p * 1.6 + 3.0));
	col = mix(col, verge * (0.8 + grain * 0.4), clamp(hump * tufts * 0.8 * crack_amount + edge * (0.35 + tufts * 0.6), 0.0, 1.0));
	// Sassolini tondi sparsi, fuori dai solchi.
	vec2 cell = floor(p * 5.0);
	vec2 at = fract(p * 5.0) - 0.5 - (vec2(hash(cell + 3.0), hash(cell + 7.0)) - 0.5) * 0.5;
	float stone = step(0.9, hash(cell)) * (1.0 - smoothstep(0.09, 0.14, length(at))) * (1.0 - ruts);
	col = mix(col, vec3(0.50, 0.48, 0.44) * (0.8 + fine * 0.3), stone * 0.7);
	// Pozzanghere nei solchi: scure e lucide.
	float puddle = smoothstep(0.74, 0.8, fbm(p * 0.35 + 21.0)) * smoothstep(0.2, 0.8, ruts + hump * 0.3) * clamp(crack_amount, 0.5, 1.5);
	col = mix(col, vec3(0.10, 0.09, 0.08), puddle * 0.75);
	ALBEDO = col;
	ROUGHNESS = mix(0.97, 0.15, puddle);
	SPECULAR = mix(0.2, 0.6, puddle);
}
