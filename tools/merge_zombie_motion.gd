extends SceneTree
# Unisce in art/zombie_motion/zombie_motion.res le clip che mancano da altri .res (pacchetti Cripta e Rocca):
#   godot --headless --path ZOMBIX_HEAD -s res://tools/merge_zombie_motion.gd -- <altro.res> [<altro.res> ...]
# Le clip già presenti restano quelle del progetto (reazioni Mixamo comprese). Le ossa devono coincidere.
func _init():
	var path := "res://art/zombie_motion/zombie_motion.res"
	var mine: Resource = load(path)
	var before: int = mine.clips.size()
	for src in OS.get_cmdline_user_args():
		var other: Resource = ResourceLoader.load(src, "", ResourceLoader.CACHE_MODE_IGNORE)
		if other == null:
			print("MERGE non leggo ", src); continue
		if other.bones != mine.bones:
			print("MERGE ossa diverse in ", src, " (", other.bones.size(), " vs ", mine.bones.size(), ")"); continue
		for name in other.clips:
			if not mine.clips.has(name):
				mine.clips[name] = other.clips[name]
				print("MERGE + ", name, " da ", src.get_file())
		for name in other.attacks:
			if not mine.attacks.has(name): mine.attacks[name] = other.attacks[name]
	print("MERGE clip ", before, " -> ", mine.clips.size(), " salvato ", ResourceSaver.save(mine, path, ResourceSaver.FLAG_COMPRESS))
	print("MERGE attacchi ", mine.attacks.keys())
	quit()
