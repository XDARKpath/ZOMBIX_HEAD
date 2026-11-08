extends RefCounted
# Tutto quello che sembra solido deve esserlo: alberi con il tronco, massi con la loro forma, mobili e pezzi di recinto
# con una scatola. Erba, felci e fiori restano attraversabili. Un albero nato in mezzo alla strada non resta lì.

const RoadNet = preload("res://world/zona1_rifugio/roadnet.gd")
const Route = preload("res://world/campaign/route.gd")
const TREES := ["Pine", "DeadTree", "CommonTree", "TwistedTree"]
const ROCKS := ["Rock_"]
const SOFT := ["Grass", "Fern", "Plant", "Clover", "Flower", "Mushroom", "Pebble", "Bush", "Petal", "Leaf", "Curtain", "Rug", "Banner", "Rope", "Cable", "Wire", "Decal", "Stain", "Blood", "Desert_Rib"]
## Quello che si apre, si raccoglie o si muove ha già le sue regole.
const LIVE := ["Portone", "Scala", "Stair", "Step", "Gradin", "Ponte", "Bridge_Plank", "Rocca", "Dungeon", "Cripta", "Door", "Porta", "Cancello", "Gate", "Item", "Pickup", "Loot", "Crate_Destructible", "Chest", "Baule", "Hatch", "Botola", "Lever", "Leva", "Trap", "Trappola", "Lamp", "Light", "Fire", "Flame", "Smoke", "Water", "Lake", "Sky", "Roof", "Tetto", "Ceiling"]
const ROAD_CLEAR := 5.5
## Sotto queste misure un oggetto è un sasso/ciotolo/arnese basso: si scavalca e non blocca.
const MIN_WIDE := 0.95
const MIN_TALL := 0.6
const ROCK_MIN_WIDE := 1.35
const ROCK_MIN_TALL := 0.72
static var _convex := {}


static func is_tree(name: String) -> bool:
	for t in TREES:
		if name.begins_with(t): return true
	return false


static func is_rock(name: String) -> bool:
	for t in ROCKS:
		if name.begins_with(t): return true
	return false


static func _has(name: String, words: Array) -> bool:
	var low := name.to_lower()
	for w in words:
		if (w as String).to_lower() in low: return true
	return false


## Tronco: un cilindro sottile, largo come il tronco vero, fermo sul terreno.
static func add_trunk(tree: Node3D, parent: Node3D) -> void:
	var size: float = tree.scale.x
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.38 * size
	cylinder.height = 5.0
	shape.shape = cylinder
	shape.position.y = 2.5
	body.add_child(shape)
	parent.add_child(body)
	body.position = tree.position
	if parent != tree.get_parent(): body.global_position = tree.global_position


## Ingombro reale del masso (unione delle sue mesh): serve a distinguere un sassolino da un macigno.
static func _mesh_box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for found in node.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh == null: continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var own: MeshInstance3D = node as MeshInstance3D
		var b: AABB = own.global_transform * own.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Masso: la sua forma convessa, condivisa fra tutti i massi uguali. I sassi piccoli
## restano attraversabili: si saltano, non devono fermare il giocatore.
static func add_rock(rock: Node3D) -> void:
	var box := _mesh_box(rock)
	if box.size != Vector3.ZERO and (maxf(box.size.x, box.size.z) < ROCK_MIN_WIDE or box.size.y < ROCK_MIN_TALL):
		return
	for found in rock.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh == null: continue
		if not _convex.has(mi.mesh): _convex[mi.mesh] = mi.mesh.create_convex_shape(true, true)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = _convex[mi.mesh]
		body.add_child(shape)
		mi.add_child(body)
	if rock is MeshInstance3D:
		var own := rock as MeshInstance3D
		if own.mesh and own.find_children("*", "StaticBody3D", true, false).is_empty():
			if not _convex.has(own.mesh): _convex[own.mesh] = own.mesh.create_convex_shape(true, true)
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = _convex[own.mesh]
			body.add_child(shape)
			own.add_child(body)


static func _touching_collider(space: PhysicsDirectSpaceState3D, box: AABB, floor_y: float) -> bool:
	var probe := BoxShape3D.new()
	var tall: float = minf(box.end.y - floor_y, 2.0)
	probe.size = Vector3(maxf(box.size.x * 0.7, 0.2), maxf(tall * 0.6, 0.2), maxf(box.size.z * 0.7, 0.2))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY, Vector3(box.get_center().x, floor_y + 0.2 + probe.size.y * 0.5, box.get_center().z))
	for hit in space.intersect_shape(query, 8):
		var body: Node = hit.collider as Node
		if body == null: continue
		# La tessera del terreno non conta: quello che cerchiamo è l'oggetto.
		if body.get_parent() and body.get_parent() is MeshInstance3D and String(body.get_parent().get_parent().name).begins_with("Sector_"): continue
		return true
	return false


## Passata su un intero pezzo di mondo, dopo che è stato costruito.
static func apply(root: Node3D, world: Node3D) -> Dictionary:
	var done := {"alberi": 0, "tolti_strada": 0, "massi": 0, "scatole": 0}
	var terrain: Node3D = world.terrain
	var trees := []
	var rocks := []
	_collect(root, terrain, trees, rocks)
	for t in trees:
		var tree := t as Node3D
		var at := Vector2(tree.global_position.x, tree.global_position.z)
		if minf(Route.road_distance(at), RoadNet.distance(at)) < ROAD_CLEAR:
			tree.queue_free()
			done.tolti_strada += 1
		elif tree.find_children("*", "StaticBody3D", true, false).is_empty():
			add_trunk(tree, tree)
			var body: Node3D = tree.get_child(tree.get_child_count() - 1)
			body.top_level = true
			body.global_position = tree.global_position
			body.global_rotation = Vector3.ZERO
			done.alberi += 1
	for r in rocks:
		if (r as Node3D).find_children("*", "StaticBody3D", true, false).is_empty():
			add_rock(r)
			done.massi += 1
	return done


static func _collect(node: Node, terrain: Node3D, trees: Array, rocks: Array) -> void:
	if node == terrain: return
	if node is CharacterBody3D or node is Control or node is CanvasLayer: return
	if node is Node3D:
		var name := String(node.name)
		if is_tree(name):
			trees.append(node)
			return
		if is_rock(name):
			rocks.append(node)
			return
	for child in node.get_children(): _collect(child, terrain, trees, rocks)


## Massi e alberi posati a mano che restano sospesi (la riva del lago scende sotto di loro): giù fino a terra.
static func settle(root: Node3D, world: Node3D) -> int:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var trees := []
	var rocks := []
	_collect(root, world.terrain, trees, rocks)
	var moved := 0
	for n in trees + rocks:
		var node := n as Node3D
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		var box: AABB = AABB()
		var first := true
		for found in node.find_children("*", "MeshInstance3D", true, false):
			var mi := found as MeshInstance3D
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if first: continue
		var ray := PhysicsRayQueryParameters3D.create(box.get_center(), box.get_center() + Vector3.DOWN * (box.size.y * 0.5 + 15.0), 1)
		var mine := []
		for body in node.find_children("*", "StaticBody3D", true, false): mine.append((body as StaticBody3D).get_rid())
		ray.exclude = mine
		var under := space.intersect_ray(ray)
		if under.is_empty(): continue
		var gap: float = box.position.y - (under.position as Vector3).y
		if gap > 0.15:
			node.global_position.y -= gap + 0.05
			moved += 1
	return moved


## Mobili e pezzi fissi senza collisione: una scatola sulla loro misura. Va chiamata con la fisica già attiva.
static func box_loose_props(root: Node3D, world: Node3D) -> int:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var count := 0
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh == null or mi.mesh is PlaneMesh or mi.mesh is QuadMesh: continue
		if _is_skipped(mi, world): continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		var floor_y: float = world.terrain.height(box.get_center().x, box.get_center().z)
		if box.position.y - floor_y > 1.4: continue
		if maxf(box.size.x, box.size.z) < MIN_WIDE or box.end.y - maxf(box.position.y, floor_y) < MIN_TALL: continue
		if box.size.y > 30.0 or box.size.x > 40.0 or box.size.z > 40.0: continue
		if _touching_collider(space, box, maxf(box.position.y, floor_y)): continue
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = mi.get_aabb().size
		shape.shape = cube
		shape.position = mi.get_aabb().get_center()
		body.add_child(shape)
		mi.add_child(body)
		count += 1
	return count


static func _is_skipped(mi: MeshInstance3D, world: Node3D) -> bool:
	var mesh_name: String = mi.mesh.resource_name
	if _has(mesh_name, SOFT) or _has(mesh_name, LIVE) or _has(mesh_name, TREES) or _has(mesh_name, ROCKS): return true
	var n: Node = mi
	var depth := 0
	while n and n != world:
		var s := String(n.name)
		if n is CharacterBody3D or n is RigidBody3D or n is Area3D or n is Control or n is CanvasLayer: return true
		if depth < 5 and (_has(s, SOFT) or _has(s, LIVE)): return true
		# "Building": i gusci di sceriffo e armeria hanno i loro muri (refuge_set._shell_collision); le loro mesh
		# raccolgono un materiale per tutto l'edificio, e la scatola di "luce" chiudeva l'ingresso del negozio.
		if s in ["Viewmodel", "Interface", "Rocca", "Dungeon", "TavoloArmi", "Building"] or n is Camera3D: return true
		n = n.get_parent()
		depth += 1
	return false
