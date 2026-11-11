extends SceneTree
# Machete del Signore, fasi e barra del boss nell'HUD, caduta/rialzata coerente, morte da strisciante a terra,
# cadavere colpito dal fucile a pompa che arriva a terra, zombie che non si incastrano.
# Con la finestra fa foto in res://../ZOMBIX-HEAD-Boss-Foto/fix_*: godot --path . -s res://tests/zombie_boss_fix_checks.gd
var fails := 0
var world
var p
var cam: Camera3D
const SPOT := Vector3(6, 0.1, -60)


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1


func _initialize() -> void:
	call_deferred("run")


func shot(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.resize(960, 540)
	var dir := ProjectSettings.globalize_path("res://../ZOMBIX-HEAD-Boss-Foto")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/fix_" + id + ".png")


func frames(n: int) -> void:
	for i in n: await physics_frame


func look(at: Vector3, from: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


func torso_height(z) -> float:
	var v = z.avatar
	var low := INF
	for bone in ["pelvis", "spine_03", "head"]:
		if v.bone_ids.has(bone):
			low = minf(low, (v.skeleton.global_transform * v.skeleton.get_bone_global_pose(v.bone_ids[bone])).origin.y)
	return low - z.global_position.y


func zombie(at: Vector3):
	var z = world._spawn_enemy(at)
	z.set_kind(0)
	return z


func run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	var gps = world.get_node("Interface").find_child("RouteGPS", true, false)
	if gps: gps.opened = false
	p = world.player
	p.rig.set_physics_process(false)
	world.spawner.set_process(false)
	world.spawner.set_physics_process(false)
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)
	p.global_position = SPOT
	cam = Camera3D.new()
	cam.fov = 60
	root.add_child(cam)
	cam.current = true

	# --- 1. Signore delle Teste: a mani nude (niente machete), fasi, barra grande.
	var boss = world._spawn_enemy(SPOT + Vector3(0, 0, -7))
	boss.custom_skin = "res://art/zx_infected/BOSS_Subject_Zero.glb"
	boss.boss_weapon = "crown"
	boss.set_kind(5)
	boss.title = "SIGNORE DELLE TESTE"
	boss.max_health = 1300.0
	boss.health = 1300.0
	boss.use_brain("signore")
	check(boss.find_child("BossMachete", true, false) == null, "Il Signore delle Teste non ha il machete")
	check(boss.crown_node != null, "La corona c'è ancora")
	await frames(200)
	look(boss.global_position + Vector3.UP * 2.2, boss.global_position + Vector3(3.5, 3.0, 5.0))
	await shot("signore_machete")
	boss.brain.gap_left = 99.0
	boss.health = 1300.0 * 0.6
	await frames(4)
	check(boss.brain.phase == 1, "Sotto il 66%% passa alla fase 2 (%d)" % boss.brain.phase)
	check(boss.get_node_or_null("BossRage") != null, "Il cambio di fase si vede: aura sul boss")
	look(boss.global_position + Vector3.UP * 2.0, SPOT + Vector3(0, 2.0, 4.0))
	await frames(20)
	await shot("barra_boss_fase2")
	boss.health = 1300.0 * 0.25
	await frames(4)
	check(boss.brain.phase == 2, "Sotto il 33%% passa alla fase 3")
	await frames(20)
	await shot("barra_boss_fase3")
	boss.global_position += Vector3(0, -300, 0)
	boss.set_physics_process(false)
	boss.title = ""

	# --- 2. Caduta: un secondo colpo mentre è a terra non lo rimette in piedi.
	var z = zombie(SPOT + Vector3(2, 0, -4))
	z.set_physics_process(true)
	await frames(10)
	z.pending_reaction = "knockdown"
	z.reaction_dir = Vector3(0, 0, -1)
	z.receive_hit("torso", 5.0, Vector3(0, 0, -2), "sledgehammer", true)
	var long_down: float = z.stagger
	check(z.reaction == "knockdown" and long_down > 2.0, "Il colpo pesante lo butta a terra (%.1f s)" % long_down)
	await frames(40)
	look(z.global_position + Vector3.UP * 0.5, z.global_position + Vector3(2.5, 1.6, 2.5))
	await shot("caduta_a_terra")
	z.pending_reaction = "hit_left"
	z.reaction_dir = Vector3(1, 0, 0)
	z.receive_hit("torso", 5.0, Vector3(1, 0, 0), "axe", false)
	check(z.reaction == "knockdown" and z.stagger > 1.0, "Colpito a terra resta nella caduta (%s, %.1f s)" % [z.reaction, z.stagger])
	var clock := 0.0
	while z.reaction != "" and clock < 6.0:
		await physics_frame
		clock += 1.0 / 60.0
	check(clock > 2.5 and clock < 6.0, "Si rialza solo alla fine della clip (%.1f s)" % clock)
	await shot("rialzato")
	z.global_position += Vector3(0, -300, 0)

	# --- 3. Muore strisciando: resta disteso.
	var c = zombie(SPOT + Vector3(-2, 0, -4))
	c.set_physics_process(true)
	await frames(5)
	c.receive_hit("legs", 40.0, Vector3.ZERO, "axe", true)
	check(c.crawling and not c.dead, "Due gambe rotte: striscia")
	await frames(60)
	c.receive_hit("head", 200.0, Vector3.ZERO, "pistol", false)
	await frames(150)
	var h: float = torso_height(c)
	check(c.dead and h < 0.55, "Morto strisciando resta a terra (busto a %.2f m)" % h)
	look(c.global_position + Vector3.UP * 0.3, c.global_position + Vector3(2.0, 1.4, 2.0))
	await shot("morte_strisciante")
	c.global_position += Vector3(0, -300, 0)

	# --- 4. Fucile a pompa: spinto in alto da morto, il corpo arriva a terra.
	var s = zombie(SPOT + Vector3(0, 0, -5))
	s.set_physics_process(true)
	await frames(5)
	s.receive_hit("torso", 300.0, Vector3(0, 6.0, -9.0), "pump_shotgun", true)
	for i in 6:
		await frames(3)
		s.receive_hit("torso", 20.0, Vector3(0, 4.0, -6.0), "pump_shotgun", true)
	await frames(200)
	var hs: float = torso_height(s)
	var ray := PhysicsRayQueryParameters3D.create(s.global_position + Vector3.UP, s.global_position + Vector3.DOWN * 5.0, 1)
	var hit: Dictionary = s.get_world_3d().direct_space_state.intersect_ray(ray)
	var above: float = s.global_position.y - (hit.position as Vector3).y if not hit.is_empty() else 0.0
	check(hs < 0.55 and above < 0.3, "Ucciso dal pompa il cadavere è a terra (busto %.2f, corpo %.2f m sopra il suolo)" % [hs, above])
	look(s.global_position + Vector3.UP * 0.3, s.global_position + Vector3(2.4, 1.5, 2.4))
	await shot("cadavere_pompa")
	s.global_position += Vector3(0, -300, 0)

	# --- 5. Muro in mezzo: lo zombie gira attorno e arriva.
	var wall := StaticBody3D.new()
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7, 3, 0.6)
	box.shape = shape
	wall.add_child(box)
	world.add_child(wall)
	wall.global_position = SPOT + Vector3(0, 1.5, -4)
	var w = zombie(SPOT + Vector3(0, 0, -8))
	w.set_physics_process(true)
	w.hear(p, 40)
	var start: float = w.global_position.distance_to(p.global_position)
	clock = 0.0
	while clock < 20.0 and w.global_position.distance_to(p.global_position) > 2.2:
		await physics_frame
		clock += 1.0 / 60.0
		p.health = 100.0
	var end_d: float = w.global_position.distance_to(p.global_position)
	check(end_d < 2.6, "Dietro un muro di 7 m gira attorno e arriva (%.1f -> %.1f m in %.1f s)" % [start, end_d, clock])
	print("FINE ", "OK" if fails == 0 else "FALLITI %d" % fails)
	quit(fails)
