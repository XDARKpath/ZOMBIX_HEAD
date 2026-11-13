# Pezzi comuni di BORGO CENERE: helper, case, ruderi e capanni. Li usano il villaggio (villaggio.gd) e i luoghi lungo la strada (world/campaign/roadside_poi.gd).
# Solo kit originale art/zx_borgo e natura CC0 di Quaternius (art/nature).
extends Node3D

const NATURE := "res://art/nature/"
const Props := preload("res://ui/camp/camp_props.gd")
## kit originale del borgo (zx_borgo, fatto da zero: nessun pezzo Synty/SurrounDead)
const BK := "res://art/zx_borgo/"
## distanze di disegno: erba 140 m (MultiMesh), oggetti 200 m, case 600 m
const RANGE_SMALL := 200.0
const RANGE_HOUSE := 600.0

var cache := {}
var glb_cache := {}
var geo: Node3D                       # dove finiscono le case e tutto quello che si costruisce
var rng := RandomNumberGenerator.new()
var mm_rows := {}                     # file -> Array[Transform3D] (erba, fiori, sassi: MultiMesh)
var perches: Array[Marker3D] = []          # tetti fuori dalla piazza (sputatori)
var plaza_perches: Array[Marker3D] = []    # tetti dei negozi della piazza
var fires: Array[OmniLight3D] = []


## Mette a ogni pezzo la sua distanza di disegno: i pezzi piccoli spariscono prima dei muri.
static func fit_ranges(node: Node, scale_so_far: float = 1.0) -> void:
	# Chi si muove (giocatori, infetti, auto) non si tocca.
	if node is CharacterBody3D: return
	var size := scale_so_far
	if node is Node3D:
		var s: Vector3 = (node as Node3D).scale
		size *= maxf(absf(s.x), maxf(absf(s.y), absf(s.z)))
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var longest: float = (node as MeshInstance3D).get_aabb().size[(node as MeshInstance3D).get_aabb().get_longest_axis_index()] * size
		(node as GeometryInstance3D).visibility_range_end = RANGE_HOUSE if longest >= 2.5 else RANGE_SMALL
		# Ombra del sole inutile per sassolini, bottiglie e lastre a terra (sangue, pozzanghere, vie).
		if longest < 0.5 or (node as MeshInstance3D).get_aabb().size.y * size < 0.06:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif node is Label3D or node is CPUParticles3D:
		(node as GeometryInstance3D).visibility_range_end = RANGE_SMALL
	elif node is Light3D and not (node as Light3D).distance_fade_enabled:
		# Le luci con un fade già scelto (torce di Rocca e Cripta, lampade del rifugio) restano corte.
		(node as Light3D).distance_fade_enabled = true
		(node as Light3D).distance_fade_begin = 120.0
		(node as Light3D).distance_fade_length = 40.0
	for child in node.get_children():
		fit_ranges(child, size)


func _collide(node: Node) -> void:
	if node is MeshInstance3D: node.create_trimesh_collision()
	for child in node.get_children():
		if not child is StaticBody3D: _collide(child)


func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid: bool = true) -> MeshInstance3D:
	var view: MeshInstance3D = Props.box(parent, at, size, color)
	if solid: view.create_trimesh_collision()
	return view


func signboard(parent: Node3D, at: Vector3, text: String, width: float = 3.5, yaw: float = 0) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.rotation.y = yaw
	box(root, Vector3.ZERO, Vector3(width, 0.7, 0.1), Color("263c3b"), false)
	var label := Label3D.new()
	root.add_child(label)
	label.text = text
	label.position.z = 0.061
	label.font = load("res://art/fonts/BarlowCondensed-SemiBold.ttf")
	label.font_size = 58
	label.pixel_size = 0.008
	label.modulate = Color("f1d6a1")
	label.outline_size = 0
	return root


func _floor(parent: Node3D, width: int, depth: int) -> void:
	for x in range(width):
		for z in range(depth):
			asset(parent, "Bld_Floor_Ceiling_Wood_01", Vector3(-width * 1.5 + x * 3, 0.025, depth * 1.5 - z * 3))


func _walls(parent: Node3D, width: int, depth: int, metal: bool = false, height_scale: float = 1) -> void:
	var wall := "Bld_Wall_Metal_01" if metal else "Bld_Wall_Brick_01"
	var window := "Bld_Wall_Metal_Window_01" if metal else "Bld_Wall_Brick_Window_01"
	var scale_value := Vector3(1, height_scale, 1)
	for i in range(width): asset(parent, window if i % 2 else wall, Vector3(width * 1.5 - i * 3, 0, -depth * 1.5), PI, true, scale_value)
	for i in range(depth):
		asset(parent, window if i == 1 else wall, Vector3(-width * 1.5, 0, -depth * 1.5 + i * 3), -PI / 2, true, scale_value)
		asset(parent, window if i == 1 else wall, Vector3(width * 1.5, 0, depth * 1.5 - i * 3), PI / 2, true, scale_value)


func _roof(parent: Node3D, width: int, y: float) -> void:
	for i in range(width): asset(parent, "Bld_Roof_01", Vector3(-width * 1.5 + (i + 1) * 3, y, 4.5), 0, true)
	for z in [-4.5, 4.5]: box(parent, Vector3(0, y + 0.08, z), Vector3(width * 3, 0.3, 0.22), Color("403e34"))
	for x in [-width * 1.5, width * 1.5]: asset(parent, "Bld_Roof_Truss_01", Vector3(x, y, 4.5), 0, false)
	# Timpani: prisma spesso come il muro, con il bordo appena sotto le falde (misurate su Bld_Roof_01:
	# la falda dietro è più alta di quella davanti), così da dentro non passa il cielo.
	for x in [-width * 1.5, width * 1.5]:
		var gable := MeshInstance3D.new()
		gable.mesh = _gable_mesh()
		gable.position = Vector3(x, y, 0)
		gable.material_override = _gable_mat
		parent.add_child(gable)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = gable.mesh.create_convex_shape()
		body.add_child(cs)
		gable.add_child(body)
		box(parent, Vector3(x, y + 0.02, 0), Vector3(0.15, 0.3, 9), Color("403e34"))


static var _gable: ArrayMesh
static var _gable_mat: StandardMaterial3D


## Profilo (z, y) del timpano sotto Bld_Roof_01, spesso 0.34 m in x, condiviso da tutte le case.
static func _gable_mesh() -> ArrayMesh:
	if _gable: return _gable
	_gable_mat = StandardMaterial3D.new()
	_gable_mat.albedo_color = Color("403e34")
	_gable_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var poly := [Vector2(4.5, 0.0), Vector2(4.5, 0.08), Vector2(0.0, 1.7), Vector2(-0.3, 1.8), Vector2(-4.5, 0.17), Vector2(-4.5, 0.0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-0.17, 0.17]:
		for i in range(1, poly.size() - 1):
			for p in [poly[0], poly[i], poly[i + 1]]: st.add_vertex(Vector3(x, p.y, p.x))
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		for p in [Vector3(-0.17, a.y, a.x), Vector3(0.17, a.y, a.x), Vector3(0.17, b.y, b.x), Vector3(-0.17, a.y, a.x), Vector3(0.17, b.y, b.x), Vector3(-0.17, b.y, b.x)]:
			st.add_vertex(p)
	st.generate_normals()
	_gable = st.commit()
	return _gable


func _entry_ramp(parent: Node3D, width: float, x: float = 0.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(x - width / 2, 0, 5.4), Vector3(x + width / 2, 0, 5.4), Vector3(x - width / 2, 0.095, 4.3), Vector3(x + width / 2, 0.095, 4.3)]
	for i in [0, 2, 1, 1, 2, 3]: st.add_vertex(points[i])
	st.generate_normals()
	var ramp := MeshInstance3D.new()
	ramp.mesh = st.commit()
	parent.add_child(ramp)
	ramp.material_override = Props.material(Color("777769"))
	ramp.create_trimesh_collision()


func _puddle_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("313f40")
		mat.roughness = 0.15
		mat.metallic = 0.35
		node.material_override = mat
	for child in node.get_children(): _puddle_material(child)

## i moduli (muri, tetti, arredo...) vengono dal kit originale zx_borgo: vale anche per
## _floor/_walls/_roof ereditati da refuge_set.gd, che chiamano asset()
func asset(parent: Node3D, id: String, at: Vector3, yaw: float = 0, solid: bool = true, scale_value: Vector3 = Vector3.ONE) -> Node3D:
	var path := BK + "SM_" + id + ".glb"
	if not cache.has(path):
		cache[path] = load(path)
	var node: Node3D = cache[path].instantiate()
	parent.add_child(node)
	node.position = at
	node.rotation.y = yaw
	node.scale = scale_value
	if solid:
		_collide(node)
	return node


func _node(parent: Node3D, at: Vector3, yaw: float = 0.0, label: String = "") -> Node3D:
	var n := Node3D.new()
	if label != "":
		n.name = label
	parent.add_child(n)
	n.position = at
	n.rotation.y = yaw
	return n


func _glb(parent: Node3D, path: String, at: Vector3, yaw: float = 0.0, s: float = 1.0, solid: bool = true) -> Node3D:
	if not glb_cache.has(path):
		glb_cache[path] = load(path)
	var n: Node3D = glb_cache[path].instantiate()
	parent.add_child(n)
	n.position = at
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	if solid:
		_collide(n)
	return n


func _char(node: Node) -> void:
	# annerisce un pezzo (legno bruciato)
	if node is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("221d19")
		m.roughness = 1.0
		node.material_override = m
	for c in node.get_children():
		_char(c)


func _apply_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for c in node.get_children():
		_apply_material(c, mat)


## albero con un tronco solido (cilindro) come in terrain.gd: niente trimesh sulle chiome
func _tree(parent: Node3D, path: String, at: Vector3, s: float) -> Node3D:
	var t := _glb(parent, path, at, rng.randf_range(0, TAU), s, false)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.38 * clampf(s, 0.8, 1.6)
	cyl.height = 5.0
	shape.shape = cyl
	shape.position.y = 2.5
	body.add_child(shape)
	parent.add_child(body)
	body.position = at
	return t


## erba / fiori / sassolini: raccolti e disegnati con un MultiMesh per file (leggero anche con migliaia)
func _scatter(file: String, at: Vector3, s: float = 1.0) -> void:
	# l'erba e i fiori del pacchetto natura sono grandi: a scala piena sembrano canne. Li riduco come nel resto della mappa.
	if "Grass" in file or "Flower" in file:
		s *= 0.45
	elif "Plant" in file or "Fern" in file or "Clover" in file:
		s *= 0.6
	if not mm_rows.has(file):
		mm_rows[file] = []
	mm_rows[file].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * s), at))


func _flush_multimesh() -> void:
	for file in mm_rows:
		var src: Node3D = load(file).instantiate()
		var parts: Array = src.find_children("*", "MeshInstance3D", true, false)
		if src is MeshInstance3D:
			parts.append(src)
		for p in parts:
			var mi := p as MeshInstance3D
			var local_xf: Transform3D = src.global_transform.affine_inverse() * mi.global_transform if src.is_inside_tree() else _rel(src, mi)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mi.mesh
			mm.instance_count = mm_rows[file].size()
			for i in mm.instance_count:
				mm.set_instance_transform(i, mm_rows[file][i] * local_xf)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 140.0
			geo.add_child(mmi)
		src.queue_free()
	mm_rows.clear()


func _rel(root: Node3D, child: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = child
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _perch(parent: Node3D, at: Vector3, plaza := false) -> void:
	var m := Marker3D.new()
	parent.add_child(m)
	m.position = at
	if plaza:
		plaza_perches.append(m)
	else:
		perches.append(m)


func _tilted(parent: Node3D, at: Vector3, size: Vector3, color: Color, rot: Vector3, solid := false) -> MeshInstance3D:
	var b := box(parent, at, size, color, false)
	b.rotation = rot
	if solid:
		b.create_trimesh_collision()
	return b


func _blood(parent: Node3D, at: Vector3, s: float = 1.0) -> void:
	var b := box(parent, at + Vector3(0, 0.035, 0), Vector3(1.3, 0.01, 0.9) * Vector3(s, 1, s), Color("4a1714"), false)
	b.rotation.y = rng.randf_range(0, TAU)
	var m: StandardMaterial3D = b.material_override
	m.roughness = 0.25
	for i in 3:
		var d := box(parent, at + Vector3(rng.randf_range(-1, 1) * s, 0.034, rng.randf_range(-1, 1) * s), Vector3(0.25, 0.01, 0.2) * s, Color("561b17"), false)
		d.rotation.y = rng.randf_range(0, TAU)


func _puddle(parent: Node3D, at: Vector3) -> void:
	var p := asset(parent, "Prop_Puddle_0%d" % rng.randi_range(1, 2), at + Vector3(0, 0.05, 0), rng.randf_range(0, TAU), false, Vector3.ONE * rng.randf_range(0.5, 1.0))
	_puddle_material(p)


func _fire(parent: Node3D, at: Vector3, big := false) -> void:
	# fusto che brucia: luce arancione che tremola, fiamme (quadrati emissivi) e fumo
	asset(parent, "Prop_Barrel_Metal_01", at, rng.randf_range(0, TAU), true)
	for i in 3:
		var f := box(parent, at + Vector3(rng.randf_range(-0.15, 0.15), 1.15 + i * 0.12, rng.randf_range(-0.15, 0.15)), Vector3(0.28, 0.32, 0.28) * (1.0 - i * 0.25), Color("ff9a3a"), false)
		f.rotation.y = i * 0.7
		var m: StandardMaterial3D = f.material_override
		m.emission_enabled = true
		m.emission = Color("ff7a1f")
		m.emission_energy_multiplier = 3.0
	var light := OmniLight3D.new()
	parent.add_child(light)
	light.position = at + Vector3(0, 1.6, 0)
	light.light_color = Color("ff9a45")
	light.omni_range = 9.0 if big else 6.5
	light.light_energy = 2.2
	light.set_meta("base", 2.2)
	fires.append(light)
	var smoke := Props.smoke(parent, at + Vector3(0, 1.5, 0), 0.9, 0.35, 16)
	smoke.lifetime = 4.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0.12, 0.3, 0)


func _sandbags(parent: Node3D, at: Vector3, length: float, yaw: float, rows: int = 2) -> void:
	var g := _node(parent, at, yaw)
	var count := int(length / 0.7)
	for r in rows:
		for i in count:
			var x := -length * 0.5 + 0.35 + i * 0.7 + (0.35 if r % 2 else 0.0)
			if x > length * 0.5:
				continue
			var b := box(g, Vector3(x, 0.16 + r * 0.27, 0), Vector3(0.66, 0.28, 0.42), Color("8a7d5c").darkened(rng.randf_range(0, 0.18)), false)
			b.rotation.y = rng.randf_range(-0.08, 0.08)
	box(g, Vector3(0, rows * 0.15, 0), Vector3(length, rows * 0.3, 0.42), Color.TRANSPARENT, true).visible = false


func _fence_line(parent: Node3D, a: Vector3, b: Vector3, broken := 0.15) -> void:
	var dir := b - a
	var count := int(dir.length() / 2.5)
	var yaw := atan2(dir.x, dir.z)
	for i in count:
		if rng.randf() < broken:
			continue
		var at := a + dir.normalized() * (i * 2.5 + 2.5)
		var f := _glb(parent, BK + "SM_Borgo_Fence_Wood.glb", at, yaw, 1.0, true)
		if rng.randf() < 0.12:
			f.rotation.z = rng.randf_range(-0.35, 0.35)


func _crate(parent: Node3D, at: Vector3, yaw: float, s: float = 1.0) -> void:
	var g := _node(parent, at, yaw)
	box(g, Vector3(0, 0.35 * s, 0), Vector3(0.9, 0.7, 0.7) * s, Color("7b5d3b"), true)
	for x in [-0.42, 0.42]:
		box(g, Vector3(x * s, 0.35 * s, 0), Vector3(0.06, 0.72, 0.72) * s, Color("5a4228"), false)
	box(g, Vector3(0, 0.71 * s, 0), Vector3(0.92, 0.03, 0.72) * s, Color("5a4228"), false)


func _junk(parent: Node3D, at: Vector3) -> void:
	# piccoli dettagli che si ripetono: sacchi, scatole, bottiglie, latte, carte
	match rng.randi_range(0, 7):
		0: asset(parent, "Prop_Bag_01", at, rng.randf_range(0, TAU), false, Vector3.ONE * rng.randf_range(4, 6))
		1: asset(parent, "Prop_CardboardBox_Stack_01", at, rng.randf_range(0, TAU), true, Vector3.ONE * rng.randf_range(0.6, 0.9))
		2: _lay(asset(parent, "Prop_Bottle_01", at, rng.randf_range(0, TAU), false), 0.05)
		3: asset(parent, "Prop_PaintCan_01", at, rng.randf_range(0, TAU), false)
		4: asset(parent, "Prop_Papers_01", at + Vector3(0, 0.03, 0), rng.randf_range(0, TAU), false, Vector3.ONE * 0.6)
		5: asset(parent, "Prop_Pallet_01", at, rng.randf_range(0, TAU), true)
		6: asset(parent, "Prop_GasCan_01", at, rng.randf_range(0, TAU), false)
		_: _crate(parent, at, rng.randf_range(0, TAU), rng.randf_range(0.7, 1.0))


func _pole(parent: Node3D, at: Vector3, yaw: float) -> Vector3:
	# palo della luce in legno con traversa e isolatori; ritorna il punto dove attaccare i fili
	var g := _node(parent, at, yaw)
	box(g, Vector3(0, 4.0, 0), Vector3(0.24, 8.0, 0.24), Color("4d3f2d"), true)
	box(g, Vector3(0, 7.4, 0), Vector3(1.9, 0.16, 0.16), Color("4d3f2d"), false)
	for x in [-0.8, 0.0, 0.8]:
		box(g, Vector3(x, 7.58, 0), Vector3(0.08, 0.2, 0.08), Color("b9c3b4"), false)
	if rng.randf() < 0.3:
		box(g, Vector3(0.0, 6.3, 0.2), Vector3(0.5, 0.6, 0.35), Color("5c615b"), false)   # trasformatore
	return at + Vector3(0, 7.62, 0)


func _wires(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var side := (b - a).cross(Vector3.UP).normalized()
	for k in [-0.8, 0.0, 0.8]:
		var p0 = a + side * k
		var p1 = b + side * k
		var mid = (p0 + p1) * 0.5 - Vector3(0, 0.6, 0)        # cavo che pende
		Props.rod(parent, p0, mid, 0.015, Color("1f2220"))
		Props.rod(parent, mid, p1, 0.015, Color("1f2220"))


func _streetlamp(parent: Node3D, at: Vector3, yaw: float) -> void:
	var g := _node(parent, at, yaw)
	Props.cylinder(g, Vector3(0, 2.4, 0), 0.07, 4.8, Color("3e4644"), 0.5).create_convex_collision()
	box(g, Vector3(0, 4.8, 0.45), Vector3(0.12, 0.1, 0.9), Color("3e4644"), false)
	box(g, Vector3(0, 4.72, 0.85), Vector3(0.35, 0.12, 0.45), Color("2d3332"), false)
	box(g, Vector3(0, 4.65, 0.85), Vector3(0.28, 0.02, 0.36), Color("c8c6b0"), false)
	if rng.randf() < 0.25:
		g.rotation.z = rng.randf_range(-0.12, 0.12)       # palo storto


func _bench(parent: Node3D, at: Vector3, yaw: float) -> void:
	var g := _node(parent, at, yaw)
	box(g, Vector3(0, 0.45, 0), Vector3(1.8, 0.08, 0.45), Color("6e5435"), true)
	box(g, Vector3(0, 0.8, -0.2), Vector3(1.8, 0.35, 0.06), Color("6e5435"), false)
	for x in [-0.75, 0.75]:
		box(g, Vector3(x, 0.22, 0), Vector3(0.08, 0.45, 0.45), Color("2f3533"), false)


func _mailbox(parent: Node3D, at: Vector3, yaw: float) -> void:
	var g := _node(parent, at, yaw)
	box(g, Vector3(0, 0.55, 0), Vector3(0.08, 1.1, 0.08), Color("4b4134"), true)
	box(g, Vector3(0, 1.18, 0), Vector3(0.28, 0.24, 0.45), Color("a03a2c" if rng.randf() < 0.5 else "4f6a6a"), false)


func _laundry(parent: Node3D, a: Vector3, b: Vector3) -> void:
	for p in [a, b]:
		box(parent, p + Vector3(0, 1.0, 0), Vector3(0.08, 2.0, 0.08), Color("4b4134"), true)
	Props.rod(parent, a + Vector3(0, 1.95, 0), b + Vector3(0, 1.95, 0), 0.01, Color("d8d4c4"))
	var cloth := [Color("b8b2a0"), Color("7d8f9a"), Color("9a5a4a"), Color("c7c09a"), Color("5f6f52")]
	var n := int(a.distance_to(b) / 0.7)
	for i in range(1, n):
		if rng.randf() < 0.3:
			continue
		var at := a.lerp(b, float(i) / n) + Vector3(0, 1.62, 0)
		var c := box(parent, at, Vector3(0.5, rng.randf_range(0.45, 0.75), 0.02), cloth[rng.randi_range(0, cloth.size() - 1)], false)
		c.rotation.y = atan2((b - a).x, (b - a).z) + PI / 2


func _flat_roof(h: Node3D, w: int, y: float, plaza: bool) -> void:
	# Il modulo è 3.39 x 3.39 (da -0.19 a 3.2, da -3.19 a 0.2): uno solo, stirato su tutto il tetto.
	var sx := (w * 3 + 0.38) / 3.39
	var sz := 9.38 / 3.39
	asset(h, "Bld_Roof_Flat_Closed_01", Vector3(-w * 1.5 - 0.19 + 0.19 * sx, y, 4.69 - 0.2 * sz), 0, true, Vector3(sx, 1, sz))
	var top := y + 0.22
	var c := Color("5d5f55")
	box(h, Vector3(0, top + 0.3, 4.6), Vector3(w * 3 + 0.3, 0.6, 0.25), c, true)
	box(h, Vector3(0, top + 0.3, -4.6), Vector3(w * 3 + 0.3, 0.6, 0.25), c, true)
	for s in [-1, 1]:
		box(h, Vector3(s * (w * 1.5 + 0.02), top + 0.3, 0), Vector3(0.25, 0.6, 9.3), c, true)
	asset(h, "Prop_Warehouse_Venting_01", Vector3(1.5, top + 0.66, -2.5), 0, false)   # la mesh scende a -0.66
	if rng.randf() < 0.6:
		asset(h, "Prop_Powerbox_01", Vector3(-w * 1.5 + 1.2, top, -3.0), 0, true)
	_perch(h, Vector3(-w * 0.75, top + 0.1, 1.5), plaza)
	_perch(h, Vector3(w * 0.75, top + 0.1, 0.5), plaza)


func _boarded(h: Node3D, w: int, door_i: int) -> void:
	# assi inchiodate sulle finestre della facciata (non su tutte, mai sulla porta: le case con porta si visitano)
	for i in w:
		if rng.randf() < 0.45 or i == door_i:
			continue
		var x := -w * 1.5 + i * 3 + 1.5
		for k in 2:
			_tilted(h, Vector3(x, 1.55 + k * 0.35, 4.72), Vector3(1.5, 0.18, 0.05), Color("7b5d3b").darkened(rng.randf_range(0, 0.25)), Vector3(0, 0, rng.randf_range(-0.35, 0.35)))


## Profondità (lato verso il muro) e altezza dei mobili del kit, per appoggiarli al muro senza entrarci.
const DEPTH := {"Prop_Shelf_Preset_01": 0.5, "Prop_Shelf_01": 0.5, "Prop_Cabinets_01": 0.59, "Prop_Table_Metal_01": 0.88,
	"Prop_Office_Desk_01": 0.92, "Prop_CardboardBox_Stack_01": 1.53, "Prop_Office_Shelf_01": 0.44, "Prop_Sink_01": 0.79, "Prop_Chair_01": 0.54}
## Mobili alti: non davanti alle finestre.
const TALL := ["Prop_Shelf_Preset_01", "Prop_Shelf_01", "Prop_Office_Shelf_01", "Prop_Cabinets_01"]
## Misure di casa (il kit è da banco): tavolo e scrivania a ~0.75 m, piano cucina a 0.9, seduta a 0.45.
const HOME_SCALE := {"Prop_Table_Metal_01": 0.82, "Prop_Office_Desk_01": 0.78, "Prop_Sink_01": 0.89, "Prop_Chair_01": 0.92}
const INNER := 4.33           # faccia interna del muro di fondo e mezza larghezza interna = w*1.5 - 0.17


## Coricato su un fianco (ruota attorno all'origine a terra): rialzato di mezza larghezza, così non affonda.
func _lay(n: Node3D, half: float) -> Node3D:
	n.rotation.z = PI / 2
	n.position.y += half
	return n


func _interior(h: Node3D, w: int, shop: bool, kit: Array = []) -> void:
	var first := h.get_child_count()
	var side := w * 1.5 - 0.17
	var bed := not shop and rng.randf() < 0.6
	# posti: lungo il muro di fondo (uno per modulo) e sui due fianchi verso la facciata
	var spots := []
	for x in range(w):
		if bed and x == w - 1:
			continue                                  # in fondo a destra c'è il letto
		spots.append(Vector3(-w * 1.5 + x * 3 + 1.5, 0.08, -INNER))
	spots.append(Vector3(-side, 0.08, 0.5))
	spots.append(Vector3(side, 0.08, 0.5))
	var pool := ["Prop_Shelf_Preset_01", "Prop_Shelf_01", "Prop_Cabinets_01", "Prop_Table_Metal_01", "Prop_Office_Desk_01", "Prop_CardboardBox_Stack_01"] if shop 		else ["Prop_Table_Metal_01", "Prop_Cabinets_01", "Prop_Office_Shelf_01", "Prop_Sink_01", "Prop_Chair_01", "Prop_CardboardBox_Stack_01"]
	if not kit.is_empty(): pool = kit
	for s in spots:
		if rng.randf() < 0.25:
			continue
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		var back: bool = s.z < -3
		# finestre (_walls): a metà dei fianchi e, sul fondo, i moduli dispari contati da destra
		if id in TALL and (not back or (w - 1 - int((s.x + w * 1.5) / 3.0)) % 2 == 1):
			id = "Prop_Table_Metal_01"
		var d: float = DEPTH[id] * 0.5
		var at: Vector3 = s + (Vector3(0, 0, d) if back else Vector3(-signf(s.x) * d, 0, 0))
		var n := asset(h, id, at, 0.0 if back else (PI / 2 if s.x < 0 else -PI / 2), true)
		if not shop and HOME_SCALE.has(id):
			n.scale.y = HOME_SCALE[id]
		if rng.randf() < 0.15 and id == "Prop_Chair_01":
			_lay(n, 0.25)
	# per terra, nel mezzo della stanza (lontano dai mobili): carte, bottiglie, libri caduti, sangue
	for i in 4:
		var at := Vector3(rng.randf_range(-side + 1.2, side - 1.2), 0.09, rng.randf_range(-0.8, 3))
		match rng.randi_range(0, 3):
			0: asset(h, "Prop_Papers_01", at, rng.randf_range(0, TAU), false, Vector3.ONE * 0.5)
			1: _lay(asset(h, "Prop_Bottle_01", at, rng.randf_range(0, TAU), false), 0.05)
			2:
				var books := asset(h, "Prop_Book_Group_01", at + Vector3(0, 0.12, 0), rng.randf_range(0, TAU), false)
				books.rotation.x = PI / 2                     # caduti sul dorso, non in fila sul pavimento
			_: _blood(h, at - Vector3(0, 0.02, 0), 0.6)
	if bed:
		# letto (come nell'alloggio di servizio), in fondo a destra contro i due muri
		var bx := side - 0.66
		box(h, Vector3(bx, 0.3, -INNER + 1.11), Vector3(1.3, 0.45, 2.2), Color("413e31"))
		box(h, Vector3(bx, 0.58, -INNER + 1.11), Vector3(1.25, 0.18, 2.1), Color("6f7560"))
		box(h, Vector3(bx, 0.71, -INNER + 0.4), Vector3(0.8, 0.15, 0.45), Color("b5ac89"), false)
	# dentro casa il sole non arriva: niente passaggio d'ombra per i mobili
	for i in range(first, h.get_child_count()):
		_no_sun_shadow(h.get_child(i))


func _no_sun_shadow(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_no_sun_shadow(c)


## casa modulare (come quelle del rifugio): w = 2..4 moduli da 3 m, profonda 9 m, facciata verso +Z locale
func _home(at: Vector3, yaw: float, w: int, style: int) -> void:
	var h := _node(geo, at, yaw, "Casa")
	var metal := style == 2
	var hs := 1.0 if style != 3 else 1.25
	_floor(h, w, 3)
	_walls(h, w, 3, metal, hs)
	var door_i := w / 2
	for i in w:
		var x0 := -w * 1.5 + i * 3
		if i == door_i:
			if metal:
				box(h, Vector3(x0 + 1.5, 2.3 + (3 * hs - 2.3) * 0.5, 4.5), Vector3(3, 3 * hs - 2.3, 0.22), Color("4c5d5b"), true)
				if w >= 4:
					continue                                      # officina: portone aperto
				asset(h, "Bld_Metal_Door_01", Vector3(x0 + 2.88, 0, 4.5), -PI / 2, true)   # anta aperta contro lo stipite: il vano resta libero
			else:
				asset(h, "Bld_Wall_Brick_Door_01", Vector3(x0, 0, 4.5), 0, true, Vector3(1, hs, 1))
		else:
			asset(h, "Bld_Wall_Metal_Window_01" if metal else "Bld_Wall_Brick_Window_01", Vector3(x0, 0, 4.5), 0, true, Vector3(1, hs, 1))
	if style == 4:
		# casa bruciata: il tetto è crollato, restano le capriate annerite, fuliggine sui muri, brace dentro
		for i in w + 1:
			var tr := asset(h, "Bld_Roof_Truss_01", Vector3(-w * 1.5 + i * 3, 3 * hs, 4.5), 0, false)
			_char(tr)
			if rng.randf() < 0.4:
				tr.rotation.z = rng.randf_range(-0.5, 0.5)
		for i in 6:
			var sx := rng.randf_range(-w * 1.5 + 0.3, w * 1.5 - 1.0)
			box(h, Vector3(sx, rng.randf_range(1.9, 2.6), 4.68), Vector3(rng.randf_range(0.6, 1.3), rng.randf_range(0.6, 1.4), 0.02), Color("2b2725"), false)
		box(h, Vector3(0, 0.1, 0), Vector3(w * 3 - 0.5, 0.04, 8), Color("2a2622"), false)
		for i in 6:
			_tilted(h, Vector3(rng.randf_range(-w, w), 0.3, rng.randf_range(-3, 1)), Vector3(0.22, 0.22, rng.randf_range(2.0, 4.0)), Color("231f1a"),   # lontano dalla porta
				Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3)), i < 2)
		if rng.randf() < 0.6:
			_fire(h, Vector3(rng.randf_range(-w, w), 0.08, rng.randf_range(-2, 1)))
	elif style == 1:
		_flat_roof(h, w, 3 * hs, false)
	else:
		_roof(h, w, 3 * hs + 0.05)
		if rng.randf() < 0.6:
			# comignolo: canna fumaria dal pavimento contro il muro di sinistra fino a 1 m sopra la falda
			# (la falda è più sottile della pendenza sotto il comignolo: una base sospesa si vedeva da dentro)
			var top := 3 * hs + 0.05 + 2.3
			box(h, Vector3(-w * 1.5 + 0.52, (0.08 + top) * 0.5, -1.8), Vector3(0.7, top - 0.08, 0.7), Color("6d4a3a"), true)
	var door_x := -w * 1.5 + door_i * 3 + 1.5
	_entry_ramp(h, 2.2, door_x)
	h.set_meta("door_x", door_x)                 # per i controlli di navigazione (tests/borgo_solid_checks.gd)
	if not metal:
		asset(h, "Bld_Exterior_Shade_01", Vector3(door_x, 2.7, 4.8), 0, false, Vector3(1.1, 0.7, 1))
	if rng.randf() < 0.6:
		_boarded(h, w, door_i)
	_interior(h, w, metal and w >= 4)              # officina: niente letto
	if metal and w >= 4:
		# officina: ruote, banco, macchina sul ponte
		asset(h, "Prop_Shelf_Preset_01", Vector3(w * 1.5 - 0.6, 0.08, -1.8), -PI / 2, true)
		for i in 3:
			var wheel := MeshInstance3D.new()
			h.add_child(wheel)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.24
			ring.outer_radius = 0.4
			wheel.mesh = ring
			wheel.position = Vector3(-w * 1.5 + 1.0, 0.25 + i * 0.28, 3.2)
			wheel.material_override = Props.material(Color("252e2b"))
		if rng.randf() < 0.7:
			_glb(h, BK + "SM_Borgo_Car_Wreck.glb", Vector3(0, 0.08, -0.5), PI / 2 + rng.randf_range(-0.1, 0.1))
	# davanti: cassetta della posta, vaso di fiori o un sacco
	_mailbox(h, Vector3(-w * 1.5 + door_i * 3 + 3.2, 0, 6.3), 0)
	if rng.randf() < 0.5:
		_scatter(NATURE + ("Flower_3_Group.gltf" if rng.randf() < 0.5 else "Flower_4_Group.gltf"), Vector3(-w * 1.5 + 0.8, 0, 5.6), rng.randf_range(0.5, 0.8))
	if rng.randf() < 0.5:
		_junk(h, Vector3(w * 1.5 - 0.8, 0.0, 5.8))


func _ruin(at: Vector3, yaw: float, w: int) -> void:
	# casa bruciata e crollata: pavimento, muri spezzati, travi carbonizzate, macerie
	var h := _node(geo, at, yaw, "Rudere")
	_floor(h, w, 3)
	for i in w:
		if rng.randf() < 0.7:
			asset(h, "Bld_Wall_Brick_01" if i % 2 else "Bld_Wall_Brick_Window_01", Vector3(w * 1.5 - i * 3, 0, -4.5), PI, true, Vector3(1, rng.randf_range(0.45, 1.0), 1))
	for s in [-1, 1]:
		asset(h, "Bld_Wall_Brick_01", Vector3(s * w * 1.5, 0, -4.5 if s < 0 else 1.5), -s * PI / 2, true, Vector3(1, rng.randf_range(0.5, 0.95), 1))
	for i in 5:
		_tilted(h, Vector3(rng.randf_range(-w, w), 0.4, rng.randf_range(-3, 3)), Vector3(0.25, 0.25, rng.randf_range(2.5, 5.0)), Color("231f1a"),
			Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), rng.randf_range(-0.2, 0.2)), i < 2)
	for i in 14:
		var r := box(h, Vector3(rng.randf_range(-w * 1.4, w * 1.4), 0.15, rng.randf_range(-4, 4)), Vector3(0.6, 0.3, 0.45) * rng.randf_range(0.5, 1.4), Color("7a5c48").lerp(Color("5c5a52"), rng.randf()), false)
		r.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0, TAU), rng.randf_range(-0.4, 0.4))
	box(h, Vector3(0, 0.1, 0), Vector3(w * 3 - 0.5, 0.04, 8), Color("2a2622"), false)       # cenere
	if rng.randf() < 0.5:
		_fire(h, Vector3(rng.randf_range(-w, w), 0.08, rng.randf_range(-2, 2)))
	for i in 4:
		_scatter(NATURE + "Grass_Wispy_Tall.gltf", Vector3(rng.randf_range(-w * 1.5, w * 1.5), 0.08, rng.randf_range(-4, 4)), rng.randf_range(0.6, 1.0))


func _shed(parent: Node3D, at: Vector3, yaw: float) -> void:
	var s := _node(parent, at, yaw, "Capanno")
	for x in [-1.3, 1.3]:
		for z in [-1.0, 1.0]:
			box(s, Vector3(x, 1.1, z), Vector3(0.12, 2.2, 0.12), Color("4d3f2d"), false)
	box(s, Vector3(0, 1.1, -1.05), Vector3(2.7, 2.2, 0.08), Color("6e5435"), true)
	for sx in [-1, 1]:
		box(s, Vector3(sx * 1.35, 1.1, 0), Vector3(0.08, 2.2, 2.1), Color("665036"), true)
	_tilted(s, Vector3(0, 2.35, 0), Vector3(3.0, 0.08, 2.6), Color("4c5d5b"), Vector3(0.12, 0, 0), true)
	asset(s, "Prop_Woodstack_01", Vector3(0, 0, 0.2), PI / 2, false, Vector3(0.9, 1, 0.45))
	if rng.randf() < 0.5:
		asset(s, "Prop_GasCan_01", Vector3(0.8, 0, -0.6), 0, false)
