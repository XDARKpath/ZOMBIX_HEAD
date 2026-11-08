extends SceneTree
# Panoramica della Zona 1: res://../screenshots/zone1-<vista>.png
# Argomento opzionale: elenco di viste separate da virgole.
var world: Node3D
const VIEWS := {
	"aerial": [Vector3(30, 120, 40), Vector3(10, 0, -70)],
	"aerial-south": [Vector3(20, 110, -110), Vector3(10, 0, -190)],
	"road-start": [Vector3(6, 1.7, -4), Vector3(6, 1.4, -40)],
	"road-mid": [Vector3(7, 1.7, -60), Vector3(10, 1.4, -100)],
	"road-end": [Vector3(8, 1.7, -130), Vector3(40, 1.4, -200)],
	"road-far": [Vector3(70, 1.7, -230), Vector3(160, 1.4, -300)],
	"bend": [Vector3(30, 2.0, -170), Vector3(130, 1.0, -260)],
	"gate": [Vector3(150, 3.0, -300), Vector3(185, 1.0, -348)],
	"gate-aerial": [Vector3(120, 90, -250), Vector3(185, 0, -348)],
	"village": [Vector3(-2, 4.5, 4), Vector3(14, 0.5, -24)],
	"lake": [Vector3(4, 2.5, -8), Vector3(6, 0, 30)],
	"dock": [Vector3(-4.5, 3.0, 9.0), Vector3(6.5, 0.0, 18.0)],
	"dock-end": [Vector3(11.5, 1.6, 26.5), Vector3(6.0, 0.4, 20.0)],
	"boat": [Vector3(12.0, 1.4, 13.5), Vector3(8.7, 0.0, 17.0)],
	"road-head": [Vector3(6.5, 1.7, -12.0), Vector3(6.0, 0.6, 6.0)],
	"car": [Vector3(13.0, 1.8, 9.0), Vector3(19.5, 0.8, 3.0)],
}
func _initialize(): call_deferred("run")
func run():
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	var p = world.player
	p.set_physics_process(false)
	p.rig.set_physics_process(false)
	world.get_node("Interface").visible = false
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args(): only = a.split(",")
	var cam := Camera3D.new()
	cam.far = 1200
	world.add_child(cam)
	cam.make_current()
	for id in VIEWS:
		if not only.is_empty() and not id in only: continue
		var v: Array = VIEWS[id]
		p.position = Vector3(v[0].x, 0.2, v[0].z)
		world.terrain.ensure_near([p.position, v[0]])
		cam.fov = 60 if id.begins_with("aerial") else 72
		cam.global_position = v[0]
		cam.look_at(v[1], Vector3.UP)
		await create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/zone1-" + id + ".png"))
		print("shot ", id)
	quit()
