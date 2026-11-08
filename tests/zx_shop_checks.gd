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
	print("ZX SHOPS ", "PASS" if failures == 0 else "FAIL", " (%d errori)" % failures)
	quit()
