extends SceneTree
# Online con due processi veri: parata direzionale e premi in riserva decisi dall'host, visti dal client.
#   godot --path . --headless -s res://tests/parry_reward_network.gd -- --net-host
#   godot --path . --headless -s res://tests/parry_reward_network.gd
const PORT := 27857
var world: Node3D
var fails := 0


func _initialize() -> void:
	call_deferred("run")


func wait_for(test: Callable, seconds: float = 8.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not test.call() and Time.get_ticks_msec() < end:
		await create_timer(0.1, true).timeout
	return test.call()


func check(good: bool, what: String) -> void:
	print("PASS " if good else "FAIL ", what)
	if not good: fails += 1


func run() -> void:
	var session: Node = root.get_node("Session")
	var hosting: bool = "--net-host" in OS.get_cmdline_user_args()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	root.get_node("Localization").current = "it"
	TranslationServer.set_locale("it")
	world.automated = true
	if hosting: await _host(session)
	else: await _client(session)
	print("RETE ", "host" if hosting else "client", ": ", fails, " errori")
	session.leave()
	world.queue_free()
	await process_frame
	await process_frame
	quit(1 if fails > 0 else 0)


func _host(session: Node) -> void:
	session.host(PORT)
	paused = false
	check(await wait_for(func(): return session.roster.size() == 2 and session.roster.values().all(func(m): return m.ready), 30.0), "Il secondo giocatore entra")
	session.launch()
	await create_timer(2.0, true).timeout
	world.spawner.set_process(false)
	for e in world.targets: e.set_physics_process(false)
	var other: CharacterBody3D
	for id in world.actors:
		if id != 1: other = world.actors[id]
	check(await wait_for(func(): return other.melee.blocking and absf(other.rig.yaw) < 0.05, 15.0), "Parata e sguardo del client arrivano all'host (yaw %.2f)" % other.rig.yaw)
	other.health = 100.0; other.stamina = other.max_stamina()
	world.hit_player(other, 20.0, {"bleed": 6.0}, other.global_position + Vector3(0, 0, -2))
	check(is_equal_approx(other.health, 95.0) and float(other.status.left.bleed) == 0.0, "Davanti: l'host para (%.1f)" % (100.0 - other.health))
	await create_timer(1.0, true).timeout
	other.health = 100.0; other.stamina = other.max_stamina()
	world.hit_player(other, 20.0, {"bleed": 6.0}, other.global_position + Vector3(0, 0, 2))
	check(is_equal_approx(other.health, 80.0) and float(other.status.left.bleed) > 0.0, "Da dietro: passa intero e sanguina (%.1f)" % (100.0 - other.health))
	other.status.clear_all()
	await create_timer(1.0, true).timeout
	# Premio con le tasche piene del client: lo decide l'host.
	other.owned.assign(["axe", "machete", "crowbar"])
	other.hotbar.assign(["axe", "machete", "crowbar", "", "", "", "", "", ""])
	other.items = {}
	other.add_item("item_bende", 1)
	other.select_slot(0)
	other.add_item("item_testa_bruto", 2)
	world.survival._publish()
	check(int(other.reserve.get("item_testa_bruto", 0)) == 2, "Host: premio del client in riserva")
	await create_timer(3.0, true).timeout
	other.remove_one("item_bende")
	world.survival._publish()
	check(other.reserve.is_empty() and int(other.items.get("item_testa_bruto", 0)) == 2, "Host: tasca liberata, la riserva entra")
	await create_timer(5.0, true).timeout


func _client(session: Node) -> void:
	session.profile("Net%d" % OS.get_process_id(), 1)
	session.join("127.0.0.1", PORT)
	paused = false
	check(await wait_for(func(): return session.roster.size() == 2, 20.0), "Collegato all'host")
	session.set_ready(true)
	check(await wait_for(func(): return world.started, 30.0), "La partita parte")
	var results: Array = []
	world.player.guard_result.connect(func(r): results.append(r))
	await create_timer(1.0, true).timeout
	world.player.rig.yaw = 0.0
	world.player.melee.block_forced = true
	check(await wait_for(func(): return results.has(world.player.GUARD_BLOCKED), 20.0), "Client: arriva l'esito della parata (segnale HUD)")
	check(await wait_for(func(): return world.player.reserve.get("item_testa_bruto", 0) == 2, 15.0), "Client: vede il premio in riserva")
	check(await wait_for(func(): return world.notice.text.contains("IN RISERVA") or world.tips.any(func(t): return String(t[0]).contains("IN RISERVA")), 5.0), "Client: avviso quantità e riserva")
	check(await wait_for(func(): return world.player.reserve.is_empty() and world.player.hotbar.has("item_testa_bruto"), 15.0), "Client: il premio entra in una tasca")
	check(await wait_for(func(): return world.notice.text.contains("NELLA TASCA") or world.tips.any(func(t): return String(t[0]).contains("NELLA TASCA")), 5.0), "Client: avviso della tasca")
	world.player.melee.block_forced = false
	await create_timer(2.0, true).timeout
