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
const UNSTICK_AFTER := 5.0
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
	target = candidate
	last_seen = candidate.global_position
	memory = 6
	state = State.CHASE

## Fa partire subito un attacco "scriptato" (il Carceriere che atterra dalla gabbia: Z_Boss_Drop_Arrival).
func force_attack(clip: String) -> void:
	var timing: Array = Motion.attack_timing(clip)
	attack_serial += 1
	attack_clip = clip
	attack_len = timing[0] * anim_scale
	attack_hit = timing[1] * anim_scale
	attack_reach = timing[2]
	attack_lunge = 0.0
	attack_clock = 0
	attack_done = false
	state = State.ATTACK
	_voice("attack")

func receive_hit(zone:String,amount:float,force:Vector3,weapon:String,heavy:bool=false) -> bool:
	if replica:return false
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
		if see(nearest):
			if state == State.WANDER and kind != 2 and (network_id % 3 != 2 or kind == 5):
				alert_time = 1.3                      # Z_Scream before the chase
				_voice("alert")
				if kind == 3: _scream(nearest)
			target = nearest
			last_seen = target.global_position
			memory = 6
			if state != State.ATTACK: state = State.CHASE
		# Chi ti insegue non ti perde per un albero: ti segue a naso, non solo dove ti ha visto l'ultima volta.
		if state == State.CHASE and is_instance_valid(target) and memory > 0.0 and target.global_position.distance_to(global_position) < 25.0:
			last_seen = target.global_position
			memory = maxf(memory, 3.0)
		if state == State.CHASE:
			agent.target_position = last_seen
			# Da vicino ti accerchiano: ognuno prende il suo lato invece di mettersi in fila dietro al primo.
			if is_instance_valid(target) and kind < 4 and not crawling:
				var from_target: Vector3 = (global_position - last_seen) * Vector3(1, 0, 1)
				var gap := from_target.length()
				if gap > 1.8 and gap < 7.0:
					var side := (float(network_id % 5) - 2.0) * 0.45
					agent.target_position = last_seen + from_target.normalized().rotated(Vector3.UP, side) * 1.1
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
		# wind-up: keep facing the target and lunge in (leap for runners) until the hit frame
		if attack_clock < attack_hit and to_target.length() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(-to_target.x, -to_target.z), delta * 10)
			var push := attack_lunge * clampf((attack_clock / attack_hit - 0.35) / 0.65, 0.0, 1.0)
			if to_target.length() < 0.9: push = 0.0
			velocity.x = -sin(rotation.y) * push
			velocity.z = -cos(rotation.y) * push
		else:
			velocity.x = move_toward(velocity.x, 0, 12 * delta)
			velocity.z = move_toward(velocity.z, 0, 12 * delta)
		if attack_clock >= attack_hit and not attack_done:
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
			elif is_instance_valid(target) and not target.dead and global_position.distance_to(target.global_position)<attack_reach and clear_line(target):
				if not (world.has_method("is_safe") and world.is_safe(target.position)):
					# Colpo parato con ascia o pala: lo zombie viene respinto e resta scoperto.
					var parried: bool = target.get("melee") != null and target.melee.get("blocking") == true and not crawling
					_strike(target)
					if parried:
						var away := global_position - target.global_position
						react("blocked", Vector3(away.x, 0, away.z))
						state = State.CHASE
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
		if state == State.CHASE:
			speed = CHASE_SPEED[kind] * speed_mul * (1.4 if frenzy > 0.0 else 1.0)
			if not is_instance_valid(target) or target.dead or memory <= 0:
				state = State.WANDER
				target = null
			else:
				var dist := global_position.distance_to(target.global_position)
				var next_clip := Motion.pick_attack(kind, network_id, attack_serial + 1, crawling)
				var start: float = 3.0 if next_clip == "Z_Attack_Leap" else 1.5
				if kind == 4 and not crawling:
					next_clip = "Z_Spit" if spit_cooldown <= 0 and dist > 2.2 else "Z_Attack_Swipe_R"
					start = 30.0 if next_clip == "Z_Spit" else 1.5
				elif kind == 5:
					next_clip = "Z_Attack_Leap" if leap_cooldown <= 0 and dist > 4.5 else ("Z_Attack_Overhead_Smash" if attack_serial % 3 != 2 else "Z_Attack_Swipe_R")
					start = 10.0 if next_clip == "Z_Attack_Leap" else 2.9
				var timing: Array = Motion.attack_timing(next_clip)
				if dist < start and clear_line(target):
					attack_serial += 1
					attack_clip = next_clip
					attack_len = timing[0] * anim_scale
					attack_hit = timing[1] * anim_scale
					attack_reach = timing[2] * (1.7 if kind == 5 else 1.0)
					attack_lunge = timing[3] * (1.6 if kind == 5 else 1.0)
					state = State.ATTACK
					attack_clock = 0
					attack_done = false
					_voice("attack")
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
		var direction := Vector3.ZERO
		if NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map)>0 and not agent.is_navigation_finished() and (state != State.CHASE or agent.is_target_reachable()):
			direction = agent.get_next_path_position()-global_position
			direction.y = 0
			direction = direction.normalized()
		# Fuori dalle zone con la mappa di navigazione (o senza strada calcolata) si va dritti verso il giocatore.
		var chasing: bool = state == State.CHASE and is_instance_valid(target)
		if chasing and direction == Vector3.ZERO:
			var straight: Vector3 = (target.global_position - global_position) * Vector3(1, 0, 1)
			if straight.length() > 0.8: direction = straight.normalized()
		if direction != Vector3.ZERO: direction = _steer(direction, delta, chasing)
		var separation := Vector3.ZERO
		if world:
			for other in world.targets:
				if not is_instance_valid(other) or other==self or other.dead: continue
				var away: Vector3 = global_position-other.global_position
				away.y = 0
				var distance := away.length()
				if distance>0.02 and distance<1.05: separation += away.normalized()*(1.05-distance)*2.0
		if kind == 4 and state == State.CHASE and is_instance_valid(target) and not crawling:
			# lo sputatore tiene la distanza: indietreggia se gli sei addosso, resta fermo se ti vede
			var gap := global_position.distance_to(target.global_position)
			if gap < 5.5 and spit_cooldown > 0.3:
				direction = (global_position - target.global_position) * Vector3(1, 0, 1)
				direction = direction.normalized()
				speed = 0.9
			elif gap < 30.0 and clear_line(target):
				direction = Vector3.ZERO
		velocity.x = direction.x*speed+separation.x
		velocity.z = direction.z*speed+separation.z
		if direction.length_squared()>0.01: rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),delta*5)
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

## Come si arriva dal giocatore senza incastrarsi: cosa piccola davanti, ci si sale sopra; cosa grande, si gira attorno
## tenendosi sempre dallo stesso lato finché la via è libera. Se dopo tutto questo è ancora fermo, si sposta poco più avanti.
func _steer(wanted: Vector3, delta: float, chasing: bool) -> Vector3:
	_probe_clock -= delta
	if _probe_clock <= 0.0:
		_probe_clock = 0.12 + float(network_id % 5) * 0.012
		_look_ahead(wanted)
	if chasing: _watch_stuck(delta)
	if _climb_top > -INF: return _climb_dir
	if _detour_side != 0.0:
		return _heading
	return wanted


func _body_size() -> Array:
	# [raggio, massimo scavalcabile, altezza della testa]
	return [0.75, 1.0, 2.5] if kind == 2 or kind == 5 else [0.4, 1.05, 1.55]


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


## Controllo finale: fermo troppo a lungo mentre ti insegue. Prima cambia lato, poi si sposta di qualche metro verso di te.
func _watch_stuck(delta: float) -> void:
	_stuck_clock += delta
	if _stuck_clock < 0.5: return
	_stuck_clock = 0.0
	var moved: float = Vector2(global_position.x - _stuck_at.x, global_position.z - _stuck_at.z).length()
	_stuck_at = global_position
	if moved > 0.12:
		_stuck_for = 0.0
		return
	_stuck_for += 0.5
	if _stuck_for == 1.5 or _stuck_for == 3.0:
		_detour_side = -_detour_side if _detour_side != 0.0 else 1.0
		_heading = -_heading if _heading != Vector3.ZERO else global_basis.x
	if _stuck_for >= UNSTICK_AFTER:
		_stuck_for = 0.0
		_unstick()


func _unstick() -> void:
	if not is_instance_valid(target): return
	var to_target: Vector3 = (target.global_position - global_position) * Vector3(1, 0, 1)
	if to_target.length() < 1.5: return
	var ahead := to_target.normalized()
	var size: Array = _body_size()
	var shape := SphereShape3D.new()
	shape.radius = float(size[0])
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var longest: float = minf(9.0, to_target.length())
	var dist := 2.0
	while dist <= longest:
		for turn in [0.0, 0.6, -0.6, 1.2, -1.2]:
			var spot: Vector3 = global_position + ahead.rotated(Vector3.UP, turn) * dist
			var floor_hit := _hit_at(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 3.0)
			if floor_hit.is_empty(): continue
			var stand: Vector3 = floor_hit.position
			if absf(stand.y - global_position.y) > 2.0: continue
			if world and world.has_method("is_safe") and world.is_safe(stand): continue
			query.transform = Transform3D(Basis.IDENTITY, stand + Vector3.UP * (float(size[0]) + 0.15))
			if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): continue
			# Mai attraverso un muro verso una stanza chiusa: da lì deve vedere il giocatore o esserci strada.
			if not _hit_at(stand + Vector3.UP * 1.2, target.global_position + Vector3.UP).is_empty() and _hit_at(global_position + Vector3.UP * 1.2, stand + Vector3.UP * 1.2).size() > 0 and global_position.distance_to(stand) > 3.0: continue
			global_position = stand + Vector3.UP * 0.05
			_detour_side = 0.0
			return
		dist += 1.0


## Ogni attacco fa una cosa sua: la manata spinge, il morso fa sanguinare, lo schianto del bruto ti butta via e ti stordisce.
func _strike(victim: CharacterBody3D) -> void:
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
	if world.has_method("hit_player"): world.hit_player(victim, damage, fx, global_position)
	else: victim.take_damage(damage)


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
	else: victim.take_damage(damage)


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
