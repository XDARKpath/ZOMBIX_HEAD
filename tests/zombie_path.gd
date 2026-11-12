extends SceneTree
# Gli infetti arrivano sempre: muretto da scavalcare, muro alto da aggirare, trappola a U, bosco fitto, scalino, tronco addosso.
#   godot --path . --headless --fixed-fps 60 -s res://tests/zombie_path.gd
var world: Node3D
var fails := 0
const AT := Vector3(400, 200, 400)
const KINDS := {"infetto": 0, "corridore": 1, "bruto": 2, "boss": 5}
var stage: Array = []


func _init() -> void:
	call_deferred("_run")


func wall(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.global_position = AT + at + Vector3.UP * size.y * 0.5
	stage.append(body)


func trunk(at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = 0.38
	c.height = 5.0
	shape.shape = c
	body.add_child(shape)
	world.add_child(body)
	body.global_position = AT + at + Vector3.UP * 2.5
	stage.append(body)


func scene(name: String) -> void:
	for b in stage: b.queue_free()
	stage.clear()
	match name:
		"aperto": pass
		"muretto": wall(Vector3(12, 0.8, 0.5), Vector3(0, 0, -6))
		"muro_alto": wall(Vector3(9, 3.5, 0.6), Vector3(0, 0, -6))
		"muro_lungo": wall(Vector3(22, 3.5, 0.6), Vector3(0, 0, -6))
		"trappola_u":
			wall(Vector3(8, 3.5, 0.6), Vector3(0, 0, -5))
			wall(Vector3(0.6, 3.5, 6), Vector3(-4, 0, -8))
			wall(Vector3(0.6, 3.5, 6), Vector3(4, 0, -8))
		"bosco":
			var rng := RandomNumberGenerator.new()
			rng.seed = 77
			for i in 70: trunk(Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-13, -2)))
		"scalini":
			wall(Vector3(12, 0.5, 0.8), Vector3(0, 0, -4))
			wall(Vector3(12, 1.0, 0.8), Vector3(0, 0, -6))
			wall(Vector3(12, 0.5, 0.8), Vector3(0, 0, -8))
		"casse":
			for i in 7: wall(Vector3(1.2, 0.9, 1.2), Vector3(-6 + i * 2.0, 0, -6))


func _run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	world.spawner.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.queue_free()
	await process_frame
	var p: CharacterBody3D = world.player
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 2, 200)
	shape.shape = box
	ground.add_child(shape)
	world.add_child(ground)
	ground.global_position = AT + Vector3.DOWN
	p.reset_at(AT + Vector3(0, 0.2, 0))
	p.set_physics_process(false)
	p.global_position = AT + Vector3(0, 0.1, 0)
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 6.0
	for name in ["muretto", "scalini", "bosco", "muro_alto", "muro_lungo", "trappola_u"]:
		scene(name)
		await physics_frame
		await physics_frame
		for who in KINDS:
			var kind: int = KINDS[who]
			var start := Vector3(0, 0.15, -12)
			if name == "trappola_u": start = Vector3(0, 0.15, -8)
			if name == "bosco":
				start = Vector3(0.0, 0.15, -14.5)
			var e: Node3D = world._spawn_enemy(AT + start, 500 + kind)
			e.global_position = AT + start
			e.set_kind(kind)
			e.spit_cooldown = 999.0
			e.leap_cooldown = 999.0
			e.home = e.global_position
			e.hear(p, 60.0)
			var speed: float = float(e.CHASE_SPEED[kind])
			var limit: float = maxf(12.0, 26.0 / speed)
			var t := 0.0
			var arrived := false
			var y_max := -INF
			var jumps := 0                       # salti > 1,5 m in un tick = teletrasporto
			var last: Vector3 = e.global_position
			while t < limit:
				await physics_frame
				t += 1.0 / 60.0
				e.memory = 6.0 if e.memory < 6.0 else e.memory
				y_max = maxf(y_max, e.global_position.y - AT.y)
				if Vector2(e.global_position.x - last.x, e.global_position.z - last.z).length() > 1.5: jumps += 1
				last = e.global_position
				if Vector2(e.global_position.x - p.global_position.x, e.global_position.z - p.global_position.z).length() < 3.2:
					arrived = true
					break
			var good := arrived and jumps == 0
			print("PASS " if good else "FAIL ", name, " ", who, " in %.1f s, salito %.2f m, fine a %s, teletrasporti %d, sblocchi %s" % [t, y_max, str((e.global_position - AT).snappedf(0.1)), jumps, str(e.get("recoveries"))])
			if not good: fails += 1
			e.queue_free()
			await physics_frame
	Engine.time_scale = 1.0
	print("PERCORSI: ", fails, " errori")
	quit(1 if fails > 0 else 0)
