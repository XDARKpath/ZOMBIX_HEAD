extends SceneTree
# Controllo delle clip ZX sugli infetti: una fila di pose ferme su fotogrammi scelti.
# res://../screenshots/anim-*.png
const ACTOR := """extends CharacterBody3D
var kind := 0
var state := 1
var attack_clock := 0.0
var crawling := false
var network_id := 0
var stagger := 0.0
var dead := false
var death_clock := 0.0
var ragdoll_kick := 0.0
var ragdoll_dir := Vector3.ZERO
var death_style := 0
var beheaded := false
var attack_clip := ""
var attack_serial := 0
var alert_time := 0.0
func update_hitboxes() -> void:
	pass
"""

func _initialize(): call_deferred("run")

func stage() -> Node3D:
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
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(40, 10)
	s.add_child(floor_mesh)
	return s

func shot(id: String):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/anim-" + id + ".png"))
	print("shot ", id)

func make(s: Node3D, model: String, x: float, setup: Callable, frames: int, yaw: float) -> void:
	var script := GDScript.new()
	script.source_code = ACTOR
	script.reload()
	var actor := CharacterBody3D.new()
	actor.set_script(script)
	s.add_child(actor)
	actor.position = Vector3(x, 0, 0)
	actor.rotation.y = yaw
	var v := Node3D.new()
	v.set_script(load("res://art/survivor_visual.gd"))
	actor.add_child(v)
	v.configure(model, actor, true)
	v.set_process(false)
	for f in frames:
		setup.call(actor, f / 60.0)
		v.clock += 1.0 / 60.0
		v._pose(1.0 / 60.0)

func run():
	DisplayServer.window_set_size(Vector2i(1800, 700))
	for yaw in [0.0, PI / 2]:
		var s := stage()
		var cam := Camera3D.new()
		s.add_child(cam)
		cam.position = Vector3(0, 1.2, 14.5)
		cam.fov = 50
		var walker := "res://art/zx_infected/ZMB_Walker_1.glb"
		var rows := [
			[walker, func(a, t): a.velocity = Vector3.ZERO, 40],
			[walker, func(a, t): a.velocity = Vector3(0, 0, 1.15), 47],
			["res://art/zx_infected/ZMB_Walker_3.glb", func(a, t): a.velocity = Vector3(0, 0, 1.15); a.network_id = 3, 33],
			["res://art/zx_infected/ZMB_Spitter.glb", func(a, t): a.kind = 1; a.velocity = Vector3(0, 0, 4.2), 30],
			[walker, func(a, t): a.state = 2; a.attack_clip = "Z_Attack_Swipe_R"; a.attack_clock = t, 38],
			["res://art/zx_infected/ZMB_Tank.glb", func(a, t): a.kind = 2; a.state = 2; a.attack_clip = "Z_Attack_Overhead_Smash"; a.attack_clock = t, 44],
			["res://art/zx_infected/ZMB_Spitter.glb", func(a, t): a.kind = 1; a.state = 2; a.attack_clip = "Z_Attack_Leap"; a.attack_clock = t, 26],
			[walker, func(a, t): a.stagger = 0.55 - t, 12],
			[walker, func(a, t): a.dead = true; a.death_clock = t; a.death_style = 0, 60],
			[walker, func(a, t): a.dead = true; a.death_clock = t; a.death_style = 1, 150],
			[walker, func(a, t): a.crawling = true; a.velocity = Vector3(0, 0, 0.5), 30],
		]
		for i in rows.size():
			make(s, rows[i][0], -9.0 + i * 1.8, rows[i][1], rows[i][2], yaw)
		await shot("front" if yaw == 0.0 else "side")
		s.queue_free()
		await process_frame
	quit()
