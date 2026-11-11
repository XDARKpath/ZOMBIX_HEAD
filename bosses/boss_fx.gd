extends RefCounted
# Effetti dei boss, solo grafica: avvisi a terra, crepe, onde, spuntoni, pozze, catene. Il danno lo decide l'host (boss_brain.gd);
# qui si disegna la stessa cosa su ogni computer. play() non tocca mai la vita o le posizioni di nessuno.
# Gli avvisi seguono il terreno: ogni vertice è appoggiato con un raggio, così funzionano anche sul prato ondulato della radura.

const COLORS := {"danger": Color(1.0, 0.32, 0.12, 0.42), "fire": Color(1.0, 0.5, 0.1, 0.46), "blood": Color(0.72, 0.05, 0.07, 0.5), "steel": Color(0.72, 0.8, 0.9, 0.42), "acid": Color(0.42, 0.95, 0.22, 0.42)}
const STONE := Color("6d675d")
const STONE_DARK := Color("3b3733")
const EMBER := Color("ff6a1e")
const LIFT := 0.07


static func play(world: Node, kind: String, at: Vector3, d: Dictionary) -> void:
	if not is_instance_valid(world) or not world.is_inside_tree(): return
	match kind:
		"warn": _warn(world, at, d)
		"crack": _crack(world, at, d)
		"ring": _ring(world, at, d)
		"spike": _spike(world, at, d)
		"patch": _patch(world, at, d)
		"boulder": _boulder(world, at, d)
		"chain": _chain(world, at, d)
		"cleaver": _cleaver(world, at, d)
		"sweep": _sweep(world, at, d)
		"cage": _cage(world, at, d)
		"pop": _pop(world, at, d)
		"burn": _burn(world, d)
		"rage": _rage(world, d)
		"flash": _flash(world, d)
		"plate": _plate(world, at)
		"bolt": _bolt(world, at, d)
		"veil": _veil(world, d)
		"crown": _crown(world, d)
		"slash": _slash(world, at, d)
		"trail": _trail(world, d)
		"death": _death(world, at, d)
		"sound": _sound(world, String(d.get("key", "")), at, float(d.get("v", 0.0)), float(d.get("p", 1.0)))
		"say": world.announce(String(d.get("text", "")), float(d.get("t", 3.0)))


# ------------------------------------------------------------------ terreno
static func _ground_y(world: Node3D, x: float, z: float, y: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, y + 1.3, z), Vector3(x, y - 3.5, z), 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else y


static func _material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = glow
	return mat


static func _instance(world: Node, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)
	node.global_position = at
	return node


## Spicchio di cerchio appoggiato al terreno (a0..a1 attorno a Y, 0 = verso -Z), con coordinate relative ad at.
static func _fan(world: Node3D, at: Vector3, r0: float, r1: float, a0: float, a1: float, steps: int, rings: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid := []
	for i in steps + 1:
		var a: float = lerpf(a0, a1, float(i) / steps)
		var row := []
		for j in rings + 1:
			var r: float = lerpf(r0, r1, float(j) / rings)
			var p := Vector3(-sin(a) * r, 0, -cos(a) * r)
			p.y = _ground_y(world, at.x + p.x, at.z + p.z, at.y) - at.y + LIFT
			row.append(p)
		grid.append(row)
	for i in steps:
		for j in rings:
			for p in [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j], grid[i + 1][j + 1], grid[i][j + 1]]:
				st.set_color(Color.WHITE)
				st.add_vertex(p)
	return st.commit()


## Striscia lunga verso yaw, partendo da at (per le cariche e le fenditure).
static func _strip(world: Node3D, at: Vector3, yaw: float, length: float, width: float, steps: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dir := Vector3(-sin(yaw), 0, -cos(yaw))
	var side := Vector3(dir.z, 0, -dir.x) * width * 0.5
	var rows := []
	for i in steps + 1:
		var mid: Vector3 = dir * (length * float(i) / steps)
		var row := []
		for s in [mid - side, mid + side]:
			var p: Vector3 = s
			p.y = _ground_y(world, at.x + p.x, at.z + p.z, at.y) - at.y + LIFT
			row.append(p)
		rows.append(row)
	for i in steps:
		for p in [rows[i][0], rows[i + 1][0], rows[i + 1][1], rows[i][0], rows[i + 1][1], rows[i][1]]:
			st.set_color(Color.WHITE)
			st.add_vertex(p)
	return st.commit()


## Striscia piana lungo -Z locale, per il riempimento che scala in lunghezza.
static func _flat_strip(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width * 0.5
	var y := LIFT
	for point in [Vector3(-half, y, 0), Vector3(-half, y, -length), Vector3(half, y, -length), Vector3(-half, y, 0), Vector3(half, y, -length), Vector3(half, y, 0)]:
		st.set_color(Color.WHITE)
		st.add_vertex(point)
	return st.commit()


static func _fade_out(world: Node, node: Node3D, mat: StandardMaterial3D, hold: float, fade: float) -> void:
	var tween := world.create_tween()
	tween.tween_interval(hold)
	tween.tween_property(mat, "albedo_color:a", 0.0, fade)
	tween.tween_callback(node.queue_free)


static func _shake_near(world: Node, at: Vector3, radius: float, power: float) -> void:
	var p = world.get("player")
	if not is_instance_valid(p) or not p.get("rig"): return
	var d: float = (p.global_position as Vector3).distance_to(at)
	if d < radius: p.rig.add_shake(power * (1.0 - d / radius))


static func _sound(world: Node, key: String, at: Vector3, volume: float, pitch: float = 1.0) -> void:
	var p = world.get("player")
	if not is_instance_valid(p): return
	var d: float = (p.global_position as Vector3).distance_to(at)
	if d > 45.0: return
	AudioManager.play_sfx(key, volume - d * 0.4, pitch)


# ------------------------------------------------------------------ avvisi
## Macchia a terra: il contorno è fisso e l'interno si riempie fino al momento del colpo. Tempo pieno = adesso fa male.
static func _warn(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var t: float = float(d.get("t", 1.0))
	var color: Color = COLORS.get(d.get("color", "danger"), COLORS.danger)
	var shape: String = d.get("shape", "circle")
	var yaw: float = float(d.get("yaw", 0.0))
	var mesh: ArrayMesh
	var edge: ArrayMesh
	var fill_axis := Vector3(1, 1, 1)
	if shape == "line":
		var length: float = float(d.get("len", 10.0))
		var width: float = float(d.get("width", 2.0))
		var steps: int = clampi(int(length / 1.5), 2, 18)
		mesh = _strip(world, at, yaw, length, width, steps)
		edge = mesh
		fill_axis = Vector3(1, 1, 1)
	elif shape == "cone":
		var half: float = float(d.get("angle", 1.0)) * 0.5
		var r: float = float(d.get("r", 5.0))
		mesh = _fan(world, at, 0.3, r, yaw - half, yaw + half, 14, 3)
		edge = mesh
	else:
		var r: float = float(d.get("r", 3.0))
		mesh = _fan(world, at, 0.0, r, 0.0, TAU, 22, 3)
		edge = _fan(world, at, maxf(r - 0.22, 0.0), r, 0.0, TAU, 28, 1)
	var outline_color := Color(color.r, color.g, color.b, 0.28 if shape != "circle" else 0.82)
	var outline_mat := _material(outline_color, 1.2)
	outline_mat.no_depth_test = true
	outline_mat.render_priority = 2
	var outline := _instance(world, edge, at, outline_mat)
	var fill_mat := _material(color, 0.9)
	fill_mat.no_depth_test = true
	fill_mat.render_priority = 3
	var fill := _instance(world, mesh, at, fill_mat)
	if shape == "line":
		# Si riempie dal boss verso il fondo: serve una striscia diritta sull'asse del nodo.
		fill.rotation.y = yaw
		fill.mesh = _flat_strip(float(d.get("len", 10.0)), float(d.get("width", 2.0)))
		fill.scale = Vector3(1, 1, 0.02)
		fill_axis = Vector3(1, 1, 1)
	else:
		fill.scale = Vector3(0.02, 1, 0.02)
	var tween := world.create_tween()
	tween.tween_property(fill, "scale", fill_axis, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(fill.queue_free)
	tween.tween_callback(outline.queue_free)


# ------------------------------------------------------------------ crepe, onde
## Colpo forte: la terra si spacca. Raggi scuri e storti, con la brace dentro se è un colpo di fuoco, sassi che saltano, polvere.
static func _crack(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var look: String = d.get("look", "")
	if look == "macellaio":
		_splat(world, at, d)
		return
	if look == "carceriere": _slabs(world, at, d)
	var r: float = float(d.get("r", 3.0))
	var ember: bool = d.get("ember", false)
	var life: float = float(d.get("life", 8.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(at.x * 10.0), int(at.z * 10.0)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow := SurfaceTool.new()
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rays: int = 7 + int(r * 1.5)
	for i in rays:
		var a: float = TAU * float(i) / rays + rng.randf_range(-0.2, 0.2)
		var pos := Vector2.ZERO
		var dir := Vector2(cos(a), sin(a))
		var left: float = r * rng.randf_range(0.65, 1.2)
		var width: float = 0.22 + r * 0.05
		while left > 0.0:
			var step: float = rng.randf_range(0.45, 0.9)
			var next: Vector2 = pos + dir * step
			var side: Vector2 = Vector2(-dir.y, dir.x)
			var w1: float = width * clampf(left / r, 0.12, 1.0)
			var w2: float = width * clampf((left - step) / r, 0.03, 1.0)
			var quad := [pos - side * w1, pos + side * w1, next + side * w2, next - side * w2]
			var pts := []
			for q in quad:
				pts.append(Vector3(q.x, _ground_y(world, at.x + q.x, at.z + q.y, at.y) - at.y + LIFT + 0.015, q.y))
			# La brace corre lungo il centro della crepa, senza interruzioni tra un tratto e l'altro.
			var core := [pts[0].lerp(pts[1], 0.3), pts[0].lerp(pts[1], 0.7), pts[3].lerp(pts[2], 0.7), pts[3].lerp(pts[2], 0.3)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color.WHITE)
				st.add_vertex(pts[idx])
				if ember:
					glow.set_color(Color.WHITE)
					glow.add_vertex(core[idx] + Vector3.UP * 0.012)
			pos = next
			dir = dir.rotated(rng.randf_range(-0.5, 0.5))
			left -= step
	var dark_mat := _material({"matriarca": Color(0.12, 0.3, 0.05, 0.9), "carceriere": Color(0.16, 0.15, 0.14, 0.95)}.get(look, Color(0.05, 0.04, 0.035, 0.95)))
	var dark := _instance(world, st.commit(), at, dark_mat)
	_fade_out(world, dark, dark_mat, life, 1.6)
	if ember:
		var hot_mat := _material(Color(1.0, 0.42, 0.08, 1.0), 2.4)
		var hot := _instance(world, glow.commit(), at, hot_mat)
		_fade_out(world, hot, hot_mat, life * 0.75, 1.6)
	_debris(world, at, r, ember)
	_shake_near(world, at, r + 13.0, float(d.get("shake", 0.8)))
	_sound(world, "weapon_hit_bone", at, 2.0, 0.42)


## Macellaio: niente crepe, una macchia di sangue schizzata a gocce attorno al colpo.
static func _splat(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var r: float = float(d.get("r", 2.5))
	var life: float = float(d.get("life", 6.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(at.x * 10.0), int(at.z * 10.0)))
	var mat := _material(Color(0.42, 0.02, 0.03, 0.9))
	var blobs := [[Vector3.ZERO, r * 0.55]]
	for i in 9 + int(r * 3.0):
		var a: float = rng.randf() * TAU
		var dist: float = rng.randf_range(r * 0.4, r * 1.25)
		blobs.append([Vector3(cos(a) * dist, 0, sin(a) * dist), rng.randf_range(0.1, 0.38) * (1.4 - dist / (r * 1.3))])
	for b in blobs:
		var spot: Vector3 = at + b[0]
		var node := _instance(world, _fan(world, spot, 0.0, maxf(b[1], 0.08), 0.0, TAU, 9, 1), spot, mat)
		node.scale = Vector3(rng.randf_range(0.7, 1.4), 1, rng.randf_range(0.7, 1.4))
		node.rotation.y = rng.randf() * TAU
		world.get_tree().create_timer(life + 1.0).timeout.connect(node.queue_free)
	var tween := world.create_tween()
	tween.tween_interval(life)
	tween.tween_property(mat, "albedo_color:a", 0.0, 1.0)
	var drops := CPUParticles3D.new()
	world.add_child(drops)
	drops.global_position = at + Vector3.UP * 0.6
	drops.one_shot = true
	drops.explosiveness = 0.9
	drops.amount = 24
	drops.lifetime = 0.8
	drops.direction = Vector3.UP
	drops.spread = 70.0
	drops.initial_velocity_min = 3.0
	drops.initial_velocity_max = 6.0
	drops.gravity = Vector3(0, -18, 0)
	var drop := SphereMesh.new()
	drop.radius = 0.06
	drop.height = 0.12
	drop.radial_segments = 5
	drop.rings = 2
	drops.mesh = drop
	drops.color = Color("8a0a0e")
	drops.emitting = true
	world.get_tree().create_timer(1.2).timeout.connect(drops.queue_free)
	_shake_near(world, at, r + 13.0, float(d.get("shake", 0.8)))
	_sound(world, "weapon_hit_bone", at, 2.0, 0.7)


## Carceriere: il pavimento si alza a lastre rotte, storte, che restano piantate.
static func _slabs(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var r: float = float(d.get("r", 3.0))
	var life: float = float(d.get("life", 8.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(at.z * 10.0), int(at.x * 10.0)))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STONE
	var holder := Node3D.new()
	world.add_child(holder)
	holder.global_position = at
	for i in 5 + int(r * 1.5):
		var a: float = TAU * float(i) / (5 + int(r * 1.5)) + rng.randf_range(-0.2, 0.2)
		var dist: float = rng.randf_range(r * 0.45, r * 0.95)
		var slab := BoxMesh.new()
		slab.size = Vector3(rng.randf_range(0.6, 1.1), 0.18, rng.randf_range(0.5, 0.9))
		slab.material = mat
		var part := MeshInstance3D.new()
		part.mesh = slab
		holder.add_child(part)
		var x: float = cos(a) * dist
		var z: float = sin(a) * dist
		part.position = Vector3(x, _ground_y(world, at.x + x, at.z + z, at.y) - at.y + 0.05, z)
		# Inclinate verso fuori, come spinte su dal colpo.
		part.rotation = Vector3(rng.randf_range(0.25, 0.6) * signf(z), -a, rng.randf_range(-0.6, -0.25) * signf(x))
	holder.scale = Vector3(1, 0.05, 1)
	var tween := world.create_tween()
	tween.tween_property(holder, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(life)
	tween.tween_property(holder, "position:y", holder.position.y - 0.5, 0.8)
	tween.tween_callback(holder.queue_free)


## Sassi e polvere che partono dal punto d'impatto.
static func _debris(world: Node3D, at: Vector3, r: float, ember: bool) -> void:
	var rocks := CPUParticles3D.new()
	world.add_child(rocks)
	rocks.global_position = at + Vector3.UP * 0.2
	rocks.one_shot = true
	rocks.explosiveness = 0.95
	rocks.amount = 14 + int(r * 3.0)
	rocks.lifetime = 1.0
	rocks.direction = Vector3.UP
	rocks.spread = 55.0
	rocks.initial_velocity_min = 3.0
	rocks.initial_velocity_max = 5.0 + r
	rocks.gravity = Vector3(0, -15, 0)
	rocks.angular_velocity_max = 300.0
	rocks.scale_amount_min = 0.5
	rocks.scale_amount_max = 1.5
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * 0.16
	rocks.mesh = chunk
	rocks.color = STONE
	rocks.emitting = true
	var dust := CPUParticles3D.new()
	world.add_child(dust)
	dust.global_position = at + Vector3.UP * 0.1
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = 26
	dust.lifetime = 1.05
	dust.direction = Vector3.UP
	dust.spread = 85.0
	dust.flatness = 0.8
	dust.initial_velocity_min = r * 1.1
	dust.initial_velocity_max = r * 2.2
	dust.damping_min = 5.0
	dust.damping_max = 7.0
	dust.gravity = Vector3(0, -1.5, 0)
	var puff := SphereMesh.new()
	puff.radius = 0.28
	puff.height = 0.56
	puff.radial_segments = 6
	puff.rings = 3
	dust.mesh = puff
	dust.color = Color("9c5a2c") if ember else Color("8a7d66")
	dust.emitting = true
	world.get_tree().create_timer(1.6).timeout.connect(rocks.queue_free)
	world.get_tree().create_timer(1.6).timeout.connect(dust.queue_free)


## Onda che corre sul terreno: si salta. Si allarga alla stessa velocità del controllo di danno dell'host.
static func _ring(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var r_max: float = float(d.get("r", 10.0))
	var speed: float = float(d.get("speed", 8.0))
	var color: Color = COLORS.get(d.get("color", "fire"), COLORS.fire)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.06
	torus.rings = 40
	torus.ring_segments = 5
	var mat := _material(Color(color.r, color.g, color.b, 0.92), 2.2)
	mat.vertex_color_use_as_albedo = false
	var ground_at := Vector3(at.x, _ground_y(world, at.x, at.z, at.y) + 0.26, at.z)
	var ring := _instance(world, torus, ground_at, mat)
	ring.scale = Vector3(0.4, 1.6, 0.4)
	var t: float = r_max / speed
	var tween := world.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(r_max, 1.6, r_max), t)
	tween.tween_property(mat, "albedo_color:a", 0.0, t * 0.35).set_delay(t * 0.65)
	tween.chain().tween_callback(ring.queue_free)


## Spuntone di roccia che esce da terra e rientra.
static func _spike(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var y: float = _ground_y(world, at.x, at.z, at.y)
	var height: float = float(d.get("h", 2.2))
	var life: float = float(d.get("life", 1.6))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(at.x * 7.0), int(at.z * 7.0)))
	var holder := Node3D.new()
	world.add_child(holder)
	holder.global_position = Vector3(at.x, y - height, at.z)
	for i in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = 0.46 - i * 0.1
		cone.height = height * (1.0 - i * 0.25)
		cone.radial_segments = 5
		cone.rings = 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = STONE if i != 1 else STONE_DARK
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		cone.material = mat
		var part := MeshInstance3D.new()
		part.mesh = cone
		holder.add_child(part)
		part.position = Vector3(rng.randf_range(-0.3, 0.3) * i, cone.height * 0.5, rng.randf_range(-0.3, 0.3) * i)
		part.rotation = Vector3(rng.randf_range(-0.22, 0.22), rng.randf() * TAU, rng.randf_range(-0.22, 0.22))
	var tween := world.create_tween()
	tween.tween_property(holder, "global_position:y", y - 0.05, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(life)
	tween.tween_property(holder, "global_position:y", y - height - 0.2, 0.5)
	tween.tween_callback(holder.queue_free)
	_debris(world, Vector3(at.x, y, at.z), 0.7, false)
	_shake_near(world, at, 9.0, 0.35)


## Fiamma morbida: un puntino di luce che sfuma nel nulla, sommato alla scena.
static func _flame_mesh(size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size * 1.35)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.86, 0.5, 1.0))
	ramp.set_color(1, Color(1.0, 0.25, 0.02, 0.0))
	ramp.add_point(0.45, Color(1.0, 0.45, 0.08, 0.8))
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 48
	tex.height = 48
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	return quad


## Macchia che resta e fa male: fuoco (voragine di brace) o sangue.
static func _patch(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var r: float = float(d.get("r", 2.5))
	var life: float = float(d.get("life", 6.0))
	var type: String = d.get("type", "fire")
	var color := Color(0.1, 0.03, 0.02, 0.92) if type == "fire" else (Color(0.2, 0.5, 0.1, 0.78) if type == "acid" else Color(0.34, 0.02, 0.03, 0.82))
	var mat := _material(color)
	var mesh := _fan(world, at, 0.0, r, 0.0, TAU, 20, 4)
	var node := _instance(world, mesh, at, mat)
	node.rotation.y = hash(int(at.x * 13.0)) % 100 * 0.06
	_fade_out(world, node, mat, life, 0.8)
	if type == "acid":
		var fumes := CPUParticles3D.new()
		world.add_child(fumes)
		fumes.global_position = at + Vector3.UP * 0.15
		fumes.amount = int(8 + r * 5.0)
		fumes.lifetime = 1.4
		fumes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fumes.emission_sphere_radius = r * 0.75
		fumes.direction = Vector3.UP
		fumes.spread = 12.0
		fumes.initial_velocity_min = 0.5
		fumes.initial_velocity_max = 1.4
		fumes.gravity = Vector3.ZERO
		var puff := SphereMesh.new()
		puff.radius = 0.2
		puff.height = 0.4
		puff.radial_segments = 6
		puff.rings = 3
		var puff_mat := StandardMaterial3D.new()
		puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff_mat.albedo_color = Color(0.5, 0.95, 0.28, 0.55)
		puff.material = puff_mat
		fumes.mesh = puff
		world.get_tree().create_timer(life + 0.8).timeout.connect(fumes.queue_free)
	if type == "fire":
		var rim_mat := _material(Color(1.0, 0.38, 0.06, 0.9), 2.2)
		var rim := _instance(world, _fan(world, at, r * 0.86, r, 0.0, TAU, 18, 1), at, rim_mat)
		_fade_out(world, rim, rim_mat, life, 0.8)
		var flames := CPUParticles3D.new()
		world.add_child(flames)
		flames.global_position = at + Vector3.UP * 0.1
		flames.amount = int(10 + r * 7.0)
		flames.lifetime = 0.8
		flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		flames.emission_sphere_radius = r * 0.8
		flames.direction = Vector3.UP
		flames.spread = 10.0
		flames.initial_velocity_min = 1.0
		flames.initial_velocity_max = 2.5
		flames.gravity = Vector3(0, 0.5, 0)
		flames.scale_amount_min = 0.55
		flames.scale_amount_max = 1.4
		var shrink := Curve.new()
		shrink.add_point(Vector2(0.0, 0.7))
		shrink.add_point(Vector2(0.3, 1.0))
		shrink.add_point(Vector2(1.0, 0.1))
		flames.scale_amount_curve = shrink
		flames.mesh = _flame_mesh(0.95)
		var light := OmniLight3D.new()
		light.light_color = Color("ff8038")
		light.light_energy = 1.4
		light.omni_range = r + 4.0
		flames.add_child(light)
		light.position = Vector3.UP * 0.8
		var tween := world.create_tween()
		tween.tween_interval(life)
		tween.tween_callback(func() -> void: if is_instance_valid(flames): flames.emitting = false)
		tween.tween_property(light, "light_energy", 0.0, 0.7)
		tween.tween_callback(flames.queue_free)


static func _boulder(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var to: Vector3 = d.get("to", at)
	var t: float = float(d.get("t", 1.0))
	var rock := SphereMesh.new()
	rock.radius = float(d.get("r", 0.75))
	rock.height = rock.radius * 1.7
	rock.radial_segments = 7
	rock.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = d.get("color", STONE)
	rock.material = mat
	var node := MeshInstance3D.new()
	node.mesh = rock
	world.add_child(node)
	node.global_position = at
	var height: float = maxf(at.distance_to(to) * 0.3, 2.0)
	var tween := world.create_tween()
	tween.tween_method(func(k: float) -> void:
		if is_instance_valid(node):
			node.global_position = at.lerp(to, k) + Vector3.UP * sin(k * PI) * height
			node.rotation = Vector3(k * 9.0, k * 5.0, 0.0), 0.0, 1.0, t)
	tween.tween_callback(node.queue_free)


## Dardo acido: una goccia luminosa che fa un arco e cade dove indica l'avviso.
static func _bolt(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var to: Vector3 = d.get("to", at)
	var t: float = float(d.get("t", 0.8))
	var drop := SphereMesh.new()
	drop.radius = 0.32
	drop.height = 0.64
	drop.radial_segments = 8
	drop.rings = 5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("9dff5a")
	mat.emission_enabled = true
	mat.emission = Color("6cff30")
	mat.emission_energy_multiplier = 2.5
	drop.material = mat
	var node := MeshInstance3D.new()
	node.mesh = drop
	world.add_child(node)
	node.global_position = at
	var light := OmniLight3D.new()
	light.light_color = Color("90ff50")
	light.light_energy = 1.0
	light.omni_range = 4.0
	node.add_child(light)
	var height: float = maxf(at.distance_to(to) * 0.28, 2.0)
	var tween := world.create_tween()
	tween.tween_method(func(k: float) -> void:
		if is_instance_valid(node): node.global_position = at.lerp(to, k) + Vector3.UP * sin(k * PI) * height, 0.0, 1.0, t)
	tween.tween_callback(node.queue_free)


## Il velo del Mago: una bolla verde attorno al corpo. on false: si strappa.
static func _veil(world: Node, d: Dictionary) -> void:
	var body := _enemy(world, int(d.get("id", -1)))
	if body == null: return
	var old := body.get_node_or_null("Veil")
	if old: old.queue_free()
	if not d.get("on", false):
		_sound(world, "weapon_hit_guard", body.global_position, 3.0, 1.4)
		return
	var bubble := SphereMesh.new()
	bubble.radius = 2.5
	bubble.height = 5.0
	bubble.radial_segments = 20
	bubble.rings = 10
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.45, 0.95, 0.25, 0.16)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.rim_enabled = false
	bubble.material = mat
	var node := MeshInstance3D.new()
	node.name = "Veil"
	node.mesh = bubble
	body.add_child(node)
	node.position = Vector3.UP * 2.2
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _crown(world: Node, d: Dictionary) -> void:
	var body := _enemy(world, int(d.get("id", -1)))
	if body and body.has_method("set_crown"): body.set_crown(int(d.get("left", 0)))


## Gancio con la catena: parte, arriva e (se back) rientra.
static func _chain(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var to: Vector3 = d.get("to", at)
	var t: float = float(d.get("t", 0.25))
	var back: float = float(d.get("back", 0.25))
	var holder := Node3D.new()
	world.add_child(holder)
	var line := CylinderMesh.new()
	line.top_radius = 0.035
	line.bottom_radius = 0.035
	line.height = 1.0
	line.radial_segments = 5
	line.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6c6f72")
	mat.metallic = 0.5
	line.material = mat
	var cord := MeshInstance3D.new()
	cord.mesh = line
	holder.add_child(cord)
	var tip := MeshInstance3D.new()
	var hook := BoxMesh.new()
	hook.size = Vector3(0.1, 0.32, 0.22)
	hook.material = mat
	tip.mesh = hook
	holder.add_child(tip)
	var place := func(k: float) -> void:
		if not is_instance_valid(holder): return
		var end: Vector3 = at.lerp(to, k)
		var mid: Vector3 = (at + end) * 0.5
		var length: float = maxf(at.distance_to(end), 0.05)
		cord.global_position = mid
		cord.scale = Vector3(1, length, 1)
		if length > 0.1:
			var up: Vector3 = (end - at).normalized()
			var side: Vector3 = up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
			cord.global_basis = Basis(side, up, side.cross(up)).scaled(Vector3(1, length, 1))
		tip.global_position = end
	var tween := world.create_tween()
	tween.tween_method(place, 0.0, 1.0, t)
	tween.tween_method(place, 1.0, 0.0, back)
	tween.tween_callback(holder.queue_free)


## La mannaia lanciata: gira, arriva lontano e torna in mano.
static func _cleaver(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var to: Vector3 = d.get("to", at)
	var t: float = float(d.get("t", 0.6))
	var holder := Node3D.new()
	world.add_child(holder)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("8a8f8c")
	steel.metallic = 0.7
	steel.roughness = 0.35
	var blade := BoxMesh.new()
	blade.size = Vector3(0.75, 0.05, 0.42)
	blade.material = steel
	var part := MeshInstance3D.new()
	part.mesh = blade
	holder.add_child(part)
	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color("3d2a1a")
	var handle := BoxMesh.new()
	handle.size = Vector3(0.42, 0.06, 0.08)
	handle.material = handle_mat
	var grip := MeshInstance3D.new()
	grip.mesh = handle
	holder.add_child(grip)
	grip.position.x = -0.55
	var flight := func(k: float) -> void:
		if not is_instance_valid(holder): return
		holder.global_position = at.lerp(to, k)
		holder.rotation.y = Time.get_ticks_msec() * 0.03
	var tween := world.create_tween()
	tween.tween_method(flight, 0.0, 1.0, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(flight, 1.0, 0.0, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(holder.queue_free)


## Catena che spazza il pavimento attorno al Carceriere. Bassa: si salta.
static func _sweep(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var r: float = float(d.get("r", 9.0))
	var t: float = float(d.get("t", 1.0))
	var a0: float = float(d.get("a0", 0.0))
	var a1: float = float(d.get("a1", TAU))
	var pivot := Node3D.new()
	world.add_child(pivot)
	pivot.global_position = Vector3(at.x, _ground_y(world, at.x, at.z, at.y) + 0.42, at.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("55585b")
	mat.metallic = 0.6
	mat.emission_enabled = true
	mat.emission = Color("7a2a14")
	mat.emission_energy_multiplier = 0.8
	var links := int(r * 2.0)
	for i in links:
		var link := BoxMesh.new()
		link.size = Vector3(0.14, 0.16, 0.36) if i % 2 == 0 else Vector3(0.05, 0.22, 0.36)
		link.material = mat
		var part := MeshInstance3D.new()
		part.mesh = link
		pivot.add_child(part)
		part.position = Vector3(0, 0, -(0.8 + (r - 0.8) * float(i) / links))
	var ball := SphereMesh.new()
	ball.radius = 0.4
	ball.height = 0.8
	ball.radial_segments = 7
	ball.rings = 4
	ball.material = mat
	var weight := MeshInstance3D.new()
	weight.mesh = ball
	pivot.add_child(weight)
	weight.position = Vector3(0, 0, -r)
	pivot.rotation.y = a0
	var tween := world.create_tween()
	tween.tween_property(pivot, "rotation:y", a1, t)
	tween.tween_callback(pivot.queue_free)
	_sound(world, "swing_blunt", at, 2.0, 0.55)


## Sbarre della gabbia che cadono dall'alto e affondano nel pavimento.
static func _cage(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var r: float = float(d.get("r", 3.0))
	var life: float = float(d.get("life", 3.5))
	var gap: float = float(d.get("gap", 0.0))
	var count := 20
	var y: float = _ground_y(world, at.x, at.z, at.y)
	var holder := Node3D.new()
	world.add_child(holder)
	holder.global_position = Vector3(at.x, y + 11.0, at.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3d3f42")
	mat.metallic = 0.5
	for i in count:
		var a: float = TAU * float(i) / count
		if absf(wrapf(a - gap, -PI, PI)) < 0.42: continue
		var bar := CylinderMesh.new()
		bar.top_radius = 0.07
		bar.bottom_radius = 0.07
		bar.height = 3.6
		bar.radial_segments = 5
		bar.rings = 1
		bar.material = mat
		var part := MeshInstance3D.new()
		part.mesh = bar
		holder.add_child(part)
		part.position = Vector3(-sin(a) * r, 1.8, -cos(a) * r)
	var tween := world.create_tween()
	tween.tween_property(holder, "global_position:y", y, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_debris(world, Vector3(at.x, y, at.z), r * 0.6, false)
		_shake_near(world, at, 12.0, 0.7)
		_sound(world, "weapon_hit_guard", at, 3.0, 0.5))
	tween.tween_interval(life)
	tween.tween_property(holder, "global_position:y", y - 4.0, 0.5)
	tween.tween_callback(holder.queue_free)


## Scia del colpo: un arco luminoso all'altezza dell'arma, nel fotogramma esatto in cui il danno arriva.
static func _slash(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var yaw: float = float(d.get("yaw", 0.0))
	var half: float = float(d.get("angle", 1.6)) * 0.5
	var r: float = float(d.get("r", 3.5))
	var color: Color = COLORS.get(d.get("color", "danger"), COLORS.danger)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 14
	for i in steps:
		var a0: float = lerpf(yaw - half, yaw + half, float(i) / steps)
		var a1: float = lerpf(yaw - half, yaw + half, float(i + 1) / steps)
		# Più chiara sul bordo d'attacco: la lama è passata da lì per ultima.
		var k0 := Color(1, 1, 1, float(i) / steps)
		var k1 := Color(1, 1, 1, float(i + 1) / steps)
		var p := [Vector3(-sin(a0), 0, -cos(a0)), Vector3(-sin(a1), 0, -cos(a1))]
		for v in [[p[0] * r * 0.45, k0], [p[0] * r, k0], [p[1] * r, k1], [p[0] * r * 0.45, k0], [p[1] * r, k1], [p[1] * r * 0.45, k1]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	var mat := _material(Color(minf(color.r + 0.3, 1.0), minf(color.g + 0.3, 1.0), minf(color.b + 0.3, 1.0), 0.85), 2.0)
	var node := _instance(world, st.commit(), at + Vector3.UP * float(d.get("h", 1.4)), mat)
	node.rotation.z = float(d.get("tilt", 0.0))
	node.scale = Vector3.ONE * 0.8
	var tween := world.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector3.ONE * 1.08, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3).set_delay(0.18)
	tween.chain().tween_callback(node.queue_free)
	_shake_near(world, at, r + 6.0, float(d.get("shake", 0.3)))


## Scritta che sale dal boss: DEBOLE, RESISTE, CORAZZA ROTTA. Una alla volta: la nuova scaccia la vecchia, mai testi sovrapposti.
static func _pop(world: Node3D, at: Vector3, d: Dictionary) -> void:
	for old in world.get_tree().get_nodes_in_group("boss_pop"):
		if is_instance_valid(old) and (old as Node3D).global_position.distance_to(at) < 4.0: old.queue_free()
	var label := Label3D.new()
	label.add_to_group("boss_pop")
	label.text = String(d.get("text", ""))
	label.font_size = int(d.get("size", 56))
	label.pixel_size = 0.006
	label.outline_size = 14
	label.modulate = d.get("color", Color.WHITE)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	world.add_child(label)
	label.global_position = at
	var tween := world.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", at.y + 1.1, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)


static func _enemy(world: Node, id: int) -> Node3D:
	for body in world.get("targets"):
		if is_instance_valid(body) and body.network_id == id: return body
	return null


## Fase nuova: aura rossa che resta attaccata al boss, più forte a ogni fase.
static func _rage(world: Node, d: Dictionary) -> void:
	var body := _enemy(world, int(d.get("id", -1)))
	if body == null: return
	var level: int = int(d.get("level", 1))
	var old := body.get_node_or_null("BossRage")
	if old: old.free()
	var aura := CPUParticles3D.new()
	aura.name = "BossRage"
	body.add_child(aura)
	aura.position = Vector3.UP * 1.8
	aura.amount = 18 + level * 14
	aura.lifetime = 0.9
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 1.2
	aura.direction = Vector3.UP
	aura.spread = 25.0
	aura.initial_velocity_min = 0.6
	aura.initial_velocity_max = 1.6 + level * 0.6
	aura.gravity = Vector3.ZERO
	var mote := SphereMesh.new()
	mote.radius = 0.07
	mote.height = 0.14
	mote.radial_segments = 6
	mote.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.18, 0.1) if level < 2 else Color(1.0, 0.05, 0.25)
	mote.material = mat
	aura.mesh = mote
	var light := OmniLight3D.new()
	light.light_color = mat.albedo_color
	light.light_energy = 0.8 + level * 0.7
	light.omni_range = 6.0
	aura.add_child(light)
	aura.emitting = true


## Il corpo del boss brucia davvero: fiamme attaccate a lui.
static func _burn(world: Node, d: Dictionary) -> void:
	var body := _enemy(world, int(d.get("id", -1)))
	if body == null: return
	var old := body.get_node_or_null("BossFlames")
	if old: old.free()
	var flames := CPUParticles3D.new()
	flames.name = "BossFlames"
	body.add_child(flames)
	flames.position = Vector3.UP * 2.0
	flames.amount = 40
	flames.lifetime = 0.7
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 1.15
	flames.direction = Vector3.UP
	flames.spread = 15.0
	flames.initial_velocity_min = 1.0
	flames.initial_velocity_max = 3.0
	flames.gravity = Vector3(0, 0.5, 0)
	flames.mesh = _flame_mesh(1.05)
	var light := OmniLight3D.new()
	light.light_color = Color("ff7a30")
	light.light_energy = 1.8
	light.omni_range = 7.0
	flames.add_child(light)
	body.get_tree().create_timer(float(d.get("t", 5.0)), false).timeout.connect(func() -> void:
		if is_instance_valid(flames): flames.queue_free())


## La morte, diversa per ognuno. Solo grafica e suono: il corpo, le ricompense e le porte li gestisce il resto del gioco.
static func _death(world: Node3D, at: Vector3, d: Dictionary) -> void:
	var look: String = d.get("look", "")
	var body := _enemy(world, int(d.get("id", -1)))
	var flash := func(color: Color, t: float) -> void:
		if body: _flash(world, {"id": body.network_id, "t": t, "color": color})
	match look:
		"capomacello":
			# Crolla nel suo stesso fuoco: voragine di brace, fiamme addosso, scoppio del serbatoio.
			_burn(world, {"id": d.get("id", -1), "t": 6.0})
			_patch(world, at, {"r": 4.0, "life": 7.0, "type": "fire"})
			_crack(world, at, {"r": 5.0, "ember": true, "shake": 1.4, "life": 10.0})
			_ring(world, at, {"r": 14.0, "speed": 16.0, "color": "fire"})
			_sound(world, "explosion", at, 5.0, 0.55)
			_sound(world, "boss_capomacello_death", at, 5.0, 1.0)
			flash.call(Color(1.0, 0.5, 0.1, 0.5), 2.0)
		"macellaio":
			# Cade nel sangue: la mannaia gli sfugge di mano e rotola via.
			_splat(world, at, {"r": 4.0, "shake": 1.0, "life": 12.0})
			_cleaver(world, at + Vector3.UP * 1.6, {"to": at + Vector3(2.5, 0.1, 2.5), "t": 0.5})
			_sound(world, "zombie_brute_death", at, 5.0, 0.65)
			_sound(world, "weapon_hit_guard", at, 2.0, 0.7)
			flash.call(Color(0.8, 0.05, 0.05, 0.5), 1.6)
		"carceriere":
			# La corazza salta pezzo per pezzo e il pavimento cede sotto di lui.
			for i in 3:
				world.get_tree().create_timer(i * 0.25).timeout.connect(func() -> void: _plate(world, at + Vector3.UP * (3.4 - i * 0.9)))
			_crack(world, at, {"r": 5.5, "shake": 1.3, "life": 10.0, "look": "carceriere"})
			_ring(world, at, {"r": 12.0, "speed": 10.0, "color": "steel"})
			_sound(world, "boss_carceriere_death", at, 5.0, 1.0)
			flash.call(Color(0.75, 0.82, 0.9, 0.45), 1.6)
		"matriarca":
			# Si dissolve: il velo esplode, il corpo diventa verde e sparisce in una nube.
			_veil(world, {"id": d.get("id", -1), "on": false})
			_patch(world, at, {"r": 3.5, "life": 7.0, "type": "acid"})
			_ring(world, at, {"r": 12.0, "speed": 9.0, "color": "acid"})
			_sound(world, "boss_mago_death", at, 5.0, 1.0)
			flash.call(Color(0.45, 1.0, 0.25, 0.7), 1.8)
			if body:
				var gone := body.create_tween()
				gone.tween_interval(1.6)
				gone.tween_callback(func() -> void:
					if not is_instance_valid(body): return
					_debris(world, body.global_position + Vector3.UP * 1.5, 2.0, false)
					body.visible = false)
		"signore":
			# Perde le teste: i teschi della corona volano via uno per uno, poi cade.
			if body and body.has_method("set_crown"): body.set_crown(0)
			for i in 5:
				var a: float = TAU * float(i) / 5.0
				_boulder(world, at + Vector3.UP * 3.8, {"to": at + Vector3(cos(a) * 5.0, 0.2, sin(a) * 5.0), "t": 0.6 + i * 0.08, "r": 0.3, "color": Color("d0c6a6")})
				world.get_tree().create_timer(0.6 + i * 0.08).timeout.connect(func() -> void: _sound(world, "weapon_hit_bone", at, 1.0, 0.8 + i * 0.12))
			_crack(world, at, {"r": 4.0, "shake": 1.0, "life": 9.0})
			_sound(world, "boss_teste_death", at, 5.0, 1.0)
			flash.call(Color(1.0, 0.95, 0.8, 0.5), 1.6)
	_shake_near(world, at, 30.0, 1.2)


## Carica: polvere e schizzi di sangue dai piedi finché corre.
static func _trail(world: Node, d: Dictionary) -> void:
	var body := _enemy(world, int(d.get("id", -1)))
	if body == null: return
	var dust := CPUParticles3D.new()
	body.add_child(dust)
	dust.position = Vector3.UP * 0.3
	dust.local_coords = false
	dust.amount = 60
	dust.lifetime = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 0.8
	dust.direction = Vector3.UP
	dust.spread = 60.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 3.0
	dust.damping_min = 2.0
	dust.damping_max = 4.0
	dust.gravity = Vector3(0, -2.0, 0)
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 2.0
	var puff := SphereMesh.new()
	puff.radius = 0.22
	puff.height = 0.44
	puff.radial_segments = 6
	puff.rings = 3
	dust.mesh = puff
	dust.color = Color(d.get("color", Color("8a7d66")))
	_sound(world, "zombie_brute_alert", body.global_position, 1.0, 1.3)
	var tween := body.create_tween()
	tween.tween_interval(float(d.get("t", 1.0)))
	tween.tween_callback(func() -> void: if is_instance_valid(dust): dust.emitting = false)
	tween.tween_interval(1.0)
	tween.tween_callback(dust.queue_free)


## Il boss è scoperto: lampeggia sopra i suoi materiali finché dura.
static func _flash(world: Node, d: Dictionary) -> void:
	var body := _enemy(world, int(d.get("id", -1)))
	if body == null: return
	var color: Color = d.get("color", Color(1.0, 0.8, 0.2, 0.3))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.0)
	var meshes := body.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		(mi as MeshInstance3D).material_overlay = mat
	var t: float = float(d.get("t", 1.5))
	var pulses: int = maxi(int(t / 0.4), 1)
	var tween := body.create_tween()
	for i in pulses:
		tween.tween_property(mat, "albedo_color:a", color.a, 0.2)
		tween.tween_property(mat, "albedo_color:a", 0.03, 0.2)
	tween.tween_callback(func() -> void:
		for mi in meshes:
			if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == mat: (mi as MeshInstance3D).material_overlay = null)


## Una piastra della corazza salta via.
static func _plate(world: Node3D, at: Vector3) -> void:
	var bits := CPUParticles3D.new()
	world.add_child(bits)
	bits.global_position = at
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.amount = 16
	bits.lifetime = 1.2
	bits.direction = Vector3.UP
	bits.spread = 80.0
	bits.initial_velocity_min = 4.0
	bits.initial_velocity_max = 8.0
	bits.gravity = Vector3(0, -16, 0)
	bits.angular_velocity_max = 400.0
	var plate := BoxMesh.new()
	plate.size = Vector3(0.42, 0.06, 0.32)
	bits.mesh = plate
	bits.color = Color("5a5e62")
	bits.emitting = true
	world.get_tree().create_timer(1.8).timeout.connect(bits.queue_free)
	_sound(world, "weapon_hit_guard", at, 5.0, 0.7)
	_shake_near(world, at, 14.0, 0.4)
