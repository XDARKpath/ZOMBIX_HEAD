extends SceneTree
# Zona 1 allargata: luoghi riservati (villaggio, dungeon), incroci e prato ondulato.
const RoadNet = preload("res://world/zona1_rifugio/roadnet.gd")
func _initialize():call_deferred("run")

func shot(cam:Camera3D,world:Node3D,from:Vector3,at:Vector3,fov:float,name:String) -> void:
	world.player.position=Vector3(at.x,at.y+0.5,at.z)
	world.terrain.ensure_near([at])
	cam.fov=fov
	cam.global_position=from
	cam.look_at(at)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/zone1map-%s.png"%name))

func run():
	var world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated=true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	world.player.set_physics_process(false)
	world.player.rig.set_physics_process(false)
	world.get_node("Interface").hide()
	var cam:=Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	# La nebbia della Zona 1 copre tutto dall'alto: per queste foto la spengo.
	var env:WorldEnvironment=world.find_children("*","WorldEnvironment",true,false)[0]
	env.environment.fog_enabled=false
	env.environment.volumetric_fog_enabled=false
	cam.far=1500
	var h=func(p:Vector3)->Vector3: return Vector3(p.x,world.terrain.height(p.x,p.z),p.z)
	await shot(cam,world,Vector3(-10,260,-110),Vector3(-10,0,-140),70,"overview")
	for key in RoadNet.SITES:
		var s:Vector3=h.call(RoadNet.SITES[key])
		await shot(cam,world,s+Vector3(55,38,55),s,55,"site-"+key)
	var j:Array=RoadNet.junctions()
	print("junctions ",j.size())
	for i in range(mini(3,j.size())):
		var p:Vector3=h.call(j[i])
		await shot(cam,world,p+Vector3(9,11,9),p,60,"junction-%d"%i)
	var v:Vector3=h.call(Vector3(68,0,-202.5))
	await shot(cam,world,v+Vector3(10,12,10),v,60,"junction-village")
	await shot(cam,world,h.call(Vector3(40,0,-95))+Vector3(0,2.2,0),h.call(Vector3(70,0,-140)),70,"meadow")
	var lo:=INF;var hi:=-INF
	for x in range(-150,150,6):
		for z in range(-200,-60,6):
			var y:float=world.terrain.height(x,z)
			if absf(x)<90 and z>-155: lo=minf(lo,y);hi=maxf(hi,y)
	print("zone1 meadow height range ",lo," .. ",hi)
	quit()
