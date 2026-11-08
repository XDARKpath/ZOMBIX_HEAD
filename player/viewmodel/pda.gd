extends Node3D
# PDA/GPS tattico tenuto dalla mano sinistra: scocca in ardesia, cornice ambrata e
# schermo di vetro traslucido. Il testo arriva da ui/route_gps.gd e viene disegnato
# in una SubViewport, così il GPS resta un oggetto nel mondo invece di un pannello 2D.
const SIZE := Vector2(0.19, 0.19)
const SCREEN := 0.155
var gps: Control
var viewport: SubViewport
var screen_label: Label


func build(source: Control) -> void:
	gps = source
	if gps: gps.embedded = true
	viewport = SubViewport.new()
	viewport.size = Vector2i(650, 650)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.07, 0.07, 0.62)
	style.border_color = Color(0.84, 0.65, 0.39, 0.85)
	style.set_border_width_all(3)
	style.border_width_left = 8
	panel.add_theme_stylebox_override("panel", style)
	viewport.add_child(panel)
	screen_label = Label.new()
	screen_label.position = Vector2(34, 34)
	screen_label.size = Vector2(590, 590)
	screen_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI"])
	screen_label.add_theme_font_override("font", font)
	screen_label.add_theme_font_size_override("font_size", 21)
	screen_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	viewport.add_child(screen_label)
	_box(Vector3(0, 0, -0.002), Vector3(SIZE.x, SIZE.y, 0.016), Color(0.13, 0.16, 0.17), 0.7)
	_box(Vector3(0, SIZE.y * 0.5 - 0.004, 0.006), Vector3(SIZE.x - 0.02, 0.004, 0.004), Color(0.84, 0.62, 0.34), 0.4, 0.6)
	_box(Vector3(-SIZE.x * 0.5 - 0.004, 0, -0.002), Vector3(0.010, SIZE.y * 0.7, 0.020), Color(0.08, 0.09, 0.09), 0.9)
	_box(Vector3(SIZE.x * 0.5 - 0.03, SIZE.y * 0.5 + 0.02, -0.004), Vector3(0.010, 0.040, 0.010), Color(0.08, 0.09, 0.09), 0.9)
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(SCREEN, SCREEN)
	screen.mesh = quad
	screen.position = Vector3(0, -0.006, 0.0065)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = viewport.get_texture()
	screen.material_override = mat
	add_child(screen)
	# Lastra di vetro sopra lo schermo: riflesso e bordo freddo, quasi trasparente.
	var glass := MeshInstance3D.new()
	var glass_quad := QuadMesh.new()
	glass_quad.size = Vector2(SCREEN + 0.012, SCREEN + 0.012)
	glass.mesh = glass_quad
	glass.position = Vector3(0, -0.006, 0.0075)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.55, 0.78, 0.80, 0.10)
	glass_mat.metallic = 0.4
	glass_mat.roughness = 0.06
	glass_mat.rim_enabled = true
	glass_mat.rim = 0.6
	glass.material_override = glass_mat
	add_child(glass)
	# Presa abbassata e avanzata: il palmo tocca il retro del PDA e le dita lo seguono
	# senza compenetrarlo; il pollice resta sulla cornice sinistra.
	preload("res://art/weapons/grip_sockets.gd").add(self, "Socket_LeftHand", Vector3(-0.062, -0.027, -0.0035), Vector3(-0.95, 0.3, 0), Vector3(0.3, 0.95, 0), 0.0, "bezel")
	for mesh in find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _box(at: Vector3, size: Vector3, color: Color, roughness: float, emission: float = 0.0) -> void:
	var view := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	view.mesh = box
	view.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.rim_enabled = true
	mat.rim = 0.25
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	view.material_override = mat
	add_child(view)


func refresh() -> void:
	if gps: screen_label.text = gps.screen_text()
