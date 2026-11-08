extends SceneTree
# json -> ZombieMotionData .res (packed arrays, identity for bones without a key)
func _init():
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/zombie_motion/zombie_clips_source.json"))
	var d := ZombieMotionData.new()
	d.fps = int(j.fps); d.bones = PackedStringArray(j.bones); d.pelvis_height = j.pelvis_height
	for k in j.attacks: d.attacks[k] = j.attacks[k]
	for name in j.clips:
		var c: Dictionary = j.clips[name]
		var q := PackedFloat32Array(); var p := PackedFloat32Array()
		for fr in c.data:
			for v in fr.q:
				if v == null: q.append_array([0, 0, 0, 1])
				else: q.append_array(v)
			p.append_array(fr.p)
		d.clips[name] = {"frames": int(c.frames), "loop": c.loop, "length": c.length, "q": q, "p": p}
	print(ResourceSaver.save(d, "res://art/zombie_motion/zombie_motion.res", ResourceSaver.FLAG_COMPRESS), " clips ", d.clips.size())
	quit()
