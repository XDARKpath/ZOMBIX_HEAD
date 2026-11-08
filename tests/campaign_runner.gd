extends SceneTree
const Route=preload("res://world/campaign/route.gd")
var world:Node3D
var mission:Node3D
var car:CharacterBody3D
var failures:int=0
var total:int=0
func _initialize() -> void: call_deferred("run")
func check(value:bool,message:String) -> void:
	total+=1
	print("PASS " if value else "FAIL ",message)
	if not value: failures+=1
func frames(count:int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	world=load("res://world/zona1_rifugio/zombix.tscn").instantiate();root.add_child(world)
	root.get_node("Session").launch();await frames(8)
	mission=world.expedition;car=mission.car
	mission.set_process(false)
	for enemy in world.targets: enemy.set_physics_process(false)
	check(Route.POINTS.size()==8,"Eight campaign destinations")
	var total_distance:=0.0;var distance_ok:=true;var roads_ok:=true
	for i in range(7):
		var d:float=Route.POINTS[i].distance_to(Route.POINTS[i+1]);total_distance+=d
		distance_ok=distance_ok and d>1400
		for j in range(31):
			var point:Vector3=Route.POINTS[i].lerp(Route.POINTS[i+1],float(j)/30)
			roads_ok=roads_ok and absf(world.terrain.height(point.x,point.z))<0.001
	check(distance_ok,"Every destination is at least 1.4 km from previous; route %.2f km"%(total_distance/1000))
	check(roads_ok,"All road samples are level and connected to terrain")
	check(world.terrain.sources.size()==68,"68 nature models available to terrain distribution")
	check(mission.unlocked==0 and not car.repaired,"Future GPS coordinates and vehicle initially locked")
	check(not mission.use(9999),"Unknown peer cannot interact")
	check(not mission.use(1),"Remote pickup denied")
	world.player.position=car.position+Vector3(2,0,0)
	check(not car.interact(1),"Unrepaired vehicle cannot be entered")
	for i in range(3):
		world.player.position=mission.POINTS[i]+Vector3(0,0.2,0)
		check(mission.use(1),"Repair component %d collected nearby"%(i+1))
	check(mission.collected.count(true)==3 and mission.stage==1,"All three components required before repair")
	check(not mission.use(1),"Repair cannot start remotely")
	world.player.position=car.position+Vector3(2,0.2,0)
	check(mission.use(1) and mission.repairing_peer==1,"Repair starts next to vehicle")
	world.player.position+=Vector3(8,0,0);mission._process(1)
	check(mission.repairing_peer==0 and mission.hold==8,"Walking away cancels repair")
	world.player.position=car.position+Vector3(2,0.2,0);mission.use(1);mission._process(8.1)
	check(car.repaired and mission.unlocked==1 and mission.stage==2,"Completed repair reveals only the next destination")
	check(car.interact(1) and world.player.seated,"Driver enters first free seat")
	check(not world.player.try_jump() and not world.player.melee.begin_charge(),"Seated player cannot jump or attack")
	for peer in range(2,5):
		var actor:CharacterBody3D=load("res://player/player.tscn").instantiate()
		actor.name="TestPeer%d"%peer;actor.local_control=false;world.add_child(actor)
		actor.rig.set_physics_process(false);actor.rig.camera.current=false
		actor.position=car.position+Vector3(-2,0.2,0);world.actors[peer]=actor
		check(car.interact(peer),"Passenger %d enters distinct seat"%peer)
	check(car.all_aboard() and car.seats==[1,2,3,4],"All four unique occupants recognized")
	var start:Vector3=car.position
	Input.action_press("move_forward");await frames(70)
	check(car.speed>5 and car.position.distance_to(start)>2,"W accelerates physical vehicle along road")
	check(not car.interact(1),"Cannot exit moving vehicle")
	Input.action_release("move_forward");await frames(65)
	check(absf(car.speed)<0.1,"Vehicle brakes to rest when input stops")
	check(car.interact(4) and not world.actors[4].seated,"Passenger can exit safely when stopped")
	check(not car.all_aboard(),"Missing passenger blocks squad travel")
	world.player.position=Route.POINTS[1]
	check(not mission.try_arrive(),"Walking/teleporting player to next zone does not complete vehicle travel")
	world.actors[4].position=car.position+Vector3(-2,0.2,0);car.interact(4)
	car.position=Route.POINTS[1]+Vector3.UP*0.2;car.speed=0;car._place_occupants()
	check(mission.try_arrive() and mission.zone_index==1 and mission.stage==3,"Stopped vehicle with entire squad activates next zone")
	check(mission.remaining_enemies()==6,"Arrival spawns six local defenders")
	check(not mission.downloading and mission.remaining_enemies()>0,"Relay download remains blocked before clearing zone")
	# Exercise all remaining destination transitions and final completion without replaying combat.
	for zone in range(1,8):
		for enemy in world.targets: enemy.dead=true;enemy.set_physics_process(false)
		for peer in world.actors:
			car._release(peer);world.actors[peer].position=mission.beacons[zone].position+Vector3.UP*0.2
		car.seats=[0,0,0,0]
		check(mission.use(1),"Zone %d relay requires cleared yard and assembled squad"%(zone+1))
		mission._process(10.1)
		if zone<7:
			check(mission.unlocked==zone+1 and mission.stage==2,"GPS unlocks exactly one new destination")
			car.seats=[1,2,3,4];car.position=Route.POINTS[zone+1]+Vector3.UP*0.2;car.speed=0;car._place_occupants()
			check(mission.try_arrive(),"Vehicle arrival for zone %d"%(zone+2))
	check(mission.stage==4 and mission.unlocked==7,"Eighth zone completes route without invalid ninth destination")
	check(world.terrain.tiles.size()<=50,"Terrain unloads distant sectors")
	var avatar:Node3D=world.player_avatar
	var zx_player=avatar.operative_driver.model if avatar.operative_driver else null
	check(zx_player and zx_player.tree and zx_player._player.has_animation("Player_Car_Sit_Drive") and zx_player._player.has_animation("Player_Repair_Wheel"),"ZX avatar clips include driving and repair")
	for weapon in ["bow","bow_native","crossbow","arrow","arrow_native","bolt"]:
		var item:Node=load("res://art/weapons/"+weapon+".tscn").instantiate()
		check(item.has_node("GripMain") and item.has_node("Muzzle"),"Reusable archery scene: "+weapon);item.free()
	print("CAMPAIGN_CHECKS ",total," failures=",failures)
	world.queue_free();await process_frame;await process_frame
	root.get_node("Session").leave();await process_frame;quit(0 if failures==0 else 1)
