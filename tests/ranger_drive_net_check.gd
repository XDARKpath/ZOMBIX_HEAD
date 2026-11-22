extends SceneTree
# 4×4 guidato da un ospite, due processi veri: l'ospite simula il 4×4 da sé (sterzo e gas visti entro pochi passi
# fisici, come l'host), l'host riceve gli stati e li accetta, poi l'ospite cade (processo ucciso a 24 m/s):
# l'host riprende il 4×4 entro 0,5 s, lo ferma in folle entro 3 s e libera il posto.
# godot --path . --headless -s res://tests/ranger_drive_net_check.gd -- --drive-host
# godot --path . --headless -s res://tests/ranger_drive_net_check.gd -- --drive-client
const PORT := 27863
const MARK := "user://ranger_drive_net.json"
var world: Node3D
var car: CharacterBody3D


func _initialize() -> void:
	call_deferred("run")


func wait_s(s: float) -> void:
	await create_timer(s, true).timeout


func keys(fwd: bool, left: bool) -> void:
	for a in ["move_forward", "move_left"]: Input.action_release(a)
	if fwd: Input.action_press("move_forward")
	if left: Input.action_press("move_left")


func run() -> void:
	var session: Node = root.get_node("Session")
	var hosting: bool = "--drive-host" in OS.get_cmdline_user_args()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	if hosting:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARK))
		session.host(PORT)
		paused = false
		var end := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < end and not (session.roster.size() == 2 and session.roster.values().all(func(m): return m.ready)):
			await wait_s(0.2)
		if session.roster.size() != 2:
			print("DRIVE_HOST lobby incompleta"); quit(1); return
		session.launch()
	else:
		session.profile("DRIVER", 0)
		session.join("127.0.0.1", PORT)
		paused = false
		await wait_s(2.0)
		session.set_ready(true)
		await session.game_started
	await wait_s(1.5)
	world.spawner.set_process(false)
	car = world.expedition.car
	if hosting: await host_flow()
	else: await client_flow()


func host_flow() -> void:
	var Route := load("res://world/campaign/route.gd")
	for e in world.targets:
		if is_instance_valid(e): e.set_physics_process(false); e.global_position += Vector3(0, -400, 0)
	var guest := 0
	for id in world.actors:
		if world.actors[id] != world.player: guest = id
	world.expedition.collected = [true, true, true]; world.expedition.stage = 2; car.repaired = true
	var road: Vector3 = Route.nearest_road(Vector3(40, 0, -320))
	var dir: Vector3 = Route.road_direction(road)
	world.terrain.ensure_near([road])
	await wait_s(0.5)
	car.position = road + Vector3.UP * 0.3; car.rotation.y = atan2(-dir.x, -dir.z); car.speed = 0.0; car.velocity = Vector3.ZERO
	car.safe_position = car.position; car.server_position = car.position
	await wait_s(0.5)
	world.actors[guest].position = car.to_global(Vector3(-2.2, 0.3, 0)); world.actors[guest].velocity = Vector3.ZERO
	world.player.reset_at(car.to_global(Vector3(2.2, 0.3, 0)))
	var end := Time.get_ticks_msec() + 15000
	while car.seats[0] != guest and Time.get_ticks_msec() < end: await process_frame
	car.interact(1)
	var start: Vector3 = car.position
	var states := 0; var driven := 0; var frames := 0
	var killed_at := -1.0; var resumed_at := -1.0; var stopped_at := -1.0; var freed_at := -1.0
	end = Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < end:
		await physics_frame
		var t := Time.get_ticks_msec() / 1000.0
		if killed_at < 0.0:
			frames += 1
			if car.driver_clock < 0.3: driven += 1
			if FileAccess.file_exists(MARK): killed_at = t
		else:
			if resumed_at < 0.0 and car.driver_clock >= 0.3: resumed_at = t
			if stopped_at < 0.0 and absf(car.speed) < 1.0: stopped_at = t
			if freed_at < 0.0 and car.seats[0] != guest: freed_at = t
			if freed_at > 0.0 and stopped_at > 0.0: break
	var client: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MARK)) if FileAccess.file_exists(MARK) else {}
	var moved := start.distance_to(car.position)
	var checks := {
		"l'ospite guida: sterzo visto da lui in %s passi fisici (≤ 3)" % client.get("steer_steps", "?"): int(client.get("steer_steps", 99)) <= 3,
		"l'ospite guida: gas visto da lui in %s passi fisici (≤ 2)" % client.get("gas_steps", "?"): int(client.get("gas_steps", 99)) <= 2,
		"l'ospite arriva a %.1f m/s senza correzioni (%s)" % [float(client.get("top", 0)), client.get("corrections", "?")]: float(client.get("top", 0)) > 20.0 and int(client.get("corrections", 1)) == 0,
		"l'host segue la guida dell'ospite (%d%% dei passi, %.0f m)" % [100 * driven / maxi(frames, 1), moved]: driven > frames * 0.8 and moved > 40.0,
		"caduta: l'host riprende il 4×4 in %.2f s (≤ 0,5)" % (resumed_at - killed_at): killed_at > 0.0 and resumed_at > 0.0 and resumed_at - killed_at <= 0.5,
		"caduta: 4×4 fermo in %.2f s (≤ 3)" % (stopped_at - killed_at): stopped_at > 0.0 and stopped_at - killed_at <= 3.0,
		"caduta: posto di guida liberato in %.1f s (≤ 9, timeout ENet 6 s)" % (freed_at - killed_at): freed_at > 0.0 and freed_at - killed_at <= 9.0,
	}
	var good := true
	for name in checks:
		print("DRIVE_HOST ", "PASS " if checks[name] else "FAIL ", name)
		good = good and checks[name]
	root.get_node("Session").leave()
	quit(0 if good else 1)


func client_flow() -> void:
	var me := root.multiplayer.get_unique_id()
	while not (car.repaired and world.player.position.distance_to(car.position) < 3.0): await process_frame
	await wait_s(0.3)
	world.expedition.request_use()
	var end := Time.get_ticks_msec() + 10000
	while car.seats[0] != me and Time.get_ticks_msec() < end: await process_frame
	await wait_s(1.0)
	var corrections := 0
	var start: Vector3 = car.position
	keys(true, false)
	var gas_steps := 0
	while car.position.distance_to(start) < 0.001 and gas_steps < 60: await physics_frame; gas_steps += 1
	await wait_s(3.5)
	var yaw: float = car.rotation.y
	keys(true, true)
	var steer_steps := 0
	while absf(wrapf(car.rotation.y - yaw, -PI, PI)) < 0.002 and steer_steps < 60: await physics_frame; steer_steps += 1
	await wait_s(0.6)
	keys(true, false)
	var top := 0.0
	var last: Vector3 = car.position
	for i in 120:
		await physics_frame
		top = maxf(top, car.speed)
		if car.position.distance_to(last) > 2.0: corrections += 1
		last = car.position
	var f := FileAccess.open(MARK, FileAccess.WRITE)
	f.store_string(JSON.stringify({"gas_steps": gas_steps, "steer_steps": steer_steps, "top": top, "corrections": corrections}))
	f.close()
	OS.kill(OS.get_process_id())
