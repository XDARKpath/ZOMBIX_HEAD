# CampMenu (Control) sotto Interface/CanvasLayer; costruisce UI nativa e riutilizzabile.
extends Control
const FireButton := preload("res://ui/camp/fire_button.gd")
const TYPE := preload("res://art/fonts/BarlowCondensed-Regular.ttf")
const DISPLAY := preload("res://art/fonts/BarlowCondensed-SemiBold.ttf")
const LOGO_TEXTURE := "res://art/zx_logo/T_ZX_Logo.png"
var world: Node3D
var page: String = "home"
var page_root: Control
var menu_list: VBoxContainer
var status_label: Label
var roster_label: Label
var ready_button: Button
var context_label: Label
var entries: Array[Button] = []
var graphics_controls: Dictionary = {}
var graphics_pending: Dictionary = {}
var graphics_status: Label
var graphics_dirty := false
var page_tween: Tween
var context_tween: Tween
var click_sound: AudioStreamPlayer
var hover_sound: AudioStreamPlayer
var language_return: String = "options"
var connection_hosting: bool = true
var lan_box: VBoxContainer
var lan_name: LineEdit

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
	var version := _text(self,Localization.t("BUILD {0}  /  LAGO CENERE", [ProjectSettings.get_setting("application/config/version")]),Vector2.ZERO,15,Color(0.69,0.78,0.75,0.65))
	version.name = "BuildBadge"
	version.hide()
	version.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	version.position = Vector2(1080,38)
	version.size.x = 280
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var badge := _text(self,Localization.t("CO-OP  /  UP TO 4 PLAYERS"),Vector2(79,852),15,Color(0.69,0.78,0.75,0.65))
	badge.name = "CoopBadge"
	badge.hide()
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
	Localization.language_changed.connect(func(_code: String) -> void: _rebuild_page())
	Session.lan_changed.connect(func() -> void: if page == "connect" and not connection_hosting: _lan_list())
	home()

## Rifà la pagina aperta: i testi passano di nuovo da Localization.t nella nuova lingua.
func _rebuild_page() -> void:
	var badge: Label = get_node_or_null("BuildBadge")
	if badge: badge.text = Localization.t("BUILD {0}  /  LAGO CENERE", [ProjectSettings.get_setting("application/config/version")])
	var coop: Label = get_node_or_null("CoopBadge")
	if coop: coop.text = Localization.t("CO-OP  /  UP TO 4 PLAYERS")
	match page:
		"multiplayer": network_menu()
		"options": options_menu()
		"settings": settings()
		"graphics":
			# Le scelte non ancora applicate restano dopo il cambio lingua.
			var pending := graphics_pending.duplicate()
			var dirty := graphics_dirty
			graphics()
			_restore_graphics_pending(pending, dirty)
		"language": language(language_return)
		"controls": controls()
		"skins": skins()
		"connect": connection(connection_hosting)
		_: home()

func clear(title: String, subtitle: String = "") -> void:
	ready_button = null
	roster_label = null
	context_label = null
	graphics_status = null
	menu_list = null
	entries.clear()
	lan_box = null
	Session.lan_search(page == "connect" and not connection_hosting)
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
	if title == "ZOMBIX HEAD" and ResourceLoader.exists(LOGO_TEXTURE):
		# Logo 3D stile POLYGON (art/zx_logo/T_ZX_Logo.png, renderizzato da SM_ZX_Logo.glb).
		var art := TextureRect.new()
		art.name = "ZombixLogo"
		art.texture = load(LOGO_TEXTURE)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(330, 158)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		titles.add_child(art)
	elif title == "ZOMBIX HEAD":
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
	node.text = Localization.t(value)
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

func button(title: String, _y: float, callback: Callable, description: String = "", parent: Container = null, width: float = 370.0) -> Button:
	var host: Container = parent if parent else _menu_container()
	var slot := Control.new()
	slot.name = "ButtonSlot%d" % entries.size()
	slot.custom_minimum_size = Vector2(width,51)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(slot)
	var node := Button.new()
	node.set_script(FireButton)
	node.name = title.to_pascal_case()
	node.text = Localization.t(title)
	node.description = description
	node.size = Vector2(width-20,51)
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

## Contenitore verticale del menu, creato alla prima voce.
func _menu_container() -> VBoxContainer:
	if not menu_list:
		menu_list = VBoxContainer.new()
		menu_list.name = "MenuList"
		menu_list.position = Vector2(78,294)
		menu_list.size.x = 370
		menu_list.add_theme_constant_override("separation",9)
		page_root.add_child(menu_list)
	return menu_list

## Riga orizzontale dentro la lista verticale: le voci restano nello stesso elenco
## e mantengono focus e navigazione, ma vengono disposte affiancate.
func button_row(separation: int = 8) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ButtonRow"
	row.add_theme_constant_override("separation",separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_container().add_child(row)
	return row

func _link_focus() -> void:
	# Raggruppa le voci per riga: in una VBox ogni pulsante è una riga,
	# mentre i pulsanti dentro un'HBox condividono la stessa riga orizzontale.
	var rows: Array = []
	for entry in entries:
		var slot: Node = entry.get_parent()
		var host: Node = slot.get_parent()
		var key: Node = host if host is HBoxContainer else slot
		var row: Array = []
		for candidate in entries:
			var candidate_slot: Node = candidate.get_parent()
			var candidate_host: Node = candidate_slot.get_parent()
			var candidate_key: Node = candidate_host if candidate_host is HBoxContainer else candidate_slot
			if candidate_key == key: row.append(candidate)
		if not rows.has(row): rows.append(row)
	for r in range(rows.size()):
		var row: Array = rows[r]
		for c in range(row.size()):
			var entry: Button = row[c]
			var above: Button = rows[(r-1+rows.size())%rows.size()][0]
			var below: Button = rows[(r+1)%rows.size()][0]
			entry.focus_neighbor_top = entry.get_path_to(above)
			entry.focus_neighbor_bottom = entry.get_path_to(below)
			if row.size() > 1:
				entry.focus_neighbor_left = entry.get_path_to(row[(c-1+row.size())%row.size()])
				entry.focus_neighbor_right = entry.get_path_to(row[(c+1)%row.size()])
			else:
				entry.focus_neighbor_left = NodePath()
				entry.focus_neighbor_right = NodePath()

func _set_context(value: String) -> void:
	if page == "home":return
	if not is_instance_valid(context_label): return
	if context_tween: context_tween.kill()
	if not value.is_empty(): context_label.text = Localization.t(value)
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
	clear("ZOMBIX HEAD" if not world.started else "PAUSED","")
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
					Session.info(Localization.t("Local address copied / UDP {0}", [Session.endpoint_port])))
			else: button("CONTROLS",0,controls)
		else:
			if not world.automated and SaveManager.has_save():
				button("CONTINUE",0,func() -> void: world.continue_save())
			button("PLAY",0,func() -> void: Session.launch())
			button("MULTIPLAYER",0,network_menu)
			button("CHARACTER",0,skins)
			button("OPTIONS",0,options_menu)
		button("EXIT GAME",0,func() -> void: Session.leave(); get_tree().quit())
		roster_label = label("",Vector2(600,790),17,Color(0.72,0.78,0.72,0.65))
		roster_label.name = "CampRoster"
		roster_label.size = Vector2(740,70)
	refresh()

func refresh() -> void:
	if status_label:
		status_label.text = "" if Session.status in ["Choose how to play","Session closed"] else Localization.t(Session.status)
	if roster_label:
		if Session.online:
			var text := Localization.t("CONNECTED  {0} / 4\n", [Session.roster.size()])
			var index := 0
			for id in Session.roster:
				var profile: Dictionary = Session.roster[id]
				text += "%s · %s     " % [profile.name,Localization.t("READY" if profile.ready else "PREPARING")]
				index += 1
				if index%2==0: text += "\n"
			roster_label.position.y = 755
			roster_label.text = text
			if multiplayer.is_server(): roster_label.text += Localization.t("LOCAL  {0}  /  UDP {1}", [Session.local_address(),Session.endpoint_port])
		else: roster_label.text = ""
	if ready_button and Session.roster.has(multiplayer.get_unique_id()):
		var ready: bool = Session.roster[multiplayer.get_unique_id()].ready
		ready_button.text = Localization.t("READY" if ready else "READY UP")
		ready_button.selected = ready

func _toggle_ready() -> void:
	if Session.roster.has(multiplayer.get_unique_id()): Session.set_ready(not Session.roster[multiplayer.get_unique_id()].ready)

func field(at: Vector2, value: String, placeholder: String) -> LineEdit:
	var line := LineEdit.new()
	line.position = at
	line.size = Vector2(330,42)
	line.text = value
	line.placeholder_text = Localization.t(placeholder)
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
	connection_hosting = hosting
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
		label("LAN GAMES",Vector2(560,270),16)
		lan_box = VBoxContainer.new()
		lan_box.name = "LanGames"
		lan_box.position = Vector2(557,297)
		lan_box.add_theme_constant_override("separation",9)
		page_root.add_child(lan_box)
		lan_name = username
		_lan_list()
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

## Una voce per ogni campo annunciato nella rete locale: un clic e si entra.
func _lan_list() -> void:
	if not is_instance_valid(lan_box): return
	for child in lan_box.get_children():
		for entry in entries.duplicate():
			if child.is_ancestor_of(entry): entries.erase(entry)
		child.queue_free()
	if Session.lan_games.is_empty():
		var wait := Label.new()
		wait.text = Localization.t("Searching the local network…")
		wait.add_theme_font_size_override("font_size",19)
		wait.modulate = Color("b4b8a9")
		lan_box.add_child(wait)
		return
	for ip in Session.lan_games:
		var game: Dictionary = Session.lan_games[ip]
		var title := Localization.t("JOIN {0}  ·  {1}/4", [game.name, game.count])
		button(title,0,func() -> void:
			Session.profile(lan_name.text if is_instance_valid(lan_name) else Session.nickname,Session.skin)
			world._save_preferences()
			if Session.join(ip,game.port)==OK:
				get_tree().paused = false
				home(),"",lan_box,420)

func skins() -> void:
	page = "skins"
	clear("CHARACTER","WHO WILL YOU BRING INTO THE DARK?")
	# Dieci skin del ZX Player: il personaggio al falò cambia subito.
	var names: Array = preload("res://ui/camp/camp.gd").NAMES
	var count: int = names.size()
	label("%02d / %02d" % [Session.skin+1,count],Vector2(81,252),15,Color("ffb703"))
	label(str(names[Session.skin]),Vector2(81,272),40)
	label(str(preload("res://art/zx_player/zx_player.gd").SKINS[Session.skin][1]),Vector2(81,326),19,Color(0.82,0.84,0.78,0.85))
	var card := button_row()
	var previous := button("◀  PREVIOUS",0,func() -> void: world.choose_skin(posmod(Session.skin-1,count)); skins(),"",card,181)
	var next := button("NEXT  ▶",0,func() -> void: world.choose_skin(posmod(Session.skin+1,count)); skins(),"",card,181)
	for entry in [previous,next]: entry.add_theme_font_size_override("font_size",26)
	button("BACK",0,home)
	menu_list.position.y = 400

func settings() -> void:
	page = "settings"
	clear("SETTINGS","MAKE THE NIGHT YOUR OWN")
	label("EFFECTS VOLUME",Vector2(81,270),18)
	slider("volume",Vector2(81,308),0,100,1)
	label("LOOK SENSITIVITY",Vector2(81,365),18)
	slider("sensitivity",Vector2(81,403),0.3,2,0.05)
	check("Blood effects","blood",469)
	label("DISPLAY AND VISUAL QUALITY ARE IN\nOPTIONS  ›  GRAPHICS.",Vector2(81,540),19,Color("b4b8a9"))
	button("GRAPHICS",0,graphics)
	button("%s  ·  %s" % [Localization.t("LANGUAGE"), Localization.language_name()],0,func() -> void: language("settings"))
	button("BACK",0,_options_or_home)
	menu_list.position.y = 610
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
	control.text = Localization.t(title)
	control.button_pressed = world.settings_data[key]
	control.add_theme_font_size_override("font_size",23)
	page_root.add_child(control)
	control.toggled.connect(func(value: bool) -> void: world.settings_data[key]=value; world._apply_settings())

func graphics() -> void:
	page = "graphics"
	clear("GRAPHICS","SO THE NIGHT RUNS AS WELL AS IT LOOKS")
	graphics_controls.clear()
	graphics_dirty = false
	var data: Dictionary = world.settings_data
	# Le scelte restano in sospeso: solo APPLY le passa al gioco e le salva.
	graphics_pending = {
		"display_mode":int(data.display_mode),
		"resolution":str(data.resolution),
		"vsync":int(data.vsync),
		"quality":int(data.quality),
		"textures":int(data.textures),
		"shadow_quality":int(data.shadow_quality),
		"anti_aliasing":int(data.anti_aliasing),
		"vegetation":int(data.get("vegetation",2)),
		"atmosphere":int(data.get("atmosphere",1))
	}
	_graphic_option("DISPLAY MODE",250,["WINDOWED","BORDERLESS","FULLSCREEN"],int(graphics_pending.display_mode),func(index: int) -> void:
		graphics_pending.display_mode = index
		_mark_graphics_dirty(),"display_mode")
	# Le risoluzioni arrivano dal monitor: niente voci fuori portata.
	var sizes: Array = world.monitor_resolutions()
	var names: Array = []
	var selected := 0
	var current: Vector2i = world.resolution_size()
	for i in range(sizes.size()):
		names.append("%d × %d" % [sizes[i].x,sizes[i].y])
		if sizes[i] == current: selected = i
	_graphic_option("RESOLUTION",294,names,selected,func(index: int) -> void:
		var size: Vector2i = sizes[clampi(index,0,sizes.size()-1)]
		graphics_pending.resolution = "%dx%d" % [size.x,size.y]
		_mark_graphics_dirty(),"resolution")
	_graphic_option("V-SYNC",338,["OFF","ON","ADAPTIVE"],int(graphics_pending.vsync),func(index: int) -> void:
		graphics_pending.vsync = index
		_mark_graphics_dirty(),"vsync")
	_graphic_option("OVERALL QUALITY",382,["LOW","MEDIUM","HIGH","ULTRA"],int(graphics_pending.quality),func(index: int) -> void:
		var preset: Dictionary = world.quality_preset_values(index)
		graphics_pending.quality = index
		graphics_pending.textures = int(preset.textures)
		graphics_pending.shadow_quality = int(preset.shadow_quality)
		graphics_pending.anti_aliasing = int(preset.anti_aliasing)
		graphics_pending.vegetation = int(preset.vegetation)
		graphics_pending.atmosphere = int(preset.atmosphere)
		_sync_graphics_controls()
		_mark_graphics_dirty(),"overall_quality")
	_graphic_option("TEXTURE QUALITY",426,["LOW","MEDIUM","HIGH","ULTRA"],int(graphics_pending.textures),func(index: int) -> void:
		graphics_pending.textures = index
		_mark_graphics_dirty(),"texture_quality")
	_graphic_option("SHADOW QUALITY",470,["OFF","LOW","MEDIUM","HIGH","ULTRA"],int(graphics_pending.shadow_quality),func(index: int) -> void:
		graphics_pending.shadow_quality = index
		_mark_graphics_dirty(),"shadow_quality")
	_graphic_option("ANTI-ALIASING",514,["OFF","FXAA","MSAA 2×","MSAA 4×","MSAA 8×"],int(graphics_pending.anti_aliasing),func(index: int) -> void:
		graphics_pending.anti_aliasing = index
		_mark_graphics_dirty(),"anti_aliasing")
	_graphic_option("VEGETATION",558,["LOW","MEDIUM","HIGH","ULTRA"],int(graphics_pending.vegetation),func(index: int) -> void:
		graphics_pending.vegetation = index
		_mark_graphics_dirty(),"vegetation")
	_graphic_option("ATMOSPHERE EFFECTS",602,["OFF","ON"],int(graphics_pending.atmosphere),func(index: int) -> void:
		graphics_pending.atmosphere = index
		_mark_graphics_dirty(),"atmosphere")
	graphics_status = label(Localization.t("ADJUST THE SETTINGS, THEN PRESS APPLY."),Vector2(81,640),15,Color(0.70,0.74,0.69,0.75))
	graphics_status.name = "GraphicsStatus"
	button("APPLY",0,_apply_graphics_pending)
	button("BACK",0,func() -> void: graphics_pending.clear(); _options_or_home())
	menu_list.position.y = 668
	context_label.hide()

func _restore_graphics_pending(pending: Dictionary, dirty: bool) -> void:
	if pending.is_empty(): return
	graphics_pending = pending
	var picks := {"display_mode":int(pending.display_mode),"vsync":int(pending.vsync),"overall_quality":int(pending.quality)}
	for key in picks: graphics_controls[key].select(picks[key])
	var sizes: Array = world.monitor_resolutions()
	for i in range(sizes.size()):
		if "%dx%d" % [sizes[i].x,sizes[i].y] == str(pending.resolution): graphics_controls.resolution.select(i)
	_sync_graphics_controls()
	if dirty: _mark_graphics_dirty()

func _mark_graphics_dirty() -> void:
	graphics_dirty = true
	if graphics_status and is_instance_valid(graphics_status):
		graphics_status.text = Localization.t("UNSAVED CHANGES  ·  PRESS APPLY")
		graphics_status.add_theme_color_override("font_color",Color("ffb703"))

## Passa al gioco tutte le scelte sospese della pagina Graphics in un colpo solo.
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

func _graphic_option(title: String, y: float, items: Array, selected: int, callback: Callable, key: String = "") -> OptionButton:
	label(title,Vector2(81,y),18)
	var control := OptionButton.new()
	control.name = key.to_pascal_case() if not key.is_empty() else title.to_pascal_case()
	control.position = Vector2(248,y-5)
	control.size = Vector2(200,38)
	control.focus_mode = Control.FOCUS_ALL
	control.add_theme_font_size_override("font_size",19)
	_style_option(control)
	for item in items: control.add_item(Localization.t(str(item)))
	control.select(clampi(selected,0,maxi(items.size()-1,0)))
	page_root.add_child(control)
	control.item_selected.connect(callback)
	if not key.is_empty(): graphics_controls[key] = control
	return control

func _style_option(control: OptionButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05,0.07,0.065,0.45)
	normal.border_width_bottom = 1
	normal.border_color = Color("8a8977")
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	var hover := normal.duplicate()
	hover.bg_color = Color(0.09,0.11,0.095,0.75)
	hover.border_color = Color("ffb703")
	var focus := hover.duplicate()
	focus.border_width_bottom = 2
	for state in ["normal","hover","pressed","focus"]:
		control.add_theme_stylebox_override(state,normal if state == "normal" else (focus if state == "focus" else hover))
	control.add_theme_color_override("font_color",Color("d4d6c9"))
	control.add_theme_color_override("font_hover_color",Color("ffb703"))
	control.add_theme_color_override("font_focus_color",Color("ffb703"))
	control.add_theme_color_override("font_pressed_color",Color("ff6b00"))
	var popup := control.get_popup()
	popup.add_theme_font_size_override("font_size",19)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035,0.05,0.045,0.98)
	panel.set_border_width_all(1)
	panel.border_color = Color(0.45,0.42,0.32,0.85)
	popup.add_theme_stylebox_override("panel",panel)
	popup.add_theme_color_override("font_color",Color("d4d6c9"))
	popup.add_theme_color_override("font_hover_color",Color("ffb703"))

func _sync_graphics_controls() -> void:
	for pair in [["texture_quality",int(graphics_pending.textures)],["shadow_quality",int(graphics_pending.shadow_quality)],["anti_aliasing",int(graphics_pending.anti_aliasing)],["vegetation",int(graphics_pending.vegetation)],["atmosphere",int(graphics_pending.atmosphere)]]:
		var control: OptionButton = graphics_controls.get(pair[0])
		if control: control.select(clampi(int(pair[1]),0,control.item_count-1))

func controls() -> void:
	page = "controls"
	clear("CONTROLS","STAY ALIVE. STAY TOGETHER.")
	label("WASD\nMOUSE\nSHIFT\nSPACE\nCTRL (hold)\nCLICK / HOLD\nE\nESC",Vector2(81,277),25,Color("d4ad76"))
	label("Move\nFirst-person look\nSprint\nJump\nCrouch\nStrike / charged strike\nCollect / activate\nPause menu",Vector2(267,277),25)
	label("Collect the supplies. Defend the radio.\nThe world keeps moving while you pause online.\n\nMENU / arrows or D-pad · Enter or A to select",Vector2(81,600),19,Color("b4b8a9"))
	button("BACK",0,_options_or_home)
	menu_list.position.y = 740
	context_label.hide()

## Dalle pagine di Opzioni si torna a Opzioni; in pausa si torna al menu di pausa.
func _options_or_home() -> void:
	if world.started: home()
	else: options_menu()

func network_menu() -> void:
	page="multiplayer"
	clear("MULTIPLAYER")
	button("HOST GAME",0,func() -> void: connection(true))
	button("JOIN FRIENDS",0,func() -> void: connection(false))
	button("BACK",0,home)

func options_menu() -> void:
	page="options"
	clear("OPTIONS")
	button("SETTINGS",0,settings)
	button("GRAPHICS",0,graphics)
	button("LANGUAGE",0,func() -> void: language("options"))
	button("CONTROLS",0,controls)
	button("BACK",0,home)

## Selettore lingua: inglese predefinito, italiano disponibile; il cambio è immediato.
func language(return_to: String = "options") -> void:
	language_return = return_to
	page = "language"
	clear("LANGUAGE","CHOOSE THE LANGUAGE OF THE GAME")
	for entry in Localization.LANGUAGES:
		var code: String = str(entry.code)
		var label_text: String = str(entry.name)
		if code == Localization.current:
			label_text += "  ·  " + Localization.t("SELECTED")
		button(label_text,0,func() -> void: select_language(code))
	label(Localization.t("THE CHANGE APPLIES IMMEDIATELY"),Vector2(81,520),18,Color("b4b8a9"))
	button("BACK",0,func() -> void:
		if language_return == "settings": settings()
		else: options_menu())
	menu_list.position.y = 294
	context_label.hide()

func select_language(code: String) -> void:
	Localization.set_language(code)
	language(language_return)
