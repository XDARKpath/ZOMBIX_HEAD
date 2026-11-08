extends SceneTree
# Arco in prima persona (art/zx_fp/SM_FP_Bow.glb) e tiro reale contro uno zombie: res://../screenshots/fpb-<stato>.png
var fails := 0
func _initialize(): call_deferred("run")
func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1
func shot(id: String, wait := 0.15):
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/fpb-" + id + ".png"))
## Solo lo zombie della prova: senza spawner e senza gli altri zombie, che attaccano il giocatore fermo e lo uccidono a caso.
func clear_world(world) -> void:
	world.spawner.set_process(false)
	world.spawner.set_physics_process(false)
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)
func run():
	var world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.5).timeout
	world.get_node("Interface").visible = false
	var p = world.player
	p.set_physics_process(false)
	p.rig.set_physics_process(false)
	p.position = Vector3(8, 0.1, -11)
	p.rig.yaw = 0
	p.rig.pitch = 0
	p.rig.reset_follow()
	var m = p.melee
	p.owned.append("bow")
	p.equipped = "bow"
	p.arrows = 3
	var vm = p.rig.camera.get_node("Viewmodel/FpBow")
	var gps = world.get_node("Interface").find_child("RouteGPS", true, false)
	if gps: gps.opened = false
	await shot("idle", 0.8)
	check(vm.visible, "Viewmodel dell'arco attivo")
	m.set_physics_process(false)
	m.charging = true
	m.charge_time = 0.1
	await shot("draw", 0.1)
	m.charge_time = 1.0
	await shot("aim", 0.3)
	m.set_physics_process(true)
	m.charging = false
	# Tiro vero: uno zombie a 9 m davanti, nessun altro sulla traiettoria.
	clear_world(world)
	var z = world.targets[0]
	z.global_position = p.global_position + Vector3(0, 0, -9)
	z.set_physics_process(false)
	var hp: float = z.health
	m.begin_charge()
	m.charge_time = 1.0
	m.release_attack()
	check(p.arrows == 2, "Una freccia in meno (%d)" % p.arrows)
	await shot("fire", 0.12)
	await shot("reload", 0.7)
	await create_timer(0.6).timeout
	check(z.health < hp or z.dead, "La freccia colpisce lo zombie (%.0f -> %.0f)" % [hp, z.health])
	check(get_nodes_in_group("arrows").size() >= 1, "Freccia piantata nella scena")
	p.arrows = 0
	m.attacking = false
	await shot("empty", 0.3)
	check(not m.begin_charge(), "Senza frecce non si tende")
	print("FP_BOW ", "OK" if fails == 0 else "FALLITO %d" % fails)
	quit(fails)
