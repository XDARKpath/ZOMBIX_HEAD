extends Node3D
var player: CharacterBody3D
var status: Label
var pause_panel: PanelContainer
var paused := false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_default_clear_color(Color("182d35"))
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("2a4655")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("93afbb")
	env.ambient_light_energy=0.6
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment=env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-25,0)
	sun.light_color=Color("ffdfb1")
	sun.light_energy=1.7
	sun.shadow_enabled=true
	add_child(sun)
	block(Vector3(0,-0.25,-5),Vector3(40,0.5,40),Color("465952"))
	for z in range(-17,12,2):
		block(Vector3(0,0.003,z),Vector3(0.08,0.006,0.8),Color("d0bc8c"),false)
	block(Vector3(-5,0.225,-4),Vector3(3.0,0.45,0.55),Color("a37345"))
	block(Vector3(5,1.32,-5),Vector3(2.4,0.20,4),Color("4f6c70"))
	for x in [3.7,6.3]:block(Vector3(x,0.61,-5),Vector3(0.20,1.22,4),Color("35484b"))
	for x in [-10,10]:block(Vector3(x,1.4,-4),Vector3(0.3,2.8,22),Color("39484c"))
	block(Vector3(0,1.4,-15),Vector3(20,2.8,0.3),Color("39484c"))
	sign_at("OSTACOLO\nSPAZIO · SALTA",Vector3(-5,2,-5.8))
	sign_at("PASSAGGIO BASSO\nTIENI CTRL",Vector3(5,2.25,-7))
	sign_at("CORSA\nTIENI SHIFT",Vector3(0,2,-13))
	for i in range(10):
		var tree:Node3D=preload("res://art/placeholders.gd").tree("Pine_1")
		tree.position=Vector3(-16+i*3.5,0,-19)
		tree.scale=Vector3.ONE*1.7
		add_child(tree)
	player=load("res://player/player.tscn").instantiate()
	player.position=Vector3(0,0.05,6)
	player.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.melee.set_physics_process(false)
	player.rig.camera.current=true
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	label(ui,"ZOMBIX HEAD  /  PROVA MOVIMENTO",Vector2(35,24),24)
	label(ui,"PRIMA PERSONA · TAPPA 1",Vector2(36,57),14)
	label(ui,"WASD muovi   SHIFT corri   SPAZIO salta   CTRL abbassati   ESC menu",Vector2(35,842),18)
	status=label(ui,"",Vector2(35,95),17)
	var dot := Label.new()
	dot.text="·";dot.add_theme_font_size_override("font_size",30)
	dot.position=Vector2(715,432);ui.add_child(dot)
	pause_panel=PanelContainer.new()
	pause_panel.position=Vector2(510,290);pause_panel.custom_minimum_size=Vector2(420,240)
	ui.add_child(pause_panel)
	var list := VBoxContainer.new();list.add_theme_constant_override("separation",18);pause_panel.add_child(list)
	for entry in [["RIPRENDI",func():set_paused(false)],["TORNA AL FALÒ",func():get_tree().paused=false;get_tree().change_scene_to_file("res://world/zona1_rifugio/zombix.tscn")]]:
		var button := Button.new();button.text=entry[0];button.custom_minimum_size.y=70
		button.pressed.connect(entry[1]);list.add_child(button)
	pause_panel.hide()
	if OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name()!="headless":Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func block(at: Vector3,size_value: Vector3,color: Color,solid: bool=true) -> void:
	var mesh := BoxMesh.new();mesh.size=size_value
	var mat := StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=0.9
	mesh.material=mat
	var parent: Node3D=StaticBody3D.new() if solid else Node3D.new()
	parent.position=at;add_child(parent)
	var view := MeshInstance3D.new();view.mesh=mesh;parent.add_child(view)
	if solid:
		var collider := CollisionShape3D.new();var shape := BoxShape3D.new()
		shape.size=size_value;collider.shape=shape;parent.add_child(collider)

func sign_at(value: String,at: Vector3) -> void:
	var text := Label3D.new();text.text=value;text.position=at;text.font_size=40
	text.pixel_size=0.009;text.modulate=Color("f2e6cc");text.outline_size=8
	add_child(text)

func label(parent: Control,value: String,at: Vector2,font_size: int) -> Label:
	var text := Label.new();text.text=value;text.position=at
	text.add_theme_font_size_override("font_size",font_size)
	text.add_theme_color_override("font_color",Color("f1e6d0"))
	text.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	text.add_theme_constant_override("shadow_offset_x",2);text.add_theme_constant_override("shadow_offset_y",2)
	parent.add_child(text);return text

func _process(_delta: float) -> void:
	if not player:return
	var posture := "ABBASSATO" if player.crouching else ("CORSA" if player.sprinting else "CAMMINATA")
	status.text="%s  ·  FIATO %d"%[posture,ceili(player.stamina)]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):set_paused(not paused)

func set_paused(value: bool) -> void:
	paused=value;get_tree().paused=value;pause_panel.visible=value
	player.controls_enabled=not value;player.rig.controls_enabled=not value
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
