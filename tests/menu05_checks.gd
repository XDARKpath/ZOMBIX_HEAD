# Prova input GUI reale, transizioni di focus, pagine e rig del menu.
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
	check(menu.entries.size()==7,"Seven native menu buttons")
	var labels: Array = []
	for entry in menu.entries: labels.append(entry.text)
	check(labels==["SOLO","HOST GAME","JOIN FRIENDS","CHARACTER","SETTINGS","CONTROLS","EXIT GAME"],"English menu hierarchy")
	check(menu.get_node("ForestVeil").material!=null,"Soft shader gradient replaces solid panel")
	check(menu.entries[0].get_theme_stylebox("normal") is StyleBoxEmpty,"Borderless native buttons")
	check(menu.entries[0].get_theme_font("font").resource_path.ends_with("BarlowCondensed-SemiBold.ttf"),"Bundled display font")
	check(menu.context_label.modulate.a<0.01,"Context hidden before selection")
	var host: Button = menu.entries[1]
	host.grab_focus()
	await world.get_tree().create_timer(0.5,true).timeout
	check(host.hover_amount>0.9 and host.position.x>8,"Keyboard focus animates warm selection and slide")
	check(menu.context_label.text.contains("three friends") and menu.context_label.modulate.a>0.9,"Host contextual text fades in")
	host.held = true
	await world.get_tree().create_timer(0.3,true).timeout
	check(host.scale.x<0.985,"Tactile press scales the native button")
	host.held = false
	var press := InputEventAction.new()
	press.action = "ui_accept"
	press.pressed = true
	Input.parse_input_event(press)
	await frames(2)
	var release := InputEventAction.new()
	release.action = "ui_accept"
	release.pressed = false
	Input.parse_input_event(release)
	await frames(5)
	check(menu.page=="connect","Native accept opens the host form")
	for child in menu.page_root.get_children():
		if child is SpinBox: child.value=27850
	menu.entries[0].pressed.emit()
	await frames(5)
	check(Session.online and menu.page=="home" and Session.roster.size()==1,"Host form opens a real camp lobby")
	var connected_visible := 0
	for avatar in world.camp.avatars:
		if avatar.visible: connected_visible += 1
	check(connected_visible==1,"Online camp shows actual connected players")
	Session.leave()
	menu.home()
	await frames(3)
	var move := InputEventMouseMotion.new()
	move.position = menu.entries[2].get_global_rect().get_center()
	move.global_position = move.position
	move.relative = Vector2(1,1)
	world.get_viewport().push_input(move,true)
	await world.get_tree().create_timer(0.5,true).timeout
	check(menu.entries[2].pointer_inside and menu.entries[2].hover_amount>0.9,"Pointer hover uses native GUI hit testing")
	move = InputEventMouseMotion.new()
	move.position = Vector2(1400,600)
	move.global_position = move.position
	move.relative = Vector2(1,1)
	world.get_viewport().push_input(move,true)
	menu.entries[0].grab_focus()
	# The fade uses elapsed time; headless frame counts vary with import/load speed.
	await world.get_tree().create_timer(0.8,true).timeout
	check(menu.context_label.modulate.a<0.01,"Solo selection has no network description")
	menu.skins()
	check(menu.page=="skins" and menu.entries.size()==4,"Character page retains three skin choices and Back")
	var before: Node3D = world.camp.avatars[1]
	world._roster_changed()
	check(before==world.camp.avatars[1],"Roster refresh preserves the idle animation instance")
	world.choose_skin(2)
	check(world.camp.skin_ids[0]==2,"Skin choice changes the camp preview")
	menu.settings()
	check(menu.page=="settings","Settings remain accessible")
	menu.controls()
	check(menu.page=="controls","Controls remain accessible")
	menu.home()
	var visible_count := 0
	var distinct: Array = []
	var grounded := true
	for avatar in world.camp.avatars:
		if avatar.visible: visible_count += 1
		distinct.append(avatar.stance)
		if avatar.bone_ids.has("foot_l"):
			grounded = grounded and (avatar.skeleton.global_transform*avatar.skeleton.get_bone_global_pose(avatar.bone_ids.foot_l)).origin.y>=0
	check(visible_count==4 and distinct==[0,1,2,3],"Four visible survivors with four different poses")
	check(grounded,"Feet remain above the campsite ground")
	var actor: Node3D = world.camp.avatars[3]
	actor.clock = 1
	actor._pose(0)
	var bone: int = actor.bone_ids.get("head",-1)
	var first: Quaternion = actor.skeleton.get_bone_pose_rotation(bone)
	actor.clock = 5
	actor._pose(0)
	check(not first.is_equal_approx(actor.skeleton.get_bone_pose_rotation(bone)),"Fourth survivor has an animated gaze")
	check(world.camp.avatars[2].sniper!=null and world.camp.avatars[3].katana!=null,"Sniper rifle and katana present on their survivors")
	check(menu.get_node("ForegroundEmbers").mouse_filter==Control.MOUSE_FILTER_IGNORE,"Foreground embers never intercept clicks")
	print("MENU05: ",failures.size()," errors")
	return failures.is_empty()

