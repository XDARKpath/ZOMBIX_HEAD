extends SceneTree
# Negozi senza pannello: si guarda l'arma appesa (o lo zaino sul bancone) e si preme E (world/campaign/zx_shops.gd).
# Foto: res://../screenshots/shopwall-<vista>.png
var fails := 0
func _initialize(): call_deferred("run")
func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1
func shot(id: String, wait := 0.4):
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/shopwall-" + id + ".png"))
## Mette il giocatore davanti all'oggetto esposto e lo fa guardare al suo centro.
func face(p, zx, d: Dictionary, back: Vector3) -> void:
	var c: Vector3 = zx._center(d.node)
	p.global_position = Vector3(c.x, c.y - 1.5, c.z) + Vector3(back.x, 0, back.z)
	var eye: Vector3 = p.global_position + Vector3.UP * p.eye_height
	var dir: Vector3 = (c - eye).normalized()
	p.rig.yaw = atan2(-dir.x, -dir.z)
	p.rig.pitch = asin(clampf(dir.y, -1.0, 1.0))
	p.rig.reset_follow()
	await process_frame
	await process_frame
func find(zx, id: String, shop = null) -> Dictionary:
	# shop null = il pannello di Big Earl (Zona 1)
	for d in zx.displays:
		if d.id == id and d.shop == shop and is_instance_valid(d.node): return d
	return {}
func run():
	var world = load("res://world/zona1_rifugio/zombix.tscn").instantiate()
	root.add_child(world)
	world.automated = true
	root.get_node("Session").launch()
	await create_timer(0.8).timeout
	var gps = world.get_node("Interface").find_child("RouteGPS", true, false)
	if gps: gps.opened = false
	var p = world.player
	p.set_physics_process(false)
	p.rig.set_physics_process(false)
	var zx = world.survival.zx
	check(not find(zx, "pistol").is_empty() and not find(zx, "bow").is_empty() and not find(zx, "runic_axe").is_empty(), "Armi del pannello di Big Earl in vendita guardandole")
	check(zx.shops.size() > 0 and not find(zx, "lmg", zx.shops[3]).is_empty(), "Anche i negozi delle zone dopo vendono dal pannello")
	var machete: Dictionary = find(zx, "machete")
	var armory: Node3D = machete.node.get_parent()
	var back: Vector3 = armory.global_basis.z.normalized() * 1.9
	await face(p, zx, machete, back)
	check(zx.target(p).get("id", "") == "machete", "Guardando il machete lo si punta (%s)" % zx.target(p).get("id", "nessuno"))
	p.credits = 10
	p.owned.assign(["axe"])
	check(zx.context(p).contains("MANCANO"), "Senza crediti il cartellino dice quanto manca (%s)" % zx.context(p))
	check(zx.request(p) and not "machete" in p.owned, "E senza crediti: niente acquisto")
	await shot("poor")
	p.credits = 500
	check(zx.context(p).begins_with("E  COMPRA MACHETE"), "Con i crediti: E COMPRA (%s)" % zx.context(p))
	check(zx.request(p) and "machete" in p.owned and p.equipped == "machete" and p.credits == 430, "E: machete comprato, 70 crediti scalati, in mano")
	await shot("bought", 0.5)
	check(zx.context(p).contains("GIÀ TUA"), "Poi il cartellino dice GIÀ TUA")
	# zaino sul bancone
	var pack: Dictionary = find(zx, "pack", null)
	await face(p, zx, pack, armory.global_basis.z.normalized() * 1.2)
	var slots: int = p.inventory_slots
	p.credits = 500
	check(zx.target(p).get("id", "") == "pack" and zx.request(p) and p.inventory_slots == slots + 1, "Zaino comprato dal bancone: +1 slot")
	await shot("pack")
	# negozio della zona 4 (Spaccio del Deposito)
	var lmg: Dictionary = find(zx, "lmg", zx.shops[3])
	await face(p, zx, lmg, zx.shops[3].global_basis.z.normalized() * 2.0)
	p.credits = 2000
	check(zx.target(p).get("id", "") == "lmg" and zx.request(p) and "lmg" in p.owned and p.magazine == 100, "Mitragliatrice comprata guardandola al Deposito")
	await shot("deposito")
	check(not world.survival.shop_open and not world.ui_open, "Nessun pannello a schermo")
	print("SHOP WALL ", "OK" if fails == 0 else "FALLITO %d" % fails)
	quit()
