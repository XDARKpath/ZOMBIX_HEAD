extends SceneTree
# Dungeon della Zona 1: Rocca maledetta + Cripta del Carceriere (world/rocca/rocca.gd, world/dungeon/dungeon.gd).
# Percorre il giro: Bruno all'ingresso -> torre -> Rocca -> botola -> Cripta -> secondini -> risalita -> arena aperta.
# Si entra nella Rocca a piedi, senza tasti: la camminata vera è in zone1_story_checks.gd, qui si usa lo stesso ingresso della porta.
# Foto: res://../screenshots/dng-<vista>.png
var fails := 0
func _initialize(): call_deferred("run")
func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1
func shot(id: String, wait := 0.4):
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/dng-" + id + ".png"))
func look(p, from: Vector3, at: Vector3) -> void:
	p.global_position = from
	var d: Vector3 = (at - (from + Vector3.UP * p.eye_height)).normalized()
	p.rig.yaw = atan2(-d.x, -d.z)
	p.rig.pitch = asin(clampf(d.y, -1.0, 1.0))
	p.rig.reset_follow()
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
	await create_timer(0.8).timeout
	world.get_node("Interface").visible = false
	var gps = world.get_node("Interface").find_child("RouteGPS", true, false)
	if gps: gps.opened = false
	var p = world.player
	p.set_physics_process(false)
	p.rig.set_physics_process(false)
	clear_world(world)
	var r = world.rocca
	var c = world.dungeon
	check(r != null and c != null and r.cripta == c and c.rocca == r, "Rocca e Cripta costruite e collegate")
	check(is_instance_valid(r.guide), "Bruno lo speleologo all'ingresso")
	check(not r.gates["arena_sud"].open, "Saracinesca sud dell'arena chiusa finché la Cripta non è ripulita")
	# superficie
	var tower: Node3D = r.entrance_node
	look(p, tower.to_global(Vector3(-3, 0.1, 16)), tower.to_global(Vector3(0, 3, 0)))
	await shot("surface", 1.2)
	look(p, r.guide_pos + (tower.global_basis * Vector3(-1.5, 0.1, 2.6)), r.guide_pos + Vector3(0, 1.5, 0))
	await shot("guide")
	p.global_position = r.guide_pos + tower.global_basis * Vector3(0, 0, 1.2)
	check(r.request_use(p) and world.survival.dialogue_open, "[E] vicino a Bruno apre il dialogo")
	await shot("guide-talk", 0.6)
	world.survival.choose_sheriff_option(0)
	check(world.survival.dialogue_lines == r.GUIDE_ROUTE, "Bruno spiega il percorso")
	world.survival.close_sheriff_dialogue()
	check(not world.survival.dialogue_open and not world.ui_open, "Dialogo chiuso, comandi restituiti")
	# entra nella torre
	p.global_position = r.entrance_pos
	r._door_entered(p)
	await physics_frame
	check(r.area_of(p.global_position) != "", "Passata la porta si è dentro la Rocca (%s)" % r.area_of(p.global_position))
	var sala: Vector3 = r.to_global(r.cell_pos(Vector2i(-2, 4), r.UP))
	look(p, sala + Vector3(0, 0.1, 1.5), r.to_global(r.cell_pos(Vector2i(2, 3), r.UP + 1.5)))
	await shot("rocca-sala", 0.8)
	# botola della Cripta in fondo al corridoio delle lame
	p.global_position = r.to_global(r.cell_pos(r.HATCH_CELL) + Vector3(0, 0.2, -1.1))
	look(p, p.global_position, r.to_global(r.cell_pos(r.HATCH_CELL) + Vector3(0, 1.2, -3.0)))
	await shot("rocca-botola", 0.6)
	check(r.request_use(p), "[E] sulla botola")
	await create_timer(0.1).timeout
	check(c.area_of(p.global_position) != "", "Nella Cripta (%s)" % c.area_of(p.global_position))
	look(p, p.global_position, p.global_position + Vector3(0, 1.4, -6))
	await shot("cripta-ingresso", 0.8)
	# sputatore e Carceriere: costruzione dei tipi nuovi
	var spitter = world._spawn_enemy(p.global_position + Vector3(2, 0, -6))
	spitter.set_kind(4, 1)
	var boss = world._spawn_enemy(r.to_global(r.OCT_C))
	boss.set_kind(5, 2)
	check(spitter.max_health > 0 and boss.max_health > 1000 and boss.visual.scale.x > 1.5, "Sputatore e Carceriere configurati")
	await create_timer(0.6).timeout
	boss.receive_hit("neck", 90, Vector3.ZERO, "axe", true)
	check(not boss.beheaded and not boss.dead, "Il Carceriere non si decapita")
	boss.queue_free(); spitter.queue_free()
	# sala dei secondini ripulita -> la Rocca alza la saracinesca
	c.rooms["arena"].state = "active"
	c.rooms["arena"].wave = 3
	c._cleared("arena")
	check(r.cripta_done and r.gates["arena_sud"].open, "Secondini caduti: saracinesca dell'arena alzata")
	check(c.gates["uscita"].open, "Porta della risalita aperta")
	p.global_position = c.to_global(c.exits[0])
	check(c.request_use(p) and r.area_of(p.global_position) != "", "Risalita nella Rocca davanti all'arena")
	look(p, p.global_position, r.to_global(r.OCT_C + Vector3(0, 2, 0)))
	await shot("arena-aperta", 0.9)
	print("DUNGEON ", "OK" if fails == 0 else "FALLITO %d" % fails)
	quit(fails)
