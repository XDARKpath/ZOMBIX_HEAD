extends Node3D
# Il boss che si evoca con l'esca all'altare: il Capomacello nella radura del bosco (bosses/boss_brain.gd, docs/BOSS.md). Il Macellaio esce dal pozzo di Borgo Cenere
# (world/villaggio), il Carceriere sta nella Rocca. Il Mago e il Signore delle Teste sono pronti per le zone future (bosses/).

const Props := preload("res://ui/camp/camp_props.gd")
const Placeholders := preload("res://art/placeholders.gd")
const BOSS_AUDIO := ["capomacello"]
const RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
const NATURE := "res://art/nature/%s.gltf"
var world: Node3D
var bosses: Array[Node3D] = []
var cleared: Array = [false]
var used: Array = [false]
var arenas: Array[Node3D] = []
var esche: Array[Node3D] = []
var fires: Dictionary = {}
var summoner: Node3D
var _away := 0.0
var rows := [
	["", Vector3(16, 0, -41), "Capomacello"],
]

func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "BossHunt"
	reset()

func reset() -> void:
	# Il Capomacello sta in fondo al ramo ovest del bosco.
	var spots := [RoadNet.arenas()[0]]
	for i in range(rows.size()):
		var at: Vector3 = spots[i]
		at.y = world.terrain.height(at.x, at.z) + 0.05
		rows[i][1] = at
	for boss in bosses:
		if is_instance_valid(boss): boss.queue_free()
	for arena in arenas:
		if is_instance_valid(arena): arena.queue_free()
	for esca in esche:
		if is_instance_valid(esca): esca.queue_free()
	bosses.clear(); arenas.clear(); esche.clear(); fires.clear()
	cleared = [false]; used = [false]
	AudioManager.clear_bosses()
	for i in range(rows.size()):
		_arena(rows[i][1], i)
		var esca_at: Vector3 = rows[i][1] + Vector3(0, 0, 4.6)
		esca_at.y = world.terrain.height(esca_at.x, esca_at.z) + 0.05
		_esca(esca_at, i)

func summon(index: int) -> bool:
	# Accendere l'esca è il modo in cui il custode entra in scena.
	if index < 0 or index >= rows.size() or used[index]: return false
	if Session.online and not multiplayer.is_server(): return false
	used[index] = true
	if world.get("quest"): world.quest._publish()
	_ignite(index)
	_spawn(index)
	var boss: Node3D = bosses[bosses.size() - 1]
	if is_instance_valid(esche[index]): _burst(esche[index].global_position)
	world.announce(Localization.t("ESCA ACCESA · {0}, {1}", [Localization.t(boss.title), Localization.t(boss.epithet)]), 6)
	return true

func context(actor: CharacterBody3D) -> String:
	if not world or not world.started: return ""
	for i in range(esche.size()):
		if used[i] or not is_instance_valid(esche[i]): continue
		if actor.global_position.distance_to(esche[i].global_position) <= 3.4:
			# L'altare resta spento finché lo sceriffo non ti manda qui con un'esca.
			if not world.quest.can_summon(i): return "ALTARE SPENTO · NON È ANCORA IL MOMENTO · PARLA CON LO SCERIFFO"
			if actor.baits > 0: return Localization.t("E  ACCENDI L'ESCA · EVOCA {0}", [Localization.t(world.quest.BOSS_NAMES[i])])
			return "TI SERVE UN'ESCA · CHIEDILA ALLO SCERIFFO"
	return ""

func try_summon(actor: CharacterBody3D) -> bool:
	for i in range(esche.size()):
		if used[i] or not is_instance_valid(esche[i]): continue
		if actor.global_position.distance_to(esche[i].global_position) <= 3.4:
			if not world.quest.can_summon(i) or actor.baits <= 0:
				world.announce(Localization.t("TI SERVE UN'ESCA · CHIEDILA ALLO SCERIFFO"), 4)
				return false
			if summon(i):
				summoner = actor
				actor.baits -= 1
				if world.get("survival"): world.survival._publish()
				return true
	return false

func _spawn(index: int) -> void:
	# Passa da _spawn_enemy come gli altri boss: così lo vedono e lo colpiscono anche i client.
	var boss: Node3D = world._spawn_enemy(rows[index][1] + Vector3.UP * 0.1)
	boss.name = rows[index][2]
	boss.custom_skin = "res://art/zx_infected/BOSS_Sheriff_Abomination.glb"
	boss.boss_weapon = "lamp"
	boss.set_kind(5)
	boss.title = "CAPOMACELLO"
	boss.epithet = "IL MACELLAIO DEL RIFUGIO"
	boss.max_health = 780.0
	boss.health = 780.0
	boss.alert_time = 1.6
	boss.use_brain("capomacello")
	boss.defeated.connect(_on_defeated.bind(index))
	bosses.append(boss)
	AudioManager.start_boss(BOSS_AUDIO[index], str(boss.title))
	AudioManager.boss_voice(BOSS_AUDIO[index], "roar", boss.global_position + Vector3.UP * 2.5, -4.0)

func _on_defeated(boss: Node3D, index: int) -> void:
	cleared[index] = true
	AudioManager.end_boss(BOSS_AUDIO[index])
	# Il premio va a tutta la squadra, come per i boss della Zona 2.
	for a in world.actors.values(): a.credits += 150
	if world.get("survival"): world.survival._publish()
	if world.get("quest"): world.quest.on_boss(index)

func all_cleared() -> bool:
	return cleared.count(true) == cleared.size()

func active_boss() -> Node3D:
	# Il custode da mostrare nell'HUD: quello sveglio più vicino al giocatore.
	var best: Node3D = null
	var distance := INF
	# Dai nemici che esistono su ogni computer, non dalla lista dell'host: così la barra la vede anche chi è collegato.
	# Il Macellaio e la Rocca (sotto terra, y > 150) hanno già la loro barra.
	for boss in world.targets:
		if not is_instance_valid(boss) or boss.dead or int(boss.get("kind")) != 5 or boss.has_meta("borgo") or boss.global_position.y > 150.0: continue
		var d: float = boss.global_position.distance_to(world.player.global_position)
		if d < 50 and d < distance:
			distance = d; best = boss
	if best == null and world.get("zone2"): best = world.zone2.active_boss()
	return best

func _check_cleared_by_progress() -> void:
	# Se i boss vengono rimossi (cambio zona) il conteggio resta coerente.
	for i in range(bosses.size()):
		if is_instance_valid(bosses[i]) and bosses[i].dead: cleared[i] = true

func _process(delta: float) -> void:
	if not world or not world.started: return
	_check_cleared_by_progress()
	if Session.online and not multiplayer.is_server(): return
	if not used[0] or cleared[0]: return
	var boss: Node3D = bosses[bosses.size() - 1] if not bosses.is_empty() else null
	if not is_instance_valid(boss) or boss.dead: return
	# Tutti lontani dalla radura (o il boss caduto fuori dal terreno): torna a dormire, l'esca torna a chi l'ha accesa.
	var home: Vector3 = rows[0][1]
	var near: CharacterBody3D = world.nearest_player(home)
	var gone: bool = near == null or near.global_position.distance_to(home) > 85.0
	_away = _away + delta if gone else 0.0
	if _away > 22.0 or boss.global_position.y < home.y - 30.0: _sleep(boss)


func _sleep(boss: Node3D) -> void:
	_away = 0.0
	bosses.erase(boss)
	boss.queue_free()
	used[0] = false
	if fires.has(0):
		fires[0][0].emitting = false
		fires[0][1].visible = false
	var back: Node3D = summoner if is_instance_valid(summoner) else world.player
	back.baits += 1
	AudioManager.end_boss(BOSS_AUDIO[0])
	world.announce(Localization.t("Il Capomacello è tornato nel bosco. L'esca è ancora buona: riaccendila sull'altare."), 6)
	if world.get("survival"): world.survival._publish()
	if world.get("quest"): world.quest._publish()

func _esca(at: Vector3, index: int) -> void:
	# Braciere basso con fuoco: si vede da lontano e si usa da vicino.
	var node := Node3D.new()
	node.name = "Esca%d" % index
	add_child(node)
	node.position = at
	esche.append(node)
	Props.cylinder(node, Vector3(0, 0.17, 0), 0.52, 0.34, Color("4b4a42"))
	Props.cylinder(node, Vector3(0, 0.32, 0), 0.40, 0.05, Color("1d1c19"))
	for i in range(6):
		var a := TAU * float(i) / 6.0
		Props.box(node, Vector3(cos(a) * 0.46, 0.37, sin(a) * 0.46), Vector3(0.13, 0.11, 0.13), Color("5b5a50"))
	var fire := CPUParticles3D.new()
	fire.name = "Fire"
	node.add_child(fire)
	fire.position = Vector3(0, 0.40, 0)
	fire.amount = 20
	fire.lifetime = 0.55
	fire.direction = Vector3.UP
	fire.spread = 12
	fire.initial_velocity_min = 0.5
	fire.initial_velocity_max = 1.15
	fire.gravity = Vector3(0, 0.5, 0)
	var flame := QuadMesh.new()
	flame.size = Vector2(0.24, 0.24)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flame_mat.albedo_color = Color("ff8a3c")
	flame_mat.emission_enabled = true
	flame_mat.emission = Color("ff6a1e")
	flame_mat.emission_energy_multiplier = 2.4
	flame.material = flame_mat
	fire.mesh = flame
	# Altare spento: si accende con l'esca dello sceriffo.
	fire.emitting = false
	var light := OmniLight3D.new()
	node.add_child(light)
	light.position = Vector3(0, 0.95, 0)
	light.light_color = Color("ff9a4a")
	light.light_energy = 1.5
	light.omni_range = 5.5
	light.visible = false
	fires[index] = [fire, light]

func _ignite(index: int) -> void:
	if not fires.has(index): return
	var pair: Array = fires[index]
	if is_instance_valid(pair[0]): pair[0].emitting = true
	if is_instance_valid(pair[1]): pair[1].visible = true

func _put_out(index: int) -> void:
	if not fires.has(index): return
	var pair: Array = fires[index]
	for item in pair:
		if is_instance_valid(item): item.queue_free()
	fires.erase(index)

func _burst(at: Vector3) -> void:
	var burst := CPUParticles3D.new()
	add_child(burst)
	burst.global_position = at + Vector3.UP * 0.5
	burst.amount = 26
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.lifetime = 0.7
	burst.direction = Vector3.UP
	burst.spread = 55
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.4
	burst.gravity = Vector3(0, -6, 0)
	var spark := SphereMesh.new()
	spark.radius = 0.035
	spark.height = 0.07
	burst.mesh = spark
	burst.color = Color("ffb066")
	burst.emitting = true
	get_tree().create_timer(1.6).timeout.connect(burst.queue_free)

func _arena(at: Vector3, index: int) -> void:
	var arena := Node3D.new()
	arena.name = "Arena%d" % index
	add_child(arena)
	arena.position = at
	arenas.append(arena)
	if index == 0: _forest_arena(arena, at)


## La radura del Capomacello: un anello di massi muschiosi e alberi morti nel bosco, con un solo passaggio aperto verso il
## sentiero. Dentro, tronchi caduti, felci, funghi e pietre ritte attorno all'altare. Niente di costruito.
func _forest_arena(arena: Node3D, at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4177
	var path: Array = RoadNet.paths()[1]
	var way: Vector3 = (path[path.size() - 1] - at)
	var gap: float = atan2(way.z, way.x)
	var count := 26
	for i in count:
		var angle: float = TAU * float(i) / float(count) + rng.randf_range(-0.05, 0.05)
		if absf(wrapf(angle - gap, -PI, PI)) < 0.34: continue
		var radius: float = rng.randf_range(17.5, 19.5)
		var spot := at + Vector3(cos(angle), 0, sin(angle)) * radius
		_rock(arena, spot, rng.randf_range(0.95, 1.7), rng)
		if i % 2 == 0: _rock(arena, spot + Vector3(cos(angle), 0, sin(angle)) * 2.2, rng.randf_range(0.7, 1.2), rng)
	# Dove finisce il sentiero, qualche pietra guida tra le rocce fino dentro la radura.
	for i in 6:
		var step: float = 21.5 - float(i) * 1.7
		var dir := Vector3(cos(gap), 0, sin(gap))
		var across := Vector3(-dir.z, 0, dir.x) * rng.randf_range(-0.7, 0.7)
		_nature(arena, "RockPath_Round_Small_%d" % (i % 3 + 1), at + dir * step + across, rng.randf() * TAU, 1.0)
	# Alberi secchi sull'anello: da fuori si riconosce la radura.
	for i in 5:
		var angle: float = gap + PI * 0.3 + float(i) * 1.05
		_nature(arena, "DeadTree_%d" % (i % 5 + 1), at + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(20.0, 22.0), rng.randf() * TAU, rng.randf_range(0.9, 1.2), 0.45)
	# Tronchi caduti: copertura durante la lotta.
	for row in [[Vector3(-9, 0, -5), 0.5], [Vector3(8, 0, -8), 2.1], [Vector3(10, 0, 6), 1.2], [Vector3(-8, 0, 8), -0.7]]:
		var log_at: Vector3 = _ground(at + row[0])
		var log_node := Node3D.new()
		arena.add_child(log_node)
		log_node.global_position = log_at
		log_node.rotation.y = row[1]
		Placeholders.cylinder(log_node, Vector3(0, 0.34, 0), 0.38, 4.6, Color("4a3a2a"), Vector3(0, 0, PI / 2))
		Placeholders.cylinder(log_node, Vector3(2.32, 0.34, 0), 0.34, 0.06, Color("8a7350"), Vector3(0, 0, PI / 2))
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4.6, 0.72, 0.72)
		shape.shape = box
		body.add_child(shape)
		log_node.add_child(body)
		body.position.y = 0.36
	# Pietre ritte attorno all'altare, come un cerchio antico.
	for i in 6:
		var angle: float = TAU * float(i) / 6.0 + 0.3
		var stone := _rock(arena, at + Vector3(0, 0, 4.6) + Vector3(cos(angle), 0, sin(angle)) * 3.2, 1.0, rng)
		stone.scale = Vector3(0.3, 0.8, 0.3)
	# Sottobosco dentro la radura.
	for i in 60:
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(5.0, 15.0)
		var kind: String = ["Fern_1", "Clover_1", "Clover_2", "Mushroom_Common", "Mushroom_Laetiporus", "Plant_1_Big"][i % 6]
		_nature(arena, kind, at + Vector3(cos(angle), 0, sin(angle)) * radius, rng.randf() * TAU, rng.randf_range(0.7, 1.2))
	var glow := OmniLight3D.new()
	glow.light_color = Color("9fb86a")
	glow.light_energy = 0.5
	glow.omni_range = 18.0
	arena.add_child(glow)
	glow.position = Vector3(0, 7.0, 0)


func _nature(parent: Node3D, asset: String, at: Vector3, yaw: float, size: float, solid_radius := 0.0) -> Node3D:
	var res: PackedScene = load(NATURE % asset)
	var node: Node3D = res.instantiate()
	parent.add_child(node)
	node.global_position = _ground(at)
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size
	if solid_radius > 0.0:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = solid_radius / size
		cyl.height = 4.0 / size
		shape.shape = cyl
		shape.position.y = 2.0 / size
		body.add_child(shape)
		node.add_child(body)
	return node


func _rock(parent: Node3D, at: Vector3, size: float, rng: RandomNumberGenerator) -> Node3D:
	return _nature(parent, "Rock_Medium_%d" % rng.randi_range(1, 3), at, rng.randf() * TAU, size, 0.9 * size)

func _ground(at: Vector3) -> Vector3:
	at.y = world.terrain.height(at.x, at.z) + 0.04
	return at

