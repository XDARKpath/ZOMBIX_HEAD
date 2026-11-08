shader_type spatial;
// Vento unico per erba, fiori e cespugli: stessa fase, stessa direzione.
// La sommità della pianta si muove, la base resta piantata a terra.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float sway = 0.09;
uniform float speed = 1.5;
uniform float bend_start = 0.10;
uniform float bend_height = 0.70;
uniform bool use_texture = true;
uniform float fade = 0.22;

void vertex() {
	float h = clamp((VERTEX.y - bend_start) / max(bend_height, 0.01), 0.0, 1.0);
	h *= h;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = TIME * speed + world.x * 0.75 + world.z * 0.55;
	VERTEX.x += sin(phase) * sway * h;
	VERTEX.z += cos(phase * 0.73) * sway * 0.55 * h;
}

void fragment() {
	vec4 c = vec4(1.0);
	if (use_texture) c = texture(albedo_tex, UV);
	c *= tint;
	if (c.a < 0.35) discard;
	// I modelli CC0 sono molto saturi: li riporto al verde spento del lago.
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(c.rgb, vec3(lum) * vec3(0.9, 0.94, 0.84), fade);
	ROUGHNESS = 0.93;
	SPECULAR = 0.12;
}
