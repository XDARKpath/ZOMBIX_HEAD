extends Node3D
# Negozi di zona del pacchetto 0.14 (art/zx_player/zx_shop.gd + zx_shop_catalog.gd).
# Tappe 1-7 della rotta: uno ZXShop accanto al punto d'arrivo, girato verso la strada, con il suo
# negoziante (art/zx_npc). Zona 1: l'Emporio di Big Earl, armi appese al pannello forato (zone1_kit.gd).
# Niente pannelli a schermo: si compra dal pannello. Guardi l'arma appesa (o lo zaino sul bancone), premi E e,
# se i crediti bastano, è tua. Il cartellino dice prezzo, "già tua" o quanti crediti mancano.
# La valuta è quella che il gioco ha già: i crediti delle teste vendute allo sceriffo.
# L'acquisto passa da survival_rules.request("zxbuy:<id>" / "buyslot") e lo convalida l'host.
const Route := preload("res://world/campaign/route.gd")
const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
const Arsenal := preload("res://weapons/zx_arsenal.gd")
const DISTANCE := 3.6
const REACH := 3.2                 # da quanto lontano si compra un oggetto esposto
const AIM := 0.955                 # quanto bisogna guardarlo (coseno dell'angolo dal centro dello schermo)
## Dal punto d'arrivo: lontano dal faro della tappa (+8, 0, -6), sul lato opposto della strada.
const OFFSET := Vector3(-10, 0, 8)
const C_TAG := Color("ffe9a8")
const C_TAG_OWNED := Color("9fb59a")
const C_TAG_POOR := Color("e08a6a")
const C_TAG_AIM := Color("fff4c2")
var world: Node3D
var survival: Node3D
var shops: Array[ZXShop] = []
## Oggetti esposti che si comprano guardandoli: {node, id, price, tag, text, shop}. id "pack" = zaino (+1 slot).
var displays: Array = []
var aimed: Dictionary = {}

func build(owner_world: Node3D, rules: Node3D) -> void:
	world = owner_world
	survival = rules
	name = "ZXShops"
	for stop in range(1, Route.POINTS.size()):
		var shop := ZXShop.new()
		shop.name = "ZXShop%d" % stop
		shop.zone = ZXShopCatalog.zone_for_stop(stop)
		add_child(shop)
		var at: Vector3 = Route.POINTS[stop] + OFFSET
		at.y = world.terrain.height(at.x, at.z) if world.get("terrain") else 0.0
		shop.global_position = at
		var toward: Vector3 = Route.POINTS[stop] - at
		shop.rotation.y = atan2(toward.x, toward.z)      # il lato cliente (+Z) guarda la strada
		shop.set_zone_for_stop(stop)
		shops.append(shop)
		_shop_displays(shop)

## Le armi appese allo ZXShop (nodi del Rack chiamati come l'id) e lo zaino sul bancone.
func _shop_displays(shop: ZXShop) -> void:
	var rack: Node3D = shop.get_node("Rack")
	for e in shop.items():
		var slot: Node3D = rack.get_node_or_null(NodePath(String(e.id)))
		if slot: register_display(slot, e.id, e.price, shop._tags.get(e.id), shop)
	var pack := make_pack()
	shop.add_child(pack)
	pack.position = Vector3(1.62, 1.0, -0.12)
	pack.rotation.y = -0.4
	register_display(pack, "pack", -1, pack.get_node("Tag"), shop)
	add_counter_items(shop, Vector3(-1.72, 1.0, -0.22), Vector3(0, 0, 0.24), shop)

## Bende, cibo e kit medico sul bancone: si comprano guardandoli, come le armi.
func add_counter_items(parent: Node3D, start: Vector3, step: Vector3, shop: Node3D = null) -> void:
	var i := 0
	for id in ["item_bende", "item_cibo", "item_kit_medico"]:
		var holder := Node3D.new()
		holder.name = "Stock_" + id
		parent.add_child(holder)
		holder.position = start + step * i
		var m := ItemInfo.model(id)
		if m: holder.add_child(m)
		var tag := Label3D.new()
		tag.name = "Tag"
		tag.text = "%s\n%d CR" % [ItemInfo.title(id), ItemInfo.ITEMS[id].price]
		tag.font_size = 24
		tag.pixel_size = 0.0017
		tag.outline_size = 8
		tag.modulate = C_TAG
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, 0.28 + 0.1 * (i % 2), 0)
		holder.add_child(tag)
		register_display(holder, id, int(ItemInfo.ITEMS[id].price), tag, shop)
		i += 1

## Registra un oggetto in vendita (lo chiama anche zone1_kit per il pannello di Big Earl).
func register_display(node: Node3D, id: String, price: int, tag: Label3D, shop: Node3D = null) -> void:
	displays.append({"node": node, "id": id, "price": price, "tag": tag, "text": tag.text if tag else "", "shop": shop})

## Zaino da bancone: tela verde, due tasche, cinghie, cartellino col prezzo del prossimo slot.
static func make_pack() -> Node3D:
	var pack := Node3D.new()
	pack.name = "Zaino"
	var canvas := StandardMaterial3D.new()
	canvas.albedo_color = Color("5b663b")
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("302113")
	for row in [[Vector3(0.34, 0.44, 0.2), Vector3(0, 0.22, 0), canvas], [Vector3(0.36, 0.08, 0.22), Vector3(0, 0.46, 0), canvas],
			[Vector3(0.26, 0.15, 0.08), Vector3(0, 0.12, 0.13), canvas], [Vector3(0.2, 0.1, 0.07), Vector3(0, 0.3, 0.125), canvas],
			[Vector3(0.04, 0.46, 0.03), Vector3(-0.1, 0.24, -0.115), dark], [Vector3(0.04, 0.46, 0.03), Vector3(0.1, 0.24, -0.115), dark],
			[Vector3(0.3, 0.025, 0.21), Vector3(0, 0.35, 0.0), dark]]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = row[0]
		mi.mesh = box
		mi.position = row[1]
		mi.material_override = row[2]
		pack.add_child(mi)
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = Localization.t("Zaino +1 slot")
	tag.font_size = 26
	tag.pixel_size = 0.0019
	tag.outline_size = 8
	tag.modulate = C_TAG
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 0.66, 0)
	pack.add_child(tag)
	return pack

## Negozio a portata dell'attore: {"items", "at", "shop", "title"} oppure {}.
func near(actor: Node3D) -> Dictionary:
	for shop in shops:
		var front := shop.to_global(Vector3(0, 0, 1.2))
		if actor.global_position.distance_to(front) <= DISTANCE:
			var info: Dictionary = ZXShopCatalog.ZONES[shop.zone]
			return {"items": shop.items(), "at": front, "shop": shop, "title": "%s · %s" % [Localization.t(str(info.shop)).to_upper(), Localization.t(str(info.name))]}
	if actor.global_position.distance_to(Layout.SHOP_NPC) <= DISTANCE:
		var info: Dictionary = ZXShopCatalog.ZONES[0]
		return {"items": ZXShopCatalog.stock(0), "at": Layout.SHOP_NPC, "shop": null, "title": "%s · %s" % [Localization.t(str(info.shop)).to_upper(), Localization.t(str(info.name))]}
	return {}

## Prezzo di un'arma per l'attore (-1 se non è in vendita lì): l'arma esposta a portata di mano o il negozio vicino.
## Usato dall'host per convalidare l'acquisto.
func offer(actor: Node3D, id: String) -> int:
	for d in displays:
		if d.id == id and is_instance_valid(d.node) and actor.global_position.distance_to(d.node.global_position) <= REACH + 1.0:
			return d.price
	var here := near(actor)
	for e in here.get("items", []):
		if e.id == id: return e.price
	return -1

## Prezzo mostrato: lo zaino costa sempre il prossimo slot.
func price_of(d: Dictionary) -> int:
	return survival.slot_price() if d.id == "pack" else int(d.price)

## Oggetto esposto che il giocatore sta guardando, entro REACH: {} se nessuno.
func target(actor: CharacterBody3D) -> Dictionary:
	var cam: Camera3D = actor.rig.camera
	var origin := cam.global_position
	var forward := -cam.global_basis.z
	var best := {}
	var best_dot := AIM
	for d in displays:
		if not is_instance_valid(d.node) or not d.node.is_visible_in_tree(): continue
		var to: Vector3 = _center(d.node) - origin
		var dist := to.length()
		if dist > REACH or dist < 0.05: continue
		# Gli oggetti vicini sono grandi sullo schermo: la tolleranza cresce man mano che ti avvicini.
		var dot := forward.dot(to / dist) + clampf(0.25 / dist, 0.0, 0.25) * 0.12
		if dot > best_dot:
			best_dot = dot
			best = d
	return best

func _center(node: Node3D) -> Vector3:
	# Le armi appese hanno l'origine sul gancio: il centro visivo sta un po' sotto.
	return node.global_position + Vector3(0, 0.1 if node.has_node("Tag") else -0.05, 0)

## Stato di un oggetto per il giocatore: "ok", "owned", "poor", "full", "max".
func status(actor: CharacterBody3D, d: Dictionary) -> String:
	if d.id == "pack":
		if actor.inventory_slots >= survival.MAX_SLOTS: return "max"
		return "ok" if actor.credits >= price_of(d) else "poor"
	var consumable: bool = ItemInfo.is_item(d.id) or ZXWeapons.get_def(d.id).get("class", "") == "consumable"
	if not consumable and d.id in actor.owned: return "owned"
	if actor.credits < price_of(d): return "poor"
	if not actor.can_take(d.id) and not ZXWeapons.get_def(d.id).get("class", "") == "consumable": return "full"
	return "ok"

func context(actor: Node3D) -> String:
	var d := target(actor)
	if not d.is_empty():
		var label: String = "ZAINO +1 SLOT" if d.id == "pack" else ItemInfo.title(d.id).to_upper()
		match status(actor, d):
			"owned": return Localization.t("{0} · GIÀ TUA", [label])
			"max": return Localization.t("ZAINO AL MASSIMO ({0} SLOT)", [actor.inventory_slots])
			"poor": return Localization.t("{0} · {1} CR · TE NE MANCANO {2}", [label, price_of(d), price_of(d) - actor.credits])
			"full": return Localization.t("{0} · TASCHE PIENE · X LASCIA QUELLO IN MANO", [label])
		return Localization.t("E  COMPRA {0} · {1} CR", [label, price_of(d)])
	for shop in shops:
		if actor.global_position.distance_to(shop.to_global(Vector3(0, 0, 1.2))) <= DISTANCE:
			return Localization.t("GUARDA UN'ARMA SUL PANNELLO · E PER COMPRARE")
	return ""

## [E] nel negozio: compra quello che guardi. Vicino al bancone senza guardare niente: il negoziante risponde.
func request(actor: CharacterBody3D) -> bool:
	var d := target(actor)
	if not d.is_empty():
		var why := status(actor, d)
		if why != "ok":
			world.announce(context(actor), 2.5)
			return true
		aimed = d if d.id != "pack" else {}
		survival.request("buyslot" if d.id == "pack" else "zxbuy:" + String(d.id))
		return true
	for shop in shops:
		if actor.global_position.distance_to(shop.to_global(Vector3(0, 0, 1.2))) <= DISTANCE and shop.npc:
			world.announce(Localization.t("{0}: «{1}» · Guarda un'arma sul pannello e premi E.", [shop.npc.title(), shop.npc.talk(actor.global_position)]), 4)
			return true
	return false

## Compatibilità con i vecchi richiami del pannello: ora si compra guardando l'arma.
func open_panel(actor: Node3D) -> bool:
	return request(actor)

## Effetto locale dopo un acquisto riuscito: il negoziante mostra l'arma e il cartellino diventa "già tua".
func on_bought() -> void:
	var shop = aimed.get("shop")
	if shop and is_instance_valid(shop) and shop.npc: shop.npc.show_item()
	elif survival.shop_npc: survival.shop_npc.show_item()
	if not aimed.is_empty():
		var label: String = "Zaino più grande" if aimed.id == "pack" else ItemInfo.title(aimed.id)
		world.announce(Localization.t("COMPRATO · {0}", [label.to_upper()]), 3)
	aimed = {}

func _process(_delta: float) -> void:
	if not world or not world.started or not is_instance_valid(world.player): return
	var a: CharacterBody3D = world.player
	var aim := target(a)
	for d in displays:
		var tag: Label3D = d.tag
		if tag == null or not is_instance_valid(tag): continue
		if tag.global_position.distance_to(a.global_position) > 9.0: continue
		var st := status(a, d)
		var base: String = d.text
		if d.id == "pack":
			base = Localization.t("Zaino +1 slot\n{0} CR", [price_of(d)]) if st != "max" else Localization.t("Zaino\nal massimo")
		tag.text = base + ("\n" + Localization.t("GIÀ TUA") if st == "owned" else "")
		var c: Color = C_TAG_OWNED if st == "owned" or st == "max" else (C_TAG_POOR if st == "poor" else C_TAG)
		var on: bool = not aim.is_empty() and aim.node == d.node
		tag.modulate = C_TAG_AIM if on else c
		tag.outline_modulate = Color(0.55, 0.32, 0.05) if on else Color(0, 0, 0)
		tag.scale = Vector3.ONE * (1.25 if on else 1.0)
