# Fase 2 — combattimento e revisione visiva

## Decisioni

Si conserva la struttura di gioco di TESTE. SurrounDead sostituisce Never Be Alone.
La richiesta più recente sostituisce i placeholder artistici con modelli recuperati dai giochi forniti.
La Fase 2 include bersagli zombie reattivi; la loro AI rimane nella Fase 3.

## Prova rapida

1. Apri AVVIA_TESTE.cmd e attendi l'importazione iniziale.
2. Seleziona ENTRA NEL RIFUGIO.
3. Avvicinati a un infetto e orienta la camera verso di lui.
4. Fai click sinistro: il colpo rapido consuma 12 stamina e infligge 26 danni.
5. Tieni premuto almeno 0,65 s e rilascia: il colpo caricato costa 28 e infligge 58.
6. Gli infetti hanno 72 vita: tre rapidi, oppure un rapido più un caricato, li abbattono.
7. Verifica la spinta, la barra dello zombie colpito e il contatore del cortile.
8. Premi E vicino al barile blu presso la tenda per ripetere.
9. Premi Esc; prova volume, sensibilità, sangue e ombre nelle impostazioni.

## Nell'editor, click per click

1. Apri MODIFICA_TESTE.cmd oppure Godot 4.5.1 > Importa > scegli TESTE/project.godot.
2. Nel pannello FileSystem espandi world/zona1_rifugio.
3. Apri fase2.tscn con doppio click. Premi F6 per questa scena o F5 per il progetto.
4. Il paesaggio e i personaggi vengono costruiti all'avvio: durante la prova scegli
   la scheda Remoto nell'albero Scene per ispezionarli.
5. Apri player/player.tscn: seleziona MeleeController/HitArea/CollisionShape3D
   per vedere il volume che raccoglie i bersagli.
6. Apri weapons/melee/axe.tres: modifica danni, tempi, costo e portata nell'Inspector.
7. La portata e il cono sono filtrati anche dallo script, con un raggio contro i muri.
8. Per fermare la prova premi F8. Salva le modifiche prima di riavviare.

## Nodi

```text
Rifugio (Node3D, processa anche in pausa; fase2.gd)
  Player (CharacterBody3D, player.tscn; processa solo durante il gioco)
    CollisionShape3D (capsula; layer giocatore, maschera mondo+nemici)
    Visual / RollPivot
      [vecchi arti di riferimento nascosti]
      SurvivorVisual (survivor_visual.gd)
        modello GLB / Skeleton3D / mesh skinnata
        ascia GLB
    MeleeController (melee_controller.gd)
      HitArea (Area3D, maschera nemici)
        CollisionShape3D (3.1 x 2.1 x 2.6)
    CameraRig / SpringArm3D / Camera3D
  SpawnPoint
  Interface (CanvasLayer)
    root / HUD, menu principale-pausa, pannello impostazioni-comandi
  Landscape [creato all'avvio; landscape.gd]
    WorldEnvironment, DirectionalLight3D
    terreno triangolato + collisione
    lago con shader; edifici/relitti/pontile con collisioni
    vegetazione; frammento mappa; accessori di pesca
  Zombie0, Zombie1, Zombie2 [CharacterBody3D; zombie_target.gd]
    CollisionShape3D, Visual / SurvivorVisual, barra salute
  Camera3D [menu]
  AudioStreamPlayer [effetti]
```

## Checklist

- [x] Importazione dei modelli scheletrici, texture e ambiente.
- [x] Cammino, sprint con stamina, schivata con invulnerabilità.
- [x] Danno rapido 26, caricato 58; costi 12/28; un impatto per bersaglio per attacco.
- [x] Attacchi alle spalle/fuori portata/attraverso muri rifiutati.
- [x] Spinta, morte, rimozione del layer del cadavere; tempo ripristinato dopo hit-stop.
- [x] Attacchi negati senza stamina e durante recupero.
- [x] Pausa, accesso impostazioni, ritorno dopo morte.
- [x] Ispezione visiva nel renderer Forward+ su RTX 3050 Laptop.
- [ ] Prova con un gamepad fisico.
- [ ] Sessione lunga da un'ora e obiettivo 60 FPS stabili (non certificati in questa fase).

Test automatici: dalla cartella estratta esegui runtime/Godot_v4.5.1-stable_win64.exe
con gli argomenti `--headless --fixed-fps 60 --path TESTE -- --verify` dopo il primo import.
Il rapporto è in docs/VERIFICA_FASE_2.txt. Gli screenshot sono catture del gioco.

## Problemi tipici

- Finestra nera al primo avvio: aspetta che Godot importi i modelli. Non avviare copie multiple.
- Errore Vulkan: usa AVVIA_TESTE_COMPATIBILE.cmd; alcuni effetti avanzati saranno ridotti.
- Zombie immobili: previsto per la Fase 2; danno e reazioni sono attivi, AI nella fase successiva.
- Colpo mancato: avvicinati entro 2,5 m, orienta la camera e controlla che non ci sia un muro.
- Nessuna pesca: gli oggetti sul pontile sono scenografia, il sistema alimentare è futuro.
- Impostazioni ripristinate dopo l'uscita: attualmente sono valide per la sessione.
- Vecchie scene rifugio.tscn e test Fase 1: conservate come riferimenti storici;
  la scena principale attuale è fase2.tscn e la suite attuale è phase2_checks.gd.
