extends SceneTree
# Mani sulle armi da fuoco:
# 1) le molle di tool_motion restano finite anche con fotogrammi lunghi (prima: NaN da 150 ms in su);
# 2) vista da fuori (ombra e compagni) la sinistra resta sull'arma durante tutta la ricarica (prima: 33-42 cm);
# 3) i suoni del gesto di ricarica arrivano anche con la prima persona ferma (GPS aperto).
# Va in finestra: godot --path ZOMBIX_HEAD --resolution 1280x720 -s res://tests/hands_contact_checks.gd
const TM := preload("res://player/tool_motion.gd")
const Arsenal := preload("res://weapons/zx_arsenal.gd")
const GUNS := ["assault_rifle", "revolver", "smg", "pump_shotgun", "lever_rifle", "sniper_rifle", "leaf_blower", "crossbow", "pistol"]
const TP_LEFT_MAX := 4.0      # cm
var failures := 0
var p: CharacterBody3D
var worst := 0.0          # le lambda catturano i locali per valore: la misura va su un membro
var samples := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame


func run() -> void:
	_springs()
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(2.0).timeout
	p = world.player
	if world.get("spawner"): world.spawner.set_process(false)
	for e in world.targets: e.set_physics_process(false)
	p.reset_at(Vector3(6, 0.1, 2))
	await frames(20)
	var rig := _find_rig(p)
	check(rig != null, "Il corpo visto da fuori ha tool_rig")
	if rig:
		for id in GUNS: await _reload_left_hand(rig, id)
	await _reload_sounds_without_fp()
	print("hands_contact_checks: %s (%d errori)" % ["OK" if failures == 0 else "FALLITO", failures])
	quit(1 if failures else 0)


func _springs() -> void:
	for dt in [0.08, 0.1, 0.15, 0.3, 0.47]:
		var m = TM.new(); m.setup("revolver"); m.tick(0.016, [], 0.0, false, false, false, -1.0, -1.0)
		m.shot(false)
		var worst := 0.0
		var finite := true
		for i in 60:
			m.tick(dt, [], 0.0, false, false, false, -1.0, -1.0)
			worst = maxf(worst, m._spring_p.length())
			finite = finite and m.frame().origin.is_finite()
		check(finite and worst < 0.3, "Molle stabili a %d ms per fotogramma: max %.3f" % [int(dt * 1000), worst])


func _find_rig(actor: Node) -> Node:
	for n in actor.find_children("*", "SkeletonModifier3D", true, false):
		if n.get_script() and str(n.get_script().resource_path).ends_with("tool_rig.gd"): return n
	return null


func _equip(id: String) -> void:
	if not p.owned.has(id): p.owned.append(id)
	if not p.hotbar.has(id):
		p.inventory_slots = 9
		p.hotbar[p.hotbar.find("")] = id
	p.select_slot(p.hotbar.find(id))
	p.magazine = Arsenal.magazine(id)


## Distanza (cm) fra il polso sinistro e il pugno chiuso sull'appoggio dell'arma VERA, senza scivolamento.
func _left_error(rig: Node) -> float:
	if rig.kind == "" or rig.weapon == null or not rig.enabled or rig._pause > 0.0: return -1.0
	var grip: Dictionary = rig.motion.grip("l")
	if grip.is_empty() or rig._left_w < 0.99: return -1.0
	var sk: Skeleton3D = rig.get_skeleton()
	var a: Transform3D = sk.get_bone_global_pose(rig._anchor)
	var chest := sk.get_bone_global_pose(rig._spine)
	var rest := sk.get_bone_global_rest(rig._spine)
	var up: Vector3 = chest.basis.orthonormalized() * rest.basis.orthonormalized().inverse() * Vector3.UP
	var place: Vector3 = rig.motion.left_shift + (Vector3(0, 0, 0.03) if rig.motion.kind == "pistol" else Vector3.ZERO)
	var sh: Vector3 = sk.get_bone_global_pose(rig._ids["upperarm_l"]).origin
	var want: Array = TM.fist_for(a, grip, "l", sh, up, 0.095, 0.035, 99.0, place, rig.motion.edge_w)
	return sk.get_bone_global_pose(rig._ids["hand_l"]).origin.distance_to(want[0]) * 100.0


func _reload_left_hand(rig: Node, id: String) -> void:
	_equip(id)
	await frames(60)
	worst = 0.0
	samples = 0
	var sk: Skeleton3D = rig.get_skeleton()
	var measure := func() -> void:
		var e := _left_error(rig)
		if e >= 0.0:
			worst = maxf(worst, e)
			samples += 1
	sk.skeleton_updated.connect(measure)
	p.magazine = 0
	p.reload_weapon()
	var guard := 0
	while (p.reload_left > 0.0 or p.magazine < Arsenal.magazine(id)) and guard < 900:
		guard += 1
		await physics_frame
	await frames(40)       # anche l'assestamento dopo la ricarica
	sk.skeleton_updated.disconnect(measure)
	check(samples > 20 and worst <= TP_LEFT_MAX, "%s: da fuori la sinistra resta sull'arma in ricarica (max %.1f cm su %d misure)" % [id, worst, samples])


## Con la prima persona ferma (come col GPS aperto) ogni passo della ricarica suona lo stesso, una volta.
func _reload_sounds_without_fp() -> void:
	_equip("assault_rifle")
	await frames(30)
	var fpw: Node = null
	for c in p.rig.camera.get_children(): if c.has_method("give_held"): fpw = c
	if fpw: fpw.process_mode = Node.PROCESS_MODE_DISABLED
	var am: Node = root.get_node("AudioManager")
	var heard := {}
	var seen := {}
	p.magazine = 0
	p.reload_weapon()
	var expected: Array = []
	for step in Arsenal.reload_steps("assault_rifle", p.reload_total): expected.append(step[1])
	while p.reload_left > 0.0:
		await physics_frame
		for pl in am._sfx_pool:
			var s: AudioStreamPlayer = pl
			var key := s.get_instance_id()
			var pos := s.get_playback_position() if s.playing else 0.0
			var was: Array = seen.get(key, [null, false, 0.0])
			if s.playing and (s.stream != was[0] or not was[1] or pos + 0.001 < float(was[2])):
				var n := str(s.stream.resource_path).get_file() if s.stream else "?"
				heard[n] = int(heard.get(n, 0)) + 1
			seen[key] = [s.stream, s.playing, pos]
	if fpw: fpw.process_mode = Node.PROCESS_MODE_INHERIT
	var total := 0
	for n in heard: total += int(heard[n])
	check(total >= expected.size(), "Ricarica con la prima persona ferma: %d suoni per %d passi %s" % [total, expected.size(), str(expected)])
