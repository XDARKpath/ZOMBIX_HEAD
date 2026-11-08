extends SceneTree
# Cerca i nodi 3D con transform non finita (NaN/inf) nel mondo della Zona 1: stampa percorso e script.
var world: Node3D
func _initialize(): call_deferred("run")
func bad(t: Transform3D) -> bool:
	return not (t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite() and t.basis.z.is_finite())
func run():
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate(); root.add_child(world); world.automated = true
	root.get_node("Session").launch()
	var seen := {}
	for f in 120:
		await process_frame
		for n in root.find_children("*", "Node3D", true, false):
			if (bad(n.transform) or (n.is_inside_tree() and bad(n.global_transform))) and not seen.has(n.get_path()):
				seen[n.get_path()] = true
				var up: Node = n
				while up and up.get_script() == null: up = up.get_parent()
				print("NAN frame=%d %s script=%s owner_script=%s" % [f, n.get_path(), n.get_script().resource_path if n.get_script() else "-", up.get_script().resource_path if up else "-"])
	print("NAN total=", seen.size())
	quit()
