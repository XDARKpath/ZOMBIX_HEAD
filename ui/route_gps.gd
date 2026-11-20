extends Control
const Route=preload("res://world/campaign/route.gd")
const Terrain=preload("res://world/campaign/terrain.gd")
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
		var goal:Vector3=mission.target_point()
		var near:float=world.player.position.distance_to(goal)
		text+="\n"+Localization.t("DISTANZA  {0} m",[int(near)])+"   ·   "+heading_text(goal)+"\n"
		text+=height_text(goal)+"\n"
		# Il luogo vicino solo quando serve: ci sei dentro o è a due passi, con la direzione.
		var place:Dictionary=Route.nearby_place(world.player.position,PLACE_RANGE)
		if not place.is_empty():
			var title:String=Localization.t(str(place.title))
			text+=(Localization.t("SEI A  {0}",[title]) if place.distance<PLACE_HERE else Localization.t("{0}  ·  {1} m  {2}",[title,int(place.distance),compass(_place_at(place))]))+"\n"
	if mission.stage==2:
		var distance:float=world.player.position.distance_to(Route.POINTS[mission.unlocked])
		text+=Localization.t("DISTANZA  {0} km   ·   4×4  {1} / 4",["%.2f"%(distance/1000.0),4-mission.car.seats.count(0)])+"\n"
	text+=Localization.t("G  CHIUDI  ·  Il mondo rimane attivo")
	return text

const PLACE_RANGE:=200.0
const PLACE_HERE:=60.0
const COMPASS:=["NORD","NORD-EST","EST","SUD-EST","SUD","SUD-OVEST","OVEST","NORD-OVEST"]
const SIDES:=["davanti","avanti a destra","a destra","dietro a destra","dietro","dietro a sinistra","a sinistra","avanti a sinistra"]

## Punto cardinale verso un punto (nord = -Z, come il radar).
func compass(at:Vector3) -> String:
	var d:Vector3=at-world.player.position
	return Localization.t(COMPASS[_sector(atan2(d.x,-d.z))])

## "NORD-EST  ·  avanti a destra": dove sta l'obiettivo sulla rosa e rispetto a dove guardi.
func heading_text(at:Vector3) -> String:
	var d:Vector3=at-world.player.position
	var bearing:=atan2(d.x,-d.z)
	var yaw:float=world.player.rig.yaw
	var facing:=atan2(-sin(yaw),cos(yaw))
	return Localization.t(COMPASS[_sector(bearing)])+"  ·  "+Localization.t(SIDES[_sector(bearing-facing)])

## Quota dell'obiettivo rispetto a te; i punti della rotta stanno a quota 0, quindi si legge il terreno.
func height_text(at:Vector3) -> String:
	var y:float=at.y if absf(at.y)>0.01 else Terrain.ground_height(at.x,at.z)
	var rise:=int(round(y-world.player.global_position.y))
	if absi(rise)<3:return Localization.t("QUOTA  stessa altezza")
	return Localization.t("QUOTA  +{0} m · sali",[rise]) if rise>0 else Localization.t("QUOTA  {0} m · scendi",[rise])

func _sector(angle:float) -> int:
	return int(round(wrapf(angle,0.0,TAU)/(TAU/8.0)))%8

func _place_at(place:Dictionary) -> Vector3:
	if str(place.title)=="BORGO CENERE":return Route.Village.CENTER
	for row in Route.places():
		if row.title==place.title:return row.at
	return world.player.position

func _draw() -> void:
	var panel:=StyleBoxFlat.new();panel.bg_color=Color(0.025,0.055,0.05,0.95)
	draw_style_box(panel,Rect2(400,170,650,650))
	draw_rect(Rect2(400,170,4,650),Color("e2b56d"))
