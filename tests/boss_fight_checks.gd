extends SceneTree
# I boss nel gioco vero, colpo per colpo: chi resta fermo si fa male, chi si sposta in tempo no, ogni boss teme la sua arma.
# Con la finestra fa foto in res://../ZOMBIX-HEAD-Boss-Foto/; con --headless solo i controlli: godot --path . -s res://tests/boss_fight_checks.gd
var fails := 0
var world
var p
var cam: Camera3D
const SPOT := Vector3(6, 0.1, -60)
const MOVES := {
	"capomacello": ["slam", "sweep", "spin", "rift", "leap", "boulder", "inferno"],
	"macellaio": ["combo", "guardbreak", "charge", "hook", "cleaver", "blood"],
	"carceriere": ["slam", "spin", "quake", "chain", "cage", "debris", "fissure", "leap"],
}
const SKINS := {"capomacello": "res://art/zx_infected/BOSS_Sheriff_Abomination.glb", "macellaio": "res://art/zx_infected/BOSS_Subject_Zero.glb", "carceriere": ""}
const LAMPS := {"capomacello": "lamp", "macellaio": "cleaver", "carceriere": ""}


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1


func _initialize() -> void:
	call_deferred("run")


func shot(id: String) -> void:
	# Senza finestra niente foto, ma i controlli girano lo stesso (--headless).
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.resize(960, 540)
	var dir := ProjectSettings.globalize_path("res://../ZOMBIX-HEAD-Boss-Foto")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/" + id + ".png")


func clear_world() -> void:
	world.spawner.set_process(false)
	world.spawner.set_physics_process(false)
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)


func spawn(style: String):
	var boss = world._spawn_enemy(SPOT + Vector3(0, 0, -6))
	boss.custom_skin = SKINS[style]
	boss.boss_weapon = LAMPS[style]
	boss.set_kind(5)
	boss.max_health = 2000.0
	boss.health = 2000.0
	boss.use_brain(style)
	boss.rotation.y = 0.0
	# L'ingresso: foto a metà e al ruggito, e intanto non prende colpi.
	check(boss.brain.in_intro(), "%s entra in scena col suo ingresso" % style)
	var clock := 0.0
	var shots := [0.5, 1.15]
	while boss.brain.in_intro() and clock < 5.0:
		await physics_frame
		clock += 1.0 / 60.0
		cam.global_position = boss.global_position + Vector3(6.5, 4.5, 9.0)
		cam.look_at(boss.global_position + Vector3.UP * 2.0, Vector3.UP)
		if not shots.is_empty() and clock > shots[0]:
			await shot("%s_ingresso_%d" % [style, 3 - shots.size()])
			shots.pop_front()
			if shots.size() == 1:
				var before: float = boss.health
				boss.receive_hit("torso", 100.0, Vector3.ZERO, "axe", false)
				check(boss.health == before, "%s non prende danno durante l'ingresso" % style)
	check(not boss.brain.in_intro(), "%s finisce l'ingresso (%.1f s)" % [style, clock])
	for i in 12: await physics_frame
	return boss


func heal() -> void:
	p.dead = false
	p.health = 100.0
	p.stamina = 100.0
	p.status.clear_all()


func frame(boss) -> void:
	var look: Vector3 = (boss.global_position + p.global_position) * 0.5 + Vector3.UP * 1.0
	cam.global_position = look + Vector3(9.5, 7.5, 11.5)
	cam.look_at(look, Vector3.UP)


## Lascia finire il colpo e fotografa a metà e nel momento dell'impatto. Quanta vita ha tolto?
func run_move(boss, style: String, id: String, offset: Vector3) -> float:
	heal()
	p.global_position = boss.global_position + offset
	await physics_frame
	boss.brain.gap_left = 99.0
	boss.brain.begin(id)
	var windup: float = float(boss.brain.move.get("windup", 0.5))
	var clock := 0.0
	var shot_a := false
	var shot_b := false
	var low := 100.0
	while clock < 9.0:
		await physics_frame
		clock += 1.0 / 60.0
		frame(boss)
		low = minf(low, p.health)
		if p.dead: heal()
		if not shot_a and clock > windup * 0.8:
			shot_a = true
			await shot("%s_%s_1_avviso" % [style, id])
		if not shot_b and clock > windup + 0.28:
			shot_b = true
			await shot("%s_%s_2_colpo" % [style, id])
		if boss.brain.move.is_empty(): boss.brain.gap_left = 99.0
		if clock > windup + 0.3 and boss.brain.move.is_empty() and boss.brain.stun <= 0.0: break
	# Effetti ritardati (onde, sassi).
	for i in 70:
		await physics_frame
		boss.brain.gap_left = 99.0
		low = minf(low, p.health)
		if p.dead: heal()
	return 100.0 - low


func run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	world.get_node("Interface").visible = false
	var gps = world.get_node("Interface").find_child("RouteGPS", true, false)
	if gps: gps.opened = false
	p = world.player
	p.rig.set_physics_process(false)
	clear_world()
	p.global_position = SPOT
	cam = Camera3D.new()
	cam.fov = 60
	root.add_child(cam)
	cam.current = true
	for style in MOVES:
		var boss = await spawn(style)
		check(boss.brain != null and boss.brain.style == style, "%s: il cervello è attaccato" % style)
		for id in MOVES[style]:
			var offset := Vector3(0, 0, 3.0) if id not in ["charge", "hook", "cleaver", "leap", "rift", "boulder", "cage"] else Vector3(0, 0, 8.0)
			boss.brain.phase = 1
			boss.brain.stun = 0.0
			boss.global_position = SPOT + Vector3(0, 0, -6)
			boss.rotation.y = PI
			var lost: float = await run_move(boss, style, id, offset)
			print("  ", style, " ", id, " toglie ", snappedf(lost, 0.1))
			if id != "blood": check(lost > 0.0, "%s · %s colpisce chi resta fermo (%.0f)" % [style, id, lost])
			else: check(boss.brain.hazards.size() > 0, "%s · %s lascia le pozze" % [style, id])
			boss.brain.hazards.clear()
			boss.brain.bars.clear()
			boss.brain.waves.clear()
			boss.brain.events.clear()
			heal()
			p.global_position = SPOT + Vector3(0, 0, 30)
			await create_timer(0.3).timeout
		# Chi si sposta durante l'avviso non si fa niente.
		boss.global_position = SPOT + Vector3(0, 0, -6)
		boss.rotation.y = PI
		boss.brain.phase = 0
		heal()
		p.global_position = boss.global_position + Vector3(0, 0, 3.5)
		await physics_frame
		for i in 90:
			await physics_frame
			boss.brain.gap_left = 99.0
		heal()
		var dodge_move: String = "combo" if style == "macellaio" else "slam"
		boss.brain.begin(dodge_move)
		await create_timer(float(boss.brain.move.windup) * 0.75).timeout
		p.global_position = boss.global_position + Vector3(14, 0, 14)
		await create_timer(1.6).timeout
		check(p.health >= 100.0, "%s: chi schiva non si fa male (%.0f)" % [style, p.health])
		boss.brain.move = {}
		boss.brain.waves.clear()
		boss.brain.hazards.clear()
		boss.brain.gap_left = 99.0
		boss.brain.exposed = 0.0
		await physics_frame
		await test_weakness(boss, style)
		# La morte, ognuno la sua.
		p.global_position = SPOT + Vector3(0, 0, 30)
		boss.brain.stun = 0.0
		boss.brain.exposed = 0.0
		boss.health = 1.0
		boss.receive_hit("torso", 500.0, Vector3.ZERO, "axe", false)
		check(boss.dead and boss.brain.dying, "%s muore con la sua morte" % style)
		for k in 2:
			await create_timer(0.35 if k == 0 else 1.0).timeout
			cam.global_position = boss.global_position + Vector3(6.5, 4.5, 9.0)
			cam.look_at(boss.global_position + Vector3.UP * 1.5, Vector3.UP)
			await shot("%s_morte_%d" % [style, k + 1])
		boss.queue_free()
		for i in 5: await physics_frame
	# Scoperto, prende di più.
	print("BOSS ", "OK" if fails == 0 else "FALLITO %d" % fails)
	quit(fails)


func dealt(boss, weapon: String, amount := 100.0) -> float:
	boss.health = 5000.0
	boss.max_health = 5000.0
	boss.brain.exposed = 0.0
	boss.brain.pop_clock = 0.0
	boss.receive_hit("torso", amount, Vector3.ZERO, weapon, false)
	return 5000.0 - boss.health


func test_weakness(boss, style: String) -> void:
	var b = boss.brain
	b.target = p
	match style:
		"capomacello":
			var pistol := dealt(boss, "pistol")
			check(is_equal_approx(pistol, 55.0), "Capomacello: la pistola quasi non lo graffia (%.0f)" % pistol)
			var axe := dealt(boss, "axe")
			check(is_equal_approx(axe, 100.0), "Capomacello: l'ascia fa danno pieno (%.0f)" % axe)
			var flare := dealt(boss, "flare_gun")
			check(flare > 200.0 and b.burning > 0.0, "Capomacello: il lanciarazzi lo incendia (%.0f)" % flare)
			var burning_axe := dealt(boss, "axe")
			b.stun = 0.0
			check(burning_axe > axe, "Capomacello: mentre brucia tutto fa di più (%.0f)" % burning_axe)
			await shot("capomacello_brucia")
		"macellaio":
			var arrow := dealt(boss, "bow")
			check(is_equal_approx(arrow, 50.0), "Macellaio: non sente le frecce (%.0f)" % arrow)
			var shotgun := dealt(boss, "sawn_off")
			check(shotgun > 200.0, "Macellaio: le canne mozze fanno male (%.0f)" % shotgun)
			b.stun = 0.0
			p.global_position = boss.global_position + Vector3(0, 0, 4)
			b.begin("charge")
			await create_timer(0.3).timeout
			dealt(boss, "sawn_off")
			check(b.stun > 0.0 and b.move.is_empty(), "Macellaio: il fucile lo ferma a metà carica")
			await shot("macellaio_fermato")
			b.stun = 0.0
			b.move = {}
			# Carica contro un muro: stordito.
			var wall := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(12, 5, 1)
			shape.shape = box
			wall.add_child(shape)
			world.add_child(wall)
			wall.global_position = boss.global_position + Vector3(0, 2, 7)
			p.global_position = boss.global_position + Vector3(0, 0, 11)
			boss.rotation.y = PI
			b.begin("charge")
			var waited := 0.0
			while waited < 4.0 and b.stun <= 0.0:
				await physics_frame
				waited += 1.0 / 60.0
			check(b.stun > 0.0, "Macellaio: schiantato contro il muro resta stordito")
			frame(boss)
			await shot("macellaio_schiantato")
			wall.queue_free()
			b.stun = 0.0
		_:
			var pistol := dealt(boss, "pistol")
			check(is_equal_approx(pistol, 30.0), "Carceriere: la pistola rimbalza sulla corazza (%.0f)" % pistol)
			var crowbar := dealt(boss, "crowbar", 40.0)
			check(is_equal_approx(crowbar, 40.0) and b.plate_hp < b.PLATE_HP, "Carceriere: il piede di porco intacca la piastra")
			while b.plates > 0:
				dealt(boss, "crowbar", 120.0)
				b.stun = 0.0
			check(b.plates == 0, "Carceriere: la corazza si rompe")
			var after := dealt(boss, "pistol")
			check(after > 100.0, "Carceriere: senza corazza fa male tutto (%.0f)" % after)
	# Scoperto: prende di più.
	var plain := dealt(boss, "axe")
	b.exposed = 2.0
	boss.health = 5000.0
	boss.receive_hit("torso", 100.0, Vector3.ZERO, "axe", false)
	var open: float = 5000.0 - boss.health
	b.exposed = 0.0
	check(open > plain, "%s: scoperto prende di più (%.0f contro %.0f)" % [style, open, plain])
