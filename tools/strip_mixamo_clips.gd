extends SceneTree
# Toglie da art/zombie_motion/zombie_motion.res le clip che venivano da Mixamo: il gioco non le usa più.
# godot --headless --path . -s res://tools/strip_mixamo_clips.gd
const PATH := "res://art/zombie_motion/zombie_motion.res"
const GONE := ["Z_Attack_Combo", "Z_React_Large_Left", "Z_React_Large_Right", "Z_Block_React"]


func _init() -> void:
	var data: Resource = load(PATH)
	for clip in GONE:
		print("tolta ", clip, ": ", data.clips.erase(clip), " / ", data.attacks.erase(clip))
	print("clip rimaste ", data.clips.size(), " salvataggio ", ResourceSaver.save(data, PATH))
	quit()
