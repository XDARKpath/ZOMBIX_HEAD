# LA ROCCA · oggetti interattivi: casse di legno distruttibili, forzieri con bende/pozioni/monete, oggetti da raccogliere.
# Tutte le decisioni (rompere, aprire, raccogliere) passano dal livello (rocca.gd) che le applica sull'host
# e le replica ai client con lo stato.
extends RefCounted

const PROPS := "res://art/zx_rocca/props/"


static func load_prop(prop: String, parent: Node3D) -> Node3D:
	var n: Node3D = load(PROPS + prop + ".glb").instantiate()
	parent.add_child(n)
	return n


static func player_of(n: Node) -> AnimationPlayer:
	var list := n.find_children("*", "AnimationPlayer", true, false)
	return list[0] if list.size() > 0 else null


# =================================================================== CASSA DI LEGNO
## Si rompe con un colpo d'arma (melee o pistola: il raggio di mira colpisce il corpo con meta "target").
## Crate_Break fa volare 8 pezzi; il corpo sparisce e libera il passaggio verso il forziere nascosto.
class Crate extends Node3D:
	var level: Node3D
	var index := 0
	var ap: AnimationPlayer
	var body: StaticBody3D
	var broken := false
	var hp := 30.0

	func setup(owner_level: Node3D, i: int) -> void:
		level = owner_level
		index = i
		var m: Node3D = load(PROPS + "SM_Rocca_Cassa" + ".glb").instantiate()
		add_child(m)
		ap = m.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("Crate_Break"); ap.seek(0.0, true); ap.pause()      # posa iniziale = primo fotogramma di Crate_Break
		body = StaticBody3D.new()
		body.collision_layer = 1 | 16
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1, 1, 1)
		cs.shape = box
		cs.position = Vector3(0, 0.5, 0)
		body.add_child(cs)
		body.set_meta("target", self)
		body.set_meta("zone", "torso")
		add_child(body)

	## stessa firma di zombie_target.receive_hit, così l'arma la colpisce come un nemico
	func receive_hit(_zone: String, amount: float, _force: Vector3, _weapon: String, _heavy := false) -> bool:
		if broken:
			return false
		hp -= amount
		if hp <= 0:
			level.break_crate(index)
		return true

	func receive_melee(amount: float, force: Vector3, heavy: bool) -> bool:
		return receive_hit("torso", amount, force, "melee", heavy)

	func smash() -> void:
		if broken:
			return
		broken = true
		ap.play("Crate_Break")
		body.process_mode = Node.PROCESS_MODE_DISABLED
		body.collision_layer = 0

	func reset() -> void:
		broken = false
		hp = 30.0
		ap.play("Crate_Break"); ap.seek(0.0, true); ap.pause()      # posa iniziale = primo fotogramma di Crate_Break
		body.process_mode = Node.PROCESS_MODE_INHERIT
		body.collision_layer = 1 | 16


# =================================================================== FORZIERE
## [E] vicino: Chest_Lid_Pop_Open, poi escono i pickup (bende / pozioni / monete) davanti al forziere.
class Chest extends Node3D:
	var level: Node3D
	var index := 0
	var ap: AnimationPlayer
	var opened := false
	var loot: Array = []           # ["bandage", "ammo", ...]

	func setup(owner_level: Node3D, i: int, contents: Array) -> void:
		level = owner_level
		index = i
		loot = contents
		var m: Node3D = load(PROPS + "SM_Rocca_Forziere" + ".glb").instantiate()
		add_child(m)
		ap = m.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("Chest_Lid_Pop_Open"); ap.seek(0.0, true); ap.pause()
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.95, 0.5, 0.6)
		cs.shape = box
		cs.position = Vector3(0, 0.25, 0)
		sb.add_child(cs)
		add_child(sb)

	func pop() -> void:
		if opened:
			return
		opened = true
		ap.play("Chest_Lid_Pop_Open")

	func reset() -> void:
		opened = false
		ap.play("Chest_Lid_Pop_Open"); ap.seek(0.0, true); ap.pause()


# =================================================================== PICKUP
## Oggetto a terra che fluttua (Item_Float_Spin). Raccolto: Item_Pickup_Pop e sparisce.
## kind: "bende" (+35 salute), "pozione" (+60 salute), "monete" (+40 crediti), "chiave", "carne" (l'esca).
class Pickup extends Node3D:
	const SCENE := {"bende": "SM_Item_Bende", "pozione": "SM_Item_Pozione", "monete": "SM_Item_Monete", "chiave": "SM_Item_Chiave", "carne": "SM_Item_Carne"}
	var level: Node3D
	var index := 0
	var kind := "bandage"
	var ap: AnimationPlayer
	var taken := false
	var light: OmniLight3D

	func setup(owner_level: Node3D, i: int, what: String) -> void:
		level = owner_level
		index = i
		kind = what
		var m: Node3D = load(PROPS + SCENE[kind] + ".glb").instantiate()
		add_child(m)
		ap = m.find_children("*", "AnimationPlayer", true, false)[0]
		ap.get_animation("Item_Float_Spin").loop_mode = Animation.LOOP_LINEAR
		ap.play("Item_Float_Spin")
		if kind in ["chiave", "carne"]:
			light = OmniLight3D.new()
			light.light_color = Color("ffcf4a") if kind == "chiave" else Color("ff3a2a")
			light.omni_range = 3.5
			light.light_energy = 1.4
			light.position = Vector3(0, 1.0, 0)
			add_child(light)

	func take() -> void:
		if taken:
			return
		taken = true
		if ap.has_animation("Item_Pickup_Pop"):
			ap.play("Item_Pickup_Pop")
			level.get_tree().create_timer(0.4).timeout.connect(func(): visible = false)
		else:
			visible = false
		if light:
			light.visible = false

	func reset() -> void:
		taken = false
		visible = true
		ap.play("Item_Float_Spin")
		if light:
			light.visible = true
