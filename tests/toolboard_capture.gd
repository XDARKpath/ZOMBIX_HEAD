extends SceneTree
func _initialize():call_deferred("run")
func run():
 var world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
 root.add_child(world)
 await create_timer(.4).timeout
 world.get_node("Interface").hide()
 var armory=world.landscape.get_node("RefugeBuildings/Armory")
 var cam=Camera3D.new()
 armory.add_child(cam)
 cam.position=Vector3(2.1,1.7,4.3)
 cam.look_at(armory.to_global(Vector3(1.9,1.35,1.25)))
 cam.fov=62
 cam.current=true
 await create_timer(.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/armory-toolboard.png"))
 quit()
