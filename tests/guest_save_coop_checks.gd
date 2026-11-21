extends SceneTree
# Salvataggio per giocatore in cooperativa, due processi veri collegati in rete locale.
# L'ospite compra un coltello e tiene teste e crediti, si scollega: l'host lo scrive nel salvataggio sotto il suo ID
# stabile. Poi si riapre il campo con CONTINUA, l'ospite rientra e ritrova tutto.
# godot --path . --headless -s res://tests/guest_save_coop_checks.gd -- --gsave-host
# godot --path . --headless -s res://tests/guest_save_coop_checks.gd -- --gsave-client
# L'host salva in uno slot suo (SLOT_PATH cambiato): la campagna del giocatore e i test delle altre sessioni non si toccano.
const PORT := 27871
const GUEST_ID := "test-guest-7f3a"
const SAVES := ["user://test_gsave_%d.json", "user://test_gsave_%d.bak.json", "user://test_gsave_%d.old.json"]
var world: Node3D
var fails := 0
var tag := ""
var session: Node
var saves: Node


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


func new_world() -> void:
	if is_instance_valid(world):
		world.queue_free()
		await process_frame
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	await process_frame


func quiet() -> void:
	world.spawner.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.global_position += Vector3(0, -500, 0); e.set_physics_process(false)


func open_camp(resume: bool) -> bool:
	session.host(PORT)
	paused = false
	if not await wait_for(func(): return session.roster.size() == 2 and session.roster.values().all(func(m): return m.ready), 60.0):
		check(false, "lobby incompleta")
		return false
	world.pending_resume = resume
	session.launch()
	await create_timer(2.0, true).timeout
	quiet()
	return true


func join_camp() -> void:
	session.join("127.0.0.1", PORT)
	paused = false
	await create_timer(2.0, true).timeout
	session.set_ready(true)
	await session.game_started
	await create_timer(2.0, true).timeout
	quiet()


func guest() -> CharacterBody3D:
	for id in world.actors:
		if world.actors[id] != world.player: return world.actors[id]
	return null


func run() -> void:
	session = root.get_node("Session")
	saves = root.get_node("SaveManager")
	var hosting: bool = "--gsave-host" in OS.get_cmdline_user_args()
	tag = "HOST" if hosting else "CLIENT"
	root.get_node("Localization").current = "it"
	await new_world()
	if hosting: await host_side()
	else: await client_side()
	print("%s FALLITI %d" % [tag, fails])
	session.leave("")
	world.queue_free()
	await process_frame
	quit(0 if fails == 0 else 1)


func host_side() -> void:
	# Slot di prova tutto suo, nome diverso a ogni esecuzione: si parte da una campagna vuota.
	var stamp := Time.get_ticks_usec() + OS.get_process_id()
	saves.SLOT_PATH = SAVES[0] % stamp
	saves.BACKUP_PATH = SAVES[1] % stamp
	saves.OLD_PATH = SAVES[2] % stamp
	session.profile("HOST", 0)
	if await open_camp(false):
		await first_session()
		# --- seconda sessione: CONTINUA, l'ospite rientra
		session.leave("")
		await new_world()
		await create_timer(1.0, true).timeout
		var on_disk: Dictionary = saves.read()
		check(int(on_disk.get("credits", -1)) == 77 and on_disk.get("players", {}).has(GUEST_ID), "Il salvataggio c'è ancora prima di riaprire il campo")
		if await open_camp(true):
			var g := guest()
			check(g != null and g.owned.has("knife"), "Al rientro l'ospite ha di nuovo il coltello (%s)" % [g.owned if g else "?"])
			check(g != null and g.credits == 150, "Al rientro l'ospite ha i suoi crediti (%d)" % [g.credits if g else -1])
			check(g != null and heads(g) == 3, "Al rientro l'ospite ha le sue teste (%d)" % [heads(g) if g else -1])
			check(world.player.credits == 77, "L'host ha i suoi crediti, non quelli dell'ospite (%d)" % world.player.credits)
			await create_timer(5.0, true).timeout
	for path in [saves.SLOT_PATH, saves.BACKUP_PATH, saves.OLD_PATH]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func first_session() -> void:
	var g := guest()
	check(g != null, "Ospite collegato come attore")
	if g == null: return
	var peer: int = world.actors.find_key(g)
	check(await wait_for(func(): return saves.peer_ids.get(peer, "") == GUEST_ID, 5.0), "L'host conosce l'ID stabile dell'ospite")
	world.player.credits = 77
	g.credits = 200
	g.set_item_count("item_testa", 3)
	world.survival._publish()
	# Prima della spesa: c'è già un salvataggio (come all'ingresso della tappa), senza il coltello.
	world.started = true
	check(saves.write(world), "Primo salvataggio scritto")
	# Il movimento lo decide l'host: è lui a portare l'ospite al banco di Big Earl, il client manda solo "buy:knife".
	var shop: Vector3 = preload("res://world/zona1_rifugio/refuge_layout.gd").SHOP_NPC
	check(await wait_for(func():
		if not is_instance_valid(g): return false
		g.global_position = shop + Vector3(1.2, 0.3, 0)
		g.velocity = Vector3.ZERO
		return g.owned.has("knife"), 30.0), "L'ospite compra il coltello da Big Earl")
	if not is_instance_valid(g): return
	check(g.credits == 150, "Il coltello costa 50 (%d)" % g.credits)
	check(await wait_for(func(): return session.roster.size() == 1, 30.0), "L'ospite si scollega")
	var saved: Dictionary = saves.read().get("players", {}).get(GUEST_ID, {})
	check((saved.get("owned", []) as Array).has("knife") and int(saved.get("credits", 0)) == 150, "Appena uscito, il salvataggio ha la sua roba (%s)" % [saved.get("owned", [])])
	check(int(saved.get("items", {}).get("item_testa", 0)) == 3, "…e le sue 3 teste")
	check(saves.write(world) and saves.read().get("players", {}).has(GUEST_ID), "Un salvataggio dopo l'uscita non lo perde")
	check(not saves.read().get("players", {}).has(saves.player_id) or saves.player_id == GUEST_ID, "L'host non si salva due volte")


func client_side() -> void:
	saves.player_id = GUEST_ID
	session.profile("GUEST", 0)
	await join_camp()
	var p: CharacterBody3D = world.player
	check(await wait_for(func(): return p.credits == 200 and heads(p) == 3, 10.0), "Crediti e teste dall'host (%d, %d)" % [p.credits, heads(p)])
	var bought: bool = await wait_for(func():
		if not p.owned.has("knife") and Engine.get_process_frames() % 30 == 0: world.survival.request("buy:knife")
		return p.owned.has("knife"), 20.0)
	check(bought, "Comprato il coltello")
	await create_timer(1.0, true).timeout
	session.leave("")
	await new_world()
	await create_timer(6.0, true).timeout
	# --- rientro nella seconda sessione dell'host
	await join_camp()
	p = world.player
	check(await wait_for(func(): return p.owned.has("knife") and p.credits == 150 and heads(p) == 3, 10.0),
		"Rientrato: coltello, 150 crediti e 3 teste (%s, %d, %d)" % [p.owned, p.credits, heads(p)])
