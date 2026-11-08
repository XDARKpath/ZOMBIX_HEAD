# Nodo Control sotto Interface. L'HUD si adatta alla dimensione reale del canvas
# (con aspect "expand" la larghezza logica non è sempre 1440): il centro è size*0.5,
# gli elementi a destra partono dal bordo destro e quelli in basso dal bordo inferiore.
# Poche scritte: vita e fiato in alto a sinistra come capsule arrotondate, obiettivo
# in una pillola in alto al centro, mappa e risorse in alto a destra, zaino in basso.
# I comandi non sono più a schermo (F1 li mostra); il nome della zona appare solo
# all'arrivo. I pannelli sono in vetro, seguono la camera con una molla e in corsa
# scendono al 30%.
extends Control

const C_BONE = Color(0.93,0.90,0.82)
const C_SAGE = Color(0.70,0.77,0.72)
const C_MUTED = Color(0.52,0.60,0.56)
const C_BRASS = Color(0.90,0.69,0.40)
const C_BRASS_SOFT = Color(0.90,0.69,0.40,0.55)
const C_RUST = Color(0.86,0.38,0.27)
const C_TEAL = Color(0.55,0.81,0.75)
const C_HP = Color(0.56,0.82,0.52)
const C_STAMINA = Color(0.93,0.74,0.42)
const C_TRACK = Color(0.02,0.05,0.05,0.55)
const WEAPON_NAMES = {"axe":"ASCIA","knife":"COLTELLO","pistol":"PISTOLA"}
const Arsenal = preload("res://weapons/zx_arsenal.gd")
var reload_total := 1.6
var last_reload := 0.0
const SLOT := 64.0
const GAP := 6.0
const C_LINE = Color("d4a56c")

var world: Node3D
var font: Font
var bold: Font
var impact: float = 0
var hurt: float = 0
var chain_time: float = 0
var chain: int = 0
var previous_kills: int = 0
var previous_health: float = 100
var grade: ShaderMaterial
var enemy_health: Dictionary = {}
var display_health: float = 100
var display_stamina: float = 100
var weapon_pulse: float = 0
var hit_flash: float = 0
var last_weapon: String = ""
var feed: Array = []
var hint_text: String = ""
var hint_action: bool = false
var zone_title: String = ""
var zone_time: float = 0
var objective_rect := Rect2()
# Pannelli in vetro (60%) che seguono la camera con una molla e sbiadiscono in corsa.
var vignette: ColorRect
var hotbar_glass: Control
var objective_glass: Control
var radar_glass: Control
var spring_offset := Vector2.ZERO
var spring_velocity := Vector2.ZERO
var last_yaw: float = 0
var last_pitch: float = 0
var sprint_fade: float = 0

func build(owner_world: Node3D) -> void:
	world = owner_world
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Bahnschrift","Segoe UI"])
	font = system
	var heavy := FontVariation.new()
	heavy.base_font = system
	heavy.variation_embolden = 0.55
	bold = heavy
	var theme_value := Theme.new()
	theme_value.default_font = font
	theme = theme_value
	radar_glass = _glass(Rect2(size.x-212,32,156,156),true)
	_glass(Rect2(28,26,292,66),false,28.0)
	hotbar_glass = _glass(Rect2(size.x*0.5-134,size.y-100,268,76),false,24.0)
	add_child(preload("res://ui/item_icons.gd").new())
	objective_glass = _glass(Rect2(size.x*0.5-160,24,320,52),false,26.0)
	# La vignettatura resta ferma a tutto schermo: è un fratello dell'HUD, non un figlio.
	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade = ShaderMaterial.new()
	grade.shader = preload("res://ui/camp/grade.gdshader")
	vignette.material = grade
	get_parent().add_child(vignette)
	get_parent().move_child(vignette,get_index())

func _glass(rect: Rect2, circular: bool = false, radius: float = 10.0) -> Control:
	var panel := Control.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show_behind_parent = true
	add_child(panel)
	preload("res://ui/glass/surface.gd").add(panel,0.38,circular,radius)
	return panel

func _motion(delta: float) -> void:
	# Molla: lo sguardo trascina i pannelli di qualche pixel e li lascia tornare.
	var rig: Node3D = world.player.rig
	var look := Vector2(wrapf(rig.yaw-last_yaw,-PI,PI),rig.pitch-last_pitch)/maxf(delta,0.001)
	last_yaw = rig.yaw
	last_pitch = rig.pitch
	var target := (look*Vector2(10.0,8.0)).limit_length(14.0)
	var k := 70.0
	spring_velocity += (k*(target-spring_offset)-2.0*sqrt(k)*0.6*spring_velocity)*delta
	spring_offset += spring_velocity*delta
	sprint_fade = move_toward(sprint_fade,1.0 if world.player.sprinting else 0.0,delta/0.25)
	var sway := Vector2(cos(rig.bob_clock)*5.0,absf(sin(rig.bob_clock))*4.0)*sprint_fade
	position = spring_offset+sway
	modulate.a = lerpf(1.0,0.3,sprint_fade)

var tint_rect: ColorRect
var tint_clock: float = 0.0

func _status_tint(delta: float) -> void:
	var p = world.player
	if tint_rect == null:
		tint_rect = ColorRect.new()
		tint_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tint_rect)
		move_child(tint_rect, 0)
	tint_clock += delta
	var color := Color(0, 0, 0, 0)
	if p.get("status") != null and not p.dead:
		var pulse: float = 0.5 + 0.5 * sin(tint_clock * 2.6)
		if float(p.status.left.poison) > 0.0: color = Color(0.35, 0.8, 0.2, 0.05 + 0.06 * pulse)
		elif float(p.status.left.bleed) > 0.0: color = Color(0.7, 0.05, 0.03, 0.04 + 0.05 * pulse)
		elif p.status.radiation > 25.0: color = Color(0.8, 0.8, 0.15, 0.03 + 0.07 * pulse * p.status.radiation / 100.0)
		elif float(p.status.left.stun) > 0.0: color = Color(0.9, 0.9, 0.85, 0.12)
		elif float(p.status.left.fear) > 0.0: color = Color(0.4, 0.25, 0.65, 0.05 + 0.04 * pulse)
	tint_rect.color = color

func _process(delta: float) -> void:
	visible = world.started and not world.ui_open
	vignette.visible = visible
	if not visible: return
	_motion(delta)
	var p = world.player
	_status_tint(delta)
	display_health = lerpf(display_health,p.health,1.0-exp(-delta*12.0))
	display_stamina = lerpf(display_stamina,p.stamina,1.0-exp(-delta*10.0))
	if last_weapon != p.equipped:
		last_weapon = p.equipped
		weapon_pulse = 1.5
	# La durata della ricarica dipende dalla clip dell'arma: l'anello parte dal valore iniziale.
	if p.reload_left > last_reload: reload_total = maxf(p.reload_left, 0.1)
	last_reload = p.reload_left
	weapon_pulse = maxf(0,weapon_pulse-delta)
	hit_flash = maxf(0,hit_flash-delta*3.0)
	if p.health < previous_health:
		hurt = 1
		hit_flash = 1
	previous_health = p.health
	hurt = move_toward(hurt,0,delta*1.3)
	impact = move_toward(impact,0,delta*3)
	grade.set_shader_parameter("hurt",maxf(hurt,0.25 if p.health < 30 else 0))
	var title: String = preload("res://world/campaign/route.gd").TITLES[world.expedition.zone_index]
	if title != zone_title:
		zone_title = title
		zone_time = 4.0
	zone_time = maxf(0,zone_time-delta)
	if world.kills > previous_kills:
		chain = chain+world.kills-previous_kills if chain_time > 0 else world.kills-previous_kills
		chain_time = 5
		impact = 1
		feed.push_front({"text":Localization.t("INFETTO ABBATTUTO"),"life":3.0})
		if feed.size() > 3: feed.resize(3)
		previous_kills = world.kills
	for row in feed: row["life"] = float(row["life"])-delta
	feed = feed.filter(func(row): return float(row["life"]) > 0.0)
	chain_time = maxf(0,chain_time-delta)
	hint_text = world.survival.context()
	if hint_text.is_empty(): hint_text = world.expedition.prompt()
	if hint_text.is_empty() and world.notice_left > 0: hint_text = world.notice.text
	if p.dead: hint_text = Localization.t("SEI CADUTO  ·  RIENTRO AL RIFUGIO")
	hint_action = hint_text.begins_with("E ")
	if hint_action: hint_text = hint_text.substr(2).strip_edges()
	for enemy in world.targets:
		if not is_instance_valid(enemy): continue
		var id: int = enemy.network_id
		if enemy_health.has(id) and enemy.health < enemy_health[id] and enemy.position.distance_to(p.position) < 7:
			impact = 1
			_damage_label(enemy.position+Vector3.UP*1.8,enemy_health[id]-enemy.health)
		enemy_health[id] = enemy.health
	# Vetri che seguono le misure di ciò che viene disegnato.
	var total: float = p.inventory_slots*SLOT+(p.inventory_slots-1)*GAP
	hotbar_glass.visible = not p.seated
	hotbar_glass.position = Vector2(size.x*0.5-total*0.5-12.0,size.y-100.0)
	hotbar_glass.size = Vector2(total+24.0,SLOT+24.0)
	radar_glass.position = Vector2(size.x-212,32)
	objective_rect = _objective_rect()
	objective_glass.position = objective_rect.position
	objective_glass.size = objective_rect.size
	queue_redraw()

func _damage_label(at: Vector3, amount: float) -> void:
	var label := Label3D.new()
	label.text = str(int(amount))
	label.font_size = 44
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("ffd591")
	label.no_depth_test = true
	world.add_child(label)
	label.position = at
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label,"position:y",at.y+0.8,0.7)
	tween.tween_property(label,"modulate:a",0.0,0.7)
	tween.chain().tween_callback(label.queue_free)

func _draw() -> void:
	if not world or not world.started: return
	var now := Time.get_ticks_msec() / 1000.0
	_draw_vitals(now)
	_draw_objective()
	_draw_status()
	_draw_hit_arrow()
	_draw_marker()
	_draw_zone_title()
	_draw_center()
	_draw_feed()
	_draw_radar(now)
	_draw_resources()
	_draw_boss_bar()
	if world.player.seated: _draw_vehicle()
	else: _draw_hotbar()

# ---------------------------------------------------------------- primitive
func _pill(rect: Rect2, fill: Color, border: Color = Color(0,0,0,0), radius: float = -1.0, width: int = 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	var r: int = int(rect.size.y*0.5 if radius < 0 else radius)
	style.set_corner_radius_all(r)
	style.corner_detail = 8
	style.anti_aliasing = true
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(width)
	draw_style_box(style,rect)

func _bar(rect: Rect2, value: float, ghost: float, color: Color, ghost_color: Color, ticks: bool = false) -> void:
	_pill(rect,C_TRACK,Color(1,1,1,0.07))
	ghost = maxf(ghost,value)
	if ghost > 0.005:
		_pill(Rect2(rect.position,Vector2(maxf(rect.size.y,rect.size.x*ghost),rect.size.y)),Color(ghost_color.r,ghost_color.g,ghost_color.b,0.35))
	if value > 0.005:
		var fill := Rect2(rect.position,Vector2(maxf(rect.size.y,rect.size.x*value),rect.size.y))
		# alone morbido sotto il colore: la barra sembra accesa, non stampata
		_pill(fill.grow(2.0),Color(color.r,color.g,color.b,0.16))
		_pill(fill,color)
		# riflesso sottile sulla metà alta
		_pill(Rect2(fill.position+Vector2(2,1),Vector2(maxf(0,fill.size.x-4),maxf(1.0,rect.size.y*0.32))),Color(1,1,1,0.22))
	# tacche ogni quarto: si legge a colpo d'occhio quanto manca
	if ticks:
		for i in range(1,4):
			var x: float = rect.position.x+rect.size.x*i/4.0
			draw_line(Vector2(x,rect.position.y+2),Vector2(x,rect.end.y-2),Color(0,0,0,0.35),1.0)

func _text(at: Vector2, value: String, size_value: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width: float = -1, f: Font = null) -> void:
	var use: Font = f if f else font
	value = Localization.t(value)
	draw_string(use,at+Vector2(0,1),value,align,width,size_value,Color(0,0,0,0.45*color.a))
	draw_string(use,at,value,align,width,size_value,color)

func _center_text(center: Vector2, value: String, size_value: int, color: Color, f: Font = null) -> void:
	var use: Font = f if f else font
	var s := use.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value)
	_text(center+Vector2(-s.x*0.5,size_value*0.35),value,size_value,color,HORIZONTAL_ALIGNMENT_LEFT,-1,use)

# ---------------------------------------------------------------- vita e fiato
func _draw_vitals(now: float) -> void:
	var p = world.player
	var hp: float = clampf(p.health/100.0,0.0,1.0)
	var sp: float = clampf(p.stamina/100.0,0.0,1.0)
	var hp_color: Color = C_HP.lerp(Color("d9573c"),clampf((0.5-hp)/0.5,0.0,1.0))
	if hp < 0.30 and fmod(now,0.8) < 0.4: hp_color = hp_color.lerp(Color("ffa184"),0.45)
	_heart(Vector2(52,48),hp_color)
	_bar(Rect2(72,41,206,14),hp,clampf(display_health/100.0,0,1),hp_color,C_RUST,true)
	_text(Vector2(286,53),"%d" % ceili(p.health),15,C_RUST if hp < 0.3 else C_BONE,HORIZONTAL_ALIGNMENT_LEFT,-1,bold)
	_bolt(Vector2(52,74),C_RUST if p.exhausted else C_STAMINA)
	var sp_color: Color = Color("e08a62") if p.exhausted else C_STAMINA
	_bar(Rect2(72,70,206,8),sp,clampf(display_stamina/100.0,0,1),sp_color,Color(0.55,0.42,0.22),true)
	_draw_noise()
	if hp < 0.30:
		_pill(Rect2(26,24,296,70),Color(0,0,0,0),Color(C_RUST.r,C_RUST.g,C_RUST.b,0.35+0.3*sin(now*5.0)),29.0,2)

func _draw_noise() -> void:
	# Rumore: altoparlante e cinque tacche sotto la vita; foglia se si è sazi.
	var life = world.get("zone_life")
	if not life: return
	var level: float = clampf(life.noise_level,0,1)
	var base := Vector2(44,112)
	var color: Color = C_SAGE.lerp(C_RUST,smoothstep(0.4,0.9,level))
	draw_colored_polygon(PackedVector2Array([base+Vector2(-6,-3),base+Vector2(-2,-3),base+Vector2(3,-7),base+Vector2(3,7),base+Vector2(-2,3),base+Vector2(-6,3)]),color)
	for i in 5:
		var on: bool = level > (i+0.5)/5.0
		var h := 4.0+i*2.2
		_pill(Rect2(base.x+12+i*8,base.y-h*0.5,4,h),color if on else Color(1,1,1,0.15),Color(0,0,0,0),2.0)
	if life.fed > 0.0:
		var leaf := base+Vector2(64,0)
		draw_colored_polygon(PackedVector2Array([leaf+Vector2(-6,4),leaf+Vector2(-2,-5),leaf+Vector2(6,-6),leaf+Vector2(3,3)]),C_HP)
		draw_line(leaf+Vector2(-6,5),leaf+Vector2(4,-4),Color(0.1,0.2,0.1),1,true)

func _heart(c: Vector2, color: Color) -> void:
	draw_circle(c+Vector2(-3.6,-2.0),4.6,color)
	draw_circle(c+Vector2(3.6,-2.0),4.6,color)
	draw_colored_polygon(PackedVector2Array([c+Vector2(-8.0,-0.6),c+Vector2(8.0,-0.6),c+Vector2(0,8.5)]),color)

func _bolt(c: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c+Vector2(1.5,-7),c+Vector2(-4.5,1),c+Vector2(-0.5,1),c+Vector2(-1.5,7),c+Vector2(4.5,-1),c+Vector2(0.5,-1)]),color)

# ---------------------------------------------------------------- obiettivo
func _objective_rect() -> Rect2:
	var title: String = world.expedition.title()
	var detail: String = world.expedition.detail()
	var w: float = maxf(bold.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x,font.get_string_size(detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x)
	w = clampf(w+64.0,260.0,560.0)
	return Rect2(size.x*0.5-w*0.5,24,w,52)

func _draw_objective() -> void:
	var r := objective_rect
	var title: String = world.expedition.title()
	var detail: String = world.expedition.detail()
	# segnalino dorato a sinistra: stesso colore dell'indicatore nel mondo
	draw_circle(r.position+Vector2(24,26),5.5,C_BRASS)
	draw_circle(r.position+Vector2(24,26),2.2,Color(0.08,0.12,0.12))
	_text(r.position+Vector2(42,24),title,15,C_BONE,HORIZONTAL_ALIGNMENT_LEFT,r.size.x-56,bold)
	_text(r.position+Vector2(42,42),detail,12,C_SAGE,HORIZONTAL_ALIGNMENT_LEFT,r.size.x-56)
	var y := r.end.y+8.0
	if world.expedition.stage == 1 or world.expedition.downloading:
		var hold: float = 1.0-world.expedition.hold/(8.0 if world.expedition.stage == 1 else 10.0)
		_bar(Rect2(r.position.x+24,y,r.size.x-48,5),clampf(hold,0,1),0,C_BRASS,C_BRASS)
		y += 13.0
	if world.get("boss_hunt"):
		var hunt = world.boss_hunt
		# La vita del boss ha la sua barra grande in basso (_draw_boss_bar).
		if not hunt.active_boss() and world.get("quest") and world.quest.bosses_done() < 3:
			# pezzi del 4×4 recuperati come tre rombi, senza testo
			var done: int = world.quest.bosses_done()
			for i in 3:
				var c := Vector2(size.x*0.5-12+i*12,y+4)
				var pts := PackedVector2Array([c+Vector2(0,-4),c+Vector2(4,0),c+Vector2(0,4),c+Vector2(-4,0)])
				draw_colored_polygon(pts,C_BRASS if i < done else Color(1,1,1,0.18))

## Il boss più vicino (entro 60 m): nome, barra larga in basso e le tacche delle fasi (66% e 33%, come boss_brain).
## Tutto viene da vita e nome già sincronizzati dall'host: uguale sui client.
var boss_ghost := 1.0
func _draw_boss_bar() -> void:
	var boss: Node3D = null
	var best := 60.0
	for body in world.get("targets"):
		if not is_instance_valid(body) or body.dead or body.kind != 5 or String(body.title) == "": continue
		var d: float = body.global_position.distance_to(world.player.global_position)
		if d < best:
			best = d
			boss = body
	if boss == null:
		boss_ghost = 1.0
		return
	var frac: float = clampf(boss.health/maxf(boss.max_health,1.0),0,1)
	boss_ghost = maxf(frac,move_toward(boss_ghost,frac,get_process_delta_time()*0.35))
	var phase: int = 3 if frac < 0.33 else (2 if frac < 0.66 else 1)
	var w: float = minf(size.x*0.62,760.0)
	var r := Rect2(size.x*0.5-w*0.5,size.y-150,w,16)
	_pill(r.grow(5),Color(0,0,0,0.45),Color(C_BRASS.r,C_BRASS.g,C_BRASS.b,0.35),-1,1)
	var color: Color = C_RUST.lerp(Color("ff2a2a"),float(phase-1)*0.5)
	_bar(r,frac,boss_ghost,color,Color("f2c27a"))
	for mark in [0.66,0.33]:
		var x: float = r.position.x+r.size.x*mark
		draw_line(Vector2(x,r.position.y-6),Vector2(x,r.end.y+6),C_BONE if frac > mark else Color(1,1,1,0.3),2.0)
	_text(Vector2(r.position.x,r.position.y-10),String(boss.title),20,Color(0.96,0.86,0.68),HORIZONTAL_ALIGNMENT_LEFT,-1,bold)
	_text(Vector2(r.position.x,r.position.y-10),Localization.t("FASE {0}/3",[phase]),15,color.lightened(0.3),HORIZONTAL_ALIGNMENT_RIGHT,r.size.x,bold)

## Veleno, sangue, radiazioni e il resto, sotto la vita: cosa hai, quanto dura, con cosa si cura.
func _draw_status() -> void:
	var p = world.player
	if p.get("status") == null: return
	var y := 150.0
	for kind in p.status.active():
		var info: Dictionary = p.status.INFO[kind]
		var c: Color = info.color
		draw_circle(Vector2(50, y), 8.0, Color(c.r, c.g, c.b, 0.9))
		draw_circle(Vector2(50, y), 4.0, Color(0.05, 0.06, 0.06, 0.9))
		_text(Vector2(66, y + 5), "%s  %d s" % [Localization.t(str(info.name)), ceili(float(p.status.left[kind]))], 13, C_BONE)
		if str(info.cure) != "": _text(Vector2(66, y + 19), Localization.t(str(info.cure)), 10, C_SAGE)
		y += 34.0 if str(info.cure) != "" else 24.0
	if p.status.radiation > 0.5:
		_text(Vector2(40, y + 5), Localization.t("RADIAZIONI  {0}", [int(p.status.radiation)]), 13, Color("ffd23a"))
		_bar(Rect2(40, y + 11, 150, 5), p.status.radiation / 100.0, 0, Color("ffd23a"), Color("ffd23a"))


## Freccia rossa attorno al mirino: da dove ti hanno colpito.
func _draw_hit_arrow() -> void:
	var p = world.player
	if not p.has_meta("hit_at"): return
	var age: float = (Time.get_ticks_msec() - int(p.get_meta("hit_at"))) / 1000.0
	if age > 0.9: return
	var to: Vector3 = p.get_meta("hit_from") - p.global_position
	var angle: float = atan2(to.x, -to.z) + p.rig.yaw
	var center := size * 0.5
	var alpha: float = 1.0 - age / 0.9
	var points := PackedVector2Array()
	for i in range(-6, 7):
		points.append(center + Vector2(sin(angle + float(i) * 0.075), -cos(angle + float(i) * 0.075)) * 118.0)
	draw_polyline(points, Color(0.95, 0.15, 0.1, alpha), 7.0, true)


## Dove andare: un rombo con i metri sopra l'obiettivo. Fuori dallo schermo resta sul bordo, così indica la direzione.
func _draw_marker() -> void:
	var p = world.player
	if p.global_position.y > 150.0 or world.ui_open: return
	var goal: Vector3 = world.expedition.target_point()
	var metres: float = p.global_position.distance_to(goal)
	if metres < 5.0: return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var view := get_viewport_rect().size
	var view_scale := Vector2(size.x / maxf(view.x,1.0), size.y / maxf(view.y,1.0))
	var world_at := goal + Vector3.UP * 2.2
	var behind: bool = camera.is_position_behind(world_at)
	var screen: Vector2 = camera.unproject_position(world_at) * view_scale
	var box := Rect2(70, 110, maxf(size.x-140.0, 1.0), maxf(size.y-220.0, 1.0))
	if behind: screen = Vector2(size.x - screen.x, size.y - 140.0)
	screen = screen.clamp(box.position, box.end)
	var pts := PackedVector2Array([screen+Vector2(0,-9),screen+Vector2(7,0),screen+Vector2(0,9),screen+Vector2(-7,0)])
	draw_colored_polygon(pts,C_BRASS)
	_center_text(screen+Vector2(0,26),"%d m" % int(metres),12,C_BONE,bold)

func _draw_zone_title() -> void:
	if zone_time <= 0: return
	var a: float = clampf(minf(4.0-zone_time,zone_time)*1.5,0,1)
	_center_text(Vector2(size.x*0.5,250),zone_title,34,Color(C_BONE.r,C_BONE.g,C_BONE.b,a),bold)
	draw_line(Vector2(size.x*0.5-60,276),Vector2(size.x*0.5+60,276),Color(C_BRASS.r,C_BRASS.g,C_BRASS.b,a*0.8),2,true)

# ---------------------------------------------------------------- centro
func _draw_center() -> void:
	var c := size * 0.5
	var p = world.player
	var speed: float = Vector2(p.velocity.x,p.velocity.z).length()
	var spread: float = 5.0+minf(speed,7.0)*0.6+impact*4.0
	if p.melee.charging: spread += 8.0*p.melee.charge_fraction()
	draw_circle(c,2.2,Color(0.97,0.94,0.85,0.9))
	draw_arc(c,spread+4.0,0,TAU,32,Color(0.97,0.94,0.85,0.22),1.5,true)
	if p.melee.charging:
		draw_arc(c,22,-PI/2,-PI/2+TAU*maxf(0.01,p.melee.charge_fraction()),40,C_BRASS,3,true)
	if hit_flash > 0:
		for side in [Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)]:
			draw_line(c+side*9,c+side*16,Color(1,0.42,0.28,hit_flash),2,true)
	if chain_time > 0 and chain > 1:
		var a: float = clampf(chain_time,0,1)
		_center_text(Vector2(c.x,c.y-52),"×%d" % chain,22,Color(C_BRASS.r,C_BRASS.g,C_BRASS.b,a),bold)
	if hint_text.is_empty(): return
	var width: float = font.get_string_size(hint_text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+(64.0 if hint_action else 36.0)
	var r := Rect2(size.x*0.5-width*0.5,size.y-232.0,width,36)
	_pill(r,Color(0.04,0.08,0.08,0.62),Color(C_BRASS.r,C_BRASS.g,C_BRASS.b,0.45))
	var x := r.position.x+18.0
	if hint_action:
		var key := Rect2(r.position.x+7,r.position.y+6,24,24)
		_pill(key,C_BRASS,Color(0,0,0,0),6.0)
		_center_text(key.get_center(),"E",13,Color(0.08,0.10,0.09),bold)
		x = key.end.x+10.0
	_text(Vector2(x,r.position.y+23),hint_text,15,C_BONE)

func _draw_feed() -> void:
	var fy := 300.0
	for row in feed:
		var a: float = clampf(float(row["life"]),0.0,1.0)
		_text(Vector2(size.x-340,fy),str(row["text"]),12,Color(0.95,0.88,0.72,0.85*a),HORIZONTAL_ALIGNMENT_RIGHT,300)
		draw_circle(Vector2(size.x-30,fy-4),2.5,Color(C_RUST.r,C_RUST.g,C_RUST.b,a))
		fy += 20

# ---------------------------------------------------------------- mappa e risorse
func _draw_radar(now: float) -> void:
	var c := Vector2(size.x-134,110)
	var radius := 72.0
	draw_arc(c,radius+6.0,0,TAU,96,Color(C_BRASS.r,C_BRASS.g,C_BRASS.b,0.75),1.5,true)
	for k in range(4):
		var pts := PackedVector2Array()
		for step in range(49):
			var a := TAU*step/48.0
			var rr := 14.0+k*14.0+sin(a*3.0+k*1.7)*5.0+cos(a*5.0-k)*2.0
			pts.append(c+Vector2(cos(a),sin(a)*0.94)*minf(rr,radius-6.0))
		draw_polyline(pts,Color(0.60,0.74,0.64,0.12),1.0,true)
	var forward := _player_map_forward()
	draw_colored_polygon(PackedVector2Array([c,c+forward.rotated(-0.5)*(radius-6),c+forward.rotated(0.5)*(radius-6)]),Color(0.90,0.80,0.58,0.07))
	var sweep := fmod(now*0.52,TAU)
	draw_arc(c,radius-8,sweep-0.35,sweep,18,Color(0.74,0.84,0.68,0.08),8,true)
	for enemy in world.targets:
		if not is_instance_valid(enemy) or enemy.dead: continue
		_map_blip(c,enemy.position,C_RUST,3.0)
	for actor in world.actors.values():
		if actor != world.player: _map_blip(c,actor.position,C_TEAL,2.6)
	if world.get("zone_life"):
		for sack in world.zone_life.sacks:
			_map_blip(c,sack["node"].global_position,C_BRASS,3.6)
	var dir := forward.normalized()
	draw_colored_polygon(PackedVector2Array([c+dir*8,c+dir.rotated(2.5)*6,c+dir.rotated(-2.5)*6]),C_BONE)
	# Nord sul bordo: unica scritta della mappa.
	var north := c+Vector2(0,-(radius+6.0))
	_pill(Rect2(north-Vector2(9,9),Vector2(18,18)),Color(0.06,0.10,0.10,0.9),C_BRASS_SOFT)
	_center_text(north,"N",10,C_BRASS,bold)

func _draw_resources() -> void:
	# Crediti, teste e allerta sotto la mappa: icone e numeri, niente etichette.
	var p = world.player
	var y := 210.0
	var x := size.x-228.0
	draw_circle(Vector2(x,y),7,C_BRASS)
	draw_circle(Vector2(x,y),4,Color(0.55,0.40,0.18))
	_text(Vector2(x+12,y+5),str(p.credits),14,C_BONE,HORIZONTAL_ALIGNMENT_LEFT,-1,bold)
	x += 52.0
	_skull(Vector2(x,y),C_BONE)
	_text(Vector2(x+12,y+5),str(p.carried_heads),14,C_BONE,HORIZONTAL_ALIGNMENT_LEFT,-1,bold)
	x += 44.0
	# Esche dello sceriffo: fiammella e numero.
	var flame := Vector2(x,y)
	draw_colored_polygon(PackedVector2Array([flame+Vector2(0,-8),flame+Vector2(5,0),flame+Vector2(3,6),flame+Vector2(-3,6),flame+Vector2(-5,0)]),C_BRASS if p.baits>0 else Color(1,1,1,0.25))
	draw_colored_polygon(PackedVector2Array([flame+Vector2(0,-2),flame+Vector2(2,3),flame+Vector2(-2,3)]),Color("ffe2a8") if p.baits>0 else Color(1,1,1,0.15))
	_text(Vector2(x+10,y+5),str(p.baits),14,C_BONE,HORIZONTAL_ALIGNMENT_LEFT,-1,bold)
	x += 40.0
	if world.get("zone_life"):
		# Scatoletta: cibo totale (Q per mangiare).
		draw_rect(Rect2(Vector2(x-5,y-7),Vector2(10,14)),Color("b23a2e"))
		draw_rect(Rect2(Vector2(x-5,y-7),Vector2(10,3)),Color("c9ccc8"))
		_text(Vector2(x+10,y+5),str(world.zone_life.food_count()),14,C_BONE,HORIZONTAL_ALIGNMENT_LEFT,-1,bold)
		x += 40.0
	if Session.online:
		_text(Vector2(size.x-190,y+26),Localization.t("SQUADRA {0}/4", [world.actors.size()]),11,C_TEAL)

func _skull(c: Vector2, color: Color) -> void:
	draw_circle(c+Vector2(0,-1.5),6.0,color)
	draw_rect(Rect2(c+Vector2(-3.5,2.5),Vector2(7,4)),color)
	draw_circle(c+Vector2(-2.3,-1.5),1.6,Color(0.08,0.10,0.10))
	draw_circle(c+Vector2(2.3,-1.5),1.6,Color(0.08,0.10,0.10))

# ---------------------------------------------------------------- zaino
func _draw_hotbar() -> void:
	# Tasche come in How to Fish: solo quelle che hai, ognuna col modello vero, contorno su quella scelta e nome sopra.
	# In più: pezzi ×N, colpi per le armi da fuoco, frecce per l'arco.
	var a = world.player
	var total: float = a.inventory_slots*SLOT+(a.inventory_slots-1)*GAP
	var y0 := size.y-88.0
	var x0 := size.x*0.5-total*0.5
	for i in range(a.inventory_slots):
		var id: String = a.hotbar[i]
		var filled: bool = id != ""
		var active: bool = i == a.slot
		var rect := Rect2(x0+i*(SLOT+GAP),y0,SLOT,SLOT)
		if active:
			rect = rect.grow(SLOT*0.04)
			# alone caldo attorno alla tasca scelta, poi vetro chiaro e bordo ottone
			_pill(rect.grow(4.0),Color(C_LINE.r,C_LINE.g,C_LINE.b,0.14),Color(0,0,0,0),13.0)
			_pill(rect,Color(0.30,0.33,0.27,0.55),C_LINE,9.0,2)
		else:
			_pill(rect,Color(0.06,0.12,0.13,0.18 if filled else 0.10),Color(1,1,1,0.14 if filled else 0.06),9.0)
		# numero del tasto in un piccolo distintivo
		var badge := Rect2(rect.position+Vector2(4,4),Vector2(15,15))
		_pill(badge,C_LINE if active else Color(0,0,0,0.35),Color(0,0,0,0),5.0)
		_center_text(badge.get_center(),str(i+1),10,Color(0.08,0.10,0.09) if active else C_MUTED,bold)
		if filled:
			var icon: Texture2D = ItemIcons.get_icon(id)
			if icon: draw_texture_rect(icon,rect.grow(-4.0),false)
			else: _glyph(_glyph_id(id),rect.get_center()+Vector2(0,2))
			var how_many: int = int(a.items.get(id,0))
			if how_many > 1:
				_text(rect.position+Vector2(rect.size.x-6,rect.size.y-5),"×%d" % how_many,12,C_LINE,HORIZONTAL_ALIGNMENT_RIGHT,-1,bold)
			elif id == "bow":
				_text(rect.position+Vector2(rect.size.x-6,rect.size.y-5),"x%d" % a.arrows,11,C_BRASS if a.arrows > 0 else C_MUTED,HORIZONTAL_ALIGNMENT_RIGHT,-1,bold)
			elif Arsenal.is_gun(id) and active:
				_text(rect.position+Vector2(rect.size.x-6,rect.size.y-5),"%d/%d" % [a.magazine,Arsenal.magazine(id)],11,C_LINE,HORIZONTAL_ALIGNMENT_RIGHT,-1,bold)
		if active and a.reload_left > 0:
			draw_arc(rect.get_center(),22,-PI/2,-PI/2+TAU*clampf(1.0-a.reload_left/reload_total,0.0,1.0),40,C_BRASS,3,true)
	# Nome dell'oggetto in mano per un istante dopo il cambio.
	if weapon_pulse > 0 and a.equipped != "":
		var alpha: float = clampf(weapon_pulse,0,1)
		var label: String = ItemInfo.title(a.equipped).to_upper()
		if int(a.items.get(a.equipped,0)) > 1: label += " ×%d" % int(a.items[a.equipped])
		_center_text(Vector2(size.x*0.5,y0-16),label,14,Color(C_BONE.r,C_BONE.g,C_BONE.b,alpha),bold)
	# [Q] tenuto premuto: forza del lancio attorno al mirino.
	# Il cerchio della carica compare solo quando Q è tenuta: il tocco breve lascia l'oggetto.
	if world.survival.throw_hold >= world.survival.THROW_TAP:
		draw_arc(size*0.5,26,-PI/2,-PI/2+TAU*clampf((world.survival.throw_hold-world.survival.THROW_TAP)/world.survival.THROW_CHARGE,0.02,1.0),40,C_LINE,3,true)

## Icona della barra: le armi ZX usano il disegno della loro famiglia (ascia, coltello, pistola).
func _glyph_id(weapon: String) -> String:
	if WEAPON_NAMES.has(weapon): return weapon
	if weapon == "bow": return "bow"
	if ItemInfo.is_item(weapon): return "pistol"
	match Arsenal.tier(weapon):
		"gun": return "pistol"
		"light": return "knife"
	return "axe"

func _draw_vehicle() -> void:
	var r := Rect2(size.x*0.5-80,size.y-92,160,62)
	_pill(r,Color(0.04,0.08,0.08,0.62),C_BRASS_SOFT,16.0)
	_center_text(Vector2(size.x*0.5,r.position.y+26),"%d" % roundi(absf(world.expedition.car.speed)*3.6),28,C_BONE,bold)
	_center_text(Vector2(size.x*0.5,r.position.y+50),"KM/H",10,C_SAGE)

func _glyph(id: String, c: Vector2) -> void:
	var steel := Color("cfd7d1")
	var edge := Color("eef3ed")
	var wood := Color("9a7448")
	var dark := Color("202825")
	if id == "axe":
		draw_line(c+Vector2(-10,14),c+Vector2(5,-13),wood,4,true)
		draw_colored_polygon(PackedVector2Array([c+Vector2(1,-17),c+Vector2(16,-12),c+Vector2(19,-1),c+Vector2(7,-4),c+Vector2(3,-10)]),steel)
		draw_line(c+Vector2(16,-12),c+Vector2(19,-6),edge,2,true)
	elif id == "bow":
		draw_arc(c+Vector2(-6,0),17,-1.25,1.25,18,wood,3,true)
		draw_line(c+Vector2(-6,0)+Vector2(cos(-1.25),sin(-1.25))*17,c+Vector2(-6,0)+Vector2(cos(1.25),sin(1.25))*17,edge,1,true)
		draw_line(c+Vector2(-2,0),c+Vector2(17,0),wood,2,true)
		draw_colored_polygon(PackedVector2Array([c+Vector2(17,-3),c+Vector2(22,0),c+Vector2(17,3)]),steel)
	elif id == "knife":
		draw_line(c+Vector2(-11,13),c+Vector2(-2,4),Color(0.16,0.15,0.13),7,true)
		draw_colored_polygon(PackedVector2Array([c+Vector2(-2,7),c+Vector2(3,1),c+Vector2(16,-15)]),steel)
		draw_line(c+Vector2(3,1),c+Vector2(16,-15),edge,1,true)
	else:
		draw_colored_polygon(PackedVector2Array([c+Vector2(-15,-4),c+Vector2(8,-4),c+Vector2(15,-1),c+Vector2(15,4),c+Vector2(-2,4),c+Vector2(-5,9),c+Vector2(-12,9),c+Vector2(-15,3)]),steel)
		draw_rect(Rect2(c+Vector2(-10,3),Vector2(7,11)),Color("333a35"))
		draw_circle(c+Vector2(-12,-1),1.4,dark)

func _player_map_forward() -> Vector2:
	var yaw: float = world.player.rig.yaw
	var f := Vector2(-sin(yaw),-cos(yaw))
	if f.length_squared() < 0.01: f = Vector2.UP
	return f.normalized()

func _map_blip(center: Vector2, point: Vector3, color: Color, radius: float) -> void:
	var p := Vector2(point.x-world.player.position.x,point.z-world.player.position.z)*2.0
	if p.length() > 64.0: return
	var pos := center+p
	draw_circle(pos,radius+3.0,Color(color.r,color.g,color.b,0.12))
	draw_circle(pos,radius,color)
