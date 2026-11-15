extends SceneTree
# Progressi che non si perdono (punto 9 del brief del 15/11/2026):
# cibo e rigenerazione con la salute massima potenziata, sacco della morte sul pavimento della cripta,
# tempo per divorarlo con 1 e 4 infetti, prezzo della pistola uguale nei due negozi,
# salvataggio rotto a metà che riparte dalla copia buona, nuova partita che non cancella la campagna.
# I salvataggi veri dell'utente si mettono da parte e si rimettono.
# godot --path . --headless -s res://tests/progress_checks.gd
var world: Node3D
var p: CharacterBody3D
var fails := 0
var kept := {}
var SM: Node   # l'autoload: preload qui non compila (Localization non esiste ancora)


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1


func _initialize() -> void:
	call_deferred("run")


func _keep_saves() -> void:
	SM = root.get_node("SaveManager")
	for path in [SM.SLOT_PATH, SM.BACKUP_PATH, SM.OLD_PATH]:
		kept[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		if kept[path] != null:
			var f := FileAccess.open(path + ".prima_del_test", FileAccess.WRITE)
			f.store_buffer(kept[path]); f.close()


func _restore_saves() -> void:
	for path in kept:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if kept[path] != null:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(kept[path]); f.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".prima_del_test"))


func run() -> void:
	_keep_saves()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	root.get_node("Localization").current = "it"
	world.automated = true
	root.get_node("Session").launch()
	for i in 30: await physics_frame
	world.spawner.set_process(false)
	for e in world.targets: e.set_physics_process(false)
	p = world.player
	var life: Node3D = world.zone_life

	# --- 1. cibo con la salute massima potenziata (prima il tetto era 100)
	p.health_ups = {"0": 1}
	check(is_equal_approx(p.max_health(), 115.0), "Salute massima con un potenziamento: 115 (%.0f)" % p.max_health())
	p.health = 108.0
	life.food["can"] = 1
	life.eat()
	check(is_equal_approx(p.health, 115.0), "Scatoletta a 108/115: salute 115 (%.1f)" % p.health)
	p.health = 108.0
	life.fed = 30.0
	for i in 60: await process_frame
	check(p.health > 108.0 and p.health <= 115.0, "Sazio a 108/115: la rigenerazione sale verso 115, non scende a 100 (%.2f)" % p.health)
	p.health = 115.0
	for i in 30: await process_frame
	check(is_equal_approx(p.health, 115.0), "Sazio a salute piena: resta 115 (%.2f)" % p.health)
	life.fed = 0.0

	# --- 2. sacco della morte sul pavimento della cripta (prima finiva sul terreno in superficie)
	var crypt_floor: Vector3 = world.dungeon.to_global(world.dungeon.cell_pos(Vector2i(1, 2)) + Vector3(2, 0.6, 2))
	p.reset_at(crypt_floor)
	world.dungeon.enter(p)   # l'ingresso vero della cripta
	for i in 40: await physics_frame
	var stood: Vector3 = p.global_position
	p.reset_inventory()
	p.add_item("item_testa", 4)
	life.drop_sack(p)
	var sack_at: Vector3 = life.sacks[-1]["node"].global_position if life.sacks.size() > 0 else Vector3.INF
	check(p.is_on_floor() and stood.y > 200.0, "Giocatore appoggiato sul pavimento della cripta (y %.2f, la cripta è a quota 260)" % stood.y)
	check(absf(sack_at.y - stood.y) < 0.4, "Sacco in cripta sullo stesso pavimento: y %.2f contro %.2f" % [sack_at.y, stood.y])
	# Si recupera da lì.
	var before: int = int(p.items.get("item_testa", 0))
	check(life.request(), "Sacco in cripta recuperabile con E")
	check(int(p.items.get("item_testa", 0)) == 4 and before == 2, "Teste tornate in tasca (%d -> %d)" % [before, int(p.items.get("item_testa", 0))])

	# --- 3. quanto resiste il sacco con 1 e 4 infetti sopra
	for n in [1, 4]:
		var sack := {"node": Node3D.new(), "label": Label3D.new(), "heads": 1, "items": {}, "eaten": 0.0}
		life.add_child(sack["node"]); sack["node"].global_position = Vector3(5000, 0, 5000)
		life.sacks.append(sack)
		var eaters: Array = world.targets.filter(func(e): return is_instance_valid(e) and not e.dead).slice(0, n)
		for e in eaters: e.global_position = Vector3(5000.5, 0, 5000)
		var t := 0.0
		while life.sacks.has(sack) and t < 40.0:
			life._sacks(0.1); t += 0.1
		check(eaters.size() == n, "%d infetti disponibili per la prova" % n)
		print("  sacco divorato da %d infetti in %.1f s" % [n, t])
		check(t >= (19.0 if n == 1 else 7.5), "Sacco con %d infetti: almeno %s s per recuperarlo (%.1f)" % [n, "19" if n == 1 else "7,5", t])
		check(sack.get("warned", false), "Sacco con %d infetti: avviso al giocatore" % n)
		for e in eaters: e.global_position = Vector3(0, -500, 0)

	# --- 4. pistola: stesso prezzo dal banco dello sceriffo e dal catalogo di Big Earl
	check(world.survival.PRICES["pistol"] == ZXShopCatalog.price("pistol", 0), "Pistola: %d al banco, %d nel catalogo" % [world.survival.PRICES["pistol"], ZXShopCatalog.price("pistol", 0)])

	# --- 4b. download del presidio: si ferma e dice perché, non riparte da 10
	var m: Node3D = world.expedition
	var post: Vector3 = m.Route.POINTS[0]
	for e in world.targets:
		if is_instance_valid(e) and e.global_position.distance_to(post) < 70.0: e.global_position = Vector3(0, -500, 0)
	p.dead = false
	p.reset_at(post + Vector3(2, 0.5, 0))
	m.stage = 3; m.zone_index = 0; m.downloading = true; m.hold = 7.0; m.download_block = ""
	m._process(0.5)
	check(is_equal_approx(m.hold, 6.5) and m.download_block == "", "Download che scorre: 6,5 s (%.2f) %s" % [m.hold, m.download_block])
	p.dead = true
	m._process(1.0)
	check(m.downloading and is_equal_approx(m.hold, 6.5) and "A TERRA" in m.download_block, "Compagno a terra: pausa a 6,5 s, motivo \"%s\"" % m.download_block)
	print("  messaggio: " + m.detail())
	p.dead = false
	p.global_position = post + Vector3(80, 0, 0)
	m._process(1.0)
	check(m.downloading and is_equal_approx(m.hold, 6.5) and "LONTANO" in m.download_block, "Compagno lontano: pausa, motivo \"%s\"" % m.download_block)
	p.global_position = post + Vector3(2, 0, 0)
	var intruder: Node3D = world.targets.filter(func(e): return is_instance_valid(e) and not e.dead)[0]
	intruder.global_position = post + Vector3(30, 0, 0)
	m._process(1.0)
	check(m.downloading and is_equal_approx(m.hold, 6.5) and "INFETT" in m.download_block, "Infetto nel raggio: pausa, motivo \"%s\"" % m.download_block)
	intruder.global_position = Vector3(0, -500, 0)
	m._process(1.0)
	check(m.downloading and is_equal_approx(m.hold, 5.5) and m.download_block == "", "Causa rimossa: riparte da sola da 6,5 a 5,5 s (%.2f)" % m.hold)
	m.stage = 0; m.downloading = false

	# --- 5. salvataggio rotto a metà e nuova partita
	var SaveManager = root.get_node("SaveManager")
	for path in [SM.SLOT_PATH, SM.BACKUP_PATH, SM.OLD_PATH]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	p.reset_at(Vector3(7, 0.5, 3))
	p.credits = 333
	life.food = {"can": 2, "mushroom": 1, "fish": 0}
	check(SaveManager.write(world), "Primo salvataggio scritto")
	p.credits = 444
	check(SaveManager.write(world), "Secondo salvataggio scritto (il primo diventa la copia)")
	check(FileAccess.file_exists(SM.BACKUP_PATH), "Copia dell'ultimo salvataggio buono presente")
	# Gioco chiuso mentre scriveva: file principale troncato.
	var broken := FileAccess.open(SM.SLOT_PATH, FileAccess.WRITE)
	broken.store_string("{\"version\": 1, \"sta")
	broken.close()
	check(SaveManager.has_save() and int(SaveManager.read().get("credits", 0)) == 333, "File rotto: si riparte dalla copia (crediti %d)" % int(SaveManager.read().get("credits", 0)))
	p.credits = 0
	life.food = {"can": 0, "mushroom": 0, "fish": 0}
	check(SaveManager.apply(world) and p.credits == 333, "Caricata la copia buona: 333 crediti (%d)" % p.credits)
	check(int(life.food["can"]) == 2 and int(life.food["mushroom"]) == 1, "Il cibo raccolto torna col salvataggio (%s)" % str(life.food))
	check(int(SaveManager.summary().get("credits", 0)) == 333, "Il menu sa cosa sta per sostituire")
	SaveManager.erase()
	check(not SaveManager.has_save() and FileAccess.file_exists(SM.OLD_PATH), "Nuova partita: la campagna passa in save_slot_1.old.json, non sparisce")

	_restore_saves()
	print("FALLITI: %d" % fails)
	quit(1 if fails > 0 else 0)
