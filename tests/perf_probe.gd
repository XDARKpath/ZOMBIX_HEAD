extends SceneTree
# Sonda prestazioni: media e minimo FPS nella strada del villaggio, vsync spento.
func _initialize():call_deferred("run")
func run():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var world:Node3D=load("res://world/zona1_rifugio/zombix.tscn").instantiate();root.add_child(world);world.automated=true
	root.get_node("Session").launch();await create_timer(2.0).timeout
	world.player.reset_at(Vector3(6,0.1,2))
	var frames:=0;var total:=0.0;var worst:=999.0
	for i in range(420):
		world.player.rig.yaw=sin(i*0.012)*0.9
		await process_frame
		if i>60:
			var fps:=Engine.get_frames_per_second()
			total+=fps;worst=minf(worst,fps);frames+=1
	print("PERF avg %.1f  min %.1f  frames %d" % [total/frames,worst,frames])
	quit()
