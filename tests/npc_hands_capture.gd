extends SceneTree
# Scatti ravvicinati di sceriffo e fumatore del falò: posa intera e mani.
func _initialize():call_deferred("run")

func shot(cam:Camera3D,from:Vector3,at:Vector3,fov:float,name:String) -> void:
	cam.fov=fov
	cam.global_position=from
	cam.look_at(at)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/npc-%s.png"%name))

func run():
	var world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	await create_timer(0.6).timeout
	world.get_node("Interface").hide()
	var cam:=Camera3D.new()
	world.add_child(cam)
	cam.current=true
	var time:float=float(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size()>0 else 0.0
	# Fumatore del falò (posto 0).
	var smoker=world.camp.avatars[0]
	smoker.set_process(false)
	smoker.clock=time
	smoker._pose(0)
	var b:Basis=smoker.global_basis
	var chest:Vector3=smoker._bone_frame("spine_03").origin
	await shot(cam,chest+b*Vector3(0.2,0.25,1.6),chest+b*Vector3(0,-0.15,0),45,"smoker-full")
	var hl:Vector3=smoker.hand("l")
	await shot(cam,hl+b*Vector3(0.35,0.1,0.45),hl,35,"smoker-pistol")
	await shot(cam,hl+b*Vector3(0.55,0.0,0.05),hl+b*Vector3(0,-0.06,0),35,"smoker-pistol-side")
	await shot(cam,hl+b*Vector3(0.1,-0.05,0.55),hl+b*Vector3(0,-0.06,0),35,"smoker-pistol-front")
	await shot(cam,hl+b*Vector3(0.8,0.2,0.8),hl+b*Vector3(0,0.0,0),40,"smoker-pistol-mid")
	await shot(cam,smoker.hand("r")+b*Vector3(-0.8,0.2,0.8),smoker.hand("r"),40,"smoker-cig-mid")
	var hr:Vector3=smoker.hand("r")
	await shot(cam,hr+b*Vector3(-0.3,0.1,0.45),hr,35,"smoker-cig")
	smoker.clock=4.0
	smoker._pose(0)
	await shot(cam,chest+b*Vector3(0.2,0.25,1.6),chest+b*Vector3(0,-0.15,0),45,"smoker-full-up")
	var cg:Vector3=smoker.cigarette.global_position
	await shot(cam,cg+b*Vector3(-0.45,0.05,0.35),cg,40,"smoker-cig-up")
	# Sceriffo.
	var npc=world.survival.sheriff_node
	var body=npc.get_node("SheriffBody")
	body.set_process(false)
	body.clock=time
	body._pose(0)
	var nb:Basis=npc.global_basis
	await shot(cam,npc.global_position+Vector3(-1.7,1.75,1.3),npc.global_position+Vector3(-.35,.95,0),58,"sheriff-full")
	var grip:Vector3=body.cigarette.global_position
	await shot(cam,grip+Vector3(-.35,.12,.42),grip,40,"sheriff-cig")
	await shot(cam,grip+nb*Vector3(-.55,.05,0),grip,40,"sheriff-cig-front")
	body.clock=time+5.5
	body._pose(0)
	grip=body.cigarette.global_position
	await shot(cam,grip+Vector3(-.5,.35,.6),grip,40,"sheriff-cig-low")
	await shot(cam,grip+nb*Vector3(-.6,.25,-.3),grip,40,"sheriff-cig-low-front")
	await shot(cam,npc.global_position+Vector3(-1.7,1.75,1.3),npc.global_position+Vector3(-.35,.95,0),58,"sheriff-full-low")
	var hl2:Vector3=(body.skeleton.global_transform*body.skeleton.get_bone_global_pose(body.bone_ids["hand_l"])).origin
	await shot(cam,hl2+Vector3(-.4,.25,.45),hl2,40,"sheriff-left")
	quit()
