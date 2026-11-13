extends CharacterBody3D
const Route=preload("res://world/campaign/route.gd")
# Seated avatar origins for SM_Veh_Ranger4x4 (cushion top - 0.555, same offset as the old seats): driver, passenger, rear L, rear R.
const SEATS:=[Vector3(-0.46,0.33,0.20),Vector3(0.46,0.33,0.20),Vector3(-0.46,0.39,0.96),Vector3(0.46,0.39,0.96)]
const RangerVisual=preload("res://vehicle/ranger_visual.gd")
var campaign:Node3D
var seats:Array=[0,0,0,0]
var repaired:bool=false
var speed:float=0
var drive_input:=Vector2.ZERO
var input_age:float=1
var send_clock:float=0
var server_position:=Vector3.ZERO
var server_yaw:float=0
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
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new();shape.size=Vector3(1.92,1.95,3.6)
	collider.shape=shape;collider.position.y=0.98;add_child(collider)
	# 04 / RANGER: modelled 4x4 with opening doors and three repair phases (ranger_visual.gd).
	visual=RangerVisual.new();visual.name="Ranger";add_child(visual)
	wheels=visual.wheels
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
	position=Vector3(19.5,0.2,3.6);rotation.y=PI/2;server_position=position

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
	visual.roll(speed*delta)
	visual.settle(delta)
	visual.steer(steer_amount)
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
	if seats[0]==local:
		var input:=Input.get_vector("move_left","move_right","move_forward","move_back") if not campaign.world.ui_open else Vector2.ZERO
		if campaign.authority(): drive_input=input;input_age=0
		else:
			send_clock+=delta
			if send_clock>=0.05: send_clock=0;steer.rpc_id(1,input)
	if campaign.authority():
		for i in range(seats.size()):
			if seats[i]!=0 and (not campaign.world.actors.has(seats[i]) or campaign.world.actors[seats[i]].dead):
				_release(seats[i]);seats[i]=0;publish()
		input_age+=delta
		var input:=drive_input if input_age<0.3 and seats[0]!=0 and repaired else Vector2.ZERO
		var target:float=-input.y*(24.0 if input.y<0 else 8.0)
		speed=move_toward(speed,target,delta*(7 if input.y!=0 else 12))
		var previous_yaw:=rotation.y
		steer_amount=lerpf(steer_amount,-input.x,delta*8)
		rotation.y-=input.x*clampf(speed/7,-1,1)*delta*0.85
		var forward:Vector3=-global_basis.z
		velocity.x=forward.x*speed;velocity.z=forward.z*speed
		velocity.y=-1 if is_on_floor() else velocity.y-delta*24
		move_and_slide()
		if is_on_wall(): speed*=0.8
		if position.y< -1:
			position=Route.nearest_road(position)+Vector3.UP*0.2;speed=0;velocity=Vector3.ZERO
			campaign.world.announce("Il 4×4 è stato recuperato sulla strada.",4)
		# Ultima sicurezza ai limiti di route.gd: prima di arrivarci ci sono le pareti di roccia.
		if not Route.inside(position): position=server_position;speed=0;velocity=Vector3.ZERO
		server_position=position
		_follow_turn(rotation.y-previous_yaw)
		_place_occupants()
		send_clock+=delta
		if send_clock>=0.05: send_clock=0;publish()
	else:
		var previous_yaw:=rotation.y
		# Sterzo stimato dalla rotazione, così anche sui client le ruote e le mani girano.
		steer_amount=lerpf(steer_amount,clampf(wrapf(server_yaw-rotation.y,-PI,PI)*6.0,-1,1),delta*8)
		position=position.lerp(server_position,1-exp(-delta*14))
		rotation.y=lerp_angle(rotation.y,server_yaw,1-exp(-delta*14))
		_follow_turn(wrapf(rotation.y-previous_yaw,-PI,PI));_place_occupants()

func _follow_turn(amount:float) -> void:
	if seat_of(multiplayer.get_unique_id())>=0: campaign.world.player.rig.yaw+=amount

@rpc("any_peer","call_remote","unreliable_ordered",1)
func steer(input:Vector2) -> void:
	if not campaign.authority() or multiplayer.get_remote_sender_id()!=seats[0] or not input.is_finite(): return
	drive_input=input.limit_length(1);input_age=0

func publish() -> void:
	if Session.online and multiplayer.is_server():
		for peer in Session.connected_peers(): state.rpc_id(peer,position,rotation.y,velocity,speed,seats,repaired)

@rpc("authority","call_remote","unreliable_ordered",1)
func state(at:Vector3,yaw:float,motion:Vector3,pace:float,occupants:Array,fixed:bool) -> void:
	var was_seated:=seat_of(multiplayer.get_unique_id())>=0
	server_position=at;server_yaw=yaw;velocity=motion;speed=pace;seats=occupants;repaired=fixed
	if position.distance_to(at)>30: position=at;rotation.y=yaw
	if not was_seated and seat_of(multiplayer.get_unique_id())>=0:
		campaign.world.player.rig.yaw=yaw;campaign.world.player.rig.pitch=0
	_place_occupants()
