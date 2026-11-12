# Nodo Player/MeleeController (Node3D). Figlio HitArea (Area3D + CollisionShape3D).
# Richiede il padre player.gd e la sua gerarchia Visual. I modelli sono indipendenti dal danno.
extends Node3D

signal attack_started(charged: bool)
signal impact(target: Node3D, charged: bool)
signal attack_rejected(reason: String)
signal charge_started
## Colpo di arma da fuoco, con il punto colpito: bossolo, vampa e scia li fa fp_arms.gd.
signal shot(at: Vector3)

const Balance = preload("res://autoload/balance.gd")
const Weapon = preload("res://weapons/melee/axe.tres")
const Arsenal = preload("res://weapons/zx_arsenal.gd")
const GunFx = preload("res://weapons/gun_fx.gd")
## Dove sono arrivati i colpi dell'ultimo sparo: uno per pallino.
var last_ends: Array = []
var _shot_done := false
@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var area: Area3D = $HitArea
var charging: bool = false
var charge_time: float = 0
var attacking: bool = false
var charged_attack: bool = false
var attack_time: float = 0
var hit_ids: Dictionary = {}
var stopping: bool = false
var swing_side: float = 1
# Fendente in corso: 0 schiacciata, 1 diagonale, 2 strisciata. Cicla a ogni colpo.
var attack_variant: int = -1
var active_windup: float = 0
var active_recovery: float = 0
# Durata del colpo attivo: dai fotogrammi di colpo della clip dell'arma (weapons/zx_arsenal.gd).
var active_seconds: float = Weapon.active_seconds
var replica: bool = false
var impact_timer: Timer

## Ascia e pala (braccia FpArms; la gamba del calcio è art/zx_fp/SM_FP_Melee.glb, tools/castle_kit/build_fp_bow.py): ogni colpo è una clip con
## [nome, primo fotogramma di colpo, ultimo, fine clip] a 30 fps. attack_time è il tempo della clip.
const TOOLS := ["axe", "runic_axe", "spartan_sword"]
# Colpi 1 e 2: finestre del colpo in fotogrammi.
const COMBO := [["Axe_Light1", 8, 11, 37], ["Axe_Light2", 12, 14, 31], ["Axe_Light3", 9, 13, 24]]
const HEAVY := ["Axe_HeavySwing", 0, 5, 23]      # 0,15 s di scatto, poi 0,6 s per strappare la lama
const TIRED := ["Axe_Tired", 9, 14, 34]
const KICK := ["Kick", 5, 9, 18]
const HEAVY_CHARGE := 0.8                        # anticipo del pesante (24 fotogrammi di Axe_HeavyWindup)
const COMBO_WINDOW := 0.45                       # dopo la fine di un colpo, il successivo continua la combo
const TIRED_STAMINA := 10.0                      # sotto il 10% il colpo è più lento del 30% e trascina l'ascia
const TIRED_SLOW := 0.7
const DAMAGE := {"light": 25.0, "heavy": 80.0, "kick": 5.0}
const HIT_STOP := {"light": 0.05, "heavy": 0.08, "kick": 0.04}
const KICK_RANGE := 1.0                          # zombie vivo nel mirino più vicino di così: calcio invece del fendente
const KICK_COST := 6.0                           # stamina; sotto KICK_MIN_STAMINA esce il fendente (anche stanco)
const KICK_MIN_STAMINA := 4.0
## Dal calcio al prossimo: lo zombie finisce la spinta (Z_React_Pushed, ~1,8 s) e torna ad attaccare prima.
## Intanto il clic da vicino è un fendente: niente zombie tenuto a calci per sempre.
const KICK_COOLDOWN := 3.0
## Reazione dello zombie per colpo (direzione del fendente rispetto a chi lo riceve).
const REACTION := {"Axe_Light1": "hit_right", "Axe_Light2": "hit_left", "Axe_Light3": "stagger", "Axe_Tired": "hit_left",
	"Axe_HeavySwing": "knockdown", "Kick": "pushed"}
## Arco (art/zx_fp/SM_FP_Bow.glb, tools/castle_kit/build_fp_bow.py): si tende tenendo premuto, si scocca al rilascio.
## Tensione piena in BOW_DRAW secondi: velocità e danno della freccia crescono con la tensione.
const Arrow = preload("res://weapons/arrow.gd")
const BOW_DRAW := 0.8
const BOW_MIN_DRAW := 0.22                       # rilascio troppo presto: l'arco torna giù senza scoccare
const BOW_FIRE := 36.0 / 60.0                    # durata di Bow_FIRE e Bow_RELOAD
const BOW_RELOAD := 70.0 / 60.0
var attack_clip := ""
var time_scale := 1.0         # 0.7 da stanco
var freeze_left := 0.0         # hit-stop: la clip resta ferma con la lama dentro lo zombie
var blocking := false
# Mira con il tasto destro: più precisa, più lenta, si stringe la vista.
var ads := false
var ads_forced := false
## Parata: block_forced la impone (prove), remote_block è quella che arriva dalla rete per chi non è il giocatore locale.
var block_forced := false
var remote_block := false
# Colpo prenotato mentre finisce il precedente: la combo non si perde per un clic un po' in anticipo.
var _queued := false
var _clock := 0.0
var _last_end := -10.0
var _last_dir := Vector3.ZERO
var _last_kick := -10.0


func tool_in_hand() -> bool:
	return player.equipped in TOOLS

## Con qualunque arma bianca si para; con le armi da fuoco il tasto destro serve a mirare.
func _melee_in_hand() -> bool:
	var id: String = player.equipped
	return id != "" and id != "bow" and not id.begins_with("item_") and not Arsenal.is_gun(id)

func _ready() -> void:
	impact_timer = Timer.new()
	impact_timer.one_shot = true
	impact_timer.ignore_time_scale = true
	impact_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(impact_timer)
	impact_timer.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		stopping = false)

func _physics_process(delta: float) -> void:
	global_position = player.global_position
	rotation.y = player.visual.rotation.y
	_clock += delta
	if player.dead or player.seated:
		cancel()
		return
	# Parata con il tasto destro (ascia e pala): l'ascia di traverso davanti al petto.
	var guard_wanted: bool = remote_block if not player.local_control else (block_forced or (player.controls_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)))
	blocking = guard_wanted and _melee_in_hand() and not attacking and not charging
	ads = ads_forced or (Arsenal.is_gun(player.equipped) and player.local_control and player.controls_enabled and player.reload_left <= 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	if not attacking:
		# Le armi automatiche sparano finché tieni premuto.
		if player.local_control and player.controls_enabled and Input.is_action_pressed("attack") and Arsenal.def(player.equipped).get("auto", false) and player.reload_left <= 0.0 and player.magazine > 0:
			charging = false
			if begin_charge(): release_attack()      # passa da charge/release: l'host riceve ogni colpo del client
		if _queued:
			_queued = false
			if begin_charge(): release_attack()
		if player.local_control and player.controls_enabled and Input.is_action_just_pressed("attack") and not blocking:
			begin_charge()
		if charging:
			charge_time = minf(charge_time + delta, maxf(Weapon.charge_seconds, HEAVY_CHARGE) * 1.5)
			if player.dodging:
				charging = false
			elif player.local_control and Input.is_action_just_released("attack"):
				release_attack()
	else:
		if player.local_control and player.controls_enabled and Input.is_action_just_pressed("attack") and attack_time >= active_windup + active_seconds * 0.5 and not attack_clip.begins_with("Bow"):
			_queued = true
		# Hit-stop: il tempo del colpo (e della clip) si ferma per qualche fotogramma.
		if freeze_left > 0.0:
			freeze_left = maxf(0.0, freeze_left - delta)
		else:
			attack_time += delta * time_scale
		if not replica and attack_time >= active_windup and attack_time <= active_windup + active_seconds:
			if attack_clip.begins_with("Bow"): pass
			elif attack_clip != "": _blade_strike()
			else: _aim_strike()
		if attack_time >= active_windup + active_seconds + active_recovery:
			attacking = false
			_last_end = _clock

func begin_charge() -> bool:
	if attacking or charging or player.dead or player.dodging or player.seated:
		return false
	# Oggetti in mano e mani vuote non colpiscono: gli oggetti si usano (survival_rules, tasto sinistro).
	if player.equipped == "" or player.equipped.begins_with("item_"):
		return false
	var gun := Arsenal.is_gun(player.equipped)
	var interrupt: bool = gun and player.reload_left > 0 and player.magazine > 0 and player.equipped in Arsenal.SHELL_RELOAD
	if player.reload_left > 0 and not interrupt:
		return false
	# Grilletto a vuoto (cilecca + ricarica) o pompa interrotta: lo decide subito perform_attack.
	# charge_started arriva all'host come "charge", così lo fa anche lì e nessuno resta in carica.
	if interrupt or (gun and player.magazine <= 0):
		charge_started.emit()
		perform_attack(false)
		return false
	if player.equipped == "bow":
		if player.arrows <= 0:
			attack_rejected.emit("Niente frecce: recuperale dai corpi o comprale da Big Earl.")
			return false
		charging = true
		charge_time = 0
		charge_started.emit()
		AudioManager.bow_draw()
		return true
	# Zombie vivo nel mirino a meno di 1 m: calcio frontale per riprendere la distanza giusta dell'ascia.
	# Si decide solo alla pressione: una carica iniziata finisce sempre in un fendente.
	# charge_started porta il clic all'host, che decide il calcio con i suoi zombie.
	if kick_ready():
		charge_started.emit()
		return perform_kick()
	# Con ascia e pala si attacca anche sfiniti: il colpo esce lento e pesante (Axe_Tired). Sparare non costa stamina.
	if not gun and player.stamina < Weapon.stamina_cost and not (tool_in_hand() and player.stamina > 0.0):
		attack_rejected.emit("Riprendi fiato.")
		return false
	charging = true
	charge_time = 0
	charge_started.emit()
	return true

func release_attack() -> bool:
	if not charging:
		return false
	charging = false
	if player.equipped == "bow":
		return _loose_arrow()
	var needed: float = HEAVY_CHARGE if tool_in_hand() else Weapon.charge_seconds
	return perform_attack(charge_time >= needed and not Arsenal.is_gun(player.equipped))

func perform_attack(charged: bool) -> bool:
	var tier: String = Arsenal.tier(player.equipped)
	var cost: float = 0 if tier=="gun" else (Weapon.charged_stamina_cost if charged else Weapon.stamina_cost)
	if tier=="light":cost*=0.5
	if tool_in_hand():
		cost = minf(cost, player.stamina)
		if cost <= 0.0 and player.stamina <= 0.0:
			attack_rejected.emit("Riprendi fiato.")
			return false
		return _start_tool(charged, cost)
	if player.reload_left>0 and tier=="gun" and player.magazine>0 and player.equipped in Arsenal.SHELL_RELOAD:
		player.reload_left=0      # pompa e leva: il grilletto interrompe la ricarica, il colpo parte al clic dopo
		return false
	if player.seated or player.reload_left>0:return false
	if tier=="gun" and player.magazine<=0:
		# A caricatore vuoto il grilletto fa cilecca e parte da solo la ricarica.
		if player.local_control: AudioManager.gun_empty()
		player.reload_weapon()
		return false
	if attacking or player.dead or player.dodging or player.stamina < cost:
		attack_rejected.emit("Stamina insufficiente.")
		return false
	if tier=="gun":player.magazine-=1
	player.stamina -= cost
	player.regen_delay = Balance.STAMINA_REGEN_DELAY
	charged_attack = charged
	attacking = true
	attack_time = 0
	attack_clip = ""
	time_scale = 1.0
	freeze_left = 0.0
	hit_ids.clear()
	_shot_done = false
	attack_variant = (attack_variant + 1) % 3
	# Carica, colpo e recupero seguono la clip: il danno parte quando la lama arriva davanti alla camera.
	var timing: Array = Arsenal.timing(player.equipped, charged, attack_variant)
	active_windup = timing[0]
	active_seconds = timing[1]
	active_recovery = timing[2]
	player.visual.rotation.y = player.rig.yaw
	rotation.y = player.rig.yaw
	swing_side = -swing_side
	attack_started.emit(charged)
	# Chi non è il giocatore locale si sente dal suo corpo (zx_avatar_driver).
	if tier == "gun" and player.local_control:
		AudioManager.weapon_fire(player.equipped)
	elif player.local_control:
		AudioManager.weapon_swing(player.equipped, charged, false)
	return true

func _start_tool(charged: bool, cost: float) -> bool:
	if attacking or player.dead or player.dodging or player.seated:
		return false
	var tired: bool = player.stamina < TIRED_STAMINA
	player.stamina -= cost
	player.regen_delay = Balance.STAMINA_REGEN_DELAY
	# Combo a tre colpi: orizzontale, rovescio, dall'alto. Se si aspetta troppo si riparte dal primo.
	attack_variant = (attack_variant + 1) % 3 if _clock - _last_end < COMBO_WINDOW and attack_variant >= 0 else 0
	var row: Array = HEAVY if charged else (TIRED if tired else COMBO[attack_variant])
	time_scale = TIRED_SLOW if tired and not charged else 1.0
	_begin_clip(row, charged)
	attack_started.emit(charged)
	AudioManager.weapon_swing(player.equipped, charged, attack_clip == "Kick")
	return true


func _loose_arrow() -> bool:
	if charge_time < BOW_MIN_DRAW or player.arrows <= 0 or player.dead or player.seated:
		return false
	var draw := clampf(charge_time / BOW_DRAW, 0.0, 1.0)
	player.arrows -= 1
	player.stamina = maxf(0.0, player.stamina - 3.0)
	player.regen_delay = Balance.STAMINA_REGEN_DELAY
	var origin: Vector3 = player.global_position + Vector3.UP * player.eye_height
	var look: Vector3 = Basis.from_euler(Vector3(player.rig.pitch, player.rig.yaw, 0)) * Vector3.FORWARD
	# Sui client online la freccia è solo da vedere: il danno lo fa quella dell'host.
	Arrow.fire(player, origin + look * 0.6, look, lerpf(22.0, 58.0, draw), 0.0 if replica else lerpf(20.0, 70.0, draw))
	AudioManager.bow_release()
	attack_clip = "Bow_FIRE"
	charged_attack = draw >= 1.0
	attacking = true
	attack_time = 0.0
	freeze_left = 0.0
	time_scale = 1.0
	hit_ids.clear()
	active_windup = 0.0
	active_seconds = 0.0
	active_recovery = BOW_FIRE + (BOW_RELOAD if player.arrows > 0 else 0.0)
	attack_started.emit(charged_attack)
	return true


func perform_kick() -> bool:
	if attacking or player.dead or player.dodging or player.seated or player.stamina < KICK_MIN_STAMINA:
		return false
	_last_kick = _clock
	player.stamina -= KICK_COST
	player.regen_delay = Balance.STAMINA_REGEN_DELAY
	time_scale = 1.0
	_begin_clip(KICK, false)
	attack_started.emit(false)
	AudioManager.weapon_swing("", false, true)
	return true


func _begin_clip(row: Array, charged: bool) -> void:
	attack_clip = row[0]
	charged_attack = charged
	attacking = true
	attack_time = 0.0
	freeze_left = 0.0
	hit_ids.clear()
	_last_dir = Vector3.ZERO
	active_windup = float(row[1]) / 30.0
	active_seconds = float(row[2] - row[1]) / 30.0
	active_recovery = float(row[3] - row[2]) / 30.0
	player.visual.rotation.y = player.rig.yaw
	rotation.y = player.rig.yaw
	swing_side = -swing_side


## Il prossimo clic sarà un calcio: ascia o pala in mano, fiato, calcio recuperato e uno zombie vivo a meno di
## KICK_RANGE. Se il mirino prende un bersaglio decide quello (un cadavere da decapitare, uno zombie più lontano:
## fendente); a mirino libero vale lo zombie vivo davanti. Pubblica: l'HUD può segnalarlo.
func kick_ready() -> bool:
	if not tool_in_hand() or player.stamina < KICK_MIN_STAMINA or _clock - _last_kick < KICK_COOLDOWN: return false
	var origin: Vector3 = player.global_position + Vector3.UP * player.eye_height
	var look: Vector3 = Basis.from_euler(Vector3(player.rig.pitch, player.rig.yaw, 0)) * Vector3.FORWARD
	var query := PhysicsRayQueryParameters3D.create(origin, origin + look * 2.65, 17, [player.get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("target"):
		var aimed: Node3D = hit.collider.get_meta("target")
		var gap: Vector3 = aimed.global_position - player.global_position
		return aimed.is_in_group("zombies") and not aimed.dead and Vector2(gap.x, gap.z).length() < KICK_RANGE
	var world: Node = _world_node()
	if world == null: return false
	var forward: Vector3 = Basis.from_euler(Vector3(0, player.rig.yaw, 0)) * Vector3.FORWARD
	for enemy in world.targets:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var off: Vector3 = enemy.global_position - player.global_position
		off.y = 0.0
		if off.length() < KICK_RANGE and forward.dot(off.normalized()) > 0.4: return true
	return false


## Colpo legato alla lama: nei fotogrammi di colpo un raggio dall'occhio passa per l'osso "blade" del viewmodel
## (e per i punti tra il fotogramma precedente e questo, così un fendente veloce non salta lo zombie).
func _blade_strike() -> void:
	if not hit_ids.is_empty(): return
	var origin: Vector3 = player.global_position + Vector3.UP * player.eye_height
	var look: Vector3 = Basis.from_euler(Vector3(player.rig.pitch, player.rig.yaw, 0)) * Vector3.FORWARD
	var kind: String = "kick" if attack_clip == "Kick" else ("heavy" if charged_attack else "light")
	var dir := look
	var reach: float = 1.5 if kind == "kick" else ({"spartan_sword": 2.3, "runic_axe": 2.8}.get(player.equipped, 2.65))
	if kind == "kick":
		# Il calcio prende il busto: a 14° il raggio passava sopra lo zombie che si sporge in avanti.
		dir = (look + Vector3.DOWN * 0.6).normalized()
	else:
		var vm: Node = player.rig.camera.get_node_or_null("Viewmodel/FpArms")
		if vm and vm.blade_ready():
			dir = (vm.blade_point() - origin).normalized()
			# La lama passa ancora sopra o dietro la testa (inizio del pesante): niente colpo alle spalle.
			if dir.dot(look) < 0.3:
				_last_dir = Vector3.ZERO
				return
	# Anche il mirino: chi ha di fronte a metà colpo lo prende, anche se la clip passa un po' di lato.
	var dirs: Array = [look, dir]
	if _last_dir != Vector3.ZERO:
		dirs = [look, _last_dir.slerp(dir, 0.33), _last_dir.slerp(dir, 0.66), dir]
	_last_dir = dir
	for d in dirs:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + (d as Vector3) * reach, 17, [player.get_rid()])
		query.collide_with_areas = true
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty() or not result.collider.has_meta("target"): continue
		var victim: Node = result.collider.get_meta("target")
		var zone: String = result.collider.get_meta("zone")
		# Reazione direzionale: il fendente da destra a sinistra spinge verso la sinistra di chi colpisce.
		var right: Vector3 = Basis.from_euler(Vector3(0, player.rig.yaw, 0)) * Vector3.RIGHT
		var away: Vector3 = Vector3(look.x, 0, look.z).normalized()
		var reaction: String = REACTION.get(attack_clip, "")
		if "pending_reaction" in victim:
			victim.pending_reaction = reaction
			victim.reaction_dir = -right if reaction == "hit_left" else (right if reaction == "hit_right" else away)
		var force: Vector3 = away * (3.0 if kind == "heavy" else 0.8)
		if victim.receive_hit(zone, DAMAGE[kind], force, "kick" if kind == "kick" else player.equipped, kind == "heavy"):
			hit_ids[victim.get_instance_id()] = true
			freeze_left = HIT_STOP[kind]
			impact.emit(victim, kind == "heavy")
			AudioManager.weapon_hit(player.equipped, zone, kind == "heavy")
			player.rig.add_shake(Balance.HEAVY_SHAKE if kind == "heavy" else Balance.LIGHT_SHAKE)
			return


func try_hit(body: Node3D) -> bool:
	if not attacking or attack_time < active_windup or attack_time > active_windup + active_seconds:
		return false
	if not is_instance_valid(body) or not body.has_method("receive_melee") or hit_ids.has(body.get_instance_id()):
		return false
	var offset := body.global_position - player.global_position
	offset.y = 0
	if offset.length() > Weapon.reach or (-global_basis.z).dot(offset.normalized()) < Balance.MELEE_CONE_DOT:
		return false
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP,
		body.global_position + Vector3.UP, 1)
	ray.exclude = [player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	var amount: float = Weapon.charged_damage if charged_attack else Weapon.damage
	var force: float = Weapon.charged_knockback if charged_attack else Weapon.knockback
	if not body.receive_melee(amount, offset.normalized() * force, charged_attack):
		return false
	hit_ids[body.get_instance_id()] = true
	impact.emit(body, charged_attack)
	AudioManager.weapon_hit(player.equipped, "torso", charged_attack)
	player.rig.add_shake(Balance.HEAVY_SHAKE if charged_attack else Balance.LIGHT_SHAKE)
	_hit_stop()
	return true

func charge_fraction() -> float:
	var needed: float = HEAVY_CHARGE if tool_in_hand() else (BOW_DRAW if player.equipped == "bow" else Weapon.charge_seconds)
	return clampf(charge_time / needed, 0, 1) if charging else 0.0

func pose() -> float:
	if charging:
		return -0.7 * charge_fraction()
	if not attacking:
		return 0
	if attack_time < active_windup:
		return -0.8 * (attack_time / active_windup)
	if attack_time < active_windup + active_seconds:
		return lerpf(-0.8, 1.4, (attack_time - active_windup) / active_seconds)
	return lerpf(1.4, 0, clampf((attack_time - active_windup - active_seconds) / active_recovery, 0, 1))

func cancel() -> void:
	charging = false
	attacking = false
	blocking = false
	freeze_left = 0.0
	charge_time = 0
	hit_ids.clear()

func _hit_stop() -> void:
	if stopping or Session.online:
		return
	stopping = true
	Engine.time_scale = Balance.HIT_STOP_SCALE
	impact_timer.start(Balance.HIT_STOP_SECONDS)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

## Il colpo vero di un'arma da fuoco: pallini, perforazione, fulmine, fuoco, esplosione o vento, secondo l'arma.
func _gun_shot() -> void:
	if _shot_done: return
	_shot_done = true
	var stats: Dictionary = Arsenal.gun(player.equipped)
	var origin: Vector3 = player.global_position + Vector3.UP * player.eye_height
	var look: Vector3 = Basis.from_euler(Vector3(player.rig.pitch, player.rig.yaw, 0)) * Vector3.FORWARD
	var moving: float = clampf(Vector2(player.velocity.x, player.velocity.z).length() / 4.0, 0.0, 1.0)
	var spread: float = float(stats.spread) * (0.3 if ads else 1.0) + (0.0 if ads else 0.012 * moving)
	var fx: String = str(stats.get("fx", ""))
	last_ends.clear()
	if fx == "blast":
		var radius: float = float(stats.radius)
		GunFx.grenade(player.get_parent(), origin + look * 0.8, look, func(at: Vector3) -> void: _explode(at, radius, float(stats.dmg), float(stats.force)))
		last_ends.append(origin + look * 3.0)
		shot.emit(last_ends[0])
		return
	if fx == "wind":
		_wind(origin, look, float(stats.reach), float(stats.force))
		last_ends.append(origin + look * float(stats.reach))
		shot.emit(last_ends[0])
		return
	for i in int(stats.get("pellets", 1)):
		var way: Vector3 = (look + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))).normalized()
		var skip: Array = [player.get_rid()]
		var end: Vector3 = origin + way * float(stats.reach)
		for through in int(stats.get("pierce", 1)):
			var query := PhysicsRayQueryParameters3D.create(origin, origin + way * float(stats.reach), 17, skip)
			query.collide_with_areas = true
			var result := get_world_3d().direct_space_state.intersect_ray(query)
			if result.is_empty(): break
			end = result.position
			var collider: Node = result.collider
			if not collider.has_meta("target"): break
			_gun_hit(collider.get_meta("target"), collider.get_meta("zone"), way, stats, fx, end)
			skip.append(result.rid)
		last_ends.append(end)
	shot.emit(last_ends[0])


func _gun_hit(victim: Node, zone: String, way: Vector3, stats: Dictionary, fx: String, at: Vector3) -> void:
	if not victim.receive_hit(zone, float(stats.dmg), way * float(stats.force), player.equipped, false): return
	hit_ids[victim.get_instance_id()] = true
	impact.emit(victim, false)
	AudioManager.weapon_hit(player.equipped, zone, false)
	player.rig.add_shake(0.35)
	match fx:
		"burn": _burn(victim)
		"bleed": _bleed(victim, zone)
		"chain": _chain(victim, at, int(stats.chain), float(stats.dmg))


func _world_node() -> Node:
	var found: Node = player.get_parent()
	while found and found.get("targets") == null: found = found.get_parent()
	return found


## Il razzo lascia il bersaglio in fiamme per qualche secondo.
func _burn(victim: Node) -> void:
	for i in 5:
		await get_tree().create_timer(0.6).timeout
		if not is_instance_valid(victim) or victim.get("dead") == true: return
		victim.receive_hit("torso", 9.0, Vector3.ZERO, player.equipped, false)
		GunFx.burn_puff(player.get_parent(), (victim as Node3D).global_position + Vector3.UP * 1.1)


## Chiodi e dardi restano nella ferita: poco danno a ogni battito, finché è vivo.
func _bleed(victim: Node, zone: String) -> void:
	for i in 3:
		await get_tree().create_timer(0.9).timeout
		if not is_instance_valid(victim) or victim.get("dead") == true: return
		victim.receive_hit(zone, 4.0, Vector3.ZERO, player.equipped, false)


## Il fulmine salta sugli infetti vicini, indebolendosi a ogni salto.
func _chain(first: Node, from: Vector3, jumps: int, damage: float) -> void:
	var world: Node = _world_node()
	if world == null: return
	var last: Vector3 = from
	var done: Array = [first]
	var hit: float = damage
	for jump in jumps:
		var best: Node3D = null
		var best_gap: float = 7.0
		for other in world.targets:
			if not is_instance_valid(other) or other.dead or other in done: continue
			var gap: float = (other as Node3D).global_position.distance_to(last)
			if gap < best_gap:
				best_gap = gap
				best = other
		if best == null: return
		hit *= 0.75
		var to: Vector3 = best.global_position + Vector3.UP * 1.1
		GunFx.arc(player.get_parent(), last, to)
		best.receive_hit("torso", hit, Vector3.ZERO, player.equipped, false)
		done.append(best)
		last = to


func _explode(at: Vector3, radius: float, damage: float, force: float) -> void:
	GunFx.explosion(player.get_parent(), at, radius)
	AudioManager.explosion(at)
	player.rig.add_shake(0.8)
	var world: Node = _world_node()
	if world == null: return
	for other in world.targets:
		if not is_instance_valid(other) or other.dead: continue
		var gap: Vector3 = (other as Node3D).global_position - at
		if gap.length() > radius: continue
		other.receive_hit("torso", damage * (1.0 - gap.length() / radius * 0.6), gap.normalized() * force, player.equipped, true)


## Il soffiatore non fa male: spinge via tutto quello che ha davanti.
func _wind(origin: Vector3, look: Vector3, reach: float, force: float) -> void:
	var world: Node = _world_node()
	if world == null: return
	for other in world.targets:
		if not is_instance_valid(other) or other.dead: continue
		var gap: Vector3 = (other as Node3D).global_position + Vector3.UP - origin
		if gap.length() > reach or gap.normalized().dot(look) < 0.82: continue
		var strength: float = force * (1.0 - gap.length() / reach * 0.6)
		if other.has_method("react"): other.react("pushed", gap.normalized() * strength)
		if "push_velocity" in other:
			other.push_velocity = Vector3(look.x, 0, look.z).normalized() * strength
			other.push_left = 0.22


func _aim_strike() -> void:
	if Arsenal.is_gun(player.equipped):
		_gun_shot()
		return
	if not hit_ids.is_empty():return
	var origin:Vector3=player.global_position+Vector3.UP*player.eye_height
	var direction:Vector3=Basis.from_euler(Vector3(player.rig.pitch,player.rig.yaw,0))*Vector3.FORWARD
	var tier:String=Arsenal.tier(player.equipped)
	# Dal fianco si spara più largo, soprattutto di corsa; mirando il colpo va dove guardi.
	if tier=="gun":
		var moving:float=clampf(Vector2(player.velocity.x,player.velocity.z).length()/4.0,0.0,1.0)
		var spread:float=0.002 if ads else 0.014+0.02*moving
		direction=(direction+Vector3(randf_range(-spread,spread),randf_range(-spread,spread),randf_range(-spread,spread))).normalized()
	var reach:float=55 if tier=="gun" else (1.8 if tier=="light" else 2.65)
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*reach,17,[player.get_rid()])
	query.collide_with_areas=true
	var result:=get_world_3d().direct_space_state.intersect_ray(query)
	if tier=="gun":shot.emit(result.position if not result.is_empty() else origin+direction*reach)
	if result.is_empty():return
	var collider:Node=result.collider
	if not collider.has_meta("target"):return
	var victim:Node=collider.get_meta("target")
	var zone:String=collider.get_meta("zone")
	var damage:float=30 if tier=="gun" else (22 if tier=="light" else (64 if charged_attack else 34))
	if tier=="gun":damage=float(Arsenal.def(player.equipped).get("damage",30.0)) if player.equipped!="pistol" else 30.0
	if victim.receive_hit(zone,damage,direction*(1.5 if charged_attack else 0.5),player.equipped,charged_attack):
		hit_ids[victim.get_instance_id()]=true;impact.emit(victim,charged_attack)
		AudioManager.weapon_hit(player.equipped,zone,charged_attack)
		player.rig.add_shake(0.35)
