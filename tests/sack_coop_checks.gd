extends SceneTree
# Sacco della morte in cooperativa, due processi veri collegati in rete locale.
# Il client muore con 4 teste: l'host crea il sacco (2 teste), il client lo vede col suo nome e senza copie finte,
# lo recupera con E e l'host gli ridà le teste. Poi muore l'host: il client vede il sacco del compagno.
# godot --path . --headless -s res://tests/sack_coop_checks.gd -- --sack-host
# godot --path . --headless -s res://tests/sack_coop_checks.gd -- --sack-client
const PORT := 27863
const SPOT := Vector3(8, 0, -14)
var world: Node3D
var fails := 0
var tag := ""


func check(ok: bool, what: String) -> void:
	print("%s %s %s" % [("PASS" if ok else "FAIL"), tag, what])
	if not ok: fails += 1


func _initialize() -> void:
	call_deferred("run")


func wait_for(cond: Callable, seconds := 20.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end and not cond.call():
		await process_frame
	return cond.call()


func heads(a: CharacterBody3D) -> int:
	return int(a.items.get("item_testa", 0))


func run() -> void:
	var session: Node = root.get_node("Session")
	var hosting: bool = "--sack-host" in OS.get_cmdline_user_args()
	tag = "HOST" if hosting else "CLIENT"
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Localization").current = "it"
	if hosting:
		session.profile("HOST", 0)
		session.host(PORT)
		paused = false
		if not await wait_for(func(): return session.roster.size() == 2 and session.roster.values().all(func(m): return m.ready), 60.0):
			print("FAIL HOST lobby incompleta")
			quit(1)
			return
		session.launch()
	else:
		session.profile("GUEST", 0)
		session.join("127.0.0.1", PORT)
		paused = false
		await create_timer(2.0, true).timeout
		session.set_ready(true)
		await session.game_started
	await create_timer(2.0, true).timeout
	world.spawner.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.global_position += Vector3(0, -500, 0); e.set_physics_process(false)
	var life: Node3D = world.zone_life
	var p: CharacterBody3D = world.player
	var ground := Vector3(SPOT.x, world.terrain.height(SPOT.x, SPOT.z) + 0.5, SPOT.z)
	if hosting:
		var guest: CharacterBody3D
		for id in world.actors:
			if world.actors[id] != p: guest = world.actors[id]
		check(guest != null, "Client collegato come attore")
		# --- 1. muore il client
		guest.set_item_count("item_testa", 4)
		world.survival._publish()
		guest.global_position = ground
		await create_timer(1.0, true).timeout
		guest.take_damage(99999.0)
		check(life.sacks.size() == 1, "L'host crea il sacco del client (%d)" % life.sacks.size())
		check(heads(guest) == 2, "Al client restano 2 teste su 4 (%d)" % heads(guest))
		if life.sacks.size() == 1:
			check(int(life.sacks[0]["heads"]) == 2 and str(life.sacks[0]["name"]) == "GUEST", "Sacco da 2 teste col nome del client (%s)" % str(life.sacks[0]["name"]))
		# Il client torna sul sacco (lo tiene lì anche l'host) e lo recupera da sé.
		check(await wait_for(func(): return not guest.dead, 8.0), "Il client rinasce")
		var recovered: bool = await wait_for(func():
			if life.sacks.size() > 0: guest.global_position = life.sacks[0]["node"].global_position + Vector3(0.6, 0.4, 0)
			return life.sacks.is_empty(), 25.0)
		check(recovered and heads(guest) == 4, "Il client ha recuperato il sacco: 4 teste sull'host (%d)" % heads(guest))
		# --- 2. muore l'host
		await create_timer(2.0, true).timeout
		p.set_item_count("item_testa", 2)
		p.global_position = ground + Vector3(3, 0, 0)
		await create_timer(0.5, true).timeout
		p.take_damage(99999.0)
		check(life.sacks.size() == 1 and int(life.sacks[0]["heads"]) == 1, "Sacco dell'host da 1 testa")
		await create_timer(4.0, true).timeout
	else:
		var st := {"phantom": 0, "asked": false}   # le lambda copiano le variabili locali: stato in un dizionario
		var seen: bool = await wait_for(func():
			st.phantom = maxi(st.phantom, life.sacks.size())
			return life.sacks.size() == 1, 20.0)
		check(seen, "Il client vede il sacco creato dall'host")
		await create_timer(0.5, true).timeout
		check(st.phantom <= 1 and life.sacks.size() == 1, "Nessun sacco finto sul client (massimo %d)" % maxi(st.phantom, life.sacks.size()))
		if life.sacks.size() == 1:
			var text: String = life.sacks[0]["label"].text
			check(text.begins_with("SACCO DI GUEST") and "2 TESTE" in text, "Etichetta del sacco sul client: %s" % text.replace("\n", " "))
		check(await wait_for(func(): return heads(p) == 2, 5.0), "Inventario dall'host: 2 teste (%d)" % heads(p))
		check(await wait_for(func(): return not p.dead, 8.0), "Rinato")
		await create_timer(0.5, true).timeout
		var got: bool = await wait_for(func():
			if life.sacks.size() > 0:
				p.global_position = life.sacks[0]["node"].global_position + Vector3(0.6, 0.4, 0)
				p.velocity = Vector3.ZERO
				if not st.asked and life.context().begins_with("E  RECUPERA IL SACCO"):
					st.asked = life.request()
			return life.sacks.is_empty() and heads(p) == 4, 25.0)
		check(st.asked, "E sul sacco manda la richiesta all'host")
		check(got, "Sacco recuperato: sparito e 4 teste sul client (%d)" % heads(p))
		var host_sack: bool = await wait_for(func(): return life.sacks.size() == 1, 15.0)
		check(host_sack and str(life.sacks[0]["name"]) == "HOST", "Il client vede il sacco dell'host col suo nome")
		check(heads(p) == 4, "Le teste del client non cambiano quando muore l'host (%d)" % heads(p))
	print("%s FALLITI %d" % [tag, fails])
	await create_timer(3.0 if hosting else 0.5, true).timeout
	session.leave()
	world.queue_free()
	await process_frame
	quit(0 if fails == 0 else 1)
