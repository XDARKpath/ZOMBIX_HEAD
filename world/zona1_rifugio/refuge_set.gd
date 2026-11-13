extends Node3D
# Zona 1: solo l'ufficio dello sceriffo e l'armeria, affacciati sulla strada.
# Tutto il resto è prato, cespugli e pini: niente paese, niente officina.
const Layout=preload("res://world/zona1_rifugio/refuge_layout.gd")
const Props=preload("res://ui/camp/camp_props.gd")
const CityPack:="res://art/kaykit_city/"
const CityScale:=4.0
const DressingY:=0.02
const SHOP_COUNTER_Z:=2.65
var cache:Dictionary={}
var power_on:bool=false
var entrances:Array[Vector3]=[]

func build() -> void:
	name="RefugeBuildings"
	power_on=true
	_office(Layout.SHERIFF,Layout.YAW_EAST,"sheriff")
	_office(Layout.SHOP,Layout.YAW_WEST,"shop")
	power_on=false
	_greenbelt()
	_outskirts()
	_zone_dressing()

func asset(parent:Node3D,id:String,at:Vector3,yaw:float=0,solid:bool=true,scale_value:Vector3=Vector3.ONE) -> Node3D:
	var block:Node3D=preload("res://art/placeholders.gd").village_block(id,at,yaw,scale_value)
	parent.add_child(block)
	if solid: _collide(block)
	return block

func city(parent:Node3D,id:String,at:Vector3,yaw:float=0,s:float=1.0,solid:bool=false) -> Node3D:
	var key:="city_"+id
	if not cache.has(key): cache[key]=load(CityPack+id+".gltf")
	var node:Node3D=cache[key].instantiate();parent.add_child(node)
	node.position=at;node.rotation.y=yaw;node.scale=Vector3.ONE*CityScale*s
	_weather_city(node)
	if solid: _collide(node)
	return node

func _weather_city(node:Node) -> void:
	# Un solo materiale condiviso: desatura i modelli CC0 e li intona al mondo.
	if node is MeshInstance3D and node.mesh != null:
		var base:StandardMaterial3D=null
		for i in node.mesh.get_surface_count():
			var mat=node.mesh.surface_get_material(i)
			if mat is StandardMaterial3D and mat.albedo_texture != null: base=mat;break
		if base != null:
			var override:=_city_material(base.albedo_texture)
			for i in node.mesh.get_surface_count(): node.set_surface_override_material(i,override)
	for child in node.get_children(): _weather_city(child)

func _city_material(tex:Texture2D) -> ShaderMaterial:
	if cache.has("city_material"): return cache["city_material"]
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://world/zona1_rifugio/city_muted.gdshader")
	mat.set_shader_parameter("albedo_tex",tex)
	cache["city_material"]=mat
	return mat

func _blocker(at:Vector3,width:float,depth:float,yaw:float) -> void:
	var body:=StaticBody3D.new();add_child(body)
	body.position=Vector3(at.x,2.2,at.z);body.rotation.y=yaw
	var shape:=CollisionShape3D.new();var box_shape:=BoxShape3D.new()
	box_shape.size=Vector3(width*0.86,4.4,depth*0.86);shape.shape=box_shape
	body.add_child(shape)

func _collide(node:Node) -> void:
	if node is MeshInstance3D: node.create_trimesh_collision()
	for child in node.get_children():
		if not child is StaticBody3D: _collide(child)

func box(parent:Node3D,at:Vector3,size:Vector3,color:Color,solid:bool=true) -> MeshInstance3D:
	var view:MeshInstance3D=Props.box(parent,at,size,color)
	if solid: view.create_trimesh_collision()
	return view

func rotated(offset:Vector3,yaw:float) -> Vector3:
	return Vector3(offset.x*cos(yaw)+offset.z*sin(yaw),offset.y,-offset.x*sin(yaw)+offset.z*cos(yaw))

func lamp(parent:Node3D,at:Vector3,color:Color=Color("ffd09a"),power:float=2.0,radius:float=8) -> void:
	if not power_on:return
	var light:=OmniLight3D.new();parent.add_child(light);light.position=at
	light.light_color=color;light.light_energy=power;light.omni_range=radius
	light.shadow_enabled=true;light.omni_attenuation=1.35
	_short_fade(light)
	# Lampada appesa: asta e coperchio, così il bulbo non sembra sospeso.
	Props.cylinder(parent,at+Vector3(0,0.30,0),0.014,0.52,Color("3a3a31"))
	Props.box(parent,at+Vector3(0,0.07,0),Vector3(0.34,0.06,0.2),Color("2c2f2a"))
	var bulb:MeshInstance3D=Props.box(parent,at,Vector3(0.3,0.05,0.14),color)
	var material:StandardMaterial3D=bulb.material_override
	material.emission_enabled=true;material.emission=color;material.emission_energy_multiplier=2

func _office(at:Vector3,yaw:float,kind:String) -> void:
	var office:=Node3D.new()
	office.name="SheriffOffice" if kind=="sheriff" else "Armory"
	add_child(office);office.position=at;office.rotation.y=yaw
	# Facciata aperta e attraversabile: si entra dalla strada e si gira attorno
	# al banco. Il retro dello sceriffo è chiuso da una parete cieca.
	_shell(office,kind)
	_porch(office,kind)
	_interior_dressing(office,kind)
	# Davanti ai portici resta il prato: nessuna pavimentazione oltre la strada.
	entrances.append(at+rotated(Vector3(0,0,8.0),yaw))

func _shell(office:Node3D,kind:String) -> void:
	# Guscio creato in Blender (tools/build_refuge_buildings.py): pareti in legno,
	# portico, pensilina e insegna sulla fascia. L'origine è al centro a terra.
	var file:String="sheriff_office" if kind=="sheriff" else "armory"
	var model:Node3D=_load_gltf(file)
	if model==null:
		push_error("Modello mancante: "+file)
		return
	model.name="Building"
	office.add_child(model)
	_shell_collision(office,kind)
	lamp(office,Vector3(0,2.7,7.4),Color("ffd3a2"),2.0,10)
	# Luce di fondo: rende leggibili cella, banchi e scaffali dall'ingresso.
	lamp(office,Vector3(0,2.55,3.35),Color("ffc58d"),1.7,9)

func _load_gltf(file:String) -> Node3D:
	# Lettura diretta del glTF: i modelli Blender restano modificabili e non
	# dipendono dalla cache di import dell'editor.
	var path:String="res://art/buildings/%s.gltf"%file
	var doc:=GLTFDocument.new()
	var state:=GLTFState.new()
	if doc.append_from_file(path,state)!=OK:
		return null
	return doc.generate_scene(state) as Node3D

func _shell_collision(office:Node3D,kind:String) -> void:
	# Muri e pilastri solidi: ingresso davanti libero; il retro è chiuso in
	# entrambi gli edifici, senza passaggi sul bosco.
	_static_box(office,Vector3(-2.7,1.55,1.0),Vector3(3.8,2.9,0.20))
	_static_box(office,Vector3(2.7,1.55,1.0),Vector3(3.8,2.9,0.20))
	_static_box(office,Vector3(0,2.72,1.0),Vector3(1.7,0.35,0.20))
	_static_box(office,Vector3(0,1.45,1.0),Vector3(1.70,2.90,0.20))
	for side in [-1.0,1.0]:
		_static_box(office,Vector3(side*4.6,1.55,4.5),Vector3(0.24,2.9,7.0))
	for x in [-4.4,0.0,4.4]:
		_static_box(office,Vector3(x,1.55,9.55),Vector3(0.24,2.9,0.24))
	if kind=="sheriff":
		# La cella è solida: le sbarre non si attraversano.
		_static_box(office,Vector3(-2.95,1.45,3.35),Vector3(2.90,2.65,0.12))
		_static_box(office,Vector3(-1.55,1.45,2.25),Vector3(0.12,2.65,2.25))

func _static_box(parent:Node3D,at:Vector3,size:Vector3) -> void:
	var body:=StaticBody3D.new();parent.add_child(body);body.position=at
	var shape:=CollisionShape3D.new();var box_shape:=BoxShape3D.new()
	box_shape.size=size;shape.shape=box_shape;body.add_child(shape)

func _porch(office:Node3D,kind:String) -> void:
	if kind=="sheriff":
		_sheriff_desk(office)
	else:
		pass # bancone, pegboard e merce arrivano dal kit ambiente (zone1_kit.gd)

const DESK_SHIFT:=-2.55        # scrivania arretrata: lo sceriffo siede tra lei e la parete
const CREDENZA_SHIFT:=-3.17     # credenza appoggiata alla parete di fondo

func _desk_node(office:Node3D,node_name:String,shift:float) -> Node3D:
	var node:=office.get_node_or_null(node_name) as Node3D
	if node: return node
	node=Node3D.new();node.name=node_name;office.add_child(node);node.position.z=shift
	return node

func _sheriff_desk(office:Node3D) -> void:
	# Scrivania vera: piano, cassetti, credenza alle spalle e oggetti da ufficio.
	var room:=office
	var credenza:=_desk_node(room,"Credenza",CREDENZA_SHIFT)
	office=_desk_node(room,"Desk",DESK_SHIFT)
	var wood:=Color("5a4a34")
	var dark:=Color("3b3024")
	var edge:=Color("8a6a45")
	var brass:=Color("c9a468")
	var paper:=Color("cfc3a1")
	# Piano e pannelli sono solidi ma non nascondono lo sceriffo al prompt "parla".
	shop_solid(office,Vector3(1.15,0.60,5.55),Vector3(2.50,0.10,0.90),wood)
	shop_solid(office,Vector3(1.15,0.34,5.98),Vector3(2.36,0.48,0.07),dark)
	for x in [0.06,2.24]:
		shop_solid(office,Vector3(x,0.28,5.55),Vector3(0.10,0.52,0.78),dark)
	for z in [5.20,5.90]:
		box(office,Vector3(0.10,0.24,z),Vector3(0.10,0.42,0.10),wood)
		box(office,Vector3(2.20,0.24,z),Vector3(0.10,0.42,0.10),wood)
	for i in range(3):
		var dx:=0.55+i*0.55
		box(office,Vector3(dx,0.35,6.02),Vector3(0.44,0.16,0.035),edge,false)
		box(office,Vector3(dx,0.35,6.04),Vector3(0.09,0.025,0.02),brass,false)
	# credenza contro la parete, alle spalle della sedia
	box(credenza,Vector3(1.15,0.67,4.52),Vector3(1.95,1.16,0.40),dark)
	box(credenza,Vector3(1.15,1.27,4.52),Vector3(2.05,0.07,0.46),wood)
	box(credenza,Vector3(1.15,0.82,4.73),Vector3(1.80,0.05,0.05),edge,false)
	for i in range(3):
		box(credenza,Vector3(0.62+i*0.53,0.62,4.74),Vector3(0.46,0.38,0.035),wood,false)
		box(credenza,Vector3(0.62+i*0.53,0.62,4.76),Vector3(0.07,0.025,0.02),brass,false)
	box(credenza,Vector3(0.85,1.34,4.52),Vector3(0.38,0.10,0.28),paper,false)
	box(credenza,Vector3(1.50,1.34,4.52),Vector3(0.30,0.10,0.24),Color("8c3f34"),false)
	# piano: registro, carta, calamaio, lampada
	box(office,Vector3(1.08,0.665,5.36),Vector3(0.52,0.025,0.34),dark,false)
	box(office,Vector3(1.08,0.680,5.36),Vector3(0.46,0.012,0.29),paper,false)
	box(office,Vector3(1.08,0.692,5.36),Vector3(0.30,0.006,0.20),Color("6e5a41"),false)
	box(office,Vector3(1.55,0.675,5.70),Vector3(0.28,0.012,0.20),paper,false)
	Props.cylinder(office,Vector3(1.78,0.70,5.30),0.045,0.08,Color("2b2e2c"),0.4)
	Props.cylinder(office,Vector3(1.95,0.78,5.30),0.025,0.20,brass,0.6)
	box(office,Vector3(1.95,0.90,5.30),Vector3(0.28,0.05,0.18),Color("6a3f2c"),false)
	store_star(office,Vector3(1.52,0.70,5.52),0.10,brass)
	office=room
	# bossolo caduto a terra, non un oggetto sospeso
	box(office,Vector3(-3.82,0.075,6.42),Vector3(0.12,0.025,0.06),brass,false)
	# sacchi di sabbia lungo la parete
	for i in range(4):
		box(office,Vector3(-3.6+(i%2)*0.44,0.12+i/2*0.22,5.2),Vector3(0.44,0.2,0.32),Color("6d6446"),false).rotation.y=i*0.25

func store_star(parent:Node3D,at:Vector3,radius:float,color:Color) -> MeshInstance3D:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(5):
		var outer_angle:float=-PI/2+i*TAU/5
		var next_angle:float=-PI/2+(i+1)*TAU/5
		var outer:=Vector3(cos(outer_angle)*radius,sin(outer_angle)*radius,0)
		var next:=Vector3(cos(next_angle)*radius,sin(next_angle)*radius,0)
		var inner:=Vector3(cos((outer_angle+next_angle)*0.5)*radius*0.42,sin((outer_angle+next_angle)*0.5)*radius*0.42,0)
		st.add_vertex(Vector3.ZERO);st.add_vertex(outer);st.add_vertex(inner)
		st.add_vertex(Vector3.ZERO);st.add_vertex(inner);st.add_vertex(next)
	st.generate_normals()
	var view:=MeshInstance3D.new();view.mesh=st.commit();view.position=at;parent.add_child(view)
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.metallic=0.85;mat.roughness=0.3
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	view.material_override=mat
	return view

func shop_solid(office:Node3D,at:Vector3,size:Vector3,color:Color) -> MeshInstance3D:
	# I corpi del banco possono intercettare il raggio verso l'armaiolo:
	# vanno marcati, altrimenti il prompt "parla" sparisce attraverso il legno.
	var view:=box(office,at,size,color,true)
	for child in view.get_children():
		if child is StaticBody3D: child.set_meta("shop_fixture",true)
	return view

func _shop_stall(office:Node3D) -> void:
	# Banco del negozio contro la parete di fondo: l'armaiolo sta tra il muro
	# e il piano, così dall'ingresso si vede tutto il negozio.
	var cx:float=-1.90
	var cz:float=SHOP_COUNTER_Z
	var wood:=Color("5b4b34")
	var dark:=Color("3a3024")
	var brass:=Color("c9a468")
	var paper:=Color("cfc3a1")
	shop_solid(office,Vector3(cx,0.82,cz),Vector3(2.75,0.10,0.95),wood)
	shop_solid(office,Vector3(cx,0.43,cz+0.44),Vector3(2.58,0.64,0.06),dark)
	for x in [cx-1.32,cx+1.32]:
		shop_solid(office,Vector3(x,0.43,cz),Vector3(0.10,0.64,0.86),dark)
	for z in [cz-0.32,cz+0.34]:
		shop_solid(office,Vector3(cx-1.28,0.24,z),Vector3(0.08,0.42,0.08),wood)
		shop_solid(office,Vector3(cx+1.28,0.24,z),Vector3(0.08,0.42,0.08),wood)
	for i in range(3):
		var px:=cx-0.78+i*0.78
		box(office,Vector3(px,0.44,cz+0.47),Vector3(0.62,0.44,0.035),wood,false)
		box(office,Vector3(px,0.54,cz+0.49),Vector3(0.12,0.025,0.02),brass,false)
	box(office,Vector3(cx,0.16,cz+0.49),Vector3(2.45,0.06,0.06),brass,false)
	# cassa, registro, munizioni
	box(office,Vector3(cx+1.18,0.96,cz-0.20),Vector3(0.28,0.18,0.22),Color("2f3430"),false)
	box(office,Vector3(cx+1.18,1.06,cz-0.20),Vector3(0.10,0.03,0.02),brass,false)
	box(office,Vector3(cx-0.88,0.895,cz),Vector3(0.42,0.02,0.28),paper,false)
	box(office,Vector3(cx-0.88,0.91,cz),Vector3(0.34,0.01,0.20),Color("756045"),false)
	# L'insegna è sulla fascia della pensilina, nel modello Blender.

func _shop_stock_shelf(office:Node3D) -> void:
	# Scaffale carico sulla parete destra: riempie il lato vuoto del negozio.
	var wood:=Color("5b4a33")
	var dark:=Color("3b3024")
	var shelf_x:float=4.08
	var z0:float=2.05
	var z1:float=4.05
	var mid:float=(z0+z1)*0.5
	shop_solid(office,Vector3(4.40,1.04,mid),Vector3(0.06,2.08,z1-z0),Color("352b20"))
	shop_solid(office,Vector3(shelf_x,1.04,z0),Vector3(0.58,2.08,0.06),wood)
	shop_solid(office,Vector3(shelf_x,1.04,z1),Vector3(0.58,2.08,0.06),wood)
	for sy in [0.36,0.96,1.56]:
		shop_solid(office,Vector3(shelf_x,sy,mid),Vector3(0.54,0.05,z1-z0-0.12),wood)
	shop_solid(office,Vector3(shelf_x,2.06,mid),Vector3(0.54,0.05,z1-z0-0.12),dark)
	# Merce allineata ma non identica: barattoli, scatole, munizioni.
	for row in range(3):
		var base:float=0.385+row*0.60
		for i in range(5):
			var gz:float=z0+0.28+i*0.36
			match (i+row)%3:
				0:
					Props.cylinder(office,Vector3(3.96,base+0.085,gz),0.050,0.17,Color("8e4434") if i%2==0 else Color("6d7d58"),0.55)
					Props.cylinder(office,Vector3(3.96,base+0.180,gz),0.052,0.02,Color("b9a77e"),0.40)
				1:
					box(office,Vector3(3.96,base+0.11,gz),Vector3(0.18,0.22,0.20),Color("b7a47d") if i%2==0 else Color("8b7a58"),false)
					box(office,Vector3(3.96,base+0.225,gz),Vector3(0.10,0.02,0.16),Color("5a4632"),false)
				_:
					box(office,Vector3(3.96,base+0.075,gz),Vector3(0.22,0.15,0.16),Color("4a513f"),false)
					box(office,Vector3(3.96,base+0.155,gz),Vector3(0.16,0.02,0.10),Color("c0a269"),false)
	# Cassa sul pavimento accanto allo scaffale: solida.
	shop_solid(office,Vector3(3.60,0.24,4.66),Vector3(0.62,0.48,0.52),Color("5d4a33"))
	box(office,Vector3(3.60,0.49,4.66),Vector3(0.66,0.03,0.56),Color("6d583c"),false)

func _shop_price_board(office:Node3D) -> void:
	# Bacheca a icone, senza testo: il villaggio non usa cartelli scritti.
	var at:=Vector3(-0.55,2.06,1.23)
	box(office,at,Vector3(1.62,0.64,0.05),Color("2f2a21"),false)
	box(office,at+Vector3(0,0,0.03),Vector3(1.50,0.52,0.014),Color("5b4a35"),false)
	var metal:=Color("d9cba6")
	# Pistola: carrello, canna e impugnatura.
	box(office,Vector3(-0.98,2.15,1.26),Vector3(0.34,0.07,0.02),metal,false)
	box(office,Vector3(-1.18,2.07,1.26),Vector3(0.10,0.17,0.02),metal,false)
	box(office,Vector3(-0.86,2.08,1.26),Vector3(0.06,0.09,0.02),metal,false)
	# Coltello: lama e manico.
	box(office,Vector3(-0.10,2.17,1.26),Vector3(0.30,0.06,0.02),metal,false)
	box(office,Vector3(0.15,2.14,1.26),Vector3(0.12,0.09,0.025),Color("8a6a45"),false)
	# Tacche di prezzo: barrette di ottone.
	for i in range(5):
		box(office,Vector3(-1.02+i*0.045,1.95,1.26),Vector3(0.026,0.10,0.02),Color("c2a269"),false)
	for i in range(2):
		box(office,Vector3(-0.10+i*0.07,1.95,1.26),Vector3(0.035,0.10,0.02),Color("c2a269"),false)

func _shop_rug(office:Node3D) -> void:
	var at:=Vector3(-1.90,0,4.45)
	box(office,at+Vector3(0,0.030,0),Vector3(2.95,0.012,1.95),Color("4d302b"),false)
	box(office,at+Vector3(0,0.037,0),Vector3(2.65,0.012,1.65),Color("674039"),false)
	for side in [-1.0,1.0]:
		box(office,at+Vector3(side*1.22,0.034,0),Vector3(0.05,0.012,1.82),Color("a98d5e"),false)
		box(office,at+Vector3(0,0.034,side*0.82),Vector3(2.82,0.012,0.05),Color("a98d5e"),false)

func _shop_counter_goods(office:Node3D) -> void:
	var cx:float=-1.90
	var cz:float=SHOP_COUNTER_Z
	box(office,Vector3(cx-0.78,0.945,cz+0.02),Vector3(0.42,0.15,0.34),Color("6a4a30"),false)
	for i in range(3):
		Props.cylinder(office,Vector3(cx-0.90+i*0.12,1.06,cz+0.02),0.045,0.15,Color("8e4434") if i%2==0 else Color("72805c"),0.55)
	Props.cylinder(office,Vector3(cx+0.56,0.99,cz+0.06),0.036,0.24,Color("3f5a42"),0.32)
	Props.cylinder(office,Vector3(cx+0.56,1.13,cz+0.06),0.018,0.06,Color("3a2b1c"),0.40)
	Props.cylinder(office,Vector3(cx+0.36,0.935,cz+0.12),0.040,0.13,Color("8a7a5e"),0.50)

func _zone_dressing() -> void:
	# Arredi CC0 dei pacchetti KayKit e Kenney: nessun edificio nuovo, solo
	# dettagli fuori dai portici, dai percorsi e dai raggi delle esche.
	var dressing:=Node3D.new()
	dressing.name="ZoneDressing"
	add_child(dressing)
	# Idranti ai lati della strada: uno per lato.
	city(dressing,"firehydrant",Vector3(9.95,DressingY,-14.30),0.3,1.0,true)
	city(dressing,"firehydrant",Vector3(2.05,DressingY,-14.30),-0.4,1.0,true)
	_streetlight(dressing,Vector3(10.75,DressingY,-1.60),0.0)

func _bench(parent:Node3D,at:Vector3,yaw:float) -> void:
	city(parent,"bench",at,yaw,1.0,true)

func _streetlight(parent:Node3D,at:Vector3,yaw:float) -> void:
	city(parent,"streetlight",at,yaw,1.0,true)
	# La lanterna del modello sporge di 0,96 m: la luce sta sotto la testa,
	# non sopra il palo, così la strada si legge anche in ombra.
	var head:=at+rotated(Vector3(-0.92,3.52,0),yaw)
	var light:=OmniLight3D.new();parent.add_child(light);light.position=head
	light.light_color=Color("ffc68f");light.light_energy=1.10;light.omni_range=9.5
	light.omni_attenuation=1.35

func _greenbelt() -> void:
	# Prato alberato tra e dietro i due edifici: la zona è un bosco, non un paese.
	var rng:=RandomNumberGenerator.new();rng.seed=5150
	for i in range(70):
		var at:=Vector3(rng.randf_range(-115,120),0,rng.randf_range(-215,-2))
		if Layout.occupied(at.x,at.z) or Layout.safe(at):continue
		if absf(at.x-Layout.ROAD_X)<9.5:continue
		if preload("res://world/zona1_rifugio/roadnet.gd").distance(Vector2(at.x,at.z))<8.0:continue
		if preload("res://world/zona1_rifugio/roadnet.gd").arena_distance(Vector2(at.x,at.z))<16.0:continue
		var tree:Node3D=load("res://art/nature/Pine_%d.gltf"%rng.randi_range(1,5)).instantiate()
		add_child(tree);tree.position=Vector3(at.x,preload("res://world/campaign/terrain.gd").ground_height(at.x,at.z),at.z)
		tree.rotation.y=rng.randf_range(0,TAU);tree.scale=Vector3.ONE*rng.randf_range(1.1,2.2)
		_mute_nature(tree)
		if i%6==0:_collide(tree)

func _outskirts() -> void:
	# Stesso bosco della mappa: pini fitti fino ai margini della radura.
	var rng:=RandomNumberGenerator.new();rng.seed=14014
	var trees:=["Pine_1","Pine_3","Pine_2","Pine_5"]
	for i in range(240):
		var at:=Vector3(rng.randf_range(-160,170),0,rng.randf_range(-280,-6))
		if Layout.occupied(at.x,at.z) or Layout.safe(at):continue
		var corridor:float=11.0 if at.z>-70 else 7.0
		if absf(at.x-Layout.ROAD_X)<corridor:continue
		if preload("res://world/zona1_rifugio/roadnet.gd").distance(Vector2(at.x,at.z))<8.5:continue
		if preload("res://world/zona1_rifugio/roadnet.gd").arena_distance(Vector2(at.x,at.z))<16.0:continue
		var tree:Node3D=load("res://art/nature/"+trees[i%trees.size()]+".gltf").instantiate()
		add_child(tree);at.y=preload("res://world/campaign/terrain.gd").ground_height(at.x,at.z);tree.position=at
		tree.rotation.y=rng.randf_range(0,TAU);tree.scale=Vector3.ONE*rng.randf_range(0.9,1.9)
		_mute_nature(tree)
		if i%10==0:_collide(tree)

func _mute_nature(node:Node) -> void:
	# Verde pieno: niente toni autunnali rossi o marroni.
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat=node.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				var copy:StandardMaterial3D=mat.duplicate()
				copy.albedo_color=copy.albedo_color.lerp(Color(0.20,0.36,0.17),0.80)
				node.set_surface_override_material(i,copy)
	for child in node.get_children(): _mute_nature(child)

func _mute_forest(node:Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat:StandardMaterial3D=node.mesh.surface_get_material(i).duplicate()
			mat.albedo_color=Color(0.34,0.48,0.26);node.set_surface_override_material(i,mat)
	for child in node.get_children():_mute_forest(child)

# ---------------------------------------------------------------- interni 0.20
# Dettagli costruiti a moduli rigidi: nessuna curva, nessuna texture nuova.
func _interior_dressing(office:Node3D,kind:String) -> void:
	if kind=="shop":
		_shop_walls(office)
		_window_shaft(office,1.0,6.2,Vector3(3.0,0.12,5.55),true,false)
	else:
		_sheriff_cell_stone(office)
		_sheriff_walls(office)
		_window_shaft(office,-1.0,3.7,Vector3(-3.05,0.12,4.80),true)
		_cell_window(office)

func _wall_group(parent:Node3D,at:Vector3,yaw:float) -> Node3D:
	var group:=Node3D.new();parent.add_child(group)
	group.position=at;group.rotation.y=yaw
	return group

func _shop_walls(office:Node3D) -> void:
	var wood:=Color("5b4b34")
	var dark:=Color("2f2b22")
	var iron:=Color("2b302d")
	# Travi e montanti pesanti, con piastre metalliche ai piedi e alla testa.
	for side in [-1.0,1.0]:
		box(office,Vector3(side*4.12,1.47,7.05),Vector3(0.20,2.86,0.20),wood,true)
		box(office,Vector3(side*4.12,0.25,7.05),Vector3(0.30,0.14,0.30),iron,false)
		box(office,Vector3(side*4.12,2.66,7.05),Vector3(0.30,0.14,0.30),iron,false)
	box(office,Vector3(0,2.74,5.15),Vector3(8.55,0.16,0.18),dark,false)
	for x in [-3.8,3.8]:
		box(office,Vector3(x,2.60,5.15),Vector3(0.16,0.30,0.24),iron,false)
	# Bancone, pegboard e banco da armaiolo: kit ambiente (world/zona1_rifugio/zone1_kit.gd).
	# Parete destra: le armi v2 appese (kit) sotto una lama di neon caldo.
	var right:=_wall_group(office,Vector3(4.39,0,0),-PI/2)
	_glow_box(right,Vector3(6.05,2.62,0.12),Vector3(1.35,0.035,0.035),Color("e3a15e"),1.6)
	# Parete sinistra: spade del kit sopra la vetrina e casse di munizioni impilate.
	_ammo_stack(office,Vector3(3.82,0,7.0),0.0)
	_ammo_stack(office,Vector3(-3.62,0,7.0),0.0)
	_shop_stock_shelf(office)
	_shop_rug(office)
	# La stufa del modello nel angolo di fondo è un volume vero.
	_static_box(office,Vector3(3.42,0.55,2.28),Vector3(0.74,1.12,0.74))

func _shop_counter_armor(office:Node3D) -> void:
	# Il banco resta lo stesso volume solido, ma guadagna un piano più spesso,
	# fasce in ferro e bulloni: deve sembrare un arredo da fortezza.
	var cz:=SHOP_COUNTER_Z
	var dark:=Color("292e2a")
	var brass:=Color("b99a63")
	box(office,Vector3(-1.90,0.91,cz),Vector3(2.94,0.05,1.05),Color("69553d"),false)
	# Fronte corazzato a doghe, non una parete liscia.
	box(office,Vector3(-1.90,0.34,cz+0.415),Vector3(2.38,0.46,0.10),Color("403526"),false)
	for i in range(5):
		box(office,Vector3(-2.86+i*0.48,0.34,cz+0.47),Vector3(0.43,0.40,0.035),Color("5c4a34"),false)
	store_star(office,Vector3(-1.90,0.55,cz+0.495),0.12,brass)
	box(office,Vector3(-1.90,0.56,cz+0.455),Vector3(2.54,0.09,0.06),dark,false)
	box(office,Vector3(-1.90,0.18,cz+0.455),Vector3(2.40,0.05,0.05),dark,false)
	for side in [-1.0,1.0]:
		box(office,Vector3(-1.90+side*1.30,0.37,cz+0.46),Vector3(0.11,0.52,0.07),dark,false)
	for x in [-3.08,-2.33,-1.58,-0.83]:
		var bolt=Props.cylinder(office,Vector3(x,0.56,cz+0.495),0.026,0.018,brass,0.55)
		bolt.rotation.x=PI/2
	_glow_box(office,Vector3(-1.90,0.22,cz+0.48),Vector3(1.75,0.025,0.025),Color("d79a58"),1.2)

func _tool_board(wall:Node3D,at:Vector3,width:float,height:float) -> void:
	box(wall,at+Vector3(0,0,0.03),Vector3(width,height,0.06),Color("2f2b22"),false)
	box(wall,at+Vector3(0,-height*0.42,0.065),Vector3(width*0.92,0.05,0.05),Color("5a4a34"),false)
	for i in range(3):
		var bx:float=at.x-width*0.32+i*width*0.31
		box(wall,Vector3(bx,at.y+0.08,0.09),Vector3(0.045,height*0.52,0.035),Color("8a7351"),false)
		box(wall,Vector3(bx,at.y+0.30,0.10),Vector3(0.18,0.06,0.04),Color("b6bdb4"),false)
		box(wall,Vector3(bx,at.y-0.25,0.10),Vector3(0.13,0.055,0.04),Color("3c403a"),false)
	for i in range(2):
		box(wall,Vector3(at.x-width*0.22+i*width*0.42,at.y-height*0.30,0.11),Vector3(0.22,0.18,0.10),Color("6a5c43"),false)

func _weapon_rack(wall:Node3D,at_x:float,at_y:float,width:float) -> void:
	box(wall,Vector3(at_x,at_y,0.04),Vector3(width,1.05,0.07),Color("39332a"),false)
	box(wall,Vector3(at_x,at_y-0.56,0.07),Vector3(width*0.94,0.06,0.08),Color("6f5b40"),false)
	for i in range(3):
		var bx:float=at_x-width*0.33+i*width*0.33
		box(wall,Vector3(bx,at_y+0.03,0.10),Vector3(0.045,0.86,0.045),Color("b8c0b8"),false)
		box(wall,Vector3(bx,at_y-0.26,0.12),Vector3(0.13,0.26,0.08),Color("6d4d35"),false)
		box(wall,Vector3(bx,at_y+0.38,0.12),Vector3(0.07,0.18,0.05),Color("323a35"),false)
		box(wall,Vector3(bx,at_y+0.12,0.13),Vector3(0.16,0.035,0.035),Color("c2a56b"),false)
		box(wall,Vector3(bx,at_y-0.48,0.07),Vector3(0.07,0.07,0.06),Color("2a2f2b"),false)

func _vest(wall:Node3D,at:Vector3,color:Color) -> void:
	# Giubbotto tattico geometrico: piastra, spallacci, tasche e gancio.
	box(wall,at+Vector3(0,0.38,0.06),Vector3(0.46,0.045,0.045),Color("2a2f2b"),false)
	box(wall,at+Vector3(0,0,0.10),Vector3(0.54,0.64,0.12),Color("2b312c"),false)
	box(wall,at+Vector3(0,0.07,0.17),Vector3(0.43,0.36,0.08),color,false)
	for side in [-1.0,1.0]:
		box(wall,at+Vector3(side*0.25,0.20,0.14),Vector3(0.08,0.34,0.08),color,false)
		box(wall,at+Vector3(side*0.15,-0.17,0.20),Vector3(0.15,0.20,0.10),color.darkened(0.16),false)
		box(wall,at+Vector3(side*0.24,-0.07,0.20),Vector3(0.06,0.05,0.05),Color("ba9b62"),false)
	box(wall,at+Vector3(0,-0.04,0.23),Vector3(0.10,0.16,0.04),color.darkened(0.25),false)
	box(wall,at+Vector3(0,0.42,0.05),Vector3(0.16,0.06,0.05),Color("b89c68"),false)

func _ammo_stack(parent:Node3D,at:Vector3,yaw:float) -> void:
	var group:=Node3D.new();parent.add_child(group);group.position=at;group.rotation.y=yaw
	for level in range(2):
		var y:=0.21+level*0.42
		shop_solid(group,Vector3(0,y,0),Vector3(0.54,0.40,0.42),Color("5a4d37"))
		box(group,Vector3(0,y+0.21,0),Vector3(0.58,0.05,0.46),Color("706046"),false)
		for i in range(3):
			box(group,Vector3(-0.18+i*0.18,y,0.22),Vector3(0.05,0.32,0.025),Color("2b302b"),false)
		box(group,Vector3(0,y+0.03,0.225),Vector3(0.26,0.035,0.025),Color("c0a267"),false)

func _sheriff_walls(office:Node3D) -> void:
	var wood:=Color("624e36")
	var iron:=Color("2b302d")
	var paper:=Color("c7baa0")
	# Piano rinforzato e angoli in ferro: la scrivania deve sembrare pesante.
	var desk:=_desk_node(office,"Desk",DESK_SHIFT)
	box(desk,Vector3(1.15,0.675,5.55),Vector3(2.64,0.06,1.00),Color("69523a"),false)
	for x in [0.02,2.28]:
		for z in [5.17,5.94]:
			box(desk,Vector3(x,0.45,z),Vector3(0.10,0.40,0.08),iron,false)
			for y in [0.30,0.60]:
				var bolt=Props.cylinder(desk,Vector3(x,y,z+0.045),0.024,0.018,Color("c2a269"),0.5)
				bolt.rotation.x=PI/2
	_radio(desk)
	# Carte, mappa e timbro sul piano.
	box(desk,Vector3(1.48,0.69,5.37),Vector3(0.44,0.018,0.30),paper,false)
	box(desk,Vector3(1.48,0.705,5.37),Vector3(0.36,0.008,0.23),Color("8a795a"),false)
	box(desk,Vector3(1.76,0.69,5.73),Vector3(0.22,0.035,0.27),Color("b8aa8d"),false)
	Props.cylinder(desk,Vector3(1.68,0.73,5.80),0.025,0.05,Color("4c4538"),0.2)
	# Classificatori in ferro e legno contro la parete sinistra.
	_filing_cabinet(office,Vector3(-4.12,0,4.10),PI/2)
	_filing_cabinet(office,Vector3(-4.12,0,4.92),PI/2)
	# Manifesti ricercati sulla parete destra, oltre la finestra.
	var right:=_wall_group(office,Vector3(4.40,0,0),-PI/2)
	_wanted_poster(right,Vector3(5.05,1.62,0.05),0.48,0.62)
	_wanted_poster(right,Vector3(5.66,1.50,0.05),0.42,0.55)
	# Anche la parete sinistra, quella che si vede entrando, porta i suoi bandi.
	var left:=_wall_group(office,Vector3(-4.40,0,0),PI/2)
	_wanted_poster(left,Vector3(-5.30,1.62,0.05),0.46,0.60)
	_wanted_poster(left,Vector3(-5.90,1.50,0.05),0.40,0.52)
	box(office,Vector3(3.92,0.05,5.4),Vector3(0.35,0.04,0.55),Color("594c38"),false)
	_sheriff_gun_rack(office)
	_sheriff_stove(office)
	_sheriff_rug(office)

func _sheriff_gun_rack(office:Node3D) -> void:
	# Rastrelliera sulla parete destra: due fucili veri, non tre stecche.
	var right:=_wall_group(office,Vector3(4.40,0,0),-PI/2)
	var wood:=Color("624e36")
	var dark:=Color("2e2a22")
	var steel:=Color("8b938b")
	var brass:=Color("c2a269")
	var cx:float=7.05
	box(right,Vector3(cx,1.45,0.04),Vector3(1.92,1.22,0.06),dark,false)
	box(right,Vector3(cx,0.80,0.12),Vector3(1.96,0.07,0.28),wood,true)
	for side in [-1.0,1.0]:
		box(right,Vector3(cx+side*0.94,1.45,0.10),Vector3(0.08,1.22,0.10),wood,false)
	for i in range(2):
		var rx:float=cx-0.43+i*0.86
		box(right,Vector3(rx,1.52,0.14),Vector3(0.055,1.04,0.055),steel,false)
		box(right,Vector3(rx,1.05,0.14),Vector3(0.10,0.30,0.09),wood,false)
		box(right,Vector3(rx,1.14,0.10),Vector3(0.13,0.10,0.10),dark,false)
		box(right,Vector3(rx,1.96,0.14),Vector3(0.035,0.14,0.035),steel,false)
		box(right,Vector3(rx,1.60,0.17),Vector3(0.09,0.035,0.03),brass,false)
		Props.cylinder(right,Vector3(rx+0.06,1.78,0.17),0.030,0.14,dark,0.45)
		box(right,Vector3(rx+0.09,1.32,0.17),Vector3(0.03,0.46,0.02),Color("4a3526"),false)

func _sheriff_stove(office:Node3D) -> void:
	# Stufa a legna nel angolo di fondo: calore, luce e volume solido.
	var iron:=Color("2f322d")
	var dark:=Color("1c1e1b")
	var at:=Vector3(3.42,0,2.28)
	Props.cylinder(office,at+Vector3(0,0.08,0),0.37,0.16,iron,0.75)
	Props.cylinder(office,at+Vector3(0,0.55,0),0.30,0.90,iron,0.75)
	Props.cylinder(office,at+Vector3(0,1.02,0),0.33,0.06,dark,0.60)
	box(office,at+Vector3(0,0.56,0.31),Vector3(0.28,0.30,0.04),dark,false)
	_glow_box(office,at+Vector3(0,0.53,0.335),Vector3(0.16,0.16,0.012),Color("e07a3e"),1.8)
	box(office,at+Vector3(0.20,0.55,0.335),Vector3(0.12,0.025,0.025),Color("8d744c"),false)
	Props.cylinder(office,at+Vector3(0,1.80,0),0.075,1.56,dark,0.60)
	Props.cylinder(office,at+Vector3(0,2.55,0),0.11,0.07,iron,0.50)
	_static_box(office,at+Vector3(0,0.55,0),Vector3(0.74,1.12,0.74))
	var fire:=OmniLight3D.new();office.add_child(fire)
	fire.position=at+Vector3(0,0.62,0.48)
	fire.light_color=Color("ff9757");fire.light_energy=0.9;fire.omni_range=4.2
	fire.omni_attenuation=1.5

func _sheriff_rug(office:Node3D) -> void:
	var at:=Vector3(1.15,0,7.05)
	box(office,at+Vector3(0,0.030,0),Vector3(3.15,0.012,2.05),Color("4c312b"),false)
	box(office,at+Vector3(0,0.037,0),Vector3(2.85,0.012,1.75),Color("5f3d34"),false)
	for side in [-1.0,1.0]:
		box(office,at+Vector3(side*1.32,0.034,0),Vector3(0.05,0.012,1.92),Color("a78b5d"),false)
		box(office,at+Vector3(0,0.034,side*0.88),Vector3(3.02,0.012,0.05),Color("a78b5d"),false)

func _radio(office:Node3D) -> void:
	var body:=Color("343b35")
	var brass:=Color("c2a269")
	box(office,Vector3(0.57,0.75,5.53),Vector3(0.36,0.15,0.23),body,false)
	box(office,Vector3(0.57,0.84,5.53),Vector3(0.27,0.04,0.18),Color("1d2422"),false)
	for i in range(2):
		var knob=Props.cylinder(office,Vector3(0.45+i*0.24,0.735,5.655),0.028,0.026,brass,0.45)
		knob.rotation.x=PI/2
	for i in range(3):
		box(office,Vector3(0.50+i*0.07,0.76,5.655),Vector3(0.025,0.08,0.015),Color("788078"),false)
	Props.rod(office,Vector3(0.40,0.84,5.52),Vector3(0.27,1.18,5.48),0.009,Color("8e948c"))
	_glow_box(office,Vector3(0.61,0.80,5.66),Vector3(0.035,0.025,0.012),Color("e46a47"),1.8)

func _filing_cabinet(parent:Node3D,at:Vector3,yaw:float) -> void:
	var group:=Node3D.new();parent.add_child(group);group.position=at;group.rotation.y=yaw
	box(group,Vector3(0,0.67,0),Vector3(0.82,1.28,0.44),Color("42473f"))
	box(group,Vector3(0,1.33,0),Vector3(0.88,0.06,0.50),Color("5b5b4c"))
	for i in range(3):
		var y:=0.97-i*0.32
		box(group,Vector3(0,y,0.235),Vector3(0.70,0.27,0.035),Color("555b50"),false)
		box(group,Vector3(0,y,0.258),Vector3(0.19,0.025,0.02),Color("be9f66"),false)
		box(group,Vector3(0,y-0.07,0.258),Vector3(0.31,0.012,0.01),Color("b8ae91"),false)
	for side in [-1.0,1.0]:
		box(group,Vector3(side*0.34,0.05,0.13),Vector3(0.07,0.10,0.34),Color("292e2a"),false)

func _wanted_poster(wall:Node3D,at:Vector3,w:float,h:float) -> void:
	var paper:=Color("c6b995")
	var ink:=Color("4d4132")
	box(wall,at+Vector3(0,0,0.012),Vector3(w+0.06,h+0.06,0.022),Color("302a20"),false)
	box(wall,at+Vector3(0,0,0.030),Vector3(w,h,0.014),paper,false)
	var head=Props.cylinder(wall,at+Vector3(0,h*0.16,0.045),w*0.15,0.012,ink,0.0)
	head.rotation.x=PI/2
	box(wall,at+Vector3(0,h*0.02,0.045),Vector3(w*0.34,h*0.26,0.012),Color("5c4b38"),false)
	box(wall,at+Vector3(0,-h*0.22,0.045),Vector3(w*0.55,h*0.06,0.012),paper,false)
	box(wall,at+Vector3(0,-h*0.32,0.046),Vector3(w*0.44,h*0.025,0.010),Color("7d6c52"),false)
	for corner in [Vector3(-w*0.5,h*0.5,0.05),Vector3(w*0.5,h*0.5,0.05)]:
		Props.cylinder(wall,at+corner,0.018,0.012,Color("b89b65"),0.4)

func _sheriff_cell_stone(office:Node3D) -> void:
	# La cella è già nell'angolo posteriore; qui la incastro in una spessa
	# muratura a blocchi, con soglia, architrave e pilastri.
	var stone:=Color("756c5b")
	var stone_dark:=Color("4e483c")
	var stone_light:=Color("8c826c")
	var iron:=Color("292e2b")
	var rng:=RandomNumberGenerator.new();rng.seed=3301
	# Malta scura dietro i conci: i giunti devono leggersi, non sparire.
	box(office,Vector3(-2.95,1.42,1.155),Vector3(3.08,2.76,0.035),Color("3b3830"),false)
	for row in range(7):
		var y:=0.25+row*0.38
		var x:=-4.30
		while x<-1.55:
			var w:=0.42+rng.randf_range(0.0,0.22)
			if x+w>-1.55:w=-1.55-x
			if w>0.10:
				var c:=stone if (row+int(absf(x)*10.0))%2==0 else stone_dark
				box(office,Vector3(x+w*0.5,y,1.19),Vector3(w-0.022,0.34,0.10),c,false)
			x+=w
	# Rivestimento in pietra sulla parete laterale sinistra.
	for row in range(7):
		var y:=0.25+row*0.38
		var z:=1.28
		while z<3.30:
			var w:=0.42+rng.randf_range(0.0,0.20)
			if z+w>3.30:w=3.30-z
			if w>0.10:
				var c:=stone_light if (row+int(absf(z)*10.0))%2==0 else stone
				box(office,Vector3(-4.45,y,z+w*0.5),Vector3(0.10,0.34,w-0.022),c,false)
			z+=w
	# Architrave e piedritti a conci: niente pilastri monolitici.
	for i in range(5):
		var lintel_color:=stone if i%2==0 else stone_light
		box(office,Vector3(-4.24+i*0.62,2.82,3.40),Vector3(0.59,0.29,0.30),lintel_color,false)
	for side_x in [-4.42,-1.50]:
		for i in range(5):
			var jamb_color:=stone_dark if i%2==1 else stone
			box(office,Vector3(side_x,0.26+i*0.54,3.40),Vector3(0.26,0.52,0.28),jamb_color,false)
	for i in range(3):
		box(office,Vector3(-3.90+i*0.95,0.09,3.40),Vector3(0.91,0.16,0.30),stone_light if i==1 else stone_dark,false)
	# Chiave d'arco centrale, leggermente aggettante.
	box(office,Vector3(-2.95,2.82,3.58),Vector3(0.34,0.42,0.12),stone_light,false)
	box(office,Vector3(-2.95,0.07,2.24),Vector3(2.86,0.08,2.18),Color("4c463b"),false)
	box(office,Vector3(-2.95,2.86,2.24),Vector3(2.86,0.08,2.18),stone_dark,false)
	# Catene di ancoraggio: collegano visivamente la gabbia alla pietra.
	for y in [0.35,2.55]:
		box(office,Vector3(-3.13,y,3.42),Vector3(0.10,0.10,0.34),iron,false)
		box(office,Vector3(-3.13,y,3.58),Vector3(0.05,0.05,0.05),Color("c0a067"),false)

func _cell_window(office:Node3D) -> void:
	# Finestra alta nella pietra, con sbarre e una luce calda nella cella.
	var x:=-2.95
	var y:=2.02
	var z:=1.31
	var iron:=Color("2a302d")
	var stone:=Color("625a4b")
	box(office,Vector3(x,y,z-0.015),Vector3(0.62,0.72,0.07),Color("171a18"),false)
	_glow_box(office,Vector3(x,y,z+0.035),Vector3(0.44,0.52,0.02),Color("f0c182"),1.8)
	box(office,Vector3(x,y+0.40,z+0.02),Vector3(0.76,0.10,0.16),stone,false)
	box(office,Vector3(x,y-0.40,z+0.02),Vector3(0.76,0.10,0.16),stone,false)
	box(office,Vector3(x-0.37,y,z+0.02),Vector3(0.10,0.88,0.16),stone,false)
	box(office,Vector3(x+0.37,y,z+0.02),Vector3(0.10,0.88,0.16),stone,false)
	for i in range(4):
		box(office,Vector3(x-0.24+i*0.16,y,z+0.07),Vector3(0.035,0.62,0.035),iron,false)
	box(office,Vector3(x,y+0.30,z+0.075),Vector3(0.56,0.035,0.035),iron,false)
	box(office,Vector3(x,y-0.30,z+0.075),Vector3(0.56,0.035,0.035),iron,false)
	_spot_at(office,Vector3(x,y+0.05,z+0.14),Vector3(x+0.55,0.14,2.72),Color("ffd0a0"),2.6,7.5,27.0)

func _window_shaft(office:Node3D,side:float,z:float,target:Vector3,bars:bool,lit:bool=true) -> void:
	var iron:=Color("292f2c")
	var from:=Vector3(side*4.46,2.08,z)
	if bars:
		for i in range(4):
			box(office,Vector3(side*4.49,1.86,z-0.30+i*0.20),Vector3(0.035,0.98,0.035),iron,false)
		box(office,Vector3(side*4.49,2.33,z),Vector3(0.035,0.035,0.92),iron,false)
		box(office,Vector3(side*4.49,1.38,z),Vector3(0.035,0.035,0.92),iron,false)
	if lit:
		_spot_at(office,from,target,Color("ffd0a0"),2.1,7.5,25.0)

func _spot_at(parent:Node3D,from:Vector3,target:Vector3,color:Color,energy:float,reach:float,angle:float) -> void:
	if not power_on:return
	var spot:=SpotLight3D.new();parent.add_child(spot);spot.position=from
	spot.look_at(parent.to_global(target),Vector3.UP)
	spot.light_color=color;spot.light_energy=energy;spot.spot_range=reach;spot.spot_angle=angle
	spot.spot_angle_attenuation=1.15;spot.shadow_enabled=true
	_short_fade(spot)

## Luci d'interno con ombra: l'ombra si spegne a 25 m e la luce a 40 m (fit_ranges non le allunga più).
func _short_fade(light:Light3D) -> void:
	light.distance_fade_enabled=true;light.distance_fade_begin=40.0;light.distance_fade_length=10.0
	light.distance_fade_shadow=25.0

func _glow_box(parent:Node3D,at:Vector3,size:Vector3,color:Color,energy:float=2.0) -> MeshInstance3D:
	var view:=box(parent,at,size,color,false)
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color;mat.emission_enabled=true;mat.emission=color
	mat.emission_energy_multiplier=energy;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	view.material_override=mat
	return view
