# Inventario licenze di `art/`

Controllo del 7 novembre 2026. Non è consulenza legale: serve a sapere cosa finisce nella build.
Sostituisce la tabella di `docs/LICENZE.md`, che diceva che il cast Synty Generic aveva i diritti d'uso: **l'utente non ha licenze Synty/POLYGON**.

Legenda: ✅ a posto · 🗑️ tolto dal gioco, in `_da_eliminare/`. Non restano voci da verificare.

Come è stato controllato:
- riferimenti `art/<cartella>` in tutti i `.gd`, `.tscn`, `.tres`, `project.godot`;
- scansione byte per byte dei binari di `art/` cercando marchi di terzi (`Synty`, `Polygon…`, `SK_Chr_`, `SM_Gen_`, `SharpGLTF`, `mixamo`...);
- campo `generator` dei `.glb`;
- file di licenza nelle cartelle.

La scansione trova solo i marchi rimasti nei file: **non prova** che un modello senza marchi sia originale. Per le voci "fatto per il gioco" ci si basa su script di generazione e documenti del progetto.

## Tolti dal gioco

| Cosa | Perché | Al suo posto |
|---|---|---|
| `art/surroundead/`, `refuge/`, `gang_warfare/`, `archery/`, `how_to_fish/` | estratti o pacchetti senza licenza; già assenti dal 1° nov 2026, restavano riferimenti nel codice | pezzi `art/zx_*`, `art/nature` |
| `art/zx_fp/SM_FP_Knife.glb` | coltello Synty estratto da SurrounDead, sotto un nome da file originale | `art/zx_fp/SM_FP_CombatKnife.glb` (`tools/build_fp_knife.py`) |
| `art/synty_generic/`, `art/synty_cast.gd` | cast POLYGON Generic | corpi `zx_player` e `survivor_operative` già in uso |
| `art/zx_dungeon/dungeon_modules.glb`, `art/zx_rocca/rocca_modules.glb` (vecchi) | kit `LowPolyDungeon` senza licenza | stessi nomi, generati da `tools/castle_kit/build_castle_kit.py` |
| `art/env/wood/` (vecchi) | `woodstuff.zip`, autore non confermato | stessi nomi, stesso generatore |
| `art/env/mine/` (vecchi) | `lowpoly_caves_and_props`, nessuna licenza | resta solo la torcia, generata da zero |
| `art/gas_station/` | Atomic Realm Assets, provenienza non confermata | `art/zx_borgo/SM_Prop_RoadBarrier_Small.glb` |
| `SM_Wep_RunicAxe`, `SM_Wep_SpartanSword` (vecchi) | archivi senza licenza | stessi nomi, generati da zero |
| `SM_FP_Bow`, `SM_Wep_Bow`, `SM_Wep_Arrows` (vecchi) | `low-poly-bow-fps-animation`, nessuna licenza | `tools/castle_kit/build_fp_bow.py`, clip calcolate nello script |
| `SM_FP_Melee.glb` (vecchio) | traiettorie ricalcate da `fps-tomahawk-animation` | solo gamba e clip `Kick`, generate da zero |
| `art/weapons/imported/AxeV1.fbx`, `SpadeV1.fbx` | nessuna fonte scritta | `SM_FP_Axe.glb`, `SM_FP_Shovel.glb` |
| 4 clip di `zombie_motion.res` | da Mixamo | `tools/strip_mixamo_clips.gd`; il Tank ora alterna schianto e manata |

I file `.gltf`/`.glb` nuovi riprendono del vecchio pezzo **solo nome e ingombro** (`tools/castle_kit/misure.json`), così il codice del gioco non cambia. La geometria è scritta da zero. SurrounDead è stato usato solo come spunto generale di clima e colori: nessun suo file aperto o copiato.

## Tutte le cartelle di `art/`

| Cartella | Cosa è | Da dove viene | Licenza | Stato | Usata da |
|---|---|---|---|---|---|
| `animation_reference/` | curve della prima persona e guida | pacchetto 0.14 fatto per il gioco | originale | ✅ | `player/first_person_weapon.gd`, `weapons/zx_arsenal.gd` |
| `buildings/` | ufficio dello sceriffo, armeria | `tools/build_refuge_buildings.py` | originale | ✅ | `world/zona1_rifugio/refuge_set.gd` |
| `camp/` | fumo `smoke_05.png` | Kenney Particle Pack, dai demo di Godot | CC0 | ✅ | `ui/camp/camp_props.gd` |
| `camp_blender/` | fuoristrada e tronco del campo | `tools/build_camp_rover.py`, `build_camp_log.py` | originale | ✅ | `ui/camp/camp.gd` |
| `env/building`, `interactive`, `shop`, `weapons` | kit ambiente e armi | `ZOMBIX_Env_Batch1`, `ZOMBIX_Batch2`, `tools/castle_kit` | originale | ✅ | `world/`, `art/zx_player/zx_weapons.gd`, `weapons/arrow.gd` |
| `env/mine/` | torcia del sentiero | `tools/castle_kit` | originale | ✅ | `world/rocca/rocca.gd` |
| `env/wood/` | arredi delle case | `tools/castle_kit` | originale | ✅ | `world/zona1_rifugio/zone1_kit.gd` |
| `fonts/` | Barlow Condensed | Google Fonts | SIL OFL 1.1 (`OFL.txt`) | ✅ | `ui/camp/`, `world/villaggio/villaggio.gd` |
| `fp_arms/` | braccia in prima persona | `tools/fp_arms/build_fp_arms.py` | originale | ✅ | `player/viewmodel/fp_hands.gd`, `player/first_person_weapon.gd` |
| `grass/` | texture e shader dell'erba | AndreVallestero/godot-grass-shader | MIT (`LICENSE.txt`) | ✅ | `world/grass/grass_field.gd`, `atmosphere.gd` |
| `kaykit_city/` | panchine, lampioni, auto | KayKit | CC0 (`LICENSE.txt`) | ✅ | `world/campaign/terrain.gd`, `landscape.gd`, `refuge_set.gd` |
| `kaykit_dungeon/` | moduli dungeon | KayKit | CC0 (`LICENSE.txt`) | ✅ | nessuno script |
| `kaykit_forest/` | cespugli, sassi | KayKit | CC0 (`LICENSE.txt`) | ✅ licenza; stile da non usare per gli alberi | `atmosphere.gd`, `art/placeholders.gd` |
| `kaykit_skeletons/` | custodi delle arene | KayKit | CC0 (`LICENSE.txt`) | ✅ | `bosses/` |
| `lake/` | pontile e barca a remi | `tools/lake/build_lake_props.py` | originale | ✅ | `world/zona1_rifugio/lake.gd` |
| `menu_batch2/` | personaggio e armi del menu | `ZOMBIX_Batch2` | originale | ✅ | `art/survivor_visual.gd`, `ui/camp/menu_assets.gd` |
| `menu_kenney/` | tenda, fuoco, tronco, cassa del menu | Kenney Nature Kit e Pirate Kit | CC0 (`LICENSE.txt`) | ✅ | `ui/camp/menu_assets.gd` |
| `nature/` | Stylized Nature MegaKit | Quaternius | CC0 (`LICENSE.txt`) | ✅ | `world/`, `art/placeholders.gd`, `bosses/boss_hunt.gd` |
| `survivor_operative/` | sopravvissuto base | `tools/Survivor_Operative`, con `.blend` e script | originale | ✅ | `art/survivor_visual.gd` |
| `water/` | shader dell'acqua | Chrisknyfe/boujie_water_shader | MIT (`LICENSE.md`) | ✅ | `world/zona1_rifugio/lake.gd` |
| `weapons/imported/sniper_rifle.glb` | fucile | Pichuliru, CC0 Flat Guns West | CC0 | ✅ | `art/weapons/weapon_visual.gd`, `ui/camp/camp_props.gd` |
| `weapons/imported/katana.tscn` | katana | DollarAlchemy/KatanaModel: il repo la dichiara lavoro proprio | CC0 ([ricontrollato](https://github.com/DollarAlchemy/KatanaModel/blob/main/LICENSE)) | ✅ | `art/weapons/weapon_visual.gd`, `ui/camp/camp_props.gd` |
| `weapons/imported/kaykit_axe/` | ascia a due mani | KayKit Adventurers | CC0 (`LICENSE.txt`) | ✅ | nessuno script |
| `weapons/` (script, `pistol.tscn`) | pistola procedurale e attacchi | codice del progetto | originale | ✅ | `art/survivor_visual.gd`, `ui/camp/` |
| `zombie_motion/` | clip degli infetti | pacchetto del gioco più clip Mixamo (vedi in fondo) | originale + Mixamo | ✅ | `art/infected_motion.gd`, `bosses/boss.gd` |
| `zx_borgo/` | kit di Borgo Cenere, transenna piccola | `tools/borgo_kit/borgo_kit.py`, `tools/castle_kit` | originale | ✅ | `world/villaggio/villaggio.gd`, `terrain.gd`, `roadblocks.gd` |
| `zx_dungeon/` | moduli della Cripta | `tools/castle_kit` | originale | ✅ | `world/dungeon/dungeon.gd` |
| `zx_fp/` | braccia, ascia, pala, coltello, arco, gamba, oggetti | pacchetti `ZOMBIX_Braccia_FPS`, `tools/build_fp_knife.py`, `tools/castle_kit` | originale | ✅ | `player/viewmodel/`, `player/item_info.gd` |
| `zx_infected/` | infetti, boss, NPC | `tools/zx_characters/build_characters.py` | originale | ✅ | `art/survivor_visual.gd`, `enemies/zombie_target.gd`, `bosses/` |
| `zx_logo/` | logo | fatto per il gioco | originale | ✅ | `ui/camp/menu.gd` |
| `zx_npc/` | armaiolo, gestore, negoziante | pacchetto 0.14 | originale | ✅ | `world/campaign/zx_shops.gd`, `survival_rules.gd` |
| `zx_player/` | SM_ZX_Player, skin e clip | `ZOMBIX_Batch2`, pacchetto 0.14 | originale | ✅ | `art/survivor_visual.gd`, `ui/camp/` |
| `zx_rocca/` | moduli, prop e trappole della Rocca | `tools/castle_kit`, pacchetto `ZOMBIX_Rocca_Livello1` | originale | ✅ | `world/rocca/` |
| `zx_vehicle/` | Ranger 4×4 | fatto per il gioco | originale | ✅ | `ui/camp/camp_vehicle.gd`, `vehicle/ranger_visual.gd` |

## File esterni fuori da `art/`

| Percorso | Da dove viene | Licenza | Stato |
|---|---|---|---|
| `audio/*.wav` | sintetizzati da `tools/make_audio.py` | originale | ✅ |
| `audio/music/`, `audio/sfx/` | sintetizzati da `tools/audio/build_audio.py` | originale | ✅ |

## Note

- `_backup_*` e `_da_eliminare/` hanno `.gdignore` e non entrano nella build. Contengono ancora il materiale vecchio: non vanno pubblicati.
- `_da_eliminare/` ha le vecchie versioni di arco, gamba, ascia runica, spada e arredi **rigenerate dalle fonti**, non i file originali identici: gli originali sono stati sovrascritti per errore durante la sostituzione.
- Fuori dal progetto restano i sorgenti di terzi: `Desktop\asssets`, `Downloads`, `project gioco\tools\incoming`.


## Animazioni Mixamo (7 novembre 2026)

Le clip di infetti e personaggio in `art/zombie_motion/zombie_motion.res` e `art/zx_player/mixamo_player.res` vengono da Mixamo (Adobe), scaricate con l'account del proprietario del progetto e portate sugli scheletri del gioco da `tools/mixamo/bake_mixamo.gd`. Le clip stanno dentro il gioco; i file FBX originali restano fuori dal progetto (`mixamo_raw/`) e non vanno ridistribuiti da soli. Prima della pubblicazione rileggere le condizioni Adobe in vigore.
## Audio

Origine e licenza di ogni suono e brano: vedi `docs/AUDIO_LICENZE.md` (tutto CC0).
