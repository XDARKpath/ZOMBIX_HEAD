extends Node3D
# Avatar di sopravvissuti e infetti. Se il modello esterno non esiste più,
# costruisce il manichino procedurale di art/placeholders.gd.
var skeleton: Skeleton3D
var actor: Node3D
var zombie: bool = false
var clock: float = 0.0
var bone_ids: Dictionary = {}
var axe: Node3D
var held_weapon: String = "axe"
var operative_driver
var motion: AnimationPlayer
var landed: bool = true
var jump_clip: float = 0
var head_piece: Node3D
var model_id: String = ""
# Clip dello ZX Player campionate sullo scheletro (art/zx_motion.gd) e stato dei colpi subiti.
var mixer
var hit_clock: float = 9.0
var last_stagger: float = 0.0

const Placeholder := preload("res://art/placeholders.gd")

func configure(model_name: String, owner_actor: Node3D, is_zombie: bool = false) -> void:
	actor = owner_actor
	model_id = model_name
	zombie = is_zombie
	var model: Node3D
	if model_name.begins_with("res://") and ResourceLoader.exists(model_name):
		# Infetti, boss e NPC generati dai batch ZOMBIX (art/zx_infected, scheletro da 65 ossa).
		model = load(model_name).instantiate()
		add_child(model)
		_palette(model)
		skeleton = _find_skeleton(model)
		# La Matriarca del Mago è una scultura senza ossa: si muove da sola in zombie_target.gd.
		if skeleton == null: return
		for i in skeleton.get_bone_count():
			bone_ids[skeleton.get_bone_name(i).to_lower()] = i
		if is_zombie:
			# La testa diventa un pezzo separato: si stacca col colpo caricato al collo.
			head_piece = preload("res://art/infected_anatomy.gd").prepare(self, model_name)
			_palette(self)
			# Il bruto nasce senza spalle e senza la parte alta delle braccia.
			if model_name.contains("ZMB_Tank"): preload("res://art/limb_patch.gd").apply(skeleton, Color("5f7f4e"), 0.075)
		_pose(0)
		return
	if model_name.begins_with("ZX_SKIN_"):
		# ZX Player (Batch2): dieci skin a vestito intero sullo stesso scheletro.
		model = load("res://art/zx_player/SM_ZX_Player.glb").instantiate()
		# In partita l'AnimationTree di ZXPlayer anima tutto (zx_avatar_driver.gd); le sottoclassi
		# del campo (camp_avatar) e gli NPC hanno pose proprie e lo tengono spento.
		model.build_animation_tree = get_script() == preload("res://art/survivor_visual.gd") and actor.get("melee") != null
		model.start_weapon = ""
		model.skin = int(model_name.trim_prefix("ZX_SKIN_")) % 10
	elif model_name.begins_with("ZX_MENU_"):
		model = load("res://art/menu_batch2/SM_ZX_Player.glb").instantiate()
		var skins := ["Operative","Scavenger","Tactician","Veteran","Mechanic","Fisherman"]
		var selected: String = skins[int(model_name.trim_prefix("ZX_MENU_")) % skins.size()]
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			mesh.visible = mesh.name == "Skin_"+selected or (selected == "Operative" and mesh.name in ["Slot1_Chest_PlateCarrier","Slot3_Thigh_Holster","Slot4_Head_BallisticCap"])
		if selected == "Mechanic": preload("res://art/limb_patch.gd").apply(model.find_children("*","Skeleton3D",true,false)[0], Color("d9d6c8"))
	elif not is_zombie and ResourceLoader.exists("res://art/survivor_operative/SM_Survivor_Operative.glb"):
		model = load("res://art/survivor_operative/SM_Survivor_Operative.glb").instantiate()
		model.build_animation_tree = false
	if model == null:
		model = Placeholder.humanoid(model_name, is_zombie)
	add_child(model)
	skeleton = _find_skeleton(model)
	if skeleton:
		for i in skeleton.get_bone_count():
			bone_ids[skeleton.get_bone_name(i).to_lower()] = i
		_alias_bones()
	if model.get("build_animation_tree") == true and model.has_method("equip"):
		operative_driver = preload("res://art/zx_player/zx_avatar_driver.gd").new()
		operative_driver.setup(model,actor)
	head_piece = model.get_node_or_null("HeadPiece")
	if not zombie and operative_driver == null:
		axe = Placeholder.axe()
		add_child(axe)
		axe.scale = Vector3.ONE * 0.8
	_pose(0)

static func _palette(node: Node) -> void:
	# Un solo materiale palette (filtro nearest) per tutti i modelli dei batch.
	var mat: Material = load("res://art/env/materials/M_Env_Palette.tres")
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = mat

func _alias_bones() -> void:
	# Alcuni rig usano Shoulder/Elbow/UpperLeg/Ankle; il gioco parla di
	# upperarm/lowerarm/thigh/calf/foot. Gli alias evitano di toccare le pose.
	var pairs := [["hips", "pelvis"], ["shoulder", "upperarm"], ["elbow", "lowerarm"], ["upperleg", "thigh"], ["lowerleg", "calf"], ["ankle", "foot"]]
	for side in ["l", "r"]:
		for pair in pairs:
			var from: String = pair[0] + "_" + side
			var to: String = pair[1] + "_" + side
			if bone_ids.has(from) and not bone_ids.has(to):
				bone_ids[to] = bone_ids[from]
	if bone_ids.has("hips"):
		bone_ids["pelvis"] = bone_ids["hips"]
	if bone_ids.has("neck") and not bone_ids.has("neck_01"):
		bone_ids["neck_01"] = bone_ids["neck"]

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found: return found
	return null

## Braccio verso `direction` (spazio del personaggio: +Z avanti, +Y su, +X sinistra) e gomito
## flesso in avanti di `elbow` radianti. Nel rig a T il braccio sinistro riposa lungo +X:
## la flessione del gomito è attorno a UP nello spazio di riposo (attorno a X è solo torsione).
func aim_arm(side: String, direction: Vector3, elbow: float) -> void:
	var rest_dir := Vector3.RIGHT if side == "l" else Vector3.LEFT
	transform_bone("upperarm_" + side, Basis(Quaternion(rest_dir, direction.normalized())))
	transform_bone("lowerarm_" + side, Basis(Vector3.UP, -elbow if side == "l" else elbow))

func rotate_bone(bone_name: String, axis: Vector3, angle: float) -> void:
	transform_bone(bone_name, Basis(axis, angle))

func transform_bone(bone_name: String, rotation_basis: Basis) -> void:
	if not bone_ids.has(bone_name): return
	var i: int = bone_ids[bone_name]
	var rest := skeleton.get_bone_rest(i)
	var parent := skeleton.get_bone_parent(i)
	var basis: Basis = skeleton.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(i, (basis.inverse() * rotation_basis * basis * rest.basis).get_rotation_quaternion())

## Come transform_bone, ma sopra la posa attuale (per esempio quella di una clip).
func add_bone(bone_name: String, rotation_basis: Basis) -> void:
	if not bone_ids.has(bone_name): return
	var i: int = bone_ids[bone_name]
	var parent := skeleton.get_bone_parent(i)
	var basis: Basis = skeleton.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
	var current := Basis(skeleton.get_bone_pose_rotation(i))
	skeleton.set_bone_pose_rotation(i, (basis.inverse() * rotation_basis * basis * current).get_rotation_quaternion())

func clips():
	if mixer == null: mixer = preload("res://art/zx_motion.gd").new(skeleton, bone_ids)
	return mixer

## Clip dello ZX Player a pieno corpo, con dissolvenza dalla precedente.
func clip_pose(clip_name: String, delta: float, speed: float = 1.0, blend: float = 0.3) -> void:
	var m = clips()
	m.play(clip_name, blend)
	m.advance(delta, speed)
	m.apply_base()

func _process(delta: float) -> void:
	clock += delta
	_pose(delta)

func _pose(delta: float) -> void:
	if not skeleton or not is_instance_valid(actor): return
	if head_piece and bone_ids.has("head"):
		head_piece.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bone_ids["head"])
	if zombie:
		preload("res://art/infected_motion.gd").apply(self, delta)
		return
	if operative_driver:
		operative_driver.tick(delta)
		return
	# Modelli senza clip (anteprime, segnaposto): solo posa a riposo con il passo.
	var speed: float = 0.0
	if actor.get("velocity") != null: speed = Vector2(actor.velocity.x, actor.velocity.z).length()
	var gait: float = sin(clock * 7.5) * minf(speed / 4.0, 1.0)
	# Dal riposo a T: le braccia scendono lungo i fianchi e seguono il passo.
	transform_bone("upperarm_l", Basis(Vector3.BACK, -1.34))
	transform_bone("upperarm_r", Basis(Vector3.BACK, 1.34))
	rotate_bone("lowerarm_l", Vector3.RIGHT, -0.30)
	rotate_bone("lowerarm_r", Vector3.RIGHT, -0.35)
	rotate_bone("thigh_l", Vector3.RIGHT, gait * 0.5)
	rotate_bone("thigh_r", Vector3.RIGHT, -gait * 0.5)
	rotate_bone("calf_l", Vector3.RIGHT, maxf(0, -gait) * 0.55)
	rotate_bone("calf_r", Vector3.RIGHT, maxf(0, gait) * 0.55)
	rotate_bone("spine_01", Vector3.RIGHT, minf(speed / 7.0, 1.0) * 0.10)
	if actor.get("crouching") == true:
		rotate_bone("thigh_l", Vector3.RIGHT, -0.72 + gait * 0.35)
		rotate_bone("thigh_r", Vector3.RIGHT, -0.72 - gait * 0.35)
		rotate_bone("calf_l", Vector3.RIGHT, 1.12)
		rotate_bone("calf_r", Vector3.RIGHT, 1.12)
	_update_equipped_tool()

func _update_equipped_tool() -> void:
	if axe and actor.get("equipped") != null and actor.equipped != held_weapon:
		held_weapon = actor.equipped
		axe.queue_free()
		axe = preload("res://art/weapons/hand_tools.gd").make(held_weapon) if held_weapon in ["axe","spade"] else Placeholder.weapon(held_weapon)
		add_child(axe)
		if actor.get("local_control") == true: actor.call_deferred("_shadow_body")
	if axe and bone_ids.has("hand_r"):
		var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_ids["hand_r"])
		axe.global_transform = hand
		if bone_ids.has("weapon_r"):
			var tool_basis := Basis(Vector3.UP,Vector3.BACK,Vector3.RIGHT) if held_weapon == "axe" else Basis(Vector3.RIGHT,PI/2)
			axe.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bone_ids["weapon_r"]) * Transform3D(tool_basis,Vector3.ZERO)

