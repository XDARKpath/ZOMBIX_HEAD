extends RefCounted
const Props=preload("res://ui/camp/camp_props.gd")
static func build(parent:Node3D,index:int) -> void:
	if index==0:
		Props.box(parent,Vector3(0,0.13,0),Vector3(0.38,0.26,0.24),Color("202b29"))
		Props.box(parent,Vector3(0,0.28,0),Vector3(0.4,0.04,0.26),Color("626b5a"))
		for x in [-0.12,0.12]: Props.cylinder(parent,Vector3(x,0.32,0),0.025,0.05,Color("c96844") if x>0 else Color("c0c4ac"),0.6)
		Props.box(parent,Vector3(0,0.34,0),Vector3(0.12,0.025,0.045),Color("bcc2a8"))
		var tag:=Label3D.new();tag.text="12V";tag.font_size=36;tag.pixel_size=0.003;tag.position=Vector3(0,0.14,0.125);parent.add_child(tag)
	elif index==1:
		var view:=MeshInstance3D.new();var mesh:=TorusMesh.new()
		mesh.inner_radius=0.14;mesh.outer_radius=0.18;mesh.rings=32;mesh.ring_segments=8
		view.mesh=mesh;view.material_override=Props.material(Color("202723"));view.position.y=0.035;parent.add_child(view)
		Props.box(parent,Vector3(0.08,0.09,0),Vector3(0.07,0.11,0.05),Color("bda575"))
	else:
		# Tanica procedurale: niente moduli esterni.
		Props.box(parent,Vector3(0,0.26,0),Vector3(0.28,0.52,0.18),Color("a33a2a"))
		Props.box(parent,Vector3(0,0.56,0),Vector3(0.10,0.07,0.06),Color("2a2c28"))
		Props.cylinder(parent,Vector3(0.12,0.52,0),0.02,0.10,Color("2a2c28"),0.4)
	var glow:=OmniLight3D.new();glow.position=Vector3(0,0.45,0);glow.light_color=Color("ffc477")
	glow.light_energy=0.32;glow.omni_range=1.2;parent.add_child(glow)
