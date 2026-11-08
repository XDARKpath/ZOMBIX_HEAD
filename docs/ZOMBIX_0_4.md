# ZOMBIX HEAD 0.4 — struttura e modifica

Scena principale: world/zona1_rifugio/zombix.tscn. Il controller zombix.gd estende fase3.gd,
che conserva rete ENet, replica del mondo e navigazione. La copia precedente TESTE è preservata.

## Nodi principali aggiunti a runtime

```text
Rifugio (zombix.gd)
├── Player / CameraRig / MeleeController
├── NavigationRegion3D / Landscape
├── Camp / Camera3D / quattro posti avatar
├── Presentation (atmosphere.gd): erba MultiMesh, luci, polvere, suono
├── Expedition (expedition.gd): tre casse, radio, missione condivisa
├── Interface / ZombixHUD (zombix_hud.gd)
├── Peer… / Label3D del compagno
└── Enemy… / NavigationAgent3D
Session (autoload)
```

## Flusso e autorità

Missione: raccolta → ritorno alla radio → difesa → trasmissione riuscita → nuova spedizione.
Tre casse a posizioni fisse, rifornimento e ripetizione. Non è una campagna generata casualmente.
L'host valida gli input di interazione con identità, distanza, stato di vita e raycast del mondo.
Pubblica stato della missione circa quattro volte al secondo; il mondo resta a circa 20 aggiornamenti.
I client visualizzano gli obiettivi condivisi. La pausa offline ferma la missione, quella online no.
L'allarme richiama i nemici e aggiunge rinforzi rispettando i limiti già esistenti.

## Aspetto e prestazioni

Erba generata in due MultiMesh, senza collider e ombre per ogni filo. Dettagli aggiuntivi
non alterano i percorsi già validati. Cielo procedurale con nuvole, foschia e luce variabile;
non è ancora un sistema completo di meteo o alternanza giorno/notte. Profondità di campo nel
solo menu. Antialiasing MSAA 2×. Camera dinamica con campo visivo maggiore in corsa e minore
in carica, rollio contenuto. Nessuna misurazione certificata di prestazioni su hardware minimo.
La modalità OpenGL riduce cielo ed effetti, ma conserva un avviso del renderer alla chiusura
per due texture; non viene dichiarata equivalente alla modalità Vulkan.

Il nuovo logo SVG, gli shader e i due suoni sintetizzati (forest.wav e footstep.wav) sono originali.
Modelli e limiti di conversione rimangono quelli documentati in ASSET_FASE_3.md.

## Nell'editor

1. Apri MODIFICA_ZOMBIX_HEAD.cmd e attendi l'importazione.
2. In FileSystem apri world/zona1_rifugio/zombix.tscn. Premi F6, oppure F5 per il progetto.
3. Durante il gioco passa a Remote per esplorare i nodi generati.
4. Modifica ui/camp/menu.gd e camp.gd per menu e scena del falò.
5. Modifica atmosphere.gd, sky.gdshader e grass.gdshader per l'ambiente.
6. Modifica expedition.gd per punti delle casse, raggio di interazione e tempo di difesa.
7. Modifica ui/zombix_hud.gd per radar, missione e feedback del combattimento.

Il codice è già nei file; CODICE_ZOMBIX.md raccoglie i file principali per consultazione.
Il nome della cartella del progetto è ZOMBIX_HEAD. Le preferenze della nuova app vengono
salvate nel suo user://; il vecchio progetto e le sue preferenze non sono sovrascritti.

## Checklist manuale

- Cambiare tre skin, volume, sensibilità, risoluzione e schermo intero; riavviare per la persistenza.
- Raggiungere ogni cassa a piedi, premere E e osservare progresso/rifornimento.
- Tornare alla radio; durante la difesa uscire dal raggio, rientrare e osservare il timer.
- Completare e riavviare una spedizione; verificare ricomparsa delle casse.
- Caricare un colpo, colpire, schivare, correre e osservare stamina, camera, numeri di danno.
- Ripetere in squadra; uscita di client e host; la chiusura dell'host termina la sessione.

I log automatici sono in VERIFICA_ZOMBIX.txt. Non sostituiscono una prova prolungata con amici
su PC e connessioni differenti. Per collegarsi leggere ONLINE.md.
