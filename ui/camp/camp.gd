extends Node3D
# Dieci skin del ZX Player (art/zx_player, Batch2): nomi e descrizioni da ZXPlayer.SKINS.
const MODELS := ["ZX_SKIN_0","ZX_SKIN_1","ZX_SKIN_2","ZX_SKIN_3","ZX_SKIN_4","ZX_SKIN_5","ZX_SKIN_6","ZX_SKIN_7","ZX_SKIN_8","ZX_SKIN_9"]
const NAMES := ["OPERATIVE","SCAVENGER","TACTICIAN","VETERAN","MECHANIC","FISHERMAN","HAZMAT","ASTRONAUT","BANANA","CHICKEN"]
const SKIN_COUNT := 10
const MenuAssets := preload("res://ui/camp/menu_assets.gd")
const Placeholder := preload("res://art/placeholders.gd")
var avatars: Array[Node3D] = []
var camera: Camera3D
var fire: OmniLight3D
var moon: DirectionalLight3D
var timer: float = 0
var crackle: AudioStreamPlayer3D
var skin_ids: Array[int] = [-1,-1,-1,-1]

func build() -> void:
	position = Vector3(200,0,0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(45,45)
	ground.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = load("res://world/zona1_rifugio/ground.gdshader")
	ground.material_override = material
	add_child(ground)
	for i in range(16):
		var tree: Node3D = MenuAssets.model("tree-pinetalla-detailed",6.5)
		tree.position = Vector3(cos(i*0.6)*9,0,-5-absf(sin(i*0.6))*8)
		tree.scale = Vector3.ONE*(1.3+float(i%4)*0.35)
		add_child(tree)

	MenuAssets.place(self,"campfire-stones",Vector3(0,0,0.3),1.35,0.0,0)
	preload("res://ui/camp/camp_vehicle.gd").build(self)
	var shared_log: Node3D = load("res://art/camp_blender/camp_log.glb").instantiate()
	shared_log.name="SharedCampLog"
	shared_log.position=Vector3(1.70,0.28,-0.08)
	shared_log.rotation.y=0.90
	shared_log.scale=Vector3(0.85,1.0,0.95)
	add_child(shared_log)
	for i in range(4):
		avatars.append(null)
		set_skin(i,[0,1,3,4][i])
	var flames := CPUParticles3D.new()
	flames.name = "FireFlames"
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.amount = 26
	flames.lifetime = 0.75
	flames.preprocess = 2
	flames.direction = Vector3.UP
	flames.spread = 12
	flames.gravity = Vector3(0,0.5,0)
	flames.initial_velocity_min = 0.3
	flames.initial_velocity_max = 0.4
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.22
	var quad := QuadMesh.new()
	quad.size = Vector2(0.36,0.44)
	flames.mesh = quad
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = load("res://ui/camp/flame.gdshader")
	flames.material_override = flame_mat
	flames.position = Vector3(0,0.2,0.3)
	add_child(flames)
	var sparks := CPUParticles3D.new()
	sparks.name = "WorldEmbers"
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.position = Vector3(0,0.5,0.3)
	sparks.amount = 16
	sparks.lifetime = 2.2
	sparks.preprocess = 2.2
	sparks.direction = Vector3.UP
	sparks.spread = 18
	sparks.gravity = Vector3(0,0.3,0)
	sparks.initial_velocity_min = 0.4
	sparks.initial_velocity_max = 0.9
	var ember := SphereMesh.new()
	ember.radius = 0.012
	ember.height = 0.024
	var ember_mat := StandardMaterial3D.new()
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mat.albedo_color = Color("ffbe56")
	ember_mat.emission_enabled = true
	ember_mat.emission = Color("ff7e24")
	ember.material = ember_mat
	sparks.mesh = ember
	add_child(sparks)
	if DisplayServer.get_name() != "headless" and ResourceLoader.exists("res://audio/fire.ogg"):
		crackle = AudioStreamPlayer3D.new()
		crackle.stream = AudioManager.loop_stream("res://audio/fire.ogg")
		crackle.position = Vector3(0,0.3,0.3)
		crackle.volume_db = -3
		crackle.unit_size = 5
		add_child(crackle)
	fire = OmniLight3D.new()
	fire.name = "FireLight"
	fire.position = Vector3(0,0.85,0.3)
	fire.light_color = Color("ff9d40")
	fire.omni_range = 9
	fire.light_energy = 4.5
	fire.shadow_enabled = true
	fire.light_size = 0.08
	add_child(fire)
	var portrait_light := OmniLight3D.new()
	portrait_light.name = "PortraitFill"
	portrait_light.position = Vector3(0.5,3.0,4.5)
	portrait_light.light_color = Color("b1c5d0")
	portrait_light.light_energy = 1.1
	portrait_light.omni_range = 8
	portrait_light.light_size = 1.5
	add_child(portrait_light)
	moon = DirectionalLight3D.new()
	moon.name = "MoonFill"
	moon.rotation_degrees = Vector3(-38,100,0)
	moon.light_color = Color("6c98bb")
	moon.light_energy = 0.7
	add_child(moon)
	camera = Camera3D.new()
	camera.name = "MenuCamera"
	add_child(camera)
	camera.position = Vector3(0,2.7,8.3)
	camera.look_at(global_position+Vector3(-1.65,0.95,-0.1))
	camera.fov = 46
	var lens := CameraAttributesPractical.new()
	lens.dof_blur_far_enabled = RenderingServer.get_current_rendering_method()!="gl_compatibility"
	lens.dof_blur_far_distance = 12
	lens.dof_blur_far_transition = 6
	lens.dof_blur_amount = 0.08
	camera.attributes = lens
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111f2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("708396")
	env.ambient_light_energy = 0.23
	var reflection_sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("152d40")
	sky_material.sky_horizon_color = Color("677d86")
	sky_material.ground_bottom_color = Color("131b1a")
	sky_material.ground_horizon_color = Color("6c6353")
	reflection_sky.sky_material = sky_material
	env.sky = reflection_sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = RenderingServer.get_current_rendering_method()!="gl_compatibility"
	env.ssao_enabled = RenderingServer.get_current_rendering_method()=="forward_plus"
	env.fog_enabled = true
	env.fog_density = 0.032
	env.fog_light_color = Color("172e38")
	camera.environment = env
	preload("res://world/zona1_rifugio/atmosphere.gd").grass(self,3000,12,17,Vector3(0,0,-2),false)
	MenuAssets.supplies(self)
	_batch_props()
	preload("res://world/zona1_rifugio/atmosphere.gd").lantern(self,Vector3(0.5,0.6,-2.6))
	var rim := OmniLight3D.new()
	rim.position = Vector3(0,3,-4)
	rim.light_color = Color("8bafc5")
	rim.light_energy = 2.1
	rim.omni_range = 7
	add_child(rim)

func _batch_props() -> void:
	# Kit ambiente e armi v2 dei batch ZOMBIX attorno al falò, infetti nella nebbia.
	var env := "res://art/env/"
	var chest: Node3D = load(env+"interactive/SM_Int_Chest_Military.glb").instantiate()
	add_child(chest);chest.position=Vector3(-3.7,0,-1.7);chest.rotation.y=0.45
	for n in chest.find_children("*_Lid","MeshInstance3D",true,false):n.rotation.x=-1.75
	var supply: Node3D = load(env+"interactive/SM_Int_Chest_Supply.glb").instantiate()
	add_child(supply);supply.position=Vector3(-4.7,0,0.4);supply.rotation.y=1.2
	var crate: Node3D = load(env+"interactive/SM_Int_Crate_Destructible.glb").instantiate()
	add_child(crate);crate.position=Vector3(4.6,0.53,1.2);crate.rotation.y=0.3
	var ammo: Node3D = load(env+"shop/SM_Prop_AmmoCrate_Wood.glb").instantiate()
	add_child(ammo);ammo.position=Vector3(-3.0,0,0.9);ammo.rotation.y=-0.6
	for i in 2:
		var can: Node3D = load(env+"shop/SM_Prop_AmmoCan_Military.glb").instantiate()
		add_child(can);can.position=Vector3(-3.1+i*0.38,0.37,0.85);can.rotation.y=-0.6+i*0.3
	var shotgun: Node3D = load(env+"weapons/SM_Wep_PumpShotgun.glb").instantiate()
	add_child(shotgun);shotgun.position=Vector3(-3.7,0.42,-1.7);shotgun.rotation=Vector3(0,0.45+PI/2,PI/2)
	var sword: Node3D = load(env+"weapons/SM_Wep_Longsword.glb").instantiate()
	add_child(sword);sword.position=Vector3(4.2,0.55,0.2);sword.rotation=Vector3(-PI/2+0.25,0.4,0)
	var Npc := preload("res://world/campaign/npc_pose.gd")
	for row in [["ZMB_Walker_1",Vector3(-6.5,0,-10.5),0.5],["ZMB_Walker_3",Vector3(5.8,0,-12.0),-0.4],["ZMB_Tank",Vector3(-1.2,0,-14.5),0.1],["ZMB_Walker_2",Vector3(9.5,0,-8.0),-0.9]]:
		Npc.spawn(self,"res://art/zx_infected/%s.glb"%row[0],"","zombie",row[1],row[2])

func set_skin(slot: int, skin_id: int) -> void:
	skin_id = clampi(skin_id,0,SKIN_COUNT-1)
	if is_instance_valid(avatars[slot]) and skin_ids[slot]==skin_id: return
	skin_ids[slot] = skin_id
	if is_instance_valid(avatars[slot]):
		remove_child(avatars[slot])
		avatars[slot].queue_free()
	var avatar := Node3D.new()
	avatar.name = "Survivor%d" % (slot+1)
	avatar.set_script(load("res://ui/camp/camp_avatar.gd"))
	avatar.stance = slot
	avatar.position = [Vector3(-2.4,0,0.34),Vector3(0.95,-0.29,-0.65),Vector3(2.4,-0.29,0.5),Vector3(-1.0,-0.4,-1.1)][slot]
	avatar.rotation.y = [0.10,-0.45,-0.95,0.35][slot]
	add_child(avatar)
	avatar.configure(MODELS[skin_id],self)
	avatars[slot] = avatar

func set_active(value: bool) -> void:
	visible = value
	moon.visible = value
	fire.visible = value
	camera.current = value
	if crackle:
		if value and not crackle.playing: crackle.play()
		elif not value: crackle.stop()

func _process(delta: float) -> void:
	timer += delta
	if fire: fire.light_energy = 2.4+sin(timer*13)*0.22+sin(timer*21)*0.12
	if camera and visible:
		camera.position = Vector3(sin(timer*0.09)*0.10,2.7+sin(timer*0.13)*0.03,8.3)
		camera.look_at(global_position+Vector3(-1.65,0.95,-0.1))

func _camp_prop(id: String) -> Node3D:
	if "Tent" in id: return Placeholder.tent()
	if "Truck" in id or "Veh" in id: return Placeholder.truck()
	if "Barrel" in id: return Placeholder.barrel()
	var root := Node3D.new()
	Placeholder.box(root,Vector3(0,0.3,0),Vector3(0.6,0.6,0.6),Color("4f4a3c"))
	return root

func _tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		node.material_override = mat
	for child in node.get_children(): _tint(child,color)

func _wind_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://world/zona1_rifugio/tree.gdshader")
		node.material_override = mat
	for child in node.get_children(): _wind_material(child)


