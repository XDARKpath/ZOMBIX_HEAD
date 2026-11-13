# LIVELLO 1 · LA ROCCA MALEDETTA  (medievale, kit originale tools/castle_kit + prop animati art/zx_rocca)
#
#   SUPERFICIE      torre di guardia in rovina ([E] entra, le ante si aprono)
#   PIANO DI SOPRA (y +5)  Corpo di guardia -> SALA GRANDE (tavolate, trono, camino, lampadari, stendardi)
#                          con la BALCONATA che guarda giù nella Fossa. Armeria: la CHIAVE D'ORO.
#                          Porta della torre CHIUSA COL LUCCHETTO: [E] con la chiave -> la chiave gira, il lucchetto cade.
#                          Torre con la SCALA A CHIOCCIOLA (5 m) fino al sotterraneo.
#   SOTTERRANEO (y 0)      Cantina (botti, casse da rompere, forziere) -> LA FOSSA (alta 10 m, impalcature con gli
#                          SPUTATORI, gabbie appese) -> Prigioni (walker che girano intorno al blocco di celle)
#                          -> Cripte (filo coi campanelli + barile di polvere) -> Corridoio dei draghi (getti di fuoco)
#                          -> Laboratorio dell'alchimista: la CARNE MALEDETTA (l'esca) -> Corridoio delle lame
#                          (pendoli, spuntoni, muro dei dardi) -> ARENA OTTAGONALE: l'esca sull'ALTARE al centro ->
#                          campane, sangue, saracinesche giù, la GABBIA appesa cade e ne esce IL CARCERIERE (kind 5).
#                          Boss morto -> uscita a nord -> superficie.
# Come il dungeon: costruito a runtime, sospeso lontano dalla mappa, host autoritativo con lo stato ai client.
#
# ZOMBIX HEAD: Rocca e Cripta (world/dungeon/dungeon.gd) sono un solo dungeon. La torre sta al sito "dungeon" della
# Zona 1 (roadnet.gd), accanto alla miniera sbarrata; Bruno lo speleologo spiega tutto all'ingresso. In fondo al
# corridoio delle lame la saracinesca dell'arena è bloccata da sotto: una botola porta nella Cripta (labirinto,
# segrete, cisterna, sala dei secondini). Ripulita la Cripta si risale, la saracinesca si alza e si affronta il Carceriere.
extends Node3D

const MODULES := preload("res://art/zx_rocca/rocca_modules.glb")
const Traps := preload("res://world/rocca/rocca_traps.gd")
const Props := preload("res://world/rocca/rocca_props.gd")
const PROPS := "res://art/zx_rocca/props/"
const ORIGIN := Vector3(1500, 600, 1500)    # sopra ogni montagna del bordo (al massimo ~450 m): a 300 i massi del terreno entravano nella torre
## Torre in superficie: al sito del dungeon (RoadNet.SITES), in una radura nel bosco, con il portone verso la pista.
## Il portone è sempre aperto e dentro la torre una scala illuminata scende sotto terra fino alla Rocca.
const SITE_OFFSET := Vector3(-3.0, 0, 0)
const STAIR_STEPS := 15
const STAIR_RISE := 0.28
const STAIR_RUN := 0.36
const STAIR_TOP_Z := 1.9
const C_STONE := Color("706b61")
const C_FLOOR := Color("7f786b")
const C_NOSE := Color("cfc6b2")
var _stone_mats := {}
var _brick_tex: ImageTexture
const ENTRANCE_YAW := PI / 2
const Terrain := preload("res://world/campaign/terrain.gd")
const RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
const Npc := preload("res://world/campaign/npc_pose.gd")
const HATCH_CELL := Vector2i(0, -10)           # botola della Cripta, davanti alla saracinesca sud dell'arena
const CELL := 4.0
const UP := 5.0                               # quota del piano di sopra (= pianerottolo della scala a chiocciola)
const TOWER := Vector2i(5, 4)                 # cella della torre (scala a chiocciola, entrambi i piani)
const OCT_C := Vector3(0, 0, -56)             # centro dell'arena ottagonale (apotema 14: lati sud/nord sui bordi di cella)
const OCT_A := 14.0
const OCT_R := 15.154
const N := Vector2i(0, -1)
const S := Vector2i(0, 1)
const E := Vector2i(1, 0)
const W := Vector2i(-1, 0)

## id, titolo, celle, piano (0 / 1), piani di parete (1 = 5 m, 2 = 10 m), tipo ("room" pavimento+volta, "corridor" volta a botte, "tall" senza volta)
const ROOMS := [
	["ingresso", "CORPO DI GUARDIA", Rect2i(0, 6, 2, 2), 1, 1, "room"],
	["sala", "SALA GRANDE", Rect2i(-2, 2, 6, 4), 1, 1, "room"],
	["armeria", "ARMERIA", Rect2i(-4, 3, 2, 2), 1, 1, "room"],
	["anticamera", "ANTICAMERA DELLA TORRE", Rect2i(4, 4, 1, 1), 1, 1, "room"],
	["cantina", "CANTINA", Rect2i(2, 2, 3, 3), 0, 1, "room"],
	["fossa", "LA FOSSA", Rect2i(-2, -4, 6, 6), 0, 2, "tall"],
	["prigioni", "LE PRIGIONI", Rect2i(-6, -6, 4, 8), 0, 1, "room"],
	["cripta_a", "CRIPTA DEI CAVALIERI", Rect2i(-6, 2, 2, 2), 0, 1, "room"],
	["corridoio", "CORRIDOIO DEI DRAGHI", Rect2i(4, -6, 1, 8), 0, 1, "corridor"],
	["cripta_b", "CRIPTA DEL TESORO", Rect2i(5, -2, 2, 2), 0, 1, "room"],
	["alchimista", "LABORATORIO DELL'ALCHIMISTA", Rect2i(5, -6, 3, 3), 0, 1, "room"],
	["lame", "CORRIDOIO DELLE LAME", Rect2i(0, -10, 1, 6), 0, 1, "corridor"],
	["uscita", "USCITA DEL CARCERIERE", Rect2i(0, -19, 1, 2), 0, 1, "corridor"],
]
## porte: cella A, cella B, piano, tipo ("door" arco di pietra, "wood" arco di legno, "open" passaggio libero, "locked", "tower", "balcony")
const DOORS := [
	[Vector2i(0, 6), Vector2i(0, 5), 1, "door"],
	[Vector2i(-3, 3), Vector2i(-2, 3), 1, "wood"],
	[Vector2i(3, 4), Vector2i(4, 4), 1, "locked"],
	[Vector2i(4, 4), Vector2i(5, 4), 1, "tower"],
	[Vector2i(4, 4), Vector2i(5, 4), 0, "tower"],
	[Vector2i(2, 2), Vector2i(2, 1), 0, "door"],
	[Vector2i(-2, -2), Vector2i(-3, -2), 0, "door"],
	[Vector2i(-6, 1), Vector2i(-6, 2), 0, "wood"],
	[Vector2i(3, -1), Vector2i(4, -1), 0, "door"],
	[Vector2i(4, -2), Vector2i(5, -2), 0, "wood"],
	[Vector2i(4, -5), Vector2i(5, -5), 0, "wood"],
	[Vector2i(0, -4), Vector2i(0, -5), 0, "door"],
	[Vector2i(0, -10), Vector2i(0, -11), 0, "open"],
	[Vector2i(0, -18), Vector2i(0, -17), 0, "open"],
]
const SOLID := ["P_BarrelBig", "P_BarrelClosed", "P_BarrelOpen", "P_TableBig", "P_TableSmall", "P_Bench", "P_Shelf", "P_Throne", "P_Cauldron",
	"P_WeaponRackBig", "P_WeaponRackSmall", "P_Desk", "P_Fireplace", "P_Oven", "P_AmphoraStand", "P_Sarcophagus", "P_ScaffoldPost", "P_SpikeRack"]
const WALLS := ["M_Wall1", "M_Wall1", "M_Wall2", "M_Wall3", "M_Wall1"]

var world: Node3D
var host := true
var clock := 0.0
var lib := {}
var _posts := {}                              # pali messi da _geometry, per non doppiarli in _tower
var cells := {}                               # Vector3i(x, z, piano) -> id
var rooms := {}
var links := {}
var spikes: Array = []
var pendulums: Array = []
var arrows: Array = []
var fires: Array = []
var wires: Array = []
var crates: Array = []
var chests: Array = []
var pickups: Array = []
var gates := {}
var torches: Array[OmniLight3D] = []
var arena_lights: Array[OmniLight3D] = []
var bells: Array[AnimationPlayer] = []
var nav: NavigationRegion3D
var env_upper: Environment
var env_lower: Environment
var env_arena: Environment
var entrance_pos: Vector3
var entrance_node: Node3D
var entrance_ap: AnimationPlayer
var cripta: Node3D                 # world/dungeon/dungeon.gd
var cripta_done := false           # sala dei secondini ripulita: la saracinesca sud dell'arena si alza
var guide: Node3D
var guide_pos: Vector3
var _hatch_label: Label3D
var has_key := false
var has_bait := false
var door_open := false
var bait_placed := false
var boss: Node3D
var boss_phase := 0
var boss_dead := false
var arena_empty := 0.0
var door: Node3D
var door_ap: AnimationPlayer
var door_body: StaticBody3D
var altar_ap: AnimationPlayer
var cage: Node3D
var cage_ap: AnimationPlayer
var exits := []
var _poll := 0.0
var _inside := ""
var _suns: Array = []
var _ui: CanvasLayer
var _bar: ProgressBar
var _bar_label: Label
var _objective: Label
var _rage := 0.0
var _rng := RandomNumberGenerator.new()


func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "Rocca"
	position = ORIGIN
	host = not Session.online or multiplayer.is_server()
	_rng.seed = 777
	var src: Node3D = MODULES.instantiate()
	for n in src.get_children():
		lib[String(n.name)] = n
	_layout()
	_geometry()
	_tower()
	_octagon()
	_dress()
	_lights()
	_environment()
	_surface_entrance()
	_ui_build()
	if host:
		_bake_navigation()
	_interactive()
	reset()


# =================================================================== LAYOUT
func _layout() -> void:
	for r in ROOMS:
		var rect: Rect2i = r[2]
		rooms[r[0]] = {"title": r[1], "rect": rect, "level": r[3], "tiers": r[4], "kind": r[5], "state": "idle", "enemies": []}
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				cells[Vector3i(x, z, r[3])] = r[0]
	for d in DOORS:
		links[_edge(d[0], d[1], d[2])] = d[3]
	for x in range(-2, 4):                                 # balconata: la sala grande si affaccia sulla fossa
		links[_edge(Vector2i(x, 2), Vector2i(x, 1), 1)] = "balcony"


func _edge(a: Vector2i, b: Vector2i, lv: int) -> String:
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var t := a; a = b; b = t
	return "%d,%d|%d,%d|%d" % [a.x, a.y, b.x, b.y, lv]


func cell_pos(c: Vector2i, y := 0.0) -> Vector3:
	return Vector3(c.x * CELL, y, c.y * CELL)


func world_pos(c: Vector2i, y := 0.0) -> Vector3:
	return to_global(cell_pos(c, y))


func _rot(d: Vector2i) -> float:
	if d == N: return 0.0
	if d == W: return PI / 2
	if d == S: return PI
	return -PI / 2


func _place(key: String, pos: Vector3, rot := 0.0, parent: Node = self) -> Node3D:
	var t: Node3D = lib.get(key, lib.get("M_" + key, lib.get("P_" + key)))
	if t == null:
		push_warning("rocca: modulo mancante " + key)
		return null
	var n := t.duplicate() as Node3D
	n.position = pos
	n.rotation = Vector3(0, rot, 0)
	parent.add_child(n)
	if key in SOLID or ("P_" + key) in SOLID:
		_box_collider(n)
	return n


## Le volte alte si vedono e devono anche fermare corpi e proiettili: sopra c'è il vuoto.
func _solid_slab(slab: Node3D) -> void:
	if slab: _box_collider(slab)


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


# =================================================================== GEOMETRIA
func _geometry() -> void:
	var posts := {}
	for key in cells:
		var c := Vector2i(key.x, key.y)
		var lv: int = key.z
		var id: String = cells[key]
		var r: Dictionary = rooms[id]
		var base := UP if lv == 1 else 0.0
		match r.kind:
			"corridor":
				_place("M_Straight", cell_pos(c, base), 0.0)
			"tall":
				_place("M_FloorTile", cell_pos(c, base))
				_solid_slab(_place("P_RoofSlab", cell_pos(c, base + 10.0)))
			_:
				_place("M_CustomCenter", cell_pos(c, base))
		for d in [N, S, E, W]:
			var o: Vector2i = c + d
			var other: String = cells.get(Vector3i(o.x, o.y, lv), "")
			if other == id:
				continue
			var kind: String = links.get(_edge(c, o, lv), "")
			var mid := cell_pos(c, base) + Vector3(d.x, 0, d.y) * CELL * 0.5
			var along := 0.0 if (d == N or d == S) else PI / 2
			var mine: bool = other == "" or d == N or d == E      # un muro condiviso si posa una volta sola
			if kind == "tower":
				continue                                          # la parete della torre ha già le sue porte
			if kind == "balcony":
				if id == "sala":
					_balcony_edge(c, d, base)
				continue
			if kind in ["door", "wood", "locked"]:
				if mine:
					_place("M_Passage" if kind != "wood" else "M_PassageWood", mid, along)
			elif kind == "open":
				pass
			elif mine:
				_place(WALLS[_rng.randi() % WALLS.size()], cell_pos(c, base), _rot(d))
				var side := Vector2i(d.y, d.x)
				for sgn in [-1, 1]:
					var p: Vector3 = mid + Vector3(side.x, 0, side.y) * CELL * 0.5 * sgn
					posts[Vector3i(roundi(p.x * 10), roundi(p.y * 10), roundi(p.z * 10))] = p
			# secondo piano di parete (sale alte): 5 -> 10 m
			if r.tiers == 2 and (mine or rooms[other].tiers < 2):
				if d == S and cells.has(Vector3i(c.x, c.y + 1, 1)):
					continue                                      # lì sopra c'è la balconata della sala grande
				_place(WALLS[_rng.randi() % WALLS.size()], cell_pos(c, base + 5.0), _rot(d))
	for p in posts.values():
		_place("M_Pillar", p)
	_posts = posts


## Ante chiuse nel vano di un cancello delle celle (il kit lo lascia aperto): le due ante strette nel varco da 1,7 m, una sola scatola.
func _jail_doors(gate: Node3D) -> void:
	for key in ["M_JailDoorL", "M_JailDoorR"]:
		var leaf := _place(key, Vector3(0, 0, 0.13), 0.0, gate)
		if leaf == null: return
		leaf.scale = Vector3(0.68, 1.0, 1.0)
		for body in leaf.find_children("*", "StaticBody3D", true, false): body.free()
	_solid(gate, Vector3(0, 1.12, 0.12), Vector3(1.7, 2.12, 0.14))


func _balcony_edge(c: Vector2i, d: Vector2i, base: float) -> void:
	# ringhiera di legno sul bordo nord della sala grande, con i pali agli angoli
	var mid := cell_pos(c, base) + Vector3(d.x, 0, d.y) * (CELL * 0.5 - 0.15)
	_place("M_BalconyRailing", mid, 0.0)
	for sx in [-1.95, 1.95]:
		_place("M_BalconyPost", mid + Vector3(sx, 0, 0))


## collider a rampa (scatola inclinata) con la superficie sulla linea da "a" a "b": niente gradini da scavalcare
func _ramp(a: Vector3, b: Vector3, width: float, thick := 0.16) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var dir := b - a
	box.size = Vector3(width, thick, dir.length() + 0.1)
	cs.shape = box
	sb.add_child(cs)
	add_child(sb)
	var up := Vector3.UP.cross(dir).cross(dir).normalized() * -1.0
	sb.transform = Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5 - up * thick * 0.5)


func _tower() -> void:
	# torre della scala a chiocciola (cella TOWER): pavimento, scala, muri su N/E/S per 10 m. Porte verso ovest (anticamera / cantina).
	var c := TOWER
	_place("M_FloorTile", cell_pos(c))
	_place("M_Staircase", cell_pos(c), -PI / 2)
	for d in [N, E, S]:
		for t in 2:
			_place("M_Wall1", cell_pos(c, 5.0 * t), _rot(d))
	for p in [Vector3(2, 0, 2), Vector3(2, 0, -2), Vector3(-2, 0, 2), Vector3(-2, 0, -2)]:
		for t in 2:
			var pp: Vector3 = cell_pos(c, 5.0 * t) + p
			# Sugli angoli dei muri il palo c'è già: lo stesso pilastro due volte nello stesso punto sfarfalla.
			if not _posts.has(Vector3i(roundi(pp.x * 10), roundi(pp.y * 10), roundi(pp.z * 10))):
				_place("M_Pillar", pp)
	# rampa elicoidale invisibile sopra i gradini della chiocciola (il giocatore non sale i gradini veri):
	# parte a nord (270°, 0 m) e gira in senso orario visto dall'alto fino al pianerottolo a 5 m (810°, quasi due giri)
	var cen := cell_pos(c)
	var a0 := 240.0
	var steps := 57
	for i in steps:
		# Ogni tratto sborda di 2° nei vicini: fra scatole dritte su un'elica restavano spigoli che fermavano i piedi.
		var da := a0 + i * 10.0 - 2.0
		var db := a0 + (i + 1) * 10.0 + 2.0
		var ha := clampf(0.2 + (da - 270.0) * 0.0089, 0.0, 5.0) + 0.04
		var hb := clampf(0.2 + (db - 270.0) * 0.0089, 0.0, 5.0) + 0.04
		var r := 1.3
		_ramp(cen + Vector3(cos(deg_to_rad(da)) * r, ha, sin(deg_to_rad(da)) * r), cen + Vector3(cos(deg_to_rad(db)) * r, hb, sin(deg_to_rad(db)) * r), 1.5)


func _octagon() -> void:
	# arena ottagonale: 3 muri del kit per lato (scalati), due piani di parete (10 m), pavimento a lastre, copertura
	var side := 2.0 * OCT_R * sin(PI / 8.0)
	var n := 3
	var seg := side / n
	for k in 8:
		var phi := deg_to_rad(45.0 * k)
		var nrm := Vector3(cos(phi), 0, sin(phi))
		var tang := Vector3(-nrm.z, 0, nrm.x)
		var rot := atan2(-nrm.x, -nrm.z)
		for i in n:
			var off := (i - (n - 1) / 2.0) * seg
			var door := (k == 2 or k == 6) and i == 1                      # varchi sud (k=2) e nord (k=6)
			var p := OCT_C + nrm * (OCT_A - 1.92) + tang * off
			for t in 2:
				var key: String = "M_Passage" if (door and t == 0) else WALLS[(k + i + t) % WALLS.size()]
				var w := _place(key, (p if key != "M_Passage" else OCT_C + nrm * OCT_A + tang * off) + Vector3(0, 5.0 * t, 0), rot)
				if w:
					w.scale = Vector3(seg / 4.0, 1.0, 1.0)
		_place("M_Pillar", OCT_C + Vector3(cos(phi + PI / 8), 0, sin(phi + PI / 8)) * (OCT_R - 0.3))
		_place("M_Pillar", OCT_C + Vector3(cos(phi + PI / 8), 0, sin(phi + PI / 8)) * (OCT_R - 0.3) + Vector3(0, 5, 0))
	for x in range(-4, 4):
		for z in range(-4, 4):
			var p := OCT_C + Vector3(x * CELL + 2, 0, z * CELL + 2)
			if Vector2(p.x - OCT_C.x, p.z - OCT_C.z).length() < OCT_R + 2.0:
				_place("M_FloorTile", p)
				_solid_slab(_place("P_RoofSlab", p + Vector3(0, 10.0, 0)))
	# Ingombro dell'altare (posato dopo il bake in _interactive): così la navmesh gli gira attorno.
	_solid(self, OCT_C + Vector3(0, 0.75, 0), Vector3(1.8, 1.5, 1.2))
	_gate("arena_sud", OCT_C + Vector3(0, 0, OCT_A + 0.32), 0.0)
	_gate("arena_nord", OCT_C + Vector3(0, 0, -OCT_A - 0.32), 0.0)


func _gate(gname: String, at: Vector3, rot: float) -> void:
	var g := _place("M_Portcullis", at, rot)
	if g == null:
		return
	gates[gname] = {"node": g, "open": true, "closed_y": at.y, "open_y": at.y + 3.7}
	g.position.y = at.y + 3.7
	for s in g.find_children("*", "CollisionShape3D", true, false):
		(s as CollisionShape3D).disabled = true


func set_gate(gname: String, open: bool) -> void:
	if not gates.has(gname):
		return
	var g: Dictionary = gates[gname]
	if g.open == open:
		return
	g.open = open
	if not open and host:
		_clear_gate(g)
	var tw := create_tween()
	tw.tween_property(g.node, "position:y", g.open_y if open else g.closed_y, 1.6 if open else 0.55).set_trans(Tween.TRANS_QUAD if open else Tween.TRANS_BOUNCE)
	for s in g.node.find_children("*", "CollisionShape3D", true, false):
		(s as CollisionShape3D).set_deferred("disabled", open)


## Chi sta nel varco quando la saracinesca cala va dentro l'arena: prima restava incastrato sotto le sbarre.
func _clear_gate(g: Dictionary) -> void:
	var at: Vector3 = g.node.position
	var inward := signf(OCT_C.z - at.z)
	for a in world.actors.values():
		if not is_instance_valid(a) or a.get("seated"):
			continue
		var l := to_local(a.global_position)
		if absf(l.x - at.x) < 2.2 and absf(l.z - at.z) < 0.9 and l.y > g.closed_y - 1.0 and l.y < g.closed_y + 3.0:
			a.global_position = to_global(Vector3(l.x, l.y + 0.05, at.z + inward * 1.3))
			a.velocity = Vector3.ZERO


# =================================================================== ARREDO
func _dress() -> void:
	var u := UP
	# --- corpo di guardia
	_place("P_WeaponRackBig", cell_pos(Vector2i(0, 7), u) + Vector3(-1.4, 0, 1.3), PI)
	_place("P_WeaponRackSmall", cell_pos(Vector2i(1, 7), u) + Vector3(1.4, 0, 1.3), PI)
	_place("P_Bench", cell_pos(Vector2i(1, 6), u) + Vector3(1.5, 0, 0), -PI / 2)
	_place("P_BannerRed", cell_pos(Vector2i(0, 7), u) + Vector3(0, 0, 1.78), PI)
	_place("P_BannerRed", cell_pos(Vector2i(1, 7), u) + Vector3(0, 0, 1.78), PI)
	_place("P_Barrel_Closed" if lib.has("P_Barrel_Closed") else "P_BarrelClosed", cell_pos(Vector2i(0, 6), u) + Vector3(-1.4, 0, -1.3))
	_place("P_Shield", cell_pos(Vector2i(0, 7), u) + Vector3(-1.5, 0, 0.2), PI / 2)
	# --- sala grande: due tavolate, trono a ovest su tappeto, camino a sud, stendardi
	for z in [3, 4]:
		for x in [-1, 1]:
			var at := cell_pos(Vector2i(x, z), u) + Vector3(2, 0, 0)
			_place("P_TableBig", at, 0.0)
			for sz in [-1.2, 1.2]:
				_place("P_Bench", at + Vector3(-1.0, 0, sz), 0.0 if sz < 0 else PI)
				_place("P_Bench", at + Vector3(1.0, 0, sz), 0.0 if sz < 0 else PI)
			for i in 4:
				var px := at + Vector3(-1.5 + i, 0.84, 0.45 * (1 if i % 2 else -1))
				_place("P_Plate", px)
				_place("P_Goblet" if i % 2 else "P_Mug", px + Vector3(0.25, 0, 0))
			_place("P_CandleTriple", at + Vector3(0, 0.84, 0))
			_place("P_Bread", at + Vector3(0.6, 0.84, 0.1))
			_place("P_BowlFull", at + Vector3(-0.6, 0.84, -0.1))
	_place("P_CarpetRed", cell_pos(Vector2i(-2, 4), u) + Vector3(0.4, 0, -2), PI / 2)
	_place("P_Throne", cell_pos(Vector2i(-2, 4), u) + Vector3(-1.2, 0, -2), -PI / 2)
	_place("P_Fireplace", cell_pos(Vector2i(0, 5), u) + Vector3(2, 0, 1.95), PI)
	_place("P_FirewoodStack", cell_pos(Vector2i(1, 5), u) + Vector3(1.2, 0, 1.2))
	for x in [-2, 2, 3]:      # non a 0: lì accanto al camino c'è il varco, lo stendardo pendeva nel vuoto
		_place("P_BannerBlue" if x % 2 else "P_BannerRed", cell_pos(Vector2i(x, 5), u) + Vector3(0, 0.3, 1.8), PI)
	_place("P_BannerRed", cell_pos(Vector2i(-2, 4), u) + Vector3(-1.8, 0.3, 0), PI / 2)      # (-2,3) è il varco dell'armeria
	_place("P_WeaponWall", cell_pos(Vector2i(3, 3), u) + Vector3(1.8, 0, 0), -PI / 2)
	# --- armeria (la chiave d'oro sullo scrittoio)
	_place("P_Desk", cell_pos(Vector2i(-4, 3), u) + Vector3(0.6, 0, -1.2), PI)
	_place("P_Chair", cell_pos(Vector2i(-4, 3), u) + Vector3(0.6, 0, -0.3), PI + 0.3)
	_place("P_WeaponRackBig", cell_pos(Vector2i(-4, 4), u) + Vector3(-1.4, 0, 0.4), PI / 2)
	_place("P_WeaponRackSmall", cell_pos(Vector2i(-3, 4), u) + Vector3(0.2, 0, 1.4), PI)
	_place("P_WeaponWall", cell_pos(Vector2i(-4, 3), u) + Vector3(-1.8, 0, 0.5), PI / 2)
	_place("P_Shield", cell_pos(Vector2i(-3, 3), u) + Vector3(1.4, 0, -1.4))
	_place("P_Spear", cell_pos(Vector2i(-3, 3), u) + Vector3(1.6, 0, -0.9))
	_place("P_CandleWall", cell_pos(Vector2i(-4, 3), u) + Vector3(0, 2.2, -1.8))
	# --- anticamera della torre
	_place("P_BannerBlue", cell_pos(Vector2i(4, 4), u) + Vector3(0, 0.3, -1.8))
	_place("P_Bench", cell_pos(Vector2i(4, 4), u) + Vector3(0, 0, 1.5), PI)
	# --- cantina: botti grandi, scaffali, giare, legna
	_place("P_BarrelBig", cell_pos(Vector2i(3, 2)) + Vector3(0, 0, -0.6), 0.0)
	_place("P_BarrelBig", cell_pos(Vector2i(4, 2)) + Vector3(0.4, 0, -0.6), 0.0)
	for p in [Vector3(-1.4, 0, -1.4), Vector3(-0.5, 0, -1.5), Vector3(1.4, 0, 1.4)]:
		_place("P_BarrelClosed", cell_pos(Vector2i(2, 3)) + p)
	_place("P_BarrelOpen", cell_pos(Vector2i(3, 3)) + Vector3(1.0, 0, 1.3))
	_place("P_Shelf", cell_pos(Vector2i(2, 4)) + Vector3(-1.6, 0, 0.6), PI / 2)
	_place("P_JarFull", cell_pos(Vector2i(2, 4)) + Vector3(-1.6, 1.1, 0.4))
	_place("P_Firewood", cell_pos(Vector2i(4, 3)) + Vector3(1.2, 0, 0.5))
	# --- la fossa: impalcature a ovest con le balconate (sputatori a 3.5 m), gabbie appese, ossa, sangue
	for z in [-4, -3, -1, 0]:
		_place("M_Balcony", cell_pos(Vector2i(-2, z), 3.5))
		for p in [Vector3(-1.7, 0, -1.7), Vector3(1.7, 0, -1.7), Vector3(-1.7, 0, 1.7), Vector3(1.7, 0, 1.7)]:
			_place("P_ScaffoldPost", cell_pos(Vector2i(-2, z)) + p)
		_place("M_BalconyRailing", cell_pos(Vector2i(-2, z), 3.5) + Vector3(1.9, 0, 0), PI / 2)
	# scala di legno nella cella libera (-2,-2): sale verso nord fino alla balconata (-2,-3) a 3.5 m
	_place("P_WoodStairs", Vector3(-8.0, 0, -6.2), PI)
	_ramp(Vector3(-8.0, 0.0, -6.0), Vector3(-8.0, 3.54, -10.0), 1.34)
	# Sotto la metà alta la scala è piena: chi entra dalla porta delle Prigioni trova i montanti, non una lastra invisibile all'altezza della testa.
	_solid(self, Vector3(-8.0, 0.85, -9.0), Vector3(1.34, 1.7, 2.0))
	for c in [Vector2i(0, -2), Vector2i(2, -3), Vector2i(1, 0), Vector2i(3, -1)]:
		_place("P_HangingCage", cell_pos(c, 5.6))
	for c in [Vector2i(1, -1), Vector2i(2, 1), Vector2i(0, -3), Vector2i(3, 0)]:
		_place("P_BloodPool", cell_pos(c) + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)), _rng.randf() * TAU)
		_place("P_Skull", cell_pos(c) + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5)), _rng.randf() * TAU)
		_place("P_Bone", cell_pos(c) + Vector3(_rng.randf_range(-1.5, 1.5), 0.02, _rng.randf_range(-1.5, 1.5)), _rng.randf() * TAU)
	for c in [Vector2i(0, 1), Vector2i(3, -4)]:
		_place("P_SpikeRack", cell_pos(c) + Vector3(0, 0, 0.8 if c.y > 0 else -1.3), 0.0)
	_place("P_Cauldron", cell_pos(Vector2i(1, -2)))
	# --- prigioni: un blocco di celle al centro (colonna -5), corsie ai lati; due celle sfondate
	for z in range(-5, 1):
		if z == -2:
			continue
		var c := Vector2i(-5, z)
		for d in [W, E]:
			var mid := cell_pos(c) + Vector3(d.x, 0, 0) * CELL * 0.5
			var key := "M_JailGate" if (z % 2 == 0) else "M_JailWall"
			if (z == -4 and d == E) or (z == 0 and d == W):
				key = "M_JailBroken"
			var cell_gate := _place(key, mid, PI / 2 * (1 if d == E else -1))
			if key == "M_JailGate" and cell_gate: _jail_doors(cell_gate)
		_place("M_JailWall", cell_pos(c) + Vector3(0, 0, -2), 0.0)
		_place("P_Skull", cell_pos(c) + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)), _rng.randf() * TAU)
		_place("P_Bucket", cell_pos(c) + Vector3(1.2, 0, 1.2))
	_place("M_JailWall", cell_pos(Vector2i(-5, 0)) + Vector3(0, 0, 2), 0.0)
	_place("M_JailWall", cell_pos(Vector2i(-5, -3)) + Vector3(0, 0, 2), 0.0)
	for c in [Vector2i(-6, -5), Vector2i(-4, 0), Vector2i(-3, -6)]:
		_place("P_BloodPool", cell_pos(c), _rng.randf() * TAU)
	_place("P_TableSmall", cell_pos(Vector2i(-3, -6)) + Vector3(0.8, 0, -1.0))
	_place("P_KeyRusty", cell_pos(Vector2i(-3, -6)) + Vector3(0.8, 0.87, -1.0))
	# --- cripte
	for p in [Vector3(-1.0, 0, -0.3), Vector3(1.0, 0, -0.3)]:
		_place("P_Sarcophagus", cell_pos(Vector2i(-6, 3)) + p)
	_place("P_Sarcophagus", cell_pos(Vector2i(6, -2)) + Vector3(0.6, 0, -0.5), PI / 2)
	for c in [Vector2i(-7, 2), Vector2i(-6, 2), Vector2i(5, -1), Vector2i(6, -1)]:
		_place("P_CandleTriple", cell_pos(c) + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)))
	# --- corridoio dei draghi
	_place("P_Skull", cell_pos(Vector2i(4, 0)) + Vector3(0.5, 0, 0.3))
	_place("P_BloodPool", cell_pos(Vector2i(4, -3)), 1.0)
	# --- laboratorio dell'alchimista (la carne maledetta sul tavolo del macellaio)
	_place("P_TableBig", cell_pos(Vector2i(6, -5)) + Vector3(0, 0, 0.6), 0.0)
	_place("P_Cauldron", cell_pos(Vector2i(5, -6)) + Vector3(-0.6, 0, -0.6))
	_place("P_CauldronEmpty", cell_pos(Vector2i(7, -6)) + Vector3(0.6, 0, -0.6))
	_place("P_Shelf", cell_pos(Vector2i(7, -4)) + Vector3(1.6, 0, 0), -PI / 2)
	_place("P_Shelf", cell_pos(Vector2i(6, -6)) + Vector3(0, 0, -1.6))
	for i in 4:
		_place("P_PotionRed" if i % 2 else "P_PotionGreen", cell_pos(Vector2i(6, -6)) + Vector3(-0.6 + i * 0.4, 1.15, -1.6))
	for p in [Vector3(-1.2, 0.84, 0.3), Vector3(1.2, 0.84, 0.5)]:
		_place("P_BookRed" if p.x < 0 else "P_ScrollOpen", cell_pos(Vector2i(6, -5)) + p + Vector3(0, 0, 0.6))
	_place("P_Beaker", cell_pos(Vector2i(6, -5)) + Vector3(0.6, 0.84, 0.9))
	_place("P_CrystalBallStand", cell_pos(Vector2i(7, -5)) + Vector3(1.0, 0, -0.6))
	_place("P_Scales", cell_pos(Vector2i(5, -4)) + Vector3(-1.0, 0, 1.0))
	_place("P_BloodPool", cell_pos(Vector2i(6, -4)), 0.5)
	_place("P_HangingCage", cell_pos(Vector2i(5, -4), 0.0))
	# --- arena: candelabri e ossa sul perimetro, catene, campane ai lati
	for k in 8:
		if k == 2 or k == 6:
			continue
		var phi := deg_to_rad(45.0 * k)
		var at := OCT_C + Vector3(cos(phi), 0, sin(phi)) * 11.0
		_place("P_SpikeRack" if k % 2 else "P_CandleTriple", at, atan2(-cos(phi), -sin(phi)))
		_place("P_Skull", at + Vector3(0.6, 0, 0.4), _rng.randf() * TAU)


# =================================================================== LUCI
func _torch(pos: Vector3, rng_m: float, energy := 1.35, color := Color("ffa245")) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.omni_range = rng_m
	l.light_energy = energy
	l.light_color = color
	l.distance_fade_enabled = true
	l.distance_fade_begin = 40.0
	l.distance_fade_length = 10.0
	l.set_meta("base", energy)
	add_child(l)
	torches.append(l)
	return l


func _lights() -> void:
	# la torre ha solo feritoie: due fiaccole lungo la chiocciola
	_torch(cell_pos(TOWER) + Vector3(0, 2.6, 0), 6.0, 1.1)
	_torch(cell_pos(TOWER) + Vector3(0, 7.4, 0), 6.0, 1.1)
	var count := 0
	for key in cells:
		var c := Vector2i(key.x, key.y)
		var lv: int = key.z
		var id: String = cells[key]
		var base := UP if lv == 1 else 0.0
		for d in [N, W, E, S]:
			var o: Vector2i = c + d
			if cells.get(Vector3i(o.x, o.y, lv), "") == id or links.has(_edge(c, o, lv)):
				continue
			# Sulla parete sud della sala grande ci sono gli stendardi: niente torcia sopra il tessuto.
			if lv == 1 and c.y == 5 and d == S and c.x in [-2, 2, 3]:
				continue
			count += 1
			if count % 3 != 0:
				continue
			var mount := cell_pos(c, base) + Vector3(d.x, 0, d.y) * 1.8 + Vector3(0, 2.3, 0)
			_place("P_TorchWall", mount, _rot(d))
			# Raggio da stanza (celle da 4 m): senza ombre una luce lunga passa muri e solai.
			_torch(mount - Vector3(d.x, 0, d.y) * 0.45 + Vector3(0, 0.35, 0), 5.5)
			break
	# sala grande: lampadari + camino
	for x in [-1, 1]:
		_place("P_Chandelier", cell_pos(Vector2i(x, 3), UP + 4.3) + Vector3(2, 0, 2))
		_torch(cell_pos(Vector2i(x, 3), UP + 2.9) + Vector3(2, 0, 2), 7.5, 2.2, Color("ffc070"))
	_torch(cell_pos(Vector2i(0, 5), UP + 0.9) + Vector3(2, 0, 1.2), 6.0, 2.2, Color("ff8a30"))
	_hearth(cell_pos(Vector2i(0, 5), UP) + Vector3(2, 0.32, 1.62))
	# Prigioni: un braciere per corsia, prima erano quasi al buio.
	for c in [Vector2i(-6, -2), Vector2i(-4, -2)]:
		_torch(cell_pos(c, 2.4), 6.0, 1.3, Color("ffa24a"))
	for c in [Vector2i(-1, 3), Vector2i(1, 4)]:
		_torch(cell_pos(c, UP + 1.3) + Vector3(2, 0, 0), 4.0, 0.8, Color("ffd38a"))
	# fossa: bracieri rossi in basso, luce fioca dall'alto
	for c in [Vector2i(1, -2), Vector2i(3, 1), Vector2i(0, 1)]:
		_torch(cell_pos(c, 1.2), 9.0, 1.6, Color("ff6a2a"))
	_torch(cell_pos(Vector2i(1, -2), 8.5), 16.0, 0.9, Color("ffb070"))
	# alchimista: calderone verde
	_torch(cell_pos(Vector2i(5, -6), 1.3) + Vector3(-0.6, 0, -0.6), 7.0, 1.6, Color("7dff6a"))
	# arena: lampadari alti + luci rituali
	for k in 4:
		var phi := deg_to_rad(90.0 * k + 45.0)
		var at := OCT_C + Vector3(cos(phi), 0, sin(phi)) * 6.5
		_place("P_Chandelier", at + Vector3(0, 9.9, 0))
		arena_lights.append(_torch(at + Vector3(0, 8.4, 0), 12.0, 1.7, Color("ffb46a")))
	for k in 8:
		var phi := deg_to_rad(45.0 * k + 22.5)
		arena_lights.append(_torch(OCT_C + Vector3(cos(phi), 0, sin(phi)) * 11.5 + Vector3(0, 1.3, 0), 6.0, 0.9))


## Fuoco nel camino: la luce arancione aveva la bocca nera.
func _hearth(at: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff9a3a")
	mat.emission_enabled = true
	mat.emission = Color("ff7a1f")
	mat.emission_energy_multiplier = 3.0
	for i in 3:
		var f := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.34, 0.36, 0.3) * (1.0 - i * 0.25)
		m.material = mat
		f.mesh = m
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(f)
		f.position = at + Vector3((i - 1) * 0.22, i * 0.12, 0)
		f.rotation.y = i * 0.7


func _environment() -> void:
	env_lower = Environment.new()
	env_lower.background_mode = Environment.BG_COLOR
	env_lower.background_color = Color(0.02, 0.018, 0.016)
	env_lower.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_lower.ambient_light_color = Color(0.34, 0.29, 0.25)
	env_lower.ambient_light_energy = 0.5
	env_lower.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_lower.fog_enabled = true
	env_lower.fog_light_color = Color(0.09, 0.07, 0.06)
	env_lower.fog_density = 0.016
	env_lower.glow_enabled = true
	env_lower.glow_intensity = 0.6
	env_upper = env_lower.duplicate()
	env_upper.ambient_light_color = Color(0.5, 0.42, 0.34)
	env_upper.ambient_light_energy = 0.7
	env_upper.fog_density = 0.008
	env_arena = env_lower.duplicate()


# =================================================================== OGGETTI INTERATTIVI (dopo la navmesh)
func _anim_prop(file: String, pos: Vector3, rot := 0.0) -> Node3D:
	var n: Node3D = load(PROPS + file + ".glb").instantiate()
	n.position = pos
	n.rotation.y = rot
	add_child(n)
	return n


func _interactive() -> void:
	var u := UP
	# porta col lucchetto: bordo (3,4)|(4,4) al piano di sopra, fronte verso la sala (ovest)
	door = _anim_prop("SM_Rocca_PortaChiave", cell_pos(Vector2i(3, 4), u) + Vector3(2.0, 0, 0), -PI / 2)
	door_ap = Traps.player_of(door)
	door_ap.get_animation("Door_Locked_Idle").loop_mode = Animation.LOOP_LINEAR
	# La chiave è nel modello per l'animazione di sblocco: compare solo quando il giocatore la usa.
	door.find_child("Door_Key").visible = false
	door_body = StaticBody3D.new()
	var dcs := CollisionShape3D.new()
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(2.7, 2.6, 0.3)
	dcs.shape = dbox
	dcs.position = Vector3(0, 1.3, 0)
	door_body.add_child(dcs)
	door.add_child(door_body)
	# altare dell'esca + gabbia del boss + campane
	var alt := _anim_prop("SM_Rocca_Altare", OCT_C)
	altar_ap = Traps.player_of(alt)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.8, 1.5, 1.2)
	cs.shape = bx
	cs.position = Vector3(0, 0.75, 0)
	sb.add_child(cs)
	# La pedana a gradini attorno all'altare: i piedi non ci entrano dentro.
	var step := CollisionShape3D.new()
	var step_box := BoxShape3D.new()
	step_box.size = Vector3(2.6, 0.22, 2.6)
	step.shape = step_box
	step.position = Vector3(0, 0.11, 0)
	sb.add_child(step)
	alt.add_child(sb)
	cage = _anim_prop("SM_Rocca_GabbiaBoss", OCT_C + Vector3(0, 0, -7.0))
	cage_ap = Traps.player_of(cage)
	cage_ap.get_animation("Cage_Sway").loop_mode = Animation.LOOP_LINEAR
	for x in [-9.0, 9.0]:
		var b := _anim_prop("SM_Rocca_Campana", OCT_C + Vector3(x, 0, -2.0), PI / 2)
		_world_box(b)
		var ba := Traps.player_of(b)
		ba.get_animation("Bell_Ring").loop_mode = Animation.LOOP_LINEAR
		bells.append(ba)
	# trappole
	for i in 2:                                                          # corridoio delle lame: due pendoli
		var pd := Traps.Pendulum.new()
		pd.position = cell_pos(Vector2i(0, -6 - i * 2))
		add_child(pd)
		pd.setup(self, i * 1.2)
		pendulums.append(pd)
	for row in [[Vector2i(0, -7), 0.0], [Vector2i(0, -9), 1.5], [Vector2i(-4, -2), 0.7], [Vector2i(-6, -2), 2.2]]:
		var sp := Traps.Spikes.new()
		sp.position = cell_pos(row[0])
		add_child(sp)
		sp.setup(self, row[1])
		spikes.append(sp)
	var at := Traps.ArrowTrap.new()
	add_child(at)
	at.setup(self, 0, cell_pos(Vector2i(0, -10)) + Vector3(-1.75, 0, 0), PI / 2, cell_pos(Vector2i(0, -10)) + Vector3(0, 0, 0.6))
	arrows.append(at)
	var at2 := Traps.ArrowTrap.new()
	add_child(at2)
	at2.setup(self, 1, cell_pos(Vector2i(6, -4)) + Vector3(0, 0, 1.75), PI, cell_pos(Vector2i(6, -4)) + Vector3(0, 0, -0.6))
	arrows.append(at2)
	for row in [[Vector2i(4, 0), W, 0.0], [Vector2i(4, -3), E, 2.0], [Vector2i(4, -5), W, 1.0]]:
		var f := Traps.FireJet.new()
		var d: Vector2i = row[1]
		f.position = cell_pos(row[0]) + Vector3(d.x, 0, d.y) * 1.75
		f.rotation.y = _rot(d)                                          # la bocca (+Z locale) guarda dentro il corridoio
		add_child(f)
		f.setup(self, row[2])
		fires.append(f)
	for row in [[Vector2i(-6, 1), S], [Vector2i(4, -2), E]]:
		var tw := Traps.Tripwire.new()
		var d: Vector2i = row[1]
		tw.position = cell_pos(row[0]) + Vector3(d.x, 0, d.y) * 2.0
		tw.rotation.y = 0.0 if d == S or d == N else PI / 2
		add_child(tw)
		tw.setup(self, wires.size())
		wires.append(tw)
	# casse da rompere (nascondono i forzieri) e forzieri
	var crate_spots := [[Vector2i(2, 4), Vector3(-0.2, 0, 1.3)], [Vector2i(2, 4), Vector3(-1.3, 0, 0.1)], [Vector2i(2, 4), Vector3(-0.2, 1.0, 1.3)],
		[Vector2i(3, 4), Vector3(0.5, 0, 1.2)], [Vector2i(-7, 3), Vector3(-1.0, 0, 0.8)], [Vector2i(-6, 3), Vector3(1.2, 0, 1.2)],
		[Vector2i(6, -2), Vector3(-1.0, 0, -1.2)], [Vector2i(5, -1), Vector3(-1.0, 0, 1.0)], [Vector2i(-6, -6), Vector3(-0.8, 0, -0.8)],
		[Vector2i(-6, -6), Vector3(0.4, 0, -1.2)], [Vector2i(7, -5), Vector3(1.2, 0, 0.8)]]
	for row in crate_spots:
		var cr := Props.Crate.new()
		cr.position = cell_pos(row[0]) + row[1]
		cr.rotation.y = _rng.randf_range(-0.3, 0.3)
		add_child(cr)
		cr.setup(self, crates.size())
		crates.append(cr)
	var chest_spots := [[Vector2i(2, 4), Vector3(-1.3, 0, 1.35), PI / 2, ["bende", "bende", "monete"]],
		[Vector2i(-7, 3), Vector3(-1.4, 0, 1.3), PI / 2, ["bende", "pozione"]],
		[Vector2i(6, -2), Vector3(-0.6, 0, -1.4), 0.0, ["monete", "monete", "pozione"]],
		[Vector2i(-6, -6), Vector3(-1.3, 0, -1.4), PI / 2, ["bende", "monete"]],
		[Vector2i(7, -5), Vector3(1.4, 0, 1.2), -PI / 2, ["bende", "pozione"]],
		[Vector2i(0, 0), Vector3.ZERO, 0.0, ["bende", "bende", "pozione", "monete", "monete"]]]      # ricompensa del boss
	for row in chest_spots:
		var ch := Props.Chest.new()
		ch.position = cell_pos(row[0]) + row[1]
		ch.rotation.y = row[2]
		if chests.size() == 5:
			ch.position = OCT_C + Vector3(0, 0, 3.4)
		add_child(ch)
		ch.setup(self, chests.size(), row[3])
		chests.append(ch)
	_pickup("chiave", cell_pos(Vector2i(-4, 3), u) + Vector3(0.6, 0.85, -1.2))
	_pickup("carne", cell_pos(Vector2i(6, -5)) + Vector3(0, 0.84, 0.6))
	_cripta_hatch()
	# uscite
	exits = [[cell_pos(Vector2i(1, 7), u) + Vector3(0, 0, 1.2), ""], [cell_pos(Vector2i(0, -19)), "boss"]]
	_label3d("USCITA · [E] superficie", cell_pos(Vector2i(1, 7), u) + Vector3(0, 2.3, 1.2), Color("ffd27a"))
	_label3d("USCITA DEL CARCERIERE · [E]", cell_pos(Vector2i(0, -19), 2.3), Color("ffd27a")).set_meta("needs", "boss")
	_label3d("[E] LUCCHETTO", door.position + Vector3(-0.5, 1.9, 0), Color("ff8a5a")).set_meta("door", true)
	_label3d("[E] ALTARE · appendi l'esca", OCT_C + Vector3(0, 2.4, 1.0), Color("ff5a4a")).set_meta("altar", true)


func _pickup(kind: String, pos: Vector3) -> Node3D:
	var p := Props.Pickup.new()
	p.position = pos
	add_child(p)
	p.setup(self, pickups.size(), kind)
	pickups.append(p)
	return p


## Scatola di collisione grande quanto la forma vera (misurata nel mondo), per i pezzi animati che non ne hanno una.
func _world_box(n: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first: return
	_solid(self, to_local(box.get_center()), box.size)


func _label3d(text: String, pos: Vector3, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.004
	l.outline_size = 10
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)
	return l


func _surface_entrance() -> void:
	var at: Vector3 = RoadNet.SITES["dungeon"] + SITE_OFFSET
	var ground: float = Terrain.ground_height(at.x, at.z)
	var b: Node3D = load(PROPS + "SM_Rocca_Ingresso.glb").instantiate()
	b.name = "RoccaIngresso"
	world.add_child(b)
	b.global_position = Vector3(at.x, ground, at.z)
	b.rotation.y = ENTRANCE_YAW
	entrance_node = b
	entrance_ap = Traps.player_of(b)
	# Ante sempre aperte: si entra quando si vuole.
	entrance_ap.play("Gate_Open")
	entrance_ap.seek(entrance_ap.current_animation_length, true)
	entrance_ap.pause()
	_open_floor(b)
	_stairwell(b)
	# Punto di ritorno in superficie: fuori dal portone, sul selciato.
	entrance_pos = b.to_global(Vector3(0, 0.3, 4.6))
	var lab := Label3D.new()
	lab.text = Localization.t("LA ROCCA MALEDETTA")
	lab.font_size = 48; lab.pixel_size = 0.005; lab.outline_size = 12; lab.modulate = Color("ffcf4a")
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, 3.5, 3.0)
	b.add_child(lab)
	_guide(b)
	_surface_ruins(b)
	_site_garden(b)
	_site_forest(b)


## Il modello della torre ha un pavimento pieno e un pannello scuro dietro il portone: si tolgono quei triangoli, sennò coprono la scala.
func _open_floor(tower: Node3D) -> void:
	for node in tower.find_children("SM_Rocca_Ingresso*", "MeshInstance3D", true, false) + ([tower] if tower is MeshInstance3D else []):
		var mi := node as MeshInstance3D
		var old: Mesh = mi.mesh
		var fresh := ArrayMesh.new()
		var removed := 0
		for surface in old.get_surface_count():
			var arrays: Array = old.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				indices.resize(verts.size())
				for i in verts.size(): indices[i] = i
			var kept := PackedInt32Array()
			var to_tower: Transform3D = tower.global_transform.affine_inverse() * mi.global_transform
			for t in range(0, indices.size(), 3):
				var a: Vector3 = to_tower * verts[indices[t]]
				var b: Vector3 = to_tower * verts[indices[t + 1]]
				var c: Vector3 = to_tower * verts[indices[t + 2]]
				var mid := (a + b + c) / 3.0
				var flat: bool = maxf(a.y, maxf(b.y, c.y)) < 0.4 and absf((b - a).cross(c - a).normalized().y) > 0.9
				var normal: Vector3 = (b - a).cross(c - a).normalized()
				var door_plane: bool = absf(normal.z) > 0.9 and absf(mid.x) < 1.3 and mid.y < 4.4 and mid.z > 0.5 and mid.z < 2.5
				if door_plane or (flat and absf(mid.x) < 2.7 and mid.z > -2.6 and mid.z < 2.75):
					removed += 1
					continue
				kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
			arrays[Mesh.ARRAY_INDEX] = kept
			fresh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			fresh.surface_set_material(surface, old.surface_get_material(surface))
		mi.mesh = fresh
		print("Torre: tolti %d triangoli tra pavimento e pannello del portone" % removed)


## Muratura vera: blocchi sfalsati con la malta in mezzo, ognuno con la sua tonalità. Proiettata dai lati, va bene su ogni pezzo.
func _masonry(tint: Color) -> StandardMaterial3D:
	if _stone_mats.has(tint): return _stone_mats[tint]
	if _brick_tex == null:
		var img := Image.create(512, 512, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5150
		var shade := {}
		for y in 512:
			var row := y / 64
			for x in 512:
				var px := (x + (64 if row % 2 == 1 else 0)) % 512
				var col := px / 128
				var key := Vector2i(col, row)
				if not shade.has(key): shade[key] = rng.randf_range(0.72, 1.0)
				var mortar: bool = y % 64 < 5 or px % 128 < 5
				var v: float = 0.5 if mortar else float(shade[key]) + rng.randf_range(-0.05, 0.05)
				img.set_pixel(x, y, Color(v, v * 0.98, v * 0.93))
		img.generate_mipmaps()
		_brick_tex = ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _brick_tex
	mat.albedo_color = tint
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.5
	mat.roughness = 0.95
	# La nebbia del bosco non scende sottoterra.
	mat.disable_fog = true
	_stone_mats[tint] = mat
	return mat


## Blocco di muratura nello spazio della torre (y 0 = pavimento della torre, a livello del terreno).
func _block(parent: Node3D, center: Vector3, size: Vector3, tint := C_STONE, solid := true) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _masonry(tint)
	mi.mesh = mesh
	parent.add_child(mi)
	mi.position = center
	if solid: _solid(parent, center, size)


func _solid(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	body.add_child(shape)
	parent.add_child(body)
	body.position = center


func _flame(parent: Node3D, at: Vector3, energy: float, reach: float) -> void:
	var fire := OmniLight3D.new()
	fire.light_color = Color("ffb066"); fire.omni_range = reach; fire.light_energy = energy
	parent.add_child(fire)
	fire.position = at
	fire.set_meta("base", energy)
	torches.append(fire)


## Dentro la torre il pavimento si apre: una scala larga e illuminata scende sotto terra fino a un arco. Chi passa l'arco è nella Rocca.
func _stairwell(tower: Node3D) -> void:
	_ground_patch(tower)
	var bottom_z: float = STAIR_TOP_Z - float(STAIR_STEPS) * STAIR_RUN
	var depth: float = float(STAIR_STEPS) * STAIR_RISE
	# Pavimento della torre attorno alla bocca della scala, e soglia fuori dal portone.
	_block(tower, Vector3(0, -0.03, 2.3), Vector3(5.2, 0.12, 0.8), C_FLOOR)
	_block(tower, Vector3(0, -0.03, 3.0), Vector3(3.0, 0.12, 0.7), C_FLOOR)
	# Soffitto pieno: niente bande scure del modello sopra la testa.
	_block(tower, Vector3(0, 3.45, 0), Vector3(2.7, 0.14, 4.7), C_FLOOR, false)
	for beam in [-1.6, 0.0, 1.6]:
		_block(tower, Vector3(0, 3.33, beam), Vector3(2.7, 0.14, 0.26), C_NOSE, false)
	for s in [-1.0, 1.0]:
		_block(tower, Vector3(s * 1.95, -0.03, -0.35), Vector3(1.1, 0.12, 4.5), C_FLOOR)
		# Cornice dove la parete della torre incontra quella della scala: nessuno spazio tra le due.
		_block(tower, Vector3(s * 1.27, -0.1, -0.2), Vector3(0.22, 0.2, 4.2), C_NOSE, false)
		# Pareti interne della torre: la muratura continua da dentro, senza stacchi con la scala.
		_block(tower, Vector3(s * 1.24, 2.7, -0.1), Vector3(0.1, 5.8, 4.4), C_STONE)
		_solid(tower, Vector3(s * 2.5, 3.0, 0), Vector3(0.3, 6.0, 5.0))
		_solid(tower, Vector3(s * 1.9, 1.5, 2.35), Vector3(1.3, 3.0, 0.3))
		# Pareti della scala fino al fondo del corridoio.
		_block(tower, Vector3(s * 1.5, -(depth + 0.4) * 0.5, -3.9), Vector3(0.3, depth + 0.4, 10.2), C_STONE)
		var torch := _place("P_TorchWall", Vector3.ZERO, 0.0, tower)
		if torch:
			torch.position = Vector3(s * 1.32, -1.5, -0.6)
			torch.rotation.y = -PI / 2 * s
			_no_fog(torch, Color.WHITE)
		var low := _place("P_TorchWall", Vector3.ZERO, 0.0, tower)
		if low:
			low.position = Vector3(s * 1.32, -2.9, -4.5)
			low.rotation.y = -PI / 2 * s
			_no_fog(low, Color.WHITE)
	_block(tower, Vector3(0, 2.75, -2.27), Vector3(4.8, 6.0, 0.1), C_STONE, false)
	_block(tower, Vector3(0, -0.2, -2.34), Vector3(2.7, 0.2, 0.3), C_NOSE, false)
	_solid(tower, Vector3(0, 3.0, -2.45), Vector3(5.0, 6.0, 0.3))
	_solid(tower, Vector3(0, 4.6, 2.3), Vector3(5.0, 2.8, 0.4))
	# Dietro il primo gradino, soffitto del tratto sotto terra, pianerottolo in fondo e muro finale.
	_block(tower, Vector3(0, -(depth + 0.4) * 0.5, STAIR_TOP_Z + 0.15), Vector3(2.7, depth + 0.4, 0.3), C_STONE)
	_block(tower, Vector3(0, -0.15, -5.7), Vector3(3.3, 0.2, 6.6), C_STONE)
	_block(tower, Vector3(0, -depth - 0.1, -6.15), Vector3(2.7, 0.2, 5.7), C_FLOOR)
	_block(tower, Vector3(0, -(depth + 0.4) * 0.5, -9.0), Vector3(2.7, depth + 0.4, 0.3), C_STONE)
	# I gradini, col bordo più chiaro così si contano a colpo d'occhio.
	for i in STAIR_STEPS:
		var top: float = -float(i) * STAIR_RISE - STAIR_RISE
		var z: float = STAIR_TOP_Z - (float(i) + 0.5) * STAIR_RUN
		var height: float = depth + 0.2 + top
		_block(tower, Vector3(0, top - height * 0.5, z), Vector3(2.7, height, STAIR_RUN + 0.01), C_FLOOR, false)
		_block(tower, Vector3(0, top - 0.03, z - STAIR_RUN * 0.5 + 0.04), Vector3(2.7, 0.08, 0.1), C_NOSE, false)
	# Si cammina su una rampa invisibile appoggiata agli spigoli dei gradini.
	var high := Vector3(0, 0.03, STAIR_TOP_Z)
	var low_end := Vector3(0, -depth, bottom_z)
	var dir: Vector3 = (low_end - high).normalized()
	var up: Vector3 = dir.cross(Vector3.UP.cross(dir)).normalized()
	var ramp_length: float = high.distance_to(low_end) + 0.5
	var ramp := StaticBody3D.new()
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(2.7, 0.2, ramp_length)
	ramp_shape.shape = ramp_box
	ramp.add_child(ramp_shape)
	tower.add_child(ramp)
	ramp.transform = Transform3D(Basis.looking_at(dir, up), high + dir * ramp_length * 0.5 - up * 0.1)
	_stair_arch(tower, -depth, -5.9)
	var banner := _place("P_BannerRed", Vector3.ZERO, 0.0, tower)
	if banner:
		banner.position = Vector3(0, -depth + 0.9, -8.8)
		_no_fog(banner, Color.WHITE)
	var last := _place("P_TorchWall", Vector3.ZERO, 0.0, tower)
	if last:
		last.position = Vector3(1.28, -depth + 1.6, -8.0)
		last.rotation.y = -PI / 2
		_no_fog(last, Color.WHITE)
	_flame(tower, Vector3(0, 2.9, 0.4), 1.8, 8.0)
	_flame(tower, Vector3(0, -0.9, -0.6), 1.6, 7.0)
	_flame(tower, Vector3(0, -2.4, -4.4), 1.7, 6.0)
	_flame(tower, Vector3(0, -depth + 2.0, -7.4), 2.0, 5.0)
	# Chi passa sotto l'arco entra nella Rocca, senza premere niente.
	var door := Area3D.new()
	door.name = "RoccaPorta"
	door.collision_mask = 0xFFFFFFFF
	var ds := CollisionShape3D.new()
	var db := BoxShape3D.new()
	db.size = Vector3(2.6, 2.6, 0.8)
	ds.shape = db
	door.add_child(ds)
	tower.add_child(door)
	door.position = Vector3(0, -depth + 1.3, -6.1)
	door.body_entered.connect(_door_entered)


## L'arco in fondo alla scala: muratura vera, largo 2,3 m e alto 3,1. Oltre si vede il corridoio che continua, illuminato.
func _stair_arch(tower: Node3D, floor_y: float, z: float) -> void:
	const OPEN := 1.15
	const SPRING := 1.95          # da questa altezza parte la curva
	const THICK := 0.5
	var ceiling: float = -0.05
	var side: float = 1.35
	for s in [-1.0, 1.0]:
		# Pilastri ai lati dell'apertura.
		_block(tower, Vector3(s * (OPEN + side) * 0.5, floor_y + SPRING * 0.5, z), Vector3(side - OPEN, SPRING, THICK), C_FLOOR)
		# Riempimento a file di mattoni tra la curva e la parete.
		var rows := 7
		for r in rows:
			var y0: float = float(r) / float(rows) * OPEN
			var y1: float = float(r + 1) / float(rows) * OPEN
			var inner: float = sqrt(maxf(0.0, OPEN * OPEN - y1 * y1)) if r < rows - 1 else 0.0
			inner = maxf(inner, 0.0)
			_block(tower, Vector3(s * (inner + side) * 0.5, floor_y + SPRING + (y0 + y1) * 0.5, z), Vector3(side - inner, y1 - y0, THICK), C_STONE)
	# Sopra la curva il muro arriva fino al soffitto: nessuna striscia vuota.
	var top: float = floor_y + SPRING + OPEN
	_block(tower, Vector3(0, (top + ceiling) * 0.5, z), Vector3(side * 2.0, ceiling - top, THICK), C_STONE)
	# La ghiera di conci chiari attorno all'apertura.
	var stones := 9
	for i in stones:
		var angle: float = PI * (float(i) + 0.5) / float(stones)
		var stone := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(PI * OPEN / float(stones) + 0.05, 0.26, THICK + 0.12)
		mesh.material = _masonry(C_NOSE)
		stone.mesh = mesh
		tower.add_child(stone)
		stone.position = Vector3(cos(angle) * (OPEN + 0.1), floor_y + SPRING + sin(angle) * (OPEN + 0.1), z)
		stone.rotation.z = angle - PI / 2.0
	for s in [-1.0, 1.0]:
		_block(tower, Vector3(s * (OPEN + 0.1), floor_y + SPRING * 0.5, z), Vector3(0.26, SPRING, THICK + 0.12), C_NOSE, false)


## Sotto terra non c'è nebbia: i pezzi del kit vanno schiariti dal velo del bosco, e volendo tinti.
func _no_fog(node: Node, tint: Color) -> void:
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D: meshes.append(node)
	for m in meshes:
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var source: Material = mi.get_active_material(i)
			if source == null: continue
			var clear: Material = source.duplicate()
			clear.set("disable_fog", true)
			if clear is BaseMaterial3D: (clear as BaseMaterial3D).albedo_color = (clear as BaseMaterial3D).albedo_color * tint
			mi.set_surface_override_material(i, clear)


## Il terreno ha perso le celle della griglia in cui si apre la scala (RoadNet.TERRAIN_HOLE): qui si richiude tutto tranne la bocca.
func _ground_patch(tower: Node3D) -> void:
	var c: Rect2 = RoadNet.TERRAIN_HOLE
	var a := tower.to_global(Vector3(-1.36, 0, STAIR_TOP_Z))
	var b := tower.to_global(Vector3(1.36, 0, -2.6))
	var hx := Vector2(minf(a.x, b.x), maxf(a.x, b.x))
	var hz := Vector2(minf(a.z, b.z), maxf(a.z, b.z))
	var y: float = tower.global_position.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in [Rect2(c.position.x, c.position.y, hx.x - c.position.x, c.size.y), Rect2(hx.y, c.position.y, c.end.x - hx.y, c.size.y),
			Rect2(hx.x, c.position.y, hx.y - hx.x, hz.x - c.position.y), Rect2(hx.x, hz.y, hx.y - hx.x, c.end.y - hz.y)]:
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			st.set_normal(Vector3.UP)
			st.set_color(Color("4a6238"))
			st.add_vertex(Vector3(r.position.x + r.size.x * corner.x, y, r.position.y + r.size.y * corner.y))
	var patch := MeshInstance3D.new()
	patch.name = "RoccaTerrenoAttorno"
	patch.mesh = st.commit()
	patch.material_override = world.terrain.ground_material
	world.add_child(patch)
	patch.create_trimesh_collision()


func _door_entered(body: Node3D) -> void:
	if not host or not world.actors.values().has(body): return
	_do(body, "enter")


## Un elemento naturale nello spazio della torre, posato sul terreno.
func _plant(parent: Node3D, tower: Node3D, asset: String, x: float, z: float, yaw: float, size: float, solid := 0.0) -> Node3D:
	var g := tower.to_global(Vector3(x, 0, z))
	var node: Node3D = load("res://art/nature/%s.gltf" % asset).instantiate()
	parent.add_child(node)
	node.global_position = Vector3(g.x, Terrain.ground_height(g.x, g.z), g.z)
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size
	if solid > 0.0:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = solid / size
		cyl.height = 3.0 / size
		shape.shape = cyl
		shape.position.y = 1.5 / size
		body.add_child(shape)
		node.add_child(body)
	return node


## Il posticino davanti alla torre: selciato fino al portone, aiuole, due lanterne, muretto a secco, edera e lucciole.
func _site_garden(tower: Node3D) -> void:
	var garden := Node3D.new()
	garden.name = "RoccaGiardino"
	world.add_child(garden)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2231
	# Selciato: pietre piatte che seguono una curva dolce dalla pista alla soglia.
	var z := 3.0
	while z < 19.0:
		var x := sin(z * 0.34) * 0.5
		_plant(garden, tower, "RockPath_Square_Wide", x, z, rng.randf_range(-0.12, 0.12), 1.0)
		if rng.randf() < 0.75: _plant(garden, tower, "RockPath_Round_Small_%d" % rng.randi_range(1, 3), x + rng.randf_range(1.2, 1.9) * (1.0 if rng.randf() < 0.5 else -1.0), z + rng.randf_range(-0.5, 0.5), rng.randf() * TAU, 1.0)
		z += 1.45
	# Due pilastrini con la lanterna ai lati del portone.
	for s in [-1.0, 1.0]:
		_block(tower, Vector3(s * 2.1, 0.65, 4.0), Vector3(0.5, 1.3, 0.5), C_STONE)
		_block(tower, Vector3(s * 2.1, 1.34, 4.0), Vector3(0.62, 0.1, 0.62), C_FLOOR, false)
		var glass := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.16, 0.24, 0.16)
		var lit := StandardMaterial3D.new()
		lit.albedo_color = Color("ffcf7a")
		lit.emission_enabled = true
		lit.emission = Color("ffb35c")
		lit.emission_energy_multiplier = 1.2
		box.material = lit
		glass.mesh = box
		tower.add_child(glass)
		glass.position = Vector3(s * 2.1, 1.51, 4.0)
		_block(tower, Vector3(s * 2.1, 1.67, 4.0), Vector3(0.26, 0.05, 0.26), C_STONE, false)
		_flame(tower, Vector3(s * 2.1, 1.8, 4.0), 1.5, 7.0)
	# Aiuole contro la torre, ai lati del portone.
	for s in [-1.0, 1.0]:
		for i in 7:
			var fx: float = s * rng.randf_range(2.8, 5.6)
			var fz: float = rng.randf_range(2.9, 4.4)
			var asset: String = ["Bush_Common_Flowers", "Flower_3_Group", "Flower_4_Group", "Plant_1_Big", "Plant_7_Big", "Fern_1", "Flower_4_Group"][i]
			_plant(garden, tower, asset, fx, fz, rng.randf() * TAU, rng.randf_range(0.4, 0.6))
	# Il cortile: fiori sparsi, erba alta, qualche sasso. Il selciato e il campo di Bruno restano liberi.
	for i in 90:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 9.6
		var fx := cos(a) * r
		var fz := 7.5 + sin(a) * r
		if fz < 3.0 or absf(fx - sin(fz * 0.34) * 0.5) < 1.7 or Vector2(fx, fz).distance_to(Vector2(8.0, 8.0)) < 3.4 or Vector2(fx, fz).distance_to(Vector2(5.4, 6.4)) < 1.4: continue
		var asset: String = ["Flower_3_Group", "Flower_4_Group", "Grass_Common_Tall", "Clover_1", "Flower_3_Single", "Grass_Wispy_Tall", "Flower_4_Single", "Clover_2", "Plant_7", "Pebble_Round_2"][i % 10]
		_plant(garden, tower, asset, fx, fz, rng.randf() * TAU, rng.randf_range(0.35, 0.6))
	# Muretto a secco attorno al cortile, aperto dove arriva il selciato.
	for i in 62:
		var a := float(i) / 62.0 * TAU
		var wx := cos(a) * 11.0
		var wz := 7.5 + sin(a) * 11.0
		if wz < -1.0 or (absf(wx) < 2.8 and wz > 12.0): continue
		_plant(garden, tower, "Rock_Medium_%d" % rng.randi_range(1, 3), wx, wz, rng.randf() * TAU, rng.randf_range(0.2, 0.3), 0.0)
	# Due grandi pini che incorniciano la torre.
	_plant(garden, tower, "Pine_2", -9.5, -6.0, 0.4, 1.8, 0.45)
	_plant(garden, tower, "Pine_4", 9.8, -6.8, 1.9, 1.7, 0.45)
	# Edera sui muri della torre.
	for row in [[Vector3(-1.95, 1.6, 2.72), 0.0], [Vector3(1.9, 2.8, 2.72), 0.0], [Vector3(-1.7, 3.8, 2.72), 0.0], [Vector3(2.72, 1.8, 1.0), PI / 2], [Vector3(-2.72, 2.4, 0.4), -PI / 2]]:
		var ivy := _place("P_Ivy", Vector3.ZERO, 0.0, tower)
		if ivy:
			ivy.position = row[0]
			ivy.rotation.y = row[1]
	# Lucciole sul cortile.
	var flies := CPUParticles3D.new()
	flies.amount = 36
	flies.lifetime = 5.0
	flies.preprocess = 5.0
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(9.0, 0.9, 7.0)
	flies.direction = Vector3.UP
	flies.spread = 180.0
	flies.gravity = Vector3.ZERO
	flies.initial_velocity_min = 0.1
	flies.initial_velocity_max = 0.35
	var dot := SphereMesh.new()
	dot.radius = 0.028
	dot.height = 0.056
	dot.radial_segments = 6
	dot.rings = 3
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("fff0a0")
	dot.material = glow
	flies.mesh = dot
	tower.add_child(flies)
	flies.position = Vector3(0, 1.1, 8.0)


## Attorno al cortile il bosco: pini, cespugli, felci e sassi. Il selciato resta libero.
func _site_forest(tower: Node3D) -> void:
	var site: Vector3 = RoadNet.SITES["dungeon"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7719
	var wood := Node3D.new()
	wood.name = "BoscoRocca"
	world.add_child(wood)
	for i in 150:
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(16.0, 62.0) if i < 70 else rng.randf_range(12.0, 44.0)
		var p := Vector2(site.x, site.z) + Vector2(cos(angle), sin(angle)) * radius
		if RoadNet.distance(p) < (6.0 if i < 70 else 3.2): continue
		var local := tower.to_local(Vector3(p.x, tower.global_position.y, p.y))
		if Vector2(local.x, local.z).distance_to(Vector2(0, 7.5)) < 12.5: continue
		if local.z > -9.0 and absf(local.x) < 7.0 and local.z < 3.0: continue
		var asset: String
		var size := 1.0
		if i < 70:
			asset = "Pine_%d" % rng.randi_range(1, 5)
			size = rng.randf_range(0.9, 1.5)
		else:
			asset = ["Plant_1_Big", "Fern_1", "Plant_7_Big", "Clover_1", "Mushroom_Common", "Rock_Medium_1"][i % 6]
			size = rng.randf_range(0.7, 1.3) if asset != "Rock_Medium_1" else rng.randf_range(0.3, 0.6)
		var node: Node3D = load("res://art/nature/%s.gltf" % asset).instantiate()
		wood.add_child(node)
		node.global_position = Vector3(p.x, Terrain.ground_height(p.x, p.y), p.y)
		node.rotation.y = rng.randf() * TAU
		node.scale = Vector3.ONE * size
		if i < 70:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.4
			cyl.height = 4.0
			shape.shape = cyl
			shape.position.y = 2.0
			body.add_child(shape)
			node.add_child(body)


func _ui_build() -> void:
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
	_bar_label.visible = false
	_bar.visible = false
	_objective = Label.new()
	_objective.position = Vector2(24, 120)
	_objective.add_theme_font_size_override("font_size", 20)
	_objective.add_theme_color_override("font_color", Color("ffe0a8"))
	_objective.add_theme_color_override("font_outline_color", Color.BLACK)
	_objective.add_theme_constant_override("outline_size", 6)
	_ui.add_child(_objective)
	_objective.visible = false


func _bake_navigation() -> void:
	nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# Archi larghi 1,84 m (1,46 m a 1,7 m d'altezza): con raggio 0,5 e altezza 1,75 la navmesh si spezzava in ogni varco.
	nm.agent_radius = 0.25
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.5
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nav.navigation_mesh = nm
	add_child(nav)
	for c in get_children():
		if c != nav and c is Node3D and not (c is Light3D) and not (c is Label3D) and not (c is CanvasLayer):
			c.reparent(nav)
	nav.bake_navigation_mesh(true)


# =================================================================== STATO / RESET
func reset() -> void:
	if not rooms.has("arena"):
		rooms["arena"] = {"title": "ARENA DEL CARCERIERE", "rect": Rect2i(), "level": 0, "tiers": 2, "kind": "tall", "state": "idle", "enemies": []}
	for id in rooms:
		for e in rooms[id].enemies:
			if is_instance_valid(e):
				e.queue_free()
		rooms[id].enemies.clear()
		rooms[id].state = "idle"
	has_key = false
	has_bait = false
	door_open = false
	bait_placed = false
	boss = null
	boss_dead = false
	boss_phase = 0
	if door_ap:
		door_ap.play("Door_Close")
		door_ap.seek(door_ap.current_animation_length, true)
		door_ap.play("Door_Locked_Idle")
		door.find_child("Door_Key").visible = false
		door_body.process_mode = Node.PROCESS_MODE_INHERIT
	cripta_done = false
	for g in gates:
		set_gate(g, g != "arena_sud")
	for t in wires: t.reset()
	for c in crates: c.reset()
	for c in chests: c.reset()
	if chests.size() > 5:
		_boss_chest(false)
	for p in pickups:
		if p.kind in ["bende", "pozione", "monete"]:
			p.queue_free()
		else:
			p.reset()
	pickups = pickups.filter(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion())
	if altar_ap:
		_rest(altar_ap, "Altar_Place_Bait")
		cage_ap.play("Cage_Sway")
		cage.visible = true
		for b in bells: _rest(b, "Bell_Ring")
		_set_rite(false)


func _rest(ap: AnimationPlayer, clip: String) -> void:
	ap.play(clip)
	ap.seek(0.0, true)
	ap.pause()


func area_of(pos: Vector3) -> String:
	var l := to_local(pos)
	if l.y < -3 or l.y > 13:
		return ""
	if Vector2(l.x - OCT_C.x, l.z - OCT_C.z).length() < OCT_A + 0.2 and l.y < 10:
		return "arena"
	if Vector2i(roundi(l.x / CELL), roundi(l.z / CELL)) == TOWER:
		return "torre"
	var lv := 1 if l.y > UP - 0.6 else 0
	return cells.get(Vector3i(roundi(l.x / CELL), roundi(l.z / CELL), lv), "")


func objective() -> String:
	if boss_dead:
		return "Il Carceriere è morto. Esci dalla porta nord dell'arena."
	if bait_placed:
		return "Uccidi IL CARCERIERE."
	if has_bait and not cripta_done:
		return "La saracinesca dell'arena è bloccata da sotto: scendi dalla BOTOLA in fondo al corridoio delle lame e ripulisci la Cripta."
	if has_bait:
		return "Appendi la CARNE MALEDETTA all'altare al centro dell'arena (oltre il corridoio delle lame)."
	if door_open:
		return "Scendi la torre e trova la CARNE MALEDETTA nel laboratorio dell'alchimista (corridoio dei draghi)."
	if has_key:
		return "Apri il LUCCHETTO della porta della torre (est della sala grande)."
	return "Trova la CHIAVE D'ORO nell'armeria (ovest della sala grande)."


# =================================================================== INTERAZIONE [E]
func request_use(actor: CharacterBody3D) -> bool:
	if not is_instance_valid(actor):
		return false
	var p := actor.global_position
	var action := ""
	var best := INF
	if is_instance_valid(guide) and actor == world.player and p.distance_to(guide_pos) < 2.6:
		talk()
		return true
	var cands := []
	for i in exits.size():
		if exits[i][1] == "boss" and not boss_dead:
			continue
		cands.append([to_global(exits[i][0]), "exit:%d" % i, 2.6])
	for i in chests.size():
		if not chests[i].opened and chests[i].visible:
			cands.append([chests[i].global_position, "chest:%d" % i, 2.0])
	for i in pickups.size():
		if is_instance_valid(pickups[i]) and not pickups[i].taken:
			cands.append([pickups[i].global_position, "pick:%d" % i, 1.9])
	cands.append([door.global_position + Vector3(0, 0.3, 0), "door", 2.3])
	if not cripta_done and cripta:
		cands.append([to_global(cell_pos(HATCH_CELL) + Vector3(0, 0, -1.1)), "cripta", 2.2])
	cands.append([to_global(OCT_C), "altar", 3.0])
	for c in cands:
		var d: float = p.distance_to(c[0])
		if d < c[2] and d < best:
			best = d
			action = c[1]
	if action == "":
		return false
	_local_anim(actor, action)
	if host:
		_do(actor, action)
	else:
		_ask.rpc_id(1, action)
	return true


func _local_anim(actor: Node3D, action: String) -> void:
	if actor != world.player:
		return
	var clip := ""
	var item := ""
	if action.begins_with("pick:") or action.begins_with("chest:"):
		clip = "Interact_Pickup"
	elif action == "door" and has_key and not door_open:
		clip = "Interact_UseKey"
		item = "chiave"
	elif action == "altar" and has_bait and not bait_placed:
		clip = "Interact_PlaceBait"
		item = "carne"
	if clip == "":
		return
	for c in world.player.rig.camera.get_children():
		if c.has_method("play_interact"):
			c.play_interact(clip, item)


@rpc("any_peer", "call_remote", "reliable")
func _ask(action: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if world.actors.has(peer):
		_do(world.actors[peer], action)


func _do(actor: CharacterBody3D, action: String) -> void:
	if action == "enter":
		_teleport(actor, to_global(cell_pos(Vector2i(0, 7), UP) + Vector3(1.0, 0.3, 0.4)))
		world.announce(Localization.t("LA ROCCA MALEDETTA · ") + Localization.t(objective()), 6)
	elif action.begins_with("exit:"):
		_teleport(actor, entrance_pos + Vector3.UP * 0.3)
	elif action == "cripta":
		cripta.enter(actor)
	elif action.begins_with("chest:"):
		open_chest(int(action.substr(6)))
	elif action.begins_with("pick:"):
		take_pickup(int(action.substr(5)), actor)
	elif action.begins_with("crate:"):
		crates[int(action.substr(6))].smash()
	elif action == "door":
		if door_open:
			return
		if not has_key:
			world.announce("È chiusa col lucchetto. Serve la chiave d'oro (armeria).", 3)
			return
		open_door()
	elif action == "altar":
		if bait_placed:
			return
		if not has_bait:
			world.announce("Un altare insanguinato con un gancio vuoto. Qui va appesa l'esca.", 3)
			return
		place_bait()
	_push_state()


func _teleport(actor: CharacterBody3D, to: Vector3) -> void:
	actor.global_position = to
	actor.velocity = Vector3.ZERO
	if actor.has_method("set_crouched"):
		actor.set_crouched(false, true)


func open_chest(i: int) -> void:
	var ch = chests[i]
	if ch.opened:
		return
	ch.pop()
	if host:
		var k := 0
		for item in ch.loot:
			var off := Vector3(-0.6 + k * 0.6 - (ch.loot.size() - 3) * 0.3, 0, 0.85)
			_pickup(item, to_local(ch.to_global(off)))
			k += 1


func take_pickup(i: int, actor: Node3D) -> void:
	var p = pickups[i]
	if not is_instance_valid(p) or p.taken:
		return
	p.take()
	if not host or actor == null:
		return
	var max_hp: float = actor.max_health()
	match p.kind:
		"bende":
			actor.health = minf(actor.health + 35.0, max_hp)
			world.announce("Bende di lino: +35 salute.", 2)
		"pozione":
			actor.health = minf(actor.health + 60.0, max_hp)
			world.announce("Pozione rossa: +60 salute.", 2)
		"monete":
			actor.credits += 40
			world.announce("Monete d'oro: +40 crediti.", 2)
		"chiave":
			has_key = true
			world.announce("CHIAVE D'ORO presa. " + objective(), 5)
		"carne":
			has_bait = true
			world.announce("CARNE MALEDETTA presa: è l'esca. " + objective(), 6)


func break_crate(i: int) -> void:
	if not host:
		_ask.rpc_id(1, "crate:%d" % i)
		return
	crates[i].smash()
	_push_state()


func trip(i: int) -> void:
	wires[i].snap()
	world.announce("Dlin dlin… la miccia è accesa!", 1.5)
	_push_state()


func arrow_trap(i: int) -> void:
	arrows[i].fire()
	_push_state_event("arrow:%d" % i)


func trap_feedback(actor: Node3D, kind: String) -> void:
	if actor.get("rig") and actor.rig.has_method("add_shake"):
		actor.rig.add_shake({"blade": 0.7, "spikes": 0.5, "arrow": 0.3, "fire": 0.15}.get(kind, 0.3))


func explosion(at: Vector3, radius: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color("ffb04a")
	l.omni_range = radius * 2.5
	l.light_energy = 6.0
	add_child(l)
	l.global_position = at + Vector3.UP * 0.5
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 46
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180
	p.initial_velocity_min = 4
	p.initial_velocity_max = 10
	p.gravity = Vector3(0, -12, 0)
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff9a3a")
	mat.emission_enabled = true
	mat.emission = Color("ff7a1a")
	m.material = mat
	p.mesh = m
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)
	if is_instance_valid(world.player) and world.player.global_position.distance_to(at) < radius * 3.0 and world.player.get("rig") and world.player.rig.has_method("add_shake"):
		world.player.rig.add_shake(0.9)


func open_door() -> void:
	if door_open:
		return
	door_open = true
	has_key = true
	door.find_child("Door_Key").visible = true
	door_ap.play("Door_Key_Unlock")
	door_ap.queue("Door_Swing_Open")
	get_tree().create_timer(1.7).timeout.connect(func(): door_body.process_mode = Node.PROCESS_MODE_DISABLED)
	world.announce("La chiave gira, il lucchetto cade. La porta della torre si apre.", 4)


func place_bait() -> void:
	if bait_placed:
		return
	bait_placed = true
	has_bait = true
	altar_ap.play("Altar_Place_Bait")
	altar_ap.queue("Altar_Blood_Rite")
	for g in gates:
		set_gate(g, false)
	get_tree().create_timer(1.2).timeout.connect(func():
		for b in bells: b.play("Bell_Ring")
		_set_rite(true)
		world.announce("Le campane suonano da sole… le saracinesche crollano. QUALCOSA HA SENTITO L'ODORE.", 5))
	get_tree().create_timer(4.6).timeout.connect(_release_boss)


func _release_boss() -> void:
	cage_ap.play("Cage_Drop")
	if is_instance_valid(world.player) and world.player.get("rig") and world.player.rig.has_method("add_shake"):
		get_tree().create_timer(0.45).timeout.connect(func(): world.player.rig.add_shake(1.0))
	if not host:
		return
	var at := to_global(OCT_C + Vector3(0, 3.45, -7.0))
	boss = world._spawn_enemy(at)
	boss.set_kind(5, 2)
	boss.title = "IL CARCERIERE"
	boss.use_brain("carceriere")
	boss.home = to_global(OCT_C)
	boss.rotation.y = 0.0
	AudioManager.boss_voice("carceriere", "roar", at + Vector3.UP * 2.6, -3.0)
	rooms["arena"].enemies.append(boss)
	rooms["arena"].state = "active"
	boss_phase = 0
	arena_empty = 0.0
	var near: CharacterBody3D = world.nearest_player(at)
	if near:
		boss.hear(near, 60)
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(boss): boss.force_attack("Z_Boss_Drop_Arrival"))
	world.announce("LA GABBIA CEDE · IL CARCERIERE È LIBERO", 4)


func _set_rite(on: bool) -> void:
	for l in arena_lights:
		l.light_color = Color("ff2a1a") if on else Color("ffb46a")
		l.set_meta("base", 2.2 if on else (1.6 if l.position.y > 5 else 0.9))
	env_arena.ambient_light_color = Color(0.45, 0.12, 0.1) if on else Color(0.34, 0.29, 0.25)
	env_arena.ambient_light_energy = 0.75 if on else 0.5
	_rage = 1.0 if on else 0.0


# =================================================================== NEMICI
func _spawn(kind: int, at_local: Vector3, room: String, patrol_local := []) -> Node3D:
	var at := to_global(at_local)
	var e: Node3D = world._spawn_enemy(at + Vector3.UP * 0.1)
	e.set_kind(kind, 1)
	e.home = at
	if patrol_local.size() > 0:
		var pts := PackedVector3Array()
		for q in patrol_local:
			pts.append(to_global(q))
		e.patrol = pts
		e.patrol_i = _rng.randi_range(0, pts.size() - 1)
	rooms[room].enemies.append(e)
	return e


func _loop(c0: Vector2i, c1: Vector2i, y := 0.0) -> Array:
	var a := cell_pos(c0, y)
	var b := cell_pos(c1, y)
	return [a, Vector3(b.x, y, a.z), b, Vector3(a.x, y, b.z)]


func _start(room: String) -> void:
	rooms[room].state = "active"
	var u := UP
	match room:
		"sala":
			_spawn(0, cell_pos(Vector2i(-1, 3), u), room, [cell_pos(Vector2i(-2, 2), u), cell_pos(Vector2i(3, 2), u), cell_pos(Vector2i(3, 5), u), cell_pos(Vector2i(-2, 5), u)])
			_spawn(0, cell_pos(Vector2i(2, 5), u) + Vector3(0.5, 0, -0.3), room)          # chino sul pasto (Z_Feed_Kneel)
			_spawn(0, cell_pos(Vector2i(-2, 3), u), room)
		"armeria":
			_spawn(3, cell_pos(Vector2i(-3, 4), u), room)                                 # guardia della chiave (elite)
			_spawn(0, cell_pos(Vector2i(-4, 4), u), room)
		"cantina":
			_spawn(0, cell_pos(Vector2i(3, 3)), room)
			_spawn(0, cell_pos(Vector2i(4, 4)) + Vector3(-0.5, 0, -0.5), room)
		"fossa":
			_spawn(0, cell_pos(Vector2i(0, -3)), room, _loop(Vector2i(0, -4), Vector2i(3, 1)))
			_spawn(0, cell_pos(Vector2i(2, 1)), room, _loop(Vector2i(0, -4), Vector2i(3, 1)))
			_spawn(0, cell_pos(Vector2i(1, -1)), room, _loop(Vector2i(1, -3), Vector2i(3, 0)))
			_spawn(0, cell_pos(Vector2i(3, -2)), room, _loop(Vector2i(1, -3), Vector2i(3, 0)))
			_spawn(2, cell_pos(Vector2i(2, -1)), room)                                     # bruto
			for z in [-4, -1]:
				_spawn(4, cell_pos(Vector2i(-2, z), 3.55), room)                           # sputatori sulle balconate
			_spawn(4, cell_pos(Vector2i(-2, 0), 3.55), room)
		"prigioni":
			var lp := [Vector3(-24, 0, -24), Vector3(-16, 0, -24), Vector3(-16, 0, 4), Vector3(-24, 0, 4)]
			for k in 4:
				_spawn(0, lp[k], room, lp)
			_spawn(0, cell_pos(Vector2i(-5, -4)), room)                                     # nella cella sfondata
			_spawn(0, cell_pos(Vector2i(-5, 0)), room)
			_spawn(1, cell_pos(Vector2i(-3, -5)), room)
		"cripta_a":
			_spawn(0, cell_pos(Vector2i(-7, 3)), room)
		"cripta_b":
			_spawn(1, cell_pos(Vector2i(6, -1)), room)
		"corridoio":
			_spawn(0, cell_pos(Vector2i(4, -5)), room, [cell_pos(Vector2i(4, -6)), cell_pos(Vector2i(4, 1))])
			_spawn(0, cell_pos(Vector2i(4, 0)), room, [cell_pos(Vector2i(4, 1)), cell_pos(Vector2i(4, -6))])
		"alchimista":
			_spawn(3, cell_pos(Vector2i(6, -5)) + Vector3(0, 0, -1.0), room)
			_spawn(2, cell_pos(Vector2i(7, -4)), room)
			_spawn(1, cell_pos(Vector2i(5, -6)), room)
			_spawn(1, cell_pos(Vector2i(7, -6)), room)
	for e in rooms[room].enemies:
		if is_instance_valid(e) and int(e.get("kind")) == 4:
			var near: CharacterBody3D = world.nearest_player(e.global_position)
			if near:
				e.hear(near, 40)


# =================================================================== LOOP
func _process(delta: float) -> void:
	if not world or not world.get("started"):
		return
	clock += delta
	var t := Time.get_ticks_msec() * 0.001
	for i in torches.size():
		var l := torches[i]
		var k := 0.88 + 0.12 * sin(t * 9.0 + i * 1.7) * sin(t * 13.0 + i)
		if _rage > 0 and arena_lights.has(l):
			k = 0.6 + 0.4 * absf(sin(t * 3.0 + i * 0.4))
		l.light_energy = l.get_meta("base") * k
	_local_view()
	_update_ui()
	if not host:
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
	for id in occupied:
		if rooms.has(id) and rooms[id].state == "idle" and id != "arena":
			_start(id)
	for i in pickups.size():
		var p = pickups[i]
		if not is_instance_valid(p) or p.taken or not (p.kind in ["bende", "pozione", "monete"]):
			continue
		for a in world.actors.values():
			if is_instance_valid(a) and not a.dead and a.global_position.distance_to(p.global_position) < 0.6:
				take_pickup(i, a)
				_push_state()
				break
	_boss_logic(occupied)
	if Session.online and int(clock * 4) % 20 == 0:
		_push_state()


func _boss_logic(occupied: Dictionary) -> void:
	if not bait_placed or boss_dead:
		return
	if is_instance_valid(boss) and boss.dead:
		boss_dead = true
		_boss_down()
		if world.get("quest"): world.quest.on_boss(2)
		return
	if not is_instance_valid(boss):
		return
	var frac: float = boss.health / boss.max_health
	if boss_phase == 0 and frac < 0.66:
		boss_phase = 1
		boss.alert_time = 1.8
		world.announce("Il Carceriere chiama i suoi prigionieri!", 3)
		for k in [0, 4]:
			var phi := deg_to_rad(45.0 * k + 22.5)
			_spawn(0, OCT_C + Vector3(cos(phi), 0, sin(phi)) * 10.0, "arena")
			_spawn(0, OCT_C + Vector3(cos(phi + 0.5), 0, sin(phi + 0.5)) * 10.0, "arena")
		_spawn(4, OCT_C + Vector3(0, 0, -11.5), "arena")
	elif boss_phase == 1 and frac < 0.33:
		boss_phase = 2
		boss.alert_time = 1.8
		boss.anim_scale = 0.9
		world.announce("FURIA · Il Carceriere perde il controllo!", 3)
		for k in [1, 3, 5, 7]:
			var phi := deg_to_rad(45.0 * k)
			_spawn(1 if k % 4 == 1 else 4, OCT_C + Vector3(cos(phi), 0, sin(phi)) * 10.5, "arena")
	if not occupied.has("arena"):
		arena_empty += 0.25
		if arena_empty > 25.0:
			for e in rooms["arena"].enemies:
				if is_instance_valid(e):
					e.queue_free()
			rooms["arena"].enemies.clear()
			rooms["arena"].state = "idle"
			boss = null
			bait_placed = false
			has_bait = false
			for p in pickups:
				if is_instance_valid(p) and p.kind == "carne":
					p.reset()
			_rest(altar_ap, "Altar_Place_Bait")
			cage_ap.play("Cage_Sway")
			for b in bells: _rest(b, "Bell_Ring")
			_set_rite(false)
			for g in gates:
				set_gate(g, true)
			world.announce("L'arena tace. La carne è tornata nel laboratorio dell'alchimista.", 4)
			_push_state()
	else:
		arena_empty = 0.0


## Il forziere del boss c'è solo a boss morto: da nascosto non deve essere un muro invisibile davanti all'altare.
func _boss_chest(on: bool) -> void:
	var ch: Node3D = chests[5]
	ch.visible = on
	for body in ch.find_children("*", "CollisionObject3D", true, false):
		if not body.has_meta("layer"): body.set_meta("layer", body.collision_layer)
		body.collision_layer = int(body.get_meta("layer")) if on else 0


func _boss_down() -> void:
	for g in gates:
		set_gate(g, true)
	for b in bells: _rest(b, "Bell_Ring")
	_set_rite(false)
	if chests.size() > 5:
		_boss_chest(true)
	world.announce("IL CARCERIERE È CADUTO · Forziere accanto all'altare. La porta nord riporta in superficie.", 7)
	_push_state()


func _local_view() -> void:
	var p: CharacterBody3D = world.player
	if not is_instance_valid(p):
		return
	var ar := area_of(p.global_position)
	var zone := ""
	if ar != "":
		zone = "arena" if ar == "arena" else ("upper" if to_local(p.global_position).y > UP - 0.6 else "lower")
	if zone == _inside:
		return
	var was := _inside
	_inside = zone
	if was != zone: apply_view()


## Ambiente della camera e sole decisi solo da dove sta il giocatore (Cripta, Rocca o superficie).
## Prima Rocca e Cripta salvavano ognuna lo stato del sole e, passando dall'una all'altra, lo lasciavano spento per sempre.
func apply_view() -> void:
	var p: CharacterBody3D = world.player
	if not is_instance_valid(p):
		return
	var env: Environment = null
	if cripta and cripta._inside:
		env = cripta.env
	elif _inside != "":
		env = {"upper": env_upper, "lower": env_lower, "arena": env_arena}[_inside]
	p.rig.camera.environment = env
	var land: Node = world.get("landscape") if world.get("landscape") else world
	for s in land.find_children("*", "DirectionalLight3D", true, false):
		s.visible = env == null and bool(world.get("started"))


func _update_ui() -> void:
	var inside := _inside != ""
	_objective.visible = inside
	if inside:
		_objective.text = Localization.t("LA ROCCA · ") + Localization.t(objective())
	if not host:
		for e in world.targets:
			if is_instance_valid(e) and e.kind == 5 and not e.dead and not e.has_meta("borgo"):   # il boss del borgo ha la sua barra
				boss = e
	# La barra del boss ora è quella grande dell'HUD (ui/zombix_hud.gd): questa resta spenta.
	var b: bool = false
	_bar.visible = b
	_bar_label.visible = b
	if b:
		_bar.max_value = boss.max_health
		_bar.value = boss.health
	for l in get_children():
		if l is Label3D:
			if l.has_meta("needs"):
				l.visible = boss_dead
			if l.has_meta("door"):
				l.visible = not door_open
				l.modulate = Color("ffd24a") if has_key else Color("ff8a5a")
			if l.has_meta("altar"):
				l.visible = not bait_placed
			if l.has_meta("hatch"):
				l.visible = not cripta_done


# =================================================================== RETE
func _push_state_event(ev: String) -> void:
	if Session.online and multiplayer.is_server():
		for peer in Session.connected_peers():
			_event.rpc_id(peer, ev)


@rpc("authority", "call_remote", "reliable")
func _event(ev: String) -> void:
	if ev.begins_with("arrow:"):
		arrows[int(ev.substr(6))].fire()


func _push_state() -> void:
	if not Session.online or not multiplayer.is_server():
		return
	var s := {"clock": clock, "cripta": cripta_done, "key": has_key, "bait": has_bait, "door": door_open, "placed": bait_placed, "boss_dead": boss_dead,
		"gates": {}, "crates": [], "chests": [], "wires": [], "picks": []}
	for g in gates: s.gates[g] = gates[g].open
	for c in crates: s.crates.append(c.broken)
	for c in chests: s.chests.append(c.opened)
	for w in wires: s.wires.append(w.tripped)
	for p in pickups: s.picks.append([p.kind, to_local(p.global_position), p.taken] if is_instance_valid(p) else ["", Vector3.ZERO, true])
	for peer in Session.connected_peers():
		_state.rpc_id(peer, s)


@rpc("authority", "call_remote", "reliable")
func _state(s: Dictionary) -> void:
	clock = s.clock
	if s.get("cripta", false) and not cripta_done:
		crypt_cleared()
	has_key = s.key
	has_bait = s.bait
	if s.door and not door_open:
		open_door()
	if s.placed and not bait_placed:
		place_bait()
	if s.boss_dead and not boss_dead:
		boss_dead = true
		_boss_down()
	for g in s.gates:
		set_gate(g, s.gates[g])
	for i in mini(s.crates.size(), crates.size()):
		if s.crates[i]: crates[i].smash()
	for i in mini(s.chests.size(), chests.size()):
		if s.chests[i]: chests[i].pop()
	for i in mini(s.wires.size(), wires.size()):
		if s.wires[i]: wires[i].snap()
	for i in s.picks.size():
		var row: Array = s.picks[i]
		if i >= pickups.size():
			if row[0] != "":
				_pickup(row[0], row[1])
			else:
				pickups.append(null)
		if i < pickups.size() and is_instance_valid(pickups[i]) and row[2] and not pickups[i].taken:
			pickups[i].take()


# =================================================================== CRIPTA (world/dungeon/dungeon.gd) E GUIDA
## Botola della Cripta davanti alla saracinesca sud dell'arena (chiamata da _interactive, dopo la navmesh).
func _cripta_hatch() -> void:
	var at := cell_pos(HATCH_CELL) + Vector3(0, 0.03, -1.1)
	# L'anta stesa è il pavimento della botola: tutta a sud della saracinesca e senza corpo, non un gradino nel varco.
	var leaf := _place("M_DoorIronL", at + Vector3(-0.67, 0.0, 1.95))
	if leaf:
		leaf.rotation = Vector3(-PI / 2, 0, 0)
		for body in leaf.find_children("*", "StaticBody3D", true, false): body.free()
	for x in [-1.5, 1.5]:
		_place("P_CandleTriple", at + Vector3(x, 0, 0.4))
	_torch(at + Vector3(0, 0.6, 0), 4.0, 0.9, Color("9fc6ff"))
	_hatch_label = _label3d("BOTOLA DELLA CRIPTA · [E] scendi", at + Vector3(0, 1.6, 0.6), Color("9fc6ff"))
	_hatch_label.no_depth_test = true
	_hatch_label.set_meta("hatch", true)


## Dove si torna su dalla Cripta: davanti alla botola, guardando la saracinesca.
func cripta_return() -> Vector3:
	return to_global(cell_pos(HATCH_CELL) + Vector3(0, 0.3, 0.2))


## La sala dei secondini è ripulita: la saracinesca sud dell'arena si alza (host, poi lo stato ai client).
func crypt_cleared() -> void:
	if cripta_done:
		return
	cripta_done = true
	if not bait_placed:
		set_gate("arena_sud", true)
	world.announce("Un rumore di catene sopra di voi: la saracinesca dell'arena si è alzata.", 5)
	_push_state()


func _guide(tower: Node3D) -> void:
	# Bruno lo speleologo, appoggiato al muro della torre con le braccia conserte, la lanterna accesa ai piedi.
	guide_pos = tower.to_global(Vector3(5.4, 0, 6.4))
	guide_pos.y = Terrain.ground_height(guide_pos.x, guide_pos.z)
	guide = Npc.spawn(world, "ZX_SKIN_3", "", "guide", guide_pos, tower.rotation.y - PI * 0.15)
	guide.name = "NPC_Bruno"
	var lamp := _place("P_Lantern", Vector3.ZERO) if lib.has("P_Lantern") else null
	if lamp:
		lamp.reparent(world)
		lamp.global_position = guide_pos + tower.global_basis * Vector3(0.5, 0, 0.4)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffc070")
	glow.omni_range = 5.0
	glow.light_energy = 1.2
	world.add_child(glow)
	glow.global_position = guide_pos + Vector3(0, 0.5, 0) + tower.global_basis * Vector3(0.5, 0, 0.4)
	var tag := Label3D.new()
	tag.text = Localization.t("BRUNO LO SPELEOLOGO\n[E] parla")
	tag.font_size = 40; tag.pixel_size = 0.004; tag.outline_size = 10; tag.modulate = Color("ffe0a8")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	world.add_child(tag)
	tag.global_position = guide_pos + Vector3(0, 2.25, 0)


const GUIDE_INTRO := [
	"Piano, piano. Non sei uno di loro, bene. Sono Bruno: mappavo queste grotte per il comune, prima che il lago diventasse cenere.",
	"Quella torre è tutto quello che resta della Rocca di Lago Cenere. Sotto c'è un castello intero, sepolto. E sotto ancora, la Cripta.",
	"Il Carceriere ci teneva i prigionieri. Quando è arrivata la febbre li ha tenuti anche dopo. Adesso il prigioniero più grosso è lui.",
	"Il portone è sempre aperto: entra nella torre e scendi la scala, in fondo c'è l'arco. Puoi entrare quando vuoi.",
]
const GUIDE_ROUTE := [
	"Piano di sopra: corpo di guardia e sala grande. Nell'armeria, a ovest, c'è la CHIAVE D'ORO. Uno di quelli che urlano la sorveglia.",
	"La chiave apre il lucchetto della porta della torre, a est della sala. Scendi la scala a chiocciola: cantina, la Fossa, le prigioni.",
	"Oltre il corridoio dei draghi c'è il laboratorio dell'alchimista. Prendi la CARNE MALEDETTA: è l'esca, senza quella il Carceriere non scende.",
	"In fondo al corridoio delle lame la saracinesca dell'arena è bloccata da sotto. C'è una botola: scendi nella CRIPTA.",
	"Labirinto, segrete, la cisterna degli sputatori, poi la sala dei secondini. Ripuliscila e la saracinesca dell'arena salta.",
	"Risali, appendi la carne all'altare e tieniti pronto. Quando suonano le campane la gabbia cade. Il resto lo sai.",
]
const GUIDE_DANGER := [
	"Spuntoni a tempo, lame a pendolo, piastre che fanno partire i dardi. Guarda il ritmo prima di correre.",
	"Le teste di drago sputano fuoco ogni quattro secondi. I fili coi campanelli fanno saltare i barili di polvere: passaci sopra e scappa.",
	"Gli sputatori stanno in alto e tengono la distanza. Copriti, e chiudi la distanza quando ricaricano.",
	"Il Carceriere non si decapita e non barcolla ai colpi leggeri. Colpi caricati, e scansati quando salta.",
	"Nei forzieri ci sono bende, pozioni e monete, le casse si rompono con l'ascia. Se cadete tutti, la Rocca si richiude e si ricomincia.",
]
const GUIDE_OPTIONS := ["Come arrivo al Carceriere?", "Cosa c'è là sotto?", "Vado."]


## [E] vicino a Bruno: dialogo nel pannello dello sceriffo (solo sul giocatore locale, niente rete).
func talk() -> void:
	var rules: Node = world.get("survival")
	if rules == null or not rules.has_method("open_npc_dialogue"):
		world.announce(GUIDE_ROUTE[0], 6)
		return
	rules.open_npc_dialogue("Bruno", GUIDE_INTRO, GUIDE_OPTIONS, Callable(self, "_on_guide_choice"))

func _on_guide_choice(index: int) -> void:
	var rules: Node = world.get("survival")
	if rules == null: return
	match index:
		0: rules.show_npc_lines(GUIDE_ROUTE)
		1: rules.show_npc_lines(GUIDE_DANGER)
		_: rules.close_sheriff_dialogue()

## Superficie: la torre è l'unico pezzo in piedi della cinta. Ai lati due tratti di mura spezzate e sprofondate, colonne
## cadute, edera; davanti un sentiero di torce dalla pista al portone; accanto il fuoco del campo di Bruno.
func _surface_ruins(tower: Node3D) -> void:
	var ruins := Node3D.new()
	ruins.name = "RoccaRovine"
	world.add_child(ruins)
	ruins.global_transform = tower.global_transform
	var put := func(key: String, at: Vector3, yaw := 0.0, tilt := Vector3.ZERO) -> Node3D:
		var n := _place(key, Vector3.ZERO, 0.0, ruins)
		if n == null: return null
		var g := tower.to_global(at)
		n.position = Vector3(at.x, Terrain.ground_height(g.x, g.z) - tower.global_position.y + at.y, at.z)
		n.rotation = Vector3(tilt.x, yaw, tilt.z)
		return n
	# mura: il primo tratto intero accanto alla torre, il secondo spezzato e affondato nel terreno
	for side in [-1.0, 1.0]:
		put.call("M_Wall2" if side < 0 else "M_Wall3", Vector3(side * 7.0, -1.2, -2.0))
		put.call("M_Pillar", Vector3(side * 5.0, -0.8, -2.0))
		put.call("M_Wall1", Vector3(side * 11.0, -2.9, -2.2 + 0.3 * side), 0.12 * side, Vector3(0, 0, 0.1 * side))
		put.call("P_Ivy", Vector3(side * 6.4, 1.6, -1.85))
	# colonna caduta e massi davanti alla cinta
	put.call("M_Pillar", Vector3(9.0, 0.35, 5.0), 0.4, Vector3(0, 0, PI / 2))
	put.call("P_BannerRed", Vector3(-7.0, 0.6, -1.8), 0.0, Vector3(0.0, 0.0, 0.08))
	put.call("P_Spear", Vector3(4.6, 0, 7.0), 0.0, Vector3(0.25, 0, 0.1))
	put.call("P_Shield", Vector3(4.8, 0, 6.6), 1.2, Vector3(-1.3, 0, 0))
	# il campo di Bruno: fuoco, sacco, sgabello, la mappa sul tavolino
	var fire := Vector3(8.0, 0, 8.0)
	for i in 3:
		put.call("P_Firewood", fire + Vector3(0, 0.05, 0), i * 1.05, Vector3(0, 0, 0.35))
	put.call("P_Stool", fire + Vector3(1.3, 0, -0.4))
	put.call("P_Bag", fire + Vector3(-1.2, 0, -0.9), 0.6)
	put.call("P_TableSmall", fire + Vector3(2.4, 0, -1.6), PI / 2 + 0.3)
	put.call("P_ScrollOpen", fire + Vector3(2.4, 0.9, -1.6), 0.5)
	put.call("P_Candlestick", fire + Vector3(2.5, 0.9, -0.7))
	var flame := OmniLight3D.new()
	flame.light_color = Color("ff9a3c")
	flame.omni_range = 8.0
	flame.light_energy = 2.0
	flame.shadow_enabled = true
	ruins.add_child(flame)
	var fg := tower.to_global(fire)
	flame.position = Vector3(fire.x, Terrain.ground_height(fg.x, fg.z) - tower.global_position.y + 0.6, fire.z)
	flame.set_meta("base", 2.0)
	torches.append(flame)
	var sparks := CPUParticles3D.new()
	sparks.amount = 28; sparks.lifetime = 0.9; sparks.direction = Vector3.UP; sparks.spread = 18
	sparks.initial_velocity_min = 0.6; sparks.initial_velocity_max = 1.4; sparks.gravity = Vector3(0, 0.6, 0)
	sparks.scale_amount_min = 0.6; sparks.scale_amount_max = 1.4
	var dot := SphereMesh.new(); dot.radius = 0.06; dot.height = 0.12; dot.radial_segments = 6; dot.rings = 3
	var glow := StandardMaterial3D.new(); glow.albedo_color = Color("ffb04a"); glow.emission_enabled = true; glow.emission = Color("ff7a1a")
	glow.emission_energy_multiplier = 3.0; glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material = glow
	sparks.mesh = dot
	ruins.add_child(sparks)
	sparks.position = flame.position - Vector3(0, 0.45, 0)
	# sentiero di torce dalla pista al portone (torce del kit della miniera)
	for i in 4:
		var z := 11.0 + i * 3.6
		var x := 2.3 * (1.0 if i % 2 == 0 else -1.0)
		var t: Node3D = load("res://art/env/mine/SM_Mine_Torch_0.glb").instantiate()
		ruins.add_child(t)
		var g := tower.to_global(Vector3(x, 0, z))
		t.position = Vector3(x, Terrain.ground_height(g.x, g.z) - tower.global_position.y, z)
		t.scale = Vector3.ONE * 0.8
		var l := OmniLight3D.new()
		l.light_color = Color("ffa245"); l.omni_range = 6.0; l.light_energy = 1.3
		l.position = t.position + Vector3(0, 2.1, 0)
		l.set_meta("base", 1.3)
		ruins.add_child(l)
		torches.append(l)