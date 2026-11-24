// Ciuffo low-poly Quaternius (CC0) per il prato GPU: colori piatti come il resto del
// gioco, erba alta che ondeggia a raffiche, punte secche più chiare.
// Tavolozza da prato di fine estate al tramonto: giallo-verde e paglia, niente verde acceso.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 base_color : source_color = vec3(0.42, 0.44, 0.18);
uniform vec3 dry : source_color = vec3(0.82, 0.72, 0.36);
uniform vec3 lush : source_color = vec3(0.36, 0.42, 0.16);
uniform float sway = 0.05;
uniform float mesh_height = 1.0;
// Stesse raffiche delle particelle (grass_particles.gdshader): il tremolio sale quando passa l'onda.
uniform vec2 wind_dir = vec2(0.8, 0.6);

varying vec3 tint;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = clamp(VERTEX.y / max(mesh_height, 0.001), 0.0, 1.0);
	float gust = sin(dot(root.xz, wind_dir) * 0.11 - TIME * 1.3) * 0.5 + 0.5;
	float flutter = sin(TIME * 4.1 + root.x * 0.9 + root.z * 0.7) * (0.25 + gust);
	VERTEX.xz += wind_dir * flutter * sway * h * h;
	// Ogni ciuffo ha il suo tono, dall'oliva alla paglia; a macchie il prato è secco.
	tint = mix(lush, base_color, COLOR.r) * mix(0.88, 1.12, fract(COLOR.r * 7.3));
	tint = mix(tint, dry, smoothstep(0.45, 0.85, COLOR.b) * 0.7);
	tint = mix(tint, dry * 1.08, h * h * 0.35);
	// Base in ombra, punte al sole: dà volume al prato.
	tint *= mix(0.45, 1.1, pow(h, 0.7));
	NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6);
}

void fragment() {
	ALBEDO = tint;
}
