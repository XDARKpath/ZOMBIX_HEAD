extends Node
# Il cervello dei boss, solo sull'host: sceglie il colpo guardando cosa fa il giocatore, lo annuncia a terra, applica il danno e
# manda gli effetti a tutti (world.boss_fx). I client vedono posizione e clip dallo snapshot e gli effetti dall'RPC.
#
# CAPOMACELLO   titano lento. Leggi il colpo, spostati, picchia quando il lampione resta piantato. Teme il FUOCO.
# MACELLAIO     duellante veloce. Fallo schiantare contro muri e barricate. I FUCILI A POMPA lo fermano a metà carica.
# CARCERIERE    gigante corazzato. Le armi CONTUNDENTI rompono le piastre, tutto il resto rimbalza finché ne ha.
# IL MAGO       scappa e avvelena. Un velo ferma tutto: solo ARCO, BALESTRA e FUCILI DA CACCIA lo strappano e ne fermano la tempesta.
# SIGNORE       corona di teschi che devia i colpi. Solo le LAME la tagliano, e ogni teschio perso lo rende più veloce.
#
# Ogni colpo: avviso a terra, poi danno. Dopo i colpi grossi il boss resta scoperto (exposed) e prende di più.

const Fx := preload("res://bosses/boss_fx.gd")
const Motion := preload("res://art/infected_motion.gd")
const FIRE := ["flare_gun", "fire", "grenade_launcher", "grenade"]
const SHOTGUN := ["sawn_off", "pump_shotgun"]
const BLUNT := ["crowbar", "nail_bat", "sledgehammer", "pickaxe", "frying_pan", "electric_guitar", "kick"]
const LIGHT_GUNS := ["pistol", "smg", "nailgun"]
const SMALL_BLADES := ["knife", "combat_knife"]
const ARROWS := ["bow", "crossbow"]
const WEAK_COLOR := Color("ffd24a")
const RESIST_COLOR := Color("aab2b8")
const STAND_HEIGHT := {"capomacello": 3.9, "macellaio": 3.7, "carceriere": 4.4, "matriarca": 4.6, "signore": 4.1}
const SPEED := {"capomacello": 1.75, "macellaio": 3.3, "carceriere": 1.9, "matriarca": 2.4, "signore": 3.5}
# Da 0 a 1: quanto velocemente si riprende tra un colpo e l'altro, per fase.
const GAP := {"capomacello": [1.25, 0.95, 0.6], "macellaio": [0.7, 0.5, 0.32], "carceriere": [1.2, 0.9, 0.6], "matriarca": [1.2, 0.9, 0.65], "signore": [0.75, 0.55, 0.35]}
const LONG_SHOTS := ["bow", "crossbow", "lever_rifle", "sniper_rifle", "revolver"]
const BLADES := ["axe", "fire_axe", "machete", "katana", "longsword", "runic_axe", "spartan_sword", "knife", "combat_knife"]
## Secondi (a velocità 1) in cui le mani toccano davvero, misurati sulle clip. attack_timing dà 0,80 allo schianto,
## quando le mani sono ancora alzate: stirando la clip su quel numero il boss colpiva a braccia in aria.
const CONTACT := {"Z_Attack_Overhead_Smash": 1.40, "Z_Attack_Swipe_R": 0.72, "Z_Attack_Swipe_L": 0.70, "Z_Attack_Headbutt": 0.70,
	"Z_Attack_Jab": 0.66, "Z_Attack_Leap": 0.50, "Z_Tank_Swipe": 0.68, "Z_Tank_Punch": 0.30}
const SKULL_HP := 70.0
const MAX_ADDS := 4
const PLATE_HP := 110.0
# Gli stessi numeri di State in enemies/zombie_ai.gd.
const WANDER := 0
const CHASE := 1
const ATTACK := 2

var host: CharacterBody3D
var world: Node3D
var style := ""
var target: CharacterBody3D
var phase := 0
var move: Dictionary = {}
var last_moves: Array = []
var cooldowns: Dictionary = {}
var gap_left := 1.0
var stun := 0.0
var stun_len := 1.0
var exposed := 0.0
var burning := 0.0
var plates := 3
var plate_hp := PLATE_HP
var events: Array = []
var waves: Array = []
var hazards: Array = []
var bars: Array = []
var strafe_side := 1.0
var strafe_clock := 0.0
# Cosa fa il giocatore: tenuto d'occhio per non farsi fregare sempre allo stesso modo.
var far_for := 0.0
var behind_for := 0.0
var hidden_for := 0.0
var think := 0.0
var pop_clock := 0.0
var hint_said := false
var scripted := false
var _rng := RandomNumberGenerator.new()
var veil := true
var veil_back := 0.0
var skulls := 3
var skull_hp := SKULL_HP
var adds: Array = []
var dying := false


func setup(owner_host: CharacterBody3D, owner_world: Node3D, boss_style: String) -> void:
	host = owner_host
	world = owner_world
	style = boss_style
	name = "BossBrain"
	_rng.seed = host.network_id * 977 + 13
	gap_left = 1.5
	if style == "matriarca":
		_place_hitboxes()
		fx("veil", Vector3.ZERO, {"id": host.network_id, "on": true})
	if style == "signore": fx("crown", Vector3.ZERO, {"id": host.network_id, "left": skulls})
	_intro()


# =================================================================== ingresso
const NAMES := {"capomacello": "CAPOMACELLO", "macellaio": "IL MACELLAIO", "carceriere": "IL CARCERIERE", "matriarca": "IL MAGO", "signore": "IL SIGNORE DELLE TESTE"}


func in_intro() -> bool:
	return move.get("id", "") == "intro"


## L'ingresso: ognuno il suo. Solo effetti e suoni, nessun danno; finché dura non colpisce e non prende colpi.
func _intro() -> void:
	var at: Vector3 = host.global_position
	var say := func() -> void:
		fx("say", Vector3.ZERO, {"text": NAMES.get(style, ""), "t": 2.5})
	var steps := []
	var clip := "Z_Roar"
	var hit := 1.0
	var total := 2.4
	match style:
		"capomacello":
			# Esce dalle fiamme: il suolo prende fuoco, poi un'esplosione e il ruggito.
			steps = [[0.0, func() -> void:
				fx("patch", at, {"r": 3.4, "life": 3.0, "type": "fire"})
				fx("burn", Vector3.ZERO, {"id": host.network_id, "t": 2.6})
				_sound("explosion", 2.0, 0.6)],
				[1.0, func() -> void:
					fx("crack", at, {"r": 4.5, "shake": 1.0, "life": 7.0})
					fx("ring", at, {"r": 12.0, "speed": 14.0, "color": "fire"})
					_sound("boss_capomacello_roar", 4.0, 0.9)
					say.call()]]
		"macellaio":
			# Trascina il gancio stridendo per terra, poi lo tira a sé e ruggisce nel sangue.
			clip = "Z_Scream"
			total = 2.3
			steps = [[0.05, func() -> void:
				fx("crack", at, {"r": 2.6, "shake": 0.3, "life": 7.0})
				fx("chain", host.global_position + Vector3.UP * 1.2, {"to": _forward(7.0) + Vector3.UP * 0.2, "t": 0.35, "back": 0.6})
				_sound("swing_blade", 2.0, 0.55)],
				[0.6, func() -> void: _sound("weapon_hit_guard", 1.0, 0.6)],
				[1.0, func() -> void:
					_slash(4.0, TAU * 0.95, "blood", 0.0, 0.9)
					_sound("zombie_brute_alert", 5.0, 0.62)
					say.call()]]
		"carceriere":
			# Cade dall'alto: sbarre che piovono attorno, il pavimento si spacca a lastre, rimbomba il ferro.
			clip = "Z_Boss_Drop_Arrival"
			hit = 0.6
			total = 2.6
			steps = [[0.0, func() -> void:
				fx("cage", at, {"r": 4.5, "life": 1.6, "gap": -10.0})
				fx("warn", at, {"r": 5.5, "t": 0.6, "color": "steel"})
				_sound("weapon_hit_guard", 3.0, 0.45)],
				[0.6, func() -> void:
					fx("crack", at, {"r": 6.0, "shake": 1.2, "life": 9.0})
					fx("ring", at, {"r": 14.0, "speed": 12.0, "color": "steel"})
					_sound("explosion", 3.0, 0.5)],
				[1.1, func() -> void:
					_sound("boss_carceriere_roar", 4.0, 1.0)
					say.call()]]
		"matriarca":
			# Un fulmine verde dal cielo, la pozza che fuma, il velo che si chiude con un urlo.
			clip = "Z_Scream"
			steps = [[0.0, func() -> void:
				fx("bolt", at + Vector3.UP * 16.0, {"to": at, "t": 0.45})
				fx("warn", at, {"r": 3.2, "t": 0.45, "color": "acid"})],
				[0.45, func() -> void:
					fx("patch", at, {"r": 3.2, "life": 3.5, "type": "acid"})
					fx("crack", at, {"r": 3.4, "shake": 0.7, "life": 6.0})
					_sound("boss_mago_attack", 3.0, 0.7)],
				[1.2, func() -> void:
					fx("veil", Vector3.ZERO, {"id": host.network_id, "on": true})
					fx("ring", at, {"r": 10.0, "speed": 9.0, "color": "acid"})
					_sound("boss_mago_roar", 4.0, 1.0)
					say.call()]]
		"signore":
			# I teschi saltano fuori da terra e gli volano in testa uno alla volta, poi la corona è completa.
			total = 2.6
			for i in 3:
				var a: float = TAU * float(i) / 3.0
				var from: Vector3 = _spot_on_floor(at + Vector3(cos(a), 0, sin(a)) * 4.0)
				steps.append([0.15 + i * 0.3, func() -> void:
					fx("crack", from, {"r": 1.2, "shake": 0.2, "life": 5.0})
					fx("boulder", from, {"to": at + Vector3.UP * 3.8, "t": 0.4, "r": 0.3, "color": Color("d0c6a6")})
					_sound("weapon_hit_bone", 2.0, 0.8 + i * 0.15)])
			steps.append([1.3, func() -> void:
				fx("crown", Vector3.ZERO, {"id": host.network_id, "left": skulls})
				fx("ring", at, {"r": 11.0, "speed": 11.0, "color": "danger"})
				_sound("boss_teste_roar", 4.0, 1.0)
				say.call()])
	_start("intro", clip, hit, {"total": total, "aim_until": total, "cooldown": 0.0, "gap": 0.4, "steps": steps})
	host.alert_time = 0.0


## Suono mandato a tutti come gli effetti, non solo sull'host.
func _sound(key: String, volume: float, pitch: float) -> void:
	fx("sound", host.global_position, {"key": key, "v": volume, "p": pitch})


func fx(kind: String, at: Vector3, data: Dictionary = {}) -> void:
	# Ogni boss lascia il suo segno a terra: fuoco, sangue, pietra, acido.
	if kind == "crack":
		data["look"] = style
		# La brace è del Capomacello; agli altri solo dove il colpo è davvero di fuoco (le fessure).
		data["ember"] = style == "capomacello" or move.get("id", "") == "fissure"
	if world.has_method("boss_fx"): world.boss_fx(kind, at, data)


# =================================================================== ciclo
func tick(delta: float) -> void:
	# L'ingresso ha già il suo ruggito: niente seconda pausa dopo.
	if in_intro(): host.alert_time = 0.0
	_clocks(delta)
	if stun > 0.0:
		_stunned(delta)
	elif not move.is_empty():
		_run_move(delta)
	elif host.alert_time > 0.0:
		_roar_pause(delta)
	elif host.state == ATTACK:
		_scripted(delta)
	else:
		_pick_target()
		if is_instance_valid(target):
			_watch(delta)
			_decide(delta)
			if move.is_empty(): _walk(delta)
		else:
			host.state = WANDER
			host.velocity.x = move_toward(host.velocity.x, 0.0, 10.0 * delta)
			host.velocity.z = move_toward(host.velocity.z, 0.0, 10.0 * delta)
	host.velocity.y = 0.0 if host.is_on_floor() else host.velocity.y - 22.0 * delta
	if move.get("flying", false): return
	host.move_and_slide()
	host._audio_steps(delta)


func _clocks(delta: float) -> void:
	host.clock += delta
	exposed = maxf(0.0, exposed - delta)
	gap_left = maxf(0.0, gap_left - delta)
	pop_clock = maxf(0.0, pop_clock - delta)
	burning = maxf(0.0, burning - delta)
	if style == "matriarca" and not veil:
		veil_back -= delta
		if veil_back <= 0.0:
			veil = true
			fx("veil", Vector3.ZERO, {"id": host.network_id, "on": true})
			_pop("IL VELO SI RICHIUDE", RESIST_COLOR, 46)
	for key in cooldowns.keys(): cooldowns[key] = maxf(0.0, cooldowns[key] - delta)
	var frac: float = host.health / maxf(host.max_health, 1.0)
	var wanted := 2 if frac < 0.33 else (1 if frac < 0.66 else 0)
	if wanted > phase:
		phase = wanted
		_phase_changed()
	for i in range(events.size() - 1, -1, -1):
		events[i][0] -= delta
		if events[i][0] <= 0.0:
			var run: Callable = events[i][1]
			events.remove_at(i)
			if not host.dead: run.call()
	_tick_waves(delta)
	_tick_hazards(delta)
	_tick_bars(delta)


func _after(seconds: float, run: Callable) -> void:
	events.append([seconds, run])


func _pick_target() -> void:
	var best: CharacterBody3D = null
	var best_d := 55.0
	for a in world.actors.values():
		if not is_instance_valid(a) or a.dead: continue
		var d: float = host.global_position.distance_to(a.global_position)
		# Il boss cambia preda solo se l'altro è parecchio più vicino: non balla fra due giocatori.
		if a == target: d -= 4.0
		if d < best_d:
			best_d = d
			best = a
	if best != target and is_instance_valid(best) and not hint_said:
		hint_said = true
		fx("say", Vector3.ZERO, {"text": _hint(), "t": 6.0})
	target = best
	host.target = best
	if best: host.state = CHASE


func _hint() -> String:
	match style:
		"matriarca": return "IL MAGO · Il velo ferma tutto: serve un tiro lungo, ARCO, BALESTRA o FUCILE DA CACCIA"
		"signore": return "IL SIGNORE DELLE TESTE · La corona devia i colpi: taglia i teschi con una LAMA"
		"capomacello": return "CAPOMACELLO · Il serbatoio sulla schiena perde benzina... teme il FUOCO"
		"macellaio": return "IL MACELLAIO · Solo una rosa di pallini da vicino lo ferma quando carica"
		_: return "IL CARCERIERE · La corazza rimbalza tutto: serve un'arma CONTUNDENTE"


## Cosa sta facendo il giocatore? Da lontano si avvicina saltando, dietro si gira col colpo a giro, nascosto lancia sassi.
func _watch(delta: float) -> void:
	var flat: Vector3 = (target.global_position - host.global_position) * Vector3(1, 0, 1)
	far_for = far_for + delta if flat.length() > 11.0 else maxf(0.0, far_for - delta * 2.0)
	var facing: Vector3 = -host.global_basis.z
	var behind: bool = flat.length() < 7.0 and facing.dot(flat.normalized()) < -0.15
	behind_for = behind_for + delta if behind else maxf(0.0, behind_for - delta * 2.0)
	think -= delta
	if think <= 0.0:
		think = 0.25
		hidden_for = 0.0 if host.clear_line(target) else hidden_for + 0.25


# =================================================================== cammino
func _walk(delta: float) -> void:
	host.state = CHASE
	var flat: Vector3 = (target.global_position - host.global_position) * Vector3(1, 0, 1)
	var dist := flat.length()
	var speed: float = float(SPEED.get(style, 2.0)) * (1.0 + phase * 0.14)
	if burning > 0.0: speed *= 1.15
	var dir := Vector3.ZERO
	host.agent.target_position = target.global_position
	if NavigationServer3D.map_get_iteration_id(host.get_world_3d().navigation_map) > 0 and not host.agent.is_navigation_finished() and host.agent.is_target_reachable():
		dir = (host.agent.get_next_path_position() - host.global_position) * Vector3(1, 0, 1)
	if dir.length_squared() < 0.01: dir = flat
	if dir.length_squared() > 0.01: dir = dir.normalized()
	# Il Macellaio non viene dritto: ti gira attorno cercando l'angolo per caricare.
	if style == "macellaio" and dist < 11.0 and dist > 3.2:
		strafe_clock -= delta
		if strafe_clock <= 0.0:
			strafe_clock = _rng.randf_range(0.9, 2.1)
			strafe_side = -strafe_side
		var tangent: Vector3 = Vector3(-flat.z, 0, flat.x).normalized() * strafe_side
		dir = (dir * 0.45 + tangent * 0.9).normalized()
	# Il Mago tiene la distanza: se ti avvicini indietreggia, altrimenti ti gira attorno.
	if style == "matriarca":
		var away: Vector3 = -flat.normalized() if dist > 0.1 else Vector3.BACK
		var round_about: Vector3 = Vector3(-flat.z, 0, flat.x).normalized() * strafe_side
		strafe_clock -= delta
		if strafe_clock <= 0.0:
			strafe_clock = _rng.randf_range(2.0, 4.0)
			strafe_side = -strafe_side
		if dist < 11.0: dir = (away + round_about * 0.5).normalized()
		elif dist < 18.0: dir = round_about
	# Il Signore corre addosso a zig-zag, tanto più veloce quanti meno teschi ha.
	if style == "signore":
		speed *= 1.0 + float(3 - skulls) * 0.15
		var wobble: Vector3 = Vector3(-flat.z, 0, flat.x).normalized() * sin(host.clock * 3.1) * 0.65
		if dist > 3.0: dir = (dir + wobble).normalized()
	if dir != Vector3.ZERO: dir = host._steer(dir, delta, true)
	# Si ferma alla sua distanza: non ti cammina dentro.
	if dist < 2.3 and style != "matriarca": dir = Vector3.ZERO
	host.velocity.x = dir.x * speed
	host.velocity.z = dir.z * speed
	var look: Vector3 = flat if dist < 9.0 or dir == Vector3.ZERO else dir
	if look.length_squared() > 0.01: host.rotation.y = lerp_angle(host.rotation.y, atan2(-look.x, -look.z), delta * 5.0)


# =================================================================== scelta del colpo
func _decide(_delta: float) -> void:
	if gap_left > 0.0: return
	var flat: Vector3 = (target.global_position - host.global_position) * Vector3(1, 0, 1)
	var dist := flat.length()
	var options: Array = []
	match style:
		"capomacello": options = _options_capomacello(dist)
		"macellaio": options = _options_macellaio(dist)
		"matriarca": options = _options_matriarca(dist)
		"signore": options = _options_signore(dist)
		_: options = _options_carceriere(dist)
	var best := ""
	var best_score := 0.0
	for row in options:
		var id: String = row[0]
		var score: float = float(row[1])
		if score <= 0.0 or cooldowns.get(id, 0.0) > 0.0: continue
		if not last_moves.is_empty() and last_moves[-1] == id: score *= 0.25
		if last_moves.has(id): score *= 0.75
		score *= _rng.randf_range(0.8, 1.25)
		if score > best_score:
			best_score = score
			best = id
	if best != "": begin(best)


func _options_capomacello(dist: float) -> Array:
	return [
		["slam", (3.0 if dist < 4.5 else 0.0)],
		["sweep", (3.4 if dist < 3.7 else 0.0)],
		["spin", (9.0 if behind_for > 0.9 and dist < 5.5 else 0.0)],
		["rift", (2.5 if dist > 4.5 and dist < 18.0 else 0.0) * (2.0 if far_for > 2.0 else 1.0)],
		["leap", (2.0 if dist > 8.0 and dist < 24.0 else 0.0) * (3.0 if far_for > 3.0 else 1.0)],
		["boulder", (hidden_for * 3.0 + (1.2 if dist > 9.0 else 0.0))],
		["inferno", (3.0 if phase >= 1 and dist < 12.0 else 0.0)],
	]


func _options_macellaio(dist: float) -> Array:
	var guarded: bool = target.melee.blocking
	return [
		["combo", (3.5 if dist < 3.6 else 0.0)],
		["guardbreak", (8.0 if guarded and dist < 3.6 else 0.0)],
		["charge", (3.0 if dist > 5.5 and dist < 22.0 else 0.0) * (2.0 if far_for > 1.5 else 1.0)],
		["hook", (3.2 if dist > 6.0 and dist < 17.0 and hidden_for <= 0.0 else 0.0)],
		["cleaver", (2.4 if phase >= 1 and dist > 3.5 and dist < 13.0 and hidden_for <= 0.0 else 0.0)],
		["blood", (2.8 if phase >= 1 else 0.0) + (3.0 if host.health / host.max_health < 0.4 else 0.0)],
	]


func _options_carceriere(dist: float) -> Array:
	return [
		["slam", (3.0 if dist < 4.8 else 0.0)],
		["spin", (9.0 if behind_for > 1.2 and dist < 6.0 else 0.0)],
		["quake", (2.6 if dist > 3.0 and dist < 16.0 else 0.0)],
		["chain", (3.0 if dist < 9.0 else 0.0)],
		["cage", (2.2 if phase >= 0 and dist < 20.0 else 0.0) * (2.0 if far_for > 2.0 else 1.0)],
		["debris", (2.4 if phase >= 1 else 0.0)],
		["fissure", (2.8 if phase >= 1 and dist < 16.0 else 0.0)],
		["leap", (2.0 if dist > 8.0 else 0.0) * (3.0 if far_for > 3.0 else 1.0)],
	]


## Fa partire un colpo per nome (lo usano anche i test).
func begin(id: String) -> void:
	last_moves.append(id)
	if last_moves.size() > 3: last_moves.pop_front()
	host.velocity.x = 0.0
	host.velocity.z = 0.0
	match id:
		"slam": _m_slam()
		"sweep": _m_sweep()
		"spin": _m_spin()
		"rift": _m_rift()
		"leap": _m_leap()
		"boulder": _m_boulder()
		"inferno": _m_inferno()
		"combo": _m_combo(0)
		"guardbreak": _m_guardbreak()
		"charge": _m_charge()
		"hook": _m_hook()
		"cleaver": _m_cleaver()
		"blood": _m_blood()
		"quake": _m_quake()
		"chain": _m_chain()
		"cage": _m_cage()
		"debris": _m_debris()
		"fissure": _m_fissure()
		"bolts": _m_bolts()
		"pool": _m_pool()
		"blink": _m_blink()
		"nova": _m_nova()
		"storm": _m_storm()
		"brood": _m_brood()
		"dash": _m_dash(2)
		"heads": _m_heads()
		"court": _m_court()
	host._voice("attack")


# =================================================================== esecuzione generica
## clip mostrata, windup = secondi prima del colpo. La clip viene stirata perché il suo fotogramma di colpo cada lì.
func _start(id: String, clip: String, windup: float, opts: Dictionary = {}) -> void:
	var timing: Array = Motion.attack_timing(clip)
	var scale: float = windup / maxf(float(CONTACT.get(clip, timing[1])), 0.05)
	host.anim_scale = scale
	host.attack_clip = clip
	host.attack_serial += 1
	host.attack_clock = 0.0
	host.attack_done = false
	host.state = ATTACK
	move = {"id": id, "clip": clip, "windup": windup, "total": float(opts.get("total", float(timing[0]) * scale)), "hold": float(opts.get("hold", 0.0)),
		"aim_until": float(opts.get("aim_until", windup * 0.45)), "steps": opts.get("steps", []), "next": opts.get("next", Callable()),
		"cooldown": float(opts.get("cooldown", 2.0)), "lunge": float(opts.get("lunge", 0.0)), "gap": float(opts.get("gap", -1.0))}
	# Il colpo non finisce prima del suo ultimo passo (le fessure cadono dopo il fotogramma del colpo).
	for step in move.steps: move.total = maxf(float(move.total), float(step[0]) + 0.05)
	cooldowns[id] = move.cooldown


func _run_move(delta: float) -> void:
	if move.get("rush", false):
		_run_rush(delta)
		return
	if move.get("flying", false):
		_run_flight(delta)
		return
	var hold: float = float(move.hold)
	var hit_passed: bool = host.attack_clock >= float(move.windup)
	if hit_passed and hold > 0.0:
		# Fermo sul fotogramma del colpo: è il momento di picchiarlo.
		move.hold = hold - delta
	else:
		host.attack_clock += delta
	var clock: float = host.attack_clock
	# Punta il bersaglio finché può, poi il colpo è deciso e si può schivare.
	if clock < float(move.aim_until) and is_instance_valid(target):
		var flat: Vector3 = (target.global_position - host.global_position) * Vector3(1, 0, 1)
		if flat.length_squared() > 0.04: host.rotation.y = lerp_angle(host.rotation.y, atan2(-flat.x, -flat.z), delta * 8.0)
	var lunge: float = float(move.lunge)
	if lunge > 0.0 and clock < float(move.windup) and clock > float(move.windup) * 0.4:
		host.velocity.x = -sin(host.rotation.y) * lunge
		host.velocity.z = -cos(host.rotation.y) * lunge
	else:
		host.velocity.x = move_toward(host.velocity.x, 0.0, 14.0 * delta)
		host.velocity.z = move_toward(host.velocity.z, 0.0, 14.0 * delta)
	var steps: Array = move.steps
	while not steps.is_empty() and clock >= float(steps[0][0]):
		var step: Array = steps.pop_front()
		(step[1] as Callable).call()
		if move.is_empty(): return
	if clock >= float(move.total) and float(move.hold) <= 0.0:
		_end_move()


func _end_move() -> void:
	var next: Callable = move.get("next", Callable())
	var gap: float = float(move.get("gap", -1.0))
	move = {}
	host.anim_scale = 1.0
	host.attack_clip = ""
	host.state = CHASE
	if next.is_valid():
		next.call()
		return
	gap_left = gap if gap >= 0.0 else GAP[style][phase] * _rng.randf_range(0.8, 1.2)


## Il colpo scriptato di chi lo chiama da fuori (il Carceriere che atterra dalla gabbia).
func _scripted(delta: float) -> void:
	# Anche l'atterraggio scriptato ha il suo cerchio prima dell'onda.
	if host.attack_clock <= 0.0 and not host.attack_done:
		fx("warn", host.global_position, {"r": 5.0, "t": maxf(host.attack_hit, 0.3), "color": "steel"})
	host.attack_clock += delta
	host.velocity.x = 0.0
	host.velocity.z = 0.0
	if host.attack_clock >= host.attack_hit and not host.attack_done:
		host.attack_done = true
		_land_blast(host.global_position, 5.0, 24.0)
	if host.attack_clock >= host.attack_len:
		host.state = CHASE


func _roar_pause(delta: float) -> void:
	if host.attack_clip != "Z_Roar": host.attack_clock = 0.0
	host.alert_time -= delta
	host.velocity.x = move_toward(host.velocity.x, 0.0, 10.0 * delta)
	host.velocity.z = move_toward(host.velocity.z, 0.0, 10.0 * delta)
	host.state = ATTACK
	host.attack_clip = "Z_Roar"
	host.anim_scale = 1.0
	host.attack_clock += delta
	if host.alert_time <= 0.0:
		host.state = CHASE
		host.attack_clip = ""


func _stunned(delta: float) -> void:
	stun -= delta
	host.attack_clock += delta
	host.velocity.x = move_toward(host.velocity.x, 0.0, 16.0 * delta)
	host.velocity.z = move_toward(host.velocity.z, 0.0, 16.0 * delta)
	if stun <= 0.0:
		host.state = CHASE
		host.attack_clip = ""
		host.anim_scale = 1.0
		gap_left = 0.3


## Stordito e scoperto: barcolla sul posto. Interrompe qualsiasi colpo.
func stagger_for(seconds: float, text: String = "") -> void:
	move = {}
	events.clear()
	stun = seconds
	stun_len = seconds
	host.state = ATTACK
	host.attack_clip = "Z_Stagger_Heavy"
	host.anim_scale = maxf(seconds / 2.0, 0.6)
	host.attack_clock = 0.0
	expose(seconds + 0.4)
	if text != "": _pop(text, WEAK_COLOR, 70)


func expose(seconds: float) -> void:
	if seconds <= exposed: return
	exposed = seconds
	fx("flash", Vector3.ZERO, {"id": host.network_id, "t": seconds, "color": Color(1.0, 0.82, 0.2, 0.34)})


# =================================================================== danno ai giocatori
func _players() -> Array:
	var list := []
	for a in world.actors.values():
		if is_instance_valid(a) and not a.dead: list.append(a)
	return list


func _hurt(a: CharacterBody3D, damage: float, from: Vector3, push: float, extra: Dictionary = {}) -> void:
	var away: Vector3 = (a.global_position - from) * Vector3(1, 0, 1)
	away = away.normalized() if away.length_squared() > 0.001 else -host.global_basis.z
	var data := {"knock": away * push + Vector3.UP * float(extra.get("up", 2.5)), "shake": float(extra.get("shake", 0.7)), "heavy": extra.get("heavy", true)}
	for key in ["stun", "bleed", "slow", "poison", "fear"]:
		if extra.has(key): data[key] = extra[key]
	world.hit_player(a, damage * (1.0 + 0.12 * phase), data.merged({"env": true}) if extra.get("env", false) else data, from)


func _hit_circle(center: Vector3, radius: float, damage: float, push: float, extra: Dictionary = {}) -> int:
	var count := 0
	for a in _players():
		var gap: Vector3 = (a.global_position - center) * Vector3(1, 0, 1)
		if gap.length() < radius and absf(a.global_position.y - center.y) < 2.6:
			_hurt(a, damage, center, push, extra)
			count += 1
	return count


func _hit_cone(origin: Vector3, yaw: float, length: float, angle: float, damage: float, push: float, extra: Dictionary = {}) -> int:
	var count := 0
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	for a in _players():
		var gap: Vector3 = (a.global_position - origin) * Vector3(1, 0, 1)
		if gap.length() > length or absf(a.global_position.y - origin.y) > 2.6: continue
		if gap.length() < 0.6 or forward.dot(gap.normalized()) >= cos(angle * 0.5):
			_hurt(a, damage, origin, push, extra)
			count += 1
	return count


## La scia del colpo, mandata nello stesso fotogramma del danno.
func _slash(r: float, angle: float, color: String, tilt: float, shake: float) -> void:
	fx("slash", host.global_position, {"yaw": host.rotation.y, "angle": angle, "r": r, "color": color, "tilt": tilt, "shake": shake, "h": float(STAND_HEIGHT.get(style, 3.5)) * 0.4})


func _forward(distance: float) -> Vector3:
	return host.global_position - host.global_basis.z * distance


## Dove sarà il giocatore fra t secondi, non dov'è adesso. Mai troppo: altrimenti restare fermi salverebbe.
func _predict(t: float) -> Vector3:
	if not is_instance_valid(target): return host.global_position
	var run: Vector3 = target.velocity * Vector3(1, 0, 1)
	return target.global_position + run.limit_length(5.0) * t * 0.65


func _spot_on_floor(at: Vector3) -> Vector3:
	var from: Vector3 = at + Vector3.UP * 1.3
	var q := PhysicsRayQueryParameters3D.create(from, at + Vector3.DOWN * 4.0, 1)
	var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else at


## Da dove arrivo a dove voglio senza passare i muri: se c'è un muro si ferma prima.
func _reach(from: Vector3, to: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.2, to + Vector3.UP * 1.2, 1, [host.get_rid()])
	var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return to
	var way: Vector3 = (to - from) * Vector3(1, 0, 1)
	var back: float = maxf(from.distance_to(hit.position) - 1.0, 0.0)
	return from + way.normalized() * back


# =================================================================== onde, pozze, sbarre
func _wave(center: Vector3, r_max: float, speed: float, damage: float, color: String = "fire") -> void:
	waves.append({"center": center, "r": 0.5, "max": r_max, "speed": speed, "damage": damage, "hit": []})
	fx("ring", center, {"r": r_max, "speed": speed, "color": color})


func _tick_waves(delta: float) -> void:
	for i in range(waves.size() - 1, -1, -1):
		var w: Dictionary = waves[i]
		w.r += float(w.speed) * delta
		for a in _players():
			if (w.hit as Array).has(a): continue
			var gap: float = ((a.global_position - (w.center as Vector3)) * Vector3(1, 0, 1)).length()
			# Si salta: chi è per aria quando passa l'onda non si fa niente.
			if absf(gap - float(w.r)) < 0.75 and a.is_on_floor() and absf(a.global_position.y - (w.center as Vector3).y) < 2.0:
				(w.hit as Array).append(a)
				_hurt(a, float(w.damage), w.center, 7.0, {"shake": 0.6, "up": 3.0})
		if float(w.r) >= float(w.max): waves.remove_at(i)


func _hazard(at: Vector3, radius: float, life: float, type: String, dps: float, extra: Dictionary = {}) -> void:
	# Il primo morso dopo mezzo secondo: la pozza appare (è lei l'avviso) e chi ci nasce sopra fa in tempo a uscire.
	hazards.append({"at": at, "r": radius, "t": life, "type": type, "dps": dps, "extra": extra, "clock": 0.5})
	fx("patch", at, {"r": radius, "life": life, "type": type})


func _tick_hazards(delta: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var h: Dictionary = hazards[i]
		h.t -= delta
		h.clock -= delta
		if float(h.t) <= 0.0:
			hazards.remove_at(i)
			continue
		if float(h.clock) > 0.0: continue
		h.clock = 0.5
		for a in _players():
			var gap: float = ((a.global_position - (h.at as Vector3)) * Vector3(1, 0, 1)).length()
			if gap < float(h.r) and a.is_on_floor():
				var extra: Dictionary = h.extra
				var data := {"shake": 0.15}
				for key in extra: data[key] = extra[key]
				world.hit_player(a, float(h.dps) * 0.5, data.merged({"env": true}), h.at)
		# Il Macellaio si rimette in forze nel sangue che ha versato: staccalo da lì.
		if h.type == "blood" and style == "macellaio" and not host.dead:
			var mine: float = ((host.global_position - (h.at as Vector3)) * Vector3(1, 0, 1)).length()
			if mine < float(h.r) and host.health < host.max_health:
				host.health = minf(host.max_health, host.health + host.max_health * 0.006)
				host.bar.scale.x = host.health / host.max_health


func _tick_bars(delta: float) -> void:
	for i in range(bars.size() - 1, -1, -1):
		bars[i][0] -= delta
		if bars[i][0] <= 0.0:
			if is_instance_valid(bars[i][1]): bars[i][1].queue_free()
			bars.remove_at(i)


# =================================================================== mosse comuni
## Lo schianto grosso. Sul Capomacello il lampione resta piantato: è il momento d'oro.
func _m_slam() -> void:
	var windup: float = 1.15 - phase * 0.1
	var reach: float = 2.6 if style == "capomacello" else 2.9
	var radius: float = 3.2 if style == "capomacello" else 3.5
	_start("slam", "Z_Attack_Overhead_Smash", windup, {"cooldown": 2.5, "hold": 2.2 if style == "capomacello" else 0.55, "total": windup + 0.55, "gap": 0.35,
		"steps": [[windup * 0.45, func() -> void:
			fx("warn", _forward(reach), {"r": radius, "t": windup * 0.55, "color": "fire" if style == "capomacello" else "danger"})],
			[windup, func() -> void:
				var center := _forward(reach)
				_hit_circle(center, radius, 32.0 if style == "capomacello" else 34.0, 10.0, {"stun": 0.8, "shake": 1.0, "up": 3.5})
				fx("crack", center, {"r": radius + 0.9, "ember": style == "capomacello" and phase >= 1, "shake": 1.0, "life": 8.0})
				if style == "capomacello":
					expose(2.5)
					_pop("È PIANTATO!", WEAK_COLOR, 60)
					if phase >= 1: _hazard(center, radius * 0.75, 5.0, "fire", 11.0)
				if phase >= 1 or style == "carceriere": _wave(center, 9.0 + phase * 2.0, 8.5, 12.0)]]})


func _m_sweep() -> void:
	var angle := 2.5
	var windup: float = 0.78 - phase * 0.06
	# L'avviso si riempie proprio sul colpo anche nelle fasi veloci (prima finiva dopo il danno).
	_start("sweep", "Z_Tank_Swipe", windup, {"cooldown": 3.0, "aim_until": 0.32, "steps": [[0.33, func() -> void:
			fx("warn", host.global_position, {"shape": "cone", "yaw": host.rotation.y, "angle": angle, "r": 5.4, "t": windup - 0.33})],
			[windup, func() -> void:
				_hit_cone(host.global_position, host.rotation.y, 5.4, angle, 22.0, 9.0, {"shake": 0.6})
				_slash(5.4, angle, "fire" if style == "capomacello" else "danger", 0.0, 0.5)
				Fx._sound(world, "swing_blunt", host.global_position, 2.0, 0.6)]]})


## Punisce chi gli sta dietro: si gira su se stesso. Ogni volta dopo qualche secondo alle spalle.
func _m_spin() -> void:
	behind_for = 0.0
	var windup := 0.72
	_start("spin", "Z_Attack_Swipe_R", windup, {"cooldown": 4.5, "aim_until": 0.0, "steps": [[0.05, func() -> void:
			fx("warn", host.global_position, {"r": 5.2, "t": windup - 0.05})],
			[windup, func() -> void:
				_hit_circle(host.global_position, 5.2, 24.0, 10.0, {"shake": 0.7})
				_slash(5.2, TAU * 0.95, "danger", 0.0, 0.6)
				fx("crack", host.global_position, {"r": 3.0, "ember": phase >= 1, "shake": 0.5, "life": 5.0})]]})


## Fenditura: spuntoni in fila che corrono verso di te. Si schiva di lato.
func _m_rift() -> void:
	var windup := 1.05
	var length := 19.0
	var yaw_lock := [0.0]
	_start("rift", "Z_Attack_Overhead_Smash", windup, {"cooldown": 5.0, "aim_until": 0.5, "steps": [[0.5, func() -> void:
			var aim: Vector3 = _predict(1.0)
			var way: Vector3 = (aim - host.global_position) * Vector3(1, 0, 1)
			if way.length_squared() > 0.1: host.rotation.y = atan2(-way.x, -way.z)
			yaw_lock[0] = host.rotation.y
			fx("warn", _forward(1.2), {"shape": "line", "yaw": yaw_lock[0], "len": length, "width": 2.2, "t": 0.55})],
			[windup, func() -> void:
				fx("crack", _forward(2.4), {"r": 2.4, "ember": phase >= 1, "shake": 0.8, "life": 5.0})
				var yaw: float = yaw_lock[0]
				var way := Vector3(-sin(yaw), 0, -cos(yaw))
				var from: Vector3 = host.global_position
				var dist := 2.4
				var when := 0.0
				var struck := []
				while dist < length:
					var spot: Vector3 = from + way * dist
					var blocked: bool = _reach(from, spot).distance_to(spot) > 0.5
					if blocked: break
					_after(when, func() -> void:
						fx("spike", spot, {"h": 2.2 + phase * 0.5, "life": 1.3})
						for a in _players():
							if struck.has(a): continue
							if ((a.global_position - spot) * Vector3(1, 0, 1)).length() < 1.25:
								struck.append(a)
								_hurt(a, 22.0, spot, 8.0, {"shake": 0.5, "up": 5.0}))
					dist += 1.55
					when += 0.085]]})


## Salto sul giocatore: si vede dove cade, e all'atterraggio parte l'onda da saltare.
func _m_leap() -> void:
	var windup := 0.62
	_start("leap", "Z_Attack_Leap", windup, {"cooldown": 7.0, "aim_until": windup, "steps": [[windup, func() -> void:
			var landing: Vector3 = _spot_on_floor(_reach(host.global_position, _predict(0.95)))
			move["flying"] = true
			move["from"] = host.global_position
			move["to"] = landing
			move["fly_t"] = 0.0
			move["fly_len"] = 0.95
			fx("warn", landing, {"r": 4.6, "t": 0.95, "color": "danger"})]]})


func _run_flight(delta: float) -> void:
	move.fly_t = float(move.fly_t) + delta
	host.attack_clock = minf(host.attack_clock + delta, float(move.windup) + 0.3)
	var k: float = clampf(float(move.fly_t) / float(move.fly_len), 0.0, 1.0)
	var from: Vector3 = move.from
	var to: Vector3 = move.to
	var pos: Vector3 = from.lerp(to, k)
	pos.y += sin(k * PI) * maxf(from.distance_to(to) * 0.32, 3.5)
	host.global_position = pos
	host.velocity = Vector3.ZERO
	if k >= 1.0:
		_land_blast(to, 4.6, 34.0)
		move.erase("flying")
		move["steps"] = []
		move["hold"] = 0.45
		move["total"] = host.attack_clock + 0.4
		move["gap"] = 0.5
		expose(1.1)


func _land_blast(center: Vector3, radius: float, damage: float) -> void:
	_hit_circle(center, radius, damage, 11.0, {"stun": 0.7, "shake": 1.0, "up": 4.0})
	fx("crack", center, {"r": radius + 1.0, "ember": phase >= 1, "shake": 1.0, "life": 8.0})
	_wave(center, 11.0 + phase * 2.0, 9.0, 14.0)


## Macigno: contro chi si nasconde o spara da lontano. Sfonda il riparo e lascia il segno.
func _m_boulder() -> void:
	hidden_for = 0.0
	var windup := 0.95
	_start("boulder", "Z_Attack_Overhead_Smash", windup, {"cooldown": 6.0, "aim_until": windup, "steps": [[windup, func() -> void:
			var aim: Vector3 = _spot_on_floor(_predict(1.15))
			var hand: Vector3 = host.global_position + Vector3.UP * 3.6
			fx("warn", aim, {"r": 2.9, "t": 1.15})
			fx("boulder", hand, {"to": aim, "t": 1.15, "r": 0.85})
			_after(1.15, func() -> void:
				_hit_circle(aim, 2.9, 26.0, 8.0, {"stun": 0.5, "up": 3.5})
				fx("crack", aim, {"r": 3.2, "ember": phase >= 1, "shake": 0.8, "life": 7.0})
				if phase >= 1: _hazard(aim, 2.3, 5.0, "fire", 11.0))]]})


## Capomacello ferito: batte il lampione in fiamme e accende il suolo attorno e sotto di te.
func _m_inferno() -> void:
	var windup := 1.2
	_start("inferno", "Z_Attack_Overhead_Smash", windup, {"cooldown": 11.0, "hold": 1.2, "steps": [[windup * 0.4, func() -> void:
			for i in 5:
				var a: float = TAU * float(i) / 5.0 + 0.4
				var spot: Vector3 = _spot_on_floor(host.global_position + Vector3(cos(a), 0, sin(a)) * 7.0)
				fx("warn", spot, {"r": 2.6, "t": windup * 0.6, "color": "fire"})
			# Il cerchio sotto di te resta dov'era: chi esce in tempo non si brucia (prima il fuoco ti seguiva).
			if is_instance_valid(target):
				move["marked"] = _spot_on_floor(target.global_position)
				fx("warn", move.marked, {"r": 2.6, "t": windup * 0.6, "color": "fire"})],
			[windup, func() -> void:
				for i in 5:
					var a: float = TAU * float(i) / 5.0 + 0.4
					var spot: Vector3 = _spot_on_floor(host.global_position + Vector3(cos(a), 0, sin(a)) * 7.0)
					_fire_burst(spot)
				if move.has("marked"): _fire_burst(move.marked)
				fx("crack", host.global_position, {"r": 4.2, "ember": true, "shake": 1.0, "life": 9.0})
				expose(1.8)]]})


func _fire_burst(spot: Vector3) -> void:
	_hit_circle(spot, 2.6, 16.0, 6.0, {"shake": 0.4, "up": 4.0})
	_hazard(spot, 2.4, 6.0, "fire", 12.0)


# =================================================================== Macellaio
## Tre colpi di mannaia che ti inseguono; l'ultimo spacca terra.
func _m_combo(step: int) -> void:
	var clips := ["Z_Attack_Swipe_R", "Z_Attack_Swipe_L", "Z_Attack_Overhead_Smash"]
	var windup: float = [0.58, 0.46, 0.72][step] * (1.0 - phase * 0.08)
	var last: bool = step == 2
	var opts := {"cooldown": 3.2, "lunge": 4.2 if not last else 5.2, "total": windup + (0.32 if not last else 0.7), "aim_until": windup * 0.72, "steps": [[windup * 0.45, func() -> void:
			fx("warn", host.global_position, {"shape": "cone", "yaw": host.rotation.y, "angle": 1.5 if not last else 1.1, "r": 3.7 if not last else 4.3, "t": windup * 0.55, "color": "blood"})],
			[windup, func() -> void:
				_hit_cone(host.global_position, host.rotation.y, 3.7 if not last else 4.3, 1.5 if not last else 1.1, 13.0 if not last else 24.0, 5.0 if not last else 9.0, {"bleed": 4.0, "shake": 0.5, "heavy": last, "up": 1.0 if not last else 3.0})
				Fx._sound(world, "swing_blade", host.global_position, 3.0, 0.8)
				# Destro, sinistro, dall'alto: la scia segue il verso del braccio.
				_slash(3.7 if not last else 4.3, 1.5 if not last else 1.1, "blood", [0.35, -0.35, 1.3][step], 0.35 if not last else 0.6)
				if last:
					fx("crack", _forward(2.2), {"r": 2.3, "shake": 0.7, "life": 6.0})
					expose(0.9)]]}
	if not last: opts["next"] = func() -> void: _m_combo(step + 1)
	_start("combo", clips[step], windup, opts)


## Chi para si prende un calcio in pieno: la parata non basta contro di lui.
func _m_guardbreak() -> void:
	_start("guardbreak", "Z_Tank_Punch", 0.42, {"cooldown": 5.0, "lunge": 4.5, "steps": [[0.18, func() -> void:
			fx("warn", host.global_position, {"shape": "cone", "yaw": host.rotation.y, "angle": 1.2, "r": 3.2, "t": 0.24, "color": "steel"})],
			[0.42, func() -> void:
				_slash(3.2, 0.9, "steel", 0.0, 0.7)
				Fx._sound(world, "weapon_hit_guard", host.global_position, 4.0, 0.6)
				# Solo dentro lo spicchio avvisato: chi gli è girato attorno non prende il calcio.
				var forward := -host.global_basis.z
				for a in _players():
					var gap: Vector3 = (a.global_position - host.global_position) * Vector3(1, 0, 1)
					if gap.length() < 3.2 and (gap.length() < 0.6 or forward.dot(gap.normalized()) >= cos(0.6)):
						a.melee.blocking = false
						_hurt(a, 10.0, host.global_position, 8.0, {"stun": 1.1, "shake": 0.8})]]})


## Carica lungo una linea decisa in anticipo. Finisce contro un muro o una barricata? Resta stordito.
func _m_charge() -> void:
	var windup: float = 0.82 - phase * 0.08
	_start("charge", "Z_Scream", windup, {"cooldown": 5.0, "aim_until": windup * 0.6, "steps": [[windup * 0.6, func() -> void:
			var aim: Vector3 = _predict(windup * 0.4 + 0.5)
			var way: Vector3 = (aim - host.global_position) * Vector3(1, 0, 1)
			if way.length_squared() > 0.1: host.rotation.y = atan2(-way.x, -way.z)
			fx("warn", host.global_position, {"shape": "line", "yaw": host.rotation.y, "len": 22.0, "width": 2.6, "t": windup * 0.4, "color": "blood"})],
			[windup, func() -> void:
				move["rush"] = true
				move["rush_left"] = 1.7
				move["rush_hit"] = []
				fx("trail", Vector3.ZERO, {"id": host.network_id, "t": 1.7, "color": Color("7a2a20")})
				host.state = CHASE
				host.anim_scale = 1.0
				host.attack_clip = ""]]})


func _run_rush(delta: float) -> void:
	move.rush_left = float(move.rush_left) - delta
	var way := -host.global_basis.z
	var speed: float = float(move.get("rush_speed", 14.0 + phase * 1.5))
	host.velocity.x = way.x * speed
	host.velocity.z = way.z * speed
	var hit: Array = move.rush_hit
	for a in _players():
		if hit.has(a): continue
		if ((a.global_position - host.global_position) * Vector3(1, 0, 1)).length() < 1.75:
			hit.append(a)
			_slash(2.6, 1.4, "blood", 0.0, 0.8)
			fx("crack", a.global_position, {"r": 1.6, "shake": 0.6, "life": 4.0})
			_hurt(a, float(move.get("rush_damage", 26.0)), host.global_position, 12.0, {"bleed": 5.0, "stun": 0.5, "shake": 0.9, "up": 4.0})
	var q := PhysicsRayQueryParameters3D.create(host.global_position + Vector3.UP * 1.2, host.global_position + Vector3.UP * 1.2 + way * 1.5, 1, [host.get_rid()])
	var wall: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(q)
	if not wall.is_empty() and absf((wall.normal as Vector3).y) < 0.6:
		host.velocity = Vector3.ZERO
		fx("crack", host.global_position - way * -0.8, {"r": 2.5, "shake": 1.0, "life": 6.0})
		Fx._sound(world, "weapon_hit_bone", host.global_position, 5.0, 0.55)
		stagger_for(1.4 if style == "signore" else 2.9, "SI È SCHIANTATO!")
		return
	if float(move.rush_left) <= 0.0:
		var chain: Callable = move.get("rush_next", Callable())
		move = {}
		host.state = CHASE
		if chain.is_valid():
			chain.call()
			return
		gap_left = GAP[style][phase]
		expose(0.8)


## Gancio: se non ti scansi o non ti ripari, ti tira da lui e la mannaia è già in aria.
func _m_hook() -> void:
	var windup := 0.78
	var yaw_lock := [0.0]
	_start("hook", "Z_Attack_Jab", windup, {"cooldown": 5.5, "aim_until": 0.42, "total": 1.05, "steps": [[0.42, func() -> void:
			yaw_lock[0] = host.rotation.y
			fx("warn", host.global_position, {"shape": "line", "yaw": yaw_lock[0], "len": 17.0, "width": 1.5, "t": windup - 0.42, "color": "steel"})],
			[windup, func() -> void:
				var way := Vector3(-sin(yaw_lock[0]), 0, -cos(yaw_lock[0]))
				var hand: Vector3 = host.global_position + Vector3.UP * 2.0
				var tip: Vector3 = _reach(host.global_position, host.global_position + way * 17.0) + Vector3.UP * 1.1
				var caught: CharacterBody3D = null
				var best: float = 18.0
				for a in _players():
					var gap: Vector3 = (a.global_position - host.global_position) * Vector3(1, 0, 1)
					var along: float = gap.dot(way)
					if along < 0.5 or along > hand.distance_to(tip) + 0.8: continue
					if (gap - way * along).length() < 1.1 and along < best and host.clear_line(a):
						best = along
						caught = a
				if caught:
					tip = caught.global_position + Vector3.UP * 1.1
				Fx._sound(world, "swing_blunt", hand, 2.0, 1.3)
				fx("chain", hand, {"to": tip, "t": 0.16, "back": 0.32})
				if not caught: return
				var pull: float = maxf(best - 2.3, 0.0) / 0.32
				var back: Vector3 = (host.global_position - caught.global_position) * Vector3(1, 0, 1)
				caught.knock(back.normalized() * clampf(pull, 11.0, 36.0))
				world.hit_player(caught, 8.0, {"bleed": 3.0, "stun": 0.45, "shake": 0.8}, hand)
				move["next"] = func() -> void: _m_combo(2)]]})


## Boomerang: la mannaia va e torna, e nel frattempo lui è disarmato. Tira di lato o abbassati e picchia.
func _m_cleaver() -> void:
	var windup := 0.68
	var flight := 0.62
	_start("cleaver", "Z_Attack_Swipe_R", windup, {"cooldown": 7.5, "aim_until": 0.34, "hold": flight * 2.0, "total": windup + 0.2, "steps": [[0.34, func() -> void:
			fx("warn", host.global_position, {"shape": "line", "yaw": host.rotation.y, "len": 15.0, "width": 1.9, "t": windup - 0.34, "color": "blood"})],
			[windup, func() -> void:
				var way := -host.global_basis.z
				var from: Vector3 = host.global_position + Vector3.UP * 1.5
				var end: Vector3 = _reach(host.global_position, host.global_position + way * 15.0) + Vector3.UP * 1.5
				fx("cleaver", from, {"to": end, "t": flight})
				_pop("È DISARMATO!", WEAK_COLOR, 56)
				expose(flight * 2.0 + 0.4)
				var hit := []
				for i in 16:
					var k: float = float(i + 1) / 16.0
					_after(flight * 2.0 * k, func() -> void:
						var t: float = 1.0 - absf(k * 2.0 - 1.0)
						# La stessa curva dell'effetto: veloce in partenza e al ritorno.
						var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
						var at: Vector3 = from.lerp(end, eased)
						for a in _players():
							if hit.has(a): continue
							if ((a.global_position - at) * Vector3(1, 0, 1)).length() < 1.5:
								hit.append(a)
								_hurt(a, 22.0, at, 7.0, {"bleed": 7.0, "shake": 0.7}))]]})


## Si apre le ferite: pozze attorno. Dentro rallenti e sanguini, e lui ci si rimette in forze: tiralo fuori.
func _m_blood() -> void:
	var windup := 1.0
	_start("blood", "Z_Scream", windup, {"cooldown": 14.0, "steps": [[windup, func() -> void:
			Fx._sound(world, "zombie_brute_alert", host.global_position, 2.0, 0.7)
			_hazard(_spot_on_floor(host.global_position), 3.6, 11.0, "blood", 4.0, {"slow": 1.2, "bleed": 2.0})
			for i in 3:
				var a: float = TAU * float(i) / 3.0 + 0.3
				var spot: Vector3 = _spot_on_floor(host.global_position + Vector3(cos(a), 0, sin(a)) * 7.0)
				_hazard(spot, 2.6, 9.0, "blood", 4.0, {"slow": 1.2, "bleed": 2.0})
			if is_instance_valid(target): _hazard(_spot_on_floor(target.global_position), 2.4, 7.0, "blood", 4.0, {"slow": 1.2, "bleed": 2.0})]]})


# =================================================================== Carceriere
## Terremoto: tre onde una dopo l'altra. Il ritmo del salto è tutto.
func _m_quake() -> void:
	var windup := 1.1
	_start("quake", "Z_Attack_Overhead_Smash", windup, {"cooldown": 7.0, "hold": 0.5, "total": windup + 0.5, "steps": [[windup * 0.4, func() -> void:
			fx("warn", _forward(2.8), {"r": 3.0, "t": windup * 0.6})],
			[windup, func() -> void:
				var center := _forward(2.8)
				_hit_circle(center, 3.0, 30.0, 10.0, {"stun": 0.7, "shake": 1.0, "up": 4.0})
				fx("crack", center, {"r": 4.8, "ember": phase >= 1, "shake": 1.0, "life": 9.0})
				for i in 3 + phase:
					_after(i * 0.8, func() -> void: _wave(center, 16.0, 7.0 + i * 0.7, 15.0))
				expose(1.0)]]})


## Catena al suolo: fa un giro quasi intero. Salta quando arriva, o stagli lontano.
func _m_chain() -> void:
	var windup := 0.92
	var swing := 1.15
	var radius := 10.0
	_start("chain", "Z_Tank_Swipe", windup, {"cooldown": 6.5, "aim_until": 0.5, "hold": swing, "total": windup + 0.3, "steps": [[0.5, func() -> void:
			fx("warn", host.global_position, {"r": radius, "t": windup - 0.5, "color": "steel"})],
			[windup, func() -> void:
				var start: float = host.rotation.y + 2.6
				var travel: float = -TAU * 0.86
				fx("sweep", host.global_position, {"r": radius, "t": swing, "a0": start, "a1": start + travel})
				var hit := []
				for i in 20:
					var k: float = float(i + 1) / 20.0
					_after(swing * k, func() -> void:
						var yaw: float = start + travel * k
						var line := Vector3(-sin(yaw), 0, -cos(yaw))
						for a in _players():
							if hit.has(a) or not a.is_on_floor(): continue
							var gap: Vector3 = (a.global_position - host.global_position) * Vector3(1, 0, 1)
							var along: float = gap.dot(line)
							if along > 0.0 and along < radius and (gap - line * along).length() < 1.0:
								hit.append(a)
								_hurt(a, 24.0, host.global_position, 11.0, {"stun": 0.5, "shake": 0.8, "up": 3.5}))
				expose(swing)]]})


## Gabbia: le sbarre cadono attorno a te. C'è una sola uscita, e lui ti viene addosso.
func _m_cage() -> void:
	var windup := 0.95
	var radius := 3.1
	_start("cage", "Z_Scream", windup, {"cooldown": 16.0, "aim_until": windup, "total": windup + 0.25, "steps": [[0.3, func() -> void:
			if is_instance_valid(target): fx("warn", _spot_on_floor(_predict(0.65)), {"r": radius + 0.5, "t": 0.65, "color": "steel"})],
			[windup, func() -> void:
				if not is_instance_valid(target): return
				var center: Vector3 = _spot_on_floor(_predict(0.0))
				# L'uscita è dalla parte opposta al Carceriere: per scappare devi girargli attorno.
				var away: Vector3 = (center - host.global_position) * Vector3(1, 0, 1)
				var gap: float = atan2(-away.x, -away.z) if away.length_squared() > 0.1 else 0.0
				fx("cage", center, {"r": radius, "life": 3.7, "gap": gap})
				_after(0.32, func() -> void: _build_cage(center, radius, gap, 3.9))
				move["next"] = func() -> void:
					cooldowns["leap"] = 0.0
					_m_leap()]]})


func _build_cage(center: Vector3, radius: float, gap: float, life: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	world.add_child(body)
	body.global_position = center
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		if absf(wrapf(a - gap, -PI, PI)) < 0.42: continue
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 3.6, 0.2)
		shape.shape = box
		body.add_child(shape)
		shape.position = Vector3(-sin(a) * radius, 1.8, -cos(a) * radius)
		shape.rotation.y = a
	bars.append([life, body])


## Il soffitto cede: sassi dove sei e dove stai andando. Fuori dall'arena non succede: lì non c'è soffitto.
func _m_debris() -> void:
	var windup := 0.8
	_start("debris", "Z_Attack_Overhead_Smash", windup, {"cooldown": 10.0, "hold": 0.4, "steps": [[windup, func() -> void:
			fx("crack", _forward(2.6), {"r": 2.8, "shake": 0.8, "life": 6.0})
			for i in 7 + phase * 2:
				var seed_at: Vector3 = _predict(0.9 + i * 0.1)
				var spot: Vector3 = _spot_on_floor(seed_at + (Vector3(_rng.randf_range(-6.5, 6.5), 0, _rng.randf_range(-6.5, 6.5)) if i > 0 else Vector3.ZERO))
				_after(i * 0.13, func() -> void:
					fx("warn", spot, {"r": 2.2, "t": 0.85})
					fx("boulder", spot + Vector3.UP * 11.0, {"to": spot, "t": 0.85, "r": 0.7})
					_after(0.85, func() -> void:
						_hit_circle(spot, 2.2, 20.0, 6.0, {"stun": 0.4, "shake": 0.5, "up": 3.0})
						fx("crack", spot, {"r": 2.2, "shake": 0.45, "life": 5.0})))]]})


## Il pavimento si apre: fessure di fuoco in più punti, si esplodono e restano. Lo spazio per muoversi si stringe.
func _m_fissure() -> void:
	var windup := 1.05
	_start("fissure", "Z_Attack_Overhead_Smash", windup, {"cooldown": 13.0, "hold": 0.8, "steps": [[windup * 0.35, func() -> void:
			var spots := []
			if is_instance_valid(target): spots.append(_spot_on_floor(target.global_position))
			for i in 4 + phase:
				var a: float = _rng.randf() * TAU
				spots.append(_spot_on_floor(host.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(5.0, 12.0)))
			move["spots"] = spots
			for spot in spots: fx("warn", spot, {"r": 2.6, "t": windup * 0.65 + 0.15, "color": "fire"})],
			[windup + 0.15, func() -> void:
				for spot in move.get("spots", []):
					fx("crack", spot, {"r": 3.0, "ember": true, "shake": 0.6, "life": 8.0})
					_hit_circle(spot, 2.6, 18.0, 7.0, {"up": 5.0, "shake": 0.5})
					_hazard(spot, 2.3, 7.0, "fire", 12.0)
				expose(1.6)]]})


# =================================================================== Il Mago
## La scultura non ha ossa: le zone si colpiscono a quote fisse.
func _place_hitboxes() -> void:
	for area in host.hitboxes:
		var zone: String = host.coarse(area.get_meta("zone"))      # zone fini (#27): thigh_l, hand_r... tornano ai gruppi
		area.position = Vector3(0, {"head": 3.4, "neck": 3.0, "torso": 2.0, "legs": 1.0, "feet": 0.5}.get(zone, 2.0), 0)


func _options_matriarca(dist: float) -> Array:
	return [
		["blink", (9.0 if dist < 6.5 else 0.0)],
		["nova", (5.0 if dist < 9.0 else 0.0)],
		["bolts", (3.0 if dist > 5.0 else 0.0)],
		["pool", (2.6 if dist < 30.0 else 0.0)],
		["storm", (2.2 + phase * 1.2 if dist > 6.0 else 0.0)],
		["brood", (2.0 if phase >= 1 else 0.0)],
	]


## Dardi a ventaglio: uno su di te, due dove potresti scappare.
func _m_bolts() -> void:
	var windup := 0.72
	_start("bolts", "Z_Spit", windup, {"cooldown": 3.0, "aim_until": windup, "total": windup + 0.3, "steps": [[windup, func() -> void:
		var count: int = 3 + phase
		var flight := 0.85
		var center: Vector3 = _predict(flight)
		var side: Vector3 = (center - host.global_position).cross(Vector3.UP).normalized()
		for i in count:
			var spread: float = (float(i) - float(count - 1) * 0.5) * 3.6
			var spot: Vector3 = _spot_on_floor(center + side * spread)
			fx("warn", spot, {"r": 2.0, "t": flight, "color": "acid"})
			fx("bolt", host.global_position + Vector3.UP * 3.0, {"to": spot, "t": flight})
			_after(flight, func() -> void:
				_hit_circle(spot, 2.0, 13.0, 4.0, {"poison": 4.0, "shake": 0.35, "up": 1.5, "env": true})
				_hazard(spot, 1.8, 4.0, "acid", 6.0, {"poison": 1.5}))]]})


## Pioggia acida attorno a te: la terra resta avvelenata e lo spazio si stringe.
func _m_pool() -> void:
	var windup := 0.95
	_start("pool", "Z_Scream", windup, {"cooldown": 7.0, "aim_until": windup, "steps": [[0.2, func() -> void:
		if not is_instance_valid(target): return
		var spots := [_spot_on_floor(target.global_position)]
		for i in 4 + phase:
			var a: float = TAU * float(i) / float(4 + phase) + _rng.randf()
			spots.append(_spot_on_floor(target.global_position + Vector3(cos(a), 0, sin(a)) * 6.0))
		move["spots"] = spots
		for spot in spots: fx("warn", spot, {"r": 2.5, "t": windup - 0.2, "color": "acid"})],
		[windup, func() -> void:
			for spot in move.get("spots", []):
				_hit_circle(spot, 2.5, 12.0, 3.0, {"poison": 4.0, "shake": 0.3, "env": true})
				_hazard(spot, 2.4, 6.5, "acid", 8.0, {"poison": 2.0})]]})


## Le sei addosso: sparisce e riappare lontano, lasciando una pozza dov'era.
func _m_blink() -> void:
	var windup := 0.38
	_start("blink", "Z_Scream", windup, {"cooldown": 4.0, "aim_until": 0.0, "total": windup + 0.12, "gap": 0.55, "steps": [[windup, func() -> void:
		var from: Vector3 = host.global_position
		_hazard(_spot_on_floor(from), 2.6, 5.0, "acid", 8.0, {"poison": 2.0})
		fx("crack", from, {"r": 2.0, "shake": 0.3, "life": 4.0})
		var away: Vector3 = (from - target.global_position) * Vector3(1, 0, 1) if is_instance_valid(target) else Vector3.BACK
		var yaw: float = atan2(away.x, away.z) + _rng.randf_range(-0.9, 0.9)
		var spot: Vector3 = _reach(from, from + Vector3(sin(yaw), 0, cos(yaw)) * 17.0)
		host.global_position = _spot_on_floor(spot) + Vector3.UP * 0.1
		Fx._sound(world, "swing_blade", host.global_position, 0.0, 0.5)]]})


## Onda acida tutto attorno: si salta.
func _m_nova() -> void:
	var windup := 0.68
	_start("nova", "Z_Scream", windup, {"cooldown": 6.0, "aim_until": 0.0, "steps": [[0.05, func() -> void:
		fx("warn", host.global_position, {"r": 3.5, "t": windup - 0.05, "color": "acid"})],
		[windup, func() -> void:
			_hit_circle(host.global_position, 3.5, 16.0, 11.0, {"poison": 3.0, "shake": 0.5})
			_wave(host.global_position, 15.0, 9.0, 15.0, "acid")
			if phase >= 1: _after(0.7, func() -> void: _wave(host.global_position, 15.0, 9.0, 15.0, "acid"))]]})


## Tempesta: resta ferma tre secondi, e se nessuno la interrompe il veleno cade ovunque. Un tiro la ferma: ecco il momento.
func _m_storm() -> void:
	var windup := 0.45
	var channel := 3.3
	_start("storm", "Z_Scream", windup, {"cooldown": 14.0, "hold": channel, "aim_until": 0.0, "total": windup + 0.2, "steps": [[windup, func() -> void:
		fx("say", Vector3.ZERO, {"text": "IL MAGO · EVOCA LA TEMPESTA · INTERROMPILA!", "t": 3.0})
		if veil:
			veil = false
			veil_back = channel + 0.6
			fx("veil", Vector3.ZERO, {"id": host.network_id, "on": false})
		expose(channel)
		var drops: int = 7 + phase * 2
		for i in drops:
			_after(channel * float(i + 1) / float(drops), func() -> void:
				for a in _players():
					var r: float = _rng.randf_range(0.0, 7.5)
					var angle: float = _rng.randf() * TAU
					var spot: Vector3 = _spot_on_floor(a.global_position + Vector3(cos(angle), 0, sin(angle)) * r)
					fx("warn", spot, {"r": 2.2, "t": 0.6, "color": "acid"})
					fx("bolt", spot + Vector3.UP * 13.0, {"to": spot, "t": 0.6})
					_after(0.6, func() -> void:
						_hit_circle(spot, 2.2, 13.0, 3.0, {"poison": 3.0, "shake": 0.35})
						_hazard(spot, 1.9, 5.0, "acid", 7.0, {"poison": 1.5})))]]})


func _m_brood() -> void:
	_summon("brood", [4, 4, 1] if phase >= 2 else [4, 4], "acid")


## Evocazione: cerchi a terra fra il boss e te, poi la terra erutta (fa male a chi ci sta sopra) e ne escono i mostri.
func _summon(id: String, kinds: Array, color: String) -> void:
	var windup := 0.9
	var spots := []
	_start(id, "Z_Scream", windup, {"cooldown": 16.0 if id == "brood" else 15.0, "aim_until": 0.0, "steps": [[0.1, func() -> void:
		var toward: Vector3 = (target.global_position - host.global_position) * Vector3(1, 0, 1) if is_instance_valid(target) else -host.global_basis.z
		var base: float = atan2(toward.x, toward.z)
		for i in kinds.size():
			var a: float = base + (float(i) - float(kinds.size() - 1) * 0.5) * 0.9
			var spot: Vector3 = _spot_on_floor(_reach(host.global_position, host.global_position + Vector3(sin(a), 0, cos(a)) * 5.5))
			spots.append(spot)
			fx("warn", spot, {"r": 2.2, "t": windup - 0.1, "color": color})],
		[windup, func() -> void:
			for spot in spots:
				fx("crack", spot, {"r": 2.4, "shake": 0.5, "life": 6.0})
				_hit_circle(spot, 2.2, 12.0, 8.0, {"shake": 0.4, "up": 4.0, "poison": 2.0} if color == "acid" else {"shake": 0.4, "up": 4.0})
				if color == "acid": _hazard(spot, 1.8, 4.0, "acid", 6.0, {"poison": 1.5})
			_spawn_adds(kinds, spots)]]})


func _spawn_adds(kinds: Array, spots: Array) -> void:
	adds = adds.filter(func(e): return is_instance_valid(e) and not e.dead)
	for i in kinds.size():
		if adds.size() >= MAX_ADDS: return
		var add: Node3D = world._spawn_enemy(spots[i])
		add.set_kind(kinds[i], 2)
		if is_instance_valid(target): add.hear(target, 60.0)
		adds.append(add)


# =================================================================== Il Signore delle Teste
func _options_signore(dist: float) -> Array:
	var guarded: bool = target.melee.blocking
	return [
		["combo", (3.2 if dist < 3.6 else 0.0)],
		["guardbreak", (7.0 if guarded and dist < 3.6 else 0.0)],
		["spin", (8.0 if behind_for > 0.8 and dist < 5.5 else 0.0)],
		["dash", (3.4 if dist > 4.5 and dist < 18.0 else 0.0)],
		["leap", (2.4 if dist > 7.0 and dist < 26.0 else 0.0) * (2.5 if far_for > 2.0 else 1.0)],
		["heads", (2.8 if dist > 5.0 else 0.0) + hidden_for],
		["court", (2.2 if phase >= 1 else 0.0)],
	]


## Tre scatti di seguito, ognuno con la sua linea: si legge il ritmo e ci si scansa ogni volta.
func _m_dash(left: int) -> void:
	var windup: float = 0.46 - phase * 0.05
	_start("dash", "Z_Attack_Lunge_Bite", windup, {"cooldown": 5.5, "aim_until": windup * 0.65, "steps": [[windup * 0.65, func() -> void:
		var aim: Vector3 = _predict(windup * 0.35 + 0.3)
		var way: Vector3 = (aim - host.global_position) * Vector3(1, 0, 1)
		if way.length_squared() > 0.1: host.rotation.y = atan2(-way.x, -way.z)
		fx("warn", host.global_position, {"shape": "line", "yaw": host.rotation.y, "len": 13.0, "width": 2.2, "t": windup * 0.35, "color": "danger"})],
		[windup, func() -> void:
			move["rush"] = true
			move["rush_left"] = 0.72
			move["rush_hit"] = []
			fx("trail", Vector3.ZERO, {"id": host.network_id, "t": 0.72})
			move["rush_speed"] = 18.0
			move["rush_damage"] = 17.0
			if left > 0: move["rush_next"] = func() -> void: _m_dash(left - 1)
			host.state = CHASE
			host.anim_scale = 1.0
			host.attack_clip = ""]]})


## Lancia teste che cadono e scoppiano un attimo dopo: si esce dai cerchi, poi lui è già lì.
func _m_heads() -> void:
	var windup := 0.62
	_start("heads", "Z_Attack_Swipe_R", windup, {"cooldown": 6.0, "aim_until": windup, "steps": [[windup, func() -> void:
		var count: int = 3 + phase
		var flight := 0.75
		var center: Vector3 = _predict(flight + 0.3)
		for i in count:
			var spot: Vector3 = _spot_on_floor(center + (Vector3(_rng.randf_range(-5.0, 5.0), 0, _rng.randf_range(-5.0, 5.0)) if i > 0 else Vector3.ZERO))
			fx("warn", spot, {"r": 2.7, "t": flight + 0.3, "color": "danger"})
			fx("boulder", host.global_position + Vector3.UP * 2.8, {"to": spot, "t": flight, "r": 0.34, "color": Color("d0c6a6")})
			_after(flight + 0.3, func() -> void:
				_hit_circle(spot, 2.7, 16.0, 9.0, {"shake": 0.45, "up": 4.0})
				fx("crack", spot, {"r": 2.6, "shake": 0.45, "life": 6.0}))]]})


func _m_court() -> void:
	_summon("court", [1, 1, 1] if phase >= 2 else [1, 1], "danger")


# =================================================================== colpi ricevuti
## Ogni boss teme qualcosa e se ne frega di altro. Questa è la cifra che arriva davvero alla vita.
func on_hit(zone: String, amount: float, weapon: String, heavy: bool) -> float:
	if in_intro():
		_resist("STA ARRIVANDO")
		return 0.0
	var multiplier := 1.0
	if exposed > 0.0: multiplier *= 1.5
	match style:
		"capomacello": multiplier *= _hit_capomacello(weapon)
		"macellaio": multiplier *= _hit_macellaio(weapon)
		"matriarca": multiplier *= _hit_matriarca(weapon)
		"signore": multiplier *= _hit_signore(amount, weapon)
		_: multiplier *= _hit_carceriere(amount, weapon, heavy)
	if phase >= 0 and zone == "head" and style == "carceriere" and plates > 0: multiplier *= 0.6
	var dealt: float = amount * multiplier
	# La vita la toglie zombie_target.receive_hit con il suo fattore di zona: la morte si decide su quella cifra, non prima.
	# Gambe e piedi lì non scendono mai sotto 1 (il boss non striscia): il colpo che ucciderebbe lo finisce subito dopo.
	if _low(zone):
		if dealt * 0.45 >= host.health - 1.0 and host.health > 0.0 and not dying:
			host.call_deferred("receive_hit", "torso", host.max_health * 10.0, Vector3.ZERO, weapon, true)
	elif dealt * (2.5 if zone == "head" else (1.3 if zone == "neck" else 1.0)) >= host.health and not dying:
		_death()
	return dealt


static func _low(zone: String) -> bool:
	return zone in ["legs", "feet"] or zone.begins_with("thigh") or zone.begins_with("calf") or zone.begins_with("foot")


## Il colpo che lo uccide: la morte la disegna boss_fx su ogni computer. Dopo, niente più colpi rimasti in sospeso.
func _death() -> void:
	dying = true
	move = {}
	events.clear()
	waves.clear()
	hazards.clear()
	_free_bars()
	fx("death", host.global_position, {"look": style, "id": host.network_id})


## Le sbarre della gabbia sono corpi nel mondo, non figli del boss: da morto o tolto di scena non le toglierebbe più nessuno.
func _free_bars() -> void:
	for row in bars:
		if is_instance_valid(row[1]): row[1].queue_free()
	bars.clear()


func _exit_tree() -> void:
	_free_bars()


func _hit_capomacello(weapon: String) -> float:
	if FIRE.has(weapon):
		var fresh: bool = burning <= 0.0
		burning = 6.0
		if fresh:
			fx("burn", Vector3.ZERO, {"id": host.network_id, "t": 6.0})
			_pop("IL SERBATOIO BRUCIA!", WEAK_COLOR, 70)
			# Il fuoco gli entra nei tubi: si ferma un attimo, urlando.
			if stun <= 0.0 and move.get("id", "") != "leap": stagger_for(1.3)
		return 2.6
	if burning > 0.0:
		_weak("BRUCIA +50%")
		return 1.5
	if LIGHT_GUNS.has(weapon) or SMALL_BLADES.has(weapon):
		_resist("RESISTE")
		return 0.55
	return 1.0


func _hit_macellaio(weapon: String) -> float:
	if SHOTGUN.has(weapon):
		# Conta chi è vicino, non solo la sua preda: in coop spara spesso l'altro.
		var near: CharacterBody3D = world.nearest_player(host.global_position)
		var dist: float = host.global_position.distance_to(near.global_position) if is_instance_valid(near) else 99.0
		_weak("DEBOLE!")
		# Da vicino, a metà carica o a metà colpo: la rosa lo butta giù.
		var committed: bool = move.get("rush", false) or move.get("id", "") in ["charge", "combo"]
		if dist < 8.0 and committed and stun <= 0.0:
			stagger_for(2.5, "FERMATO!")
		return 2.1
	if ARROWS.has(weapon):
		_resist("NON SENTE LE FRECCE")
		return 0.5
	if LIGHT_GUNS.has(weapon):
		_resist("RESISTE")
		return 0.7
	return 1.0


func _hit_carceriere(amount: float, weapon: String, heavy: bool) -> float:
	if plates <= 0:
		return 1.3 if BLUNT.has(weapon) else 1.15
	if BLUNT.has(weapon):
		plate_hp -= amount * (1.6 if heavy else 1.0)
		if plate_hp <= 0.0:
			plates -= 1
			plate_hp = PLATE_HP
			fx("plate", host.global_position + Vector3.UP * 3.0)
			if plates > 0:
				stagger_for(1.5, "PIASTRA ROTTA! Ne restano %d" % plates)
			else:
				stagger_for(3.2, "CORAZZA DISTRUTTA!")
		else:
			_weak("LA CORAZZA CEDE")
		return 1.0
	_resist("RIMBALZA SULLA CORAZZA")
	return 0.3


func _hit_matriarca(weapon: String) -> float:
	var long_shot: bool = LONG_SHOTS.has(weapon)
	if veil:
		if long_shot:
			veil = false
			veil_back = 7.0
			fx("veil", Vector3.ZERO, {"id": host.network_id, "on": false})
			if stun <= 0.0: stagger_for(1.5, "VELO STRAPPATO!")
			return 1.6
		_resist("IL VELO ASSORBE")
		return 0.2
	# Scoperta, e se stava evocando la tempesta si ferma.
	if move.get("id", "") == "storm" and stun <= 0.0: stagger_for(2.0, "TEMPESTA INTERROTTA!")
	if long_shot:
		_weak("DEBOLE!")
		return 1.8
	return 1.15


func _hit_signore(amount: float, weapon: String) -> float:
	if skulls <= 0:
		return 1.35 if BLADES.has(weapon) else 1.1
	if BLADES.has(weapon):
		skull_hp -= amount
		if skull_hp <= 0.0:
			skulls -= 1
			skull_hp = SKULL_HP
			fx("crown", Vector3.ZERO, {"id": host.network_id, "left": skulls})
			fx("plate", host.global_position + Vector3.UP * 3.3)
			stagger_for(1.1, "TESCHIO TAGLIATO! Ne restano %d" % skulls if skulls > 0 else "CORONA DISTRUTTA!")
		else:
			_weak("IL TESCHIO SI CREPA")
		return 1.0
	_resist("LA CORONA DEVIA IL COLPO")
	return 0.35


func _weak(text: String) -> void:
	_pop(text, WEAK_COLOR, 54)


func _resist(text: String) -> void:
	_pop(text, RESIST_COLOR, 44)


func _pop(text: String, color: Color, size: int) -> void:
	if pop_clock > 0.0: return
	pop_clock = 0.55
	var tall: float = float(STAND_HEIGHT.get(style, 3.5))
	fx("pop", host.global_position + Vector3.UP * tall + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5)), {"text": text, "color": color, "size": size})


func _phase_changed() -> void:
	var line := ""
	match style:
		"capomacello":
			line = "CAPOMACELLO · Il lampione prende fuoco!" if phase == 1 else "CAPOMACELLO · Non si ferma più!"
			if phase == 1: fx("burn", Vector3.ZERO, {"id": host.network_id, "t": 4.0})
		"macellaio":
			line = "IL MACELLAIO · Sente l'odore del sangue" if phase == 1 else "IL MACELLAIO · È furioso!"
		_:
			line = "%s · FASE %d" % [NAMES.get(style, ""), phase + 1]
	if line != "": fx("say", Vector3.ZERO, {"text": line, "t": 4.0})
	# Cambio di fase visibile a tutti: lampo rosso, onda, ruggito e un'aura che resta (più forte in fase 3).
	fx("flash", Vector3.ZERO, {"id": host.network_id, "color": Color(1.0, 0.15, 0.1, 0.45), "t": 1.6})
	fx("ring", host.global_position, {"r": 9.0 + phase * 3.0, "speed": 12.0, "color": "danger"})
	fx("rage", Vector3.ZERO, {"id": host.network_id, "level": phase})
	_sound("explosion", 0.0, 0.55)
	# Il Carceriere ruggisce già da rocca.gd, il Macellaio dal paese: qui solo un attimo di pausa se è libero.
	if move.is_empty() and stun <= 0.0 and style == "capomacello": host.alert_time = 1.3
