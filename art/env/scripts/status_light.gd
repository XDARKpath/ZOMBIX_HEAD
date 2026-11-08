@tool
class_name StatusLight
extends Node3D
## Red / green indicator. Shows the glowing lens child and a small OmniLight for the active state.

enum State { OFF, RED, GREEN }

@export var state := State.RED: set = set_state
@export var cast_light := true
@export var blink := false
@export var blink_rate := 2.0

var _red: Node3D
var _green: Node3D
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		if n.name.ends_with("_Lit_Red"):
			_red = n
		elif n.name.ends_with("_Lit_Green"):
			_green = n
	if cast_light and not Engine.is_editor_hint():
		_light = OmniLight3D.new()
		_light.omni_range = 2.0
		_light.light_energy = 0.8
		_light.position = Vector3(0, 0, 0.25)
		add_child(_light)
	set_state(state)


func set_state(s: State) -> void:
	state = s
	if not is_inside_tree():
		return
	if _red:
		_red.visible = s == State.RED
	if _green:
		_green.visible = s == State.GREEN
	if _light:
		_light.visible = s != State.OFF
		_light.light_color = Color(1, 0.2, 0.15) if s == State.RED else Color(0.3, 1, 0.4)
		_light.position.y = 0.08 if s == State.RED else -0.08


func _process(dt: float) -> void:
	if not blink or state == State.OFF or Engine.is_editor_hint():
		return
	_t += dt * blink_rate
	var on := fmod(_t, 1.0) < 0.5
	if _red:
		_red.visible = on and state == State.RED
	if _green:
		_green.visible = on and state == State.GREEN
	if _light:
		_light.visible = on
