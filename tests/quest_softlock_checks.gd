extends SceneTree
# La storia non si blocca mai: boss abbandonati, boss caduti, esche dopo un caricamento.
# godot --path . -s res://tests/quest_softlock_checks.gd
const VL := preload("res://world/villaggio/villaggio_layout.gd")
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
var world: Node3D
var fails: Array = []


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


func wait(frames: int) -> void:
	for i in frames: await physics_frame


func _run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	world.spawner.set_process(false)
	var p: CharacterBody3D = world.player
	var quest: Node3D = world.quest
	var hunt: Node3D = world.boss_hunt
	p.health = 100000.0

	# Capomacello: tutti scappano, il boss torna a dormire e l'esca torna in tasca.
	quest.stage = quest.FOREST_BOSS
	p.baits = 1
	var altar: Node3D = hunt.esche[0]
	p.reset_at(altar.global_position + Vector3(1, 0.5, 0))
	await wait(4)
	check(hunt.try_summon(p) and p.baits == 0 and hunt.used[0], "L'esca evoca il Capomacello")
	var capo: Node3D = hunt.bosses[hunt.bosses.size() - 1]
	p.reset_at(Layout.SHERIFF_NPC + Vector3(-1.5, 0.3, 0))
	hunt._away = 21.0
	await wait(90)
	check(not is_instance_valid(capo) and not hunt.used[0] and p.baits == 1, "Scappati tutti: il Capomacello torna a dormire e l'esca torna")
	p.reset_at(altar.global_position + Vector3(1, 0.5, 0))
	await wait(4)
	check(hunt.context(p).begins_with("E  "), "L'altare si può riaccendere (%s)" % hunt.context(p))
	check(hunt.try_summon(p) and p.baits == 0, "Si riaccende")
	capo = hunt.bosses[hunt.bosses.size() - 1]
	capo.global_position.y -= 60.0
	await wait(3)
	check(not is_instance_valid(capo) and not hunt.used[0] and p.baits == 1, "Boss caduto fuori dal terreno: si riparte, niente blocco")
	quest.stage = quest.FOREST_BOSS
	quest.talk(p)
	check(p.baits == 1, "Con l'esca in tasca lo sceriffo non ne regala un'altra")

	# Borgo: lo scontro abbandonato restituisce l'esca a chi l'ha gettata.
	quest.stage = quest.VILLAGE_BOSS
	var village: Node3D = world.village
	village.set_process(true)
	p.reset_at(VL.CENTER + Vector3(3.5, 0.5, 3.5))
	await wait(4)
	check(village.request_use(p) and p.baits == 0 and village.arena == "active", "L'esca sveglia il Macellaio")
	SaveManager_write()
	p.reset_at(VL.CENTER + Vector3(300, 0.5, 0))
	village.empty_time = 19.9
	await wait(30)
	check(village.arena == "idle" and p.baits == 1, "Scontro abbandonato: l'esca torna a chi l'ha gettata")
	# Salvato a metà scontro: al caricamento l'esca c'è.
	p.baits = 0
	root.get_node("SaveManager").apply(world)
	check(quest.stage == quest.VILLAGE_BOSS and p.baits == 1, "Salvato durante lo scontro del borgo: al caricamento l'esca c'è")

	# Premi dei boss: a tutti i giocatori.
	var before: int = p.credits
	hunt._on_defeated(null, 0)
	check(p.credits == before + 150, "Il Capomacello paga")
	print("BLOCCHI: %d errori %s" % [fails.size(), fails])
	quit(0 if fails.is_empty() else 1)


func SaveManager_write() -> void:
	root.get_node("SaveManager").write(world)
