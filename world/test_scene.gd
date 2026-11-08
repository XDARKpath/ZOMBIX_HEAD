# Nodo: TestScene (Node3D), scena world/test_scene.tscn.
# Figli richiesti: Camera3D, Interface (CanvasLayer), Terrain/Ground,
# House, Dock, Forest, ZombiePlaceholder, SpawnPoint, Environment, Sun.
# Solo anteprima Fase 0: nessun personaggio o sistema di combattimento attivo.
extends Node3D

const Balance = preload("res://autoload/balance.gd")
const INK := Color("10282d")
const PAPER := Color("e4ebd3")
const MUTED := Color("9bafb0")
const ACCENT := Color("dcec91")

@onready var camera: Camera3D = $Camera3D
@onready var interface: CanvasLayer = $Interface
var target: Vector3 = Balance.PREVIEW_TARGET
var distance: float = Balance.PREVIEW_DISTANCE
var yaw: float = Balance.PREVIEW_YAW
var pitch: float = Balance.PREVIEW_PITCH
var input_label: Label
var view_label: Label
var help_panel: PanelContainer
var escape_panel: PanelContainer
var root_ui: Control
var view_buttons: Array[Button] = []
var input_active: bool = true

func _ready() -> void:
	_build_interface()
	_set_view(0)
	for argument in OS.get_cmdline_user_args():
		if argument == "--verify":
			_verify_setup()
		elif argument.begins_with("--capture="):
			_capture(argument.trim_prefix("--capture="))
		elif argument == "--capture-help":
			_toggle_help()

func _process(delta: float) -> void:
	if input_active:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		yaw -= stick.x * Balance.PREVIEW_PAD_SPEED * delta
		pitch = clampf(pitch + stick.y * Balance.PREVIEW_PAD_SPEED * delta,
			Balance.PREVIEW_MIN_PITCH, Balance.PREVIEW_MAX_PITCH)
	_update_camera()

func _update_camera() -> void:
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)
	camera.h_offset = -distance * 0.12

func _input(event: InputEvent) -> void:
	# Il pannello mostra gli input anche quando un controllo UI ha il focus.
	if event is InputEventKey and event.echo:
		return
	var actions: PackedStringArray = []
	for action in InputMap.get_actions():
		if not action.begins_with("ui_") and event.is_action_pressed(action):
			actions.append(action)
	if not actions.is_empty():
		input_label.text = "INPUT RICEVUTO  /  " + ", ".join(actions)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		escape_panel.visible = not escape_panel.visible
		input_active = not escape_panel.visible and not help_panel.visible
		return
	if event.is_action_pressed("preview_help"):
		_toggle_help()
	if not input_active:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * Balance.PREVIEW_MOUSE_SENSITIVITY
		pitch = clampf(pitch + event.relative.y * Balance.PREVIEW_MOUSE_SENSITIVITY,
			Balance.PREVIEW_MIN_PITCH, Balance.PREVIEW_MAX_PITCH)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(Balance.PREVIEW_MIN_DISTANCE, distance - Balance.PREVIEW_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(Balance.PREVIEW_MAX_DISTANCE, distance + Balance.PREVIEW_ZOOM_STEP)
	for i in range(3):
		if event.is_action_pressed("preview_view_%d" % i):
			_set_view(i)

func _set_view(index: int) -> void:
	var targets := [Balance.PREVIEW_TARGET, Balance.PREVIEW_HOUSE_TARGET, Balance.PREVIEW_DOCK_TARGET]
	var distances := [Balance.PREVIEW_DISTANCE, Balance.PREVIEW_HOUSE_DISTANCE, Balance.PREVIEW_DOCK_DISTANCE]
	target = targets[index]
	distance = distances[index]
	yaw = Balance.PREVIEW_YAW
	pitch = Balance.PREVIEW_PITCH
	view_label.text = ["01 / LA RIVA", "02 / IL RIFUGIO", "03 / IL PONTILE"][index]
	for i in range(view_buttons.size()):
		view_buttons[i].modulate = ACCENT if i == index else Color.WHITE
	_update_camera()

func _style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _label(text: String, size: int, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_stylebox_override("normal", _style(Color("203c40"), Color("45605c")))
	button.add_theme_stylebox_override("hover", _style(Color("35504b"), ACCENT))
	button.add_theme_stylebox_override("pressed", _style(Color("425b42"), ACCENT))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), ACCENT))
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", PAPER)
	button.pressed.connect(callback)
	return button

func _build_interface() -> void:
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface.add_child(root_ui)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	root_ui.theme = theme
	var masthead := _label("T /   TESTE     ·     STUDIO DEL MONDO", 18, ACCENT)
	masthead.position = Vector2(42, 28)
	root_ui.add_child(masthead)
	var phase := _label("FASE 00     /     STUDIO DEL MONDO", 16)
	phase.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	phase.position = Vector2(-360, 28)
	root_ui.add_child(phase)
	var panel := PanelContainer.new()
	panel.position = Vector2(42, 108)
	panel.custom_minimum_size = Vector2(338, 0)
	panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.12, 0.14, 0.94), Color("355253")))
	root_ui.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 13)
	panel.add_child(stack)
	stack.add_child(_label("UN RIFUGIO NEL MONDO DEGLI INFETTI.", 14, ACCENT))
	stack.add_child(_label("TESTE", 78))
	stack.add_child(_label("IL RIFUGIO", 23, ACCENT))
	stack.add_child(HSeparator.new())
	var premise := _label("Esplora il mondo.\nAffronta gli infetti.\nTorna al rifugio.", 23)
	stack.add_child(premise)
	var scope := _label("Anteprima del mondo in Godot.\nRifugio, bosco e pontile esplorabili\ncon la camera di osservazione.", 17, MUTED)
	stack.add_child(scope)
	stack.add_child(_label("CAMERA DI OSSERVAZIONE", 13, ACCENT))
	for i in range(3):
		var button := _button(["01   La riva                     F6", "02   Il rifugio                  F7", "03   Il pontile                  F8"][i], _set_view.bind(i))
		view_buttons.append(button)
		stack.add_child(button)
	stack.add_child(_button("Comandi e stato del progetto   F1", _toggle_help))
	stack.add_child(_label("PERSONAGGIO E COMBATTIMENTO\nIN ARRIVO NELLE PROSSIME FASI", 12, MUTED))
	view_label = _label("", 17, PAPER)
	view_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	view_label.position = Vector2(-240, -124)
	root_ui.add_child(view_label)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 42
	bottom.offset_right = -42
	bottom.offset_top = -98
	bottom.offset_bottom = -24
	bottom.add_theme_stylebox_override("panel", _style(Color(0.04, 0.12, 0.14, 0.96), Color("355253")))
	root_ui.add_child(bottom)
	var rows := VBoxContainer.new()
	bottom.add_child(rows)
	rows.add_child(_label("MOUSE DESTRO + TRASCINA  Orbita     /     ROTELLA  Zoom     /     STICK DESTRO  Orbita     /     ESC  Menu", 16))
	input_label = _label("TEST INPUT  /  Premi WASD, E, Q o un comando del gamepad: qui vedrai l'azione rilevata.", 14, ACCENT)
	rows.add_child(input_label)
	help_panel = _overlay("COMANDI / FASE 0", "Ora puoi ruotare la camera, cambiare vista e verificare gli input.\nWASD e gli altri comandi vengono rilevati, ma non muovono un giocatore.\n\nCONTROLLI PREDISPOSTI PER LE PROSSIME FASI\nWASD / stick sinistro: movimento   ·   Shift / L3: sprint\nSpazio o Ctrl / B: schivata   ·   E / A: interazione\nMouse sinistro / RT: attacco   ·   Mouse destro / LT: mira\nR / X: ricarica   ·   Q / D-pad su: cura   ·   F / Y: veicolo\n1–5: armi   ·   LB / RB: arma precedente / successiva\nTab / Back: inventario   ·   M / D-pad giù: mappa\nEsc / Start: menu   ·   F1: questa guida\n\nNon sono ancora attivi pesca, nemici, economia, salvataggi o audio.\nLa casa, la barca e lo zombie sono elementi statici di prova.")
	help_panel.get_child(0).add_child(_button("Torna all'anteprima", _toggle_help))
	escape_panel = _overlay("ANTEPRIMA IN PAUSA", "TESTE · Acque morte\nFase 0: configurazione e ambiente di prova.\n\nIl progetto completo si sviluppa nelle fasi successive.")
	escape_panel.get_child(0).add_child(_button("Riprendi", func() -> void:
		escape_panel.hide()
		input_active = not help_panel.visible))
	escape_panel.get_child(0).add_child(_button("Esci", func() -> void: get_tree().quit()))

func _overlay(title: String, body: String) -> PanelContainer:
	var panel := PanelContainer.new()
	root_ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -310
	panel.offset_bottom = 310
	panel.add_theme_stylebox_override("panel", _style(Color("10282d"), ACCENT))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	panel.add_child(rows)
	rows.add_child(_label(title, 26, ACCENT))
	rows.add_child(_label(body, 19))
	panel.hide()
	return panel

func _toggle_help() -> void:
	help_panel.visible = not help_panel.visible
	escape_panel.hide()
	input_active = not help_panel.visible

func _verify_setup() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var errors: PackedStringArray = []
	for service in ["GameState", "EconomyManager", "SaveManager", "AudioManager", "TimeManager"]:
		if get_node_or_null("/root/" + service) == null:
			errors.append("Autoload assente: " + service)
	for action in ["move_forward", "move_back", "move_left", "move_right", "attack", "aim", "interact", "sprint", "dodge", "reload", "heal", "vehicle", "inventory", "map", "pause", "weapon_1", "weapon_5"]:
		if not InputMap.has_action(action) or InputMap.action_get_events(action).is_empty():
			errors.append("Input assente: " + action)
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 5, 0), Vector3(0, -5, 0), 1)
	if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		errors.append("Collisione del terreno assente")
	for i in range(3):
		_set_view(i)
		if not camera.position.is_finite():
			errors.append("Camera non valida")
	_toggle_help()
	if not help_panel.visible or input_active:
		errors.append("Apertura guida non valida")
	_toggle_help()
	if help_panel.visible or not input_active:
		errors.append("Chiusura guida non valida")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	event.pressed = true
	get_viewport().push_input(event)
	if not input_label.text.contains("interact"):
		errors.append("Il tasto E non raggiunge il monitor input")
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	get_viewport().push_input(release)
	if errors.is_empty():
		print("FASE 0: PASS — autoload, input, collisione terreno, tre camere e guida.")
		get_tree().quit(0)
	else:
		for message in errors:
			push_error(message)
		get_tree().quit(1)

func _capture(path: String) -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("Anteprima salvata: ", path, " | esito: ", error)
	get_tree().quit(error)
