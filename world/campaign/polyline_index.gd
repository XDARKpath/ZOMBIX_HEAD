extends RefCounted
# Distanza veloce da una rete di strade dense: ogni cella della griglia conosce solo i tratti vicini.
# Lontano da tutto basta il tracciato grezzo: chi chiede la distanza da così lontano non ha bisogno del centimetro.
const CELL := 64.0
var ends := PackedVector2Array()          # coppie: inizio e fine di ogni tratto
var coarse := PackedVector2Array()
var grid := {}


func add_line(points: Array) -> void:
	for i in range(points.size() - 1):
		var a := Vector2(points[i].x, points[i].z)
		var b := Vector2(points[i + 1].x, points[i + 1].z)
		var index := ends.size()
		ends.append(a)
		ends.append(b)
		var low := Vector2i(floori((minf(a.x, b.x) - CELL) / CELL), floori((minf(a.y, b.y) - CELL) / CELL))
		var high := Vector2i(floori((maxf(a.x, b.x) + CELL) / CELL), floori((maxf(a.y, b.y) + CELL) / CELL))
		for x in range(low.x, high.x + 1):
			for y in range(low.y, high.y + 1):
				var key := Vector2i(x, y)
				if not grid.has(key): grid[key] = PackedInt32Array()
				grid[key].append(index)


func add_coarse(points: Array) -> void:
	for i in range(points.size() - 1):
		coarse.append(Vector2(points[i].x, points[i].z))
		coarse.append(Vector2(points[i + 1].x, points[i + 1].z))


func distance(p: Vector2) -> float:
	var best := INF
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	if grid.has(key):
		for index in grid[key]:
			best = minf(best, _to_segment(p, ends[index], ends[index + 1]))
		return best
	for i in range(0, coarse.size(), 2):
		best = minf(best, _to_segment(p, coarse[i], coarse[i + 1]))
	return best


static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)
