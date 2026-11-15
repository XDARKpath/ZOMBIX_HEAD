extends SceneTree
# 4×4 in rete con due processi veri: l'host guida fuori strada sui pendii, il client siede accanto e vede la carrozzeria
# inclinata come la vede l'host (stessa posizione sulla pista, stesso beccheggio e rollio).
# godot --headless --path . -s res://tests/ranger_coop_check.gd -- --coop-host
# godot --headless --path . -s res://tests/ranger_coop_check.gd -- --coop-client
const Route := preload("res://world/campaign/route.gd")
const PORT := 27853
const SHARED := "user://ranger_coop_host.json"
var Terrain: GDScript
var world: Node3D
var car: CharacterBody3D


func _initialize() -> void:
	call_deferred("run")


## Come in vehicle_terrain_checks.gd: tratti in pendenza lontano dalla statale, da guidare di sbieco.
func slope_lines() -> Array:
	var out: Array = []
	var road: Array = Route.road_points()
	var walked := 0.0
	for i in range(road.size() - 1):
		var a: Vector3 = road[i]
		var b: Vector3 = road[i + 1]
		var n := int((walked + a.distance_to(b)) / 60.0) - int(walked / 60.0)
		walked += a.distance_to(b)
		for k in n:
			var at: Vector3 = a.lerp(b, (float(k) + 0.5) / n)
			if walked < 200.0 or at.z < Route.WALL_Z + 150.0: continue
			var side := (b - a).normalized().cross(Vector3.UP)
			for d in [40.0, 70.0, -40.0, -70.0]:
				var q: Vector3 = at + side * d
				var g := Vector2(Terrain.ground_height(q.x + 3, q.z) - Terrain.ground_height(q.x - 3, q.z), Terrain.ground_height(q.x, q.z + 3) - Terrain.ground_height(q.x, q.z - 3)) / 6.0
				if g.length() < 0.15 or g.length() > 0.4: continue
				var dir := Vector3(g.x, 0, g.y).normalized().rotated(Vector3.UP, PI / 4)
				var end := q + dir * 40.0
				if Route.road_distance(Vector2(end.x, end.z)) < 14.0 or Route.road_distance(Vector2(q.x, q.z)) < 14.0 or not Route.inside(end): continue
				out.append([q, atan2(-dir.x, -dir.z)])
				break
			if out.size() >= 3: return out
	return out


func sample() -> Array:
	return [car.global_position.x, car.global_position.z, car.visual.rotation.x, car.visual.rotation.z]


func run() -> void:
	var session: Node = root.get_node("Session")
	var hosting: bool = "--coop-host" in OS.get_cmdline_user_args()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	Terrain = load("res://world/campaign/terrain.gd")
	var good := true
	if hosting:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SHARED))
		session.host(PORT)
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
		session.join("127.0.0.1", PORT)
		paused = false
		await create_timer(2.0, true).timeout
		session.set_ready(true)
		await session.game_started
	await create_timer(1.0, true).timeout
	world.spawner.set_process(false)
	car = world.expedition.car
	var mine: Array = []
	if hosting:
		for e in world.targets:
			if is_instance_valid(e): e.set_physics_process(false); e.global_position += Vector3(0, -300, 0)
		world.expedition.collected = [true, true, true]; world.expedition.stage = 2
		car.repaired = true
		var guest := 0
		for id in world.actors:
			if world.actors[id] != world.player: guest = id
		world.player.reset_at(car.to_global(Vector3(-2.0, 0.3, 0)))
		world.actors[guest].reset_at(car.to_global(Vector3(2.0, 0.3, 0)))
		await create_timer(0.5, true).timeout
		var seated: bool = car.interact(1) and car.interact(guest)
		print("COOP_HOST a bordo: ", seated, " posti ", car.seats)
		good = seated
		await create_timer(2.0, true).timeout
		var lines := slope_lines()
		for line in lines:
			var at: Vector3 = line[0]
			world.terrain.ensure_near([at])
			car.position = Vector3(at.x, Terrain.ground_height(at.x, at.z) + 0.3, at.z)
			car.rotation.y = line[1]; car.speed = 0.0; car.velocity = Vector3.ZERO
			await create_timer(1.5, true).timeout
			Input.action_press("move_forward", 0.6)
			for i in 200:
				car.rotation.y = line[1]
				await physics_frame
				if absf(car.speed) > 3.0: mine.append(sample())
			Input.action_release("move_forward")
			await create_timer(1.0, true).timeout
		var file := FileAccess.open(SHARED, FileAccess.WRITE)
		file.store_string(JSON.stringify(mine))
		file.close()
		print("COOP_HOST %d tratti, %d campioni scritti" % [lines.size(), mine.size()])
		good = good and lines.size() >= 2 and mine.size() > 200
		await create_timer(8.0, true).timeout
	else:
		# Il client registra quello che vede finché l'host non ha scritto i suoi campioni.
		var deadline := Time.get_ticks_msec() + 90000
		var seated_seen := false
		while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(SHARED):
			await physics_frame
			seated_seen = seated_seen or world.player.seated
			if absf(car.speed) > 3.0: mine.append(sample())
		await create_timer(0.5, true).timeout
		var host: Array = JSON.parse_string(FileAccess.get_file_as_string(SHARED)) if FileAccess.file_exists(SHARED) else []
		var diffs: Array = []
		var tilt := 0.0
		for c in mine:
			var best := INF
			var match_row: Array = []
			for h in host:
				var d: float = Vector2(c[0] - h[0], c[1] - h[1]).length()
				if d < best: best = d; match_row = h
			tilt = maxf(tilt, maxf(absf(c[2]), absf(c[3])))
			if best < 0.3: diffs.append(maxf(absf(c[2] - match_row[2]), absf(c[3] - match_row[3])))
		diffs.sort()
		var p90: float = diffs[int(diffs.size() * 0.9)] if not diffs.is_empty() else INF
		var worst: float = diffs[-1] if not diffs.is_empty() else INF
		good = seated_seen and diffs.size() > 150 and tilt > 0.1 and p90 < 0.04 and worst < 0.12
		print("COOP_CLIENT seduto %s, %d campioni, %d confrontati con l'host, inclinazione massima %.2f rad, scarto p90 %.3f max %.3f rad, valido %s" % [seated_seen, mine.size(), diffs.size(), tilt, p90, worst, good])
		await create_timer(2.0, true).timeout
	session.leave()
	world.queue_free()
	await process_frame
	quit(0 if good else 1)
