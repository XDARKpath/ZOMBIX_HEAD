extends SceneTree
# Partita lunga simulata: ogni minuto arrivano 10 infetti, vengono abbattuti e si spara.
# Stampa nodi, nemici in lista, luci, particelle e tempo medio del frame minuto per minuto.
# Uso: Godot --headless --path . -s res://tests/perf_soak.gd -- --minutes=10
const GunFx := preload("res://weapons/gun_fx.gd")
var world: Node3D

func _initialize(): call_deferred("run")

func count(type: String) -> int:
	return world.find_children("*", type, true, false).size()

func frame_ms(frames: int) -> float:
	var t := Time.get_ticks_usec()
	for i in frames: await process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / frames

func run():
	var minutes := 10
	var waves := 10
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="): minutes = int(arg.get_slice("=", 1))
		if arg.begins_with("--waves="): waves = int(arg.get_slice("=", 1))
	Engine.max_fps = 0
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate(); root.add_child(world); world.automated = true
	root.get_node("Session").launch(); await create_timer(2.0).timeout
	var p: CharacterBody3D = world.player
	p.reset_at(Vector3(6, 0.1, 2))
	print("SOAK start nodes=%d ms=%.2f" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), await frame_ms(60)])
	Engine.time_scale = 6.0
	for m in minutes:
		for i in waves:
			var e: Node3D = world._spawn_enemy(p.position + Vector3(randf_range(-8, 8), 0, randf_range(-14, -6)))
			await process_frame
			if is_instance_valid(e): e.receive_hit("head", 99999.0, Vector3(0, 0, -1), "pistol", false)
			GunFx.fire(world, "assault_rifle", p.position + Vector3.UP * 1.5, [e.global_position if is_instance_valid(e) else p.position], Vector3.FORWARD, Vector3.RIGHT)
		# Il resto del minuto passa a tempo accelerato.
		await create_timer(60.0).timeout
		Engine.time_scale = 1.0
		var ms: float = await frame_ms(60)
		Engine.time_scale = 6.0
		print("SOAK min=%d nodes=%d enemies=%d lights=%d particles=%d orphans=%d ms=%.2f" % [m + 1,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), world.targets.size(), count("Light3D"),
			count("CPUParticles3D") + count("GPUParticles3D"), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), ms])
	quit()
