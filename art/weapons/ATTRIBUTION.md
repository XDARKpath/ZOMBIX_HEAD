# Armi — provenienza e riuso

## Fucile

Autore: Pichuliru, **CC0 Flat Guns West**.
Fonte dell'autore e licenza CC0: https://opengameart.org/content/cc0-flat-guns-west
Mirror GitHub: https://github.com/petroulacl/fps-asset-kit
Commit: a19b7458a593598211c95ec46ef4eb4b6d1f94d7
File: weapons/flat_guns_west/Flat Guns West/GLB/Sniper_Rifle_West.glb
Git blob SHA-1: 0577f0d5ee82f35d5d5c8038e4f4d2138c6e0984
Locale: imported/sniper_rifle.glb.

Adattamenti: scala in metri, asse della canna +X, materiali, ottica aggiunta,
riferimenti per bocca, prese, ottica, caricatore, espulsione e superficie di pulizia.
Conservato lo scheletro originale del fucile.

## Katana

Fonte: https://github.com/DollarAlchemy/KatanaModel
Commit: a0d7bda50c51399065104e463765f0b3e0276801
File: Katana2.fbx
Git blob SHA-1: 02dbec520131d82a701212b2b071d3b2a50c10d1
Licenza CC0: https://github.com/DollarAlchemy/KatanaModel/blob/main/LICENSE
Copia della licenza: imported/CC0-LICENSE.txt.
Locale: imported/katana.tscn, conversione nativa del FBX con geometria incorporata.

Adattamenti: dimensioni e orientamento, lama più stretta con punta rastremata,
materiali separati, fasciatura incrociata, pomolo e riferimenti di impugnatura/lama.

## Ascia a due mani

Autore: Kay Lousberg, **KayKit Adventurers Character Pack 1.0**, CC0 1.0.
Repo GitHub: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
Commit: 672074b73ba276876a19e8816ecdc5241817ab47
File: `addons/kaykit_character_pack_adventures/Assets/gltf/axe_2handed.gltf`
(+ `.bin` e `barbarian_texture.png`); licenza in `imported/kaykit_axe/LICENSE.txt`.
Locale: `imported/kaykit_axe/`.

Adattamenti: caricamento diretto del glTF in prima persona, scala e rotazione
dell'ascia, presa a due mani e tre fendenti. Geometria e texture non sono
state modificate.

## Scene riutilizzabili

sniper.tscn e katana.tscn si istanziano indipendentemente dal menu. Unità: metri;
direzione canna/lama: +X. I Marker3D sono figli della radice. Il fucile espone anche
weapon_skeleton. Queste scene forniscono la parte visiva e i punti di aggancio;
spari, munizioni, ricarica, danni e sincronizzazione delle nuove armi non sono ancora
collegati al gameplay. Nessun codice dei repository esterni è stato eseguito.

La pistola nella mano libera del fumatore è procedurale (`pistol_placeholder.gd`).
Elenco completo delle licenze: `docs/ART_LICENZE.md`.
