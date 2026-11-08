# ZOMBIX HEAD 0.8 — Sosta al campo

4x4 militare accanto al fumatore: carrozzeria verde oliva, quattro ruote con battistrada,
ruota di scorta, portapacchi, paraurti, fari e vetri. È un oggetto scenico originale,
costruito nel progetto con geometrie native; non è ancora un veicolo guidabile.

Il fumatore appoggia il corpo al mezzo, tiene una gamba piegata con lo stivale presso
la ruota e l'altra a terra. Il ginocchio rimane davanti alla fiancata. Il ciclo di 14 secondi
comprende salita del braccio, pausa, discesa, espirazione e riposo; il polso ruota durante
la salita e la sigaretta segue il riferimento della mano. Piccoli movimenti di testa e respiro.

La tenda è spostata verso destra, dietro il falò; la lanterna ne illumina l'ingresso.
La pentola e il treppiede sono rimossi. Il cuoco tiene un bastone con un pollo arrosto:
corpo, ali, cosce e segni di cottura, con fumo leggero. Il bastone mantiene la lunghezza
mentre il personaggio lo inclina e gira il pollo sopra il fuoco.

Il personaggio sul tronco è girato verso il gruppo. Pulisce la pistola con passaggi più lenti,
brevi soste, sollevamento per l'ispezione e ritorno al lavoro. Mano di sostegno e polsi
seguono ora la rotazione dell'arma. Il superstite con la katana è girato leggermente verso
il fuoco; alterna sollevamento, pausa di osservazione e abbassamento della lama.

I quattro personaggi restano disposti attorno al falò, con il centro libero.
Le tre skin sono conservate. La resa rimane low-poly, coerente con gli asset del progetto.

## Implementazione e prove

- ui/camp/camp_vehicle.gd: 4x4 militare originale.
- ui/camp/camp_props.gd: pollo, bastone e altri oggetti del campo.
- ui/camp/camp_avatar.gd: appoggi, mani e cicli delle attività.
- ui/camp/camp.gd: posizioni del gruppo, tenda e luce.
- tests/camp08_checks.gd: 16 verifiche delle attività e degli oggetti.

16 controlli superati su tre skin e 28 campioni per ciclo: mani, piedi, spazio del ginocchio
rispetto al mezzo, stivale sollevato presso la ruota, pollo sopra il fuoco, bastone rigido,
panno sull'arma, cambio skin e visibilità degli oggetti in lobby.
Errore massimo mano-bersaglio 2,3 mm; pollo entro 10,8 cm dal centro di riferimento sopra il fuoco.
24 controlli del menu superati, comprese selezione delle skin e apertura della lobby.
Queste misure verificano punti dello scheletro e degli oggetti; non certificano ogni vertice
delle mesh. La resa è stata controllata anche su catture effettive di Godot Vulkan.

Anteprima di 14 secondi, 140 fotogrammi a 10 fps, ridotta a 800 x 500.
Log in VERIFICA_CAMP_0_8.txt. --verify-camp esegue i controlli della revisione corrente.
Nessun plugin nuovo. Provenienza del fumo e licenze esistenti in art/camp/ATTRIBUTION.md.
Gameplay, guida dei veicoli e cucina interattiva non sono stati aggiunti: questa revisione
riguarda la scena animata del menu. Il gameplay esistente resta disponibile.
