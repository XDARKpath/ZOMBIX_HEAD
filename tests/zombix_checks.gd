# Verifica funzionale della campagna, della sopravvivenza e dei vincoli del server.
extends RefCounted
var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	print("PASS " if condition else "FAIL ",message)
	if not condition: failures.append(message)
func run(world: Node3D) -> bool:
	check(ProjectSettings.get_setting("application/config/name")=="ZOMBIX HEAD","Nuovo nome del gioco")
	check(world.camp.avatars.size()==4,"Accampamento compatibile con quattro giocatori")
	Session.launch()
	for i in range(10): await world.get_tree().physics_frame
	# La navigazione di Godot 4.5 si sincronizza in modo asincrono: si aspetta che sia pronta.
	for i in range(240):
		# La Rocca e la Cripta hanno già la loro navigazione (lontano dalla mappa): si aspetta quella del rifugio.
		if NavigationServer3D.map_get_closest_point(world.get_world_3d().navigation_map,Vector3(3,0.3,2)).distance_to(Vector3(3,0.3,2))<5.0: break
		await world.get_tree().physics_frame
	for enemy in world.targets: enemy.set_physics_process(false)
	var mission: Node3D = world.expedition
	var accessible := true
	for point in mission.POINTS:
		var closest := NavigationServer3D.map_get_closest_point(world.get_world_3d().navigation_map,point)
		var path := NavigationServer3D.map_get_path(world.get_world_3d().navigation_map,Vector3(3,0.3,2),closest,true)
		if point.distance_to(closest)>=1.5 or path.size()<=1: print("  percorso mancante verso ",point," vicino ",closest," passi ",path.size())
		accessible = accessible and point.distance_to(closest)<1.5 and path.size()>1
	check(accessible,"Percorsi navigabili dal rifugio ai tre ricambi")
	check(mission.stage==0 and mission.collected.count(true)==0,"Spedizione iniziale con tre ricambi")
	check(not mission.use(999),"Interazione rifiutata per un giocatore inesistente")
	world.player.position = Vector3(30,0,5)
	check(not mission.use(1),"Non si raccolgono ricambi a distanza")
	for i in range(3):
		world.player.position = mission.POINTS[i]+Vector3(0,0.1,1.5)
		for frame in range(2): await world.get_tree().physics_frame
		check(mission.use(1),"Raccolta reale del ricambio %d" % (i+1))
	check(mission.stage==1,"Tre ricambi sbloccano la riparazione")
	check(world.survival.threat==3,"Ogni ricambio alza l'allerta degli infetti")
	check(world.targets.size()<=36,"L'assalto resta entro il tetto dei corpi")
	world.player.position = mission.car.position+Vector3(0,0.1,2)
	for frame in range(2): await world.get_tree().physics_frame
	check(mission.use(1) and mission.repairing_peer==1,"Riparazione avviata vicino al 4×4")
	var before: float = mission.hold
	mission._process(0.5)
	check(mission.hold<before,"La riparazione avanza con il sopravvissuto presente")
	world.player.position = Vector3(30,0.1,5)
	mission._process(0.5)
	check(mission.repairing_peer==0,"La riparazione si interrompe se ci si allontana")
	check(world.survival.PRICES["pistol"]==125 and world.survival.PRICES["knife"]==50,"Prezzi delle due armi del negozio")
	world.player.credits=200
	world.player.position = preload("res://world/zona1_rifugio/refuge_layout.gd").SHOP_NPC+Vector3(0,0.1,1.2)
	for frame in range(2): await world.get_tree().physics_frame
	check(world.survival.act(1,"buy:knife") and world.player.credits==150,"Acquisto del military knife")
	check(world.survival.act(1,"buy:pistol") and world.player.credits==25 and "pistol" in world.player.owned,"Acquisto della pistola compatta")
	world.player.carried_heads=2;world.player.equip_id("item_testa")
	world.player.credits=0
	world.player.position = preload("res://world/zona1_rifugio/refuge_layout.gd").SHERIFF_NPC+Vector3(0,0.1,1.2)
	for frame in range(2): await world.get_tree().physics_frame
	check(world.survival.act(1,"sell:item_testa") and world.survival.act(1,"sell:item_testa") and world.player.credits==50 and world.player.carried_heads==0,"Lo sceriffo paga 25 crediti per testa")
	check(world.survival.INTRO.size()>=4 and world.survival.INTRO[0].contains("traveler"),"Lo sceriffo si presenta come traveler")
	check(world.survival.sheriff_node.get_node_or_null("Chair")!=null,"Lo sceriffo è seduto su una sedia")
	var layout := preload("res://world/zona1_rifugio/refuge_layout.gd")
	var facing_ok := true
	for row in [[layout.SHERIFF,layout.YAW_EAST],[layout.SHOP,layout.YAW_WEST]]:
		var facing: Vector3 = Vector3(sin(row[1]),0,cos(row[1]))
		var to_road: Vector3 = Vector3(layout.ROAD_X-row[0].x,0,0).normalized()
		facing_ok = facing_ok and facing.dot(to_road)>0.9
	check(facing_ok,"Ogni facciata guarda la strada")
	var signage: Array = [0]
	_count_labels(world.landscape.get_node_or_null("RefugeBuildings"),signage)
	check(signage[0]==0,"Nessun cartello con testo nel villaggio")
	var village:Node=world.landscape.get_node("RefugeBuildings")
	check(village.get_node_or_null("TownRow")==null and village.get_node_or_null("SheriffOffice")!=null and village.get_node_or_null("Armory")!=null,"La zona ha solo sceriffo e armeria, nessun altro edificio")
	var neck_test:Node3D=world._spawn_enemy(Vector3(0,0.1,-16))
	neck_test.set_physics_process(false)
	neck_test.receive_hit("neck",20.0,Vector3.ZERO,"axe",false)
	check(not neck_test.beheaded,"Il collo regge un colpo d'ascia leggero")
	neck_test.receive_hit("neck",20.0,Vector3.ZERO,"axe",true)
	check(neck_test.beheaded,"Il colpo caricato al collo stacca la testa")
	var leg_test:Node3D=world._spawn_enemy(Vector3(3,0.1,-16))
	leg_test.set_physics_process(false)
	leg_test.receive_hit("legs",20.0,Vector3.ZERO,"axe",false)
	var standing:bool=not leg_test.crawling
	leg_test.receive_hit("legs",20.0,Vector3.ZERO,"axe",false)
	check(standing and leg_test.crawling and not leg_test.dead,"Due colpi alle gambe lo atterrano e striscia")
	var blade_test:Node3D=world._spawn_enemy(Vector3(-3,0.1,-16))
	blade_test.set_physics_process(false)
	var heads_before:int=world.survival.heads.size()
	blade_test.receive_hit("torso",90.0,Vector3.ZERO,"katana",false)
	var blunt_test:Node3D=world._spawn_enemy(Vector3(-6,0.1,-16))
	blunt_test.set_physics_process(false)
	blunt_test.receive_hit("torso",90.0,Vector3.ZERO,"crowbar",false)
	check(blade_test.beheaded and world.survival.heads.size()==heads_before+1 and blunt_test.dead and not blunt_test.beheaded,"Ucciso con una lama perde la testa da raccogliere, con un'arma contundente no")
	check(world.boss_hunt.esche.size()==3,"Tre altari ai margini delle arene")
	# Esca dallo sceriffo: senza esca l'altare non si accende, cinque teste ne danno una.
	world.player.baits=0
	world.player.position = world.boss_hunt.esche[0].global_position+Vector3(1,0.1,0)
	check(not world.boss_hunt.try_summon(world.player) and not world.boss_hunt.used[0],"Senza esca l'altare resta spento")
	world.player.position = preload("res://world/zona1_rifugio/refuge_layout.gd").SHERIFF_NPC+Vector3(-1.6,0.1,0)
	world.player.carried_heads=5;world.player.equip_id("item_testa")
	for frame in range(2): await world.get_tree().physics_frame
	for _i in 5: world.survival.act(1,"sell:item_testa")
	check(world.player.baits==1,"Cinque teste consegnate: lo sceriffo dà un'esca")
	world.player.position = world.boss_hunt.esche[0].global_position+Vector3(1,0.1,0)
	check(world.boss_hunt.try_summon(world.player) and world.player.baits==0,"L'esca accende l'altare e viene consumata")
	world.boss_hunt.used[0]=false
	for boss in world.boss_hunt.bosses: boss.queue_free()
	world.boss_hunt.bosses.clear()
	mission.stage=2;mission.unlocked=1;mission.car.repaired=true
	check(mission.title()=="EVOCA I CUSTODI CON LE ESCHE","La partenza chiede di evocare i custodi")
	check(world.boss_hunt.summon(0),"L'esca del cortile evoca il primo custode")
	var capo:Node3D=world.boss_hunt.bosses[0]
	world.player.reset_at(capo.global_position+Vector3(0,0.1,2.0))
	for frame in range(120): await world.get_tree().physics_frame
	check(capo.state!=0,"Il custode si sveglia quando ti avvicini")
	check(world.player.health<100,"Il custode ferisce davvero il sopravvissuto")
	world.player.reset_at(Vector3(3,0.1,2))
	check(world.boss_hunt.summon(1) and world.boss_hunt.summon(2),"Le altre esche evocano gli altri custodi")
	var titles:Array=[]
	for boss in world.boss_hunt.bosses: titles.append(boss.title)
	check(titles.size()==3 and titles[0]!=titles[1] and titles[1]!=titles[2],"I tre custodi sono diversi")
	check(world.boss_hunt.bosses[0].max_health>=500 and world.boss_hunt.bosses[1].max_health>=350,"I custodi hanno vita da boss")
	check(not world.boss_hunt.summon(0),"Un'esca spenta non evoca due volte")
	check(mission.title()=="ABBATTI I TRE CUSTODI","La partenza è bloccata finché i custodi sono vivi")
	for boss in world.boss_hunt.bosses: boss.receive_hit("torso",10000.0,Vector3.ZERO,"axe")
	check(world.boss_hunt.all_cleared(),"Abbattere i tre custodi bonifica la Zona 1")
	check(mission.title()=="SEGUI IL GPS","Dopo i custodi la missione riprende il viaggio")
	check(world.roadblocks.points.size()==2 and world.roadblocks.cleared.count(true)==0,"Due sbarramenti chiudono la strada per la Zona 2")
	check(not world.roadblocks.clear_near(world.player),"Uno sbarramento non si apre senza eliminare gli infetti")
	world.player.dead = true
	world.player.position = mission.POINTS[0]
	check(not mission.use(1),"Un giocatore morto non può interagire")
	world.player.dead = false
	check(is_instance_valid(world.overlay) and is_instance_valid(world.presentation),"Nuovo HUD e ambiente attivi")
	print("ZOMBIX: ",failures.size()," errori")
	return failures.is_empty()

func _count_labels(node: Node, total: Array) -> void:
	if node == null: return
	for child in node.get_children():
		# I cartellini dei prezzi sulle armi in vendita da Big Earl non sono insegne.
		if String(child.name).begins_with("Stock_"): continue
		if child is Label3D: total[0] += 1
		_count_labels(child,total)

