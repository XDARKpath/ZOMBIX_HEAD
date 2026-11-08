class_name WeaponItem
extends Node3D
## Root script of every SM_Wep_*.glb (v2). Guns and blades are modelled in the socket frame
## (grip at the origin, muzzle / blade forward), so attaching is one fixed basis on the bone.
##
##   var gun := preload("res://art/env/weapons/SM_Wep_Pistol.glb").instantiate() as WeaponItem
##   add_child(gun); gun.attach_to(player, "weapon_anchor")   # ZXPlayer does this for you
##   gun.play_part("Wep_Fire")                                 # slide / pump / bolt / cylinder
##
## Sockets on SM_ZX_Player: weapon_anchor (animated, recommended), weapon_r, weapon_l, holster_r,
## katana_saya (left hip), sword_back (between the shoulders). The old Survivor rig has weapon_r/l + holster_r.

## glTF (barrel -Z, top +Y) -> bone frame (barrel +Y, top +Z)
const SOCKET_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))

const MUZZLES := {
	"SM_Wep_AssaultRifle": Vector3(0, 0.07, -0.68),
	"SM_Wep_PumpShotgun": Vector3(0, 0.066, -0.75),
	"SM_Wep_SniperRifle": Vector3(0, 0.07, -0.95),
	"SM_Wep_Revolver": Vector3(0, 0.06, -0.255),
	"SM_Wep_Pistol": Vector3(0, 0.049, -0.172),
	"SM_Wep_SMG": Vector3(0, 0.045, -0.49),
}

var _anim: AnimationPlayer


func _ready() -> void:
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer


func get_muzzle_global() -> Vector3:
	return global_transform * MUZZLES.get(String(name), Vector3(0, 0.05, -0.5))


## Plays one of the weapon's own part animations ("Wep_Fire", "Wep_Reload") from the start.
func play_part(anim_name: String) -> void:
	if _anim == null:
		_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim and _anim.has_animation(anim_name):
		_anim.stop()
		_anim.play(anim_name)


func get_magazine() -> Node3D:
	for n in find_children("*_Mag", "MeshInstance3D", true, false):
		return n
	return null


func set_magazine_visible(v: bool) -> void:
	var m := get_magazine()
	if m:
		m.visible = v


## Parent this weapon to a bone of `character` (finds its Skeleton3D).
func attach_to(character: Node, socket := "weapon_anchor") -> void:
	attach_node(self, character, socket)


static func attach_node(node: Node3D, character: Node, socket: String) -> void:
	var skel: Skeleton3D = character as Skeleton3D
	if skel == null:
		for n in character.find_children("*", "Skeleton3D", true, false):
			skel = n
			break
	if skel == null:
		push_error("WeaponItem: no Skeleton3D under %s" % character.name)
		return
	if skel.find_bone(socket) == -1 and socket == "weapon_anchor":
		socket = "weapon_r"                     # fallback for the original Survivor rig
	var ba_name := "Socket_" + socket
	var ba := skel.get_node_or_null(ba_name) as BoneAttachment3D
	if ba == null:
		ba = BoneAttachment3D.new()
		ba.name = ba_name
		ba.bone_name = socket
		skel.add_child(ba)
	if node.get_parent():
		node.get_parent().remove_child(node)
	ba.add_child(node)
	node.transform = Transform3D(SOCKET_BASIS, Vector3.ZERO)


func drop(world: Node) -> void:
	var t := global_transform
	get_parent().remove_child(self)
	world.add_child(self)
	global_transform = t
