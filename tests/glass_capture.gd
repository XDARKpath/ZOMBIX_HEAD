extends SceneTree
var world: Node3D
func _initialize(): call_deferred("run")
func shot(id: String):
 await create_timer(1.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/glass-"+id+".png"))
func run():
 world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
 root.add_child(world)
 world.automated=true
 root.get_node("Session").launch()
 await create_timer(1.0).timeout
 world.player.controls_enabled=false
 world.player.set_physics_process(false)
 world.player.rig.set_physics_process(false)
 world.player.position=preload("res://world/zona1_rifugio/refuge_layout.gd").SHOP_NPC+Vector3(3,0,0)
 world.player.rig.yaw=PI/2
 world.player.rig.pitch=-0.10
 world.player.rig.reset_follow()
 world.player.credits=180
 await shot("hud")
 world.survival.open_shop()
 await shot("shop")
 world.survival.close_shop()
 world.survival.open_sheriff_dialogue()
 await shot("dialogue")
 quit()
