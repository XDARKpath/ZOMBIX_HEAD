# Economia; autoload EconomyManager, nessun figlio richiesto.
# Interfaccia predisposta: la logica arriva nelle fasi successive.
extends Node

signal heads_changed(carried: int, banked: int)
signal transaction_completed(kind: String, amount: int)
