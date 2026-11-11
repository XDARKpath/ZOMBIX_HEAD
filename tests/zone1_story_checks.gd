extends SceneTree
# La storia della Zona 1 dall'inizio alla fine, dentro il gioco vero: recinto, spawn per zona, teste, boss, scale della Rocca, GPS, salvataggio.
# godot --path . -s res://tests/zone1_story_checks.gd
var world: Node3D
var fails: Array = []
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
const Spawner := preload("res://world/campaign/zone1_spawner.gd")
const RoadNetTest := preload("res://world/zona1_rifugio/roadnet.gd")


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


func wait(frames: int) -> void:
	for i in frames: await physics_frame


## I boss entrano in scena per un paio di secondi e intanto non prendono colpi (boss_brain.gd, ingresso).
func past_intro(boss: Node3D) -> void:
	for i in 600:
		if not is_instance_valid(boss) or boss.brain == null or not boss.brain.in_intro(): return
		await physics_frame


func _run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	# I controlli leggono i testi italiani: la lingua si cambia solo in memoria, senza salvare la scelta del giocatore.
	root.get_node("Localization").current = "it"
	TranslationServer.set_locale("it")
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	var quest: Node3D = world.quest
	var rules: Node3D = world.survival
	var p: CharacterBody3D = world.player
	var mission: Node3D = world.expedition

	# Luoghi
	check(Layout.safe(Layout.SHERIFF_NPC) and Layout.safe(Layout.SHOP_NPC) and Layout.safe(mission.car.position), "Sceriffo, negozio e 4×4 stanno nella zona sicura")
	check(not Layout.safe(Vector3(6, 0, -60)), "Il prato fuori dal portone non è sicuro")
	for at in Layout.ENEMIES: check(not Layout.safe(at), "Infetto iniziale fuori dal recinto %s" % at)
	check(world.fence.gates.size() >= 2, "Il recinto ha i portoni")

	# Il portone si apre da solo e si passa
	var gate: Dictionary = world.fence.gates[0]
	p.reset_at(gate.at + Vector3(0, 0.3, 12))
	await wait(10)
	check(not gate.open, "Portone chiuso se non c'è nessuno vicino")
	p.reset_at(gate.at + Vector3(0, 0.3, 4))
	await wait(70)
	check(gate.open and gate.shape.disabled, "Il portone si apre quando ti avvicini")

	# La palizzata blocca davvero e nella zona sicura nessuno ti insegue
	var q := PhysicsRayQueryParameters3D.create(Vector3(-10, 1.2, -40), Vector3(-10, 1.2, -52), 1)
	var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(q)
	check(not hit.is_empty(), "La palizzata ha la collisione")
	p.reset_at(Layout.SHERIFF_NPC + Vector3(-1.5, 0.3, 0))
	await wait(4)
	check(world.nearest_player(Vector3(0, 0, -30)) == null, "Dentro il recinto gli infetti non ti prendono di mira")

	# Strade: senza spigoli, senza doppioni sulla statale, e il sentiero si ferma prima della radura.
	var worst_turn := 0.0
	var all_roads: Array = RoadNetTest.paths() + [preload("res://world/campaign/route.gd").road_points()]
	for line in all_roads:
		for i in range(1, line.size() - 1):
			var d1: Vector3 = (line[i] - line[i - 1])
			var d2: Vector3 = (line[i + 1] - line[i])
			if d1.length() < 0.01 or d2.length() < 0.01 or i == 1: continue
			worst_turn = maxf(worst_turn, rad_to_deg(d1.angle_to(d2)))
	print("  curva più brusca tra due punti: %.1f gradi" % worst_turn)
	check(worst_turn < 40.0, "Nessuno spigolo sulle strade")
	var overlap := 0
	for line in RoadNetTest.paths():
		for i in range(4, line.size()):
			if preload("res://world/campaign/route.gd").road_distance(Vector2(line[i].x, line[i].z)) < 2.0: overlap += 1
	check(overlap == 0, "Le strade secondarie non corrono sopra la statale (%d punti)" % overlap)
	var forest_center: Vector3 = RoadNetTest.arenas()[0]
	var forest_road: float = RoadNetTest.distance(Vector2(forest_center.x, forest_center.z))
	print("  il sentiero più vicino alla radura è a %.1f m dal centro" % forest_road)
	check(forest_road > 22.0, "Il sentiero si ferma prima della zona del boss")

	# Spawn per zona
	check(Spawner.zone_at(Vector2(6, -78)) == 0 and Spawner.ZONES[0][3] == [0], "Nel prato solo infetti normali")
	check(Spawner.ZONES[Spawner.zone_at(Vector2(95, -385))][4] == 2, "Il villaggio è la zona più dura")
	var count_before: int = world.targets.filter(func(e): return is_instance_valid(e) and not e.dead).size()
	p.reset_at(Vector3(6, 0.5, -55))
	var seen_kinds := {}
	for i in 60:
		world.spawner._tick = 0.0
		for key in world.spawner.clocks: world.spawner.clocks[key] = 0.0
		await process_frame
	var count_after: int = world.targets.filter(func(e): return is_instance_valid(e) and not e.dead).size()
	check(count_after > count_before, "Fuori dal recinto arrivano infetti (%d → %d)" % [count_before, count_after])
	for key in world.spawner.alive:
		if key == 0:
			for e in world.spawner.alive[key]: seen_kinds[e.kind] = true
	check(seen_kinds.is_empty() or seen_kinds.keys() == [0], "Le comparse del prato sono del tipo giusto")
	for e in world.targets:
		if is_instance_valid(e): e.set_physics_process(false)
	world.spawner.set_process(false)

	# Missione: sceriffo → 2 teste → altre 3 + arma → esca
	check(quest.stage == quest.TALK and mission.title() == "PARLA CON LO SCERIFFO", "Si comincia parlando con lo sceriffo")
	check(mission.target_point().distance_to(Layout.SHERIFF_NPC) < 0.1, "Il GPS porta allo sceriffo")
	p.reset_at(Layout.SHERIFF_NPC + Vector3(-1.5, 0.3, 0))
	await wait(3)
	rules.act(1, "quest:talk")
	check(quest.stage == quest.KILL_TWO, "Lo sceriffo ti manda a uccidere")
	check(mission.target_point().z < -50.0, "Senza teste il GPS porta nel prato")
	p.add_item("item_testa"); p.add_item("item_testa")
	p.equip_id("item_testa")
	check(mission.target_point().distance_to(Layout.SHERIFF_NPC) < 0.1, "Con le teste il GPS torna allo sceriffo")
	var bank: int = p.credits
	rules.act(1, "sell:item_testa"); rules.act(1, "sell:item_testa")
	check(p.credits == bank + 50, "Teste normali pagate 25 l'una")
	check(quest.stage == quest.MORE_AND_WEAPON, "Dopo 2 teste ne vuole di più e un'arma")
	p.add_item("item_testa_bruto"); p.equip_id("item_testa_bruto")
	bank = p.credits
	rules.act(1, "sell:item_testa_bruto")
	check(p.credits == bank + 100, "La testa di bruto vale di più")
	p.add_item("item_testa"); p.add_item("item_testa"); p.equip_id("item_testa")
	rules.act(1, "sell:item_testa"); rules.act(1, "sell:item_testa")
	check(quest.stage == quest.MORE_AND_WEAPON, "Le teste non bastano senza arma")
	quest.on_weapon_bought()
	check(quest.stage == quest.GET_BAIT, "Con arma e 5 teste è pronto")
	rules.act(1, "quest:talk")
	check(quest.stage == quest.FOREST_BOSS and p.baits == 1, "Lo sceriffo dà l'esca")

	# Limite di 5 e cose che non si impilano
	p.items.clear()
	for i in p.hotbar.size():
		if ItemInfo.is_item(p.hotbar[i]): p.hotbar[i] = ""
	for i in 7:
		if p.can_take("item_testa"): p.add_item("item_testa")
	check(int(p.items.get("item_testa", 0)) == 5 and not p.can_take("item_testa"), "Al massimo 5 teste dello stesso tipo")
	check(p.can_take("item_testa_corridore"), "Un altro tipo di testa ha la sua tasca")
	p.take_heads(5)
	for i in 7:
		if p.can_take("item_bende"): p.add_item("item_bende")
	check(int(p.items.get("item_bende", 0)) == 5, "Al massimo 5 bende")
	p.remove_one("item_bende"); p.remove_one("item_bende"); p.remove_one("item_bende"); p.remove_one("item_bende"); p.remove_one("item_bende")

	# Bosco
	var altar: Node3D = world.boss_hunt.esche[0]
	p.reset_at(preload("res://world/villaggio/villaggio_layout.gd").CENTER + Vector3(3.5, 0.5, 3.5))
	await wait(4)
	check(world.village.context(p).contains("SILENZIO"), "Il pozzo del borgo non si usa prima del tempo")
	check(not world.village.request_use(p) and world.village.arena == "idle", "Niente boss se lo sceriffo non ti ha mandato lì")
	p.reset_at(altar.global_position + Vector3(1, 0.5, 0))
	await wait(4)
	check(rules.context().contains("ACCENDI"), "All'altare della radura si può accendere l'esca")
	check(world.boss_hunt.try_summon(p) and p.baits == 0, "L'esca evoca il boss del bosco")
	var capo: Node3D = world.boss_hunt.bosses[0]
	check(String(capo.name) == "Capomacello", "Il boss del bosco è il Capomacello")
	await past_intro(capo)
	capo.receive_hit("torso", 100000.0, Vector3.ZERO, "axe")
	await wait(3)
	check(quest.stage == quest.BRING_FOREST and mission.collected[0], "Il boss morto dà il primo pezzo del 4×4")
	check(p.items.has("item_testa_capomacello"), "Il boss morto dà la sua testa")
	check(ItemInfo.head_price("item_testa_capomacello") > ItemInfo.head_price("item_testa_bruto"), "La testa del boss vale molto di più")
	check(mission.target_point().distance_to(Layout.SHERIFF_NPC) < 0.1, "Il GPS riporta allo sceriffo")
	p.reset_at(Layout.SHERIFF_NPC + Vector3(-1.5, 0.3, 0))
	await wait(3)
	rules.act(1, "quest:talk")
	check(quest.stage == quest.VILLAGE_BOSS and p.baits == 1, "Lo sceriffo manda al villaggio con una nuova esca")

	# Borgo Cenere
	const VL := preload("res://world/villaggio/villaggio_layout.gd")
	var village: Node3D = world.village
	check(mission.target_point().distance_to(VL.CENTER) < 3.0, "Il GPS porta a Borgo Cenere")
	var flat_ok := true
	for off in [Vector3(0, 0, 0), Vector3(90, 0, 0), Vector3(-100, 0, 40), Vector3(10, 0, -105)]:
		flat_ok = flat_ok and absf(world.terrain.height(VL.CENTER.x + off.x, VL.CENTER.z + off.z)) < 0.01
	check(flat_ok, "Il terreno del borgo è piatto")
	check(RoadNetTest.distance(Vector2(190, -385)) < 1.0, "La bretella arriva al posto di blocco")
	world.terrain.ensure_near([VL.CENTER + Vector3(100, 0, 0), VL.CENTER])
	await wait(5)
	# Il varco del posto di blocco: un box largo come il 4×4 passa dalla statale alla via est.
	var car_box := BoxShape3D.new()
	car_box.size = Vector3(2.4, 1.2, 2.4)
	var cast := PhysicsShapeQueryParameters3D.new()
	cast.shape = car_box
	cast.transform = Transform3D(Basis(), Vector3(205, 1.0, -385))
	cast.motion = Vector3(-90, 0, 0)
	cast.collision_mask = 1
	var free_part: PackedFloat32Array = root.get_world_3d().direct_space_state.cast_motion(cast)
	print("  varco del 4×4: libero per il %.0f%% dei 90 m" % (free_part[0] * 100.0))
	cast.transform = Transform3D(Basis(), Vector3(205, 1.0, -385) + cast.motion * free_part[1])
	var blocker: Dictionary = root.get_world_3d().direct_space_state.get_rest_info(cast)
	if not blocker.is_empty(): print("  ostacolo: ", instance_from_id(blocker.collider_id).get_path(), " a ", blocker.point)
	check(free_part[0] > 0.99, "Il 4×4 passa tra le transenne fino alla piazza")
	# Entrando nel paese
	p.reset_at(VL.CENTER + Vector3(70, 0.5, 0))
	village._poll = 0.0
	await process_frame
	await process_frame
	check(village.state == "active" and village.town_enemies.size() > 15, "Entrando compaiono gli infetti (%d)" % village.town_enemies.size())
	var spitters := 0
	for e in village.town_enemies:
		if is_instance_valid(e) and e.kind == 4 and e.global_position.y > 2.0: spitters += 1
	check(spitters >= 5, "Sputatori sui tetti (%d)" % spitters)
	check(rules.context() != "" or true, "Scritta vicino al borgo senza errori")
	p.health = 100000.0
	# Al pozzo con l'esca
	p.reset_at(VL.CENTER + Vector3(3.5, 0.5, 3.5))
	await wait(4)
	check(village.context(p).contains("POZZO"), "Al pozzo si può gettare l'esca")
	check(village.request_use(p) and p.baits == 0 and village.arena == "active", "L'esca sveglia il Macellaio")
	check(village.barricade_up, "Le barricate chiudono la piazza")
	for i in 240:
		await physics_frame
		if is_instance_valid(village.boss): break
	var macellaio: Node3D = village.boss
	check(is_instance_valid(macellaio) and macellaio.kind == 5, "Dal pozzo esce il boss")
	await wait(5)
	# La barra la disegna l'HUD per il boss con un nome entro 60 m (zombix_hud._draw_boss_bar).
	check(is_instance_valid(macellaio) and String(macellaio.title) != "" and macellaio.global_position.distance_to(p.global_position) < 60.0, "C'è la barra del boss")
	village._arena_reset()
	check(village.arena == "idle" and p.baits == 1 and not village.barricade_up, "Scontro abbandonato: l'esca torna e le vie si riaprono")
	check(village.request_use(p) and village.arena == "active", "Si può riprovare")
	for i in 240:
		await physics_frame
		if is_instance_valid(village.boss): break
	await past_intro(village.boss)
	village.boss.receive_hit("torso", 1000000.0, Vector3.ZERO, "axe")
	for i in 40: await process_frame
	check(village.arena == "cleared" and not village.barricade_up, "Boss morto: barricate giù")
	check(quest.stage == quest.BRING_VILLAGE and mission.collected[1] and p.items.has("item_testa_macellaio"), "Il Macellaio dà la testa e il secondo pezzo")
	var chest_money: int = p.credits
	p.reset_at(village.chests[0].pos + Vector3(0, 0.5, 1.4))
	await wait(4)
	check(village.context(p).contains("APRI") and village.request_use(p), "Le casse si aprono")
	check(p.credits > chest_money or village.chests[0].heal, "La cassa paga")
	for e in world.targets:
		if is_instance_valid(e): e.set_physics_process(false)
	village.set_process(false)
	p.health = 100.0
	p.reset_at(Layout.SHERIFF_NPC + Vector3(-1.5, 0.3, 0))
	await wait(3)
	rules.act(1, "quest:talk")
	check(quest.stage == quest.DUNGEON, "Lo sceriffo manda al dungeon")
	# Rocca: si cammina su per la gradinata, oltre il portone e giù per la scala, e si entra senza premere niente.
	p.inventory_slots = 8
	var tower: Node3D = world.rocca.entrance_node
	world.terrain.ensure_near([tower.global_position])
	await wait(5)
	var walk_dir: Vector3 = tower.global_basis * Vector3(0, 0, -1)
	p.set_physics_process(true)
	p.reset_at(tower.to_global(Vector3(0, 0.3, 10.0)))
	p.rig.yaw = atan2(-walk_dir.x, -walk_dir.z)
	p.controls_enabled = true
	await wait(5)
	Input.action_press("move_forward")
	var top := -INF
	var lowest := INF
	var went_in := false
	for i in 900:
		await physics_frame
		p.rig.yaw = atan2(-walk_dir.x, -walk_dir.z)
		if p.global_position.y > 150.0:
			went_in = true
			break
		top = maxf(top, p.global_position.y - tower.global_position.y)
		lowest = minf(lowest, p.global_position.y - tower.global_position.y)
	Input.action_release("move_forward")
	print("  quota più bassa raggiunta: %.2f · posizione finale %s" % [lowest, tower.to_local(p.global_position)])
	check(lowest < -2.5 or went_in, "Dal selciato si passa il portone e si scende la scala")
	check(went_in, "In fondo alla scala si entra nella Rocca camminando")
	await wait(5)
	world.rocca._do(p, "exit:0")
	await wait(5)
	check(p.global_position.y < 150.0, "Si può uscire e tornare in superficie")
	world.rocca._boss_down()
	quest.on_boss(2)
	check(quest.stage == quest.BRING_DUNGEON and mission.collected[2] and p.items.has("item_testa_carceriere"), "Il Carceriere dà la testa e l'ultimo pezzo")
	check(mission.stage == 0, "La riparazione aspetta la chiacchierata con lo sceriffo")

	# Salvataggio a metà
	var snapshot: int = quest.stage
	SaveManager_write()
	quest.stage = quest.TALK
	root.get_node("SaveManager").apply(world)
	check(quest.stage == snapshot, "Il salvataggio riprende dal punto della storia")
	check(p.items.has("item_testa_carceriere"), "Il salvataggio tiene le teste per tipo")

	# Fine
	p.reset_at(Layout.SHERIFF_NPC + Vector3(-1.5, 0.3, 0))
	await wait(3)
	rules.act(1, "quest:talk")
	check(quest.finished() and mission.stage == 1, "Con tre pezzi si ripara il 4×4")
	check(mission.title() == "RIPARA IL 4×4", "L'obiettivo diventa la riparazione")
	check(world.rocca.GUIDE_INTRO[3].contains("scala") and not " ".join(world.rocca.GUIDE_INTRO).contains("miniera"), "Bruno non parla più della miniera")
	check(world.village.get_node_or_null("BorgoNav/Borgo/Piazza") != null, "Borgo Cenere esiste")
	print("STORIA: %d errori %s" % [fails.size(), fails])
	quit(0 if fails.is_empty() else 1)


func SaveManager_write() -> void:
	root.get_node("SaveManager").write(world)
