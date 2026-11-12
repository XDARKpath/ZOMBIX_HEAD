extends SceneTree
# Colpi d'arma bianca sull'ambiente (AudioManager.surface_hit): materiale ricavato dai nomi veri della Zona 1 e suoni presenti.
# godot --path . --headless -s res://tests/surface_material_checks.gd
const CASES := {"SM_Wood_Chair_A": "wood", "SM_Bld_Wall_Log_Solid": "wood", "TownFence": "wood", "SM_Prop_CardboardBox_Stack": "wood",
	"car_police": "metal", "SM_Prop_Table_Metal": "metal", "M_DoorIronL": "metal", "streetlight": "metal", "SM_Shop_SecurityShutter_Door": "metal",
	"SM_Bld_Wall_Brick_Doorway": "stone", "Rock_Medium": "stone", "_MeshInstance3D_8": "stone"}
var fails := 0

func _initialize(): call_deferred("run")
func run():
	var AM = root.get_node("AudioManager")
	for name in CASES:
		var parent := Node3D.new(); parent.name = name
		var body := StaticBody3D.new(); parent.add_child(body)
		var got: String = AM.surface_material(body)
		print("PASS " if got == CASES[name] else "FAIL ", "%s -> %s" % [name, got])
		if got != CASES[name]: fails += 1
		parent.free()
	var tagged := StaticBody3D.new(); tagged.set_meta("material", "metal")
	if AM.surface_material(tagged) != "metal": fails += 1; print("FAIL meta material")
	tagged.free()
	for key in ["impact_wood", "impact_metal", "impact_stone"]:
		var ok := ResourceLoader.exists("res://audio/sfx/%s.wav" % key)
		print("PASS " if ok else "FAIL ", key)
		if not ok: fails += 1
	# Colpo vero: muro di legno a 1,2 m davanti all'occhio, la scansione della lama lo tocca e suona una volta per colpo.
	var lab: Node3D = load("res://world/movement_lab/movement_lab.tscn").instantiate(); root.add_child(lab)
	for i in 20: await physics_frame
	var p: CharacterBody3D = lab.player
	p.owned.assign(["axe"]); p.hotbar.assign(["axe", "", "", "", "", "", "", "", ""]); p.select_slot(0)
	var look: Vector3 = Basis.from_euler(Vector3(p.rig.pitch, p.rig.yaw, 0)) * Vector3.FORWARD
	var wall := StaticBody3D.new(); wall.name = "SM_Wood_Wall"
	var shape := CollisionShape3D.new(); shape.shape = BoxShape3D.new(); (shape.shape as BoxShape3D).size = Vector3(3, 3, 0.2)
	wall.add_child(shape); lab.add_child(wall)
	wall.global_position = p.global_position + Vector3.UP * p.eye_height + look * 1.2
	wall.look_at(wall.global_position + look)
	for i in 3: await physics_frame
	var m = p.melee
	m._clock = 10.0; m._wall_at = -1.0; m.hit_ids.clear(); m.attack_clip = ""; m.charged_attack = false
	m._blade_strike()
	var first: float = m._wall_at
	m._clock = 10.1; m._blade_strike()
	var ok: bool = first == 10.0 and m._wall_at == 10.0
	print("PASS " if ok else "FAIL ", "La lama sul muro di legno suona una volta per colpo (%.1f, %.1f)" % [first, m._wall_at])
	if not ok: fails += 1
	print("SURFACE %s (%d errori)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
