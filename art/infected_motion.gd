extends RefCounted
# Keyframed infected animation set (21 clips, art/zombie_motion/zombie_motion.res) for the infected.
# Clips are stored as skeleton-space rotation deltas over the T-pose rest, applied exactly like
# survivor_visual.transform_bone():  pose = Pparent^-1 * R * Pparent * rest  -> they fit any rig with these bone names.
# Picks the clip from the actor state (zombie_ai.gd): walk / run / idle / scream / attacks / hits / deaths / crawl,
# crossfades between clips and keeps the existing head split + hitboxes working.
# Usato da tutti gli infetti e dai boss (art/zx_infected, stesso rig a 65 ossa).

const DATA_PATH := "res://art/zombie_motion/zombie_motion.res"
const WALK_SPEED := 0.9        # m/s the walk clips were authored for
const RUN_SPEED := 4.0         # m/s of Z_Run
const DEATHS := ["Z_Death_Back", "Z_Death_Front", "Z_Death_Spin", "Z_Death_Front"]
const HITS := ["Z_Hit_Front", "Z_Hit_Head", "Z_Hit_L", "Z_Hit_R"]

static var _data: Resource
static var _rigs := {}          # model id -> {index, parent_basis, rest_basis, rest_origin, scale}


static func data() -> Resource:
	if _data == null and ResourceLoader.exists(DATA_PATH):
		_data = load(DATA_PATH)
	return _data


## Attack clip used by an infected for its n-th attack. Shared by zombie_ai (timing) and the visual (pose),
## deterministic so network replicas pick the same clip without extra sync.
static func pick_attack(kind: int, id: int, serial: int, crawling: bool) -> String:
	if crawling:
		return "Z_Crawl_Attack"
	var clips: Dictionary = data().clips if data() else {}
	match kind:
		1: return "Z_Attack_Leap" if serial % 3 != 2 else "Z_Attack_Swipe_R"
		# Il bruto alterna lo schianto dall'alto, la manata e il pugno.
		2:
			if clips.has("Z_Tank_Swipe"): return ["Z_Attack_Overhead_Smash", "Z_Tank_Swipe", "Z_Tank_Punch"][serial % 3]
			return ["Z_Attack_Overhead_Smash", "Z_Attack_Swipe_R"][serial % 2]
		3: return ["Z_Attack_Headbutt", "Z_Attack_Swipe_L"][serial % 2]
		4: return "Z_Spit"
		5: return ["Z_Attack_Overhead_Smash", "Z_Attack_Leap", "Z_Attack_Swipe_R"][serial % 3]
	if clips.has("Z_Attack_Jab"): return ["Z_Attack_Swipe_R", "Z_Attack_Headbutt", "Z_Attack_Swipe_L", "Z_Attack_Jab"][(id + serial) % 4]
	return ["Z_Attack_Swipe_R", "Z_Attack_Headbutt", "Z_Attack_Swipe_L"][(id + serial) % 3]


## A che velocità è stata fatta una clip del passo (misurata da tools/mixamo/bake_mixamo.gd).
static func _clip_speed(d: Resource, clip: String, fallback: float) -> float:
	var speed: float = float(d.clips[clip].get("speed", 0.0)) if d.clips.has(clip) else 0.0
	return speed if speed > 0.15 else fallback


## [length s, hit time s, reach m, lunge speed m/s]
static func attack_timing(clip: String) -> Array:
	var d := data()
	if d and d.attacks.has(clip):
		return d.attacks[clip]
	return [1.25, 0.62, 1.8, 0.0]


static func apply(v: Node3D, delta: float) -> void:
	var d := data()
	if d == null:
		push_error("infected_motion: manca " + DATA_PATH)
		return
	var a: Node3D = v.actor
	var rig := _rig(v, d)
	var st: Dictionary = v.get_meta("zm") if v.has_meta("zm") else {"clip": "", "t": 0.0, "prev": "", "pt": 0.0, "blend": 1.0,
		"fade": 0.2, "hit": "", "stag": false, "hits": 0, "state": 0, "serial": 0, "scream": 0.0}
	v.rotation = Vector3.ZERO
	v.position = Vector3.ZERO
	var pace: float = Vector2(a.velocity.x, a.velocity.z).length()
	var id: int = a.get("network_id") if a.get("network_id") != null else 0
	var state: int = a.get("state") if a.get("state") != null else 0
	var clip := "Z_Idle"
	var t: float = st.t
	var rate := 1.0
	var fade := 0.2
	# attack serial counted on every entry into ATTACK (same on host and replicas)
	if state == 2 and st.state != 2:
		st.serial += 1
	if state == 1 and st.state == 0 and a.get("alert_time") != null and a.alert_time > 0:
		st.scream = a.alert_time
	st.state = state
	st.scream = maxf(0.0, st.scream - delta)
	var stag: bool = a.stagger > 0.03 and not a.dead and a.kind != 2 and a.kind != 5
	if stag and not st.stag:
		st.hits += 1
		st.hit = "Z_Stagger_Heavy" if a.stagger > 0.4 else HITS[(id + st.hits) % HITS.size()]
	st.stag = stag
	if a.dead:
		clip = DEATHS[a.death_style % DEATHS.size()]
		t = a.death_clock
		if a.crawling or a.death_style == 4:
			# Muore strisciando: solo la fine della caduta in avanti, così resta disteso a terra e non torna su.
			clip = "Z_Death_Front"
			t = float(d.clips[clip].frames) * 0.72 / d.fps + a.death_clock
		elif a.kind == 5:
			clip = "Z_Boss_Death_Collapse"
		rate = 0.0
		fade = 0.12
	elif a.get("reaction") != null and a.reaction != "":
		# Reazione direzionale al colpo (Z_React_*): ha la precedenza sulle hit generiche.
		clip = a.reaction_clip()
		t = a.reaction_clip_time()
		rate = 0.0
		fade = 0.06
	elif stag:
		clip = st.hit
		fade = 0.06
	elif state == 2:
		clip = a.attack_clip if a.get("attack_clip") and a.attack_clip != "" else pick_attack(a.kind, id, st.serial, a.crawling)
		# il boss attacca più lento e pesante: anim_scale allunga la clip
		t = a.attack_clock / maxf(float(a.get("anim_scale")) if a.get("anim_scale") != null else 1.0, 0.1)
		rate = 0.0
		fade = 0.1
	elif st.scream > 0 and not a.crawling:
		clip = "Z_Roar" if a.kind == 5 else "Z_Scream"
	elif a.crawling:
		clip = "Z_Crawl"
		rate = clampf(pace / 0.45, 0.15, 1.4)
	elif pace > 2.2:
		clip = "Z_Tank_Run" if a.kind in [2, 5] and d.clips.has("Z_Tank_Run") else "Z_Run"
		rate = clampf(pace / _clip_speed(d, clip, RUN_SPEED), 0.6, 1.5)
	elif pace > 0.08 and state == 0 and a.kind == 0 and id % 2 == 0 and a.get("patrol") != null and a.patrol.size() > 0:
		clip = "Z_Patrol_Walk_Limp"                     # walker di pattuglia (zoppica, ~0.75 m/s a rate 1)
		rate = clampf(pace / 0.75, 0.45, 1.5)
	elif pace > 0.08:
		clip = "Z_Walk_A" if id % 2 == 0 else "Z_Walk_B"
		# Uno su cinque zoppica anche quando ti insegue.
		if a.kind == 0 and id % 5 == 1:
			clip = "Z_Patrol_Walk_Limp"
		if a.kind in [2, 5] and d.clips.has("Z_Tank_Walk"):
			clip = "Z_Tank_Walk"
		# La velocità della clip segue il passo vero, così i piedi non scivolano.
		rate = clampf(pace / _clip_speed(d, clip, WALK_SPEED), 0.35, 1.8)
	elif state == 0 and id % 4 == 3:
		clip = "Z_Feed_Kneel"
	elif a.kind in [2, 5] and d.clips.has("Z_Tank_Idle"):
		clip = "Z_Tank_Idle"
	elif d.clips.has("Z_Idle2") and id % 3 == 1:
		clip = "Z_Idle2"
	elif d.clips.has("Z_Idle3") and id % 3 == 2:
		clip = "Z_Idle3"
	if clip != st.clip:
		st.prev = st.clip
		st.pt = st.t
		st.blend = 0.0 if st.clip != "" else 1.0
		st.fade = fade
		st.clip = clip
		if rate != 0.0:
			t = 0.0 if not clip.begins_with("Z_Walk") else fposmod(float(id) * 0.37, 1.0)
	if rate != 0.0:
		t += delta * rate
	st.t = t
	st.blend = minf(1.0, st.blend + delta / maxf(st.fade, 0.01))
	v.set_meta("zm", st)
	var pose := _sample(d, clip, t)
	if st.blend < 1.0 and st.prev != "":
		var old := _sample(d, st.prev, st.pt)
		var w: float = smoothstep(0.0, 1.0, st.blend)
		for i in pose.q.size():
			pose.q[i] = (old.q[i] as Quaternion).slerp(pose.q[i], w)
		pose.p = (old.p as Vector3).lerp(pose.p, w)
	_layers(v, a, st, pose, rig, delta, id)
	_write(v, rig, pose)
	if a.get("kind") == 2 or (a.get("kind") == 5 and a.get("custom_skin") == ""): _bulk(v)
	v.skeleton.force_update_all_bone_transforms()
	if a.dead: _ground_corpse(v, a)
	v.head_piece.visible = not a.beheaded
	if v.head_piece.visible:
		v.head_piece.global_transform = v.skeleton.global_transform * v.skeleton.get_bone_global_pose(v.bone_ids["head"])
	a.update_hitboxes()


## Il cadavere sta a terra: finita la caduta, se il busto resta sollevato (colpo che l'ha alzato, clip che
## finisce in aria) il modello scende finché la parte più bassa del busto tocca il pavimento.
static func _ground_corpse(v: Node3D, a: Node3D) -> void:
	var lowest := INF
	for bone in ["pelvis", "spine_02", "spine_03", "head"]:
		if v.bone_ids.has(bone):
			lowest = minf(lowest, (v.skeleton.global_transform * v.skeleton.get_bone_global_pose(v.bone_ids[bone])).origin.y)
	if lowest == INF: return
	var ray := PhysicsRayQueryParameters3D.create(a.global_position + Vector3.UP * 0.5, a.global_position + Vector3.DOWN * 4.0, 1)
	var hit: Dictionary = a.get_world_3d().direct_space_state.intersect_ray(ray)
	var floor_y: float = (hit.position as Vector3).y if not hit.is_empty() else a.global_position.y
	var drop: float = clampf(lowest - floor_y - 0.14, 0.0, 3.5) * clampf((float(a.death_clock) - 0.9) / 0.5, 0.0, 1.0)
	if drop > 0.0:
		v.global_position.y -= drop
		v.skeleton.force_update_all_bone_transforms()


## Il bruto è grosso davvero: torace e spalle larghi, braccia e cosce spesse, testa della misura giusta.
static func _bulk(v: Node3D) -> void:
	var sk: Skeleton3D = v.skeleton
	for row in [["spine_02", 1.14], ["spine_03", 1.12], ["neck_01", 0.78], ["upperarm_l", 1.08], ["upperarm_r", 1.08], ["lowerarm_l", 1.0], ["lowerarm_r", 1.0],
			["hand_l", 0.85], ["hand_r", 0.85], ["thigh_l", 1.18], ["thigh_r", 1.18], ["calf_l", 0.94], ["calf_r", 0.94]]:
		var i: int = v.bone_ids.get(row[0], -1)
		if i >= 0: sk.set_bone_pose_scale(i, Vector3.ONE * float(row[1]))


## Ruota un osso sopra la clip. Spazio del personaggio: +Z avanti, +Y su, +X sinistra.
static func _bend(pose: Dictionary, named: Dictionary, bone: String, axis: Vector3, angle: float) -> void:
	if named.has(bone):
		pose.q[named[bone]] = Quaternion(axis, angle) * (pose.q[named[bone]] as Quaternion)


## Quello che le clip da sole non danno: il corpo che incassa il colpo da dove arriva, la carica prima di colpire,
## la testa che ti segue, le braccia protese, il respiro. Ogni infetto è diverso dagli altri.
static func _layers(v: Node3D, a: Node3D, st: Dictionary, pose: Dictionary, rig: Dictionary, delta: float, id: int) -> void:
	# I boss hanno il loro modo di incassare i colpi.
	if a.get("hit_age") == null: return
	var named: Dictionary = rig.named
	var heavy: bool = a.kind == 2 or a.kind == 5
	# Da morto: ogni colpo al cadavere lo fa sobbalzare.
	if a.dead:
		var kick: float = a.ragdoll_kick
		if kick > 0.01:
			_bend(pose, named, "spine_01", Vector3.RIGHT, -kick * 0.3)
			_bend(pose, named, "spine_03", Vector3.RIGHT, kick * 0.22)
		return
	var seed: float = float(id % 97) * 0.731
	var t: float = v.clock
	# Respiro e testa ciondolante: ognuno la tiene storta a modo suo.
	_bend(pose, named, "spine_02", Vector3.RIGHT, sin(t * (1.5 + fposmod(seed, 0.5)) + seed) * 0.022)
	_bend(pose, named, "head", Vector3.BACK, (float(id % 5) - 2.0) * 0.07 + sin(t * 0.9 + seed) * 0.03)
	if heavy:
		_bend(pose, named, "spine_01", Vector3.RIGHT, 0.10)
	var state: int = a.get("state") if a.get("state") != null else 0
	var world = a.get("world")
	# Chi è più lontano di 30 m non ha bisogno del resto.
	var watcher: Node3D = world.player if world != null and is_instance_valid(world.get("player")) else null
	if watcher == null or watcher.global_position.distance_squared_to(a.global_position) > 900.0:
		return
	# La testa segue il giocatore.
	var look_goal := Vector2.ZERO
	if (state == 1 or state == 2) and not a.crawling:
		var local: Vector3 = a.to_local(watcher.global_position + Vector3.UP * 1.3)
		var yaw: float = clampf(atan2(-local.x, -local.z), -1.0, 1.0)
		var pitch: float = clampf(atan2(1.4 - local.y, Vector2(local.x, local.z).length()), -0.5, 0.5)
		look_goal = Vector2(yaw, pitch)
	var look: Vector2 = st.get("look", Vector2.ZERO)
	look = look.lerp(look_goal, 1.0 - exp(-delta * 7.0))
	st["look"] = look
	_bend(pose, named, "neck_01", Vector3.UP, look.x * 0.35)
	_bend(pose, named, "head", Vector3.UP, look.x * 0.55)
	_bend(pose, named, "head", Vector3.RIGHT, look.y * 0.7)
	# Le braccia si allungano quando ti è vicino e ti insegue.
	var reach: float = st.get("reach", 0.0)
	var wants: float = 1.0 if state == 1 and a.kind in [0, 3] and id % 3 != 0 and not a.crawling else 0.0
	reach = move_toward(reach, wants, delta * 2.2)
	st["reach"] = reach
	if reach > 0.01:
		var swing: float = sin(t * 3.1 + seed) * 0.09
		_bend(pose, named, "upperarm_l", Vector3.RIGHT, -reach * (0.85 + swing))
		_bend(pose, named, "upperarm_r", Vector3.RIGHT, -reach * (0.72 - swing))
		_bend(pose, named, "lowerarm_l", Vector3.RIGHT, -reach * 0.25)
		_bend(pose, named, "lowerarm_r", Vector3.RIGHT, -reach * 0.25)
	# Attacco: carica all'indietro, poi tutto il peso sul colpo.
	if state == 2 and a.get("attack_hit") != null and a.attack_hit > 0.01:
		var windup: float = clampf(a.attack_clock / a.attack_hit, 0.0, 1.0)
		var after: float = maxf(0.0, a.attack_clock - a.attack_hit)
		var spit: bool = str(a.attack_clip) == "Z_Spit"
		var back: float = sin(windup * PI * 0.5) * exp(-after * 16.0)
		var throw_in: float = (1.0 - exp(-after * 22.0)) * exp(-after * 3.5)
		var force: float = 1.35 if heavy else 1.0
		_bend(pose, named, "spine_01", Vector3.RIGHT, (-0.1 * back + 0.14 * throw_in) * force)
		_bend(pose, named, "spine_03", Vector3.RIGHT, (-0.15 * back + 0.24 * throw_in) * force)
		if spit:
			# Sputare: inghiotte, butta indietro la testa, frusta in avanti.
			_bend(pose, named, "neck_01", Vector3.RIGHT, -0.38 * back + 0.42 * throw_in)
			_bend(pose, named, "head", Vector3.RIGHT, -0.55 * back + 0.5 * throw_in)
			_bend(pose, named, "spine_02", Vector3.RIGHT, -0.2 * back + 0.3 * throw_in)
		_spit_glow(v, a, windup if spit and after <= 0.0 else 0.0)
	else:
		_spit_glow(v, a, 0.0)
	# Il colpo incassato: il corpo cede da dove è arrivato, poi torna con un rimbalzo.
	var age: float = a.hit_age
	if age < 0.9:
		var env: float = minf(age / 0.05, 1.0) * exp(-age * 5.2) * a.hit_power * (0.6 if heavy else 1.0)
		var rebound: float = env * cos(age * 11.0)
		var dir: Vector3 = a.hit_dir
		if dir.length_squared() < 0.01: dir = Vector3.BACK * -1.0
		var axis: Vector3 = Vector3.UP.cross(dir).normalized()
		match str(a.hit_zone):
			"head", "neck":
				_bend(pose, named, "head", axis, rebound * 0.75)
				_bend(pose, named, "neck_01", axis, rebound * 0.4)
				_bend(pose, named, "spine_03", axis, rebound * 0.14)
			"legs", "feet":
				pose.p = (pose.p as Vector3) + Vector3.DOWN * env * 0.07
				_bend(pose, named, "pelvis", axis, rebound * 0.12)
				_bend(pose, named, "spine_02", axis, -rebound * 0.2)
				_bend(pose, named, "thigh_l", Vector3.RIGHT, -env * 0.25)
				_bend(pose, named, "calf_l", Vector3.RIGHT, env * 0.35)
			_:
				_bend(pose, named, "spine_01", axis, rebound * 0.24)
				_bend(pose, named, "spine_02", axis, rebound * 0.26)
				_bend(pose, named, "spine_03", axis, rebound * 0.24)
				_bend(pose, named, "head", axis, -rebound * 0.2)
				# Le braccia seguono il corpo in ritardo.
				_bend(pose, named, "upperarm_l", axis, -env * 0.3)
				_bend(pose, named, "upperarm_r", axis, -env * 0.3)


## Il liquido che si raccoglie in bocca prima dello sputo: si vede arrivare e si fa in tempo a scansarsi.
static func _spit_glow(v: Node3D, a: Node3D, amount: float) -> void:
	if a.kind != 4: return
	var ball: Node3D = v.get_node_or_null("SpitGlow")
	if ball == null:
		if amount <= 0.0: return
		ball = MeshInstance3D.new()
		ball.name = "SpitGlow"
		var mesh := SphereMesh.new()
		mesh.radius = 0.09
		mesh.height = 0.18
		mesh.radial_segments = 8
		mesh.rings = 4
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("8fd14a")
		mat.emission_enabled = true
		mat.emission = Color("6dff3a")
		mat.emission_energy_multiplier = 2.6
		mesh.material = mat
		(ball as MeshInstance3D).mesh = mesh
		v.add_child(ball)
		ball.top_level = true
	ball.visible = amount > 0.02
	if ball.visible and v.head_piece:
		ball.global_position = a.mouth_position()
		ball.scale = Vector3.ONE * lerpf(0.2, 1.15, amount)


static func _sample(d: Resource, clip: String, t: float) -> Dictionary:
	var c: Dictionary = d.clips[clip]
	var n: int = c.frames
	var f: float = t * d.fps
	if c.loop:
		f = fposmod(f, float(n))
	else:
		f = clampf(f, 0.0, float(n))
	var f0 := int(floor(f))
	var f1 := mini(f0 + 1, n) if not c.loop else (f0 + 1) % n
	var w := f - f0
	var nb: int = d.bones.size()
	var q: PackedFloat32Array = c.q
	var p: PackedFloat32Array = c.p
	var out := []
	for b in nb:
		var i0 := (f0 * nb + b) * 4
		var i1 := (f1 * nb + b) * 4
		var qa := Quaternion(q[i0], q[i0 + 1], q[i0 + 2], q[i0 + 3])
		var qb := Quaternion(q[i1], q[i1 + 1], q[i1 + 2], q[i1 + 3])
		out.append(qa.slerp(qb, w))
	var pa := Vector3(p[f0 * 3], p[f0 * 3 + 1], p[f0 * 3 + 2])
	var pb := Vector3(p[f1 * 3], p[f1 * 3 + 1], p[f1 * 3 + 2])
	return {"q": out, "p": pa.lerp(pb, w)}


static func _rig(v: Node3D, d: Resource) -> Dictionary:
	var key: String = v.model_id
	if _rigs.has(key):
		return _rigs[key]
	var sk: Skeleton3D = v.skeleton
	var info := {"index": [], "pb": [], "rest": [], "pelvis": -1, "porigin": Vector3.ZERO, "ppb": Basis.IDENTITY, "scale": 1.0, "named": {}}
	for name in d.bones:
		var i: int = v.bone_ids.get(String(name).to_lower(), -1)
		info.named[String(name).to_lower()] = info.index.size()
		info.index.append(i)
		if i < 0:
			info.pb.append(Basis.IDENTITY)
			info.rest.append(Basis.IDENTITY)
			continue
		var parent := sk.get_bone_parent(i)
		info.pb.append(sk.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY)
		info.rest.append(sk.get_bone_rest(i).basis)
	var pelvis: int = v.bone_ids.get("pelvis", -1)
	if pelvis >= 0:
		info.pelvis = pelvis
		info.porigin = sk.get_bone_rest(pelvis).origin
		var parent := sk.get_bone_parent(pelvis)
		info.ppb = sk.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
		# clip offsets are metres for a 0.95 m pelvis; rescale to this skeleton's units and size
		var h: float = sk.get_bone_global_rest(pelvis).origin.y
		var ppb: Basis = info.ppb
		info.scale = (h / float(d.pelvis_height)) if h > 0.01 else 1.0
	_rigs[key] = info
	return info


static func _write(v: Node3D, rig: Dictionary, pose: Dictionary) -> void:
	var sk: Skeleton3D = v.skeleton
	sk.reset_bone_poses()
	for b in rig.index.size():
		var i: int = rig.index[b]
		if i < 0:
			continue
		var pb: Basis = rig.pb[b]
		var R := Basis(pose.q[b])
		sk.set_bone_pose_rotation(i, (pb.inverse() * R * pb * rig.rest[b]).get_rotation_quaternion())
	if rig.pelvis >= 0:
		var off: Vector3 = (rig.ppb as Basis).inverse() * (pose.p * rig.scale)
		sk.set_bone_pose_position(rig.pelvis, rig.porigin + off)
