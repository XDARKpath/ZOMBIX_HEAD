extends SceneTree
func _initialize():
 var model: Node3D=load("res://art/fp_arms/SM_FP_Arms.glb").instantiate()
 root.add_child(model)
 var sk: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
 print("skeleton path ",model.get_path_to(sk)," xf ",sk.global_transform)
 for i in sk.get_bone_count():
  var n:=sk.get_bone_name(i)
  if n.ends_with("_r") and (n.begins_with("hand") or n.begins_with("index") or n.begins_with("thumb") or n.begins_with("upper") or n.begins_with("lower")) or n=="root":
   var g:=sk.get_bone_global_rest(i)
   print(n," o=",g.origin.snapped(Vector3.ONE*0.001)," x=",g.basis.x.snapped(Vector3.ONE*0.01)," y=",g.basis.y.snapped(Vector3.ONE*0.01)," z=",g.basis.z.snapped(Vector3.ONE*0.01))
 for m in model.find_children("*","MeshInstance3D",true,false):
  for s in m.mesh.get_surface_count():print(m.name," surf ",s," ",m.mesh.surface_get_material(s).resource_name if m.mesh.surface_get_material(s) else "-")
 quit()
