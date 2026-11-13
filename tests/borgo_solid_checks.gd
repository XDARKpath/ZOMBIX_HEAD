extends SceneTree
# Borgo Cenere solido e percorribile: case fuori dai negozi, cimitero lontano dalla statale, luoghi di fine via
# sul terreno, mobili che non si compenetrano, pali solidi, navmesh dentro le porte e infetti che ti seguono in casa.
# godot --path . -s res://tests/borgo_solid_checks.gd
const L := preload("res://world/villaggio/villaggio_layout.gd")
const Route := preload("res://world/campaign/route.gd")
const Build := preload("res://world/villaggio/borgo_build.gd")
var world: Node3D
var p: CharacterBody3D
var fails: Array = []


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


func wait(frames: int) -> void:
	for i in frames: await physics_frame


## AABB in coordinate di 'base' di tutte le mesh sotto 'node' (anche se 'node' non è nell'albero).
func _box(node: Node, base: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var list: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D: list.append(node)
	for mi in list:
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		var b: AABB = _rel(base, m) * m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Trasformazione di 'node' rispetto a 'base' (vale anche prima che il mondo giri).
func _rel(base: Node, node: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while node != null and node != base:
		if node is Node3D: xf = (node as Node3D).transform * xf
		node = node.get_parent()
	return xf


func _flat(b: AABB) -> Rect2:
	return Rect2(b.position.x, b.position.z, b.size.x, b.size.z)


func _furniture() -> void:
	# 300 stanze con semi diversi: i mobili solidi non si toccano, stanno dentro i muri e nessuno affonda.
	var builder := Build.new()
	root.add_child(builder)
	var bad := 0
	var outside := 0
	var sunk := 0
	for seed in 300:
		builder.rng.seed = seed
		var w := 2 + seed % 3
		var h := Node3D.new()
		builder.add_child(h)
		builder._interior(h, w, seed % 5 == 0, preload("res://world/villaggio/villaggio.gd").SHOP_KIT.values()[seed % 8] if seed % 5 == 1 else [])
		var solid := []
		var bed_x := INF
		for c in h.get_children():
			var b := _box(c, h)
			if b.size == Vector3.ZERO: continue
			if b.position.y < 0.06: sunk += 1
			if not c.find_children("*", "StaticBody3D", true, false).is_empty():
				if c is MeshInstance3D and is_equal_approx(bed_x, (c as Node3D).position.x):
					continue                          # materasso sul telaio del letto: un pezzo solo
				if c is MeshInstance3D: bed_x = (c as Node3D).position.x
				solid.append(b)
				if absf(b.position.x) > w * 1.5 - 0.12 or absf(b.end.x) > w * 1.5 - 0.12 or b.position.z < -4.37:   # muro interno a w*1.5-0.17, 5 cm di tolleranza
					outside += 1
					if outside < 6: print("  fuori dal muro (w %d): %s %s" % [w, c.name, b])
		for i in solid.size():
			for j in range(i + 1, solid.size()):
				if (solid[i] as AABB).grow(-0.02).intersects(solid[j]):
					bad += 1
		h.free()
	builder.free()
	check(bad == 0, "Mobili solidi senza compenetrazioni in 300 stanze (%d)" % bad)
	check(outside == 0, "Mobili dentro i muri (%d fuori)" % outside)
	check(sunk == 0, "Nessun oggetto sotto il pavimento (%d)" % sunk)


func _run() -> void:
	_furniture()
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	await wait(30)
	world.spawner.set_process(false)
	p = world.player
	var village: Node3D = world.village
	var geo: Node3D = village.geo

	# --- Pianta: nessuna casa dentro un negozio o un'altra casa.
	var plans := []
	for c in geo.get_children():
		var n := String(c.name)
		if c.find_child("*Floor_Ceiling*", false, false) and n != "Chiesa":
			var r := Rect2()
			var first := true
			for f in c.get_children():
				if String(f.name).contains("Floor_Ceiling"):
					var fr := _flat(_box(f, geo))
					r = fr if first else r.merge(fr)
					first = false
			if not first: plans.append([n, r])
	var overlaps := 0
	for i in plans.size():
		for j in range(i + 1, plans.size()):
			if (plans[i][1] as Rect2).grow(-0.05).intersects(plans[j][1]):
				overlaps += 1
				print("  sovrapposti: ", plans[i][0], " ", plans[j][0], " ", plans[i][1], " ", plans[j][1])
	check(plans.size() > 40 and overlaps == 0, "%d edifici, nessuna sovrapposizione in pianta (%d)" % [plans.size(), overlaps])

	# --- Cimitero lontano dalla statale.
	var cem: Node3D = geo.get_node("Cimitero")
	var nearest := 999.0
	for body in cem.find_children("*", "StaticBody3D", true, false):
		var at: Vector3 = (body as Node3D).global_position
		nearest = minf(nearest, Route.road_distance(Vector2(at.x, at.z)))
	check(nearest > 8.0, "Cimitero a %.1f m dalla statale" % nearest)

	# --- Luoghi di fine via sul terreno.
	world.terrain.ensure_near([L.CENTER + Vector3(0, 0, -130), L.CENTER + Vector3(-128, 0, 0), L.CENTER + Vector3(-25, 0, 120)])
	for site in ["Chiesa", "Cimitero", "CampoProfughi", "Fattoria"]:
		var b := _box(geo.get_node(site), geo)
		var worst := 0.0
		var x := b.position.x
		while x <= b.end.x:
			var z := b.position.z
			while z <= b.end.z:
				worst = maxf(worst, world.terrain.height(L.CENTER.x + x, L.CENTER.z + z))
				z += 1.0
			x += 1.0
		check(worst < 0.05, "%s: terreno sotto la pianta al massimo %.2f m" % [site, worst])

	# --- Pali e lampioni: quello che sembra un palo si urta.
	var loose := 0
	for mi in geo.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh is CylinderMesh and (m.mesh as CylinderMesh).height >= 2.0 and (m.mesh as CylinderMesh).top_radius > 0.03 \
				and m.global_position.y < 4.0 and m.find_children("*", "StaticBody3D", true, false).is_empty():
			loose += 1
	check(loose == 0, "Lampioni solidi (%d attraversabili)" % loose)

	# --- Navmesh: dalla via si arriva dentro ogni casa con porta, nei negozi e nei luoghi di fine via.
	var t := 0.0
	while village.nav.navigation_mesh.get_polygon_count() == 0 and t < 120.0:
		await process_frame
		t += 0.02
	await wait(20)
	var map: RID = world.get_world_3d().navigation_map
	var doors := 0
	var reached := 0
	for c in geo.get_children():
		if not c.has_meta("door_x"): continue
		doors += 1
		var h := c as Node3D
		var from := h.to_global(Vector3(h.get_meta("door_x"), 0, 12.5))     # in mezzo alla via
		var to := h.to_global(Vector3(h.get_meta("door_x"), 0.1, 2.0))
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		if path.size() > 0 and path[path.size() - 1].distance_to(to) < 0.6:
			reached += 1
		else:
			print("  non si entra: ", h.name, " ", h.position, " porta ", h.get_meta("door_x"), " fine ", h.to_local(path[path.size() - 1]) if path.size() else "-")
			for k in h.get_children():
				var kb := _box(k, h)
				if kb.size != Vector3.ZERO and kb.end.z > 2.5 and kb.position.z < 6.5 and absf(kb.get_center().x - float(h.get_meta("door_x"))) < 2.0 + kb.size.x * 0.5:
					print("    vicino alla porta: ", k.name, " ", kb)
	check(doors > 30 and reached == doors, "Percorso dalla via dentro %d/%d edifici con porta" % [reached, doors])
	# chiesa (fra le panche), cimitero, campo profughi, davanti al fienile
	for local in [Vector3(0, 0.2, -131), village.CEMETERY + Vector3(1.3, 0.2, -1.7), Vector3(-128.5, 0.2, 4), Vector3(-14, 0.2, 120.5)]:
		var world_at: Vector3 = L.CENTER + local
		var near := NavigationServer3D.map_get_closest_point(map, world_at)
		check(Vector2(near.x, near.z).distance_to(Vector2(world_at.x, world_at.z)) < 0.6, "Navmesh a %s (%.2f m)" % [local, Vector2(near.x, near.z).distance_to(Vector2(world_at.x, world_at.z))])

	# --- Barricate: chi sta sulla linea finisce in piazza; su-giù-su in fretta non lascia buchi.
	p.reset_at(L.CENTER + Vector3(0, 0.1, -(village.PLAZA - 0.6)))
	await wait(5)
	village.set_barricades(true)
	await wait(90)
	var rel: Vector3 = p.global_position - L.CENTER
	check(absf(rel.z) < village.PLAZA - 1.0, "La barricata che sale porta il giocatore in piazza (z %.2f)" % rel.z)
	village.set_barricades(false)
	await wait(20)
	village.set_barricades(true)
	await wait(150)
	var holes := 0
	for b in village.barricades:
		if (b.get_meta("shape") as CollisionShape3D).disabled or absf(b.position.y - L.CENTER.y) > 0.05: holes += 1
	check(holes == 0, "Su, giù e su in fretta: tutte le barricate alzate e solide (%d no)" % holes)
	village.set_barricades(false)
	await wait(120)

	# --- Inseguimento vero: un infetto dalla via entra in casa e nel campo profughi.
	var house: Node3D = null
	for c in geo.get_children():
		if c.has_meta("door_x") and float(c.get_meta("door_x")) == 0.0 and c.find_child("*Brick_Door*", false, false):
			house = c
			break
	# un infetto per ogni lato dell'accerchiamento (network_id % 5): tutti devono entrare
	for side in 5:
		await _chase("casa (lato %d)" % side, house.to_global(Vector3(-1.5, 0.3, -2.0)), house.to_global(Vector3(house.get_meta("door_x"), 0.3, 16.0)), house, side)
	await _chase("campo profughi", L.CENTER + Vector3(-128.5, 0.3, 4.0), L.CENTER + Vector3(-100, 0.3, 0), null)
	print("FALLITI: ", fails.size())
	for f in fails: print("  - ", f)
	quit(1 if fails.size() > 0 else 0)


func _chase(where: String, hide: Vector3, start: Vector3, house: Node3D, side := -1) -> void:
	world.terrain.ensure_near([hide, start])
	p.reset_at(hide)
	await wait(10)
	var e: Node3D = world._spawn_enemy(start)
	e.set_kind(1)                                # corridore: stessa navigazione, prova più corta
	if side >= 0: e.network_id += side - e.network_id % 5
	await wait(5)
	var best := 999.0
	for i in 60 * 45:
		p.health = 100.0
		if i % 30 == 0: e.hear(p, 100.0)
		await physics_frame
		best = minf(best, e.global_position.distance_to(p.global_position))
		if i % 120 == 0: print("  %s: infetto a %s (casa %s), stato %d, distanza %.1f" % [where, e.global_position.snapped(Vector3.ONE * 0.1), house.to_local(e.global_position).snapped(Vector3.ONE * 0.1) if house else "-", e.state, best])
		if best < e.attack_reach + 0.3: break
	var inside := house == null or (absf(house.to_local(e.global_position).x) < 6.0 and absf(house.to_local(e.global_position).z) < 4.3)
	check(best < e.attack_reach + 0.3 and inside, "L'infetto raggiunge il giocatore nel %s (a %.1f m, dentro %s)" % [where, best, inside])
	e.queue_free()
