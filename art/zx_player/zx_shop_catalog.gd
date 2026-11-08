class_name ZXShopCatalog
extends RefCounted
## Which weapons each zone's shop sells. 5 shop zones over the 8 GPS stops of world/campaign/route.gd:
##   Zona 1 = stop 0 (Lago Cenere), Zona 2 = stops 1-2, Zona 3 = stop 3, Zona 4 = stops 4-5, Zona 5 = stops 6-7.
## Every shop sells its own new arrivals plus everything from earlier zones (at a mark-up, the road is long).
## Prices are in CR, the credits the sheriff pays for heads. Weapon ids are the keys of ZXWeapons.DEFS.

const CURRENCY := "CR"
const CARRYOVER_MARKUP := 1.25   # weapons from earlier zones cost 25% more further down the road

const ZONES := [
	{"name": "LAGO CENERE", "stops": [0], "shop": "Emporio di Big Earl", "npc": "res://art/zx_npc/SM_NPC_Shopkeeper.glb",
	 "theme": "Rifugio e roba da garage: si combatte con quello che c'è.",
	 "stock": [
		{"id": "pistol", "price": 120},
		{"id": "flare_gun", "price": 90},
		{"id": "sawn_off", "price": 260},
		{"id": "machete", "price": 70},
		{"id": "crowbar", "price": 40},
		{"id": "nail_bat", "price": 55},
		{"id": "runic_axe", "price": 320},
		{"id": "spartan_sword", "price": 180},
		{"id": "bow", "price": 150},
		{"id": "arrows", "price": 20},
		{"id": "trout", "price": 15, "fun": true},
		{"id": "baguette", "price": 5, "fun": true},
	]},
	{"name": "PORTO SECCO / CAVA SILENTE", "stops": [1, 2], "shop": "Bazar di Porto Secco", "npc": "res://art/zx_npc/SM_NPC_Gunsmith.glb",
	 "theme": "Roba da deserto: armi lunghe per chi non vuole farsi avvicinare, attrezzi pesanti.",
	 "stock": [
		{"id": "revolver", "price": 220},
		{"id": "lever_rifle", "price": 380},
		{"id": "crossbow", "price": 340},
		{"id": "pump_shotgun", "price": 420},
		{"id": "pickaxe", "price": 130},
		{"id": "sledgehammer", "price": 190},
	]},
	{"name": "BORGO DEL RIPETITORE", "stops": [3], "shop": "Ferramenta del Borgo", "npc": "res://art/zx_npc/SM_NPC_Manager.glb",
	 "theme": "Il Dottor Ferri ha 'rilevato' la ferramenta. Ha anche un piano marketing.",
	 "stock": [
		{"id": "smg", "price": 520},
		{"id": "nailgun", "price": 300},
		{"id": "frying_pan", "price": 60, "fun": true},
		{"id": "electric_guitar", "price": 240, "fun": true},
		{"id": "rubber_chicken", "price": 25, "fun": true},
	]},
	{"name": "DEPOSITO MILITARE / DIGA NORD", "stops": [4, 5], "shop": "Spaccio del Deposito", "npc": "res://art/zx_npc/SM_NPC_Gunsmith.glb",
	 "theme": "Materiale militare dimenticato: potenza di fuoco vera.",
	 "stock": [
		{"id": "assault_rifle", "price": 780},
		{"id": "sniper_rifle", "price": 900},
		{"id": "lmg", "price": 1250},
		{"id": "combat_knife", "price": 160},
		{"id": "grenade_launcher", "price": 1400},
	]},
	{"name": "CENTRO DI RICERCA / ULTIMA FREQUENZA", "stops": [6, 7], "shop": "Laboratorio Abbandonato", "npc": "res://art/zx_npc/SM_NPC_Shopkeeper.glb",
	 "theme": "Prototipi e lame da collezione. Big Earl è arrivato prima di te.",
	 "stock": [
		{"id": "tesla_rifle", "price": 1800},
		{"id": "leaf_blower", "price": 666, "fun": true},
		{"id": "katana", "price": 1100},
		{"id": "longsword", "price": 950},
	]},
]


## Shop zone (0..4) for a GPS stop index (campaign.zone_index).
static func zone_for_stop(stop: int) -> int:
	for z in ZONES.size():
		if ZONES[z].stops.has(stop):
			return z
	return ZONES.size() - 1


## Items on sale in a zone: [{id, price, zone, new}], new arrivals first.
static func stock(zone: int, include_previous := true) -> Array:
	var out := []
	zone = clampi(zone, 0, ZONES.size() - 1)
	for e in ZONES[zone].stock:
		out.append({"id": e.id, "price": e.price, "zone": zone, "new": true, "fun": e.get("fun", false)})
	if include_previous:
		for z in zone:
			for e in ZONES[z].stock:
				out.append({"id": e.id, "price": int(round(e.price * CARRYOVER_MARKUP)), "zone": z, "new": false, "fun": e.get("fun", false)})
	return out


## Zone where a weapon is first sold (-1 if not in any shop).
static func zone_of(id: String) -> int:
	for z in ZONES.size():
		for e in ZONES[z].stock:
			if e.id == id:
				return z
	return -1


static func price(id: String, zone: int) -> int:
	for e in stock(zone):
		if e.id == id:
			return e.price
	return -1
