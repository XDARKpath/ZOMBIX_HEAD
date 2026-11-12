extends SceneTree
# Inventario, lancio e vendita (world/campaign/survival_rules.gd, player/player.gd, ui/backpack_panel.gd, player/viewmodel/fp_arms.gd).
# Foto: res://../screenshots/inv-<vista>.png
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
var fails := 0
func _initialize(): call_deferred("run")
func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1
func shot(id: String, wait := 0.4):
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/inv-" + id + ".png"))
func look(p, from: Vector3, at: Vector3) -> void:
	p.global_position = from
	var d: Vector3 = (at - (from + Vector3.UP * p.eye_height)).normalized()
	p.rig.yaw = atan2(-d.x, -d.z)
	p.rig.pitch = asin(clampf(d.y, -1.0, 1.0))
	p.rig.reset_follow()
func wait_until(cond: Callable, seconds := 3.0) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call(): return true
		await process_frame
		t += get_root().get_process_delta_time()
	return cond.call()
func press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
func run():
	var world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	# I controlli leggono i testi italiani: la lingua si cambia solo in memoria, senza salvare la scelta del giocatore.
	root.get_node("Localization").current = "it"
	TranslationServer.set_locale("it")
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.8).timeout
	var gps = world.get_node("Interface").find_child("RouteGPS", true, false)
	if gps: gps.opened = false
	var p = world.player
	var rules = world.survival
	var me: int = world.multiplayer.get_unique_id()
	var vm = rules.viewmodel()
	p.set_physics_process(false)
	p.rig.set_physics_process(false)
	for e in world.targets: e.set_physics_process(false)
	look(p, Vector3(8, 0.1, -11), Vector3(8, 1.4, -20))
	# --- barra
	p.owned.assign(["axe", "machete"]); p.hotbar[1] = "machete"
	check(p.hotbar[0] == "axe" and p.equipped == "axe" and p.slot == 0 and p.inventory_slots == 4, "Quattro tasche: ascia nella prima")
	check(rules.act(me, "slot:-1") and p.equipped == "", "Stesso tasto: mani vuote")
	rules.act(me, "slot:0")
	rules._scroll_slot(-1)
	check(p.slot == 0, "Rotella: al bordo si ferma")
	rules._scroll_slot(1)
	check(p.slot == 1 and p.equipped == "machete", "Rotella: tasca dopo")
	rules._scroll_slot(1)
	check(p.slot == 2 and p.equipped == "", "Rotella: tasca vuota = mani vuote")
	rules.act(me, "slot:0")
	check(rules.act(me, "slot:1") and p.equipped == "machete", "Tasto 2: machete in mano")
	rules.act(me, "slot:0")
	await shot("hotbar", 1.0)
	# --- raccolta teste: ×3 nello slot
	p.carried_heads = 3
	check(p.hotbar.has("item_testa") and int(p.items["item_testa"]) == 3, "Tre teste: ×3 in barra")
	await shot("tasche", 1.5)
	# --- tasche piene
	p.owned.assign(["axe", "machete", "crowbar"]); p.hotbar[3] = "crowbar"
	check(not p.can_take("item_bende") and p.can_take("item_testa"), "Tasche piene: niente di nuovo, le teste si impilano nella loro")
	p.owned.assign(["axe", "machete"]); p.hotbar[3] = ""
	# --- vendita
	var near: Vector3 = Layout.SHERIFF_NPC + Vector3(-1.6, 0, 0)
	look(p, Vector3(near.x, Layout.SHERIFF_NPC.y, near.z), Layout.SHERIFF_NPC + Vector3(0, 1.0, 0))
	rules.act(me, "slot:0")
	await process_frame
	check(rules.context().begins_with("METTI LA TESTA IN MANO"), "Senza testa in mano: %s" % rules.context())
	check(not rules.act(me, "sell:item_testa") and p.credits == 0, "Vendita rifiutata senza testa in mano")
	rules.act(me, "slot:%d" % p.hotbar.find("item_testa"))
	await create_timer(0.7).timeout
	check(rules.sell_ready() and rules.context().begins_with("[V] VENDI"), "Con la testa in mano: %s" % rules.context())
	await shot("vendi")
	rules.request_context()
	check(p.credits == 0 and int(p.items["item_testa"]) == 3, "E vicino allo sceriffo non vende")
	if world.survival.dialogue_open: world.survival.close_sheriff_dialogue()
	rules.press_sell()
	check(vm.throwing(), "V: parte la consegna (Item_Testa_Give)")
	await shot("vendi-give", 0.4)
	check(await wait_until(func(): return p.credits == 25), "Mano aperta: +25 crediti")
	check(int(p.items["item_testa"]) == 2, "Restano ×2")
	await create_timer(1.0).timeout
	Input.action_press("sell")
	check(await wait_until(func(): return p.carried_heads == 0, 6.0), "V tenuto: vendute anche le altre")
	Input.action_release("sell")
	check(p.credits == 75 and p.equipped != "item_testa" and not p.hotbar.has("item_testa"), "Slot vuoto, si torna a un'arma (%s)" % p.equipped)
	check(not rules.act(me, "sell:item_testa"), "Nessuna testa: l'host rifiuta la vendita")
	# --- lancio: ascia su uno zombie
	var z = world.targets[0]
	look(p, Vector3(8, 0.1, -11), Vector3(8, 1.5, -18))
	z.global_position = Vector3(8, Terrain_y(8, -16), -16)
	z.global_position.y = p.global_position.y
	rules.act(me, "equip:axe")
	await create_timer(0.8).timeout
	var hp: float = z.health
	rules.press_throw()
	check(vm.throwing(), "Q: parte la clip Axe_Throw")
	await shot("lancio", 0.28)
	check(await wait_until(func(): return not p.owned.has("axe")), "Alla mano aperta l'ascia esce dall'inventario")
	check(p.equipped == "machete", "In mano passa il machete")
	check(rules.thrown.size() == 1, "Ascia in volo")
	var body = rules.thrown[0].node if rules.thrown.size() > 0 else null
	await shot("lancio-volo", 0.15)
	check(await wait_until(func(): return z.health < hp or z.dead, 2.0), "L'ascia colpisce lo zombie (%.0f -> %.0f)" % [hp, z.health])
	check(await wait_until(func(): return is_instance_valid(body) and body.resting, 8.0), "L'ascia si ferma per terra")
	if is_instance_valid(body):
		look(p, body.global_position + Vector3(0, 0, 1.5), body.global_position)
		await shot("lancio-terra", 0.3)
		check(rules.context().begins_with("E  RACCOGLI"), "A terra: %s" % rules.context())
		# Se l'ascia ha decapitato lo zombie, con E si prende prima la testa caduta lì vicino.
		for _i in 3:
			if not p.owned.has("axe"): rules.request_context()
		check(p.owned.has("axe") and rules.thrown.is_empty(), "E: ascia di nuovo in tasca")
		p.carried_heads = 0
	# --- lancio: testa e bende
	look(p, Vector3(8, 0.1, -11), Vector3(8, 1.5, -18))
	p.carried_heads = 2
	p.add_item("item_bende", 2)
	rules.act(me, "equip:item_bende")
	await create_timer(0.7).timeout
	await shot("bende", 0.1)
	var heads_before: int = rules.heads.size()
	rules.press_throw()
	check(await wait_until(func(): return int(p.items.get("item_bende", 0)) == 1), "Q con le bende: ×2 -> ×1")
	check(p.equipped == "item_bende", "Te ne resta una in mano")
	await create_timer(1.2).timeout
	p.health = 50
	vm.use_item()
	rules._use_held()
	rules.pending_use = "item_bende"
	check(await wait_until(func(): return p.health > 50 and not p.items.has("item_bende"), 4.0), "Tasto sinistro: bende usate, +35 salute (%.0f)" % p.health)
	rules.act(me, "equip:item_testa")
	await create_timer(0.7).timeout
	rules.press_throw()
	check(await wait_until(func(): return p.carried_heads == 1), "Q con la testa: ×2 -> ×1")
	check(await wait_until(func(): return rules.heads.size() > heads_before, 8.0), "La testa lanciata torna testa per terra")
	# --- Q toccata appena: le bende cadono ai piedi, non volano
	p.add_item("item_bende", 1)
	rules.act(me, "equip:item_bende")
	await create_timer(0.7).timeout
	var dropped_before: int = rules.thrown.size()
	rules.throw_hold = 0.05
	rules._inventory_tick(0.0)
	check(await wait_until(func(): return rules.thrown.size() > dropped_before), "Q breve: le bende escono dall'inventario")
	check(not vm.throwing(), "Q breve: nessuna clip di lancio")
	var drop = rules.thrown[rules.thrown.size() - 1].node if rules.thrown.size() > dropped_before else null
	if drop:
		await wait_until(func(): return not is_instance_valid(drop) or drop.resting, 6.0)
		var gap: float = Vector2(drop.global_position.x - p.global_position.x, drop.global_position.z - p.global_position.z).length() if is_instance_valid(drop) else 99.0
		check(gap < 1.5, "Q breve: cadono ai piedi (%.2f m)" % gap)
	# --- reset
	p.reset_inventory()
	check(p.items.is_empty() and p.equipped == "axe" and p.hotbar[0] == "axe" and p.hotbar[4] == "", "Nuova partita: inventario pulito")
	print("INVENTARIO ", "OK" if fails == 0 else "FALLITO %d" % fails)
	quit()
func Terrain_y(_x: float, _z: float) -> float:
	return 0.0