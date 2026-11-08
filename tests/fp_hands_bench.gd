extends SceneTree
# Banco di prova delle impugnature: braccia + arma su sfondo neutro, tre angolazioni.
# Uscita: res://../screenshots/bench-<arma>-<vista>.png
const Hands := preload("res://player/viewmodel/fp_hands.gd")
const VM := preload("res://player/first_person_weapon.gd")
var view: Node3D
var hands := Hands.new()
var cam: Camera3D
func _initialize(): call_deferred("run")
func shot(id: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/bench-" + id + ".png"))
	print("shot ", id)
func run():
	DisplayServer.window_set_size(Vector2i(900, 600))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.42, 0.45, 0.47)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.62)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	root.add_child(sun)
	view = Node3D.new()
	root.add_child(view)
	var arms: Node3D = load("res://art/fp_arms/SM_FP_Arms.glb").instantiate()
	view.add_child(arms)
	var vm = VM.new()
	vm.arms = arms
	vm._materials()
	hands.setup(arms)
	cam = Camera3D.new()
	cam.near = 0.01
	root.add_child(cam)
	cam.make_current()
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args(): only = a.split(",")
	for weapon in ["axe", "knife", "pistol", "pistol_fire", "pda", "relaxed"]:
		if not only.is_empty() and not weapon in only: continue
		var id: String = weapon.split("_")[0]
		var item: Node3D
		if id in ["axe", "spade"]: item = preload("res://art/weapons/hand_tools.gd").make(id)
		elif id == "pistol": item = load("res://art/weapons/pistol.tscn").instantiate()
		elif id == "pda":
			item = preload("res://player/viewmodel/pda.gd").new()
		else: item = preload("res://art/placeholders.gd").knife()
		view.add_child(item)
		if id == "pda": item.build(null)
		if id == "pda":
			item.transform = Transform3D(Basis.from_euler(Vector3(14, 10, -4) * PI / 180), Vector3(-0.085, -0.075, -0.30))
		elif id != "relaxed":
			var pose: Dictionary = VM.POSES.get(id, VM.POSES["knife"])
			vm.weapon = id
			vm.item = item
			item.transform = Transform3D(Basis.from_euler(pose["rot"] * PI / 180) * vm._canonical(), pose["at"])
		var right: Node3D = item.get_node_or_null("Socket_RightHand")
		var left: Node3D = item.get_node_or_null("Socket_LeftHand")
		var rest_r := Transform3D(vm._hand_basis(Vector3(-0.25, 0.15, -1), Vector3(1, 0.4, 0.2)), Vector3(0.21, -0.40, -0.34))
		var rest_l := Transform3D(vm._hand_basis(Vector3(0.25, 0.15, -1), Vector3(-1, 0.4, 0.2)), Vector3(-0.21, -0.40, -0.34))
		if right: hands.grip("r", right, 1.0, 0.5, 1.0 if weapon == "pistol_fire" else 0.0)
		else: hands.free_hand("r", rest_r)
		if left: hands.grip("l", left, 1.0, 0.5)
		else: hands.free_hand("l", rest_l)
		hands.apply()
		var focus: Vector3 = right.global_position if right else (left.global_position if left else Vector3(0, -0.3, -0.4))
		cam.fov = 75
		cam.transform = Transform3D.IDENTITY
		await shot(weapon + "-eye")
		cam.fov = 35
		for k in 3:
			var off: Vector3 = [Vector3(0.45, 0.05, -0.05), Vector3(-0.35, 0.10, -0.30), Vector3(0.05, 0.10, -0.50)][k]
			cam.global_position = focus + off
			cam.look_at(focus, Vector3.UP)
			await shot(weapon + "-v%d" % k)
		item.queue_free()
	quit()
