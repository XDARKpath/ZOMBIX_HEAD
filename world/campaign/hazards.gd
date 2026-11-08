extends Node3D
# Posti contaminati della Zona 1: chi ci entra accumula radiazioni. Valgono il rischio, c'è sempre roba da prendere in mezzo.
# Il disegno è uguale per tutti i giocatori; le radiazioni le decide l'host (player/status_effects.gd).

## centro (x, z), raggio, radiazioni al secondo, nome
const SITES := [
	[Vector2(102, -96), 12.0, 7.0, "LA GOLA"],
	[Vector2(57, -281), 11.0, 9.0, "IL SERBATOIO DEL BORGO"],
]
const Props := preload("res://ui/camp/camp_props.gd")
const BARREL := "res://art/zx_borgo/SM_Prop_Barrel_Metal_01.glb"
var world: Node3D
var _tick := 0.0
var _warned := false


func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "Hazards"
	for site in SITES: _site(site)


func _site(site: Array) -> void:
	var at: Vector2 = site[0]
	var radius: float = site[1]
	var root := Node3D.new()
	root.name = "Contaminato"
	add_child(root)
	root.position = Vector3(at.x, world.terrain.height(at.x, at.y), at.y)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color("9dff4a")
	glow_mat.emission_enabled = true
	glow_mat.emission = Color("6dff3a")
	glow_mat.emission_energy_multiplier = 0.55
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color.a = 0.75
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 7.0 + at.y * 3.0)
	for i in 6:
		var angle := rng.randf() * TAU
		var r := rng.randf_range(1.2, radius * 0.5)
		var spot := Vector3(cos(angle) * r, 0, sin(angle) * r)
		var barrel: Node3D = load(BARREL).instantiate()
		root.add_child(barrel)
		barrel.position = spot
		barrel.rotation = Vector3(rng.randf_range(-0.2, 0.2) if i % 3 else PI / 2.0, rng.randf() * TAU, 0)
		var puddle := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = rng.randf_range(0.7, 1.4)
		disc.bottom_radius = disc.top_radius
		disc.height = 0.015
		disc.radial_segments = 12
		disc.rings = 0
		puddle.mesh = disc
		puddle.material_override = glow_mat
		root.add_child(puddle)
		puddle.position = spot + Vector3(0.5, 0.03, 0.3)
	# Cartelli di pericolo attorno al posto.
	for i in 4:
		var angle := TAU * float(i) / 4.0 + 0.4
		var post := Node3D.new()
		root.add_child(post)
		post.position = Vector3(cos(angle), 0, sin(angle)) * (radius + 1.5)
		post.rotation.y = -angle + PI / 2.0
		Props.box(post, Vector3(0, 0.9, 0), Vector3(0.09, 1.8, 0.09), Color("4b4134"))
		var label := Label3D.new()
		label.text = "☢ RADIAZIONI"
		label.font_size = 42
		label.pixel_size = 0.006
		label.outline_size = 10
		label.modulate = Color("ffd23a")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		post.add_child(label)
		label.position.y = 1.95
	var light := OmniLight3D.new()
	light.light_color = Color("7dff4a")
	light.light_energy = 2.2
	light.omni_range = radius + 3.0
	root.add_child(light)
	light.position.y = 1.6
	var fumes := CPUParticles3D.new()
	fumes.amount = 40
	fumes.lifetime = 3.2
	fumes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fumes.emission_box_extents = Vector3(radius * 0.65, 0.1, radius * 0.65)
	fumes.direction = Vector3.UP
	fumes.spread = 12.0
	fumes.gravity = Vector3(0, 0.15, 0)
	fumes.initial_velocity_min = 0.15
	fumes.initial_velocity_max = 0.5
	# Vapore morbido: una macchia sfumata rivolta sempre verso chi guarda, non una palla piena.
	var puff := QuadMesh.new()
	puff.size = Vector2(1.5, 1.5)
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 64
	soft.height = 64
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 1.0, 0.35, 0.2))
	ramp.set_color(1, Color(0.55, 1.0, 0.35, 0.0))
	soft.gradient = ramp
	var fog := StandardMaterial3D.new()
	fog.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fog.albedo_texture = soft
	fog.no_depth_test = false
	puff.material = fog
	fumes.mesh = puff
	root.add_child(fumes)
	fumes.position.y = 0.4


func _process(delta: float) -> void:
	if not world or not world.started: return
	_tick -= delta
	if _tick > 0.0: return
	_tick = 0.25
	var host: bool = not Session.online or multiplayer.is_server()
	for actor in world.actors.values():
		if not is_instance_valid(actor) or actor.dead or actor.global_position.y > 150.0: continue
		var flat := Vector2(actor.global_position.x, actor.global_position.z)
		var inside := false
		for site in SITES:
			if flat.distance_to(site[0]) <= float(site[1]):
				inside = true
				if host: actor.status.add_radiation(float(site[2]) * 0.25)
				if actor == world.player and not _warned:
					_warned = true
					world.announce("%s · RADIAZIONI · Esci in fretta: le cura solo il kit medico" % site[3], 5)
		actor.status.in_radiation = inside
		if actor == world.player and not inside: _warned = false
