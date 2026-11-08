class_name ZXNpc
extends Node3D
## NPC wrapper for SM_NPC_*.glb (same 65-bone rig as the player).
## Plays a looping idle, says one of its lines when talked to, turns to face the speaker.

const DATA := {
	"SM_NPC_Manager": {"title": "Il Dottor Ferri", "idle": "NPC_Nervous_Idle", "talk": "NPC_Merchant_Idle_Talk",
		"extra": ["NPC_Phone_Talk", "NPC_Check_Watch"],
		"lines": ["Come da mia ultima email: i morti camminano.", "Ne riparliamo quando gli zombie se ne vanno?",
			"Mi serve il settore B ripulito entro venerdì.", "Sinergia. E poi: correre."]},
	"SM_NPC_Shopkeeper": {"title": "Big Earl", "idle": "NPC_Counter_Lean", "talk": "NPC_Merchant_Idle_Talk",
		"extra": ["NPC_Show_Item"],
		"lines": ["Benvenuto da Earl. Contanti, scatolette o pezzi d'auto.", "Se lo rompi, lo compri. Se lo compri, non faccio domande.",
			"Ho una batteria sul retro. Puzza di procione morto. Funziona.", "Munizioni corsia due. Carne secca corsia uno. Priorità."]},
	"SM_NPC_Gunsmith": {"title": "L'Armaiolo", "idle": "NPC_Counter_Lean", "talk": "NPC_Merchant_Idle_Talk",
		"extra": ["NPC_Show_Item"],
		"lines": ["Portami rottami, ti porto potenza di fuoco.", "Quella canna è storta. Come la tua mira.",
			"Pulisci il fucile e lui pulirà la strada."]},
}
const LOOPING := ["Player_Idle_Unarmed", "NPC_Merchant_Idle_Talk", "NPC_Counter_Lean", "NPC_Phone_Talk", "NPC_Nervous_Idle"]

signal said(text: String)

@export_enum("SM_NPC_Manager", "SM_NPC_Shopkeeper", "SM_NPC_Gunsmith") var npc := "SM_NPC_Shopkeeper"
@export var idle_variety := true

var model: Node3D
var anim: AnimationPlayer
var _line := -1
var _face: Vector3
var _facing := false
var _next_extra := 6.0


func _ready() -> void:
	model = (load("res://art/zx_npc/%s.glb" % npc) as PackedScene).instantiate()
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for n in anim.get_animation_list():
		anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR if LOOPING.has(String(n)) else Animation.LOOP_NONE
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			var m := (mi as MeshInstance3D).mesh.surface_get_material(i) as StandardMaterial3D
			if m:
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var phone := model.find_child("Prop_Phone", true, false) as Node3D
	if phone:
		phone.visible = false
	anim.animation_finished.connect(func(_n): _play(DATA[npc].idle))
	_play(DATA[npc].idle)


func title() -> String:
	return Localization.t(DATA[npc].title)


## Next line (cycles, never repeats twice in a row). Optionally turns towards `from`.
func talk(from := Vector3.INF) -> String:
	var lines: Array = DATA[npc].lines
	_line = (_line + 1 + randi() % maxi(lines.size() - 1, 1)) % lines.size()
	if from != Vector3.INF:
		_face = from
		_facing = true
	_play(DATA[npc].talk, false)
	get_tree().create_timer(2.6).timeout.connect(func(): _play(DATA[npc].idle))
	var text: String = Localization.t(lines[_line])
	said.emit(text)
	return text


func wave() -> void:
	_play("NPC_Wave", false)


func show_item() -> void:
	if anim.has_animation("NPC_Show_Item"):
		_play("NPC_Show_Item", false)


func _play(clip: String, _loop := true) -> void:
	if anim and anim.has_animation(clip):
		anim.play(clip, 0.25)
		var phone := model.find_child("Prop_Phone", true, false) as Node3D
		if phone:
			phone.visible = clip == "NPC_Phone_Talk"


func _process(delta: float) -> void:
	if _facing:
		var d := _face - global_position
		d.y = 0
		if d.length() > 0.1:
			var goal := atan2(d.x, d.z)   # the model faces +Z after glTF import
			rotation.y = lerp_angle(rotation.y, goal, 1.0 - exp(-delta * 6.0))
			if absf(angle_difference(rotation.y, goal)) < 0.02:
				_facing = false
	if idle_variety and anim and anim.current_animation == DATA[npc].idle:
		_next_extra -= delta
		if _next_extra <= 0.0:
			_next_extra = randf_range(7.0, 14.0)
			var ex: Array = DATA[npc].extra
			_play(ex[randi() % ex.size()], false)
