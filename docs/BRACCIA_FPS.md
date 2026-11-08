# Braccia FPS, impugnature e HUD in vetro

## Modello (Blender)
`tools/fp_arms/build_fp_arms.py` genera `art/fp_arms/SM_FP_Arms.glb` (sorgente `tools/fp_arms/FP_Arms.blend`):
mani low-poly a cinque dita con tre falangi, guanti senza dita, maniche della giacca. 37 ossa
(root, braccio, avambraccio, mano e 15 falangi per lato), 1.296 triangoli, flat shading.
Skinning rigido: ogni segmento segue un solo osso e si sovrappone al successivo, quindi niente
deformazioni o fessure ai giunti.

```
blender --background --factory-startup --python tools/fp_arms/build_fp_arms.py -- ZOMBIX_HEAD/art/fp_arms
```

## Impugnatura procedurale
`player/viewmodel/fp_hands.gd`
- IK a due ossa verso `Socket_RightHand` / `Socket_LeftHand` dell'arma; se il manico è fuori
  portata la spalla avanza fino a 9 cm invece di staccare la mano.
- Le dita non usano pose fisse: ogni falange viene appoggiata sul cilindro del manico (raggio dal
  socket), quindi seguono la geometria e non entrano nella mesh. Il pollice si chiude dal lato opposto.
- Socket: X lungo il manico, Y verso cui escono le dita, Z dorso; meta `radius` e `grip`.
  Funzionano a qualunque scala dell'arma. Profili: power, pistol, clamp, bezel, relaxed, flat, open, pinch.

| Arma | Presa |
|---|---|
| Ascia / pala | destra sotto la testa, sinistra alla base (socket misurati dalla mesh) |
| Pistola | destra con indice lungo il ponticello, entra nel grilletto solo quando spara; sinistra a C sopra la destra |
| Coltello | destra a pugno, sinistra rilassata |

## Stati (`player/first_person_weapon.gd`)
Mira 0,15 s (tasto destro, pistola) · cambio arma 0,15 s in uscita + 0,15 s in entrata ·
corsa con spinta a 45° verso il basso · inerzia a molla su sguardo e accelerazioni, più lenta
per le armi pesanti · peso dell'ascia: polso inclinato e stretta più forte · fendenti in tre
varianti, rinculo, ricarica con la sinistra sul caricatore, E allunga la sinistra, sussulto se colpito.

**PDA (G):** la sinistra porta in vista un GPS con schermo di vetro traslucido; il testo del GPS
è renderizzato sul dispositivo (`player/viewmodel/pda.gd`), il mondo resta attivo.
**Dialogo con sceriffo/mercante:** la camera si sporge in avanti, le mani si appoggiano al bancone
e la destra accompagna le frasi.

## HUD (ui/zombix_hud.gd)
Poche scritte. In alto a sinistra cuore + barra della vita arrotondata e fulmine + fiato, senza
etichette; in alto al centro una pillola con l'obiettivo (e i rombi dei custodi o la barra del boss);
in alto a destra mappa con la sola N e, sotto, icone di crediti, teste e allerta. In basso lo zaino
con slot arrotondati: il nome dell'arma compare solo per un attimo al cambio. Il nome della zona
appare 4 s all'arrivo; la serie di uccisioni solo da ×2. I comandi non sono più a schermo.
Vetro smerigliato al 60% con bordi ambrati e angoli regolabili (`radius` in ui/glass/frost.gdshader);
i pannelli seguono la camera con una molla, in corsa scendono al 30% e oscillano col passo.

## Dialoghi (ui/sheriff_dialogue.gd)
Fumetto in vetro con targhetta del nome, testo che si scrive lettera per lettera (E lo completa,
E di nuovo avanza), risposte come bolle numerate che compaiono a fine frase, puntini di pagina
e freccia animata. `set_speaker()` cambia il nome per altri NPC.

## Sceriffo
Seduto dietro la scrivania, spalle alla parete di fondo (Layout.SHERIFF_NPC); scrivania e credenza
arretrate in refuge_set.gd. Il bacino viene appoggiato sul cuscino dopo la posa (sheriff.gd, SEAT).
Acquisizioni: tests/sheriff_capture.gd → screenshots/sheriff-*.png.

## Verifiche
`tests/fp_hands_bench.gd` (prese su sfondo neutro, 3 viste), `tests/fp_hands_capture.gd` (stati in gioco,
immagini `screenshots/fp-*.png`), `--verify-zombix` senza errori.

## Limiti
Nessun inventario a schermo intero: il PDA mostra il GPS. Pollici di pistola e PDA regolati a vista.
Non c'è un FOV separato per il viewmodel: contro un muro molto vicino l'arma può entrarvi.
Le clip `Player_*` del corpo intero restano per gli altri giocatori e la galleria; F6/F7 non sono più sulle braccia.
