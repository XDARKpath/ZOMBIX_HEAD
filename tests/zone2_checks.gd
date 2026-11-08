extends SceneTree
# Confini della Zona 1, valichi, deserto, Porto Secco con Mira e il negozio, Il Mago e il Signore delle Teste.
# Serve la finestra (foto in res://../ZOMBIX-HEAD-Zona2-Foto/): godot --path . -s res://tests/zone2_checks.gd
const Route := preload("res://world/campaign/route.gd")
const Terrain := preload("res://world/campaign/terrain.gd")
const MOVES := {"matriarca": ["bolts", "pool", "blink", "nova", "storm", "brood"], "signore": ["combo", "dash", "leap", "heads", "spin", "court"]}
var fails := 0
var world
var p
var cam: Camera3D


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1


func _initialize() -> void:
	call_deferred("run")


func shot(id: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.resize(960, 540)
	var dir := ProjectSettings.globalize_path("res://../ZOMBIX-HEAD-Zona2-Foto")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/" + id + ".png")


func view(id: String, from: Vector3, at: Vector3, wait := 0.7) -> void:
	world.terrain.ensure_near([from, at])
	p.global_position = Vector3(from.x, Terrain.ground_height(from.x, from.z) + 0.2, from.z)
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	await create_timer(wait).timeout
	await shot(id)


func heal() -> void:
	p.dead = false
	p.health = 100.0
	p.stamina = 100.0
	p.status.clear_all()


func clear_world() -> void:
	world.spawner.set_process(false)
	world.spawner.set_physics_process(false)
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)


## Tutto il confine: dappertutto una parete, tranne la gola con la statale.
func check_walls() -> void:
	var low := 0
	var checked := 0
	var samples: Array = []
	var z := Route.WALL_Z + 60.0
	while z < Route.MAX_Z - 120.0:
		samples.append(Vector2(Route.Z1_EAST, z))
		z += 40.0
	var x := Route.MIN_X + 120.0
	while x < Route.Z2_EAST:
		samples.append(Vector2(x, Route.WALL_Z))
		x += 40.0
	z = Route.WALL_Z
	while z > Route.Z2_NORTH:
		samples.append(Vector2(Route.Z2_EAST, z))
		z -= 40.0
	x = Route.MIN_X + 120.0
	while x < Route.Z2_EAST:
		samples.append(Vector2(x, Route.Z2_NORTH))
		x += 40.0
	var gaps := []
	for s in samples:
		if Route.road_distance(s) < 60.0: continue
		checked += 1
		if Route.zone_wall(s.x, s.y) < 70.0:
			low += 1
			gaps.append(s)
	check(checked > 150 and low == 0, "Montagne continue lungo tutti i confini (%d punti, %d bassi %s)" % [checked, low, gaps.slice(0, 4)])
	# Nessun altro passaggio per la statale.
	var gates: Array = Route.gates()
	check(gates.size() == 2, "La statale attraversa le catene solo ai due valichi (%d)" % gates.size())
	for g in gates:
		var at: Vector3 = g.at
		check(Route.zone_wall(at.x, at.z) < 1.0 and Terrain.ground_height(at.x, at.z) < 30.0, "Valico aperto nel terreno a %s" % [at])
	# Le pareti sono più ripide di quanto un personaggio riesca a salire (45 gradi).
	var steep := 0.0
	var probe := Vector2(Route.Z1_EAST - 56.0, -300.0)
	for i in 6:
		var a: float = Terrain.ground_height(probe.x + i * 8.0, probe.y)
		var b: float = Terrain.ground_height(probe.x + (i + 1) * 8.0, probe.y)
		steep = maxf(steep, (b - a) / 8.0)
	check(steep > 1.2, "La parete è troppo ripida da salire (pendenza %.2f)" % steep)


func test_gate_blocks() -> void:
	var gates: Array = Route.gates()
	var g0: Vector3 = gates[0].at
	var dir: Vector3 = gates[0].dir
	world.expedition.collected = [true, true, false]
	world.zone_gates.refresh()
	check(not world.zone_gates.is_open(0), "Con due boss su tre il valico resta chiuso")
	check(world.zone_gates.missing(0) == ["CARCERIERE"], "Il cartello dice chi manca")
	# Prova vera: il giocatore cammina verso il valico e si ferma.
	world.terrain.ensure_near([g0])
	var start: Vector3 = g0 - dir * 8.0
	p.set_physics_process(true)
	p.global_position = Vector3(start.x, Terrain.ground_height(start.x, start.z) + 0.3, start.z)
	await create_timer(0.3).timeout
	var yaw: float = atan2(-dir.x, -dir.z)
	p.rig.yaw = yaw
	Input.action_press("move_forward")
	await create_timer(3.5).timeout
	Input.action_release("move_forward")
	var passed: float = (p.global_position - g0).dot(dir)
	check(passed < 0.0, "A piedi il valico chiuso non si passa (%.1f m oltre)" % passed)
	await view("valico_chiuso", g0 - dir * 16.0 + Vector3.UP * 3.0, g0 + Vector3.UP * 2.5, 0.8)
	# Montagne viste da lontano.
	var far: Vector3 = g0 - dir * 90.0 + Vector3.UP * 24.0
	cam.global_position = far
	await view("confine_da_lontano", far, g0 + Vector3.UP * 20.0, 0.8)
	world.expedition.collected = [true, true, true]
	world.zone_gates.refresh()
	check(world.zone_gates.is_open(0), "Morti i tre boss il valico si apre")
	var at: Vector3 = g0 - dir * 6.0
	p.global_position = Vector3(at.x, Terrain.ground_height(at.x, at.z) + 0.3, at.z)
	await create_timer(0.3).timeout
	p.rig.yaw = atan2(-dir.x, -dir.z)
	Input.action_press("move_forward")
	await create_timer(5.5).timeout
	Input.action_release("move_forward")
	passed = (p.global_position - g0).dot(dir)
	check(passed > 1.0, "Aperto, si passa a piedi (%.1f m oltre)" % passed)
	await view("valico_aperto", g0 - dir * 16.0 + Vector3.UP * 3.0, g0 + dir * 40.0 + Vector3.UP * 2.0, 0.8)
	p.set_physics_process(false)


func run_move(boss, style: String, id: String, offset: Vector3) -> float:
	heal()
	p.global_position = boss.global_position + offset
	await physics_frame
	boss.brain.begin(id)
	var windup: float = float(boss.brain.move.get("windup", 0.5))
	var clock := 0.0
	var a := false
	var b := false
	var low := 100.0
	while clock < 7.0:
		await physics_frame
		clock += 1.0 / 60.0
		var look: Vector3 = (boss.global_position + p.global_position) * 0.5 + Vector3.UP
		# Se il giocatore muore la camera della morte prende il posto: le foto devono restare su questa.
		cam.current = true
		cam.global_position = look + Vector3(10.0, 8.0, 12.0)
		cam.look_at(look, Vector3.UP)
		low = minf(low, p.health)
		if p.dead: heal()
		if boss.brain.move.is_empty(): boss.brain.gap_left = 99.0
		if not a and clock > windup * 0.8:
			a = true
			await shot("%s_%s_1" % [style, id])
		if not b and clock > windup + 0.3:
			b = true
			await shot("%s_%s_2" % [style, id])
		if clock > windup + 0.4 and boss.brain.move.is_empty() and boss.brain.stun <= 0.0: break
	for i in 60:
		await physics_frame
		boss.brain.gap_left = 99.0
		low = minf(low, p.health)
		if p.dead: heal()
	return 100.0 - low


func dealt(boss, weapon: String, amount := 100.0) -> float:
	boss.health = 5000.0
	boss.max_health = 5000.0
	boss.brain.exposed = 0.0
	boss.brain.pop_clock = 0.0
	boss.receive_hit("torso", amount, Vector3.ZERO, weapon, false)
	return 5000.0 - boss.health


## L'ingresso del boss: due foto, nessun danno finché dura, e deve finire.
func watch_intro(boss, style: String) -> void:
	check(boss.brain.in_intro(), "%s entra in scena col suo ingresso" % style)
	var clock := 0.0
	var shots := [0.5, 1.35]
	while boss.brain.in_intro() and clock < 5.0:
		await physics_frame
		clock += 1.0 / 60.0
		cam.current = true
		cam.global_position = boss.global_position + Vector3(-6.5, 4.5, 9.0)
		cam.look_at(boss.global_position + Vector3.UP * 2.2, Vector3.UP)
		if not shots.is_empty() and clock > shots[0]:
			await shot("%s_ingresso_%d" % [style, 3 - shots.size()])
			shots.pop_front()
			if shots.size() == 1:
				var before: float = boss.health
				boss.receive_hit("torso", 100.0, Vector3.ZERO, "bow", false)
				check(boss.health == before, "%s non prende danno durante l'ingresso" % style)
	check(not boss.brain.in_intro(), "%s finisce l'ingresso (%.1f s)" % [style, clock])


func death_shots(boss, style: String) -> void:
	var at: Vector3 = boss.global_position
	for k in 2:
		await create_timer(0.35 if k == 0 else 1.5).timeout
		cam.current = true
		cam.global_position = at + Vector3(-6.5, 4.5, 9.0)
		cam.look_at(at + Vector3.UP * 1.5, Vector3.UP)
		await shot("%s_morte_%d" % [style, k + 1])


func test_bosses() -> void:
	var z2 = world.zone2
	var arena: Vector3 = Route.ARENA_MATRIARCA
	world.terrain.ensure_near([arena])
	await view("cratere", arena + Vector3(-24, 9, 20), arena + Vector3(0, 1, 0), 1.0)
	var mago = z2.spawn_for_test("matriarca")
	check(mago != null and mago.brain != null and mago.brain.style == "matriarca", "Il Mago compare nel Cratere col suo cervello")
	await watch_intro(mago, "matriarca")
	check(mago.avatar != null and mago.avatar.skeleton == null, "La scultura del Mago funziona senza ossa")
	await view("mago_arrivo", mago.global_position + Vector3(-7, 4.5, 9), mago.global_position + Vector3(0, 2.5, 0), 0.9)
	var b = mago.brain
	var pistol := dealt(mago, "pistol")
	check(is_equal_approx(pistol, 20.0), "Il velo ferma le pallottole (%.0f)" % pistol)
	b.stun = 0.0
	var arrow := dealt(mago, "bow")
	check(arrow > 150.0 and not b.veil, "L'arco strappa il velo (%.0f)" % arrow)
	b.stun = 0.0
	var pistol2 := dealt(mago, "pistol")
	check(pistol2 > 100.0, "Senza velo fa male tutto (%.0f)" % pistol2)
	b.veil_back = 99.0
	p.global_position = mago.global_position + Vector3(0, 0, 8)
	b.begin("storm")
	await create_timer(1.0).timeout
	check(b.move.get("id", "") == "storm", "La tempesta è in corso")
	dealt(mago, "bow")
	check(b.stun > 0.0 and b.move.is_empty(), "Un tiro ferma la tempesta")
	b.stun = 0.0
	b.events.clear()
	for id in MOVES.matriarca:
		b.phase = 1
		b.stun = 0.0
		b.gap_left = 99.0
		mago.global_position = arena + Vector3.UP * 0.2
		var lost: float = await run_move(mago, "matriarca", id, Vector3(0, 0, 9.0 if id != "nova" and id != "blink" else 4.0))
		print("  mago ", id, " toglie ", snappedf(lost, 0.1))
		if id not in ["blink", "brood"]: check(lost > 0.0, "Mago · %s colpisce chi resta fermo (%.0f)" % [id, lost])
		b.hazards.clear()
		b.waves.clear()
		b.events.clear()
	mago.health = 1.0
	b.exposed = 0.0
	b.veil = false
	b.veil_back = 99.0
	heal()
	mago.receive_hit("torso", 100.0, Vector3.ZERO, "bow", false)
	check(b.dying, "Il Mago muore con la sua morte")
	await death_shots(mago, "matriarca")
	check(z2.dead_matriarca, "Il Mago morto è registrato")
	check(p.items.has("item_testa_matriarca") or z2.world.survival.heads.any(func(h): return h[4] == "item_testa_matriarca"), "Lascia la sua testa (in tasca: %s, can_take %s, slot %d)" % [p.items.has("item_testa_matriarca"), p.can_take("item_testa_matriarca"), p.inventory_slots])
	# Il Signore.
	arena = Route.ARENA_SIGNORE
	world.terrain.ensure_near([arena])
	await view("cimitero", arena + Vector3(-23, 9, 18), arena + Vector3(0, 1, 0), 1.0)
	var sig = z2.spawn_for_test("signore")
	await watch_intro(sig, "signore")
	check(sig.crown_node != null, "Il Signore porta la corona di teschi")
	await view("signore_arrivo", sig.global_position + Vector3(-5, 3.2, 7), sig.global_position + Vector3(0, 2.2, 0), 0.9)
	b = sig.brain
	var gun := dealt(sig, "pistol")
	check(is_equal_approx(gun, 35.0), "La corona devia le pallottole (%.0f)" % gun)
	while b.skulls > 0:
		dealt(sig, "machete", 80.0)
		b.stun = 0.0
	check(b.skulls == 0, "Il machete taglia tutti i teschi")
	var gun2 := dealt(sig, "pistol")
	check(gun2 > gun * 2.0, "Senza corona fa male tutto (%.0f)" % gun2)
	for id in MOVES.signore:
		b.phase = 1
		b.stun = 0.0
		b.gap_left = 99.0
		sig.global_position = arena + Vector3.UP * 0.2
		var lost: float = await run_move(sig, "signore", id, Vector3(0, 0, 3.0 if id in ["combo", "spin"] else 8.0))
		print("  signore ", id, " toglie ", snappedf(lost, 0.1))
		if id != "court": check(lost > 0.0, "Signore · %s colpisce chi resta fermo (%.0f)" % [id, lost])
		b.hazards.clear()
		b.waves.clear()
		b.events.clear()
	check(not world.zone_gates.is_open(1), "Finché il Signore vive il secondo valico è chiuso")
	sig.health = 1.0
	sig.receive_hit("torso", 100.0, Vector3.ZERO, "machete", false)
	check(b.dying, "Il Signore muore con la sua morte")
	await death_shots(sig, "signore")
	check(z2.dead_signore and z2.stage == z2.REPORT, "Morti tutti e due, si torna da Mira")
	world.zone_gates.refresh()
	check(world.zone_gates.is_open(1), "Il secondo valico si apre")
	heal()


func run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.8).timeout
	world.get_node("Interface").visible = false
	var gps = world.get_node("Interface").find_child("RouteGPS", true, false)
	if gps: gps.opened = false
	p = world.player
	p.set_physics_process(false)
	p.rig.set_physics_process(false)
	clear_world()
	world.zone2._spawn_clock = 99999.0
	cam = Camera3D.new()
	cam.fov = 62
	root.add_child(cam)
	cam.current = true
	check_walls()
	check(not world.zone_gates.is_open(0) and not world.zone_gates.is_open(1), "All'inizio i due valichi sono chiusi")
	check(Route.desert(120, -1450) > 0.9 and Route.desert(100, -500) == 0.0, "Il deserto sta oltre il valico, non in Zona 1")
	check(Route.TITLES[1] == "PORTO SECCO", "La tappa si chiama Porto Secco")
	await test_gate_blocks()
	# Deserto e paese.
	var town: Vector3 = Route.POINTS[1]
	await view("deserto_dune", Vector3(-250, 22, -1800), Vector3(-450, 4, -2300), 1.2)
	await view("deserto_strada", Vector3(600, 12, -1650), Vector3(1000, 3, -1900), 1.2)
	await view("porto_secco", town + Vector3(30, 11, 38), town + Vector3(-8, 1, -6), 1.0)
	await view("mira", world.zone2.mira_at + Vector3(4.5, 1.7, 2.5), world.zone2.mira_at + Vector3(0, 1.1, 0), 0.8)
	# Mira.
	var z2 = world.zone2
	p.global_position = z2.mira_at + Vector3(2.0, 0.2, 0)
	check(z2.request_use(p) and world.survival.dialogue_open, "E vicino a Mira apre il dialogo")
	check(z2.stage == z2.HUNT, "Parlarle fa partire la caccia")
	world.survival.close_sheriff_dialogue()
	# Vende le teste come lo sceriffo.
	check(world.survival._near_sheriff(p), "A Mira si vendono le teste")
	# Negozio.
	var shop = world.survival.zx.shops[0]
	var front: Vector3 = shop.to_global(Vector3(0, 0, 1.2))
	p.global_position = front
	var here: Dictionary = world.survival.zx.near(p)
	check(not here.is_empty() and String(here.title).contains(root.get_node("Localization").t("Bazar di Porto Secco").to_upper()), "Il negozio di Porto Secco (%s)" % here.get("title", ""))
	await view("bazar", front + Vector3(0, 1.7, 0) + (front - shop.global_position).normalized() * 3.5, shop.global_position + Vector3.UP * 1.4, 0.8)
	world.expedition.zone_index = 1
	world.expedition.stage = 2
	check(z2.active() and world.expedition.title().contains("MAGO"), "L'obiettivo a schermo è della Zona 2 (%s)" % world.expedition.title())
	check(z2.safe(town), "Porto Secco è zona sicura dopo il presidio")
	await test_bosses()
	# Salvataggio.
	var saved: Dictionary = z2.save_data()
	z2.reset()
	check(not z2.dead_signore, "Reset: Zona 2 da capo")
	z2.load_data(saved)
	check(z2.dead_signore and z2.dead_matriarca, "Il salvataggio ricorda i boss morti")
	print("ZONA2 ", "OK" if fails == 0 else "FALLITO %d" % fails)
	quit(fails)
