extends Node3D
const Route = preload("res://world/campaign/route.gd")
const RoadNet = preload("res://world/zona1_rifugio/roadnet.gd")
const Placeholder = preload("res://art/placeholders.gd")
const RoadDecals = preload("res://world/campaign/road_decals.gd")
const TILE := 128
const STEP := 8
var tiles: Dictionary = {}
var noise := FastNoiseLite.new()
var sources: Array[PackedScene] = []
var source_names: Array[String] = []
var world: Node3D
var timer: float = 0
var material: StandardMaterial3D
var ground_material: ShaderMaterial
# Strade e oggetti lungo la strada sono divisi per settore (TILE): restano visibili
# solo i settori caricati, così i tratti lontani non galleggiano nel vuoto.
var chunks: Dictionary = {}
var road_material: ShaderMaterial
static var _shared_noise: FastNoiseLite
static var _wave_noise: FastNoiseLite
static var _dune_noise: FastNoiseLite
const Layout = preload("res://world/zona1_rifugio/refuge_layout.gd")
const Village = preload("res://world/villaggio/villaggio_layout.gd")
const Poi = preload("res://world/campaign/roadside_poi.gd")
const Solid = preload("res://world/campaign/solid_props.gd")
## Distanze di disegno: oltre la nebbia gli alberi non si vedono comunque, l'erba sparisce molto prima.
const RANGE_GRASS := 140.0
const RANGE_TREE := 320.0
const RANGE_ROCK := 600.0
## Lavoro massimo per frame sulle tessere in coda (microsecondi): il caricamento non deve far scattare la guida.
const WORK_BUDGET := 2500
const CACTUS := ["SM_Cactus_A", "SM_Cactus_B", "SM_Cactus_C"]
## Distanza della camera: all'aperto si vedono montagne e borgo; dentro il recinto, il borgo e sottoterra la vista e' chiusa e costa di meno.
var far_open := 340.0
var far_closed := 160.0
var poi: Node3D
var _places_by_tile: Dictionary = {}
var _queue: Array[Vector2i] = []
var _jobs: Array[Dictionary] = []
var _mute_cache: Dictionary = {}
var _solid_later: Array = []

func build(owner_world: Node3D) -> void:
	world=owner_world
	noise=shared_noise()
	road_material=ShaderMaterial.new()
	road_material.shader=preload("res://world/campaign/road.gdshader")
	material=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=1
	ground_material=ShaderMaterial.new()
	ground_material.shader=preload("res://world/campaign/ground.gdshader")
	ground_material.set_shader_parameter("desert_box",Vector4(Route.MIN_X,Route.Z2_NORTH,Route.Z2_EAST,Route.WALL_Z))
	for file in DirAccess.get_files_at("res://art/nature"):
		# niente alberi rossi (TwistedTree) e cespugli rossi (Bush_Common): stonano con il resto della mappa
		if file.ends_with(".gltf") and not file.begins_with("TwistedTree") and not file.begins_with("Bush_Common"):
			sources.append(load("res://art/nature/"+file))
			source_names.append(file)
	for id in CACTUS:
		sources.append(load("res://art/zx_desert/%s.glb"%id))
		source_names.append(id)
	poi=Poi.new();poi.name="RoadsideBuilder";poi.ground_height=Callable(self,"height");add_child(poi)
	for i in Route.places().size():
		_file_place(Route.places()[i].at,{"place":i})
	for road_sign in Route.road_signs():
		_file_place(road_sign.at,{"sign":road_sign})
	ensure_near([Vector3.ZERO])
	_roads()
	_side_roads()
	_sites()

static func shared_noise() -> FastNoiseLite:
	if _shared_noise == null:
		_shared_noise=FastNoiseLite.new()
		_shared_noise.seed=20261030
		_shared_noise.frequency=0.003
	return _shared_noise

func height(x: float,z: float) -> float:
	return ground_height(x,z)

## Altezza del terreno visibile: usata anche da alberi, erba e oggetti della Zona 1.
## È la superficie vera della griglia di triangoli: quello che ci si posa sopra non galleggia e non affonda sui pendii.
static func ground_height(x: float,z: float) -> float:
	var gx:=floorf(x/STEP)*STEP
	var gz:=floorf(z/STEP)*STEP
	var fx:=(x-gx)/STEP
	var fz:=(z-gz)/STEP
	var h10:=_raw_height(gx+STEP,gz)
	var h01:=_raw_height(gx,gz+STEP)
	if fx+fz<=1.0:
		var h00:=_raw_height(gx,gz)
		return h00+(h10-h00)*fx+(h01-h00)*fz
	var h11:=_raw_height(gx+STEP,gz+STEP)
	return h11+(h01-h11)*(1.0-fx)+(h10-h11)*(1.0-fz)

## Altezza ai vertici della griglia.
static func _raw_height(x: float,z: float) -> float:
	return Route.shape_height(x,z,_base_height(x,z))

static func _base_height(x: float,z: float) -> float:
	var p:=Vector2(x,z)
	# Preserve the beach and flat starting refuge; the road and every arrival yard are level.
	if absf(x)<90 and z>10 and z<240: return -2.5*smoothstep(10,18,z)
	var refuge_clear:=smoothstep(10,40,maxf(absf(x)-80,absf(z+65)-80))
	var clearing:=minf(refuge_clear,smoothstep(55,100,Route.site_distance(p)))
	var verge:=smoothstep(15,55,Route.road_distance(p))
	# Borgo Cenere: terreno piatto dentro il paese, poi tornano le colline.
	var borgo:=Village.flat(x,z)
	var wave:=zone1_wave(x,z)*borgo
	if clearing*verge*borgo<=0.0: return wave
	# Strade del bosco, arene e luoghi riservati in piano: niente colline sopra le strade.
	if absf(x)<300 and z>-460:
		verge*=smoothstep(6,28,RoadNet.distance(p))*smoothstep(16,42,RoadNet.arena_distance(p))
		verge*=smoothstep(RoadNet.SITE_RADIUS,RoadNet.SITE_RADIUS+28,RoadNet.site_distance(p))
	var hills:=maxf(0,shared_noise().get_noise_2d(x,z)*42+15)
	var sand:=Route.desert(x,z)
	if sand>0.0: hills=lerpf(hills,dunes(x,z),sand)
	return hills*clearing*verge*borgo+wave

## Le dune del Mare di Sabbia: lunghe creste morbide, non colline.
static func dunes(x: float, z: float) -> float:
	if _dune_noise==null:
		_dune_noise=FastNoiseLite.new()
		_dune_noise.seed=771
		_dune_noise.frequency=0.0042
		_dune_noise.fractal_octaves=2
	var ridge:=1.0-absf(_dune_noise.get_noise_2d(x*0.75+z*0.35,z))*2.3
	return maxf(0.0,ridge)*ridge*17.0+_dune_noise.get_noise_2d(x*2.0,z*2.0)*2.2+2.5

## Ondulazione leggera della Zona 1 (al massimo ~0,8 m): il prato non è più un biliardo e le
## strade la seguono, ma paese, rovine, arene, luoghi riservati e punti di comparsa restano in piano.
static func zone1_wave(x: float, z: float) -> float:
	var area:=1.0-smoothstep(0.0,40.0,maxf(absf(x)-300.0,-z-330.0))
	# Verso il lago si spegne prima della spiaggia (z > 10).
	area*=1.0-smoothstep(-14.0,8.0,z)
	if area<=0.0: return 0.0
	var pad:=smoothstep(0.0,14.0,maxf(absf(x-5.0)-34.0,absf(z+19.0)-31.0))
	for corner in [Layout.CABIN,Layout.FARM]:
		pad=minf(pad,smoothstep(9.0,20.0,maxf(absf(x-corner.x-4.0),absf(z-corner.z-4.0))))
	if pad<=0.0: return 0.0
	var p:=Vector2(x,z)
	pad=minf(pad,smoothstep(20.0,36.0,RoadNet.arena_distance(p)))
	pad=minf(pad,smoothstep(RoadNet.SITE_RADIUS,RoadNet.SITE_RADIUS+22.0,RoadNet.site_distance(p)))
	for at in Layout.PART_POINTS+Layout.ENEMIES:
		pad=minf(pad,smoothstep(3.0,9.0,p.distance_to(Vector2(at.x,at.z))))
	if pad<=0.0: return 0.0
	if _wave_noise==null:
		_wave_noise=FastNoiseLite.new()
		_wave_noise.seed=1907
		_wave_noise.frequency=0.011
		_wave_noise.fractal_octaves=2
	return _wave_noise.get_noise_2d(x,z)*1.4*area*pad

func chunk(at: Vector3) -> Node3D:
	var key:=Vector2i(floori(at.x/TILE),floori(at.z/TILE))
	if not chunks.has(key):
		var node:=Node3D.new();node.name="Roadside_%d_%d"%[key.x,key.y];add_child(node)
		node.visible=tiles.has(key)
		chunks[key]=node
	return chunks[key]

func _process(delta: float) -> void:
	if not world.started: return
	# La Cripta sta sospesa a 260 m: in superficie non deve vedersi e non deve pesare.
	if world.get("dungeon"): world.dungeon.visible=world.player.global_position.y>150.0
	_fit_camera(delta)
	_work(WORK_BUDGET)
	timer-=delta
	if timer>0: return
	timer=0.35
	# I luoghi lungo la strada: dopo un giro di fisica, quello che è rimasto senza collisione prende una scatola.
	for group in _solid_later:
		if is_instance_valid(group): Solid.box_loose_props(group,world)
	_solid_later.clear()
	# Il terreno serve attorno a chi gioca: ±2 tessere a piedi, ±3 in auto, ±1 sotto il 4×4 parcheggiato.
	var wanted: Dictionary={}
	_want(wanted,world.player.position,3 if world.player.seated else 2)
	if not Session.online or multiplayer.is_server():
		for actor in world.actors.values(): _want(wanted,actor.position,3 if actor.seated else 2)
	if world.expedition and world.expedition.car:
		var car:Node3D=world.expedition.car
		_want(wanted,car.position,3 if car.seats.count(0)<car.seats.size() else 1)
	_apply_needed(wanted,true)

func _fit_camera(delta: float) -> void:
	var at:Vector3=world.player.global_position
	var closed:bool=at.y>150.0 or Layout.safe(at) or Village.inside(at.x,at.z)
	var camera:Camera3D=world.player.rig.camera
	# Si cambia piano: la nebbia a quella distanza copre il passaggio.
	camera.far=move_toward(camera.far,far_closed if closed else far_open,delta*120.0)

## Carica subito e tutto (partenza, salvataggi, teletrasporti). "wide" sono i punti da tenere a ±3.
func ensure_near(positions: Array, wide: Array=[]) -> void:
	var wanted: Dictionary={}
	for point in positions: _want(wanted,point,2)
	for point in wide: _want(wanted,point,3)
	_apply_needed(wanted,false)

## Distanze di disegno per tutto il resto del mondo: con la camera piu' lunga i pezzi piccoli lontani non devono pesare.
func fit_world_ranges(extra: Array) -> void:
	for key in chunks: Poi.fit_ranges(chunks[key])
	for child in get_parent().get_children():
		if child!=self: Poi.fit_ranges(child)
	for node in extra:
		if node: Poi.fit_ranges(node)

func _want(wanted: Dictionary, point: Vector3, radius: int) -> void:
	var center:=Vector2i(floori(point.x/TILE),floori(point.z/TILE))
	for x in range(-radius,radius+1):
		for z in range(-radius,radius+1):
			var key:=center+Vector2i(x,z)
			wanted[key]=mini(int(wanted.get(key,99)),maxi(absi(x),absi(z)))

func _apply_needed(needed: Dictionary, queued: bool) -> void:
	for key in tiles.keys():
		if not needed.has(key): tiles[key].queue_free();tiles.erase(key)
	_queue=_queue.filter(func(key:Vector2i)->bool:return needed.has(key) and not tiles.has(key))
	for key in needed:
		if tiles.has(key): continue
		# Sotto i piedi la tessera serve subito, le altre arrivano un po' per frame.
		if not queued or needed[key]<=1: _start_tile(key)
		elif not _queue.has(key): _queue.append(key)
	_queue.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return needed[a]<needed[b])
	for key in chunks: chunks[key].visible=needed.has(key)
	if not queued: _work(-1)

## Finisce le tessere in coda finché c'è tempo: budget in microsecondi, -1 = tutto.
func _work(budget: int) -> void:
	var start:=Time.get_ticks_usec()
	while budget<0 or Time.get_ticks_usec()-start<budget:
		if not _jobs.is_empty():
			var job:Dictionary=_jobs[0]
			if not is_instance_valid(job.group) or job.group.is_queued_for_deletion() or job.next>=job.plan.size():
				_jobs.pop_front()
				continue
			_spawn(job.group,job.plan[job.next])
			job.next+=1
		elif not _queue.is_empty():
			_start_tile(_queue.pop_front())
			# Il terreno di una tessera basta per un frame.
			if budget>=0: return
		else:
			return

func _start_tile(key: Vector2i) -> void:
	var group:=Node3D.new()
	group.name="Sector_%d_%d"%[key.x,key.y]
	add_child(group)
	tiles[key]=group
	_ground(key,group)
	_jobs.append({"key":key,"group":group,"plan":_plan(key),"next":0})

func _file_place(at: Vector3, entry: Dictionary) -> void:
	var key:=Vector2i(floori(at.x/TILE),floori(at.z/TILE))
	if not _places_by_tile.has(key): _places_by_tile[key]=[]
	_places_by_tile[key].append(entry)

func _ground(key: Vector2i, group: Node3D) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Altezze calcolate una volta per vertice della griglia (con un bordo per le normali).
	var n:int=TILE/STEP+3
	var grid:=PackedFloat32Array();grid.resize(n*n)
	for gz in n:
		for gx in n:
			grid[gz*n+gx]=_raw_height(key.x*TILE+(gx-1)*STEP,key.y*TILE+(gz-1)*STEP)
	var near_edge:bool=Route.edge_distance(key.x*TILE+TILE*0.5,key.y*TILE+TILE*0.5)<800.0 or Route.wall_distance(key.x*TILE+TILE*0.5,key.y*TILE+TILE*0.5)<220.0
	for x in range(0,TILE,STEP):
		for z in range(0,TILE,STEP):
			if RoadNet.in_terrain_hole(key.x*TILE+x,key.y*TILE+z): continue
			for offset in [Vector2i(0,0),Vector2i(STEP,0),Vector2i(0,STEP),Vector2i(STEP,0),Vector2i(STEP,STEP),Vector2i(0,STEP)]:
				var px:float=key.x*TILE+x+offset.x
				var pz:float=key.y*TILE+z+offset.y
				var gx:int=(x+offset.x)/STEP+1
				var gz:int=(z+offset.y)/STEP+1
				# Normali continue dal rilievo: niente facce piatte a scacchiera sui pendii.
				var nx:=grid[gz*n+gx+1]-grid[gz*n+gx-1]
				var nz:=grid[(gz+1)*n+gx]-grid[(gz-1)*n+gx]
				st.set_normal(Vector3(-nx,2.0*STEP,-nz).normalized())
				var tint:=Color("354d2c").lerp(Color("5d7644"),clampf(noise.get_noise_2d(px*9,pz*9)+0.5,0,1))
				# L'alfa dice allo shader quanta roccia c'è: solo sulle montagne del bordo.
				if near_edge: tint.a=1.0-smoothstep(16.0,46.0,Route.edge_rise(px,pz))
				st.set_color(tint)
				st.add_vertex(Vector3(px,grid[gz*n+gx],pz))
	var ground:=MeshInstance3D.new()
	ground.mesh=st.commit()
	ground.material_override=ground_material
	group.add_child(ground)
	ground.create_trimesh_collision()

## Cosa ci sta su una tessera: stessa sequenza casuale su ogni macchina, poi si crea un pezzo alla volta.
func _plan(key: Vector2i) -> Array:
	var plan: Array=[]
	var rng:=RandomNumberGenerator.new()
	rng.seed=absi(key.x*73856093 ^ key.y*19349663)+2026
	# Più pini per settore: il bosco resta fitto ora che è di un solo tipo.
	for i in range(70):
		var x:=key.x*TILE+rng.randf_range(0,TILE)
		var z:=key.y*TILE+rng.randf_range(0,TILE)
		if absf(x)<75 and z> -90: continue
		if Route.road_distance(Vector2(x,z))<11 or Route.site_distance(Vector2(x,z))<40: continue
		# Nel deserto niente bosco: qualche cactus, un albero morto ogni tanto.
		if Route.desert(x,z)>0.5:
			if Route.edge_rise(x,z)>12.0: continue
			if i%9<2:
				plan.append({"pick":source_names.find(CACTUS[posmod(key.x+key.y+i,3)]),"x":x,"z":z,"yaw":rng.randf_range(0,TAU),"scale":Vector3.ONE*rng.randf_range(0.8,1.5),"cactus":true})
			elif i%23==3:
				plan.append({"pick":source_names.find("DeadTree_%d.gltf"%rng.randi_range(1,5)),"x":x,"z":z,"yaw":rng.randf_range(0,TAU),"scale":Vector3.ONE*rng.randf_range(0.7,1.1),"tree":true,"body":false})
			continue
		if RoadNet.distance(Vector2(x,z))<9.0 or RoadNet.arena_distance(Vector2(x,z))<17.0: continue
		if RoadNet.clearing_distance(Vector2(x,z))<4.0 or Layout.near_fence(x,z) or Village.inside(x,z): continue
		var pick:=rng.randi_range(0,sources.size()-1)
		# Un solo linguaggio visivo: pini a cono. Le chiome tonde (CommonTree) e gli
		# alberi scheletrici (TwistedTree, DeadTree) stonavano con il bosco della mappa.
		var pines:=["Pine_1.gltf","Pine_2.gltf","Pine_3.gltf","Pine_4.gltf","Pine_5.gltf"]
		if i%2==0:
			pick=source_names.find(pines[posmod(key.x+key.y+i,5)])
		elif _off_style(source_names[pick]):
			pick=source_names.find(pines[rng.randi_range(0,pines.size()-1)])
		var yaw:=rng.randf_range(0,TAU)
		var size:=rng.randf_range(0.8,1.4)
		# Sulla roccia del bordo non crescono alberi, e nemmeno appesi alle pareti fra le zone.
		if Route.edge_rise(x,z)>38.0 or Route.zone_wall(x,z)>5.0: continue
		plan.append({"pick":pick,"x":x,"z":z,"yaw":yaw,"scale":Vector3.ONE*size,"tree":"Tree" in source_names[pick] or "Pine" in source_names[pick],"body":i%5==0})
	# Sottobosco: felci, cespugli, fiori, funghi e ciottoli vicino al terreno.
	var undergrowth:=["Fern_1.gltf","Pebble_Round_1.gltf","Pebble_Square_2.gltf","Grass_Wispy_Tall.gltf","Grass_Common_Short.gltf"]
	# Niente cespugli: né rossi né verdi chiaro, restano felci, erba e sassi.
	for i in range(26):
		var x:=key.x*TILE+rng.randf_range(0,TILE)
		var z:=key.y*TILE+rng.randf_range(0,TILE)
		if absf(x)<72 and z> -86: continue
		# Sulla sabbia solo sassi e ciuffi secchi, pochi.
		if Route.desert(x,z)>0.5 and i%4!=1 and i%4!=3: continue
		if Route.road_distance(Vector2(x,z))<8 or Route.site_distance(Vector2(x,z))<20: continue
		if RoadNet.distance(Vector2(x,z))<6.5 or RoadNet.arena_distance(Vector2(x,z))<12.0: continue
		if RoadNet.clearing_distance(Vector2(x,z))<-4.0 or Layout.near_fence(x,z) or Village.inside(x,z): continue
		var pick:=source_names.find(undergrowth[i%undergrowth.size()])
		if pick<0: continue
		var yaw:=rng.randf_range(0,TAU)
		var size:=rng.randf_range(0.45,0.95)
		var stretch:=rng.randf_range(0.9,1.2)
		if Route.edge_rise(x,z)>38.0 or Route.zone_wall(x,z)>5.0: continue
		plan.append({"pick":pick,"x":x,"z":z,"yaw":yaw,"scale":Vector3(size,size*stretch,size),"grass":true})
	# Massi sui fianchi delle montagne.
	if Route.edge_distance(key.x*TILE+TILE*0.5,key.y*TILE+TILE*0.5)<700.0 or Route.wall_distance(key.x*TILE+TILE*0.5,key.y*TILE+TILE*0.5)<200.0:
		for i in range(10):
			var x:=key.x*TILE+rng.randf_range(0,TILE)
			var z:=key.y*TILE+rng.randf_range(0,TILE)
			var pick:=source_names.find("Rock_Medium_%d.gltf"%rng.randi_range(1,3))
			var yaw:=rng.randf_range(0,TAU)
			var size:=rng.randf_range(2.5,8.0)
			if pick<0 or Route.edge_rise(x,z)<22.0: continue
			plan.append({"pick":pick,"x":x,"z":z,"yaw":yaw,"scale":Vector3.ONE*size,"rock":true})
	plan.append_array(_places_by_tile.get(key,[]))
	return plan

func _spawn(group: Node3D, entry: Dictionary) -> void:
	if entry.has("place"):
		var at:Vector3=Route.places()[entry.place].at
		poi.build_place(group,entry.place,height(at.x,at.z))
		_solid_later.append(group)
		return
	if entry.has("sign"):
		poi.build_sign(group,entry.sign,height(entry.sign.at.x,entry.sign.at.z))
		return
	var item:Node3D=sources[entry.pick].instantiate()
	group.add_child(item)
	item.position=Vector3(entry.x,height(entry.x,entry.z),entry.z)
	item.rotation.y=entry.yaw
	item.scale=entry.scale
	if entry.has("grass"):
		_set_range(item,RANGE_GRASS)
		return
	if entry.has("cactus"):
		_set_range(item,RANGE_TREE)
		Solid.add_trunk(item,group)
		return
	if entry.has("rock"):
		_set_range(item,RANGE_ROCK)
		Solid.add_rock(item)
		return
	_set_range(item,RANGE_TREE)
	if entry.tree:
		_mute_tree(item)
		# Ogni tronco è solido: un cilindro statico solo, non pesa sulla fisica.
		Solid.add_trunk(item,group)

func _set_range(node: Node, value: float) -> void:
	if node is GeometryInstance3D: (node as GeometryInstance3D).visibility_range_end=value
	for child in node.get_children(): _set_range(child,value)


func _roads() -> void:
	# Asfalto continuo: tre colonne (bordo, centro consumato, bordo), senza
	# sponde pavimentate: ai lati resta il prato della radura.
	var points:Array=_sample_path(Route.road_points(),6.0)
	# Asfalto rovinato (road.gdshader): crepe, rattoppi e buche, diviso per settore.
	var asphalt:={}
	_road_strip(asphalt,points,3.45,0.075,Color("3b3b35"),Color("4e4c44"))
	_commit(asphalt,road_material)
	_distances(points)
	_road_end()
	_roadside()

func _road_end() -> void:
	# Inizio della strada: l'asfalto arriva al lago e finisce nel prato, con
	# barriere, panchina, lampione e il passaggio verso il pontile.
	var asphalt:={}
	_road_strip(asphalt,_sample_path([Vector3(6,0,-6.5),Vector3(6,0,2.6)],1.5),3.45,0.075,Color("3b3b35"),Color("4e4c44"))
	_commit(asphalt,road_material)
	var rng:=RandomNumberGenerator.new();rng.seed=4410
	# Fine dell'asfalto mangiata dal gelo.
	_stain(Vector3(6,0,2.2),4.2,0.0,Color.BLACK,"torn")
	_stain(Vector3(4.4,0,-1.5),2.6,0.7,Color.BLACK,"crack")
	_stain(Vector3(7.8,0,-4.0),1.2,0.0,Color.BLACK,"pothole")
	var barrier:=_scene("res://art/zx_borgo/SM_Prop_RoadBarrier_Small.glb")
	_place(barrier,Vector3(3.6,0,4.0),0.35)
	var barrier2:=_scene("res://art/zx_borgo/SM_Prop_RoadBarrier_Small.glb")
	_place(barrier2,Vector3(9.1,0,3.7),-0.5)
	var bench:=_scene("res://art/kaykit_city/bench.gltf");bench.scale=Vector3.ONE*2.6
	_place(bench,Vector3(1.8,0,7.4),PI)
	var bin:=_scene("res://art/kaykit_city/trash_A.gltf");bin.scale=Vector3.ONE*2.4
	_place(bin,Vector3(10.6,0,7.0),0.4)
	var lamp:=_scene("res://art/kaykit_city/streetlight.gltf");lamp.scale=Vector3.ONE*3.2
	_place(lamp,Vector3(10.4,0,1.2),-PI/2)
	var glow:=OmniLight3D.new();glow.light_color=Color("ffcf8a");glow.light_energy=1.2;glow.omni_range=9
	_place(glow,Vector3(9.4,0,1.2),0.0).position.y+=4.0
	# Qualcuno è stato trascinato verso l'acqua.
	_stain(Vector3(7.2,0,6.0),3.0,0.25,Color.BLACK,"drag")
	_stain(Vector3(6.8,0,4.6),1.3,0.0,Color.BLACK,"blood")

func _tool(tools:Dictionary, at:Vector3) -> SurfaceTool:
	var key:=Vector2i(floori(at.x/TILE),floori(at.z/TILE))
	if not tools.has(key):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);tools[key]=st
	return tools[key]

func _commit(tools:Dictionary, mat:Material, normals:=true) -> void:
	for key in tools:
		var st:SurfaceTool=tools[key]
		if normals:st.generate_normals()
		var view:=MeshInstance3D.new();view.mesh=st.commit();view.material_override=mat
		chunk(Vector3(key.x*TILE+1,0,key.y*TILE+1)).add_child(view)

func _side_roads() -> void:
	# Strade locali: nastro unico con lati raccordati, non una serie di strisce
	# staccate. Niente sponde di ghiaia: il prato arriva al ciglio.
	var asphalt := {}
	var paths:Array=RoadNet.paths()
	for index in paths.size():
		# Il ramo parte dal bordo della statale, non dal centro: niente triangolo
		# scuro che taglia l'erba allo sbocco.
		var points:Array=_sample_path(_trim_to_road_edge(paths[index]),4.0)
		# Incroci: la strada si allarga a imbuto negli ultimi 10 m, come un raccordo vero.
		# Ogni ramo sta qualche millimetro più in basso del precedente: dove due rami si
		# sovrappongono all'incrocio non sfarfallano.
		var widths:Array=[]
		var last:Vector3=points[points.size()-1]
		# La bretella del borgo continua nella via est: non è una strada senza uscita.
		var dead_end:bool=RoadNet.junction_distance(Vector2(last.x,last.z))>1.0 and not Village.inside(last.x,last.z)
		for p in points:
			# Allo sbocco il raccordo si apre piano, senza spuntoni.
			var w:float=1.0+0.55*pow(1.0-clampf(RoadNet.junction_distance(Vector2(p.x,p.z))/16.0,0.0,1.0),2.0)
			# Dove la strada finisce: punta arrotondata, non un triangolo.
			if dead_end:w*=lerpf(0.12,1.0,sqrt(clampf(p.distance_to(last)/5.0,0.0,1.0)))
			widths.append(w)
		var drop:=0.004*float(index%4)
		_road_strip(asphalt,points,RoadNet.WIDTH*0.5,0.060-drop,Color("41413a"),Color("545249"),0.0,widths)
	_reserved_sites()
	# Strade del bosco: stesso asfalto rovinato, con più crepe.
	var side_material:=road_material.duplicate() as ShaderMaterial
	side_material.set_shader_parameter("crack_amount",1.4)
	_commit(asphalt,side_material)

func _reserved_sites() -> void:
	# Niente piazzali disegnati: la terra battuta della piazza la dipinge la maschera dell'erba (grass_field.gd), dal bordo irregolare.
	for key in []:
		var center:Vector3=RoadNet.SITES[key]
		var site:=Node3D.new();site.name="ReservedSite_"+key
		chunk(center).add_child(site)
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var radius:float=RoadNet.SITE_RADIUS*0.85
		var rim:Array[Vector3]=[]
		for i in range(48):
			var angle:=TAU*i/48.0
			# Bordo irregolare: il prato si mangia la terra.
			var r:=radius*(0.9+0.1*noise.get_noise_2d(cos(angle)*90.0+center.x,sin(angle)*90.0))
			var x:=center.x+cos(angle)*r;var z:=center.z+sin(angle)*r
			rim.append(Vector3(x,height(x,z)+0.03,z))
		var middle:=Vector3(center.x,height(center.x,center.z)+0.03,center.z)
		for i in range(48):
			for p in [middle,rim[i],rim[(i+1)%48]]:
				st.set_color(Color("6a5f4a").lerp(Color("5a5141"),0.5+0.5*sin(p.x*0.3+p.z*0.2)))
				st.set_normal(Vector3.UP)
				st.add_vertex(p)
		var pad:=MeshInstance3D.new();pad.mesh=st.commit()
		var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=1.0
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		pad.material_override=mat;site.add_child(pad)

func _trim_to_road_edge(path:Array) -> Array:
	# Taglia i primi metri del ramo che finiscono sotto la statale, così la
	# strada locale nasce dal ciglio e non disegna una toppa sopra l'asfalto.
	var out:Array=[]
	var started:=false
	for i in range(path.size()-1):
		var a:Vector3=path[i];var b:Vector3=path[i+1]
		var n:int=maxi(2,ceili(a.distance_to(b)/2.0))
		for s in range(n):
			var p:Vector3=a.lerp(b,float(s)/n)
			if not started:
				if Route.road_distance(Vector2(p.x,p.z))>3.55:
					out.append(p);started=true
			else:out.append(p)
	out.append(path[path.size()-1])
	return out if out.size()>=2 else path

func _sample_path(points:Array, step:float) -> Array:
	# Campiona ogni segmento a passo fisso: curve morbide anche con pochi punti.
	var out:Array=[]
	for i in range(points.size()-1):
		var a:Vector3=points[i];var b:Vector3=points[i+1]
		var n:int=maxi(1,ceili(a.distance_to(b)/step))
		for s in range(n):out.append(a.lerp(b,float(s)/n))
	out.append(points[points.size()-1])
	return out

func _road_strip(tools:Dictionary, points:Array, half:float, lift:float, base:Color, edge:Color, taper:float=0.0, widths:Array=[]) -> void:
	if points.size()<2:return
	var sides:Array[Vector3]=[]
	for i in range(points.size()):
		var prev:Vector3=points[maxi(i-1,0)]
		var next:Vector3=points[mini(i+1,points.size()-1)]
		var dir:=Vector3(next.x-prev.x,0,next.z-prev.z)
		if dir.length()<0.001:dir=Vector3(0,0,1)
		sides.append(dir.normalized().cross(Vector3.UP).normalized())
	var columns:Array[float]=[-half,0.0,half]
	for i in range(points.size()-1):
		var a:Vector3=points[i];var b:Vector3=points[i+1]
		if a.distance_to(b)<0.05:continue
		var sa:Vector3=sides[i];var sb:Vector3=sides[i+1]
		var st:=_tool(tools,(a+b)*0.5)
		# Allo sbocco la strada si allarga da 40% a 100% in pochi metri.
		var ha:float=half*(lerpf(0.40,1.0,clampf(float(i)/taper,0.0,1.0)) if taper>0.0 else 1.0)
		var hb:float=half*(lerpf(0.40,1.0,clampf(float(i+1)/taper,0.0,1.0)) if taper>0.0 else 1.0)
		if not widths.is_empty():
			ha*=widths[i];hb*=widths[i+1]
		for col in range(2):
			# p0/p1 sullo stesso lato del nastro, ognuno con la larghezza del proprio punto:
			# così l'imbuto degli incroci si allarga senza scalini.
			var p0:=_edge_point(a,sa,columns[col]*ha/half,lift);var p1:=_edge_point(b,sb,columns[col]*hb/half,lift)
			var p2:=_edge_point(a,sa,columns[col+1]*ha/half,lift);var p3:=_edge_point(b,sb,columns[col+1]*hb/half,lift)
			var c0:Color=edge if col==0 else base
			var c1:Color=base if col==0 else edge
			for row in [[p0,c0],[p1,c0],[p2,c1],[p1,c0],[p3,c1],[p2,c1]]:
				_push_road(st,row[0],row[1])

func _edge_point(at:Vector3, side:Vector3, width:float, lift:float) -> Vector3:
	var x:float=at.x+side.x*width;var z:float=at.z+side.z*width
	return Vector3(x,height(x,z)+lift,z)

func _push_road(st:SurfaceTool, at:Vector3, color:Color) -> void:
	st.set_color(color.darkened(0.05*(0.5+0.5*sin(at.x*0.13+at.z*0.17))))
	st.set_normal(_ground_normal(at.x,at.z))
	st.add_vertex(at)

func _ground_normal(x:float,z:float) -> Vector3:
	var e:=1.5
	var nx:=height(x+e,z)-height(x-e,z)
	var nz:=height(x,z+e)-height(x,z-e)
	return Vector3(-nx,2.0*e,-nz).normalized()

func _distances(samples:Array) -> void:
	# Tratteggio centrale sbiadito e a tratti mancante: la vernice non è più rifatta da anni.
	var tools:={}
	var travelled:=0.0
	for i in range(samples.size()-1):
		var a:Vector3=samples[i];var b:Vector3=samples[i+1]
		var length:=a.distance_to(b)
		var dir:Vector3=(b-a).normalized()
		var side:Vector3=dir.cross(Vector3.UP).normalized()
		var phase:=fmod(travelled,11.0)
		var worn:bool=noise.get_noise_2d(a.x*3.0,a.z*3.0)>0.18
		if phase<3.6 and not worn:
			var st:=_tool(tools,(a+b)*0.5)
			# Sopra l'asfalto (0.075), altrimenti la mezzeria sparisce sotto.
			var ya:float=height(a.x,a.z)+0.085
			var yb:float=height(b.x,b.z)+0.085
			var left_a:=Vector3(a.x-side.x*0.13,ya,a.z-side.z*0.13)
			var right_a:=Vector3(a.x+side.x*0.13,ya,a.z+side.z*0.13)
			var left_b:=Vector3(b.x-side.x*0.13,yb,b.z-side.z*0.13)
			var right_b:=Vector3(b.x+side.x*0.13,yb,b.z+side.z*0.13)
			st.set_color(Color("b6ab84"))
			for p in [left_a,left_b,right_a,left_b,right_b,right_a]: st.add_vertex(p)
		travelled+=length
	var mark_material:=StandardMaterial3D.new()
	mark_material.albedo_color=Color("a39d82")
	mark_material.roughness=0.9
	_commit(tools,mark_material)

const WRECKS:=["car_sedan","car_hatchback","car_stationwagon","car_taxi","car_police"]
# Detriti: sacchi della spazzatura e oggetti del kit ambiente ZOMBIX (niente casse da dungeon).
const JUNK:=["res://art/kaykit_city/trash_A.gltf","res://art/kaykit_city/trash_B.gltf","res://art/env/shop/SM_Prop_AmmoCrate_Wood.glb","res://art/env/interactive/SM_Int_Chest_Supply.glb","res://art/env/shop/SM_Prop_OilTin.glb","res://art/env/shop/SM_Prop_AmmoCan_Military.glb"]
var _scene_cache:Dictionary={}

func _scene(path:String) -> Node3D:
	if not _scene_cache.has(path):_scene_cache[path]=load(path)
	return _scene_cache[path].instantiate()

func _place(node:Node3D,at:Vector3,yaw:float) -> Node3D:
	chunk(at).add_child(node)
	node.position=Vector3(at.x,height(at.x,at.z),at.z)
	node.rotation.y=yaw
	return node

func _burn(node:Node) -> void:
	# Carcassa bruciata: stessi modelli, colori carbonizzati.
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat=node.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				var copy:StandardMaterial3D=mat.duplicate()
				copy.albedo_color=copy.albedo_color.lerp(Color(0.10,0.09,0.08),0.78)
				copy.roughness=1.0
				node.set_surface_override_material(i,copy)
	for child in node.get_children():_burn(child)

func _stain(at:Vector3,size:float,yaw:float,_color:Color,kind:String="blood") -> void:
	# Decal proiettato sull'asfalto (world/campaign/road_decals.gd): segue la superficie.
	var aspect:float=0.5 if kind=="drag" else 1.0
	var d:=RoadDecals.decal(kind,Vector2(size,size*aspect),yaw)
	_place(d,at,yaw).position.y+=0.1

func _road_damage(points:Array, half:float, rng:RandomNumberGenerator) -> void:
	# Strada rotta: crepe ogni pochi metri, buche con pezzi d'asfalto sollevati,
	# bordi strappati fino alla ghiaia.
	var travelled:=0.0
	for i in range(points.size()-1):
		var a:Vector3=points[i];var b:Vector3=points[i+1]
		var dir:=(b-a).normalized();var side:=dir.cross(Vector3.UP).normalized()
		travelled+=a.distance_to(b)
		if travelled<rng.randf_range(5.0,9.0):continue
		travelled=0.0
		if a.z>-40.0 and absf(a.x-6.0)<40.0 and rng.randf()<0.6:continue
		var yaw:=atan2(-dir.x,-dir.z)
		var roll:=rng.randf()
		var at:=a+side*rng.randf_range(-half*0.8,half*0.8)
		if roll<0.5:
			_stain(at,rng.randf_range(1.6,3.2),rng.randf_range(0,TAU),Color.BLACK,"crack")
		elif roll<0.68:
			_stain(at,rng.randf_range(0.9,1.7),rng.randf_range(0,TAU),Color.BLACK,"pothole")
			for k in rng.randi_range(2,4):
				var chunk_at:=at+Vector3(rng.randf_range(-0.9,0.9),0,rng.randf_range(-0.9,0.9))
				var slab:=_box(chunk(chunk_at),Vector3(rng.randf_range(0.18,0.42),0.06,rng.randf_range(0.14,0.3)),Vector3(chunk_at.x,height(chunk_at.x,chunk_at.z)+0.1,chunk_at.z),Color("2c2c29"))
				slab.rotation=Vector3(rng.randf_range(-0.4,0.4),rng.randf_range(0,TAU),rng.randf_range(-0.4,0.4))
		elif roll<0.86:
			var edge:=a+side*(half-0.3)*(1.0 if rng.randf()<0.5 else -1.0)
			_stain(edge,rng.randf_range(1.8,3.4),yaw+rng.randf_range(-0.3,0.3),Color.BLACK,"torn")
		else:
			# Tracce di chi è stato trascinato via.
			_stain(at,rng.randf_range(2.4,3.8),yaw+rng.randf_range(-0.6,0.6),Color.BLACK,"drag")
			_stain(at-dir*1.4,rng.randf_range(0.9,1.4),rng.randf_range(0,TAU),Color.BLACK,"blood")

func _zombie_road(points:Array, from_index:int, count:int, rng:RandomNumberGenerator) -> void:
	# Ogni ~26 m qualcosa racconta la fuga: auto ferme sul ciglio, detriti, sangue.
	# I relitti restano fuori da una corsia (|offset| >= 3.9 m): il 4×4 passa sempre.
	var travelled:=0.0
	var next:=rng.randf_range(10,24)
	for i in range(from_index,mini(from_index+count,points.size()-1)):
		var a:Vector3=points[i];var b:Vector3=points[i+1]
		var dir:=(b-a).normalized();var side:=dir.cross(Vector3.UP).normalized()
		var length:=a.distance_to(b)
		var s:=0.0
		while travelled+length-s>=next:
			s+=next-travelled;travelled=0.0;next=rng.randf_range(18,34)
			var at:=a+dir*s
			var flip:=-1.0 if rng.randf()<0.5 else 1.0
			var roll:=rng.randf()
			# Il paese e le arene restano sgombri.
			if (at.z>-48.0 and absf(at.x-6.0)<45.0) or RoadNet.arena_distance(Vector2(at.x,at.z))<20.0:continue
			if Village.inside(at.x,at.z) or RoadNet.site_distance(Vector2(at.x,at.z))<RoadNet.SITE_RADIUS or RoadNet.junction_distance(Vector2(at.x,at.z))<12.0:continue
			var yaw:=atan2(-dir.x,-dir.z)
			if roll<0.38:
				var car:=_scene("res://art/kaykit_city/%s.gltf"%WRECKS[rng.randi_range(0,WRECKS.size()-1)])
				car.scale=Vector3.ONE*4.0
				_place(car,at+side*flip*rng.randf_range(4.4,6.2),yaw+rng.randf_range(-0.9,0.9))
				if rng.randf()<0.45:_burn(car)
				_collide_box(car)
				_stain(at+side*flip*rng.randf_range(1.0,2.6),rng.randf_range(0.8,1.6),rng.randf_range(0,TAU),Color(0.22,0.03,0.02,0.75))
			elif roll<0.70:
				for k in rng.randi_range(2,4):
					var junk:=_scene(JUNK[rng.randi_range(0,JUNK.size()-1)])
					var size:=rng.randf_range(1.6,2.6) if "kaykit_city" in junk.scene_file_path else rng.randf_range(0.95,1.1)
					junk.scale=Vector3.ONE*size
					_place(junk,at+side*flip*rng.randf_range(4.6,6.8)+dir*rng.randf_range(-2.5,2.5),rng.randf_range(0,TAU))
			elif roll<0.86:
				_stain(at+side*rng.randf_range(-2.0,2.0),rng.randf_range(1.0,2.2),rng.randf_range(0,TAU),Color(0.20,0.03,0.02,0.7))
				_stain(at+side*rng.randf_range(-2.0,2.0)+dir*1.6,rng.randf_range(0.4,0.9),rng.randf_range(0,TAU),Color(0.16,0.02,0.02,0.65))
			else:
				var barrier:=_scene("res://art/zx_borgo/SM_Prop_RoadBarrier_Small.glb")
				_place(barrier,at+side*flip*rng.randf_range(4.0,5.0),yaw+PI*0.5+rng.randf_range(-0.6,0.6))
			# Alberi secchi sul ciglio, come nel concept del rifugio.
			if rng.randf()<0.22:
				var dead:=_scene("res://art/nature/DeadTree_%d.gltf"%rng.randi_range(1,5))
				dead.scale=Vector3.ONE*rng.randf_range(0.9,1.4)
				_place(dead,at+side*flip*rng.randf_range(9.0,13.0),rng.randf_range(0,TAU))
		travelled+=length-s

func _roadside() -> void:
	# Palo della luce spento, relitti e detriti: la strada deve raccontare l'abbandono.
	var points:Array=Route.road_points()
	var rng:=RandomNumberGenerator.new();rng.seed=6061
	var main:=_sample_path(points,6.0)
	_zombie_road(main,2,140,rng)
	_road_damage(main.slice(0,160),3.45,rng)
	for path in RoadNet.paths():
		var side_rng:=RandomNumberGenerator.new();side_rng.seed=int(absf(path[0].x*31+path[0].z*17))+9
		var samples:=_sample_path(path,4.0)
		_zombie_road(samples,3,400,side_rng)
		_road_damage(samples,RoadNet.WIDTH*0.5,side_rng)
	for i in range(1,7):
		var a:Vector3=points[i]
		var b:Vector3=points[i+1]
		var dir:Vector3=(b-a).normalized()
		var side:Vector3=dir.cross(Vector3.UP).normalized()
		var pole:=Node3D.new()
		var pole_at:Vector3=a+side*8.5
		_place(pole,pole_at,atan2(-dir.x,-dir.z))
		# Pali piegati dal tempo, non tutti dritti.
		pole.rotation.z=rng.randf_range(-0.18,0.18)
		var shaft:=CylinderMesh.new();shaft.top_radius=0.10;shaft.bottom_radius=0.16;shaft.height=6.4
		var shaft_node:=MeshInstance3D.new();shaft_node.mesh=shaft;shaft_node.position.y=3.2
		shaft_node.material_override=_metal(Color("3f4741"));pole.add_child(shaft_node)
		var arm:=MeshInstance3D.new();var arm_mesh:=BoxMesh.new();arm_mesh.size=Vector3(1.5,0.12,0.12)
		arm.mesh=arm_mesh;arm.position=Vector3(-0.7,6.3,0);arm.material_override=shaft_node.material_override
		pole.add_child(arm)
		var head:=MeshInstance3D.new();var shade:=BoxMesh.new();shade.size=Vector3(0.5,0.14,0.3)
		head.mesh=shade;head.position=Vector3(-1.4,6.2,0);head.material_override=_metal(Color("2c322e"))
		pole.add_child(head)
		if i%2==0:
			var wreck:Node3D=load("res://art/kaykit_city/car_police.gltf").instantiate()
			wreck.scale=Vector3.ONE*4.0
			_place(wreck,a-side*7.2+dir*20,atan2(-dir.x,-dir.z)+0.5)
			_burn(wreck)
			_collide_box(wreck)
		if i==2 or i==5:
			var barricade:=Node3D.new()
			for k in range(3): _box(barricade,Vector3(1.6,0.8,0.5),Vector3(k*1.7-1.7,0.4,0),Color("6a6555"))
			_place(barricade,a+side*5.6,atan2(-dir.x,-dir.z))
		# Guardrail solo dove resta fuori dall'asfalto: prima un tratto tagliava la curva.
		if i<4:
			for k in range(6):
				var post:Vector3=a+dir*(k*4.0)+side*5.2
				var tail:Vector3=post+dir*4.0
				if Route.road_distance(Vector2(post.x,post.z))<4.9 or Route.road_distance(Vector2(tail.x,tail.z))<4.9:continue
				var rail:=Node3D.new()
				_place(rail,post,atan2(-dir.x,-dir.z))
				rail.rotation.z=rng.randf_range(-0.12,0.12)
				_box(rail,Vector3(0.10,1.0,0.10),Vector3(0,0.5,0),Color("4d5148"))
				if k<5:_box(rail,Vector3(0.07,0.16,4.0),Vector3(0,0.78,2.0),Color("77796c"))

func _off_style(asset: String) -> bool:
	return asset.begins_with("CommonTree") or asset.begins_with("TwistedTree") or asset.begins_with("DeadTree")

func _mute_tree(node: Node) -> void:
	# Palette autunnale spenta: il bosco resta leggibile e non fluo.
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat = node.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				if not _mute_cache.has(mat):
					var copy: StandardMaterial3D = mat.duplicate()
					copy.albedo_color = copy.albedo_color.lerp(Color(0.20,0.36,0.17),0.80)
					_mute_cache[mat]=copy
				node.set_surface_override_material(i,_mute_cache[mat])
	for child in node.get_children():
		_mute_tree(child)

func _landmark(path:String,at:Vector3,yaw:float,scale_value:float) -> void:
	if "Tent" in path:
		var tent:Node3D=Placeholder.tent()
		add_child(tent);tent.position=Vector3(at.x,height(at.x,at.z),at.z)
		tent.rotation.y=yaw;tent.scale=Vector3.ONE*scale_value
		return
	var id:="building_B" if "Burnt" in path else "building_D"
	var node:Node3D=load("res://art/kaykit_city/"+id+".gltf").instantiate()
	add_child(node)
	node.position=Vector3(at.x,height(at.x,at.z),at.z)
	node.rotation.y=yaw
	node.scale=Vector3.ONE*4.0*scale_value
	_collide(node)

func side_node_add(node:Node3D,at:Vector3) -> void:
	add_child(node)
	var y:float=height(at.x,at.z)
	node.position=Vector3(at.x,y,at.z)

func _metal(color:Color) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.metallic=0.55;mat.roughness=0.55
	return mat

func _box(parent:Node3D,size:Vector3,at:Vector3,color:Color) -> MeshInstance3D:
	var view:=MeshInstance3D.new()
	var mesh:=BoxMesh.new();mesh.size=size
	view.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=color
	view.material_override=mat
	view.position=at
	parent.add_child(view)
	return view

func _sites() -> void:
	for i in range(1,Route.POINTS.size()):
		# Le località lontane appaiono solo quando il loro settore è caricato.
		var site:=Node3D.new();chunk(Route.POINTS[i]).add_child(site);site.position=Route.POINTS[i]
		var house:Node3D=load("res://art/kaykit_city/building_A.gltf").instantiate()
		house.scale=Vector3.ONE*4.0
		site.add_child(house);house.position=_off_road(Route.POINTS[i],44,i*0.7,20);house.rotation.y=i*0.7
		_collide(house)
		for k in range(3):
			var tent:Node3D=Placeholder.tent()
			tent.scale=Vector3.ONE*1.3
			site.add_child(tent);tent.position=_off_road(Route.POINTS[i],36,PI+k*0.45,12)
			_collide(tent)
		# Nessun cartello con il nome della località: si arriva e si guarda.

func _off_road(center:Vector3,radius:float,angle:float,clearance:float) -> Vector3:
	for attempt in range(32):
		var at:=Vector3(cos(angle+attempt*0.2)*radius,0,sin(angle+attempt*0.2)*radius)
		if Route.road_distance(Vector2(center.x+at.x,center.z+at.z))>clearance: return at
	return Vector3(0,0,radius)

func _collide_box(node:Node3D) -> void:
	# Relitti: una scatola sola al posto della mesh a triangoli (fisica e navigazione leggere).
	var box:=AABB();var first:=true
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		var local:Transform3D=node.global_transform.affine_inverse()*mesh.global_transform
		var b:AABB=local*mesh.get_aabb()
		box=b if first else box.merge(b);first=false
	if first:return
	var body:=StaticBody3D.new();node.add_child(body)
	var shape:=CollisionShape3D.new();var cube:=BoxShape3D.new();cube.size=box.size;shape.shape=cube
	shape.position=box.get_center();body.add_child(shape)

func _collide(node:Node) -> void:
	if node is MeshInstance3D: node.create_trimesh_collision()
	for child in node.get_children():
		if not child is StaticBody3D: _collide(child)
