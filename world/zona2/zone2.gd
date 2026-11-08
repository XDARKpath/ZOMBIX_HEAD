extends Node3D
# ZONA 2 · IL MARE DI SABBIA. Un vecchio fondale prosciugato: dune, barche arenate, costole di balena. Si arriva dal valico nord col 4×4.
# Porto Secco è il presidio: la sceriffa Mira, il negozio (ZXShop della tappa 1) e il riposo. Due boss: Il Mago nel Cratere e il
# Signore delle Teste nel Cimitero delle Barche. Morti tutti e due, si apre il secondo valico verso il Borgo del Ripetitore.
# Decide l'host, i client ricevono lo stato.

const Route := preload("res://world/campaign/route.gd")
const Terrain := preload("res://world/campaign/terrain.gd")
const Solid := preload("res://world/campaign/solid_props.gd")
const Fx := preload("res://bosses/boss_fx.gd")
const KIT := "res://art/zx_borgo/%s.glb"
const DESERT := "res://art/zx_desert/%s.glb"
const NATURE := "res://art/nature/%s.gltf"
enum { MEET, HUNT, REPORT, DONE }
const MIRA_LOCAL := Vector3(-17, 0, -9)
const TALK_RANGE := 3.4
const SAFE_RADIUS := 40.0
const STEPS := ["Parla con Mira a Porto Secco", "Il Mago, nel Cratere", "Il Signore delle Teste, nel Cimitero", "Torna da Mira"]
const OPTIONS := ["Come si battono?", "Dove vanno le strade?", "Torno dopo."]

var world: Node3D
var stage := MEET
var dead_matriarca := false
var dead_signore := false
var mira: Node3D
var mira_at: Vector3
var boss_matriarca: Node3D
var boss_signore: Node3D
var _spawned: Array[Node3D] = []
var _spawn_clock := 3.0
var _away: Dictionary = {"matriarca": 0.0, "signore": 0.0}
var _env: Environment
var _sun: DirectionalLight3D
var _base := {}
var _desert_k := 0.0
var _dust: CPUParticles3D


func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "Zone2"
	_town()
	_arena_matriarca()
	_arena_signore()
	_scatter()
	_grab_environment()


func reset() -> void:
	stage = MEET
	dead_matriarca = false
	dead_signore = false
	for b in [boss_matriarca, boss_signore]:
		if is_instance_valid(b): b.queue_free()
	boss_matriarca = null
	boss_signore = null
	_spawned.clear()


func authority() -> bool:
	return not Session.online or multiplayer.is_server()


# ------------------------------------------------------------------ storia
## Da quando conta la Zona 2 sull'obiettivo a schermo: si è arrivati a Porto Secco e il presidio è libero.
func active() -> bool:
	var mission: Node3D = world.expedition
	if stage >= DONE or mission.zone_index < 1: return false
	return not (mission.zone_index == 1 and mission.stage == 3)


func secured() -> bool:
	var mission: Node3D = world.expedition
	return mission.zone_index >= 1 and not (mission.zone_index == 1 and mission.stage == 3)


func safe(at: Vector3) -> bool:
	return secured() and Vector2(at.x - Route.POINTS[1].x, at.z - Route.POINTS[1].z).length() < SAFE_RADIUS


func title() -> String:
	match stage:
		MEET: return "PARLA CON LA SCERIFFA MIRA"
		HUNT:
			if not dead_matriarca and not dead_signore: return "UCCIDI IL MAGO E IL SIGNORE DELLE TESTE"
			return "UCCIDI IL SIGNORE DELLE TESTE" if dead_matriarca else "UCCIDI IL MAGO"
	return "TORNA DA MIRA"


func detail() -> String:
	match stage:
		MEET: return "Porto Secco · sotto la tettoia, accanto alla barca"
		HUNT:
			if not dead_matriarca and not dead_signore: return "Il Cratere è a nord, il Cimitero delle Barche a ovest"
			return "Il Cimitero delle Barche, a ovest" if dead_matriarca else "Il Cratere, a nord"
	return "Porto Secco · il valico verso est è libero"


func target() -> Vector3:
	match stage:
		HUNT:
			if not dead_matriarca and not dead_signore:
				var p: Vector3 = world.player.global_position
				return Route.ARENA_MATRIARCA if p.distance_to(Route.ARENA_MATRIARCA) < p.distance_to(Route.ARENA_SIGNORE) else Route.ARENA_SIGNORE
			return Route.ARENA_SIGNORE if dead_matriarca else Route.ARENA_MATRIARCA
	return mira_at


func steps_text() -> String:
	var marks := [stage > MEET, dead_matriarca, dead_signore, stage >= DONE]
	var text := ""
	for i in STEPS.size():
		text += "%s  %s\n" % ["✓" if marks[i] else "·", STEPS[i]]
	return text


func lines() -> Array:
	match stage:
		MEET:
			return ["Hai passato il valico col 4×4 di Lago Cenere? Allora il vecchio sceriffo non ti ha mentito. Io sono Mira, qui a Porto Secco comando io.",
				"Questo era mare. Adesso è sabbia, barche e gente che si secca al sole. Le teste te le pago come lui, con la V.",
				"Due bestie tengono chiuso il valico a est. Il Mago è nel Cratere, a nord. Il Signore delle Teste è nel Cimitero delle Barche, a ovest. Finché respirano non si passa."]
		HUNT:
			if dead_matriarca: return ["Il Mago è finito. Resta il Signore delle Teste, nel Cimitero delle Barche a ovest."]
			if dead_signore: return ["Il Signore delle Teste è a pezzi. Resta il Mago, nel Cratere a nord."]
			return ["Il Mago è nel Cratere a nord, il Signore delle Teste nel Cimitero a ovest. Se non sai come batterli, chiedimelo."]
		REPORT:
			return ["Tutti e due. Sentivo il valico saltare fin da qui.", "Tieni, ottocento crediti. Prendi la strada a est: oltre le montagne c'è il Borgo del Ripetitore, e speriamo che ci sia ancora qualcuno."]
	return ["Il valico a est è aperto. Buona strada."]


const HOW_TO := [
	"Il Mago si copre con un velo acido: le pallottole ci muoiono dentro. Arco, balestra, fucile da caccia lo strappano, e lì fa male tutto.",
	"Se gli vai addosso sparisce e riappare lontano. Quando alza le braccia e il cielo si fa verde, tiragli subito: se finisce la tempesta non resta terra su cui stare.",
	"Il Signore delle Teste porta una corona di teschi che gli gira attorno e devia tutto. Solo una lama li taglia: machete, spada, ascia. Ogni teschio che perde lo rende più veloce: tieniti pronto.",
]
const ROADS := [
	"A sud c'è il valico da cui sei venuto. A est, dopo la Cava, il secondo valico: chiuso finché quei due sono vivi.",
	"Il Bazar è qui accanto. Ha quello che ti serve contro di loro: balestra e fucili lunghi. Le lame le hai già, spero.",
]


func request_use(actor: CharacterBody3D) -> bool:
	if not is_instance_valid(mira) or actor.global_position.distance_to(mira_at) > TALK_RANGE: return false
	if world.survival.dialogue_open: return false
	world.survival.open_npc_dialogue("Sceriffa Mira", lines(), OPTIONS, _on_choice)
	if authority(): talked()
	else: ask_talk.rpc_id(1)
	return true


func _on_choice(index: int) -> void:
	match index:
		0: world.survival.show_npc_lines(HOW_TO)
		1: world.survival.show_npc_lines(ROADS)
		_: world.survival.close_sheriff_dialogue()


func near_sheriff(actor: Node3D, distance: float) -> bool:
	return is_instance_valid(mira) and actor.global_position.distance_to(mira_at) <= distance


func context(actor: Node3D) -> String:
	if near_sheriff(actor, TALK_RANGE): return "E  PARLA CON LA SCERIFFA MIRA"
	return ""


@rpc("any_peer", "call_remote", "reliable")
func ask_talk() -> void:
	if authority(): talked()


func talked() -> void:
	if stage == MEET:
		stage = HUNT
		_publish()
	elif stage == REPORT:
		stage = DONE
		for a in world.actors.values(): a.credits += 800
		world.survival._publish()
		world.announce("MIRA · +800 crediti · Prendi la strada a est", 7)
		_publish()


func _on_boss(style: String) -> void:
	if style == "matriarca": dead_matriarca = true
	else: dead_signore = true
	var head: String = "item_testa_matriarca" if style == "matriarca" else "item_testa_signore"
	var at: Vector3 = Route.ARENA_MATRIARCA if style == "matriarca" else Route.ARENA_SIGNORE
	# Chi è vivo e vicino la prende in tasca. Se sono tutti morti o con le tasche piene resta per terra: non si perde mai.
	var actor: CharacterBody3D = world.nearest_player(at)
	for a in world.actors.values(): a.credits += 300
	if is_instance_valid(actor) and not actor.dead and actor.can_take(head):
		actor.add_item(head)
	else:
		at.y = Terrain.ground_height(at.x, at.z)
		world.survival.heads.append([world.survival.next_head, "res://art/zx_infected/ZMB_Walker_1.glb", Transform3D(Basis(), at + Vector3.UP), at + Vector3(0.6, 0.18, 0.6), head])
		world.survival.next_head += 1
	world.survival._publish()
	AudioManager.end_boss("mago" if style == "matriarca" else "teste")
	world.announce(Localization.t("{0} È MORTO · +300 crediti e la sua testa", [Localization.t("IL MAGO" if style == "matriarca" else "IL SIGNORE DELLE TESTE")]), 7)
	if dead_matriarca and dead_signore and stage < REPORT: stage = REPORT
	_publish()


# ------------------------------------------------------------------ rete e salvataggio
func _publish() -> void:
	if Session.online and multiplayer.is_server():
		for peer in Session.connected_peers(): receive.rpc_id(peer, stage, dead_matriarca, dead_signore)


@rpc("authority", "call_remote", "reliable")
func receive(step: int, matriarca: bool, signore: bool) -> void:
	stage = step
	dead_matriarca = matriarca
	dead_signore = signore


func save_data() -> Dictionary:
	return {"stage": stage, "matriarca": dead_matriarca, "signore": dead_signore}


func load_data(data: Dictionary) -> void:
	stage = int(data.get("stage", MEET))
	dead_matriarca = bool(data.get("matriarca", false))
	dead_signore = bool(data.get("signore", false))


# ------------------------------------------------------------------ boss (host)
func _process(delta: float) -> void:
	if not world or not world.started or not is_instance_valid(world.player): return
	_atmosphere(delta)
	if not authority(): return
	_boss_logic("matriarca", delta)
	_boss_logic("signore", delta)
	_wanderers(delta)


func _boss_logic(style: String, delta: float) -> void:
	var dead: bool = dead_matriarca if style == "matriarca" else dead_signore
	if dead: return
	var at: Vector3 = Route.ARENA_MATRIARCA if style == "matriarca" else Route.ARENA_SIGNORE
	var boss: Node3D = boss_matriarca if style == "matriarca" else boss_signore
	var near: CharacterBody3D = world.nearest_player(at)
	var distance: float = near.global_position.distance_to(at) if near else INF
	if not is_instance_valid(boss):
		if distance < 34.0: _spawn_boss(style)
		return
	if boss.dead:
		_on_boss(style)
		return
	# Tutti scappati: la bestia torna a dormire con la vita piena, così non si vince logorandola da lontano.
	_away[style] = _away[style] + delta if distance > 85.0 else 0.0
	if _away[style] > 22.0:
		_away[style] = 0.0
		boss.queue_free()
		if style == "matriarca": boss_matriarca = null
		else: boss_signore = null
		AudioManager.end_boss("mago" if style == "matriarca" else "teste")


func spawn_for_test(style: String) -> Node3D:
	var present: Node3D = boss_matriarca if style == "matriarca" else boss_signore
	if not is_instance_valid(present): _spawn_boss(style)
	return boss_matriarca if style == "matriarca" else boss_signore


func _spawn_boss(style: String) -> void:
	var at: Vector3 = Route.ARENA_MATRIARCA if style == "matriarca" else Route.ARENA_SIGNORE
	at.y = Terrain.ground_height(at.x, at.z)
	var boss: Node3D = world._spawn_enemy(at + Vector3.UP * 0.1)
	if style == "matriarca":
		boss.name = "IlMago"
		boss.custom_skin = "res://art/zx_infected/BOSS_Toxic_Matriarch.glb"
		boss.set_kind(5)
		boss.title = "IL MAGO"
		boss.epithet = "IL VELENO DEL CRATERE"
		boss.voice_id = "mago"
		boss.max_health = 1150.0
		boss.health = 1150.0
		boss_matriarca = boss
	else:
		boss.name = "SignoreDelleTeste"
		boss.custom_skin = "res://art/zx_infected/BOSS_Subject_Zero.glb"
		boss.boss_weapon = "crown+machete"
		boss.set_kind(5)
		boss.title = "SIGNORE DELLE TESTE"
		boss.epithet = "IL RE DEL CIMITERO"
		boss.voice_id = "teste"
		boss.max_health = 1300.0
		boss.health = 1300.0
		boss_signore = boss
	boss.alert_time = 1.8
	boss.use_brain(style)
	AudioManager.start_boss("mago" if style == "matriarca" else "teste", boss.title)
	world.boss_fx("say", Vector3.ZERO, {"text": "%s · %s" % [Localization.t(boss.title), Localization.t(boss.epithet)], "t": 5.0})
	world.boss_fx("crack", at, {"r": 7.0, "ember": style == "matriarca", "shake": 1.0, "life": 14.0})


func active_boss() -> Node3D:
	for boss in [boss_matriarca, boss_signore]:
		if is_instance_valid(boss) and not boss.dead and boss.global_position.distance_to(world.player.global_position) < 60.0: return boss
	return null


## Qualche infetto che vaga per le dune: mai dentro Porto Secco, mai sugli occhi, e sparisce quando resta indietro.
func _wanderers(delta: float) -> void:
	_spawn_clock -= delta
	if _spawn_clock > 0.0: return
	_spawn_clock = 4.0
	_spawned = _spawned.filter(func(e): return is_instance_valid(e) and not e.dead)
	var p: CharacterBody3D = world.player
	if p == null or p.dead or Route.desert(p.global_position.x, p.global_position.z) < 0.5: return
	for e in _spawned:
		if e.global_position.distance_to(p.global_position) > 110.0: e.queue_free()
	if _spawned.size() >= 7 or safe(p.global_position): return
	var yaw: float = randf() * TAU
	var spot: Vector3 = p.global_position + Vector3(cos(yaw), 0, sin(yaw)) * randf_range(32.0, 46.0)
	if Route.desert(spot.x, spot.z) < 0.9 or safe(spot): return
	spot.y = Terrain.ground_height(spot.x, spot.z)
	var enemy: Node3D = world._spawn_enemy(spot)
	enemy.set_kind([0, 0, 1, 3, 2, 4][randi() % 6], 2)
	_spawned.append(enemy)


# ------------------------------------------------------------------ aria del deserto
func _grab_environment() -> void:
	for child in world.landscape.get_children():
		if child is WorldEnvironment: _env = child.environment
		if child is DirectionalLight3D: _sun = child
	_dust = CPUParticles3D.new()
	_dust.name = "SandDrift"
	add_child(_dust)
	_dust.amount = 70
	_dust.lifetime = 3.2
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(30, 1.2, 30)
	_dust.direction = Vector3(1, 0.02, 0.35)
	_dust.spread = 8.0
	_dust.initial_velocity_min = 3.0
	_dust.initial_velocity_max = 7.0
	_dust.gravity = Vector3.ZERO
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.6
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 0.22)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.68, 0.42, 0.14)
	quad.material = mat
	_dust.mesh = quad
	_dust.emitting = false


func _atmosphere(delta: float) -> void:
	if _env == null: return
	var at: Vector3 = world.player.global_position
	# Sottoterra (Rocca, Cripta) resta la loro aria.
	var wanted: float = Route.desert(at.x, at.z) if at.y < 150.0 else 0.0
	_desert_k = move_toward(_desert_k, wanted, delta * 0.35)
	if _base.is_empty():
		_base = {"fog": _env.fog_light_color, "ambient": _env.ambient_light_color, "energy": _env.ambient_light_energy, "sat": _env.adjustment_saturation, "sun": _sun.light_color if _sun else Color.WHITE}
	_env.fog_light_color = (_base.fog as Color).lerp(Color("c6a67a"), _desert_k)
	_env.ambient_light_color = (_base.ambient as Color).lerp(Color("e6d3b0"), _desert_k)
	_env.ambient_light_energy = lerpf(_base.energy, 0.62, _desert_k)
	_env.adjustment_saturation = lerpf(_base.sat, 1.0, _desert_k)
	if _sun: _sun.light_color = (_base.sun as Color).lerp(Color("ffe6bd"), _desert_k)
	_dust.emitting = _desert_k > 0.5
	if _dust.emitting: _dust.global_position = at + Vector3(-14, 1.5, -4)


# ------------------------------------------------------------------ Porto Secco
func _ground(at: Vector3) -> Vector3:
	at.y = Terrain.ground_height(at.x, at.z)
	return at


func _put(parent: Node3D, path: String, at: Vector3, yaw: float = 0.0, size: float = 1.0, sink: float = 0.0, tilt: Vector3 = Vector3.ZERO) -> Node3D:
	if not ResourceLoader.exists(path): return null
	var node: Node3D = load(path).instantiate()
	parent.add_child(node)
	node.global_position = _ground(at) + Vector3.DOWN * sink
	node.rotation = Vector3(tilt.x, yaw, tilt.z)
	node.scale = Vector3.ONE * size
	return node


func _town() -> void:
	var c: Vector3 = Route.POINTS[1]
	var town := Node3D.new()
	town.name = "PortoSecco"
	add_child(town)
	var kit := func(id: String, x: float, z: float, yaw := 0.0, size := 1.0) -> Node3D:
		return _put(town, KIT % id, c + Vector3(x, 0, z), yaw, size)
	# La tettoia di Mira, con tavolo, casse e la mappa appesa.
	mira_at = _ground(c + MIRA_LOCAL)
	var shade := kit.call("SM_Bld_Exterior_Shade_01", -19.5, -9.0, PI / 2) as Node3D
	if shade: shade.position.y += 2.7
	kit.call("SM_Prop_Table_Metal_01", -19.0, -7.2, 0.3)
	kit.call("SM_Prop_Chair_01", -20.5, -8.4, -0.8)
	kit.call("SM_Prop_Barrel_Metal_01", -22.0, -13.0)
	kit.call("SM_Prop_CardboardBox_Stack_01", -22.5, -6.0, 0.6)
	_mira()
	# Le case di chi non se n'è mai andato, coi muri che la sabbia sta mangiando.
	_hut(town, c + Vector3(-34, 0, -30), 0.15, 3, 2)
	_hut(town, c + Vector3(-44, 0, -13), 1.4, 2, 2)
	_hut(town, c + Vector3(28, 0, -32), -0.3, 3, 2)
	_hut(town, c + Vector3(42, 0, -20), 1.1, 2, 2)
	_hut(town, c + Vector3(-36, 0, 18), -1.2, 2, 3)
	# Le tende di chi si è fermato.
	kit.call("SM_Borgo_Tent_Dome", -30.0, -16.0, 0.4)
	kit.call("SM_Borgo_Tent_Dome_Orange", -34.0, -4.0, 2.0)
	kit.call("SM_Borgo_Tent_Dome_Blue", -26.0, -25.0, -0.7)
	kit.call("SM_Prop_Woodstack_01", -29.0, -9.0, 0.2)
	kit.call("SM_Borgo_Barrel_Water", -24.0, -19.0)
	kit.call("SM_Borgo_Barrel_Water_Open", -25.2, -18.2, 0.6)
	# La cisterna del paese e i container del porto.
	kit.call("SM_Prop_Container_01", 22.0, 16.0, 0.2)
	kit.call("SM_Prop_Container_01", 24.0, 25.0, 1.5)
	kit.call("SM_Prop_Pallet_01", 17.0, 14.0, 0.8)
	kit.call("SM_Prop_GasCan_01", 15.8, 13.2, 0.3)
	kit.call("SM_Borgo_Truck_Wreck", 30.0, 2.0, 2.3)
	kit.call("SM_Prop_Powerbox_01", 13.0, 18.0, PI)
	# Le barche: è un porto senza mare.
	_put(town, "res://art/lake/SM_Lake_Rowboat.glb", c + Vector3(-13, 0, -24), 0.7, 3.6, 0.35, Vector3(0.14, 0, 0.24))
	_put(town, "res://art/lake/SM_Lake_Rowboat.glb", c + Vector3(33, 0, 15), 2.2, 4.4, 0.45, Vector3(-0.1, 0, -0.3))
	_put(town, "res://art/lake/SM_Lake_Rowboat.glb", c + Vector3(-40, 0, 14), -0.6, 3.0, 0.5, Vector3(0.2, 0, 0.1))
	_put(town, "res://art/lake/SM_Lake_Dock.glb", c + Vector3(-22, 0, 22), 1.2, 1.2, 0.2)
	# Il cartello all'ingresso, dalla strada che arriva da sud.
	var welcome := Label3D.new()
	welcome.text = Localization.t("PORTO SECCO\nSCERIFFO · BAZAR · ACQUA")
	welcome.font_size = 48
	welcome.pixel_size = 0.012
	welcome.outline_size = 12
	welcome.modulate = Color("ffe0a0")
	town.add_child(welcome)
	welcome.global_position = _ground(c + Vector3(7.5, 0, 34)) + Vector3.UP * 3.6
	welcome.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_post(town, c + Vector3(7.5, 0, 34), 3.2, 0.2)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffbf7a")
	glow.light_energy = 1.1
	glow.omni_range = 11.0
	town.add_child(glow)
	glow.global_position = mira_at + Vector3(-1.5, 3.2, 0)


## Palo di legno piantato nella sabbia.
func _post(parent: Node3D, at: Vector3, height: float, width: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, width)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("5b4630")
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	parent.add_child(node)
	node.global_position = _ground(at) + Vector3.UP * height * 0.5


## Casa piccola con i muri modulari del borgo: larga w moduli e profonda d, una porta sul davanti, finestre e tetto piano.
func _hut(parent: Node3D, at: Vector3, yaw: float, w: int, d: int) -> void:
	var hut := Node3D.new()
	hut.name = "Casa"
	parent.add_child(hut)
	hut.global_position = _ground(at)
	hut.rotation.y = yaw
	var wall := func(id: String, local: Vector3, turn: float) -> void:
		var node: Node3D = load(KIT % id).instantiate()
		hut.add_child(node)
		node.position = local
		node.rotation.y = turn
	var size := 3.0
	for i in w:
		var front := "SM_Bld_Wall_Brick_Door_01" if i == w / 2 else "SM_Bld_Wall_Brick_Window_01"
		wall.call(front, Vector3(i * size, 0, d * size), 0.0)
		wall.call("SM_Bld_Wall_Brick_01", Vector3((i + 1) * size, 0, 0), PI)
	for i in d:
		wall.call("SM_Bld_Wall_Brick_Window_01" if i == 0 else "SM_Bld_Wall_Brick_01", Vector3(w * size, 0, (i + 1) * size), PI / 2)
		wall.call("SM_Bld_Wall_Brick_01", Vector3(0, 0, i * size), -PI / 2)
	for i in w:
		for k in d:
			var roof: Node3D = load(KIT % "SM_Bld_Roof_Flat_Closed_01").instantiate()
			hut.add_child(roof)
			roof.position = Vector3(i * size, 3.0, (k + 1) * size)


func _mira() -> void:
	var body := StaticBody3D.new()
	body.name = "SceriffaMira"
	body.collision_layer = 1
	body.set_meta("trader", true)
	add_child(body)
	body.global_position = mira_at
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.5
	shape.shape = capsule
	shape.position.y = 0.78
	body.add_child(shape)
	var npc := ZXNpc.new()
	npc.name = "MiraBody"
	npc.npc = "SM_NPC_Manager"
	body.add_child(npc)
	npc.rotation.y = -PI * 0.42
	mira = body
	var tag := Label3D.new()
	tag.text = Localization.t("SCERIFFA MIRA")
	tag.font_size = 30
	tag.pixel_size = 0.004
	tag.outline_size = 8
	tag.modulate = Color("ffe9a8")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 2.15, 0)
	body.add_child(tag)


# ------------------------------------------------------------------ arene
## Il Cratere: pareti di roccia attorno, pilastri dietro cui ripararsi dai dardi, vasche d'acido che fumano.
func _arena_matriarca() -> void:
	var c: Vector3 = Route.ARENA_MATRIARCA
	var arena := Node3D.new()
	arena.name = "Cratere"
	add_child(arena)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var gap := atan2(Route.POINTS[1].z - c.z, Route.POINTS[1].x - c.x)
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		if absf(wrapf(a - gap, -PI, PI)) < 0.32: continue
		var r: float = rng.randf_range(27.0, 30.0)
		var rock := _put(arena, NATURE % ("Rock_Medium_%d" % rng.randi_range(1, 3)), c + Vector3(cos(a), 0, sin(a)) * r, rng.randf() * TAU, rng.randf_range(2.4, 3.6))
		if rock: Solid.add_rock(rock)
	# Pilastri di copertura.
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + 0.25
		var pillar := _put(arena, NATURE % ("Rock_Medium_%d" % (i % 3 + 1)), c + Vector3(cos(a), 0, sin(a)) * 13.5, rng.randf() * TAU, 1.5)
		if pillar:
			pillar.scale = Vector3(1.5, 2.8, 1.5)
			Solid.add_rock(pillar)
	# Vasche di veleno, solo da guardare: quelle vere le fa lei.
	for spot in [Vector3(-19, 0, 6), Vector3(17, 0, -13), Vector3(4, 0, 21)]:
		_pool(arena, c + spot)
	_put(arena, DESERT % "SM_Desert_Rib", c + Vector3(-11, 0, -21), 0.6, 1.2)
	_put(arena, DESERT % "SM_Desert_Rib", c + Vector3(-8, 0, -22), 0.6, 1.0)


func _pool(arena: Node3D, at: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.2
	mesh.bottom_radius = 2.2
	mesh.height = 0.06
	mesh.radial_segments = 12
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6dcc3f")
	mat.emission_enabled = true
	mat.emission = Color("3f9c26")
	mat.emission_energy_multiplier = 1.5
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	arena.add_child(node)
	node.global_position = _ground(at) + Vector3.UP * 0.05
	var smoke := CPUParticles3D.new()
	arena.add_child(smoke)
	smoke.global_position = node.global_position
	smoke.amount = 10
	smoke.lifetime = 2.0
	smoke.direction = Vector3.UP
	smoke.spread = 16.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.1
	smoke.gravity = Vector3.ZERO
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.6
	var puff := SphereMesh.new()
	puff.radius = 0.28
	puff.height = 0.56
	puff.radial_segments = 6
	puff.rings = 3
	smoke.mesh = puff
	smoke.color = Color(0.5, 0.82, 0.32)


## Il Cimitero delle Barche: scafi arenati e costole di balena. Si corre fra gli scafi, e lui ci salta sopra.
func _arena_signore() -> void:
	var c: Vector3 = Route.ARENA_SIGNORE
	var arena := Node3D.new()
	arena.name = "CimiteroBarche"
	add_child(arena)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3129
	for i in 9:
		var a: float = TAU * float(i) / 9.0 + rng.randf_range(-0.2, 0.2)
		var r: float = rng.randf_range(20.0, 27.0)
		var boat := _put(arena, "res://art/lake/SM_Lake_Rowboat.glb", c + Vector3(cos(a), 0, sin(a)) * r, rng.randf() * TAU, rng.randf_range(3.2, 5.4), 0.45, Vector3(rng.randf_range(-0.22, 0.22), 0, rng.randf_range(-0.35, 0.35)))
		if boat: _box_for(boat, Vector3(2.0, 1.6, 4.5) * boat.scale.x * 0.5)
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		var side: float = -1.0 if i % 2 else 1.0
		_put(arena, DESERT % "SM_Desert_Rib", c + Vector3(cos(a), 0, sin(a)) * 11.0 + Vector3(0, 0, side), a, rng.randf_range(1.1, 1.7))
	# Mucchi di teschi: la sua collezione.
	for spot in [Vector3(-5, 0, 7), Vector3(9, 0, -3), Vector3(-2, 0, -9)]:
		_skulls(arena, c + spot, rng)


func _box_for(node: Node3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size / node.scale.x
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	body.add_child(shape)
	node.add_child(body)


func _skulls(arena: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color("d0c6a6")
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("1a1714")
	var holder := Node3D.new()
	arena.add_child(holder)
	holder.global_position = _ground(at)
	for i in 14:
		var head := SphereMesh.new()
		head.radius = 0.17
		head.height = 0.34
		head.radial_segments = 7
		head.rings = 4
		head.material = bone
		var node := MeshInstance3D.new()
		node.mesh = head
		holder.add_child(node)
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(0.0, 0.9)
		var y: float = 0.15 + (0.9 - r) * rng.randf_range(0.1, 0.5)
		node.position = Vector3(cos(a) * r, y, sin(a) * r)
		node.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf() * 0.4)
		for side in [-1.0, 1.0]:
			var eye := BoxMesh.new()
			eye.size = Vector3(0.07, 0.06, 0.03)
			eye.material = dark
			var hole := MeshInstance3D.new()
			hole.mesh = eye
			node.add_child(hole)
			hole.position = Vector3(side * 0.065, 0.02, -0.15)


# ------------------------------------------------------------------ deserto: relitti sparsi
func _scatter() -> void:
	var group := Node3D.new()
	group.name = "RelittiDelDeserto"
	add_child(group)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5512
	for i in 34:
		var at := Vector3(rng.randf_range(Route.MIN_X + 300.0, Route.Z2_EAST - 140.0), 0, rng.randf_range(Route.Z2_NORTH + 140.0, Route.WALL_Z - 140.0))
		if Route.road_distance(Vector2(at.x, at.z)) < 22.0 or Route.site_distance(Vector2(at.x, at.z)) < 60.0 or Route.edge_rise(at.x, at.z) > 8.0: continue
		match i % 3:
			0:
				var boat := _put(group, "res://art/lake/SM_Lake_Rowboat.glb", at, rng.randf() * TAU, rng.randf_range(2.6, 5.0), 0.6, Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.4, 0.4)))
				if boat: _box_for(boat, Vector3(2.0, 1.4, 4.5) * boat.scale.x * 0.5)
			1:
				for k in 5:
					_put(group, DESERT % "SM_Desert_Rib", at + Vector3(0, 0, k * 2.4), 0.05 * k, 1.0 + 0.12 * (2 - absi(k - 2)))
			_:
				var wreck := _put(group, KIT % "SM_Borgo_Truck_Wreck", at, rng.randf() * TAU, 1.0, 0.25)
				if wreck: wreck.rotation.x = rng.randf_range(-0.08, 0.08)
