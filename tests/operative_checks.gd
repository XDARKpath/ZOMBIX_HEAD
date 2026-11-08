extends SceneTree
func _initialize():
 print("LOAD MODEL")
 var m = load("res://art/survivor_operative/SM_Survivor_Operative.glb").instantiate()
 print("MODEL OK")
 m.build_animation_tree=false
 root.add_child(m)
 print("TOOLS")
 root.add_child(preload("res://art/weapons/hand_tools.gd").make("axe"))
 root.add_child(preload("res://art/weapons/hand_tools.gd").make("axe"))
 print("OK")
 quit()
