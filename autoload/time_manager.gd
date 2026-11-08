# Tempo; autoload TimeManager, nessun figlio richiesto.
# Interfaccia predisposta: la logica arriva nelle fasi successive.
extends Node

signal night_changed(is_night: bool)
signal sunset_warning

# Il tempo resta fermo nell’anteprima: il ciclo sarà implementato in Fase 7.
