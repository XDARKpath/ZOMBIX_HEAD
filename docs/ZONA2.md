# Confini delle zone e Zona 2, il Mare di Sabbia

Prova: `tests/zone2_checks.gd`, con la finestra aperta (foto in `ZOMBIX-HEAD-Zona2-Foto/`).

## Confini

Le montagne sono nel terreno (`Route.zone_wall`), non muri invisibili: pareti troppo ripide da salire a piedi o in auto.

| Zona | Dove | Si esce da |
|---|---|---|
| Zona 1, Lago Cenere | x < 600, z > -1235 | Valico nord, sulla statale |
| Zona 2, Mare di Sabbia | x < 2300, -3000 < z < -1235 | Valico est, sulla statale |
| Dopo | tutto il resto | ancora da fare |

La statale attraversa le catene solo in quei due punti (`Route.gates()`). `world/zona2/zone_gates.gd` li chiude con un posto di blocco: un cartello dice quali boss mancano, e quando muore l'ultimo salta in aria.

- **Valico nord:** Capomacello, Macellaio, Carceriere.
- **Valico est:** Il Mago, Signore delle Teste.

## Il deserto

`Route.desert(x, z)` dice quanto è sabbia un punto. Lo usano le dune (`terrain.dunes`), i colori (`ground.gdshader`), cosa cresce (cactus, alberi morti, sassi), la luce e la sabbia nel vento (`zone2._atmosphere`).

Gli infetti vagano per le dune: mai dentro Porto Secco, al massimo 7, e spariscono quando restano indietro.

## Porto Secco (tappa 1)

Un porto senza mare: case di mattoni, tende, container, barche arenate. Dopo la liberazione del presidio è zona sicura.

- **Sceriffa Mira:** dà la missione, spiega come battere i boss e compra le teste con V, come lo sceriffo di Lago Cenere. +800 crediti alla fine.
- **Bazar di Porto Secco:** lo ZXShop della tappa 1, con balestra, fucili lunghi, pompa, piccone e martello.

## Il Mago: il veleno del Cratere

Sculta che galleggia nel Cratere, a nord. Scappa se ti avvicini e si combatte a distanza. Il Cratere ha pilastri dietro cui ripararsi.

**Velo acido:** finché c'è, tutto fa il 20%. **Arco, balestra, fucile a leva, fucile di precisione e revolver** lo strappano per 7 secondi; poi tutto fa male e questi tiri fanno 1,8 volte.

| Colpo | Cosa fa | Come si evita |
|---|---|---|
| Dardi | ventaglio che cade dove stai andando | muoviti di traverso |
| Pioggia | cerchi attorno a te, la terra resta avvelenata | esci subito dal centro |
| Sparizione | se le sei addosso riappare lontano, lascia una pozza | tienila con un tiro |
| Onda | anello acido che si allarga | salta |
| Tempesta | 3 secondi ferma: **un colpo la interrompe e la stordisce** | se finisce, il suolo è tutto veleno |
| Covata (ferito) | sputatori attorno | ammazzali o scappa |

## Il Signore delle Teste: il re del Cimitero

Veloce, nel Cimitero delle Barche a ovest, tra scafi e costole di balena.

**Corona:** tre teschi che gli girano attorno; tutto fa il 35%. **Le lame** (ascia, machete, spada, katana, coltello) li tagliano uno a uno, e ognuno lo stordisce un attimo ma lo rende più veloce del 15%. Senza corona le lame fanno 1,35 volte.

| Colpo | Cosa fa | Come si evita |
|---|---|---|
| Scatti | tre di fila, ognuno con la sua linea | scansati ogni volta |
| Combo | tre colpi, sanguini | allontanati |
| Salto | ti cade addosso con onda | esci dal cerchio, salta |
| Teste | cadono e scoppiano un attimo dopo | leggi i cerchi |
| Colpo a giro | se gli stai dietro | non restare alle spalle |
| Calcio | rompe la parata | non restare fermo a parare |
| La corte (ferito) | corridori attorno | gestiscili |
