# Nodo figlio del mondo. Genera solo elementi visivi, senza collisioni aggiuntive.
extends Node3D
const NATURE := "res://art/nature/"
const FOREST := "res://art/kaykit_forest/"
var world: Node3D
var ambience: AudioStreamPlayer
var clock: float = 0
var sun: DirectionalLight3D
var weather: Environment
var breeze: CPUParticles3D
var nature_cache: Dictionary = {}
var forest_cache: Dictionary = {}
const FOG_BASE := 0.008

func build(owner_world: Node3D) -> void:
	world = owner_world
	for child in world.landscape.get_children():
		if child is WorldEnvironment:
			weather = child.environment
			var sky := Sky.new()
			var sky_material := ShaderMaterial.new()
			sky_material.shader = preload("res://world/zona1_rifugio/sky.gdshader")
			sky.sky_material = sky_material
			if RenderingServer.get_current_rendering_method()!="gl_compatibility": weather.sky = sky
			weather.ambient_light_color = Color("aec8cc")
			weather.ambient_light_energy = 0.38
			weather.fog_light_color = Color("66746f")
			weather.fog_density = FOG_BASE
			weather.glow_enabled = RenderingServer.get_current_rendering_method()!="gl_compatibility"
			# Occlusione ambientale più marcata: gli angoli e gli incastri in pietra
			# devono leggere come volumi solidi anche nella luce piatta del mezzogiorno.
			weather.ssao_enabled = true
			weather.ssao_radius = 1.4
			weather.ssao_intensity = 1.5
			weather.adjustment_enabled = true
			weather.adjustment_contrast = 1.10
			# Toni più spenti: è un mondo dopo l'epidemia, non un parco.
			weather.adjustment_saturation = 0.82
		if child is DirectionalLight3D:
			sun = child
			sun.rotation_degrees = Vector3(-26,-32,0)
			sun.light_color = Color("ffd0a1")
			sun.light_energy = 1.15
	# Erba GPU con licenza MIT (art/grass/ATTRIBUTION.md) al posto del vecchio prato piatto.
	var field := Node3D.new()
	field.set_script(preload("res://world/grass/grass_field.gd"))
	add_child(field)
	field.build(world)
	# Dettagli ai margini: vegetazione bassa, senza rocce decorative.
	scatter_nature()
	scatter_undergrowth()
	if DisplayServer.get_name() != "headless":
		ambience = AudioStreamPlayer.new()
		ambience.stream = AudioManager.loop_stream("res://audio/forest.ogg")
		ambience.volume_db = -8
		add_child(ambience)
		ambience.play()

static func blade_mesh() -> ArrayMesh:
	# Ciuffo di cinque fili d'erba a due segmenti: base larga, punta sottile.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5171
	for blade in range(6):
		var angle := rng.randf_range(0,TAU)
		var lean := rng.randf_range(0.06,0.26)
		var tall := rng.randf_range(0.22,0.44)
		var wide := rng.randf_range(0.010,0.018)
		var origin := Vector3(rng.randf_range(-0.09,0.09),0,rng.randf_range(-0.09,0.09))
		var dir := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-dir.z,0,dir.x)
		var mid := origin+dir*lean*tall*0.5+Vector3.UP*tall*0.55
		var tip := origin+dir*lean*tall+Vector3.UP*tall
		var base_half := side*wide*0.5
		var mid_half := side*wide*0.34
		for point_row in [[origin-base_half,origin+base_half,mid-mid_half,mid+mid_half],[mid-mid_half,mid+mid_half,tip,tip]]:
			var p0:Vector3=point_row[0];var p1:Vector3=point_row[1];var p2:Vector3=point_row[2];var p3:Vector3=point_row[3]
			for p in [p0,p1,p2,p1,p3,p2]:
				st.set_uv(Vector2(0.5,p.y/tall if tall>0.001 else 0.0))
				st.add_vertex(p)
	# Normali verso l'alto: l'erba resta morbida anche con luci basse.
	st.generate_normals()
	return st.commit()

static func grass(parent: Node3D, count: int, width: float, depth: float, center: Vector3, field: bool) -> void:
	var mesh := blade_mesh()
	var material := ShaderMaterial.new()
	material.shader = preload("res://world/zona1_rifugio/grass.gdshader")
	mesh.surface_set_material(0,material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 992 if field else 182
	var used := 0
	for i in range(count):
		var x := rng.randf_range(-width,width)+center.x
		var z := rng.randf_range(-depth*0.5,depth*0.5)+center.z
		if field:
			if preload("res://world/zona1_rifugio/refuge_layout.gd").occupied(x,z): continue
			if absf(x-6)<(10.5 if z>-74 else 4.2) or z>11: continue
			if preload("res://world/zona1_rifugio/refuge_layout.gd").safe(Vector3(x,0,z)): continue
			if preload("res://world/zona1_rifugio/roadnet.gd").distance(Vector2(x,z))<3.4: continue
			if preload("res://world/zona1_rifugio/roadnet.gd").arena_distance(Vector2(x,z))<14.0: continue
		else:
			if Vector2(x,z).length()<2.8: continue
		var scale_value := rng.randf_range(0.6,1.25)
		var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(scale_value,scale_value*rng.randf_range(0.75,1.2),scale_value))
		multi.set_instance_transform(used,Transform3D(basis,Vector3(x,0.012,z)))
		# Prato verde e uniforme: solo variazioni di tono, nessuna chiazza secca.
		var tint := Color(0.17,0.33,0.10).lerp(Color(0.30,0.44,0.15),rng.randf_range(0.0,0.45))
		tint = tint.lerp(Color(0.12,0.24,0.08),rng.randf_range(0.0,0.30))
		multi.set_instance_color(used,tint)
		used += 1
	multi.visible_instance_count = used
	var view := MultiMeshInstance3D.new()
	view.multimesh = multi
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)

func nature(id: String) -> Node3D:
	if not nature_cache.has(id): nature_cache[id] = load(NATURE+id+".gltf")
	var node: Node3D = nature_cache[id].instantiate()
	return node

func scatter_nature() -> void:
	# Sottobosco vario: felci, trifogli, fiori, funghi e pietre lungo i margini.
	var rng := RandomNumberGenerator.new()
	rng.seed = 91472
	var layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
	# Niente fiori: la zona resta verde, senza macchie rosse o rosa.
	var plants := ["Grass_Common_Short","Grass_Wispy_Short","Grass_Common_Short","Grass_Wispy_Short"]
	for i in range(260):
		var x := rng.randf_range(-95,100)
		var z := rng.randf_range(-215,10)
		if layout.occupied(x,z) or layout.safe(Vector3(x,0,z)): continue
		if absf(x-6)<(11.0 if z>-74 else 4.6): continue
		if preload("res://world/zona1_rifugio/roadnet.gd").distance(Vector2(x,z))<4.0: continue
		if preload("res://world/zona1_rifugio/roadnet.gd").arena_distance(Vector2(x,z))<15.0: continue
		var at := Vector3(x,world.landscape.height(x,z),z)
		var id: String = plants[rng.randi()%plants.size()]
		var node: Node3D = nature(id)
		add_child(node)
		node.position = at
		node.rotation.y = rng.randf_range(0,TAU)
		# Sottobosco basso: felci e piante grandi non devono sembrare alberi.
		var size := rng.randf_range(0.28,0.6)
		node.scale = Vector3(size,size*rng.randf_range(0.9,1.25),size)
func forest(id: String) -> Node3D:
	if not forest_cache.has(id): forest_cache[id] = load(FOREST+id+".gltf")
	return forest_cache[id].instantiate()

func _undergrowth_spot(layout, x: float, z: float) -> bool:
	if layout.occupied(x,z) or layout.safe(Vector3(x,0,z)): return false
	# Marciapiedi, asfalto e arene restano puliti: la vegetazione parte oltre il cordolo.
	if absf(x-6.0)<5.4: return false
	if preload("res://world/zona1_rifugio/roadnet.gd").distance(Vector2(x,z))<4.0: return false
	if preload("res://world/zona1_rifugio/roadnet.gd").arena_distance(Vector2(x,z))<14.5: return false
	return true

func scatter_undergrowth() -> void:
	# Felci e piante Quaternius, senza cespugli quadrati né rocce decorative.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41877
	var layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
	for i in range(110):
		var close := i < 84
		var x := rng.randf_range(-46,50) if close else rng.randf_range(-80,86)
		var z := rng.randf_range(-82,10) if close else rng.randf_range(-140,-64)
		if not _undergrowth_spot(layout,x,z): continue
		var id: String = ["Fern_1","Plant_1_Big","Plant_7","Fern_1"][i%4]
		var node := nature(id)
		add_child(node)
		node.position = Vector3(x,world.landscape.height(x,z)+0.01,z)
		node.rotation.y = rng.randf_range(0,TAU)
		var size := rng.randf_range(0.16,0.30) if id=="Fern_1" else rng.randf_range(0.34,0.62)
		node.scale = Vector3(size,size*rng.randf_range(0.9,1.2),size)

func _tint_forest(node: Node, tint: Color) -> void:
	# Stessa tavolozza verde del resto del bosco: niente cespugli gialli o autunnali.
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var mat = node.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				var copy: StandardMaterial3D = mat.duplicate()
				copy.albedo_color = copy.albedo_color.lerp(tint,0.70)
				node.set_surface_override_material(i,copy)
	for child in node.get_children():
		_tint_forest(child,tint)

static func lantern(parent: Node3D, point: Vector3) -> void:
	# Lanterna da tavolo usata nel campo: piccola, appoggiata, non sospesa.
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12,0.22,0.12)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffcf83")
	mat.emission_enabled = true
	mat.emission = Color("ffaf58")
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	mesh.position = point
	parent.add_child(mesh)
	var light := OmniLight3D.new()
	light.position = point
	light.light_color = Color("ffc27a")
	light.light_energy = 1.2
	light.omni_range = 4.5
	parent.add_child(light)

func _process(delta: float) -> void:
	if not world or not world.started: return
	clock += delta
	# Passaggi di nuvole: variazioni lente, senza cambiare la leggibilità del combattimento.
	if sun: sun.light_energy = 1.1+sin(clock*0.025)*0.12
	# Banchi di nebbia che vanno e vengono.
	if weather: weather.fog_density = FOG_BASE+(sin(clock*0.017)*0.5+0.5)*0.004
