class_name ZXWeapons
extends RefCounted
## Weapon registry: which model, which animation set, how it fires. Add your own entries here.
## Keys used by ZXPlayer: scene, idle, aim, fire, fire_auto, auto, rate, reload, attacks, heavy, block,
## draw, sheathe, sheath (scene of the scabbard), mount (bone the sheathed weapon hangs from).

const W := "res://art/env/weapons/"

const DEFS := {
	"unarmed": {"name": "Pugni", "scene": "", "idle": "Player_Idle_Unarmed", "attacks": ["Player_Melee_Knife_Slash"]},
	"assault_rifle": {"name": "Fucile d'assalto", "scene": W + "SM_Wep_AssaultRifle.glb", "class": "rifle",
		"aim": "Player_Rifle_Aim_In", "fire_auto": "Player_Rifle_Fire_Auto", "auto": true, "rate": 0.1,
		"reload": "Player_Rifle_Reload", "mag": 30},
	"pump_shotgun": {"name": "Fucile a pompa", "scene": W + "SM_Wep_PumpShotgun.glb", "class": "rifle",
		"aim": "Player_Rifle_Aim_In", "fire": "Player_Shotgun_Fire_Pump", "reload": "Player_Shotgun_Reload_Shell", "mag": 6,
		"pellets": 8},
	"sniper_rifle": {"name": "Fucile di precisione", "scene": W + "SM_Wep_SniperRifle.glb", "class": "rifle",
		"aim": "Player_Sniper_Aim", "fire": "Player_Sniper_Fire_Bolt", "reload": "Player_Rifle_Reload", "mag": 5},
	"pistol": {"name": "Pistola", "scene": "res://art/menu_batch2/SM_Wep_Pistol.glb", "class": "pistol", "idle": "Player_Pistol_Idle",
		"aim": "Player_Pistol_Aim", "fire": "Player_Pistol_Fire", "reload": "Player_Pistol_Reload", "mag": 15},
	"revolver": {"name": "Revolver", "scene": W + "SM_Wep_Revolver.glb", "class": "pistol", "idle": "Player_Pistol_Idle",
		"aim": "Player_Pistol_Aim", "fire": "Player_Revolver_Fire", "reload": "Player_Revolver_Reload", "mag": 6},
	"smg": {"name": "SMG", "scene": W + "SM_Wep_SMG.glb", "class": "pistol", "idle": "Player_Pistol_Idle",
		"aim": "Player_Pistol_Aim", "fire_auto": "Player_SMG_Fire_Auto", "auto": true, "rate": 0.067,
		"reload": "Player_Pistol_Reload", "mag": 32},
	"katana": {"name": "Katana", "scene": W + "SM_Wep_Katana.glb", "class": "sword", "idle": "Player_Sword_Idle",
		"attacks": ["Player_Sword_Slash_1", "Player_Sword_Slash_2", "Player_Sword_Slash_3"], "heavy": "Player_Sword_Heavy",
		"block": "Player_Sword_Block", "parry": "Player_Sword_Parry_Riposte", "dodge": "Player_Sword_Dodge_Back",
		"draw": "Player_Katana_Draw_Iai", "sheathe": "Player_Katana_Sheathe",
		"sheath": W + "SM_Wep_Katana_Saya.glb", "mount": "katana_saya"},
	"longsword": {"name": "Spada medievale", "scene": W + "SM_Wep_Longsword.glb", "class": "sword", "idle": "Player_Sword_Idle",
		"attacks": ["Player_Sword_Slash_1", "Player_Sword_Slash_2"], "heavy": "Player_Sword_Heavy", "block": "Player_Sword_Block",
		"draw": "Player_Longsword_Draw", "sheath": W + "SM_Wep_Longsword_Scabbard.glb", "mount": "sword_back"},
	"fire_axe": {"name": "Ascia", "scene": "res://art/zx_fp/SM_FP_Axe.glb", "class": "axe", "idle": "Player_Axe_Idle",
		"attacks": ["Player_Axe_Swing_Horizontal"], "heavy": "Player_Axe_Chop_Overhead",
		"block": "Player_Axe_Block", "shove": "Player_Axe_Shove", "two_handed": true,
		"flavor": "Due mani, un colpo, nessuna porta chiusa."},
	# Armi aggiunte in Zona 1 (tools/incoming/convert_new_weapons.py): in prima persona usano il rig di Blender
	# di ascia e pala (player/viewmodel/fp_melee.gd), la spada a una mano.
	"runic_axe": {"name": "Ascia runica", "scene": W + "SM_Wep_RunicAxe.tscn", "class": "axe", "idle": "Player_Axe_Idle",
		"attacks": ["Player_Axe_Swing_Horizontal", "Player_Axe_Swing_Back"], "heavy": "Player_Axe_Chop_Overhead",
		"block": "Player_Axe_Block", "shove": "Player_Axe_Shove", "two_handed": true,
		"flavor": "Manico intagliato, lama incisa: pesa come una promessa."},
	"spartan_sword": {"name": "Spada spartana", "scene": W + "SM_Wep_SpartanSword.tscn", "class": "melee1h", "idle": "Player_Melee1H_Idle",
		"attacks": ["Player_Melee1H_Swing", "Player_Melee1H_Swing_Back"], "heavy": "Player_Melee1H_Slap",
		"flavor": "Corta, ricurva, fatta per tagliare da vicino."},
	# Arco (kit FPS low-poly-bow, tools/fp_bow/convert_bow_kit.py): silenzioso, frecce da recuperare.
	"bow": {"name": "Arco", "scene": W + "SM_Wep_Bow.tscn", "class": "rifle", "idle": "Player_Idle_Rifle",
		"aim": "Player_Rifle_Aim_In", "flavor": "Non fa rumore. Le frecce si riprendono."},
	"arrows": {"name": "Frecce ×10", "scene": W + "SM_Wep_Arrows.tscn", "class": "consumable",
		"flavor": "Dieci frecce di legno, punta d'acciaio."},
	"trout": {"name": "La Trota", "scene": W + "SM_Wep_Fun_Trout.glb", "class": "melee1h", "idle": "Player_Melee1H_Idle",
		"attacks": ["Player_Melee1H_Swing", "Player_Melee1H_Swing_Back"], "heavy": "Player_Melee1H_Slap",
		"flavor": "Spinta: assurda. Odore: peggio."},
	"baguette": {"name": "Baguette", "scene": W + "SM_Wep_Fun_Baguette.glb", "class": "melee1h", "idle": "Player_Melee1H_Idle",
		"attacks": ["Player_Melee1H_Swing", "Player_Melee1H_Swing_Back"], "heavy": "Player_Melee1H_Slap",
		"flavor": "Di tre giorni fa. Dura come un tondino."},
	"rubber_chicken": {"name": "Pollo di gomma", "scene": W + "SM_Wep_Fun_RubberChicken.glb", "class": "melee1h",
		"idle": "Player_Melee1H_Idle", "attacks": ["Player_Melee1H_Swing", "Player_Melee1H_Swing_Back"],
		"heavy": "Player_Melee1H_Slap", "flavor": "Squittisce all'impatto. Gli zombie la odiano."},
	# ---- shop weapons (see zx_shop_catalog.gd for which zone sells what)
	"sawn_off": {"name": "Doppietta a canne mozze", "scene": W + "SM_Wep_SawnOff.glb", "class": "rifle",
		"aim": "Player_Rifle_Aim_In", "fire": "Player_Rifle_Fire_Single", "reload": "Player_Break_Reload", "mag": 2, "pellets": 10},
	"flare_gun": {"name": "Pistola lanciarazzi", "scene": W + "SM_Wep_FlareGun.glb", "class": "pistol", "idle": "Player_Pistol_Idle",
		"aim": "Player_Pistol_Aim", "fire": "Player_Revolver_Fire", "reload": "Player_Pistol_Reload", "mag": 1, "flare": true,
		"flavor": "Illumina la notte. E l'infetto. Soprattutto l'infetto."},
	"machete": {"name": "Machete", "scene": W + "SM_Wep_Machete.glb", "class": "melee1h", "idle": "Player_Melee1H_Idle", "attacks": ["Player_Melee1H_Swing", "Player_Melee1H_Swing_Back"], "heavy": "Player_Melee1H_Slap"},
	"crowbar": {"name": "Piede di porco", "scene": W + "SM_Wep_Crowbar.glb", "class": "melee1h", "idle": "Player_Melee1H_Idle", "attacks": ["Player_Melee1H_Swing", "Player_Melee1H_Swing_Back"], "heavy": "Player_Melee1H_Bonk",
		"flavor": "Apre casse, porte e discussioni."},
	"nail_bat": {"name": "Mazza chiodata", "scene": W + "SM_Wep_NailBat.glb", "class": "melee1h", "idle": "Player_Melee1H_Idle", "attacks": ["Player_Melee1H_Swing", "Player_Melee1H_Swing_Back"], "heavy": "Player_Melee1H_Bonk"},
	"lever_rifle": {"name": "Fucile a leva", "scene": W + "SM_Wep_LeverRifle.glb", "class": "rifle",
		"aim": "Player_Rifle_Aim_In", "fire": "Player_Lever_Fire", "reload": "Player_Shotgun_Reload_Shell", "mag": 8},
	"crossbow": {"name": "Balestra", "scene": W + "SM_Wep_Crossbow.glb", "class": "rifle",
		"aim": "Player_Rifle_Aim_In", "fire": "Player_Rifle_Fire_Single", "reload": "Player_Crossbow_Reload", "mag": 1, "silent": true},
	"pickaxe": {"name": "Piccone", "scene": W + "SM_Wep_Pickaxe.glb", "class": "axe", "idle": "Player_Axe_Idle", "attacks": ["Player_Axe_Swing_Horizontal", "Player_Axe_Swing_Back"], "heavy": "Player_Axe_Chop_Overhead", "block": "Player_Axe_Block", "shove": "Player_Axe_Shove", "two_handed": true},
	"sledgehammer": {"name": "Mazza da demolizione", "scene": W + "SM_Wep_Sledgehammer.glb", "class": "axe", "idle": "Player_Axe_Idle", "attacks": ["Player_Axe_Swing_Horizontal", "Player_Axe_Swing_Back"], "heavy": "Player_Axe_Chop_Overhead", "block": "Player_Axe_Block", "shove": "Player_Axe_Shove", "two_handed": true},
	"frying_pan": {"name": "Padella della nonna", "scene": W + "SM_Wep_Fun_FryingPan.glb", "class": "melee1h", "idle": "Player_Melee1H_Idle", "attacks": ["Player_Melee1H_Swing", "Player_Melee1H_Swing_Back"], "heavy": "Player_Melee1H_Bonk",
		"flavor": "L'uovo è ancora lì. Nessuno sa da quando."},
	"electric_guitar": {"name": "L'Assolo Finale", "scene": W + "SM_Wep_Fun_Guitar.glb", "class": "axe", "idle": "Player_Axe_Idle", "attacks": ["Player_Axe_Swing_Horizontal", "Player_Axe_Swing_Back"], "heavy": "Player_Axe_Chop_Overhead", "block": "Player_Axe_Block", "shove": "Player_Axe_Shove", "two_handed": true,
		"flavor": "Un solo accordo: quello che spacca le teste."},
	"nailgun": {"name": "Sparachiodi", "scene": W + "SM_Wep_Nailgun.glb", "class": "pistol", "idle": "Player_Pistol_Idle",
		"aim": "Player_Pistol_Aim", "fire_auto": "Player_SMG_Fire_Auto", "auto": true, "rate": 0.16,
		"reload": "Player_Pistol_Reload", "mag": 40},
	"lmg": {"name": "Mitragliatrice leggera", "scene": W + "SM_Wep_LMG.glb", "class": "rifle",
		"aim": "Player_Rifle_Aim_In", "fire_auto": "Player_Rifle_Fire_Auto", "auto": true, "rate": 0.08,
		"reload": "Player_LMG_Reload", "mag": 100},
	"combat_knife": {"name": "Coltello da combattimento", "scene": W + "SM_Wep_CombatKnife.glb", "class": "melee1h",
		"idle": "Player_Melee1H_Idle", "attacks": ["Player_Knife_Stab", "Player_Melee_Knife_Slash"], "heavy": "Player_Melee1H_Swing_Back"},
	"grenade_launcher": {"name": "Lanciagranate a tamburo", "scene": W + "SM_Wep_GrenadeLauncher.glb", "class": "rifle",
		"aim": "Player_Rifle_Aim_In", "fire": "Player_Rifle_Fire_Single", "reload": "Player_Shotgun_Reload_Shell", "mag": 6, "explosive": true},
	"tesla_rifle": {"name": "Fucile Tesla (prototipo)", "scene": W + "SM_Wep_TeslaRifle.glb", "class": "rifle",
		"aim": "Player_Rifle_Aim_In", "fire_auto": "Player_Rifle_Fire_Auto", "auto": true, "rate": 0.12,
		"reload": "Player_Rifle_Reload", "mag": 40, "chain": 3, "flavor": "Il fulmine salta da un infetto all'altro. Tre volte."},
	"leaf_blower": {"name": "Soffiatore Spazzazombie", "scene": W + "SM_Wep_Fun_LeafBlower.glb", "class": "rifle",
		"aim": "Player_Rifle_Aim_In", "fire_auto": "Player_Blower_Sweep", "auto": true, "rate": 0.05,
		"reload": "Player_Rifle_Reload", "mag": 200, "knockback": 9.0, "damage": 0.0,
		"flavor": "Zero danni. Spinta infinita. Il burrone fa il resto."},
}

const ORDER := ["assault_rifle", "pump_shotgun", "sniper_rifle", "pistol", "revolver", "smg", "katana", "longsword", "runic_axe", "spartan_sword",
	"trout", "baguette", "rubber_chicken",
	"sawn_off", "flare_gun", "machete", "crowbar", "nail_bat", "lever_rifle", "crossbow", "pickaxe", "sledgehammer",
	"frying_pan", "electric_guitar", "nailgun", "lmg", "combat_knife", "grenade_launcher", "tesla_rifle", "leaf_blower", "unarmed"]


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func display_name(id: String) -> String:
	return Localization.t(str(DEFS.get(id, {}).get("name", id)))
