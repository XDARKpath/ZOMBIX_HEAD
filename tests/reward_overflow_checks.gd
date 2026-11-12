extends SceneTree
# Premi con le tasche piene (player.gd add_item/reserve): premio del boss, pila piena, più premi insieme,
# tasca liberata, salvataggio e caricamento. Il salvataggio vero dell'utente si mette da parte e si rimette.
# godot --path . --headless -s res://tests/reward_overflow_checks.gd
const SLOT := "user://save_slot_1.json"
var world: Node3D
var p: CharacterBody3D
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1


func _initialize() -> void:
	call_deferred("run")


func reserve() -> Dictionary:
	return p.get("reserve") if p.get("reserve") != null else {}


## Quante copie di id ha il giocatore in tutto: tasche più riserva.
func total(id: String) -> int:
	return int(p.items.get(id, 0)) + int(reserve().get(id, 0))


## Nessun oggetto senza tasca: tutto quello che è in items sta in una tasca della barra.
func all_visible() -> bool:
	for id in p.items:
		var at: int = p.hotbar.find(id)
		if at < 0 or at >= p.inventory_slots: return false
	return true


func fill_pockets() -> void:
	p.reset_inventory()
	p.owned.assign(["axe", "machete", "crowbar"])
	p.hotbar.assign(["axe", "machete", "crowbar", "", "", "", "", "", ""])
	p.add_item("item_bende", 1)
	p.select_slot(0)


func run() -> void:
	var saved_before: PackedByteArray = FileAccess.get_file_as_bytes(SLOT) if FileAccess.file_exists(SLOT) else PackedByteArray()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	root.get_node("Localization").current = "it"
	TranslationServer.set_locale("it")
	world.automated = true
	root.get_node("Session").launch()
	for i in 30: await physics_frame
	world.spawner.set_process(false)
	for e in world.targets: e.set_physics_process(false)
	p = world.player
	p.set_physics_process(false)

	# --- premio del boss con le tasche piene
	fill_pockets()
	check(p.hotbar[3] == "item_bende" and not p.can_take("item_testa_matriarca"), "Tasche piene (4 su 4)")
	var Route := preload("res://world/campaign/route.gd")
	p.global_position = Route.ARENA_MATRIARCA + Vector3(2, 0, 0)
	var ground_before: int = world.survival.heads.size()
	var credits_before: int = p.credits
	world.zone2._on_boss("matriarca")
	check(p.credits == credits_before + 300, "Boss: i crediti arrivano comunque")
	check(total("item_testa_matriarca") == 1, "Boss a tasche piene: la testa è del giocatore (tasca o riserva), non persa")
	check(world.survival.heads.size() == ground_before, "Boss a tasche piene: niente testa lasciata per terra (non si salva)")
	check(p.equipped == "axe" and p.slot == 0, "Boss a tasche piene: la tasca in mano non cambia (%s, %d)" % [p.equipped, p.slot])
	check(all_visible(), "Nessun oggetto invisibile dopo il premio del boss")
	check(world.tips.any(func(t): return String(t[0]).contains("IN RISERVA") and String(t[0]).contains("×1")), "Avviso in coda: quantità e riserva")

	# --- più premi insieme
	var left := []
	for id in ["item_testa_bruto", "item_bende", "item_testa"]:
		left.append(p.add_item(id, 2))
	check(total("item_testa_bruto") == 2 and total("item_bende") == 3 and total("item_testa") == 2, "Più premi insieme: nessuno perso (%s)" % str(reserve()))
	check(all_visible() and p.equipped == "axe", "Più premi insieme: niente oggetti invisibili, mano invariata")

	# --- pila piena
	p.reset_inventory()
	p.owned.assign(["axe", "machete", "crowbar"])
	p.hotbar.assign(["axe", "machete", "crowbar", "", "", "", "", "", ""])
	p.carried_heads = 3
	p.global_position = Vector3(30, 0.5, 30)
	world.zone_life.drop_sack(p)
	if world.zone_life.sacks.size() > 0: p.global_position = world.zone_life.sacks[0]["node"].global_position
	check(world.zone_life.sacks.size() == 1 and p.carried_heads == 1, "Sacco della morte con 2 teste")
	p.add_item("item_testa", 4)
	check(int(p.items.get("item_testa", 0)) == 5, "Pila di teste piena (5)")
	world.zone_life.request()
	check(total("item_testa") == 7, "Sacco recuperato con la pila piena: nessuna testa persa (%d)" % total("item_testa"))
	check(all_visible(), "Pila piena: niente oggetti invisibili")

	# --- tasca liberata: la riserva entra in una tasca che non hai in mano
	fill_pockets()
	p.add_item("item_testa_bruto", 1)
	check(int(reserve().get("item_testa_bruto", 0)) == 1, "Premio in riserva")
	p.select_slot(3)
	check(p.equipped == "item_bende", "In mano le bende (tasca 4)")
	p.remove_one("item_bende")
	check(p.equipped != "item_testa_bruto", "Usata l'ultima benda: la mano non prende da sola il premio (%s)" % p.equipped)
	check(int(p.items.get("item_testa_bruto", 0)) == 1 and p.hotbar.find("item_testa_bruto") >= 0 and p.hotbar.find("item_testa_bruto") != p.slot, "Tasca liberata: il premio entra in una tasca non in mano")
	check(reserve().is_empty(), "Riserva vuota dopo la consegna")
	# Pila che si svuota: le teste in riserva entrano nella loro tasca.
	p.reset_inventory()
	p.owned.assign(["axe", "machete", "crowbar"])
	p.hotbar.assign(["axe", "machete", "crowbar", "", "", "", "", "", ""])
	p.add_item("item_testa", 7)
	p.set_item_count("item_testa", 3)
	check(int(p.items.get("item_testa", 0)) == 5 and total("item_testa") == 5, "Pila scesa a 3: le 2 in riserva rientrano (5 in tasca)")

	# --- progressione e morte: la riserva non finisce nel sacco
	fill_pockets()
	p.add_item("item_testa_signore", 1)
	var baits_before: int = p.baits
	p.baits += 1
	check(p.baits == baits_before + 1, "L'esca (progressione) è un contatore: entra anche a tasche piene")
	world.zone_life.drop_sack(p)
	check(int(reserve().get("item_testa_signore", 0)) == 1, "Morte: la testa del boss in riserva non finisce nel sacco")

	# --- salvataggio e caricamento
	fill_pockets()
	p.add_item("item_testa_matriarca", 1)
	p.add_item("item_testa_bruto", 2)
	var expect: Dictionary = reserve().duplicate()
	var wrote: bool = root.get_node("SaveManager").write(world)
	p.reset_inventory()
	if p.get("reserve") != null: p.reserve = {}
	root.get_node("SaveManager").apply(world)
	check(wrote and not expect.is_empty() and reserve() == expect, "Salvataggio e caricamento: la riserva torna (%s)" % str(reserve()))
	check(all_visible(), "Dopo il caricamento: niente oggetti invisibili")

	# Rimette il salvataggio dell'utente com'era.
	if saved_before.is_empty():
		if FileAccess.file_exists(SLOT): DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT))
	else:
		var f := FileAccess.open(SLOT, FileAccess.WRITE)
		f.store_buffer(saved_before)
		f.close()
	print("PREMI ", "OK" if fails == 0 else "FALLITO %d" % fails)
	quit(fails)
