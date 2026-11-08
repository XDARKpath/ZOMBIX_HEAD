extends SceneTree
var world:Node3D
var camera:Camera3D
var folder:String
func _initialize():call_deferred("run")
func shot(name:String,at:Vector3,target:Vector3,fov:float=65.0):
	camera.global_position=at;camera.look_at(target);camera.fov=fov;camera.current=true
	await create_timer(0.35).timeout;await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image();img.resize(1000,int(1000.0*img.get_height()/img.get_width()),Image.INTERPOLATE_BILINEAR);img.save_png(folder+"/"+name+".png");print("PHOTO ",name)
func player_shot(name:String,at:Vector3,yaw:float,pitch:float=-0.05):
	world.player.reset_at(at);world.player.rig.yaw=yaw;world.player.rig.pitch=pitch;world.player.rig.reset_follow()
	world.player.rig.camera.current=true
	await create_timer(0.6).timeout;await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image();img.resize(1000,int(1000.0*img.get_height()/img.get_width()),Image.INTERPOLATE_BILINEAR);img.save_png(folder+"/"+name+".png");print("PHOTO ",name)
func run():
	folder=ProjectSettings.globalize_path("res://../ZOMBIX-HEAD-0.16-Foto");DirAccess.make_dir_recursive_absolute(folder)
	world=load("res://world/zona1_rifugio/zombix.tscn").instantiate();root.add_child(world);world.automated=true
	root.get_node("Session").launch();await create_timer(0.3).timeout
	world.player.set_physics_process(false);world.player.rig.set_physics_process(false);world.player.controls_enabled=false;world.expedition.car.set_physics_process(false)
	world.get_node("Interface").hide()
	for e in world.targets:e.set_physics_process(false);e.velocity=Vector3.ZERO
	camera=Camera3D.new();world.add_child(camera);camera.fov=66;camera.far=1500;camera.near=0.08
	await shot("01-aerial",Vector3(95,70,50),Vector3(2,0,-45))
	await shot("02-street",Vector3(6,2.2,12),Vector3(6,1.2,-40))
	await shot("03-sheriff",Vector3(11.2,1.55,-8.6),Vector3(13.0,1.15,-10.2),62)
	await shot("04-shop",Vector3(1.4,1.9,-25.6),Vector3(-6.8,1.3,-28.1),62)
	# Per le foto degli edifici il 4×4 non deve coprire la facciata.
	# Camera spostata verso nord: il bagagliaio e il portapacchi restano fuori campo.
	world.expedition.car.visible=false
	await shot("21-sheriff-esterno",Vector3(3.2,2.8,-14.0),Vector3(11.4,1.9,-8.0),58)
	await shot("22-armory-esterno",Vector3(8.5,2.7,-19.5),Vector3(0.6,1.9,-29.6),58)
	world.expedition.car.visible=true
	await shot("05-row",Vector3(-3,2.0,-22),Vector3(8,1.2,-40))
	await shot("06-porch",Vector3(10.5,1.7,-7.5),Vector3(13.6,1.3,-9.4))
	await shot("07-north",Vector3(6,2.2,-42),Vector3(6,1.2,-70))
	await shot("08-deal",Vector3(10.6,1.6,-9.2),Vector3(13.1,1.25,-10.25),72)
	world.get_node("Interface").show();world.player.set_physics_process(true)
	await player_shot("09-hud-sheriff",Vector3(10.2,0.1,-7.2),-0.66)
	await player_shot("10-hud-street",Vector3(6,0.1,6),0.0)
	var layout:=preload("res://world/zona1_rifugio/refuge_layout.gd")
	# Primo incontro con lo sceriffo: seduto, sigaretta, dialogo aperto.
	world.player.reset_at(layout.SHERIFF_NPC+Vector3(-2.8,0.1,0.4));world.player.rig.yaw=-PI/2;world.player.rig.pitch=-0.10;world.player.rig.reset_follow()
	world.survival.seen_intro=false
	world.survival.open_sheriff_dialogue();world.survival.advance_sheriff_dialogue()
	await create_timer(0.5).timeout;await RenderingServer.frame_post_draw
	var dialogue_img:=root.get_texture().get_image();dialogue_img.resize(1000,int(1000.0*dialogue_img.get_height()/dialogue_img.get_width()),Image.INTERPOLATE_BILINEAR)
	dialogue_img.save_png(folder+"/19-sheriff-dialogo.png");print("PHOTO 19-sheriff-dialogo")
	world.survival.close_sheriff_dialogue()
	await shot("13-tower",Vector3(-13,2.4,-37),Vector3(-24,5.6,-52))
	await shot("14-town-west",Vector3(-11,2.0,-14),Vector3(-18,4.0,-20))
	await shot("15-town-east",Vector3(21,2.0,-38),Vector3(28,4.0,-44))
	await player_shot("16-boss-capomacello",Vector3(16,0.1,-48),PI)
	await player_shot("17-boss-mago",Vector3(-16,0.1,-63),PI)
	# Ascia caricata: si vede tutto il braccio destro, non solo la mano.
	world.player.equipped="axe"
	world.player.reset_at(Vector3(6,0.1,-18));world.player.rig.yaw=0.15;world.player.rig.pitch=-0.02;world.player.rig.reset_follow()
	world.player.melee.perform_attack(true)
	await create_timer(0.30).timeout;await RenderingServer.frame_post_draw
	var arm_img:=root.get_texture().get_image();arm_img.resize(1000,int(1000.0*arm_img.get_height()/arm_img.get_width()),Image.INTERPOLATE_BILINEAR)
	arm_img.save_png(folder+"/20-ascia-braccio.png");print("PHOTO 20-ascia-braccio")
	await player_shot("18-boss-teste",Vector3(6,0.1,-104),PI)
	await player_shot("11-shop-view",layout.SHOP_NPC+Vector3(1.6,0.1,0.3),PI/2)
	world.survival.open_shop()
	await create_timer(0.5).timeout;await RenderingServer.frame_post_draw
	var panel_img:=root.get_texture().get_image();panel_img.resize(1000,int(1000.0*panel_img.get_height()/panel_img.get_width()),Image.INTERPOLATE_BILINEAR)
	panel_img.save_png(folder+"/12-shop-ui.png");print("PHOTO 12-shop-ui")
	world.queue_free();await process_frame;await process_frame;quit()
