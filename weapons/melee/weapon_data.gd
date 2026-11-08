# Resource dati arma. Nessun nodo o figlio richiesto; usata da axe.tres.
extends Resource
class_name MeleeWeaponData

@export var display_name: String = "Accetta"
@export var damage: float = 26.0
@export var charged_damage: float = 58.0
@export var stamina_cost: float = 12.0
@export var charged_stamina_cost: float = 28.0
@export var charge_seconds: float = 0.65
@export var windup: float = 0.16
@export var active_seconds: float = 0.16
@export var recovery: float = 0.32
@export var charged_windup: float = 0.24
@export var charged_recovery: float = 0.46
@export var reach: float = 2.5
@export var knockback: float = 2.8
@export var charged_knockback: float = 5.0
@export var noise: float = 10.0
@export var price: int = 0
@export var tier: int = 1
@export var special_effect: String = ""
