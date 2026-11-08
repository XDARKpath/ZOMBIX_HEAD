extends Control
# Ritratto procedurale dello sceriffo: tagli netti, niente texture o immagini.
# Disegnato nel rettangolo del pannello per restare leggibile a ogni risoluzione.

const INK := Color("0c1413")
const PANEL := Color("151d1b")
const PANEL_HI := Color("1d2824")
const AMBER := Color("d4aa6a")
const AMBER_SOFT := Color(0.83,0.67,0.42,0.38)
const TEAL := Color("72b9ad")
const BONE := Color("e8e2d3")
const SKIN := Color("d2ab80")
const SKIN_SHADE := Color("b78a61")
const SKIN_LIGHT := Color("e0bd90")
const HAIR := Color("d9d8ce")
const SUIT := Color("232b29")
const SUIT_HI := Color("2e3833")
const SHIRT := Color("c8c3b4")
const TIE := Color("3d2a25")
const LENS := Color("111a18")

var clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(true)

func _process(delta: float) -> void:
	clock += delta
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return
	var w := size.x
	var h := size.y
	var frame := _chamfer(Rect2(3,3,w-6,h-6),10.0)
	draw_colored_polygon(frame,PANEL)
	draw_polyline(_closed(frame),Color(0.80,0.65,0.41,0.66),1.2,true)
	var inner := _chamfer(Rect2(7,7,w-14,h-14),7.0)
	draw_colored_polygon(inner,PANEL_HI)
	# Trama tecnica: righe sottilissime e una lama di luce teal.
	for i in range(1,9):
		var y:float = 8.0+(h-16.0)*i/9.0
		draw_line(Vector2(9,y),Vector2(w-9,y),Color(1,1,1,0.022),1.0,true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w*0.62,7),Vector2(w-7,7),Vector2(w-7,h*0.43),Vector2(w*0.43,h*0.62)
	]),Color(0.35,0.62,0.58,0.045))
	# Angoli a squadra.
	var c:=11.0
	for corner in [Vector2(8,8),Vector2(w-8,8),Vector2(8,h-8),Vector2(w-8,h-8)]:
		var sx:float = 1.0 if corner.x < w*0.5 else -1.0
		var sy:float = 1.0 if corner.y < h*0.5 else -1.0
		draw_line(corner,corner+Vector2(sx*c,0),AMBER,1.7,true)
		draw_line(corner,corner+Vector2(0,sy*c),AMBER,1.7,true)
	# Busto e spalle.
	var cx:=w*0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(w*0.10,h*0.97),Vector2(w*0.19,h*0.70),
		Vector2(w*0.36,h*0.62),Vector2(cx,h*0.60),
		Vector2(w*0.64,h*0.62),Vector2(w*0.81,h*0.70),Vector2(w*0.90,h*0.97)
	]),SUIT)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w*0.18,h*0.75),Vector2(w*0.36,h*0.63),Vector2(cx,h*0.60),
		Vector2(w*0.64,h*0.63),Vector2(w*0.82,h*0.75),Vector2(w*0.68,h*0.90),
		Vector2(w*0.32,h*0.90)
	]),SUIT_HI)
	# Camicia e cravatta.
	draw_colored_polygon(PackedVector2Array([
		Vector2(w*0.39,h*0.65),Vector2(cx,h*0.70),Vector2(w*0.61,h*0.65),
		Vector2(w*0.57,h*0.97),Vector2(w*0.43,h*0.97)
	]),SHIRT)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx-w*0.035,h*0.69),Vector2(cx+w*0.035,h*0.69),
		Vector2(cx+w*0.055,h*0.82),Vector2(cx,h*0.94),Vector2(cx-w*0.055,h*0.82)
	]),TIE)
	draw_line(Vector2(cx-w*0.03,h*0.71),Vector2(cx,h*0.86),Color(0.25,0.18,0.16),1.0,true)
	# Collo.
	draw_rect(Rect2(cx-w*0.105,h*0.51,w*0.21,h*0.17),SKIN_SHADE)
	draw_rect(Rect2(cx-w*0.105,h*0.51,w*0.16,h*0.17),SKIN)
	# Testa squadrata con orecchie e mascella.
	var head_top:=h*0.155
	var head_bottom:=h*0.53
	var head_left:=w*0.265
	var head_right:=w*0.735
	var head_mid:=w*0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(head_left+7,head_top),Vector2(head_right-7,head_top),
		Vector2(head_right,head_top+18),Vector2(head_right,head_bottom-16),
		Vector2(head_right-15,head_bottom),Vector2(head_left+15,head_bottom),
		Vector2(head_left,head_bottom-16),Vector2(head_left,head_top+18)
	]),SKIN)
	# Luce e ombra laterali.
	draw_colored_polygon(PackedVector2Array([
		Vector2(head_left+6,head_top+12),Vector2(head_left+26,head_top+7),
		Vector2(head_left+30,head_bottom-15),Vector2(head_left+15,head_bottom-4),
		Vector2(head_left,head_bottom-16),Vector2(head_left,head_top+18)
	]),SKIN_SHADE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(head_right-28,head_top+6),Vector2(head_right-7,head_top+1),
		Vector2(head_right,head_top+18),Vector2(head_right,head_bottom-25),
		Vector2(head_right-25,head_bottom-18)
	]),SKIN_LIGHT)
	# Capelli rasati e basette chiare.
	draw_colored_polygon(PackedVector2Array([
		Vector2(head_left+4,head_top+18),Vector2(head_left+13,head_top+1),
		Vector2(head_mid,head_top-3),Vector2(head_right-13,head_top+1),
		Vector2(head_right-3,head_top+18),Vector2(head_right-18,head_top+12),
		Vector2(head_mid,head_top+8),Vector2(head_left+17,head_top+13)
	]),HAIR)
	for side in [-1.0,1.0]:
		var ear_x:float = head_mid+side*(head_right-head_left)*0.5
		draw_rect(Rect2(ear_x-6,head_top+37,12,25),SKIN_SHADE)
	# Occhiali da aviatore: due lenti nere e un ponte sottile.
	var eye_y:=head_top+44
	draw_colored_polygon(PackedVector2Array([
		Vector2(head_left+15,eye_y-4),Vector2(head_mid-7,eye_y-2),
		Vector2(head_mid-12,eye_y+17),Vector2(head_left+22,eye_y+15)
	]),LENS)
	draw_colored_polygon(PackedVector2Array([
		Vector2(head_mid+7,eye_y-2),Vector2(head_right-15,eye_y-4),
		Vector2(head_right-19,eye_y+15),Vector2(head_mid+12,eye_y+17)
	]),LENS)
	draw_line(Vector2(head_mid-7,eye_y+1),Vector2(head_mid+7,eye_y+1),Color("736048"),2.0,true)
	draw_line(Vector2(head_left+20,eye_y+2),Vector2(head_left+38,eye_y+7),Color(0.80,0.69,0.50,0.50),1.0,true)
	draw_line(Vector2(head_mid+14,eye_y+2),Vector2(head_mid+34,eye_y+8),Color(0.80,0.69,0.50,0.45),1.0,true)
	# Naso, bocca, mento: pochi tagli, nessuna curva.
	draw_line(Vector2(head_mid,eye_y+19),Vector2(head_mid+4,eye_y+36),SKIN_SHADE,2.0,true)
	draw_line(Vector2(head_mid-17,eye_y+46),Vector2(head_mid+16,eye_y+45),Color("6a4b3b"),1.8,true)
	draw_line(Vector2(head_mid-10,eye_y+56),Vector2(head_mid+11,eye_y+55),Color(0.48,0.31,0.25,0.5),1.2,true)
	# Sigaretta e brago.
	draw_line(Vector2(head_mid+17,eye_y+45),Vector2(head_mid+39,eye_y+43),Color("e8e0cf"),2.2,true)
	draw_circle(Vector2(head_mid+40,eye_y+42),2.4,Color("f18b58"))
	draw_circle(Vector2(head_mid+40,eye_y+42),4.8,Color(0.95,0.45,0.25,0.12))
	# Stella sul petto, a sinistra.
	_star(Vector2(w*0.29,h*0.82),w*0.037,AMBER)
	draw_circle(Vector2(w*0.29,h*0.82),w*0.027,Color("5f4a2e"))
	_star(Vector2(w*0.29,h*0.82),w*0.023,Color("f2cf88"))
	# Status teal e cornice bassa.
	var pulse:float = 0.45+0.35*(0.5+0.5*sin(clock*2.4))
	draw_circle(Vector2(w-17,17),3.2,Color(0.45,0.76,0.70,pulse))
	draw_circle(Vector2(w-17,17),1.3,Color("d8eee7"))
	draw_line(Vector2(w*0.12,h-9),Vector2(w*0.63,h-9),AMBER_SOFT,1.0,true)
	draw_line(Vector2(w*0.12,h-6),Vector2(w*0.38,h-6),Color(0.45,0.72,0.66,0.25),1.0,true)

func _star(c:Vector2,radius:float,color:Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var a:float=-PI/2+i*PI/5
		var r:float=radius if i%2==0 else radius*0.43
		points.append(c+Vector2(cos(a),sin(a))*r)
	draw_colored_polygon(points,color)

func _chamfer(rect:Rect2,cut:float) -> PackedVector2Array:
	var p:=rect.position
	var e:=rect.end
	return PackedVector2Array([
		Vector2(p.x+cut,p.y),Vector2(e.x-cut,p.y),Vector2(e.x,p.y+cut),
		Vector2(e.x,e.y-cut),Vector2(e.x-cut,e.y),Vector2(p.x+cut,e.y),
		Vector2(p.x,e.y-cut),Vector2(p.x,p.y+cut)
	])

func _closed(points:PackedVector2Array) -> PackedVector2Array:
	var out:=points.duplicate()
	out.append(points[0])
	return out
