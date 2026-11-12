extends SceneTree
# Sblocco misurato: percorsi raggiungibili e non, zombie da soli e in gruppo.
# Per ognuno conta: arrivo, teletrasporti (salti > 1,5 m in un tick), muri attraversati, inversioni avanti/indietro, passi di sblocco usati.
#   godot --path . --headless --fixed-fps 60 -s res://tests/zombie_recovery.gd
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


func build(name: String) -> void:
	for b in stage: b.queue_free()
	stage.clear()
	match name:
		"muro_lungo": wall(Vector3(22, 3.5, 0.6), Vector3(0, 0, -6))
		"trappola_u":
			wall(Vector3(8, 3.5, 0.6), Vector3(0, 0, -5))
			wall(Vector3(0.6, 3.5, 6), Vector3(-4, 0, -8))
			wall(Vector3(0.6, 3.5, 6), Vector3(4, 0, -8))
		"porta":
			# muro con una porta larga 1,4 m fuori asse
			wall(Vector3(10, 3.5, 0.5), Vector3(-6.2, 0, -6))
			wall(Vector3(10, 3.5, 0.5), Vector3(5.2, 0, -6))
		"corridoio":
			# corridoio a gomito largo 1,8 m
			wall(Vector3(0.5, 3.5, 10), Vector3(-1.1, 0, -9))
			wall(Vector3(0.5, 3.5, 7), Vector3(1.1, 0, -10.5))
			wall(Vector3(6, 3.5, 0.5), Vector3(3.9, 0, -7.2))
			wall(Vector3(8, 3.5, 0.5), Vector3(2.8, 0, -4.0))
		"recinto":
			# giocatore chiuso in un recinto alto: irraggiungibile
			wall(Vector3(7, 3.5, 0.5), Vector3(0, 0, -3.5))
			wall(Vector3(7, 3.5, 0.5), Vector3(0, 0, 3.5))
			wall(Vector3(0.5, 3.5, 7), Vector3(-3.5, 0, 0))
			wall(Vector3(0.5, 3.5, 7), Vector3(3.5, 0, 0))


func crossed(from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.0, to + Vector3.UP * 1.0, 1)
	var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and stage.has(hit.collider)


## Fa partire gli zombie e li segue. reachable=false: devono restare fuori dal recinto.
func trial(label: String, kinds: Array, starts: Array, reachable: bool, limit: float) -> void:
	var zs := []
	for i in kinds.size():
		var e: Node3D = world._spawn_enemy(AT + starts[i], 700 + i)
		e.global_position = AT + starts[i]
		e.set_kind(kinds[i])
		e.spit_cooldown = 999.0
		e.leap_cooldown = 999.0
		e.home = e.global_position
		e.hear(p, 60.0)
		zs.append({"z": e, "prev": e.global_position, "seg": e.global_position, "dir": Vector3.ZERO, "tp": 0, "wall": 0, "flip": 0, "at": -1.0})
	var t := 0.0                         # secondi di gioco
	var n := 0                           # tick
	var arrived := 0
	while t < limit and arrived < zs.size():
		await physics_frame
		n += 1
		t += Engine.time_scale / 60.0
		p.health = 100.0
		for r in zs:
			var e: Node3D = r.z
			if not is_instance_valid(e): continue
			e.memory = maxf(e.memory, 6.0)
			if e.state == e.State.WANDER and n % 20 == 0: e.hear(p, 60.0)
			var now: Vector3 = e.global_position
			if Vector2(now.x - r.prev.x, now.z - r.prev.z).length() > 1.5: r.tp += 1
			if crossed(r.prev, now): r.wall += 1
			if r.at >= 0.0:
				r.prev = now
				continue
			r.prev = now
			# inversioni: ogni 0,5 s di gioco, spostamento che torna indietro rispetto al precedente
			if n % 10 == 0:
				var step: Vector3 = (now - r.seg) * Vector3(1, 0, 1)
				if step.length() > 0.25:
					if r.dir != Vector3.ZERO and step.normalized().dot(r.dir) < -0.5: r.flip += 1
					r.dir = step.normalized()
				r.seg = now
			if reachable and r.at < 0.0 and Vector2(now.x - p.global_position.x, now.z - p.global_position.z).length() < 3.2:
				r.at = t
				arrived += 1
	var need: int = zs.size() if zs.size() == 1 else zs.size() - 1
	var good: bool = (arrived >= need) if reachable else true
	for r in zs:
		var e: Node3D = r.z
		var steps = e.get("recoveries") if is_instance_valid(e) else {}
		var inside: bool = not reachable and absf(e.global_position.x - AT.x) < 3.4 and absf(e.global_position.z - AT.z) < 3.4
		if r.tp > 0 or r.wall > 0 or inside or r.flip > 6: good = false
		print("    %s: %s tp %d muri %d inversioni %d sblocchi %s" % [["infetto", "corridore", "bruto", "urlatore", "sputatore", "boss"][e.kind],
			("arrivato in %.1f s" % r.at) if r.at >= 0.0 else ("a %.1f m" % e.global_position.distance_to(p.global_position)), r.tp, r.wall, r.flip, str(steps)])
		e.queue_free()
	print("PASS " if good else "FAIL ", label, " (", arrived, "/", zs.size(), " arrivati, %.0f s)" % t)
	if not good: fails += 1
	await physics_frame


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
	p.global_position = AT + Vector3(0, 0.1, 0)
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 3.0
	var far := Vector3(0, 0.15, -12)
	for name in ["muro_lungo", "trappola_u", "porta", "corridoio"]:
		build(name)
		await physics_frame
		var start: Vector3 = Vector3(0, 0.15, -8) if name == "trappola_u" else far
		if name == "corridoio": start = Vector3(0, 0.15, -13)
		for kind in [0, 1, 2]:
			await trial("%s singolo %d" % [name, kind], [kind], [start], true, 40.0)
		await trial(name + " gruppo", [0, 0, 1, 2, 3, 0], [start, start + Vector3(1.2, 0, 0), start + Vector3(-1.2, 0, 0), start + Vector3(0, 0, -1.5), start + Vector3(2.0, 0, -1.0), start + Vector3(-2.0, 0, -1.0)], true, 60.0)
	build("recinto")
	await physics_frame
	for kind in [0, 1, 2]:
		await trial("recinto singolo %d (irraggiungibile)" % kind, [kind], [Vector3(0, 0.15, -9)], false, 25.0)
	await trial("recinto gruppo (irraggiungibile)", [0, 0, 1, 2, 3], [Vector3(0, 0.15, -9), Vector3(6, 0.15, -6), Vector3(-7, 0.15, 2), Vector3(0, 0.15, 9), Vector3(8, 0.15, 3)], false, 30.0)
	Engine.time_scale = 1.0
	print("SBLOCCO: ", fails, " errori")
	quit(1 if fails > 0 else 0)
