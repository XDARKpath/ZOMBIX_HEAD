extends RefCounted
# Rete stradale della Zona 1: si stacca dalla strada principale e si ramifica
# nel bosco. Non è una via unica: alcuni rami finiscono in vicoli ciechi, altri
# portano alle arene dei custodi. Seed fisso: la mappa è sempre la stessa, ma
# non è una linea dritta.
const SEED := 7331
const WIDTH := 4.4
const START := Vector3(6, 0, -12)
## Luoghi della Zona 1: Borgo Cenere (world/villaggio) e la Rocca.
const SITES := {"village": Vector3(95, 0, -385), "dungeon": Vector3(-230, 0, -245)}
const SITE_RADIUS := 32.0
const TOWER_CLEARING := 15.0
const CURVE_RADIUS := 22.0
## Il sentiero del bosco si ferma a questa distanza dal centro della radura: fuori dall'anello di rocce.
const FOREST_STOP := 24.0
## Celle della griglia del terreno tolte dove si apre la scala della Rocca (x, z, larghezza, profondità): rocca.gd richiude attorno alla bocca.
const TERRAIN_HOLE := Rect2(-240, -248, 16, 8)
static var _cache: Dictionary = {}

static func data() -> Dictionary:
	if not _cache.is_empty(): return _cache
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var paths: Array = []
	var arenas: Array = []
	# Pista: nasce dalla statale dove questa piega a est e prosegue dritta nel bosco. Prima correva sopra la statale.
	var trunk: Array = [Vector3(6, 0, -118), Vector3(8, 0, -158)]
	paths.append(trunk)
	# Ramo ovest: si perde tra i pini e FINISCE PRIMA della radura del Capomacello, all'imbocco tra le rocce.
	var west := _branch(rng, Vector3(6, 0, -58), Vector3(-58, 0, -86), 3)
	var forest := Vector3(-96, 0, -112)
	arenas.append(forest)
	west.append(forest + (west[west.size() - 1] - forest).normalized() * FOREST_STOP)
	paths.append(west)
	# Ramo est: curva larga verso la gola.
	var east := _branch(rng, Vector3(6, 0, -78), Vector3(72, 0, -108), 3)
	east.append(Vector3(108, 0, -96))
	arenas.append(east[east.size() - 1])
	paths.append(east)
	# La pista continua a sud fino alla radura: un''unica strada, senza giunte.
	var south := _branch(rng, Vector3(8, 0, -158), Vector3(6, 0, -212), 2)
	arenas.append(south[south.size() - 1])
	trunk.append_array(south.slice(1))
	# Rami secondari: servono a perdersi. Il primo porta alla fattoria e prosegue fino alla Rocca.
	var farm := _branch(rng, Vector3(-58, 0, -86), Vector3(-30, 0, -150), 2)
	paths.append(farm)
	paths.append(_branch(rng, Vector3(72, 0, -108), Vector3(44, 0, -170), 2))
	# Dentro il recinto, dalla statale al portone est.
	paths.append(_branch(rng, Vector3(6, 0, -36), Vector3(38, 0, -34), 2))
	# Il ramo del vecchio villaggio non c''è più: si calcola lo stesso per lasciare identiche le strade che seguono.
	_branch(rng, Vector3(68, 0, -202.5), Vector3(150, 0, -176), 3)
	# Bretella dalla statale al posto di blocco di Borgo Cenere.
	paths.append([Vector3(208, 0, -385), Vector3(184, 0, -385)])
	# Oltre la fattoria, attraverso il bosco, fino davanti alla torre della Rocca.
	var dungeon := _branch(rng, Vector3(-30, 0, -150), Vector3(-120, 0, -205), 3)
	dungeon.append_array([Vector3(-170, 0, -226), Vector3(-205, 0, -241), SITES["dungeon"] + Vector3(15, 0, 0)])
	farm.append_array(dungeon.slice(1))
	_cache = {"paths": _rounded(paths), "arenas": arenas}
	return _cache

## Curve morbide su tutte le strade; chi si stacca da un''altra strada parte esattamente dal suo bordo arrotondato.
static func _rounded(paths: Array) -> Array:
	const Route := preload("res://world/campaign/route.gd")
	var out: Array = []
	for path in paths:
		var line: Array = Route.round_corners(path, CURVE_RADIUS)
		var start: Vector3 = line[0]
		if Route.road_distance(Vector2(start.x, start.z)) < 12.0:
			line[0] = Route.nearest_road(start)
		else:
			var best := INF
			for other in out:
				for i in range(other.size() - 1):
					var a: Vector3 = other[i]
					var b: Vector3 = other[i + 1]
					var t := clampf((start - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
					var on: Vector3 = a + (b - a) * t
					if on.distance_squared_to(start) < best:
						best = on.distance_squared_to(start)
						line[0] = on
		out.append(line)
	return out

static func _branch(rng: RandomNumberGenerator, from: Vector3, to: Vector3, steps: int) -> Array:
	var points: Array = [from]
	var span := to - from
	var side := Vector3(-span.z, 0, span.x).normalized()
	for i in range(1, steps):
		var t := float(i) / steps
		points.append(from + span * t + side * rng.randf_range(-9.0, 9.0) + Vector3(0, 0, rng.randf_range(-5.0, 5.0)))
	points.append(to)
	return points

static func paths() -> Array:
	return data()["paths"]

static func arenas() -> Array:
	return data()["arenas"]

static var _index: RefCounted = null

static func distance(p: Vector2) -> float:
	if _index == null:
		_index = preload("res://world/campaign/polyline_index.gd").new()
		for path in paths():
			_index.add_line(path)
			_index.add_coarse([path[0], path[path.size() - 1]])
	return _index.distance(p)

## Quanto è lontano il punto dall'area da tenere sgombra di alberi: tutto il villaggio, solo la radura della torre.
static func clearing_distance(p: Vector2) -> float:
	var village := p.distance_to(Vector2(SITES["village"].x, SITES["village"].z)) - 29.0
	var tower := p.distance_to(Vector2(SITES["dungeon"].x, SITES["dungeon"].z)) - TOWER_CLEARING
	return minf(village, tower)


static func in_terrain_hole(x: float, z: float) -> bool:
	return TERRAIN_HOLE.has_point(Vector2(x + 0.5, z + 0.5))


## Attorno alla torre della Rocca non compaiono infetti: lì c'è Bruno.
static func safe_ring(p: Vector2) -> bool:
	return p.distance_to(Vector2(SITES["dungeon"].x, SITES["dungeon"].z)) < TOWER_CLEARING + 4.0


static func site_distance(p: Vector2) -> float:
	var best := INF
	for key in SITES:
		best = minf(best, p.distance_to(Vector2(SITES[key].x, SITES[key].z)))
	return best

## Incroci: estremi di un ramo che toccano un'altra strada (statale o rete del bosco).
static func junctions() -> Array:
	if _cache.has("junctions"): return _cache["junctions"]
	var out: Array = []
	var all: Array = paths()
	for index in all.size():
		var path: Array = all[index]
		for end in [path[0], path[path.size() - 1]]:
			var flat := Vector2(end.x, end.z)
			var on_road: bool = preload("res://world/campaign/route.gd").road_distance(flat) < 1.0
			for other in all.size():
				if other != index and _path_distance(all[other], flat) < 1.0: on_road = true
			if on_road: out.append(end)
	_cache["junctions"] = out
	return out

static func junction_distance(p: Vector2) -> float:
	var best := INF
	for at in junctions(): best = minf(best, p.distance_to(Vector2(at.x, at.z)))
	return best

static func _path_distance(path: Array, p: Vector2) -> float:
	var best := INF
	for i in range(path.size() - 1):
		var a := Vector2(path[i].x, path[i].z)
		var ab := Vector2(path[i + 1].x, path[i + 1].z) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

static func arena_distance(p: Vector2) -> float:
	var best := INF
	for arena in arenas():
		best = minf(best, p.distance_to(Vector2(arena[0], arena[2])))
	return best
