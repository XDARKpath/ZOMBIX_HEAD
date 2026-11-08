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
 var avatar=npc.get_node("SheriffBody")
 avatar.set_process(false)
 var grip:Vector3=avatar.cigarette.global_position
 cam.global_position=grip+Vector3(-.28,.10,.35)
 cam.look_at(grip)
 cam.fov=40
 cam.current=true
 await create_timer(.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/sheriff-cigar-grip.png"))
 quit()

