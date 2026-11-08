extends Node3D
# Braccia in prima persona v3 (art/zx_fp/SM_FP_Arms.glb, pacchetto ZOMBIX_Braccia_FPS_v3): una sola coppia di mani per
# tutte le armi e gli oggetti. Controller del pacchetto adattato al progetto: i set di clip si scelgono dal registro
# ZXWeapons (art/zx_player/zx_weapons.gd), i modelli sono quelli di art/env/weapons, i tempi dei colpi quelli di
# MeleeController. Strati: idle <-> sprint, azione (equip / attacco / carica / fuoco / ricarica / lancio) sopra, poi il
# "feel" procedurale: passo agganciato alla distanza, inerzia a molla sullo sguardo, inclinazione, salto e contraccolpo.
# Parata e calcio non hanno clip nel pacchetto: la parata tiene l'arma di traverso (posa dalla clip di ispezione),
# il calcio usa solo la gamba del vecchio rig (art/zx_fp/SM_FP_Melee.glb).

signal released(kind: String, weapon_id: String)

const ARMS := preload("res://art/zx_fp/SM_FP_Arms.glb")
const ToolMotion := preload("res://player/tool_motion.gd")
const ArmIk := preload("res://player/arm_ik.gd")
const GunFx := preload("res://weapons/gun_fx.gd")
const SET := {"axe": "Axe", "knife": "Knife", "pistol": "Pistol"}
const CLASS_SET := {"melee1h": "Melee1H", "axe": "Axe2H", "sword": "Sword", "pistol": "Pistol", "rifle": "Rifle"}
## Armi del registro con un set proprio invece di quello della loro classe.
const VARIANT := {"nail_bat": "Blunt1H", "frying_pan": "Blunt1H", "baguette": "Blunt1H", "rubber_chicken": "Blunt1H", "trout": "Blunt1H",
	"combat_knife": "Knife", "runic_axe": "Axe2H"}
const RELOAD_SECONDS := {"Pistol": 1.6, "Rifle": 2.0}
## Fotogramma d'impatto di ogni clip (30 fps): la finestra attiva del MeleeController viene allineata qui.
const HIT_FRAME := {"Axe_Attack_A": 11, "Axe_Attack_B": 11, "Axe_Heavy": 10,
	"Melee1H_Attack_A": 11, "Melee1H_Attack_B": 11, "Melee1H_Heavy": 10, "Axe2H_Attack_A": 13, "Axe2H_Attack_B": 13, "Axe2H_Heavy": 10,
	"Sword_Attack_A": 11, "Sword_Attack_B": 11, "Sword_Heavy": 10, "Rifle_Fire": 1, "Shotgun_Fire": 1, "Shovel_Attack_A": 8, "Shovel_Attack_B": 8,
	"Shovel_Heavy": 8, "Knife_Attack_A": 8, "Knife_Attack_B": 8, "Knife_Heavy": 7, "Pistol_Fire": 1,
	"Blunt1H_Attack_A": 12, "Blunt1H_Attack_B": 11, "Blunt1H_Heavy": 10}
const RELEASE_FRAME := {"Throw": 10, "Give": 16}
## Testa in mano. Il socket segue il pugno: qui la si raddrizza e la si appende sotto le dita.
const HEAD_GRIP_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
const HEAD_GRIP_OFFSET := Vector3(0, 0.015, 0)
## Dove si sposta la mano quando miri, per avere il mirino al centro.
const ADS_SHIFT := {"Pistol": Vector3(-0.115, 0.055, 0.03), "Rifle": Vector3(-0.13, 0.05, 0.03)}
const SOCKET_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))   # assi Blender -> glTF
## Armi bianche di art/env/weapons (manico +Y, filo -Z): le clip Melee1H, Axe2H, Sword e Blunt1H hanno il manico lungo +X
## del socket e il filo lungo +Y.
const BLADE_BASIS := Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
## Modelli di art/env/weapons la cui origine non sta sull'impugnatura: metri lungo il manico (+Y del modello).
const GRIP_OFFSET := {"runic_axe": 0.42, "spartan_sword": 0.09}
## Quanto arrivano davvero le braccia di questo rig, dalla spalla al polso.
const ARM_REACH := 0.57
const SHOULDER_FORWARD := Vector3(0, -0.02, -0.15)
const KICK_ARMS_SHIFT := Vector3(0.12, -0.07, 0.02)   # dove va l'arma mentre calci
const KICK_LEG_RAISE := Vector3(0, 0.14, -0.05)       # la gamba sale in campo: il piede arriva a metà schermo
const INTER_LIFT :=Vector3(0.04, 0.24, -0.04)    # quanto sale la spalla sinistra mentre raccogli (spazio dello scheletro)
const WALK_STRIDE := 1.6       # metri per ciclo di camminata (2 passi)
const SPRINT_STRIDE := 2.7     # metri per ciclo di corsa (2 passi) = una clip *_Sprint
const BLADE_LENGTH := 0.62     # dall'impugnatura al filo, per il raggio del colpo
const GUARD_TIME := 1.25       # secondo della clip *_Inspect con l'arma di traverso davanti al petto
const INTER_ITEMS := {
	"chiave": ["res://art/zx_rocca/props/SM_Item_Chiave.glb", "Item", 0.45, 0.0],
	"carne": ["res://art/zx_rocca/props/SM_Item_Carne.glb", "Item", 0.5, PI / 2],
}

var player: CharacterBody3D
var rig: Node3D
var skeleton: Skeleton3D
var library: AnimationPlayer
var socket: BoneAttachment3D
var item: Node3D
var weapon := "-"
var clock := 0.0
var set_name := "Axe"
var _gun := false
var _blade_axis := Vector3(0, 0, 1)     # asse del manico nel socket
var _use_t := -1.0
var _one := ""
var _one_t := -1.0
var _one_fired := false
var _inspect_t := -1.0
var _idle_for := 0.0
var _fidget_t := -1.0
var _tracks := {}
var _rest := {}
var _sprint_w := 0.0
var _action := ""
var _action_t := 0.0
var _action_w := 0.0
var _guard_w := 0.0
var _follow := false
var _last_pose := {}
var _xfade := {}
var _xfade_w := 0.0
var _equip_t := -1.0
var _last_look := Vector2.ZERO
var _was_floor := true
var _kick := 0.0
var _kick_w := 0.0
var _ads := 0.0
var _slide: Node3D
var _slide_base := Vector3.ZERO
var _slide_back := 0.0
var _swing_env := 0.0
var _wind_env := 0.0
var _bite_p := 0.0
var _bite_v := 0.0
var _stride := 0.0
var _run_phase := 0.0
var _walk_w := 0.0
var _sway_p := Vector2.ZERO
var _sway_v := Vector2.ZERO
var _tilt := 0.0
var _air := 0.0
var _land_p := 0.0
var _land_v := 0.0
var _last_vy := 0.0
var _inter := ""
var _inter_t := 0.0
var _inter_w := 0.0
var _left_bones := {}
var _held: Node3D
var _hand_socket: BoneAttachment3D
var _leg_rig: Node3D
var _leg_player: AnimationPlayer
# Mani vuote: niente arma né posa d'impugnatura. Le braccia stanno basse e pompano col passo, agganciate alla distanza.
var _empty := false
var _empty_show := 0.0
# Ascia e pistola: l'arma si muove e le mani la seguono.
var _motion: RefCounted
var _tip_y := 0.0
var _trail_last: Array = []
var _hit_mark: Control
var _tool_w := 1.0
var _mag: Node3D
var _mag_base := Vector3.ZERO
# Caricatore o cartuccia nella mano sinistra durante la ricarica: blocchetti originali, l'arma importata non li ha.
var _carry_mag: MeshInstance3D
var _carry_shell: MeshInstance3D


func build(owner_player: CharacterBody3D) -> void:
	player = owner_player
	rig = ARMS.instantiate()
	add_child(rig)
	skeleton = rig.find_children("*", "Skeleton3D", true, false)[0]
	library = rig.find_children("*", "AnimationPlayer", true, false)[0]
	library.active = false                       # campionato a mano
	for i in skeleton.get_bone_count():
		_rest[i] = [skeleton.get_bone_rest(i).basis.get_rotation_quaternion(), skeleton.get_bone_rest(i).origin]
		if skeleton.get_bone_name(i).ends_with("_l"):
			_left_bones[i] = true
	for clip in library.get_animation_list():
		var anim := library.get_animation(clip)
		var rows := []
		for t in anim.get_track_count():
			var bone := skeleton.find_bone(String(anim.track_get_path(t).get_concatenated_subnames()))
			if bone < 0: continue
			match anim.track_get_type(t):
				Animation.TYPE_ROTATION_3D: rows.append([bone, 0, t])
				Animation.TYPE_POSITION_3D: rows.append([bone, 1, t])
		_tracks[String(clip)] = rows
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).extra_cull_margin = 2
		for s in (mi as MeshInstance3D).mesh.get_surface_count():
			var m := (mi as MeshInstance3D).mesh.surface_get_material(s) as StandardMaterial3D
			if m: m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	socket = BoneAttachment3D.new()
	socket.bone_name = "weapon_r"
	skeleton.add_child(socket)
	_hand_socket = BoneAttachment3D.new()
	_hand_socket.bone_name = "hand_l"
	skeleton.add_child(_hand_socket)
	_carry_mag = _carry_piece(BoxMesh.new(), Color("2b2d2f"), Vector3(0.026, 0.10, 0.045))
	_carry_shell = _carry_piece(CylinderMesh.new(), Color("a3302a"), Vector3(0.022, 0.06, 0.022))
	if player.local_control: _build_hit_mark()
	player.melee.impact.connect(func(_t, charged):
		_show_hit(charged)
		_kick = 1.0 if charged else 0.6
		if _motion: _motion.kick(2.2 if charged else 1.4, 3.0 if charged else 1.8)
		elif not _gun: _bite_v += 5.2 if charged else 3.4)
	player.melee.shot.connect(_gun_fired)
	_build_leg()


## La gamba del calcio viene dal vecchio rig: tutto il resto di quel modello resta nascosto.
func _build_leg() -> void:
	_leg_rig = load("res://art/zx_fp/SM_FP_Melee.glb").instantiate()
	add_child(_leg_rig)
	_leg_player = _leg_rig.find_children("*", "AnimationPlayer", true, false)[0]
	for mi in _leg_rig.find_children("*", "MeshInstance3D", true, false):
		mi.visible = String(mi.name).begins_with("FP_Leg")
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).extra_cull_margin = 2
	_leg_rig.visible = false


static func handles(id: String) -> bool:
	if id == "bow": return false
	if id == "" or SET.has(id) or ItemInfo.is_item(id): return true
	return ZXWeapons.DEFS.has(id) and ZXWeapons.DEFS[id].get("class", "") != "consumable"


## Quale set di clip e quale modello: armi storiche (ascia, pala, coltello, pistola), armi ZX, oggetti.
func _set_weapon(id: String) -> void:
	weapon = id
	if item: item.queue_free()
	item = null
	set_name = "Axe"
	_gun = false
	_blade_axis = Vector3(0, 0, 1)
	_empty = id == ""
	if _empty: set_name = "Melee1H"
	match id:
		"": pass
		"axe":
			set_name = SET[id]
			item = load("res://art/zx_fp/SM_FP_%s.glb" % SET[id]).instantiate()
			item.transform = Transform3D(SOCKET_BASIS, Vector3.ZERO)
			_blade_axis = Vector3(0, 1, 0)
		"knife":
			set_name = "Knife"
			item = load("res://art/zx_fp/SM_FP_CombatKnife.glb").instantiate()
			# Lama +Y, filo su Z (glTF) -> lama lungo l'impugnatura del rig, filo in avanti.
			var r := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
			item.transform = Transform3D(r * SOCKET_BASIS, Vector3(0, 0.01, 0))
		"pistol":
			set_name = "Pistol"
			_gun = true
			# Lo stesso modello che vedono gli altri: canna -Z, alto +Y, lo mette in mano ToolMotion.
			item = load(str(ZXWeapons.get_def("pistol").scene)).instantiate()
		_:
			if ItemInfo.is_item(id):
				set_name = "Item_" + ItemInfo.ITEMS[id].model
				item = ItemInfo.model(id)
				item.transform = Transform3D(SOCKET_BASIS, Vector3.ZERO)
				# La testa pende dal pugno, tenuta per i capelli: dritta e con la faccia verso chi guarda.
				if ItemInfo.is_head(id):
					item.transform = Transform3D(HEAD_GRIP_BASIS, HEAD_GRIP_OFFSET)
			else:
				var def: Dictionary = ZXWeapons.DEFS.get(id, {})
				var cls: String = def.get("class", "melee1h")
				set_name = VARIANT.get(id, CLASS_SET.get(cls, "Melee1H"))
				_gun = cls == "pistol" or cls == "rifle"
				if def.get("scene", "") != "":
					item = load(def.scene).instantiate()
					# Armi da fuoco: canna -Z e alto +Y, come i modelli del rig. Armi bianche: vedi BLADE_BASIS.
					var lay: Basis = SOCKET_BASIS if _gun else BLADE_BASIS
					if not _gun: _blade_axis = Vector3(1, 0, 0)
					item.transform = Transform3D(lay, lay * Vector3(0, float(GRIP_OFFSET.get(id, 0.0)), 0))
	if item:
		socket.add_child(item)
		for mi in item.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(mi as MeshInstance3D).extra_cull_margin = 2
	_slide = null
	_mag = null
	if item and _gun:
		_slide = item.find_child("*Slide*", true, false) as Node3D
		if _slide: _slide_base = _slide.position
		_mag = item.find_child("*_Mag*", true, false) as Node3D
		if not _mag: _mag = item.find_child("Magazine*", true, false) as Node3D
		if _mag: _mag_base = _mag.position
	_motion = null
	for side in ["r", "l"]:
		var shoulder := skeleton.find_bone("upperarm_" + side)
		skeleton.set_bone_pose_position(shoulder, _rest[shoulder][1])
	if ToolMotion.handles(id):
		_motion = ToolMotion.new()
		_motion.setup(id)
		_motion.place_item(item)
		var box: AABB = item.transform * ToolMotion.model_box(item)
		_tip_y = box.end.y
		_trail_last = []
		_tool_w = 1.0
		if not _gun: _blade_axis = Vector3(0, 1, 0)
	_equip_t = 0.0
	_use_t = -1.0
	_inspect_t = -1.0
	_fidget_t = -1.0
	_one_t = -1.0


## Punto della lama nel mondo: MeleeController ci traccia il colpo.
func blade_point() -> Vector3:
	var g := socket.global_transform
	return g.origin + (g.basis * _blade_axis).normalized() * BLADE_LENGTH


func blade_ready() -> bool:
	return visible and is_inside_tree() and not _gun and not _empty


## Mano sinistra: clip Interact_* sopra l'arma (raccogli, chiave nel lucchetto, carne sull'altare).
func play_interact(clip: String, held := "") -> void:
	if not library.has_animation(clip): return
	_inter = clip
	_inter_t = 0.0
	if _held:
		_held.queue_free()
		_held = null
	if not INTER_ITEMS.has(held): return
	var cfg: Array = INTER_ITEMS[held]
	var scene: Node3D = load(cfg[0]).instantiate()
	for a in scene.find_children("*", "AnimationPlayer", true, false):
		(a as AnimationPlayer).active = false
	var part: Node3D = scene.find_child(cfg[1], true, false)
	if part == null:
		scene.queue_free()
		return
	part.get_parent().remove_child(part)
	scene.queue_free()                       # tiene solo l'oggetto, non l'alone a terra
	_held = Node3D.new()
	_held.add_child(part)
	part.transform = Transform3D.IDENTITY
	_held.transform = Transform3D(SOCKET_BASIS * Basis(Vector3.RIGHT, cfg[3]), Vector3(0.0, 0.07, 0.03)).scaled_local(Vector3.ONE * float(cfg[2]))
	_hand_socket.add_child(_held)


func interacting() -> bool:
	return _inter != ""


func inspect() -> void:
	if not _empty and library.has_animation(set_name + "_Inspect") and not player.melee.attacking and not player.melee.charging and player.reload_left <= 0.0:
		_inspect_t = 0.0


func inspecting() -> bool:
	return _inspect_t >= 0.0


func use_item() -> bool:
	if set_name.begins_with("Item_") and library.has_animation(set_name + "_Use") and _use_t < 0.0 and _one_t < 0.0:
		_use_t = 0.0
		return true
	return false


func using_item() -> bool:
	return _use_t >= 0.0


## [Q] lancia quello che hai in mano. False se il set non ha la clip o stai già facendo altro.
func throw_held() -> bool:
	return _start_one("Throw", set_name + "_Throw")


## Porge la testa allo sceriffo; "released" con kind "Give" = momento della vendita.
func give_held() -> bool:
	return _start_one("Give", set_name + "_Give")


func throwing() -> bool:
	return _one_t >= 0.0


func _start_one(kind: String, clip: String) -> bool:
	if _one_t >= 0.0 or not library.has_animation(clip) or player.melee.attacking or player.reload_left > 0.0:
		return false
	_one = kind
	_one_t = 0.0
	_one_fired = false
	_use_t = -1.0
	_inspect_t = -1.0
	_fidget_t = -1.0
	_equip_t = -1.0
	return true


func tick(delta: float, equipped: String) -> void:
	clock += delta
	if weapon != equipped: _set_weapon(equipped)
	if _empty:
		_tick_empty(delta)
		return
	var melee = player.melee
	var kicking: bool = melee.attacking and melee.attack_clip == "Kick"
	if melee.attacking or melee.charging or player.sprinting:
		_inspect_t = -1.0           # un colpo o la corsa interrompono l'ispezione
	var still: bool = Vector2(player.velocity.x, player.velocity.z).length() < 0.3 and not melee.attacking and not melee.charging
	_idle_for = _idle_for + delta if still and _inspect_t < 0.0 else 0.0
	if _idle_for > 6.0 and _fidget_t < 0.0 and library.has_animation(set_name + "_Fidget"):
		_fidget_t = 0.0
		_idle_for = -randf_range(2.0, 6.0)
	# Dopo un po' fermo si guarda l'arma, poi riprende la guardia. Mai con un'arma da fuoco puntata.
	if _idle_for > 9.0 and _fidget_t < 0.0 and _inspect_t < 0.0 and not library.has_animation(set_name + "_Fidget") and library.has_animation(set_name + "_Inspect") and not melee.ads:
		_inspect_t = 0.0
		_idle_for = -randf_range(6.0, 14.0)
	if not still: _fidget_t = -1.0
	# ---- quale clip d'azione, e in che punto
	var act := ""
	var t := 0.0
	if _one_t >= 0.0:
		act = set_name + "_" + _one
		_one_t += delta
		t = _one_t
		if not _one_fired and _one_t >= RELEASE_FRAME[_one] / 30.0:
			_one_fired = true
			if item: item.visible = false            # l'oggetto ora vola (o è in mano allo sceriffo)
			released.emit(_one, weapon)
		if _one_t >= _len(act):
			_one_t = -1.0
			if item: item.visible = true             # ne avevi più di uno: ricompare il prossimo
	elif _motion:
		_equip_t = -1.0
		_follow = false
		if _inspect_t >= 0.0:
			_inspect_t += delta
			if _inspect_t >= ToolMotion.INSPECT_SECONDS: _inspect_t = -1.0
		_fidget_t = -1.0
	elif _gun and player.reload_left > 0:
		act = set_name + "_Reload"
		var rs: float = maxf(player.reload_total, 0.1)
		t = clampf((rs - player.reload_left) / rs, 0.0, 1.0) * _len(act)
	elif _use_t >= 0.0:
		act = set_name + "_Use"
		_use_t += delta
		t = _use_t
		if _use_t >= _len(act): _use_t = -1.0
	elif melee.charging and not _gun:
		act = set_name + "_Charge"
		t = melee.charge_fraction() * _len(act)
	elif melee.attacking and not kicking:
		if _gun:
			act = "Shotgun_Fire" if weapon == "pump_shotgun" else set_name + "_Fire"
		elif melee.charged_attack:
			act = set_name + "_Heavy"
		else:
			act = set_name + ("_Attack_A" if melee.swing_side < 0 else "_Attack_B")
		t = _warp(act, melee.attack_time, melee.active_windup, melee.active_seconds, melee.active_recovery)
		_equip_t = -1.0
		_follow = true
	elif _follow and _action != "" and _action_t < _len(_action):
		# accompagnamento: il gioco ha già chiuso il colpo, la clip finisce a velocità reale e torna alla posa
		act = _action
		t = _action_t + delta
	elif _inspect_t >= 0.0:
		act = set_name + "_Inspect"
		_inspect_t += delta
		t = _inspect_t
		if _inspect_t >= _len(act): _inspect_t = -1.0
	elif _fidget_t >= 0.0:
		act = set_name + "_Fidget"
		_fidget_t += delta
		t = _fidget_t
		if _fidget_t >= _len(act): _fidget_t = -1.0
	elif _equip_t >= 0.0:
		act = set_name + "_Equip"
		_equip_t += delta
		t = _equip_t
		if _equip_t >= _len(act): _equip_t = -1.0
	if act == "" or not act.begins_with(set_name) and act != "Shotgun_Fire": _follow = false
	if act != "" and act != _action and _action_w > 0.05 and not _last_pose.is_empty():
		_xfade = _last_pose.duplicate(true)      # combo: si parte da dove era la mano, niente salti
		_xfade_w = 1.0
	if act != "":
		_action = act
		_action_t = t
		_action_w = minf(1.0, _action_w + delta / 0.06)
	else:
		_action_w = maxf(0.0, _action_w - delta / 0.14)
	# ---- strati
	var running: bool = player.sprinting and _action_w < 0.5
	_sprint_w = move_toward(_sprint_w, 1.0 if running else 0.0, delta * (4.0 if running else 6.0))
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var grounded: bool = player.is_on_floor()
	if grounded:
		_stride += speed * delta / WALK_STRIDE
		_run_phase += speed * delta / SPRINT_STRIDE
	var pose := _pose(ToolMotion.finger_clip(weapon), 0.0) if _motion else _pose(set_name + "_Idle", fposmod(clock, _len(set_name + "_Idle")))
	if _sprint_w > 0.001 and not _motion:
		_mix(pose, _pose(set_name + "_Sprint", fposmod(_run_phase, 1.0) * _len(set_name + "_Sprint")), smoothstep(0.0, 1.0, _sprint_w))
	if _action_w > 0.001 and _action != "":
		_mix(pose, _pose(_action, _action_t), smoothstep(0.0, 1.0, _action_w))
	_guard_w = move_toward(_guard_w, 1.0 if melee.blocking else 0.0, delta / 0.1)
	if _guard_w > 0.001 and not _motion and library.has_animation(set_name + "_Inspect"):
		_mix(pose, _pose(set_name + "_Inspect", GUARD_TIME), smoothstep(0.0, 1.0, _guard_w))
	if _xfade_w > 0.0:
		_mix(pose, _xfade, smoothstep(0.0, 1.0, _xfade_w))
		_xfade_w = maxf(0.0, _xfade_w - delta / 0.09)
	if _inter != "":
		_inter_t += delta
		var il := _len(_inter)
		_inter_w = clampf(minf(_inter_t / 0.12, (il - _inter_t) / 0.16), 0.0, 1.0)
		var ip := _pose(_inter, minf(_inter_t, il))
		for b in ip.keys():
			if not _left_bones.has(b): ip.erase(b)
		_mix(pose, ip, smoothstep(0.0, 1.0, _inter_w))
		if _inter_t >= il:
			_inter = ""
			if _held:
				_held.queue_free()
				_held = null
	_last_pose = pose
	for b in pose:
		skeleton.set_bone_pose_rotation(b, pose[b][0])
		if pose[b][1] != null: skeleton.set_bone_pose_position(b, pose[b][1])
	if _motion: _tool_pose(delta, pose, kicking)
	_lift_left()
	_leg(kicking)
	_feel(delta, speed, grounded)
	# Calcio: l'arma si scansa verso destra e in basso, così la gamba non resta nascosta dietro.
	_kick_w = move_toward(_kick_w, 1.0 if kicking else 0.0, delta / 0.08)
	var kw := smoothstep(0.0, 1.0, _kick_w)
	rig.position += KICK_ARMS_SHIFT * kw
	rig.rotation.z -= 0.12 * kw


## L'arma va dove dice ToolMotion e le braccia la raggiungono. Lancio e oggetti della sinistra riprendono le loro clip.
func _tool_pose(delta: float, pose: Dictionary, kicking: bool) -> void:
	var melee = player.melee
	var row := []
	if melee.attacking and not kicking and not _gun:
		var which: String = str(ToolMotion.SWING_ROW.get(melee.attack_clip, "H" if melee.charged_attack else ToolMotion.VARIANT_ROW[posmod(melee.attack_variant, 3)]))
		row = [which, melee.attack_time, melee.active_windup, melee.active_seconds, melee.active_recovery]
	var reload := -1.0
	if _gun and player.reload_left > 0.0:
		var rs: float = maxf(player.reload_total, 0.1)
		reload = clampf((rs - player.reload_left) / rs, 0.0, 1.0)
	_motion.tick(delta, row, melee.charge_fraction() if melee.charging and not _gun else 0.0, melee.blocking, _sprint_w > 0.5, melee.ads, reload, _inspect_t)
	_tool_w = move_toward(_tool_w, 0.0 if _one_t >= 0.0 else 1.0, delta / 0.1)
	if _mag:
		_mag.position = _mag_base + Vector3(0, -0.3, 0) * _motion.mag_out
		_mag.visible = _motion.mag_out < 0.98
	_carry_mag.visible = _motion.carry == "mag"
	_carry_shell.visible = _motion.carry == "shell"
	if _tool_w <= 0.0: return
	# Le spalle sono fuori dall'inquadratura: portarle avanti allunga il braccio senza che si veda, e la mano arriva sulla canna.
	for side in ["r", "l"]:
		var shoulder := skeleton.find_bone("upperarm_" + side)
		skeleton.set_bone_pose_position(shoulder, (_rest[shoulder][1] as Vector3).lerp((_rest[shoulder][1] as Vector3) + SHOULDER_FORWARD, _tool_w))
	skeleton.force_update_all_bone_transforms()
	var w: Transform3D = _reachable(_motion.frame())
	_swing_trail(w, not row.is_empty() and melee.attack_time >= melee.active_windup * 0.6 and melee.attack_time <= melee.active_windup + melee.active_seconds + 0.12)
	var slot := skeleton.find_bone("weapon_r")
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(slot))
	var inside := parent.affine_inverse() * w
	_blend_bone(slot, pose, inside.basis.get_rotation_quaternion(), inside.origin)
	skeleton.force_update_all_bone_transforms()
	_tool_arm("r", w, _motion.grip("r"), Vector3.ZERO, Vector3(0.5, -1.0, 0.2), pose)
	var left: Dictionary = _motion.grip("l")
	if _inter == "" and not left.is_empty(): _tool_arm("l", w, left, _motion.left_shift, Vector3(-0.5, -1.0, 0.2), pose)
	skeleton.force_update_all_bone_transforms()


## Scia della lama: si vede l'arco del colpo, poi sfuma.
func _swing_trail(w: Transform3D, on: bool) -> void:
	if not on or _tip_y < 0.2:
		_trail_last = []
		return
	var to_world: Transform3D = skeleton.global_transform * w
	var tip: Vector3 = to_world * Vector3(0, _tip_y, 0)
	var mid: Vector3 = to_world * Vector3(0, _tip_y * 0.55, 0)
	if _trail_last.size() == 2 and (_trail_last[0] as Vector3).distance_to(tip) > 0.02:
		GunFx.trail(player.get_parent(), _trail_last[0], _trail_last[1], tip, mid, Color(1, 0.96, 0.85) if not player.melee.charged_attack else Color(1, 0.8, 0.55))
	_trail_last = [tip, mid]


## Conferma del colpo: quattro trattini attorno al mirino, rossi se è pesante.
func _build_hit_mark() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_hit_mark = Control.new()
	_hit_mark.set_anchors_preset(Control.PRESET_CENTER)
	_hit_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_mark.modulate.a = 0.0
	layer.add_child(_hit_mark)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			var dash := ColorRect.new()
			dash.size = Vector2(9, 2)
			dash.pivot_offset = Vector2(4.5, 1)
			dash.position = Vector2(x * 11.0 - 4.5, y * 11.0 - 1.0)
			dash.rotation = x * y * PI * 0.25
			dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hit_mark.add_child(dash)


func _show_hit(heavy: bool) -> void:
	if _hit_mark == null: return
	_hit_mark.modulate = Color(1, 0.3, 0.2, 1) if heavy else Color(1, 1, 1, 1)
	_hit_mark.scale = Vector2.ONE * (1.5 if heavy else 1.2)
	var fade := _hit_mark.create_tween().set_parallel()
	fade.tween_property(_hit_mark, "scale", Vector2.ONE, 0.1)
	fade.tween_property(_hit_mark, "modulate:a", 0.0, 0.22)


## Il braccio destro è lungo quello che è: se la posa chiede di più, l'arma si ferma dove arriva la mano.
func _reachable(w: Transform3D) -> Transform3D:
	var shoulder: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("upperarm_r")).origin
	var fist: Array = ToolMotion.fist_for(w, _motion.grip("r"), "r", shoulder, Vector3.UP, 0.078, 0.029, ARM_REACH, Vector3.ZERO, _motion.edge_w)
	var gap: Vector3 = (fist[0] as Vector3) - shoulder
	if gap.length() > ARM_REACH: w.origin -= gap.normalized() * (gap.length() - ARM_REACH)
	return w


func _tool_arm(side: String, w: Transform3D, grip: Dictionary, shift: Vector3, pole: Vector3, pose: Dictionary) -> void:
	var up := skeleton.find_bone("upperarm_" + side)
	var lo := skeleton.find_bone("lowerarm_" + side)
	var ha := skeleton.find_bone("hand_" + side)
	var fist: Array = ToolMotion.fist_for(w, grip, side, skeleton.get_bone_global_pose(up).origin, Vector3.UP, 0.078, 0.029, ARM_REACH, shift, _motion.edge_w)
	var z: Vector3 = fist[2] * (1.0 if side == "r" else -1.0)
	var hand := Basis((fist[1] as Vector3).cross(z), fist[1], z)
	var rots: Array = ArmIk.solve(skeleton, up, lo, ha, fist[0], hand, pole, Vector3.UP)
	_blend_bone(up, pose, rots[0], null)
	_blend_bone(lo, pose, rots[1], null)
	_blend_bone(ha, pose, rots[2], null)


func _blend_bone(bone: int, pose: Dictionary, rot: Quaternion, at: Variant) -> void:
	var was: Quaternion = pose[bone][0] if pose.has(bone) else _rest[bone][0]
	skeleton.set_bone_pose_rotation(bone, was.slerp(rot, _tool_w))
	if at != null:
		var from: Vector3 = pose[bone][1] if pose.has(bone) and pose[bone][1] != null else _rest[bone][1]
		skeleton.set_bone_pose_position(bone, from.lerp(at, _tool_w))


## Mani vuote: il ciclo di corsa fa pompare le braccia col passo vero (distanza percorsa), lento e basso camminando.
## Da fermi le mani scendono fuori campo con un respiro appena visibile: nessun arto rigido davanti alla camera.
func _tick_empty(delta: float) -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var grounded: bool = player.is_on_floor()
	if grounded:
		_run_phase += speed * delta / (SPRINT_STRIDE if player.sprinting else WALK_STRIDE * 0.9)
	var want := 0.0
	if _inter != "": want = 1.0
	elif player.sprinting and speed > 1.0: want = 1.0
	elif speed > 0.5 and grounded: want = 0.42
	_empty_show = move_toward(_empty_show, want, delta * (3.0 if want > _empty_show else 1.6))
	var run := _pose(set_name + "_Sprint", fposmod(_run_phase, 1.0) * _len(set_name + "_Sprint"))
	var pose := _pose(set_name + "_Idle", fposmod(clock, _len(set_name + "_Idle")))
	_mix(pose, run, 0.92)
	if _inter != "":
		_inter_t += delta
		var il := _len(_inter)
		_inter_w = clampf(minf(_inter_t / 0.12, (il - _inter_t) / 0.16), 0.0, 1.0)
		var ip := _pose(_inter, minf(_inter_t, il))
		_mix(pose, ip, smoothstep(0.0, 1.0, _inter_w))
		if _inter_t >= il: _inter = ""
	for b in pose:
		skeleton.set_bone_pose_rotation(b, pose[b][0])
		if pose[b][1] != null: skeleton.set_bone_pose_position(b, pose[b][1])
	_lift_left()
	_leg_rig.visible = false
	_feel(delta, speed, grounded)
	var s := smoothstep(0.0, 1.0, _empty_show)
	rig.position += Vector3(0.05 * (1.0 - s), lerpf(-0.42, 0.0, s) + sin(clock * 1.9) * 0.004, 0.03 * (1.0 - s))
	rig.rotation += Vector3(lerpf(-0.45, 0.0, s), 0, 0)


## Le clip Interact_* portano la mano verso terra, sotto l'inquadratura: durante il gesto la spalla sinistra sale
## e la mano resta in campo, davanti in basso.
func _lift_left() -> void:
	var shoulder := skeleton.find_bone("upperarm_l")
	# Con ascia e pistola _tool_pose ha appena rimesso la spalla; altrimenti si riparte dal riposo (niente accumulo).
	var base: Vector3 = skeleton.get_bone_pose_position(shoulder) if _motion else _rest[shoulder][1]
	var w := smoothstep(0.0, 1.0, _inter_w) if _inter != "" else 0.0
	if w <= 0.0 and _motion: return
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(shoulder)).basis
	skeleton.set_bone_pose_position(shoulder, base + parent.inverse() * (INTER_LIFT * w))
	skeleton.force_update_all_bone_transforms()


func _leg(kicking: bool) -> void:
	_leg_rig.visible = kicking
	if not kicking: return
	_leg_rig.position = KICK_LEG_RAISE
	if _leg_player.current_animation != "Kick": _leg_player.play("Kick")
	_leg_player.seek(player.melee.attack_time, true)
	_leg_player.pause()


func _feel(delta: float, speed: float, grounded: bool) -> void:
	var melee = player.melee
	var target_walk := clampf(speed / 3.5, 0.0, 1.0) * (1.0 - _sprint_w) if grounded else 0.0
	_walk_w = lerpf(_walk_w, target_walk, 1.0 - exp(-delta * 8.0))
	var calm := 1.0 - _action_w * 0.75 - (0.6 if _inter != "" else 0.0)
	var ph := _stride * TAU
	# figura a 8: destra-sinistra una volta per ciclo, giù a ogni appoggio del piede
	var bob := Vector3(sin(ph) * 0.010, -(1.0 - cos(ph * 2.0)) * 0.5 * 0.013, 0.0) * _walk_w * calm
	var bob_rot := Vector3(sin(ph * 2.0 + 0.6) * 0.012, sin(ph) * 0.010, -sin(ph) * 0.018) * _walk_w * calm
	# inerzia dello sguardo: molla, l'arma resta un attimo indietro e poi recupera (niente scatti)
	var look := Vector2(player.rig.yaw, player.rig.pitch)
	var dlook := (look - _last_look) / maxf(delta, 0.001)
	_last_look = look
	var goal := Vector2(clampf(dlook.x * 0.0055, -0.045, 0.045), clampf(-dlook.y * 0.0055, -0.04, 0.04))
	# Molle rigide integrate a passo fisso: con un frame lungo (caricamento, scatto) Euler esplodeva in inf/NaN,
	# il NaN restava per sempre e il motore stampava migliaia di errori instance_set_transform al minuto.
	var dt := minf(delta, 1.0 / 60.0)
	_sway_v += ((goal - _sway_p) * 160.0 - _sway_v * 22.0) * dt
	_sway_p += _sway_v * dt
	if not (_sway_p.is_finite() and _sway_v.is_finite()): _sway_p = Vector2.ZERO; _sway_v = Vector2.ZERO
	var local_v: Vector3 = Basis(Vector3.UP, player.rig.yaw).inverse() * player.velocity
	_tilt = lerpf(_tilt, clampf(-local_v.x / 4.0, -1.0, 1.0), 1.0 - exp(-delta * 6.0))
	_air = move_toward(_air, 0.0 if grounded else 1.0, delta * 5.0)
	if grounded and not _was_floor:
		_land_v -= clampf(-_last_vy, 2.0, 12.0) * 0.06
	_was_floor = grounded
	_last_vy = player.velocity.y
	_land_v += (-_land_p * 220.0 - _land_v * 18.0) * dt
	_land_p += _land_v * dt
	if not (is_finite(_land_p) and is_finite(_land_v)): _land_p = 0.0; _land_v = 0.0
	_kick = move_toward(_kick, 0.0, delta * 6.0)
	var tremble := Vector3.ZERO
	if melee.charging and melee.charge_fraction() >= 1.0:
		tremble = Vector3(sin(clock * 47.0), cos(clock * 53.0), 0) * 0.0025
	rig.position = bob + Vector3(_sway_p.x, _sway_p.y, 0) + Vector3(0, _land_p + 0.012 * _air, 0) + tremble + Vector3(0, 0, 0.025 * _kick) \
		+ Vector3(-0.008 * _tilt, 0, 0)
	if _inter != "":
		rig.position += Vector3(0.0, -0.025, 0.01) * _inter_w     # l'arma si abbassa un poco mentre la sinistra lavora
	rig.rotation = bob_rot + Vector3(-0.06 * _kick + _sway_p.y * 1.6 - 0.04 * _air + _land_p * 0.8, _sway_p.x * 2.2, -_sway_p.x * 1.4 + 0.035 * _tilt)
	_weight(delta)


## Il peso dell'arma: caricando la si porta indietro e in alto, il corpo accompagna il fendente, la vista segue di poco.
## Con le armi da fuoco: mira al centro con il tasto destro, rinculo e carrello che torna indietro.
func _weight(delta: float) -> void:
	var melee = player.melee
	var charge: float = melee.charge_fraction() if melee.charging and not _gun and not _motion else 0.0
	rig.position += Vector3(0.012, 0.03, 0.05) * charge
	rig.rotation += Vector3(0.14, -0.05, 0.05) * charge
	var swinging: bool = melee.attacking and not _gun and melee.attack_clip != "Kick"
	var goal := 0.0
	var wind := 0.0
	if swinging:
		var hit_at: float = melee.active_windup + melee.active_seconds * 0.5
		var through: float = melee.attack_time / maxf(hit_at, 0.01)
		goal = sin(clampf(through, 0.0, 1.0) * PI * 0.5) * exp(-maxf(0.0, through - 1.0) * 2.6) * (1.4 if melee.charged_attack else 1.0)
		# Si prende slancio prima: le mani tornano indietro e poi il corpo entra nel colpo.
		wind = sin(clampf(through / 0.65, 0.0, 1.0) * PI) * (1.3 if melee.charged_attack else 1.0)
	_swing_env = lerpf(_swing_env, goal, 1.0 - exp(-delta * 24.0))
	_wind_env = lerpf(_wind_env, wind, 1.0 - exp(-delta * 30.0))
	var side: float = float(melee.swing_side)
	if not _motion:
		rig.rotation.z += side * 0.09 * _swing_env - side * 0.05 * _wind_env
		rig.rotation.y += side * 0.06 * _swing_env - side * 0.07 * _wind_env
		rig.rotation.x += 0.06 * _wind_env
		rig.position += Vector3(0, 0.014 * _wind_env - 0.012 * _swing_env, 0.03 * _wind_env - 0.045 * _swing_env)
	# La lama che entra nella carne si ferma di colpo e rimbalza sulle mani.
	var bite_dt := minf(delta, 1.0 / 60.0)     # stessa ragione delle molle in _feel: niente NaN coi frame lunghi
	_bite_v += (-_bite_p * 240.0 - _bite_v * 17.0) * bite_dt
	_bite_p += _bite_v * bite_dt
	rig.rotation.x += _bite_p * 0.55
	rig.rotation.z -= side * _bite_p * 0.35
	rig.position.z += _bite_p * 0.11
	player.rig.swing_roll = lerpf(player.rig.swing_roll, side * -0.018 * _swing_env, 1.0 - exp(-delta * 16.0))
	_ads = move_toward(_ads, 1.0 if melee.ads and _gun else 0.0, delta / 0.14)
	var aim: float = smoothstep(0.0, 1.0, _ads)
	if not _motion: rig.position += ADS_SHIFT.get(set_name, Vector3(-0.1, 0.05, 0.02)) * aim
	player.rig.aim_amount = aim
	if _slide:
		var empty: bool = player.magazine <= 0 and player.reload_left <= 0.0
		_slide_back = move_toward(_slide_back, 1.0 if empty else 0.0, delta * 16.0)
		_slide.position = _slide_base + Vector3(0, 0, 0.03) * maxf(_slide_back, _motion.slide_back if _motion else 0.0)


## Sparo: vampa, bossolo, scia del proiettile, l'arma scalcia e la vista sale di poco.
func _gun_fired(at: Vector3) -> void:
	_kick = 1.0
	_slide_back = 1.0
	if _motion:
		_motion.shot(player.melee.ads)
		# Pompa, leva, otturatore: i pezzi dell'arma si muovono da soli.
		for found in (item.find_children("*", "AnimationPlayer", true, false) if item else []):
			if (found as AnimationPlayer).has_animation("Wep_Fire"): (found as AnimationPlayer).play("Wep_Fire")
	if player.local_control:
		# Ogni arma scalcia a modo suo: la vista sale e devia di quanto vale il colpo.
		var kick_row: Array = ToolMotion.WEAPONS.get(weapon, {}).get("rec", [1.6, 2.6])
		var soft: float = 0.5 if player.melee.ads else 1.0
		player.rig.pitch += float(kick_row[1]) * 0.0055 * soft
		player.rig.yaw += randf_range(-1.0, 1.0) * float(kick_row[1]) * 0.002 * soft
		player.rig.add_shake(float(kick_row[0]) * 0.07)
	if item == null: return
	var view: Camera3D = player.rig.camera
	var forward: Vector3 = -view.global_basis.z
	var muzzle: Vector3 = view.global_position + forward * 0.5
	var best := -INF
	for mesh in item.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		for i in 8:
			var corner := box.get_endpoint(i)
			if corner.dot(forward) > best:
				best = corner.dot(forward)
				muzzle = corner
	GunFx.fire(player.get_parent(), weapon, muzzle, player.melee.last_ends if not player.melee.last_ends.is_empty() else [at], forward, view.global_basis.x)


## Tempo di gioco di un attacco -> tempo della clip: l'impatto cade a metà della finestra attiva.
func _warp(clip: String, time: float, windup: float, active: float, recovery: float) -> float:
	var length := _len(clip)
	var hit := float(HIT_FRAME.get(clip, 8)) / 30.0
	var game_hit := windup + active * 0.5
	var total := windup + active + recovery
	if time <= game_hit:
		return time / maxf(game_hit, 0.001) * hit
	# dopo l'impatto la clip va a velocità reale: l'accompagnamento può durare più della finestra del gioco
	return minf(length, hit + (time - game_hit) * maxf(1.0, (length - hit) / maxf(total - game_hit, 0.001) * 0.6))


func _len(clip: String) -> float:
	return library.get_animation(clip).length if library.has_animation(clip) else 1.0


func _pose(clip: String, time: float) -> Dictionary:
	var out := {}
	if not library.has_animation(clip) or not _tracks.has(clip): return out
	var anim := library.get_animation(clip)
	for row in _tracks[clip]:
		var b: int = row[0]
		if not out.has(b): out[b] = [_rest[b][0], null]
		if row[1] == 0: out[b][0] = anim.rotation_track_interpolate(row[2], time)
		else: out[b][1] = anim.position_track_interpolate(row[2], time)
	return out


func _mix(a: Dictionary, b: Dictionary, w: float) -> void:
	for bone in b:
		if not a.has(bone): a[bone] = [_rest[bone][0], null]
		a[bone][0] = (a[bone][0] as Quaternion).slerp(b[bone][0], w)
		if b[bone][1] != null:
			var p: Vector3 = a[bone][1] if a[bone][1] != null else _rest[bone][1]
			a[bone][1] = p.lerp(b[bone][1], w)


func _carry_piece(mesh: PrimitiveMesh, color: Color, size: Vector3) -> MeshInstance3D:
	if mesh is BoxMesh: (mesh as BoxMesh).size = size
	else:
		(mesh as CylinderMesh).top_radius = size.x * 0.5; (mesh as CylinderMesh).bottom_radius = size.x * 0.5; (mesh as CylinderMesh).height = size.y
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, 0.07, 0.03)      # nel palmo, verso le dita
	mi.visible = false
	_hand_socket.add_child(mi)
	return mi
