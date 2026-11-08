extends RefCounted
static func make(id: String) -> Node3D:
 var root := Node3D.new()
 var source: Node3D = load("res://art/zx_fp/"+("SM_FP_Shovel.glb" if id=="spade" else "SM_FP_Axe.glb")).instantiate()
 var records: Array=[]
 var bounds := AABB()
 var first := true
 for mesh in source.find_children("*","MeshInstance3D",true,false):
  var xf: Transform3D=mesh.transform
  var parent: Node3D=mesh.get_parent()
  while parent!=null:
   xf=parent.transform*xf
   parent=parent.get_parent()
  for surface in mesh.mesh.get_surface_count():
   var arrays: Array=mesh.mesh.surface_get_arrays(surface)
   var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   for i in points.size():
    points[i]=xf*points[i]
    if first:bounds=AABB(points[i],Vector3.ZERO);first=false
    else:bounds=bounds.expand(points[i])
    if not normals.is_empty():normals[i]=(xf.basis.inverse().transposed()*normals[i]).normalized()
   arrays[Mesh.ARRAY_VERTEX]=points
   arrays[Mesh.ARRAY_NORMAL]=normals
   arrays[Mesh.ARRAY_TANGENT]=null
   records.append(arrays)
 var axis:=bounds.size.max_axis_index()
 var orientation:=Basis.IDENTITY
 if axis==0:orientation=Basis(Vector3.BACK,PI/2)
 elif axis==2:orientation=Basis(Vector3.RIGHT,-PI/2)
 var rotated: AABB=Transform3D(orientation,Vector3.ZERO)*bounds
 var factor: float=(1.0 if id=="spade" else 0.62)/rotated.size.y
 var center:=Vector3(rotated.get_center().x,rotated.position.y+rotated.size.y*0.22,rotated.get_center().z)
 var result:=ArrayMesh.new()
 for arrays in records:
  var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  for i in points.size():
   points[i]=(orientation*points[i]-center)*factor
   if not normals.is_empty():normals[i]=orientation*normals[i]
  arrays[Mesh.ARRAY_VERTEX]=points
  arrays[Mesh.ARRAY_NORMAL]=normals
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var view:=MeshInstance3D.new()
 view.mesh=result
 var material:=ShaderMaterial.new()
 material.shader=preload("res://art/weapons/tool_material.gdshader")
 material.set_shader_parameter("head_height",0.30 if id=="axe" else 0.55)
 view.material_override=material
 root.add_child(view)
 # Destra sotto la testa, sinistra alla base del manico.
 if id=="spade":preload("res://art/weapons/grip_sockets.gd").shaft(root,result,0.20,-0.17)
 else:preload("res://art/weapons/grip_sockets.gd").shaft(root,result,0.22,-0.10)
 source.free()
 return root

