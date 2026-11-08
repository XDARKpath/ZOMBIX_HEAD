extends RefCounted
# Braccia FPS (art/fp_arms/SM_FP_Arms.glb, generato da tools/fp_arms/build_fp_arms.py).
# IK a due ossa spalla-gomito-polso verso i socket dell'arma e impugnatura procedurale:
# ogni falange viene appoggiata sul cilindro del manico, quindi le dita seguono la
# geometria reale invece di una posa fissa e non entrano nella mesh né restano sospese.
#
# Convenzione dei socket (Socket_RightHand / Socket_LeftHand, Marker3D sull'arma):
#   origine = asse del manico sotto il centro del palmo
#   X = lungo il manico (pollice destro verso -X, pollice sinistro verso +X)
#   Y = direzione delle dita che escono dal palmo, Z = dorso della mano
#   meta "radius" = raggio del manico in metri (scala dell'arma applicata a parte)
#   meta "grip"   = profilo delle dita (vedi PROFILES)

const PALM := 0.0175        # dal centro dell'osso della mano alla superficie del palmo
const HANDLE_U := 0.072     # il manico passa sotto la base delle dita
const FINGER_HALF := 0.0085
const MAX_SHOULDER_SHIFT := 0.09
const FINGERS := ["index", "middle", "ring", "pinky"]
const DISTAL := {"index": 0.020, "middle": 0.021, "ring": 0.020, "pinky": 0.017}

# Pose del pollice (flessione e opposizione di thumb_01, flessione di 02 e 03) e
# sostituzioni per singolo dito. "wrap" indica se le dita si chiudono sul manico.
const PROFILES := {
	"power": {"wrap": true, "thumb_wrap": true, "thumb": [0.0, 0.45, 0.0, 0.0]},
	"pistol": {"wrap": true, "thumb_wrap": true, "thumb": [0.0, 0.40, 0.0, 0.0], "index_free": true},
	"clamp": {"wrap": true, "thumb": [0.05, 0.30, 0.0, 0.0]},
	"bezel": {"wrap": false, "curl": [0.02, 0.05, 0.03], "thumb": [-0.20, 0.50, -0.18, -0.21]},
	"relaxed": {"wrap": false, "curl": [0.32, 0.42, 0.28], "thumb": [0.20, 0.35, 0.20, 0.15]},
	"flat": {"wrap": false, "curl": [0.10, 0.14, 0.10], "thumb": [0.05, 0.15, 0.05, 0.05]},
	"open": {"wrap": false, "curl": [0.02, 0.05, 0.04], "thumb": [-0.15, -0.05, 0.0, 0.0]},
	"pinch": {"wrap": false, "curl": [0.55, 0.65, 0.35], "thumb": [0.35, 0.65, 0.35, 0.25]},
}

var skeleton: Skeleton3D
var ids := {}
var rest_local := {}        # Quaternion di riposo locali
var rest_pos := {}
var upper_len := {}
var lower_len := {}
var finger_geo := {}        # side -> finger -> [knuckle_u, [l1, l2, l3]]
# Stato richiesto per mano: chiavi target(Transform3D globale del polso), profile,
# radius, closure (0 aperta, 1 chiusa), pressure (0..1), trigger (0..1).
var hands := {"r": {}, "l": {}}


func setup(model: Node3D) -> void:
	for node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node
	for i in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(i)
		ids[n] = i
		rest_local[n] = skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		rest_pos[n] = skeleton.get_bone_rest(i).origin
	for side in ["r", "l"]:
		upper_len[side] = skeleton.get_bone_rest(ids["lowerarm_" + side]).origin.length()
		lower_len[side] = skeleton.get_bone_rest(ids["hand_" + side]).origin.length()
		finger_geo[side] = {}
		for f in FINGERS:
			var k: Vector3 = rest_pos["%s_01_%s" % [f, side]]
			finger_geo[side][f] = [k.y, [rest_pos["%s_02_%s" % [f, side]].y, rest_pos["%s_03_%s" % [f, side]].y, DISTAL[f]]]
		hands[side] = {"profile": "relaxed", "closure": 1.0, "pressure": 0.0, "trigger": 0.0, "radius": 0.02}


## Polso globale che mette il palmo sul manico descritto dal socket.
static func wrist_for_socket(socket: Transform3D, radius: float) -> Transform3D:
	var b := socket.basis.orthonormalized()
	return Transform3D(b, socket.origin - b * Vector3(0, HANDLE_U, -(PALM + radius)))


static func socket_radius(marker: Node3D) -> float:
	var r: float = marker.get_meta("radius", 0.018)
	return r * marker.global_basis.get_scale().x


func grip(side: String, marker: Node3D, closure: float = 1.0, pressure: float = 0.0, trigger: float = 0.0) -> void:
	var r := socket_radius(marker)
	hands[side] = {"target": wrist_for_socket(marker.global_transform, r), "radius": r,
		"profile": str(marker.get_meta("grip", "power")), "closure": closure, "pressure": pressure, "trigger": trigger}


func free_hand(side: String, wrist: Transform3D, profile: String = "relaxed") -> void:
	hands[side] = {"target": wrist, "radius": 0.02, "profile": profile, "closure": 1.0, "pressure": 0.0, "trigger": 0.0}


func blend_target(side: String, other: Transform3D, weight: float) -> void:
	if weight <= 0.0 or not hands[side].has("target"): return
	var t: Transform3D = hands[side]["target"]
	hands[side]["target"] = t.interpolate_with(other, clampf(weight, 0.0, 1.0))


func apply() -> void:
	if not skeleton: return
	var to_skel := skeleton.global_transform.affine_inverse()
	for side in ["r", "l"]:
		var h: Dictionary = hands[side]
		if not h.has("target"): continue
		_arm(side, to_skel * (h["target"] as Transform3D))
		_fingers(side, h)


# ----------------------------------------------------------------- braccio
func _frame(dir: Vector3, normal: Vector3) -> Basis:
	var y := dir.normalized()
	var x := (normal - y * normal.dot(y)).normalized()
	return Basis(x, y, x.cross(y))


func _arm(side: String, wrist: Transform3D) -> void:
	var s := 1.0 if side == "r" else -1.0
	var root_basis := skeleton.get_bone_global_rest(ids["root"]).basis
	var shoulder0: Vector3 = skeleton.get_bone_global_rest(ids["upperarm_" + side]).origin
	var elbow0: Vector3 = skeleton.get_bone_global_rest(ids["lowerarm_" + side]).origin
	var wrist0: Vector3 = skeleton.get_bone_global_rest(ids["hand_" + side]).origin
	var l1: float = upper_len[side]
	var l2: float = lower_len[side]
	var target := wrist.origin
	var shoulder := shoulder0
	var reach := l1 + l2 - 0.002
	var to_target := target - shoulder
	# Se il manico è fuori portata la spalla avanza (come una spinta del busto)
	# invece di lasciare la mano staccata dall'arma.
	if to_target.length() > reach:
		var shift := minf(to_target.length() - reach, MAX_SHOULDER_SHIFT)
		shoulder += to_target.normalized() * shift
		to_target = target - shoulder
	var d := clampf(to_target.length(), absf(l1 - l2) + 0.01, reach)
	var dir := to_target.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	# Gomito verso il basso e leggermente all'esterno.
	var pole := Vector3(0.55 * s, -0.80, 0.25)
	var bend := (pole - dir * pole.dot(dir)).normalized()
	var elbow := shoulder + dir * a + bend * h
	var wrist_pos := shoulder + dir * d
	var n0 := (elbow0 - shoulder0).cross(wrist0 - elbow0).normalized()
	var n1 := (elbow - shoulder).cross(wrist_pos - elbow).normalized()
	var upper_rest := skeleton.get_bone_global_rest(ids["upperarm_" + side]).basis
	var lower_rest := skeleton.get_bone_global_rest(ids["lowerarm_" + side]).basis
	var upper := _frame(elbow - shoulder, n1) * _frame(elbow0 - shoulder0, n0).inverse() * upper_rest
	var lower := _frame(wrist_pos - elbow, n1) * _frame(wrist0 - elbow0, n0).inverse() * lower_rest
	var hand := wrist.basis.orthonormalized()
	var ua := ids["upperarm_" + side] as int
	skeleton.set_bone_pose_position(ua, rest_pos["upperarm_" + side] + root_basis.inverse() * (shoulder - shoulder0))
	skeleton.set_bone_pose_rotation(ua, (root_basis.inverse() * upper).get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(ids["lowerarm_" + side], (upper.inverse() * lower).get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(ids["hand_" + side], (lower.inverse() * hand).get_rotation_quaternion())


# ----------------------------------------------------------------- dita
func _wrap(knuckle_u: float, lengths: Array, center: Vector2, radius: float) -> Array:
	# Piano della mano: x = avanti lungo il dorso, y = verso il palmo.
	var p := Vector2(knuckle_u, 0.0)
	var heading := 0.0
	var out := []
	for L in lengths:
		var q := _step(p, float(L), center, radius, heading)
		var absolute := atan2(q.y - p.y, q.x - p.x)
		var joint := clampf(wrapf(absolute - heading, -PI, PI), -0.15, 1.95)
		heading += joint
		out.append(joint)
		p += Vector2(cos(heading), sin(heading)) * float(L)
	return out


func _step(p: Vector2, L: float, c: Vector2, R: float, heading: float) -> Vector2:
	var to_c := c - p
	var dist := to_c.length()
	if dist > R + L - 0.0005:
		return p + to_c.normalized() * L
	if dist < absf(R - L) + 0.0005:
		return p + Vector2(cos(heading + 0.6), sin(heading + 0.6)) * L
	var a := (L * L - R * R + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(L * L - a * a, 0.0))
	var m := p + to_c * (a / dist)
	var perp := Vector2(-to_c.y, to_c.x) / dist
	var best := m + perp * h
	var best_progress := -INF
	for q in [m + perp * h, m - perp * h]:
		var from := p - c
		var to: Vector2 = q - c
		var progress := atan2(from.cross(to), from.dot(to))
		if progress > best_progress:
			best_progress = progress
			best = q
	return best


func _fingers(side: String, h: Dictionary) -> void:
	var profile: Dictionary = PROFILES.get(h["profile"], PROFILES["relaxed"])
	var relaxed: Array = PROFILES["relaxed"]["curl"]
	var closure: float = h["closure"]
	var squeeze: float = 1.0 + 0.07 * float(h["pressure"])
	var center := Vector2(HANDLE_U, PALM + float(h["radius"]))
	var wrap_radius := float(h["radius"]) + FINGER_HALF
	for f in FINGERS:
		var geo: Array = finger_geo[side][f]
		var angles: Array
		if profile["wrap"]:
			angles = _wrap(geo[0], geo[1], center, wrap_radius)
			for i in 3: angles[i] = float(angles[i]) * squeeze
		else:
			angles = (profile["curl"] as Array).duplicate()
			if f == "pinky" or f == "ring":
				for i in 3: angles[i] = float(angles[i]) * 1.12
		if f == "index" and profile.get("index_free", false):
			# Indice disteso lungo il ponticello; entra nel grilletto solo quando si spara.
			var t: float = h["trigger"]
			angles = [lerpf(0.06, 0.62, t), lerpf(0.04, 0.95, t), lerpf(0.02, 0.55, t)]
		for i in 3:
			var bone := "%s_%02d_%s" % [f, i + 1, side]
			var flex := lerpf(float(relaxed[i]), float(angles[i]), closure)
			skeleton.set_bone_pose_rotation(ids[bone], rest_local[bone] * Quaternion(Vector3.RIGHT, -flex))
	var thumb: Array = (profile["thumb"] as Array).duplicate()
	var s := 1.0 if side == "r" else -1.0
	if profile.get("thumb_wrap", false):
		# Il pollice si chiude sul manico nel proprio piano di flessione, dal lato opposto alle dita.
		var rest := skeleton.get_bone_rest(ids["thumb_01_" + side])
		var frame := Transform3D(rest.basis * Basis(Vector3.BACK, -float(thumb[1]) * s), rest.origin)
		var c := frame.affine_inverse() * Vector3(0, HANDLE_U, -(PALM + float(h["radius"])))
		var lengths := [rest_pos["thumb_02_" + side].length(), rest_pos["thumb_03_" + side].length(), 0.023]
		var a := _wrap(0.0, lengths, Vector2(c.y, -c.z), float(h["radius"]) + FINGER_HALF + 0.001)
		thumb[0] = a[0]
		thumb[2] = a[1]
		thumb[3] = a[2]
	var thumb_relaxed: Array = PROFILES["relaxed"]["thumb"]
	var t := []
	for i in 4: t.append(lerpf(float(thumb_relaxed[i]), float(thumb[i]), closure))
	skeleton.set_bone_pose_rotation(ids["thumb_01_" + side], rest_local["thumb_01_" + side] * Quaternion(Vector3.BACK, -t[1] * s) * Quaternion(Vector3.RIGHT, -t[0]))
	skeleton.set_bone_pose_rotation(ids["thumb_02_" + side], rest_local["thumb_02_" + side] * Quaternion(Vector3.RIGHT, -t[2]))
	skeleton.set_bone_pose_rotation(ids["thumb_03_" + side], rest_local["thumb_03_" + side] * Quaternion(Vector3.RIGHT, -t[3]))
