extends Control
const Route=preload("res://world/campaign/route.gd")
var world:Node3D
var opened:bool=false
# Con le braccia FPS il GPS compare sul PDA tenuto in mano (player/viewmodel/pda.gd).
var embedded:bool=false
var label:Label
func build(owner_world:Node3D) -> void:
	world=owner_world;mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label=Label.new();label.position=Vector2(435,208);label.add_theme_font_size_override("font_size",18)
	var font:=SystemFont.new();font.font_names=PackedStringArray(["Bahnschrift","Segoe UI"])
	label.add_theme_font_override("font",font);add_child(label)
func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_G and world.started and not world.ui_open:
		opened=not opened;get_viewport().set_input_as_handled()
func _process(_delta:float) -> void:
	visible=opened and world.started and not world.ui_open and not embedded
	if not visible: return
	label.text=screen_text()
	queue_redraw()
func screen_text() -> String:
	var mission:Node3D=world.expedition
	var text:=Localization.t("FIELD GPS  /  ZONA {0}",[mission.zone_index+1])+"\n\n"
	if mission.stage==0 or mission.stage==1:
		text+=world.quest.steps_text()+"\n\n"
	else:
		for i in range(8):
			text+=("●  %02d  %s"%[i+1,Localization.t(Route.TITLES[i])] if i<=mission.unlocked else "·  %02d  %s"%[i+1,Localization.t("COORDINATE BLOCCATE")])+"\n"
		text+="\n"
	text+=mission.title()+"\n"+mission.detail()+"\n"
	# Nella Rocca e nella Cripta il segnale non arriva.
	if world.player.position.y>150.0:text+="\n"+Localization.t("NESSUN SEGNALE SOTTO TERRA")+"\n"
	else:
		var near:float=world.player.position.distance_to(mission.target_point())
		text+="\n"+Localization.t("DISTANZA  {0} m",[int(near)])+"\n"
		var place:Dictionary=Route.nearby_place(world.player.position)
		if not place.is_empty():text+=Localization.t("LUOGO VICINO  {0}  ·  {1} m",[Localization.t(str(place.title)),int(place.distance)])+"\n"
	if mission.stage==2:
		var distance:float=world.player.position.distance_to(Route.POINTS[mission.unlocked])
		text+=Localization.t("DISTANZA  {0} km   ·   4×4  {1} / 4",["%.2f"%(distance/1000.0),4-mission.car.seats.count(0)])+"\n"
	text+=Localization.t("G  CHIUDI  ·  Il mondo rimane attivo")
	return text
func _draw() -> void:
	var panel:=StyleBoxFlat.new();panel.bg_color=Color(0.025,0.055,0.05,0.95)
	draw_style_box(panel,Rect2(400,170,650,650))
	draw_rect(Rect2(400,170,4,650),Color("e2b56d"))
