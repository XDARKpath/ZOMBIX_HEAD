extends SceneTree
# Si entra nella torre e si scende la scala camminando, con la camera del giocatore: una foto a ogni tappa, in user://rocca_walk/.
# godot --path . -s res://tests/rocca_walk.gd
var world: Node3D
var p: CharacterBody3D
var tower: Node3D
var stops := [6.5, 4.0, 2.6, 1.3, 0.2, -0.9, -2.0, -3.1, -4.2, -5.0]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://rocca_walk"))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await physics_frame
	world.spawner.set_process(false)
	world.village.set_process(false)
	world.get_node("Interface").visible = false
	p = world.player
	p.select_slot(-1)
	tower = world.rocca.entrance_node
	world.terrain.ensure_near([tower.global_position])
	p.reset_at(tower.to_global(Vector3(0, 0.3, 9.0)))
	p.controls_enabled = true
	var dir: Vector3 = tower.global_basis * Vector3(0, 0, -1)
	p.rig.camera.current = true
	for i in 20: await physics_frame
	var index := 0
	Input.action_press("move_forward")
	var clock := 0
	while index < stops.size() and clock < 2400 and p.global_position.y < 150.0:
		clock += 1
		p.rig.yaw = atan2(-dir.x, -dir.z)
		p.rig.pitch = -0.3 if index >= 2 else -0.05
		await physics_frame
		var local := tower.to_local(p.global_position)
		if local.z <= float(stops[index]):
			Input.action_release("move_forward")
			for i in 8: await physics_frame
			await RenderingServer.frame_post_draw
			var head := tower.to_local(p.rig.camera.global_position)
			var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 1.0, p.global_position + Vector3.UP * 6.0, 1)
			var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(q)
			print("TAPPA z=%.2f piedi y=%.2f occhi y=%.2f spazio sopra i piedi=%s" % [local.z, local.y, head.y, ("%.2f" % (hit.position.y - p.global_position.y)) if not hit.is_empty() else "libero"])
			root.get_texture().get_image().save_png("user://rocca_walk/%02d_z_%s.png" % [index, str(stops[index])])
			index += 1
			Input.action_press("move_forward")
	Input.action_release("move_forward")
	print("FINE tappe=%d quota=%.1f" % [index, p.global_position.y])
	quit(0)
