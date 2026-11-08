extends SceneTree
func _initialize():call_deferred("run")
func run():
 var model=load("res://art/survivor_operative/SM_Survivor_Operative.glb").instantiate()
 model.build_animation_tree=false
 root.add_child(model)
 var animation: AnimationPlayer=model.find_child("AnimationPlayer",true,false)
 var count:=0
 for clip in animation.get_animation_list():
  if not clip.begins_with("Player_"):continue
  var resource:=animation.get_animation(clip)
  assert(resource.length>0)
  animation.play(clip)
  for fraction in [0.0,0.25,0.5,0.75,0.99]:
   animation.seek(resource.length*fraction,true)
   for skeleton in model.find_children("*","Skeleton3D",true,false):
    skeleton.force_update_all_bone_transforms()
    for bone in skeleton.get_bone_count():assert(skeleton.get_bone_global_pose(bone).is_finite())
  count+=1
  print("PASS ",clip)
 assert(count==23)
 for id in ["axe"]:
  var tool=preload("res://art/weapons/hand_tools.gd").make(id)
  var bounds: AABB=tool.get_child(0).get_aabb()
  assert(bounds.size.y<1.1 and bounds.size.y>0.5)
  print("PASS tool bounds ",id," ",bounds)
  tool.free()
 print("PASS all 23 source clips / 5 sampled poses each")
 quit()
