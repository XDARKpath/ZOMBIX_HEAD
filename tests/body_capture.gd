extends SceneTree
var world: Node3D
var folder: String
func _initialize(): call_deferred("run")
func run():
	folder = ProjectSettings.globalize_path("res://../ZOMBIX-HEAD-0.15-Foto")
	DirAccess.make_dir_recursive_absolute(folder)
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	world.player.set_physics_process(false)
	world.player.rig.set_physics_process(false)
	world.get_node("Interface").hide()
	# Mostra il corpo del giocatore e mettilo in posa di camminata davanti alla camera.
	if world.player.visual:
		world.player.visual.visible = true
	world.player.velocity = Vector3(0, 0, 2.2)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 45
	await create_timer(0.6).timeout
	var at: Vector3 = world.player.global_position
	cam.position = at + Vector3(2.4, 1.5, 3.0)
	cam.look_at(at + Vector3(0, 1.0, 0))
	cam.current = true
	world.player.visual.rotation.y = PI
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/body-01.png")
	print("PHOTO body-01")
	quit()
