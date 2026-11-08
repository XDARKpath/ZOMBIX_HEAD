extends RefCounted
# IK spalla-gomito-polso per le braccia che seguono l'arma: vale per il rig in prima persona e per quello a 68 ossa.
# Tutto nello spazio dello scheletro; `flex` è la direzione verso cui si piega il gomito nella posa di riposo.


static func _frame(a: Vector3, b: Vector3) -> Basis:
	var x := a.normalized()
	var y := (b - x * b.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


static func align(a0: Vector3, b0: Vector3, a1: Vector3, b1: Vector3) -> Basis:
	return _frame(a1, b1) * _frame(a0, b0).transposed()


## Rotazioni locali [braccio, avambraccio, mano] che portano il polso in `wrist` con la mano orientata `hand`.
static func solve(sk: Skeleton3D, up: int, lo: int, ha: int, wrist: Vector3, hand: Basis, pole: Vector3, flex: Vector3) -> Array:
	var r_up := sk.get_bone_global_rest(up)
	var r_lo := sk.get_bone_global_rest(lo)
	var r_ha := sk.get_bone_global_rest(ha)
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(up)).basis.orthonormalized()
	var start := sk.get_bone_global_pose(up).origin
	var l1 := r_up.origin.distance_to(r_lo.origin)
	var l2 := r_lo.origin.distance_to(r_ha.origin)
	var to := wrist - start
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.003)
	var dir := to.normalized()
	var bend := pole - dir * pole.dot(dir)
	bend = bend.normalized() if bend.length() > 0.0001 else Vector3.DOWN
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var elbow := start + dir * a + bend * sqrt(maxf(l1 * l1 - a * a, 0.0))
	var u := (elbow - start).normalized()
	var w := (start + dir * d - elbow).normalized()
	var f := w - u * w.dot(u)
	f = f.normalized() if f.length() > 0.0001 else -bend
	var hinge := u.cross(f).normalized()
	var rest_up := r_up.basis.orthonormalized()
	var rest_lo := r_lo.basis.orthonormalized()
	var rest_ha := r_ha.basis.orthonormalized()
	var g_up := align(r_lo.origin - r_up.origin, flex, u, f) * rest_up
	var g_lo := align(r_ha.origin - r_lo.origin, flex, w, hinge.cross(w)) * rest_lo
	# Parte della torsione del polso la prende l'avambraccio: niente polso strizzato.
	var turn := (hand * (g_lo * rest_lo.inverse() * rest_ha).inverse()).orthonormalized().get_rotation_quaternion()
	var twist := 2.0 * atan2(Vector3(turn.x, turn.y, turn.z).dot(w), turn.w)
	g_lo = Basis(w, wrapf(twist, -PI, PI) * 0.6) * g_lo
	return [(parent.inverse() * g_up).get_rotation_quaternion(), (g_up.inverse() * g_lo).get_rotation_quaternion(), (g_lo.inverse() * hand).get_rotation_quaternion()]
