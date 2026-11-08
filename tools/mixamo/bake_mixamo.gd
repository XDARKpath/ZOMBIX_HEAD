extends SceneTree
# Porta le animazioni Mixamo (FBX senza pelle, fuori dal progetto) sugli scheletri del gioco.
# Entrambi partono dalla posa a T con +Z avanti: conta di quanto ruota ogni osso rispetto a quella posa, non come sono orientate le ossa.
# Infetti: art/zombie_motion/zombie_motion.res. Giocatore: art/zx_player/mixamo_player.res, una libreria che sostituisce le clip per nome.
#   godot --path . --headless -s res://tools/mixamo/bake_mixamo.gd -- <cartella FBX>
const NAMES := {
	"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03", "Neck": "neck_01", "Head": "head",
	"LeftShoulder": "clavicle_l", "RightShoulder": "clavicle_r", "LeftArm": "upperarm_l", "RightArm": "upperarm_r",
	"LeftForeArm": "lowerarm_l", "RightForeArm": "lowerarm_r", "LeftHand": "hand_l", "RightHand": "hand_r",
	"LeftUpLeg": "thigh_l", "RightUpLeg": "thigh_r", "LeftLeg": "calf_l", "RightLeg": "calf_r", "LeftFoot": "foot_l", "RightFoot": "foot_r",
	"LeftToeBase": "ball_l", "RightToeBase": "ball_r",
}
const FINGERS := {"Thumb": "thumb", "Index": "index", "Middle": "middle", "Ring": "ring", "Pinky": "pinky"}
const LOOPS := ["Z_Idle", "Z_Idle2", "Z_Idle3", "Z_Walk_A", "Z_Walk_B", "Z_Run", "Z_Crawl", "Z_Feed_Kneel", "Z_Patrol_Walk_Limp", "Z_Tank_Walk", "Z_Tank_Idle", "Z_Tank_Run",
	"Player_Idle_Unarmed", "Player_Idle_Rifle", "Player_Walk_Slow", "Player_Walk_Fwd_Rifle", "Player_Walk_Bwd_Rifle", "Player_Strafe_Left_Rifle", "Player_Strafe_Right_Rifle", "Player_Run_Fwd_Rifle",
	"Player_Crouch_Idle_Rifle", "Player_Crouch_Walk_Fwd", "Player_Axe_Idle", "Player_Axe_Walk", "Player_Axe_Run"]
## Colpi degli infetti: [portata m, spinta m/s]. Il momento del colpo lo misura la mano; se è tardi, la clip viene accelerata.
const ATTACKS := {"Z_Attack_Swipe_R": [1.7, 1.2], "Z_Attack_Swipe_L": [1.7, 1.2], "Z_Attack_Jab": [1.6, 1.0], "Z_Attack_Headbutt": [1.7, 1.6], "Z_Attack_Lunge_Bite": [1.9, 2.0],
	"Z_Attack_Overhead_Smash": [1.9, 0.8], "Z_Attack_Leap": [2.4, 6.0], "Z_Tank_Swipe": [2.0, 1.0], "Z_Tank_Punch": [1.9, 1.2]}
const HIT_LIMIT := {"Z_Attack_Leap": 0.5, "Z_Attack_Overhead_Smash": 0.85}
## Stessa animazione per più nomi.
const ALIASES := {"Player_Idle_Rifle": "Player_Idle_Unarmed", "Player_Melee1H_Idle": "Player_Axe_Idle", "Player_Melee1H_Swing": "Player_Axe_Swing_Horizontal",
	"Player_Melee1H_Swing_Back": "Player_Axe_Swing_Back", "Player_Melee1H_Bonk": "Player_Axe_Chop_Overhead"}
## Clip del personaggio accelerate: un colpo o un gesto non possono durare secondi.
const PLAYER_RATE := {"Player_Axe_Swing_Horizontal": 1.8, "Player_Axe_Swing_Back": 1.8, "Player_Axe_Chop_Overhead": 1.7, "Player_Melee_Kick": 1.5, "Player_Axe_Shove": 1.5, "Player_Sword_Slash_1": 1.5, "Player_Sword_Slash_2": 1.5, "Player_Sword_Slash_3": 1.5, "Player_Sword_Heavy": 1.4,
	"Player_Interact_Reach_High": 1.6, "Player_Interact_Reach_Low": 1.35, "Player_Grenade_Throw": 1.25, "Player_Hit_Impact_Back": 1.1}
## Clip fatte di due pezzi: cade e si rialza.
## Reazioni: [velocità, secondi tenuti dopo l'accelerazione]. Lo zombie barcolla e torna a combattere, non resta fuori gioco per secondi.
const REACT_TIMING := {"Z_React_Pushed": [1.5, 1.8], "Z_React_Knockdown": [1.35, 4.0]}
const JOINS := {"Z_React_Knockdown": ["Z_React_Knock", "Z_Up_Back"]}
const NO_DRIFT := ["Z_React_Knock", "Z_Up_Back", "Z_Up_Front", "Z_React_Pushed", "Z_Stagger_Heavy", "Z_Hit_Front", "Z_Hit_Head", "Z_Hit_L", "Z_Hit_R", "Z_Scream", "Z_Roar", "Z_Feed_Kneel"]


func _init() -> void:
	call_deferred("_run")


func _source(file: String) -> Dictionary:
	var doc := FBXDocument.new()
	var state := FBXState.new()
	if doc.append_from_file(file, state) != OK: return {}
	var scene: Node = doc.generate_scene(state)
	root.add_child(scene)
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var clip := ""
	for a in ap.get_animation_list():
		if a != "RESET": clip = a
	var map := {}
	for i in sk.get_bone_count():
		var raw: String = sk.get_bone_name(i)
		var short: String = raw.get_slice(":", raw.get_slice_count(":") - 1)
		if short.begins_with("mixamorig"): short = short.trim_prefix("mixamorig").trim_prefix("_")
		if NAMES.has(short): map[NAMES[short]] = i
		else:
			for key in FINGERS:
				for side in [["Left", "l"], ["Right", "r"]]:
					for n in 3:
						if short == "%sHand%s%d" % [side[0], key, n + 1]:
							map["%s_0%d_%s" % [FINGERS[key], n + 1, side[1]]] = i
	return {"scene": scene, "sk": sk, "ap": ap, "clip": clip, "map": map, "length": ap.get_animation(clip).length}


## L'osso che indica dove punta questo: serve a far puntare ogni arto come nella clip, anche se le proporzioni a riposo sono diverse.
const CHAIN := {"spine_01": "spine_02", "spine_02": "spine_03", "spine_03": "neck_01", "neck_01": "head", "clavicle_l": "upperarm_l", "clavicle_r": "upperarm_r",
	"upperarm_l": "lowerarm_l", "upperarm_r": "lowerarm_r", "lowerarm_l": "hand_l", "lowerarm_r": "hand_r", "thigh_l": "calf_l", "thigh_r": "calf_r",
	"calf_l": "foot_l", "calf_r": "foot_r", "foot_l": "ball_l", "foot_r": "ball_r"}
func _child_of(name: String) -> String:
	return CHAIN.get(name, "")


## Fotogrammi: per ogni osso la rotazione nello spazio del genitore rispetto alla posa a T, più il bacino normalizzato.
func _frames(src: Dictionary) -> Dictionary:
	var sk: Skeleton3D = src.sk
	var ap: AnimationPlayer = src.ap
	ap.play(src.clip)
	var map: Dictionary = src.map
	var hips: int = map["pelvis"]
	var hips_rest: Vector3 = sk.get_bone_global_rest(hips).origin
	var scale_to: float = 0.95 / maxf(hips_rest.y, 0.001)
	var count: int = maxi(1, int(round(float(src.length) * 30.0)))
	var out := {"count": count, "rot": [], "pos": [], "hand": [], "foot": [], "world": [], "rest_dir": {}}
	var rest_q := {}
	for name in map: rest_q[name] = sk.get_bone_global_rest(map[name]).basis.get_rotation_quaternion()
	for name in map:
		var child := _child_of(name)
		if child != "" and map.has(child):
			out.rest_dir[name] = (sk.get_bone_global_rest(map[child]).origin - sk.get_bone_global_rest(map[name]).origin).normalized()
	for f in count + 1:
		ap.seek(minf(float(f) / 30.0, float(src.length)), true)
		sk.force_update_all_bone_transforms()
		var delta := {}
		for name in map:
			delta[name] = sk.get_bone_global_pose(map[name]).basis.get_rotation_quaternion() * (rest_q[name] as Quaternion).inverse()
		var row := {}
		for name in map:
			var parent: int = sk.get_bone_parent(map[name])
			var parent_delta := Quaternion.IDENTITY
			if parent >= 0 and name != "pelvis":
				parent_delta = sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() * sk.get_bone_global_rest(parent).basis.get_rotation_quaternion().inverse()
			row[name] = parent_delta.inverse() * (delta[name] as Quaternion)
		out.rot.append(row)
		out.world.append(delta)
		out.pos.append((sk.get_bone_global_pose(hips).origin - hips_rest) * scale_to)
		out.hand.append([sk.get_bone_global_pose(map["hand_r"]).origin * scale_to, sk.get_bone_global_pose(map["hand_l"]).origin * scale_to])
		out.foot.append([sk.get_bone_global_pose(map["foot_l"]).origin * scale_to, sk.get_bone_global_pose(map["foot_r"]).origin * scale_to])
	ap.stop()
	return out


## Istante del colpo: quando una mano è più veloce, nella prima parte della clip.
func _hit_time(fr: Dictionary) -> float:
	var best := 0.0
	var best_f := 1
	for f in range(1, int(fr.count * 0.8)):
		for side in 2:
			var speed: float = (fr.hand[f][side] as Vector3).distance_to(fr.hand[f - 1][side])
			if speed > best:
				best = speed
				best_f = f
	return float(best_f) / 30.0


## Velocità del passo: quanto scorre il piede mentre poggia a terra. Serve a non far pattinare i piedi.
func _stride_speed(fr: Dictionary) -> float:
	var samples: Array = []
	for side in 2:
		var low := INF
		for f in fr.count: low = minf(low, (fr.foot[f][side] as Vector3).y)
		for f in range(1, fr.count):
			var a: Vector3 = fr.foot[f - 1][side]
			var b: Vector3 = fr.foot[f][side]
			if b.y < low + 0.025:
				samples.append(Vector2(b.x - a.x, b.z - a.z).length() * 30.0)
	if samples.is_empty(): return 0.0
	samples.sort()
	return float(samples[samples.size() / 2])


## Un cadavere non tiene il braccio per aria: alla fine della caduta il braccio alzato si affloscia a terra.
func _limp(fr: Dictionary) -> void:
	var last: int = fr.count
	var pelvis_y: float = (fr.pos[last] as Vector3).y + 0.95
	for row in [[0, "r"], [1, "l"]]:
		if (fr.hand[last][row[0]] as Vector3).y - pelvis_y < 0.35: continue
		var chain: Array = ["clavicle_" + row[1], "upperarm_" + row[1], "lowerarm_" + row[1], "hand_" + row[1]]
		var hold: Dictionary = (fr.rot[last] as Dictionary).duplicate()
		for f in 20:
			var w := smoothstep(0.0, 1.0, float(f + 1) / 20.0)
			if fr.rot.size() <= last + f + 1:
				fr.rot.append((fr.rot[last] as Dictionary).duplicate())
				fr.pos.append(fr.pos[last])
				fr.hand.append(fr.hand[last])
				fr.foot.append(fr.foot[last])
			for bone in chain:
				fr.rot[last + f + 1][bone] = (hold[bone] as Quaternion).slerp(Quaternion.IDENTITY, w)
	fr.count = fr.rot.size() - 1


func _packed(fr: Dictionary, bones: PackedStringArray, rate: float, drift: bool) -> Dictionary:
	var frames: int = maxi(1, int(round(float(fr.count) / rate)))
	var q := PackedFloat32Array()
	var p := PackedFloat32Array()
	var start: Vector3 = fr.pos[0]
	for f in frames + 1:
		var at: float = minf(float(f) * rate, float(fr.count))
		var i0: int = int(floor(at))
		var i1: int = mini(i0 + 1, fr.count)
		var w: float = at - float(i0)
		for name in bones:
			var a: Quaternion = fr.rot[i0].get(name, Quaternion.IDENTITY)
			var b: Quaternion = fr.rot[i1].get(name, Quaternion.IDENTITY)
			var v := a.slerp(b, w)
			q.append_array(PackedFloat32Array([v.x, v.y, v.z, v.w]))
		var off: Vector3 = (fr.pos[i0] as Vector3).lerp(fr.pos[i1], w)
		if not drift: off = Vector3(start.x * 0.0, off.y, start.z * 0.0)
		p.append_array(PackedFloat32Array([off.x, off.y, off.z]))
	return {"frames": frames, "q": q, "p": p}


func _run() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	var data: Resource = load("res://art/zombie_motion/zombie_motion.res")
	var bones: PackedStringArray = data.bones
	var baked := {}
	var report: Array = []
	for file in DirAccess.get_files_at(folder):
		if not file.ends_with(".fbx"): continue
		var clip := file.get_basename()
		var src := _source(folder.path_join(file))
		if src.is_empty():
			print("ERRORE lettura ", file)
			continue
		if not src.map.has("pelvis"):
			print("ERRORE ossa ", file, " ", src.sk.get_bone_name(0))
			src.scene.free()
			continue
		if baked.is_empty():
			var sk: Skeleton3D = src.sk
			print("POSA braccio sx ", (sk.get_bone_global_rest(src.map["lowerarm_l"]).origin - sk.get_bone_global_rest(src.map["upperarm_l"]).origin).normalized(),
				" piede avanti ", (sk.get_bone_global_rest(src.map["ball_l"]).origin - sk.get_bone_global_rest(src.map["foot_l"]).origin).normalized(), " dita ", src.map.size())
		baked[clip] = _frames(src)
		src.scene.free()
	# --- Infetti
	for clip in ["Z_Death_Back", "Z_Death_Front", "Z_Boss_Death_Collapse"]:
		if baked.has(clip): _limp(baked[clip])
	var joined := {}
	for name in JOINS:
		var parts: Array = JOINS[name]
		if not baked.has(parts[0]) or not baked.has(parts[1]): continue
		var a: Dictionary = baked[parts[0]]
		var b: Dictionary = baked[parts[1]]
		var fr := {"count": a.count + b.count, "rot": a.rot.duplicate(), "pos": a.pos.duplicate(), "hand": a.hand.duplicate(), "foot": a.foot.duplicate()}
		fr.rot.append_array(b.rot.slice(1))
		fr.hand.append_array(b.hand.slice(1))
		fr.foot.append_array(b.foot.slice(1))
		for f in range(1, b.pos.size()): fr.pos.append(Vector3(0, (b.pos[f] as Vector3).y, 0))
		joined[name] = fr
	for name in joined: baked[name] = joined[name]
	var clips: Dictionary = data.clips.duplicate()
	var attacks: Dictionary = data.attacks.duplicate()
	for clip in baked:
		if not clip.begins_with("Z_"): continue
		var fr: Dictionary = baked[clip]
		var rate := 1.0
		if ATTACKS.has(clip):
			var hit: float = _hit_time(fr)
			rate = maxf(1.0, hit / float(HIT_LIMIT.get(clip, 0.68)))
			var length: float = float(fr.count) / 30.0 / rate
			# Non si resta bloccati per tutta la coda dell'animazione.
			attacks[clip] = [minf(length, hit / rate + 0.75), hit / rate, ATTACKS[clip][0], ATTACKS[clip][1]]
		elif clip in ["Z_Hit_Front", "Z_Hit_Head", "Z_Hit_L", "Z_Hit_R"]:
			rate = maxf(1.0, float(fr.count) / 30.0 / 0.6)
		elif REACT_TIMING.has(clip):
			rate = float(REACT_TIMING[clip][0])
			fr = fr.duplicate()
			fr.count = mini(int(fr.count), int(float(REACT_TIMING[clip][1]) * 30.0 * rate))
		var pack := _packed(fr, bones, rate, not (clip in NO_DRIFT or clip.begins_with("Z_Attack") or clip.begins_with("Z_Tank")))
		var looping: bool = clip in LOOPS
		var entry := {"frames": pack.frames, "loop": looping, "length": float(pack.frames) / 30.0, "q": pack.q, "p": pack.p}
		if looping and pack.frames > 0:
			entry["speed"] = _stride_speed(fr)
		clips[clip] = entry
		report.append("%s %.2fs%s%s" % [clip, entry.length, (" colpo %.2f" % attacks[clip][1]) if attacks.has(clip) and ATTACKS.has(clip) else "", (" passo %.2f" % entry.speed) if entry.has("speed") else ""])
	for name in ALIASES:
		if ALIASES[name].begins_with("Z_") and clips.has(ALIASES[name]):
			clips[name] = clips[ALIASES[name]]
			if attacks.has(ALIASES[name]): attacks[name] = attacks[ALIASES[name]]
	data.clips = clips
	data.attacks = attacks
	print("INFETTI ", ResourceSaver.save(data, "res://art/zombie_motion/zombie_motion.res"))
	# --- Giocatore
	var model: Node3D = load("res://art/zx_player/SM_ZX_Player.glb").instantiate()
	model.build_animation_tree = false
	model.start_weapon = ""
	root.add_child(model)
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	ap.stop()
	var template: Animation = ap.get_animation("Player_Idle_Unarmed")
	var prefix := String(template.track_get_path(0)).get_slice(":", 0)
	var lib := AnimationLibrary.new()
	var pelvis: int = sk.find_bone("pelvis")
	var height: float = sk.get_bone_global_rest(pelvis).origin.y
	var anchor: int = sk.find_bone("weapon_anchor")
	var socket: int = sk.find_bone("weapon_r")
	var speeds := {}
	var sole_y: float = sk.get_bone_global_rest(sk.find_bone("foot_l")).origin.y
	for clip in baked:
		if not clip.begins_with("Player_"): continue
		var fr: Dictionary = baked[clip]
		var anim := Animation.new()
		var speed_up: float = float(PLAYER_RATE.get(clip, 1.0))
		anim.length = float(fr.count) / 30.0 / speed_up
		anim.loop_mode = Animation.LOOP_LINEAR if clip in LOOPS else Animation.LOOP_NONE
		var track := {}
		for name in fr.rot[0]:
			var bone := sk.find_bone(name)
			if bone < 0: continue
			var t := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, NodePath("%s:%s" % [prefix, name]))
			track[name] = [t, bone]
		var t_pelvis := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(t_pelvis, NodePath("%s:pelvis" % prefix))
		var t_anchor_p := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(t_anchor_p, NodePath("%s:weapon_anchor" % prefix))
		var t_anchor_r := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t_anchor_r, NodePath("%s:weapon_anchor" % prefix))
		var parent_of_pelvis := sk.get_bone_parent(pelvis)
		var pelvis_parent_basis: Basis = sk.get_bone_global_rest(parent_of_pelvis).basis if parent_of_pelvis >= 0 else Basis.IDENTITY
		var drifts: bool = not (clip.begins_with("Player_Hit") or clip.begins_with("Player_Axe_Swing") or clip.begins_with("Player_Axe_Chop") or clip.begins_with("Player_Axe_Block") or clip.begins_with("Player_Axe_Shove") or clip.begins_with("Player_Sword") or clip == "Player_Melee_Kick")
		# Ogni arto punta dove punta nella clip: le gambe restano aperte come quelle vere, le ginocchia non si incrociano.
		var fix := {}
		for name in fr.rest_dir:
			var child := sk.find_bone(_child_of(name))
			var me := sk.find_bone(name)
			if child < 0 or me < 0: continue
			var mine: Vector3 = (sk.get_bone_global_rest(child).origin - sk.get_bone_global_rest(me).origin).normalized()
			fix[name] = Quaternion(mine, fr.rest_dir[name])
		var pose_at := func(f: int, lift: float) -> Vector3:
			sk.reset_bone_poses()
			var made := {}
			for bone in sk.get_bone_count():
				var name := sk.get_bone_name(bone)
				var parent := sk.get_bone_parent(bone)
				var up: Basis = made[parent] if made.has(parent) else Basis.IDENTITY
				var whole: Basis
				if track.has(name):
					var q: Quaternion = fr.world[f][name]
					if fix.has(name): q = q * (fix[name] as Quaternion)
					whole = Basis(q) * sk.get_bone_global_rest(bone).basis.orthonormalized()
					sk.set_bone_pose_rotation(bone, (up.inverse() * whole).get_rotation_quaternion())
				else:
					whole = up * sk.get_bone_rest(bone).basis.orthonormalized()
				made[bone] = whole
			var off: Vector3 = fr.pos[f] * (height / 0.95)
			if not drifts: off = Vector3(0, off.y, 0)
			off.y += lift
			var at_pelvis: Vector3 = sk.get_bone_rest(pelvis).origin + pelvis_parent_basis.inverse() * off
			sk.set_bone_pose_position(pelvis, at_pelvis)
			sk.force_update_all_bone_transforms()
			return at_pelvis
		# I piedi poggiano a terra: le proporzioni diverse non li fanno galleggiare né affondare.
		var lift := 0.0
		if clip.begins_with("Player_") and not clip.begins_with("Player_Death"):
			var low := INF
			for f in range(0, fr.count + 1, 2):
				pose_at.call(f, 0.0)
				low = minf(low, minf(sk.get_bone_global_pose(sk.find_bone("foot_l")).origin.y, sk.get_bone_global_pose(sk.find_bone("foot_r")).origin.y))
			lift = sole_y - low
		speeds[clip] = _stride_speed(fr) * height / 0.95
		for f in fr.count + 1:
			var at: float = float(f) / 30.0 / speed_up
			var pelvis_pos: Vector3 = pose_at.call(f, lift)
			for name in track:
				anim.rotation_track_insert_key(track[name][0], at, sk.get_bone_pose_rotation(track[name][1]))
			anim.position_track_insert_key(t_pelvis, at, pelvis_pos)
			# L'arma segue la mano: weapon_anchor sta dove sta weapon_r.
			if anchor >= 0 and socket >= 0:
				var wanted: Transform3D = sk.get_bone_global_pose(socket)
				var parent := sk.get_bone_parent(anchor)
				var local_a: Transform3D = sk.get_bone_global_pose(parent).affine_inverse() * wanted if parent >= 0 else wanted
				anim.position_track_insert_key(t_anchor_p, at, local_a.origin)
				anim.rotation_track_insert_key(t_anchor_r, at, local_a.basis.get_rotation_quaternion())
		lib.add_animation(clip, anim)
		report.append("%s %.2fs" % [clip, anim.length])
	for name in ALIASES:
		if ALIASES[name].begins_with("Player_") and lib.has_animation(ALIASES[name]):
			lib.add_animation(name, lib.get_animation(ALIASES[name]))
	lib.set_meta("speeds", speeds)
	print("VELOCITA ", speeds)
	print("GIOCATORE ", ResourceSaver.save(lib, "res://art/zx_player/mixamo_player.res"), " clip ", lib.get_animation_list().size())
	for line in report: print("  ", line)
	print("FINE")
	quit(0)
