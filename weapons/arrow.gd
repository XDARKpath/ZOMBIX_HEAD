extends Node3D
# Freccia dell'arco: vola con la gravità, colpisce gli zombie sulle loro hitbox (testa ×2,5) e resta piantata
# nello zombie o nel terreno. Passandoci sopra (anche sul cadavere) il giocatore la recupera.

const MODEL := preload("res://art/env/weapons/SM_Wep_Arrows.glb")
const GRAVITY := 9.8
const PICKUP := 1.3
const LIFETIME := 90.0

var shooter: CharacterBody3D
var velocity := Vector3.ZERO
var damage := 40.0
var flying := true
var stuck_on: Node3D
var age := 0.0
var _check := 0.0


static func fire(owner_player: CharacterBody3D, from: Vector3, dir: Vector3, speed: float, dmg: float) -> Node3D:
	var a := Node3D.new()
	a.set_script(load("res://weapons/arrow.gd"))
	a.shooter = owner_player
	a.velocity = dir.normalized() * speed
	a.damage = dmg
	a.name = "Arrow"
	owner_player.get_parent().add_child(a)
	a.global_position = from
	a._aim()
	return a


func _ready() -> void:
	var m: Node3D = MODEL.instantiate()
	add_child(m)
	m.scale = Vector3.ONE * 0.95
	add_to_group("arrows")


func _aim() -> void:
	# Il modello della freccia punta lungo +Y: lo giro sulla velocità.
	if velocity.length() > 0.01:
		global_basis = Basis(Quaternion(Vector3.UP, velocity.normalized()))


func _physics_process(delta: float) -> void:
	age += delta
	if age > LIFETIME:
		queue_free()
		return
	if flying:
		velocity.y -= GRAVITY * delta
		var from := global_position
		var to := from + velocity * delta
		var query := PhysicsRayQueryParameters3D.create(from, to, 17, [shooter.get_rid()] if is_instance_valid(shooter) else [])
		query.collide_with_areas = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			global_position = to
			_aim()
			return
		flying = false
		global_position = hit.position - velocity.normalized() * 0.25
		_aim()
		var collider: Object = hit.collider
		if damage <= 0.0:
			# Copia da vedere (client online): resta piantata un attimo e sparisce.
			age = LIFETIME - 4.0
			if collider is Node3D: reparent(collider)
			return
		if collider.has_meta("target"):
			var victim: Node3D = collider.get_meta("target")
			var zone: String = str(collider.get_meta("zone"))
			# Freccia: niente reazione direzionale, solo il sussulto del colpo.
			victim.receive_hit(zone, damage, velocity.normalized() * 0.4, "bow", false)
			AudioManager.weapon_hit("bow", zone, false)
			stuck_on = victim
			reparent(victim)
			return
		AudioManager.play_3d("arrow_impact", global_position, -7.0, randf_range(0.92, 1.08), 22.0)
	# Piantata: si recupera passandoci accanto.
	_check -= delta
	if _check > 0.0 or damage <= 0.0: return
	_check = 0.25
	if is_instance_valid(stuck_on) and not stuck_on.get("dead") and stuck_on.get("dead") != null: return
	if is_instance_valid(shooter) and shooter.global_position.distance_to(global_position) < PICKUP:
		shooter.arrows += 1
		# Online il conto delle frecce arriva ai client solo col publish dell'host.
		var survival = shooter.get_parent().get("survival") if shooter.get_parent() else null
		if survival and survival.has_method("_publish"): survival._publish()
		AudioManager.arrow_pickup(global_position)
		queue_free()
