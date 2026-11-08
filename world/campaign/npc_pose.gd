extends "res://art/survivor_visual.gd"
# NPC decorativi in posa (modelli dei batch ZOMBIX): rotazioni nello spazio di riposo
# globale come il resto del gioco, con un respiro leggero. Gli oggetti in mano sono i
# *_Held.glb esportati da tools/zx_characters (frame del socket weapon_r).
var pose_id := ""
var held: Node3D
var rod: Node3D

static func spawn(parent: Node3D, model: String, held_path: String, pose: String, at: Vector3, yaw: float) -> Node3D:
	var npc := Node3D.new()
	npc.set_script(load("res://world/campaign/npc_pose.gd"))
	npc.name = "NPC_" + pose.capitalize().replace(" ", "")
	parent.add_child(npc)
	npc.position = at
	npc.rotation.y = yaw
	npc.pose_id = pose
	npc.configure(model, npc, false)
	if npc.axe:
		npc.axe.queue_free()
		npc.axe = null
	if held_path != "" and ResourceLoader.exists(held_path):
		npc.held = load(held_path).instantiate()
		npc.add_child(npc.held)
		_palette(npc.held)
		preload("res://art/env/scripts/weapon_item.gd").attach_node(npc.held, npc, "weapon_r")
	if pose == "fishing":
		npc.rod = preload("res://art/placeholders.gd").fishing_rod()
		npc.add_child(npc.rod)
	# Seduti: il modello scende finché il bacino tocca la seduta.
	if pose in ["fishing", "sit_steps"]:
		for child in npc.get_children():
			if child is Node3D and not child.find_children("*", "Skeleton3D", true, false).is_empty():
				child.position.y = -0.84
	npc._pose(0.0)
	return npc

func _pose(_delta: float) -> void:
	if not skeleton: return
	skeleton.reset_bone_poses()
	var breath := sin(clock * 1.3 + position.x) * 0.015
	match pose_id:
		"fishing":
			# Seduto sul bordo del pontile, gambe a penzoloni, canna tenuta con due mani.
			_seated(1.52, 1.45)
			rotate_bone("spine_01", Vector3.RIGHT, 0.18 + breath)
			rotate_bone("neck_01", Vector3.RIGHT, 0.12)
			aim_arm("l", Vector3(0.15, -0.55, 0.82), 0.55)
			aim_arm("r", Vector3(-0.2, -0.5, 0.84), 0.7)
			# Respiro e sguardo dalla clip di riposo dello ZX Player, sopra la posa seduta.
			clips().additive("Idle_Unarmed", clock * 0.7, ["spine_02", "spine_03", "neck_01", "head"], 1.5)
		"guard":
			# In piedi, peso su una gamba, fucile basso pronto.
			transform_bone("thigh_l", Basis(Vector3.RIGHT, -0.06) * Basis(Vector3.UP, 0.18))
			transform_bone("thigh_r", Basis(Vector3.RIGHT, 0.08) * Basis(Vector3.UP, -0.1))
			rotate_bone("calf_l", Vector3.RIGHT, 0.12)
			rotate_bone("spine_01", Vector3.UP, 0.25)
			rotate_bone("spine_02", Vector3.RIGHT, 0.06 + breath)
			rotate_bone("head", Vector3.UP, -0.3 + sin(clock * 0.25) * 0.35)
			aim_arm("r", Vector3(-0.22, -0.9, 0.25), 1.25)
			aim_arm("l", Vector3(0.12, -0.8, 0.55), 1.55)
		"sit_steps":
			# Seduto sui gradini, avambracci sulle ginocchia, fucile a pompa sulle gambe.
			_seated(1.35, 1.6)
			transform_bone("thigh_l", Basis(Vector3.RIGHT, -1.35) * Basis(Vector3.UP, 0.25))
			transform_bone("thigh_r", Basis(Vector3.RIGHT, -1.35) * Basis(Vector3.UP, -0.25))
			rotate_bone("spine_01", Vector3.RIGHT, 0.42 + breath)
			rotate_bone("spine_02", Vector3.RIGHT, 0.12)
			rotate_bone("neck_01", Vector3.RIGHT, -0.45)
			aim_arm("l", Vector3(0.25, -0.62, 0.74), 0.45)
			aim_arm("r", Vector3(-0.25, -0.62, 0.74), 0.55)
		"lean":
			# Schiena contro il 4×4, caviglie incrociate, chiave inglese che dondola.
			transform_bone("thigh_l", Basis(Vector3.RIGHT, -0.22) * Basis(Vector3.UP, 0.1))
			transform_bone("thigh_r", Basis(Vector3.RIGHT, -0.16) * Basis(Vector3.BACK, -0.18))
			rotate_bone("calf_l", Vector3.RIGHT, 0.1)
			rotate_bone("pelvis", Vector3.RIGHT, -0.12)
			rotate_bone("spine_01", Vector3.RIGHT, -0.16 + breath)
			rotate_bone("head", Vector3.RIGHT, 0.12)
			# Braccia conserte, la chiave inglese che spunta dalla destra.
			aim_arm("l", Vector3(0.22, -0.95, 0.22), 1.65)
			aim_arm("r", Vector3(-0.22, -0.95, 0.24), 1.6 + sin(clock * 0.9) * 0.05)
		"guide":
			# In piedi, braccia conserte, il peso che passa da una gamba all'altra; guarda chi arriva e poi la torre.
			transform_bone("thigh_l", Basis(Vector3.RIGHT, -0.05) * Basis(Vector3.UP, 0.12))
			transform_bone("thigh_r", Basis(Vector3.RIGHT, 0.04) * Basis(Vector3.UP, -0.08))
			rotate_bone("pelvis", Vector3.BACK, sin(clock * 0.35) * 0.03)
			rotate_bone("spine_01", Vector3.RIGHT, 0.04 + breath)
			rotate_bone("head", Vector3.UP, sin(clock * 0.3) * 0.45)
			aim_arm("l", Vector3(0.22, -0.95, 0.22), 1.65)
			aim_arm("r", Vector3(-0.22, -0.95, 0.24), 1.6)
			clips().additive("Idle_Unarmed", clock * 0.7, ["spine_02", "spine_03", "neck_01"], 1.2)
		"zombie":
			# Infetto fermo nella nebbia: curvo, braccia protese, testa storta.
			rotate_bone("spine_01", Vector3.RIGHT, 0.32 + breath)
			rotate_bone("spine_02", Vector3.RIGHT, 0.18)
			transform_bone("neck_01", Basis(Vector3.RIGHT, 0.3) * Basis(Vector3.BACK, 0.25 + sin(clock * 0.6) * 0.08))
			aim_arm("l", Vector3(0.25, -0.45, 0.86), 0.35)
			aim_arm("r", Vector3(-0.3, -0.62, 0.72), 0.5)
			rotate_bone("thigh_l", Vector3.RIGHT, -0.12)
			rotate_bone("calf_l", Vector3.RIGHT, 0.2)
			clips().additive("Idle_Unarmed", clock * 0.6 + position.x, ["spine_02", "spine_03", "neck_01", "head"], 2.0)
	skeleton.force_update_all_bone_transforms()
	if rod:
		var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_ids["hand_r"])
		rod.global_position = hand.origin
		rod.global_basis = global_basis * Basis(Vector3.RIGHT, 1.05)

func _seated(thigh: float, calf: float) -> void:
	transform_bone("thigh_l", Basis(Vector3.RIGHT, -thigh) * Basis(Vector3.UP, 0.1))
	transform_bone("thigh_r", Basis(Vector3.RIGHT, -thigh) * Basis(Vector3.UP, -0.1))
	rotate_bone("calf_l", Vector3.RIGHT, calf + sin(clock * 0.8) * 0.12)
	rotate_bone("calf_r", Vector3.RIGHT, calf - 0.1 + sin(clock * 0.8 + 1.3) * 0.12)
