shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying float blade_height;
varying vec3 blade_world;
varying float blade_seed;

void vertex() {
	blade_height = UV.y;
	blade_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	blade_seed = fract(sin(dot(blade_world.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float gust = sin(TIME * 0.4 + blade_world.x * 0.035 + blade_world.z * 0.025) * 0.5 + 0.5;
	float sway = sin(TIME * 1.3 + blade_world.x * 0.55 + blade_world.z * 0.35 + blade_seed * 6.283) * 0.5;
	sway += sin(TIME * 2.2 + blade_world.z * 0.9) * 0.15;
	float bend = blade_height * blade_height;
	float strength = (0.030 + gust * 0.045) * (0.7 + blade_seed * 0.6);
	VERTEX.x += sway * strength * bend + gust * 0.022 * bend;
	VERTEX.z += sway * 0.024 * bend;
	VERTEX.y -= abs(sway) * bend * 0.006;
}

void fragment() {
	vec3 tint = COLOR.rgb;
	vec3 root = mix(vec3(0.045, 0.090, 0.040), tint * 0.55, 0.40);
	vec3 tip = mix(vec3(0.24, 0.38, 0.14), tint, 0.55);
	vec3 albedo = mix(root, tip, smoothstep(0.0, 1.0, blade_height));
	albedo *= 0.92 + blade_seed * 0.22;
	ALBEDO = albedo;
	ROUGHNESS = 0.90;
	SPECULAR = 0.10;
	BACKLIGHT = mix(vec3(0.12, 0.20, 0.06), tint * 0.65, 0.5) * blade_height;
	AO = mix(0.62, 1.0, blade_height);
	AO_LIGHT_AFFECT = 0.30;
}
