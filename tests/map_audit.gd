extends SceneTree
# Controllo della mappa: cosa si attraversa, cosa galleggia, cosa sta sulla strada. Stampa gruppi con quantità e posizioni.
#   godot --path . --headless -s res://tests/map_audit.gd
var world: Node3D
const CELL := 6.0
const MIN_SOLID := 0.6      # sotto questa misura un oggetto si può attraversare senza che sembri un errore
const FLOAT_GAP := 0.45
var cells := {}


func _init() -> void:
	call_deferred("_run")


func frames(n: int) -> void:
	for i in n: await process_frame


func _run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	root.get_node("Session").launch()
	world.automated = true
	await frames(30)
	world.spawner.set_process(false)
	var points: Array = [Vector3.ZERO]
	var Route: Script = load("res://world/campaign/route.gd")
	var RoadNet: Script = load("res://world/zona1_rifugio/roadnet.gd")
	for p in Route.POINTS: points.append(p)
	for path in RoadNet.paths():
		for k in range(0, path.size(), 3): points.append(path[k])
	var terrain: Node3D = world.terrain
	# Le tessere intorno a ogni punto notevole vengono costruite una alla volta: il controllo le guarda tutte.
	var seen_keys := {}
	var issues := {"passable": {}, "float": {}, "road": {}}
	var total := 0
	for p in points:
		terrain.ensure_near([p])
		for guard in 600:
			if terrain._queue.is_empty() and terrain._jobs.is_empty(): break
			terrain._work(200000)
			await process_frame
		await physics_frame
		await physics_frame
		total += _scan(issues, seen_keys, RoadNet, Route)
	print("OGGETTI CONTROLLATI ", total)
	for what in issues:
		print("=== ", what)
		var rows: Array = issues[what].keys()
		rows.sort_custom(func(a, b): return issues[what][a].size() > issues[what][b].size())
		for name in rows.slice(0, 45):
			var list: Array = issues[what][name]
			print("  ", list.size(), "x ", name, " es. ", list.slice(0, 3))
	print("FINE")
	quit(0)


func _label(mi: MeshInstance3D) -> String:
	# Il nome utile è il primo antenato che non è un nodo generico.
	var n: Node = mi
	var parts := []
	for i in 3:
		if n == null: break
		var s := String(n.name)
		if not s.begins_with("@"): parts.append(s)
		n = n.get_parent()
	var mesh_name: String = mi.mesh.resource_name if mi.mesh else ""
	return mesh_name + " | " + "/".join(parts)


func _scan(issues: Dictionary, seen: Dictionary, RoadNet: Script, Route: Script) -> int:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var meshes: Array = world.find_children("*", "MeshInstance3D", true, false)
	var boxes := {}
	cells.clear()
	var fresh := []
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_inside_tree(): continue
		if _skip(mi): continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		boxes[mi] = box
		var c := Vector3i((box.get_center() / CELL).floor())
		if not cells.has(c): cells[c] = []
		cells[c].append(mi)
		if not seen.has(mi.get_instance_id()):
			seen[mi.get_instance_id()] = true
			fresh.append(mi)
	var shape := BoxShape3D.new()
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = 1
	query.shape = shape
	for m in fresh:
		var mi := m as MeshInstance3D
		var box: AABB = boxes[mi]
		var where: Vector3 = box.get_center().snappedf(1.0)
		var flat: float = world.terrain.height(box.get_center().x, box.get_center().z)
		var label := _label(mi)
		# Galleggia: staccato da terra e da qualunque altra cosa.
		if box.size.length() > 0.3 and box.position.y - flat < 30.0:
			# Si guarda cosa c'è davvero sotto: il terreno disegnato, non quello teorico.
			var ray := PhysicsRayQueryParameters3D.create(box.get_center(), box.get_center() + Vector3.DOWN * (box.size.y * 0.5 + 12.0), 1)
			var under := space.intersect_ray(ray)
			var gap: float = box.position.y - (under.position as Vector3).y if not under.is_empty() else box.position.y - flat
			if gap > FLOAT_GAP and not _touches(mi, box, boxes):
				_add(issues["float"], label, Vector3(where.x, snappedf(gap, 0.1), where.z))
		# Si attraversa: alto da terra almeno al ginocchio, largo almeno MIN_SOLID e nessun collider dentro.
		var ground_part: float = box.end.y - maxf(box.position.y, flat)
		var wide: float = maxf(box.size.x, box.size.z)
		if wide >= MIN_SOLID and ground_part >= 0.5 and box.position.y - flat < 1.5 and box.size.y < 30.0:
			shape.size = Vector3(maxf(box.size.x * 0.6, 0.15), minf(ground_part, 2.0) * 0.6, maxf(box.size.z * 0.6, 0.15))
			query.transform = Transform3D(Basis.IDENTITY, Vector3(box.get_center().x, maxf(box.position.y, flat) + shape.size.y * 0.5 + 0.2, box.get_center().z))
			var solid := false
			for hit in space.intersect_shape(query, 8):
				if not _is_ground(hit.collider):
					solid = true
					break
			if not solid: _add(issues["passable"], label, where)
		# Sulla strada: alberi e vegetazione alta.
		var low: String = label.to_lower()
		if ("pine" in low or "tree" in low or "albero" in low or "bush" in low) and box.size.y > 1.0:
			var at := Vector2(box.get_center().x, box.get_center().z)
			var gap: float = minf(Route.road_distance(at), RoadNet.distance(at))
			if gap < 4.5: _add(issues["road"], label, Vector3(where.x, gap, where.z))
	return fresh.size()


func _skip(mi: MeshInstance3D) -> bool:
	var n: Node = mi
	while n and n != world:
		var s := String(n.name)
		if n is CharacterBody3D or n is Control or n is CanvasLayer: return true
		if s in ["Viewmodel", "Interface", "Atmosphere"] or n is Camera3D: return true
		n = n.get_parent()
	if mi.mesh is PlaneMesh or mi.mesh is QuadMesh: return true
	return false


func _touches(mi: MeshInstance3D, box: AABB, boxes: Dictionary) -> bool:
	var grown := box.grow(0.25)
	var c := Vector3i((box.get_center() / CELL).floor())
	var reach: int = 1 + int(box.size.length() / CELL)
	for x in range(c.x - reach, c.x + reach + 1):
		for y in range(c.y - reach, c.y + reach + 1):
			for z in range(c.z - reach, c.z + reach + 1):
				for other in cells.get(Vector3i(x, y, z), []):
					if other != mi and grown.intersects(boxes[other]): return true
	return false


func _is_ground(collider: Object) -> bool:
	var n: Node = collider as Node
	if n == null: return false
	# Il terreno ha una sola forma a griglia di altezze o una mesh larga quanto una tessera.
	for child in n.get_children():
		if child is CollisionShape3D and ((child as CollisionShape3D).shape is HeightMapShape3D or (child as CollisionShape3D).shape is ConcavePolygonShape3D and String(n.name).to_lower().contains("ground")): return true
	return n.get_parent() == world.terrain or String(n.name).to_lower().contains("terrain")


func _add(group: Dictionary, label: String, where: Vector3) -> void:
	if not group.has(label): group[label] = []
	group[label].append(where)
