# Audio globale: musica con dissolvenze, effetti 2D/3D e voci.
# Autoload AudioManager. In headless non crea player, così i test restano muti.
extends Node

signal music_requested(context: String)
signal music_changed(track: String)

const MUSIC := {
	"menu": "res://audio/music/menu.ogg",
	"explore": "res://audio/music/explore.ogg",
	"combat": "res://audio/music/combat.ogg",
	"boss_capomacello": "res://audio/music/boss_capomacello.ogg",
	"boss_mago": "res://audio/music/boss_mago.ogg",
	"boss_teste": "res://audio/music/boss_teste.ogg",
	"boss_carceriere": "res://audio/music/boss_carceriere.ogg",
}
const ZOMBIE_TYPES := ["walker", "runner", "brute", "elite", "spitter", "carceriere"]
const AXES := ["axe", "fire_axe", "runic_axe", "pickaxe", "sledgehammer", "electric_guitar"]
const BLADES := ["katana", "longsword", "spartan_sword", "machete"]
const BLUNTS := ["crowbar", "nail_bat", "frying_pan", "trout", "baguette", "rubber_chicken", "unarmed", ""]
const GUNS := ["pistol", "revolver", "smg", "assault_rifle", "pump_shotgun", "sniper_rifle",
	"sawn_off", "flare_gun", "lever_rifle", "crossbow", "nailgun", "lmg", "grenade_launcher",
	"tesla_rifle", "leaf_blower"]
const ZOMBIE_ACTIONS := ["idle", "alert", "attack", "hurt", "death"]
# Dopo lo sparo l'arma si riarma a mano: pompa, leva, otturatore.
const RACK := {"pump_shotgun": 0.34, "lever_rifle": 0.3, "sniper_rifle": 0.5}
# Armi che sparano così in fretta da fondere i colpi: il suono riparte solo dopo questa pausa.
const FIRE_GAP := {"leaf_blower": 0.38, "tesla_rifle": 0.12}

var _enabled := false
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _music_key := ""
var _music_tween: Tween
var _in_menu := true
var _in_game := false
var _combat := false
var _bosses: Array[String] = []
var _idle_clock := 6.0
var _variants: Dictionary = {}
var _last_variant: Dictionary = {}
var _fire_clock: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = DisplayServer.get_name() != "headless"
	if not _enabled:
		return
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_music_a = _music_player("MusicA")
	_music_b = _music_player("MusicB")
	if AudioServer.get_bus_effect_count(AudioServer.get_bus_index("SFX")) == 0:
		AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), AudioEffectHardLimiter.new())
	for i in range(24):
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_pool.append(player)


func _process(delta: float) -> void:
	if not _enabled or not _in_game or get_tree().paused:
		return
	# Una voce lontana ogni tanto: il bosco non è mai davvero vuoto.
	_idle_clock -= delta
	if _idle_clock > 0.0:
		return
	_idle_clock = randf_range(4.5, 8.0)
	var zombies := get_tree().get_nodes_in_group("zombies")
	if zombies.is_empty():
		return
	var pick: Node3D = zombies[randi() % zombies.size()]
	if not is_instance_valid(pick) or bool(pick.get("dead")):
		return
	var kind := int(pick.get("kind"))
	if kind == 5:
		return
	zombie_voice(kind, "idle", pick.global_position + Vector3.UP * 1.4, -11.0, randf_range(0.91, 1.08))


# ---------------------------------------------------------------- stato musica
func enter_menu() -> void:
	_in_menu = true
	_in_game = false
	_combat = false
	_bosses.clear()
	_music_key = _music_key if _music_key == "menu" else ""
	_refresh_music(1.4)


func enter_game() -> void:
	_in_menu = false
	_in_game = true
	_combat = false
	_bosses.clear()
	_idle_clock = randf_range(4.0, 7.0)
	_refresh_music(1.1)


func set_combat(active: bool) -> void:
	if not _in_game or _combat == active:
		return
	_combat = active
	_refresh_music(0.8)


func start_boss(id: String, _title: String = "") -> void:
	if not _in_game or not MUSIC.has("boss_" + id):
		return
	if not _bosses.has(id):
		_bosses.append(id)
	_refresh_music(0.65)


func end_boss(id: String) -> void:
	if not _bosses.has(id):
		return
	while _bosses.has(id):
		_bosses.erase(id)
	_refresh_music(1.25)


func clear_bosses() -> void:
	if _bosses.is_empty():
		return
	_bosses.clear()
	_refresh_music(1.0)


func _desired_track() -> String:
	if not _in_game or _in_menu:
		return "menu"
	if not _bosses.is_empty():
		return "boss_" + _bosses[_bosses.size() - 1]
	if _combat:
		return "combat"
	return "explore"


func _refresh_music(fade: float) -> void:
	var key := _desired_track()
	if key == _music_key:
		return
	_music_key = key
	music_requested.emit(key)
	music_changed.emit(key)
	if not _enabled:
		return
	var path: String = MUSIC.get(key, MUSIC["menu"])
	var stream := _load_audio(path, true)
	if stream == null:
		return
	var next: AudioStreamPlayer = _music_a
	if _active_music == _music_a:
		next = _music_b
	var old := _active_music
	_active_music = next
	next.stream = stream
	next.volume_db = -55.0
	next.play()
	var target := -7.0 if key == "combat" or key.begins_with("boss_") else (-6.0 if key == "menu" else -10.0)
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(next, "volume_db", target, fade)
	if is_instance_valid(old) and old.playing:
		_music_tween.tween_property(old, "volume_db", -55.0, fade)
		_music_tween.chain().tween_callback(old.stop)
	_music_tween.finished.connect(func() -> void:
		if is_instance_valid(next):
			next.volume_db = target)


func _music_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = "Music"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


# ---------------------------------------------------------------- effetti
func play_sfx(key: String, volume_db: float = -5.0, pitch: float = 1.0) -> void:
	if not _enabled:
		return
	var stream := _load_audio(_sfx_path(_variant(key)), false)
	if stream == null:
		return
	var player: AudioStreamPlayer = null
	for candidate in _sfx_pool:
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		player = _sfx_pool[Time.get_ticks_msec() % _sfx_pool.size()]
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.55, 1.8)
	player.play()


func play_3d(key: String, at: Vector3, volume_db: float = -6.0, pitch: float = 1.0, distance: float = 32.0) -> void:
	if not _enabled:
		return
	var stream := _load_audio(_sfx_path(_variant(key)), false)
	if stream == null:
		return
	var host: Node = get_tree().current_scene
	if host == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "Sfx3D"
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.55, 1.8)
	player.max_distance = distance
	player.unit_size = 4.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


func zombie_voice(kind: int, action: String, at: Vector3, volume_db: float = -7.0, pitch: float = 1.0) -> void:
	if action not in ZOMBIE_ACTIONS:
		return
	var type: String = ZOMBIE_TYPES[clampi(kind, 0, ZOMBIE_TYPES.size() - 1)]
	play_3d("zombie_%s_%s" % [type, action], at, volume_db, pitch, 28.0)


func zombie_step(kind: int, at: Vector3) -> void:
	var pitch: float = [0.88, 1.18, 0.7, 0.96, 1.02, 0.58][clampi(kind, 0, 5)]
	play_3d("zombie_step", at, -16.0, pitch * randf_range(0.94, 1.07), 19.0)


func boss_voice(id: String, action: String, at: Vector3, volume_db: float = -3.0) -> void:
	if action not in ["roar", "attack", "death"]:
		return
	play_3d("boss_%s_%s" % [id, action], at, volume_db, randf_range(0.94, 1.05), 46.0)


func weapon_swing(equipped: String, charged: bool = false, kick: bool = false) -> void:
	if kick:
		play_sfx("kick", -2.0, randf_range(0.93, 1.07))
		return
	if equipped == "bow":
		return
	if _is_gun(equipped):
		weapon_fire(equipped)
		return
	var family := _weapon_family(equipped)
	var pitch := randf_range(0.94, 1.06) * (0.82 if charged else 1.0)
	play_sfx("swing_" + family, -2.0 if charged else -4.0, pitch)


func weapon_fire(equipped: String) -> void:
	if not _fire_ready(equipped):
		return
	var stats: Dictionary = preload("res://weapons/zx_arsenal.gd").gun(equipped)
	play_sfx(_fire_key(equipped), float(stats.vol), randf_range(0.97, 1.03))
	if _enabled and RACK.has(equipped):
		get_tree().create_timer(RACK[equipped], false).timeout.connect(play_sfx.bind("gun_rack", -9.0, randf_range(0.97, 1.03)))


# Lo sparo di un altro giocatore: arriva dal punto in cui spara e si sente da lontano.
func weapon_fire_at(equipped: String, at: Vector3) -> void:
	if not _fire_ready(equipped):
		return
	var stats: Dictionary = preload("res://weapons/zx_arsenal.gd").gun(equipped)
	play_3d(_fire_key(equipped), at, float(stats.vol) + 3.0, randf_range(0.97, 1.03), 90.0)


func _fire_key(equipped: String) -> String:
	if _is_gun(equipped):
		return "fire_" + equipped
	return "fire_pistol"


func _fire_ready(equipped: String) -> bool:
	var gap: float = FIRE_GAP.get(equipped, 0.0)
	if gap <= 0.0:
		return true
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_fire_clock.get(equipped, -9.0)) < gap:
		return false
	_fire_clock[equipped] = now
	return true


func weapon_reload(equipped: String) -> void:
	if equipped in ["pump_shotgun", "sawn_off", "lever_rifle"]:
		play_sfx("weapon_reload_shell", -5.0)
	elif equipped == "crossbow":
		play_sfx("weapon_reload_bolt", -5.0)
	else:
		play_sfx("weapon_reload_rifle" if _is_rifle(equipped) else "weapon_reload_pistol", -5.0)


## Un evento della ricarica (zx_arsenal.RELOAD_STEPS): chi ricarica lo sente in 2D, gli altri dal punto `at`.
## Volume sotto i nemici: la ricarica non deve coprire uno zombie che arriva.
func reload_step(equipped: String, step: String, at: Variant = null) -> void:
	var size := "rifle" if _is_rifle(equipped) else "pistol"
	var key: String = {"mag_out": "reload_mag_out_" + size, "mag_in": "reload_mag_in_" + size,
		"slide": "reload_bolt_rifle" if size == "rifle" else "reload_slide_pistol",
		"shell_in": "reload_shell_in", "rounds_in": "reload_cyl_round" if equipped == "revolver" else "reload_shell_in",
		"break_open": "reload_break_open", "break_close": "reload_break_close",
		"cyl_open": "reload_cyl_open", "cyl_close": "reload_cyl_close",
		"string": "reload_crossbow_string", "bolt_in": "reload_crossbow_bolt",
		"chamber": "reload_lever" if equipped == "lever_rifle" else "reload_pump"}.get(step, "")
	if key == "": return
	var pitch := randf_range(0.97, 1.03)
	if at == null: play_sfx(key, -9.0, pitch)        # file a circa -14 dB: 7 dB sotto la voce di uno zombie a un metro
	else: play_3d(key, at, -12.0, pitch, 18.0)


func gun_empty() -> void:
	play_sfx("gun_empty", -8.0, randf_range(0.96, 1.04))


func explosion(at: Vector3) -> void:
	play_3d("explosion", at, 3.0, randf_range(0.95, 1.05), 110.0)


# Un colpo in aria di un altro giocatore.
func weapon_swing_at(equipped: String, at: Vector3) -> void:
	play_3d("swing_" + _weapon_family(equipped), at, -6.0, randf_range(0.94, 1.06), 18.0)


func footstep(pitch: float) -> void:
	play_sfx("footstep", -14.0, pitch)


# Un suono continuo (vento, fuoco, motore): stesso file, in giro senza stacchi.
func loop_stream(path: String) -> AudioStream:
	return _load_audio(path, true)


func weapon_equip(equipped: String) -> void:
	if equipped == "":
		return
	play_sfx("weapon_equip", -8.0, randf_range(0.92, 1.08))


func weapon_hit(equipped: String, zone: String, heavy: bool = false, kick: bool = false) -> void:
	if kick:
		play_sfx("kick", -2.0, randf_range(0.93, 1.07))
		return
	var key := "weapon_hit_flesh"
	if zone == "head":
		key = "weapon_hit_head"
	elif zone in ["feet", "legs"]:
		key = "weapon_hit_bone"
	var pitch := randf_range(0.92, 1.06) * (0.86 if heavy else 1.0)
	play_sfx(key, -1.5 if heavy else -3.0, pitch)


func bow_draw() -> void:
	play_sfx("bow_draw", -8.0, randf_range(0.96, 1.04))


func bow_release() -> void:
	play_sfx("bow_release", -3.0, randf_range(0.96, 1.04))


func arrow_pickup(at: Vector3) -> void:
	play_3d("arrow_pickup", at, -9.0, randf_range(0.94, 1.08), 12.0)


func player_hurt() -> void:
	play_sfx("player_hurt", -2.0, randf_range(0.94, 1.06))


func player_death() -> void:
	play_sfx("player_death", -1.0)


func _weapon_family(equipped: String) -> String:
	if equipped == "spade":
		return "shovel"
	if equipped in ["knife", "combat_knife"]:
		return "knife"
	if equipped in AXES:
		return "axe"
	if equipped in BLADES:
		return "blade"
	if equipped in BLUNTS:
		return "blunt"
	return "blunt"


func _is_gun(equipped: String) -> bool:
	return equipped in GUNS


func _is_rifle(equipped: String) -> bool:
	return equipped in ["assault_rifle", "pump_shotgun", "sniper_rifle", "sawn_off", "lever_rifle",
		"crossbow", "lmg", "grenade_launcher", "tesla_rifle", "leaf_blower"]


# ---------------------------------------------------------------- risorse
func _sfx_path(key: String) -> String:
	return "res://audio/sfx/%s.wav" % key


# Più registrazioni per lo stesso suono (nome, nome_2, nome_3...): mai la stessa due volte di fila.
func _variant(key: String) -> String:
	if not _variants.has(key):
		var n := 1
		while ResourceLoader.exists(_sfx_path("%s_%d" % [key, n + 1])):
			n += 1
		_variants[key] = n
	var count: int = _variants[key]
	if count < 2:
		return key
	var pick: int = (int(_last_variant.get(key, 0)) + 1 + randi() % (count - 1)) % count
	_last_variant[key] = pick
	return key if pick == 0 else "%s_%d" % [key, pick + 1]


func _load_audio(path: String, looped: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	if looped:
		stream = stream.duplicate() as AudioStream
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = _wav_frames(wav)
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
	_cache[path] = stream
	return stream


func _wav_frames(wav: AudioStreamWAV) -> int:
	var bytes_per_sample := 2
	if wav.format == AudioStreamWAV.FORMAT_8_BITS:
		bytes_per_sample = 1
	elif wav.format == AudioStreamWAV.FORMAT_IMA_ADPCM:
		return 0
	elif wav.format == AudioStreamWAV.FORMAT_QOA:
		return 0
	var channels := 2 if wav.stereo else 1
	return int(wav.data.size() / maxi(1, bytes_per_sample * channels))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
