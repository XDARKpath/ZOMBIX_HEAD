# Zona 1 — primo traguardo dell'idea "TESTE"

Riferimento visivo: ZOMBIX_Concept_Panels.zip (piazzale in terra battuta, alberi secchi, casse, relitti).
Gli script Blender del pacchetto dipendono da moduli non inclusi (buildings, shop, weapons, interactive):
le tavole sono servite come riferimento, non come asset.

## Mappa
- **Erba GPU** (world/grass/): porting Godot 4 di AndreVallestero/godot-grass-shader (MIT, vedi
  art/grass/ATTRIBUTION.md). ~29.000 ciuffi attorno al giocatore, altezza identica alla mesh del
  terreno, maschera che lascia spogli strade, edifici, acqua, arene e chiazze di terra.
  La stessa maschera dipinge la terra battuta sul terreno (ground.gdshader).
- **Terreno unico**: `Terrain.ground_height()` è usata anche da alberi e oggetti di landscape.gd
  (prima seguivano un'altra funzione). Strade del bosco e arene ora sono in piano: prima le strade
  secondarie salivano sulle colline e sparivano sotto il terreno.
- **Strade**: asfalto rovinato (road.gdshader: crepe, rattoppi, buche, polvere ai bordi), mezzeria
  sbiadita a tratti. Ogni ~26 m: auto abbandonate o bruciate sul ciglio (una corsia resta libera
  per il 4×4), detriti, sangue, barriere storte, alberi secchi. Guardrail tolto dove tagliava la curva.
- **Fine strada**: strade, relitti e località lontane sono divisi per settore di 128 m e appaiono solo
  quando il settore è caricato; prima i tratti delle Zone 2–8 galleggiavano nel vuoto.
- **Nebbia**: densità 0,008–0,012 con banchi che vanno e vengono, foschia bassa (fog_height) e nebbia
  volumetrica in Forward+; saturazione abbassata a 0,82.

## Gameplay (world/campaign/zone1_life.gd)
| Sistema | Come funziona |
|---|---|
| Rumore | Passi 5,5 m, corsa 13 m, accovacciati 0; coltello 5 m, ascia/pala 11 m, colpo a segno 12–16 m, pistola 45 m. Indicatore sotto la vita. |
| Sacco della morte | Morendo metà delle teste (arrotondata per eccesso) resta in un sacco luminoso, segnato in mappa. Gli infetti vicini ci vanno e lo divorano in 8 s. E per riprenderlo. |
| Cibo | 18 scatolette/funghi nella zona. Q mangia (pesce, poi scatoletta, poi funghi): cura e "sazio" per 90 s = vita che rigenera, più fiato, passi più silenziosi. Niente morte per fame. |
| Pesca | In fondo al pontile: E lancia, quando compare "E TIRA!" hai 0,9 s. |

Verifica: `tests/zone1_loop_checks.gd` (14 controlli), `--verify-zombix` (42 PASS).
Foto: `tests/zone1_capture.gd` → screenshots/zone1-*.png.

## Ancora da fare (dall'idea)
Il Vecchio e la sua casa, Calore/orde, mercato e contratti, notte con teste che valgono di più,
cucina, teste speciali, rifugio migliorabile, casinò, meteo con pioggia. Sacco, cibo e pesca sono
locali (giocatore singolo/host): la cooperativa non è ancora collegata.
