extends SceneTree
# Armi da fuoco online, due processi veri: i colpi del client li decide l'host.
# Automatica tenuta, grilletto a vuoto (ricarica sull'host, nessuno resta in carica), pistola a stamina 0, pompa interrotta.
#   godot --path . --headless -s res://tests/gun_net_checks.gd -- --gun-host
#   godot --path . --headless -s res://tests/gun_net_checks.gd
const PORT := 27869
var world: Node3D
var fails := 0


func _initialize() -> void:
	call_deferred("run")


func wait_for(test: Callable, seconds: float = 8.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not test.call() and Time.get_ticks_msec() < end:
		await physics_frame
	return test.call()


func check(good: bool, what: String) -> void:
	print("PASS " if good else "FAIL ", what)
	if not good: fails += 1


func run() -> void:
	var session: Node = root.get_node("Session")
	var hosting: bool = "--gun-host" in OS.get_cmdline_user_args()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	if hosting: await _host(session)
	else: await _client(session)
	print("GUN_NET ", "host" if hosting else "client", ": ", fails, " errori")
	session.leave()
	world.queue_free()
	await process_frame
	await process_frame
	quit(1 if fails > 0 else 0)


func _host(session: Node) -> void:
	session.host(PORT)
	paused = false
	check(await wait_for(func(): return session.roster.size() == 2 and session.roster.values().all(func(m): return m.ready), 60.0), "Il secondo giocatore entra")
	session.launch()
	await create_timer(2.0, true).timeout
	world.spawner.set_process(false)
	var other: CharacterBody3D
	for id in world.actors:
		if id != 1: other = world.actors[id]
	other.owned.assign(["axe", "pistol", "assault_rifle", "pump_shotgun"])
	other.hotbar.assign(["assault_rifle", "pistol", "pump_shotgun", "axe", "", "", "", "", ""])
	other.select_slot(0)
	# D4: automatica tenuta dal client.
	var full: int = other.magazine
	check(await wait_for(func(): return other.magazine <= full - 3, 20.0), "Automatica del client: l'host spara davvero")
	await create_timer(2.5, true).timeout
	print("colpi automatici sparati dall'host: ", full - other.magazine)
	# D3: grilletto a vuoto del client.
	other.select_slot(1)
	other.magazine = 0
	check(await wait_for(func(): return other.reload_left > 0.0, 20.0), "Grilletto a vuoto del client: la ricarica parte sull'host")
	await create_timer(0.4, true).timeout
	check(not other.melee.charging, "Dopo il grilletto a vuoto l'host non resta in carica")
	check(await wait_for(func(): return other.magazine == 8 and other.reload_left <= 0.0, 6.0), "La ricarica dell'host riempie la pistola (%d)" % other.magazine)
	# D6 in rete: pistola a stamina 0.
	var loaded: bool = other.magazine == 8
	var shot := false
	var end := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < end and not shot:
		other.stamina = 0.0
		await physics_frame
		shot = other.magazine < 8
	check(loaded and shot, "Pistola del client a stamina 0: l'host spara (%d)" % other.magazine)
	await create_timer(1.0, true).timeout
	# D1: pompa in ricarica interrotta dal grilletto del client.
	other.select_slot(2)
	other.magazine = 2
	other.reload_weapon()
	check(await wait_for(func(): return other.reload_left <= 0.0, 20.0) and other.magazine < 6, "Pompa del client: il grilletto interrompe la ricarica sull'host (%d/6)" % other.magazine)
	await create_timer(0.4, true).timeout
	check(not other.melee.charging, "Dopo la pompa interrotta l'host non resta in carica")
	await create_timer(3.0, true).timeout


## Clic vero sul client, ripetuto finché la condizione (vista dallo snapshot dell'host) non cambia.
func _click_until(done: Callable, tries: int = 6) -> bool:
	for i in tries:
		Input.action_press("attack")
		for f in 3: await physics_frame
		Input.action_release("attack")
		if await wait_for(done, 1.0): return true
	return false


func _client(session: Node) -> void:
	session.profile("Gun%d" % OS.get_process_id(), 1)
	session.join("127.0.0.1", PORT)
	paused = false
	check(await wait_for(func(): return session.roster.size() == 2, 30.0), "Collegato all'host")
	session.set_ready(true)
	check(await wait_for(func(): return world.started, 60.0), "La partita parte")
	var me: CharacterBody3D = world.player
	check(await wait_for(func(): return me.equipped == "assault_rifle" and me.magazine > 20, 20.0), "In mano l'automatica data dall'host")
	var shots: Array = [0]
	var count := func(_h: bool) -> void: shots[0] += 1
	me.melee.attack_started.connect(count)
	Input.action_press("attack")
	await create_timer(1.5, true).timeout
	Input.action_release("attack")
	me.melee.attack_started.disconnect(count)
	print("colpi automatici partiti dal client: ", shots[0])
	check(await wait_for(func(): return me.equipped == "pistol" and me.magazine == 0 and me.reload_left <= 0.0, 20.0), "Pistola scarica")
	check(await _click_until(func(): return me.reload_left > 0.0), "Il grilletto a vuoto fa partire la ricarica")
	check(await wait_for(func(): return me.magazine == 8 and me.stamina < 5.0, 20.0), "Pistola carica, stamina a zero")
	check(await _click_until(func(): return me.magazine < 8), "La pistola spara a stamina 0")
	check(await wait_for(func(): return me.equipped == "pump_shotgun" and me.reload_left > 0.0, 20.0), "Pompa in ricarica")
	check(await _click_until(func(): return me.reload_left <= 0.0 and me.magazine < 6, 3), "Il grilletto interrompe la pompa")
	await create_timer(5.0, true).timeout
