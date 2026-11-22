# BORGO CENERE, seconda mano: quello che una via abbandonata ha in più di case e lampioni.
# Scritte sui muri, bidoni e sacchi, cassonetti, auto parcheggiate e lasciate lì, cartacce sull'asfalto,
# targhe delle vie, qualche luce rimasta accesa dentro. SurrounDead solo come riferimento di densità:
# niente asset, codice o file suoi. Pezzi: kit originale art/zx_borgo e scatole fatte qui.
# Ha un suo generatore di numeri: la pianta del borgo (case, lotti, auto già presenti) non cambia.
extends RefCounted

const BK := "res://art/zx_borgo/"
const CARS := ["SM_Borgo_Car_Wreck.glb", "SM_Borgo_Car_Wreck_Red.glb", "SM_Borgo_Car_Wreck_Burnt.glb", "SM_Borgo_Truck_Wreck.glb"]
const WORDS := ["AIUTO", "NON ENTRATE", "INFETTI DENTRO", "SIAMO AL RIFUGIO", "3 VIVI", "NIENTE CIBO", "VIA DI QUI", "X", "MORSI. NON APRIRE", "TORNIAMO"]
const PAINT := [Color("8e1f17"), Color("1d1b19"), Color("d9d3c3"), Color("8e1f17")]
const STREET_NAMES := {"N": "VIA DELLA CHIESA", "S": "VIA DEI CAMPI", "O": "VIA DEL CAMPO", "E": "VIA PROVINCIALE"}
const ROAD_TOP := 0.065            # asfalto delle vie (terrain.gd: lift 0.060)
const MAX_LIGHTS := 7


static func dress(v: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	var houses: Array = []
	for child in v.geo.get_children():
		if child.has_meta("door_x"): houses.append(child)
	var taken: Array = []                    # punti già occupati (locali al borgo): lampioni, pali, auto, detriti
	for child in v.geo.get_children():
		if child is Node3D and not child.has_meta("door_x"): taken.append((child as Node3D).position)
	var cars: Array = []                     # relitti già sulle vie: un'auto è lunga 4,8 m
	var doors: Array = []                    # davanti alle porte niente auto: gli infetti entrano dritti
	for h in houses:
		doors.append(h.position + h.basis * Vector3(float(h.get_meta("door_x")), 0, 4.5))
	for child in v.geo.get_children():
		if "Wreck" in child.scene_file_path: cars.append((child as Node3D).position)
	var lights := 0
	for h in houses:
		lights += _house(v, h, houses, rng, lights < MAX_LIGHTS)
	for key in v.DIRS:
		_street(v, key, houses, taken, cars, doors, rng)
		_street_sign(v, key)


## Una casa: scritta sul muro di lato, bidone e sacchi accanto, a volte una luce dentro. Ritorna le luci messe.
static func _house(v: Node3D, h: Node3D, others: Array, rng: RandomNumberGenerator, light_ok: bool) -> int:
	if not ((h.get_child(0) as MeshInstance3D) and (h.get_child(0) as MeshInstance3D).mesh is BoxMesh):
		return 0                             # negozio della piazza: ha già insegna, tenda e vetrina
	var half := _half(h) - 0.25
	var burnt := not (_has_scene(h, "Bld_Roof_01") or _has_scene(h, "Roof_Flat"))      # casa bruciata: restano le capriate
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	if rng.randf() < 0.4:
		var tag := Label3D.new()
		h.add_child(tag)
		tag.name = "Scritta"
		tag.text = WORDS[rng.randi_range(0, WORDS.size() - 1)]
		tag.position = Vector3(side * (half + 0.21), rng.randf_range(1.2, 1.9), rng.randf_range(-2.0, 2.4))
		tag.rotation = Vector3(0, side * PI / 2, rng.randf_range(-0.09, 0.09))
		tag.font_size = 56
		tag.pixel_size = 0.011
		tag.outline_size = 0
		tag.double_sided = false
		tag.modulate = PAINT[rng.randi_range(0, PAINT.size() - 1)]
		tag.modulate.a = 0.85
	# dall'altra parte: bidone (a volte rovesciato) e sacchi, contro il muro di lato, non davanti alla porta
	if rng.randf() < 0.55 and _alley_wide(h, Vector3(-side * (half + 1.2), 0, 1.4), others):
		# lontano dalla porta (tests/borgo_solid_checks: niente corpi davanti all'ingresso, z > 2.5)
		var at := Vector3(-side * (half + 1.2), 0, 1.4)
		var bin := _bin(v, h, at, rng)
		if rng.randf() < 0.25:
			bin.rotation = Vector3(PI / 2, rng.randf_range(-0.5, 0.5), 0)
			bin.position += Vector3(0, 0.34, -0.6)
		for i in rng.randi_range(1, 4):
			v.asset(h, "Prop_Bag_01", at + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-1.6, -0.5)), rng.randf_range(0, TAU), false, Vector3.ONE * rng.randf_range(4, 6))
	if light_ok and not burnt and rng.randf() < 0.18:
		# qualcuno ha lasciato una lampada accesa: dalla via si vede la finestra calda
		var lamp := OmniLight3D.new()
		h.add_child(lamp)
		lamp.name = "LampadaAccesa"
		lamp.position = Vector3(rng.randf_range(-half + 1.2, half - 1.2), 2.1, rng.randf_range(-3.2, -1.8))   # in fondo alla stanza, lontano dalla porta
		lamp.light_color = Color("ffc27a")
		lamp.light_energy = 1.4
		lamp.omni_range = 5.5
		lamp.shadow_enabled = false
		v.box(h, lamp.position + Vector3(0, 0.35, 0), Vector3(0.3, 0.22, 0.3), Color("e9d3a0"), false)   # paralume
		return 1
	return 0


## Bidone carrellato: scatola verde o grigia con il coperchio. Solido.
static func _bin(v: Node3D, parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	g.name = "Bidone"
	g.position = at
	g.rotation.y = rng.randf_range(-0.4, 0.4)
	var color: Color = [Color("3d5a3a"), Color("4a4f4c"), Color("6b5a2e")][rng.randi_range(0, 2)]
	v.box(g, Vector3(0, 0.5, 0), Vector3(0.62, 1.0, 0.7), color, true)
	v.box(g, Vector3(0, 1.03, 0.02), Vector3(0.66, 0.06, 0.76), color.darkened(0.25), false)
	return g


## Cassonetto della via: grande, con due coperchi, uno alzato.
static func _dumpster(v: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var g := Node3D.new()
	v.geo.add_child(g)
	g.name = "Cassonetto"
	g.position = at
	g.rotation.y = yaw
	var color: Color = [Color("2f4a3a"), Color("51544e"), Color("6a3b2b")][rng.randi_range(0, 2)]
	v.box(g, Vector3(0, 0.62, 0), Vector3(1.9, 1.15, 1.15), color, true)
	v.box(g, Vector3(-0.48, 1.23, 0), Vector3(0.94, 0.05, 1.2), color.darkened(0.3), false)
	var lid: Node3D = v.box(g, Vector3(0.48, 1.55, -0.55), Vector3(0.94, 0.05, 0.7), color.darkened(0.3), false)
	lid.rotation.x = -1.2
	for i in rng.randi_range(2, 5):
		v.asset(g, "Prop_Bag_01", Vector3(rng.randf_range(-1.1, 1.1), 0, rng.randf_range(0.75, 1.5)), rng.randf_range(0, TAU), false, Vector3.ONE * rng.randf_range(4, 6))
	if rng.randf() < 0.5:
		v.asset(g, "Prop_Papers_01", Vector3(rng.randf_range(-1, 1), 0.02, rng.randf_range(0.9, 1.8)), rng.randf_range(0, TAU), false, Vector3.ONE * 0.6)


## Una via: nei vuoti fra due case della stessa fila un cassonetto, un'auto parcheggiata o una catasta.
## Sull'asfalto cartacce. Tutto fuori dalla corsia: il 4×4 passa sempre (le auto al bordo, come quelle già presenti).
static func _street(v: Node3D, key: String, houses: Array, taken: Array, cars: Array, doors: Array, rng: RandomNumberGenerator) -> void:
	var d: Vector2 = v.DIRS[key]
	var dir := Vector3(d.x, 0, d.y)
	var side_v := Vector3(-d.y, 0, d.x)
	var length: float = v.STREET_LEN if key != "E" else 72.0
	for s in [-1.0, 1.0]:
		var row: Array = []                       # [lungo la via, mezza larghezza] delle case su questo lato
		for h in houses:
			var p: Vector3 = h.position
			var along := p.dot(dir)
			var lateral: float = p.dot(side_v) * s
			if along > v.PLAZA and lateral > 6.0 and lateral < 20.0:
				row.append([along, _half(h)])
		row.sort_custom(func(a, b): return a[0] < b[0])
		for i in row.size() - 1:
			var gap: float = row[i + 1][0] - row[i + 1][1] - (row[i][0] + row[i][1])
			if gap < 4.0:
				continue
			var mid: float = (row[i][0] + row[i][1] + row[i + 1][0] - row[i + 1][1]) * 0.5
			# a metà del vuoto stanno già lampioni e pali: si prova un po' prima o un po' dopo
			var tries: Array = [mid + 2.8, mid - 2.8] if gap >= 7.6 else [mid]
			var roll := rng.randf()
			for along in tries:
				if roll < 0.4:
					var at: Vector3 = dir * along + side_v * s * 6.3
					if _free(taken, at, 2.4):
						_dumpster(v, at, atan2(-s * side_v.x, -s * side_v.z), rng)   # coperchi verso la via
						taken.append(at)
						break
				elif roll < 0.72:
					var at: Vector3 = dir * along + side_v * s * 3.6 + Vector3(0, ROAD_TOP - 0.005, 0)
					if _free(taken, at, 2.4) and _free(cars, at, 5.6) and _clear_of_doors(doors, at, dir):
						var car: Node3D = v._glb(v.geo, BK + CARS[rng.randi_range(0, CARS.size() - 1)], at, atan2(dir.x, dir.z) + (PI if s > 0 else 0.0) + rng.randf_range(-0.08, 0.08))
						car.name = "AutoParcheggiata"
						taken.append(at)
						cars.append(at)
						break
				elif roll < 0.9:
					var at: Vector3 = dir * along + side_v * s * 7.0
					if _free(taken, at, 2.2):
						v.asset(v.geo, "Prop_Pallet_01", at, rng.randf_range(0, TAU), true)
						for k in rng.randi_range(1, 3):
							v.asset(v.geo, "Prop_Bag_01", at + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)), rng.randf_range(0, TAU), false, Vector3.ONE * rng.randf_range(4, 6))
						taken.append(at)
						break
	# auto lasciate al bordo davanti alle case (anche davanti alle porte: la rampa resta libera, la corsia pure)
	for s in [-1.0, 1.0]:
		var along: float = v.PLAZA + 14.0
		while along < v.PLAZA + length - 6.0:
			var at: Vector3 = dir * along + side_v * s * 3.6 + Vector3(0, ROAD_TOP - 0.005, 0)
			if rng.randf() < 0.3 and _free(taken, at, 2.4) and _free(cars, at, 6.0) and _clear_of_doors(doors, at, dir):
				var car: Node3D = v._glb(v.geo, BK + CARS[rng.randi_range(0, CARS.size() - 1)], at, atan2(dir.x, dir.z) + (PI if s > 0 else 0.0) + rng.randf_range(-0.1, 0.1))
				car.name = "AutoParcheggiata"
				taken.append(at)
				cars.append(at)
			along += rng.randf_range(9.0, 14.0)
	# cartacce e foglie sull'asfalto, più fitte vicino ai bordi
	var t: float = v.PLAZA + 6.0
	while t < v.PLAZA + length:
		var lat: float = rng.randf_range(-3.3, 3.3)
		v.asset(v.geo, "Prop_Papers_01", dir * t + side_v * lat + Vector3(0, ROAD_TOP + 0.01, 0), rng.randf_range(0, TAU), false, Vector3.ONE * rng.randf_range(0.35, 0.55))
		t += rng.randf_range(5.0, 11.0)


## Mezza larghezza di una casa dallo zoccolo (w*3 + 0.5); i negozi della piazza non lo hanno.
static func _half(h: Node3D) -> float:
	var base := h.get_child(0) as MeshInstance3D
	if base != null and base.mesh is BoxMesh: return (base.mesh as BoxMesh).size.x * 0.5
	return 6.0


static func _has_scene(h: Node3D, part: String) -> bool:
	for c in h.get_children():
		if part in c.scene_file_path: return true
	return false


## Un'auto lunga 4,8 m non sta davanti a una porta (5 m di qua e di là lungo la via, entro 12 m di lato).
static func _clear_of_doors(doors: Array, at: Vector3, dir: Vector3) -> bool:
	for door in doors:
		var off: Vector3 = door - at
		if absf(off.dot(dir)) < 5.0 and Vector2(off.x, off.z).length() < 12.0: return false
	return true


## Il bidone accanto alla casa non chiude il passaggio verso la casa vicina (4 m liberi oltre il bidone).
static func _alley_wide(h: Node3D, local_at: Vector3, others: Array) -> bool:
	var at: Vector3 = h.position + h.basis * local_at
	for o in others:
		if o == h: continue
		var l: Vector3 = (o as Node3D).basis.inverse() * (at - (o as Node3D).position)
		if absf(l.x) < _half(o) + 4.0 and absf(l.z) < 9.0: return false
	return true


static func _free(taken: Array, at: Vector3, radius: float) -> bool:
	for p in taken:
		if Vector2(p.x - at.x, p.z - at.z).length() < radius: return false
	return true


## Targa della via all'angolo con la piazza: palo sottile (solido) e targa bianca a bordo scuro.
static func _street_sign(v: Node3D, key: String) -> void:
	var d: Vector2 = v.DIRS[key]
	var dir := Vector3(d.x, 0, d.y)
	var side_v := Vector3(-d.y, 0, d.x)
	var g := Node3D.new()
	v.geo.add_child(g)
	g.name = "TargaVia"
	g.position = dir * (v.PLAZA + 10.5) + side_v * 5.2
	g.rotation.y = atan2(dir.x, dir.z)          # la targa sta di traverso: si legge dalla piazza e da chi arriva
	v.box(g, Vector3(0, 1.3, 0), Vector3(0.07, 2.6, 0.07), Color("3e4644"), true)
	var plate := Node3D.new()
	g.add_child(plate)
	plate.position = Vector3(0, 2.45, 0)
	v.box(plate, Vector3.ZERO, Vector3(1.5, 0.36, 0.04), Color("262626"), false)
	v.box(plate, Vector3.ZERO, Vector3(1.42, 0.3, 0.05), Color("e6e2d6"), false)
	for f in [1.0, -1.0]:
		var label := Label3D.new()
		plate.add_child(label)
		label.text = STREET_NAMES[key]
		label.position.z = 0.03 * f
		label.rotation.y = 0.0 if f > 0 else PI
		label.font_size = 40
		label.pixel_size = 0.005
		label.outline_size = 0
		label.double_sided = false
		label.modulate = Color("1d2a3a")
