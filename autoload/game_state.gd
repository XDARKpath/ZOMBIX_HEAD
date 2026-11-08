# Stato globale; autoload GameState, nessun figlio richiesto.
# Interfaccia predisposta: la logica arriva nelle fasi successive.
extends Node

signal objective_changed(text: String)
signal zone_unlocked(zone_id: int)

const PROJECT_PHASE: int = 1
const CONTENT_VERSION: String = "0.1.0"
