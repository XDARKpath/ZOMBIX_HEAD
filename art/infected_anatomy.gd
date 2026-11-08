extends RefCounted
# Separa la testa dal corpo mantenendo pelle e texture. Il taglio segue i pesi dello scheletro: appartiene alla testa
# solo ciò che si muove con l'osso della testa. Un taglio ad altezza fissa si portava via le spalle dei modelli grossi,
# che arrivano più in alto del collo.
static var cache: Dictionary = {}


static func prepare(avatar: Node3D, model_name: String) -> MeshInstance3D:
	var mesh_node: MeshInstance3D = find_mesh(avatar)
	# Manichino procedurale: la testa è già un pezzo separato, niente split.
	if mesh_node == null: return avatar.head_piece as MeshInstance3D
	_split(mesh_node, avatar.skeleton, model_name)
	mesh_node.mesh = cache[model_name][0]
	var part := MeshInstance3D.new()
	part.mesh = cache[model_name][1]
	avatar.add_child(part)
	return part


static func _split(mesh_node: MeshInstance3D, skeleton: Skeleton3D, key: String) -> void:
	if cache.has(key): return
	var head_id: int = skeleton.find_bone("head")
	if head_id < 0:
		for b in skeleton.get_bone_count():
			if String(skeleton.get_bone_name(b)).to_lower() == "head": head_id = b
	var rest: Transform3D = skeleton.get_bone_global_rest(head_id)
	var head_bones := _head_binds(mesh_node, skeleton, head_id)
	var body := ArrayMesh.new()
	var head := ArrayMesh.new()
	for surface in mesh_node.mesh.get_surface_count():
		var source: Array = mesh_node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		var share := _head_share(source, vertices.size(), head_bones)
		var body_indices := PackedInt32Array()
		var head_indices := PackedInt32Array()
		var neck_y: float = rest.origin.y - 0.02
		for i in range(0, indices.size(), 3):
			var a: int = indices[i]
			var b: int = indices[i + 1]
			var c: int = indices[i + 2]
			var on_head: bool
			if share.is_empty():
				on_head = (vertices[a].y + vertices[b].y + vertices[c].y) / 3.0 > neck_y
			else:
				on_head = (share[a] + share[b] + share[c]) / 3.0 > 0.5
			for j in 3:
				if on_head: head_indices.append(indices[i + j])
				else: body_indices.append(indices[i + j])
		var arrays: Array = source.duplicate()
		arrays[Mesh.ARRAY_INDEX] = body_indices
		if not body_indices.is_empty():
			body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mesh_node.mesh.surface_get_format(surface))
			body.surface_set_material(body.get_surface_count() - 1, mesh_node.mesh.surface_get_material(surface))
		var loose_arrays: Array = []
		loose_arrays.resize(Mesh.ARRAY_MAX)
		var v := PackedVector3Array()
		var n := PackedVector3Array()
		var uv := PackedVector2Array()
		for index in head_indices:
			v.append(rest.affine_inverse() * vertices[index])
			n.append((rest.basis.inverse() * source[Mesh.ARRAY_NORMAL][index]).normalized())
			uv.append(source[Mesh.ARRAY_TEX_UV][index])
		if not v.is_empty():
			loose_arrays[Mesh.ARRAY_VERTEX] = v
			loose_arrays[Mesh.ARRAY_NORMAL] = n
			loose_arrays[Mesh.ARRAY_TEX_UV] = uv
			head.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, loose_arrays)
			head.surface_set_material(head.get_surface_count() - 1, mesh_node.mesh.surface_get_material(surface))
	cache[key] = [body, head, rest.basis]


## Indici di bind dell'osso della testa e dei suoi figli (mascella, occhi...).
static func _head_binds(mesh_node: MeshInstance3D, skeleton: Skeleton3D, head_id: int) -> Dictionary:
	var out := {}
	var skin: Skin = mesh_node.skin
	if skin == null: return out
	for bind in skin.get_bind_count():
		var bone: int = skin.get_bind_bone(bind)
		if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(bind))
		var walk := bone
		while walk >= 0:
			if walk == head_id:
				out[bind] = true
				break
			walk = skeleton.get_bone_parent(walk)
	return out


## Per ogni vertice, quanto del suo peso segue la testa (0..1). Vuoto se il modello non ha i pesi.
static func _head_share(source: Array, count: int, head_bones: Dictionary) -> PackedFloat32Array:
	var share := PackedFloat32Array()
	if head_bones.is_empty(): return share
	var bones = source[Mesh.ARRAY_BONES]
	var weights = source[Mesh.ARRAY_WEIGHTS]
	if bones == null or weights == null or bones.size() == 0 or count == 0: return share
	var stride: int = int(bones.size() / count)
	share.resize(count)
	for i in count:
		var total := 0.0
		for j in stride:
			if head_bones.has(int(bones[i * stride + j])): total += float(weights[i * stride + j])
		share[i] = total
	return share


static func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.skin: return node
	for child in node.get_children():
		var found := find_mesh(child)
		if found: return found
	return null


## Testa a terra di quel modello. Se nessun infetto di quel tipo è ancora comparso, la prepara ora.
static func loose(model_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	_ensure(model_name)
	if cache.has(model_name):
		node.mesh = cache[model_name][1]
		node.material_override = load("res://art/env/materials/M_Env_Palette.tres")
	else:
		# Testa del manichino: sfera originale, nessun modello esterno.
		var skull := SphereMesh.new()
		skull.radius = 0.115
		skull.height = 0.23
		node.mesh = skull
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("77836a")
		mat.roughness = 0.9
		node.material_override = mat
	return node


static func _ensure(model_name: String) -> void:
	if cache.has(model_name) or not model_name.begins_with("res://") or not ResourceLoader.exists(model_name): return
	var scene: Node = load(model_name).instantiate()
	var mesh_node := find_mesh(scene)
	var skeleton := _skeleton(scene)
	if mesh_node and skeleton: _split(mesh_node, skeleton, model_name)
	scene.free()


static func _skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found := _skeleton(child)
		if found: return found
	return null


## La testa staccata come oggetto da tenere in mano: dritta, con il faccia in avanti (+Z) e l'origine sulla sommità,
## dove la mano la tiene per i capelli. Sotto il collo il taglio rosso e qualche goccia.
static func severed(model_name: String, height: float = 0.25) -> Node3D:
	_ensure(model_name)
	var root := Node3D.new()
	root.name = "TestaMozzata"
	var part := loose(model_name)
	root.add_child(part)
	if not cache.has(model_name): return root
	part.basis = cache[model_name][2]
	var box: AABB = part.transform * part.mesh.get_aabb()
	var size: float = height / maxf(box.size.y, 0.05)
	part.basis = part.basis.scaled(Vector3.ONE * size)
	box = part.transform * part.mesh.get_aabb()
	part.position = Vector3(-(box.position.x + box.size.x * 0.5), -(box.position.y + box.size.y), -(box.position.z + box.size.z * 0.5))
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("5e1410")
	red.roughness = 0.45
	var cut := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = box.size.x * 0.27
	disc.bottom_radius = box.size.x * 0.21
	disc.height = 0.035
	disc.radial_segments = 8
	disc.rings = 0
	cut.mesh = disc
	cut.material_override = red
	root.add_child(cut)
	cut.position = Vector3(0, -box.size.y - 0.012, -box.size.z * 0.06)
	for i in 3:
		var drop := MeshInstance3D.new()
		var bit := SphereMesh.new()
		bit.radius = 0.014 - float(i) * 0.002
		bit.height = bit.radius * 3.4
		bit.radial_segments = 6
		bit.rings = 3
		drop.mesh = bit
		drop.material_override = red
		root.add_child(drop)
		drop.position = Vector3(-0.03 + float(i) * 0.03, -box.size.y - 0.045 - float(i % 2) * 0.03, 0.01 * float(i))
	return root
