# Batch ZOMBIX nel gioco (Env Batch 1, Batch 2, Concept Panels)

## Dove sono gli asset
| Cartella | Contenuto | Origine |
|---|---|---|
| `art/env/` | 61 asset del kit ambiente (edifici modulari, negozio, interattivi) + armi v2 | ZOMBIX_Env_Batch1.zip, armi e script sostituiti da ZOMBIX_Batch2.zip come da README |
| `art/zx_player/` | SM_ZX_Player: 10 skin, 65 ossa, 49 clip, menu skin | ZOMBIX_Batch2.zip |
| `art/zx_infected/` | 4 walker, spitter, tank, 3 boss, lampione del boss, 5 NPC + armi in mano | **generati** con `tools/zx_characters/build_characters.py` dagli script originali di characters.py (tavole concept) |

Rigenerare i personaggi:
```
blender --background --factory-startup --python tools/zx_characters/build_characters.py -- ZOMBIX_HEAD/art
```
Gli script copiati in `tools/zx_characters/` (survivor, env, zx) sono quelli dei tre zip; il percorso del
Survivor .blend è impostato in locale. Le armature sono esportate in posa di riposo: tutte le pose sono procedurali.

## Gameplay
- **Esca dei custodi**: gli altari delle arene sono spenti. Lo sceriffo dà un'esca ogni 5 teste consegnate
  (massimo 3, una per custode). E all'altare con un'esca: si accende e il custode esce. Icona a fiammella nell'HUD.
- **Skin**: le 10 skin ZX nel menu CHARACTER (precedente/successiva, nome e descrizione); salvate nel profilo e
  condivise in cooperativa. In gioco il corpo visto dagli altri è lo ZX Player con le clip originali.
- **Infetti**: walker con quattro varianti (tipo 0 e 3), spitter (tipo 1, i corridori), tank (tipo 2, i bruti). La testa
  è un pezzo separato della mesh (`infected_anatomy.prepare`) e si stacca col colpo caricato al collo.
- **Boss**: Capomacello = Abominio dello Sceriffo con il lampione divelto, Il Mago = Matriarca Tossica (scultura
  che pulsa e si piega), Signore delle Teste = Soggetto Zero. Stessa IA e stessi attacchi di prima.

## Zona 1 (world/zona1_rifugio/zone1_kit.gd)
- Armeria: bancone, cassa retrò, munizioni, pegboard carico, banco da armaiolo con morsa e attrezzi, serranda,
  vetrina vuota, fucili v2 a parete, katana e spada lunga con i foderi, insegna GUNS & AMMO.
- Ufficio dello sceriffo: cassaforte e luce di stato rossa lampeggiante sulla cella.
- Casa del Vecchio (tronchi, tetto in lamiera, portico) sulla riva e fattoria in mattoni diroccata con capriata crollata.
- 10 casse distruttibili (si rompono con le armi, lasciano una scatoletta), 4 casse militari / rifornimenti da aprire con E.
- Piastra a pressione e filo d'inciampo alla fattoria: accendono l'allarme e fanno rumore per 30 m.
- NPC: solo sceriffo (Veterano) che fuma, armaiolo (ZXNpc del pacchetto 0.14) appoggiato al bancone e il Vecchio (giallo) che pesca sul pontile.
- Niente più casse KayKit, barili, stendardi e torce da dungeon: arene, detriti stradali e portico usano il kit ambiente
  (muro di mattoni crollato, casse di munizioni, casse distruttibili, lanterne su palo).

## Pacchetto 0.14 (animazioni, armi, negozi)
Guida: `art/animation_reference/ANIMATION_GUIDE.md`. Sorgenti .blend e GIF di riferimento fuori dal progetto, in
`../tools/zx014_source`. Copia dei file sovrascritti in `../ZOMBIX_HEAD_backup_pre014`.
- **Zombie e boss**: solo `art/infected_motion.gd` + `art/zombie_motion/zombie_motion.res` (21 clip). I normali
  camminano a 0,95 m/s e non corrono mai, i runner corrono e saltano, il danno parte sul fotogramma `hit` della clip
  (`zombie_ai.gd`). In rete passano anche `attack_clip`, `attack_serial` e `alert_time`. Capomacello usa
  Z_Attack_Overhead_Smash, il Signore delle Teste Z_Attack_Leap, con carica e colpo presi dalla clip.
- **Avatar in terza persona**: ZXPlayer con il suo AnimationTree, guidato da `art/zx_player/zx_avatar_driver.gd`. Ci sono
  le clip d'arma in combo e il colpo pesante, la ricarica, il 4×4 (salire, guidare con lo sterzo, passeggero, scendere)
  e le riparazioni (motore davanti al cofano, ruota altrove). C'è anche la raccolta dei pezzi (Install_Part) e la
  morte. L'arma vera di `art/env/weapons` è agganciata a `weapon_anchor`.
- **Prima persona**: `player/first_person_weapon.gd` segue le curve di `art/animation_reference/curves`. Ci sono le 18 del
  pacchetto e 30 ricavate dalle clip con `tests/bake_fp_curves.gd`, che riproduce le originali entro 2 mm e 1°. Le mani
  seguono hand_r/hand_l rispetto all'arma, quindi le armi a due mani restano in due mani. Un'inquadratura rigida per
  famiglia d'arma porta la curva in vista. I tempi del colpo vengono da `weapons/zx_arsenal.gd`: fotogrammi della guida
  per ascia e spada, picco di velocità della lama per le altre.
- **Ascia e pala in prima persona**: rig costruito in Blender da `tools/fp_melee/build_fp_melee.py`
  (`art/zx_fp/SM_FP_Melee.glb`, viewmodel `player/viewmodel/fp_melee.gd`).
  - Ogni pezzo (palmo, falangi, maniche, arma) pesa al 100% su un osso: niente polsi che si sciolgono.
  - Le clip muovono l'arma, le braccia la seguono con un'IK analitica (gomiti in basso e all'esterno, l'avambraccio
    ruota con la mano). Le dita sono calcolate tangenti al manico (0,2 mm di margine, nessuna compenetrazione) con
    il pollice chiuso sopra indice e medio. La destra tiene la base, la sinistra scorre sul manico.
  - Clip: Axe_Equip/Unequip (dalla cinghia dello zaino), Idle, Sprint, Light1 (orizzontale da destra), Light2
    (rovescio), Light3 (dall'alto), HeavyWindup (0,8 s dietro la testa), HeavySwing (0,15 s), HeavyRecover (0,6 s,
    strappo), Tired, Block/BlockHold, Kick (calcio frontale con la gamba). La pala usa lo stesso rig col suo modello.
- **Combattimento** (`weapons/melee/melee_controller.gd`, ascia e pala):
  - Combo a tre colpi da 25 danni; pesante caricato 0,8 s da 80 danni.
  - Sotto il 10% di stamina il colpo è più lento del 30% e trascina l'ascia.
  - Tasto destro: parata (un quarto del danno, costa fiato).
  - Zombie entro 1 m: al click parte il calcio (5 danni, lo respinge di circa 1,5 m).
  - Il danno segue l'osso "blade" solo nei fotogrammi di colpo, con un hit-stop di 0,08 s sul pesante.
- **Reazioni degli zombie** (`tools/zombie_reactions/bake_reactions.py`, clip aggiunte a `zombie_motion.res`):
  - Z_React_Hit_Left: testa e spalla destra scattano a destra, due passi di lato.
  - Z_React_Hit_Right: ruota a sinistra e cade su un ginocchio.
  - Z_React_Knockdown: crolla a faccia in giù, rimbalza e si rialza.
  - Z_React_Pushed: barcolla all'indietro agitando le braccia.
  - Gli spostamenti li fa la fisica; reazione e tempo passano in rete.
- **Emporio di Big Earl (Zona 1)**: nell'armeria vende Big Earl (`SM_NPC_Shopkeeper`, il venditore della Zona 1 nel
  catalogo del pacchetto). Sul pannello forato dietro il banco sono appese, con il prezzo, le armi della Zona 1
  di `ZXShopCatalog`: pistola, lanciarazzi, canne mozze, machete, piede di porco, mazza chiodata, trota e baguette.
  Fucili e spade delle zone successive non sono più alle pareti.
- **Armi nuove**: ascia runica (320 CR) e spada spartana (180 CR), in vetrina sopra la teca. Convertite in Blender da
  `tools/incoming/convert_new_weapons.py` (`art/env/weapons/SM_Wep_RunicAxe` e `SM_Wep_SpartanSword`, scene .tscn con
  WeaponItem). In prima persona usano il rig di ascia e pala: l'ascia a due mani, la spada a una mano.
- **Coltello e pistola**: clip fatte a mano di `art/zx_fp/SM_FP_Arms.glb` (`player/viewmodel/fp_clips.gd`).
  Con PDA e dialogo si torna alle braccia del viewmodel a curve.
- Controlli e foto: `tests/melee_overhaul_checks.gd`, `tests/fp_melee_capture.gd`, `tests/zombie_reaction_capture.gd`.
- **Armi**: tasti 1-8 sugli slot dello zaino. Ascia, coltello, pistola e pala usano i modelli fire_axe, combat_knife,
  pistol e pickaxe. Danni a tre fasce già esistenti: fuoco 30, leggera 22, pesante 34/64. Caricatore e durata della
  ricarica sono quelli dell'arma.
- **Negozi**: uno ZXShop per ogni tappa 1-7 (`world/campaign/zx_shops.gd`) e il catalogo di Zona 1 al banco
  dell'armaiolo. Si paga in crediti delle teste e l'host convalida (`zxbuy:<id>`). L'armaiolo di Zona 1 è ZXNpc
  (SM_NPC_Gunsmith, Counter_Lean, battute).
- Sceriffo, pescatore e infetti del menu restano in posa a mano, con respiro e sguardo da `art/zx_motion.gd`: il
  pacchetto non ha clip da seduto.
- Controlli: `tests/zx_shop_checks.gd`, `tests/anim_capture.gd`, `tests/avatar_capture.gd`, `tests/fp_curve_capture.gd`.
- Natura: massi con collisione, ciottoli, sentieri di pietra, felci, cespugli, funghi, trifogli, alberi secchi, tronchi.

## Zombie: gambe e teste
- Hitbox "legs" sui polpacci oltre ai piedi. Il danno alle gambe si accumula (`LEG_LIMIT` in
  `enemies/zombie_target.gd`: walker 30, corridore 26, bruto 70, mutato 36). Superata la soglia lo
  zombie barcolla (`Z_Stagger_Heavy`) e poi continua strisciando (`Z_Crawl`, `Z_Crawl_Attack`).
- Lame (`Arsenal.BLADES`: ascia da pompiere, katana, spada medievale, machete): il colpo caricato al
  collo stacca la testa, e anche il colpo che uccide con una lama la stacca. La testa resta a terra da
  raccogliere (E) e vendere allo sceriffo. Coltello e armi contundenti uccidono senza decapitare.

## Zona 1 allargata
- `world/zona1_rifugio/roadnet.gd`: due luoghi riservati e ancora vuoti, `SITES` con piazzale in piano di
  32 m. Il villaggio è a est (215, -150), con un bivio dalla statale e un raccordo dall'arena del Mago.
  Il dungeon sotterraneo è a ovest (-230, -245), in fondo alla pista oltre la fattoria, in una conca tra
  le colline. I piazzali sono di terra battuta, con quattro paletti col nastro rosso agli angoli.
- Incroci (`RoadNet.junctions()`): ogni ramo si allarga a imbuto negli ultimi 10 m dove tocca un'altra
  strada, e i rami stanno a quote di pochi millimetri diverse, così non sfarfallano dove si sovrappongono.
- Terreno: `Terrain.zone1_wave` aggiunge un'ondulazione leggera (circa ±0,8 m) a prato e strade della
  Zona 1. Paese, rovine, arene, piazzali e punti di comparsa restano in piano; gli zombie compaiono
  sempre sopra il terreno. La navigazione copre la zona allargata (`NAV_BOUNDS`).
- Foto: `tests/zone1_map_capture.gd`.

## Prato e strada
- Erba: stessa griglia GPU (porting MIT di AndreVallestero/godot-grass-shader) ma con il ciuffo basso Quaternius
  (CC0, art/nature): 32 cm, vento appena percettibile. Prima era alta e si muoveva troppo.
- Strada: decal proiettati (`world/campaign/road_decals.gd`, texture procedurali) con crepe ramificate, buche con
  pezzi d'asfalto sollevati, bordi strappati fino alla ghiaia, pozze e scie di sangue.

## Menu
Al falò: casse militari e rifornimenti del kit, munizioni, fucile a pompa e spada lunga v2, infetti fermi nella nebbia
dietro gli alberi. Le quattro sedute mostrano skin ZX diverse; il primo posto è la tua skin.

## Verifiche
`--verify-zombix` 45 PASS (3 nuove sull'esca), `tests/zone1_loop_checks.gd` 18/18, `tests/glass_checks.gd`.
Foto: `tests/batch_capture.gd`, `tests/zx_bench.gd`, `tests/menu_batch_capture.gd`, `tests/zone1_capture.gd`.

## Limiti
- Le armi v2 sono esposte (negozio, menu, NPC) ma non ancora utilizzabili: si espandono nelle zone successive.
- Pose degli NPC e dei boss procedurali, regolate a vista; la Matriarca non ha ossa.
- I decal non si vedono con il renderer Compatibilità (OpenGL).

## Lago e inizio strada
- Acqua: Boujie Water Shader (MIT) tarato per un lago calmo in world/zona1_rifugio/lake.gd (onde di Gerstner basse, schiuma a riva e attorno ai pali, rifrazione, nebbia di profondità). In OpenGL resta l'acqua semplice.
- Pontile e barca a remi modellati in Blender (tools/lake/build_lake_props.py -> art/lake): assi irregolari e mancanti, pali con controventi, piattaforma a T, scaletta, bitte, cime, lanterna accesa; la barca ormeggiata dondola.
- Inizio strada: l'asfalto arriva al lago e finisce in un piazzale di ghiaia con cordolo rotto, barriere, panchina, cestino, lampione, crepe e una scia di sangue verso l'acqua.
- Il 4x4 parte parcheggiato sul lato destro dell'ufficio dello sceriffo, muso verso la strada, con il Meccanico appoggiato.

## Ascia del kit tomahawk, arco, reazioni Mixamo, miniera e arredi
- Ascia: idle, camminata, corsa e i due fendenti leggeri seguono le traiettorie del kit FPS del tomahawk
  (`tools/fp_melee/extract_kit.py` -> `tomahawk_track.json`, usato da `build_fp_melee.py`). Pesante, parata e calcio
  restano a due mani.
- Zombie: quattro clip Mixamo convertite (`tools/zombie_reactions/mixamo_to_zombie.py`): colpo forte da destra e da
  sinistra (specchiato), reazione alla parata (lo zombie rimbalza indietro quando colpisce chi para) e combo del Tank.
- Arco (Big Earl, 150 CR, con 12 frecce; frecce x10 a 20 CR senza occupare slot): viewmodel del kit
  `low-poly-bow-fps-animation` (`tools/fp_bow/convert_bow_kit.py` -> `art/zx_fp/SM_FP_Bow.glb`, `player/viewmodel/fp_bow.gd`).
  Si tende tenendo premuto (0,8 s per la tensione piena), sotto 0,22 s non scocca. Freccia con gravità
  (`weapons/arrow.gd`): 22-58 m/s e 20-70 di danno secondo la tensione, testa ×2,5. Resta piantata e si recupera
  passandoci accanto, anche sul cadavere. Rumore quasi nullo. Frecce sincronizzate in rete; sui client la freccia è
  solo visiva, il danno lo fa l'host. HUD: contatore sulla casella dell'arco.
- Dungeon: imbocco della Miniera di Lago Cenere al sito ovest (`zone1_kit._mine_gate`, kit `lowpoly_caves_and_props`
  esportato con `tools/env_kits/export_props.py` in `art/env/mine`): monte con collisione, assi inchiodate e tappo,
  cartello dello sceriffo, torce accese, campo dei minatori e un baule rifornimenti. Il sotterraneo arriva con il suo kit.
- Arredi WoodStuff (`art/env/wood`): casa del Vecchio (tavolo con bollitore, sedie, libreria, mobile, sedia a dondolo
  sul portico), fattoria e campo dei minatori. Collisione a scatola sulla mesh (`zone1_kit.prop`).
- Non usato: `rifle.zip` (mani a blocchi e una sola clip di sparo, stile diverso dal resto).
- Verifiche: `--verify-zombix` 47/47, `zone1_loop_checks` 18/18, `zx_shop_checks` 8/8, `melee_overhaul_checks` 15/15,
  `tests/fp_bow_capture.gd` (tiro reale) e `tests/env_kits_capture.gd`.
## Dungeon della Zona 1: Rocca maledetta + Cripta del Carceriere
- Un solo dungeon dai due pacchetti (`ZOMBIX_Rocca_Livello1`, `ZOMBIX_Cripta_Carceriere`). Script e modelli copiati
  (`world/rocca/`, `world/dungeon/dungeon.gd`, `art/zx_rocca/`, `art/zx_dungeon/`, `enemies/spit_projectile.gd`);
  i file che i pacchetti sostituivano (zombie_ai, zombie_target, infected_motion, zombie_motion.res, zombix.gd) sono
  stati uniti a mano perché nel frattempo erano cambiati. Originali in `_backup_rocca/`.
- Superficie, al sito "dungeon" della pista ovest: la torre della Rocca con le mura spezzate, edera, colonna caduta,
  sentiero di torce e il campo di **Bruno lo speleologo** (fuoco, mappa). [E] su Bruno: dialogo nel pannello dello
  sceriffo con tre scelte (percorso, pericoli, vado) (`survival_rules.open_npc_dialogue`). La miniera accanto resta
  sbarrata: è crollata nelle cripte.
- Percorso: torre -> corpo di guardia e sala grande (chiave d'oro in armeria) -> lucchetto -> chiocciola -> cantina,
  Fossa, prigioni, cripte, draghi, alchimista (carne maledetta) -> corridoio delle lame. La saracinesca sud dell'arena
  è bloccata da sotto: la botola porta nella Cripta (labirinto, segrete, cisterna degli sputatori, **sala dei
  secondini** in tre ondate al posto del secondo Carceriere). Ripulita, la saracinesca si alza; si risale, si appende
  la carne all'altare e scende **il Carceriere**.
- Nemici nuovi: sputatore (kind 4, sputo acido e pozza) e Carceriere (kind 5, 1400 HP, onda d'urto, salto, niente
  decapitazione, non barcolla ai colpi leggeri). Pattuglie zoppicanti. Clip unite con `tools/merge_zombie_motion.gd`
  (29 -> 34: Z_Spit, Z_Roar, Z_Patrol_Walk_Limp, Z_Boss_Drop_Arrival, Z_Boss_Death_Collapse).
- Test: `tests/dungeon_checks.gd` (15 controlli, foto `screenshots/dng-*.png`).

## Mani uguali e ascia più pesante
- Tutte le braccia in prima persona hanno la stessa giacca verde oliva, guanti senza dita scuri e pelle: PDA/dialogo
  con i colori del rig dell'ascia, l'arco con `player/viewmodel/fp_arms_dressed.gdshader` (manica, polsino e guanto
  sulle braccia nude del kit). Confronto: `tests/fp_hands_capture.gd` -> `screenshots/hands-*.png`.
- Rig dell'ascia: dita, palmo, polso e guanto smussati (bevel a 2 segmenti in `Builder.box(..., round=)`), ombreggiatura
  morbida sulla pelle, maniche a 9 lati.
- `fp_melee.gd`: molla smorzata sul rig. La lama in movimento trascina le braccia (inerzia del fendente) e quando entra
  nello zombie il braccio rimbalza indietro contro il verso del colpo (più forte col pesante), poi si assesta.
- Verifiche: `--verify-zombix` 47/47 (l'attesa della navigazione ora guarda il rifugio, non la Cripta), zone1_loop 18/18,
  zx_shop 8/8, melee_overhaul 15/15, fp_bow 5/5, dungeon 15/15.
## Negozi senza pannello e colpi degli zombie come prima
- Si compra dal pannello: guardi l'arma appesa (o lo zaino +1 slot sul bancone) e premi E. Il cartellino si illumina
  quando lo guardi e dice prezzo, "già tua" (verde) o quanti crediti mancano (rosso); il suggerimento a schermo dice
  "E COMPRA ...". Vale per l'Emporio di Big Earl e per tutti i negozi di zona (`world/campaign/zx_shops.gd`:
  `register_display`, `target`, `request`). Il vecchio pannello a schermo (pistola compatta, coltello, zaino) e il
  catalogo non si aprono più; Big Earl e gli altri negozianti rispondono con una battuta e indicano il pannello.
  Prezzi sui cartellini in CR in tutte le zone. Test: `tests/shop_wall_checks.gd` (11 controlli, foto `screenshots/shopwall-*.png`).
- Reazioni ai colpi: i fendenti laterali e la parata usano di nuovo le clip originali (Z_Hit_L, Z_Hit_R, Z_Hit_Front)
  con la spinta di lato o all'indietro; le clip Mixamo restano nel .res ma non si usano. Atterramento col pesante e
  spinta col calcio invariati.
## Braccia v3, tasche come How to Fish, lancio e vendita
- Braccia: `player/viewmodel/fp_arms.gd` è il controller del pacchetto `ZOMBIX_Braccia_FPS_v3` adattato al progetto (v3 contiene già la v2).
  Una sola coppia di mani per tutte le armi e gli oggetti; arco a parte (`fp_bow.gd`, stessi colori); PDA e dialogo sulle curve.
  `first_person_weapon.gd` e `survivor_visual.gd` del pacchetto NON sono stati copiati: erano basati su file vecchi (niente ZXPlayer, PDA, arco, combo).
  La terza persona resta quella di `zx_avatar_driver.gd`, che già mostra l'arma giusta. Parata: posa presa da `<Set>_Inspect`. Calcio: solo la gamba di `SM_FP_Melee.glb`.
- Inventario come How to Fish (dal suo `PlayerInventory`/`InventorySlot`): niente pannello zaino, solo la fila delle tasche che hai
  (4, se ne comprano fino a 8), col modello vero, contorno su quella scelta e nome. 1-8 scelgono la tasca, lo stesso tasto lascia a mani vuote,
  la rotella si ferma ai bordi. Diverso da How to Fish: gli oggetti uguali si impilano nella stessa tasca (×3), come chiesto nel prompt per le teste.
- [Q] tieni premuto per la forza (6-16 m/s), al rilascio parte la clip `<Set>_Throw` e l'oggetto nasce quando la mano si apre (`world/campaign/thrown_item.gd`).
  Danno come da tabella, un colpo per lancio, E raccoglie, oggetti via dopo 5 minuti, armi mai. X lo lascia appena.
- [V] vende una testa, con la testa in mano, vicino allo sceriffo (`HEAD_PRICE`): clip `Item_Testa_Give`, +25 che sale; V tenuto 1 s vende tutte. E parla e basta.
  Tasti nuovi: L torcia, F guarda l'arma, H mangia (prima Q), B veicolo (azione non usata dal codice). Bende, cibo e kit medico sul bancone di ogni negozio; tasto sinistro per usarli.
- Test: `tests/inventory_checks.gd` (32), `_test_join` prova anche inventario e lancio in rete. Video: `_preview/inventario_lancio_vendita.avi`. Backup: `_backup_inventario_20261106/`.
## Borgo Cenere (villaggio della Zona 1)
`world/villaggio/villaggio.gd` e `villaggio_layout.gd`, kit originale `art/zx_borgo` (sorgente Blender in `tools/borgo_kit`). Centro (95, 0, -385), bretella dalla statale al posto di blocco.
Boss della missione: il Macellaio, si sveglia gettando l'esca nel pozzo in piazza (solo quando lo sceriffo ti manda lì). Barricate e sputatori sui tetti, poi testa, cinghia e due casse. Se abbandoni lo scontro per 20 s l'esca torna.
Il vecchio villaggio è in `_da_eliminare/`. Il Mago resta in `bosses/il_mago` per una zona futura. Foto: `tests/borgo_photos.gd`.

## Animazioni e combattimento, novembre 2026

- 62 clip Mixamo per infetti e personaggio; riconversione con `tools/mixamo/bake_mixamo.gd`.
- Reazioni per zona, parata e sbalzo; veleno, sanguinamento, stordimento, rallentamento, paura, radiazioni in `player/status_effects.gd`.
- Online: `tests/online_feel.gd` (due istanze) e `tests/campaign_network.gd` (quattro). La parata viaggia in `input_packet` e torna nello snapshot.
- Video di controllo: `tests/animation_reel.gd`.
## Tavolo, armi, zombie, mappa
Tavolo con tutte le armi all'inizio: `world/campaign/weapon_table.gd`. Tutte le armi tranne l'arco hanno movimento per famiglia in `player/tool_motion.gd`; danno, gittata, pallini ed effetti in `weapons/zx_arsenal.gd` e `weapons/gun_fx.gd`. Gli infetti scavalcano e aggirano in `enemies/zombie_ai.gd` (`_steer`). Collisioni e oggetti sospesi: `world/campaign/solid_props.gd`, e `terrain.gd` posa sulla superficie vera. Controlli: `tests/zombie_path.gd`, `tests/map_audit.gd`, `tests/weapon_table_checks.gd`, `tests/weapon_table_shots.gd`.

## Personaggio visto da fuori
Clip Mixamo in `mixamo_raw` (le vecchie in `mixamo_raw/_vecchie_personaggio`), portate da `tools/mixamo/bake_mixamo.gd`: ogni arto punta dove punta nella clip e i piedi poggiano a terra. In `art/zx_player/zx_player.gd` le braccia hanno un livello proprio, il busto segue il passo e le gambe vanno alla velocità vera del corpo. In `art/zx_player/tool_rig.gd`: testa stabile che segue lo sguardo, benda e consegna scritte a mano. Controllo: `tests/body_shots.gd` con `--fixed-fps 30`.

## Ascia e pistola: l'arma si muove, le mani la seguono
Movimento in `player/tool_motion.gd`, IK in `player/arm_ik.gd`; prima persona in `player/viewmodel/fp_arms.gd`, vista da fuori in `art/zx_player/tool_rig.gd`. Chiavi scritte a mano guardando i video di riferimento, nessun file preso da altri giochi o pacchetti. Controllo: `tests/weapon_shots.gd` con `--fixed-fps 30`. Le altre armi usano ancora le vecchie clip.

- Audio: `tests/audio_mix.gd` controlla che ogni suono esista; con `--write-movie` e `tools/audio/measure_mix.py` misura il mix.
