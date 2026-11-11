extends SceneTree
# Forzieri originali (world/campaign/loot_chest.gd) nella Zona 1, nel Borgo e nella Rocca; niente casse verdi né casse delle armi.
# Poi l'ombra del giocatore in prima persona con ogni cosa in mano: mai la T-pose.
# Foto: res://../screenshots/chest-*.png e shadow-*.png.  godot --path . -s res://tests/loot_chest_checks.gd
var fails := 0
var world: Node3D
var p: CharacterBody3D
func _initialize(): call_deferred("run")
func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1
func shot(id: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/" + id + ".png"))
func look(from: Vector3, at: Vector3) -> void:
	p.global_position = from
	p.velocity = Vector3.ZERO
	var d: Vector3 = (at - (from + Vector3.UP * p.eye_height)).normalized()
	p.rig.yaw = atan2(-d.x, -d.z)
	p.rig.pitch = asin(clampf(d.y, -1.0, 1.0))
	if p.rig.has_method("reset_follow"): p.rig.reset_follow()
func lid_angle(chest: Node3D) -> float:
	return chest.get_node("Lid").rotation.x
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
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)
	p = world.player
	p.set_physics_process(false)
	p.rig.camera.current = true
	# niente modelli di casse verdi o casse delle armi in scena
	var banned := ["SM_Int_Chest_Supply", "SM_Int_Chest_Military", "SM_Prop_AmmoCrate_Wood", "SM_Prop_AmmoCan_Military", "SM_Prop_Container_01"]
	var found := []
	for n in root.find_children("*", "Node3D", true, false):
		if str(n.get_path()).contains("CampfireStage"): continue      # il palco del menu del campo, fuori dalla mappa
		for b in banned:
			if n.scene_file_path.contains(b): found.append(n.get_path())
	check(found.is_empty(), "Nessuna cassa verde o cassa delle armi sulla mappa %s" % [found.slice(0, 3)])
	# Zona 1: forzieri del kit
	var kit = world.zone_kit
	check(kit.chests.size() >= 3, "Forzieri della Zona 1: %d" % kit.chests.size())
	var c0: Dictionary = kit.chests[0]
	world.terrain.ensure_near([c0.node.global_position])
	p.global_position = c0.node.global_position + c0.node.global_basis * Vector3(0, 0.1, 1.2)
	var hp_before: float = p.health
	p.health = 40.0
	var credits: int = p.credits
	check(kit.chest_context(p).begins_with("E  ") and kit.open_chest(p), "Il forziere della casa del Vecchio si apre")
	check(p.health > 40.0 or p.credits > credits, "Dà bende o soldi")
	check(not kit.open_chest(p), "Si apre una volta sola")
	p.health = hp_before
	await create_timer(0.6).timeout
	check(lid_angle(c0.node) < -1.5, "Il coperchio resta aperto")
	# Borgo Cenere: forzieri liberi
	var v = world.village
	v.set_process(false)
	var free := []
	for ch in v.chests:
		if ch.free: free.append(ch)
	check(free.size() >= 3, "Forzieri liberi nel Borgo: %d" % free.size())
	var f0: Dictionary = free[0]
	world.terrain.ensure_near([f0.pos])
	await create_timer(0.3).timeout
	look(f0.pos + Vector3(0, 0, -2.6), f0.pos + Vector3(0, 0.4, 0))
	await shot("chest-borgo-chiuso")
	p.global_position = f0.pos + Vector3(0, 0, -1.4)
	credits = p.credits
	check(v.context(p).begins_with("E  ") and v.request_use(p), "[E] apre un forziere del Borgo senza aver battuto il boss")
	check(p.credits == credits + 60, "Il forziere del Borgo dà 60 crediti")
	check(not v.request_use(p) or p.credits == credits + 60, "Il forziere del Borgo non si riapre")
	await create_timer(0.6).timeout
	look(f0.pos + Vector3(0, 0, -2.6), f0.pos + Vector3(0, 0.4, 0))
	await shot("chest-borgo-aperto")
	# Rocca: forzieri nuovi e pickup
	var r = world.rocca
	var ch = r.chests[5]                 # il forziere del boss, accanto all'altare: stanza libera per la foto
	ch.visible = true
	look(ch.global_position + ch.global_basis * Vector3(0.8, 0, 2.6), ch.global_position + Vector3(0, 0.3, 0))
	await shot("chest-rocca-chiuso")
	var picks: int = r.pickups.size()
	r.open_chest(5)
	await create_timer(0.7).timeout
	check(ch.opened and r.pickups.size() == picks + ch.loot.size(), "Forziere della Rocca aperto, escono %d oggetti" % ch.loot.size())
	look(ch.global_position + ch.global_basis * Vector3(0.8, 0, 2.6), ch.global_position + Vector3(0, 0.3, 0))
	await shot("chest-rocca-aperto")
	# Ombra in prima persona: per ogni cosa in mano il braccio sinistro non sta mai orizzontale.
	var spot := Vector3(0, 0, -30)
	world.terrain.ensure_near([spot])
	await create_timer(0.3).timeout
	var ground: float = world.terrain.height(spot.x, spot.z) if world.terrain.has_method("height") else 0.0
	p.global_position = Vector3(spot.x, ground + 0.05, spot.z)
	p.rig.yaw = 0.0
	p.rig.pitch = -1.1
	var sk: Skeleton3D = p.visual.find_children("*", "Skeleton3D", true, false)[0]
	for id in ["", "axe", "pistol", "assault_rifle", "item_cibo", "item_testa"]:
		p.equipped = id
		await create_timer(0.8).timeout
		var up := sk.get_bone_global_pose(sk.find_bone("upperarm_l")).origin
		var hand := sk.get_bone_global_pose(sk.find_bone("hand_l")).origin
		var up_r := sk.get_bone_global_pose(sk.find_bone("upperarm_r")).origin
		var hand_r := sk.get_bone_global_pose(sk.find_bone("hand_r")).origin
		var ok := up.y - hand.y > 0.1 or up_r.y - hand_r.y > 0.1
		check(ok, "Ombra con '%s': braccia non in T-pose (sx %.2f, dx %.2f sotto la spalla)" % [id, up.y - hand.y, up_r.y - hand_r.y])
		await shot("shadow-" + (id if id != "" else "mani"))
	print("LOOT CHEST %s (%d errori)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
