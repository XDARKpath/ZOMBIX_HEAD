# Giocare insieme — massimo quattro persone

## Sulla stessa rete

1. Tutti estraggono la stessa versione del pacchetto ZOMBIX HEAD e avviano il gioco.
2. L'host sceglie HOST GAME, inserisce il nome e lascia la porta 27831
   oppure ne sceglie una libera, poi OPEN CAMP.
3. L'host usa COPY LOCAL ADDRESS e comunica indirizzo e porta agli amici.
4. Gli amici scelgono JOIN FRIENDS e inseriscono questi dati.
5. Ogni persona sceglie la propria skin e preme READY UP. L'host avvia con START EXPEDITION.

La lobby visualizza solo le persone connesse. Senza connessione il menu mostra quattro pose
di anteprima, non tre compagni controllati dal computer.

## Su Internet

Il collegamento usa ENet/UDP. L'indirizzo locale 192.168… o 10… non è l'indirizzo pubblico
da dare agli amici su un'altra rete. La porta UDP scelta deve essere raggiungibile sul PC
dell'host attraverso router e firewall. Il gioco non modifica automaticamente queste impostazioni.
Se la connessione è dietro CGNAT, l'inoltro sul solo router domestico può non bastare;
questa versione non dispone di un relay. Nessun account, lista server o invito Steam è implementato.

Riferimento tecnico: [rete multigiocatore Godot 4.5](https://docs.godotengine.org/en/4.5/tutorials/networking/high_level_multiplayer.html).

## Durante la partita

L'host gestisce movimenti remoti, danni, stamina e zombie. I client ricevono aggiornamenti
del mondo e anticipano il proprio movimento. Esc apre il menu senza fermare gli altri.
La morte riporta al rifugio. Non c'è fuoco amico. La skin si cambia prima di entrare nel mondo.
Quando un client esce il suo personaggio scompare; se l'host esce la sessione termina.
Non c'è trasferimento dell'host, ingresso a partita iniziata o salvataggio del mondo.

## Problemi comuni

- Porta non disponibile: un'altra istanza la sta usando; chiudi quella sessione oppure cambia porta su tutti i PC.
- Connessione non riuscita: controlla indirizzo, porta, host aperto e raggiungibilità UDP.
- VPN o più schede di rete: l'indirizzo suggerito può essere della scheda sbagliata; usa quello della rete condivisa.
- Non parte: tutti i membri devono essere pronti, incluso l'host se ha tolto il proprio stato pronto.
- Partita iniziata o piena: rientrate nel menu e create una nuova lobby.
- Primo avvio lento: Godot sta importando i modelli; lascia terminare l'operazione.

## Verifica eseguita

Quattro processi sullo stesso PC: un host e tre client, stessa build, connessione 127.0.0.1.
Confermati quattro personaggi, sei zombie iniziali, aggiornamenti del mondo, movimento,
attacco remoto con danno applicato dall'host e consumo della stamina. Uscita senza errori nei log.
Non è ancora una prova fra quattro PC su reti Internet diverse, né un test di latenza,
perdita di pacchetti o sessioni di lunga durata.

La missione Ultimo segnale è condivisa: casse, radio e tempo di difesa sono decisi dall’host.
Una seconda prova con quattro processi ha confermato raccolta via RPC, attivazione e conclusione su tutti i client.

