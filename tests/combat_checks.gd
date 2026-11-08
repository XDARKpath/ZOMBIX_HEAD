extends SceneTree
# Combattimento e reazioni nel gioco vero: teste solo dai morti, sputo, effetti sul giocatore, barricate, boss, spalle, fine zona.
# Foto in user://combat/ (godot --path . -s res://tests/combat_checks.gd).
const L := preload("res://world/villaggio/villaggio_layout.gd")
var world: Node3D
var p: CharacterBody3D
var fails: Array = []
var cam: Camera3D


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


func wait(frames: int) -> void:
	for i in frames: await physics_frame


func _snap(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://combat/%s.png" % title)
	print("FOTO ", title)


func _hold(title: String, eye: Vector3, look: Vector3) -> void:
	world.get_node("Interface").visible = false
	cam.global_position = eye
	cam.look_at(look)
	cam.current = true
	for i in 3: await process_frame
	await _snap(title)
	world.get_node("Interface").visible = true


func _enemy(kind: int, at: Vector3) -> Node3D:
	var e: Node3D = world._spawn_enemy(at)
	e.set_kind(kind)
	return e


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://combat"))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	# I controlli leggono i testi italiani: la lingua si cambia solo in memoria, senza salvare la scelta del giocatore.
	root.get_node("Localization").current = "it"
	TranslationServer.set_locale("it")
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	world.spawner.set_process(false)
	p = world.player
	cam = Camera3D.new()
	world.add_child(cam)
	var field := Vector3(6, 0.4, -70)
	world.terrain.ensure_near([field])
	await wait(5)

	# --- Spalle: la testa non si porta via nient'altro.
	var Anatomy := preload("res://art/infected_anatomy.gd")
	for model in ["ZMB_Tank", "ZMB_Walker_1", "ZMB_Spitter", "BOSS_Subject_Zero"]:
		var path := "res://art/zx_infected/%s.glb" % model
		var head_piece: MeshInstance3D = Anatomy.loose(path)
		var box: AABB = head_piece.mesh.get_aabb()
		print("  testa di %s: larga %.2f alta %.2f" % [model, box.size.x, box.size.y])
		check(maxf(box.size.x, box.size.z) < 0.55, "La testa di %s non contiene le spalle" % model)
		head_piece.free()
	var tank: Node3D = _enemy(2, field + Vector3(-3, 0, -6))
	var walker: Node3D = _enemy(0, field + Vector3(0, 0, -6))
	var spitter: Node3D = _enemy(4, field + Vector3(3, 0, -6))
	var runner: Node3D = _enemy(1, field + Vector3(6, 0, -6))
	for e in [tank, walker, spitter, runner]: e.set_physics_process(false)
	p.reset_at(field + Vector3(0, 0, 40))
	await wait(15)
	await _hold("01_infetti", field + Vector3(1.5, 1.6, -0.5), field + Vector3(1.5, 1.0, -6))
	check(not runner.skin_path().contains("Spitter") and spitter.skin_path().contains("Spitter"), "Il modello dello sputatore è solo di chi sputa")

	# --- Bruto colpito: incassa col corpo, non parte una clip di colpo.
	tank.pending_reaction = "knockdown"
	tank.reaction_dir = Vector3(0, 0, -1)
	tank.receive_hit("torso", 30.0, Vector3(0, 0, -2), "axe", true)
	check(tank.reaction == "", "Il bruto non cade per un colpo")
	check(tank.hit_age < 0.1 and tank.hit_power > 0.0, "Il bruto incassa il colpo")
	await wait(4)
	await _hold("02_bruto_colpito", tank.global_position + Vector3(2.8, 1.5, 2.8), tank.global_position + Vector3.UP * 1.3)
	var zm: Dictionary = tank.avatar.get_meta("zm")
	check(not str(zm.clip).begins_with("Z_Hit") and not str(zm.clip).begins_with("Z_Stagger"), "Nessuna clip strana sul bruto (%s)" % zm.clip)

	# --- La testa si stacca solo dal morto.
	var victim: Node3D = _enemy(0, field + Vector3(-6, 0, -2))
	victim.set_physics_process(false)
	var heads_before: int = world.survival.heads.size()
	victim.receive_hit("neck", 20.0, Vector3.ZERO, "axe", true)
	check(not victim.beheaded and not victim.dead, "Da vivo il colpo al collo non stacca la testa")
	victim.receive_hit("torso", 999.0, Vector3.ZERO, "axe", true)
	check(victim.dead and not victim.beheaded and world.survival.heads.size() == heads_before, "Ucciso con la lama resta con la testa")
	victim.receive_hit("torso", 10.0, Vector3.ZERO, "crowbar", true)
	check(not victim.beheaded, "Con un'arma senza lama la testa resta attaccata")
	victim.receive_hit("torso", 10.0, Vector3.ZERO, "axe", false)
	check(not victim.beheaded, "Un colpetto al corpo del cadavere non la stacca")
	p.reset_at(victim.global_position + Vector3(1.2, 0.3, 0))
	p.select_slot(0)
	await wait(4)
	check(world.survival.context().contains("CADAVERE"), "Accanto al morto il gioco dice come staccare la testa")
	victim.receive_hit("head", 10.0, Vector3.ZERO, "axe", false)
	check(victim.beheaded and world.survival.heads.size() == heads_before + 1, "Sul cadavere la lama alla testa la stacca")
	var drop: Array = world.survival.heads[world.survival.heads.size() - 1]
	check(drop[4] == "item_testa", "A terra c'è la testa di quel tipo")

	# --- La testa in mano è una testa.
	p.reset_at(field + Vector3(10, 0.3, 10))
	world.survival.heads.clear()
	world.survival._publish()
	p.add_item("item_testa")
	p.add_item("item_testa_bruto")
	p.equip_id("item_testa")
	await wait(40)
	world.get_node("Interface").visible = true
	p.rig.camera.current = true
	await _snap("03_testa_in_mano")
	p.equip_id("item_testa_bruto")
	await wait(30)
	await _snap("04_testa_di_bruto_in_mano")
	p.select_slot(-1)
	p.take_heads(9)

	# --- Sputatore: sputa, dalla bocca, e avvelena.
	p.reset_at(field + Vector3(3, 0.3, 6))
	spitter.set_physics_process(true)
	spitter.hear(p, 100.0)
	p.health = 100.0
	var saw_spit := false
	var glow_seen := false
	for i in 400:
		await physics_frame
		p.health = maxf(p.health, 60.0)
		if str(spitter.attack_clip) == "Z_Spit": saw_spit = true
		if spitter.avatar.get_node_or_null("SpitGlow") != null and spitter.avatar.get_node("SpitGlow").visible: glow_seen = true
		if saw_spit and float(p.status.left.poison) > 0.0: break
	check(saw_spit, "Lo sputatore sputa")
	check(glow_seen, "Si vede il veleno raccogliersi in bocca")
	check(float(p.status.left.poison) > 0.0, "Lo sputo avvelena")
	world.get_node("Interface").visible = true
	await _snap("05_avvelenato")
	var hp_before: float = p.health
	await wait(130)
	check(p.health < hp_before, "Il veleno toglie vita nel tempo")
	p.status.clear_all()
	spitter.queue_free()

	# --- Spinte, stordimento, sangue, parata.
	p.reset_at(field + Vector3(0, 0.3, 8))
	await wait(5)
	var before: Vector3 = p.global_position
	world.hit_player(p, 10.0, {"knock": Vector3(0, 0, 8.5), "stun": 0.9, "shake": 0.85, "heavy": true}, before + Vector3(0, 0, -1))
	check(float(p.status.left.stun) > 0.0, "Lo schianto stordisce")
	await wait(12)
	var moved: float = p.global_position.distance_to(before)
	check(moved > 0.6, "Lo schianto ti butta indietro (%.1f m)" % moved)
	check(p.status.speed_factor() < 0.5, "Da stordito ti muovi piano")
	await _snap("06_stordito")
	p.status.clear_all()
	world.hit_player(p, 5.0, {"bleed": 6.0}, p.global_position)
	check(float(p.status.left.bleed) > 0.0, "Il morso fa sanguinare")
	p.add_item("item_bende")
	world.survival.act(1, "useitem:item_bende")
	check(float(p.status.left.bleed) == 0.0, "Le bende fermano il sangue")
	p.melee.blocking = true
	world.hit_player(p, 5.0, {"poison": 6.0}, p.global_position)
	p.melee.blocking = false
	check(float(p.status.left.poison) == 0.0, "La parata tiene lontano il veleno")
	var scream: Node3D = _enemy(3, p.global_position + Vector3(0, 0, -5))
	var helper: Node3D = _enemy(0, p.global_position + Vector3(4, 0, -9))
	scream._scream(p)
	check(float(p.status.left.fear) > 0.0 and helper.frenzy > 0.0, "L'urlatore terrorizza e chiama gli altri")
	scream.queue_free()
	helper.queue_free()
	p.status.clear_all()

	# --- Radiazioni.
	var site: Vector2 = world.hazards.SITES[0][0]
	world.terrain.ensure_near([Vector3(site.x, 0, site.y)])
	p.reset_at(Vector3(site.x, world.terrain.height(site.x, site.y) + 0.4, site.y))
	await wait(240)
	check(p.status.radiation > 10.0, "Nel posto contaminato salgono le radiazioni (%.0f)" % p.status.radiation)
	await _snap("07_radiazioni")
	await _hold("08_posto_contaminato", Vector3(site.x + 13, world.terrain.height(site.x + 13, site.y + 9) + 2.2, site.y + 9), Vector3(site.x, 0.6, site.y))
	p.add_item("item_kit_medico")
	world.survival.act(1, "useitem:item_kit_medico")
	check(p.status.radiation == 0.0, "Il kit medico cura le radiazioni")

	# --- Borgo: le barricate chiudono davvero e il boss è il Macellaio.
	var village: Node3D = world.village
	world.terrain.ensure_near([L.CENTER])
	world.quest.stage = world.quest.VILLAGE_BOSS
	p.baits = 1
	p.reset_at(L.CENTER + Vector3(3.5, 0.5, 3.5))
	await wait(10)
	check(village.request_use(p) and village.arena == "active", "L'esca nel pozzo fa partire lo scontro")
	await wait(130)
	var space := root.get_world_3d().direct_space_state
	var closed := 0
	for dir in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		for off in [-3.5, 0.0, 3.5]:
			var side: Vector3 = dir.cross(Vector3.UP) * off
			var from: Vector3 = L.CENTER + dir * 14.0 + side + Vector3.UP * 1.0
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 10.0, 1))
			if not hit.is_empty(): closed += 1
	check(closed == 12, "Le barricate chiudono tutta la larghezza delle quattro vie (%d/12)" % closed)
	await wait(60)
	var boss: Node3D = village.boss
	check(is_instance_valid(boss) and boss.custom_skin.contains("Subject_Zero"), "Il Macellaio ha il suo modello")
	if is_instance_valid(boss):
		boss.set_physics_process(false)
		await wait(10)
		await _hold("09_macellaio", L.CENTER + Vector3(-5, 2.0, 7), boss.global_position + Vector3.UP * 2.0)
		await _hold("10_barricata_est", L.CENTER + Vector3(9, 1.8, 7), L.CENTER + Vector3(18, 1.2, 0))
		await _hold("11_barricata_nord", L.CENTER + Vector3(6, 1.8, -8), L.CENTER + Vector3(0, 1.2, -18))
		boss.set_physics_process(true)
	p.health = 100.0

	# --- La fine della zona.
	p.reset_at(Vector3(6, 0.4, -6))
	print("COMBAT: %d errori %s" % [fails.size(), fails])
	quit(0 if fails.is_empty() else 1)
