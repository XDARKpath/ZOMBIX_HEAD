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
