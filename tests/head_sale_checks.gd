extends SceneTree
# Vendita delle teste allo sceriffo (world/campaign/survival_rules.gd, ui/sell_prompt.gd).
# Il gesto parte subito in locale; "+N CREDITI" e i crediti arrivano solo quando l'host ha accettato.
# godot --path . --headless -s res://tests/head_sale_checks.gd
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
var fails := 0
var pops := 0
var p
var rules
var vm
var me: int
func _initialize(): call_deferred("run")
func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1
func wait_until(cond: Callable, seconds := 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		if cond.call(): return true
		await process_frame
	return cond.call()
## Crediti + valore delle teste in tasca: vendere non lo cambia mai (teste tolte = crediti dati).
func value() -> int:
	var v: int = p.credits
	for id in p.items: if ItemInfo.is_head(id): v += int(p.items[id]) * ItemInfo.head_price(id)
	return v
func count(id: String) -> int: return int(p.items.get(id, 0))
func hold(id: String) -> void:
	rules.act(me, "slot:%d" % p.hotbar.find(id))
	await create_timer(0.7).timeout
func near() -> void:
	var at: Vector3 = Layout.SHERIFF_NPC + Vector3(-1.6, 0, 0)
	p.global_position = Vector3(at.x, Layout.SHERIFF_NPC.y, at.z)
## Il gesto parte e, nello stesso frame (la mano si apre solo più avanti nella clip), succede "what"; poi fine della clip.
func gesture_then(what: Callable) -> void:
	rules.press_sell()
	check(vm.throwing(), "  gesto partito")
	what.call()
	await wait_until(func(): return not vm.throwing(), 3.0)
	await create_timer(0.2).timeout
func run():
	var world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	root.get_node("Localization").current = "it"
	TranslationServer.set_locale("it")
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.8).timeout
	var gps = world.get_node("Interface").find_child("RouteGPS", true, false)
	if gps: gps.opened = false
	p = world.player
	rules = world.survival
	me = world.multiplayer.get_unique_id()
	vm = rules.viewmodel()
	p.set_physics_process(false)
	p.rig.set_physics_process(false)
	for e in world.targets: e.set_physics_process(false)
	world.get_node("Interface").child_entered_tree.connect(func(n):
		if n is Label and n.text.begins_with("+") and n.text.contains("CREDITI"): pops += 1)
	near()
	# --- un oggetto
	p.set_item_count("item_testa", 1)
	var start := value()
	await hold("item_testa")
	rules.press_sell()
	check(vm.throwing() and pops == 0 and p.credits == 0, "V: parte il gesto, ancora nessun pagamento")
	check(await wait_until(func(): return p.credits == 25), "Mano aperta: l'host paga 25")
	check(pops == 1 and count("item_testa") == 0, "Un solo +25 e la testa sparisce (pop %d)" % pops)
	check(value() == start, "Invariante: teste tolte = crediti dati")
	await wait_until(func(): return not vm.throwing())
	# --- più stack: il pulsante dice cosa vende un tocco e cosa vende V tenuto
	p.set_item_count("item_testa", 3)
	p.set_item_count("item_testa_bruto", 2)
	start = value()
	await hold("item_testa")
	await process_frame
	var label: String = rules.sell_prompt.button.text
	check(label.contains("25") and label.contains("×3") and label.contains("75"), "Prima del gesto: prezzo, quantità e totale (%s)" % label.replace("\n", " / "))
	# --- pressione ripetuta nella stessa animazione
	var credits: int = p.credits
	rules.press_sell()
	for i in 20:
		rules.press_sell()
		await process_frame
	await wait_until(func(): return not vm.throwing())
	check(p.credits == credits + 25 and count("item_testa") == 2, "Pressione ripetuta: una sola vendita (%d crediti)" % (p.credits - credits))
	# --- cambio slot durante il gesto: mano su un'altra tasca, niente vendita e niente "+25"
	var before := pops
	credits = p.credits
	await gesture_then(func(): rules.act(me, "slot:0"))
	check(pops == before and p.credits == credits and count("item_testa") == 2, "Cambio slot nel gesto: annullata (pop %d, crediti %d)" % [pops - before, p.credits - credits])
	# --- cambio tipo durante il gesto: si era partiti con l'infetto, non si vende il bruto
	await hold("item_testa")
	await gesture_then(func(): rules.act(me, "slot:%d" % p.hotbar.find("item_testa_bruto")))
	check(pops == before and count("item_testa_bruto") == 2 and p.credits == credits, "Cambio tipo nel gesto: il bruto resta (pop %d)" % (pops - before))
	# --- allontanamento durante il gesto
	await hold("item_testa")
	await gesture_then(func(): p.global_position += Vector3(12, 0, 0))
	check(pops == before and p.credits == credits and count("item_testa") == 2, "Lontano dallo sceriffo: niente vendita né pagamento")
	near()
	# --- rifiuto dell'host: risposta "no" alla richiesta in attesa (in rete lo prova tests/head_sale_coop.gd)
	rules.sell_wait = 4243
	rules.sale_result(4242, "item_testa", true)
	check(pops == before and rules.sell_wait == 4243, "Risposta vecchia (altro numero): ignorata")
	rules.sell_auto = true
	rules.sale_result(4243, "item_testa", false)
	check(pops == before and p.credits == credits and not rules.sell_auto, "Host rifiuta: nessun +25 e la serie si ferma (pop %d, crediti %d)" % [pops - before, p.credits - credits])
	check(rules.get("sell_wait") is int and rules.get("sell_wait") == 0, "Dopo il rifiuto nessuna richiesta resta appesa")
	rules.press_sell()
	check(await wait_until(func(): return p.credits == credits + 25, 3.0) and pops == before + 1, "Dopo il rifiuto si vende di nuovo")
	check(value() == start, "Invariante dopo gesti annullati e rifiuti")
	await wait_until(func(): return not vm.throwing())
	# --- V tenuto: vende lo stack in mano, si ferma se lasci V, non tocca l'altro stack
	p.set_item_count("item_testa", 5)
	start = value()
	await hold("item_testa")
	Input.action_press("sell")
	check(await wait_until(func(): return count("item_testa") <= 3, 8.0), "V tenuto: vende una dopo l'altra")
	Input.action_release("sell")
	var left := count("item_testa")
	await create_timer(1.5).timeout
	check(count("item_testa") == left and not rules.sell_auto, "Lasci V: la serie si ferma (%d -> %d)" % [left, count("item_testa")])
	before = pops
	credits = p.credits
	var t0 := Time.get_ticks_msec()
	Input.action_press("sell")
	check(await wait_until(func(): return count("item_testa") == 0, 10.0), "V tenuto di nuovo: lo stack finisce")
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	Input.action_release("sell")
	await create_timer(1.0).timeout
	check(count("item_testa_bruto") == 2 and not rules.sell_auto, "L'altro stack (bruto ×2) non si tocca")
	check(p.credits - credits == 25 * left and pops - before == left, "Un +25 per testa: %d crediti, %d pop" % [p.credits - credits, pops - before])
	check(secs < left * 1.4 + 1.5, "Rapida: %d teste in %.1f s" % [left, secs])
	check(value() == start, "Invariante finale: teste tolte = crediti dati")
	print("HEAD_SALE fails=%d" % fails)
	quit(1 if fails else 0)
