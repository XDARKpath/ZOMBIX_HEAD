extends SceneTree
# Aspetto delle armi in cinque luci: un foglio per arma.
# Righe: profilo, tre quarti da vicino, prima persona. Colonne: sole, ombra, interno, fuoco, notte.
#   godot --path . --resolution 1280x720 -s res://tests/weapon_look_shots.gd -- <cartella> [id,id,...]
var world: Node3D
var cam: Camera3D
var folder := ""
var sheet: Image
const AT := Vector3(14, 140.02, -60)
const SPOT := Vector3(17, 141.0, -63.5)
const W := 384
const H := 216
const LIGHTS := ["sole", "ombra", "interno", "fuoco", "notte"]
var sun: DirectionalLight3D
var env: Environment
var moon: DirectionalLight3D
var lamp: OmniLight3D
var fire: OmniLight3D
var roof: Node3D
var walls: Node3D
var keep := {}


func frames(n: int) -> void:
	for i in n: await process_frame


func _init() -> void:
	call_deferred("_run")


func _box(size: Vector3, at: Vector3, parent: Node3D) -> void:
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.36, 0.3)
	mesh.material = mat
	view.mesh = mesh
	parent.add_child(view)
	view.global_position = at


func _light(id: String) -> void:
	sun.visible = id in ["sole", "ombra"]
	roof.visible = id != "sole"
	walls.visible = id in ["interno", "fuoco"]
	lamp.visible = id == "interno"
	fire.visible = id == "fuoco"
	moon.visible = id == "notte"
	env.ambient_light_energy = 0.04 if id == "notte" else keep.ambient
	env.background_energy_multiplier = 0.05 if id == "notte" else keep.background


func _take(cell: Vector2i, full: String = "") -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if full != "": img.save_png(folder.path_join(full + ".png"))
	img.resize(W, H, Image.INTERPOLATE_BILINEAR)
	sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(cell.x * W, cell.y * H))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	root.get_node("Session").launch()
	world.automated = true
	await frames(30)
	world.spawner.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.queue_free()
	world.get_node("Interface").visible = false
	for c in world.landscape.get_children():
		if c is WorldEnvironment: env = c.environment
		if c is DirectionalLight3D: sun = c
	keep.ambient = env.ambient_light_energy
	keep.background = env.background_energy_multiplier
	var stage := Node3D.new()
	world.add_child(stage)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	stage.add_child(floor_body)
	floor_body.global_position = Vector3(AT.x, 139.5, AT.z)
	_box(Vector3(40, 1, 40), Vector3(AT.x, 139.5, AT.z), stage)
	roof = Node3D.new()
	stage.add_child(roof)
	_box(Vector3(14, 0.3, 14), Vector3(15.5, 143.2, -60), roof)
	walls = Node3D.new()
	stage.add_child(walls)
	for s in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var size := Vector3(0.3, 3.2, 14) if s.x != 0 else Vector3(14, 3.2, 0.3)
		_box(size, Vector3(15.5, 141.6, -60) + s * 7.0, walls)
	lamp = OmniLight3D.new()
	lamp.light_color = Color("ffe6c4")
	lamp.light_energy = 1.6
	lamp.omni_range = 8.0
	lamp.shadow_enabled = true
	stage.add_child(lamp)
	lamp.global_position = Vector3(16, 142.8, -59.2)
	fire = OmniLight3D.new()
	fire.light_color = Color("ff9348")
	fire.light_energy = 2.2
	fire.omni_range = 5.0
	fire.shadow_enabled = true
	stage.add_child(fire)
	fire.global_position = Vector3(16.4, 140.4, -58.7)
	moon = DirectionalLight3D.new()
	moon.light_color = Color("8fa6d6")
	moon.light_energy = 0.22
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-40, 140, 0)
	stage.add_child(moon)
	cam = Camera3D.new()
	cam.fov = 30.0
	world.add_child(cam)
	var p: CharacterBody3D = world.player
	p.controls_enabled = true
	p.rig.controls_enabled = false
	p.reset_at(AT)
	p.rig.pitch = -0.06
	await frames(20)
	var ids: Array = []
	if args.size() > 1:
		ids = args[1].split(",")
	else:
		for id in ZXWeapons.DEFS:
			if String(ZXWeapons.DEFS[id].get("scene", "")) != "" and id != "arrows": ids.append(id)
	for id in ids:
		sheet = Image.create(W * LIGHTS.size(), H * 3, false, Image.FORMAT_RGB8)
		var model: Node3D = load(ZXWeapons.DEFS[id].scene).instantiate()
		for a in model.find_children("*", "AnimationPlayer", true, false): a.stop()
		world.add_child(model)
		model.global_position = SPOT
		var aabb := AABB()
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			aabb = aabb.merge(mi.transform * mi.get_aabb())
		var longest := maxf(aabb.size.z, aabb.size.y)
		var mid: Vector3 = SPOT + aabb.get_center()
		if not p.owned.has(id): p.owned.append(id)
		p.magazine = 30
		p.equip_id(id)
		await frames(40)
		for li in LIGHTS.size():
			_light(LIGHTS[li])
			cam.current = true
			var side := Vector3(1, 0, 0) if aabb.size.z >= aabb.size.y else Vector3(0, 0, 1)
			cam.global_position = mid + side * (longest * 1.6 + 0.2) + Vector3(0, 0.02, 0)
			cam.look_at(mid)
			await frames(3)
			await _take(Vector2i(li, 0), id + "_profilo_interno" if LIGHTS[li] == "interno" else "")
			cam.global_position = mid + Vector3(0.55, 0.38, 0.5).normalized() * (longest * 1.05 + 0.12)
			cam.look_at(mid)
			await frames(3)
			await _take(Vector2i(li, 1), id + "_34_sole" if LIGHTS[li] == "sole" else "")
			p.rig.camera.current = true
			await frames(3)
			await _take(Vector2i(li, 2))
		model.queue_free()
		sheet.save_png(folder.path_join(id + ".png"))
		print("FOGLIO ", id)
	print("FINE")
	quit(0)
