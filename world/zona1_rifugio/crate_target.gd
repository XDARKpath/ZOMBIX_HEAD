extends Node
# Ponte tra i colpi del giocatore (melee_controller._aim_strike usa receive_hit sulle
# hitbox con meta "target") e le casse distruttibili del kit ambiente.
var crate: Node3D

func receive_hit(_zone: String, amount: float, force: Vector3, _weapon: String, _heavy: bool = false) -> bool:
	if not is_instance_valid(crate) or not crate.has_method("damage"): return false
	crate.damage(amount, crate.global_position + Vector3.UP * 0.5, force)
	return true
