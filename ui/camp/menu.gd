# CampMenu (Control) sotto Interface/CanvasLayer; costruisce UI nativa e riutilizzabile.
# Stile: titolo grande a sinistra e pulsanti a cornice chiara in basso a sinistra (home);
# Opzioni a schede in un pannello semitrasparente, righe scure a tutta larghezza (Grafica).
# Mouse, tastiera e controller: focus visibile, Esc / B per tornare indietro.
extends "res://ui/camp/menu_widgets.gd"

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
	version_label = _corner_label("VersionLabel",-44,MUTED)
	status_label = _corner_label("SessionStatus",-72,Color("b0bdb2"))
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
	Localization.language_changed.connect(func(_code: String) -> void: _rebuild_page())
	home()

## Rifà la pagina aperta: i testi passano di nuovo da Localization.t nella nuova lingua.
func _rebuild_page() -> void:
	match page:
		"options":
			# Le scelte grafiche non ancora applicate restano dopo il cambio lingua.
			var pending := graphics_pending.duplicate()
			var dirty := graphics_dirty
			options_menu(tab)
			if tab == "graphics": _restore_graphics_pending(pending,dirty)
		"multiplayer": network_menu()
		"credits": credits()
		"skins": skins()
		"connect": connection(connection_hosting)
		_: home()

func go_back() -> void:
	match page:
		_: home()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if page != "home" and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		go_back()
		get_viewport().set_input_as_handled()
		return
	if entries.is_empty(): return
	for action in ["ui_down","ui_up","ui_left","ui_right"]:
		if event.is_action_pressed(action) and not get_viewport().gui_get_focus_owner():
			for candidate in entries:
				if not candidate.disabled:
					candidate.grab_focus()
					break
			get_viewport().set_input_as_handled()
			return

func home() -> void:
	page = "home"
	clear("PAUSED" if world.started else "ZOMBIX HEAD")
	if world.started:
		label("Your squad keeps moving while you pause." if Session.online else "The woods can wait a moment.",Vector2(66,168),22,MUTED)
		button("RESUME",func() -> void: world.set_paused(false))
		button("OPTIONS",options_menu)
		button("RETURN TO CAMP",world.leave_game)
	elif Session.online:
		button("START EXPEDITION" if multiplayer.is_server() else "WAITING FOR HOST",func() -> void: Session.launch()).disabled = not multiplayer.is_server()
		ready_button = button("READY UP",_toggle_ready)
		button("CHARACTER",skins)
		button("OPTIONS",options_menu)
		if multiplayer.is_server():
			button("COPY LOCAL ADDRESS",func() -> void:
				DisplayServer.clipboard_set(Session.local_address())
				Session.info(Localization.t("Local address copied / UDP {0}", [Session.endpoint_port])))
		button("LEAVE LOBBY",func() -> void: Session.leave(); home())
	else:
		if not world.automated and SaveManager.has_save():
			button("CONTINUE",func() -> void: world.continue_save())
		button("PLAY",func() -> void: Session.launch())
		button("HOST GAME",func() -> void: connection(true))
		button("JOIN GAME",func() -> void: connection(false))
		button("CHARACTER",skins)
		button("OPTIONS",options_menu)
		button("CREDITS",credits)
		button("QUIT",func() -> void: Session.leave(); get_tree().quit())
	roster_label = label("",Vector2(420,770),17,Color(0.72,0.78,0.72,0.75))
	roster_label.name = "CampRoster"
	roster_label.size = Vector2(740,70)
	refresh()
	_focus_first()

func refresh() -> void:
	if status_label:
		status_label.text = "" if Session.status in ["Choose how to play","Session closed"] else Localization.t(Session.status)
	if roster_label and is_instance_valid(roster_label):
		if Session.online:
			var text := Localization.t("CONNECTED  {0} / 4\n", [Session.roster.size()])
			var index := 0
			for id in Session.roster:
				var profile: Dictionary = Session.roster[id]
				text += "%s · %s     " % [profile.name,Localization.t("READY" if profile.ready else "PREPARING")]
				index += 1
				if index%2==0: text += "\n"
			if multiplayer.is_server(): text += Localization.t("LOCAL  {0}  /  UDP {1}", [Session.local_address(),Session.endpoint_port])
			roster_label.text = text
		else: roster_label.text = ""
	if ready_button and is_instance_valid(ready_button) and Session.roster.has(multiplayer.get_unique_id()):
		var ready: bool = Session.roster[multiplayer.get_unique_id()].ready
		ready_button.text = Localization.t("READY" if ready else "READY UP")

func _toggle_ready() -> void:
	if Session.roster.has(multiplayer.get_unique_id()): Session.set_ready(not Session.roster[multiplayer.get_unique_id()].ready)

func field(at: Vector2, value: String, placeholder: String) -> LineEdit:
	var line := LineEdit.new()
	line.position = at
	line.size = Vector2(380,46)
	line.text = value
	line.placeholder_text = Localization.t(placeholder)
	line.max_length = 64
	line.add_theme_font_size_override("font_size",22)
	line.add_theme_stylebox_override("normal",_box(ROW_BG,Color(FRAME,0.6),2))
	line.add_theme_stylebox_override("focus",_box(Color(0,0,0,0),ACCENT,3))
	page_root.add_child(line)
	return line

func connection(hosting: bool) -> void:
	page = "connect"
	connection_hosting = hosting
	clear("HOST GAME" if hosting else "JOIN GAME")
	label("A FIRE IS BETTER SHARED",Vector2(66,168),20,MUTED)
	label("SURVIVOR NAME",Vector2(66,230),18)
	var username := field(Vector2(66,258),Session.nickname,"Your name")
	username.max_length = 20
	label("PORT",Vector2(66,326),18)
	var port := SpinBox.new()
	port.position = Vector2(66,354)
	port.size = Vector2(380,46)
	port.min_value = 1024
	port.max_value = 65535
	port.value = Session.PORT
	page_root.add_child(port)
	var address: LineEdit
	if not hosting:
		label("HOST ADDRESS",Vector2(66,422),18)
		address = field(Vector2(66,450),"","e.g. 192.168.1.10")
	else: label("Friends connect using your address\nand the port above.",Vector2(66,428),21,MUTED)
	label("DIRECT CONNECTION / NO ACCOUNT\nInternet play requires a reachable host UDP port.",Vector2(66,530),17,MUTED)
	button("OPEN CAMP" if hosting else "CONNECT",func() -> void:
		Session.profile(username.text,Session.skin)
		world._save_preferences()
		var result: Error = Session.host(int(port.value)) if hosting else Session.join(address.text,int(port.value))
		if result==OK:
			get_tree().paused = false
			home())
	back_button(home)
	_focus_first()

func skins() -> void:
	page = "skins"
	clear("CHARACTER")
	label("WHO WILL YOU BRING INTO THE DARK?",Vector2(66,168),20,MUTED)
	var names: Array = preload("res://ui/camp/camp.gd").NAMES
	var count: int = names.size()
	label("%02d / %02d" % [Session.skin+1,count],Vector2(66,232),17,ACCENT)
	label(str(names[Session.skin]),Vector2(66,254),44)
	label(str(preload("res://art/zx_player/zx_player.gd").SKINS[Session.skin][1]),Vector2(66,312),20,MUTED)
	var row := button_row()
	button("◀  PREVIOUS",func() -> void: world.choose_skin(posmod(Session.skin-1,count)); skins(),row,180)
	button("NEXT  ▶",func() -> void: world.choose_skin(posmod(Session.skin+1,count)); skins(),row,180)
	back_button(home)
	_focus_first()

func network_menu() -> void:
	page = "multiplayer"
	clear("MULTIPLAYER")
	button("HOST GAME",func() -> void: connection(true))
	button("JOIN GAME",func() -> void: connection(false))
	back_button(home)
	_focus_first()

func credits() -> void:
	page = "credits"
	clear("CREDITS",true)
	var panel := _panel(Vector2(900,560),110)
	var list := VBoxContainer.new()
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_theme_constant_override("separation",6)
	panel.add_child(list)
	var logo := _text(list,"ZOMBIX HEAD",Vector2.ZERO,46,TEXT)
	logo.add_theme_font_override("font",DISPLAY)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for line in CREDITS:
		var head := _text(list,line[0],Vector2.ZERO,18,ACCENT)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_theme_font_override("font",DISPLAY)
		var body := _text(list,line[1],Vector2.ZERO,24,TEXT)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_button(home)
	_focus_first()

# ------------------------------------------------------------------ opzioni a schede
func options_menu(which: String = "") -> void:
	if not which.is_empty(): tab = which
	page = "options"
	clear("OPTIONS",true)
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation",10)
	tabs.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tabs.offset_left = -600
	tabs.offset_right = 600
	tabs.offset_top = 112
	page_root.add_child(tabs)
	var active: Button
	for entry in TABS:
		var key: String = entry[0]
		var node := button(entry[1],func() -> void: options_menu(key),tabs,232,48)
		node.name = "Tab" + key.to_pascal_case()
		if key == tab:
			active = node
			node.add_theme_stylebox_override("normal",_box(Color(0.93,0.90,0.82,0.24),Color(FRAME,1.0),3))
	var panel := _panel(Vector2(1200,588),172)
	var body := VBoxContainer.new()
	body.name = "TabBody"
	body.add_theme_constant_override("separation",6)
	panel.add_child(body)
	match tab:
		"game": _game_tab(body)
		"graphics": _graphics_tab(body)
		"audio": _audio_tab(body)
		"controls": _controls_tab(body)
		"language": _language_tab(body)
	back_button(home)
	_focus_first(active)

## Vecchi punti d'ingresso: aprono la scheda giusta.
func settings() -> void: options_menu("game")
func graphics() -> void: options_menu("graphics")
func controls() -> void: options_menu("controls")
func language(_return_to: String = "") -> void: options_menu("language")

func _game_tab(body: Control) -> void:
	_section(body,"GAME")
	_slider(body,"LOOK SENSITIVITY","sensitivity",0.3,2.0,0.05,"%.2f")
	_choice(body,"BLOOD EFFECTS",["OFF","ON"],1 if bool(world.settings_data.blood) else 0,func(i: int) -> void:
		world.settings_data.blood = i == 1
		world._apply_settings(),"blood")

func _audio_tab(body: Control) -> void:
	_section(body,"AUDIO")
	_slider(body,"EFFECTS VOLUME","volume",0,100,1,"%.0f")

func _controls_tab(body: Control) -> void:
	_section(body,"CONTROLS")
	for pair in KEYS:
		var row := _row(body,pair[1])
		var key := _text(row,pair[0],Vector2.ZERO,20,ACCENT)
		key.add_theme_font_override("font",DISPLAY)
	var hint := _text(body,"MENU / arrows or D-pad · Enter or A to select · Esc or B to go back",Vector2.ZERO,17,MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _language_tab(body: Control) -> void:
	_section(body,"LANGUAGE")
	var names: Array = []
	var selected := 0
	for i in Localization.LANGUAGES.size():
		names.append(str(Localization.LANGUAGES[i].name))
		if Localization.LANGUAGES[i].code == Localization.current: selected = i
	_choice(body,"LANGUAGE OF THE GAME",names,selected,func(i: int) -> void:
		Localization.set_language(str(Localization.LANGUAGES[i].code)),"language")
	var hint := _text(body,"THE CHANGE APPLIES IMMEDIATELY",Vector2.ZERO,17,MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# ------------------------------------------------------------------ grafica
func _graphics_tab(body: Control) -> void:
	var data: Dictionary = world.settings_data
	graphics_dirty = false
	# Le scelte restano in sospeso: solo APPLICA le passa al gioco e le salva.
	graphics_pending = {"display_mode":int(data.display_mode),"resolution":str(data.resolution),"vsync":int(data.vsync),
		"quality":int(data.quality),"textures":int(data.textures),"shadow_quality":int(data.shadow_quality),"anti_aliasing":int(data.anti_aliasing)}
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",6)
	scroll.add_child(list)
	_section(list,"DISPLAY")
	_choice(list,"DISPLAY MODE",["WINDOWED","BORDERLESS","FULLSCREEN"],int(graphics_pending.display_mode),func(i: int) -> void: _pend("display_mode",i),"display_mode")
	var sizes: Array = world.monitor_resolutions()
	var resolution := OptionButton.new()
	resolution.name = "Resolution"
	resolution.custom_minimum_size = Vector2(220,36)
	resolution.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resolution.add_theme_font_size_override("font_size",19)
	resolution.add_theme_stylebox_override("normal",_box(Color(0,0,0,0.2),Color(FRAME,0.5),1))
	resolution.add_theme_stylebox_override("hover",_box(Color(0,0,0,0.3),ACCENT,1))
	resolution.add_theme_stylebox_override("focus",_box(Color(0,0,0,0),ACCENT,2))
	resolution.get_popup().add_theme_font_size_override("font_size",19)
	var current: Vector2i = world.resolution_size()
	for i in sizes.size():
		resolution.add_item("%d × %d" % [sizes[i].x,sizes[i].y])
		if sizes[i] == current: resolution.select(i)
	resolution.item_selected.connect(func(i: int) -> void:
		var size: Vector2i = sizes[clampi(i,0,sizes.size()-1)]
		_pend("resolution","%dx%d" % [size.x,size.y]))
	_row(list,"RESOLUTION").add_child(resolution)
	graphics_controls["resolution"] = resolution
	_choice(list,"V-SYNC",["OFF","ON","ADAPTIVE"],int(graphics_pending.vsync),func(i: int) -> void: _pend("vsync",i),"vsync")
	_section(list,"QUALITY")
	_choice(list,"OVERALL QUALITY",["LOW","MEDIUM","HIGH","ULTRA"],int(graphics_pending.quality),func(i: int) -> void:
		var preset: Dictionary = world.quality_preset_values(i)
		graphics_pending.quality = i
		graphics_pending.textures = int(preset.textures)
		graphics_pending.shadow_quality = int(preset.shadow_quality)
		graphics_pending.anti_aliasing = int(preset.anti_aliasing)
		_sync_graphics_controls()
		_mark_graphics_dirty(),"overall_quality")
	_choice(list,"TEXTURE QUALITY",["LOW","MEDIUM","HIGH","ULTRA"],int(graphics_pending.textures),func(i: int) -> void: _pend("textures",i),"texture_quality")
	_choice(list,"SHADOW QUALITY",["OFF","LOW","MEDIUM","HIGH","ULTRA"],int(graphics_pending.shadow_quality),func(i: int) -> void: _pend("shadow_quality",i),"shadow_quality")
	_choice(list,"ANTI-ALIASING",["OFF","FXAA","MSAA 2×","MSAA 4×","MSAA 8×"],int(graphics_pending.anti_aliasing),func(i: int) -> void: _pend("anti_aliasing",i),"anti_aliasing")
	# Barra in basso: stato, Predefiniti, Applica, Annulla.
	var bar := HBoxContainer.new()
	bar.name = "GraphicsBar"
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation",14)
	body.add_child(bar)
	graphics_status = _text(bar,"ADJUST THE SETTINGS, THEN PRESS APPLY.",Vector2.ZERO,17,MUTED)
	graphics_status.name = "GraphicsStatus"
	graphics_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button("DEFAULTS",_graphics_defaults,bar,170,44)
	button("APPLY",_apply_graphics_pending,bar,170,44)
	button("CANCEL",func() -> void: options_menu("graphics"),bar,170,44)

func _pend(key: String, value: Variant) -> void:
	graphics_pending[key] = value
	_mark_graphics_dirty()

func _graphics_defaults() -> void:
	var native: Vector2i = world._native_resolution()
	graphics_pending.display_mode = 0
	graphics_pending.vsync = 1
	graphics_pending.resolution = "%dx%d" % [native.x,native.y]
	graphics_pending.quality = 2
	var preset: Dictionary = world.quality_preset_values(2)
	for key in ["textures","shadow_quality","anti_aliasing"]: graphics_pending[key] = int(preset[key])
	_restore_graphics_pending(graphics_pending,true)

func _restore_graphics_pending(pending: Dictionary, dirty: bool) -> void:
	if pending.is_empty() or not graphics_controls.has("display_mode"): return
	graphics_pending = pending
	graphics_controls.display_mode.select(int(pending.display_mode))
	graphics_controls.vsync.select(int(pending.vsync))
	graphics_controls.overall_quality.select(int(pending.quality))
	var sizes: Array = world.monitor_resolutions()
	for i in sizes.size():
		if "%dx%d" % [sizes[i].x,sizes[i].y] == str(pending.resolution): graphics_controls.resolution.select(i)
	_sync_graphics_controls()
	if dirty: _mark_graphics_dirty()

func _mark_graphics_dirty() -> void:
	graphics_dirty = true
	if graphics_status and is_instance_valid(graphics_status):
		graphics_status.text = Localization.t("UNSAVED CHANGES  ·  PRESS APPLY")
		graphics_status.add_theme_color_override("font_color",ACCENT)

## Passa al gioco tutte le scelte sospese della scheda Grafica in un colpo solo.
func _apply_graphics_pending() -> void:
	if graphics_pending.is_empty(): return
	for key in graphics_pending:
		world.settings_data[key] = graphics_pending[key]
	world.settings_data.fullscreen = int(graphics_pending.display_mode) == 2
	world.settings_data.shadows = int(graphics_pending.shadow_quality) > 0
	world._apply_settings()
	graphics_dirty = false
	if graphics_status and is_instance_valid(graphics_status):
		graphics_status.text = Localization.t("SETTINGS APPLIED")
		graphics_status.add_theme_color_override("font_color",Color("8ecf9a"))

func _sync_graphics_controls() -> void:
	for pair in [["texture_quality",int(graphics_pending.textures)],["shadow_quality",int(graphics_pending.shadow_quality)],["anti_aliasing",int(graphics_pending.anti_aliasing)]]:
		var control: MenuChoice = graphics_controls.get(pair[0])
		if control: control.select(int(pair[1]))
