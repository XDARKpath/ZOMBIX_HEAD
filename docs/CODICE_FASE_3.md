# Codice della Fase 3

Questi file sono già presenti nel progetto; non occorre incollarli. Le dipendenze delle fasi precedenti rimangono nelle rispettive cartelle.

## project.godot

```
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="TESTE"
run/main_scene="res://world/zona1_rifugio/fase3.tscn"
config/features=PackedStringArray("4.5", "GL Compatibility")
config/icon="res://art/icon.svg"

[autoload]

GameState="*res://autoload/game_state.gd"
EconomyManager="*res://autoload/economy_manager.gd"
SaveManager="*res://autoload/save_manager.gd"
AudioManager="*res://autoload/audio_manager.gd"
TimeManager="*res://autoload/time_manager.gd"
Session="*res://autoload/session.gd"

[display]

window/size/viewport_width=1440
window/size/viewport_height=900
window/size/window_width_override=1440
window/size/window_height_override=900
window/stretch/mode="canvas_items"

[input]

move_forward={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":1,"axis_value":-1.0,"script":null)
]
}
move_back={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":1,"axis_value":1.0,"script":null)
]
}
move_left={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":0,"axis_value":-1.0,"script":null)
]
}
move_right={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":0,"axis_value":1.0,"script":null)
]
}
sprint={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194325,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":7,"pressure":0.0,"pressed":false,"script":null)
]
}
dodge={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194326,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":1,"pressure":0.0,"pressed":false,"script":null)
]
}
interact={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":0,"pressure":0.0,"pressed":false,"script":null)
]
}
reload={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":82,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":2,"pressure":0.0,"pressed":false,"script":null)
]
}
heal={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":81,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":11,"pressure":0.0,"pressed":false,"script":null)
]
}
vehicle={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":70,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":3,"pressure":0.0,"pressed":false,"script":null)
]
}
inventory={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194306,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":4,"pressure":0.0,"pressed":false,"script":null)
]
}
map={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":77,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":12,"pressure":0.0,"pressed":false,"script":null)
]
}
pause={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":6,"pressure":0.0,"pressed":false,"script":null)
]
}
weapon_1={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":49,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
weapon_2={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":50,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
weapon_3={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":51,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
weapon_4={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":52,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
weapon_5={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":53,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
preview_help={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194332,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
preview_view_0={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194337,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
preview_view_1={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194338,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
preview_view_2={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194339,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
attack={
"deadzone": 0.22,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":5,"axis_value":1.0,"script":null)
]
}
aim={
"deadzone": 0.22,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":2,"canceled":false,"pressed":false,"double_click":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":4,"axis_value":1.0,"script":null)
]
}
weapon_next={
"deadzone": 0.22,
"events": [Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":10,"pressure":0.0,"pressed":false,"script":null)
]
}
weapon_previous={
"deadzone": 0.22,
"events": [Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":9,"pressure":0.0,"pressed":false,"script":null)
]
}
look_left={
"deadzone": 0.22,
"events": [Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":2,"axis_value":-1.0,"script":null)
]
}
look_right={
"deadzone": 0.22,
"events": [Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":2,"axis_value":1.0,"script":null)
]
}
look_up={
"deadzone": 0.22,
"events": [Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":3,"axis_value":-1.0,"script":null)
]
}
look_down={
"deadzone": 0.22,
"events": [Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":3,"axis_value":1.0,"script":null)
]
}
test_damage={
"deadzone": 0.22,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194333,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}

[layer_names]

3d_physics/layer_1="Mondo"
3d_physics/layer_2="Giocatore"
3d_physics/layer_3="Nemici"
3d_physics/layer_4="Interazioni"
3d_physics/layer_5="Bottino"

[rendering]

renderer/rendering_method="forward_plus"
renderer/rendering_method.mobile="forward_plus"
environment/defaults/default_clear_color=Color(0.055, 0.09, 0.11, 1)
```

## autoload/session.gd

```gdscript
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
var nickname: String = "Sopravvissuto"
var skin: int = 0
var status: String = "Scegli come giocare"
var endpoint_port: int = PORT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func() -> void: leave("Connessione non riuscita. Controlla indirizzo e porta."))
	multiplayer.server_disconnected.connect(func() -> void: leave("L'host ha chiuso la sessione."))
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
		info("Porta non disponibile: scegli un'altra porta.")
		return result
	multiplayer.multiplayer_peer = peer
	multiplayer.server_relay = false
	online = true
	roster[1] = {"name":nickname.left(20),"skin":skin,"ready":true}
	info("Accampamento aperto · porta %d" % port)
	roster_changed.emit()
	return OK

func join(address: String, port: int = PORT) -> Error:
	leave("")
	endpoint_port = port
	if address.strip_edges().is_empty():
		info("Inserisci l'indirizzo dell'host.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address.strip_edges(),port)
	if result != OK:
		info("Indirizzo non valido.")
		return result
	multiplayer.multiplayer_peer = peer
	online = true
	info("Connessione all'accampamento…")
	return OK

func _connected() -> void:
	register.rpc_id(1,nickname,skin)

@rpc("any_peer","call_remote","reliable")
func register(player_name: String, selected_skin: int) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if playing or (roster.size() >= MAX_PLAYERS and not roster.has(sender)):
		rejected.rpc_id(sender,"Partita già iniziata o accampamento pieno.")
		return
	roster[sender] = {"name":player_name.strip_edges().left(20),"skin":clampi(selected_skin,0,2),"ready":false}
	_sync()

@rpc("authority","call_remote","reliable")
func rejected(message: String) -> void:
	leave(message)

func profile(player_name: String, selected_skin: int) -> void:
	nickname = player_name.strip_edges().left(20)
	if nickname.is_empty(): nickname = "Sopravvissuto"
	skin = clampi(selected_skin,0,2)
	if online and roster.has(multiplayer.get_unique_id()):
		if multiplayer.is_server(): _profile(1,nickname,skin)
		else: update_profile.rpc_id(1,nickname,skin)
	roster_changed.emit()

func _profile(id: int, player_name: String, selected_skin: int) -> void:
	if playing or not roster.has(id): return
	roster[id].name = player_name.left(20)
	roster[id].skin = clampi(selected_skin,0,2)
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
	info("%d / 4 giocatori nell'accampamento" % roster.size())
	roster_changed.emit()

func launch() -> bool:
	if online:
		if not multiplayer.is_server(): return false
		for member in roster.values():
			if not member.ready:
				info("Attendi che tutti siano pronti.")
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

func leave(message: String = "Sessione chiusa") -> void:
	var was_playing := playing
	online = false
	playing = false
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	playing = false
	roster.clear()
	if not message.is_empty(): info(message)
	roster_changed.emit()
	if was_playing: session_closed.emit()
```

## world/zona1_rifugio/fase3.tscn

```
[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://world/zona1_rifugio/fase3.gd" id="1"]
[ext_resource type="PackedScene" path="res://player/player.tscn" id="2"]
[node name="Rifugio" type="Node3D"]
process_mode = 3
script = ExtResource("1")
[node name="Player" parent="." instance=ExtResource("2")]
position = Vector3(3,0.5,2)
[node name="SpawnPoint" type="Marker3D" parent="."]
position = Vector3(3,0.5,2)
[node name="Interface" type="CanvasLayer" parent="."]
```

## world/zona1_rifugio/fase3.gd

```gdscript
extends "res://world/zona1_rifugio/fase2.gd"
const SKINS := preload("res://ui/camp/camp.gd").MODELS
var camp: Node3D
var menu: Control
var nav_region: NavigationRegion3D
var actors: Dictionary = {}
var next_enemy_id: int = 1
var spawn_clock: float = 0
var net_clock: float = 0
var player_avatar: Node3D
var snapshots_received: int = 0
var ui_open: bool = true
var profile_config := ConfigFile.new()
var settings_data := {"sensitivity":1.0,"volume":70.0,"blood":true,"shadows":true,"fullscreen":false,"resolution":1}

func _ready() -> void:
	automated = not OS.get_cmdline_user_args().is_empty()
	_load_preferences()
	nav_region = NavigationRegion3D.new()
	add_child(nav_region)
	landscape = Node3D.new()
	landscape.process_mode = Node.PROCESS_MODE_PAUSABLE
	landscape.set_script(preload("res://world/zona1_rifugio/landscape.gd"))
	nav_region.add_child(landscape)
	landscape.build()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.agent_radius = 0.5
	mesh.agent_height = 2.0
	mesh.agent_max_climb = 0.5
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.filter_baking_aabb = AABB(Vector3(-44,-2,-72),Vector3(88,15,85))
	nav_region.navigation_mesh = mesh
	nav_region.bake_navigation_mesh(false)
	player_avatar = _dress(player,Session.skin)
	sound = AudioStreamPlayer.new()
	add_child(sound)
	# Retain the compact gameplay HUD from phase 2; replace the main menu entirely.
	super._build_ui()
	pause_panel.hide()
	settings_panel.hide()
	camp = Node3D.new()
	camp.set_script(preload("res://ui/camp/camp.gd"))
	add_child(camp)
	camp.build()
	menu = Control.new()
	menu.set_script(preload("res://ui/camp/menu.gd"))
	$Interface.add_child(menu)
	menu.build(self)
	player.vitals_changed.connect(_update_vitals)
	player.died.connect(func() -> void: _respawn(player))
	player.fell_out.connect(func() -> void: _respawn(player))
	player.melee.attack_rejected.connect(announce)
	player.melee.charge_started.connect(func() -> void: _send_action("charge"))
	player.melee.attack_started.connect(_local_attack)
	player.dodge_started.connect(func() -> void: _send_action("dodge"))
	player.melee.impact.connect(func(_target: Node3D,heavy: bool) -> void: _play("heavy" if heavy else "hit"))
	Session.game_started.connect(_begin_play)
	Session.roster_changed.connect(_roster_changed)
	Session.session_closed.connect(_back_to_camp)
	_apply_settings()
	_roster_changed()
	set_paused(true)
	for arg in OS.get_cmdline_user_args():
		if arg == "--verify3": call_deferred("_verify3")
		elif arg.begins_with("--capture="): _capture(arg.trim_prefix("--capture="))
		elif arg == "--capture-play": Session.launch()
		elif arg == "--capture-skin": choose_skin(2); menu.skins()
		elif arg.begins_with("--net-host="): _test_host(int(arg.get_slice("=",1)))
		elif arg.begins_with("--net-join="): _test_join(int(arg.get_slice("=",1)))

func _dress(body: CharacterBody3D, skin_id: int) -> Node3D:
	for child in body.roll_pivot.get_children():
		if child.name == "Survivor":
			body.roll_pivot.remove_child(child)
			child.queue_free()
		elif child is Node3D: child.hide()
	var avatar := Node3D.new()
	avatar.name = "Survivor"
	avatar.set_script(preload("res://art/survivor_visual.gd"))
	body.roll_pivot.add_child(avatar)
	avatar.position.y = -0.9
	avatar.rotation.y = PI
	avatar.configure(SKINS[clampi(skin_id,0,2)],body)
	return avatar

func _roster_changed() -> void:
	if not camp: return
	var ids: Array = Session.roster.keys()
	ids.sort()
	if Session.online:
		for i in range(4):
			if i < ids.size(): camp.set_skin(i,Session.roster[ids[i]].skin)
			camp.avatars[i].visible = i < ids.size()
	else:
		for i in range(3):
			camp.set_skin(i,Session.skin if i == 0 else i)
			camp.avatars[i].show()
		camp.avatars[3].hide()
	if started:
		for id in actors.keys():
			if id != multiplayer.get_unique_id() and not Session.roster.has(id):
				actors[id].queue_free()
				actors.erase(id)
	if menu:
		if menu.page == "home" and ui_open: menu.home()
		else: menu.refresh()

func choose_skin(value: int) -> void:
	Session.profile(Session.nickname,value)
	player_avatar = _dress(player,Session.skin)
	_save_preferences()

func _begin_play() -> void:
	started = true
	kills = 0
	next_enemy_id = 1
	actors.clear()
	actors[multiplayer.get_unique_id()] = player
	player.reset_at(Vector3(3,0.5,2))
	player.melee.replica = Session.online and not multiplayer.is_server()
	var index := 0
	for id in Session.roster:
		if id == multiplayer.get_unique_id(): continue
		var body: CharacterBody3D = load("res://player/player.tscn").instantiate()
		body.name = "Peer%d" % id
		body.position = Vector3(3+index*1.8,0.5,3)
		body.local_control = false
		add_child(body)
		_dress(body,Session.roster[id].skin)
		body.rig.controls_enabled = false
		body.rig.set_physics_process(false)
		body.rig.camera.current = false
		body.melee.replica = not multiplayer.is_server()
		if not multiplayer.is_server():
			body.set_physics_process(false)
		body.died.connect(func() -> void: _respawn(body))
		body.melee.attack_started.connect(func(_heavy: bool) -> void: _noise(body))
		actors[id] = body
		index += 1
	if not Session.online or multiplayer.is_server(): _spawn_targets()
	set_paused(false)
	announce("Gli infetti sentono i colpi. Tieni libera la via del ritorno.",5)

func _spawn_targets() -> void:
	for body in targets:
		if is_instance_valid(body): body.queue_free()
	targets.clear()
	for point in [Vector3(3,0,-9),Vector3(10,0,-12),Vector3(-3,0,-15),Vector3(7,0,-25),Vector3(-7,0,-31),Vector3(16,0,-40)]:
		_spawn_enemy(point)
	spawn_clock = 15

func _spawn_enemy(at: Vector3, enemy_id: int = -1) -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.set_script(preload("res://enemies/zombie_ai.gd"))
	enemy.network_id = next_enemy_id if enemy_id < 0 else enemy_id
	next_enemy_id = maxi(next_enemy_id,enemy.network_id+1)
	enemy.name = "Enemy%d" % enemy.network_id
	enemy.position = at+Vector3.UP*0.1
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(enemy)
	enemy.setup(enemy.network_id%3)
	enemy.world = self
	enemy.replica = Session.online and not multiplayer.is_server()
	enemy.blood_enabled = blood_enabled
	enemy.rotation.y = PI
	enemy.defeated.connect(func(_body: Node3D) -> void: kills += 1)
	targets.append(enemy)
	return enemy

func nearest_player(at: Vector3) -> CharacterBody3D:
	var result: CharacterBody3D
	var distance := INF
	for body in actors.values():
		if is_instance_valid(body) and not body.dead and body.position.distance_squared_to(at)<distance:
			distance = body.position.distance_squared_to(at)
			result = body
	return result

func _process(delta: float) -> void:
	if not started: return
	if get_tree().paused: return
	for i in range(targets.size()-1,-1,-1):
		if not is_instance_valid(targets[i]): targets.remove_at(i)
	if player.position.y < -1 and not returning: _respawn(player)
	var alive := 0
	for body in targets:
		if not body.dead: alive += 1
	objective.text = "LAGO CENERE\nInfetti vicini: %d  ·  Abbattuti: %d" % [alive,kills]
	charge_bar.value = player.melee.charge_fraction()*100
	charge_bar.visible = player.melee.charging
	notice_left = maxf(0,notice_left-delta)
	notice.visible = notice_left > 0
	if not Session.online or multiplayer.is_server():
		spawn_clock -= delta
		if spawn_clock <= 0 and alive < 8 and targets.size()<24:
			spawn_clock = 15
			var point := Vector3(randf_range(-6,14),0,randf_range(-50,-25))
			var closest := nearest_player(point)
			if closest and closest.position.distance_to(point)>12: _spawn_enemy(point)
	if Session.online:
		net_clock += delta
		if net_clock >= 0.05:
			net_clock = 0
			if multiplayer.is_server(): _send_snapshot()
			else:
				var movement := Input.get_vector("move_left","move_right","move_forward","move_back") if not ui_open else Vector2.ZERO
				input_packet.rpc_id(1,movement,player.rig.yaw,Input.is_action_pressed("sprint") and not ui_open)

func _noise(body: CharacterBody3D) -> void:
	for enemy in targets:
		if is_instance_valid(enemy): enemy.hear(body)

func _local_attack(_heavy: bool) -> void:
	_play("swing")
	_send_action("release")
	if not Session.online or multiplayer.is_server(): _noise(player)

func _send_action(action: String) -> void:
	if Session.online and not multiplayer.is_server() and started: action_packet.rpc_id(1,action)

@rpc("any_peer","call_remote","unreliable_ordered")
func input_packet(movement: Vector2, yaw: float, sprint: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not started or not actors.has(id) or not movement.is_finite() or not is_finite(yaw): return
	var body: CharacterBody3D = actors[id]
	body.network_move = movement.limit_length(1)
	body.network_sprint = sprint
	body.rig.yaw = wrapf(yaw,-PI,PI)
	body.input_age = 0

@rpc("any_peer","call_remote","reliable")
func action_packet(action: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not started or not actors.has(id): return
	var body: CharacterBody3D = actors[id]
	match action:
		"charge": body.melee.begin_charge()
		"release": body.melee.release_attack()
		"dodge": body.try_dodge(body.rig.movement_direction(body.network_move))

func _send_snapshot() -> void:
	var people: Array = []
	for id in actors:
		var body: CharacterBody3D = actors[id]
		people.append([id,body.position,body.visual.rotation.y,body.velocity,body.health,body.stamina,body.dead,body.melee.attacking,body.melee.attack_time,body.melee.charged_attack,body.dodging,body.dodge_elapsed])
	var enemies: Array = []
	for body in targets:
		if is_instance_valid(body): enemies.append([body.network_id,body.position,body.rotation.y,body.velocity,body.health,body.dead,int(body.state),body.visual.rotation.x,body.visual.position.y])
	for id in Session.connected_peers(): snapshot.rpc_id(id,people,enemies,kills)

@rpc("authority","call_remote","unreliable_ordered")
func snapshot(people: Array, enemies: Array, count: int) -> void:
	if not started: return
	snapshots_received += 1
	kills = count
	for row in people:
		if not actors.has(row[0]): continue
		var body: CharacterBody3D = actors[row[0]]
		var local: bool = row[0] == multiplayer.get_unique_id()
		if local:
			if body.position.distance_to(row[1])>2.0 or body.dead != row[6]: body.position = row[1]
			else: body.position = body.position.lerp(row[1],0.12)
		else:
			body.position = body.position.lerp(row[1],0.6)
			body.visual.rotation.y = row[2]
			body.velocity = row[3]
			body.melee.attacking = row[7]
			body.melee.attack_time = row[8]
			body.melee.charged_attack = row[9]
			body.melee.active_windup = 0.24 if row[9] else 0.16
			body.melee.active_recovery = 0.46 if row[9] else 0.32
			body.dodging = row[10]
			body.dodge_elapsed = row[11]
			body._animate(0.05)
		body.health = row[4]
		body.stamina = row[5]
		body.dead = row[6]
		if local:
			body.rig.controls_enabled = not ui_open and not body.dead
			_update_vitals(body.health,body.stamina)
	var by_id: Dictionary = {}
	for body in targets:
		if is_instance_valid(body): by_id[body.network_id] = body
	var received: Array = []
	for row in enemies:
		var body: Node3D = by_id.get(row[0])
		if not is_instance_valid(body): body = _spawn_enemy(row[1],row[0])
		if row[4] < body.health and body.position.distance_to(player.position)<3:
			_play("hit")
			player.rig.add_shake(0.25)
		body.position = row[1]
		body.rotation.y = row[2]
		body.velocity = row[3]
		body.health = row[4]
		body.dead = row[5]
		body.state = row[6]
		body.visual.rotation.x = row[7]
		body.visual.position.y = row[8]
		body.collision_layer = 0 if body.dead else 4
		body.bar.visible = not body.dead and body.health<72
		body.bar.scale.x = body.health/72.0
		received.append(row[0])
	for body in targets:
		if is_instance_valid(body) and not received.has(body.network_id): body.queue_free()

func _respawn(body: CharacterBody3D) -> void:
	if Session.online and not multiplayer.is_server(): return
	if body.get_meta("respawning",false): return
	body.set_meta("respawning",true)
	body.dead = true
	body.melee.cancel()
	await get_tree().create_timer(1.5,false).timeout
	if is_instance_valid(body):
		body.reset_at(Vector3(3,0.5,2))
		body.set_meta("respawning",false)

func set_paused(value: bool) -> void:
	ui_open = value
	get_tree().paused = value and not Session.online
	hud.visible = not value
	if menu: menu.visible = value
	player.controls_enabled = not value
	player.rig.controls_enabled = not value
	if value: player.melee.cancel()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or automated else Input.MOUSE_MODE_CAPTURED
	if camp:
		camp.set_active(not started)
		if started: player.rig.camera.current = true
	for child in landscape.get_children():
		if child is DirectionalLight3D: child.visible = started
	if menu: menu.home()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if started: set_paused(not ui_open)
		else: menu.home()
	elif event.is_action_pressed("preview_help"): set_paused(true); menu.controls()

func _back_to_camp() -> void:
	started = false
	get_tree().paused = false
	for body in actors.values():
		if body != player and is_instance_valid(body): body.queue_free()
	actors.clear()
	for body in targets:
		if is_instance_valid(body): body.queue_free()
	targets.clear()
	player.reset_at(Vector3(3,0.5,2))
	set_paused(true)

func leave_game() -> void:
	if Session.playing: Session.leave()
	else: _back_to_camp()

func _load_preferences() -> void:
	if profile_config.load("user://preferences.cfg") == OK:
		for key in settings_data: settings_data[key] = profile_config.get_value("settings",key,settings_data[key])
		Session.nickname = str(profile_config.get_value("profile","name","Sopravvissuto"))
		Session.skin = clampi(int(profile_config.get_value("profile","skin",0)),0,2)

func _save_preferences() -> void:
	if automated: return
	for key in settings_data: profile_config.set_value("settings",key,settings_data[key])
	profile_config.set_value("profile","name",Session.nickname)
	profile_config.set_value("profile","skin",Session.skin)
	profile_config.save("user://preferences.cfg")

func _apply_settings() -> void:
	player.rig.sensitivity = float(settings_data.sensitivity)
	blood_enabled = bool(settings_data.blood)
	AudioServer.set_bus_volume_db(0,linear_to_db(float(settings_data.volume)/100))
	for body in targets:
		if is_instance_valid(body): body.blood_enabled = blood_enabled
	for child in landscape.get_children():
		if child is DirectionalLight3D: child.shadow_enabled = bool(settings_data.shadows)
	if not automated:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings_data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not settings_data.fullscreen:
			DisplayServer.window_set_size([Vector2i(1280,800),Vector2i(1440,900),Vector2i(1600,1000)][clampi(int(settings_data.resolution),0,2)])
	_save_preferences()

func _capture(path: String) -> void:
	await get_tree().create_timer(4,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

func _verify3() -> void:
	var checks := preload("res://tests/phase3_checks.gd").new()
	var success: bool = await checks.run(self)
	Session.leave()
	get_tree().quit(0 if success else 1)

func _test_host(port: int) -> void:
	Session.host(port)
	get_tree().paused = false
	await get_tree().create_timer(7,true).timeout
	Session.launch()
	print("NET_HOST_START roster=",Session.roster.size()," actors=",actors.size())
	await get_tree().create_timer(1.5,true).timeout
	for id in actors:
		if id != 1:
			targets[0].position = actors[id].position+Vector3(0,0,-1.3)
			targets[0].set_physics_process(false)
			break
	await get_tree().create_timer(3,true).timeout
	var damage_ok: bool = targets[0].health<72
	print("NET_HOST_DAMAGE health=",targets[0].health," validated=",damage_ok)
	await get_tree().create_timer(5,true).timeout
	Session.leave()
	get_tree().quit(0 if damage_ok else 1)

func _test_join(port: int) -> void:
	Session.profile("Peer%d" % OS.get_process_id(),OS.get_process_id()%3)
	Session.join("127.0.0.1",port)
	get_tree().paused = false
	await get_tree().create_timer(3,true).timeout
	Session.set_ready(true)
	await Session.game_started
	await get_tree().create_timer(0.4,true).timeout
	var initial := player.position
	Input.action_press("move_right")
	await get_tree().create_timer(0.8,true).timeout
	Input.action_release("move_right")
	await get_tree().create_timer(0.4,true).timeout
	var moved: bool = player.position.distance_to(initial)>1
	player.melee.begin_charge()
	await get_tree().create_timer(0.8,true).timeout
	player.melee.release_attack()
	await get_tree().create_timer(0.35,true).timeout
	var expected := 2
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected-peers="): expected = int(arg.get_slice("=",1))
	print("NET_CLIENT roster=",Session.roster.size()," actors=",actors.size()," snapshots=",snapshots_received," enemies=",targets.size()," moved=",moved," stamina=",player.stamina)
	var good: bool = actors.size()==expected and snapshots_received>10 and targets.size()>0 and moved and player.stamina<85
	await get_tree().create_timer(4,true).timeout
	Session.leave()
	get_tree().quit(0 if good else 1)
```

## enemies/zombie_ai.gd

```gdscript
extends "res://enemies/zombie_target.gd"
enum State { WANDER, CHASE, ATTACK, DEAD }
var state: State = State.WANDER
var agent: NavigationAgent3D
var world: Node3D
var target: CharacterBody3D
var memory: float = 0
var think: float = 0
var wander_timer: float = 0
var attack_clock: float = 0
var attack_done: bool = false
var corpse_time: float = 0
var network_id: int = 0
var replica: bool = false
var last_seen := Vector3.ZERO

func setup(variant: int) -> void:
	super.setup(variant)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.65
	agent.path_height_offset = 0.4
	agent.target_desired_distance = 0.65
	agent.radius = 0.4
	add_child(agent)
	visual.rotation.y = PI
	wander_timer = randf_range(1,3)

func see(candidate: CharacterBody3D) -> bool:
	if not is_instance_valid(candidate) or candidate.dead: return false
	var offset := candidate.global_position-global_position
	if offset.length() > 15: return false
	if offset.length() > 2.5 and (-global_basis.z).dot(offset.normalized()) < 0.25: return false
	return clear_line(candidate)

func clear_line(candidate: CharacterBody3D) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.3,candidate.global_position+Vector3.UP,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func hear(candidate: CharacterBody3D, radius: float = 15) -> void:
	if dead or candidate.dead or global_position.distance_to(candidate.global_position)>radius: return
	target = candidate
	last_seen = candidate.global_position
	memory = 6
	state = State.CHASE

func receive_melee(amount: float, force: Vector3, heavy: bool) -> bool:
	if replica: return false
	var hit := super.receive_melee(amount,force,heavy)
	if dead:
		state = State.DEAD
		corpse_time = 30
	elif hit and world:
		var nearest: CharacterBody3D = world.nearest_player(global_position)
		if nearest: hear(nearest,40)
	return hit

func _physics_process(delta: float) -> void:
	if replica: return
	if dead:
		corpse_time -= delta
		if corpse_time <= 0: queue_free(); return
		super._physics_process(delta)
		return
	clock += delta
	stagger = maxf(0,stagger-delta)
	think -= delta
	memory = maxf(0,memory-delta)
	if think <= 0:
		think = 0.2
		var nearest: CharacterBody3D = world.nearest_player(global_position) if world else null
		if not nearest or nearest.global_position.distance_to(global_position)>50:
			think = 0.8
			velocity = Vector3.ZERO
			return
		if see(nearest):
			target = nearest
			last_seen = target.global_position
			memory = 6
			if state != State.ATTACK: state = State.CHASE
		if state == State.CHASE:
			agent.target_position = last_seen
	if stagger > 0:
		velocity.x = move_toward(velocity.x,0,10*delta)
		velocity.z = move_toward(velocity.z,0,10*delta)
	elif state == State.ATTACK:
		velocity.x = 0
		velocity.z = 0
		attack_clock += delta
		visual.rotation.x = -sin(minf(attack_clock/0.8,1)*PI)*0.25
		if attack_clock >= 0.5 and not attack_done:
			attack_done = true
			if is_instance_valid(target) and not target.dead and global_position.distance_to(target.global_position)<1.8 and clear_line(target):
				target.take_damage(14)
		if attack_clock >= 1.2:
			state = State.CHASE
			visual.rotation.x = 0
	else:
		var speed := 0.8
		if state == State.CHASE:
			speed = 1.85
			if not is_instance_valid(target) or target.dead or memory <= 0:
				state = State.WANDER
				target = null
			elif global_position.distance_to(target.global_position)<1.5 and clear_line(target):
				state = State.ATTACK
				attack_clock = 0
				attack_done = false
		else:
			wander_timer -= delta
			if wander_timer <= 0:
				wander_timer = randf_range(3,6)
				agent.target_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map,home+Vector3(randf_range(-5,5),0,randf_range(-5,5)))
		var direction := Vector3.ZERO
		if NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map)>0 and not agent.is_navigation_finished():
			direction = agent.get_next_path_position()-global_position
			direction.y = 0
			direction = direction.normalized()
		velocity.x = direction.x*speed
		velocity.z = direction.z*speed
		if direction.length_squared()>0.01: rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),delta*5)
	velocity.y = 0 if is_on_floor() else velocity.y-22*delta
	move_and_slide()
```

## ui/camp/camp.gd

```gdscript
extends Node3D
const MODELS := ["SK_Chr_Hunter_Male_01","SK_Chr_Soldier_Male_01","SK_Chr_Contractor_Male_02"]
const NAMES := ["CACCIATORE","RICOGNITORE","VETERANO"]
var avatars: Array[Node3D] = []
var camera: Camera3D
var fire: OmniLight3D
var moon: DirectionalLight3D
var timer: float = 0
var crackle: AudioStreamPlayer3D

func build() -> void:
	position = Vector3(200,0,0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(45,45)
	ground.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = load("res://world/zona1_rifugio/ground.gdshader")
	ground.material_override = material
	add_child(ground)
	for i in range(16):
		var tree: Node3D = load("res://art/surroundead/SM_Tree_Pine_01.glb").instantiate()
		tree.position = Vector3(cos(i*0.6)*9,0,-5-absf(sin(i*0.6))*8)
		tree.scale = Vector3.ONE*(1.3+float(i%4)*0.35)
		add_child(tree)
		_tint(tree,Color("3c594a"))
	for i in range(10):
		var rock: Node3D = load("res://art/surroundead/SM_Env_Rock_01.glb").instantiate()
		rock.position = Vector3(cos(i*TAU/10)*0.65,0,sin(i*TAU/10)*0.65+0.3)
		rock.scale = Vector3(0.3,0.25,0.3)
		add_child(rock)
	for i in range(3):
		var log: Node3D = load("res://art/surroundead/SM_Tree_Log_01.glb").instantiate()
		log.position = Vector3(0,0.13,0.3)
		log.rotation.y = i*PI/3
		log.scale = Vector3(0.5,0.5,0.35)
		add_child(log)
	var seat: Node3D = load("res://art/surroundead/SM_Tree_Log_01.glb").instantiate()
	seat.position = Vector3(1.7,0.25,-0.9)
	seat.rotation.y = PI/2
	seat.scale = Vector3(1.4,1.4,0.6)
	add_child(seat)
	for i in range(4):
		avatars.append(null)
		set_skin(i,i%3)
	avatars[3].hide()
	var flames := CPUParticles3D.new()
	flames.amount = 26
	flames.lifetime = 0.75
	flames.preprocess = 2
	flames.direction = Vector3.UP
	flames.spread = 12
	flames.gravity = Vector3(0,0.5,0)
	flames.initial_velocity_min = 0.3
	flames.initial_velocity_max = 0.7
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.22
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45,0.85)
	flames.mesh = quad
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = load("res://ui/camp/flame.gdshader")
	flames.material_override = flame_mat
	flames.position = Vector3(0,0.2,0.3)
	add_child(flames)
	var sparks := CPUParticles3D.new()
	sparks.position = Vector3(0,0.5,0.3)
	sparks.amount = 16
	sparks.lifetime = 2.2
	sparks.preprocess = 2.2
	sparks.direction = Vector3.UP
	sparks.spread = 18
	sparks.gravity = Vector3(0,0.3,0)
	sparks.initial_velocity_min = 0.4
	sparks.initial_velocity_max = 0.9
	var ember := SphereMesh.new()
	ember.radius = 0.012
	ember.height = 0.024
	var ember_mat := StandardMaterial3D.new()
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mat.albedo_color = Color("ffbe56")
	ember_mat.emission_enabled = true
	ember_mat.emission = Color("ff7e24")
	ember.material = ember_mat
	sparks.mesh = ember
	add_child(sparks)
	if DisplayServer.get_name() != "headless" and ResourceLoader.exists("res://audio/fire.wav"):
		crackle = AudioStreamPlayer3D.new()
		var stream: AudioStreamWAV = load("res://audio/fire.wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size()/2
		crackle.stream = stream
		crackle.position = Vector3(0,0.3,0.3)
		crackle.volume_db = -3
		crackle.unit_size = 5
		add_child(crackle)
	fire = OmniLight3D.new()
	fire.position = Vector3(0,0.85,0.3)
	fire.light_color = Color("ff9d40")
	fire.omni_range = 9
	fire.light_energy = 4.5
	fire.shadow_enabled = true
	add_child(fire)
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38,100,0)
	moon.light_color = Color("6c98bb")
	moon.light_energy = 0.7
	add_child(moon)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(4,3.0,7.6)
	camera.look_at(global_position+Vector3(-1.2,0.95,-0.5))
	camera.fov = 48
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111f2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("708396")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.018
	env.fog_light_color = Color("172e38")
	camera.environment = env

func set_skin(slot: int, skin_id: int) -> void:
	if is_instance_valid(avatars[slot]):
		remove_child(avatars[slot])
		avatars[slot].queue_free()
	var avatar := Node3D.new()
	avatar.set_script(load("res://ui/camp/camp_avatar.gd"))
	avatar.stance = slot%3
	avatar.position = [Vector3(-1.8,0,-0.6),Vector3(1.7,-0.45,-0.9),Vector3(0.1,0,-2.4),Vector3(-2.8,0,-2.1)][slot]
	avatar.rotation.y = [0.7,-0.9,0.1,0.5][slot]
	add_child(avatar)
	avatar.configure(MODELS[clampi(skin_id,0,2)],self)
	if slot%3 == 2: avatar.add_knife()
	avatars[slot] = avatar

func set_active(value: bool) -> void:
	visible = value
	moon.visible = value
	fire.visible = value
	camera.current = value
	if crackle:
		if value and not crackle.playing: crackle.play()
		elif not value: crackle.stop()

func _process(delta: float) -> void:
	timer += delta
	if fire: fire.light_energy = 4.5+sin(timer*13)*0.3+sin(timer*21)*0.17

func _tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		node.material_override = mat
	for child in node.get_children(): _tint(child,color)
```

## ui/camp/camp_avatar.gd

```gdscript
extends "res://art/survivor_visual.gd"
var stance: int = 0
var knife: Node3D

func _pose(_delta: float) -> void:
	if not skeleton: return
	rotate_bone("upperarm_l",Vector3.BACK,-1.35)
	rotate_bone("upperarm_r",Vector3.BACK,1.35)
	rotate_bone("spine_01",Vector3.RIGHT,sin(clock*1.3)*0.018)
	rotate_bone("head",Vector3.RIGHT,0.12+sin(clock*0.5)*0.035)
	if stance == 1:
		rotate_bone("thigh_l",Vector3.RIGHT,-1.45)
		rotate_bone("thigh_r",Vector3.RIGHT,-1.45)
		rotate_bone("calf_l",Vector3.RIGHT,1.45)
		rotate_bone("calf_r",Vector3.RIGHT,1.45)
		transform_bone("upperarm_l",Basis(Vector3.RIGHT,-0.4)*Basis(Vector3.BACK,-1.3))
		transform_bone("upperarm_r",Basis(Vector3.RIGHT,-0.4)*Basis(Vector3.BACK,1.3))
		rotate_bone("spine_01",Vector3.RIGHT,0.16)
	elif stance == 2:
		transform_bone("upperarm_r",Basis(Vector3.RIGHT,-1.0)*Basis(Vector3.BACK,1.15))
		rotate_bone("lowerarm_r",Vector3.RIGHT,-0.7+sin(clock*0.7)*0.08)
		transform_bone("head",Basis(Vector3.UP,-0.2+sin(clock*0.5)*0.07)*Basis(Vector3.RIGHT,0.35))
	if axe: axe.hide()
	if knife and bone_ids.has("hand_r"):
		knife.global_position = (skeleton.global_transform*skeleton.get_bone_global_pose(bone_ids.hand_r)).origin
		knife.global_rotation = global_rotation+Vector3(0.2,sin(clock*0.7)*0.12,0.1)

func add_knife() -> void:
	knife = load("res://art/surroundead/SM_Wep_Melee_HuntingKnife_01.glb").instantiate()
	add_child(knife)
	knife.scale = Vector3.ONE*0.65
```

## ui/camp/menu.gd

```gdscript
extends Control
var world: Node3D
var page: String = "home"
var status_label: Label
var roster_label: Label
var ready_button: Button

func build(owner_world: Node3D) -> void:
	world = owner_world
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift","Segoe UI"])
	var style := Theme.new()
	style.default_font = font
	theme = style
	Session.status_changed.connect(func(_message: String) -> void: refresh())
	home()

func clear(title: String, subtitle: String = "") -> void:
	ready_button = null
	roster_label = null
	for child in get_children(): remove_child(child); child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.018,0.035,0.045,0.80)
	shade.position = Vector2(26,26)
	shade.size = Vector2(398,794)
	add_child(shade)
	label(title,Vector2(52,60),65)
	label(subtitle,Vector2(56,144),14,Color("d8b687"))
	status_label = label(Session.status,Vector2(52,842),15,Color("b6c8c7"))
	status_label.size.x = 1320
	status_label.clip_text = true
	label("TESTE  0.3  /  LAGO CENERE",Vector2(1130,31),12,Color("99b2b4"))

func label(text: String, at: Vector2, size: int, color: Color = Color("f0eee1")) -> Label:
	return world._label(self,text,at,size,color)

func button(text: String, y: float, callback: Callable) -> Button:
	var node: Button = world._button(self,text,Vector2(54,y),callback)
	node.size = Vector2(340,52)
	return node

func home() -> void:
	page = "home"
	clear("TESTE" if not world.started else "PAUSA","ATTORNO AL FUOCO" if not world.started else "LA SQUADRA TI ASPETTA")
	if world.started:
		label("La partita online continua\nmentre sei nel menu." if Session.online else "Un momento per riprendere fiato.",Vector2(56,200),17)
		button("RIPRENDI",300,func() -> void: world.set_paused(false))
		button("IMPOSTAZIONI",366,settings)
		button("COMANDI",432,controls)
		button("TORNA ALL'ACCAMPAMENTO",498,world.leave_game)
	else:
		label("Prepara la squadra.\nPoi affrontate quello che resta.",Vector2(56,193),18,Color("b8c8c5"))
		if Session.online:
			button("ENTRA NEL MONDO" if multiplayer.is_server() else "ATTENDI L'HOST",280,func() -> void: Session.launch()).disabled = not multiplayer.is_server()
			ready_button = button("SONO PRONTO",346,_toggle_ready)
			button("PERSONAGGIO",412,skins)
			button("IMPOSTAZIONI",478,settings)
			button("LASCIA LA LOBBY",544,func() -> void: Session.leave(); home())
		else:
			button("GIOCA DA SOLO",280,func() -> void: Session.launch())
			button("OSPITA UNA PARTITA",346,func() -> void: connection(true))
			button("UNISCITI AGLI AMICI",412,func() -> void: connection(false))
			button("PERSONAGGIO",478,skins)
			button("IMPOSTAZIONI",544,settings)
		if Session.online and multiplayer.is_server():
			button("COPIA INDIRIZZO LOCALE",610,func() -> void:
				DisplayServer.clipboard_set(Session.local_address())
				Session.info("Indirizzo locale copiato · porta %d" % Session.endpoint_port))
		else: button("COMANDI",610,controls)
		button("ESCI DAL GIOCO",676,func() -> void: Session.leave(); get_tree().quit())
		roster_label = label("",Vector2(505,752),18)
		label("COOPERATIVA  /  FINO A 4 GIOCATORI",Vector2(56,778),11,Color("98aeaf"))
	refresh()

func refresh() -> void:
	if status_label: status_label.text = Session.status
	if roster_label:
		if Session.online:
			var text := "SQUADRA  %d / 4\n" % Session.roster.size()
			var index := 0
			for id in Session.roster:
				var profile: Dictionary = Session.roster[id]
				text += "%s  ·  %s     " % [profile.name,"PRONTO" if profile.ready else "SI PREPARA"]
				index += 1
				if index%2 == 0: text += "\n"
			roster_label.position.y = 710
			roster_label.text = text
			if multiplayer.is_server(): roster_label.text += "\nRete locale: %s  ·  Porta UDP %d" % [Session.local_address(),Session.endpoint_port]
		else:
			roster_label.position.y = 752
			roster_label.text = "IL TUO ACCAMPAMENTO\nTre pose d'anteprima · gli amici appariranno nella lobby"
	if ready_button and Session.roster.has(multiplayer.get_unique_id()):
		ready_button.text = "PRONTO  ✓" if Session.roster[multiplayer.get_unique_id()].ready else "SONO PRONTO"

func _toggle_ready() -> void:
	if Session.roster.has(multiplayer.get_unique_id()): Session.set_ready(not Session.roster[multiplayer.get_unique_id()].ready)

func field(at: Vector2, text: String, placeholder: String) -> LineEdit:
	var line := LineEdit.new()
	line.position = at
	line.size = Vector2(335,44)
	line.text = text
	line.placeholder_text = placeholder
	line.max_length = 64
	line.add_theme_font_size_override("font_size",19)
	add_child(line)
	return line

func connection(hosting: bool) -> void:
	page = "connect"
	clear("OSPITA" if hosting else "UNISCITI","UNA SERATA, FINO A QUATTRO SOPRAVVISSUTI")
	label("Il tuo nome",Vector2(56,215),17)
	var username := field(Vector2(56,245),Session.nickname,"Nome")
	username.max_length = 20
	label("Porta della partita",Vector2(56,315),17)
	var port := SpinBox.new()
	port.position = Vector2(56,345)
	port.size = Vector2(335,44)
	port.min_value = 1024
	port.max_value = 65535
	port.value = Session.PORT
	add_child(port)
	var address: LineEdit
	if not hosting:
		label("Indirizzo dell'host",Vector2(56,415),17)
		address = field(Vector2(56,445),"","es. 192.168.1.10")
	else: label("Gli amici useranno il tuo indirizzo\ne questa porta per collegarsi.",Vector2(56,420),17)
	button("APRI L'ACCAMPAMENTO" if hosting else "COLLEGATI",530,func() -> void:
		Session.profile(username.text,Session.skin)
		world._save_preferences()
		var result: Error = Session.host(int(port.value)) if hosting else Session.join(address.text,int(port.value))
		if result == OK:
			get_tree().paused = false
			home())
	button("INDIETRO",600,home)
	label("Online tramite collegamento diretto.\nSu Internet l'host deve rendere\nraggiungibile la porta UDP scelta.\nNessun account richiesto.",Vector2(56,695),14,Color("a9bcbc"))

func skins() -> void:
	page = "skins"
	clear("PERSONA","IL TUO VOLTO ALL'ACCAMPAMENTO")
	label("La scelta resta salvata e appare\nanche agli altri giocatori.",Vector2(56,210),17)
	for i in range(3):
		var index := i
		var title: String = preload("res://ui/camp/camp.gd").NAMES[i]
		button(("✓  " if Session.skin == i else "")+title,300+i*76,func() -> void: world.choose_skin(index); skins())
	button("INDIETRO",620,home)

func settings() -> void:
	page = "settings"
	clear("OPZIONI","LE TUE PREFERENZE VENGONO SALVATE")
	label("Volume effetti",Vector2(56,210),18)
	slider("volume",Vector2(56,246),0,100,1)
	label("Sensibilità visuale",Vector2(56,300),18)
	slider("sensitivity",Vector2(56,338),0.3,2,0.05)
	check("Sangue","blood",414)
	check("Ombre","shadows",472)
	label("Dimensione finestra",Vector2(56,530),17)
	var resolution := OptionButton.new()
	resolution.position = Vector2(56,564)
	resolution.size = Vector2(330,40)
	for title in ["1280 × 800","1440 × 900","1600 × 1000"]: resolution.add_item(title)
	resolution.select(clampi(int(world.settings_data.resolution),0,2))
	add_child(resolution)
	resolution.item_selected.connect(func(index: int) -> void: world.settings_data.resolution = index; world._apply_settings())
	check("Schermo intero","fullscreen",626)
	button("INDIETRO",710,home)

func slider(key: String, at: Vector2, minimum: float, maximum: float, step: float) -> void:
	var control := HSlider.new()
	control.position = at
	control.size = Vector2(330,30)
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = world.settings_data[key]
	add_child(control)
	control.value_changed.connect(func(value: float) -> void: world.settings_data[key] = value; world._apply_settings())

func check(title: String, key: String, y: float) -> void:
	var control := CheckButton.new()
	control.position = Vector2(56,y)
	control.text = title
	control.button_pressed = world.settings_data[key]
	control.add_theme_font_size_override("font_size",19)
	add_child(control)
	control.toggled.connect(func(value: bool) -> void: world.settings_data[key] = value; world._apply_settings())

func controls() -> void:
	page = "controls"
	clear("COMANDI","RESTARE VIVI È UN LAVORO DI SQUADRA")
	label("WASD  ·  Muoviti\nMOUSE  ·  Guarda\nSHIFT  ·  Corri\nSPAZIO / CTRL  ·  Schiva\nCLICK  ·  Colpo rapido\nTIENI + RILASCIA  ·  Caricato\nESC  ·  Menu",Vector2(56,230),20)
	label("Gli infetti vedono e sentono.\nIl colpo caricato li respinge.\nIn cooperativa il mondo continua\nanche mentre apri il menu.\n\nLa pesca alimentare arriverà\nin una fase successiva.",Vector2(56,470),17,Color("b5c4c1"))
	button("INDIETRO",700,home)
```

## ui/camp/flame.gdshader

```
shader_type spatial;
render_mode unshaded,cull_disabled,blend_add,depth_draw_never;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float width=mix(0.7,0.05,1.0-UV.y);
 float sway=sin(UV.y*8.0+TIME*6.0)*0.12;
 float edge=1.0-smoothstep(width*0.35,width,abs(p.x+sway));
 float alpha=edge*smoothstep(0.0,0.15,UV.y)*(1.0-smoothstep(0.7,1.0,UV.y));
 ALBEDO=mix(vec3(1.0,0.18,0.015),vec3(1.0,0.8,0.25),UV.y);
 EMISSION=ALBEDO*2.0;
 ALPHA=alpha*0.8;
}
```

## player/player.gd

```gdscript
# Nodo: Player (CharacterBody3D), player/player.tscn.
# Figli: CollisionShape3D, Visual/RollPivot/LeftLeg e RightLeg,
# Visual/RollPivot/LeftArm e RightArm, CameraRig, WeaponHolder.
extends CharacterBody3D

signal vitals_changed(health: float, stamina: float)
signal damaged(amount: float)
signal died
signal fell_out
signal dodge_started

const Balance = preload("res://autoload/balance.gd")
@onready var rig: Node3D = $CameraRig
@onready var visual: Node3D = $Visual
@onready var roll_pivot: Node3D = $Visual/RollPivot
@onready var left_leg: Node3D = $Visual/RollPivot/LeftLeg
@onready var right_leg: Node3D = $Visual/RollPivot/RightLeg
@onready var left_arm: Node3D = $Visual/RollPivot/LeftArm
@onready var right_arm: Node3D = $Visual/RollPivot/RightArm
@onready var melee: Node3D = $MeleeController
var health: float = Balance.PLAYER_MAX_HEALTH
var stamina: float = Balance.PLAYER_MAX_STAMINA
var dead: bool = false
var sprinting: bool = false
var exhausted: bool = false
var dodging: bool = false
var dodge_elapsed: float = 0.0
var dodge_cooldown: float = 0.0
var regen_delay: float = 0.0
var dodge_direction: Vector3 = Vector3.FORWARD
var animation_clock: float = 0.0
var local_control: bool = true
var controls_enabled: bool = true
var network_move := Vector2.ZERO
var network_sprint: bool = false
var input_age: float = 0

func _ready() -> void:
	floor_snap_length = Balance.FLOOR_SNAP
	vitals_changed.emit(health, stamina)

func _physics_process(delta: float) -> void:
	if dead:
		return
	input_age += delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if local_control else network_move
	if not controls_enabled or (not local_control and input_age > 0.5): input = Vector2.ZERO
	var direction: Vector3 = rig.movement_direction(input)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	regen_delay = maxf(0, regen_delay - delta)
	if exhausted and stamina >= Balance.EXHAUSTION_RECOVERY:
		exhausted = false
	if local_control and controls_enabled and Input.is_action_just_pressed("dodge"):
		try_dodge(direction)
	sprinting = false
	if dodging:
		dodge_elapsed += delta
		velocity.x = dodge_direction.x * Balance.DODGE_SPEED
		velocity.z = dodge_direction.z * Balance.DODGE_SPEED
		if dodge_elapsed >= Balance.DODGE_SECONDS:
			dodging = false
			dodge_cooldown = Balance.DODGE_COOLDOWN
			roll_pivot.rotation.x = 0
	else:
		var wants_sprint: bool = Input.is_action_pressed("sprint") if local_control else network_sprint
		sprinting = wants_sprint and input.length() > 0.1 and not exhausted and stamina > 0 and is_on_floor() and not melee.attacking and not melee.charging
		var speed: float = Balance.SPRINT_SPEED if sprinting else Balance.WALK_SPEED
		if melee.attacking or melee.charging:
			speed *= Balance.ATTACK_MOVE_MULTIPLIER
		var acceleration: float = Balance.ACCELERATION if input.length() > 0.1 else Balance.DECELERATION
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
		if sprinting:
			stamina = maxf(0, stamina - Balance.SPRINT_DRAIN * delta)
			regen_delay = Balance.STAMINA_REGEN_DELAY
			if stamina <= 0:
				exhausted = true
	if not dodging and not sprinting and regen_delay <= 0:
		stamina = minf(Balance.PLAYER_MAX_STAMINA, stamina + Balance.STAMINA_REGEN * delta)
	if not is_on_floor():
		velocity.y -= Balance.GRAVITY * delta
	else:
		velocity.y = 0
	move_and_slide()
	var facing: Vector3 = dodge_direction if dodging else direction
	if facing.length_squared() > 0.01 and not melee.attacking and not melee.charging:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), minf(1, Balance.TURN_SPEED * delta))
	_animate(delta)
	vitals_changed.emit(health, stamina)
	if global_position.y < Balance.FALL_RESET_Y:
		dead = true
		velocity = Vector3.ZERO
		rig.controls_enabled = false
		fell_out.emit()

func try_dodge(direction: Vector3) -> bool:
	if melee.attacking or dead or dodging or dodge_cooldown > 0 or stamina < Balance.DODGE_COST or not is_on_floor():
		return false
	melee.cancel()
	dodge_direction = direction.normalized() if direction.length_squared() > 0.01 else -visual.global_basis.z
	dodge_direction.y = 0
	dodge_direction = dodge_direction.normalized()
	stamina = maxf(0, stamina - Balance.DODGE_COST)
	regen_delay = Balance.STAMINA_REGEN_DELAY
	dodging = true
	dodge_elapsed = 0
	dodge_started.emit()
	return true

func is_invulnerable() -> bool:
	return dodging and dodge_elapsed < Balance.DODGE_IFRAMES

func take_damage(amount: float) -> bool:
	if dead or is_invulnerable() or amount <= 0:
		return false
	var applied: float = minf(health, amount)
	health = maxf(0, health - amount)
	damaged.emit(applied)
	vitals_changed.emit(health, stamina)
	if health <= 0:
		dead = true
		sprinting = false
		dodging = false
		velocity = Vector3.ZERO
		rig.controls_enabled = false
		died.emit()
	return true

func reset_at(point: Vector3) -> void:
	melee.cancel()
	global_position = point
	velocity = Vector3.ZERO
	health = Balance.PLAYER_MAX_HEALTH
	stamina = Balance.PLAYER_MAX_STAMINA
	dead = false
	sprinting = false
	exhausted = false
	dodging = false
	dodge_elapsed = 0
	dodge_cooldown = 0
	regen_delay = 0
	roll_pivot.rotation = Vector3.ZERO
	roll_pivot.position.y = 0.9
	rig.controls_enabled = true
	rig.reset_follow()
	vitals_changed.emit(health, stamina)

func _animate(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	animation_clock += horizontal_speed * Balance.WALK_ANIMATION_SPEED * delta
	var weight: float = clampf(horizontal_speed / Balance.WALK_SPEED, 0, 1)
	var swing: float = sin(animation_clock) * Balance.LEG_SWING * weight
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -swing * 0.7
	right_arm.rotation.x = swing * 0.7
	roll_pivot.position.y = 0.9 + absf(sin(animation_clock)) * Balance.BODY_BOB * weight
	roll_pivot.rotation.x = -TAU * clampf(dodge_elapsed / Balance.DODGE_SECONDS, 0, 1) if dodging else 0.0

	if melee.attacking or melee.charging:
		right_arm.rotation.x = -1.0 + melee.pose() * 1.5
		right_arm.rotation.z = -0.3 - melee.pose() * 0.4
	else:
		right_arm.rotation.z = 0
```

## weapons/melee/melee_controller.gd

```gdscript
# Nodo Player/MeleeController (Node3D). Figlio HitArea (Area3D + CollisionShape3D).
# Richiede il padre player.gd e la sua gerarchia Visual. I modelli sono indipendenti dal danno.
extends Node3D

signal attack_started(charged: bool)
signal impact(target: Node3D, charged: bool)
signal attack_rejected(reason: String)
signal charge_started

const Balance = preload("res://autoload/balance.gd")
const Weapon = preload("res://weapons/melee/axe.tres")
@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var area: Area3D = $HitArea
var charging: bool = false
var charge_time: float = 0
var attacking: bool = false
var charged_attack: bool = false
var attack_time: float = 0
var hit_ids: Dictionary = {}
var stopping: bool = false
var swing_side: float = 1
var active_windup: float = 0
var active_recovery: float = 0
var replica: bool = false

func _physics_process(delta: float) -> void:
	global_position = player.global_position
	rotation.y = player.visual.rotation.y
	if player.dead:
		cancel()
		return
	if not attacking:
		if player.local_control and player.controls_enabled and Input.is_action_just_pressed("attack"):
			begin_charge()
		if charging:
			charge_time = minf(charge_time + delta, Weapon.charge_seconds * 1.5)
			if player.dodging:
				charging = false
			elif player.local_control and Input.is_action_just_released("attack"):
				release_attack()
	else:
		attack_time += delta
		if not replica and attack_time >= active_windup and attack_time <= active_windup + Weapon.active_seconds:
			for body in area.get_overlapping_bodies():
				try_hit(body)
		if attack_time >= active_windup + Weapon.active_seconds + active_recovery:
			attacking = false

func begin_charge() -> bool:
	if attacking or charging or player.dead or player.dodging:
		return false
	if player.stamina < Weapon.stamina_cost:
		attack_rejected.emit("Riprendi fiato.")
		return false
	charging = true
	charge_time = 0
	charge_started.emit()
	return true

func release_attack() -> bool:
	if not charging:
		return false
	charging = false
	return perform_attack(charge_time >= Weapon.charge_seconds)

func perform_attack(charged: bool) -> bool:
	var cost: float = Weapon.charged_stamina_cost if charged else Weapon.stamina_cost
	if attacking or player.dead or player.dodging or player.stamina < cost:
		attack_rejected.emit("Stamina insufficiente.")
		return false
	player.stamina -= cost
	player.regen_delay = Balance.STAMINA_REGEN_DELAY
	charged_attack = charged
	attacking = true
	attack_time = 0
	hit_ids.clear()
	active_windup = Weapon.charged_windup if charged else Weapon.windup
	active_recovery = Weapon.charged_recovery if charged else Weapon.recovery
	player.visual.rotation.y = player.rig.yaw
	rotation.y = player.rig.yaw
	swing_side = -swing_side
	attack_started.emit(charged)
	return true

func try_hit(body: Node3D) -> bool:
	if not attacking or attack_time < active_windup or attack_time > active_windup + Weapon.active_seconds:
		return false
	if not is_instance_valid(body) or not body.has_method("receive_melee") or hit_ids.has(body.get_instance_id()):
		return false
	var offset := body.global_position - player.global_position
	offset.y = 0
	if offset.length() > Weapon.reach or (-global_basis.z).dot(offset.normalized()) < Balance.MELEE_CONE_DOT:
		return false
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP,
		body.global_position + Vector3.UP, 1)
	ray.exclude = [player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	var amount: float = Weapon.charged_damage if charged_attack else Weapon.damage
	var force: float = Weapon.charged_knockback if charged_attack else Weapon.knockback
	if not body.receive_melee(amount, offset.normalized() * force, charged_attack):
		return false
	hit_ids[body.get_instance_id()] = true
	impact.emit(body, charged_attack)
	player.rig.add_shake(Balance.HEAVY_SHAKE if charged_attack else Balance.LIGHT_SHAKE)
	_hit_stop()
	return true

func charge_fraction() -> float:
	return clampf(charge_time / Weapon.charge_seconds, 0, 1) if charging else 0.0

func pose() -> float:
	if charging:
		return -0.7 * charge_fraction()
	if not attacking:
		return 0
	if attack_time < active_windup:
		return -0.8 * (attack_time / active_windup)
	if attack_time < active_windup + Weapon.active_seconds:
		return lerpf(-0.8, 1.4, (attack_time - active_windup) / Weapon.active_seconds)
	return lerpf(1.4, 0, clampf((attack_time - active_windup - Weapon.active_seconds) / active_recovery, 0, 1))

func cancel() -> void:
	charging = false
	attacking = false
	charge_time = 0
	hit_ids.clear()

func _hit_stop() -> void:
	if stopping:
		return
	stopping = true
	Engine.time_scale = Balance.HIT_STOP_SCALE
	await get_tree().create_timer(Balance.HIT_STOP_SECONDS, true, false, true).timeout
	Engine.time_scale = 1.0
	stopping = false

func _exit_tree() -> void:
	Engine.time_scale = 1.0
```

## tests/phase3_checks.gd

```gdscript
extends RefCounted
var failures: Array[String] = []
var world: Node3D
func check(condition: bool, message: String) -> void:
	print("PASS " if condition else "FAIL ",message)
	if not condition: failures.append(message)
func frames(count: int) -> void:
	for i in count: await world.get_tree().physics_frame
func run(scene: Node3D) -> bool:
	world = scene
	check(world.camp.avatars.size()==4,"Quattro posti nella lobby")
	check(world.camp.avatars[1].stance==1 and world.camp.avatars[2].knife!=null,"Pose seduta e coltello")
	world.choose_skin(2)
	check(Session.skin==2,"Scelta della skin")
	world.menu.settings()
	check(world.menu.page=="settings","Impostazioni accessibili")
	world.menu.home()
	Session.launch()
	await frames(10)
	check(world.nav_region.navigation_mesh.get_polygon_count()>0,"NavMesh generata dalle collisioni")
	check(world.targets.size()==6,"Sei zombie iniziali")
	check(world.actors.size()==1,"Giocatore singolo registrato")
	var zombie: CharacterBody3D = world.targets[0]
	for other in world.targets:
		if other!=zombie: other.set_physics_process(false)
	world.player.reset_at(Vector3(3,0.1,2))
	zombie.position = Vector3(3,0.1,-4)
	zombie.rotation.y = PI
	await frames(15)
	check(zombie.state==1,"Vista attiva l'inseguimento")
	var start := zombie.position
	await frames(60)
	check(zombie.position.distance_to(start)>0.6,"Navigazione muove lo zombie")
	var route := NavigationServer3D.map_get_path(world.get_world_3d().navigation_map,Vector3(9,0,-23),Vector3(9,0,-11),true)
	check(route.size()>2,"Percorso devia attorno al camion")
	zombie.position = world.player.position+Vector3(0,0,-1.1)
	zombie.state = 1
	zombie.target = world.player
	zombie.memory = 6
	var health: float = world.player.health
	await frames(75)
	check(world.player.health<health,"Attacco infligge danno dopo il preavviso")
	zombie.position = Vector3(0,0.1,-10)
	zombie.state = 0
	zombie.target = null
	zombie.hear(world.player,30)
	check(zombie.state==1,"Rumore attiva l'inseguimento")
	var wall: StaticBody3D = world.landscape.box(Vector3(3,3,0.2),(zombie.position+world.player.position)*0.5+Vector3.UP,Color.TRANSPARENT)
	await frames(2)
	check(not zombie.clear_line(world.player),"I muri bloccano la linea di vista")
	wall.queue_free()
	zombie.memory = 0
	world.player.position = Vector3(30,0.1,5)
	await frames(10)
	check(zombie.state==0,"Perdita interesse riporta al vagare")
	zombie.receive_melee(1000,Vector3.ZERO,true)
	check(zombie.dead and zombie.corpse_time==30,"Cadavere conservato per 30 secondi")
	zombie.corpse_time = 0.05
	await frames(10)
	check(not is_instance_valid(zombie),"Cadavere rimosso alla scadenza")
	for i in range(12):
		world.spawn_clock = -1
		world._process(0.1)
	var alive := 0
	for enemy in world.targets:
		if is_instance_valid(enemy) and not enemy.dead: alive += 1
	check(alive==8,"Spawner rispetta il limite di otto infetti vivi")
	check(world.targets.size()<=24,"Limite totale dei corpi rispettato")
	world.set_paused(true)
	check(world.get_tree().paused,"Pausa ferma la partita singola")
	world.set_paused(false)
	print("FASE3: ",failures.size()," errori")
	return failures.is_empty()
```
