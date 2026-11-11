// Porting Godot 4 di grass-particle.gdshader (AndreVallestero/godot-grass-shader, MIT;
// tecnica di Bastiaan Olij). Ogni particella è un ciuffo su una griglia che segue il
// giocatore a passi fissi, quindi l'erba non scivola mentre ci si muove.
shader_type particles;
render_mode disable_velocity, disable_force;

uniform int rows = 170;
uniform float spacing = 0.42;
uniform float radius = 34.0;
// Altezze ai vertici della griglia del terreno (8 m), triangolate come la mesh.
uniform sampler2D heights : filter_nearest, repeat_disable;
uniform vec2 height_origin;
uniform float height_cell = 8.0;
uniform ivec2 height_size;
// Densità 0..1: strade, edifici, acqua e chiazze di terra restano spogli.
uniform sampler2D density : filter_linear, repeat_disable;
uniform vec4 bounds; // x0, z0, larghezza, profondità
uniform vec2 scale_range = vec2(0.55, 1.2);
uniform vec2 tall_range = vec2(0.75, 1.35);
// Frazione di punti tenuti (fiori: pochi) e macchie irregolari a bassa frequenza,
// così la vegetazione cresce a gruppi spontanei e non a scacchiera.
uniform float keep = 1.0;
uniform float patch_scale = 0.09;


float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}


float corner(ivec2 c) {
	return texelFetch(heights, clamp(c, ivec2(0), height_size - ivec2(1)), 0).r;
}

float ground(vec2 p) {
	vec2 g = (p - height_origin) / height_cell;
	ivec2 c = ivec2(floor(g));
	vec2 f = g - vec2(c);
	float h00 = corner(c);
	float h10 = corner(c + ivec2(1, 0));
	float h01 = corner(c + ivec2(0, 1));
	float h11 = corner(c + ivec2(1, 1));
	if (f.x + f.y <= 1.0) return h00 + (h10 - h00) * f.x + (h01 - h00) * f.y;
	return h11 + (h01 - h11) * (1.0 - f.x) + (h10 - h11) * (1.0 - f.y);
}

void process() {
	int i = int(INDEX);
	vec2 cell = vec2(float(i % rows), float(i / rows)) - float(rows) * 0.5;
	vec2 center = EMISSION_TRANSFORM[3].xz;
	vec2 p = floor(center / spacing) * spacing + cell * spacing;
	vec2 seed = p;
	p += (vec2(hash(seed), hash(seed + 7.13)) - 0.5) * spacing * 0.9;
	vec2 uv = (p - bounds.xy) / bounds.zw;
	float d = 0.0;
	if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) d = texture(density, uv).r;
	float fade = 1.0 - smoothstep(radius * 0.72, radius, length(p - center));
	float patchy = vnoise(p * patch_scale) * 0.65 + vnoise(p * patch_scale * 3.1 + 5.0) * 0.35;
	d *= keep < 1.0 ? smoothstep(0.55, 0.8, patchy) * keep * 6.0 : mix(0.7, 1.0, smoothstep(0.25, 0.6, patchy));
	float s = hash(seed * 1.31 + 3.0) < d ? mix(scale_range.x, scale_range.y, hash(seed + 11.0)) * fade : 0.0;
	float a = hash(seed + 5.0) * 6.2831853;
	// Altezza a macchie: ciuffi alti in gruppi, più bassi ai margini del prato.
	s *= mix(0.55, 1.0, smoothstep(0.05, 0.6, d));
	float tall = s * mix(tall_range.x, tall_range.y, hash(seed + 2.0)) * mix(0.6, 1.25, smoothstep(0.2, 0.75, patchy));
	TRANSFORM = mat4(
		vec4(cos(a) * s, 0.0, -sin(a) * s, 0.0),
		vec4(0.0, tall, 0.0, 0.0),
		vec4(sin(a) * s, 0.0, cos(a) * s, 0.0),
		vec4(p.x, ground(p) + 0.03, p.y, 1.0));
	COLOR = vec4(hash(seed + 9.0), d, patchy, 1.0);
}
