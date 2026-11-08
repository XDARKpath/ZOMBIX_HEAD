class_name PressurePlate
extends Node3D
## 1x1 m floor trap. Emits pressed/released when a physics body steps on it; the plate sinks 3 cm.

signal pressed(body: Node3D)
signal released

@export var trigger_group := ""          ## empty = any body (e.g. set to "player" or "zombie")
@export var travel := 0.03
@export var one_shot := false

var is_pressed := false
var _plate: Node3D
var _rest_y := 0.0
var _count := 0


func _ready() -> void:
	for n in find_children("*_Plate", "MeshInstance3D", true, false):
		_plate = n
	if _plate:
		_rest_y = _plate.position.y
	var area := Area3D.new()
	area.name = "Trigger"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.25, 0.8)
	cs.shape = box
	cs.position.y = 0.15
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_enter)
	area.body_exited.connect(_on_exit)


func _accepts(b: Node) -> bool:
	return trigger_group == "" or b.is_in_group(trigger_group)


func _on_enter(b: Node3D) -> void:
	if not _accepts(b):
		return
	_count += 1
	if not is_pressed:
		is_pressed = true
		_move(_rest_y - travel)
		pressed.emit(b)


func _on_exit(b: Node3D) -> void:
	if not _accepts(b):
		return
	_count = max(_count - 1, 0)
	if _count == 0 and is_pressed and not one_shot:
		is_pressed = false
		_move(_rest_y)
		released.emit()


func _move(y: float) -> void:
	if _plate:
		create_tween().tween_property(_plate, "position:y", y, 0.08)
