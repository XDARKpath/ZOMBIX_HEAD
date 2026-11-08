extends SceneTree
# Rocca: si cammina davvero (tasti premuti) su scale e rampe e si attraversa l'armeria; foto in res://../screenshots/rs-*.png.
# godot --path . -s res://tests/rocca_stairs_checks.gd
var fails := 0
var world: Node3D
var p: CharacterBody3D
var r: Node3D
func _initialize(): call_deferred("run")
func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1
func shot(id: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/rs-" + id + ".png"))
func face(at_local: Vector3, pitch := -0.1) -> void:
	var d: Vector3 = r.to_global(at_local) - p.global_position
	p.rig.yaw = atan2(-d.x, -d.z)
	p.rig.pitch = pitch
## cammina in avanti verso "to" (locale della Rocca) per al massimo "frames": torna la distanza rimasta in orizzontale
func walk(from: Vector3, to: Vector3, frames := 500) -> float:
	for e in root.find_children("Enemy*", "CharacterBody3D", true, false):      # gli infetti delle stanze non fanno da muro
		e.set_physics_process(false)
		e.global_position += Vector3(0, -300, 0)
	p.reset_at(r.to_global(from))
	p.velocity = Vector3.ZERO
	for i in 10: await physics_frame
	Input.action_press("move_forward")
	var left := 99.0
	for i in frames:
		face(to)
		await physics_frame
		var l: Vector3 = r.to_local(p.global_position)
		left = Vector2(l.x - to.x, l.z - to.z).length()
		if left < 0.6: break
	Input.action_release("move_forward")
	var l: Vector3 = r.to_local(p.global_position)
	print("  da %s a %s: arrivato a %s (manca %.2f)" % [from, to, l, left])
	return left
func run():
	DisplayServer.window_set_size(Vector2i(1280, 720))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.8).timeout
	world.get_node("Interface").visible = false
	world.spawner.set_process(false)
	world.spawner.set_physics_process(false)
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)
	p = world.player
	r = world.rocca
	p.controls_enabled = true
	p.rig.camera.current = true
	world.terrain.ensure_near([r.global_position])
	if p.has_method("select_slot"): p.select_slot(-1)
	# 1. scala di legno della Fossa: su fino alla balconata (3.5 m) e di nuovo giù
	check(await walk(Vector3(-8, 0.2, -4.6), Vector3(-8, 3.6, -11.0), 600) < 0.8 and r.to_local(p.global_position).y > 3.0, "Sale la scala della Fossa fino alla balconata")
	face(Vector3(-8, 0, -4), -0.5)
	await shot("fossa-top")
	check(await walk(Vector3(-8, 3.8, -11.0), Vector3(-8, 0.0, -3.6), 600) < 0.8, "Scende la scala della Fossa")
	# 2. armeria al piano di sopra: dalla sala grande verso ovest fin dentro l'armeria e ritorno
	var u: float = r.UP
	check(await walk(Vector3(-4, u + 0.2, 12), Vector3(-15, u, 12), 600) < 0.8, "Dalla sala grande si entra nell'armeria")
	face(Vector3(-16, u + 1.5, 12))
	await shot("varco-armeria")
	face(Vector3(-4, u + 1.5, 12))
	await shot("armeria-verso-sala")
	check(await walk(Vector3(-15, u + 0.2, 11), Vector3(-12, u, 17), 400) < 0.8, "Si gira libero dentro l'armeria")
	face(Vector3(-16, u + 1.2, 12))
	await shot("armeria")
	# 3. scala a chiocciola della torre: su seguendo l'elica fino al pianerottolo (5 m) e giù di nuovo
	var cen: Vector3 = r.cell_pos(r.TOWER)
	var path := []
	for i in range(0, 58, 3):
		var ang := deg_to_rad(240.0 + i * 10.0)
		path.append(cen + Vector3(cos(ang) * 1.25, 0, sin(ang) * 1.25))
	p.reset_at(r.to_global(path[0] + Vector3(0, 0.3, 0)))
	for i in 10: await physics_frame
	var stuck := 0
	for k in range(1, path.size()):
		Input.action_press("move_forward")
		var n := 0
		while n < 120:
			face(path[k])
			await physics_frame
			n += 1
			var l: Vector3 = r.to_local(p.global_position)
			if Vector2(l.x - path[k].x, l.z - path[k].z).length() < 0.5: break
		if n >= 120: stuck += 1
	Input.action_release("move_forward")
	var top: float = r.to_local(p.global_position).y
	print("  chiocciola: quota %.2f, tappe mancate %d" % [top, stuck])
	check(top > 4.3 and stuck == 0, "Sale la scala a chiocciola della torre fino al piano di sopra")
	face(cen, -0.6)
	await shot("chiocciola")
	path.reverse()
	stuck = 0
	for k in range(1, path.size()):
		Input.action_press("move_forward")
		var n := 0
		while n < 120:
			face(path[k])
			await physics_frame
			n += 1
			var l: Vector3 = r.to_local(p.global_position)
			if Vector2(l.x - path[k].x, l.z - path[k].z).length() < 0.5: break
		if n >= 120: stuck += 1
	Input.action_release("move_forward")
	print("  chiocciola in discesa: quota %.2f, tappe mancate %d" % [r.to_local(p.global_position).y, stuck])
	check(r.to_local(p.global_position).y < 0.8 and stuck == 0, "Scende la scala a chiocciola fino alla cantina")
	print("ROCCA STAIRS %s (%d errori)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
