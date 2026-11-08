shader_type spatial;
// I modelli KayKit sono molto saturi: qui perdono un po' di colore e prendono
// la polvere del resto del villaggio, restando riconoscibili.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float desaturate = 0.58;
uniform vec3 tint : source_color = vec3(0.80, 0.86, 0.72);
uniform float grime = 0.22;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	// Niente rosso: tende, insegne e fioriere diventano crema/verde.
	float redness = max(0.0, c.r - max(c.g, c.b));
	c.r -= redness * 0.85;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(grey), desaturate) * tint;
	// Sporco leggero verso il basso: i muri non sono mai uniformi.
	c *= 1.0 - grime * smoothstep(0.0, 1.0, 1.0 - UV.y);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.18;
}
