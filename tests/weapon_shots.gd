extends SceneTree
# Fogli di fotogrammi: come si tengono e si usano ascia e pistola, viste da fuori e in prima persona.
#   godot --path . --resolution 1280x720 -s res://tests/weapon_shots.gd -- <cartella>
var world: Node3D
var cam: Camera3D
var folder := ""
var sheet: Image
var cell := 0
const AT := Vector3(14, 140.02, -60)
const W := 320
const H := 180
const COLUMNS := 5


func _init() -> void:
	call_deferred("_run")


func frames(n: int) -> void:
	for i in n: await process_frame


func begin() -> void:
	sheet = Image.create(W * COLUMNS, H * 4, false, Image.FORMAT_RGB8)
	cell = 0


func take() -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(W, H, Image.INTERPOLATE_BILINEAR)
	sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(cell % COLUMNS * W, cell / COLUMNS * H))
	cell += 1


func finish(name: String) -> void:
	sheet.save_png(folder.path_join(name + ".png"))
	print("FOGLIO ", name)


func view(body: Node3D, angle: float, dist: float, high: float, tall: float = 1.2) -> void:
	var c: Vector3 = body.global_position + Vector3.UP * tall
	cam.global_position = c + Vector3(sin(angle) * dist, high, cos(angle) * dist)
	cam.look_at(c)


func _run() -> void:
	folder = OS.get_cmdline_user_args()[0]
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
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(200, 200)
	plane.mesh = mesh
	floor_body.add_child(plane)
	world.add_child(floor_body)
	floor_body.global_position = Vector3(AT.x, 140.0, AT.z)
	cam = Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	var p: CharacterBody3D = world.player
	p.visible = false
	p.set_physics_process(false)
	var other: CharacterBody3D = load("res://player/player.tscn").instantiate()
	other.local_control = false
	world.add_child(other)
	other.global_position = AT
	world._dress(other, 2)
	world.actors[2] = other
	other.rig.camera.current = false
	other.set_physics_process(false)
	var face: float = other.visual.global_rotation.y + PI
	cam.current = true
	await frames(20)
	# --- Da fuori
	begin()
	for id in ["axe", "pistol"]:
		other.equipped = id
		await frames(25)
		for a in [0.5, -0.6, 1.5, -1.5, PI]:
			view(other, face + a, 2.3, 0.1)
			await take()
	other.equipped = "axe"
	await frames(12)
	view(other, face + 0.7, 2.6, 0.2)
	other.melee.remote_block = true
	await frames(25)
	await take()
	other.melee.remote_block = false
	await frames(20)
	await take()
	other.melee.charging = true
	other.melee.charge_time = 0.8
	await frames(20)
	await take()
	other.melee.charging = false
	await frames(10)
	await take()
	finish("fuori_pose")
	for i in 4:
		begin()
		other.melee.charged_attack = i == 3
		other.melee.attacking = true
		await frames(2)
		other.melee.attacking = false
		for k in 10:
			await frames(3)
			view(other, face + 0.7, 2.6, 0.2)
			await take()
		finish("fuori_colpo_%d" % i)
		await frames(20)
	other.equipped = "pistol"
	await frames(25)
	begin()
	view(other, face + 0.8, 2.0, 0.1)
	other.melee.attacking = true
	await frames(2)
	other.melee.attacking = false
	await take()
	await frames(10)
	other.reload_left = 1.6
	for k in 14:
		await frames(4)
		await take()
	other.reload_left = 0.0
	finish("fuori_pistola")
	world.actors.erase(2)
	other.queue_free()
	# --- Prima persona
	p.visible = true
	p.set_physics_process(true)
	p.controls_enabled = true
	p.rig.controls_enabled = false
	p.rig.pitch = -0.04
	p.reset_at(AT + Vector3(6, 0.3, 0))
	p.rig.camera.current = true
	p.equip_id("axe")
	await frames(45)
	for i in 3:
		begin()
		p.stamina = 100.0
		p.melee.begin_charge()
		p.melee.release_attack()
		for k in 15:
			await frames(2)
			await take()
		finish("fp_colpo_%d" % i)
		while p.melee.attacking: await process_frame
	begin()
	p.stamina = 100.0
	p.melee.begin_charge()
	for k in 6:
		await frames(6)
		await take()
	p.melee.release_attack()
	for k in 8:
		await frames(2)
		await take()
	finish("fp_pesante")
	await frames(30)
	begin()
	p.melee.block_forced = true
	await frames(20)
	await take()
	p.melee.block_forced = false
	await frames(20)
	await take()
	p.owned.append("pistol")
	p.magazine = 8
	p.equip_id("pistol")
	await frames(5)
	await take()
	await frames(30)
	await take()
	p.melee.ads_forced = true
	await frames(20)
	await take()
	p.melee.ads_forced = false
	await frames(15)
	await take()
	p.melee.perform_attack(false)
	await frames(1)
	p.melee._aim_strike()
	await frames(1)
	await take()
	await frames(2)
	await take()
	await frames(20)
	p.reload_left = 1.6
	if p.has_method("reload_weapon"): p.magazine = 0
	for k in 12:
		await frames(4)
		await take()
	finish("fp_pistola")
	print("FINE")
	quit(0)
