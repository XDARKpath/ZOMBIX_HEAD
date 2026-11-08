# 10 asset CC0 per sostituire quelli bloccati

Tutti i pacchetti qui sotto sono **CC0 1.0** (o equivalenti verificati): uso
commerciale libero, nessuna attribuzione obbligatoria, nessun vincolo su Steam.
Le date di verifica sono al 31 ottobre 2026; i link portano alla pagina
ufficiale dell'autore, non a mirror.

## Perché servono

L'audit di `docs/LICENZE.md` ha trovato quattro gruppi non distribuibili:

| Cartella | File | Origine |
|---|---|---|
| `art/surroundead/` | 32 modelli | estratti da SurrounDead (Synty Apocalypse/Military) |
| `art/refuge/` | 55 modelli | POLYGON Gang Warfare non acquistato |
| `art/gang_warfare/` | 3 personaggi + 2 mani + pistola | POLYGON Gang Warfare non acquistato |
| `art/archery/` + archi/balestra | texture + scene | POLYGON BowAndCrossbow non acquistato |

Tutte e quattro le cartelle sono state **rimosse il 1 novembre 2026**. Al loro
posto sono arrivati i **sorgenti Synty POLYGON forniti dall'utente** (Generic,
Starter, FX, Sky, QuadBike, Wheelchair, Pumpkins, FacePlates): il cast Generic è
già collegato a sopravvissuti e sceriffo in `art/synty_generic/`, mentre per il
resto il gioco usa i segnaposto originali (`art/placeholders.gd`,
`ui/camp/source_hands.gd`). La mappa in fondo dice cosa è già coperto e cosa
manca; i pacchetti CC0 restano un'alternativa se in futuro si vuole togliere
anche Synty dal progetto.

## Cosa è già stato installato

**Pacchetto 4 — KayKit City Builder Bits**: scaricato da GitHub
(`KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0`, licenza CC0 nel file
`LICENSE.txt`), importato in `art/kaykit_city/` con 41 modelli glTF e la texture
`citybits_texture.png`. Nel gioco lo usa `world/zona1_rifugio/refuge_set.gd`
(`city()`, scala 4×) per cinque palazzi di sfondo, cinque auto abbandonate,
cassonetti, panchine, idrante, semaforo, casse e vegetazione dei lotti. Gli
edifici giocabili e gli arredi interni sono ora **segnaposto a blocchi**
(`art/placeholders.gd`), pronti a essere rimpiazzati dai moduli Quaternius.

**KayKit Character Pack: Skeletons** e **KayKit Dungeon Remastered** (entrambi
CC0, scaricati da GitHub) sono in `art/kaykit_skeletons/` e
`art/kaykit_dungeon/`. Il primo fornisce i tre custodi della Zona 1 (guerriero,
mago, ladro) con 95 animazioni ciascuno, usate da `bosses/boss.gd`; il secondo
fornisce torce, casse, barili e stendardi delle arene (`bosses/boss_hunt.gd`).

Gli altri nove pacchetti **non sono stati scaricati**: kenney.nl risponde 403 ai
download automatici e i link Quaternius passano da una cartella Google Drive che
richiede il consenso dell'utente. I punti 1, 2, 3, 5, 6, 7, 8, 9 e 10 restano
quindi da fare a mano, seguendo le istruzioni qui sotto.

## La lista

### 1. Quaternius — Zombie Apocalypse Kit

- **Licenza**: CC0 (scritta nella scheda: `License CC0`)
- **Formati**: FBX, OBJ, glTF, Blend — **glTF nativo per Godot 4.5**
- **Contenuto**: 60 modelli — 4 sopravvissuti con **20 animazioni ciascuno**, 4
  nemici, 2 cani, veicoli ed elementi d'ambiente.
- **Sostituisce**: `art/gang_warfare/chars/*`, gli zombi e i veicoli relitti di
  `art/surroundead/`. È il pacchetto più vicino al gioco: survivora + infetti +
  rottami, stesso low-poly piatto.
- **Nota**: il free download contiene il necessario; le versioni Pro/Source
  aggiungono solo i `.blend` e contenuti extra.
- https://quaternius.com/packs/zombieapocalypsekit.html

### 2. Quaternius — Ultimate Buildings Pack

- **Licenza**: CC0
- **Formati**: FBX, OBJ, Blend (niente glTF: importa FBX o converti)
- **Contenuto**: 76 moduli edilizi con atlanti alternativi per cambiare palette.
- **Sostituisce**: tutti i 55 `SM_Bld_*` di `art/refuge/` — muri, pavimenti,
  tetti, porte, finestre, travi. È l'unico modo per rifare il villaggio senza
  Synty.
- **Nota**: la griglia non è quella Synty da 3 m: il costruttore
  (`refuge_set.gd`) va riallineato alle misure nuove, non è un copia-incolla.
- https://quaternius.com/packs/ultimatetexturedbuildings.html

### 3. Quaternius — Ultimate Modular Ruins Pack

- **Licenza**: CC0
- **Formati**: FBX, OBJ, Blend
- **Contenuto**: 90 pezzi — muri crollati, strutture diroccate, macerie.
- **Sostituisce**: le varianti "bruciate" oggi ottenute riusando gli stessi
  moduli; dà al villaggio l'aspetto post-apocalittico senza dipendere da Synty.
- https://quaternius.com/packs/ultimatemodularruins.html

### 4. KayKit — City Builder Bits

- **Licenza**: CC0 (LICENSE.txt nel repository: *"License: (Creative Commons
  Zero, CC0)"*, uso commerciale consentito, credito non obbligatorio)
- **Formati**: FBX, GLTF, OBJ
- **Contenuto**: 32+ modelli — edifici, strade, marciapiedi, elementi urbani.
- **Sostituisce**: officina, deposito carburante e arredo della strada quando i
  moduli Quaternius non bastano; è lo stesso autore dei pini già in uso, quindi
  lo stile è coerente.
- https://kaylousberg.itch.io/city-builder-bits ·
  https://github.com/KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0

### 5. Kenney — Car Kit (v2, con detriti)

- **Licenza**: CC0 (*"all game assets on the asset pages are public domain
  licensed (CC0)"*)
- **Formati**: GLTF, OBJ, FBX, DAE
- **Contenuto**: 45 modelli, la v2 aggiunge i pezzi di **debris**.
- **Sostituisce**: `art/surroundead/SM_Veh_Truck_Destroyed_01` e i relitti lungo
  la strada; il 4×4 può restare quello procedurale già nel progetto.
- https://kenney.nl/assets/car-kit

### 6. Kenney — Survival Kit

- **Licenza**: CC0
- **Formati**: GLTF, OBJ, FBX
- **Contenuto**: 80 modelli animati — tende, barili, casse, taniche, attrezzi,
  campo base.
- **Sostituisce**: `SM_Prop_Tent_Dome_01`, `SM_Prop_Barrel_Water_01`,
  `SM_Prop_Barrel_Metal_01`, `pallet_cluster_1`, `jerry_can_with_nozzle` e le
  casse del portico dello sceriffo.
- https://kenney.nl/assets/survival-kit

### 7. Quaternius — Modular Weapons Pack

- **Licenza**: CC0
- **Formati**: FBX, OBJ, Blend
- **Contenuto**: 24 modelli — **asce**, pugnali, spade, **archi**, scudi, mazze.
- **Sostituisce**: `SM_Wep_Axe_01`, `SM_Wep_Knife_01` di `art/surroundead/` e la
  balestra/arco POLYGON di `art/archery/`.
- **Nota**: la balestra non è inclusa; per quella serve un CC0 singolo da
  OpenGameArt (collezione "CC0 Weapons", voce *Wooden Crossbow*) — verifica la
  licenza della singola pagina, non della collezione.
- https://quaternius.com/packs/medievalweapons.html

### 8. Quaternius — 50+ LowPoly Guns

- **Licenza**: CC0 (*"free for everyone … even commercially"*)
- **Formati**: FBX, OBJ, Blend
- **Contenuto**: 50+ armi da fuoco, **pistola** e revolver compresi.
- **Sostituisce**: `art/gang_warfare/pistol_gold.tscn` (la pistola Synty usata
  anche in `art/weapons/pistol.tscn`).
- **Nota**: la scena `pistol.tscn` normalizza la canna su +X e aggiunge
  `GripMain/Muzzle/Magazine`; quei tre marker vanno ricreati sul modello nuovo,
  il resto del codice non cambia.
- https://quaternius.itch.io/50-lowpoly-guns

### 9. Kenney — Impact Sounds + RPG Audio

- **Licenza**: CC0 entrambi
- **Formati**: OGG/WAV
- **Contenuto**: 130 effetti d'impatto il primo, 50 file con foley, passi e armi
  il secondo.
- **Sostituisce**: `audio/hit.wav`, `audio/heavy.wav`, `audio/swing.wav`,
  `audio/footstep.wav`.
- **Nota**: tieni i **nomi file identici** e il codice non cambia.
- https://kenney.nl/assets/impact-sounds · https://kenney.nl/assets/rpg-audio

### 10. BigSoundBank — libreria CC0

- **Licenza**: CC0 1.0 (*"use, including for commercial purposes … without any
  restrictions"*)
- **Formati**: WAV/MP3
- **Contenuto**: fuoco, passi, motori, ambienti, armi.
- **Sostituisce**: `audio/fire.wav`, `audio/forest.wav`,
  `audio/vehicle_engine.wav` — gli unici tre senza provenienza scritta.
- https://bigsoundbank.com/licenses.html

## Mappa rapida

| Nel progetto | Stato | Sostituto definitivo |
|---|---|---|
| Personaggi (`SM_Chr_*`, `SM_Zombie_*`) | manichino procedurale | 1 |
| Cast della lobby e sceriffo | manichino procedurale | 1 |
| Edifici del villaggio (55 moduli) | blockout `village_block()` | 2 (+3 per le rovine) |
| Arredi interni (`SM_Prop_*`) | blockout `village_block()` | 6 (+2) |
| Veicoli (`SM_Veh_*`) | camion procedurale | 5 |
| Alberi | **già fatto** con `art/nature/` e `art/kaykit_forest/` (CC0) | — |
| Ascia e coltello | segnaposto procedurali | 7 |
| Pistola | `pistol.tscn` procedurale con marker | 8 |
| Archi e balestra | rimossi (nessuna scena) | 7 (+1 CC0 singolo) |
| `audio/hit, heavy, swing, footstep` | già sintetizzati da `tools/make_audio.py` | 9 |
| `audio/fire, forest, vehicle_engine` | già sintetizzati da `tools/make_audio.py` | 10 |

## Da NON usare come "asset pack"

- **Mixamo**: le animazioni si possono usare *dentro* un gioco commerciale, ma la
  licenza Adobe vieta di distribuire i file grezzi, i pacchetti e i DLC che li
  contengono. Va bene come target di retarget con i clip cotti nella build, non
  come cartella di asset nel progetto.
- **Freesound**: la licenza è **per singolo suono**. I file `CC BY-NC` vietano
  l'uso commerciale e i pacchetti misti sono la trappola più comune. Filtra su
  CC0, uno per uno.
- **Sonniss GDC Bundle**: royalty-free per il gioco finito, ma il EULA vieta di
  ridistribuire i suoni (anche modificati) in pacchetti, template o mod kit. Non
  è CC0: non scriverlo nei crediti come pubblico dominio.
- **Poly Pizza**: aggregatore, licenza per modello; buona parte è CC-BY. Scarica
  dall'autore originale, non dal mirror.

## Cosa è già a posto

`art/nature/` (Quaternius CC0), `art/kaykit_forest/`, `art/kaykit_city/`,
`art/kaykit_skeletons/`, `art/kaykit_dungeon/` (CC0), fumo Kenney, font Barlow
(OFL), `art/gas_station/` (uso commerciale, vietata la rivendita). Non vanno
toccati. `art/animations/` è stato rimosso: era CC0 ma legato ai rig protetti.

## Ordine di lavoro consigliato

1. **Audio** (9 e 10): mezz'ora, nessuna modifica al codice, toglie tre file
   senza provenienza.
2. **Armi** (7 e 8): scene piccole, si ricreano i marker di presa.
3. **Personaggi** (1): rig nuovo, quindi rivedere `art/survivor_visual.gd`,
   `ui/camp/source_hands.gd` e la posa degli infetti.
4. **Edifici** (2, 3, 4, 6): l'intervento più lungo, perché cambia la griglia
   del costruttore del villaggio.
