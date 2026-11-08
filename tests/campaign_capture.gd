extends SceneTree
var world:Node3D
var folder:String
func _initialize() -> void: call_deferred("run")
func shot(name:String) -> void:
	await create_timer(0.6,true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../../work")
	world=load("res://world/zona1_rifugio/zombix.tscn").instantiate();root.add_child(world)
	world.automated=true;world.set_process_unhandled_input(false)
	root.get_node("Session").launch()
	await create_timer(0.3,true).timeout
	for enemy in world.targets: enemy.set_physics_process(false);enemy.hide()
	world.player.set_physics_process(false);world.player.rig.set_physics_process(false)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true
	camera.position=Vector3(-3,2.3,4);camera.look_at(Vector3(-3,0.85,1))
	camera.current=true
	await shot("campaign-archery")
	for i in range(3):
		var actor:CharacterBody3D=load("res://player/player.tscn").instantiate();actor.local_control=false
		world.add_child(actor);actor.position=Vector3(-1+i*2,0,0);actor.set_physics_process(false)
		actor.rig.set_physics_process(false);actor.rig.camera.current=false
		world._dress(actor,i)
		if i==0: actor.velocity=Vector3(0,0,4)
		elif i==1: actor.set_meta("repair_until",Time.get_ticks_msec()+100000)
		else: actor.seated=true
	camera.current=true;camera.position=Vector3(6,2.4,5);camera.look_at(Vector3(1,1,0))
	await shot("campaign-animations")
	world.expedition.collected=[true,true,true];world.expedition.stage=2;world.expedition.unlocked=1
	world.expedition.car.repaired=true;world.player.position=world.expedition.car.position+Vector3(2,0.2,0)
	world.expedition.car.interact(1)
	world.expedition.car.set_physics_process(false)
	world.expedition.car.speed=0;world.expedition.car._place_occupants()
	world.player.rig.set_physics_process(true);world.player.rig.camera.current=true
	await shot("campaign-driving")
	for node in world.get_node("Interface").get_children():
		if node.get_script() and node.get_script().resource_path=="res://ui/route_gps.gd": node.opened=true
	await shot("campaign-gps")
	world.queue_free();await process_frame;await process_frame;quit()
