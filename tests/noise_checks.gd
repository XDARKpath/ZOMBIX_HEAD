extends SceneTree
# Rumore delle armi (world/campaign/zone1_life.gd): raggio per categoria, zombie dentro sente, fuori no,
# nessuna arma senza categoria, impatti dei proiettili non contati due volte.
const Life := preload("res://world/campaign/zone1_life.gd")
const Arsenal := preload("res://weapons/zx_arsenal.gd")
const SAMPLES := {"unarmed": "", "melee_light": "knife", "melee_heavy": "axe", "bow": "bow", "pistol": "pistol",
	"rifle": "pump_shotgun", "automatic": "assault_rifle", "explosive": "grenade_launcher"}
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run():
	var world: Node3D = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.5).timeout
	var life = world.zone_life
	var p = world.player
	p.set_physics_process(false)
	p.global_position = Vector3(6, 0.5, -70)   # fuori dal recinto: dentro gli infetti non inseguono
	var near = world._spawn_enemy(p.position + Vector3(0, 0, -5))
	var far = world._spawn_enemy(p.position + Vector3(0, 0, -8))
	await create_timer(0.1).timeout
	for z in [near, far]:
		z.set_physics_process(false)
		z.set_process(false)
	# Ogni arma del registro ha una categoria; nessuna arma da fuoco sotto la pistola se non è un'eccezione scritta.
	for id in ZXWeapons.DEFS:
		if ZXWeapons.DEFS[id].get("class", "") == "consumable": continue
		var r: float = Life.weapon_noise(id)
		print("  %-18s %-12s %5.1f m" % [id, Life.noise_class(id), r])
		if Arsenal.is_gun(id) and not Life.NOISE_EXCEPTIONS.has(id):
			check(r >= 45.0, "%s: arma da fuoco udibile ad almeno 45 m" % id)
	for id in Life.NOISE_EXCEPTIONS: check(ZXWeapons.DEFS.has(id), "Eccezione %s è un'arma vera" % id)
	# Per categoria: zombie a 0,8 del raggio sente, a 1,2 del raggio no.
	for kind in SAMPLES:
		var weapon: String = SAMPLES[kind]
		var radius: float = Life.weapon_noise(weapon)
		check(Life.noise_class(weapon) == kind and is_equal_approx(radius, Life.NOISE[kind]["swing"]), "%s (%s): %.0f m" % [kind, weapon, radius])
		_place(p, near, radius * 0.8)
		_place(p, far, radius * 1.2)
		p.equipped = weapon
		p.melee.attack_clip = ""
		life.attack_noise(p)
		check(near.state == near.State.CHASE and far.state == far.State.WANDER, "%s: sente a %.1f m, non a %.1f m" % [kind, radius * 0.8, radius * 1.2])
	# Calcio con la pistola in mano: rumore da calcio, non da sparo.
	p.equipped = "pistol"
	p.melee.attack_clip = "Kick"
	_place(p, near, 10.0)
	_place(p, far, 12.0)
	life.attack_noise(p)
	check(near.state == near.State.WANDER, "Calcio con la pistola in mano non suona come uno sparo")
	# Impatti: corpo a corpo sì, proiettili no (lo sparo è già stato emesso).
	p.melee.attack_clip = ""
	p.equipped = "axe"
	_place(p, near, 14.0)
	life.impact_noise(p)
	check(near.state == near.State.CHASE, "Impatto d'ascia sentito a 14 m")
	p.equipped = "knife"
	_place(p, near, 10.0)
	life.impact_noise(p)
	check(near.state == near.State.WANDER, "Impatto di coltello non sentito a 10 m")
	p.equipped = "pump_shotgun"
	_place(p, near, 3.0)
	life.noise_level = 0.0
	life.impact_noise(p)
	check(near.state == near.State.WANDER and life.noise_level == 0.0, "Pallini a segno: nessun secondo rumore oltre allo sparo")
	print("NOISE %s (%d errori)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit()

func _place(p: Node3D, z: Node3D, distance: float) -> void:
	z.global_position = p.global_position + Vector3(0, 0, -distance)
	z.state = z.State.WANDER
	z.target = null
