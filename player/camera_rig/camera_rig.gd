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
var bob_clock: float = 0.0
var dip: float = 0.0
var lean: float = 0.0
var was_airborne: bool = false
# Dialogo con sceriffo/mercante: ci si sporge sul bancone (0..1, dal viewmodel).
var focus_lean: float = 0.0
# Colpo subito: la testa scatta dalla parte opposta e torna. Da stordito o avvelenato la vista ondeggia.
var punch := Vector2.ZERO
var wobble_clock: float = 0.0
# Mira (0..1) e lo sguardo che segue il peso del fendente.
var aim_amount: float = 0.0
var swing_roll: float = 0.0

func _ready() -> void:
	top_level = true
	arm.spring_length = 0.0
	arm.collision_mask = 0
	camera.position = Vector3.ZERO
	camera.near = 0.04
	arm.add_excluded_object(subject.get_rid())
	reset_follow()

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * Balance.CAMERA_SENSITIVITY * sensitivity
		pitch = clampf(pitch - event.relative.y * Balance.CAMERA_SENSITIVITY * sensitivity,
			Balance.CAMERA_PITCH_MIN, Balance.CAMERA_PITCH_MAX)

func _physics_process(delta: float) -> void:
	if controls_enabled:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		yaw -= stick.x * Balance.CAMERA_PAD_SPEED * delta
		pitch = clampf(pitch - stick.y * Balance.CAMERA_PAD_SPEED * delta,
			Balance.CAMERA_PITCH_MIN, Balance.CAMERA_PITCH_MAX)
	# Follow the collision body without horizontal lag or third-person orbit.
	var speed: float = Vector2(subject.velocity.x, subject.velocity.z).length()
	var walking: float = clampf(speed / 3.2, 0.0, 1.0)
	bob_clock += delta * (8.6 if subject.sprinting else 7.0) * walking
	var bob := Vector3(cos(bob_clock) * 0.012, absf(sin(bob_clock)) * 0.020, 0.0) * walking
	if subject.crouching: bob *= 0.55
	# Atterraggio: piccolo cedimento elastico invece di uno scatto secco.
	if not subject.is_on_floor():
		was_airborne = true
	elif was_airborne:
		was_airborne = false
		dip = 0.055
	dip = move_toward(dip, 0.0, delta * 0.28)
	global_position = subject.global_position + Vector3.UP * (subject.eye_height - dip)
	rotation = Vector3(0, yaw, 0)
	arm.rotation.x = pitch - focus_lean * 0.10
	camera.position = Vector3(0, -0.05, -0.07) * focus_lean
	# Inclinazione laterale quando si corre di lato, più una leggera rotazione del polso.
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back") if subject.local_control else subject.network_move
	var target_lean: float = -input.x * (0.045 if subject.sprinting else 0.025)
	lean = lerpf(lean, target_lean, 1.0 - exp(-delta * 6.0))
	trauma = move_toward(trauma, 0, delta * 2.5)
	camera.h_offset = randf_range(-1, 1) * trauma * 0.012 + bob.x - lean * 0.35
	camera.v_offset = randf_range(-1, 1) * trauma * 0.010 + bob.y
	var target_fov := (79.0 if subject.sprinting else 75.0) + (3.0 if subject.melee.attacking and aim_amount < 0.1 else 0.0) - 20.0 * aim_amount
	camera.fov = lerpf(camera.fov,target_fov,1.0-exp(-delta*5))
	punch = punch.lerp(Vector2.ZERO, 1.0 - exp(-delta * 7.0))
	wobble_clock += delta
	var woozy: float = subject.status.wobble() if subject.get("status") else 0.0
	camera.rotation.z = lean + sin(bob_clock * 0.5) * 0.0035 * walking + punch.x + swing_roll + sin(wobble_clock * 1.7) * 0.035 * woozy
	camera.rotation.x = punch.y + sin(wobble_clock * 1.1) * 0.012 * woozy

## from: da dove è arrivato il colpo, nel mondo. forza 0..1.
func hit_punch(from: Vector3, force: float) -> void:
	var to: Vector3 = from - subject.global_position
	var right: Vector3 = Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var front: Vector3 = Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var sideways: float = clampf(right.dot(to.normalized()), -1.0, 1.0)
	punch += Vector2(sideways * 0.09, front.dot(to.normalized()) * 0.05 + 0.02) * clampf(force, 0.2, 1.2)

func add_shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func reset_follow() -> void:
	global_position = subject.global_position + Vector3.UP * subject.eye_height
	rotation = Vector3(0, yaw, 0)
	arm.rotation.x = pitch

func movement_direction(input: Vector2) -> Vector3:
	# Si usa solo lo yaw: inclinare la camera non altera la velocità del personaggio.
	return Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
