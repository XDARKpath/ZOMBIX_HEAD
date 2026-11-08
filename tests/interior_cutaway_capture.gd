extends SceneTree
# Concept cutaway: nasconde solo i tetti, non i muri, e affianca i due interni.
# Serve a controllare che la cella, il banco e gli arredi si leggano dall'alto.
var world:Node3D
var camera:Camera3D
var out_dir:String
const PANEL:=Vector2i(800,900)

func _initialize() -> void:
	call_deferred("run")

func _hide_roof(node:Node) -> void:
	if node is MeshInstance3D:
		var n:String=node.name.to_lower()
		if n.contains("tetto") or n.contains("lamiera"):
			node.visible=false
	for child in node.get_children():
		_hide_roof(child)

func _panel(office:Node3D,other:Node3D,name:String) -> Image:
	other.visible=false
	camera.global_position=office.to_global(Vector3(10.5,8.0,17.0))
	camera.look_at(office.to_global(Vector3(-0.4,1.0,4.0)),Vector3.UP)
	camera.current=true
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image()
	img.resize(PANEL.x,PANEL.y,Image.INTERPOLATE_BILINEAR)
	img.save_png(out_dir+"/cutaway-"+name+".png")
	print("CUTAWAY ",name)
	other.visible=true
	return img

func run() -> void:
	out_dir=ProjectSettings.globalize_path("res://../screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	world=load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated=true
	root.get_node("Session").launch()
	await create_timer(0.3).timeout
	world.player.set_physics_process(false)
	world.player.rig.set_physics_process(false)
	world.player.controls_enabled=false
	world.expedition.car.set_physics_process(false)
	world.expedition.car.visible=false
	world.player.visible=false
	world.get_node("Interface").hide()
	for e in world.targets:
		e.set_physics_process(false);e.velocity=Vector3.ZERO
	root.size=PANEL
	camera=Camera3D.new()
	world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=15.8
	camera.near=0.05
	camera.far=80.0
	var village:Node=world.landscape.get_node_or_null("RefugeBuildings")
	if village==null:
		push_error("RefugeBuildings mancante")
		quit();return
	var sheriff:Node3D=village.get_node_or_null("SheriffOffice")
	var shop:Node3D=village.get_node_or_null("Armory")
	if sheriff==null or shop==null:
		push_error("Interni mancanti")
		quit();return
	_hide_roof(sheriff)
	_hide_roof(shop)
	var left:Image=await _panel(sheriff,shop,"sheriff")
	var right:Image=await _panel(shop,sheriff,"shop")
	var final:=Image.create(PANEL.x*2,PANEL.y,false,left.get_format())
	final.fill(Color("171713"))
	final.blit_rect(left,Rect2i(Vector2i.ZERO,PANEL),Vector2i.ZERO)
	final.blit_rect(right,Rect2i(Vector2i.ZERO,PANEL),Vector2i(PANEL.x,0))
	final.fill_rect(Rect2i(PANEL.x-3,0,6,PANEL.y),Color("b4975e"))
	final.fill_rect(Rect2i(0,0,PANEL.x*2,3),Color("24231e"))
	final.fill_rect(Rect2i(0,PANEL.y-3,PANEL.x*2,3),Color("24231e"))
	final.save_png(out_dir+"/interiors-cutaway.png")
	var preview:=final.duplicate()
	preview.resize(1200,675,Image.INTERPOLATE_LANCZOS)
	preview.save_png(out_dir+"/interiors-cutaway-preview.png")
	print("CONCEPT screenshots/interiors-cutaway.png")
	world.queue_free()
	await process_frame
	await process_frame
	quit()
