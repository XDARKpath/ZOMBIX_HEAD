shader_type spatial;
// Weapons: env palette albedo + per-cell roughness/metallic (T_Wep_Surface: R rough, G metal, B grain).
// Grain 0.5 = wood: streaks along grain_axis. Metal stays flat: noise on small faces reads as sparkle. Built by tools/weapon_look.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D surface_tex : filter_nearest, repeat_disable;
uniform sampler2D emission_tex : source_color, filter_nearest, repeat_disable;
uniform float emission_energy = 2.5;
instance uniform vec3 grain_axis = vec3(0.0, 0.0, 1.0);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	vec3 albedo = texture(albedo_tex, UV).rgb;
	vec3 s = texture(surface_tex, UV).rgb;
	float rough = s.r;
	vec3 ax = normalize(grain_axis);
	float along = dot(local_pos, ax);
	vec3 across = local_pos - ax * along;
	if (s.b > 0.25 && s.b < 0.75) {
		// wood: long streaks, darker late wood, slightly rougher between streaks
		float g = noise(across * 70.0 + ax * along * 3.0) * 3.0 + noise(across * 260.0 + ax * along * 9.0) * 0.6;
		float streak = smoothstep(0.25, 0.75, abs(fract(g) * 2.0 - 1.0));
		albedo *= mix(0.84, 1.06, streak);
		rough = clamp(rough + (1.0 - streak) * 0.1, 0.0, 1.0);
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = s.g;
	SPECULAR = 0.5;
	EMISSION = texture(emission_tex, UV).rgb * emission_energy;
}
