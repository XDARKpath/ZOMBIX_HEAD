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
## Dal punto d'arrivo: lontano dal faro della tappa (+8, 0, -6), sul lato opposto della strada.
const OFFSET := Vector3(-10, 0, 8)
const C_TAG := Color("ffe9a8")
const C_TAG_OWNED := Color("9fb59a")
const C_TAG_POOR := Color("e08a6a")
const C_TAG_AIM := Color("fff4c2")
## Cartellini: grandezza fissa sullo schermo (non più 4 cm da lontano e 30 cm da vicino), visibili solo dentro il negozio.
const TAG_PIXEL := 0.0011
const TAG_RANGE := 7.0
const PICK := 0.2                  # quanto può mancare il mirino dal centro di un oggetto esposto (m)
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
	add_upgrades(shop, Vector3(1.1, 1.0, -0.2), Vector3(-0.42, 0, 0), shop)

## Vita e fiato massimi sul bancone (id "up_health", "up_stamina"): si comprano guardandoli, due per zona.
func add_upgrades(parent: Node3D, start: Vector3, step: Vector3, shop: Node3D = null) -> void:
	var i := 0
	for kind in ["health", "stamina"]:
		var up := make_upgrade(kind)
		parent.add_child(up)
		up.position = start + step * i
		up.get_node("Tag").position.y += 0.16 * i
		register_display(up, "up_" + kind, -1, up.get_node("Tag"), shop)
		i += 1

## Cassetta rossa con la croce (vita) o lattina gialla (fiato), con il cartellino.
static func make_upgrade(kind: String) -> Node3D:
	var up := Node3D.new()
	up.name = "Stock_up_" + kind
	var body := StandardMaterial3D.new()
	body.albedo_color = Color("9c2b22") if kind == "health" else Color("d9a521")
	var mark := StandardMaterial3D.new()
	mark.albedo_color = Color("efe8d8") if kind == "health" else Color("2a2a26")
	var rows: Array = [[Vector3(0.26, 0.16, 0.18), Vector3(0, 0.08, 0), body], [Vector3(0.14, 0.04, 0.012), Vector3(0, 0.08, 0.091), mark], [Vector3(0.04, 0.12, 0.012), Vector3(0, 0.08, 0.091), mark]]
	if kind != "health": rows = [[Vector3(0.1, 0.24, 0.1), Vector3(0, 0.12, 0), body], [Vector3(0.102, 0.06, 0.102), Vector3(0, 0.12, 0), mark]]
	for row in rows:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = row[0]
		mi.mesh = box
		mi.position = row[1]
		mi.material_override = row[2]
		up.add_child(mi)
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = Localization.t("Vita +15") if kind == "health" else Localization.t("Fiato +15")
	tag.font_size = 24
	tag.pixel_size = 0.0017
	tag.outline_size = 8
	tag.modulate = C_TAG
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 0.42, 0)
	up.add_child(tag)
	return up

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
		tag.position = Vector3(0, 0.28 + 0.18 * (i % 2), 0)      # sfalsati: i vicini non si coprono
		holder.add_child(tag)
		register_display(holder, id, int(ItemInfo.ITEMS[id].price), tag, shop)
		i += 1

## Registra un oggetto in vendita (lo chiama anche zone1_kit per il pannello di Big Earl).
func register_display(node: Node3D, id: String, price: int, tag: Label3D, shop: Node3D = null) -> void:
	if tag:
		tag.fixed_size = true
		tag.font_size = 30
		tag.outline_size = 10
		tag.pixel_size = TAG_PIXEL
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.rotation = Vector3.ZERO
	displays.append({"node": node, "id": id, "price": price, "tag": tag, "shop": shop})

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
	if String(d.id).begins_with("up_"): return survival.upgrade_price(String(d.id).substr(3))
	return survival.slot_price() if d.id == "pack" else int(d.price)

## Oggetto esposto sotto il mirino, entro REACH: {} se nessuno.
## Vince quello che il raggio del mirino sfiora di meno; il negoziante davanti all'oggetto lo copre.
func target(actor: CharacterBody3D) -> Dictionary:
	var cam: Camera3D = actor.rig.camera
	var origin := cam.global_position
	var forward := -cam.global_basis.z
	var npc_at := _npc_along(origin, forward)
	var best := {}
	var best_miss := PICK
	for d in displays:
		if not is_instance_valid(d.node) or not d.node.is_visible_in_tree(): continue
		var to: Vector3 = _center(d.node) - origin
		var along := forward.dot(to)
		if along > REACH or along < 0.05 or along > npc_at: continue
		var miss := (to - forward * along).length()
		if miss < best_miss:
			best_miss = miss
			best = d
	return best

## Distanza lungo il mirino a cui c'è un negoziante (INF se il mirino non lo prende): testa e busto, 1,1-1,9 m.
func _npc_along(origin: Vector3, forward: Vector3) -> float:
	var npcs: Array = [survival.shop_npc] if survival and survival.get("shop_npc") else []
	for shop in shops:
		if shop.npc: npcs.append(shop.npc)
	var nearest := INF
	for npc in npcs:
		if not is_instance_valid(npc): continue
		var base: Vector3 = (npc as Node3D).global_position
		for h in [1.15, 1.4, 1.65, 1.85]:
			var to: Vector3 = base + Vector3(0, h, 0) - origin
			var along := forward.dot(to)
			if along > 0.0 and (to - forward * along).length() < (0.16 if h > 1.5 else 0.22): nearest = minf(nearest, along)
	return nearest

func _center(node: Node3D) -> Vector3:
	# Le armi appese hanno l'origine sul gancio: il centro visivo sta un po' sotto.
	return node.global_position + Vector3(0, 0.1 if node.has_node("Tag") else -0.05, 0)

## Stato di un oggetto per il giocatore: "ok", "owned", "poor", "full", "max".
func status(actor: CharacterBody3D, d: Dictionary) -> String:
	if d.id == "pack":
		if actor.inventory_slots >= survival.MAX_SLOTS: return "max"
		return "ok" if actor.credits >= price_of(d) else "poor"
	if String(d.id).begins_with("up_"):
		var zone: int = int(d.shop.zone) if d.shop else 0
		if survival.upgrades_left(String(d.id).substr(3), actor, zone) <= 0: return "max"
		return "ok" if actor.credits >= price_of(d) else "poor"
	var consumable: bool = ItemInfo.is_item(d.id) or ZXWeapons.get_def(d.id).get("class", "") == "consumable"
	if not consumable and d.id in actor.owned: return "owned"
	if actor.credits < price_of(d): return "poor"
	if not actor.can_take(d.id) and not ZXWeapons.get_def(d.id).get("class", "") == "consumable": return "full"
	return "ok"

func context(actor: Node3D) -> String:
	var d := target(actor)
	if not d.is_empty():
		var label: String = Localization.t("ZAINO +1 SLOT") if d.id == "pack" else ItemInfo.title(d.id).to_upper()
		if d.id == "up_health": label = Localization.t("VITA MASSIMA +15")
		elif d.id == "up_stamina": label = Localization.t("FIATO MASSIMO +15")
		match status(actor, d):
			"owned": return Localization.t("{0} · GIÀ TUA", [label])
			"max":
				if String(d.id).begins_with("up_"): return Localization.t("{0} · GIÀ PRESI I DUE DI QUESTA ZONA", [label])
				return Localization.t("ZAINO AL MASSIMO ({0} SLOT)", [actor.inventory_slots])
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
		aimed = d if d.id != "pack" and not String(d.id).begins_with("up_") else {}
		if String(d.id).begins_with("up_"): survival.request("buyup:" + String(d.id).substr(3))
		else: survival.request("buyslot" if d.id == "pack" else "zxbuy:" + String(d.id))
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
		var label: String = Localization.t("Zaino più grande") if aimed.id == "pack" else ItemInfo.title(aimed.id)
		world.announce(Localization.t("COMPRATO · {0}", [label.to_upper()]), 3)
	aimed = {}

func _process(_delta: float) -> void:
	if not world or not world.started or not is_instance_valid(world.player): return
	var a: CharacterBody3D = world.player
	var aim := target(a)
	for d in displays:
		var tag: Label3D = d.tag
		if tag == null or not is_instance_valid(tag): continue
		tag.visible = tag.global_position.distance_to(a.global_position) <= TAG_RANGE
		if not tag.visible: continue
		var st := status(a, d)
		var lines := _tag_lines(d, st)
		var on: bool = not aim.is_empty() and aim.node == d.node
		# Sul pannello resta solo il prezzo (o "già tua"): il nome compare, più grande, sull'oggetto sotto il mirino.
		tag.text = "\n".join(lines) if on else lines[-1]
		var c: Color = C_TAG_OWNED if st == "owned" or st == "max" else (C_TAG_POOR if st == "poor" else C_TAG)
		tag.modulate = C_TAG_AIM if on else c
		tag.outline_modulate = Color(0.55, 0.32, 0.05) if on else Color(0, 0, 0)
		tag.scale = Vector3.ONE * (1.3 if on else 0.8)
		tag.render_priority = 1 if on else 0
		tag.outline_render_priority = 0 if on else -1

## Righe del cartellino nella lingua del momento (prima il testo restava quello dell'avvio): nome, prezzo, stato.
func _tag_lines(d: Dictionary, st: String) -> Array:
	if d.id == "pack":
		return [Localization.t("Zaino +1 slot"), Localization.t("{0} CR", [price_of(d)])] if st != "max" else Array(Localization.t("Zaino\nal massimo").split("\n"))
	if String(d.id).begins_with("up_"):
		var what: String = Localization.t("Vita +15") if d.id == "up_health" else Localization.t("Fiato +15")
		return [what, Localization.t("{0} CR", [price_of(d)]) if st != "max" else Localization.t("finiti in questa zona")]
	var title: String = ItemInfo.title(d.id) if ItemInfo.is_item(d.id) else ZXWeapons.display_name(d.id)
	var lines := [title, Localization.t("{0} CR", [price_of(d)])]
	if st == "owned": lines.append(Localization.t("GIÀ TUA"))
	return lines
