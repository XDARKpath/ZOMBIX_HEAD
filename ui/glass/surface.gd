extends RefCounted
static func add(host: Control, opacity: float = 0.6, circular: bool = false, radius: float = 10.0) -> ColorRect:
 var glass := ColorRect.new()
 glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
 glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var mat := ShaderMaterial.new()
 mat.shader = preload("res://ui/glass/frost.gdshader")
 mat.set_shader_parameter("opacity",opacity)
 mat.set_shader_parameter("circular",1.0 if circular else 0.0)
 mat.set_shader_parameter("radius",radius)
 glass.material = mat
 host.add_child(glass)
 host.move_child(glass,0)
 glass.show_behind_parent = true
 glass.resized.connect(func(): mat.set_shader_parameter("panel_size",glass.size))
 return glass
static func hover(button: Button) -> void:
 button.focus_mode = Control.FOCUS_ALL
 button.mouse_entered.connect(func(): _lift(button,1.025))
 button.mouse_exited.connect(func(): _lift(button,1.0))
 button.focus_entered.connect(func(): _lift(button,1.025))
 button.focus_exited.connect(func(): _lift(button,1.0))
static func _lift(button: Button, amount: float) -> void:
 if button.has_meta("hover_tween"):
  var previous: Tween = button.get_meta("hover_tween")
  if previous.is_valid(): previous.kill()
 button.pivot_offset = button.size*0.5
 var tween := button.create_tween()
 button.set_meta("hover_tween",tween)
 tween.tween_property(button,"scale",Vector2.ONE*amount,0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
