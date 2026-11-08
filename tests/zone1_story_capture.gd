extends SceneTree
# Catture della Zona 1 rifatta (recinto, torre della Rocca, radura del boss, villaggio) e controllo dei luoghi.
# Immagini in user://zone1_story/ (godot --path . -s res://tests/zone1_story_capture.gd).
var world: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://zone1_story"))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	for i in 30: await process_frame
	world.spawner.set_process(false)
	for gate in world.fence.gates: print("PORTONE ", gate.at)
	var site: Vector3 = preload("res://world/zona1_rifugio/roadnet.gd").SITES["dungeon"]
	var tower: Node3D = world.rocca.entrance_node
	var front: Vector3 = tower.to_global(Vector3(0, 0, 0))
	print("TORRE ", front, " sito ", site)
	var arena: Vector3 = world.boss_hunt.rows[0][1]
	var square: Vector3 = world.boss_hunt.rows[1][1]
	var shots := [
		["recinto_nord", Vector3(5, 0, -66), Vector3(5, 2, -30), 2.2],
		["recinto_alto", Vector3(-48, 26, -62), Vector3(6, 0, -18), 2.0],
		["recinto_dentro", Vector3(5, 0, -30), Vector3(5, 2, -46), 1.7],
		["torre_pista", tower.to_global(Vector3(2, -1.0, 17)), tower.to_global(Vector3(0, -0.5, 0)), 1.7],
		["torre_scala_fuori", tower.to_global(Vector3(0, -1.0, 11)), tower.to_global(Vector3(0, 0.6, 2)), 1.7],
		["torre_dentro", tower.to_global(Vector3(0, 1.6, 3.4)), tower.to_global(Vector3(0, -2.2, -3.4)), 1.7],
		["torre_alto", tower.to_global(Vector3(24, 18, 24)), tower.to_global(Vector3(0, -1, 3)), 1.0],
		["radura_sentiero", arena + Vector3(13, 0, 9), arena + Vector3(0, 1, 2), 1.7],
		["radura_centro", arena + Vector3(-6, 0, -7), arena + Vector3(4, 1, 6), 1.7],
		["radura_alto", arena + Vector3(-20, 24, 20), arena, 1.0],
		["villaggio", square + Vector3(-14, 0, 14), square + Vector3(0, 2, -6), 1.7],
		["villaggio_alto", square + Vector3(30, 34, 34), square, 1.0],
	]
	for shot in shots:
		world.player.reset_at(Vector3(shot[1].x, world.terrain.height(shot[1].x, shot[1].z) + 0.3, shot[1].z))
		world.player.set_physics_process(false)
		world.terrain.ensure_near([shot[1], shot[2]])
		for i in 20: await process_frame
		var cam := Camera3D.new()
		world.add_child(cam)
		var eye: Vector3 = shot[1]
		var ground: float = world.terrain.height(eye.x, eye.z)
		if eye.y < ground + 1.0 and not String(shot[0]).begins_with("torre"): eye.y = ground + float(shot[3])
		cam.global_position = eye
		cam.look_at(shot[2])
		cam.current = true
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://zone1_story/%s.png" % shot[0])
		print("CATTURA ", shot[0])
		cam.queue_free()
		await process_frame
	quit(0)
