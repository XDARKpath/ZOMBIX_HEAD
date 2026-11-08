extends SceneTree
# Online vero, due istanze: ciò che fa un giocatore si vede dall'altro; gli effetti li decide l'host.
#   godot --path . --headless -s res://tests/online_feel.gd -- --feel-host
#   godot --path . --headless -s res://tests/online_feel.gd
const PORT := 27851
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
	var hosting: bool = "--feel-host" in OS.get_cmdline_user_args()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	if hosting: await _host(session)
	else: await _client(session)
	print("FEEL ", "host" if hosting else "client", ": ", fails, " errori")
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
	var me: CharacterBody3D = world.player
	var other: CharacterBody3D
	for id in world.actors:
		if id != 1: other = world.actors[id]
	me.owned.assign(["axe"])
	me.equip_id("axe")
	await create_timer(0.8, true).timeout
	me.melee.block_forced = true
	await create_timer(1.5, true).timeout
	me.melee.block_forced = false
	check(await wait_for(func(): return other.melee.blocking, 10.0), "La parata del secondo giocatore arriva all'host")
	var whole: float = other.health
	world.hit_player(other, 10.0, {"poison": 12.0}, other.global_position + Vector3(0, 1, -1))
	check(other.health > whole - 10.0, "La parata online riduce il danno (%.1f -> %.1f)" % [whole, other.health])
	check(other.status.left["poison"] <= 0.0, "La parata tiene lontano il veleno")
	other.status.clear_all()
	await create_timer(3.5, true).timeout
	world.survival.gesture(me, "wave")
	await create_timer(1.0, true).timeout
	check(world.hit_player(other, 10.0, {"poison": 12.0, "slow": 1.0, "knock": Vector3(0, 0, 3), "shake": 0.3}, other.global_position + Vector3(0, 1, -1)), "L'host colpisce il secondo giocatore")
	check(other.status.left["poison"] > 0.0, "Sull'host il secondo giocatore è avvelenato")
	var z: Node3D = world.targets[0]
	z.set_physics_process(false)
	z.global_position = me.global_position + Vector3(2, 0, 0)
	await create_timer(0.6, true).timeout
	z.receive_hit("torso", 99999.0, Vector3(0, 0, 1), "axe", true)
	await create_timer(1.5, true).timeout
	z.receive_hit("head", 20.0, Vector3.ZERO, "axe", false)
	check(z.beheaded, "Il cadavere perde la testa sull'host")
	await create_timer(6.0, true).timeout


func _client(session: Node) -> void:
	session.profile("Feel%d" % OS.get_process_id(), 1)
	session.join("127.0.0.1", PORT)
	paused = false
	check(await wait_for(func(): return session.roster.size() == 2, 20.0), "Collegato all'host")
	session.set_ready(true)
	check(await wait_for(func(): return world.started, 30.0), "La partita parte")
	check(await wait_for(func(): return is_instance_valid(world.actors.get(1)), 10.0), "Si vede l'host")
	var host_seen: CharacterBody3D = world.actors[1]
	check(await wait_for(func(): return host_seen.equipped == "axe", 10.0), "L'host ha l'ascia in mano")
	check(await wait_for(func(): return host_seen.melee.blocking, 8.0), "L'host è visto parare")
	world.player.melee.block_forced = true
	await create_timer(3.0, true).timeout
	world.player.melee.block_forced = false
	check(await wait_for(func(): return str(host_seen.get_meta("gesture_what", "")) == "wave", 8.0), "L'host è visto salutare")
	check(await wait_for(func(): return world.player.status.left["poison"] > 0.0, 8.0), "Il veleno arriva a chi è stato colpito")
	check(world.player.health < world.player.max_health if "max_health" in world.player else true, "Il danno arriva a chi è stato colpito")
	var zombie: Array = [null]
	check(await wait_for(func():
		for t in world.targets:
			if is_instance_valid(t) and t.dead:
				zombie[0] = t
				return true
		return false, 10.0), "Si vede l'infetto morto")
	check(await wait_for(func(): return is_instance_valid(zombie[0]) and zombie[0].beheaded, 8.0), "Si vede il cadavere senza testa")
