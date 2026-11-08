# Licenze e pubblicazione su Steam

> **Superato il 6 novembre 2026: lo stato valido è in `docs/ART_LICENZE.md`.** Qui sotto resta la storia. Quello che dice sul cast Synty Generic e sul "nessun blocco noto" è **sbagliato**: l'utente non ha licenze Synty/POLYGON, e nel progetto restavano il cast e un coltello Synty (ora tolti).

Data dell'audit: 31 ottobre 2026. Ultimo aggiornamento: 1 novembre 2026, dopo la
rimozione degli asset non distribuibili. Non è consulenza legale: serve a sapere
cosa c'è nella build prima di caricarla.

## Riepilogo

| Stato | Gruppi | Pubblicabile su Steam |
|---|---|---|
| ✅ OK | Natura Quaternius, KayKit (forest, city, skeletons, dungeon), armi CC0, fumo Kenney, font Barlow, Gas Station | Sì |
| ✅ OK | Segnaposto originali del progetto (`art/placeholders.gd`, `ui/camp/source_hands.gd`, pistola procedurale) | Sì |
| ✅ OK | Effetti sonori in `audio/`, sintetizzati da `tools/make_audio.py` | Sì |

Nessun blocco noto: nella build non restano file estratti da giochi commerciali
né pacchetti Synty non acquistati.

## 🗑️ Cosa è stato rimosso (1 novembre 2026)

| Percorso | Contenuto | Motivo |
|---|---|---|
| `art/surroundead/` | 32 modelli (edifici, veicoli, zombi, ascia, coltello, ponte) + `provenance.json` | Estratti da SurrounDead con CUE4Parse |
| `art/refuge/` | 55 moduli edilizi e arredi | POLYGON Gang Warfare non acquistato (`sources.json`) |
| `art/gang_warfare/` | 3 sopravvissuti, 2 mani, pistola | POLYGON Gang Warfare non acquistato |
| `art/archery/`, `art/bow*`, `crossbow.tscn`, `arrow*`, `bolt.tscn` | Archi, balestra, frecce, dardi | POLYGON BowAndCrossbow non acquistato |
| `art/animations/` | Universal Animation Library | CC0, ma ritargettizzata sui rig rimossi |
| `art/how_to_fish/` | Props della pesca | Stessa origine degli altri pacchetti |
| `tools/build_camp_hands.gd`, `tests/inspect_assets.gd` | Script che leggevano i modelli rimossi | Non più necessari |

Rimosse anche le scene e le voci di menu che esponevano archi e balestra.

## ✅ Cosa c'è al loro posto

Tutto ciò che dipendeva dai modelli rimossi ora ha un **fallback originale**:
se il file esiste viene caricato, altrimenti il gioco costruisce il segnaposto e
continua a funzionare.

| Segnaposto | File | Uso |
|---|---|---|
| Cast Synty Generic (22 corpi, atlante `Generic_01_A`) | `art/synty_generic/` + `art/synty_cast.gd` | Sopravvissuti, lobby, sceriffo |
| Manichino snodato (17 ossa con i nomi del vecchio rig) | `art/placeholders.gd` → `humanoid()` | Fallback e infetti (testa staccabile) |
| Mano a 20 falangi | `ui/camp/source_hands.gd` | Prima persona, attività al falò, presa armi |
| Ascia, coltello, pistola | `art/placeholders.gd` → `axe()`, `knife()`, `pistol()`; `art/weapons/pistol.tscn` + `pistol_placeholder.gd` | Visuali in prima persona e pistola dello sceriffo |
| Edifici a blocchi su griglia 3 m | `art/placeholders.gd` → `village_block()` | Villaggio, officina, ufficio dello sceriffo |
| Tenda, camion, barile, barca, canna da pesca | `art/placeholders.gd` | Campagna e riva del lago |
| Alberi e rocce | `art/nature/`, `art/kaykit_forest/` (CC0) | Paesaggio, rifugio, campo |
| Effetti sonori | `tools/make_audio.py` (solo stdlib Python) | `audio/*.wav` |

Il manichino conserva i nomi osso del rig precedente (`pelvis`, `spine_01/02`,
`neck_01`, `head`, `upperarm/lowerarm/hand_l/r`, `thigh/calf/foot_l/r`): pose
procedurali, IK, hitbox localizzate e decapitazione non sono cambiate. Le
finestre e gli arredi del blockout non hanno collisione, così non bloccano raggi
e interazioni delle missioni.

## Cast Synty fornito dall'utente

Il giocatore ha fornito sulla propria macchina i sorgenti **Synty POLYGON**
(`POLYGON_Generic_SourceFiles_v3`, `POLYGON_Starter_Godot_4_6_2`,
`POLYGON_QuadBike`, `POLYGON_Wheelchair`, `POLYGON_Pumpkins`,
`POLYGON_AdultFacePlates`, `SIMPLE_FX`, `SIMPLE_Sky`) dichiarandone i diritti
d'uso. Da questi è stato importato solo il cast Generic in `art/synty_generic/`:
un FBX da 7,3 MB con ventidue corpi skinnati su un unico scheletro da 50 ossa e
l'atlante `Generic_01_A`.

- `art/synty_cast.gd` istanzia il FBX e rende visibile un solo corpo (più
  capelli/barba abbinati), perché tutti i personaggi condividono lo scheletro.
- `art/survivor_visual.gd` aggiunge gli alias osso Synty → nomi del gioco, così
  pose, IK e hitbox non cambiano.
- `ui/camp/source_hands.gd` delega a `hand_mesh_trim.gd` il ritaglio delle mani
  fuse nel corpo; al loro posto resta il guanto procedurale a 20 falangi.
- Gli infetti continuano a usare il manichino: la decapitazione ha bisogno del
  nodo `HeadPiece`, che il modello Synty non espone.

La licenza Synty consente l'uso commerciale degli asset **dentro il gioco**, ma
vieta di ridistribuirli come pacchetto di asset: il FBX resta nel progetto per
la build, non va pubblicato a parte né condiviso. Gli altri pacchetti dello
stesso gruppo (Starter, FX, Sky, QuadBike, Wheelchair, Pumpkins, FacePlates)
sono disponibili ma non ancora importati.

## ✅ Asset con licenza verificata ancora in uso

| Asset | Licenza | Prova |
|---|---|---|
| `art/nature/` (68 modelli Stylized Nature MegaKit FREE) | **CC0 1.0** | `art/nature/LICENSE.txt` |
| `art/kaykit_forest/` | **CC0 1.0** | `art/kaykit_forest/LICENSE.txt` |
| `art/kaykit_city/` (KayKit City Builder Bits, 41 modelli) | **CC0 1.0** | `art/kaykit_city/LICENSE.txt` |
| `art/kaykit_skeletons/` (KayKit Skeletons) | **CC0 1.0** | `art/kaykit_skeletons/LICENSE.txt` |
| `art/kaykit_dungeon/` (KayKit Dungeon) | **CC0 1.0** | `art/kaykit_dungeon/LICENSE.txt` |
| Fucile, katana e altre armi CC0 | **CC0** | `art/weapons/ATTRIBUTION.md` |
| Ascia KayKit Adventurers (`axe_2handed`) | **CC0 1.0** | `art/weapons/imported/kaykit_axe/LICENSE.txt` |
| Fumo/vapore Kenney | **CC0** | `art/camp/ATTRIBUTION.md` |
| Font Barlow Condensed | **SIL OFL 1.1** | `art/fonts/OFL.txt` |
| Gas Station (Atomic Realm Assets) | Uso commerciale consentito, vietata la ridistribuzione degli asset | `art/gas_station/2. License.png` |

CC0 non richiede attribuzione, ma tenerla nel README è buona pratica.

## Audio

I nove file in `audio/` (`hit`, `heavy`, `swing`, `footstep`, `fire`, `forest`,
`vehicle_engine`, `menu_hover`, `menu_press`) sono generati da
`tools/make_audio.py` con la sola libreria standard di Python: nessun campione
di terzi. Per rigenerarli basta eseguire lo script dalla cartella del progetto.

## Prossimo passo (facoltativo)

I segnaposto sono giocabili ma provvisori. `docs/ASSET_CC0.md` elenca i
pacchetti definitivi con licenza verificata (Quaternius, Kenney, KayKit) e la
mappa dei file: quando arrivano, si copiano nelle cartelle e il gioco li carica
al posto dei segnaposto senza modifiche al codice, perché ogni punto di aggancio
controlla prima se il modello esiste.

## Nota su Steam

Valve non verifica le licenze in fase di caricamento, ma risponde alle segnalazioni
DMCA con la rimozione del gioco e possibili conseguenze sull'account. Nella build
attuale non ci sono asset riconducibili a SurrounDead o Synty: il rischio è
legato solo agli asset CC0 e originali elencati sopra.

## Erba GPU
art/grass/grass_diffuse_1024.png e la tecnica di world/grass/ derivano da https://github.com/AndreVallestero/godot-grass-shader — licenza MIT, (c) 2022 Andre Vallestero. Testo in art/grass/LICENSE.txt, dettagli in art/grass/ATTRIBUTION.md.

## Acqua del lago
art/water/ deriva da https://github.com/Chrisknyfe/boujie_water_shader — licenza MIT, (c) 2023-present Zach Bernal and contributors. Testo in art/water/LICENSE.md, dettagli in art/water/ATTRIBUTION.md. Pontile e barca: modelli originali (tools/lake/build_lake_props.py).
