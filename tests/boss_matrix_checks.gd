extends SceneTree
# I cinque boss nel gioco vero, ognuno dal suo punto d'ingresso (altare, pozzo, Rocca, Cratere, Cimitero):
# ingresso, tre fasi, sconfitta del giocatore, reset, si riprova, vittoria, ricompensa una volta sola.
# Più le correzioni della revisione boss: morte decisa sulla vita vera (gambe e testa), gabbia tolta con il boss,
# fuoco dell'inferno fermo dove è stato avvisato, calcio solo nello spicchio avvisato, pompa che ferma la carica in coop.
# godot --path . --headless -s res://tests/boss_matrix_checks.gd
const VL := preload("res://world/villaggio/villaggio_layout.gd")
const Route := preload("res://world/campaign/route.gd")
## Il colpo che compare solo dalla fase 2: cambia cosa conviene fare (fuoco a terra, mannaia, fessure, covata, corte).
const PHASE_MOVE := {"capomacello": "inferno", "macellaio": "cleaver", "carceriere": "fissure", "matriarca": "brood", "signore": "court"}
const HEADS := {"capomacello": "item_testa_capomacello", "macellaio": "item_testa_macellaio", "carceriere": "item_testa_carceriere", "matriarca": "item_testa_matriarca", "signore": "item_testa_signore"}
var fails := 0
var world
var p
var quest


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1


func _initialize() -> void:
	call_deferred("run")


func frames(n: int) -> void:
	for i in n: await physics_frame


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func reserve() -> Dictionary:
	return p.get("reserve") if p.get("reserve") != null else {}


func total(id: String) -> int:
	return int(p.items.get(id, 0)) + int(reserve().get(id, 0))


## Vita altissima: gli infetti del paese o della Rocca non devono decidere il test al posto del boss.
func tough() -> void:
	p.dead = false
	p.health = 100000.0
	p.status.clear_all()


func ground(at: Vector3) -> Vector3:
	world.terrain.ensure_near([at])
	at.y = world.terrain.height(at.x, at.z) + 0.3
	return at


func calm(b) -> void:
	b.move = {}
	b.stun = 0.0
	b.events.clear()
	b.waves.clear()
	b.hazards.clear()
	b.gap_left = 99.0
	b.exposed = 0.0
	b.burning = 0.0
	b.host.alert_time = 0.0
	b.host.state = 1


func past_intro(boss) -> void:
	var clock := 0.0
	while is_instance_valid(boss) and boss.brain.in_intro() and clock < 6.0:
		await physics_frame
		clock += 1.0 / 60.0
	await frames(5)


func entered(boss, style: String) -> void:
	check(is_instance_valid(boss) and boss.brain != null and boss.brain.style == style, "%s · ingresso: compare col suo cervello" % style)
	check(boss.brain.in_intro(), "%s · ingresso: parte con il suo ingresso (niente colpi, niente danno)" % style)
	check(boss.health == boss.max_health and boss.brain.phase == 0, "%s · ingresso: vita piena, fase 1" % style)


func score(b, style: String, id: String) -> float:
	b.target = p
	b.hidden_for = 0.0
	for row in b.call("_options_" + style, 8.0):
		if row[0] == id: return float(row[1])
	return -1.0


## Tre fasi decise dalla vita, e dalla seconda compare un colpo nuovo che cambia le scelte del giocatore.
func phases(boss, style: String) -> void:
	var b = boss.brain
	calm(b)
	var id: String = PHASE_MOVE[style]
	check(b.phase == 0 and score(b, style, id) == 0.0, "%s · fase 1: niente %s" % [style, id])
	boss.health = boss.max_health * 0.6
	await frames(3)
	check(b.phase == 1 and score(b, style, id) > 0.0, "%s · sotto il 66%%: fase 2 e compare %s" % [style, id])
	boss.health = boss.max_health * 0.25
	await frames(3)
	check(b.phase == 2, "%s · sotto il 33%%: fase 3" % style)
	boss.health = boss.max_health * 0.25
	calm(b)


## Il giocatore muore: il boss lo lascia stare, non si cura da solo, il giocatore rinasce.
func defeat(boss, style: String) -> void:
	var b = boss.brain
	calm(b)
	tough()
	var kept: float = boss.health
	world.hit_player(p, 10000000.0, {}, boss.global_position)
	check(p.dead, "%s · sconfitta: il giocatore muore" % style)
	await frames(8)
	check(b.target != p, "%s · sconfitta: da morto il boss non lo punta più" % style)
	await wait(2.0)
	check(not p.dead, "%s · sconfitta: il giocatore rinasce (%.0f m dal boss)" % [style, p.global_position.distance_to(boss.global_position)])
	check(is_instance_valid(boss) and not boss.dead and boss.health >= kept - 0.01, "%s · sconfitta: il boss resta com'era finché non scatta il reset" % style)
	tough()


## Ucciso: la ricompensa arriva, e colpire il cadavere o aspettare non la ripete.
func reward_once(boss, style: String, credits: int, money: int, heads: int, more: Callable) -> void:
	check(p.credits == money + credits and total(HEADS[style]) == heads + 1, "%s · vittoria: +%d crediti (%d -> %d) e la testa (%d -> %d)" % [style, credits, money, p.credits, heads, total(HEADS[style])])
	check(more.call(), "%s · vittoria: la storia va avanti" % style)
	boss.receive_hit("torso", 5000.0, Vector3.ZERO, "axe", true)
	boss.receive_hit("head", 5000.0, Vector3.ZERO, "machete", true)
	await wait(1.0)
	check(p.credits == money + credits and total(HEADS[style]) == heads + 1, "%s · ricompensa una volta sola" % style)


func run() -> void:
	world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await wait(0.6)
	p = world.player
	quest = world.quest
	p.rig.set_physics_process(false)
	p.set_physics_process(false)
	world.spawner.set_process(false)
	world.spawner.set_physics_process(false)
	for t in world.targets:
		if is_instance_valid(t):
			t.set_physics_process(false)
			t.global_position += Vector3(0, -300, 0)
	await capomacello()
	await macellaio()
	await carceriere()
	await zone2("matriarca")
	await zone2("signore")
	print("BOSS MATRICE ", "OK" if fails == 0 else "FALLITO %d" % fails)
	quit(fails)


# ------------------------------------------------------------------ Capomacello: altare nella radura
func capomacello() -> void:
	var hunt = world.boss_hunt
	quest.stage = quest.FOREST_BOSS
	p.baits = 1
	var altar: Vector3 = hunt.esche[0].global_position
	p.global_position = ground(altar + Vector3(1.0, 0, 0))
	tough()
	check(hunt.try_summon(p) and p.baits == 0, "capomacello · ingresso: l'esca accende l'altare")
	var boss = hunt.bosses[-1]
	entered(boss, "capomacello")
	check(not hunt.try_summon(p), "capomacello · ingresso: un altare acceso non evoca due volte")
	await past_intro(boss)
	await phases(boss, "capomacello")
	await defeat(boss, "capomacello")
	print("  radura a %.0f m dal punto di rinascita" % hunt.rows[0][1].distance_to(world.respawn_point()))
	# Reset: tutti lontani dalla radura per 22 s (qui l'orologio parte da 21,9).
	p.global_position = ground(hunt.rows[0][1] + Vector3(120, 0, 0))
	hunt._away = 21.9
	await frames(10)
	check(hunt.bosses.is_empty() and not hunt.used[0] and p.baits == 1 and not is_instance_valid(boss), "capomacello · reset: torna nel bosco e ridà l'esca")
	p.global_position = ground(altar + Vector3(1.0, 0, 0))
	check(hunt.try_summon(p), "capomacello · reset: si riprova")
	boss = hunt.bosses[-1]
	check(boss.health == boss.max_health and boss.brain.phase == 0, "capomacello · reset: riparte da vita piena e fase 1")
	await past_intro(boss)
	var b = boss.brain
	# Inferno: il fuoco cade dove è stato avvisato, non ti insegue.
	calm(b)
	b.phase = 1
	b.target = p
	tough()
	p.global_position = boss.global_position + Vector3(0, 0, 3.0)
	b.begin("inferno")
	await wait(0.7)
	check(b.move.has("marked"), "capomacello · inferno: il cerchio sotto il giocatore è segnato")
	p.global_position = boss.global_position + Vector3(0, 0, 22.0)
	var hp: float = p.health
	await wait(1.2)
	check(p.health >= hp, "capomacello · inferno: chi esce dal cerchio avvisato non si brucia (%.0f)" % (hp - p.health))
	# Gambe: un colpo forte che non uccide davvero non fa partire la morte finta.
	calm(b)
	boss.health = 400.0
	boss.receive_hit("legs", 600.0, Vector3.ZERO, "axe")
	check(not b.dying and not boss.dead and boss.health > 1.0, "capomacello · gambe: colpo forte ma non letale, niente morte finta (vita %.0f)" % boss.health)
	# Vittoria con un colpo letale alle gambe: prima restava a 1 di vita per sempre.
	var money: int = p.credits
	var heads: int = total(HEADS.capomacello)
	calm(b)
	boss.health = 30.0
	boss.receive_hit("legs", 200.0, Vector3.ZERO, "axe")
	await frames(10)
	check(boss.dead and b.dying, "capomacello · gambe: il colpo letale alle gambe lo uccide davvero")
	check(hunt.cleared[0], "capomacello · vittoria: la radura è bonificata")
	await reward_once(boss, "capomacello", 150, money, heads, func() -> bool: return quest.stage == quest.BRING_FOREST)
	check(not hunt.try_summon(p), "capomacello · vittoria: l'altare non lo evoca più")


# ------------------------------------------------------------------ Macellaio: pozzo di Borgo Cenere
func wait_boss(get_boss: Callable, seconds: float):
	var clock := 0.0
	while clock < seconds and not is_instance_valid(get_boss.call()):
		await physics_frame
		clock += 1.0 / 60.0
	return get_boss.call()


func macellaio() -> void:
	var v = world.village
	var well: Vector3 = ground(VL.CENTER + Vector3(3.5, 0, 3.5))
	quest.stage = quest.VILLAGE_BOSS
	p.baits = 1
	p.global_position = well
	tough()
	check(v.request_use(p) and v.arena == "active" and p.baits == 0 and v.barricade_up, "macellaio · ingresso: l'esca nel pozzo chiude la piazza")
	var boss = await wait_boss(func(): return v.boss, 5.0)
	entered(boss, "macellaio")
	await past_intro(boss)
	await phases(boss, "macellaio")
	await defeat(boss, "macellaio")
	p.global_position = ground(VL.CENTER + Vector3(70, 0, 0))
	v.empty_time = 19.95
	await wait(0.7)
	check(v.arena == "idle" and p.baits == 1 and not v.barricade_up and not is_instance_valid(boss), "macellaio · reset: piazza vuota, torna nel pozzo e ridà l'esca")
	p.global_position = well
	tough()
	check(v.request_use(p) and v.arena == "active", "macellaio · reset: si riprova")
	boss = await wait_boss(func(): return v.boss, 5.0)
	check(is_instance_valid(boss) and boss.health == boss.max_health and boss.brain.phase == 0, "macellaio · reset: riparte da vita piena e fase 1")
	await past_intro(boss)
	var b = boss.brain
	# Infetti del paese e sputatori sui tetti fermi: qui si misura solo il calcio.
	for e in world.targets:
		if is_instance_valid(e) and e != boss: e.set_physics_process(false)
	# Calcio: solo dentro lo spicchio avvisato.
	calm(b)
	b.target = null
	boss.rotation.y = 0.0
	tough()
	p.global_position = boss.global_position + Vector3(0, 0, 2.0)
	var hp: float = p.health
	b.begin("guardbreak")
	await wait(0.7)
	check(p.health >= hp, "macellaio · calcio: alle sue spalle non arriva (%.0f, boss girato di %.2f)" % [hp - p.health, boss.rotation.y])
	calm(b)
	boss.rotation.y = 0.0
	p.global_position = boss.global_position + Vector3(0, 0, -2.0)
	hp = p.health
	b.begin("guardbreak")
	await wait(0.7)
	check(p.health < hp, "macellaio · calcio: davanti, nello spicchio avvisato, sì")
	# Pompa a metà carica: conta chi spara da vicino anche se la sua preda è un altro (coop).
	calm(b)
	b.target = null
	p.global_position = boss.global_position + Vector3(0, 0, -4.0)
	b.begin("charge")
	await wait(0.3)
	boss.receive_hit("torso", 30.0, Vector3.ZERO, "sawn_off")
	check(b.stun > 0.0 and b.move.is_empty(), "macellaio · pompa da vicino lo ferma anche se non punta chi spara")
	var money: int = p.credits
	var heads: int = total(HEADS.macellaio)
	calm(b)
	boss.receive_hit("torso", 10000000.0, Vector3.ZERO, "axe")
	await wait(0.7)
	check(boss.dead and v.arena == "cleared" and not v.barricade_up, "macellaio · vittoria: barricate giù")
	await reward_once(boss, "macellaio", 0, money, heads, func() -> bool: return quest.stage == quest.BRING_VILLAGE and world.expedition.collected[1])
	check(v.arena == "cleared", "macellaio · vittoria: la piazza resta libera")


# ------------------------------------------------------------------ Carceriere: arena della Rocca
func carceriere() -> void:
	var r = world.rocca
	var inside: Vector3 = r.to_global(r.OCT_C + Vector3(0, 0.3, 6.0))
	quest.stage = quest.DUNGEON
	p.global_position = inside
	tough()
	check(r.area_of(p.global_position) == "arena", "carceriere · il giocatore è nell'arena della Rocca")
	r.place_bait()
	var boss = await wait_boss(func(): return r.boss, 8.0)
	entered(boss, "carceriere")
	await past_intro(boss)
	await phases(boss, "carceriere")
	await defeat(boss, "carceriere")
	# Gabbia alzata poi reset: le sbarre (corpi nel mondo) devono sparire con lui.
	var b = boss.brain
	calm(b)
	p.global_position = inside
	tough()
	b.target = p
	b.begin("cage")
	await wait(1.5)
	var bar = b.bars[0][1] if not b.bars.is_empty() else null
	check(bar != null, "carceriere · gabbia: le sbarre ci sono")
	p.global_position = world.respawn_point()
	r.arena_empty = 24.9
	await wait(0.8)
	check(not r.bait_placed and r.boss == null and not is_instance_valid(boss), "carceriere · reset: arena vuota, la carne torna, si richiude")
	check(not is_instance_valid(bar), "carceriere · reset: le sbarre della gabbia non restano nell'arena")
	p.global_position = inside
	tough()
	r.place_bait()
	boss = await wait_boss(func(): return r.boss, 8.0)
	check(is_instance_valid(boss) and boss.health == boss.max_health and boss.brain.phase == 0, "carceriere · reset: si riprova da vita piena e fase 1")
	await past_intro(boss)
	b = boss.brain
	calm(b)
	b.target = p
	b.begin("cage")
	await wait(1.5)
	bar = b.bars[0][1] if not b.bars.is_empty() else null
	var caged: bool = bar != null
	var money: int = p.credits
	var heads: int = total(HEADS.carceriere)
	boss.receive_hit("torso", 10000000.0, Vector3.ZERO, "sledgehammer", true)
	await wait(0.7)
	check(boss.dead and caged and not is_instance_valid(bar), "carceriere · morto con la gabbia alzata: le sbarre spariscono")
	check(r.boss_dead, "carceriere · vittoria: la Rocca lo segna morto")
	await reward_once(boss, "carceriere", 0, money, heads, func() -> bool: return quest.stage == quest.BRING_DUNGEON and quest.carceriere_dead)


# ------------------------------------------------------------------ Mago e Signore: Zona 2
func zone2(style: String) -> void:
	var z2 = world.zone2
	var at: Vector3 = Route.ARENA_MATRIARCA if style == "matriarca" else Route.ARENA_SIGNORE
	var get_boss := func(): return z2.boss_matriarca if style == "matriarca" else z2.boss_signore
	var close: Vector3 = ground(at + Vector3(0, 0, 20.0))
	p.global_position = close
	tough()
	var boss = await wait_boss(get_boss, 2.0)
	entered(boss, style)
	await past_intro(boss)
	await phases(boss, style)
	await defeat(boss, style)
	p.global_position = ground(at + Vector3(200, 0, 0))
	z2._away[style] = 21.95
	await wait(0.4)
	check(not is_instance_valid(boss) and get_boss.call() == null, "%s · reset: tutti lontani, torna a dormire" % style)
	p.global_position = close
	tough()
	boss = await wait_boss(get_boss, 2.0)
	check(is_instance_valid(boss) and boss.health == boss.max_health and boss.brain.phase == 0, "%s · reset: tornando riparte da vita piena e fase 1" % style)
	await past_intro(boss)
	var money: int = p.credits
	var heads: int = total(HEADS[style])
	calm(boss.brain)
	boss.receive_hit("torso", 10000000.0, Vector3.ZERO, "axe")
	await wait(0.5)
	check(boss.dead and (z2.dead_matriarca if style == "matriarca" else z2.dead_signore), "%s · vittoria: morto e registrato" % style)
	await reward_once(boss, style, 300, money, heads, func() -> bool: return z2.stage == z2.REPORT if style == "signore" else true)
	await wait(0.3)
	check(get_boss.call() == boss or not is_instance_valid(get_boss.call()) or get_boss.call().dead, "%s · vittoria: non ne nasce un altro" % style)
