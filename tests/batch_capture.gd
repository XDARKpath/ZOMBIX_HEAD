extends SceneTree
# Foto dei batch ZOMBIX nel gioco: armeria, sceriffo, NPC, rovine, infetti e boss.
# res://../screenshots/batch-<vista>.png ; argomento opzionale: elenco di viste.
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
var world: Node3D
var cam: Camera3D
func _initialize(): call_deferred("run")
func view(id: String, from: Vector3, to: Vector3, fov := 62.0, wait := 0.6):
	cam.fov = fov
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	world.player.position = Vector3(from.x, 0.2, from.z)
	world.terrain.ensure_near([from])
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/batch-" + id + ".png"))
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
	world.get_node("Interface").visible = false
	cam = Camera3D.new()
	cam.far = 400
	world.add_child(cam)
	cam.make_current()
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args(): only = a.split(",")
	var want := func(id): return only.is_empty() or id in only
	var shop: Vector3 = Layout.SHOP
	if want.call("shop"): await view("shop", shop + Vector3(6.5, 1.7, 0.4), shop + Vector3(0, 1.1, 0.5), 70)
	if want.call("shop-wall"): await view("shop-wall", shop + Vector3(3.5, 1.6, -2.0), shop + Vector3(-1.0, 1.6, 4.4), 70)
	if want.call("sheriff"): await view("sheriff", Layout.SHERIFF_NPC + Vector3(-3.0, 1.6, 0.6), Layout.SHERIFF_NPC + Vector3(0, 0.8, 0), 60)
	if want.call("sheriff-side"): await view("sheriff-side", Layout.SHERIFF_NPC + Vector3(-1.4, 1.4, 2.6), Layout.SHERIFF_NPC + Vector3(-0.6, 0.7, 0), 60)
	if want.call("npc-steps"): await view("npc-steps", Vector3(5.5, 1.6, -23.5), Vector3(1.3, 0.8, -26.2), 55)
	if want.call("npc-guard"): await view("npc-guard", Vector3(10.5, 1.6, -49), Vector3(10.5, 1.0, -44), 55)
	if want.call("npc-lean"): await view("npc-lean", Vector3(16.5, 1.7, -3.0), Vector3(11.6, 0.9, -2.4), 55)
	if want.call("dock"): await view("dock", Vector3(10.5, 2.0, 18.5), Vector3(7.2, 0.4, 22.0), 55)
	if want.call("cabin"): await view("cabin", Layout.CABIN + Vector3(14, 4, -10), Layout.CABIN + Vector3(4, 1.2, 4), 60)
	if want.call("farm"): await view("farm", Layout.FARM + Vector3(14, 5, -8), Layout.FARM + Vector3(4, 1.0, 4), 60)
	if want.call("zombies"):
		var kinds := [0, 0, 1, 2, 3, 0]
		for i in kinds.size():
			var z: Node3D = world._spawn_enemy(Vector3(-6 + i * 2.2, 0.1, -64))
			z.set_kind(kinds[i])
			z.set_physics_process(false)
			z.rotation.y = 0
		await view("zombies", Vector3(-0.5, 1.8, -57.5), Vector3(-0.5, 1.0, -64), 60, 1.0)
	if want.call("bosses"):
		world.boss_hunt.summon(0); world.boss_hunt.summon(1); world.boss_hunt.summon(2)
		var xs := [-6.0, 0.0, 7.0]
		for i in world.boss_hunt.bosses.size():
			var b: Node3D = world.boss_hunt.bosses[i]
			b.set_physics_process(false)
			b.global_position = Vector3(xs[i], 0.1, -80)
			b.rotation.y = 0
		await view("bosses", Vector3(0.5, 3.0, -68), Vector3(0.5, 2.0, -80), 62, 1.2)
	quit()
