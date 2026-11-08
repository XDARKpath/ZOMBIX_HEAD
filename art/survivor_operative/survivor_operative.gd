class_name SurvivorOperative
extends Node3D
## Root script of SM_Survivor_Operative.glb (set as "Root Script" in the import settings).
## Equipment slots + the AnimationTree from the spec (StateMachine + OneShot overlays).

enum HeadGear { NONE, CAP, CAP_NVG_DOWN, CAP_NVG_UP }

@export var plate_carrier := true: set = set_plate_carrier
@export var backpack := true: set = set_backpack
@export var thigh_holster := true: set = set_thigh_holster
@export var head_gear := HeadGear.CAP: set = set_head_gear
@export var build_animation_tree := true

var tree: AnimationTree
var _movement: AnimationNodeStateMachinePlayback
var _action_anim: AnimationNodeAnimation
var _crouched := false
var _dead := false
const SHOTS := ["Reload", "Fire", "Melee_Kick", "Action"]


func _ready() -> void:
	_apply_equipment()
	if build_animation_tree:
		_build_tree()


# ------------------------------------------------------------------ equipment
func set_plate_carrier(v: bool) -> void:
	plate_carrier = v
	_apply_equipment()

func set_backpack(v: bool) -> void:
	backpack = v
	_apply_equipment()

func set_thigh_holster(v: bool) -> void:
	thigh_holster = v
	_apply_equipment()

func set_head_gear(v: HeadGear) -> void:
	head_gear = v
	_apply_equipment()

func _slot(n: String) -> Node3D:
	return find_child(n, true, false) as Node3D

func _show(n: String, v: bool) -> void:
	var s := _slot(n)
	if s:
		s.visible = v

func _apply_equipment() -> void:
	if not is_inside_tree():
		return
	_show("Slot1_Chest_PlateCarrier", plate_carrier)
	_show("Slot2_Back_SurvivalPack", backpack)
	_show("Slot3_Thigh_Holster", thigh_holster)
	_show("Slot4_Head_BallisticCap", head_gear != HeadGear.NONE)
	_show("Slot4_Head_NVG_Down", head_gear == HeadGear.CAP_NVG_DOWN)
	_show("Slot4_Head_NVG_Up", head_gear == HeadGear.CAP_NVG_UP)


# ------------------------------------------------------------------ animation tree
func _anim(n: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = n
	return a

func _one_shot(fade_in := 0.08, fade_out := 0.15) -> AnimationNodeOneShot:
	var o := AnimationNodeOneShot.new()
	o.fadein_time = fade_in
	o.fadeout_time = fade_out
	o.filter_enabled = false
	return o

func _xfade(t := 0.2) -> AnimationNodeStateMachineTransition:
	var tr := AnimationNodeStateMachineTransition.new()
	tr.xfade_time = t
	return tr

func _build_tree() -> void:
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		push_warning("SurvivorOperative: no AnimationPlayer found")
		return

	# Locomotion: x = strafe (-1 left / +1 right), y = forward (-1 back, 1 walk, 2 run)
	var loco := AnimationNodeBlendSpace2D.new()
	loco.min_space = Vector2(-1, -1)
	loco.max_space = Vector2(1, 2)
	loco.add_blend_point(_anim("Player_Idle_Rifle"), Vector2(0, 0))
	loco.add_blend_point(_anim("Player_Walk_Fwd_Rifle"), Vector2(0, 1))
	loco.add_blend_point(_anim("Player_Walk_Bwd_Rifle"), Vector2(0, -1))
	loco.add_blend_point(_anim("Player_Strafe_Left_Rifle"), Vector2(-1, 0))
	loco.add_blend_point(_anim("Player_Strafe_Right_Rifle"), Vector2(1, 0))
	loco.add_blend_point(_anim("Player_Run_Fwd_Rifle"), Vector2(0, 2))

	# Crouch: only a forward sneak exists, reused for every direction
	var crouch := AnimationNodeBlendSpace2D.new()
	crouch.min_space = Vector2(-1, -1)
	crouch.max_space = Vector2(1, 1)
	crouch.add_blend_point(_anim("Player_Crouch_Idle_Rifle"), Vector2(0, 0))
	for p in [Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]:
		crouch.add_blend_point(_anim("Player_Crouch_Walk_Fwd"), p)

	var sm := AnimationNodeStateMachine.new()
	sm.add_node("Locomotion_BlendSpace2D", loco, Vector2(200, 100))
	sm.add_node("Crouch_BlendSpace2D", crouch, Vector2(200, 260))
	sm.add_node("Death_State", _anim("Player_Death_Collapse_Front"), Vector2(500, 100))
	sm.add_node("Death_Blown_Back", _anim("Player_Death_Blown_Back"), Vector2(500, 260))
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", "Locomotion_BlendSpace2D", start)
	sm.add_transition("Locomotion_BlendSpace2D", "Crouch_BlendSpace2D", _xfade(0.25))
	sm.add_transition("Crouch_BlendSpace2D", "Locomotion_BlendSpace2D", _xfade(0.25))
	for from in ["Locomotion_BlendSpace2D", "Crouch_BlendSpace2D"]:
		sm.add_transition(from, "Death_State", _xfade(0.15))
		sm.add_transition(from, "Death_Blown_Back", _xfade(0.1))

	# Overlays: Movement -> Reload -> Fire -> Kick -> Action (any other one-shot clip)
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("Movement", sm, Vector2(0, 0))
	var chain := [["Reload", "Player_Rifle_Reload"], ["Fire", "Player_Rifle_Fire_Single"],
		["Melee_Kick", "Player_Melee_Kick"], ["Action", "Player_Rifle_Aim_In"]]
	var prev := "Movement"
	var x := 250
	for pair in chain:
		var shot_name: String = pair[0]
		var fade_in := 0.03 if shot_name == "Fire" else 0.1
		bt.add_node(shot_name, _one_shot(fade_in, 0.15), Vector2(x, 0))
		var clip := _anim(pair[1])
		if shot_name == "Action":
			_action_anim = clip
		bt.add_node(shot_name + "_Clip", clip, Vector2(x - 120, 200))
		bt.connect_node(shot_name, 0, prev)
		bt.connect_node(shot_name, 1, shot_name + "_Clip")
		prev = shot_name
		x += 250
	bt.connect_node("output", 0, prev)

	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.tree_root = bt
	tree.active = true
	_movement = tree.get("parameters/Movement/playback")


## Movement input in local space: x strafe (-1..1), y forward (-1..1); running pushes y to 2.
func set_move(dir: Vector2, running := false) -> void:
	if tree == null:
		return
	var v := dir.limit_length(1.0)
	if running and v.y > 0.5 and not _crouched:
		v.y = 2.0
	tree.set("parameters/Movement/Locomotion_BlendSpace2D/blend_position", v)
	tree.set("parameters/Movement/Crouch_BlendSpace2D/blend_position", dir.limit_length(1.0))

func set_crouched(v: bool) -> void:
	if tree == null or v == _crouched or _dead:
		return
	_crouched = v
	_movement.travel("Crouch_BlendSpace2D" if v else "Locomotion_BlendSpace2D")

func fire() -> void:
	_request("Fire")

func reload() -> void:
	_request("Reload")

func kick() -> void:
	_request("Melee_Kick")

## Plays any non-looping clip as an overlay, e.g. "Player_Grenade_Throw", "Player_Hit_Impact_Front".
func play_action(clip: String) -> void:
	if _action_anim == null:
		return
	_action_anim.animation = clip
	_request("Action")

func die(blown_back := false) -> void:
	if tree == null or _dead:
		return
	_dead = true
	for shot in SHOTS:  # overlays would hide the fall
		tree.set("parameters/%s/request" % shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	_movement.travel("Death_Blown_Back" if blown_back else "Death_State")

## Back on your feet (respawn): jumps straight to the standing locomotion state.
func revive() -> void:
	if tree == null:
		return
	_dead = false
	_crouched = false
	_movement.start("Locomotion_BlendSpace2D")

func _request(shot: String) -> void:
	if tree and not _dead:
		tree.set("parameters/%s/request" % shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
