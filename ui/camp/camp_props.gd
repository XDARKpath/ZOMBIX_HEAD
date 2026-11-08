# Oggetti originali del falò. La sola texture del fumo proviene dai demo Godot/Kenney.
extends RefCounted

static func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.64 if metal>0 else 0.9
	return mat

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	view.mesh = mesh
	view.material_override = material(color,metal)
	view.position = at
	parent.add_child(view)
	return view

static func rod(parent: Node3D, from: Vector3, to: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var view := cylinder(parent,(from+to)*0.5,radius,from.distance_to(to),color,0.4)
	view.quaternion = Quaternion(Vector3.UP,(to-from).normalized())
	return view

static func smoke(parent: Node3D, at: Vector3, size: float, alpha: float, count: int = 14) -> CPUParticles3D:
	var node := CPUParticles3D.new()
	node.name = "Smoke"
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	node.amount = count
	node.lifetime = 2.1
	node.preprocess = 0.0
	node.local_coords = false
	node.direction = Vector3(0.12,1,0)
	node.spread = 8
	node.gravity = Vector3(0.014,0.04,0)
	node.initial_velocity_min = 0.07
	node.initial_velocity_max = 0.11
	node.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	node.emission_sphere_radius = 0.012
	node.angle_min = -180
	node.angle_max = 180
	node.angular_velocity_min = -12
	node.angular_velocity_max = 12
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0,0.25))
	scale_curve.add_point(Vector2(0.35,0.7))
	scale_curve.add_point(Vector2(1,1.2))
	node.scale_amount_curve = scale_curve
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0.72,0.77,0.79,0))
	gradient.add_point(0.18,Color(0.72,0.77,0.79,alpha))
	gradient.add_point(0.55,Color(0.72,0.77,0.79,alpha*0.55))
	gradient.set_color(gradient.get_point_count()-1,Color(0.72,0.77,0.79,0))
	node.color_ramp = gradient
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE*size
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://ui/camp/smoke.gdshader")
	mat.set_shader_parameter("smoke_mask",preload("res://art/camp/smoke_05.png"))
	mesh.material = mat
	node.mesh = mesh
	parent.add_child(node)
	return node

static func cooking_station(parent: Node3D) -> Node3D:
	var station := Node3D.new()
	station.name = "CookingStation"
	station.position = Vector3(0,0,0.3)
	parent.add_child(station)
	for i in range(3):
		var angle := float(i)*TAU/3+0.2
		rod(station,Vector3(cos(angle)*0.66,0.05,sin(angle)*0.66),Vector3(0,1.6,0),0.013,Color("3b3931"))
	rod(station,Vector3(0,1.6,0),Vector3(0,1.05,0),0.006,Color("626158"))
	var pot := cylinder(station,Vector3(0,0.82,0),0.23,0.23,Color("292c2b"),0.7)
	pot.name = "IronPot"
	var soup := cylinder(station,Vector3(0,0.941,0),0.211,0.008,Color("72512e"))
	soup.name = "StewSurface"
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.212
	ring.outer_radius = 0.239
	ring.rings = 16
	ring.ring_segments = 8
	rim.mesh = ring
	rim.position.y = 0.935
	rim.material_override = material(Color("50514a"),0.65)
	station.add_child(rim)
	for side in [-1,1]:
		var handle := MeshInstance3D.new()
		handle.mesh = ring
		handle.scale = Vector3.ONE*0.35
		handle.position = Vector3(side*0.23,0.9,0)
		handle.rotation.z = PI/2
		handle.material_override = rim.material_override
		station.add_child(handle)
	var steam := smoke(station,Vector3(0,0.96,0),0.25,0.25,20)
	steam.name = "CookingSteam"
	return station

static func cigarette(parent: Node3D) -> Node3D:
	var prop := Node3D.new()
	prop.name = "Cigarette"
	parent.add_child(prop)
	var paper := cylinder(prop,Vector3.ZERO,0.007,0.095,Color("d0c7a9"))
	paper.rotation.x = PI/2
	var filter_tip := cylinder(prop,Vector3(0,0,-0.035),0.0071,0.025,Color("866444"))
	filter_tip.rotation.x = PI/2
	var ember := cylinder(prop,Vector3(0,0,0.049),0.0072,0.004,Color("ff641b"))
	ember.rotation.x = PI/2
	var mat := ember.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color("ff4812")
	mat.emission_energy_multiplier = 2
	smoke(prop,Vector3(0,0,0.052),0.12,0.16,18)
	return prop

static func stone(parent: Node3D) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = "Whetstone"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09,0.035,0.055)
	view.mesh = mesh
	view.material_override = material(Color("808b82"))
	parent.add_child(view)
	return view

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, metal: float = 0) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	view.position = at
	view.material_override = material(color,metal)
	parent.add_child(view)
	return view

static func katana(parent: Node3D) -> Node3D:
	var weapon: Node3D=load("res://art/weapons/katana.tscn").instantiate()
	parent.add_child(weapon)
	return weapon

static func pistol(parent: Node3D) -> Node3D:
	var prop := Node3D.new()
	prop.name = "Pistol"
	parent.add_child(prop)
	# Decorative unloaded sidearm; muzzle along local +X.
	box(prop,Vector3(0.045,0.08,0),Vector3(0.25,0.052,0.044),Color("6a7780"),0.85)
	box(prop,Vector3(0.035,0.05,0),Vector3(0.22,0.025,0.038),Color("20272b"),0.5)
	var grip := box(prop,Vector3(-0.035,-0.01,0),Vector3(0.055,0.12,0.043),Color("1b2225"))
	grip.rotation.z = -0.18
	for i in range(5): box(prop,Vector3(-0.065+i*0.008,0.082,0),Vector3(0.003,0.035,0.046),Color("2b343a"),0.5)
	var muzzle := cylinder(prop,Vector3(0.174,0.08,0),0.012,0.008,Color("101416"),0.5)
	muzzle.rotation.z = PI/2
	box(prop,Vector3(0.145,0.112,0),Vector3(0.014,0.013,0.012),Color("151b20"),0.5)
	box(prop,Vector3(0.03,-0.016,0),Vector3(0.065,0.009,0.018),Color("30393e"),0.6)
	box(prop,Vector3(0.063,0.008,0),Vector3(0.009,0.047,0.018),Color("30393e"),0.6)
	return prop

static func ellipsoid(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	node.mesh = mesh
	node.scale = size
	node.position = at
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func roast_chicken(parent: Node3D) -> Node3D:
	var chicken := Node3D.new()
	chicken.name = "RoastChicken"
	parent.add_child(chicken)
	var skin := Color("bb7538")
	ellipsoid(chicken,Vector3.ZERO,Vector3(0.145,0.115,0.20),skin)
	ellipsoid(chicken,Vector3(0,0.035,-0.04),Vector3(0.12,0.10,0.15),Color("cf8c46"))
	for side in [-1.0,1.0]:
		var leg := ellipsoid(chicken,Vector3(side*0.11,-0.035,0.16),Vector3(0.065,0.07,0.11),skin)
		leg.rotation.y = side*0.3
		rod(chicken,Vector3(side*0.14,-0.03,0.22),Vector3(side*0.14,-0.02,0.29),0.018,Color("e0c59a"))
		ellipsoid(chicken,Vector3(side*0.14,-0.02,0.29),Vector3(0.026,0.02,0.018),Color("e0c59a"))
		var wing := ellipsoid(chicken,Vector3(side*0.145,-0.025,-0.04),Vector3(0.045,0.065,0.09),Color("9b542d"))
		wing.rotation.z = side*0.45
	for i in range(7):
		var mark := ellipsoid(chicken,Vector3(sin(i*1.8)*0.09,0.102,-0.13+i*0.04),Vector3(0.035,0.009,0.011),Color("724021"))
		mark.rotation.y = 0.4
	smoke(chicken,Vector3(0,0.13,0),0.16,0.14,8)
	return chicken

static func sniper(parent: Node3D) -> Node3D:
	var weapon: Node3D=load("res://art/weapons/sniper.tscn").instantiate()
	parent.add_child(weapon)
	return weapon
