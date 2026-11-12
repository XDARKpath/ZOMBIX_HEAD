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
	print("SURFACE %s (%d errori)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
