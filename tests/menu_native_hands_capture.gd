extends SceneTree
var world: Node3D
func _initialize():call_deferred("run")
func run():
 world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
 root.add_child(world)
 await create_timer(0.5).timeout
 world.get_node("Interface").hide()
 var cam:=Camera3D.new()
 world.add_child(cam)
 cam.current=true
 cam.fov=38
 for avatar in world.camp.avatars:
  assert(avatar.find_children("SourceHand_*","",true,false).is_empty())
  assert(avatar.find_children("HandRig","Skeleton3D",true,false).is_empty())
  var at: Vector3=avatar.global_position+Vector3(0,1.1,0)
  cam.global_position=at+avatar.global_basis*Vector3(0,0.15,2.2)
  cam.look_at(at)
  await create_timer(0.5).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/menu-native-hands-%d.png"%avatar.stance))
  print("PASS native hands only: ",avatar.activity)
 quit()
