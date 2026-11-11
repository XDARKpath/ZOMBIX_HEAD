extends Node3D
const Layout=preload("res://world/zona1_rifugio/refuge_layout.gd")
const Anatomy=preload("res://art/infected_anatomy.gd")
const Props2=preload("res://ui/camp/camp_props.gd")
const PRICES={"knife":50,"pistol":125}
const NAMES={"pistol":"PISTOLA COMPATTA","knife":"MILITARY KNIFE"}
const DESCS={"pistol":"8 colpi · ricarica R · buona a media distanza","knife":"Veloce e silenzioso · più danno da vicino"}
# Si tratta dal marciapiede, non solo appoggiandosi al banco.
const TRADE_DISTANCE:=3.6
const HEADS_PER_BAIT:=5
const MAX_BAITS:=3
const ThrownItem=preload("res://world/campaign/thrown_item.gd")
## Oggetti lanciati o lasciati: {"sid","item","node"}. Sull'host node è il RigidBody, sui client un modello mosso da thrown_state.
var thrown:Array=[]
var next_thrown:int=1
var thrown_clock:float=0.0
var sell_prompt:Control
var sell_hold:float=0.0
var sell_auto:bool=false
var sold_once:bool=false
var pending_use:String=""
## [Q] come in How to Fish: tenendo premuto aumenta la forza del lancio, al rilascio parte.
const THROW_MIN:=6.0
const THROW_MAX:=16.0
const THROW_CHARGE:=0.8
## [Q] lasciato prima di questo tempo: l'oggetto cade ai piedi invece di essere lanciato.
const THROW_TAP:=0.2
var throw_hold:float=-1.0
var throw_force:float=THROW_MAX
var _vm_cache:Node3D
var world:Node3D
var threat:int=0
var heads:Array=[]
var head_nodes:Dictionary={}
var next_head:int=1
var shop_ui:Control
var wallet:Label
var shop_open:bool=false
var shop_buttons:Dictionary={}
var shop_slot:Button
var zx:Node3D
var shop_npc:Node3D
const MAX_SLOTS:=8
## Consigli del primo incontro con lo sceriffo, in quest'ordine (world.tip li mostra uno dopo l'altro).
const TUTORIAL_TIPS:=["Click: colpo rapido  ·  Tieni premuto: colpo caricato","Tasto destro: pari con le armi bianche, miri con quelle da fuoco","Armi da fuoco: click per sparare  ·  R per ricaricare","Infetto a terra: colpiscilo alla testa con l'ascia per staccarla","Testa in mano davanti allo sceriffo: V per venderla"]
var wave_serial:int=0
var sheriff_node:Node3D
var dialogue:Control
var dialogue_ui
var dialogue_text:Label
var dialogue_hint:Label
var dialogue_page:Label
var dialogue_open:bool=false
var dialogue_lines:Array=[]
var dialogue_index:int=0
var seen_intro:bool=false
const GREETING:=["Portami teste, traveler."]
const CUSTODI_INFO:=[
	"Tre cose tengono in pugno questa zona: il Capomacello nel bosco, il Macellaio a Borgo Cenere e il Carceriere sotto la Rocca.",
	"Il Capomacello e il Macellaio escono solo se gli porti un'esca: sull'altare nel bosco, nel pozzo del borgo. L'esca te la do io, quando sei pronto.",
	"Ognuno custodisce un pezzo del tuo 4×4: batteria, cinghia, tanica. Senza quelli da qui non te ne vai.",
]
const HEAD_TIP:=[
	"Non tutte le teste valgono uguale. Infetto 25, corridore 40, sputatore 55, urlatore 70, bruto 100. Quelle dei custodi molto di più.",
	"Più di cinque dello stesso tipo non te le porti dietro. Tieni la testa in mano e premi V davanti a me.",
	"La testa si stacca solo dal morto. Prima lo ammazzi, poi colpisci il cadavere con una lama, alla testa o al collo. Con un bastone non fai niente.",
]
const DIALOGUE_OPTIONS:=["Chi sono i custodi?","Come si taglia una testa?","Torno dopo."]

func _ready() -> void:
	var cfg:=ConfigFile.new()
	if cfg.load("user://story.cfg")==OK:seen_intro=bool(cfg.get_value("story","met_sheriff",false))
func build(owner_world:Node3D) -> void:
	world=owner_world;name="SurvivalRules"
	# Sceriffo a est della strada (guarda a ovest), armaiolo sul lato opposto.
	_sheriff()
	_shopkeeper()
	_build_shop()
	_build_dialogue()
	sell_prompt=preload("res://ui/sell_prompt.gd").new();sell_prompt.name="SellPrompt";world.get_node("Interface").add_child(sell_prompt);sell_prompt.build(self)
	# Negozi di zona del pacchetto 0.14 lungo la rotta (dopo il terreno, che dà l'altezza del suolo).
	zx=preload("res://world/campaign/zx_shops.gd").new();add_child(zx)
	zx.call_deferred("build",world,self)
func authority() -> bool:return not Session.online or multiplayer.is_server()
func reset() -> void:
	close_shop();threat=0;wave_serial=0;next_head=1;heads.clear();_refresh_heads()
	for row in thrown:
		if is_instance_valid(row["node"]):row["node"].queue_free()
	thrown.clear();sell_auto=false;sell_hold=0.0;pending_use=""
	for actor in world.actors.values():actor.reset_inventory()
func _npc(at:Vector3,skin:int,facing:float) -> void:
	var previous:Camera3D=get_viewport().get_camera_3d()
	var npc:CharacterBody3D=load("res://player/player.tscn").instantiate();npc.local_control=false;add_child(npc)
	npc.position=at;npc.set_physics_process(false);npc.controls_enabled=false;npc.rig.controls_enabled=false;npc.rig.set_physics_process(false);npc.rig.camera.current=false
	npc.collision_layer=1;npc.set_meta("trader",true)
	var model:Node3D=world._dress(npc,skin)
	if model.axe:model.axe.queue_free();model.axe=null
	npc.visual.rotation.y=facing
	if previous:previous.current=true
func _sheriff() -> void:
	# Sedia da portico e corpo seduto: lo sceriffo non passeggia, aspetta le taglie.
	var body:=StaticBody3D.new();body.name="Sheriff";body.position=Layout.SHERIFF_NPC
	body.collision_layer=1;body.set_meta("trader",true);add_child(body)
	sheriff_node=body
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=0.42;capsule.height=1.2;shape.shape=capsule;shape.position.y=0.8;body.add_child(shape)
	var chair:=Node3D.new();chair.name="Chair";body.add_child(chair)
	var cwood:=Color("5b4630")
	var cdark:=Color("3d2d1f")
	var leather:=Color("5d3b2d")
	var brass:=Color("c9a468")
	Props2.box(chair,Vector3(0,0.45,0),Vector3(0.56,0.08,0.54),cdark)
	Props2.box(chair,Vector3(0,0.51,0),Vector3(0.48,0.05,0.46),leather)
	for z in [-0.22,0.22]:
		Props2.box(chair,Vector3(0.28,0.82,z),Vector3(0.06,0.80,0.06),cdark)
	for y in [0.62,0.80,0.98]:
		Props2.box(chair,Vector3(0.29,y,0),Vector3(0.05,0.08,0.46),cwood)
	Props2.box(chair,Vector3(0.29,1.06,0),Vector3(0.07,0.06,0.50),cdark)
	for z in [-0.30,0.30]:
		Props2.box(chair,Vector3(0.05,0.72,z),Vector3(0.56,0.06,0.06),cwood)
		Props2.box(chair,Vector3(0.25,0.59,z),Vector3(0.06,0.26,0.06),cdark)
		Props2.box(chair,Vector3(0.05,0.70,z),Vector3(0.04,0.04,0.04),brass)
	for sx in [-0.20,0.20]:
		for sz in [-0.20,0.20]:
			Props2.box(chair,Vector3(sx,0.22,sz),Vector3(0.07,0.42,0.07),cdark)
	Props2.box(chair,Vector3(0,0.18,-0.22),Vector3(0.40,0.04,0.04),cwood)
	Props2.box(chair,Vector3(0,0.18,0.22),Vector3(0.40,0.04,0.04),cwood)
	# sputacchiera da portico accanto alla sedia
	Props2.cylinder(chair,Vector3(0.40,0.13,0.34),0.08,0.22,Color("5d584c"),0.35)
	var avatar:=Node3D.new();avatar.name="SheriffBody"
	avatar.set_script(preload("res://world/campaign/sheriff.gd"))
	body.add_child(avatar)
	avatar.position=Vector3(0,-0.42,0.06);avatar.rotation.y=-PI/2
	avatar.configure_seated("NPC_Veteran")

func _shopkeeper() -> void:
	# Big Earl in piedi, appoggiato al banco: posa diversa dallo sceriffo seduto.
	var body:=StaticBody3D.new();body.name="Shopkeeper";body.position=Layout.SHOP_NPC
	body.collision_layer=1;body.set_meta("trader",true);add_child(body)
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=0.42;capsule.height=1.5;shape.shape=capsule;shape.position.y=0.78;body.add_child(shape)
	# Big Earl (art/zx_npc/SM_NPC_Shopkeeper, il venditore della Zona 1 nel catalogo del pacchetto 0.14):
	# appoggiato al banco con NPC_Counter_Lean, parla e mostra l'arma.
	shop_npc=ZXNpc.new();shop_npc.name="ShopkeeperBody";shop_npc.npc="SM_NPC_Shopkeeper"
	body.add_child(shop_npc)
	# L'armaiolo guarda verso la strada, non verso il fondo del negozio.
	shop_npc.rotation.y=PI/2

## Le teste si vendono allo sceriffo di Lago Cenere e a Mira a Porto Secco.
func _near_sheriff(a:CharacterBody3D) -> bool:
	if _near(a,Layout.SHERIFF_NPC,TRADE_DISTANCE):return true
	return world.get("zone2")!=null and world.zone2.near_sheriff(a,TRADE_DISTANCE)

## Vita e fiato massimi: come lo zaino, ma al massimo due per zona. kind "health" o "stamina".
func upgrade_price(kind:String,a:CharacterBody3D=null) -> int:
	if a==null:a=world.player
	return 90+a._ups(a.health_ups if kind=="health" else a.stamina_ups)*60
## Zona del negozio a portata dell'attore (-1 se non è da nessun negozio): la decide la posizione, non il client.
func shop_zone(a:CharacterBody3D) -> int:
	if not zx:return -1
	var here:Dictionary=zx.near(a)
	if here.is_empty():
		for d in zx.displays:
			if String(d.id).begins_with("up_") and is_instance_valid(d.node) and a.global_position.distance_to(d.node.global_position)<=zx.REACH+1.0:
				return int(d.shop.zone) if d.shop else 0
		return -1
	return int(here.shop.zone) if here.shop else 0
func upgrades_left(kind:String,a:CharacterBody3D,zone:int) -> int:
	var table:Dictionary=a.health_ups if kind=="health" else a.stamina_ups
	return a.UPGRADES_PER_ZONE-int(table.get(str(zone),0))
func slot_price() -> int:
	return 60+(world.player.inventory_slots-4)*40

func _drop_weapon(a:CharacterBody3D) -> bool:
	# X: lascia per terra quello che hai in mano, per liberare uno slot (lo stesso oggetto del lancio, con poca forza).
	if a.equipped=="":return false
	if not ItemInfo.is_item(a.equipped) and a.owned.size()<=1:
		world.announce("TI SERVE ALMENO UN'ARMA",4);return false
	return _let_go(a,a.equipped,2.0)
## Un pezzo di id esce dall'inventario e diventa un corpo nel mondo: lanciato forte oppure appena lasciato.
func _let_go(a:CharacterBody3D,id:String,force:float) -> bool:
	if not a.has_thing(id):return false
	var dir:Vector3=Basis.from_euler(Vector3(a.rig.pitch,a.rig.yaw,0))*Vector3.FORWARD
	var at:Vector3=a.global_position+Vector3.UP*a.eye_height+dir*0.5
	var push:Vector3=dir*force*(0.75 if ItemInfo.heavy(id) else 1.0)+Vector3.UP*(1.5 if force>THROW_MIN else 1.0)
	if force<THROW_MIN:
		# Lasciato: cade davanti ai piedi, senza volare.
		var flat:Vector3=Basis.from_euler(Vector3(0,a.rig.yaw,0))*Vector3.FORWARD
		at=a.global_position+flat*0.4+Vector3.UP*0.5
		push=flat*0.5
	a.remove_one(id)
	var body:=ThrownItem.new()
	body.setup(self,id,next_thrown,a,at,push)
	thrown.append({"sid":next_thrown,"item":id,"node":body});next_thrown+=1
	_publish();return true
## Oggetto lanciato fermo per terra: la testa torna una testa normale, il resto aspetta di essere raccolto.
func thrown_rest(body:Node3D) -> void:
	if ItemInfo.is_head(body.item):
		var landing:Vector3=body.global_position+Vector3.UP*0.1
		heads.append([next_head,ItemInfo.head_path(body.item),body.global_transform,landing,body.item]);next_head+=1
		thrown_remove(body);return
	_publish()
func thrown_remove(body:Node3D) -> void:
	for row in thrown.duplicate():
		if row["node"]==body:thrown.erase(row)
	body.queue_free()
	_publish()
func _thrown_rows() -> Array:
	var rows:Array=[]
	for row in thrown:
		if is_instance_valid(row["node"]):rows.append([row["sid"],row["item"],row["node"].global_transform])
	return rows
## Client: modelli degli oggetti lanciati, mossi dall'host.
@rpc("authority","call_remote","unreliable_ordered")
func thrown_state(rows:Array) -> void:
	var seen:Array=[]
	for r in rows:
		seen.append(r[0])
		var row:Dictionary={}
		for t in thrown:
			if t["sid"]==r[0]:row=t
		if row.is_empty():
			var node:=Node3D.new();add_child(node)
			var m:=ItemInfo.model(r[1])
			if m:node.add_child(m)
			row={"sid":r[0],"item":r[1],"node":node};thrown.append(row)
		row["node"].global_transform=r[2]
	for t in thrown.duplicate():
		if not seen.has(t["sid"]):
			if is_instance_valid(t["node"]):t["node"].queue_free()
			thrown.erase(t)
## Stato completo dopo ogni cambiamento (affidabile: un oggetto raccolto deve sparire anche sui client).
@rpc("authority","call_remote","reliable")
func thrown_sync(rows:Array) -> void:
	thrown_state(rows)
## Gesto visto dagli altri giocatori (zx_avatar_driver legge il meta): lancio, cura, consegna, raccolta, saluto.
func gesture(a:CharacterBody3D,what:String) -> void:
	_set_gesture(a,what)
	if Session.online and multiplayer.is_server():
		var peer:int=world.actors.find_key(a)
		for other in Session.connected_peers():gesture_seen.rpc_id(other,peer,what)
@rpc("authority","call_remote","reliable")
func gesture_seen(peer:int,what:String) -> void:
	if world.actors.has(peer):_set_gesture(world.actors[peer],what)
func _set_gesture(a:CharacterBody3D,what:String) -> void:
	a.set_meta("gesture_what",what);a.set_meta("gesture_serial",int(a.get_meta("gesture_serial",0))+1)

func _build_dialogue() -> void:
	# Il pannello vive in ui/sheriff_dialogue.gd: ritratto, testo e tre scelte.
	dialogue_ui=preload("res://ui/sheriff_dialogue.gd").new()
	dialogue_ui.name="SheriffDialogue"
	world.get_node("Interface").add_child(dialogue_ui)
	dialogue_ui.build()
	dialogue=dialogue_ui
	dialogue_text=dialogue_ui.text_label
	dialogue_hint=dialogue_ui.hint_label
	dialogue_page=dialogue_ui.page_label
	dialogue_ui.choice_selected.connect(_on_dialogue_choice)
	dialogue_ui.hide()

## Pannello di dialogo per gli altri NPC (stesso pannello dello sceriffo): righe, tre scelte e chi le gestisce.
var npc_choice:Callable
func open_npc_dialogue(speaker:String,lines:Array,options:Array,on_choice:Callable) -> void:
	if dialogue_open or not world.started:return
	dialogue_lines=lines;dialogue_index=0;dialogue_open=true;npc_choice=on_choice
	world.ui_open=true;world.player.controls_enabled=false;world.player.rig.controls_enabled=false;world.player.melee.cancel()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	dialogue_ui.set_speaker(speaker);dialogue_ui.set_choices(options)
	dialogue.modulate.a=0.0;dialogue.show();_show_line()
	var tween:=create_tween();tween.tween_property(dialogue,"modulate:a",1.0,0.18)
func show_npc_lines(lines:Array) -> void:
	dialogue_lines=lines;dialogue_index=0;_show_line()
func open_sheriff_dialogue() -> void:
	if dialogue_open or not world.started:return
	dialogue_lines=world.quest.lines() if world.get("quest") else GREETING
	dialogue_index=0;dialogue_open=true;npc_choice=Callable();dialogue_ui.set_speaker("Sceriffo")
	world.ui_open=true;world.player.controls_enabled=false;world.player.rig.controls_enabled=false;world.player.melee.cancel()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	dialogue_ui.set_choices(DIALOGUE_OPTIONS)
	dialogue.modulate.a=0.0;dialogue.show();_show_line()
	var tween:=create_tween();tween.tween_property(dialogue,"modulate:a",1.0,0.18)

func _show_line() -> void:
	if dialogue_ui==null:return
	dialogue_ui.set_line(str(dialogue_lines[dialogue_index]),"%d / %d"%[dialogue_index+1,dialogue_lines.size()],"E  CHIUDI" if dialogue_index>=dialogue_lines.size()-1 else "E  CONTINUA")

func _on_dialogue_choice(index:int) -> void:
	choose_sheriff_option(index)

func choose_sheriff_option(index:int) -> void:
	if not dialogue_open:return
	if npc_choice.is_valid():npc_choice.call(index);return
	match index:
		0:
			dialogue_lines=CUSTODI_INFO;dialogue_index=0;_show_line()
		1:
			dialogue_lines=HEAD_TIP;dialogue_index=0;_show_line()
		2:
			close_sheriff_dialogue()

func advance_sheriff_dialogue() -> void:
	if not dialogue_open:return
	# Prima pressione: completa la frase che si sta scrivendo.
	if dialogue_ui.skip():return
	dialogue_index+=1
	if dialogue_index>=dialogue_lines.size():close_sheriff_dialogue();return
	_show_line()

func close_sheriff_dialogue() -> void:
	if not dialogue_open:return
	dialogue_open=false;dialogue.hide()
	world.ui_open=false;world.player.controls_enabled=true;world.player.rig.controls_enabled=true
	if npc_choice.is_valid():
		npc_choice=Callable();dialogue_ui.set_choices(DIALOGUE_OPTIONS);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;return
	# Fine del discorso con lo sceriffo: la missione va avanti (esca, consegna della testa del custode...).
	if world.get("quest") and world.quest.stage==world.quest.TALK and world.has_method("tip"):
		# Primo incontro: il vecchio "parla con lo sceriffo" sparisce e i consigli arrivano uno alla volta.
		world.notice_left=0.0
		for row in TUTORIAL_TIPS:world.tip(Localization.t(row),5.5)
	request("quest:talk")
	if not seen_intro:
		seen_intro=true
		var cfg:=ConfigFile.new();cfg.set_value("story","met_sheriff",true);cfg.save("user://story.cfg")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func drop_head(enemy:Node3D,at:Transform3D) -> void:
	if not authority():return
	var landing:Vector3=enemy.position+Vector3(0.5,0.18,0.5)
	var ray:=PhysicsRayQueryParameters3D.create(landing+Vector3.UP*3,landing-Vector3.UP*6,1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():landing.y=hit.position.y+0.18
	# Ogni tipo di infetto lascia la sua testa: vale di più quanto è più pericoloso.
	var kinds:Array=ItemInfo.KIND_HEAD
	heads.append([next_head,enemy.avatar.model_id,at,landing,kinds[clampi(int(enemy.kind),0,kinds.size()-1)]]);next_head+=1
	_publish()
func _refresh_heads() -> void:
	var present:Array=[]
	for row in heads:
		var id:int=row[0];present.append(id)
		if head_nodes.has(id):continue
		var node:MeshInstance3D=Anatomy.loose(row[1]);add_child(node);node.global_transform=row[2];head_nodes[id]=node
		var tween:=create_tween();tween.tween_property(node,"global_position",row[3],0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for id in head_nodes.keys():
		if not present.has(id):head_nodes[id].queue_free();head_nodes.erase(id)

func _near(actor:CharacterBody3D,at:Vector3,distance:float=3) -> bool:
	if actor.dead or actor.seated or actor.position.distance_to(at)>distance: return false
	var q:=PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP,at+Vector3.UP,1,[actor.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(q)
	# Il banco e il retrobanco non devono nascondere l'armaiolo al cliente.
	return hit.is_empty() or hit.collider.has_meta("trader") or hit.collider.has_meta("shop_fixture")
func context() -> String:
	if not world.started:return ""
	var a:CharacterBody3D=world.player
	if world.get("weapon_table"):
		var table_hint:String=world.weapon_table.context(a)
		if not table_hint.is_empty():return table_hint
	if world.get("zone_life"):
		var life:String=world.zone_life.context()
		if not life.is_empty():return life
	for row in heads:
		if _near(a,row[3],2.6):
			if not a.can_take(row[4]):return Localization.t("{0} · NE PUOI PORTARE AL MASSIMO {1}",[ItemInfo.title(row[4]).to_upper(),ItemInfo.MAX_STACK])
			return Localization.t("E  RACCOGLI {0} · {1} CREDITI",[ItemInfo.title(row[4]).to_upper(),ItemInfo.head_price(row[4])])
	for row in thrown:
		if is_instance_valid(row["node"]) and _near(a,row["node"].global_position,2.6):return Localization.t("E  RACCOGLI {0}",[ItemInfo.title(row["item"]).to_upper()])
	# Accanto a un cadavere con la testa ancora attaccata: come si stacca.
	for body in world.targets:
		if is_instance_valid(body) and body.dead and not body.beheaded and body.kind<5 and body.global_position.distance_to(a.global_position)<2.4:
			if preload("res://weapons/zx_arsenal.gd").beheads(a.equipped):return Localization.t("COLPISCI IL CADAVERE ALLA TESTA · LA STACCHI")
			return Localization.t("PER STACCARE LA TESTA SERVE UNA LAMA")
	if world.get("zone2") and world.zone2.near_sheriff(a,TRADE_DISTANCE) and not ItemInfo.is_head(a.equipped):return world.zone2.context(a)
	if _near_sheriff(a):
		if ItemInfo.is_head(a.equipped):return Localization.t("[V] VENDI {0} · {1} CREDITI   (hai ×{2})",[ItemInfo.title(a.equipped).to_upper(),ItemInfo.head_price(a.equipped),int(a.items.get(a.equipped,0))])
		if a.carried_heads>0:
			for n in range(a.inventory_slots):
				if ItemInfo.is_head(a.hotbar[n]):return Localization.t("METTI LA TESTA IN MANO PER VENDERLA  (tasto {0})",[n+1])
		return Localization.t("E  PARLA CON LO SCERIFFO")
	# Negozi: si compra guardando l'arma appesa al pannello (world/campaign/zx_shops.gd).
	if zx:
		var hint:String=zx.context(a)
		if not hint.is_empty():return hint
	if _near(a,Layout.SHOP_NPC,TRADE_DISTANCE):return Localization.t("GUARDA UN'ARMA SUL PANNELLO · E PER COMPRARE")
	if world.get("village"):
		var borgo:String=world.village.context(a)
		if not borgo.is_empty():return borgo
	if world.get("boss_hunt"):
		var esca:String=world.boss_hunt.context(a)
		if not esca.is_empty():return esca
	return world.roadblocks.context(a)
func request_context() -> bool:
	if world.get("weapon_table"):
		var on_table:String=world.weapon_table.looked_at(world.player)
		if on_table!="":
			request("table:"+on_table);return true
	if world.get("zone_life") and world.zone_life.request():return true
	if _pickup_near(world.player):
		request("use");return true
	if zx and zx.request(world.player):return true
	if _near(world.player,Layout.SHOP_NPC,TRADE_DISTANCE):
		# Big Earl non apre più un pannello: risponde e indica il pannello forato alle sue spalle.
		var line:String=shop_npc.talk(world.player.global_position) if shop_npc else ""
		world.announce(Localization.t("Big Earl: «{0}» · Guarda un'arma sul pannello e premi E.",[line]) if line!="" else Localization.t("Guarda un'arma sul pannello e premi E per comprarla."),4)
		return true
	# E dallo sceriffo parla e basta: le teste si vendono con [V], con la testa in mano.
	if _near(world.player,Layout.SHERIFF_NPC,TRADE_DISTANCE):
		open_sheriff_dialogue();return true
	if context().is_empty():return false
	request("use");return true
func _pickup_near(a:CharacterBody3D) -> bool:
	for row in heads:
		if _near(a,row[3],2.6):return true
	for row in thrown:
		if is_instance_valid(row["node"]) and _near(a,row["node"].global_position,2.6):return true
	return false
func request(action:String) -> void:
	if authority():act(multiplayer.get_unique_id(),action)
	else:command.rpc_id(1,action)
@rpc("any_peer","call_remote","reliable")
func command(action:String) -> void:
	if authority():act(multiplayer.get_remote_sender_id(),action)
func act(peer:int,action:String) -> bool:
	if not authority() or not world.started or not world.actors.has(peer):return false
	var a:CharacterBody3D=world.actors[peer]
	if a.dead or a.seated:return false
	if action.begins_with("table:"):
		if not world.get("weapon_table") or not world.weapon_table.take(a,action.get_slice(":",1)):return false
		gesture(a,"pickup");_publish();return true
	if action.begins_with("equip:"):
		var weapon:String=action.get_slice(":",1)
		if not a.has_thing(weapon) or a.melee.attacking or a.melee.charging or a.reload_left>0:return false
		a.equip_id(weapon);_publish();return true
	if action.begins_with("slot:"):
		if a.melee.attacking or a.melee.charging or a.reload_left>0:return false
		a.select_slot(int(action.get_slice(":",1)));_publish();return true
	if action.begins_with("throw:"):
		var id:String=action.get_slice(":",1)
		var force:float=clampf(float(action.get_slice(":",2)),THROW_MIN,THROW_MAX)
		if id!=a.equipped or id=="" or not _let_go(a,id,force):return false
		gesture(a,"throw")
		return true
	if action.begins_with("sell:"):
		# Si vende una testa alla volta, tenendola in mano, vicino allo sceriffo. L'host controlla tutto.
		var id:String=action.get_slice(":",1)
		if not _near_sheriff(a) or a.equipped!=id or not ItemInfo.is_head(id) or not a.items.has(id):return false
		gesture(a,"give")
		a.remove_one(id);a.credits+=ItemInfo.head_price(id);a.heads_delivered+=1
		if world.get("quest"):world.quest.on_head_sold(a,id)
		_publish();return true
	if action=="quest:talk":
		if world.get("quest"):world.quest.talk(a)
		_publish();return true
	if action.begins_with("useitem:"):
		var id:String=action.get_slice(":",1)
		if not a.items.has(id) or int(ItemInfo.ITEMS.get(id,{}).get("heal",0))<=0:return false
		a.health=minf(a.health+float(ItemInfo.ITEMS[id].heal),a.max_health())
		# Le bende fermano il sangue e il veleno, il cibo aiuta col veleno, il kit medico cura tutto.
		match id:
			"item_bende":a.status.clear(["bleed","poison"])
			"item_cibo":a.status.clear(["poison"])
			"item_kit_medico":a.status.clear_all()
		gesture(a,"use")
		a.remove_one(id);_publish();return true
	if action=="reload":return a.reload_weapon()
	if action.begins_with("buy:"):
		var weapon:String=action.get_slice(":",1)
		if not PRICES.has(weapon) or not _near(a,Layout.SHOP_NPC,TRADE_DISTANCE):return false
		if weapon in a.owned or a.credits<PRICES[weapon] or not a.can_take(weapon):return false
		a.credits-=PRICES[weapon];a.owned.append(weapon);a.equip_id(weapon);_publish()
		if shop_npc:shop_npc.show_item()
		return true
	if action.begins_with("zxbuy:"):
		# Armi dei negozi di zona: prezzo e scorte li decide il negozio vicino, sull'host.
		var weapon:String=action.get_slice(":",1)
		var price:int=zx.offer(a,weapon) if zx else -1
		# Oggetti da bancone (bende, cibo, kit medico): impilabili, non occupano gli slot delle armi.
		if price>=0 and ItemInfo.is_item(weapon):
			if a.credits<price or not a.can_take(weapon):return false
			a.credits-=price;a.add_item(weapon);_publish()
			if Session.online and peer!=multiplayer.get_unique_id():zx_bought.rpc_id(peer,weapon)
			else:zx.on_bought()
			return true
		# Consumabili (frecce): non occupano lo zaino, si comprano quante volte si vuole.
		if price>=0 and ZXWeapons.get_def(weapon).get("class","")=="consumable":
			if a.credits<price:return false
			a.credits-=price;a.arrows+=10;_publish()
			if Session.online and peer!=multiplayer.get_unique_id():zx_bought.rpc_id(peer,weapon)
			else:zx.on_bought()
			return true
		if price<0 or weapon in a.owned or a.credits<price or not a.can_take(weapon):return false
		a.credits-=price;a.owned.append(weapon);a.equip_id(weapon)
		if world.get("quest"):world.quest.on_weapon_bought()
		if weapon=="bow":a.arrows+=12
		a.magazine=preload("res://weapons/zx_arsenal.gd").magazine(weapon)
		_publish()
		if Session.online and peer!=multiplayer.get_unique_id():zx_bought.rpc_id(peer,weapon)
		else:zx.on_bought()
		return true
	if action=="buyslot":
		var cost:int=slot_price()
		if a.inventory_slots>=MAX_SLOTS or a.credits<cost:return false
		a.credits-=cost;a.inventory_slots+=1;_publish()
		world.announce(Localization.t("ZAINO PIÙ GRANDE · {0} SLOT",[a.inventory_slots]),4);return true
	if action.begins_with("buyup:"):
		var kind:String=action.get_slice(":",1)
		var zone:int=shop_zone(a)
		if not kind in ["health","stamina"] or zone<0:return false
		var cost:int=upgrade_price(kind,a)
		if upgrades_left(kind,a,zone)<=0 or a.credits<cost:return false
		var table:Dictionary=a.health_ups if kind=="health" else a.stamina_ups
		a.credits-=cost;table[str(zone)]=int(table.get(str(zone),0))+1
		if kind=="health":a.health=minf(a.health+a.HEALTH_PER_UPGRADE,a.max_health())
		else:a.stamina=minf(a.stamina+a.STAMINA_PER_UPGRADE,a.max_stamina())
		_publish()
		world.announce(Localization.t("VITA MASSIMA {0}",[int(a.max_health())]) if kind=="health" else Localization.t("FIATO MASSIMO {0}",[int(a.max_stamina())]),4);return true
	if action=="drop":return _drop_weapon(a)
	if action.begins_with("emote:"):
		gesture(a,action.get_slice(":",1) if action.get_slice(":",1) in ["wave","dance"] else "wave")
		return true
	if action!="use":return false
	for row in heads:
		if _near(a,row[3],2.6):
			if not a.can_take(row[4]):
				world.announce(Localization.t("NE PORTI GIÀ {0} · VAI DALLO SCERIFFO",[ItemInfo.MAX_STACK]) if a.items.has(row[4]) else Localization.t("TASCHE PIENE · Q LANCIA O X LASCIA QUELLO CHE HAI IN MANO"),4);return false
			gesture(a,"pickup")
			a.add_item(row[4]);heads.erase(row);_publish();return true
	for row in thrown.duplicate():
		if not is_instance_valid(row["node"]) or not _near(a,row["node"].global_position,2.6):continue
		var picked:String=row["item"]
		if not a.can_take(picked):
			world.announce(Localization.t("TASCHE PIENE · Q LANCIA O X LASCIA QUELLO CHE HAI IN MANO"),4);return false
		if ItemInfo.is_item(picked):a.add_item(picked)
		else:
			if picked not in a.owned:a.owned.append(picked)
			a.hotbar_add(picked)
		if a.equipped=="":a.equip_id(picked)
		thrown_remove(row["node"]);return true
	if world.get("boss_hunt") and world.boss_hunt.try_summon(a):return true
	return world.roadblocks.clear_near(a)
func raise_threat() -> void:
	if not authority() or threat>=3:return
	threat+=1;wave_serial+=1
	for enemy in world.targets:
		if not is_instance_valid(enemy) or enemy.dead:continue
		var ratio:float=enemy.health/enemy.max_health;enemy.set_kind(enemy.kind,threat);enemy.health=enemy.max_health*ratio
	var sites:=Layout.PART_POINTS
	var anchor:Vector3=sites[threat-1]
	var spawn_points:Array=[]
	for i in range(4+threat*2):
		var angle:float=i*TAU/(4+threat*2)
		var at:Vector3=anchor+Vector3(cos(angle)*24,0,sin(angle)*24)
		at=NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map,at)
		var nearest:CharacterBody3D=world.nearest_player(at)
		if nearest and nearest.position.distance_to(at)<13:at=anchor+Vector3(-22,0,-20-i*2)
		if Layout.safe(at):continue
		var enemy:Node3D=world._spawn_enemy(at)
		var kind:int=(i%(threat+1))
		enemy.set_kind(kind,threat)
		if nearest:enemy.hear(nearest,65)
	world.announce(Localization.t("ALLERTA {0} / 3 · Altri infetti si avvicinano. Torna dallo sceriffo per vendere le teste.",[threat]),7)
	_publish()
func _publish() -> void:
	_refresh_heads()
	var inventory:Array=[]
	for peer in world.actors:
		var a:CharacterBody3D=world.actors[peer];inventory.append([peer,a.credits,a.carried_heads,a.owned,a.equipped,a.baits,a.arrows,a.items,a.hotbar,a.slot,a.inventory_slots,a.health_ups,a.stamina_ups])
	if Session.online and multiplayer.is_server():
		for peer in Session.connected_peers():sync.rpc_id(peer,heads,inventory,threat,world.roadblocks.triggered,world.roadblocks.cleared);thrown_sync.rpc_id(peer,_thrown_rows())
@rpc("authority","call_remote","reliable")
func zx_bought(_weapon:String) -> void:
	if zx:zx.on_bought()
@rpc("authority","call_remote","reliable")
func sync(items:Array,inventory:Array,tier:int,road_started:Array,road_open:Array) -> void:
	heads=items;threat=tier;_refresh_heads()
	world.roadblocks.triggered=road_started;world.roadblocks.cleared=road_open;world.roadblocks.refresh()
	for row in inventory:
		if not world.actors.has(row[0]):continue
		var a:CharacterBody3D=world.actors[row[0]];a.credits=row[1];a.owned.assign(row[3]);a.equipped=row[4]
		if row.size()>5:a.baits=row[5]
		if row.size()>6:a.arrows=row[6]
		if row.size()>10:
			a.items=row[7].duplicate();a.hotbar.assign(row[8]);a.slot=row[9];a.inventory_slots=row[10]
		if row.size()>12:
			a.health_ups=row[11].duplicate();a.stamina_ups=row[12].duplicate()
func _build_shop() -> void:
	shop_ui=Control.new()
	shop_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.get_node("Interface").add_child(shop_ui)
	shop_ui.hide()
	var font:=SystemFont.new()
	font.font_names=PackedStringArray(["Bahnschrift","Segoe UI"])
	var theme:=Theme.new()
	theme.default_font=font
	theme.default_font_size=16
	shop_ui.theme=theme
	var title:=Label.new()
	title.position=Vector2(230,235)
	title.text=Localization.t("EMPORIO DI BIG EARL / LAGO CENERE")
	title.add_theme_font_size_override("font_size",30)
	title.add_theme_color_override("font_color",Color("e6f1e7"))
	shop_ui.add_child(title)
	wallet=Label.new()
	wallet.position=Vector2(890,240)
	wallet.size=Vector2(320,46)
	wallet.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	wallet.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	wallet.add_theme_color_override("font_color",Color("f2cf91"))
	shop_ui.add_child(wallet)
	preload("res://ui/glass/surface.gd").add(wallet,0.35)
	var grid:=HBoxContainer.new()
	grid.position=Vector2(230,310)
	grid.add_theme_constant_override("separation",18)
	shop_ui.add_child(grid)
	for id in ["pistol","knife","pack"]:
		var shell:=PanelContainer.new()
		shell.custom_minimum_size=Vector2(314,300)
		shell.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		grid.add_child(shell)
		preload("res://ui/glass/surface.gd").add(shell,0.4)
		var card:=VBoxContainer.new()
		card.add_theme_constant_override("separation",14)
		shell.add_child(card)
		var preview:=preload("res://ui/glass/preview.gd").new()
		preview.item_id=id
		preview.custom_minimum_size=Vector2(314,180)
		card.add_child(preview)
		var button:=Button.new()
		button.custom_minimum_size=Vector2(314,98)
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size",16)
		button.add_theme_stylebox_override("normal",_shop_box(Color(0.1,0.2,0.23,0.12),Color(0.55,0.8,0.8,0.22),1))
		button.add_theme_stylebox_override("hover",_shop_box(Color(0.9,0.6,0.25,0.3),Color("dfbc7f"),1))
		button.add_theme_stylebox_override("focus",_shop_box(Color(0.9,0.6,0.25,0.3),Color("dfbc7f"),1))
		button.add_theme_stylebox_override("pressed",_shop_box(Color(0.9,0.6,0.25,0.4),Color("dfbc7f"),1))
		button.add_theme_stylebox_override("disabled",_shop_box(Color(0.1,0.2,0.23,0.1),Color(0.5,0.6,0.6,0.16),1))
		button.add_theme_color_override("font_disabled_color",Color("a7b3ae"))
		card.add_child(button)
		preload("res://ui/glass/surface.gd").hover(button)
		if id=="pack":
			shop_slot=button
			button.pressed.connect(func():request("buyslot"))
		else:
			var weapon_id: String=id
			button.text="%s · %d CR\n%s"%[Localization.t(NAMES[id]),PRICES[id],Localization.t(DESCS[id])]
			button.pressed.connect(func():request("buy:"+weapon_id))
			shop_buttons[id]=button
	# Catalogo della Zona 1 (pacchetto 0.14): stesse armi dell'Emporio, vendute da questo banco.
	var catalog:=Button.new()
	catalog.position=Vector2(230,685)
	catalog.size=Vector2(420,42)
	catalog.text=Localization.t("CATALOGO LAGO CENERE  ·  {0} ARMI",[ZXShopCatalog.ZONES[0].stock.size()])
	catalog.add_theme_stylebox_override("normal",_shop_box(Color(0.1,0.2,0.23,0.2),Color(0.6,0.8,0.8,0.3),1))
	catalog.add_theme_stylebox_override("hover",_shop_box(Color(0.9,0.6,0.25,0.3),Color("dfbc7f"),1))
	shop_ui.add_child(catalog)
	catalog.pressed.connect(func():close_shop();zx.open_panel(world.player))
	preload("res://ui/glass/surface.gd").hover(catalog)
	var info:=Label.new()
	info.position=Vector2(230,640)
	info.text=Localization.t("ISPEZIONA · SCEGLI · SOPRAVVIVI     /     Le teste valgono 25 CR dallo sceriffo.")
	info.add_theme_font_size_override("font_size",13)
	info.add_theme_color_override("font_color",Color("c0d3ca"))
	shop_ui.add_child(info)
	var close:=Button.new()
	close.position=Vector2(970,685)
	close.size=Vector2(240,42)
	close.text=Localization.t("E / ESC   TORNA ALLA STRADA")
	close.add_theme_stylebox_override("normal",_shop_box(Color(0.1,0.2,0.23,0.2),Color(0.6,0.8,0.8,0.3),1))
	close.add_theme_stylebox_override("hover",_shop_box(Color(0.9,0.6,0.25,0.3),Color("dfbc7f"),1))
	shop_ui.add_child(close)
	close.pressed.connect(close_shop)
	preload("res://ui/glass/surface.gd").hover(close)

func _shop_box(bg:Color,border:Color,width:int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=bg
	style.set_corner_radius_all(8)
	style.set_border_width_all(width)
	style.border_color=border
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=12
	style.content_margin_bottom=12
	return style
func open_shop() -> void:
	var toward: Vector3 = Layout.SHOP_NPC-world.player.global_position
	world.player.rig.yaw=atan2(-toward.x,-toward.z)
	world.player.rig.pitch=-0.08
	if shop_npc:shop_npc.talk(world.player.global_position)
	shop_open=true;shop_ui.show();world.ui_open=true;world.player.controls_enabled=false;world.player.rig.controls_enabled=false;world.player.melee.cancel();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func close_shop() -> void:
	if not shop_open:return
	shop_open=false;shop_ui.hide();world.ui_open=false;world.player.controls_enabled=true;world.player.rig.controls_enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _input(event:InputEvent) -> void:
	if dialogue_open and event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				choose_sheriff_option(0);get_viewport().set_input_as_handled();return
			KEY_2:
				choose_sheriff_option(1);get_viewport().set_input_as_handled();return
			KEY_3:
				choose_sheriff_option(2);get_viewport().set_input_as_handled();return
	if dialogue_open and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		advance_sheriff_dialogue();get_viewport().set_input_as_handled();return
	if dialogue_open and event.is_action_pressed("pause"):
		close_sheriff_dialogue();get_viewport().set_input_as_handled();return
	if shop_open and event.is_action_pressed("pause"):close_shop();get_viewport().set_input_as_handled()
func _unhandled_input(event:InputEvent) -> void:
	if not world.started or world.ui_open:return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:request("reload")
			KEY_X:request("drop")
			KEY_T:request("emote:wave")
			KEY_Y:request("emote:dance")
	for n in range(9):
		if event.is_action_pressed("slot_%d"%(n+1)):
			# Stesso tasto della tasca in mano: mani vuote, come in How to Fish.
			if n<world.player.inventory_slots:request("slot:%d"%(-1 if n==world.player.slot else n))
			return
	if event.is_action_pressed("throw"):throw_hold=0.0;return
	if event.is_action_pressed("sell"):press_sell();return
	if event.is_action_pressed("attack"):_use_held();return
	var wheel:int=1 if event.is_action_pressed("weapon_next") else (-1 if event.is_action_pressed("weapon_previous") else 0)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:wheel=1
		elif event.button_index==MOUSE_BUTTON_WHEEL_UP:wheel=-1
	if wheel!=0:_scroll_slot(wheel)
## Rotella: una tasca alla volta, anche quelle vuote; ai bordi si ferma (non fa il giro).
func _scroll_slot(step:int) -> void:
	var a:CharacterBody3D=world.player
	var n:int=clampi(a.slot+step,0,a.inventory_slots-1)
	if n!=a.slot:request("slot:%d"%n)
func viewmodel() -> Node3D:
	if _vm_cache==null or not is_instance_valid(_vm_cache):
		_vm_cache=world.player.rig.camera.get_node_or_null("Viewmodel")
		if _vm_cache and not _vm_cache.released.is_connected(_on_released):_vm_cache.released.connect(_on_released)
	return _vm_cache
## [Q] lancia quello che hai in mano, con la forza accumulata (0..1): la richiesta parte quando la mano si apre (released).
func press_throw(charge:float=1.0) -> void:
	var a:CharacterBody3D=world.player
	if world.ui_open or a.dead or a.seated or a.equipped=="" or a.melee.attacking or a.melee.charging:return
	var vm:=viewmodel()
	if vm and vm.throwing():return
	throw_force=lerpf(THROW_MIN,THROW_MAX,clampf(charge,0.0,1.0))
	if vm==null or not vm.throw_held():request("throw:%s:%f"%[a.equipped,throw_force])
func sell_ready() -> bool:
	if not is_instance_valid(world.player):return false
	var a:CharacterBody3D=world.player
	return world.started and not world.ui_open and ItemInfo.is_head(a.equipped) and a.items.has(a.equipped) and _near_sheriff(a)
## [V] porge la testa allo sceriffo: la vendita parte quando la mano si apre.
func press_sell() -> void:
	if not sell_ready():return
	var vm:=viewmodel()
	if vm and vm.throwing():return
	if vm==null or not vm.give_held():_sold_locally()
func _sold_locally(id:String="") -> void:
	if id=="":id=world.player.equipped
	request("sell:"+id)
	if sell_prompt:sell_prompt.pop(ItemInfo.head_price(id))
	if not sold_once:
		sold_once=true;world.announce(Localization.t("Taglia pagata: +{0}",[ItemInfo.head_price(id)]),2)
	_sheriff_takes_head(id)
func _on_released(kind:String,id:String) -> void:
	if kind=="Throw":request("throw:%s:%f"%[id,throw_force])
	elif kind=="Give":_sold_locally(id)
## La testa consegnata resta un attimo sul banco accanto allo sceriffo, poi sparisce nella cesta.
func _sheriff_takes_head(id:String) -> void:
	if sheriff_node==null:return
	var m:=ItemInfo.model(id)
	if m==null:return
	sheriff_node.add_child(m)
	m.position=Vector3(-0.55,0.75,0.3)
	var tw:=create_tween();tw.tween_property(m,"position:y",0.1,0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6);tw.tween_callback(m.queue_free)
## Tasto sinistro con un oggetto in mano: lo usi (bende, cibo, kit). La cura arriva alla fine della clip.
func _use_held() -> void:
	var a:CharacterBody3D=world.player
	if world.ui_open or not ItemInfo.is_item(a.equipped):return
	var vm:=viewmodel()
	if vm and vm.use_item() and int(ItemInfo.ITEMS[a.equipped].heal)>0:pending_use=a.equipped
func _inventory_tick(delta:float) -> void:
	var vm:=viewmodel()
	if throw_hold>=0.0:
		if world.ui_open or world.player.equipped=="":throw_hold=-1.0
		elif Input.is_action_pressed("throw"):throw_hold+=delta
		else:
			if throw_hold<THROW_TAP:request("drop")
			else:press_throw((throw_hold-THROW_TAP)/THROW_CHARGE)
			throw_hold=-1.0
	if pending_use!="" and vm and not vm.using_item():
		request("useitem:"+pending_use);pending_use=""
	# V tenuta premuta per un secondo: vende tutte le teste una dopo l'altra.
	if sell_ready() and Input.is_action_pressed("sell"):
		sell_hold=minf(1.0,sell_hold+delta)
		if sell_hold>=1.0:sell_auto=true
	else:sell_hold=0.0
	if not sell_ready():sell_auto=false
	if sell_auto and vm and not vm.throwing():press_sell()
	# Host online: gli oggetti in volo ai client, 15 volte al secondo.
	if Session.online and multiplayer.is_server() and not thrown.is_empty():
		thrown_clock-=delta
		var moving:bool=false
		for row in thrown:
			if is_instance_valid(row["node"]) and not row["node"].resting:moving=true
		if moving and thrown_clock<=0.0:
			thrown_clock=0.066
			var rows:=_thrown_rows()
			for peer in Session.connected_peers():thrown_state.rpc_id(peer,rows)
func _process(delta:float) -> void:
	if not world:return
	if world.started:_inventory_tick(delta)
	# Prima volta che ti avvicini allo sceriffo: ti ferma lui.
	if world.started and world.get("quest") and world.quest.stage==0 and not dialogue_open and not shop_open and not world.automated and world.player.position.distance_to(Layout.SHERIFF_NPC)<6.0:
		open_sheriff_dialogue()
	if shop_open:
		var a:CharacterBody3D=world.player
		wallet.text=Localization.t("CREDITI {0}   ·   TESTE {1}",[a.credits,a.carried_heads])
		for weapon in shop_buttons:
			shop_buttons[weapon].disabled = weapon in a.owned or a.credits<PRICES[weapon] or a.owned.size()>=a.inventory_slots
		if shop_slot:
			shop_slot.text=Localization.t("ZAINO  +1 SLOT   ·   {0} CR\n{1} / {2} posti disponibili",[slot_price(),a.inventory_slots,MAX_SLOTS])
			shop_slot.disabled=a.inventory_slots>=MAX_SLOTS or a.credits<slot_price()
		if not _near(world.player,Layout.SHOP_NPC,TRADE_DISTANCE) or not world.started:close_shop()
