extends RefCounted
static var trimmed_meshes: Dictionary = {}
static func trim_source(node: Node, key: String, wrist_x: float) -> int:
	var removed := 0
	if node is MeshInstance3D and node.mesh and node.skin:
		var cache_key := key+":"+str(node.get_path()).get_file()
		if trimmed_meshes.has(cache_key):
			node.mesh=trimmed_meshes[cache_key][0]
			return trimmed_meshes[cache_key][1]
		var source: Mesh = node.mesh
		var result := ArrayMesh.new()
		# Remaining sleeve vertices must follow the forearm, not the replaced hand.
		# Source cuffs blend into Hand_* up to 8 cm before the wrist; a posed hand
		# otherwise twists and folds those sleeve rings independently of the arm.
		var bind_names: Array[String]=[]
		var forearm_binds := {}
		var rig: Skeleton3D=node.get_node(node.skeleton)
		for bind in node.skin.get_bind_count():
			var bone_name: String=node.skin.get_bind_name(bind)
			if bone_name.is_empty():bone_name=rig.get_bone_name(node.skin.get_bind_bone(bind))
			bone_name=bone_name.to_lower()
			bind_names.append(bone_name)
			if bone_name.begins_with("lowerarm_"):forearm_binds[bone_name.right(1)]=bind
		for s in source.get_surface_count():
			var arrays := source.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var original: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if original.is_empty():
				for i in points.size(): original.append(i)
			var indices := PackedInt32Array()
			for t in range(0,original.size(),3):
				var beyond := false
				for k in range(3):
					# T-pose hands are the only geometry beyond the wrists.
					beyond = beyond or absf(points[original[t+k]].x)>wrist_x-0.008
				if beyond: removed+=1
				else:
					for k in range(3): indices.append(original[t+k])
			if indices.is_empty(): continue
			arrays[Mesh.ARRAY_INDEX]=indices
			var bindings: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			for j in bindings.size():
				var bone_name: String=bind_names[bindings[j]]
				if bone_name.begins_with("hand_") or bone_name.begins_with("thumb_") or bone_name.begins_with("finger_") or bone_name.begins_with("indexfinger_"):
					bindings[j]=forearm_binds.get(bone_name.right(1),bindings[j])
			arrays[Mesh.ARRAY_BONES]=bindings
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},source.surface_get_format(s))
			result.surface_set_material(result.get_surface_count()-1,source.surface_get_material(s))
		trimmed_meshes[cache_key]=[result,removed]
		node.mesh=result
	for child in node.get_children(): removed+=trim_source(child,key,wrist_x)
	return removed

