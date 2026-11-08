class_name ZXShop
extends Node3D
## A zone shop built in code: counter, pegboard wall with the zone's weapons hung on it, price tags, shop sign and NPC.
## Drop it in a level, set `zone` (0..4, see ZXShopCatalog) or call set_zone_for_stop(campaign.zone_index).
## Interaction: items() lists what is on sale; buy(id, wallet) returns the new wallet (or -1 if not affordable).
## The shop faces +Z (customer side). Size about 4.2 x 2.6 m.

signal bought(id: String, price: int)

@export_range(0, 4) var zone := 0: set = set_zone
@export var include_previous := true
@export var show_prices := true

var npc: ZXNpc
var _rack: Node3D
var _items: Array = []
var _tags := {}


func _ready() -> void:
	_build_static()
	set_zone(zone)


func set_zone_for_stop(stop: int) -> void:
	set_zone(ZXShopCatalog.zone_for_stop(stop))


func set_zone(z: int) -> void:
	zone = clampi(z, 0, ZXShopCatalog.ZONES.size() - 1)
	if not is_inside_tree() or _rack == null:
		return
	for c in _rack.get_children():
		_rack.remove_child(c)          # subito fuori: i nuovi slot tengono il nome dell'arma (zx_shops.gd li cerca per nome)
		c.queue_free()
	_tags.clear()
	_items = ZXShopCatalog.stock(zone, include_previous)
	var info: Dictionary = ZXShopCatalog.ZONES[zone]
	var who := String(info.npc).get_file().get_basename()
	if npc and npc.npc != who:
		npc.queue_free()
		npc = null
	if npc == null:
		npc = ZXNpc.new()
		npc.npc = who
		npc.position = Vector3(1.1, 0, -0.65)
		add_child(npc)
	(get_node("Sign") as Label3D).text = "%s\n%s" % [Localization.t(str(info.shop)).to_upper(), Localization.t(str(info.name))]
	# hang weapons: 2 rows of 5 on the pegboard (new arrivals first), then 6 on the counter.
	# Anything beyond 16 is still for sale through items()/buy() ("dal catalogo"), just not on display.
	var per_row := 5
	for i in mini(_items.size(), 16):
		var e: Dictionary = _items[i]
		var d := ZXWeapons.get_def(e.id)
		if d.is_empty() or d.scene == "":
			continue
		var row := i / per_row
		var col := i % per_row
		var slot := Node3D.new()
		slot.name = e.id
		slot.position = Vector3(-1.6 + col * 0.8, 2.05 - row * 0.62, -1.06) if row < 2 else Vector3(-1.4 + (i - 10) * 0.56, 1.02, 0.05)
		_rack.add_child(slot)
		var w := (load(d.scene) as PackedScene).instantiate() as Node3D
		slot.add_child(w)
		_lay(w, d, row >= 2)
		if show_prices:
			var tag := Label3D.new()
			tag.text = "%s\n%d %s%s" % [ZXWeapons.display_name(e.id), e.price, ZXShopCatalog.CURRENCY, ("  " + Localization.t("NUOVO")) if e.new else ""]
			tag.font_size = 28
			tag.pixel_size = 0.0022
			tag.outline_size = 8
			tag.modulate = Color("ffe9a8") if e.new else Color("d8d8d8")
			tag.position = Vector3(0, -0.26, 0.06) if row < 2 else Vector3(0, -0.02, 0.22)
			tag.rotation.x = 0.0 if row < 2 else -1.2
			slot.add_child(tag)
			_tags[e.id] = tag


## Display pose. Imported weapons point the muzzle / blade edge along -Z with the top (or blade) along +Y.
## Wall: everything turned so the customer (+Z) sees the side; counter: laid flat, pointing +X.
func _lay(w: Node3D, d: Dictionary, on_counter: bool) -> void:
	var cls: String = d.get("class", "")
	var long := cls == "sword" or cls == "axe" or cls == "melee1h"
	if on_counter:
		w.basis = Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)) if long \
			else Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0))
	else:
		w.rotation = Vector3(0, -PI / 2, 0)
		if long:
			w.position.y = -0.15
		w.scale = Vector3.ONE * (0.62 if cls in ["sword", "axe"] else (0.8 if cls in ["rifle", "melee1h"] else 1.2))


func items() -> Array:
	return _items


func buy(id: String, wallet: int) -> int:
	for e in _items:
		if e.id == id:
			if wallet < e.price:
				return -1
			bought.emit(id, e.price)
			if npc:
				npc.show_item()
			return wallet - e.price
	return -1


func _build_static() -> void:
	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color("6b4a32")
	var mat_peg := StandardMaterial3D.new()
	mat_peg.albedo_color = Color("b48a5a")
	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color("4a4f55")
	mat_metal.metallic = 0.6
	_box("Wall", Vector3(4.2, 2.6, 0.1), Vector3(0, 1.3, -1.2), mat_wood)
	_box("Pegboard", Vector3(4.0, 1.4, 0.04), Vector3(0, 1.75, -1.13), mat_peg)
	_box("Counter", Vector3(3.6, 0.95, 0.6), Vector3(0, 0.475, 0.0), mat_wood)
	_box("CounterTop", Vector3(3.7, 0.05, 0.66), Vector3(0, 0.975, 0.0), mat_metal)
	var col := StaticBody3D.new()
	col.name = "Collision"
	add_child(col)
	for b in [[Vector3(3.7, 1.0, 0.66), Vector3(0, 0.5, 0)], [Vector3(4.2, 2.6, 0.1), Vector3(0, 1.3, -1.2)]]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = b[0]
		cs.shape = sh
		cs.position = b[1]
		col.add_child(cs)
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.font_size = 64
	sign.pixel_size = 0.004
	sign.outline_size = 14
	sign.modulate = Color("ffcf4a")
	sign.position = Vector3(0, 2.75, -1.1)
	add_child(sign)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.4, -0.4)
	lamp.light_color = Color("ffd9a0")
	lamp.omni_range = 5.0
	lamp.light_energy = 1.4
	add_child(lamp)
	_rack = Node3D.new()
	_rack.name = "Rack"
	add_child(_rack)


func _box(n: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	add_child(mi)
