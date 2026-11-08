# Attività al falò: fumatore, cuoco, pulizia fucile e ispezione katana.
# IK nativo SkeletonIK3D, configurato seguendo il demo ufficiale Godot su GitHub.
extends "res://art/survivor_visual.gd"
const Props := preload("res://ui/camp/camp_props.gd")
const Hands := preload("res://art/hand_pose.gd")
# Asse dell'impugnatura della pistola del menu (spazio dell'arma: +X canna, +Y carrello).
const PISTOL_GRIP := Vector3(-0.3,-1,0)
var foot_targets: Dictionary = {}
var foot_solvers: Dictionary = {}
var stance: int = 0
var knife: Node3D
var phase: float = 0
var rest_position := Vector3.ZERO
var left_goal: Marker3D
var right_goal: Marker3D
var left_ik: SkeletonIK3D
var right_ik: SkeletonIK3D
var cigarette: Node3D
var stone: Node3D
var spit: Node3D
var spit_shaft: MeshInstance3D
var chicken: Node3D
var exhale: CPUParticles3D
var activity: String = ""
var sip: float = 0
var katana: Node3D
var sniper: Node3D
var cloth: MeshInstance3D
var sidearm: Node3D

func configure(model_name: String, owner_actor: Node3D, is_zombie: bool = false) -> void:
	phase = stance*1.73
	clock = 0.0 if stance==0 else phase
	rest_position = position
	# La skin scelta resta quella del giocatore: ognuno dei quattro posti mostra la propria.
	super.configure(model_name,owner_actor,is_zombie)
	left_goal = Marker3D.new()
	left_goal.name = "LeftHandTarget"
	add_child(left_goal)
	right_goal = Marker3D.new()
	right_goal.name = "RightHandTarget"
	add_child(right_goal)
	left_ik = _make_ik("l",left_goal)
	right_ik = _make_ik("r",right_goal)
	right_ik.override_tip_basis = true
	left_ik.override_tip_basis = true
	# Il fumatore usa l'IK analitica di hand_pose.gd.
	left_ik.active = stance!=0
	right_ik.active = stance!=0
	if stance==1 or stance==2:
		for side in ["l","r"]:
			var target := Marker3D.new()
			target.name="FootTarget_"+side
			add_child(target)
			var solver := SkeletonIK3D.new()
			solver.root_bone=skeleton.get_bone_name(bone_ids["thigh_"+side])
			solver.tip_bone=skeleton.get_bone_name(bone_ids["foot_"+side])
			solver.override_tip_basis=true
			solver.use_magnet=true
			solver.magnet=Vector3(0.23 if side=="l" else -0.23,0.70,0.65)
			solver.max_iterations=32
			solver.min_distance=0.001
			skeleton.add_child(solver)
			solver.target_node=solver.get_path_to(target)
			foot_targets[side]=target
			foot_solvers[side]=solver
	match stance:
		0:
			activity = "smoking"
			sidearm=preload("res://ui/camp/menu_assets.gd").weapon("pistol")
			add_child(sidearm)
			cigarette = Props.cigarette(self)
			exhale = Props.smoke(self,Vector3.ZERO,0.20,0.12,20)
			exhale.name = "ExhaledSmoke"
			exhale.lifetime = 1.6
			exhale.initial_velocity_min = 0.18
			exhale.initial_velocity_max = 0.25
			exhale.emitting = false
		1:
			activity = "roasting_chicken"
			spit = Node3D.new()
			spit.name = "RoastingSpit"
			get_parent().add_child(spit,true)
			spit_shaft = Props.cylinder(spit,Vector3.ZERO,0.017,0.8,Color("765030"))
			chicken = Props.roast_chicken(spit)
		2:
			activity = "cleaning_sniper"
			sniper = preload("res://ui/camp/menu_assets.gd").weapon("sniper")
			add_child(sniper)
			cloth = Props.box(self,Vector3.ZERO,Vector3(0.09,0.012,0.075),Color("b7aa87"))
			cloth.name = "CleaningCloth"
		3:
			activity = "inspecting_katana"
			katana = preload("res://ui/camp/menu_assets.gd").weapon("katana")
			add_child(katana)
	_pose(0)

func _make_ik(side: String, target: Marker3D) -> SkeletonIK3D:
	var ik := SkeletonIK3D.new()
	ik.name = "HandIK_"+side
	ik.root_bone = skeleton.get_bone_name(bone_ids["upperarm_"+side])
	ik.tip_bone = skeleton.get_bone_name(bone_ids["hand_"+side])
	ik.override_tip_basis = false
	ik.use_magnet = true
	ik.magnet = Vector3(0.40 if side=="l" else -0.40,1.02,0.15)
	ik.max_iterations = 48
	ik.min_distance = 0.002
	skeleton.add_child(ik)
	ik.target_node = ik.get_path_to(target)
	return ik

func hand(side: String) -> Vector3:
	return (skeleton.global_transform*skeleton.get_bone_global_pose(bone_ids["hand_"+side])).origin

func _pose(_delta: float) -> void:
	if not skeleton: return
	skeleton.clear_bones_global_pose_override()
	var breath := sin(clock*1.35+phase)
	var shift := sin(clock*0.33+phase)
	position = rest_position+Vector3(0,breath*0.003,0)
	for leg in ["thigh_l","thigh_r","calf_l","calf_r"]: rotate_bone(leg,Vector3.RIGHT,0)
	transform_bone("spine_01",Basis(Vector3.RIGHT,breath*0.012)*Basis(Vector3.BACK,shift*0.014))
	transform_bone("head",Basis(Vector3.UP,shift*0.07)*Basis(Vector3.RIGHT,0.05))
	transform_bone("upperarm_l",Basis(Vector3.RIGHT,-0.1)*Basis(Vector3.BACK,-1.35))
	transform_bone("upperarm_r",Basis(Vector3.RIGHT,-0.1)*Basis(Vector3.BACK,1.35))
	rotate_bone("lowerarm_l",Vector3.RIGHT,-0.4)
	rotate_bone("lowerarm_r",Vector3.RIGHT,-0.4)
	if axe: axe.hide()
	if not left_goal: return
	left_goal.position = Vector3(0.28,0.91,0.12)
	right_goal.position = Vector3(-0.28,0.91,0.12)
	left_goal.basis = _hand_basis("l",Vector3(-0.2,-1,-0.4),Vector3.LEFT)
	match stance:
		0:
			var cycle := fposmod(clock,14.0)
			sip = smoothstep(1.0,2.8,cycle)*(1-smoothstep(5.0,6.8,cycle))
			rotate_bone("spine_01",Vector3.RIGHT,-0.12+breath*0.008)
			right_goal.position = Vector3(-0.30,1.02,0.16).lerp(Vector3(-0.12,1.52,0.23),sip)
			var lowered := _hand_basis("r",Vector3(0,-0.8,0.6),Vector3.RIGHT).get_rotation_quaternion()
			var raised := _hand_basis("r",Vector3(0.9,0.35,0),Vector3.FORWARD).get_rotation_quaternion()
			right_goal.basis = Basis(lowered.slerp(raised,sip))
			left_goal.position = Vector3(0.26,0.86,0.14)
			left_goal.basis = _hand_basis("l",Vector3(0,-1,0.05),Vector3.LEFT)
			left_ik.magnet = Vector3(0.25,1.16,-0.12)
			transform_bone("head",Basis(Vector3.UP,-0.10+sin(clock*0.28)*0.10)*Basis(Vector3.RIGHT,-sip*0.025))
			rotate_bone("pelvis",Vector3.BACK,0.025)
			rotate_bone("thigh_l",Vector3.RIGHT,-0.75)
			rotate_bone("calf_l",Vector3.RIGHT,2.0)
			rotate_bone("foot_l",Vector3.RIGHT,-1.25)
		1:
			rotate_bone("thigh_l",Vector3.RIGHT,-0.9)
			rotate_bone("thigh_r",Vector3.RIGHT,-1.05)
			rotate_bone("calf_l",Vector3.RIGHT,1.3)
			rotate_bone("calf_r",Vector3.RIGHT,1.45)
			rotate_bone("spine_01",Vector3.RIGHT,0.15+breath*0.015)
			rotate_bone("head",Vector3.RIGHT,0.32)
			left_goal.position = Vector3(0.25,0.96,0.31)
			left_goal.basis = _hand_basis("l",Vector3(0,-0.3,1),Vector3.DOWN)
			right_goal.position = Vector3(-0.13+sin(clock*0.48)*0.03,1.20+sin(clock*0.48)*0.035,0.50)
			right_goal.basis = _hand_basis("r",Vector3(0,1,0.3),Vector3.LEFT)
			right_ik.magnet = Vector3(-0.4,0.85,0.15)
		2:
			rotate_bone("thigh_l",Vector3.RIGHT,-1.45)
			rotate_bone("thigh_r",Vector3.RIGHT,-1.45)
			rotate_bone("calf_l",Vector3.RIGHT,1.45)
			rotate_bone("calf_r",Vector3.RIGHT,1.45)
			rotate_bone("spine_01",Vector3.RIGHT,0.25+breath*0.012)
			rotate_bone("head",Vector3.RIGHT,0.4)
			var cycle := fposmod(clock+phase,10.0)
			var inspect := smoothstep(5.2,6.7,cycle)*(1.0-smoothstep(8.0,9.6,cycle))
			sniper.position = Vector3(0.02,1.04+inspect*0.08,0.42)
			sniper.rotation = Vector3(inspect*0.14,0.06*sin(clock*0.6),0.06+inspect*0.12)
			left_goal.position = sniper.transform*Vector3(0.18,-0.04,-0.10)
			var pass_time := fposmod(cycle,1.7)
			var wipe := smoothstep(0.15,1.05,pass_time)*(1.0-smoothstep(1.15,1.65,pass_time))
			var stroke := lerpf(-0.10,0.08,wipe)*(1.0-inspect)
			cloth.position = sniper.transform*(sniper.get_node("CleaningSurface").position+Vector3(stroke,0,0))
			cloth.basis = sniper.basis
			right_goal.position = cloth.position+sniper.basis*Vector3(0,0.093,-0.14)
			left_goal.basis = sniper.basis*_hand_basis("l",Vector3.BACK,Vector3.UP)
			# Palmo rivolto verso lo straccio, dita che scendono sul tessuto.
			right_goal.basis = sniper.basis*_hand_basis("r",Vector3.BACK,Vector3.DOWN)*Basis(Vector3.RIGHT,PI)
			rotate_bone("head",Vector3.RIGHT,0.36-inspect*0.16)
		3:
			rotate_bone("thigh_l",Vector3.RIGHT,-1.57)
			rotate_bone("calf_l",Vector3.RIGHT,1.57)
			rotate_bone("thigh_r",Vector3.RIGHT,0.15)
			rotate_bone("calf_r",Vector3.RIGHT,1.50)
			rotate_bone("spine_01",Vector3.RIGHT,0.08+breath*0.01)
			var cycle := fposmod(clock+phase,12.0)
			var inspect := smoothstep(1.0,3.5,cycle)*(1.0-smoothstep(6.0,8.5,cycle))
			katana.position = Vector3(-0.29,1.18+inspect*0.12,0.38)
			katana.rotation = Vector3(sin(clock*0.55)*0.25,0.08*sin(clock*0.3),0.12+inspect*0.12)
			right_goal.position = katana.transform*Vector3(-0.10,-0.025,-0.09)
			left_goal.position = katana.transform*Vector3(0.33,-0.025,-0.11)
			right_goal.basis = katana.basis*_hand_basis("r",Vector3.BACK,Vector3.UP)
			left_goal.basis = katana.basis*_hand_basis("l",Vector3(-0.25,0,1),Vector3.UP)
			transform_bone("head",Basis(Vector3.UP,-0.10+inspect*0.25)*Basis(Vector3.RIGHT,0.26))
	if stance==2:
		left_goal.position=sniper.transform*sniper.get_node("GripSupport").position-left_goal.basis*Vector3(0,0.07,0.025)
		right_goal.position=cloth.position-right_goal.basis*Vector3(0,0.07,0.025)
	elif stance==3:
		right_goal.position=katana.transform*katana.get_node("GripMain").position-right_goal.basis*Vector3(0,0.07,0.025)
		left_goal.position=katana.transform*katana.get_node("InspectionSupport").position-left_goal.basis*Vector3(0,0.07,0.025)
	if stance==0:
		_smoker_arms()
	else:
		left_ik.start(true)
		right_ik.start(true)
	_plant_feet()
	if stance!=0: _update_hands()
	_update_objects()

## Fumatore: pistola impugnata lungo la coscia (indice lungo il carrello) e sigaretta tra
## indice e medio, portata alla bocca a ogni boccata. IK analitica, niente SkeletonIK3D.
func _smoker_arms() -> void:
	Hands.grip(skeleton,bone_ids,"l","pistol")
	var left := Hands.shoulder(skeleton,bone_ids,"l")
	Hands.reach(skeleton,bone_ids,"l",left+Vector3(0.07,-0.46,0.07),Vector3(0.05,-1,0.2),Vector3(-1,0,0.1),left+Vector3(0.3,0,-1))
	# Destra: la mano resta ferma sull'avambraccio, si muove solo il braccio fino alla bocca.
	Hands.smoke_arm(skeleton,bone_ids,sip,sin(clock*0.8))

func _update_objects() -> void:
	if sidearm:
		# Impugnatura nel pugno, canna lungo l'avambraccio.
		sidearm.global_transform=skeleton.global_transform*Hands.pistol_frame(skeleton,bone_ids,"l",sidearm.get_node("GripMain").position,PISTOL_GRIP)
	if cigarette:
		cigarette.global_transform=skeleton.global_transform*Hands.cigarette_frame(skeleton,bone_ids,"r")
		var head: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(bone_ids["head"])
		exhale.global_position = head*Vector3(0,0.14,-0.04)
		exhale.global_basis = Basis.IDENTITY
		exhale.direction = (global_basis*Vector3(0.15,0.3,1)).normalized()
		(cigarette.get_node("Smoke") as CPUParticles3D).global_basis = Basis.IDENTITY
		var cycle := fposmod(clock,14.0)
		exhale.emitting = cycle>6.0 and cycle<6.8
	if spit:
		spit.visible = visible
		var grip: Vector3 = _bone_frame("hand_r")*Vector3(0,0.07,0.025)
		var aim: Vector3 = get_parent().global_position+Vector3(sin(clock*0.48)*0.06,0.91,0.3)
		var direction := (aim-grip).normalized()
		var tip := grip+direction*0.75
		spit_shaft.global_position = grip+direction*0.375
		spit_shaft.global_basis = Basis(Quaternion(Vector3.UP,direction))
		(spit_shaft.mesh as CylinderMesh).height = 1.05
		chicken.global_position = tip
		chicken.global_basis = Basis(Quaternion(Vector3.BACK,(tip-grip).normalized()))*Basis(Vector3.BACK,sin(clock*0.48)*0.75)
	if knife:
		knife.global_position = hand("l")+global_basis*Vector3(-0.02,-0.07,0.015)
		knife.global_basis = global_basis*Basis(Vector3.FORWARD,-PI/2)*Basis.from_scale(Vector3.ONE*0.8)
	if stone:
		stone.global_position = hand("r")+global_basis*Vector3(0.055,-0.055,0.015)
		stone.global_basis = global_basis

func add_knife() -> void:
	knife = preload("res://art/placeholders.gd").knife()
	knife.name = "SharpenedKnife"
	add_child(knife)
	_update_objects()

func _exit_tree() -> void:
	if is_instance_valid(spit): spit.queue_free()

func _bone_frame(bone_name: String) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone_ids[bone_name])

func _update_hands() -> void:
	# Pose the imported fingers directly; the original skinned mesh is intact.
	for side in ["l","r"]:
		var profile: String = ["cigarette","grip","cloth","grip"][stance] if side=="r" else ("pistol" if stance==0 else "support")
		for digit in ["index","middle","ring","pinky"]:
			var angles := Vector3(0.85,1.05,0.65)
			if profile=="cloth": angles=Vector3(0.18,0.25,0.12)
			elif profile=="support": angles=Vector3(0.45,0.65,0.35)
			elif profile=="cigarette" and digit in ["index","middle"]: angles=Vector3(0.15,0.22,0.12)
			elif profile=="pistol":
				angles=Vector3(0.95,1.20,0.75)
			for joint in range(1,4):
				var id: int=bone_ids.get("%s_0%d_%s"%[digit,joint,side],-1)
				if id<0:continue
				var rest: Basis=skeleton.get_bone_rest(id).basis
				skeleton.set_bone_pose_rotation(id,(rest*Basis(Vector3.RIGHT,angles[joint-1])).get_rotation_quaternion())
		for joint in range(1,4):
			var id: int=bone_ids.get("thumb_0%d_%s"%[joint,side],-1)
			if id>=0:
				var rest: Basis=skeleton.get_bone_rest(id).basis
				var curl := rest*Basis(Vector3.RIGHT,0.35)
				if profile=="pistol":
					curl=rest*Basis(Vector3.BACK,0.85 if joint==1 else 0.0)*Basis(Vector3.RIGHT,0.15 if joint==1 else 0.35)
				skeleton.set_bone_pose_rotation(id,curl.get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

func _plant_feet() -> void:
	for side in foot_targets:
		var left: bool = side=="l"
		var reach := 0.44 if left else 0.48
		if stance==2: reach=0.32 if left else 0.62
		var target: Marker3D=foot_targets[side]
		target.position=Vector3(0.19 if left else -0.19,0.075-position.y,reach)
		target.basis=Basis(Vector3.UP,0.08 if left else -0.08)*skeleton.get_bone_global_rest(bone_ids["foot_"+side]).basis
		foot_solvers[side].start(true)

func _hand_basis(_side: String, fingers: Vector3, palm: Vector3) -> Basis:
	# Survivor Operative hand bones run along local +Y, unlike the removed hands.
	var y := fingers.normalized()
	var z := (palm-y*palm.dot(y)).normalized()
	return Basis(y.cross(z).normalized(),y,z)
