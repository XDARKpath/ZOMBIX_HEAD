extends CharacterBody3D
signal defeated(target: Node3D)
const Balance = preload("res://autoload/balance.gd")
const Arsenal = preload("res://weapons/zx_arsenal.gd")
## Danno alle gambe che lo fa cadere (per tipo: walker, corridore, bruto, mutato).
const LEG_LIMIT := [30.0, 26.0, 70.0, 36.0, 28.0, 99999.0]
var leg_damage: float = 0.0
## Reazioni direzionali (clip Z_React_* di tools/zombie_reactions/bake_reactions.py). Chi colpisce imposta
## pending_reaction e reaction_dir prima di receive_hit; la spinta la fa la fisica, la clip resta sul posto.
## [clip, durata s, velocità della spinta m/s, durata della spinta s, velocità della clip]
## Colpi laterali e parata: le clip di colpo originali del gioco (Z_Hit_L / Z_Hit_R / Z_Hit_Front), con la spinta
## laterale o all'indietro della fisica.
const REACTIONS := {"hit_left": ["Z_Hit_L", 16.0 / 30.0, 1.2, 0.45, 1.0],
	"hit_right": ["Z_Hit_R", 16.0 / 30.0, 1.2, 0.45, 1.0],
	"knockdown": ["Z_React_Knockdown", 80.0 / 30.0, 1.0, 0.35, 1.0], "pushed": ["Z_React_Pushed", 36.0 / 30.0, 2.3, 0.55, 1.0],
	"blocked": ["Z_Hit_Front", 18.0 / 30.0, 1.6, 0.3, 1.0]}
var pending_reaction := ""
var reaction_dir := Vector3.ZERO
var reaction := ""
var reaction_time := 0.0
var push_velocity := Vector3.ZERO
var push_left := 0.0
var health: float = Balance.TARGET_HEALTH
var dead: bool = false
var stagger: float = 0.0
var visual: Node3D
var bar: MeshInstance3D
var home: Vector3
var blood_enabled: bool = true
var clock: float = 0
var avatar:Node3D
var kind:int=0
var max_health:float=72
var crawling:bool=false
var beheaded:bool=false
var death_style:int=0
var death_clock:float=0
var ragdoll_kick:float=0.0
var ragdoll_dir:=Vector3.ZERO
var body_shape:CollisionShape3D
var hitboxes:Array[Area3D]=[]
var voice_cooldown:float=0.0
# L'ultimo colpo ricevuto: infected_motion.gd fa cedere il corpo da quella parte. hit_dir è nello spazio del modello.
var hit_age:float=9.0
var hit_power:float=0.0
var hit_zone:String="torso"
var hit_dir:=Vector3.ZERO
var hit_serial:int=0
## Boss con un aspetto suo: il modello e cosa tiene in mano (per ora "cleaver").
var custom_skin:String=""
var boss_weapon:String=""
## Nome e sottotitolo del boss, per l'HUD.
var title:String=""
var epithet:String=""

func setup(variant: int) -> void:
	add_to_group("zombies")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	body_shape=shape
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	model_variant = variant
	_dress()
	bar = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.65, 0.045)
	bar.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("b54a35")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar.material_override = mat
	bar.position.y = 2.15
	bar.visible = false
	add_child(bar)
	home = global_position
	_make_hitboxes()
	update_hitboxes()

# Skin degli infetti (art/zx_infected, dalle tavole concept): quattro walker diversi,
# lo spitter per i corridori (tipo 1) e gli sputatori (tipo 4, verdastri), il tank per i bruti (tipo 2)
# e per il Carceriere (tipo 5, alto 1,7 volte e arrossato).
const WALKERS := ["ZMB_Walker_1", "ZMB_Walker_2", "ZMB_Walker_3", "ZMB_Walker_4"]
var model_variant: int = 0

func skin_path() -> String:
	if custom_skin != "": return custom_skin
	var id: String = WALKERS[posmod(model_variant + get_instance_id(), WALKERS.size())]
	# Il modello con la sacca del veleno è solo di chi sputa davvero.
	if kind == 4: id = "ZMB_Spitter"
	elif kind in [2, 5]: id = "ZMB_Tank"
	return "res://art/zx_infected/%s.glb" % id

func _dress() -> void:
	if avatar: avatar.queue_free()
	avatar = Node3D.new()
	avatar.set_script(preload("res://art/survivor_visual.gd"))
	visual.add_child(avatar)
	avatar.configure(skin_path(), self, true)
	if boss_weapon == "cleaver": _give_cleaver()
	if boss_weapon == "lamp": _give_lamp()
	if boss_weapon.begins_with("crown"): _give_crown()

## La corona del Signore delle Teste: tre teschi che gli girano attorno. set_crown toglie quelli tagliati.
var crown_node:Node3D
func _give_crown() -> void:
	if crown_node: crown_node.queue_free()
	crown_node=Node3D.new();crown_node.name="Crown";add_child(crown_node);crown_node.position.y=3.3
	var bone:=StandardMaterial3D.new();bone.albedo_color=Color("e0d6b4");bone.emission_enabled=true;bone.emission=Color("6b3fa0");bone.emission_energy_multiplier=0.22
	var dark:=StandardMaterial3D.new();dark.albedo_color=Color("120d16")
	for i in 3:
		var skull:=MeshInstance3D.new();var head:=SphereMesh.new();head.radius=0.3;head.height=0.56;head.radial_segments=8;head.rings=5;head.material=bone;skull.mesh=head
		crown_node.add_child(skull);var a:=TAU*float(i)/3.0;skull.position=Vector3(cos(a)*1.25,0,sin(a)*1.25)
		for side in [-1.0,1.0]:
			var eye:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(0.11,0.1,0.05);box.material=dark;eye.mesh=box;skull.add_child(eye);eye.position=Vector3(side*0.11,0.04,-0.27)
func set_crown(left:int) -> void:
	if not crown_node: return
	for i in crown_node.get_child_count(): crown_node.get_child(i).visible=i<left

## Il lampione divelto del Capomacello.
func _give_lamp() -> void:
	if not avatar.skeleton: return
	var held: Node3D = load("res://art/zx_infected/BOSS_Sheriff_Abomination_Held.glb").instantiate()
	avatar.add_child(held)
	preload("res://art/survivor_visual.gd")._palette(held)
	preload("res://art/env/scripts/weapon_item.gd").attach_node(held, avatar, "weapon_r")

## La mannaia del Macellaio: lama lunga, sporca, legata alla mano.
func _give_cleaver() -> void:
	if not avatar.skeleton or not avatar.bone_ids.has("hand_r"): return
	var grip:=BoneAttachment3D.new()
	avatar.skeleton.add_child(grip)
	grip.bone_name=avatar.skeleton.get_bone_name(avatar.bone_ids["hand_r"])
	var steel:=StandardMaterial3D.new();steel.albedo_color=Color("8a8f8c");steel.metallic=0.7;steel.roughness=0.4
	var blood:=StandardMaterial3D.new();blood.albedo_color=Color("4e120e");blood.roughness=0.5
	var wood:=StandardMaterial3D.new();wood.albedo_color=Color("3d2a1a");wood.roughness=0.9
	for row in [[Vector3(0.2,0.03,0.0),Vector3(0.05,0.3,0.05),wood],[Vector3(0.62,0.05,0.0),Vector3(0.62,0.3,0.035),steel],[Vector3(0.74,-0.07,0.0),Vector3(0.36,0.1,0.038),blood]]:
		var part:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=row[1] if row[1].y<0.28 or row[1].x>0.2 else Vector3(row[1].y,row[1].x,row[1].z)
		cube.material=row[2];part.mesh=cube;grip.add_child(part);part.position=row[0]

## Da dove esce lo sputo: la bocca, davanti alla testa.
func mouth_position() -> Vector3:
	if avatar and avatar.head_piece:return avatar.head_piece.global_position+Vector3.UP*0.06-global_basis.z*0.16
	return global_position+Vector3.UP*1.55-global_basis.z*0.3

func set_kind(value:int,tier:int=0) -> void:
	var previous:=kind
	kind=clampi(value,0,5)
	if kind!=previous and avatar and (kind in [1,2,4,5] or previous in [1,2,4,5]): _dress()
	max_health=[72.0,62.0,155.0,88.0,58.0,1400.0][kind]*(1.0+tier*0.12)
	health=max_health
	visual.scale=Vector3.ONE*[1.0,0.94,1.18,1.0,0.96,1.7][kind]
	if kind==3: visual.scale.y=1.09
	if kind>=4 and custom_skin=="":call_deferred("_tint",Color(0.82,1.0,0.7) if kind==4 else Color(1.12,0.72,0.66))
	if kind==5:
		# Il Carceriere: capsula e hitbox più grandi, barra della vita più in alto.
		var cap:=(body_shape.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		cap.radius=0.58;cap.height=3.0;body_shape.shape=cap;body_shape.position.y=1.5
		for area in hitboxes:
			var sh:=area.get_child(0) as CollisionShape3D
			sh.shape=sh.shape.duplicate()
			if sh.shape is SphereShape3D:(sh.shape as SphereShape3D).radius*=1.7
		bar.position.y=3.55

## Colore della pelle per sputatori e boss (moltiplica i materiali della skin).
func _tint(color:Color) -> void:
	if not avatar:return
	# Le skin usano un solo materiale palette (material_override): una copia tinta per questo infetto.
	var tinted:StandardMaterial3D
	for node in avatar.find_children("*","MeshInstance3D",true,false):
		var mi:=node as MeshInstance3D
		if not (mi.material_override is StandardMaterial3D):continue
		if tinted==null:
			tinted=(mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			tinted.albedo_color=tinted.albedo_color*color
		mi.material_override=tinted

func receive_melee(amount:float,force:Vector3,heavy:bool) -> bool:
	return receive_hit("torso",amount,force,"axe",heavy)

func receive_hit(zone:String,amount:float,force:Vector3,weapon:String,heavy:bool=false) -> bool:
	if amount<=0 or beheaded:
		pending_reaction=""
		return false
	# La testa si stacca solo dal cadavere: prima lo uccidi, poi lo finisci con una lama. Testa e collo bastano
	# con un colpo qualsiasi, il resto del corpo vuole un colpo caricato. I boss danno la testa da soli.
	var blade:bool=Arsenal.beheads(weapon)
	_note_hit(zone,force,amount,heavy)
	if dead:
		if blade and kind<5 and (zone=="head" or zone=="neck" or heavy):
			decapitate()
			return true
		# Cadavere molle: ogni colpo lo fa sobbalzare di nuovo.
		ragdoll_kick=minf(1.3,ragdoll_kick+0.85)
		ragdoll_dir=force.normalized() if force.length_squared()>0.01 else ragdoll_dir
		if blood_enabled:_blood(global_position+Vector3.UP*0.25)
		return true
	var low:bool=zone=="feet" or zone=="legs"
	if low:
		# Gambe: il danno si accumula. Un colpo pesante o qualche colpo leggero lo
		# atterrano e da lì continua strisciando (Z_Stagger_Heavy, poi Z_Crawl).
		leg_damage+=amount*(1.6 if heavy else 1.0)
		health=maxf(1 if not crawling else 0,health-amount*0.45)
		if not crawling and leg_damage>=LEG_LIMIT[kind]:
			crawling=true;heavy=true;reaction=""
			body_shape.shape.height=0.64;body_shape.position.y=0.32
	else:health=maxf(0,health-amount*(2.5 if zone=="head" else (1.3 if zone=="neck" else 1.0)))
	# Se è già a terra per una caduta non si accorcia: finisce caduta, terra e rialzata come sono.
	velocity+=force;stagger=maxf(stagger,0.55 if heavy else 0.25)
	_react()
	bar.visible=true;bar.scale.x=health/max_health
	if blood_enabled:_blood(global_position+Vector3.UP*(0.35 if low else 1.2))
	ragdoll_dir=force.normalized() if force.length_squared()>0.01 else ragdoll_dir
	if health<=0:
		_die()
	elif voice_cooldown<=0.0:
		voice_cooldown=0.7
		AudioManager.zombie_voice(kind,"hurt",global_position+Vector3.UP*1.4,-7.0,randf_range(0.92,1.06))
	return true

## Da dove è arrivato il colpo, per far cedere il corpo da quella parte.
func _note_hit(zone:String,force:Vector3,amount:float,heavy:bool) -> void:
	hit_age=0.0
	hit_serial+=1
	hit_zone=zone
	hit_power=clampf(amount/40.0,0.45,1.0)*(1.25 if heavy else 1.0)
	var local:Vector3=global_basis.inverse()*force
	# Il modello guarda dietro al corpo (visual ruotato di 180 gradi).
	hit_dir=Vector3(-local.x,0,-local.z).normalized() if local.length_squared()>0.001 else Vector3.BACK*-1.0

func _react() -> void:
	var kind := pending_reaction
	pending_reaction = ""
	if kind == "" or not REACTIONS.has(kind) or self.kind == 5: return     # il boss non si fa spostare
	# Già a terra: un altro colpo non lo rimette in piedi né ricomincia la caduta a metà.
	if reaction == "knockdown" and stagger > 0.0: return
	# Il bruto non cade per un calcio e non cambia clip: indietreggia di poco e incassa col corpo.
	if self.kind == 2:
		var away := Vector3(reaction_dir.x, 0, reaction_dir.z).normalized()
		push_velocity = away * 0.9
		push_left = 0.18
		return
	# Da terra lo zombie non barcolla: il calcio lo spinge e basta.
	var row: Array = REACTIONS[kind].duplicate()
	# La durata la dà la clip vera (Mixamo): cade e si rialza quanto serve.
	var motion_data: Resource = load("res://art/infected_motion.gd").data()
	if motion_data and motion_data.clips.has(row[0]): row[1] = float(motion_data.clips[row[0]].frames) / 30.0
	var dir := Vector3(reaction_dir.x, 0, reaction_dir.z).normalized()
	push_velocity = dir * float(row[2])
	push_left = float(row[3])
	if crawling: return
	reaction = kind
	reaction_time = 0.0
	stagger = maxf(stagger, float(row[1]))   # l'IA aspetta la fine della reazione prima di inseguire di nuovo
	if kind in ["knockdown", "pushed", "blocked"]:
		# Si gira verso chi l'ha colpito: la spinta va all'indietro, la caduta in avanti verso di lui.
		rotation.y = atan2(dir.x, dir.z)


func reaction_clip() -> String:
	return REACTIONS[reaction][0] if REACTIONS.has(reaction) else ""


## Tempo della clip della reazione (alcune sono accelerate).
func reaction_clip_time() -> float:
	return reaction_time * float(REACTIONS[reaction][4]) if REACTIONS.has(reaction) else 0.0


## Reazione decisa da fuori (per esempio il colpo dello zombie parato dal giocatore).
func react(kind: String, dir: Vector3) -> void:
	pending_reaction = kind
	reaction_dir = dir
	_react()


func decapitate() -> void:
	if beheaded:return
	var at:Transform3D=avatar.head_piece.global_transform if avatar.head_piece else global_transform
	beheaded=true
	if not dead:_die()
	if has_method("see") and get("world") and get("world").has_method("drop_head"):get("world").drop_head(self,at)
	if blood_enabled:_blood(at.origin)

func _die() -> void:
	pending_reaction="";reaction=""
	dead=true;death_clock=0;death_style=4 if crawling else posmod(get_instance_id(),4)
	bar.hide();collision_layer=0
	# A terra testa e collo sono più facili da prendere con la lama.
	for area in hitboxes:
		if area.get_meta("zone") in ["head","neck"]:
			var sh:=area.get_child(0) as CollisionShape3D
			sh.shape=sh.shape.duplicate()
			(sh.shape as SphereShape3D).radius*=1.9
	if kind==5:
		if custom_skin=="":
			AudioManager.boss_voice("carceriere","death",global_position+Vector3.UP*2.4,-2.0)
			AudioManager.end_boss("carceriere")
		AudioManager.play_sfx("boss_defeat",-2.0)
	else:
		AudioManager.zombie_voice(kind,"death",global_position+Vector3.UP*1.2,-4.0,randf_range(0.92,1.05))
	defeated.emit(self)

func _blood(at:Vector3) -> void:
	var particles:=CPUParticles3D.new();get_parent().add_child(particles);particles.global_position=at
	particles.amount=10;particles.one_shot=true;particles.explosiveness=1;particles.lifetime=0.35
	particles.direction=Vector3.UP;particles.spread=90;particles.initial_velocity_min=0.6;particles.initial_velocity_max=1.4;particles.gravity=Vector3(0,-8,0)
	var drop:=SphereMesh.new();drop.radius=0.018;drop.height=0.036;particles.mesh=drop;particles.color=Color("742d22");particles.emitting=true
	get_tree().create_timer(1).timeout.connect(particles.queue_free)

func _make_hitboxes() -> void:
	for row in [["head","head",0.14],["neck","neck_01",0.09],["torso","spine_02",0.26],["feet","foot_l",0.2],["feet","foot_r",0.2],["legs","calf_l",0.14],["legs","calf_r",0.14],["torso","pelvis",0.25]]:
		var area:=Area3D.new();add_child(area);area.collision_layer=16;area.collision_mask=0;area.monitoring=false
		area.set_meta("target",self);area.set_meta("zone",row[0]);area.set_meta("bone",row[1])
		var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=row[2];shape.shape=sphere;area.add_child(shape);hitboxes.append(area)

func update_hitboxes() -> void:
	if not avatar or not avatar.skeleton:return
	for area in hitboxes:
		var bone:String=area.get_meta("bone")
		if not avatar.bone_ids.has(bone):continue
		var pose:Transform3D=avatar.skeleton.global_transform*avatar.skeleton.get_bone_global_pose(avatar.bone_ids[bone])
		area.global_position=pose*(Vector3(0,0,-0.08) if bone=="head" else (Vector3(0.025,0,0) if bone=="neck_01" else Vector3.ZERO))
		area.collision_layer=0 if beheaded else 16

func _process(delta:float) -> void:
	voice_cooldown=maxf(0.0,voice_cooldown-delta)
	if crown_node: crown_node.rotation.y+=delta*1.9
	# Scultura senza ossa (Il Mago): galleggia, respira, si piega quando colpisce e affonda da morta.
	if avatar and not avatar.skeleton and avatar.get_child_count()>0:
		var body:=avatar.get_child(0) as Node3D
		var t:=Time.get_ticks_msec()*0.001
		var lean:=sin(clampf(get("attack_clock")/1.3,0.0,1.0)*PI) if get("state")==2 else 0.0
		body.scale=Vector3(1.0+sin(t*1.7)*0.03,1.0-sin(t*1.7)*0.025,1.0+sin(t*1.7)*0.03)
		body.position.y=(sin(t*1.1)*0.1+0.28) if not dead else -minf(death_clock,3.0)*0.55
		body.rotation.x=-0.25*lean if not dead else minf(death_clock,1.0)*0.5
	hit_age=minf(hit_age+delta,9.0)
	if reaction != "":
		reaction_time += delta
		if dead or stagger <= 0.0: reaction = ""
	if dead:
		death_clock=minf(death_clock+delta,6.0)
		ragdoll_kick=maxf(0.0,ragdoll_kick-delta*2.6)

func _physics_process(delta: float) -> void:
	clock+=delta;stagger=maxf(0,stagger-delta)
	velocity.x=move_toward(velocity.x,0,Balance.TARGET_FRICTION*delta)
	velocity.z=move_toward(velocity.z,0,Balance.TARGET_FRICTION*delta)
	velocity.y=0 if is_on_floor() else velocity.y-Balance.GRAVITY*delta
	move_and_slide()
