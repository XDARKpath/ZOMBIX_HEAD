extends SceneTree
func _initialize():call_deferred("run")
func run():
 var model=load("res://art/survivor_operative/SM_Survivor_Operative.glb").instantiate()
 model.build_animation_tree=false
 root.add_child(model)
 var anim=model.find_child("AnimationPlayer",true,false)
 anim.play("Player_Idle_Rifle")
 anim.advance(0.1)
 for skeleton in model.find_children("*","Skeleton3D",true,false):
  skeleton.force_update_all_bone_transforms()
  for b in ["upperarm_r","lowerarm_r","hand_r","weapon_r","upperarm_l","lowerarm_l","hand_l"]:
   print(b,": ",skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(b)))
 quit()
