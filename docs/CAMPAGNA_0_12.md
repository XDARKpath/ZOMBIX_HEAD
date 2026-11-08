# ZOMBIX HEAD 0.12 — Mappa, GPS e 4×4

## Prova la partita

Apri `AVVIA_ZOMBIX_HEAD.cmd`, scegli SOLO oppure HOST GAME. Per la cooperativa,
gli altri tre giocatori entrano nel campo e si dichiarano pronti prima dell'avvio.
Le istruzioni di collegamento e porta UDP sono in ONLINE.md.

1. Al rifugio recupera batteria, cinghia motore e carburante: avvicinati e premi E.
2. Torna al 4×4. Premi E per iniziare gli otto secondi di riparazione e rimani vicino.
3. Premi E per salire. Il primo occupante guida; ci sono altri tre posti.
4. WASD guida: W accelera, S frena e va in retromarcia, A/D sterzano. Rilascia
   l'acceleratore per frenare. E fa scendere solo da fermo, se c'è spazio libero.
5. G apre il GPS. Segui la strada e il segnalino fino alla destinazione. Fermatevi
   entro 22 metri con tutta la squadra a bordo per attivare il nuovo presidio.
6. Scendete, eliminate i sei infetti, riunitevi al presidio e usate il relay con E.
   Il download di dieci secondi rivela una sola nuova coordinata. Ripartite insieme.

Il GPS non mette in pausa la partita. Esc apre il menu; in cooperativa il mondo
continua. A piedi restano WASD, Shift, Spazio e Ctrl. Gli attacchi in mischia del
prototipo rimangono disponibili. Una nuova partita ricomincia dal rifugio.

## Dimensioni e progressione

Otto destinazioni, sette collegamenti continui per circa **12,78 km di strada**.
Ogni coppia di tappe consecutive dista tra 1,45 e 2,09 km. Il 4×4 raggiunge 24 m/s
(86 km/h); la taratura di guida è provvisoria. Il terreno carica e scarica settori
di 128 metri vicino ai giocatori e al mezzo, senza caricare tutta la regione insieme.

Nomi e temi sono proposte modificabili: Lago Cenere, Stazione Forestale, Cava
Silente, Borgo del Ripetitore, Deposito Militare, Diga Nord, Centro di Ricerca,
Ultima Frequenza. **Le ultime sette zone sono presidi di prova con edifici,
tende e infetti; non rappresentano ancora cave, dighe o laboratori completi.**
Missioni, interni, varietà del paesaggio e punti d'interesse richiedono il prossimo
passaggio di progettazione con l'utente.

La distanza rende il viaggio a piedi lungo, ma non lo rende fisicamente impossibile.
La progressione richiede il mezzo riparato, la squadra a bordo e il GPS sbloccato:
raggiungere una zona a piedi non la attiva. Le coordinate future restano nascoste.

## Asset dei pacchetti forniti

- **Stylized Nature MegaKit Standard**: 68 modelli, con 15 texture utilizzate dai
  file glTF; distribuiti nei settori del terreno. Conservata la licenza CC0 fornita
  da Quaternius. Non sono inclusi i duplicati FBX/OBJ/Unity.
- **Universal Animation Library Standard**: selezionate 24 clip utili al survival,
  adattate agli scheletri delle tre skin esistenti. Il gioco collega camminata,
  corsa, accovacciamento, salto/atterraggio, raccolta, riparazione, guida, morte e
  attacco. Mira, ricarica, reazioni e nuoto sono pronti nella libreria per le future
  meccaniche corrispondenti. Esclusi balli, incantesimi, conversazioni, camminata
  formale e duplicati con root motion. Licenza CC0 originale inclusa.
- **POLYGON BowAndCrossbow SourceFiles v3**: due archi, balestra, due frecce e dardo
  convertiti in sei scene native, con texture e rig conservati. Presenti sul banco
  del rifugio; impugnatura e punto di uscita predisposti. Questi modelli non
  costituiscono ancora un sistema di tiro, munizioni, ricarica o equipaggiamento.
- **Tripo3D 3ds Max Bridge**: ispezionato, non installato. È un ponte di authoring
  per 3ds Max, non un contenuto da inserire nella partita né un plugin Godot
  necessario per questi asset.

I materiali precedenti, il menu al falò e le skin rimangono nel progetto. Le skin
definitive verranno valutate alla fine come richiesto. Nessun plugin nuovo aggiunto.
Il suono provvisorio del motore è sintetizzato appositamente per il progetto.

## Limiti della versione

È una base giocabile di campagna, non un gioco finito. Mancano salvataggio della
campagna, inventario completo, mani/armi FPS dedicate, tiro e ricarica delle armi
a distanza, pesca alimentare, missioni differenziate e asset ambientali specifici
dei sette temi. La fisica del 4×4 è un controller semplificato, senza sospensioni
realistiche o danni. Le disconnessioni liberano i posti; non c'è migrazione dell'host.
La verifica in locale con quattro processi non sostituisce una prova su quattro
PC attraverso Internet. La vegetazione usa per ora una distribuzione iniziale,
da ottimizzare e comporre artisticamente dopo aver deciso le ambientazioni.

## Verifiche riproducibili

Con Godot 4.5.1 e progetto importato:

```
godot --headless --path ZOMBIX_HEAD --script res://tests/campaign_runner.gd
godot --headless --fixed-fps 60 --path ZOMBIX_HEAD --script res://tests/campaign_drive.gd
godot --headless --path ZOMBIX_HEAD --script res://tests/fps_runner.gd
```

Il runner campagna controlla interazioni a distanza, requisiti di riparazione,
posti univoci, uscita da fermo, squadra, otto transizioni, selezione delle animazioni
e scene delle armi. La prova di guida percorre fisicamente la prima tratta; le
altre transizioni del runner sono accelerate per verificare la logica.
Il test di rete usa `campaign_network.gd` con `--campaign-host` e tre processi
`--campaign-client` sulla porta locale 27849. I test storici della missione radio
descrivono la vecchia missione e non la campagna 0.12.

La prima importazione nella copia estratta si è interrotta durante i font; il
secondo tentativo è terminato correttamente senza risorse mancanti. Il programma
di avvio ritenta già automaticamente una volta se l'importazione si interrompe.

Dettagli di conversione: API native [GLTFDocument](https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html)
e AnimationLibrary; nessun servizio online necessario per giocare.
