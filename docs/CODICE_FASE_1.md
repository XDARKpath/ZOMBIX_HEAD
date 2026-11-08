# Script completi — Fase 1

I file sono già presenti e pronti all’uso.

## autoload/audio_manager.gd

```gdscript
# Audio; autoload AudioManager, nessun figlio richiesto.
# Interfaccia predisposta: la logica arriva nelle fasi successive.
extends Node

signal music_requested(context: String)
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

## autoload/economy_manager.gd

```gdscript
# Economia; autoload EconomyManager, nessun figlio richiesto.
# Interfaccia predisposta: la logica arriva nelle fasi successive.
extends Node

signal heads_changed(carried: int, banked: int)
signal transaction_completed(kind: String, amount: int)
```

## autoload/game_state.gd

```gdscript
# Stato globale; autoload GameState, nessun figlio richiesto.
# Interfaccia predisposta: la logica arriva nelle fasi successive.
extends Node

signal objective_changed(text: String)
signal zone_unlocked(zone_id: int)

const PROJECT_PHASE: int = 1
const CONTENT_VERSION: String = "0.1.0"
```

## autoload/save_manager.gd

```gdscript
# Salvataggi; autoload SaveManager, nessun figlio richiesto.
# Interfaccia predisposta: la logica arriva nelle fasi successive.
extends Node

signal save_completed(slot: int)
signal save_failed(reason: String)

const FUTURE_SAVE_PATTERN: String = "user://save_slot_%d.json"
```

## autoload/time_manager.gd

```gdscript
# Tempo; autoload TimeManager, nessun figlio richiesto.
# Interfaccia predisposta: la logica arriva nelle fasi successive.
extends Node

signal night_changed(is_night: bool)
signal sunset_warning

# Il tempo resta fermo nell’anteprima: il ciclo sarà implementato in Fase 7.
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
		yaw -= event.relative.x * Balance.CAMERA_SENSITIVITY
		pitch = clampf(pitch - event.relative.y * Balance.CAMERA_SENSITIVITY,
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

func reset_follow() -> void:
	global_position = subject.global_position + Vector3.UP * Balance.CAMERA_HEIGHT
	rotation = Vector3(0, yaw, 0)
	arm.rotation.x = pitch

func movement_direction(input: Vector2) -> Vector3:
	# Si usa solo lo yaw: inclinare la camera non altera la velocità del personaggio.
	return Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
```

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
		sprinting = Input.is_action_pressed("sprint") and input.length() > 0.1 and not exhausted and stamina > 0 and is_on_floor()
		var speed: float = Balance.SPRINT_SPEED if sprinting else Balance.WALK_SPEED
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
	if facing.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), minf(1, Balance.TURN_SPEED * delta))
	_animate(delta)
	vitals_changed.emit(health, stamina)
	if global_position.y < Balance.FALL_RESET_Y:
		dead = true
		velocity = Vector3.ZERO
		rig.controls_enabled = false
		fell_out.emit()

func try_dodge(direction: Vector3) -> bool:
	if dead or dodging or dodge_cooldown > 0 or stamina < Balance.DODGE_COST or not is_on_floor():
		return false
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
```

## tests/phase1_checks.gd

```gdscript
# Test di integrazione eseguito da Rifugio con --verify; nessun nodo o figlio richiesto.
extends RefCounted

const Balance = preload("res://autoload/balance.gd")
var world: Node3D
var player: CharacterBody3D
var failures: PackedStringArray = []

func check(condition: bool, description: String) -> void:
	print("PASS  " if condition else "FAIL  ", description)
	if not condition:
		failures.append(description)

func frames(count: int) -> void:
	for i in range(count):
		await world.get_tree().physics_frame

func release_inputs() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "dodge"]:
		Input.action_release(action)

func reset(point: Vector3 = Vector3(0, 0.5, 2)) -> void:
	release_inputs()
	player.rig.yaw = 0
	player.rig.pitch = Balance.CAMERA_PITCH_DEFAULT
	player.reset_at(point)
	await frames(20)

func run(scene: Node3D) -> bool:
	world = scene
	player = scene.get_node("Player")
	await reset()
	check(player.is_on_floor(), "Il personaggio appoggia sul terreno")
	check(is_equal_approx(player.health, 100), "Vita iniziale piena")
	var start := player.global_position
	Input.action_press("move_forward")
	await frames(60)
	var walking: float = (player.global_position - start).length()
	check(walking > 3.2 and walking < 4.3, "Cammino misurato: %.2f m" % walking)
	await reset()
	start = player.global_position
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await frames(60)
	var diagonal: float = (player.global_position - start).length()
	check(absf(diagonal - walking) < 0.3, "Diagonale senza bonus velocità: %.2f m" % diagonal)
	await reset()
	start = player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(60)
	var sprint: float = (player.global_position - start).length()
	check(sprint > walking * 1.5, "La corsa è più veloce: %.2f m" % sprint)
	check(player.stamina < 85 and player.stamina > 70, "La corsa consuma stamina")
	release_inputs()
	await frames(120)
	check(is_equal_approx(player.stamina, 100), "Stamina recuperata dopo la pausa")
	await reset()
	player.stamina = 0.1
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(5)
	check(player.exhausted and player.stamina >= 0 and not player.sprinting, "Esaurimento senza stamina negativa")
	await reset()
	player.stamina = Balance.DODGE_COST - 1
	check(not player.try_dodge(Vector3.FORWARD), "Schivata negata se la stamina non basta")
	await reset()
	Input.action_press("dodge")
	await frames(2)
	Input.action_release("dodge")
	check(player.dodging and player.stamina <= 75, "Input schivata e costo stamina")
	check(not player.take_damage(20) and player.health == 100, "I-frame iniziali bloccano il danno")
	await frames(18)
	check(player.dodging and not player.is_invulnerable(), "L'invulnerabilità termina prima del rotolamento")
	check(player.take_damage(20) and player.health == 80, "Danno nuovamente attivo dopo gli i-frame")
	await frames(17)
	check(not player.try_dodge(Vector3.FORWARD), "Cooldown impedisce schivate consecutive immediate")
	await reset()
	player.rig.yaw = PI / 2
	start = player.global_position
	Input.action_press("move_forward")
	await frames(25)
	check(player.global_position.x < start.x - 0.6 and absf(player.global_position.z - start.z) < 0.15,
		"Movimento relativo allo yaw della camera")
	await reset(Vector3(-9, 0.5, -12))
	player.rig.yaw = PI
	Input.action_press("move_forward")
	await frames(100)
	check(player.global_position.z < -8.5, "Il muro posteriore della casa blocca il giocatore")
	await reset(Vector3(-9, 0.9, -6))
	player.rig.yaw = PI
	player.rig.pitch = -0.12
	player.rig.reset_follow()
	await frames(15)
	var arm: SpringArm3D = player.rig.arm
	check(arm.get_hit_length() > 0 and arm.get_hit_length() < Balance.CAMERA_LENGTH - 0.5,
		"SpringArm avvicina la camera davanti al muro: %.2f m" % arm.get_hit_length())
	await reset(Vector3(-9, 0.5, 3))
	Input.action_press("move_forward")
	await frames(75)
	check(player.global_position.z < -0.5 and player.global_position.y > 0.25,
		"La rampa permette di entrare sul portico senza salto")
	await frames(45)
	check(player.global_position.z < -3 and player.global_position.y > 0.35,
		"Il giocatore entra all'interno del rifugio")
	await reset(Vector3(6, 0.5, 6))
	player.rig.yaw = PI
	Input.action_press("move_forward")
	await frames(105)
	check(player.global_position.z > 12 and player.global_position.y > 0.15,
		"Il pontile è raggiungibile a piedi e sostiene il giocatore")
	await reset()
	check(world.get_viewport().get_visible_rect().encloses(world.health_bar.get_global_rect()),
		"La barra vita è dentro la finestra")
	start = player.global_position
	world.set_paused(true)
	check(world.resume_button.has_focus(), "Il menu dà il focus al pulsante Riprendi")
	Input.action_press("move_forward")
	await frames(20)
	check(player.global_position.distance_to(start) < 0.01, "La pausa blocca il movimento")
	world.set_paused(false)
	await reset(Vector3(6, 0.5, -8))
	await frames(65)
	check(player.health < 100 and player.health > 0, "La zona rossa infligge danni reali")
	await reset()
	check(not player.take_damage(-20) and player.health == 100, "Danni negativi rifiutati")
	player.take_damage(1000)
	check(player.dead and player.health == 0, "La morte azzera la vita senza valori negativi")
	await frames(90)
	check(not player.dead and player.health == 100 and player.stamina == 100,
		"Respawn con vita e stamina ripristinate")
	check(player.global_position.distance_to(world.get_node("SpawnPoint").global_position) < 0.7,
		"Respawn nel punto previsto")
	player.global_position.y = -8
	await frames(90)
	check(not player.dead and player.global_position.y >= 0, "Recupero dopo caduta fuori dal mondo")
	release_inputs()
	print("FASE 1: ", "PASS" if failures.is_empty() else "FAIL", " — ", failures.size(), " errori")
	return failures.is_empty()
```

## world/test_scene.gd

```gdscript
# Nodo: TestScene (Node3D), scena world/test_scene.tscn.
# Figli richiesti: Camera3D, Interface (CanvasLayer), Terrain/Ground,
# House, Dock, Forest, ZombiePlaceholder, SpawnPoint, Environment, Sun.
# Solo anteprima Fase 0: nessun personaggio o sistema di combattimento attivo.
extends Node3D

const Balance = preload("res://autoload/balance.gd")
const INK := Color("10282d")
const PAPER := Color("e4ebd3")
const MUTED := Color("9bafb0")
const ACCENT := Color("dcec91")

@onready var camera: Camera3D = $Camera3D
@onready var interface: CanvasLayer = $Interface
var target: Vector3 = Balance.PREVIEW_TARGET
var distance: float = Balance.PREVIEW_DISTANCE
var yaw: float = Balance.PREVIEW_YAW
var pitch: float = Balance.PREVIEW_PITCH
var input_label: Label
var view_label: Label
var help_panel: PanelContainer
var escape_panel: PanelContainer
var root_ui: Control
var view_buttons: Array[Button] = []
var input_active: bool = true

func _ready() -> void:
	_build_interface()
	_set_view(0)
	for argument in OS.get_cmdline_user_args():
		if argument == "--verify":
			_verify_setup()
		elif argument.begins_with("--capture="):
			_capture(argument.trim_prefix("--capture="))
		elif argument == "--capture-help":
			_toggle_help()

func _process(delta: float) -> void:
	if input_active:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		yaw -= stick.x * Balance.PREVIEW_PAD_SPEED * delta
		pitch = clampf(pitch + stick.y * Balance.PREVIEW_PAD_SPEED * delta,
			Balance.PREVIEW_MIN_PITCH, Balance.PREVIEW_MAX_PITCH)
	_update_camera()

func _update_camera() -> void:
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)
	camera.h_offset = -distance * 0.12

func _input(event: InputEvent) -> void:
	# Il pannello mostra gli input anche quando un controllo UI ha il focus.
	if event is InputEventKey and event.echo:
		return
	var actions: PackedStringArray = []
	for action in InputMap.get_actions():
		if not action.begins_with("ui_") and event.is_action_pressed(action):
			actions.append(action)
	if not actions.is_empty():
		input_label.text = "INPUT RICEVUTO  /  " + ", ".join(actions)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		escape_panel.visible = not escape_panel.visible
		input_active = not escape_panel.visible and not help_panel.visible
		return
	if event.is_action_pressed("preview_help"):
		_toggle_help()
	if not input_active:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * Balance.PREVIEW_MOUSE_SENSITIVITY
		pitch = clampf(pitch + event.relative.y * Balance.PREVIEW_MOUSE_SENSITIVITY,
			Balance.PREVIEW_MIN_PITCH, Balance.PREVIEW_MAX_PITCH)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(Balance.PREVIEW_MIN_DISTANCE, distance - Balance.PREVIEW_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(Balance.PREVIEW_MAX_DISTANCE, distance + Balance.PREVIEW_ZOOM_STEP)
	for i in range(3):
		if event.is_action_pressed("preview_view_%d" % i):
			_set_view(i)

func _set_view(index: int) -> void:
	var targets := [Balance.PREVIEW_TARGET, Balance.PREVIEW_HOUSE_TARGET, Balance.PREVIEW_DOCK_TARGET]
	var distances := [Balance.PREVIEW_DISTANCE, Balance.PREVIEW_HOUSE_DISTANCE, Balance.PREVIEW_DOCK_DISTANCE]
	target = targets[index]
	distance = distances[index]
	yaw = Balance.PREVIEW_YAW
	pitch = Balance.PREVIEW_PITCH
	view_label.text = ["01 / LA RIVA", "02 / IL RIFUGIO", "03 / IL PONTILE"][index]
	for i in range(view_buttons.size()):
		view_buttons[i].modulate = ACCENT if i == index else Color.WHITE
	_update_camera()

func _style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _label(text: String, size: int, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_stylebox_override("normal", _style(Color("203c40"), Color("45605c")))
	button.add_theme_stylebox_override("hover", _style(Color("35504b"), ACCENT))
	button.add_theme_stylebox_override("pressed", _style(Color("425b42"), ACCENT))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), ACCENT))
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", PAPER)
	button.pressed.connect(callback)
	return button

func _build_interface() -> void:
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface.add_child(root_ui)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	root_ui.theme = theme
	var masthead := _label("T /   TESTE     ·     STUDIO DEL MONDO", 18, ACCENT)
	masthead.position = Vector2(42, 28)
	root_ui.add_child(masthead)
	var phase := _label("FASE 00     /     STUDIO DEL MONDO", 16)
	phase.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	phase.position = Vector2(-360, 28)
	root_ui.add_child(phase)
	var panel := PanelContainer.new()
	panel.position = Vector2(42, 108)
	panel.custom_minimum_size = Vector2(338, 0)
	panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.12, 0.14, 0.94), Color("355253")))
	root_ui.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 13)
	panel.add_child(stack)
	stack.add_child(_label("UN RIFUGIO NEL MONDO DEGLI INFETTI.", 14, ACCENT))
	stack.add_child(_label("TESTE", 78))
	stack.add_child(_label("IL RIFUGIO", 23, ACCENT))
	stack.add_child(HSeparator.new())
	var premise := _label("Esplora il mondo.\nAffronta gli infetti.\nTorna al rifugio.", 23)
	stack.add_child(premise)
	var scope := _label("Anteprima del mondo in Godot.\nRifugio, bosco e pontile esplorabili\ncon la camera di osservazione.", 17, MUTED)
	stack.add_child(scope)
	stack.add_child(_label("CAMERA DI OSSERVAZIONE", 13, ACCENT))
	for i in range(3):
		var button := _button(["01   La riva                     F6", "02   Il rifugio                  F7", "03   Il pontile                  F8"][i], _set_view.bind(i))
		view_buttons.append(button)
		stack.add_child(button)
	stack.add_child(_button("Comandi e stato del progetto   F1", _toggle_help))
	stack.add_child(_label("PERSONAGGIO E COMBATTIMENTO\nIN ARRIVO NELLE PROSSIME FASI", 12, MUTED))
	view_label = _label("", 17, PAPER)
	view_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	view_label.position = Vector2(-240, -124)
	root_ui.add_child(view_label)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 42
	bottom.offset_right = -42
	bottom.offset_top = -98
	bottom.offset_bottom = -24
	bottom.add_theme_stylebox_override("panel", _style(Color(0.04, 0.12, 0.14, 0.96), Color("355253")))
	root_ui.add_child(bottom)
	var rows := VBoxContainer.new()
	bottom.add_child(rows)
	rows.add_child(_label("MOUSE DESTRO + TRASCINA  Orbita     /     ROTELLA  Zoom     /     STICK DESTRO  Orbita     /     ESC  Menu", 16))
	input_label = _label("TEST INPUT  /  Premi WASD, E, Q o un comando del gamepad: qui vedrai l'azione rilevata.", 14, ACCENT)
	rows.add_child(input_label)
	help_panel = _overlay("COMANDI / FASE 0", "Ora puoi ruotare la camera, cambiare vista e verificare gli input.\nWASD e gli altri comandi vengono rilevati, ma non muovono un giocatore.\n\nCONTROLLI PREDISPOSTI PER LE PROSSIME FASI\nWASD / stick sinistro: movimento   ·   Shift / L3: sprint\nSpazio o Ctrl / B: schivata   ·   E / A: interazione\nMouse sinistro / RT: attacco   ·   Mouse destro / LT: mira\nR / X: ricarica   ·   Q / D-pad su: cura   ·   F / Y: veicolo\n1–5: armi   ·   LB / RB: arma precedente / successiva\nTab / Back: inventario   ·   M / D-pad giù: mappa\nEsc / Start: menu   ·   F1: questa guida\n\nNon sono ancora attivi pesca, nemici, economia, salvataggi o audio.\nLa casa, la barca e lo zombie sono elementi statici di prova.")
	help_panel.get_child(0).add_child(_button("Torna all'anteprima", _toggle_help))
	escape_panel = _overlay("ANTEPRIMA IN PAUSA", "TESTE · Acque morte\nFase 0: configurazione e ambiente di prova.\n\nIl progetto completo si sviluppa nelle fasi successive.")
	escape_panel.get_child(0).add_child(_button("Riprendi", func() -> void:
		escape_panel.hide()
		input_active = not help_panel.visible))
	escape_panel.get_child(0).add_child(_button("Esci", func() -> void: get_tree().quit()))

func _overlay(title: String, body: String) -> PanelContainer:
	var panel := PanelContainer.new()
	root_ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -310
	panel.offset_bottom = 310
	panel.add_theme_stylebox_override("panel", _style(Color("10282d"), ACCENT))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	panel.add_child(rows)
	rows.add_child(_label(title, 26, ACCENT))
	rows.add_child(_label(body, 19))
	panel.hide()
	return panel

func _toggle_help() -> void:
	help_panel.visible = not help_panel.visible
	escape_panel.hide()
	input_active = not help_panel.visible

func _verify_setup() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var errors: PackedStringArray = []
	for service in ["GameState", "EconomyManager", "SaveManager", "AudioManager", "TimeManager"]:
		if get_node_or_null("/root/" + service) == null:
			errors.append("Autoload assente: " + service)
	for action in ["move_forward", "move_back", "move_left", "move_right", "attack", "aim", "interact", "sprint", "dodge", "reload", "heal", "vehicle", "inventory", "map", "pause", "weapon_1", "weapon_5"]:
		if not InputMap.has_action(action) or InputMap.action_get_events(action).is_empty():
			errors.append("Input assente: " + action)
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 5, 0), Vector3(0, -5, 0), 1)
	if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		errors.append("Collisione del terreno assente")
	for i in range(3):
		_set_view(i)
		if not camera.position.is_finite():
			errors.append("Camera non valida")
	_toggle_help()
	if not help_panel.visible or input_active:
		errors.append("Apertura guida non valida")
	_toggle_help()
	if help_panel.visible or not input_active:
		errors.append("Chiusura guida non valida")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	event.pressed = true
	get_viewport().push_input(event)
	if not input_label.text.contains("interact"):
		errors.append("Il tasto E non raggiunge il monitor input")
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	get_viewport().push_input(release)
	if errors.is_empty():
		print("FASE 0: PASS — autoload, input, collisione terreno, tre camere e guida.")
		get_tree().quit(0)
	else:
		for message in errors:
			push_error(message)
		get_tree().quit(1)

func _capture(path: String) -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("Anteprima salvata: ", path, " | esito: ", error)
	get_tree().quit(error)
```

## world/zona1_rifugio/rifugio.gd

```gdscript
# Nodo: Rifugio (Node3D), scena rifugio.tscn; process_mode Always per gestire il menu in pausa.
# Figli richiesti: Player, SpawnPoint, DamageZone (Area3D), Interface (CanvasLayer).
extends Node3D

const Balance = preload("res://autoload/balance.gd")
@onready var player: CharacterBody3D = $Player
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var health_text: Label
var stamina_text: Label
var state_text: Label
var notice: Label
var pause_panel: Control
var notice_left: float = 0
var damage_clock: float = 0
var returning: bool = false
var automated: bool = false
var resume_button: Button

func _ready() -> void:
	automated = not OS.get_cmdline_user_args().is_empty()
	_build_ui()
	player.vitals_changed.connect(_update_vitals)
	player.damaged.connect(func(amount: float) -> void: announce("Colpo ricevuto: −%d vita" % int(amount)))
	player.died.connect(func() -> void: _return_to_spawn("Hai perso la testa. Per ora, solo per prova."))
	player.fell_out.connect(func() -> void: _return_to_spawn("Fuori dall'area di prova: ritorno al rifugio."))
	_update_vitals(player.health, player.stamina)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if automated else Input.MOUSE_MODE_CAPTURED
	announce("Esplora il rifugio. F1 per i comandi; Esc per liberare il mouse.", 7)
	for argument in OS.get_cmdline_user_args():
		if argument == "--verify":
			_run_checks()
		elif argument.begins_with("--capture="):
			_capture(argument.trim_prefix("--capture="))
		elif argument == "--capture-menu":
			set_paused(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not automated:
		set_paused(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("preview_help"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif not get_tree().paused and event.is_action_pressed("test_damage"):
		if not player.take_damage(Balance.TEST_DAMAGE):
			announce("Schivata riuscita: colpo evitato." if player.is_invulnerable() else "Attendi il rientro al rifugio.")

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if $DamageZone.overlaps_body(player) and not player.dead:
		damage_clock += delta
		if damage_clock >= Balance.TEST_DAMAGE_INTERVAL:
			damage_clock = 0
			player.take_damage(Balance.TEST_DAMAGE)
	else:
		damage_clock = 0
	if notice_left > 0:
		notice_left -= delta
		notice.visible = notice_left > 0
	if player.dead:
		state_text.text = "RIENTRO AL RIFUGIO…"
	elif player.is_invulnerable():
		state_text.text = "SCHIVATA  /  INVULNERABILE"
	elif player.dodging:
		state_text.text = "RECUPERO SCHIVATA"
	elif player.exhausted:
		state_text.text = "AFFATICATO  /  RECUPERA STAMINA"
	elif player.sprinting:
		state_text.text = "CORSA"
	else:
		state_text.text = "ESPLORAZIONE"

func set_paused(value: bool) -> void:
	get_tree().paused = value
	pause_panel.visible = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or automated else Input.MOUSE_MODE_CAPTURED
	if value:
		resume_button.grab_focus()

func announce(text: String, seconds: float = 3.0) -> void:
	notice.text = text
	notice.show()
	notice_left = seconds

func _return_to_spawn(message: String) -> void:
	if returning:
		return
	returning = true
	announce(message, Balance.RESPAWN_SECONDS + 2)
	await get_tree().create_timer(Balance.RESPAWN_SECONDS, false).timeout
	player.reset_at($SpawnPoint.global_position)
	damage_clock = 0
	returning = false

func _update_vitals(health: float, stamina: float) -> void:
	health_bar.value = health
	stamina_bar.value = stamina
	health_text.text = "VITA                         %03d / 100" % ceili(health)
	stamina_text.text = "STAMINA                      %03d / 100" % ceili(stamina)

func _label(text: String, size: int = 18, color: Color = Color("e6eddc")) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.08, 0.08, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	return button

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(310, 13)
	bar.show_percentage = false
	bar.max_value = 100
	bar.add_theme_stylebox_override("background", _style(Color("162c2c")))
	bar.add_theme_stylebox_override("fill", _style(color))
	return bar

func _build_ui() -> void:
	var root := Control.new()
	$Interface.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI"])
	var theme := Theme.new()
	theme.default_font = font
	root.theme = theme
	var heading := _label("TESTE", 40, Color("dcec91"))
	heading.position = Vector2(36, 24)
	root.add_child(heading)
	var sub := _label("01  /  IL RIFUGIO", 17)
	sub.position = Vector2(38, 76)
	root.add_child(sub)
	var task := _label("FASE 1  ·  CAMPO DI PROVA\nEsplora, corri e prova la schivata.\nIl riquadro rosso infligge danni di prova.", 17)
	root.add_child(task)
	task.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	task.offset_left = -412
	task.offset_top = 34
	task.offset_right = -30
	var hud := PanelContainer.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.offset_left = 36
	hud.offset_top = -265
	hud.offset_bottom = -74
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_stylebox_override("panel", _style(Color(0.035, 0.1, 0.11, 0.94)))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 9)
	hud.add_child(rows)
	health_text = _label("")
	rows.add_child(health_text)
	health_bar = _bar(Color("de8469"))
	rows.add_child(health_bar)
	stamina_text = _label("")
	rows.add_child(stamina_text)
	stamina_bar = _bar(Color("dcec91"))
	rows.add_child(stamina_bar)
	state_text = _label("ESPLORAZIONE", 13, Color("b8cda4"))
	rows.add_child(state_text)
	var controls := _label("WASD  Muovi     SHIFT  Corri     SPAZIO / CTRL  Schiva     MOUSE  Camera     F1 / ESC  Comandi e pausa", 17)
	root.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 36
	controls.offset_top = -40
	notice = _label("", 20, Color("f3e7a5"))
	root.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -440
	notice.offset_right = 440
	notice.offset_top = 126
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var crosshair := _label("·", 28)
	root.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -4
	crosshair.offset_top = -20
	pause_panel = ColorRect.new()
	root.add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(pause_panel as ColorRect).color = Color(0.02, 0.06, 0.07, 0.85)
	var menu := PanelContainer.new()
	pause_panel.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -390
	menu.offset_right = 390
	menu.offset_top = -315
	menu.offset_bottom = 315
	menu.add_theme_stylebox_override("panel", _style(Color("152f32")))
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", 17)
	menu.add_child(items)
	items.add_child(_label("TESTE  /  PAUSA", 32, Color("dcec91")))
	items.add_child(_label("WASD / stick sinistro: movimento\nMouse / stick destro: camera · Rotella: distanza\nShift / L3: corsa · Spazio, Ctrl / B: rotolamento\nEsc / Start: pausa · F1: questa guida\n\nF2: ricevi un colpo di prova (20 danni).\nSchiva e premi F2 per provare l'invulnerabilità iniziale.\nA vita zero torni al rifugio. Non esiste ancora un inventario.\n\nGli zombie sono modelli di prova: AI nella Fase 3.\nLa pesca futura fornirà solo cibo. Non si pescano zombie.\nArmi e combattimento iniziano nella Fase 2.", 20))
	resume_button = _button("Riprendi", func() -> void: set_paused(false))
	items.add_child(resume_button)
	items.add_child(_button("Riparti al rifugio", func() -> void:
		if returning:
			return
		player.reset_at($SpawnPoint.global_position)
		damage_clock = 0
		set_paused(false)))
	items.add_child(_button("Esci", func() -> void: get_tree().quit()))
	pause_panel.hide()

func _run_checks() -> void:
	var checks = load("res://tests/phase1_checks.gd").new()
	var passed: bool = await checks.run(self)
	get_tree().quit(0 if passed else 1)

func _capture(path: String) -> void:
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("Cattura Fase 1: ", error)
	get_tree().quit(error)
```
