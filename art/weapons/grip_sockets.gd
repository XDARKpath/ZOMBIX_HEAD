extends RefCounted
# Socket_RightHand / Socket_LeftHand per le braccia FPS (player/viewmodel/fp_hands.gd).
# X lungo il manico (pollice destro verso -X, sinistro verso +X), Y verso cui escono
# le dita, Z dorso della mano. Le coordinate sono locali all'arma: i socket seguono
# qualunque scala del modello.

static func add(weapon: Node3D, socket_name: String, origin: Vector3, along: Vector3, fingers: Vector3, radius: float, grip: String = "power") -> Marker3D:
	var x := along.normalized()
	var y := (fingers - x * fingers.dot(x)).normalized()
	var marker := Marker3D.new()
	marker.name = socket_name
	marker.transform = Transform3D(Basis(x, y, x.cross(y)), origin)
	marker.set_meta("radius", radius)
	marker.set_meta("grip", grip)
	weapon.add_child(marker)
	return marker


## Attrezzi a manico lungo (ascia, pala): misura asse e raggio del manico dalla mesh.
static func shaft(weapon: Node3D, mesh: Mesh, right_y: float, left_y: float) -> void:
	var points := PackedVector3Array()
	var head := Vector3.ZERO
	var head_count := 0
	var top := -INF
	for s in mesh.get_surface_count():
		for p in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			points.append(p)
			top = maxf(top, p.y)
	var center := Vector2.ZERO
	var band := 0
	for p in points:
		if p.y > -0.04 and p.y < 0.12:
			center += Vector2(p.x, p.z)
			band += 1
	center /= maxf(band, 1)
	var radius := 0.0
	for p in points:
		if p.y > -0.04 and p.y < 0.12:
			radius = maxf(radius, Vector2(p.x, p.z).distance_to(center))
		if p.y > top - 0.12:
			head += Vector3(p.x - center.x, 0, p.z - center.y)
			head_count += 1
	var blade := head / maxf(head_count, 1)
	if blade.length() < 0.004: blade = Vector3.BACK
	blade = blade.normalized()
	weapon.set_meta("blade_dir", blade)
	radius = clampf(radius, 0.010, 0.030)
	var axis := Vector3(center.x, 0, center.y)
	add(weapon, "Socket_RightHand", axis + Vector3.UP * right_y, Vector3.DOWN, blade, radius)
	add(weapon, "Socket_LeftHand", axis + Vector3.UP * left_y, Vector3.UP, blade, radius)
