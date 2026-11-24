shader_type sky;
// Cielo del tardo pomeriggio: blu-viola in alto, orizzonte arancio verso il sole e rosa dall'altra parte,
// grandi nuvole stirate color salmone, accese da sotto e più scure sul dorso. Tutto procedurale.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);   // quintica: niente spigoli fra le celle
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + 1.0), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	// Ogni ottava ruotata: niente quadretti allineati agli assi.
	mat2 turn = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 6; i++) { v += a * noise(p); p = turn * p * 2.03 + vec2(13.7, -7.1); a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = max(d.y, 0.0);
	// Quanto si guarda verso il sole (solo in orizzontale): da lì il cielo si scalda.
	vec2 flat_sun = normalize(LIGHT0_DIRECTION.xz + vec2(0.0001));
	float toward = dot(normalize(d.xz + vec2(0.0001)), flat_sun) * 0.5 + 0.5;
	vec3 zenith = vec3(0.18, 0.28, 0.60);
	vec3 horizon = mix(vec3(0.80, 0.55, 0.52), vec3(0.98, 0.45, 0.16), toward * toward);
	vec3 c = mix(horizon, zenith, pow(h, 0.42));
	// Fascia calda appena sopra l'orizzonte, più forte dietro al sole.
	c += vec3(1.0, 0.42, 0.12) * exp(-h * 9.0) * (0.25 + 0.55 * toward);
	// Nuvole: strisce lunghe (stirate in x), poche e grandi, che scorrono piano.
	vec2 uv = d.xz / (h + 0.25) * vec2(0.45, 1.1) + vec2(TIME * 0.003, 0.0);
	// Il dominio deformato toglie le linee dritte: le nuvole si gonfiano e si sfilacciano.
	vec2 warp = vec2(fbm(uv * 0.7 + 3.1), fbm(uv * 0.7 + 8.4)) - 0.5;
	uv += warp * 1.4;
	float n = fbm(uv * 1.3);
	float cover = smoothstep(0.42, 0.70, n) * smoothstep(0.02, 0.18, h) * (1.0 - smoothstep(0.65, 0.95, h));
	float thick = smoothstep(0.55, 0.85, fbm(uv * 1.3 + vec2(0.0, 0.08)));
	vec3 lit = mix(vec3(0.95, 0.42, 0.22), vec3(1.0, 0.55, 0.24), toward);
	vec3 shade = vec3(0.55, 0.42, 0.52);
	c *= 0.86;
	c = mix(c, mix(lit, shade, thick * 0.5), cover * 0.95);
	// Disco del sole e alone.
	float sun = max(dot(d, LIGHT0_DIRECTION), 0.0);
	c += vec3(1.0, 0.55, 0.22) * (pow(sun, 12.0) * 0.35 + pow(sun, 900.0) * 4.0);
	// Sotto l'orizzonte: foschia calda (le montagne la coprono quasi sempre).
	if (d.y < 0.0) c = mix(horizon, vec3(0.55, 0.45, 0.40), clamp(-d.y * 3.0, 0.0, 1.0));
	COLOR = c;
}
