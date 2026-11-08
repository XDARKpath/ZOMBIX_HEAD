extends SceneTree
# Misura FPS della mappa, sempre con gli stessi punti e lo stesso giro in auto. Vsync spento, 1280×720.
# godot --path . -s res://tests/map_bench.gd -- --out=<cartella per le foto>
const L := preload("res://world/villaggio/villaggio_layout.gd")
var world: Node3D
var p: CharacterBody3D
var out := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
	if out != "": DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var t0 := Time.get_ticks_msec()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	print("BENCH mondo costruito in ms ", Time.get_ticks_msec() - t0)
	print("BENCH scheda ", RenderingServer.get_video_adapter_name())
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	p = world.player
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--far="):
			world.terrain.far_open = float(arg.substr(6))
			world.terrain.far_closed = world.terrain.far_open
			print("BENCH far ", world.terrain.far_open)
	world.spawner.set_process(false)
	world.village.set_process(false)
	p.set_physics_process(false)
	var c: Vector3 = L.CENTER
	await _still("rifugio", Vector3(6, 0, -6), 0.0)
	await _still("piazza", c + Vector3(15, 0, 13), 0.85)
	await _still("borgo_da_fuori", c + Vector3(116, 0, 3), 1.5)
	await _still("strada_bosco", Vector3(60, 0, -900), 0.3)
	await _still("strada_lontana", Vector3(1600, 0, -2000), 0.0)
	await _drive()
	print("BENCH fine")
	quit(0)


func _still(title: String, at: Vector3, yaw: float) -> void:
	at.y = world.terrain.height(at.x, at.z)
	world.terrain.ensure_near([at])
	p.reset_at(at + Vector3.UP * 0.3)
	p.rig.yaw = yaw
	p.rig.pitch = -0.05
	for i in 60: await process_frame
	var frames: Array = []
	for i in 300:
		var a := Time.get_ticks_usec()
		await process_frame
		frames.append(Time.get_ticks_usec() - a)
	_report(title, frames)
	await _photo(title)


## Giro in auto: 60 s a 24 m/s lungo la statale, con il sedile occupato e il terreno che si carica da solo.
func _drive() -> void:
	var car: CharacterBody3D = world.expedition.car
	car.repaired = true
	p.reset_at(car.position + Vector3(0, 0.3, 2.5))
	for i in 5: await process_frame
	var seated: bool = car.interact(1)
	print("BENCH seduto ", seated)
	car.set_physics_process(false)
	var road: Array = preload("res://world/campaign/route.gd").road_points()
	var leg := 1
	var at: Vector3 = road[0]
	var frames: Array = []
	var clock := 0.0
	var a := Time.get_ticks_usec()
	while clock < 60.0 and leg < road.size():
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := minf((now - a) / 1000000.0, 0.1)
		frames.append(now - a)
		a = now
		clock += dt
		var goal: Vector3 = road[leg]
		var flat := at.move_toward(goal, 24.0 * dt)
		at = flat
		if at.distance_to(goal) < 0.5: leg += 1
		car.position = Vector3(at.x, world.terrain.height(at.x, at.z) + 0.2, at.z)
		car.rotation.y = atan2(-(goal - at).x, -(goal - at).z)
		car._place_occupants()
		p.rig.yaw = car.rotation.y
	_report("giro_auto_60s", frames)
	await _photo("giro_auto_fine")


func _report(title: String, frames: Array) -> void:
	frames.sort()
	var total := 0.0
	for f in frames: total += f
	var avg := 1000000.0 * frames.size() / total
	var low: float = 1000000.0 / float(frames[int(frames.size() * 0.99)])
	print("BENCH %-16s media %5.1f fps | 1%% peggiore %5.1f fps | frame peggiore %6.1f ms | oggetti %d | draw %d | tessere %d" % [title, avg, low, frames[-1] / 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), world.terrain.tiles.size()])


func _photo(title: String) -> void:
	if out == "": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(title + ".png"))
