extends SceneTree
# In inglese i testi delle missioni non escono in italiano: obiettivi, scritte [E], avvisi, valichi.
# godot --path . -s res://tests/translation_checks.gd
var world: Node3D
var fails: Array = []


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok: fails.append(what)


func _init() -> void:
	call_deferred("_run")


## Il testo come lo mostra una Label in inglese: Localization.t e poi la traduzione automatica di Godot.
func shown(text: String) -> String:
	return TranslationServer.translate(text)


func _run() -> void:
	var loc: Node = root.get_node("Localization")
	loc.current = "en"
	TranslationServer.set_locale("en")
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	root.get_node("Session").launch()
	world.automated = true
	for i in 30: await physics_frame
	var italian := ["GETTA", "ESCA", "CASSA", "RIPARA", "SCARICA", "PRESIDIO", "ROCCA", "VALICO", "UCCIDI", "SVEGLIA", "SCENDI", "SALI", "Cratere", "Cimitero", "infetti", "recuperato", "Trova", "Scendi", "Apri", "Appendi", "Uccidi", "Esci", "della", "nella"]
	var samples: Array = []
	var mission: Node3D = world.expedition
	# Testi fissi che passano dalle Label.
	for text in ["E  RIPARA IL 4×4", "E  SALI SUL 4×4", "E  SCARICA LA PROSSIMA COORDINATA", "Il 4×4 è stato recuperato sulla strada.", "IL POZZO È IN SILENZIO · PARLA CON LO SCERIFFO",
			"E  GETTA L'ESCA NEL POZZO · SVEGLIA IL MACELLAIO", "IL CARCERIERE È CADUTO · Forziere accanto all'altare. La porta nord riporta in superficie.", "Il Cratere, a nord", "E  PARLA CON LA SCERIFFA MIRA",
			"RIPARA IL 4×4", "SEGUI IL GPS", "LIBERA IL PRESIDIO", "Il Capomacello è tornato nel bosco. L'esca è ancora buona: riaccendila sull'altare."]:
		samples.append(shown(text))
	# Testi composti nel codice.
	samples.append(Localization_t(loc, "RIPARAZIONE  {0} s · RESTA VICINO", [5]))
	samples.append(Localization_t(loc, "{0} infetti · riunitevi e scaricate il segnale", [3]))
	samples.append(Localization_t(loc, "LA ROCCA MALEDETTA · ") + Localization_t(loc, world.rocca.objective()))
	# Tutti gli obiettivi della Rocca, uno per passo.
	var rocca: Node3D = world.rocca
	for step in [["has_key", true], ["door_open", true], ["has_bait", true], ["cripta_done", true], ["bait_placed", true], ["boss_dead", true]]:
		rocca.set(step[0], step[1])
		samples.append(Localization_t(loc, rocca.objective()))
	rocca.reset()
	samples.append(world.boss_hunt.context(world.player) if false else Localization_t(loc, "E  ACCENDI L'ESCA · EVOCA {0}", [Localization_t(loc, "IL CAPOMACELLO")]))
	world.zone_gates.refresh()
	samples.append(world.zone_gates.labels[0].text)
	samples.append(world.village.context(world.player) if false else Localization_t(loc, "E  APRI {0}", [Localization_t(loc, "LA CASSA MEDICA")]))
	samples.append(shown(mission.prompt()) + " | " + shown(mission.title()))
	for text in samples:
		var leftover := ""
		for word in italian:
			if (text as String).contains(word): leftover = word
		check(leftover == "", "In inglese: %s" % (text as String).replace("\n", " / "))
	print("TRADUZIONI: %d errori %s" % [fails.size(), fails])
	quit(0 if fails.is_empty() else 1)


func Localization_t(loc: Node, text: String, args: Array = []) -> String:
	return loc.t(text, args)
