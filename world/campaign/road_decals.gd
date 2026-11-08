extends RefCounted
# Texture procedurali per i Decal della strada: sangue (pozza e scia), crepe ramificate,
# buche con bordo spaccato e asfalto strappato fino alla ghiaia. Generate una volta sola.
static var _cache: Dictionary = {}

static func texture(kind: String) -> ImageTexture:
	if _cache.has(kind): return _cache[kind]
	var image: Image
	match kind:
		"blood": image = _blood(256, 256, false)
		"drag": image = _blood(256, 128, true)
		"crack": image = _crack(256)
		"pothole": image = _pothole(192)
		_: image = _torn(256)
	image.generate_mipmaps()
	var tex := ImageTexture.create_from_image(image)
	_cache[kind] = tex
	return tex

static func _noise(seed_value: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	return n

static func _blood(w: int, h: int, drag: bool) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n := _noise(311, 0.035)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 if drag else 41
	var drops: Array = []
	for i in 26:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(0.42, 0.95)
		drops.append([Vector2(cos(a) * r, sin(a) * r), rng.randf_range(0.015, 0.06)])
	for y in h:
		for x in w:
			var p := Vector2(float(x) / w * 2.0 - 1.0, float(y) / h * 2.0 - 1.0)
			var d: float
			if drag:
				# Scia: si assottiglia e si sfrangia verso destra.
				var t := (p.x + 1.0) * 0.5
				d = absf(p.y) / lerpf(0.85, 0.15, t) + n.get_noise_2d(x * 1.5, y * 3.0) * 0.35
			else:
				d = p.length() / 0.55 + n.get_noise_2d(x, y) * 0.45
			var alpha := 1.0 - smoothstep(0.85, 1.0, d)
			if not drag:
				for drop in drops:
					alpha = maxf(alpha, 1.0 - smoothstep(drop[1] * 0.7, drop[1], p.distance_to(drop[0])))
			var dry := clampf(0.5 + n.get_noise_2d(x * 3.0 + 50, y * 3.0) * 0.8, 0.0, 1.0)
			var col := Color(0.30, 0.03, 0.02).lerp(Color(0.16, 0.02, 0.015), dry)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, alpha * 0.92))
	return img

static func _crack(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 903
	for branch in 7:
		var p := Vector2(size * 0.5, size * 0.5) + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
		var dir := Vector2.from_angle(rng.randf_range(0, TAU))
		var width := rng.randf_range(1.6, 3.0)
		for step in 90:
			dir = dir.rotated(rng.randf_range(-0.45, 0.45)).normalized()
			p += dir * 1.6
			if p.x < 2 or p.y < 2 or p.x > size - 3 or p.y > size - 3: break
			width = maxf(0.6, width - 0.02)
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					var q := Vector2i(int(p.x) + ox, int(p.y) + oy)
					var fall := 1.0 - clampf(Vector2(ox, oy).length() / width, 0.0, 1.0)
					if fall <= 0.0: continue
					var old := img.get_pixelv(q)
					img.set_pixelv(q, Color(0.035, 0.033, 0.03, maxf(old.a, fall * 0.95)))
	return img

static func _pothole(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var n := _noise(55, 0.05)
	var grit := _noise(91, 0.4)
	for y in size:
		for x in size:
			var p := Vector2(x, y) / size * 2.0 - Vector2.ONE
			var d := p.length() / 0.7 + n.get_noise_2d(x, y) * 0.35
			var inside := 1.0 - smoothstep(0.72, 0.8, d)
			var rim := smoothstep(0.65, 0.8, d) * (1.0 - smoothstep(0.8, 1.0, d))
			var g := 0.5 + grit.get_noise_2d(x, y) * 0.5
			var col := Color(0.07, 0.065, 0.06).lerp(Color(0.22, 0.2, 0.17), g * 0.5)
			col = col.lerp(Color(0.26, 0.25, 0.23), rim)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, maxf(inside, rim * 0.9)))
	return img

static func _torn(size: int) -> Image:
	# Asfalto strappato: sotto si vede la ghiaia.
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var n := _noise(808, 0.025)
	var grit := _noise(17, 0.5)
	for y in size:
		for x in size:
			var p := Vector2(x, y) / size * 2.0 - Vector2.ONE
			var d := Vector2(p.x * 0.8, p.y * 1.3).length() + n.get_noise_2d(x, y) * 0.5
			var alpha := 1.0 - smoothstep(0.6, 0.7, d)
			var g := 0.5 + grit.get_noise_2d(x, y) * 0.5
			var col := Color(0.33, 0.30, 0.25).lerp(Color(0.18, 0.16, 0.13), g)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, alpha))
	return img

static func decal(kind: String, size: Vector2, yaw: float) -> Decal:
	var d := Decal.new()
	d.texture_albedo = texture(kind)
	d.size = Vector3(size.x, 0.5, size.y)
	d.rotation.y = yaw
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.cull_mask = 1
	return d
