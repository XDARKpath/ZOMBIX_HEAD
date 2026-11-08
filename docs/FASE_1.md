# Fase 1 — Giocatore in terza persona

## File creati o modificati

| File | Funzione |
|---|---|
| player/player.tscn | CharacterBody3D, collisione, modello provvisorio articolato, camera e portaarma |
| player/player.gd | Movimento, sprint, stamina, schivata, vita, danno e segnali |
| player/camera_rig/camera_rig.gd | Orbita mouse/gamepad, direzione di movimento e follow |
| world/zona1_rifugio/rifugio.tscn | Mondo percorribile con rampe, collisioni, player e zona danni |
| world/zona1_rifugio/rifugio.gd | HUD, pausa, prova danno e rientro al rifugio |
| autoload/balance.gd | Tutti i parametri numerici di gameplay e camera |
| autoload/game_state.gd | Versione e fase aggiornate |
| project.godot | Nuova scena iniziale, nome TESTE e azione test_damage |
| tests/phase1_checks.gd | Prove di integrazione nel motore |
| docs/*.md | Analisi, direzione, registro, guida e sorgenti aggiornati |

## Struttura delle scene

```
Player (CharacterBody3D, player.gd, process_mode Pausable)
├── CollisionShape3D (capsula, layer Giocatore; mask Mondo)
├── Visual (Node3D, rotazione verso il movimento)
│   └── RollPivot (Node3D, rotolamento visivo)
│       ├── Torso / Vest / Pack / PackStrap / Head / Hat / HatBrim / Eyes (mesh)
│       ├── LeftLeg / RightLeg (Node3D → Leg e Boot)
│       └── LeftArm / RightArm (Node3D → Sleeve e Hand)
├── WeaponHolder (Node3D sotto Visual, riservato alla Fase 2)
└── CameraRig (Node3D top_level, camera_rig.gd)
    └── SpringArm3D (SphereShape3D, mask Mondo)
        └── Camera3D

Rifugio (Node3D, rifugio.gd, process_mode Always)
├── Environment / Sun
├── Terrain / House / Dock / BoatPlaceholder / Forest / Details
├── ZombiePlaceholder (modello statico)
├── HouseRamp / DockRamp (StaticBody3D)
├── NorthBoundary / WestBoundary / EastBoundary (StaticBody3D)
├── TreeCollision0…14 (StaticBody3D)
├── DamageZone (Area3D → CollisionShape3D)
├── DamageMarker / DamageSign / DockSign / ZombieSign
├── SpawnPoint (Marker3D)
├── Player (istanza player.tscn)
├── Camera3D (vecchia camera panoramica, current=false)
└── Interface (CanvasLayer)
    └── Control [creato a runtime]
        ├── Titolo / obiettivo / notifica / reticolo / comandi
        ├── HUD → vita, stamina, stato
        └── Pausa → guida / Riprendi / Riparti al rifugio / Esci
```

La capsula rimane intera durante il rotolamento: non permette di attraversare muri o passaggi
bassi. L'invulnerabilità riguarda il danno, non disattiva la collisione con l'ambiente.
Il mondo gestisce menu e input anche in pausa, ma salta la simulazione; player e camera sono
Pausable. Il timer del respawn si ferma mentre il gioco è in pausa.

## Valori iniziali modificabili

Cammino 4 m/s; corsa 7 m/s; vita e stamina 100. Corsa: 22 stamina/s; recupero 27/s
dopo 0,7 s senza consumo. A esaurimento, corsa riabilitata a 20 stamina.
Rotolamento: costo 25, velocità 9 m/s, durata 0,55 s; invulnerabilità iniziale 0,28 s;
cooldown successivo 0,3 s. Danno di prova 20; rientro dopo 1,2 s.
Tutti i valori sono in balance.gd. Sono valori di partenza, non un bilanciamento definitivo.

## Apertura nell'editor, click per click

1. Estrai il pacchetto e apri `MODIFICA_TESTE.cmd`.
2. Attendi l'importazione. Nel pannello FileSystem espandi `world/zona1_rifugio`.
3. Apri `rifugio.tscn` e seleziona `Player` nell'albero.
4. Apri la scena dell'istanza tramite l'icona accanto a Player, oppure apri `player/player.tscn`.
5. Seleziona `CollisionShape3D`: nell'Inspector osserva la capsula, alta 1,8 m.
6. Seleziona `CameraRig/SpringArm3D`: controlla collision_mask=Mondo e spring_length=5,2.
   I valori runtime sono assegnati dalla configurazione in balance.gd.
7. Apri `autoload/balance.gd` per modificare velocità, stamina, schivata e sensibilità.
8. Project → Project Settings → Input Map: controlla move_forward, sprint, dodge e test_damage.
9. Per rimappare, espandi un'azione, premi + e registra il nuovo tasto.
10. Premi F5 per avviare l'intero progetto. Il mouse viene catturato dalla finestra.
11. Prova WASD, Shift, Spazio e la camera con il mouse. Esc libera il mouse e mette in pausa.
12. Entra nella casa passando dalla rampa e raggiungi il pontile.
13. Cammina nel riquadro rosso o premi F2: controlla la vita e il ritorno al rifugio a zero.
14. Tieni la camera vicino a un muro: deve avvicinarsi al personaggio senza oltrepassarlo.
15. Nell'editor premi F8 per arrestare l'esecuzione, poi Ctrl+S per salvare le tue modifiche.

## Checklist della tua prova

- [ ] Il personaggio cammina rispetto alla direzione della camera, anche in diagonale.
- [ ] Shift fa correre e riduce stamina; fermarsi la ripristina.
- [ ] Spazio e Ctrl avviano il rotolamento se la stamina è sufficiente.
- [ ] F2 immediatamente dopo l'inizio della schivata non toglie vita.
- [ ] F2 nella seconda parte del rotolamento infligge danno.
- [ ] Casa e tronchi bloccano il movimento; rampa e pontile sono percorribili.
- [ ] Camera e zoom rispettano gli ostacoli.
- [ ] A zero vita torni allo SpawnPoint con valori ripristinati.
- [ ] Esc ferma il movimento; Riprendi riprende e cattura nuovamente il mouse.
- [ ] Gamepad: stick, L3, B, Start e navigazione menu funzionano con il tuo dispositivo.

## Problemi tipici

| Problema | Spiegazione / soluzione |
|---|---|
| Il mouse scompare | È catturato per controllare la camera. Premi Esc |
| Alt-Tab mette in pausa | È intenzionale per evitare movimento mentre usi altre finestre |
| La corsa smette anche tenendo Shift | Stamina esaurita: recupera almeno 20 punti |
| Non parte un altro rotolamento | Serve stamina, appoggio al terreno e cooldown terminato |
| F2 non danneggia durante la schivata | Sono gli i-frame iniziali; riprova nella seconda metà |
| Il personaggio non salta | Il brief usa Spazio per rotolare. Casa e pontile hanno rampe |
| Cadendo nell'acqua ritorno al rifugio | Nuoto e acqua non sono implementati; funziona il recupero fuori area |
| Lo zombie non attacca | In questa fase è statico. La sua AI è prevista in Fase 3 |
| Click non colpisce | Il combattimento melee viene implementato in Fase 2 |
| La canna non si usa | La pesca alimentare è pianificata con la fame, in Fase 7 |
| La camera stringe nei locali | SpringArm riduce la distanza per rispettare i muri |
| Aprendo F6 vedo solo il player | F6 esegue la scena corrente. Premi F5 per il mondo completo |

Gli script completi sono nei file del progetto e in CODICE_FASE_1.md. Non occorre incollarli.
Le indicazioni per sostituire i placeholder sono nella guida della Fase 0; nessun asset dei
giochi commerciali è stato importato in questa fase.
