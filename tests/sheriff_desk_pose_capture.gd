extends SceneTree
func _initialize():call_deferred("run")
func run():
 var world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
 root.add_child(world)
 await create_timer(.5).timeout
 world.get_node("Interface").hide()
 var npc=world.survival.sheriff_node
 var cam:=Camera3D.new()
 world.add_child(cam)
 cam.global_position=npc.global_position+Vector3(-1.7,1.75,1.3)
 cam.look_at(npc.global_position+Vector3(-.35,.95,0))
 cam.fov=58
 cam.current=true
 await create_timer(.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/sheriff-desk-crossed.png"))
 quit()
