extends SceneTree
# Lesioni per parte degli infetti (pacchetto B): zone fini con il lato, stato di ogni parte e conseguenze, arti staccati
# con il moncone chiuso, cadavere, teste, rete. Nel gioco vero (zombix.tscn).
#   godot --path . --headless -s res://tests/zombie_injury_checks.gd
# Rete, due processi (prima l'host):
#   godot --path . --headless -s res://tests/zombie_injury_checks.gd -- --injury-host
#   godot --path . --headless -s res://tests/zombie_injury_checks.gd -- --injury-client
var Injury: GDScript   # caricato in run(): zx_arsenal vuole gli autoload pronti
const Anatomy = preload("res://art/infected_anatomy.gd")
const Pose = preload("res://art/infected_injury_pose.gd")
const PORT := 27871
var world: Node3D
var fails := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails += 1


## Fotogrammi interi: le hitbox le sposta infected_motion nel _process, la fisica può fare più passi in un fotogramma.
func wait(frames: int) -> void:
	for i in frames:
		await process_frame
		await physics_frame


func wait_for(test: Callable, seconds: float = 8.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not test.call() and Time.get_ticks_msec() < end:
		await physics_frame
	return test.call()


func run() -> void:
	Injury = load("res://enemies/zombie_injury.gd")
	var args := OS.get_cmdline_user_args()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	var session: Node = root.get_node("Session")
	if "--injury-host" in args: await _host(session)
	elif "--injury-client" in args: await _client(session)
	else: await _local(session)
	print("ZOMBIE_INJURY ", fails, " errori")
	if session.online: session.leave()
	world.queue_free()
	await process_frame
	await process_frame
	quit(1 if fails > 0 else 0)


func _enemy(kind: int, at: Vector3) -> Node3D:
	var e: Node3D = world._spawn_enemy(at)
	e.set_kind(kind)
	e.set_physics_process(false)
	return e


func _area(e: Node3D, zone: String) -> Area3D:
	for a in e.hitboxes:
		if a.get_meta("zone") == zone: return a
	return null


func _tris(e: Node3D) -> int:
	var mesh: Mesh = Anatomy.find_mesh(e.avatar).mesh
	var n := 0
	for s in mesh.get_surface_count(): n += mesh.surface_get_array_index_len(s) / 3
	return n


func _stump(e: Node3D) -> MeshInstance3D:
	return Anatomy.find_mesh(e.avatar).get_parent().get_node_or_null("Moncone")


func _ray_zone(from: Vector3, to: Vector3) -> String:
	var q := PhysicsRayQueryParameters3D.create(from, to, 16)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	return str(hit.collider.get_meta("zone")) if not hit.is_empty() and hit.collider.has_meta("zone") else ""


func _local(session: Node) -> void:
	for i in 10: await process_frame
	session.launch()
	world.automated = true
	await wait(30)
	world.spawner.set_process(false)
	var field := Vector3(6, 0.4, -70)
	world.terrain.ensure_near([field])
	world.player.reset_at(field + Vector3(0, 0, 40))
	await wait(5)

	# --- Zone fini: 16 hitbox piccole che seguono le ossa, nessuna più "torso".
	var a: Node3D = _enemy(0, field)
	await wait(4)
	var zones: Array = a.hitboxes.map(func(h): return h.get_meta("zone"))
	check(zones.size() == 16 and Injury.PARTS.all(func(p): return p in zones), "Una hitbox per ogni parte fine (%d)" % zones.size())
	var biggest := 0.0
	for h in a.hitboxes: biggest = maxf(biggest, h.get_child(0).shape.radius)
	check(biggest <= 0.16, "Niente sfere giganti: raggio massimo %.2f m" % biggest)
	var hand: Area3D = _area(a, "hand_r")
	var bone_at: Vector3 = (a.avatar.skeleton.global_transform * a.avatar.skeleton.get_bone_global_pose(a.avatar.bone_ids["hand_r"])).origin
	check(hand.global_position.distance_to(bone_at) < 0.15, "La hitbox della mano destra sta sulla mano (%.2f m dall'osso)" % hand.global_position.distance_to(bone_at))
	var seen := _ray_zone(hand.global_position + Vector3.UP * 0.5, hand.global_position + Vector3.DOWN * 0.05)
	check(seen == "hand_r", "Un raggio dall'alto sulla mano destra colpisce hand_r (%s)" % seen)
	check(a.coarse("hand_r") == "torso" and a.coarse("calf_l") == "legs" and a.coarse("foot_r") == "feet" and a.coarse("head") == "head", "coarse() dà i vecchi gruppi")

	var t0 := Time.get_ticks_usec()
	for i in 500: a.update_hitboxes()
	print("  misura: update_hitboxes (16 parti) %.1f us per chiamata" % ((Time.get_ticks_usec() - t0) / 500.0))

	# --- Colpo alla mano destra: lesione su hand_r, non su hand_l.
	a.receive_hit("hand_r", 25.0, Vector3(0, 0, -1), "crowbar", false)
	check(a.part_state("hand_r") >= Injury.WOUNDED and a.part_state("hand_l") == Injury.HEALTHY, "Mano destra lesa (%d), sinistra sana (%d)" % [a.part_state("hand_r"), a.part_state("hand_l")])
	check(a.hit_zone == "hand_r" and a.hit_point.distance_to(hand.global_position) < 0.01, "hit_zone e hit_point tengono parte e lato (%s)" % a.hit_zone)
	a.receive_hit("legs", 10.0, Vector3.ZERO, "crowbar", false)
	check(a.hit_zone in ["calf_l", "calf_r"], "Il vecchio nome \"legs\" diventa un polpaccio (%s)" % a.hit_zone)

	# --- Lama sull'avambraccio: si stacca, da quel lato niente manata.
	var b: Node3D = _enemy(0, field + Vector3(3, 0, 0))
	await wait(4)
	var tris_before := _tris(b)
	var dropped_before: int = Anatomy.dropped.filter(func(n): return is_instance_valid(n)).size()
	var forearm_at: Vector3 = _area(b, "forearm_r").global_position
	var t1 := Time.get_ticks_usec()
	b.receive_hit("forearm_r", 80.0, Vector3(0, 0, -2), "axe", true)
	print("  misura: primo distacco (taglio, moncone e pezzo da preparare) %.1f ms" % ((Time.get_ticks_usec() - t1) / 1000.0))
	check(b.part_state("forearm_r") == Injury.SEVERED and b.part_state("hand_r") == Injury.SEVERED and b.part_state("forearm_l") == Injury.HEALTHY, "Ascia caricata sull'avambraccio destro: staccato (mano compresa)")
	check(not b.can_strike("r") and b.can_strike("l"), "can_strike: destra no, sinistra sì")
	await wait(3)
	check(_area(b, "forearm_r").collision_layer == 0 and _area(b, "hand_r").collision_layer == 0 and _area(b, "upperarm_r").collision_layer == 16, "Hitbox di avambraccio e mano spente, braccio ancora colpibile")
	var after := _ray_zone(forearm_at + Vector3.UP * 0.5, forearm_at + Vector3.DOWN * 0.3)
	check(after != "forearm_r" and after != "hand_r", "Dove c'era l'avambraccio il raggio non lo trova più (%s)" % after)
	var stump := _stump(b)
	check(_tris(b) < tris_before and stump != null and stump.mesh != null and stump.mesh.get_surface_count() == 1, "Corpo senza l'avambraccio (%d -> %d triangoli) e moncone chiuso (%d triangoli)" % [tris_before, _tris(b), stump.mesh.surface_get_array_len(0) / 3 if stump and stump.mesh else 0])
	var pieces: Array = Anatomy.dropped.filter(func(n): return is_instance_valid(n))
	var piece: RigidBody3D = pieces.back() if not pieces.is_empty() else null
	check(pieces.size() == dropped_before + 1 and piece != null and piece.get_child(0).mesh.get_surface_count() == 2, "L'avambraccio cade come corpo fisico, chiuso dove si attaccava")
	var start_y: float = piece.global_position.y if piece else 0.0
	await wait(60)
	check(piece and is_instance_valid(piece) and piece.global_position.y < start_y - 0.3, "Il pezzo cade a terra (%.2f -> %.2f)" % [start_y, piece.global_position.y if piece else 0.0])
	check(b.health > 0.0 and not b.dead, "Perdere un avambraccio non è morire (vita %.0f)" % b.health)

	# --- Mazza sulla gamba: frattura e zoppia, nessun distacco. Il bruto, che non cade per un colpo solo.
	var c: Node3D = _enemy(2, field + Vector3(-3, 0, 0))
	await wait(4)
	c.receive_hit("calf_l", 40.0, Vector3(0, 0, -2), "sledgehammer", true)
	var any_cut: bool = Injury.PARTS.any(func(p): return c.part_state(p) == Injury.SEVERED)
	check(c.part_state("calf_l") == Injury.FRACTURED and c.move_factor() < 1.0 and not any_cut and not c.crawling, "Bruto, mazza sul polpaccio sinistro: fratturato, move_factor %.2f, nessun distacco, in piedi" % c.move_factor())
	var w: Node3D = _enemy(0, field + Vector3(-6, 0, 0))
	await wait(2)
	w.receive_hit("calf_l", 30.0, Vector3(0, 0, -2), "sledgehammer", true)
	check(w.part_state("calf_l") == Injury.FRACTURED and not Injury.PARTS.any(func(p): return w.part_state(p) == Injury.SEVERED), "Infetto comune, mazza sulla gamba: fratturata, niente distacco")
	print("  infetto comune dopo la mazza: crawling=", w.crawling, " (leg_damage ", w.leg_damage, " su ", w.LEG_LIMIT[0], ")")
	check(Injury.must_crawl({"calf_l": 3, "calf_r": 3}) and not Injury.must_crawl({"calf_l": 3}) and Injury.must_crawl({"thigh_r": 4}) and not Injury.must_crawl({"foot_r": 4}), "Striscia con una gamba staccata o due fratturate, non con una sola frattura o senza piede")
	var cut_leg: Node3D = _enemy(2, field + Vector3(-9, 0, 0))
	await wait(2)
	cut_leg.receive_hit("thigh_r", 90.0, Vector3(0, 0, -2), "axe", true)
	check(cut_leg.part_state("calf_r") == Injury.SEVERED and cut_leg.crawling, "Coscia staccata dall'ascia: striscia")

	# --- Proiettili: lesione localizzata, mai un distacco.
	var d: Node3D = _enemy(2, field + Vector3(0, 0, 4))
	await wait(2)
	d.receive_hit("forearm_l", 30.0, Vector3(0, 0, -1), "pistol", false)
	d.receive_hit("forearm_l", 30.0, Vector3(0, 0, -1), "pistol", false)
	d.receive_hit("hand_r", 130.0, Vector3(0, 0, -1), "sniper_rifle", false)
	check(d.part_state("forearm_l") in [Injury.WOUNDED, Injury.MAIMED] and d.part_state("hand_r") == Injury.FRACTURED and d.part_state("forearm_r") == Injury.HEALTHY, "Pistola: avambraccio leso (%d); fucile di precisione: mano rotta (%d), il resto sano" % [d.part_state("forearm_l"), d.part_state("hand_r")])
	var shot := {}
	for i in 20: Injury.hit(shot, {}, "hand_l", "sniper_rifle", 500.0, true, 0)
	check(not shot.values().has(Injury.SEVERED), "Nessun proiettile stacca un arto, nemmeno a 500 di danno")
	var blast := {}
	Injury.hit(blast, {}, "chest", "grenade", 120.0, true, 0)
	var cut_by_blast := blast.values().count(Injury.SEVERED)
	check(cut_by_blast <= 1 and blast.size() >= 10, "Granata: ferisce quasi tutto (%d parti) e stacca al massimo un arto (%d)" % [blast.size(), cut_by_blast])
	var boss := {}
	Injury.hit(boss, {}, "forearm_r", "axe", 500.0, true, 5)
	check(int(boss.get("forearm_r", 0)) <= Injury.WOUNDED, "Il boss si ferisce ma non perde pezzi")
	check(Injury.category("axe") == "blade" and Injury.category("knife") == "blade" and Injury.category("crowbar") == "blunt" and Injury.category("pistol") == "bullet" and Injury.category("bow") == "bullet" and Injury.category("grenade_launcher") == "blast", "Categorie d'arma dalla tabella di zx_arsenal")

	# --- Pose delle lesioni (le chiamerà infected_motion): braccio penzolante, gamba rigida.
	var pose := {"q": [Quaternion(), Quaternion(), Quaternion(), Quaternion(), Quaternion(), Quaternion()], "p": Vector3.ZERO}
	var named := {"upperarm_r": 0, "lowerarm_r": 1, "hand_r": 2, "calf_l": 3, "pelvis": 4, "spine_02": 5}
	Pose.apply(pose, named, d)
	check((pose.q[2] as Quaternion).is_equal_approx(Quaternion()) and (pose.q[0] as Quaternion).angle_to(Quaternion()) > 1.0, "Mano rotta: il braccio destro penzola lungo il fianco")
	var limp := {"q": pose.q.map(func(_q): return Quaternion()), "p": Vector3.ZERO}
	Pose.apply(limp, named, c)
	check((limp.q[4] as Quaternion).angle_to(Quaternion()) > 0.01 and (limp.p as Vector3).y < 0.0, "Gamba fratturata: il bacino cede da quella parte")

	# --- Cadavere: le parti restano, la lama a un arto stacca l'arto, la testa si stacca e si raccoglie ancora.
	var heads_before: int = world.survival.heads.size()
	b.receive_hit("chest", 999.0, Vector3.ZERO, "crowbar", true)
	await wait(3)
	check(b.dead and b.part_state("forearm_r") == Injury.SEVERED and _area(b, "hand_r").collision_layer == 0 and _stump(b).mesh != null, "Il cadavere resta senza avambraccio")
	b.receive_hit("forearm_l", 30.0, Vector3.ZERO, "axe", true)
	check(b.part_state("forearm_l") == Injury.SEVERED and not b.beheaded, "Sul cadavere la lama all'avambraccio lo stacca, la testa resta")
	b.receive_hit("head", 10.0, Vector3.ZERO, "axe", false)
	check(b.beheaded and world.survival.heads.size() == heads_before + 1, "Poi la lama alla testa la stacca e la testa è a terra da raccogliere")
	var held: Node3D = Anatomy.severed("res://art/zx_infected/ZMB_Walker_1.glb")
	check(held.get_child_count() >= 2 and (held.get_child(0) as MeshInstance3D).mesh.get_surface_count() > 0, "La testa in mano (vendita) ha ancora la sua mesh")
	held.free()

	# --- Stato per la rete: impacchettato e riapplicato su un altro infetto (come fa il client).
	var copy: Node3D = _enemy(0, field + Vector3(6, 0, 4))
	await wait(2)
	var packed: PackedByteArray = b.injury_pack()
	copy.injury_apply(packed)
	await wait(3)
	check(copy.injury_pack() == packed and copy.part_state("forearm_r") == Injury.SEVERED and _area(copy, "hand_l").collision_layer == 0 and _stump(copy).mesh != null, "Lo stato ricevuto taglia il corpo e spegne le hitbox anche sulla copia")

	# --- Limite dei pezzi a terra.
	for i in 14:
		var e: Node3D = _enemy(0, field + Vector3(-4 + i, 0, 8))
		await wait(1)
		e.receive_hit("hand_l", 60.0, Vector3.ZERO, "axe", true)
	var alive: int = Anatomy.dropped.filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()).size()
	check(alive <= Anatomy.MAX_DROPPED, "Al massimo %d pezzi a terra (%d)" % [Anatomy.MAX_DROPPED, alive])


func _host(session: Node) -> void:
	session.host(PORT)
	paused = false
	check(await wait_for(func(): return session.roster.size() == 2 and session.roster.values().all(func(m): return m.ready), 60.0), "Il secondo giocatore entra")
	session.launch()
	await create_timer(2.0, true).timeout
	world.spawner.set_process(false)
	var at: Vector3 = world.player.global_position + Vector3(0, 0, -4)
	var z: Node3D = world._spawn_enemy(at)
	z.set_physics_process(false)
	await create_timer(1.5, true).timeout
	z.receive_hit("forearm_r", 80.0, Vector3(0, 0, -2), "axe", true)
	z.receive_hit("calf_l", 20.0, Vector3(0, 0, -2), "crowbar", false)
	check(z.part_state("forearm_r") == Injury.SEVERED and z.part_state("calf_l") >= Injury.MAIMED, "Host: avambraccio staccato e polpaccio leso")
	await create_timer(6.0, true).timeout


func _client(session: Node) -> void:
	session.profile("Lesioni%d" % OS.get_process_id(), 1)
	session.join("127.0.0.1", PORT)
	paused = false
	check(await wait_for(func(): return session.roster.size() == 2, 30.0), "Collegato all'host")
	session.set_ready(true)
	check(await wait_for(func(): return world.started, 60.0), "La partita parte")
	var found := [null]
	var seen := func() -> bool:
		for t in world.targets:
			if is_instance_valid(t) and t.part_state("forearm_r") == Injury.SEVERED: found[0] = t
		return found[0] != null
	check(await wait_for(seen, 20.0), "Il client riceve l'avambraccio staccato dall'host")
	var z: Node3D = found[0]
	if z == null: return
	await wait(5)
	check(z.part_state("calf_l") >= Injury.MAIMED and not z.can_strike("r") and z.move_factor() < 1.0, "Sul client: polpaccio leso (%d), destra senza manata, zoppia %.2f" % [z.part_state("calf_l"), z.move_factor()])
	check(_area(z, "forearm_r").collision_layer == 0 and _stump(z) != null and _stump(z).mesh != null, "Sul client: hitbox spenta e moncone chiuso")
	check(z.hit_zone == "calf_l", "Sul client: ultimo colpo con parte e lato (%s)" % z.hit_zone)
	# Il client non decide: un colpo locale sulla replica non cambia nulla.
	var before: PackedByteArray = z.injury_pack()
	z.receive_hit("forearm_l", 200.0, Vector3.ZERO, "axe", true)
	check(z.injury_pack() == before, "Un colpo deciso dal client non stacca niente")
