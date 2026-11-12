# LA ROCCA · trappole medievali. Ogni trappola ha il suo modello animato (art/zx_rocca/props/SM_Trap_*.glb).
# Il DANNO lo decide solo l'host (level.host). Le trappole a tempo usano l'orologio comune del livello (level.clock),
# così host e client vedono lame e fiamme negli stessi istanti.
extends RefCounted

const PROPS := "res://art/zx_rocca/props/"


static func player_of(n: Node) -> AnimationPlayer:
	var list := n.find_children("*", "AnimationPlayer", true, false)
	return list[0] if list.size() > 0 else null


# =================================================================== SPUNTONI
## Piastra 3.6 x 1.6 a pavimento. Ogni PERIOD scatta (Trap_Spikes_Strike, 1.57 s): punte su da 0.1 a 0.9 s.
class Spikes extends Node3D:
	const PERIOD := 3.0
	const STRIKE := 1.567
	const DAMAGE := 30.0
	var level: Node3D
	var offset := 0.0
	var ap: AnimationPlayer
	var _cycle := -1
	var _hit := {}

	func setup(owner_level: Node3D, phase_offset: float) -> void:
		level = owner_level
		offset = phase_offset
		var m: Node3D = load(PROPS + "SM_Trap_Spuntoni.glb").instantiate()
		add_child(m)
		ap = m.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("Trap_Spikes_Strike")
		ap.seek(0.0, true)
		ap.pause()

	func _t() -> float:
		return fposmod(level.clock + offset, PERIOD)

	func up() -> bool:
		var t := _t()
		return t > 0.1 and t < 0.9

	func _process(_dt: float) -> void:
		if not level:
			return
		var t := _t()
		ap.seek(minf(t, STRIKE), true)

	func _physics_process(_dt: float) -> void:
		if not level or not level.host:
			return
		var cycle := int(floorf((level.clock + offset) / PERIOD))
		if cycle != _cycle:
			_cycle = cycle
			_hit.clear()
		if not up():
			return
		for a in level.world.actors.values():
			if not is_instance_valid(a) or a.dead or _hit.has(a.get_instance_id()):
				continue
			var l := to_local(a.global_position)
			if absf(l.x) < 1.8 and absf(l.z) < 0.85 and l.y < 0.6 and l.y > -0.3:
				a.take_damage(DAMAGE, Vector3.INF, "env")
				_hit[a.get_instance_id()] = true
				level.trap_feedback(a, "spikes")
		for z in level.world.targets:
			if not is_instance_valid(z) or z.dead or _hit.has(z.get_instance_id()):
				continue
			var lz := to_local(z.global_position)
			if absf(lz.x) < 1.8 and absf(lz.z) < 0.85 and lz.y < 0.6:
				_hit[z.get_instance_id()] = true
				z.receive_hit("feet", 60.0, Vector3.UP * 2.0, "trap", true)


# =================================================================== LAMA A PENDOLO
## Perno a 4.1 m, lama a ~3 m dal perno. Oscilla attraverso il corridoio (asse X locale) in 2.4 s, ±62°.
## La posizione della lama viene dalla stessa formula della clip (Trap_Pendulum_Swing campionata col clock).
class Pendulum extends Node3D:
	const PERIOD := 2.4
	const AMP := 1.08
	const ARM := 3.05
	const DAMAGE := 35.0
	var level: Node3D
	var offset := 0.0
	var ap: AnimationPlayer
	var _cool := {}

	func setup(owner_level: Node3D, phase_offset: float) -> void:
		level = owner_level
		offset = phase_offset
		var m: Node3D = load(PROPS + "SM_Trap_Pendolo.glb").instantiate()
		add_child(m)
		ap = m.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("Trap_Pendulum_Swing")
		ap.pause()

	func phase() -> float:
		return fposmod(level.clock + offset, PERIOD)

	func blade() -> Vector3:
		# Blender ruota intorno a +Y (= -Z in Godot): angolo positivo porta la lama verso +X
		var a := AMP * sin(TAU * phase() / PERIOD)
		return Vector3(sin(a) * ARM, 4.1 - cos(a) * ARM, 0)

	func _process(_dt: float) -> void:
		if level:
			ap.seek(phase(), true)

	func _physics_process(dt: float) -> void:
		if not level or not level.host:
			return
		for k in _cool.keys():
			_cool[k] -= dt
			if _cool[k] <= 0:
				_cool.erase(k)
		var b := blade()
		for a in level.world.actors.values():
			if not is_instance_valid(a) or a.dead or _cool.has(a.get_instance_id()):
				continue
			var l := to_local(a.global_position) + Vector3(0, 1.0, 0)
			if Vector2(l.x - b.x, l.y - b.y).length() < 0.95 and absf(l.z) < 0.6:
				a.take_damage(DAMAGE, Vector3.INF, "env")
				a.velocity += global_basis.x * signf(cos(TAU * phase() / PERIOD)) * 6.0     # spinta nel verso della lama
				_cool[a.get_instance_id()] = 0.9
				level.trap_feedback(a, "blade")
		for z in level.world.targets:
			if not is_instance_valid(z) or z.dead or _cool.has(z.get_instance_id()):
				continue
			var lz := to_local(z.global_position) + Vector3(0, 1.0, 0)
			if Vector2(lz.x - b.x, lz.y - b.y).length() < 0.95 and absf(lz.z) < 0.6:
				_cool[z.get_instance_id()] = 0.9
				z.receive_hit("torso", 80.0, global_basis.x * 4.0, "trap", true)


# =================================================================== MURO DEI DARDI + PIASTRA
## La piastra (a pavimento) fa sparare il muro: 5 dardi attraversano il corridoio (verso +Z locale del muro).
class ArrowTrap extends Node3D:
	const COOLDOWN := 2.5
	const DAMAGE := 18.0
	const SPEED := 22.0
	var level: Node3D
	var index := 0
	var wall: Node3D
	var wall_ap: AnimationPlayer
	var plate: Node3D
	var plate_ap: AnimationPlayer
	var arrow_mesh: Node3D
	var _cool := 0.0
	var _arrows := []                     # [nodo, distanza percorsa, già colpiti]

	## wall_at / plate_at in coordinate locali del livello; wall_rot = rotazione Y del muro (fronte = +Z locale)
	func setup(owner_level: Node3D, i: int, wall_at: Vector3, wall_rot: float, plate_at: Vector3) -> void:
		level = owner_level
		index = i
		wall = load(PROPS + "SM_Trap_MuroDardi.glb").instantiate()
		level.add_child(wall)
		wall.position = wall_at
		wall.rotation.y = wall_rot
		wall_ap = wall.find_children("*", "AnimationPlayer", true, false)[0]
		arrow_mesh = wall.find_child("Arrow", true, false)
		plate = load(PROPS + "SM_Trap_Piastra.glb").instantiate()
		level.add_child(plate)
		plate.position = plate_at
		plate_ap = plate.find_children("*", "AnimationPlayer", true, false)[0]

	func fire() -> void:
		_cool = COOLDOWN
		plate_ap.play("Trap_Plate_Press")
		wall_ap.play("Trap_Arrow_Fire")
		level.get_tree().create_timer(0.6).timeout.connect(func(): plate_ap.play("Trap_Plate_Release"))
		for p in [Vector3(-0.8, 0.6, 0), Vector3(0, 0.9, 0), Vector3(0.8, 0.6, 0), Vector3(-0.4, 1.5, 0), Vector3(0.4, 1.8, 0)]:
			var a := Node3D.new()
			var vis := arrow_mesh.duplicate() as Node3D
			vis.position = Vector3.ZERO
			vis.scale = Vector3.ONE
			vis.rotation = Vector3.ZERO
			a.add_child(vis)
			wall.add_child(a)
			a.position = p + Vector3(0, 0, 0.25)
			a.rotation.y = PI                    # la freccia del modello punta verso -Y Blender = +Z Godot: giriamo il nodo
			_arrows.append([a, 0.0, {}])

	func _physics_process(dt: float) -> void:
		if not level:
			return
		_cool = maxf(0.0, _cool - dt)
		for row in _arrows.duplicate():
			var a: Node3D = row[0]
			var step := SPEED * dt
			a.position.z += step
			row[1] += step
			if level.host:
				for act in level.world.actors.values():
					if is_instance_valid(act) and not act.dead and not row[2].has(act.get_instance_id()):
						if (act.global_position + Vector3.UP * 1.0).distance_to(a.global_position) < 0.75:
							act.take_damage(DAMAGE, Vector3.INF, "env")
							row[2][act.get_instance_id()] = true
							level.trap_feedback(act, "arrow")
			if row[1] > 4.2:
				a.queue_free()
				_arrows.erase(row)
		if not level.host or _cool > 0.0:
			return
		for act in level.world.actors.values() + level.world.targets:
			if is_instance_valid(act) and not act.dead:
				var l := plate.to_local(act.global_position)
				if absf(l.x) < 0.62 and absf(l.z) < 0.62 and absf(l.y) < 0.5:
					level.arrow_trap(index)
					return


# =================================================================== GETTO DI FUOCO
## Testa di drago a parete: ogni PERIOD sputa fuoco (Trap_Fire_Burst, 1.57 s), lingua di 3 m verso +Z locale.
class FireJet extends Node3D:
	const PERIOD := 4.0
	const BURST := 1.567
	const BURN := 14.0           # danni al secondo dentro la fiamma
	var level: Node3D
	var offset := 0.0
	var ap: AnimationPlayer
	var glow: OmniLight3D
	var _last := -1

	func setup(owner_level: Node3D, phase_offset: float) -> void:
		level = owner_level
		offset = phase_offset
		var m: Node3D = load(PROPS + "SM_Trap_Fuoco.glb").instantiate()
		add_child(m)
		ap = m.find_children("*", "AnimationPlayer", true, false)[0]
		ap.get_animation("Trap_Fire_Idle").loop_mode = Animation.LOOP_LINEAR
		ap.play("Trap_Fire_Idle")
		glow = OmniLight3D.new()
		glow.light_color = Color("ff8a2a")
		glow.omni_range = 7.0
		glow.light_energy = 0.0
		glow.position = Vector3(0, 1.3, 1.6)
		add_child(glow)

	func burning() -> bool:
		var t := fposmod(level.clock + offset, PERIOD)
		return t > 0.15 and t < BURST - 0.15

	func _process(_dt: float) -> void:
		if not level:
			return
		var cyc := int(floorf((level.clock + offset) / PERIOD))
		var t := fposmod(level.clock + offset, PERIOD)
		if t < BURST and cyc != _last:
			_last = cyc
			ap.play("Trap_Fire_Burst")
			ap.seek(t, true)
		elif t >= BURST and ap.current_animation != "Trap_Fire_Idle":
			ap.play("Trap_Fire_Idle")
		glow.light_energy = (3.0 + 0.6 * sin(level.clock * 40.0)) if t < BURST else 0.0

	func _in_flame(p: Vector3) -> bool:
		var l := to_local(p + Vector3.UP * 1.0)
		return l.z > 0.4 and l.z < 3.4 and Vector2(l.x, l.y - 1.2).length() < 0.35 + l.z * 0.12

	func _physics_process(dt: float) -> void:
		if not level or not level.host or not burning():
			return
		for a in level.world.actors.values():
			if is_instance_valid(a) and not a.dead and _in_flame(a.global_position):
				a.take_damage(BURN * dt, Vector3.INF, "env")
				if randf() < dt * 3.0:
					level.trap_feedback(a, "fire")
		for z in level.world.targets:
			if is_instance_valid(z) and not z.dead and _in_flame(z.global_position):
				z.health -= 30.0 * dt
				if z.health <= 0:
					z.receive_hit("torso", 1.0, Vector3.ZERO, "fire", true)


# =================================================================== FILO + BARILE DI POLVERE
## Filo coi campanelli in un varco di 2.2 m (asse X locale) legato a un barile di polvere nera.
## Chi lo attraversa a piedi (non saltando) lo strappa: Trap_Tripwire_Snap, miccia, il barile esplode dopo FUSE.
class Tripwire extends Node3D:
	const FUSE := 1.1
	const RADIUS := 4.2
	const DAMAGE := 50.0
	var level: Node3D
	var index := 0
	var ap: AnimationPlayer
	var tripped := false
	var keg: Node3D
	var _side := {}

	func setup(owner_level: Node3D, i: int) -> void:
		level = owner_level
		index = i
		var m: Node3D = load(PROPS + "SM_Trap_FiloBarile.glb").instantiate()
		add_child(m)
		ap = m.find_children("*", "AnimationPlayer", true, false)[0]
		ap.get_animation("Trap_Tripwire_Idle").loop_mode = Animation.LOOP_LINEAR
		ap.play("Trap_Tripwire_Idle")
		keg = m.find_child("Keg", true, false)

	func reset() -> void:
		tripped = false
		_side.clear()
		ap.play("Trap_Tripwire_Idle")
		visible = true

	func _physics_process(_dt: float) -> void:
		if tripped or not level or not level.host:
			return
		for a in level.world.actors.values() + level.world.targets:
			if not is_instance_valid(a) or a.dead:
				continue
			var l := to_local(a.global_position)
			var id: int = a.get_instance_id()
			if absf(l.x) > 1.15 or absf(l.z) > 1.5:
				_side.erase(id)
				continue
			var s := signf(l.z)
			if _side.has(id) and _side[id] != s and s != 0.0 and l.y < 0.35:
				level.trip(index)
				return
			_side[id] = s

	func snap() -> void:
		if tripped:
			return
		tripped = true
		ap.play("Trap_Tripwire_Snap")
		level.get_tree().create_timer(FUSE).timeout.connect(_explode)

	func _explode() -> void:
		var at: Vector3 = keg.global_position + Vector3.UP * 0.3 if keg else global_position
		level.explosion(at, RADIUS)
		if keg:
			keg.visible = false
		if level.host:
			for a in level.world.actors.values():
				if is_instance_valid(a) and not a.dead:
					var d: float = a.global_position.distance_to(at)
					if d < RADIUS:
						a.take_damage(DAMAGE * (1.0 - d / RADIUS * 0.6), Vector3.INF, "env")
			for z in level.world.targets:
				if is_instance_valid(z) and not z.dead and z.global_position.distance_to(at) < RADIUS:
					z.receive_hit("torso", 120.0, (z.global_position - at).normalized() * 6.0, "grenade", true)
