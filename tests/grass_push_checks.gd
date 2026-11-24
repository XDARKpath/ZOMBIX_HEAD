extends SceneTree
# godot --path . -s res://tests/grass_push_checks.gd  (esce con 1 se il 4×4 non apre l'erba in marcia)
# Il 4×4 in marcia vicino al giocatore occupa due slot dei pushers con raggio CAR_PUSH; da fermo nessuno.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	for i in 30: await process_frame
	world.spawner.set_process(false)
	var grass = root.find_child("GrassField", true, false)
	var car = world.expedition.car
	world.player.set_physics_process(false)
	world.player.global_position = car.global_position + Vector3(4, 0, 0)
	var count := func() -> int:
		var n := 0
		for v in grass.layers[0].process_material.get_shader_parameter("pushers"):
			if is_equal_approx(v.w, grass.CAR_PUSH): n += 1
		return n
	for i in 5: await process_frame
	var still: int = count.call()
	var where: Vector3 = car.global_position
	var moving := 0
	for i in 20:
		car.speed = 3.0
		car.global_position = where
		await physics_frame
		await process_frame
		moving = count.call()
	print("PUSHER_4x4 fermo=%d in_marcia=%d" % [still, moving])
	quit(0 if still == 0 and moving == 2 else 1)
