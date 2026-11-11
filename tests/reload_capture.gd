extends SceneTree
# Foto del viewmodel in tre momenti della ricarica (pistola e pompa) nella Zona 1. Serve una finestra vera, non --headless.
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
	p.owned.assign(["pistol", "pump_shotgun", "assault_rifle", "lmg"])
	p.inventory_slots = 4
	p.hotbar.assign(["pistol", "pump_shotgun", "assault_rifle", "lmg", "", "", "", "", ""])
	var arms: Node = p.find_child("FpArms", true, false)
	var cam: Camera3D = p.rig.camera
	for id in ["pistol", "pump_shotgun", "assault_rifle", "lmg"]:
		p.select_slot(p.hotbar.find(id))
		await create_timer(1.0).timeout
		# Tre momenti: inizio (caricatore fuori / mano alla tasca), metà (pezzo nuovo in mano), fine (scatto / spinta).
		for k in [0.22, 0.5, 0.8]:
			p.magazine = 1
			p.reload_left = 0.0
			await process_frame
			p.reload_weapon()
			# Il frame in finestra è lento: si porta la ricarica al punto voluto e si lasciano assestare le molle.
			p.reload_left = p.reload_total * (1.0 - k) + 0.05
			p._reload_seen = p.reload_left      # non è una ricarica nuova: la durata resta quella vera
			for f in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(dir.path_join("reload_%s_%02d.png" % [id, int(k * 100)]))
			print("shot %s %d%% mag=%d left=%.2f/%.2f" % [id, int(k * 100), p.magazine, p.reload_left, p.reload_total])
			if arms:
				for piece in [arms._carry_mag, arms._carry_shell]:
					print("   piece vis=%s cam=%s on_screen=%s" % [piece.is_visible_in_tree(), cam.global_transform.affine_inverse() * piece.global_position, cam.unproject_position(piece.global_position)])
				if arms._mag: print("   mag vis=%s cam=%s" % [arms._mag.is_visible_in_tree(), cam.global_transform.affine_inverse() * arms._mag.global_position])
				else: print("   mag none")
	quit()
