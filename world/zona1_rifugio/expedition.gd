# Nodo Expedition sotto Rifugio. Missione condivisa: tre scorte, radio, difesa e nuova sortita.
extends Node3D
const POINTS := [Vector3(-3,0,-7),Vector3(12,0,-27),Vector3(-5,0,-44)]
const RADIO := Vector3(-2,0,3)
const HOLD_SECONDS := 45.0
const USE_DISTANCE := 3.0
var world: Node3D
var collected: Array = [false,false,false]
var stage: int = 0
var hold: float = HOLD_SECONDS
var operation: int = 1
var tick: float = 0
var pulse: float = 0
var wave: float = 0
var crates: Array[Node3D] = []
var radio_light: OmniLight3D
var broadcast_count: int = 0

func build(owner_world: Node3D) -> void:
	world = owner_world
	for i in range(3):
		var crate := Node3D.new()
		crate.position = POINTS[i]
		add_child(crate)
		piece(crate,Vector3(0,0.36,0),Vector3(0.9,0.6,0.65),Color("3e5551"))
		piece(crate,Vector3(0,0.69,0),Vector3(0.96,0.09,0.71),Color("b7a071"))
		for x in [-0.29,0.29]: piece(crate,Vector3(x,0.4,0.34),Vector3(0.07,0.6,0.04),Color("222e30"))
		var tag := Label3D.new()
		tag.text = "0%d" % (i+1)
		tag.font_size = 36
		tag.pixel_size = 0.005
		tag.position = Vector3(0,0.4,0.37)
		crate.add_child(tag)
		crates.append(crate)
	var radio := Node3D.new()
	radio.position = RADIO
	add_child(radio)
	piece(radio,Vector3(0,0.45,0),Vector3(1.4,0.8,0.65),Color("35443f"))
	piece(radio,Vector3(0,0.97,0),Vector3(0.65,0.24,0.45),Color("182b2d"))
	piece(radio,Vector3(0.45,1.8,0),Vector3(0.035,2.2,0.035),Color("92998c"))
	for i in range(4): piece(radio,Vector3(-0.18+i*0.12,1,0.24),Vector3(0.055,0.035,0.02),Color("72c9b4"))
	radio_light = OmniLight3D.new()
	radio_light.position = RADIO+Vector3(0,1.3,0)
	radio_light.light_color = Color("80ddc5")
	radio_light.omni_range = 4
	add_child(radio_light)
	visible = false

static func piece(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	view.material_override = material
	view.position = at
	parent.add_child(view)

func start() -> void:
	collected = [false,false,false]
	stage = 0
	hold = HOLD_SECONDS
	operation = 1
	visible = true
	_refresh()

func authority() -> bool:
	return not Session.online or multiplayer.is_server()

func request_use() -> void:
	if authority(): use(multiplayer.get_unique_id())
	else: interact.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func interact() -> void:
	if authority(): use(multiplayer.get_remote_sender_id())

func use(peer: int) -> bool:
	if not authority() or not world.started or not world.actors.has(peer): return false
	var player: CharacterBody3D = world.actors[peer]
	if player.dead: return false
	if stage == 0:
		for i in range(3):
			if not collected[i] and _can_reach(player,POINTS[i]):
				collected[i] = true
				player.health = minf(100,player.health+20)
				player.vitals_changed.emit(player.health,player.stamina)
				if collected.count(true)==3: stage = 1
				_publish()
				_refresh()
				return true
	elif _can_reach(player,RADIO):
		if stage == 1:
			stage = 2
			hold = HOLD_SECONDS
			wave = 0
			_alarm()
		elif stage == 3:
			operation += 1
			stage = 0
			collected = [false,false,false]
			for actor in world.actors.values():
				actor.health = minf(100,actor.health+35)
				actor.vitals_changed.emit(actor.health,actor.stamina)
		else: return false
		_publish()
		_refresh()
		return true
	return false

func _can_reach(player: CharacterBody3D, at: Vector3) -> bool:
	if player.position.distance_to(at)>USE_DISTANCE: return false
	var ray := PhysicsRayQueryParameters3D.create(player.position+Vector3.UP,at+Vector3.UP,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func target_point() -> Vector3:
	if stage != 0: return RADIO
	var result := RADIO
	var distance := INF
	for i in range(3):
		if not collected[i] and world.player.position.distance_squared_to(POINTS[i])<distance:
			distance = world.player.position.distance_squared_to(POINTS[i])
			result = POINTS[i]
	return result

func prompt() -> String:
	if world.player.dead: return ""
	if world.player.position.distance_to(target_point())>USE_DISTANCE: return ""
	return Localization.t(["E  RECUPERA SCORTE  ·  +20 VITA","E  ATTIVA LA RADIO","RESTA VICINO ALLA RADIO","E  NUOVA SPEDIZIONE"][stage])

func title() -> String:
	return Localization.t(["RECUPERA LE SCORTE","RIPRISTINA IL SEGNALE","DIFENDI LA RADIO","SEGNALE TRASMESSO"][stage])

func detail() -> String:
	match stage:
		0: return Localization.t("{0} / 3 casse  ·  esplora il rifugio", [collected.count(true)])
		1: return Localization.t("Ritorna alla radio dell'accampamento")
		2: return Localization.t("{0} s  ·  resta entro 10 metri", [ceili(hold)])
		_: return Localization.t("Squadra rifornita. Preparati a ripartire.")

func _process(delta: float) -> void:
	if not world or not world.started: visible = false; return
	visible = true
	pulse += delta
	radio_light.light_energy = (1.0+sin(pulse*3)*0.3) if stage>0 else 0.1
	if not authority(): return
	if stage == 2:
		var defender: CharacterBody3D = world.nearest_player(RADIO)
		if defender and defender.position.distance_to(RADIO)<10: hold = maxf(0,hold-delta)
		wave -= delta
		if wave <= 0:
			wave = 9
			_alarm()
		if hold <= 0:
			stage = 3
			for actor in world.actors.values():
				actor.health = minf(100,actor.health+35)
				actor.vitals_changed.emit(actor.health,actor.stamina)
			_publish()
	tick += delta
	if tick>=0.25:
		tick = 0
		_publish()

func _alarm() -> void:
	var alive := 0
	for enemy in world.targets:
		if is_instance_valid(enemy) and not enemy.dead:
			alive += 1
			var player: CharacterBody3D = world.nearest_player(enemy.position)
			if player: enemy.hear(player,200)
	if alive<8 and world.targets.size()<24:
		var at := Vector3(-5 if operation%2 else 14,0,-20)
		var enemy: Node3D = world._spawn_enemy(at)
		var player: CharacterBody3D = world.nearest_player(at)
		if player: enemy.hear(player,200)

func _refresh() -> void:
	for i in range(crates.size()): crates[i].visible = not collected[i]

func _publish() -> void:
	if Session.online and multiplayer.is_server():
		for peer in Session.connected_peers(): receive.rpc_id(peer,collected,stage,hold,operation)

@rpc("authority","call_remote","reliable")
func receive(items: Array, step: int, remaining: float, number: int) -> void:
	collected = items
	stage = step
	hold = remaining
	operation = number
	broadcast_count += 1
	_refresh()
