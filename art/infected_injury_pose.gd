extends RefCounted
# Pose delle lesioni sopra la clip, chiamata da art/infected_motion.gd (_layers): il braccio rotto o senza mano
# penzola lungo il fianco, la gamba ferita resta rigida e il bacino cede da quella parte (zoppia).
# Formato di infected_motion._bend: pose.q[named[osso]] è la rotazione dell'osso rispetto al padre, negli assi del
# personaggio a riposo (+Z avanti, +Y su, +X sinistra; braccia a T lungo X).

## Braccio lungo il fianco, la stessa posa di riposo di survivor_visual.gd.
const HANG := {"l": -1.34, "r": 1.34}
## Quanto pesa la posa per lo stato peggiore della parte [sano, ferito, menomato, fratturato, staccato].
const ARM_WEIGHT := [0.0, 0.0, 0.45, 1.0, 1.0]
const LEG_WEIGHT := [0.0, 0.35, 0.6, 1.0, 1.0]


static func apply(pose: Dictionary, named: Dictionary, actor) -> void:
	if actor == null or not actor.has_method("part_state") or actor.get("dead") == true: return
	var t: float = float(actor.get("clock")) if actor.get("clock") != null else 0.0
	for side in ["l", "r"]:
		var arm := 0
		for part in ["upperarm_", "forearm_", "hand_"]: arm = maxi(arm, actor.part_state(part + side))
		if ARM_WEIGHT[arm] > 0.0 and actor.part_state("upperarm_" + side) < 4:
			_dangle(pose, named, side, ARM_WEIGHT[arm], t)
		var leg := 0
		for part in ["thigh_", "calf_", "foot_"]: leg = maxi(leg, actor.part_state(part + side))
		if LEG_WEIGHT[leg] > 0.0 and not actor.get("crawling"):
			_limp(pose, named, side, LEG_WEIGHT[leg], t)


## Il braccio che non regge più: cade lungo il fianco, gomito e polso molli, oscilla col passo.
static func _dangle(pose: Dictionary, named: Dictionary, side: String, w: float, t: float) -> void:
	var sway: float = sin(t * 2.3 + (0.0 if side == "l" else 1.7)) * 0.08
	_toward(pose, named, "upperarm_" + side, Quaternion(Vector3.BACK, HANG[side]) * Quaternion(Vector3.RIGHT, sway), w)
	_toward(pose, named, "lowerarm_" + side, Quaternion(Vector3.RIGHT, sway * 1.5), w)
	_toward(pose, named, "hand_" + side, Quaternion.IDENTITY, w)


## La gamba ferita: il ginocchio piega meno, il bacino scende da quella parte e il busto compensa dall'altra.
static func _limp(pose: Dictionary, named: Dictionary, side: String, w: float, t: float) -> void:
	var lean: float = 1.0 if side == "l" else -1.0
	_toward(pose, named, "calf_" + side, Quaternion.IDENTITY, w * 0.5)
	_bend(pose, named, "pelvis", Vector3.BACK, lean * 0.08 * w)
	_bend(pose, named, "spine_02", Vector3.BACK, -lean * 0.12 * w)
	pose.p = (pose.p as Vector3) + Vector3.DOWN * 0.03 * w * (0.5 + 0.5 * sin(t * 6.0))


static func _toward(pose: Dictionary, named: Dictionary, bone: String, goal: Quaternion, w: float) -> void:
	if named.has(bone):
		pose.q[named[bone]] = (pose.q[named[bone]] as Quaternion).slerp(goal, clampf(w, 0.0, 1.0))


static func _bend(pose: Dictionary, named: Dictionary, bone: String, axis: Vector3, angle: float) -> void:
	if named.has(bone):
		pose.q[named[bone]] = Quaternion(axis, angle) * (pose.q[named[bone]] as Quaternion)
