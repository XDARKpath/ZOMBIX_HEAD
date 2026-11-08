extends SceneTree
var world:Node3D
var player:CharacterBody3D
var failures:=0
var total:=0
func _initialize():call_deferred("run")
func frames(n:int):
	for i in n: await physics_frame
func check(ok:bool,label:String):
	total+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func walk(to:Vector3,label:String):
	var arrived:=false
	for i in 360:
		var d:=to-player.position;d.y=0
		if d.length()<0.2:arrived=true;break
		player.rig.yaw=atan2(-d.x,-d.z)
		Input.action_press("move_forward")
		await frames(1)
	Input.action_release("move_forward");await frames(10)
	check(arrived,label+" actual="+str(player.position))
func run():
	world=load("res://world/zona1_rifugio/zombix.tscn").instantiate();root.add_child(world)
	world.automated=true;root.get_node("Session").launch();await frames(10)
	player=world.player;world.expedition.set_process(false)
	for e in world.targets:e.set_physics_process(false);e.collision_layer=0
	player.reset_at(Vector3(-15,0.1,-6));await frames(10)
	await walk(Vector3(-15,0,-10),"Enter keeper house walking without jumping")
	await walk(Vector3(-15,0,-11.1),"Cross front room around table")
	await walk(Vector3(-17.25,0,-11.1),"Approach inner doorway")
	await walk(Vector3(-17.25,0,-13.3),"Walk through inner doorway")
	await walk(Vector3(-17.25,0,-13.7),"Stand beside office desk")
	check(world.expedition.use(1),"Battery collected from floor beside desk")
	player.reset_at(Vector3(-17.5,0.1,-17.1));await frames(8)
	check(not world.expedition.can_reach(player,world.expedition.POINTS[0]),"Back wall blocks interaction through wall")
	player.reset_at(Vector3(23.4,0.1,-17));await frames(8)
	await walk(Vector3(23.4,0,-25.1),"Enter open workshop and reach bench")
	check(world.expedition.use(1),"Belt collected from floor beside workbench")
	player.reset_at(Vector3(-10,0.1,-40));await frames(8)
	await walk(Vector3(-10,0,-42.2),"Reach fuel pallet from forecourt")
	check(world.expedition.use(1) and world.expedition.stage==1,"Fuel collected; repair stage unlocked")
	var map=world.get_world_3d().navigation_map
	for pair in [[Vector3(-15,0,-6),Vector3(-17.25,0,-13.7)],[Vector3(23.4,0,-17),Vector3(23.4,0,-25.1)],[Vector3(-15,0,-29),Vector3(-17.25,0,-36.7)]]:
		var path=NavigationServer3D.map_get_path(map,pair[0],pair[1],true)
		check(path.size()>1 and path[-1].distance_to(pair[1])<0.8,"Zombie navigation reaches room "+str(pair[1])+" path="+str(path))
	player.reset_at(Vector3(-15,0.1,-13.6));await frames(10)
	var pursuer=world.targets[0]
	pursuer.position=Vector3(-15,0.1,-6);pursuer.velocity=Vector3.ZERO
	pursuer.target=player;pursuer.last_seen=player.position;pursuer.memory=60;pursuer.state=1
	pursuer.agent.target_position=player.position;pursuer.set_physics_process(true)
	var reached:=false
	for tick in 900:
		await frames(1)
		if pursuer.position.z< -12.9 and pursuer.position.distance_to(player.position)<1.8 and pursuer.clear_line(player):reached=true;break
	pursuer.set_physics_process(false)
	check(reached,"Zombie physically pursues player through both doors; actual="+str(pursuer.position))
	for i in 3:
		var e=world.targets[i];e.stagger=0;e.state=0;e.velocity=Vector3.ZERO
		e.avatar._pose(0.2)
		var bones=e.avatar.bone_ids;var skeleton:Skeleton3D=e.avatar.skeleton
		var id:int=bones["hand_r"]
		var rest:Quaternion=skeleton.get_bone_pose_rotation(id)
		e.state=2;e.attack_clock=0.48
		for tick in 20:e.avatar._pose(0.02)
		check(str(e.avatar.get_meta("zm").clip).begins_with("Z_Attack") and rest.angle_to(skeleton.get_bone_pose_rotation(id))>0.01,"Zombie variant %d attack changes skeletal hand pose"%i)
		e.state=1;e.stagger=0.5;e.avatar._pose(0.2)
		check(str(e.avatar.get_meta("zm").clip) in ["Z_Hit_Front","Z_Hit_Head","Z_Hit_L","Z_Hit_R","Z_Stagger_Heavy"],"Zombie variant %d reacts to hit"%i)
		e.dead=true;e.avatar._pose(0.2)
		check(str(e.avatar.get_meta("zm").clip).begins_with("Z_Death"),"Zombie variant %d uses skeletal death"%i)
	print("REFUGE_CHECKS ",total," failures=",failures)
	world.queue_free();await process_frame;await process_frame;quit(0 if failures==0 else 1)


