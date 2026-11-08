extends Node3D
const Balance = preload("res://autoload/balance.gd")
@onready var player: CharacterBody3D = $Player
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var charge_bar: ProgressBar
var objective: Label
var notice: Label
var pause_panel: Control
var settings_panel: Control
var hud: Control
var menu_title: Label
var resume_button: Button
var cinematic: Camera3D
var landscape: Node3D
var targets: Array[Node3D] = []
var kills: int = 0
var started: bool = false
var automated: bool = false
var notice_left: float = 0
var returning: bool = false
var blood_enabled: bool = true
var sound: AudioStreamPlayer

func _ready() -> void:
	automated = not OS.get_cmdline_user_args().is_empty()
	landscape = Node3D.new()
	landscape.process_mode = Node.PROCESS_MODE_PAUSABLE
	landscape.set_script(preload("res://world/zona1_rifugio/landscape.gd"))
	add_child(landscape)
	landscape.build()
	for child in player.roll_pivot.get_children():
		if child is Node3D: child.visible = false
	var avatar := Node3D.new()
	avatar.set_script(preload("res://art/survivor_visual.gd"))
	player.roll_pivot.add_child(avatar)
	avatar.position.y = -0.9
	avatar.rotation.y = PI
	avatar.configure(preload("res://ui/camp/camp.gd").MODELS[clampi(Session.skin,0,9)],player)
	_spawn_targets()
	cinematic = Camera3D.new()
	add_child(cinematic)
	cinematic.position = Vector3(14,4.8,12)
	cinematic.look_at(Vector3(-5,1,-11))
	cinematic.fov = 61
	sound = AudioStreamPlayer.new()
	add_child(sound)
	_build_ui()
	player.vitals_changed.connect(_update_vitals)
	player.died.connect(func() -> void: _return_to_spawn("Rientro al rifugio"))
	player.fell_out.connect(func() -> void: _return_to_spawn("Ritorno sulla riva"))
	player.melee.attack_rejected.connect(announce)
	player.melee.attack_started.connect(func(_heavy: bool) -> void: _play("swing"))
	player.melee.impact.connect(func(_target: Node3D, heavy: bool) -> void: _play("heavy" if heavy else "hit"))
	_update_vitals(player.health,player.stamina)
	started = automated
	set_paused(not automated)
	for arg in OS.get_cmdline_user_args():
		if arg == "--verify": _run_checks()
		elif arg.begins_with("--capture="): _capture(arg.trim_prefix("--capture="))
		elif arg == "--capture-menu":
			started = false
			set_paused(true)

func _spawn_targets() -> void:
	for target in targets:
		if is_instance_valid(target): target.queue_free()
	targets.clear()
	kills = 0
	for i in range(3):
		var zombie := CharacterBody3D.new()
		zombie.set_script(preload("res://enemies/zombie_target.gd"))
		zombie.process_mode = Node.PROCESS_MODE_PAUSABLE
		zombie.name = "Zombie%d" % i
		zombie.position = [Vector3(3,0.3,-3),Vector3(8,0.3,-7),Vector3(1,0.3,-10)][i]
		add_child(zombie)
		zombie.rotation.y = 0
		zombie.setup(i)
		zombie.blood_enabled = blood_enabled
		zombie.defeated.connect(func(_body: Node3D) -> void:
			kills += 1
			if kills == 3: announce("Cortile libero. Raggiungi il pontile per riprendere fiato.",8))
		targets.append(zombie)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if not started and not settings_panel.visible: return
		if settings_panel.visible:
			settings_panel.hide()
			pause_panel.show()
		else: set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("preview_help"):
		set_paused(true)
		_show_controls()
	elif not get_tree().paused and event.is_action_pressed("interact"):
		if player.position.distance_to(Vector3(-1,0,4)) < 3:
			_spawn_targets()
			player.health = 100
			player.stamina = 100
			announce("Scorte recuperate. Il cortile è pronto per una nuova prova.")
	elif not get_tree().paused and event.is_action_pressed("test_damage"):
		player.take_damage(20)

## Sotto quota -1 si è caduti in acqua, salvo dove il gioco scende davvero sotto terra.
func below_ground_ok() -> bool:
	return false


func _process(delta: float) -> void:
	if get_tree().paused: return
	if player.position.y < -1.0 and not returning and not below_ground_ok(): _return_to_spawn("L'acqua è troppo profonda. Ritorno sulla riva.")
	objective.text = "CORTILE DEL RIFUGIO\n" + ("Area ripulita" if kills == 3 else "Elimina gli infetti  ·  %d / 3" % kills)
	charge_bar.value = player.melee.charge_fraction()*100
	charge_bar.visible = player.melee.charging
	if notice_left > 0:
		notice_left -= delta
		notice.visible = notice_left > 0
	if player.position.distance_to(Vector3(-1,0,4)) < 2.5 and notice_left <= 0:
		notice.text = "E  ·  Rifornisciti e ripeti la prova"
		notice.show()

func set_paused(value: bool) -> void:
	get_tree().paused = value
	pause_panel.visible = value
	settings_panel.hide()
	hud.visible = not value
	cinematic.current = value and not started
	if started: player.rig.camera.current = true
	menu_title.text = "TESTE" if not started else "IN PAUSA"
	resume_button.text = "ENTRA NEL RIFUGIO" if not started else "RIPRENDI"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or automated else Input.MOUSE_MODE_CAPTURED
	if value: resume_button.grab_focus()

func _start() -> void:
	started = true
	set_paused(false)
	announce("Click: colpo rapido  ·  Tieni premuto: colpo caricato",6)

func announce(message: String, seconds: float = 3.0) -> void:
	notice.text = message
	notice.show()
	notice_left = seconds

func _return_to_spawn(message: String) -> void:
	if returning: return
	returning = true
	player.melee.cancel()
	announce(message)
	await get_tree().create_timer(Balance.RESPAWN_SECONDS,false).timeout
	player.reset_at($SpawnPoint.global_position)
	returning = false

func _play(asset: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var path := "res://audio/"+asset+".wav"
	if ResourceLoader.exists(path):
		sound.stream = load(path)
		sound.pitch_scale = randf_range(0.92,1.08)
		sound.play()

func _update_vitals(health: float, stamina: float) -> void:
	health_bar.value = health
	stamina_bar.value = stamina

func _label(parent: Node, text: String, at: Vector2, font_size: int, color: Color = Color("deddd3")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, at: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(330,52)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",20)
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.11,0.16,0.16,0.45)
	base.corner_radius_top_right = 6
	base.corner_radius_bottom_right = 6
	base.content_margin_left = 20
	base.border_width_left = 2
	base.border_color = Color("59605a")
	button.add_theme_stylebox_override("normal",base)
	var hover := base.duplicate()
	hover.bg_color = Color("665038")
	hover.border_color = Color("e6a16e")
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("focus",hover)
	parent.add_child(button)
	button.pressed.connect(callback)
	button.mouse_entered.connect(func() -> void:
		button.create_tween().tween_property(button,"position:x",at.x+5,0.12))
	button.mouse_exited.connect(func() -> void:
		button.create_tween().tween_property(button,"position:x",at.x,0.12))
	return button

func _bar(parent: Node, at: Vector2, width: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = Vector2(width,5)
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size",1)
	bar.custom_minimum_size = Vector2(width,5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03,0.04,0.04,0.7)
	bar.add_theme_stylebox_override("background",bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill",fill)
	parent.add_child(bar)
	bar.set_deferred("size",Vector2(width,5))
	return bar

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Interface.add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift","Segoe UI"])
	var theme := Theme.new()
	theme.default_font = font
	root.theme = theme
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	_label(hud,"LAGO CENERE",Vector2(42,30),23)
	_label(hud,"ZONA 01  /  RIFUGIO",Vector2(43,60),12,Color("b4b9a6"))
	objective = _label(hud,"",Vector2(1080,34),17)
	_label(hud,"+",Vector2(713,439),20,Color(1,1,1,0.65))
	_label(hud,"SOPRAVVISSUTO",Vector2(42,787),13,Color("b4b9a6"))
	health_bar = _bar(hud,Vector2(42,817),240,Color("c9c7ad"))
	stamina_bar = _bar(hud,Vector2(42,831),240,Color("a28555"))
	_label(hud,"ASCIA DA POMPIERE",Vector2(1140,787),17)
	_label(hud,"CLICK  Colpisci     TIENI  Carica",Vector2(1140,817),12,Color("b4b9a6"))
	charge_bar = _bar(hud,Vector2(675,489),90,Color("d18e59"))
	notice = _label(hud,"",Vector2(390,750),17)
	notice.size.x = 660
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(pause_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.018,0.032,0.035,0.78)
	shade.size = Vector2(510,900)
	pause_panel.add_child(shade)
	_label(pause_panel,"UN POSTO DOVE RESTARE VIVI",Vector2(62,120),13,Color("bd9869"))
	menu_title = _label(pause_panel,"TESTE",Vector2(56,152),94)
	_label(pause_panel,"LAGO CENERE",Vector2(62,267),22,Color("b3b8aa"))
	_label(pause_panel,"La strada è silenziosa.\nIl cortile non è vuoto.",Vector2(62,320),18,Color("aeb4ac"))
	resume_button = _button(pause_panel,"ENTRA NEL RIFUGIO",Vector2(62,428),_start)
	_button(pause_panel,"IMPOSTAZIONI",Vector2(62,490),_show_settings)
	_button(pause_panel,"COMANDI",Vector2(62,552),_show_controls)
	_button(pause_panel,"ESCI",Vector2(62,614),func() -> void: get_tree().quit())
	_label(pause_panel,"SOPRAVVIVENZA  /  COMBATTIMENTO  /  ESPLORAZIONE",Vector2(62,807),11,Color("8b978d"))
	_label(pause_panel,"VERSIONE DI SVILUPPO  0.2",Vector2(62,832),11,Color("8b978d"))
	settings_panel = Control.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(settings_panel)
	settings_panel.hide()

func _clear_settings(title: String) -> void:
	for child in settings_panel.get_children():
		settings_panel.remove_child(child)
		child.queue_free()
	pause_panel.hide()
	settings_panel.show()
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.04,0.043,0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(shade)
	_label(settings_panel,title,Vector2(140,130),42)
	_button(settings_panel,"INDIETRO",Vector2(140,680),func() -> void: settings_panel.hide(); pause_panel.show())

func _show_controls() -> void:
	_clear_settings("COMANDI")
	_label(settings_panel,"W A S D\nSHIFT\nSPAZIO / CTRL\nMOUSE\nCLICK SINISTRO\nTIENI + RILASCIA\nE\nESC",Vector2(140,230),22,Color("c69b68"))
	_label(settings_panel,"Muoviti\nCorri\nSchiva\nRuota la visuale\nColpo rapido\nColpo caricato\nRifornimenti vicino al barile\nPausa",Vector2(490,230),22)
	_label(settings_panel,"Controller: levetta sinistra per muoversi, destra per guardare.\nLa pesca è dedicata al cibo; non è ancora attiva in questa versione.\nGli infetti reagiscono ai colpi. L'inseguimento arriverà nella fase successiva.",Vector2(140,550),17,Color("a8b1a7"))

func _show_settings() -> void:
	_clear_settings("IMPOSTAZIONI")
	_label(settings_panel,"Sensibilità visuale",Vector2(140,230),22)
	var sensitivity := HSlider.new()
	sensitivity.position = Vector2(520,240)
	sensitivity.size.x = 400
	sensitivity.min_value = 0.3
	sensitivity.max_value = 2.0
	sensitivity.step = 0.05
	sensitivity.value = player.rig.sensitivity
	settings_panel.add_child(sensitivity)
	sensitivity.value_changed.connect(func(value: float) -> void: player.rig.sensitivity = value)
	_label(settings_panel,"Volume effetti",Vector2(140,310),22)
	var volume := HSlider.new()
	volume.position = Vector2(520,320)
	volume.size.x = 400
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0))*100
	settings_panel.add_child(volume)
	volume.value_changed.connect(func(value: float) -> void: AudioServer.set_bus_volume_db(0,linear_to_db(value/100)))
	var blood := CheckButton.new()
	blood.text = "Effetti del sangue"
	blood.position = Vector2(140,400)
	blood.button_pressed = blood_enabled
	settings_panel.add_child(blood)
	blood.toggled.connect(func(value: bool) -> void:
		blood_enabled = value
		for target in targets: target.blood_enabled = value)
	var shadows := CheckButton.new()
	shadows.text = "Ombre del sole"
	shadows.position = Vector2(140,470)
	var sun: DirectionalLight3D
	for child in landscape.get_children():
		if child is DirectionalLight3D: sun = child
	shadows.button_pressed = sun.shadow_enabled
	settings_panel.add_child(shadows)
	shadows.toggled.connect(func(value: bool) -> void: sun.shadow_enabled = value)

func _capture(path: String) -> void:
	if "--capture-lake" in OS.get_cmdline_user_args():
		player.reset_at(Vector3(6,0.1,12))
		player.rig.yaw = PI
		player.visual.rotation.y = PI
	await get_tree().create_timer(3,true).timeout
	if "--capture-combat" in OS.get_cmdline_user_args():
		player.reset_at(Vector3(3,0.1,-1.45))
		player.melee.perform_attack(true)
		await get_tree().create_timer(0.29).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ",path)
	get_tree().quit()

func _run_checks() -> void:
	var checks := preload("res://tests/phase2_checks.gd").new()
	var success: bool = await checks.run(self)
	sound.stop()
	sound.stream = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if success else 1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not automated and pause_panel:
		set_paused(true)
