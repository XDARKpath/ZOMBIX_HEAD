class_name DestructibleCrate
extends Node3D
## 1 m wooden crate. damage() it; at 0 health it swaps to the 5-piece fractured mesh,
## each piece a RigidBody3D with a convex collider, and optionally drops loot.

signal broken

@export var health := 30.0
@export var fractured_scene: PackedScene = preload("res://art/env/interactive/SM_Int_Crate_Destructible_Fractured.glb")
@export var loot_scene: PackedScene
@export var piece_mass := 3.0
@export var piece_lifetime := 8.0
@export var break_impulse := 4.0

var _broken := false


## Walk up from a hit collider (e.g. a raycast result) to the crate, or null.
static func find_from(node: Node) -> DestructibleCrate:
	while node:
		if node is DestructibleCrate:
			return node
		node = node.get_parent()
	return null


func damage(amount: float, hit_point := Vector3.INF, hit_dir := Vector3.ZERO) -> void:
	if _broken:
		return
	health -= amount
	if health <= 0.0:
		break_apart(global_position + Vector3.UP * 0.5 if hit_point == Vector3.INF else hit_point, hit_dir)


func break_apart(origin: Vector3, dir := Vector3.ZERO) -> void:
	if _broken:
		return
	_broken = true
	var parent := get_parent()
	var frac := fractured_scene.instantiate()
	for node in frac.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var local := Transform3D.IDENTITY
		var n: Node = mi
		while n != frac:
			local = (n as Node3D).transform * local
			n = n.get_parent()
		var rb := RigidBody3D.new()
		rb.mass = piece_mass
		var m := MeshInstance3D.new()
		m.mesh = mi.mesh
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_convex_shape(true, true)
		rb.add_child(m)
		rb.add_child(cs)
		parent.add_child(rb)
		rb.global_transform = global_transform * local
		var away := (rb.global_position - origin).normalized() + dir.normalized() * 0.6 + Vector3.UP * 0.4
		rb.apply_central_impulse(away.normalized() * break_impulse * randf_range(0.7, 1.3))
		rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.6)
		get_tree().create_timer(piece_lifetime).timeout.connect(rb.queue_free)
	frac.free()
	if loot_scene:
		var loot := loot_scene.instantiate() as Node3D
		parent.add_child(loot)
		loot.global_position = global_position + Vector3.UP * 0.2
	broken.emit()
	queue_free()
