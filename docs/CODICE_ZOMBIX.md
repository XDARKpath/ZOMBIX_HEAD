# Codice ZOMBIX HEAD 0.4

File già presenti nel progetto, con le dipendenze mantenute dalle fasi precedenti.

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

config/name="ZOMBIX HEAD"
config/version="0.4"
run/main_scene="res://world/zona1_rifugio/zombix.tscn"
config/features=PackedStringArray("4.5", "Forward Plus")
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

anti_aliasing/quality/msaa_3d=1
renderer/rendering_method="forward_plus"
renderer/rendering_method.mobile="forward_plus"
environment/defaults/default_clear_color=Color(0.055, 0.09, 0.11, 1)
```

## world/zona1_rifugio/zombix.tscn

```
[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://world/zona1_rifugio/zombix.gd" id="1"]
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

## world/zona1_rifugio/zombix.gd

```gdscript
# Scena principale ZOMBIX HEAD. Mantiene il nucleo cooperativo e aggiunge missione e presentazione.
extends "res://world/zona1_rifugio/fase3.gd"
var expedition: Node3D
var presentation: Node3D
var overlay: Control
var footstep_clock: float = 0
var footsteps: AudioStreamPlayer

func _ready() -> void:
	super._ready()
	presentation = Node3D.new()
	presentation.set_script(preload("res://world/zona1_rifugio/atmosphere.gd"))
	presentation.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(presentation)
	presentation.build(self)
	expedition = Node3D.new()
	expedition.name = "Expedition"
	expedition.process_mode = Node.PROCESS_MODE_PAUSABLE
	expedition.set_script(preload("res://world/zona1_rifugio/expedition.gd"))
	add_child(expedition)
	expedition.build(self)
	if started: expedition.start()
	overlay = Control.new()
	overlay.set_script(preload("res://ui/zombix_hud.gd"))
	$Interface.add_child(overlay)
	overlay.build(self)
	hud.hide()
	if DisplayServer.get_name() != "headless":
		footsteps = AudioStreamPlayer.new()
		footsteps.stream = load("res://audio/footstep.wav")
		footsteps.volume_db = -18
		add_child(footsteps)
	for arg in OS.get_cmdline_user_args():
		if arg=="--verify-zombix": call_deferred("_verify_zombix")
		elif arg=="--capture-action": call_deferred("_stage_action")
		elif arg=="--capture-options": menu.settings()
		elif arg=="--exp-host" or arg=="--exp-client": call_deferred("_verify_expedition_network",arg=="--exp-host")

func _begin_play() -> void:
	super._begin_play()
	if expedition: expedition.start()
	if overlay:
		overlay.previous_kills = 0
		overlay.chain = 0
		overlay.chain_time = 0
		overlay.enemy_health.clear()
	for id in actors:
		if actors[id]==player: continue
		var tag := Label3D.new()
		tag.text = str(Session.roster[id].name)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position.y = 1.8
		tag.pixel_size = 0.004
		tag.font_size = 32
		tag.modulate = Color("a1d9c3")
		actors[id].add_child(tag)
	announce("Recupera tre casse. Riattiva la radio. Difendi il segnale.",6)

func _process(delta: float) -> void:
	super._process(delta)
	if hud: hud.hide()
	if not started or get_tree().paused: return
	if footsteps and player.is_on_floor() and player.velocity.length()>1 and not player.dodging:
		footstep_clock -= delta
		if footstep_clock<=0:
			footstep_clock = 0.28 if player.sprinting else 0.43
			footsteps.pitch_scale = randf_range(0.86,1.15)
			footsteps.play()

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if started and not ui_open and event.is_action_pressed("interact") and expedition: expedition.request_use()

func _stage_action() -> void:
	if not started: Session.launch()
	await get_tree().create_timer(0.7).timeout
	player.reset_at(Vector3(3,0.5,-4))
	player.rig.yaw = -0.25
	player.rig.pitch = -0.2
	targets[0].position = Vector3(3,0,-6)

func _capture(path: String) -> void:
	await get_tree().create_timer(3.5,true).timeout
	if "--capture-action" in OS.get_cmdline_user_args() and not targets.is_empty():
		player.reset_at(Vector3(3,0.1,-4))
		player.rig.yaw = 0
		targets[0].position = Vector3(3,0.1,-5.65)
		player.melee.perform_attack(true)
		await get_tree().create_timer(0.29).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	sound.stop()
	sound.stream = null
	await get_tree().create_timer(0.2,true,false,true).timeout
	# Libera le risorse grafiche prima della chiusura del renderer nelle catture automatiche.
	get_tree().create_timer(0.15,true).timeout.connect(get_tree().quit)
	queue_free()

func _verify_zombix() -> void:
	var checks := preload("res://tests/zombix_checks.gd").new()
	var success: bool = await checks.run(self)
	Session.leave()
	get_tree().quit(0 if success else 1)

func _verify_expedition_network(hosting: bool) -> void:
	var check := preload("res://tests/coop_expedition.gd").new()
	add_child(check)
	await check.run(self,hosting)
```

## world/zona1_rifugio/expedition.gd

```gdscript
# Nodo Expedition sotto Rifugio. Missione condivisa: tre scorte, radio, difesa e nuova sortita.
extends Node3D
const POINTS := [Vector3(-3,0,-7),Vector3(12,0,-27),Vector3(-5,0,-44)]
const RADIO := Vector3(-2,0,3)
const HOLD_SECONDS := 45.0
const USE_DISTANCE := 3.0
var world: Node3D
var collected: Array = [false,false,false]
var stage: int = 0
var hold: float = HOLD_SECONDS
var operation: int = 1
var tick: float = 0
var pulse: float = 0
var wave: float = 0
var crates: Array[Node3D] = []
var radio_light: OmniLight3D
var broadcast_count: int = 0

func build(owner_world: Node3D) -> void:
	world = owner_world
	for i in range(3):
		var crate := Node3D.new()
		crate.position = POINTS[i]
		add_child(crate)
		piece(crate,Vector3(0,0.36,0),Vector3(0.9,0.6,0.65),Color("3e5551"))
		piece(crate,Vector3(0,0.69,0),Vector3(0.96,0.09,0.71),Color("b7a071"))
		for x in [-0.29,0.29]: piece(crate,Vector3(x,0.4,0.34),Vector3(0.07,0.6,0.04),Color("222e30"))
		var tag := Label3D.new()
		tag.text = "0%d" % (i+1)
		tag.font_size = 36
		tag.pixel_size = 0.005
		tag.position = Vector3(0,0.4,0.37)
		crate.add_child(tag)
		crates.append(crate)
	var radio := Node3D.new()
	radio.position = RADIO
	add_child(radio)
	piece(radio,Vector3(0,0.45,0),Vector3(1.4,0.8,0.65),Color("35443f"))
	piece(radio,Vector3(0,0.97,0),Vector3(0.65,0.24,0.45),Color("182b2d"))
	piece(radio,Vector3(0.45,1.8,0),Vector3(0.035,2.2,0.035),Color("92998c"))
	for i in range(4): piece(radio,Vector3(-0.18+i*0.12,1,0.24),Vector3(0.055,0.035,0.02),Color("72c9b4"))
	radio_light = OmniLight3D.new()
	radio_light.position = RADIO+Vector3(0,1.3,0)
	radio_light.light_color = Color("80ddc5")
	radio_light.omni_range = 4
	add_child(radio_light)
	visible = false

static func piece(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	view.material_override = material
	view.position = at
	parent.add_child(view)

func start() -> void:
	collected = [false,false,false]
	stage = 0
	hold = HOLD_SECONDS
	operation = 1
	visible = true
	_refresh()

func authority() -> bool:
	return not Session.online or multiplayer.is_server()

func request_use() -> void:
	if authority(): use(multiplayer.get_unique_id())
	else: interact.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func interact() -> void:
	if authority(): use(multiplayer.get_remote_sender_id())

func use(peer: int) -> bool:
	if not authority() or not world.started or not world.actors.has(peer): return false
	var player: CharacterBody3D = world.actors[peer]
	if player.dead: return false
	if stage == 0:
		for i in range(3):
			if not collected[i] and _can_reach(player,POINTS[i]):
				collected[i] = true
				player.health = minf(100,player.health+20)
				player.vitals_changed.emit(player.health,player.stamina)
				if collected.count(true)==3: stage = 1
				_publish()
				_refresh()
				return true
	elif _can_reach(player,RADIO):
		if stage == 1:
			stage = 2
			hold = HOLD_SECONDS
			wave = 0
			_alarm()
		elif stage == 3:
			operation += 1
			stage = 0
			collected = [false,false,false]
			for actor in world.actors.values():
				actor.health = minf(100,actor.health+35)
				actor.vitals_changed.emit(actor.health,actor.stamina)
		else: return false
		_publish()
		_refresh()
		return true
	return false

func _can_reach(player: CharacterBody3D, at: Vector3) -> bool:
	if player.position.distance_to(at)>USE_DISTANCE: return false
	var ray := PhysicsRayQueryParameters3D.create(player.position+Vector3.UP,at+Vector3.UP,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func target_point() -> Vector3:
	if stage != 0: return RADIO
	var result := RADIO
	var distance := INF
	for i in range(3):
		if not collected[i] and world.player.position.distance_squared_to(POINTS[i])<distance:
			distance = world.player.position.distance_squared_to(POINTS[i])
			result = POINTS[i]
	return result

func prompt() -> String:
	if world.player.dead: return ""
	if world.player.position.distance_to(target_point())>USE_DISTANCE: return ""
	return ["E  RECUPERA SCORTE  ·  +20 VITA","E  ATTIVA LA RADIO","RESTA VICINO ALLA RADIO","E  NUOVA SPEDIZIONE"][stage]

func title() -> String:
	return ["RECUPERA LE SCORTE","RIPRISTINA IL SEGNALE","DIFENDI LA RADIO","SEGNALE TRASMESSO"][stage]

func detail() -> String:
	match stage:
		0: return "%d / 3 casse  ·  esplora il rifugio" % collected.count(true)
		1: return "Ritorna alla radio dell'accampamento"
		2: return "%02d s  ·  resta entro 10 metri" % ceili(hold)
		_: return "Squadra rifornita. Preparati a ripartire."

func _process(delta: float) -> void:
	if not world or not world.started: visible = false; return
	visible = true
	pulse += delta
	radio_light.light_energy = (1.0+sin(pulse*3)*0.3) if stage>0 else 0.1
	if not authority(): return
	if stage == 2:
		var defender: CharacterBody3D = world.nearest_player(RADIO)
		if defender and defender.position.distance_to(RADIO)<10: hold = maxf(0,hold-delta)
		wave -= delta
		if wave <= 0:
			wave = 9
			_alarm()
		if hold <= 0:
			stage = 3
			for actor in world.actors.values():
				actor.health = minf(100,actor.health+35)
				actor.vitals_changed.emit(actor.health,actor.stamina)
			_publish()
	tick += delta
	if tick>=0.25:
		tick = 0
		_publish()

func _alarm() -> void:
	var alive := 0
	for enemy in world.targets:
		if is_instance_valid(enemy) and not enemy.dead:
			alive += 1
			var player: CharacterBody3D = world.nearest_player(enemy.position)
			if player: enemy.hear(player,200)
	if alive<8 and world.targets.size()<24:
		var at := Vector3(-5 if operation%2 else 14,0,-20)
		var enemy: Node3D = world._spawn_enemy(at)
		var player: CharacterBody3D = world.nearest_player(at)
		if player: enemy.hear(player,200)

func _refresh() -> void:
	for i in range(crates.size()): crates[i].visible = not collected[i]

func _publish() -> void:
	if Session.online and multiplayer.is_server():
		for peer in Session.connected_peers(): receive.rpc_id(peer,collected,stage,hold,operation)

@rpc("authority","call_remote","reliable")
func receive(items: Array, step: int, remaining: float, number: int) -> void:
	collected = items
	stage = step
	hold = remaining
	operation = number
	broadcast_count += 1
	_refresh()
```

## world/zona1_rifugio/atmosphere.gd

```gdscript
# Nodo figlio del mondo. Genera solo elementi visivi, senza collisioni aggiuntive.
extends Node3D
var world: Node3D
var ambience: AudioStreamPlayer
var clock: float = 0
var sun: DirectionalLight3D
var weather: Environment
var breeze: CPUParticles3D

func build(owner_world: Node3D) -> void:
	world = owner_world
	for child in world.landscape.get_children():
		if child is WorldEnvironment:
			weather = child.environment
			var sky := Sky.new()
			var sky_material := ShaderMaterial.new()
			sky_material.shader = preload("res://world/zona1_rifugio/sky.gdshader")
			sky.sky_material = sky_material
			if RenderingServer.get_current_rendering_method()!="gl_compatibility": weather.sky = sky
			weather.ambient_light_color = Color("aec8cc")
			weather.ambient_light_energy = 0.52
			weather.fog_light_color = Color("8b9b98")
			weather.fog_density = 0.0035
			weather.glow_enabled = RenderingServer.get_current_rendering_method()!="gl_compatibility"
			weather.ssao_radius = 1.1
			weather.ssao_intensity = 1.2
			weather.adjustment_enabled = true
			weather.adjustment_contrast = 1.08
			weather.adjustment_saturation = 0.94
		if child is DirectionalLight3D:
			sun = child
			sun.rotation_degrees = Vector3(-18,-32,0)
			sun.light_color = Color("ffce8f")
			sun.light_energy = 1.5
	grass(self, 11500, 27, 63, Vector3(0,0,-22), true)
	# Dettagli ai margini: vegetazione e pietre, senza bloccare i percorsi esistenti.
	var rng := RandomNumberGenerator.new()
	rng.seed = 142
	for i in range(34):
		var x := rng.randf_range(-24,26)
		var z := rng.randf_range(-52,9)
		if absf(x-6)<5 or (x< -8 and z< -4) or (x>14 and z< -14): continue
		var rock: Node3D = world.landscape.prop("SM_Env_Rock_01",Vector3(x,world.landscape.height(x,z)-0.12,z),rng.randf_range(0,360))
		rock.scale = Vector3.ONE*rng.randf_range(0.18,0.45)
	for point in [Vector3(-4,1.2,3),Vector3(6,1.6,14),Vector3(12,1.4,-24)]: lantern(self,point)
	breeze = CPUParticles3D.new()
	breeze.amount = 90
	breeze.lifetime = 8
	breeze.preprocess = 8
	breeze.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	breeze.emission_box_extents = Vector3(18,4,18)
	breeze.direction = Vector3(1,0.1,0.4)
	breeze.spread = 22
	breeze.gravity = Vector3.ZERO
	breeze.initial_velocity_min = 0.2
	breeze.initial_velocity_max = 0.6
	var dust := SphereMesh.new()
	dust.radius = 0.014
	dust.height = 0.028
	breeze.mesh = dust
	breeze.color = Color(0.9,0.77,0.45,0.45)
	add_child(breeze)
	if DisplayServer.get_name() != "headless":
		ambience = AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load("res://audio/forest.wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size()/2
		ambience.stream = stream
		ambience.volume_db = -20
		add_child(ambience)
		ambience.play()

static func grass(parent: Node3D, count: int, width: float, depth: float, center: Vector3, field: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0,PI/2]:
		for p in [Vector3(-0.025,0,0),Vector3(0.005,0.27,0),Vector3(0.025,0,0),Vector3(0.005,0.27,0),Vector3(0.07,0.48,0.02),Vector3(0.035,0.27,0)]:
			st.set_uv(Vector2(0,p.y/0.48))
			st.add_vertex(Basis(Vector3.UP,angle)*p)
	st.generate_normals()
	var mesh := st.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://world/zona1_rifugio/grass.gdshader")
	mesh.surface_set_material(0,material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 992 if field else 182
	var used := 0
	for i in range(count):
		var x := rng.randf_range(-width,width)+center.x
		var z := rng.randf_range(-depth*0.5,depth*0.5)+center.z
		if field:
			if absf(x-6)<4.5 or (x< -9 and z< -4) or (x>14 and z< -14) or z>11: continue
		else:
			if Vector2(x,z).length()<2.8: continue
		var scale_value := rng.randf_range(0.4,1.1)
		var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(scale_value,scale_value,scale_value))
		multi.set_instance_transform(used,Transform3D(basis,Vector3(x,0.015,z)))
		used += 1
	multi.visible_instance_count = used
	var view := MultiMeshInstance3D.new()
	view.multimesh = multi
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)

static func lantern(parent: Node3D, point: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12,0.22,0.12)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffcf83")
	mat.emission_enabled = true
	mat.emission = Color("ffaf58")
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	mesh.position = point
	parent.add_child(mesh)
	var light := OmniLight3D.new()
	light.position = point
	light.light_color = Color("ffc27a")
	light.light_energy = 1.2
	light.omni_range = 4.5
	parent.add_child(light)

func _process(delta: float) -> void:
	if not world or not world.started: return
	clock += delta
	breeze.position = world.player.position+Vector3.UP*2
	# Passaggi di nuvole: variazioni lente, senza cambiare la leggibilità del combattimento.
	if sun: sun.light_energy = 1.3+sin(clock*0.025)*0.2
	if weather: weather.fog_density = 0.0035+(sin(clock*0.017)*0.5+0.5)*0.0015
```

## world/zona1_rifugio/grass.gdshader

```
shader_type spatial;
render_mode cull_disabled;
varying float height;
varying float variation;
void vertex() {
 height=UV.y;
 vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 variation=fract(sin(dot(wp.xz,vec2(12.9898,78.233)))*43758.5453);
 VERTEX.x+=(sin(TIME*1.5+wp.x*0.8+wp.z*0.3)*0.12+sin(TIME*2.9+wp.z)*0.04)*height*height;
 VERTEX.z+=sin(TIME+wp.x*0.3)*height*height*0.08;
}
void fragment() {
 ALBEDO=mix(vec3(0.075,0.12,0.065),vec3(0.30,0.33,0.14),height)*(0.8+variation*0.25);
 ROUGHNESS=0.9;
 BACKLIGHT=vec3(0.16,0.21,0.07)*height;
}
```

## world/zona1_rifugio/sky.gdshader

```
shader_type sky;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y); }
void sky() {
 float h=max(EYEDIR.y,0.0);
 vec3 c=mix(vec3(0.76,0.43,0.23),vec3(0.10,0.22,0.30),pow(h,0.35));
 vec2 uv=EYEDIR.xz/(h+0.18)*1.6+vec2(TIME*0.002,0.0);
 float n=noise(uv)*0.55+noise(uv*2.1)*0.28+noise(uv*4.3)*0.17;
 float clouds=smoothstep(0.48,0.74,n)*smoothstep(0.0,0.15,h);
 c=mix(c,mix(vec3(0.31,0.33,0.35),vec3(0.80,0.61,0.43),pow(1.0-h,3.0)),clouds*0.8);
 float sun=dot(EYEDIR,normalize(vec3(-0.5,0.22,-0.75)));
 c+=vec3(1.0,0.64,0.28)*pow(max(sun,0.0),180.0)*1.7;
 COLOR=c;
}
```

## ui/zombix_hud.gd

```gdscript
# Nodo Control sotto Interface. HUD disegnato nel viewport di riferimento 1440×900.
extends Control
var world: Node3D
var heading: Label
var task: Label
var hint: Label
var counter: Label
var zone: Label
var health_number: Label
var stamina_number: Label
var impact: float = 0
var hurt: float = 0
var chain_time: float = 0
var chain: int = 0
var previous_kills: int = 0
var previous_health: float = 100
var marker: Label
var squad: Label
var grade: ShaderMaterial
var enemy_health: Dictionary = {}

func build(owner_world: Node3D) -> void:
	world = owner_world
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift","Segoe UI"])
	var theme_value := Theme.new()
	theme_value.default_font = font
	theme = theme_value
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade = ShaderMaterial.new()
	grade.shader = preload("res://ui/camp/grade.gdshader")
	vignette.material = grade
	add_child(vignette)
	zone = text("LAGO CENERE",Vector2(40,30),24,Color("ede8d9"))
	text("ZONA 01  /  ULTIMO SEGNALE",Vector2(42,63),11,Color("b7c3b4"))
	heading = text("",Vector2(62,127),19,Color("ede8d9"))
	task = text("",Vector2(62,158),14,Color("a9bab2"))
	text("SOPRAVVISSUTO",Vector2(62,759),11,Color("b9c3b3"))
	health_number = text("100",Vector2(325,781),20,Color("e4e7d5"))
	stamina_number = text("100",Vector2(325,817),16,Color("d9b179"))
	text("VITA",Vector2(62,782),10,Color("aab9ad"))
	text("FIATO",Vector2(62,820),10,Color("aab9ad"))
	text("ASCIA DA POMPIERE",Vector2(1140,774),19,Color("e2dfcd"))
	text("CLICK  colpo     TIENI  carica\nSPAZIO  schiva    E  interagisci",Vector2(1140,806),12,Color("a3b4ae"))
	hint = text("",Vector2(390,705),17,Color("f4dbad"))
	hint.size.x = 660
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter = text("",Vector2(585,90),18,Color("e7c58c"))
	counter.size.x = 270
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker = text("",Vector2.ZERO,13,Color("f4c57c"))
	marker.size.x = 190
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	squad = text("",Vector2(1180,218),13,Color("a9cfc0"))

func text(value: String, at: Vector2, size_value: int, color: Color) -> Label:
	var node := Label.new()
	node.text = value
	node.position = at
	node.add_theme_font_size_override("font_size",size_value)
	node.add_theme_color_override("font_color",color)
	node.add_theme_color_override("font_shadow_color",Color(0,0,0,0.5))
	node.add_theme_constant_override("shadow_offset_y",2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func _process(delta: float) -> void:
	visible = world.started and not world.ui_open
	if not visible: return
	heading.text = world.expedition.title()
	task.text = world.expedition.detail()
	health_number.text = "%03d" % ceili(world.player.health)
	stamina_number.text = "%03d" % ceili(world.player.stamina)
	if world.player.health<previous_health: hurt = 1
	previous_health = world.player.health
	hurt = move_toward(hurt,0,delta*1.3)
	impact = move_toward(impact,0,delta*3)
	grade.set_shader_parameter("hurt",maxf(hurt,0.25 if world.player.health<30 else 0))
	if world.kills>previous_kills:
		chain = chain+world.kills-previous_kills if chain_time>0 else world.kills-previous_kills
		chain_time = 6
		impact = 1
	previous_kills = world.kills
	chain_time = maxf(0,chain_time-delta)
	counter.text = ("SERIE ×%d" % chain) if chain_time>0 else ("%02d  ABBATTUTI" % world.kills)
	hint.text = world.expedition.prompt()
	if hint.text.is_empty() and world.notice_left>0: hint.text = world.notice.text
	if world.player.dead: hint.text = "SEI CADUTO  ·  RIENTRO AL RIFUGIO"
	var at: Vector3 = world.expedition.target_point()+Vector3.UP*1.5
	var camera: Camera3D = world.player.rig.camera
	var screen: Vector2 = camera.unproject_position(at)
	var behind: bool = camera.is_position_behind(at)
	if behind: screen.x = 1370 if wrapf(atan2(-(at-world.player.position).x,-(at-world.player.position).z)-world.player.rig.yaw,-PI,PI)<0 else 70
	marker.position = Vector2(clampf(screen.x-95,420,1110),clampf(screen.y,200,630))
	marker.text = ("↶  " if behind else "◇  ")+"%d m" % int(world.player.position.distance_to(world.expedition.target_point()))
	squad.text = "SQUADRA  %d / 4" % world.actors.size() if Session.online else "IN SOLITARIA"
	for enemy in world.targets:
		if not is_instance_valid(enemy): continue
		var id: int = enemy.network_id
		if enemy_health.has(id) and enemy.health<enemy_health[id] and enemy.position.distance_to(world.player.position)<7:
			impact = 1
			_damage_label(enemy.position+Vector3.UP*1.8,enemy_health[id]-enemy.health)
		enemy_health[id] = enemy.health
	queue_redraw()

func _damage_label(at: Vector3, amount: float) -> void:
	var label := Label3D.new()
	label.text = str(int(amount))
	label.font_size = 44
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("ffd591")
	label.no_depth_test = true
	world.add_child(label)
	label.position = at
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label,"position:y",at.y+0.8,0.7)
	tween.tween_property(label,"modulate:a",0.0,0.7)
	tween.chain().tween_callback(label.queue_free)

func _draw() -> void:
	if not world or not world.started: return
	var dark := Color(0.025,0.055,0.055,0.82)
	var accent := Color("d4a56c")
	draw_style_box(panel(dark),Rect2(40,113,345,79))
	draw_rect(Rect2(40,113,3,79),accent)
	draw_style_box(panel(dark),Rect2(40,744,345,114))
	for row in [[world.player.health,803.0,Color("bad4b0")],[world.player.stamina,837.0,accent]]:
		draw_rect(Rect2(62,row[1],248,5),Color(1,1,1,0.12))
		draw_rect(Rect2(62,row[1],248*clampf(row[0]/100.0,0,1),5),row[2])
	var c := Vector2(720,450)
	draw_circle(c,2,Color(1,1,1,0.65))
	if world.player.melee.charging:
		draw_arc(c,23,-PI/2,-PI/2+TAU*maxf(0.01,world.player.melee.charge_fraction()),40,accent,3,true)
	if impact>0:
		for side in [Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)]: draw_line(c+side*7,c+side*14,Color(1,0.8,0.5,impact),2,true)
	# Radar orientato alla camera: mostra soltanto le presenze entro 30 metri.
	var center := Vector2(1295,126)
	draw_circle(center,72,Color(0.03,0.06,0.065,0.8))
	draw_arc(center,72,0,TAU,64,Color(0.6,0.7,0.6,0.4),1,true)
	draw_arc(center,36,0,TAU,64,Color(0.6,0.7,0.6,0.15),1,true)
	draw_line(center-Vector2(72,0),center+Vector2(72,0),Color(1,1,1,0.08))
	draw_line(center-Vector2(0,72),center+Vector2(0,72),Color(1,1,1,0.08))
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-6),center+Vector2(-4,4),center+Vector2(4,4)]),Color("f3e7c8"))
	for enemy in world.targets:
		if is_instance_valid(enemy) and not enemy.dead: _dot(center,enemy.position,Color("d87254"),2.5)
	for actor in world.actors.values():
		if actor!=world.player: _dot(center,actor.position,Color("8fd6c5"),3)
	_dot(center,world.expedition.target_point(),accent,4)
	if world.expedition.stage==2:
		draw_rect(Rect2(62,184,300*(1-world.expedition.hold/45.0),3),accent)

func _dot(center: Vector2, point: Vector3, color: Color, radius: float) -> void:
	var relative: Vector3 = Basis(Vector3.UP,-world.player.rig.yaw)*(point-world.player.position)
	var p := Vector2(relative.x,relative.z)*2.1
	if p.length()<66: draw_circle(center+p,radius,color)

func panel(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = 8
	box.corner_radius_bottom_right = 8
	return box
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
	shade.color = Color(0.016,0.03,0.035,0.89)
	shade.position = Vector2(26,26)
	shade.size = Vector2(398,794)
	add_child(shade)
	if title == "ZOMBIX HEAD":
		label("ZOMBIX",Vector2(50,47),68,Color("eee9d7"))
		label("H E A D",Vector2(56,119),38,Color("d4a56c"))
		var emblem := TextureRect.new()
		emblem.texture = preload("res://art/icon.svg")
		emblem.position = Vector2(325,62)
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.size = Vector2(128,128)
		emblem.scale = Vector2(0.5,0.5)
		add_child(emblem)
	else: label(title,Vector2(52,60),44 if title.length()>10 else 55)
	label(subtitle,Vector2(56,170),11,Color("d8b687"))
	var rule := ColorRect.new()
	rule.position = Vector2(56,156)
	rule.size = Vector2(242,2)
	rule.color = Color("b28754")
	add_child(rule)
	status_label = label(Session.status,Vector2(52,842),15,Color("b6c8c7"))
	status_label.size.x = 1320
	status_label.clip_text = true
	label("ZOMBIX HEAD  /  0.4",Vector2(1130,31),12,Color("99b2b4"))

func label(text: String, at: Vector2, size: int, color: Color = Color("f0eee1")) -> Label:
	return world._label(self,text,at,size,color)

func button(text: String, y: float, callback: Callable) -> Button:
	var node: Button = world._button(self,text,Vector2(54,y),callback)
	node.size = Vector2(340,52)
	return node

func home() -> void:
	page = "home"
	clear("ZOMBIX HEAD" if not world.started else "PAUSA","ATTORNO AL FUOCO" if not world.started else "LA SQUADRA TI ASPETTA")
	if world.started:
		label("La partita online continua\nmentre sei nel menu." if Session.online else "Un momento per riprendere fiato.",Vector2(56,200),17)
		button("RIPRENDI",300,func() -> void: world.set_paused(false))
		button("IMPOSTAZIONI",366,settings)
		button("COMANDI",432,controls)
		button("TORNA ALL'ACCAMPAMENTO",498,world.leave_game)
	else:
		label("Tre casse. Una radio.\nUna ragione per tornare.",Vector2(56,193),18,Color("b8c8c5"))
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
			roster_label.text = "IL TUO ACCAMPAMENTO\nTre pose d'anteprima · forma la tua squadra"
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
	clear("PERSONAGGIO","SCEGLI CHI PORTARE NEL BUIO")
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
	label("WASD  ·  Muoviti\nMOUSE  ·  Guarda\nSHIFT  ·  Corri\nSPAZIO / CTRL  ·  Schiva\nCLICK  ·  Colpo rapido\nTIENI + RILASCIA  ·  Caricato\nE  ·  Recupera / attiva\nESC  ·  Menu",Vector2(56,230),20)
	label("Gli infetti vedono e sentono.\nRaccogli scorte. Difendi la radio.\nIn cooperativa il mondo continua\nanche mentre apri il menu.\n\nLa pesca sarà solo alimentare.",Vector2(56,505),16,Color("b5c4c1"))
	button("INDIETRO",700,home)
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
		_wind_material(tree)
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
	camera.position = Vector3(3.6,2.4,6.7)
	camera.look_at(global_position+Vector3(-1.2,1.05,-0.6))
	camera.fov = 46
	var lens := CameraAttributesPractical.new()
	lens.dof_blur_far_enabled = RenderingServer.get_current_rendering_method()!="gl_compatibility"
	lens.dof_blur_far_distance = 9
	lens.dof_blur_far_transition = 6
	lens.dof_blur_amount = 0.12
	camera.attributes = lens
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111f2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("708396")
	env.ambient_light_energy = 0.23
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = RenderingServer.get_current_rendering_method()!="gl_compatibility"
	env.ssao_enabled = RenderingServer.get_current_rendering_method()=="forward_plus"
	env.fog_enabled = true
	env.fog_density = 0.032
	env.fog_light_color = Color("172e38")
	camera.environment = env
	preload("res://world/zona1_rifugio/atmosphere.gd").grass(self,3000,12,17,Vector3(0,0,-2),false)
	for item in [["SM_Prop_Tent_Dome_01",Vector3(-3.9,0,-3.6),0.4],["SM_Veh_Truck_Destroyed_01",Vector3(4,0,-6),-0.6],["SM_Prop_Barrel_Water_01",Vector3(3.8,0,-1.4),0.0]]:
		var prop: Node3D = load("res://art/surroundead/"+item[0]+".glb").instantiate()
		prop.position = item[1]
		prop.rotation.y = item[2]
		add_child(prop)
	preload("res://world/zona1_rifugio/atmosphere.gd").lantern(self,Vector3(-3.2,0.6,-2.4))
	var rim := OmniLight3D.new()
	rim.position = Vector3(0,3,-4)
	rim.light_color = Color("8bafc5")
	rim.light_energy = 2.1
	rim.omni_range = 7
	add_child(rim)

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
	if fire: fire.light_energy = 3.9+sin(timer*13)*0.3+sin(timer*21)*0.17
	if camera and visible:
		camera.position = Vector3(3.6+sin(timer*0.09)*0.16,2.4+sin(timer*0.13)*0.045,6.7)
		camera.look_at(global_position+Vector3(-1.2,1.05,-0.6))

func _tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		node.material_override = mat
	for child in node.get_children(): _tint(child,color)

func _wind_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://world/zona1_rifugio/tree.gdshader")
		node.material_override = mat
	for child in node.get_children(): _wind_material(child)
```

## ui/camp/grade.gdshader

```
shader_type canvas_item;
uniform float hurt : hint_range(0.0,1.0)=0.0;
uniform float cinematic : hint_range(0.0,1.0)=0.0;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float edge=smoothstep(0.35,1.35,length(p*vec2(0.85,1.0)));
 float grain=fract(sin(dot(UV+TIME*0.001,vec2(127.1,311.7)))*43758.5453);
 COLOR=vec4(mix(vec3(0.015,0.025,0.03),vec3(0.45,0.015,0.01),hurt),edge*(0.23+cinematic*0.14+hurt*0.42)+grain*0.018);
}
```

## art/survivor_visual.gd

```gdscript
extends Node3D
# Original runtime posing over the recovered skeletal meshes.
var skeleton: Skeleton3D
var actor: Node3D
var zombie: bool = false
var clock: float = 0.0
var bone_ids: Dictionary = {}
var axe: Node3D

func configure(model_name: String, owner_actor: Node3D, is_zombie: bool = false) -> void:
	actor = owner_actor
	zombie = is_zombie
	var model: Node3D = load("res://art/surroundead/" + model_name + ".glb").instantiate()
	add_child(model)
	skeleton = _find_skeleton(model)
	if skeleton:
		for i in skeleton.get_bone_count():
			bone_ids[skeleton.get_bone_name(i).to_lower()] = i
	if not zombie:
		axe = load("res://art/surroundead/SM_Wep_FireAxe_01.glb").instantiate()
		add_child(axe)
		axe.scale = Vector3.ONE * 0.8
	_pose(0)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found: return found
	return null

func rotate_bone(bone_name: String, axis: Vector3, angle: float) -> void:
	transform_bone(bone_name, Basis(axis, angle))

func transform_bone(bone_name: String, rotation_basis: Basis) -> void:
	if not bone_ids.has(bone_name): return
	var i: int = bone_ids[bone_name]
	var rest := skeleton.get_bone_rest(i)
	var parent := skeleton.get_bone_parent(i)
	var basis: Basis = skeleton.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(i, (basis.inverse() * rotation_basis * basis * rest.basis).get_rotation_quaternion())

func _process(delta: float) -> void:
	clock += delta
	_pose(delta)

func _pose(_delta: float) -> void:
	if not skeleton or not is_instance_valid(actor): return
	var speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
	var gait: float = sin(clock * (10.0 if speed > 4.5 else 7.5)) * minf(speed / 4.0, 1.0)
	if zombie:
		var reach := -0.7
		if actor.has_method("see") and actor.state==2: reach = -1.0-sin(clock*9)*0.45
		transform_bone("upperarm_l",Basis(Vector3.RIGHT,reach+gait*0.15)*Basis(Vector3.BACK,-1.2))
		transform_bone("upperarm_r",Basis(Vector3.RIGHT,reach-gait*0.15)*Basis(Vector3.BACK,1.2))
		rotate_bone("lowerarm_l", Vector3.RIGHT, -0.35)
		rotate_bone("lowerarm_r", Vector3.RIGHT, -0.4)
		rotate_bone("spine_01", Vector3.RIGHT, 0.14 + sin(clock) * 0.025)
	else:
		var swing: float = actor.melee.pose()
		transform_bone("upperarm_l", Basis(Vector3.RIGHT,-gait*0.32)*Basis(Vector3.BACK,-1.35))
		transform_bone("upperarm_r", Basis(Vector3.RIGHT,gait*0.22)*Basis(Vector3.BACK,1.22))
		# Rotate the arm around the shoulder in world space, preserving the rest rig.
		if actor.melee.attacking or actor.melee.charging:
			transform_bone("upperarm_r", Basis(Vector3.RIGHT, -1.3 + swing * 1.2) * Basis(Vector3.BACK, 1.22))
		rotate_bone("lowerarm_r", Vector3.RIGHT, -0.35)
		transform_bone("spine_01", Basis(Vector3.UP,swing*0.3)*Basis(Vector3.RIGHT,minf(speed/7.0,1.0)*0.1))
	rotate_bone("thigh_l", Vector3.RIGHT, gait * 0.48)
	rotate_bone("thigh_r", Vector3.RIGHT, -gait * 0.48)
	rotate_bone("calf_l", Vector3.RIGHT, maxf(0, -gait) * 0.5)
	rotate_bone("calf_r", Vector3.RIGHT, maxf(0, gait) * 0.5)
	if axe and bone_ids.has("hand_r"):
		var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_ids["hand_r"])
		axe.global_position = hand.origin
		axe.global_rotation = global_rotation + Vector3(-0.55 + actor.melee.pose() * 1.8, 0, -0.15)
```

## player/camera_rig/camera_rig.gd

```gdscript
# Nodo: Player/CameraRig (Node3D top_level) nella scena player.tscn.
# Figli: SpringArm3D/Camera3D. Il padre è il CharacterBody3D da seguire.
extends Node3D

const Balance = preload("res://autoload/balance.gd")
@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var subject: CharacterBody3D = get_parent() as CharacterBody3D
var trauma: float = 0.0
var sensitivity: float = 1.0
var yaw: float = 0.0
var pitch: float = Balance.CAMERA_PITCH_DEFAULT
var controls_enabled: bool = true

func _ready() -> void:
	top_level = true
	arm.spring_length = Balance.CAMERA_LENGTH
	arm.add_excluded_object(subject.get_rid())
	reset_follow()

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * Balance.CAMERA_SENSITIVITY * sensitivity
		pitch = clampf(pitch - event.relative.y * Balance.CAMERA_SENSITIVITY * sensitivity,
			Balance.CAMERA_PITCH_MIN, Balance.CAMERA_PITCH_MAX)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arm.spring_length = maxf(Balance.CAMERA_MIN_LENGTH, arm.spring_length - Balance.CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arm.spring_length = minf(Balance.CAMERA_MAX_LENGTH, arm.spring_length + Balance.CAMERA_ZOOM_STEP)

func _physics_process(delta: float) -> void:
	if controls_enabled:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		yaw -= stick.x * Balance.CAMERA_PAD_SPEED * delta
		pitch = clampf(pitch - stick.y * Balance.CAMERA_PAD_SPEED * delta,
			Balance.CAMERA_PITCH_MIN, Balance.CAMERA_PITCH_MAX)
	global_position = global_position.lerp(subject.global_position + Vector3.UP * Balance.CAMERA_HEIGHT,
		1.0 - exp(-Balance.CAMERA_FOLLOW_SPEED * delta))
	rotation = Vector3(0, yaw, 0)
	arm.rotation.x = pitch
	trauma = move_toward(trauma, 0, delta * 2.5)
	camera.h_offset = randf_range(-1, 1) * trauma * 0.05
	camera.v_offset = randf_range(-1, 1) * trauma * 0.04
	var target_fov := 76.0 if subject.sprinting else (65.0 if subject.melee.charging else 68.0)
	camera.fov = lerpf(camera.fov,target_fov,1.0-exp(-delta*5))
	camera.rotation.z = lerpf(camera.rotation.z,clampf(-subject.velocity.dot(global_basis.x)*0.002,-0.018,0.018),delta*4)

func add_shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func reset_follow() -> void:
	global_position = subject.global_position + Vector3.UP * Balance.CAMERA_HEIGHT
	rotation = Vector3(0, yaw, 0)
	arm.rotation.x = pitch

func movement_direction(input: Vector2) -> Vector3:
	# Si usa solo lo yaw: inclinare la camera non altera la velocità del personaggio.
	return Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
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
var impact_timer: Timer

func _ready() -> void:
	impact_timer = Timer.new()
	impact_timer.one_shot = true
	impact_timer.ignore_time_scale = true
	impact_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(impact_timer)
	impact_timer.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		stopping = false)

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
	if stopping or Session.online:
		return
	stopping = true
	Engine.time_scale = Balance.HIT_STOP_SCALE
	impact_timer.start(Balance.HIT_STOP_SECONDS)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
```

## tests/zombix_checks.gd

```gdscript
# Verifica funzionale della spedizione e dei vincoli del server.
extends RefCounted
var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	print("PASS " if condition else "FAIL ",message)
	if not condition: failures.append(message)
func run(world: Node3D) -> bool:
	check(ProjectSettings.get_setting("application/config/name")=="ZOMBIX HEAD","Nuovo nome del gioco")
	check(world.camp.avatars.size()==4,"Accampamento compatibile con quattro giocatori")
	Session.launch()
	for i in range(10): await world.get_tree().physics_frame
	for enemy in world.targets: enemy.set_physics_process(false)
	var mission: Node3D = world.expedition
	var accessible := true
	for point in mission.POINTS:
		var closest := NavigationServer3D.map_get_closest_point(world.get_world_3d().navigation_map,point)
		var path := NavigationServer3D.map_get_path(world.get_world_3d().navigation_map,mission.RADIO,closest,true)
		accessible = accessible and point.distance_to(closest)<1.5 and path.size()>1
	check(accessible,"Percorsi navigabili dal rifugio alle tre scorte")
	check(mission.stage==0 and mission.collected.count(true)==0,"Spedizione iniziale con tre casse")
	check(not mission.use(999),"Interazione rifiutata per un giocatore inesistente")
	world.player.position = Vector3(30,0,5)
	check(not mission.use(1),"Non si possono raccogliere scorte a distanza")
	world.player.health = 40
	for i in range(3):
		world.player.position = mission.POINTS[i]+Vector3(0,0.1,1.5)
		for frame in range(2): await world.get_tree().physics_frame
		check(mission.use(1),"Raccolta reale della cassa %d" % (i+1))
	check(world.player.health==100,"Le scorte curano il giocatore che le raccoglie")
	check(mission.stage==1,"Tre casse sbloccano la radio")
	check(not mission.use(1),"Radio non attivabile da lontano")
	world.player.position = mission.RADIO+Vector3(0,0.1,1.6)
	for i in range(2): await world.get_tree().physics_frame
	check(mission.use(1) and mission.stage==2,"Attivazione radio vicino al terminale")
	var before: float = mission.hold
	mission._process(1)
	check(mission.hold<before,"La difesa avanza con un sopravvissuto presente")
	world.player.position = Vector3(30,0.1,5)
	before = mission.hold
	mission._process(1)
	check(mission.hold==before,"La difesa si ferma se la squadra si allontana")
	world.player.position = mission.RADIO+Vector3(0,0.1,1.6)
	world.player.health = 50
	mission.hold = 0.1
	mission._process(0.2)
	check(mission.stage==3 and world.player.health==85,"Trasmissione completata e squadra curata")
	check(mission.use(1) and mission.operation==2 and mission.stage==0,"Una nuova spedizione ripristina gli obiettivi")
	check(mission.collected.count(true)==0,"Le tre casse sono nuovamente disponibili")
	world.player.dead = true
	world.player.position = mission.POINTS[0]
	check(not mission.use(1),"Un giocatore morto non può interagire")
	world.player.dead = false
	check(world.targets.size()<=8,"L'assalto rispetta il limite dei nemici")
	check(is_instance_valid(world.overlay) and is_instance_valid(world.presentation),"Nuovo HUD e ambiente attivi")
	print("ZOMBIX: ",failures.size()," errori")
	return failures.is_empty()
```

## tests/coop_expedition.gd

```gdscript
# Prova con processi distinti: l'host posiziona la squadra, i client interagiscono via RPC.
extends Node
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds,true).timeout
func run(world: Node3D, hosting: bool) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	if hosting:
		Session.host(27846)
		await wait(5)
		Session.launch()
		await wait(0.5)
		for enemy in world.targets: enemy.set_physics_process(false)
		for actor in world.actors.values(): actor.set_physics_process(false)
		for point in world.expedition.POINTS:
			for actor in world.actors.values(): actor.position = point+Vector3(0,0.1,1.5)
			await wait(1.5)
		for actor in world.actors.values(): actor.position = world.expedition.RADIO+Vector3(0,0.1,1.5)
		await wait(1.5)
		var activated: bool = world.expedition.stage==2
		world.expedition.hold = 0.1
		await wait(0.5)
		var success: bool = activated and world.expedition.stage==3 and world.expedition.collected.count(true)==3 and world.actors.size()==4
		print("EXP_HOST completed=",success," stage=",world.expedition.stage," members=",world.actors.size())
		await wait(2)
		Session.leave()
		get_tree().quit(0 if success else 1)
	else:
		Session.profile("Scout%d"%OS.get_process_id(),OS.get_process_id()%3)
		Session.join("127.0.0.1",27846)
		await wait(1.5)
		Session.set_ready(true)
		await Session.game_started
		world.player.set_physics_process(false)
		var elapsed := 0.0
		while elapsed<13 and world.expedition.stage!=3:
			await wait(0.15)
			elapsed += 0.15
			if world.expedition.stage<2 and not world.expedition.prompt().is_empty(): world.expedition.request_use()
		var success: bool = world.expedition.stage==3 and world.expedition.collected.count(true)==3 and world.actors.size()==4 and world.expedition.broadcast_count>10
		print("EXP_CLIENT completed=",success," updates=",world.expedition.broadcast_count," members=",world.actors.size())
		await wait(0.6)
		Session.leave()
		get_tree().quit(0 if success else 1)
```
