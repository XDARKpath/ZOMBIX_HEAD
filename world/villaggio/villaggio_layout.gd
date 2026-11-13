# BORGO CENERE: dove sta il villaggio. Usato da terrain.gd (terreno piatto, niente alberi casuali dentro)
# e da villaggio.gd. Coordinate del mondo in metri, nord = -Z. La strada del GPS taglia l'angolo sud-est.
extends RefCounted
const CENTER := Vector3(95, 0, -385)
const FLAT := 112.0          # raggio piatto
const BLEND := 160.0         # da qui in poi torna il terreno normale
const KEEP_CLEAR := 122.0    # terrain.gd non mette alberi casuali qui dentro
const WELL_REACH := 5.0      # da qui si accende l'esca nel pozzo della piazza
## Luoghi di fine via oltre FLAT (x, z locali, raggio): chiesa e cimitero, campo profughi, fattoria, viottolo.
## Qui il terreno resta piatto come in paese, poi le colline tornano con la stessa rampa (BLEND - FLAT).
const SITES := [Vector3(-12, -130, 30), Vector3(-128.5, 0, 24), Vector3(-28, 119, 33), Vector3(24, 121, 14)]


static func local(x: float, z: float) -> Vector2:
	return Vector2(x - CENTER.x, z - CENTER.z)


## 0 dentro il villaggio, 1 fuori: moltiplica l'altezza delle colline
static func flat(x: float, z: float) -> float:
	return smoothstep(FLAT, BLEND, reach(x, z))


## Distanza "dal paese": quella dal centro, oppure FLAT più quanto si è fuori da un luogo di fine via.
static func reach(x: float, z: float) -> float:
	var p := local(x, z)
	var d := p.length()
	for s in SITES:
		d = minf(d, FLAT + maxf(0.0, p.distance_to(Vector2(s.x, s.y)) - s.z))
	return d


## Vie e case: qui il prato GPU non cresce, si vede la terra battuta (sennò spunta dai pavimenti).
static func corridor(x: float, z: float) -> bool:
	var p := local(x, z)
	return (absf(p.x) < 30.0 and absf(p.y) < 150.0) or (absf(p.y) < 30.0 and p.x > -150.0 and p.x < 98.0)


static func inside(x: float, z: float, radius: float = KEEP_CLEAR) -> bool:
	return reach(x, z) < radius
