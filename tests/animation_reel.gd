extends SceneTree
# Il video delle animazioni: modelli e codice del gioco vero, su un palco sgombro dove nessun albero copre la vista.
#   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie video.avi -s res://tests/animation_reel.gd
var world: Node3D
var p: CharacterBody3D
var cam: Camera3D
var label: Label
var title_layer: CanvasLayer
const AT := Vector3(14, 0, -78)
const STAGE_Y := 140.0


func _init() -> void:
	call_deferred("_run")


func frames(seconds: float) -> void:
	for i in int(seconds * 30.0): await process_frame


func _say(text: String) -> void:
	label.text = text
	print("SCENA ", text)


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	world.spawner.set_process(false)
	p = world.player
	for e in world.targets:
		if is_instance_valid(e): e.queue_free()
	title_layer = CanvasLayer.new()
	title_layer.layer = 50
	root.add_child(title_layer)
	label = Label.new()
	label.position = Vector2(40, 620)
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color("ffe2b0"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	title_layer.add_child(label)
	cam = Camera3D.new()
	world.add_child(cam)
	world.terrain.ensure_near([AT])
	_stage()
	world.get_node("Interface").visible = false
	p.visible = false
	p.set_physics_process(false)
	p.reset_at(AT + Vector3(0, 0.4, 40))
	cam.current = true
	await _zombie_section("INFETTO", 0, AT)
	await _zombie_section("CORRIDORE", 1, AT + Vector3(9, 0, 0))
	await _zombie_section("BRUTO", 2, AT + Vector3(18, 0, 0))
	await _spitter(AT + Vector3(-9, 0, 0))
	await _macellaio(AT + Vector3(-18, 0, 0))
	await _others_section(AT + Vector3(0, 0, 10))
	await _first_person(AT + Vector3(4, 0, 22))
	print("FINE")
	quit(0)


func _stage() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(400, 400)
	plane.mesh = mesh
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color("4a4f4c"))
	for i in 64:
		img.set_pixel(i, 0, Color("6d736f"))
		img.set_pixel(0, i, Color("6d736f"))
	var look := StandardMaterial3D.new()
	look.albedo_texture = ImageTexture.create_from_image(img)
	look.uv1_scale = Vector3(200, 200, 1)
	look.roughness = 1.0
	plane.material_override = look
	floor_body.add_child(plane)
	world.add_child(floor_body)
	floor_body.global_position = Vector3(AT.x, STAGE_Y, AT.z)


func _h(at: Vector3) -> Vector3:
	return Vector3(at.x, STAGE_Y + 0.02, at.z)


func _look(target: Node3D, angle: float, dist: float, high: float = 1.5) -> void:
	var c: Vector3 = target.global_position + Vector3.UP * 1.0
	# Gli infetti guardano verso -Z: l'angolo 0 li riprende di fronte.
	cam.global_position = c + Vector3(sin(angle) * dist, high - 1.0, -cos(angle) * dist)
	cam.look_at(c)


func _enemy(kind: int, at: Vector3) -> Node3D:
	var e: Node3D = world._spawn_enemy(_h(at), 100 + kind * 4)
	e.set_kind(kind)
	e.set_physics_process(false)
	e.rotation.y = 0.0
	return e


func _attack(e: Node3D, clip: String, turn: float) -> void:
	var timing: Array = load("res://art/infected_motion.gd").attack_timing(clip)
	e.attack_clip = clip
	e.attack_hit = timing[1]
	e.attack_clock = 0.0
	e.state = 2
	var t := 0.0
	while t < float(timing[0]):
		t += 1.0 / 30.0
		e.attack_clock = t
		_look(e, turn, 3.2)
		await process_frame
	e.state = 0
	await frames(0.25)


func _walk(e: Node3D, speed: float, seconds: float, angle: float) -> void:
	var t := 0.0
	var dir: Vector3 = -e.global_basis.z
	e.state = 1 if speed > 1.0 else 0
	while t < seconds:
		t += 1.0 / 30.0
		e.velocity = dir * speed
		e.global_position += dir * speed / 30.0
		e.global_position.y = STAGE_Y + 0.02
		_look(e, angle, 3.6)
		await process_frame
	e.velocity = Vector3.ZERO
	e.state = 0


func _zombie_section(name: String, kind: int, at: Vector3) -> void:
	var e := _enemy(kind, at)
	_look(e, 0.5, 3.6)
	_say(name + " · fermo")
	await frames(2.2)
	if kind == 0:
		_say(name + " · ti vede e urla")
		e.alert_time = 2.0
		e.state = 1
		await frames(1.8)
		e.alert_time = 0.0
		e.state = 0
	_say(name + " · cammina" if kind != 1 else "CORRIDORE · corre")
	await _walk(e, {0: 0.95, 1: 4.2, 2: 0.8}[kind], 2.8, 0.75)
	e.global_position = _h(at)
	_say(name + " · attacchi")
	var clips: Array = {0: ["Z_Attack_Swipe_R", "Z_Attack_Headbutt", "Z_Attack_Swipe_L", "Z_Attack_Jab"], 1: ["Z_Attack_Leap", "Z_Attack_Swipe_R"], 2: ["Z_Attack_Overhead_Smash", "Z_Tank_Swipe", "Z_Tank_Punch"]}[kind]
	for clip in clips: await _attack(e, clip, 0.9)
	_say(name + " · colpito")
	var dirs := [Vector3(0, 0, 2), Vector3(2, 0, 0), Vector3(-2, 0, 0)]
	var zones := ["torso", "head", "torso"]
	for i in 3:
		_look(e, 0.4, 3.0)
		e.pending_reaction = "hit_left" if i == 1 else "hit_right"
		e.reaction_dir = dirs[i]
		e.health = e.max_health
		e.receive_hit(zones[i], 18.0, dirs[i], "axe", false)
		await frames(0.9)
	e.health = e.max_health
	if kind != 2:
		_say(name + " · calcio: cade e si rialza")
		e.pending_reaction = "knockdown"
		e.reaction_dir = Vector3(0, 0, 1)
		e.receive_hit("torso", 5.0, Vector3.ZERO, "kick", true)
		await frames(minf(4.5, e.stagger + 0.2))
	_say(name + " · morto")
	e.receive_hit("torso", 99999.0, Vector3(0, 0, 2), "axe", true)
	await frames(2.6)
	_say(name + " · la lama stacca la testa dal cadavere")
	_look(e, 0.6, 2.8, 1.6)
	e.receive_hit("head", 20.0, Vector3.ZERO, "axe", false)
	await frames(1.6)
	world.survival.heads.clear()
	world.survival._publish()
	e.queue_free()
	await process_frame


func _spitter(at: Vector3) -> void:
	var e := _enemy(4, at)
	e.state = 1
	_say("SPUTATORE · si riempie la bocca e sputa")
	for i in 3:
		var timing: Array = load("res://art/infected_motion.gd").attack_timing("Z_Spit")
		e.attack_clip = "Z_Spit"
		e.attack_hit = timing[1]
		e.state = 2
		var t := 0.0
		var fired := false
		while t < float(timing[0]):
			t += 1.0 / 30.0
			e.attack_clock = t
			_look(e, 0.9, 3.0)
			if t >= float(timing[1]) and not fired:
				fired = true
				preload("res://enemies/spit_projectile.gd").launch(world, e.mouth_position(), e.global_position - e.global_basis.z * 9.0, true)
			await process_frame
		e.state = 1
		await frames(0.5)
	e.queue_free()
	await frames(0.5)


func _macellaio(at: Vector3) -> void:
	var e: Node3D = world._spawn_enemy(_h(at), 300)
	e.custom_skin = "res://art/zx_infected/BOSS_Subject_Zero.glb"
	e.boss_weapon = "cleaver"
	e.set_kind(5)
	e._dress()
	e.set_physics_process(false)
	e.rotation.y = 0.0
	_say("IL MACELLAIO DEL BORGO")
	var t := 0.0
	while t < 2.0:
		t += 1.0 / 30.0
		_look(e, 0.3 + t * 0.2, 5.6, 2.2)
		await process_frame
	await _walk(e, 0.9, 2.2, 0.6)
	for clip in ["Z_Tank_Swipe", "Z_Attack_Overhead_Smash"]:
		await _attack(e, clip, 0.7)
	e.queue_free()
	await process_frame


func _others_section(at: Vector3) -> void:
	# Il personaggio come lo vedono gli altri giocatori in partita.
	var other: CharacterBody3D = load("res://player/player.tscn").instantiate()
	other.local_control = false
	world.add_child(other)
	other.global_position = _h(at)
	world._dress(other, 2)
	world.actors[2] = other
	other.rig.camera.current = false
	cam.current = true
	other.set_physics_process(false)
	await frames(0.6)
	var ring := func(angle: float) -> void:
		var c: Vector3 = other.global_position + Vector3.UP * 1.0
		cam.global_position = c + Vector3(sin(angle) * 2.6, 0.4, cos(angle) * 2.6)
		cam.look_at(c)
	ring.call(0.6)
	_say("IL TUO PERSONAGGIO VISTO DAGLI ALTRI · a mani vuote")
	other.equipped = ""
	await frames(2.0)
	var move := func(seconds: float, speed: float, sprint: bool, dir: Vector3) -> void:
		var t := 0.0
		while t < seconds:
			t += 1.0 / 30.0
			other.velocity = dir * speed
			other.sprinting = sprint
			other.global_position += dir * speed / 30.0
			other.global_position.y = STAGE_Y + 0.02
			ring.call(0.9)
			await process_frame
		other.velocity = Vector3.ZERO
		other.sprinting = false
	var forward: Vector3 = -other.visual.global_basis.z
	_say("cammina piano")
	await move.call(2.4, 1.4, false, forward)
	_say("corre (velocità normale del gioco)")
	await move.call(2.2, 4.0, false, forward)
	_say("scatto")
	await move.call(2.0, 7.0, true, forward)
	other.global_position = _h(at)
	_say("indietro")
	await move.call(1.6, 4.0, false, -forward)
	_say("di lato")
	await move.call(1.6, 4.0, false, other.visual.global_basis.x)
	other.global_position = _h(at)
	_say("accucciato")
	other.crouching = true
	await frames(1.0)
	await move.call(1.8, 1.4, false, forward)
	other.crouching = false
	other.global_position = _h(at)
	_say("con l'ascia · fermo")
	other.equipped = "axe"
	ring.call(0.7)
	await frames(1.6)
	_say("con l'ascia · corre")
	await move.call(2.0, 4.0, false, forward)
	other.global_position = _h(at)
	ring.call(1.0)
	for i in 4:
		_say("con l'ascia · colpo %d" % (i + 1) if i < 3 else "con l'ascia · colpo caricato")
		if i == 3:
			other.melee.charging = true
			other.melee.charge_time = 0.8
			await frames(0.8)
			other.melee.charging = false
		other.melee.attacking = true
		other.melee.charged_attack = i == 3
		await frames(0.07)
		other.melee.attacking = false
		await frames(1.3)
	_say("parata")
	other.melee.remote_block = true
	await frames(1.3)
	other.melee.remote_block = false
	_say("pistola · ferma")
	other.equipped = "pistol"
	ring.call(0.8)
	await frames(1.5)
	_say("pistola · spara")
	for i in 3:
		other.melee.attacking = true
		await frames(0.07)
		other.melee.attacking = false
		await frames(0.5)
	_say("pistola · ricarica")
	other.reload_left = 1.6
	await frames(1.8)
	other.reload_left = 0.0
	other.equipped = "axe"
	await frames(0.5)
	_say("colpito · sbalzato")
	other.damaged.emit(10.0)
	await frames(1.1)
	other.set_meta("hit_heavy_until", Time.get_ticks_msec() + 500)
	await frames(1.3)
	_say("in mano ha una testa")
	other.items["item_testa"] = 1
	other.equipped = "item_testa"
	await frames(1.4)
	_say("la consegna")
	world.survival._set_gesture(other, "give")
	await frames(1.6)
	_say("si fascia il braccio")
	other.items["item_bende"] = 1
	other.equipped = "item_bende"
	await frames(0.5)
	ring.call(0.3)
	world.survival._set_gesture(other, "use")
	await frames(3.0)
	ring.call(0.7)
	_say("lancia")
	world.survival._set_gesture(other, "throw")
	await frames(1.6)
	other.equipped = ""
	_say("saluta")
	world.survival._set_gesture(other, "wave")
	await frames(2.2)
	_say("cade")
	other.dead = true
	await frames(2.6)
	world.actors.erase(2)
	other.queue_free()
	await process_frame


func _first_person(at: Vector3) -> void:
	p.visible = true
	p.set_physics_process(true)
	p.controls_enabled = true
	p.rig.controls_enabled = false
	p.rig.pitch = -0.04
	p.rig.yaw = 0.0
	p.reset_at(_h(at) + Vector3.UP * 0.3)
	p.equip_id("axe")
	p.rig.camera.current = true
	var dummy := _enemy(0, at + Vector3(0.2, 0, -2.0))
	dummy.rotation.y = PI
	dummy.health = 100000.0
	dummy.max_health = 100000.0
	_say("PRIMA PERSONA · ascia")
	await frames(2.0)
	_say("colpi uno dopo l'altro")
	for i in 3:
		p.stamina = 100.0
		p.melee.begin_charge()
		await frames(0.08)
		p.melee.release_attack()
		while p.melee.attacking: await process_frame
	_say("parata")
	p.melee.block_forced = true
	await frames(1.2)
	p.melee.block_forced = false
	await frames(0.5)
	_say("colpo caricato")
	p.stamina = 100.0
	p.melee.begin_charge()
	await frames(1.0)
	p.melee.release_attack()
	await frames(1.3)
	_say("si guarda l'ascia")
	p.rig.get_node_or_null(".")
	var vm: Node = p.rig.camera.get_node_or_null("Viewmodel")
	if vm: vm.inspect()
	await frames(2.6)
	_say("mani vuote")
	p.select_slot(-1)
	dummy.queue_free()
	await frames(1.0)
	_say("TESTA IN MANO")
	p.add_item("item_testa")
	p.equip_id("item_testa")
	await frames(2.2)
	_say("PISTOLA")
	p.owned.append("pistol")
	p.magazine = 8
	p.equip_id("pistol")
	await frames(1.6)
	for i in 2:
		p.melee.perform_attack(false)
		await frames(0.12)
		p.melee._aim_strike()
		await frames(0.45)
	_say("PISTOLA · mira col tasto destro")
	p.melee.ads_forced = true
	await frames(1.0)
	for i in 2:
		p.melee.perform_attack(false)
		await frames(0.12)
		p.melee._aim_strike()
		await frames(0.45)
	p.melee.ads_forced = false
	await frames(0.8)
	_say("PISTOLA · ricarica")
	p.reload_weapon()
	await frames(2.2)
