extends SceneTree
# Stampa le dimensioni (AABB) degli asset del kit ambiente: serve per posizionarli.
func _initialize():
	for dir in ["building", "shop", "interactive"]:
		for f in DirAccess.get_files_at("res://art/env/" + dir):
			if not f.ends_with(".glb"): continue
			var n: Node3D = load("res://art/env/%s/%s" % [dir, f]).instantiate()
			root.add_child(n)
			var box := AABB()
			var first := true
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				var b: AABB = mi.global_transform * mi.get_aabb()
				box = b if first else box.merge(b)
				first = false
			print("%-40s pos=%s size=%s" % [f.get_basename(), box.position.snapped(Vector3.ONE * 0.01), box.size.snapped(Vector3.ONE * 0.01)])
			n.free()
	quit()
