// Porting Godot 4 di grass-spatial.gdshader (AndreVallestero/godot-grass-shader, MIT).
// Aggiunte: vento a onde, tinta per ciuffo (verde spento / secco), base scura.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float alpha_scissor = 0.42;
uniform vec3 green_a : source_color = vec3(0.27, 0.35, 0.15);
uniform vec3 green_b : source_color = vec3(0.42, 0.46, 0.21);
uniform vec3 dry : source_color = vec3(0.45, 0.40, 0.24);
uniform float base_v = 0.64; // riga della texture dove poggia il ciuffo

varying float tip;
varying vec3 tint;

void vertex() {
	tip = clamp(1.0 - UV.y / base_v, 0.0, 1.0);
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Stesse raffiche delle particelle (direzione 0,8; 0,6): il prato lontano ondeggia insieme a quello vicino.
	vec2 wind_dir = vec2(0.8, 0.6);
	float gust = sin(dot(root.xz, wind_dir) * 0.11 - TIME * 1.3) * 0.5 + 0.5;
	float wave = sin(TIME * 3.7 + root.x * 1.1 + root.z * 0.8) * (0.25 + gust);
	float bend = tip * tip;
	VERTEX.xz += wind_dir * wave * 0.1 * bend;
	NORMAL = vec3(0.0, 1.0, 0.0);
	tint = mix(green_a, green_b, COLOR.r);
	tint = mix(tint, dry, smoothstep(0.55, 1.0, COLOR.b) * 0.55);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	float lum = dot(t.rgb, vec3(0.30, 0.59, 0.11));
	ALBEDO = tint * (0.55 + lum * 2.4) * mix(0.45, 1.0, tip);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
}
