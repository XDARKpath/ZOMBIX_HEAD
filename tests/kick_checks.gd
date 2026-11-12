extends SceneTree
# Calcio contestuale di ascia e pala: quando scatta e quando no.
# godot --path . --headless -s res://tests/kick_checks.gd
var failures := 0
var p
var m
var world

func _initialize(): call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame

## Zombie fermo (fisica spenta) a `ahead` metri davanti e `side` di lato; morto se `corpse`.
func place(ahead: float, side: float = 0.0, corpse := false) -> Node3D:
	var z: Node3D = world._spawn_enemy(p.position + Vector3(side, 0, -ahead))
	z.set_physics_process(false)
	z.rotation.y = 0.0
	await frames(3)
	if corpse:
		z.receive_hit("torso", 9999.0, Vector3.ZERO, "axe")
		z.set_process(false)     # resta nella posa in piedi: le hitbox della testa restano dove guarda il mirino
	z.update_hitboxes()
	await frames(2)
	return z

func remove(list: Array) -> void:
	for z in list:
		if is_instance_valid(z): z.global_position += Vector3(400, -300, 0)    # anche di lato: il calcio misura in piano

func idle() -> void:
	m.charging = false
	while m.attacking: await physics_frame
	if "_last_kick" in m: m._last_kick = -100.0     # niente recupero residuo dalla prova prima
	p.stamina = 100.0
	await frames(2)

func run():
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.5).timeout
	p = world.player
	m = p.melee
	p.set_physics_process(false)
	world.spawner.set_process(false)
	world.spawner.set_physics_process(false)
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)
	p.health = 100
	p.set_crouched(false, true)
	p.eye_height = preload("res://autoload/balance.gd").EYE_HEIGHT
	p.position = Vector3(6, 0.1, -60)
	p.rig.yaw = 0.0
	p.rig.pitch = 0.0
	p.equipped = "axe"
	await create_timer(0.7).timeout
	var charges := [0]
	m.charge_started.connect(func() -> void: charges[0] += 1)

	# 1. Zombie vivo vicino, sotto il mirino: calcio, e l'host lo sa (charge_started arriva all'host come "charge").
	await idle()
	var z: Node3D = await place(0.8)
	charges[0] = 0
	m.begin_charge()
	check(m.attacking and m.attack_clip == "Kick", "Zombie vivo a 0,8 m nel mirino: calcio")
	check(charges[0] == 1, "Il calcio parte da charge_started: online lo decide anche l'host")
	while m.attacking: await physics_frame
	var stun: float = z.stagger
	var cooldown: float = m.get_script().get_script_constant_map().get("KICK_COOLDOWN", 0.0)
	check(stun > 0.5 and cooldown > stun + 0.8, "Recupero del calcio (%.1f s) più lungo dello stordimento (%.1f s)" % [cooldown, stun])
	remove([z])

	# 2. Cadavere davanti nel mirino, zombie vivo vicino di lato: si colpisce il cadavere (la testa), niente calcio.
	await idle()
	var corpse: Node3D = await place(1.3, 0.0, true)
	var side: Node3D = await place(0.65, 0.6)
	m.begin_charge()
	check(m.charging and not m.attacking, "Cadavere nel mirino e vivo di lato: fendente, non calcio")
	remove([corpse, side])

	# 3. Bersagli sovrapposti: quello mirato è più lontano, il vicino è di lato.
	await idle()
	var far: Node3D = await place(1.9)
	var near: Node3D = await place(0.65, 0.6)
	m.begin_charge()
	check(m.charging and not m.attacking, "Mirato quello lontano, il vicino è di lato: fendente")
	remove([far, near])
	# ...e il vicino davanti copre il lontano: calcio a quello davanti.
	await idle()
	far = await place(1.9)
	near = await place(0.8)
	m.begin_charge()
	check(m.attacking and m.attack_clip == "Kick", "Vicino davanti al lontano: calcio")
	remove([far, near])

	# 4. Stamina bassa (sotto il costo del calcio): con uno zombie addosso si colpisce comunque, stanchi.
	await idle()
	z = await place(0.8)
	p.stamina = 3.0
	check(m.begin_charge() and m.charging, "Stamina 3 con zombie addosso: il colpo parte lo stesso")
	m.release_attack()
	check(m.attack_clip == "Axe_Tired", "...ed è il colpo stanco, non il calcio (%s)" % m.attack_clip)

	# 5. Colpo caricato: iniziata la carica, il rilascio non diventa mai un calcio.
	await idle()
	z.global_position += Vector3(0, 0, -6)
	await frames(2)
	check(m.begin_charge() and m.charging, "Zombie lontano: inizia la carica")
	z.global_position = p.global_position + Vector3(0, 0, -0.8)
	z.update_hitboxes()
	await frames(2)
	m.charge_time = 1.0
	m.release_attack()
	check(m.attack_clip == "Axe_HeavySwing", "Zombie arrivato addosso durante la carica: esce il pesante (%s)" % m.attack_clip)
	await idle()
	z.global_position += Vector3(0, 0, -6)
	await frames(2)
	m.begin_charge()
	z.global_position = p.global_position + Vector3(0, 0, -0.8)
	z.update_hitboxes()
	await frames(2)
	m.release_attack()
	check(m.attack_clip.begins_with("Axe_Light"), "Clic breve iniziato senza zombie vicino: fendente (%s)" % m.attack_clip)

	# 6. Input ripetuti con stamina sempre piena: lo zombie addosso non viene tenuto a calci per sempre.
	remove([z])                  # il pesante della prova 5 può averlo ucciso: uno nuovo
	await idle()
	z = await place(0.8)
	var kicks: Array = []
	var was_kick := false
	var last_time := 0.0
	var t0: float = m._clock
	while m._clock - t0 < 6.5:
		z.global_position = p.global_position + Vector3(0, 0, -0.8)
		z.health = z.max_health
		z.update_hitboxes()
		p.stamina = 100.0
		if not m.attacking:
			if m.charging: m.release_attack()
			else: m.begin_charge()
		var kick_now: bool = m.attacking and m.attack_clip == "Kick"
		# Un calcio nuovo può partire nello stesso fotogramma in cui finisce il precedente: lo si vede dal tempo che riparte.
		if kick_now and (not was_kick or m.attack_time < last_time): kicks.append(m._clock - t0)
		was_kick = kick_now
		last_time = m.attack_time
		await physics_frame
	var min_gap := 99.0
	for i in range(1, kicks.size()): min_gap = minf(min_gap, kicks[i] - kicks[i - 1])
	check(kicks.size() <= 3, "Clic continui per 6,5 s: al massimo 3 calci (%d, a %s)" % [kicks.size(), kicks])
	check(min_gap >= stun + 0.8, "Tra un calcio e l'altro lo zombie finisce la reazione e torna a muoversi (min %.2f s)" % min_gap)
	remove([z])

	print("KICK ", "PASS" if failures == 0 else "FAIL", " (%d errori)" % failures)
	quit(failures)
