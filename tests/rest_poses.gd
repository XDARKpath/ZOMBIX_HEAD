extends SceneTree
# I modelli degli infetti e del menu fermi nella loro posa di riposo, senza animazioni: serve a capire se un difetto è nel modello
# o nel modo in cui lo si anima. In user://rest/.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://rest"))
	var scene := Node3D.new()
	root.add_child(scene)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	scene.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("6d7a7a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	scene.add_child(env)
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.current = true
	var x := 0.0
	var names := ["ZMB_Tank", "ZMB_Spitter", "ZMB_Walker_1", "BOSS_Subject_Zero"]
	for model in names:
		var m: Node3D = load("res://art/zx_infected/%s.glb" % model).instantiate()
		scene.add_child(m)
		m.position.x = x
		for s in m.find_children("*", "Skeleton3D", true, false):
			(s as Skeleton3D).reset_bone_poses()
			var sk := s as Skeleton3D
			var low := INF
			var high := -INF
			for b in sk.get_bone_count():
				var y: float = sk.get_bone_global_rest(b).origin.y
				low = minf(low, y)
				high = maxf(high, y)
			print(model, " ossa da y ", snappedf(low, 0.01), " a ", snappedf(high, 0.01), " testa ", snappedf(sk.get_bone_global_rest(sk.find_bone("head")).origin.y, 0.01), " spalle ", snappedf(sk.get_bone_global_rest(sk.find_bone("upperarm_l")).origin.x, 0.01))
		for mesh in m.find_children("*", "MeshInstance3D", true, false):
			print(model, " aabb ", (mesh as MeshInstance3D).get_aabb())
		x += 2.6
	cam.global_position = Vector3(3.9, 1.3, 5.6)
	cam.look_at(Vector3(3.9, 0.9, 0))
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://rest/fronte.png")
	cam.global_position = Vector3(0, 1.45, 1.5)
	cam.look_at(Vector3(0, 1.35, 0))
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://rest/tank_fronte.png")
	cam.global_position = Vector3(0, 1.45, -1.5)
	cam.look_at(Vector3(0, 1.35, 0))
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://rest/tank_dietro.png")
	# Le skin del menu.
	var menu: Node3D = load("res://art/menu_batch2/SM_ZX_Player.glb").instantiate()
	for c in scene.get_children():
		if c is Node3D and c != cam and not c is DirectionalLight3D and not c is WorldEnvironment: c.queue_free()
	await process_frame
	var offset := 0.0
	for skin in ["Operative", "Scavenger", "Tactician", "Veteran", "Mechanic", "Fisherman"]:
		var copy: Node3D = menu.duplicate()
		scene.add_child(copy)
		copy.position.x = offset
		for mesh in copy.find_children("*", "MeshInstance3D", true, false):
			mesh.visible = mesh.name == "Skin_" + skin or (skin == "Operative" and mesh.name in ["Slot1_Chest_PlateCarrier", "Slot3_Thigh_Holster", "Slot4_Head_BallisticCap"])
		for s in copy.find_children("*", "Skeleton3D", true, false): (s as Skeleton3D).reset_bone_poses()
		offset += 2.2
	cam.global_position = Vector3(5.5, 1.3, 6.5)
	cam.look_at(Vector3(5.5, 0.9, 0))
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://rest/menu_skin.png")
	cam.global_position = Vector3(8.8, 1.45, 1.5)
	cam.look_at(Vector3(8.8, 1.35, 0))
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://rest/mechanic_fronte.png")
	menu.free()
	quit(0)
