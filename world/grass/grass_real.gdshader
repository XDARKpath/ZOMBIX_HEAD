// Filo d'erba fatto in casa (grass_field.gd blade_clump): ogni cespo è un mazzo di fili affusolati e curvi.
// UV.x = di traverso sul filo (-1..1), UV.y = altezza sul filo (0 radice, 1 punta), UV2.x = caso del filo.
// COLOR viene dalle particelle: r = caso del cespo, g = densità del prato, b = macchie (grass_particles.gdshader).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 root : source_color = vec3(0.10, 0.12, 0.04);
uniform vec3 green : source_color = vec3(0.42, 0.52, 0.16);
uniform vec3 yellow : source_color = vec3(0.72, 0.68, 0.26);
uniform vec3 straw : source_color = vec3(0.80, 0.70, 0.42);
// Quanta paglia c'è in questo strato (0 = verde, 1 = secco).
uniform float dryness = 0.3;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float flutter = 0.06;

varying vec3 tint;
varying float h;

void vertex() {
	h = UV.y;
	float own = UV2.x;
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Stesse raffiche delle particelle; ogni filo trema un po' per conto suo.
	float gust = sin(dot(base.xz, wind_dir) * 0.11 - TIME * 1.3) * 0.5 + 0.5;
	float shake = sin(TIME * (3.2 + own * 2.5) + own * 40.0 + base.x * 0.7) * (0.3 + gust);
	VERTEX.xz += wind_dir * shake * flutter * h * h;
	// Colore: verde vivo, giallo e paglia a macchie e per filo; la punta schiarisce, la radice è in ombra.
	float dry = clamp(dryness + (COLOR.b - 0.5) * 0.8 + (own - 0.5) * 0.5, 0.0, 1.0);
	vec3 body = mix(green, yellow, smoothstep(0.15, 0.6, dry));
	body = mix(body, straw, smoothstep(0.55, 0.95, dry));
	body *= mix(0.85, 1.12, fract(COLOR.r * 7.3 + own));
	tint = mix(root, body, smoothstep(0.0, 0.45, h));
	tint = mix(tint, straw * 1.05, smoothstep(0.75, 1.0, h) * 0.35);
	// Normale arrotondata di traverso e piegata verso l'alto: luce morbida come su un filo vero.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.45));
}

void fragment() {
	ALBEDO = tint;
	// In controluce il filo si accende (tardo pomeriggio): luce che passa attraverso la foglia.
	BACKLIGHT = tint * 0.55;
	ROUGHNESS = 0.62;
	SPECULAR = 0.3;
	// Radice in ombra anche nelle zone illuminate.
	AO = mix(0.35, 1.0, smoothstep(0.0, 0.5, h));
	AO_LIGHT_AFFECT = 0.4;
}
