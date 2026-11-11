# Salvataggio dell'host. Un solo slot, scritto all'ingresso di ogni tappa e
# ripreso dal menu con CONTINUE. In cooperativa fa fede lo stato dell'host.
extends Node

signal save_completed(slot: int)
signal save_failed(reason: String)

const SLOT_PATH: String = "user://save_slot_1.json"
const REMOVED := ["spade", "fire_axe"]
var pending_resume: bool = false

func has_save() -> bool:
	return FileAccess.file_exists(SLOT_PATH)

func erase() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT_PATH))

func _vec(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

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
		"player": _vec(world.player.global_position),
		"credits": world.player.credits,
		"heads": world.player.carried_heads,
		"owned": world.player.owned,
		"equipped": world.player.equipped,
		"slots": world.player.inventory_slots,
		"items": world.player.items,
		"hotbar": world.player.hotbar,
		"slot": world.player.slot,
		"arrows": world.player.arrows,
		"magazine": world.player.magazine,
		"mags": world.player.mags,
		"threat": survival.threat if survival else 0,
		"intro": survival.seen_intro if survival else false,
		"road_started": roadblocks.triggered if roadblocks else [],
		"road_open": roadblocks.cleared if roadblocks else [],
		"boss_used": bosses.used if bosses else [],
		"boss_cleared": bosses.cleared if bosses else [],
		"baits": world.player.baits,
		"quest": world.quest.save_data() if world.get("quest") else {},
		"zone2": world.zone2.save_data() if world.get("zone2") else {},
	}
	var file := FileAccess.open(SLOT_PATH, FileAccess.WRITE)
	if file == null:
		save_failed.emit("write")
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	save_completed.emit(1)
	return true

func read() -> Dictionary:
	if not has_save():
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SLOT_PATH))
	return parsed if parsed is Dictionary else {}

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
	world.player.credits = int(data.get("credits", 0))
	# Le armi tolte dal gioco spariscono anche dai salvataggi vecchi.
	world.player.owned.assign((data.get("owned", ["axe"]) as Array).filter(func(w): return not w in REMOVED))
	world.player.equipped = "axe" if str(data.get("equipped", "axe")) in REMOVED else str(data.get("equipped", "axe"))
	world.player.inventory_slots = int(data.get("slots", 4))
	world.player.arrows = int(data.get("arrows", 0))
	# Salvataggi di prima della barra rapida: la barra si ricostruisce dalle armi.
	var saved_items: Dictionary = data.get("items", {})
	var bar: Array = data.get("hotbar", [])
	world.player.items = {}
	# Salvataggi di prima del borgo: la testa del Mago diventa quella del Macellaio.
	for key in saved_items: world.player.items[String(key).replace("item_testa_mago", "item_testa_macellaio")] = int(saved_items[key])
	# Salvataggi vecchi: le teste erano un numero solo e non c'era limite.
	if not data.has("quest") and int(data.get("heads", 0)) > 0: world.player.items["item_testa"] = mini(int(data.get("heads", 0)), ItemInfo.MAX_STACK)
	world.player.baits = int(data.get("baits", 0))
	world.player.hotbar.assign(["", "", "", "", "", "", "", "", ""])
	for i in mini(bar.size(), 9): world.player.hotbar[i] = "" if String(bar[i]) in REMOVED else String(bar[i]).replace("item_testa_mago", "item_testa_macellaio")
	if bar.is_empty():
		for id in world.player.owned: world.player.hotbar_add(id)
		for id in world.player.items: world.player.hotbar_add(id)
	world.player.slot = clampi(int(data.get("slot", 0)), 0, 8)
	if world.player.equipped != "" and world.player.hotbar.has(world.player.equipped): world.player.slot = world.player.hotbar.find(world.player.equipped)
	world.player.mags = data.get("mags", {})
	world.player.magazine = int(data.get("magazine", preload("res://weapons/zx_arsenal.gd").magazine(world.player.equipped)))
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
	mission._refresh()
	mission._publish()
	mission.save_signature = mission._signature()
	world.announce(Localization.t("PARTITA RIPRESA · TAPPA {0}", [mission.zone_index + 1]), 4)
	return true
