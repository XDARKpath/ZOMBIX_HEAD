extends SceneTree
# Attacchi degli infetti: colpo deciso che si schiva di lato, colpo a vuoto che lascia scoperti, due alla volta, salto visto da fuori.
#   godot --path . --headless -s res://tests/zombie_dodge_checks.gd
var fails := 0
var world
var p
const SPOT := Vector3(6, 0.1, -60)


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1


func _initialize() -> void:
	call_deferred("run")


func frames(n: int) -> void:
	for i in n: await physics_frame


func zombie(at: Vector3):
	var z = world._spawn_enemy(at)
	z.set_kind(0)
	z.rotation.y = 0.0          # guarda verso -Z, dove sta il giocatore
	z.pounce_cooldown = 99.0
	z.hear(p, 40)
	return z


## Aspetta l'attacco e ferma il mondo a `before` secondi dal colpo.
func until_hit(z, before: float) -> bool:
	var clock := 0.0
	while clock < 8.0 and not (z.state == 2 and z.attack_clock >= z.attack_hit - before):
		await physics_frame
		clock += 1.0 / 60.0
		if z.state != 2: p.health = 100.0
	return z.state == 2


func run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	p = world.player
	p.rig.set_physics_process(false)
	world.spawner.set_process(false)
	world.spawner.set_physics_process(false)
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)
	p.global_position = SPOT
	await frames(20)

	# --- 1. Fermo davanti: il colpo arriva.
	var a = zombie(SPOT + Vector3(0, 0, 1.2))
	p.health = 100.0
	check(await until_hit(a, 0.0), "L'infetto attacca chi gli sta davanti")
	await frames(3)
	check(p.health < 100.0 and not a.whiffed, "Fermo davanti, il colpo va a segno (vita %.0f)" % p.health)
	a.global_position += Vector3(0, -300, 0)
	a.set_physics_process(false)

	# --- 2. Passo di lato dopo che il colpo è deciso: a vuoto, sbilanciato, e il contrattacco vale di più.
	p.global_position = SPOT
	p.velocity = Vector3.ZERO
	p.knock_left = 0.0
	if p.status: p.status.clear_all()
	await frames(10)
	var b = zombie(SPOT + Vector3(0, 0, 1.2))
	await until_hit(b, b.COMMIT * 0.8)
	p.health = 100.0
	var planned: float = b.attack_len
	var facing: Vector3 = -b.global_basis.z
	# alle sue spalle, ancora a portata di braccio
	p.global_position = b.global_position - facing * 1.2
	p.set_physics_process(false)
	await frames(int(b.COMMIT * 60.0) + 4)
	check(p.health >= 100.0, "Alle sue spalle dopo il colpo deciso: nessun danno (vita %.0f)" % p.health)
	check(b.whiffed and b.attack_len > planned + 0.3, "Il colpo a vuoto lo lascia sbilanciato (%.2f -> %.2f s)" % [planned, b.attack_len])
	var before: float = b.health
	b.receive_hit("torso", 10.0, Vector3.ZERO, "axe", false)
	check(before - b.health > 13.0 and b.stagger >= 0.5, "Colpito da sbilanciato incassa di più e barcolla (-%.1f, %.2f s)" % [before - b.health, b.stagger])
	b.global_position += Vector3(0, -300, 0)
	b.set_physics_process(false)

	# --- 3. Quattro addosso: mai più di due che colpiscono insieme.
	p.global_position = SPOT
	await frames(5)
	var pack := []
	for i in 4:
		var angle := TAU * float(i) / 4.0
		pack.append(zombie(SPOT + Vector3(cos(angle), 0, sin(angle)) * 1.3))
	var most := 0
	var waited := false
	for i in 360:
		await physics_frame
		p.health = 100.0
		p.global_position = SPOT
		if p.status: p.status.clear_all()
		var busy := 0
		for z in pack:
			if z.state == 2: busy += 1
			if z._waiting: waited = true
		most = maxi(most, busy)
	check(most >= 1 and most <= 2, "In quattro attaccano al massimo in due insieme (visti %d)" % most)
	check(waited, "Gli altri aspettano il turno girando attorno")
	for z in pack:
		z.set_physics_process(false)
		z.global_position += Vector3(0, -300, 0)

	# --- 4. Salto visto da fuori: le ossa delle gambe ci sono e la posa in aria le muove.
	var avatar: Node = p.roll_pivot.get_node_or_null("Survivor")
	var driver = avatar.operative_driver if avatar else null
	check(driver != null, "Il giocatore ha l'avatar animato")
	if driver:
		var rig = driver.model.tool_rig
		var sk: Skeleton3D = rig.get_skeleton()
		var missing := []
		for row in rig.AIR_LEGS:
			if sk.find_bone(row[0]) < 0: missing.append(row[0])
		check(missing.is_empty(), "Ossa delle gambe per il salto: mancano %s" % str(missing))
		p.set_physics_process(true)
		p.global_position = SPOT + Vector3(8, 0.2, 0)
		await frames(30)
		check(rig.air < 0.05, "A terra niente posa da salto (%.2f)" % rig.air)
		# La posa finale (dopo tool_rig) si legge solo in skeleton_updated: fuori da lì lo scheletro torna alla clip.
		var knee := [0.0]
		sk.skeleton_updated.connect(func(): knee[0] = sk.get_bone_global_pose(sk.find_bone("calf_l")).origin.y)
		for i in 3: await process_frame
		var knee_ground: float = knee[0]
		p.stamina = 100.0
		check(p.try_jump(), "Il giocatore salta")
		await frames(14)
		for i in 3: await process_frame
		var knee_air: float = knee[0]
		if DisplayServer.get_name() != "headless":
			var cam := Camera3D.new()
			root.add_child(cam)
			cam.global_position = p.global_position + Vector3(2.2, 1.2, 1.6)
			cam.look_at(p.global_position + Vector3.UP * 1.0)
			cam.current = true
			for mesh in p.visual.find_children("*", "MeshInstance3D", true, false): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			world.get_node("Interface").visible = false
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/salto_da_fuori.png"))
		check(rig.air > 0.8 and knee_air > knee_ground + 0.08, "In aria il ginocchio sale (aria %.2f, ginocchio %.2f -> %.2f m)" % [rig.air, knee_ground, knee_air])
		await frames(90)
		check(rig.air < 0.05, "Atterrato torna a camminare (%.2f)" % rig.air)
	print("FINE ", "OK" if fails == 0 else "FALLITI %d" % fails)
	quit(fails)
