@tool
extends EditorScenePostImport
## Post-import for every ZOMBIX HEAD environment GLB (art/env/**).
## - swaps the embedded materials for the two shared palette materials (one draw-call family)
## - adds collision: trimesh for building tiles, convex hull for static props, none for weapons
## - attaches the gameplay script for interactive props

const PALETTE := "res://art/env/materials/M_Env_Palette.tres"
const GLASS := "res://art/env/materials/M_Env_Glass.tres"
const SCRIPTS := "res://art/env/scripts/"
## child meshes that move at runtime never get their own static collision
const MOVING_SUFFIX := ["_Lid", "_Door", "_Plate", "_Mag"]
const MOVING_TAG := ["_Lit_", "_Piece_"]


func _post_import(scene: Node) -> Object:
	var file := get_source_file().get_file().get_basename()
	var palette: Material = load(PALETTE)
	var glass: Material = load(GLASS)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh := mi.mesh as ArrayMesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			var is_glass := m != null and String(m.resource_name).begins_with("M_Env_Glass")
			mesh.surface_set_material(i, glass if is_glass else palette)
		if mi.name.contains("_Lit_"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_collision(file, mi, scene)
	var script := _script_for(file)
	if script != "":
		scene.set_script(load(SCRIPTS + script))
	return scene


func _is_moving(n: String) -> bool:
	for tag in MOVING_SUFFIX:
		if n.ends_with(tag):
			return true
	for tag in MOVING_TAG:
		if n.contains(tag):
			return true
	return false


func _add_collision(file: String, mi: MeshInstance3D, scene: Node) -> void:
	if file.begins_with("SM_Wep_") or file.ends_with("_Fractured") or file.contains("Tripwire_Wire"):
		return
	if String(mi.name) != file and _is_moving(mi.name):
		return
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	if file.begins_with("SM_Bld_"):
		cs.shape = mi.mesh.create_trimesh_shape()
	else:
		cs.shape = mi.mesh.create_convex_shape(true, true)
	mi.add_child(body)
	body.add_child(cs)
	body.owner = scene
	cs.owner = scene


func _script_for(file: String) -> String:
	if file == "SM_Int_Crate_Destructible":
		return "destructible_crate.gd"
	if file.begins_with("SM_Int_Chest_") or file == "SM_Int_Safe_Steel":
		return "hinged_container.gd"
	if file == "SM_Int_PressurePlate":
		return "pressure_plate.gd"
	if file == "SM_Int_StatusLight":
		return "status_light.gd"
	if file.begins_with("SM_Wep_"):
		return "weapon_item.gd"
	return ""
