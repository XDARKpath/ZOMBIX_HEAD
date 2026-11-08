// Ciuffo low-poly Quaternius (CC0) per il prato GPU: colori piatti come il resto del
// gioco, vento appena percettibile (l'erba precedente era troppo alta e mossa).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 base_color : source_color = vec3(0.30, 0.38, 0.17);
uniform vec3 dry : source_color = vec3(0.46, 0.42, 0.25);
uniform float sway = 0.025;
uniform float mesh_height = 1.0;

varying vec3 tint;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = clamp(VERTEX.y / max(mesh_height, 0.001), 0.0, 1.0);
	float wave = sin(TIME * 1.1 + root.x * 0.27 + root.z * 0.19);
	VERTEX.x += wave * sway * h * h;
	tint = mix(base_color * mix(0.8, 1.15, COLOR.r), dry, smoothstep(0.6, 1.0, COLOR.b) * 0.6);
	tint *= mix(0.62, 1.0, h);
	NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6);
}

void fragment() {
	ALBEDO = tint;
}
