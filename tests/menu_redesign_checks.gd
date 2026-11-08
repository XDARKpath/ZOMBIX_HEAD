extends SceneTree
func _initialize():call_deferred("run")
func run():
 var world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
 root.add_child(world)
 world.automated=true
 await create_timer(0.4).timeout
 world.menu.home()
 assert(world.menu.entries.size()<=6)
 assert(not world.menu.get_node("BuildBadge").visible)
 assert(not world.menu.get_node("CoopBadge").visible)
 assert(world.menu.roster_label.text.is_empty())
 world.menu.network_menu()
 assert(world.menu.entries.size()==3)
 world.menu.options_menu()
 assert(world.menu.entries.size()==3)
 world.menu.home()
 for avatar in world.camp.avatars:
  assert(avatar.find_children("SourceHand_*","",true,false).is_empty())
  var visible_skins:=0
  for mesh in avatar.find_children("Skin_*","MeshInstance3D",true,false):
   if mesh.visible:visible_skins+=1
  assert(visible_skins==1)
  for clock in [0.0,3.0,6.0,10.0,13.5]:
   avatar.clock=clock
   avatar._pose(0)
   for side in ["l","r"]:assert(avatar._bone_frame("hand_"+side).is_finite())
 print("PASS menu home, multiplayer/options navigation, four Batch2 skins, native hands and poses")
 await create_timer(1.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/menu-redesign.png"))
 quit()
