extends Control
# Pulsante VENDI dallo sceriffo, con la testa in mano: tasto [V] disegnato, prezzo di una testa, e se ne hai più d'una
# quante e il totale dello stack in mano (barra che si riempie tenendo premuto). "+25 CREDITI" sale e sfuma quando l'host paga.

const C_LINE := Color("d4a56c")
var rules: Node3D
var button: Button
var fill: ColorRect


func build(owner_rules: Node3D) -> void:
	rules = owner_rules
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -170.0
	offset_right = 170.0
	offset_top = -214.0
	offset_bottom = -132.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.text = Localization.t("[V]  VENDI")
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", C_LINE)
	button.add_theme_color_override("font_hover_color", Color("ffe2b0"))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.05, 0.05, 0.82)
	box.border_color = C_LINE
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, box)
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	button.pressed.connect(func() -> void: rules.press_sell())
	fill = ColorRect.new()
	fill.color = Color(C_LINE.r, C_LINE.g, C_LINE.b, 0.9)
	fill.anchor_top = 1.0
	fill.anchor_bottom = 1.0
	fill.offset_top = -5.0
	fill.offset_bottom = -2.0
	fill.offset_left = 3.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	hide()


func _process(_delta: float) -> void:
	visible = rules.sell_ready()
	if visible:
		fill.offset_right = 3.0 + (size.x - 6.0) * clampf(rules.sell_hold, 0.0, 1.0)
		var id: String = rules.world.player.equipped
		var n: int = int(rules.world.player.items.get(id, 0))
		var price: int = ItemInfo.head_price(id)
		if rules.sell_wait > 0:
			button.text = Localization.t("LO SCERIFFO CONTA...")
		elif n > 1:
			button.text = Localization.t("[V]  VENDI 1  ·  {0} CREDITI\nTIENI [V]: TUTTE QUESTE ×{1}  ·  {2} CREDITI", [price, n, price * n])
		else:
			button.text = Localization.t("[V]  VENDI  ·  {0} CREDITI", [price])


## "+25 CREDITI" che sale e sfuma sopra il pulsante.
func pop(amount: int) -> void:
	var label := Label.new()
	label.text = Localization.t("+{0} CREDITI", [amount])
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("ffe2b0"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	get_parent().add_child(label)
	label.position = Vector2(global_position.x + 90.0, global_position.y - 34.0)
	var tw := label.create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 60.0, 1.1)
	tw.tween_property(label, "modulate:a", 0.0, 1.1)
	tw.chain().tween_callback(label.queue_free)
