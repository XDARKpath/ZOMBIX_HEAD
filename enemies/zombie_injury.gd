extends RefCounted
# Lesioni per parte del corpo degli infetti. zombie_target.gd tiene stato e danno di ogni parte, qui stanno le regole:
# quale arma fa cosa, a quale parte, con quanta forza, su chi. Un calo di vita non è una lesione: qui si decide solo
# lo stato dell'arto (ferito, menomato, fratturato, staccato) e da quello dipende il comportamento.

const Arsenal = preload("res://weapons/zx_arsenal.gd")

const HEALTHY := 0
const WOUNDED := 1
const MAIMED := 2
const FRACTURED := 3
const SEVERED := 4

## Parti fini, nell'ordine del pacchetto di rete (world/zona1_rifugio/fase3.gd).
const PARTS := ["head", "neck", "chest", "pelvis", "upperarm_l", "upperarm_r", "forearm_l", "forearm_r", "hand_l", "hand_r",
	"thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r"]
## Da chi pende ogni parte: se manca il padre manca anche il figlio.
const PARENT := {"forearm_l": "upperarm_l", "forearm_r": "upperarm_r", "hand_l": "forearm_l", "hand_r": "forearm_r",
	"calf_l": "thigh_l", "calf_r": "thigh_r", "foot_l": "calf_l", "foot_r": "calf_r"}
## Osso degli infetti per ogni parte, senza lato (l'avambraccio nello scheletro si chiama lowerarm).
const BONE := {"head": "head", "neck": "neck_01", "chest": "spine_02", "pelvis": "pelvis", "upperarm": "upperarm",
	"forearm": "lowerarm", "hand": "hand", "thigh": "thigh", "calf": "calf", "foot": "foot"}

## La matrice. Per categoria d'arma, il danno accumulato sulla parte che serve per ogni stato
## [sano, ferito, menomato, fratturato, staccato]; 0 = quell'arma non ci arriva mai.
## "min" è la forza del singolo colpo che serve per fratturare o staccare: tanti colpetti feriscono e menomano, non spezzano.
const MATRIX := {
	"blade": {"at": [0.0, 1.0, 15.0, 0.0, 45.0], "min": 35.0},    # lame: tagliano e staccano, non fratturano
	"blunt": {"at": [0.0, 1.0, 14.0, 30.0, 0.0], "min": 22.0},    # contundenti: fratturano, non staccano
	"bullet": {"at": [0.0, 1.0, 18.0, 70.0, 0.0], "min": 55.0},   # proiettili: lesione dove colpiscono, mai un distacco
	"blast": {"at": [0.0, 1.0, 18.0, 45.0, 80.0], "min": 60.0},   # esplosivi: tutto il corpo, ma un arto solo al massimo
}
## Quanto regge ogni zona (moltiplica soglie e "min") e lo stato più grave che può avere.
## La testa si stacca con la decapitazione di zombie_target.gd, non da qui.
const ZONE := {"head": [1.0, MAIMED], "neck": [1.0, MAIMED], "chest": [1.0, MAIMED], "pelvis": [1.0, MAIMED],
	"upperarm": [1.6, SEVERED], "forearm": [1.0, SEVERED], "hand": [0.6, SEVERED],
	"thigh": [1.6, SEVERED], "calf": [1.0, SEVERED], "foot": [0.7, SEVERED]}
## Protezione per tipo di infetto: [moltiplicatore delle soglie, stato più grave]. Il bruto regge di più; il boss
## (tipo 5) si ferisce ma non perde pezzi e non si spezza: le sue lotte restano quelle di bosses/.
const PROTECTION := {2: [1.6, SEVERED], 5: [1.0, WOUNDED]}
## Stato dell'arto: uno già menomato o fratturato cede prima (moltiplica le soglie degli stati successivi).
const WEAKENED := [1.0, 1.0, 0.85, 0.6, 1.0]
## Quanto dell'esplosione arriva agli altri arti (solo ferite e menomazioni).
const BLAST_SPREAD := 0.35
## Il coltello taglia, ma con meno forza di ascia e spade.
const KNIFE := 0.6
## Zoppia per lo stato peggiore di una gamba (coscia, polpaccio, piede).
const LIMP := [1.0, 0.9, 0.7, 0.5, 0.4]


static func category(weapon: String) -> String:
	if weapon == "fire": return ""      # il fuoco brucia la vita, non spezza ossa
	if weapon == "grenade" or Arsenal.gun(weapon).get("fx", "") == "blast": return "blast"
	if Arsenal.beheads(weapon) or Arsenal.zx_id(weapon) == "combat_knife": return "blade"
	if weapon in ["bow", "arrow"] or Arsenal.is_gun(weapon): return "bullet"
	return "blunt"


static func intensity(weapon: String, amount: float, heavy: bool) -> float:
	return amount * (1.5 if heavy else 1.0) * (KNIFE if Arsenal.zx_id(weapon) == "combat_knife" else 1.0)


static func side(part: String) -> String:
	return part.right(1) if part.ends_with("_l") or part.ends_with("_r") else ""


static func base(part: String) -> String:
	return part.left(-2) if side(part) != "" else part


static func bone(part: String) -> String:
	var name: String = BONE.get(base(part), "")
	return name + "_" + side(part) if side(part) != "" else name


static func missing(parts: Dictionary, part: String) -> bool:
	while part != "":
		if int(parts.get(part, 0)) >= SEVERED: return true
		part = PARENT.get(part, "")
	return false


## Vero se `part` pende (anche alla lontana) da `ancestor`: la mano dal braccio, il piede dalla coscia.
static func hangs_from(part: String, ancestor: String) -> bool:
	while part != "":
		part = PARENT.get(part, "")
		if part == ancestor: return true
	return false


static func state(parts: Dictionary, part: String) -> int:
	return SEVERED if missing(parts, part) else int(parts.get(part, 0))


## Il colpo: aggiorna danno e stato in `parts` e `damage` (della vittima). Ritorna le parti appena staccate.
static func hit(parts: Dictionary, damage: Dictionary, part: String, weapon: String, amount: float, heavy: bool, kind: int) -> Array:
	var cat := category(weapon)
	var cut := []
	if cat == "" or amount <= 0.0 or not ZONE.has(base(part)): return cut
	var force := intensity(weapon, amount, heavy)
	if cat == "blast":
		# Impulso ampio ma limitato: tutti gli arti si feriscono, uno solo prende il colpo pieno.
		var main := part if ZONE[base(part)][1] == SEVERED else _blast_target(parts)
		for p in PARTS:
			if p != main and not missing(parts, p): _raise(parts, damage, p, cat, force * BLAST_SPREAD, kind, MAIMED, cut)
		part = main
	if part != "" and not missing(parts, part): _raise(parts, damage, part, cat, force, kind, SEVERED, cut)
	return cut


static func _blast_target(parts: Dictionary) -> String:
	var options := ["hand_l", "hand_r", "foot_l", "foot_r", "forearm_l", "forearm_r", "calf_l", "calf_r"].filter(func(p): return not missing(parts, p))
	return options[randi() % options.size()] if not options.is_empty() else ""


static func _raise(parts: Dictionary, damage: Dictionary, part: String, cat: String, force: float, kind: int, cap: int, cut: Array) -> void:
	var row: Array = MATRIX[cat].at
	var zone: Array = ZONE[base(part)]
	var guard: Array = PROTECTION.get(kind, [1.0, SEVERED])
	var limit: int = mini(cap, mini(zone[1], guard[1]))
	damage[part] = float(damage.get(part, 0.0)) + force
	var now := int(parts.get(part, 0))
	var toughness: float = float(zone[0]) * float(guard[0])
	var best := now
	for s in range(now + 1, limit + 1):
		if row[s] <= 0.0 or damage[part] < row[s] * toughness * WEAKENED[now]: continue
		if s >= FRACTURED and force < float(MATRIX[cat].min) * toughness: continue
		best = s
	if best > now:
		parts[part] = best
		if best == SEVERED: cut.append(part)


## Mano, avambraccio o braccio rotti o staccati: da quel lato niente manata.
static func can_strike(parts: Dictionary, which: String) -> bool:
	for b in ["upperarm_", "forearm_", "hand_"]:
		if state(parts, b + which) >= FRACTURED: return false
	return true


## Velocità rispetto al sano (0.35..1): la gamba peggiore comanda, due gambe ferite rallentano ancora.
static func move_factor(parts: Dictionary) -> float:
	var legs := []
	for which in ["l", "r"]:
		var worst := 0
		for b in ["thigh_", "calf_", "foot_"]: worst = maxi(worst, state(parts, b + which))
		legs.append(LIMP[worst])
	return clampf(minf(legs[0], legs[1]) * (0.9 if legs[0] < 1.0 and legs[1] < 1.0 else 1.0), 0.35, 1.0)


## Gamba staccata (dal polpaccio in su) o entrambe fratturate: non sta più in piedi.
static func must_crawl(parts: Dictionary) -> bool:
	var broken := 0
	for which in ["l", "r"]:
		if missing(parts, "calf_" + which): return true
		if int(parts.get("thigh_" + which, 0)) == FRACTURED or int(parts.get("calf_" + which, 0)) == FRACTURED: broken += 1
	return broken == 2


static func pack(parts: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	for p in PARTS: out.append(int(parts.get(p, 0)))
	return out


static func unpack(bytes: PackedByteArray) -> Dictionary:
	var out := {}
	for i in mini(bytes.size(), PARTS.size()):
		if bytes[i] > 0: out[PARTS[i]] = int(bytes[i])
	return out
