extends Node3D
# Kit ambiente ZOMBIX (art/env, Batch 1 + armi v2 del Batch 2) nella Zona 1:
# armeria arredata, ufficio dello sceriffo, casa di tronchi del Vecchio sul lago,
# fattoria in mattoni diroccata, casse distruttibili con cibo, casse da aprire nelle
# arene e una piastra a pressione che fa scattare l'allarme (rumore per gli infetti).
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
const Terrain := preload("res://world/campaign/terrain.gd")
const Solid := preload("res://world/campaign/solid_props.gd")
const ENV := "res://art/env/"
const WEP := "res://art/env/weapons/"

var world: Node3D
var crates: Array = []
var chests: Array = []      # {node, loot, opened}
var plate_light: Node3D
var npcs: Array = []

func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "Zone1Kit"
	var village: Node = world.landscape.get_node_or_null("RefugeBuildings")
	if village:
		var armory: Node3D = village.get_node_or_null("Armory")
		var office: Node3D = village.get_node_or_null("SheriffOffice")
		if armory: _armory(armory)
		if office: _sheriff_office(office)
	_cabin(Layout.CABIN)
	_farm(Layout.FARM)
	_cabin_furniture()
	_farm_furniture()
	_crates()
	_arena_chests()
	_npcs()
	_nature()

# ---------------------------------------------------------------- utilità
func put(parent: Node3D, path: String, at: Vector3, yaw: float = 0.0, fixture: bool = false) -> Node3D:
	var node: Node3D = load(path).instantiate()
	parent.add_child(node)
	node.position = at
	node.rotation.y = yaw
	# Il raggio "parla con l'armaiolo" attraversa banchi e vetrine.
	if fixture:
		for body in node.find_children("*", "StaticBody3D", true, false): body.set_meta("shop_fixture", true)
	return node

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, Terrain.ground_height(at.x, at.z), at.z)

func weapon(parent: Node3D, file: String, at: Vector3, rot: Vector3) -> Node3D:
	var gun: Node3D = load(WEP + file + ".glb").instantiate()
	parent.add_child(gun)
	gun.position = at
	gun.rotation = rot
	return gun

# ---------------------------------------------------------------- armeria
func _armory(o: Node3D) -> void:
	# Coordinate locali dell'edificio: +Z verso la strada, parete di fondo a z≈1,1.
	var cz: float = 2.65
	put(o, ENV + "shop/SM_Shop_SalesCounter.glb", Vector3(-1.9, 0, cz), 0.0, true)
	# Il bancone ha già la sua cassa inglobata nella mesh a x +0.729, z -0.0675.
	# Una sola cassa la copre ed è ruotata verso il venditore, così il fronte
	# con i tasti guarda l'armaiolo e non il cliente.
	var cash := put(o, ENV + "shop/SM_Prop_CashRegister_Retro.glb", Vector3(-1.171, 1.0, cz - 0.0675), PI, true)
	cash.scale = Vector3.ONE * 1.08
	put(o, ENV + "shop/SM_Prop_AmmoBox_9mm_Open.glb", Vector3(-2.6, 1.0, cz + 0.1), 0.4, true)
	put(o, ENV + "shop/SM_Prop_AmmoBox_556.glb", Vector3(-2.35, 1.0, cz + 0.05), -0.2, true)
	put(o, ENV + "shop/SM_Prop_AmmoBox_556_Open.glb", Vector3(-2.15, 1.0, cz + 0.12), 0.1, true)
	# Pannello forato dell'Emporio di Big Earl: ci sono appese le armi in vendita in Zona 1 (ZXShopCatalog).
	put(o, ENV + "shop/SM_Shop_Pegboard.glb", Vector3(-1.9, 0.95, 1.12), 0.0, true)
	_zone1_stock(o)
	# Lo zaino da +1 slot sul bancone, accanto alle munizioni.
	if world.get("survival") and world.survival.zx:
		var pack: Node3D = world.survival.zx.make_pack()
		pack.name = "Stock_pack"          # in vendita come le armi appese
		o.add_child(pack)
		pack.position = Vector3(-3.3, 1.0, cz - 0.05)
		pack.rotation.y = 0.5
		world.survival.zx.register_display(pack, "pack", -1, pack.get_node("Tag"))
		world.survival.zx.add_counter_items(o, Vector3(-1.98, 1.0, cz + 0.12), Vector3(0.26, 0, 0))
	put(o, ENV + "shop/SM_Shop_GunsmithWorkbench.glb", Vector3(1.9, 0, 1.55), 0.0, true)
	put(o, ENV + "shop/SM_Prop_Vise.glb", Vector3(1.25, 0.92, 1.6), 0.0, true)
	put(o, ENV + "shop/SM_Prop_Wrench.glb", Vector3(1.65, 0.92, 1.75), 0.6, true)
	put(o, ENV + "shop/SM_Prop_OilCan.glb", Vector3(2.45, 0.92, 1.55), -0.4, true)
	put(o, ENV + "shop/SM_Prop_OilTin.glb", Vector3(2.65, 0.92, 1.62), 0.2, true)
	put(o, ENV + "shop/SM_Prop_Rag.glb", Vector3(2.1, 0.92, 1.8), 1.1, true)
	put(o, ENV + "shop/SM_Prop_AmmoCrate_Wood.glb", Vector3(-0.1, 0, 1.55), 0.15, true)
	put(o, ENV + "shop/SM_Prop_AmmoCan_Military.glb", Vector3(-0.15, 0.37, 1.55), -0.2, true)
	put(o, ENV + "shop/SM_Shop_SecurityShutter_Door.glb", Vector3(3.6, 0, 1.13), 0.0, true)
	# Vetrina vuota: niente oggetti decorativi che trapassino il vetro.
	put(o, ENV + "shop/SM_Shop_DisplayCase.glb", Vector3(-3.55, 0, 5.2), PI / 2, true)
	# Fucili e spade delle zone successive non sono più alle pareti: qui si vende solo la roba della Zona 1.
	# Le due novità (ascia runica e spada spartana) in vetrina sulla parete sinistra, sopra la teca.
	_featured(o, "runic_axe", Vector3(-4.34, 1.62, 5.45))
	_featured(o, "spartan_sword", Vector3(-4.34, 1.62, 4.75))
	# Insegna a proiettile sul fronte della pensilina, fuori dal portico.
	var sign := put(o, ENV + "shop/SM_Shop_Sign_GunsAmmo.glb", Vector3(0, 2.0, 9.9), 0.0)
	# L'insegna pende a 2 m sopra l'ingresso: la sua collisione fermava la testa di chi entrava.
	for body in sign.find_children("*", "StaticBody3D", true, false): body.queue_free()

## Armi della Zona 1 sul pannello forato (largo 2,08 m, alto 1,54, faccia verso la strada):
## in alto le armi da fuoco, sotto quelle da mischia appese in verticale, ognuna con il suo cartellino.
func _zone1_stock(o: Node3D) -> void:
	var board := Vector3(-1.9, 0.95, 1.12 + 0.17)
	var guns := []
	var blades := []
	for e in ZXShopCatalog.stock(0, false):
		if e.id in ["runic_axe", "spartan_sword"]: continue          # in vetrina sulla parete sinistra
		var d := ZXWeapons.get_def(e.id)
		if d.is_empty() or d.scene == "": continue
		(guns if d.get("class", "") in ["pistol", "rifle"] else blades).append(e)
	for i in guns.size():
		_hang(o, guns[i], board + Vector3((i - (guns.size() - 1) * 0.5) * 0.62, 1.38, 0), false)
	for i in blades.size():
		_hang(o, blades[i], board + Vector3((i - (blades.size() - 1) * 0.5) * 0.36, 0.52, 0), true)


func _hang(o: Node3D, e: Dictionary, at: Vector3, upright: bool) -> Node3D:
	var d := ZXWeapons.get_def(e.id)
	var slot := Node3D.new()
	slot.name = "Stock_" + e.id
	o.add_child(slot)
	slot.position = at
	var w: Node3D = (load(d.scene) as PackedScene).instantiate()
	slot.add_child(w)
	# Le armi importate puntano canna o filo lungo -Z con l'alto lungo +Y: girate di lato verso il cliente.
	w.rotation = Vector3(0, -PI / 2, 0)
	if upright: w.position.y = -0.05
	var tag := Label3D.new()
	tag.text = "%s\n%d CR" % [ZXWeapons.display_name(e.id), e.price]
	tag.font_size = 26
	tag.pixel_size = 0.0019
	tag.outline_size = 8
	tag.modulate = Color("ffe9a8")
	# Cartellino sotto l'arma, sopra il bordo del bancone visto dal cliente.
	tag.position = Vector3(0, -0.36 if upright else -0.15, 0.05)
	slot.add_child(tag)
	# Si compra guardando l'arma e premendo E (world/campaign/zx_shops.gd).
	if world.get("survival") and world.survival.zx:
		world.survival.zx.register_display(slot, e.id, e.price, tag)
	return slot


func _featured(o: Node3D, id: String, at: Vector3) -> void:
	var e := {"id": id, "price": ZXShopCatalog.price(id, 0)}
	var slot := _hang(o, e, at, true)
	# Parete sinistra: il fronte guarda +X, verso l'interno del negozio.
	slot.rotation.y = PI / 2

# ---------------------------------------------------------------- ufficio dello sceriffo
func _sheriff_office(o: Node3D) -> void:
	put(o, ENV + "interactive/SM_Int_Safe_Steel.glb", Vector3(2.8, 0, 1.45), 0.0, true).set("locked", true)
	var light := put(o, ENV + "interactive/SM_Int_StatusLight.glb", Vector3(-2.2, 1.8, 3.44), 0.0)
	light.set("blink", true)
	light.set("state", 1)

# ---------------------------------------------------------------- rovine
func _tile(parent: Node3D, file: String, at: Vector3, yaw: float) -> Node3D:
	return put(parent, ENV + "building/" + file + ".glb", at, yaw)

func _walls(parent: Node3D, front: Array, back: Array, left: Array, right: Array, posts: String) -> void:
	# Rettangolo 8×8: muri lungo +X con l'esterno verso -Z (convenzione del kit).
	var s := Layout.RUIN_SIZE
	for i in front.size():
		if front[i] != "": _tile(parent, front[i], Vector3(i * 4.0, 0, 0), 0.0)
	for i in back.size():
		if back[i] != "": _tile(parent, back[i], Vector3(s - i * 4.0, 0, s), PI)
	for i in left.size():
		if left[i] != "": _tile(parent, left[i], Vector3(0, 0, s - i * 4.0), PI / 2)
	for i in right.size():
		if right[i] != "": _tile(parent, right[i], Vector3(s, 0, i * 4.0), -PI / 2)
	for c in [Vector3.ZERO, Vector3(s, 0, 0), Vector3(0, 0, s), Vector3(s, 0, s)]:
		_tile(parent, posts, c, 0.0)

func _cabin(corner: Vector3) -> void:
	# Casa del Vecchio: tronchi, tetto in lamiera, porta verso il paese.
	var cabin := Node3D.new()
	cabin.name = "CasaDelVecchio"
	add_child(cabin)
	cabin.position = ground(corner)
	for x in [0.0, 4.0]:
		for z in [0.0, 4.0]:
			_tile(cabin, "SM_Bld_Floor_Wood_4x4", Vector3(x, 0.02, z), 0.0)
			_tile(cabin, "SM_Bld_Roof_Corrugated_4x4", Vector3(x, 3.0, z), 0.0)
	_walls(cabin, ["SM_Bld_Wall_Log_Window", "SM_Bld_Wall_Log_Doorway"], ["SM_Bld_Wall_Log_Solid", "SM_Bld_Wall_Log_Window"],
		["SM_Bld_Wall_Log_Solid", "SM_Bld_Wall_Log_Window"], ["SM_Bld_Wall_Log_Doorway", "SM_Bld_Wall_Log_Solid"], "SM_Bld_Wall_CornerPost")
	_tile(cabin, "SM_Bld_Pillar_Porch", Vector3(4.6, 0, -2.4), 0.0)
	_tile(cabin, "SM_Bld_Pillar_Porch", Vector3(7.6, 0, -2.4), 0.0)
	_tile(cabin, "SM_Bld_Beam_4m", Vector3(4.2, 2.95, -2.4), 0.0)
	var chest := put(cabin, ENV + "interactive/SM_Int_Chest_Supply.glb", Vector3(1.5, 0.02, 6.6), 0.2)
	chests.append({"node": chest, "loot": "supply", "opened": false})
	put(cabin, ENV + "shop/SM_Prop_OilTin.glb", Vector3(6.5, 0.02, 6.8), 0.0)
	put(cabin, ENV + "shop/SM_Prop_Rag.glb", Vector3(6.2, 0.02, 6.5), 0.5)

func _farm(corner: Vector3) -> void:
	# Fattoria diroccata: mattoni danneggiati, niente tetto, una capriata crollata.
	var farm := Node3D.new()
	farm.name = "FattoriaDiroccata"
	add_child(farm)
	farm.position = ground(corner)
	for x in [0.0, 4.0]:
		for z in [0.0, 4.0]:
			_tile(farm, "SM_Bld_Floor_Concrete_4x4", Vector3(x, 0.02, z), 0.0)
	_walls(farm, ["SM_Bld_Wall_Brick_Doorway", "SM_Bld_Wall_Brick_Damaged"], ["SM_Bld_Wall_Brick_Window", "SM_Bld_Wall_Brick_Solid"],
		["SM_Bld_Wall_Brick_Damaged", ""], ["SM_Bld_Wall_Brick_Window", "SM_Bld_Wall_Damaged"], "SM_Bld_Wall_CornerPost_Brick")
	for z in [0.0, 4.0]:
		_tile(farm, "SM_Bld_Foundation_Stone_4m", Vector3(0, 0.0, z), PI / 2)
	var truss := _tile(farm, "SM_Bld_Truss_4m", Vector3(2.0, 0.15, 3.0), 0.4)
	truss.rotation.z = 0.35
	_tile(farm, "SM_Bld_Roof_Corrugated_4x4", Vector3(4.0, 0.8, 4.0), 0.2).rotation.x = 0.45
	var chest := put(farm, ENV + "interactive/SM_Int_Chest_Military.glb", Vector3(6.0, 0.02, 6.4), PI)
	chests.append({"node": chest, "loot": "military", "opened": false})
	# Allarme: la piastra alla porta accende la luce e fa rumore per 30 m.
	var plate := put(farm, ENV + "interactive/SM_Int_PressurePlate.glb", Vector3(2.0, 0.03, 0.9), 0.0)
	plate_light = put(farm, ENV + "interactive/SM_Int_StatusLight.glb", Vector3(3.6, 2.2, 0.25), 0.0)
	plate_light.set("state", 2)
	if plate.has_signal("pressed"):
		plate.pressed.connect(_alarm)
	# Filo d'inciampo davanti alla breccia sul lato sinistro.
	for i in 3:
		put(farm, ENV + "interactive/SM_Int_Tripwire_Wire_1m.glb", Vector3(-0.6, 0.25, 5.0 + i), PI / 2)
	put(farm, ENV + "interactive/SM_Int_Tripwire_Hook.glb", Vector3(-0.6, 0.25, 5.0), PI / 2)
	put(farm, ENV + "interactive/SM_Int_Tripwire_Hook.glb", Vector3(-0.6, 0.25, 8.0), PI / 2)
	var trip := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.6, 3.0)
	shape.shape = box
	trip.add_child(shape)
	farm.add_child(trip)
	trip.position = Vector3(-0.6, 0.3, 6.5)
	trip.body_entered.connect(_alarm)

func _alarm(body: Node3D) -> void:
	if body != world.player: return
	if plate_light: plate_light.set("state", 1); plate_light.set("blink", true)
	world.zone_life.emit(world.player, 30.0, 1.0)
	world.announce(Localization.t("ALLARME · GLI INFETTI HANNO SENTITO"), 3)

# ---------------------------------------------------------------- arredi (WoodStuff) e miniera (caves & props)
const WOOD := "res://art/env/wood/SM_Wood_"

## Oggetto con collisione a scatola sulla sua mesh (i kit WoodStuff e caves non hanno collisioni).
func prop(parent: Node3D, path: String, at: Vector3, yaw: float = 0.0, solid: bool = true) -> Node3D:
	var node := put(parent, path, at, yaw)
	if not solid: return node
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var local: AABB = node.global_transform.affine_inverse() * m.global_transform * m.get_aabb() if m.is_inside_tree() else m.get_aabb()
		box = local if first else box.merge(local)
		first = false
	if first: return node
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = box.size
	shape.shape = cube
	shape.position = box.get_center()
	body.add_child(shape)
	node.add_child(body)
	return node

func _cabin_furniture() -> void:
	# La casa del Vecchio: vive al pontile, dorme qui. Tavolo con il bollitore ancora tiepido, la sedia a dondolo
	# sotto il portico che guarda il lago.
	var cabin: Node3D = get_node_or_null("CasaDelVecchio")
	if cabin == null: return
	prop(cabin, WOOD + "Table_Round_A.glb", Vector3(4.2, 0.02, 4.4), 0.3)
	prop(cabin, WOOD + "Kettle.glb", Vector3(4.1, 0.76, 4.3), 0.8, false)
	prop(cabin, WOOD + "Mug.glb", Vector3(4.45, 0.76, 4.55), 0.2, false)
	prop(cabin, WOOD + "Chair_A.glb", Vector3(3.4, 0.02, 4.2), PI / 2 + 0.2)
	prop(cabin, WOOD + "Chair_B.glb", Vector3(5.0, 0.02, 4.8), -PI / 2 - 0.3)
	prop(cabin, WOOD + "BookShelf_A.glb", Vector3(0.45, 0.02, 3.0), PI / 2)
	prop(cabin, WOOD + "Cabinet_A_Static.glb", Vector3(7.5, 0.02, 2.0), -PI / 2)
	prop(cabin, WOOD + "Shelf_A.glb", Vector3(4.0, 1.45, 7.75), PI, false)
	prop(cabin, WOOD + "Barrel_A.glb", Vector3(0.6, 0.02, 7.3), 0.0)
	prop(cabin, WOOD + "Basket_E.glb", Vector3(7.3, 0.02, 7.2), 0.5)
	prop(cabin, WOOD + "Stool_A.glb", Vector3(6.4, 0.02, 5.8), 0.0)
	prop(cabin, WOOD + "Chair_Rockign.glb", Vector3(6.1, 0.02, -1.4), PI + 0.3)

func _farm_furniture() -> void:
	# Fattoria diroccata: quello che i saccheggiatori non si sono portati via.
	var farm: Node3D = get_node_or_null("FattoriaDiroccata")
	if farm == null: return
	prop(farm, WOOD + "Barrel_B_Static.glb", Vector3(6.8, 0.02, 1.2), 0.4)
	prop(farm, WOOD + "Barrel_A.glb", Vector3(7.2, 0.02, 1.7), 0.0)
	prop(farm, WOOD + "Crate_Static.glb", Vector3(1.0, 0.02, 6.9), 0.3)
	prop(farm, WOOD + "Crate_Open.glb", Vector3(1.45, 0.02, 7.1), -0.2)
	prop(farm, WOOD + "Bench_B.glb", Vector3(4.4, 0.02, 7.3), PI)
	prop(farm, WOOD + "Basket_D.glb", Vector3(3.0, 0.02, 4.2), 1.2)
	var shovel := prop(farm, WOOD + "Shovel.glb", Vector3(7.55, 0.02, 4.5), -PI / 2, false)
	shovel.rotation.z = 0.25

# ---------------------------------------------------------------- casse e bauli
func _crates() -> void:
	var spots := [Vector3(-28, 0, -6), Vector3(-26.8, 0, -6.4), Vector3(-25, 0, -118), Vector3(-24, 0, -119.4),
		Vector3(14, 0, -60), Vector3(-6, 0, -84), Vector3(22, 0, -132), Vector3(40, 0, -36), Vector3(-44, 0, -70), Vector3(12, 0, -150)]
	for at in spots:
		var crate := put(self, ENV + "interactive/SM_Int_Crate_Destructible.glb", ground(at), randf_range(0, TAU))
		# Le casse si rompono con la mischia come gli infetti e lasciano cibo.
		var adapter := Node.new()
		adapter.set_script(preload("res://world/zona1_rifugio/crate_target.gd"))
		crate.add_child(adapter)
		adapter.crate = crate
		for body in crate.find_children("*", "StaticBody3D", true, false):
			body.collision_layer = 1 | 16
			body.set_meta("target", adapter)
			body.set_meta("zone", "torso")
		if crate.has_signal("broken"):
			crate.broken.connect(func(): world.zone_life.add_pickup(crate.global_position - Vector3(0, 0.5, 0), "can"))
		crates.append(crate)

func _arena_chests() -> void:
	for arena in preload("res://world/zona1_rifugio/roadnet.gd").arenas():
		var at: Vector3 = ground(arena + Vector3(-3.0, 0, 5.5))
		var chest := put(self, ENV + "interactive/SM_Int_Chest_Military.glb", at, 0.3)
		chests.append({"node": chest, "loot": "military", "opened": false})

func chest_context(p: Node3D) -> String:
	for c in chests:
		if not c["opened"] and p.global_position.distance_to(c["node"].global_position) < 2.2:
			return Localization.t("E  APRI CASSA MILITARE" if c["loot"] == "military" else "E  APRI CASSA RIFORNIMENTI")
	return ""

func open_chest(p: Node3D) -> bool:
	for c in chests:
		if c["opened"] or p.global_position.distance_to(c["node"].global_position) >= 2.2: continue
		c["opened"] = true
		if c["node"].has_method("open"): c["node"].open()
		if c["loot"] == "military":
			p.credits += 30
			world.zone_life.food["can"] = int(world.zone_life.food["can"]) + 1
			world.announce(Localization.t("CASSA MILITARE · +30 CREDITI, UNA SCATOLETTA"), 4)
		else:
			world.zone_life.food["can"] = int(world.zone_life.food["can"]) + 2
			world.zone_life.food["mushroom"] = int(world.zone_life.food["mushroom"]) + 1
			world.announce(Localization.t("RIFORNIMENTI · DUE SCATOLETTE E FUNGHI SECCHI"), 4)
		if world.get("survival"): world.survival._publish()
		return true
	return false

# ---------------------------------------------------------------- rocce e natura
func _nature() -> void:
	# Quaternius (art/nature, CC0): massi con collisione, ciottoli, felci, cespugli,
	# funghi, trifogli, alberi secchi e tronchi caduti. Strade, paese e arene restano liberi.
	var Route := preload("res://world/campaign/route.gd")
	var RoadNet := preload("res://world/zona1_rifugio/roadnet.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 90417
	var cache := {}
	var groups := [
		[["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"], 70, Vector2(0.7, 1.6), true],
		[["Pebble_Round_1", "Pebble_Round_3", "Pebble_Square_2", "Pebble_Square_4", "RockPath_Round_Wide", "RockPath_Square_Wide"], 160, Vector2(0.6, 1.2), false],
		[["Fern_1", "Plant_1", "Plant_7", "Plant_7"], 150, Vector2(0.35, 0.7), false],
		[["Mushroom_Common", "Mushroom_Laetiporus", "Clover_1", "Clover_2"], 120, Vector2(0.5, 0.9), false],
		[["DeadTree_1", "DeadTree_2", "DeadTree_3", "DeadTree_4", "DeadTree_5"], 26, Vector2(0.9, 1.4), true],
	]
	for group in groups:
		var ids: Array = group[0]
		var placed := 0
		var tries := 0
		while placed < int(group[1]) and tries < int(group[1]) * 8:
			tries += 1
			var x := rng.randf_range(-120, 130)
			var z := rng.randf_range(-220, 6)
			var p := Vector2(x, z)
			if Layout.occupied(x, z) or Layout.safe(Vector3(x, 0, z)): continue
			if Route.road_distance(p) < 6.0 or RoadNet.distance(p) < 4.5 or RoadNet.arena_distance(p) < 14.0: continue
			var id: String = ids[rng.randi() % ids.size()]
			if not cache.has(id): cache[id] = load("res://art/nature/%s.gltf" % id)
			var node: Node3D = cache[id].instantiate()
			add_child(node)
			node.position = ground(Vector3(x, 0, z)) - Vector3(0, 0.05, 0)
			node.rotation.y = rng.randf_range(0, TAU)
			var s := rng.randf_range(group[2].x, group[2].y)
			node.scale = Vector3(s, s * rng.randf_range(0.85, 1.15), s)
			_mute(node)
			if group[3]:
				if id.begins_with("Rock"):
					# Stessa regola dei massi: la forma convessa solo per quelli grandi.
					Solid.add_rock(node)
				else:
					var body := StaticBody3D.new()
					var shape := CollisionShape3D.new()
					var cyl := CylinderShape3D.new()
					cyl.radius = 0.25
					cyl.height = 4.0
					shape.shape = cyl
					shape.position.y = cyl.height * 0.5
					body.add_child(shape)
					node.add_child(body)
			placed += 1
	# Tronchi caduti lungo i margini del bosco.
	for i in 18:
		var x := rng.randf_range(-110, 120)
		var z := rng.randf_range(-215, -20)
		if Layout.occupied(x, z) or Route.road_distance(Vector2(x, z)) < 7.0 or RoadNet.distance(Vector2(x, z)) < 5.0: continue
		var log: Node3D = preload("res://art/placeholders.gd").log()
		add_child(log)
		log.position = ground(Vector3(x, 0, z))
		log.rotation.y = rng.randf_range(0, TAU)
		log.scale = Vector3.ONE * rng.randf_range(1.0, 1.8)

func _mute(node: Node) -> void:
	# Toni spenti come il resto del bosco: niente verdi fluo o funghi da cartone.
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat = node.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				var copy: StandardMaterial3D = mat.duplicate()
				copy.albedo_color = copy.albedo_color.lerp(Color(0.32, 0.33, 0.26), 0.35)
				node.set_surface_override_material(i, copy)
	for child in node.get_children(): _mute(child)

# ---------------------------------------------------------------- NPC in posa
func _npcs() -> void:
	var Npc := preload("res://world/campaign/npc_pose.gd")
	# Il Vecchio pesca in fondo al pontile con la skin del pescatore.
	# Seduto sul bordo della piattaforma a T, gambe sull'acqua.
	npcs.append(Npc.spawn(self, "ZX_SKIN_5", "", "fishing", Vector3(7.3, 0.2, 24.75), 0.0))
	# Gli unici NPC del paese sono il Vecchio, lo sceriffo e l'armaiolo.
