class_name FPSCurvePlayer
extends Node3D
## Plays an animation_reference/curves/*.json clip on a first-person rig.
## Put this node under the Camera3D; assign `weapon` (the weapon scene root, gun/blade frame as in ZXWeapons),
## and optionally `hand_r` / `hand_l` (your FPS hand meshes, wrist at origin, fingers along -Z... any frame:
## set hand_*_offset once so the rest pose looks right). Positions are metres in camera space.
## The weapon socket frame needs the same fix-up as weapon_item.gd: SOCKET_BASIS maps Blender bone axes to Godot.

signal finished(clip: String)

const SOCKET_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))

@export var weapon: Node3D
@export var hand_r: Node3D
@export var hand_l: Node3D
@export var hand_r_offset := Transform3D.IDENTITY
@export var hand_l_offset := Transform3D.IDENTITY
@export var loop := false
@export var speed := 1.0

var clip := ""
var _data: Dictionary
var _t := 0.0
var _playing := false


func play(path: String, looping := false) -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(path))
	clip = _data.get("clip", path.get_file().get_basename())
	loop = looping
	_t = 0.0
	_playing = true


func _process(delta: float) -> void:
	if not _playing or _data.is_empty():
		return
	_t += delta * speed
	var n: int = int(_data.frames)
	var f := _t * float(_data.fps)
	if f >= n:
		if loop:
			f = fposmod(f, n)
			_t = f / float(_data.fps)
		else:
			f = n
			_playing = false
			finished.emit(clip)
	if weapon:
		weapon.transform = _sample("weapon_anchor", f) * Transform3D(SOCKET_BASIS, Vector3.ZERO)
	if hand_r:
		hand_r.transform = _sample("hand_r", f) * hand_r_offset
	if hand_l:
		hand_l.transform = _sample("hand_l", f) * hand_l_offset


func _sample(track: String, f: float) -> Transform3D:
	var keys: Array = _data.tracks[track]
	var i := clampi(int(floor(f)), 0, keys.size() - 1)
	var j := mini(i + 1, keys.size() - 1)
	var w := f - floor(f)
	var a: Dictionary = keys[i]
	var b: Dictionary = keys[j]
	var qa := Quaternion(a.q[0], a.q[1], a.q[2], a.q[3])
	var qb := Quaternion(b.q[0], b.q[1], b.q[2], b.q[3])
	var pa := Vector3(a.p[0], a.p[1], a.p[2])
	var pb := Vector3(b.p[0], b.p[1], b.p[2])
	return Transform3D(Basis(qa.slerp(qb, w)), pa.lerp(pb, w))
