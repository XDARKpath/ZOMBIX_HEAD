extends RefCounted
# Spalla e parte alta del braccio per i modelli che ne sono privi (il bruto e la skin Mechanic hanno un vuoto tra busto e
# gomito). I pezzi seguono le ossa, quindi stanno al loro posto con ogni animazione, nel menu come in partita e online.

const SIDES := ["l", "r"]


static func apply(skeleton: Skeleton3D, color: Color, radius: float = 0.062) -> void:
	if skeleton == null or skeleton.has_meta("limb_patch"):
		if skeleton: show_patch(skeleton, true)
		return
	skeleton.set_meta("limb_patch", true)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	for side in SIDES:
		var upper := skeleton.find_bone("upperarm_" + side)
		var lower := skeleton.find_bone("lowerarm_" + side)
		if upper < 0 or lower < 0: continue
		var grip := BoneAttachment3D.new()
		grip.name = "BraccioAggiunto_" + side
		skeleton.add_child(grip)
		grip.bone_name = skeleton.get_bone_name(upper)
		grip.set_meta("limb_part", true)
		var along: Vector3 = skeleton.get_bone_rest(lower).origin
		var arm := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.height = along.length() * 1.06
		tube.top_radius = radius * 0.8
		tube.bottom_radius = radius
		tube.radial_segments = 7
		tube.rings = 1
		tube.material = mat
		arm.mesh = tube
		grip.add_child(arm)
		arm.transform = Transform3D(Basis(Quaternion(Vector3.DOWN, along.normalized())), along * 0.5)
		var ball := MeshInstance3D.new()
		var round_part := SphereMesh.new()
		round_part.radius = radius * 1.42
		round_part.height = radius * 2.75
		round_part.radial_segments = 8
		round_part.rings = 4
		round_part.material = mat
		ball.mesh = round_part
		grip.add_child(ball)


static func show_patch(skeleton: Skeleton3D, on: bool) -> void:
	if skeleton == null: return
	for child in skeleton.get_children():
		if child.has_meta("limb_part"): child.visible = on
