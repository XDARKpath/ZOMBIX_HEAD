extends RefCounted
# Armi del gioco sulle definizioni di ZXWeapons (art/zx_player/zx_weapons.gd) e sulle curve FPS
# (art/animation_reference/curves). Un solo posto per: id ZX, categoria di danno, caricatore,
# clip d'attacco e finestra di colpo, così prima persona, terza persona e danno restano allineati.

const CURVES := "res://art/animation_reference/curves/"
## Id storici del gioco -> id ZXWeapons (la pala usa il piccone, l'arma a due mani più vicina).
const MAP := {"axe": "fire_axe", "knife": "combat_knife", "pistol": "pistol", "": "unarmed"}
## Fotogrammi di colpo (30 fps) dalla tabella di ANIMATION_GUIDE.md. Le altre clip usano il picco
## di velocità di weapon_anchor nella loro curva, ±2 fotogrammi.
const HITS := {"Player_Axe_Swing_Horizontal": [13, 17], "Player_Axe_Swing_Back": [12, 16], "Player_Axe_Chop_Overhead": [18, 22],
	"Player_Axe_Shove": [7, 10], "Player_Sword_Slash_1": [9, 14], "Player_Sword_Slash_2": [9, 14], "Player_Sword_Slash_3": [10, 18],
	"Player_Sword_Heavy": [14, 19], "Player_Sword_Parry_Riposte": [17, 21], "Player_Katana_Draw_Iai": [8, 12]}
## Lame che staccano la testa: ascia, spade e machete. Il coltello taglia ma non decapita.
const BLADES := ["fire_axe", "katana", "longsword", "machete", "runic_axe", "spartan_sword"]
static var _curves := {}
## Ogni arma da fuoco è un'arma diversa: danno, dispersione, gittata, pausa fra i colpi, pallini, effetto sul bersaglio, suono.
const GUNS := {
	"pistol": {"dmg": 30.0, "spread": 0.014, "reach": 55.0, "wait": 0.22, "force": 0.5, "vol": -6.0},
	"revolver": {"dmg": 62.0, "spread": 0.01, "reach": 60.0, "wait": 0.6, "force": 2.2, "vol": -4.0},
	"flare_gun": {"dmg": 14.0, "spread": 0.012, "reach": 45.0, "wait": 0.7, "force": 0.8, "fx": "burn", "vol": -7.0},
	"nailgun": {"dmg": 13.0, "spread": 0.02, "reach": 28.0, "wait": 0.1, "force": 0.2, "fx": "bleed", "vol": -12.0},
	"smg": {"dmg": 15.0, "spread": 0.03, "reach": 40.0, "wait": 0.04, "force": 0.25, "vol": -9.0},
	"assault_rifle": {"dmg": 24.0, "spread": 0.018, "reach": 70.0, "wait": 0.06, "force": 0.5, "vol": -7.0},
	"lmg": {"dmg": 22.0, "spread": 0.03, "reach": 70.0, "wait": 0.04, "force": 0.8, "vol": -7.0},
	"sniper_rifle": {"dmg": 130.0, "spread": 0.0, "reach": 160.0, "wait": 1.25, "force": 4.0, "pierce": 3, "vol": -3.0},
	"tesla_rifle": {"dmg": 18.0, "spread": 0.006, "reach": 26.0, "wait": 0.1, "force": 0.3, "fx": "chain", "chain": 3, "vol": -9.0},
	"pump_shotgun": {"dmg": 13.0, "spread": 0.07, "reach": 24.0, "wait": 0.8, "force": 1.0, "pellets": 8, "vol": -4.0},
	"sawn_off": {"dmg": 15.0, "spread": 0.13, "reach": 14.0, "wait": 0.3, "force": 1.4, "pellets": 10, "vol": -3.0},
	"lever_rifle": {"dmg": 58.0, "spread": 0.006, "reach": 90.0, "wait": 0.7, "force": 2.0, "vol": -5.0},
	"crossbow": {"dmg": 75.0, "spread": 0.0, "reach": 60.0, "wait": 1.1, "force": 1.5, "fx": "bleed", "vol": -8.0},
	"grenade_launcher": {"dmg": 95.0, "spread": 0.0, "reach": 60.0, "wait": 0.9, "force": 6.0, "fx": "blast", "radius": 4.5, "vol": -6.0},
	"leaf_blower": {"dmg": 0.0, "spread": 0.0, "reach": 10.0, "wait": 0.03, "force": 9.0, "fx": "wind", "vol": -12.0},
}
const GUN_DEFAULT := {"dmg": 30.0, "spread": 0.014, "reach": 55.0, "wait": 0.22, "force": 0.5, "vol": -6.0}

static func gun(equipped: String) -> Dictionary:
	return GUNS.get(zx_id(equipped), GUN_DEFAULT)

static func beheads(equipped: String) -> bool:
	return zx_id(equipped) in BLADES

static func zx_id(equipped: String) -> String:
	if ZXWeapons.DEFS.has(equipped): return equipped
	return MAP.get(equipped, "unarmed")

static func def(equipped: String) -> Dictionary:
	return ZXWeapons.get_def(zx_id(equipped))

static func is_gun(equipped: String) -> bool:
	var d := def(equipped)
	return d.has("fire") or d.has("fire_auto")

## "gun" (pistola: 30 di danno, 55 m), "light" (coltello: 22, 1,8 m), "heavy" (ascia: 34 / 64 caricato, 2,65 m).
static func tier(equipped: String) -> String:
	if is_gun(equipped): return "gun"
	return "light" if def(equipped).get("class", "") in ["melee1h", ""] else "heavy"

static func magazine(equipped: String) -> int:
	if equipped == "pistol": return 8          # la pistola compatta del gioco ha sempre avuto 8 colpi
	return int(def(equipped).get("mag", 8))

static func display_name(equipped: String) -> String:
	return Localization.t(str(def(equipped).get("name", equipped))).to_upper()

static func idle_clip(equipped: String) -> String:
	var d := def(equipped)
	return d.get("idle", "Player_Idle_Rifle" if d.get("class", "") == "rifle" else "Player_Idle_Unarmed")

## Clip del colpo n-esimo (combo) o del colpo caricato; per le armi da fuoco lo sparo.
static func attack_clip(equipped: String, charged: bool, variant: int) -> String:
	var d := def(equipped)
	if d.has("fire"): return d.fire
	if d.has("fire_auto"): return d.fire_auto
	if charged and d.has("heavy"): return d.heavy
	var list: Array = d.get("attacks", ["Player_Melee_Knife_Slash"])
	return list[posmod(variant, list.size())]

static func curve(clip: String) -> Dictionary:
	if not _curves.has(clip):
		var path := CURVES + clip + ".json"
		_curves[clip] = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	return _curves[clip]

## Durata della ricarica in secondi. Le armi a cartucce ("shell") ricaricano un colpo alla volta:
## qui c'è il tempo di una cartuccia. Le clip FP durano meno di una ricarica vera, per questo c'è una tabella.
const RELOAD_SECONDS := {"pistol": 1.6, "revolver": 2.8, "flare_gun": 1.8, "nailgun": 2.0, "smg": 2.1,
	"assault_rifle": 2.5, "lmg": 4.8, "sniper_rifle": 3.0, "tesla_rifle": 2.8, "sawn_off": 2.3, "leaf_blower": 2.2,
	"crossbow": 2.0, "pump_shotgun": 0.6, "lever_rifle": 0.55, "grenade_launcher": 0.9}
const SHELL_RELOAD := ["pump_shotgun", "lever_rifle", "grenade_launcher"]

## Ricarica a eventi: [frazione della ricarica, evento]. Gesto (tool_motion), colpi (player.gd) e suoni leggono
## questa tabella, così il numero sale quando il caricatore entra, non a fine clip. Una ricarica "shell" è una cartuccia.
const RELOAD_STEPS := {
	"mag": [[0.12, "mag_out"], [0.64, "mag_in"], [0.84, "slide"]],       # da vuoto: va riarmato il carrello
	"mag_tac": [[0.15, "mag_out"], [0.8, "mag_in"]],                     # tattica: c'è già un colpo in canna
	"shell": [[0.76, "shell_in"]],
	"break": [[0.1, "break_open"], [0.6, "rounds_in"], [0.8, "break_close"]],
	"cylinder": [[0.1, "cyl_open"], [0.62, "rounds_in"], [0.82, "cyl_close"]],
	"string": [[0.35, "string"], [0.72, "bolt_in"]],
}
const FILL_STEPS := ["mag_in", "shell_in", "rounds_in", "bolt_in"]
const TACTICAL := 0.8          # la tattica dura così tanto rispetto a quella da vuoto

static func reload_kind(equipped: String) -> String:
	return str(preload("res://player/tool_motion.gd").WEAPONS.get(equipped, {}).get("reload", "mag"))

## Da vuoto o tattica: la durata lo dice anche ai client, che vedono solo reload_left.
static func reload_seconds(equipped: String, dry := true) -> float:
	var full := float(RELOAD_SECONDS.get(equipped, clip_seconds(str(def(equipped).get("reload", "Player_Pistol_Reload")))))
	return full if dry or reload_kind(equipped) != "mag" else full * TACTICAL

static func reload_dry(equipped: String, total: float) -> bool:
	return total > reload_seconds(equipped, false) + 0.02

static func reload_steps(equipped: String, total: float) -> Array:
	var kind := reload_kind(equipped)
	if kind == "mag" and not reload_dry(equipped, total): kind = "mag_tac"
	return RELOAD_STEPS.get(kind, RELOAD_STEPS.mag)

## Frazione della ricarica in cui salgono i colpi.
static func reload_fill(equipped: String, total: float) -> float:
	for step in reload_steps(equipped, total):
		if step[1] in FILL_STEPS: return float(step[0])
	return 1.0

## Eventi passati fra due frazioni (from escluso, to incluso): ognuno scatta una volta sola.
static func reload_crossed(equipped: String, total: float, from: float, to: float) -> Array:
	var out := []
	for step in reload_steps(equipped, total):
		if float(step[0]) > from and float(step[0]) <= to: out.append(step[1])
	return out

static func clip_seconds(clip: String) -> float:
	var c := curve(clip)
	return (float(c.frames) - 1.0) / float(c.fps) if not c.is_empty() else 0.8

## [inizio, fine] della finestra di danno in secondi dall'inizio della clip.
static func hit_window(clip: String) -> Vector2:
	var c := curve(clip)
	if c.is_empty(): return Vector2(0.3, 0.45)
	var fps := float(c.fps)
	if HITS.has(clip): return Vector2(HITS[clip][0], HITS[clip][1]) / fps
	var keys: Array = c.tracks.weapon_anchor
	var peak := keys.size() / 2
	var fastest := 0.0
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1].p
		var b: Array = keys[i].p
		var speed := Vector3(a[0], a[1], a[2]).distance_to(Vector3(b[0], b[1], b[2]))
		if speed > fastest:
			fastest = speed
			peak = i
	return Vector2(maxi(peak - 2, 0), mini(peak + 2, keys.size() - 1)) / fps

## [carica, colpo attivo, recupero] per melee_controller: il danno parte quando la lama arriva davanti alla camera.
static func timing(equipped: String, charged: bool, variant: int) -> Array:
	if is_gun(equipped): return [0.01, 0.03, float(gun(equipped).wait)]
	var clip := attack_clip(equipped, charged, variant)
	var w := hit_window(clip)
	return [w.x, maxf(w.y - w.x, 1.0 / 30.0), maxf(clip_seconds(clip) - w.y, 0.05)]
