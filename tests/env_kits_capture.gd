extends SceneTree
# Casa del Vecchio e fattoria arredate (zone1_kit.gd): res://../screenshots/kit-<vista>.png
var fails := 0
func _initialize(): call_deferred("run")
func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1
func shot(id: String, wait := 0.3):
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/kit-" + id + ".png"))
func look(p, from: Vector3, at: Vector3) -> void:
	p.global_position = from
	var d: Vector3 = (at -(from + Vector3.UP * p.eye_height)).normalized()
	p.rig.yaw = atan2(-d.x, -d.z)
	p.rig.pitch = asin(d.y)
	p.rig.reset_follow()
func run():
	var world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.6).timeout
	world.get_node("Interface").visible = false
	var gps = world.get_node("Interface").find_child("RouteGPS", true, false)
	if gps: gps.opened = false
	var p = world.player
	p.set_physics_process(false)
	p.rig.set_physics_process(false)
	p.equipped = ""
	for t in world.targets:
		if is_instance_valid(t): t.global_position += Vector3(0, -200, 0)
	var kit = world.zone_kit
	var cabin: Node3D = kit.get_node("CasaDelVecchio")
	check(cabin.find_children("SM_Wood_*", "Node3D", true, false).size() >= 8, "Casa del Vecchio arredata")
	look(p, cabin.global_position + Vector3(6.6, 0.1, 6.6), cabin.global_position + Vector3(2.5, 0.6, 3.0))
	await shot("cabin")
	look(p, cabin.global_position + Vector3(6.0, 0.1, -5.5), cabin.global_position + Vector3(6.0, 0.6, -1.0))
	await shot("porch")
	var farm: Node3D = kit.get_node("FattoriaDiroccata")
	check(farm.find_children("SM_Wood_*", "Node3D", true, false).size() >= 5, "Fattoria arredata")
	look(p, farm.global_position + Vector3(4.0, 0.1, 2.0), farm.global_position + Vector3(4.0, 0.4, 7.0))
	await shot("farm")
	print("ENV_KITS ", "OK" if fails == 0 else "FALLITO %d" % fails)
	quit(fails)
