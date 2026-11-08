extends SceneTree
# Combattimento con ascia e pala (braccia FpArms, gamba del calcio art/zx_fp/SM_FP_Melee.glb): combo, pesante, stanchezza, calcio,
# colpo legato alla lama, hit-stop, parata e reazioni direzionali degli zombie.
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
## Solo lo zombie della prova: senza spawner e senza gli altri zombie, che attaccano il giocatore fermo e lo uccidono a caso.
func clear_world(world) -> void:
	world.spawner.set_process(false)
	world.spawner.set_physics_process(false)
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)
func run():
	var world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.5).timeout
	var p = world.player
	var m = p.melee
	p.set_physics_process(false)
	clear_world(world)
	p.health = 100
	# In piedi: la fisica è spenta e altrimenti resterebbe l'altezza degli occhi dei primi fotogrammi.
	p.set_crouched(false, true)
	p.eye_height = preload("res://autoload/balance.gd").EYE_HEIGHT
	p.position = Vector3(6, 0.1, -60)
	p.rig.yaw = 0.0
	p.rig.pitch = 0.0
	p.equipped = "axe"
	var vm = p.rig.camera.get_node("Viewmodel/FpArms")
	await create_timer(0.7).timeout
	check(vm.visible and vm.blade_ready(), "Ascia sulle braccia v3 (viewmodel FpArms)")
	var clips: PackedStringArray = vm.library.get_animation_list()
	check("Axe_Equip" in clips and "Axe_Attack_A" in clips and "Axe_Attack_B" in clips and "Axe_Charge" in clips and "Axe_Heavy" in clips and vm._leg_player.has_animation("Kick"), "Clip di estrazione, colpi, carica, pesante e calcio")
	# Combo: tre colpi di fila, poi si ricomincia se si aspetta.
	var seen := []
	for i in 3:
		p.stamina = 100
		m.perform_attack(false)
		seen.append(m.attack_clip)
		while m.attacking: await physics_frame
	check(seen == ["Axe_Light1", "Axe_Light2", "Axe_Light3"], "Combo orizzontale, rovescio, dall'alto %s" % [seen])
	await create_timer(0.6).timeout
	p.stamina = 100
	m.perform_attack(false)
	check(m.attack_clip == "Axe_Light1", "Dopo una pausa la combo riparte dal primo colpo")
	while m.attacking: await physics_frame
	p.stamina = 100
	m.perform_attack(true)
	check(m.attack_clip == "Axe_HeavySwing" and is_equal_approx(m.active_seconds, 5.0 / 30.0) and is_equal_approx(m.active_recovery, 18.0 / 30.0), "Pesante: scatto 0,15 s e strappo 0,6 s")
	while m.attacking: await physics_frame
	p.stamina = 5
	m.perform_attack(false)
	check(m.attack_clip == "Axe_Tired" and is_equal_approx(m.time_scale, 0.7), "Sotto il 10% di stamina il colpo è stanco e più lento del 30%")
	while m.attacking: await physics_frame
	# Colpo legato alla lama: uno zombie davanti viene colpito solo nei fotogrammi di colpo.
	var z: Node3D = world._spawn_enemy(p.position + Vector3(0, 0, -1.6))
	z.set_physics_process(false)
	await frames(3)
	z.update_hitboxes()
	var hp: float = z.health
	p.stamina = 100
	m.perform_attack(false)
	var during_windup := true
	while m.attacking and m.attack_time < m.active_windup:
		during_windup = during_windup and is_equal_approx(z.health, hp)
		await physics_frame
	var froze := false
	while m.attacking:
		froze = froze or m.freeze_left > 0.0
		await physics_frame
	check(during_windup, "Nessun danno durante la carica del colpo")
	# 25 al corpo, ×1,3 al collo, ×2,5 alla testa (il colpo dall'alto del kit arriva spesso sulla testa).
	var dealt: float = hp - z.health
	check(z.dead or is_equal_approx(dealt, 25.0) or is_equal_approx(dealt, 32.5) or is_equal_approx(dealt, 62.5), "Fendente leggero: 25 danni, più alla testa e al collo (%.1f)" % dealt)
	check(froze, "Hit-stop all'impatto")
	check(z.reaction == "hit_left" or z.reaction_time > 0.0, "Il primo fendente fa barcollare lo zombie di lato")
	# Calcio automatico sotto 1 m.
	await create_timer(1.0).timeout
	z.global_position = p.global_position + Vector3(0, 0, -0.8)
	z.reaction = ""
	z.stagger = 0.0
	z.health = z.max_health        # il fendente può aver preso la testa: il calcio non deve finirlo
	await frames(2)
	z.update_hitboxes()
	var before: Vector3 = z.global_position
	p.stamina = 100
	m.begin_charge()
	check(m.attacking and m.attack_clip == "Kick", "Zombie a meno di 1 m: calcio frontale")
	z.set_physics_process(true)
	while m.attacking: await physics_frame
	await create_timer(0.7).timeout
	var pushed: float = Vector2(z.global_position.x - before.x, z.global_position.z - before.z).length()
	check(z.reaction == "pushed" or pushed > 1.0, "Il calcio lo respinge (%.2f m)" % pushed)
	check(pushed > 1.1 and pushed < 2.0, "Il calcio lo riporta a distanza d'ascia (circa 1,5 m)")
	# Parata.
	p.health = 100
	m.blocking = true
	p.take_damage(20)
	check(is_equal_approx(p.health, 95.0), "Parata: il colpo fa un quarto del danno")
	m.blocking = false
	# Pala: stesso rig, modello diverso.
	p.equipped = "machete"
	await create_timer(0.3).timeout
	check(vm.weapon == "machete" and vm.item != null, "Il machete usa le stesse braccia con il suo modello e le sue clip")
	print("MELEE OVERHAUL ", "PASS" if failures == 0 else "FAIL", " (%d errori)" % failures)
	quit(failures)
