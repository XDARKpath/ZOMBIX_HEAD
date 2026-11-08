shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.040, 0.105, 0.115, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.115, 0.225, 0.205, 1.0);
uniform vec4 foam_color : source_color = vec4(0.74, 0.78, 0.74, 1.0);
uniform float shoreline_z = 13.0;
uniform float wave_strength = 1.0;
uniform float wave_height = 0.14;

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Pendenza di un treno d'onda direzionale: serve a inclinare la normale.
vec2 wave_grad(vec2 p, vec2 dir, float k, float amp, float speed) {
	float phase = dot(p, dir) * k + TIME * speed;
	return dir * (k * amp * cos(phase));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float swell = sin(world_pos.x * 0.11 + TIME * 0.55) * 0.10;
	swell += sin(world_pos.z * 0.085 - TIME * 0.42) * 0.07;
	swell += sin((world_pos.x + world_pos.z) * 0.27 + TIME * 0.95) * 0.022;
	VERTEX.y += swell * wave_strength * wave_height;
}

void fragment() {
	vec2 p = world_pos.xz;
	float dist = distance(CAMERA_POSITION_WORLD, world_pos);
	float shore = smoothstep(shoreline_z + 26.0, shoreline_z + 2.0, world_pos.z);

	// Normali d'onda: increspature direzionali di quattro scale. In lontananza
	// l'ampiezza si spegne, così non compaiono reticoli o moire.
	float damp = (1.0 - smoothstep(6.0, 42.0, dist)) * wave_strength;
	vec2 g = vec2(0.0);
	g += wave_grad(p, vec2(0.82, 0.57), 0.42, 0.030, 0.85);
	g += wave_grad(p, vec2(-0.45, 0.89), 0.78, 0.020, 1.25);
	g += wave_grad(p, vec2(0.96, -0.28), 1.70, 0.009, 1.95);
	g += wave_grad(p, vec2(-0.21, -0.98), 3.10, 0.004, 2.60);
	g *= 0.55 * damp;
	float mottle = noise(p * 0.28 + vec2(TIME * 0.02, TIME * 0.014));
	g *= 0.7 + 0.6 * mottle;
	vec3 n_world = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// Fresnel: acqua scura di taglio, più chiara a vista radente.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 base = mix(shallow_color.rgb, deep_color.rgb, clamp(shore * 1.2, 0.0, 1.0));
	base += vec3(0.018, 0.030, 0.026) * shore;
	base += vec3(0.014, 0.024, 0.020) * (mottle - 0.5);
	base = mix(base, vec3(0.050, 0.105, 0.105), fresnel * 0.30);
	ALBEDO = base;
	ROUGHNESS = mix(0.20, 0.34, shore);
	METALLIC = 0.05;
	SPECULAR = 0.40;

	// Battigia: banda di schiuma irregolare, mai una linea dritta.
	float edge = shoreline_z + 1.1 + sin(p.x * 0.55 + TIME * 0.35) * 0.35 + noise(p * 1.7) * 0.25;
	float line = smoothstep(0.7, 0.06, abs(world_pos.z - edge));
	float froth = line * (0.30 + 0.55 * noise(p * 4.2 + vec2(TIME * 0.45, -TIME * 0.3)));
	ALBEDO = mix(ALBEDO, foam_color.rgb, clamp(froth, 0.0, 0.5));
	ROUGHNESS = mix(ROUGHNESS, 0.72, froth);
	EMISSION = vec3(0.018, 0.045, 0.05) * fresnel;
}
