# ZOMBIX HEAD 0.6 — Attività al falò

Quattro superstiti con gesti e posizioni distinti:

- A sinistra, un fumatore alza la sigaretta, fa una pausa e abbassa il braccio; fumo dalla brace ed espirazione.
- Vicino al fuoco, un cuoco sullo sgabello mescola una pentola sospesa, con vapore e cucchiaio in movimento.
- Sul tronco a destra, un superstite affila il coltello con una pietra e guarda il lavoro.
- Sul fondo, una sentinella tiene le braccia raccolte e controlla il bosco con piccoli movimenti della testa.

Sono animazioni procedurali native Godot 4.5.1. La scena mantiene la resa low-poly dei modelli.
Respirazione, tempi sfasati, dita piegate e bersagli per le mani sostituiscono le vecchie pose.
Il falò è più basso per lasciare visibile la pentola. Sedute e distanze sono state ricomposte.
Le tre skin funzionano con tutte e quattro le attività. In lobby appaiono solo i giocatori connessi;
gli oggetti del cuoco vengono nascosti quando il suo posto è vuoto e liberati al cambio della skin.

## Struttura e manutenzione

CampfireStage contiene CookingStation (IronPot, StewSurface, CookingSteam), CookStool,
quattro Survivor, WoodenSpoon, FireFlames, WorldEmbers, luci e MenuCamera.
Ogni Survivor contiene il modello e Skeleton3D, due SkeletonIK3D, due Marker3D per le mani
e gli oggetti specifici della sua attività. Il cucchiaio è figlio del campo per restare nella pentola.

- ui/camp/camp.gd: composizione e ambiente.
- ui/camp/camp_avatar.gd: pose, dita, bersagli delle mani, cicli e oggetti.
- ui/camp/camp_props.gd: geometrie e fumo.
- tests/camp06_checks.gd: verifiche delle attività.
- art/camp/ATTRIBUTION.md: risorse GitHub, autore, licenza e revisione esatta.

SkeletonIK3D è un componente nativo della versione 4.5.1 inclusa. È deprecato da Godot:
un futuro aggiornamento del motore richiederà di rivalutare il sistema IK. Nessun plugin installato.

## Verifica

10 controlli delle attività superati: 3 skin, 24 campioni per ciclo, bersagli delle mani,
piedi, sigaretta, cucchiaio nella pentola, pietra presso la lama, fumo e pulizia degli oggetti.
Errore massimo delle mani rispetto ai bersagli: 3,7 mm. Piedi sempre sopra il terreno nei campioni.
24 controlli di regressione del menu superati, inclusi input, skin, impostazioni e apertura della lobby.
Il test del menu usa --fixed-fps 60 per rendere ripetibili le transizioni basate sul tempo.
Acquisizione Vulkan senza errori nel log, 120 immagini per una preview di 12 secondi a 10 fps.
La GIF è una registrazione del renderer del gioco, ridotta a 800 x 500, non un video prerenderizzato usato dal menu.

Le prove precedenti della cooperativa e della missione restano documentate nella 0.5.
Questa revisione riguarda il falò; non aggiunge sistemi di gameplay o connessione via relay.
