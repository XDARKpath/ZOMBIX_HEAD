# Scena principale ZOMBIX HEAD. Mantiene il nucleo cooperativo e aggiunge missione e presentazione.
extends "res://world/zona1_rifugio/fase3.gd"
var expedition: Node3D
var presentation: Node3D
var overlay: Control
var footstep_clock: float = 0
var footsteps: AudioStreamPlayer
var survival:Node3D
var zone_life:Node3D
var zone_kit:Node3D
var roadblocks:Node3D
var boss_hunt:Node3D
var zone2:Node3D
var zone_gates:Node3D
var pending_resume:bool=false
var dungeon:Node3D
var rocca:Node3D
var village:Node3D
var quest:Node3D
var spawner:Node
var fence:Node3D
var hazards:Node3D
var audio_clock:float=0.0
var weapon_table:Node3D
const TABLE_AT:=Vector3(-5.5,0,-6)
const TABLE_YAW:=PI*0.5

## Mobili e pezzi fissi rimasti senza collisione: serve la fisica già attiva, poi la navigazione li vede.
func _solidify() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var solid:=preload("res://world/campaign/solid_props.gd")
	solid.settle(self,self)
	solid.box_loose_props(self,self)
	await get_tree().physics_frame
	nav_region.bake_navigation_mesh(true)

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
	expedition.set_script(preload("res://world/campaign/campaign.gd"))
	add_child(expedition)
	expedition.build(self)
	roadblocks=Node3D.new();roadblocks.set_script(preload("res://world/campaign/roadblocks.gd"));nav_region.add_child(roadblocks);roadblocks.build(self)
	survival=Node3D.new();survival.set_script(preload("res://world/campaign/survival_rules.gd"));add_child(survival);survival.build(self)
	# Rumore, sacco della morte, cibo e pesca (primo traguardo della Zona 1).
	zone_life=Node3D.new();zone_life.set_script(preload("res://world/campaign/zone1_life.gd"));zone_life.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(zone_life);zone_life.build(self)
	# Kit ambiente dei batch ZOMBIX: armeria, rovine, casse, bauli e NPC in posa.
	zone_kit=Node3D.new();zone_kit.set_script(preload("res://world/zona1_rifugio/zone1_kit.gd"));add_child(zone_kit);zone_kit.build(self)
	# Il dungeon della Zona 1: la ROCCA MALEDETTA (torre al sito ovest, sala grande, segrete con trappole, arena del
	# Carceriere) con sotto la CRIPTA (labirinto, segrete, cisterna, sala dei secondini). Due costruttori, un percorso.
	dungeon=Node3D.new();dungeon.name="Dungeon";dungeon.process_mode=Node.PROCESS_MODE_PAUSABLE
	dungeon.set_script(preload("res://world/dungeon/dungeon.gd"));add_child(dungeon);dungeon.build(self)
	rocca=Node3D.new();rocca.name="Rocca";rocca.process_mode=Node.PROCESS_MODE_PAUSABLE
	rocca.set_script(preload("res://world/rocca/rocca.gd"));add_child(rocca);rocca.build(self)
	dungeon.rocca=rocca;rocca.cripta=dungeon
	# Borgo Cenere: il villaggio del secondo boss, sulla statale a nord-est del paese.
	village=Node3D.new();village.process_mode=Node.PROCESS_MODE_PAUSABLE
	village.set_script(preload("res://world/villaggio/villaggio.gd"));add_child(village);village.build_village(self)
	# Il recinto sta nella regione di navigazione: gli infetti ci girano attorno.
	fence=preload("res://world/zona1_rifugio/town_fence.gd").new();fence.build(self,nav_region)
	spawner=preload("res://world/campaign/zone1_spawner.gd").new();add_child(spawner);spawner.build(self)
	hazards=preload("res://world/campaign/hazards.gd").new();add_child(hazards);hazards.build(self)
	boss_hunt=Node3D.new();boss_hunt.set_script(preload("res://bosses/boss_hunt.gd"));boss_hunt.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(boss_hunt);boss_hunt.build(self)
	quest=Node3D.new();quest.set_script(preload("res://world/campaign/zone1_quest.gd"));add_child(quest);quest.build(self)
	# La Zona 2 (deserto, Porto Secco, Mago e Signore) e i valichi che chiudono le zone.
	zone2=Node3D.new();zone2.set_script(preload("res://world/zona2/zone2.gd"));zone2.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(zone2);zone2.build(self)
	zone_gates=Node3D.new();zone_gates.set_script(preload("res://world/zona2/zone_gates.gd"));add_child(zone_gates);zone_gates.build(self)
	terrain.fit_world_ranges([survival,zone_life,zone_kit,dungeon,rocca,boss_hunt,zone2,zone_gates])
	# Il tavolo con tutte le armi, appena fuori dalla partenza.
	weapon_table=preload("res://world/campaign/weapon_table.gd").new();nav_region.add_child(weapon_table);weapon_table.build(self,TABLE_AT,TABLE_YAW)
	# Alberi e massi piazzati da paese, kit e borgo: solidi anche loro, e via dalla strada.
	preload("res://world/campaign/solid_props.gd").apply(self,self)
	if started: expedition.start()
	overlay = Control.new()
	overlay.set_script(preload("res://ui/zombix_hud.gd"))
	$Interface.add_child(overlay)
	overlay.build(self)
	var gps:=Control.new()
	gps.name="RouteGPS"
	gps.set_script(preload("res://ui/route_gps.gd"))
	$Interface.add_child(gps)
	gps.build(self)
	var viewmodel:=Node3D.new();viewmodel.name="Viewmodel";viewmodel.set_script(preload("res://player/first_person_weapon.gd"));add_child(viewmodel);viewmodel.build(self)
	hud.hide()
	if DisplayServer.get_name() != "headless":
		footsteps = AudioStreamPlayer.new()
		footsteps.stream = load("res://audio/footstep.wav")
		footsteps.volume_db = -18
		add_child(footsteps)
	for arg in OS.get_cmdline_user_args():
		if arg=="--verify-zombix": call_deferred("_verify_zombix")
		elif arg=="--capture-action": call_deferred("_stage_action")
		elif arg.begins_with("--language="): Localization.set_language(arg.trim_prefix("--language="))
		elif arg.begins_with("--capture-language="):
			Localization.set_language("it"); menu.language("options"); _capture(arg.trim_prefix("--capture-language="))
		elif arg=="--capture-options": menu.settings()
		elif arg=="--capture-graphics": menu.graphics()
		elif arg=="--capture-hover": menu.entries[1].grab_focus()
		elif arg=="--capture-characters": menu.skins()
		elif arg=="--capture-controls": menu.controls()
		elif arg=="--verify-menu": call_deferred("_verify_menu")
		elif arg=="--verify-graphics": call_deferred("_verify_graphics")
		elif arg=="--verify-save": call_deferred("_verify_save")
		elif arg=="--verify-camp": call_deferred("_verify_camp")
		elif arg.begins_with("--record-camp="): call_deferred("_record_camp",arg.trim_prefix("--record-camp="))
		elif arg.begins_with("--record-menu="): call_deferred("_record_menu",arg.trim_prefix("--record-menu="))
		elif arg=="--exp-host" or arg=="--exp-client": call_deferred("_verify_expedition_network",arg=="--exp-host")
	AudioManager.enter_menu()

func continue_save() -> void:
	if not SaveManager.has_save(): return
	pending_resume=true
	Session.launch()

func _begin_play() -> void:
	super._begin_play()
	if expedition: expedition.start()
	if survival:survival.reset()
	if zone_life:zone_life.reset()
	if roadblocks:roadblocks.reset()
	if boss_hunt:boss_hunt.reset()
	if zone2:zone2.reset()
	if dungeon:dungeon.reset()
	if rocca:rocca.reset()
	if village:village.reset()
	if quest:quest.reset()
	if spawner:spawner.reset()
	terrain.ensure_near([Vector3.ZERO])
	nav_region.navigation_mesh.filter_baking_aabb=preload("res://world/zona1_rifugio/refuge_layout.gd").NAV_BOUNDS
	nav_region.bake_navigation_mesh(false)
	_solidify()
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
	if pending_resume:
		pending_resume=false
		SaveManager.apply(self)
	else:
		if not automated: SaveManager.erase()
		announce("Il 4×4 è a pezzi. Parla con lo sceriffo. G apre il GPS.",6)
	AudioManager.enter_game()

func _back_to_camp() -> void:
	if expedition:
		expedition.car.reset()
		expedition.visible=false
	if boss_hunt:boss_hunt.reset()
	if zone2:zone2.reset()
	if dungeon:dungeon.reset()
	if rocca:rocca.reset()
	if village:village.reset()
	super._back_to_camp()
	AudioManager.enter_menu()

func _process(delta: float) -> void:
	super._process(delta)
	if hud: hud.hide()
	if not started or get_tree().paused: return
	audio_clock -= delta
	if audio_clock <= 0.0:
		audio_clock = 0.35
		var danger := false
		for enemy in targets:
			if is_instance_valid(enemy) and not enemy.dead and player.global_position.distance_to(enemy.global_position) < 27.0:
				danger = true
				break
		AudioManager.set_combat(danger)
	if footsteps and player.is_on_floor() and player.velocity.length()>1 and not player.dodging:
		footstep_clock -= delta
		if footstep_clock<=0:
			footstep_clock = 0.28 if player.sprinting else 0.43
			AudioManager.footstep(randf_range(0.9,1.1))

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if started and not ui_open and event.is_action_pressed("interact") and rocca and (rocca.request_use(player) or dungeon.request_use(player) or (village and village.request_use(player)) or (zone2 and zone2.request_use(player))):
		return
	if started and not ui_open and event.is_action_pressed("interact") and expedition:
		if not survival.request_context():expedition.request_use()

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

func _verify_save() -> void:
	Session.launch()
	await get_tree().create_timer(1.2).timeout
	var probe := preload("res://tests/save_probe.gd").new()
	var success: bool = await probe.run(self)
	Session.leave()
	get_tree().quit(0 if success else 1)

func _verify_menu() -> void:
	var checks := preload("res://tests/menu05_checks.gd").new()
	var success: bool = await checks.run(self)
	Session.leave()
	get_tree().quit(0 if success else 1)

func _verify_graphics() -> void:
	var checks := preload("res://tests/graphics_menu_checks.gd").new()
	var success: bool = await checks.run(self)
	Session.leave()
	get_tree().quit(0 if success else 1)

func _record_menu(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for warmup in range(60): await get_tree().process_frame
	for frame in range(72):
		if frame==18: menu.entries[1].grab_focus()
		elif frame==36: menu.entries[2].grab_focus()
		elif frame==54: get_viewport().gui_release_focus()
		for step in range(6): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder+"/frame_%03d.png" % frame)
	get_tree().create_timer(0.15,true).timeout.connect(get_tree().quit)
	queue_free()

func _verify_camp() -> void:
	var checks := preload("res://tests/camp10_checks.gd").new()
	var success: bool = await checks.run(self)
	Session.leave()
	get_tree().quit(0 if success else 1)

func _record_camp(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for warmup in range(30): await get_tree().process_frame
	camp.avatars[0].clock = 0
	for frame in range(140):
		for step in range(6): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder+"/frame_%03d.png" % frame)
	get_tree().create_timer(0.15,true).timeout.connect(get_tree().quit)
	queue_free()

func respawn_point() -> Vector3:
	if expedition and expedition.car.repaired:
		var point:Vector3=expedition.car.position+Vector3(4,0,0)
		point.y=terrain.height(point.x,point.z)+0.5
		return point
	return Vector3(3,0.5,2)

func activate_zone(index:int) -> void:
	if Session.online and not multiplayer.is_server(): return
	var at:Vector3=preload("res://world/campaign/route.gd").POINTS[index]
	terrain.ensure_near([at])
	for enemy in targets:
		if is_instance_valid(enemy): enemy.queue_free()
	targets.clear()
	nav_region.navigation_mesh.filter_baking_aabb=AABB(at+Vector3(-55,-2,-55),Vector3(110,12,110))
	nav_region.bake_navigation_mesh(false)
	for i in range(6):
		var angle:float=i*TAU/6
		_spawn_enemy(at+Vector3(cos(angle)*27,0,sin(angle)*27))
	announce("Presidio raggiunto. Scendete, eliminate gli infetti e usate il relay.",6)

func is_safe(at:Vector3) -> bool:
	return preload("res://world/zona1_rifugio/refuge_layout.gd").safe(at) or (zone2!=null and zone2.safe(at))
func drop_head(enemy:Node3D,at:Transform3D) -> void:
	if survival:survival.drop_head(enemy,at)

## Nel recinto del paese nessuno ti vede: gli infetti lasciano perdere e tornano indietro.
func nearest_player(at:Vector3) -> CharacterBody3D:
	var result:CharacterBody3D
	var distance:=INF
	for body in actors.values():
		if is_instance_valid(body) and not body.dead and not preload("res://world/zona1_rifugio/refuge_layout.gd").safe(body.global_position) and body.position.distance_squared_to(at)<distance:
			distance=body.position.distance_squared_to(at)
			result=body
	return result

## La scala della Rocca scende sotto il livello del terreno: lì non si sta annegando.
func below_ground_ok() -> bool:
	return rocca!=null and rocca.entrance_node!=null and player.global_position.distance_to(rocca.entrance_node.global_position)<16.0

## Tutti i colpi ai giocatori passano da qui (solo host). fx: knock (spinta), shake, heavy, e i secondi di poison, bleed, stun, slow, fear.
func hit_player(a:CharacterBody3D,amount:float,fx:Dictionary,from:Vector3) -> bool:
	if a.dead:return false
	var guarded:bool=a.melee.blocking and a.stamina>0.0
	if amount>0.0 and not a.take_damage(amount):return false
	var push:Vector3=fx.get("knock",Vector3.ZERO)
	if guarded:push*=0.35
	a.knock(push)
	# La parata tiene lontano il morso e il veleno, ma non lo schianto che ti stordisce.
	for kind in ["poison","bleed","slow","fear"]:
		if fx.has(kind) and not guarded:a.status.add(kind,float(fx[kind]))
	if fx.has("stun"):a.status.add("stun",float(fx["stun"])*(0.5 if guarded else 1.0))
	var heavy:bool=fx.get("heavy",false)
	var shake:float=float(fx.get("shake",0.2))
	if heavy:a.set_meta("hit_heavy_until",Time.get_ticks_msec()+500)
	var peer:int=actors.find_key(a) if actors.values().has(a) else 0
	if a==player:_feel_hit(from,shake)
	elif Session.online and peer>0:hit_feedback.rpc_id(peer,from,shake,push)
	if Session.online and multiplayer.is_server():
		for other in Session.connected_peers():
			if heavy:heavy_hit_seen.rpc_id(other,peer)
	return true

## Gli effetti dei boss (bosses/boss_fx.gd): solo grafica, l'host li fa partire per tutti.
func boss_fx(kind:String,at:Vector3,data:Dictionary) -> void:
	preload("res://bosses/boss_fx.gd").play(self,kind,at,data)
	if Session.online and multiplayer.is_server():
		for peer in Session.connected_peers():boss_fx_seen.rpc_id(peer,kind,at,data)

@rpc("authority","call_remote","reliable")
func boss_fx_seen(kind:String,at:Vector3,data:Dictionary) -> void:
	preload("res://bosses/boss_fx.gd").play(self,kind,at,data)

## Solo sul computer di chi è stato colpito: la testa scatta, la camera trema, la freccia rossa indica da dove.
func _feel_hit(from:Vector3,shake:float) -> void:
	player.rig.add_shake(shake)
	player.rig.hit_punch(from,shake+0.25)
	player.set_meta("hit_from",from)
	player.set_meta("hit_at",Time.get_ticks_msec())

@rpc("authority","call_remote","reliable")
func hit_feedback(from:Vector3,shake:float,push:Vector3) -> void:
	_feel_hit(from,shake)
	player.knock(push)

@rpc("authority","call_remote","reliable")
func heavy_hit_seen(peer:int) -> void:
	if actors.has(peer):actors[peer].set_meta("hit_heavy_until",Time.get_ticks_msec()+500)
