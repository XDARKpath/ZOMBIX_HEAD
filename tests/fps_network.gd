extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var session=root.get_node("Session")
	var host := "--fps-host" in OS.get_cmdline_user_args()
	var world=load("res://world/zona1_rifugio/zombix.tscn").instantiate();root.add_child(world)
	var good := true
	if host:
		session.host(27847);paused=false
		await create_timer(7,true).timeout
		good=session.roster.size()==4
		session.launch()
		var crouched := {};var jumped := {}
		var elapsed := 0.0
		while elapsed<7.0:
			await create_timer(0.05,true).timeout;elapsed+=0.05
			for id in world.actors:
				if id==1:continue
				var actor=world.actors[id]
				if actor.crouching and actor.body_collider.shape.height<1.2:crouched[id]=true
				if elapsed>2.5 and actor.position.y>0.35:jumped[id]=true
		good=good and crouched.size()==3 and jumped.size()==3
		print("FPS_NET_HOST peers=",session.roster.size()," crouched=",crouched.size()," jumped=",jumped.size()," valid=",good)
	else:
		session.profile("FPS%d"%OS.get_process_id(),OS.get_process_id()%3)
		session.join("127.0.0.1",27847);paused=false
		await create_timer(2,true).timeout;session.set_ready(true)
		await session.game_started
		await create_timer(0.5,true).timeout
		Input.action_press("crouch");Input.action_press("move_right")
		await create_timer(1.5,true).timeout
		good=world.player.crouching and world.player.eye_height<1.0
		Input.action_release("crouch");Input.action_release("move_right")
		await create_timer(0.7,true).timeout
		Input.action_press("jump")
		await create_timer(0.05,true).timeout;Input.action_release("jump")
		await create_timer(0.2,true).timeout
		good=good and world.player.position.y>0.3 and world.player.rig.camera.current and not world.player.visual.visible
		var remote_seen := false
		for id in world.actors:
			if world.actors[id]!=world.player:remote_seen=remote_seen or world.actors[id].visual.visible
		good=good and remote_seen
		print("FPS_NET_CLIENT actors=",world.actors.size()," jump_y=",world.player.position.y," snapshots=",world.snapshots_received," valid=",good)
		await create_timer(4,true).timeout
	session.leave();world.queue_free();await process_frame;quit(0 if good else 1)
