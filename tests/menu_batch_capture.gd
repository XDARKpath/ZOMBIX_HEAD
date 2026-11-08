extends SceneTree
# Menu al falò con i batch ZOMBIX: res://../screenshots/menu-batch.png e menu-skins.png
func _initialize(): call_deferred("run")
func shot(id: String) -> void:
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/menu-" + id + ".png"))
	print("shot ", id)
func run():
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	world.set("automated", true)
	root.add_child(world)
	await create_timer(2.5).timeout
	await shot("batch")
	world.choose_skin(8)
	world.menu.skins()
	await shot("skins")
	world.choose_skin(0)
	quit()
