# Salvataggio dell'host. Un solo slot, scritto all'ingresso di ogni tappa e
# ripreso dal menu con CONTINUE. In cooperativa fa fede lo stato dell'host.
# Ogni ospite ha la sua roba in "players", sotto un ID stabile che si porta da casa (user://player_id.cfg):
# la scrive l'host quando salva e quando l'ospite si scollega, e gliela ridà quando la partita riprende.
extends Node

signal save_completed(slot: int)
signal save_failed(reason: String)

const SLOT_PATH: String = "user://save_slot_1.json"
## Copia dell'ultimo salvataggio buono: se il file principale è rotto (gioco chiuso mentre scriveva) si riparte da qui.
const BACKUP_PATH: String = "user://save_slot_1.bak.json"
## La campagna sostituita da una nuova partita, finché non se ne inizia un'altra.
const OLD_PATH: String = "user://save_slot_1.old.json"
const REMOVED := ["spade", "fire_axe"]
var pending_resume: bool = false
const ID_PATH: String = "user://player_id.cfg"
## ID stabile di questo giocatore: nasce al primo avvio e non cambia più.
var player_id: String = ""
## Sull'host: peer collegato → suo ID stabile.
var peer_ids: Dictionary = {}

func _ready() -> void:
	player_id = _load_id()
	multiplayer.connected_to_server.connect(func() -> void: introduce.rpc_id(1, player_id))
	multiplayer.peer_disconnected.connect(_on_peer_left)

func _load_id() -> String:
	var cfg := ConfigFile.new()
	cfg.load(ID_PATH)
	var id := str(cfg.get_value("player", "id", ""))
	if id.is_empty():
		id = Crypto.new().generate_random_bytes(16).hex_encode()
		cfg.set_value("player", "id", id)
		cfg.save(ID_PATH)
	return id

## L'ospite si presenta all'host appena collegato.
@rpc("any_peer", "call_remote", "reliable")
func introduce(id: String) -> void:
	if not multiplayer.is_server(): return
	var clean := id.strip_edges().left(64)
	if not clean.is_empty(): peer_ids[multiplayer.get_remote_sender_id()] = clean

## L'ospite se ne va a metà partita: la sua roba entra subito nel salvataggio, prima che l'attore sparisca.
func _on_peer_left(peer: int) -> void:
	var id: String = peer_ids.get(peer, "")
	peer_ids.erase(peer)
	var world := _world()
	if id.is_empty() or world == null or not multiplayer.is_server() or not world.started or not world.actors.has(peer): return
	var data := read()
	if data.is_empty(): return
	var players: Dictionary = data.get("players", {})
	players[id] = player_state(world.actors[peer])
	data["players"] = players
	_store(data)

func _world() -> Node:
	for node in get_tree().root.get_children():
		if node.get("expedition") != null and node.get("actors") != null: return node
	return null

func has_save() -> bool:
	return FileAccess.file_exists(SLOT_PATH) or FileAccess.file_exists(BACKUP_PATH)

## Nuova partita: la campagna non si cancella, si sposta in OLD_PATH.
func erase() -> void:
	if FileAccess.file_exists(SLOT_PATH): _move(SLOT_PATH, OLD_PATH)
	elif FileAccess.file_exists(BACKUP_PATH): _move(BACKUP_PATH, OLD_PATH)
	if FileAccess.file_exists(BACKUP_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))

func _move(from: String, to: String) -> void:
	if FileAccess.file_exists(to): DirAccess.remove_absolute(ProjectSettings.globalize_path(to))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))

## Per il menu: tappa (da 1), crediti e boss sconfitti della campagna salvata.
func summary() -> Dictionary:
	var data := read()
	var bosses := 0
	for done in data.get("boss_cleared", []): bosses += int(bool(done))
	var quest: Dictionary = data.get("quest", {})
	bosses += int(bool(quest.get("carceriere", false)))
	return {"stage": int(data.get("zone", 0)) + 1, "credits": int(data.get("credits", 0)), "bosses": bosses}

func _vec(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

## Chi salva seduto nel 4×4 riparte in piedi accanto all'auto, non dentro la sua collisione.
func _standing_point(world: Node, mission) -> Vector3:
	var seat: int = mission.car.seat_of(multiplayer.get_unique_id())
	if seat < 0: return world.player.global_position
	var exit_at: Vector3 = mission.car.safe_exit(seat, world.player)
	return exit_at if exit_at != Vector3.INF else mission.car.global_position + Vector3.UP * 2.2

func write(world: Node) -> bool:
	var mission = world.get("expedition")
	if mission == null or not world.started:
		return false
	var survival = world.get("survival")
	var roadblocks = world.get("roadblocks")
	var bosses = world.get("boss_hunt")
	var data := {
		"version": 1,
		"time": int(Time.get_unix_time_from_system()),
		"stage": mission.stage,
		"zone": mission.zone_index,
		"unlocked": mission.unlocked,
		"collected": mission.collected,
		"car_repaired": mission.car.repaired,
		"car": _vec(mission.car.global_position),
		"player": _vec(_standing_point(world, mission)),
		"heads": world.player.carried_heads,
		"threat": survival.threat if survival else 0,
		"intro": survival.seen_intro if survival else false,
		"road_started": roadblocks.triggered if roadblocks else [],
		"road_open": roadblocks.cleared if roadblocks else [],
		"boss_used": bosses.used if bosses else [],
		"boss_cleared": bosses.cleared if bosses else [],
		"quest": world.quest.save_data() if world.get("quest") else {},
		"zone2": world.zone2.save_data() if world.get("zone2") else {},
	}
	data.merge(player_state(world.player))
	if world.get("zone_life"): data["food"] = world.zone_life.food.duplicate()
	# Ospiti: chi è collegato adesso più chi c'era nelle sessioni prima (restano finché non si ricomincia).
	var players: Dictionary = read().get("players", {})
	for peer in world.actors:
		if peer != multiplayer.get_unique_id() and peer_ids.has(peer): players[peer_ids[peer]] = player_state(world.actors[peer])
	data["players"] = players
	return _store(data)

## La roba di un giocatore: la stessa per l'host (in cima al file) e per ogni ospite (in "players").
func player_state(a: Node) -> Dictionary:
	return {
		"credits": a.credits, "owned": a.owned, "equipped": a.equipped, "slots": a.inventory_slots,
		"health_ups": a.health_ups, "stamina_ups": a.stamina_ups, "items": a.items, "reserve": a.reserve,
		"hotbar": a.hotbar, "slot": a.slot, "arrows": a.arrows, "magazine": a.magazine, "mags": a.mags, "baits": a.baits,
	}

func _store(data: Dictionary) -> bool:
	# Scrive accanto e poi sostituisce: chiudere il gioco a metà lascia intatto l'ultimo salvataggio.
	var temp := SLOT_PATH + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		save_failed.emit("write")
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(SLOT_PATH) and read_file(SLOT_PATH).size() > 0: _move(SLOT_PATH, BACKUP_PATH)
	_move(temp, SLOT_PATH)
	save_completed.emit(1)
	return true

func read() -> Dictionary:
	var data := read_file(SLOT_PATH)
	return data if not data.is_empty() else read_file(BACKUP_PATH)

func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary and parsed.has("stage") else {}

func apply(world: Node) -> bool:
	var data := read()
	var mission = world.get("expedition")
	if data.is_empty() or mission == null:
		return false
	mission.stage = int(data.get("stage", 0))
	mission.zone_index = int(data.get("zone", 0))
	mission.unlocked = int(data.get("unlocked", 0))
	mission.collected = data.get("collected", [false, false, false])
	mission.hold = 8.0
	mission.downloading = false
	mission.repairing_peer = 0
	var car = mission.car
	var car_at: Array = data.get("car", [0.0, 0.28, 0.0])
	car.global_position = Vector3(float(car_at[0]), float(car_at[1]), float(car_at[2]))
	car.repaired = bool(data.get("car_repaired", false))
	var player_at: Array = data.get("player", [3.0, 0.5, 2.0])
	world.player.reset_at(Vector3(float(player_at[0]), float(player_at[1]), float(player_at[2])))
	apply_player(world.player, data)
	# Ogni ospite ritrova la sua roba (si è presentato con l'ID stabile nella lobby).
	var players: Dictionary = data.get("players", {})
	for peer in world.actors:
		if peer != multiplayer.get_unique_id() and players.has(peer_ids.get(peer, "")): apply_player(world.actors[peer], players[peer_ids[peer]])
	if world.get("zone_life") and data.has("food"):
		for kind in world.zone_life.food: world.zone_life.food[kind] = int(data["food"].get(kind, 0))
	var survival = world.get("survival")
	if survival:
		survival.threat = int(data.get("threat", 0))
		survival.seen_intro = bool(data.get("intro", false))
	var roadblocks = world.get("roadblocks")
	if roadblocks:
		roadblocks.triggered.assign(data.get("road_started", [false, false]))
		roadblocks.cleared.assign(data.get("road_open", [false, false]))
		roadblocks.refresh()
	var bosses = world.get("boss_hunt")
	if bosses:
		bosses.used.assign((data.get("boss_used", [false]) as Array).slice(0, 1))
		bosses.cleared.assign((data.get("boss_cleared", [false]) as Array).slice(0, 1))
		# Un boss evocato ma non ucciso non esiste più dopo il caricamento: si riprende l'esca e si riaccende.
		for i in bosses.used.size():
			if bosses.used[i] and not bosses.cleared[i]:
				bosses.used[i] = false
				world.player.baits += 1
	var quest = world.get("quest")
	if quest:
		var saved: Dictionary = data.get("quest", {})
		if saved.is_empty() and mission.stage >= 1: saved = {"stage": quest.DONE, "delivered": quest.TOTAL_HEADS, "weapon": true, "carceriere": true}
		quest.load_data(saved)
		# Lo scontro del borgo non si salva: chi lo stava combattendo ritrova l'esca, come per il Capomacello.
		if quest.stage == quest.VILLAGE_BOSS and world.player.baits == 0: world.player.baits = 1
		quest._publish()
	if world.get("zone2"):
		world.zone2.load_data(data.get("zone2", {}))
		world.zone2._publish()
	if world.get("zone_gates"): world.zone_gates._first = true
	if world.get("zone_gates"): world.zone_gates.refresh()
	# Non si riparte sotto terra: la Rocca al caricamento è di nuovo chiusa.
	if world.player.global_position.y > 150.0 and world.get("rocca"): world.player.reset_at(world.rocca.entrance_pos + Vector3.UP * 0.3)
	if survival: survival._publish()
	mission._refresh()
	mission._publish()
	mission.save_signature = mission._signature()
	world.announce(Localization.t("PARTITA RIPRESA · TAPPA {0}", [mission.zone_index + 1]), 4)
	return true

## Rimette la roba salvata su un giocatore (l'host o un ospite).
func apply_player(a: Node, data: Dictionary) -> void:
	a.credits = int(data.get("credits", 0))
	# Le armi tolte dal gioco spariscono anche dai salvataggi vecchi.
	a.owned.assign((data.get("owned", ["axe"]) as Array).filter(func(w): return not w in REMOVED))
	a.equipped = "axe" if str(data.get("equipped", "axe")) in REMOVED else str(data.get("equipped", "axe"))
	a.inventory_slots = int(data.get("slots", 4))
	a.health_ups = (data.get("health_ups", {}) as Dictionary).duplicate()
	a.stamina_ups = (data.get("stamina_ups", {}) as Dictionary).duplicate()
	a.health = a.max_health()
	a.stamina = a.max_stamina()
	a.arrows = int(data.get("arrows", 0))
	# Salvataggi di prima della barra rapida: la barra si ricostruisce dalle armi.
	var saved_items: Dictionary = data.get("items", {})
	var bar: Array = data.get("hotbar", [])
	a.items = {}
	# Salvataggi di prima del borgo: la testa del Mago diventa quella del Macellaio.
	for key in saved_items: a.items[String(key).replace("item_testa_mago", "item_testa_macellaio")] = int(saved_items[key])
	# Salvataggi vecchi: le teste erano un numero solo e non c'era limite.
	if not data.has("quest") and int(data.get("heads", 0)) > 0: a.items["item_testa"] = mini(int(data.get("heads", 0)), ItemInfo.MAX_STACK)
	a.baits = int(data.get("baits", 0))
	a.hotbar.assign(["", "", "", "", "", "", "", "", ""])
	for i in mini(bar.size(), 9): a.hotbar[i] = "" if String(bar[i]) in REMOVED else String(bar[i]).replace("item_testa_mago", "item_testa_macellaio")
	if bar.is_empty():
		for id in a.owned: a.hotbar_add(id)
		for id in a.items: a.hotbar_add(id)
	# Premi senza tasca: la riserva, e gli oggetti rimasti fuori dalla barra nei salvataggi di prima.
	a.reserve = {}
	for key in data.get("reserve", {}): a.reserve[String(key)] = int(data["reserve"][key])
	for id in a.items.keys():
		if not a.hotbar.has(id):
			a.reserve[id] = int(a.reserve.get(id, 0)) + int(a.items[id])
			a.items.erase(id)
	a.slot = clampi(int(data.get("slot", 0)), 0, 8)
	if a.equipped != "" and a.hotbar.has(a.equipped): a.slot = a.hotbar.find(a.equipped)
	a.mags = data.get("mags", {})
	a.magazine = int(data.get("magazine", preload("res://weapons/zx_arsenal.gd").magazine(a.equipped)))
