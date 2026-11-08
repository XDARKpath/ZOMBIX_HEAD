extends RefCounted
static func model(id: String, span: float, axis: int = 1) -> Node3D:
 var root:=Node3D.new()
 var mesh_root: Node3D=load("res://art/menu_kenney/"+id+".glb").instantiate()
 root.add_child(mesh_root)
 var bounds:=AABB()
 var first:=true
 for mesh in mesh_root.find_children("*","MeshInstance3D",true,false):
  var xf: Transform3D=mesh.transform
  var parent: Node3D=mesh.get_parent()
  while parent!=root:
   xf=parent.transform*xf
   parent=parent.get_parent()
  var box: AABB=xf*mesh.get_aabb()
  bounds=box if first else bounds.merge(box)
  first=false
 var factor:=span/maxf(bounds.size[axis],0.001)
 mesh_root.scale*=factor
 mesh_root.position=-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
 return root
static func place(parent: Node3D,id: String,at: Vector3,span: float,yaw: float=0.0,axis: int=1) -> Node3D:
 var node:=model(id,span,axis)
 node.name=id.to_pascal_case()
 parent.add_child(node)
 node.position=at
 node.rotation.y=yaw
 return node
static func supplies(parent: Node3D) -> void:
 place(parent,"tent-detailedopen",Vector3(0.0,0,-3.9),2.9,0.12,0)
 place(parent,"crate",Vector3(3.5,0,-1.5),0.65,-0.12)
 place(parent,"crate",Vector3(3.55,0.65,-1.5),0.40,0.10)
 place(parent,"crate",Vector3(4.25,0,-1.65),0.5,0.15)
 for i in range(4):
  var log:=place(parent,"log",Vector3(2.9,0.09+(i/2)*0.16,-2.7+(i%2)*0.22),0.8,PI/2,2)
 for i in range(9):
  place(parent,"plant-bush",Vector3(-5.5+i*1.45,0,-4.8-sin(i*1.7)),0.45+0.12*(i%3),i*0.7)
 place(parent,"rock-largea",Vector3(4.8,0,-2.7),0.65,0.3)
 var rifle: Node3D=load("res://art/menu_batch2/SM_Wep_AssaultRifle.glb").instantiate()
 parent.add_child(rifle)
 rifle.position=Vector3(3.4,0.74,-1.4)
 rifle.rotation=Vector3(PI/2,0.3,PI/2)
static func weapon(kind: String) -> Node3D:
 var root:=Node3D.new()
 var file: String={"pistol":"Pistol","sniper":"SniperRifle","katana":"Katana"}[kind]
 var model: Node3D=load("res://art/menu_batch2/SM_Wep_"+file+".glb").instantiate()
 root.add_child(model)
 model.rotation.y=-PI/2
 if kind=="katana":model.rotation=Vector3(0,0,-PI/2)
 var sockets: Dictionary
 if kind=="pistol":sockets={"GripMain":Vector3(-0.025,-0.045,0)}
 elif kind=="sniper":sockets={"GripMain":Vector3.ZERO,"GripSupport":Vector3(0.32,0.01,0),"CleaningSurface":Vector3(-0.12,0.07,0)}
 else:sockets={"GripMain":Vector3.ZERO,"InspectionSupport":Vector3(0.34,0,0)}
 for key in sockets:
  var marker:=Marker3D.new()
  marker.name=key
  marker.position=sockets[key]
  root.add_child(marker)
 return root
