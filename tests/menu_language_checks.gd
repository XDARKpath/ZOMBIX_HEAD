extends SceneTree
# Ogni testo visibile del menu (tutte le pagine) ha la traduzione italiana e cambia subito con la lingua;
# le impostazioni vengono salvate e ricaricate.
# godot --headless --path . -s res://tests/menu_language_checks.gd
var fails: Array = []


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


## Testi mostrati dalla pagina corrente del menu (Label, Button, OptionButton).
func page_texts(menu: Control) -> Array:
	var out: Array = []
	for node in menu.find_children("*", "", true, false):
		if not node is CanvasItem or node.is_queued_for_deletion() or not node.is_visible_in_tree(): continue
		if node is Label or node is Button: out.append(str(node.text))
		if node is OptionButton:
			for i in node.item_count: out.append(node.get_item_text(i))
	return out


## Testi che non vanno tradotti: numeri, risoluzioni, nomi propri.
func translatable(text: String) -> bool:
	var letters := RegEx.create_from_string("[A-Za-z]{2,}")
	if letters.search(text) == null: return false
	if RegEx.create_from_string("^\\d+ × \\d+$").search(text) or text.contains("English"): return false  # "LINGUA  ·  Italiano" è composto
	return not text in ["ZOMBIX", "H E A D", "English", "Italiano", "FXAA", "MSAA 2×", "MSAA 4×", "MSAA 8×", "WASD", "E", "ESC", "ULTRA", "MOUSE", "SHIFT", "ZOMBIX HEAD", "AUDIO"] and not text.begins_with("VERSION")


func _run() -> void:
	var loc: Node = root.get_node("Localization")
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	world.automated = true
	root.add_child(world)
	for i in 10: await process_frame
	var menu: Control = world.menu
	var names: Array = load("res://ui/camp/camp.gd").NAMES
	var skins: Array = load("res://art/zx_player/zx_player.gd").SKINS
	var pages := {"home": menu.home, "multiplayer": menu.network_menu, "game": menu.settings, "audio": menu.options_menu.bind("audio"),
		"graphics": menu.graphics, "language": menu.language, "controls": menu.controls, "skins": menu.skins, "credits": menu.credits,
		"host": menu.connection.bind(true), "join": menu.connection.bind(false)}
	for page in pages:
		loc.set_language("en")
		pages[page].call()
		var english := page_texts(menu)
		loc.set_language("it")
		await process_frame
		var italian := page_texts(menu)
		for text in english:
			if not translatable(text) or text in names: continue
			var skin_text := false
			for skin in skins: if str(skin[1]) == text: skin_text = true
			if skin_text: continue
			var it_text: String = loc.t(text)
			check(it_text != text and italian.has(it_text), "%s: '%s' in italiano" % [page, text.replace("\n", " / ")])
	# Il cambio lingua rifà la pagina aperta senza lasciare testi inglesi.
	loc.set_language("en")
	menu.settings()
	loc.set_language("it")
	await process_frame
	check(menu.page == "options" and menu.tab == "game" and page_texts(menu).has("OPZIONI"), "Cambio lingua: la pagina aperta si aggiorna subito")
	# Le scelte grafiche non applicate restano dopo il cambio lingua.
	menu.graphics()
	var vsync = menu.graphics_controls.vsync
	var wanted: int = (vsync.selected + 1) % vsync.item_count
	vsync.select(wanted)
	vsync.item_selected.emit(wanted)
	loc.set_language("en")
	await process_frame
	check(menu.graphics_controls.vsync.selected == wanted and int(menu.graphics_pending.vsync) == wanted and menu.graphics_dirty, "Cambio lingua: le modifiche grafiche non applicate restano")
	# Salvataggio e ricarica delle impostazioni.
	world.automated = false
	var saved: Dictionary = world.settings_data.duplicate()
	world.settings_data.volume = 33.0
	world.settings_data.sensitivity = 1.45
	world.settings_data.blood = false
	world.settings_data.vsync = 2
	world.settings_data.quality = 1
	world.settings_data.textures = 1
	world.settings_data.shadow_quality = 2
	world.settings_data.anti_aliasing = 2
	world.settings_data.display_mode = 0
	world._save_preferences()
	var expected: Dictionary = world.settings_data.duplicate()
	for key in world.settings_data: world.settings_data[key] = saved[key]
	world._load_preferences()
	var same := true
	for key in ["volume", "sensitivity", "blood", "vsync", "quality", "textures", "shadow_quality", "anti_aliasing", "display_mode"]:
		if str(world.settings_data[key]) != str(expected[key]):
			same = false
			print("  diverso: ", key, " ", world.settings_data[key], " != ", expected[key])
	check(same, "Impostazioni salvate in user://preferences.cfg e ricaricate uguali")
	for key in saved: world.settings_data[key] = saved[key]
	world._save_preferences()
	world.automated = true
	print("MENU_LINGUE: %d errori" % fails.size())
	quit(0 if fails.is_empty() else 1)
