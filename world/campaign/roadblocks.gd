extends Node3D
const Route=preload("res://world/campaign/route.gd")
const Props=preload("res://ui/camp/camp_props.gd")
var world:Node3D
var points:Array[Vector3]=[]
var gates:Array[Node3D]=[]
var triggered:Array=[false,false]
var cleared:Array=[false,false]
var timer:float=0
func build(owner_world:Node3D) -> void:
	world=owner_world;name="ForestRoadblocks"
	var route:Array=Route.road_corners()
	# Il primo sbarramento sta dopo il bivio per Borgo Cenere: col 4×4 al borgo ci si arriva sempre.
	for index in [3,6]:
		# Lo sbarramento sta sulla strada vera e ne segue la direzione anche dove curva.
		var chord:Vector3=(route[index+1]-route[index]).normalized()
		var at:Vector3=Route.nearest_road(route[index].lerp(route[index+1],0.55))
		var direction:Vector3=(Route.nearest_road(at+chord*6.0)-Route.nearest_road(at-chord*6.0)).normalized()
		at.y=preload("res://world/campaign/terrain.gd").ground_height(at.x,at.z);points.append(at)
		var gate:=Node3D.new();add_child(gate);gate.position=at;gate.rotation.y=atan2(-direction.x,-direction.z);gates.append(gate)
		var body:=StaticBody3D.new();gate.add_child(body);body.set_meta("road_gate",true)
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(6.5,1.2,0.8);shape.shape=box;shape.position.y=0.6;body.add_child(shape)
		for x in [-2.2,0,2.2]:
			var prop:Node3D=load("res://art/zx_borgo/SM_Prop_RoadBarrier_Small.glb").instantiate();gate.add_child(prop);prop.position.x=x
		var sign:=Label3D.new();gate.add_child(sign);sign.position=Vector3(0,2,0.5);sign.text=Localization.t("STRADA INTERROTTA\nLIBERA L'AREA · E RIMUOVI");sign.font_size=38;sign.pixel_size=0.009
		for x in [-4.2,4.2]:
			Props.box(gate,Vector3(x,0.8,0),Vector3(1,1.6,1),Color("45483a"))
func reset() -> void:
	triggered=[false,false];cleared=[false,false];refresh()
func remaining(index:int) -> int:
	var count:=0
	for e in world.targets:
		if is_instance_valid(e) and not e.dead and e.position.distance_to(points[index])<52:count+=1
	return count
func refresh() -> void:
	for i in gates.size():
		gates[i].visible=not cleared[i]
		for child in gates[i].get_children():
			if child is StaticBody3D:child.collision_layer=0 if cleared[i] else 1
func context(actor:CharacterBody3D) -> String:
	for i in points.size():
		if not cleared[i] and actor.position.distance_to(points[i])<4:
			return Localization.t("E  RIMUOVI SBARRAMENTO") if triggered[i] and remaining(i)==0 else Localization.t("SBARRAMENTO · ELIMINA GLI INFETTI ({0})",[remaining(i)])
	return ""
func clear_near(actor:CharacterBody3D) -> bool:
	if actor.dead or actor.seated:return false
	for i in points.size():
		if triggered[i] and not cleared[i] and actor.position.distance_to(points[i])<4 and remaining(i)==0:
			cleared[i]=true;refresh();world.survival._publish();return true
	return false
func _process(delta:float) -> void:
	if not world.started or not world.survival or not world.survival.authority() or world.expedition.stage!=2 or world.expedition.unlocked!=1:return
	timer-=delta
	if timer>0:return
	timer=0.5
	for i in points.size():
		var nearest:CharacterBody3D=world.nearest_player(points[i])
		if triggered[i] or not nearest or nearest.position.distance_to(points[i])>58:continue
		triggered[i]=true
		world.terrain.ensure_near([nearest.position,world.expedition.car.position])
		world.nav_region.navigation_mesh.filter_baking_aabb=AABB(points[i]+Vector3(-65,-3,-65),Vector3(130,25,130));world.nav_region.bake_navigation_mesh(false)
		for j in range(5+i*2):
			var local_at:=Vector3((-1 if j%2 else 1)*(7+j),0,-8-j*2)
			var at:Vector3=gates[i].to_global(local_at)
			at=NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map,at)
			var enemy:Node3D=world._spawn_enemy(at);enemy.set_kind(j%4,3);enemy.hear(nearest,90)
		world.announce(Localization.t("SBARRAMENTO {0} / 2 · Scendete, eliminate gli infetti e liberate la strada.",[i+1]),7)
		world.survival._publish()
