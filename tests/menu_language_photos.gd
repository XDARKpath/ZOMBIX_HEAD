extends SceneTree
# Foto con finestra di menu, impostazioni e grafica in italiano e inglese.
# godot --path . -s res://tests/menu_language_photos.gd -- <cartella>
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var folder: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ProjectSettings.globalize_path("user://menu_photos")
	DirAccess.make_dir_recursive_absolute(folder)
	var loc: Node = root.get_node("Localization")
	var before: String = loc.current
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	world.automated = true
	root.add_child(world)
	await create_timer(3.0).timeout
	for code in ["it", "en"]:
		loc.set_language(code)
		for page in ["home", "options", "settings", "graphics", "language"]:
			match page:
				"home": world.menu.home()
				"options": world.menu.options_menu()
				"settings": world.menu.settings()
				"graphics": world.menu.graphics()
				"language": world.menu.language()
			await create_timer(0.8).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/menu_%s_%s.png" % [folder, page, code])
	loc.set_language(before)
	quit()
