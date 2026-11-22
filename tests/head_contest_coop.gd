extends SceneTree
# Testa contesa, due processi veri: host e ospite accanto alla stessa testa, l'host la raccoglie per primo.
# L'ospite, che preme E subito dopo, deve leggere "PRESA DA <nome dell'host>" (prima la testa spariva in silenzio).
# Controllo: un'ospite che preme E lontano da teste appena prese non riceve nessun avviso.
# godot --path . --headless -s res://tests/head_contest_coop.gd -- --contest-host
# godot --path . --headless -s res://tests/head_contest_coop.gd -- --contest-client
const PORT := 27864
const MARK := "user://head_contest_%s.json"
var world: Node3D


func _initialize() -> void:
	call_deferred("run")


func wait_s(s: float) -> void:
	await create_timer(s, true).timeout


func mark(name: String, data) -> void:
	var f := FileAccess.open(MARK % name, FileAccess.WRITE); f.store_string(JSON.stringify(data)); f.close()


func until(name: String, seconds := 30.0):
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end and not FileAccess.file_exists(MARK % name): await process_frame
	return JSON.parse_string(FileAccess.get_file_as_string(MARK % name)) if FileAccess.file_exists(MARK % name) else null


func run() -> void:
	var session: Node = root.get_node("Session")
	var hosting: bool = "--contest-host" in OS.get_cmdline_user_args()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	if hosting:
		for n in ["ready", "res", "far", "res_far"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(MARK % n))
		session.profile("CAPO", 0)
		session.host(PORT)
		paused = false
		var end := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < end and not (session.roster.size() == 2 and session.roster.values().all(func(m): return m.ready)):
			await wait_s(0.2)
		if session.roster.size() != 2:
			print("CONTEST_HOST lobby incompleta"); quit(1); return
		session.launch()
	else:
		session.profile("OSPITE", 0)
		session.join("127.0.0.1", PORT)
		paused = false
		await wait_s(2.0)
		session.set_ready(true)
		await session.game_started
	await wait_s(1.5)
	world.spawner.set_process(false)
	var rules: Node3D = world.survival
	var kind: String = ItemInfo.KIND_HEAD[0]
	if not hosting:
		await until("ready")
		await wait_s(0.6)
		world.notice.text = ""
		rules.request("use")
		await wait_s(1.0)
		mark("res", {"avviso": world.notice.text, "teste": int(world.player.items.get(kind, 0))})
		await until("far")
		await wait_s(0.6)
		world.notice.text = ""
		rules.request("use")
		await wait_s(1.0)
		mark("res_far", {"avviso": world.notice.text})
		await wait_s(2.0)
		quit(0)
		return
	for e in world.targets:
		if is_instance_valid(e): e.set_physics_process(false); e.global_position += Vector3(0, -400, 0)
	var guest := 0
	for id in world.actors:
		if world.actors[id] != world.player: guest = id
	var spot: Vector3 = Vector3(12, 0, -40)
	spot.y = world.terrain.height(spot.x, spot.z)
	world.player.reset_at(spot + Vector3(-1.2, 0.3, 0))
	world.actors[guest].position = spot + Vector3(1.2, 0.3, 0); world.actors[guest].velocity = Vector3.ZERO
	var model_id = null
	for e in world.targets:
		if is_instance_valid(e) and e.get("avatar"): model_id = e.avatar.model_id; break
	rules.heads.append([rules.next_head, model_id, Transform3D(Basis.IDENTITY, spot + Vector3.UP), spot + Vector3.UP * 0.18, kind]); rules.next_head += 1
	rules._publish()
	await wait_s(1.0)
	mark("ready", true)
	await wait_s(0.5)
	rules.request("use")
	var got: bool = int(world.player.items.get(kind, 0)) == 1
	var res = await until("res")
	# Seconda prova: l'ospite lontano dalla testa presa preme E.
	world.actors[guest].position = spot + Vector3(30, 0.3, 0); world.actors[guest].velocity = Vector3.ZERO
	await wait_s(1.0)
	mark("far", true)
	var far = await until("res_far")
	var shown: String = str(res.get("avviso", "")) if res else ""
	var checks := {
		"l'host raccoglie per primo": got,
		"l'ospite legge chi l'ha presa («%s»)" % shown: shown.contains("CAPO"),
		"una testa sola: l'ospite non ne ha": res != null and int(res.get("teste", 1)) == 0,
		"lontano dalla testa nessun avviso («%s»)" % (str(far.get("avviso", "")) if far else "?"): far != null and not str(far.get("avviso", "")).contains("CAPO"),
	}
	var good := true
	for name in checks:
		print("CONTEST_HOST ", "PASS " if checks[name] else "FAIL ", name)
		good = good and checks[name]
	session_leave()
	quit(0 if good else 1)


func session_leave() -> void:
	root.get_node("Session").leave()
