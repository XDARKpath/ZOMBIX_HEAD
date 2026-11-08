# BORGO CENERE — villaggio abbandonato a ~250 m dal rifugio, sulla strada del GPS.
# Grafica SENZA asset con licenza di terzi: muri, tetti, porte, arredo, auto, tende, barili, recinti sono il kit originale
# art/zx_borgo (fatto da zero in Blender, sorgente zx/borgo_kit.py) con le stesse misure dei moduli del rifugio;
# alberi, cespugli, sassi, erba e fiori sono del pacchetto Quaternius (art/nature, licenza CC0).
# Nessun file Synty / POLYGON / SurrounDead. Niente alberi tondi KayKit e niente alberi rossi (TwistedTree).
# stesso cielo, stessa luce, stesso terreno (terrain.gd lo appiattisce qui: villaggio_layout.gd).
#
# Pianta (locale, nord = -Z):  4 vie (N, S, O, E) di case che portano alla PIAZZA (36×36 m) al centro.
#   Piazza: pozzo crollato al centro = punto da cui esce il boss "IL MACELLAIO DEL BORGO" (kind 5);
#   8 negozi col tetto piatto (gli sputatori ci salgono sopra); quando entri, 4 barricate si alzano e chiudono le vie.
#   Fine via N: chiesa con campanile + cimitero.  Fine via O: campo profughi con torretta.  Fine via S: fattoria
#   con fienile e serbatoio dell'acqua.  Fine via E: posto di blocco sulla strada.  Fuori: bosco, orti, recinti.
# Incontri (solo host, i client ricevono via RPC): entri nel borgo -> infetti per le vie + sputatori sui tetti;
#   entri in piazza -> barricate + boss a 3 fasi (chiama rinforzi e sputatori). Boss morto -> barricate giù, 2 casse.
# Uso: village = Node3D con questo script; world.add_child(village); village.build_village(world).
extends "res://world/villaggio/borgo_build.gd"

const L := preload("res://world/villaggio/villaggio_layout.gd")
## alberi: pini Quaternius, come il resto del bosco
const FOREST := ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5", "Pine_1"]
const BOSS_MUSIC := "mago"
const PLAZA := 18.5           # mezza piazza: qui stanno le facciate dei negozi
const STREET := 4.5           # mezza larghezza delle vie (= mezza bocca della barricata)
const STREET_LEN := 100.0
const BOSS_NAME := "IL MACELLAIO DEL BORGO"
const SHOPS := ["ALIMENTARI", "FARMACIA", "BAR CENERE", "FERRAMENTA", "POSTE", "BARBIERE", "MACELLERIA", "TABACCHI"]
const DIRS := {"N": Vector2(0, -1), "S": Vector2(0, 1), "O": Vector2(-1, 0), "E": Vector2(1, 0)}

var world: Node3D
var nav: NavigationRegion3D
var street_points: Array[Vector3] = []     # punti a terra lungo le vie (locali)
var barricades: Array[Node3D] = []
var chests := []                      # {pos, lid, looted, amount, heal}
var state := "idle"                   # borgo: idle / active / cleared
var arena := "idle"                   # piazza: idle / active / cleared
var town_enemies: Array = []
var arena_enemies: Array = []
var boss: Node3D
var boss_phase := 0
var empty_time := 0.0
var away_time := 0.0
var bait_actor: Node3D                # chi ha gettato l'esca: se lo scontro si abbandona, la riprende lui
var barricade_up := false
var _poll := 0.0
var supplies: Array = []              # punti (locali) con le scatolette nei negozi
var _ui: CanvasLayer
var _bar: ProgressBar


func build_village(owner_world: Node3D) -> void:
	world = owner_world
	name = "BorgoCenere"
	rng.seed = 20261106
	nav = NavigationRegion3D.new()
	nav.name = "BorgoNav"
	add_child(nav)
	geo = Node3D.new()
	geo.name = "Borgo"
	geo.position = L.CENTER
	nav.add_child(geo)
	_ground()
	_plaza()
	for key in DIRS:
		_street(key)
	_church()
	_refugee_camp()
	_farm()
	_checkpoint()
	_woods()
	_flush_multimesh()
	_road_signs()
	fit_ranges(geo)
	_boss_ui()
	if _is_host():
		_bake()


# ================================================================== helpers
func _is_host() -> bool:
	return not Session.online or multiplayer.is_server()


# ================================================================== terreno, vie, piazza
func _ground() -> void:
	# piano di collisione per la navigazione (il terreno vero lo disegna terrain.gd, qui è piatto a y = 0)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(L.FLAT * 2.3, 1.0, L.FLAT * 2.3)
	cs.shape = shape
	cs.position.y = -0.5
	body.add_child(cs)
	geo.add_child(body)
	# vie di terra battuta (come i sentieri del rifugio) con un bordo d'erba più scuro
	for key in DIRS:
		var d: Vector2 = DIRS[key]
		var length := STREET_LEN if key != "E" else 72.0
		var mid := Vector3(d.x, 0, d.y) * (PLAZA + length * 0.5)
		var size := Vector3(length if d.x != 0 else STREET * 2, 0.05, length if d.y != 0 else STREET * 2)
		box(geo, mid + Vector3(0, 0.0, 0), size, Color("5b5a4b"), false)
		var verge := size + (Vector3(0, 0, 2.6) if d.x != 0 else Vector3(2.6, 0, 0))
		box(geo, mid + Vector3(0, -0.012, 0), verge, Color("4a4a39"), false)
		# solchi delle ruote
		for side in [-1.3, 1.3]:
			var off = Vector3(d.y, 0, d.x) * side
			box(geo, mid + off + Vector3(0, 0.03, 0), Vector3(size.x if d.x != 0 else 0.5, 0.01, size.z if d.y != 0 else 0.5), Color("4f4d40"), false)
	# viottolo dalla fine della via S alla strada asfaltata
	var a := Vector3(0, 0, PLAZA + STREET_LEN)
	var b := Vector3(44, 0, 122)
	var lane := box(geo, (a + b) * 0.5, Vector3(6, 0.05, a.distance_to(b) + 4), Color("5b5a4b"), false)
	lane.rotation.y = atan2((b - a).x, (b - a).z)


func _plaza() -> void:
	var p := _node(geo, Vector3.ZERO, 0, "Piazza")
	# lastricato: un'unica mesh a quadrotti con colori leggermente diversi
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tile := 1.5
	var half := PLAZA
	var x := -half
	while x < half - 0.01:
		var z := -half
		while z < half - 0.01:
			var c := Color("565349").lerp(Color("45443b"), rng.randf())
			if rng.randf() < 0.06:
				c = Color("3a3a32")
			st.set_color(c)
			var g := 0.04
			var y := 0.06 + rng.randf_range(0.0, 0.012)
			for v in [Vector3(x + g, y, z + g), Vector3(x + tile - g, y, z + g), Vector3(x + g, y, z + tile - g),
					Vector3(x + tile - g, y, z + g), Vector3(x + tile - g, y, z + tile - g), Vector3(x + g, y, z + tile - g)]:
				st.add_vertex(v)
			z += tile
		x += tile
	st.generate_normals()
	var paving := MeshInstance3D.new()
	paving.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	paving.material_override = mat
	p.add_child(paving)
	box(p, Vector3(0, 0.025, 0), Vector3(half * 2, 0.05, half * 2), Color("3d3c33"), false)   # fughe
	# ---- il pozzo crollato (il boss esce da qui)
	var well := _node(p, Vector3.ZERO, 0, "PozzoBoss")
	var hole := Props.cylinder(well, Vector3(0, 0.07, 0), 2.0, 0.02, Color("0d0c0b"))
	hole.name = "Buco"
	for i in 12:
		if i in [2, 3, 8]:
			continue                                  # tre varchi: il boss esce camminando
		var ang := i * TAU / 12.0
		var stone := box(well, Vector3(cos(ang) * 2.3, 0.3, sin(ang) * 2.3), Vector3(1.15, 0.6 - (0.25 if i % 4 == 0 else 0.0), 0.5), Color("706d60").darkened(rng.randf_range(0, 0.2)), true)
		stone.rotation.y = -ang + PI / 2
	for i in 6:
		var ang := rng.randf_range(0, TAU)
		var r := rng.randf_range(3.0, 5.5)
		var rock := box(well, Vector3(cos(ang) * r, 0.12, sin(ang) * r), Vector3(0.5, 0.25, 0.4) * rng.randf_range(0.6, 1.3), Color("6a675a"), false)
		rock.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), 0)
	# argano rotto sopra il pozzo
	for s in [-1, 1]:
		box(well, Vector3(s * 2.3, 1.2, 0), Vector3(0.18, 2.4, 0.18), Color("4d3f2d"), true)
	_tilted(well, Vector3(0.3, 2.3, 0), Vector3(4.8, 0.16, 0.16), Color("4d3f2d"), Vector3(0, 0, 0.12))
	var rope := Props.rod(well, Vector3(0.2, 2.3, 0), Vector3(0.15, 0.3, 0), 0.02, Color("8a7a55"))
	rope.name = "Corda"
	var glow := OmniLight3D.new()
	glow.name = "Bagliore"
	well.add_child(glow)
	glow.position = Vector3(0, 0.4, 0)
	glow.light_color = Color("c2402c")
	glow.light_energy = 0.8
	glow.omni_range = 4.0
	for i in 5:
		_blood(well, Vector3(rng.randf_range(-4, 4), 0.04, rng.randf_range(-4, 4)), rng.randf_range(0.7, 1.4))
	var smoke := Props.smoke(well, Vector3(0, 0.3, 0), 1.8, 0.18, 10)
	smoke.lifetime = 5.0
	smoke.initial_velocity_min = 0.2
	smoke.initial_velocity_max = 0.4
	smoke.gravity = Vector3(0.05, 0.08, 0)
	# ---- negozi tutto intorno (2 per lato, la via passa in mezzo)
	var shop := 0
	for key in DIRS:
		var d: Vector2 = DIRS[key]
		var normal := Vector3(d.x, 0, d.y)
		var along := Vector3(-d.y, 0, d.x)
		for s in [-1, 1]:
			var center = normal * (PLAZA + 4.5) + along * s * 10.5
			_shop(center, atan2(-normal.x, -normal.z), SHOPS[shop], shop)
			shop += 1
		# muretti negli angoli: la piazza resta chiusa tranne le 4 vie
		for s in [-1, 1]:
			var w := asset(p, "Bld_Wall_Brick_01", normal * PLAZA + along * s * 16.5 + (along * s * 2.0 if s < 0 else Vector3.ZERO), atan2(-normal.x, -normal.z) + (PI if s < 0 else 0.0), true, Vector3(0.68, 0.8, 1))
			w.position = normal * PLAZA + along * (16.5 if s > 0 else -18.5)
			w.rotation.y = atan2(along.x, along.z) - PI / 2 if true else 0.0
			_orient_wall(w, normal * PLAZA + along * (16.5 if s > 0 else -18.5), along, 2.0)
		# barricata (giù finché non inizia lo scontro)
		# Di piatto attraverso la via: larghezza lungo "along".
		_barricade(normal * (PLAZA - 0.6), atan2(-along.z, along.x))
	# ---- arredo della piazza
	for c in [Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(-12, 0, 12), Vector3(12, 0, 12)]:
		_streetlamp(p, c, atan2(-c.x, -c.z))
		_tree(p, NATURE + "CommonTree_%d.gltf" % rng.randi_range(1, 5), c * 1.25, rng.randf_range(0.75, 0.95))
		box(p, c * 1.25 + Vector3(0, 0.2, 0), Vector3(2.6, 0.4, 2.6), Color("5e5b4e"), true)   # aiuola
	# monumento rotto e le due casse del premio davanti
	var mon := _node(p, Vector3(0, 0, -10), 0, "Monumento")
	box(mon, Vector3(0, 0.6, 0), Vector3(2.6, 1.2, 2.0), Color("77746a"), true)
	box(mon, Vector3(0, 1.35, 0), Vector3(1.8, 0.3, 1.4), Color("85827a"), true)
	_tilted(mon, Vector3(0.2, 2.2, 0), Vector3(0.6, 1.5, 0.5), Color("8c897e"), Vector3(0, 0.3, 0.25))
	_tilted(mon, Vector3(1.8, 0.25, 1.4), Vector3(0.5, 0.5, 0.9), Color("8c897e"), Vector3(0.4, 0.8, 1.3))   # braccio caduto
	var plate := Label3D.new()
	mon.add_child(plate)
	plate.text = Localization.t("AI CADUTI\nDI CENERE")
	plate.position = Vector3(0, 0.75, 1.01)
	plate.font_size = 40
	plate.pixel_size = 0.006
	plate.modulate = Color("d8d1b9")
	plate.font = load("res://art/fonts/BarlowCondensed-SemiBold.ttf")
	_chest(Vector3(-2.2, 0, -7.5), 200, false)
	_chest(Vector3(2.2, 0, -7.5), 0, true)
	# bancarelle del mercato abbandonato
	for m in [Vector3(-10, 0, 3), Vector3(10, 0, 3), Vector3(-6, 0, 11), Vector3(7, 0, 12)]:
		_stall(p, m, rng.randf_range(-0.3, 0.3) + (PI if m.z > 8 else 0.0))
	# l'ultima difesa dei sopravvissuti: sacchi di sabbia, casse di munizioni, auto della polizia bruciata
	_sandbags(p, Vector3(6, 0, -4), 5.0, 0.4)
	_sandbags(p, Vector3(-6.5, 0, -3.5), 4.0, -0.5)
	_glb(p, BK + "SM_Borgo_Police_Wreck.glb", Vector3(-11, 0, -4), 1.2)
	for i in 4:
		_crate(p, Vector3(5 + i * 0.9, 0, -5.6), rng.randf_range(-0.2, 0.2), 0.6)
	for b in [Vector3(-14, 0, 8), Vector3(14, 0, -6)]:
		_bench(p, b, atan2(-b.x, -b.z))
	_fire(p, Vector3(-4, 0, 6), true)
	_fire(p, Vector3(9, 0, -9), true)
	# bacheca degli avvisi
	var board := _node(p, Vector3(14.5, 0, 5), -PI / 2)
	for bx in [-0.9, 0.9]:
		box(board, Vector3(bx, 1.0, 0), Vector3(0.1, 2.0, 0.1), Color("4b4134"), true)
	box(board, Vector3(0, 1.55, 0), Vector3(2.0, 1.0, 0.06), Color("6e5435"), false)
	for i in 5:
		var paper := box(board, Vector3(rng.randf_range(-0.75, 0.75), rng.randf_range(1.2, 1.9), 0.04), Vector3(0.3, 0.4, 0.01), Color("d6d0bd"), false)
		paper.rotation.z = rng.randf_range(-0.2, 0.2)
	var note := Label3D.new()
	board.add_child(note)
	note.text = Localization.t("EVACUAZIONE\nNON TORNATE")
	note.position = Vector3(0, 1.55, 0.05)
	note.font_size = 36
	note.pixel_size = 0.005
	note.modulate = Color("7a1e19")
	note.font = load("res://art/fonts/BarlowCondensed-SemiBold.ttf")
	for i in 40:
		var at := Vector3(rng.randf_range(-16, 16), 0.07, rng.randf_range(-16, 16))
		if at.length() < 5:
			continue
		if rng.randf() < 0.5:
			_junk(p, at)
		elif rng.randf() < 0.4:
			_blood(p, at, rng.randf_range(0.6, 1.2))
		elif rng.randf() < 0.5:
			_scatter(NATURE + "Grass_Wispy_Short.gltf", at, rng.randf_range(0.4, 0.7))   # erba tra le pietre
	for i in 4:
		_puddle(p, Vector3(rng.randf_range(-15, 15), 0.02, rng.randf_range(-15, 15)))


func _orient_wall(w: Node3D, at: Vector3, along: Vector3, length: float) -> void:
	# il pezzo di muro va da 'at' lungo 'along' per 'length' metri
	w.position = at
	w.rotation = Vector3.ZERO
	w.rotation.y = atan2(-along.z, along.x)
	w.scale = Vector3(length / 3.0, 0.8, 1)


func _stall(parent: Node3D, at: Vector3, yaw: float) -> void:
	var g := _node(parent, at, yaw)
	for x in [-1.3, 1.3]:
		for z in [-0.6, 0.6]:
			box(g, Vector3(x, 1.1, z), Vector3(0.08, 2.2, 0.08), Color("4b4134"), false)
	asset(g, "Bld_Exterior_Shade_01", Vector3(0, 2.25, -0.75), 0, false, Vector3(1.1, 0.6, 1.0))
	asset(g, "Prop_Table_Metal_01", Vector3(0, 0, 0), 0, true)
	if rng.randf() < 0.5:
		g.get_child(g.get_child_count() - 1).rotation.z = PI / 2.2    # tavolo ribaltato
	for i in 3:
		_junk(g, Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(0.7, 1.4)))
	asset(g, "Prop_Pot_01", Vector3(-0.5, 0.92, 0), 0, false)
	asset(g, "Prop_Container_01", Vector3(0.6, 0.92, 0.1), 0.4, false)


func _barricade(at: Vector3, yaw: float) -> void:
	# barricata che sale dal terreno e chiude la via (larga quanto la via, alta 2.6 m)
	var b := Node3D.new()
	b.name = "Barricata%d" % barricades.size()
	add_child(b)                                     # fuori da 'geo': non entra nella navigazione
	b.position = L.CENTER + at + Vector3(0, -3.2, 0)
	b.rotation.y = yaw
	var w := STREET * 2 + 0.6
	for x in [-w * 0.5, -w * 0.17, w * 0.17, w * 0.5]:
		box(b, Vector3(x, 1.3, 0), Vector3(0.22, 2.6, 0.22), Color("4d3f2d"), false)
	for y in [0.5, 1.2, 1.9]:
		var plank := box(b, Vector3(0, y, 0.05), Vector3(w, 0.32, 0.08), Color("6e5435").darkened(rng.randf_range(0, 0.2)), false)
		plank.rotation.z = rng.randf_range(-0.03, 0.03)
	for i in 3:
		var x := -w * 0.33 + i * w * 0.33
		_tilted(b, Vector3(x, 1.25, 0.12), Vector3(0.14, 2.6, 0.06), Color("5a4228"), Vector3(0, 0, 0.75))
		_tilted(b, Vector3(x, 1.25, 0.12), Vector3(0.14, 2.6, 0.06), Color("5a4228"), Vector3(0, 0, -0.75))
	for i in 7:
		_tilted(b, Vector3(-w * 0.45 + i * w * 0.15, 2.65, 0.3), Vector3(0.08, 0.9, 0.08), Color("8c897e"), Vector3(0.6, 0, 0))   # punte
	asset(b, "Prop_Sign_Danger_01", Vector3(0, 1.6, -0.15), PI, false, Vector3.ONE * 3)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, 2.8, 0.7)
	cs.shape = shape
	cs.position.y = 1.4
	cs.disabled = true
	body.add_child(cs)
	b.add_child(body)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.8, -1.0)
	light.light_color = Color("ff6a3a")
	light.light_energy = 0.0
	light.omni_range = 7
	b.add_child(light)
	b.visible = false
	b.set_meta("shape", cs)
	b.set_meta("light", light)
	barricades.append(b)


func set_barricades(up: bool) -> void:
	if up == barricade_up:
		return
	barricade_up = up
	for b in barricades:
		var cs: CollisionShape3D = b.get_meta("shape")
		var light: OmniLight3D = b.get_meta("light")
		var y0 := L.CENTER.y - 3.2
		var tw := create_tween()
		if up:
			b.visible = true
			cs.disabled = false
			tw.tween_property(b, "position:y", L.CENTER.y, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(light, "light_energy", 1.6, 0.6)
		else:
			tw.tween_property(b, "position:y", y0, 1.4).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(light, "light_energy", 0.0, 0.5)
			tw.tween_callback(func() -> void:
				cs.disabled = true
				b.visible = false)
	if _is_host():
		_push_state()


func _chest(at: Vector3, amount: int, heal: bool) -> void:
	var g := _node(geo, at, PI)
	box(g, Vector3(0, 0.35, 0), Vector3(1.2, 0.7, 0.7), Color("4f5a40") if not heal else Color("d6d0bd"), true)
	for x in [-0.5, 0.5]:
		box(g, Vector3(x, 0.35, 0), Vector3(0.08, 0.72, 0.72), Color("2f3533"), false)
	var lid := box(g, Vector3(0, 0.76, 0), Vector3(1.22, 0.12, 0.72), Color("5a6748") if not heal else Color("c0392b"), false)
	var tag := Label3D.new()
	g.add_child(tag)
	tag.text = Localization.t("CASSA DEL BORGO" if not heal else "CASSA MEDICA") + "\n" + Localization.t("[E] apri")
	tag.position = Vector3(0, 1.4, 0)
	tag.font_size = 34
	tag.pixel_size = 0.005
	tag.outline_size = 10
	tag.modulate = Color("ffcf4a")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.visible = false
	chests.append({"pos": L.CENTER + at, "lid": lid, "tag": tag, "looted": false, "amount": amount, "heal": heal})


# ================================================================== edifici
## negozio col tetto piatto, larghezza 4 moduli (12 m), facciata verso la piazza. Gli sputatori stanno sul tetto.
func _shop(at: Vector3, yaw: float, title: String, index: int) -> void:
	var h := _node(geo, at, yaw, "Negozio_" + title.replace(" ", "_"))
	var metal := index % 3 == 2
	var hs := 1.15
	_floor(h, 4, 3)
	_walls(h, 4, 3, metal, hs)
	for i in 4:
		var piece := ("Bld_Wall_Metal_Window_01" if metal else "Bld_Wall_Brick_Window_01")
		if i == 1:
			piece = "Bld_Wall_Brick_Door_01" if not metal else ""
		if piece == "":
			box(h, Vector3(-6 + i * 3 + 1.5, 2.3 + (3 * hs - 2.3) * 0.5, 4.5), Vector3(3, 3 * hs - 2.3, 0.22), Color("4c5d5b"), true)
			asset(h, "Bld_Metal_Door_01", Vector3(-6 + i * 3 + 2.0, 0, 4.5), -1.2, true)
		else:
			asset(h, piece, Vector3(-6 + i * 3, 0, 4.5), 0, true, Vector3(1, hs, 1))
	_flat_roof(h, 4, 3 * hs, true)
	asset(h, "Bld_Exterior_Shade_01", Vector3(-1.5, 2.75, 4.75), 0, false, Vector3(1.3, 0.7, 1))
	asset(h, "Bld_Exterior_Shade_01", Vector3(3.0, 2.75, 4.75), 0, false, Vector3(1.3, 0.7, 1))
	signboard(h, Vector3(0, 3 * hs + 0.75, 4.8), title, 6.5)
	_entry_ramp(h, 2.4)
	_boarded(h, 4)
	_interior(h, 4, true)
	supplies.append(h.position + Vector3(0, 0.3, 0).rotated(Vector3.UP, yaw) + Vector3(2.5, 0, 0).rotated(Vector3.UP, yaw))
	for i in 2:
		_junk(h, Vector3(rng.randf_range(-5, 5), 0.07, rng.randf_range(5.3, 7.0)))


func _backyard(at: Vector3, yaw: float, w: int) -> void:
	# dietro la casa: recinto, orto, capanno, panni stesi, alberi
	var y := _node(geo, at, yaw, "Cortile")
	var half := w * 1.5 + 1.5
	_fence_line(y, Vector3(-half, 0, -4.8), Vector3(-half, 0, -14.5))
	_fence_line(y, Vector3(half, 0, -14.5), Vector3(half, 0, -4.8))
	_fence_line(y, Vector3(-half, 0, -14.5), Vector3(half, 0, -14.5), 0.25)
	match rng.randi_range(0, 3):
		0:
			# orto: file di piante e paletti
			for row in 4:
				for k in int(half * 2 / 1.2) - 1:
					_scatter(NATURE + ("Plant_1.gltf" if row % 2 else "Clover_1.gltf"), Vector3(-half + 1.2 + k * 1.2, 0, -7 - row * 1.8), rng.randf_range(0.5, 0.75))
				box(y, Vector3(0, 0.03, -7 - row * 1.8), Vector3(half * 2 - 1, 0.04, 0.8), Color("4a3d2b"), false)
		1:
			_laundry(y, Vector3(-half + 1, 0, -9), Vector3(half - 1, 0, -10))
			_tree(y, NATURE + "CommonTree_%d.gltf" % rng.randi_range(1, 5), Vector3(half - 2.5, 0, -12.5), rng.randf_range(0.7, 0.95))
		2:
			_shed(y, Vector3(-half + 2.5, 0, -12.2), 0)
			_tree(y, NATURE + "Pine_%d.gltf" % rng.randi_range(1, 5), Vector3(half - 2.5, 0, -9), rng.randf_range(0.8, 1.1))
		_:
			_tree(y, NATURE + "DeadTree_%d.gltf" % rng.randi_range(1, 5), Vector3(0, 0, -11), rng.randf_range(0.5, 0.65))
			asset(y, "Prop_Woodstack_01", Vector3(-half + 1.3, 0, -9.5), 0, true)
	for i in 10:
		_scatter(NATURE + ("Grass_Common_Short.gltf" if i % 3 else "Grass_Wispy_Tall.gltf"), Vector3(rng.randf_range(-half, half), 0, rng.randf_range(-14, -5)), rng.randf_range(0.6, 1.1))
	if rng.randf() < 0.35:
		_glb(y, BK + ("SM_Borgo_Barrel_Water.glb" if rng.randf() < 0.5 else "SM_Borgo_Barrel_Water_Open.glb"), Vector3(half - 1.2, 0, -5.8), 0, 1.0, true)


func _street(key: String) -> void:
	var d: Vector2 = DIRS[key]
	var dir := Vector3(d.x, 0, d.y)
	var side_v := Vector3(-d.y, 0, d.x)
	var length := STREET_LEN if key != "E" else 72.0
	var t := PLAZA + 11.0
	var poles := []
	while t < PLAZA + length - 6.0:
		for s in [-1, 1]:
			var front = side_v * s
			var center = dir * t + front * (STREET + 3.0 + 4.5 + rng.randf_range(0, 1.5))
			var yaw := atan2(-front.x, -front.z)
			var roll := rng.randf()
			var lot = center
			if roll < 0.12:
				_home(center, yaw, 3, 4)          # casa bruciata ma ancora in piedi
			elif roll < 0.3:
				_ruin(center, yaw, rng.randi_range(2, 3))
			else:
				var w := 3 if roll < 0.62 else (2 if roll < 0.82 else 4)
				var style := 0
				var sr := rng.randf()
				if w == 4:
					style = 2
				elif sr < 0.28:
					style = 1                 # tetto piatto (sputatori)
				elif sr < 0.4:
					style = 3                 # casa alta
				_home(center, yaw, w, style)
				if roll < 0.9:
					_backyard(center, yaw, w)
			# davanti alla casa, sul bordo della via
			var edge = dir * (t + rng.randf_range(-4, 4)) + front * (STREET + 0.8)
			if rng.randf() < 0.35:
				_junk(geo, edge)
			if rng.randf() < 0.25:
				_blood(geo, dir * (t + rng.randf_range(-6, 6)) + front * rng.randf_range(0, STREET), rng.randf_range(0.6, 1.2))
			for i in 4:
				_scatter(NATURE + ["Grass_Wispy_Short.gltf", "Grass_Common_Short.gltf", "Grass_Wispy_Tall.gltf", "Clover_2.gltf"][i],
					dir * (t + rng.randf_range(-7, 7)) + front * (STREET + rng.randf_range(0.2, 2.6)), rng.randf_range(0.5, 1.0))
			lot = lot
		# auto abbandonate ai margini della via: in mezzo il 4×4 passa sempre
		if rng.randf() < 0.3:
			var s := -1 if rng.randf() < 0.5 else 1
			var car = BK + ["SM_Borgo_Car_Wreck.glb", "SM_Borgo_Car_Wreck_Red.glb", "SM_Borgo_Police_Wreck.glb", "SM_Borgo_Truck_Wreck.glb"][rng.randi_range(0, 3) if rng.randf() < 0.85 else 0]
			_glb(geo, car, dir * (t + 8) + side_v * s * 3.5, atan2(dir.x, dir.z) + rng.randf_range(-0.14, 0.14))
		if rng.randf() < 0.3:
			_puddle(geo, dir * (t + rng.randf_range(-6, 6)) + side_v * rng.randf_range(-2.5, 2.5))
		if rng.randf() < 0.18:
			_fire(geo, dir * (t + 5) + side_v * (STREET + 1.2) * (-1 if rng.randf() < 0.5 else 1))
		poles.append(dir * t + side_v * (STREET + 1.6))
		street_points.append(dir * (t + rng.randf_range(-4, 4)) + side_v * rng.randf_range(-2.5, 2.5))
		street_points.append(dir * (t + 8) + side_v * rng.randf_range(-2.5, 2.5))
		_streetlamp(geo, dir * (t + 8) - side_v * (STREET + 1.2), atan2(side_v.x, side_v.z))
		t += 16.0 + rng.randf_range(0, 2.0)
	var last := Vector3.ZERO
	for i in poles.size():
		var top := _pole(geo, poles[i], atan2(dir.x, dir.z))
		if i > 0:
			_wires(geo, last, top)
		last = top


# ================================================================== fine delle vie
func _church() -> void:
	# fine via N: chiesa con campanile e cimitero
	var c := _node(geo, Vector3(0, 0, -(PLAZA + STREET_LEN + 12)), 0, "Chiesa")
	var hs := 1.7
	_floor(c, 4, 3)
	_walls(c, 4, 3, false, hs)
	for i in 4:
		asset(c, "Bld_Wall_Brick_Door_01" if i == 1 or i == 2 else "Bld_Wall_Brick_Window_01", Vector3(-6 + i * 3, 0, 4.5), 0, true, Vector3(1, hs, 1))
	_roof(c, 4, 3 * hs + 0.05)
	_entry_ramp(c, 6.2)
	# campanile
	var tw := _node(c, Vector3(-7.5, 0, 3.0), 0, "Campanile")
	for level in 3:
		for side in 4:
			var yaw := side * PI / 2
			var off := Vector3(0, level * 3.0, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 1.5
			var piece := "Bld_Wall_Brick_01" if level < 2 else "Bld_Wall_Brick_Window_01"
			var w := asset(tw, piece, off - Vector3(cos(yaw), 0, -sin(yaw)) * 1.5, yaw, true)
			w.rotation.y = yaw
	box(tw, Vector3(0, 9.1, 0), Vector3(3.5, 0.25, 3.5), Color("5d5f55"), true)
	var spire := MeshInstance3D.new()
	tw.add_child(spire)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.3
	cone.height = 4.0
	cone.radial_segments = 4
	spire.mesh = cone
	spire.position = Vector3(0, 11.2, 0)
	spire.rotation.y = PI / 4
	spire.material_override = Props.material(Color("403e34"))
	var bell := Props.cylinder(tw, Vector3(0, 7.6, 0), 0.45, 0.7, Color("8a6a2e"), 0.7)
	bell.name = "Campana"
	_tilted(tw, Vector3(0, 13.6, 0), Vector3(0.1, 1.2, 0.1), Color("2f3533"), Vector3.ZERO)
	_tilted(tw, Vector3(0, 13.7, 0), Vector3(0.6, 0.1, 0.1), Color("2f3533"), Vector3.ZERO)
	signboard(c, Vector3(0, 3 * hs + 0.8, 4.8), "CHIESA DI SAN ROCCO", 6)
	# panche dentro, alcune ribaltate
	for row in 4:
		for s in [-1, 1]:
			var b := Vector3(s * 2.6, 0.08, 2.0 - row * 1.6)
			_bench(c, b, 0)
			if rng.randf() < 0.3:
				c.get_child(c.get_child_count() - 1).rotation.z = PI / 2
	box(c, Vector3(0, 0.55, -3.5), Vector3(2.6, 1.0, 1.0), Color("b5ac89"), true)   # altare
	for i in 6:
		_blood(c, Vector3(rng.randf_range(-4, 4), 0.06, rng.randf_range(-3, 3)), 0.8)
	# cimitero a est della chiesa
	var cem := _node(geo, Vector3(24, 0, -(PLAZA + STREET_LEN + 8)), 0, "Cimitero")
	_fence_line(cem, Vector3(-10, 0, -10), Vector3(10, 0, -10), 0.2)
	_fence_line(cem, Vector3(10, 0, -10), Vector3(10, 0, 10), 0.2)
	_fence_line(cem, Vector3(-10, 0, 10), Vector3(-10, 0, -10), 0.2)
	for gx in range(-3, 4):
		for gz in range(-2, 3):
			if rng.randf() < 0.2:
				continue
			var g := Vector3(gx * 2.6 + rng.randf_range(-0.2, 0.2), 0, gz * 3.4)
			if rng.randf() < 0.55:
				var cross := _node(cem, g, rng.randf_range(-0.1, 0.1))
				box(cross, Vector3(0, 0.7, 0), Vector3(0.12, 1.4, 0.12), Color("8c897e"), true)
				box(cross, Vector3(0, 1.05, 0), Vector3(0.6, 0.12, 0.12), Color("8c897e"), false)
				cross.rotation.z = rng.randf_range(-0.15, 0.15)
			else:
				var stone := box(cem, g + Vector3(0, 0.5, 0), Vector3(0.8, 1.0, 0.18), Color("77746a").darkened(rng.randf_range(0, 0.2)), true)
				stone.rotation.x = rng.randf_range(-0.12, 0.12)
			var mound := box(cem, g + Vector3(0, 0.08, 1.1), Vector3(0.9, 0.16, 1.8), Color("4a3d2b"), false)
			if rng.randf() < 0.25:
				mound.scale.y = 0.2      # tomba aperta: qualcosa è uscito
				box(cem, g + Vector3(0, 0.02, 1.1), Vector3(0.8, 0.02, 1.6), Color("0d0c0b"), false)
	for i in 3:
		_tree(cem, NATURE + "DeadTree_%d.gltf" % rng.randi_range(1, 5), Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)), rng.randf_range(0.5, 0.7))
	for i in 30:
		_scatter(NATURE + ("Grass_Wispy_Tall.gltf" if i % 2 else "Mushroom_Common.gltf"), Vector3(rng.randf_range(-9, 9), 0, rng.randf_range(-9, 9)), rng.randf_range(0.5, 1.0))
	_perch(c, Vector3(-7.5, 9.35, 3.0))             # sputatore sul campanile


func _refugee_camp() -> void:
	# fine via O: campo profughi travolto, con torretta di guardia
	var camp := _node(geo, Vector3(-(PLAZA + STREET_LEN + 10), 0, 0), 0, "CampoProfughi")
	for i in 9:
		var ang := i * TAU / 9 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(8, 13)
		var tent := _glb(camp, BK + ["SM_Borgo_Tent_Dome.glb", "SM_Borgo_Tent_Dome.glb", "SM_Borgo_Tent_Dome_Orange.glb", "SM_Borgo_Tent_Dome_Blue.glb"][rng.randi_range(0, 3)], Vector3(cos(ang) * r, 0, sin(ang) * r), -ang + PI / 2, rng.randf_range(1.2, 1.6))
		if rng.randf() < 0.25:
			tent.rotation.z = 0.5        # tenda crollata
	var fire := _node(camp, Vector3.ZERO)
	Props.cooking_station(fire)
	for i in 8:
		var ang := i * TAU / 8
		var st := box(fire, Vector3(cos(ang) * 0.8, 0.1, sin(ang) * 0.8), Vector3(0.3, 0.2, 0.25), Color("5c5a52"), false)
		st.rotation.y = ang
	var embers := OmniLight3D.new()
	fire.add_child(embers)
	embers.position = Vector3(0, 0.6, 0)
	embers.light_color = Color("ff8a3a")
	embers.light_energy = 1.4
	embers.omni_range = 7
	embers.set_meta("base", 1.4)
	fires.append(embers)
	for i in 4:
		_glb(camp, BK + "SM_Borgo_Log.glb", Vector3(cos(i * TAU / 4) * 2.4, 0.2, sin(i * TAU / 4) * 2.4), i * PI / 2 + PI / 2, 1.0, true)
	_sandbags(camp, Vector3(0, 0, -15), 12, 0)
	_sandbags(camp, Vector3(0, 0, 15), 12, 0)
	_sandbags(camp, Vector3(-15, 0, 0), 10, PI / 2)
	for i in 6:
		_crate(camp, Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)), rng.randf_range(0, TAU))
		_glb(camp, BK + "SM_Borgo_Barrel_Water.glb", Vector3(rng.randf_range(-11, 11), 0, rng.randf_range(-11, 11)), 0, 1.0, true)
	_laundry(camp, Vector3(-6, 0, 6), Vector3(-1, 0, 9))
	for i in 5:
		_blood(camp, Vector3(rng.randf_range(-10, 10), 0.02, rng.randf_range(-10, 10)), 1.2)
	# torretta: 4 pali, piattaforma, parapetto, scala
	var tw := _node(camp, Vector3(-11, 0, -11), PI / 4, "Torretta")
	for x in [-1.4, 1.4]:
		for z in [-1.4, 1.4]:
			box(tw, Vector3(x, 2.5, z), Vector3(0.22, 5.0, 0.22), Color("4d3f2d"), true)
	box(tw, Vector3(0, 5.0, 0), Vector3(3.4, 0.2, 3.4), Color("6e5435"), true)
	for s in [-1, 1]:
		box(tw, Vector3(s * 1.65, 5.55, 0), Vector3(0.1, 0.9, 3.4), Color("665036"), true)
		box(tw, Vector3(0, 5.55, s * 1.65), Vector3(3.4, 0.9, 0.1), Color("665036"), true)
	_tilted(tw, Vector3(0, 6.6, 0), Vector3(3.8, 0.1, 3.8), Color("4c5d5b"), Vector3(0.08, 0, 0))
	for side in [-0.38, 0.38]: box(tw, Vector3(side, 2.5, 1.55), Vector3(0.07, 5.0, 0.07), Color("4d3f2d"), false)    # montanti della scala
	for k in 10:
		box(tw, Vector3(0, 0.3 + k * 0.48, 1.55), Vector3(0.7, 0.06, 0.06), Color("4d3f2d"), false)    # scala
	_perch(tw, Vector3(0, 5.2, 0))
	for side in [-3.0, 3.0]: box(camp, Vector3(8 + side, 0.9, -16.05), Vector3(0.14, 1.8, 0.14), Color("4d3f2d"), true)    # pali del cartello
	signboard(camp, Vector3(8, 1.6, -16), "ZONA DI RACCOLTA · PROTEZIONE CIVILE", 7)
	for i in 60:
		_scatter(NATURE + ["Grass_Wispy_Short.gltf", "Grass_Common_Tall.gltf", "Plant_7.gltf"][i % 3], Vector3(rng.randf_range(-18, 18), 0, rng.randf_range(-18, 18)), rng.randf_range(0.5, 1.1))


func _farm() -> void:
	# fine via S: fienile, serbatoio dell'acqua, campi e balle di fieno
	var f := _node(geo, Vector3(-20, 0, PLAZA + STREET_LEN - 6), 0, "Fattoria")
	var barn := _node(f, Vector3(0, 0, 0), PI / 2, "Fienile")
	_floor(barn, 4, 3)
	_walls(barn, 4, 3, true, 1.45)
	for i in 4:
		if i == 1 or i == 2:
			continue
		asset(barn, "Bld_Wall_Metal_01", Vector3(-6 + i * 3, 0, 4.5), 0, true, Vector3(1, 1.45, 1))
	box(barn, Vector3(0, 3.6, 4.5), Vector3(6, 1.1, 0.22), Color("7a3328"), true)
	_roof(barn, 4, 3 * 1.45 + 0.05)
	_entry_ramp(barn, 6.2)
	for i in 6:
		var hay := box(barn, Vector3(rng.randf_range(-4, 4), 0.5, rng.randf_range(-3, 1)), Vector3(1.4, 0.9, 1.0), Color("c2a85a").darkened(rng.randf_range(0, 0.15)), true)
		hay.rotation.y = rng.randf_range(-0.3, 0.3)
	# serbatoio
	var tank := _node(f, Vector3(14, 0, -8), 0, "Serbatoio")
	for x in [-1.6, 1.6]:
		for z in [-1.6, 1.6]:
			box(tank, Vector3(x, 3.5, z), Vector3(0.2, 7.0, 0.2), Color("4e5546"), true)
	box(tank, Vector3(0, 7.05, 0), Vector3(4.0, 0.2, 4.0), Color("4e5546"), true)
	Props.cylinder(tank, Vector3(0, 8.6, 0), 1.9, 2.9, Color("6b7a74"), 0.4)
	var cap := MeshInstance3D.new()
	tank.add_child(cap)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 2.0
	cm.height = 0.8
	cap.mesh = cm
	cap.position.y = 10.45
	cap.material_override = Props.material(Color("4c5d5b"), 0.4)
	_perch(tank, Vector3(1.3, 7.25, 1.3))
	# campi coltivati (abbandonati) e balle di fieno
	for row in 10:
		box(f, Vector3(-22, 0.03, -14 + row * 2.6), Vector3(18, 0.05, 1.1), Color("4a3d2b"), false)
		for k in 12:
			_scatter(NATURE + ("Plant_1.gltf" if row % 3 else "Grass_Common_Tall.gltf"), Vector3(-30 + k * 1.5 + rng.randf_range(-0.3, 0.3), 0.05, -14 + row * 2.6), rng.randf_range(0.6, 0.9))
	_fence_line(f, Vector3(-32, 0, -16), Vector3(-12, 0, -16), 0.2)
	_fence_line(f, Vector3(-32, 0, 12), Vector3(-32, 0, -16), 0.2)
	for i in 6:
		var hay := Props.cylinder(f, Vector3(rng.randf_range(4, 16), 0.65, rng.randf_range(2, 14)), 0.7, 1.2, Color("c2a85a").darkened(rng.randf_range(0, 0.15)))
		hay.rotation.z = PI / 2
		hay.rotation.y = rng.randf_range(0, TAU)
		hay.create_trimesh_collision()
	_glb(f, BK + "SM_Borgo_Truck_Wreck.glb", Vector3(10, 0, 8), 2.2)
	# spaventapasseri
	var sc := _node(f, Vector3(-22, 0, -2), 0.4, "Spaventapasseri")
	box(sc, Vector3(0, 1.1, 0), Vector3(0.1, 2.2, 0.1), Color("4b4134"), false)
	box(sc, Vector3(0, 1.7, 0), Vector3(1.4, 0.08, 0.08), Color("4b4134"), false)
	box(sc, Vector3(0, 1.55, 0), Vector3(0.55, 0.7, 0.3), Color("6b5a3a"), false)
	box(sc, Vector3(0, 2.15, 0), Vector3(0.32, 0.32, 0.32), Color("c7b27a"), false)
	box(sc, Vector3(0, 2.38, 0), Vector3(0.6, 0.06, 0.6), Color("4b4134"), false)


func _checkpoint() -> void:
	# fine via E: posto di blocco sulla strada asfaltata, auto della polizia, coni, cartello del paese
	var cp := _node(geo, Vector3(PLAZA + 72.0 - 4, 0, 0), 0, "PostoDiBlocco")
	for z in [-6.5, 6.5]:
		var bar := _glb(cp, BK + "SM_Borgo_Road_Barrier.glb", Vector3(0, 0, z), PI / 2, 1.0, true)
		bar.name = "Barriera"
	_glb(cp, BK + "SM_Borgo_Police_Wreck.glb", Vector3(-7, 0, 9.5), 0.4)
	for i in 6:
		asset(cp, "Prop_Cone_01", Vector3(rng.randf_range(-3, 3), 0.2, rng.randf_range(-3, 3)), 0, false, Vector3.ONE * 1.8)
	_sandbags(cp, Vector3(-3, 0, -11), 6, PI / 2)
	_sandbags(cp, Vector3(-3, 0, 11), 6, PI / 2)
	_fire(cp, Vector3(-6, 0, -8))
	# arco d'ingresso del paese
	var arch := _node(geo, Vector3(PLAZA + 50, 0, 0), PI / 2, "ArcoIngresso")
	for x in [-5.5, 5.5]:
		box(arch, Vector3(x, 2.4, 0), Vector3(0.35, 4.8, 0.35), Color("4d3f2d"), true)
	var sign := signboard(arch, Vector3(0, 4.6, 0.2), "BORGO CENERE", 7)
	sign.rotation.z = 0.06
	var sub := signboard(arch, Vector3(0, 3.8, 0.2), "ABITANTI 312 · 0", 4)
	sub.rotation.z = -0.04


func _woods() -> void:
	# fuori dal paese: lo stesso bosco della mappa (pini), qualche albero secco, cespugli, sassi
	var trees := FOREST + ["DeadTree_2", "DeadTree_4"]
	var count := 0
	var tries := 0
	while count < 230 and tries < 4000:
		tries += 1
		var ang := rng.randf_range(0, TAU)
		var r := rng.randf_range(62, L.FLAT + 30)
		var at := Vector3(cos(ang) * r, 0, sin(ang) * r)
		if _busy(at):
			continue
		at.y = _ground_local(at)
		var pick: String = trees[rng.randi_range(0, trees.size() - 1)]
		if pick.begins_with("Dead"):
			_tree(geo, NATURE + pick + ".gltf", at, rng.randf_range(0.5, 0.75))
		else:
			_tree(geo, NATURE + pick + ".gltf", at, rng.randf_range(0.8, 1.35))
		count += 1
	for i in 90:
		var ang := rng.randf_range(0, TAU)
		var at := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(55, L.FLAT + 25)
		if _busy(at):
			continue
		at.y = _ground_local(at)
		_glb(geo, NATURE + ("Plant_7_Big.gltf" if rng.randf() < 0.5 else "Plant_1_Big.gltf"), at, rng.randf_range(0, TAU), rng.randf_range(0.5, 0.9), false)
	for i in 900:
		var at := Vector3(rng.randf_range(-L.FLAT - 20, L.FLAT + 20), 0, rng.randf_range(-L.FLAT - 20, L.FLAT + 20))
		# Fuori da vie, case, negozi e piazza: niente erba che spunta dal pavimento.
		if at.length() > L.FLAT + 25 or _busy(at) or (absf(at.x) < PLAZA + 2 and absf(at.z) < PLAZA + 2):
			continue
		at.y = _ground_local(at)
		var file = NATURE + ["Grass_Wispy_Short.gltf", "Grass_Wispy_Tall.gltf", "Grass_Common_Short.gltf", "Grass_Common_Tall.gltf", "Grass_Common_Tall.gltf",
			"Fern_1.gltf", "Fern_1.gltf", "Flower_3_Single.gltf", "Flower_4_Single.gltf", "Pebble_Round_2.gltf", "Mushroom_Common.gltf", "Clover_1.gltf"][i % 12]
		_scatter(file, at, rng.randf_range(0.6, 1.2))
	for i in 40:
		var ang := rng.randf_range(0, TAU)
		var at := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(58, L.FLAT + 20)
		if _busy(at):
			continue
		at.y = _ground_local(at)
		var s := rng.randf_range(0.6, 1.3)
		# Nessuna collisione qui: solid_props.apply decide dal vero ingombro (sassi piccoli = attraversabili).
		_glb(geo, NATURE + "Rock_Medium_%d.gltf" % rng.randi_range(1, 3), at, rng.randf_range(0, TAU), s, false)


## Quota del terreno per un punto locale a geo (geo sta in L.CENTER, y = 0).
func _ground_local(at: Vector3) -> float:
	if world == null or world.get("terrain") == null:
		return at.y
	return float(world.terrain.height(at.x + L.CENTER.x, at.z + L.CENTER.z))


func _on_street(at: Vector3) -> bool:
	if absf(at.x) < STREET + 1.5 and absf(at.z) < PLAZA + STREET_LEN + 2:
		return true
	if absf(at.z) < STREET + 1.5 and at.x > -(PLAZA + STREET_LEN + 2) and at.x < PLAZA + 74:
		return true
	return false


## punto occupato da case, vie, piazza o luoghi speciali (per alberi e sassi)
func _busy(at: Vector3) -> bool:
	if _on_street(at):
		return true
	var axis_n := absf(at.x) < 28.0 and absf(at.z) < PLAZA + STREET_LEN + 28
	var axis_e := absf(at.z) < 28.0 and at.x > -(PLAZA + STREET_LEN + 30) and at.x < PLAZA + 80
	if axis_n or axis_e:
		return true
	if at.distance_to(Vector3(24, 0, -(PLAZA + STREET_LEN + 8))) < 14:
		return true
	if at.distance_to(Vector3(-20, 0, PLAZA + STREET_LEN - 6)) < 40:
		return true
	# la strada asfaltata che taglia l'angolo sud-est
	var world_p := Vector2(at.x + L.CENTER.x, at.z + L.CENTER.z)
	return preload("res://world/campaign/route.gd").road_distance(world_p) < 12


func _road_signs() -> void:
	# cartello all'incrocio vicino al rifugio
	var at := Vector3(12, 0, -150)
	if world.get("terrain"):
		at.y = world.terrain.height(at.x, at.z)
	var post := _node(self, at, 0.6)
	box(post, Vector3(0, 1.3, 0), Vector3(0.12, 2.6, 0.12), Color("4b5041"), true)
	signboard(post, Vector3(0, 2.4, 0.08), "BORGO CENERE  ↗  250 m", 5)
	var warn := signboard(post, Vector3(0, 1.75, 0.08), "PERICOLO · INFETTI", 3.6)
	warn.rotation.z = -0.05


# ================================================================== navigazione
func _bake() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.5
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.filter_baking_aabb = AABB(L.CENTER + Vector3(-L.FLAT - 10, -1.5, -L.FLAT - 10), Vector3(L.FLAT * 2 + 20, 16, L.FLAT * 2 + 20))
	nav.navigation_mesh = nm
	nav.bake_navigation_mesh(true)


# ================================================================== boss UI
func _boss_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var box2 := VBoxContainer.new()
	box2.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box2.position = Vector2(-310, 96)
	box2.custom_minimum_size = Vector2(620, 0)
	_ui.add_child(box2)
	var label := Label.new()
	label.text = BOSS_NAME
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("e8c27a"))
	box2.add_child(label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(620, 18)
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("9e2a1d")
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", bg)
	box2.add_child(_bar)
	_ui.visible = false


func _update_boss_bar() -> void:
	var b: Node3D = null
	for e in world.targets:
		if is_instance_valid(e) and e.kind == 5 and not e.dead and e.global_position.distance_to(L.CENTER) < 60:
			b = e
			break
	var p: CharacterBody3D = world.player
	var was_visible: bool = _ui.visible
	_ui.visible = b != null and is_instance_valid(p) and b.global_position.distance_to(p.global_position) < 50
	if _ui.visible != was_visible:
		if _ui.visible: AudioManager.start_boss(BOSS_MUSIC, BOSS_NAME)
		else: AudioManager.end_boss(BOSS_MUSIC)
	if _ui.visible:
		_bar.max_value = b.max_health
		_bar.value = b.health


# ================================================================== gioco (host)
func in_town(p: Vector3) -> bool:
	return Vector2(p.x - L.CENTER.x, p.z - L.CENTER.z).length() < 95.0


func in_plaza(p: Vector3) -> bool:
	return absf(p.x - L.CENTER.x) < PLAZA - 0.8 and absf(p.z - L.CENTER.z) < PLAZA - 0.8


func reset() -> void:
	for e in town_enemies + arena_enemies:
		if is_instance_valid(e):
			e.queue_free()
	town_enemies.clear()
	arena_enemies.clear()
	boss = null
	boss_phase = 0
	state = "idle"
	arena = "idle"
	for ch in chests:
		ch.looted = false
		ch.lid.visible = true
		ch.tag.visible = false
	barricade_up = true
	set_barricades(false)
	_place_supplies()


## Scaffali dei negozi: scatolette da raccogliere. Vale la pena frugare prima dello scontro.
func _place_supplies() -> void:
	if not _is_host() or not world.get("zone_life"): return
	for at in supplies: world.zone_life.add_pickup(L.CENTER + at, "can")


## Scritta a schermo vicino al pozzo e alle casse.
func context(actor: CharacterBody3D) -> String:
	if not is_instance_valid(actor): return ""
	if arena == "cleared":
		for ch in chests:
			if not ch.looted and actor.global_position.distance_to(ch.pos) < 2.4:
				return Localization.t("E  APRI {0}", [Localization.t("LA CASSA MEDICA" if ch.heal else "LA CASSA DEL BORGO")])
		return ""
	if actor.global_position.distance_to(L.CENTER) > L.WELL_REACH or arena != "idle": return ""
	if not world.quest.can_summon(1): return "IL POZZO È IN SILENZIO · PARLA CON LO SCERIFFO"
	if actor.baits > 0: return "E  GETTA L'ESCA NEL POZZO · SVEGLIA IL MACELLAIO"
	return "TI SERVE UN'ESCA · CHIEDILA ALLO SCERIFFO"


func _spawn(kind: int, local_at: Vector3, list: Array, on_roof := false) -> Node3D:
	var at := L.CENTER + local_at
	if not on_roof:
		at = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, at) if nav.navigation_mesh and nav.navigation_mesh.get_polygon_count() > 0 else at
	var e: Node3D = world._spawn_enemy(at)
	e.set_kind(kind, 1)
	e.home = at
	list.append(e)
	var near: CharacterBody3D = world.nearest_player(at)
	if near and near.global_position.distance_to(at) < 35:
		e.hear(near, 35)
	return e


func _populate_town() -> void:
	state = "active"
	world.announce("BORGO CENERE · Il paese è infestato. Attenti ai tetti: gli sputatori vi vedono da lontano.", 6)
	var pts := street_points.duplicate()
	pts.shuffle()
	for i in mini(18, pts.size()):
		var roll := rng.randf()
		var kind := 0
		if roll > 0.9:
			kind = 2          # bruto
		elif roll > 0.75:
			kind = 1          # corridore
		elif roll > 0.65:
			kind = 3          # élite
		_spawn(kind, pts[i], town_enemies)
	var roofs := perches.duplicate()
	roofs.shuffle()
	for i in mini(7, roofs.size()):
		_spawn(4, geo.to_local((roofs[i] as Marker3D).global_position) + Vector3(0, 0.1, 0), town_enemies, true)
	# qualche infetto già in piazza, intorno al pozzo
	for i in 4:
		var ang := i * TAU / 4 + 0.4
		_spawn(0, Vector3(cos(ang) * 9, 0, sin(ang) * 9), town_enemies)


func _start_arena() -> void:
	arena = "active"
	set_barricades(true)
	world.announce("LA PIAZZA SI CHIUDE · Dal pozzo sale qualcosa di enorme...", 5)
	get_tree().create_timer(2.4).timeout.connect(func() -> void:
		if arena != "active":
			return
		boss = _spawn(5, Vector3(0, 0, 0.5), arena_enemies, true)
		boss.set_meta("borgo", true)
		# Il Macellaio ha il suo corpo e la sua mannaia, non è il Carceriere ridipinto.
		boss.custom_skin = "res://art/zx_infected/BOSS_Subject_Zero.glb"
		boss.boss_weapon = "cleaver"
		boss._dress()
		boss.title = BOSS_NAME
		boss.max_health = 950.0
		boss.health = 950.0
		boss.use_brain("macellaio")
		boss.alert_time = 2.1
		boss_phase = 0
		empty_time = 0.0
		world.announce(Localization.t("{0} SI SVEGLIA", [Localization.t(BOSS_NAME)]), 4)
		_burst(Vector3.ZERO)
		for m in plaza_perches.slice(0, 2):
			_spawn(4, geo.to_local((m as Marker3D).global_position) + Vector3(0, 0.1, 0), arena_enemies, true))


func _burst(local_at: Vector3) -> void:
	var s := Props.smoke(geo, local_at + Vector3(0, 0.5, 0), 3.0, 0.5, 24)
	s.one_shot = true
	s.explosiveness = 0.9
	s.initial_velocity_min = 2.0
	s.initial_velocity_max = 4.0
	s.spread = 60
	get_tree().create_timer(6.0).timeout.connect(s.queue_free)


func _arena_logic(dt: float) -> void:
	if arena != "active":
		return
	var anyone := false
	for a in world.actors.values():
		if is_instance_valid(a) and not a.dead and in_plaza(a.global_position):
			anyone = true
	if is_instance_valid(boss) and boss.dead:
		_arena_won()
		return
	if not is_instance_valid(boss):
		# il boss non è ancora uscito (timer) oppure è stato liberato da un reset
		if not anyone:
			empty_time += dt
		if empty_time > 20.0:
			_arena_reset()
		return
	var frac: float = boss.health / boss.max_health
	if boss_phase == 0 and frac < 0.66:
		boss_phase = 1
		boss.alert_time = 1.6
		world.announce("Il Macellaio chiama il paese! Altri infetti scavalcano le barricate.", 4)
		for key in DIRS:
			var d: Vector2 = DIRS[key]
			_spawn(0 if key != "E" else 1, Vector3(d.x, 0, d.y) * (PLAZA - 3.0), arena_enemies)
		for m in plaza_perches.slice(2, 5):
			_spawn(4, geo.to_local((m as Marker3D).global_position) + Vector3(0, 0.1, 0), arena_enemies, true)
	elif boss_phase == 1 and frac < 0.33:
		boss_phase = 2
		boss.alert_time = 1.6
		boss.anim_scale = 0.9
		world.announce("FURIA · Il Macellaio perde il controllo!", 4)
		_spawn(2, Vector3(-PLAZA + 4, 0, 0), arena_enemies)
		_spawn(1, Vector3(PLAZA - 4, 0, 0), arena_enemies)
		_spawn(1, Vector3(0, 0, PLAZA - 4), arena_enemies)
		for m in plaza_perches.slice(5, 9):
			_spawn(4, geo.to_local((m as Marker3D).global_position) + Vector3(0, 0.1, 0), arena_enemies, true)
	if not anyone:
		empty_time += dt
		if empty_time > 20.0:
			_arena_reset()
	else:
		empty_time = 0.0


func _arena_won() -> void:
	arena = "cleared"
	set_barricades(false)
	for ch in chests:
		ch.tag.visible = not ch.looted
	if world.get("quest"): world.quest.on_boss(1)
	_push_state()


func _arena_reset() -> void:
	for e in arena_enemies:
		if is_instance_valid(e):
			e.queue_free()
	arena_enemies.clear()
	boss = null
	boss_phase = 0
	empty_time = 0.0
	arena = "idle"
	set_barricades(false)
	var back: Node3D = bait_actor if is_instance_valid(bait_actor) else world.player
	back.baits += 1
	world.announce("Il Macellaio è tornato nel pozzo. L'esca è ancora buona: riprovaci.", 5)
	if world.get("survival"): world.survival._publish()
	_push_state()


func request_use(actor: CharacterBody3D) -> bool:
	if not is_instance_valid(actor):
		return false
	if arena == "idle" and actor.global_position.distance_to(L.CENTER) <= L.WELL_REACH and world.quest.can_summon(1) and actor.baits > 0:
		if _is_host():
			_do(actor, -1)
		else:
			_ask.rpc_id(1, -1)
		return true
	if arena != "cleared":
		return false
	for i in chests.size():
		if not chests[i].looted and actor.global_position.distance_to(chests[i].pos) < 2.4:
			if _is_host():
				_do(actor, i)
			else:
				_ask.rpc_id(1, i)
			return true
	return false


@rpc("any_peer", "call_remote", "reliable")
func _ask(index: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if world.actors.has(peer):
		_do(world.actors[peer], index)


func _do(actor: CharacterBody3D, index: int) -> void:
	if index == -1:
		if arena != "idle" or actor.global_position.distance_to(L.CENTER) > L.WELL_REACH + 1.0 or not world.quest.can_summon(1) or actor.baits <= 0:
			return
		actor.baits -= 1
		bait_actor = actor
		if world.get("survival"): world.survival._publish()
		_start_arena()
		_push_state()
		return
	if index < 0 or index >= chests.size() or arena != "cleared":
		return
	var ch: Dictionary = chests[index]
	if ch.looted or actor.global_position.distance_to(ch.pos) > 3.0:
		return
	ch.looted = true
	ch.lid.visible = false
	ch.tag.visible = false
	if ch.heal:
		actor.health = load("res://autoload/balance.gd").PLAYER_MAX_HEALTH
		world.announce("Cassa medica: salute al massimo.", 3)
	else:
		actor.credits += ch.amount
		world.announce("Cassa del borgo: +%d crediti." % ch.amount, 3)
	if world.get("survival"):
		world.survival._publish()
	_push_state()


func _process(delta: float) -> void:
	if not world or not world.get("started"):
		return
	var t := Time.get_ticks_msec() * 0.001
	for i in fires.size():
		fires[i].light_energy = fires[i].get_meta("base", 2.0) * (0.8 + 0.2 * sin(t * 11.0 + i * 1.9) * sin(t * 7.0 + i))
	_update_boss_bar()
	if not _is_host():
		return
	_poll -= delta
	if _poll > 0:
		return
	_poll = 0.25
	var near := false
	var town := false
	for a in world.actors.values():
		if not is_instance_valid(a) or a.dead:
			continue
		var pos: Vector3 = a.global_position
		if Vector2(pos.x - L.CENTER.x, pos.z - L.CENTER.z).length() < 170:
			near = true
		if in_town(pos):
			town = true
	if state == "idle" and town:
		_populate_town()
	elif state == "active":
		var alive := 0
		for e in town_enemies:
			if is_instance_valid(e) and not e.dead:
				alive += 1
		if alive == 0:
			state = "cleared"
			world.announce("Le vie del borgo sono libere. Resta la piazza...", 4)
	_arena_logic(0.25)
	# il paese si ripopola se ve ne andate per un po'
	away_time = 0.0 if near else away_time + 0.25
	if away_time > 120.0 and state == "cleared":
		state = "idle"
		town_enemies.clear()


# ================================================================== rete
func _push_state() -> void:
	if not Session.online or not multiplayer.is_server():
		return
	var looted := []
	for ch in chests:
		looted.append(ch.looted)
	for peer in Session.connected_peers():
		_state.rpc_id(peer, barricade_up, looted, arena)


@rpc("authority", "call_remote", "reliable")
func _state(up: bool, looted: Array, arena_state: String) -> void:
	arena = arena_state
	set_barricades(up)
	for i in mini(looted.size(), chests.size()):
		chests[i].looted = looted[i]
		chests[i].lid.visible = not looted[i]
		chests[i].tag.visible = arena == "cleared" and not looted[i]
