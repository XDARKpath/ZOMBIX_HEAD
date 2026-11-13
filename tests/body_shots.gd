extends SceneTree
# Fogli di fotogrammi del personaggio visto da fuori, un foglio per azione.
#   godot --path . --resolution 1280x720 --fixed-fps 30 -s res://tests/body_shots.gd -- <cartella>
var world: Node3D
var cam: Camera3D
var other: CharacterBody3D
var folder := ""
var sheet: Image
var cell := 0
var face := 0.0
const AT := Vector3(14, 140.02, -60)
const W := 256
const H := 288
const COLUMNS := 8


func _init() -> void:
	call_deferred("_run")


func frames(n: int) -> void:
	for i in n: await process_frame


func take() -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var crop := img.get_region(Rect2i(320, 0, 640, 720))
	crop.resize(W, H, Image.INTERPOLATE_BILINEAR)
	sheet.blit_rect(crop, Rect2i(0, 0, W, H), Vector2i(cell % COLUMNS * W, cell / COLUMNS * H))
	cell += 1


## Una azione: fa partire `start` e fotografa `count` fotogrammi ogni `step`, con la camera che segue il corpo.
func action(name: String, start: Callable, count: int = 16, step: int = 3, angle: float = 0.6, speed: Vector3 = Vector3.ZERO) -> void:
	sheet = Image.create(W * COLUMNS, H * ceili(float(count) / COLUMNS), false, Image.FORMAT_RGB8)
	cell = 0
	start.call()
	for k in count:
		for i in step:
			other.velocity = speed
			other.global_position += speed / 30.0
			await process_frame
		var c: Vector3 = other.global_position + Vector3.UP * 0.95
		cam.global_position = c + Vector3(sin(face + angle) * 3.2, 0.25, cos(face + angle) * 3.2)
		cam.look_at(c)
		await take()
	other.velocity = Vector3.ZERO
	other.global_position = AT
	sheet.save_png(folder.path_join(name + ".png"))
	print("FOGLIO ", name)
	await frames(25)


func _run() -> void:
	folder = OS.get_cmdline_user_args()[0]
	var only: Array = OS.get_cmdline_user_args().slice(1)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	root.get_node("Session").launch()
	world.automated = true
	await frames(30)
	world.spawner.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.queue_free()
	world.get_node("Interface").visible = false
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(400, 400)
	plane.mesh = mesh
	floor_body.add_child(plane)
	world.add_child(floor_body)
	floor_body.global_position = Vector3(AT.x, 140.0, AT.z)
	cam = Camera3D.new()
	cam.fov = 36.0
	world.add_child(cam)
	var p: CharacterBody3D = world.player
	p.visible = false
	p.set_physics_process(false)
	other = load("res://player/player.tscn").instantiate()
	other.local_control = false
	world.add_child(other)
	other.global_position = AT
	world._dress(other, 2)
	world.actors[2] = other
	other.rig.camera.current = false
	other.set_physics_process(false)
	cam.current = true
	await frames(30)
	face = other.visual.global_rotation.y + PI
	var fwd: Vector3 = -other.visual.global_basis.z
	var right: Vector3 = other.visual.global_basis.x
	var run := func(name: String, start: Callable, count: int = 16, step: int = 3, angle: float = 0.6, speed: Vector3 = Vector3.ZERO) -> void:
		if only.is_empty() or name in only: await action(name, start, count, step, angle, speed)
	var nothing := func() -> void: pass
	await run.call("fermo", nothing, 8, 15)
	await run.call("cammina", nothing, 16, 2, 1.2, fwd * 2.6)
	await run.call("corre", func() -> void: other.sprinting = true, 16, 2, 1.2, fwd * 5.5)
	other.sprinting = false
	await run.call("indietro", nothing, 8, 3, 0.6, -fwd * 2.2)
	await run.call("lato", nothing, 8, 3, 0.2, right * 2.2)
	await run.call("accucciato", func() -> void: other.crouching = true, 8, 4, 0.8, fwd * 1.2)
	other.crouching = false
	await frames(15)
	other.items["item_bende"] = 1
	other.equipped = "item_bende"
	await frames(15)
	await run.call("benda", func() -> void: world.survival._set_gesture(other, "use"), 24, 3)
	await run.call("lancia", func() -> void: world.survival._set_gesture(other, "throw"), 16, 3)
	other.items["item_testa"] = 1
	other.equipped = "item_testa"
	await frames(15)
	await run.call("testa", nothing, 8, 8)
	await run.call("consegna", func() -> void: world.survival._set_gesture(other, "give"), 16, 3)
	other.equipped = ""
	await frames(15)
	await run.call("saluta", func() -> void: world.survival._set_gesture(other, "wave"), 16, 4)
	await run.call("colpito", func() -> void: other.health -= 10.0, 16, 2)
	await run.call("sbalzato", func() -> void: other.set_meta("hit_heavy_until", Time.get_ticks_msec() + 500), 16, 3)
	await run.call("cade", func() -> void: other.dead = true, 16, 4)
	print("FINE")
	quit(0)
