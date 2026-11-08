extends Node3D
# Alberi CC0 (Quaternius).
const NATURE := "res://art/nature/"
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
var nature_cache: Dictionary = {}
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var props: Dictionary = {}

func build() -> void:
	rng.seed = 74251
	noise.seed = 281
	noise.frequency = 0.035
	_environment()
	_far_shore()
	# Nessun edificio o relitto: la zona è prato e bosco attorno ai due uffici.
	prop("SM_Tree_Log_01", Vector3(0,0.2,7), 70, true)
	# Lago, pontile e barca: world/zona1_rifugio/lake.gd (acqua MIT, modelli Blender).
	preload("res://world/zona1_rifugio/lake.gd").new().build(self)
	var buildings:=Node3D.new()
	buildings.set_script(preload("res://world/zona1_rifugio/refuge_set.gd"))
	add_child(buildings)
	buildings.build()
	# Bosco attorno alla radura: prima il filtro scartava ogni albero e restavano
	# solo i venti pini del bordo.
	for i in range(220):
		var x := rng.randf_range(-125,130)
		var z := rng.randf_range(-225,11)
		if absf(x-6)<9.5: continue
		# Posto auto del 4×4 accanto all'ufficio dello sceriffo.
		if Vector2(x,z).distance_to(Vector2(19.5,3.6))<6.5: continue
		if preload("res://world/zona1_rifugio/roadnet.gd").distance(Vector2(x,z))<8.5: continue
		if preload("res://world/zona1_rifugio/roadnet.gd").arena_distance(Vector2(x,z))<16.0: continue
		if preload("res://world/zona1_rifugio/refuge_layout.gd").occupied(x,z): continue
		var names := ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"]
		var node := nature_tree(names[i % 5], Vector3(x,height(x,z),z), rng.randf_range(0,360))
		node.scale = Vector3.ONE * rng.randf_range(0.9,1.9)
		# Simple trunk collisions keep tree detail out of the physics broadphase.
		if absf(x) < 45 and z > -60 and i%4==0:
			box(Vector3(0.5,4,0.5), node.position+Vector3.UP*2, Color.TRANSPARENT)
	# Il prato ora è l'erba GPU (world/grass/grass_field.gd): niente più centinaia di
	# ciuffi-modello sparsi a mano.
	for i in range(20):
		var x: float = (-27.0 if i%2 else 31.0)+rng.randf_range(-4,4)
		var z := rng.randf_range(-45,9)
		# Reserve canopy clearance as well as trunk clearance around the workshop.
		if preload("res://world/zona1_rifugio/refuge_layout.gd").safe(Vector3(x,0,z)):continue
		if preload("res://world/zona1_rifugio/refuge_layout.gd").occupied(x,z): continue
		var tree := nature_tree("Pine_3" if i%2 else "Pine_1",Vector3(x,height(x,z),z),rng.randf_range(0,360))
		tree.scale = Vector3.ONE*rng.randf_range(1.0,1.7)

func foliage(id: String, at: Vector3, yaw: float = 0, sway: float = 0.06, fade: float = 0.55) -> Node3D:
	# Erba e fiori veri (CC0), senza desaturazione: sono il colore del prato.
	if not nature_cache.has(id): nature_cache[id] = load(NATURE + id + ".gltf")
	var node: Node3D = nature_cache[id].instantiate()
	add_child(node)
	node.position = at
	node.rotation.y = yaw
	_sway(node,sway,fade)
	return node

func _sway(node: Node, strength: float, fade: float = 0.22) -> void:
	# Un solo shader per tutta la vegetazione bassa: il vento passa sopra il prato
	# come un'onda, invece di muovere ogni cespuglio per conto suo.
	if node is MeshInstance3D and node.mesh != null:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://world/zona1_rifugio/foliage_wind.gdshader")
		var tex: Texture2D = null
		var tint := Color(0.88,0.90,0.80)
		for i in node.mesh.get_surface_count():
			var base = node.mesh.surface_get_material(i)
			if base is StandardMaterial3D:
				if base.albedo_texture != null: tex = base.albedo_texture
				tint = base.albedo_color
				break
		if tex != null: mat.set_shader_parameter("albedo_tex",tex)
		else: mat.set_shader_parameter("use_texture",false)
		mat.set_shader_parameter("tint",tint)
		var h: float = maxf(node.mesh.get_aabb().size.y,0.12)
		mat.set_shader_parameter("bend_start",h*0.16)
		mat.set_shader_parameter("bend_height",h*0.78)
		mat.set_shader_parameter("sway",strength)
		mat.set_shader_parameter("fade",fade)
		mat.set_shader_parameter("speed",1.35+strength*3.0)
		node.material_override = mat
	for child in node.get_children(): _sway(child,strength,fade)

func _meadow() -> void:
	# Solo ciuffi d'erba: niente fiori, la zona resta completamente verde.
	var meadow:=RandomNumberGenerator.new();meadow.seed=9137
	for i in range(160):
		var x:=meadow.randf_range(-48,48)
		var z:=meadow.randf_range(-78,12)
		if absf(x-Layout.ROAD_X)<4.6: continue
		if Layout.occupied(x,z) or Layout.safe(Vector3(x,0,z)): continue
		var g:=foliage("Grass_Common_Short" if i%2 else "Grass_Wispy_Short",Vector3(x,height(x,z)+0.02,z),meadow.randf_range(0,TAU),0.04,0.3)
		g.scale=Vector3.ONE*meadow.randf_range(0.34,0.52)

func nature_tree(id: String, at: Vector3, yaw: float = 0) -> Node3D:
	if not nature_cache.has(id): nature_cache[id] = load(NATURE + id + ".gltf")
	var node: Node3D = nature_cache[id].instantiate()
	add_child(node)
	node.position = at
	node.rotation.y = deg_to_rad(yaw)
	_mute_nature(node)
	return node

func _mute_nature(node: Node) -> void:
	# Stessa desaturazione dei pini del terreno, così il bosco resta uniforme.
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat = node.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				var copy: StandardMaterial3D = mat.duplicate()
				copy.albedo_color = copy.albedo_color.lerp(Color(0.20,0.36,0.17),0.80)
				node.set_surface_override_material(i,copy)
	for child in node.get_children():
		_mute_nature(child)

func prop(asset: String, at: Vector3, yaw: float = 0, collision: bool = false) -> Node3D:
	# Il nome dice che pezzo serve: sostituto CC0 o segnaposto procedurale.
	var node := _proxy(asset)
	add_child(node)
	node.position = at
	node.rotation.y = deg_to_rad(yaw)
	if collision: _colliders(node)
	return node

func _proxy(asset: String) -> Node3D:
	var P := preload("res://art/placeholders.gd")
	if asset.begins_with("SM_Tree_") and not "Log" in asset:
		var tree: Node3D = load(NATURE + "Pine_1.gltf").instantiate()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://world/zona1_rifugio/tree.gdshader")
		_apply_material(tree,mat)
		return tree
	if "Log" in asset: return P.log()
	if "Rock" in asset: return P.rock()
	if "Grass" in asset: return load(NATURE + "Grass_Common_Short.gltf").instantiate()
	if "Bush" in asset or "Plant" in asset: return load(NATURE + "Grass_Common_Short.gltf").instantiate()
	if "House" in asset:
		var house: Node3D = load("res://art/kaykit_city/building_E.gltf").instantiate()
		house.scale = Vector3.ONE * 4.0
		return house
	if "Truck" in asset or "Veh" in asset:
		var car: Node3D = load("res://art/kaykit_city/car_sedan.gltf").instantiate()
		car.scale = Vector3.ONE * 4.0
		return car
	if "Tent" in asset: return P.tent()
	if "Barrel" in asset: return P.barrel()
	if "Dock_Poles" in asset: return P.log()
	if "Dock" in asset:
		var dock := Node3D.new()
		P.box(dock,Vector3(0,0.06,0),Vector3(2.6,0.12,5.0),Color("5b5242"))
		return dock
	var fallback := Node3D.new()
	P.box(fallback,Vector3(0,0.3,0),Vector3(0.8,0.6,0.8),Color("4f4a3c"))
	return fallback

func _apply_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D: node.material_override = mat
	for child in node.get_children(): _apply_material(child,mat)

func _colliders(node: Node) -> void:
	if node is MeshInstance3D:
		node.create_trimesh_collision()
	for child in node.get_children():
		if not child is StaticBody3D: _colliders(child)

func box(size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	body.add_child(shape)
	if color.a > 0:
		var view := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		view.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		view.material_override = mat
		body.add_child(view)
	return body

func height(x: float,z: float) -> float:
	# Stesso rilievo della mesh del terreno: prima gli alberi seguivano un'altra
	# funzione e restavano sospesi o sepolti ai bordi della radura.
	if z > 14: return -2.5
	return preload("res://world/campaign/terrain.gd").ground_height(x,z)

func _terrain() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(350,180)
	plane.subdivide_width = 90
	plane.subdivide_depth = 60
	water.mesh = plane
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://world/zona1_rifugio/water.gdshader")
	water.material_override = shader
	water.position = Vector3(0,-0.23,100)
	# L'acqua non proietta ombre: evita l'acne a scacchiera sulle onde.
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(water)

func _environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2a424d")
	sky_mat.sky_horizon_color = Color("9aabae")
	sky_mat.ground_horizon_color = Color("9aabae")
	sky_mat.ground_bottom_color = Color("323e3c")
	sky.sky_material = sky_mat
	if RenderingServer.get_current_rendering_method()!="gl_compatibility": e.sky = sky
	else:
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color("839994")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("a0b9c9")
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Nebbia da zombie: il bosco sparisce a 60-80 m e una foschia bassa resta a terra.
	e.fog_enabled = true
	e.fog_light_color = Color("6d7c78")
	e.fog_density = 0.011
	e.fog_sky_affect = 0.75
	e.fog_aerial_perspective = 0.35
	e.fog_height = 3.0
	e.fog_height_density = 0.09
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		e.volumetric_fog_enabled = true
		e.volumetric_fog_density = 0.012
		e.volumetric_fog_albedo = Color("a9b3ae")
		e.volumetric_fog_length = 70.0
		e.volumetric_fog_ambient_inject = 0.5
		e.volumetric_fog_sky_affect = 0.4
	e.ssao_enabled = RenderingServer.get_current_rendering_method()=="forward_plus"
	e.ssao_radius = 1.6
	e.ssao_intensity = 1.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24,-35,0)
	sun.light_color = Color("ffe1bc")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

func _ridge_height(x: float, z: float) -> float:
	# Sponda lontana: colline morbide che salgono dall'acqua, non picchi isolati.
	var t := clampf((z - 76.0) / 30.0, 0.0, 1.0)
	var peak := 9.0 + noise.get_noise_2d(x * 0.5, 152.0) * 12.0 + noise.get_noise_2d(x * 1.7, 88.0) * 4.5
	var profile := sin(t * PI * 0.9)
	return -1.4 + maxf(profile, 0.0) * peak + t * 3.0

func _far_shore() -> void:
	var rows: Array[float] = [76.0, 84.0, 92.0, 100.0, 110.0, 122.0, 136.0]
	var cols: int = 101
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rows.size()):
		for c in range(cols):
			var x := -200.0 + c * 4.0
			var z: float = rows[r]
			var h := _ridge_height(x, z)
			st.set_color(Color("2c3d3a").lerp(Color("55695f"), clampf(h / 26.0, 0.0, 1.0)))
			st.add_vertex(Vector3(x, h, z))
	for r in range(rows.size() - 1):
		for c in range(cols - 1):
			var a := r * cols + c
			var b := a + 1
			var d := a + cols
			var e := d + 1
			st.add_index(a); st.add_index(d); st.add_index(b)
			st.add_index(b); st.add_index(d); st.add_index(e)
	st.index()
	st.generate_normals()
	var ridge := MeshInstance3D.new()
	ridge.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ridge.material_override = mat
	add_child(ridge)

func _fishing_props() -> void:
	# Barca e canna procedurali: niente mesh di provenienza sconosciuta.
	var P := preload("res://art/placeholders.gd")
	var boat: Node3D = P.boat()
	add_child(boat)
	boat.position = Vector3(8.6,-0.10,18.4)
	boat.rotation.y = -PI/2
	var rod: Node3D = P.fishing_rod()
	add_child(rod)
	rod.position = Vector3(5.6,0.15,18.6)
	rod.rotation.y = 0.3
