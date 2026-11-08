@tool
extends EditorScenePostImport
## Post-import for SM_ZX_Player.glb: loop flags, shared palette material, default skin visibility.

const LOOPING := [
	"Player_Idle_Unarmed", "Player_Idle_Rifle", "Player_Walk_Fwd_Rifle", "Player_Walk_Bwd_Rifle",
	"Player_Strafe_Left_Rifle", "Player_Strafe_Right_Rifle", "Player_Run_Fwd_Rifle", "Player_Crouch_Idle_Rifle",
	"Player_Crouch_Walk_Fwd", "Player_Rifle_Fire_Auto", "Player_Sniper_Aim", "Player_Pistol_Idle", "Player_Pistol_Aim",
	"Player_SMG_Fire_Auto", "Player_Sword_Idle", "Player_Sword_Block", "Player_Melee1H_Idle", "Player_Emote_Dance",
	"Player_Axe_Idle", "Player_Axe_Block", "Player_Car_Sit_Drive", "Player_Car_Steer_Left", "Player_Car_Steer_Right",
	"Player_Car_Sit_Passenger", "Player_Repair_Engine", "Player_Repair_Wheel", "Player_Blower_Sweep",
]
const PALETTE := "res://art/env/materials/M_Env_Palette.tres"


func _post_import(scene: Node) -> Object:
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		for lib_name in player.get_animation_library_list():
			var lib := player.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				lib.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if LOOPING.has(String(anim_name)) else Animation.LOOP_NONE
	var mat: Material = load(PALETTE)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			mi.mesh.surface_set_material(i, mat)
		mi.visible = String(mi.name) == "Skin_Operative" or String(mi.name).begins_with("Slot1") \
			or String(mi.name).begins_with("Slot2") or String(mi.name).begins_with("Slot3") or String(mi.name) == "Slot4_Head_BallisticCap"
	return scene
