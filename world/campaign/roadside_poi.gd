# Luoghi lungo la statale: fattorie, distributori, campeggi, posti di blocco, incidenti, ponti, cartelli.
# Si costruiscono quando si carica la tessera e se ne vanno con lei. Sono solo scenografia: stesso seme su host e client, nessuno stato di gioco.
# Pezzi: kit originale art/zx_borgo, natura CC0 art/nature e forme fatte in codice.
extends "res://world/villaggio/borgo_build.gd"

const Route := preload("res://world/campaign/route.gd")
const CONCRETE := Color("77746a")
const ASPHALT_DARK := Color("2c2c29")
const RUST := Color("6b4a35")
## Quota del terreno vera, impostata da terrain.gd: erba e fiori seguono i pendii.
var ground_height: Callable


## Nessuna luce e nessun fumo lontano dal borgo: resta il fusto con la brace.
func _fire(parent: Node3D, at: Vector3, _big := false) -> void:
	asset(parent, "Prop_Barrel_Metal_01", at, rng.randf_range(0, TAU), true)
	var ember := box(parent, at + Vector3(0, 1.0, 0), Vector3(0.4, 0.12, 0.4), Color("ff7a1f"), false)
	var mat: StandardMaterial3D = ember.material_override
	mat.emission_enabled = true
	mat.emission = Color("ff7a1f")
	mat.emission_energy_multiplier = 2.0


func build_place(parent: Node3D, index: int, y: float) -> Node3D:
	var place: Dictionary = Route.places()[index]
	rng.seed = 90210 + index * 131
	var holder := Node3D.new()
	holder.name = "Luogo_%d_%s" % [index, place.kind]
	parent.add_child(holder)
	holder.position = Vector3(place.at.x, y, place.at.z)
	geo = holder
	# Chi sta fuori strada guarda la strada (+Z locale); chi sta sulla strada è allineato a lei (+Z = senso di marcia).
	var aim: Vector3
	if place.kind in Route.ON_ROAD:
		aim = place.dir
	else:
		aim = Route.nearest_road(place.at) - Vector3(place.at.x, 0, place.at.z)
	holder.rotation.y = atan2(aim.x, aim.z)
	match place.kind:
		"farm": _farm_place()
		"gas": _gas_place()
		"camp": _camp_place()
		"ruin": _ruin_place()
		"mil": _military_place()
		"crash": _crash_place()
		"bridge": _bridge_place()
	_flush_multimesh()
	fit_ranges(holder)
	return holder


func build_sign(parent: Node3D, sign_data: Dictionary, y: float) -> Node3D:
	var post := Node3D.new()
	post.name = "CartelloStradale"
	parent.add_child(post)
	post.position = Vector3(sign_data.at.x, y, sign_data.at.z)
	post.rotation.y = sign_data.yaw
	box(post, Vector3(-1.9, 1.5, -0.06), Vector3(0.12, 3.0, 0.12), Color("4b5041"), true)
	box(post, Vector3(1.9, 1.5, -0.06), Vector3(0.12, 3.0, 0.12), Color("4b5041"), true)
	var lines: Array = sign_data.lines
	for i in lines.size():
		var board := signboard(post, Vector3(0, 2.6 - i * 0.78, 0), lines[i], 4.6)
		if i == lines.size() - 1: board.rotation.z = -0.025
	fit_ranges(post)
	return post


func _grass_patch(half: float, count: int) -> void:
	for i in count:
		var at := Vector3(rng.randf_range(-half, half), 0, rng.randf_range(-half, half))
		if ground_height.is_valid():
			# Segue il pendio invece di restare al livello del centro del luogo.
			var wp: Vector3 = geo.to_global(at)
			at.y = float(ground_height.call(wp.x, wp.z)) - geo.global_position.y
		_scatter(NATURE + ["Grass_Wispy_Tall.gltf", "Grass_Common_Short.gltf", "Grass_Common_Tall.gltf", "Fern_1.gltf"][i % 4], at, rng.randf_range(0.6, 1.2))


func _wreck(at: Vector3, yaw: float, file: String = "") -> Node3D:
	if file == "":
		file = ["SM_Borgo_Car_Wreck.glb", "SM_Borgo_Car_Wreck_Red.glb", "SM_Borgo_Police_Wreck.glb"][rng.randi_range(0, 2)]
	return _glb(geo, BK + file, at, yaw)


# ================================================================== fuori strada
func _farm_place() -> void:
	# casa, fienile di lamiera, capanno, recinto storto e un vecchio camion
	_home(Vector3(-6, 0, 0), rng.randf_range(-0.12, 0.12), 3, 0 if rng.randf() < 0.6 else 4)
	_home(Vector3(13, 0, -6), -0.2 + rng.randf_range(-0.1, 0.1), 4, 2)
	_shed(geo, Vector3(-18, 0, -8), 0.5)
	_fence_line(geo, Vector3(-24, 0, 12), Vector3(24, 0, 12), 0.3)
	_fence_line(geo, Vector3(-24, 0, -16), Vector3(-24, 0, 12), 0.35)
	_fence_line(geo, Vector3(24, 0, 12), Vector3(24, 0, -16), 0.35)
	_glb(geo, BK + "SM_Borgo_Truck_Wreck.glb", Vector3(7, 0, 8.5), 1.2)
	asset(geo, "Prop_Woodstack_01", Vector3(-12, 0, 6), 0.3, true)
	_glb(geo, BK + "SM_Borgo_Barrel_Water.glb", Vector3(-1, 0, 7), 0.0)
	_tree(geo, NATURE + "DeadTree_%d.gltf" % rng.randi_range(1, 5), Vector3(-20, 0, 7), rng.randf_range(0.55, 0.75))
	_tree(geo, NATURE + "Pine_%d.gltf" % rng.randi_range(1, 5), Vector3(20, 0, -14), rng.randf_range(0.9, 1.2))
	for i in 3:
		_junk(geo, Vector3(rng.randf_range(-10, 12), 0, rng.randf_range(6, 11)))
	_grass_patch(23.0, 42)


func _gas_place() -> void:
	# piazzale, pensilina su quattro pilastri, due isole con le pompe, officina e insegna
	box(geo, Vector3(0, 0.03, 6), Vector3(30, 0.05, 26), Color("45443b"), false)
	_home(Vector3(0, 0, -11), 0, 4, 2)
	for x in [-7.5, 7.5]:
		for z in [3.5, 12.5]:
			box(geo, Vector3(x, 2.6, z), Vector3(0.45, 5.2, 0.45), Color("c9c4b3"), true)
	box(geo, Vector3(0, 5.35, 8), Vector3(19, 0.5, 13), Color("b9402f"), false)
	box(geo, Vector3(0, 5.05, 8), Vector3(18.6, 0.12, 12.6), Color("d3cfbf"), false)
	for x in [-3.5, 3.5]:
		box(geo, Vector3(x, 0.1, 8), Vector3(1.5, 0.2, 7), CONCRETE, true)
		for z in [6.0, 10.0]:
			box(geo, Vector3(x, 0.95, z), Vector3(0.75, 1.5, 0.5), Color("a8362b"), true)
			box(geo, Vector3(x, 1.25, z + 0.26), Vector3(0.5, 0.42, 0.02), Color("1e2523"), false)
	# insegna alta
	box(geo, Vector3(-14, 3.6, 13), Vector3(0.3, 7.2, 0.3), Color("3e4644"), true)
	signboard(geo, Vector3(-14, 7.0, 13.2), "BENZINA", 3.6)
	signboard(geo, Vector3(-14, 6.15, 13.2), "CHIUSO", 2.2).rotation.z = -0.08
	_wreck(Vector3(7.8, 0.04, 8), 0.1)
	_wreck(Vector3(-9, 0.04, -1.5), 1.4, "SM_Borgo_Car_Wreck_Red.glb")
	for at in [Vector3(11, 0, 0), Vector3(12, 0, 1.5), Vector3(10.6, 0, 2.2)]:
		asset(geo, "Prop_Barrel_Metal_01", at, rng.randf_range(0, TAU), true)
	for i in 4:
		asset(geo, "Prop_GasCan_01", Vector3(rng.randf_range(-6, 6), 0.05, rng.randf_range(-3, 1)), rng.randf_range(0, TAU), false)
	for i in 5:
		var oil := box(geo, Vector3(rng.randf_range(-9, 9), 0.06, rng.randf_range(2, 15)), Vector3(rng.randf_range(0.8, 2.0), 0.01, rng.randf_range(0.6, 1.5)), ASPHALT_DARK, false)
		oil.rotation.y = rng.randf_range(0, TAU)
	_grass_patch(20.0, 22)


func _camp_place() -> void:
	# campeggio abbandonato in fretta: tende in cerchio, tronchi, roulotte di lamiera
	for i in 8:
		var ang := i * TAU / 8 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(9, 15)
		var tent := _glb(geo, BK + ["SM_Borgo_Tent_Dome.glb", "SM_Borgo_Tent_Dome_Orange.glb", "SM_Borgo_Tent_Dome_Blue.glb"][i % 3], Vector3(cos(ang) * r, 0, sin(ang) * r), -ang + PI / 2, rng.randf_range(1.1, 1.5))
		if rng.randf() < 0.3: tent.rotation.z = 0.45
	for i in 4:
		_glb(geo, BK + "SM_Borgo_Log.glb", Vector3(cos(i * TAU / 4) * 2.4, 0.2, sin(i * TAU / 4) * 2.4), i * PI / 2 + PI / 2)
	_fire(geo, Vector3.ZERO)
	# roulotte: scatola di lamiera con finestra, su due ruote
	var van := _node(geo, Vector3(-17, 0, -6), 0.5, "Roulotte")
	box(van, Vector3(0, 1.5, 0), Vector3(2.4, 2.1, 5.5), Color("b8b2a0"), true)
	box(van, Vector3(1.22, 1.75, 0.5), Vector3(0.03, 0.7, 1.4), Color("1e2523"), false)
	box(van, Vector3(0, 2.6, 0), Vector3(2.5, 0.12, 5.6), Color("8f897a"), false)
	for z in [-0.4]:
		for x in [-1.2, 1.2]:
			Props.cylinder(van, Vector3(x, 0.32, z), 0.32, 0.2, Color("252e2b")).rotation.z = PI / 2
	_wreck(Vector3(16, 0, 8), 2.2)
	asset(geo, "Prop_Table_Metal_01", Vector3(4, 0, 5), 0.6, true)
	asset(geo, "Prop_Chair_01", Vector3(5.6, 0, 5.6), 2.0, true).rotation.z = PI / 2
	_laundry(geo, Vector3(-8, 0, 12), Vector3(-2, 0, 15))
	box(geo, Vector3(14, 1.1, 15), Vector3(0.15, 2.2, 0.15), Color("4b4134"), true)
	signboard(geo, Vector3(14, 2.3, 15.1), "CAMPEGGIO", 3.2)
	for i in 3:
		_blood(geo, Vector3(rng.randf_range(-9, 9), 0.02, rng.randf_range(-9, 9)), 1.1)
	for i in 4:
		_junk(geo, Vector3(rng.randf_range(-11, 11), 0, rng.randf_range(-11, 11)))
	_grass_patch(21.0, 40)


func _ruin_place() -> void:
	_ruin(Vector3(-8, 0, 0), rng.randf_range(-0.2, 0.2), 3)
	_ruin(Vector3(11, 0, -4), rng.randf_range(0.1, 0.4), 2)
	_shed(geo, Vector3(-3, 0, -13), 0.2)
	_wreck(Vector3(3, 0, 9), 0.9)
	_tree(geo, NATURE + "DeadTree_%d.gltf" % rng.randi_range(1, 5), Vector3(19, 0, 5), 0.7)
	_grass_patch(22.0, 34)


# ================================================================== sulla strada: la corsia centrale (|x| < 3,6) resta sempre libera
func _military_place() -> void:
	for s in [-1, 1]:
		for z in [-9.0, 9.0]:
			_glb(geo, BK + "SM_Borgo_Road_Barrier.glb", Vector3(s * 5.4, 0, z), 0.0)
		_sandbags(geo, Vector3(s * 7.0, 0, 0), 12.0, PI / 2)
		_sandbags(geo, Vector3(s * 9.5, 0, -7.0), 5.0, 0.0)
		for z in [-14.0, -11.5, 11.5, 14.0]:
			asset(geo, "Prop_Cone_01", Vector3(s * 4.3, 0.2, z), 0, false, Vector3.ONE * 1.8)
	_glb(geo, BK + "SM_Borgo_Truck_Wreck.glb", Vector3(-11.5, 0, 6), 0.1)
	asset(geo, "Prop_Container_01", Vector3(13, 0, 7), 0.2, true, Vector3.ONE * 3.0)
	# torretta di guardia e tenda del comando
	var tw := _node(geo, Vector3(12.5, 0, -9), 0.0, "Torretta")
	for x in [-1.4, 1.4]:
		for z in [-1.4, 1.4]:
			box(tw, Vector3(x, 2.5, z), Vector3(0.22, 5.0, 0.22), Color("4d4a35"), true)
	box(tw, Vector3(0, 5.0, 0), Vector3(3.4, 0.2, 3.4), Color("5b5a3f"), true)
	for s in [-1, 1]:
		box(tw, Vector3(s * 1.65, 5.55, 0), Vector3(0.1, 0.9, 3.4), Color("55553c"), true)
		box(tw, Vector3(0, 5.55, s * 1.65), Vector3(3.4, 0.9, 0.1), Color("55553c"), true)
	_tilted(tw, Vector3(0, 6.6, 0), Vector3(3.8, 0.1, 3.8), Color("3f4433"), Vector3(0.08, 0, 0))
	_glb(geo, BK + "SM_Borgo_Tent_Dome.glb", Vector3(-13, 0, -7), 0.6, 1.7)
	box(geo, Vector3(-6.2, 1.1, -13), Vector3(0.12, 2.2, 0.12), Color("4b5041"), true)
	signboard(geo, Vector3(-6.2, 2.3, -12.9), "ALT · ESERCITO", 3.2)
	for i in 5:
		_crate(geo, Vector3(rng.randf_range(10, 14), 0, rng.randf_range(0, 4)), rng.randf_range(-0.3, 0.3), 0.8)


func _crash_place() -> void:
	# tamponamento: auto di traverso sulle banchine, vetri, sangue, coni
	for i in 3:
		var s := -1.0 if i % 2 else 1.0
		var at := Vector3(s * rng.randf_range(5.8, 7.0), 0, -10.0 + i * 9.0 + rng.randf_range(-1, 1))
		_wreck(at, rng.randf_range(0.5, 2.6))
	_glb(geo, BK + "SM_Borgo_Truck_Wreck.glb", Vector3(9.5, 0, 14), 0.5)
	for i in 6:
		asset(geo, "Prop_Cone_01", Vector3(rng.randf_range(-4.4, 4.4), 0.2, rng.randf_range(-16, 16)), rng.randf_range(0, TAU), false, Vector3.ONE * 1.6).rotation.z = PI / 2 if i % 3 == 0 else 0.0
	for i in 6:
		_blood(geo, Vector3(rng.randf_range(-3, 3), 0.09, rng.randf_range(-14, 14)), rng.randf_range(0.7, 1.3))
		var bit := box(geo, Vector3(rng.randf_range(-3.2, 3.2), 0.11, rng.randf_range(-12, 12)), Vector3(0.3, 0.02, 0.22), Color("6d8488"), false)
		bit.rotation.y = rng.randf_range(0, TAU)
	for i in 4:
		_junk(geo, Vector3(rng.randf_range(5, 9) * (-1.0 if i % 2 else 1.0), 0, rng.randf_range(-14, 14)))


func _bridge_place() -> void:
	# Ponte di cemento sul torrente: spallette a filo strada, pile scure sotto, acqua nel canale. Il torrente corre lungo X locale.
	var deck_half := 4.2
	for s in [-1, 1]:
		# fiancate del terrapieno e bocca scura sotto la strada
		box(geo, Vector3(s * 5.0, -1.9, 0), Vector3(0.7, 3.8, 15), CONCRETE.darkened(0.15), false)
		box(geo, Vector3(s * 5.4, -2.0, 0), Vector3(0.08, 2.6, 8), Color("0e0e0d"), false)
		for z in [-8.2, 8.2]:
			box(geo, Vector3(s * 7.0, -1.5, z), Vector3(4.5, 3.6, 0.7), CONCRETE.darkened(0.25), false)
		# parapetto: tratti pieni e un buco dove qualcuno è uscito di strada
		for z in [-7.5, -4.5, -1.5, 1.5, 4.5, 7.5]:
			if s == 1 and absf(z - 1.5) < 0.1: continue
			box(geo, Vector3(s * deck_half, 0.5, z), Vector3(0.3, 1.0, 2.8), CONCRETE, true)
	_tilted(geo, Vector3(deck_half + 1.0, -1.1, 1.5), Vector3(0.3, 1.0, 2.8), CONCRETE.darkened(0.1), Vector3(0.4, 0.3, 1.1))
	# macchina finita nel torrente, muso in giù
	var sunk := _wreck(Vector3(12, -3.1, 4), 1.2, "SM_Borgo_Car_Wreck_Red.glb")
	sunk.rotation.x = 0.28
	# acqua: una striscia bassa che si vede solo dentro il canale
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(260, 18)
	water.mesh = plane
	water.position = Vector3(0, -Route.BRIDGE_HUMP - 0.28, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("24393a")
	mat.roughness = 0.12
	mat.metallic = 0.3
	water.material_override = mat
	geo.add_child(water)
	for at in [Vector3(16, -3.0, -4), Vector3(-14, -3.0, 3), Vector3(25, -3.0, 2)]:
		_glb(geo, NATURE + "Rock_Medium_%d.gltf" % rng.randi_range(1, 3), at, rng.randf_range(0, TAU), rng.randf_range(0.7, 1.3), false)
