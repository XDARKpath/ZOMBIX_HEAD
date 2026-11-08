# ZOMBIX HEAD · Guida animazioni (per chi le implementa, anche un futuro Claude)

Questa cartella è la **fonte di verità** per i movimenti delle braccia in prima persona e per le animazioni in terza persona.
Le GIF servono a vedere il movimento, i JSON a riprodurlo esattamente. Anche gli zombie sono descritti qui.

## 1. Convenzioni (non cambiarle)

| Cosa | Convenzione |
|---|---|
| FPS | 30 fotogrammi al secondo. Tutte le clip sono *in place* |
| Personaggio | Rig da 65 ossa (nomi Synty/UE: `pelvis`, `spine_01..03`, `neck_01`, `head`, `upperarm_l`, `hand_r`…). In Godot guarda verso **+Z** |
| Frame arma (pistole e fucili) | Origine sull'impugnatura della mano che spara, **+Y canna**, **+Z sopra**, +X destra. In Godot la canna è **-Z** e il sopra è **+Y** |
| Frame lama | +Z lungo la lama, +Y verso il filo, origine sulla mano destra, inclinata di **-17° su X** rispetto al frame arma |
| Socket | L'osso `weapon_anchor` contiene già la matrice dell'arma; `weapon_item.gd` applica `SOCKET_BASIS = Basis((1,0,0),(0,0,1),(0,-1,0))` |
| Due mani (spada/katana) | Mano sinistra 0,11 m sotto la destra lungo l'asse della lama |
| Due mani (ascia, piccone, mazza, chitarra) | Mano sinistra **0,36 m** sotto la destra, verso il pomolo |
| Fucili | Mano sinistra sull'astina a y ≈ 0,30 m (`HL_RIFLE`); le armi nuove hanno l'astina fra y 0,22 e 0,38 |

## 2. Prima persona: come usare le curve

`curves/<clip>.json` contiene, per ogni fotogramma, posizione (metri) e quaternione (x, y, z, w) di
`weapon_anchor`, `hand_r`, `hand_l`, `lowerarm_r` e `lowerarm_l` **nello spazio della camera**. È lo stesso spazio di
`Camera3D` in Godot: +X destra, +Y su, -Z avanti. La camera è attaccata all'osso `head`
(`camera_from_head` nel file), cioè all'altezza degli occhi, 8 cm davanti al centro della testa.

```gdscript
var fps := FPSCurvePlayer.new()          # animation_reference/fps_curve_player.gd
camera.add_child(fps)
fps.weapon = preload("res://art/env/weapons/SM_Wep_FireAxe.glb").instantiate()
fps.add_child(fps.weapon)
fps.play("res://animation_reference/curves/Player_Axe_Chop_Overhead.json")
```

Regole per un viewmodel FPS:
- Usa la traiettoria di `weapon_anchor` così com'è. Il colpo cade sul fotogramma indicato nella tabella sotto: in quel momento apri la finestra di danno.
- Le mani seguono l'arma. Con due mani, le mani destra e sinistra restano alla distanza indicata sopra, quindi l'ascia non scivola mai fra le dita.
- Se il viewmodel ha un FOV diverso da 80°, scala solo la profondità (z) e lascia invariata la rotazione.

## 3. Ascia a due mani (`SM_Wep_FireAxe`, piccone, mazza, chitarra)

| Clip | Fotogrammi | Colpo | Descrizione |
|---|---|---|---|
| Player_Axe_Idle | 60 (loop) | – | Ascia diagonale sul petto, testa in alto a destra, respiro |
| Player_Axe_Swing_Horizontal | 34 | 13–17 (picco 15) | Carica sopra la spalla destra, colpo orizzontale da destra a sinistra, il busto ruota |
| Player_Axe_Swing_Back | 32 | 12–16 (picco 14) | Rovescio da sinistra a destra (combo dopo l'orizzontale) |
| Player_Axe_Chop_Overhead | 44 | 18–22 (picco 21) | Colpo pesante: braccia sopra la testa, poi giù dritto davanti, piegando le gambe |
| Player_Axe_Block | 30 (loop) | – | Manico orizzontale davanti al viso |
| Player_Axe_Shove | 20 | 7–10 (picco 9) | Spinta col manico per allontanare l'infetto |

## 4. Katana e spada

| Clip | Fotogrammi | Colpo | Descrizione |
|---|---|---|---|
| Player_Sword_Idle | 60 (loop) | – | Guardia media (chudan), punta verso la gola |
| Player_Sword_Slash_1 / _2 | 24 | 9–14 (picco 11) | Fendenti diagonali (combo) |
| Player_Sword_Slash_3 | 28 | 10–18 (picco 12) | Affondo con passo avanti, la punta va dritta in avanti |
| Player_Sword_Heavy | 36 | 14–19 (picco 17) | Fendente dall'alto con passo |
| Player_Sword_Block | 30 (loop) | – | Lama orizzontale alta |
| Player_Sword_Parry_Riposte | 34 | 5–9 parata, 17–21 colpo | Parata alta, poi contrattacco |
| Player_Sword_Dodge_Back | 22 | – | Passo indietro con la lama in guardia |
| Player_Katana_Draw_Iai | 28 | 8–12 (picco 10) | Estrazione dal saya con taglio |
| Player_Katana_Sheathe | 34 | – | Chiburi, poi rinfodero |

## 5. Clip di ogni arma

| Arma (id ZXWeapons) | Classe | Idle | Attacco / fuoco | Pesante | Ricarica |
|---|---|---|---|---|---|
| pistol, revolver, smg, flare_gun, nailgun | pistol | Pistol_Idle | Pistol_Fire / Revolver_Fire / SMG_Fire_Auto | – | Pistol_Reload / Revolver_Reload |
| assault_rifle, sniper_rifle, pump_shotgun | rifle | Idle_Rifle | Rifle_Fire_Auto / Sniper_Fire_Bolt / Shotgun_Fire_Pump | – | Rifle_Reload / Shotgun_Reload_Shell |
| sawn_off | rifle | Idle_Rifle | Rifle_Fire_Single | – | **Break_Reload** (apre le canne, 2 cartucce, chiude) |
| lever_rifle | rifle | Idle_Rifle | **Lever_Fire** (la mano scende con la leva) | – | Shotgun_Reload_Shell |
| crossbow | rifle | Idle_Rifle | Rifle_Fire_Single | – | **Crossbow_Reload** (piede nella staffa, tira la corda, mette il dardo) |
| lmg | rifle | Idle_Rifle | Rifle_Fire_Auto | – | **LMG_Reload** (apre il coperchio, cambia la cassetta) |
| grenade_launcher, tesla_rifle | rifle | Idle_Rifle | Rifle_Fire_Single / Rifle_Fire_Auto | – | Shotgun_Reload_Shell / Rifle_Reload |
| leaf_blower | rifle | Idle_Rifle | **Blower_Sweep** (spazza a destra e a sinistra) | – | Rifle_Reload |
| katana, longsword | sword | Sword_Idle | Sword_Slash_1/2/3 | Sword_Heavy | – |
| fire_axe, pickaxe, sledgehammer, electric_guitar | axe | Axe_Idle | Axe_Swing_Horizontal / Back | Axe_Chop_Overhead | – |
| machete, crowbar, nail_bat, frying_pan | melee1h | Melee1H_Idle | Melee1H_Swing / Swing_Back | Slap o **Melee1H_Bonk** | – |
| combat_knife | melee1h | Melee1H_Idle | **Knife_Stab** / Melee_Knife_Slash | Melee1H_Swing_Back | – |
| trout, baguette, rubber_chicken | melee1h | Melee1H_Idle | Melee1H_Swing / Swing_Back | Melee1H_Slap | – |

`weapons/<id>.gif` mostra ogni arma in sequenza (idle, attacco o fuoco, pesante, ricarica), in terza persona e in prima persona.
Le parti mobili (canne, leva, dardo, coperchio, ventola) si muovono in sincronia: `Wep_Fire` parte insieme alla clip di fuoco,
`Wep_Reload` insieme alla clip di ricarica.

## 6. Zombie

I dati sono in `art/zombie_motion/zombie_motion.res` (21 clip), applicati da `art/infected_motion.gd` agli infetti.
Ogni rotazione è un delta nello spazio dello scheletro rispetto alla T-pose, la stessa formula di `survivor_visual.transform_bone()`.

| Tipo (`kind`) | Inseguimento | Movimento | Attacchi |
|---|---|---|---|
| 0 normale | 0,95 m/s, **non corre mai** | Z_Walk_A / Z_Walk_B (trascina un piede) | Swipe_R, Swipe_L, Lunge_Bite a rotazione |
| 1 runner | 4,2 m/s | Z_Run | Z_Attack_Leap (salto da 3 m), a volte Swipe_R |
| 2 bruto | 0,8 m/s | Walk, più lento | Z_Attack_Overhead_Smash |
| 3 elite | 1,3 m/s | Walk veloce | Lunge_Bite, Swipe_L |

Tempi degli attacchi (`attacks` nel file dati): **lunghezza / colpo / portata / affondo**.
`zombie_ai.gd` applica il danno esattamente sul fotogramma del colpo, si gira verso il bersaglio durante la carica e avanza
con l'affondo. Così il colpo si vede e arriva nello stesso momento.

| Clip | Durata s | Colpo s | Portata m |
|---|---|---|---|
| Z_Attack_Swipe_R / L | 1,20 | 0,63 | 1,7 |
| Z_Attack_Lunge_Bite | 1,27 | 0,63 | 1,9 |
| Z_Attack_Overhead_Smash | 1,40 | 0,73 | 1,9 |
| Z_Attack_Leap | 1,00 | 0,43 | 2,4 |
| Z_Crawl_Attack | 1,00 | 0,53 | 1,3 |

Le altre clip:
- base: Z_Idle, Z_Feed_Kneel (alcuni infetti mangiano quando sono fermi), Z_Scream (urla quando ti vedono per la prima volta);
- colpi subiti: Z_Hit_Front, Z_Hit_Head, Z_Hit_L, Z_Hit_R, Z_Stagger_Heavy (colpo pesante);
- morti: Z_Death_Back, Z_Death_Front, Z_Death_Spin (scelte da `death_style`);
- strisciante: Z_Crawl, Z_Crawl_Attack (dopo un colpo ai piedi).

Le anteprime sono in `zombies/preview/*.gif`.

## 7. Rigenerare

Le clip sono codice in `source/scripts/`: `clips3.py` (ascia, katana, auto, riparazione, NPC), `clips4.py` (armi nuove) e
`zombie_clips.py` (zombie). Per modificare un movimento cambia le pose a chiave (rotazioni sugli assi del mondo: X = sinistra del personaggio,
-Y = davanti, Z = su) e poi riesporta. Per gli zombie usa `zombie_clips.bake()` seguito da `tools/convert_zombie_motion.gd`.
