extends SceneTree
# Sceriffo dietro la scrivania e dialogo: res://../screenshots/sheriff-*.png
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
var world: Node3D
func _initialize(): call_deferred("run")
func shot(id: String, wait := 0.4):
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/sheriff-" + id + ".png"))
	print("shot ", id)
func run():
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	var p = world.player
	p.set_physics_process(false)
	p.rig.set_physics_process(false)
	# Davanti alla scrivania, verso la parete di fondo (+X nel mondo).
	p.position = Layout.SHERIFF_NPC + Vector3(-2.1, 0.05, 0)
	p.rig.yaw = -PI / 2
	p.rig.pitch = -0.12
	p.rig.reset_follow()
	await shot("front", 1.0)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.global_position = Layout.SHERIFF_NPC + Vector3(-0.6, 1.2, 2.2)
	cam.look_at(Layout.SHERIFF_NPC + Vector3(0, 0.7, 0), Vector3.UP)
	cam.make_current()
	await shot("side")
	p.rig.camera.make_current()
	cam.queue_free()
	p.rig.set_physics_process(true)
	world.survival.open_sheriff_dialogue()
	await shot("dialogue", 0.15)
	await shot("dialogue-full", 1.6)
	world.survival.close_sheriff_dialogue()
	p.rig.set_physics_process(false)
	p.position = Vector3(8, 0.1, -11)
	p.rig.yaw = 0
	p.rig.pitch = 0
	p.rig.reset_follow()
	await shot("hud", 1.0)
	quit()
