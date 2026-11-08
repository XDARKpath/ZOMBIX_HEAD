# Controlla che ogni suono del gioco esista e suoni, poi passa in rassegna musica ed effetti attraverso AudioManager.
# Con --write-movie il mix finale finisce in un wav: tools/audio/measure_mix.py ne misura il volume scena per scena.
extends SceneTree

const TYPES := ["walker", "runner", "brute", "elite", "spitter", "carceriere"]
const ACTIONS := ["idle", "alert", "attack", "hurt", "death"]
const BOSSES := ["capomacello", "mago", "teste", "carceriere"]
const OTHER := ["kick", "player_hurt", "player_death", "boss_defeat", "explosion", "footstep", "zombie_step", "weapon_equip",
	"weapon_hit_flesh", "weapon_hit_head", "weapon_hit_bone", "weapon_hit_guard", "bow_draw", "bow_release", "arrow_impact", "arrow_pickup",
	"weapon_reload_pistol", "weapon_reload_rifle", "weapon_reload_shell", "weapon_reload_bolt", "gun_rack", "gun_empty",
	"swing_axe", "swing_blade", "swing_blunt", "swing_knife", "swing_shovel"]
var pass_n := 0
var fail_n := 0
var frames := 0


func check(ok: bool, what: String) -> void:
	if ok:
		pass_n += 1
	else:
		fail_n += 1
		print("FAIL ", what)


func sound(path: String) -> void:
	var s = load(path) if ResourceLoader.exists(path) else null
	check(s is AudioStream and s.get_length() > 0.05, path)


func _initialize() -> void:
	await process_frame
	var audio: Node = root.get_node("AudioManager")
	for key in audio.MUSIC:
		sound(audio.MUSIC[key])
		check(audio.MUSIC[key].ends_with(".ogg") and load(audio.MUSIC[key]).get_length() > 30.0, "musica lunga " + key)
	for t in TYPES:
		for a in ACTIONS:
			sound("res://audio/sfx/zombie_%s_%s.wav" % [t, a])
	for b in BOSSES:
		for a in ["roar", "attack", "death"]:
			sound("res://audio/sfx/boss_%s_%s.wav" % [b, a])
	for g in audio.GUNS:
		sound("res://audio/sfx/fire_%s.wav" % g)
	for k in OTHER:
		sound("res://audio/sfx/%s.wav" % k)
	for k in ["forest.ogg", "fire.ogg", "vehicle_engine.ogg", "footstep.wav", "menu_press.wav", "menu_hover.wav", "hit.wav", "heavy.wav", "swing.wav"]:
		sound("res://audio/" + k)
	check(audio.loop_stream("res://audio/forest.ogg").loop, "vento in giro")
	check(audio._variant("zombie_walker_attack") != audio._variant("zombie_walker_attack"), "due varianti di fila diverse")
	print("audio_checks : PASS=%d FAIL=%d" % [pass_n, fail_n])
	if DisplayServer.get_name() == "headless":
		quit()
		return
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var ear := Camera3D.new()
	scene.add_child(ear)
	var front := Vector3(0, 0, -6)
	audio.enter_menu()
	await mark("menu", 5.0)
	audio.enter_game()
	await mark("explore", 7.0)
	audio.set_combat(true)
	await mark("combat", 6.0)
	for b in BOSSES:
		audio.start_boss(b)
		await mark("boss_" + b, 6.0)
		audio.end_boss(b)
	audio.set_combat(false)
	await mark("calma", 4.0)
	for g in audio.GUNS:
		print("T fire_%s %.2f" % [g, frames / 30.0])
		audio.weapon_fire(g)
		await seconds(0.9)
	for t in range(6):
		for a in ACTIONS:
			print("T zombie_%s_%s %.2f" % [TYPES[t], a, frames / 30.0])
			audio.zombie_voice(t, a, front)
			await seconds(0.7)
	for b in BOSSES:
		print("T boss_%s %.2f" % [b, frames / 30.0])
		audio.boss_voice(b, "roar", front)
		await seconds(1.6)
	print("T explosion %.2f" % (frames / 30.0))
	audio.explosion(front)
	await seconds(1.5)
	print("T fine %.2f" % (frames / 30.0))
	quit()


func mark(what: String, wait: float) -> void:
	print("T %s %.2f" % [what, frames / 30.0])
	await seconds(wait)


func seconds(wait: float) -> void:
	for i in range(int(wait * 30.0)):
		await process_frame
		frames += 1
