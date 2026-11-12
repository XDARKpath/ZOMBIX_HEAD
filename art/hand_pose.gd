extends RefCounted
# Braccia e mani credibili sul rig ZX a 65 ossa: IK analitica spalla-gomito-polso,
# prese con le dita vere (sigaretta tra indice e medio, impugnatura della pistola)
# e oggetti piazzati sulle falangi. Tutto è nello spazio dello scheletro (+Z avanti, +Y su).

const DIGITS := ["index", "middle", "ring", "pinky"]
# Curvature (MCP, PIP, DIP) per presa.
const GRIPS := {
	# Come nella foto di riferimento: indice e medio quasi dritti, anulare e mignolo chiusi morbidi.
	"cigarette": {"index": [0.12, 0.16, 0.08], "middle": [0.15, 0.2, 0.1], "ring": [0.55, 0.8, 0.5], "pinky": [0.65, 0.9, 0.55], "thumb": [0.1, 0.15, 0.1], "spread": 0.08},
	"pistol": {"index": [0.32, 0.12, 0.08], "middle": [1.15, 1.3, 0.75], "ring": [1.2, 1.32, 0.75], "pinky": [1.25, 1.3, 0.7], "thumb": [0.45, 0.4, 0.3], "spread": 0.0},
	"relaxed": {"index": [0.25, 0.35, 0.2], "middle": [0.32, 0.42, 0.25], "ring": [0.4, 0.5, 0.3], "pinky": [0.48, 0.55, 0.32], "thumb": [0.15, 0.2, 0.15], "spread": 0.03},
}

## Base ortonormale dal primo asse e da un secondo vettore (ortogonalizzato).
static func frame(a: Vector3, b: Vector3) -> Basis:
	var x := a.normalized()
	var y := (b - x * b.dot(x)).normalized()
	return Basis(x, y, x.cross(y))

## Rotazione che porta la coppia (a0, b0) su (a1, b1).
static func align(a0: Vector3, b0: Vector3, a1: Vector3, b1: Vector3) -> Basis:
	return frame(a1, b1) * frame(a0, b0).transposed()

static func _rest(skel: Skeleton3D, id: int) -> Transform3D:
	var t := skel.get_bone_global_rest(id)
	return Transform3D(t.basis.orthonormalized(), t.origin)

static func _pose(skel: Skeleton3D, id: int) -> Transform3D:
	var t := skel.get_bone_global_pose(id)
	return Transform3D(t.basis.orthonormalized(), t.origin)

static func _set_global(skel: Skeleton3D, id: int, parent_basis: Basis, global_basis: Basis) -> void:
	skel.set_bone_pose_rotation(id, (parent_basis.inverse() * global_basis).get_rotation_quaternion())

## Bocca: offset dall'osso della testa nello spazio di riposo, seguendo la testa in posa.
const MOUTH := Vector3(0.0, 0.07, 0.11)
static func mouth(skel: Skeleton3D, ids: Dictionary) -> Vector3:
	var head := _pose(skel, ids["head"])
	return head.origin + head_turn(skel, ids) * MOUTH

## Rotazione della testa rispetto al riposo (per orientare la mano verso il viso).
static func head_turn(skel: Skeleton3D, ids: Dictionary) -> Basis:
	return _pose(skel, ids["head"]).basis * _rest(skel, ids["head"]).basis.inverse()

static func shoulder(skel: Skeleton3D, ids: Dictionary, side: String) -> Vector3:
	skel.force_update_all_bone_transforms()
	return _pose(skel, ids["upperarm_" + side]).origin

## Normale del palmo nello spazio dello scheletro (verso dove si chiudono le dita).
static func palm_normal(skel: Skeleton3D, ids: Dictionary, side: String) -> Vector3:
	var hand := _pose(skel, ids["hand_" + side])
	var rest := _rest(skel, ids["hand_" + side])
	return (hand.basis * rest.basis.inverse() * _rest_palm(skel, ids, side)).normalized()

static func _rest_fingers(skel: Skeleton3D, ids: Dictionary, side: String) -> Vector3:
	return (_rest(skel, ids["middle_01_" + side]).origin - _rest(skel, ids["hand_" + side]).origin).normalized()

static func _rest_palm(skel: Skeleton3D, ids: Dictionary, side: String) -> Vector3:
	# Sui rig ZX (posa a T con i palmi in giù, pollice avanti) il palmo è -Z locale delle falangi:
	# la curvatura negativa attorno a X le chiude lì, come in tool_rig.gd.
	var fingers := _rest_fingers(skel, ids, side)
	var palm := _rest(skel, ids["middle_01_" + side]).basis * Vector3.FORWARD
	return (palm - fingers * palm.dot(fingers)).normalized()

## Polso in `wrist`, dita verso `fingers`, palmo verso `palm`, gomito dalla parte di `pole`.
static func reach(skel: Skeleton3D, ids: Dictionary, side: String, wrist: Vector3, fingers: Vector3, palm: Vector3, pole: Vector3) -> void:
	var up_id: int = ids["upperarm_" + side]
	var lo_id: int = ids["lowerarm_" + side]
	var ha_id: int = ids["hand_" + side]
	skel.force_update_all_bone_transforms()
	var parent := _pose(skel, skel.get_bone_parent(up_id))
	var start := _pose(skel, up_id).origin
	var r_up := _rest(skel, up_id)
	var r_lo := _rest(skel, lo_id)
	var r_ha := _rest(skel, ha_id)
	var l1 := r_up.origin.distance_to(r_lo.origin)
	var l2 := r_lo.origin.distance_to(r_ha.origin)
	var to := wrist - start
	var d := clampf(to.length(), absf(l1 - l2) + 0.002, l1 + l2 - 0.002)
	var dir := to.normalized()
	var bend := pole - start
	bend = bend - dir * bend.dot(dir)
	bend = bend.normalized() if bend.length() > 0.0001 else Vector3.DOWN
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var elbow := start + dir * a + bend * sqrt(maxf(l1 * l1 - a * a, 0.0))
	var hand_at := start + dir * d
	var u := (elbow - start).normalized()
	var w := (hand_at - elbow).normalized()
	var f := w - u * w.dot(u)
	f = f.normalized() if f.length() > 0.0001 else -bend
	var hinge := u.cross(f).normalized()
	# A riposo (a T) il gomito si flette in avanti (+Z): stesso cardine dopo la rotazione.
	var ax_up := (r_lo.origin - r_up.origin).normalized()
	var ax_lo := (r_ha.origin - r_lo.origin).normalized()
	var g_up := align(ax_up, Vector3.BACK, u, f) * r_up.basis
	var g_lo := align(ax_lo, Vector3.BACK, w, hinge.cross(w)) * r_lo.basis
	var g_ha := align(_rest_fingers(skel, ids, side), _rest_palm(skel, ids, side), fingers, palm) * r_ha.basis
	_set_global(skel, up_id, parent.basis, g_up)
	_set_global(skel, lo_id, g_up, g_lo)
	_set_global(skel, ha_id, g_lo, g_ha)
	skel.force_update_all_bone_transforms()

## Solo spalla e gomito: il polso va in `wrist`, la mano resta ferma sull'avambraccio
## (rotazione locale di riposo). `twist` ruota l'avambraccio sul suo asse (prono-supinazione).
static func reach_arm(skel: Skeleton3D, ids: Dictionary, side: String, wrist: Vector3, pole: Vector3, twist: float) -> void:
	var up_id: int = ids["upperarm_" + side]
	var lo_id: int = ids["lowerarm_" + side]
	skel.force_update_all_bone_transforms()
	var parent := _pose(skel, skel.get_bone_parent(up_id))
	var start := _pose(skel, up_id).origin
	var r_up := _rest(skel, up_id)
	var r_lo := _rest(skel, lo_id)
	var r_ha := _rest(skel, ids["hand_" + side])
	var l1 := r_up.origin.distance_to(r_lo.origin)
	var l2 := r_lo.origin.distance_to(r_ha.origin)
	var to := wrist - start
	var d := clampf(to.length(), absf(l1 - l2) + 0.002, l1 + l2 - 0.002)
	var dir := to.normalized()
	var bend := pole - start
	bend = bend - dir * bend.dot(dir)
	bend = bend.normalized() if bend.length() > 0.0001 else Vector3.DOWN
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var elbow := start + dir * a + bend * sqrt(maxf(l1 * l1 - a * a, 0.0))
	var u := (elbow - start).normalized()
	var w := (start + dir * d - elbow).normalized()
	var f := w - u * w.dot(u)
	f = f.normalized() if f.length() > 0.0001 else -bend
	var hinge := u.cross(f).normalized()
	var ax_up := (r_lo.origin - r_up.origin).normalized()
	var ax_lo := (r_ha.origin - r_lo.origin).normalized()
	var g_up := align(ax_up, Vector3.BACK, u, f) * r_up.basis
	var g_lo := Basis(w, twist) * align(ax_lo, Vector3.BACK, w, hinge.cross(w)) * r_lo.basis
	_set_global(skel, up_id, parent.basis, g_up)
	_set_global(skel, lo_id, g_up, g_lo)
	skel.set_bone_pose_rotation(ids["hand_" + side], skel.get_bone_rest(ids["hand_" + side]).basis.get_rotation_quaternion())
	skel.force_update_all_bone_transforms()

## Polso che porta il filtro su `mouth` muovendo solo il braccio (mano ferma sull'avambraccio).
static func wrist_to_mouth(skel: Skeleton3D, ids: Dictionary, side: String, mouth: Vector3, pole: Vector3, twist: float) -> Vector3:
	var hand := _pose(skel, ids["hand_" + side])
	var local := hand.basis.inverse() * (filter_tip(skel, ids, side) - hand.origin)
	var wrist := mouth
	# Poche iterazioni: l'orientamento della mano dipende da dove arriva l'avambraccio.
	for i in range(5):
		reach_arm(skel, ids, side, wrist, pole, twist)
		wrist = mouth - _pose(skel, ids["hand_" + side]).basis * local
	return wrist

## Boccata del fumatore del menu (destra): mano ferma sull'avambraccio, braccio lungo il
## fianco che sale finché il filtro arriva alle labbra. `sip` va da 0 (giù) a 1 (alla bocca).
## Il gomito può stare più o meno all'esterno: serve agli NPC seduti, dove un gomito
## arretrato attraversa il busto mentre la mano raggiunge la bocca.
static func smoke_arm(skel: Skeleton3D, ids: Dictionary, sip: float, breath: float, pole_out: float = 0.45, pole_forward: float = -0.4) -> void:
	grip(skel, ids, "r", "cigarette", breath)
	var right := shoulder(skel, ids, "r")
	var pole := right + Vector3(-pole_out, -1, pole_forward)
	var up_wrist := wrist_to_mouth(skel, ids, "r", mouth(skel, ids), pole, 0.0)
	# Anche il punto di partenza resta un po' più largo del fianco.
	reach_arm(skel, ids, "r", (right + Vector3(-0.18, -0.45, 0.14)).lerp(up_wrist, sip), pole, 0.0)

## Ciclo di 14 s del menu: sale tra 1 e 2,8 s, resta alla bocca, scende tra 5 e 6,8 s.
static func sip_at(time: float) -> float:
	var cycle := fposmod(time, 14.0)
	return smoothstep(1.0, 2.8, cycle) * (1.0 - smoothstep(5.0, 6.8, cycle))

## Dita nella presa indicata; `breath` aggiunge un movimento minimo.
static func grip(skel: Skeleton3D, ids: Dictionary, side: String, kind: String, breath: float = 0.0) -> void:
	var g: Dictionary = GRIPS[kind]
	for digit in DIGITS + ["thumb"]:
		var curls: Array = g[digit]
		for joint in range(1, 4):
			var id: int = ids.get("%s_0%d_%s" % [digit, joint, side], -1)
			if id < 0: continue
			var rest := skel.get_bone_rest(id).basis
			var turn := Basis(Vector3.RIGHT, -(curls[joint - 1] + breath * 0.03 * joint))
			if joint == 1 and digit in ["index", "middle"] and g["spread"] > 0.0:
				# Indice e medio si aprono a V per tenere la sigaretta.
				turn = _spread(skel, ids, side, digit, g["spread"]) * turn
			skel.set_bone_pose_rotation(id, (rest * turn).get_rotation_quaternion())
	skel.force_update_all_bone_transforms()

static func _spread(skel: Skeleton3D, ids: Dictionary, side: String, digit: String, amount: float) -> Basis:
	var me := _rest(skel, ids[digit + "_01_" + side])
	var other := _rest(skel, ids[("middle" if digit == "index" else "index") + "_01_" + side])
	var away := me.basis.inverse() * (me.origin - other.origin)
	# Rotazione attorno a Z: la punta (+Y) va verso -X per angoli positivi.
	return Basis(Vector3.BACK, -signf(away.x) * amount)

static func _joint(skel: Skeleton3D, ids: Dictionary, bone: String) -> Vector3:
	return _pose(skel, ids[bone]).origin

## Trasformazione (spazio scheletro) della sigaretta stretta tra indice e medio:
## filtro sul lato del palmo, brace sul dorso.
static func cigarette_frame(skel: Skeleton3D, ids: Dictionary, side: String) -> Transform3D:
	var s := "_" + side
	var i1 := _joint(skel, ids, "index_01" + s)
	var i2 := _joint(skel, ids, "index_02" + s)
	var m1 := _joint(skel, ids, "middle_01" + s)
	var m2 := _joint(skel, ids, "middle_02" + s)
	var pinch := (i1.lerp(i2, 0.72) + m1.lerp(m2, 0.72)) * 0.5
	var n := palm_normal(skel, ids, side)
	var along := ((i2 - i1) + (m2 - m1)).normalized()
	var z := -n
	var y := (along - z * along.dot(z)).normalized()
	# Il filtro (z = -0.0475) sporge di circa 3 cm sul lato del palmo.
	return Transform3D(Basis(y.cross(z), y, z), pinch + n * (0.03 - 0.0475))

## Punta del filtro (spazio scheletro).
static func filter_tip(skel: Skeleton3D, ids: Dictionary, side: String) -> Vector3:
	var t := cigarette_frame(skel, ids, side)
	return t * Vector3(0, 0, -0.0475)

## Polso che porta il filtro su `mouth` con la mano orientata come richiesto.
static func wrist_for_tip(skel: Skeleton3D, ids: Dictionary, side: String, mouth: Vector3, fingers: Vector3, palm: Vector3) -> Vector3:
	# L'offset del filtro nel frame della mano non dipende dal braccio: lo misuro adesso.
	var hand := _pose(skel, ids["hand_" + side])
	var local := hand.basis.inverse() * (filter_tip(skel, ids, side) - hand.origin)
	var r_ha := _rest(skel, ids["hand_" + side])
	var target := align(_rest_fingers(skel, ids, side), _rest_palm(skel, ids, side), fingers, palm) * r_ha.basis
	return mouth - target * local

## Pistola nel pugno: impugnatura nel tunnel di medio, anulare e mignolo, canna lungo l'avambraccio.
## `grip_center` e `grip_axis` sono nello spazio dell'arma (+X canna, +Y carrello).
static func pistol_frame(skel: Skeleton3D, ids: Dictionary, side: String, grip_center: Vector3, grip_axis: Vector3) -> Transform3D:
	var s := "_" + side
	var hand := _pose(skel, ids["hand" + s])
	var n := palm_normal(skel, ids, side)
	var knuckles := _joint(skel, ids, "index_01" + s) - _joint(skel, ids, "pinky_01" + s)
	var forearm := (hand.origin - _joint(skel, ids, "lowerarm" + s)).normalized()
	var basis := align(-grip_axis, Vector3.RIGHT, knuckles, forearm)
	var tunnel := Vector3.ZERO
	for digit in ["middle", "ring", "pinky"]:
		tunnel += _joint(skel, ids, digit + "_01" + s).lerp(_joint(skel, ids, digit + "_02" + s), 0.35)
	tunnel = tunnel / 3.0 + n * 0.022
	return Transform3D(basis, tunnel - basis * grip_center)
