extends Node3D
# Storia della Zona 1 (decide l'host, i client ricevono lo stato). Lo sceriffo guida tutto:
# due teste → altre tre e un'arma → esca → Capomacello nel bosco → il Macellaio a Borgo Cenere → Il Carceriere sotto la Rocca.
# Ogni boss lascia la sua testa e un pezzo del 4×4; con tre pezzi si ripara il mezzo e la Zona 1 è finita.

const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
const RoadNetSites: Dictionary = preload("res://world/zona1_rifugio/roadnet.gd").SITES
enum { TALK, KILL_TWO, MORE_AND_WEAPON, GET_BAIT, FOREST_BOSS, BRING_FOREST, VILLAGE_BOSS, BRING_VILLAGE, DUNGEON, BRING_DUNGEON, DONE }
const FIRST_HEADS := 2
const TOTAL_HEADS := 5
const BOSS_HEADS := ["item_testa_capomacello", "item_testa_macellaio", "item_testa_carceriere"]
const BOSS_NAMES := ["IL CAPOMACELLO", "IL MACELLAIO", "IL CARCERIERE"]
const PARTS := ["LA BATTERIA", "LA CINGHIA", "LA TANICA"]
const STEPS := [
	"Parla con lo sceriffo", "Portagli 2 teste", "Altre 3 teste e un'arma", "Prendi l'esca", "Capomacello, nel bosco", "Torna dallo sceriffo",
	"Il Macellaio, a Borgo Cenere", "Torna dallo sceriffo", "Il Carceriere, nella Rocca", "Torna dallo sceriffo", "Ripara il 4×4",
]

var world: Node3D
var stage := TALK
var delivered := 0
var weapon_bought := false
var carceriere_dead := false


func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "Zone1Quest"


func reset() -> void:
	stage = TALK
	delivered = 0
	weapon_bought = false
	carceriere_dead = false


func authority() -> bool:
	return not Session.online or multiplayer.is_server()


func finished() -> bool:
	return stage >= DONE


## Può accendere questo altare, adesso? (0 bosco, 1 villaggio)
func can_summon(index: int) -> bool:
	return stage == (FOREST_BOSS if index == 0 else VILLAGE_BOSS)


func bosses_done() -> int:
	return world.expedition.collected.count(true)


# ---------------------------------------------------------------- avanzamento (host)
func on_head_sold(_actor: Node3D, id: String) -> void:
	if not authority() or BOSS_HEADS.has(id): return
	delivered += 1
	if stage == KILL_TWO and delivered >= FIRST_HEADS:
		_go(MORE_AND_WEAPON)
		world.announce(Localization.t("Sceriffo: «Bene. Altre {0} teste e comprati un'arma vera da Big Earl.", [TOTAL_HEADS - delivered]), 7)
	elif stage == MORE_AND_WEAPON:
		_check_ready()
	else: _publish()


func on_weapon_bought() -> void:
	if not authority(): return
	weapon_bought = true
	_check_ready()
	_publish()


func _check_ready() -> void:
	if stage == MORE_AND_WEAPON and delivered >= TOTAL_HEADS and weapon_bought:
		_go(GET_BAIT)
		world.announce(Localization.t("Sei pronto. Torna a parlare con lo sceriffo: ha l'esca."), 7)
	else: _publish()


## Fine del dialogo con lo sceriffo.
func talk(actor: CharacterBody3D) -> void:
	if not authority(): return
	# L'arma presa dal tavolo o comprata altrove vale come "arma vera": con 5 teste l'esca arriva subito.
	if stage == MORE_AND_WEAPON and actor.owned.any(func(w): return w != "axe"):
		weapon_bought = true
		_check_ready()
	match stage:
		TALK:
			_go(KILL_TWO)
		GET_BAIT:
			actor.baits += 1
			if world.get("survival"): world.survival.gesture(actor, "give")
			_go(FOREST_BOSS)
			world.announce(Localization.t("HAI L'ESCA · Accendila sull'altare di pietra nella radura del bosco"), 7)
		FOREST_BOSS, VILLAGE_BOSS:
			# Esca persa per strada: lo sceriffo ne ha un'altra, così la storia non si blocca mai.
			var waiting: bool = not world.boss_hunt.used[0] if stage == FOREST_BOSS else world.village.arena == "idle"
			var someone_has := false
			for a in world.actors.values(): someone_has = someone_has or a.baits > 0
			if not someone_has and waiting: actor.baits += 1
		BRING_FOREST:
			actor.baits += 1
			_go(VILLAGE_BOSS)
			world.announce(Localization.t("NUOVA ESCA · Gettala nel pozzo in piazza a Borgo Cenere, lungo la statale verso nord"), 7)
		BRING_VILLAGE:
			if carceriere_dead: _go(BRING_DUNGEON)
			else:
				_go(DUNGEON)
				world.announce(Localization.t("La Rocca è nel bosco a ovest, oltre la fattoria. Bruno ti aspetta all'ingresso."), 7)
		BRING_DUNGEON:
			_go(DONE)
			world.expedition.begin_repair()
			world.announce(Localization.t("HAI I TRE PEZZI · Ripara il 4×4 e lascia Lago Cenere"), 7)


## Un boss è morto: la sua testa e un pezzo del 4×4 a chi gli è più vicino. Il Carceriere si può battere anche in anticipo.
func on_boss(index: int) -> void:
	if not authority(): return
	var mission: Node3D = world.expedition
	if index == 2: carceriere_dead = true
	if mission.collected[index]:
		_publish()
		return
	mission.collected[index] = true
	mission._publish()
	var at: Vector3 = world.boss_hunt.rows[0][1] if index == 0 else RoadNetSites["village"]
	var actor: CharacterBody3D = world.nearest_player(at) if index < 2 else _inside_actor()
	var head: String = BOSS_HEADS[index]
	if is_instance_valid(actor):
		if actor.can_take(head): actor.add_item(head)
		else:
			var spot := Transform3D(Basis(), actor.global_position + Vector3.UP)
			world.survival.heads.append([world.survival.next_head, "res://art/zx_infected/ZMB_Walker_1.glb", spot, actor.global_position + Vector3(0.6, 0.18, 0.6), head])
			world.survival.next_head += 1
	world.survival._publish()
	world.announce(Localization.t("{0} È MORTO · Hai la sua testa e {1} del 4×4. Torna dallo sceriffo.", [Localization.t(BOSS_NAMES[index]), Localization.t(PARTS[index])]), 8)
	if stage == FOREST_BOSS and index == 0: _go(BRING_FOREST)
	elif stage == VILLAGE_BOSS and index == 1: _go(BRING_VILLAGE)
	elif stage == DUNGEON and index == 2: _go(BRING_DUNGEON)
	else: _publish()


func _inside_actor() -> CharacterBody3D:
	for a in world.actors.values():
		if is_instance_valid(a) and not a.dead and a.global_position.y > 150.0: return a
	return world.player


func _go(next: int) -> void:
	stage = next
	_publish()


# ---------------------------------------------------------------- dialogo
func lines() -> Array:
	match stage:
		TALK:
			return [Localization.t("Quello lì fuori è il tuo 4×4? Sfasciato. Senza batteria, cinghia e carburante non vai da nessuna parte."),
				Localization.t("Qui dentro il recinto sei al sicuro. Fuori no. Le teste valgono soldi, e a me servono: vediamo se sai usare quell'ascia."),
				Localization.t("Esci dal portone a nord, nel prato ne trovi. Ammazzalo, poi colpisci il cadavere alla testa con l'ascia. Portamene {0}.", [FIRST_HEADS])]
		KILL_TWO:
			return [Localization.t("Ne voglio {0}, te ne mancano {1}. Tieni la testa in mano e premi V davanti a me.", [FIRST_HEADS, maxi(0, FIRST_HEADS - delivered)])]
		MORE_AND_WEAPON:
			var left := maxi(0, TOTAL_HEADS - delivered)
			var out: Array = []
			if left > 0: out.append(Localization.t("Due teste non bastano a farmi fidare. Portamene altre {0}.", [left]))
			if not weapon_bought: out.append(Localization.t("E con quell'ascetta ti fai ammazzare. Vai da Big Earl, guarda il pannello e comprati un'arma vera."))
			return out if not out.is_empty() else [Localization.t("Sei pronto.")]
		GET_BAIT:
			return [Localization.t("Adesso ragioniamo. Tre bestie tengono i pezzi del tuo mezzo, ognuna ha fatto il nido dove è morto chi li portava."),
				Localization.t("La prima è il Capomacello. Sta in una radura nel bosco a ovest, ma esce solo se sente l'odore giusto."),
				Localization.t("Questa è l'esca. Accendila sull'altare di pietra e stai pronto. Il GPS ti porta lì.")]
		FOREST_BOSS:
			return [Localization.t("Il Capomacello è ancora vivo. L'altare è nella radura a ovest: segui il GPS.")]
		BRING_FOREST:
			return [Localization.t("L'hai fatto davvero. Quella testa te la pago bene, quando vuoi: V, come le altre. La batteria tienila stretta."),
				Localization.t("Il secondo è il Macellaio. Si è preso Borgo Cenere, il paese lungo la statale a nord, e la cinghia del tuo motore è lì."),
				Localization.t("Altra esca. Gettala nel pozzo in mezzo alla piazza. Attento ai tetti: lassù sputano, e quando esce lui le vie si chiudono.")]
		VILLAGE_BOSS:
			return [Localization.t("Il Macellaio è nel pozzo in piazza, a Borgo Cenere. Lungo la statale a nord: getta l'esca e stai pronto.")]
		BRING_VILLAGE:
			if carceriere_dead: return [Localization.t("Hai già sistemato anche il Carceriere? Allora abbiamo finito.")]
			return [Localization.t("Due su tre. L'ultimo è il Carceriere e non serve esca: è già in casa sua, sotto la Rocca."),
				Localization.t("La torre è nel bosco a ovest, oltre la fattoria. Il portone è sempre aperto. Parla con Bruno, ti spiega lui come arrivarci. La tanica è laggiù.")]
		DUNGEON:
			return [Localization.t("Il Carceriere è sotto la Rocca, a ovest oltre la fattoria. Scendi le scale della torre.")]
		BRING_DUNGEON:
			return [Localization.t("Tutti e tre. Non ci avrei scommesso una testa."), Localization.t("Hai batteria, cinghia e tanica. Rimetti in moto il 4×4 e vattene da Lago Cenere, finché puoi.")]
	return [Localization.t("Il 4×4 è tuo. Vai, prima che ne arrivino altri.")]


# ---------------------------------------------------------------- obiettivo a schermo
func title() -> String:
	var value := "PARLA CON LO SCERIFFO"
	match stage:
		KILL_TWO: value = "PORTA 2 TESTE ALLO SCERIFFO"
		MORE_AND_WEAPON: value = "PORTA ALTRE TESTE E COMPRA UN'ARMA"
		FOREST_BOSS: value = "UCCIDI IL CAPOMACELLO"
		VILLAGE_BOSS: value = "UCCIDI IL MACELLAIO"
		DUNGEON: value = "UCCIDI IL CARCERIERE"
	return Localization.t(value)


func detail() -> String:
	match stage:
		TALK: return Localization.t("Lago Cenere · è seduto sotto il portico")
		KILL_TWO: return Localization.t("Teste consegnate {0} / {1} · uccidi gli infetti nel prato a nord", [mini(delivered, FIRST_HEADS), FIRST_HEADS])
		MORE_AND_WEAPON: return Localization.t("Teste {0} / {1} · Arma: {2}", [mini(delivered, TOTAL_HEADS), TOTAL_HEADS, Localization.t("presa") if weapon_bought else Localization.t("da comprare da Big Earl")])
		GET_BAIT: return Localization.t("Ti dà l'esca per il boss del bosco")
		FOREST_BOSS: return Localization.t("Combatti nella radura" if world.boss_hunt.used[0] else "Accendi l'esca sull'altare nella radura del bosco")
		BRING_FOREST: return Localization.t("Testa e batteria presi · ti dà la prossima esca")
		VILLAGE_BOSS: return Localization.t("Combatti nella piazza" if world.village.arena == "active" else "Borgo Cenere · getta l'esca nel pozzo in piazza")
		BRING_VILLAGE: return Localization.t("Testa e cinghia presi · manca l'ultimo")
		DUNGEON: return Localization.t("Scendi nella Rocca, nel bosco a ovest · parla con Bruno")
		BRING_DUNGEON: return Localization.t("Hai tutti i pezzi del 4×4")
	return ""


func target() -> Vector3:
	var has_head: bool = world.player.carried_heads > 0
	match stage:
		KILL_TWO:
			return Layout.SHERIFF_NPC if has_head else Vector3(6, 0, -62)
		MORE_AND_WEAPON:
			if has_head and delivered < TOTAL_HEADS: return Layout.SHERIFF_NPC
			if delivered < TOTAL_HEADS: return Vector3(6, 0, -62)
			return Layout.SHOP_NPC
		FOREST_BOSS:
			return world.boss_hunt.rows[0][1]
		VILLAGE_BOSS:
			return RoadNetSites["village"]
		DUNGEON:
			return world.rocca.entrance_node.global_position if world.rocca.entrance_node else Vector3.ZERO
	return Layout.SHERIFF_NPC


func steps_text() -> String:
	var text := ""
	var done_parts: int = world.expedition.collected.count(true)
	for i in STEPS.size():
		var mark := "✓" if i < stage else ("●" if i == stage else "·")
		text += "%s  %s\n" % [mark, Localization.t(STEPS[i])]
	return text + "\n" + Localization.t("Pezzi del 4×4  {0} / 3", [done_parts])


# ---------------------------------------------------------------- rete e salvataggio
func _publish() -> void:
	if Session.online and multiplayer.is_server():
		for peer in Session.connected_peers():
			receive.rpc_id(peer, stage, delivered, weapon_bought, carceriere_dead, world.boss_hunt.used, world.boss_hunt.cleared)


@rpc("authority", "call_remote", "reliable")
func receive(step: int, heads: int, weapon: bool, carceriere: bool, used: Array, cleared: Array) -> void:
	stage = step
	delivered = heads
	weapon_bought = weapon
	carceriere_dead = carceriere
	world.boss_hunt.used = used
	world.boss_hunt.cleared = cleared


func save_data() -> Dictionary:
	return {"stage": stage, "delivered": delivered, "weapon": weapon_bought, "carceriere": carceriere_dead}


func load_data(data: Dictionary) -> void:
	stage = int(data.get("stage", TALK))
	delivered = int(data.get("delivered", 0))
	weapon_bought = bool(data.get("weapon", false))
	carceriere_dead = bool(data.get("carceriere", false))
