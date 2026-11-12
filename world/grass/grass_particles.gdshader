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
// Ogni specie ha la sua griglia sfalsata e cresce solo nella sua fascia di macchie.
uniform float seed_shift = 0.0;
uniform vec2 patch_band = vec2(0.0, 1.0);
// Le specie rare (cespugli, felci, fiori) hanno macchie loro: non crescono tutte nello stesso punto.
uniform float patch_offset = 0.0;
// Quanto si piega ogni ciuffo da un lato (0 = tutti dritti come soldatini).
uniform float lean = 0.0;
// Strato lontano: vuoto vicino al giocatore, dove ci sono già i ciuffi veri.
uniform float inner = 0.0;
// Vento a onde che attraversano il prato (direzione xz, forza in metri di piega per metro d'altezza).
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind = 0.16;
// Chi passa nel prato (giocatori, zombie): xyz posizione, w raggio; w = 0 slot vuoto.
uniform vec4 pushers[8];
// 1 = erba morbida, meno = cespugli rigidi.
uniform float stiff = 1.0;


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
	// Ogni particella possiede una cella fissa del mondo (griglia toroidale): quando il giocatore
	// avanza si ricicla solo la fila che esce dal bordo, invisibile. Prima tutte le particelle
	// passavano alla cella accanto a ogni scatto e, interpolate e col TAA, i ciuffi si deformavano.
	vec2 center = EMISSION_TRANSFORM[3].xz;
	vec2 first = floor(center / spacing) - floor(float(rows) * 0.5);
	vec2 cell = first + mod(vec2(float(i % rows), float(i / rows)) - first, float(rows));
	vec2 p = cell * spacing + seed_shift * spacing;
	vec2 seed = p + seed_shift * 31.7;
	p += (vec2(hash(seed), hash(seed + 7.13)) - 0.5) * spacing * 0.9;
	vec2 uv = (p - bounds.xy) / bounds.zw;
	float d = 0.0;
	if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) d = texture(density, uv).r;
	float fade = 1.0 - smoothstep(radius * 0.72, radius, length(p - center));
	if (inner > 0.0) fade *= smoothstep(inner * 0.6, inner, length(p - center));
	vec2 pp = p + patch_offset;
	float patchy = vnoise(pp * patch_scale) * 0.65 + vnoise(pp * patch_scale * 3.1 + 5.0) * 0.35;
	d *= keep < 1.0 ? smoothstep(0.55, 0.8, patchy) * keep * 6.0 : mix(0.7, 1.0, smoothstep(0.25, 0.6, patchy));
	d *= smoothstep(patch_band.x - 0.08, patch_band.x + 0.08, patchy) * (1.0 - smoothstep(patch_band.y - 0.08, patch_band.y + 0.08, patchy));
	float s = hash(seed * 1.31 + 3.0) < d ? mix(scale_range.x, scale_range.y, hash(seed + 11.0)) * fade : 0.0;
	float a = hash(seed + 5.0) * 6.2831853;
	// Altezza a macchie: ciuffi alti in gruppi, più bassi ai margini del prato.
	s *= mix(0.55, 1.0, smoothstep(0.05, 0.6, d));
	float tall = s * mix(tall_range.x, tall_range.y, hash(seed + 2.0)) * mix(0.6, 1.25, smoothstep(0.2, 0.75, patchy));
	float y = ground(p);
	// Vento: raffiche che scorrono lungo wind_dir, più un tremolio per ciuffo.
	float front = dot(p, wind_dir);
	float gust = sin(front * 0.11 - TIME * 1.3) * 0.5 + 0.5;
	gust = gust * gust * 0.8 + 0.2 + sin(TIME * 2.3 + hash(seed + 21.0) * 6.28) * 0.12;
	vec2 bend = wind_dir * wind * gust * stiff;
	// Chi cammina nel prato apre l'erba intorno a sé: i ciuffi si piegano via e si abbassano.
	vec2 push = vec2(0.0);
	for (int k = 0; k < 8; k++) {
		vec4 q = pushers[k];
		vec2 off = p - q.xz;
		float dist = length(off);
		if (q.w <= 0.0 || dist > q.w || abs(q.y - y) > 1.6) continue;
		push += off / max(dist, 0.05) * (1.0 - smoothstep(q.w * 0.25, q.w, dist));
	}
	// Memoria per ciuffo (la cella è fissa, quindi resta suo): si piega in fretta e si rialza piano.
	if (any(notEqual(USERDATA1.zw, cell))) USERDATA1 = vec4(0.0, 0.0, cell);
	float rate = dot(push, push) > dot(USERDATA1.xy, USERDATA1.xy) ? 14.0 : 1.8;
	USERDATA1.xy = mix(USERDATA1.xy, push, 1.0 - exp(-DELTA * rate));
	vec2 pressed = USERDATA1.xy;
	float down = clamp(length(pressed), 0.0, 1.0) * stiff;
	bend += pressed / max(length(pressed), 1.0) * 1.1 * stiff;
	bend += (vec2(hash(seed + 13.0), hash(seed + 17.0)) - 0.5) * 2.0 * lean;
	TRANSFORM = mat4(
		vec4(cos(a) * s, 0.0, -sin(a) * s, 0.0),
		vec4(bend.x * tall, tall * (1.0 - 0.55 * down), bend.y * tall, 0.0),
		vec4(sin(a) * s, 0.0, cos(a) * s, 0.0),
		vec4(p.x, y + 0.03, p.y, 1.0));
	COLOR = vec4(hash(seed + 9.0), d, patchy, 1.0);
}
