extends SceneTree
var world: Node3D
func _initialize():call_deferred("run")
func shot(id:String):
 await create_timer(0.4).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/arms-"+id+".png"))
func run():
 world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
 root.add_child(world)
 world.automated=true
 root.get_node("Session").launch()
 await create_timer(0.5).timeout
 world.player.set_physics_process(false)
 world.player.rig.set_physics_process(false)
 world.player.position=Vector3(8,0.1,-11)
 world.player.rig.yaw=0
 world.player.rig.pitch=0
 world.player.rig.reset_follow()
 for weapon in ["axe","pistol","knife"]:
  world.player.equipped=weapon
  await create_timer(1.0).timeout
  await shot(weapon)
 world.player.equipped="axe"
 await create_timer(0.8).timeout
 world.player.melee.perform_attack(false)
 await shot("attack")
 quit()
