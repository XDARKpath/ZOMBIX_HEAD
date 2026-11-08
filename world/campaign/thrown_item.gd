extends RigidBody3D
# Arma od oggetto lanciato con [Q] (fisica solo sull'host; i client ricevono posizione e rotazione da survival_rules).
# Nasce davanti alla camera, ruota in volo, colpisce una volta sola un infetto se va oltre 6 m/s e poi resta per terra:
# con E si raccoglie. Le teste lanciate tornano a essere teste per terra normali. Gli oggetti spariscono dopo 5 minuti,
# le armi no.

const HIT_SPEED := 6.0
const LIFETIME := 300.0
const REST_SPEED := 0.35

var sid := 0
var item := ""
var rules: Node3D
var shooter: CharacterBody3D
var age := 0.0
var hit_done := false
var resting := false
var _still := 0.0
var _last := Vector3.ZERO


func setup(owner_rules: Node3D, id: String, serial: int, from: CharacterBody3D, at: Vector3, velocity: Vector3) -> void:
	rules = owner_rules
	item = id
	sid = serial
	shooter = from
	name = "Thrown%d" % serial
	collision_layer = 0
	collision_mask = 1
	mass = 2.0
	continuous_cd = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.22, 0.42 if not ItemInfo.is_item(id) else 0.22, 0.22)
	shape.shape = box
	add_child(shape)
	var m := ItemInfo.model(id)
	if m: add_child(m)
	rules.add_child(self)
	global_position = at
	_last = at
	linear_velocity = velocity
	angular_velocity = global_basis.x * -11.0 + Vector3(0, randf_range(-1.5, 1.5), 0)


func _physics_process(delta: float) -> void:
	age += delta
	if global_position.y < -30.0:
		# Caduto fuori dal mondo: torna accanto a chi l'ha lanciato, la partita non deve bloccarsi.
		global_position = shooter.global_position + Vector3.UP if is_instance_valid(shooter) else Vector3(3, 2, 2)
		linear_velocity = Vector3.ZERO
	if not hit_done and linear_velocity.length() > HIT_SPEED: _sweep()
	_last = global_position
	if linear_velocity.length() < REST_SPEED: _still += delta
	else: _still = 0.0
	if _still > 0.5 and not resting:
		resting = true
		rules.thrown_rest(self)
	if age > LIFETIME and ItemInfo.is_item(item) and resting:
		rules.thrown_remove(self)


## Raggio fra la posizione di prima e quella di adesso, sulle hitbox degli infetti (come le frecce).
func _sweep() -> void:
	var exclude: Array[RID] = [get_rid()]
	if is_instance_valid(shooter): exclude.append(shooter.get_rid())
	var to := global_position + linear_velocity.normalized() * 0.3
	var query := PhysicsRayQueryParameters3D.create(_last, to, 16, exclude)
	query.collide_with_areas = true
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		# L'arma è lunga e ruota: prende anche chi le passa a un palmo, non solo chi sta sulla linea esatta.
		var ball := SphereShape3D.new()
		ball.radius = 0.35
		var near := PhysicsShapeQueryParameters3D.new()
		near.shape = ball
		near.transform = Transform3D(Basis.IDENTITY, global_position)
		near.collision_mask = 16
		near.collide_with_areas = true
		near.exclude = exclude
		var found := space.intersect_shape(near, 8)
		var best := INF
		for row in found:
			if not row.collider.has_meta("target"): continue
			var away: float = (row.collider as Node3D).global_position.distance_squared_to(global_position)
			if away < best:
				best = away
				hit = row
	if hit.is_empty() or not hit.collider.has_meta("target"): return
	var victim: Node3D = hit.collider.get_meta("target")
	if victim.get("dead") == true: return
	hit_done = true
	var dir := linear_velocity.normalized()
	if "reaction_dir" in victim:
		victim.pending_reaction = "pushed" if ItemInfo.throw_damage(item) >= 30.0 else ""
		victim.reaction_dir = Vector3(dir.x, 0, dir.z)
	victim.receive_hit(hit.collider.get_meta("zone"), ItemInfo.throw_damage(item), dir * 1.2, item if not ItemInfo.is_item(item) else "thrown", false)
	linear_velocity *= 0.2
