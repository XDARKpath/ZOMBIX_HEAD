class_name ZombieMotionData
extends Resource
## Baked infected clips (see art/infected_motion.gd). Per clip: frames, loop, length,
## q = PackedFloat32Array [(frames+1) * bones * 4] skeleton-space rotation deltas (x,y,z,w; Godot axes),
## p = PackedFloat32Array [(frames+1) * 3] pelvis offset in metres for a 0.95 m pelvis.
@export var fps := 30
@export var bones: PackedStringArray = []
@export var pelvis_height := 0.95
@export var attacks := {}      # clip -> [length s, hit s, reach m, lunge m/s]
@export var clips := {}
