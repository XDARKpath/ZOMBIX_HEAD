extends SceneTree
# Il Signore delle Teste nella Zona 2 vera: ti raggiunge da 4 lati diversi senza incastrarsi negli oggetti dell'arena.
# godot --path . -s res://tests/boss_unstick_zone2.gd   (va anche headless)
const Route := preload("res://world/campaign/route.gd")
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
	var arena: Vector3 = Route.ARENA_SIGNORE
	world.terrain.ensure_near([arena])
	p.reset_at(arena + Vector3(0, 2, 0))
	for i in 30: await physics_frame
	var boss = world.zone2.spawn_for_test("signore")
	var reached := 0
	for side in 4:
		var dir := Vector3(cos(side * PI * 0.5 + 0.4), 0, sin(side * PI * 0.5 + 0.4))
		var spot: Vector3 = boss.global_position + dir * 18.0
		var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 30, spot + Vector3.DOWN * 40, 1))
		if not hit.is_empty(): spot = hit.position
		p.reset_at(spot + Vector3.UP * 0.5)
		var start: float = boss.global_position.distance_to(p.global_position)
		var clock := 0.0
		var best := start
		while clock < 30.0:
			await physics_frame
			clock += 1.0 / 60.0
			p.health = 100.0
			p.dead = false
			best = minf(best, boss.global_position.distance_to(p.global_position))
			if int(clock * 60.0) % 120 == 0:
				print("    t %.0f dist %.1f mossa %s stun %.1f vel %.1f aperta %s" % [clock, boss.global_position.distance_to(p.global_position), boss.brain.move.get("id", "-"), boss.brain.stun, Vector2(boss.velocity.x, boss.velocity.z).length(), boss._open_way])
			if best < 5.0: break
		print("  lato %d: da %.1f m a %.1f m in %.1f s" % [side, start, best, clock])
		if best < 13.0: reached += 1   # entro il raggio dei suoi colpi (salto, scatto, teste)
	var ok: bool = reached >= 4
	print(("PASS " if ok else "FAIL ") + "Zona 2: il Signore delle Teste ti raggiunge da %d lati su 4" % reached)
	quit(0 if ok else 1)
