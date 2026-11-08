extends SceneTree
# Reazioni direzionali degli zombie (Z_React_*): res://../screenshots/zreact-<reazione>-<tempo>.png
func _initialize(): call_deferred("run")
func shot(id: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/zreact-" + id + ".png"))
func run():
	var world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.5).timeout
	world.get_node("Interface").visible = false
	var p = world.player
	p.set_physics_process(false)
	p.position = Vector3(6, 0.1, -60)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	cam.fov = 50
	for kind in ["hit_left", "hit_right", "knockdown", "pushed", "blocked"]:
		var z: Node3D = world._spawn_enemy(Vector3(6, 0, -64))
		z.rotation.y = 0.0
		await create_timer(0.3).timeout
		var start: Vector3 = z.global_position
		cam.global_position = start + Vector3(3.2, 1.6, 2.4)
		cam.look_at(start + Vector3(0, 0.8, 0))
		z.pending_reaction = kind
		z.reaction_dir = Vector3(-1, 0, 0) if kind == "hit_left" else (Vector3(1, 0, 0) if kind == "hit_right" else Vector3(0, 0, -1))
		z.receive_hit("torso", 5.0, Vector3.ZERO, "axe", kind == "knockdown")
		var total: float = z.REACTIONS[kind][1]
		for k in 4:
			var at: float = total * (0.12 + 0.26 * k)
			while z.reaction_time < at and z.reaction != "":
				await process_frame
			await shot("%s-%d" % [kind, k])
		while z.reaction != "": await process_frame
		print(kind, " spostamento ", snappedf(z.global_position.distance_to(start), 0.01), " m, durata ", snappedf(total, 0.01), " s")
		z.queue_free()
	quit()
