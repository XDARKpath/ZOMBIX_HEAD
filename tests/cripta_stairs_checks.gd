extends SceneTree
# Cripta del Carceriere (world/dungeon/dungeon.gd): si cammina con i tasti su e giù per le rampe StairsLow e la scala di risalita.
# Foto in res://../screenshots/rs-cripta-*.png.  godot --path . -s res://tests/cripta_stairs_checks.gd
const STAIR_Y := 2.5
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
	for e in root.find_children("*", "CharacterBody3D", true, false):      # gli infetti delle stanze non fanno da muro
		if e == p: continue
		e.set_physics_process(false)
		e.set_process(false)
		e.global_position += Vector3(0, -300, 0)
	p.health = 100.0
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
	p = world.player
	r = world.dungeon
	p.controls_enabled = true
	p.rig.camera.current = true
	if p.has_method("select_slot"): p.select_slot(-1)
	# rampe: salgono verso nord dalla cella della rampa alla piattaforma
	var k := 0
	for c in r.RAMPS:
		var base: Vector3 = r.cell_pos(c)
		var top_cell: Vector2i = r.RAMP_FOR_SIDE.get(c, c + Vector2i(0, -1))
		var top: Vector3 = r.cell_pos(top_cell)
		check(await walk(base + Vector3(0, 0.3, 3.2), top + Vector3(0, 0, 0), 500) < 0.8 and r.to_local(p.global_position).y > 2.0, "Sale la rampa %s (quota %.2f)" % [c, r.to_local(p.global_position).y])
		face(base + Vector3(0, 0, 3), -0.5)
		await shot("cripta-rampa-%d" % k)
		check(await walk(top + Vector3(0, STAIR_Y + 0.3, 0), base + Vector3(0, 0, 3.2), 500) < 0.8, "Scende la rampa %s" % c)
		k += 1
	# scala di risalita verso est
	var s0: Vector3 = r.cell_pos(Vector2i(8, -45)) + Vector3(0.6, 0, 2)
	r.set_gate("uscita", true)            # la porta est dell'arena si apre col Carceriere morto
	await create_timer(2.0).timeout
	await walk(Vector3(27.5, 0.3, -178.0), s0 + Vector3(1.0, 0, 0), 500)
	check(r.to_local(p.global_position).y > 1.5, "Sale la scala di risalita (quota %.2f)" % r.to_local(p.global_position).y)
	await shot("cripta-risalita")
	print("CRIPTA STAIRS %s (%d errori)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
