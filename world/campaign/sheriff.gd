extends "res://art/survivor_visual.gd"
# Sceriffo seduto sotto il portico: posa procedurale e sigaro acceso.
const Props := preload("res://ui/camp/camp_props.gd")
const Hands := preload("res://art/hand_pose.gd")
var cigarette: Node3D
# Punto della seduta (spazio del corpo fisico, sedia con schienale verso +X): il bacino
# viene portato qui dopo la posa, così il corpo poggia sul cuscino invece di attraversarlo.
const SEAT := Vector3(0.05, 0.64, 0.0)
var seat_fitted := false
var desk_feet: Array[SkeletonIK3D] = []

func configure_seated(_model_name: String) -> void:
	# Il Veterano delle tavole concept: cappello, trench e bandoliera.
	configure("res://art/zx_infected/NPC_Veteran.glb", self, false)
	cigarette = Props.cigar(self)
	_pose(0.0)
	for side in ["l","r"]:
		var target := Marker3D.new()
		get_parent().add_child(target)
		target.name="DeskBoot_"+side
		# Left ankle rests on the desk; right ankle crosses above it.
		target.position=Vector3(-0.82,0.84,-0.06) if side=="l" else Vector3(-0.78,1.00,0.05)
		var relaxed_ankle := deg_to_rad(-72.0 if side=="l" else -66.0)
		target.global_basis=Basis(global_basis.x.normalized(),relaxed_ankle)*skeleton.global_basis*skeleton.get_bone_global_rest(bone_ids["foot_"+side]).basis
		var ik:=SkeletonIK3D.new()
		ik.root_bone=skeleton.get_bone_name(bone_ids["thigh_"+side])
		ik.tip_bone=skeleton.get_bone_name(bone_ids["foot_"+side])
		ik.override_tip_basis=true
		ik.max_iterations=48
		ik.min_distance=0.001
		skeleton.add_child(ik)
		ik.target_node=ik.get_path_to(target)
		desk_feet.append(ik)
	_pose(0)

func _pose(_delta: float) -> void:
	if not skeleton: return
	if head_piece and bone_ids.has("head"):
		head_piece.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bone_ids["head"])
	skeleton.reset_bone_poses()
	# Posa da sceriffo: appoggiato allo schienale con gli stivali sulla scrivania,
	# caviglie incrociate, le mani in grembo e il sigaro all'angolo della bocca.
	transform_bone("thigh_l", Basis(Vector3.RIGHT, -1.62) * Basis(Vector3.UP, 0.06))
	transform_bone("thigh_r", Basis(Vector3.RIGHT, -1.58) * Basis(Vector3.UP, -0.04) * Basis(Vector3.BACK, -0.06))
	rotate_bone("calf_l", Vector3.RIGHT, 0.08)
	rotate_bone("calf_r", Vector3.RIGHT, 0.05)
	rotate_bone("foot_l", Vector3.RIGHT, -0.35)
	rotate_bone("foot_r", Vector3.RIGHT, -0.35)
	rotate_bone("spine_01", Vector3.RIGHT, -0.22 + sin(clock * 1.3) * 0.012)
	rotate_bone("spine_02", Vector3.RIGHT, -0.08)
	rotate_bone("neck_01", Vector3.RIGHT, 0.26)
	# Mani abbandonate in grembo.
	aim_arm("l", Vector3(0.38, -0.9, 0.18), 1.1)
	aim_arm("r", Vector3(-0.38, -0.9, 0.18), 1.1)
	# Respiro e piccoli movimenti della testa presi dalla clip di riposo dello ZX Player.
	clips().additive("Idle_Unarmed", clock * 0.8, ["spine_02", "spine_03", "neck_01", "head", "clavicle_l"], 1.4)
	if not seat_fitted and bone_ids.has("pelvis") and is_inside_tree():
		seat_fitted = true
		skeleton.force_update_all_bone_transforms()
		var pelvis: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(bone_ids["pelvis"])).origin
		global_position += get_parent().to_global(SEAT) - pelvis
	for ik in desk_feet:ik.start(true)
	Hands.grip(skeleton, bone_ids, "l", "relaxed", sin(clock * 0.8))
	Hands.grip(skeleton, bone_ids, "r", "relaxed", sin(clock * 0.7))
	if cigarette:
		cigarette.global_transform = skeleton.global_transform * _cigar_frame()

## Sigaro stretto all'angolo destro della bocca, punta in avanti e un poco in giù: segue la testa.
## La punta da bocca del sigaro è a z = -0.0475 (ui/camp/camp_props.gd).
func _cigar_frame() -> Transform3D:
	var turn: Basis = Hands.head_turn(skeleton, bone_ids)
	var corner: Vector3 = Hands.mouth(skeleton, bone_ids) + turn * Vector3(-0.022, -0.008, 0.0)
	var z: Vector3 = (turn * Vector3(-0.35, -0.32 + sin(clock * 0.9) * 0.03, 1.0)).normalized()
	var y: Vector3 = (turn * Vector3.UP - z * (turn * Vector3.UP).dot(z)).normalized()
	return Transform3D(Basis(y.cross(z), y, z), corner + z * 0.0475)
