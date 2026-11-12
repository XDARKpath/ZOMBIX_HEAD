extends SceneTree
# Vendita teste online, due processi veri e host lento (5 fps = ~200 ms di ritardo): il client vede "+25" solo dopo il sì dell'host.
# godot --path . --headless -s res://tests/head_sale_coop.gd -- --sale-host
# godot --path . --headless -s res://tests/head_sale_coop.gd -- --sale-client
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
const PORT := 27861
var world: Node3D
var pops := 0


func _initialize() -> void:
	call_deferred("run")


func wait_for(cond: Callable, seconds := 20.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end and not cond.call():
		await process_frame
	return cond.call()


func run() -> void:
	var session: Node = root.get_node("Session")
	var hosting: bool = "--sale-host" in OS.get_cmdline_user_args()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	# Il controllo legge "+25 CREDITI" in italiano: lingua cambiata solo in memoria.
	root.get_node("Localization").current = "it"
	var rules: Node3D = world.survival
	var good := true
	if hosting:
		session.host(PORT)
		paused = false
		if not await wait_for(func(): return session.roster.size() == 2 and session.roster.values().all(func(m): return m.ready), 60.0):
			print("SALE_HOST lobby incompleta")
			quit(1)
			return
		session.launch()
	else:
		session.profile("SALE", 0)
		session.join("127.0.0.1", PORT)
		paused = false
		await create_timer(2.0, true).timeout
		session.set_ready(true)
		await session.game_started
	await create_timer(1.5, true).timeout
	world.spawner.set_process(false)
	for e in world.targets: e.set_physics_process(false)
	if hosting:
		var guest: CharacterBody3D
		for id in world.actors:
			if world.actors[id] != world.player: guest = world.actors[id]
		# La posizione del client la decide l'host: lo si porta davanti allo sceriffo.
		var at: Vector3 = Layout.SHERIFF_NPC + Vector3(-1.6, 0, 0)
		guest.global_position = Vector3(at.x, Layout.SHERIFF_NPC.y, at.z)
		guest.velocity = Vector3.ZERO
		guest.set_item_count("item_testa", 3)
		rules._publish()
		Engine.max_fps = 5
		# Finché il client è collegato: teste tolte e crediti dati, letti sullo stato dell'host.
		var sold := 0
		var credits := 0
		var end := Time.get_ticks_msec() + 25000
		while Time.get_ticks_msec() < end and is_instance_valid(guest):
			sold = 3 - int(guest.items.get("item_testa", 0))
			credits = guest.credits
			await process_frame
		Engine.max_fps = 0
		good = sold >= 1 and credits == sold * 25
		var guest_credits := credits
		print("SALE_HOST teste vendute %d · crediti %d · invariante %s" % [sold, guest_credits, good])
	else:
		var p: CharacterBody3D = world.player
		world.get_node("Interface").child_entered_tree.connect(func(n):
			if n is Label and n.text.begins_with("+") and n.text.contains("CREDITI"): pops += 1)
		good = await wait_for(func(): return int(p.items.get("item_testa", 0)) == 3)
		var at: Vector3 = Layout.SHERIFF_NPC + Vector3(-1.6, 0, 0)
		p.set_physics_process(false)
		p.global_position = Vector3(at.x, Layout.SHERIFF_NPC.y, at.z)
		await create_timer(1.0, true).timeout
		rules.request("slot:%d" % p.hotbar.find("item_testa"))
		good = await wait_for(func(): return p.equipped == "item_testa") and good
		await create_timer(0.8, true).timeout
		# Gesto locale + pressioni ripetute ogni frame finché l'host non risponde.
		rules.press_sell()
		good = await wait_for(func(): return int(rules.sell_wait) > 0, 3.0) and good
		var sent := Time.get_ticks_msec()
		var early_pops := pops
		var early_credits: int = p.credits
		var presses := 0
		while int(rules.sell_wait) > 0 and Time.get_ticks_msec() - sent < 5000:
			rules.press_sell()
			presses += 1
			await process_frame
		var rtt := Time.get_ticks_msec() - sent
		await create_timer(0.5, true).timeout
		var paid_after: bool = early_pops == 0 and early_credits == 0
		var one: bool = pops == 1 and p.credits == 25 and int(p.items.get("item_testa", 0)) == 2
		print("SALE_CLIENT attesa host %d ms · %d pressioni in attesa · pagamento prima del sì: %s · dopo: pop %d crediti %d teste %d" % [rtt, presses, not paid_after, pops, p.credits, int(p.items.get("item_testa", 0))])
		good = good and paid_after and one and rtt > 20
		# Rifiuto dall'host: richiesta per una testa che non hai in mano.
		await create_timer(1.0, true).timeout
		rules.sell_wait = 777
		rules.request("sell:item_testa_bruto:777")
		var cleared: bool = await wait_for(func(): return int(rules.sell_wait) == 0, 5.0)
		await create_timer(0.3, true).timeout
		print("SALE_CLIENT rifiuto dell'host: attesa chiusa %s · pop %d · crediti %d" % [cleared, pops, p.credits])
		good = good and cleared and pops == 1 and p.credits == 25
		await create_timer(2.0, true).timeout
	print("%s valido %s" % ["SALE_HOST" if hosting else "SALE_CLIENT", good])
	await create_timer(3.0 if hosting else 0.5, true).timeout
	session.leave()
	world.queue_free()
	await process_frame
	quit(0 if good else 1)
