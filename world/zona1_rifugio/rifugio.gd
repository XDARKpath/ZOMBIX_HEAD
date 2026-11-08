# Nodo: Rifugio (Node3D), scena rifugio.tscn; process_mode Always per gestire il menu in pausa.
# Figli richiesti: Player, SpawnPoint, DamageZone (Area3D), Interface (CanvasLayer).
extends Node3D

const Balance = preload("res://autoload/balance.gd")
@onready var player: CharacterBody3D = $Player
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var health_text: Label
var stamina_text: Label
var state_text: Label
var notice: Label
var pause_panel: Control
var notice_left: float = 0
var damage_clock: float = 0
var returning: bool = false
var automated: bool = false
var resume_button: Button

func _ready() -> void:
	automated = not OS.get_cmdline_user_args().is_empty()
	_build_ui()
	player.vitals_changed.connect(_update_vitals)
	player.damaged.connect(func(amount: float) -> void: announce("Colpo ricevuto: −%d vita" % int(amount)))
	player.died.connect(func() -> void: _return_to_spawn("Hai perso la testa. Per ora, solo per prova."))
	player.fell_out.connect(func() -> void: _return_to_spawn("Fuori dall'area di prova: ritorno al rifugio."))
	_update_vitals(player.health, player.stamina)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if automated else Input.MOUSE_MODE_CAPTURED
	announce("Esplora il rifugio. F1 per i comandi; Esc per liberare il mouse.", 7)
	for argument in OS.get_cmdline_user_args():
		if argument == "--verify":
			_run_checks()
		elif argument.begins_with("--capture="):
			_capture(argument.trim_prefix("--capture="))
		elif argument == "--capture-menu":
			set_paused(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not automated:
		set_paused(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("preview_help"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif not get_tree().paused and event.is_action_pressed("test_damage"):
		if not player.take_damage(Balance.TEST_DAMAGE):
			announce("Schivata riuscita: colpo evitato." if player.is_invulnerable() else "Attendi il rientro al rifugio.")

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if $DamageZone.overlaps_body(player) and not player.dead:
		damage_clock += delta
		if damage_clock >= Balance.TEST_DAMAGE_INTERVAL:
			damage_clock = 0
			player.take_damage(Balance.TEST_DAMAGE)
	else:
		damage_clock = 0
	if notice_left > 0:
		notice_left -= delta
		notice.visible = notice_left > 0
	if player.dead:
		state_text.text = "RIENTRO AL RIFUGIO…"
	elif player.is_invulnerable():
		state_text.text = "SCHIVATA  /  INVULNERABILE"
	elif player.dodging:
		state_text.text = "RECUPERO SCHIVATA"
	elif player.exhausted:
		state_text.text = "AFFATICATO  /  RECUPERA STAMINA"
	elif player.sprinting:
		state_text.text = "CORSA"
	else:
		state_text.text = "ESPLORAZIONE"

func set_paused(value: bool) -> void:
	get_tree().paused = value
	pause_panel.visible = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or automated else Input.MOUSE_MODE_CAPTURED
	if value:
		resume_button.grab_focus()

func announce(text: String, seconds: float = 3.0) -> void:
	notice.text = text
	notice.show()
	notice_left = seconds

func _return_to_spawn(message: String) -> void:
	if returning:
		return
	returning = true
	announce(message, Balance.RESPAWN_SECONDS + 2)
	await get_tree().create_timer(Balance.RESPAWN_SECONDS, false).timeout
	player.reset_at($SpawnPoint.global_position)
	damage_clock = 0
	returning = false

func _update_vitals(health: float, stamina: float) -> void:
	health_bar.value = health
	stamina_bar.value = stamina
	health_text.text = "VITA                         %03d / 100" % ceili(health)
	stamina_text.text = "STAMINA                      %03d / 100" % ceili(stamina)

func _label(text: String, size: int = 18, color: Color = Color("e6eddc")) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.08, 0.08, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	return button

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(310, 13)
	bar.show_percentage = false
	bar.max_value = 100
	bar.add_theme_stylebox_override("background", _style(Color("162c2c")))
	bar.add_theme_stylebox_override("fill", _style(color))
	return bar

func _build_ui() -> void:
	var root := Control.new()
	$Interface.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI"])
	var theme := Theme.new()
	theme.default_font = font
	root.theme = theme
	var heading := _label("TESTE", 40, Color("dcec91"))
	heading.position = Vector2(36, 24)
	root.add_child(heading)
	var sub := _label("01  /  IL RIFUGIO", 17)
	sub.position = Vector2(38, 76)
	root.add_child(sub)
	var task := _label("FASE 1  ·  CAMPO DI PROVA\nEsplora, corri e prova la schivata.\nIl riquadro rosso infligge danni di prova.", 17)
	root.add_child(task)
	task.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	task.offset_left = -412
	task.offset_top = 34
	task.offset_right = -30
	var hud := PanelContainer.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.offset_left = 36
	hud.offset_top = -265
	hud.offset_bottom = -74
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_stylebox_override("panel", _style(Color(0.035, 0.1, 0.11, 0.94)))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 9)
	hud.add_child(rows)
	health_text = _label("")
	rows.add_child(health_text)
	health_bar = _bar(Color("de8469"))
	rows.add_child(health_bar)
	stamina_text = _label("")
	rows.add_child(stamina_text)
	stamina_bar = _bar(Color("dcec91"))
	rows.add_child(stamina_bar)
	state_text = _label("ESPLORAZIONE", 13, Color("b8cda4"))
	rows.add_child(state_text)
	var controls := _label("WASD  Muovi     SHIFT  Corri     SPAZIO / CTRL  Schiva     MOUSE  Camera     F1 / ESC  Comandi e pausa", 17)
	root.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 36
	controls.offset_top = -40
	notice = _label("", 20, Color("f3e7a5"))
	root.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -440
	notice.offset_right = 440
	notice.offset_top = 126
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var crosshair := _label("·", 28)
	root.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -4
	crosshair.offset_top = -20
	pause_panel = ColorRect.new()
	root.add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(pause_panel as ColorRect).color = Color(0.02, 0.06, 0.07, 0.85)
	var menu := PanelContainer.new()
	pause_panel.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -390
	menu.offset_right = 390
	menu.offset_top = -315
	menu.offset_bottom = 315
	menu.add_theme_stylebox_override("panel", _style(Color("152f32")))
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", 17)
	menu.add_child(items)
	items.add_child(_label("TESTE  /  PAUSA", 32, Color("dcec91")))
	items.add_child(_label("WASD / stick sinistro: movimento\nMouse / stick destro: camera · Rotella: distanza\nShift / L3: corsa · Spazio, Ctrl / B: rotolamento\nEsc / Start: pausa · F1: questa guida\n\nF2: ricevi un colpo di prova (20 danni).\nSchiva e premi F2 per provare l'invulnerabilità iniziale.\nA vita zero torni al rifugio. Non esiste ancora un inventario.\n\nGli zombie sono modelli di prova: AI nella Fase 3.\nLa pesca futura fornirà solo cibo. Non si pescano zombie.\nArmi e combattimento iniziano nella Fase 2.", 20))
	resume_button = _button("Riprendi", func() -> void: set_paused(false))
	items.add_child(resume_button)
	items.add_child(_button("Riparti al rifugio", func() -> void:
		if returning:
			return
		player.reset_at($SpawnPoint.global_position)
		damage_clock = 0
		set_paused(false)))
	items.add_child(_button("Esci", func() -> void: get_tree().quit()))
	pause_panel.hide()

func _run_checks() -> void:
	var checks = load("res://tests/phase1_checks.gd").new()
	var passed: bool = await checks.run(self)
	get_tree().quit(0 if passed else 1)

func _capture(path: String) -> void:
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("Cattura Fase 1: ", error)
	get_tree().quit(error)
