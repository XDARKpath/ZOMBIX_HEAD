extends Node3D
# Palizzata del paese di Lago Cenere: tronchi appuntiti con traverse e puntoni, dentro ci sono sceriffo, Big Earl e il
# 4×4, ed è la zona sicura (refuge_layout.gd: FENCE_MIN, FENCE_MAX). Verso il lago i due lati finiscono nell'acqua.
# I portoni stanno dove le strade attraversano il recinto: si aprono quando arriva un sopravvissuto o il 4×4.

const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
const Terrain := preload("res://world/campaign/terrain.gd")
const Route := preload("res://world/campaign/route.gd")
const RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
const LOG_STEP := 0.3
const HEIGHT := 2.5
const OPEN_DISTANCE := 7.5
const C_WOOD := Color("5a4630")
const C_DARK := Color("3a2d20")

var world: Node3D
var gates: Array = []              # {left, right, body, at, side, open}
var doors_root: Node3D
var _logs: Array = []              # [posizione, altezza, tinta]
var _tips: Array = []


func build(owner_world: Node3D, parent: Node3D) -> void:
	world = owner_world
	name = "TownFence"
	parent.add_child(self)
	doors_root = Node3D.new()
	doors_root.name = "TownGates"
	world.add_child(doors_root)         # fuori dalla regione di navigazione: i portoni non fanno buchi nel navmesh
	var a: Vector2 = Layout.FENCE_MIN
	var b: Vector2 = Layout.FENCE_MAX
	var water := b.y + 6.0
	_side(Vector2(a.x, a.y), Vector2(b.x, a.y), _gaps_on_z(a.y, a.x, b.x), true)
	_side(Vector2(a.x, a.y), Vector2(a.x, water), [Layout.WEST_GATE_Z], false)
	_side(Vector2(b.x, a.y), Vector2(b.x, water), _gaps_on_x(b.x, a.y, b.y), false)
	_flush_logs()


## Dove le strade attraversano il lato nord: un solo portone largo se sono vicine.
func _gaps_on_z(z: float, x0: float, x1: float) -> Array:
	var hits: Array = []
	var lines: Array = RoadNet.paths() + [Route.road_points()]
	for line in lines:
		for i in range(line.size() - 1):
			var p: Vector3 = line[i]
			var q: Vector3 = line[i + 1]
			if (p.z - z) * (q.z - z) < 0.0:
				var x: float = lerpf(p.x, q.x, (z - p.z) / (q.z - p.z))
				if x > x0 and x < x1: hits.append(x)
	hits.sort()
	var out: Array = []
	for x in hits:
		if out.is_empty() or x - out[-1][1] > 9.0: out.append([x, x])
		else: out[-1][1] = x
	return out.map(func(r): return (r[0] + r[1]) * 0.5)


func _gaps_on_x(x: float, z0: float, z1: float) -> Array:
	var hits: Array = []
	for line in RoadNet.paths():
		for i in range(line.size() - 1):
			var p: Vector3 = line[i]
			var q: Vector3 = line[i + 1]
			if (p.x - x) * (q.x - x) < 0.0:
				var z: float = lerpf(p.z, q.z, (x - p.x) / (q.x - p.x))
				if z > z0 and z < z1: hits.append(z)
	return hits


func _ground(p: Vector2) -> float:
	return Terrain.ground_height(p.x, p.y)


## Un lato del recinto da a a b con i varchi dei portoni (coordinata lungo il lato, x se along_x, altrimenti z).
func _side(a: Vector2, b: Vector2, gaps: Array, along_x: bool) -> void:
	var length := a.distance_to(b)
	var dir := (b - a).normalized()
	var half: float = Layout.GATE_WIDTH * 0.5
	var pieces: Array = []
	var cursor := 0.0
	var centers: Array = []
	for g in gaps:
		var along: float = (float(g) - a.x) if along_x else (float(g) - a.y)
		centers.append(along)
	centers.sort()
	for c in centers:
		pieces.append([cursor, c - half])
		cursor = c + half
		_gate(a + dir * c, dir)
	pieces.append([cursor, length])
	for row in pieces:
		if row[1] - row[0] < 0.3: continue
		_wall(a + dir * float(row[0]), a + dir * float(row[1]), dir)


func _wall(from: Vector2, to: Vector2, dir: Vector2) -> void:
	var length := from.distance_to(to)
	var count := int(length / LOG_STEP)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(from.x * 13.0 + from.y * 7.0) + 91
	for i in count:
		var p := from + dir * (float(i) + 0.5) * LOG_STEP
		var h := HEIGHT + rng.randf_range(-0.14, 0.14)
		var y := _ground(p)
		_logs.append([Vector3(p.x, y + h * 0.5 - 0.15, p.y), h, rng.randf_range(0.78, 1.12)])
		_tips.append(Vector3(p.x, y + h - 0.15 + 0.11, p.y))
	# Traverse sul lato interno e puntoni ogni 6 metri.
	var inner := Vector3(-dir.y, 0, dir.x) * _inside_sign(from, dir)
	var mid := (from + to) * 0.5
	var my := _ground(mid)
	var yaw := atan2(-dir.y, dir.x)
	for rail_y in [0.8, 1.9]:
		var rail := _box(Vector3(length, 0.09, 0.07), C_DARK)
		rail.position = Vector3(mid.x, my + rail_y, mid.y) + inner * 0.18
		rail.rotation.y = yaw
	var braces := int(length / 6.0)
	for i in range(1, braces + 1):
		var p := from + dir * (length * float(i) / float(braces + 1))
		var y := _ground(p)
		var foot := Vector3(p.x, y - 0.05, p.y) + inner * 1.25
		var top := Vector3(p.x, y + 2.0, p.y) + inner * 0.2
		var brace := _box(Vector3(0.12, foot.distance_to(top), 0.12), C_DARK)
		var up := (top - foot).normalized()
		var along := Vector3(dir.x, 0, dir.y)
		brace.transform = Transform3D(Basis(along, up, along.cross(up)), (foot + top) * 0.5)
	# Collisione a pezzi da ~3 m che seguono il terreno come i tronchi: dal punto più basso a 3 m sopra il più alto,
	# così non resta luce sotto dove il terreno scende e non si scavalca dove sale.
	var parts := maxi(1, ceili(length / 3.0))
	for k in parts:
		var a := from + dir * (length * k / parts)
		var b := from + dir * (length * (k + 1) / parts)
		var low := minf(minf(_ground(a), _ground(b)), _ground((a + b) * 0.5)) - 0.2
		var high := maxf(maxf(_ground(a), _ground(b)), _ground((a + b) * 0.5)) + 3.0
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = Vector3(length / parts, high - low, 0.4)
		shape.shape = cube
		body.add_child(shape)
		add_child(body)
		body.position = Vector3((a.x + b.x) * 0.5, (low + high) * 0.5, (a.y + b.y) * 0.5)
		body.rotation.y = yaw


func _inside_sign(from: Vector2, dir: Vector2) -> float:
	var center: Vector2 = (Layout.FENCE_MIN + Layout.FENCE_MAX) * 0.5
	var normal := Vector2(-dir.y, dir.x)
	return 1.0 if normal.dot(center - from) > 0.0 else -1.0


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh.material = mat
	mi.mesh = mesh
	add_child(mi)
	return mi


## Tutti i tronchi in due MultiMesh: centinaia di pezzi, due draw call.
func _flush_logs() -> void:
	var log := CylinderMesh.new()
	log.top_radius = 0.14
	log.bottom_radius = 0.16
	log.height = 1.0
	log.radial_segments = 7
	log.rings = 0
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.roughness = 1.0
	log.material = mat
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.14
	tip.height = 0.22
	tip.radial_segments = 7
	tip.rings = 0
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color("6e583c")
	tip_mat.roughness = 1.0
	tip.material = tip_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = log
	mm.instance_count = _logs.size()
	for i in _logs.size():
		var row: Array = _logs[i]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, row[1], 1)), row[0]))
		var c: Color = C_WOOD * float(row[2])
		c.a = 1.0
		mm.set_instance_color(i, c)
	var logs := MultiMeshInstance3D.new()
	logs.multimesh = mm
	add_child(logs)
	var mt := MultiMesh.new()
	mt.transform_format = MultiMesh.TRANSFORM_3D
	mt.mesh = tip
	mt.instance_count = _tips.size()
	for i in _tips.size():
		mt.set_instance_transform(i, Transform3D(Basis(), _tips[i]))
	var tips := MultiMeshInstance3D.new()
	tips.multimesh = mt
	add_child(tips)


## Portone a due ante con torri di legno, tettoia, lanterne e cartello. Le ante girano verso l'interno.
func _gate(at: Vector2, dir: Vector2) -> void:
	var y := _ground(at)
	var center := Vector3(at.x, y, at.y)
	var side := Vector3(dir.x, 0, dir.y)
	var half: float = Layout.GATE_WIDTH * 0.5
	var yaw := atan2(-dir.y, dir.x)
	for s in [-1.0, 1.0]:
		var post := _box(Vector3(0.5, 4.3, 0.5), C_DARK)
		post.position = center + side * (half + 0.1) * s + Vector3.UP * 2.0
		var cap := _box(Vector3(0.9, 0.12, 0.9), C_WOOD)
		cap.position = post.position + Vector3.UP * 2.2
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("ffc070")
		lamp.light_energy = 1.3
		lamp.omni_range = 9.0
		add_child(lamp)
		lamp.position = post.position + Vector3.UP * 1.4
		var glass := _box(Vector3(0.2, 0.28, 0.2), Color("ffcf7a"))
		var gm := glass.mesh.material as StandardMaterial3D
		gm.emission_enabled = true
		gm.emission = Color("ffb35c")
		gm.emission_energy_multiplier = 2.2
		glass.position = post.position + Vector3.UP * 1.2 + side * -0.32 * s
	var beam := _box(Vector3(Layout.GATE_WIDTH + 1.2, 0.34, 0.5), C_DARK)
	beam.position = center + Vector3.UP * 4.0
	beam.rotation.y = yaw
	# Un cartello per lato: da una Label3D a doppia faccia, da dietro, il testo si legge al contrario.
	for face in [0.0, PI]:
		var sign := Label3D.new()
		sign.text = Localization.t("LAGO CENERE · ZONA SICURA")
		sign.font_size = 56
		sign.pixel_size = 0.0065
		sign.outline_size = 12
		sign.modulate = Color("ffe0a8")
		sign.double_sided = false
		add_child(sign)
		sign.rotation.y = yaw + face
		sign.position = center + Vector3.UP * 4.5 + sign.transform.basis.z * 0.27
	var left := _leaf(center - side * half, side, yaw, 1.0)
	var right := _leaf(center + side * half, side, yaw, -1.0)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = Vector3(Layout.GATE_WIDTH, 3.2, 0.3)
	shape.shape = cube
	body.add_child(shape)
	doors_root.add_child(body)
	body.position = center + Vector3.UP * 1.4
	body.rotation.y = yaw
	gates.append({"left": left, "right": right, "shape": shape, "at": center, "yaw": yaw, "open": false,
		"inward": _inside_sign(at, dir)})


func _leaf(hinge: Vector3, side: Vector3, yaw: float, sgn: float) -> Node3D:
	var pivot := Node3D.new()
	doors_root.add_child(pivot)
	pivot.position = hinge
	pivot.rotation.y = yaw
	var width: float = Layout.GATE_WIDTH * 0.5
	var planks := int(width / 0.3)
	for i in planks:
		var plank := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.28, HEIGHT - 0.1 + sin(float(i) * 2.3) * 0.08, 0.08)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = C_WOOD * (0.85 + 0.2 * fposmod(float(i) * 0.37, 1.0))
		mat.albedo_color.a = 1.0
		mesh.material = mat
		plank.mesh = mesh
		pivot.add_child(plank)
		plank.position = Vector3(sgn * (0.15 + float(i) * 0.3), 1.2, 0)
	for rail_y in [0.55, 1.9]:
		var rail := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, 0.14, 0.12)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = C_DARK
		mesh.material = mat
		rail.mesh = mesh
		pivot.add_child(rail)
		rail.position = Vector3(sgn * width * 0.5, rail_y, 0.03)
	return pivot


func _process(_delta: float) -> void:
	if not world or not world.started: return
	for g in gates:
		var near := false
		var at: Vector3 = g.at
		for actor in world.actors.values():
			if is_instance_valid(actor) and not actor.dead and actor.global_position.distance_to(at) < OPEN_DISTANCE: near = true
		if world.get("expedition") and world.expedition.car.global_position.distance_to(at) < OPEN_DISTANCE + 4.0 and world.expedition.car.repaired: near = true
		if near == g.open: continue
		g.open = near
		(g.shape as CollisionShape3D).set_deferred("disabled", near)
		var turn: float = float(g.inward) * 1.45
		var tw := create_tween().set_parallel(true)
		tw.tween_property(g.left, "rotation:y", g.yaw + (turn if near else 0.0), 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(g.right, "rotation:y", g.yaw - (turn if near else 0.0), 0.7).set_trans(Tween.TRANS_SINE)
