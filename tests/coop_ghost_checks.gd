extends SceneTree
# Ospite che cade (processo ucciso, niente leave) durante la riparazione del 4×4, due processi veri.
# Prima: il corpo restava valido 7–11 s e completava la riparazione 5 s dopo la caduta.
# Ora: la riparazione si ferma entro ~1 s, non si completa, l'ospite esce dalla partita entro ~7 s,
# e poi l'host ripara da solo.
# godot --path . --headless -s res://tests/coop_ghost_checks.gd -- --ghost-host
# godot --path . --headless -s res://tests/coop_ghost_checks.gd -- --ghost-client
const PORT := 27861
const MARK := "user://coop_ghost_kill.txt"
var world: Node3D


func _initialize() -> void:
	call_deferred("run")


func now() -> float:
	return Time.get_unix_time_from_system() * 1000.0


func wait_s(s: float) -> void:
	await create_timer(s, true).timeout


func run() -> void:
	var session: Node = root.get_node("Session")
	var hosting: bool = "--ghost-host" in OS.get_cmdline_user_args()
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
			print("GHOST_HOST lobby incompleta"); quit(1); return
		session.launch()
	else:
		session.profile("GHOST", 0)
		session.join("127.0.0.1", PORT)
		paused = false
		await wait_s(2.0)
		session.set_ready(true)
		await session.game_started
	await wait_s(1.5)
	world.spawner.set_process(false)
	var campaign: Node3D = world.expedition
	var car: CharacterBody3D = campaign.car
	if not hosting:
		while campaign.stage != 1: await wait_s(0.1)
		await wait_s(0.5)
		campaign.request_use()
		await wait_s(3.0)
		var f := FileAccess.open(MARK, FileAccess.WRITE); f.store_string(str(now())); f.close()
		OS.kill(OS.get_process_id())
		return
	for e in world.targets:
		if is_instance_valid(e): e.set_physics_process(false); e.global_position += Vector3(0, -400, 0)
	var guest_id := 0
	for id in world.actors:
		if world.actors[id] != world.player: guest_id = id
	campaign.collected = [true, true, true]; campaign.stage = 1; car.repaired = false; campaign.repairing_peer = 0; campaign.hold = 8
	campaign._publish(); car.publish()
	world.actors[guest_id].position = car.to_global(Vector3(2.2, 0.3, 0)); world.actors[guest_id].velocity = Vector3.ZERO
	world.player.reset_at(car.to_global(Vector3(0, 0.3, 14)))
	var end := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < end and not FileAccess.file_exists(MARK): await process_frame
	if not FileAccess.file_exists(MARK):
		print("GHOST_HOST il client non ha mai iniziato"); quit(1); return
	var killed := float(FileAccess.get_file_as_string(MARK))
	var started: bool = campaign.repairing_peer == guest_id and campaign.hold < 8.0
	var paused_at := -1.0
	var gone_at := -1.0
	var last_hold: float = campaign.hold
	var completed := false
	end = Time.get_ticks_msec() + 14000
	while Time.get_ticks_msec() < end:
		await wait_s(0.1)
		if campaign.stage != 1 or car.repaired: completed = true
		if paused_at < 0.0 and is_equal_approx(campaign.hold, last_hold): paused_at = now() - killed
		last_hold = campaign.hold
		if gone_at < 0.0 and not world.actors.has(guest_id): gone_at = now() - killed
	var left: float = campaign.hold
	world.player.reset_at(car.to_global(Vector3(2.2, 0.3, 0)))
	await wait_s(0.3)
	campaign.request_use()
	await wait_s(left + 1.0)
	var resumed: bool = car.repaired and campaign.stage == 2
	var checks := {
		"riparazione avviata dall'ospite": started,
		"nessun completamento fantasma (14 s)": not completed,
		"lavoro in pausa entro 1,3 s (%.0f ms)" % paused_at: paused_at >= 0.0 and paused_at <= 1300.0,
		"ospite fuori dalla partita entro 7,5 s (%.0f ms)" % gone_at: gone_at >= 0.0 and gone_at <= 7500.0,
		"l'host ripara da solo dopo la caduta": resumed,
	}
	var good := true
	for name in checks:
		print("GHOST_HOST ", "PASS " if checks[name] else "FAIL ", name)
		good = good and checks[name]
	session.leave()
	quit(0 if good else 1)
