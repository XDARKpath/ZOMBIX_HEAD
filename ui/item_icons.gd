class_name ItemIcons
extends Node
# Icone della barra e dello zaino: generate una volta dai modelli 3D (ItemInfo.model) in un SubViewport trasparente
# 128×128, poi tenute in user://icons/<id>.png. Finché l'icona non è pronta l'HUD usa il suo disegno di riserva.

const SIZE := 128
const VERSION := "v1"
static var cache := {}
static var instance: ItemIcons
var queue: Array[String] = []
var busy := false


func _ready() -> void:
	instance = self


static func get_icon(id: String) -> Texture2D:
	if id == "": return null
	if cache.has(id): return cache[id]
	if instance == null or DisplayServer.get_name() == "headless": return null
	var path := "user://icons/%s_%s.png" % [VERSION, id]
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			cache[id] = ImageTexture.create_from_image(img)
			return cache[id]
	if not instance.queue.has(id): instance.queue.append(id)
	return null


func _process(_delta: float) -> void:
	if busy or queue.is_empty(): return
	busy = true
	_bake(queue.pop_front())


func _bake(id: String) -> void:
	var model := ItemInfo.model(id)
	if model == null:
		cache[id] = null
		busy = false
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.82, 0.76)
	env.environment.ambient_light_energy = 0.75
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	# Di traverso: armi lunghe in diagonale nella casella.
	var pivot := Node3D.new()
	vp.add_child(pivot)
	pivot.add_child(model)
	pivot.rotation = Vector3(0.25, 1.15, -0.72)
	var box := _bounds(pivot)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(maxf(box.size.x, box.size.y), 0.05) * 1.12
	cam.near = 0.01
	cam.far = 50.0
	vp.add_child(cam)
	cam.global_position = box.get_center() + Vector3(0, 0, maxf(box.size.z, 0.5) + 2.0)
	cam.current = true
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://icons")
	img.save_png("user://icons/%s_%s.png" % [VERSION, id])
	cache[id] = ImageTexture.create_from_image(img)
	vp.queue_free()
	busy = false


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var local: AABB = m.global_transform * m.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box
