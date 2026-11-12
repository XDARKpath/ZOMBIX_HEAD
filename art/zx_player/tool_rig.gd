extends SkeletonModifier3D
# Chi ti vede da fuori: dopo le clip del corpo, l'arma va dove dice ToolMotion, le mani la impugnano e weapon_anchor
# segue la mano destra. Le altre armi non hanno un movimento proprio: restano nella mano che porta la clip.

const ToolMotion := preload("res://player/tool_motion.gd")
const ArmIk := preload("res://player/arm_ik.gd")
const HOLD_Y := 1.47                    # dove finisce l'origine della camera sullo scheletro
const HOLD_Z := 0.05
const Z_SCALE := 0.85
## Stessi numeri dei colpi della prima persona (fotogrammi a 30 fps: carica, fine colpo, fine clip).
const COMBO := [["A", 8, 11, 37], ["B", 12, 14, 31], ["C", 9, 13, 24]]
const HEAVY := ["H", 0, 5, 23]
const POWER := {"index": [1.05, 1.2, 0.7], "middle": [1.15, 1.3, 0.75], "ring": [1.2, 1.32, 0.75], "pinky": [1.25, 1.3, 0.7], "thumb": [0.5, 0.45, 0.3]}
const PISTOL := {"index": [0.32, 0.12, 0.08], "middle": [1.15, 1.3, 0.75], "ring": [1.2, 1.32, 0.75], "pinky": [1.25, 1.3, 0.7], "thumb": [0.45, 0.4, 0.3]}

const RELAXED := {"index": [0.25, 0.35, 0.2], "middle": [0.32, 0.42, 0.25], "ring": [0.4, 0.5, 0.3], "pinky": [0.48, 0.55, 0.32], "thumb": [0.15, 0.2, 0.15]}
const RELAXED_LEFT := Vector3(0.30, 0.98, 0.10)
## Da fuori le armi lunghe vanno alla spalla destra (+X è la sinistra del personaggio), un poco più in basso.
const LONG_GUN_SHIFT := Vector3(-0.08, -0.05, 0.04)
const ROLL := {"index": [0.5, 0.65, 0.4], "middle": [0.6, 0.7, 0.45], "ring": [0.65, 0.75, 0.45], "pinky": [0.7, 0.75, 0.45], "thumb": [0.35, 0.3, 0.2]}
## Altre armi: canna o lama lungo le dita piegate di 90 gradi, in alto il dorso (asse +Z dell'arma).
const OTHER_GRIP := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
const ARM_REACH := 0.55
## Arco (non è in ToolMotion): nella sinistra. A riposo lungo il fianco; tendendo sale davanti alla spalla e la destra
## aggancia la corda. Spazio dello scheletro (+X sinistra del personaggio, +Z avanti). Il modello ha la corda a +Z.
const BOW_LOW := Vector3(0.26, 0.96, 0.10)
const BOW_HIGH := Vector3(0.08, 1.40, 0.56)
const BOW_GRIP := {"c": Vector3(0, 0, -0.075), "t": Vector3(0, 1, 0)}
const BOW_DRAW_LEN := 0.05                 # la corda del modello è rigida: la destra resta sulla corda, non a mezz'aria
const BANDAGE_SECONDS := 2.6
const BANDAGE_TURNS := 3.0
const OFFER_SECONDS := 1.3

var motion := ToolMotion.new()
var kind := ""
var enabled := true
var guard := false
var sprint := false
var aim := false
var charge := 0.0
var weapon: Node3D
var _bow := false
var _bow_w := 0.0
var _parts := {}
var loaded := true                       # c'è un dardo sulla balestra (lo dice zx_avatar_driver)
var _swing := []
var _swing_t := 0.0
var _combo := 0
## Spento il rig, rilassa comunque le dita (no da morto, in auto o mentre ripara: lì le mani hanno la loro clip).
var relax_free := true
var _left_w := 1.0
var _reload := -1.0
var _reload_len := 1.6
var _ids := {}
var _spine := -1
var _anchor := -1
var _neck := -1
var _head_bone := -1
var look_pitch := 0.0
var _pause := 0.0
var _hold := Transform3D.IDENTITY
var _has_hold := false
var _care := ""
var _care_t := 0.0
var _care_w := 0.0
var _care_look := 0.0
## Il corpo accompagna il colpo: torsione delle spalle (rad, + = verso destra) e piegamento in avanti.
var _twist := 0.0
var _bend := 0.0
var _spines: Array[int] = []
## Per colpo: [torsione in carica, torsione a fine colpo, piegamento a fine colpo].
const BODY := {"A": [0.55, -0.45, 0.22], "B": [-0.5, 0.45, 0.12], "C": [0.12, -0.1, 0.42], "H": [0.35, -0.3, 0.5]}


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null: return
	for b in ["upperarm", "lowerarm", "hand"]:
		for s in ["r", "l"]: _ids[b + "_" + s] = sk.find_bone(b + "_" + s)
	_spine = sk.find_bone("spine_03")
	for b in ["spine_01", "spine_02", "spine_03"]:
		var id := sk.find_bone(b)
		if id >= 0: _spines.append(id)
	_anchor = sk.find_bone("weapon_anchor")
	_neck = sk.find_bone("neck_01")
	_head_bone = sk.find_bone("head")


func set_weapon(id: String, item: Node3D) -> void:
	weapon = item
	kind = id if ToolMotion.handles(id) else ""
	_swing = []
	_reload = -1.0
	_parts = {}
	_bow = id == "bow" and item != null
	if _bow: item.transform = Transform3D.IDENTITY     # niente SOCKET_BASIS: l'arco lo mette _bow_pose
	if kind == "": return
	motion.outside = true
	motion.setup(kind)
	if item:
		motion.place_item(item)
		_parts = ToolMotion.find_parts(item, kind)


func swing(heavy: bool) -> void:
	if kind == "" or motion.is_gun(): return
	var row: Array = HEAVY if heavy else COMBO[_combo % COMBO.size()]
	if not heavy: _combo += 1
	_swing = row
	_swing_t = 0.0


func shot() -> void:
	if kind != "" and motion.is_gun(): motion.shot(aim)


## La ricarica vista da fuori segue quella vera del giocatore (frazione 0-1, -1 ferma), non un timer suo:
## dura quanto la sua, si ferma quando lui la interrompe e sta al passo anche per chi arriva a metà.
func set_reload(fraction: float, total: float) -> void:
	_reload = fraction if kind != "" and motion.is_gun() else -1.0
	_reload_len = total


func _process(delta: float) -> void:
	_pause = maxf(0.0, _pause - delta)
	if _care != "":
		_care_t += delta
		var length: float = BANDAGE_SECONDS if _care == "bandage" else OFFER_SECONDS
		if _care_t >= length: _care = ""
	var want: float = 1.0 if _care != "" and _care_t < (BANDAGE_SECONDS if _care == "bandage" else OFFER_SECONDS) - 0.3 else 0.0
	_care_w = move_toward(_care_w, want, delta / 0.28)
	_bow_w = move_toward(_bow_w, 1.0 if _bow and charge > 0.0 else 0.0, delta / 0.25)
	if kind == "": return
	var row := []
	if not _swing.is_empty():
		_swing_t += delta
		var w: float = _swing[1] / 30.0
		var a: float = (_swing[2] - _swing[1]) / 30.0
		var r: float = (_swing[3] - _swing[2]) / 30.0
		if _swing_t >= w + a + r: _swing = []
		else: row = [_swing[0], _swing_t, w, a, r]
	motion.reload_total = _reload_len
	# I colpi leggeri sono a una mano: la sinistra lascia il manico e torna appena il colpo è finito.
	var one_hand: bool = motion.grip("l").is_empty() or (motion.kind == "axe" and not row.is_empty() and row[0] != "H" and _swing_t < float(row[2]) + float(row[3]) + 0.25)
	_left_w = move_toward(_left_w, 0.0 if one_hand else 1.0, delta / (0.07 if one_hand else 0.2))
	motion.tick(delta, row, charge, guard, sprint, aim, _reload, -1.0)
	_body_follow(row, delta)
	motion.pose_parts(_parts, 0.0, loaded)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _ids.is_empty(): return
	# Mani libere (arma nel fodero, mani vuote): le clip le chiudono a pugno storto e da fuori sembrano spezzate.
	if not enabled:
		if relax_free:
			_relax(sk, "l")
			_relax(sk, "r")
		return
	_twist_spine(sk)
	# Il busto porta con sé le mani: l'arma gira con il petto della clip.
	var chest := sk.get_bone_global_pose(_spine)
	var rest := sk.get_bone_global_rest(_spine)
	var turn := chest.basis.orthonormalized() * rest.basis.orthonormalized().inverse()
	_care_pose(sk, chest, rest, turn)
	_head(sk, turn)
	_keep_item(sk)
	if _bow and _pause <= 0.0 and _care_w <= 0.01:
		_bow_pose(sk, chest, rest, turn)
		return
	if (kind == "" or weapon == null) and _pause <= 0.0 and _care_w <= 0.01:
		_relax(sk, "l")
		_relax(sk, "r")
	if kind == "" or weapon == null or _pause > 0.0 or _care_w > 0.99: return
	var f: Transform3D = motion.frame()
	var flip := Basis(Vector3.UP, PI)
	var local := Vector3(-f.origin.x, HOLD_Y + f.origin.y, HOLD_Z - f.origin.z * Z_SCALE)
	if motion.is_gun() and kind != "pistol":
		local += LONG_GUN_SHIFT          # calcio sulla spalla destra: la sinistra arriva al paramano senza torcere il polso
	var w := Transform3D(turn * flip * f.basis, rest.origin + turn * (local - rest.origin) + (chest.origin - rest.origin))
	var up := turn * Vector3.UP
	# Come in prima persona: se la sinistra non arriva al suo appoggio è l'arma che arretra lungo la canna, non la mano.
	var left_row: Dictionary = motion.grip("l")
	if motion.is_gun() and not left_row.is_empty():
		var shoulder: Vector3 = sk.get_bone_global_pose(_ids["upperarm_l"]).origin
		var barrel: Vector3 = (w.basis * Vector3.UP).normalized()
		for i in 3:
			var hand: Array = _fist(sk, "l", w, left_row, motion.left_shift, up, 99.0)
			var over: float = ((hand[0] as Vector3) - shoulder).length() - (ARM_REACH - 0.01)
			if over <= 0.0: break
			w.origin -= barrel * over
	if _left_w < 1.0:
		# Mano libera: lungo il fianco, segue il busto ma non vola via con la clip.
		# Durante il colpo a una mano la sinistra si apre per bilanciare, dalla parte opposta all'ascia.
		var balance := clampf(absf(_twist) / 0.5, 0.0, 1.0)
		var free_at := RELAXED_LEFT.lerp(Vector3(0.40, 1.04, 0.26), balance)
		var at := rest.origin + turn * (free_at - rest.origin) + (chest.origin - rest.origin)
		_reach(sk, "l", at, turn * Vector3(0, -1, 0.15), turn * Vector3(-1, 0, 0), Vector3(0.6, -0.6, -0.5), 1.0)
	var left_grip: Dictionary = motion.grip("l")
	if not left_grip.is_empty():
		var left: Array = _fist(sk, "l", w, left_grip, motion.left_shift, up)
		# Col fucile il gomito sinistro sta in fuori e in basso, sotto il paramano: l'avambraccio non taglia il petto.
		var pole := Vector3(1.0, -0.8, 0.35) if motion.is_gun() and kind != "pistol" else Vector3(0.45, -1.0, -0.1)
		_reach(sk, "l", left[0], left[1], left[2], pole, _left_w)
	var right: Array = _fist(sk, "r", w, motion.grip("r"), Vector3.ZERO, up)
	_reach(sk, "r", right[0], right[1], right[2], Vector3(-0.45, -1.0, -0.1), 1.0)
	_fingers(sk, "r", PISTOL if motion.is_gun() else POWER)
	_fingers(sk, "l", POWER if _left_w > 0.5 else RELAXED)
	# L'arma resta nella mano anche se il braccio non arriva fino al punto voluto.
	var wanted := _hand_basis(sk, "r", right[1], right[2])
	var real := sk.get_bone_global_pose(_ids["hand_r"])
	var hold := Transform3D(wanted, right[0]).affine_inverse() * w
	_hold = hold
	_has_hold = true
	var final := Transform3D(real.basis.orthonormalized(), real.origin) * hold
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(_anchor))
	var inside := parent.affine_inverse() * final
	sk.set_bone_pose_position(_anchor, inside.origin)
	sk.set_bone_pose_rotation(_anchor, inside.basis.get_rotation_quaternion())


## Dove deve stare il corpo in questo istante del colpo: carica (spalle indietro), colpo (gira e si piega), recupero (torna dritto).
func _body_follow(row: Array, delta: float) -> void:
	var want_twist := 0.0
	var want_bend := 0.0
	if not row.is_empty() and BODY.has(row[0]):
		var body: Array = BODY[row[0]]
		var t: float = row[1]
		var wind: float = maxf(row[2], 0.001)
		var hit: float = wind + float(row[3]) * 0.5
		var out: float = hit + 0.13
		var end: float = wind + float(row[3]) + float(row[4])
		if t < wind:
			var k := smoothstep(0.0, 1.0, t / wind)
			want_twist = body[0] * k
			want_bend = -0.08 * k                                 # in carica si tira un poco indietro
		elif t < out:
			var k := pow((t - wind) / (out - wind), 1.4)           # accelera fino al contatto, come l'arma
			want_twist = lerpf(body[0], body[1], k)
			want_bend = lerpf(-0.08, body[2], k)
		else:
			var k := smoothstep(0.0, 1.0, (t - out) / maxf(end - out, 0.001))
			want_twist = lerpf(body[1], 0.0, k)
			want_bend = lerpf(body[2], 0.0, k)
	# Segue in fretta durante il colpo, torna con calma a riposo.
	var speed := 22.0 if not row.is_empty() else 7.0
	_twist = lerpf(_twist, want_twist, 1.0 - exp(-speed * delta))
	_bend = lerpf(_bend, want_bend, 1.0 - exp(-speed * delta))


## Torsione e piegamento divisi sulle tre vertebre, sopra la clip del corpo.
func _twist_spine(sk: Skeleton3D) -> void:
	if _spines.is_empty() or (absf(_twist) < 0.002 and absf(_bend) < 0.002): return
	var share := 1.0 / float(_spines.size())
	var extra := Basis(Vector3.UP, -_twist * share) * Basis(Vector3.RIGHT, _bend * share)
	for id in _spines:
		var parent := sk.get_bone_global_pose(sk.get_bone_parent(id)).basis.orthonormalized()
		var now := sk.get_bone_global_pose(id).basis.orthonormalized()
		sk.set_bone_pose_rotation(id, (parent.inverse() * extra * now).get_rotation_quaternion())


## Fuori dalla presa (clip, cure, altre armi) l'arma resta comunque nella mano.
func _keep_item(sk: Skeleton3D) -> void:
	if _anchor < 0: return
	var hand := sk.get_bone_global_pose(_ids["hand_r"])
	var inside: Transform3D
	if kind != "" and _has_hold and (_pause > 0.0 or _care_w > 0.99):
		inside = sk.get_bone_global_pose(sk.get_bone_parent(_anchor)).affine_inverse() * Transform3D(hand.basis.orthonormalized(), hand.origin) * _hold
	elif kind == "":
		# Armi senza movimento proprio: manico nel pugno, canna o lama lungo le nocche.
		var w := Transform3D(hand.basis.orthonormalized() * OTHER_GRIP, hand.origin + (hand.basis.orthonormalized() * Vector3.UP) * 0.09)
		inside = sk.get_bone_global_pose(sk.get_bone_parent(_anchor)).affine_inverse() * w
	else:
		return
	sk.set_bone_pose_position(_anchor, inside.origin)
	sk.set_bone_pose_rotation(_anchor, inside.basis.get_rotation_quaternion())


## Arco nella sinistra, la destra sulla corda mentre tende. weapon_anchor segue la mano sinistra vera.
func _bow_pose(sk: Skeleton3D, chest: Transform3D, rest: Transform3D, turn: Basis) -> void:
	var k := smoothstep(0.0, 1.0, _bow_w)
	var at := BOW_LOW.lerp(BOW_HIGH, k)
	# A riposo la punta va un poco avanti; teso è dritto, appena inclinato verso destra come chi tira d'istinto.
	var tilt := Basis(Vector3.RIGHT, 0.3 * (1.0 - k)) * Basis(Vector3.BACK, 0.18 * k)
	var w := Transform3D(turn * tilt * Basis(Vector3.UP, PI), rest.origin + turn * (at - rest.origin) + (chest.origin - rest.origin))
	var left: Array = ToolMotion.fist_for(w, BOW_GRIP, "l", sk.get_bone_global_pose(_ids["upperarm_l"]).origin, turn * Vector3.UP, 0.095, 0.035, 2.0, Vector3.ZERO, 0.0)
	_reach(sk, "l", left[0], left[1], left[2], Vector3(0.6, -1.0, -0.2), 1.0)
	_fingers(sk, "l", POWER)
	if k > 0.05:
		var nock: Vector3 = w * Vector3(0, 0, 0.095 + BOW_DRAW_LEN * charge)
		var fingers: Vector3 = (w.origin - nock).normalized()
		var palm: Vector3 = turn * Vector3.RIGHT
		_reach(sk, "r", nock - fingers * 0.085 - turn * Vector3.RIGHT * 0.03, fingers, palm, Vector3(-1.0, 0.1, -0.6), k)
		_fingers(sk, "r", ROLL)
	else:
		_relax(sk, "r")
	var real := sk.get_bone_global_pose(_ids["hand_l"])
	var final := Transform3D(real.basis.orthonormalized(), real.origin) * (Transform3D(_hand_basis(sk, "l", left[1], left[2]), left[0]).affine_inverse() * w)
	var inside := sk.get_bone_global_pose(sk.get_bone_parent(_anchor)).affine_inverse() * final
	sk.set_bone_pose_position(_anchor, inside.origin)
	sk.set_bone_pose_rotation(_anchor, inside.basis.get_rotation_quaternion())


## La testa non scatta con la clip: guarda dritto davanti (o dove mira il giocatore), con un resto di vita dalla clip.
## Quando il busto si piega molto, o il corpo è per terra, la testa torna a seguire il corpo.
func _head(sk: Skeleton3D, turn: Basis) -> void:
	if _neck < 0 or _head_bone < 0: return
	var chest_up := turn * Vector3.UP
	var weight := 0.82 * smoothstep(0.55, 0.92, chest_up.dot(Vector3.UP))
	if weight <= 0.0: return
	var ahead := turn * Vector3.BACK
	ahead.y = 0.0
	if ahead.length() < 0.1: return
	ahead = ahead.normalized()
	var calm := Basis(Vector3.UP.cross(ahead), Vector3.UP, ahead)
	var pitch := look_pitch + _care_look * _care_w
	var look := calm * Basis(Vector3.RIGHT, -pitch)
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(_neck)).basis.orthonormalized()
	var neck_rest := sk.get_bone_global_rest(_neck).basis.orthonormalized()
	var neck_now := sk.get_bone_global_pose(_neck).basis.orthonormalized()
	var neck_goal := calm.slerp(look, 0.4) * neck_rest
	var neck_final := neck_now.slerp(neck_goal, weight * 0.7)
	sk.set_bone_pose_rotation(_neck, (parent.inverse() * neck_final).get_rotation_quaternion())
	var head_rest := sk.get_bone_global_rest(_head_bone).basis.orthonormalized()
	var head_now: Basis = neck_final * Basis(sk.get_bone_pose_rotation(_head_bone))
	var head_final := head_now.orthonormalized().slerp(look * head_rest, weight)
	sk.set_bone_pose_rotation(_head_bone, (neck_final.inverse() * head_final).get_rotation_quaternion())


## Cure viste da fuori. Benda: il braccio sinistro si alza e la destra gira attorno all'avambraccio, svolgendo la benda,
## con lo sguardo sul braccio. Consegna: il braccio destro porge quello che ha in mano e torna indietro.
func bandage() -> void:
	_care = "bandage"
	_care_t = 0.0


func offer() -> void:
	_care = "offer"
	_care_t = 0.0


func pause(seconds: float) -> void:
	_pause = seconds


func _care_pose(sk: Skeleton3D, chest: Transform3D, rest: Transform3D, turn: Basis) -> void:
	if _care_w <= 0.0: return
	var place := func(p: Vector3) -> Vector3: return rest.origin + turn * (p - rest.origin) + (chest.origin - rest.origin)
	if _care == "bandage":
		var along := (turn * Vector3(-0.72, 0.12, 0.68)).normalized()      # avambraccio sinistro, dal gomito al polso
		var wrist: Vector3 = place.call(Vector3(0.03, 1.2, 0.33))
		var palm := (turn * Vector3(0.1, 1.0, 0.1)).normalized()
		palm = (palm - along * palm.dot(along)).normalized()
		_reach(sk, "l", wrist, along, palm, turn * Vector3(0.55, -0.8, -0.25), _care_w)
		# La destra gira attorno all'avambraccio: sopra, davanti, sotto, dietro.
		var center := wrist - along * 0.11
		var side := palm
		var other := along.cross(side)
		var angle := _care_t * TAU * BANDAGE_TURNS / BANDAGE_SECONDS
		var radial := side * cos(angle) + other * sin(angle)
		var tangent := -side * sin(angle) + other * cos(angle)
		var fingers := (tangent + along * 0.25 + turn * Vector3(0.25, 0.0, 0.25)).normalized()
		var hand_palm := -radial
		var grip := center + radial * 0.07 + along * (sin(_care_t * 1.6) * 0.03)
		_reach(sk, "r", grip - fingers * 0.085 - hand_palm * 0.03, fingers, hand_palm, turn * Vector3(-0.6, -0.8, -0.2), _care_w)
		_care_look = -0.72
		_fingers(sk, "l", RELAXED)
		_fingers(sk, "r", ROLL)
	elif _care == "offer":
		var fingers := (turn * Vector3(-0.1, -0.12, 1)).normalized()
		var palm := (turn * Vector3(0.05, 1, 0.12)).normalized()
		_reach(sk, "r", place.call(Vector3(-0.17, 1.2, 0.42)), fingers, palm, turn * Vector3(-0.5, -1, -0.1), _care_w)
		_care_look = -0.1
		_fingers(sk, "r", ROLL)


## Nella posa a T di questo rig i palmi guardano in basso: è il -Z delle falangi.
func _hand_basis(sk: Skeleton3D, side: String, fingers: Vector3, palm: Vector3) -> Basis:
	var r_ha := sk.get_bone_global_rest(_ids["hand_" + side])
	var finger_bone := sk.get_bone_global_rest(sk.find_bone("middle_01_" + side))
	var rest_f := (finger_bone.origin - r_ha.origin).normalized()
	var rest_p := finger_bone.basis.orthonormalized() * Vector3.FORWARD
	return ArmIk.align(rest_f, rest_p, fingers, palm) * r_ha.basis.orthonormalized()


func _fist(sk: Skeleton3D, side: String, w: Transform3D, grip: Dictionary, shift: Vector3, up: Vector3, longest := ARM_REACH) -> Array:
	# Questa mano è più grande di quella in prima persona: sulla pistola sale per riempire l'impugnatura.
	var place: Vector3 = shift + (Vector3(0, 0, 0.03) if motion.is_gun() and (side == "r" or motion.kind == "pistol") else Vector3.ZERO)
	return ToolMotion.fist_for(w, grip, side, sk.get_bone_global_pose(_ids["upperarm_" + side]).origin, up, 0.095, 0.035, longest, place, motion.edge_w)


func _reach(sk: Skeleton3D, side: String, wrist: Vector3, fingers: Vector3, palm: Vector3, pole: Vector3, weight: float) -> void:
	if weight <= 0.0: return
	var up: int = _ids["upperarm_" + side]
	var lo: int = _ids["lowerarm_" + side]
	var ha: int = _ids["hand_" + side]
	var rots: Array = ArmIk.solve(sk, up, lo, ha, wrist, _hand_basis(sk, side, fingers.normalized(), palm.normalized()), pole, Vector3.BACK)
	sk.set_bone_pose_rotation(up, sk.get_bone_pose_rotation(up).slerp(rots[0], weight))
	sk.set_bone_pose_rotation(lo, sk.get_bone_pose_rotation(lo).slerp(rots[1], weight))
	sk.set_bone_pose_rotation(ha, sk.get_bone_pose_rotation(ha).slerp(rots[2], weight))


## Mano libera: polso quasi dritto sull'avambraccio e dita appena chiuse.
func _relax(sk: Skeleton3D, side: String) -> void:
	var ha: int = _ids["hand_" + side]
	sk.set_bone_pose_rotation(ha, sk.get_bone_pose_rotation(ha).slerp(sk.get_bone_rest(ha).basis.get_rotation_quaternion(), 0.85))
	_fingers(sk, side, RELAXED)


func _fingers(sk: Skeleton3D, side: String, curls: Dictionary) -> void:
	for digit in curls:
		for j in 3:
			var id := sk.find_bone("%s_0%d_%s" % [digit, j + 1, side])
			if id >= 0:
				var curl := Basis(Vector3.RIGHT, -float(curls[digit][j]))
				# Il pollice si richiude sulle dita, non solo verso il palmo.
				if digit == "thumb" and j == 0: curl = Basis(Vector3.BACK, -0.75) * curl
				sk.set_bone_pose_rotation(id, (sk.get_bone_rest(id).basis * curl).get_rotation_quaternion())
