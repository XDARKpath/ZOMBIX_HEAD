extends SceneTree
# Online con due processi veri: due giocatori lontani, ognuno vede il terreno attorno a sé e l'host lo tiene per tutti.
# godot --headless --path . -s res://tests/map_coop_check.gd -- --coop-host
# godot --headless --path . -s res://tests/map_coop_check.gd -- --coop-client
const TILE := 128
const HOST_AT := Vector3(1600, 0, -2000)
const CLIENT_AT := Vector3(3200, 0, -3200)
var world: Node3D


func _initialize() -> void:
	call_deferred("run")


func ring(at: Vector3, radius: int) -> bool:
	var center := Vector2i(floori(at.x / TILE), floori(at.z / TILE))
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			if not world.terrain.tiles.has(center + Vector2i(x, z)): return false
	return true


func floor_under(at: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 200.0, at + Vector3.DOWN * 60.0, 1)
	return not root.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func go_to(at: Vector3) -> void:
	var y: float = world.terrain.height(at.x, at.z)
	world.terrain.ensure_near([at])
	world.player.reset_at(Vector3(at.x, y + 0.5, at.z))


func run() -> void:
	var session: Node = root.get_node("Session")
	var hosting: bool = "--coop-host" in OS.get_cmdline_user_args()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	var good := true
	if hosting:
		session.host(27851)
		paused = false
		var deadline := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline and not (session.roster.size() == 2 and session.roster.values().all(func(member): return member.ready)):
			await create_timer(0.2, true).timeout
		good = session.roster.size() == 2
		if not good:
			print("COOP_HOST lobby incompleta")
			quit(1)
			return
		session.launch()
	else:
		session.profile("COOP", 0)
		session.join("127.0.0.1", 27851)
		paused = false
		await create_timer(2.0, true).timeout
		session.set_ready(true)
		await session.game_started
	await create_timer(1.0, true).timeout
	world.spawner.set_process(false)
	# Comanda l'host: sposta se stesso e l'altro giocatore, il client riceve la posizione.
	if hosting:
		go_to(HOST_AT)
		for id in world.actors:
			if world.actors[id] != world.player:
				world.actors[id].reset_at(Vector3(CLIENT_AT.x, world.terrain.height(CLIENT_AT.x, CLIENT_AT.z) + 0.5, CLIENT_AT.z))
	await create_timer(8.0, true).timeout
	var me: Vector3 = world.player.global_position
	var mine: Vector3 = HOST_AT if hosting else CLIENT_AT
	good = me.distance_to(Vector3(mine.x, me.y, mine.z)) < 12.0
	good = good and ring(me, 2) and floor_under(me)
	if hosting:
		# L'host simula tutti: deve avere il terreno anche attorno all'altro giocatore.
		var other_ok := false
		for id in world.actors:
			if world.actors[id] != world.player:
				var other: Vector3 = world.actors[id].global_position
				print("COOP_HOST altro giocatore a ", other)
				other_ok = other.distance_to(Vector3(CLIENT_AT.x, other.y, CLIENT_AT.z)) < 12.0 and ring(other, 2) and floor_under(other)
		good = good and other_ok
		print("COOP_HOST pos ", me, " tessere ", world.terrain.tiles.size(), " valido ", good)
		await create_timer(2.0, true).timeout
	else:
		print("COOP_CLIENT pos ", me, " tessere ", world.terrain.tiles.size(), " valido ", good)
		await create_timer(4.0, true).timeout
	session.leave()
	world.queue_free()
	await process_frame
	quit(0 if good else 1)
