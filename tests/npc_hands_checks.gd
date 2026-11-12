extends SceneTree
# Mani degli NPC (art/hand_pose.gd): le dita si chiudono verso il palmo, la sigaretta del fumatore resta fra le dita
# e arriva alle labbra senza che la mano entri nella testa, il sigaro dello sceriffo sta all'angolo della bocca.
# godot --path . --headless -s res://tests/npc_hands_checks.gd
const Hands := preload("res://art/hand_pose.gd")
var fails := 0

func _initialize(): call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: fails += 1

func run():
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate(); root.add_child(world)
	await create_timer(0.6).timeout
	var smoker = world.camp.avatars[0]
	smoker.set_process(false)
	var sk: Skeleton3D = smoker.skeleton
	var ids: Dictionary = smoker.bone_ids
	# Palmo: nella posa a T dei rig ZX i palmi guardano in giù (pollice avanti, glb) e le dita si chiudono lì.
	sk.reset_bone_poses(); sk.force_update_all_bone_transforms()
	for side in ["l", "r"]:
		check(Hands.palm_normal(sk, ids, side).dot(Vector3.DOWN) > 0.9, "Mano %s: a riposo il palmo guarda in giù" % side)
	smoker.clock = 9.0; smoker._pose(0)
	for side in ["l", "r"]:
		Hands.grip(sk, ids, side, "pistol")
		var knuckle := sk.get_bone_global_pose(ids["middle_01_" + side]).origin
		var tip := sk.get_bone_global_pose(ids["middle_03_" + side]).origin
		var hand := sk.get_bone_global_pose(ids["hand_" + side]).origin
		var along := (knuckle - hand).normalized()
		var bent := (tip - knuckle) - along * (tip - knuckle).dot(along)
		check(bent.normalized().dot(Hands.palm_normal(sk, ids, side)) > 0.5, "Mano %s: il medio si chiude verso il palmo (%.2f)" % [side, bent.normalized().dot(Hands.palm_normal(sk, ids, side))])
	# Boccata: la sigaretta segue la mano, il filtro arriva alle labbra, la mano resta fuori dalla testa.
	var far := 0.0
	var best := 1.0
	var inside := 1.0
	for i in 29:
		smoker.clock = i * 0.5
		smoker._pose(0)
		far = maxf(far, smoker.cigarette.global_position.distance_to(smoker.hand("r")))
		if Hands.sip_at(smoker.clock) > 0.99:
			var mouth: Vector3 = Hands.mouth(sk, ids)
			best = minf(best, Hands.filter_tip(sk, ids, "r").distance_to(mouth))
			inside = minf(inside, sk.get_bone_global_pose(ids["hand_r"]).origin.distance_to(sk.get_bone_global_pose(ids["head"]).origin))
	check(far < 0.16, "La sigaretta resta fra le dita (al massimo %.3f m dal polso)" % far)
	check(best < 0.03, "Il filtro arriva alle labbra (%.3f m)" % best)
	check(inside > 0.08, "La mano non entra nella testa (%.3f m dall'osso della testa)" % inside)
	# Sceriffo: sigaro all'angolo della bocca, punta da bocca a z = -0.0475.
	var body = world.survival.sheriff_node.get_node("SheriffBody")
	body.set_process(false)
	body.clock = 3.0; body._pose(0)
	var bsk: Skeleton3D = body.skeleton
	var lips: Vector3 = bsk.global_transform * Hands.mouth(bsk, body.bone_ids)
	var end: Vector3 = body.cigarette.global_transform * Vector3(0, 0, -0.0475)
	check(body.cigarette.name == "Cigar", "Lo sceriffo ha il sigaro")
	check(end.distance_to(lips) < 0.04, "Il sigaro sta all'angolo della bocca (%.3f m)" % end.distance_to(lips))
	print("NPC HANDS %s (%d errori)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
