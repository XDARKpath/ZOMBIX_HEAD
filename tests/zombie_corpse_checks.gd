extends SceneTree
# Cadaveri degli infetti (art/zombie_ragdoll.gd) in una scena di prova: piano, scale, pendenza, muro, cassa, mucchio.
# Controlla che ogni corpo si fermi, resti fuori da pavimento e muri, senza NaN né esplosioni, con le giunture
# piegate dal verso giusto; poi budget, distanza, boss, decapitazione, repliche di rete e costo con 0 / 6 / 12 morti.
#   godot --path . --headless -s res://tests/zombie_corpse_checks.gd
#   foto prima/dopo (clip contro ragdoll), con finestra:  godot --path . --resolution 1280x720 -s res://tests/zombie_corpse_checks.gd -- --foto
const Ragdoll := preload("res://art/zombie_ragdoll.gd")
const SETTLE_LIMIT := 10.0
var fails := 0
var scene: Node3D
var cam: Camera3D
var next_id := 1


func _initialize() -> void:
	create_timer(600.0).timeout.connect(func(): print("FAIL tempo scaduto"); quit(2))
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1


func frames(n: int) -> void:
	for i in n: await physics_frame


func block(at: Vector3, size: Vector3, tilt := 0.0, color := Color("6f6a60")) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)
	scene.add_child(body)
	body.position = at
	body.rotation.x = tilt
	return body


func zombie(at: Vector3, kind := 0, facing := 0.0) -> CharacterBody3D:
	var e := CharacterBody3D.new()
	e.set_script(load("res://enemies/zombie_ai.gd"))     # load: gli autoload (AudioManager) esistono solo a partita avviata
	e.network_id = next_id
	next_id += 1
	scene.add_child(e)
	e.global_position = at
	e.setup(e.network_id % 3)
	e.rotation.y = facing
	if kind != 0: e.set_kind(kind)
	return e


func floor_at(x: float, z: float) -> float:
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 20, z), Vector3(x, -5, z), 1))
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


func kill(e: Node3D, push: Vector3, zone := "torso", weapon := "pistol") -> void:
	e.receive_hit(zone, 9999.0, push, weapon, true)


func mode(e: Node3D) -> String:
	return str(e.avatar.get_meta("zr", {}).get("mode", "?"))


func node(e: Node3D):
	return e.avatar.get_node_or_null("Ragdoll")


func bone_at(e: Node3D, bone: String) -> Vector3:
	var sk: Skeleton3D = e.avatar.skeleton
	return sk.global_transform * sk.get_bone_global_pose(e.avatar.bone_ids[bone]).origin


## Aspetta che tutti smettano di simulare; torna il tempo impiegato (o SETTLE_LIMIT).
func settle(list: Array) -> float:
	var t := 0.0
	while t < SETTLE_LIMIT:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if list.all(func(e): return mode(e) != "active"): break
	await process_frame
	return t


const POINTS := ["pelvis", "spine_02", "spine_03", "neck_01", "upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r", "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"]


## Corpo fermo, sopra il pavimento e fuori dai muri, giunture dal verso giusto.
func inspect(e: Node3D, what: String, took: float, top: float) -> void:
	var n = node(e)
	var life: float = n.life if n else -1.0
	if n: top = maxf(top, n.top_speed)
	check(mode(e) == "frozen", "%s: il corpo si ferma e si congela (%.1f s di simulazione%s, picco %.1f m/s, stato %s)" % [what, life, " = tetto, non si era calmato" if life >= Ragdoll.MAX_LIFE - 0.05 else "", top, mode(e)])
	check(top < 20.0, "%s: nessuna esplosione (picco %.1f m/s prima del limite di %.0f)" % [what, top, Ragdoll.MAX_SPEED])
	var space := scene.get_world_3d().direct_space_state
	var finite := true
	var inside: Array = []
	for bone in POINTS:
		var p := bone_at(e, bone)
		if not p.is_finite():
			finite = false
			continue
		var q := PhysicsPointQueryParameters3D.new()
		q.position = p
		q.collision_mask = 1
		if not space.intersect_point(q, 1).is_empty(): inside.append(bone)
	check(finite, "%s: nessun NaN nelle ossa" % what)
	check(inside.is_empty(), "%s: nessun osso dentro pavimento, gradini o muri %s" % [what, inside])
	var sk: Skeleton3D = e.avatar.skeleton
	var ids: Dictionary = e.avatar.bone_ids
	for side in ["l", "r"]:
		# Avanti del modello visto dall'osso a riposo, poi dove punta il segmento sotto.
		var thigh: int = ids["thigh_" + side]
		var fwd: Vector3 = sk.get_bone_global_rest(thigh).basis.inverse() * Vector3.BACK
		var shin: Vector3 = (sk.get_bone_global_pose(ids["foot_" + side]).origin - sk.get_bone_global_pose(ids["calf_" + side]).origin)
		var knee: float = (sk.get_bone_global_pose(thigh).basis.orthonormalized().inverse() * shin).normalized().dot(fwd.normalized())
		check(knee < 0.3, "%s: ginocchio %s non piegato al contrario (%.2f)" % [what, side, knee])
		var arm: int = ids["upperarm_" + side]
		var afwd: Vector3 = sk.get_bone_global_rest(arm).basis.inverse() * Vector3.BACK
		var fore: Vector3 = (sk.get_bone_global_pose(ids["hand_" + side]).origin - sk.get_bone_global_pose(ids["lowerarm_" + side]).origin)
		var elbow: float = (sk.get_bone_global_pose(arm).basis.orthonormalized().inverse() * fore).normalized().dot(afwd.normalized())
		check(elbow > -0.45, "%s: gomito %s non piegato all'indietro (%.2f)" % [what, side, elbow])


func cases() -> Array:
	# [nome, posizione, tipo, spinta]
	var stairs_z := 1.05
	return [
		["piano", Vector3(0, 0, 0), 0, Vector3(0, 0, 2.5)],
		["scale", Vector3(8, floor_at(8, stairs_z), stairs_z), 0, Vector3(0, 0, -2.5)],
		["pendenza", Vector3(16, floor_at(16, 0.0), 0.0), 0, Vector3(0, 0, -2.5)],
		["muro", Vector3(24, 0, 0), 0, Vector3(0, 0, -3.0)],
		["cassa", Vector3(32, 0.6, 0), 0, Vector3(0.6, 0, 1.5)],
	]


func build_world() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	var sun := DirectionalLight3D.new()
	scene.add_child(sun)
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.shadow_enabled = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("36414a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	scene.add_child(env)
	block(Vector3(30, -0.5, 0), Vector3(120, 1, 40), 0.0, Color("4d5a3f"))
	for k in 8:                                   # scale: gradini da 20 cm che salgono verso +Z
		var h := 0.2 * (k + 1)
		block(Vector3(8, h * 0.5, 0.15 + k * 0.3), Vector3(3, h, 0.3))
	block(Vector3(16, 0.0, 0.0), Vector3(3, 0.6, 6), deg_to_rad(-25.0))     # pendenza di 25° che sale verso +Z
	block(Vector3(24, 1.25, -0.75), Vector3(4, 2.5, 0.3))                   # muro dietro
	block(Vector3(32, 0.3, 0), Vector3(1.0, 0.6, 1.0), 0.0, Color("7a5a36"))  # cassa
	cam = Camera3D.new()
	scene.add_child(cam)
	cam.current = true


func aim(at: Vector3, from: Vector3) -> void:
	cam.global_position = at + from
	cam.look_at(at + Vector3.UP * 0.4)


func photo_dir() -> String:
	# La cartella screenshots/ sta nella radice "project gioco" (sopra ZOMBIX_HEAD o sopra il worktree).
	var dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	for i in 6:
		if DirAccess.dir_exists_absolute(dir + "/screenshots") and DirAccess.dir_exists_absolute(dir + "/runtime"): return dir + "/screenshots"
		dir = dir.get_base_dir()
	return ProjectSettings.globalize_path("user://")


func snap(title: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path := photo_dir() + "/corpse-" + title + ".png"
	root.get_texture().get_image().save_png(path)
	print("FOTO ", path)


func photos() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for row in cases():
		for physics in [false, true]:
			Ragdoll.enabled = physics
			var e := zombie(row[1], row[2], PI)
			var view: Vector3 = Vector3(2.6, 1.6, 2.6) if row[0] != "muro" else Vector3(2.8, 1.5, 1.8)
			aim(row[1], view)
			await frames(20)
			if physics: await snap("%s-0-vivo" % row[0])
			kill(e, row[3])
			await frames(8)
			await snap("%s-%s-caduta" % [row[0], "dopo" if physics else "prima"])
			await settle([e])
			await frames(40 if physics else 220)          # la clip di morte dura ~2 s: la foto "prima" a caduta finita
			await snap("%s-%s" % [row[0], "dopo" if physics else "prima"])
			e.queue_free()
			await frames(2)
	Ragdoll.enabled = true


## Millisecondi per frame intero (fisica + animazione), misurati con l'orologio. Valgono solo con --fixed-fps 60:
## così ogni frame fa un passo di fisica e non aspetta il tempo vero.
func timing(n: int) -> float:
	await process_frame
	var start := Time.get_ticks_usec()
	for i in n: await process_frame
	return float(Time.get_ticks_usec() - start) / 1000.0 / n


func run() -> void:
	build_world()
	await frames(5)
	if "--foto" in OS.get_cmdline_user_args():
		await photos()
		print("FOTO FATTE")
		quit(0)
		return
	cam.global_position = Vector3(20, 6, 14)          # vicino a tutti i casi (< 30 m)

	# --- Casi: muore e resta dove deve. Cinque insieme (budget 6), poi il mucchio.
	var list: Array = []
	for row in cases():
		var e := zombie(row[1], row[2], PI)
		list.append([row[0], e, row[3]])
	await frames(20)
	for row in list: kill(row[1], row[2])
	await frames(1)
	await process_frame
	for row in list: check(mode(row[1]) == "active", "%s: alla morte parte il ragdoll" % row[0])
	var tops := {}
	var t := 0.0
	while t < SETTLE_LIMIT and list.any(func(r): return mode(r[1]) == "active"):
		for row in list:
			var n = node(row[1])
			if n and mode(row[1]) == "active": tops[row[0]] = n.top_speed
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	await process_frame
	for row in list:
		var n = node(row[1])
		inspect(row[1], row[0], t, maxf(float(tops.get(row[0], 0.0)), n.top_speed if n else 0.0))
	# Fermo davvero: dopo un secondo le ossa sono dove erano.
	var before := bone_at(list[0][1], "head")
	await frames(60)
	check(before.distance_to(bone_at(list[0][1], "head")) < 0.001, "piano: congelato, la posa non si muove più")
	check(Ragdoll.active.is_empty(), "nessun ragdoll resta attivo dopo l'assestamento")

	# Non chiude i passaggi: un giocatore (maschera 1|4|8) attraversa il cadavere.
	var walker := CharacterBody3D.new()
	walker.collision_layer = 2
	walker.collision_mask = 13
	var cap := CollisionShape3D.new()
	cap.shape = CapsuleShape3D.new()
	cap.position.y = 0.9
	walker.add_child(cap)
	scene.add_child(walker)
	var lying := bone_at(list[0][1], "pelvis")
	walker.global_position = lying + Vector3(-1.5, -lying.y + 0.15, 0)    # capsula alta 2 m centrata a 0,9: i piedi a 5 cm da terra
	await frames(2)
	check(not walker.test_move(walker.global_transform, Vector3(3, 0, 0)), "il giocatore passa sopra/attraverso il cadavere")
	var alive := zombie(lying + Vector3(-1.5, -lying.y + 0.05, 0.5))
	alive.set_physics_process(false)
	check(not alive.test_move(alive.global_transform, Vector3(3, 0, 0)), "uno zombie vivo passa attraverso il cadavere")
	alive.queue_free()
	walker.queue_free()

	# --- Colpo al cadavere: impulso vero, si sveglia e si riassesta.
	var corpse: Node3D = list[0][1]
	var before_hit := {}
	for bone in POINTS: before_hit[bone] = bone_at(corpse, bone)
	corpse.receive_hit("torso", 30.0, Vector3(3, 0, 0), "pistol", true)
	await frames(1)
	await process_frame
	check(mode(corpse) == "active", "colpo al cadavere congelato: torna fisico")
	var took := await settle([corpse])
	var moved := 0.0
	for bone in POINTS: moved = maxf(moved, bone_at(corpse, bone).distance_to(before_hit[bone]))
	check(moved > 0.08, "il colpo lo sposta davvero (la parte più spostata di %.2f m)" % moved)
	inspect(corpse, "piano dopo il colpo", took, node(corpse).top_speed if node(corpse) else 0.0)

	# --- Mucchio: tre (bruto e mutato compresi) muoiono uno sull'altro, sopra un cadavere congelato.
	var pile: Array = []
	var base := Vector3(44, 0, 0)
	var first := zombie(base, 0, PI)
	await frames(10)
	kill(first, Vector3(0, 0, 1.0))
	await settle([first])
	for row in [[Vector3(0, 0, 0.4), 2], [Vector3(0.4, 0, -0.3), 3], [Vector3(-0.4, 0, 0.2), 1]]:
		pile.append(zombie(base + row[0], row[1], PI))
	await frames(10)
	for e in pile: kill(e, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	took = await settle(pile)
	for i in pile.size(): inspect(pile[i], "mucchio %d (tipo %d)" % [i, pile[i].kind], took, 0.0)
	var high := 0.0
	for e in pile: high = maxf(high, bone_at(e, "pelvis").y)
	print("  mucchio: bacino più alto a %.2f m" % high)

	# --- Decapitato da morto: la testa si stacca, il corpo resta fisico.
	var head_case := zombie(Vector3(14, 0, 8), 0, PI)
	await frames(10)
	kill(head_case, Vector3(0, 0, 1.5), "torso", "axe")
	await frames(5)
	head_case.receive_hit("neck", 40.0, Vector3(0, 0, 1.0), "axe", true)
	await frames(2)
	await process_frame
	check(head_case.beheaded and not head_case.avatar.head_piece.visible, "decapitato a terra: testa staccata e nascosta sul corpo")
	took = await settle([head_case])
	inspect(head_case, "decapitato", took, 0.0)

	# --- Esclusi: Carceriere e boss con skin propria restano sulla loro clip.
	var boss := zombie(Vector3(22, 0, 8), 5, PI)          # vicini alla camera: escluse per tipo, non per distanza
	var custom := zombie(Vector3(26, 0, 8), 0, PI)
	custom.custom_skin = "res://art/zx_infected/ZMB_Walker_1.glb"
	await frames(10)
	kill(boss, Vector3(0, 0, 1))
	kill(custom, Vector3(0, 0, 1))
	await frames(2)
	await process_frame
	check(mode(boss) == "clip", "Carceriere: morte a clip, niente ragdoll")
	check(mode(custom) == "clip", "boss con skin propria: morte a clip, niente ragdoll")

	# --- Lontano dalla camera (> 30 m): clip.
	var far := zombie(Vector3(80, 0, 0), 0, PI)
	cam.global_position = Vector3(80, 2, 40)
	await frames(10)
	kill(far, Vector3(0, 0, 1))
	await frames(2)
	await process_frame
	check(mode(far) == "clip", "a 40 m dalla camera: morte a clip")
	cam.global_position = Vector3(20, 6, 14)

	# --- Replica di rete: i campi arrivano dal sync, il ragdoll è solo locale e non tocca il corpo.
	var rep := zombie(Vector3(4, 0, 8), 0, PI)
	rep.replica = true
	await frames(10)
	var root_before := rep.global_position
	rep.dead = true
	rep.death_clock = 0.05
	rep.collision_layer = 0
	rep.hit_serial += 1
	rep.hit_zone = "torso"
	rep.hit_dir = Vector3(0, 0, -1)
	rep.hit_power = 1.0
	rep.hit_age = 0.0
	await frames(2)
	await process_frame
	check(mode(rep) == "active", "replica: morte dal sync, ragdoll locale")
	took = await settle([rep])
	inspect(rep, "replica", took, 0.0)
	check(rep.global_position.distance_to(root_before) < 0.001 and rep.dead and rep.health == rep.max_health, "replica: posizione, vita e stato non toccati dalla fisica")
	rep.hit_serial += 1
	rep.hit_dir = Vector3(1, 0, 0)
	await frames(1)
	await process_frame
	check(mode(rep) == "active", "replica: colpo al cadavere (hit_serial dal sync) lo risveglia")
	await settle([rep])
	var late := zombie(Vector3(6, 0, 10), 0, PI)
	late.replica = true
	late.dead = true
	late.death_clock = 6.0
	await frames(3)
	await process_frame
	check(mode(late) == "clip", "replica entrata dopo: cadavere vecchio con la clip finita, niente ragdoll da in piedi")

	# --- Budget e costo. Ogni giro: 12 infetti in piedi, poi ne muoiono 0, 6 o 12 insieme (vecchio modo = solo clip).
	for e in scene.get_children():
		if e is CharacterBody3D: e.queue_free()
	await frames(5)
	for row in [[0, true], [6, true], [12, true], [12, false]]:
		Ragdoll.enabled = row[1]
		var crowd: Array = []
		for i in 12: crowd.append(zombie(Vector3(-20 + (i % 4) * 2.0, 0, -10 + int(i / 4) * 2.5), 0, PI))
		cam.global_position = Vector3(-17, 6, 6)
		await frames(30)
		var standing := await timing(90)
		for i in row[0]: kill(crowd[i], Vector3(0, 0, 1.5))
		await frames(1)
		await process_frame
		var ragdolls := crowd.filter(func(e): return mode(e) == "active").size()
		var falling := await timing(90)
		await settle(crowd)
		var still := await timing(90)
		print("COSTO %2d morti %s: in piedi %.2f ms/frame, durante la caduta %.2f, dopo l'assestamento %.2f (%d ragdoll)" % [row[0], "ragdoll" if row[1] else "solo clip", standing, falling, still, ragdolls])
		if row[0] == 12 and row[1]:
			check(ragdolls == Ragdoll.MAX_ACTIVE, "12 morti insieme: %d ragdoll, gli altri %d con la clip (budget %d)" % [ragdolls, 12 - ragdolls, Ragdoll.MAX_ACTIVE])
		for e in crowd: e.queue_free()
		await frames(5)
	Ragdoll.enabled = true

	print("ESITO: %s (%d falliti)" % ["OK" if fails == 0 else "FALLITO", fails])
	quit(1 if fails > 0 else 0)