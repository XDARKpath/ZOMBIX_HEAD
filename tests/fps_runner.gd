extends SceneTree
var failures := 0
var lab: Node3D
var player: CharacterBody3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func frames(count: int) -> void:
	for i in range(count):await physics_frame
## Il corpo locale resta in scena ma è solo ombra: non disegna nulla davanti alla camera.
func avatar_hidden() -> bool:
	for mesh in player.visual.find_children("*","MeshInstance3D",true,false):
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:return false
	return true
func reset(at: Vector3) -> void:
	for action in ["move_forward","move_back","move_left","move_right","sprint","jump","crouch"]:Input.action_release(action)
	player.reset_at(at);player.rig.yaw=0;player.rig.pitch=0
	await frames(8)
func run() -> void:
	lab=load("res://world/movement_lab/movement_lab.tscn").instantiate();root.add_child(lab)
	player=lab.player
	await frames(10)
	check(player.is_on_floor(),"Player settles on the floor")
	# L'atterraggio abbassa la camera di qualche centimetro: si aspetta che la molla rientri.
	for i in 30:await frames(1)
	check(avatar_hidden() and player.rig.arm.spring_length==0,"Local avatar does not obscure first-person camera")
	check(absf(player.rig.camera.global_position.y-player.position.y-player.eye_height)<0.01,"Standing camera is at eye height")
	Input.action_press("move_forward");await frames(45)
	check(absf(player.velocity.z+4)<0.05,"Walk accelerates to 4 m/s")
	Input.action_press("sprint");await frames(35)
	check(player.sprinting and player.velocity.z< -6.9 and player.stamina<100,"Forward sprint reaches 7 m/s and consumes stamina")
	await reset(Vector3(0,0.05,5))
	Input.action_press("move_right");Input.action_press("sprint");await frames(30)
	check(not player.sprinting and player.velocity.x<=4.01,"Sideways movement does not become a full-speed sprint")
	await reset(Vector3(0,0.05,5))
	check(player.try_jump(),"Grounded jump accepted")
	check(not player.try_jump(),"Repeated jump before takeoff is rejected")
	var apex := player.position.y
	for i in range(60):await frames(1);apex=maxf(apex,player.position.y)
	check(apex>1.15 and apex<1.45 and player.is_on_floor(),"Jump reaches a controlled height and lands (%.2f m)"%apex)
	await reset(Vector3(-5,0.05,-2))
	Input.action_press("move_forward");await frames(10);Input.action_press("jump");await frames(65)
	check(player.position.z< -4.7,"Jump clears the 45 cm obstacle")
	await reset(Vector3(5,0.05,-1.5))
	Input.action_press("move_forward");await frames(50)
	check(player.position.z> -3.0,"Standing player is blocked by low tunnel entrance")
	Input.action_press("crouch");await frames(70)
	check(player.crouching and player.position.z< -3.5,"Crouched player enters the low tunnel")
	Input.action_release("move_forward");Input.action_release("crouch");await frames(15)
	check(player.crouching and player.eye_height<1.0,"Releasing crouch under roof keeps body and eyes below ceiling")
	check(not player.try_jump(),"Jump is blocked while crouched under roof")
	Input.action_press("move_forward");await frames(160);Input.action_release("move_forward");await frames(20)
	check(not player.crouching and player.position.z< -7.5 and player.eye_height>1.6,"Player stands again after leaving tunnel")
	await reset(Vector3(0,0.05,5));player.rig.pitch=1.35
	Input.action_press("move_forward");await frames(30)
	check(absf(player.velocity.z+4)<0.05,"Looking up does not change horizontal walking speed")
	await reset(Vector3(0,0.05,5));player.controls_enabled=false
	Input.action_press("move_forward");Input.action_press("jump");await frames(20)
	check(player.position.distance_to(Vector3(0,0,5))<0.05,"Disabled controls cannot move or jump")
	player.controls_enabled=true
	await reset(Vector3(0,0.05,5));player.stamina=0
	check(not player.try_jump(),"Empty stamina blocks jumping")
	player.stamina=100
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			player.rig.pitch=-0.12
			await frames(8);await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))
	print("FPS: ",failures," errors")
	lab.queue_free();await process_frame;quit(0 if failures==0 else 1)
