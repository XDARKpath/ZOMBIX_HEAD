extends SceneTree
var world:Node3D
var camera:Camera3D
var folder:String
func _initialize():call_deferred("run")
func shot(name:String,at:Vector3,target:Vector3):
	camera.global_position=at;camera.look_at(target);camera.current=true
	await create_timer(0.35).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png");print("PHOTO ",name)
func run():
	folder=ProjectSettings.globalize_path("res://../ZOMBIX-HEAD-0.14-Foto");DirAccess.make_dir_recursive_absolute(folder)
	world=load("res://world/zona1_rifugio/zombix.tscn").instantiate();root.add_child(world);world.automated=true
	root.get_node("Session").launch();await create_timer(0.2).timeout
	world.player.set_physics_process(false);world.player.rig.set_physics_process(false);world.player.controls_enabled=false;world.expedition.car.set_physics_process(false)
	world.get_node("Interface").hide()
	for e in world.targets:e.set_physics_process(false);e.velocity=Vector3.ZERO
	camera=Camera3D.new();world.add_child(camera);camera.fov=66;camera.far=1500
	await shot("01-area",Vector3(110,70,70),Vector3(5,0,-50))
	await shot("02-sceriffo",Vector3(45,2,19),Vector3(44,1,-1))
	var e=world.targets[0];e.position=Vector3(3,0,-18);e.rotation.y=PI;e.state=1;e.velocity=Vector3(0,0,0.8)
	var c=world.targets[1];c.position=Vector3(5,0,-18);c.rotation.y=PI;c.crawling=true;c.velocity=Vector3(0,0,0.5)
	var b=world.targets[2];b.position=Vector3(7,0,-18);b.rotation.y=PI+0.55;b.set_kind(2);b.state=2;b.attack_clock=0.6
	await shot("03-infetti",Vector3(12,1.9,-13.4),Vector3(4.8,0.9,-18))
	e.receive_hit("neck",20,Vector3.ZERO,"axe",true);e.death_clock=1.5
	await shot("04-testa",Vector3(3.5,1.6,-15.3),Vector3(3,0.4,-18))
	world.player.position=Vector3(8,0.1,-11);world.player.rig.yaw=0;world.player.rig.pitch=-0.05;world.player.rig.reset_follow();world.player.rig.camera.current=true
	for weapon in ["axe","knife","pistol"]:
		world.player.equipped=weapon;world.player.owned.assign(["axe","knife","pistol"])
		await create_timer(0.4).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/fps-"+weapon+".png")
	world.player.equipped="axe";world.player.owned.assign(["axe","knife","pistol"])
	world.player.melee.perform_attack(true)
	for step in [[0.16,"fps-windup"],[0.09,"fps-strike"],[0.10,"fps-swing"]]:
		await create_timer(step[0]).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/"+step[1]+".png")
	var p:Vector3=world.roadblocks.points[0];world.terrain.ensure_near([p])
	await shot("05-strada",p+Vector3(18,15,22),p)
	await shot("06-lago",Vector3(14,2.2,17),Vector3(-4,-0.2,46))
	var bend:Vector3=preload("res://world/campaign/route.gd").road_points()[2]
	world.terrain.ensure_near([bend])
	await create_timer(0.6).timeout
	await shot("07-curva",bend+Vector3(-26,12,18),bend+Vector3(10,0,-30))
	world.queue_free();await process_frame;await process_frame;quit()

