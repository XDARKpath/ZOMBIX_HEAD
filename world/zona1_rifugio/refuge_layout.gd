extends RefCounted
# Zona 1 verde: strada, ufficio dello sceriffo a est, armeria a ovest.
# Non ci sono altre costruzioni: attorno ci sono solo prato e bosco.
const ROAD_X := 6.0
const WEST_X := -9.0
const EAST_X := 19.0
const YAW_WEST := PI/2
const YAW_EAST := -PI/2
const SHERIFF:=Vector3(EAST_X,0,-8)
const SHOP:=Vector3(WEST_X,0,-30)
# Punti di consegna davanti ai due portici.
# Lo sceriffo siede dietro la scrivania, con la schiena verso la parete di fondo
# (in locale x=1.15, z=2.05 dell'ufficio ruotato verso la strada).
const SHERIFF_NPC:=SHERIFF+Vector3(-2.05,0,1.15)
const SHOP_NPC:=SHOP+Vector3(1.65,0,1.9)
# I tre ricambi stanno all'aperto, dove prima c'erano casa, officina e deposito.
# Ricambi sparsi sui rami della rete stradale: bisogna girare per trovarli.
const PART_POINTS:=[Vector3(-40.0,0.05,-58.0),Vector3(60.0,0.05,-52.0),Vector3(10.0,0.05,-160.0)]
const PART_PLACES:=["BIVIO OVEST","BIVIO EST","VECCHIA PISTA"]
# Primi infetti, fuori dal recinto: i due più vicini aspettano nel prato appena oltre il portone nord.
const ENEMIES:=[Vector3(2,0,-58),Vector3(14,0,-62),Vector3(28,0,-66),Vector3(-16,0,-68),Vector3(-40,0,-72),Vector3(6,0,-186)]
# Recinto del paese: dentro ci sono sceriffo, Big Earl e il 4×4 ed è zona sicura (town_fence.gd). Il lato sud è il lago.
const FENCE_MIN:=Vector2(-22,-46)
const FENCE_MAX:=Vector2(32,16)
const GATE_WIDTH:=8.0
const WEST_GATE_Z:=-2.0
# Zona 1 allargata fino al villaggio (est) e al dungeon (ovest) di roadnet.gd.
const NAV_BOUNDS:=AABB(Vector3(-280,-3,-290),Vector3(540,26,330))
# Rovine costruite con il kit ambiente (world/zona1_rifugio/zone1_kit.gd): angolo e lato in metri.
const CABIN:=Vector3(-34,0,0)       # casa di tronchi del Vecchio, sulla riva
const FARM:=Vector3(-30,0,-122)     # fattoria in mattoni diroccata
const RUIN_SIZE:=8.0
static func occupied(x:float,z:float) -> bool:
	# I due edifici del paese e le due rovine restano ingombri: il resto è prato.
	if absf(x-SHERIFF.x)<8.6 and absf(z-SHERIFF.z)<8.6:return true
	if absf(x-SHOP.x)<8.6 and absf(z-SHOP.z)<8.6:return true
	for corner in [CABIN,FARM]:
		if x>corner.x-2.0 and x<corner.x+RUIN_SIZE+2.0 and z>corner.z-2.5 and z<corner.z+RUIN_SIZE+2.0:return true
	return false
static func safe(at:Vector3) -> bool:
	# Tutto il paese dentro il recinto è al sicuro: gli infetti non ti vedono e non ti colpiscono.
	return at.y<150.0 and at.x>FENCE_MIN.x and at.x<FENCE_MAX.x and at.z>FENCE_MIN.y and at.z<FENCE_MAX.y+6.0
## Alberi e cespugli non crescono addosso alla palizzata.
static func near_fence(x:float,z:float) -> bool:
	return x>FENCE_MIN.x-3.0 and x<FENCE_MAX.x+3.0 and z>FENCE_MIN.y-3.0 and z<FENCE_MAX.y+8.0
## I due cortili illuminati: lì l'erba è rada.
static func yard(at:Vector3) -> bool:
	var east:bool=absf(at.x-EAST_X)<7.5 and at.z>SHERIFF.z-7.0 and at.z<SHERIFF.z+6.0
	var west:bool=absf(at.x-WEST_X)<7.5 and at.z>SHOP.z-7.0 and at.z<SHOP.z+6.0
	return east or west
