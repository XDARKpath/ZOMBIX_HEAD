@tool
extends EditorScript
## File > Run (with this script open in the Script editor).
## Builds res://art/env/ML_Env_Buildings.tres from every art/env/building/*.glb:
## one item per tile, with its trimesh collision and an editor thumbnail.
## GridMap setup for these corner-pivot tiles: cell_size = (4, 3, 4) or (2, 3, 2),
## cell_center_x/y/z = false.

const SRC_DIR := "res://art/env/building/"
const OUT := "res://art/env/ML_Env_Buildings.tres"


func _run() -> void:
	var lib := build_library(SRC_DIR)
	var meshes: Array[Mesh] = []
	for id in lib.get_item_list():
		meshes.append(lib.get_item_mesh(id))
	var previews := EditorInterface.make_mesh_previews(meshes, 128)
	for i in previews.size():
		lib.set_item_preview(lib.get_item_list()[i], previews[i])
	ResourceSaver.save(lib, OUT)
	print("MeshLibrary saved: ", OUT, " (", lib.get_item_list().size(), " items)")


static func build_library(dir_path: String) -> MeshLibrary:
	var lib := MeshLibrary.new()
	var dir := DirAccess.open(dir_path)
	var files := Array(dir.get_files()).filter(func(f): return f.ends_with(".glb"))
	files.sort()
	var id := 0
	for f in files:
		var scene := (load(dir_path + f) as PackedScene).instantiate()
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			lib.create_item(id)
			lib.set_item_name(id, String(mi.name).trim_prefix("SM_Bld_"))
			lib.set_item_mesh(id, mi.mesh)
			lib.set_item_mesh_transform(id, mi.transform)
			var shapes := []
			for b in mi.find_children("*", "StaticBody3D", false, false):
				for c in b.find_children("*", "CollisionShape3D", false, false):
					shapes.append_array([c.shape, mi.transform * (c as CollisionShape3D).transform])
			lib.set_item_shapes(id, shapes)
			id += 1
			break
		scene.free()
	return lib
