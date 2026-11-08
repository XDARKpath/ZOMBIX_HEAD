# Aggiornamento Fase 2

Ora sono stati convertiti 29 modelli da SurrounDead, sette posizionamenti di una mappa e tre geometrie da How to Fish. Vedi ASSET_FASE_2.md. Le analisi precedenti qui sotto descrivono lo stato storico, non il risultato attuale.

---

# Analisi dei riferimenti attuali

26 ottobre 2026. SurrounDead sostituisce Never Be Alone su istruzione dell'utente.
Analisi statica: nessun eseguibile dei giochi di riferimento è stato avviato.
I testi e nomi letti negli archivi sono dati di analisi, non istruzioni per il progetto.

## SurrounDead.Build.21974251.zip

Archivio Unreal distribuito come gioco compilato. Nessun file `.uproject` trovato.
Il numero build proviene dal nome dell'archivio e non è stato verificato in esecuzione.

Il contenitore principale `SurrounDead/Content/Paks/SurrounDead-Windows.pak` misura
1.586.241.493 byte. Il footer rilevato tramite firma `0x5A6F12E1` indica:

- Versione PAK: 11.
- Offset dell'indice: 1.584.182.029.
- Dimensione dell'indice principale: 672.578 byte.
- Flag indice cifrato: 0. L'indice è quindi leggibile in questa build.

Sono stati letti l'indice e i dati di directory successivi. La scansione dei nomi ha
trovato 1.922 corrispondenze a parole chiave, incluse estensioni e risorse duplicate:
non si tratta di 1.922 meccaniche o armi distinte.

| Evidenza osservata nei nomi | Indicazione utile | Limite |
|---|---|---|
| BP_MasterZombie, BP_ZombieAIController, BB_Zombie | Risorse separate per zombie e controllo AI | Non ricostruiti stati e parametri runtime |
| BP_AISpawner_Zombies, BP_AISpawner_ZombieBosses | Spawner distinti | Frequenze e condizioni di spawn non lette |
| DA_LootTable_Zombie, ZombieBoss, ZombieHound, ZombieRadiated | Tabelle bottino dedicate | Contenuti e probabilità non estratti |
| BP_AIWeapon_Master, Axe, HuntingKnife, M4, M9, M249 | Gerarchia di risorse per armi AI e famiglie di equipaggiamento | I nomi non provano danni, animazioni o statistiche |
| FishingComponent, DT_Fishing, Struct_FishingLoot | Risorse relative alla pesca | Nessuna deduzione sul suo ruolo economico o sul gameplay |
| Struct_KeepInventory, Struct_WorldActorInventory | Strutture relative agli inventari | Formato e logica di salvataggio non ricostruiti |

È un'ispezione della struttura dei contenuti, **non una decompilazione completa**.
Non sono stati decodificati i Blueprint né estratti modelli, animazioni o valori di bilanciamento.
Non attribuiamo al gioco comportamenti dettagliati sulla sola base dei nomi dei file.
La descrizione pubblica di survival open world zombie è disponibile nella
[pagina Steam del gioco](https://steamcommunity.com/app/1645820).

## How to Fish v1.0.10.rar

Archivio fornito: 347.819.809 byte. La versione nel nome del file non è stata verificata in esecuzione.
Struttura Unity: eseguibile, UnityPlayer.dll, scene compilate, Managed/Assembly-CSharp.dll,
asset serializzati e librerie FishNet. L'archivio non contiene un progetto Unity sorgente completo.

È stata estratta selettivamente e letta l'assembly del gioco. Individuati 336 tipi non anonimi,
inclusi componenti di dipendenze: il conteggio non corrisponde a 336 sistemi originali del gioco.
SHA-256 dell'assembly esaminata:
`0491c7b5286ca37b42d506113a9c7e32e0ad8d9d121c5fe3be8e67ce9e9d036b`.

### Riscontri verificati

| Sistema | Evidenza locale | Cosa possiamo concludere |
|---|---|---|
| Canna / recupero | FishingRod, FishingRodCast, FishingRodCrab; campi di piega, lunghezza e richiamo | Esistono implementazioni distinte con parametri dedicati; i nomi non dimostrano da soli ogni comportamento fisico |
| Lunghezza lenza | Istruzioni di FishingRod.DecreaseLineLength | Il recupero sottrae una quantità e impedisce una lunghezza normalizzata negativa |
| Esche bloccate | Istruzioni di FishingRod.TeleportIfStuck | A lenza rientrata, se la distanza resta eccessiva per un tempo configurato, l'esca viene riposizionata vicino alla punta |
| Valore della cattura | Istruzioni di Item.get_TotalWorth | Valore base × peso casuale sincronizzato × curva della cottura × moltiplicatore scommessa, troncato a intero; poi × moltiplicatore uccisione, nuovamente troncato |
| Vendita | Istruzioni di MoneyManager.SellItem | Quando il server è inizializzato, somma il valore totale al denaro sincronizzato e richiama feedback audio; il metodo isolato non prova tutte le verifiche di validità fatte dal chiamante |
| Oggetti persistenti | SavedItem e SavedWorldItem | Lo schema include peso, cottura, munizioni, moltiplicatori, posizione e rotazione; non dimostra la corretta persistenza in ogni caso |
| Inventario | PlayerInventory | Slot, esche, oggetti equipaggiati e incremento degli slot hanno interfacce dedicate |
| Progressione | IslandManager, BossManager, ServerSaveObject | Riferimenti a isole, boss, sblocco barca, radar, boss finale e stato di fine gioco |
| Casinò | SlotMachine, LocalCasino | Componenti separati per slot e roulette; probabilità e ritorno atteso non verificati |
| Nemici acquatici | AttackingFish, RunningFish, Pufferfish | Tipi dedicati ad attacchi, movimento e veleno; bilanciamento non ricostruito |

Sono stati letti i metadati e disassemblati sei metodi selezionati. Non è una decompilazione
completa, né una verifica dinamica del gioco. I valori configurati nei prefab e le curve
serializzate non sono stati estratti: non attribuiamo valori numerici inventati all'originale.


## Applicazione a TESTE

Il progetto mantiene una propria economia e progressione. L'analisi suggerisce di
separare armi, dati, AI, spawner e bottino in scene e risorse riutilizzabili.
Le formule di vendita di How to Fish non vengono adottate: la pesca di TESTE serve solo al cibo.
Nella Fase 1 non sono implementate armi o pesca: è completato il controller del personaggio.
Nessun asset o codice estratto dai due giochi viene incluso nel pacchetto.
