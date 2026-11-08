extends SceneTree
# Online con due processi veri: il Capomacello evocato dall'host si vede, ha la barra e paga anche sul client.
# godot --path . -s res://tests/boss_coop_check.gd -- --coop-host
# godot --path . -s res://tests/boss_coop_check.gd -- --coop-client
var world: Node3D


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var session: Node = root.get_node("Session")
	var hosting: bool = "--coop-host" in OS.get_cmdline_user_args()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	var good := true
	if hosting:
		session.host(27853)
		paused = false
		var deadline := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline and not (session.roster.size() == 2 and session.roster.values().all(func(member): return member.ready)):
			await create_timer(0.2, true).timeout
		if session.roster.size() != 2:
			print("COOP_HOST lobby incompleta")
			quit(1)
			return
		session.launch()
	else:
		session.profile("COOP", 0)
		session.join("127.0.0.1", 27853)
		paused = false
		await create_timer(2.0, true).timeout
		session.set_ready(true)
		await session.game_started
	await create_timer(1.5, true).timeout
	world.spawner.set_process(false)
	var altar: Vector3 = world.boss_hunt.esche[0].global_position
	if hosting:
		# L'host porta tutti all'altare e accende l'esca.
		world.quest.stage = world.quest.FOREST_BOSS
		world.quest._publish()
		world.player.baits = 1
		world.terrain.ensure_near([altar])
		world.player.reset_at(altar + Vector3(1.0, 0.5, 0))
		for id in world.actors:
			if world.actors[id] != world.player: world.actors[id].reset_at(altar + Vector3(-6.0, 0.5, 4.0))
		await create_timer(1.0, true).timeout
		good = world.boss_hunt.try_summon(world.player)
		print("COOP_HOST evocato ", good)
	await create_timer(5.0, true).timeout
	# Su tutti e due: il boss c'è e la barra lo trova.
	var boss: Node3D = world.boss_hunt.active_boss()
	var seen: bool = is_instance_valid(boss) and String(boss.title).length() > 0
	print("%s barra del boss: %s" % ["COOP_HOST" if hosting else "COOP_CLIENT", boss.title if seen else "NESSUNA"])
	good = good and seen
	var money: int = world.player.credits
	if hosting and seen:
		boss.receive_hit("torso", 1000000.0, Vector3.ZERO, "axe", true)
	await create_timer(4.0, true).timeout
	var stage_ok: bool = world.quest.stage == world.quest.BRING_FOREST
	var paid: bool = world.player.credits >= money + 150
	print("%s storia %d (attesa %d) · crediti %d -> %d" % ["COOP_HOST" if hosting else "COOP_CLIENT", world.quest.stage, world.quest.BRING_FOREST, money, world.player.credits])
	good = good and stage_ok and paid
	print("%s valido %s" % ["COOP_HOST" if hosting else "COOP_CLIENT", good])
	await create_timer(3.0 if hosting else 1.0, true).timeout
	session.leave()
	world.queue_free()
	await process_frame
	quit(0 if good else 1)
