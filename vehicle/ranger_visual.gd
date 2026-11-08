# Visual of the 04 / RANGER 4x4: model, 3 repair phases, opening doors/hood/tailgate, wheels, steering, lights.
# Used by vehicle/expedition_car.gd (campaign) and ui/camp/camp_vehicle.gd (menu). Front = -Z, driver = -X.
#   Phase 1: wreck (rust, smashed glass, flat rear tyre, hood up). Each part you pick up appears in place:
#            BATTERIA -> Fix_Battery, CINGHIA MOTORE -> Fix_Belt, TANICA CARBURANTE -> Fix_FuelCap.
#   Phase 2: all parts found, repair in progress (taped windscreen, primer door, plywood window).
#   Phase 3: repaired (fresh paint, bull bar, light bar, headlights on).
extends Node3D

const SCENE := preload("res://art/zx_vehicle/SM_Veh_Ranger4x4.glb")
const DOOR_SIGN := {"Door_FL": -1.0, "Door_RL": -1.0, "Door_FR": 1.0, "Door_RR": 1.0}   # hinges at the front edge: + swings into the cabin on the left
const SEAT_DOORS := ["Door_FL", "Door_FR", "Door_RL", "Door_RR"]   # same order as expedition_car SEATS
const DOOR_OPEN := 70.0
const HOOD_OPEN := 58.0
const TAILGATE_OPEN := 85.0
const WHEEL_RADIUS := 0.42
const FIX_NODES := ["Fix_Battery", "Fix_Belt", "Fix_FuelCap"]       # campaign.PART_NAMES order

var model: Node3D
var phase := 0
var parts := [false, false, false]
var wheels: Array[Node3D] = []
var front_wheels: Array[Node3D] = []
var lights: Array[SpotLight3D] = []
var steer_mesh: Node3D
var _pivots := {}
var _target := {}
var _close_at := {}
var _lights_on := false
var _spin := 0.0


func _init() -> void:
	model = SCENE.instantiate()
	add_child(model)
	for n in ["Door_FL", "Door_FR", "Door_RL", "Door_RR", "Hood", "Tailgate"]:
		_pivots[n] = model.find_child(n, true, false)
		_target[n] = 0.0
	for n in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
		var w := model.find_child(n, true, false) as Node3D
		wheels.append(w)
		if n.begins_with("Wheel_F"):
			front_wheels.append(w)
	steer_mesh = model.find_child("SteeringWheel_Mesh", true, false)
	_crisp(model)
	for side in [-0.66, 0.66]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(side, 0.9, -1.72)
		lamp.spot_range = 60.0
		lamp.spot_angle = 32.0
		lamp.light_color = Color("fff1ca")
		lamp.light_energy = 2.0
		lamp.shadow_enabled = false
		add_child(lamp)
		lights.append(lamp)
	set_phase(1)


## Palette textures must stay pixel-sharp; the glass material becomes transparent.
func _crisp(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null:
				continue
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mat.roughness = 1.0 if not String(mat.resource_name).contains("Glass") else 0.08
			if String(mat.resource_name).contains("Glass"):
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.32
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			elif mat.emission_texture:
				mat.emission_enabled = true
				mat.emission = Color.BLACK
				mat.emission_energy_multiplier = 2.5
	for c in node.get_children():
		_crisp(c)


## Campaign state -> look. stage 0 = collecting, 1 = repairing, >=2 = repaired (see world/campaign/campaign.gd).
func update_state(collected: Array, stage: int, repaired: bool, repairing: bool) -> void:
	var p := 3 if repaired else (2 if stage >= 1 else 1)
	if p != phase or collected != parts:
		parts = collected.duplicate()
		set_phase(p)
	_target["Hood"] = HOOD_OPEN if (p == 1 or repairing) else 0.0
	set_lights(p == 3)


func set_phase(p: int) -> void:
	phase = clampi(p, 1, 3)
	for node in model.find_children("*", "", true, false):
		var n := String(node.name)
		if n.ends_with("_P1") or n.ends_with("_P2") or n.ends_with("_P3"):
			(node as Node3D).visible = n.ends_with("_P%d" % phase)
	for i in FIX_NODES.size():
		var f := model.find_child(FIX_NODES[i], true, false) as Node3D
		if f:
			f.visible = phase >= 2 or (i < parts.size() and parts[i])
	set_lights(phase == 3 and _lights_on)


func set_lights(on: bool) -> void:
	_lights_on = on
	for l in lights:
		l.visible = on and phase == 3


## Opens the door of a seat for a moment (getting in / out).
func pulse_door(seat: int, hold := 1.1) -> void:
	if seat < 0 or seat >= SEAT_DOORS.size():
		return
	open_door(SEAT_DOORS[seat], true)
	_close_at[SEAT_DOORS[seat]] = Time.get_ticks_msec() + int(hold * 1000.0)


func open_door(door: String, open := true) -> void:
	if not _target.has(door):
		return
	if door == "Hood":
		_target[door] = HOOD_OPEN if open else 0.0
	elif door == "Tailgate":
		_target[door] = TAILGATE_OPEN if open else 0.0
	else:
		_target[door] = DOOR_OPEN if open else 0.0
	_close_at.erase(door)


func is_open(door: String) -> bool:
	return _target.get(door, 0.0) > 1.0


func steer(amount: float) -> void:
	for w in front_wheels:
		w.rotation.y = amount * 0.55
	if steer_mesh:
		steer_mesh.rotation.y = amount * 2.4


func roll(distance: float) -> void:
	_spin -= distance / WHEEL_RADIUS
	for w in wheels:
		w.rotation.x = _spin


func marker(name_: String) -> Node3D:
	return model.find_child(name_, true, false) as Node3D


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	for door in _close_at.keys():
		if now >= _close_at[door]:
			_target[door] = 0.0
			_close_at.erase(door)
	for door in _pivots:
		var piv := _pivots[door] as Node3D
		if piv == null:
			continue
		var goal := deg_to_rad(_target[door])
		if door == "Hood":
			piv.rotation.x = lerp_angle(piv.rotation.x, goal, 1.0 - exp(-delta * 7.0))
		elif door == "Tailgate":
			piv.rotation.y = lerp_angle(piv.rotation.y, -goal, 1.0 - exp(-delta * 7.0))
		else:
			piv.rotation.y = lerp_angle(piv.rotation.y, goal * DOOR_SIGN[door], 1.0 - exp(-delta * 9.0))
