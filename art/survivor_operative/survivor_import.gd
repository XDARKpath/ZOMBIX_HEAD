@tool
extends EditorScenePostImport
## Post-import for SM_Survivor_Operative.glb:
## loops the locomotion clips, keeps the palette crisp, sets default equipment.

const LOOPING := [
	"Player_Idle_Unarmed", "Player_Idle_Rifle", "Player_Walk_Fwd_Rifle", "Player_Walk_Bwd_Rifle",
	"Player_Strafe_Left_Rifle", "Player_Strafe_Right_Rifle", "Player_Run_Fwd_Rifle",
	"Player_Crouch_Idle_Rifle", "Player_Crouch_Walk_Fwd",
]


func _post_import(scene: Node) -> Object:
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		for lib_name in player.get_animation_library_list():
			var lib := player.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				var anim := lib.get_animation(anim_name)
				anim.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(String(anim_name)) else Animation.LOOP_NONE
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat:
				# flat palette swatches: no filtering/mip bleeding between colours
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat.roughness = 1.0
				mat.metallic_specular = 0.2
		# NVG variants start hidden; SurvivorOperative toggles them at runtime
		if mi.name.begins_with("Slot4_Head_NVG"):
			mi.visible = false
	return scene
