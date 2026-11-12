extends SceneTree
# Foto del prato (da vicino, ad altezza d'occhi, dall'alto) e FPS medi sul prato.
#   godot --path . -s res://tests/grass_capture.gd -- nome     -> res://../screenshots/prato_nome_*.png
const SPOTS := [Vector3(6, 0, -66)]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var tag: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "ora"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(1.0).timeout
	world.spawner.set_process(false)
	for t in world.targets:
		if is_instance_valid(t): t.global_position += Vector3(0, -300, 0)
	world.get_node("Interface").visible = false
	var p: CharacterBody3D = world.player
	p.set_physics_process(false)
	p.visible = false
	p.rig.visible = false
	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 340
	root.add_child(cam)
	cam.current = true
	var n := 0
	for spot in SPOTS:
		var ground: float = world.terrain.height(spot.x, spot.z)
		p.global_position = Vector3(spot.x, ground, spot.z)
		for view in [[Vector3(0, 1.6, 0), Vector3(3, 0.2, -6)], [Vector3(0, 1.7, 0), Vector3(-12, 1.0, -30)], [Vector3(0, 7, 6), Vector3(0, 0, -8)]]:
			cam.global_position = p.global_position + view[0]
			cam.look_at(p.global_position + view[1])
			for i in 90: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/prato_%s_%d.png" % [tag, n]))
			n += 1
		var start := Time.get_ticks_usec()
		for i in 240: await process_frame
		print("FPS prato %s: %.0f  (oggetti %d, draw call %d)" % [tag, 240.0 / (float(Time.get_ticks_usec() - start) / 1e6),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit()
