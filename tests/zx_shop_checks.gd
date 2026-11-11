extends SceneTree
# Negozi di zona 0.14: un negozio per tappa, armi giuste, acquisto convalidato e arma equipaggiabile.
const Route := preload("res://world/campaign/route.gd")
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
var failures := 0
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	var rules: Node3D = world.survival
	var zx: Node3D = rules.zx
	var p: CharacterBody3D = world.player
	var me: int = world.multiplayer.get_unique_id()
	check(zx.shops.size() == Route.POINTS.size() - 1, "Un negozio ZX per ogni tappa dopo il Lago (%d)" % zx.shops.size())
	var zone4: Array = zx.shops[3].items().map(func(e): return e.id)
	check("assault_rifle" in zone4 and "lmg" in zone4 and zx.shops[3].npc != null, "Spaccio del Deposito: armi militari e negoziante")
	# Zona 1: il catalogo dal banco dell'armaiolo.
	p.global_position = Layout.SHOP_NPC + Vector3(1.5, 0, 0)
	var here: Dictionary = zx.near(p)
	var ids: Array = here.get("items", []).map(func(e): return e.id)
	check("machete" in ids and "sawn_off" in ids and not "lmg" in ids, "Catalogo Lago Cenere sul banco dell'armaiolo")
	p.credits = 0
	check(not rules.act(me, "zxbuy:machete"), "Senza crediti l'acquisto è rifiutato")
	p.credits = 500
	p.owned.assign(["axe"])
	check(rules.act(me, "zxbuy:machete") and "machete" in p.owned and p.equipped == "machete" and p.credits == 430, "Acquisto: crediti scalati e arma in mano")
	check(not rules.act(me, "zxbuy:lmg"), "Un'arma di un'altra zona non si compra qui")
	p.global_position = zx.shops[3].to_global(Vector3(0, 0, 1.2))
	p.credits = 2000
	check(rules.act(me, "zxbuy:lmg") and p.magazine == 100, "Mitragliatrice comprata al Deposito, caricatore da 100")
	var timing: Array = preload("res://weapons/zx_arsenal.gd").timing("machete", false, 0)
	check(absf(timing[0] - preload("res://weapons/zx_arsenal.gd").hit_window("Player_Melee1H_Swing").x) < 0.001, "Il colpo del machete parte sul fotogramma della clip")
	# Vita e fiato massimi: due per zona, come lo zaino; l'host decide la zona dalla posizione.
	p.credits = 5000
	p.health_ups = {}
	p.stamina_ups = {}
	p.global_position = Layout.SHOP_NPC + Vector3(1.5, 0, 0)
	check(rules.act(me, "buyup:health") and rules.act(me, "buyup:health") and p.max_health() == 130.0, "Due vite in più da Big Earl: 130")
	check(not rules.act(me, "buyup:health"), "La terza vita in Zona 1 è rifiutata")
	check(rules.act(me, "buyup:stamina") and rules.act(me, "buyup:stamina") and not rules.act(me, "buyup:stamina") and p.max_stamina() == 130.0, "Fiato: due per zona")
	var d_up: Dictionary = {}
	for d in zx.displays:
		if d.id == "up_health" and d.shop == null: d_up = d
	check(not d_up.is_empty() and zx.status(p, d_up) == "max", "Il cartellino di Big Earl dice finiti")
	p.global_position = zx.shops[3].to_global(Vector3(0, 0, 1.2))
	check(rules.act(me, "buyup:health") and p.max_health() == 145.0, "In un'altra zona se ne comprano altre due")
	p.global_position = Vector3(500, 0, 500)
	check(not rules.act(me, "buyup:health"), "Lontano dai negozi niente acquisti")
	var saved: Dictionary = JSON.parse_string(JSON.stringify({"h": p.health_ups, "s": p.stamina_ups}))
	p.reset_inventory()
	check(p.max_health() == 100.0, "Nuova partita: vita base")
	p.health_ups = saved.h
	p.stamina_ups = saved.s
	check(p.max_health() == 145.0 and p.max_stamina() == 130.0, "Dopo il salvataggio JSON i potenziamenti restano")
	var src: String = FileAccess.get_file_as_string("res://autoload/save_manager.gd")
	check(src.contains("\"health_ups\"") and src.contains("\"stamina_ups\""), "Il salvataggio scrive i potenziamenti")
	# Sceriffo: con 5 teste e un'arma presa dal tavolo, l'esca arriva parlando.
	var quest: Node3D = world.quest
	quest.stage = quest.MORE_AND_WEAPON
	quest.delivered = quest.TOTAL_HEADS
	quest.weapon_bought = false
	p.owned.assign(["axe", "pistol"])
	p.baits = 0
	p.global_position = Layout.SHERIFF_NPC + Vector3(-1.5, 0, 0)
	rules.act(me, "quest:talk")
	check(quest.stage == quest.FOREST_BOSS and p.baits == 1, "Lo sceriffo dà l'esca (arma non comprata da Big Earl)")
	# Consigli del tutorial: in coda, uno alla volta, fermi mentre il dialogo è aperto.
	world.tips.clear()
	world.notice_left = 0.0
	for t in ["A", "B", "C"]: world.tip(t, 0.3)
	world.ui_open = true
	await create_timer(0.5).timeout
	check(world.notice_left <= 0.0 and world.tips.size() == 3, "Con il dialogo aperto nessun consiglio compare")
	world.ui_open = false
	await create_timer(0.1).timeout
	check(world.notice.text == "A" and world.tips.size() == 2, "Primo consiglio da solo")
	await create_timer(0.35).timeout
	check(world.notice.text == "B", "Poi il secondo")
	# Borgo: lo sputatore del serbatoio sta fuori dal cilindro e il borgo si popola all'ingresso.
	var village: Node3D = world.village
	var tank_ok := true
	for m in village.perches:
		var parent: Node3D = (m as Node3D).get_parent()
		if parent.name == "Serbatoio" and Vector2(m.position.x, m.position.z).length() < 2.1: tank_ok = false
	check(tank_ok, "Nessuno sputatore dentro il serbatoio dell'acqua")
	check(village.ARRIVE > village.L.FLAT and village.ARRIVE > 95.0, "Il borgo si popola all'ingresso (%d m)" % village.ARRIVE)
	print("ZX SHOPS ", "PASS" if failures == 0 else "FAIL", " (%d errori)" % failures)
	quit()
