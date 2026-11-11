# Nodo Button dentro un Control ButtonSlot, ospitato dal VBoxContainer del menu.
# Nessuna texture di pannello: testo nativo, focus accessibile e accento disegnato.
extends Button
signal highlighted(description: String)
signal unhighlighted
const MUTED := Color(0.72,0.76,0.72,0.84)
const AMBER := Color("ffb703")
const PRESS := Color("ff6b00")
var description: String = ""
var hover_amount: float = 0
var press_amount: float = 0
var pointer_inside: bool = false
var held: bool = false
var fire_clock: float = 0
var selected: bool = false
var base_position := Vector2.ZERO

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	add_theme_font_override("font",preload("res://art/fonts/BarlowCondensed-SemiBold.ttf"))
	add_theme_font_size_override("font_size",31)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 29
		add_theme_stylebox_override(state,empty)
	add_theme_color_override("font_shadow_color",Color(0.02,0.01,0.0,0.85))
	add_theme_constant_override("shadow_offset_x",1)
	add_theme_constant_override("shadow_offset_y",3)
	mouse_entered.connect(func() -> void: pointer_inside=true; highlighted.emit(description))
	mouse_exited.connect(func() -> void:
		pointer_inside=false
		if not has_focus(): unhighlighted.emit())
	focus_entered.connect(func() -> void: highlighted.emit(description))
	focus_exited.connect(func() -> void:
		if not pointer_inside: unhighlighted.emit())
	button_down.connect(func() -> void: held=true)
	button_up.connect(func() -> void: held=false)
	base_position = position

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	fire_clock += delta
	var target := 1.0 if not disabled and (pointer_inside or has_focus() or selected) else 0.0
	hover_amount = lerpf(hover_amount,target,1.0-exp(-delta*12))
	press_amount = lerpf(press_amount,1.0 if held else 0.0,1.0-exp(-delta*24))
	position = base_position+Vector2(hover_amount*11+press_amount*2,press_amount*1.5)
	scale = Vector2.ONE*(1.0-press_amount*0.025)
	var color := MUTED.lerp(AMBER,hover_amount).lerp(PRESS,press_amount)
	if disabled: color = Color(0.55,0.6,0.58,0.34)
	color = color.lerp(Color("ffe5b0"),hover_amount*(0.04+0.025*sin(fire_clock*8)))
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_disabled_color"]: add_theme_color_override(state,color)
	add_theme_color_override("font_outline_color",Color(1,0.30,0.015,hover_amount*0.15))
	add_theme_constant_override("outline_size",3)
	queue_redraw()

func _draw() -> void:
	if hover_amount<0.01: return
	var center := Vector2(8,size.y*0.5)
	for i in range(4,0,-1): draw_circle(center,3+i*2.0,Color(1,0.35,0.02,hover_amount*0.025))
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-5),center+Vector2(3,0),center+Vector2(0,5),center+Vector2(-3,0)]),Color(1,0.68,0.17,hover_amount))
	draw_line(Vector2(29,size.y-4),Vector2(29+110*hover_amount,size.y-4),Color(1,0.56,0.12,hover_amount*0.28),1,true)
