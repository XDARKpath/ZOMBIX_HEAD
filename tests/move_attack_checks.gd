extends SceneTree
# Passo mentre si colpisce: sparo 0,7, mischia leggera 0,6, pesante, arco e carica 0,3 (Balance.ATTACK_MOVE_MULTIPLIER).
#   godot --path . --headless -s res://tests/move_attack_checks.gd
var fails := 0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails += 1

func _run() -> void:
	var world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await process_frame
	var p = world.player
	var want := {"pistol": 0.7, "assault_rifle": 0.7, "pump_shotgun": 0.7, "knife": 0.6, "axe": 0.3, "bow": 0.3}
	for id in want:
		p.equipped = id
		p.melee.charging = false
		check(is_equal_approx(p.attack_move_multiplier(), want[id]), "%s colpendo: %.2f (atteso %.2f)" % [id, p.attack_move_multiplier(), want[id]])
	p.equipped = "knife"
	p.melee.charging = true
	check(is_equal_approx(p.attack_move_multiplier(), 0.3), "coltello in carica: 0,3")
	p.melee.charging = false
	print("PASSO IN ATTACCO: ", fails, " errori")
	quit(1 if fails > 0 else 0)
