extends RefCounted
# Ciò che si vede quando un'arma spara: ogni arma ha la sua vampa, la sua scia e il suo proiettile.
# Solo effetti: il danno lo decide weapons/melee/melee_controller.gd.

static var _glow: Texture2D


static func glow() -> Texture2D:
	if _glow: return _glow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 0.75, 0.35, 0))
	ramp.add_point(0.3, Color(1, 0.86, 0.55, 0.85))
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_glow = tex
	return tex


static func _lit(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	return mat


static func _life(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds).timeout.connect(func() -> void: if is_instance_valid(node): node.queue_free())


static func _flash(parent: Node, at: Vector3, raw_size: float, color: Color, raw_energy: float) -> void:
	# Vicino alla camera la luce abbaglia: la vampa conta più del lampo.
	var size: float = raw_size * 0.7
	var energy: float = raw_energy * 0.14
	if energy > 0.0:
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = energy
		light.omni_range = 2.5 + energy * 2.0
		parent.add_child(light)
		light.global_position = at
		_life(light, 0.05)
	if size > 0.0:
		var star := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * size
		var bright := _lit(color)
		bright.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		bright.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bright.albedo_texture = glow()
		quad.material = bright
		star.mesh = quad
		parent.add_child(star)
		star.global_position = at
		_life(star, 0.045)


## Scia dritta tra due punti, che sfuma.
static func _beam(parent: Node, from: Vector3, to: Vector3, width: float, color: Color, alpha: float, seconds: float) -> void:
	var length: float = from.distance_to(to)
	if length < 0.5: return
	var line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, length)
	var mat := _lit(color, alpha)
	box.material = mat
	line.mesh = box
	parent.add_child(line)
	line.global_position = (from + to) * 0.5
	line.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.98 else Vector3.RIGHT)
	var fade := line.create_tween()
	fade.tween_property(mat, "albedo_color:a", 0.0, seconds * 2.0)
	fade.tween_callback(line.queue_free)


## Cosa che vola davvero: si vede partire e arrivare.
static func _shot_body(parent: Node, from: Vector3, to: Vector3, speed: float, mesh: Mesh, color: Color, light: float, stays: float) -> void:
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = _lit(color)
	parent.add_child(body)
	body.global_position = from
	if from.distance_to(to) > 0.1: body.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.98 else Vector3.RIGHT)
	if light > 0.0:
		var glow_light := OmniLight3D.new()
		glow_light.light_color = color
		glow_light.light_energy = light
		glow_light.omni_range = 7.0
		body.add_child(glow_light)
	var move := body.create_tween()
	move.tween_property(body, "global_position", to, from.distance_to(to) / speed)
	move.tween_interval(stays)
	move.tween_callback(body.queue_free)


static func _rod(length: float, width: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, length)
	return mesh


static func _casing(parent: Node, at: Vector3, right: Vector3, length: float, color: Color) -> void:
	var casing := CPUParticles3D.new()
	casing.one_shot = true
	casing.amount = 1
	casing.lifetime = 0.7
	casing.explosiveness = 1.0
	casing.direction = right + Vector3.UP * 0.7
	casing.spread = 16.0
	casing.initial_velocity_min = 2.2
	casing.initial_velocity_max = 2.8
	casing.gravity = Vector3(0, -9.8, 0)
	casing.local_coords = false
	var brass := CylinderMesh.new()
	brass.top_radius = length * 0.3
	brass.bottom_radius = length * 0.3
	brass.height = length
	brass.radial_segments = 6
	brass.rings = 0
	var metal := StandardMaterial3D.new()
	metal.albedo_color = color
	metal.metallic = 0.9
	brass.material = metal
	casing.mesh = brass
	parent.add_child(casing)
	casing.global_position = at
	casing.emitting = true
	_life(casing, 1.0)


static func _smoke(parent: Node, at: Vector3, way: Vector3, amount: int, color: Color, spread: float, speed: float) -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.amount = amount
	puff.lifetime = 0.55
	puff.explosiveness = 0.9
	puff.direction = way
	puff.spread = spread
	puff.initial_velocity_min = speed * 0.5
	puff.initial_velocity_max = speed
	puff.gravity = Vector3(0, 0.6, 0)
	puff.local_coords = false
	puff.scale_amount_min = 0.5
	puff.scale_amount_max = 1.4
	var ball := SphereMesh.new()
	ball.radius = 0.08
	ball.height = 0.16
	ball.radial_segments = 6
	ball.rings = 3
	ball.material = _lit(color, 0.28)
	puff.mesh = ball
	parent.add_child(puff)
	puff.global_position = at
	puff.emitting = true
	_life(puff, 1.2)


## Scintille rapide: getto dalla canna o schegge dove il colpo arriva.
static func _sparks(parent: Node, at: Vector3, way: Vector3, amount: int, color: Color, spread: float, speed: float, life: float) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.amount = amount
	burst.lifetime = life
	burst.explosiveness = 1.0
	burst.direction = way
	burst.spread = spread
	burst.initial_velocity_min = speed * 0.5
	burst.initial_velocity_max = speed
	burst.gravity = Vector3(0, -9.8, 0)
	burst.local_coords = false
	burst.scale_amount_min = 0.4
	burst.scale_amount_max = 1.0
	var bit := _rod(0.05, 0.012)
	var hot := _lit(color)
	hot.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bit.material = hot
	burst.mesh = bit
	burst.particle_flag_align_y = true
	parent.add_child(burst)
	burst.global_position = at
	burst.emitting = true
	_life(burst, life + 0.3)


## Schegge solo se lì c'è davvero qualcosa: un colpo a vuoto finisce a fine gittata, in aria.
static func _impact(parent: Node, end: Vector3, forward: Vector3) -> void:
	if not (parent is Node3D) or not parent.is_inside_tree(): return
	var ray := PhysicsRayQueryParameters3D.create(end - forward * 0.3, end + forward * 0.3)
	var hit: Dictionary = (parent as Node3D).get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return
	var normal: Vector3 = hit.normal
	_sparks(parent, hit.position + normal * 0.02, normal, 7, Color("ffcf7a"), 55.0, 3.5, 0.28)
	_smoke(parent, hit.position + normal * 0.05, normal, 3, Color("8a8378"), 30.0, 0.8)


## Un pezzo di scia di una lama, fra due posizioni del filo.
static func trail(parent: Node, a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [a0, a1, b0, b0, a1, b1]: st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := _lit(color, 0.22)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	parent.add_child(mi)
	var fade := mi.create_tween()
	fade.tween_property(mat, "albedo_color:a", 0.0, 0.14)
	fade.tween_callback(mi.queue_free)


## Fiammella su chi sta bruciando.
static func burn_puff(parent: Node, at: Vector3) -> void:
	_flash(parent, at, 0.5, Color("ff8a3a"), 1.2)
	_smoke(parent, at, Vector3.UP, 5, Color("ff7a30"), 25.0, 1.4)


## Fulmine: una linea spezzata fra due punti.
static func arc(parent: Node, from: Vector3, to: Vector3) -> void:
	var points := 6
	var last := from
	for i in range(1, points + 1):
		var next: Vector3 = from.lerp(to, float(i) / points)
		if i < points: next += Vector3(randf_range(-0.28, 0.28), randf_range(-0.28, 0.28), randf_range(-0.28, 0.28))
		_beam(parent, last, next, 0.035, Color("9fe8ff"), 0.95, 0.13)
		last = next
	_flash(parent, to, 0.5, Color("9fe8ff"), 1.5)


static func explosion(parent: Node, at: Vector3, radius: float) -> void:
	_flash(parent, at + Vector3.UP * 0.4, radius * 1.1, Color("ffb45a"), 6.0)
	_smoke(parent, at + Vector3.UP * 0.3, Vector3.UP, 26, Color("3b3631"), 70.0, 5.0)
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.03
	var mat := _lit(Color("ffcf8a"), 0.7)
	disc.material = mat
	ring.mesh = disc
	parent.add_child(ring)
	ring.global_position = at + Vector3.UP * 0.1
	var grow := ring.create_tween().set_parallel()
	grow.tween_property(ring, "scale", Vector3(radius, 1, radius), 0.22)
	grow.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	grow.chain().tween_callback(ring.queue_free)


## La granata fa un arco vero e scoppia dove arriva: `on_land` riceve il punto.
static func grenade(parent: Node, from: Vector3, way: Vector3, on_land: Callable) -> void:
	var ball := SphereMesh.new()
	ball.radius = 0.05
	ball.height = 0.1
	var body := MeshInstance3D.new()
	body.mesh = ball
	body.material_override = _lit(Color("5a6b3f"))
	parent.add_child(body)
	body.global_position = from
	var state := {"v": way * 24.0 + Vector3.UP * 3.0, "t": 0.0, "done": false}
	var step := func(_x: float) -> void:
		if state.done or not is_instance_valid(body): return
		var dt := 1.0 / 60.0
		var was: Vector3 = body.global_position
		state.v += Vector3.DOWN * 11.0 * dt
		var now: Vector3 = was + state.v * dt
		var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(was, now, 17))
		state.t += dt
		if not hit.is_empty() or state.t > 4.0:
			state.done = true
			var at: Vector3 = hit.position if not hit.is_empty() else now
			on_land.call(at)
			body.queue_free()
		else:
			body.global_position = now
	var run := body.create_tween()
	run.tween_method(step, 0.0, 1.0, 4.2)


## Il colpo a schermo. `ends` sono i punti d'arrivo, uno per pallino.
static func fire(parent: Node, id: String, muzzle: Vector3, ends: Array, forward: Vector3, right: Vector3) -> void:
	var to: Vector3 = ends[0] if not ends.is_empty() else muzzle + forward * 40.0
	match id:
		"revolver":
			_flash(parent, muzzle, 0.42, Color("ffd38a"), 2.6)
			_smoke(parent, muzzle, forward, 6, Color("8a8378"), 18.0, 2.2)
			_beam(parent, muzzle, to, 0.018, Color("ffe6ad"), 0.7, 0.07)
		"flare_gun":
			_flash(parent, muzzle, 0.35, Color("ff5a3a"), 2.0)
			_smoke(parent, muzzle, forward, 8, Color("c05040"), 12.0, 3.0)
			var ball := SphereMesh.new()
			ball.radius = 0.06
			ball.height = 0.12
			_shot_body(parent, muzzle, to, 34.0, ball, Color("ff6a3a"), 4.0, 0.9)
		"nailgun":
			_flash(parent, muzzle, 0.07, Color("c8d0d8"), 0.0)
			_shot_body(parent, muzzle, to, 80.0, _rod(0.09, 0.012), Color("b9c0c6"), 0.0, 4.0)
		"smg":
			_flash(parent, muzzle, 0.16, Color("ffcf8a"), 0.9)
			_casing(parent, muzzle - forward * 0.12, right, 0.016, Color("c8a24a"))
			_beam(parent, muzzle, to, 0.008, Color("ffd9a0"), 0.5, 0.035)
		"assault_rifle":
			_flash(parent, muzzle, 0.26, Color("ffc070"), 1.5)
			_casing(parent, muzzle - forward * 0.3, right, 0.024, Color("c8a24a"))
			_beam(parent, muzzle, to, 0.011, Color("ffe0a0"), 0.55, 0.04)
		"lmg":
			_flash(parent, muzzle, 0.34, Color("ffb060"), 2.0)
			_casing(parent, muzzle - forward * 0.35, right, 0.026, Color("c8a24a"))
			_beam(parent, muzzle, to, 0.018, Color("ff9a50"), 0.8, 0.05)
		"sniper_rifle":
			_flash(parent, muzzle, 0.5, Color("ffe8c8"), 3.0)
			_smoke(parent, muzzle, forward, 10, Color("9a968e"), 25.0, 2.5)
			_beam(parent, muzzle, to, 0.03, Color("e8f0ff"), 0.6, 0.7)     # la scia resta nell'aria
		"tesla_rifle":
			_flash(parent, muzzle, 0.3, Color("9fe8ff"), 2.0)
			arc(parent, muzzle, to)
		"pump_shotgun", "sawn_off":
			_flash(parent, muzzle, 0.62 if id == "sawn_off" else 0.5, Color("ffc070"), 3.0)
			_smoke(parent, muzzle, forward, 12, Color("8a8378"), 28.0, 3.0)
			if id == "pump_shotgun": _casing(parent, muzzle - forward * 0.4, right, 0.05, Color("b03a2a"))
			for end in ends: _beam(parent, muzzle, end, 0.006, Color("ffe0a0"), 0.5, 0.05)
		"lever_rifle":
			_flash(parent, muzzle, 0.36, Color("ffd090"), 2.2)
			_smoke(parent, muzzle, forward, 6, Color("8a8378"), 15.0, 2.2)
			_casing(parent, muzzle - forward * 0.45, right + Vector3.UP, 0.03, Color("c8a24a"))
			_beam(parent, muzzle, to, 0.012, Color("ffe6ad"), 0.6, 0.06)
		"crossbow":
			_shot_body(parent, muzzle, to, 55.0, _rod(0.45, 0.02), Color("7a5a38"), 0.0, 6.0)
		"grenade_launcher":
			_flash(parent, muzzle, 0.4, Color("ffc070"), 1.6)
			_smoke(parent, muzzle, forward, 12, Color("a39d92"), 15.0, 4.0)
		"leaf_blower":
			_smoke(parent, muzzle, forward, 10, Color("d8dcc8"), 12.0, 12.0)
		_:
			_flash(parent, muzzle, 0.24, Color("ffdf9a"), 1.3)
			_casing(parent, muzzle - forward * 0.12, right, 0.022, Color("c8a24a"))
			_beam(parent, muzzle, to, 0.012, Color("ffe6a0"), 0.55, 0.045)
	# Le armi a polvere: getto di scintille dalla canna e schegge dove arriva ogni colpo.
	if id not in ["crossbow", "flare_gun", "nailgun", "grenade_launcher", "leaf_blower", "tesla_rifle"]:
		_sparks(parent, muzzle, forward, 5, Color("ffd590"), 10.0, 9.0, 0.07)
		for end in ends: _impact(parent, end, forward)
