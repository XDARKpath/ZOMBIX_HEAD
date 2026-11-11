# CRIPTA DEL CARCERIERE: dungeon costruito con il kit originale (art/zx_dungeon/dungeon_modules.glb, tools/castle_kit).
# Percorso: Ingresso -> Labirinto (generato, seme fisso) -> Segrete (le celle si aprono, 2 ondate)
#        -> Cisterna (sputatori sulle piattaforme) -> Anticamera -> Sala dei secondini (saracinesca) -> Sala del tesoro.
# Uso: world.add_child(dungeon); dungeon.build(world). In ZOMBIX HEAD è il piano più basso della Rocca
# (world/rocca/rocca.gd): si scende dalla botola in fondo al corridoio delle lame e si risale lì. Ripulita la sala
# dei secondini, la Rocca alza la saracinesca dell'arena dove aspetta il Carceriere.
# L'host comanda incontri, porte e bottino; i client ricevono lo stato via RPC. Griglia: celle da 4 m, nord = -Z.
extends Node3D

const MODULES := preload("res://art/zx_dungeon/dungeon_modules.glb")
const Spit := preload("res://enemies/spit_projectile.gd")
const ORIGIN := Vector3(-700, 260, -1800)      # sospeso nel vuoto, lontano da tutto (fase3 rispawna sotto y = -1)
const HATCH := Vector3(12, 0, 9)               # botola vicino al rifugio (y presa dal terreno)
const CELL := 4.0
const SEED := 1337
const N := Vector2i(0, -1)
const S := Vector2i(0, 1)
const E := Vector2i(1, 0)
const W := Vector2i(-1, 0)

# id, nome mostrato, rettangolo di celle (x, z, larghezza, profondità), tipo
const ROOMS := [
	["ingresso", "INGRESSO DELLA CRIPTA", Rect2i(0, 0, 4, 3), "room"],
	["c1", "", Rect2i(1, -3, 1, 3), "corridor"],
	["labirinto", "IL LABIRINTO", Rect2i(-5, -15, 12, 12), "maze"],
	["c2", "", Rect2i(4, -18, 1, 3), "corridor"],
	["prigioni", "LE SEGRETE", Rect2i(0, -26, 8, 8), "room"],
	["c3", "", Rect2i(4, -29, 1, 3), "corridor"],
	["cisterna", "LA CISTERNA DEGLI SPUTATORI", Rect2i(-2, -36, 13, 7), "room"],
	["c4", "", Rect2i(4, -37, 1, 1), "corridor"],
	["anticamera", "ANTICAMERA", Rect2i(4, -41, 2, 4), "room"],
	["arena", "SALA DEI SECONDINI", Rect2i(2, -47, 6, 6), "big"],
	["tesoro", "SALA DEL TESORO", Rect2i(4, -51, 2, 4), "room"],
	["risalita", "RISALITA", Rect2i(8, -45, 1, 2), "room"],      # dietro la porta est dell'arena
]
const BOSS_DOOR_Z := -178.0          # porta est dell'arena (centro del Big tile centrale, lato est x = 30)
const BOSS_DOOR_X := 30.0
# porte tra aree: cella A, direzione verso B, tipo (passage / gate:<nome> / big / big_gate:<nome>)
const DOORS := [
	[Vector2i(1, 0), N, "passage"], [Vector2i(1, -3), N, "passage"], [Vector2i(4, -15), N, "passage"],
	[Vector2i(4, -18), N, "passage"], [Vector2i(4, -26), N, "gate:prigioni"], [Vector2i(4, -29), N, "passage"],
	[Vector2i(4, -36), N, "gate:cisterna"], [Vector2i(4, -37), N, "passage"],
	[Vector2i(4, -41), N, "big_gate:arena"], [Vector2i(4, -47), N, "big_gate:tesoro"],
]
const JAIL_ROWS := [-25, -24, -23, -22, -21, -20]
const PLATFORMS := [Vector2i(-2, -36), Vector2i(-1, -36), Vector2i(9, -36), Vector2i(10, -36), Vector2i(-2, -33), Vector2i(10, -33)]
const STAIR_TOP := 2.5                            # quota della piattaforma in cima a StairsLow
const RAMPS := [Vector2i(-1, -35), Vector2i(9, -35), Vector2i(-2, -32), Vector2i(10, -32)]   # StairsLow, sale verso nord
const RAMP_FOR_SIDE := {Vector2i(-2, -32): Vector2i(-2, -33), Vector2i(10, -32): Vector2i(10, -33)}

var world: Node3D
var lib := {}
var cells := {}                 # Vector2i -> area id
var links := {}                 # "a|b" -> true (passaggio aperto tra due celle)
var door_edges := {}            # "a|b" -> tipo
var gates := {}                 # nome -> {node, open, y0}
var jail_bars: Array[Node3D] = []
var chests := []                # [{pos, node, lid, looted, amount}]
var exits := []                 # posizioni da cui si torna in superficie
var rooms := {}                 # id -> {rect, state, enemies, wave}
var torches: Array[OmniLight3D] = []
var nav: NavigationRegion3D
var env: Environment
var hatch_pos: Vector3
var boss: Node3D
var boss_phase := 0
var boss_empty_time := 0.0
var _poll := 0.0
var _suns: Array[Node] = []
var _inside := false
var _ui: CanvasLayer
var _bar: ProgressBar
var _bar_label: Label
var _host := true
var _pending_gates := []
var _pending_jails := []
var exit_locks := {}           # indice uscita -> nome cancello che deve essere aperto
var _boss_door: Array[Node3D] = []
var _exit_label: Label3D
var _door_light: OmniLight3D
var rocca: Node3D                 # world/rocca/rocca.gd: da lì si scende e lì si risale


func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "Dungeon"
	position = ORIGIN
	_host = not Session.online or multiplayer.is_server()
	var src: Node3D = MODULES.instantiate()
	for n in src.get_children():
		lib[String(n.name)] = n
	_layout()
	_geometry()
	_props()
	_lights()
	_environment()
	_boss_ui()
	if _host:
		_bake_navigation()
	_late_parts()


# ------------------------------------------------------------------ layout
func _layout() -> void:
	for r in ROOMS:
		var rect: Rect2i = r[2]
		rooms[r[0]] = {"name": r[1], "rect": rect, "kind": r[3], "state": "idle", "enemies": [], "wave": 0}
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				cells[Vector2i(x, z)] = r[0]
	# jail cells are their own small areas
	for row in JAIL_ROWS:
		for x in [0, 7]:
			cells[Vector2i(x, row)] = "cella_%d_%d" % [x, row]
	# open links inside every room / corridor (not maze)
	for c in cells:
		for d in [E, S]:
			var o: Vector2i = c + d
			if cells.has(o) and cells[o] == cells[c] and rooms.get(cells[c], {}).get("kind", "") != "maze":
				links[_key(c, o)] = true
	_maze(rooms["labirinto"].rect)
	for d in DOORS:
		var a: Vector2i = d[0]
		var b: Vector2i = a + d[1]
		links[_key(a, b)] = true
		door_edges[_key(a, b)] = d[2]
		if String(d[2]).begins_with("big"):
			links[_key(a + E, b + E)] = true
			door_edges[_key(a + E, b + E)] = "skip"
	for row in JAIL_ROWS:
		links[_key(Vector2i(0, row), Vector2i(1, row))] = true
		door_edges[_key(Vector2i(0, row), Vector2i(1, row))] = "jail"
		links[_key(Vector2i(7, row), Vector2i(6, row))] = true
		door_edges[_key(Vector2i(7, row), Vector2i(6, row))] = "jail"


func _maze(rect: Rect2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var start := Vector2i(1, rect.end.y - 1)
	var seen := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var c: Vector2i = stack[-1]
		var options := []
		for d in [N, S, E, W]:
			var o: Vector2i = c + d
			if rect.has_point(o) and not seen.has(o):
				options.append(o)
		if options.is_empty():
			stack.pop_back()
			continue
		var o: Vector2i = options[rng.randi() % options.size()]
		links[_key(c, o)] = true
		seen[o] = true
		stack.append(o)
	# a few loops so it is not a pure tree (more routes, better fights)
	for i in 22:
		var c := Vector2i(rng.randi_range(rect.position.x, rect.end.x - 2), rng.randi_range(rect.position.y, rect.end.y - 2))
		links[_key(c, c + (E if rng.randf() < .5 else S))] = true


func _key(a: Vector2i, b: Vector2i) -> String:
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var t := a; a = b; b = t
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]


func cell_pos(c: Vector2i, y := 0.0) -> Vector3:
	return Vector3(c.x * CELL, y, c.y * CELL)


func world_pos(c: Vector2i, y := 0.0) -> Vector3:
	return global_transform * cell_pos(c, y)


func _rot(d: Vector2i) -> float:
	if d == N: return 0.0
	if d == W: return PI / 2
	if d == S: return PI
	return -PI / 2


# ------------------------------------------------------------------ geometry
func _place(key: String, pos: Vector3, rot := 0.0, parent: Node = self) -> Node3D:
	var t: Node3D = lib.get(key, lib.get("M_" + key))
	if t == null:
		push_warning("dungeon: modulo mancante " + key)
		return null
	var n := t.duplicate() as Node3D
	n.position = pos
	n.rotation = Vector3(0, rot, 0)
	parent.add_child(n)
	return n


## Rampa invisibile appoggiata sugli spigoli dei gradini di StairsLow (8 gradini da 0,31 m tra +1,7 e -1,4 dal centro della cella): i gradini da 0,3 m fermavano il giocatore.
func _stair_ramp(a: Vector3, b: Vector3, width := 3.6, thick := 0.16) -> void:
	var sb := StaticBody3D.new()
	sb.name = "RampaScala"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var dir := b - a
	box.size = Vector3(width, thick, dir.length() + 0.1)
	cs.shape = box
	sb.add_child(cs)
	add_child(sb)
	var up := Vector3.UP.cross(dir).cross(dir).normalized() * -1.0
	sb.transform = Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5 - up * thick * 0.5)


## Sopra piattaforme e rampe della cisterna la volta (4 m) taglia la testa di chi sta a 2,5 m: lì la volta resta solo da vedere.
var _roofless: ConcavePolygonShape3D
func _open_roof(n: Node3D) -> void:
	for cs in n.find_children("*", "CollisionShape3D", true, false):
		if not (cs.shape is ConcavePolygonShape3D): continue
		if _roofless == null:
			var faces: PackedVector3Array = cs.shape.get_faces()
			var keep := PackedVector3Array()
			for i in range(0, faces.size(), 3):
				if maxf(faces[i].y, maxf(faces[i + 1].y, faces[i + 2].y)) < 3.0:
					keep.append_array([faces[i], faces[i + 1], faces[i + 2]])
			_roofless = ConcavePolygonShape3D.new()
			_roofless.set_faces(keep)
		cs.shape = _roofless


func _is_big(c: Vector2i) -> bool:
	return cells.get(c, "") == "arena"


func _geometry() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	var walls := ["Wall1", "Wall1", "Wall2", "Wall3", "Wall1", "WallWindow"]
	var posts := {}
	for c in cells:
		if _is_big(c):
			continue
		var area: String = cells[c]
		var kind: String = rooms.get(area, {}).get("kind", "room")
		# floor / ceiling piece
		var open_ns := links.has(_key(c, c + N)) or links.has(_key(c, c + S))
		var open_ew := links.has(_key(c, c + E)) or links.has(_key(c, c + W))
		if kind == "corridor" or kind == "maze":
			var straight_ns := open_ns and not open_ew
			var straight_ew := open_ew and not open_ns
			if straight_ns:
				_place("Straight", cell_pos(c), 0.0)
			elif straight_ew:
				_place("Straight", cell_pos(c), PI / 2)
			else:
				_place("Crossing", cell_pos(c), 0.0)
		else:
			var center := _place("CustomCenter", cell_pos(c))
			if center and (c in PLATFORMS or c in RAMPS):
				_open_roof(center)
		# edges
		for d in [N, S, E, W]:
			var o: Vector2i = c + d
			var k := _key(c, o)
			var edge_mid := cell_pos(c) + Vector3(d.x, 0, d.y) * CELL * 0.5
			if door_edges.has(k):
				if ((d == N or d == E) and not _is_big(o)) or _is_big(o):   # each door once (from the non-arena side)
					_door(door_edges[k], c, d, edge_mid)
				continue
			if links.has(k) and cells.has(o):
				continue
			if _is_big(o):
				continue                                          # the arena builds its own walls
			if cells.has(o) and (d == S or d == W):
				continue                                          # shared wall, built from the other cell
			_place(walls[rng.randi() % walls.size()], cell_pos(c), _rot(d))
			# posts at both ends of the wall
			var side := Vector2i(d.y, d.x)
			for s in [-1, 1]:
				var p: Vector3 = edge_mid + Vector3(side.x, 0, side.y) * CELL * 0.5 * s
				posts[Vector2i(roundi(p.x * 10), roundi(p.z * 10))] = p
	for p in posts.values():
		_place("Pillar", p)
	_arena()
	for c in PLATFORMS:
		_place("StairsPlatform", cell_pos(c))
	for c in RAMPS:
		_place("StairsLow", cell_pos(c))
		_stair_ramp(cell_pos(c) + Vector3(0, 0, 2.5), cell_pos(c) + Vector3(0, STAIR_TOP + 0.03, -1.5))


func _door(kind: String, c: Vector2i, d: Vector2i, mid: Vector3) -> void:
	var along := 0.0 if (d == N or d == S) else PI / 2
	if kind == "skip":
		return
	if kind == "passage":
		_place("Passage", mid, along)
	elif kind.begins_with("gate:"):
		_place("PassageWood", mid, along)
		_pending_gates.append([kind.substr(5), "PortcullisWood", mid + Vector3(0, 0, 0.32), false])
	elif kind.begins_with("big_gate:"):
		var m := mid + Vector3(CELL * 0.5, 0, 0)
		_place("BigPassage", m, 0.0)
		var gname := kind.substr(9)
		_pending_gates.append([gname, "Portcullis", m + Vector3(0, 0, 0.34 if gname == "arena" else -0.34), gname == "arena"])
	elif kind == "jail":
		_pending_jails.append([mid, PI / 2])


func _late_parts() -> void:
	# movable parts are added after the navmesh parse so open gates do not leave holes in it
	for g in _pending_gates:
		_gate(g[0], g[1], g[2], g[3])
	for j in _pending_jails:
		var bars := _place("JailGate", j[0], j[1])
		if bars:
			jail_bars.append(bars)
	var door_pos := cell_pos(Vector2i(1, 2)) + Vector3(2, 0, 1.8)
	_place("DoorIronL", door_pos, PI)
	_place("DoorIronR", door_pos, PI)
	_make_boss_door()
	var tz: Rect2i = rooms["tesoro"].rect
	var door2 := cell_pos(Vector2i(4, tz.position.y)) + Vector3(2, 0, -1.8)
	_place("DoorIronL", door2, 0.0)
	_place("DoorIronR", door2, 0.0)


## Porta a due battenti nella parete est dell'arena: si spalanca quando il Carceriere muore
## e porta alla scala di risalita verso la superficie.
func _make_boss_door() -> void:
	for side in [["DoorIronL", -1.0], ["DoorIronR", 1.0]]:
		var pivot := Node3D.new()
		pivot.position = Vector3(BOSS_DOOR_X + 0.12, 0, BOSS_DOOR_Z + side[1] * 1.336)
		pivot.rotation.y = -PI / 2
		add_child(pivot)
		var leaf := _place(side[0], Vector3.ZERO, 0.0, pivot)
		if leaf:
			_boss_door.append(pivot)
	gates["uscita"] = {"node": null, "open": false, "y0": 0.0}
	# scala verso l'alto e luce fredda "dall'esterno"
	_place("StairsLow", cell_pos(Vector2i(8, -45)) + Vector3(0.6, 0, 2), -PI / 2)   # sale verso est, verso la luce
	var up_at := cell_pos(Vector2i(8, -45)) + Vector3(0.6, 0, 2)
	_stair_ramp(up_at + Vector3(-2.5, 0, 0), up_at + Vector3(1.5, STAIR_TOP + 0.03, 0))
	_door_light = OmniLight3D.new()
	_door_light.position = Vector3(BOSS_DOOR_X + 2.5, 3.4, BOSS_DOOR_Z)
	_door_light.light_color = Color("cfe3ff")
	_door_light.omni_range = 11.0
	_door_light.light_energy = 0.0
	add_child(_door_light)
	exits.append(Vector3(BOSS_DOOR_X + 0.9, 0, BOSS_DOOR_Z))
	exit_locks[exits.size() - 1] = "uscita"
	_exit_label = Label3D.new()
	_exit_label.text = Localization.t("RISALITA · [E] torna nella Rocca")
	_exit_label.font_size = 40; _exit_label.pixel_size = 0.004; _exit_label.outline_size = 10
	_exit_label.modulate = Color("cfe3ff")
	_exit_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_exit_label.position = Vector3(BOSS_DOOR_X + 1.3, 2.7, BOSS_DOOR_Z)
	_exit_label.visible = false
	add_child(_exit_label)


func _gate(gname: String, key: String, pos: Vector3, start_open: bool) -> void:
	var node := _place(key, pos, 0.0)
	if node == null:
		return
	gates[gname] = {"node": node, "open": start_open, "y0": pos.y}
	if start_open:
		node.position.y = pos.y + 3.7


func set_gate(gname: String, open: bool) -> void:
	if not gates.has(gname) or gates[gname].open == open:
		return
	gates[gname].open = open
	if gname == "uscita":
		var tw2 := create_tween().set_parallel(true)
		for i in _boss_door.size():
			var sgn := 1.0 if i == 0 else -1.0
			tw2.tween_property(_boss_door[i], "rotation:y", -PI / 2 + (sgn * 1.75 if open else 0.0), 1.8 if open else 0.4) \
				.set_trans(Tween.TRANS_BACK if open else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.tween_property(_door_light, "light_energy", 2.2 if open else 0.0, 1.5)
		_exit_label.visible = open
		if _host:
			_push_state()
		return
	var g: Node3D = gates[gname].node
	var tw := create_tween()
	tw.tween_property(g, "position:y", gates[gname].y0 + (3.7 if open else 0.0), 1.6 if open else 0.45) \
		.set_trans(Tween.TRANS_SINE if open else Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT if open else Tween.EASE_IN)
	if _host:
		_push_state()


func _arena() -> void:
	var r: Rect2i = rooms["arena"].rect
	for bx in range(r.position.x, r.end.x, 2):
		for bz in range(r.position.y, r.end.y, 2):
			var center := cell_pos(Vector2i(bx, bz)) + Vector3(CELL * 0.5, 0, CELL * 0.5)
			_place("Big", center)
			for d in [N, S, E, W]:
				var inside := r.has_point(Vector2i(bx + (2 if d == E else (-1 if d == W else 0)), bz + (2 if d == S else (-1 if d == N else 0))))
				if inside:
					continue
				var is_door: bool = bx == 4 and ((d == S and bz == r.end.y - 2) or (d == N and bz == r.position.y))
				if is_door:
					continue                                       # BigPassage built by the door
				if d == E and bz == r.position.y + 2:
					_place("BigPassage", Vector3(BOSS_DOOR_X, 0, BOSS_DOOR_Z), PI / 2)   # porta di risalita
					continue
				_place("BigWall", center, _rot(d))


# ------------------------------------------------------------------ props & lights
func _props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 21
	var solid := ["BarrelBig", "BarrelClosed", "BarrelOpen", "TableBig", "TableSmall", "Bench", "Chest", "WeaponRackBig",
		"WeaponRackSmall", "Shelf", "Throne", "Cauldron", "Desk", "Fireplace", "AmphoraStand", "FirewoodStack", "Oven"]
	var put := func(key: String, c: Vector2i, off := Vector3.ZERO, rot := 0.0) -> Node3D:
		var n := _place("P_" + key, cell_pos(c) + off, rot)
		if n and key in solid:
			_box_collider(n)
		return n
	# ingresso
	put.call("CarpetRed", Vector2i(1, 1), Vector3(2, 0.02, 0), PI / 2)
	put.call("WeaponRackBig", Vector2i(0, 0), Vector3(-1.2, 0, -1.4))
	put.call("BarrelClosed", Vector2i(3, 0), Vector3(1.2, 0, -1.3))
	put.call("BarrelOpen", Vector2i(3, 0), Vector3(0.2, 0, -1.5))
	put.call("Bench", Vector2i(0, 2), Vector3(-1.4, 0, 0), PI / 2)
	put.call("Chest", Vector2i(3, 2), Vector3(1.2, 0, 1.2), PI)
	exits.append(cell_pos(Vector2i(1, 2)) + Vector3(2, 0, 1.6))
	_label("SCALA DELLA ROCCA · [E] risali", exits[0] + Vector3(0, 2.6, 0.2))
	# labirinto: ossa, teschi e tre forzieri nei vicoli ciechi
	var maze: Rect2i = rooms["labirinto"].rect
	var dead_ends := []
	for x in range(maze.position.x, maze.end.x):
		for z in range(maze.position.y, maze.end.y):
			var c := Vector2i(x, z)
			var exits_n := 0
			for d in [N, S, E, W]:
				if links.has(_key(c, c + d)):
					exits_n += 1
			if exits_n == 1:
				dead_ends.append(c)
			if rng.randf() < .18:
				put.call("Skull" if rng.randf() < .5 else "Bone", c, Vector3(rng.randf_range(-1.3, 1.3), 0.02, rng.randf_range(-1.3, 1.3)), rng.randf() * TAU)
	dead_ends.shuffle()
	for i in mini(4, dead_ends.size()):
		_chest(dead_ends[i], 60)
	# prigioni
	put.call("TableBig", Vector2i(3, -23), Vector3(2, 0, 0), PI / 2)
	put.call("Bench", Vector2i(2, -23), Vector3(2, 0, 0), PI / 2)
	put.call("Bench", Vector2i(5, -23), Vector3(-0.5, 0, 0), PI / 2)
	for row in JAIL_ROWS:
		for x in [0, 7]:
			put.call("Bone", Vector2i(x, row), Vector3(rng.randf_range(-.8, .8), 0.02, rng.randf_range(-.8, .8)), rng.randf() * TAU)
			if rng.randf() < .4:
				put.call("Bucket", Vector2i(x, row), Vector3(.9 if x == 0 else -.9, 0, -1.2))
	_place("P_Chandelier", cell_pos(Vector2i(4, -23)) + Vector3(-2, 4.3, 0))
	# cisterna: copertura tra le piattaforme degli sputatori
	for c in [Vector2i(1, -34), Vector2i(3, -32), Vector2i(6, -34), Vector2i(8, -31), Vector2i(2, -31), Vector2i(7, -33), Vector2i(4, -34)]:
		put.call(["BarrelBig", "TableBig", "BarrelClosed", "Cauldron", "AmphoraStand"][rng.randi() % 5], c, Vector3(rng.randf_range(-.6, .6), 0, rng.randf_range(-.6, .6)), rng.randf() * TAU)
	for c in PLATFORMS:
		put.call("BarrelClosed", c, Vector3(1.2, 2.51, -1.2))
	# anticamera: armeria e due forzieri che curano
	put.call("WeaponRackBig", Vector2i(4, -40), Vector3(-1.4, 0, 0), PI / 2)
	put.call("WeaponRackSmall", Vector2i(5, -40), Vector3(1.4, 0, 0), -PI / 2)
	put.call("Shield", Vector2i(4, -39), Vector3(-1.75, 1.7, 0), PI / 2)
	put.call("Spear", Vector2i(5, -39), Vector3(1.7, 0, 0.3), 0)
	_chest(Vector2i(4, -38), 0, true)
	_chest(Vector2i(5, -38), 0, true)
	# arena
	var ar: Rect2i = rooms["arena"].rect
	var top := cell_pos(Vector2i(4, ar.position.y)) + Vector3(CELL * 0.5, 0, -1.2)
	_place("P_Throne", top, 0.0)
	_place("P_CarpetRed", top + Vector3(0, 0.02, 8), PI / 2)
	_place("P_CarpetRed", top + Vector3(0, 0.02, 12.3), PI / 2)
	# torce sulle pareti laterali (niente lampadari: il Carceriere è alto più di 3 m)
	for z in range(ar.position.y, ar.end.y):
		for side in [[ar.position.x, W], [ar.end.x - 1, E]]:
			var d: Vector2i = side[1]
			var mount := cell_pos(Vector2i(side[0], z)) + Vector3(d.x, 0, d.y) * 1.8 + Vector3(0, 2.3, 0)
			_place("P_TorchWall", mount, _rot(d))
			if z % 2 == 0:
				_torch_light(mount - Vector3(d.x, 0, d.y) * 0.45 + Vector3(0, 0.35, 0), 9.0, 1.5)
	for p in [Vector3(-3, 0, 2), Vector3(3, 0, 2), Vector3(-6, 0, 6), Vector3(6, 0, 6)]:
		_place("P_CandleTriple", top + p)
	for i in 10:
		_place("P_Skull" if i % 2 else "P_Bone", top + Vector3(rng.randf_range(-9, 9), 0.02, rng.randf_range(3, 20)), rng.randf() * TAU)
	# tesoro
	var tz: Rect2i = rooms["tesoro"].rect
	for i in 3:
		_chest(Vector2i(4 + (i % 2), tz.position.y + i), 150)
	exits.append(cell_pos(Vector2i(4, tz.position.y)) + Vector3(2, 0, -1.4))
	_label("SCALA DELLA ROCCA · [E] risali", exits[1] + Vector3(0, 2.6, 0.2))


func _chest(c: Vector2i, amount: int, heal := false) -> void:
	var pos := cell_pos(c) + Vector3(0, 0, -1.2)
	var body := _place("P_Chest", pos, PI)
	var lid := _place("P_ChestLid", pos, PI)
	if body:
		_box_collider(body)
	chests.append({"pos": pos, "node": body, "lid": lid, "looted": false, "amount": amount, "heal": heal})


func _box_collider(n: Node3D) -> void:
	var aabb := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var a: AABB = (mi as MeshInstance3D).get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	if first or aabb.size.length() < 0.3:
		return
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size
	cs.shape = box
	cs.position = aabb.get_center()
	sb.add_child(cs)
	n.add_child(sb)


func _label(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.004
	l.outline_size = 10
	l.modulate = Color("ffd27a")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)


func _lights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var count := 0
	for c in cells:
		if _is_big(c) or c in PLATFORMS:
			continue
		var area: String = cells[c]
		if area.begins_with("cella"):
			continue
		var every := 5 if rooms.get(area, {}).get("kind", "") == "maze" else 3
		for d in [N, W, E, S]:
			var o: Vector2i = c + d
			if links.has(_key(c, o)) or door_edges.has(_key(c, o)) or _is_big(o) or (cells.has(o) and cells[o] == area and rooms.get(area, {}).get("kind", "") != "maze"):
				continue
			count += 1
			if count % every != 0:
				continue
			var r := _rot(d)
			var mount := cell_pos(c) + (Vector3(d.x, 0, d.y) * 1.8) + Vector3(0, 2.3, 0)
			_place("P_TorchWall", mount, r)
			_torch_light(mount - Vector3(d.x, 0, d.y) * 0.45 + Vector3(0, 0.35, 0), 6.5)
			break
	# arena & big rooms: chandeliers glow brighter
	var ar: Rect2i = rooms["arena"].rect
	for i in 3:
		_torch_light(cell_pos(Vector2i(2 + i * 2, ar.position.y + 3)) + Vector3(CELL * 0.5, 3.6, 0), 14.0, 2.2)
	for p in [Vector2i(2, -44), Vector2i(7, -44), Vector2i(4, -42)]:
		_torch_light(cell_pos(p) + Vector3(0, 3.2, 0), 9.0, 1.4)
	_torch_light(cell_pos(Vector2i(4, -23)) + Vector3(-2, 2.8, 0), 12.0, 1.8)
	# prigioni: un secondo lampadario a sud, bracieri al centro della cisterna
	_place("P_Chandelier", cell_pos(Vector2i(4, -20)) + Vector3(-2, 4.3, 0))
	_torch_light(cell_pos(Vector2i(4, -20)) + Vector3(-2, 2.8, 0), 11.0, 1.6)
	for c in [Vector2i(1, -33), Vector2i(4, -33), Vector2i(7, -33)]:
		_place("P_Chandelier", cell_pos(c) + Vector3(0, 4.3, 0))
		_torch_light(cell_pos(c) + Vector3(0, 2.9, 0), 11.0, 1.5, Color("ffb35a"))
	for c in PLATFORMS:
		_torch_light(cell_pos(c) + Vector3(0, 4.0, 0), 7.0, 1.0, Color("7dff9a"))


func _torch_light(pos: Vector3, rng_m: float, energy := 1.35, color := Color("ffa245")) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.omni_range = rng_m
	l.light_energy = energy
	l.light_color = color
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 40.0
	l.distance_fade_length = 10.0
	l.set_meta("base", energy)
	add_child(l)
	torches.append(l)


func _surface_hatch() -> void:
	var y: float = world.terrain.height(HATCH.x, HATCH.z) if world.get("terrain") else 0.0
	hatch_pos = Vector3(HATCH.x, y, HATCH.z)
	var h := Node3D.new()
	h.name = "BotolaCripta"
	world.add_child(h)
	h.global_position = hatch_pos
	var floor_t: Node3D = lib["M_FloorTile"].duplicate()
	h.add_child(floor_t)
	floor_t.position = Vector3(0, 0.12, 0)
	var door: Node3D = lib["M_DoorIronL"].duplicate()
	h.add_child(door)
	door.rotation = Vector3(-PI / 2, 0, 0)
	door.position = Vector3(-0.67, 0.16, 1.05)
	for x in [-1.8, 1.8]:
		var t: Node3D = lib["P_Torch"].duplicate()
		h.add_child(t)
		t.position = Vector3(x, 0, -1.8)
		var l := OmniLight3D.new(); l.position = Vector3(x, 1.0, -1.8); l.omni_range = 6; l.light_color = Color("ffa245"); h.add_child(l)
	var l3 := Label3D.new()
	l3.text = Localization.t("CRIPTA DEL CARCERIERE\n[E] scendi")
	l3.font_size = 48; l3.pixel_size = 0.005; l3.outline_size = 12; l3.modulate = Color("ffcf4a")
	l3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l3.position = Vector3(0, 2.2, 0)
	h.add_child(l3)


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.018, 0.016)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.29, 0.25)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.09, 0.07, 0.06)
	env.fog_density = 0.018
	env.glow_enabled = true
	env.glow_intensity = 0.6


func _boss_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-310, 28)
	box.custom_minimum_size = Vector2(620, 0)
	_ui.add_child(box)
	_bar_label = Label.new()
	_bar_label.text = Localization.t("IL CARCERIERE")
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_label.add_theme_font_size_override("font_size", 26)
	_bar_label.add_theme_color_override("font_color", Color("e8c27a"))
	box.add_child(_bar_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(620, 18)
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new(); fill.bg_color = Color("9e2a1d")
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, 0.6)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", bg)
	box.add_child(_bar)
	_ui.visible = false


func _bake_navigation() -> void:
	nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.5
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nav.navigation_mesh = nm
	add_child(nav)
	# the region parses its own children: move the built geometry under it
	for c in get_children():
		if c != nav and c is Node3D and not (c is OmniLight3D) and not (c is Label3D):
			c.reparent(nav)
	nav.bake_navigation_mesh(true)


# ------------------------------------------------------------------ gameplay (host)
func reset() -> void:
	for id in rooms:
		for e in rooms[id].enemies:
			if is_instance_valid(e):
				e.queue_free()
		rooms[id].enemies.clear()
		rooms[id].state = "idle"
		rooms[id].wave = 0
	boss = null
	boss_phase = 0
	for g in gates:
		set_gate(g, g == "arena")
	for b in jail_bars:
		b.visible = true
		_bars_collision(b, true)
	for ch in chests:
		ch.looted = false
		if ch.lid: ch.lid.visible = true


func area_of(pos: Vector3) -> String:
	var local := to_local(pos)
	if local.y < -3 or local.y > 12:
		return ""
	return cells.get(Vector2i(roundi(local.x / CELL), roundi(local.z / CELL)), "")


func request_use(actor: CharacterBody3D) -> bool:
	if not is_instance_valid(actor):
		return false
	var p := actor.global_position
	var action := ""
	var best := INF
	if area_of(p) == "":
		return false
	if true:
		# the closest thing in reach wins (the treasure-room exit sits next to a chest)
		for ei in exits.size():
			if exit_locks.has(ei) and not gates[exit_locks[ei]].open:
				continue
			var d := p.distance_to(to_global(exits[ei]))
			if d < 2.6 and d < best:
				best = d
				action = "exit"
		for i in chests.size():
			var d := p.distance_to(to_global(chests[i].pos))
			if not chests[i].looted and d < 2.2 and d < best:
				best = d
				action = "chest:%d" % i
	if action == "":
		return false
	if _host:
		_do(actor, action)
	else:
		_ask.rpc_id(1, action)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _ask(action: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if world.actors.has(peer):
		_do(world.actors[peer], action)


func _do(actor: CharacterBody3D, action: String) -> void:
	if action == "exit":
		_teleport(actor, rocca.cripta_return() if rocca else Vector3(0, 2, 0))
	elif action.begins_with("chest:"):
		var ch: Dictionary = chests[int(action.substr(6))]
		if ch.looted:
			return
		ch.looted = true
		if ch.heal:
			actor.health = load("res://autoload/balance.gd").PLAYER_MAX_HEALTH
			world.announce("Bende e acqua pulita: salute al massimo.", 3)
		else:
			actor.credits += ch.amount
			world.announce("Forziere: +%d crediti." % ch.amount, 3)
		if ch.lid:
			ch.lid.visible = false
		_push_state()


## Dalla botola della Rocca (host): giù nell'ingresso della Cripta.
func enter(actor: CharacterBody3D) -> void:
	_teleport(actor, to_global(cell_pos(Vector2i(1, 1)) + Vector3(2, 0.3, 0)))
	world.announce("LA CRIPTA · Labirinto, segrete, cisterna. In fondo la sala dei secondini tiene bloccata l'arena.", 6)


func _teleport(actor: CharacterBody3D, to: Vector3) -> void:
	actor.global_position = to
	actor.velocity = Vector3.ZERO
	if actor.has_method("set_crouched"):
		actor.set_crouched(false, true)


func _spawn(kind: int, c: Vector2i, room: String, offset := Vector3.ZERO, y := 0.0) -> Node3D:
	var at := world_pos(c, y) + offset
	var e: Node3D = world._spawn_enemy(at)
	e.set_kind(kind, 2)
	e.home = at
	rooms[room].enemies.append(e)
	var near: CharacterBody3D = world.nearest_player(at)
	if near and near.global_position.distance_to(at) < 45:
		e.hear(near, 45)
	return e


func _start(room: String) -> void:
	var r: Dictionary = rooms[room]
	r.state = "active"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match room:
		"labirinto":
			world.announce("IL LABIRINTO · Qualcosa si trascina tra i corridoi.", 4)
			var rect: Rect2i = r.rect
			var placed := 0
			while placed < 12:
				var c := Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1), rng.randi_range(rect.position.y, rect.end.y - 4))
				_spawn(1 if placed % 6 == 5 else 0, c, room)
				placed += 1
		"prigioni":
			world.announce("LE SEGRETE · Le serrature cedono...", 4)
			get_tree().create_timer(2.0).timeout.connect(func():
				_open_jails()
				for row in JAIL_ROWS:
					for x in [0, 7]:
						_spawn(3 if rng.randf() < .15 else 0, Vector2i(x, row), room)
				r.wave = 1)
		"cisterna":
			world.announce("LA CISTERNA · Gli sputatori vi aspettano sulle piattaforme. Usate la copertura.", 5)
			for c in PLATFORMS:
				_spawn(4, c, room, Vector3.ZERO, 2.55)
			for i in 6:
				_spawn(0, Vector2i(rng.randi_range(-1, 9), rng.randi_range(-35, -31)), room)
			_spawn(2, Vector2i(4, -35), room)
			_spawn(1, Vector2i(1, -35), room)
		"arena":
			# Sala dei secondini: i carcerieri del Carceriere, due bruti e il capo dei secondini (urlatore), poi le ondate.
			set_gate("arena", false)
			world.announce("LA SALA DEI SECONDINI · La saracinesca si chiude alle vostre spalle.", 5)
			var top: int = rooms["arena"].rect.position.y
			boss = _spawn(3, Vector2i(4, top + 1), room, Vector3(CELL * 0.5, 0, 0))
			boss.alert_time = 1.6
			_spawn(2, Vector2i(2, top + 2), room)
			_spawn(2, Vector2i(7, top + 2), room)
			for c in [Vector2i(3, top + 3), Vector2i(6, top + 3)]:
				_spawn(0, c, room)
			r.wave = 1
			boss_phase = 0
			boss_empty_time = 0.0


func _cleared(room: String) -> void:
	var r: Dictionary = rooms[room]
	match room:
		"prigioni":
			if r.wave == 1:
				r.wave = 2
				world.announce("Altri arrivano dal fondo!", 3)
				for i in 4:
					_spawn(1, Vector2i(2 + i, -26), room)
				_spawn(2, Vector2i(4, -25), room)
				return
			set_gate("prigioni", true)
			world.announce("Le prigioni tacciono. La porta nord si apre.", 4)
		"cisterna":
			set_gate("cisterna", true)
			world.announce("La cisterna è libera. Avanti, verso l'anticamera.", 4)
		"arena":
			if r.wave < 3:
				r.wave += 1
				var top: int = rooms["arena"].rect.position.y
				if r.wave == 2:
					world.announce("Dalle celle in alto scendono gli sputatori!", 3)
					for c in [Vector2i(2, top + 1), Vector2i(7, top + 1)]:
						_spawn(4, c, room)
					for c in [Vector2i(3, top + 4), Vector2i(6, top + 4), Vector2i(4, top + 5)]:
						_spawn(1, c, room)
				else:
					world.announce("L'ultima squadra dei secondini!", 3)
					_spawn(2, Vector2i(4, top + 2), room, Vector3(CELL * 0.5, 0, 0))
					for c in [Vector2i(2, top + 4), Vector2i(7, top + 4), Vector2i(3, top + 1), Vector2i(6, top + 1)]:
						_spawn(0 if c.y > top + 2 else 3, c, room)
				return
			set_gate("arena", true)
			set_gate("tesoro", true)
			set_gate("uscita", true)
			if rocca: rocca.crypt_cleared()
			world.announce("I SECONDINI SONO CADUTI · Il tesoro è aperto. La scala riporta nella Rocca: l'arena del Carceriere è libera.", 7)
	r.state = "cleared"


func _open_jails() -> void:
	for b in jail_bars:
		var tw := create_tween()
		tw.tween_property(b, "position:y", b.position.y + 3.2, 1.2).set_trans(Tween.TRANS_BACK)
		_bars_collision(b, false)
	if _host:
		_push_state()


func _bars_collision(b: Node3D, on: bool) -> void:
	for s in b.find_children("*", "CollisionShape3D", true, false):
		(s as CollisionShape3D).disabled = not on


func _process(delta: float) -> void:
	if not world or not world.get("started"):
		return
	# flicker
	var t := Time.get_ticks_msec() * 0.001
	for i in torches.size():
		var l := torches[i]
		l.light_energy = l.get_meta("base") * (0.88 + 0.12 * sin(t * 9.0 + i * 1.7) * sin(t * 13.0 + i))
	_local_view()
	_update_boss_bar()
	if not _host:
		return
	_poll -= delta
	if _poll > 0:
		return
	_poll = 0.25
	var occupied := {}
	for a in world.actors.values():
		if is_instance_valid(a) and not a.dead:
			var ar := area_of(a.global_position)
			if ar != "":
				occupied[ar] = true
	for id in rooms:
		var r: Dictionary = rooms[id]
		if r.state == "idle" and occupied.has(id) and id in ["labirinto", "prigioni", "cisterna", "arena"]:
			_start(id)
		elif r.state == "active":
			var alive := 0
			for e in r.enemies:
				if is_instance_valid(e) and not e.dead:
					alive += 1
			if alive == 0 and (id != "prigioni" or r.wave > 0):
				_cleared(id)
	_boss_logic(occupied, 0.25)


func _boss_logic(occupied: Dictionary, dt: float) -> void:
	if not is_instance_valid(boss) or boss.dead or boss.kind != 5:
		return
	var frac: float = boss.health / boss.max_health
	if boss_phase == 0 and frac < 0.66:
		boss_phase = 1
		boss.alert_time = 1.8
		world.announce("Il Carceriere chiama i suoi prigionieri!", 3)
		for c in [Vector2i(2, -46), Vector2i(7, -46), Vector2i(2, -43)]:
			_spawn(0, c, "arena")
		_spawn(4, Vector2i(7, -43), "arena")
	elif boss_phase == 1 and frac < 0.33:
		boss_phase = 2
		boss.alert_time = 1.8
		world.announce("FURIA · Il Carceriere perde il controllo!", 3)
		boss.anim_scale = 0.9
		for c in [Vector2i(3, -46), Vector2i(6, -46)]:
			_spawn(1, c, "arena")
		_spawn(4, Vector2i(2, -43), "arena")
		_spawn(4, Vector2i(7, -43), "arena")
	# nobody left in the arena: reset the fight after 20 s
	if not occupied.has("arena"):
		boss_empty_time += dt
		if boss_empty_time > 20.0:
			for e in rooms["arena"].enemies:
				if is_instance_valid(e):
					e.queue_free()
			rooms["arena"].enemies.clear()
			rooms["arena"].state = "idle"
			boss = null
			set_gate("arena", true)
	else:
		boss_empty_time = 0.0


func _local_view() -> void:
	var p: CharacterBody3D = world.player
	if not is_instance_valid(p):
		return
	var inside := area_of(p.global_position) != ""
	if inside == _inside:
		return
	_inside = inside
	p.rig.camera.environment = env if inside else null
	if inside:
		_suns = world.find_children("*", "DirectionalLight3D", true, false)
		for s in _suns:
			s.set_meta("was_visible", s.visible)
			s.visible = false
	else:
		for s in _suns:
			if is_instance_valid(s):
				s.visible = s.get_meta("was_visible", true)
		_suns.clear()


func _update_boss_bar() -> void:
	# Il Carceriere ha la sua barra nella Rocca: qui sotto niente boss.
	_ui.visible = false
	if true:
		return
	var p: CharacterBody3D = world.player
	var b: Node3D = null
	for e in world.targets:
		if is_instance_valid(e) and e.kind == 5 and not e.dead and not e.has_meta("borgo"):   # il boss del borgo ha la sua barra
			b = e
			break
	_ui.visible = b != null and is_instance_valid(p) and b.global_position.distance_to(p.global_position) < 45
	if _ui.visible:
		_bar.max_value = b.max_health
		_bar.value = b.health


# ------------------------------------------------------------------ network
func _push_state() -> void:
	if not Session.online or not multiplayer.is_server():
		return
	var g := {}
	for k in gates:
		g[k] = gates[k].open
	var looted := []
	for ch in chests:
		looted.append(ch.looted)
	var jails_open := not jail_bars.is_empty() and jail_bars[0].position.y > 1.0
	for peer in Session.connected_peers():
		_state.rpc_id(peer, g, looted, jails_open)


@rpc("authority", "call_remote", "reliable")
func _state(g: Dictionary, looted: Array, jails_open: bool) -> void:
	for k in g:
		set_gate(k, g[k])
	for i in mini(looted.size(), chests.size()):
		if looted[i] and not chests[i].looted:
			chests[i].looted = true
			if chests[i].lid:
				chests[i].lid.visible = false
	if jails_open and not jail_bars.is_empty() and jail_bars[0].position.y < 1.0:
		_open_jails()
