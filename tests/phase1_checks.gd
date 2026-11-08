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
