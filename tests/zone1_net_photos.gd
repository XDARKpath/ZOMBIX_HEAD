extends SceneTree
# Rete stradale della Zona 1: pianta schematica + foto dall'alto (camera ortografica) e a livello del giocatore.
# godot --path . -s res://tests/zone1_net_photos.gd -- <cartella> [solo_pianta]
const RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
const Route := preload("res://world/campaign/route.gd")
const Village := preload("res://world/villaggio/villaggio_layout.gd")
var Terrain: Script
var out := ""
var world: Node3D
var cam: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://rete")
	DirAccess.make_dir_recursive_absolute(out)
	Terrain = load("res://world/campaign/terrain.gd")
	_map()
	if args.has("solo_pianta"):
		quit(0)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	world.spawner.set_process(false)
	world.village.set_process(false)
	world.get_node("Interface").visible = false
	world.player.visible = false
	world.player.set_physics_process(false)
	for env in world.find_children("*", "WorldEnvironment", true, false):
		env.environment.fog_enabled = false
		env.environment.volumetric_fog_enabled = false
	cam = Camera3D.new()
	world.add_child(cam)
	cam.far = 900.0
	var boss: Vector3 = RoadNet.arenas()[0]
	# -- <cartella> eye x z altezza lx lz [...]: solo foto a livello del giocatore.
	if args.size() > 1 and args[1] == "eye":
		for k in range(2, args.size() - 4, 5):
			await _eye("V_%s_%s" % [args[k], args[k + 1]], Vector3(float(args[k]), float(args[k + 2]), float(args[k + 1])), Vector3(float(args[k + 3]), 0.8, float(args[k + 4])))
		quit(0)
		return
	# -- <cartella> top x z lato [x z lato ...]: solo queste foto dall'alto.
	if args.size() > 1 and args[1] == "top":
		for k in range(2, args.size() - 2, 3):
			await _top("T_%s_%s" % [args[k], args[k + 1]], Vector3(float(args[k]), 0, float(args[k + 1])), float(args[k + 2]))
		quit(0)
		return
	await _top("A_rete_intera", Vector3(10, 0, -230), 560.0)
	await _top("B_rifugio_e_bivi", Vector3(10, 0, -110), 200.0)
	await _top("C_borgo_e_bretella", Vector3(120, 0, -385), 220.0)
	await _top("D_radura_boss", boss, 110.0)
	await _top("E_posto_di_blocco", Terrain.get_script_constant_map()["CHECKPOINT"] + Vector3(0, 0, -6), 60.0)
	for j in RoadNet.junctions().size():
		var at: Vector3 = RoadNet.junctions()[j]
		await _top("F_incrocio_%02d" % j, at, 46.0)
	var cp: Vector3 = Route.nearest_road(Terrain.get_script_constant_map()["CHECKPOINT"])
	await _eye("G_posto_di_blocco_da_nord", cp + Vector3(1.5, 1.7, 30), cp + Vector3(0, 0.8, -6))
	await _eye("H_posto_di_blocco_da_sud", cp + Vector3(-6, 1.7, -30), cp + Vector3(0, 0.8, 0))
	await _eye("I_ingresso_borgo", Vector3(214, 1.7, -378), Vector3(150, 1.5, -385))
	await _eye("J_via_est_borgo", Vector3(150, 1.7, -383), Vector3(70, 1.5, -385))
	await _eye("M_dallo_scatto_utente", Vector3(112, 1.7, -258), Vector3(106, 0.8, -285))
	var paths: Array = RoadNet.paths()
	for p in paths.size():
		var line: Array = paths[p]
		var end: Vector3 = line[line.size() - 1]
		var before: Vector3 = line[maxi(0, line.size() - 6)]
		await _eye("K_fine_ramo_%d" % p, before + (before - end).normalized() * 6.0 + Vector3.UP * 1.7, end + Vector3.UP)
	await _eye("L_verso_la_radura", boss + Vector3(0, 1.7, 0) + (paths[1][paths[1].size() - 1] - boss).normalized() * 34.0, boss + Vector3.UP)
	quit(0)


## Foto dall'alto, ortografica, nord in alto.
func _top(title: String, center: Vector3, size: float) -> void:
	var ring: Array = [center]
	for k in 8: ring.append(center + Vector3(cos(k * TAU / 8), 0, sin(k * TAU / 8)) * size * 0.45)
	world.terrain.ensure_near(ring, ring)
	world.player.reset_at(Vector3(center.x, world.terrain.height(center.x, center.z) + 0.3, center.z))
	for i in 40: await process_frame
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	cam.global_position = Vector3(center.x, 400.0, center.z)
	cam.rotation = Vector3(-PI / 2, 0, 0)
	cam.current = true
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(title + ".png"))
	print("FOTO ", title)


func _eye(title: String, eye: Vector3, look: Vector3) -> void:
	world.terrain.ensure_near([eye, look])
	world.player.reset_at(Vector3(eye.x, world.terrain.height(eye.x, eye.z) + 0.3, eye.z))
	for i in 30: await process_frame
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 70.0
	cam.global_position = Vector3(eye.x, world.terrain.height(eye.x, eye.z) + eye.y, eye.z)
	cam.look_at(Vector3(look.x, world.terrain.height(look.x, look.z) + look.y, look.z))
	cam.current = true
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(title + ".png"))
	print("FOTO ", title)


# ------------------------------------------------------------------ pianta schematica (2 px = 1 m)
const MAP_MIN := Vector2(-300, -560)
const MAP_SCALE := 2.0
var img: Image


func _px(p: Vector3) -> Vector2:
	return (Vector2(p.x, p.z) - MAP_MIN) * MAP_SCALE


func _line(a: Vector3, b: Vector3, color: Color, width: float) -> void:
	var pa := _px(a)
	var pb := _px(b)
	var steps := int(pa.distance_to(pb)) + 1
	for s in steps + 1:
		_dot(pa.lerp(pb, float(s) / steps), width, color)


func _dot(c: Vector2, r: float, color: Color) -> void:
	for x in range(int(c.x - r), int(c.x + r) + 1):
		for y in range(int(c.y - r), int(c.y + r) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and Vector2(x, y).distance_to(c) <= r:
				img.set_pixel(x, y, color)


func _map() -> void:
	img = Image.create(int(620 * MAP_SCALE), int(620 * MAP_SCALE), false, Image.FORMAT_RGB8)
	img.fill(Color("2f4a2c"))
	# griglia ogni 50 m
	for g in range(-300, 320, 50):
		_line(Vector3(g, 0, MAP_MIN.y), Vector3(g, 0, MAP_MIN.y + 620), Color("3a5636"), 0.5)
		_line(Vector3(MAP_MIN.x, 0, g - 260), Vector3(MAP_MIN.x + 620, 0, g - 260), Color("3a5636"), 0.5)
	# vie del Borgo (terra)
	var c := Village.CENTER
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var length := 72.0 if d.x > 0 else 100.0
		_line(c, c + d * (18.5 + length), Color("8a7a55"), 9.0)
	var road: Array = Route.road_points()
	for i in road.size() - 1:
		if road[i].z > -600: _line(road[i], road[i + 1], Color("b0b0a8"), 7.0)
	var colors := [Color.ORANGE, Color.CYAN, Color.MAGENTA, Color.YELLOW, Color.WHITE, Color.PINK, Color.LIGHT_BLUE, Color.SALMON, Color.LIME]
	var paths: Array = RoadNet.paths()
	for p in paths.size():
		var line: Array = paths[p]
		for i in line.size() - 1:
			_line(line[i], line[i + 1], colors[p % colors.size()], 4.4)
		var end: Vector3 = line[line.size() - 1]
		var open: bool = RoadNet.junction_distance(Vector2(end.x, end.z)) < 1.0
		print("RAMO %d  da %s  a %s  lungo %.0f m  fine %s" % [p, line[0], end, _length(line), "incrocio" if open else "cieca"])
	for j in RoadNet.junctions():
		_dot(_px(j), 4.0, Color.BLACK)
	for a in RoadNet.arenas():
		_dot(_px(a), 7.0, Color.RED)
	_dot(_px(RoadNet.arenas()[0]), 12.0, Color.DARK_RED)
	for key in RoadNet.SITES:
		_dot(_px(RoadNet.SITES[key]), 9.0, Color.PURPLE)
	_dot(_px(RoadNet.START), 9.0, Color.GREEN)
	_dot(_px(Terrain.get_script_constant_map()["CHECKPOINT"]), 7.0, Color.BLUE)
	img.save_png(out.path_join("00_pianta.png"))
	print("PIANTA salvata; boss a %s, %.0f m dal rifugio" % [RoadNet.arenas()[0], RoadNet.arenas()[0].distance_to(RoadNet.START)])


func _length(line: Array) -> float:
	var total := 0.0
	for i in line.size() - 1: total += line[i].distance_to(line[i + 1])
	return total
