extends RefCounted
# Provisional destinations, in metres. Only the active leg is disclosed by the GPS.
const POINTS := [Vector3(6,0,-6),Vector3(120,0,-1450),Vector3(1600,0,-2100),Vector3(2900,0,-900),Vector3(3900,0,-2500),Vector3(3000,0,-4200),Vector3(1000,0,-4800),Vector3(-500,0,-3400)]
const TITLES := ["LAGO CENERE", "PORTO SECCO", "CAVA SILENTE", "BORGO DEL RIPETITORE", "DEPOSITO MILITARE", "DIGA NORD", "CENTRO DI RICERCA", "ULTIMA FREQUENZA"]
# Limiti del mondo: il 4×4 si ferma qui (expedition_car.gd), ma le montagne (edge_rise) fermano tutti prima di arrivarci.
# Allargamento moderato: 900 m di margine oltre la strada, quanto basta per colline e pareti di roccia.
const MIN_X := -1400.0
const MAX_X := 4800.0
const MIN_Z := -5700.0
const MAX_Z := 1000.0
# Le zone sono chiuse da catene di montagne: si passa solo dai valichi sulla statale (world/zona2/zone_gates.gd).
# Zona 1: x < Z1_EAST, z > WALL_Z. Zona 2, il Mare di Sabbia: x < Z2_EAST, Z2_NORTH < z < WALL_Z. Il resto è per le zone dopo.
const Z1_EAST := 600.0
const WALL_Z := -1235.0
const Z2_EAST := 2300.0
const Z2_NORTH := -3000.0
const WALL_HALF := 80.0
const ARENA_MATRIARCA := Vector3(760, 0, -2350)
const ARENA_SIGNORE := Vector3(-560, 0, -1950)
const Village := preload("res://world/villaggio/villaggio_layout.gd")
## Luoghi lungo la strada (world/campaign/roadside_poi.gd). "at" è indicativo: places() li aggancia alla strada vera.
const PLACES := [
	{"at": Vector3(13,0,-787), "kind": "farm", "title": "FATTORIA ISOLATA"},
	{"at": Vector3(175,0,-1155), "kind": "crash", "title": "INCIDENTE"},
	{"at": Vector3(474,0,-1649), "kind": "farm", "title": "FATTORIA ISOLATA"},
	{"at": Vector3(948,0,-1776), "kind": "gas", "title": "STAZIONE DI SERVIZIO"},
	{"at": Vector3(1304,0,-1970), "kind": "crash", "title": "INCIDENTE"},
	{"at": Vector3(1963,0,-1711), "kind": "camp", "title": "CAMPEGGIO"},
	{"at": Vector3(2406,0,-1356), "kind": "bridge", "title": "PONTE"},
	{"at": Vector3(2729,0,-1106), "kind": "ruin", "title": "CASCINA BRUCIATA"},
	{"at": Vector3(3200,0,-1380), "kind": "mil", "title": "POSTO DI BLOCCO MILITARE"},
	{"at": Vector3(3532,0,-1840), "kind": "farm", "title": "FATTORIA ISOLATA"},
	{"at": Vector3(3750,0,-2260), "kind": "crash", "title": "INCIDENTE"},
	{"at": Vector3(3705,0,-2941), "kind": "gas", "title": "STAZIONE DI SERVIZIO"},
	{"at": Vector3(3371,0,-3417), "kind": "ruin", "title": "CASCINA BRUCIATA"},
	{"at": Vector3(3180,0,-3860), "kind": "bridge", "title": "PONTE"},
	{"at": Vector3(2600,0,-4320), "kind": "mil", "title": "POSTO DI BLOCCO MILITARE"},
	{"at": Vector3(2011,0,-4538), "kind": "camp", "title": "CAMPEGGIO"},
	{"at": Vector3(1389,0,-4644), "kind": "farm", "title": "FATTORIA ISOLATA"},
	{"at": Vector3(625,0,-4450), "kind": "crash", "title": "INCIDENTE"},
	{"at": Vector3(276,0,-4072), "kind": "farm", "title": "FATTORIA ISOLATA"},
	{"at": Vector3(-150,0,-3776), "kind": "gas", "title": "STAZIONE DI SERVIZIO"},
]
const ON_ROAD := ["crash", "mil", "bridge"]
const PLACE_SETBACK := 38.0   # i luoghi fuori strada stanno a questa distanza dalla mezzeria
const BRIDGE_HUMP := 3.2      # la strada sale sul ponte; il greto resta sopra y = -1, dove scatta il recupero
const BRIDGE_BED := -0.6
const SITE_CELL := 256.0
static var _site_cells: Dictionary = {}
static var _places: Array = []
static var _bridges: Array = []
static var _edge_noise: FastNoiseLite
static var _ridge_noise: FastNoiseLite

const PolylineIndex := preload("res://world/campaign/polyline_index.gd")
const CURVE_RADIUS := 60.0        # raggio di raccordo sulla statale
const STOP_RADIUS := 26.0         # alle tappe la curva resta stretta: la strada passa davvero dal posto
static var _road: Array = []
static var _index: RefCounted = null

## Il tracciato di progetto: gli angoli, prima di arrotondarli. I lavori sulla strada aggiungono punti qui.
static func road_corners() -> Array:
	return [POINTS[0],Vector3(6,0,-145),Vector3(130,0,-260),Vector3(230,0,-420),Vector3(85,0,-540),Vector3(-90,0,-720),Vector3(60,0,-900),Vector3(250,0,-1060),Vector3(100,0,-1250)]+POINTS.slice(1)

## La strada vera, densa e senza spigoli: tutto (asfalto, erba, alberi, 4×4) usa questa.
static func road_points() -> Array:
	if _road.is_empty():
		_road = round_corners(_meander(road_corners()), CURVE_RADIUS, POINTS)
	return _road

## I rettilinei lunghi non sono tirati col righello: ondeggiano un po', sempre allo stesso modo.
static func _meander(corners: Array) -> Array:
	var out: Array = [corners[0]]
	for i in range(corners.size() - 1):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[i + 1]
		var length := a.distance_to(b)
		# Il primo tratto attraversa il paese e il recinto: resta dritto.
		if i >= 1 and length > 150.0:
			var side := Vector3(-(b - a).z, 0, (b - a).x).normalized()
			var parts := int(length / 95.0)
			for k in range(1, parts):
				var t := float(k) / float(parts)
				var fade := sin(t * PI)
				out.append(a.lerp(b, t) + side * sin(float(k) * 1.9 + float(i) * 2.3) * minf(16.0, length * 0.06) * fade)
		out.append(b)
	return out

## Arrotonda ogni angolo con un arco: i tratti dritti restano dritti e gli estremi non si muovono.
static func round_corners(points: Array, radius: float, tight: Array = []) -> Array:
	if points.size() < 3: return points.duplicate()
	var out: Array = [points[0]]
	for i in range(1, points.size() - 1):
		var v: Vector3 = points[i]
		var before: Vector3 = points[i - 1]
		var after: Vector3 = points[i + 1]
		var r: float = minf(STOP_RADIUS if tight.has(v) else radius, 0.48 * minf(v.distance_to(before), v.distance_to(after)))
		var a: Vector3 = v + (before - v).normalized() * r
		var b: Vector3 = v + (after - v).normalized() * r
		var steps: int = maxi(3, ceili(r * 2.0 / 3.5))
		for k in range(steps + 1):
			var t := float(k) / float(steps)
			out.append(a.lerp(v, t).lerp(v.lerp(b, t), t))
	out.append(points[points.size() - 1])
	return out

static func road_distance(p: Vector2) -> float:
	if _index == null:
		_index = PolylineIndex.new()
		_index.add_line(road_points())
		_index.add_coarse(road_corners())
	return _index.distance(p)

## Distanza dalla tappa o dal luogo più vicino: lì il terreno è in piano e il bosco si apre.
## Chi la usa guarda solo i primi 100 m: oltre SITE_CELL risponde "lontano" e il calcolo del terreno resta rapido.
static func site_distance(p: Vector2) -> float:
	if _site_cells.is_empty():
		var sites:Array=POINTS.duplicate()+[ARENA_MATRIARCA,ARENA_SIGNORE]
		for place in places(): sites.append(place.at)
		for point in sites:
			var at:=Vector2(point.x,point.z)
			var center:=Vector2i(floori(at.x/SITE_CELL),floori(at.y/SITE_CELL))
			for x in range(-1,2):
				for z in range(-1,2):
					var key:=center+Vector2i(x,z)
					if not _site_cells.has(key): _site_cells[key]=[]
					_site_cells[key].append(at)
	var distance:=SITE_CELL
	for at in _site_cells.get(Vector2i(floori(p.x/SITE_CELL),floori(p.y/SITE_CELL)),[]):
		distance=minf(distance,p.distance_to(at))
	return distance

static func inside(p: Vector3) -> bool:
	return p.x>MIN_X and p.x<MAX_X and p.z>MIN_Z and p.z<MAX_Z

## I luoghi agganciati alla strada vera: sulla mezzeria chi sta in strada, a PLACE_SETBACK di lato gli altri.
static func places() -> Array:
	if _places.is_empty():
		for place in PLACES:
			var road_at:=nearest_road(place.at)
			var at:=road_at
			if not place.kind in ON_ROAD:
				at=road_at+(Vector3(place.at.x,0,place.at.z)-road_at).normalized()*PLACE_SETBACK
			_places.append({"at":at,"kind":place.kind,"title":place.title,"dir":road_direction(road_at)})
	return _places

## Metri dal limite del mondo più vicino (negativo fuori).
static func edge_distance(x: float, z: float) -> float:
	return minf(minf(x-MIN_X,MAX_X-x),minf(z-MIN_Z,MAX_Z-z))

## Quanto si alza il terreno verso il bordo: colline, poi una parete di roccia troppo ripida per salire a piedi o in auto,
## poi le creste. La parete sta tutta dentro i limiti, quindi nessuno arriva mai al blocco del 4×4.
static func edge_rise(x: float, z: float) -> float:
	var wall:=zone_wall(x,z)
	var d:=edge_distance(x,z)
	if d>660.0: return wall
	if _edge_noise==null:
		_edge_noise=FastNoiseLite.new();_edge_noise.seed=4242;_edge_noise.frequency=0.002;_edge_noise.fractal_type=FastNoiseLite.FRACTAL_NONE
		_ridge_noise=FastNoiseLite.new();_ridge_noise.seed=919;_ridge_noise.frequency=0.0065;_ridge_noise.fractal_octaves=3
	var e:=d+_edge_noise.get_noise_2d(x,z)*40.0
	var foothill:=1.0-smoothstep(170.0,610.0,e)
	var cliff:=1.0-smoothstep(130.0,178.0,e)
	var crest:=1.0-smoothstep(20.0,135.0,e)
	# La parete ondulata si può risalire in diagonale: questa seconda, parallela al limite e dietro le creste, non si aggira.
	var last_wall:=1.0-smoothstep(72.0,100.0,d)
	return foothill*48.0+cliff*85.0+crest*(70.0+90.0*(1.0-absf(_ridge_noise.get_noise_2d(x,z))*2.0))+last_wall*70.0+wall

## Metri dalla catena di montagne più vicina tra le zone.
static func wall_distance(x: float, z: float) -> float:
	var d:=INF
	if z>WALL_Z: d=minf(d,absf(x-Z1_EAST)+maxf(0.0,z-MAX_Z))
	else: d=minf(d,sqrt(pow(x-Z1_EAST,2)+pow(z-WALL_Z,2)))
	d=minf(d,absf(z-WALL_Z)+maxf(0.0,x-Z2_EAST))
	if z<WALL_Z and z>Z2_NORTH: d=minf(d,absf(x-Z2_EAST))
	else: d=minf(d,sqrt(pow(x-Z2_EAST,2)+pow(z-clampf(z,Z2_NORTH,WALL_Z),2)))
	d=minf(d,absf(z-Z2_NORTH)+maxf(0.0,x-Z2_EAST))
	return d

## Le montagne fra le zone: pareti che a piedi e in auto non si salgono. La statale le attraversa in una gola stretta.
static func zone_wall(x: float, z: float) -> float:
	var d:=wall_distance(x,z)
	if d>=WALL_HALF: return 0.0
	if _edge_noise==null:
		_edge_noise=FastNoiseLite.new();_edge_noise.seed=4242;_edge_noise.frequency=0.002;_edge_noise.fractal_type=FastNoiseLite.FRACTAL_NONE
		_ridge_noise=FastNoiseLite.new();_ridge_noise.seed=919;_ridge_noise.frequency=0.0065;_ridge_noise.fractal_octaves=3
	var body:=1.0-smoothstep(28.0,WALL_HALF,d)
	var pass_open:=smoothstep(13.0,46.0,road_distance(Vector2(x,z)))
	return body*pass_open*(120.0+70.0*(0.5+_ridge_noise.get_noise_2d(x,z)))

## Quanto è deserto questo punto (1 = sabbia piena). Finisce sul versante interno delle montagne.
static func desert(x: float, z: float) -> float:
	var d:=maxf(maxf(x-Z2_EAST,MIN_X-x),maxf(z-WALL_Z,Z2_NORTH-z))
	return 1.0-smoothstep(-50.0,-6.0,d)

## Dove la statale attraversa le catene: il primo valico porta nel deserto, il secondo fuori. {at, dir} nel senso di marcia.
static func gates() -> Array:
	var out:Array=[]
	var road:Array=road_points()
	for i in range(road.size()-1):
		var a:Vector3=road[i];var b:Vector3=road[i+1]
		if out.size()==0 and a.z>WALL_Z and b.z<=WALL_Z:
			out.append({"at":a.lerp(b,(a.z-WALL_Z)/(a.z-b.z)),"dir":(b-a).normalized()})
		elif out.size()==1 and a.x<Z2_EAST and b.x>=Z2_EAST:
			out.append({"at":a.lerp(b,(Z2_EAST-a.x)/(b.x-a.x)),"dir":(b-a).normalized()})
	return out

## Forma finale del terreno: aggiunge al rilievo le montagne del bordo e i ponti.
static func shape_height(x: float, z: float, base: float) -> float:
	return _bridge_shape(x,z,base)+edge_rise(x,z)

static func _bridge_shape(x: float, z: float, base: float) -> float:
	if _bridges.is_empty():
		for place in places():
			if place.kind=="bridge": _bridges.append({"at":Vector2(place.at.x,place.at.z),"dir":Vector2(place.dir.x,place.dir.z)})
	var p:=Vector2(x,z)
	for bridge in _bridges:
		var off:Vector2=p-bridge.at
		if off.length_squared()>144.0*144.0: continue
		# Gobba della strada attorno al ponte e canale del torrente che la attraversa.
		var hump:=BRIDGE_HUMP*(1.0-smoothstep(9.0,58.0,off.length()))
		var along:=absf(off.dot(bridge.dir))
		var across:=absf(off.dot(Vector2(-bridge.dir.y,bridge.dir.x)))
		var channel:=(1.0-smoothstep(6.0,15.0,along))*smoothstep(4.6,9.0,across)*(1.0-smoothstep(96.0,136.0,across))
		return lerpf(base+hump,BRIDGE_BED,channel)
	return base

## Direzione della strada nel punto più vicino a "at", nel senso di marcia.
static func road_direction(at: Vector3) -> Vector3:
	var road:Array=road_points()
	var best:=INF;var result:=Vector3.FORWARD
	var flat:=Vector3(at.x,0,at.z)
	for i in range(road.size()-1):
		var a:Vector3=road[i];var b:Vector3=road[i+1]
		if a.is_equal_approx(b): continue
		var point:Vector3=a+(b-a)*clampf((flat-a).dot(b-a)/(b-a).length_squared(),0,1)
		if flat.distance_squared_to(point)<best: best=flat.distance_squared_to(point);result=(b-a).normalized()
	return result

## Cartelli stradali con le distanze: subito dopo ogni tappa, sul lato destro, le prossime due.
static func road_signs() -> Array:
	var signs:Array=[]
	for i in range(1,POINTS.size()-1):
		var from:Vector3=POINTS[i];var to:Vector3=POINTS[i+1]
		var road_at:=nearest_road(from+(to-from).normalized()*62.0)
		var dir:=road_direction(road_at)
		var lines:Array=["%s  %s km"%[TITLES[i+1],_km(from.distance_to(to))]]
		if i+2<POINTS.size():
			lines.append("%s  %s km"%[TITLES[i+2],_km(from.distance_to(to)+to.distance_to(POINTS[i+2]))])
		signs.append({"at":road_at+dir.cross(Vector3.UP)*7.5,"yaw":atan2(-dir.x,-dir.z),"lines":lines})
	return signs

static func _km(metres: float) -> String:
	return ("%.1f"%(metres/1000.0)).replace(".",",")

## Luogo vicino per il GPS: il borgo o un punto lungo la strada, entro "radius" metri. Vuoto se non c'è niente.
static func nearby_place(at: Vector3, radius: float = 450.0) -> Dictionary:
	var best:={}
	var flat:=Vector3(at.x,0,at.z)
	var distance:=flat.distance_to(Village.CENTER)
	if distance<radius: best={"title":"BORGO CENERE","distance":distance}
	for place in places():
		var away:float=flat.distance_to(place.at)
		if away<radius and (best.is_empty() or away<best.distance): best={"title":place.title,"distance":away}
	return best

static func nearest_road(p:Vector3) -> Vector3:
	var result:Vector3=POINTS[0];var distance:=INF
	var road:Array=road_points()
	for i in range(road.size()-1):
		var a:Vector3=road[i];var b:Vector3=road[i+1]
		var flat:=Vector3(p.x,0,p.z)
		var point:Vector3=a+(b-a)*clampf((flat-a).dot(b-a)/(b-a).length_squared(),0,1)
		if flat.distance_squared_to(point)<distance: distance=flat.distance_squared_to(point);result=point
	return result
