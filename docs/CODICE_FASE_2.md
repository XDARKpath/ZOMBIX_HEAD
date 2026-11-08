# Codice completo — Fase 2

## player/player.gd

```gdscript
# Nodo: Player (CharacterBody3D), player/player.tscn.
# Figli: CollisionShape3D, Visual/RollPivot/LeftLeg e RightLeg,
# Visual/RollPivot/LeftArm e RightArm, CameraRig, WeaponHolder.
extends CharacterBody3D

signal vitals_changed(health: float, stamina: float)
signal damaged(amount: float)
signal died
signal fell_out
signal dodge_started

const Balance = preload("res://autoload/balance.gd")
@onready var rig: Node3D = $CameraRig
@onready var visual: Node3D = $Visual
@onready var roll_pivot: Node3D = $Visual/RollPivot
@onready var left_leg: Node3D = $Visual/RollPivot/LeftLeg
@onready var right_leg: Node3D = $Visual/RollPivot/RightLeg
@onready var left_arm: Node3D = $Visual/RollPivot/LeftArm
@onready var right_arm: Node3D = $Visual/RollPivot/RightArm
@onready var melee: Node3D = $MeleeController
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

func _ready() -> void:
	floor_snap_length = Balance.FLOOR_SNAP
	vitals_changed.emit(health, stamina)

func _physics_process(delta: float) -> void:
	if dead:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = rig.movement_direction(input)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	regen_delay = maxf(0, regen_delay - delta)
	if exhausted and stamina >= Balance.EXHAUSTION_RECOVERY:
		exhausted = false
	if Input.is_action_just_pressed("dodge"):
		try_dodge(direction)
	sprinting = false
	if dodging:
		dodge_elapsed += delta
		velocity.x = dodge_direction.x * Balance.DODGE_SPEED
		velocity.z = dodge_direction.z * Balance.DODGE_SPEED
		if dodge_elapsed >= Balance.DODGE_SECONDS:
			dodging = false
			dodge_cooldown = Balance.DODGE_COOLDOWN
			roll_pivot.rotation.x = 0
	else:
		sprinting = Input.is_action_pressed("sprint") and input.length() > 0.1 and not exhausted and stamina > 0 and is_on_floor() and not melee.attacking and not melee.charging
		var speed: float = Balance.SPRINT_SPEED if sprinting else Balance.WALK_SPEED
		if melee.attacking or melee.charging:
			speed *= Balance.ATTACK_MOVE_MULTIPLIER
		var acceleration: float = Balance.ACCELERATION if input.length() > 0.1 else Balance.DECELERATION
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
		if sprinting:
			stamina = maxf(0, stamina - Balance.SPRINT_DRAIN * delta)
			regen_delay = Balance.STAMINA_REGEN_DELAY
			if stamina <= 0:
				exhausted = true
	if not dodging and not sprinting and regen_delay <= 0:
		stamina = minf(Balance.PLAYER_MAX_STAMINA, stamina + Balance.STAMINA_REGEN * delta)
	if not is_on_floor():
		velocity.y -= Balance.GRAVITY * delta
	else:
		velocity.y = 0
	move_and_slide()
	var facing: Vector3 = dodge_direction if dodging else direction
	if facing.length_squared() > 0.01 and not melee.attacking and not melee.charging:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), minf(1, Balance.TURN_SPEED * delta))
	_animate(delta)
	vitals_changed.emit(health, stamina)
	if global_position.y < Balance.FALL_RESET_Y:
		dead = true
		velocity = Vector3.ZERO
		rig.controls_enabled = false
		fell_out.emit()

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
		died.emit()
	return true

func reset_at(point: Vector3) -> void:
	melee.cancel()
	global_position = point
	velocity = Vector3.ZERO
	health = Balance.PLAYER_MAX_HEALTH
	stamina = Balance.PLAYER_MAX_STAMINA
	dead = false
	sprinting = false
	exhausted = false
	dodging = false
	dodge_elapsed = 0
	dodge_cooldown = 0
	regen_delay = 0
	roll_pivot.rotation = Vector3.ZERO
	roll_pivot.position.y = 0.9
	rig.controls_enabled = true
	rig.reset_follow()
	vitals_changed.emit(health, stamina)

func _animate(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	animation_clock += horizontal_speed * Balance.WALK_ANIMATION_SPEED * delta
	var weight: float = clampf(horizontal_speed / Balance.WALK_SPEED, 0, 1)
	var swing: float = sin(animation_clock) * Balance.LEG_SWING * weight
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -swing * 0.7
	right_arm.rotation.x = swing * 0.7
	roll_pivot.position.y = 0.9 + absf(sin(animation_clock)) * Balance.BODY_BOB * weight
	roll_pivot.rotation.x = -TAU * clampf(dodge_elapsed / Balance.DODGE_SECONDS, 0, 1) if dodging else 0.0

	if melee.attacking or melee.charging:
		right_arm.rotation.x = -1.0 + melee.pose() * 1.5
		right_arm.rotation.z = -0.3 - melee.pose() * 0.4
	else:
		right_arm.rotation.z = 0

```

## player/camera_rig/camera_rig.gd

```gdscript
# Nodo: Player/CameraRig (Node3D top_level) nella scena player.tscn.
# Figli: SpringArm3D/Camera3D. Il padre è il CharacterBody3D da seguire.
extends Node3D

const Balance = preload("res://autoload/balance.gd")
@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var subject: CharacterBody3D = get_parent() as CharacterBody3D
var trauma: float = 0.0
var sensitivity: float = 1.0
var yaw: float = 0.0
var pitch: float = Balance.CAMERA_PITCH_DEFAULT
var controls_enabled: bool = true

func _ready() -> void:
	top_level = true
	arm.spring_length = Balance.CAMERA_LENGTH
	arm.add_excluded_object(subject.get_rid())
	reset_follow()

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * Balance.CAMERA_SENSITIVITY * sensitivity
		pitch = clampf(pitch - event.relative.y * Balance.CAMERA_SENSITIVITY * sensitivity,
			Balance.CAMERA_PITCH_MIN, Balance.CAMERA_PITCH_MAX)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arm.spring_length = maxf(Balance.CAMERA_MIN_LENGTH, arm.spring_length - Balance.CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arm.spring_length = minf(Balance.CAMERA_MAX_LENGTH, arm.spring_length + Balance.CAMERA_ZOOM_STEP)

func _physics_process(delta: float) -> void:
	if controls_enabled:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		yaw -= stick.x * Balance.CAMERA_PAD_SPEED * delta
		pitch = clampf(pitch - stick.y * Balance.CAMERA_PAD_SPEED * delta,
			Balance.CAMERA_PITCH_MIN, Balance.CAMERA_PITCH_MAX)
	global_position = global_position.lerp(subject.global_position + Vector3.UP * Balance.CAMERA_HEIGHT,
		1.0 - exp(-Balance.CAMERA_FOLLOW_SPEED * delta))
	rotation = Vector3(0, yaw, 0)
	arm.rotation.x = pitch
	trauma = move_toward(trauma, 0, delta * 2.5)
	camera.h_offset = randf_range(-1, 1) * trauma * 0.05
	camera.v_offset = randf_range(-1, 1) * trauma * 0.04
	camera.fov = lerpf(camera.fov, 73.0 if subject.sprinting else 68.0, delta * 5)

func add_shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func reset_follow() -> void:
	global_position = subject.global_position + Vector3.UP * Balance.CAMERA_HEIGHT
	rotation = Vector3(0, yaw, 0)
	arm.rotation.x = pitch

func movement_direction(input: Vector2) -> Vector3:
	# Si usa solo lo yaw: inclinare la camera non altera la velocità del personaggio.
	return Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)

```

## weapons/melee/weapon_data.gd

```gdscript
# Resource dati arma. Nessun nodo o figlio richiesto; usata da axe.tres.
extends Resource
class_name MeleeWeaponData

@export var display_name: String = "Accetta"
@export var damage: float = 26.0
@export var charged_damage: float = 58.0
@export var stamina_cost: float = 12.0
@export var charged_stamina_cost: float = 28.0
@export var charge_seconds: float = 0.65
@export var windup: float = 0.16
@export var active_seconds: float = 0.16
@export var recovery: float = 0.32
@export var charged_windup: float = 0.24
@export var charged_recovery: float = 0.46
@export var reach: float = 2.5
@export var knockback: float = 2.8
@export var charged_knockback: float = 5.0
@export var noise: float = 10.0
@export var price: int = 0
@export var tier: int = 1
@export var special_effect: String = ""

```

## weapons/melee/melee_controller.gd

```gdscript
# Nodo Player/MeleeController (Node3D). Figlio HitArea (Area3D + CollisionShape3D).
# Richiede il padre player.gd e la sua gerarchia Visual. I modelli sono indipendenti dal danno.
extends Node3D

signal attack_started(charged: bool)
signal impact(target: Node3D, charged: bool)
signal attack_rejected(reason: String)

const Balance = preload("res://autoload/balance.gd")
const Weapon = preload("res://weapons/melee/axe.tres")
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
var active_windup: float = 0
var active_recovery: float = 0

func _physics_process(delta: float) -> void:
	global_position = player.global_position
	rotation.y = player.visual.rotation.y
	if player.dead:
		cancel()
		return
	if not attacking:
		if Input.is_action_just_pressed("attack"):
			begin_charge()
		if charging:
			charge_time = minf(charge_time + delta, Weapon.charge_seconds * 1.5)
			if player.dodging:
				charging = false
			elif Input.is_action_just_released("attack"):
				release_attack()
	else:
		attack_time += delta
		if attack_time >= active_windup and attack_time <= active_windup + Weapon.active_seconds:
			for body in area.get_overlapping_bodies():
				try_hit(body)
		if attack_time >= active_windup + Weapon.active_seconds + active_recovery:
			attacking = false

func begin_charge() -> bool:
	if attacking or charging or player.dead or player.dodging:
		return false
	if player.stamina < Weapon.stamina_cost:
		attack_rejected.emit("Riprendi fiato.")
		return false
	charging = true
	charge_time = 0
	return true

func release_attack() -> bool:
	if not charging:
		return false
	charging = false
	return perform_attack(charge_time >= Weapon.charge_seconds)

func perform_attack(charged: bool) -> bool:
	var cost: float = Weapon.charged_stamina_cost if charged else Weapon.stamina_cost
	if attacking or player.dead or player.dodging or player.stamina < cost:
		attack_rejected.emit("Stamina insufficiente.")
		return false
	player.stamina -= cost
	player.regen_delay = Balance.STAMINA_REGEN_DELAY
	charged_attack = charged
	attacking = true
	attack_time = 0
	hit_ids.clear()
	active_windup = Weapon.charged_windup if charged else Weapon.windup
	active_recovery = Weapon.charged_recovery if charged else Weapon.recovery
	player.visual.rotation.y = player.rig.yaw
	rotation.y = player.rig.yaw
	swing_side = -swing_side
	attack_started.emit(charged)
	return true

func try_hit(body: Node3D) -> bool:
	if not attacking or attack_time < active_windup or attack_time > active_windup + Weapon.active_seconds:
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
	player.rig.add_shake(Balance.HEAVY_SHAKE if charged_attack else Balance.LIGHT_SHAKE)
	_hit_stop()
	return true

func charge_fraction() -> float:
	return clampf(charge_time / Weapon.charge_seconds, 0, 1) if charging else 0.0

func pose() -> float:
	if charging:
		return -0.7 * charge_fraction()
	if not attacking:
		return 0
	if attack_time < active_windup:
		return -0.8 * (attack_time / active_windup)
	if attack_time < active_windup + Weapon.active_seconds:
		return lerpf(-0.8, 1.4, (attack_time - active_windup) / Weapon.active_seconds)
	return lerpf(1.4, 0, clampf((attack_time - active_windup - Weapon.active_seconds) / active_recovery, 0, 1))

func cancel() -> void:
	charging = false
	attacking = false
	charge_time = 0
	hit_ids.clear()

func _hit_stop() -> void:
	if stopping:
		return
	stopping = true
	Engine.time_scale = Balance.HIT_STOP_SCALE
	await get_tree().create_timer(Balance.HIT_STOP_SECONDS, true, false, true).timeout
	Engine.time_scale = 1.0
	stopping = false

func _exit_tree() -> void:
	Engine.time_scale = 1.0

```

## enemies/zombie_target.gd

```gdscript
extends CharacterBody3D
signal defeated(target: Node3D)
const Balance = preload("res://autoload/balance.gd")
var health: float = Balance.TARGET_HEALTH
var dead: bool = false
var stagger: float = 0.0
var visual: Node3D
var bar: MeshInstance3D
var home: Vector3
var blood_enabled: bool = true
var clock: float = 0

func setup(variant: int) -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	var avatar := Node3D.new()
	avatar.set_script(preload("res://art/survivor_visual.gd"))
	visual.add_child(avatar)
	var names := ["SK_Chr_Zombie_Male_01", "SK_Chr_Zombie_Female_01", "SK_Chr_Zombie_Male_02"]
	avatar.configure(names[variant % 3], self, true)
	bar = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.65, 0.045)
	bar.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("b54a35")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar.material_override = mat
	bar.position.y = 2.15
	bar.visible = false
	add_child(bar)
	home = global_position

func receive_melee(amount: float, knockback: Vector3, heavy: bool) -> bool:
	if dead or amount <= 0: return false
	health = maxf(0, health - amount)
	velocity += knockback
	stagger = Balance.TARGET_HEAVY_STAGGER if heavy else Balance.TARGET_STAGGER
	bar.visible = true
	bar.scale.x = health / Balance.TARGET_HEALTH
	var tween := create_tween()
	visual.rotation.x = -0.25 if heavy else -0.12
	tween.tween_property(visual, "rotation:x", 0.0, stagger)
	if blood_enabled:
		var particles := CPUParticles3D.new()
		get_parent().add_child(particles)
		particles.global_position = global_position + Vector3.UP * 1.3
		particles.amount = 14 if heavy else 8
		particles.one_shot = true
		particles.explosiveness = 1
		particles.lifetime = 0.35
		particles.direction = Vector3.UP
		particles.spread = 100
		particles.initial_velocity_min = 1
		particles.initial_velocity_max = 2.5
		particles.gravity = Vector3(0,-8,0)
		var drop := SphereMesh.new()
		drop.radius = 0.018
		drop.height = 0.036
		particles.mesh = drop
		particles.color = Color("742d22")
		particles.emitting = true
		get_tree().create_timer(1).timeout.connect(particles.queue_free)
	if health <= 0:
		dead = true
		bar.hide()
		collision_layer = 0
		tween.kill()
		var fall := create_tween()
		fall.set_parallel(true)
		fall.tween_property(visual, "rotation:x", -PI / 2, Balance.TARGET_COLLAPSE_SECONDS)
		fall.tween_property(visual, "position:y", 0.18, Balance.TARGET_COLLAPSE_SECONDS)
		defeated.emit(self)
	return true

func _physics_process(delta: float) -> void:
	clock += delta
	stagger = maxf(0, stagger - delta)
	velocity.x = move_toward(velocity.x, 0, Balance.TARGET_FRICTION * delta)
	velocity.z = move_toward(velocity.z, 0, Balance.TARGET_FRICTION * delta)
	velocity.y = 0 if is_on_floor() else velocity.y - Balance.GRAVITY * delta
	move_and_slide()

```

## art/survivor_visual.gd

```gdscript
extends Node3D
# Original runtime posing over the recovered skeletal meshes.
var skeleton: Skeleton3D
var actor: Node3D
var zombie: bool = false
var clock: float = 0.0
var bone_ids: Dictionary = {}
var axe: Node3D

func configure(model_name: String, owner_actor: Node3D, is_zombie: bool = false) -> void:
	actor = owner_actor
	zombie = is_zombie
	var model: Node3D = load("res://art/surroundead/" + model_name + ".glb").instantiate()
	add_child(model)
	skeleton = _find_skeleton(model)
	if skeleton:
		for i in skeleton.get_bone_count():
			bone_ids[skeleton.get_bone_name(i).to_lower()] = i
	if not zombie:
		axe = load("res://art/surroundead/SM_Wep_FireAxe_01.glb").instantiate()
		add_child(axe)
		axe.scale = Vector3.ONE * 0.8
	_pose(0)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found: return found
	return null

func rotate_bone(bone_name: String, axis: Vector3, angle: float) -> void:
	transform_bone(bone_name, Basis(axis, angle))

func transform_bone(bone_name: String, rotation_basis: Basis) -> void:
	if not bone_ids.has(bone_name): return
	var i: int = bone_ids[bone_name]
	var rest := skeleton.get_bone_rest(i)
	var parent := skeleton.get_bone_parent(i)
	var basis: Basis = skeleton.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(i, (basis.inverse() * rotation_basis * basis * rest.basis).get_rotation_quaternion())

func _process(delta: float) -> void:
	clock += delta
	_pose(delta)

func _pose(_delta: float) -> void:
	if not skeleton or not is_instance_valid(actor): return
	var speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
	var gait: float = sin(clock * (10.0 if speed > 4.5 else 7.5)) * minf(speed / 4.0, 1.0)
	if zombie:
		rotate_bone("upperarm_l", Vector3.BACK, -0.85 + sin(clock * 1.2) * 0.05)
		rotate_bone("upperarm_r", Vector3.BACK, 0.85 + cos(clock * 1.4) * 0.05)
		rotate_bone("lowerarm_l", Vector3.RIGHT, -0.55)
		rotate_bone("lowerarm_r", Vector3.RIGHT, -0.65)
		rotate_bone("spine_01", Vector3.RIGHT, 0.14 + sin(clock) * 0.025)
	else:
		var swing: float = actor.melee.pose()
		rotate_bone("upperarm_l", Vector3.BACK, -1.35)
		rotate_bone("upperarm_r", Vector3.BACK, 1.22)
		# Rotate the arm around the shoulder in world space, preserving the rest rig.
		if actor.melee.attacking or actor.melee.charging:
			transform_bone("upperarm_r", Basis(Vector3.RIGHT, -1.3 + swing * 1.2) * Basis(Vector3.BACK, 1.22))
		rotate_bone("lowerarm_r", Vector3.RIGHT, -0.35)
		rotate_bone("spine_01", Vector3.UP, swing * 0.22)
	rotate_bone("thigh_l", Vector3.RIGHT, gait * 0.48)
	rotate_bone("thigh_r", Vector3.RIGHT, -gait * 0.48)
	rotate_bone("calf_l", Vector3.RIGHT, maxf(0, -gait) * 0.5)
	rotate_bone("calf_r", Vector3.RIGHT, maxf(0, gait) * 0.5)
	if axe and bone_ids.has("hand_r"):
		var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_ids["hand_r"])
		axe.global_position = hand.origin
		axe.global_rotation = global_rotation + Vector3(-0.55 + actor.melee.pose() * 1.8, 0, -0.15)

```

## world/zona1_rifugio/fase2.gd

```gdscript
extends Node3D
const Balance = preload("res://autoload/balance.gd")
@onready var player: CharacterBody3D = $Player
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var charge_bar: ProgressBar
var objective: Label
var notice: Label
var pause_panel: Control
var settings_panel: Control
var hud: Control
var menu_title: Label
var resume_button: Button
var cinematic: Camera3D
var landscape: Node3D
var targets: Array[Node3D] = []
var kills: int = 0
var started: bool = false
var automated: bool = false
var notice_left: float = 0
var returning: bool = false
var blood_enabled: bool = true
var sound: AudioStreamPlayer

func _ready() -> void:
	automated = not OS.get_cmdline_user_args().is_empty()
	landscape = Node3D.new()
	landscape.process_mode = Node.PROCESS_MODE_PAUSABLE
	landscape.set_script(preload("res://world/zona1_rifugio/landscape.gd"))
	add_child(landscape)
	landscape.build()
	for child in player.roll_pivot.get_children():
		if child is Node3D: child.visible = false
	var avatar := Node3D.new()
	avatar.set_script(preload("res://art/survivor_visual.gd"))
	player.roll_pivot.add_child(avatar)
	avatar.position.y = -0.9
	avatar.rotation.y = PI
	avatar.configure("SK_Chr_Hunter_Male_01",player)
	_spawn_targets()
	cinematic = Camera3D.new()
	add_child(cinematic)
	cinematic.position = Vector3(14,4.8,12)
	cinematic.look_at(Vector3(-5,1,-11))
	cinematic.fov = 61
	sound = AudioStreamPlayer.new()
	add_child(sound)
	_build_ui()
	player.vitals_changed.connect(_update_vitals)
	player.died.connect(func() -> void: _return_to_spawn("Rientro al rifugio"))
	player.fell_out.connect(func() -> void: _return_to_spawn("Ritorno sulla riva"))
	player.melee.attack_rejected.connect(announce)
	player.melee.attack_started.connect(func(_heavy: bool) -> void: _play("swing"))
	player.melee.impact.connect(func(_target: Node3D, heavy: bool) -> void: _play("heavy" if heavy else "hit"))
	_update_vitals(player.health,player.stamina)
	started = automated
	set_paused(not automated)
	for arg in OS.get_cmdline_user_args():
		if arg == "--verify": _run_checks()
		elif arg.begins_with("--capture="): _capture(arg.trim_prefix("--capture="))
		elif arg == "--capture-menu":
			started = false
			set_paused(true)

func _spawn_targets() -> void:
	for target in targets:
		if is_instance_valid(target): target.queue_free()
	targets.clear()
	kills = 0
	for i in range(3):
		var zombie := CharacterBody3D.new()
		zombie.set_script(preload("res://enemies/zombie_target.gd"))
		zombie.process_mode = Node.PROCESS_MODE_PAUSABLE
		zombie.name = "Zombie%d" % i
		zombie.position = [Vector3(3,0.3,-3),Vector3(8,0.3,-7),Vector3(1,0.3,-10)][i]
		add_child(zombie)
		zombie.rotation.y = 0
		zombie.setup(i)
		zombie.blood_enabled = blood_enabled
		zombie.defeated.connect(func(_body: Node3D) -> void:
			kills += 1
			if kills == 3: announce("Cortile libero. Raggiungi il pontile per riprendere fiato.",8))
		targets.append(zombie)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if not started and not settings_panel.visible: return
		if settings_panel.visible:
			settings_panel.hide()
			pause_panel.show()
		else: set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("preview_help"):
		set_paused(true)
		_show_controls()
	elif not get_tree().paused and event.is_action_pressed("interact"):
		if player.position.distance_to(Vector3(-1,0,4)) < 3:
			_spawn_targets()
			player.health = 100
			player.stamina = 100
			announce("Scorte recuperate. Il cortile è pronto per una nuova prova.")
	elif not get_tree().paused and event.is_action_pressed("test_damage"):
		player.take_damage(20)

func _process(delta: float) -> void:
	if get_tree().paused: return
	if player.position.y < -1.0 and not returning: _return_to_spawn("L'acqua è troppo profonda. Ritorno sulla riva.")
	objective.text = "CORTILE DEL RIFUGIO\n" + ("Area ripulita" if kills == 3 else "Elimina gli infetti  ·  %d / 3" % kills)
	charge_bar.value = player.melee.charge_fraction()*100
	charge_bar.visible = player.melee.charging
	if notice_left > 0:
		notice_left -= delta
		notice.visible = notice_left > 0
	if player.position.distance_to(Vector3(-1,0,4)) < 2.5 and notice_left <= 0:
		notice.text = "E  ·  Rifornisciti e ripeti la prova"
		notice.show()

func set_paused(value: bool) -> void:
	get_tree().paused = value
	pause_panel.visible = value
	settings_panel.hide()
	hud.visible = not value
	cinematic.current = value and not started
	if started: player.rig.camera.current = true
	menu_title.text = "TESTE" if not started else "IN PAUSA"
	resume_button.text = "ENTRA NEL RIFUGIO" if not started else "RIPRENDI"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or automated else Input.MOUSE_MODE_CAPTURED
	if value: resume_button.grab_focus()

func _start() -> void:
	started = true
	set_paused(false)
	announce("Click: colpo rapido  ·  Tieni premuto: colpo caricato",6)

func announce(message: String, seconds: float = 3.0) -> void:
	notice.text = message
	notice.show()
	notice_left = seconds

func _return_to_spawn(message: String) -> void:
	if returning: return
	returning = true
	player.melee.cancel()
	announce(message)
	await get_tree().create_timer(Balance.RESPAWN_SECONDS,false).timeout
	player.reset_at($SpawnPoint.global_position)
	returning = false

func _play(asset: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var path := "res://audio/"+asset+".wav"
	if ResourceLoader.exists(path):
		sound.stream = load(path)
		sound.pitch_scale = randf_range(0.92,1.08)
		sound.play()

func _update_vitals(health: float, stamina: float) -> void:
	health_bar.value = health
	stamina_bar.value = stamina

func _label(parent: Node, text: String, at: Vector2, font_size: int, color: Color = Color("deddd3")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, at: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(330,52)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",20)
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.05,0.075,0.075,0.8)
	base.content_margin_left = 20
	base.border_width_left = 2
	base.border_color = Color("59605a")
	button.add_theme_stylebox_override("normal",base)
	var hover := base.duplicate()
	hover.bg_color = Color("a54e32")
	hover.border_color = Color("e6a16e")
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("focus",hover)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _bar(parent: Node, at: Vector2, width: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = Vector2(width,5)
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size",1)
	bar.custom_minimum_size = Vector2(width,5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03,0.04,0.04,0.7)
	bar.add_theme_stylebox_override("background",bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill",fill)
	parent.add_child(bar)
	bar.set_deferred("size",Vector2(width,5))
	return bar

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Interface.add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift","Segoe UI"])
	var theme := Theme.new()
	theme.default_font = font
	root.theme = theme
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	_label(hud,"LAGO CENERE",Vector2(42,30),23)
	_label(hud,"ZONA 01  /  RIFUGIO",Vector2(43,60),12,Color("b4b9a6"))
	objective = _label(hud,"",Vector2(1080,34),17)
	_label(hud,"+",Vector2(713,439),20,Color(1,1,1,0.65))
	_label(hud,"SOPRAVVISSUTO",Vector2(42,787),13,Color("b4b9a6"))
	health_bar = _bar(hud,Vector2(42,817),240,Color("c9c7ad"))
	stamina_bar = _bar(hud,Vector2(42,831),240,Color("a28555"))
	_label(hud,"ASCIA DA POMPIERE",Vector2(1140,787),17)
	_label(hud,"CLICK  Colpisci     TIENI  Carica",Vector2(1140,817),12,Color("b4b9a6"))
	charge_bar = _bar(hud,Vector2(675,489),90,Color("d18e59"))
	notice = _label(hud,"",Vector2(390,750),17)
	notice.size.x = 660
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(pause_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.018,0.032,0.035,0.78)
	shade.size = Vector2(510,900)
	pause_panel.add_child(shade)
	_label(pause_panel,"UN POSTO DOVE RESTARE VIVI",Vector2(62,120),13,Color("bd9869"))
	menu_title = _label(pause_panel,"TESTE",Vector2(56,152),94)
	_label(pause_panel,"LAGO CENERE",Vector2(62,267),22,Color("b3b8aa"))
	_label(pause_panel,"La strada è silenziosa.\nIl cortile non è vuoto.",Vector2(62,320),18,Color("aeb4ac"))
	resume_button = _button(pause_panel,"ENTRA NEL RIFUGIO",Vector2(62,428),_start)
	_button(pause_panel,"IMPOSTAZIONI",Vector2(62,490),_show_settings)
	_button(pause_panel,"COMANDI",Vector2(62,552),_show_controls)
	_button(pause_panel,"ESCI",Vector2(62,614),func() -> void: get_tree().quit())
	_label(pause_panel,"SOPRAVVIVENZA  /  COMBATTIMENTO  /  ESPLORAZIONE",Vector2(62,807),11,Color("8b978d"))
	_label(pause_panel,"VERSIONE DI SVILUPPO  0.2",Vector2(62,832),11,Color("8b978d"))
	settings_panel = Control.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(settings_panel)
	settings_panel.hide()

func _clear_settings(title: String) -> void:
	for child in settings_panel.get_children():
		settings_panel.remove_child(child)
		child.queue_free()
	pause_panel.hide()
	settings_panel.show()
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.04,0.043,0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(shade)
	_label(settings_panel,title,Vector2(140,130),42)
	_button(settings_panel,"INDIETRO",Vector2(140,680),func() -> void: settings_panel.hide(); pause_panel.show())

func _show_controls() -> void:
	_clear_settings("COMANDI")
	_label(settings_panel,"W A S D\nSHIFT\nSPAZIO / CTRL\nMOUSE\nCLICK SINISTRO\nTIENI + RILASCIA\nE\nESC",Vector2(140,230),22,Color("c69b68"))
	_label(settings_panel,"Muoviti\nCorri\nSchiva\nRuota la visuale\nColpo rapido\nColpo caricato\nRifornimenti vicino al barile\nPausa",Vector2(490,230),22)
	_label(settings_panel,"Controller: levetta sinistra per muoversi, destra per guardare.\nLa pesca è dedicata al cibo; non è ancora attiva in questa versione.\nGli infetti reagiscono ai colpi. L'inseguimento arriverà nella fase successiva.",Vector2(140,550),17,Color("a8b1a7"))

func _show_settings() -> void:
	_clear_settings("IMPOSTAZIONI")
	_label(settings_panel,"Sensibilità visuale",Vector2(140,230),22)
	var sensitivity := HSlider.new()
	sensitivity.position = Vector2(520,240)
	sensitivity.size.x = 400
	sensitivity.min_value = 0.3
	sensitivity.max_value = 2.0
	sensitivity.step = 0.05
	sensitivity.value = player.rig.sensitivity
	settings_panel.add_child(sensitivity)
	sensitivity.value_changed.connect(func(value: float) -> void: player.rig.sensitivity = value)
	_label(settings_panel,"Volume effetti",Vector2(140,310),22)
	var volume := HSlider.new()
	volume.position = Vector2(520,320)
	volume.size.x = 400
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0))*100
	settings_panel.add_child(volume)
	volume.value_changed.connect(func(value: float) -> void: AudioServer.set_bus_volume_db(0,linear_to_db(value/100)))
	var blood := CheckButton.new()
	blood.text = "Effetti del sangue"
	blood.position = Vector2(140,400)
	blood.button_pressed = blood_enabled
	settings_panel.add_child(blood)
	blood.toggled.connect(func(value: bool) -> void:
		blood_enabled = value
		for target in targets: target.blood_enabled = value)
	var shadows := CheckButton.new()
	shadows.text = "Ombre del sole"
	shadows.position = Vector2(140,470)
	var sun: DirectionalLight3D
	for child in landscape.get_children():
		if child is DirectionalLight3D: sun = child
	shadows.button_pressed = sun.shadow_enabled
	settings_panel.add_child(shadows)
	shadows.toggled.connect(func(value: bool) -> void: sun.shadow_enabled = value)

func _capture(path: String) -> void:
	if "--capture-lake" in OS.get_cmdline_user_args():
		player.reset_at(Vector3(6,0.1,12))
		player.rig.yaw = PI
		player.visual.rotation.y = PI
	await get_tree().create_timer(3,true).timeout
	if "--capture-combat" in OS.get_cmdline_user_args():
		player.reset_at(Vector3(3,0.1,-1.45))
		player.melee.perform_attack(true)
		await get_tree().create_timer(0.29).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ",path)
	get_tree().quit()

func _run_checks() -> void:
	var checks := preload("res://tests/phase2_checks.gd").new()
	var success: bool = await checks.run(self)
	sound.stop()
	sound.stream = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if success else 1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not automated and pause_panel:
		set_paused(true)

```

## world/zona1_rifugio/landscape.gd

```gdscript
extends Node3D
const ART := "res://art/surroundead/"
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var props: Dictionary = {}

func build() -> void:
	rng.seed = 74251
	noise.seed = 281
	noise.frequency = 0.035
	_environment()
	_terrain()
	_far_shore()
	# A seven-object fragment from SurrounDead's MainMenu map, retaining relative placement.
	var fragment: Array = JSON.parse_string(FileAccess.get_file_as_string(ART + "map_fragment.json"))
	for row in fragment:
		var p: Array = row.position
		var node := prop(row.mesh, Vector3(p[0], p[1], p[2]), row.yaw, true)
		var s: Array = row.scale
		node.scale = Vector3(s[0], s[1], s[2])
	prop("SM_Bld_House_01", Vector3(20,0,-29), 90, true)
	prop("SM_Veh_Truck_Destroyed_01", Vector3(9,0,-17), -22, true)
	prop("SM_Prop_Tent_Dome_01", Vector3(-3,0,5), 35, true)
	prop("SM_Prop_Barrel_Water_01", Vector3(-1,0,4), 0, true)
	prop("SM_Tree_Log_01", Vector3(0,0.2,7), 70, true)
	for i in range(9):
		var road := prop("SM_Env_RoadPiece_Damaged_01", Vector3(6,0.01,-4-i*6), 0, true)
		road.scale.y = 0.12
	for i in range(2):
		prop("SM_Env_Dock_01", Vector3(6,0,15+i*5), 0, true)
		prop("SM_Env_Dock_Poles_01", Vector3(6,0,16+i*5), 0, false)
	for i in range(6):
		prop("SM_Prop_Fence_Wood_Straight_01", Vector3(-8,0,3-i*2.5), 0, true)
	for i in range(170):
		var x := rng.randf_range(-68,68)
		var z := rng.randf_range(-80,11)
		if absf(x) < 31 and z > -55: continue
		var names := ["SM_Tree_Pine_01", "SM_Tree_Pine_02", "SM_Tree_Pine_Small_01", "SM_Tree_Birch_01"]
		var node := prop(names[i % 4], Vector3(x,height(x,z),z),rng.randf_range(0,360),false)
		node.scale = Vector3.ONE * rng.randf_range(1.1,2.8)
		# Simple trunk collisions keep tree detail out of the physics broadphase.
		if absf(x) < 45 and z > -60:
			box(Vector3(0.5,4,0.5), node.position+Vector3.UP*2, Color.TRANSPARENT)
	for i in range(480):
		var x := rng.randf_range(-40,40)
		var z := rng.randf_range(-58,13)
		if absf(x-6) < 4.5 or (x < -9 and z < -4) or (x > 14 and z < -14):continue
		var n := prop("SM_GrassMeshPatch_03" if i%4 else "SM_Plant_Bush_Leaves_03",Vector3(x,height(x,z),z),rng.randf_range(0,360),false)
		n.scale = Vector3.ONE * rng.randf_range(0.45,1.2)
	for i in range(20):
		var x: float = (-27.0 if i%2 else 31.0)+rng.randf_range(-4,4)
		var z := rng.randf_range(-45,9)
		var tree := prop("SM_Tree_Pine_01",Vector3(x,height(x,z),z),rng.randf_range(0,360),false)
		tree.scale = Vector3.ONE*rng.randf_range(1.3,2.2)
	for i in range(38):
		var x := rng.randf_range(-45,45)
		var z := rng.randf_range(10.5,14)
		if absf(x-6) < 3:continue
		var n := prop("SM_Env_Rock_01", Vector3(x,-0.15,z), rng.randf_range(0,360),true)
		n.scale = Vector3.ONE*rng.randf_range(0.7,1.9)
	_fishing_props()
	# Low barriers at the playable region edge are buried in vegetation.
	box(Vector3(2,6,100),Vector3(-48,2,-28),Color.TRANSPARENT)
	box(Vector3(2,6,100),Vector3(48,2,-28),Color.TRANSPARENT)
	box(Vector3(98,6,2),Vector3(0,2,-77),Color.TRANSPARENT)
	box(Vector3(98,2,1),Vector3(0,-0.15,24),Color.TRANSPARENT)
	var sign := Label3D.new()
	sign.text = "RIFUGIO 01\nLAGO CENERE"
	sign.font_size = 48
	sign.pixel_size = 0.009
	sign.modulate = Color("d8d1b9")
	sign.position = Vector3(-5,1.5,3)
	sign.outline_size = 0
	add_child(sign)
	box(Vector3(2.8,1.1,0.12),Vector3(-5,1.5,3.04),Color("242c29"))
	box(Vector3(0.1,1.3,0.1),Vector3(-5,0.65,3.04),Color("3b3328"))

func prop(asset: String, at: Vector3, yaw: float = 0, collision: bool = false) -> Node3D:
	if not props.has(asset): props[asset] = load(ART + asset + ".glb")
	var node: Node3D = props[asset].instantiate()
	add_child(node)
	node.position = at
	node.rotation.y = deg_to_rad(yaw)
	if asset.begins_with("SM_Tree_") and not "Log" in asset:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://world/zona1_rifugio/tree.gdshader")
		_apply_material(node,mat)
	if collision: _colliders(node)
	return node

func _apply_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D: node.material_override = mat
	for child in node.get_children(): _apply_material(child,mat)

func _colliders(node: Node) -> void:
	if node is MeshInstance3D:
		node.create_trimesh_collision()
	for child in node.get_children():
		if not child is StaticBody3D: _colliders(child)

func box(size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	body.add_child(shape)
	if color.a > 0:
		var view := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		view.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		view.material_override = mat
		body.add_child(view)
	return body

func height(x: float,z: float) -> float:
	if z > 14: return -2.5
	var edge := smoothstep(29,65,absf(x)) + smoothstep(53,85,-z)
	return noise.get_noise_2d(x,z)*edge*10 + edge*2

func _terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-90,90,2):
		for z in range(-100,40,2):
			var corners := [Vector3(x,height(x,z),z),Vector3(x+2,height(x+2,z),z),Vector3(x,height(x,z+2),z+2),Vector3(x+2,height(x+2,z+2),z+2)]
			for k in [0,1,2,1,3,2]:
				var p: Vector3 = corners[k]
				var value := noise.get_noise_2d(p.x*4,p.z*4)*0.5+0.5
				var c := Color("353b28").lerp(Color("62644a"),value)
				if p.z > 9: c = Color("77705d").lerp(Color("44483b"),value)
				st.set_color(c)
				st.add_vertex(p)
	st.generate_normals()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/zona1_rifugio/ground.gdshader")
	mesh.surface_set_material(0,mat)
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	add_child(ground)
	ground.create_trimesh_collision()
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(350,180)
	plane.subdivide_width = 90
	plane.subdivide_depth = 60
	water.mesh = plane
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://world/zona1_rifugio/water.gdshader")
	water.material_override = shader
	water.position = Vector3(0,-0.23,100)
	add_child(water)

func _environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2a424d")
	sky_mat.sky_horizon_color = Color("9aabae")
	sky_mat.ground_horizon_color = Color("9aabae")
	sky_mat.ground_bottom_color = Color("323e3c")
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("a0b9c9")
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("82999e")
	e.fog_density = 0.0022
	e.fog_sky_affect = 0.4
	e.ssao_enabled = true
	e.ssao_radius = 1.6
	e.ssao_intensity = 1.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24,-35,0)
	sun.light_color = Color("ffe1bc")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

func _far_shore() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-160,160,8):
		var h1 := 12.0 + noise.get_noise_2d(x,152)*28.0
		var h2 := 12.0 + noise.get_noise_2d(x+8,152)*28.0
		var vertices := [Vector3(x,-1,75),Vector3(x+8,-1,75),Vector3(x,h1,103),Vector3(x+8,h2,103),Vector3(x,3,135),Vector3(x+8,3,135)]
		for k in [0,1,2,1,3,2,2,3,4,3,5,4]: st.add_vertex(vertices[k])
	st.generate_normals()
	var ridge := MeshInstance3D.new()
	ridge.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("344b49")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ridge.material_override = mat
	add_child(ridge)

func _fishing_props() -> void:
	for item in ["FishingRod","Pike","Boat"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/how_to_fish/"+item+".json"))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for sub in data.triangles:
			for triangle in sub:
				for index in [triangle[2],triangle[1],triangle[0]]:
					var v: Array = data.vertices[index]
					st.add_vertex(Vector3(-v[0],v[1],v[2]))
		st.generate_normals()
		var model := MeshInstance3D.new()
		model.mesh = st.commit()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("4d5e4b") if item == "Boat" else Color("9e9a7e")
		mat.roughness = 0.65
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		model.material_override = mat
		add_child(model)
		var bounds := model.mesh.get_aabb()
		var extent: float = maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
		var wanted: float = 3.7 if item == "Boat" else (1.6 if item == "FishingRod" else 0.45)
		model.scale = Vector3.ONE * wanted / maxf(extent,0.01)
		model.position = Vector3(9,-0.12,18) if item == "Boat" else Vector3(5.5,0.15,19)
		if item == "Pike": model.position = Vector3(6.8,0.15,18.8)

```

## world/zona1_rifugio/ground.gdshader

```gdscript
shader_type spatial;
varying vec3 wp;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float n=noise(wp.xz*0.8)*0.5+noise(wp.xz*3.0)*0.3+noise(wp.xz*24.0)*0.2;
 vec3 moss=mix(vec3(0.085,0.11,0.066),vec3(0.24,0.25,0.16),n);
 vec3 dirt=mix(vec3(0.13,0.115,0.085),vec3(0.31,0.285,0.23),n);
 float path=1.0-smoothstep(3.5,6.0,abs(wp.x-6.0));
 ALBEDO=mix(moss,dirt,max(path*0.65,smoothstep(8.0,14.0,wp.z)));
 ROUGHNESS=0.96;
}

```

## world/zona1_rifugio/tree.gdshader

```gdscript
shader_type spatial;
render_mode cull_disabled;
varying vec3 local_pos;
void vertex(){
 local_pos=VERTEX;
 vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(TIME*0.8+wp.x*0.4+wp.z*0.5)*max(0.0,VERTEX.y-1.2)*0.008;
}
void fragment(){
 float variation=sin(local_pos.x*9.0+local_pos.z*5.0)*0.5+0.5;
 vec3 leaf=mix(vec3(0.055,0.105,0.075),vec3(0.12,0.19,0.10),variation);
 vec3 bark=mix(vec3(0.12,0.10,0.078),vec3(0.21,0.19,0.145),variation);
 ALBEDO=mix(bark,leaf,smoothstep(0.7,1.4,local_pos.y));
 ROUGHNESS=0.95;
}

```

## world/zona1_rifugio/water.gdshader

```gdscript
shader_type spatial;
render_mode cull_disabled;
uniform vec4 water_color : source_color = vec4(0.07,0.18,0.19,1.0);
varying vec3 world_pos;
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y += sin(world_pos.x*1.4+TIME*0.7)*0.018+sin(world_pos.z*2.1-TIME)*0.012;
}
void fragment(){
 float ripple=sin(world_pos.x*4.0+sin(world_pos.z*3.0+TIME))*sin(world_pos.z*5.0-TIME);
 ALBEDO=water_color.rgb+ripple*0.012;
 ROUGHNESS=0.16; METALLIC=0.45;
 NORMAL=normalize(vec3(ripple*0.035,0.0,1.0));
}

```

## tests/phase2_checks.gd

```gdscript
extends RefCounted
var world: Node3D
var player: CharacterBody3D
var failures: Array[String] = []

func check(value: bool, description: String) -> void:
	print("PASS  " if value else "FAIL  ", description)
	if not value: failures.append(description)

func frames(count: int) -> void:
	for i in count: await world.get_tree().physics_frame

func reset_player() -> void:
	for action in ["attack","move_forward","move_right","sprint","dodge"]: Input.action_release(action)
	player.reset_at(Vector3(0,0.3,0))
	player.rig.yaw = 0
	player.visual.rotation.y = 0
	await frames(15)

func target_at(point: Vector3) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.set_script(preload("res://enemies/zombie_target.gd"))
	target.position = point
	world.add_child(target)
	target.setup(0)
	target.blood_enabled = false
	return target

func run(scene: Node3D) -> bool:
	world = scene
	player = world.player
	for target in world.targets: target.position += Vector3(30,0,0)
	await reset_player()
	check(player.is_on_floor(),"Il giocatore appoggia sul terreno importato")
	var avatar: Node3D = player.roll_pivot.get_child(player.roll_pivot.get_child_count()-1)
	check(avatar.skeleton != null and avatar.skeleton.get_bone_count() > 20,"Cacciatore originale con scheletro importato")
	var start := player.position
	Input.action_press("move_forward")
	await frames(60)
	var walking: float = player.position.distance_to(start)
	check(walking > 3.2 and walking < 4.3,"Cammino senza regressioni: %.2f m" % walking)
	await reset_player()
	start = player.position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(60)
	check(player.position.distance_to(start) > walking*1.4,"Sprint più veloce del cammino")
	check(player.stamina < 100,"Sprint consuma stamina")
	await reset_player()
	check(player.try_dodge(Vector3.FORWARD),"Schivata disponibile")
	check(not player.take_damage(20),"Invulnerabilità durante la schivata")
	await reset_player()
	var target := target_at(Vector3(0,0.1,-1.5))
	await frames(8)
	var old_pos := target.position
	check(player.melee.perform_attack(false),"Avvio del colpo rapido")
	check(is_equal_approx(player.stamina,88),"Costo rapido: 12 stamina")
	check(not player.melee.perform_attack(false),"Nessun secondo attacco durante il recupero")
	check(not player.try_dodge(Vector3.RIGHT),"La schivata non interrompe un attacco attivo")
	await frames(45)
	check(is_equal_approx(target.health,46),"Un solo danno da 26 per bersaglio e colpo")
	check(target.position.z < old_pos.z - 0.05,"Impatto sposta lo zombie")
	await world.get_tree().create_timer(0.1,true,false,true).timeout
	check(is_equal_approx(Engine.time_scale,1),"Hit-stop ripristina il tempo")
	await reset_player()
	target.position = Vector3(0,0.1,-1.5)
	await frames(5)
	check(player.melee.begin_charge(),"Inizio caricamento")
	player.melee.charge_time = 0.7
	check(player.melee.release_attack(),"Rilascio del colpo caricato")
	check(is_equal_approx(player.stamina,72),"Costo caricato: 28 stamina")
	await frames(60)
	check(target.dead and is_zero_approx(target.health),"Colpo caricato uccide con salute limitata a zero")
	check(target.collision_layer == 0,"Cadavere escluso dagli impatti successivi")
	target.queue_free()
	await reset_player()
	target = target_at(Vector3(0,0.1,1.4))
	await frames(6)
	player.melee.perform_attack(false)
	await frames(40)
	check(is_equal_approx(target.health,72),"Il colpo non raggiunge alle spalle")
	target.position = Vector3(0,0.1,-3.5)
	await reset_player()
	player.melee.perform_attack(true)
	await frames(60)
	check(is_equal_approx(target.health,72),"Portata limitata")
	await reset_player()
	target.position = Vector3(0,0.1,-1.5)
	var wall: StaticBody3D = world.landscape.box(Vector3(2,2,0.15),Vector3(0,1,-0.7),Color.TRANSPARENT)
	await frames(6)
	player.melee.perform_attack(false)
	await frames(45)
	check(is_equal_approx(target.health,72),"Nessun danno attraverso un muro")
	wall.queue_free()
	target.queue_free()
	await reset_player()
	player.stamina = 5
	check(not player.melee.begin_charge(),"Stamina insufficiente impedisce l'attacco")
	player.stamina = 20
	check(not player.melee.perform_attack(true),"Costo caricato verificato prima dell'attacco")
	check(is_equal_approx(player.stamina,20),"Attacco negato non consuma stamina")
	world.set_paused(true)
	check(world.get_tree().paused and world.pause_panel.visible,"Pausa mostra il menu")
	world._show_settings()
	check(world.settings_panel.visible and not world.pause_panel.visible,"Impostazioni accessibili")
	world.set_paused(false)
	player.take_damage(1000)
	await world.get_tree().create_timer(1.5,false).timeout
	check(not player.dead and is_equal_approx(player.health,100),"Rientro dopo morte ripristina giocatore")
	print("FASE 2: ",failures.size()," errori")
	return failures.is_empty()

```

## autoload/balance.gd

```gdscript
# Risorsa di sole costanti, precaricata dagli script. Nessun nodo o figlio richiesto.
extends RefCounted

# Giocatore Fase 1. Economia, tempo e combattimento saranno implementati in seguito.
const PLAYER_MAX_HEALTH: float = 100.0
const PLAYER_MAX_STAMINA: float = 100.0
const WALK_SPEED: float = 4.0
const SPRINT_SPEED: float = 7.0
const ACCELERATION: float = 22.0
const DECELERATION: float = 28.0
const TURN_SPEED: float = 12.0
const GRAVITY: float = 22.0
const FLOOR_SNAP: float = 0.4
const SPRINT_DRAIN: float = 22.0
const STAMINA_REGEN: float = 27.0
const STAMINA_REGEN_DELAY: float = 0.7
const EXHAUSTION_RECOVERY: float = 20.0
const DODGE_COST: float = 25.0
const DODGE_SPEED: float = 9.0
const DODGE_SECONDS: float = 0.55
const DODGE_IFRAMES: float = 0.28
const DODGE_COOLDOWN: float = 0.3
const RESPAWN_SECONDS: float = 1.2
const FALL_RESET_Y: float = -5.0
const TEST_DAMAGE: float = 20.0
const TEST_DAMAGE_INTERVAL: float = 1.0
const CAMERA_SENSITIVITY: float = 0.0025
const CAMERA_PAD_SPEED: float = 2.2
const CAMERA_PITCH_MIN: float = -1.05
const CAMERA_PITCH_MAX: float = 0.3
const CAMERA_PITCH_DEFAULT: float = -0.28
const CAMERA_LENGTH: float = 5.2
const CAMERA_MIN_LENGTH: float = 2.0
const CAMERA_MAX_LENGTH: float = 7.0
const CAMERA_ZOOM_STEP: float = 0.5
const CAMERA_HEIGHT: float = 1.45
const CAMERA_FOLLOW_SPEED: float = 18.0
const WALK_ANIMATION_SPEED: float = 2.6
const LEG_SWING: float = 0.52
const BODY_BOB: float = 0.035
const MELEE_CONE_DOT: float = 0.25
const ATTACK_MOVE_MULTIPLIER: float = 0.3
const HIT_STOP_SECONDS: float = 0.055
const HIT_STOP_SCALE: float = 0.08
const LIGHT_SHAKE: float = 0.3
const HEAVY_SHAKE: float = 0.65
const TARGET_HEALTH: float = 72.0
const TARGET_FRICTION: float = 12.0
const TARGET_STAGGER: float = 0.35
const TARGET_HEAVY_STAGGER: float = 0.7
const TARGET_RESET_RANGE: float = 3.0
const TARGET_COLLAPSE_SECONDS: float = 0.65
const DAY_SECONDS: float = 720.0
const NIGHT_SECONDS: float = 360.0
const SUNSET_WARNING_SECONDS: float = 30.0
const NIGHT_SPEED_MULTIPLIER: float = 1.3
const NIGHT_HEALTH_MULTIPLIER: float = 1.4
const NIGHT_HEAD_MULTIPLIER: int = 2
const ARMORED_HEAD_VALUE: int = 2
const BANK_CAPACITY: int = 200
const CORPSE_LIFETIME: float = 30.0
const AUTOSAVE_SECONDS: float = 300.0
const SAVE_SLOTS: int = 3
const WOOD_FOR_SAFEHOUSE: int = 10
const HEADS_FOR_SHOP: int = 20
const GAMBLING_MIN_BET: int = 5
const GAMBLING_MAX_BET: int = 100

# Parametri della sola anteprima, separati dai futuri controlli del personaggio.
const PREVIEW_MOUSE_SENSITIVITY: float = 0.004
const PREVIEW_PAD_SPEED: float = 1.5
const PREVIEW_MIN_PITCH: float = 0.18
const PREVIEW_MAX_PITCH: float = 1.2
const PREVIEW_MIN_DISTANCE: float = 9.0
const PREVIEW_MAX_DISTANCE: float = 65.0
const PREVIEW_ZOOM_STEP: float = 2.0
const PREVIEW_DISTANCE: float = 47.0
const PREVIEW_YAW: float = 0.68
const PREVIEW_PITCH: float = 0.62
const PREVIEW_TARGET: Vector3 = Vector3(0, 0, 0)
const PREVIEW_HOUSE_TARGET: Vector3 = Vector3(-9, 1, -5)
const PREVIEW_DOCK_TARGET: Vector3 = Vector3(5, 0, 7)
const PREVIEW_HOUSE_DISTANCE: float = 22.0
const PREVIEW_DOCK_DISTANCE: float = 23.0

```

