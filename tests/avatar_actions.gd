extends SceneTree
# Come gli altri giocatori vedono il tuo personaggio: una foto per ogni cosa che può fare. In user://avatar/.
# godot --path . -s res://tests/avatar_actions.gd
var world: Node3D
var other: CharacterBody3D
var cam: Camera3D
var fails: Array = []


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


func wait(frames: int) -> void:
	for i in frames: await physics_frame


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://avatar"))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	world.spawner.set_process(false)
	world.get_node("Interface").visible = false
	world.player.visible = false
	world.player.reset_at(Vector3(6, 0.4, -24))
	# Un secondo giocatore, costruito come fa il gioco in rete.
	other = world._spawn_actor(2, Vector3(6, 0.3, -28)) if world.has_method("_spawn_actor") else null
	if other == null:
		other = load("res://player/player.tscn").instantiate()
		other.local_control = false
		world.add_child(other)
		other.global_position = Vector3(6, 0.3, -28)
		world._dress(other, 2)
		world.actors[2] = other
	other.rig.camera.current = false
	cam = Camera3D.new()
	world.add_child(cam)
	cam.global_position = Vector3(7.3, 1.3, -26.0)
	cam.look_at(Vector3(6, 1.0, -28))
	other.visual.rotation.y = -0.6
	cam.current = true
	await wait(20)
	var driver = other.get_node("Visual").find_children("*", "Node3D", true, false).filter(func(n): return n.get("operative_driver") != null)
	check(not driver.is_empty(), "Il personaggio degli altri ha il suo guidatore di animazioni")
	await _pose("01_fermo")
	other.equipped = "axe"
	await wait(15)
	await _pose("02_con_ascia")
	other.melee.attacking = true
	await wait(10)
	await _pose("03_colpo")
	other.melee.attacking = false
	other.melee.blocking = true
	await wait(12)
	await _pose("04_parata")
	other.melee.blocking = false
	await wait(5)
	other.equipped = "pistol"
	await wait(12)
	await _pose("05_pistola")
	other.items["item_testa"] = 1
	other.equipped = "item_testa"
	await wait(15)
	await _pose("06_testa_in_mano")
	world.survival._set_gesture(other, "give")
	await wait(16)
	await _pose("07_consegna")
	other.items["item_bende"] = 1
	other.equipped = "item_bende"
	await wait(10)
	world.survival._set_gesture(other, "use")
	await wait(16)
	await _pose("08_si_cura")
	other.equipped = "item_testa"
	await wait(8)
	world.survival._set_gesture(other, "throw")
	await wait(14)
	await _pose("09_lancio")
	other.equipped = ""
	await wait(8)
	world.survival._set_gesture(other, "wave")
	await wait(26)
	await _pose("10_saluto")
	await wait(40)
	other.set_meta("hit_heavy_until", Time.get_ticks_msec() + 500)
	await wait(12)
	await _pose("11_sbalzato")
	await wait(30)
	other.crouching = true
	await wait(20)
	await _pose("12_accucciato")
	other.crouching = false
	other.dodging = true
	await wait(10)
	await _pose("13_schivata")
	other.dodging = false
	await wait(30)
	other.dead = true
	await wait(40)
	await _pose("14_morto")
	print("AVATAR: %d errori %s" % [fails.size(), fails])
	quit(0 if fails.is_empty() else 1)


func _pose(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://avatar/%s.png" % title)
	print("FOTO ", title)
