extends SceneTree
# Guida del 4×4 su una piattaforma piatta di prova (y=150, sopra la Zona 1): raggio di svolta a passo d'uomo
# e a tutta velocità, nessun testacoda, frenata con S, cordolo da 0,15 m superato, muro da 0,5 m e
# sbarramento stradale (1,2 m) che fermano. L'input arriva come da un conducente remoto (valori esatti).
# godot --headless --path . -s res://tests/ranger_drive_checks.gd
const Y := 150.0
const C := Vector3(0, Y, -150)
var world: Node3D
var car: CharacterBody3D
var cmd := Vector2.ZERO
var results := {}


func _initialize() -> void:
	call_deferred("run")


func _feed() -> void:
	if car: car.drive_input = cmd; car.input_age = 0.0


func wait(n: int) -> void:
	for i in n: await physics_frame


func box(size: Vector3, at: Vector3) -> void:
	var b := StaticBody3D.new(); b.collision_layer = 1; b.collision_mask = 0
	var s := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; s.shape = sh; b.add_child(s)
	world.add_child(b); b.global_position = at


func place(at: Vector3, yaw := 0.0) -> void:
	cmd = Vector2.ZERO
	car.position = at; car.rotation.y = yaw; car.speed = 0.0; car.velocity = Vector3.ZERO
	await wait(30)


func check(name: String, ok: bool) -> void:
	results[name] = ok
	print("RANGER_DRIVE ", "PASS " if ok else "FAIL ", name)


## Raggio del cerchio percorso a velocità costante con sterzo pieno (metà della distanza massima tra punti opposti).
func radius(v: float) -> Array:
	await place(C + Vector3(0, 0.3, 0), 0)
	cmd = Vector2(0, -v / 24.0)
	while car.speed < v - 0.01: await physics_frame
	cmd = Vector2(-1, -v / 24.0)
	await wait(60)
	var pts: Array = []; var turned := 0.0; var prev: float = car.rotation.y; var t := 0; var slip := 0.0
	while absf(turned) < TAU and t < 3000:
		await physics_frame; t += 1
		turned += wrapf(car.rotation.y - prev, -PI, PI); prev = car.rotation.y
		pts.append(Vector2(car.position.x, car.position.z))
		var fwd: Vector3 = -car.global_basis.z
		if car.velocity.length() > 0.5: slip = maxf(slip, fwd.angle_to(Vector3(car.velocity.x, 0, car.velocity.z)))
	var diam := 0.0
	for i in pts.size():
		diam = maxf(diam, (pts[i] as Vector2).distance_to(pts[(i + pts.size() / 2) % pts.size()]))
	return [diam / 2.0, slip]


## Guida dritta a v verso z=-60 dal centro; true se passa oltre l'ostacolo.
func crosses(x: float, v: float) -> bool:
	await place(C + Vector3(x, 0.3, 100), 0)
	cmd = Vector2(0, -v / 24.0)
	var t := 0
	while t < 600:
		await physics_frame; t += 1
		if car.position.z < C.z + 56.0: return true
		if t > 120 and car.speed < 0.5: return false
	return false


func run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	world.spawner.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.set_physics_process(false); e.global_position += Vector3(0, -400, 0)
	car = world.expedition.car
	world.expedition.collected = [true, true, true]; world.expedition.stage = 2
	car.repaired = true
	box(Vector3(300, 1, 300), C - Vector3(0, 0.5, 0))
	await place(C + Vector3(0, 0.3, 100), 0)
	var drv: CharacterBody3D = load("res://player/player.tscn").instantiate()
	drv.local_control = false; drv.name = "FakeDriver"; world.add_child(drv)
	drv.rig.controls_enabled = false; drv.rig.set_physics_process(false); drv.rig.camera.current = false
	world.actors[2] = drv; drv.reset_at(car.to_global(Vector3(-2.0, 0.3, 0))); await wait(5)
	check("conducente seduto", car.interact(2))
	physics_frame.connect(_feed)
	var slow: Array = await radius(3.0)
	check("raggio a 3 m/s %.2f m (4–5)" % slow[0], slow[0] > 3.8 and slow[0] < 5.0)
	var fast: Array = await radius(24.0)
	check("raggio a 24 m/s %.2f m (9–13)" % fast[0], fast[0] > 9.0 and fast[0] < 13.0)
	check("niente testacoda: muso sulla traiettoria (%.3f rad)" % maxf(slow[1], fast[1]), maxf(slow[1], fast[1]) < 0.05)
	# Frenata con S da 24 m/s.
	await place(C + Vector3(-100, 0.3, 140), 0)
	cmd = Vector2(0, -1)
	while car.speed < 23.99: await physics_frame
	cmd = Vector2(0, 1)
	var start := car.position; var t := 0
	while car.speed > 0.0 and t < 600: await physics_frame; t += 1
	var brake := start.distance_to(car.position)
	check("S frena da 24 m/s in %.1f m (< 22)" % brake, brake < 22.0)
	# Ostacoli trasversali sul percorso.
	box(Vector3(7, 0.15, 0.3), C + Vector3(-120, 0.075, 60))
	box(Vector3(7, 0.28, 0.3), C + Vector3(-108, 0.14, 60))
	box(Vector3(7, 0.5, 0.3), C + Vector3(-96, 0.25, 60))
	box(Vector3(6.5, 1.2, 0.8), C + Vector3(-84, 0.6, 60)) # come world/campaign/roadblocks.gd
	check("cordolo 0,15 m superato a 5 m/s", await crosses(-120, 5.0))
	check("gradino 0,28 m superato a 5 m/s", await crosses(-108, 5.0))
	check("muretto 0,5 m ferma a 15 m/s", not await crosses(-96, 15.0))
	check("sbarramento stradale ferma a 24 m/s", not await crosses(-84, 24.0))
	cmd = Vector2.ZERO
	root.get_node("Session").leave()
	quit(0 if results.values().all(func(ok): return ok) else 1)
