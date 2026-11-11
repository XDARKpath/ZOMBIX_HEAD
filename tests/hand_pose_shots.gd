extends SceneTree
# Avatar visto da fuori (zx_avatar_driver.gd + tool_rig.gd): pistola, fucile, ascia, mani vuote, fermo e in cammino.
# Foto: res://../screenshots/hands-<tag>-front.png e -side.png. Controlla anche che le ossa non restino nella posa di riposo (T-pose).
# godot --path . -s res://tests/hand_pose_shots.gd -- <tag>
const ACTOR := """extends CharacterBody3D
signal damaged(amount)
var equipped := "axe"
var dead := false
var seated := false
var crouching := false
var sprinting := false
var reload_left := 0.0
var local_control := false
var melee: Node
"""
const MELEE := """extends Node
var attacking := false
var charged_attack := false
var charging := false
var ads := false
var blocking := false
var attack_clip := ""
func charge_fraction() -> float: return 0.0
"""
const WEAPONS := ["pistol", "assault_rifle", "axe", "", "pistol", "assault_rifle", "axe"]
var fails := 0

func _initialize(): call_deferred("run")

func shot(id: String):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/hands-" + id + ".png"))

func source(code: String) -> GDScript:
	var s := GDScript.new()
	s.source_code = code
	s.reload()
	return s

func run():
	var tag: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "now"
	DisplayServer.window_set_size(Vector2i(1800, 700))
	var s := Node3D.new()
	root.add_child(s)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.48, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	s.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	s.add_child(sun)
	var cam := Camera3D.new()
	s.add_child(cam)
	cam.fov = 40
	var actors := []
	for i in WEAPONS.size():
		var actor := CharacterBody3D.new()
		actor.set_script(source(ACTOR))
		var melee := Node.new()
		melee.set_script(source(MELEE))
		actor.melee = melee
		actor.add_child(melee)
		actor.equipped = WEAPONS[i]
		s.add_child(actor)
		actor.position = Vector3(-5.4 + i * 1.8, 0, 0)
		var v := Node3D.new()
		v.set_script(load("res://art/survivor_visual.gd"))
		actor.add_child(v)
		v.rotation.y = PI
		v.configure("ZX_SKIN_%d" % (i % 10), actor)
		actors.append(actor)
	for i in range(4, WEAPONS.size()):
		actors[i].velocity = Vector3(0, 0, -2.6)      # gli ultimi tre camminano verso la camera
	var t := 0.0
	while t < 1.4:
		for a in actors:
			var vis = a.get_child(1)
			if vis.operative_driver: vis.operative_driver.tick(0.016)
		await process_frame
		t += 0.016
	# T-pose: braccio sinistro orizzontale e teso come nella posa di riposo
	for i in actors.size():
		var vis = actors[i].get_child(1)
		var sk: Skeleton3D = vis.skeleton
		var up := sk.get_bone_global_pose(sk.find_bone("upperarm_l")).origin
		var hand := sk.get_bone_global_pose(sk.find_bone("hand_l")).origin
		var drop := up.y - hand.y
		var ok := drop > 0.12
		print(("PASS " if ok else "FAIL ") + "%s: mano sinistra %.2f m sotto la spalla" % [WEAPONS[i] if WEAPONS[i] != "" else "mani vuote", drop])
		if not ok: fails += 1
	cam.position = Vector3(0, 1.3, -9.0)
	cam.look_at(Vector3(0, 1.0, 0))
	await shot(tag + "-front")
	cam.position = Vector3(-9.0, 1.4, -2.0)
	cam.look_at(Vector3(0, 1.0, 0))
	await shot(tag + "-side")
	cam.position = Vector3(-2.2, 1.5, -3.6)
	cam.look_at(Vector3(-3.6, 1.15, 0))
	await shot(tag + "-close")
	print("HAND POSE %s (%d errori)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
