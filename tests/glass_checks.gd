extends SceneTree
func _initialize():call_deferred("run")
func run():
 var world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
 root.add_child(world)
 world.automated=true
 root.get_node("Session").launch()
 await create_timer(0.3).timeout
 world.player.set_physics_process(false)
 world.player.position=preload("res://world/zona1_rifugio/refuge_layout.gd").SHOP_NPC+Vector3(2,0,0)
 world.player.credits=300
 world.survival.open_shop()
 assert(world.survival.shop_open)
 world.survival.request("buy:pistol")
 await process_frame
 assert("pistol" in world.player.owned)
 assert(world.player.credits==175)
 world.survival.request("buyslot")
 await process_frame
 assert(world.player.inventory_slots==5)
 world.survival.close_shop()
 world.survival.open_sheriff_dialogue()
 assert(world.survival.dialogue_open)
 world.survival.choose_sheriff_option(0)
 assert(not world.survival.dialogue_text.text.is_empty())
 world.survival.close_sheriff_dialogue()
 print("GLASS UI PASS: purchase, wallet, inventory upgrade, dialogue choice, close")
 quit()
