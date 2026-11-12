extends SceneTree
# Piedi che scivolano (zx_player._pace): un corpo ZX cammina, corre, arretra, va di lato e accucciato alla velocità vera
# del gioco. Si misura quanto si muove nel mondo il piede mentre poggia davvero a terra.
# godot --path . --headless -s res://tests/foot_slide_checks.gd
const ACTOR := """extends CharacterBody3D
signal damaged(amount)
var equipped := "axe"
var dead := false
var seated := false
var crouching := false
var sprinting := false
var reload_left := 0.0
var local_control := false
var melee: Node
"""
const MELEE := """extends Node
var attacking := false
var charged_attack := false
var charging := false
var ads := false
var blocking := false
var attack_clip := ""
func charge_fraction() -> float: return 0.0
"""
## [nome, velocità locale (+Z avanti del corpo), corsa, accucciato]: velocità di autoload/balance.gd.
const CASES := [["camminata 4,0", Vector3(0, 0, 4.0), false, false], ["corsa 7,0", Vector3(0, 0, 7.0), true, false],
	["piano 1,8", Vector3(0, 0, 1.8), false, false], ["attaccando 1,2", Vector3(0, 0, 1.2), false, false], ["indietro 4,0", Vector3(0, 0, -4.0), false, false],
	["di lato 4,0", Vector3(4.0, 0, 0), false, false], ["accucciato 1,8", Vector3(0, 0, 1.8), false, true]]
const LIMIT := 0.3          # il piede d'appoggio può scivolare al massimo del 30% della velocità
var fails := 0

func _initialize(): call_deferred("run")
func source(code: String) -> GDScript:
	var s := GDScript.new(); s.source_code = code; s.reload(); return s

func run():
	var scene := Node3D.new(); root.add_child(scene)
	for c in CASES:
		var actor := CharacterBody3D.new(); actor.set_script(source(ACTOR))
		var melee := Node.new(); melee.set_script(source(MELEE)); actor.melee = melee; actor.add_child(melee)
		actor.equipped = "assault_rifle"
		scene.add_child(actor)
		var v := Node3D.new(); v.set_script(load("res://art/survivor_visual.gd")); actor.add_child(v)
		v.configure("ZX_SKIN_1", actor)
		actor.crouching = c[3]; actor.sprinting = c[2]
		var sk: Skeleton3D = v.skeleton
		var feet := [sk.find_bone("foot_l"), sk.find_bone("foot_r")]
		# Contatto vero: piede entro 2 cm dal suo punto più basso (la corsa ha una fase di volo con tutti e due i piedi su).
		var track: Array = [[], []]
		# Il corpo avanza con il delta vero del fotogramma, lo stesso con cui avanza l'AnimationTree.
		var dt := 0.016
		for i in 150:
			actor.velocity = v.global_basis * (c[1] as Vector3)
			actor.position += actor.velocity * dt
			if v.operative_driver: v.operative_driver.tick(dt)
			await process_frame
			dt = clampf(root.get_process_delta_time(), 0.001, 0.05)
			if i <= 50: continue
			for k in 2:
				track[k].append([sk.get_bone_global_pose(feet[k]).origin.y, sk.global_transform * sk.get_bone_global_pose(feet[k]).origin, dt])
		var speeds: Array[float] = []
		for k in 2:
			var low := INF
			for row in track[k]: low = minf(low, row[0])
			for j in range(1, track[k].size()):
				if track[k][j][0] < low + 0.02 and track[k][j - 1][0] < low + 0.02:
					var d: Vector3 = track[k][j][1] - track[k][j - 1][1]
					speeds.append(Vector2(d.x, d.z).length() / float(track[k][j - 1][2]))
		speeds.sort()
		var speed: float = (c[1] as Vector3).length()
		var mean: float = speeds[speeds.size() / 2] if not speeds.is_empty() else INF   # mediana durante il contatto
		var ok := mean < speed * LIMIT
		print(("PASS " if ok else "FAIL ") + "%s m/s: il piede a terra scivola a %.2f m/s (%.0f%%)" % [c[0], mean, mean / speed * 100.0])
		if not ok: fails += 1
		actor.queue_free()
	print("FOOT SLIDE %s (%d errori)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
