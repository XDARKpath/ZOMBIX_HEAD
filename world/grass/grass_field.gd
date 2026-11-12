extends Node3D
# Prato GPU della Zona 1 (porting MIT di AndreVallestero/godot-grass-shader, vedi
# art/grass/ATTRIBUTION.md). Ciuffi, sottobosco, cespugli e fiori in un quadrato che segue il
# giocatore (LAYERS); l'altezza arriva dalla stessa griglia della mesh del terreno, la densità
# da una maschera che lascia spogli strade, edifici, acqua, arene e chiazze di terra.
# La maschera viene condivisa con lo shader del terreno, che dipinge la terra battuta.
const Route := preload("res://world/campaign/route.gd")
const RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
const Village := preload("res://world/villaggio/villaggio_layout.gd")
const ROWS := 170
const SPACING := 0.34
# Prolungamento asfaltato verso il lago (terrain.gd, _road_end): non fa parte
# della route, quindi va escluso esplicitamente dalla maschera dell'erba.
const ROAD_END_A := Vector2(6.0, -6.5)
const ROAD_END_B := Vector2(6.0, 2.6)
const CELL := 8.0
const ORIGIN := Vector2(-296, -560)    # multipli di 8: coincide con la griglia del terreno (a ovest arriva fino alla Rocca)
const SIZE := Vector2(560, 600)
const MASK_STEP := 2.0

# Specie del prato, come un prato vero e non un tappeto: ogni strato ha la sua
# pianta CC0 (art/nature), il suo colore, la sua altezza e le sue macchie (band =
# fascia del rumore in cui cresce), così le specie si alternano a gruppi.
const LAYERS := [
	{"mesh": "Grass_Common_Tall", "rows": 120, "spacing": 0.4, "height": 0.5, "band": Vector2(0.0, 1.0), "keep": 1.0, "color": Color(0.50, 0.52, 0.27), "seed": 0.0},
	{"mesh": "Grass_Wispy_Tall", "rows": 80, "spacing": 0.58, "height": 0.62, "band": Vector2(0.42, 1.0), "keep": 1.0, "color": Color(0.72, 0.67, 0.42), "seed": 0.17},
	{"mesh": "Grass_Common_Short", "rows": 72, "spacing": 0.6, "height": 0.24, "band": Vector2(0.0, 0.55), "keep": 1.0, "color": Color(0.30, 0.36, 0.14), "seed": 0.31},
	{"mesh": "Plant_1", "rows": 64, "spacing": 0.9, "height": 0.35, "band": Vector2(0.0, 1.0), "keep": 0.35, "color": Color(0.26, 0.32, 0.12), "seed": 0.53},
	{"mesh": "Clover_1", "rows": 64, "spacing": 0.9, "height": 0.18, "band": Vector2(0.0, 0.6), "keep": 0.45, "color": Color(0.30, 0.34, 0.14), "seed": 0.71},
	# Sottobosco rado, ognuno nelle sue macchie (offset): felci, piante a foglia larga, rosette basse.
	{"mesh": "Fern_1", "rows": 40, "spacing": 1.5, "height": 0.4, "keep": 0.1, "color": Color(0.22, 0.36, 0.14), "seed": 0.23, "offset": 37.0, "lean": 0.08},
	{"mesh": "Plant_1_Big", "rows": 36, "spacing": 1.7, "height": 0.55, "keep": 0.07, "color": Color(0.28, 0.40, 0.16), "seed": 0.41, "offset": 81.0, "lean": 0.08},
	{"mesh": "Plant_7_Big", "rows": 40, "spacing": 1.4, "height": 0.14, "keep": 0.12, "color": Color(0.30, 0.42, 0.18), "seed": 0.59, "offset": 123.0, "lean": 0.0},
	# Piccoli cespugli a gruppetti (il modello è rosso: qui prende il verde del prato). Non fermano chi cammina.
	{"look": "bush", "mesh": "Bush_Common", "rows": 30, "spacing": 2.4, "height": 0.7, "keep": 0.07, "color": Color(0.20, 0.33, 0.13), "seed": 0.63, "offset": 211.0, "lean": 0.05, "stiff": 0.3},
	# Fiori CC0 con i loro colori: pochi, a macchie.
	{"look": "flower", "mesh": "Flower_3_Group", "rows": 64, "spacing": 0.9, "height": 0.5, "keep": 0.3, "seed": 0.89, "lean": 0.1},
	{"look": "flower", "mesh": "Flower_4_Single", "rows": 44, "spacing": 1.3, "height": 0.42, "keep": 0.18, "seed": 0.47, "offset": 150.0, "lean": 0.1},
	# Prato lontano: ciuffi da sei triangoli fino a 47 m, vuoti vicino a te dove ci sono quelli veri. Senza, l'erba finiva a 20 m.
	{"look": "far", "rows": 104, "spacing": 0.95, "height": 0.5, "keep": 1.0, "seed": 0.07, "inner": 15.0, "lean": 0.15},
]
# VEGETAZIONE (basso, medio, alto, ultra): moltiplica le righe di ogni strato.
const QUALITY_SCALE := [0.55, 0.75, 0.9, 1.2]
# Chi apre l'erba camminando: giocatori e gli zombie più vicini (raggio in metri).
const PUSHERS := 8
const PLAYER_PUSH := 0.8
const ZOMBIE_PUSH := 0.65

var world: Node3D
var layers: Array[GPUParticles3D] = []
var density_texture: ImageTexture
var process: ShaderMaterial

func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "GrassField"
	var heights := _height_image()
	var mask := _density_image()
	density_texture = ImageTexture.create_from_image(mask)
	add_to_group("grass_field")
	process = ShaderMaterial.new()
	process.shader = preload("res://world/grass/grass_particles.gdshader")
	process.set_shader_parameter("heights", ImageTexture.create_from_image(heights))
	process.set_shader_parameter("height_origin", ORIGIN)
	process.set_shader_parameter("height_cell", CELL)
	process.set_shader_parameter("height_size", Vector2i(heights.get_width(), heights.get_height()))
	process.set_shader_parameter("density", density_texture)
	process.set_shader_parameter("bounds", Vector4(ORIGIN.x, ORIGIN.y, SIZE.x, SIZE.y))
	for spec in LAYERS:
		var mesh := _mesh_for(spec)
		var p: ShaderMaterial = process.duplicate()
		p.set_shader_parameter("spacing", spec.spacing)
		p.set_shader_parameter("keep", spec.keep)
		p.set_shader_parameter("patch_band", spec.get("band", Vector2(0.0, 1.0)))
		p.set_shader_parameter("seed_shift", spec.seed)
		p.set_shader_parameter("patch_offset", spec.get("offset", 0.0))
		p.set_shader_parameter("lean", spec.get("lean", 0.22))
		p.set_shader_parameter("inner", spec.get("inner", 0.0))
		p.set_shader_parameter("stiff", spec.get("stiff", 1.0))
		p.set_shader_parameter("scale_range", Vector2(0.75, 1.25) * (spec.height / maxf(mesh.get_aabb().size.y, 0.01)))
		p.set_shader_parameter("tall_range", Vector2(0.7, 1.25))
		var view := _particles(p, mesh)
		view.set_meta("spec", spec)
		layers.append(view)
	var settings = world.get("settings_data")
	set_quality(int(settings.get("vegetation", 2)) if settings is Dictionary else 2)
	# Il terreno usa la stessa maschera: dove manca l'erba compare terra battuta.
	var ground: ShaderMaterial = world.terrain.ground_material
	ground.set_shader_parameter("grass_mask", density_texture)
	ground.set_shader_parameter("mask_bounds", Vector4(ORIGIN.x, ORIGIN.y, SIZE.x, SIZE.y))

func _particles(p: ShaderMaterial, mesh: Mesh) -> GPUParticles3D:
	var view := GPUParticles3D.new()
	# Mai rinascere (a fine vita il prato lampeggiava) e calcolo a ogni fotogramma, senza
	# interpolare: la piega intorno a chi cammina segue liscia anche oltre i 30 fps.
	view.lifetime = 86400.0
	view.explosiveness = 1.0
	view.fixed_fps = 0
	view.interpolate = false
	view.local_coords = false
	view.process_material = p
	view.draw_pass_1 = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.visibility_aabb = AABB(Vector3(-55, -40, -55), Vector3(110, 120, 110))
	add_child(view)
	return view

func _process(_delta: float) -> void:
	if world and is_instance_valid(world.player):
		global_position = world.player.global_position * Vector3(1, 0, 1)
		_update_pushers()

## Giocatori e zombie vicini piegano l'erba: solo grafica, ogni macchina usa le posizioni che già vede.
func _update_pushers() -> void:
	var list := PackedVector4Array()
	var me: Vector3 = world.player.global_position
	var actors = world.get("actors")
	var bodies: Array = actors.values() if actors is Dictionary and not actors.is_empty() else [world.player]
	for body in bodies:
		if list.size() < PUSHERS and is_instance_valid(body) and body.is_inside_tree():
			list.append(_pusher(body.global_position, PLAYER_PUSH))
	var near: Array = []
	for t in world.get("targets") if world.get("targets") is Array else []:
		if is_instance_valid(t) and t.is_inside_tree():
			var d: float = me.distance_squared_to(t.global_position)
			if d < 900.0: near.append([d, t.global_position])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for z in near:
		if list.size() >= PUSHERS: break
		list.append(_pusher(z[1], ZOMBIE_PUSH))
	list.resize(PUSHERS)
	for view in layers:
		view.process_material.set_shader_parameter("pushers", list)

static func _pusher(at: Vector3, radius: float) -> Vector4:
	return Vector4(at.x, at.y, at.z, radius)

## La mesh di uno strato: ciuffo a colore piatto, fiore con i suoi materiali, cespuglio a foglie, filo d'erba lontano.
func _mesh_for(spec: Dictionary) -> Mesh:
	var look: String = spec.get("look", "")
	if look == "far":
		var blades := tuft_mesh()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://world/grass/grass_blade.gdshader")
		mat.set_shader_parameter("albedo_tex", preload("res://art/grass/grass_diffuse_1024.png"))
		mat.set_shader_parameter("green_a", Color(0.36, 0.42, 0.18))
		mat.set_shader_parameter("green_b", Color(0.50, 0.52, 0.26))
		mat.set_shader_parameter("dry", Color(0.66, 0.61, 0.38))
		blades.surface_set_material(0, mat)
		return blades
	if look == "":
		return tuft(spec.mesh, spec.color)
	var source: Node3D = load("res://art/nature/" + spec.mesh + ".gltf").instantiate()
	var found: MeshInstance3D = source.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: ArrayMesh = found.mesh.duplicate() if look == "bush" else found.mesh
	source.free()
	if look == "bush":
		for s in mesh.get_surface_count():
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://world/grass/bush_lowpoly.gdshader")
			var original := mesh.surface_get_material(s) as BaseMaterial3D
			if original: mat.set_shader_parameter("leaf", original.albedo_texture)
			mat.set_shader_parameter("base_color", spec.color)
			mat.set_shader_parameter("mesh_height", mesh.get_aabb().size.y)
			mesh.surface_set_material(s, mat)
	return mesh

# VEGETAZIONE: meno piante e raggio più corto sulle macchine lente; al minimo niente fiori.
func set_quality(level: int) -> void:
	var factor: float = QUALITY_SCALE[clampi(level, 0, QUALITY_SCALE.size() - 1)]
	for view in layers:
		var spec: Dictionary = view.get_meta("spec")
		view.visible = level > 0 or not spec.get("look", "") in ["flower", "bush"]
		var rows := int(spec.rows * factor)
		if view.amount == rows * rows: continue
		view.process_material.set_shader_parameter("rows", rows)
		view.process_material.set_shader_parameter("radius", rows * spec.spacing * 0.48)
		view.amount = rows * rows
		view.restart()

static func tuft(id: String, color: Color) -> ArrayMesh:
	var source: Node3D = load("res://art/nature/" + id + ".gltf").instantiate()
	var found: MeshInstance3D = source.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: ArrayMesh = found.mesh.duplicate()
	source.free()
	for s in mesh.get_surface_count():
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://world/grass/grass_lowpoly.gdshader")
		var original := mesh.surface_get_material(s) as BaseMaterial3D
		mat.set_shader_parameter("base_color", original.albedo_color.lerp(color, 0.95) if original else color)
		mat.set_shader_parameter("mesh_height", mesh.get_aabb().size.y)
		mesh.surface_set_material(s, mat)
	return mesh

static func tuft_mesh() -> ArrayMesh:
	# Tre quadrilateri incrociati con la texture del ciuffo (base a v = 0.64).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.36
	var h := 0.66
	for k in 3:
		var a := k * PI / 3.0
		var side := Vector3(cos(a), 0, sin(a)) * w
		var quad := [[-side, Vector2(0.18, 0.64)], [side, Vector2(0.86, 0.64)], [side + Vector3.UP * h, Vector2(0.86, 0.0)], [-side + Vector3.UP * h, Vector2(0.18, 0.0)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(quad[idx][1])
			st.add_vertex(quad[idx][0])
	return st.commit()

func _height_image() -> Image:
	var cols := int(SIZE.x / CELL) + 1
	var rows := int(SIZE.y / CELL) + 1
	var image := Image.create(cols, rows, false, Image.FORMAT_RF)
	for z in rows:
		for x in cols:
			var px: float = ORIGIN.x + x * CELL
			var pz: float = ORIGIN.y + z * CELL
			image.set_pixel(x, z, Color(world.terrain.height(px, pz), 0, 0))
	return image

static func density_at(x: float, z: float, clumps: FastNoiseLite) -> float:
	if z > 10.5: return 0.0
	if Layout.occupied(x, z): return 0.0
	var p := Vector2(x, z)
	# L'erba arriva al ciglio dell'asfalto: niente più spalle grigie o strisce
	# verdi artificiali. La transizione è breve e irregolare grazie al rumore.
	var road: float = minf(Route.road_distance(p) - 3.55, RoadNet.distance(p) - 3.4)
	road = minf(road, _segment_distance(p, ROAD_END_A, ROAD_END_B) - 3.7)
	var d := smoothstep(0.0, 0.45, road)
	d *= smoothstep(5.0, 9.0, RoadNet.arena_distance(p))
	if Layout.yard(Vector3(x, 0, z)): d *= 0.25
	if Village.corridor(x, z): return 0.0
	# Attorno alla torre l'erba arriva fino ai muri.
	d *= smoothstep(6.5, 8.0, p.distance_to(Vector2(RoadNet.SITES["dungeon"].x - 3.0, RoadNet.SITES["dungeon"].z)))
	# Chiazze di terra e ciuffi più fitti: il prato non è un tappeto uniforme.
	var n := clumps.get_noise_2d(x, z)
	d *= smoothstep(-0.8, -0.55, n)
	return clampf(d * (0.75 + 0.25 * smoothstep(0.1, 0.5, n)), 0.0, 1.0)

static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _density_image() -> Image:
	var clumps := FastNoiseLite.new()
	clumps.seed = 4417
	clumps.frequency = 0.045
	var w := int(SIZE.x / MASK_STEP)
	var h := int(SIZE.y / MASK_STEP)
	var image := Image.create(w, h, false, Image.FORMAT_L8)
	for z in h:
		for x in w:
			var px: float = ORIGIN.x + (x + 0.5) * MASK_STEP
			var pz: float = ORIGIN.y + (z + 0.5) * MASK_STEP
			image.set_pixel(x, z, Color(density_at(px, pz, clumps), 0, 0))
	return image
