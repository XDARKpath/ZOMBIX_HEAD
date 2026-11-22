extends RefCounted
# Rete stradale della Zona 1: strade secondarie che si staccano dalla statale.
# Ogni strada collega due posti (statale, pista, Borgo, Rocca, radure): niente vicoli
# ciechi nel nulla. Seed fisso: la mappa è sempre la stessa.
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
## Radura del Capomacello, il primo boss: lontana dal rifugio (6, -12), oltre la vecchia pista.
const BOSS_ARENA := Vector3(-74, 0, -292)
## Dove la via est del Borgo entra in piazza (villaggio.gd: CENTER.x + PLAZA).
const VILLAGE_PLAZA_X := 113.5
## Fattore di larghezza dell'asfalto della via del Borgo: 7 m come la statale (la via è larga 9 m, restano i bordi).
const VILLAGE_STREET_WIDTH := 1.6
## Celle della griglia del terreno tolte dove si apre la scala della Rocca (x, z, larghezza, profondità): rocca.gd richiude attorno alla bocca.
const TERRAIN_HOLE := Rect2(-240, -248, 16, 8)
static var _cache: Dictionary = {}

static func data() -> Dictionary:
	if not _cache.is_empty(): return _cache
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	# Ogni strada parte da un incrocio e arriva in un posto: niente rami che finiscono nel nulla.
	#   0 Vecchia pista: dal posto di blocco sulla curva della statale, nel bosco, fino al campo profughi di Borgo Cenere.
	#   1 Sentiero del Capomacello: si stacca dalla pista e si ferma all'anello di rocce della radura.
	#   2 Strada della gola: dalla statale alla radura della gola, a est.
	#   3 Strada della Rocca: dalla statale, accanto alla fattoria, fino alla torre.
	#   4 Dentro il recinto, dalla statale al portone est.
	#   5 Via del Borgo: dalla statale, attraverso il posto di blocco del paese, fino alla piazza.
	var paths: Array = []
	var arenas: Array = []
	# La pista lascia la statale a quasi 60° verso ovest (bivio netto, senza cuneo d'asfalto), poi piega a nord.
	paths.append([Vector3(8, 0, -100), Vector3(-10, 0, -110), Vector3(-16, 0, -136), Vector3(-12, 0, -166),
		Vector3(-4, 0, -196), Vector3(-3, 0, -226), Vector3(-12, 0, -254), Vector3(-22, 0, -282),
		Vector3(-24, 0, -315), Vector3(-20, 0, -348), Vector3(-17, 0, -366), Vector3(-18, 0, -381)])
	# Il Capomacello: nel bosco a nord-ovest, quasi 300 m dal rifugio. Ci si arriva solo dopo pista e radura dei morti.
	var forest := BOSS_ARENA
	arenas.append(forest)
	var spur: Array = [Vector3(-22, 0, -283), Vector3(-40, 0, -289)]
	spur.append(forest + (spur[spur.size() - 1] - forest).normalized() * FOREST_STOP)
	paths.append(spur)
	# Stessa sequenza di semi di prima: la strada della gola e il viale del portone non cambiano forma.
	_branch(rng, Vector3(6, 0, -58), Vector3(-58, 0, -86), 3)
	var east := _branch(rng, Vector3(6, 0, -78), Vector3(72, 0, -108), 3)
	east.append(Vector3(108, 0, -96))
	arenas.append(east[east.size() - 1])
	paths.append(east)
	# La radura dei morti sta accanto alla pista, non sopra: il baule resta fuori dall'asfalto.
	_branch(rng, Vector3(8, 0, -158), Vector3(6, 0, -212), 2)
	arenas.append(Vector3(16, 0, -206))
	_branch(rng, Vector3(-58, 0, -86), Vector3(-30, 0, -150), 2)
	_branch(rng, Vector3(72, 0, -108), Vector3(44, 0, -170), 2)
	var gate := _branch(rng, Vector3(6, 0, -36), Vector3(38, 0, -34), 2)
	_branch(rng, Vector3(68, 0, -202.5), Vector3(150, 0, -176), 3)
	# Strada della Rocca: un nastro solo e senza zig-zag dalla statale alla torre, accanto alla fattoria in mattoni (-30, -122).
	# Prima il bivio ovest aveva un moncone verso la vecchia radura e la strada tornava indietro verso est.
	paths.append([Vector3(6, 0, -58), Vector3(-28, 0, -68), Vector3(-44, 0, -92), Vector3(-47, 0, -122), Vector3(-62, 0, -158),
		Vector3(-96, 0, -188), Vector3(-130, 0, -208), Vector3(-170, 0, -226), Vector3(-205, 0, -241), SITES["dungeon"] + Vector3(15, 0, 0)])
	paths.append(gate)
	# La via est del Borgo è asfaltata come la statale da cui arriva: un'unica strada fino alla piazza.
	paths.append([Vector3(208, 0, -385), Vector3(184, 0, -385), Vector3(VILLAGE_PLAZA_X, 0, -385)])
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
