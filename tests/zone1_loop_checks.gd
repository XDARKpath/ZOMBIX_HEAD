extends SceneTree
# Verifiche del primo traguardo della Zona 1: rumore, sacco della morte, cibo, pesca, erba.
var world: Node3D
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run():
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	# I controlli leggono i testi italiani: la lingua si cambia solo in memoria, senza salvare la scelta del giocatore.
	root.get_node("Localization").current = "it"
	TranslationServer.set_locale("it")
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.5).timeout
	var life = world.zone_life
	var p = world.player
	p.set_physics_process(false)
	check(life != null, "Sistema della Zona 1 attivo")
	check(world.landscape.find_child("GrassField", true, false) != null or world.presentation.find_child("GrassField", true, false) != null, "Erba GPU presente")
	# Rumore: il coltello si sente a 5 m, la pistola a 45 m. Fuori dal recinto: dentro gli infetti non ti inseguono.
	p.global_position = Vector3(6, 0.5, -70)
	var zombie = world._spawn_enemy(p.position + Vector3(0, 0, -20))
	await create_timer(0.1).timeout
	zombie.state = zombie.State.WANDER
	p.equipped = "knife"
	life.attack_noise(p)
	check(zombie.state == zombie.State.WANDER, "Coltello: zombie a 20 m non sente")
	p.equipped = "pistol"
	life.attack_noise(p)
	check(zombie.state == zombie.State.CHASE, "Pistola: zombie a 20 m sente e insegue")
	check(life.noise_level > 0.9, "Indicatore del rumore al massimo dopo lo sparo")
	# Sacco della morte.
	p.carried_heads = 5
	life.drop_sack(p)
	check(p.carried_heads == 2 and life.sacks.size() == 1 and life.sacks[0]["heads"] == 3, "Morte: metà delle teste (arrotondata) resta nel sacco")
	check(life.context().begins_with("E  RECUPERA IL SACCO"), "Il sacco si può recuperare")
	check(life.request() and p.carried_heads == 5 and life.sacks.is_empty(), "Sacco recuperato: teste restituite")
	p.carried_heads = 2
	life.drop_sack(p)
	zombie.global_position = life.sacks[0]["node"].global_position + Vector3(0.5, 0, 0)
	for i in 10: life._sacks(1.0)
	check(life.sacks.is_empty(), "Uno zombie sul sacco lo divora in 8 secondi")
	# Cibo.
	var item = life.pickups[0]
	p.global_position = item["node"].global_position
	var kind: String = item["kind"]
	check(life.request() and life.food[kind] == 1, "Raccolta del cibo")
	p.health = 50
	life.eat()
	check(p.health > 50 and life.food_count() == 0, "Mangiare cura")
	# Pesca.
	p.global_position = life.FISHING_SPOT + Vector3(0, 0.2, 0)
	check(life.context() == "E  PESCA", "Al pontile si può pescare")
	life.request()
	life.fishing_timer = 0.0
	life._fishing(0.01)
	check(life.fishing == "bite", "Il pesce abbocca")
	life.request()
	check(life.food["fish"] == 1, "Pesce preso premendo E in tempo")
	# Kit ambiente: cassa distruttibile e cassa militare.
	var kit = world.zone_kit
	check(kit != null and kit.crates.size() >= 8 and kit.chests.size() >= 4, "Casse e bauli del kit ambiente nella zona")
	var before: int = life.pickups.size()
	var crate: Node3D = kit.crates[0]
	var adapter = crate.get_child(crate.get_child_count() - 1)
	for body in crate.find_children("*", "StaticBody3D", true, false):
		if body.has_meta("target"): adapter = body.get_meta("target")
	adapter.receive_hit("torso", 60.0, Vector3.FORWARD, "axe", true)
	await create_timer(0.1).timeout
	check(life.pickups.size() == before + 1, "Una cassa rotta con l'ascia lascia una scatoletta")
	var chest: Dictionary = kit.chests[kit.chests.size() - 1]
	p.global_position = chest["node"].global_position + Vector3(0.8, 0.2, 0)
	var credits: int = p.credits
	check(kit.chest_context(p).begins_with("E  APRI") and kit.open_chest(p) and p.credits == credits + 30, "La cassa militare si apre e dà crediti e cibo")
	var counter := false
	for child in world.landscape.get_node("RefugeBuildings/Armory").get_children():
		if child.scene_file_path.ends_with("SM_Shop_SalesCounter.glb"): counter = true
	check(counter, "Armeria arredata con il bancone del kit")
	print("ZONE1 LOOP %s (%d errori)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit()
