extends RefCounted
# Il movimento di tutte le armi: è l'arma a muoversi, le mani la seguono (player/arm_ik.gd). Lo stesso movimento serve
# la prima persona (player/viewmodel/fp_arms.gd) e chi ti vede da fuori (art/zx_player/tool_rig.gd).
# Spazio: quello della camera, +X destra, +Y su, -Z avanti. Ogni posa è [posizione della mano destra, manico o canna, filo o destra].

## Ogni arma: famiglia, due mani, rinculo [indietro, su], come si ricarica, cosa fa dopo lo sparo.
const WEAPONS := {
	"axe": {"fam": "axe"}, "fire_axe": {"fam": "axe"}, "runic_axe": {"fam": "axe"},
	"pickaxe": {"fam": "heavy"}, "sledgehammer": {"fam": "heavy"}, "electric_guitar": {"fam": "heavy"},
	"katana": {"fam": "katana"}, "longsword": {"fam": "sword"},
	"spartan_sword": {"fam": "blade"}, "machete": {"fam": "blade"},
	"crowbar": {"fam": "blunt"}, "nail_bat": {"fam": "blunt"}, "frying_pan": {"fam": "blunt"}, "baguette": {"fam": "blunt"}, "trout": {"fam": "blunt"}, "rubber_chicken": {"fam": "blunt"},
	"knife": {"fam": "knife"}, "combat_knife": {"fam": "knife"},
	"pistol": {"fam": "pistol", "rec": [1.6, 2.6], "reload": "mag"}, "revolver": {"fam": "pistol", "rec": [2.2, 4.2], "reload": "cylinder"},
	"flare_gun": {"fam": "pistol", "rec": [1.4, 3.4], "reload": "break"}, "nailgun": {"fam": "pistol", "rec": [0.6, 0.9], "reload": "mag"},
	"smg": {"fam": "smg", "rec": [0.7, 1.0], "reload": "mag"},
	"assault_rifle": {"fam": "rifle", "rec": [1.0, 1.4], "reload": "mag"}, "lmg": {"fam": "rifle", "rec": [1.2, 1.1], "reload": "mag"},
	"sniper_rifle": {"fam": "rifle", "rec": [3.0, 3.6], "reload": "mag", "cycle": "bolt"}, "tesla_rifle": {"fam": "rifle", "rec": [0.5, 0.6], "reload": "mag"},
	"pump_shotgun": {"fam": "rifle", "rec": [3.2, 4.2], "reload": "shell", "cycle": "pump"}, "lever_rifle": {"fam": "rifle", "rec": [2.2, 3.0], "reload": "shell", "cycle": "lever"},
	"sawn_off": {"fam": "smg", "rec": [3.8, 5.2], "reload": "break"}, "crossbow": {"fam": "rifle", "rec": [0.8, 1.0], "reload": "string"},
	"grenade_launcher": {"fam": "hip", "rec": [2.8, 3.4], "reload": "shell"}, "leaf_blower": {"fam": "hip", "rec": [0.15, 0.1], "reload": "mag"},
}
const GUNS := ["pistol", "smg", "rifle", "hip"]
const POSES := {
	"axe": {
		# Alta e vicina, manico in diagonale, testa in alto a destra col filo verso il cielo: si vede il piatto della lama.
		"idle": [Vector3(0.08, -0.17, -0.40), Vector3(0.78, 0.55, -0.22), Vector3(-0.55, 0.78, 0.0)],
		"sprint": [Vector3(0.20, -0.20, -0.38), Vector3(0.6, 0.75, -0.2), Vector3(-0.6, 0.5, -0.55)],
		"guard": [Vector3(0.13, -0.08, -0.42), Vector3(0.98, 0.05, -0.1), Vector3(0.05, 0.9, -0.4)],
		"charge": [Vector3(0.08, 0.14, -0.18), Vector3(0.2, 0.8, 0.55), Vector3(0.1, 0.55, -0.8)],
		"inspect": [Vector3(0.06, -0.14, -0.40), Vector3(0.3, 0.85, -0.4), Vector3(0.9, -0.1, 0.4)],
		"low": [Vector3(0.16, -0.48, -0.26), Vector3(0.4, 0.2, 0.9), Vector3(0.3, -0.9, 0.1)],
	},
	# In spalla: il peso si vede già da fermo.
	"heavy": {
		"idle": [Vector3(0.12, -0.20, -0.48), Vector3(0.6, 0.62, -0.5), Vector3(0.5, -0.78, 0.0)],
		"sprint": [Vector3(0.22, -0.26, -0.36), Vector3(0.55, 0.8, 0.2), Vector3(0.25, -0.4, -0.88)],
		"guard": [Vector3(0.16, -0.12, -0.42), Vector3(0.97, 0.1, -0.2), Vector3(0.1, 0.85, -0.5)],
		"charge": [Vector3(0.16, 0.20, -0.08), Vector3(0.1, 0.65, 0.75), Vector3(0.0, 0.75, -0.65)],
		"inspect": [Vector3(0.10, -0.20, -0.42), Vector3(0.45, 0.8, -0.4), Vector3(0.85, -0.3, 0.4)],
		"low": [Vector3(0.18, -0.55, -0.22), Vector3(0.3, -0.2, -0.93), Vector3(0.9, 0, 0.3)],
	},
	# Guardia centrale a due mani, la punta verso il bersaglio.
	"sword": {
		"idle": [Vector3(0.10, -0.20, -0.40), Vector3(-0.12, 0.72, -0.68), Vector3(0.05, -0.68, -0.72)],
		"sprint": [Vector3(0.22, -0.30, -0.30), Vector3(-0.5, 0.45, 0.72), Vector3(0.1, -0.85, 0.5)],
		"guard": [Vector3(0.14, -0.06, -0.42), Vector3(-0.97, 0.18, -0.15), Vector3(0.15, 0.97, 0.1)],
		"charge": [Vector3(0.24, 0.10, -0.14), Vector3(0.3, 0.75, 0.6), Vector3(-0.1, 0.6, -0.8)],
		"inspect": [Vector3(0.08, -0.14, -0.40), Vector3(-0.3, 0.9, -0.3), Vector3(0.9, 0.2, -0.3)],
		"low": [Vector3(0.20, -0.52, -0.20), Vector3(-0.4, -0.3, 0.85), Vector3(0, -0.95, -0.3)],
	},
	# Katana: bassa e tirata indietro da ferma; in carica si piega verso il fianco sinistro; in guardia sta alta sopra la testa.
	"katana": {
		"idle": [Vector3(0.14, -0.22, -0.40), Vector3(-0.22, 0.62, -0.75), Vector3(0.1, -0.76, -0.64)],
		"sprint": [Vector3(0.24, -0.30, -0.34), Vector3(-0.2, 0.25, 0.95), Vector3(0.1, -0.97, 0.25)],
		"guard": [Vector3(0.08, 0.02, -0.40), Vector3(0.45, 0.82, 0.35), Vector3(-0.25, 0.5, -0.83)],
		"charge": [Vector3(-0.12, -0.30, -0.34), Vector3(0.72, 0.1, 0.68), Vector3(0.3, -0.92, -0.2)],
		"inspect": [Vector3(0.08, -0.14, -0.40), Vector3(-0.3, 0.9, -0.3), Vector3(0.9, 0.2, -0.3)],
		"low": [Vector3(-0.10, -0.50, -0.26), Vector3(0.6, -0.1, 0.8), Vector3(0.2, -0.97, -0.1)],
	},
	# Una mano sola, bassa e pronta.
	"blade": {
		"idle": [Vector3(0.24, -0.19, -0.42), Vector3(0.25, 0.75, -0.6), Vector3(0.35, -0.66, -0.66)],
		"sprint": [Vector3(0.28, -0.32, -0.34), Vector3(0.1, 0.25, 0.96), Vector3(0.1, -0.95, 0.25)],
		"guard": [Vector3(0.14, -0.08, -0.42), Vector3(-0.95, 0.3, -0.1), Vector3(0.1, 0.1, -0.99)],
		"charge": [Vector3(0.36, 0.10, -0.14), Vector3(0.5, 0.8, 0.3), Vector3(-0.2, -0.2, -0.95)],
		"inspect": [Vector3(0.14, -0.18, -0.38), Vector3(-0.2, 0.9, -0.4), Vector3(0.95, 0.1, -0.3)],
		"low": [Vector3(0.24, -0.52, -0.22), Vector3(0.1, -0.2, 0.97), Vector3(0, -0.97, -0.2)],
	},
	# Una mano sola, tenuto alto vicino alla spalla come chi sta per dare una botta.
	"blunt": {
		"idle": [Vector3(0.26, -0.17, -0.40), Vector3(0.2, 0.85, -0.35), Vector3(0.0, -0.38, -0.9)],
		"sprint": [Vector3(0.26, -0.26, -0.28), Vector3(0.15, 0.55, 0.82), Vector3(0, -0.82, 0.55)],
		"guard": [Vector3(0.14, -0.08, -0.42), Vector3(-0.95, 0.25, -0.1), Vector3(0.1, 0.1, -0.99)],
		"charge": [Vector3(0.40, 0.10, -0.08), Vector3(0.55, 0.78, 0.25), Vector3(0, -0.2, -0.97)],
		"inspect": [Vector3(0.14, -0.18, -0.38), Vector3(-0.3, 0.85, -0.4), Vector3(0.9, 0.2, -0.3)],
		"low": [Vector3(0.24, -0.52, -0.22), Vector3(0.1, -0.2, 0.97), Vector3(0, -0.97, -0.2)],
	},
	"knife": {
		"idle": [Vector3(0.22, -0.20, -0.40), Vector3(0.05, 0.7, -0.7), Vector3(0.7, -0.5, -0.5)],
		"sprint": [Vector3(0.28, -0.32, -0.32), Vector3(0.1, 0.6, -0.8), Vector3(0.9, -0.4, -0.2)],
		"guard": [Vector3(0.14, -0.08, -0.40), Vector3(-0.85, 0.5, -0.15), Vector3(0.1, 0.1, -0.99)],
		"charge": [Vector3(0.28, 0.02, -0.26), Vector3(0.2, 0.65, -0.73), Vector3(0.1, -0.73, -0.65)],
		"inspect": [Vector3(0.12, -0.16, -0.32), Vector3(-0.3, 0.8, -0.5), Vector3(0.9, 0.1, -0.4)],
		"low": [Vector3(0.24, -0.50, -0.24), Vector3(0.1, -0.2, 0.97), Vector3(0, -0.97, -0.2)],
	},
	"pistol": {
		"idle": [Vector3(0.13, -0.20, -0.46), Vector3(-0.06, 0.05, -0.99), Vector3(1, 0, -0.06)],
		"sprint": [Vector3(0.17, -0.27, -0.36), Vector3(0.05, 0.5, -0.85), Vector3(0.95, -0.2, 0.1)],
		"aim": [Vector3(0.0, -0.135, -0.36), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		"reload": [Vector3(0.02, -0.07, -0.36), Vector3(-0.45, 0.2, -0.87), Vector3(0.9, 0.35, -0.2)],
		"inspect": [Vector3(0.08, -0.17, -0.38), Vector3(-0.6, 0.15, -0.8), Vector3(0.8, 0.1, -0.6)],
		"low": [Vector3(0.14, -0.46, -0.28), Vector3(0.1, -0.7, -0.7), Vector3(1, 0, 0)],
	},
	"smg": {
		"idle": [Vector3(0.10, -0.18, -0.30), Vector3(-0.05, 0.04, -0.99), Vector3(1, 0, -0.05)],
		"sprint": [Vector3(0.18, -0.30, -0.26), Vector3(-0.5, 0.45, -0.72), Vector3(0.8, 0.5, -0.25)],
		"aim": [Vector3(0.0, -0.14, -0.28), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		"reload": [Vector3(0.06, -0.18, -0.30), Vector3(-0.3, 0.45, -0.84), Vector3(0.88, 0.45, 0.0)],
		"inspect": [Vector3(0.10, -0.20, -0.32), Vector3(-0.65, 0.2, -0.72), Vector3(0.7, 0.2, -0.65)],
		"low": [Vector3(0.14, -0.48, -0.20), Vector3(0.05, -0.7, -0.7), Vector3(1, 0, 0)],
	},
	# Il calcio in spalla.
	"rifle": {
		"idle": [Vector3(0.12, -0.20, -0.24), Vector3(-0.08, 0.06, -0.99), Vector3(1, 0, -0.08)],
		"sprint": [Vector3(0.12, -0.30, -0.16), Vector3(-0.55, 0.4, -0.73), Vector3(0.75, 0.55, -0.3)],
		"aim": [Vector3(0.0, -0.15, -0.14), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		"reload": [Vector3(0.03, -0.10, -0.26), Vector3(-0.45, 0.25, -0.86), Vector3(0.85, 0.5, -0.0)],
		"inspect": [Vector3(0.10, -0.22, -0.26), Vector3(-0.6, 0.25, -0.75), Vector3(0.72, 0.25, -0.6)],
		"low": [Vector3(0.16, -0.50, -0.14), Vector3(0.05, -0.65, -0.75), Vector3(1, 0, 0)],
	},
	# Pesante, all'anca: si vede lo sforzo di tenerla su.
	"hip": {
		"idle": [Vector3(0.12, -0.25, -0.22), Vector3(-0.12, 0.14, -0.98), Vector3(0.99, 0.02, -0.12)],
		"sprint": [Vector3(0.22, -0.38, -0.20), Vector3(-0.5, 0.3, -0.8), Vector3(0.85, 0.3, -0.4)],
		"aim": [Vector3(0.02, -0.17, -0.18), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		"reload": [Vector3(0.08, -0.24, -0.26), Vector3(-0.3, 0.5, -0.81), Vector3(0.85, 0.5, 0.0)],
		"inspect": [Vector3(0.12, -0.28, -0.26), Vector3(-0.6, 0.25, -0.75), Vector3(0.72, 0.25, -0.6)],
		"low": [Vector3(0.18, -0.55, -0.14), Vector3(0.05, -0.65, -0.75), Vector3(1, 0, 0)],
	},
}
## I colpi: carica, contatto, lama che attraversa ed esce di scena. A e B da una parte e dall'altra, C il terzo della combo, H il caricato.
const SWINGS := {
	"axe": {
		"A": [[Vector3(0.30, -0.06, -0.30), Vector3(0.85, 0.35, 0.40), Vector3(0.3, -0.2, -0.9)],
			[Vector3(0.02, -0.12, -0.52), Vector3(0.25, 0.1, -0.96), Vector3(-0.9, -0.2, -0.2)],
			[Vector3(-0.30, -0.30, -0.32), Vector3(-0.85, -0.1, -0.2), Vector3(-0.1, -0.6, 0.7)]],
		# Anche il secondo parte dalla destra: dall'alto della spalla scende in diagonale a sinistra, il filo sempre avanti.
		"B": [[Vector3(0.34, 0.10, -0.20), Vector3(0.6, 0.7, 0.4), Vector3(-0.4, 0.2, -0.9)],
			[Vector3(0.06, -0.14, -0.52), Vector3(0.2, 0.3, -0.93), Vector3(-0.7, -0.7, -0.1)],
			[Vector3(-0.26, -0.40, -0.30), Vector3(-0.6, -0.6, -0.5), Vector3(-0.5, -0.4, 0.75)]],
		"C": [[Vector3(0.05, 0.12, -0.25), Vector3(0.05, 0.75, 0.65), Vector3(0, 0.65, -0.75)],
			[Vector3(0.0, -0.18, -0.55), Vector3(0.02, 0.25, -0.97), Vector3(0, -0.97, -0.25)],
			[Vector3(0.0, -0.44, -0.36), Vector3(0.03, -0.65, -0.75), Vector3(0, -0.75, 0.65)]],
		"H": [[Vector3(0.08, 0.16, -0.18), Vector3(0.2, 0.8, 0.55), Vector3(0.1, 0.55, -0.8)],
			[Vector3(0.0, -0.20, -0.56), Vector3(0.05, 0.2, -0.98), Vector3(0, -0.98, -0.2)],
			[Vector3(-0.04, -0.50, -0.34), Vector3(-0.05, -0.75, -0.65), Vector3(0, -0.65, 0.75)]],
	},
	"heavy": {
		"A": [[Vector3(0.42, -0.02, -0.12), Vector3(0.85, 0.35, 0.4), Vector3(0.3, -0.2, -0.93)],
			[Vector3(0.05, -0.10, -0.55), Vector3(0.2, 0.1, -0.97), Vector3(-0.97, -0.1, -0.2)],
			[Vector3(-0.38, -0.25, -0.25), Vector3(-0.9, -0.1, -0.1), Vector3(-0.1, -0.6, 0.8)]],
		"B": [[Vector3(0.12, 0.22, -0.10), Vector3(0.05, 0.7, 0.7), Vector3(0, 0.7, -0.7)],
			[Vector3(0.02, -0.22, -0.60), Vector3(0.02, 0.1, -0.99), Vector3(0, -0.99, -0.1)],
			[Vector3(0.02, -0.55, -0.35), Vector3(0, -0.8, -0.6), Vector3(0, -0.6, 0.8)]],
		"C": [[Vector3(-0.34, 0.0, -0.14), Vector3(-0.85, 0.35, 0.4), Vector3(-0.3, -0.2, -0.93)],
			[Vector3(0.0, -0.10, -0.55), Vector3(-0.2, 0.1, -0.97), Vector3(0.97, -0.1, -0.2)],
			[Vector3(0.40, -0.25, -0.25), Vector3(0.9, -0.1, -0.1), Vector3(0.1, -0.6, 0.8)]],
		"H": [[Vector3(0.16, 0.26, -0.04), Vector3(0.1, 0.6, 0.8), Vector3(0, 0.8, -0.6)],
			[Vector3(0.02, -0.26, -0.62), Vector3(0.02, 0.0, -1), Vector3(0, -1, 0)],
			[Vector3(0.0, -0.62, -0.40), Vector3(0, -0.9, -0.45), Vector3(0, -0.45, 0.9)]],
	},
	"sword": {
		"A": [[Vector3(0.28, 0.12, -0.20), Vector3(0.35, 0.85, 0.4), Vector3(-0.3, -0.2, -0.93)],
			[Vector3(0.02, -0.12, -0.52), Vector3(-0.35, 0.1, -0.93), Vector3(-0.85, -0.4, 0.3)],
			[Vector3(-0.30, -0.38, -0.32), Vector3(-0.75, -0.5, -0.4), Vector3(-0.4, -0.25, 0.88)]],
		"B": [[Vector3(-0.25, -0.28, -0.30), Vector3(-0.7, -0.4, -0.6), Vector3(0.3, -0.9, 0.0)],
			[Vector3(0.05, -0.06, -0.52), Vector3(0.3, 0.35, -0.9), Vector3(0.9, -0.3, 0.2)],
			[Vector3(0.32, 0.15, -0.30), Vector3(0.75, 0.6, -0.25), Vector3(0.3, -0.7, -0.6)]],
		"C": [[Vector3(0.14, -0.20, -0.30), Vector3(0, 0.55, -0.83), Vector3(0, -0.83, -0.55)],
			[Vector3(0.02, -0.20, -0.56), Vector3(0, 0.42, -0.9), Vector3(0, -0.9, -0.42)],
			[Vector3(0.02, -0.22, -0.48), Vector3(0, 0.5, -0.86), Vector3(0, -0.86, -0.5)]],
		"H": [[Vector3(0.20, 0.20, -0.10), Vector3(0.2, 0.8, 0.55), Vector3(-0.1, 0.55, -0.8)],
			[Vector3(0.0, -0.20, -0.58), Vector3(0.0, 0.2, -0.98), Vector3(0, -0.98, -0.2)],
			[Vector3(-0.06, -0.50, -0.34), Vector3(-0.1, -0.75, -0.65), Vector3(0, -0.65, 0.75)]],
	},
	# Quattro mosse: fendente ampio da destra, ritorno dal basso, discesa profonda in avanti, e il taglio largo dalla carica bassa.
	"katana": {
		"A": [[Vector3(0.34, 0.14, -0.22), Vector3(0.55, 0.78, 0.3), Vector3(-0.25, -0.2, -0.95)],
			[Vector3(0.04, -0.10, -0.56), Vector3(-0.45, 0.12, -0.88), Vector3(-0.85, -0.25, 0.42)],
			[Vector3(-0.36, -0.20, -0.36), Vector3(-0.95, 0.05, -0.1), Vector3(-0.05, -0.5, 0.86)]],
		"B": [[Vector3(-0.30, -0.28, -0.34), Vector3(-0.8, -0.35, -0.45), Vector3(0.25, -0.92, 0.2)],
			[Vector3(0.06, -0.08, -0.56), Vector3(0.4, 0.35, -0.85), Vector3(0.85, -0.4, 0.3)],
			[Vector3(0.38, 0.18, -0.34), Vector3(0.8, 0.58, -0.1), Vector3(0.45, -0.72, -0.5)]],
		"C": [[Vector3(0.16, 0.20, -0.20), Vector3(0.12, 0.85, 0.5), Vector3(-0.05, 0.5, -0.86)],
			[Vector3(0.02, -0.22, -0.60), Vector3(-0.1, 0.1, -0.99), Vector3(0, -0.99, -0.1)],
			[Vector3(-0.08, -0.56, -0.42), Vector3(-0.25, -0.65, -0.72), Vector3(-0.1, -0.72, 0.68)]],
		"H": [[Vector3(-0.16, -0.32, -0.32), Vector3(0.78, 0.05, 0.62), Vector3(0.3, -0.92, -0.25)],
			[Vector3(0.08, -0.16, -0.60), Vector3(0.65, 0.1, -0.75), Vector3(0.7, -0.25, 0.65)],
			[Vector3(0.46, -0.10, -0.32), Vector3(0.98, 0.1, 0.15), Vector3(0.1, -0.5, 0.86)]],
	},
	"blade": {
		"A": [[Vector3(0.38, 0.08, -0.18), Vector3(0.5, 0.8, 0.3), Vector3(-0.2, -0.2, -0.95)],
			[Vector3(0.08, -0.12, -0.55), Vector3(-0.3, 0.15, -0.94), Vector3(-0.9, -0.3, 0.2)],
			[Vector3(-0.18, -0.34, -0.35), Vector3(-0.8, -0.45, -0.4), Vector3(-0.3, -0.3, 0.9)]],
		"B": [[Vector3(-0.12, 0.02, -0.30), Vector3(-0.75, 0.55, 0.2), Vector3(-0.2, -0.2, -0.95)],
			[Vector3(0.12, -0.10, -0.55), Vector3(0.3, 0.15, -0.94), Vector3(0.9, -0.3, 0.2)],
			[Vector3(0.42, -0.22, -0.28), Vector3(0.9, 0.0, 0.2), Vector3(0.1, -0.7, 0.7)]],
		"C": [[Vector3(0.24, -0.20, -0.30), Vector3(0.05, 0.55, -0.83), Vector3(0, -0.83, -0.55)],
			[Vector3(0.12, -0.20, -0.56), Vector3(0, 0.42, -0.9), Vector3(0, -0.9, -0.42)],
			[Vector3(0.14, -0.22, -0.48), Vector3(0, 0.5, -0.86), Vector3(0, -0.86, -0.5)]],
		"H": [[Vector3(0.36, 0.14, -0.12), Vector3(0.4, 0.85, 0.3), Vector3(-0.1, 0.3, -0.95)],
			[Vector3(0.06, -0.16, -0.58), Vector3(-0.1, 0.2, -0.97), Vector3(-0.3, -0.92, -0.2)],
			[Vector3(-0.10, -0.46, -0.34), Vector3(-0.4, -0.7, -0.6), Vector3(-0.2, -0.6, 0.8)]],
	},
	"blunt": {
		"A": [[Vector3(0.42, 0.05, -0.10), Vector3(0.6, 0.75, 0.1), Vector3(0, -0.1, -0.99)],
			[Vector3(0.10, -0.08, -0.58), Vector3(-0.1, 0.25, -0.96), Vector3(-0.98, 0, 0.1)],
			[Vector3(-0.25, -0.22, -0.35), Vector3(-0.85, -0.1, -0.4), Vector3(-0.35, -0.2, 0.9)]],
		"B": [[Vector3(-0.14, 0.06, -0.26), Vector3(-0.7, 0.7, 0.1), Vector3(0, -0.1, -0.99)],
			[Vector3(0.14, -0.08, -0.58), Vector3(0.2, 0.25, -0.95), Vector3(0.98, 0, 0.2)],
			[Vector3(0.45, -0.20, -0.25), Vector3(0.9, -0.1, 0.2), Vector3(0.2, -0.6, 0.75)]],
		"C": [[Vector3(0.20, 0.20, -0.12), Vector3(0.1, 0.8, 0.55), Vector3(0, 0.55, -0.8)],
			[Vector3(0.08, -0.20, -0.55), Vector3(0.05, 0.2, -0.97), Vector3(0, -0.97, -0.2)],
			[Vector3(0.08, -0.42, -0.38), Vector3(0, -0.6, -0.8), Vector3(0, -0.8, 0.6)]],
		"H": [[Vector3(0.36, 0.20, -0.06), Vector3(0.4, 0.8, 0.45), Vector3(0, 0.5, -0.85)],
			[Vector3(0.06, -0.24, -0.58), Vector3(0, 0.1, -0.99), Vector3(0, -0.99, -0.1)],
			[Vector3(-0.05, -0.52, -0.34), Vector3(-0.2, -0.8, -0.55), Vector3(0, -0.55, 0.8)]],
	},
	"knife": {
		"A": [[Vector3(0.34, -0.06, -0.26), Vector3(0.55, 0.2, -0.8), Vector3(0.1, -0.97, -0.2)],
			[Vector3(0.06, -0.14, -0.55), Vector3(-0.4, 0.05, -0.92), Vector3(-0.9, -0.2, 0.4)],
			[Vector3(-0.14, -0.26, -0.40), Vector3(-0.85, -0.15, -0.5), Vector3(-0.4, -0.3, 0.85)]],
		"B": [[Vector3(-0.08, -0.08, -0.30), Vector3(-0.6, 0.2, -0.77), Vector3(0.1, -0.97, -0.2)],
			[Vector3(0.14, -0.14, -0.55), Vector3(0.4, 0.05, -0.92), Vector3(0.9, -0.2, 0.4)],
			[Vector3(0.36, -0.24, -0.36), Vector3(0.85, -0.1, -0.5), Vector3(0.4, -0.3, 0.85)]],
		"C": [[Vector3(0.22, -0.20, -0.28), Vector3(0.03, 0.6, -0.8), Vector3(0.9, -0.4, -0.2)],
			[Vector3(0.10, -0.20, -0.56), Vector3(0, 0.45, -0.89), Vector3(0.9, -0.4, -0.2)],
			[Vector3(0.14, -0.24, -0.44), Vector3(0.05, 0.55, -0.83), Vector3(0.9, -0.4, -0.2)]],
		"H": [[Vector3(0.28, 0.02, -0.26), Vector3(0.2, 0.65, -0.73), Vector3(0.1, -0.73, -0.65)],
			[Vector3(0.08, -0.20, -0.58), Vector3(0, 0.4, -0.92), Vector3(0, -0.92, -0.4)],
			[Vector3(0.14, -0.28, -0.42), Vector3(0.1, 0.5, -0.86), Vector3(0.5, -0.74, -0.45)]],
	},
}
## Gli stessi colpi visti da fuori, per l'ascia: a una mano, sale accanto alla testa e scende in diagonale.
const SWINGS_OUT := {
	"A": [[Vector3(0.26, 0.10, -0.06), Vector3(0.25, 0.9, 0.25), Vector3(-0.5, 0.1, -0.85)],
		[Vector3(0.10, -0.15, -0.50), Vector3(0.1, 0.25, -0.96), Vector3(-0.2, -0.95, -0.2)],
		[Vector3(-0.12, -0.50, -0.38), Vector3(-0.2, -0.75, -0.6), Vector3(-0.2, -0.6, 0.75)]],
	"B": [[Vector3(-0.12, -0.02, -0.22), Vector3(-0.7, 0.6, 0.2), Vector3(-0.3, -0.1, -0.95)],
		[Vector3(0.10, -0.12, -0.50), Vector3(0.2, 0.15, -0.96), Vector3(0.9, -0.2, 0.1)],
		[Vector3(0.38, -0.20, -0.25), Vector3(0.9, 0, 0.1), Vector3(0.1, -0.7, 0.7)]],
	"C": [[Vector3(0.20, 0.22, -0.08), Vector3(0.1, 0.85, 0.5), Vector3(-0.1, 0.5, -0.85)],
		[Vector3(0.08, -0.15, -0.52), Vector3(0.03, 0.25, -0.97), Vector3(0, -0.97, -0.25)],
		[Vector3(0.05, -0.52, -0.34), Vector3(0, -0.7, -0.7), Vector3(0, -0.7, 0.7)]],
}
## Ricarica vista da fuori: l'arma di sbieco sul petto, la bocca in alto a sinistra, lontana dal viso.
## (La posa della prima persona, vista da fuori, metteva la canna dritta davanti alla faccia.)
const RELOAD_OUT := {
	"pistol": [Vector3(0.06, -0.22, -0.32), Vector3(-0.4, 0.45, -0.8), Vector3(0.9, 0.4, -0.2)],
	"smg": [Vector3(0.08, -0.26, -0.28), Vector3(-0.55, 0.5, -0.67), Vector3(0.75, 0.65, -0.1)],
	"rifle": [Vector3(0.10, -0.30, -0.26), Vector3(-0.72, 0.32, -0.62), Vector3(0.55, 0.82, -0.2)],
	"hip": [Vector3(0.10, -0.32, -0.24), Vector3(-0.5, 0.45, -0.74), Vector3(0.8, 0.55, -0.2)],
}
const SWING_ROW := {"Axe_Light1": "A", "Axe_Light2": "B", "Axe_Light3": "C", "Axe_Tired": "A", "Axe_HeavySwing": "H"}
const VARIANT_ROW := ["A", "B", "C"]
## Dove si chiude il pugno, nello spazio dell'arma (+Y manico o canna, +Z alto): centro del pugno, verso del pollice,
## e le nocche se sono fisse. Su un manico tondo le nocche seguono l'avambraccio: il polso resta dritto.
const RIGHT_MELEE := {"c": Vector3.ZERO, "t": Vector3(0, 1, 0)}
const RIGHT_GUN := {"c": Vector3(0, 0, -0.023), "t": Vector3(0, -0.31, 0.95), "f": Vector3(0, 0.95, 0.31)}
const LEFT_PISTOL := {"c": Vector3(-0.017, 0.018, -0.055), "t": Vector3(0, 0, 1), "f": Vector3(0, 1, 0)}
const LEFT_TWO := {"axe": -0.15, "heavy": -0.18, "sword": -0.14, "katana": -0.14}
## Il modello rispetto alla mano. Armi bianche: manico +Y, filo -Z. Armi da fuoco: canna -Z, alto +Y.
const MELEE_BASIS := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
const GUN_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
const GUN_OFFSET := Vector3(0, 0.025, 0.045)
const AXE_OFFSET := Vector3(0, -0.12, 0)
## Quanto manico resta sotto la mano destra.
const TAIL := {"heavy": 0.34, "sword": 0.20, "katana": 0.20, "blade": 0.07, "blunt": 0.09, "knife": 0.05}
const FINGERS := {"axe": "Axe2H_Idle", "heavy": "Axe2H_Idle", "sword": "Sword_Idle", "katana": "Sword_Idle", "blade": "Melee1H_Idle", "blunt": "Melee1H_Idle", "knife": "Knife_Idle",
	"pistol": "Pistol_Idle", "smg": "Rifle_Idle", "rifle": "Rifle_Idle", "hip": "Rifle_Idle"}
const EQUIP_SECONDS := 0.42
const INSPECT_SECONDS := 2.4
const CYCLE_SECONDS := 0.6

var id := "axe"
var kind := "axe"                        # la famiglia
var outside := false                     # chi ti guarda da fuori vede i colpi di SWINGS_OUT
var pos := Vector3.ZERO
var rot := Quaternion.IDENTITY
## Ricarica: caricatore fuori (0-1), carrello indietro (0-1), mano sinistra spostata (spazio dell'arma).
var mag_out := 0.0
var slide_back := 0.0
# Cosa tiene la sinistra durante la ricarica: "mag" (caricatore nuovo), "shell" (cartuccia) o "".
var carry := ""
var open := 0.0                          # canne spezzate, tamburo fuori o coperchio alzato (0-1)
var reload_total := 0.0                  # durata vera della ricarica in corso: dice se è da vuoto (lo imposta chi chiama tick)
var _steps: Array = []
var _r := -1.0
var _aim_w := 0.0
var left_shift := Vector3.ZERO
var edge_w := 0.0
var walk := 0.0                          # da 0 a 1: il passo fa ondeggiare l'arma (da fuori; la prima persona ha il suo)
var sight := 0.135                       # quanto sta sotto la linea degli occhi la mano mirando
var support := 0.25                      # dove prende la sinistra lungo la canna
var under := 0.02                        # quanto è bassa la canna in quel punto
var _clock := 0.0
var _ready_pose := false
var _equip := 1.0
var _cycle := -1.0
var _spring_p := Vector3.ZERO
var _spring_pv := Vector3.ZERO
var _spring_r := Vector3.ZERO
var _spring_rv := Vector3.ZERO


static func handles(weapon: String) -> bool:
	return WEAPONS.has(weapon)


static func family(weapon: String) -> String:
	return str(WEAPONS.get(weapon, {}).get("fam", ""))


static func is_gun_family(fam: String) -> bool:
	return fam in GUNS


static func finger_clip(weapon: String) -> String:
	return FINGERS.get(family(weapon), "Melee1H_Idle")


## Le armi non devono specchiare il cielo color sabbia né abbagliare: acciaio brunito, poco riflettente.
static func burnish(item: Node3D) -> void:
	for mi in item.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as StandardMaterial3D
			if mat and mat.metallic > 0.5:
				var dull: StandardMaterial3D = mat.duplicate()
				dull.metallic = 0.35
				dull.roughness = 0.55
				(mi as MeshInstance3D).set_surface_override_material(s, dull)


## Misura del modello nel suo spazio, anche prima che entri nella scena.
static func model_box(item: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for found in item.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		var t := mi.transform
		var n: Node = mi.get_parent()
		while n and n != item:
			if n is Node3D: t = (n as Node3D).transform * t
			n = n.get_parent()
		var b: AABB = t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Dove passa il manico: due medie di vertici, in fondo e in cima, danno una retta (i manici low-poly hanno vertici solo alle estremità). In molti modelli è fuori centro o inclinato.
## Ritorna [punto sulla retta alla quota y=0 del modello, direzione verso la punta].
static func handle_line(item: Node3D, low: float, tall: float) -> Array:
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var na := 0
	var nb := 0
	for found in item.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh == null: continue
		var t := mi.transform
		var n: Node = mi.get_parent()
		while n and n != item:
			if n is Node3D: t = (n as Node3D).transform * t
			n = n.get_parent()
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = t * (v as Vector3)
				var h: float = (p.y - low) / tall
				if h <= 0.22:
					a += p
					na += 1
				elif h >= 0.72:
					b += p
					nb += 1
	if na == 0 or nb == 0: return [Vector3.ZERO, Vector3.UP]
	a /= float(na)
	b /= float(nb)
	var way: Vector3 = (b - a).normalized()
	if way.y < 0.8: way = Vector3.UP
	return [a + way * ((0.0 - a.y) / way.y), way]

## Il punto più basso dell'arma dove prende la sinistra, nello spazio della mano. Ogni modello ha la sua canna.
static func _underside(item: Node3D, along: float) -> float:
	var low := INF
	for found in item.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh == null: continue
		var t := mi.transform
		var n: Node = mi.get_parent()
		while n and n != item:
			if n is Node3D: t = (n as Node3D).transform * t
			n = n.get_parent()
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = t * (v as Vector3)
				if absf(-p.z - GUN_OFFSET.y - along) < 0.09: low = minf(low, p.y + GUN_OFFSET.z)
	return low if low < INF else 0.02


## Mette il modello nella mano giusta: la destra chiusa all'origine, il manico o la canna lungo +Y.
func place_item(item: Node3D) -> void:
	if item == null: return
	burnish(item)
	var box := model_box(item)
	if id == "axe" or id == "fire_axe":
		item.transform = Transform3D(GUN_BASIS, AXE_OFFSET)
	elif is_gun_family(kind):
		item.transform = Transform3D(GUN_BASIS, GUN_OFFSET)
		sight = box.end.y + GUN_OFFSET.z + 0.01
		var length: float = -box.position.z
		# Oltre 0,30 m il braccio del modello non arriva: la mano scivolava indietro dove la canna è più spessa.
		support = clampf(length * 0.48, 0.14, 0.30)
		# La sinistra regge da sotto: il pugno è fatto per un manico sottile, attorno a pompa e paramano spariva dentro.
		under = _underside(item, support) - 0.025
	else:
		# Il manico finisce TAIL sotto la mano: va bene sia per le lame con l'origine sull'elsa, sia per le mazze con l'origine a metà.
		var lift: float = -box.position.y - float(TAIL.get(kind, 0.1))
		if box.position.y > -0.3 and kind != "heavy": lift = 0.0
		# Il manico non è sempre dritto né al centro del modello: si raddrizza e il pugno si chiude sul manico vero.
		var line: Array = handle_line(item, box.position.y, box.size.y)
		var way: Vector3 = line[1]
		var turn := Basis.IDENTITY
		if way.dot(Vector3.UP) < 0.9999: turn = Basis(way.cross(Vector3.UP).normalized(), way.angle_to(Vector3.UP))
		var full: Basis = MELEE_BASIS * turn
		var grip_point: Vector3 = (line[0] as Vector3) + way * (-lift / way.y)
		item.transform = Transform3D(full, -(full * grip_point))


func setup(weapon: String) -> void:
	id = weapon
	kind = family(weapon)
	_equip = 0.0
	_ready_pose = false
	_cycle = -1.0


func is_gun() -> bool:
	return is_gun_family(kind)


func grip(side: String) -> Dictionary:
	if side == "r":
		return RIGHT_GUN if is_gun() else RIGHT_MELEE
	if LEFT_TWO.has(kind):
		return {"c": Vector3(0, float(LEFT_TWO[kind]), 0), "t": Vector3(0, 1, 0)}
	if kind == "pistol": return LEFT_PISTOL
	if is_gun():
		# Sotto la canna, palmo in su, dita che salgono ai lati.
		return {"c": Vector3(0, support, under), "t": Vector3(0, 1, 0), "f": Vector3(1, 0, 0.5)}
	return {}


## Sparo o lama che entra: il colpo torna sulle mani e la molla lo riassorbe.
func kick(back: float, up: float) -> void:
	_spring_pv += Vector3(randf_range(-0.05, 0.05), up * 0.12, back)
	_spring_rv += Vector3(up, randf_range(-0.8, 0.8), randf_range(-1.0, 1.0))


## Colpo sparato: rinculo dell'arma e, se è a ripetizione manuale, il gesto per armarla.
func shot(aiming: bool = false) -> void:
	var row: Array = WEAPONS[id].get("rec", [1.6, 2.6])
	var soft: float = 0.55 if aiming else 1.0
	kick(float(row[0]) * soft, float(row[1]) * soft)
	if WEAPONS[id].has("cycle"): _cycle = 0.0


## Fine di una ricarica da vuoto a cartucce: pompa o leva armano il primo colpo. Vero se l'arma ha il gesto.
func chamber() -> bool:
	if not WEAPONS[id].has("cycle"): return false
	_cycle = 0.0
	return true


static func _basis(row: Array) -> Quaternion:
	var y: Vector3 = (row[1] as Vector3).normalized()
	var x: Vector3 = row[2]
	x = (x - y * x.dot(y)).normalized()
	return Basis(x, y, x.cross(y)).get_rotation_quaternion()


## Punto del colpo: `t` è il tempo dal via, il contatto cade a metà della finestra attiva.
func _swing(row: String, from: Array, t: float, windup: float, active: float, recovery: float) -> Array:
	var keys: Array = SWINGS_OUT[row] if outside and kind == "axe" and SWINGS_OUT.has(row) else SWINGS[kind][row]
	var hit := windup + active * 0.5
	var peak := hit * 0.62
	var out := hit + 0.13
	var end := maxf(windup + active + recovery, out + 0.1)
	var path: Array = [from, keys[0], keys[1], keys[2], from]
	var i: int
	var w: float
	if t < peak:
		i = 0
		w = smoothstep(0.0, 1.0, t / maxf(peak, 0.001))
	elif t < hit:
		i = 1
		w = pow((t - peak) / maxf(hit - peak, 0.001), 1.6)     # accelera fino al contatto
	elif t < out:
		i = 2
		w = 1.0 - pow(1.0 - (t - hit) / (out - hit), 1.5)
	else:
		i = 3
		w = smoothstep(0.0, 1.0, (t - out) / (end - out))
	# Una curva che passa per i punti chiave: la lama descrive un arco, non una spezzata.
	var a: Array = path[i]
	var b: Array = path[i + 1]
	var before: Array = path[maxi(i - 1, 0)]
	var after: Array = path[mini(i + 2, 4)]
	return [(a[0] as Vector3).cubic_interpolate(b[0], before[0], after[0], w),
		_basis(a).spherical_cubic_interpolate(_basis(b), _basis(before), _basis(after), w)]


## Stato del turno: swing = [riga, tempo, carica, attiva, recupero] oppure []; reload da 0 a 1 oppure -1; inspect in secondi oppure -1.
func tick(delta: float, swing: Array, charge: float, guard: bool, sprint: bool, aim: bool, reload: float, inspect: float) -> void:
	_clock += delta
	var table: Dictionary = POSES[kind]
	var home: Array = table["idle"]
	if sprint: home = table["sprint"]
	var goal_p: Vector3 = home[0]
	var goal_r := _basis(home)
	var rate := 11.0
	mag_out = 0.0
	slide_back = 0.0
	open = 0.0
	_r = reload
	_aim_w = move_toward(_aim_w, 1.0 if aim and reload < 0.0 and is_gun() else 0.0, delta / 0.14)
	carry = ""
	left_shift = Vector3.ZERO
	if not is_gun():
		if not swing.is_empty():
			var at: Array = _swing(swing[0], table["charge"] if swing[0] == "H" else home, swing[1], swing[2], swing[3], swing[4])
			goal_p = at[0]
			goal_r = at[1]
			rate = 42.0
		elif guard:
			goal_p = table["guard"][0]
			goal_r = _basis(table["guard"])
			rate = 20.0
		elif charge > 0.0:
			var w := smoothstep(0.0, 1.0, charge * 1.6)
			goal_p = goal_p.lerp(table["charge"][0], w)
			goal_r = goal_r.slerp(_basis(table["charge"]), w)
			rate = 16.0
	elif reload >= 0.0:
		var reload_pose: Array = RELOAD_OUT.get(kind, table["reload"]) if outside else table["reload"]
		goal_p = reload_pose[0]
		goal_r = _basis(reload_pose)
		_steps = load("res://weapons/zx_arsenal.gd").reload_steps(id, reload_total)
		if reload > float(_steps[-1][0]) + 0.1 and WEAPONS[id].get("reload", "mag") != "shell":
			goal_p = table["idle"][0]          # assestamento: l'arma torna in guardia dopo l'ultimo gesto
			goal_r = _basis(table["idle"])
		rate = 14.0
		goal_r = goal_r * _reload_hands(reload, delta)
	elif aim:
		goal_p = Vector3(0.0, -sight, table["aim"][0].z)
		goal_r = _basis(table["aim"])
		rate = 18.0
	if _cycle >= 0.0 and reload < 0.0:
		_cycle += delta
		var c: float = sin(clampf(_cycle / CYCLE_SECONDS, 0.0, 1.0) * PI)
		match str(WEAPONS[id].get("cycle", "")):
			"pump": left_shift += Vector3(0, -0.13, 0) * c
			"lever": goal_r = goal_r * Quaternion(Vector3.RIGHT, 0.32 * c)
			"bolt":
				goal_r = goal_r * Quaternion(Vector3.UP, -0.3 * c)
				left_shift += Vector3(0.12, -support + 0.06, 0.1) * c
		if _cycle >= CYCLE_SECONDS: _cycle = -1.0
	if inspect >= 0.0 and swing.is_empty() and reload < 0.0 and not guard:
		var w := smoothstep(0.0, 0.35, inspect) * (1.0 - smoothstep(INSPECT_SECONDS - 0.4, INSPECT_SECONDS, inspect))
		goal_p = goal_p.lerp(table["inspect"][0], w)
		goal_r = goal_r.slerp(_basis(table["inspect"]), w)
	# Estrazione: l'arma sale da sotto con un piccolo scatto finale.
	if _equip < 1.0:
		_equip = minf(1.0, _equip + delta / EQUIP_SECONDS)
		var e := 1.0 - pow(1.0 - _equip, 3.0)
		goal_p = (table["low"][0] as Vector3).lerp(goal_p, e)
		goal_r = _basis(table["low"]).slerp(goal_r, e)
		rate = 30.0
	if not _ready_pose:
		_ready_pose = true
		pos = goal_p
		rot = goal_r
	var k := 1.0 - exp(-delta * rate)
	pos = pos.lerp(goal_p, k)
	rot = rot.slerp(goal_r, k)
	# Nel colpo le nocche vanno dietro al filo, come in una vera accettata.
	edge_w = move_toward(edge_w, 1.0 if not swing.is_empty() else 0.0, delta * 7.0)
	# Molle: rapide ad assorbire, senza oscillazioni lunghe.
	_spring_pv += (-_spring_p * 260.0 - _spring_pv * 22.0) * delta
	_spring_p += _spring_pv * delta
	_spring_rv += (-_spring_r * 200.0 - _spring_rv * 18.0) * delta
	_spring_r += _spring_rv * delta


## La sinistra durante la ricarica, sugli eventi di zx_arsenal.RELOAD_STEPS: il gesto cade dove salgono i colpi.
## Ritorna quanto ruota l'arma (spazio dell'arma: +X destra, +Y volata, +Z alto).
func _reload_hands(r: float, delta: float) -> Quaternion:
	var turn := Quaternion.IDENTITY
	match str(WEAPONS[id].get("reload", "mag")):
		"shell":
			# Una ricarica = una cartuccia (player.gd riparte per la successiva): la mano va alla tasca,
			# torna con la cartuccia e la spinge nel tubo; la spinta dà un piccolo colpo all'arma.
			var push := _step("shell_in")
			var c: float = sin(clampf(r / (push + 0.09), 0.0, 1.0) * PI)
			left_shift = Vector3(-0.04, -0.09, -0.03) * c + Vector3(0, -support * 0.4, 0.04)   # resta in vista sotto la finestra
			if r > 0.3 and r < push + 0.02: carry = "shell"
			if r > push and r < push + 0.05: _spring_pv.y += 0.25 * delta * 30.0
		"break", "cylinder":
			# Si apre (doppietta: volata giù; tamburo: arma ruotata a sinistra e su per far cadere i bossoli),
			# la sinistra torna con i colpi, li infila, poi un colpo secco richiude.
			var open_at := _step("break_open") if _step("break_open") >= 0.0 else _step("cyl_open")
			var fill := _step("rounds_in")
			var shut := _step("break_close") if _step("break_close") >= 0.0 else _step("cyl_close")
			var o := smoothstep(open_at - 0.04, open_at + 0.08, r) * (1.0 - smoothstep(shut - 0.03, shut + 0.02, r))
			open = o
			var away := smoothstep(open_at + 0.1, open_at + 0.22, r) * (1.0 - smoothstep(fill - 0.2, fill - 0.06, r))
			left_shift = Vector3(-0.05, -0.03, -0.14) * away
			if r > open_at + 0.22 and r < fill: carry = "shell"
			if WEAPONS[id].reload == "cylinder":
				var dump := smoothstep(open_at + 0.05, open_at + 0.14, r) * (1.0 - smoothstep(open_at + 0.2, open_at + 0.3, r))
				turn = Quaternion(Vector3.UP, -0.55 * o) * Quaternion(Vector3.RIGHT, 0.6 * dump)
			else:
				turn = Quaternion(Vector3.RIGHT, -0.5 * o)
			if r > shut and r < shut + 0.04: _spring_rv.x += 1.2 * delta * 30.0
		"string":
			# Balestra: la volata va giù, la sinistra tende la corda verso il calcio, poi appoggia il dardo.
			var pull := _step("string")
			var load_at := _step("bolt_in")
			var down := smoothstep(0.02, 0.15, r) * (1.0 - smoothstep(load_at + 0.05, load_at + 0.15, r))
			turn = Quaternion(Vector3.RIGHT, -0.45 * down)
			var tug := smoothstep(0.12, pull, r) * (1.0 - smoothstep(pull + 0.02, pull + 0.12, r))
			left_shift = Vector3(0, -support - 0.05, 0.05) * tug
			if r > pull + 0.08 and r < load_at: carry = "shell"
			if r > pull and r < pull + 0.04: _spring_pv.z += 0.3 * delta * 30.0
		_:
			var o := _step("mag_out")
			var i := _step("mag_in")
			var s := _step("slide")
			# Il vecchio scivola fuori dal pozzetto, il nuovo sale e il palmo lo chiude in i.
			mag_out = smoothstep(o - 0.02, o + 0.18, r) * (1.0 - smoothstep(i - 0.1, i, r))
			open = smoothstep(o - 0.08, o, r) * (1.0 - smoothstep(i + 0.04, i + 0.12, r))     # coperchio della mitragliatrice
			var away := smoothstep(o + 0.06, o + 0.2, r) * (1.0 - smoothstep(i - 0.22, i - 0.06, r))
			if r > o + 0.22 and r < i - 0.06: carry = "mag"
			if r > i and r < i + 0.05: _spring_pv.y += 0.4 * delta * 30.0
			var rack := 0.0
			if s >= 0.0:      # solo da vuoto: la sinistra tira indietro il carrello e lo lascia andare in s
				rack = smoothstep(s - 0.12, s - 0.05, r) * (1.0 - smoothstep(s + 0.04, s + 0.1, r))
				slide_back = smoothstep(s - 0.07, s - 0.01, r) * (1.0 - smoothstep(s, s + 0.02, r))
			left_shift = Vector3(-0.06, 0.06, 0.0) * away + Vector3(-0.03, -support * 0.5, 0.12) * rack
	return turn


## Parti mobili del glb (nodi separati con il pivot vero): [nodo, trasformazione di riposo] per ruolo.
## La balestra chiama "Bolt" il dardo; il fucile di precisione l'otturatore.
static func find_parts(item: Node3D, weapon: String) -> Dictionary:
	var parts := {}
	if item == null: return parts
	var roles := {"mag": ["*_Mag"], "slide": ["*_Slide", "*_Charging", "*_Knob"], "hinge": ["*_Barrels", "*_Barrel"], "cover": ["*_Cover"]}
	if weapon == "crossbow": roles["dart"] = ["*_Bolt"]
	else: roles["slide"].append("*_Bolt")
	if weapon == "revolver": roles["cylinder"] = ["*_Cylinder"]
	for role in roles:
		for pattern in roles[role]:
			var n := item.find_child(pattern, true, false) as Node3D
			if n:
				parts[role] = [n, n.transform]
				break
	return parts


## Mette le parti dove dice la ricarica. `slide` aggiunge il carrello tenuto aperto da fuori (sparo, arma vuota);
## `loaded` dice se c'è un dardo sulla balestra. Corse prese dalle clip Wep_Reload dei modelli.
func pose_parts(parts: Dictionary, slide: float, loaded: bool) -> void:
	if parts.has("mag"):
		var m: Array = parts.mag
		m[0].position = (m[1] as Transform3D).origin + Vector3(0, -0.15, 0) * mag_out
		m[0].visible = mag_out < 0.98
	if parts.has("slide") and (slide > 0.0 or _r >= 0.0 or not WEAPONS[id].has("cycle")):    # pompa, leva, otturatore: anche Wep_Fire
		parts.slide[0].position = (parts.slide[1] as Transform3D).origin + Vector3(0, 0, 0.035) * maxf(slide_back, slide)
	if parts.has("hinge"):
		parts.hinge[0].transform = parts.hinge[1] * Transform3D(Basis(Vector3.RIGHT, -0.66 * open), Vector3.ZERO)
	if parts.has("cover"):
		parts.cover[0].transform = parts.cover[1] * Transform3D(Basis(Vector3.RIGHT, 1.2 * open), Vector3.ZERO)
	if parts.has("cylinder"):
		parts.cylinder[0].position = (parts.cylinder[1] as Transform3D).origin + Vector3(-0.04, -0.02, 0) * open
	if parts.has("dart"):
		parts.dart[0].visible = loaded or (_r >= 0.0 and _r >= _step("bolt_in"))


func _step(name: String) -> float:
	for step in _steps:
		if step[1] == name: return float(step[0])
	return -1.0


## La posa finale dell'arma, con il rinculo e il respiro, nello spazio della camera.
func frame() -> Transform3D:
	var q := Quaternion.from_euler(_spring_r * 0.09 + Vector3(sin(_clock * 1.3), 0, sin(_clock * 0.9)) * 0.008)
	var step := Vector3(sin(_clock * 8.0) * 0.012, abs(cos(_clock * 8.0)) * 0.02, 0) * walk
	# In prima persona le braccia non devono coprire la vista: oltre un certo punto l'arma non si avvicina.
	var at := pos
	if not outside and kind != "axe":
		at.z = minf(at.z, -0.3)
		at.y = minf(at.y, 0.03) - 0.04 * (1.0 - _aim_w)     # mirando la tacca resta sulla linea dell'occhio
	return Transform3D(Basis(q * rot), at + _spring_p * 0.1 + Vector3(0, sin(_clock * 1.6) * 0.003, 0) + step)


## Il pugno con il braccio com'è: la mano sinistra scivola sulla canna o sul manico finché ci arriva, così non resta mai a mezz'aria.
## Il polso non si piega oltre MAX_WRIST: le nocche seguono l'avambraccio, nel colpo tendono al filo ma senza spezzarsi.
static func fist_for(w: Transform3D, grip_row: Dictionary, side: String, shoulder: Vector3, up: Vector3, reach: float, palm: float, longest: float, shift: Vector3, edge: float) -> Array:
	var along: Vector3 = shift
	var fist: Array = []
	for i in 14:
		var center: Vector3 = w * ((grip_row["c"] as Vector3) + along)
		fist = hand_on(w, grip_row, side, _arm_way(w, grip_row, center, shoulder, up, edge), reach, palm, along)
		if side == "r" or (fist[0] as Vector3).distance_to(shoulder) <= longest: break
		along.y -= 0.03
	return fist


const MAX_WRIST := 1.05


static func _arm_way(w: Transform3D, grip_row: Dictionary, center: Vector3, shoulder: Vector3, up: Vector3, edge: float) -> Vector3:
	var thumb: Vector3 = (w.basis * (grip_row["t"] as Vector3)).normalized()
	var arm: Vector3 = (center - shoulder).normalized() + up * 0.45
	var arm_flat: Vector3 = arm - thumb * arm.dot(thumb)
	var blade: Vector3 = w.basis.x - thumb * w.basis.x.dot(thumb)
	blade = blade.normalized()
	# Manico quasi in linea con l'avambraccio: lì la direzione non è affidabile, comanda il filo.
	if arm_flat.length() < 0.5: arm_flat += blade * (0.5 - arm_flat.length()) * 2.0
	arm_flat = arm_flat.normalized()
	var angle: float = arm_flat.signed_angle_to(blade, thumb)
	return arm_flat.rotated(thumb, clampf(angle * edge, -MAX_WRIST, MAX_WRIST))


## Il pugno chiuso attorno all'arma: [polso, nocche, palmo]. `reach` e `palm` sono le misure della mano del rig.
## `arm` è l'arrivo dell'avambraccio, nello stesso spazio di `w`.
static func hand_on(w: Transform3D, grip_row: Dictionary, side: String, arm: Vector3, reach: float, palm: float, shift := Vector3.ZERO) -> Array:
	var thumb: Vector3 = (w.basis * (grip_row["t"] as Vector3)).normalized()
	var fingers: Vector3 = w.basis * (grip_row["f"] as Vector3) if grip_row.has("f") else arm
	fingers = (fingers - thumb * fingers.dot(thumb)).normalized()
	var out: Vector3 = thumb.cross(fingers) if side == "r" else fingers.cross(thumb)
	var center: Vector3 = w * ((grip_row["c"] as Vector3) + shift)
	return [center - fingers * reach - out * palm, fingers, out]
