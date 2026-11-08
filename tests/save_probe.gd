extends RefCounted
# Prova del salvataggio dell'host: scrive un checkpoint, sporca lo stato e lo
# ripristina, controllando crediti, teste, armi, ricambi e posizione del 4×4.
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	print("PASS " if value else "FAIL ", message)
	if not value: failures.append(message)

func run(world: Node) -> bool:
	for i in range(4): await world.get_tree().physics_frame
	var mission = world.expedition
	world.player.credits = 210
	world.player.carried_heads = 3
	world.player.owned.assign(["axe", "knife", "pistol"])
	world.player.equipped = "knife"
	mission.collected = [true, false, false]
	mission.stage = 0
	mission.car.repaired = true
	mission.car.global_position = Vector3(4.0, 0.3, -2.0)
	world.player.reset_at(Vector3(7.0, 0.5, 3.0))
	check(SaveManager.write(world), "Il checkpoint viene scritto")
	check(FileAccess.file_exists(SaveManager.SLOT_PATH), "Il file di salvataggio esiste")
	world.player.credits = 0
	world.player.carried_heads = 0
	world.player.owned.assign(["axe"])
	world.player.equipped = "axe"
	mission.collected = [false, false, false]
	mission.car.repaired = false
	mission.car.global_position = Vector3.ZERO
	world.player.reset_at(Vector3(0.0, 0.5, 0.0))
	check(SaveManager.apply(world), "Il checkpoint viene ripreso")
	check(world.player.credits == 210, "I crediti tornano dal salvataggio")
	check(world.player.carried_heads == 3, "Le teste tornano dal salvataggio")
	check("pistol" in world.player.owned and world.player.equipped == "knife", "Armi ed equipaggiamento tornano")
	check(mission.collected[0] and not mission.collected[1], "I ricambi raccolti tornano")
	check(mission.car.repaired, "Il 4×4 resta riparato")
	check(mission.car.global_position.distance_to(Vector3(4.0, 0.3, -2.0)) < 0.2, "Il 4×4 riparte da dove era")
	check(world.player.position.distance_to(Vector3(7.0, 0.5, 3.0)) < 0.6, "Il giocatore riparte dal checkpoint")
	SaveManager.erase()
	check(not SaveManager.has_save(), "Il salvataggio di prova viene rimosso")
	return failures.is_empty()
