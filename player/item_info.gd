class_name ItemInfo
extends RefCounted
# Oggetti impilabili dell'inventario (id del viewmodel: player/viewmodel/fp_arms.gd) e dati comuni ad armi e oggetti:
# nome, descrizione, modello 3D (per lancio, icone e bancone) e danno da lancio.

const ITEMS := {
	# Teste: ogni tipo di infetto ha la sua, con il suo colore e il suo prezzo dallo sceriffo. Si tengono in mano e si vendono con V.
	"item_testa": {"name": "Testa di infetto", "model": "Testa", "heal": 0, "sell": 25, "tint": Color(1, 1, 1)},
	"item_testa_corridore": {"name": "Testa di corridore", "model": "Testa", "heal": 0, "sell": 40, "tint": Color(1.1, 1.05, 0.62)},
	"item_testa_sputatore": {"name": "Testa di sputatore", "model": "Testa", "heal": 0, "sell": 55, "tint": Color(0.62, 1.25, 0.5)},
	"item_testa_urlatore": {"name": "Testa di urlatore", "model": "Testa", "heal": 0, "sell": 70, "tint": Color(0.86, 0.68, 1.2)},
	"item_testa_bruto": {"name": "Testa di bruto", "model": "Testa", "heal": 0, "sell": 100, "tint": Color(1.2, 0.62, 0.55)},
	"item_testa_capomacello": {"name": "Testa del Capomacello", "model": "Testa", "heal": 0, "sell": 300, "tint": Color(0.7, 0.42, 0.34)},
	"item_testa_macellaio": {"name": "Testa del Macellaio", "model": "Testa", "heal": 0, "sell": 400, "tint": Color(1.25, 0.5, 0.45)},
	"item_testa_carceriere": {"name": "Testa del Carceriere", "model": "Testa", "heal": 0, "sell": 600, "tint": Color(1.25, 0.95, 0.4)},
	"item_testa_matriarca": {"name": "Testa del Mago", "model": "Testa", "heal": 0, "sell": 700, "tint": Color(0.62, 1.3, 0.45)},
	"item_testa_signore": {"name": "Testa del Signore", "model": "Testa", "heal": 0, "sell": 800, "tint": Color(0.86, 0.62, 1.15)},
	"item_bende": {"name": "Bende", "desc": "Tasto sinistro: ti fasci il polso. +35 salute.", "model": "Bende", "heal": 35, "price": 30},
	"item_cibo": {"name": "Scatoletta", "desc": "Tasto sinistro: mangi. +20 salute.", "model": "Cibo", "heal": 20, "price": 15},
	"item_kit_medico": {"name": "Kit medico", "desc": "Tasto sinistro: ti fai la puntura. +70 salute.", "model": "KitMedico", "heal": 70, "price": 90},
	"item_legna": {"name": "Legna", "desc": "Serve per il fuoco e per barricare.", "model": "Legna", "heal": 0},
	"item_batteria": {"name": "Batteria", "desc": "Serve per riparare il veicolo.", "model": "Batteria", "heal": 0},
	"item_tanica": {"name": "Tanica", "desc": "Serve per riparare il veicolo.", "model": "Tanica", "heal": 0},
	"item_cinghia": {"name": "Cinghia", "desc": "Serve per riparare il veicolo.", "model": "Cinghia", "heal": 0},
}
## Testa lasciata da ogni tipo di infetto (zombie_target.kind).
const KIND_HEAD := ["item_testa", "item_testa_corridore", "item_testa_bruto", "item_testa_urlatore", "item_testa_sputatore", "item_testa_carceriere"]
## Di che modello è la testa di ogni tipo: è proprio quella staccata dal cadavere.
const HEAD_MODEL := {"item_testa": "ZMB_Walker_1", "item_testa_corridore": "ZMB_Walker_4", "item_testa_sputatore": "ZMB_Spitter", "item_testa_urlatore": "ZMB_Walker_3",
	"item_testa_bruto": "ZMB_Tank", "item_testa_capomacello": "BOSS_Sheriff_Abomination", "item_testa_macellaio": "BOSS_Subject_Zero", "item_testa_carceriere": "ZMB_Tank", "item_testa_matriarca": "ZMB_Spitter", "item_testa_signore": "BOSS_Subject_Zero"}
## Solo teste e bende si tengono in più copie, fino a questo numero. Tutto il resto: una alla volta.
const MAX_STACK := 5
const OLD_NAMES := {"axe": "Ascia", "knife": "Coltello", "pistol": "Pistola"}
## Danno da lancio per id o per classe dell'arma.
const THROW_DAMAGE := {"axe": 45.0, "knife": 35.0, "combat_knife": 35.0, "pistol": 15.0}
const CLASS_DAMAGE := {"axe": 45.0, "sword": 45.0, "melee1h": 35.0, "pistol": 15.0, "rifle": 15.0}


static func is_item(id: String) -> bool:
	return ITEMS.has(id)


static func is_head(id: String) -> bool:
	return id.begins_with("item_testa")


static func stacks(id: String) -> bool:
	return is_head(id) or id == "item_bende"


static func head_price(id: String) -> int:
	return int(ITEMS.get(id, {}).get("sell", 0))


static func title(id: String) -> String:
	var value: String
	if ITEMS.has(id): value = str(ITEMS[id].name)
	elif OLD_NAMES.has(id): value = str(OLD_NAMES[id])
	else: value = str(ZXWeapons.get_def(id).get("name", id))
	return Localization.t(value)


static func throw_damage(id: String) -> float:
	if id == "item_testa": return 5.0
	if ITEMS.has(id): return 10.0
	if THROW_DAMAGE.has(id): return THROW_DAMAGE[id]
	return CLASS_DAMAGE.get(ZXWeapons.get_def(id).get("class", ""), 30.0)


## Armi pesanti a due mani: il lancio è più corto.
static func heavy(id: String) -> bool:
	return ZXWeapons.get_def(id).get("class", "") in ["axe", "rifle"]


## Modello 3D senza braccia: lo stesso del viewmodel. L'alto o il manico sta lungo +Y.
static func head_path(id: String) -> String:
	return "res://art/zx_infected/%s.glb" % HEAD_MODEL.get(id, "ZMB_Walker_1")


static func model(id: String) -> Node3D:
	if HEAD_MODEL.has(id):
		var head := preload("res://art/infected_anatomy.gd").severed(head_path(id), 0.22 if id in ["item_testa_bruto", "item_testa_carceriere"] else 0.2)
		if ITEMS[id].has("tint"): _tint(head, ITEMS[id].tint)
		return head
	var path := ""
	if ITEMS.has(id): path = "res://art/zx_fp/items/SM_FP_Item_%s.glb" % ITEMS[id].model
	else:
		match id:
			"axe": path = "res://art/zx_fp/SM_FP_Axe.glb"
			"knife": path = "res://art/zx_fp/SM_FP_CombatKnife.glb"
			_: path = str(ZXWeapons.get_def(id).get("scene", ""))
	if path == "" or not ResourceLoader.exists(path): return null
	var node: Node3D = load(path).instantiate()
	if ITEMS.get(id, {}).has("tint"): _tint(node, ITEMS[id].tint)
	for a in node.find_children("*", "AnimationPlayer", true, false): (a as AnimationPlayer).active = false
	for s in node.find_children("*", "StaticBody3D", true, false): s.queue_free()
	return node


## Stesso modello, colore del tipo di testa: moltiplica i materiali su copie locali.
static func _tint(node: Node3D, color: Color) -> void:
	if color == Color(1, 1, 1): return
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			var m := (mi as MeshInstance3D).mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var c := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				c.albedo_color = c.albedo_color * color
				(mi as MeshInstance3D).set_surface_override_material(i, c)
