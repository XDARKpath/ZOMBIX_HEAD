# Asset della Fase 3

La Fase 3 conserva gli asset e i limiti di conversione descritti in ASSET_FASE_2.md.
Il totale SurrounDead sale da 29 a 32 GLB, con questi tre nuovi modelli:

- SK_Chr_Soldier_Male_01.glb
- SK_Chr_Contractor_Male_02.glb
- SM_Wep_Melee_HuntingKnife_01.glb

Elenco e provenienza dei modelli: art/surroundead/provenance.json.
Sono state ricostruite le connessioni dei materiali militari alle texture.
Le animazioni originali compresse non sono state convertite: pose e movimento sono procedurali.
Il mondo mantiene il frammento di sette oggetti con disposizione relativa della mappa
MainMenu di SurrounDead; il restante paesaggio è una composizione per TESTE, non una mappa completa estratta.

Di How to Fish è stata ispezionata la gerarchia del menu: host, ingresso, opzioni,
personalizzazione, colori/abiti e posizioni dei giocatori. Questa struttura ha ispirato
il flusso del nuovo menu, implementato in GDScript con falò, skin e impostazioni.
Non sono stati trasferiti codice del menu, servizi Steam o matchmaking del gioco originale.
Barca, canna e luccio già recuperati rimangono oggetti statici dell'ambiente.

Falò, shader delle fiamme, composizione, particelle, interfaccia e posa degli avatar sono
realizzati per TESTE. I modelli estratti restano dei rispettivi titolari; la conversione locale
non fornisce una licenza di pubblicazione commerciale. UE4SS rimane nella copia di lavoro
autorizzata in precedenza e non è distribuito nel pacchetto. Nessun nuovo plugin installato.
