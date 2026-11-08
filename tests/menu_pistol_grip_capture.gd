extends SceneTree
func _initialize():call_deferred("run")
func run():
 var world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
 root.add_child(world)
 await create_timer(0.3).timeout
 world.get_node("Interface").hide()
 var avatar=world.camp.avatars[0]
 avatar.set_process(false)
 avatar.clock=0
 avatar._pose(0)
 var cam:=Camera3D.new()
 world.add_child(cam)
 cam.current=true
 cam.fov=42
 var at:Vector3=avatar._bone_frame("hand_l").origin
 var lamp:=DirectionalLight3D.new()
 world.add_child(lamp)
 lamp.light_energy=1.6
 lamp.shadow_enabled=false
 lamp.look_at_from_position(at+avatar.global_basis*Vector3(1.2,2.0,2.0),at,Vector3.UP)
 var offsets=[Vector3(0.55,0.25,0.85),Vector3(0.9,0.15,0.25),Vector3(0.1,0.25,1.0),Vector3(0.45,-0.05,0.9)]
 for side in range(4):
  cam.global_position=at+avatar.global_basis*offsets[side]
  cam.look_at(at+avatar.global_basis*Vector3(0,-0.05,0))
  await create_timer(0.25).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/menu-pistol-grip-%d.png"%side))
 cam.fov=35
 cam.global_position=at+avatar.global_basis*Vector3(0.3,0.18,0.55)
 cam.look_at(at+avatar.global_basis*Vector3(0,-0.05,0))
 await create_timer(0.25).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/menu-pistol-grip-close.png"))
 quit()
