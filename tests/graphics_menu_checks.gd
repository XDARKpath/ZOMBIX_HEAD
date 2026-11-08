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
	# La voce GRAPHICS compare nell'elenco verticale OPTIONS.
	menu.options_menu()
	var labels: Array = []
	for entry in menu.entries: labels.append(entry.text)
	check(labels==["SETTINGS","GRAPHICS","LANGUAGE","CONTROLS","BACK"],"Graphics and language inserted in Options")
	check(menu.entries[0].get_node_or_null(menu.entries[0].focus_neighbor_bottom)==menu.entries[1],"Vertical focus links adjacent menu entries")
	# La pagina Graphics contiene tutti i controlli richiesti.
	menu.graphics()
	check(menu.page=="graphics","Graphics page opens")
	var resolution: OptionButton = menu.page_root.find_child("Resolution",true,false)
	check(resolution is OptionButton and resolution.item_count==sizes.size(),"Resolution dropdown lists every detected mode")
	check(resolution.get_item_text(resolution.selected)=="%d × %d" % [world.resolution_size().x,world.resolution_size().y],"Resolution dropdown selects the active mode")
	check(menu.graphics_controls.has("texture_quality") and menu.graphics_controls.has("shadow_quality") and menu.graphics_controls.has("anti_aliasing"),"Texture, shadow and anti-aliasing dropdowns exist")
	check(menu.page_root.find_child("DisplayMode",true,false)!=null and menu.page_root.find_child("Vsync",true,false)!=null and menu.page_root.find_child("OverallQuality",true,false)!=null,"Display mode, V-Sync and quality preset exist")
	# Le modifiche restano in sospeso finché non si preme APPLY.
	var original: Vector2i = world.resolution_size()
	var target: Vector2i = sizes[0]
	resolution.select(0)
	resolution.item_selected.emit(0)
	var quality: OptionButton = menu.graphics_controls.get("overall_quality")
	quality.select(0)
	quality.item_selected.emit(0)
	await frames(2)
	check(world.resolution_size()==original and str(menu.graphics_pending.resolution)=="%dx%d" % [target.x,target.y],"Graphics changes stay pending until Apply")
	check(int(menu.graphics_pending.quality)==0 and menu.graphics_controls.texture_quality.selected==0 and menu.graphics_controls.shadow_quality.selected==0,"Preset updates the lower dropdowns before Apply")
	var apply: Button
	for entry in menu.entries:
		if entry.text=="APPLY": apply = entry
	check(apply!=null and menu.entries.size()==2 and menu.entries[1].text=="BACK","Apply button sits above Back")
	apply.pressed.emit()
	await frames(3)
	check(world.resolution_size()==target and str(world.settings_data.resolution)=="%dx%d" % [target.x,target.y],"Apply commits the resolution")
	check(int(world.settings_data.quality)==0 and int(world.settings_data.textures)==0 and int(world.settings_data.shadow_quality)==0 and int(world.settings_data.anti_aliasing)==0,"Apply commits the whole preset")
	check(menu.graphics_status.text=="SETTINGS APPLIED","Apply confirms in the panel")
	# Il preset HIGH si riflette nei menu e viene applicato con lo stesso tasto.
	quality.select(2)
	quality.item_selected.emit(2)
	await frames(2)
	check(menu.graphics_controls.texture_quality.selected==2 and menu.graphics_controls.shadow_quality.selected==3,"High preset updates the lower dropdowns")
	apply.pressed.emit()
	await frames(3)
	check(int(world.settings_data.quality)==2 and int(world.settings_data.textures)==2 and int(world.settings_data.shadow_quality)==3,"Apply commits the high preset")
	# NEXT / PREVIOUS sono affiancati nella stessa riga.
	menu.skins()
	await frames(2)
	check(menu.entries.size()==3,"Character page keeps its three rows")
	var previous: Button = menu.entries[0]
	var next: Button = menu.entries[1]
	var same_row: bool = previous.get_parent().get_parent()==next.get_parent().get_parent()
	check(same_row and previous.get_parent().position.y==next.get_parent().position.y,"NEXT and PREVIOUS share one horizontal row")
	check(previous.get_parent().position.x<next.get_parent().position.x,"PREVIOUS sits left of NEXT")
	check(previous.get_node_or_null(previous.focus_neighbor_right)==next and next.get_node_or_null(next.focus_neighbor_left)==previous,"Left and right focus stay inside the row")
	check(previous.get_node_or_null(previous.focus_neighbor_bottom)==menu.entries[2] and next.get_node_or_null(next.focus_neighbor_bottom)==menu.entries[2],"Moving down from the row reaches Back")
	print("GRAPHICS_MENU: ",failures.size()," errors")
	return failures.is_empty()
