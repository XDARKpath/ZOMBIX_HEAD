# Survivor Operative — integrazione

Braccia FPS: sostituite da art/fp_arms con IK e impugnatura procedurale (vedi BRACCIA_FPS.md); il corpo qui descritto resta per gli altri giocatori. Il corpo proietta l’ombra e riproduce le clip originali. Ascia 62 cm, pala 100 cm; geometria FBX normalizzata una volta.

## Gameplay
Idle, camminata avanti/indietro, spostamento laterale, corsa, accovacciamento, mira (mouse destro con pistola), sparo, ricarica, estrazione/riposta, fendente, impatto frontale e morte frontale sono collegati agli stati del giocatore. Le due clip di interazione sono richiamabili con E, secondo la postura.

## Tutte le 23 clip
ANTEPRIMA_ANIMAZIONI.cmd apre il personaggio intero: frecce per cambiare, spazio per ripetere, Esc per uscire.
Calcio, lancio granata, impatto posteriore e morte all’indietro sono disponibili nella galleria e nel controller tramite action(nome_clip). Non aggiungono automaticamente nuove meccaniche di danno, granate o rilevamento della direzione del colpo.

Le animazioni originali sono state create per un fucile: ascia/pala usano il fendente disponibile e un adattamento IK della mano sinistra. I materiali degli attrezzi sono provvisori perché manca PolyPack_Main1.png.

Verifica: 23 clip campionate in 5 posizioni; trasformazioni finite, controllo dimensioni attrezzi, acquisizioni FPS delle quattro armi e fendente.
