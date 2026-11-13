extends "res://enemies/zombie_target.gd"
enum State { WANDER, CHASE, ATTACK, DEAD }
var state: State = State.WANDER
var agent: NavigationAgent3D
var world: Node3D
var target: CharacterBody3D
var memory: float = 0
var think: float = 0
var wander_timer: float = 0
var attack_clock: float = 0
var attack_done: bool = false
var corpse_time: float = 0
var network_id: int = 0
var replica: bool = false
var last_seen := Vector3.ZERO
# Movement / attack tuning (0 = normale, 1 = runner, 2 = bruto, 3 = elite). Normal infected never run.
const Motion = preload("res://art/infected_motion.gd")
# 4 = sputatore (attacco a distanza), 5 = boss "Il Carceriere" (Rocca e Cripta)
const CHASE_SPEED := [0.95, 4.2, 0.8, 1.3, 1.0, 1.75]
const WANDER_SPEED := [0.5, 0.7, 0.45, 0.55, 0.5, 0.6]
const HIT_DAMAGE := [14, 12, 26, 16, 9, 30]
const Spit = preload("res://enemies/spit_projectile.gd")
var attack_clip: String = ""
var attack_serial: int = 0
var attack_hit: float = 0.62
var attack_len: float = 1.25
var attack_reach: float = 1.8
var attack_lunge: float = 0.0
var alert_time: float = 0
var anim_scale: float = 1.0        # >1 = attacchi più lenti e pesanti (boss)
var spit_cooldown: float = 1.0
var leap_cooldown: float = 5.0
var _spit_shown: bool = false
## Giro di pattuglia (punti in coordinate globali). Vuoto = vagare intorno a home come prima.
var patrol: PackedVector3Array = PackedVector3Array()
var patrol_i: int = 0
var step_clock: float = 0.0
## L'urlatore ha chiamato: chi lo sente corre di più per qualche secondo.
var frenzy: float = 0.0
var scream_cooldown: float = 0.0
# Scavalcare e aggirare (vedi _steer).
## Sblocco camminando, mai teletrasporti: ricalcolo → punto intermedio → deviazione → arretramento → rivaluta il bersaglio.
const RECOVER_STEPS := [[1.0, "ricalcolo"], [1.0, "intermedio"], [1.5, "deviazione"], [2.5, "deviazione"], [3.0, "arretramento"], [4.0, "rinuncia"]]
var recoveries := {}               # quante volte ha usato ogni passo (letto dai test)
var _recover_dir := Vector3.ZERO
var _recover_left := 0.0
var _give_up_until := 0.0
var searched := 0                  # punti di ricerca visitati dopo averti perso (letto dai test)
var _contact_at := -99.0
var _search_at := Vector3.INF
var _search_until := 0.0
var _probe_clock: float = 0.0
var _climb_top: float = -INF
var _climb_left: float = 0.0
var _climb_dir := Vector3.ZERO
var _detour_side: float = 0.0
var _heading := Vector3.ZERO
var _detour_start: float = 0.0
var _detour_time: float = 0.0
var _stuck_clock: float = 0.0
var _stuck_for: float = 0.0
var _stuck_at := Vector3.ZERO
## Il cervello dei boss (bosses/boss_brain.gd): se c'è, decide lui mosse e colpi. Solo sull'host.
var brain: Node
var voice_id := "capomacello"
var speed_mul := 1.0              # ognuno ha il suo passo: non si muovono a tempo come soldatini
## Il colpo è "deciso" poco prima di arrivare: da lì non ti segue più, un passo di lato o la scivolata lo manda a vuoto.
const COMMIT := 0.22
## Al massimo due addosso allo stesso giocatore: gli altri gli girano attorno e aspettano il turno.
const MAX_ATTACKERS := 2
var whiffed := false              # colpo a vuoto: resta sbilanciato e i colpi che prende valgono di più
var combo_left := 0               # secondo colpo veloce dopo uno andato a segno
var pounce_cooldown := 3.0        # slancio da due passi di distanza
var _waiting := false
## Colpi misurati sulle clip (ossa delle mani e della testa, tests/zombie_attack_matrix.gd): [parti che colpiscono,
## inizio e fine della finestra attiva, contatto, distanza radice-bersaglio a cui il gesto arriva], secondi a velocità 1.
## Nei dati lo schianto dall'alto colpiva a 0,80 s con le mani ancora alzate: scendono tra 1,30 e 1,50 s.
## Le due manate le dà entrambe la mano destra del modello.
const STRIKES := {
	"Z_Attack_Swipe_R": [["hand_r"], 0.62, 0.84, 0.72, 0.75],
	"Z_Attack_Swipe_L": [["hand_r"], 0.60, 0.82, 0.70, 0.75],
	"Z_Attack_Headbutt": [["head", "hand_l", "hand_r"], 0.60, 0.80, 0.70, 0.6],
	"Z_Attack_Jab": [["hand_r"], 0.56, 0.76, 0.66, 0.75],
	"Z_Attack_Overhead_Smash": [["hand_l", "hand_r"], 1.28, 1.52, 1.40, 1.0],
	"Z_Attack_Leap": [["hand_l", "hand_r", "head"], 0.42, 0.62, 0.50, 0.9],
	"Z_Crawl_Attack": [["head", "hand_l", "hand_r"], 0.42, 0.66, 0.53, 0.7],
	"Z_Tank_Swipe": [["hand_l", "hand_r"], 0.58, 0.78, 0.68, 1.1],
	"Z_Tank_Punch": [["hand_r"], 0.24, 0.40, 0.30, 1.05],
}
## Passo durante la carica (m/s), per tipo: chi ti è addosso ti viene incontro mentre carica, non colpisce l'aria dov'eri.
const STEP_MAX := [2.2, 3.0, 1.6, 2.2, 1.4, 2.0]
## Previsione breve e limitata: mira dove sarai fra poco, al massimo 0,4 s e 1,4 m più in là.
const LEAD_TIME := 0.4
const LEAD_MAX := 1.4
## Giro massimo (rad/s) mentre carica e dopo il colpo deciso: dopo non ti segue più del tutto, la schivata giusta funziona.
const TURN_AIM := 7.0
const TURN_COMMIT := 1.2
## Due attacchi sullo stesso giocatore partono sfalsati di almeno tanto.
const STAGGER_START := 0.35
var attack_parts: Array = []
var attack_from := 0.0           # finestra attiva (s, già scalata)
var attack_until := 0.0
var attack_gap := 0.95           # distanza a cui il gesto arriva
var _sweep_prev := {}
var _sweep_best := INF           # quanto ci è andato vicino (m dalla capsula), per i test e il motivo del mancato
var _sweep_wall := false
## L'ultimo attacco, misurato (lo leggono i test): distanza, velocità, clip, tempi, rotazione, spostamento, esito.
var last_attack := {}

func setup(variant: int) -> void:
	super.setup(variant)
	agent = NavigationAgent3D.new()
	# Follow door corners closely; a wide acceptance radius cuts across the jamb.
	agent.path_desired_distance = 0.2
	agent.path_height_offset = 0.4
	agent.target_desired_distance = 0.65
	agent.radius = 0.4
	add_child(agent)
	visual.rotation.y = PI
	wander_timer = randf_range(1,3)
	speed_mul = randf_range(0.88, 1.15)

func use_brain(style: String) -> void:
	if replica or brain: return
	brain = preload("res://bosses/boss_brain.gd").new()
	add_child(brain)
	brain.setup(self, world, style)


## Percezione valida (vista o rumore): aggiorna dove crede che tu sia e quanto se lo ricorda.
func _contact(at: Vector3, remember: float) -> void:
	last_seen = at
	memory = maxf(memory, remember)
	_contact_at = clock
	_search_at = Vector3.INF


## Vista durante l'inseguimento: testa o fianchi liberi bastano (una cassetta bassa non ti nasconde, un muro sì).
func _glimpse(candidate: CharacterBody3D) -> bool:
	var eye := global_position + Vector3.UP * 1.3
	for h in [1.6, 0.6]:
		if _hit_at(eye, candidate.global_position + Vector3.UP * h).is_empty(): return true
	return false


## Perso di vista: va dove ti ha visto l'ultima volta, poi gira lì attorno finché se lo ricorda.
func _search() -> void:
	var flat := Vector2(global_position.x - last_seen.x, global_position.z - last_seen.z).length()
	if _search_at == Vector3.INF:
		agent.target_position = last_seen
		# Sta ancora andando a vedere: non dimentica a metà strada (al massimo 30 s; se si incastra ci pensa lo sblocco).
		if flat > 1.5:
			if clock - _contact_at < 30.0: memory = maxf(memory, 1.0)
			return
		memory = maxf(memory, 6.0)        # arrivato sul posto: ancora qualche secondo per cercare
	elif Vector2(global_position.x - _search_at.x, global_position.z - _search_at.z).length() > 1.2 and clock < _search_until:
		return
	searched += 1
	var turn := randf() * TAU
	_search_at = last_seen + Vector3(cos(turn), 0, sin(turn)) * randf_range(2.5, 5.0)
	_search_until = clock + 4.0
	agent.target_position = _search_at


func see(candidate: CharacterBody3D) -> bool:
	if not is_instance_valid(candidate) or candidate.dead: return false
	if world and world.has_method("is_safe") and world.is_safe(candidate.position):return false
	var offset := candidate.global_position-global_position
	# sputatori e boss tengono d'occhio tutta la sala
	var sight := 34.0 if kind == 4 else (30.0 if kind == 5 else 15.0)
	if offset.length() > sight: return false
	if kind < 4 and offset.length() > 2.5 and (-global_basis.z).dot(offset.normalized()) < 0.25: return false
	return clear_line(candidate)

func clear_line(candidate: CharacterBody3D) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.3,candidate.global_position+Vector3.UP,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func hear(candidate: CharacterBody3D, radius: float = 15) -> void:
	if dead or candidate.dead or global_position.distance_to(candidate.global_position)>radius: return
	if world and world.has_method("is_safe") and world.is_safe(candidate.position):return
	_contact(candidate.global_position, 6.0)
	# Un rumore (passi, colpi, spari) non interrompe un attacco già partito: prima lo annullava a metà carica.
	if state == State.ATTACK: return
	target = candidate
	state = State.CHASE

## Fa partire subito un attacco "scriptato" (il Carceriere che atterra dalla gabbia: Z_Boss_Drop_Arrival).
func force_attack(clip: String) -> void:
	_begin_attack(clip, 0.0)

func receive_hit(zone:String,amount:float,force:Vector3,weapon:String,heavy:bool=false) -> bool:
	if replica:return false
	# Contrattacco: colpito mentre è sbilanciato dopo un colpo a vuoto, incassa di più e barcolla.
	if whiffed and state == State.ATTACK and not dead:
		amount *= 1.35
		heavy = true
	if brain and not dead: amount = brain.on_hit(zone, amount, weapon, heavy)
	var result:=super.receive_hit(zone,amount,force,weapon,heavy)
	if kind==5 and result:
		stagger=0.3 if heavy else 0.0      # il boss non barcolla ai colpi leggeri
		velocity=Vector3(velocity.x*0.2,velocity.y,velocity.z*0.2)
	if dead:state=State.DEAD;corpse_time=300
	elif result and world:
		var nearest:CharacterBody3D=world.nearest_player(global_position)
		if nearest:hear(nearest,40)
	return result

func _physics_process(delta: float) -> void:
	if replica:
		# client: lo sputo si vede anche qui (solo effetto, il danno lo fa l'host)
		if kind==4 and state==State.ATTACK and not dead:
			if attack_clock>=0.66 and not _spit_shown and world and is_instance_valid(world.nearest_player(global_position)):
				_spit_shown=true
				var aim:CharacterBody3D=world.nearest_player(global_position)
				Spit.launch(world,mouth_position(),aim.global_position+Vector3.UP*1.0,true)
		elif state!=State.ATTACK:_spit_shown=false
		return
	if dead:
		corpse_time -= delta
		if corpse_time <= 0: queue_free(); return
		super._physics_process(delta)
		return
	if brain:
		brain.tick(delta)
		return
	clock += delta
	stagger = maxf(0,stagger-delta)
	spit_cooldown = maxf(0,spit_cooldown-delta)
	leap_cooldown = maxf(0,leap_cooldown-delta)
	pounce_cooldown = maxf(0,pounce_cooldown-delta)
	frenzy = maxf(0,frenzy-delta)
	scream_cooldown = maxf(0,scream_cooldown-delta)
	think -= delta
	memory = maxf(0,memory-delta)
	if think <= 0:
		think = 0.2
		var nearest: CharacterBody3D = world.nearest_player(global_position) if world else null
		if not nearest or nearest.global_position.distance_to(global_position)>50:
			think = 0.8
			velocity = Vector3.ZERO
			return
		if see(nearest) and (clock >= _give_up_until or state != State.WANDER):
			if state == State.WANDER and kind != 2 and (network_id % 3 != 2 or kind == 5):
				alert_time = 1.3                      # Z_Scream before the chase
				_voice("alert")
				if kind == 3: _scream(nearest)
			target = nearest
			_contact(target.global_position, 8.0)
			if state != State.ATTACK: state = State.CHASE
		# Chi ti insegue ti tiene d'occhio tutt'attorno, ma solo se ti vede davvero: niente telepatia dietro i muri.
		if state == State.CHASE and is_instance_valid(target) and not target.dead and target.global_position.distance_to(global_position) < 25.0 and _glimpse(target):
			_contact(target.global_position, 8.0)
		if state == State.CHASE and clock - _contact_at > 0.6:
			_search()
		elif state == State.CHASE:
			_search_at = Vector3.INF
			agent.target_position = last_seen
			# Da vicino ti accerchiano: ognuno prende il suo lato invece di mettersi in fila dietro al primo.
			if is_instance_valid(target) and kind < 4 and not crawling:
				var from_target: Vector3 = (global_position - last_seen) * Vector3(1, 0, 1)
				var gap := from_target.length()
				if gap > 1.8 and gap < 12.0:
					# Più sono lontani più si allargano: arrivano da lati diversi, non in fila indiana.
					var side := (float(network_id % 5) - 2.0) * (0.45 + clampf((gap - 3.0) / 9.0, 0.0, 1.0) * 0.35)
					var flank: Vector3 = last_seen + from_target.normalized().rotated(Vector3.UP, side) * clampf(gap * 0.45, 1.1, 3.5)
					# Il punto di lato deve stare dalla parte del giocatore: se c'è un muro in mezzo (giocatore in casa) si va dritti,
					# altrimenti l'infetto resta fermo fuori dalla parete per sempre.
					var wall := PhysicsRayQueryParameters3D.create(last_seen + Vector3.UP, flank + Vector3.UP, 1)
					if get_world_3d().direct_space_state.intersect_ray(wall).is_empty(): agent.target_position = flank
	if push_left > 0:
		# Spinta della reazione (due passi di lato, 1,5 m all'indietro dopo il calcio...).
		push_left -= delta
		velocity.x = push_velocity.x
		velocity.z = push_velocity.z
		if state == State.ATTACK: state = State.CHASE
	elif stagger > 0:
		velocity.x = move_toward(velocity.x,0,10*delta)
		velocity.z = move_toward(velocity.z,0,10*delta)
		if reaction != "" and state == State.ATTACK: state = State.CHASE
	elif state == State.ATTACK:
		attack_clock += delta
		visual.rotation.x = 0
		var to_target := Vector3.ZERO
		if is_instance_valid(target):
			to_target = target.global_position - global_position
			to_target.y = 0
		_track(delta)
		var melee_hit: bool = attack_clip != "Z_Spit" and kind != 5
		if melee_hit and not attack_done and attack_clock >= attack_from:
			# Finestra attiva: mano, avambraccio o testa devono toccare davvero la capsula (vedi _sweep).
			var victim: CharacterBody3D = _sweep()
			if victim:
				attack_done = true
				var parried: bool = victim.get("melee") != null and victim.melee.get("blocking") == true and not crawling
				var dodged: bool = victim.has_method("is_invulnerable") and victim.is_invulnerable()
				var landed := _strike(victim)
				_close_attack("parato" if landed and parried else ("colpito" if landed else ("schivato" if dodged else "protetto")))
				if parried and landed:
					var away := global_position - victim.global_position
					react("blocked", Vector3(away.x, 0, away.z))
					state = State.CHASE
				if not landed: _whiff()
			elif attack_clock >= attack_until:
				# A vuoto (schivato, fuori portata, di lato): il peso lo porta avanti e resta scoperto per un attimo.
				attack_done = true
				_close_attack(_miss_reason())
				_whiff()
		elif attack_clock >= attack_hit and not attack_done:
			attack_done = true
			if attack_clip == "Z_Spit":
				spit_cooldown = 2.7
				if is_instance_valid(target) and not target.dead:
					Spit.launch(world, mouth_position(), target.global_position + Vector3.UP * 1.0)
			elif kind == 5:
				# colpo del Carceriere: onda d'urto intorno al punto d'impatto
				var impact_at := global_position - global_basis.z * 1.6
				var radius := 3.4
				if attack_clip == "Z_Attack_Leap": leap_cooldown = 9.0
				if attack_clip == "Z_Boss_Drop_Arrival":
					impact_at = global_position      # atterraggio: onda d'urto tutto intorno
					radius = 4.2
				_shockwave(impact_at, radius)
				for a in world.actors.values():
					if is_instance_valid(a) and not a.dead and a.global_position.distance_to(impact_at) < radius:
						_boss_hit(a, impact_at)
		# Uno-due: dopo un colpo a segno alcuni tirano subito il secondo dall'altro lato, più veloce.
		if combo_left > 0 and attack_done and state == State.ATTACK and attack_clock >= attack_hit + 0.2:
			combo_left = 0
			if is_instance_valid(target) and not target.dead and to_target.length() < 3.0:
				anim_scale = 0.8
				_begin_attack("Z_Attack_Swipe_R" if attack_clip == "Z_Attack_Swipe_L" else "Z_Attack_Swipe_L", 2.2)
		if attack_clock >= attack_len:
			state = State.CHASE
			visual.rotation.x = 0
	elif alert_time > 0:
		alert_time -= delta
		velocity.x = move_toward(velocity.x, 0, 10 * delta)
		velocity.z = move_toward(velocity.z, 0, 10 * delta)
		if is_instance_valid(target):
			var look := target.global_position - global_position
			rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), delta * 6)
	else:
		var speed: float = WANDER_SPEED[kind] * speed_mul
		_waiting = false
		if state == State.CHASE:
			speed = CHASE_SPEED[kind] * speed_mul * (1.4 if frenzy > 0.0 else 1.0) * _surge(delta)
			if not is_instance_valid(target) or target.dead or memory <= 0:
				state = State.WANDER
				target = null
			else:
				var dist := global_position.distance_to(target.global_position)
				var next_clip := _usable(Motion.pick_attack(kind, network_id, attack_serial + 1, crawling))
				# start = distanza di scelta: da qui in poi valuta se il colpo ti arriva (reachable più sotto).
				var start: float = 4.5 if next_clip == "Z_Attack_Leap" else 3.0
				if kind == 4 and not crawling:
					next_clip = "Z_Spit" if spit_cooldown <= 0 and dist > 2.2 else "Z_Attack_Swipe_R"
					start = 30.0 if next_clip == "Z_Spit" else 3.0
				elif kind == 5:
					next_clip = "Z_Attack_Leap" if leap_cooldown <= 0 and dist > 4.5 else ("Z_Attack_Overhead_Smash" if attack_serial % 3 != 2 else "Z_Attack_Swipe_R")
					start = 10.0 if next_clip == "Z_Attack_Leap" else 2.9
				var timing: Array = Motion.attack_timing(next_clip)
				# Slancio: da due passi si butta in avanti e arriva fin dove eri. Chi si sposta di lato lo vede passare.
				var lunge := -1.0
				if kind in [0, 3] and not crawling and pounce_cooldown <= 0.0 and dist > 1.9 and dist < 2.9:
					lunge = (dist - 1.1) / maxf(float(timing[1]) * 0.325, 0.05)
				if dist < start + 1.0 and not _may_attack():
					_waiting = true
				elif dist < start and (next_clip == "Z_Spit" or kind == 5 or _reachable(next_clip, lunge)) and clear_line(target):
					if kind < 4:
						anim_scale = 1.0
						combo_left = 1 if kind in [0, 3] and not crawling and (network_id + attack_serial) % 3 == 0 else 0
					if lunge >= 0.0: pounce_cooldown = randf_range(4.0, 7.0)
					_begin_attack(next_clip, lunge)
		elif patrol.size() > 0:
			# pattuglia in cerchio: punto dopo punto, senza fermarsi (zoppicando, vedi infected_motion)
			var goal := patrol[patrol_i % patrol.size()]
			if Vector2(global_position.x - goal.x, global_position.z - goal.z).length() < 1.2:
				patrol_i = (patrol_i + 1) % patrol.size()
				goal = patrol[patrol_i]
			if agent.target_position.distance_to(goal) > 0.5:
				agent.target_position = goal
		else:
			wander_timer -= delta
			if wander_timer <= 0:
				wander_timer = randf_range(3,6)
				agent.target_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map,home+Vector3(randf_range(-5,5),0,randf_range(-5,5)))
		if crawling:speed=0.45
		elif has_method("move_factor"): speed *= call("move_factor")   # zoppia (lesioni, pacchetto B)
		var direction := Vector3.ZERO
		if NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map)>0 and not agent.is_navigation_finished() and (state != State.CHASE or agent.is_target_reachable()):
			direction = agent.get_next_path_position()-global_position
			direction.y = 0
			direction = direction.normalized()
		# Fuori dalle zone con la mappa di navigazione (o senza strada calcolata) si va dritti verso il giocatore.
		var chasing: bool = state == State.CHASE and is_instance_valid(target)
		if chasing:
			var straight: Vector3 = (target.global_position - global_position) * Vector3(1, 0, 1)
			# Se la strada dritta è libera (ginocchia e petto) si va dritti: niente giri lunghi della navigazione.
			_open_clock -= delta
			if _open_clock <= 0.0:
				_open_clock = 0.3
				_open_way = straight.length() < 30.0 and _hit_at(global_position + Vector3.UP * 0.4, target.global_position + Vector3.UP * 0.4).is_empty() and _hit_at(global_position + Vector3.UP * 1.2, target.global_position + Vector3.UP * 1.2).is_empty()
				if _open_way: _detour_side = 0.0
			if _open_way:
				# verso il suo punto di accerchiamento, non tutti sulla stessa linea
				var flank: Vector3 = (agent.target_position - global_position) * Vector3(1, 0, 1)
				if flank.length() > 0.5: direction = flank.normalized()
				elif straight.length() > 0.8: direction = straight.normalized()
			elif direction == Vector3.ZERO:
				# senza strada calcolata: dritti verso dove crede che tu sia (vista, rumore o ricerca), non dove sei davvero
				var guess: Vector3 = (agent.target_position - global_position) * Vector3(1, 0, 1)
				if guess.length() > 0.8: direction = guess.normalized()
		if direction != Vector3.ZERO: direction = _steer(direction, delta, chasing)
		var separation := Vector3.ZERO
		if world:
			for other in world.targets:
				if not is_instance_valid(other) or other==self or other.dead: continue
				var away: Vector3 = global_position-other.global_position
				away.y = 0
				var distance := away.length()
				if distance>0.02 and distance<1.05: separation += away.normalized()*(1.05-distance)*2.0
				# Uno davanti sulla stessa strada: si scosta di lato invece di accodarsi.
				elif chasing and direction != Vector3.ZERO and distance < 2.6 and direction.dot(-away / distance) > 0.8:
					var lateral := direction.cross(Vector3.UP) * (1.0 if direction.cross(Vector3.UP).dot(away) >= 0.0 else -1.0)
					separation += lateral * (2.6 - distance) * 0.45
		if kind == 4 and state == State.CHASE and is_instance_valid(target) and not crawling:
			# lo sputatore tiene la distanza: indietreggia se gli sei addosso, resta fermo se ti vede
			var gap := global_position.distance_to(target.global_position)
			if gap < 5.5 and spit_cooldown > 0.3:
				direction = (global_position - target.global_position) * Vector3(1, 0, 1)
				direction = direction.normalized()
				speed = 0.9
			elif gap < 30.0 and clear_line(target):
				direction = Vector3.ZERO
		var facing := direction
		if _waiting and is_instance_valid(target):
			# Aspetta il turno girandoti attorno a due passi, sempre dallo stesso lato e con gli occhi su di te.
			var from: Vector3 = (global_position - target.global_position) * Vector3(1, 0, 1)
			var gap := maxf(from.length(), 0.01)
			var around: Vector3 = (from / gap).cross(Vector3.UP) * (1.0 if network_id % 2 == 0 else -1.0)
			direction = (around + from / gap * clampf(2.1 - gap, -1.0, 1.0)).normalized()
			facing = -from
			speed *= 0.7
		velocity.x = direction.x*speed+separation.x
		velocity.z = direction.z*speed+separation.z
		if facing.length_squared()>0.01: rotation.y = lerp_angle(rotation.y,atan2(-facing.x,-facing.z),delta*5)
	if _climb_top > -INF:
		# Sta scavalcando: sale fino a superare l'ostacolo, poi avanza e ricade dall'altra parte.
		_climb_left -= delta
		if global_position.y < _climb_top and _climb_left > 0.0:
			velocity.y = 3.4
			velocity.x = _climb_dir.x * maxf(0.7, Vector2(velocity.x, velocity.z).length() * 0.4)
			velocity.z = _climb_dir.z * maxf(0.7, Vector2(velocity.x, velocity.z).length() * 0.4)
			floor_snap_length = 0.0
		else:
			_climb_top = -INF
			floor_snap_length = 0.5
			velocity.x += _climb_dir.x * 1.2
			velocity.z += _climb_dir.z * 1.2
			velocity.y = 0.0
	else:
		velocity.y = 0 if is_on_floor() else velocity.y-22*delta
	move_and_slide()
	_audio_steps(delta)

func _begin_attack(clip: String, lunge: float = -1.0) -> void:
	var timing: Array = Motion.attack_timing(clip)
	var strike: Array = STRIKES.get(clip, [["hand_l", "hand_r", "head"], float(timing[1]) - 0.1, float(timing[1]) + 0.12, float(timing[1]), 0.9])
	attack_serial += 1
	attack_clip = clip
	attack_parts = strike[0]
	attack_from = float(strike[1]) * anim_scale
	attack_until = float(strike[2]) * anim_scale
	attack_hit = float(strike[3]) * anim_scale
	attack_len = maxf(float(timing[0]), float(strike[2]) + 0.45) * anim_scale
	attack_gap = float(strike[4])
	attack_reach = timing[2] * (1.7 if kind == 5 else 1.0)
	attack_lunge = lunge if lunge >= 0.0 else maxf(float(timing[3]), STEP_MAX[kind]) * (1.6 if kind == 5 else 1.0)
	if clip == "Z_Attack_Leap" and lunge < 0.0: attack_lunge = float(timing[3])
	state = State.ATTACK
	attack_clock = 0
	attack_done = false
	whiffed = false
	_sweep_prev.clear()
	_sweep_best = INF
	_sweep_wall = false
	if is_instance_valid(target):
		target.set_meta("zx_attacked_at", Time.get_ticks_msec())
		var rel: Vector3 = (target.velocity - velocity) * Vector3(1, 0, 1)
		last_attack = {"clip": clip, "dist": global_position.distance_to(target.global_position), "speed": rel.length(),
			"windup": attack_hit, "window": [attack_from, attack_until], "yaw": rotation.y, "from": global_position, "result": ""}
	_voice("attack")


## Il lato rotto non colpisce (lesioni, pacchetto B): con la mano destra inutilizzabile niente manate, testata al loro posto.
func _usable(clip: String) -> String:
	if not has_method("can_strike") or not STRIKES.has(clip): return clip
	for part in STRIKES[clip][0]:
		if part.begins_with("hand") and not call("can_strike", part.substr(5)):
			return "Z_Attack_Headbutt" if clip != "Z_Attack_Headbutt" else clip
	return clip


## Il colpo ti arriva? Conta dove sarai al contatto (previsione breve) e quanto può avanzare caricando.
## Se ti allontani più in fretta di quanto lui avanzi non parte: niente colpi tirati all'aria mentre arretri.
func _reachable(clip: String, lunge: float) -> bool:
	var timing: Array = Motion.attack_timing(clip)
	var strike: Array = STRIKES.get(clip, [[], 0.0, 0.0, float(timing[1]), 0.9])
	var contact: float = float(strike[3]) * anim_scale
	var step_speed: float = lunge if lunge >= 0.0 else (float(timing[3]) if clip == "Z_Attack_Leap" else maxf(float(timing[3]), STEP_MAX[kind]))
	# Avanza solo dal 20% della carica al colpo deciso (poi resta lo slancio): tanto può accorciare.
	var step: float = step_speed * maxf(contact * 0.8 - COMMIT * anim_scale, 0.0) + 0.1
	# Più in alto o più in basso di quanto arrivano le braccia (rialzo, scala, buca): niente colpo all'aria.
	if absf(target.global_position.y - global_position.y) > 0.9 * visual.scale.y: return false
	var flat: Vector3 = (target.global_position - global_position) * Vector3(1, 0, 1)
	var moving: Vector3 = target.velocity * Vector3(1, 0, 1)
	var ahead: float = (flat + (moving * minf(contact, LEAD_TIME)).limit_length(LEAD_MAX)).length()
	# Ti giri attorno o mi passi di fianco senza allontanarti: conta anche la distanza di adesso.
	var away: float = moving.dot(flat.normalized()) if flat.length() > 0.05 else 0.0
	var now: float = flat.length() if away < step_speed * 0.5 else INF
	return minf(ahead, now) - step <= float(strike[4]) + 0.15


## Carica: si gira verso dove sarai (giro limitato, quasi fermo dopo il colpo deciso) e ti viene incontro fino a portata.
func _track(delta: float) -> void:
	var aim := Vector3.ZERO
	if is_instance_valid(target) and not target.dead:
		var left: float = maxf(attack_hit - attack_clock, 0.0)
		var lead: Vector3 = (target.velocity * Vector3(1, 0, 1) * minf(left, LEAD_TIME)).limit_length(LEAD_MAX)
		aim = (target.global_position + lead - global_position) * Vector3(1, 0, 1)
	var committed: bool = attack_clock >= attack_hit - COMMIT * anim_scale
	if aim.length() > 0.05 and attack_clock < attack_until:
		var turn: float = (TURN_COMMIT if committed else TURN_AIM) * delta
		rotation.y += clampf(wrapf(atan2(-aim.x, -aim.z) - rotation.y, -PI, PI), -turn, turn)
	var push := 0.0
	if committed and not attack_done and attack_clock < attack_until:
		# Colpo deciso: niente più inseguimento della distanza, resta solo lo slancio che aveva (chi arretra al momento giusto lo evita).
		velocity.x = move_toward(velocity.x, 0, 3 * delta)
		velocity.z = move_toward(velocity.z, 0, 3 * delta)
		return
	if not committed and attack_clock > attack_hit * 0.2 and aim.length() > 0.6:
		push = clampf((aim.length() - attack_gap) / maxf(attack_hit - attack_clock, 0.08), 0.0, attack_lunge)
	if push > 0.0:
		velocity.x = -sin(rotation.y) * push
		velocity.z = -cos(rotation.y) * push
	else:
		velocity.x = move_toward(velocity.x, 0, 12 * delta)
		velocity.z = move_toward(velocity.z, 0, 12 * delta)


## Finestra attiva: ogni parte che colpisce (mano, testa) traccia il segmento fatto da un fotogramma di fisica all'altro,
## le mani anche l'avambraccio. Prende il primo giocatore la cui capsula vera (accucciato compreso) tocca quei segmenti,
## se tra il petto dello zombie e il punto toccato non c'è un muro. Niente sfere grandi attorno allo zombie.
func _sweep() -> CharacterBody3D:
	if avatar == null or avatar.skeleton == null: return null
	avatar._pose(0.0)       # posa al tempo esatto della fisica, anche quando il disegno va più lento
	var sk: Skeleton3D = avatar.skeleton
	var size: float = visual.scale.x
	var chest: Vector3 = global_position + Vector3.UP * 1.2 * visual.scale.y
	for part in attack_parts:
		var id: int = avatar.bone_ids.get(part, -1)
		if id < 0: continue
		var now: Vector3 = sk.global_transform * sk.get_bone_global_pose(id).origin
		var before: Vector3 = _sweep_prev.get(part, now)
		_sweep_prev[part] = now
		var elbow := now
		if part.begins_with("hand"):
			var e: int = avatar.bone_ids.get("lowerarm" + part.substr(4), -1)
			if e >= 0: elbow = sk.global_transform * sk.get_bone_global_pose(e).origin
		var r: float = (0.13 if part == "head" else 0.12) * size
		for victim in _victims():
			var axis: Array = _capsule(victim)
			var swing: PackedVector3Array = Geometry3D.get_closest_points_between_segments(before, now, axis[0], axis[1])
			var arm: PackedVector3Array = Geometry3D.get_closest_points_between_segments(elbow, now, axis[0], axis[1])
			var gap: float = minf(swing[0].distance_to(swing[1]) - r, arm[0].distance_to(arm[1]) - r * 0.8) - float(axis[2])
			if gap > 0.0:
				_sweep_best = minf(_sweep_best, gap)
				continue
			var touch: Vector3 = swing[1] if swing[0].distance_to(swing[1]) - r < arm[0].distance_to(arm[1]) - r * 0.8 else arm[1]
			if not _hit_at(chest, touch).is_empty():
				_sweep_wall = true
				continue
			_sweep_best = 0.0
			return victim
	return null


func _victims() -> Array:
	var out := []
	var all: Array = world.actors.values() if world and world.get("actors") is Dictionary and not world.actors.is_empty() else [target]
	for a in all:
		if is_instance_valid(a) and not a.dead and not (world and world.has_method("is_safe") and world.is_safe(a.position)): out.append(a)
	return out


## Asse e raggio della capsula vera di chi può essere colpito (accucciato si accorcia).
func _capsule(victim: Node3D) -> Array:
	var shape: CollisionShape3D = victim.get("body_collider")
	if shape == null:
		for child in victim.get_children():
			if child is CollisionShape3D and (child as CollisionShape3D).shape is CapsuleShape3D:
				shape = child
				break
	if shape == null or not (shape.shape is CapsuleShape3D):
		return [victim.global_position + Vector3.UP * 0.3, victim.global_position + Vector3.UP * 1.5, 0.32]
	var cap := shape.shape as CapsuleShape3D
	var half: float = maxf(cap.height * 0.5 - cap.radius, 0.0)
	var at: Transform3D = shape.global_transform
	return [at.origin - at.basis.y.normalized() * half, at.origin + at.basis.y.normalized() * half, cap.radius]


## Colpo a vuoto: il peso lo porta avanti e resta scoperto per un attimo (i colpi che prende valgono di più).
func _whiff() -> void:
	whiffed = true
	combo_left = 0
	attack_len += Motion.WHIFF_SECONDS
	velocity -= global_basis.z * 2.5


func _close_attack(result: String) -> void:
	if last_attack.is_empty(): return
	last_attack["result"] = result
	last_attack["turned"] = absf(wrapf(rotation.y - float(last_attack.yaw), -PI, PI))
	last_attack["moved"] = (global_position - (last_attack.from as Vector3)).length()
	last_attack["closest"] = _sweep_best
	if is_instance_valid(target): last_attack["end_dist"] = global_position.distance_to(target.global_position)


func _miss_reason() -> String:
	if _sweep_wall: return "muro"
	if not is_instance_valid(target) or target.dead: return "nessun bersaglio"
	var to: Vector3 = (target.global_position - global_position) * Vector3(1, 0, 1)
	if to.length() > 0.3 and (-global_basis.z).dot(to.normalized()) < 0.0: return "alle spalle"
	return "fuori portata"


func _may_attack() -> bool:
	if kind >= 4 or frenzy > 0.0 or not world: return true
	var busy := 0
	for other in world.targets:
		# Conta solo chi gli è davvero addosso (entro 4 m): uno lontano non tiene il posto agli altri.
		if is_instance_valid(other) and other != self and not other.dead and other.get("state") == State.ATTACK and other.get("target") == target \
				and other.global_position.distance_to(target.global_position) < 4.0: busy += 1
	if busy >= MAX_ATTACKERS: return false
	# Sfalsati: chi arriva subito dopo un altro aspetta un attimo, non colpiscono tutti insieme.
	var last: int = int(target.get_meta("zx_attacked_at", -100000)) if is_instance_valid(target) else -100000
	return busy == 0 or Time.get_ticks_msec() - last > int(STAGGER_START * 1000.0)


## Passo che cambia: rallenta e accelera a ondate, e ogni tanto uno scatto quando la preda è a pochi metri.
var _open_clock := 0.0
var _open_way := false
var _burst := 0.0
var _burst_wait := 0.0
func _surge(delta: float) -> float:
	if kind in [1, 4, 5] or crawling: return 1.0
	_burst = maxf(0.0, _burst - delta)
	_burst_wait -= delta
	var gap: float = global_position.distance_to(target.global_position) if is_instance_valid(target) else 99.0
	if _burst_wait <= 0.0 and gap > 2.5 and gap < 7.0:
		_burst_wait = randf_range(3.0, 6.0)
		_burst = randf_range(0.5, 0.9)
	var wave: float = 1.0 + 0.2 * sin(clock * (1.1 + float(network_id % 7) * 0.13) + float(network_id))
	return wave * (1.7 if _burst > 0.0 else 1.0)


## Come si arriva dal giocatore senza incastrarsi: cosa piccola davanti, ci si sale sopra; cosa grande, si gira attorno
## tenendosi sempre dallo stesso lato finché la via è libera. Se dopo tutto questo è ancora fermo, si sposta poco più avanti.
func _steer(wanted: Vector3, delta: float, chasing: bool) -> Vector3:
	_probe_clock -= delta
	if _probe_clock <= 0.0:
		_probe_clock = 0.12 + float(network_id % 5) * 0.012
		_look_ahead(wanted)
	if chasing: _watch_stuck(delta)
	if _climb_top > -INF: return _climb_dir
	if _recover_left > 0.0:
		_recover_left -= delta
		return _recover_dir
	if _detour_side != 0.0:
		return _heading
	return wanted


func _body_size() -> Array:
	# [raggio, massimo scavalcabile, altezza della testa]. Il raggio segue la capsula vera (0,32; boss 0,58) più un margine:
	# col bruto largo 0,75 le sonde vedevano muri dove passava e nel bosco girava a vuoto.
	if kind == 5: return [0.75, 1.0, 2.5]
	return [0.45, 1.0, 1.8] if kind == 2 else [0.4, 1.05, 1.55]


func _hit_at(from: Vector3, to: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray)


func _look_ahead(wanted: Vector3) -> void:
	var size: Array = _body_size()
	var radius: float = float(size[0])
	var reach: float = radius + 0.75
	var at := global_position
	var side_step := wanted.cross(Vector3.UP).normalized() * radius
	# Tre raggi larghi quanto il corpo. Mentre gira attorno guarda più lontano: smette solo se la via è davvero libera.
	var length: float = reach + (2.2 if _detour_side != 0.0 else 0.0)
	var knee := {}
	for offset in [Vector3.ZERO, side_step, -side_step]:
		var hit := _hit_at(at + Vector3.UP * 0.35 + offset, at + Vector3.UP * 0.35 + offset + wanted * length)
		if not hit.is_empty() and (hit.normal as Vector3).y <= 0.65:
			if knee.is_empty() or (hit.position as Vector3).distance_to(at) < (knee.position as Vector3).distance_to(at): knee = hit
	var far_from: float = at.distance_to(target.global_position) if is_instance_valid(target) else 0.0
	if _detour_side != 0.0:
		# Mano sul muro: si molla solo con la via libera e più vicini di quando si è cominciato a girare.
		_detour_time += 0.12
		if knee.is_empty() and (far_from < _detour_start - 0.4 or not is_instance_valid(target) or _detour_time > 30.0):
			_detour_side = 0.0
		else:
			_hand_on_wall(at, reach, radius)
		return
	if knee.is_empty(): return
	# Quanto è alto? Si guarda dall'alto poco oltre il punto toccato.
	if (knee.position as Vector3).distance_to(at) < reach + 0.4:
		var past: Vector3 = (knee.position as Vector3) + wanted * 0.3
		var over := _hit_at(past + Vector3.UP * (float(size[1]) + 1.2), Vector3(past.x, at.y - 0.3, past.z))
		if not over.is_empty():
			var tall: float = (over.position as Vector3).y - at.y
			var head_y: float = tall + float(size[2]) * 0.5
			var top_free := _hit_at(at + Vector3.UP * head_y, at + Vector3.UP * head_y + wanted * reach)
			var safe_side: bool = not (world and world.has_method("is_safe") and world.is_safe(past + wanted * 0.8))
			if tall > 0.2 and tall <= float(size[1]) and top_free.is_empty() and safe_side and is_on_floor():
				_climb_top = at.y + tall + 0.12
				_climb_left = 0.7
				_climb_dir = wanted
				_detour_side = 0.0
				return
	# Troppo grande: si gira attorno, dal lato già scelto o da quello più libero.
	var angles := [0.35, 0.8, 1.2, 1.6, 2.1, 2.6, 3.0]
	var best := 0.0
	var best_angle := 9.0
	for side in [1.0, -1.0]:
		for a in angles:
			if _free_way(at, wanted.rotated(Vector3.UP, float(side) * float(a)), reach + 1.2, radius):
				if float(a) < best_angle:
					best = float(side)
					best_angle = float(a)
				break
	_detour_side = best if best != 0.0 else 1.0
	_heading = wanted.rotated(Vector3.UP, _detour_side * (best_angle if best != 0.0 else 1.6))
	_detour_start = far_from
	_detour_time = 0.0


## Segue il contorno: prova prima verso il muro, poi via via più lontano. Funziona anche negli ostacoli a U.
func _hand_on_wall(at: Vector3, reach: float, radius: float) -> void:
	for a in [-1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0]:
		var way: Vector3 = _heading.rotated(Vector3.UP, _detour_side * float(a))
		if _free_way(at, way, reach + 0.3, radius * 0.9):
			_heading = way.normalized()
			return

func _free_way(at: Vector3, way: Vector3, length: float, radius: float) -> bool:
	var side_step := way.cross(Vector3.UP).normalized() * radius
	for offset in [Vector3.ZERO, side_step, -side_step]:
		if not _hit_at(at + Vector3.UP * 0.35 + offset, at + Vector3.UP * 0.35 + offset + way * length).is_empty(): return false
	return true


## Controllo finale: fermo troppo a lungo mentre ti insegue. Si sblocca un passo alla volta, sempre camminando:
## niente teletrasporti, quindi niente muri attraversati. Il conto riparte appena si muove.
func _watch_stuck(delta: float) -> void:
	_stuck_clock += delta
	if _stuck_clock < 0.5: return
	_stuck_clock = 0.0
	var moved: float = Vector2(global_position.x - _stuck_at.x, global_position.z - _stuck_at.z).length()
	_stuck_at = global_position
	# Fermo apposta: è già addosso (o in fila nella calca), oppure è lo sputatore che ti tiene sotto tiro.
	var gap: float = global_position.distance_to(target.global_position) if is_instance_valid(target) else 0.0
	if moved > 0.12 or gap < 3.0 or (kind == 4 and gap < 30.0 and clear_line(target)):
		_stuck_for = 0.0
		return
	_stuck_for += 0.5
	for step in RECOVER_STEPS:
		if is_equal_approx(_stuck_for, float(step[0])): _recover(str(step[1]))
	if _stuck_for >= 4.0: _stuck_for = 0.0


func _recover(step: String) -> void:
	recoveries[step] = int(recoveries.get(step, 0)) + 1
	var radius: float = float(_body_size()[0])
	match step:
		"ricalcolo":
			# Strada nuova da dove si trova adesso. La mano sul muro si molla solo se c'è una navigazione che guida:
			# senza, ripartire dritti riporta contro lo stesso muro (avanti e indietro nelle U).
			agent.target_position = last_seen
			if not agent.get_current_navigation_path().is_empty(): _detour_side = 0.0
			_probe_clock = 0.0
		"intermedio":
			# Il prossimo punto della navigazione che si raggiunge dritti (senza navigazione non c'è: si aspetta la deviazione).
			_recover_dir = _waypoint_dir(radius)
			_recover_left = 1.5 if _recover_dir != Vector3.ZERO else 0.0
		"deviazione":
			_detour_side = -_detour_side if _detour_side != 0.0 else 1.0
			_heading = -_heading if _heading != Vector3.ZERO else global_basis.x
		"arretramento":
			var back: Vector3 = global_basis.z
			if is_instance_valid(target): back = ((global_position - target.global_position) * Vector3(1, 0, 1)).normalized()
			_recover_dir = Vector3.ZERO
			for turn in [0.0, 0.6, -0.6, 1.2, -1.2]:
				if _free_way(global_position, back.rotated(Vector3.UP, turn), 1.2, radius * 0.9):
					_recover_dir = back.rotated(Vector3.UP, turn)
					break
			_recover_left = 1.4 if _recover_dir != Vector3.ZERO else 0.0
		"rinuncia":
			# i boss restano nell'arena, e chi è a pochi passi non molla: si ricomincia dal ricalcolo
			if brain or kind == 5 or not is_instance_valid(target) or global_position.distance_to(target.global_position) < 6.0: return
			# Un altro giocatore a vista e con la strada libera? Allora va da lui.
			if world and world.get("actors") is Dictionary:
				for a in world.actors.values():
					if is_instance_valid(a) and a != target and not a.dead and a.global_position.distance_to(global_position) < 30.0 and clear_line(a) and _hit_at(global_position + Vector3.UP * 0.4, a.global_position + Vector3.UP * 0.4).is_empty():
						target = a
						last_seen = a.global_position
						return
			# Nessuno raggiungibile: smette di inseguire e gira lì attorno per un po'.
			state = State.WANDER
			target = null
			memory = 0.0
			home = global_position
			_give_up_until = clock + 8.0


## Il primo punto della strada di navigazione oltre 1,5 m che si raggiunge dritti (ZERO se non c'è).
## Niente scelta "il punto più vicino al bersaglio": nelle trappole a U riporta dentro.
func _waypoint_dir(radius: float) -> Vector3:
	var at := global_position
	for point in agent.get_current_navigation_path():
		var way: Vector3 = (point - at) * Vector3(1, 0, 1)
		if way.length() > 1.5 and _free_way(at, way.normalized(), minf(way.length(), 4.0), radius):
			return way.normalized()
	return Vector3.ZERO


## Ogni attacco fa una cosa sua: la manata spinge, il morso fa sanguinare, lo schianto del bruto ti butta via e ti stordisce.
func _strike(victim: CharacterBody3D) -> bool:
	var damage: float = HIT_DAMAGE[kind] * (0.65 if crawling else 1.0)
	var away: Vector3 = (victim.global_position - global_position) * Vector3(1, 0, 1)
	away = away.normalized() if away.length_squared() > 0.001 else -global_basis.z
	var side: Vector3 = away.cross(Vector3.UP)
	var fx := {}
	match attack_clip:
		"Z_Attack_Swipe_R":
			fx = {"knock": away * 3.2 - side * 2.2, "shake": 0.25}
		"Z_Attack_Swipe_L":
			fx = {"knock": away * 3.2 + side * 2.2, "shake": 0.25}
		"Z_Attack_Headbutt":
			# La testata intontisce: vista che trema e un attimo di stordimento.
			fx = {"knock": away * 3.0, "stun": 0.35, "shake": 0.5}
			damage *= 1.1
		"Z_Attack_Leap":
			fx = {"knock": away * 6.5 + Vector3.UP * 1.5, "slow": 1.6, "shake": 0.45}
		"Z_Attack_Overhead_Smash":
			fx = {"knock": away * 8.5 + Vector3.UP * 3.0, "stun": 0.9, "shake": 0.85, "heavy": true}
		"Z_Tank_Swipe":
			fx = {"knock": away * 7.0 + side * 3.0, "shake": 0.6, "heavy": true}
		"Z_Tank_Punch":
			fx = {"knock": away * 5.5, "stun": 0.4, "shake": 0.45}
		"Z_Attack_Jab":
			fx = {"knock": away * 2.0, "shake": 0.2}
		"Z_Crawl_Attack":
			fx = {"slow": 2.4, "bleed": 3.0, "shake": 0.15}
		_:
			fx = {"knock": away * 2.5, "shake": 0.2}
	if kind == 4: fx["poison"] = 4.0
	if kind == 3: fx["fear"] = 3.0
	if world.has_method("hit_player"): return world.hit_player(victim, damage, fx, global_position)
	return victim.take_damage(damage, global_position)


## Colpo dei boss: onda d'urto. Il Macellaio apre ferite con la mannaia, il Carceriere spacca il pavimento.
func _boss_hit(victim: CharacterBody3D, center: Vector3) -> void:
	var away: Vector3 = (victim.global_position - center) * Vector3(1, 0, 1)
	away = away.normalized() if away.length_squared() > 0.001 else -global_basis.z
	var damage: float = {"Z_Attack_Overhead_Smash": 34.0, "Z_Boss_Drop_Arrival": 20.0}.get(attack_clip, 26.0)
	var fx := {"knock": away * 11.0 + Vector3.UP * 3.5, "stun": 0.8, "shake": 1.0, "heavy": true}
	if custom_skin != "":
		fx["bleed"] = 8.0
		damage *= 0.8
	if world.has_method("hit_player"): world.hit_player(victim, damage, fx, center)
	else: victim.take_damage(damage, center, "heavy")


## Polvere e sassi dove il colpo ha toccato terra.
func _shockwave(at: Vector3, radius: float) -> void:
	var dust := CPUParticles3D.new()
	world.add_child(dust)
	dust.global_position = at + Vector3.UP * 0.1
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = 34
	dust.lifetime = 0.8
	dust.direction = Vector3.UP
	dust.spread = 80.0
	dust.flatness = 0.75
	dust.initial_velocity_min = radius * 1.1
	dust.initial_velocity_max = radius * 2.0
	dust.damping_min = 5.0
	dust.damping_max = 7.0
	dust.gravity = Vector3(0, -3, 0)
	var puff := SphereMesh.new()
	puff.radius = 0.16
	puff.height = 0.32
	puff.radial_segments = 6
	puff.rings = 3
	dust.mesh = puff
	dust.color = Color("8a7d66")
	dust.emitting = true
	get_tree().create_timer(1.3).timeout.connect(dust.queue_free)


## L'urlatore grida: chi è vicino resta col fiato corto e gli altri infetti accorrono più veloci.
func _scream(victim: CharacterBody3D) -> void:
	if scream_cooldown > 0.0 or not world: return
	scream_cooldown = 12.0
	if world.has_method("hit_player"):
		for a in world.actors.values():
			if is_instance_valid(a) and not a.dead and a.global_position.distance_to(global_position) < 14.0:
				world.hit_player(a, 0.0, {"fear": 4.0, "shake": 0.4}, global_position)
	for other in world.targets:
		if is_instance_valid(other) and other != self and not other.dead and other.global_position.distance_to(global_position) < 22.0:
			other.frenzy = 6.0
			other.hear(victim, 40.0)


func _voice(action: String) -> void:
	if dead:
		return
	if kind == 5 and custom_skin != "":
		if action in ["alert", "attack"]:
			AudioManager.boss_voice(voice_id, action, global_position + Vector3.UP * 2.4, -3.0)
		return
	if kind == 5:
		AudioManager.start_boss("carceriere", "IL CARCERIERE")
		if action in ["alert", "attack"]:
			AudioManager.boss_voice("carceriere", action, global_position + Vector3.UP * 2.4, -3.0)
		else:
			AudioManager.zombie_voice(kind, action, global_position + Vector3.UP * 2.0, -6.0)
	else:
		AudioManager.zombie_voice(kind, action, global_position + Vector3.UP * 1.3, -4.0 if action == "attack" else -7.0)

func _audio_steps(delta: float) -> void:
	if dead or not is_on_floor():
		return
	if Vector2(velocity.x, velocity.z).length() < 0.18:
		return
	if world == null or not is_instance_valid(world.player) or world.player.dead:
		return
	if global_position.distance_to(world.player.global_position) > 21.0:
		return
	step_clock -= delta
	if step_clock > 0.0:
		return
	step_clock = randf_range(0.42, 0.62) if kind == 1 else (randf_range(0.95, 1.25) if kind == 5 else randf_range(0.56, 0.84))
	AudioManager.zombie_step(kind, global_position)
