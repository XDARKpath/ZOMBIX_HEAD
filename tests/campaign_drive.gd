extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world:Node3D=load("res://world/zona1_rifugio/zombix.tscn").instantiate();root.add_child(world)
	root.get_node("Session").launch()
	for i in range(10): await physics_frame
	for enemy in world.targets: enemy.set_physics_process(false)
	var mission:Node3D=world.expedition;var car:CharacterBody3D=mission.car
	mission.collected=[true,true,true];mission.stage=2;mission.unlocked=1;car.repaired=true
	world.player.position=car.position+Vector3(2.1,0.2,0);car.interact(1)
	var destination:Vector3=preload("res://world/campaign/route.gd").POINTS[1]
	var low_y:float=car.position.y;var peak:float=0;var samples:=0;var stuck:=0
	for frame in range(7200):
		var difference:Vector3=destination-car.position
		var yaw:=atan2(-difference.x,-difference.z)
		var error:=wrapf(yaw-car.rotation.y,-PI,PI)
		Input.action_release("move_left");Input.action_release("move_right")
		if error>0.015: Input.action_press("move_left",minf(1,error*4))
		elif error< -0.015: Input.action_press("move_right",minf(1,-error*4))
		if difference.length()>18: Input.action_press("move_forward")
		else: Input.action_release("move_forward")
		await physics_frame
		low_y=minf(low_y,car.position.y);peak=maxf(peak,car.speed);samples+=1
		if frame>180 and car.speed<1 and difference.length()>22: stuck+=1
		if mission.zone_index==1 or stuck>300: break
	for action in ["move_forward","move_left","move_right"]: Input.action_release(action)
	var valid:bool=mission.zone_index==1 and low_y> -0.1 and peak>20 and car.all_aboard()
	print("CAMPAIGN_DRIVE distance_remaining=",car.position.distance_to(destination)," pos=",car.position," frames=",samples," peak_speed=",peak," floor_min=",low_y," valid=",valid)
	root.get_node("Session").leave();world.queue_free();await process_frame;quit(0 if valid else 1)
