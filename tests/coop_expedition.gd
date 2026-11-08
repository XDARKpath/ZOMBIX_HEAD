# Prova con processi distinti: l'host posiziona la squadra, i client interagiscono via RPC.
extends Node
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds,true).timeout
func run(world: Node3D, hosting: bool) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	if hosting:
		Session.host(27846)
		await wait(5)
		Session.launch()
		await wait(0.5)
		for enemy in world.targets: enemy.set_physics_process(false)
		for actor in world.actors.values(): actor.set_physics_process(false)
		for point in world.expedition.POINTS:
			for actor in world.actors.values(): actor.position = point+Vector3(0,0.1,1.5)
			await wait(1.5)
		for actor in world.actors.values(): actor.position = world.expedition.RADIO+Vector3(0,0.1,1.5)
		await wait(1.5)
		var activated: bool = world.expedition.stage==2
		world.expedition.hold = 0.1
		await wait(0.5)
		var success: bool = activated and world.expedition.stage==3 and world.expedition.collected.count(true)==3 and world.actors.size()==4
		print("EXP_HOST completed=",success," stage=",world.expedition.stage," members=",world.actors.size())
		await wait(2)
		Session.leave()
		get_tree().quit(0 if success else 1)
	else:
		Session.profile("Scout%d"%OS.get_process_id(),OS.get_process_id()%3)
		Session.join("127.0.0.1",27846)
		await wait(1.5)
		Session.set_ready(true)
		await Session.game_started
		world.player.set_physics_process(false)
		var elapsed := 0.0
		while elapsed<13 and world.expedition.stage!=3:
			await wait(0.15)
			elapsed += 0.15
			if world.expedition.stage<2 and not world.expedition.prompt().is_empty(): world.expedition.request_use()
		var success: bool = world.expedition.stage==3 and world.expedition.collected.count(true)==3 and world.actors.size()==4 and world.expedition.broadcast_count>10
		print("EXP_CLIENT completed=",success," updates=",world.expedition.broadcast_count," members=",world.actors.size())
		await wait(0.6)
		Session.leave()
		get_tree().quit(0 if success else 1)
