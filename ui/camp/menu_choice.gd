# Scelte in fila a destra di una riga delle opzioni: quella attiva è evidenziata.
# Stessa interfaccia minima di OptionButton (selected, item_count, select, item_selected).
# Un solo punto di focus per riga: sinistra/destra cambiano la scelta (tastiera e controller).
extends HBoxContainer
signal item_selected(index: int)
const ACTIVE := Color("f1ead8")
const IDLE := Color(0.62,0.64,0.60,0.75)
const ACCENT := Color("ffb703")
var selected: int = 0
var item_count: int:
	get: return _items.size()
var _items: Array[Button] = []


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 26)
	focus_entered.connect(_paint)
	focus_exited.connect(_paint)
	mouse_entered.connect(_paint)
	mouse_exited.connect(_paint)


func add_item(text: String) -> void:
	var item := Button.new()
	item.text = text
	item.flat = true
	item.focus_mode = Control.FOCUS_NONE
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_font_size_override("font_size", 19)
	var index := _items.size()
	item.pressed.connect(func() -> void:
		grab_focus()
		_choose(index))
	add_child(item)
	_items.append(item)
	_paint()


func get_item_text(index: int) -> String:
	return _items[index].text


func select(index: int) -> void:
	selected = clampi(index, 0, maxi(_items.size()-1, 0))
	_paint()


func _choose(index: int) -> void:
	if index == selected: return
	select(index)
	item_selected.emit(selected)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_choose(posmod(selected-1, _items.size()))
		accept_event()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		_choose(posmod(selected+1, _items.size()))
		accept_event()


func _paint() -> void:
	var hot := has_focus()
	for i in _items.size():
		var color := ACTIVE if i == selected else IDLE
		if i == selected and hot: color = ACCENT
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_items[i].add_theme_color_override(state, color if state == "font_color" else ACCENT)
		_items[i].add_theme_font_override("font", preload("res://art/fonts/BarlowCondensed-SemiBold.ttf") if i == selected else preload("res://art/fonts/BarlowCondensed-Regular.ttf"))
