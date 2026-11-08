extends Node3D
# Viewmodel dell'arco: braccia, arco, corda e freccia originali (art/zx_fp/SM_FP_Bow.glb, generato da
# tools/castle_kit/build_fp_bow.py). Qui si sceglie solo la clip: tendere, tenere, scoccare e incoccare seguono
# MeleeController (charge_time e attack_time); senza frecce si usano le varianti _NoArrow.

const RIG := preload("res://art/zx_fp/SM_FP_Bow.glb")
const FADE := 0.12

var player: CharacterBody3D
var rig: Node3D
var library: AnimationPlayer
var arrow_mesh: Node3D
var clock := 0.0
var _clip := ""
var _last_look := Vector2.ZERO
var _sway := Vector3.ZERO


static func handles(id: String) -> bool:
	return id == "bow"


func build(owner_player: CharacterBody3D) -> void:
	player = owner_player
	rig = RIG.instantiate()
	add_child(rig)
	library = rig.find_children("*", "AnimationPlayer", true, false)[0]
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 2
		if String(mesh.name).to_lower().begins_with("fleche"): arrow_mesh = mesh
	for loop in ["Bow_IDLE", "Bow_IDLE_NoArrow", "Bow_WALK", "Bow_WALK_NoArrow", "Bow_RUN", "Bow_RUN_NoArrow", "Bow_AIM_IDLE"]:
		if library.has_animation(loop): library.get_animation(loop).loop_mode = Animation.LOOP_LINEAR


func _len(clip: String) -> float:
	return library.get_animation(clip).length if library.has_animation(clip) else 0.5


func _play(clip: String, at := -1.0) -> void:
	if not library.has_animation(clip): return
	if clip != _clip:
		library.play(clip, FADE)
		_clip = clip
	if at >= 0.0:
		library.seek(clampf(at, 0.0, _len(clip)), true)


## Clip della posa a riposo, con o senza freccia incoccata.
func _rest_clip(base: String) -> String:
	return base + ("" if player.arrows > 0 else "_NoArrow")


func tick(delta: float, _equipped: String) -> void:
	clock += delta
	var melee = player.melee
	var nocked: bool = player.arrows > 0
	if melee.attacking and melee.attack_clip == "Bow_FIRE":
		# Scocca, poi incocca la freccia successiva (Bow_RELOAD) se ce n'è un'altra.
		if melee.attack_time < melee.BOW_FIRE:
			_play("Bow_FIRE", melee.attack_time)
		else:
			_play("Bow_RELOAD", melee.attack_time - melee.BOW_FIRE)
		nocked = melee.attack_time >= melee.BOW_FIRE + melee.BOW_RELOAD * 0.35
	elif melee.charging:
		if melee.charge_time < _len("Bow_AIM"): _play("Bow_AIM", melee.charge_time)
		else: _play("Bow_AIM_IDLE")
	elif not player.is_on_floor():
		_play(_rest_clip("Bow_FALL"))
	elif player.sprinting:
		_play(_rest_clip("Bow_RUN"))
	elif Vector2(player.velocity.x, player.velocity.z).length() > 0.6:
		_play(_rest_clip("Bow_WALK"))
	else:
		_play(_rest_clip("Bow_IDLE"))
	if arrow_mesh: arrow_mesh.visible = nocked
	_feel(delta)


func _feel(delta: float) -> void:
	# Ritardo sullo sguardo sopra la clip; mentre si mira quasi niente.
	var calm := 0.3 if player.melee.charging else 1.0
	var look := Vector2(player.rig.yaw, player.rig.pitch)
	var dlook := (look - _last_look) / maxf(delta, 0.001)
	_last_look = look
	_sway = _sway.lerp(Vector3(clampf(dlook.x * 0.004, -0.03, 0.03), clampf(-dlook.y * 0.004, -0.03, 0.03), 0) * calm, 1.0 - exp(-delta * 10.0))
	rig.position = Vector3(_sway.x, _sway.y, 0)
	rig.rotation = Vector3(_sway.y * 1.5, _sway.x * 2.0, -_sway.x * 1.5)
