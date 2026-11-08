# Sputo acido degli infetti "sputatori" (kind 4): parabola verso il bersaglio, schizzo e pozza che brucia.
# cosmetic = true sui client (solo effetto visivo): il danno lo applica soltanto l'host.
extends Node3D

const GRAVITY := Vector3(0, -4.0, 0)   # parabola bassa: sta sotto il soffitto del dungeon (4.3 m)
const HIT_DAMAGE := 7.0
const POISON_SECONDS := 7.0
const PUDDLE_POISON := 2.5

var world: Node3D
var velocity := Vector3.ZERO
var cosmetic := false
var life := 3.0
var _mat: StandardMaterial3D
var _ball: MeshInstance3D


static func launch(owner_world: Node3D, from: Vector3, to: Vector3, cosmetic_only := false) -> Node3D:
	var s := Node3D.new()
	s.set_script(load("res://enemies/spit_projectile.gd"))
	owner_world.add_child(s)
	s.world = owner_world
	s.cosmetic = cosmetic_only
	s.global_position = from
	var t := clampf(from.distance_to(to) / 20.0, 0.25, 1.1)
	s.velocity = (to - from) / t - 0.5 * GRAVITY * t
	return s


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color("8fd14a")
	_mat.emission_enabled = true
	_mat.emission = Color("6dff3a")
	_mat.emission_energy_multiplier = 2.5
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.15; sm.height = 0.3; sm.radial_segments = 8; sm.rings = 4
	ball.mesh = sm; ball.material_override = _mat
	add_child(ball)
	_ball = ball
	AudioManager.zombie_voice(4, "attack", global_position, -5.0, randf_range(1.15, 1.35))
	var glow := OmniLight3D.new(); glow.light_color = Color("7dff4a"); glow.omni_range = 3.0; glow.light_energy = 1.2
	add_child(glow)
	var trail := CPUParticles3D.new()
	trail.amount = 24; trail.lifetime = 0.4; trail.local_coords = false
	var dm := SphereMesh.new(); dm.radius = 0.04; dm.height = 0.08; dm.radial_segments = 6; dm.rings = 3
	trail.mesh = dm; trail.material_override = _mat
	trail.gravity = Vector3(0, -3, 0); trail.initial_velocity_min = 0.1; trail.initial_velocity_max = 0.4; trail.spread = 180
	trail.scale_amount_min = 0.5; trail.scale_amount_max = 1.0
	add_child(trail)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0:
		queue_free()
		return
	velocity += GRAVITY * delta
	# Una massa molle che si allunga mentre vola.
	if _ball and velocity.length() > 0.5:
		var wob: float = 1.0 + sin(life * 22.0) * 0.12
		_ball.scale = Vector3(wob, 1.0 / wob, 1.0 + clampf(velocity.length() * 0.05, 0.0, 0.7))
		_ball.look_at(global_position + velocity, Vector3.UP)
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	for a in world.actors.values():
		if is_instance_valid(a) and not a.dead and (a.global_position + Vector3.UP).distance_to(to) < 0.75:
			if not cosmetic:
				if world.has_method("hit_player"):
					world.hit_player(a, HIT_DAMAGE, {"poison": POISON_SECONDS, "slow": 1.2, "knock": velocity.normalized() * 2.0 * Vector3(1, 0, 1), "shake": 0.3}, global_position)
				else:
					a.take_damage(HIT_DAMAGE)
			_splash(to)
			return
	if not hit.is_empty():
		_splash(hit.position)
		return
	global_position = to


func _splash(at: Vector3) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true; burst.explosiveness = 1.0; burst.amount = 26; burst.lifetime = 0.5
	var dm := SphereMesh.new(); dm.radius = 0.05; dm.height = 0.1; dm.radial_segments = 6; dm.rings = 3
	burst.mesh = dm; burst.material_override = _mat
	burst.direction = Vector3.UP; burst.spread = 75; burst.initial_velocity_min = 1.5; burst.initial_velocity_max = 3.5
	world.add_child(burst)
	burst.global_position = at + Vector3.UP * 0.05
	burst.emitting = true
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)
	var puddle := Puddle.new()
	world.add_child(puddle)
	puddle.global_position = at + Vector3.UP * 0.03
	puddle.start(world, _mat, cosmetic)
	queue_free()


class Puddle:
	extends Node3D
	var world: Node3D
	var cosmetic := false
	var time := 5.0
	var tick := 0.0
	var disc: MeshInstance3D

	func start(w: Node3D, mat: StandardMaterial3D, cosmetic_only: bool) -> void:
		world = w
		cosmetic = cosmetic_only
		disc = MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 1.15; cm.bottom_radius = 1.15; cm.height = 0.02; cm.radial_segments = 14
		disc.mesh = cm
		var m := mat.duplicate() as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.42, 0.62, 0.2, 0.62)
		m.emission_energy_multiplier = 0.12
		disc.material_override = m
		add_child(disc)
		var l := OmniLight3D.new(); l.light_color = Color("7dff4a"); l.omni_range = 2.5; l.light_energy = 0.6; l.position.y = 0.3
		add_child(l)

	func _process(delta: float) -> void:
		time -= delta
		disc.scale = Vector3.ONE * clampf(time / 1.0, 0.0, 1.0) if time < 1.0 else Vector3.ONE
		if time <= 0:
			queue_free()
			return
		tick -= delta
		if tick <= 0 and not cosmetic:
			tick = 0.5
			for a in world.actors.values():
				if is_instance_valid(a) and not a.dead and a.global_position.distance_to(global_position) < 1.3 and absf(a.global_position.y - global_position.y) < 1.0:
					if a.get("status"): a.status.add("poison", PUDDLE_POISON)
					else: a.take_damage(2.0)
