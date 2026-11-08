extends SceneTree
# Foto del viewmodel a metà ricarica (pistola e pompa) nella Zona 1. Serve una finestra vera, non --headless.
# Uso: Godot --path . -s res://tests/reload_capture.gd -- --shots=<cartella>
func _initialize(): call_deferred("run")
func run():
	var dir := ProjectSettings.globalize_path("res://../screenshots")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): dir = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(dir)
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate(); root.add_child(world); world.automated = true
	root.get_node("Session").launch(); await create_timer(2.0).timeout
	var p: CharacterBody3D = world.player
	p.reset_at(Vector3(6, 0.1, 2)); p.rig.yaw = PI; p.rig.pitch = -0.05
	p.owned.assign(["axe", "pistol", "pump_shotgun"])
	p.hotbar.assign(["pistol", "pump_shotgun", "axe", "", "", "", "", "", ""])
	for id in ["pistol", "pump_shotgun"]:
		p.select_slot(p.hotbar.find(id))
		await create_timer(1.0).timeout
		p.magazine = 1
		p.reload_weapon()
		await create_timer(p.reload_total * 0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("reload_%s.png" % id))
		print("shot %s mag=%d left=%.2f/%.2f" % [id, p.magazine, p.reload_left, p.reload_total])
	quit()
