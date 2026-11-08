extends Node
# Popolazione della Zona 1 (solo host): ogni zona ha i suoi tipi di infetti, il suo livello, quanti ne tiene vivi e ogni
# quanto ne arrivano. Vicino al paese si incontrano quelli normali, più ci si allontana più diventano pericolosi.
# Compaiono fuori vista dal giocatore, mai nel recinto; chi resta lontano da tutti sparisce per lasciare posto.

const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
const RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
const NEAR := 22.0
const FAR := 48.0
const DESPAWN := 120.0
const MAX_ALIVE := 34
## nome, centro (x, z), raggio, tipi (0 infetto, 1 corridore, 2 bruto, 3 urlatore, 4 sputatore), livello, massimo vivi, secondi tra un arrivo e l'altro
const ZONES := [
	["IL PRATO", Vector2(6, -78), 34.0, [0], 0, 8, 4.0],
	["BOSCO DI PONENTE", Vector2(-62, -92), 48.0, [0, 0, 0, 1], 0, 8, 4.5],
	["BOSCO DI LEVANTE", Vector2(66, -70), 48.0, [0, 0, 1], 0, 8, 4.5],
	["LA FATTORIA", Vector2(-26, -120), 26.0, [0, 2, 0, 3], 1, 8, 4.0],
	["LA VECCHIA PISTA", Vector2(8, -158), 42.0, [0, 1, 0, 2], 1, 9, 3.5],
	["LA RADURA DEI MORTI", Vector2(6, -212), 30.0, [3, 2, 4, 1], 2, 10, 3.0],
	["LA GOLA", Vector2(108, -96), 30.0, [1, 3, 4, 1], 2, 9, 3.0],
	["LA STRADA DEL BORGO", Vector2(150, -285), 42.0, [0, 1, 0, 3], 1, 8, 3.5],
	# Nel borgo gli infetti e gli sputatori li mette villaggio.gd: qui solo il nome e il pericolo.
	["BORGO CENERE", Vector2(95, -385), 105.0, [0], 2, 0, 9.0],
	["LA PISTA DELLA ROCCA", Vector2(-125, -208), 42.0, [0, 1, 0, 3], 1, 9, 3.5],
	["IL BOSCO DELLA ROCCA", Vector2(-230, -245), 46.0, [2, 3, 4, 1], 2, 9, 3.0],
]
const DANGER := ["TRANQUILLA", "PERICOLOSA", "MOLTO PERICOLOSA"]

var world: Node3D
var clocks := {}
var alive := {}                    # indice zona -> Array di infetti
var rng := RandomNumberGenerator.new()
var _tick := 0.0
var _here := -1


func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "Zone1Spawner"
	rng.randomize()


func reset() -> void:
	alive.clear()
	clocks.clear()
	_here = -1


func _host() -> bool:
	return not Session.online or multiplayer.is_server()


## Zona in cui si trova un punto (la più piccola che lo contiene), -1 fuori da tutte.
static func zone_at(p: Vector2) -> int:
	var best := -1
	var size := INF
	for i in ZONES.size():
		if p.distance_to(ZONES[i][1]) <= ZONES[i][2] and ZONES[i][2] < size:
			best = i
			size = ZONES[i][2]
	return best


func _process(delta: float) -> void:
	if not world or not world.started or world.get_tree().paused: return
	_tick -= delta
	if _tick > 0.0: return
	_tick = 0.5
	_announce_zone()
	if not _host() or world.expedition.zone_index != 0: return
	var players: Array = world.actors.values().filter(func(a): return is_instance_valid(a) and not a.dead and a.global_position.y < 150.0)
	_tidy(players)
	if players.is_empty(): return
	var total := 0
	for key in alive: total += alive[key].size()
	if total >= MAX_ALIVE: return
	for i in ZONES.size():
		var row: Array = ZONES[i]
		var close := false
		for a in players:
			if Vector2(a.global_position.x, a.global_position.z).distance_to(row[1]) < float(row[2]) + FAR: close = true
		if not close: continue
		clocks[i] = float(clocks.get(i, 0.0)) - 0.5
		if clocks[i] > 0.0 or alive.get(i, []).size() >= int(row[5]): continue
		clocks[i] = float(row[6])
		_spawn(i, players)


func _spawn(index: int, players: Array) -> void:
	var row: Array = ZONES[index]
	for attempt in 8:
		var angle := rng.randf() * TAU
		var p: Vector2 = row[1] + Vector2(cos(angle), sin(angle)) * sqrt(rng.randf()) * float(row[2])
		if Layout.near_fence(p.x, p.y) or RoadNet.safe_ring(p) or _near_roadblock(p): continue
		var ok := true
		for a in players:
			var d := Vector2(a.global_position.x, a.global_position.z).distance_to(p)
			if d < NEAR: ok = false
		if not ok: continue
		var at := Vector3(p.x, world.terrain.height(p.x, p.y), p.y)
		var enemy: Node3D = world._spawn_enemy(at)
		var kinds: Array = row[3]
		enemy.set_kind(kinds[rng.randi() % kinds.size()], int(row[4]))
		enemy.home = at
		if not alive.has(index): alive[index] = []
		alive[index].append(enemy)
		return


## Vicino a uno sbarramento ancora chiuso non arrivano rinforzi: per aprirlo l'area va ripulita.
func _near_roadblock(p: Vector2) -> bool:
	for i in world.roadblocks.points.size():
		if world.roadblocks.cleared[i]: continue
		var at: Vector3 = world.roadblocks.points[i]
		if p.distance_to(Vector2(at.x, at.z)) < 70.0: return true
	return false


func _tidy(players: Array) -> void:
	# Chiunque resti dentro il recinto se ne va appena nessuno lo guarda da vicino.
	for enemy in world.targets:
		if is_instance_valid(enemy) and not enemy.dead and Layout.safe(enemy.global_position):
			var close := false
			for a in players:
				if a.global_position.distance_to(enemy.global_position) < 18.0: close = true
			if not close: enemy.queue_free()
	for key in alive.keys():
		var kept: Array = []
		for enemy in alive[key]:
			if not is_instance_valid(enemy) or enemy.dead: continue
			var far := true
			for a in players:
				if a.global_position.distance_to(enemy.global_position) < DESPAWN: far = false
			if far:
				enemy.queue_free()
				continue
			kept.append(enemy)
		alive[key] = kept


## Entrando in una zona nuova, una riga: come si chiama e quanto è pericolosa.
func _announce_zone() -> void:
	var p: CharacterBody3D = world.player
	if not is_instance_valid(p) or p.global_position.y > 150.0: return
	var here := -2 if Layout.safe(p.global_position) else zone_at(Vector2(p.global_position.x, p.global_position.z))
	if here == _here: return
	var was := _here
	_here = here
	if here == -2:
		if was != -1: world.announce(Localization.t("LAGO CENERE · ZONA SICURA · qui gli infetti non ti seguono"), 4)
	elif here >= 0:
		var tier: int = ZONES[here][4]
		world.announce(Localization.t("{0} · ZONA {1}", [Localization.t(ZONES[here][0]), Localization.t(DANGER[tier])]), 4)
