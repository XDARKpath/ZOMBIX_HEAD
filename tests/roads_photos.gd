extends SceneTree
# Foto delle strade, in user://strade/ (godot --path . -s res://tests/roads_photos.gd).
const RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
const Route := preload("res://world/campaign/route.gd")
var world: Node3D
var cam: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://strade"))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	cam = Camera3D.new()
	world.add_child(cam)
	world.spawner.set_process(false)
	world.village.set_process(false)
	world.get_node("Interface").visible = false
	world.player.visible = false
	world.player.set_physics_process(false)
	var forest: Vector3 = RoadNet.arenas()[0]
	var west: Array = RoadNet.paths()[1]
	var end: Vector3 = west[west.size() - 1]
	var along: Vector3 = (end - forest).normalized()
	await _shot("01_fine_sentiero_e_radura", end + along * 12.0 + Vector3.UP * 1.7, forest + Vector3.UP)
	await _shot("02_radura_dall_alto", forest + along * 30.0 + Vector3(0, 20, 0), forest + along * 8.0)
	await _shot("03_curva_statale_a_terra", Vector3(26, 1.7, -130), Vector3(90, 1, -225))
	await _shot("04_curva_statale_dall_alto", Vector3(-5, 24, -125), Vector3(50, 0, -175))
	await _shot("05_bivio_pista_e_statale", Vector3(6, 1.8, -96), Vector3(7, 0.5, -150))
	await _shot("06_bivio_ramo_ovest", Vector3(16, 12, -44), Vector3(-6, 0, -66))
	await _shot("07_ramo_del_bosco", Vector3(-22, 1.7, -66), Vector3(-58, 1, -88))
	await _shot("08_statale_lontano", Vector3(205, 1.7, -395), Vector3(160, 1, -495))
	await _shot("09_bretella_borgo", Vector3(214, 8, -372), Vector3(175, 0, -387))
	await _shot("10_pista_verso_la_rocca", Vector3(-160, 1.7, -222), Vector3(-205, 1, -242))
	quit(0)


func _shot(title: String, eye: Vector3, look: Vector3) -> void:
	world.terrain.ensure_near([eye, look])
	world.player.reset_at(Vector3(eye.x, world.terrain.height(eye.x, eye.z) + 0.3, eye.z))
	for i in 25: await process_frame
	var ground: float = world.terrain.height(eye.x, eye.z)
	cam.global_position = Vector3(eye.x, maxf(eye.y, ground + 1.7), eye.z)
	cam.look_at(look)
	cam.current = true
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://strade/%s.png" % title)
	print("FOTO ", title)