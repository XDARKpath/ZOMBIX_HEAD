# Stato globale; autoload GameState, nessun figlio richiesto.
# Interfaccia predisposta: la logica arriva nelle fasi successive.
extends Node

signal objective_changed(text: String)
signal zone_unlocked(zone_id: int)

const PROJECT_PHASE: int = 1
const CONTENT_VERSION: String = "0.1.0"

# Il TAA esiste solo in Forward+: dalle impostazioni del progetto Godot lo
# accendeva anche in Compatibility (OpenGL) e stampava un errore all'avvio.
func _ready() -> void:
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		get_tree().root.use_taa = true
