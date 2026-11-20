extends Node3D
# Storia della Zona 1 (decide l'host, i client ricevono lo stato). Catene brevi verbo+luogo, ognuna con un motivo e
# un personaggio: lo sceriffo ti manda a caccia, Big Earl ti arma e tiene i pezzi, alla fattoria impari il rumore,
# tre boss (radura, Borgo Cenere, Rocca), un respiro al falò di Bruno, e i tre pezzi tornano al 4×4.
# Ogni boss lascia la sua testa e un pezzo del 4×4; con tre pezzi si ripara il mezzo e la Zona 1 è finita.

const Layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
const RoadNetSites: Dictionary = preload("res://world/zona1_rifugio/roadnet.gd").SITES
enum { TALK, KILL_TWO, WEAPON, NOISE, GET_BAIT, FOREST_BOSS, BRING_FOREST, VILLAGE_BOSS, BRING_VILLAGE, DUNGEON, BRING_DUNGEON, DONE }
## Vecchio nome del passo "teste e arma", usato da alcuni test.
const MORE_AND_WEAPON := WEAPON
## Versione degli stati salvati: senza "v" il salvataggio è di prima del passo del rumore (11 passi).
const SAVE_VERSION := 2
const FIRST_HEADS := 2
const TOTAL_HEADS := 5
const BOSS_HEADS := ["item_testa_capomacello", "item_testa_macellaio", "item_testa_carceriere"]
const BOSS_NAMES := ["IL CAPOMACELLO", "IL MACELLAIO", "IL CARCERIERE"]
const PARTS := ["LA BATTERIA", "LA CINGHIA", "LA TANICA"]
const STEPS := [
	"Parla con lo sceriffo, sotto il portico", "Prendi 2 teste nel prato a nord", "Fatti armare da Big Earl, all'Emporio",
	"Caccia in silenzio alla fattoria: altre 3 teste", "Ritira l'esca dallo sceriffo", "Accendi l'esca all'altare della radura",
	"Porta la batteria a Big Earl", "Getta l'esca nel pozzo di Borgo Cenere", "Riposa al falò di Bruno, davanti alla Rocca",
	"Scendi dal Carceriere, sotto la Rocca", "Porta i tre pezzi al 4×4, nel recinto", "Ripara il 4×4",
]
const PRATO := Vector3(6, 0, -62)
const ARRIVE_EARL := 4.0
const ARRIVE_FIRE := 8.0
const ARRIVE_CAR := 6.0
const FARM_RADIUS := 35.0

var world: Node3D
var stage := TALK
var delivered := 0
var weapon_bought := false
var carceriere_dead := false
var farm_told := false     # la lezione sul rumore si dice una volta sola
var poll := 0.0


func build(owner_world: Node3D) -> void:
	world = owner_world
	name = "Zone1Quest"


func reset() -> void:
	stage = TALK
	delivered = 0
	weapon_bought = false
	carceriere_dead = false
	farm_told = false


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
		_go(WEAPON)
		world.announce(Localization.t("Sceriffo: «Due. Con l'ascetta non arrivi alla terza bestia: fatti armare da Big Earl, all'Emporio.»"), 7)
		_check_ready()
	elif stage == NOISE:
		_check_ready()
	else: _publish()


func on_weapon_bought() -> void:
	if not authority(): return
	weapon_bought = true
	_check_ready()


## Arma presa → la fattoria; teste fatte → l'esca. Si possono saltare più passi in un colpo (arma già in tasca).
func _check_ready() -> void:
	if stage == WEAPON and weapon_bought:
		_go(NOISE)
		world.announce(Localization.t("Big Earl: «Con questa li stendi. Ma uno sparo si sente lontano: provala alla fattoria e guarda chi arriva.»"), 8)
	if stage == NOISE and delivered >= TOTAL_HEADS:
		_go(GET_BAIT)
		world.announce(Localization.t("Sei pronto. Torna a parlare con lo sceriffo: ha l'esca."), 7)
	_publish()


## Fine del dialogo con lo sceriffo.
func talk(actor: CharacterBody3D) -> void:
	if not authority(): return
	# L'arma presa dal tavolo o comprata altrove vale come "arma vera".
	if stage <= NOISE and actor.owned.any(func(w): return w != "axe"):
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
		BRING_DUNGEON:
			_finish()


## Arrivi nei luoghi del passo: Big Earl, il falò di Bruno, il 4×4. Decide l'host, 4 volte al secondo.
func _process(delta: float) -> void:
	if world == null or not authority() or not world.get("started"): return
	poll -= delta
	if poll > 0.0: return
	poll = 0.25
	for a in world.actors.values():
		if is_instance_valid(a) and not a.dead: arrive(a)


func arrive(actor: CharacterBody3D) -> void:
	var at: Vector3 = actor.global_position
	match stage:
		WEAPON:
			if _flat(at, Layout.SHOP_NPC) < ARRIVE_EARL and actor.owned.any(func(w): return w != "axe"): on_weapon_bought()
		NOISE:
			if not farm_told and _flat(at, Layout.FARM) < FARM_RADIUS:
				farm_told = true
				world.announce(Localization.t("LA FATTORIA · Accucciato (Ctrl) non ti sentono. Uno sparo li chiama tutti: spara solo quando sei pronto."), 9)
		BRING_FOREST:
			if _flat(at, Layout.SHOP_NPC) < ARRIVE_EARL:
				actor.baits += 1
				if world.get("survival"): world.survival.gesture(actor, "give")
				_go(VILLAGE_BOSS)
				world.announce(Localization.t("Big Earl: «La batteria la tengo in carica io. Lo sceriffo ha lasciato un'altra esca: il pozzo in piazza a Borgo Cenere, lungo la statale a nord.»"), 9)
		BRING_VILLAGE:
			if world.get("rocca") and _flat(at, fire()) < ARRIVE_FIRE:
				actor.health = actor.max_health()
				if "status" in actor and actor.status: actor.status.clear_all()
				_go(BRING_DUNGEON if carceriere_dead else DUNGEON)
				world.announce(Localization.t("Bruno: «Siediti, scaldati. Qui non vengono. Quando sei pronto il portone è aperto: chiedimi la strada.»"), 9)
		BRING_DUNGEON:
			if _flat(at, world.expedition.car.global_position) < ARRIVE_CAR: _finish()


func _finish() -> void:
	_go(DONE)
	world.expedition.begin_repair()
	world.announce(Localization.t("HAI I TRE PEZZI · Ripara il 4×4 e lascia Lago Cenere"), 7)


func fire() -> Vector3:
	return world.rocca.guide_pos if world.get("rocca") else RoadNetSites["dungeon"]


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


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
		actor.add_item(head)   # con le tasche piene va in riserva (player.gd): si salva e non si perde
	world.survival._publish()
	var next: String = ["Portala a Big Earl, all'Emporio.", "Riprendi fiato al falò di Bruno, davanti alla Rocca.", "Portala al 4×4, nel recinto."][index]
	world.announce(Localization.t("{0} È MORTO · Hai la sua testa e {1} del 4×4.", [Localization.t(BOSS_NAMES[index]), Localization.t(PARTS[index])]) + " " + Localization.t(next), 8)
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
		WEAPON:
			return [Localization.t("Con quell'ascetta ti fai ammazzare. Big Earl sta all'Emporio, dall'altra parte della strada: guarda il pannello e fatti armare."),
				Localization.t("Coi soldi delle teste ci arrivi. Se no, sul tavolo accanto c'è roba da prendere.")]
		NOISE:
			var left := maxi(0, TOTAL_HEADS - delivered)
			return [Localization.t("Altre {0} teste. Vai alla fattoria in mattoni, a ovest lungo il sentiero: là sono tanti.", [left]),
				Localization.t("Accucciato non ti sentono, l'ascia si sente poco. Uno sparo li chiama tutti da lontano: decidi tu quando.")]
		GET_BAIT:
			return [Localization.t("Adesso ragioniamo. Tre bestie tengono i pezzi del tuo mezzo, ognuna ha fatto il nido dove è morto chi li portava."),
				Localization.t("La prima è il Capomacello. Sta in una radura nel bosco a ovest, ma esce solo se sente l'odore giusto."),
				Localization.t("Questa è l'esca. Accendila sull'altare di pietra e stai pronto. Il GPS ti porta lì.")]
		FOREST_BOSS:
			return [Localization.t("Il Capomacello è ancora vivo. L'altare è nella radura a ovest: segui il GPS.")]
		BRING_FOREST:
			return [Localization.t("L'hai fatto davvero. Quella testa te la pago bene, quando vuoi: V, come le altre."),
				Localization.t("La batteria portala a Big Earl, all'Emporio: la mette in carica, e gli ho lasciato la prossima esca.")]
		VILLAGE_BOSS:
			return [Localization.t("Il Macellaio è nel pozzo in piazza, a Borgo Cenere. Lungo la statale a nord: getta l'esca e stai pronto."),
				Localization.t("Attento ai tetti: lassù sputano, e quando esce lui le vie si chiudono.")]
		BRING_VILLAGE:
			return [Localization.t("Due su tre. L'ultimo è il Carceriere e non serve esca: è già in casa sua, sotto la Rocca."),
				Localization.t("Prima riprendi fiato. Bruno ha un falò davanti alla torre, nel bosco a ovest oltre la fattoria: lì gli infetti non vengono.")]
		DUNGEON:
			return [Localization.t("Il Carceriere è sotto la Rocca, a ovest oltre la fattoria. Scendi le scale della torre.")]
		BRING_DUNGEON:
			return [Localization.t("Tutti e tre. Non ci avrei scommesso una testa."), Localization.t("Hai batteria, cinghia e tanica. Rimetti in moto il 4×4 e vattene da Lago Cenere, finché puoi.")]
	return [Localization.t("Il 4×4 è tuo. Vai, prima che ne arrivino altri.")]


# ---------------------------------------------------------------- obiettivo a schermo
const TITLES := {
	KILL_TWO: "PORTA 2 TESTE ALLO SCERIFFO", WEAPON: "FATTI ARMARE DA BIG EARL", NOISE: "CACCIA ALLA FATTORIA",
	GET_BAIT: "RITIRA L'ESCA DALLO SCERIFFO", FOREST_BOSS: "UCCIDI IL CAPOMACELLO", BRING_FOREST: "PORTA LA BATTERIA A BIG EARL",
	VILLAGE_BOSS: "UCCIDI IL MACELLAIO", BRING_VILLAGE: "RIPOSA AL FALÒ DI BRUNO", DUNGEON: "UCCIDI IL CARCERIERE",
	BRING_DUNGEON: "PORTA I PEZZI AL 4×4",
}


func title() -> String:
	return Localization.t(TITLES.get(stage, "PARLA CON LO SCERIFFO"))


func detail() -> String:
	match stage:
		TALK: return Localization.t("Lago Cenere · è seduto sotto il portico")
		KILL_TWO: return Localization.t("Teste consegnate {0} / {1} · uccidi gli infetti nel prato a nord", [mini(delivered, FIRST_HEADS), FIRST_HEADS])
		WEAPON: return Localization.t("Emporio di Big Earl · compra un'arma dal pannello")
		NOISE: return Localization.t("Teste {0} / {1} · Accucciato non ti sentono, uno sparo li chiama", [mini(delivered, TOTAL_HEADS), TOTAL_HEADS])
		GET_BAIT: return Localization.t("Ti dà l'esca per il boss del bosco")
		FOREST_BOSS: return Localization.t("Combatti nella radura" if world.boss_hunt.used[0] else "Accendi l'esca sull'altare nella radura del bosco")
		BRING_FOREST: return Localization.t("Emporio di Big Earl · ha la prossima esca")
		VILLAGE_BOSS: return Localization.t("Combatti nella piazza" if world.village.arena == "active" else "Borgo Cenere · getta l'esca nel pozzo in piazza")
		BRING_VILLAGE: return Localization.t("Davanti alla Rocca · ti curi e senti la strada")
		DUNGEON: return Localization.t("Scendi nella Rocca, nel bosco a ovest · parla con Bruno")
		BRING_DUNGEON: return Localization.t("Batteria, cinghia e tanica · il 4×4 è nel recinto")
	return ""


func target() -> Vector3:
	var has_head: int = world.player.carried_heads
	match stage:
		KILL_TWO:
			return Layout.SHERIFF_NPC if has_head >= FIRST_HEADS - delivered else _nearest_infected(PRATO)
		WEAPON, BRING_FOREST:
			return Layout.SHOP_NPC
		NOISE:
			return Layout.SHERIFF_NPC if has_head >= TOTAL_HEADS - delivered else Layout.FARM
		FOREST_BOSS:
			return world.boss_hunt.rows[0][1]
		VILLAGE_BOSS:
			return RoadNetSites["village"]
		BRING_VILLAGE:
			return fire()
		DUNGEON:
			return world.rocca.entrance_node.global_position if world.rocca.entrance_node else Vector3.ZERO
		BRING_DUNGEON:
			return world.expedition.car.global_position
	return Layout.SHERIFF_NPC


## Il primo obiettivo non è più un punto fisso nel prato: il GPS punta all'infetto vivo più vicino fuori dal recinto.
func _nearest_infected(fallback: Vector3) -> Vector3:
	var from: Vector3 = world.player.global_position
	var best := fallback
	var best_d := 150.0 * 150.0
	for e in world.targets:
		if not is_instance_valid(e) or e.dead or Layout.safe(e.global_position): continue
		var d: float = e.global_position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = e.global_position
	return best


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
	return {"v": SAVE_VERSION, "stage": stage, "delivered": delivered, "weapon": weapon_bought, "carceriere": carceriere_dead}


func load_data(data: Dictionary) -> void:
	stage = int(data.get("stage", TALK))
	delivered = int(data.get("delivered", 0))
	weapon_bought = bool(data.get("weapon", false))
	carceriere_dead = bool(data.get("carceriere", false))
	farm_told = false
	if int(data.get("v", 1)) < SAVE_VERSION: stage = migrate(stage, weapon_bought)


## Salvataggi di prima (11 passi, "teste e arma" era uno solo): da lì in poi tutto scala di uno.
static func migrate(old: int, weapon: bool) -> int:
	if old < 2: return old
	if old == 2: return NOISE if weapon else WEAPON
	return mini(old + 1, DONE)
