extends SceneTree
# Un foglio per ogni attacco degli infetti.
#   godot --path . --resolution 1280x720 --fixed-fps 30 -s res://tests/zombie_attack_shots.gd -- <cartella>
const CLIPS := {"Z_Attack_Lunge_Bite": 0, "Z_Attack_Headbutt": 0, "Z_Attack_Jab": 0, "Z_Attack_Swipe_R": 0, "Z_Attack_Overhead_Smash": 2}
const AT := Vector3(14, 140.02, -60)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	world.spawner.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.queue_free()
	world.get_node("Interface").visible = false
	world.player.visible = false
	world.player.set_physics_process(false)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	world.add_child(floor_body)
	floor_body.global_position = Vector3(AT.x, 140.0, AT.z)
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.current = true
	var motion: Script = load("res://art/infected_motion.gd")
	for clip in CLIPS:
		var e: Node3D = world._spawn_enemy(AT, 100)
		e.set_kind(CLIPS[clip])
		e.set_physics_process(false)
		e.rotation.y = 0.0
		for i in 8: await process_frame
		var timing: Array = motion.attack_timing(clip)
		e.attack_clip = clip
		e.attack_hit = timing[1]
		e.state = 2
		var sheet := Image.create(240 * 8, 270, false, Image.FORMAT_RGB8)
		for k in 8:
			var t: float = float(timing[0]) * float(k) / 7.0
			e.attack_clock = t
			cam.global_position = e.global_position + Vector3(2.4, 1.0, -2.2)
			cam.look_at(e.global_position + Vector3.UP * 0.9)
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			var crop := img.get_region(Rect2i(320, 0, 640, 720))
			crop.resize(240, 270, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(crop, Rect2i(0, 0, 240, 270), Vector2i(k * 240, 0))
		sheet.save_png(folder.path_join(clip + ".png"))
		print(clip, " durata ", timing[0], " colpo ", timing[1])
		e.queue_free()
		await process_frame
	print("FINE")
	quit(0)
