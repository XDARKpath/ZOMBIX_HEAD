extends RefCounted
static func material(color: String, metallic: float = 0.0, roughness: float = 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=Color(color)
	m.metallic=metallic
	m.roughness=roughness
	return m
static func part(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh=mesh
	view.position=at
	view.material_override=mat
	parent.add_child(view)
	return view
static func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=size
	return part(parent,mesh,at,mat)
static func tube(parent: Node3D, a: Vector3, b: Vector3, radius_a: float, radius_b: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius=radius_a
	mesh.top_radius=radius_b
	mesh.height=a.distance_to(b)
	mesh.radial_segments=24
	var node := part(parent,mesh,(a+b)*0.5,mat)
	node.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return node
