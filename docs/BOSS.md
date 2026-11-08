# I boss

`bosses/boss_brain.gd` decide tutto sull'host: osserva il giocatore, sceglie il colpo, lo annuncia a terra, applica il danno.
`bosses/boss_fx.gd` è solo grafica e gira uguale su ogni computer (`world.boss_fx`).
Prova: `tests/boss_fight_checks.gd`, con la finestra aperta (foto in `ZOMBIX-HEAD-Boss-Foto/`).

## Regole comuni

- **Avviso prima del colpo.** La macchia a terra si riempie: piena vuol dire adesso. Spostandosi in tempo non si prende nulla.
- **Scoperto.** Dopo i colpi grossi il boss lampeggia e prende il 50% in più.
- **Tre fasi.** Sotto il 66% e il 33% cambia ritmo e aggiunge colpi.
- **Intelligenza.** Prevede dove stai andando. Chi resta lontano si prende salti e cariche, chi gli sta dietro il colpo a giro, chi si nasconde i macigni, chi para il calcio che rompe la guardia. Non ripete lo stesso colpo di fila.
- **Onde e catene si saltano**: colpiscono solo chi è a terra.

## Capomacello: leggi il colpo e punisci

Titano lento nella radura. **Teme il fuoco:** lanciarazzi e lanciagranate fanno 2,6 volte il danno e incendiano il serbatoio; finché brucia, tutto fa +50%. Pistola, mitra, sparachiodi e coltelli lo graffiano appena (55%).

| Colpo | Cosa fa | Come si evita |
|---|---|---|
| Schianto | crepa nel terreno; il lampione resta **piantato 2 s** | spostati e picchia: è il momento d'oro |
| Spazzata | ventaglio largo, da vicino | indietro |
| Colpo a giro | se gli stai dietro troppo | non restare alle spalle |
| Fenditura | fila di spuntoni che corre verso di te | di lato |
| Salto | ti cade addosso, poi parte l'onda | esci dal cerchio, salta l'onda |
| Macigno | contro chi si nasconde o spara da lontano | muoviti |
| Inferno (ferito) | cerchi di fuoco attorno e sotto di te; il fuoco resta | esci e cambia zona |

## Macellaio: fallo schiantare

Duellante veloce in piazza a Borgo Cenere: ti gira attorno. **Teme i fucili a pompa e le canne mozze:** 2,1 volte il danno e, entro 8 m, lo fermano a metà carica o a metà combo. Le frecce gli fanno la metà, le armi leggere il 70%.

| Colpo | Cosa fa | Come si evita |
|---|---|---|
| Combo | tre colpi di mannaia, l'ultimo spacca terra | allontanati tra un colpo e l'altro |
| Carica | linea decisa in anticipo; **contro muro o barricata resta stordito** | mettiti davanti a un muro e scansati all'ultimo |
| Gancio | ti tira da lui, e la mannaia è già in aria | di lato o dietro un riparo |
| Boomerang | la mannaia va e torna; **lui resta disarmato** | scansati due volte, poi picchia |
| Calcio | rompe la parata di chi si ripara | non restare fermo a parare |
| Sangue (ferito) | pozze che rallentano e fanno sanguinare; **dentro si rimette in forze** | staccalo dalle pozze |

## Carceriere: spacca la corazza

Gigante nell'arena della Rocca. **Armi contundenti** (piede di porco, mazza chiodata, martello, piccone): rompono tre piastre, ognuna lo stordisce, l'ultima a lungo. Finché ha la corazza tutto il resto fa il 30%; senza, tutto fa di più.

| Colpo | Cosa fa | Come si evita |
|---|---|---|
| Schianto | crepa e onda | fuori dal cerchio, salta |
| Terremoto | tre o più onde una dopo l'altra | a ritmo |
| Catena | spazza quasi tutto il giro, bassa | salta quando arriva, o stai oltre i 10 m |
| Gabbia | sbarre attorno a te con **una sola uscita**, poi ti salta addosso | esci subito dall'apertura |
| Soffitto (ferito) | sassi dove sei e dove vai | muoviti, leggi i cerchi |
| Fessure (ferito) | il pavimento si apre a fuoco e resta aperto | lo spazio si stringe: stagli lontano |
| Colpo a giro, Salto | come il Capomacello | |

## Zona 2

Il Mago e il Signore delle Teste sono in `docs/ZONA2.md`, sullo stesso cervello.
