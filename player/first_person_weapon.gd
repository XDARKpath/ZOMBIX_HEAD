extends Node3D
# Viewmodel FPS sulle curve del pacchetto 0.14 (art/animation_reference/curves, una per clip dello
# ZX Player): l'arma segue weapon_anchor nello spazio della camera e le mani SM_FP_Arms raggiungono
# con l'IK (player/viewmodel/fp_hands.gd) hand_r e hand_l della stessa curva, espresse rispetto
# all'arma, così ascia e katana restano in due mani in ogni fotogramma. Sopra la curva ci sono solo
# piccoli offset: passo, cambio arma, PDA e dialogo. Il tempo dei colpi è melee.attack_time, quindi
# la finestra di danno (weapons/zx_arsenal.gd) cade sui fotogrammi di colpo della clip.
# Armi e oggetti usano le braccia v3 di art/zx_fp/SM_FP_Arms.glb (viewmodel/fp_arms.gd), l'arco il suo kit (viewmodel/fp_bow.gd).
# Le curve restano solo per PDA e dialogo, dove le mani devono tenere il dispositivo o appoggiarsi al bancone.
const Hands := preload("res://player/viewmodel/fp_hands.gd")
const Pda := preload("res://player/viewmodel/pda.gd")
const Arsenal := preload("res://weapons/zx_arsenal.gd")
const FpArms := preload("res://player/viewmodel/fp_arms.gd")
const Bow := preload("res://player/viewmodel/fp_bow.gd")
var bow_vm: Node3D
signal released(kind: String, weapon_id: String)
var arms_vm: Node3D
const SOCKET_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
const SWITCH_TIME := 0.15
const ADS_TIME := 0.15
const FADE := 0.12
## Inquadratura del viewmodel: le curve hanno la camera sugli occhi del personaggio e lasciano arma e
## mani sotto il bordo dello schermo. Uno spostamento rigido unico (arma e mani insieme) le porta in
## vista senza cambiare il movimento né la presa.
const FRAMING := {"axe": Vector3(-0.02, 0.27, -0.22), "sword": Vector3(-0.02, 0.27, -0.22), "melee1h": Vector3(-0.02, 0.24, -0.24),
	"pistol": Vector3(0.0, 0.22, -0.26), "rifle": Vector3(0.03, 0.25, -0.24), "": Vector3(0.0, 0.24, -0.22)}
var framing := Vector3.ZERO
## Mira della pistola: l'arma allineata alla camera, tacca di mira al centro.
const PISTOL_ADS := Vector3(0.0, -0.105, -0.40)
var player: CharacterBody3D
var world: Node3D
var hands := Hands.new()
var arms: Node3D
var anchor: Node3D
var item: Node3D
var weapon := ""
var shown_weapon := ""
var lamp: SpotLight3D
var flash: OmniLight3D
var pda: Node3D
var gps: Control
# Clip in corso e dissolvenza dalla precedente.
var clip := ""
var clip_time := 0.0
var clip_loop := true
var prev_clip := ""
var prev_time := 0.0
var fade := 1.0
var action := ""            # clip una tantum (colpo, sparo, ricarica): ha la precedenza sul loop
var action_time := 0.0
var blocking := false
# Stati interpolati (0..1)
var ads := 0.0
var lower := 0.0          # cambio arma: 1 = arma fuori campo
var switch_left := 0.0
var pda_up := 0.0
var talk := 0.0
var reach := 0.0
var flash_left := 0.0
var clock := 0.0
var force_ads := false   # solo per le acquisizioni automatiche


func build(owner_world: Node3D) -> void:
	world = owner_world
	player = world.player
	reparent(player.rig.camera)
	transform = Transform3D.IDENTITY
	arms = load("res://art/fp_arms/SM_FP_Arms.glb").instantiate()
	add_child(arms)
	_materials()
	hands.setup(arms)
	anchor = Node3D.new()
	add_child(anchor)
	pda = Pda.new()
	add_child(pda)
	gps = world.get_node("Interface").find_child("RouteGPS", true, false)
	if gps: pda.build(gps)
	pda.visible = false
	flash = OmniLight3D.new()
	flash.light_color = Color("ffd594")
	flash.omni_range = 3
	add_child(flash)
	lamp = SpotLight3D.new()
	lamp.rotation.y = PI
	lamp.spot_range = 24
	lamp.spot_angle = 33
	lamp.light_energy = 1.5
	lamp.visible = false
	add_child(lamp)
	player.melee.attack_started.connect(_on_attack)
	arms_vm = FpArms.new()
	arms_vm.name = "FpArms"
	add_child(arms_vm)
	arms_vm.build(player)
	arms_vm.visible = false
	arms_vm.released.connect(func(kind: String, id: String) -> void: released.emit(kind, id))
	bow_vm = Bow.new()
	bow_vm.name = "FpBow"
	add_child(bow_vm)
	bow_vm.build(player)
	bow_vm.visible = false


func _materials() -> void:
	# Flat shading con luce di contorno ambrata sulle sagome di dita e maniche.
	# Stessi colori delle braccia v3 (art/zx_fp/SM_FP_Arms.glb): una sola giacca e un solo paio di guanti.
	var palette := {"FP_Skin": Color("d9a483"), "FP_Glove": Color("8d8a62"), "FP_GlovePad": Color("6e6b4a"),
		"FP_Sleeve": Color("6b7345"), "FP_SleeveDark": Color("565d38"), "FP_Cuff": Color("8d8a62")}
	for mesh in arms.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 2
		for s in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(s)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = palette.get(source.resource_name if source else "", Color.GRAY)
			mat.roughness = 0.9
			mat.rim_enabled = true
			mat.rim = 0.35
			mat.rim_tint = 0.75
			mesh.set_surface_override_material(s, mat)


## [Q], consegna, [F], uso degli oggetti e interazioni: li fanno le braccia v3 (l'arco non ha queste clip).
func throw_held() -> bool: return arms_vm.visible and arms_vm.throw_held()
func give_held() -> bool: return arms_vm.visible and arms_vm.give_held()
func throwing() -> bool: return arms_vm.throwing()
func inspect() -> void: arms_vm.inspect()
func inspecting() -> bool: return arms_vm.inspecting()
func use_item() -> bool: return arms_vm.visible and arms_vm.use_item()
func using_item() -> bool: return arms_vm.using_item()
func play_interact(clip: String, held := "") -> void: arms_vm.play_interact(clip, held)
func interacting() -> bool: return arms_vm.interacting()


func _unhandled_input(event: InputEvent) -> void:
	if not world.started or world.ui_open: return
	if event.is_action_pressed("lamp"): lamp.visible = not lamp.visible
	elif event.is_action_pressed("inspect"): arms_vm.inspect()
	elif event.is_action_pressed("interact"): arms_vm.play_interact("Interact_Pickup")


func _on_attack(charged: bool) -> void:
	# Combo e colpo pesante come in terza persona: stessa clip, stesso indice di melee_controller.
	action = Arsenal.attack_clip(weapon, charged, player.melee.attack_variant)
	action_time = 0.0
	if Arsenal.is_gun(weapon):
		flash_left = 0.06
		if item and item.has_method("play_part"): item.play_part("Wep_Fire")


func _process(delta: float) -> void:
	if not player: return
	var talking: bool = world.ui_open and world.get("survival") != null and (world.survival.dialogue_open or world.survival.shop_open)
	visible = world.started and not player.seated and not player.dead and (not world.ui_open or talking)
	if not visible: return
	clock += delta
	_states(delta, talking)
	if weapon != player.equipped and switch_left <= 0.0:
		weapon = player.equipped
		AudioManager.weapon_equip(weapon)
		switch_left = SWITCH_TIME * 2.0
	if switch_left > 0.0:
		switch_left = maxf(0.0, switch_left - delta)
		lower = clampf((SWITCH_TIME * 2.0 - switch_left) / SWITCH_TIME, 0.0, 1.0) if switch_left > SWITCH_TIME else switch_left / SWITCH_TIME
		if switch_left <= SWITCH_TIME and shown_weapon != weapon: _swap_item()
	else:
		lower = 0.0
	# PDA e dialogo restano sulle braccia del viewmodel a curve, che sanno tenere il dispositivo e appoggiarsi al
	# bancone. Slot vuoto: mani vuote, niente braccia in vista.
	var free: bool = pda_up <= 0.0 and talk <= 0.0
	var arms_mode: bool = FpArms.handles(player.equipped) and free
	var bow_mode: bool = Bow.handles(player.equipped) and free
	arms_vm.visible = arms_mode
	bow_vm.visible = bow_mode
	arms.visible = not free
	anchor.visible = not free
	if bow_mode:
		bow_vm.tick(delta, player.equipped)
		return
	if arms_mode:
		arms_vm.tick(delta, player.equipped)
		flash.light_energy = 3.5 if Arsenal.is_gun(player.equipped) and player.melee.attacking and player.melee.attack_time < 0.06 else 0.0
		return
	if not item: return
	_choose_clip(delta)
	var raw := _sample_blend("weapon_anchor")
	var final := _offsets() * raw
	if Arsenal.is_gun(weapon) and weapon in ["pistol", "revolver", "flare_gun", "nailgun", "smg"]:
		var a := _smooth(ads)
		final = final.interpolate_with(Transform3D(Basis.IDENTITY, PISTOL_ADS), a)
	anchor.transform = final * Transform3D(SOCKET_BASIS, Vector3.ZERO)
	_hands_pose(raw, final)
	hands.apply()
	if gps and pda.visible: pda.refresh()
	flash.global_position = item.global_position
	flash_left = maxf(0.0, flash_left - delta)
	flash.light_energy = 2.5 if flash_left > 0.0 else 0.0


func _swap_item() -> void:
	if item: item.queue_free()
	shown_weapon = weapon
	var d := Arsenal.def(weapon)
	framing = FRAMING.get(d.get("class", ""), FRAMING[""])
	if d.get("scene", "") != "":
		item = (load(d.scene) as PackedScene).instantiate()
	else:
		item = Node3D.new()      # a mani nude
	anchor.add_child(item)
	for mesh in item.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	action = ""
	clip = ""


func _states(delta: float, talking: bool) -> void:
	var gun := Arsenal.is_gun(weapon)
	var aiming: bool = gun and (force_ads or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and not player.sprinting and player.reload_left <= 0 and not world.ui_open
	ads = move_toward(ads, 1.0 if aiming else 0.0, delta / ADS_TIME)
	# Tasto destro con un'arma da mischia: parata (Axe_Block / Sword_Block) se l'arma ce l'ha.
	blocking = not gun and Arsenal.def(weapon).has("block") and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not world.ui_open and not player.melee.attacking
	pda_up = move_toward(pda_up, 1.0 if gps and gps.opened and not world.ui_open else 0.0, delta / 0.25)
	talk = move_toward(talk, 1.0 if talking else 0.0, delta / 0.35)
	reach = move_toward(reach, 0.0, delta / 0.45)
	pda.visible = pda_up > 0.0
	player.rig.focus_lean = _smooth(talk)


func _choose_clip(delta: float) -> void:
	var d := Arsenal.def(weapon)
	var melee: Node3D = player.melee
	# Colpi: il tempo è quello di melee_controller, così danno e lama coincidono.
	if action != "" and not Arsenal.is_gun(weapon) and melee.attacking:
		action_time = melee.attack_time
	elif action != "":
		action_time += delta
	if action != "" and action_time >= Arsenal.clip_seconds(action):
		action = ""
	# Ricarica: la clip copre tutta la durata della ricarica.
	if player.reload_left > 0 and d.has("reload"):
		var total: float = 1.6 if weapon == "pistol" else Arsenal.clip_seconds(d.reload)
		_set_clip(d.reload, false)
		clip_time = clampf((total - player.reload_left) / total, 0.0, 1.0) * Arsenal.clip_seconds(d.reload)
	elif action != "":
		_set_clip(action, false)
		clip_time = action_time
	elif melee.charging and d.has("heavy"):
		# Colpo caricato: l'arma sale lungo la carica del colpo pesante, poi parte al rilascio.
		_set_clip(d.heavy, false)
		clip_time = Arsenal.hit_window(d.heavy).x * 0.6 * melee.charge_fraction()
	elif blocking:
		_set_clip(d.block, true)
		clip_time += delta
	elif ads > 0.5 and d.has("aim"):
		_set_clip(d.aim, Arsenal.curve(d.aim).get("frames", 2) > 20)
		clip_time += delta
	else:
		_set_clip(Arsenal.idle_clip(weapon), true)
		clip_time += delta
	prev_time += delta
	fade = minf(1.0, fade + delta / FADE)


func _set_clip(name: String, looping: bool) -> void:
	if name == clip: return
	prev_clip = clip
	prev_time = clip_time
	fade = 0.0 if clip != "" else 1.0
	clip = name
	clip_loop = looping
	clip_time = 0.0


func _sample(name: String, time: float, looping: bool, track: String) -> Transform3D:
	var c := Arsenal.curve(name)
	if c.is_empty(): return Transform3D(Basis.IDENTITY, Vector3(0.2, -0.3, -0.4))
	var keys: Array = c.tracks[track]
	var n := keys.size()
	var f := time * float(c.fps)
	f = fposmod(f, float(n - 1)) if looping else clampf(f, 0.0, float(n - 1))
	var i := int(floor(f))
	var j := mini(i + 1, n - 1)
	var w := f - float(i)
	var a: Dictionary = keys[i]
	var b: Dictionary = keys[j]
	var qa := Quaternion(a.q[0], a.q[1], a.q[2], a.q[3])
	var qb := Quaternion(b.q[0], b.q[1], b.q[2], b.q[3])
	return Transform3D(Basis(qa.slerp(qb, w)), Vector3(a.p[0], a.p[1], a.p[2]).lerp(Vector3(b.p[0], b.p[1], b.p[2]), w) + framing)


func _sample_blend(track: String) -> Transform3D:
	var now := _sample(clip, clip_time, clip_loop, track)
	if fade >= 1.0 or prev_clip == "": return now
	return _sample(prev_clip, prev_time, true, track).interpolate_with(now, _smooth(fade))


func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _euler(deg: Vector3) -> Basis:
	return Basis.from_euler(deg * (PI / 180.0))


func _offsets() -> Transform3D:
	# Piccoli offset sopra la curva, mai una posa al suo posto.
	var rot := Vector3.ZERO
	var at := Vector3.ZERO
	# Cambio arma: l'arma esce dal basso e rientra.
	var l := _smooth(lower)
	rot += Vector3(-40, 0, 10) * l
	at += Vector3(0.0, -0.30, 0.08) * l
	# PDA e dialogo: l'arma scende per lasciare spazio alla mano sinistra.
	var away := maxf(_smooth(pda_up) * 0.75, _smooth(talk))
	rot += Vector3(-30, 15, 8) * away
	at += Vector3(0.04, -0.20, 0.08) * away
	# Passo: piccolo dondolio della camminata, ridotto in mira.
	var walking: float = clampf(Vector2(player.velocity.x, player.velocity.z).length() / 3.2, 0.0, 1.0)
	var c: float = player.rig.bob_clock
	var amp: float = (1.0 + (0.8 if player.sprinting else 0.0)) * (1.0 - ads * 0.85)
	at += Vector3(cos(c) * 0.008, -absf(sin(c)) * 0.010, 0.0) * walking * amp
	rot += Vector3(sin(c * 2.0) * 0.8, cos(c) * 1.0, cos(c) * 1.5) * walking * amp
	return Transform3D(_euler(rot), at)


func _hand_basis(fingers: Vector3, back: Vector3) -> Basis:
	var y := fingers.normalized()
	var z := (back - y * back.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


func _local(xf: Transform3D) -> Transform3D:
	return global_transform * xf


func _hands_pose(raw: Transform3D, final: Transform3D) -> void:
	# Mani della curva, rispetto all'arma: seguono anche gli offset e la mira.
	var to_weapon := raw.affine_inverse()
	var right := _local(final * to_weapon * _sample_blend("hand_r"))
	var left := _local(final * to_weapon * _sample_blend("hand_l"))
	var closure := 1.0 - _smooth(lower) * 0.85
	var gun := Arsenal.is_gun(weapon)
	hands.free_hand("r", right, "pistol" if gun else "power")
	hands.hands["r"]["closure"] = closure
	hands.hands["r"]["trigger"] = 1.0 if flash_left > 0.0 else 0.0
	hands.free_hand("l", left, "power")
	hands.hands["l"]["closure"] = closure
	_hands_overlays()


func _hands_overlays() -> void:
	# Interazione (E): la sinistra si allunga in avanti.
	if reach > 0.0:
		var t := sin(reach * PI)
		var wrist := _local(Transform3D(_hand_basis(Vector3(0, 0.05, -1), Vector3(0, 1, 0.1)), Vector3(-0.08, -0.12, -0.56)))
		hands.blend_target("l", wrist, t)
		hands.hands["l"]["profile"] = "open" if reach > 0.5 else "pinch"
	# PDA: la sinistra porta il dispositivo in vista, pollice sulla cornice.
	if pda_up > 0.0:
		var p := _smooth(pda_up)
		pda.transform = Transform3D(_euler(Vector3(14, 10, -4)), Vector3(-0.085, -0.075, -0.30)).interpolate_with(
			Transform3D(_euler(Vector3(60, 30, 0)), Vector3(-0.15, -0.42, -0.24)), 1.0 - p)
		hands.grip("l", pda.get_node("Socket_LeftHand"))
	# Dialogo: entrambe le mani appoggiate al bancone, la destra accompagna le frasi.
	if talk > 0.0:
		var t := _smooth(talk)
		var gesture := maxf(0.0, sin(clock * 1.7)) * 0.5
		var rh := _local(Transform3D(_hand_basis(Vector3(-0.15, -0.30 + gesture * 0.5, -1), Vector3(0.15 - gesture * 0.8, 1, 0)), Vector3(0.15, -0.25 + gesture * 0.05, -0.44)))
		var lh := _local(Transform3D(_hand_basis(Vector3(0.18, -0.30, -1), Vector3(-0.1, 1, 0)), Vector3(-0.16, -0.26, -0.46)))
		hands.blend_target("r", rh, t)
		hands.blend_target("l", lh, t)
		if t > 0.5:
			hands.hands["r"]["profile"] = "open" if gesture > 0.2 else "flat"
			hands.hands["l"]["profile"] = "flat"
		item.visible = t < 0.6
	else:
		item.visible = true
