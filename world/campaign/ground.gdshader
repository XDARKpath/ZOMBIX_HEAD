shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_pos;
varying vec3 vertex_tint;
varying float rock_amount;
// Maschera dell'erba GPU (world/grass/grass_field.gd): dove manca il prato è terra battuta.
uniform sampler2D grass_mask : filter_linear, repeat_disable;
uniform vec4 mask_bounds = vec4(0.0, 0.0, 0.0, 0.0);
// Il Mare di Sabbia (Route): min x, min z, max x, max z. Stessa sfumatura di Route.desert.
uniform vec4 desert_box = vec4(0.0, 0.0, 0.0, 0.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.3, -9.1);
		a *= 0.5;
	}
	return v / 0.9375;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_tint = COLOR.rgb;
	rock_amount = 1.0 - COLOR.a;
}

void fragment() {
	// Erba dipinta con rumore su più scale: chiazze organiche, niente quadretti.
	float broad = fbm(world_pos.xz * 0.045);
	float medium = fbm(world_pos.xz * 0.30 + 12.0);
	float fine = fbm(world_pos.xz * 2.1);
	vec3 grass = mix(vec3(0.10, 0.17, 0.05), vec3(0.19, 0.26, 0.08), broad);
	vec3 dry = mix(vec3(0.215, 0.198, 0.104), vec3(0.300, 0.268, 0.150), fine);
	vec3 dirt = mix(vec3(0.130, 0.112, 0.086), vec3(0.230, 0.198, 0.152), fine);
	vec3 albedo = mix(grass, dry, smoothstep(0.44, 0.78, medium) * 0.34);
	albedo = mix(albedo, dirt, smoothstep(0.60, 0.88, medium) * 0.32);
	if (mask_bounds.z > 0.0) {
		vec2 muv = (world_pos.xz - mask_bounds.xy) / mask_bounds.zw;
		if (muv.x > 0.0 && muv.y > 0.0 && muv.x < 1.0 && muv.y < 1.0) {
			float bare = 1.0 - texture(grass_mask, muv).r;
			// Terra battuta e fango scuro, come il piazzale del concept.
			vec3 mud = mix(vec3(0.16, 0.105, 0.060), vec3(0.26, 0.175, 0.10), fine);
			albedo = mix(albedo, mud, smoothstep(0.35, 0.95, bare) * 0.65);
		}
	}
	// Micro-variazione dei fili d'erba e del terreno calpestato.
	albedo *= 0.92 + fine * 0.14;
	albedo *= 0.84 + vertex_tint.g * 0.34;
	float sand = 0.0;
	if (desert_box.z > desert_box.x) {
		float inside = max(max(world_pos.x - desert_box.z, desert_box.x - world_pos.x), max(world_pos.z - desert_box.w, desert_box.y - world_pos.z));
		sand = 1.0 - smoothstep(-50.0, -6.0, inside);
	}
	if (sand > 0.001) {
		// Sabbia calda con increspature del vento, più chiara in cresta.
		float ripple = sin((world_pos.x * 0.9 + world_pos.z * 0.42) * 2.4 + fbm(world_pos.xz * 0.16) * 10.0) * 0.5 + 0.5;
		vec3 dune = mix(vec3(0.58, 0.40, 0.21), vec3(0.74, 0.56, 0.32), broad);
		dune = mix(dune, vec3(0.50, 0.33, 0.17), smoothstep(0.55, 0.85, medium) * 0.45);
		dune *= 0.93 + ripple * 0.09 + fine * 0.05;
		albedo = mix(albedo, dune, sand);
	}
	// Montagne del bordo (alfa del vertice, terrain.gd): roccia a strati e neve in cima.
	if (rock_amount > 0.001) {
		float strata = fbm(vec2(world_pos.y * 0.09, (world_pos.x + world_pos.z) * 0.012));
		vec3 stone = mix(vec3(0.150, 0.145, 0.135), vec3(0.285, 0.272, 0.250), strata);
		vec3 snow = vec3(0.62, 0.65, 0.68);
		stone = mix(stone, snow, smoothstep(165.0, 215.0, world_pos.y + fine * 22.0) * (1.0 - sand));
		stone = mix(stone, stone * vec3(1.35, 1.0, 0.72), sand);
		albedo = mix(albedo, stone, smoothstep(0.0, 1.0, rock_amount + (medium - 0.5) * 0.35 * rock_amount));
	}
	ALBEDO = albedo;
	ROUGHNESS = mix(0.97, 0.86, smoothstep(0.55, 0.9, medium));
	SPECULAR = 0.06;
	AO = mix(0.78, 1.0, fine);
	AO_LIGHT_AFFECT = 0.2;
}
