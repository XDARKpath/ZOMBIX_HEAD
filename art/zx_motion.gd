extends RefCounted
# Mixer delle clip dello ZX Player (ZOMBIX_Batch2) per infetti, boss e NPC generati.
# I personaggi di art/zx_infected hanno lo stesso scheletro da 65 ossa con le stesse pose
# di riposo: le tracce si leggono osso per osso e si scrivono direttamente sullo Skeleton3D.
# Così il busto può attaccare mentre le gambe camminano, e i ritocchi procedurali
# (gobba, testa storta, braccia protese) si sommano sopra la clip.

const SOURCE := "res://art/zx_player/SM_ZX_Player.glb"
# Ossa che restano alla locomozione quando un attacco o un colpo occupa il busto.
const LOWER := {"root": true, "pelvis": true, "thigh_l": true, "calf_l": true, "foot_l": true, "ball_l": true,
	"thigh_twist_01_l": true, "thigh_r": true, "calf_r": true, "foot_r": true, "ball_r": true, "thigh_twist_01_r": true}
static var _clips: Dictionary = {}

var skeleton: Skeleton3D
var ids: Dictionary
var base := ""
var base_time := 0.0
var prev := ""
var prev_time := 0.0
var fade := 1.0
var fade_time := 0.25

func _init(target: Skeleton3D, bone_ids: Dictionary) -> void:
	skeleton = target
	ids = bone_ids

static func clip(name: String) -> Dictionary:
	if _clips.is_empty(): _load()
	return _clips.get("Player_" + name, {})

static func _load() -> void:
	var player: Node = load(SOURCE).instantiate()
	var ap: AnimationPlayer = player.find_children("*", "AnimationPlayer", true, false)[0]
	for name in ap.get_animation_list():
		var anim := ap.get_animation(name)
		var rot := []
		var pos := []
		for t in anim.get_track_count():
			var bone := String(anim.track_get_path(t).get_concatenated_subnames())
			if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D: rot.append([bone, t])
			elif anim.track_get_type(t) == Animation.TYPE_POSITION_3D and bone == "pelvis": pos.append([bone, t])
		_clips[String(name)] = {"anim": anim, "rot": rot, "pos": pos, "length": anim.length,
			"loop": anim.loop_mode != Animation.LOOP_NONE, "contact": _contact(anim, rot)}
	player.free()

static func _contact(anim: Animation, rot: Array) -> float:
	# Istante del colpo: dove il braccio destro e il busto ruotano più in fretta.
	var tracks := []
	for row in rot:
		if row[0] in ["upperarm_r", "lowerarm_r", "spine_02", "spine_03"]: tracks.append(row[1])
	var best := anim.length * 0.5
	var fastest := 0.0
	var step := 1.0 / 60.0
	var t := step
	while t < anim.length - step:
		var speed := 0.0
		for track in tracks:
			speed += anim.rotation_track_interpolate(track, t).angle_to(anim.rotation_track_interpolate(track, t + step))
		if speed > fastest:
			fastest = speed
			best = t
		t += step
	return best

func play(name: String, blend: float = 0.25) -> void:
	if name == base: return
	prev = base
	prev_time = base_time
	base = name
	base_time = 0.0
	fade = 0.0 if prev != "" else 1.0
	fade_time = blend

func advance(delta: float, speed: float = 1.0) -> void:
	base_time += delta * speed
	prev_time += delta * speed
	fade = minf(1.0, fade + delta / maxf(fade_time, 0.001))

func apply_base() -> void:
	# Clip corrente a pieno corpo; durante la dissolvenza quella vecchia sfuma sopra.
	write(base, base_time, 1.0, false)
	if fade < 1.0 and prev != "": write(prev, prev_time, 1.0 - fade, false)

func finished() -> bool:
	var c := clip(base)
	return c.is_empty() or (not c.loop and base_time >= c.length)

func write(name: String, time: float, weight: float, upper_only: bool) -> void:
	var c := clip(name)
	if c.is_empty() or weight <= 0.001: return
	var anim: Animation = c.anim
	time = fposmod(time, c.length) if c.loop else clampf(time, 0.0, c.length)
	for row in c.rot:
		var i: int = ids.get(row[0], -1)
		if i < 0 or (upper_only and LOWER.has(row[0])): continue
		var q: Quaternion = anim.rotation_track_interpolate(row[1], time)
		if weight < 0.999: q = skeleton.get_bone_pose_rotation(i).slerp(q, weight)
		skeleton.set_bone_pose_rotation(i, q)
	if upper_only: return
	for row in c.pos:
		var i: int = ids.get(row[0], -1)
		if i < 0: continue
		var p: Vector3 = anim.position_track_interpolate(row[1], time)
		if weight < 0.999: p = skeleton.get_bone_pose_position(i).lerp(p, weight)
		skeleton.set_bone_pose_position(i, p)

func additive(name: String, time: float, bones: Array, weight: float = 1.0) -> void:
	# Solo il movimento della clip rispetto al suo primo fotogramma: respiro e sguardo
	# della clip di riposo sopra una posa seduta costruita a mano.
	var c := clip(name)
	if c.is_empty(): return
	var anim: Animation = c.anim
	time = fposmod(time, c.length) if c.loop else clampf(time, 0.0, c.length)
	for row in c.rot:
		if not row[0] in bones: continue
		var i: int = ids.get(row[0], -1)
		if i < 0: continue
		var delta_q: Quaternion = anim.rotation_track_interpolate(row[1], time) * anim.rotation_track_interpolate(row[1], 0.0).inverse()
		delta_q = delta_q.normalized()
		if delta_q.w < 0.0: delta_q = -delta_q
		var angle := delta_q.get_angle()
		if angle < 0.0001: continue
		# Il peso può superare 1 per accentuare un movimento troppo discreto.
		delta_q = Quaternion(delta_q.get_axis().normalized(), angle * weight)
		skeleton.set_bone_pose_rotation(i, delta_q * skeleton.get_bone_pose_rotation(i))
