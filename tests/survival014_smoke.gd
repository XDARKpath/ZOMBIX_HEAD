extends SceneTree
func _initialize():call_deferred("run")
func run():
	var w=load("res://world/zona1_rifugio/zombix.tscn").instantiate();root.add_child(w);w.automated=true;root.get_node("Session").launch()
	await create_timer(0.3).timeout
	print("ENEMIES ",w.targets.size())
	var e=w.targets[0];print("HEAD ",e.avatar.head_piece.mesh.get_aabb()," zones=",e.hitboxes.size())
	e.receive_hit("feet",20,Vector3.ZERO,"axe");print("CRAWL ",e.crawling)
	e.receive_hit("neck",20,Vector3.ZERO,"axe",true);print("HEADS ",w.survival.heads.size())
	await create_timer(0.2).timeout
	w.queue_free();await process_frame;await process_frame;quit()
