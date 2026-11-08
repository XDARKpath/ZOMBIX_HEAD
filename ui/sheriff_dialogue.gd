extends Control
# Dialogo con gli NPC in stile gioco: fumetto arrotondato in vetro con il nome su una
# targhetta, testo che si scrive lettera per lettera, risposte come bolle che compaiono
# a fine frase e una freccia che invita a continuare. Niente etichette di servizio:
# i tasti sono indicati da piccoli tasti disegnati.
# survival_rules.gd chiama set_line/set_choices e skip() prima di avanzare.
signal choice_selected(index: int)

const C_BONE := Color("efe8d8")
const C_SAGE := Color("a9b8ae")
const C_BRASS := Color("e0b06a")
const C_INK := Color("15191a")
const CHARS_PER_SECOND := 48.0
const WIDTH := 860.0

const DEFAULT_CHOICES:Array[String] = ["Chi sono i custodi?","Come si taglia una testa?","Torno dopo."]

var box:PanelContainer
var name_tag:PanelContainer
var name_label:Label
var text_label:Label
var page_label:Label   # compatibilità: contiene "n / tot", disegnato come puntini
var hint_label:Label   # compatibilità: contiene il suggerimento, disegnato come tasto
var choice_box:VBoxContainer
var buttons:Array[Button] = []
var marker:Control
var built := false
var typing := false
var shown_chars := 0.0
var page := 0
var pages := 1
var clock := 0.0
var font:Font
var bold:Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build()
	visibility_changed.connect(func(): if visible: _pop_in())

func build() -> void:
	if built:
		return
	built = true
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Bahnschrift","Segoe UI"])
	font = system
	var heavy := FontVariation.new()
	heavy.base_font = system
	heavy.variation_embolden = 0.6
	bold = heavy
	var theme_value := Theme.new()
	theme_value.default_font = font
	theme_value.default_font_size = 16
	theme = theme_value
	# Fumetto principale
	box = PanelContainer.new()
	box.name = "DialoguePanel"
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -WIDTH*0.5
	box.offset_right = WIDTH*0.5
	box.offset_top = -176
	box.offset_bottom = -40
	box.add_theme_stylebox_override("panel",_style(Color(0,0,0,0),Color(0.88,0.69,0.42,0.55),24,2))
	add_child(box)
	preload("res://ui/glass/surface.gd").add(box,0.5,false,24.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",34)
	margin.add_theme_constant_override("margin_right",34)
	margin.add_theme_constant_override("margin_top",30)
	margin.add_theme_constant_override("margin_bottom",24)
	box.add_child(margin)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.add_theme_font_size_override("font_size",21)
	text_label.add_theme_constant_override("line_spacing",7)
	text_label.add_theme_color_override("font_color",C_BONE)
	text_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.35))
	text_label.add_theme_constant_override("shadow_offset_y",1)
	margin.add_child(text_label)
	# Targhetta con il nome, a cavallo del bordo superiore
	name_tag = PanelContainer.new()
	name_tag.add_theme_stylebox_override("panel",_style(C_BRASS,Color(1,0.9,0.7,0.6),16,1,18,6))
	name_tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	name_tag.grow_horizontal = Control.GROW_DIRECTION_END
	name_tag.offset_left = -WIDTH*0.5+30
	name_tag.offset_right = -WIDTH*0.5+30
	name_tag.offset_top = -176-17
	name_tag.offset_bottom = -176+17
	add_child(name_tag)
	name_label = Label.new()
	name_label.text = Localization.t("SCERIFFO")
	name_label.add_theme_font_override("font",bold)
	name_label.add_theme_font_size_override("font_size",16)
	name_label.add_theme_color_override("font_color",C_INK)
	name_tag.add_child(name_label)
	# Freccia "continua" e puntini di pagina disegnati
	marker = Control.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	marker.offset_left = -WIDTH*0.5
	marker.offset_right = WIDTH*0.5
	marker.offset_top = -176
	marker.offset_bottom = -40
	marker.draw.connect(_draw_marker)
	add_child(marker)
	page_label = Label.new()
	page_label.visible = false
	add_child(page_label)
	hint_label = Label.new()
	hint_label.visible = false
	add_child(hint_label)
	# Risposte: bolle impilate sopra il fumetto, a destra
	choice_box = VBoxContainer.new()
	choice_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	choice_box.offset_left = WIDTH*0.5-330
	choice_box.offset_right = WIDTH*0.5
	choice_box.offset_top = -344
	choice_box.offset_bottom = -192
	choice_box.alignment = BoxContainer.ALIGNMENT_END
	choice_box.add_theme_constant_override("separation",8)
	add_child(choice_box)
	for i in range(DEFAULT_CHOICES.size()):
		var choice := _make_button(i,DEFAULT_CHOICES[i])
		choice_box.add_child(choice)
		buttons.append(choice)

func _style(fill:Color,border:Color,radius:int,width:int,pad_x:int=0,pad_y:int=0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.corner_detail = 10
	style.anti_aliasing = true
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	return style

func _make_button(index:int,label_text:String) -> Button:
	var button := Button.new()
	button.text = Localization.t(label_text)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0,42)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_color_override("font_color",C_BONE)
	button.add_theme_color_override("font_hover_color",C_INK)
	button.add_theme_color_override("font_pressed_color",C_INK)
	var normal := _style(Color(0.05,0.09,0.09,0.55),Color(0.88,0.69,0.42,0.35),21,1,0,0)
	normal.content_margin_left = 52
	normal.content_margin_right = 18
	var hover := _style(C_BRASS,Color(1,0.9,0.7,0.8),21,1,0,0)
	hover.content_margin_left = 52
	hover.content_margin_right = 18
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",hover)
	button.add_theme_stylebox_override("focus",normal)
	# Tastino numerato a sinistra della bolla
	var key := Label.new()
	key.text = str(index+1)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.position = Vector2(10,8)
	key.size = Vector2(28,26)
	key.add_theme_font_override("font",bold)
	key.add_theme_font_size_override("font_size",14)
	key.add_theme_color_override("font_color",C_INK)
	key.add_theme_stylebox_override("normal",_style(C_BRASS,Color(0,0,0,0),8,0))
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(key)
	preload("res://ui/glass/surface.gd").hover(button)
	button.pressed.connect(_choose.bind(index))
	return button

func _choose(index:int) -> void:
	choice_selected.emit(index)

func set_speaker(value:String) -> void:
	if not built: build()
	name_label.text = Localization.t(value.to_upper())

func set_line(value:String,page_text:String,hint_text:String) -> void:
	if not built:
		build()
	text_label.text = Localization.t(value)
	page_label.text = page_text
	hint_label.text = Localization.t(hint_text)
	var parts := page_text.split("/")
	if parts.size() == 2:
		page = int(parts[0].strip_edges())-1
		pages = maxi(1,int(parts[1].strip_edges()))
	shown_chars = 0.0
	typing = true
	text_label.visible_characters = 0
	_show_choices(false)

func set_choices(labels:Array) -> void:
	if not built:
		build()
	for i in range(mini(labels.size(),buttons.size())):
		buttons[i].text = Localization.t(str(labels[i]))

## Se la frase si sta ancora scrivendo la completa e restituisce true.
func skip() -> bool:
	if not typing: return false
	shown_chars = text_label.text.length()
	_finish()
	return true

func _finish() -> void:
	typing = false
	text_label.visible_characters = -1
	_show_choices(true)

func _show_choices(value:bool) -> void:
	for i in buttons.size():
		var b := buttons[i]
		if not value:
			b.modulate.a = 0.0
			b.disabled = true
			continue
		b.disabled = false
		b.create_tween().tween_property(b,"modulate:a",1.0,0.18).set_delay(i*0.07)

func _pop_in() -> void:
	box.pivot_offset = Vector2(WIDTH*0.5,box.size.y)
	box.scale = Vector2(0.96,0.96)
	box.position.y += 18
	var tween := box.create_tween().set_parallel(true)
	tween.tween_property(box,"scale",Vector2.ONE,0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(box,"position:y",box.position.y-18,0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process(delta:float) -> void:
	if not visible: return
	clock += delta
	if typing:
		shown_chars += delta*CHARS_PER_SECOND
		text_label.visible_characters = int(shown_chars)
		if shown_chars >= text_label.text.length(): _finish()
	marker.queue_redraw()

func _draw_marker() -> void:
	var s := marker.size
	# puntini di pagina in basso a sinistra
	if pages > 1:
		for i in pages:
			var c := Vector2(36+i*14,s.y-16)
			marker.draw_circle(c,3.6 if i == page else 2.6,C_BRASS if i == page else Color(1,1,1,0.22))
	if typing: return
	# tasto E e freccia che rimbalza in basso a destra
	var bob := sin(clock*5.0)*3.0
	var tip := Vector2(s.x-34,s.y-14+bob)
	marker.draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-8,-10),tip+Vector2(8,-10)]),C_BRASS)
	var key := Rect2(s.x-82,s.y-34,24,24)
	marker.draw_style_box(_style(Color(1,1,1,0.10),Color(0.88,0.69,0.42,0.6),7,1),key)
	marker.draw_string(bold,key.position+Vector2(7,17),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,13,C_BRASS)
