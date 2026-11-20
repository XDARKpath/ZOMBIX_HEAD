extends SceneTree
# Uscita dal portone nord, subito o dopo N secondi nello shop di Big Earl (regola "soglia calma", re_nemici_boss §1.6).
#   godot --path ZOMBIX_HEAD --headless --fixed-fps 60 -s tests/spawner_gate_checks.gd -- --wait 0|120 --seed N [--out cartella]
# Stampa una riga RESULT; tests/spawner_gate_summary.sh mette insieme i semi e controlla le soglie del 95%.
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
var world: Node3D
var p: CharacterBody3D
var gate := Vector3.ZERO
var t := 0.0
var exit_t := -1.0
var seen := {}
var chasers := {}
var reach8 := 0
var bad_spawns := 0
var yaws: Array = []


func _init() -> void:
	call_deferred("_run")


func arg(name: String, def: String) -> String:
	var a := OS.get_cmdline_user_args()
	var i := a.find(name)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else def


func step(seconds: float, walk := Vector2.ZERO) -> void:
	var left := seconds
	while left > 0.0:
		if walk != Vector2.ZERO:
			p.local_control = false
			p.network_move = walk
			p.input_age = 0.0
		p.rig.yaw = 0.0
		p.health = 100.0
		await physics_frame
		left -= 1.0 / 60.0
		t += 1.0 / 60.0
		_track()


func _track() -> void:
	var inside := Layout.safe(p.global_position)
	var reach := 0
	for e in world.targets:
		if not is_instance_valid(e) or e.dead: continue
		var id: int = e.network_id
		if not seen.has(id):
			seen[id] = true
			if t > 0.2:   # i sei fissi nascono col mondo
				yaws.append(int(round(rad_to_deg(wrapf(e.rotation.y, -PI, PI)) / 30.0)))
				if inside and Vector2(e.global_position.x, e.global_position.z).distance_to(Vector2(gate.x, gate.z)) < 35.0:
					bad_spawns += 1
		if exit_t < 0.0: continue
		if (e.state == e.State.CHASE or e.state == e.State.ATTACK) and e.target == p and t - exit_t <= 5.0:
			chasers[id] = true
		if e.global_position.distance_to(p.global_position) < 2.3 or e.state == e.State.ATTACK: reach += 1
	if exit_t >= 0.0 and t - exit_t <= 8.0: reach8 = maxi(reach8, reach)


func visible(e: Node3D) -> bool:
	var eye: Vector3 = p.global_position + Vector3.UP * 1.6
	var to: Vector3 = e.global_position + Vector3.UP * 1.2 - eye
	var fwd := Vector3(-sin(p.rig.yaw), 0, -cos(p.rig.yaw))
	var flat := Vector3(to.x, 0, to.z).normalized()
	if rad_to_deg(acos(clampf(fwd.dot(flat), -1, 1))) > 53.0 or to.length() > 120.0: return false
	var q := PhysicsRayQueryParameters3D.create(eye, eye + to, 1, [p.get_rid()])
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == e


func photo(tag: String) -> void:
	var out := arg("--out", "")
	if out == "" or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/portone_%s_attesa%s_seme%s.png" % [out, tag, arg("--wait", "0"), arg("--seed", "1")])


func _run() -> void:
	var s := int(arg("--seed", "1"))
	seed(s)
	var wait := float(arg("--wait", "0"))
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.spawner.rng.seed = s
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	world.spawner.rng.seed = s
	for i in 30: await process_frame
	p = world.player
	for g in world.fence.gates:
		if absf(g.at.z - Layout.FENCE_MIN.y) < 1.0: gate = g.at
	var shop := Vector3(-6.5, 0, -30.0)
	shop.y = world.terrain.height(shop.x, shop.z) + 0.2
	p.global_position = shop
	await step(wait + 0.1)
	# appena dentro il portone, guardando a nord
	p.global_position = gate + Vector3(0, 0.3, 4.0)
	await step(0.5)
	var present25 := 0
	var vis := 0
	for e in world.targets:
		if not is_instance_valid(e) or e.dead: continue
		if e.global_position.distance_to(p.global_position) < 25.0: present25 += 1
		if visible(e): vis += 1
	await photo("soglia")
	exit_t = t
	for i in 16: await step(0.5, Vector2(0, -1))
	await photo("dopo8s")
	print("RESULT seed=%d wait=%d presenti25=%d visibili=%d inseguono5=%d portata8=%d spawn_soglia=%d yaw=%s" % [s, int(wait), present25, vis, chasers.size(), reach8, bad_spawns, ",".join(yaws.map(func(y): return str(y)))])
	quit(0)
