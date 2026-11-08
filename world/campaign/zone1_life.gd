extends Node3D
# Primo traguardo della Zona 1 (docs/ZONA1_LOOP.md), dall'idea "TESTE":
# - Rumore: passi, corsa e armi fanno rumore con raggi diversi; gli infetti entro il
#   raggio ti sentono. Il silenzio (accovacciato, coltello) è una scelta vera.
# - Sacco della morte: morendo lasci a terra metà delle teste che porti. Gli infetti
#   che ci restano sopra lo divorano: corsa contro il tempo per riprenderlo.
# - Cibo: scatolette e funghi da raccogliere, Q per mangiare. Sazio = rigenera vita,
#   più fiato e passi più silenziosi. Niente morte per fame: il tono resta leggero.
# - Pesca: al pontile E lancia, aspetta che abbocchi e premi E al momento giusto.
# Logica locale/host: la cooperativa resta nell'architettura ma non è ancora testata.
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
const Route := preload("res://world/campaign/route.gd")
const RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
const Terrain := preload("res://world/campaign/terrain.gd")
const FISHING_SPOT := preload("res://world/zona1_rifugio/lake.gd").FISHING_SPOT   # piattaforma a T del pontile
const SACK_EAT_SECONDS := 8.0
const FED_SECONDS := 90.0
const WEAPON_NOISE := {"pistol": 45.0, "axe": 11.0, "knife": 5.0, "bow": 3.0}

var world: Node3D
var noise_level := 0.0      # 0..1, letto dall'HUD
var step_clock := 0.0
var fed := 0.0              # secondi di sazietà rimasti
var food := {"can": 0, "mushroom": 0, "fish": 0}
var sacks: Array = []       # {node, label, heads, eaten}
var pickups: Array = []     # {node, kind}
var fishing := ""           # "", "wait", "bite"
var fishing_timer := 0.0
var fishing_from := Vector3.ZERO
var rng := RandomNumberGenerator.new()

func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "Zone1Life"
	rng.seed = 5150
	world.player.died.connect(func(): drop_sack(world.player))
	world.player.melee.impact.connect(func(_t, heavy): emit(world.player, 16.0 if heavy else 12.0, 0.5))
	_spawn_food()

func reset() -> void:
	for sack in sacks: sack["node"].queue_free()
	sacks.clear()
	for item in pickups: item["node"].queue_free()
	pickups.clear()
	food = {"can": 0, "mushroom": 0, "fish": 0}
	fed = 0.0
	fishing = ""
	_spawn_food()

# ---------------------------------------------------------------- rumore
func emit(actor: CharacterBody3D, radius: float, strength: float) -> void:
	if actor == world.player: noise_level = maxf(noise_level, strength)
	if Session.online and not multiplayer.is_server(): return
	for enemy in world.targets:
		if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(actor.global_position) < radius:
			enemy.hear(actor, radius)

func attack_noise(actor: CharacterBody3D) -> void:
	var weapon: String = actor.equipped
	emit(actor, WEAPON_NOISE.get(weapon, 10.0), 1.0 if weapon == "pistol" else 0.45)

func _footsteps(delta: float) -> void:
	var p: CharacterBody3D = world.player
	if p.dead or p.seated or not p.is_on_floor(): return
	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	step_clock -= delta
	if speed < 0.8 or step_clock > 0.0: return
	var quiet := 0.6 if fed > 0.0 else 1.0
	if p.crouching:
		step_clock = 0.8
		noise_level = maxf(noise_level, 0.05)
	elif p.sprinting:
		step_clock = 0.4
		emit(p, 13.0 * quiet, 0.55 * quiet)
	else:
		step_clock = 0.6
		emit(p, 5.5 * quiet, 0.22 * quiet)

# ---------------------------------------------------------------- sacco della morte
func drop_sack(actor: CharacterBody3D) -> void:
	if actor.carried_heads <= 0: return
	var lost := int(ceil(actor.carried_heads * 0.5))
	var lost_items: Dictionary = actor.take_heads(lost)
	var node := Node3D.new()
	add_child(node)
	var at := actor.global_position
	node.global_position = Vector3(at.x, Terrain.ground_height(at.x, at.z) if at.z <= 14 else at.y, at.z)
	var P := preload("res://art/placeholders.gd")
	var bag := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.5
	sphere.radial_segments = 8
	sphere.rings = 4
	bag.mesh = sphere
	bag.position.y = 0.24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6a4a2e")
	mat.roughness = 1.0
	bag.material_override = mat
	node.add_child(bag)
	P.box(node, Vector3(0, 0.52, 0), Vector3(0.10, 0.10, 0.10), Color("3b2a1a"))
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffb35c")
	glow.light_energy = 1.4
	glow.omni_range = 3.5
	glow.position.y = 0.8
	node.add_child(glow)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.pixel_size = 0.006
	label.position.y = 1.2
	label.modulate = Color("ffd591")
	node.add_child(label)
	sacks.append({"node": node, "label": label, "heads": lost, "items": lost_items, "eaten": 0.0})
	world.announce(Localization.t("HAI PERSO {0} TESTE · IL SACCO È RIMASTO DOVE SEI CADUTO", [lost]), 6)

func _sacks(delta: float) -> void:
	for sack in sacks.duplicate():
		var at: Vector3 = sack["node"].global_position
		var eaters := 0
		for enemy in world.targets:
			if not is_instance_valid(enemy) or enemy.dead: continue
			var d: float = enemy.global_position.distance_to(at)
			if d < 2.2: eaters += 1
			# Gli infetti che non inseguono nessuno vanno a frugare nel sacco.
			elif d < 28.0 and int(enemy.state) == 0: enemy.home = at
		sack["eaten"] = float(sack["eaten"]) + delta * eaters
		var left := 1.0 - float(sack["eaten"]) / SACK_EAT_SECONDS
		sack["label"].text = Localization.t("SACCO · {0} TESTE\n{1}%", [sack["heads"], int(left * 100)])
		if left <= 0.0:
			sack["node"].queue_free()
			sacks.erase(sack)
			world.announce(Localization.t("GLI INFETTI HANNO DIVORATO IL SACCO"), 5)

# ---------------------------------------------------------------- cibo
func _spawn_food() -> void:
	var P := preload("res://art/placeholders.gd")
	var spots := 0
	var tries := 0
	while spots < 18 and tries < 400:
		tries += 1
		var x := rng.randf_range(-90, 110)
		var z := rng.randf_range(-200, 4)
		var p := Vector2(x, z)
		if Layout.occupied(x, z) or Route.road_distance(p) < 5.0 or RoadNet.distance(p) < 3.0: continue
		add_pickup(Vector3(x, Terrain.ground_height(x, z), z), "can" if spots % 3 != 2 else "mushroom")
		spots += 1

## Cibo a terra (anche quello che cade dalle casse rotte).
func add_pickup(at: Vector3, kind: String) -> void:
	var P := preload("res://art/placeholders.gd")
	var node := Node3D.new()
	add_child(node)
	node.global_position = at
	if kind == "can":
		P.cylinder(node, Vector3(0, 0.07, 0), 0.05, 0.14, Color("b23a2e"))
		P.cylinder(node, Vector3(0, 0.145, 0), 0.051, 0.012, Color("c9ccc8"))
	else:
		var shroom: Node3D = load("res://art/nature/Mushroom_Common.gltf").instantiate()
		shroom.scale = Vector3.ONE * 0.8
		node.add_child(shroom)
	var hint := OmniLight3D.new()
	hint.light_color = Color("ffe2a8")
	hint.light_energy = 0.5
	hint.omni_range = 1.6
	hint.position.y = 0.4
	node.add_child(hint)
	pickups.append({"node": node, "kind": kind})

func eat() -> void:
	var p: CharacterBody3D = world.player
	if p.dead or p.seated: return
	for kind in ["fish", "can", "mushroom"]:
		if int(food[kind]) <= 0: continue
		food[kind] = int(food[kind]) - 1
		var heal: float = {"fish": 20.0, "can": 15.0, "mushroom": 8.0}[kind]
		p.health = minf(100.0, p.health + heal)
		fed = FED_SECONDS if kind != "mushroom" else maxf(fed, 40.0)
		world.announce(Localization.t({"fish": "PESCE MANGIATO · SAZIO", "can": "SCATOLETTA MANGIATA · SAZIO", "mushroom": "FUNGHI MANGIATI"}[kind]), 3)
		return
	world.announce(Localization.t("NON HAI NIENTE DA MANGIARE"), 3)

# ---------------------------------------------------------------- pesca
func _fishing(delta: float) -> void:
	if fishing.is_empty(): return
	var p: CharacterBody3D = world.player
	if p.dead or p.global_position.distance_to(fishing_from) > 1.2:
		fishing = ""
		world.announce(Localization.t("LENZA RITIRATA"), 2)
		return
	fishing_timer -= delta
	if fishing_timer > 0.0: return
	if fishing == "wait":
		fishing = "bite"
		fishing_timer = 0.9
		emit(p, 3.0, 0.1)
	else:
		fishing = ""
		world.announce(Localization.t("È SCAPPATO"), 2)

# ---------------------------------------------------------------- interazioni
func context() -> String:
	var p: CharacterBody3D = world.player
	if fishing == "wait": return Localization.t("LA LENZA È IN ACQUA…")
	if fishing == "bite": return Localization.t("E  TIRA!")
	for sack in sacks:
		if p.global_position.distance_to(sack["node"].global_position) < 2.4:
			return Localization.t("E  RECUPERA IL SACCO ({0} TESTE)", [sack["heads"]])
	for item in pickups:
		if p.global_position.distance_to(item["node"].global_position) < 2.0:
			return Localization.t("E  RACCOGLI " + ("SCATOLETTA" if item["kind"] == "can" else "FUNGHI"))
	if world.get("zone_kit"):
		var chest: String = world.zone_kit.chest_context(p)
		if not chest.is_empty(): return chest
	if _at_dock(p): return Localization.t("E  PESCA")
	return ""

func request() -> bool:
	var p: CharacterBody3D = world.player
	if p.dead or p.seated: return false
	if fishing == "bite":
		fishing = ""
		food["fish"] = int(food["fish"]) + 1
		world.announce(Localization.t("PESCE PRESO · H PER MANGIARE"), 3)
		return true
	if fishing == "wait": return true
	for sack in sacks.duplicate():
		if p.global_position.distance_to(sack["node"].global_position) < 2.4:
			for id in sack.get("items", {"item_testa": int(sack["heads"])}):
				p.add_item(id, int(sack["items"][id]) if sack.has("items") else int(sack["heads"]))
			sack["node"].queue_free()
			sacks.erase(sack)
			world.survival._publish()
			world.announce(Localization.t("SACCO RECUPERATO · +{0} TESTE", [sack["heads"]]), 4)
			return true
	for item in pickups.duplicate():
		if p.global_position.distance_to(item["node"].global_position) < 2.0:
			food[item["kind"]] = int(food[item["kind"]]) + 1
			item["node"].queue_free()
			pickups.erase(item)
			return true
	if world.get("zone_kit") and world.zone_kit.open_chest(p): return true
	if _at_dock(p):
		fishing = "wait"
		fishing_timer = rng.randf_range(2.5, 6.0)
		fishing_from = p.global_position
		return true
	return false

func _at_dock(p: CharacterBody3D) -> bool:
	return Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(FISHING_SPOT.x, FISHING_SPOT.z)) < 3.0

func _unhandled_input(event: InputEvent) -> void:
	if not world.started or world.ui_open: return
	if event.is_action_pressed("heal"):   # H: mangia (la Q ora lancia)
		eat()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not world or not world.started: return
	noise_level = move_toward(noise_level, 0.0, delta * 0.8)
	_footsteps(delta)
	_sacks(delta)
	_fishing(delta)
	if fed > 0.0:
		fed = maxf(0.0, fed - delta)
		var p: CharacterBody3D = world.player
		if not p.dead:
			p.health = minf(100.0, p.health + 0.6 * delta)
			p.stamina = minf(100.0, p.stamina + 4.0 * delta)

func food_count() -> int:
	return int(food["can"]) + int(food["mushroom"]) + int(food["fish"])
