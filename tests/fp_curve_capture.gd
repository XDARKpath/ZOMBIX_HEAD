extends SceneTree
# Prima persona sulle curve 0.14: res://../screenshots/fpc-<stato>.png
const Arsenal := preload("res://weapons/zx_arsenal.gd")
var world: Node3D
var vm: Node3D
func _initialize(): call_deferred("run")
func shot(id: String, wait := 0.5):
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/fpc-" + id + ".png"))
	print("shot ", id)
func run():
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.5).timeout
	var p = world.player
	p.set_physics_process(false)
	p.rig.set_physics_process(false)
	p.position = Vector3(8, 0.1, -11)
	p.rig.yaw = 0
	p.rig.pitch = 0
	p.rig.reset_follow()
	vm = p.rig.camera.get_node("Viewmodel")
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args(): only = a.split(",")
	for weapon in ["axe", "katana", "knife", "pistol", "pump_shotgun", "sledgehammer"]:
		if not only.is_empty() and not weapon in only: continue
		p.equipped = weapon
		p.stamina = 100
		await shot(weapon, 0.9)
		var cam: Camera3D = p.rig.camera
		var sk: Skeleton3D = vm.hands.skeleton
		for side in ["r", "l"]:
			var t: Transform3D = vm.hands.hands[side]["target"]
			var bone: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_" + side))).origin
			var shoulder: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("upperarm_" + side))).origin
			print(weapon, " mano ", side, " bersaglio ", cam.to_local(t.origin), " osso ", cam.to_local(bone), " spalla ", cam.to_local(shoulder))
		print(weapon, " arma ", cam.to_local(vm.item.global_position), " braccia visibili ", vm.arms.is_visible_in_tree())
		if Arsenal.is_gun(weapon): continue
		# Colpo: fotogramma di picco della finestra di danno, poi colpo pesante.
		for charged in [false, true]:
			p.melee.attacking = false
			p.melee.perform_attack(charged)
			var clip: String = vm.action
			var hit: Vector2 = Arsenal.hit_window(clip)
			p.melee.set_physics_process(false)
			p.melee.attack_time = (hit.x + hit.y) * 0.5
			await shot("%s-%s" % [weapon, "heavy" if charged else "hit"], 0.15)
			print(weapon, " ", clip, " finestra ", hit, " windup ", p.melee.active_windup, " attivo ", p.melee.active_seconds)
			p.melee.set_physics_process(true)
			p.melee.cancel()
	quit()
