extends Node3D
# Pistola compatta originale: canna su +X e marker di presa/volata.
const Placeholder := preload("res://art/placeholders.gd")

func _ready() -> void:
	Placeholder.box(self, Vector3(0.055, 0.070, 0), Vector3(0.26, 0.060, 0.046), Color("5b6268"))
	Placeholder.box(self, Vector3(0.045, 0.028, 0), Vector3(0.22, 0.030, 0.040), Color("242a2d"))
	Placeholder.box(self, Vector3(-0.030, -0.030, 0), Vector3(0.058, 0.135, 0.046), Color("1d2225"))
	Placeholder.cylinder(self, Vector3(0.190, 0.070, 0), 0.014, 0.035, Color("14181a"), Vector3(0, 0, PI / 2))
	Placeholder.box(self, Vector3(0.120, 0.104, 0), Vector3(0.020, 0.016, 0.012), Color("151b20"))
	# Ponticello e grilletto: l'indice ci appoggia accanto e vi entra solo per sparare.
	Placeholder.box(self, Vector3(0.018, -0.020, 0), Vector3(0.050, 0.008, 0.014), Color("1d2225"))
	Placeholder.box(self, Vector3(0.042, -0.004, 0), Vector3(0.008, 0.028, 0.014), Color("1d2225"))
	Placeholder.box(self, Vector3(0.012, 0.000, 0), Vector3(0.006, 0.020, 0.008), Color("8d949a"))
	var Sockets := preload("res://art/weapons/grip_sockets.gd")
	Sockets.add(self, "Socket_RightHand", Vector3(-0.034, -0.034, 0), Vector3(0.10, -1, 0), Vector3.RIGHT, 0.024, "pistol")
	Sockets.add(self, "Socket_LeftHand", Vector3(-0.030, -0.058, -0.004), Vector3(-0.10, 1, 0), Vector3.RIGHT, 0.040, "clamp")
	_marker("GripMain", Vector3(-0.020, -0.040, 0))
	_marker("GripSupport", Vector3(0.060, 0.010, 0))
	_marker("Muzzle", Vector3(0.208, 0.070, 0))
	_marker("Magazine", Vector3(-0.030, -0.100, 0))

func _marker(marker_name: String, at: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = at
	add_child(marker)
