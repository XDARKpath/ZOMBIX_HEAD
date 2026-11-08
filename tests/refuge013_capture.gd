extends SceneTree
var world:Node3D
var camera:Camera3D
var folder:String
func _initialize() -> void: call_deferred("run")
func shot(filename:String,at:Vector3,target:Vector3,fov:float=65) -> void:
	camera.position=at;camera.look_at(target);camera.fov=fov;camera.current=true
	await create_timer(0.5,true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+filename+".png")
	print("PHOTO ",filename)
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../ZOMBIX-HEAD-0.13-Foto")
	DirAccess.make_dir_recursive_absolute(folder)
	world=load("res://world/zona1_rifugio/zombix.tscn").instantiate();root.add_child(world)
	world.automated=true;world.set_process_unhandled_input(false)
	root.get_node("Session").launch();await create_timer(0.3,true).timeout
	world.player.set_physics_process(false);world.player.controls_enabled=false;world.player.rig.set_physics_process(false)
	world.expedition.car.set_physics_process(false)
	world.get_node("Interface").hide()
	for enemy in world.targets: enemy.set_physics_process(false);enemy.velocity=Vector3.ZERO
	camera=Camera3D.new();world.add_child(camera);camera.current=true;camera.near=0.08;camera.far=900
	await shot("01-panorama",Vector3(43,25,24),Vector3(0,0.8,-22),65)
	await shot("02-officina",Vector3(15,2.1,-12),Vector3(20,1.9,-23.5),73)
	await shot("03-casa",Vector3(-14.8,1.7,-8.6),Vector3(-17.0,1.0,-15.5),78)
	await shot("04-deposito",Vector3(-3.5,2.1,-36.2),Vector3(-12,1,-44),65)
	await shot("06-batteria",Vector3(-14.3,1.7,-13.8),Vector3(-17.5,1.1,-15.6),65)
	var enemy:Node3D=world.targets[0]
	enemy.position=Vector3(10,0,-13);enemy.rotation.y=PI;enemy.state=2;enemy.attack_clock=0.48
	await shot("05-zombie",Vector3(10.8,1.7,-10.2),Vector3(10,1,-13),65)
	world.queue_free();await process_frame;await process_frame;quit()
