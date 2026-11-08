extends SceneTree
var world:Node3D
var mission:Node3D
var car:CharacterBody3D
var good:bool=true
func _initialize() -> void: call_deferred("run")
func wait_for(predicate:Callable,seconds:float=25) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline: await create_timer(0.1,true).timeout
	return predicate.call()
func run() -> void:
	var session:Node=root.get_node("Session")
	var hosting:bool="--campaign-host" in OS.get_cmdline_user_args()
	world=load("res://world/zona1_rifugio/zombix.tscn").instantiate();root.add_child(world)
	mission=world.expedition;car=mission.car
	if hosting:
		session.host(27849);paused=false
		good=await wait_for(func(): return session.roster.size()==4 and session.roster.values().all(func(member): return member.ready))
		if good: session.launch()
		else: print("FAIL network lobby did not assemble");quit(1);return
		for enemy in world.targets: enemy.set_physics_process(false)
		world.targets[0].state=2;world.targets[0].attack_clock=0.48;world.targets[0].stagger=0
		await create_timer(1.2,true).timeout
		good=good and mission.collected.count(true)==0 and car.seats.count(0)==4 and car.drive_input==Vector2.ZERO
		print("NET invalid remote interactions rejected=",good)
		mission.collected=[true,true,true];mission.stage=1;mission._publish()
		for peer in world.actors: world.actors[peer].position=car.position+Vector3(2.1,0.2,0)
		good=await wait_for(func(): return car.repaired) and good
		good=await wait_for(func(): return car.seats.count(0)==1) and good
		world.player.position=car.position+Vector3(-2.1,0.2,0)
		good=car.interact(1) and good
		var driver:int=car.seats[0]
		good=driver!=1 and car.all_aboard() and good
		var start:Vector3=car.position
		good=await wait_for(func(): return car.position.distance_to(start)>4,15) and good
		print("NET remote driver motion=",car.position.distance_to(start)," all_aboard=",car.all_aboard())
		good=await wait_for(func(): return absf(car.speed)<0.1,15) and good
		# Validate shared destination replication; the long route itself is covered separately.
		car.position=preload("res://world/campaign/route.gd").POINTS[1]+Vector3.UP*0.2
		car.speed=0;car.velocity=Vector3.ZERO;car.drive_input=Vector2.ZERO;car.input_age=1
		# La strada verso la Zona 2 si apre dopo i due posti di blocco: qui conta solo la destinazione condivisa.
		if world.get("roadblocks"): world.roadblocks.cleared=[true,true]
		car._place_occupants()
		good=mission.try_arrive() and good;car.publish()
		good=await wait_for(func(): return car.seats.count(0)==3,15) and good
		print("CAMPAIGN_NET_HOST zone=",mission.zone_index," seats=",car.seats," valid=",good)
		await create_timer(2,true).timeout
	else:
		session.profile("Campaign%d"%OS.get_process_id(),OS.get_process_id()%3)
		session.join("127.0.0.1",27849);paused=false
		good=await wait_for(func(): return session.roster.size()==4)
		session.set_ready(true)
		good=await wait_for(func(): return world.started) and good
		# A non-driver attempts steering and a distant player requests pickup.
		car.steer.rpc_id(1,Vector2(1,-1));mission.request_use()
		var attack_synced:bool=await wait_for(func(): return not world.targets.is_empty() and world.targets[0].attack_clock>0.4 and str(world.targets[0].avatar.get_meta("zm",{}).get("clip","")).begins_with("Z_Attack"),8)
		good=good and attack_synced
		print("NET zombie skeletal attack synchronized=",attack_synced)
		good=await wait_for(func(): return mission.stage==1 and world.player.position.distance_to(car.position)<3.4) and good
		var ids:Array=session.roster.keys();ids.erase(1);ids.sort()
		var rank:int=ids.find(world.multiplayer.get_unique_id())
		if rank==0: mission.request_use()
		good=await wait_for(func(): return car.repaired) and good
		await create_timer(0.4+rank*0.7,true).timeout;mission.request_use()
		good=await wait_for(func(): return world.player.seated) and good
		good=await wait_for(func(): return car.seats.count(0)==0) and good
		if rank==0:
			Input.action_press("move_forward");await create_timer(2.5,true).timeout;Input.action_release("move_forward")
		else:
			# Passenger packets cannot overwrite the legitimate driver's controls.
			car.steer.rpc_id(1,Vector2(1,1))
		good=await wait_for(func(): return mission.zone_index==1,25) and good
		good=good and mission.unlocked==1 and mission.stage==3 and world.player.seated
		await create_timer(0.4+rank*0.3,true).timeout;mission.request_use()
		good=await wait_for(func(): return not world.player.seated,10) and good
		good=good and world.player.controls_enabled and world.player.position.distance_to(car.position)<6
		print("CAMPAIGN_NET_CLIENT rank=",rank," snapshots=",world.snapshots_received," campaign_packets=",mission.broadcast_count," valid=",good)
		await create_timer(3,true).timeout
	session.leave();world.queue_free();await process_frame;await process_frame;quit(0 if good else 1)
