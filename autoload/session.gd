extends Node
signal roster_changed
signal status_changed(message: String)
signal game_started
signal session_closed
const PORT := 27831
const MAX_PLAYERS := 4
var online: bool = false
var playing: bool = false
var roster: Dictionary = {}
var nickname: String = "Survivor"
var skin: int = 0
var status: String = "Choose how to play"
var endpoint_port: int = PORT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func() -> void: leave(Localization.t("Connection failed. Check the address and port.")))
	multiplayer.server_disconnected.connect(func() -> void: leave(Localization.t("The host closed the session.")))
	multiplayer.peer_disconnected.connect(_disconnected)

func info(message: String) -> void:
	status = message
	status_changed.emit(message)

func host(port: int = PORT) -> Error:
	leave("")
	endpoint_port = port
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port,MAX_PLAYERS-1)
	if result != OK:
		info(Localization.t("Port unavailable. Choose another port."))
		return result
	multiplayer.multiplayer_peer = peer
	multiplayer.server_relay = false
	online = true
	roster[1] = {"name":nickname.left(20),"skin":skin,"ready":true}
	info(Localization.t("Camp open / UDP {0}", [port]))
	roster_changed.emit()
	return OK

func join(address: String, port: int = PORT) -> Error:
	leave("")
	endpoint_port = port
	if address.strip_edges().is_empty():
		info(Localization.t("Enter the host address."))
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address.strip_edges(),port)
	if result != OK:
		info(Localization.t("Invalid address."))
		return result
	multiplayer.multiplayer_peer = peer
	online = true
	info(Localization.t("Connecting to camp…"))
	return OK

func _connected() -> void:
	register.rpc_id(1,nickname,skin)

@rpc("any_peer","call_remote","reliable")
func register(player_name: String, selected_skin: int) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if playing or (roster.size() >= MAX_PLAYERS and not roster.has(sender)):
		rejected.rpc_id(sender,Localization.t("Expedition started or camp full."))
		return
	roster[sender] = {"name":player_name.strip_edges().left(20),"skin":clampi(selected_skin,0,9),"ready":false}
	_sync()

@rpc("authority","call_remote","reliable")
func rejected(message: String) -> void:
	leave(message)

func profile(player_name: String, selected_skin: int) -> void:
	nickname = player_name.strip_edges().left(20)
	if nickname.is_empty(): nickname = "Survivor"
	skin = clampi(selected_skin,0,9)
	if online and roster.has(multiplayer.get_unique_id()):
		if multiplayer.is_server(): _profile(1,nickname,skin)
		else: update_profile.rpc_id(1,nickname,skin)
	roster_changed.emit()

func _profile(id: int, player_name: String, selected_skin: int) -> void:
	if playing or not roster.has(id): return
	roster[id].name = player_name.left(20)
	roster[id].skin = clampi(selected_skin,0,9)
	_sync()

@rpc("any_peer","call_remote","reliable")
func update_profile(player_name: String, selected_skin: int) -> void:
	if multiplayer.is_server(): _profile(multiplayer.get_remote_sender_id(),player_name,selected_skin)

func set_ready(value: bool) -> void:
	if not online: return
	if multiplayer.is_server():
		roster[1].ready = value
		_sync()
	else: ready_request.rpc_id(1,value)

@rpc("any_peer","call_remote","reliable")
func ready_request(value: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and roster.has(sender) and not playing:
		roster[sender].ready = value
		_sync()

func _sync() -> void:
	if not online or not multiplayer.is_server(): return
	for id in connected_peers(): receive_roster.rpc_id(id,roster)
	roster_changed.emit()

func connected_peers() -> Array[int]:
	var result: Array[int] = []
	if not online: return result
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not peer: return result
	for id in multiplayer.get_peers():
		var packet := peer.get_peer(id)
		if packet and packet.get_state() == ENetPacketPeer.STATE_CONNECTED and packet.get_channels()>0: result.append(id)
	return result

func local_address() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10."): return address
	for address in IP.get_local_addresses():
		if address.begins_with("172."): return address
	return "127.0.0.1"

@rpc("authority","call_remote","reliable")
func receive_roster(value: Dictionary) -> void:
	roster = value
	info(Localization.t("{0} / 4 survivors in camp", [roster.size()]))
	roster_changed.emit()

func launch() -> bool:
	if online:
		if not multiplayer.is_server(): return false
		for member in roster.values():
			if not member.ready:
				info(Localization.t("Wait until every survivor is ready."))
				return false
		multiplayer.multiplayer_peer.refuse_new_connections = true
		for id in connected_peers(): begin.rpc_id(id)
		begin()
	else: begin()
	return true

@rpc("authority","call_local","reliable")
func begin() -> void:
	playing = true
	game_started.emit()

func _disconnected(id: int) -> void:
	if not online or not multiplayer.is_server(): return
	roster.erase(id)
	call_deferred("_sync")

func leave(message: String = "Session closed") -> void:
	var was_playing := playing
	online = false
	playing = false
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	playing = false
	roster.clear()
	if not message.is_empty(): info(Localization.t(message))
	roster_changed.emit()
	if was_playing: session_closed.emit()
