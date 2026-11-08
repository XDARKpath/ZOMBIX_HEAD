extends SceneTree
# Allineamento di controllo: skin ZX Player e infetti/boss/NPC generati. res://../screenshots/zx-*.png
const PALETTE := "res://art/env/materials/M_Env_Palette.tres"
func _initialize(): call_deferred("run")
func shot(id: String):
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/zx-" + id + ".png"))
	print("shot ", id)
func stage() -> Node3D:
	var s := Node3D.new()
	root.add_child(s)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.48, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	s.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	s.add_child(sun)
	return s
func run():
	DisplayServer.window_set_size(Vector2i(1600, 700))
	var s := stage()
	var cam := Camera3D.new()
	s.add_child(cam)
	cam.position = Vector3(0, 1.3, 9)
	cam.fov = 50
	for i in 10:
		var p: Node3D = load("res://art/zx_player/SM_ZX_Player.glb").instantiate()
		p.start_weapon = ["assault_rifle", "pump_shotgun", "sniper_rifle", "pistol", "revolver", "smg", "katana", "longsword", "trout", "rubber_chicken"][i]
		s.add_child(p)
		p.set_skin(i)
		p.position = Vector3(-6.75 + i * 1.5, 0, 0)
	await create_timer(1.0).timeout
	await shot("skins")
	s.queue_free()
	var s2 := stage()
	var cam2 := Camera3D.new()
	s2.add_child(cam2)
	cam2.position = Vector3(0, 2.2, 14)
	cam2.fov = 50
	var names := ["ZMB_Walker_1", "ZMB_Walker_2", "ZMB_Walker_3", "ZMB_Walker_4", "ZMB_Spitter", "ZMB_Tank", "BOSS_Sheriff_Abomination", "BOSS_Subject_Zero", "BOSS_Toxic_Matriarch", "NPC_Gunsmith", "NPC_Veteran"]
	for i in names.size():
		var n: Node3D = load("res://art/zx_infected/%s.glb" % names[i]).instantiate()
		s2.add_child(n)
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = load(PALETTE)
		n.position = Vector3(-9 + i * 1.8, 0, 0)
		var skel: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0] if not n.find_children("*", "Skeleton3D", true, false).is_empty() else null
		print(names[i], " bones=", skel.get_bone_count() if skel else 0, " meshes=", n.find_children("*", "MeshInstance3D", true, false).size())
	await shot("infected")
	quit()
