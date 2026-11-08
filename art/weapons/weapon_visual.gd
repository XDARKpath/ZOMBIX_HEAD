# Reusable weapon scenes: metre scale, +X muzzle/blade, named gameplay sockets.
extends Node3D
const Geo := preload("res://art/weapons/weapon_geometry.gd")
@export_enum("Sniper","Katana") var weapon_kind: int = 0
var weapon_skeleton: Skeleton3D
func _ready() -> void:
	if weapon_kind==0: _sniper()
	else: _katana()

func _socket(label: String, at: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name=label
	marker.position=at
	add_child(marker)

func _sniper() -> void:
	var model: Node3D=preload("res://art/weapons/imported/sniper_rifle.glb").instantiate()
	model.name="RifleModel"
	model.rotation.y=-PI/2
	model.scale=Vector3.ONE*1.15
	add_child(model)
	_style_rifle(model)
	var scope := Node3D.new()
	scope.name="Scope"
	add_child(scope)
	var steel := Geo.material("30393c",0.72,0.34)
	var dark := Geo.material("171e22",0.55,0.43)
	var glass := Geo.material("32586a",0.75,0.12)
	for x in [-0.10,0.10]:
		Geo.box(scope,Vector3(x,0.085,0),Vector3(0.026,0.065,0.045),steel)
		Geo.tube(scope,Vector3(x-0.012,0.145,0),Vector3(x+0.012,0.145,0),0.031,0.031,steel)
	Geo.tube(scope,Vector3(-0.22,0.145,0),Vector3(0.15,0.145,0),0.025,0.025,dark)
	Geo.tube(scope,Vector3(0.15,0.145,0),Vector3(0.23,0.145,0),0.025,0.044,dark)
	Geo.tube(scope,Vector3(0.23,0.145,0),Vector3(0.28,0.145,0),0.044,0.044,steel)
	Geo.tube(scope,Vector3(0.280,0.145,0),Vector3(0.282,0.145,0),0.037,0.037,glass)
	Geo.tube(scope,Vector3(-0.27,0.145,0),Vector3(-0.22,0.145,0),0.034,0.030,dark)
	Geo.tube(scope,Vector3(-0.272,0.145,0),Vector3(-0.270,0.145,0),0.027,0.027,glass)
	Geo.tube(scope,Vector3(0,0.155,0),Vector3(0,0.197,0),0.022,0.022,steel)
	Geo.tube(scope,Vector3(0,0.145,0.015),Vector3(0,0.145,0.040),0.018,0.018,steel)
	for i in range(5):
		var x := -0.23+float(i)*0.009
		Geo.tube(scope,Vector3(x,0.145,0),Vector3(x+0.003,0.145,0),0.029,0.029,steel)
	_socket("Muzzle",Vector3(0.626,0.018,0))
	_socket("GripMain",Vector3(-0.15,-0.065,0))
	_socket("GripSupport",Vector3(0.21,-0.030,0))
	_socket("Sight",Vector3(-0.28,0.145,0))
	_socket("CleaningSurface",Vector3(-0.34,0.040,0))
	_socket("Magazine",Vector3(-0.008,-0.075,0))
	_socket("EjectionPort",Vector3(0.02,0.03,0.035))

func _style_rifle(node: Node) -> void:
	if node is Skeleton3D: weapon_skeleton=node
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var source: Material=node.mesh.surface_get_material(i)
			var name_lower := source.resource_name.to_lower()
			var mat := Geo.material("38423c",0.45,0.55)
			if "brown" in name_lower: mat=Geo.material("5c6049",0.05,0.85)
			elif "brass" in name_lower: mat=Geo.material("aaa18b",0.8,0.34)
			elif "white" in name_lower: mat=Geo.material("889496",0.8,0.3)
			elif "black" in name_lower: mat=Geo.material("202829",0.4,0.58)
			node.set_surface_override_material(i,mat)
	for child in node.get_children():_style_rifle(child)

func _katana() -> void:
	var model: Node3D=preload("res://art/weapons/imported/katana.tscn").instantiate()
	model.name="KatanaModel"
	model.basis=Basis(Vector3.RIGHT,PI/2)*Basis(Vector3.BACK,-PI/2)
	model.scale=Vector3.ONE*0.065
	model.position.x=-0.26
	add_child(model)
	_style_katana(model)
	var fabric := Geo.material("202c2b",0.0,0.92)
	var brass := Geo.material("8c784e",0.78,0.4)
	# Two crossing fabric ribbons leave the traditional diamond-shaped openings.
	for winding in [-1.0,1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(180):
			var t0 := float(i)/180
			var t1 := float(i+1)/180
			var a0: float = t0*TAU*7*winding
			var a1: float = t1*TAU*7*winding
			var p0 := Vector3(lerpf(-0.25,0.035,t0),cos(a0)*0.023,sin(a0)*0.020)
			var p1 := Vector3(lerpf(-0.25,0.035,t1),cos(a1)*0.023,sin(a1)*0.020)
			var width := Vector3(0.007,0,0)
			for p in [p0-width,p1-width,p1+width,p0-width,p1+width,p0+width]:st.add_vertex(p)
		st.generate_normals()
		var mat := fabric.duplicate()
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		Geo.part(self,st.commit(),Vector3.ZERO,mat)
	Geo.tube(self,Vector3(-0.270,0,0),Vector3(-0.252,0,0),0.023,0.023,brass)
	Geo.box(self,Vector3(0.066,0,0),Vector3(0.025,0.034,0.020),brass)
	_socket("GripMain",Vector3(-0.10,0,0))
	_socket("GripSupport",Vector3(-0.22,0,0))
	_socket("BladeBase",Vector3(0.08,0,0))
	_socket("BladeTip",Vector3(0.78,0.02,0))
	_socket("InspectionSupport",Vector3(0.33,-0.008,0))

func _style_katana(node: Node) -> void:
	if node is MeshInstance3D:
		var source: Mesh=node.mesh
		if node.name=="Cylinder_001":
			node.material_override=Geo.material("8c784e",0.8,0.38)
		else:
			var result := ArrayMesh.new()
			for s in source.get_surface_count():
				var arrays := source.surface_get_arrays(s)
				var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				# Refine the source blade: narrow section and an angled, tapered kissaki.
				for v in points.size():
					if points[v].z>0.048:
						var taper := clampf((points[v].z-0.145)/0.01588,0.0,1.0)
						points[v]=Vector3(points[v].x*(1.0-taper),lerpf(points[v].y*0.60,0.003,taper),points[v].z)
				arrays[Mesh.ARRAY_VERTEX]=points
				var ids: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				if ids.is_empty():
					for i in points.size():ids.append(i)
				for region in range(2):
					var selected := PackedInt32Array()
					for t in range(0,ids.size(),3):
						var z := (points[ids[t]].z+points[ids[t+1]].z+points[ids[t+2]].z)/3.0
						if (z>0.047)==(region==1):
							for k in range(3):selected.append(ids[t+k])
					if selected.is_empty():continue
					arrays[Mesh.ARRAY_INDEX]=selected
					result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},source.surface_get_format(s))
					result.surface_set_material(result.get_surface_count()-1,Geo.material("b4bdc2",0.86,0.27) if region==1 else Geo.material("877a5e",0.0,0.88))
			node.mesh=result
	for child in node.get_children():_style_katana(child)
