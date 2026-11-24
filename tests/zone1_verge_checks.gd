extends SceneTree
# Ciglio della Zona 1: niente piante sull'asfalto, niente cactus nel bosco, erba fino al bordo dei rami,
# prato su tutta la statale della zona, buca del 4×4 in dissolvenza, ciglio rado con un solo posto di blocco
# voluto, imbocchi netti, niente banchina di sabbia, accessi in terra battuta a edifici e radure.
# godot --path . -s res://tests/zone1_verge_checks.gd
const Route := preload("res://world/campaign/route.gd")
const RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
const Grass := preload("res://world/grass/grass_field.gd")
const ZONE := Rect2(-296, -1235, 896, 1275)   # x −296…600, z −1235…40
var world: Node3D
var fails: Array = []


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	world.spawner.set_process(false)
	_vegetation_off_asphalt()
	_no_forest_cactus()
	_grass_to_branch_verge()
	var field: Node = root.get_tree().get_first_node_in_group("grass_field")
	if field.has_method("finish_mask"): field.finish_mask()
	_meadow_along_road(field)
	_car_hole_fades(field)
	_sparse_verge()
	_clean_junctions()
	_no_sand_shoulder(field)
	_accesses(field)
	print("RIEPILOGO zone1_verge: %d errori" % fails.size())
	for f in fails: print("  - ", f)
	quit(0 if fails.is_empty() else 1)


func _on_asphalt(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	return Route.road_distance(p) <= Route.ROAD_HALF or RoadNet.distance(p) <= RoadNet.WIDTH * 0.5


## 1. Ogni pianta già in scena (rifugio, sottobosco, pini) e ogni voce del piano del terreno sta fuori dall'asfalto.
func _vegetation_off_asphalt() -> void:
	var bad: Array = []
	for n in world.find_children("*", "Node3D", true, false):
		var node := n as Node3D
		# Le lastre RockPath sono il selciato voluto davanti alla Rocca, non vegetazione.
		if not node.scene_file_path.begins_with("res://art/nature/") or node.scene_file_path.get_file().begins_with("RockPath"): continue
		var at := node.global_position
		if ZONE.has_point(Vector2(at.x, at.z)) and _on_asphalt(at.x, at.z): bad.append("%s %s" % [node.scene_file_path.get_file(), at])
	for entry in _terrain_plan():
		if entry.has("pick") and _on_asphalt(entry.x, entry.z): bad.append("terreno %s (%.1f, %.1f)" % [world.terrain.source_names[entry.pick], entry.x, entry.z])
	for b in bad.slice(0, 10): print("  sull'asfalto: ", b)
	check(bad.is_empty(), "Niente vegetazione sull'asfalto di statale e rami (%d trovate)" % bad.size())


## 2. I cactus stanno solo nel deserto.
func _no_forest_cactus() -> void:
	var bad := 0
	for entry in _terrain_plan():
		if entry.has("pick") and world.terrain.source_names[entry.pick].begins_with("SM_Cactus") and Route.desert(entry.x, entry.z) <= 0.5: bad += 1
	check(bad == 0, "Niente cactus fuori dal deserto (%d trovati)" % bad)


## 3. A 2,5 m dall'asse di un ramo (0,3 m fuori dall'asfalto) c'è erba, dove a 6 m c'è prato.
func _grass_to_branch_verge() -> void:
	var clumps := FastNoiseLite.new()
	clumps.seed = 4417
	clumps.frequency = 0.045
	var tried := 0
	var green := 0
	for path in RoadNet.paths():
		for i in range(path.size() - 1):
			var a := Vector2(path[i].x, path[i].z)
			var b := Vector2(path[i + 1].x, path[i + 1].z)
			var mid := (a + b) * 0.5
			if RoadNet.junction_distance(mid) < 20.0 or Route.road_distance(mid) < 12.0: continue
			var side := (b - a).normalized().orthogonal()
			for s: float in [-1.0, 1.0]:
				var far := mid + side * s * 6.0
				var near := mid + side * s * 2.5
				if RoadNet.distance(far) < 5.5 or Grass.density_at(far.x, far.y, clumps) < 0.5: continue
				tried += 1
				if Grass.density_at(near.x, near.y, clumps) >= 0.3: green += 1
	print("  ciglio dei rami: %d/%d punti con erba" % [green, tried])
	check(tried >= 50 and green >= tried * 0.9, "Erba fino al ciglio dei rami (%d/%d)" % [green, tried])


var _plan_cache: Array = []
func _terrain_plan() -> Array:
	if _plan_cache.is_empty():
		var t: int = world.terrain.TILE
		for kx in range(floori(ZONE.position.x / t), floori(ZONE.end.x / t) + 1):
			for kz in range(floori(ZONE.position.y / t), floori(ZONE.end.y / t) + 1):
				for entry in world.terrain._plan(Vector2i(kx, kz)):
					if entry.has("x") and ZONE.has_point(Vector2(entry.x, entry.z)): _plan_cache.append(entry)
	return _plan_cache


## Valore della maschera (senza veicoli) nel punto, 0 fuori dai limiti.
func _mask_at(field: Node, image: Image, x: float, z: float) -> float:
	var cell := Vector2i(floori((x - Grass.ORIGIN.x) / Grass.MASK_STEP), floori((z - Grass.ORIGIN.y) / Grass.MASK_STEP))
	if cell.x < 0 or cell.y < 0 or cell.x >= image.get_width() or cell.y >= image.get_height(): return 0.0
	return image.get_pixel(cell.x, cell.y).r


## 4. Lungo la statale della Zona 1, ogni 20 m, a 6 m dall'asse c'è prato (paese, Borgo e arene esclusi a parte).
func _meadow_along_road(field: Node) -> void:
	var road: Array = Route.road_points()
	var walked := 0.0
	var next := 0.0
	var tried := 0
	var green := 0
	for i in range(road.size() - 1):
		var a := Vector2(road[i].x, road[i].z)
		var b := Vector2(road[i + 1].x, road[i + 1].z)
		var step := a.distance_to(b)
		while next <= walked + step:
			var at := a.lerp(b, (next - walked) / maxf(step, 0.001))
			next += 20.0
			if not ZONE.has_point(at): continue
			var side := (b - a).normalized().orthogonal()
			for s: float in [-6.0, 6.0]:
				tried += 1
				if _mask_at(field, field._base, at.x + side.x * s, at.y + side.y * s) > 0.0: green += 1
		walked += step
	print("  prato a 6 m dalla statale: %d/%d (%.0f%%)" % [green, tried, 100.0 * green / maxi(tried, 1)])
	check(tried >= 100 and green >= tried * 0.9, "Prato su tutta la statale della Zona 1 (%d/%d)" % [green, tried])


## 6. Il 4×4 fermo nel prato, poi in marcia: sotto di lui l'erba torna in modo continuo in almeno 1 s, senza salti.
func _car_hole_fades(field: Node) -> void:
	if not "_car_fade" in field:
		check(false, "Buca del 4×4 in dissolvenza (oggi si accende e si spegne a ogni giro da 0,5 s)")
		return
	var car: Node3D = world.expedition.car
	car.set_physics_process(false)
	var spot := Vector3.ZERO
	for x in range(-60, 61, 6):
		for z in range(-160, -60, 6):
			var ok := true
			for o in [Vector2.ZERO, Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
				if _mask_at(field, field._base, x + o.x, z + o.y) < 0.6: ok = false
			if ok and spot == Vector3.ZERO: spot = Vector3(x, world.terrain.height(x, z), z)
	car.global_position = spot
	car.speed = 0.0
	for i in 30: field._update_holes(0.1)
	var full := _mask_at(field, field._static, spot.x, spot.z)
	var values: Array = [_mask_at(field, field._mask, spot.x, spot.z)]
	car.speed = 3.0
	for i in 25:
		field._update_holes(0.1)
		values.append(_mask_at(field, field._mask, spot.x, spot.z))
	var monotone := true
	var jump := 0.0
	var reach := -1
	for i in range(1, values.size()):
		if values[i] < values[i - 1] - 0.005: monotone = false
		jump = maxf(jump, values[i] - values[i - 1])
		if reach < 0 and values[i] >= full * 0.9: reach = i
	car.speed = 0.0
	print("  4×4 in %s: maschera %.2f -> %.2f in %.1f s, salto massimo %.2f per 0,1 s" % [spot.snapped(Vector3.ONE * 0.1), values[0], values[-1], reach * 0.1, jump])
	check(values[0] < 0.05 and monotone and reach >= 10 and jump < full * 0.2, "Buca del 4×4 in dissolvenza (%.1f s, salto massimo %.2f)" % [reach * 0.1, jump])

## 5. Ciglio rado: pali ad almeno 30 m l'uno dall'altro, posto di blocco intero e fuori dall'asfalto,
## e attorno a lui (120 m) al massimo un relitto casuale ogni 100 m di ramo.
func _sparse_verge() -> void:
	var poles: Array = []
	var block: Array = []
	var wrecks: Array = []
	for n in world.terrain.find_children("*", "Node3D", true, false):
		if n.name.contains("PaloSpento"): poles.append(n.global_position)
		elif n.name.contains("PostoDiBlocco"): block.append(n.global_position)
		elif n.name.contains("RelittoCiglio"): wrecks.append(n.global_position)
	var closest := INF
	for i in poles.size():
		for j in range(i + 1, poles.size()): closest = minf(closest, Vector2(poles[i].x, poles[i].z).distance_to(Vector2(poles[j].x, poles[j].z)))
	check(poles.size() >= 10 and closest >= 30.0, "Pali spenti distribuiti: %d, i più vicini a %.0f m" % [poles.size(), closest])
	var on_road := 0
	for at in block:
		if _on_asphalt(at.x, at.z) or Route.road_distance(Vector2(at.x, at.z)) < 5.0: on_road += 1
	check(block.size() >= 6 and on_road == 0, "Posto di blocco all'imbocco della pista: %d pezzi, %d sull'asfalto" % [block.size(), on_road])
	var center := Vector2(6, -108)
	var branch := 0.0
	for path in RoadNet.paths():
		for i in range(path.size() - 1):
			var a := Vector2(path[i].x, path[i].z)
			var b := Vector2(path[i + 1].x, path[i + 1].z)
			var steps := ceili(a.distance_to(b) / 2.0)
			for k in steps:
				if a.lerp(b, (k + 0.5) / steps).distance_to(center) < 120.0: branch += a.distance_to(b) / steps
	var near := 0
	for at in wrecks:
		if Vector2(at.x, at.z).distance_to(center) < 120.0 and RoadNet.distance(Vector2(at.x, at.z)) < 8.0: near += 1
	check(near <= branch / 100.0, "Ciglio quieto attorno al posto di blocco: %d relitti su %.0f m di rami" % [near, branch])


## Imbocchi netti: ogni ramo si stacca con almeno 45° e a 10 m il suo asfalto è già separato da quello da cui parte.
func _clean_junctions() -> void:
	var paths: Array = RoadNet.paths()
	var bad: Array = []
	for index in paths.size():
		for e in [0, 1]:
			var pts: Array = paths[index].duplicate()
			if e == 1: pts.reverse()
			var start := Vector2(pts[0].x, pts[0].z)
			if _other_road(paths, index, start) > 1.0: continue
			var at2 := _along(pts, 2.0)
			var at10 := _along(pts, 10.0)
			var d2 := _other_road(paths, index, at2)
			var d10 := _other_road(paths, index, at10)
			if d2 < 2.0 * sin(deg_to_rad(45.0)) or d10 < 6.2: bad.append("ramo %d da %s: %.1f m a 2 m, %.1f m a 10 m" % [index, start.snapped(Vector2.ONE), d2, d10])
	for b in bad: print("  imbocco: ", b)
	check(bad.is_empty(), "Imbocchi a 45° o più e asfalti separati entro 10 m (%d da rifare)" % bad.size())


func _other_road(paths: Array, index: int, p: Vector2) -> float:
	var best := Route.road_distance(p)
	for o in paths.size():
		if o != index: best = minf(best, RoadNet._path_distance(paths[o], p))
	return best


func _along(pts: Array, want: float) -> Vector2:
	var walked := 0.0
	for i in range(pts.size() - 1):
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var seg := a.distance_to(b)
		if walked + seg >= want: return a.lerp(b, (want - walked) / maxf(seg, 0.001))
		walked += seg
	return Vector2(pts[-1].x, pts[-1].z)


## Maschera letta come la legge lo shader del suolo: lineare, celle da 2 m (canale G = prato dipinto).
func _bilinear(image: Image, x: float, z: float) -> Color:
	var fx: float = (x - Grass.ORIGIN.x) / Grass.MASK_STEP - 0.5
	var fz: float = (z - Grass.ORIGIN.y) / Grass.MASK_STEP - 0.5
	var x0 := floori(fx)
	var z0 := floori(fz)
	var px := func(cx: int, cz: int) -> Color: return image.get_pixel(clampi(cx, 0, image.get_width() - 1), clampi(cz, 0, image.get_height() - 1))
	return px.call(x0, z0).lerp(px.call(x0 + 1, z0), fx - x0).lerp(px.call(x0, z0 + 1).lerp(px.call(x0 + 1, z0 + 1), fx - x0), fz - z0)


## Banchina: a 0,3 m dal bordo dell'asfalto il suolo è già prato (dove a 6 m lo è), lungo statale e rami.
func _no_sand_shoulder(field: Node) -> void:
	var lines: Array = [[Route.road_points(), Route.ROAD_HALF]]
	for path in RoadNet.paths(): lines.append([path, RoadNet.WIDTH * 0.5])
	var tried := 0
	var green := 0
	for line in lines:
		var pts: Array = line[0]
		var half: float = line[1]
		var walked := 0.0
		var next := 10.0
		for i in range(pts.size() - 1):
			var a := Vector2(pts[i].x, pts[i].z)
			var b := Vector2(pts[i + 1].x, pts[i + 1].z)
			var seg := a.distance_to(b)
			walked += seg
			while next <= walked:
				var at := b.lerp(a, (walked - next) / maxf(seg, 0.001))
				next += 20.0
				if not ZONE.has_point(at) or RoadNet.junction_distance(at) < 12.0: continue
				var side := (b - a).normalized().orthogonal()
				for s: float in [-1.0, 1.0]:
					var far := at + side * s * (half + 6.0)
					var near := at + side * s * (half + 0.3)
					if _bilinear(field._base, far.x, far.y).g < 0.5 or Route.road_distance(far) < Route.ROAD_HALF or RoadNet.distance(far) < RoadNet.WIDTH * 0.5: continue
					tried += 1
					if _bilinear(field._base, near.x, near.y).g >= 0.5: green += 1
	print("  prato dipinto a 0,3 m dall'asfalto: %d/%d" % [green, tried])
	check(tried >= 100 and green >= tried * 0.9, "Niente banchina di sabbia lungo le strade (%d/%d)" % [green, tried])


## Accessi: rudere della fattoria, Casa del Vecchio, fattorie isolate e rami ciechi hanno una pista di terra
## battuta (niente erba nel mezzo) che tocca una strada, un portone o una radura.
func _accesses(field: Node) -> void:
	var tracks: Array = Grass._tracks
	var bad: Array = []
	for t in tracks:
		var mid: Vector2 = (t[0] + t[1]) * 0.5
		if _mask_at(field, field._base, mid.x, mid.y) > 0.1: bad.append("pista %s→%s con erba nel mezzo" % [t[0].snapped(Vector2.ONE), t[1].snapped(Vector2.ONE)])
	print("  piste di terra: %d" % tracks.size())
	for b in bad: print("  accesso: ", b)
	check(tracks.size() >= 4 and bad.is_empty(), "Accessi in terra battuta a edifici e radure: %d piste, %d con erba" % [tracks.size(), bad.size()])
