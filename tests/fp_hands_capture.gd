extends SceneTree
# Le braccia v3 con ogni tipo d'arma: res://../screenshots/hands-<arma>.png (griglia in hands-grid*.png)
func _initialize(): call_deferred("run")
func shot(id: String, wait := 0.5):
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.resize(640, 360)
	img.save_png(ProjectSettings.globalize_path("res://../screenshots/hands-" + id + ".png"))
func grid(name: String, ids: Array) -> void:
	var out := Image.create(640 * 3, 360 * (ids.size() + 2) / 3, false, Image.FORMAT_RGBA8)
	for i in ids.size():
		var part := Image.load_from_file(ProjectSettings.globalize_path("res://../screenshots/hands-" + ids[i] + ".png"))
		part.convert(Image.FORMAT_RGBA8)
		out.blit_rect(part, Rect2i(0, 0, 640, 360), Vector2i(640 * (i % 3), 360 * (i / 3)))
	out.save_png(ProjectSettings.globalize_path("res://../screenshots/hands-grid-" + name + ".png"))
func run():
	var world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	world.get_node("Interface").visible = false
	var gps = world.get_node("Interface").find_child("RouteGPS", true, false)
	if gps: gps.opened = false
	var p = world.player
	p.set_physics_process(false)
	p.rig.set_physics_process(false)
	for e in world.targets: e.set_physics_process(false)
	p.position = Vector3(8, 0.1, -11)
	p.rig.yaw = 0
	p.rig.pitch = -0.1
	p.rig.reset_follow()
	p.arrows = 5
	var weapons := ["axe", "knife", "pistol", "machete", "crowbar", "nail_bat", "pickaxe", "katana", "runic_axe", "spartan_sword", "assault_rifle", "pump_shotgun", "sawn_off", "flare_gun", "bow", "item_bende"]
	for w in weapons:
		p.equipped = w
		await shot(w, 0.9)
	grid("armi1", weapons.slice(0, 9))
	grid("armi2", weapons.slice(9, 18))
	var m = p.melee
	m.set_physics_process(false)
	p.equipped = "axe"
	await create_timer(0.8).timeout
	var ids := []
	for row in [["light1", m.COMBO[0], false, 1.0], ["light2", m.COMBO[1], false, -1.0], ["heavy", m.HEAVY, true, 1.0]]:
		m.swing_side = row[3] * -1.0
		m._begin_clip(row[1], row[2])
		var r: Array = row[1]
		for phase in [["wind", r[1] * 0.7], ["hit", (r[1] + r[2]) * 0.5], ["end", r[3] * 0.7]]:
			m.attack_time = phase[1] / 30.0
			await shot("axe-%s-%s" % [row[0], phase[0]], 0.12)
			ids.append("axe-%s-%s" % [row[0], phase[0]])
	m.attacking = false
	await create_timer(0.4).timeout
	grid("colpi", ids)
	m.blocking = true
	await shot("axe-block", 0.5)
	m.blocking = false
	await create_timer(0.3).timeout
	m._begin_clip(m.KICK, false)
	m.attack_time = 7.0 / 30.0
	await shot("axe-kick", 0.15)
	m.attacking = false
	m.charging = true
	m.charge_time = 0.8
	await shot("axe-charge", 0.2)
	m.charging = false
	p.sprinting = true
	await shot("axe-sprint", 0.4)
	p.sprinting = false
	grid("azioni", ["axe-block", "axe-kick", "axe-charge", "axe-sprint"])
	quit()
