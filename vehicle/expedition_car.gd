extends CharacterBody3D
const Route=preload("res://world/campaign/route.gd")
# Origine dell'avatar seduto = marker Seat_* del glb: con le clip da seduti il bacino poggia sul cuscino
# (anteriori 0,885, posteriori 0,945) e i piedi sul pianale (0,50); davanti c'è posto per le ginocchia fino al cruscotto.
# Ordine: guidatore, passeggero, dietro sinistra, dietro destra.
const SEATS:=[Vector3(-0.46,0.53,0.32),Vector3(0.46,0.53,0.32),Vector3(-0.46,0.56,0.96),Vector3(0.46,0.56,0.96)]
const RangerVisual=preload("res://vehicle/ranger_visual.gd")
## Guida "pesante ma agile": sterzo a bicicletta (angolo delle ruote, non velocità di rotazione), sottosterzo
## leggero, niente testacoda. Ogni numero nasce dai nostri obiettivi e dal nostro modello, non da altri giochi:
## passo misurato sul Ranger (ruote a z = ±1,02 m in ranger_visual.gd).
const WHEELBASE:=2.04
## Obiettivo raggio ~4,3 m a passo d'uomo: atan(2,04 / 4,3) = 25,4°.
const MAX_STEER:=deg_to_rad(25.4)
## Obiettivo raggio ~11 m a 24 m/s: atan(2,04 / 11) = 10,5° = 25,4° × (1 − 0,59).
const STEER_FADE:=0.59
## Obiettivo frenata: S a 16 m/s² (da 24 m/s ~18 m), più forte del rilascio (12 m/s²).
const BRAKE:=16.0
## Obiettivo gradini: cordoli, assi e soglie fino a 0,3 m si scavalcano (resta sotto il raggio ruota 0,42 m).
const STEP:=0.3
var campaign:Node3D
var seats:Array=[0,0,0,0]
var repaired:bool=false
var speed:float=0
var drive_input:=Vector2.ZERO
var input_age:float=1
var send_clock:float=0
var server_position:=Vector3.ZERO
var server_yaw:float=0
## Rete: chi siede al volante simula il 4×4 sul proprio processo e manda lo stato all'host (drive_state);
## l'host lo valida e lo rilancia. Chi non guida lo disegna BUFFER_MS indietro, interpolando tra due stati.
const BUFFER_MS:=100.0
## Tutti i tempi sono "di simulazione" (somma dei passi fisici, ms): i fotogrammi a grappoli non falsano né
## l'interpolazione né il controllo di plausibilità. Tra due processi si passa con lo scarto medio di arrivo.
var sim_ms:float=0
var server_t:float=0          # tempo (orologio dell'host) di server_position
var snaps:Array=[]            # [tempo host ms, posizione, yaw, speed]
var clock_offset:float=INF    # client: orologio locale - orologio dell'host
var driver_peer:int=0         # host: ospite che sta simulando
var driver_clock:float=1.0    # host: secondi dall'ultimo drive_state valido
var driver_t:float=0          # host: tempo del conducente nell'ultimo drive_state
var driver_offset:float=INF   # host: orologio dell'host - orologio del conducente
var safe_position:=Vector3.ZERO
var visual:Node3D
var steer_amount:float=0
var last_seats:Array=[0,0,0,0]
var exhaust:Node3D
var wheels:Array[Node3D]=[]
var engine_sound:AudioStreamPlayer3D

func build(owner_campaign:Node3D) -> void:
	campaign=owner_campaign
	collision_layer=8;collision_mask=1
	floor_snap_length=1.5
	# Scatola alzata a 0,32 m da terra: sotto, quattro raggi alle ruote fanno da "piedi" e scavalcano
	# cordoli, assi e macerie fino a ~0,3 m. Prima la scatola toccava terra e ogni gradino da 1 cm era un muro.
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new();shape.size=Vector3(1.92,1.955-STEP,3.6)
	collider.shape=shape;collider.position.y=(1.955+STEP)*0.5;add_child(collider)
	# 04 / RANGER: modelled 4x4 with opening doors and three repair phases (ranger_visual.gd).
	visual=RangerVisual.new();visual.name="Ranger";add_child(visual)
	wheels=visual.wheels
	for w in wheels:
		var foot:=CollisionShape3D.new();var ray:=SeparationRayShape3D.new();ray.length=STEP+0.03
		var hub:=to_local(w.global_position)
		foot.shape=ray;foot.position=Vector3(hub.x,STEP+0.03,hub.z);foot.rotation.x=PI/2;add_child(foot)
	exhaust=preload("res://ui/camp/camp_props.gd").smoke(self,Vector3(0.32,0.42,1.74),0.5,0.35,10)
	exhaust.emitting=false
	if DisplayServer.get_name()!="headless":
		engine_sound=AudioStreamPlayer3D.new();engine_sound.stream=AudioManager.loop_stream("res://audio/vehicle_engine.ogg")
		engine_sound.volume_db=-16;engine_sound.max_distance=55;add_child(engine_sound)
	reset()

func reset() -> void:
	for peer in seats:
		if peer: _release(peer)
	seats=[0,0,0,0];last_seats=[0,0,0,0];repaired=false;speed=0;velocity=Vector3.ZERO
	if visual: visual.update_state([false,false,false],0,false,false)
	# Parcheggiato sul lato destro dell'ufficio dello sceriffo (guardandolo dalla strada), muso verso la strada.
	position=Vector3(19.5,0.2,3.6);rotation.y=PI/2;server_position=position;safe_position=position;snaps.clear()

func seat_of(peer:int) -> int: return seats.find(peer)

func interact(peer:int) -> bool:
	if not campaign.authority() or not repaired or not campaign.world.actors.has(peer): return false
	var actor:CharacterBody3D=campaign.world.actors[peer]
	if actor.dead: return false
	var seat:=seat_of(peer)
	if seat>=0:
		if absf(speed)>0.8: return false
		var exit_at:=safe_exit(seat,actor)
		if exit_at==Vector3.INF: return false
		seats[seat]=0;_release(peer);actor.position=exit_at
		actor.velocity=Vector3.ZERO
		publish();return true
	if actor.position.distance_to(position)>3.4 or absf(speed)>0.8: return false
	seat=seats.find(0)
	if seat<0: return false
	seats[seat]=peer;actor.melee.cancel()
	actor.set_crouched(false,true)
	if actor.local_control: actor.rig.yaw=rotation.y;actor.rig.pitch=0
	_place_occupants();publish();return true

func safe_exit(seat:int,actor:CharacterBody3D) -> Vector3:
	# Si scende solo dove dal sedile si arriva in linea retta (niente palizzate o muri in mezzo),
	# sul pavimento vero sotto il punto (ponti, piazzali) e con la capsula in piedi libera.
	var space:=get_world_3d().direct_space_state
	var from:=to_global(SEATS[seat]+Vector3.UP*0.9)
	for offset in [Vector3(-2.2 if seat%2==0 else 2.2,0.1,0),Vector3(0,0.1,3),Vector3(2.2 if seat%2==0 else -2.2,0.1,0)]:
		var at:=to_global(offset);at.y=from.y
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from,at,1)).is_empty(): continue
		var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at,at+Vector3.DOWN*6.0,1))
		if floor_hit.is_empty(): continue
		at.y=floor_hit.position.y+0.15
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=actor.standing_shape
		query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*0.9)
		query.collision_mask=1|8;query.exclude=[actor.get_rid()]
		if space.intersect_shape(query,1).is_empty(): return at
	return Vector3.INF

func _release(peer:int) -> void:
	if not campaign.world.actors.has(peer): return
	var actor:CharacterBody3D=campaign.world.actors[peer]
	actor.seated=false;actor.collision_layer=2;actor.collision_mask=13
	actor.remove_meta("seat")
	actor.controls_enabled=not campaign.world.ui_open if actor.local_control else true
	actor.eye_height=1.62
	actor.visual.visible=not actor.local_control

func _place_occupants() -> void:
	for peer in campaign.world.actors:
		var actor:CharacterBody3D=campaign.world.actors[peer]
		var seat:=seat_of(peer)
		if seat<0:
			if actor.seated: _release(peer)
			continue
		actor.seated=true;actor.controls_enabled=false;actor.collision_layer=0;actor.collision_mask=0
		# Posto e sterzo per le clip dell'avatar (Car_Sit_Drive / Steer_Left / Steer_Right / Sit_Passenger).
		actor.set_meta("seat",seat);actor.set_meta("steer",-steer_amount)
		actor.position=visual.to_global(SEATS[seat]);actor.velocity=velocity
		actor.eye_height=1.23;actor.visual.rotation.y=rotation.y
		actor.visual.visible=not actor.local_control
		if actor.local_control:
			actor.rig.global_position=actor.position+Vector3.UP*actor.eye_height

func all_aboard() -> bool:
	if seats[0]==0: return false
	for peer in campaign.world.actors:
		if campaign.world.actors[peer].dead or seat_of(peer)<0: return false
	return true

func _physics_process(delta:float) -> void:
	if not campaign or not campaign.world.started: return
	sim_ms+=delta*1000.0
	visual.roll(speed*delta)
	visual.settle(delta)
	visual.steer(steer_amount*steer_angle()/0.55) # ranger_visual gira le ruote di amount × 0,55 rad: così mostrano l'angolo vero
	visual.update_state(campaign.collected,campaign.stage,repaired,campaign.repairing_peer!=0)
	for i in range(seats.size()):
		if seats[i]!=last_seats[i]: visual.pulse_door(i)
	last_seats=seats.duplicate()
	if exhaust: exhaust.emitting=repaired and seats[0]!=0
	if engine_sound:
		if repaired and seats[0]!=0:
			if not engine_sound.playing: engine_sound.play()
			engine_sound.pitch_scale=0.8+absf(speed)/18.0
		elif engine_sound.playing: engine_sound.stop()
	var local:=multiplayer.get_unique_id()
	var input:=Input.get_vector("move_left","move_right","move_forward","move_back") if seats[0]==local and not campaign.world.ui_open else Vector2.ZERO
	var previous_yaw:=rotation.y
	if campaign.authority():
		for i in range(seats.size()):
			if seats[i]!=0 and (not campaign.world.actors.has(seats[i]) or campaign.world.actors[seats[i]].dead):
				_release(seats[i]);seats[i]=0;publish()
		if seats[0]!=driver_peer: driver_peer=seats[0];driver_t=0;driver_clock=1.0;driver_offset=INF;snaps.clear()
		driver_clock+=delta
		if Session.online and seats[0]!=local and driver_clock<0.3:
			# Guida un ospite: si mostra la sua simulazione, 100 ms indietro, senza scatti a 20 Hz.
			_interpolate(sim_ms)
		else:
			# Guida l'host, nessuno, o l'ospite è caduto da 0,3 s: simula l'host (in folle se non c'è input).
			if seats[0]==local: drive_input=input;input_age=0
			input_age+=delta
			_simulate(delta,drive_input if input_age<0.3 and seats[0]!=0 and repaired else Vector2.ZERO)
			server_position=position;server_yaw=rotation.y;server_t=sim_ms
		send_clock+=delta
		if send_clock>=0.05: send_clock=0;publish()
	elif seats[0]==local and repaired:
		# Ospite al volante: comando visto al fotogramma dopo, come in locale.
		_simulate(delta,input)
		send_clock+=delta
		if send_clock>=0.05: send_clock=0;drive_state.rpc_id(1,sim_ms,position,rotation.y,speed)
	else:
		_interpolate(sim_ms-clock_offset)
		# Sterzo stimato dalla rotazione, così anche sui client le ruote e le mani girano.
		var rate:=wrapf(rotation.y-previous_yaw,-PI,PI)/maxf(delta,0.001)
		steer_amount=lerpf(steer_amount,clampf(rate*WHEELBASE/(speed if absf(speed)>1.0 else 1.0)/steer_angle(),-1,1),delta*8)
	_follow_turn(wrapf(rotation.y-previous_yaw,-PI,PI));_place_occupants()

## Il modello di guida: lo esegue chi ha il volante (host o ospite).
func _simulate(delta:float,input:Vector2) -> void:
	var target:float=-input.y*(24.0 if input.y<0 else 8.0)
	# S mentre si va avanti (o W in retromarcia) frena davvero, poi fa partire la retro.
	var braking:=input.y!=0 and absf(speed)>0.3 and signf(target)!=signf(speed)
	speed=move_toward(speed,target,delta*(BRAKE if braking else 7.0 if input.y!=0 else 12.0))
	steer_amount=lerpf(steer_amount,-input.x,delta*8)
	rotation.y+=speed/WHEELBASE*tan(steer_amount*steer_angle())*delta
	var forward:Vector3=-global_basis.z
	velocity.x=forward.x*speed;velocity.z=forward.z*speed
	velocity.y=-1 if is_on_floor() else velocity.y-delta*24
	move_and_slide()
	if is_on_wall(): speed*=0.8
	if position.y< -1:
		position=Route.nearest_road(position)+Vector3.UP*0.2;speed=0;velocity=Vector3.ZERO
		campaign.world.announce("Il 4×4 è stato recuperato sulla strada.",4)
	# Ultima sicurezza ai limiti di route.gd: prima di arrivarci ci sono le pareti di roccia.
	if not Route.inside(position): position=safe_position;speed=0;velocity=Vector3.ZERO
	safe_position=position

## Posa al tempo t-BUFFER_MS (orologio dell'host) tra i due stati che lo circondano;
## oltre l'ultimo stato prosegue con la sua velocità per al massimo 100 ms.
func _interpolate(now:float) -> void:
	if snaps.is_empty(): return
	var t:=now-BUFFER_MS
	while snaps.size()>2 and snaps[1][0]<=t: snaps.pop_front()
	var a:Array=snaps[0]
	var last:Array=snaps[-1]
	if snaps.size()>=2 and t<=last[0]:
		var b:Array=snaps[1]
		var f:=clampf((t-a[0])/maxf(1.0,b[0]-a[0]),0.0,1.0)
		position=(a[1] as Vector3).lerp(b[1],f);rotation.y=lerp_angle(a[2],b[2],f);speed=lerpf(a[3],b[3],f)
	else:
		# Prosegue anche la rotazione (velocità angolare degli ultimi due stati): in curva niente yaw fermo e poi a scatto.
		var ahead:=clampf(t-last[0],0.0,BUFFER_MS)/1000.0
		var rate:=0.0
		if snaps.size()>=2: rate=wrapf(last[2]-snaps[-2][2],-PI,PI)/maxf(0.001,(last[0]-snaps[-2][0])/1000.0)
		rotation.y=last[2]+rate*ahead;speed=last[3]
		position=(last[1] as Vector3)+Basis(Vector3.UP,last[2]+rate*ahead*0.5).z*-speed*ahead
	var forward:Vector3=-global_basis.z
	velocity=Vector3(forward.x*speed,0,forward.z*speed)

## Angolo massimo delle ruote anteriori: 25,4° da fermi, il 59 % in meno a 24 m/s.
func steer_angle() -> float:
	return MAX_STEER*(1.0-STEER_FADE*clampf(absf(speed)/24.0,0.0,1.0))

func _follow_turn(amount:float) -> void:
	if seat_of(multiplayer.get_unique_id())>=0: campaign.world.player.rig.yaw+=amount

## Ospite al volante -> host. L'host accetta solo dal posto 0 e solo stati plausibili; altrimenti lo riporta indietro.
@rpc("any_peer","call_remote","unreliable_ordered",1)
func drive_state(t:float,at:Vector3,yaw:float,pace:float) -> void:
	var sender:=multiplayer.get_remote_sender_id()
	if not campaign.authority() or sender!=seats[0] or not repaired or not is_finite(t) or t<=driver_t: return
	var dt:=clampf((t-driver_t)/1000.0,0.016,0.5) if driver_t>0 else 0.1
	var reach:=(24.5+2.0)*dt*1.5+0.5
	var flat:=Vector2(at.x-server_position.x,at.z-server_position.z).length()
	if not at.is_finite() or not is_finite(yaw) or absf(pace)>24.5 or flat>reach or at.y< -1 or not Route.inside(at):
		correct.rpc_id(sender,server_position,server_yaw)
		return
	driver_t=t;driver_clock=0.0
	driver_offset=_track(driver_offset,sim_ms-t)
	server_position=at;server_yaw=yaw;server_t=t+driver_offset
	snaps.append([server_t,at,yaw,pace])
	if snaps.size()>8: snaps.pop_front()

## Scarto tra due orologi come media mobile dei ritardi d'arrivo: con fotogrammi a grappolo il minimo disegnerebbe
## oltre l'ultimo stato. Salta subito se cambia di colpo (primo pacchetto, intoppo lungo).
func _track(offset:float,sample:float) -> float:
	if absf(sample-offset)>400.0: return sample
	return lerpf(offset,sample,0.1)

@rpc("authority","call_remote","reliable",1)
func correct(at:Vector3,yaw:float) -> void:
	position=at;safe_position=at;rotation.y=yaw;speed=0;velocity=Vector3.ZERO

func publish() -> void:
	if Session.online and multiplayer.is_server():
		for peer in Session.connected_peers(): state.rpc_id(peer,server_t,server_position,server_yaw,speed,seats,repaired)

@rpc("authority","call_remote","unreliable_ordered",1)
func state(t:float,at:Vector3,yaw:float,pace:float,occupants:Array,fixed:bool) -> void:
	var local:=multiplayer.get_unique_id()
	var was_seated:=seat_of(local)>=0
	var was_driving:bool=seats[0]==local
	seats=occupants;repaired=fixed
	clock_offset=_track(clock_offset,sim_ms-t)
	if snaps.is_empty() or t>snaps[-1][0]:
		snaps.append([t,at,yaw,pace])
		if snaps.size()>8: snaps.pop_front()
	server_position=at;server_yaw=yaw
	if seats[0]==local and repaired:
		if not was_driving: position=at;rotation.y=yaw;safe_position=at;speed=pace
	elif position.distance_to(at)>30: position=at;rotation.y=yaw
	if not was_seated and seat_of(local)>=0:
		campaign.world.player.rig.yaw=yaw;campaign.world.player.rig.pitch=0
	_place_occupants()
