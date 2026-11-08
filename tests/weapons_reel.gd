extends SceneTree
# Il video di controllo: il tavolo, ogni arma da fuori e in prima persona, gli infetti che scavalcano e aggirano.
#   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie video.avi -s res://tests/weapons_reel.gd
var world: Node3D
var cam: Camera3D
var label: Label
var p: CharacterBody3D
const STAGE := Vector3(400, 200, 400)
const Arsenal := preload("res://weapons/zx_arsenal.gd")


func _init() -> void:
	call_deferred("_run")


func frames(seconds: float) -> void:
	for i in int(seconds * 30.0): await process_frame


func say(text: String) -> void:
	label.text = text


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	view.mesh = mesh
	body.add_child(view)
	world.add_child(body)
	body.global_position = at + Vector3.UP * size.y * 0.5


func _run() -> void:
	var mode: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	DisplayServer.window_set_size(Vector2i(1280, 720))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	world.spawner.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.queue_free()
	world.get_node("Interface").visible = false
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(40, 630)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("ffe2b0"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	layer.add_child(label)
	cam = Camera3D.new()
	cam.fov = 45.0
	world.add_child(cam)
	p = world.player
	# --- Il tavolo
	cam.current = true
	p.visible = false
	var table: Node3D = world.weapon_table
	say("IL TAVOLO · tutte le armi, all'inizio del gioco")
	var t := 0.0
	while t < 5.0:
		t += 1.0 / 30.0
		cam.global_position = table.global_position + Vector3(4.6, 2.0, lerpf(-4.5, 4.5, t / 5.0))
		cam.look_at(table.global_position + Vector3(0, 0.85, lerpf(-3.0, 3.0, t / 5.0)))
		await process_frame
	# --- Palco
	_box(Vector3(300, 2, 300), STAGE + Vector3.DOWN * 2.0, Color("4a4f4c"))
	var other: CharacterBody3D = load("res://player/player.tscn").instantiate()
	other.local_control = false
	world.add_child(other)
	other.global_position = STAGE
	world._dress(other, 2)
	world.actors[2] = other
	other.rig.camera.current = false
	other.set_physics_process(false)
	await frames(0.5)
	var face: float = other.visual.global_rotation.y + PI
	if mode != "fp":
		for id in table.ORDER:
			if id == "bow": continue
			other.global_position = STAGE
			other.equipped = id
			var gun: bool = Arsenal.is_gun(id)
			say("VISTO DA UN ALTRO GIOCATORE · " + Arsenal.display_name(id))
			# Quello che vede chi ti sta accanto: gira attorno a te, all'altezza degli occhi.
			var angle: float = face + 0.7
			var tick := func(extra: float) -> void:
				angle += extra
				var c: Vector3 = other.global_position + Vector3.UP * 1.1
				cam.global_position = c + Vector3(sin(angle) * 3.6, 0.45, cos(angle) * 3.6)
				cam.look_at(c)
			for k in 18:
				tick.call(0.01)
				await process_frame
			# Corre.
			var way: Vector3 = -other.visual.global_basis.z
			for k in 30:
				other.velocity = way * 4.0
				other.global_position += way * 4.0 / 30.0
				tick.call(0.01)
				await process_frame
			other.velocity = Vector3.ZERO
			for k in 8:
				tick.call(0.01)
				await process_frame
			# Colpisce o spara.
			for i in (3 if gun else 3):
				other.melee.charged_attack = not gun and i == 2
				other.melee.attacking = true
				for k in 2:
					tick.call(0.006)
					await process_frame
				other.melee.attacking = false
				for k in (11 if gun else 28):
					tick.call(0.006)
					await process_frame
			if gun:
				say("VISTO DA UN ALTRO GIOCATORE · " + Arsenal.display_name(id) + " · ricarica")
				other.reload_left = 1.6
				for k in 52:
					tick.call(0.006)
					await process_frame
				other.reload_left = 0.0
			else:
				say("VISTO DA UN ALTRO GIOCATORE · " + Arsenal.display_name(id) + " · parata")
				other.melee.remote_block = true
				for k in 24:
					tick.call(0.006)
					await process_frame
				other.melee.remote_block = false
				for k in 8: await process_frame
	if mode == "fuori":
		print("FINE")
		quit(0)
		return
	world.actors.erase(2)
	other.queue_free()
	# --- Prima persona
	p.visible = true
	p.set_physics_process(true)
	p.controls_enabled = true
	p.rig.controls_enabled = false
	p.rig.pitch = -0.04
	p.reset_at(STAGE + Vector3(0, 0.3, 30))
	p.rig.camera.current = true
	p.inventory_slots = 8
	for id in table.ORDER:
		if id == "bow": continue
		p.owned.assign([id])
		p.hotbar[0] = id
		p.equip_id(id)
		p.magazine = 30
		say("PRIMA PERSONA · " + Arsenal.display_name(id))
		await frames(0.7)
		if Arsenal.is_gun(id):
			for i in 2:
				p.melee.perform_attack(false)
				await frames(0.1)
				p.melee._aim_strike()
				await frames(0.35)
			if id in ["pistol", "assault_rifle", "pump_shotgun", "revolver"]:
				say("PRIMA PERSONA · " + Arsenal.display_name(id) + " · ricarica")
				p.reload_weapon()
				await frames(2.2)
		else:
			for i in 2:
				p.stamina = 100.0
				p.melee.begin_charge()
				await frames(0.05)
				p.melee.release_attack()
				var guard := 0
				while p.melee.attacking and guard < 90:
					guard += 1
					await process_frame
	# --- Infetti
	p.owned.assign(["axe"])
	p.hotbar[0] = "axe"
	p.equip_id("axe")
	p.visible = false
	p.set_physics_process(false)
	p.global_position = STAGE + Vector3(0, 0.1, 100)
	cam.current = true
	var base := STAGE + Vector3(60, 0, 60)
	p.global_position = base
	_box(Vector3(10, 0.8, 0.6), base + Vector3(-22, 0, -6), Color("6a5e49"))
	_box(Vector3(8, 3.5, 0.6), base + Vector3(0, 0, -5), Color("6a5e49"))
	_box(Vector3(0.6, 3.5, 5), base + Vector3(-4, 0, -7.5), Color("6a5e49"))
	_box(Vector3(0.6, 3.5, 5), base + Vector3(4, 0, -7.5), Color("6a5e49"))
	for row in [["INFETTO · scavalca un muretto", 0, Vector3(-22, 0.15, -11), Vector3(-29, 3.0, -2)], ["CORRIDORE · trappola a U: esce e gira attorno", 1, Vector3(0, 0.15, -8), Vector3(9, 8, -3)], ["BRUTO · trappola a U", 2, Vector3(0, 0.15, -8), Vector3(9, 8, -3)], ["BOSS · muretto e poi da te", 5, Vector3(-22, 0.15, -11), Vector3(-29, 4.0, -2)]]:
		var e: Node3D = world._spawn_enemy(base + row[2], 900 + row[1])
		e.global_position = base + row[2]
		e.set_kind(row[1])
		e.spit_cooldown = 999.0
		e.leap_cooldown = 999.0
		if row[2].x < -10.0: p.global_position = base + Vector3(-22, 0.1, 0)
		else: p.global_position = base
		e.hear(p, 60.0)
		say(row[0])
		t = 0.0
		while t < 14.0:
			t += 1.0 / 30.0
			e.memory = 6.0
			cam.global_position = base + row[3]
			cam.look_at(e.global_position + Vector3.UP)
			await process_frame
			if t > 2.0 and e.global_position.distance_to(p.global_position) < 2.4: break
		await frames(0.8)
		e.queue_free()
	print("FINE")
	quit(0)
