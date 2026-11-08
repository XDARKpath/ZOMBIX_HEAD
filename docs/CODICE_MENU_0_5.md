# ZOMBIX HEAD 0.5 — script completi del menu

Questi file sono già applicati al progetto Godot incluso.

## ui/camp/fire_button.gd

```gdscript
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
```

## ui/camp/menu.gd

```gdscript
# CampMenu (Control) sotto Interface/CanvasLayer; costruisce UI nativa e riutilizzabile.
extends Control
const FireButton := preload("res://ui/camp/fire_button.gd")
const TYPE := preload("res://art/fonts/BarlowCondensed-Regular.ttf")
const DISPLAY := preload("res://art/fonts/BarlowCondensed-SemiBold.ttf")
var world: Node3D
var page: String = "home"
var page_root: Control
var menu_list: VBoxContainer
var status_label: Label
var roster_label: Label
var ready_button: Button
var context_label: Label
var entries: Array[Button] = []
var page_tween: Tween
var context_tween: Tween
var click_sound: AudioStreamPlayer
var hover_sound: AudioStreamPlayer

func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "CampMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := Theme.new()
	style.default_font = TYPE
	style.default_font_size = 22
	theme = style
	var veil := ColorRect.new()
	veil.name = "ForestVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://ui/camp/menu_veil.gdshader")
	veil.material = material
	add_child(veil)
	page_root = Control.new()
	page_root.name = "Page"
	page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page_root)
	var version := _text(self,"BUILD 0.5  /  LAGO CENERE",Vector2.ZERO,15,Color(0.69,0.78,0.75,0.65))
	version.name = "BuildBadge"
	version.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	version.position = Vector2(1080,38)
	version.size.x = 280
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var badge := _text(self,"CO-OP  /  UP TO 4 PLAYERS",Vector2(79,852),15,Color(0.69,0.78,0.75,0.65))
	badge.name = "CoopBadge"
	status_label = _text(self,"",Vector2(560,852),15,Color("b0bdb2"))
	status_label.name = "SessionStatus"
	status_label.size.x = 800
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.clip_text = true
	var embers := Control.new()
	embers.name = "ForegroundEmbers"
	embers.set_script(preload("res://ui/camp/menu_embers.gd"))
	add_child(embers)
	if DisplayServer.get_name()!="headless":
		click_sound = AudioStreamPlayer.new()
		click_sound.name = "WoodPress"
		click_sound.stream = preload("res://audio/menu_press.wav")
		click_sound.volume_db = -12
		add_child(click_sound)
		hover_sound = AudioStreamPlayer.new()
		hover_sound.name = "EmberHover"
		hover_sound.stream = preload("res://audio/menu_hover.wav")
		hover_sound.volume_db = -24
		add_child(hover_sound)
	Session.status_changed.connect(func(_message: String) -> void: refresh())
	home()

func clear(title: String, subtitle: String = "") -> void:
	ready_button = null
	roster_label = null
	context_label = null
	menu_list = null
	entries.clear()
	if page_tween: page_tween.kill()
	if context_tween: context_tween.kill()
	for child in page_root.get_children():
		page_root.remove_child(child)
		child.queue_free()
	var titles := VBoxContainer.new()
	titles.name = "TitleBlock"
	titles.position = Vector2(78,57)
	titles.size.x = 360
	titles.add_theme_constant_override("separation",-9)
	page_root.add_child(titles)
	if title == "ZOMBIX HEAD":
		var logo := _text(titles,"ZOMBIX",Vector2.ZERO,96,Color("e7dfcc"))
		logo.name = "ZombixWordmark"
		logo.add_theme_font_override("font",DISPLAY)
		logo.add_theme_constant_override("shadow_offset_x",3)
		logo.add_theme_constant_override("shadow_offset_y",5)
		var ink := ShaderMaterial.new()
		ink.shader = preload("res://ui/camp/logo_ink.gdshader")
		logo.material = ink
		var head := _text(titles,"H E A D",Vector2.ZERO,42,Color("c7a579"))
		head.name = "HeadWordmark"
		head.add_theme_font_override("font",DISPLAY)
		head.material = ink
	else:
		var heading := _text(titles,title,Vector2.ZERO,64 if title.length()<12 else 51,Color("e7dfcc"))
		heading.add_theme_font_override("font",DISPLAY)
	if not subtitle.is_empty(): label(subtitle,Vector2(81,220),15,Color(0.76,0.69,0.57,0.78))
	context_label = label("",Vector2(109,755),20,Color("c2b39b"))
	context_label.name = "ContextHint"
	context_label.size = Vector2(350,66)
	context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_label.modulate.a = 0
	page_root.modulate.a = 0
	page_tween = create_tween()
	page_tween.tween_property(page_root,"modulate:a",1.0,0.22).set_trans(Tween.TRANS_SINE)

func _text(parent: Node, value: String, at: Vector2, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = value
	node.position = at
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.add_theme_color_override("font_shadow_color",Color(0.02,0.025,0.02,0.9))
	node.add_theme_constant_override("shadow_offset_y",2)
	parent.add_child(node)
	return node

func label(value: String, at: Vector2, font_size: int, color: Color = Color("d4d6c9")) -> Label:
	return _text(page_root,value,at,font_size,color)

func button(title: String, _y: float, callback: Callable, description: String = "") -> Button:
	if not menu_list:
		menu_list = VBoxContainer.new()
		menu_list.name = "MenuList"
		menu_list.position = Vector2(78,294)
		menu_list.size.x = 370
		menu_list.add_theme_constant_override("separation",9)
		page_root.add_child(menu_list)
	var slot := Control.new()
	slot.name = "ButtonSlot%d" % entries.size()
	slot.custom_minimum_size = Vector2(370,51)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_list.add_child(slot)
	var node := Button.new()
	node.set_script(FireButton)
	node.name = title.to_pascal_case()
	node.text = title
	node.description = description
	node.size = Vector2(350,51)
	slot.add_child(node)
	entries.append(node)
	node.highlighted.connect(func(info: String) -> void:
		_set_context(info)
		if hover_sound and not node.disabled: hover_sound.play())
	node.unhighlighted.connect(func() -> void:
		var hot := false
		for entry in entries:
			if entry.pointer_inside or entry.has_focus(): hot = true
		if not hot: _set_context(""))
	node.pressed.connect(func() -> void:
		if click_sound:
			click_sound.pitch_scale = randf_range(0.93,1.06)
			click_sound.play()
		callback.call_deferred())
	_link_focus()
	return node

func _link_focus() -> void:
	for i in range(entries.size()):
		entries[i].focus_neighbor_top = entries[i].get_path_to(entries[(i-1+entries.size())%entries.size()])
		entries[i].focus_neighbor_bottom = entries[i].get_path_to(entries[(i+1)%entries.size()])

func _set_context(value: String) -> void:
	if not is_instance_valid(context_label): return
	if context_tween: context_tween.kill()
	if not value.is_empty(): context_label.text = value
	context_tween = create_tween()
	context_tween.tween_property(context_label,"modulate:a",0.0 if value.is_empty() else 1.0,0.18)

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or entries.is_empty(): return
	if (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up")) and not get_viewport().gui_get_focus_owner():
		var candidates := entries.duplicate()
		if event.is_action_pressed("ui_up"): candidates.reverse()
		for candidate in candidates:
			if not candidate.disabled:
				candidate.grab_focus()
				break
		get_viewport().set_input_as_handled()

func home() -> void:
	page = "home"
	clear("ZOMBIX HEAD" if not world.started else "PAUSED","THE LAST LIGHT" if not world.started else "TAKE A BREATH")
	if world.started:
		label("Your squad keeps moving while you pause." if Session.online else "The woods can wait a moment.",Vector2(81,258),19)
		menu_list = null
		button("RESUME",300,func() -> void: world.set_paused(false))
		button("SETTINGS",360,settings)
		button("CONTROLS",420,controls)
		button("RETURN TO CAMP",480,world.leave_game)
	else:
		if Session.online:
			button("START EXPEDITION" if multiplayer.is_server() else "WAITING FOR HOST",0,func() -> void: Session.launch()).disabled = not multiplayer.is_server()
			ready_button = button("READY UP",0,_toggle_ready)
			button("CHARACTER",0,skins)
			button("SETTINGS",0,settings)
			button("LEAVE LOBBY",0,func() -> void: Session.leave(); home())
			if multiplayer.is_server():
				button("COPY LOCAL ADDRESS",0,func() -> void:
					DisplayServer.clipboard_set(Session.local_address())
					Session.info("Local address copied / UDP %d" % Session.endpoint_port))
			else: button("CONTROLS",0,controls)
		else:
			button("SOLO",0,func() -> void: Session.launch())
			button("HOST GAME",0,func() -> void: connection(true),"Keep the fire alive. Open your camp to three friends.")
			button("JOIN FRIENDS",0,func() -> void: connection(false),"Find your people. Join a friend's camp by address.")
			button("CHARACTER",0,skins)
			button("SETTINGS",0,settings)
			button("CONTROLS",0,controls)
		button("EXIT GAME",0,func() -> void: Session.leave(); get_tree().quit())
		roster_label = label("",Vector2(600,790),17,Color(0.72,0.78,0.72,0.65))
		roster_label.name = "CampRoster"
		roster_label.size = Vector2(740,70)
	refresh()

func refresh() -> void:
	if status_label:
		status_label.text = "" if Session.status in ["Choose how to play","Session closed"] else Session.status
	if roster_label:
		if Session.online:
			var text := "CONNECTED  %d / 4\n" % Session.roster.size()
			var index := 0
			for id in Session.roster:
				var profile: Dictionary = Session.roster[id]
				text += "%s · %s     " % [profile.name,"READY" if profile.ready else "PREPARING"]
				index += 1
				if index%2==0: text += "\n"
			roster_label.position.y = 755
			roster_label.text = text
			if multiplayer.is_server(): roster_label.text += "LOCAL  %s  /  UDP %d" % [Session.local_address(),Session.endpoint_port]
		else: roster_label.text = "CAMP PREVIEW / FOUR SURVIVORS\nYour friends take their places when they join."
	if ready_button and Session.roster.has(multiplayer.get_unique_id()):
		var ready: bool = Session.roster[multiplayer.get_unique_id()].ready
		ready_button.text = "READY" if ready else "READY UP"
		ready_button.selected = ready

func _toggle_ready() -> void:
	if Session.roster.has(multiplayer.get_unique_id()): Session.set_ready(not Session.roster[multiplayer.get_unique_id()].ready)

func field(at: Vector2, value: String, placeholder: String) -> LineEdit:
	var line := LineEdit.new()
	line.position = at
	line.size = Vector2(330,42)
	line.text = value
	line.placeholder_text = placeholder
	line.max_length = 64
	line.add_theme_font_size_override("font_size",22)
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.05,0.07,0.065,0.35)
	base.border_width_bottom = 1
	base.border_color = Color("8a8977")
	base.content_margin_left = 8
	line.add_theme_stylebox_override("normal",base)
	var focus := base.duplicate()
	focus.border_color = Color("ffb703")
	line.add_theme_stylebox_override("focus",focus)
	page_root.add_child(line)
	return line

func connection(hosting: bool) -> void:
	page = "connect"
	clear("HOST GAME" if hosting else "JOIN FRIENDS","A FIRE IS BETTER SHARED")
	label("SURVIVOR NAME",Vector2(81,270),16)
	var username := field(Vector2(81,297),Session.nickname,"Your name")
	username.max_length = 20
	label("PORT",Vector2(81,365),16)
	var port := SpinBox.new()
	port.position = Vector2(81,392)
	port.size = Vector2(330,42)
	port.min_value = 1024
	port.max_value = 65535
	port.value = Session.PORT
	page_root.add_child(port)
	var address: LineEdit
	if not hosting:
		label("HOST ADDRESS",Vector2(81,460),16)
		address = field(Vector2(81,487),"","e.g. 192.168.1.10")
	else: label("Friends connect using your address\nand the port above.",Vector2(81,466),21)
	button("OPEN CAMP" if hosting else "CONNECT",0,func() -> void:
		Session.profile(username.text,Session.skin)
		world._save_preferences()
		var result: Error = Session.host(int(port.value)) if hosting else Session.join(address.text,int(port.value))
		if result==OK:
			get_tree().paused = false
			home())
	button("BACK",0,home)
	menu_list.position.y = 580
	label("DIRECT CONNECTION / NO ACCOUNT\nInternet play requires a reachable host UDP port.",Vector2(81,746),17,Color("b4b8a9"))

func skins() -> void:
	page = "skins"
	clear("CHARACTER","WHO WILL YOU BRING INTO THE DARK?")
	label("Your appearance is saved and shared\nwith your squad in the lobby.",Vector2(81,260),21)
	for i in range(3):
		var index := i
		var node := button(["HUNTER","SCOUT","VETERAN"][i],0,func() -> void: world.choose_skin(index); skins())
		node.selected = Session.skin==i
	button("BACK",0,home)
	menu_list.position.y = 355

func settings() -> void:
	page = "settings"
	clear("SETTINGS","MAKE THE NIGHT YOUR OWN")
	label("EFFECTS VOLUME",Vector2(81,270),18)
	slider("volume",Vector2(81,308),0,100,1)
	label("LOOK SENSITIVITY",Vector2(81,365),18)
	slider("sensitivity",Vector2(81,403),0.3,2,0.05)
	check("Blood effects","blood",469)
	check("Sun shadows","shadows",519)
	label("WINDOW SIZE",Vector2(81,580),18)
	var resolution := OptionButton.new()
	resolution.position = Vector2(81,611)
	resolution.size = Vector2(330,38)
	for title in ["1280 × 800","1440 × 900","1600 × 1000"]: resolution.add_item(title)
	resolution.select(clampi(int(world.settings_data.resolution),0,2))
	page_root.add_child(resolution)
	resolution.item_selected.connect(func(index: int) -> void: world.settings_data.resolution=index; world._apply_settings())
	check("Fullscreen","fullscreen",678)
	button("BACK",0,home)
	menu_list.position.y = 754
	context_label.hide()

func slider(key: String, at: Vector2, minimum: float, maximum: float, step: float) -> void:
	var control := HSlider.new()
	control.position = at
	control.size = Vector2(330,28)
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = world.settings_data[key]
	control.modulate = Color("c6aa7d")
	page_root.add_child(control)
	control.value_changed.connect(func(value: float) -> void: world.settings_data[key]=value; world._apply_settings())

func check(title: String, key: String, y: float) -> void:
	var control := CheckButton.new()
	control.position = Vector2(81,y)
	control.text = title
	control.button_pressed = world.settings_data[key]
	control.add_theme_font_size_override("font_size",23)
	page_root.add_child(control)
	control.toggled.connect(func(value: bool) -> void: world.settings_data[key]=value; world._apply_settings())

func controls() -> void:
	page = "controls"
	clear("CONTROLS","STAY ALIVE. STAY TOGETHER.")
	label("WASD\nMOUSE\nSHIFT\nSPACE / CTRL\nCLICK\nHOLD + RELEASE\nE\nESC",Vector2(81,277),25,Color("d4ad76"))
	label("Move\nLook around\nSprint\nDodge\nQuick strike\nCharged strike\nCollect / activate\nPause menu",Vector2(267,277),25)
	label("Collect the supplies. Defend the radio.\nThe world keeps moving while you pause online.\n\nMENU / arrows or D-pad · Enter or A to select",Vector2(81,600),19,Color("b4b8a9"))
	button("BACK",0,home)
	menu_list.position.y = 740
	context_label.hide()
```

## ui/camp/menu_veil.gdshader

```glsl
shader_type canvas_item;
uniform float strength : hint_range(0.0,1.0)=1.0;
void fragment(){
 // Un'unica sfumatura continua; nessun rettangolo alle spalle delle voci.
 float side=1.0-smoothstep(0.0,0.55,UV.x);
 vec2 p=UV*2.0-1.0;
 float vignette=smoothstep(0.35,1.35,length(p*vec2(0.8,1.0)));
 float flicker=0.5+0.5*sin(TIME*1.9)*sin(TIME*3.1);
 vec3 shade=mix(vec3(0.018,0.028,0.030),vec3(0.065,0.032,0.014),flicker*0.3);
 COLOR=vec4(shade,(side*0.72+vignette*0.20)*strength);
}
```

## ui/camp/logo_ink.gdshader

```glsl
shader_type canvas_item;
void fragment(){
 vec4 ink=texture(TEXTURE,UV)*COLOR;
 float grain=fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453);
 float scratches=step(0.975,grain);
 float warmth=0.5+0.5*sin(TIME*1.3)*sin(TIME*2.1);
 ink.rgb*=mix(0.93,1.0,warmth);
 ink.a*=1.0-scratches*0.38;
 COLOR=ink;
}
```

## ui/camp/menu_embers.gd

```gdscript
# Control sopra le pagine del menu: particelle decorative che non intercettano input.
extends Control
var motes: Array[Vector4] = []
var time: float = 0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 735
	for i in range(22): motes.append(Vector4(rng.randf_range(0,1440),rng.randf_range(0,900),rng.randf_range(0.6,1.7),rng.randf_range(0,TAU)))
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta
	for i in range(motes.size()):
		motes[i].y -= delta*(9+motes[i].z*7)
		motes[i].x += sin(time*0.3+motes[i].w)*delta*6
		if motes[i].y< -10: motes[i].y=910
	queue_redraw()
func _draw() -> void:
	for mote in motes:
		var point := Vector2(mote.x,mote.y)
		var alpha := (0.15+0.15*sin(time*1.1+mote.w))*smoothstep(0,80,mote.y)
		draw_circle(point,mote.z*3,Color(1,0.24,0.03,alpha*0.10))
		draw_circle(point,mote.z,Color(1,0.62,0.18,alpha))
```

## ui/camp/camp_avatar.gd

```gdscript
# Avatar di anteprima al falò. Quattro pose procedurali, fasi diverse e transizioni continue.
# Scheletro importato da survivor_visual.gd; non influenza movimento o combattimento.
extends "res://art/survivor_visual.gd"
var stance: int = 0
var knife: Node3D
var phase: float = 0
var rest_position := Vector3.ZERO

func configure(model_name: String, owner_actor: Node3D, is_zombie: bool = false) -> void:
	phase = stance*1.73
	clock = phase
	rest_position = position
	super.configure(model_name,owner_actor,is_zombie)

func _pose(_delta: float) -> void:
	if not skeleton: return
	var breath := sin(clock*1.45+phase)
	var shift := sin(clock*0.36+phase)
	var action := (sin(clock*0.56+phase)+1)*0.5
	action = smoothstep(0.2,0.9,action)
	position = rest_position+Vector3(shift*0.009,breath*0.004,0)
	# Ogni posa parte da gambe e braccia definite: nessuna deriva fra animazioni.
	rotate_bone("thigh_l",Vector3.RIGHT,0)
	rotate_bone("thigh_r",Vector3.RIGHT,0)
	rotate_bone("calf_l",Vector3.RIGHT,0)
	rotate_bone("calf_r",Vector3.RIGHT,0)
	rotate_bone("lowerarm_l",Vector3.RIGHT,-0.08)
	rotate_bone("lowerarm_r",Vector3.RIGHT,-0.08)
	rotate_bone("hand_l",Vector3.RIGHT,0)
	rotate_bone("hand_r",Vector3.RIGHT,0)
	transform_bone("upperarm_l",Basis(Vector3.RIGHT,-0.08)*Basis(Vector3.BACK,-1.38))
	transform_bone("upperarm_r",Basis(Vector3.RIGHT,-0.08)*Basis(Vector3.BACK,1.38))
	transform_bone("spine_01",Basis(Vector3.RIGHT,breath*0.013)*Basis(Vector3.BACK,shift*0.018))
	transform_bone("head",Basis(Vector3.UP,shift*0.09)*Basis(Vector3.RIGHT,0.13+breath*0.015))
	match stance:
		0: # In piedi: sposta il peso e sistema il colletto ogni pochi secondi.
			rotate_bone("pelvis",Vector3.BACK,-shift*0.018)
			transform_bone("upperarm_l",Basis(Vector3.RIGHT,-0.1-action*0.5)*Basis(Vector3.BACK,-1.35))
			rotate_bone("lowerarm_l",Vector3.RIGHT,-0.1-action*0.85)
			rotate_bone("thigh_r",Vector3.RIGHT,shift*0.025)
		1: # Seduto: gomiti in avanti, sfrega lentamente le mani sopra il fuoco.
			rotate_bone("thigh_l",Vector3.RIGHT,-1.45)
			rotate_bone("thigh_r",Vector3.RIGHT,-1.45)
			rotate_bone("calf_l",Vector3.RIGHT,1.45)
			rotate_bone("calf_r",Vector3.RIGHT,1.45)
			transform_bone("upperarm_l",Basis(Vector3.RIGHT,-0.6-action*0.15)*Basis(Vector3.BACK,-1.25))
			transform_bone("upperarm_r",Basis(Vector3.RIGHT,-0.6-action*0.15)*Basis(Vector3.BACK,1.25))
			rotate_bone("lowerarm_l",Vector3.RIGHT,-0.6+sin(clock*2.2)*0.05*action)
			rotate_bone("lowerarm_r",Vector3.RIGHT,-0.6-sin(clock*2.2)*0.05*action)
			rotate_bone("spine_01",Vector3.RIGHT,0.15+breath*0.02)
		2: # Ispezione del coltello: cambia angolo del polso e segue la lama con lo sguardo.
			transform_bone("upperarm_r",Basis(Vector3.RIGHT,-0.9-action*0.2)*Basis(Vector3.BACK,1.2))
			rotate_bone("lowerarm_r",Vector3.RIGHT,-0.65-action*0.25)
			rotate_bone("hand_r",Vector3.UP,shift*0.22)
			transform_bone("upperarm_l",Basis(Vector3.RIGHT,-0.15-action*0.3)*Basis(Vector3.BACK,-1.35))
			rotate_bone("lowerarm_l",Vector3.RIGHT,-action*0.45)
			transform_bone("head",Basis(Vector3.UP,-0.16+shift*0.08)*Basis(Vector3.RIGHT,0.2+action*0.14))
		3: # Accovacciato: mani protese verso il calore e brevi sguardi al bosco.
			rotate_bone("thigh_l",Vector3.RIGHT,-0.9)
			rotate_bone("thigh_r",Vector3.RIGHT,-1.0)
			rotate_bone("calf_l",Vector3.RIGHT,1.35)
			rotate_bone("calf_r",Vector3.RIGHT,1.45)
			rotate_bone("spine_01",Vector3.RIGHT,0.2+breath*0.015)
			transform_bone("upperarm_l",Basis(Vector3.RIGHT,-0.8+breath*0.025)*Basis(Vector3.BACK,-1.28))
			transform_bone("upperarm_r",Basis(Vector3.RIGHT,-0.8-breath*0.025)*Basis(Vector3.BACK,1.28))
			rotate_bone("lowerarm_l",Vector3.RIGHT,-0.35)
			rotate_bone("lowerarm_r",Vector3.RIGHT,-0.42)
			transform_bone("head",Basis(Vector3.UP,shift*0.32)*Basis(Vector3.RIGHT,0.18))
	if axe: axe.hide()
	if knife and bone_ids.has("hand_r"):
		knife.global_position = (skeleton.global_transform*skeleton.get_bone_global_pose(bone_ids.hand_r)).origin
		knife.global_rotation = global_rotation+Vector3(0.18+action*0.12,shift*0.3,0.14+shift*0.08)

func add_knife() -> void:
	knife = load("res://art/surroundead/SM_Wep_Melee_HuntingKnife_01.glb").instantiate()
	add_child(knife)
	knife.scale = Vector3.ONE*0.65
```

## ui/camp/camp.gd

```gdscript
extends Node3D
const MODELS := ["SK_Chr_Hunter_Male_01","SK_Chr_Soldier_Male_01","SK_Chr_Contractor_Male_02"]
const NAMES := ["CACCIATORE","RICOGNITORE","VETERANO"]
var avatars: Array[Node3D] = []
var camera: Camera3D
var fire: OmniLight3D
var moon: DirectionalLight3D
var timer: float = 0
var crackle: AudioStreamPlayer3D
var skin_ids: Array[int] = [-1,-1,-1,-1]

func build() -> void:
	position = Vector3(200,0,0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(45,45)
	ground.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = load("res://world/zona1_rifugio/ground.gdshader")
	ground.material_override = material
	add_child(ground)
	for i in range(16):
		var tree: Node3D = load("res://art/surroundead/SM_Tree_Pine_01.glb").instantiate()
		tree.position = Vector3(cos(i*0.6)*9,0,-5-absf(sin(i*0.6))*8)
		tree.scale = Vector3.ONE*(1.3+float(i%4)*0.35)
		add_child(tree)
		_wind_material(tree)
	for i in range(10):
		var rock: Node3D = load("res://art/surroundead/SM_Env_Rock_01.glb").instantiate()
		rock.position = Vector3(cos(i*TAU/10)*0.65,0,sin(i*TAU/10)*0.65+0.3)
		rock.scale = Vector3(0.3,0.25,0.3)
		add_child(rock)
	for i in range(3):
		var log: Node3D = load("res://art/surroundead/SM_Tree_Log_01.glb").instantiate()
		log.position = Vector3(0,0.13,0.3)
		log.rotation.y = i*PI/3
		log.scale = Vector3(0.5,0.5,0.35)
		add_child(log)
	var seat: Node3D = load("res://art/surroundead/SM_Tree_Log_01.glb").instantiate()
	seat.position = Vector3(1.7,0.25,-0.9)
	seat.rotation.y = PI/2
	seat.scale = Vector3(1.4,1.4,0.6)
	add_child(seat)
	for i in range(4):
		avatars.append(null)
		set_skin(i,i%3)
	var flames := CPUParticles3D.new()
	flames.name = "FireFlames"
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.amount = 26
	flames.lifetime = 0.75
	flames.preprocess = 2
	flames.direction = Vector3.UP
	flames.spread = 12
	flames.gravity = Vector3(0,0.5,0)
	flames.initial_velocity_min = 0.3
	flames.initial_velocity_max = 0.7
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.22
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45,0.85)
	flames.mesh = quad
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = load("res://ui/camp/flame.gdshader")
	flames.material_override = flame_mat
	flames.position = Vector3(0,0.2,0.3)
	add_child(flames)
	var sparks := CPUParticles3D.new()
	sparks.name = "WorldEmbers"
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.position = Vector3(0,0.5,0.3)
	sparks.amount = 16
	sparks.lifetime = 2.2
	sparks.preprocess = 2.2
	sparks.direction = Vector3.UP
	sparks.spread = 18
	sparks.gravity = Vector3(0,0.3,0)
	sparks.initial_velocity_min = 0.4
	sparks.initial_velocity_max = 0.9
	var ember := SphereMesh.new()
	ember.radius = 0.012
	ember.height = 0.024
	var ember_mat := StandardMaterial3D.new()
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mat.albedo_color = Color("ffbe56")
	ember_mat.emission_enabled = true
	ember_mat.emission = Color("ff7e24")
	ember.material = ember_mat
	sparks.mesh = ember
	add_child(sparks)
	if DisplayServer.get_name() != "headless" and ResourceLoader.exists("res://audio/fire.wav"):
		crackle = AudioStreamPlayer3D.new()
		var stream: AudioStreamWAV = load("res://audio/fire.wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size()/2
		crackle.stream = stream
		crackle.position = Vector3(0,0.3,0.3)
		crackle.volume_db = -3
		crackle.unit_size = 5
		add_child(crackle)
	fire = OmniLight3D.new()
	fire.name = "FireLight"
	fire.position = Vector3(0,0.85,0.3)
	fire.light_color = Color("ff9d40")
	fire.omni_range = 9
	fire.light_energy = 4.5
	fire.shadow_enabled = true
	add_child(fire)
	moon = DirectionalLight3D.new()
	moon.name = "MoonFill"
	moon.rotation_degrees = Vector3(-38,100,0)
	moon.light_color = Color("6c98bb")
	moon.light_energy = 0.7
	add_child(moon)
	camera = Camera3D.new()
	camera.name = "MenuCamera"
	add_child(camera)
	camera.position = Vector3(3.6,2.4,6.7)
	camera.look_at(global_position+Vector3(-1.2,1.05,-0.6))
	camera.fov = 46
	var lens := CameraAttributesPractical.new()
	lens.dof_blur_far_enabled = RenderingServer.get_current_rendering_method()!="gl_compatibility"
	lens.dof_blur_far_distance = 12
	lens.dof_blur_far_transition = 6
	lens.dof_blur_amount = 0.08
	camera.attributes = lens
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111f2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("708396")
	env.ambient_light_energy = 0.23
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = RenderingServer.get_current_rendering_method()!="gl_compatibility"
	env.ssao_enabled = RenderingServer.get_current_rendering_method()=="forward_plus"
	env.fog_enabled = true
	env.fog_density = 0.032
	env.fog_light_color = Color("172e38")
	camera.environment = env
	preload("res://world/zona1_rifugio/atmosphere.gd").grass(self,3000,12,17,Vector3(0,0,-2),false)
	for item in [["SM_Prop_Tent_Dome_01",Vector3(-3.9,0,-3.6),0.4],["SM_Veh_Truck_Destroyed_01",Vector3(4,0,-6),-0.6],["SM_Prop_Barrel_Water_01",Vector3(3.8,0,-1.4),0.0]]:
		var prop: Node3D = load("res://art/surroundead/"+item[0]+".glb").instantiate()
		prop.position = item[1]
		prop.rotation.y = item[2]
		add_child(prop)
	preload("res://world/zona1_rifugio/atmosphere.gd").lantern(self,Vector3(-3.2,0.6,-2.4))
	var rim := OmniLight3D.new()
	rim.position = Vector3(0,3,-4)
	rim.light_color = Color("8bafc5")
	rim.light_energy = 2.1
	rim.omni_range = 7
	add_child(rim)

func set_skin(slot: int, skin_id: int) -> void:
	skin_id = clampi(skin_id,0,2)
	if is_instance_valid(avatars[slot]) and skin_ids[slot]==skin_id: return
	skin_ids[slot] = skin_id
	if is_instance_valid(avatars[slot]):
		remove_child(avatars[slot])
		avatars[slot].queue_free()
	var avatar := Node3D.new()
	avatar.name = "Survivor%d" % (slot+1)
	avatar.set_script(load("res://ui/camp/camp_avatar.gd"))
	avatar.stance = slot
	avatar.position = [Vector3(-2.1,0,-0.5),Vector3(1.7,-0.35,-0.9),Vector3(0.4,0,-2.8),Vector3(-1.6,-0.2,-3.3)][slot]
	avatar.rotation.y = [0.7,-0.9,0.1,0.4][slot]
	add_child(avatar)
	avatar.configure(MODELS[clampi(skin_id,0,2)],self)
	if slot == 2: avatar.add_knife()
	avatars[slot] = avatar

func set_active(value: bool) -> void:
	visible = value
	moon.visible = value
	fire.visible = value
	camera.current = value
	if crackle:
		if value and not crackle.playing: crackle.play()
		elif not value: crackle.stop()

func _process(delta: float) -> void:
	timer += delta
	if fire: fire.light_energy = 3.4+sin(timer*13)*0.22+sin(timer*21)*0.12
	if camera and visible:
		camera.position = Vector3(3.6+sin(timer*0.09)*0.16,2.4+sin(timer*0.13)*0.045,6.7)
		camera.look_at(global_position+Vector3(-1.2,1.05,-0.6))

func _tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		node.material_override = mat
	for child in node.get_children(): _tint(child,color)

func _wind_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://world/zona1_rifugio/tree.gdshader")
		node.material_override = mat
	for child in node.get_children(): _wind_material(child)
```
