extends SceneTree
# Foto della Zona 1: godot --path . -s res://tests/zone1_showcase.gd  (user://showcase/*.png). Borgo Cenere: tests/borgo_photos.gd
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
const RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
var world: Node3D
var p: CharacterBody3D
var cam: Camera3D
var ui: CanvasLayer
var number := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://showcase"))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	p = world.player
	ui = world.get_node("Interface")
	cam = Camera3D.new()
	world.add_child(cam)
	world.spawner.set_process(false)
	await _photos()
	quit(0)


func _still_enemies() -> void:
	p.health = 100.0
	for e in world.targets:
		if is_instance_valid(e): e.set_physics_process(false)


func _clear_town() -> void:
	for e in world.targets:
		if is_instance_valid(e): e.queue_free()
	world.targets.clear()


func _load_near(at: Vector3, also: Vector3 = at) -> void:
	world.terrain.ensure_near([at, also])
	p.set_physics_process(false)
	p.reset_at(Vector3(at.x, world.terrain.height(at.x, at.z) + 0.3, at.z))
	# Il giocatore non deve finire nell'inquadratura: la foto è del luogo.
	p.visible = false


func _h(at: Vector3, above := 1.7) -> Vector3:
	return Vector3(at.x, world.terrain.height(at.x, at.z) + above, at.z)


## Foto dei luoghi, senza interfaccia.
func _place(title: String, eye: Vector3, look: Vector3, wait := 25) -> void:
	_load_near(eye, look)
	ui.visible = false
	for i in wait: await process_frame
	cam.global_position = eye
	cam.look_at(look)
	cam.current = true
	for i in 6: await process_frame
	await _snap(title)


func _snap(title: String) -> void:
	await RenderingServer.frame_post_draw
	number += 1
	root.get_texture().get_image().save_png("user://showcase/%02d_%s.png" % [number, title])
	print("FOTO ", title)


## Foto in prima persona, con l'interfaccia vera.
func _fps(at: Vector3, face: Vector3, pitch := -0.05) -> void:
	world.terrain.ensure_near([at])
	ui.visible = true
	p.set_physics_process(true)
	p.visible = true
	p.reset_at(_h(at, 0.3))
	p.controls_enabled = true
	p.rig.controls_enabled = false
	var to := face - at
	p.rig.yaw = atan2(-to.x, -to.z)
	p.rig.pitch = pitch
	p.rig.camera.current = true
	for i in 20: await physics_frame


func _photos() -> void:
	var tower: Node3D = world.rocca.entrance_node
	var arena: Vector3 = world.boss_hunt.rows[0][1]
	var gate: Vector3 = world.fence.gates[0].at
	_still_enemies()
	# --- Recinto
	await _place("recinto_dal_prato", _h(gate + Vector3(4, 0, -22)), gate + Vector3(0, 2, 0))
	await _place("recinto_dall_alto", Vector3(-30, 13, -60), Vector3(8, 0, -24))
	await _place("recinto_lato", _h(Vector3(46, 0, -20)), Vector3(30, 1.5, -40))
	await _place("recinto_interno", _h(gate + Vector3(3, 0, 14)), gate + Vector3(0, 2, 0))
	# portone che si apre
	p.set_physics_process(false)
	p.reset_at(gate + Vector3(0, 0.3, 4))
	p.visible = false
	ui.visible = false
	for i in 70: await process_frame
	cam.global_position = _h(gate + Vector3(3, 0, -10))
	cam.look_at(gate + Vector3(0, 1.5, 6))
	cam.current = true
	for i in 4: await process_frame
	await _snap("portone_aperto")
	# --- Torre della Rocca
	await _place("rocca_dalla_pista", tower.to_global(Vector3(2.5, 1.7, 21)), tower.to_global(Vector3(0, 2.0, 0)))
	await _place("rocca_cortile", tower.to_global(Vector3(-5.5, 1.7, 14)), tower.to_global(Vector3(1, 1.5, 3)))
	await _place("rocca_portone", tower.to_global(Vector3(0, 1.7, 7.5)), tower.to_global(Vector3(0, 0.6, 0)))
	await _place("rocca_aiuole", tower.to_global(Vector3(5.5, 1.0, 8.5)), tower.to_global(Vector3(-1, 1.0, 2.5)))
	await _place("rocca_dentro_scala", tower.to_global(Vector3(0, 1.75, 1.5)), tower.to_global(Vector3(0, -1.7, -3.2)))
	await _place("rocca_meta_scala", tower.to_global(Vector3(0, -0.6, -2.0)), tower.to_global(Vector3(0, -3.0, -7)))
	await _place("rocca_arco", tower.to_global(Vector3(0, -2.0, -4.3)), tower.to_global(Vector3(0, -2.2, -9)))
	await _place("rocca_dall_alto", tower.to_global(Vector3(15, 12, 21)), tower.to_global(Vector3(0, 0, 4)))
	await _place("rocca_bruno", tower.to_global(Vector3(-1.5, 1.7, 13)), tower.to_global(Vector3(7, 0.8, 7)))
	# --- Radura
	await _place("radura_ingresso", _h(arena + Vector3(15, 0, 10)), arena + Vector3(0, 1, 2))
	await _place("radura_centro", _h(arena + Vector3(-6, 0, -7)), arena + Vector3(3, 1, 6))
	await _place("radura_altare", _h(arena + Vector3(5, 0, 10)), arena + Vector3(0, 0.5, 4.6))
	await _place("radura_alto", arena + Vector3(-11, 13, 11), arena)
	# --- Tipi di infetti per zona
	_clear_town()
	var show := Vector3(6, 0, -70)
	var kinds := [0, 1, 2, 3, 4]
	for i in kinds.size():
		var e: Node3D = world._spawn_enemy(_h(show + Vector3(float(i) * 1.8 - 3.6, 0, 0), 0.1))
		e.set_kind(kinds[i], 2)
		e.set_physics_process(false)
		e.rotation.y = 0.0
	await _place("infetti_tipi", _h(show + Vector3(0, 0, 6)), show + Vector3(0, 1, 0))
	_clear_town()
	# --- Boss
	p.baits = 2
	world.quest.stage = world.quest.FOREST_BOSS
	world.boss_hunt.summon(0)
	world.boss_hunt.bosses[0].set_physics_process(false)
	await _place("boss_capomacello", _h(arena + Vector3(4, 0, 9)), arena + Vector3(0, 1.5, 0))
	for boss in world.boss_hunt.bosses: boss.queue_free()
	world.boss_hunt.bosses.clear()
	root.get_node("AudioManager").clear_bosses()
	# --- In prima persona: mani vuote, ferme e in cammino
	world.quest.stage = world.quest.TALK
	await _fps(Vector3(4, 0, -22), Vector3(4, 0, -44))
	p.select_slot(-1)
	for i in 30: await physics_frame
	await _snap("mani_vuote_fermo")
	Input.action_press("move_forward")
	for i in 50: await physics_frame
	await _snap("mani_vuote_cammina")
	Input.action_press("sprint")
	for i in 45: await physics_frame
	await _snap("mani_vuote_corsa_1")
	for i in 11: await physics_frame
	await _snap("mani_vuote_corsa_2")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	# --- Teste per tipo in tasca e prezzi
	for id in ["item_testa", "item_testa", "item_testa", "item_testa_bruto"]: p.add_item(id)
	await _fps(Layout.SHERIFF_NPC + Vector3(-2.2, 0, 0.3), Layout.SHERIFF_NPC + Vector3(0, 1.0, 0))
	p.equip_id("item_testa")
	for i in 30: await physics_frame
	await _snap("testa_normale_prezzo")
	p.equip_id("item_testa_bruto")
	for i in 30: await physics_frame
	await _snap("testa_bruto_prezzo")
	# --- Dialogo dello sceriffo
	world.survival.open_sheriff_dialogue()
	for i in 90: await process_frame
	await _snap("sceriffo_dialogo")
	world.survival.close_sheriff_dialogue()
	world.quest.stage = world.quest.KILL_TWO
	for i in 5: await process_frame
	# --- Obiettivo e segnalino
	await _fps(Vector3(4, 0, -38), Vector3(4, 0, -70))
	await _snap("obiettivo_e_segnalino")
	# --- GPS sul PDA
	world.quest.stage = world.quest.FOREST_BOSS
	world.quest.delivered = 5
	var key := InputEventKey.new()
	key.physical_keycode = KEY_G
	key.pressed = true
	Input.parse_input_event(key)
	for i in 80: await physics_frame
	await _snap("gps_missioni")
	key = InputEventKey.new()
	key.physical_keycode = KEY_G
	key.pressed = false
	Input.parse_input_event(key)
