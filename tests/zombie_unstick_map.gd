extends SceneTree
# Sblocco su oggetti veri: zombie sparsi fra case, auto e casse di Borgo Cenere che devono raggiungere il giocatore.
# godot --path . -s res://tests/zombie_unstick_map.gd   (va anche headless)
const L := preload("res://world/villaggio/villaggio_layout.gd")
var world
var p


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	p = world.player
	p.rig.set_physics_process(false)
	world.spawner.set_process(false)
	world.spawner.set_physics_process(false)
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)
	world.terrain.ensure_near([L.CENTER])
	p.reset_at(L.CENTER + Vector3(3.5, 0.5, 3.5))
	for i in 30: await physics_frame
	var goal: Vector3 = p.global_position
	var zs := []
	for i in 10:
		var a := TAU * float(i) / 10.0 + 0.3
		var at := goal + Vector3(cos(a), 0, sin(a)) * (16.0 + float(i % 3) * 5.0)
		var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30, at + Vector3.DOWN * 30, 1))
		if not hit.is_empty(): at = hit.position + Vector3.UP * 0.1
		# Niente tetti né interni chiusi: solo punti all'aperto, a terra.
		var tries := 0
		while (hit.is_empty() or absf(at.y - goal.y) > 1.2) and tries < 12:
			tries += 1
			a += 0.25
			at = goal + Vector3(cos(a), 0, sin(a)) * (16.0 + float(i % 3) * 5.0)
			hit = root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30, at + Vector3.DOWN * 30, 1))
			if not hit.is_empty(): at = hit.position + Vector3.UP * 0.1
		var z = world._spawn_enemy(at)
		z.set_kind(0)
		z.hear(p, 60)
		zs.append([z, at.distance_to(goal)])
	var clock := 0.0
	var arrived := {}
	var moved_back := 0
	while clock < 45.0 and arrived.size() < zs.size():
		await physics_frame
		clock += 1.0 / 60.0
		p.health = 100.0
		p.dead = false
		# Il gioco a volte lo rimanda al punto di partenza (morte/respawn della fase): lo si rimette dove deve essere,
		# altrimenti risultano "fermi a 390 m" zombie che non c'entrano.
		if p.global_position.distance_to(goal) > 6.0:
			p.reset_at(goal)
			moved_back += 1
		for row in zs:
			var z = row[0]
			# il giocatore fa rumore: tutti sanno dov'è (si prova lo sblocco, non la vista)
			if int(clock * 60.0) % 60 == 0: z.hear(p, 80)
			if not arrived.has(z) and z.global_position.distance_to(p.global_position) < 3.0: arrived[z] = clock
	for row in zs:
		var z = row[0]
		print("  zombie da %.0f m: %s sblocchi %s" % [row[1], ("arrivato in %.1f s" % arrived[z]) if arrived.has(z) else ("FERMO a %.1f m (%s)" % [z.global_position.distance_to(p.global_position), str((z.global_position - p.global_position).snappedf(0.1))]), str(z.get("recoveries"))])
		if not arrived.has(z):
			var col: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(z.global_position + Vector3.UP, p.global_position + Vector3.UP, 1))
			print("    stato %d vel %.2f nav_ok %s detour %.0f muro: %s" % [z.state, Vector2(z.velocity.x, z.velocity.z).length(), z.agent.is_target_reachable(), z._detour_side, (str(col.collider.name) + " " + str(col.collider.get_parent().name)) if not col.is_empty() else "-"])
	if moved_back > 0: print("  giocatore riportato al centro %d volte" % moved_back)
	var ok: bool = arrived.size() >= zs.size() - 1
	print(("PASS " if ok else "FAIL ") + "Borgo Cenere: %d zombie su %d arrivano fra case, auto e casse in 45 s" % [arrived.size(), zs.size()])
	quit(0 if ok else 1)
