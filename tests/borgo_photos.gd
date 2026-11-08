extends SceneTree
# Foto di Borgo Cenere nel gioco vero, in user://borgo/ (godot --path . -s res://tests/borgo_photos.gd).
const L := preload("res://world/villaggio/villaggio_layout.gd")
var world: Node3D
var p: CharacterBody3D
var cam: Camera3D
var ui: CanvasLayer
var number := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://borgo"))
	var started_at := Time.get_ticks_msec()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	print("MONDO COSTRUITO IN ms ", Time.get_ticks_msec() - started_at)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	p = world.player
	ui = world.get_node("Interface")
	cam = Camera3D.new()
	world.add_child(cam)
	world.spawner.set_process(false)
	world.village.set_process(false)
	var c: Vector3 = L.CENTER
	# Il villaggio visto dalla strada
	await _place("01_bretella_e_posto_di_blocco", c + Vector3(116, 1.7, 3), c + Vector3(70, 2, 0))
	await _place("02_arco_borgo_cenere", c + Vector3(82, 1.7, -2), c + Vector3(68, 3, 0))
	await _place("03_via_est", c + Vector3(62, 1.7, 1), c + Vector3(20, 2, 0))
	await _place("04_piazza_e_pozzo", c + Vector3(15, 1.7, 13), c + Vector3(0, 1, 0))
	print("FPS PIAZZA ", Engine.get_frames_per_second())
	await _place("05_negozi", c + Vector3(-12, 1.7, 8), c + Vector3(8, 2.5, -18))
	await _place("06_dall_alto", c + Vector3(30, 22, 38), c)
	await _place("07_via_nord_e_chiesa", c + Vector3(3, 1.7, -35), c + Vector3(0, 3, -118))
	await _place("08_chiesa_e_cimitero", c + Vector3(0, 1.7, -92), c + Vector3(0, 4, -125))
	await _place("09_campo_profughi", c + Vector3(-100, 1.7, 8), c + Vector3(-125, 1, 0))
	await _place("10_fattoria", c + Vector3(6, 1.7, 100), c + Vector3(-15, 2, 125))
	await _place("11_cartello_dal_bivio", Vector3(4, 1.7, -142), Vector3(12, 2, -150))
	# Infetti per le vie e sputatori sui tetti
	world.village.set_process(true)
	p.visible = false
	p.set_physics_process(false)
	p.reset_at(c + Vector3(42, 0.3, 0))
	for i in 40: await process_frame
	world.village.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.set_physics_process(false)
	await _hold("12_infetti_nelle_vie", c + Vector3(45, 1.7, 2), c + Vector3(5, 1, 0))
	# Davanti al pozzo, con la scritta della missione
	world.quest.stage = world.quest.VILLAGE_BOSS
	p.baits = 1
	await _fps(c + Vector3(3.5, 0, 3.5), c)
	await _snap("13_il_pozzo_con_l_esca")
	# Lo scontro: barricate su, boss dal pozzo
	world.village.set_process(true)
	world.village._do(p, -1)
	p.health = 100000.0
	for i in 200: await physics_frame
	await _snap("14_boss_prima_persona")
	var boss: Node3D = world.village.boss
	if is_instance_valid(boss):
		boss.set_physics_process(false)
		world.village.set_process(false)
		await _hold("15_macellaio_e_barricate", c + Vector3(-9, 2.2, 9), boss.global_position + Vector3.UP * 1.6)
	# Caduto: barricate giù e casse
	if is_instance_valid(boss):
		world.village.set_process(true)
		boss.receive_hit("torso", 1000000.0, Vector3.ZERO, "axe")
		for i in 90: await process_frame
		var chest_at: Vector3 = world.village.chests[0].pos
		await _fps(chest_at + Vector3(-1.5, 0, 3.0), chest_at)
		await _snap("16_boss_caduto_e_casse")
	# GPS
	await _fps(c + Vector3(30, 0, 1), c + Vector3(10, 0, 0))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_G
	key.pressed = true
	Input.parse_input_event(key)
	for i in 80: await physics_frame
	await _snap("17_gps")
	quit(0)


func _place(title: String, eye: Vector3, look: Vector3) -> void:
	world.terrain.ensure_near([eye, look])
	p.set_physics_process(false)
	p.visible = false
	p.reset_at(Vector3(eye.x, world.terrain.height(eye.x, eye.z) + 0.3, eye.z))
	for i in 25: await process_frame
	await _hold(title, eye, look)


func _hold(title: String, eye: Vector3, look: Vector3) -> void:
	ui.visible = false
	cam.global_position = eye
	cam.look_at(look)
	cam.current = true
	for i in 6: await process_frame
	await _snap(title)


func _fps(at: Vector3, face: Vector3) -> void:
	world.terrain.ensure_near([at])
	ui.visible = true
	p.visible = true
	p.set_physics_process(true)
	p.reset_at(at + Vector3.UP * 0.3)
	p.controls_enabled = true
	p.rig.controls_enabled = false
	var to := face - at
	p.rig.yaw = atan2(-to.x, -to.z)
	p.rig.pitch = -0.1
	p.rig.camera.current = true
	for i in 20: await physics_frame


func _snap(title: String) -> void:
	await RenderingServer.frame_post_draw
	number += 1
	root.get_texture().get_image().save_png("user://borgo/%s.png" % title)
	print("FOTO ", title)
