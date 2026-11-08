> Storico Fase 0. La versione corrente è la Fase 1: vedi FASE_1.md e README.md.

# Fase 0 — Setup e ambiente di prova

## Risultato

Progetto Godot 4.5.1 Standard, Compatibility, scena principale assegnata, cinque autoload
predisposti, 30 azioni input, terreno con collisione e camera di osservazione.
Tutte le cartelle del brief sono create; le cartelle vuote sono prenotate per le fasi successive.
Non occorre copiare codice a mano: i file sono già pronti.

## File creati

| File | Responsabilità |
|---|---|
| project.godot | Motore, rendering, autoload, Input Map, livelli collisione |
| autoload/balance.gd | Costanti future di bilanciamento e parametri camera |
| autoload/game_state.gd | Interfaccia dello stato globale; nessuna partita implementata |
| autoload/economy_manager.gd | Segnali futuri di economia |
| autoload/save_manager.gd | Segnali futuri e percorso previsto dei salvataggi |
| autoload/audio_manager.gd | Segnale futuro per il contesto musicale |
| autoload/time_manager.gd | Segnali futuri giorno/notte; nessun tempo che scorre |
| world/test_scene.tscn | Ambiente 3D statico, modificabile nell'editor |
| world/test_scene.gd | Camera, UI di anteprima e verifica di setup |
| art/icon.svg | Icona originale del progetto |
| data/quest.json | Due traguardi tutorial, solo dati di design |
| data/prices.json | Prezzi del brief, solo dati di design |
| docs/*.md | Istruzioni, analisi, design, registro, sorgenti e verifica |

I dati JSON non sono caricati dal runtime in Fase 0. Le future risorse di armi e drop table
saranno create quando avranno una logica di gioco associata.

## Struttura dei nodi

La sola scena eseguibile è `world/test_scene.tscn`:

```
TestScene (Node3D, test_scene.gd)
├── Environment (WorldEnvironment)
├── Sun (DirectionalLight3D)
├── Terrain (Node3D)
│   ├── Ground (StaticBody3D)
│   │   ├── Mesh (MeshInstance3D)
│   │   └── Collision (CollisionShape3D)
│   ├── Soil / Road / Footpath (MeshInstance3D)
│   └── Lake (MeshInstance3D, scenografico)
├── House (Node3D)
│   ├── Floor / BackWall / SideWall / RightWall / FrontLeft / FrontRight
│   ├── DoorHeader / Porch (StaticBody3D, ciascuno con Mesh e Collision)
│   ├── RoofLeft / RoofRight / Chimney / WindowGlow / WindowCrossA / WindowCrossB
│   ├── SignBoard (MeshInstance3D)
│   ├── Sign (Label3D)
│   └── PorchLamp (OmniLight3D)
├── Dock (Node3D)
│   ├── Plank0–14 (StaticBody3D, ciascuno con Mesh e Collision)
│   └── Posts / Bench / BenchLegs / RodDisplay / TackleBox (mesh decorative)
├── BoatPlaceholder (Node3D + mesh, non guidabile)
├── Forest (Node3D + tronchi e chiome decorative)
├── Details (Node3D + pietre, acqua decorativa, casse)
├── ZombiePlaceholder (Node3D + mesh, non un nemico attivo)
├── SpawnPoint (Marker3D, riservato al player)
├── Camera3D
└── Interface (CanvasLayer)
    └── Control [creato dallo script]
        ├── Intestazione e indicatore fase
        ├── PanelContainer → VBoxContainer → testi / pulsanti viste / guida
        ├── Barra inferiore → testo comandi / monitor input
        ├── Pannello guida → testi / pulsante chiudi
        └── Pannello Esc → testi / riprendi / esci
```

La lista esatta di ogni nodo, inclusi i nomi degli elementi ripetuti, è in `NODI_FASE_0.txt`.
Nell'albero remoto sono inoltre presenti cinque nodi autoload figli di `/root`.
Non creare un autoload per balance.gd: viene caricato come risorsa di costanti.

## Passaggi click per click

1. Estrai tutto il pacchetto Windows in una cartella scrivibile.
2. Apri `MODIFICA_TESTE.cmd`: si avvia Godot con il progetto.
3. Alternativa con Godot già installato: Project Manager → **Import / Importa** → **Browse / Sfoglia**.
4. Seleziona `TESTE/project.godot`, poi **Import & Edit / Importa e modifica**.
5. Attendi la prima importazione. Il renderer in alto a destra deve essere **Compatibility**.
6. Nel pannello FileSystem apri `world`, poi fai doppio clic su `test_scene.tscn`.
7. Seleziona `Terrain/Ground/Collision`: nell'Inspector compare una BoxShape3D.
8. Vai in **Project → Project Settings → Globals → Autoload**: verifica i cinque servizi.
9. Vai alla scheda **Input Map**: cerca `move_forward`, `interact`, `attack` e `pause`.
10. Se vuoi rimappare una tastiera, espandi l'azione, usa **+**, premi il nuovo tasto e conferma.
    Questa è una rimappatura nell'editor; il menu di rimappatura dentro il gioco è futuro.
11. Premi **F5** (Run Project). F6 nell'editor esegue invece la scena aperta.
12. Una volta dentro la finestra dell'anteprima, F6/F7/F8 selezionano le tre viste.
13. Tieni il destro sul mondo e muovi il mouse; prova la rotella.
14. Premi E, Q, WASD: controlla il nome dell'azione nella barra inferiore.
15. Premi F1 e leggi i controlli; chiudi la guida. Premi Esc e prova Riprendi, poi Esci.
16. Per modificare la casa, arresta l'esecuzione con F8 **nell'editor**, seleziona `House`
    o una sua mesh e modifica Transform / Mesh nell'Inspector. Ctrl+S salva la scena.

## Checklist manuale

- [ ] L'anteprima parte senza errori rossi.
- [ ] Si vedono casa, alberi, zombie statico, acqua, pontile e barca.
- [ ] I tre pulsanti e F6/F7/F8 cambiano inquadratura.
- [ ] Orbita e zoom restano nei limiti senza capovolgere la camera.
- [ ] E mostra `interact`; WASD mostra le azioni di movimento.
- [ ] F1 apre e chiude la guida; durante la guida il mouse non ruota il mondo.
- [ ] Esc apre il menu; Riprendi ed Esci funzionano.
- [ ] Con un gamepad collegato, stick destro e pulsanti vengono riconosciuti.
- [ ] Ridimensionando la finestra, testi e comandi rimangono leggibili.

Le caselle sono intenzionalmente da spuntare durante la tua prova. Per i controlli già
eseguiti automaticamente e la verifica grafica, vedi VERIFICA.md.

## Problemi tipici

| Problema | Soluzione |
|---|---|
| WASD non muove nessuno | Previsto: il personaggio viene implementato in Fase 1; ora si verifica solo l'input |
| Il mouse non orbita | Trascina con il destro sul mondo, fuori dai pannelli; chiudi guida e menu |
| F8 chiude la partita | L'editor ha il focus: clicca prima nella finestra dell'anteprima |
| Errore aprendo in Godot 3 | Usa Godot 4.5.1 Standard incluso o la versione ufficiale indicata |
| Non trova il motore | Estrai anche la cartella runtime e mantienila accanto a TESTE e ai due launcher |
| Lo ZIP non parte | Estrai l'intero archivio prima di avviare il file .cmd |
| Schermo nero / driver | Verifica Compatibility e il supporto OpenGL 3.3 del driver; usa driver del produttore |
| Impossibile creare log | Sposta il pacchetto in una cartella scrivibile e verifica che il profilo Windows consenta dati applicazione |
| Gamepad non riconosciuto | Collega prima il controller, riapri l'anteprima e controlla i binding in Input Map |
| La casa sembra già costruita | È il modello statico di prova; lo stato diroccato/riparato arriva con la quest in Fase 5 |
| Gli alberi non bloccano il passaggio | Sono decorativi in Fase 0; collisioni e navigazione saranno definite con player e AI |

## Sostituire i placeholder

Fonti consultate: [Kenney](https://kenney.nl/assets), [Quaternius](https://quaternius.com/),
[Freesound](https://freesound.org/help/faq/), [game-icons.net](https://game-icons.net/).
Kenney e Quaternius offrono raccolte utilizzabili per la grafica di prova; controlla la
licenza del pacchetto specifico. Su Freesound filtra CC0 se vuoi evitare attribuzioni;
le altre licenze vanno rispettate. Per le icone conserva autore e licenza del download.
Questa consegna non usa asset di questi cataloghi né dei due giochi originali.

Per i modelli: preferisci GLB/glTF, copia in `art/`, attendi l'importazione, trascina
il modello sotto il nodo da sostituire e regola scala e orientamento. Mantieni il nodo
StaticBody3D/Collision del sistema, se presente, sostituendo soltanto la mesh visiva.
Per audio futuro: copia WAV/OGG in `audio/` e assegnalo a un AudioStreamPlayer quando
AudioManager sarà implementato. Non serve un plugin per questi formati.

[Documentazione InputMap di Godot](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html).
[Versione ufficiale Godot 4.5.1](https://godotengine.org/download/archive/4.5.1-stable/).
