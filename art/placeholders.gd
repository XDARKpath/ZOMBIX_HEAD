extends RefCounted
# Segnaposto originali del progetto: nessun file esterno, nessuna licenza terza.
# Servono a tenere il gioco giocabile mentre si cercano asset CC0 definitivi.
const Props := preload("res://ui/camp/camp_props.gd")

static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	return mat

static func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.rotation = rot
	view.material_override = _material(color)
	parent.add_child(view)
	return view

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, color)

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _mesh(parent, mesh, at, color, rot)

static func sphere(parent: Node3D, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	return _mesh(parent, mesh, at, color)

# ---------------------------------------------------------------- personaggi

static func humanoid(model_name: String, zombie_mode: bool) -> Node3D:
	# Manichino snodato con gli stessi nomi osso del vecchio rig: pose, hitbox e
	# decapitazione continuano a funzionare senza modelli di terzi.
	var root := Node3D.new()
	root.name = "Mannequin"
	var sk := Skeleton3D.new()
	sk.name = "MannequinSkeleton"
	root.add_child(sk)
	var rows := [
		["pelvis", -1, Vector3(0, 0.94, 0)],
		["spine_01", 0, Vector3(0, 0.13, 0)],
		["spine_02", 1, Vector3(0, 0.20, 0)],
		["neck_01", 2, Vector3(0, 0.18, 0)],
		["head", 3, Vector3(0, 0.10, 0)],
		["upperarm_l", 2, Vector3(0.19, 0.12, 0)],
		["lowerarm_l", 5, Vector3(0.27, 0, 0)],
		["hand_l", 6, Vector3(0.25, 0, 0)],
		["upperarm_r", 2, Vector3(-0.19, 0.12, 0)],
		["lowerarm_r", 8, Vector3(-0.27, 0, 0)],
		["hand_r", 9, Vector3(-0.25, 0, 0)],
		["thigh_l", 0, Vector3(0.11, -0.02, 0)],
		["calf_l", 11, Vector3(0, -0.40, 0)],
		["foot_l", 12, Vector3(0, -0.40, 0.02)],
		["thigh_r", 0, Vector3(-0.11, -0.02, 0)],
		["calf_r", 14, Vector3(0, -0.40, 0)],
		["foot_r", 15, Vector3(0, -0.40, 0.02)],
	]
	for i in range(rows.size()):
		sk.add_bone(rows[i][0])
		if int(rows[i][1]) >= 0:
			sk.set_bone_parent(i, int(rows[i][1]))
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, rows[i][2]))
	sk.reset_bone_poses()

	var skin := Color("77836a")
	var shirt := Color("3c4a41")
	var pants := Color("2f3631")
	var shoe := Color("20231e")
	if not zombie_mode:
		skin = Color("a8836a")
		var palette := [Color("38505a"), Color("4a3f34"), Color("3d4a3a")]
		shirt = palette[absi(model_name.hash()) % palette.size()]
		pants = Color("343a3d")
		shoe = Color("23211d")

	# Busto e testa
	var pelvis := _attach(sk, "pelvis")
	box(pelvis, Vector3(0, 0, 0), Vector3(0.30, 0.20, 0.20), pants)
	var chest := _attach(sk, "spine_02")
	box(chest, Vector3(0, 0.10, 0), Vector3(0.40, 0.36, 0.24), shirt)
	box(chest, Vector3(0, 0.26, 0), Vector3(0.30, 0.10, 0.20), shirt)
	var neck := _attach(sk, "neck_01")
	cylinder(neck, Vector3(0, 0.05, 0), 0.055, 0.12, skin)

	# Testa staccabile: contenitore figlio dell'avatar, non dell'osso.
	var head := Node3D.new()
	head.name = "HeadPiece"
	var head_mesh := MeshInstance3D.new()
	var skull := SphereMesh.new()
	skull.radius = 0.115
	skull.height = 0.23
	skull.radial_segments = 16
	skull.rings = 10
	head_mesh.mesh = skull
	head_mesh.position = Vector3(0, 0.06, 0)
	head_mesh.material_override = _material(skin)
	head.add_child(head_mesh)
	var hair := MeshInstance3D.new()
	var cap := SphereMesh.new()
	cap.radius = 0.118
	cap.height = 0.12
	cap.is_hemisphere = true
	hair.mesh = cap
	hair.position = Vector3(0, 0.10, 0)
	hair.material_override = _material(Color("2a2620") if zombie_mode else Color("3a2f26"))
	head.add_child(hair)
	if zombie_mode:
		for side in [-1.0, 1.0]:
			box(head, Vector3(side * 0.045, 0.06, 0.10), Vector3(0.028, 0.03, 0.02), Color("1a1210"))
	root.add_child(head)

	# Braccia e gambe
	for side in ["l", "r"]:
		var sign_value := 1.0 if side == "l" else -1.0
		var upper := _attach(sk, "upperarm_" + side)
		var arm := CapsuleMesh.new()
		arm.radius = 0.055
		arm.height = 0.34
		_mesh(upper, arm, Vector3(sign_value * 0.14, 0, 0), shirt, Vector3(0, 0, PI / 2))
		var lower := _attach(sk, "lowerarm_" + side)
		var fore := CapsuleMesh.new()
		fore.radius = 0.045
		fore.height = 0.30
		_mesh(lower, fore, Vector3(sign_value * 0.14, 0, 0), skin if zombie_mode else shirt, Vector3(0, 0, PI / 2))
		var hand := _attach(sk, "hand_" + side)
		box(hand, Vector3(sign_value * 0.10, 0, 0), Vector3(0.10, 0.09, 0.06), skin)
		var thigh := _attach(sk, "thigh_" + side)
		var leg := CapsuleMesh.new()
		leg.radius = 0.075
		leg.height = 0.42
		_mesh(thigh, leg, Vector3(0, -0.21, 0), pants)
		var calf := _attach(sk, "calf_" + side)
		var shin := CapsuleMesh.new()
		shin.radius = 0.055
		shin.height = 0.40
		_mesh(calf, shin, Vector3(0, -0.20, 0), pants)
		var foot := _attach(sk, "foot_" + side)
		box(foot, Vector3(0, -0.02, 0.06), Vector3(0.11, 0.08, 0.26), shoe)
	return root

static func _attach(sk: Skeleton3D, bone: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	sk.add_child(attachment)
	return attachment

# ---------------------------------------------------------------- armi

static func axe() -> Node3D:
	return preload("res://art/weapons/hand_tools.gd").make("axe")

static func legacy_axe() -> Node3D:
	var root := Node3D.new()
	root.name = "PlaceholderAxe"
	var wood := Color("6a4b2f")
	var steel := Color("929ba1")
	var edge := Color("c3cbd0")
	var dark := Color("2a2721")
	# Manico dritto con impugnatura in cuoio e fondello.
	cylinder(root, Vector3(0, 0.06, 0), 0.030, 0.96, wood)
	cylinder(root, Vector3(0, -0.30, 0), 0.035, 0.24, dark)
	for y in [-0.39, -0.25]:
		cylinder(root, Vector3(0, y, 0), 0.038, 0.022, Color("3c3126"))
	cylinder(root, Vector3(0, 0.55, 0), 0.034, 0.03, dark)
	# Testa forgiata: occhio sul manico e lama a scure con filo continuo.
	box(root, Vector3(0, 0.47, 0.02), Vector3(0.085, 0.17, 0.14), steel)
	var blade := _axe_blade(0.032, Color("8d969c"))
	root.add_child(blade)
	# Filo chiaro e contrappeso/pollice dietro l'occhio.
	var bevel := _axe_edge(0.034)
	root.add_child(bevel)
	box(root, Vector3(0, 0.47, -0.11), Vector3(0.07, 0.13, 0.10), dark)
	cylinder(root, Vector3(0, 0.26, 0), 0.033, 0.04, Color("5a3f27"))
	return root

static func _axe_blade(half:float, color:Color) -> MeshInstance3D:
	# Sei facce: due lati della lama, filo, dorso e due raccordi all'occhio.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner_top:=Vector3(0,0.60,0.05);var inner_bottom:=Vector3(0,0.34,0.05)
	var outer_top:=Vector3(0,0.64,0.30);var outer_bottom:=Vector3(0,0.23,0.235)
	var faces:=[
		[inner_top,inner_bottom,outer_bottom],[inner_top,outer_bottom,outer_top],
		[outer_top,outer_bottom,inner_bottom],[outer_top,inner_bottom,inner_top],
		[outer_top,inner_top,inner_bottom],[outer_top,inner_bottom,outer_bottom],
		[inner_top,outer_bottom,inner_bottom],[inner_top,outer_top,outer_bottom],
	]
	for face in faces:
		for point in face:
			st.add_vertex(point+Vector3(half,0,0))
		for point in [face[0],face[2],face[1]]:
			st.add_vertex(point-Vector3(half,0,0))
	st.generate_normals()
	var view:=MeshInstance3D.new();view.mesh=st.commit()
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.metallic=0.65;mat.roughness=0.32
	view.material_override=mat
	return view

static func _axe_edge(half:float) -> MeshInstance3D:
	# Filo lucido: una lama sottile sul bordo esterno.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a:=Vector3(0,0.64,0.30);var b:=Vector3(0,0.23,0.235);var c:=Vector3(0,0.645,0.335);var d:=Vector3(0,0.225,0.26)
	for face in [[a,b,d],[a,d,c]]:
		for point in face:st.add_vertex(point+Vector3(half,0,0))
		for point in [face[0],face[2],face[1]]:st.add_vertex(point-Vector3(half,0,0))
	st.generate_normals()
	var view:=MeshInstance3D.new();view.mesh=st.commit()
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("d9e2e7");mat.metallic=0.9;mat.roughness=0.18
	view.material_override=mat
	return view

static func knife() -> Node3D:
	var root := Node3D.new()
	root.name = "PlaceholderKnife"
	cylinder(root, Vector3(0, -0.06, 0), 0.022, 0.20, Color("2b2a26"))
	box(root, Vector3(0, 0.16, 0.01), Vector3(0.016, 0.30, 0.055), Color("aeb6bb"))
	preload("res://art/weapons/grip_sockets.gd").add(root, "Socket_RightHand", Vector3(0, -0.075, 0), Vector3.DOWN, Vector3.BACK, 0.022)
	return root

static func pistol() -> Node3D:
	var root := Node3D.new()
	root.name = "PlaceholderPistol"
	box(root, Vector3(0.06, 0.07, 0), Vector3(0.26, 0.06, 0.045), Color("5b6268"))
	box(root, Vector3(0.05, 0.03, 0), Vector3(0.22, 0.03, 0.04), Color("242a2d"))
	box(root, Vector3(-0.03, -0.02, 0), Vector3(0.06, 0.13, 0.045), Color("1d2225"))
	cylinder(root, Vector3(0.19, 0.07, 0), 0.014, 0.03, Color("14181a"), Vector3(0, 0, PI / 2))
	return root

static func weapon(id: String) -> Node3D:
	match id:
		"axe": return axe()
		"knife": return knife()
		"pistol": return pistol()
	return axe()

# ---------------------------------------------------------------- edifici

static func village_block(id: String, at: Vector3, yaw: float, scale_value: Vector3) -> Node3D:
	# Blockout con la stessa griglia da 3 m dei moduli originali.
	var size := Vector3(2.9, 2.9, 0.18)
	var color := Color("6b4a3d")
	var lift := 0.0
	if "Floor" in id:
		size = Vector3(2.9, 0.12, 2.9); color = Color("4a4238")
	elif "Roof" in id:
		size = Vector3(2.9, 0.22, 2.9); color = Color("3b3a33")
	elif "Shade" in id:
		size = Vector3(2.9, 0.12, 2.9); color = Color("3a3a31")
	elif "Beam" in id or "Truss" in id or "Pole" in id or "Fence_Pole" in id:
		size = Vector3(0.22, 2.9, 0.22); color = Color("3d352b")
	elif "Fence_Wire" in id:
		size = Vector3(2.9, 1.20, 0.05); color = Color("4a4f48")
	elif "Metal" in id:
		color = Color("5c6462")
	elif "Door" in id:
		size = Vector3(2.9, 2.6, 0.16); color = Color("3b332a")
	elif "Interior" in id:
		size = Vector3(2.9, 2.6, 0.14); color = Color("5a5044")
	elif "Prop" in id:
		size = Vector3(0.62, 0.62, 0.62); color = Color("5a5344")
		if "Table" in id or "Desk" in id:
			size = Vector3(1.60, 0.09, 0.72); lift = 0.72
		elif "Shelf" in id or "Cabinet" in id:
			size = Vector3(1.10, 1.70, 0.40)
		elif "Chair" in id:
			size = Vector3(0.52, 0.85, 0.52)
		elif "Bag" in id or "Bottle" in id or "Can" in id or "Papers" in id:
			size = Vector3(0.22, 0.24, 0.22)
		elif "Barrel" in id:
			var root := Node3D.new()
			cylinder(root, Vector3(0, 0.43, 0), 0.30, 0.85, Color("4c5348"))
			root.position = at
			root.rotation.y = yaw
			return root
		elif "Light" in id:
			size = Vector3(0.16, 0.30, 0.10); color = Color("8a7b55")
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = at + Vector3(0, size.y * 0.5 + lift, 0)
	node.rotation.y = yaw
	node.scale = scale_value
	if "Window" in id:
		var glass := box(node, Vector3(0, 0, size.z * 0.5 + 0.03), Vector3(1.30, 1.15, 0.04), Color("26343a"))
		glass.material_override = _material(Color("26343a"))
	return node

# ---------------------------------------------------------------- natura e rottami

static func tree(kind: String = "Pine_1") -> Node3D:
	return load("res://art/nature/" + kind + ".gltf").instantiate()

static func rock() -> Node3D:
	return load("res://art/kaykit_forest/Rock_1_A_Color1.gltf").instantiate()

static func log() -> Node3D:
	# Tronco coricato sull'asse Z, centro sull'asse del cilindro: la panca del
	# falò appoggia sulla superficie a 0.24 dal centro.
	var root := Node3D.new()
	cylinder(root, Vector3.ZERO, 0.28, 2.40, Color("4a3b2b"), Vector3(PI / 2, 0, 0))
	return root

static func tent() -> Node3D:
	var root := Node3D.new()
	var canvas := Color("4c5147")
	var left := box(root, Vector3(-0.62, 0.85, 0), Vector3(1.45, 0.10, 2.40), canvas)
	left.rotation.z = 0.72
	var right := box(root, Vector3(0.62, 0.85, 0), Vector3(1.45, 0.10, 2.40), canvas)
	right.rotation.z = -0.72
	box(root, Vector3(0, 0.02, 0), Vector3(2.10, 0.06, 2.40), Color("3f443c"))
	return root

static func truck() -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(0, 0.75, 0), Vector3(4.20, 0.90, 1.85), Color("4a5147"))
	box(root, Vector3(-0.40, 1.55, 0), Vector3(2.10, 0.80, 1.70), Color("3d443b"))
	for sx in [-1.4, 1.4]:
		for sz in [-0.85, 0.85]:
			var wheel := MeshInstance3D.new()
			var ring := CylinderMesh.new()
			ring.top_radius = 0.38
			ring.bottom_radius = 0.38
			ring.height = 0.26
			wheel.mesh = ring
			wheel.rotation.x = PI / 2
			wheel.position = Vector3(sx, 0.38, sz)
			wheel.material_override = _material(Color("1e211f"))
			root.add_child(wheel)
	return root

static func barrel() -> Node3D:
	var root := Node3D.new()
	cylinder(root, Vector3(0, 0.42, 0), 0.30, 0.85, Color("46564f"))
	return root

static func boat() -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(0, 0.16, 0), Vector3(0.85, 0.32, 3.40), Color("5c5646"))
	box(root, Vector3(0, 0.33, 0), Vector3(0.62, 0.10, 3.00), Color("6a6350"))
	for z in [-1.0, 0.2]:
		box(root, Vector3(0, 0.42, z), Vector3(0.70, 0.07, 0.28), Color("4c463a"))
	return root

static func fishing_rod() -> Node3D:
	var root := Node3D.new()
	cylinder(root, Vector3(0, 0.30, 0), 0.012, 1.60, Color("8a7a55"), Vector3(0.42, 0, 0))
	return root
