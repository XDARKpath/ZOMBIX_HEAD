# ZOMBIX HEAD 0.13 — Rifugio Lago Cenere

30 ottobre 2026. Godot 4.5.1. Aggiornamento del primo livello giocabile.

## Ambienti e obiettivo

- Casa del guardiano: cucina/soggiorno e ufficio posteriore. Batteria 12 V sulla scrivania.
- Alloggio di servizio: due stanze, letto, tavolo e arredi.
- Officina Cenere: due baie aperte, banchi, scaffali, sollevatore, ruote e ricambi.
  Cinghia motore sul banco posteriore destro.
- Deposito carburante: tettoia, fusti e taniche. Carburante sul pallet a destra.
- Ingressi raccordati al terreno, corridoi liberati dai mobili, collisioni per pareti,
  arredi e tetti. Sentieri, cartelli e luci guidano verso i punti di interesse.
- Recuperare i tre pezzi con E e riparare il mezzo per otto secondi, poi viaggiare
  insieme verso il prossimo punto GPS. Rimangono attive le otto destinazioni della 0.12.

## Provenienza

55 modelli selezionati dai Source Files v4 del POLYGON Gang Warfare fornito dall'utente,
convertiti in scene Godot native con la texture originale PNG assegnata. Moduli di
pareti, finestre, porte, pavimenti, tetti e arredi; catalogo in art/refuge/sources.json.
Il convertitore FBX segnalava i vecchi riferimenti PSD del progetto d'origine: le scene
native usano la texture PNG fornita, senza dipendenze dai percorsi del computer d'origine.

Mantenuti i modelli SurrounDead già importati, compresi i tre zombie. Il frammento
originale della mappa contiene sette oggetti con disposizione relativa conservata:
non è l'intera mappa di SurrounDead. Le due nuove case e l'officina sono composizioni
originali costruite dai moduli Gang Warfare. Il terreno della regione usa il Nature MegaKit.

Universal Animation Library: sette clip selezionate, adattate separatamente ai tre
scheletri zombie: Idle_Loop, Walk_Loop, Jog_Fwd_Loop, Punch_Cross, Punch_Jab,
Hit_Chest, Death01. Le animazioni giocatore della 0.12 restano separate. Nessuna skin
sostituita. Nessun plugin installato. Le pose e le mani del menu al falò sono conservate.

## Comportamento

Zombie con andatura e attacchi scheletrici, reazione ai colpi e caduta; leggera postura
curva aggiunta al movimento. Attacco sincronizzato con il tempo dell'host sui client.
Il percorso segue più precisamente gli angoli delle porte, per non tagliare contro gli
stipiti. La navmesh comprende gli interni. Il recupero pezzi controlla distanza e muri.
Il GPS evita di proiettare punti sul piano della camera durante i cambi posto in auto.

## Verifiche

Esiti e log conclusivi: VERIFICA_RIFUGIO_0_13.txt. Prove automatiche su ingressi, raccolta
pezzi dal pavimento, ostacoli, navigazione, inseguimento e selezione delle animazioni.
La prova campagna copre la riparazione e tutte le transizioni GPS. Quattro processi
locali verificano host, tre client, animazione d'attacco replicata, guida e arrivo condiviso.
Il test locale non sostituisce una prova Internet con PC separati.

Le sei foto sono immagini del renderer del gioco a 1440×900, con camera fotografica,
HUD nascosto e attori fermati per l'inquadratura. Non sono immagini generate da IA.

## Stato del progetto

Questa è una rifinitura del prototipo di livello 1, con stile low poly coerente con
le risorse fornite. Le altre sette tappe restano presidi provvisori. Missioni specifiche,
armi e mani FPS, tiro/ricarica, inventario, salvataggi della campagna e pesca alimentare
restano da sviluppare nelle prossime fasi con l'utente.
