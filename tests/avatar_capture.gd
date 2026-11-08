extends SceneTree
# Avatar in terza persona (zx_avatar_driver.gd): una fila di stati. res://../screenshots/avatar-*.png
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
"""

func _initialize(): call_deferred("run")

func shot(id: String):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/avatar-" + id + ".png"))
	print("shot ", id)

func source(code: String) -> GDScript:
	var s := GDScript.new()
	s.source_code = code
	s.reload()
	return s

func run():
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
	cam.position = Vector3(0, 1.3, 13.5)
	cam.fov = 50
	var states := ["walk", "attack", "heavy", "drive", "passenger", "wheel", "engine", "dead", "pistol", "katana"]
	var actors := []
	for i in states.size():
		var actor := CharacterBody3D.new()
		actor.set_script(source(ACTOR))
		var melee := Node.new()
		melee.set_script(source(MELEE))
		actor.melee = melee
		actor.add_child(melee)
		s.add_child(actor)
		actor.position = Vector3(-8.1 + i * 1.8, 0, 0)
		actor.rotation.y = 0.5
		var v := Node3D.new()
		v.set_script(load("res://art/survivor_visual.gd"))
		actor.add_child(v)
		v.rotation.y = PI
		v.configure("ZX_SKIN_%d" % (i % 10), actor)
		actors.append(actor)
	await create_timer(0.6).timeout
	for i in states.size():
		var a = actors[i]
		match states[i]:
			"walk": a.velocity = a.global_basis * Vector3(0, 0, -2.6)
			"attack": a.melee.attacking = true
			"heavy": a.melee.attacking = true; a.melee.charged_attack = true
			"drive": a.seated = true; a.set_meta("seat", 0); a.set_meta("steer", 1.0)
			"passenger": a.seated = true; a.set_meta("seat", 1)
			"wheel": a.set_meta("repair_until", Time.get_ticks_msec() + 100000); a.set_meta("repair_kind", "wheel")
			"engine": a.set_meta("repair_until", Time.get_ticks_msec() + 100000); a.set_meta("repair_kind", "engine")
			"dead": a.dead = true
			"pistol": a.equipped = "pistol"
			"katana": a.equipped = "katana"
	await create_timer(0.45).timeout
	await shot("states")
	await create_timer(1.6).timeout
	await shot("states-late")
	# Primi tre da vicino: camminata con l'ascia, colpo in combo, colpo pesante.
	cam.position = Vector3(-6.3, 1.2, 4.2)
	actors[1].melee.attacking = false
	actors[2].melee.attacking = false
	await create_timer(0.3).timeout
	actors[1].melee.attacking = true
	actors[2].melee.attacking = true
	await create_timer(0.42).timeout
	await shot("close")
	var walker: Node3D = actors[0].get_child(1).operative_driver.model
	print("walk blend ", walker.tree.get("parameters/Movement/Locomotion_BlendSpace2D/blend_position"), " stato ", walker._movement.get_current_node(), " vel ", actors[0].velocity, " arma ", walker.weapon_id)
	quit()
