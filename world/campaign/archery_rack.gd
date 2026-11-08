extends Node3D
const Props=preload("res://ui/camp/camp_props.gd")
func build() -> void:
	position=Vector3(-3,0,1)
	Props.box(self,Vector3(0,0.8,0),Vector3(3.8,0.12,1.2),Color("594d38"))
	for x in [-1.6,1.6]:
		for z in [-0.4,0.4]: Props.box(self,Vector3(x,0.4,z),Vector3(0.1,0.8,0.1),Color("383e32"))
	# Armi bianche rimosse (licenza POLYGON): il rastrelliera resta come arredo.
	for i in range(3):
		Props.box(self,Vector3(-1.3+i*1.3,0.99,-0.2),Vector3(0.06,0.90,0.06),Color("3a3a30"))
	var body:=StaticBody3D.new();add_child(body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3.8,0.9,1.2)
	shape.shape=box;shape.position.y=0.45;body.add_child(shape)
