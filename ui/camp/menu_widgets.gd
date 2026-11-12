# Base del CampMenu: costanti, stato e controlli riutilizzabili (pulsanti a cornice, pannelli, righe).
# Le pagine stanno in menu.gd, che estende questo file.
extends Control
const MenuChoice := preload("res://ui/camp/menu_choice.gd")
const TYPE := preload("res://art/fonts/BarlowCondensed-Regular.ttf")
const DISPLAY := preload("res://art/fonts/BarlowCondensed-SemiBold.ttf")
const LOGO_TEXTURE := "res://art/zx_logo/T_ZX_Logo.png"
const FRAME := Color("ece6d6")
const TEXT := Color("ece6d6")
const MUTED := Color(0.70,0.72,0.67,0.85)
const ACCENT := Color("ffb703")
const PANEL_BG := Color(0.03,0.045,0.04,0.66)
const ROW_BG := Color(0.02,0.025,0.025,0.72)
const TABS := [["game","GAME"],["graphics","GRAPHICS"],["audio","AUDIO"],["controls","CONTROLS"],["language","LANGUAGE"]]
const KEYS := [["WASD","Move"],["MOUSE","First-person look"],["SHIFT","Sprint"],["SPACE","Jump"],["CTRL (hold)","Crouch"],["CLICK / HOLD","Strike / charged strike"],["E","Collect / activate"],["ESC","Pause menu"]]
const CREDITS := [["A GAME BY","The ZOMBIX HEAD team"],["ENGINE","Godot Engine 4.5 · MIT license"],["FONT","Barlow Condensed · SIL Open Font License 1.1"],["ART","Original models and textures, CC0 assets"],["SOUND","CC0 sound libraries"],["THANKS","Everyone who sat by the fire and tested the camp"]]
var world: Node3D
var page: String = "home"
var tab: String = "game"
var page_root: Control
var menu_list: VBoxContainer
var status_label: Label
var version_label: Label
var roster_label: Label
var ready_button: Button
var context_label: Label
var entries: Array[Button] = []
var graphics_controls: Dictionary = {}
var graphics_pending: Dictionary = {}
var graphics_status: Label
var graphics_dirty := false
var page_tween: Tween
var click_sound: AudioStreamPlayer
var hover_sound: AudioStreamPlayer
var connection_hosting: bool = true
var keyboard_nav := false
## Etichetta in basso a destra (versione, stato della sessione).
func _corner_label(node_name: String, top: float, color: Color) -> Label:
	var node := _text(self,"",Vector2.ZERO,17,color)
	node.name = node_name
	node.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	node.offset_left = -720
	node.offset_right = -30
	node.offset_top = top
	node.offset_bottom = top+26
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	node.clip_text = true
	return node

func clear(title: String, centered: bool = false) -> void:
	ready_button = null
	roster_label = null
	graphics_status = null
	menu_list = null
	entries.clear()
	graphics_controls.clear()
	if page_tween: page_tween.kill()
	for child in page_root.get_children():
		page_root.remove_child(child)
		child.queue_free()
	if title == "ZOMBIX HEAD" and ResourceLoader.exists(LOGO_TEXTURE):
		var art := TextureRect.new()
		art.name = "ZombixLogo"
		art.texture = load(LOGO_TEXTURE)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.position = Vector2(34,26)
		art.size = Vector2(600,288)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		page_root.add_child(art)
	elif centered:
		var heading := _text(page_root,title,Vector2.ZERO,64,TEXT)
		heading.name = "Title"
		heading.add_theme_font_override("font",DISPLAY)
		heading.set_anchors_preset(Control.PRESET_CENTER_TOP)
		heading.offset_left = -400
		heading.offset_right = 400
		heading.offset_top = 26
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var heading := _text(page_root,"ZOMBIX" if title == "ZOMBIX HEAD" else title,Vector2(60,40),104,TEXT)
		heading.name = "Title"
		heading.add_theme_font_override("font",DISPLAY)
		heading.add_theme_constant_override("shadow_offset_y",5)
	version_label.text = Localization.t("VERSION {0}",[ProjectSettings.get_setting("application/config/version")]) if page == "home" else ""
	page_root.modulate.a = 0
	page_tween = create_tween()
	page_tween.tween_property(page_root,"modulate:a",1.0,0.18).set_trans(Tween.TRANS_SINE)

func _text(parent: Node, value: String, at: Vector2, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = Localization.t(value)
	node.position = at
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.add_theme_color_override("font_shadow_color",Color(0.02,0.025,0.02,0.9))
	node.add_theme_constant_override("shadow_offset_y",2)
	parent.add_child(node)
	return node

func label(value: String, at: Vector2, font_size: int, color: Color = TEXT) -> Label:
	return _text(page_root,value,at,font_size,color)

func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.content_margin_left = 14
	box.content_margin_right = 14
	return box

## Pulsante a cornice chiara: hover e focus accendono bordo e testo ambra.
func button(title: String, callback: Callable, parent: Node = null, width: float = 300.0, height: float = 52.0) -> Button:
	var node := Button.new()
	node.name = title.to_pascal_case()
	node.text = Localization.t(title)
	node.custom_minimum_size = Vector2(width,height)
	node.focus_mode = Control.FOCUS_ALL
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font",DISPLAY)
	node.add_theme_font_size_override("font_size",27 if height >= 50 else 22)
	node.add_theme_stylebox_override("normal",_box(Color(0.02,0.03,0.03,0.38),Color(FRAME,0.9),2))
	node.add_theme_stylebox_override("hover",_box(Color(0.93,0.90,0.82,0.16),ACCENT,2))
	node.add_theme_stylebox_override("pressed",_box(Color(1,0.72,0.1,0.28),ACCENT,2))
	node.add_theme_stylebox_override("focus",_box(Color(0,0,0,0),ACCENT,3))
	node.add_theme_stylebox_override("disabled",_box(Color(0.02,0.03,0.03,0.25),Color(FRAME,0.3),2))
	node.add_theme_color_override("font_color",TEXT)
	for state in ["font_hover_color","font_focus_color","font_hover_pressed_color"]: node.add_theme_color_override(state,ACCENT)
	node.add_theme_color_override("font_pressed_color",Color.WHITE)
	node.add_theme_color_override("font_disabled_color",Color(MUTED,0.4))
	node.mouse_entered.connect(func() -> void:
		if hover_sound and not node.disabled: hover_sound.play())
	node.pressed.connect(func() -> void:
		if click_sound:
			click_sound.pitch_scale = randf_range(0.93,1.06)
			click_sound.play()
		callback.call_deferred())
	(parent if parent else _menu_container()).add_child(node)
	entries.append(node)
	return node

## Colonna dei pulsanti in basso a sinistra.
func _menu_container() -> VBoxContainer:
	if not menu_list:
		menu_list = VBoxContainer.new()
		menu_list.name = "MenuList"
		menu_list.add_theme_constant_override("separation",12)
		menu_list.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		menu_list.offset_left = 60
		menu_list.offset_bottom = -46
		menu_list.grow_vertical = Control.GROW_DIRECTION_BEGIN
		page_root.add_child(menu_list)
	return menu_list

## Riga orizzontale dentro la colonna (es. PRECEDENTE / SUCCESSIVO).
func button_row(separation: int = 12) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ButtonRow"
	row.add_theme_constant_override("separation",separation)
	_menu_container().add_child(row)
	return row

## Indietro in basso a destra, con il tasto che lo richiama.
func back_button(callback: Callable) -> Button:
	var node := button("[Esc]  BACK",callback,page_root,230,52)
	node.name = "Back"
	node.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	node.offset_left = -290
	node.offset_right = -60
	node.offset_top = -98
	node.offset_bottom = -46
	return node

func _focus_first(preferred: Control = null) -> void:
	if not keyboard_nav or entries.is_empty(): return
	var target: Control = preferred if preferred else entries[0]
	target.grab_focus.call_deferred()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: keyboard_nav = false
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion: keyboard_nav = true

## Pannello semitrasparente con cornice chiara, centrato in orizzontale.
func _panel(size_px: Vector2, top: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -size_px.x/2
	panel.offset_right = size_px.x/2
	panel.offset_top = top
	panel.offset_bottom = top+size_px.y
	var box := _box(PANEL_BG,Color(FRAME,0.85),2)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel",box)
	page_root.add_child(panel)
	return panel

func _section(parent: Control, title: String) -> void:
	var node := _text(parent,title,Vector2.ZERO,32,TEXT)
	node.add_theme_font_override("font",DISPLAY)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.custom_minimum_size.y = 50

## Riga scura a tutta larghezza: etichetta maiuscola a sinistra, controllo a destra.
func _row(parent: Control, title: String) -> HBoxContainer:
	var panel := PanelContainer.new()
	var box := _box(ROW_BG,Color(0,0,0,0),0)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel",box)
	panel.custom_minimum_size.y = 46
	parent.add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var name_label := _text(row,title,Vector2.ZERO,20,TEXT)
	name_label.add_theme_font_override("font",DISPLAY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return row

func _choice(parent: Control, title: String, items: Array, selected: int, callback: Callable, key: String) -> MenuChoice:
	var control := MenuChoice.new()
	control.name = key.to_pascal_case()
	for item in items: control.add_item(Localization.t(str(item)))
	control.select(selected)
	control.item_selected.connect(callback)
	_row(parent,title).add_child(control)
	graphics_controls[key] = control
	return control

func _slider(parent: Control, title: String, key: String, minimum: float, maximum: float, step: float, format: String) -> HSlider:
	var row := _row(parent,title)
	var value := _text(row,format % float(world.settings_data[key]),Vector2.ZERO,20,TEXT)
	value.custom_minimum_size.x = 70
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var control := HSlider.new()
	control.name = key.to_pascal_case()
	control.custom_minimum_size = Vector2(420,30)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = float(world.settings_data[key])
	control.add_theme_stylebox_override("focus",_box(Color(0,0,0,0),ACCENT,2))
	row.add_child(control)
	control.value_changed.connect(func(v: float) -> void:
		world.settings_data[key] = v
		value.text = format % v
		world._apply_settings())
	graphics_controls[key] = control
	return control
