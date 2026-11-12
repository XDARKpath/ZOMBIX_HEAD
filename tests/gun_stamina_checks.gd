extends SceneTree
# Armi da fuoco e stamina: sparare costa 0, quindi si spara anche a stamina 0 (clic, tenuto, input remoto).
# Restano i blocchi veri (caricatore vuoto, ricarica); corpo a corpo e arco come prima.
# godot --path . --headless -s res://tests/gun_stamina_checks.gd
const Balance := preload("res://autoload/balance.gd")
var failures := 0
var p: CharacterBody3D
var rejects: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame

## Stamina a zero come dopo una corsa: sfinito e rigenerazione ancora ferma.
func drained(amount: float = 0.0) -> void:
	p.stamina = amount
	p.exhausted = true
	p.regen_delay = Balance.STAMINA_REGEN_DELAY

func idle() -> void:
	Input.action_release("attack")
	while p.melee.attacking or p.melee.charging:
		p.melee.charging = false
		await physics_frame
	await frames(2)

func equip(slot: int) -> void:
	await idle()
	p.select_slot(slot)
	p.reload_left = 0.0
	await frames(2)

## Clic singolo vero (premi, un attimo, rilascia) attraverso l'input del gioco.
func click() -> int:
	var before: int = p.magazine
	Input.action_press("attack")
	await frames(3)
	Input.action_release("attack")
	await frames(3)
	return before - p.magazine

func run() -> void:
	var lab: Node3D = load("res://world/movement_lab/movement_lab.tscn").instantiate(); root.add_child(lab)
	p = lab.player
	p.melee.set_physics_process(true)   # il laboratorio lo spegne: qui serve l'input vero del gioco
	await frames(20)
	p.melee.attack_rejected.connect(func(r: String) -> void: rejects.append(r))
	p.owned.assign(["axe", "pistol", "assault_rifle", "knife", "bow", "pump_shotgun"])
	p.inventory_slots = 9
	p.hotbar.assign(["pistol", "assault_rifle", "axe", "knife", "bow", "pump_shotgun", "", "", ""])

	# Pistola (semiautomatica) a stamina 0, chiamata diretta come fa l'host.
	await equip(0)
	drained()
	var mag: int = p.magazine
	check(p.melee.begin_charge() and p.melee.release_attack(), "Pistola spara a stamina 0 (begin_charge/release)")
	check(p.magazine == mag - 1, "Pistola: un colpo consumato (%d -> %d)" % [mag, p.magazine])
	await idle()
	drained()
	check(await click() == 1, "Pistola: clic singolo a stamina 0 spara")
	await idle()
	drained(5.0)
	p.exhausted = false
	check(await click() == 1, "Pistola: clic in recupero (stamina 5) spara")
	# Clic mentre il colpo precedente finisce (colpo prenotato).
	await idle()
	drained()
	mag = p.magazine
	p.melee.begin_charge(); p.melee.release_attack()
	for i in 120:
		if not p.melee.attacking or p.melee.attack_time >= p.melee.active_windup + p.melee.active_seconds * 0.5 + 0.02: break
		await physics_frame
	var was_attacking: bool = p.melee.attacking
	Input.action_press("attack"); await frames(3); Input.action_release("attack")
	var queued: bool = p.melee._queued
	await idle()
	check(was_attacking and queued, "Pistola: clic durante il colpo viene prenotato")
	check(p.magazine == mag - 2, "Pistola: secondo clic prenotato a stamina 0 spara (%d -> %d)" % [mag, p.magazine])

	# Automatica: clic singolo e tenuto a stamina 0.
	await equip(1)
	drained()
	check(await click() >= 1, "Automatica: clic singolo a stamina 0 spara")
	await idle()
	drained()
	mag = p.magazine
	Input.action_press("attack")
	await frames(60)
	Input.action_release("attack")
	await idle()
	check(mag - p.magazine >= 3, "Automatica tenuta a stamina 0 spara a raffica (%d colpi)" % (mag - p.magazine))
	# Input remoto: sull'host il client arriva con begin_charge/release_attack.
	await idle()
	drained()
	p.local_control = false
	mag = p.magazine
	check(p.melee.begin_charge() and p.melee.release_attack() and p.magazine == mag - 1, "Input remoto: automatica spara a stamina 0")
	await idle()
	p.local_control = true

	# Blocchi legittimi.
	await equip(0)
	drained()
	p.magazine = 0
	p.melee.begin_charge(); p.melee.release_attack()
	check(p.magazine == 0 and not p.melee.attacking and p.reload_left > 0.0, "Caricatore vuoto: niente colpo, parte la ricarica")
	drained()
	check(not p.melee.begin_charge() and not p.melee.perform_attack(false), "In ricarica non si spara")
	# Pompa in ricarica: il grilletto vero (begin_charge) interrompe la ricarica, il colpo parte al clic dopo.
	await equip(5)
	drained()
	p.magazine = 2
	p.reload_weapon()
	check(p.reload_left > 0.0 and not p.melee.begin_charge() and p.reload_left == 0.0 and p.magazine == 2 and not p.melee.charging, "Pompa: il grilletto interrompe la ricarica a 2/6")
	check(await click() == 1, "Pompa: il clic dopo spara")
	check(not "Riprendi fiato." in rejects, "Nessun 'Riprendi fiato.' con le armi da fuoco: %s" % [rejects])

	# Corpo a corpo e arco: come prima.
	await equip(2)
	drained()
	rejects.clear()
	check(not p.melee.begin_charge() and "Riprendi fiato." in rejects, "Ascia a stamina 0: Riprendi fiato.")
	drained(5.0)
	check(p.melee.begin_charge(), "Ascia sfinita (stamina 5): colpo stanco consentito")
	await equip(3)
	drained(5.0)
	check(not p.melee.begin_charge(), "Coltello sotto il costo: rifiutato")
	await equip(4)
	p.arrows = 3
	drained()
	check(p.melee.begin_charge(), "Arco a stamina 0 si tende come prima")
	await idle()
	print("GUN_STAMINA: ", failures, " errors")
	quit(0 if failures == 0 else 1)
