extends SceneTree
# Primi piani per giudicare modelli e animazioni: infetti, boss, mani con testa e pistola, menu. In user://close/.
# godot --path . -s res://tests/closeups.gd
var world: Node3D
var cam: Camera3D
var p: CharacterBody3D


func _init() -> void:
	call_deferred("_run")


func wait(frames: int) -> void:
	for i in frames: await physics_frame


func _snap(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://close/%s.png" % title)
	print("FOTO ", title)


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://close"))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	# Il menu, prima di partire.
	for i in 40: await process_frame
	await _snap("00_menu")
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	world.spawner.set_process(false)
	p = world.player
	cam = Camera3D.new()
	world.add_child(cam)
	var at := Vector3(12, 0, -74)
	world.terrain.ensure_near([at])
	await wait(5)
	var row := {"tank": 2, "walker": 0, "spitter": 4, "runner": 1}
	p.reset_at(at + Vector3(0, 0.4, 30))
	p.visible = false
	world.get_node("Interface").visible = false
	var x := 0.0
	for key in row:
		var e: Node3D = world._spawn_enemy(at + Vector3(x, 0.1, 0))
		e.set_kind(row[key])
		e.set_physics_process(false)
		e.rotation.y = PI
		await wait(6)
		cam.global_position = e.global_position + Vector3(0, 1.5, 3.0)
		cam.look_at(e.global_position + Vector3.UP * 1.05)
		cam.current = true
		await wait(4)
		await _snap("0%d_%s_davanti" % [int(x / 4.0) + 1, key])
		cam.global_position = e.global_position + Vector3(2.7, 1.8, 0.9)
		cam.look_at(e.global_position + Vector3.UP * 1.25)
		await wait(2)
		await _snap("0%d_%s_lato" % [int(x / 4.0) + 1, key])
		# Colpito: tre istanti della reazione.
		if key == "tank":
			e.receive_hit("torso", 40.0, Vector3(0, 0, -2.0), "axe", true)
			for i in 3:
				await wait(5)
				await _snap("05_bruto_colpito_%d" % i)
		x += 4.0
	var boss: Node3D = world._spawn_enemy(at + Vector3(x + 2, 0.1, 0))
	boss.custom_skin = "res://art/zx_infected/BOSS_Subject_Zero.glb"
	boss.boss_weapon = "cleaver"
	boss.set_kind(5)
	boss._dress()
	boss.set_physics_process(false)
	boss.rotation.y = PI
	await wait(8)
	cam.global_position = boss.global_position + Vector3(1.4, 2.0, 5.0)
	cam.look_at(boss.global_position + Vector3.UP * 1.6)
	await wait(3)
	await _snap("06_macellaio")
	# Mani del giocatore.
	p.visible = true
	p.reset_at(at + Vector3(0, 0.4, 30))
	p.set_physics_process(true)
	p.controls_enabled = true
	p.rig.controls_enabled = false
	p.rig.pitch = -0.05
	p.rig.camera.current = true
	world.get_node("Interface").visible = false
	p.owned.append("pistol")
	p.equip_id("pistol")
	await wait(50)
	await _snap("07_pistola_in_mano")
	p.melee.ads_forced = true
	await wait(30)
	await _snap("07_pistola_mira")
	p.melee.perform_attack(false)
	await wait(4)
	p.melee._aim_strike()
	await wait(1)
	await _snap("07_pistola_sparo")
	p.melee.ads_forced = false
	p.magazine = 0
	await wait(30)
	await _snap("07_pistola_vuota")
	p.magazine = 8
	p.add_item("item_testa")
	p.equip_id("item_testa")
	await wait(50)
	await _snap("08_testa_in_mano")
	p.add_item("item_testa_bruto")
	p.equip_id("item_testa_bruto")
	await wait(50)
	await _snap("09_testa_bruto_in_mano")
	# La pistola da sola, da vicino.
	var gun: Node3D = load("res://art/env/weapons/SM_Wep_Pistol.glb").instantiate()
	world.add_child(gun)
	gun.global_position = at + Vector3(0, 40, 0)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	cam.global_position = gun.global_position + Vector3(0.3, 0.06, 0.05)
	cam.look_at(gun.global_position + Vector3(0, -0.01, 0.04))
	cam.fov = 40.0
	cam.current = true
	world.get_node("Interface").visible = false
	await wait(4)
	await _snap("10_pistola_modello")
	quit(0)
