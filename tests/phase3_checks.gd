extends RefCounted
var failures: Array[String] = []
var world: Node3D
func check(condition: bool, message: String) -> void:
	print("PASS " if condition else "FAIL ",message)
	if not condition: failures.append(message)
func frames(count: int) -> void:
	for i in count: await world.get_tree().physics_frame
func run(scene: Node3D) -> bool:
	world = scene
	check(world.camp.avatars.size()==4,"Quattro posti nella lobby")
	check(world.camp.avatars[1].stance==1 and world.camp.avatars[2].sniper!=null and world.camp.avatars[3].katana!=null,"Pose al falò con i loro oggetti")
	world.choose_skin(2)
	check(Session.skin==2,"Scelta della skin")
	world.menu.settings()
	check(world.menu.page=="settings","Impostazioni accessibili")
	world.menu.home()
	Session.launch()
	await frames(10)
	check(world.nav_region.navigation_mesh.get_polygon_count()>0,"NavMesh generata dalle collisioni")
	check(world.targets.size()==6,"Sei zombie iniziali")
	check(world.actors.size()==1,"Giocatore singolo registrato")
	var zombie: CharacterBody3D = world.targets[0]
	for other in world.targets:
		if other!=zombie: other.set_physics_process(false)
	world.player.reset_at(Vector3(3,0.1,2))
	zombie.position = Vector3(3,0.1,-4)
	zombie.rotation.y = PI
	await frames(15)
	check(zombie.state==1,"Vista attiva l'inseguimento")
	var start := zombie.position
	await frames(60)
	check(zombie.position.distance_to(start)>0.6,"Navigazione muove lo zombie")
	var route := NavigationServer3D.map_get_path(world.get_world_3d().navigation_map,Vector3(9,0,-23),Vector3(9,0,-11),true)
	check(route.size()>2,"Percorso devia attorno al camion")
	zombie.position = world.player.position+Vector3(0,0,-1.1)
	zombie.state = 1
	zombie.target = world.player
	zombie.memory = 6
	var health: float = world.player.health
	await frames(75)
	check(world.player.health<health,"Attacco infligge danno dopo il preavviso")
	zombie.position = Vector3(0,0.1,-10)
	zombie.state = 0
	zombie.target = null
	zombie.hear(world.player,30)
	check(zombie.state==1,"Rumore attiva l'inseguimento")
	var wall: StaticBody3D = world.landscape.box(Vector3(3,3,0.2),(zombie.position+world.player.position)*0.5+Vector3.UP,Color.TRANSPARENT)
	await frames(2)
	check(not zombie.clear_line(world.player),"I muri bloccano la linea di vista")
	wall.queue_free()
	zombie.memory = 0
	world.player.position = Vector3(30,0.1,5)
	await frames(10)
	check(zombie.state==0,"Perdita interesse riporta al vagare")
	zombie.receive_melee(1000,Vector3.ZERO,true)
	check(zombie.dead and zombie.corpse_time>120,"Cadavere conservato per tagliare la testa")
	zombie.corpse_time = 0.05
	await frames(10)
	check(not is_instance_valid(zombie),"Cadavere rimosso alla scadenza")
	check(world.targets.size()<=24,"Limite totale dei corpi rispettato")
	check(world.survival.threat==0,"Allerta iniziale a zero")
	for i in range(5): world.survival.raise_threat()
	check(world.survival.threat==3,"Allerta limitata a tre ondate")
	var intruders := 0
	for enemy in world.targets:
		if is_instance_valid(enemy) and preload("res://world/zona1_rifugio/refuge_layout.gd").safe(enemy.position): intruders += 1
	check(intruders==0,"Le ondate non entrano nell'area illuminata")
	check(world.targets.size()<=36,"Ondate entro il tetto dei corpi")
	world.set_paused(true)
	check(world.get_tree().paused,"Pausa ferma la partita singola")
	world.set_paused(false)
	print("FASE3: ",failures.size()," errori")
	return failures.is_empty()
