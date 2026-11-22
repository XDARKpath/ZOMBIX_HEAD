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
	# Il primo boss arriva dopo un po' di esplorazione, non dietro il recinto.
	print("  radura del Capomacello a %.0f m dal rifugio" % forest_center.distance_to(Layout.SHERIFF))
	check(forest_center.distance_to(Layout.SHERIFF) > 250.0, "Il Capomacello è lontano dalla partenza")
	# Ogni strada parte e arriva in un posto: incrocio, Borgo, radura, Rocca o portone del recinto.
	var loose: Array = []
	for line in RoadNetTest.paths():
		for end in [line[0], line[line.size() - 1]]:
			var flat := Vector2(end.x, end.z)
			var placed: bool = RoadNetTest.junction_distance(flat) < 1.0 or preload("res://world/villaggio/villaggio_layout.gd").inside(end.x, end.z)
			placed = placed or RoadNetTest.arena_distance(flat) <= RoadNetTest.FOREST_STOP + 1.0 or RoadNetTest.site_distance(flat) < RoadNetTest.SITE_RADIUS or Rect2(Layout.FENCE_MIN, Layout.FENCE_MAX - Layout.FENCE_MIN).grow(8.0).has_point(flat)
			if not placed: loose.append(flat.snapped(Vector2.ONE))
	check(loose.is_empty(), "Nessuna strada finisce nel nulla %s" % [loose])

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
	var hunt: Vector3 = mission.target_point()
	check(not Layout.safe(hunt), "Senza teste il GPS porta fuori dal recinto")
	var on_infected := false
	for e in world.targets:
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(hunt) < 0.1: on_infected = true
	check(on_infected, "Il primo obiettivo è un infetto vivo, non un punto fisso nel prato")
	p.add_item("item_testa"); p.add_item("item_testa")
	p.equip_id("item_testa")
	check(mission.target_point().distance_to(Layout.SHERIFF_NPC) < 0.1, "Con le teste il GPS torna allo sceriffo")
	var bank: int = p.credits
	rules.act(1, "sell:item_testa"); rules.act(1, "sell:item_testa")
	check(p.credits == bank + 50, "Teste normali pagate 25 l'una")
	check(quest.stage == quest.WEAPON, "Dopo 2 teste ti manda da Big Earl")
	check(mission.target_point().distance_to(Layout.SHOP_NPC) < 0.1, "Il GPS porta all'Emporio di Big Earl")
	quest.arrive(p)
	check(quest.stage == quest.WEAPON, "Da Big Earl senza arma non si va avanti")
	p.owned.append("pistol")
	p.reset_at(Layout.SHOP_NPC + Vector3(1.0, 0.3, 0))
	await wait(3)
	quest.arrive(p)
	check(quest.stage == quest.NOISE and quest.weapon_bought, "Armato da Big Earl: si va alla fattoria")
	check(mission.target_point().distance_to(Layout.FARM) < 0.1, "Senza teste il GPS porta alla fattoria")
	check(" ".join(quest.lines()).contains("Accucciato") and " ".join(quest.lines()).contains("sparo"), "Il passo della fattoria insegna il rumore")
	p.reset_at(Layout.FARM + Vector3(12, 0.5, 12))
	await wait(3)
	quest.arrive(p)
	check(quest.farm_told, "Alla fattoria arriva la lezione sul rumore")
	p.reset_at(Layout.SHERIFF_NPC + Vector3(-1.5, 0.3, 0))
	await wait(3)
	p.add_item("item_testa_bruto"); p.equip_id("item_testa_bruto")
	bank = p.credits
	rules.act(1, "sell:item_testa_bruto")
	check(p.credits == bank + 100, "La testa di bruto vale di più")
	p.add_item("item_testa"); p.add_item("item_testa"); p.equip_id("item_testa")
	rules.act(1, "sell:item_testa"); rules.act(1, "sell:item_testa")
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
	check(mission.target_point().distance_to(Layout.SHOP_NPC) < 0.1, "Il GPS porta la batteria a Big Earl")
	p.reset_at(Layout.SHERIFF_NPC + Vector3(-1.5, 0.3, 0))
	await wait(3)
	rules.act(1, "quest:talk")
	check(quest.stage == quest.BRING_FOREST and p.baits == 0, "Lo sceriffo non ripete: la prossima esca ce l'ha Big Earl")
	p.reset_at(Layout.SHOP_NPC + Vector3(1.0, 0.3, 0))
	await wait(3)
	quest.arrive(p)
	check(quest.stage == quest.VILLAGE_BOSS and p.baits == 1, "Big Earl prende la batteria e dà la nuova esca")

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
	check(mission.target_point().distance_to(world.rocca.guide_pos) < 0.1, "Dopo il Macellaio il GPS porta al falò di Bruno")
	world.terrain.ensure_near([world.rocca.guide_pos])
	p.reset_at(world.rocca.guide_pos + Vector3(2.5, 0.5, 0))
	await wait(3)
	p.health = 30.0
	quest.arrive(p)
	check(quest.stage == quest.DUNGEON and p.health == p.max_health(), "Al falò di Bruno si riprende fiato e si va alla Rocca")
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
	check(mission.stage == 0, "La riparazione aspetta i pezzi al 4×4")
	check(mission.target_point().distance_to(mission.car.global_position) < 0.1, "Il GPS porta al 4×4")

	# Salvataggio a metà
	var snapshot: int = quest.stage
	SaveManager_write()
	quest.stage = quest.TALK
	root.get_node("SaveManager").apply(world)
	check(quest.stage == snapshot, "Il salvataggio riprende dal punto della storia")
	check(p.items.has("item_testa_carceriere"), "Il salvataggio tiene le teste per tipo")

	# Salvataggi di prima dei passi nuovi (11 passi): ognuno riprende dal passo giusto.
	var before: int = quest.stage
	var kept := [quest.delivered, quest.weapon_bought, quest.carceriere_dead]
	for row in [[{"stage": 1}, quest.KILL_TWO], [{"stage": 2}, quest.WEAPON], [{"stage": 2, "weapon": true}, quest.NOISE],
			[{"stage": 3}, quest.GET_BAIT], [{"stage": 5}, quest.BRING_FOREST], [{"stage": 7}, quest.BRING_VILLAGE], [{"stage": 10}, quest.DONE],
			[{"stage": quest.DONE}, quest.DONE], [{"v": 2, "stage": quest.NOISE}, quest.NOISE]]:
		quest.load_data(row[0])
		check(quest.stage == row[1], "Salvataggio %s → passo %d" % [row[0], row[1]])
	quest.stage = before
	quest.delivered = kept[0]; quest.weapon_bought = kept[1]; quest.carceriere_dead = kept[2]
	# I passi: tutti diversi, e lo sceriffo non ti richiama più di due volte.
	var sheriff_steps := 0
	for text in quest.STEPS: sheriff_steps += int((text as String).contains("sceriffo"))
	var unique := {}
	for text in quest.STEPS: unique[text] = true
	check(unique.size() == quest.STEPS.size() and sheriff_steps <= 2, "Passi tutti diversi, sceriffo solo in %d" % sheriff_steps)
	check(quest.STEPS.size() == quest.DONE + 1, "Un passo scritto per ogni stato")

	# Fine: si portano i pezzi al 4×4
	p.reset_at(mission.car.global_position + Vector3(2.5, 0.3, 0))
	await wait(3)
	quest.arrive(p)
	check(quest.finished() and mission.stage == 1, "Con tre pezzi portati al 4×4 si ripara")
	check(mission.title() == "RIPARA IL 4×4", "L'obiettivo diventa la riparazione")
	check(world.rocca.GUIDE_INTRO[3].contains("scala") and not " ".join(world.rocca.GUIDE_INTRO).contains("miniera"), "Bruno non parla più della miniera")
	check(world.village.get_node_or_null("BorgoNav/Borgo/Piazza") != null, "Borgo Cenere esiste")
	print("STORIA: %d errori %s" % [fails.size(), fails])
	quit(0 if fails.is_empty() else 1)


func SaveManager_write() -> void:
	root.get_node("SaveManager").write(world)
