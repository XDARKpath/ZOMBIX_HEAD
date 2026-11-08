extends SceneTree
# Il tavolo dà davvero le armi, ogni arma da fuoco fa quello che dice, la fisica regge.
#   godot --path . --resolution 1280x720 -s res://tests/weapon_table_checks.gd
var fails := 0
var melee: Node
const Arsenal := preload("res://weapons/zx_arsenal.gd")


func _init() -> void:
	call_deferred("_run")


func check(good: bool, what: String) -> void:
	print("PASS " if good else "FAIL ", what)
	if not good: fails += 1


func _run() -> void:
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	world.spawner.set_process(false)
	var p: CharacterBody3D = world.player
	melee = p.melee
	var me: int = 1
	var table: Node3D = world.weapon_table
	p.global_position = table.global_position + Vector3(2.0, 0.1, 0)
	await create_timer(0.3).timeout
	check(table.ORDER.size() == 32, "Sul tavolo ci sono 32 armi")
	check(world.survival.act(me, "table:katana") and p.equipped == "katana", "Dal tavolo si prende la katana")
	for id in ["machete", "lmg", "pump_shotgun", "sniper_rifle", "crowbar"]:
		await create_timer(0.1).timeout
		check(world.survival.act(me, "table:" + id) and p.equipped == id, "Con le tasche piene si prende anche " + id)
	p.global_position = Vector3(200, 0.1, 200)
	check(not world.survival.act(me, "table:katana") or p.owned.has("katana"), "Da lontano il tavolo non dà niente di nuovo")
	# Differenze vere fra le armi.
	check(Arsenal.gun("pump_shotgun").pellets == 8, "Il fucile a pompa spara 8 pallini")
	check(Arsenal.gun("sniper_rifle").dmg > Arsenal.gun("smg").dmg * 5.0, "Il precisione fa molto più male del mitra")
	check(Arsenal.gun("smg").wait < Arsenal.gun("revolver").wait, "Il mitra è più rapido del revolver")
	check(Arsenal.gun("leaf_blower").dmg == 0.0, "Il soffiatore non fa danno")
	# Bersaglio vero.
	p.reset_at(Vector3(30, 0.3, -30))
	p.set_physics_process(true)
	p.controls_enabled = true
	p.rig.controls_enabled = false
	p.rig.pitch = -0.085          # al petto: dritti si passerebbe sopra un infetto curvo
	p.rig.yaw = 0.0
	for e in world.targets:
		if is_instance_valid(e): e.queue_free()
	await process_frame
	var near: Node3D = world._spawn_enemy(p.global_position + Vector3(0, 0, -6), 700)
	near.set_physics_process(false)
	near.global_position = p.global_position + Vector3(0, 0, -6)
	near.health = 1000.0
	near.max_health = 1000.0
	var second: Node3D = world._spawn_enemy(p.global_position + Vector3(3, 0, -7), 701)
	second.set_physics_process(false)
	second.global_position = p.global_position + Vector3(3, 0, -7)
	second.health = 1000.0
	second.max_health = 1000.0
	await create_timer(0.5).timeout
	var shoot := func(id: String) -> void:
		p.owned.assign([id])
		p.hotbar[0] = id
		p.equip_id(id)
		p.magazine = 10
		near.update_hitboxes()
		second.update_hitboxes()
		p.rig.pitch = -0.085      # il rinculo del colpo prima ha alzato la mira
		p.melee.perform_attack(false)
	await _shot(shoot, "pistol")
	var after_pistol: float = near.health
	check(after_pistol < 1000.0, "La pistola colpisce (%.0f)" % after_pistol)
	check(p.melee.last_ends.size() == 1, "La pistola spara un colpo")
	await _shot(shoot, "pump_shotgun")
	check(p.melee.last_ends.size() == 8, "Il fucile a pompa disegna 8 scie")
	var before_chain: float = second.health
	near.health = 1000.0
	await _shot(shoot, "tesla_rifle")
	await create_timer(0.1).timeout
	check(second.health < before_chain, "Il fulmine salta sull'altro infetto (%.0f)" % second.health)
	near.health = 1000.0
	await _shot(shoot, "flare_gun")
	var burning: float = near.health
	await create_timer(1.5).timeout
	check(near.health < burning, "Il razzo lascia il bersaglio in fiamme (%.0f -> %.0f)" % [burning, near.health])
	near.health = 1000.0
	second.health = 1000.0
	await _shot(shoot, "grenade_launcher")
	await create_timer(1.5).timeout
	check(near.health < 1000.0 or second.health < 1000.0, "La granata esplode (%.0f, %.0f)" % [near.health, second.health])
	# Prestazioni: quanto pesa la fisica con i tronchi solidi.
	var sum := 0.0
	var frames := 0
	for i in 120:
		await process_frame
		sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		frames += 1
	print("FISICA %.2f ms a giro, corpi attivi %d, FPS %d" % [sum / frames * 1000.0, Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Engine.get_frames_per_second()])
	print("TAVOLO: ", fails, " errori")
	quit(1 if fails > 0 else 0)


func _shot(shoot: Callable, id: String) -> void:
	await create_timer(1.4).timeout      # la pausa dell'arma di prima: il fucile a pompa ci mette quasi un secondo
	shoot.call(id)
	# Il colpo parte alla fine della carica: si aspetta quello, non un tempo fisso, che sotto carico non basta.
	var limit := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < limit and not melee._shot_done:
		await process_frame
	await create_timer(0.05).timeout
