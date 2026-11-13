extends SceneTree
# Matrice degli attacchi degli infetti: per ogni attacco distanza all'avvio, velocità relativa, clip, carica, finestra,
# rotazione, spostamento, contatto visivo (ossa vere della mano/testa contro la capsula vera del giocatore) ed esito.
# Il contatto visivo è misurato qui, indipendente da zombie_ai: così il test giudica anche la versione vecchia.
#   godot --path . --headless -s res://tests/zombie_attack_matrix.gd
var fails := 0
var world
var p
const SPOT := Vector3(6, 0.1, -60)
const WALK := 4.0
## Parti che colpiscono e finestra in cui la clip colpisce davvero (misurate sulle ossa, vedi STRIKES in zombie_ai).
const TRUTH := {
	"Z_Attack_Swipe_R": [["hand_r"], 0.62, 0.84], "Z_Attack_Swipe_L": [["hand_r"], 0.60, 0.82],
	"Z_Attack_Headbutt": [["head", "hand_l", "hand_r"], 0.60, 0.80], "Z_Attack_Jab": [["hand_r"], 0.56, 0.76],
	"Z_Attack_Overhead_Smash": [["hand_l", "hand_r"], 1.28, 1.52], "Z_Attack_Leap": [["hand_l", "hand_r", "head"], 0.42, 0.62],
	"Z_Tank_Swipe": [["hand_l", "hand_r"], 0.58, 0.78], "Z_Tank_Punch": [["hand_r"], 0.24, 0.40]}
var summary := []


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1


func _initialize() -> void:
	call_deferred("run")


func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func zombie(at: Vector3, kind: int = 0):
	var z = world._spawn_enemy(at)
	z.set_kind(kind)
	var look: Vector3 = flat(p.global_position - at)
	z.rotation.y = atan2(-look.x, -look.z)
	z.pounce_cooldown = 99.0
	z.speed_mul = 1.0
	z.hear(p, 40)
	return z


func park(z) -> void:
	if not is_instance_valid(z): return
	z.set_physics_process(false)
	z.state = 0
	z.target = null
	z.global_position += Vector3(0, -300, 0)
	z.queue_free()


func reset_player(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.health = 100.0
	p.dodging = false
	p.dodge_elapsed = 0.0
	if p.crouching: p.set_crouched(false, true)
	if p.status: p.status.clear_all()


## Distanza tra le parti che colpiscono e la capsula del giocatore (negativa = si toccano).
func touch_gap(z, parts: Array, prev: Dictionary) -> float:
	var sk: Skeleton3D = z.avatar.skeleton
	var shape: CollisionShape3D = p.body_collider
	var cap := shape.shape as CapsuleShape3D
	var half: float = cap.height * 0.5 - cap.radius
	var a: Vector3 = shape.global_position - Vector3.UP * half
	var b: Vector3 = shape.global_position + Vector3.UP * half
	var best := INF
	for part in parts:
		var now: Vector3 = sk.global_transform * sk.get_bone_global_pose(z.avatar.bone_ids[part]).origin
		var before: Vector3 = prev.get(part, now)
		prev[part] = now
		var r: float = (0.13 if part == "head" else 0.12) * z.visual.scale.x
		var q := Geometry3D.get_closest_points_between_segments(before, now, a, b)
		best = minf(best, q[0].distance_to(q[1]) - r - cap.radius)
		if part.begins_with("hand"):
			# l'avambraccio conta come la mano (contatto visivo)
			var elbow: Vector3 = sk.global_transform * sk.get_bone_global_pose(z.avatar.bone_ids["lowerarm" + part.substr(4)]).origin
			var e := Geometry3D.get_closest_points_between_segments(elbow, now, a, b)
			best = minf(best, e[0].distance_to(e[1]) - r * 0.8 - cap.radius)
	return best


## Fa girare uno scenario: mover(z, t, dt) restituisce la velocità del giocatore. Ritorna la lista degli attacchi.
func scenario(name: String, zs: Array, seconds: float, mover: Callable, pin := false) -> Array:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var attacks := []
	var open := {}
	var t := 0.0
	var pins := {}
	var serials := {}
	for z in zs:
		pins[z] = z.global_position
		serials[z] = z.attack_serial
	while t < seconds:
		await physics_frame
		t += dt
		var v: Vector3 = mover.call(zs[0], t, dt)
		p.velocity = Vector3(v.x, 0, v.z)
		p.move_and_slide()
		if p.dodging: p.dodge_elapsed += dt
		for z in zs:
			if pin: z.global_position = pins[z]
			var rec = open.get(z)
			if rec != null and rec.serial != z.attack_serial:
				# la combo è partita nello stesso passo in cui si chiudeva il colpo prima
				rec.turned = absf(wrapf(z.rotation.y - rec.yaw, -PI, PI))
				rec.moved = flat(z.global_position - rec.from).length()
				rec.why = str(z.last_attack.get("result", "")) if z.get("last_attack") != null else ""
				attacks.append(rec)
				open.erase(z)
				rec = null
			if z.state == 2 and rec == null and z.attack_clip != "" and z.attack_serial != serials[z]:
				serials[z] = z.attack_serial
				rec = {"scen": name, "clip": z.attack_clip, "dist": flat(z.global_position - p.global_position).length(),
					"vrel": flat(p.velocity - z.velocity).length(), "windup": z.attack_hit, "yaw": z.rotation.y, "from": z.global_position,
					"t0": t, "serial": z.attack_serial, "gap": INF, "hurt": false, "prev": {}, "dodge": false, "z": z}
				open[z] = rec
			if rec != null:
				var truth: Array = TRUTH.get(rec.clip, [["hand_l", "hand_r", "head"], z.attack_hit - 0.1, z.attack_hit + 0.12])
				var scale: float = float(z.anim_scale)
				if z.attack_clock >= float(truth[1]) * scale and z.attack_clock <= float(truth[2]) * scale:
					z.avatar._pose(0.0)
					rec.gap = minf(rec.gap, touch_gap(z, truth[0], rec.prev))
					if p.is_invulnerable(): rec.dodge = true
				if z.state != 2 or z.attack_clock > float(truth[2]) * scale + 0.05:
					if rec.gap == INF: rec.why = "interrotto: stato %d clock %.2f/%.2f stagger %.2f push %.2f reaz '%s' serial %d" % [z.state, z.attack_clock, float(truth[1]) * scale, z.stagger, z.push_left, z.reaction, z.attack_serial]
					rec.turned = absf(wrapf(z.rotation.y - rec.yaw, -PI, PI))
					rec.moved = flat(z.global_position - rec.from).length()
					if rec.gap < INF: rec.why = str(z.last_attack.get("result", "")) if z.get("last_attack") != null else ""
					attacks.append(rec)
					open.erase(z)
		if p.health < 100.0:
			for z in open: open[z].hurt = true
			if open.is_empty() and not attacks.is_empty(): attacks[-1].hurt = true
			p.health = 100.0
			if p.status: p.status.clear_all()
	if attacks.is_empty(): print("  (nessun attacco: stato %d, distanza %.2f, giocatore morto %s, serial %d)" % [zs[0].state, flat(zs[0].global_position - p.global_position).length(), p.dead, zs[0].attack_serial])
	var hits := 0
	var false_hit := 0
	var false_miss := 0
	for a in attacks:
		var seen: bool = a.gap <= 0.0
		if a.hurt: hits += 1
		if a.hurt and a.gap > 0.05: false_hit += 1
		if seen and not a.hurt and not a.dodge: false_miss += 1
		print("  ATT %-14s %-24s avvio %.2f m  vrel %.1f m/s  carica %.2f s  giro %3.0f°  passo %.2f m  contatto %-11s danno %-2s %s" % [name, a.clip, a.dist, a.vrel, a.windup,
			rad_to_deg(a.turned), a.moved, ("si" if seen else "no (%.2f m)" % a.gap) if a.gap < INF else "n/d", "si" if a.hurt else "no", a.why])
	var row := {"name": name, "attacks": attacks.size(), "hits": hits, "false_hit": false_hit, "false_miss": false_miss}
	print("SCEN %-14s attacchi %d  a segno %d  danno senza contatto %d  contatto senza danno %d" % [name, attacks.size(), hits, false_hit, false_miss])
	summary.append(row)
	return attacks


func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	world.add_child(body)
	body.global_position = at
	return body


## Il colpo è deciso (zombie_ai.COMMIT prima del contatto). Una volta per attacco: le combo ricominciano il conto.
func committed(z, memo: Dictionary) -> bool:
	if z.state != 2 or memo.get("serial", -1) == z.attack_serial or z.attack_clock < z.attack_hit - z.COMMIT * float(z.anim_scale): return false
	memo["serial"] = z.attack_serial
	return true


func run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	p = world.player
	p.set_physics_process(false)
	world.spawner.set_process(false)
	world.spawner.set_physics_process(false)
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)
	reset_player(SPOT)
	for i in 20: await physics_frame
	var still := func(z, t, dt): return Vector3.ZERO

	# --- 1. Fermo davanti.
	var z = zombie(SPOT + Vector3(0, 0, 1.6))
	var r := await scenario("fermo", [z], 5.0, still)
	park(z)
	var stand_hits := r.filter(func(a): return a.hurt).size()
	check(r.size() >= 2 and stand_hits == r.size(), "Fermo davanti: ogni colpo va a segno (%d/%d)" % [stand_hits, r.size()])

	# --- 2. Contatto visivo e fuori portata con lo zombie bloccato sul posto (niente passo): decide solo il gesto.
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.0))
	r = await scenario("vicino_fermo", [z], 4.0, still, true)
	park(z)
	check(r.size() >= 1 and r.all(func(a): return a.hurt == (a.gap <= 0.0)), "Bloccato a 1,0 m: danno solo se mano o testa toccano (%s)" % str(r.map(func(a): return [a.clip, snappedf(a.gap, 0.01), a.hurt])))
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.5))
	z.attack_reach = 1.7
	r = await scenario("fuori_portata", [z], 4.0, still, true)
	park(z)
	check(r.all(func(a): return not a.hurt), "Bloccato a 1,5 m (oltre il braccio): nessun danno (%d attacchi)" % r.size())

	# --- 3. Passo di lato dopo il colpo deciso: va a vuoto.
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.6))
	var side := {"go": -1.0}
	r = await scenario("lato_indietro", [z], 5.0, func(z, t, dt):
		if committed(z, side): side.go = t
		if side.go >= 0.0 and t - side.go < 0.45: return (-z.global_basis.x - z.global_basis.z).normalized() * WALK   # via dal braccio e indietro
		return Vector3.ZERO)
	park(z)
	check(r.size() >= 1 and r.all(func(a): return not a.hurt), "Passo di lato e indietro dopo il colpo deciso: sempre a vuoto (%d attacchi)" % r.size())
	# Solo di lato: contro le manate larghe non sempre basta (misurato, non controllato).
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.6))
	side = {"go": -1.0}
	await scenario("lato_puro", [z], 5.0, func(z, t, dt):
		if committed(z, side): side.go = t
		if side.go >= 0.0 and t - side.go < 0.45: return -z.global_basis.x * WALK
		return Vector3.ZERO)
	park(z)

	# --- 4. Schivata (rotolata con invulnerabilità) al momento giusto.
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.6))
	var roll := {"at": -1.0, "dir": Vector3.ZERO}
	r = await scenario("schivata", [z], 5.0, func(z, t, dt):
		if committed(z, roll):
			roll.at = t
			roll.dir = -z.global_basis.x
			p.dodging = true
			p.dodge_elapsed = 0.0
		if roll.at >= 0.0 and t - roll.at < 0.55: return roll.dir * 9.0
		p.dodging = false
		return Vector3.ZERO)
	park(z)
	check(r.size() >= 1 and r.all(func(a): return not a.hurt), "Schivata al momento giusto: nessun danno (%d attacchi)" % r.size())

	# --- 5. Giro attorno allo zombie a passo pieno (strafe guardandolo): non deve annullare tutto.
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.4))
	r = await scenario("giro_attorno", [z], 8.0, func(z, t, dt):
		var off: Vector3 = flat(p.global_position - z.global_position)
		var tangent: Vector3 = off.normalized().cross(Vector3.UP)
		return (tangent * WALK + off.normalized() * clampf(1.4 - off.length(), -1.0, 1.0) * 3.0).limit_length(WALK))
	park(z)
	var circle_hits := r.filter(func(a): return a.hurt).size()
	check(circle_hits >= 1, "Girando attorno a passo pieno qualche colpo arriva (%d/%d)" % [circle_hits, r.size()])

	# --- 6. Strafe dritto avanti e indietro davanti allo zombie.
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.4))
	r = await scenario("strafe_lungo", [z], 8.0, func(z, t, dt): return Vector3.RIGHT * WALK * (1.0 if fmod(t, 3.2) < 1.6 else -1.0))
	park(z)
	var strafe_hits := r.filter(func(a): return a.hurt).size()
	check(strafe_hits >= 1, "Strafe dritto tenuto a lungo: qualche colpo arriva (%d/%d)" % [strafe_hits, r.size()])
	# Avanti e indietro ogni 0,8 s: è già un cambio di direzione continuo, solo misurato.
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.4))
	await scenario("strafe_corto", [z], 8.0, func(z, t, dt): return Vector3.RIGHT * WALK * (1.0 if fmod(t, 1.6) < 0.8 else -1.0))
	park(z)

	# --- 7. Cambio di direzione irregolare attorno allo zombie.
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.4))
	r = await scenario("zigzag", [z], 8.0, func(z, t, dt):
		var off: Vector3 = flat(p.global_position - z.global_position)
		var turn: float = 1.0 if fmod(t, 1.1) < 0.45 else -1.0
		return (off.normalized().cross(Vector3.UP) * turn * WALK + off.normalized() * clampf(1.4 - off.length(), -1.0, 1.0) * 3.0).limit_length(WALK))
	park(z)

	# --- 8. Arretramento: a passo pieno lo zombie non tira colpi all'aria; piano invece lo raggiunge.
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.6))
	r = await scenario("arretra_4ms", [z], 4.0, func(z, t, dt): return flat(p.global_position - z.global_position).normalized() * WALK)
	park(z)
	var air := r.filter(func(a): return not a.hurt).size()
	check(air <= 1, "Arretrando a passo pieno al massimo un colpo all'aria (%d)" % air)
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.6))
	r = await scenario("arretra_06ms", [z], 5.0, func(z, t, dt): return flat(p.global_position - z.global_position).normalized() * 0.6)
	park(z)
	check(r.filter(func(a): return a.hurt).size() >= 1, "Arretrando piano (0,6 m/s, meno del suo passo) lo zombie ti raggiunge (%d/%d)" % [r.filter(func(a): return a.hurt).size(), r.size()])

	# --- 9. Passaggio ravvicinato e corsa davanti allo zombie (a 1 m di lato).
	for row in [["passaggio", WALK], ["corsa", 7.0]]:
		reset_player(SPOT + Vector3(-4.0, 0, 0))
		z = zombie(SPOT + Vector3(0, 0, 1.0))
		r = await scenario(row[0], [z], 8.0 / float(row[1]) + 0.6, func(z, t, dt): return Vector3.RIGHT * float(row[1]))
		park(z)
	check(summary[-2].hits >= 1, "Passando a 1 m da uno zombie a passo normale si viene presi")

	# --- 10. Muro tra i due e giocatore su un rialzo.
	reset_player(SPOT)
	var wall := box(SPOT + Vector3(0, 1.0, 0.55), Vector3(3.0, 2.2, 0.12))
	z = zombie(SPOT + Vector3(0, 0, 1.15))
	r = await scenario("muro", [z], 4.0, still, true)
	summary[-1].false_miss = 0          # col muro il braccio passa attraverso: il contatto non conta
	park(z)
	wall.queue_free()
	check(r.all(func(a): return not a.hurt), "Col muro in mezzo nessun danno (%d attacchi)" % r.size())
	var ledge := box(SPOT + Vector3(0, 0.6, -0.6), Vector3(2.0, 1.2, 2.0))
	reset_player(SPOT + Vector3(0, 1.3, -0.3))
	for i in 5: await physics_frame
	z = zombie(SPOT + Vector3(0, 0, 0.9))
	r = await scenario("rialzo_1m2", [z], 4.0, still, true)
	park(z)
	ledge.queue_free()
	check(r.all(func(a): return a.hurt == (a.gap <= 0.0)), "Sul rialzo di 1,2 m: danno solo con contatto vero (%s)" % str(r.map(func(a): return [a.clip, snappedf(a.gap, 0.01), a.hurt])))

	# --- 11. Accucciato.
	reset_player(SPOT)
	p.set_crouched(true, true)
	z = zombie(SPOT + Vector3(0, 0, 1.0))
	r = await scenario("accucciato", [z], 4.0, still, true)
	park(z)
	reset_player(SPOT)
	p.set_crouched(true, true)
	z = zombie(SPOT + Vector3(0, 0, 1.6))
	var low := await scenario("accucciato_libero", [z], 5.0, still)
	park(z)
	p.set_crouched(false, true)
	check(low.filter(func(a): return a.hurt).size() >= 1, "Accucciarsi non annulla gli attacchi (%d/%d a segno)" % [low.filter(func(a): return a.hurt).size(), low.size()])
	check(r.all(func(a): return a.hurt == (a.gap <= 0.0)), "Accucciato: danno solo con contatto vero (%s)" % str(r.map(func(a): return [a.clip, snappedf(a.gap, 0.01), a.hurt])))

	# --- 12. Bruto.
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.8), 2)
	r = await scenario("bruto_fermo", [z], 7.0, still)
	park(z)
	check(r.size() >= 1 and r.all(func(a): return a.hurt), "Il bruto colpisce chi gli sta fermo davanti (%d/%d)" % [r.filter(func(a): return a.hurt).size(), r.size()])

	# --- 13. Gruppo di quattro: al massimo due insieme, partenze sfalsate, chi aspetta si muove.
	reset_player(SPOT)
	var pack := []
	for i in 4:
		var angle := TAU * float(i) / 4.0 + 0.3
		pack.append(zombie(SPOT + Vector3(cos(angle), 0, sin(angle)) * 1.7))
	var starts := []
	var most := 0
	var idle := 0.0
	var waited := 0.0
	var prev_state := {}
	var prev_pos := {}
	for i in 480:
		await physics_frame
		p.global_position = SPOT
		p.health = 100.0
		if p.status: p.status.clear_all()
		var busy := 0
		for q in pack:
			if q.state == 2 and prev_state.get(q, 0) != 2: starts.append(float(i) / 60.0)
			prev_state[q] = q.state
			if q.state == 2: busy += 1
			if q._waiting:
				waited += 1.0
				if prev_pos.has(q) and flat(q.global_position - prev_pos[q]).length() * 60.0 < 0.15: idle += 1.0
			prev_pos[q] = q.global_position
		most = maxi(most, busy)
	var spacing := INF
	starts.sort()
	for i in range(1, starts.size()): spacing = minf(spacing, starts[i] - starts[i - 1])
	for q in pack: park(q)
	check(most >= 1 and most <= 2, "In quattro attaccano al massimo in due insieme (visti %d)" % most)
	check(starts.size() >= 3 and spacing >= 0.3, "Attacchi sfalsati: %d partenze, distanza minima %.2f s" % [starts.size(), spacing])
	check(waited > 0.0 and idle / maxf(waited, 1.0) < 0.25, "Chi aspetta il turno non sta fermo (fermo %.0f%% del tempo d'attesa)" % (100.0 * idle / maxf(waited, 1.0)))

	# --- 14. Fisica a 30 Hz: stessi esiti.
	Engine.physics_ticks_per_second = 30
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.6))
	r = await scenario("fermo_30hz", [z], 5.0, still)
	park(z)
	check(r.size() >= 1 and r.all(func(a): return a.hurt), "A 30 Hz fermo davanti: a segno (%d/%d)" % [r.filter(func(a): return a.hurt).size(), r.size()])
	reset_player(SPOT)
	z = zombie(SPOT + Vector3(0, 0, 1.6))
	side = {"go": -1.0}
	r = await scenario("lato_ind_30hz", [z], 5.0, func(z, t, dt):
		if committed(z, side): side.go = t
		if side.go >= 0.0 and t - side.go < 0.45: return (-z.global_basis.x - z.global_basis.z).normalized() * WALK
		return Vector3.ZERO)
	park(z)
	check(r.all(func(a): return not a.hurt), "A 30 Hz il passo di lato e indietro tardivo va a vuoto (%d attacchi)" % r.size())
	Engine.physics_ticks_per_second = 60

	var fh := 0
	var fm := 0
	for row in summary:
		fh += row.false_hit
		fm += row.false_miss
	check(fh == 0, "Nessun danno senza contatto visivo in tutta la matrice (%d)" % fh)
	check(fm == 0, "Nessun contatto visivo senza danno (escluse schivate) in tutta la matrice (%d)" % fm)
	print("FINE ", "OK" if fails == 0 else "FALLITI %d" % fails)
	quit(fails)
