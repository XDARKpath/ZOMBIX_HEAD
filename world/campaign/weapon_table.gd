extends Node3D
# Il tavolo all'inizio: tutte le armi del gioco in fila, da guardare e da provare. Si prende gratis con E.
# Quello che guardi viene evidenziato dal nome sopra l'arma; l'host decide (survival_rules, azione "table:<id>").

const LENGTH := 11.0
const WIDTH := 2.0
const TOP := 0.86
const REACH := 3.2
## Dal più comune al più strano, le armi bianche davanti a chi arriva.
const ORDER := ["axe", "runic_axe", "pickaxe", "sledgehammer", "electric_guitar", "katana", "longsword", "spartan_sword", "machete", "knife", "crowbar", "nail_bat",
	"frying_pan", "baguette", "trout", "rubber_chicken", "pistol", "revolver", "flare_gun", "nailgun", "smg", "sawn_off", "assault_rifle", "lmg", "sniper_rifle",
	"pump_shotgun", "lever_rifle", "crossbow", "bow", "grenade_launcher", "tesla_rifle", "leaf_blower"]
const Motion := preload("res://player/tool_motion.gd")
var world: Node3D
var spots := {}
var _label: Label3D


func build(owner_world: Node3D, at: Vector3, yaw: float) -> void:
	world = owner_world
	name = "TavoloArmi"
	rotation.y = yaw
	position = at
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5b4630")
	wood.roughness = 0.85
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("2c2f2d")
	_box(Vector3(LENGTH, 0.08, WIDTH), Vector3(0, TOP, 0), wood)
	_box(Vector3(LENGTH + 0.08, 0.04, WIDTH + 0.08), Vector3(0, TOP - 0.06, 0), iron)
	for x in [-LENGTH * 0.47, -LENGTH * 0.16, LENGTH * 0.16, LENGTH * 0.47]:
		for z in [-WIDTH * 0.42, WIDTH * 0.42]:
			_box(Vector3(0.1, TOP - 0.08, 0.1), Vector3(x, (TOP - 0.08) * 0.5, z), iron)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = Vector3(LENGTH, TOP + 0.05, WIDTH)
	shape.shape = cube
	shape.position.y = (TOP + 0.05) * 0.5
	body.add_child(shape)
	add_child(body)
	var count: int = ORDER.size()
	var per_row: int = ceili(float(count) / 2.0)
	for i in count:
		var row: int = i / per_row
		var col: int = i % per_row
		var spot := Vector3(-LENGTH * 0.46 + LENGTH * 0.92 * float(col) / float(per_row - 1), TOP + 0.05, (0.48 if row == 0 else -0.48))
		_lay(ORDER[i], spot)
		spots[ORDER[i]] = spot
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.004
	_label.font_size = 40
	_label.outline_size = 12
	_label.modulate = Color("ffe2b0")
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)


func _box(size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	add_child(mi)


## L'arma stesa sul tavolo, con la canna o la lama verso chi guarda.
func _lay(id: String, spot: Vector3) -> void:
	var item := model(id)
	if item == null: return
	for a in item.find_children("*", "AnimationPlayer", true, false): (a as AnimationPlayer).active = false
	add_child(item)
	# Steso sul lato più sottile, con il lato lungo per il largo del tavolo.
	var box: AABB = Motion.model_box(item)
	var turn := Basis.IDENTITY
	var thin: int = 0
	if box.size.y < box.size[thin]: thin = 1
	if box.size.z < box.size[thin]: thin = 2
	if thin == 0: turn = Basis(Vector3.BACK, PI * 0.5)        # x verso l'alto
	elif thin == 2: turn = Basis(Vector3.RIGHT, PI * 0.5)     # z verso l'alto
	var laid: AABB = Transform3D(turn, Vector3.ZERO) * box
	if laid.size.x > laid.size.z:
		turn = Basis(Vector3.UP, PI * 0.5) * turn
		laid = Transform3D(turn, Vector3.ZERO) * box
	item.transform = Transform3D(turn, spot - Vector3(laid.get_center().x, laid.position.y - 0.01, laid.get_center().z))
	Motion.burnish(item)


func model(id: String) -> Node3D:
	var scene := ""
	if id == "axe": scene = "res://art/zx_fp/SM_FP_Axe.glb"
	elif id == "knife": scene = "res://art/zx_fp/SM_FP_CombatKnife.glb"
	else: scene = str(ZXWeapons.get_def(id).get("scene", ""))
	if scene == "": return null
	return load(scene).instantiate()


## L'arma che il giocatore sta guardando: la più vicina al raggio dello sguardo, se è abbastanza vicino al tavolo.
func looked_at(a: CharacterBody3D) -> String:
	if a.global_position.distance_to(global_position) > LENGTH * 0.5 + REACH: return ""
	var eye: Vector3 = a.global_position + Vector3.UP * a.eye_height
	var look: Vector3 = Basis.from_euler(Vector3(a.rig.pitch, a.rig.yaw, 0)) * Vector3.FORWARD
	var best := ""
	var best_gap := 0.45
	for id in spots:
		var point: Vector3 = to_global(spots[id])
		var along: float = (point - eye).dot(look)
		if along < 0.2 or along > REACH + 1.0: continue
		var gap: float = (eye + look * along).distance_to(point)
		if gap < best_gap:
			best_gap = gap
			best = id
	return best


## La riga che compare a schermo e il nome sopra l'arma.
func context(a: CharacterBody3D) -> String:
	var id := looked_at(a)
	_label.visible = id != ""
	if id == "": return ""
	_label.position = spots[id] + Vector3(0, 0.4, 0)
	var name_text: String = preload("res://weapons/zx_arsenal.gd").display_name(id)
	_label.text = name_text
	return Localization.t("[E] PRENDI {0}", [name_text])


## Sull'host: l'arma va in mano al giocatore. Con le tasche piene sostituisce quella che ha in mano.
func take(a: CharacterBody3D, id: String) -> bool:
	if not spots.has(id) or a.global_position.distance_to(global_position) > LENGTH * 0.5 + REACH + 1.0: return false
	if a.melee.attacking or a.melee.charging or a.reload_left > 0.0: return false
	if a.owned.has(id):
		a.equip_id(id)
	else:
		if not a.can_take(id):
			var old: String = a.equipped
			if old == "" or ItemInfo.is_item(old): old = str(a.hotbar[0])
			a.owned.erase(old)
			a.hotbar_clear(old)
		a.owned.append(id)
		a.equip_id(id)
	a.magazine = preload("res://weapons/zx_arsenal.gd").magazine(id)
	if id == "bow": a.arrows = maxi(a.arrows, 20)
	return true
