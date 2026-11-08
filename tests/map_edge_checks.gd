extends SceneTree
# La mappa allargata nel gioco vero: limiti, montagne senza varchi, nessun buco, ±3 tessere in auto, luoghi, GPS.
# godot --path . -s res://tests/map_edge_checks.gd -- --out=<cartella per le foto>
const Route := preload("res://world/campaign/route.gd")
const TILE := 128
var Terrain: GDScript   # si carica a mondo avviato: dipende dagli autoload
const RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
const VL := preload("res://world/villaggio/villaggio_layout.gd")
var world: Node3D
var p: CharacterBody3D
var fails: Array = []
var out := ""
var cam: Camera3D


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


func wait(frames: int) -> void:
	for i in frames: await physics_frame


func _run() -> void:
	Terrain = load("res://world/campaign/terrain.gd")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
	if out != "": DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	# I controlli leggono i testi italiani: la lingua si cambia solo in memoria, senza salvare la scelta del giocatore.
	root.get_node("Localization").current = "it"
	TranslationServer.set_locale("it")
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	p = world.player
	world.spawner.set_process(false)
	world.village.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.set_physics_process(false)
	check(Route.MIN_X < -1100.0 and Route.MAX_X > 4500.0 and Route.MIN_Z < -5400.0 and Route.MAX_Z > 400.0, "Limiti più larghi di prima (%d/%d/%d/%d)" % [Route.MIN_X, Route.MAX_X, Route.MIN_Z, Route.MAX_Z])
	check(Route.inside(Vector3(Route.MAX_X - 1, 0, Route.MIN_Z + 1)) and not Route.inside(Vector3(Route.MAX_X + 1, 0, 0)), "Il blocco del 4×4 usa i nuovi limiti")
	for at in Route.road_corners():
		if Route.edge_distance(at.x, at.z) < 700.0: fails.append("tappa troppo vicina al bordo %s" % at)
	_no_pass()
	_hold_terrain(true)
	await _no_holes()
	_hold_terrain(false)
	await _tile_radius()
	await _walk_to_edges()
	await _drive_to_edges()
	_hold_terrain(true)
	await _places_and_lane()
	_gps()
	if out != "": await _photos()
	print("MAPPA: %d errori %s" % [fails.size(), fails])
	quit(0 if fails.is_empty() else 1)


## Riempimento sulla griglia del terreno: da dentro la mappa, passando solo su pendenze camminabili (45°), si arriva al limite?
func _no_pass() -> void:
	var t0 := Time.get_ticks_msec()
	const S := 8
	var seen := {}
	var stack: Array[Vector2i] = []
	var band := 720.0
	for x in range(int(Route.MIN_X + band), int(Route.MAX_X - band), S * 8):
		for z in [Route.MIN_Z + band, Route.MAX_Z - band]:
			stack.append(Vector2i(x / S, int(z) / S))
	for z in range(int(Route.MIN_Z + band), int(Route.MAX_Z - band), S * 8):
		for x in [Route.MIN_X + band, Route.MAX_X - band]:
			stack.append(Vector2i(int(x) / S, z / S))
	var closest := INF
	var cells := 0
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if seen.has(c): continue
		var x := float(c.x * S)
		var z := float(c.y * S)
		var d := Route.edge_distance(x, z)
		if d > band or d < 0.0: continue
		seen[c] = true
		cells += 1
		closest = minf(closest, d)
		var h: float = Terrain.ground_height(x, z)
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + step
			if seen.has(n): continue
			if absf(Terrain.ground_height(n.x * S, n.y * S) - h) <= float(S): stack.append(n)
	print("  riempimento: %d celle in %d ms, punto più vicino al limite %.0f m" % [cells, Time.get_ticks_msec() - t0, closest])
	check(closest > 40.0, "A 45° non esiste nessun passaggio fino al limite (si arriva a %.0f m)" % closest)


## Lungo tutto il perimetro e la strada il terreno c'è e ha collisione, anche oltre i limiti che si vedono dal bordo.
func _no_holes() -> void:
	var spots: Array = []
	var inset := 150.0
	for x in range(int(Route.MIN_X), int(Route.MAX_X) + 1, 700):
		spots.append(Vector3(x, 0, Route.MIN_Z + inset))
		spots.append(Vector3(x, 0, Route.MAX_Z - inset))
	for z in range(int(Route.MIN_Z), int(Route.MAX_Z) + 1, 700):
		spots.append(Vector3(Route.MIN_X + inset, 0, z))
		spots.append(Vector3(Route.MAX_X - inset, 0, z))
	for at in Route.road_corners(): spots.append(at)
	var misses := 0
	var rays := 0
	var missing_mesh := 0
	var space := root.get_world_3d().direct_space_state
	for spot in spots:
		world.terrain.ensure_near([], [spot])
		await wait(2)
		for key in world.terrain.tiles:
			var ground: MeshInstance3D = world.terrain.tiles[key].get_child(0)
			if ground.mesh == null or ground.mesh.get_surface_count() == 0: missing_mesh += 1
			for offset in [Vector2(16, 16), Vector2(64, 40), Vector2(104, 104)]:
				var x: float = key.x * TILE + offset.x
				var z: float = key.y * TILE + offset.y
				if RoadNet.in_terrain_hole(x, z): continue
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, 600, z), Vector3(x, -30, z), 1)
				rays += 1
				var hit: Dictionary = space.intersect_ray(q)
				# Buco = niente sotto, o si arriva sotto il terreno. Un masso sopra il terreno non e' un buco.
				if hit.is_empty() or hit.position.y < Terrain.ground_height(x, z) - 3.0:
					misses += 1
					print("  buco o ostacolo a (%.0f, %.0f): terreno %.1f, colpito %s %s" % [x, z, Terrain.ground_height(x, z), hit.get("position", "niente"), hit.get("collider", null)])
	print("  buchi: %d tessere controllate da %d punti, %d raggi" % [rays / 3, spots.size(), rays])
	check(misses == 0 and missing_mesh == 0, "Nessun buco nel terreno ai bordi e lungo la strada (mancati %d, senza mesh %d)" % [misses, missing_mesh])


## ±2 a piedi, ±3 in auto (via _process, come nel gioco), e due giocatori lontani hanno tutti e due il loro terreno.
func _tile_radius() -> void:
	var car: CharacterBody3D = world.expedition.car
	var far := Vector3(600, 0, -1700)
	p.set_physics_process(true)
	p.health = 100000.0
	p.reset_at(Vector3(far.x, Terrain.ground_height(far.x, far.z) + 0.5, far.z))
	world.terrain.timer = 0.0
	await _settle()
	var foot_center := Vector2i(floori(far.x / TILE), floori(far.z / TILE))
	check(_has_ring(foot_center, 2) and not _has_ring(foot_center, 3), "A piedi ±2 tessere (%d in tutto, col 4×4 parcheggiato)" % world.terrain.tiles.size())
	car.repaired = true
	car.reset()
	car.repaired = true
	p.set_physics_process(true)
	p.reset_at(car.position + Vector3(0, 0.3, 2.6))
	await wait(4)
	check(car.interact(1), "Si sale sul 4×4")
	car.position = far + Vector3.UP * 0.3
	car.set_physics_process(false)
	car._place_occupants()
	world.terrain.timer = 0.0
	await _settle()
	check(_has_ring(foot_center, 3) and world.terrain.tiles.size() <= 50, "In auto ±3 tessere (%d)" % world.terrain.tiles.size())
	car.set_physics_process(true)
	car.seats[0] = 0
	car.position = Vector3(19.5, 0.2, 3.6)
	car._release(1)
	var a := Vector3(4000, 0, -3000)
	var b := Vector3(-1500, 0, 800)
	world.terrain.timer = 1000000.0
	world.terrain.ensure_near([a, b])
	await wait(3)
	check(_has_ring(Vector2i(floori(a.x / TILE), floori(a.z / TILE)), 2) and _has_ring(Vector2i(floori(b.x / TILE), floori(b.z / TILE)), 2), "Due giocatori lontani: terreno attorno a tutti e due")
	p.set_physics_process(true)


## Il test comanda le tessere: il giocatore resta fermo e il giro normale del terreno non le scarica.
func _hold_terrain(hold: bool) -> void:
	p.set_physics_process(not hold)
	world.terrain.timer = 1000000.0 if hold else 0.0


func _settle() -> void:
	for i in 200:
		await process_frame
		if i > 40 and world.terrain._queue.is_empty() and world.terrain._jobs.is_empty(): return


func _has_ring(center: Vector2i, radius: int) -> bool:
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			if not world.terrain.tiles.has(center + Vector2i(x, z)): return false
	return true


func _side_points() -> Array:
	# Da una zona di colline verso il limite, su tutti e quattro i lati.
	return [
		{"name": "ovest", "at": Vector3(Route.MIN_X + 330, 0, -3000), "dir": Vector3(-1, 0, 0)},
		{"name": "est", "at": Vector3(Route.MAX_X - 330, 0, -2000), "dir": Vector3(1, 0, 0)},
		{"name": "nord", "at": Vector3(1500, 0, Route.MIN_Z + 330), "dir": Vector3(0, 0, -1)},
		{"name": "sud", "at": Vector3(1500, 0, Route.MAX_Z - 330), "dir": Vector3(0, 0, 1)},
	]


func _walk_to_edges() -> void:
	p.controls_enabled = true
	p.health = 100000.0
	for side in _side_points():
		var at: Vector3 = side.at
		world.terrain.ensure_near([at])
		p.reset_at(Vector3(at.x, Terrain.ground_height(at.x, at.z) + 0.5, at.z))
		var yaw := atan2(-side.dir.x, -side.dir.z)
		await wait(4)
		Input.action_press("move_forward")
		Input.action_press("sprint")
		var closest := INF
		var ticks := 0
		var stuck := 0
		var last: Vector3 = p.global_position
		for i in 3600:
			await physics_frame
			p.rig.yaw = yaw
			ticks += 1
			closest = minf(closest, Route.edge_distance(p.global_position.x, p.global_position.z))
			if i % 60 == 59:
				stuck = stuck + 1 if p.global_position.distance_to(Vector3(last.x, p.global_position.y, last.z)) < 2.0 else 0
				last = p.global_position
				if stuck >= 4: break
		Input.action_release("move_forward")
		Input.action_release("sprint")
		print("  a piedi %s: fermo a %.0f m dal limite, quota %.0f m, dopo %.0f s" % [side.name, closest, p.global_position.y, ticks / 60.0])
		check(closest > 20.0 and stuck >= 4, "A piedi verso %s la montagna ti ferma prima del limite" % side.name)
		if side.name == "ovest" and out != "":
			await _snap("montagne_a_piedi_ai_piedi_della_parete")


func _drive_to_edges() -> void:
	var car: CharacterBody3D = world.expedition.car
	for side in _side_points():
		var at: Vector3 = side.at
		world.terrain.ensure_near([at], [at])
		car.position = Vector3(at.x, Terrain.ground_height(at.x, at.z) + 0.6, at.z)
		car.server_position = car.position
		car.rotation.y = atan2(-side.dir.x, -side.dir.z)
		car.speed = 0.0
		car.seats = [1, 0, 0, 0]
		car.repaired = true
		await wait(4)
		Input.action_press("move_forward")
		var closest := INF
		var stuck := 0
		var ticks := 0
		var last: Vector3 = car.global_position
		for i in 2400:
			await physics_frame
			ticks += 1
			closest = minf(closest, Route.edge_distance(car.global_position.x, car.global_position.z))
			if i % 60 == 59:
				stuck = stuck + 1 if car.global_position.distance_to(Vector3(last.x, car.global_position.y, last.z)) < 3.0 else 0
				last = car.global_position
				if stuck >= 3: break
		Input.action_release("move_forward")
		print("  in auto %s: fermo a %.0f m dal limite, quota %.0f m, dopo %.0f s" % [side.name, closest, car.global_position.y, ticks / 60.0])
		check(closest > 20.0 and stuck >= 3, "In auto verso %s la montagna ti ferma prima del blocco" % side.name)
	car.seats = [0, 0, 0, 0]
	car.speed = 0.0
	car._release(1)
	car.position = Vector3(19.5, 0.2, 3.6)
	car.server_position = car.position


func _places_and_lane() -> void:
	var space := root.get_world_3d().direct_space_state
	var car_box := BoxShape3D.new()
	car_box.size = Vector3(2.4, 1.2, 2.4)
	var build_ms := 0
	for i in Route.places().size():
		var place: Dictionary = Route.places()[i]
		var t0 := Time.get_ticks_usec()
		world.terrain.ensure_near([place.at])
		build_ms = maxi(build_ms, (Time.get_ticks_usec() - t0) / 1000)
		await wait(3)
		var node: Node = _find_place(i)
		check(node != null and node.get_child_count() > 2, "Luogo %d %s costruito" % [i, place.kind])
		var road_at: Vector3 = Route.nearest_road(place.at)
		var gap: float = road_at.distance_to(Vector3(place.at.x, 0, place.at.z))
		if place.kind in Route.ON_ROAD:
			check(gap < 12.0, "%d %s sta sulla strada (%.1f m)" % [i, place.kind, gap])
		else:
			check(gap > 24.0 and gap < 60.0, "%d %s sta a lato della strada (%.1f m)" % [i, place.kind, gap])
		# Il 4×4 passa lungo la statale davanti a ogni luogo.
		var dir: Vector3 = Route.road_direction(place.at)
		var from: Vector3 = road_at - dir * 45.0
		from.y = Terrain.ground_height(from.x, from.z) + 1.6
		var to: Vector3 = road_at + dir * 45.0
		to.y = Terrain.ground_height(to.x, to.z) + 1.6
		var blocked := ""
		for k in 18:
			var a: Vector3 = from.lerp(to, k / 18.0)
			var b: Vector3 = from.lerp(to, (k + 1) / 18.0)
			a.y = Terrain.ground_height(a.x, a.z) + 1.6
			b.y = Terrain.ground_height(b.x, b.z) + 1.6
			var cast := PhysicsShapeQueryParameters3D.new()
			cast.shape = car_box
			cast.transform = Transform3D(Basis.looking_at(dir), a)
			cast.motion = b - a
			cast.collision_mask = 1
			var free_part: PackedFloat32Array = space.cast_motion(cast)
			if free_part[0] < 0.999:
				cast.transform = Transform3D(Basis.looking_at(dir), a + cast.motion * free_part[1])
				var hit: Dictionary = space.get_rest_info(cast)
				blocked = str(instance_from_id(hit.collider_id).get_path()) if not hit.is_empty() else "?"
				break
		check(blocked == "", "%d %s: la corsia resta libera per il 4×4 %s" % [i, place.kind, blocked])
	print("  tessera con luogo, caricata tutta insieme: al massimo %d ms" % build_ms)
	check(not Route.road_signs().is_empty(), "Ci sono %d cartelli con le distanze" % Route.road_signs().size())
	for road_sign in Route.road_signs():
		check(road_sign.lines[0].contains(" km"), "Cartello: %s" % " / ".join(road_sign.lines))


func _find_place(index: int) -> Node:
	for key in world.terrain.tiles:
		for child in world.terrain.tiles[key].get_children():
			if String(child.name).begins_with("Luogo_%d_" % index): return child
	return null


func _gps() -> void:
	p.position = VL.CENTER + Vector3(180, 0, 0)
	var near: Dictionary = Route.nearby_place(p.position)
	check(near.get("title", "") == "BORGO CENERE", "Il GPS segna Borgo Cenere quando ci passi vicino")
	check(world.get_node("Interface").find_children("*", "Control", true, false).size() > 0, "Interfaccia presente")
	var gps: Control = null
	for node in world.find_children("*", "Control", true, false):
		if node.has_method("screen_text"):
			gps = node
			break
	if gps != null:
		check(gps.screen_text().contains("BORGO CENERE"), "La schermata GPS scrive il borgo")
	check(Route.nearby_place(Vector3(600, 0, -400)).is_empty(), "Lontano da tutto il GPS non segna luoghi")


func _photos() -> void:
	cam = Camera3D.new()
	cam.far = 1500.0
	world.add_child(cam)
	cam.current = true
	world.get_node("Interface").visible = false
	p.visible = false
	var shots := [
		["fattoria", 2, Vector3(0, 7, 34)], ["distributore", 3, Vector3(-14, 4, 30)], ["campeggio", 5, Vector3(10, 5, 34)],
		["posto_di_blocco_militare", 8, Vector3(9, 5, 34)], ["ponte", 6, Vector3(26, 6, 22)], ["incidente", 4, Vector3(8, 4, 26)],
		["cascina_bruciata", 7, Vector3(4, 6, 30)],
	]
	for shot in shots:
		var place: Dictionary = Route.places()[shot[1]]
		var node: Node3D = null
		world.terrain.ensure_near([place.at])
		await wait(3)
		node = _find_place(shot[1])
		var eye: Vector3 = node.to_global(shot[2])
		await _shoot(shot[0], eye, node.global_position + Vector3.UP * 1.5)
	var road_sign: Dictionary = Route.road_signs()[0]
	await _shoot("cartello_distanze", road_sign.at + Vector3.UP * 1.8 - Vector3(sin(road_sign.yaw + PI), 0, cos(road_sign.yaw + PI)) * 7.0, road_sign.at + Vector3.UP * 2.0)
	# I quattro bordi, dalla strada/collina verso il limite, e dall'alto.
	for side in _side_points():
		var at: Vector3 = side.at + side.dir * -80.0
		await _shoot("bordo_" + side.name, at + Vector3.UP * (Terrain.ground_height(at.x, at.z) + 2.0), at + side.dir * 300.0 + Vector3.UP * (Terrain.ground_height(at.x, at.z) + 60.0))
	var at: Vector3 = _side_points()[0].at
	await _shoot("bordo_dalla_collina", _eye(at + Vector3(120, 0, 60), 14.0), at + Vector3(-300, 110, 0))


func _eye(at: Vector3, above: float) -> Vector3:
	return Vector3(at.x, Terrain.ground_height(at.x, at.z) + above, at.z)


func _shoot(title: String, eye: Vector3, look: Vector3) -> void:
	world.terrain.ensure_near([eye, look])
	await wait(4)
	cam.global_position = eye
	cam.look_at(look)
	cam.current = true
	await wait(4)
	await _snap(title)


func _snap(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(title + ".png"))
	print("FOTO ", title)
