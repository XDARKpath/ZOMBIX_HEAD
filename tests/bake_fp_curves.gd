extends SceneTree
# Curve FPS dalle clip dello ZX Player (stesso metodo di source/scripts/anim_ref.py): per ogni fotogramma
# weapon_anchor, hand_r, hand_l, lowerarm_r, lowerarm_l nello spazio della camera attaccata all'osso head.
# Con --check confronta il risultato con le curve del pacchetto 0.14 e stampa lo scarto.
const OUT := "res://art/animation_reference/curves/"
const TRACKS := ["weapon_anchor", "hand_r", "hand_l", "lowerarm_r", "lowerarm_l"]

func _initialize() -> void:
	var player: Node3D = load("res://art/zx_player/SM_ZX_Player.glb").instantiate()
	player.build_animation_tree = false
	player.start_weapon = ""
	root.add_child(player)
	var ap: AnimationPlayer = player.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = player.find_children("*", "Skeleton3D", true, false)[0]
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT + "Player_Axe_Swing_Horizontal.json"))
	var m: Array = ref.camera_from_head
	var cam_from_head := Transform3D(Basis(Vector3(m[0][0], m[1][0], m[2][0]), Vector3(m[0][1], m[1][1], m[2][1]), Vector3(m[0][2], m[1][2], m[2][2])), Vector3(m[0][3], m[1][3], m[2][3]))
	var check := "--check" in OS.get_cmdline_user_args()
	var clips: Array = []
	if check: clips = ["Player_Axe_Swing_Horizontal", "Player_Sword_Slash_1"]
	else:
		clips.append("Player_Idle_Rifle")      # i fucili non hanno "idle" in ZXWeapons: usano questa
		for d in ZXWeapons.DEFS.values():
			for key in ["idle", "aim", "fire", "fire_auto", "reload", "heavy", "block", "parry", "dodge", "shove", "draw", "sheathe"]:
				if d.has(key) and not d[key] in clips: clips.append(d[key])
			for a in d.get("attacks", []):
				if not a in clips: clips.append(a)
	var index := {}
	for clip in clips:
		if not ap.has_animation(clip):
			print("MANCA ", clip); continue
		var anim := ap.get_animation(clip)
		var frames := int(round(anim.length * 30.0))
		var tracks := {}
		for t in TRACKS: tracks[t] = []
		for f in frames + 1:
			_sample(anim, sk, minf(f / 30.0, anim.length))
			var cam: Transform3D = _global(sk, sk.find_bone("head")) * cam_from_head
			for t in TRACKS:
				var x: Transform3D = cam.affine_inverse() * _global(sk, sk.find_bone(t))
				var q := x.basis.get_rotation_quaternion()
				tracks[t].append({"f": f, "p": [snappedf(x.origin.x, 0.0001), snappedf(x.origin.y, 0.0001), snappedf(x.origin.z, 0.0001)],
					"q": [snappedf(q.x, 0.00001), snappedf(q.y, 0.00001), snappedf(q.z, 0.00001), snappedf(q.w, 0.00001)]})
		if check:
			var theirs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT + clip + ".json"))
			var worst := 0.0
			var worst_q := 0.0
			for t in ["weapon_anchor", "hand_r", "hand_l"]:
				for f in mini(tracks[t].size(), theirs.tracks[t].size()):
					var a: Dictionary = tracks[t][f]
					var b: Dictionary = theirs.tracks[t][f]
					worst = maxf(worst, Vector3(a.p[0], a.p[1], a.p[2]).distance_to(Vector3(b.p[0], b.p[1], b.p[2])))
					worst_q = maxf(worst_q, Quaternion(a.q[0], a.q[1], a.q[2], a.q[3]).angle_to(Quaternion(b.q[0], b.q[1], b.q[2], b.q[3])))
			print(clip, " scarto max posizione ", worst, " m, rotazione ", rad_to_deg(worst_q), " gradi; frames ", tracks.weapon_anchor.size(), "/", theirs.tracks.weapon_anchor.size())
			print("  mio f0 ", tracks.weapon_anchor[0], "\n  loro f0 ", theirs.tracks.weapon_anchor[0])
			continue
		if FileAccess.file_exists(OUT + clip + ".json"):
			continue      # le curve del pacchetto restano quelle originali
		var data := {"clip": clip, "fps": 30, "frames": frames + 1, "space": ref.space, "camera_from_head": ref.camera_from_head,
			"source": "ricavata da SM_ZX_Player.glb (tests/bake_fp_curves.gd)", "tracks": tracks}
		var file := FileAccess.open(OUT + clip + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		index[clip] = {"frames": frames + 1, "seconds": snappedf(anim.length, 0.001)}
		print("curva ", clip, " ", frames + 1)
	if not check:
		var file := FileAccess.open(OUT + "_baked_index.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(index, " "))
	quit()

func _sample(anim: Animation, sk: Skeleton3D, time: float) -> void:
	sk.reset_bone_poses()
	for t in anim.get_track_count():
		var bone := sk.find_bone(String(anim.track_get_path(t).get_concatenated_subnames()))
		if bone < 0: continue
		match anim.track_get_type(t):
			Animation.TYPE_ROTATION_3D: sk.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(t, time))
			Animation.TYPE_POSITION_3D: sk.set_bone_pose_position(bone, anim.position_track_interpolate(t, time))
			Animation.TYPE_SCALE_3D: sk.set_bone_pose_scale(bone, anim.scale_track_interpolate(t, time))
	sk.force_update_all_bone_transforms()

func _global(sk: Skeleton3D, bone: int) -> Transform3D:
	# Catena delle pose locali: non dipende dall'aggiornamento differito dello scheletro.
	var xf := sk.get_bone_pose(bone)
	var parent := sk.get_bone_parent(bone)
	while parent >= 0:
		xf = sk.get_bone_pose(parent) * xf
		parent = sk.get_bone_parent(parent)
	return xf
