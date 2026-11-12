class_name ZXPlayer
extends Node3D
## Root script of SM_ZX_Player.glb.
## - 10 full-outfit skins (one shared skeleton, swap with set_skin)
## - loadout: any weapon from ZXWeapons, attached to the animated `weapon_anchor` bone
## - AnimationTree: legs from locomotion, upper body from the weapon class, one-shot actions on top
##   and a full-body layer for emotes. Weapon part animations (slide, pump, bolt, mag) play in sync.

signal shot_fired(muzzle: Vector3, direction: Vector3)
signal melee_hit_window(active: bool)
signal skin_changed(index: int)
signal weapon_changed(id: String)

const SKINS := [
	["Operative", "The original. Sensible, tactical, slightly sweaty."],
	["Scavenger", "Hoodie, canvas jacket and a backpack full of mystery cans."],
	["Tactician", "Fade, plate carrier, rolled sleeves. Has a plan. Several."],
	["Veteran", "Flat cap, trench coat, bandolier. Has seen things."],
	["Mechanic", "Overalls, flannel at the waist. Fixes trucks and zombies."],
	["Fisherman", "Oilskin, waders and a trout for emergencies."],
	["Hazmat", "Sealed suit with respirator. Smells of nothing. Finally."],
	["Astronaut", "Took a wrong turn on re-entry. Stayed for the zombies."],
	["Banana", "Peak potassium. Zero stealth."],
	["Chicken", "Why did the survivor cross the road? Exactly."],
]

## Upper-body bones driven by the weapon layer (everything above the pelvis + the gun anchor).
const UPPER_ROOTS := ["spine_01", "weapon_anchor"]

@export var skin := 0: set = set_skin
@export var gear_slots := true: set = set_gear_slots
@export var start_weapon := "assault_rifle"
@export var build_animation_tree := true

var tree: AnimationTree
var weapon: WeaponItem
var weapon_id := ""
var sheath: Node3D
var _skeleton: Skeleton3D
var _movement: AnimationNodeStateMachinePlayback
var _upper_anim: AnimationNodeAnimation
var _action_anim: AnimationNodeAnimation
var _full_anim: AnimationNodeAnimation
var _player: AnimationPlayer
var _crouched := false
var _dead := false
var _aiming := false
var _blocking := false
var _trigger := false
var _drawn := true
var _combo := 0
var _seat := -1          # -1 = on foot, 0 = driver, 1..3 = passenger (expedition_car SEATS order)
var _repair := ""
var _auto_timer: Timer
## Ascia e pistola: l'arma si muove e le mani la seguono (art/zx_player/tool_rig.gd).
var tool_rig: Node
## Velocità dei piedi di ogni clip, misurata quando le clip vengono portate sul personaggio.
var _speeds := {}
## Da fermo alla camminata lenta: sopra questo valore la camminata sfuma nella corsetta.
const SLOW_Y := 0.38
## Le braccia seguono la posa dell'arma; il busto resta libero di muoversi col passo.
const ARM_ROOTS := ["clavicle_l", "clavicle_r", "weapon_anchor"]


func _ready() -> void:
	_skeleton = find_children("*", "Skeleton3D", true, false)[0]
	_player = find_child("AnimationPlayer", true, false)
	_use_mixamo_clips()
	tool_rig = preload("res://art/zx_player/tool_rig.gd").new()
	_skeleton.add_child(tool_rig)
	set_skin(skin)
	if build_animation_tree:
		_build_tree()
	_auto_timer = Timer.new()
	_auto_timer.one_shot = false
	add_child(_auto_timer)
	_auto_timer.timeout.connect(_auto_shot)
	if start_weapon != "":
		equip(start_weapon)


## Le animazioni nuove (tools/mixamo/bake_mixamo.gd) sostituiscono per nome quelle del modello: tutto il resto non cambia.
func _use_mixamo_clips() -> void:
	const PATH := "res://art/zx_player/mixamo_player.res"
	if _player == null or not ResourceLoader.exists(PATH): return
	var own: AnimationLibrary = _player.get_animation_library("")
	if own == null: return
	if own.has_meta("mixamo"):
		_speeds = own.get_meta("speeds", {})
		return
	own.set_meta("mixamo", true)
	var extra: AnimationLibrary = load(PATH)
	_speeds = extra.get_meta("speeds", {})
	own.set_meta("speeds", _speeds)
	for clip in extra.get_animation_list():
		if own.has_animation(clip): own.remove_animation(clip)
		own.add_animation(clip, extra.get_animation(clip))


# ================================================================== skins
func set_skin(i: int) -> void:
	skin = posmod(i, SKINS.size())
	if not is_inside_tree():
		return
	for n in SKINS.size():
		var m := find_child("Skin_" + SKINS[n][0], true, false) as Node3D
		if m:
			m.visible = n == skin
	set_gear_slots(gear_slots)
	# La skin Mechanic nasce senza spalle e senza la parte alta delle braccia.
	var limbs := preload("res://art/limb_patch.gd")
	if SKINS[skin][0] == "Mechanic": limbs.apply(_skeleton, Color("d9d6c8"))
	else: limbs.show_patch(_skeleton, false)
	skin_changed.emit(skin)


func skin_name() -> String:
	return SKINS[skin][0]


func set_gear_slots(v: bool) -> void:
	gear_slots = v
	if not is_inside_tree():
		return
	var op := skin == 0 and v       # the slots are tailored to the Operative outfit
	for n in ["Slot1_Chest_PlateCarrier", "Slot2_Back_SurvivalPack", "Slot3_Thigh_Holster", "Slot4_Head_BallisticCap"]:
		var s := find_child(n, true, false) as Node3D
		if s:
			s.visible = op
	for n in ["Slot4_Head_NVG_Down", "Slot4_Head_NVG_Up"]:
		var s := find_child(n, true, false) as Node3D
		if s:
			s.visible = false


# ================================================================== loadout
func equip(id: String) -> void:
	unequip()
	var d: Dictionary = ZXWeapons.get_def(id)
	if d.is_empty():
		push_warning("ZXPlayer: unknown weapon %s" % id)
		return
	weapon_id = id
	weapon_changed.emit(id)
	if d.scene == "":
		_set_class(d)
		return
	var made: Node3D = (load(d.scene) as PackedScene).instantiate()
	# I modelli delle mani in prima persona sono nello stesso sistema delle armi, ma senza il loro script.
	if not made is WeaponItem: made.set_script(load("res://art/env/scripts/weapon_item.gd"))
	weapon = made as WeaponItem
	if d.has("sheath"):
		sheath = (load(d.sheath) as PackedScene).instantiate() as Node3D
		add_child(sheath)
		WeaponItem.attach_node(sheath, self, d.mount)
		add_child(weapon)
		weapon.attach_to(self, d.mount)        # starts sheathed, draw() pulls it out
		_drawn = false
		_set_class(d)
		draw()
	else:
		add_child(weapon)
		weapon.attach_to(self, "weapon_anchor")
		_drawn = true
		_set_class(d)
	tool_rig.set_weapon(id, weapon)


func unequip() -> void:
	tool_rig.set_weapon("", null)
	_set_trigger_internal(false)
	if weapon:
		weapon.queue_free()
		weapon = null
	if sheath:
		sheath.queue_free()
		sheath = null
	weapon_id = ""


func current_def() -> Dictionary:
	return ZXWeapons.get_def(weapon_id)


func draw() -> void:
	var d := current_def()
	if weapon == null or _drawn or not d.has("draw"):
		return
	weapon.attach_to(self, "weapon_anchor")
	_drawn = true
	_play_action(d.draw)


func sheathe() -> void:
	var d := current_def()
	if weapon == null or not _drawn or not d.has("mount"):
		return
	_drawn = false
	if d.has("sheathe"):
		_play_action(d.sheathe)
		var t := get_tree().create_timer(_clip_len(d.sheathe))
		t.timeout.connect(func(): if weapon and not _drawn: weapon.attach_to(self, d.mount))
	else:
		weapon.attach_to(self, d.mount)


# ================================================================== combat API
func fire() -> void:
	var d := current_def()
	if weapon == null or _dead:
		return
	if d.get("auto", false):
		_set_trigger_internal(true)
		get_tree().create_timer(0.12).timeout.connect(func(): _set_trigger_internal(false))
		return
	if not d.has("fire"):
		return
	_play_action(d.fire)
	weapon.play_part("Wep_Fire")
	tool_rig.shot()
	_emit_shot()


## Hold for automatic weapons (AR / SMG); semi-auto weapons fire once.
func set_trigger(held: bool) -> void:
	var d := current_def()
	if not d.get("auto", false):
		if held:
			fire()
		return
	_set_trigger_internal(held)


func _set_trigger_internal(held: bool) -> void:
	_trigger = held
	var d := current_def()
	if _auto_timer == null:
		return
	if held and d.has("fire_auto"):
		_set_upper(d.fire_auto, 1.0)
		_auto_timer.wait_time = d.get("rate", 0.1)
		_auto_timer.start()
		_auto_shot()
	else:
		_auto_timer.stop()
		_refresh_upper()


func _auto_shot() -> void:
	if weapon:
		weapon.play_part("Wep_Fire")
		tool_rig.shot()
		_emit_shot()


func reload() -> void:
	var d := current_def()
	if weapon and d.has("reload"):
		_play_action(d.reload)
		if tool_rig.kind == "": weapon.play_part("Wep_Reload")   # il gesto lo guida zx_avatar_driver con set_reload


func attack() -> void:
	var d := current_def()
	if not d.has("attacks"):
		return
	if weapon and not _drawn:
		draw()
		return
	var list: Array = d.attacks
	_play_action(list[_combo % list.size()])
	_combo += 1
	tool_rig.swing(false)
	_hit_window(0.18, 0.15)


func heavy_attack() -> void:
	var d := current_def()
	if d.has("heavy"):
		_play_action(d.heavy)
		tool_rig.swing(true)
		_hit_window(0.5, 0.2)


func set_block(on: bool) -> void:
	_blocking = on and current_def().has("block")
	tool_rig.guard = _blocking
	_refresh_upper()


func set_aiming(on: bool) -> void:
	_aiming = on
	_refresh_upper()


func emote(clip := "Player_Emote_Dance") -> void:
	if tree == null:
		return
	if weapon:
		weapon.visible = false
		get_tree().create_timer(_clip_len(clip) if not clip.ends_with("Dance") else 3.2).timeout.connect(
			func(): if weapon: weapon.visible = true)
	_full_anim.use_custom_timeline = false
	_full_anim.animation = clip
	tree.set("parameters/FullBody/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


# ================================================================== movement (same API as SurvivorOperative)
func set_move(dir: Vector2, running := false, metres := 0.0) -> void:
	if tree == null:
		return
	var v := dir.limit_length(1.0)
	# Fino a 2,4 m/s solo la camminata lenta, accelerata dal Pace: mescolata alla corsetta (passo più lungo) i piedi pattinano.
	if not _crouched and absf(v.x) < 0.3 and v.y > SLOW_Y and v.y <= 1.0:
		v.y = SLOW_Y if v.y < 0.6 else remap(v.y, 0.6, 1.0, SLOW_Y, 1.0)
	if running and dir.y > 0.5 and not _crouched:
		v.y = 2.0
	tool_rig.sprint = v.y >= 2.0
	tool_rig.motion.walk = 0.0 if _crouched else clampf(dir.length(), 0.0, 1.0)
	tool_rig.relax_free = not _dead and _seat < 0 and _repair == ""
	tool_rig.enabled = tool_rig.relax_free and (weapon == null or weapon.visible)
	tree.set("parameters/Movement/Locomotion_BlendSpace2D/blend_position", v)
	# Accucciato la clip del passo va a peso pieno appena ci si muove: la velocità la dà il Pace (a 0,45 era metà ferma).
	tree.set("parameters/Movement/Crouch_BlendSpace2D/blend_position", dir.normalized() * clampf(metres / 0.6, 0.0, 1.0) if metres > 0.05 else Vector2.ZERO)
	tree.set("parameters/Pace/scale", _pace(v, metres))


## Le gambe vanno alla velocità vera del corpo: il piede a terra non scivola.
func _pace(v: Vector2, metres: float) -> float:
	if metres < 0.2 or _dead: return 1.0
	var clip_speed: float
	if _crouched: clip_speed = _speed_of("Player_Crouch_Walk_Fwd", 1.2)
	elif absf(v.x) > absf(v.y): clip_speed = _speed_of("Player_Strafe_Left_Rifle", 3.5)
	elif v.y < 0.0: clip_speed = _speed_of("Player_Walk_Bwd_Rifle", 3.5)
	elif v.y <= SLOW_Y: clip_speed = _speed_of("Player_Walk_Slow", 1.5)
	else: clip_speed = lerpf(_speed_of("Player_Walk_Slow", 1.5), _speed_of("Player_Run_Fwd_Rifle", 4.2), clampf((v.y - SLOW_Y) / (1.0 - SLOW_Y), 0.0, 1.0))
	return clampf(metres / maxf(clip_speed, 0.3), 0.7, 1.7)


func _speed_of(clip: String, fallback: float) -> float:
	var s: float = float(_speeds.get(clip, 0.0))
	return s if s > 0.3 else fallback


func set_crouched(v: bool) -> void:
	if tree == null or v == _crouched or _dead:
		return
	_crouched = v
	_movement.travel("Crouch_BlendSpace2D" if v else "Locomotion_BlendSpace2D")


func kick() -> void:
	_play_action("Player_Melee_Kick", true)


## Sword / axe extras (see ZXWeapons: parry, dodge, shove).
func parry() -> void:
	var d := current_def()
	if d.has("parry"):
		_play_action(d.parry)
		_hit_window(0.55, 0.15)


func dodge() -> void:
	var d := current_def()
	if d.has("dodge"):
		_play_action(d.dodge, true)


func shove() -> void:
	var d := current_def()
	if d.has("shove"):
		_play_action(d.shove)
		_hit_window(0.12, 0.12)


# ================================================================== vehicle (04 / RANGER) and repair
## seat: 0 = driver, 1 = front passenger, 2/3 = rear. Plays the climb-in clip, then the seated loop.
## Parent the player to the car at the Seat_* marker of vehicle/ranger_visual.gd (marker = pelvis on the cushion).
func enter_vehicle(seat: int) -> void:
	if tree == null or _dead:
		return
	_seat = seat
	if weapon:
		weapon.visible = false
	_refresh_upper()
	_play_action("Player_Car_Enter_Driver" if seat == 0 else "Player_Car_Enter_Passenger", true)
	_movement.travel("Seated_Driver" if seat == 0 else "Seated_Passenger")


func exit_vehicle() -> void:
	if tree == null or _seat < 0:
		return
	_play_action("Player_Car_Exit_Driver" if _seat == 0 else "Player_Car_Exit_Passenger", true)
	_seat = -1
	_movement.travel("Locomotion_BlendSpace2D")
	if weapon:
		weapon.visible = true
	_refresh_upper()


## -1 = full left, +1 = full right: pass the steering input x (move_left/move_right).
func set_steer(amount: float) -> void:
	if tree:
		tree.set("parameters/Movement/Seated_Driver/blend_position", clampf(amount, -1.0, 1.0))


## kind: "engine" (bent over the bay), "wheel" (kneeling at a hub), "" to stop. install_part() for the 0.8 s snap-in.
func set_repairing(kind: String) -> void:
	if tree == null or _dead or kind == _repair:
		return
	_repair = kind
	if weapon:
		weapon.visible = kind == ""
	_movement.travel({"engine": "Repair_Engine", "wheel": "Repair_Wheel"}.get(kind, "Locomotion_BlendSpace2D"))
	_refresh_upper()


func install_part() -> void:
	_play_action("Player_Install_Part", true)


func play_action(clip: String) -> void:
	_play_action(clip)


## cut > 0: la clip si ferma lì (dissolvenza del OneShot), per le clip Mixamo con una lunga coda ferma.
func play_whole(clip: String, cut := 0.0) -> void:
	_play_action(clip, true)
	if cut > 0.0:
		_full_anim.use_custom_timeline = true
		_full_anim.timeline_length = cut
		_full_anim.stretch_time_scale = false


func clip_seconds(clip: String) -> float:
	return _clip_len(clip)


func die(blown_back := false) -> void:
	if tree == null or _dead:
		return
	_dead = true
	tool_rig.enabled = false
	_set_trigger_internal(false)
	for shot in ["Action", "FullBody"]:
		tree.set("parameters/%s/request" % shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	tree.set("parameters/Upper/blend_amount", 0.0)
	_movement.travel("Death_Blown_Back" if blown_back else "Death_State")


func revive() -> void:
	if tree == null:
		return
	_dead = false
	_crouched = false
	_movement.start("Locomotion_BlendSpace2D")
	_refresh_upper()


# ================================================================== internals
func _set_class(_d: Dictionary) -> void:
	_combo = 0
	_aiming = false
	_blocking = false
	_refresh_upper()


func _refresh_upper() -> void:
	if tree == null:
		return
	var d := current_def()
	var clip := ""
	if _trigger and d.has("fire_auto"):
		clip = d.fire_auto
	elif _blocking and d.has("block"):
		clip = d.block
	elif _aiming and d.has("aim"):
		clip = d.aim
	elif d.has("idle"):
		clip = d.idle
	if weapon and not _drawn:
		clip = "Player_Idle_Unarmed"
	if clip == "Player_Idle_Unarmed":
		clip = ""                      # a mani vuote le braccia ondeggiano con il passo
	if _seat >= 0 or _repair != "":
		clip = ""                      # seated / repairing: the full-body state owns the arms
	_set_upper(clip, 1.0 if clip != "" else 0.0)


func _set_upper(clip: String, amount: float) -> void:
	if tree == null:
		return
	if clip != "" and not _player.has_animation(clip):
		clip = ""
		amount = 0.0                   # senza la posa dell'arma le braccia seguono il passo, mai la T-pose
	if clip != "":
		_upper_anim.animation = clip
	tree.set("parameters/Upper/blend_amount", amount)


func _play_action(clip: String, full_body := false) -> void:
	if tree == null or _dead or not _player.has_animation(clip):
		return                         # gesto senza clip: si salta, il corpo resta nella posa che ha
	if full_body:
		_full_anim.use_custom_timeline = false
		_full_anim.animation = clip
		tree.set("parameters/FullBody/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		return
	_action_anim.animation = clip
	tree.set("parameters/Action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _emit_shot() -> void:
	if weapon:
		shot_fired.emit(weapon.get_muzzle_global(), -weapon.global_basis.z)


func _hit_window(delay: float, length: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		melee_hit_window.emit(true)
		get_tree().create_timer(length).timeout.connect(func(): melee_hit_window.emit(false)))


func _clip_len(clip: String) -> float:
	if _player and _player.has_animation(clip):
		return _player.get_animation(clip).length
	return 0.8


func _anim(n: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = _valid(n)
	return a


## Una clip che non c'è lascia le ossa nella posa di riposo: la T-pose che si vede dall'ombra.
## Qui ogni nome passa da una clip che esiste davvero (prima la stessa, poi le pose di base).
func _valid(clip: String) -> String:
	if _player == null or clip == "" or _player.has_animation(clip):
		return clip
	for fallback in ["Player_Idle_Rifle", "Player_Idle_Unarmed", "Player_Walk_Fwd_Rifle"]:
		if _player.has_animation(fallback):
			push_warning("zx_player: clip mancante %s, uso %s" % [clip, fallback])
			return fallback
	return clip


func _xfade(t := 0.2) -> AnimationNodeStateMachineTransition:
	var tr := AnimationNodeStateMachineTransition.new()
	tr.xfade_time = t
	return tr


func _upper_paths(roots: Array = UPPER_ROOTS) -> Array:
	var out := []
	var skel_path := String(get_path_to(_skeleton))
	for i in _skeleton.get_bone_count():
		var b := i
		var upper := false
		while b != -1:
			if roots.has(_skeleton.get_bone_name(b)):
				upper = true
				break
			b = _skeleton.get_bone_parent(b)
		if upper:
			out.append(NodePath("%s:%s" % [skel_path, _skeleton.get_bone_name(i)]))
	return out


func _filtered_one_shot(paths: Array, fade_in := 0.08, fade_out := 0.15) -> AnimationNodeOneShot:
	var o := AnimationNodeOneShot.new()
	o.fadein_time = fade_in
	o.fadeout_time = fade_out
	o.filter_enabled = true
	for p in paths:
		o.set_filter_path(p, true)
	return o


func _build_tree() -> void:
	if _player == null:
		return
	var loco := AnimationNodeBlendSpace2D.new()
	loco.min_space = Vector2(-1, -1)
	loco.max_space = Vector2(1, 2)
	loco.sync = true
	loco.add_blend_point(_anim("Player_Idle_Rifle"), Vector2(0, 0))
	loco.add_blend_point(_anim("Player_Walk_Slow"), Vector2(0, SLOW_Y))
	loco.add_blend_point(_anim("Player_Run_Fwd_Rifle"), Vector2(0, 1))
	loco.add_blend_point(_anim("Player_Walk_Bwd_Rifle"), Vector2(0, -1))
	loco.add_blend_point(_anim("Player_Strafe_Left_Rifle"), Vector2(-1, 0))
	loco.add_blend_point(_anim("Player_Strafe_Right_Rifle"), Vector2(1, 0))
	loco.add_blend_point(_anim("Player_Run_Fwd_Rifle"), Vector2(0, 2))
	var crouch := AnimationNodeBlendSpace2D.new()
	crouch.min_space = Vector2(-1, -1)
	crouch.max_space = Vector2(1, 1)
	crouch.add_blend_point(_anim("Player_Crouch_Idle_Rifle"), Vector2(0, 0))
	for p in [Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]:
		crouch.add_blend_point(_anim("Player_Crouch_Walk_Fwd"), p)
	var steer := AnimationNodeBlendSpace1D.new()
	steer.min_space = -1.0
	steer.max_space = 1.0
	steer.add_blend_point(_anim("Player_Car_Steer_Left"), -1.0)
	steer.add_blend_point(_anim("Player_Car_Sit_Drive"), 0.0)
	steer.add_blend_point(_anim("Player_Car_Steer_Right"), 1.0)
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("Seated_Driver", steer, Vector2(-100, 400))
	sm.add_node("Seated_Passenger", _anim("Player_Car_Sit_Passenger"), Vector2(100, 400))
	sm.add_node("Repair_Engine", _anim("Player_Repair_Engine"), Vector2(300, 400))
	sm.add_node("Repair_Wheel", _anim("Player_Repair_Wheel"), Vector2(500, 400))
	sm.add_node("Locomotion_BlendSpace2D", loco, Vector2(200, 100))
	sm.add_node("Crouch_BlendSpace2D", crouch, Vector2(200, 260))
	sm.add_node("Death_State", _anim("Player_Death_Collapse_Front"), Vector2(500, 100))
	sm.add_node("Death_Blown_Back", _anim("Player_Death_Blown_Back"), Vector2(500, 260))
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", "Locomotion_BlendSpace2D", start)
	sm.add_transition("Locomotion_BlendSpace2D", "Crouch_BlendSpace2D", _xfade(0.25))
	sm.add_transition("Crouch_BlendSpace2D", "Locomotion_BlendSpace2D", _xfade(0.25))
	for st in ["Seated_Driver", "Seated_Passenger", "Repair_Engine", "Repair_Wheel"]:
		sm.add_transition("Locomotion_BlendSpace2D", st, _xfade(0.3))
		sm.add_transition(st, "Locomotion_BlendSpace2D", _xfade(0.3))
		sm.add_transition("Crouch_BlendSpace2D", st, _xfade(0.3))
		sm.add_transition(st, "Death_State", _xfade(0.15))
	for from in ["Locomotion_BlendSpace2D", "Crouch_BlendSpace2D"]:
		sm.add_transition(from, "Death_State", _xfade(0.15))
		sm.add_transition(from, "Death_Blown_Back", _xfade(0.1))

	var paths := _upper_paths()
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("Movement", sm, Vector2(0, 0))
	bt.add_node("Pace", AnimationNodeTimeScale.new(), Vector2(120, 0))
	bt.connect_node("Pace", 0, "Movement")
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true
	for p in _upper_paths(ARM_ROOTS):
		upper.set_filter_path(p, true)
	_upper_anim = _anim("Player_Idle_Unarmed")
	bt.add_node("Upper", upper, Vector2(250, 0))
	bt.add_node("UpperClip", _upper_anim, Vector2(100, 200))
	bt.connect_node("Upper", 0, "Pace")
	bt.connect_node("Upper", 1, "UpperClip")
	_action_anim = _anim("Player_Rifle_Fire_Single")
	bt.add_node("Action", _filtered_one_shot(paths, 0.05, 0.15), Vector2(500, 0))
	bt.add_node("ActionClip", _action_anim, Vector2(350, 200))
	bt.connect_node("Action", 0, "Upper")
	bt.connect_node("Action", 1, "ActionClip")
	var full := AnimationNodeOneShot.new()
	full.fadein_time = 0.2
	full.fadeout_time = 0.25
	_full_anim = _anim("Player_Emote_Dance")
	bt.add_node("FullBody", full, Vector2(750, 0))
	bt.add_node("FullClip", _full_anim, Vector2(600, 200))
	bt.connect_node("FullBody", 0, "Action")
	bt.connect_node("FullBody", 1, "FullClip")
	bt.connect_node("output", 0, "FullBody")

	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	add_child(tree)
	tree.anim_player = tree.get_path_to(_player)
	tree.tree_root = bt
	tree.active = true
	_movement = tree.get("parameters/Movement/playback")
	_refresh_upper()
