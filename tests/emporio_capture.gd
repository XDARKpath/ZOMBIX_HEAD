extends SceneTree
# Emporio di Big Earl (armeria della Zona 1): res://../screenshots/emporio-<vista>.png
const Layout = preload("res://world/zona1_rifugio/refuge_layout.gd")
func _initialize(): call_deferred("run")
func shot(cam: Camera3D, from: Vector3, at: Vector3, fov: float, name: String) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(at)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/emporio-%s.png" % name))
func run():
	var world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.8).timeout
	world.get_node("Interface").visible = false
	var p = world.player
	p.set_physics_process(false)
	var armory: Node3D = world.landscape.get_node("RefugeBuildings/Armory")
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	# Il cliente davanti al bancone guarda il pannello dietro Big Earl.
	var eye: Vector3 = armory.to_global(Vector3(-1.9, 1.65, 4.6))
	p.global_position = armory.to_global(Vector3(-1.9, 0.1, 4.2))
	await shot(cam, eye, armory.to_global(Vector3(-1.9, 1.55, 1.2)), 62, "banco")
	await shot(cam, armory.to_global(Vector3(-1.9, 1.75, 3.2)), armory.to_global(Vector3(-1.9, 1.75, 1.2)), 55, "pannello")
	await shot(cam, armory.to_global(Vector3(-2.4, 1.6, 5.1)), armory.to_global(Vector3(-4.3, 1.55, 5.1)), 55, "vetrina")
	var npc: Node3D = world.survival.shop_npc
	print("venditore ", npc.npc, " · ", npc.title())
	var names := []
	for c in armory.get_children():
		if String(c.name).begins_with("Stock_"): names.append(String(c.name).trim_prefix("Stock_"))
	print("in vendita appese: ", names)
	quit()
