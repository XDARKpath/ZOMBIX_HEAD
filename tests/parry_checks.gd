extends SceneTree
# Parata direzionale (player.gd resolve_guard/take_damage, zombix.gd hit_player): fronte/lato/retro,
# fiato pieno/minimo/zero, colpi ambientali e pesanti, effetti e spinta dallo stesso esito, guardia rotta.
# godot --path . --headless -s res://tests/parry_checks.gd
var world: Node3D
var p: CharacterBody3D
var fails := 0
var seen: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1


## Costante di player.gd (null se non c'è: su origin/main la parata non ha esiti).
func k(name: String) -> Variant:
	return p.get_script().get_script_constant_map().get(name)


func _initialize() -> void:
	call_deferred("run")


## Colpo da `dir` (in metri rispetto al giocatore, che guarda verso -Z). Torna la salute persa.
func hit(dir: Vector3, amount: float, fx: Dictionary, stamina: float) -> float:
	p.status.clear_all()
	p.health = 100.0
	p.stamina = stamina
	p.knock_velocity = Vector3.ZERO
	p.melee.blocking = true
	world.hit_player(p, amount, fx, p.global_position + dir)
	p.melee.blocking = false
	return 100.0 - p.health


func run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	for i in 30: await physics_frame
	world.spawner.set_process(false)
	for e in world.targets: e.set_physics_process(false)
	p = world.player
	p.rig.yaw = 0.0
	if p.has_signal("guard_result"): p.guard_result.connect(func(r): seen.append(r))
	var full: float = p.max_stamina()
	var front := Vector3(0, 0, -2)
	var side := Vector3(2, 0, 0)
	var back := Vector3(0, 0, 2)

	# --- direzione, fiato pieno
	var d := hit(front, 20.0, {}, full)
	check(is_equal_approx(d, 5.0), "Fronte, fiato pieno: un quarto del danno (%.1f)" % d)
	d = hit(Vector3(1.2, 0, -2), 20.0, {}, full)
	check(is_equal_approx(d, 5.0), "Fronte un po' di lato (31 gradi): parato (%.1f)" % d)
	d = hit(side, 20.0, {}, full)
	check(is_equal_approx(d, 20.0), "Lato (90 gradi): non si para (%.1f)" % d)
	d = hit(back, 20.0, {}, full)
	check(is_equal_approx(d, 20.0), "Retro: non si para (%.1f)" % d)
	d = hit(Vector3.ZERO, 20.0, {}, full)
	check(is_equal_approx(d, 5.0), "Colpo a contatto (origine sul giocatore): conta come frontale (%.1f)" % d)

	# --- fiato minimo e zero: assorbimento parziale e guardia rotta
	seen.clear()
	d = hit(front, 20.0, {}, 1.0)
	check(d > 15.0 and d < 20.0, "Fiato minimo: assorbe solo una parte (%.2f)" % d)
	check(p.stamina == 0.0, "Fiato minimo: il fiato va a zero")
	check(float(p.get("guard_broken_left") if p.get("guard_broken_left") != null else 0.0) > 0.0, "Fiato minimo: guardia rotta")
	check(seen.has(k("GUARD_BROKEN")) and k("GUARD_BROKEN") != null, "Segnale per l'HUD: guardia rotta")
	d = hit(front, 20.0, {}, full)
	check(is_equal_approx(d, 20.0), "Guardia rotta: il colpo dopo passa intero anche col fiato pieno (%.1f)" % d)
	var wait_s: float = float(k("GUARD_BREAK_SECONDS")) if k("GUARD_BREAK_SECONDS") != null else 1.2
	await create_timer(wait_s + 0.3).timeout
	seen.clear()
	d = hit(front, 20.0, {}, full)
	check(is_equal_approx(d, 5.0), "Dopo il recupero si para di nuovo (%.1f)" % d)
	check(seen.has(k("GUARD_BLOCKED")) and k("GUARD_BLOCKED") != null, "Segnale per l'HUD: parata riuscita")
	if p.get("guard_broken_left") != null: p.guard_broken_left = 0.0
	d = hit(front, 20.0, {}, 0.0)
	check(is_equal_approx(d, 20.0), "Fiato zero: danno intero (%.1f)" % d)
	if p.get("guard_broken_left") != null: p.guard_broken_left = 0.0

	# --- tipi di colpo
	d = hit(front, 20.0, {"env": true, "poison": 4.0}, full)
	check(is_equal_approx(d, 20.0) and float(p.status.left.poison) > 0.0, "Ambientale (acido/veleno/fuoco): non si para, effetto pieno (%.1f)" % d)
	check(p.stamina == full, "Ambientale: la parata non consuma fiato")
	d = hit(front, 20.0, {"heavy": true}, full)
	check(is_equal_approx(d, 10.0), "Pesante davanti: si para a metà (%.1f)" % d)
	check(is_equal_approx(p.stamina, full - 16.0), "Pesante: costa il doppio del fiato (%.1f)" % p.stamina)
	if p.has_method("take_damage") and p.get_method_argument_count("take_damage") >= 3:
		p.health = 100.0; p.stamina = full; p.melee.blocking = true
		p.take_damage(20.0, Vector3.INF, "env")
		p.melee.blocking = false
		check(is_equal_approx(p.health, 80.0), "Trappola (take_damage env senza origine): non si para (%.1f)" % (100.0 - p.health))
	else:
		check(false, "take_damage accetta origine e tipo del colpo")
	p.health = 100.0; p.stamina = full; p.melee.blocking = true
	p.take_damage(20.0)
	p.melee.blocking = false
	check(is_equal_approx(p.health, 95.0), "Chiamante vecchio take_damage(20) senza origine: parato come prima (%.1f)" % (100.0 - p.health))
	if p.get("guard_broken_left") != null: p.guard_broken_left = 0.0

	# --- effetti e spinta: lo stesso esito della parata
	hit(front, 10.0, {"bleed": 6.0, "stun": 1.0, "knock": Vector3(0, 0, 8)}, full)
	check(float(p.status.left.bleed) == 0.0, "Parato: niente sanguinamento")
	check(is_equal_approx(float(p.status.left.stun), 0.5), "Parato: stordimento dimezzato (%.2f)" % float(p.status.left.stun))
	var front_push: float = p.knock_velocity.length()
	hit(back, 10.0, {"bleed": 6.0, "stun": 1.0, "knock": Vector3(0, 0, 8)}, full)
	check(float(p.status.left.bleed) > 0.0, "Da dietro: sanguina")
	check(is_equal_approx(float(p.status.left.stun), 1.0), "Da dietro: stordimento pieno")
	var back_push: float = p.knock_velocity.length()
	check(front_push < back_push * 0.5, "Spinta ridotta solo se parato (%.1f contro %.1f)" % [front_push, back_push])
	hit(front, 10.0, {"bleed": 6.0, "stun": 1.0, "knock": Vector3(0, 0, 8)}, 1.0)
	check(float(p.status.left.bleed) > 0.0 and is_equal_approx(float(p.status.left.stun), 1.0), "Guardia rotta: effetti pieni")
	check(p.knock_velocity.length() > back_push * 0.9, "Guardia rotta: spinta piena")
	if p.get("guard_broken_left") != null: p.guard_broken_left = 0.0
	hit(front, 0.0, {"fear": 4.0}, full)
	check(float(p.status.left.fear) == 0.0, "Urlo senza danno parato davanti: niente paura (come prima)")
	print("PARATA ", "OK" if fails == 0 else "FALLITO %d" % fails)
	quit(fails)
