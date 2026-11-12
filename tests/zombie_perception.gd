extends SceneTree
# Percezione degli infetti: niente telepatia dietro i muri, ricerca attorno all'ultima posizione nota,
# il rumore li riporta sulla pista, una cassetta in mezzo non basta a far perdere l'inseguimento.
#   godot --path . --headless --fixed-fps 60 -s res://tests/zombie_perception.gd
var world: Node3D
var fails := 0
const AT := Vector3(400, 200, 400)
var stage: Array = []
var p: CharacterBody3D


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


func clear() -> void:
	for b in stage: b.queue_free()
	stage.clear()


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails += 1


func zombie(at: Vector3) -> Node3D:
	var e: Node3D = world._spawn_enemy(AT + at, 900 + stage.size())
	e.global_position = AT + at
	e.set_kind(0)
	e.home = e.global_position
	e.spit_cooldown = 999.0
	e.leap_cooldown = 999.0
	return e


func wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await physics_frame
		t += Engine.time_scale / 60.0
		p.health = 100.0


func put_player(at: Vector3) -> void:
	p.global_position = AT + at
	p.velocity = Vector3.ZERO


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
	p = world.player
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
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 3.0

	# 1. Dietro un muro alto, fermo e in silenzio: chi vaga dall'altra parte non lo nota.
	wall(Vector3(14, 3.5, 0.5), Vector3(0, 0, -4))
	put_player(Vector3(0, 0.1, 0))
	var a := zombie(Vector3(0, 0.15, -8))
	a.rotation.y = PI          # guarda verso il muro e il giocatore
	await wait(8.0)
	check(a.state == a.State.WANDER, "dietro il muro non ti vede (stato %d)" % a.state)
	a.queue_free()
	clear()

	# 2. Ti vede, ti insegue, tu sparisci dietro un muro lontano: va dove ti ha visto, cerca lì attorno, poi molla.
	put_player(Vector3(0, 0.1, 0))
	var b := zombie(Vector3(0, 0.15, -6))
	b.rotation.y = PI
	await wait(1.0)
	check(b.state == b.State.CHASE, "in vista ti insegue (stato %d)" % b.state)
	var seen_at: Vector3 = p.global_position
	wall(Vector3(0.5, 3.5, 12), Vector3(-10, 0, 0))
	wall(Vector3(12, 3.5, 0.5), Vector3(-16, 0, -6))
	await physics_frame                         # i muri entrano nello spazio fisico al tick dopo
	await physics_frame
	put_player(Vector3(-16, 0.1, 0))           # dietro l'angolo, a 16 m, senza far rumore
	await wait(4.0)
	check(b.last_seen.distance_to(seen_at) < 1.0, "senza vederti non sa dove sei andato (ultima posizione nota a %.1f m da dove ti ha visto)" % b.last_seen.distance_to(seen_at))
	var closest := INF
	var t := 0.0
	while t < 24.0 and b.state == b.State.CHASE:
		await wait(0.25)
		t += 0.25
		closest = minf(closest, b.global_position.distance_to(p.global_position))
	check(closest > 5.0, "non ti segue a naso dietro l'angolo (arrivato a %.1f m)" % closest)
	check(b.state == b.State.WANDER, "dopo aver cercato smette (stato %d dopo %.0f s)" % [b.state, t])
	check(b.get("searched") != null and int(b.searched) > 0, "ha cercato attorno all'ultima posizione (%s punti)" % str(b.get("searched")))

	# 3. Il rumore lo riporta sulla pista (uno sparo dietro il muro).
	b.hear(p, 45.0)
	await wait(0.5)
	check(b.state == b.State.CHASE and b.last_seen.distance_to(p.global_position) < 1.0, "lo sparo lo rimette sulle tue tracce")
	b.queue_free()
	clear()

	# 4. Una cassetta bassa in mezzo non gli fa perdere l'inseguimento.
	put_player(Vector3(0, 0.1, 0))
	wall(Vector3(0.6, 0.6, 0.6), Vector3(0, 0, -4))
	var c := zombie(Vector3(0, 0.15, -9))
	c.rotation.y = PI
	await wait(1.0)
	var moves := 0
	for i in 6:
		put_player(Vector3(float(i % 2) * 1.5 - 0.75, 0.1, 0))
		await wait(1.0)
		if c.state == c.State.CHASE and c.last_seen.distance_to(p.global_position) < 1.0: moves += 1
	check(moves >= 5, "con una cassetta in mezzo ti tiene d'occhio (%d/6)" % moves)
	c.queue_free()

	Engine.time_scale = 1.0
	print("PERCEZIONE: ", fails, " errori")
	quit(1 if fails > 0 else 0)
