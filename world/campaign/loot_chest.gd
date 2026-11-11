# Forziere originale low-poly (legno, bande di ferro, serratura d'ottone), costruito in codice: niente modelli esterni.
# make() rende un Node3D con figlio "Lid" incernierato sul retro e un corpo solido; set_open() apre o chiude il coperchio.
extends RefCounted

const WOOD := Color("7a4a2a")
const WOOD_DARK := Color("5b3620")
const IRON := Color("2e2c2a")
const BRASS := Color("d4a937")
const SIZE := Vector3(1.0, 0.5, 0.62)     # cassa senza coperchio


static func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.material = mat
	mi.mesh = mesh
	mi.position = at
	parent.add_child(mi)
	return mi


static func make(gold := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Forziere"
	var w := SIZE
	_box(root, Vector3(0, w.y * 0.5, 0), w, WOOD)
	_box(root, Vector3(0, 0.04, 0), Vector3(w.x + 0.04, 0.08, w.z + 0.04), WOOD_DARK)   # zoccolo
	for x in [-0.36, 0.36]:
		_box(root, Vector3(x, w.y * 0.5, 0), Vector3(0.07, w.y + 0.01, w.z + 0.03), IRON)
	# coperchio: cerniera sul bordo posteriore alto, il pivot ruota su X
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, w.y, -w.z * 0.5)
	root.add_child(lid)
	_box(lid, Vector3(0, 0.07, w.z * 0.5), Vector3(w.x + 0.02, 0.14, w.z + 0.02), WOOD)
	_box(lid, Vector3(0, 0.17, w.z * 0.5), Vector3(w.x - 0.06, 0.08, w.z - 0.18), WOOD_DARK)   # bombatura a gradino
	for x in [-0.36, 0.36]:
		_box(lid, Vector3(x, 0.11, w.z * 0.5), Vector3(0.07, 0.23, w.z + 0.04), IRON)
	_box(lid, Vector3(0, 0.02, w.z + 0.02), Vector3(0.16, 0.18, 0.04), BRASS if gold else Color("b08a3a"))   # serratura
	# interno visibile ad apertura: fondo scuro e un po' di bottino
	_box(root, Vector3(0, w.y - 0.02, 0), Vector3(w.x - 0.1, 0.02, w.z - 0.1), Color("2a1a10"))
	var shine := _box(root, Vector3(0, w.y + 0.02, 0.02), Vector3(0.5, 0.06, 0.3), BRASS if gold else Color("e6e0d0"))
	shine.name = "Bottino"
	var body := StaticBody3D.new()
	body.name = "Solido"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w.x, w.y + 0.2, w.z)
	cs.shape = shape
	cs.position = Vector3(0, (w.y + 0.2) * 0.5, 0)
	body.add_child(cs)
	root.add_child(body)
	return root


## Coperchio aperto (ruotato indietro di ~110°) o chiuso. animate=false per stati ripristinati dalla rete.
static func set_open(chest: Node3D, open: bool, animate := true) -> void:
	var lid: Node3D = chest.get_node_or_null("Lid")
	if lid == null:
		return
	var target := -1.95 if open else 0.0
	var loot: Node3D = chest.get_node_or_null("Bottino")
	if loot:
		loot.visible = not open
	if animate and chest.is_inside_tree():
		chest.create_tween().tween_property(lid, "rotation:x", target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		lid.rotation.x = target
