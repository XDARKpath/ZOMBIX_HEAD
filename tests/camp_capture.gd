extends SceneTree
var world: Node3D
var folder: String
func _initialize(): call_deferred("run")
func shot(name: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/" + name + ".png")
	print("PHOTO ", name)
func run():
	folder = ProjectSettings.globalize_path("res://../ZOMBIX-HEAD-0.15-Foto")
	DirAccess.make_dir_recursive_absolute(folder)
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	await create_timer(1.2).timeout
	var ui := world.get_node_or_null("Interface")
	if ui: ui.hide()
	world.camp.camera.current = true
	await shot("camp-01")
	# Primo piano dei tre sopravvissuti.
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 42
	cam.position = world.camp.global_position + Vector3(1.2, 1.45, 4.6)
	cam.look_at(world.camp.global_position + Vector3(0.4, 1.0, 0.0))
	cam.current = true
	await shot("camp-02")
	cam.position = world.camp.global_position + Vector3(-3.6, 1.6, 3.4)
	cam.look_at(world.camp.global_position + Vector3(-0.5, 1.0, 0.0))
	await shot("camp-03")
	quit()
