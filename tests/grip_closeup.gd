extends SceneTree
# Primi piani della presa: mano e manico visti da vicino, da fuori e in prima persona, più le misure della mano sull'arma.
#   godot --path . --resolution 1280x720 --fixed-fps 30 -s res://tests/grip_closeup.gd -- <cartella>
var world: Node3D
var cam: Camera3D
var folder := ""
var sheet: Image
var cell := 0
const AT := Vector3(14, 140.02, -60)
const W := 480
const H := 270


func _init() -> void:
	call_deferred("_run")


func frames(n: int) -> void:
	for i in n: await process_frame


func take() -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(W, H, Image.INTERPOLATE_BILINEAR)
	sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(cell % 3 * W, cell / 3 * H))
	cell += 1


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
	world.add_child(floor_body)
	floor_body.global_position = Vector3(AT.x, 140.0, AT.z)
	cam = Camera3D.new()
	cam.fov = 35.0
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
	cam.current = true
	await frames(20)
	var sk: Skeleton3D = other.find_children("*", "Skeleton3D", true, false).filter(func(s): return s.find_bone("weapon_anchor") >= 0)[0]
	for id in ["axe", "pistol"]:
		other.equipped = id
		await frames(30)
		sheet = Image.create(W * 3, H * 2, false, Image.FORMAT_RGB8)
		cell = 0
		# Il centro della foto è l'arma vera: la pose dello scheletro qui non contiene ancora l'IK.
		var item: Node3D = sk.get_node("Socket_weapon_anchor").get_child(0)
		var center: Vector3 = item.global_position
		var yaw: float = other.visual.global_rotation.y
		for a in [0.0, 1.05, 2.1, 3.15, 4.2, 5.25]:
			cam.global_position = center + Basis(Vector3.UP, yaw + a) * Vector3(0, 0.12, 0.55)
			cam.look_at(center)
			await take()
		sheet.save_png(folder.path_join("fuori_" + id + ".png"))
	world.actors.erase(2)
	other.queue_free()
	p.visible = true
	p.set_physics_process(true)
	p.controls_enabled = true
	p.rig.controls_enabled = false
	p.rig.pitch = -0.04
	p.reset_at(AT + Vector3(6, 0.3, 0))
	p.rig.camera.current = true
	p.equip_id("axe")
	await frames(40)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(folder.path_join("fp_axe.png"))
	p.owned.append("pistol")
	p.magazine = 8
	p.equip_id("pistol")
	await frames(40)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(folder.path_join("fp_pistol.png"))
	print("FINE")
	quit(0)
