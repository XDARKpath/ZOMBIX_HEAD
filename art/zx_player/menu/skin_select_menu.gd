extends Control
## Character select: turntable preview of the ZX player, skin + weapon pickers, emote, random, play.
## Saves the choice with ZXLoadout; in your level call ZXLoadout.apply(player).
## Keys: A/D or arrows = skin, W/S or up/down = weapon, E = emote, R = random, Enter = play, drag = rotate.

signal play_pressed(skin: int, weapon: String)

@export_file("*.tscn") var next_scene := ""
@export var player_scene: PackedScene = preload("res://art/zx_player/SM_ZX_Player.glb")

const BG := Color(0.086, 0.094, 0.106)
const INK := Color(0.91, 0.89, 0.85)
const DIM := Color(0.6, 0.6, 0.58)
const YEL := Color(0.9, 0.73, 0.16)

var player: ZXPlayer
var _skin := 0
var _weapon := 0
var _spin := 0.0
var _drag := false
var _pivot: Node3D
var _name: Label
var _desc: Label
var _wname: Label
var _wflav: Label
var _count: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var saved := ZXLoadout.load_choice()
	_skin = saved.skin
	_weapon = max(0, ZXWeapons.ORDER.find(saved.weapon))
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_stage()
	_build_ui()
	_apply()


func _build_stage() -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.74)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.7
	rim.light_color = Color(0.7, 0.85, 1.0)
	vp.add_child(rim)
	var floor_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 1.2
	cyl.height = 0.12
	cyl.radial_segments = 10
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.21, 0.23)
	cyl.material = fm
	floor_mesh.mesh = cyl
	floor_mesh.position.y = -0.06
	vp.add_child(floor_mesh)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.12
	tor.outer_radius = 1.16
	tor.rings = 10
	tor.ring_segments = 4
	var rm := StandardMaterial3D.new()
	rm.albedo_color = YEL
	rm.emission_enabled = true
	rm.emission = YEL
	tor.material = rm
	ring.mesh = tor
	vp.add_child(ring)
	_pivot = Node3D.new()
	vp.add_child(_pivot)
	player = player_scene.instantiate() as ZXPlayer
	player.start_weapon = ""
	_pivot.add_child(player)
	var cam := Camera3D.new()
	cam.position = Vector3(-0.55, 1.25, 3.2)
	cam.rotation_degrees = Vector3(-6, -4, 0)
	cam.fov = 38
	vp.add_child(cam)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(56, 52) if text.length() <= 2 else Vector2(150, 52)
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = YEL if accent else Color(0.16, 0.17, 0.19)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = YEL
	b.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate() as StyleBoxFlat
	hv.bg_color = YEL.lightened(0.15) if accent else Color(0.24, 0.25, 0.28)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_color_override("font_color", BG if accent else INK)
	b.add_theme_color_override("font_hover_color", BG if accent else INK)
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(60, 60)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)
	panel.add_child(_label("ZOMBIX HEAD", 54, INK))
	panel.add_child(_label("CHOOSE YOUR SURVIVOR", 22, YEL))
	panel.add_child(HSeparator.new())
	_count = _label("", 18, DIM)
	panel.add_child(_count)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_button("<", func(): _step_skin(-1)))
	_name = _label("", 40, INK)
	_name.custom_minimum_size = Vector2(300, 0)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_name)
	row.add_child(_button(">", func(): _step_skin(1)))
	panel.add_child(row)
	_desc = _label("", 20, DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(500, 60)
	panel.add_child(_desc)
	panel.add_child(HSeparator.new())
	panel.add_child(_label("LOADOUT", 18, YEL))
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 12)
	wrow.add_child(_button("<", func(): _step_weapon(-1)))
	_wname = _label("", 30, INK)
	_wname.custom_minimum_size = Vector2(300, 0)
	_wname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrow.add_child(_wname)
	wrow.add_child(_button(">", func(): _step_weapon(1)))
	panel.add_child(wrow)
	_wflav = _label("", 18, DIM)
	panel.add_child(_wflav)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 12)
	acts.add_child(_button("EMOTE", _emote))
	acts.add_child(_button("RANDOM", _random))
	acts.add_child(_button("PLAY", _play, true))
	panel.add_child(acts)
	var hint := _label("A/D skin   W/S weapon   E emote   R random   Enter play   drag to rotate", 15, DIM)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(60, -50)
	add_child(hint)


func _apply() -> void:
	_skin = posmod(_skin, ZXPlayer.SKINS.size())
	_weapon = posmod(_weapon, ZXWeapons.ORDER.size())
	player.set_skin(_skin)
	var id: String = ZXWeapons.ORDER[_weapon]
	player.equip(id)
	_name.text = ZXPlayer.SKINS[_skin][0].to_upper()
	_desc.text = ZXPlayer.SKINS[_skin][1]
	_count.text = "SKIN %d / %d" % [_skin + 1, ZXPlayer.SKINS.size()]
	_wname.text = ZXWeapons.display_name(id).to_upper()
	_wflav.text = ZXWeapons.get_def(id).get("flavor", "")


func _step_skin(d: int) -> void:
	_skin += d
	_apply()


func _step_weapon(d: int) -> void:
	_weapon += d
	_apply()


func _emote() -> void:
	player.emote("Player_Emote_Dance" if randf() < 0.6 else "Player_Emote_Dab")


func _random() -> void:
	_skin = randi() % ZXPlayer.SKINS.size()
	_weapon = randi() % ZXWeapons.ORDER.size()
	_apply()
	_emote()


func _play() -> void:
	var id: String = ZXWeapons.ORDER[_weapon]
	ZXLoadout.save(_skin, id)
	play_pressed.emit(_skin, id)
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)


func _process(dt: float) -> void:
	if not _drag:
		_spin += dt * 0.35
	_pivot.rotation.y = _spin


func _gui_input(ev: InputEvent) -> void:
	pass


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed and ev.position.x > size.x * 0.45
	elif ev is InputEventMouseMotion and _drag:
		_spin += ev.relative.x * 0.01
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_A, KEY_LEFT: _step_skin(-1)
			KEY_D, KEY_RIGHT: _step_skin(1)
			KEY_W, KEY_UP: _step_weapon(-1)
			KEY_S, KEY_DOWN: _step_weapon(1)
			KEY_E: _emote()
			KEY_R: _random()
			KEY_ENTER, KEY_KP_ENTER: _play()
