extends Node
# Cosa ti hanno fatto: veleno, sanguinamento, radiazioni, stordimento, rallentamento, paura. Decide l'host: il danno nel
# tempo lo applica solo lui, i client ricevono i tempi nell'istantanea (fase3.gd) e li mostrano sull'HUD e sulla camera.

const ORDER := ["poison", "bleed", "stun", "slow", "fear"]
const INFO := {
	"poison": {"name": "VELENO", "color": Color("8fd14a"), "cure": "bende, cibo o kit medico"},
	"bleed": {"name": "EMORRAGIA", "color": Color("d0382a"), "cure": "bende o kit medico"},
	"stun": {"name": "STORDITO", "color": Color("e6d9a8"), "cure": ""},
	"slow": {"name": "AZZOPPATO", "color": Color("c98a4a"), "cure": ""},
	"fear": {"name": "TERRORE", "color": Color("a884e0"), "cure": ""},
}
const POISON_DPS := 2.4
const BLEED_DPS := 2.0
const RAD_LIMITS := [[30.0, 0.5], [60.0, 1.2], [85.0, 2.6]]

var player: CharacterBody3D
var left := {"poison": 0.0, "bleed": 0.0, "stun": 0.0, "slow": 0.0, "fear": 0.0}
var radiation := 0.0
var in_radiation := false
var _tick := 0.0


func _host() -> bool:
	return not Session.online or multiplayer.is_server()


## Riparte dalla durata più lunga tra quella che resta e quella nuova.
func add(kind: String, seconds: float) -> void:
	if left.has(kind): left[kind] = maxf(float(left[kind]), seconds)


func add_radiation(amount: float) -> void:
	radiation = clampf(radiation + amount, 0.0, 100.0)


func clear(kinds: Array) -> void:
	for kind in kinds:
		if left.has(kind): left[kind] = 0.0
		elif kind == "radiation": radiation = 0.0


func clear_all() -> void:
	for kind in left: left[kind] = 0.0
	radiation = 0.0
	in_radiation = false


func speed_factor() -> float:
	var factor := 1.0
	if float(left.stun) > 0.0: factor *= 0.35
	if float(left.slow) > 0.0: factor *= 0.6
	if float(left.poison) > 0.0: factor *= 0.92
	if radiation > 60.0: factor *= 0.85
	return factor


## Quanto deve ondeggiare la camera, da 0 a 1.
func wobble() -> float:
	var w := 0.0
	if float(left.stun) > 0.0: w = 1.0
	elif float(left.poison) > 0.0: w = 0.35
	if radiation > 60.0: w = maxf(w, 0.4)
	return w


func active() -> Array:
	var out: Array = []
	for kind in ORDER:
		if float(left[kind]) > 0.0: out.append(kind)
	return out


## Per l'istantanea di rete: tempi e radiazioni in poco spazio.
func packed() -> PackedFloat32Array:
	return PackedFloat32Array([left.poison, left.bleed, left.stun, left.slow, left.fear, radiation])


func unpack(row: PackedFloat32Array) -> void:
	if row.size() < 6: return
	for i in ORDER.size(): left[ORDER[i]] = row[i]
	radiation = row[5]


func _process(delta: float) -> void:
	if player == null or player.dead: return
	for kind in left: left[kind] = maxf(0.0, float(left[kind]) - delta)
	if float(left.fear) > 0.0: player.regen_delay = maxf(player.regen_delay, 0.3)
	if not in_radiation: radiation = maxf(0.0, radiation - delta * 1.2)
	if not _host(): return
	_tick -= delta
	if _tick > 0.0: return
	_tick = 1.0
	var damage := 0.0
	if float(left.poison) > 0.0: damage += POISON_DPS
	# Correre fa uscire più sangue.
	if float(left.bleed) > 0.0: damage += BLEED_DPS * (1.8 if player.sprinting else 1.0)
	for row in RAD_LIMITS:
		if radiation >= float(row[0]): damage = maxf(damage, damage + float(row[1]) - (0.0 if row == RAD_LIMITS[0] else float(RAD_LIMITS[RAD_LIMITS.find(row) - 1][1])))
	if damage > 0.0: player.wound(damage)
