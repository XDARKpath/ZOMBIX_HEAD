extends SceneTree
# Munizioni: caricatore per arma, ricarica con durata vera, pompa a cartucce interrompibile, niente sparo in ricarica.
# Con --capture=<cartella> (finestra vera, non headless) salva le foto a metà ricarica di pistola e pompa.
const Arsenal := preload("res://weapons/zx_arsenal.gd")
var failures := 0
var p: CharacterBody3D

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func wait(seconds: float) -> void:
	await create_timer(seconds, true, true).timeout

func snap(dir: String, id: String) -> void:
	if dir == "": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir.path_join("reload_%s.png" % id))
	print("shot ", id)

func run() -> void:
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): dir = arg.trim_prefix("--capture=")
	var lab: Node3D = load("res://world/movement_lab/movement_lab.tscn").instantiate(); root.add_child(lab)
	p = lab.player
	await frames(20)
	p.owned.assign(["axe", "pistol", "pump_shotgun", "lmg"])
	p.hotbar.assign(["pistol", "pump_shotgun", "lmg", "axe", "", "", "", "", ""])
	p.select_slot(0)
	check(p.magazine == 8, "Pistola piena: %d/8" % p.magazine)
	p.magazine = 3
	p.select_slot(2)
	check(p.magazine == 100, "LMG ha il suo caricatore (100), non i 3 della pistola: %d" % p.magazine)
	p.magazine = 40
	p.select_slot(1)
	check(p.magazine == 6, "Pompa non eredita 40 colpi: %d/6" % p.magazine)
	p.select_slot(0)
	check(p.magazine == 3, "Tornando alla pistola restano i suoi 3 colpi: %d" % p.magazine)
	# Ricarica pistola: dura davvero e non si spara nel frattempo.
	check(p.reload_weapon(), "Ricarica pistola parte")
	check(absf(p.reload_left - Arsenal.reload_seconds("pistol")) < 0.05, "Ricarica pistola dura %.2f s" % p.reload_left)
	check(not p.melee.perform_attack(false), "Durante la ricarica non si spara")
	await wait(0.6)
	await snap(dir, "pistol")
	check(p.magazine == 3 and p.reload_left > 0.0, "A metà ricarica il caricatore non è ancora pieno")
	await wait(1.3)
	check(p.magazine == 8 and p.reload_left == 0.0, "Fine ricarica: 8/8")
	# Cambio arma a metà ricarica: si annulla, nessun travaso.
	p.magazine = 2; p.reload_weapon(); await wait(0.3)
	p.select_slot(2)
	check(p.reload_left == 0.0 and p.magazine == 40, "Cambio arma annulla la ricarica (LMG resta a 40)")
	await wait(2.0)
	check(p.magazine == 40, "La ricarica annullata non riempie l'arma nuova")
	# Pompa: una cartuccia alla volta, interrompibile dal grilletto.
	p.select_slot(1); p.magazine = 2; p.melee.attacking = false
	var t0 := Time.get_ticks_msec()
	check(p.reload_weapon(), "Ricarica pompa parte")
	await wait(Arsenal.reload_seconds("pump_shotgun") + 0.1)
	check(p.magazine == 3 and p.reload_left > 0.0, "Pompa: una cartuccia (3/6) e la ricarica continua")
	await wait(0.25)
	await snap(dir, "pump")
	p.melee.perform_attack(false)
	check(p.reload_left == 0.0 and p.magazine == 3, "Il grilletto interrompe la ricarica della pompa a 3/6")
	p.reload_weapon()
	while p.reload_left > 0.0: await physics_frame
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	check(p.magazine == 6, "Pompa piena dopo cartucce una a una: %d/6" % p.magazine)
	check(Arsenal.reload_seconds("pump_shotgun") * 4 > 2.0, "Pompa da 2 a 6 colpi richiede più di 2 s")
	print("pump total %.2f s" % secs)
	print("AMMO: ", failures, " errors")
	quit(0 if failures == 0 else 1)
