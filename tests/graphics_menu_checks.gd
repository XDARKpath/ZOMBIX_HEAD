# Verifica menu: voci orizzontali, pagina GRAPHICS e risoluzioni del monitor.
extends RefCounted
var failures: Array[String] = []
var world: Node3D
func check(value: bool, message: String) -> void:
	print("PASS " if value else "FAIL ",message)
	if not value: failures.append(message)
func frames(count: int) -> void:
	for i in range(count): await world.get_tree().process_frame
func run(scene: Node3D) -> bool:
	world = scene
	await frames(4)
	var menu: Control = world.menu
	# Risoluzioni rilevate dal monitor: mai oltre la nativa, sempre ordinabili.
	var native: Vector2i = world._native_resolution()
	var sizes: Array = world.monitor_resolutions()
	check(not sizes.is_empty() and sizes.has(native),"Native monitor resolution detected")
	var inside := true
	for size in sizes:
		if size.x > native.x or size.y > native.y: inside = false
	check(inside and sizes.has(world.resolution_size()),"Resolution list stays within the monitor and contains the current mode")
	var ordered := true
	var seen := {}
	for i in range(sizes.size()):
		if seen.has(sizes[i]): ordered = false
		seen[sizes[i]] = true
		if i > 0 and (sizes[i].x < sizes[i-1].x or (sizes[i].x == sizes[i-1].x and sizes[i].y < sizes[i-1].y)): ordered = false
	check(ordered,"Resolution list has no duplicates and is ordered by width then height")
	check(not sizes.has(Vector2i(1360,768)) and sizes.has(Vector2i(1366,768)),"Ladder keeps the standard 1366x768 only")
	check(is_equal_approx(world.render_scale_for(native),1.0),"Native resolution renders at full scale")
	if sizes[0] != native:
		check(world.render_scale_for(sizes[0]) < 1.0,"Lower resolutions scale the fullscreen render")
	# Opzioni: schede in alto e Indietro in basso a destra.
	menu.options_menu("game")
	var labels: Array = []
	for entry in menu.entries: labels.append(entry.text)
	check(labels==["GAME","GRAPHICS","AUDIO","CONTROLS","LANGUAGE","[Esc]  BACK"],"Options tabs and Back")
	var back: Button = menu.entries[-1]
	check(back.get_global_rect().position.x > 1000 and back.get_global_rect().position.y > 700,"Back sits bottom right")
	# Esc torna alla home.
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	menu._unhandled_input(esc)
	check(menu.page=="home","Esc goes back from Options")
	# La scheda Grafica contiene tutti i controlli richiesti.
	menu.graphics()
	await frames(2)
	check(menu.page=="options" and menu.tab=="graphics","Graphics tab opens")
	var resolution: OptionButton = menu.page_root.find_child("Resolution",true,false)
	check(resolution is OptionButton and resolution.item_count==sizes.size(),"Resolution dropdown lists every detected mode")
	check(resolution.get_item_text(resolution.selected)=="%d × %d" % [world.resolution_size().x,world.resolution_size().y],"Resolution dropdown selects the active mode")
	check(menu.graphics_controls.has("texture_quality") and menu.graphics_controls.has("shadow_quality") and menu.graphics_controls.has("anti_aliasing"),"Texture, shadow and anti-aliasing choices exist")
	check(menu.page_root.find_child("DisplayMode",true,false)!=null and menu.page_root.find_child("Vsync",true,false)!=null and menu.page_root.find_child("OverallQuality",true,false)!=null,"Display mode, V-Sync and quality preset exist")
	# Le modifiche restano in sospeso finché non si preme APPLY.
	var original: Vector2i = world.resolution_size()
	var target: Vector2i = sizes[0]
	resolution.select(0)
	resolution.item_selected.emit(0)
	var quality = menu.graphics_controls.get("overall_quality")
	quality.select(0)
	quality.item_selected.emit(0)
	await frames(2)
	check(world.resolution_size()==original and str(menu.graphics_pending.resolution)=="%dx%d" % [target.x,target.y],"Graphics changes stay pending until Apply")
	check(int(menu.graphics_pending.quality)==0 and menu.graphics_controls.texture_quality.selected==0 and menu.graphics_controls.shadow_quality.selected==0,"Preset updates the lower choices before Apply")
	var apply: Button
	var cancel: Button
	var defaults: Button
	for entry in menu.entries:
		if entry.text=="APPLY": apply = entry
		if entry.text=="CANCEL": cancel = entry
		if entry.text=="DEFAULTS": defaults = entry
	check(apply!=null and cancel!=null and defaults!=null,"Bottom bar has Defaults, Apply and Cancel")
	apply.pressed.emit()
	await frames(3)
	check(world.resolution_size()==target and str(world.settings_data.resolution)=="%dx%d" % [target.x,target.y],"Apply commits the resolution")
	check(int(world.settings_data.quality)==0 and int(world.settings_data.textures)==0 and int(world.settings_data.shadow_quality)==0 and int(world.settings_data.anti_aliasing)==0,"Apply commits the whole preset")
	check(menu.graphics_status.text=="SETTINGS APPLIED","Apply confirms in the panel")
	# Il preset HIGH si riflette nelle scelte e viene applicato con lo stesso tasto.
	quality.select(2)
	quality.item_selected.emit(2)
	await frames(2)
	check(menu.graphics_controls.texture_quality.selected==2 and menu.graphics_controls.shadow_quality.selected==3,"High preset updates the lower choices")
	apply.pressed.emit()
	await frames(3)
	check(int(world.settings_data.quality)==2 and int(world.settings_data.textures)==2 and int(world.settings_data.shadow_quality)==3,"Apply commits the high preset")
	# Annulla scarta le scelte in sospeso.
	quality = menu.graphics_controls.get("overall_quality")
	quality.select(0)
	quality.item_selected.emit(0)
	for entry in menu.entries:
		if entry.text=="CANCEL": cancel = entry
	cancel.pressed.emit()
	await frames(3)
	check(int(world.settings_data.quality)==2 and menu.graphics_controls.overall_quality.selected==2 and not menu.graphics_dirty,"Cancel discards pending changes")
	# Le scelte in fila si cambiano anche con sinistra/destra (tastiera e controller).
	var vsync = menu.graphics_controls.vsync
	var before: int = vsync.selected
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	vsync._gui_input(right)
	check(vsync.selected==(before+1)%vsync.item_count and int(menu.graphics_pending.vsync)==vsync.selected,"Right arrow changes a choice row")
	# PRECEDENTE / SUCCESSIVO sono affiancati nella stessa riga.
	menu.skins()
	await frames(2)
	check(menu.entries.size()==3,"Character page keeps its three buttons")
	var previous: Button = menu.entries[0]
	var next: Button = menu.entries[1]
	check(previous.get_parent()==next.get_parent() and previous.get_parent() is HBoxContainer,"NEXT and PREVIOUS share one horizontal row")
	await frames(2)
	check(previous.global_position.x<next.global_position.x,"PREVIOUS sits left of NEXT")
	print("GRAPHICS_MENU: ",failures.size()," errors")
	return failures.is_empty()