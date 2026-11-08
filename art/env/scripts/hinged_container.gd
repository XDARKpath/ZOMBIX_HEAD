class_name HingedContainer
extends Node3D
## Loot chests and the steel safe. The hinged child (*_Lid rotates on X, *_Door on Y) has its
## pivot on the hinge axis, so opening is a single rotation tween.

signal opened
signal closed

@export var open_angle_deg := 105.0
@export var open_time := 0.55
@export var locked := false

var is_open := false
var _hinge: Node3D
var _closed_rot := Vector3.ZERO
var _tween: Tween


func _ready() -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		if n.name.ends_with("_Lid") or n.name.ends_with("_Door"):
			_hinge = n
	if _hinge:
		_closed_rot = _hinge.rotation


## Call from your interaction system. Returns false while locked.
func interact() -> bool:
	if locked:
		return false
	if is_open:
		close()
	else:
		open()
	return true


func open() -> void:
	_swing(true)


func close() -> void:
	_swing(false)


func unlock() -> void:
	locked = false


func _swing(to_open: bool) -> void:
	if _hinge == null or is_open == to_open:
		return
	is_open = to_open
	var target := _closed_rot
	if to_open:
		var a := -deg_to_rad(open_angle_deg)
		target += Vector3(a, 0, 0) if _hinge.name.ends_with("_Lid") else Vector3(0, a, 0)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK if to_open else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hinge, "rotation", target, open_time)
	(opened if to_open else closed).emit()
