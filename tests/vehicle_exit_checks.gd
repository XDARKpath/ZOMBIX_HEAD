extends SceneTree
# Discesa dal 4×4 vicino a palizzata ed edifici, rinascita accanto al 4×4 e salvataggio da seduti.
# godot --path . -s res://tests/vehicle_exit_checks.gd
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
var world: Node3D
var p: CharacterBody3D
var fails: Array = []


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


func wait(frames: int) -> void:
	for i in frames: await physics_frame


func ground(x: float, z: float, up := 0.2) -> Vector3:
	return Vector3(x, world.terrain.height(x, z) + up, z)


## Libero per una persona in piedi e dentro il recinto del paese.
func free_inside(at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = p.standing_shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.9)
	query.collision_mask = 1 | 8
	query.exclude = [p.get_rid()]
	var free: bool = root.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	return free and at.x > Layout.FENCE_MIN.x and at.x < Layout.FENCE_MAX.x and at.z > Layout.FENCE_MIN.y


func _run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	p = world.player
	world.spawner.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.set_physics_process(false)
	world.terrain.ensure_near([Vector3(0, 0, -10)])
	await wait(30)
	var car: CharacterBody3D = world.expedition.car
	var peer: int = root.multiplayer.get_unique_id()
	car.repaired = true
	for t in [[ground(Layout.FENCE_MIN.x + 1.3, -20.0), 0.0, "contro la palizzata ovest"],
			[ground(Layout.FENCE_MAX.x - 1.3, -20.0), PI, "contro la palizzata est"],
			[ground(Layout.SHERIFF.x - 7.0, Layout.SHERIFF.z), 0.0, "contro l'ufficio dello sceriffo"],
			[ground(10, -10), 0.0, "in mezzo al paese"]]:
		car.position = t[0]; car.rotation.y = t[1]; car.velocity = Vector3.ZERO; car.speed = 0
		await wait(30)
		p.reset_at(car.to_global(Vector3(0, 0.2, 2.6)))
		await wait(5)
		var got_in: bool = car.interact(peer)
		await wait(10)
		var got_out: bool = car.interact(peer)
		await wait(30)
		check(got_in and got_out and not p.seated, "4×4 %s: si sale e si scende" % t[2])
		check(free_inside(p.global_position) and p.is_on_floor(), "4×4 %s: a terra libero e dentro il recinto (%s)" % [t[2], p.global_position.snapped(Vector3.ONE * 0.01)])
		if p.seated: car.seats = [0, 0, 0, 0]; car._release(peer)
	# rinascita accanto al 4×4 riparato, parcheggiato contro la palizzata ovest
	car.position = ground(Layout.FENCE_MIN.x + 1.3, -20.0); car.rotation.y = 0.0
	await wait(30)
	var spawn: Vector3 = world.respawn_point()
	check(free_inside(spawn) and spawn.distance_to(car.position) < 4.5, "Rinascita accanto al 4×4: libera e dentro il recinto (%s)" % spawn.snapped(Vector3.ONE * 0.01))
	# salvataggio da seduti: il punto salvato è fuori dalla collisione dell'auto
	car.position = ground(10, -10); car.rotation.y = 0.7
	await wait(30)
	p.reset_at(car.to_global(Vector3(0, 0.2, 2.6)))
	await wait(5)
	car.interact(peer)
	await wait(10)
	var saved: Vector3 = root.get_node("SaveManager")._standing_point(world, world.expedition)
	car.seats = [0, 0, 0, 0]; car._release(peer)
	p.reset_at(saved)
	await wait(60)
	check(free_inside(p.global_position) and p.is_on_floor(), "Ripresa da un salvataggio fatto alla guida: in piedi accanto al 4×4 (%s)" % p.global_position.snapped(Vector3.ONE * 0.01))
	print("ESITO ", "OK" if fails.is_empty() else "FALLITI %d" % fails.size())
	quit(0 if fails.is_empty() else 1)
