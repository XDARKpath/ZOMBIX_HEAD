extends SceneTree
# Presa di ogni arma da fuoco: prima persona a riposo e in mira, corpo visto da sinistra (mano secondaria).
# Misura anche la mano sinistra in prima persona: quanto è scivolata dal contatto voluto e quanto manca al polso.
# Serve una finestra: Godot --path . --resolution 1280x720 -s res://tests/gun_hold_shots.gd -- --shots=<cartella> [--only=pistol,smg]
const ToolMotion := preload("res://player/tool_motion.gd")
const IDS := ["pistol", "revolver", "flare_gun", "nailgun", "smg", "assault_rifle", "lmg", "sniper_rifle", "tesla_rifle",
	"pump_shotgun", "sawn_off", "lever_rifle", "crossbow", "grenade_launcher", "leaf_blower"]
var p: CharacterBody3D

func _initialize(): call_deferred("run")

func snap(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir.path_join(name + ".png"))

## [cm di scivolamento lungo la canna, cm fra polso voluto e polso vero] della mano sinistra in prima persona.
func left_gap(arms: Node) -> Array:
	var m = arms._motion
	var grip: Dictionary = m.grip("l")
	if grip.is_empty(): return [0.0, 0.0]
	var sk: Skeleton3D = arms.skeleton
	var shoulder: Vector3 = sk.get_bone_global_pose(sk.find_bone("upperarm_l")).origin
	var w: Transform3D = arms._reachable(m.frame())
	var ideal: Array = ToolMotion.fist_for(w, grip, "l", shoulder, Vector3.UP, 0.078, 0.029, 99.0, m.left_shift, m.edge_w)
	var used: Array = ToolMotion.fist_for(w, grip, "l", shoulder, Vector3.UP, 0.078, 0.029, arms.ARM_REACH, m.left_shift, m.edge_w)
	var real: Vector3 = sk.get_bone_global_pose(sk.find_bone("hand_l")).origin
	return [(ideal[0] as Vector3).distance_to(used[0]) * 100.0, (used[0] as Vector3).distance_to(real) * 100.0]

func run():
	var dir := ProjectSettings.globalize_path("res://../screenshots/gun_hold")
	var only: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): dir = arg.trim_prefix("--shots=")
		if arg.begins_with("--only="): only = Array(arg.trim_prefix("--only=").split(","))
	DirAccess.make_dir_recursive_absolute(dir)
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate(); root.add_child(world); world.automated = true
	root.get_node("Session").launch(); await create_timer(2.0).timeout
	p = world.player
	p.reset_at(Vector3(6, 0.1, 2)); p.rig.yaw = PI; p.rig.pitch = -0.05
	p.owned.assign(IDS)
	p.inventory_slots = 15
	p.hotbar.assign(IDS)
	var fp_cam: Camera3D = p.rig.camera
	var arms: Node = p.find_child("FpArms", true, false)
	var out_cam := Camera3D.new(); out_cam.fov = 32.0; out_cam.cull_mask = 0xFFFFF & ~(1 << 19); world.add_child(out_cam)
	for id in IDS:
		if not only.is_empty() and not id in only: continue
		p.select_slot(p.hotbar.find(id))
		p.melee.ads_forced = false
		await create_timer(1.2).timeout
		var gaps: Array = left_gap(arms)
		fp_cam.make_current()
		for mesh in arms.get_parent().find_children("*", "VisualInstance3D", true, false): (mesh as VisualInstance3D).layers = 1
		await snap(dir, "%s_fp_riposo" % id)
		p.melee.ads_forced = true
		await create_timer(0.6).timeout
		var aim_gaps: Array = left_gap(arms)
		await snap(dir, "%s_fp_mira" % id)
		p.melee.ads_forced = false
		await create_timer(0.5).timeout
		# Braccia in prima persona viste dal lato sinistro (camera di servizio, non quella del gioco).
		var eye: Transform3D = fp_cam.global_transform
		out_cam.global_position = eye.origin - eye.basis.x * 0.75 - eye.basis.z * 0.3 + eye.basis.y * 0.05
		out_cam.look_at(eye.origin - eye.basis.z * 0.35 - eye.basis.y * 0.15)
		out_cam.cull_mask = 0xFFFFF
		out_cam.make_current()
		await snap(dir, "%s_fp_lato" % id)
		out_cam.cull_mask = 0xFFFFF & ~(1 << 19)
		# Da fuori, lato sinistro del personaggio, all'altezza delle mani: il viewmodel non c'è (layer 19).
		for mesh in arms.get_parent().find_children("*", "VisualInstance3D", true, false): (mesh as VisualInstance3D).layers = 1 << 19
		for mesh in p.visual.find_children("*", "MeshInstance3D", true, false): (mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var front: Vector3 = p.visual.global_basis.z
		var side: Vector3 = p.visual.global_basis.x
		out_cam.global_position = p.global_position + Vector3.UP * 1.35 - front * 0.9 + side * 1.3
		out_cam.look_at(p.global_position + Vector3.UP * 1.25 - front * 0.25)
		out_cam.make_current()
		await create_timer(0.2).timeout
		await snap(dir, "%s_tp_sinistra" % id)
		for mesh in p.visual.find_children("*", "MeshInstance3D", true, false): (mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		print("PRESA %s: sinistra scivolata %.1f cm (mira %.1f), polso a %.1f cm dal voluto (mira %.1f)" % [id, gaps[0], aim_gaps[0], gaps[1], aim_gaps[1]])
	fp_cam.make_current()
	quit()
