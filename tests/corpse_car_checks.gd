extends SceneTree
# Cadaveri sul 4×4: lasciati cadere sul cofano restano sopra, spinti contro la fiancata restano fuori dalla carrozzeria.
#   godot --path . --headless --fixed-fps 60 -s res://tests/corpse_car_checks.gd
var world: Node3D
var p: CharacterBody3D
var fails := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1


func wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await physics_frame
		t += 1.0 / 60.0
		p.health = 100.0


func pelvis(e: Node3D) -> Vector3:
	var sk: Skeleton3D = e.avatar.skeleton
	return sk.global_transform * sk.get_bone_global_pose(e.avatar.bone_ids["pelvis"]).origin


## Cade un infetto in `at` con la spinta `force`; torna il bacino nel riferimento del 4×4 dopo l'assestamento.
func drop(car: Node3D, at: Vector3, force: Vector3) -> Vector3:
	var e: Node3D = world._spawn_enemy(at, 700 + randi() % 200)
	e.global_position = at
	e.set_kind(0)
	e.home = at
	e.state = e.State.WANDER
	e.receive_hit("chest", 500.0, force, "pistol")
	await wait(8.0)
	var local: Vector3 = car.global_transform.affine_inverse() * pelvis(e)
	var mode := str(e.visual.get_meta("zr", {}).get("mode", "?"))
	e.queue_free()
	await wait(0.2)
	print("  bacino nel 4x4 x=%.2f y=%.2f z=%.2f modo=%s" % [local.x, local.y, local.z, mode])
	return local


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
	p = world.player
	var car: Node3D = world.expedition.car
	var fwd: Vector3 = -car.global_basis.z
	var side: Vector3 = car.global_basis.x
	p.global_position = car.global_position + side * 6.0   # la camera vicina: entro 30 m i corpi cadono col ragdoll
	await wait(0.5)
	var ground: float = world.terrain.height(car.global_position.x, car.global_position.z) - car.global_position.y
	for i in 3:
		var l := await drop(car, car.global_position + fwd * 1.3 + side * (i - 1) * 0.4 + Vector3.UP * 2.2, Vector3(0, -2, 0))
		check(l.y > ground + 0.7, "Lasciato cadere sul cofano resta sopra (bacino %.2f m sopra il suolo)" % (l.y - ground))
	for i in 2:
		var at: Vector3 = car.global_position + fwd * 1.3 + side * 1.35
		at.y = world.terrain.height(at.x, at.z)
		var l := await drop(car, at, -side * 4.0)
		var inside: bool = absf(l.x) < 0.9 and absf(l.z) < 1.8 and l.y < ground + 1.0
		check(not inside, "Spinto contro la fiancata resta fuori dalla carrozzeria (x %.2f)" % l.x)
	print("RISULTATO corpse_car_checks: %d errori" % fails)
	quit(1 if fails else 0)
