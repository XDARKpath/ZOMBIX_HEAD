# Fase 3 — AI, falò e cooperativa

Scena principale: res://world/zona1_rifugio/fase3.tscn. Godot 4.5.1, GDScript.
Il progetto estende le funzioni di ambiente e HUD della Fase 2, conservando le vecchie scene.

## Struttura dei nodi

```text
Session (autoload: lobby, profili, ENet e avvio)
Rifugio (fase3.gd, processa anche mentre il mondo è in pausa)
├── Player (player.tscn: corpo, visuale, camera, ascia)
├── SpawnPoint
├── Interface (CanvasLayer)
│   ├── HUD ereditato
│   └── Menu (camp/menu.gd, creato a runtime)
├── NavigationRegion3D (creata a runtime)
│   └── Landscape (terreno, collisioni, case, lago e oggetti)
├── Camp (camp.gd, fuori dall'area di gioco)
│   ├── Camera3D e ambiente dedicato
│   ├── Fuoco, particelle, luci e audio
│   └── Quattro posti avatar, tre mostrati nell'anteprima offline
├── Peer… (personaggi remoti, presenti in cooperativa)
└── Enemy… (zombie_ai.gd)
    ├── Collisione e visuale ereditate da ZombieTarget
    └── NavigationAgent3D
```

I nomi dei nodi creati da codice possono essere automatici nell'albero Remote.
L'ambiente viene generato all'avvio: la scena nell'editor contiene soltanto il nucleo statico.

## Comportamento

Gli zombie alternano vagare, inseguire, attaccare e morte. Vista con cono e controllo
dei muri, udito attivato dai colpi, memoria breve dell'ultima posizione. L'attacco ha
un preavviso di mezzo secondo. La navigazione usa le collisioni del mondo, con la
quota dei punti corretta per l'origine del corpo. I nemici molto lontani pensano meno spesso.
Sei nemici all'inizio, massimo otto vivi; il generatore considera anche il limite di 24 corpi
e la distanza dai giocatori. I morti restano 30 secondi. Non c'è ancora evitamento dinamico
fra zombie, quindi gruppi molto vicini possono ammassarsi.

Le tre skin usano i modelli importati; le pose attorno al fuoco sono nuove animazioni
procedurali dello scheletro. In lobby il cambio viene condiviso con gli altri partecipanti.
La partita cooperativa usa un host autoritativo, aggiornamenti circa 20 volte al secondo,
input di movimento e azioni di combattimento. Non comprende server persistenti o matchmaking.

Le preferenze sono in user://preferences.cfg: volume, sensibilità, sangue, ombre,
schermo intero, risoluzione, nome e skin. Non è il salvataggio della campagna.

## Aprire e modificare nell'editor

1. Avvia MODIFICA_TESTE.cmd e attendi l'importazione.
2. Nel pannello FileSystem apri world/zona1_rifugio/fase3.tscn.
3. Premi F6 per la scena oppure F5 per il progetto.
4. A gioco avviato seleziona Remote nel pannello Scene per vedere falò, navmesh e nemici.
5. Modifica ui/camp/camp.gd per composizione e luci; camp_avatar.gd per le pose;
   menu.gd per pagine e impostazioni; enemies/zombie_ai.gd per i comportamenti.
6. In Project > Project Settings > Globals verifica Session fra gli autoload.
7. Per verificare il solo gameplay precedente apri fase2.tscn e premi F6.

## Checklist di prova

- Avviare singolo, camminare, correre, schivare, attaccare rapidamente e con carica.
- Attirare uno zombie, interrompere la vista con un edificio, farsi inseguire intorno al camion.
- Ricevere un attacco, morire e tornare al rifugio; osservare la sparizione di un cadavere.
- Aprire PERSONAGGIO e cambiare fra tutte le tre skin.
- Cambiare impostazioni, chiudere e riaprire normalmente per verificarne la persistenza.
- Creare una lobby, collegare gli amici, osservare le skin, rendersi pronti e avviare.
- Aprire Esc in cooperativa e verificare che gli altri continuino a giocare.
- Provare l'uscita di un client e poi dell'host.

Risultati automatici e ambito delle verifiche in VERIFICA_FASE_3.txt. Codice integrale
dei file principali in CODICE_FASE_3.md; elenco del progetto in FILE_FASE_3.txt.

## Risoluzione dei problemi e limiti

Schermata vuota o Vulkan non disponibile: prova il launcher compatibile; effetti grafici
possono differire. L'avvio e le catture visive sono stati verificati con Vulkan.
Se non vedi nodi generati, usa Remote durante l'esecuzione. Per problemi di rete leggi ONLINE.md.
Non sono ancora certificati 60 FPS su hardware medio-basso o sessioni di un'ora.
Pesca alimentare, fame, valuta, quest, inventario, armi da fuoco, boss e salvataggi del mondo
restano nelle fasi successive. Nessun plugin aggiunto per questa fase.
