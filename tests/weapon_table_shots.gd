extends SceneTree
# Il tavolo e ogni arma in mano: un foglio da fuori, uno in prima persona, uno per i colpi delle famiglie.
#   godot --path . --resolution 1280x720 --fixed-fps 30 -s res://tests/weapon_table_shots.gd -- <cartella> [tavolo|fuori|fp|colpi]
var world: Node3D
var cam: Camera3D
var folder := ""
var sheet: Image
var cell := 0
const W := 240
const H := 200
const COLUMNS := 8


func _init() -> void:
	call_deferred("_run")


func frames(n: int) -> void:
	for i in n: await process_frame


func start(rows: int) -> void:
	sheet = Image.create(W * COLUMNS, H * rows, false, Image.FORMAT_RGB8)
	cell = 0


func take() -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(W, H, Image.INTERPOLATE_BILINEAR)
	sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(cell % COLUMNS * W, cell / COLUMNS * H))
	cell += 1


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[0]
	var only: Array = args.slice(1)
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
	var p: CharacterBody3D = world.player
	var ids: Array = world.weapon_table.ORDER
	cam = Camera3D.new()
	cam.fov = 45.0
	world.add_child(cam)
	if only.is_empty() or "tavolo" in only:
		cam.current = true
		p.visible = false
		var at: Vector3 = world.weapon_table.global_position
		for row in [[Vector3(7.5, 3.0, 0), at], [Vector3(2.5, 1.7, -3.2), at + Vector3(0, 0.85, -3.2)], [Vector3(2.5, 1.7, 3.2), at + Vector3(0, 0.85, 3.2)], [Vector3(0, 7, 0.01), at]]:
			cam.global_position = at + row[0]
			cam.look_at(row[1])
			await frames(3)
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(folder.path_join("tavolo_%d.png" % cell))
			cell += 1
	var other: CharacterBody3D = load("res://player/player.tscn").instantiate()
	other.local_control = false
	world.add_child(other)
	other.global_position = Vector3(14, 140, -60)
	world._dress(other, 2)
	world.actors[2] = other
	other.rig.camera.current = false
	other.set_physics_process(false)
	await frames(10)
	var face: float = other.visual.global_rotation.y + PI
	if only.is_empty() or "fuori" in only:
		cam.current = true
		p.visible = false
		start(4)
		for id in ids:
			if id == "knife": other.equipped = "knife"
			else: other.equipped = id
			await frames(20)
			var c: Vector3 = other.global_position + Vector3.UP * 1.05
			cam.global_position = c + Vector3(sin(face + 0.75) * 2.6, 0.2, cos(face + 0.75) * 2.6)
			cam.look_at(c)
			await take()
		sheet.save_png(folder.path_join("fuori_armi.png"))
	world.actors.erase(2)
	if only.is_empty() or "fp" in only or "colpi" in only or "spari" in only or String(only[0]).begins_with("pieno:"):
		other.queue_free()
		p.visible = true
		p.set_physics_process(true)
		p.controls_enabled = true
		p.rig.controls_enabled = false
		p.rig.pitch = -0.04
		p.reset_at(Vector3(40, 0.3, -30))
		p.rig.camera.current = true
		p.inventory_slots = 40
	if only.is_empty() or "fp" in only:
		start(4)
		for id in ids:
			if id == "bow": continue
			p.owned.assign([id])
			p.hotbar[0] = id
			p.equip_id(id)
			await frames(20)
			await take()
		sheet.save_png(folder.path_join("fp_armi.png"))
	for arg in only:
		if not String(arg).begins_with("pieno:"): continue
		var id: String = String(arg).get_slice(":", 1)
		p.owned.assign([id])
		p.hotbar[0] = id
		p.equip_id(id)
		await frames(25)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(folder.path_join("pieno_" + id + ".png"))
	if "spari" in only:
		var dummy: Node3D = world._spawn_enemy(Vector3(40, 0.3, -36), 800)
		dummy.set_physics_process(false)
		dummy.health = 100000.0
		dummy.max_health = 100000.0
		start(4)
		for id in ids:
			if not preload("res://weapons/zx_arsenal.gd").is_gun(id): continue
			p.owned.assign([id])
			p.hotbar[0] = id
			p.equip_id(id)
			p.magazine = 30
			await frames(16)
			p.melee.perform_attack(false)
			await frames(1)
			await take()
			await frames(2)
			await take()
			await frames(40)
		sheet.save_png(folder.path_join("spari.png"))
	if only.is_empty() or "colpi" in only:
		for id in ["pickaxe", "katana", "machete", "crowbar", "knife", "assault_rifle", "pump_shotgun"]:
			start(3)
			p.owned.assign([id])
			p.hotbar[0] = id
			p.equip_id(id)
			await frames(25)
			if preload("res://weapons/zx_arsenal.gd").is_gun(id):
				p.magazine = 8
				p.melee.perform_attack(false)
				await frames(1)
				p.melee._aim_strike()
				for k in 8:
					await frames(2)
					await take()
				await frames(10)
				p.reload_left = 2.0
				for k in 16:
					await frames(4)
					await take()
				p.reload_left = 0.0
			else:
				for v in 3:
					p.stamina = 100.0
					p.melee.begin_charge()
					p.melee.release_attack()
					for k in 8:
						await frames(3)
						await take()
					while p.melee.attacking: await process_frame
					await frames(4)
			sheet.save_png(folder.path_join("colpi_" + id + ".png"))
	print("FINE")
	quit(0)
