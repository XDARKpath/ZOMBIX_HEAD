extends Node3D
# Lago della Zona 1: acqua (Boujie Water Shader, MIT, art/water/ATTRIBUTION.md), pontile e
# barca a remi fatti in Blender (tools/lake/build_lake_props.py), riva con canne e sassi.
# Il pontile parte dal piazzale di fine strada (terrain.gd) e finisce con una piattaforma a T.
const DOCK_ORIGIN := Vector3(6, 0.18, 10.4)   # attacco a riva; il piano è a y=0.18
const DOCK_LENGTH := 14.6                       # fino al bordo della piattaforma finale
const FISHING_SPOT := Vector3(5.2, 0.18, 23.4)
const BOAT_AT := Vector3(8.75, 0.06, 16.8)    # pescaggio ~20 cm: il bordo resta fuori dall'acqua
const Terrain := preload("res://world/campaign/terrain.gd")
var water: MeshInstance3D
var boat: Node3D
var clock := 0.0

func build(parent: Node3D) -> void:
	name = "Lake"
	parent.add_child(self)
	_water()
	_dock()
	_boat()
	_shore()

func _water() -> void:
	water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(350, 180)
	plane.subdivide_width = 175
	plane.subdivide_depth = 90
	water.mesh = plane
	water.position = Vector3(0, -0.23, 100)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# Lo shader MIT legge profondità e schermo: in OpenGL resta l'acqua semplice.
		var simple := ShaderMaterial.new()
		simple.shader = preload("res://world/zona1_rifugio/water.gdshader")
		water.material_override = simple
	else:
		water.material_override = lake_material()
	add_child(water)

static func _pad(values: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array(values)
	while out.size() < 8: out.append(0.0)
	return out

static func lake_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://art/water/boujie_water.gdshader")
	var p := {
		"albedo": Color(0.09, 0.2, 0.2, 0.5), "albedo_fresnel": Color(0.32, 0.42, 0.42, 0.85),
		"albedo_snell": Color(0.12, 0.22, 0.22, 0.9), "specular": 0.5, "roughness": 0.12, "metallic": 0.0,
		"vertex_displace_from_mesh_normal": true, "normal_wave_from_mesh_normal": true,
		"texture_albedo": preload("res://art/water/ocean_albedo_1.png"),
		"texture_refraction": preload("res://art/water/refraction.png"), "refraction": 0.05,
		"refraction_texture_channel": Vector4(1, 0, 0, 0), "refraction_opacity": 0.65,
		"texture_foam": preload("res://art/water/foam_1.png"), "shore_start_blend": 0.0, "shore_end_blend": 0.55,
		"distance_fade_min": 600.0, "distance_fade_max": 900.0, "near_fade_min": 0.0, "near_fade_max": 0.01,
		"foam_fade_min": 60.0, "foam_fade_max": 160.0, "shore_fade_min": 80.0, "shore_fade_max": 200.0,
		"vertex_wave_fade_min": 80.0, "vertex_wave_fade_max": 220.0, "depth_fog_fade_min": 150.0, "depth_fog_fade_max": 300.0,
		"refraction_scaling_distance_min": 40.0, "uv_blend_sharpness": 2.0, "uv_tri_scale": Vector3(14, 14, 14),
		"uv_tri_offset": Vector3.ZERO, "color_deep": Color(0.03, 0.085, 0.09, 0.92), "color_shallow": Color(0.13, 0.24, 0.21, 0.35),
		"beers_law": 0.9, "depth_offset": -0.2, "snell_direction": Vector3(0, 1, 0), "snell_tightness": 0.7,
		# Lago: onde corte e basse, non oceano.
		"WaveCount": 4, "WaveSteepnesses": _pad([0.06, 0.04, 0.03, 0.02]), "WaveAmplitudes": _pad([0.5, 0.4, 0.3, 0.3]),
		"WaveDirectionsDegrees": _pad([20, 110, 250, 320]), "WaveFrequencies": _pad([0.08, 0.14, 0.22, 0.3]),
		"WaveSpeeds": _pad([0.9, 1.3, 1.6, 2.0]), "WavePhases": _pad([0, 0, 0, 0]),
		"FoamWaveCount": 1, "FoamWaveSteepnesses": _pad([0.12]), "FoamWaveAmplitudes": _pad([1.0]),
		"FoamWaveDirectionsDegrees": _pad([30]), "FoamWaveFrequencies": _pad([0.03]), "FoamWaveSpeeds": _pad([0.3]), "FoamWavePhases": _pad([0]),
		"UVWaveCount": 2, "UVWaveSteepnesses": _pad([0.02, 0.015]), "UVWaveAmplitudes": _pad([0.7, 0.5]),
		"UVWaveDirectionsDegrees": _pad([315, 90]), "UVWaveFrequencies": _pad([0.5, 0.3]), "UVWaveSpeeds": _pad([0.4, 0.25]),
		"UVWavePhases": _pad([0, 0]),
	}
	for key in p: m.set_shader_parameter(key, p[key])
	return m

func _dock() -> void:
	var dock: Node3D = load("res://art/lake/SM_Lake_Dock.glb").instantiate()
	dock.name = "Pontile"
	add_child(dock)
	dock.position = DOCK_ORIGIN
	dock.rotation.y = PI   # in Blender il pontile va verso +Y, qui verso il largo (+Z)
	for mesh in dock.find_children("*", "MeshInstance3D", true, false):
		mesh.create_trimesh_collision()
	# Rampa di assi dal piazzale al piano del pontile (0,18 m da salire senza scalino).
	var ramp := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 0.06, 1.5)
	ramp.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6b4f34")
	mat.roughness = 0.9
	ramp.material_override = mat
	add_child(ramp)
	ramp.position = DOCK_ORIGIN + Vector3(0, -0.1, -0.7)
	ramp.rotation.x = -0.12
	ramp.create_trimesh_collision()
	# La lanterna in fondo al pontile è accesa.
	var light := OmniLight3D.new()
	light.light_color = Color("ffbf6e")
	light.light_energy = 1.6
	light.omni_range = 7.0
	add_child(light)
	light.position = DOCK_ORIGIN + Vector3(-1.95, 1.95, 12.4)

func _boat() -> void:
	boat = load("res://art/lake/SM_Lake_Rowboat.glb").instantiate()
	boat.name = "BarcaARemi"
	add_child(boat)
	boat.position = BOAT_AT
	boat.rotation.y = PI + 0.08
	# Cima dalla bitta del pontile alla prua.
	var rope := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.015
	rope.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("9e8556")
	rope.material_override = mat
	add_child(rope)
	var a := DOCK_ORIGIN + Vector3(1.05, 0.22, 6.0)
	var b := BOAT_AT + Vector3(-0.1, 0.35, 3.3)
	cyl.height = a.distance_to(b)
	rope.position = (a + b) * 0.5
	rope.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))

func _shore() -> void:
	# Canne e sassi lungo la battigia, ai lati del pontile.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6611
	var cache := {}
	for i in 70:
		var x := rng.randf_range(-60, 70)
		if absf(x - 6.0) < 3.5: continue
		# Battigia vera: dove il terreno incontra l'acqua (z≈8.7). Più in là è fondale.
		var z := rng.randf_range(8.2, 9.6)
		var id: String = ["Grass_Wispy_Tall", "Grass_Common_Tall", "Pebble_Round_2", "Rock_Medium_2", "Grass_Wispy_Tall"][i % 5]
		if not cache.has(id): cache[id] = load("res://art/nature/%s.gltf" % id)
		var node: Node3D = cache[id].instantiate()
		add_child(node)
		# Quota dal terreno vero: niente più formula approssimata che li lasciava sospesi.
		var y: float = Terrain.ground_height(x, z)
		node.position = Vector3(x, y - 0.03, z)
		node.rotation.y = rng.randf_range(0, TAU)
		var s := rng.randf_range(0.5, 0.9) if id.begins_with("Grass") else rng.randf_range(0.5, 1.1)
		node.scale = Vector3.ONE * s

func _process(delta: float) -> void:
	clock += delta
	if boat:
		boat.position.y = BOAT_AT.y + sin(clock * 1.1) * 0.035
		boat.rotation.z = sin(clock * 0.8) * 0.035
		boat.rotation.x = sin(clock * 0.6 + 1.0) * 0.02
