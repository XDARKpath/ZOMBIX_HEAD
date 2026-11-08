# 04 / RANGER military 4x4 for the camp menu: the modelled vehicle (art/zx_vehicle) shown repaired,
# with the hood up and the driver door ajar so it reads as "being prepared" next to the fire.
extends RefCounted
const RangerVisual = preload("res://vehicle/ranger_visual.gd")

static func build(parent: Node3D) -> Node3D:
	var car := Node3D.new()
	car.name = "Military4x4"
	car.position = Vector3(-3.45,0,-0.72)
	parent.add_child(car)
	var ranger := RangerVisual.new()
	ranger.name = "Ranger"
	ranger.rotation.y = -PI/2          # the old camp model faced +X, the Ranger is authored facing -Z
	car.add_child(ranger)
	ranger.set_phase(3)
	ranger.set_lights(false)
	ranger.open_door("Hood", true)
	ranger._target["Door_FL"] = 28.0
	return car
