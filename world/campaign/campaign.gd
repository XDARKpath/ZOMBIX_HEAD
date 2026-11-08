extends Node3D
const Route=preload("res://world/campaign/route.gd")
const Parts=preload("res://world/zona1_rifugio/expedition.gd")
const Layout=preload("res://world/zona1_rifugio/refuge_layout.gd")
const POINTS=Layout.PART_POINTS
const PART_NAMES:=["BATTERIA", "CINGHIA MOTORE", "TANICA CARBURANTE"]
var world:Node3D
var car:CharacterBody3D
var crates:Array[Node3D]=[]
var beacons:Array[Node3D]=[]
var collected:Array=[false,false,false]
var stage:int=0 # parts, repair, travel, secure/download, complete
var zone_index:int=0
var unlocked:int=0
var operation:int=1
var hold:float=8
var repairing_peer:int=0
var downloading:bool=false
var guardians_warned:bool=false
var publish_clock:float=0
var broadcast_count:int=0
var save_signature:String=""

func build(owner_world:Node3D) -> void:
	world=owner_world
	for i in range(3):
		var crate:=Node3D.new();add_child(crate);crate.position=POINTS[i]
		crate.name="RepairPart%d"%i
		preload("res://world/zona1_rifugio/repair_part.gd").build(crate,i)
		crates.append(crate)
	for i in range(Route.POINTS.size()):
		var beacon:=Node3D.new();add_child(beacon)
		# I ripetitori seguono le tappe; il primo viene riposizionato accanto al
		# 4×4 dopo la creazione del veicolo, fuori dallo scorcio del marciapiede.
		beacon.position=Route.POINTS[i]+(Vector3(5.6,0,4.4) if i==0 else Vector3(8,0,-6))
		Parts.piece(beacon,Vector3(0,0.6,0),Vector3(1,1.2,0.7),Color("35443f"))
		Parts.piece(beacon,Vector3(0,2,0),Vector3(0.04,3,0.04),Color("92998c"))
		beacons.append(beacon)
	car=CharacterBody3D.new();car.name="SquadVehicle";car.set_script(preload("res://vehicle/expedition_car.gd"))
	add_child(car);car.build(self)
	# Il primo ripetitore sta accanto al 4×4, fuori dal marciapiede: davanti
	# allo sceriffo sembrava un secondo lampione e sporcava lo scorcio.
	if not beacons.is_empty():
		beacons[0].position=Vector3(car.position.x-3.2,Route.POINTS[0].y,car.position.z+2.4)
	visible=false

func start() -> void:
	for crate in crates:crate.visible=false
	collected=[false,false,false];stage=0;zone_index=0;unlocked=0;operation=1;hold=8;guardians_warned=false
	repairing_peer=0;downloading=false;car.reset();visible=true;_refresh()
	save_signature=_signature()

func _signature() -> String:
	return "%d|%d|%d|%s|%s|%d"%[stage,zone_index,unlocked,car.repaired,collected,world.quest.stage if world.get("quest") else 0]

func authority() -> bool: return not Session.online or multiplayer.is_server()

func request_use() -> void:
	if authority(): use(multiplayer.get_unique_id())
	else: interact.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func interact() -> void:
	if authority(): use(multiplayer.get_remote_sender_id())

func can_reach(actor:CharacterBody3D,at:Vector3,distance:float=3.2) -> bool:
	if actor.position.distance_to(at)>distance: return false
	# Il raggio si ferma un metro prima: l'oggetto stesso (il ripetitore è solido) non conta come ostacolo.
	var from:=actor.position+Vector3.UP
	var to:=at+Vector3.UP
	to=to.move_toward(from,minf(1.0,from.distance_to(to)))
	var query:=PhysicsRayQueryParameters3D.create(from,to,1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func use(peer:int) -> bool:
	if not authority() or not world.started or not world.actors.has(peer): return false
	var actor:CharacterBody3D=world.actors[peer]
	if actor.dead: return false
	if car.seat_of(peer)>=0: return car.interact(peer)
	if stage==1 and can_reach(actor,car.position,3.4):
		if repairing_peer==0: repairing_peer=peer;hold=8
		_publish();return true
	if car.repaired and actor.position.distance_to(car.position)<3.4: return car.interact(peer)
	if stage==3 and can_reach(actor,beacons[zone_index].position):
		if remaining_enemies()>0 or not squad_near(): return false
		downloading=true;_publish();return true
	return false

## Davanti al muso (cofano aperto) si lavora al motore, altrove sulle ruote.
func repair_kind(actor:Node3D) -> String:
	return "engine" if car.to_local(actor.global_position).z < -1.2 else "wheel"

func squad_near() -> bool:
	for actor in world.actors.values():
		if actor.dead or actor.position.distance_to(Route.POINTS[zone_index])>45: return false
	return not world.actors.is_empty()

func remaining_enemies() -> int:
	var count:=0
	for enemy in world.targets:
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(Route.POINTS[zone_index])<65: count+=1
	return count

func try_arrive() -> bool:
	if not authority() or stage!=2 or not car.repaired or not car.all_aboard(): return false
	if unlocked==1 and world.get("roadblocks") and world.roadblocks.cleared.count(true)!=2:return false
	if car.position.distance_to(Route.POINTS[unlocked])>22 or absf(car.speed)>1: return false
	zone_index=unlocked;operation=zone_index+1;stage=3;hold=10;downloading=false
	world.activate_zone(zone_index)
	if zone_index==1:
		world.announce("ZONA 1 COMPLETATA · Lago Cenere è alle tue spalle · +500 crediti",10)
		for actor in world.actors.values():actor.credits+=500
		if world.get("survival"):world.survival._publish()
	_publish();return true

func _process(delta:float) -> void:
	if not world or not world.started: visible=false;return
	visible=true
	if not authority(): return
	if stage==1 and repairing_peer!=0:
		var actor:CharacterBody3D=world.actors.get(repairing_peer)
		if not is_instance_valid(actor) or actor.dead or not can_reach(actor,car.position,3.4):
			repairing_peer=0;hold=8
		else:
			hold=maxf(0,hold-delta)
			actor.set_meta("repair_until",Time.get_ticks_msec()+200)
			actor.set_meta("repair_kind",repair_kind(actor))
			if hold<=0:
				car.repaired=true;stage=2;unlocked=1;repairing_peer=0;car.publish();_publish()
	elif stage==2: try_arrive()
	elif stage==3 and downloading:
		if not squad_near() or remaining_enemies()>0: downloading=false;hold=10
		else:
			hold=maxf(0,hold-delta)
			if hold<=0:
				downloading=false
				if zone_index==7: stage=4
				else: unlocked=zone_index+1;stage=2
				_publish()
	publish_clock+=delta
	if publish_clock>=0.2: publish_clock=0;_publish()
	# Autosalvataggio all'ingresso di ogni tappa e a ogni ricambio raccolto.
	if not world.automated:
		var sig:=_signature()
		if sig!=save_signature:
			save_signature=sig
			SaveManager.write(world)

func begin_repair() -> void:
	if stage==0:stage=1;hold=8;_publish()

func target_point() -> Vector3:
	if world.get("zone2") and world.zone2.active(): return world.zone2.target()
	if stage==0: return world.quest.target()
	if stage==1: return car.position
	if stage==2:
		return Route.POINTS[unlocked] if car.seat_of(multiplayer.get_unique_id())>=0 else car.position
	return beacons[zone_index].position

func prompt() -> String:
	if world.player.dead: return ""
	var seat:int=car.seat_of(multiplayer.get_unique_id())
	if seat>=0:
		return Localization.t("WASD  GUIDA · " if seat==0 else "PASSEGGERO · ")+Localization.t("E  SCENDI" if absf(car.speed)<0.8 else "FERMATI PER SCENDERE")
	if world.player.position.distance_to(car.position)<3.4:
		if stage==1: return Localization.t("RIPARAZIONE  {0} s · RESTA VICINO",[ceili(hold)]) if repairing_peer else "E  RIPARA IL 4×4"
		if car.repaired: return "E  SALI SUL 4×4"
	if stage==0: return "G  GPS"
	if world.player.position.distance_to(target_point())>3.2: return "G  GPS"
	if stage==3:
		if remaining_enemies()>0: return "ELIMINA GLI INFETTI DEL PRESIDIO"
		if not squad_near(): return "RIUNISCI LA SQUADRA AL PRESIDIO"
		return Localization.t("DOWNLOAD  {0} s",[ceili(hold)]) if downloading else "E  SCARICA LA PROSSIMA COORDINATA"
	return "G  GPS"

func title() -> String:
	if world.get("zone2") and world.zone2.active(): return world.zone2.title()
	if stage==0: return world.quest.title()
	return ["RECUPERA I RICAMBI", "RIPARA IL 4×4", "SEGUI IL GPS", "LIBERA IL PRESIDIO", "ROTTA COMPLETATA"][stage]

func detail() -> String:
	if world.get("zone2") and world.zone2.active(): return world.zone2.detail()
	match stage:
		0: return world.quest.detail()
		1: return "8 secondi di lavoro vicino al motore"
		2: return "%02d → %02d · %.2f km\n%s"%[zone_index+1,unlocked+1,car.position.distance_to(Route.POINTS[unlocked])/1000.0,Localization.t(Route.TITLES[unlocked])]
		3: return Localization.t("{0} infetti · riunitevi e scaricate il segnale",[remaining_enemies()])
		_: return "8 / 8 · fine del percorso prototipo"

func _refresh() -> void:
	for i in range(beacons.size()): beacons[i].visible=i<=unlocked

func _publish() -> void:
	_refresh()
	if Session.online and multiplayer.is_server():
		for peer in Session.connected_peers(): receive.rpc_id(peer,collected,stage,zone_index,unlocked,hold,repairing_peer,downloading)

@rpc("authority","call_remote","reliable")
func receive(items:Array,step:int,current:int,revealed:int,remaining:float,repairer:int,download:bool) -> void:
	collected=items;stage=step;zone_index=current;unlocked=revealed;hold=remaining;repairing_peer=repairer;downloading=download
	operation=zone_index+1;broadcast_count+=1;_refresh()
	if repairing_peer and world.actors.has(repairing_peer):
		world.actors[repairing_peer].set_meta("repair_until",Time.get_ticks_msec()+300)
		world.actors[repairing_peer].set_meta("repair_kind",repair_kind(world.actors[repairing_peer]))
