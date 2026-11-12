extends SceneTree
# Foto del prato (da vicino, ad altezza d'occhi, dall'alto) e FPS medi sul prato.
#   godot --path . -s res://tests/grass_capture.gd -- nome         -> res://../screenshots/prato_nome_*.png
#   godot --path . -s res://tests/grass_capture.gd -- nome cammina -> il giocatore cammina nel prato:
#     fotogrammi in sequenza in prima persona e da dietro (prato_nome_fp_*.png, prato_nome_tp_*.png) e FPS in marcia.
const SPOTS := [Vector3(6, 0, -66)]
const WALK_SPEED := 4.5


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var tag: String = args[0] if not args.is_empty() else "ora"
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
	if "cammina" in args:
		await walk(world, p, tag)
		quit()
		return
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


## Il giocatore cammina nel prato a passo costante: prima con la sua camera, poi visto da dietro.
func walk(world: Node3D, p: CharacterBody3D, tag: String) -> void:
	var spot: Vector3 = SPOTS[0]
	var own_cam: Camera3D = p.rig.camera
	var tp := Camera3D.new()
	tp.fov = 70
	tp.far = 340
	root.add_child(tp)
	for mode in ["fp", "tp"]:
		var pos := Vector3(spot.x - 10.0, 0, spot.z + 6.0)
		own_cam.current = mode == "fp"
		tp.current = mode == "tp"
		# Da dietro si vede il corpo e non il viewmodel (come in tests/reload_frames.gd).
		tp.cull_mask = 0xFFFFF & ~(1 << 19)
		for mesh in p.visual.find_children("*", "MeshInstance3D", true, false):
			(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if mode == "tp" else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		var arms := p.find_child("FpArms", true, false)
		if arms:
			for mesh in arms.get_parent().find_children("*", "VisualInstance3D", true, false):
				(mesh as VisualInstance3D).layers = 1 << 19 if mode == "tp" else 1
		var frames := 0
		var shot := 0
		var start := 0
		var last := Time.get_ticks_usec()
		while shot < 8:
			var now := Time.get_ticks_usec()
			var dt := minf(float(now - last) / 1e6, 0.05)
			last = now
			pos.z -= WALK_SPEED * dt
			pos.y = world.terrain.height(pos.x, pos.z)
			p.global_position = pos
			p.rotation.y = 0.0
			tp.global_position = pos + Vector3(0.6, 1.9, 3.2)
			tp.look_at(pos + Vector3(0, 0.3, -2.0))
			await process_frame
			frames += 1
			if frames == 60: start = Time.get_ticks_usec()
			# Dopo un secondo di marcia, un fotogramma ogni 4: si vede se i ciuffi scattano o strisciano.
			if frames >= 120 and frames % 4 == 0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/prato_%s_%s_%d.png" % [tag, mode, shot]))
				shot += 1
		print("FPS prato in marcia %s %s: %.0f  (oggetti %d, draw call %d)" % [tag, mode, (frames - 60) / (float(Time.get_ticks_usec() - start) / 1e6),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
