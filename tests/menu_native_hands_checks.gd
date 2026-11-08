extends SceneTree
func _initialize():call_deferred("run")
func run():
 var world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
 root.add_child(world)
 await create_timer(0.3).timeout
 var source=load("res://art/survivor_operative/SM_Survivor_Operative.glb").instantiate()
 var original: MeshInstance3D=source.find_child("SM_Survivor_Body",true,false)
 var checks:=0
 for avatar in world.camp.avatars:
  avatar.set_process(false)
  assert(avatar.find_children("SourceHand_*","",true,false).is_empty())
  assert(avatar.get_child(0).find_children("*","Skeleton3D",true,false).size()==1)
  var mesh: MeshInstance3D=avatar.find_child("SM_Survivor_Body",true,false)
  assert(mesh.mesh==original.mesh,"Camp must retain the unmodified source body and hands")
  for clock in [0.0,2.5,5.0,8.0,11.0,13.9]:
   avatar.clock=clock
   avatar._pose(0)
   for side in ["l","r"]:
    for name in ["hand_","index_01_","middle_02_","thumb_03_"]:
     var id: int=avatar.bone_ids[name+side]
     assert(avatar.skeleton.get_bone_global_pose(id).is_finite())
   for prop in [avatar.sidearm,avatar.cigarette,avatar.sniper,avatar.katana,avatar.spit]:
    if prop:assert(prop.global_transform.is_finite())
   checks+=1
  print("PASS intact source hands, single skeleton, six animation phases: ",avatar.activity)
 source.free()
 print("PASS ",checks," camp poses; no replacement hands or mesh trimming")
 quit()

