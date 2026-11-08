extends SceneTree
var actor: Node3D
var animation: AnimationPlayer
var clips: PackedStringArray
var index:=0
var label: Label
func _initialize():call_deferred("build")
func build():
 var scene:=Node3D.new()
 root.add_child(scene)
 var camera:=Camera3D.new()
 scene.add_child(camera)
 camera.position=Vector3(2.4,1.7,3.6)
 camera.look_at(Vector3(0,0.9,0))
 var floor_mesh:=MeshInstance3D.new()
 var plane:=PlaneMesh.new()
 plane.size=Vector2(12,12)
 floor_mesh.mesh=plane
 var mat:=StandardMaterial3D.new()
 mat.albedo_color=Color("34464b")
 floor_mesh.material_override=mat
 scene.add_child(floor_mesh)
 var sun:=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-40,-30,0)
 sun.light_energy=1.3
 sun.shadow_enabled=true
 scene.add_child(sun)
 var fill:=DirectionalLight3D.new()
 fill.rotation_degrees=Vector3(-20,160,0)
 fill.light_color=Color("8ccfdf")
 fill.light_energy=0.8
 scene.add_child(fill)
 actor=load("res://art/survivor_operative/SM_Survivor_Operative.glb").instantiate()
 actor.build_animation_tree=false
 scene.add_child(actor)
 animation=actor.find_child("AnimationPlayer",true,false)
 for clip in animation.get_animation_list():
  if clip.begins_with("Player_"):clips.append(clip)
 label=Label.new()
 label.position=Vector2(40,40)
 label.add_theme_font_size_override("font_size",24)
 root.add_child(label)
 play()
func play():
 animation.play(clips[index],0.15)
 label.text="SURVIVOR OPERATIVE · %d / %d\n%s\n\n← / → cambia · SPAZIO ripeti · ESC chiudi"%[index+1,clips.size(),clips[index]]
func _process(_delta):
 if Input.is_physical_key_pressed(KEY_ESCAPE):quit()
 return false
func _input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_RIGHT:index=(index+1)%clips.size();play()
  elif event.physical_keycode==KEY_LEFT:index=posmod(index-1,clips.size());play()
  elif event.physical_keycode==KEY_SPACE:play()
