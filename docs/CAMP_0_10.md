# ZOMBIX HEAD 0.10 — Mani, pose e tronco condiviso

Il cuoco e il personaggio a destra con lo sniper siedono sullo stesso tronco grande.
Il cuoco tiene le gambe raccolte; il tiratore ne distende una. Quello con la katana,
a sinistra del fuoco, conserva la precedente posizione inginocchiata. Il fumatore
rimane appoggiato alla 4x4, ora con una pistola del pacchetto Gang Warfare nella mano libera.
Il polso della pistola segue la direzione del braccio; canna abbassata e indice disteso.
La tenda è spostata leggermente a sinistra.

Le mani vengono dal modello DEA del pacchetto Gang Warfare fornito dall'utente.
Palmo, pollice e indice sono adattati dal modello; medio, anulare e mignolo sono
ricostruiti dalla geometria dell'indice, con proporzioni diverse. Ogni mano ha
20 ossa, cinque dita separate e pose specifiche per sigaretta, bastone, panno e armi.
I polsi seguono lo scheletro del personaggio; le vecchie mani unite sono escluse
dalla mesh usata nel falò. Corrette le direzioni dei palmi e la piega dei polsi.
La modifica riguarda i personaggi del menu; il personaggio giocabile usa ancora
il proprio sistema di animazione.

Sniper e katana usano nuovi modelli provenienti da GitHub, con materiali e dettagli
adattati. Il fucile conserva il suo scheletro e ha una nuova ottica; la katana ha
lama rastremata, fasciatura incrociata e materiali separati. Le scene indipendenti
art/weapons/sniper.tscn e katana.tscn hanno riferimenti per le prese e il futuro
utilizzo nel gameplay. Spari, ricarica e combattimento con queste armi restano
da collegare. Provenienza e licenze in art/weapons/ATTRIBUTION.md e
art/gang_warfare/PROVENANCE.md. Nessun nuovo plugin.

## Verifiche

31 controlli del falò su tre skin e 28 campioni del ciclo; 24 controlli del menu.
55 controlli superati. Verificati i bersagli delle mani, il contatto del panno,
le prese, i piedi sopra il terreno, la seduta di cuoco e tiratore sullo stesso
tronco e il ripristino della posizione della katana. Catture ravvicinate e laterali
nel motore Vulkan, più anteprima animata di 14 secondi. Le misure dei punti dello
scheletro non certificano l'assenza di ogni piccola intersezione delle mesh.
Lo stile degli asset rimane low-poly e le animazioni sono procedurali.

Log: docs/VERIFICA_CAMP_0_10.txt. --verify-camp esegue tests/camp10_checks.gd.
