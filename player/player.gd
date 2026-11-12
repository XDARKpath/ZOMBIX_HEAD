# Nodo: Player (CharacterBody3D), player/player.tscn.
# Figli: CollisionShape3D, Visual/RollPivot/LeftLeg e RightLeg,
# Visual/RollPivot/LeftArm e RightArm, CameraRig, WeaponHolder.
extends CharacterBody3D

signal vitals_changed(health: float, stamina: float)
signal damaged(amount: float)
signal died
signal fell_out
signal dodge_started
signal jumped

const Balance = preload("res://autoload/balance.gd")
@onready var rig: Node3D = $CameraRig
@onready var visual: Node3D = $Visual
@onready var roll_pivot: Node3D = $Visual/RollPivot
@onready var left_leg: Node3D = $Visual/RollPivot/LeftLeg
@onready var right_leg: Node3D = $Visual/RollPivot/RightLeg
@onready var left_arm: Node3D = $Visual/RollPivot/LeftArm
@onready var right_arm: Node3D = $Visual/RollPivot/RightArm
@onready var melee: Node3D = $MeleeController
var credits:int=0
# Inventario come in How to Fish: una fila di tasche (inventory_slots, se ne comprano altre), niente pannello a parte.
# Tutto quello che hai sta in una tasca: armi in owned, oggetti impilabili in items, la tasca di ognuno in hotbar.
# equipped è hotbar[slot]; slot -1 = mani vuote. Le teste stanno in items["item_testa"].
const HOTBAR_SIZE:=9
var items:Dictionary={}
var hotbar:Array[String]=["axe","","","","","","","",""]
var slot:int=0
var carried_heads:int:
	get:
		var total:=0
		for id in items:
			if ItemInfo.is_head(id):total+=int(items[id])
		return total
	set(v):
		var change:int=v-carried_heads
		if change>0:add_item("item_testa",change)
		elif change<0:take_heads(-change)
# Esche per evocare i custodi: lo sceriffo ne dà una ogni HEADS_PER_BAIT teste consegnate.
var baits:int=0
var heads_delivered:int=0
var baits_earned:int=0
var owned:Array[String]=["axe"]
var equipped:String="axe"
# Zaino a slot come in How to Fish: si parte con quattro posti e se ne comprano
# altri dall'armeria. Ogni arma occupa uno slot.
var inventory_slots:int=4
# Potenziamenti comprati nei negozi, come lo zaino: {zona: quanti}, al massimo UPGRADES_PER_ZONE per zona.
const UPGRADES_PER_ZONE:=2
const HEALTH_PER_UPGRADE:=15.0
const STAMINA_PER_UPGRADE:=15.0
var health_ups:Dictionary={}
var stamina_ups:Dictionary={}
var magazine:int=8
# Colpi rimasti nelle armi da fuoco che non si hanno in mano (ognuna ha il suo caricatore).
var mags:Dictionary={}
# Frecce dell'arco (comprese quella incoccata): si comprano da Big Earl e si recuperano dove sono piantate.
var arrows:int=0
var reload_left:float=0
# Durata della ricarica in corso (o della cartuccia in corso): serve alle animazioni e all'HUD.
var reload_total:float=1.6
var _reload_seen:float=0
var health: float = Balance.PLAYER_MAX_HEALTH
var stamina: float = Balance.PLAYER_MAX_STAMINA
var dead: bool = false
var sprinting: bool = false
var exhausted: bool = false
var dodging: bool = false
var dodge_elapsed: float = 0.0
var dodge_cooldown: float = 0.0
var regen_delay: float = 0.0
var dodge_direction: Vector3 = Vector3.FORWARD
var animation_clock: float = 0.0
var local_control: bool = true
var controls_enabled: bool = true
var network_move := Vector2.ZERO
var network_sprint: bool = false
var input_age: float = 0
var seated: bool = false
var crouching: bool = false
var network_crouch: bool = false
var eye_height: float = Balance.EYE_HEIGHT
var jump_lock: float = 0.0
var standing_shape: CapsuleShape3D
var status: Node
var knock_velocity := Vector3.ZERO
var knock_left: float = 0.0
@onready var body_collider: CollisionShape3D=$CollisionShape3D

func _ready() -> void:
	status=preload("res://player/status_effects.gd").new()
	status.name="Status"
	status.player=self
	add_child(status)
	body_collider.shape=body_collider.shape.duplicate()
	standing_shape=CapsuleShape3D.new()
	standing_shape.radius=0.31
	standing_shape.height=Balance.STANDING_HEIGHT-0.02
	visual.visible=true
	if local_control:
		call_deferred("_shadow_body")
	floor_snap_length = Balance.FLOOR_SNAP
	vitals_changed.emit(health, stamina)

func _physics_process(delta: float) -> void:
	if reload_left>_reload_seen:reload_total=reload_left   # vale anche sui client, dove reload_left arriva dall'host
	if reload_left>0:
		reload_left=maxf(0,reload_left-delta)
		if reload_left==0:
			var Arsenal=preload("res://weapons/zx_arsenal.gd")
			if equipped in Arsenal.SHELL_RELOAD:
				# Una cartuccia alla volta: si continua finché il tubo è pieno (sparare interrompe).
				magazine=mini(magazine+1,Arsenal.magazine(equipped))
				if magazine<Arsenal.magazine(equipped):reload_left=Arsenal.reload_seconds(equipped);reload_total=reload_left
			else:magazine=Arsenal.magazine(equipped)
	_reload_seen=reload_left
	if seated: return
	if dead:
		return
	input_age += delta
	jump_lock=maxf(0,jump_lock-delta)
	var wants_crouch: bool=Input.is_action_pressed("crouch") if local_control else network_crouch and input_age<=0.5
	if not controls_enabled:wants_crouch=crouching
	set_crouched(wants_crouch)
	var target_eye: float=Balance.CROUCH_EYE_HEIGHT if crouching else Balance.EYE_HEIGHT
	# Lower the eyes before entering a low opening; standing up can ease out.
	eye_height=target_eye if crouching else move_toward(eye_height,target_eye,delta*3.5)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if local_control else network_move
	if not controls_enabled or (not local_control and input_age > 0.5): input = Vector2.ZERO
	var direction: Vector3 = rig.movement_direction(input)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	regen_delay = maxf(0, regen_delay - delta)
	if exhausted and stamina >= Balance.EXHAUSTION_RECOVERY:
		exhausted = false
	if local_control and controls_enabled and Input.is_action_just_pressed("jump"):
		try_jump()
	sprinting = false
	if knock_left > 0.0:
		# Spinto da un colpo: per un attimo decide la spinta, non le gambe.
		knock_left -= delta
		velocity.x = knock_velocity.x
		velocity.z = knock_velocity.z
		knock_velocity *= exp(-delta * 5.0)
	elif dodging:
		dodge_elapsed += delta
		velocity.x = dodge_direction.x * Balance.DODGE_SPEED
		velocity.z = dodge_direction.z * Balance.DODGE_SPEED
		if dodge_elapsed >= Balance.DODGE_SECONDS:
			dodging = false
			dodge_cooldown = Balance.DODGE_COOLDOWN
			roll_pivot.rotation.x = 0
	else:
		var wants_sprint: bool = Input.is_action_pressed("sprint") if local_control else network_sprint
		sprinting = wants_sprint and input.y< -0.1 and not crouching and not exhausted and stamina > 0 and is_on_floor() and not melee.attacking and not melee.charging
		var speed: float = Balance.CROUCH_SPEED if crouching else (Balance.SPRINT_SPEED if sprinting else Balance.WALK_SPEED)
		if melee.attacking or melee.charging:
			speed *= attack_move_multiplier()
		speed *= status.speed_factor()
		var acceleration: float = Balance.ACCELERATION if input.length() > 0.1 else Balance.DECELERATION
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
		if sprinting:
			stamina = maxf(0, stamina - Balance.SPRINT_DRAIN * delta)
			regen_delay = Balance.STAMINA_REGEN_DELAY
			if stamina <= 0:
				exhausted = true
	if not dodging and not sprinting and regen_delay <= 0:
		stamina = minf(max_stamina(), stamina + Balance.STAMINA_REGEN * delta)
	if not is_on_floor():
		velocity.y -= Balance.GRAVITY * delta
	elif velocity.y<=0:
		velocity.y = 0
	move_and_slide()
	visual.rotation.y=rig.yaw
	_animate(delta)
	vitals_changed.emit(health, stamina)
	if global_position.y < Balance.FALL_RESET_Y:
		dead = true
		velocity = Vector3.ZERO
		rig.controls_enabled = false
		fell_out.emit()

## Spinta di un colpo o di un'esplosione. Chi è in scivolata non la sente.
func knock(push: Vector3) -> void:
	if dead or seated or dodging or push.length_squared() < 0.01: return
	knock_velocity = Vector3(push.x, 0, push.z)
	knock_left = clampf(push.length() * 0.035, 0.1, 0.4)
	if push.y > 0.1 and is_on_floor(): velocity.y = push.y

## Ferita che continua (veleno, sangue, radiazioni): non si para e non si schiva, e non fa sobbalzare.
func wound(amount: float) -> void:
	if dead or amount <= 0: return
	health = maxf(0, health - amount)
	vitals_changed.emit(health, stamina)
	if health <= 0:
		dead = true
		sprinting = false
		dodging = false
		velocity = Vector3.ZERO
		rig.controls_enabled = false
		AudioManager.player_death()
		died.emit()

func try_jump() -> bool:
	if seated: return false
	if dead or crouching or dodging or jump_lock>0 or velocity.y>0.1 or not is_on_floor() or stamina<Balance.JUMP_COST:return false
	velocity.y=Balance.JUMP_SPEED
	jump_lock=0.2
	stamina-=Balance.JUMP_COST
	regen_delay=Balance.STAMINA_REGEN_DELAY
	jumped.emit()
	return true

func can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=standing_shape
	query.transform=Transform3D(Basis.IDENTITY,global_position+Vector3.UP*Balance.STANDING_HEIGHT*0.5)
	query.collision_mask=collision_mask
	query.exclude=[get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func set_crouched(value: bool, force: bool=false) -> void:
	if crouching==value:return
	if not value and not force and not can_stand():return
	crouching=value
	var height: float=Balance.CROUCH_HEIGHT if value else Balance.STANDING_HEIGHT
	body_collider.shape.height=height
	body_collider.position.y=height*0.5

func try_dodge(direction: Vector3) -> bool:
	if melee.attacking or dead or dodging or dodge_cooldown > 0 or stamina < Balance.DODGE_COST or not is_on_floor():
		return false
	melee.cancel()
	dodge_direction = direction.normalized() if direction.length_squared() > 0.01 else -visual.global_basis.z
	dodge_direction.y = 0
	dodge_direction = dodge_direction.normalized()
	stamina = maxf(0, stamina - Balance.DODGE_COST)
	regen_delay = Balance.STAMINA_REGEN_DELAY
	dodging = true
	dodge_elapsed = 0
	dodge_started.emit()
	return true

func is_invulnerable() -> bool:
	return dodging and dodge_elapsed < Balance.DODGE_IFRAMES

func take_damage(amount: float) -> bool:
	if dead or is_invulnerable() or amount <= 0:
		return false
	# Parata con ascia o pala: il colpo si scarica sul manico e costa fiato.
	var guarded: bool = melee.blocking and stamina > 0.0
	if guarded:
		stamina = maxf(0.0, stamina - amount * 0.4)
		regen_delay = Balance.STAMINA_REGEN_DELAY
		amount *= 0.25
	var applied: float = minf(health, amount)
	health = maxf(0, health - amount)
	damaged.emit(applied)
	vitals_changed.emit(health, stamina)
	if health <= 0:
		dead = true
		sprinting = false
		dodging = false
		velocity = Vector3.ZERO
		rig.controls_enabled = false
		AudioManager.player_death()
		died.emit()
	elif guarded:
		AudioManager.play_sfx("weapon_hit_guard", -7.0, randf_range(0.92, 1.08))
	else:
		AudioManager.player_hurt()
	return true

func reset_at(point: Vector3) -> void:
	melee.cancel()
	global_position = point
	velocity = Vector3.ZERO
	if status: status.clear_all()
	knock_left = 0.0
	health = max_health()
	stamina = max_stamina()
	dead = false
	sprinting = false
	exhausted = false
	dodging = false
	dodge_elapsed = 0
	dodge_cooldown = 0
	regen_delay = 0
	jump_lock=0
	set_crouched(false,true)
	eye_height=Balance.EYE_HEIGHT
	roll_pivot.rotation = Vector3.ZERO
	roll_pivot.position.y = 0.9
	rig.controls_enabled = true
	rig.reset_follow()
	vitals_changed.emit(health, stamina)

func _animate(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	animation_clock += horizontal_speed * Balance.WALK_ANIMATION_SPEED * delta
	var weight: float = clampf(horizontal_speed / Balance.WALK_SPEED, 0, 1)
	var sprint_weight: float = clampf((horizontal_speed - Balance.WALK_SPEED) / maxf(0.1, Balance.SPRINT_SPEED - Balance.WALK_SPEED), 0, 1)
	var swing: float = sin(animation_clock) * Balance.LEG_SWING * weight
	# Passo più ampio in corsa e ginocchia che si raccolgono sul richiamo.
	var stride: float = lerpf(1.0, 1.55, sprint_weight)
	left_leg.rotation.x = swing * stride
	right_leg.rotation.x = -swing * stride
	left_arm.rotation.x = -swing * 0.62 - sprint_weight * 0.25
	right_arm.rotation.x = swing * 0.62 - sprint_weight * 0.25
	left_arm.rotation.z = -0.06 - sprint_weight * 0.10
	# Oscillazione del bacino e appoggio irregolare: non è un manichino.
	var sway: float = sin(animation_clock * 0.5) * 0.035 * weight
	var bounce: float = absf(sin(animation_clock)) * Balance.BODY_BOB * weight
	var idle_breath: float = sin(Time.get_ticks_msec() * 0.0016) * 0.006 * (1.0 - weight)
	roll_pivot.position.y = 0.9 + bounce + idle_breath-(0.28 if crouching else 0.0)
	roll_pivot.rotation.x = -TAU * clampf(dodge_elapsed / Balance.DODGE_SECONDS, 0, 1) if dodging else -sprint_weight * 0.13
	roll_pivot.rotation.z = sway * 0.5
	roll_pivot.rotation.y = sin(animation_clock) * 0.05 * weight
	if not is_on_floor():
		# Saltando le gambe si raccolgono e le braccia si aprono per l'equilibrio.
		var tuck: float = clampf(-velocity.y * 0.05, -0.5, 0.7)
		left_leg.rotation.x = -0.35 + tuck
		right_leg.rotation.x = -0.2 - tuck * 0.6
		left_arm.rotation.z = -0.35
		right_arm.rotation.z = 0.35
		left_arm.rotation.x = -0.4
		right_arm.rotation.x = -0.4
	else:
		left_arm.rotation.z = -0.06 - sprint_weight * 0.10
		right_arm.rotation.z = 0.06 + sprint_weight * 0.10

	# I colpi li anima l'avatar ZX con le clip dell'arma (zx_avatar_driver.gd), non le braccia del manichino.
	right_arm.rotation.z = 0.06 + sprint_weight * 0.10

## Quantità di un oggetto: entra nella barra alla prima copia, ne esce all'ultima.
func set_item_count(id:String,count:int) -> void:
	count=mini(count,ItemInfo.MAX_STACK if ItemInfo.stacks(id) else 1)
	if count>0:
		items[id]=count
		if not hotbar.has(id):hotbar_add(id)
	else:
		items.erase(id)
		hotbar_clear(id)
func add_item(id:String,count:int=1) -> void:
	set_item_count(id,int(items.get(id,0))+count)
func hotbar_add(id:String) -> void:
	if hotbar.has(id):return
	var free:=_open_pocket()
	if free>=0:hotbar[free]=id
## Tasca libera: quella in mano se è vuota, altrimenti la prima (-1 se sono tutte piene).
func _open_pocket() -> int:
	if slot>=0 and slot<inventory_slots and hotbar[slot]=="":return slot
	for n in range(inventory_slots):
		if hotbar[n]=="":return n
	return -1
## C'è posto per questa cosa? Un oggetto che hai già si impila nella sua tasca.
func can_take(id:String) -> bool:
	if items.has(id):return ItemInfo.stacks(id) and int(items[id])<ItemInfo.MAX_STACK
	if owned.has(id):return false
	return hotbar.has(id) or _open_pocket()>=0
## Toglie n teste a partire da quelle che valgono meno: {id: quante}. Le usa il sacco della morte.
func take_heads(n:int) -> Dictionary:
	var taken:={}
	var ids:Array=items.keys().filter(func(id): return ItemInfo.is_head(id))
	ids.sort_custom(func(a,b): return ItemInfo.head_price(a)<ItemInfo.head_price(b))
	for id in ids:
		while n>0 and items.has(id):
			taken[id]=int(taken.get(id,0))+1
			set_item_count(id,int(items[id])-1)
			n-=1
	return taken
## Toglie un id dalla sua tasca; se era in mano passa alla tasca piena più vicina (mani vuote se non c'è altro).
func hotbar_clear(id:String) -> void:
	var at:=hotbar.find(id)
	if at<0:
		if equipped==id:select_slot(slot)
		return
	hotbar[at]=""
	# Oggetti rimasti senza tasca (ricompense con le tasche piene): entrano appena se ne libera una.
	for other in items:
		if not hotbar.has(other):hotbar[at]=other;break
	if at==slot or equipped==id:
		for step in range(0,inventory_slots):
			for n in [at+step,at-step]:
				if n>=0 and n<inventory_slots and hotbar[n]!="":
					select_slot(n);return
		select_slot(-1)
func select_slot(n:int) -> void:
	slot=clampi(n,-1,inventory_slots-1)
	var next:String=hotbar[slot] if slot>=0 else ""
	if next!=equipped:
		# Cambiando arma il caricatore resta suo e una ricarica a metà si annulla.
		var Arsenal=preload("res://weapons/zx_arsenal.gd")
		if Arsenal.is_gun(equipped):mags[equipped]=magazine
		reload_left=0
		magazine=int(mags.get(next,Arsenal.magazine(next)))
	equipped=next
## Mette in mano un'arma o un oggetto: resta nella sua tasca se ce l'ha, altrimenti in una libera o in quella attuale.
func equip_id(id:String) -> void:
	if not hotbar.has(id):
		var free:=_open_pocket()
		hotbar[free if free>=0 else maxi(slot,0)]=id
	select_slot(hotbar.find(id))
## Toglie un pezzo di quello che si ha in mano o nello zaino (arma intera o una copia dell'oggetto).
func remove_one(id:String) -> void:
	if items.has(id):set_item_count(id,int(items[id])-1)
	elif owned.has(id):
		owned.erase(id);hotbar_clear(id)
func has_thing(id:String) -> bool:
	return items.has(id) or owned.has(id)
func reset_inventory() -> void:
	credits=0;carried_heads=0;baits=0;heads_delivered=0;baits_earned=0;owned=["axe"];items={};hotbar.assign(["axe","","","","","","","",""]);slot=0;equipped="axe";magazine=8;mags={};arrows=0;reload_left=0;inventory_slots=4;health_ups={};stamina_ups={}

func _ups(table:Dictionary) -> int:
	var n:=0
	for zone in table:n+=int(table[zone])
	return n
func max_health() -> float:
	return Balance.PLAYER_MAX_HEALTH+HEALTH_PER_UPGRADE*_ups(health_ups)
func max_stamina() -> float:
	return Balance.PLAYER_MAX_STAMINA+STAMINA_PER_UPGRADE*_ups(stamina_ups)

func free_slot() -> bool:
	return owned.size() < inventory_slots

## Quanto ci si muove mentre si colpisce: chi spara si sposta quasi normale, il coltello poco meno,
## l'arma pesante e la carica tengono il passo corto (Balance.ATTACK_MOVE_MULTIPLIER, 0,3) come prima.
func attack_move_multiplier() -> float:
	var kind: String = preload("res://weapons/zx_arsenal.gd").tier(equipped)
	if kind == "gun": return 0.7
	if kind == "light" and not melee.charging and equipped != "bow": return 0.6
	return Balance.ATTACK_MOVE_MULTIPLIER

func reload_weapon() -> bool:
	var Arsenal=preload("res://weapons/zx_arsenal.gd")
	if dead or seated or not Arsenal.is_gun(equipped) or magazine>=Arsenal.magazine(equipped) or reload_left>0 or melee.attacking:return false
	# Ogni arma ha la sua durata (zx_arsenal.RELOAD_SECONDS); le armi a cartucce una cartuccia alla volta.
	reload_left=Arsenal.reload_seconds(equipped)
	reload_total=reload_left
	AudioManager.weapon_reload(equipped)
	return true

func _shadow_body() -> void:
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
