extends SceneTree
# Ciglio della Zona 1: niente piante sull'asfalto, niente cactus nel bosco, erba fino al bordo dei rami.
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
	print("RIEPILOGO zone1_verge: %d errori" % fails.size())
	for f in fails: print("  - ", f)
	quit(0 if fails.is_empty() else 1)


func _on_asphalt(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	return Route.road_distance(p) <= 3.45 or RoadNet.distance(p) <= RoadNet.WIDTH * 0.5


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
