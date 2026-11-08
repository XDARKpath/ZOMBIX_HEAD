# ZOMBIX HEAD — piano del gameplay

Piano proposto il 29 ottobre 2026. Le preferenze da decidere con l'utente sono
indicate esplicitamente: non sono requisiti già approvati.

## Rifugio 0.13 — aggiornamento del 30 ottobre 2026

Prima zona ora dotata di case esplorabili, officina, deposito carburante e ricambi
collocati negli ambienti. Zombie con sette animazioni selezionate UAL e navigazione
negli interni. Prossimo feedback: valutare queste foto e la visita nel livello 1;
poi definire combattimento FPS, inventario e contenuto delle zone successive.
Dettagli e limiti in RIFUGIO_0_13.md. Le otto tappe non sono otto livelli rifiniti.

## Aggiornamento approvato — 30 ottobre 2026

L'utente ha scelto una mappa grande con almeno 7–8 destinazioni GPS lontane e
un'auto da riparare nella prima zona. La 0.12 introduce otto tappe continue, sette
tratti di strada (12,78 km totali), riparazione e viaggio cooperativo sul 4×4.
Le coordinate si sbloccano una alla volta. Distanze e regola del mezzo sono attive;
le ambientazioni delle tappe e le missioni differenziate sono ancora provvisorie.
I nuovi pacchetti Nature, UAL e Archery sono integrati secondo CAMPAGNA_0_12.md.
La vecchia proposta di una sola piccola zona, riportata sotto, è superata da questa
scelta. La prossima decisione riguarda l'aspetto e il contenuto della prima zona.

## Decisioni già fissate

- Gioco survival con zombie presenti nel mondo.
- Visuale in prima persona.
- La squadra entra insieme, completa una zona e prosegue verso la successiva
  seguendo il GPS. Questo è il percorso principale della partita.
- Movimento equilibrato: camminata con peso, corsa fluida, salto e accovacciamento.
- Pesca per procurarsi cibo; non si pescano zombie.
- Solo oppure cooperativa fino a quattro giocatori; uno dei giocatori ospita.
- Conservare le skin attuali durante lo sviluppo. Valutare quelle definitive
  quando il gioco sarà finito.
- Procedere una tappa alla volta, con indicazioni dell'utente e una versione
  giocabile da provare prima della tappa successiva.
- Chiedere prima di aggiungere nuovi plugin non già autorizzati.

## Punto di partenza

La 0.10.1 contiene un prototipo in terza persona con movimento, attacco in mischia,
zombie, interazioni e una missione di raccolta/difesa della radio. La cooperativa
è stata verificata con quattro processi sullo stesso PC. Il menu ha quattro
attività animate, skin selezionabili e impostazioni.

Pistola, sniper e katana del menu sono scene visive: la loro presenza non equivale
a un sistema giocabile di tiro, munizioni, ricarica e danni. Inventario completo,
pesca alimentare, fame e salvataggio del mondo non sono ancora implementati.
La prova della cooperativa fra PC su reti diverse resta da svolgere.

## Metodo di lavoro

Per ogni tappa: raccogliere le preferenze relative a quella parte, fissare un
obiettivo piccolo, implementarlo, controllarlo in solo e con host/client quando
tocca lo stato condiviso, consegnare una versione giocabile e incorporare il
feedback dell'utente. Le scelte visive e di ritmo restano aperte fino al suo riscontro.
Non aprire tutte le tappe insieme.

Primo traguardo proposto: una sessione breve completa in una piccola zona,
con ingresso della squadra, esplorazione, raccolta, combattimento e completamento
della zona, seguito dall'indicazione GPS per proseguire. Durata indicativa per la
prova: 10–15 minuti, non limite del gioco finale. Checkpoint da concordare.

## Scelte iniziali ricevute

Prima persona; movimento equilibrato con salto e accovacciamento. Progressione
cooperativa a zone consecutive guidata dal GPS. Restano da scegliere gli obiettivi
che completano una zona, l'aspetto del GPS e il modo di attraversare il confine
(percorso continuo oppure caricamento). Le regole di checkpoint e salvataggio
non sono ancora state definite.

## 1. Movimento, camera e interazioni

Da decidere: peso e velocità del personaggio, corsa, salto/accovacciamento/schivata,
sensibilità della camera e distanza di interazione. Le azioni non sono tutte
obbligatorie: scegliere quelle utili al gioco desiderato.

Realizzare: controlli coerenti, animazioni delle azioni scelte, camera che evita
i muri, feedback chiaro per raccogliere e interagire, HUD essenziale.

Prova: muoversi in un percorso con porte, angoli, dislivelli e ostacoli, senza
incastrarsi o perdere il personaggio dietro la camera. Questa è la prima tappa attiva.

## 2. Prima zona giocabile

Da decidere: ambientazione, ora e atmosfera, luoghi da esplorare, grado di libertà.
Proposta da discutere: rifugio al lago, bosco, una strada e un piccolo edificio
da saccheggiare. Non è ancora la mappa finale.

Realizzare: distanze interessanti a piedi, interni accessibili, percorsi leggibili,
collisioni e aree in cui gli zombie possono muoversi. Inserire luci e audio
ambientali sufficienti a giudicare l'atmosfera già durante la prova.

Prevedere un ingresso comune della squadra e un'uscita verso la zona successiva,
indicata dal GPS dopo il completamento degli obiettivi concordati. L'host gestirà
lo stato condiviso della progressione. Non sostituire questo percorso con un mondo
aperto persistente o un rientro obbligatorio al campo senza una nuova scelta dell'utente.

Prova: uscire dal rifugio, raggiungere un luogo utile e ritornare senza blocchi;
la zona deve offrire almeno una decisione fra percorso diretto e percorso prudente.

## 3. Oggetti, inventario e primo salvataggio

Da decidere: zaino a griglia o a slot, peso/capienza, barra rapida, loot condiviso
o individuale, conseguenze della morte e regole del salvataggio.

Realizzare: raccogliere, equipaggiare, usare, spostare e lasciare oggetti; contenitori;
identificatori stabili degli oggetti; primo salvataggio coerente con la struttura
scelta. Impostare versioni dei dati e responsabilità dell'host fin dall'inizio.

Prova: due giocatori non duplicano lo stesso oggetto; lasciare e ricaricare la
partita conserva gli elementi previsti dalle regole scelte.

## 4. Combattimento e armi giocabili

Da decidere: mira, rinculo, danni, munizioni, ricarica, ritmo degli attacchi e
eventuale fuoco amico. Non assumere automaticamente un sistema realistico o arcade.

Realizzare per prime una pistola e un'arma da mischia, poi lo sniper sullo stesso
sistema: equipaggiamento, prese corrette, animazioni, colpi, impatti, suoni e danni.
Tenere modello visivo e caratteristiche dell'arma separati. L'host decide danni e
consumo delle risorse condivise.

Prova: mirare e colpire bersagli fermi/in movimento; ricaricare, cambiare arma,
esaurire munizioni e verificare i danni sia da host sia da client.

## 5. Comportamento degli zombie

Da decidere: zombie lenti, veloci o misti; quanto vedono e sentono; quantità,
pericolosità e tempi di respawn.

Realizzare: vagare, percepire, indagare, inseguire, attaccare, perdere il bersaglio,
reagire ai colpi e morire. Collegare il rumore degli spari alle reazioni scelte.
Gestire porte, ostacoli, distanze di attacco e limiti necessari alle prestazioni.

Prova: affrontare un nemico e un piccolo gruppo, tentare di evitarli, rompere
il contatto visivo e controllare le stesse reazioni sui client.

## 6. Sopravvivenza, pesca e cucina

Da decidere: presenza e severità di fame/sete, recupero della stamina, ferite,
meccanica della pesca, tempi di cottura e utilità del giorno/notte.

Realizzare: un ciclo alimentare completo e leggibile — trovare attrezzatura,
pescare, conservare e cucinare il pesce, mangiare — collegato all'inventario.
Integrare i bisogni selezionati senza introdurre indicatori senza funzione.

Prova: procurarsi una cena partendo senza cibo; verificare uso e consumo condiviso
degli oggetti e l'effetto sul personaggio.

## 7. Obiettivi, rifugio e progressione

Da decidere: libertà di esplorazione, quest, ricompense, obiettivo di una sessione,
ruolo del rifugio. La missione della radio attuale resta un prototipo da valutare.

Realizzare: una prima sequenza completa con motivo per uscire, rischio, ricompensa
e ritorno. Integrare solo i miglioramenti del rifugio approvati dall'utente.

Prova: giocare la sessione di 10–15 minuti dall'inizio al salvataggio senza
comandi di sviluppo o salti artificiali degli obiettivi.

## 8. Cooperativa fra PC e gestione delle interruzioni

L'online viene mantenuto durante le tappe precedenti; qui si verifica una sessione
completa fra computer diversi. La prova locale attuale non sostituisce questa tappa.

Da decidere: rianimazione, respawn, riconnessione, ingresso a partita iniziata,
comportamento quando l'host esce e modalità desiderata per invitare gli amici.
Eventuali servizi o plugin aggiuntivi richiedono una scelta separata.

Realizzare e provare: regole concordate, sincronizzazione di inventari/nemici/quest,
latenza, disconnessioni, riapertura del salvataggio e messaggi comprensibili per gli errori.

## 9. Espansione e rifinitura del gioco

Dopo la prima sessione completa: aggiungere le zone, armi, nemici e attività
effettivamente scelti, usando i sistemi già provati. Rifinire animazioni, audio,
illuminazione, meteo se approvato, leggibilità degli interni, HUD e impostazioni.
Misurare le prestazioni sui PC di riferimento e provare sessioni più lunghe.

Veicoli guidabili, costruzione libera, boss, negozi e altre espansioni restano
idee da discutere: non sono automaticamente parte del prossimo lavoro.

## 10. Skin definitive, dopo il completamento del gioco

Conservare fino ad allora le skin attuali. Quando l'utente sceglierà i personaggi
definitivi, adattare scheletri e animazioni e verificare di nuovo mani, prese,
equipaggiamento, collisioni, camera e rappresentazione dei compagni online.

## Stato delle scelte

- Visuale: prima persona, confermata.
- Struttura: zone consecutive completate dalla squadra, avanzamento guidato dal GPS.
- Movimento: equilibrato; camminata, corsa, salto e accovacciamento.
- Tappa 1: prima implementazione 0.11 pronta per la prova dell'utente. Dettagli in FPS_0_11.md.
- Tappa 2: da progettare con l'utente dopo il feedback sui controlli.
