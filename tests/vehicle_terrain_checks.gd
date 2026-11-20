extends SceneTree
# Veicoli sul terreno, senza prove a mano: assetto del 4×4 guidato davvero lungo la statale e fuori strada
# (ruote a terra, inclinazione come il terreno), camion solidi come la loro sagoma (zona 1, Porto Secco, deserto,
# valichi) ed erba spenta dentro gli abitacoli.
# godot --path . -s res://tests/vehicle_terrain_checks.gd
const Route := preload("res://world/campaign/route.gd")
var Terrain: GDScript      # caricato dopo l'avvio: col preload in un SceneTree non vede l'autoload Session
const Grass := preload("res://world/grass/grass_field.gd")
const WHEEL_R := 0.445
const HUBS := [Vector3(-0.86, 0, -1.02), Vector3(0.86, 0, -1.02), Vector3(-0.86, 0, 1.02), Vector3(0.86, 0, 1.02)]
var world: Node3D
var p: CharacterBody3D
var car: CharacterBody3D
var fails: Array = []


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


func wait(frames: int) -> void:
	for i in frames: await physics_frame


func ray(from: Vector3, to: Vector3) -> Dictionary:
	return root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


func quantile(list: Array, q: float) -> float:
	if list.is_empty(): return INF
	var s := list.duplicate()
	s.sort()
	return s[clampi(int(q * (s.size() - 1)), 0, s.size() - 1)]


## Beccheggio e rollio che il terreno vero (terrain.gd, non i raggi del 4×4) dà sotto le quattro ruote.
func ground_tilt() -> Vector2:
	var h: Array[float] = []
	for hub in HUBS:
		var at: Vector3 = car.to_global(hub)
		h.append(Terrain.ground_height(at.x, at.z) - car.global_position.y)
	return Vector2(atan2((h[0] + h[1]) - (h[2] + h[3]), 4.08), atan2((h[1] + h[3]) - (h[0] + h[2]), 3.44))


## Guida per "frames" fotogrammi tenendo la rotta (heading = funzione della posizione) e misura ogni fotogramma in moto.
func drive(start: Vector3, heading: Callable, frames: int, gaps: Array, tilt_err: Array, slopes: Array) -> float:
	world.terrain.ensure_near([start])
	car.position = Vector3(start.x, Terrain.ground_height(start.x, start.z) + 0.3, start.z)
	car.rotation.y = heading.call(car.position)
	car.speed = 0.0; car.velocity = Vector3.ZERO
	await wait(40)
	var from := car.position
	Input.action_press("move_forward", 0.6)
	for i in frames:
		car.rotation.y = heading.call(car.position)
		await physics_frame
		if absf(car.speed) < 3.0 or i < 30: continue
		var up: Vector3 = car.visual.global_basis.y
		for w in car.visual.wheels:
			var bottom: Vector3 = (w as Node3D).global_position - up * WHEEL_R
			var hit := ray(bottom + Vector3.UP * 1.5, bottom + Vector3.DOWN * 2.5)
			if hit: gaps.append(bottom.y - hit.position.y)
		var want := ground_tilt()
		tilt_err.append(maxf(absf(car.visual.rotation.x - want.x), absf(car.visual.rotation.z - want.y)))
		slopes.append(maxf(absf(want.x), absf(want.y)))
	Input.action_release("move_forward")
	return Vector2(car.position.x - from.x, car.position.z - from.z).length()


## Linee in pendenza lontano dalla statale: si guida di sbieco alla pendenza, così ci sono beccheggio e rollio insieme.
func slope_lines() -> Array:
	var out: Array = []
	var road: Array = Route.road_points()
	var walked := 0.0
	for i in range(road.size() - 1):
		var a: Vector3 = road[i]
		var b: Vector3 = road[i + 1]
		var n := int((walked + a.distance_to(b)) / 60.0) - int(walked / 60.0)
		walked += a.distance_to(b)
		for k in n:
			var at: Vector3 = a.lerp(b, (float(k) + 0.5) / n)
			if walked < 200.0 or absf(at.z - Route.WALL_Z) < 150.0: continue
			var side := (b - a).normalized().cross(Vector3.UP)
			for d in [40.0, 70.0, 100.0, -40.0, -70.0, -100.0]:
				var q: Vector3 = at + side * d
				var g := Vector2(Terrain.ground_height(q.x + 3, q.z) - Terrain.ground_height(q.x - 3, q.z), Terrain.ground_height(q.x, q.z + 3) - Terrain.ground_height(q.x, q.z - 3)) / 6.0
				if g.length() < 0.1 or g.length() > 0.4: continue
				var dir := Vector3(g.x, 0, g.y).normalized().rotated(Vector3.UP, PI / 4)
				var end := q + dir * 40.0
				if Route.road_distance(Vector2(end.x, end.z)) < 14.0 or Route.road_distance(Vector2(q.x, q.z)) < 14.0 or not Route.inside(end): continue
				out.append([q, atan2(-dir.x, -dir.z)])
				break
			if out.size() >= 6: return out
	return out


func ranger_attitude() -> void:
	var peer: int = root.multiplayer.get_unique_id()
	car.repaired = true
	world.expedition.collected = [true, true, true]; world.expedition.stage = 2
	p.reset_at(car.to_global(Vector3(-2.0, 0.3, 0)))
	await wait(5)
	check(car.interact(peer), "Si sale alla guida del 4×4")
	# Statale: un tratto dopo il paese e il ponte (l'unico pezzo in salita: la strada altrove è piana), seguendo la mezzeria.
	var follow := func(at: Vector3) -> float:
		var ahead: Vector3 = Route.nearest_road(at + Route.road_direction(at) * 12.0) + Route.road_direction(at) * 6.0
		return atan2(-(ahead.x - at.x), -(ahead.z - at.z))
	var gaps: Array = []; var err: Array = []; var slopes: Array = []
	var went: float = await drive(Route.nearest_road(Vector3(40, 0, -320)), follow, 300, gaps, err, slopes)
	var bridge: Vector3 = Route.nearest_road(Vector3(2406, 0, -1356))
	went += await drive(Route.nearest_road(bridge - Route.road_direction(bridge) * 70.0), follow, 300, gaps, err, slopes)
	print("  statale: %.0f m, %d misure; ruota peggiore mediana %.3f p90 %.3f min %.3f; scarto d'inclinazione p90 %.3f rad (pendenza max %.2f)" % [went, gaps.size(), quantile(gaps.map(func(g): return absf(g)), 0.5), quantile(gaps.map(func(g): return absf(g)), 0.9), quantile(gaps, 0.0), quantile(err, 0.9), quantile(slopes, 1.0)])
	check(went > 80.0 and gaps.size() > 800 and quantile(slopes, 1.0) > 0.05, "4×4 sulla statale: guidato per %.0f m, ponte compreso (pendenza max %.2f rad)" % [went, quantile(slopes, 1.0)])
	check(quantile(gaps.map(func(g): return absf(g)), 0.9) < 0.08 and quantile(gaps, 0.0) > -0.12, "4×4 sulla statale: ruote a terra (p90 %.3f m, più affondata %.3f m)" % [quantile(gaps.map(func(g): return absf(g)), 0.9), quantile(gaps, 0.0)])
	check(quantile(err, 0.9) < 0.05, "4×4 sulla statale: carrozzeria inclinata come la strada (p90 scarto %.3f rad)" % quantile(err, 0.9))
	# Fuori strada, in pendenza.
	var lines := slope_lines()
	gaps = []; err = []; slopes = []
	went = 0.0
	for line in lines:
		var yaw: float = line[1]
		went += await drive(line[0], func(_at: Vector3) -> float: return yaw, 160, gaps, err, slopes)
	var abs_gaps: Array = gaps.map(func(g): return absf(g))
	print("  fuori strada: %d linee, %.0f m, %d misure; ruota mediana %.3f p90 %.3f min %.3f (p1 %.3f, p5 %.3f); scarto d'inclinazione mediana %.3f p90 %.3f rad; pendenza mediana %.2f max %.2f" % [lines.size(), went, gaps.size(), quantile(abs_gaps, 0.5), quantile(abs_gaps, 0.9), quantile(gaps, 0.0), quantile(gaps, 0.01), quantile(gaps, 0.05), quantile(err, 0.5), quantile(err, 0.9), quantile(slopes, 0.5), quantile(slopes, 1.0)])
	check(lines.size() >= 3 and gaps.size() > 300 and quantile(slopes, 0.5) > 0.08, "4×4 fuori strada: %d tratti in pendenza guidati (pendenza mediana %.2f rad)" % [lines.size(), quantile(slopes, 0.5)])
	check(quantile(abs_gaps, 0.5) < 0.08 and quantile(abs_gaps, 0.9) < 0.2 and quantile(gaps, 0.0) > -0.2, "4×4 fuori strada: ruote a terra (mediana %.3f, p90 %.3f, più affondata %.3f m)" % [quantile(abs_gaps, 0.5), quantile(abs_gaps, 0.9), quantile(gaps, 0.0)])
	check(quantile(err, 0.9) < 0.08, "4×4 fuori strada: si inclina come il pendio (p90 scarto %.3f rad)" % quantile(err, 0.9))
	# Di nuovo fermo, parcheggiato al paese: serve alla prova dell'erba.
	car.position = Vector3(19.5, 0.2, 3.6); car.rotation.y = PI / 2; car.speed = 0.0; car.velocity = Vector3.ZERO
	await wait(10)
	car.interact(peer)
	await wait(20)


## Camion: raggi dai fianchi e dall'alto, in coordinate del camion. Ai valichi il muro è più alto: lì conta il fianco a sud.
func trucks() -> void:
	var found: Array = []
	for n in root.find_children("*", "Node3D", true, false):
		if (n as Node3D).scene_file_path.ends_with("SM_Borgo_Truck_Wreck.glb") and (n as Node3D).is_visible_in_tree(): found.append(n)
	var bad := 0
	var tested := 0
	for t in found:
		var truck := t as Node3D
		world.terrain.ensure_near([truck.global_position])
	await wait(30)
	for t in found:
		var truck := t as Node3D
		var gate: Node3D = truck.get_parent() if String(truck.get_parent().name).begins_with("Gate") else null
		var sides := [1.0, -1.0]
		if gate: sides = [1.0 if truck.global_basis.x.dot(gate.global_basis.z) > 0.0 else -1.0]
		var problems: Array = []
		for z in [-1.0, 2.6]:
			var expect: float = 2.0 - (1.25 if z < 0.0 else 1.15)
			var y: float = 1.6 if z < 0.0 else 1.3        # cabina: portiera sotto il finestrino (nei relitti a trimesh il vetro rotto è aperto)
			for s in sides:
				var hit := ray(truck.to_global(Vector3(2.0 * s, y, z)), truck.to_global(Vector3(0, y, z)))
				var d: float = (hit.position - truck.to_global(Vector3(2.0 * s, y, z))).length() if hit else INF
				if absf(d - expect) > 0.35: problems.append("fianco %+d z %.1f: %.2f invece di %.2f" % [s, z, d, expect])
			if not gate:
				var top := ray(truck.to_global(Vector3(0, 6.0, z)), truck.to_global(Vector3(0, -1.0, z)))
				var roof: float = truck.to_local(top.position).y if top else -INF
				if absf(roof - (2.55 if z < 0.0 else 2.4)) > 0.2: problems.append("tetto z %.1f a %.2f" % [z, roof])
		tested += 1
		if not problems.is_empty():
			bad += 1
			print("  camion ", truck.get_path(), " ", truck.global_position.snapped(Vector3.ONE * 0.1), ": ", problems)
	check(tested >= 12 and bad == 0, "Camion solidi come la sagoma: %d su %d (porto, deserto, valichi, zona 1)" % [tested - bad, tested])


## Erba: la maschera letta come la legge lo shader (lineare, celle da 2 m) dentro gli abitacoli.
func sample(field: Node, at: Vector3) -> float:
	var img: Image = field._mask
	var fx: float = (at.x - Grass.ORIGIN.x) / Grass.MASK_STEP - 0.5
	var fz: float = (at.z - Grass.ORIGIN.y) / Grass.MASK_STEP - 0.5
	var x0 := floori(fx); var z0 := floori(fz)
	var tx := fx - x0; var tz := fz - z0
	var v := func(x: int, z: int) -> float: return img.get_pixel(clampi(x, 0, img.get_width() - 1), clampi(z, 0, img.get_height() - 1)).r
	return lerpf(lerpf(v.call(x0, z0), v.call(x0 + 1, z0), tx), lerpf(v.call(x0, z0 + 1), v.call(x0 + 1, z0 + 1), tx), tz)


func grass() -> void:
	var field: Node = root.get_tree().get_first_node_in_group("grass_field")
	if field == null:
		check(false, "Erba GPU presente")
		return
	world.terrain.ensure_near([Vector3(40, 0, -320), Vector3(60, 0, -700)])
	await wait(60)
	var worst := 0.0
	var worst_at := ""
	var inside := 0
	field._update_holes(10.0)   # la buca del 4×4 fermo arriva in dissolvenza: qui la si porta subito al pieno
	var all: Dictionary = field.holes.duplicate()
	if not field._car_hole.is_empty(): all["ranger"] = field._car_hole
	for key in all:
		var at: Transform3D = all[key][0]
		var box: AABB = all[key][1]
		var c: Vector3 = at * box.get_center()
		if c.x < Grass.ORIGIN.x or c.z < Grass.ORIGIN.y or c.x > Grass.ORIGIN.x + Grass.SIZE.x or c.z > Grass.ORIGIN.y + Grass.SIZE.y: continue
		inside += 1
		var x := box.position.x + 0.3
		while x <= box.end.x - 0.3:
			var z := box.position.z + 0.3
			while z <= box.end.z - 0.3:
				var d := sample(field, at * Vector3(x, 0, z))
				if d > worst: worst = d; worst_at = "%s %s" % [key, (at * Vector3(x, 0, z)).snapped(Vector3.ONE * 0.1)]
				z += 0.25
			x += 0.25
	var t0 := Time.get_ticks_usec()
	field._dirty = true
	field._update_holes()
	var cost := (Time.get_ticks_usec() - t0) / 1000.0
	print("  veicoli nel prato: %d (4×4 fermo: %s), densità massima negli abitacoli %.3f (%s), ridisegno maschera %.2f ms" % [inside, all.has("ranger"), worst, worst_at, cost])
	check(inside >= 5 and all.has("ranger"), "Erba: buche sotto %d veicoli fermi, 4×4 parcheggiato compreso" % inside)
	check(worst < 0.05, "Erba: niente ciuffi negli abitacoli (densità massima %.3f)" % worst)
	check(cost < 8.0, "Erba: ridisegno della maschera in %.2f ms" % cost)
	# In moto il 4×4 non lascia la buca dove passa: sfuma e torna quando si ferma.
	car.speed = 6.0
	field._update_holes(0.1)
	var fading: bool = field._car_fade > 0.0 and field._car_fade < 1.0
	field._update_holes(10.0)
	var moving_gone: bool = field._car_fade == 0.0
	car.speed = 0.0
	field._update_holes(10.0)
	check(fading and moving_gone and field._car_fade == 1.0, "Erba: la buca del 4×4 c'è solo da fermo e sfuma in marcia")


func _run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	p = world.player
	world.spawner.set_process(false)
	for e in world.targets:
		if is_instance_valid(e): e.set_physics_process(false); e.global_position += Vector3(0, -300, 0)
	car = world.expedition.car
	Terrain = load("res://world/campaign/terrain.gd")
	await ranger_attitude()
	await grass()
	await trucks()
	print("ESITO ", "OK" if fails.is_empty() else "FALLITI %d" % fails.size())
	quit(0 if fails.is_empty() else 1)
