extends Node3D
## Ragdoll alla morte degli infetti normali (art/zx_infected, 65 ossa): 12 corpi rigidi sulle ossa principali
## (13 con la testa), legati da giunti con limiti articolari. Parte dalla posa e dalla velocità del momento della
## morte, prende l'impulso nel punto colpito, si assesta e poi si congela in posa: giunti liberati, corpi resi statici
## (non simulano più, ma chi muore dopo ci cade sopra). I colpi al cadavere lo risvegliano con un impulso vero.
## Cosmetico e locale: host e client lo simulano ognuno per conto suo dai campi già sincronizzati
## (dead, death_clock, velocity, hit_serial, hit_dir, hit_power, hit_zone). Non tocca mai lo stato del bersaglio.
## RigidBody3D top-level + giunti del PhysicsServer invece di PhysicalBone3D: lo scheletro sta sotto `visual`,
## scalato per tipo (0.94..1.7, il mutato solo in altezza 1.09), e i corpi fisici non vanno messi sotto un padre scalato.

const MAX_ACTIVE := 6
const MAX_DISTANCE := 30.0
## Layer 11, solo cadaveri: urtano il mondo (layer 1) e gli altri cadaveri. Il giocatore (maschera 1|4|8) e gli
## zombie vivi (maschera 1) ci passano attraverso: un corpo a terra non chiude mai un passaggio.
const LAYER := 1 << 10
const MAX_SPEED := 9.0
const MAX_SPIN := 18.0
const KILL_IMPULSE := 38.0
const HIT_IMPULSE := 40.0
const SETTLE_SPEED := 0.12
const SETTLE_SPIN := 0.6
const SETTLE_TIME := 0.6
const MAX_LIFE := 8.0

## [osso, osso della punta ("" = lungo l'asse Y dell'osso), allungo m, massa kg, forma, misura (box: lati; altre: x = raggio)]
## In ordine dal bacino in giù: pose() scrive i padri prima dei figli.
const PARTS := [
	["pelvis", "spine_02", 0.0, 11.0, "box", Vector3(0.30, 0.26, 0.20)],
	["spine_02", "spine_03", 0.0, 8.0, "box", Vector3(0.30, 0.16, 0.19)],
	["spine_03", "neck_01", 0.0, 10.0, "box", Vector3(0.34, 0.24, 0.21)],
	["head", "", 0.17, 4.5, "sphere", Vector3(0.115, 0, 0)],
	["upperarm_l", "lowerarm_l", 0.0, 2.4, "capsule", Vector3(0.05, 0, 0)],
	["lowerarm_l", "hand_l", 0.09, 1.8, "capsule", Vector3(0.045, 0, 0)],
	["upperarm_r", "lowerarm_r", 0.0, 2.4, "capsule", Vector3(0.05, 0, 0)],
	["lowerarm_r", "hand_r", 0.09, 1.8, "capsule", Vector3(0.045, 0, 0)],
	["thigh_l", "calf_l", 0.0, 7.0, "capsule", Vector3(0.075, 0, 0)],
	["calf_l", "foot_l", 0.04, 4.0, "capsule", Vector3(0.055, 0, 0)],
	["thigh_r", "calf_r", 0.0, 7.0, "capsule", Vector3(0.075, 0, 0)],
	["calf_r", "foot_r", 0.04, 4.0, "capsule", Vector3(0.055, 0, 0)],
]
## [padre, figlio, osso del perno, limiti in radianti attorno agli assi del modello a riposo (posa a T):
##  X di lato (+sinistra), Y su, Z avanti -> [x_min, x_max, y_min, y_max, z_min, z_max]]
## Spina e collo: +X piega in avanti. Anca: -X porta la coscia avanti. Ginocchio: +X porta il piede indietro.
## Spalla e gomito partono dal braccio orizzontale: ±Z lo abbassa, ±Y lo porta avanti o indietro.
const JOINTS := [
	["pelvis", "spine_02", "spine_02", [-0.35, 0.6, -0.3, 0.3, -0.3, 0.3]],
	["spine_02", "spine_03", "spine_03", [-0.3, 0.5, -0.3, 0.3, -0.25, 0.25]],
	["spine_03", "head", "neck_01", [-0.6, 0.85, -0.9, 0.9, -0.45, 0.45]],
	["spine_03", "upperarm_l", "upperarm_l", [-0.7, 0.7, -1.4, 0.6, -1.5, 1.1]],
	["upperarm_l", "lowerarm_l", "lowerarm_l", [-0.5, 0.5, -2.3, 0.0, -0.1, 0.1]],
	["spine_03", "upperarm_r", "upperarm_r", [-0.7, 0.7, -0.6, 1.4, -1.1, 1.5]],
	["upperarm_r", "lowerarm_r", "lowerarm_r", [-0.5, 0.5, 0.0, 2.3, -0.1, 0.1]],
	["pelvis", "thigh_l", "thigh_l", [-1.6, 0.35, -0.45, 0.45, -0.2, 0.85]],
	["thigh_l", "calf_l", "calf_l", [0.0, 2.3, -0.05, 0.05, -0.05, 0.05]],
	["pelvis", "thigh_r", "thigh_r", [-1.6, 0.35, -0.45, 0.45, -0.85, 0.2]],
	["thigh_r", "calf_r", "calf_r", [0.0, 2.3, -0.05, 0.05, -0.05, 0.05]],
]

## Spento dai test per fotografare la vecchia morte a clip.
static var enabled := true
static var active: Array = []
static var _material: PhysicsMaterial

var v: Node3D
var st: Dictionary
var bodies := {}          # osso -> RigidBody3D
var offsets := {}         # osso -> corpo-a-osso (spazio mondo, con la scala del modello)
var joints: Array[RID] = []
var calm := 0.0
var life := 0.0
var top_speed := 0.0      # velocità più alta vista prima del limite (letta dai test)
var start_y := 0.0


## Chiamato da infected_motion per un infetto morto, ogni frame. true = la posa la fa il ragdoll (attivo o congelato).
static func drive(visual: Node3D, a: Node3D) -> bool:
	var state: Dictionary = visual.get_meta("zr", {})
	if state.is_empty():
		state = {"mode": "clip", "serial": a.hit_serial, "node": null}
		visual.set_meta("zr", state)
		# Solo una morte appena successa: chi entra in partita e trova cadaveri vecchi li vede con la clip finita.
		if float(a.death_clock) < 0.5 and _eligible(visual, a): _begin(visual, a, state, KILL_IMPULSE if a.hit_age < 0.3 else 0.0)
	elif int(a.hit_serial) != int(state.serial):
		state.serial = a.hit_serial
		if state.mode == "active" and is_instance_valid(state.node): state.node.push(a, HIT_IMPULSE)
		elif _eligible(visual, a):
			# Si risveglia dalla posa in cui è (congelata o fine clip): i vecchi collisori via subito, sennò lo urterebbero.
			if is_instance_valid(state.node): state.node.free()
			_begin(visual, a, state, HIT_IMPULSE)
	if state.mode == "active" and is_instance_valid(state.node):
		state.node.pose()
		return true
	return state.mode == "frozen"


static func _eligible(visual: Node3D, a: Node3D) -> bool:
	if not enabled or visual.skeleton == null: return false
	# Carceriere e boss hanno le loro morti (clip Z_Boss_Death_Collapse, boss_fx): scheletro 1.7 volte e scena scritta.
	if int(a.kind) == 5 or str(a.get("custom_skin")) != "" or a.get("brain") != null: return false
	for row in PARTS:
		if not visual.bone_ids.has(row[0]): return false
	active = active.filter(func(n): return is_instance_valid(n))
	if active.size() >= MAX_ACTIVE: return false
	var cam := visual.get_viewport().get_camera_3d()
	return cam == null or cam.global_position.distance_squared_to(a.global_position) <= MAX_DISTANCE * MAX_DISTANCE


static func _begin(visual: Node3D, a: Node3D, state: Dictionary, strength: float) -> void:
	var node: Node3D = load("res://art/zombie_ragdoll.gd").new()
	node.name = "Ragdoll"
	visual.add_child(node)
	node.build(visual, a)
	node.st = state
	state.mode = "active"
	state.node = node
	active.append(node)
	if strength > 0.0: node.push(a, strength)


func build(visual: Node3D, a: Node3D) -> void:
	v = visual
	top_level = true
	global_transform = Transform3D.IDENTITY
	if _material == null:
		_material = PhysicsMaterial.new()
		_material.friction = 0.9
		_material.bounce = 0.0
	var sk: Skeleton3D = v.skeleton
	var sg: Transform3D = sk.global_transform
	var rests := {}
	var rest_frames := {}
	for row in PARTS:
		var bone: String = row[0]
		if bone == "head" and a.beheaded: continue
		var i: int = v.bone_ids[bone]
		var rest: Transform3D = _rest(sk, i, rests)
		var tip: Vector3 = rest.origin + rest.basis.y.normalized() * float(row[2])
		if row[1] != "":
			tip = _rest(sk, v.bone_ids[row[1]], rests).origin
			tip += (tip - rest.origin).normalized() * float(row[2])
		var center: Vector3 = rest.affine_inverse() * ((rest.origin + tip) * 0.5)
		var now: Transform3D = sg * sk.get_bone_global_pose(i)
		var body_now := _frame(now, center)
		var body_rest := _frame(sg * rest, center)
		rest_frames[bone] = body_rest
		offsets[bone] = body_now.affine_inverse() * now
		var length: float = ((sg * tip) - (sg * rest.origin)).length()
		var axis: Vector3 = (body_rest.basis.inverse() * ((sg * tip) - (sg * rest.origin))).normalized()
		# Grossezza dell'osso nel mondo: scala del tipo (visual) per quella delle ossa (il bruto ha spalle e cosce gonfiate).
		var gs: Vector3 = (sg * rest).basis.get_scale()
		var s: float = (gs.x + gs.y + gs.z) / 3.0
		var b := RigidBody3D.new()
		b.mass = float(row[3])
		b.collision_layer = LAYER
		b.collision_mask = 1 | LAYER
		b.linear_damp = 0.25
		b.angular_damp = 3.0 if bone.contains("arm") else 1.6     # avambracci leggeri: senza frenarli frustano a 20 m/s
		b.continuous_cd = true
		b.physics_material_override = _material
		var shape := CollisionShape3D.new()
		var size: Vector3 = row[5]
		match String(row[4]):
			"box":
				var box := BoxShape3D.new()
				box.size = size * s
				shape.shape = box
			"sphere":
				var ball := SphereShape3D.new()
				ball.radius = size.x * s
				shape.shape = ball
			_:
				var cap := CapsuleShape3D.new()
				cap.radius = size.x * s
				cap.height = maxf(length + cap.radius, cap.radius * 2.0)
				shape.shape = cap
		shape.basis = Basis(Quaternion(Vector3.UP, axis))
		b.add_child(shape)
		add_child(b)
		b.global_transform = body_now
		b.linear_velocity = a.velocity
		bodies[bone] = b
	var list: Array = bodies.values()
	for x in list.size():
		for y in range(x + 1, list.size()):
			list[x].add_collision_exception_with(list[y])
	# Giunti fatti a mano. Gli assi e lo zero degli angoli vengono dalla posa a riposo, così i limiti valgono per
	# l'anatomia e non per la posa in cui è morto. Il perno invece è dove sta adesso l'osso (le ossa di mezzo non
	# simulate, spine_01, clavicole e collo, lo spostano di qualche centimetro): niente strappo al primo passo.
	var axes: Basis = sg.basis.orthonormalized()
	for row in JOINTS:
		if not bodies.has(row[0]) or not bodies.has(row[1]): continue
		var at: Vector3 = sg * sk.get_bone_global_pose(v.bone_ids[row[2]]).origin
		var la := Transform3D((rest_frames[row[0]] as Transform3D).basis.inverse() * axes, bodies[row[0]].global_transform.affine_inverse() * at)
		var lb := Transform3D((rest_frames[row[1]] as Transform3D).basis.inverse() * axes, bodies[row[1]].global_transform.affine_inverse() * at)
		var joint := PhysicsServer3D.joint_create()
		PhysicsServer3D.joint_make_generic_6dof(joint, bodies[row[0]].get_rid(), la, bodies[row[1]].get_rid(), lb)
		PhysicsServer3D.joint_disable_collisions_between_bodies(joint, true)
		# Angolo di adesso come lo misura il server (padre rispetto al figlio, XYZ): se la posa animata sta già fuori
		# dai limiti, il limite si allarga fin lì invece di raddrizzarla di colpo (era il calcio da 15 m/s al primo passo).
		var now: Vector3 = ((bodies[row[1]].global_basis * lb.basis).inverse() * (bodies[row[0]].global_basis * la.basis)).get_euler(EULER_ORDER_XYZ)
		var lim: Array = row[3]
		for k in 3:
			PhysicsServer3D.generic_6dof_joint_set_flag(joint, k, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_LINEAR_LIMIT, true)
			PhysicsServer3D.generic_6dof_joint_set_param(joint, k, PhysicsServer3D.G6DOF_JOINT_LINEAR_LOWER_LIMIT, 0.0)
			PhysicsServer3D.generic_6dof_joint_set_param(joint, k, PhysicsServer3D.G6DOF_JOINT_LINEAR_UPPER_LIMIT, 0.0)
			PhysicsServer3D.generic_6dof_joint_set_flag(joint, k, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_ANGULAR_LIMIT, true)
			# Godot Physics misura l'angolo del padre rispetto al figlio: limiti [0, 1] lasciano ruotare il figlio in [-1, 0]
			# (provato con due corpi). Qui i limiti sono scritti dal lato del figlio, quindi si girano.
			PhysicsServer3D.generic_6dof_joint_set_param(joint, k, PhysicsServer3D.G6DOF_JOINT_ANGULAR_LOWER_LIMIT, minf(-float(lim[k * 2 + 1]), now[k] - 0.05))
			PhysicsServer3D.generic_6dof_joint_set_param(joint, k, PhysicsServer3D.G6DOF_JOINT_ANGULAR_UPPER_LIMIT, maxf(-float(lim[k * 2]), now[k] + 0.05))
		joints.append(joint)
	start_y = bodies["pelvis"].global_position.y


## Posa a riposo nello spazio dello scheletro, ma con la scala che le ossa hanno adesso (il bruto, _bulk di infected_motion).
static func _rest(sk: Skeleton3D, i: int, memo: Dictionary) -> Transform3D:
	if memo.has(i): return memo[i]
	var local: Transform3D = sk.get_bone_rest(i)
	local.basis = local.basis * Basis.from_scale(sk.get_bone_pose_scale(i))
	var parent := sk.get_bone_parent(i)
	memo[i] = (_rest(sk, parent, memo) if parent >= 0 else Transform3D.IDENTITY) * local
	return memo[i]


static func _frame(bone: Transform3D, center: Vector3) -> Transform3D:
	return Transform3D(bone.basis.orthonormalized(), bone * center)


## Impulso del colpo nel punto colpito (hit_point se c'è, sennò il centro della hitbox della zona, sennò il bacino).
func push(a: Node3D, strength: float) -> void:
	var dir: Vector3 = a.visual.global_basis.orthonormalized() * Vector3(a.hit_dir)
	if dir.length_squared() < 0.01: return
	var at := _hit_point(a)
	var best: RigidBody3D = bodies["pelvis"]
	for b in bodies.values():
		if b.global_position.distance_squared_to(at) < best.global_position.distance_squared_to(at): best = b
	for b in bodies.values(): b.sleeping = false
	# Velocità data al pezzo colpito, al massimo 4 m/s (un braccio da 2 kg non deve schizzare via con l'impulso pensato
	# per il busto). Niente apply_impulse: nel frame in cui il corpo nasce il server usa ancora la massa di 1 kg
	# (provato: 32 m/s invece di 4). Al centro del pezzo: il corpo ruota lo stesso attorno ai giunti.
	var kick: Vector3 = dir.normalized() * minf(strength * clampf(float(a.hit_power), 0.3, 1.3) / best.mass, 4.0)
	# A terra un colpo orizzontale muore nell'attrito (5 cm): il pezzo colpito sobbalza anche in su.
	if strength == HIT_IMPULSE: kick += Vector3.UP * kick.length() * 0.6
	best.linear_velocity += kick
	calm = 0.0
	life = 0.0


func _hit_point(a: Node3D) -> Vector3:
	var pelvis: Vector3 = bodies["pelvis"].global_position
	var p = a.get("hit_point")
	# Su un client hit_point può essere vecchio se non arriva col sync: buono solo se è sul corpo.
	if p is Vector3 and (p as Vector3).is_finite() and (p as Vector3).distance_to(pelvis) < 2.0: return p
	for area in a.hitboxes:
		if str(area.get_meta("zone")) == str(a.hit_zone): return area.global_position
	return pelvis


func _physics_process(delta: float) -> void:
	life += delta
	# Caduto: da qui in poi l'attrito sale, così i giunti smettono di tremare e il corpo si addormenta presto.
	var settling := life > 1.5
	if settling != (bodies["pelvis"].linear_damp > 1.0):
		for b in bodies.values():
			b.linear_damp = 2.0 if settling else 0.25
			b.angular_damp = 6.0 if settling else (3.0 if bodies.find_key(b).contains("arm") else 1.6)
	var slow := true
	for b in bodies.values():
		var lv: Vector3 = b.linear_velocity
		if not (b.global_position.is_finite() and lv.is_finite()) or b.global_position.y < start_y - 30.0:
			push_warning("zombie_ragdoll: corpo non valido (%s), torna la clip" % b.global_position)
			_end("clip")
			return
		var speed := lv.length()
		top_speed = maxf(top_speed, speed)
		if speed > MAX_SPEED: b.linear_velocity = lv * (MAX_SPEED / speed)
		var spin: float = b.angular_velocity.length()
		if spin > MAX_SPIN: b.angular_velocity *= MAX_SPIN / spin
		if speed > SETTLE_SPEED or spin > SETTLE_SPIN: slow = false
	calm = calm + delta if slow else 0.0
	if calm >= SETTLE_TIME or life >= MAX_LIFE:
		pose()
		_end("frozen")


## Fermo: la posa resta sullo scheletro, i giunti spariscono e i corpi diventano collisori statici (niente simulazione,
## ma chi muore dopo ci cade sopra). "clip" = qualcosa è andato storto: via tutto, torna la clip di morte.
func _end(mode: String) -> void:
	st.mode = mode
	active.erase(self)
	_free_joints()
	set_physics_process(false)
	if mode == "clip":
		st.node = null
		queue_free()
		return
	for b in bodies.values():
		b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		b.freeze = true


func _free_joints() -> void:
	for joint in joints: PhysicsServer3D.free_rid(joint)
	joints.clear()


func _exit_tree() -> void:
	active.erase(self)
	_free_joints()


## Scrive sullo scheletro la posa dei corpi: il bacino anche in posizione, gli altri solo in rotazione (niente stiramenti).
func pose() -> void:
	var sk: Skeleton3D = v.skeleton
	var inv: Transform3D = sk.global_transform.affine_inverse()
	for row in PARTS:
		var bone: String = row[0]
		if not bodies.has(bone): continue
		var i: int = v.bone_ids[bone]
		var want: Transform3D = inv * ((bodies[bone] as RigidBody3D).global_transform * offsets[bone])
		var parent := sk.get_bone_parent(i)
		var local: Transform3D = (sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY).affine_inverse() * want
		sk.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		if bone == "pelvis": sk.set_bone_pose_position(i, local.origin)
