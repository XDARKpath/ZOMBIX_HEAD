extends Node3D
# I valichi: l'unico passaggio nelle montagne fra una zona e l'altra (Route.gates, sulla statale). Chiusi da un posto di blocco
# finché i boss della zona sono vivi. Lo stato si ricava da dati già sincronizzati, così host e client vedono la stessa cosa.

const Route := preload("res://world/campaign/route.gd")
const Terrain := preload("res://world/campaign/terrain.gd")
const Fx := preload("res://bosses/boss_fx.gd")
const KIT := "res://art/zx_borgo/%s.glb"
const WIDTH := 34.0
const HEIGHT := 14.0
const NAMES := [["CAPOMACELLO", "MACELLAIO", "CARCERIERE"], ["IL MAGO", "SIGNORE DELLE TESTE"]]
const HEADER := ["VALICO CHIUSO · OLTRE C'È IL MARE DI SABBIA", "VALICO CHIUSO · OLTRE C'È IL BORGO DEL RIPETITORE"]

var world: Node3D
var nodes: Array[Node3D] = []
var bodies: Array[StaticBody3D] = []
var labels: Array[Label3D] = []
var opened: Array = [false, false]
var _clock := 0.0
var _first := true


func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "ZoneGates"
	var rows: Array = Route.gates()
	for i in rows.size():
		_gate(i, rows[i].at, rows[i].dir)


func _gate(index: int, at: Vector3, dir: Vector3) -> void:
	var gate := Node3D.new()
	gate.name = "Gate%d" % index
	add_child(gate)
	at.y = Terrain.ground_height(at.x, at.z)
	gate.global_position = at
	gate.rotation.y = atan2(-dir.x, -dir.z)
	nodes.append(gate)
	# Un muro che non si scavalca: più alto di ogni salto, largo come tutta la gola.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, HEIGHT, 1.6)
	shape.shape = box
	shape.position.y = HEIGHT * 0.5
	body.add_child(shape)
	gate.add_child(body)
	bodies.append(body)
	# Quello che si vede: camion di traverso, barriere, sacchi di terra.
	for row in [["SM_Borgo_Truck_Wreck", Vector3(0.8, 0, 0.5), 1.45, 1.0], ["SM_Prop_Sign_Danger_01", Vector3(-5.0, 0, 1.8), 0.15, 1.0],
			["SM_Prop_RoadBarrier_Small", Vector3(-3.4, 0, 2.6), 0.1, 1.4], ["SM_Prop_RoadBarrier_Small", Vector3(0.0, 0, 3.0), -0.07, 1.4], ["SM_Prop_RoadBarrier_Small", Vector3(3.4, 0, 2.6), 0.06, 1.4],
			["SM_Prop_Barrel_Metal_01", Vector3(5.4, 0, 1.9), 0.0, 1.0], ["SM_Prop_Barrel_Metal_01", Vector3(6.2, 0, 2.4), 0.5, 1.0]]:
		_prop(gate, row[0], row[1], row[2], row[3])
	# Ai due lati il pendio sale subito: i blocchi di roccia chiudono la fessura sopra i container.
	for x in [-17.0, -13.5, 13.5, 17.0]:
		var rock: Node3D = load("res://art/nature/Rock_Medium_%d.gltf" % (1 + int(absf(x)) % 3)).instantiate()
		gate.add_child(rock)
		rock.position = Vector3(x, 0, 0)
		rock.scale = Vector3.ONE * 3.6
	var label := Label3D.new()
	label.font_size = 42
	label.pixel_size = 0.0085
	label.outline_size = 10
	label.modulate = Color("ffd98a")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = Vector3(0, 6.6, 2.0)
	label.no_depth_test = false
	gate.add_child(label)
	labels.append(label)
	# Da entrambi i lati il cartello dice la stessa cosa, ma dall'altra parte non serve: si arriva da sud.
	refresh()


func _prop(gate: Node3D, id: String, at: Vector3, yaw: float, size: float) -> void:
	var path: String = KIT % id
	if not ResourceLoader.exists(path): return
	var node: Node3D = load(path).instantiate()
	gate.add_child(node)
	node.position = at
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size


## Quali boss della zona sono ancora vivi.
func missing(index: int) -> Array:
	var out: Array = []
	if index == 0:
		var parts: Array = world.expedition.collected
		for i in 3:
			if not parts[i]: out.append(NAMES[0][i])
	elif world.get("zone2"):
		if not world.zone2.dead_matriarca: out.append(NAMES[1][0])
		if not world.zone2.dead_signore: out.append(NAMES[1][1])
	return out


func is_open(index: int) -> bool:
	return opened[index]


func refresh() -> void:
	for i in nodes.size():
		var left := missing(i)
		var open_now: bool = left.is_empty()
		if open_now != opened[i]:
			opened[i] = open_now
			if open_now and not _first: _blow(i)
		bodies[i].collision_layer = 0 if open_now else 1
		nodes[i].visible = not open_now
		if not open_now:
			labels[i].text = Localization.t("{0}\nUCCIDI PRIMA: {1}", [Localization.t(HEADER[i]), " · ".join(left.map(func(n): return Localization.t(n)))])
	_first = false


## Il posto di blocco salta quando l'ultimo boss muore. Si vede e si sente, ovunque tu sia.
func _blow(index: int) -> void:
	var at: Vector3 = nodes[index].global_position
	Fx.play(world, "crack", at + Vector3(0, 0.1, 0), {"r": 6.0, "ember": true, "shake": 0.8, "life": 14.0})
	world.announce(Localization.t("IL VALICO È LIBERO · La strada verso {0} è aperta", [Localization.t("il Mare di Sabbia" if index == 0 else "il Borgo del Ripetitore")]), 8)


func _process(delta: float) -> void:
	if not world or not world.started: return
	_clock -= delta
	if _clock > 0.0: return
	_clock = 0.5
	refresh()
