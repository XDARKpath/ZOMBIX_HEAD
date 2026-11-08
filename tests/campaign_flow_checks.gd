extends SceneTree
# Il viaggio dopo la Zona 1, passo per passo: riparazione, sbarramenti, Porto Secco, boss di Mira, valichi, presidi, ultima tappa.
# A ogni passo legge anche titolo, dettaglio, GPS e scritta a schermo: un errore lì blocca la partita.
# godot --path . -s res://tests/campaign_flow_checks.gd
const Route := preload("res://world/campaign/route.gd")
const Terrain := preload("res://world/campaign/terrain.gd")
var world: Node3D
var mission: Node3D
var car: CharacterBody3D
var p: CharacterBody3D
var fails: Array = []


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


func wait(frames: int) -> void:
	for i in frames: await physics_frame


func screens(where: String) -> void:
	# Le stesse chiamate che fanno HUD e GPS a ogni frame.
	var text := "%s | %s | %s | %s" % [mission.title(), mission.detail(), mission.target_point(), mission.prompt()]
	check(text.length() > 10, "%s: HUD e GPS rispondono (%s)" % [where, text.replace("\n", " ")])


func _run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	world.spawner.set_process(false)
	mission = world.expedition
	car = mission.car
	p = world.player
	p.health = 100000.0
	mission.set_process(false)
	car.set_physics_process(false)
	var quest: Node3D = world.quest

	# Fine della Zona 1: tre pezzi, lo sceriffo, la riparazione.
	for i in 3: quest.on_boss(i)
	quest.stage = quest.BRING_DUNGEON
	quest.talk(p)
	check(quest.finished() and mission.stage == 1, "Con tre pezzi si passa alla riparazione")
	screens("Riparazione")
	p.reset_at(car.global_position + Vector3(2.0, 0.3, 0))
	await wait(3)
	check(mission.use(1) and mission.repairing_peer == 1, "Si ripara accanto al 4×4")
	mission._process(8.1)
	check(car.repaired and mission.stage == 2 and mission.unlocked == 1, "Il 4×4 è riparato e la prima tappa si sblocca")
	world.zone_gates.refresh()
	check(world.zone_gates.is_open(0) and not world.zone_gates.is_open(1), "Valico nord aperto, valico est ancora chiuso")
	screens("Viaggio verso la tappa 1")

	# Sbarramenti e arrivo a Porto Secco.
	check(car.interact(1) and car.seat_of(1) == 0, "Si sale alla guida")
	await drive_to(1)
	check(not mission.try_arrive(), "Con gli sbarramenti chiusi non si arriva")
	world.roadblocks.cleared = [true, true]
	world.roadblocks.refresh()
	check(mission.try_arrive() and mission.zone_index == 1 and mission.stage == 3, "Arrivo a Porto Secco")
	screens("Presidio di Porto Secco")
	await free_post(1)
	check(mission.stage == 2 and mission.unlocked == 2, "Presidio liberato: si sblocca la tappa 2")

	# Zona 2: Mira e i due boss.
	var z2: Node3D = world.zone2
	check(z2.active(), "La Zona 2 comincia dopo il presidio")
	screens("Zona 2, da Mira")
	z2.talked()
	check(z2.stage == z2.HUNT, "Mira manda a caccia")
	screens("Zona 2, caccia")
	z2._on_boss("matriarca")
	screens("Zona 2, manca il Signore")
	z2._on_boss("signore")
	check(z2.stage == z2.REPORT, "Morti tutti e due: si torna da Mira")
	var money: int = p.credits
	z2.talked()
	check(z2.stage == z2.DONE and p.credits == money + 800, "Mira paga e chiude la Zona 2")
	world.zone_gates.refresh()
	check(world.zone_gates.is_open(1), "Valico est aperto")
	screens("Dopo Mira")

	# Le tappe seguenti fino all'ultima.
	for zone in range(2, Route.POINTS.size()):
		check(mission.stage == 2 and mission.unlocked == zone, "Tappa %d sbloccata" % zone)
		if car.seat_of(1) < 0:
			p.reset_at(car.global_position + Vector3(2.0, 0.3, 0))
			await wait(2)
			check(car.interact(1), "Si risale sul 4×4 (tappa %d)" % zone)
		await drive_to(zone)
		check(mission.try_arrive() and mission.zone_index == zone and mission.stage == 3, "Arrivo alla tappa %d · %s" % [zone, Route.TITLES[zone]])
		screens("Presidio %d" % zone)
		await free_post(zone)
	check(mission.stage == 4, "Ultima tappa: rotta completata")
	screens("Fine")

	# Salvataggio e ripresa in fondo al viaggio.
	root.get_node("SaveManager").write(world)
	mission.stage = 0
	root.get_node("SaveManager").apply(world)
	check(mission.stage == 4 and car.repaired and world.zone2.stage == world.zone2.DONE, "Il salvataggio riprende a fine viaggio")
	print("VIAGGIO: %d errori %s" % [fails.size(), fails])
	quit(0 if fails.is_empty() else 1)


## Porta il 4×4 (con la squadra a bordo) fermo accanto alla tappa.
func drive_to(zone: int) -> void:
	var at: Vector3 = Route.nearest_road(Route.POINTS[zone] + Vector3(6, 0, 6))
	world.terrain.ensure_near([at])
	car.global_position = Vector3(at.x, Terrain.ground_height(at.x, at.z) + 0.3, at.z)
	car.speed = 0.0
	car._place_occupants()
	await wait(3)


## Scende, elimina i difensori, scarica la coordinata al ripetitore.
func free_post(zone: int) -> void:
	check(car.interact(1) and car.seat_of(1) < 0, "Si scende dal 4×4 alla tappa %d" % zone)
	await wait(4)
	var count := 0
	for e in world.targets:
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(Route.POINTS[zone]) < 65.0:
			e.receive_hit("head", 100000.0, Vector3.ZERO, "axe", true)
			count += 1
	await wait(10)
	check(mission.remaining_enemies() == 0, "Tappa %d: difensori eliminati (%d)" % [zone, count])
	var beacon: Vector3 = mission.beacons[zone].global_position
	world.terrain.ensure_near([beacon])
	var spot := Vector3.ZERO
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var at := beacon + Vector3(cos(angle), 0, sin(angle)) * 1.8
		p.reset_at(Vector3(at.x, Terrain.ground_height(at.x, at.z) + 0.4, at.z))
		await wait(3)
		if mission.can_reach(p, beacon):
			spot = at
			break
	check(spot != Vector3.ZERO, "Tappa %d: il ripetitore si raggiunge" % zone)
	check(mission.use(1) and mission.downloading, "Tappa %d: download avviato" % zone)
	mission._process(10.1)
