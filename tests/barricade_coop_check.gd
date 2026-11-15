extends SceneTree
# Barricate del borgo in rete con due processi veri: l'host sta sulla linea di una barricata, il client su quella di
# un'altra. Le barricate salgono: nessuno resta dentro il legno e tutti e due camminano verso la piazza.
# godot --headless --path . -s res://tests/barricade_coop_check.gd -- --coop-host
# godot --headless --path . -s res://tests/barricade_coop_check.gd -- --coop-client
const L := preload("res://world/villaggio/villaggio_layout.gd")
const PORT := 27855
var world: Node3D
var village: Node3D


func _initialize() -> void:
	call_deferred("run")


## Il giocatore è dentro una barricata alzata?
func trapped(actor: CharacterBody3D) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = actor.standing_shape
	q.transform = Transform3D(Basis.IDENTITY, actor.global_position + Vector3.UP * 0.9)
	q.collision_mask = 1
	q.exclude = [actor.get_rid()]
	for hit in root.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var body: Node = hit.collider
		if body and body.get_parent() in village.barricades: return true
	return false


## Distanza dalla linea della barricata verso la piazza (positiva = lato piazza).
func past_line(actor: Node3D, b: Node3D) -> float:
	var inward := -b.global_basis.z.normalized()
	if inward.dot(L.CENTER - b.global_position) < 0.0: inward = -inward
	return (actor.global_position - b.global_position).dot(inward)


func face_plaza() -> void:
	var d: Vector3 = L.CENTER - world.player.global_position
	world.player.rig.yaw = atan2(-d.x, -d.z)


func run() -> void:
	var session: Node = root.get_node("Session")
	var hosting: bool = "--coop-host" in OS.get_cmdline_user_args()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	var good := true
	if hosting:
		session.host(PORT)
		paused = false
		var deadline := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline and not (session.roster.size() == 2 and session.roster.values().all(func(member): return member.ready)):
			await create_timer(0.2, true).timeout
		if session.roster.size() != 2:
			print("COOP_HOST lobby incompleta")
			quit(1)
			return
		session.launch()
	else:
		session.profile("COOP", 0)
		session.join("127.0.0.1", PORT)
		paused = false
		await create_timer(2.0, true).timeout
		session.set_ready(true)
		await session.game_started
	await create_timer(1.0, true).timeout
	world.spawner.set_process(false)
	village = world.village
	world.terrain.ensure_near([L.CENTER])
	if hosting:
		for e in world.targets:
			if is_instance_valid(e): e.set_physics_process(false); e.global_position += Vector3(0, -300, 0)
		var guest: CharacterBody3D
		for id in world.actors:
			if world.actors[id] != world.player: guest = world.actors[id]
		# Ognuno sulla linea di una barricata diversa, a un metro dal centro della via.
		var lines: Array = []
		for i in 2:
			var b: Node3D = village.barricades[i]
			lines.append(Vector3(b.global_position.x, L.CENTER.y + 0.2, b.global_position.z) + b.global_basis.x.normalized() * (1.0 if i == 0 else -1.0))
		world.player.reset_at(lines[0])
		guest.reset_at(lines[1])
		await create_timer(2.5, true).timeout
		print("COOP_HOST sulle linee: host %.2f, client %.2f m oltre la linea" % [past_line(world.player, village.barricades[0]), past_line(guest, village.barricades[1])])
		village.set_barricades(true)
		await create_timer(2.5, true).timeout
		var before := [world.player.global_position, guest.global_position]
		var trapped_now := [trapped(world.player), trapped(guest)]
		var past := [past_line(world.player, village.barricades[0]), past_line(guest, village.barricades[1])]
		face_plaza()
		Input.action_press("move_forward")
		await create_timer(1.8, true).timeout
		Input.action_release("move_forward")
		var moved := [world.player.global_position.distance_to(before[0]), guest.global_position.distance_to(before[1])]
		for k in 2:
			print("COOP_HOST %s: dentro la barricata %s, oltre la linea %.2f m, poi cammina %.2f m" % [["host", "client"][k], trapped_now[k], past[k], moved[k]])
			good = good and not trapped_now[k] and past[k] > 0.6 and moved[k] > 2.0
		good = good and village.barricade_up and not trapped(world.player) and not trapped(guest)
		print("COOP_HOST valido ", good)
		await create_timer(2.0, true).timeout
		village.set_barricades(false)
		await create_timer(3.0, true).timeout
	else:
		var deadline := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline and not village.barricade_up:
			await physics_frame
		await create_timer(2.5, true).timeout
		var b: Node3D = village.barricades[1]
		var stuck := trapped(world.player)
		var past := past_line(world.player, b)
		var start: Vector3 = world.player.global_position
		face_plaza()
		Input.action_press("move_forward")
		await create_timer(1.8, true).timeout
		Input.action_release("move_forward")
		var moved: float = world.player.global_position.distance_to(start)
		var solid: bool = not (b.get_meta("shape") as CollisionShape3D).disabled and absf(b.position.y - L.CENTER.y) < 0.05
		good = village.barricade_up and solid and not stuck and past > 0.6 and moved > 2.0
		print("COOP_CLIENT barricata su e solida %s, dentro %s, oltre la linea %.2f m, cammina %.2f m, valido %s" % [solid, stuck, past, moved, good])
		await create_timer(4.0, true).timeout
	session.leave()
	world.queue_free()
	await process_frame
	quit(0 if good else 1)
