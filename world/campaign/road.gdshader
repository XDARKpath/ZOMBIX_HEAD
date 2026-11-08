// Asfalto abbandonato: crepe, rattoppi, buche e polvere ai bordi, tutto in spazio mondo.
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 asphalt : source_color = vec3(0.155, 0.152, 0.140);
uniform vec3 patch_color : source_color = vec3(0.095, 0.094, 0.090);
uniform vec3 dust : source_color = vec3(0.300, 0.262, 0.196);
uniform float crack_amount = 1.0;

varying vec3 world_pos;
varying vec3 tint;

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
	tint = COLOR.rgb;
}

void fragment() {
	vec2 p = world_pos.xz;
	float grain = fbm(p * 3.1);
	vec3 col = asphalt * (0.86 + grain * 0.28);
	// Bordi più chiari dai vertex color (colonne esterne del nastro): polvere e terra.
	float edge = smoothstep(0.30, 0.36, tint.r);
	col = mix(col, dust, edge * smoothstep(0.35, 0.8, fbm(p * 0.7)) * 0.55);
	// Rattoppi rettangolari scuri.
	vec2 cell = floor(p / vec2(3.4, 5.2));
	float has_patch = step(0.80, hash(cell));
	vec2 local = fract(p / vec2(3.4, 5.2));
	float inside = step(0.12, local.x) * step(local.x, 0.88) * step(0.15, local.y) * step(local.y, 0.85);
	col = mix(col, patch_color * (0.9 + grain * 0.2), has_patch * inside * 0.85);
	// Crepe: linee sottili dove il rumore attraversa la metà.
	float crack = 1.0 - smoothstep(0.0, 0.018, abs(fbm(p * 0.55 + 4.0) - 0.5));
	crack *= smoothstep(0.45, 0.7, fbm(p * 0.13 + 9.0));
	col *= 1.0 - crack * 0.55 * crack_amount;
	// Buche: macchie scure e un po' lucide d'acqua.
	float hole = smoothstep(0.80, 0.86, fbm(p * 0.42 + 21.0));
	col = mix(col, vec3(0.05, 0.05, 0.05), hole * 0.8);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.35, hole);
	SPECULAR = 0.25;
}
