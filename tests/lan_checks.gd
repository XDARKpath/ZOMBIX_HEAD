extends SceneTree
# LAN: l'host annuncia il campo e chi cerca lo trova con nome, porta e giocatori.
var failures := 0
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	var session: Node = root.get_node("Session")
	session.nickname = "Ahmed"
	check(session.host(27841) == OK, "Campo aperto sulla porta 27841")
	session.lan_search(true)
	await create_timer(2.5).timeout
	var games: Dictionary = session.lan_games
	check(not games.is_empty(), "La ricerca trova il campo in LAN (%d)" % games.size())
	var game: Dictionary = games.values()[0] if not games.is_empty() else {}
	check(game.get("name") == "Ahmed" and game.get("port") == 27841 and game.get("count") == 1, "Annuncio con nome, porta e giocatori: %s" % str(game))
	session.leave("")
	await create_timer(4.0).timeout
	check(session.lan_games.is_empty(), "Chiuso il campo, sparisce dalla lista")
	session.lan_search(false)
	print("LAN %s (%d errori)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)
