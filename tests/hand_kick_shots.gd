extends SceneTree
# Mano, raccolta e calcio: in prima persona e come li vede un altro giocatore. Foto in user://mano/.
# godot --path . -s res://tests/hand_kick_shots.gd   (con la finestra: le foto non vengono in --headless)
var world: Node3D
var other: CharacterBody3D
var cam: Camera3D
var fails: Array = []


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


func wait(frames: int) -> void:
	for i in frames: await physics_frame


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://mano"))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	world.spawner.set_process(false)
	world.get_node("Interface").visible = false
	var p = world.player
	p.reset_at(Vector3(6, 0.4, -24))
	p.rig.pitch = -0.15
	var vm = p.find_children("*", "Node3D", true, false).filter(func(n): return n.has_method("play_interact") and n.get("arms_vm") != null)[0]
	# ---- prima persona: raccolta a mani vuote, con l'ascia, con la pistola
	for w in ["", "axe", "pistol"]:
		p.equipped = w
		await wait(40)
		vm.play_interact("Interact_Pickup")
		await wait(14)
		var hand: Vector3 = p.rig.camera.to_local(vm.arms_vm.skeleton.to_global(vm.arms_vm.skeleton.get_bone_global_pose(vm.arms_vm.skeleton.find_bone("hand_l")).origin))
		check(hand.z < -0.15 and absf(hand.x) < 0.6 and absf(hand.y) < 0.4 and vm.arms_vm.visible and vm.arms_vm.rig.visible, "Raccolta '%s': mano sinistra in campo (%s)" % [w, hand])
		await _shot("fp_raccolta_" + (w if w != "" else "mani"))
		await wait(40)
	# ---- prima persona: calcio
	p.equipped = "axe"
	await wait(30)
	var m = p.melee
	m.set_physics_process(false)
	m._begin_clip(m.KICK, false)
	m.attack_time = 7.0 / 30.0
	await wait(10)
	check(vm.arms_vm._leg_rig.visible, "Calcio in prima persona: gamba visibile")
	await _shot("fp_calcio")
	m.attacking = false
	m.set_physics_process(true)
	# ---- da fuori
	p.visible = false
	other = load("res://player/player.tscn").instantiate()
	other.local_control = false
	world.add_child(other)
	other.global_position = Vector3(6, 0.3, -28)
	world._dress(other, 2)
	world.actors[2] = other
	other.rig.camera.current = false
	cam = Camera3D.new()
	world.add_child(cam)
	cam.global_position = Vector3(7.6, 1.4, -26.2)
	cam.look_at(Vector3(6, 0.9, -28))
	other.visual.rotation.y = -0.6
	cam.current = true
	other.equipped = "axe"
	await wait(30)
	await _shot("fuori_ascia_ferma")
	other.equipped = ""
	await wait(30)
	await _shot("fuori_mani_vuote")
	other.equipped = "axe"
	await wait(20)
	var model = other.get_node("Visual").find_children("*", "Node3D", true, false).filter(func(n): return n.get("operative_driver") != null)[0].operative_driver.model
	cam.global_position = model.global_position + model.global_basis.x.normalized() * 3.2 + Vector3(0, 1.0, 0)
	cam.look_at(model.global_position + Vector3(0, 0.8, 0))
	print("calcio: durata clip ", model.clip_seconds("Player_Melee_Kick"))
	other.melee.attack_clip = "Kick"
	other.melee.attacking = true
	await wait(2)
	check(str(model._full_anim.animation) == "Player_Melee_Kick", "Da fuori parte la clip del calcio (%s)" % model._full_anim.animation)
	for k in 6:
		await wait(5)
		await _shot("fuori_calcio_%d" % k)
	other.melee.attacking = false
	other.melee.attack_clip = ""
	await wait(60)
	# Primi piani delle mani, di lato, con varie cose in mano (prima della raccolta: il gesto mette in pausa il rig).
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	for w in ["", "axe", "pistol", "machete"]:
		other.equipped = w
		await wait(40)
		check(model.tool_rig._pause <= 0.0, "Rig delle mani attivo con '%s'" % w)
		for side in ["l", "r"]:
			var at: Vector3 = skel.to_global(skel.get_bone_global_pose(skel.find_bone("hand_" + side)).origin)
			var out: Vector3 = model.global_basis.x.normalized() * (1.0 if side == "l" else -1.0)
			cam.global_position = at + out * 0.55 + model.global_basis.z.normalized() * 0.35 + Vector3(0, 0.1, 0)
			cam.look_at(at)
			await wait(1)
			await _shot("mano_%s_%s" % [w if w != "" else "vuote", side])
	cam.global_position = model.global_position + model.global_basis.x.normalized() * 3.2 + Vector3(0, 1.0, 0)
	cam.look_at(model.global_position + Vector3(0, 0.6, 0))
	print("raccolta: clip %.2f s" % model.clip_seconds("Player_Interact_Reach_Low"))
	world.survival._set_gesture(other, "pickup")
	for k in 8:
		await wait(30)
		await _shot("fuori_raccolta_%d" % k)
	check(model.tool_rig._pause <= 0.0, "Dopo 4 s dalla raccolta le mani tornano al rig (pausa %.2f)" % model.tool_rig._pause)
	print("MANO: %d errori %s" % [fails.size(), fails])
	quit(0 if fails.is_empty() else 1)


func _shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://mano/%s.png" % title)
	print("FOTO ", title)
