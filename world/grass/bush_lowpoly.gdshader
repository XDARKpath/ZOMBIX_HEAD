// Cespuglio Quaternius (CC0) nel prato GPU: la forma delle foglie viene dalla sua texture, il colore dal prato
// (l'originale è rosso e stona con la mappa).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D leaf : filter_linear_mipmap;
uniform vec3 base_color : source_color = vec3(0.24, 0.36, 0.16);
uniform float mesh_height = 1.0;

varying vec3 tint;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = clamp(VERTEX.y / max(mesh_height, 0.001), 0.0, 1.0);
	VERTEX.x += sin(TIME * 1.3 + root.x * 0.27 + root.z * 0.19) * 0.03 * h;
	// Ogni cespuglio ha il suo verde; dentro è in ombra, in cima prende il sole.
	tint = base_color * mix(0.75, 1.25, COLOR.r) * mix(0.5, 1.15, h);
	NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6);
}

void fragment() {
	vec4 t = texture(leaf, UV);
	ALBEDO = tint * (0.7 + t.r * 0.9);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
