# Provenienza e conversione

## SurrounDead.Build.21974251.zip

29 modelli GLB convertiti, elencati in art/surroundead/provenance.json.
Il rifugio usa cacciatore, tre zombie, ascia, case, veicoli, pontili, alberi, cespugli e props.
Sette elementi del livello MainMenu mantengono la disposizione relativa originale, con
un'origine traslata e conversione centimetri/metri: casa bruciata, barricate, barile,
due relitti e due parti del bunker. Dati: art/surroundead/map_fragment.json.
Il resto del terreno, il lago e la distribuzione degli elementi sono costruiti per TESTE.
Non sono state importate le intere mappe LongdownValley o PersistentLevel.

UE4SS è stato aggiunto alla sola copia in work con autorizzazione dell'utente.
Ha generato il file usmap; la copia del gioco è stata chiusa dopo l'estrazione.
Conversione con CUE4Parse.CLI; repak per l'ispezione dei pacchetti.
UE4SS e i giochi originali non sono inclusi nel pacchetto TESTE.

Le connessioni texture sono state ricostruite; i colori vertice usati da Unreal come
maschere non vengono moltiplicati per l'albedo. Materiali del terreno, acqua e alberi
sono shader nuovi per Godot. Geometria dei modelli conservata, illuminazione nuova.
Le animazioni compresse originali non sono state convertite con successo: posa,
cammino, attacco, reazioni e caduta sono implementazioni procedurali nuove.

## How to Fish v1.0.10.rar

UnityPy ha recuperato FishingRod, Pike e Boat da sharedassets0.assets.
Le geometrie sono in art/how_to_fish/*.json e sono costruite come ArrayMesh all'avvio.
Materiali semplici ricostruiti. Sono elementi statici sul pontile, non un sistema di pesca.

## Originale di TESTE

Codice GDScript, controller, combattimento, interfaccia, terreno, composizione aggiuntiva,
shader e tre effetti sonori sintetizzati. I diritti dei modelli estratti restano ai rispettivi
titolari: questa conversione locale non attribuisce una licenza di pubblicazione commerciale.
Godot è incluso con il suo file di licenze; nessun nuovo plugin è necessario per giocare.
