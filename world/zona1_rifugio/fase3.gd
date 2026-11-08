extends "res://world/zona1_rifugio/fase2.gd"
const SKINS := preload("res://ui/camp/camp.gd").MODELS
var camp: Node3D
var menu: Control
var terrain: Node3D
var nav_region: NavigationRegion3D
var actors: Dictionary = {}
var next_enemy_id: int = 1
var spawn_clock: float = 0
var net_clock: float = 0
var player_avatar: Node3D
var snapshots_received: int = 0
var ui_open: bool = true
## Suggerimenti in coda (tutorial): uno alla volta, ciascuno quando il precedente è sparito. [testo, secondi]
var tips: Array = []
var tip_text := ""
var profile_config := ConfigFile.new()
var settings_data := {
	"sensitivity":1.0,"volume":70.0,"blood":true,"shadows":true,
	"fullscreen":false,"resolution":"1440x900",
	"display_mode":0,"vsync":1,
	"quality":2,"textures":2,"shadow_quality":3,"anti_aliasing":1
}
# Risoluzioni standard PC, filtrate sulla risoluzione nativa dello schermo.
const RESOLUTION_LADDER := [
	Vector2i(1024,768),Vector2i(1152,864),Vector2i(1280,720),Vector2i(1280,800),
	Vector2i(1280,960),Vector2i(1280,1024),Vector2i(1366,768),Vector2i(1440,900),
	Vector2i(1600,900),Vector2i(1600,1200),Vector2i(1680,1050),Vector2i(1920,1080),
	Vector2i(1920,1200),Vector2i(2048,1152),Vector2i(2560,1080),Vector2i(2560,1440),
	Vector2i(2560,1600),Vector2i(2880,1620),Vector2i(3200,1800),Vector2i(3440,1440),
	Vector2i(3840,2160),Vector2i(5120,1440),Vector2i(5120,2880),Vector2i(7680,4320)
]
# Texture, ombre e anti-aliasing impostati da ogni preset complessivo.
const QUALITY_PRESETS := [
	{"textures":0,"shadow_quality":0,"anti_aliasing":0},
	{"textures":1,"shadow_quality":2,"anti_aliasing":1},
	{"textures":2,"shadow_quality":3,"anti_aliasing":1},
	{"textures":3,"shadow_quality":4,"anti_aliasing":3}
]
var _resolution_cache: Array[Vector2i] = []

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
	terrain=Node3D.new()
	terrain.name="CampaignTerrain"
	terrain.set_script(preload("res://world/campaign/terrain.gd"))
	nav_region.add_child(terrain)
	terrain.build(self)
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.agent_radius = 0.5
	mesh.agent_height = 2.0
	mesh.agent_max_climb = 0.5
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.filter_baking_aabb = preload("res://world/zona1_rifugio/refuge_layout.gd").NAV_BOUNDS
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
	camp.name = "CampfireStage"
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
	player.jumped.connect(func() -> void: _send_action("jump"))
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
	avatar.configure(SKINS[clampi(skin_id,0,SKINS.size()-1)],body)
	if body.local_control: body.call_deferred("_shadow_body")
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
		for i in range(4):
			camp.set_skin(i,Session.skin if i == 0 else [0,1,3,4][i])
			camp.avatars[i].show()
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

## Mette un suggerimento in coda: non copre l'avviso in corso e non arriva insieme agli altri.
func tip(message: String, seconds: float = 5.0) -> void:
	for row in tips:
		if row[0] == message: return
	tips.append([message, seconds])

## Un avviso nuovo sostituisce subito quello in corso; se copriva un suggerimento, il suggerimento torna in coda.
func announce(message: String, seconds: float = 3.0) -> void:
	if notice_left > 0 and tip_text != "" and notice.text == tip_text and message != tip_text:
		tips.push_front([tip_text, maxf(notice_left, 3.0)])
	tip_text = ""
	super.announce(message, seconds)

func _spawn_targets() -> void:
	for body in targets:
		if is_instance_valid(body): body.queue_free()
	targets.clear()
	for point in preload("res://world/zona1_rifugio/refuge_layout.gd").ENEMIES:
		_spawn_enemy(point)
	spawn_clock = 15

func _spawn_enemy(at: Vector3, enemy_id: int = -1) -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.set_script(preload("res://enemies/zombie_ai.gd"))
	enemy.network_id = next_enemy_id if enemy_id < 0 else enemy_id
	next_enemy_id = maxi(next_enemy_id,enemy.network_id+1)
	enemy.name = "Enemy%d" % enemy.network_id
	# Il prato della Zona 1 ondeggia: lo zombie compare sopra il terreno, mai sotto.
	enemy.position = Vector3(at.x, maxf(at.y, preload("res://world/campaign/terrain.gd").ground_height(at.x, at.z)), at.z)+Vector3.UP*0.1
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
	if player.position.y < -1 and not returning and not below_ground_ok(): _respawn(player)
	var alive := 0
	for body in targets:
		if not body.dead: alive += 1
	objective.text = "LAGO CENERE\nInfetti vicini: %d  ·  Abbattuti: %d" % [alive,kills]
	charge_bar.value = player.melee.charge_fraction()*100
	charge_bar.visible = player.melee.charging
	# Con un dialogo o un pannello aperto gli avvisi aspettano: compaiono quando si chiude.
	if not ui_open: notice_left = maxf(0,notice_left-delta)
	if notice_left <= 0 and not ui_open and not tips.is_empty():
		var row: Array = tips.pop_front()
		announce(row[0],row[1])
		tip_text = notice.text
	notice.visible = notice_left > 0 and not ui_open
	if not Session.online or multiplayer.is_server():
		if not has_method("activate_zone"): spawn_clock -= delta
		if not has_method("activate_zone") and spawn_clock <= 0 and alive < 8 and targets.size()<24:
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
				input_packet.rpc_id(1,movement,player.rig.yaw,Input.is_action_pressed("sprint") and not ui_open,Input.is_action_pressed("crouch") if not ui_open else player.crouching,player.rig.pitch,player.melee.blocking)

func _noise(body: CharacterBody3D) -> void:
	# Con il sistema del rumore ogni arma ha il suo raggio (pistola 45 m, coltello 5 m).
	if get("zone_life"):
		get("zone_life").attack_noise(body)
		return
	for enemy in targets:
		if is_instance_valid(enemy): enemy.hear(body)

func _local_attack(_heavy: bool) -> void:
	_send_action("release")
	if not Session.online or multiplayer.is_server(): _noise(player)

func _send_action(action: String) -> void:
	if Session.online and not multiplayer.is_server() and started: action_packet.rpc_id(1,action,player.rig.yaw,player.rig.pitch)

@rpc("any_peer","call_remote","unreliable_ordered")
func input_packet(movement: Vector2, yaw: float, sprint: bool, crouch: bool=false, pitch:float=0, guard:bool=false) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not started or not actors.has(id) or not movement.is_finite() or not is_finite(yaw) or not is_finite(pitch): return
	var body: CharacterBody3D = actors[id]
	body.network_move = movement.limit_length(1)
	body.network_sprint = sprint
	body.network_crouch = crouch
	body.melee.remote_block = guard
	body.rig.yaw = wrapf(yaw,-PI,PI)
	body.rig.pitch = clampf(pitch,-1.4,1.4)
	body.input_age = 0

@rpc("any_peer","call_remote","reliable")
func action_packet(action: String,yaw:float=0,pitch:float=0) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not started or not actors.has(id): return
	var body: CharacterBody3D = actors[id]
	if body.seated or not is_finite(yaw) or not is_finite(pitch): return
	body.rig.yaw=wrapf(yaw,-PI,PI);body.rig.pitch=clampf(pitch,-1.4,1.4)
	match action:
		"charge": body.melee.begin_charge()
		"release": body.melee.release_attack()
		"dodge": body.try_dodge(body.rig.movement_direction(body.network_move))
		"jump": body.try_jump()

func _send_snapshot() -> void:
	var people: Array = []
	for id in actors:
		var body: CharacterBody3D = actors[id]
		people.append([id,body.position,body.visual.rotation.y,body.velocity,body.health,body.stamina,body.dead,body.melee.attacking,body.melee.attack_time,body.melee.charged_attack,body.dodging,body.dodge_elapsed,body.crouching,body.equipped,body.magazine,body.reload_left,body.credits,body.carried_heads,body.owned,body.items,body.hotbar,body.slot,body.status.packed(),body.melee.blocking,body.rig.pitch,body.melee.attack_clip])
	var enemies: Array = []
	for body in targets:
		if is_instance_valid(body): enemies.append([body.network_id,body.position,body.rotation.y,body.velocity,body.health,body.dead,int(body.state),body.visual.rotation.x,body.visual.position.y,body.stagger,body.attack_clock,body.kind,body.max_health,body.crawling,body.beheaded,body.death_style,body.death_clock,body.attack_clip,body.attack_serial,body.alert_time,body.reaction,body.reaction_time,body.hit_serial,body.hit_zone,body.hit_dir,body.hit_power,body.custom_skin,body.boss_weapon,body.anim_scale,body.title])
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
		if not local:body.set_crouched(row[12],true)
		if local and not body.seated:
			if body.position.distance_to(row[1])>2.0 or body.dead != row[6]: body.position = row[1]
			else: body.position = body.position.lerp(row[1],0.12)
		elif not body.seated:
			body.position = body.position.lerp(row[1],0.6)
			body.visual.rotation.y = row[2]
			body.velocity = row[3]
			body.melee.attacking = row[7]
			body.melee.attack_time = row[8]
			body.melee.charged_attack = row[9]
			var timing: Array = preload("res://weapons/zx_arsenal.gd").timing(row[13], row[9], 0)
			body.melee.active_windup = timing[0]
			body.melee.active_seconds = timing[1]
			body.melee.active_recovery = timing[2]
			body.dodging = row[10]
			body.dodge_elapsed = row[11]
			body._animate(0.05)
		body.equipped=row[13];body.magazine=row[14];body.reload_left=row[15];body.credits=row[16];body.owned.assign(row[18])
		if row.size()>21:
			body.items=row[19].duplicate();body.hotbar.assign(row[20]);body.slot=row[21]
		if row.size()>23:
			body.status.unpack(row[22])
			if not local:
				body.melee.remote_block=row[23]
				body.rig.pitch=row[24]
				if row.size()>25: body.melee.attack_clip=row[25]
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
		body.stagger = row[9]
		body.attack_clock = row[10]
		# Il boss con un aspetto suo va rivestito prima di tutto il resto.
		if row.size()>27 and body.custom_skin!=row[26]:
			body.custom_skin=row[26];body.boss_weapon=row[27];body._dress()
		if row.size()>28:body.anim_scale=row[28]
		# Il nome del boss serve alla barra della vita anche sui client.
		if row.size()>29:body.title=row[29]
		if body.kind!=row[11]:body.set_kind(row[11])
		# Stesso colpo incassato dell'host.
		if row.size()>25 and body.hit_serial!=row[22]:
			body.hit_serial=row[22];body.hit_zone=row[23];body.hit_dir=row[24];body.hit_power=row[25];body.hit_age=0.0
		body.max_health=row[12];body.crawling=row[13];body.beheaded=row[14];body.death_style=row[15];body.death_clock=row[16]
		# Stesso attacco e stesso urlo dell'host (infected_motion sceglie la clip da questi campi).
		if row.size()>19: body.attack_clip=row[17];body.attack_serial=row[18];body.alert_time=row[19]
		# Reazione direzionale al colpo: il client riprende la stessa clip dallo stesso punto.
		if row.size()>21 and (row[20]!=body.reaction or absf(row[21]-body.reaction_time)>0.15): body.reaction=row[20];body.reaction_time=row[21]
		body.collision_layer = 0 if body.dead else 4
		body.bar.visible = not body.dead and body.health<body.max_health
		body.bar.scale.x = body.health/body.max_health
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
		body.reset_at(call("respawn_point") if has_method("respawn_point") else Vector3(3,0.5,2))
		body.set_meta("respawning",false)

func set_paused(value: bool) -> void:
	ui_open = value
	if terrain: terrain.visible=started
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
		# Migrazione delle preferenze delle versioni precedenti: solo fullscreen + indice 0..2.
		if not profile_config.has_section_key("settings","display_mode"):
			settings_data.display_mode = 2 if bool(settings_data.fullscreen) else 0
		if not profile_config.has_section_key("settings","shadow_quality"):
			settings_data.shadow_quality = 3 if bool(settings_data.shadows) else 0
		settings_data.shadows = int(settings_data.shadow_quality) > 0
		if typeof(settings_data.resolution) != TYPE_STRING:
			var legacy := [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1600,1000)]
			settings_data.resolution = _resolution_key(legacy[clampi(int(settings_data.resolution),0,2)])
		Session.nickname = str(profile_config.get_value("profile","name","Survivor"))
		Session.skin = clampi(int(profile_config.get_value("profile","skin",0)),0,SKINS.size()-1)
	settings_data.resolution = _resolution_key(_nearest_resolution(resolution_size()))

func _save_preferences() -> void:
	if automated: return
	for key in settings_data: profile_config.set_value("settings",key,settings_data[key])
	profile_config.set_value("profile","name",Session.nickname)
	profile_config.set_value("profile","skin",Session.skin)
	profile_config.save("user://preferences.cfg")

func _apply_settings() -> void:
	player.rig.sensitivity = float(settings_data.sensitivity)
	blood_enabled = bool(settings_data.blood)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(float(settings_data.volume),0.001)/100))
	for body in targets:
		if is_instance_valid(body): body.blood_enabled = blood_enabled
	_apply_graphics()
	_save_preferences()

## Risoluzione nativa dello schermo su cui è aperta la finestra.
func _native_resolution() -> Vector2i:
	var screen := DisplayServer.window_get_current_screen()
	var size := DisplayServer.screen_get_size(screen)
	if size.x <= 0 or size.y <= 0: size = DisplayServer.window_get_size()
	if size.x <= 0 or size.y <= 0: size = Vector2i(1440,900)
	return size

## Elenco delle risoluzioni realmente utilizzabili sul monitor corrente.
## Parte dalla risoluzione nativa e tiene solo i formati che ci stanno dentro.
func monitor_resolutions() -> Array[Vector2i]:
	if _resolution_cache.is_empty(): _resolution_cache = _detect_resolutions()
	return _resolution_cache

func _detect_resolutions() -> Array[Vector2i]:
	var native := _native_resolution()
	var found: Array[Vector2i] = []
	var seen := {}
	for size in RESOLUTION_LADDER:
		if size.x <= native.x and size.y <= native.y and not seen.has(size):
			found.append(size)
			seen[size] = true
	if not seen.has(native):
		found.append(native)
		seen[native] = true
	var window := DisplayServer.window_get_size()
	if window.x >= 1024 and window.y >= 600 and window.x <= native.x and window.y <= native.y and not seen.has(window):
		found.append(window)
	found.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		if a.x == b.x: return a.y < b.y
		return a.x < b.x)
	return found

func _nearest_resolution(size: Vector2i) -> Vector2i:
	var options := monitor_resolutions()
	if options.is_empty(): return Vector2i(1280,720)
	if size == Vector2i.ZERO: return options[options.size()-1]
	var best := options[0]
	var score := INF
	for option in options:
		var delta := option-size
		var distance := float(delta.x*delta.x+delta.y*delta.y)
		if distance < score:
			score = distance
			best = option
	return best

func _resolution_key(size: Vector2i) -> String:
	return "%dx%d" % [size.x,size.y]

func resolution_size() -> Vector2i:
	var text := str(settings_data.get("resolution","")).to_lower().strip_edges()
	var parts := text.split("x")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(int(parts[0]),int(parts[1]))
	return Vector2i.ZERO

## Preset complessivo: aggiorna texture, ombre e anti-aliasing in un colpo solo.
func apply_quality_preset(index: int) -> void:
	var level := clampi(index,0,QUALITY_PRESETS.size()-1)
	settings_data.quality = level
	var preset: Dictionary = QUALITY_PRESETS[level]
	settings_data.textures = int(preset.textures)
	settings_data.shadow_quality = int(preset.shadow_quality)
	settings_data.anti_aliasing = int(preset.anti_aliasing)
	settings_data.shadows = int(preset.shadow_quality) > 0
	_apply_settings()

func quality_preset_values(index: int) -> Dictionary:
	return QUALITY_PRESETS[clampi(index,0,QUALITY_PRESETS.size()-1)]

func _apply_graphics() -> void:
	var display_mode := clampi(int(settings_data.display_mode),0,2)
	var target := resolution_size()
	if target == Vector2i.ZERO: target = _native_resolution()
	if not automated and DisplayServer.get_name() != "headless":
		var vsync: int = [DisplayServer.VSYNC_DISABLED,DisplayServer.VSYNC_ENABLED,DisplayServer.VSYNC_ADAPTIVE][clampi(int(settings_data.vsync),0,2)]
		DisplayServer.window_set_vsync_mode(vsync)
		match display_mode:
			0:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_size(target)
				_center_window(target)
				_set_render_scale(1.0)
			_:
				# A schermo intero Windows ignora window_set_size: la risoluzione scelta
				# diventa la risoluzione interna di rendering, poi scalata al monitor.
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if display_mode == 1 else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
				_set_render_scale(render_scale_for(target))
	_apply_render_quality()

## Fattore di scala per far corrispondere il rendering 3D alla risoluzione scelta.
## Vale 1.0 quando la risoluzione coincide con quella nativa del monitor.
func render_scale_for(target: Vector2i) -> float:
	var screen := _native_resolution()
	if target == Vector2i.ZERO or screen.x <= 0 or screen.y <= 0: return 1.0
	var scale := minf(float(target.x)/float(screen.x),float(target.y)/float(screen.y))
	return clampf(scale,0.25,1.0)

func _set_render_scale(scale: float) -> void:
	var viewport := get_viewport()
	if viewport: viewport.scaling_3d_scale = clampf(scale,0.25,1.0)

func _center_window(size: Vector2i) -> void:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	if usable.size.x <= 0 or usable.size.y <= 0: return
	DisplayServer.window_set_position(usable.position + (usable.size-size)/2)

func _apply_render_quality() -> void:
	var viewport := get_viewport()
	if viewport:
		var textures := clampi(int(settings_data.textures),0,3)
		viewport.anisotropic_filtering_level = [Viewport.ANISOTROPY_DISABLED,Viewport.ANISOTROPY_2X,Viewport.ANISOTROPY_8X,Viewport.ANISOTROPY_16X][textures]
		var aa := clampi(int(settings_data.anti_aliasing),0,4)
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
		viewport.msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_8X][aa]
		viewport.msaa_2d = Viewport.MSAA_DISABLED
	var shadow := clampi(int(settings_data.shadow_quality),0,4)
	if not bool(settings_data.shadows): shadow = 0
	var max_distance: float = [0.0,55.0,85.0,130.0,200.0][shadow]
	var blur: float = [0.0,1.6,1.2,0.8,0.5][shadow]
	for child in landscape.get_children():
		if child is DirectionalLight3D:
			child.shadow_enabled = shadow > 0
			child.directional_shadow_max_distance = maxf(max_distance,1.0)
			child.shadow_blur = blur
			child.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if shadow <= 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS

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
	await get_tree().create_timer(14,true).timeout
	for id in actors:
		if id != 1: print("NET_HOST_INV owned=",actors[id].owned," hotbar=",actors[id].hotbar," items=",actors[id].items," credits=",actors[id].credits," thrown=",get("survival").thrown.size())
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
	await get_tree().create_timer(2,true).timeout
	# Inventario in rete: l'host decide tutto. Vendita senza teste rifiutata, lancio, oggetto lasciato e raccolto.
	var rules: Node3D = get("survival")
	if rules:
		rules.request("sell:item_testa")
		await get_tree().create_timer(0.4,true).timeout
		var refused: bool = player.credits == 0
		rules.request("slot:1")
		await get_tree().create_timer(0.4,true).timeout
		var slot_ok: bool = player.equipped == ""
		rules.request("slot:0")
		await get_tree().create_timer(0.3,true).timeout
		rules.request("throw:axe:14")
		await get_tree().create_timer(0.5,true).timeout
		var throw_ok: bool = not player.owned.has("axe") and rules.thrown.size() == 1
		rules.request("slot:0")
		await get_tree().create_timer(0.3,true).timeout
		var seen_flying: int = rules.thrown.size()
		print("NET_INV sell_refused=",refused," slot=",slot_ok," throw=",throw_ok," thrown_on_client=",seen_flying," owned=",player.owned," hotbar=",player.hotbar)
		good = good and refused and slot_ok and throw_ok
	await get_tree().create_timer(3,true).timeout
	Session.leave()
	get_tree().quit(0 if good else 1)
