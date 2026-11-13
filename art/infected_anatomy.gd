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
	var head_id := _head_id(skeleton)
	var rest: Transform3D = skeleton.get_bone_global_rest(head_id)
	var head_bones := _binds(mesh_node, skeleton, head_id)
	var body := ArrayMesh.new()
	var head := ArrayMesh.new()
	for surface in mesh_node.mesh.get_surface_count():
		var source: Array = mesh_node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		var share := _share(source, vertices.size(), head_bones)
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
	cache[key] = [body, head, rest.basis, mesh_node.mesh]


## Indici di bind di un osso e dei suoi figli (per la testa: mascella, occhi...; per un braccio: mano e dita).
static func _binds(mesh_node: MeshInstance3D, skeleton: Skeleton3D, root_id: int) -> Dictionary:
	var out := {}
	var skin: Skin = mesh_node.skin
	if skin == null: return out
	for bind in skin.get_bind_count():
		var bone: int = skin.get_bind_bone(bind)
		if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(bind))
		var walk := bone
		while walk >= 0:
			if walk == root_id:
				out[bind] = true
				break
			walk = skeleton.get_bone_parent(walk)
	return out


## Per ogni vertice, quanto del suo peso segue quelle ossa (0..1). Vuoto se il modello non ha i pesi.
static func _share(source: Array, count: int, group: Dictionary) -> PackedFloat32Array:
	var share := PackedFloat32Array()
	if group.is_empty(): return share
	var bones = source[Mesh.ARRAY_BONES]
	var weights = source[Mesh.ARRAY_WEIGHTS]
	if bones == null or weights == null or bones.size() == 0 or count == 0: return share
	var stride: int = int(bones.size() / count)
	share.resize(count)
	for i in count:
		var total := 0.0
		for j in stride:
			if group.has(int(bones[i * stride + j])): total += float(weights[i * stride + j])
		share[i] = total
	return share


static func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.skin and node.name != "Moncone": return node
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


static func _head_id(skeleton: Skeleton3D) -> int:
	var head_id: int = skeleton.find_bone("head")
	if head_id < 0:
		for b in skeleton.get_bone_count():
			if String(skeleton.get_bone_name(b)).to_lower() == "head": head_id = b
	return head_id


# ------------------------------------------------------------------ Arti staccati
# Stesso criterio della testa: appartiene all'arto ciò che porta più di metà del peso sulle sue ossa. Il corpo tagliato
# dipende da quali arti mancano, quindi si prepara (e si tiene) per modello e insieme di arti mancanti.

## [corpo, moncone] per modello e arti mancanti; pezzi staccati per modello, osso e figli già persi.
static var cuts: Dictionary = {}
static var pieces: Dictionary = {}
## Arti a terra: al massimo MAX_DROPPED (i più vecchi spariscono prima), ognuno dura DROPPED_LIFE secondi.
static var dropped: Array = []
const MAX_DROPPED := 10
const DROPPED_LIFE := 20.0
static var _flesh_mat: StandardMaterial3D


## Toglie dal corpo gli arti che partono dalle ossa `roots` e ne chiude i monconi. Il moncone è una mesh a parte con la
## stessa pelle: segue le ossa come il corpo, ma ha il suo colore di carne invece della palette.
static func carve(avatar: Node3D, model_name: String, roots: Array) -> void:
	var mesh_node := find_mesh(avatar)
	if mesh_node == null or avatar.skeleton == null or not cache.has(model_name): return
	var bones := roots.duplicate()
	bones.sort()
	var key := model_name + "|" + ",".join(PackedStringArray(bones))
	if bones.is_empty(): cuts[key] = [cache[model_name][0], null]
	if not cuts.has(key): cuts[key] = _carve(mesh_node, avatar.skeleton, model_name, bones)
	mesh_node.mesh = cuts[key][0]
	var stump := mesh_node.get_parent().get_node_or_null("Moncone") as MeshInstance3D
	if stump == null:
		stump = MeshInstance3D.new()
		stump.name = "Moncone"
		mesh_node.get_parent().add_child(stump)
		stump.transform = mesh_node.transform
		stump.skin = mesh_node.skin
		stump.skeleton = stump.get_path_to(mesh_node.get_node(mesh_node.skeleton))
		stump.material_override = _flesh()
	stump.mesh = cuts[key][1]


static func _carve(mesh_node: MeshInstance3D, skeleton: Skeleton3D, model_name: String, bones: Array) -> Array:
	var source: Mesh = cache[model_name][3]
	var groups := [_binds(mesh_node, skeleton, _head_id(skeleton))]
	for b in bones: groups.append(_binds(mesh_node, skeleton, skeleton.find_bone(b)))
	var body := ArrayMesh.new()
	var cap := {"v": [], "n": [], "b": [], "w": [], "stride": 4}
	for surface in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var indices := _indices(arrays)
		var owner := _owners(arrays, indices, groups)
		var keep := PackedInt32Array()
		for t in owner.size():
			if owner[t] == -1: keep.append_array(indices.slice(t * 3, t * 3 + 3))
		var out: Array = arrays.duplicate()
		out[Mesh.ARRAY_INDEX] = keep
		if not keep.is_empty():
			body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, source.surface_get_format(surface))
			body.surface_set_material(body.get_surface_count() - 1, source.surface_get_material(surface))
		for g in range(1, groups.size()):
			var id := skeleton.find_bone(bones[g - 1])
			var up := skeleton.get_bone_parent(id)
			var outward := (skeleton.get_bone_global_rest(id).origin - skeleton.get_bone_global_rest(up).origin).normalized()
			_close(cap, arrays, _rim(arrays[Mesh.ARRAY_VERTEX], indices, owner, -1, g), outward, _bind_of(mesh_node.skin, skeleton, up))
	return [body, _cap_mesh(cap)]


## Il pezzo staccato nello spazio di riposo del suo osso, chiuso dove si attaccava. `exclude`: ossa dei figli già persi.
static func _piece(mesh_node: MeshInstance3D, skeleton: Skeleton3D, model_name: String, bone: String, exclude: Array) -> ArrayMesh:
	var source: Mesh = cache[model_name][3]
	var id := skeleton.find_bone(bone)
	var to_rest := skeleton.get_bone_global_rest(id).affine_inverse()
	var groups := exclude.map(func(b): return _binds(mesh_node, skeleton, skeleton.find_bone(b)))
	groups.append(_binds(mesh_node, skeleton, id))
	var inside := groups.size() - 1
	var toward_body := to_rest.basis * (skeleton.get_bone_global_rest(skeleton.get_bone_parent(id)).origin - skeleton.get_bone_global_rest(id).origin).normalized()
	var mesh := ArrayMesh.new()
	var cap := {"v": [], "n": [], "b": [], "w": [], "stride": 4}
	for surface in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := _indices(arrays)
		var owner := _owners(arrays, indices, groups)
		var v := PackedVector3Array()
		var n := PackedVector3Array()
		var uv := PackedVector2Array()
		for t in owner.size():
			if owner[t] != inside: continue
			for j in 3:
				var i: int = indices[t * 3 + j]
				v.append(to_rest * vertices[i])
				n.append((to_rest.basis * arrays[Mesh.ARRAY_NORMAL][i]).normalized())
				uv.append(arrays[Mesh.ARRAY_TEX_UV][i])
		if v.is_empty(): continue
		var loose_arrays: Array = []
		loose_arrays.resize(Mesh.ARRAY_MAX)
		loose_arrays[Mesh.ARRAY_VERTEX] = v
		loose_arrays[Mesh.ARRAY_NORMAL] = n
		loose_arrays[Mesh.ARRAY_TEX_UV] = uv
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, loose_arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, load("res://art/env/materials/M_Env_Palette.tres"))
		_close(cap, arrays, _rim(vertices, indices, owner, inside, -1), toward_body, -1, to_rest)
	var lid := _cap_mesh(cap)
	if lid and mesh.get_surface_count() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, lid.surface_get_arrays(0))
		mesh.surface_set_material(mesh.get_surface_count() - 1, _flesh())
	return mesh


static func _indices(arrays: Array) -> PackedInt32Array:
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(i)
	return indices


## Per ogni triangolo il primo gruppo di ossa che ne porta più di metà del peso (-1: nessuno, resta al corpo).
static func _owners(arrays: Array, indices: PackedInt32Array, groups: Array) -> PackedInt32Array:
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	var shares := groups.map(func(g): return _share(arrays, count, g))
	var out := PackedInt32Array()
	out.resize(indices.size() / 3)
	for t in out.size():
		out[t] = -1
		for g in shares.size():
			var s: PackedFloat32Array = shares[g]
			if not s.is_empty() and s[indices[t * 3]] + s[indices[t * 3 + 1]] + s[indices[t * 3 + 2]] > 1.5:
				out[t] = g
				break
	return out


## Lati dei triangoli `inside` che confinano con triangoli `outside`: l'orlo del taglio. Confronta le posizioni e non gli
## indici, perché sulle cuciture delle UV lo stesso punto ha più vertici.
static func _rim(vertices: PackedVector3Array, indices: PackedInt32Array, owner: PackedInt32Array, inside: int, outside: int) -> Array:
	var across := {}
	for t in owner.size():
		if owner[t] != outside: continue
		for j in 3: across[_edge_key(vertices, indices[t * 3 + j], indices[t * 3 + (j + 1) % 3])] = true
	var rim := []
	for t in owner.size():
		if owner[t] != inside: continue
		for j in 3:
			var a: int = indices[t * 3 + j]
			var b: int = indices[t * 3 + (j + 1) % 3]
			if across.has(_edge_key(vertices, a, b)): rim.append([a, b])
	return rim


static func _edge_key(vertices: PackedVector3Array, a: int, b: int) -> String:
	var ka := str(Vector3i((vertices[a] * 1000.0).round()))
	var kb := str(Vector3i((vertices[b] * 1000.0).round()))
	return ka + kb if ka < kb else kb + ka


## Chiude l'orlo con un ventaglio attorno al suo centro. Con la pelle (centre_bind >= 0) i vertici dell'orlo tengono i
## pesi del corpo e il centro segue l'osso dove resta attaccato; senza pelle è il tappo del pezzo staccato.
static func _close(cap: Dictionary, arrays: Array, rim: Array, normal: Vector3, centre_bind: int, to_rest := Transform3D.IDENTITY) -> void:
	if rim.is_empty(): return
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	var stride: int = int(bones.size() / vertices.size()) if centre_bind >= 0 and bones != null and bones.size() > 0 else 0
	var centre := Vector3.ZERO
	for e in rim: centre += vertices[e[0]] + vertices[e[1]]
	centre /= rim.size() * 2.0
	for e in rim:
		for i in [e[1], e[0], -1]:
			cap.v.append(to_rest * (vertices[i] if i >= 0 else centre))
			cap.n.append(normal)
			for j in stride:
				cap.b.append(int(bones[i * stride + j]) if i >= 0 else (centre_bind if j == 0 else 0))
				cap.w.append(float(weights[i * stride + j]) if i >= 0 else (1.0 if j == 0 else 0.0))
	if stride > 0: cap.stride = stride


static func _cap_mesh(cap: Dictionary) -> ArrayMesh:
	if cap.v.is_empty(): return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(cap.v)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(cap.n)
	var flags := 0
	if not cap.b.is_empty():
		arrays[Mesh.ARRAY_BONES] = PackedInt32Array(cap.b)
		arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array(cap.w)
		if cap.stride == 8: flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return mesh


static func _bind_of(skin: Skin, skeleton: Skeleton3D, bone_id: int) -> int:
	for bind in skin.get_bind_count():
		var bone: int = skin.get_bind_bone(bind)
		if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(bind))
		if bone == bone_id: return bind
	return 0


static func _flesh() -> StandardMaterial3D:
	if _flesh_mat == null:
		_flesh_mat = StandardMaterial3D.new()
		_flesh_mat.albedo_color = Color("5e1410")
		_flesh_mat.roughness = 0.45
		_flesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _flesh_mat


## Il pezzo staccato cade come corpo fisico semplice e sparisce dopo DROPPED_LIFE secondi.
static func drop_limb(avatar: Node3D, model_name: String, bone: String, exclude: Array, push: Vector3, parent: Node) -> RigidBody3D:
	var mesh_node := find_mesh(avatar)
	var sk: Skeleton3D = avatar.skeleton
	if mesh_node == null or sk == null or parent == null or not cache.has(model_name) or sk.find_bone(bone) < 0: return null
	var key := model_name + "|" + bone + "|" + ",".join(PackedStringArray(exclude))
	if not pieces.has(key): pieces[key] = _piece(mesh_node, sk, model_name, bone, exclude)
	var mesh: ArrayMesh = pieces[key]
	if mesh.get_surface_count() == 0: return null
	var at: Transform3D = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone))
	var size: float = at.basis.get_scale().x
	var body := RigidBody3D.new()
	body.name = "ArtoStaccato"
	body.collision_layer = 0
	body.collision_mask = 1
	body.mass = 3.0
	var look := MeshInstance3D.new()
	look.mesh = mesh
	look.scale = Vector3.ONE * size
	body.add_child(look)
	var box: AABB = mesh.get_aabb()
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = (box.size * size).max(Vector3.ONE * 0.06)
	shape.shape = cube
	shape.position = box.get_center() * size
	body.add_child(shape)
	parent.add_child(body)
	body.global_transform = Transform3D(at.basis.orthonormalized(), at.origin)
	body.linear_velocity = push + Vector3.UP * 1.5
	body.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	dropped = dropped.filter(func(n): return is_instance_valid(n))
	while dropped.size() >= MAX_DROPPED: dropped.pop_front().queue_free()
	dropped.append(body)
	body.get_tree().create_timer(DROPPED_LIFE, false).timeout.connect(body.queue_free)
	return body
