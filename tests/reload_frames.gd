extends SceneTree
# Ricarica di ogni categoria fermata sugli eventi di zx_arsenal.RELOAD_STEPS, in prima persona e vista da fuori.
# Serve una finestra vera: Godot --path . --resolution 1280x720 -s res://tests/reload_frames.gd -- --shots=<cartella> [--only=pistol]
const Arsenal := preload("res://weapons/zx_arsenal.gd")
const IDS := ["pistol", "assault_rifle", "lmg", "pump_shotgun", "sawn_off", "revolver", "lever_rifle", "crossbow"]
var p: CharacterBody3D

func _initialize(): call_deferred("run")

## Tiene la ricarica ferma alla frazione f mentre molle e IK si assestano.
func hold(f: float, frames: int) -> void:
	for i in frames:
		p.reload_left = p.reload_total * (1.0 - f)
		p._reload_seen = p.reload_left
		await process_frame

func run():
	var dir := ProjectSettings.globalize_path("res://../screenshots/reload_frames")
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): dir = arg.trim_prefix("--shots=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(dir)
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate(); root.add_child(world); world.automated = true
	root.get_node("Session").launch(); await create_timer(2.0).timeout
	p = world.player
	p.reset_at(Vector3(6, 0.1, 2)); p.rig.yaw = PI; p.rig.pitch = -0.05
	p.owned.assign(IDS)
	p.inventory_slots = 9
	p.hotbar.assign(IDS + [""])
	var fp_cam: Camera3D = p.rig.camera
	# Camera esterna: tre quarti davanti a sinistra, all'altezza del petto. Il corpo locale torna a fare ombra e a vedersi.
	var out_cam := Camera3D.new(); out_cam.fov = 40.0; world.add_child(out_cam)
	for id in IDS:
		if only != "" and id != only: continue
		p.select_slot(p.hotbar.find(id))
		await create_timer(1.0).timeout
		var steps: Array = Arsenal.reload_steps(id, Arsenal.reload_seconds(id, true))
		var marks: Array = [0.04]
		for s in steps: marks.append_array([float(s[0]) - 0.05, float(s[0]) + 0.03])
		marks.append(0.97)
		for view in ["fp", "tp"]:
			var bodies: Array = p.visual.find_children("*", "MeshInstance3D", true, false)
			for mesh in bodies:
				(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if view == "tp" else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			var front: Vector3 = p.visual.global_basis.z
			out_cam.global_position = p.global_position + Vector3.UP * 1.45 - front * 1.7 - p.visual.global_basis.x * 0.9   # il corpo guarda -Z del visual
			out_cam.look_at(p.global_position + Vector3.UP * 1.25)
			(out_cam if view == "tp" else fp_cam).make_current()
			for k in marks.size():
				p.magazine = 0
				p.reload_left = 0.0
				await process_frame
				p.reload_weapon()
				await hold(marks[k], 16)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(dir.path_join("%s_%s_%d.png" % [id, view, k]))
				print("shot %s %s %.2f mag=%d" % [id, view, marks[k], p.magazine])
		fp_cam.make_current()
	quit()
