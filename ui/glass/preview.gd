extends SubViewportContainer
var item_id := "sheriff"
var model: Node3D
var timer := 0.0
var view: SubViewport
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 stretch = true
 view = SubViewport.new()
 view.size = Vector2i(320,240)
 view.transparent_bg = true
 view.own_world_3d = true
 view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
 add_child(view)
 var scene := Node3D.new()
 view.add_child(scene)
 var camera := Camera3D.new()
 scene.add_child(camera)
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 0.8 if item_id == "sheriff" else 0.9
 camera.position = Vector3(0,1.5,3) if item_id == "sheriff" else Vector3(0,0.15,3)
 camera.look_at(Vector3(0,1.48,0) if item_id == "sheriff" else Vector3.ZERO)
 for i in range(2):
  var light := DirectionalLight3D.new()
  light.rotation_degrees = Vector3(-25,-35 if i == 0 else 140,0)
  light.light_color = Color("d6f7f0") if i == 0 else Color("eebb7c")
  light.light_energy = 1.5 if i == 0 else 2.0
  scene.add_child(light)
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_CLEAR_COLOR
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color("91b1b6")
 env.environment.ambient_light_energy = 0.65
 scene.add_child(env)
 if item_id == "sheriff":
  model = preload("res://art/survivor_visual.gd").new()
  scene.add_child(model)
  model.configure("survivor",model)
  if model.axe: model.axe.hide()
 elif item_id == "pack":
  model = Node3D.new()
  scene.add_child(model)
  var body := MeshInstance3D.new()
  var box := BoxMesh.new()
  box.size = Vector3(0.35,0.46,0.18)
  body.mesh = box
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color("738478")
  body.material_override = mat
  model.add_child(body)
  for y in [-0.12,0.10]:
   var pocket := MeshInstance3D.new()
   var shape := BoxMesh.new()
   shape.size = Vector3(0.28,0.15,0.09)
   pocket.mesh = shape
   pocket.position = Vector3(0,y,0.12)
   pocket.material_override = mat
   model.add_child(pocket)
  for x in [-0.11,0.11]:
   var strap := MeshInstance3D.new()
   var mesh := BoxMesh.new()
   mesh.size = Vector3(0.045,0.50,0.035)
   strap.mesh = mesh
   strap.position = Vector3(x,0,0.18)
   model.add_child(strap)
 else:
  model = load("res://art/weapons/pistol.tscn").instantiate() if item_id == "pistol" else preload("res://art/placeholders.gd").knife()
  scene.add_child(model)
  model.rotation.z = -0.3
  if item_id == "knife": model.position.y = -0.18
func _process(delta: float) -> void:
 if not is_visible_in_tree() or not model: return
 timer += delta
 model.rotation.y = sin(timer*0.5)*0.22 if item_id == "sheriff" else timer*0.22
