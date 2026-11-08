extends Node3D
# Mano procedurale originale (guanto): 5 dita snodate su 20 falangi.
# Espone la stessa interfaccia della vecchia mano, così prima persona e falò
# non cambiano il resto del codice.
var side: String = "r"
var rig: Skeleton3D
var source_mesh: MeshInstance3D
var fingertips: Array[Vector3] = []
var digit_meshes: int = 0
var _digit_bones: Array[Array] = []
var _tip_ids: Array[int] = []
const DIGITS := ["indexFinger", "middleFinger", "ringFinger", "littleFinger"]

static func trim_source(node: Node, key: String, wrist_x: float) -> int:
	# Se le mani sono fuse nel corpo le tolgo con il vecchio ritaglio
	# sulla T-pose, così resta solo il guanto procedurale.
	return preload("res://ui/camp/hand_mesh_trim.gd").trim_source(node, key, wrist_x)

func _piece(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	# Guanto arrotondato: capsula schiacciata invece di una scatola.
	var view := MeshInstance3D.new()
	var radius := minf(size.x, size.z) * 0.5
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = size.y
	mesh.radial_segments = 10
	mesh.rings = 4
	view.mesh = mesh
	view.position = at
	view.scale = Vector3(size.x / (radius * 2.0), 1.0, size.z / (radius * 2.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	view.material_override = mat
	add_child(view)
	return view

func build(hand_side: String) -> void:
	side = hand_side
	var mirror := 1.0 if side == "l" else -1.0
	rig = Skeleton3D.new()
	rig.name = "HandRig"
	add_child(rig)
	# Polso e palmo: il manico passa davanti alle nocche.
	_piece(Vector3(0, 0.020, -0.010), Vector3(0.076, 0.060, 0.050), Color("a97a58"))
	_piece(Vector3(0, 0.105, -0.020), Vector3(0.095, 0.110, 0.052), Color("b98763"))
	for i in range(DIGITS.size()):
		var x := (0.030 - 0.020 * float(i)) * mirror
		_add_digit(DIGITS[i], [
			Vector3(x, 0.150, 0.000),
			Vector3(x, 0.140, 0.032),
			Vector3(x, 0.120, 0.050),
			Vector3(x, 0.096, 0.050),
		])
	_add_digit("thumbFinger", [
		Vector3(0.050 * mirror, 0.095, 0.000),
		Vector3(0.050 * mirror, 0.092, 0.028),
		Vector3(0.040 * mirror, 0.086, 0.046),
		Vector3(0.026 * mirror, 0.080, 0.054),
	])
	rig.reset_bone_poses()
	pose("relaxed", 0.0)

func _add_digit(digit: String, points: Array) -> void:
	var parent_basis := Basis.IDENTITY
	var parent_pos := Vector3.ZERO
	var ids: Array[int] = []
	for i in range(4):
		var at: Vector3 = points[i]
		var span: Vector3 = points[mini(i + 1, 3)] - points[i] if i < 3 else points[3] - points[2]
		var length: float = span.length()
		var basis := Basis(Quaternion(Vector3.UP, span.normalized()))
		var bone := "%s_0%d_%s" % [digit, i + 1, side]
		var idx := rig.get_bone_count()
		rig.add_bone(bone)
		if i > 0:
			rig.set_bone_parent(idx, idx - 1)
		rig.set_bone_rest(idx, Transform3D(parent_basis.inverse() * basis, parent_basis.inverse() * (at - parent_pos)))
		parent_basis = basis
		parent_pos = at
		ids.append(idx)
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = bone
		rig.add_child(attachment)
		var segment := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.0078
		mesh.height = length * 1.08
		mesh.radial_segments = 8
		mesh.rings = 3
		segment.mesh = mesh
		segment.position = Vector3(0, length * 0.5, 0)
		segment.scale = Vector3(1.0, 1.0, 1.25)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("b98763")
		mat.roughness = 0.9
		segment.material_override = mat
		attachment.add_child(segment)
		digit_meshes += 1
	_digit_bones.append(ids)
	_tip_ids.append(ids[3])

func pose(profile: String, time: float) -> void:
	if not rig:
		return
	var curl := 0.15
	match profile:
		"grip": curl = 0.55
		"pistol": curl = 0.45
		"support": curl = 0.12
		"cigarette": curl = 0.50
		"cloth": curl = 0.08
	curl += sin(time * 0.9) * 0.02
	var factors := [0.0, 0.55, 0.85, 0.5]
	for digit in _digit_bones:
		for i in range(1, 4):
			rig.set_bone_pose_rotation(digit[i], Quaternion(Vector3.RIGHT, curl * factors[i]))
	fingertips.clear()
	for id in _tip_ids:
		fingertips.append(rig.get_bone_global_pose(id).origin)

# Asse e centro del tunnel di presa, sulla verticale del manico.
func grip_frame() -> Dictionary:
	return {"center": Vector3(0, 0.100, 0.030), "axis": Vector3.UP}

func cigarette_anchor() -> Vector3:
	return Vector3(0.026, 0.082, 0.058)
