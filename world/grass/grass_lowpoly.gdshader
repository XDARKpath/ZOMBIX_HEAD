// Ciuffo low-poly Quaternius (CC0) per il prato GPU: colori piatti come il resto del
// gioco, erba alta che ondeggia a raffiche, punte secche più chiare.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 base_color : source_color = vec3(0.30, 0.38, 0.17);
uniform vec3 dry : source_color = vec3(0.74, 0.68, 0.44);
uniform vec3 lush : source_color = vec3(0.34, 0.40, 0.17);
uniform float sway = 0.11;
uniform float mesh_height = 1.0;

varying vec3 tint;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = clamp(VERTEX.y / max(mesh_height, 0.001), 0.0, 1.0);
	float gust = sin(TIME * 0.35 + root.x * 0.035 + root.z * 0.02) * 0.5 + 0.5;
	float wave = sin(TIME * 1.6 + root.x * 0.27 + root.z * 0.19) * (0.4 + gust);
	VERTEX.x += wave * sway * h * h;
	VERTEX.z += cos(TIME * 1.2 + root.z * 0.31) * sway * 0.4 * h * h;
	// Macchie più secche dove il rumore del prato è alto, punte chiare al sole.
	// Ogni ciuffo ha il suo verde (dal fresco all'oliva); a macchie diventa secco.
	tint = mix(lush, base_color, COLOR.r) * mix(0.85, 1.15, fract(COLOR.r * 7.3));
	tint = mix(tint, dry, smoothstep(0.55, 0.9, COLOR.b) * 0.6);
	tint = mix(tint, dry * 1.1, h * h * 0.18);
	// Base in ombra, punte al sole: dà volume al prato.
	tint *= mix(0.25, 1.1, pow(h, 0.7));
	NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6);
}

void fragment() {
	ALBEDO = tint;
}
