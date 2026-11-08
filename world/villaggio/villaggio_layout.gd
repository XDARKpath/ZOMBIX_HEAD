# BORGO CENERE: dove sta il villaggio. Usato da terrain.gd (terreno piatto, niente alberi casuali dentro)
# e da villaggio.gd. Coordinate del mondo in metri, nord = -Z. La strada del GPS taglia l'angolo sud-est.
extends RefCounted
const CENTER := Vector3(95, 0, -385)
const FLAT := 112.0          # raggio piatto
const BLEND := 160.0         # da qui in poi torna il terreno normale
const KEEP_CLEAR := 122.0    # terrain.gd non mette alberi casuali qui dentro
const WELL_REACH := 5.0      # da qui si accende l'esca nel pozzo della piazza


static func local(x: float, z: float) -> Vector2:
	return Vector2(x - CENTER.x, z - CENTER.z)


## 0 dentro il villaggio, 1 fuori: moltiplica l'altezza delle colline
static func flat(x: float, z: float) -> float:
	return smoothstep(FLAT, BLEND, local(x, z).length())


## Vie e case: qui il prato GPU non cresce, si vede la terra battuta (sennò spunta dai pavimenti).
static func corridor(x: float, z: float) -> bool:
	var p := local(x, z)
	return (absf(p.x) < 30.0 and absf(p.y) < 150.0) or (absf(p.y) < 30.0 and p.x > -150.0 and p.x < 98.0)


static func inside(x: float, z: float, radius: float = KEEP_CLEAR) -> bool:
	return local(x, z).length() < radius
