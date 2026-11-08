# Control sopra le pagine del menu: particelle decorative che non intercettano input.
extends Control
var motes: Array[Vector4] = []
var time: float = 0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 735
	for i in range(22): motes.append(Vector4(rng.randf_range(0,1440),rng.randf_range(0,900),rng.randf_range(0.6,1.7),rng.randf_range(0,TAU)))
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta
	for i in range(motes.size()):
		motes[i].y -= delta*(9+motes[i].z*7)
		motes[i].x += sin(time*0.3+motes[i].w)*delta*6
		if motes[i].y< -10: motes[i].y=910
	queue_redraw()
func _draw() -> void:
	for mote in motes:
		var point := Vector2(mote.x,mote.y)
		var alpha := (0.15+0.15*sin(time*1.1+mote.w))*smoothstep(0,80,mote.y)
		draw_circle(point,mote.z*3,Color(1,0.24,0.03,alpha*0.10))
		draw_circle(point,mote.z,Color(1,0.62,0.18,alpha))
