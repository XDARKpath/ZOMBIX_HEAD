# ZOMBIX HEAD 0.5 — Atmospheric Camp Menu

Implementato nel progetto nativo Godot 4.5.1, GDScript. Il nome corrente rimane
ZOMBIX HEAD. Il redesign sostituisce il vecchio menu; non è una pagina web o un mockup.
Menu e messaggi di lobby sono in inglese; il gameplay conserva i testi italiani.

## Gerarchia effettiva dei nodi

La scena principale è world/zona1_rifugio/zombix.tscn. I nodi del menu vengono creati
a runtime: per vederli nell'editor occorre avviare il progetto e selezionare Remote.

```text
Rifugio (Node3D, zombix.gd → fase3.gd)
├── CampfireStage (Node3D, camp.gd, process_mode ALWAYS)
│   ├── MenuCamera (Camera3D)
│   │   ├── Environment: ambient/fog/tonemapping/glow/SSAO
│   │   └── CameraAttributesPractical: far depth of field
│   ├── FireLight (OmniLight3D, flicker continuo)
│   ├── MoonFill (DirectionalLight3D)
│   ├── FireFlames (CPUParticles3D, senza ombre)
│   ├── WorldEmbers (CPUParticles3D, senza ombre)
│   ├── Survivor1 (Node3D, camp_avatar.gd: in piedi)
│   ├── Survivor2 (Node3D, camp_avatar.gd: seduto)
│   ├── Survivor3 (Node3D, camp_avatar.gd: coltello)
│   ├── Survivor4 (Node3D, camp_avatar.gd: posa bassa)
│   │   └── modello GLB → Skeleton3D → ossa animate
│   └── terreno, erba MultiMesh, tenda, relitto, tronchi e luci di riempimento
└── Interface (CanvasLayer)
    └── CampMenu (Control, menu.gd, process_mode ALWAYS)
        ├── ForestVeil (ColorRect + ShaderMaterial menu_veil.gdshader)
        ├── Page (Control, pagine ricostruite con dissolvenza)
        │   ├── TitleBlock (VBoxContainer)
        │   │   ├── ZombixWordmark (Label + logo_ink.gdshader)
        │   │   └── HeadWordmark (Label + logo_ink.gdshader)
        │   ├── MenuList (VBoxContainer, separazione 9 px)
        │   │   └── ButtonSlot0…6 (Control, 370×51)
        │   │       └── FireButton (Button, fire_button.gd, 350×51)
        │   ├── ContextHint (Label, testo solo per Host/Join)
        │   ├── CampRoster (Label, anteprima o partecipanti effettivi)
        │   └── controlli della pagina aperta: LineEdit, SpinBox,
        │       HSlider, CheckButton, OptionButton e Label
        ├── BuildBadge (Label, angolo superiore destro)
        ├── CoopBadge (Label, angolo inferiore sinistro)
        ├── SessionStatus (Label, messaggi della connessione)
        ├── ForegroundEmbers (Control, menu_embers.gd)
        ├── WoodPress (AudioStreamPlayer)
        └── EmberHover (AudioStreamPlayer)
Session (autoload, session.gd): lobby ENet e stato della squadra
```

Environment e CameraAttributesPractical sono risorse assegnate alla camera, non nodi figli.
Anche lo ShaderMaterial appartiene al ColorRect/Label: non è un nodo aggiuntivo.

## Composizione e gerarchia visiva

Non esiste più un contenitore rettangolare nero dietro la lista. ForestVeil copre
il viewport con una sfumatura continua scura e leggermente calda, che si dissolve verso
il bosco. Lo shader combina questa sfumatura con una vignettatura morbida. Il colore
varia lentamente, richiamando il fuoco. La sfocatura è profondità di campo della camera
3D: testo e pulsanti rimangono nitidi e leggibili.

Il titolo usa Barlow Condensed SemiBold a 96 px; HEAD a 42 px, con spaziatura manuale.
LogoInk aggiunge una trama sottile di usura e ombra, senza una bitmap applicata sulla scena.
Le voci hanno corpo 31 px. Il layout di riferimento è 1440×900, scalato dal viewport Godot;
la lista usa un VBoxContainer. Non è ancora un layout mobile o ultrawide dedicato.

Voci principali, in ordine: SOLO, HOST GAME, JOIN FRIENDS, CHARACTER, SETTINGS,
CONTROLS, EXIT GAME. Il testo descrittivo non occupa spazio permanente sotto il logo:
appare con dissolvenza quando Host o Join ricevono hover o focus da tastiera/controller.
I badge ai margini hanno contrasto ridotto e gerarchia secondaria.

## Stati del pulsante e logica di selezione

| Stato | Aspetto e comportamento |
| --- | --- |
| Normale | Testo desaturato, alpha 0,84, StyleBoxEmpty senza box o bordo |
| Hover / focus | Colore verso #FFB703, spostamento di 11 px, piccolo indicatore luminoso a sinistra |
| Pressione | Colore verso #FF6B00, scala fino a 0,975, abbassamento di 1,5 px e suono di legno |
| Selezionato | Accento persistente per skin corrente e stato READY |
| Disabilitato | Testo attenuato; il client non può avviare la partita dell'host |

L'interpolazione usa 1−exp(−velocità×delta), indipendente dal frame rate. L'offset
avviene sul Button interno, mentre il Control ButtonSlot mantiene stabile il layout
del VBoxContainer. Questo evita conflitti fra animazione e layout automatico.

mouse_entered / mouse_exited, focus_entered / focus_exited, button_down / button_up
aggiornano lo stato visuale. Il segnale pressed riproduce WoodPress e invoca una
Callable differita: la pagina può essere ricostruita senza distruggere il pulsante
durante la sua gestione dell'input. I collegamenti focus_neighbor_top/bottom mantengono
l'ordine della lista. La prima navigazione salta i pulsanti disabilitati.

Tab/frecce ed Enter funzionano con i controlli nativi. Le azioni UI di Godot includono
D-pad e A; i test hanno usato eventi sintetici nel viewport, non un controller fisico.
Le particelle in primo piano usano MOUSE_FILTER_IGNORE e non possono bloccare i click.

## Quattro animazioni attorno al fuoco

Le pose agiscono sullo Skeleton3D importato e rimangono separate dalle animazioni
di combattimento. Le quattro fasi temporali sono diverse per evitare gesti sincronizzati.

1. In piedi: respirazione, cambio di peso, movimento del braccio verso il colletto.
2. Seduto: busto inclinato, gomiti avanti e movimento delle mani vicino al calore.
3. Coltello: variazione di spalla/gomito/polso e sguardo che segue l'arma; lama agganciata alla mano.
4. Posa bassa: gambe piegate, mani protese e brevi movimenti della testa verso il bosco.

Le animazioni sono procedurali, non motion capture né clip originali convertite.
La cache delle skin evita di ricreare l'avatar e azzerare il movimento a ogni aggiornamento
della lobby. L'anteprima offline mostra quattro sopravvissuti; la lobby mostra soltanto
le persone effettivamente collegate, fino a quattro. Le skin selezionabili restano tre.

## File e istruzioni nell'editor

- ui/camp/menu.gd: pagine, callback, contesto, focus e connessione ai sistemi esistenti.
- ui/camp/fire_button.gd: transizioni e disegno dell'accento, riutilizzabile su un Button.
- ui/camp/menu_veil.gdshader: sfumatura atmosferica e vignettatura.
- ui/camp/logo_ink.gdshader: usura lieve del wordmark.
- ui/camp/menu_embers.gd: scintille decorative in primo piano.
- ui/camp/camp_avatar.gd: quattro pose e movimento dello scheletro.
- ui/camp/camp.gd: disposizione dei personaggi, camera, luce e particelle 3D.
- art/fonts/: font inclusi e licenza; audio/menu_press.wav e menu_hover.wav: suoni originali.

1. Avvia MODIFICA_ZOMBIX_HEAD.cmd, attendi l'importazione e premi F5.
2. Seleziona Remote per trovare CampMenu e CampfireStage.
3. Per usare FireButton altrove, crea un Control di altezza 51 in un VBoxContainer,
   aggiungi un Button, assegna fire_button.gd, imposta text e collega pressed all'azione.
4. Per un nuovo item nella pagina usa button(titolo, 0, callable, descrizione_opzionale).
   Il parametro y è mantenuto per compatibilità; la posizione viene dal VBoxContainer.
5. Modifica MUTED, AMBER e PRESS in fire_button.gd per i colori. Modifica i valori
   12 e 24 per velocità delle transizioni, 11 per lo slide e 0,025 per la pressione.
6. Modifica stance in camp_avatar.gd e le quattro posizioni in camp.gd per la regia.

Il codice completo dei componenti è in CODICE_MENU_0_5.md ed è già applicato al progetto.
Non serve copiare codice dall'esterno o installare plugin.

## Verifiche e limiti

24 controlli sul menu: voci inglesi, font, gradienti, focus, input del puntatore, selezione,
apertura reale della lobby, pagine, skin, quattro avatar, contatto dei piedi e particelle.
19 regressioni AI/lobby e 21 controlli della spedizione. Sessione con host e tre client
locali: quattro personaggi, movimento, danni e stamina confermati.
Catture del menu, della selezione, delle impostazioni e del personaggio; preview animata
di 7,2 secondi acquisita dal renderer Godot a campioni di 10 fotogrammi al secondo.

Vulkan è la modalità verificata per questa resa. La modalità OpenGL sperimentale conserva
il limite noto della 0.4 relativo a due texture segnalate alla chiusura. Internet fra reti
diverse, controller fisico, ultrawide e prestazioni su hardware minimo non sono verificati.

## Font e provenienza

Barlow Condensed Regular e SemiBold, distribuiti insieme alla licenza SIL OFL 1.1.
Fonte: [repository ufficiale Google Fonts](https://github.com/google/fonts/tree/main/ofl/barlowcondensed).
Licenza: art/fonts/OFL.txt. Nessun font installato nel sistema operativo.
Gli altri modelli restano quelli delle versioni precedenti; nessun nuovo plugin o gioco estratto.
