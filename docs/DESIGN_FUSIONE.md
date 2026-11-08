# TESTE — direzione aggiornata

26 ottobre 2026. Questa versione sostituisce la proposta “Acque morte”.

## Vincoli confermati dall'utente

1. SurrounDead sostituisce Never Be Alone come riferimento.
2. Gli zombie sono nemici che popolano il mondo: non si pescano.
3. Si pescano pesci soltanto per mangiare. Niente teste pescate, catture da rivendere,
   esche contro gli zombie, canna da combattimento, gare o boss acquatico.
4. TESTE deve essere un gioco distinto da How to Fish, con spunti selezionati dalle opere
   di riferimento, per esempio per le armi.
5. Terminata la correzione della direzione, avviare direttamente la Fase 1.

## Identità

Un open world zombie stilizzato in terza persona. Parti dal rifugio del Vecchio, esplori,
affronti infetti e raccogli teste per migliorare equipaggiamento e cure. Le quest riparano
il rifugio e aprono i servizi; i boss consentono l'accesso alle zone successive.
La sopravvivenza alimentare è un supporto all'esplorazione, non il centro del gioco.
Il nome torna a essere semplicemente TESTE.

| Riferimento | Cosa osserviamo | Adattamento per TESTE |
|---|---|---|
| SurrounDead | Famiglie di armi, risorse separate per zombie, spawner e bottino | Armi e nemici modulari, con dati di bilanciamento propri |
| How to Fish | Sistemi distinti per equipaggiamento, inventario e uso delle armi | Interazioni leggibili e feedback; niente copia del suo ciclo economico della pesca |
| Brief TESTE | Valuta in teste, morte leggera, NPC comici, quattro zone, casinò e boss | Rimane la struttura di progressione principale |

Queste sono scelte di design: non significano importazione degli asset o del codice
compilato dei giochi. Il progetto usa modelli provvisori originali e nuovo GDScript.

## Armi previste dal brief

Accetta iniziale, coltello, machete, katana e motosega; pistola, revolver, shotgun e fucile
d'assalto; molotov e granate. Danno, portata, cadenza, stamina, prezzo e rumore saranno dati
modificabili. In Fase 2 si implementa l'accetta; le armi da fuoco arriveranno in Fase 8.
L'analisi dei giochi serve a separare responsabilità e parametri, senza attribuire a TESTE
valori di danno non verificati o copiare l'economia di un altro gioco.

## Pesca alimentare futura

Nel sistema di fame della Fase 7, il pontile permetterà di ottenere pesci commestibili.
Il pesce ripristinerà fame secondo dati dedicati. Non produce valuta, non sblocca zone
e non sostituisce il ciclo zombie → teste → equipaggiamento.
La pesca non è ancora disponibile nella build Fase 1.

## Decisioni mantenute

- Prima versione single player; multiplayer fuori dall'ambito attuale.
- Teste base 1, corazzate 2, valore doppio di notte; nessuna doppia applicazione del bonus.
- La morte futura fa perdere solo le teste trasportate e ne lascia metà recuperabile.
- Gli strumenti F2 e ripristino della Fase 1 sono strumenti di prova, da eliminare dalla build finale.
- Nessun plugin verrà aggiunto senza chiedertelo.
