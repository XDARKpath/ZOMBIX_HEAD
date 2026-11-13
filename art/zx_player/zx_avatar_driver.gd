extends RefCounted
# Avatar in terza persona (gli altri giocatori in partita): un solo ZXPlayer con il suo AnimationTree.
# Legge lo stato dell'attore e chiama l'API di zx_player.gd: passo e corsa, accucciato, combo e colpo
# pesante dell'arma (ZXWeapons), ricarica, salita/guida/discesa dal 4×4, riparazione, raccolta, morte.
# L'arma è il modello di art/env/weapons agganciato all'osso weapon_anchor da ZXPlayer.equip().

## Id del gioco -> id ZXWeapons. Le armi comprate nei negozi hanno già l'id ZXWeapons.
const MAP := {"axe": "fire_axe", "knife": "combat_knife", "pistol": "pistol", "": "unarmed"}
const WALK_SPEED := 4.0                  # Balance.WALK_SPEED: a questa velocità il personaggio fa la corsetta

var model: Node3D
var actor: Node3D
var weapon := "-"
var seat := -1
var repairing := ""
var was_attacking := false
var was_reloading := false
var was_dead := false
var gesture_until := 0
var gesture_seen := 0
var was_dodging := false
var was_blocking := false
var heavy_seen := 0
var hand_item: Node3D
var hand_id := ""
var stun_seen := false
var last_health := -1.0
var was_air := false
var last_local := Vector3.ZERO
var lean := Vector2.ZERO
## Il gesto che vedono gli altri, per ogni cosa che si può fare a mani piene o vuote.
const GESTURES := {"throw": "Player_Grenade_Throw", "pickup": "Player_Interact_Reach_Low", "wave": "Player_Emote_Wave", "dance": "Player_Emote_Dance"}
## Clip che muovono anche le gambe (ci si china davvero a raccogliere).
const WHOLE_BODY := ["pickup", "dance"]
const PICKUP_SECONDS := 3.4
## Cibo e bevande vanno alla bocca, il resto delle cure si fa sul braccio.
const DRINKS := ["Cibo", "Tanica"]

func setup(zx_player: Node3D, owner_actor: Node3D) -> void:
	model = zx_player
	actor = owner_actor

static func weapon_id(equipped: String) -> String:
	if ZXWeapons.DEFS.has(equipped): return equipped
	return MAP.get(equipped, "unarmed")

func tick(_delta: float) -> void:
	if not is_instance_valid(model) or not is_instance_valid(actor) or model.tree == null: return
	var now := Time.get_ticks_msec()
	# Morte e ritorno in vita.
	if actor.dead:
		if not was_dead: model.die(posmod(actor.get_instance_id(), 3) == 0)
		was_dead = true
		_upright()
		return
	if was_dead:
		was_dead = false
		model.revive()
	# Colpo ricevuto: la vita cala di colpo. Vale anche sui client, dove la vita arriva dall'host
	# (veleno e sangue tolgono poco per volta e non fanno sobbalzare).
	var hp: float = actor.health
	if last_health - hp > 2.0 and seat < 0: model.play_action("Player_Hit_Impact_Front")
	last_health = hp
	# Arma in mano.
	var wanted := weapon_id(str(actor.get("equipped")) if actor.get("equipped") != null else "")
	_hold_item(str(actor.get("equipped")) if actor.get("equipped") != null else "")
	if wanted != weapon:
		weapon = wanted
		model.equip(weapon)
		if actor.get("local_control") == true: actor.call_deferred("_shadow_body")
	# 4×4: salire, guidare con lo sterzo, fare il passeggero, scendere (le porte si aprono da ranger_visual).
	var now_seat: int = actor.get_meta("seat", -1) if actor.get("seated") == true else -1
	if now_seat != seat:
		if seat >= 0: model.exit_vehicle()
		if now_seat >= 0: model.enter_vehicle(now_seat)
		seat = now_seat
	if seat >= 0:
		if seat == 0: model.set_steer(actor.get_meta("steer", 0.0))
		_upright()
		return
	# Riparazione: chino sul motore davanti al cofano, in ginocchio alle ruote.
	var kind: String = actor.get_meta("repair_kind", "wheel") if int(actor.get_meta("repair_until", 0)) > now else ""
	if kind != repairing:
		repairing = kind
		model.set_repairing(kind)
	if repairing != "": return
	# Raccolta di un pezzo del 4×4.
	var gesture: int = actor.get_meta("gesture_until", 0)
	if gesture > now and gesture != gesture_until:
		gesture_until = gesture
		model.install_part()
	# Lancio con [Q]: il braccio va avanti quando parte l'oggetto (survival_rules.throw_gesture).
	var serial: int = actor.get_meta("gesture_serial", 0)
	if serial != gesture_seen:
		gesture_seen = serial
		_gesture(str(actor.get_meta("gesture_what", "")))
	# Colpo forte ricevuto: si vede che viene sbalzato.
	var heavy_until: int = actor.get_meta("hit_heavy_until", 0)
	if heavy_until > now and heavy_until != heavy_seen:
		heavy_seen = heavy_until
		model.play_action("Player_Hit_Impact_Back")
	# Schivata e parata.
	var dodging: bool = actor.get("dodging") == true
	if dodging and not was_dodging: model.dodge()
	was_dodging = dodging
	var melee_now = actor.get("melee")
	var blocking: bool = melee_now != null and melee_now.get("blocking") == true
	if blocking != was_blocking:
		was_blocking = blocking
		model.set_block(blocking)
	# Colpi: combo dell'arma, pesante col colpo caricato, fuoco per le armi da sparo.
	var melee = actor.get("melee")
	if melee != null and model.tool_rig:
		model.tool_rig.charge = melee.charge_fraction() if melee.charging else 0.0
		model.tool_rig.aim = melee.ads
	var attacking: bool = melee != null and melee.attacking
	if attacking and not was_attacking:
		var d: Dictionary = ZXWeapons.get_def(weapon)
		if melee.attack_clip == "Kick":
			model.kick()      # calcio: si vede la gamba, con qualunque arma in mano
		elif d.has("fire") or d.has("fire_auto"):
			model.fire()
			# Chi guarda vede lo sparo di quell'arma; il giocatore locale lo vede già in prima persona.
			if actor.get("local_control") != true and model.weapon:
				var way: Vector3 = model.weapon.global_basis * Vector3.FORWARD
				var mouth: Vector3 = model.weapon.get_muzzle_global() if model.weapon.has_method("get_muzzle_global") else model.weapon.global_position + way * 0.3
				preload("res://weapons/gun_fx.gd").fire(actor.get_parent(), weapon, mouth, [mouth + way * 35.0], way, model.weapon.global_basis.x)
				AudioManager.weapon_fire_at(str(actor.get("equipped")), mouth)
		else:
			if actor.get("local_control") != true: AudioManager.weapon_swing_at(str(actor.get("equipped")), actor.global_position + Vector3.UP)
			if melee.charged_attack and d.has("heavy"): model.heavy_attack()
			else: model.attack()
	was_attacking = attacking
	var reloading: bool = actor.get("reload_left") != null and actor.reload_left > 0
	if reloading and not was_reloading: model.reload()
	was_reloading = reloading
	_reload_view(reloading)
	# Gambe: blend space di zx_player (y 1 = cammina, 2 = corre), nello spazio dell'avatar che guarda +Z.
	model.set_crouched(actor.get("crouching") == true)
	var velocity: Vector3 = actor.velocity if actor.get("velocity") != null else Vector3.ZERO
	var local: Vector3 = model.global_basis.inverse() * Vector3(velocity.x, 0, velocity.z)
	var dir := Vector2(-local.x, local.z) / WALK_SPEED
	# In aria: gambe raccolte al posto del passo, e un piegamento quando tocca terra. Sui client lo dice l'host.
	var rig: Node = model.tool_rig
	var air: bool = actor.get_meta("airborne") if actor.has_meta("airborne") else not actor.is_on_floor()
	rig.air = move_toward(rig.air, 1.0 if air else 0.0, _delta * (9.0 if air else 6.0))
	if was_air and not air: rig.land()
	was_air = air
	dir *= 1.0 - rig.air
	model.set_move(dir, actor.get("sprinting") == true and dir.y > 0.5, Vector2(local.x, local.z).length())
	var pitch: float = actor.rig.pitch if actor.get("rig") != null else 0.0
	rig.look_pitch = lerpf(rig.look_pitch, clampf(pitch, -0.6, 0.6), minf(1.0, _delta * 8.0))
	# Il corpo si butta dove accelera: in avanti alla partenza, indietro alla frenata, di lato nei cambi di direzione.
	var accel: Vector3 = (local - last_local) / maxf(_delta, 0.001)
	last_local = local
	var want := Vector2(clampf(accel.z * 0.006, -0.12, 0.12), clampf(-accel.x * 0.006, -0.12, 0.12))
	lean = lean.lerp(want, 1.0 - exp(-_delta * 6.0))
	model.rotation.x = lean.x
	model.rotation.z = lean.y


func _upright() -> void:
	lean = Vector2.ZERO
	model.rotation.x = 0.0
	model.rotation.z = 0.0


func _gesture(what: String) -> void:
	var rig: Node = model.tool_rig
	if what == "give":
		rig.offer()
		return
	if what == "use":
		var held: String = str(actor.get("equipped"))
		if ItemInfo.is_item(held) and ItemInfo.ITEMS[held].model in DRINKS:
			what = "drink"
		else:
			rig.bandage()
			return
	var clip: String = "Player_Use_Drink" if what == "drink" else str(GESTURES.get(what, "Player_Interact_Reach_Low"))
	# La clip della raccolta dura 7 s ma dopo ~3,4 s il personaggio è già in piedi: si taglia lì.
	var seconds: float = PICKUP_SECONDS if what == "pickup" else model.clip_seconds(clip)
	rig.pause(seconds)
	if what == "pickup": model.play_whole(clip, PICKUP_SECONDS)
	elif what in WHOLE_BODY: model.play_whole(clip)
	else: model.play_action(clip)


## Quello che ha in mano e non è un'arma (una testa, le bende, la scatoletta): anche gli altri lo vedono.
func _hold_item(id: String) -> void:
	var wanted: String = id if ItemInfo.is_item(id) else ""
	if wanted == hand_id: return
	hand_id = wanted
	if is_instance_valid(hand_item): hand_item.queue_free()
	hand_item = null
	if wanted == "": return
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0] if not model.find_children("*", "Skeleton3D", true, false).is_empty() else null
	if skeleton == null: return
	var bone := skeleton.find_bone("hand_r")
	if bone < 0: return
	var thing := ItemInfo.model(wanted)
	if thing == null: return
	hand_item = BoneAttachment3D.new()
	(hand_item as BoneAttachment3D).bone_name = "hand_r"
	skeleton.add_child(hand_item)
	hand_item.add_child(thing)
	thing.position = Vector3(0, 0.09, 0.02)


## Ricarica di chi vedi: il gesto segue la sua frazione vera, i suoni meccanici arrivano dal suo corpo
## (il tuo li senti già dalla prima persona).
const Arsenal := preload("res://weapons/zx_arsenal.gd")
var reload_seen := -1.0

func _reload_view(reloading: bool) -> void:
	var total: float = maxf(float(actor.get("reload_total")) if actor.get("reload_total") != null else 1.6, 0.1)
	var r: float = clampf((total - actor.reload_left) / total, 0.0, 1.0) if reloading else -1.0
	var equipped := str(actor.get("equipped"))
	if r >= 0.0 and actor.get("local_control") != true:
		for step in Arsenal.reload_crossed(equipped, total, reload_seen if r >= reload_seen else 0.0, r):
			AudioManager.reload_step(equipped, step, actor.global_position + Vector3.UP * 1.2)
	reload_seen = r
	model.tool_rig.set_reload(r, total)
	model.tool_rig.loaded = actor.get("magazine") == null or int(actor.magazine) > 0
