# ZOMBIX HEAD — 0.16

Survival in prima persona, solo o cooperativa fino a quattro giocatori con un host.

## Lavorare insieme (GitHub)

**Aprire il gioco.** Serve Godot **4.5.1** (versione standard, non .NET):
scaricalo da godotengine.org. Clona il repo, apri Godot, *Importa* e scegli
`project.godot`. Il primo avvio importa gli asset e richiede qualche minuto.

```
git clone https://github.com/XDARKpath/ZOMBIX_HEAD.git
Godot_v4.5.1-stable_win64.exe --path ZOMBIX_HEAD
```

**Lanciare i test.** I test sono script in `tests/`. Quelli senza foto girano
senza finestra; quelli che fanno foto o video (`*_capture`, `*_photos`) ne
richiedono una. Se è un clone nuovo, prima importa una volta gli asset:

```
Godot_v4.5.1-stable_win64.exe --headless --path . --import
Godot_v4.5.1-stable_win64.exe --headless --path . -s res://tests/zx_shop_checks.gd
```

Ogni riga `FAIL` è un controllo fallito.

**Regole di lavoro.**
- Non si lavora su `main`: per ogni modifica crei un branch
  (`git switch -c nome-modifica`), poi apri una Pull Request e un altro la guarda prima del merge.
- Arte e suoni solo **originali o CC0**. Ogni asset nuovo va annotato in
  `docs/ART_LICENZE.md` o `docs/AUDIO_LICENZE.md`.
- Il multiplayer è **host-autoritativo**: decide l'host (danni, bottino,
  acquisti); i client mandano richieste e mostrano il risultato.
- Non entrano nel repo: `.godot/`, le copie `_backup_*`, `_da_eliminare/`, video e foto dei test.

## Avvio

Estrai tutto lo ZIP e apri **AVVIA_ZOMBIX_HEAD.cmd**. Il primo avvio importa i
contenuti e può richiedere un po' di tempo. Godot 4.5.1 è incluso nella cartella
runtime; non occorre installare un editor o un plugin. Per il renderer alternativo
usa AVVIA_ZOMBIX_HEAD_COMPATIBILE.cmd. MODIFICA_ZOMBIX_HEAD.cmd apre il progetto.

## Natura, acqua e strada nella 0.15

Erba rifatta in **world/zona1_rifugio/grass.gdshader**: ciuffi a sei fili con
radice scura e punta chiara, tinta diversa per ciascun ciuffo, vento a raffiche
e trasparenza in controluce. Il sottobosco usa il pacchetto Stylized Nature
MegaKit: felci, trifogli, fiori, funghi, cespugli, pietre e ciottoli, distribuiti
con densità diverse fra prato, sentiero e riva.
Il lago ha un nuovo shader (**water.gdshader**): le increspature ora sono onde
vere che inclinano la normale, quindi il riflesso del sole si muove sulla
superficie invece di restare una striscia piatta; niente più reticoli in
lontananza, fresnel, schiuma irregolare sulla battigia e acqua più scura di
taglio. La sponda opposta (**world/zona1_rifugio/landscape.gd**) è una cresta
di colline con normali morbide e sfumatura di colore per quota, non più picchi
isolati; il pontile appoggia sull'acqua. La strada della campagna
(**world/campaign/terrain.gd**) è un nastro d'asfalto continuo con banchine
di ghiaia, tratteggio centrale, guardrail, lampioni spenti, relitti, case
bruciate e tende lungo il percorso. Il terreno usa normali continue calcolate
dal rilievo (niente facce piatte a scacchiera sui pendii) e uno shader con
rumore a più ottave per chiazze d'erba, terra battuta e secche.

## Zona 1 verde nella 0.17

La Zona 1 è un bosco con **due soli edifici**: l'ufficio dello sceriffo a est e
l'armeria a ovest, un po' più avanti lungo la strada della campagna. Sono modelli CC0 di
KayKit City Builder Bits (`art/kaykit_city/`) con portico, banco, stella e
lampade accese; tutto il resto è stato tolto: niente case, officina, deposito,
torre dell'acqua, palazzi di sfondo, auto abbandonate o semafori.
La mappa è molto più grande di prima e **non ha una strada unica**: da
**world/zona1_rifugio/roadnet.gd** parte una rete di strade locali che si
diramano nel bosco (tronco a sud, rami a ovest e a est, vicoli ciechi). I tre
ricambi sono sparsi sui rami, quindi bisogna girare per trovarli. Anche le
**arene dei custodi** stanno in fondo ai vicoli ciechi: si scoprono esplorando,
e l'esca accesa fa arrivare il custode. La statale resta solo come uscita verso
la Zona 2 e come collegamento con il paese.

Il bosco è molto più fitto: **world/zona1_rifugio/landscape.gd** aveva un filtro
che scartava ogni albero della radura; ora pianta centinaia di pini attorno ai
due uffici, e **refuge_set.gd** ne aggiunge altri fino ai margini. L'erba
(**atmosphere.gd**, **grass.gdshader**) è più alta, più fitta e di un verde
pieno, senza chiazze secche e con un vento morbido. Sono spariti i fiori, i
trifogli rossi, i funghi arancioni e le particelle che volavano nell'aria: la
zona è **completamente verde**, senza macchie rosse.

Niente più cartelli con i nomi dei luoghi: né tabelle sulle facciate, né
cartelli direzionali, né etichette fluttuanti sui mercanti o sulle tappe. Si
capisce dove si è guardando gli edifici: la stella appesa al portico è
l'ufficio dello sceriffo, le rastrelliere con i fucili sono l'armeria. Anche il
segnalatore che indicava la missione sullo schermo è stato tolto: la distanza
dal ricambio più vicino si legge nel GPS (G).

## Arredi e sottobosco della Zona 1

I due uffici non sono più isole. Panchine, idranti, cassonetti, sacchi di
rifiuti, casse impilate e lampioni accesi vengono dai pacchetti CC0 KayKit City
Builder Bits e stanno ai lati dei portici e sul marciapiede, mai davanti alle
porte né nel raggio delle esche. Le arene dei custodi hanno stendardi rossi su
intelaiatura e casse impilate accanto ai barili (KayKit Dungeon): il centro
resta libero per il custode e per il braciere. Il sottobosco mescola cespugli e
pietre KayKit Forest con felci e piante Quaternius, fuori da prato, strada e
arene; niente fiori, niente macchie rosse, e nessuna collisione aggiunta alla
vegetazione bassa, così i percorsi restano navigabili.

## I tre custodi della Zona 1

La Zona 1 non si chiude con i soli ricambi: dopo la riparazione del 4×4 servono
tre boss. Sono scheletri animati **CC0** del pacchetto KayKit (95 clip
ciascuno), ognuno con un'arena segnata da torce su palo, casse e barili.

| Custode | Dove | Comportamento |
|---|---|---|
| CAPOMACELLO | cortile dell'officina | lento e pesante, rotazione ad area ogni 7,5 s, furia al 50% |
| IL MAGO | torre dell'acqua | tiene la distanza, dardi magici, teletrasporto se lo stringi, due rinforzi al 60% |
| SIGNORE DELLE TESTE | strada nord | veloce, lancia teste, chiama la corte sotto il 45% |

Ognuno ha la barra vita in alto e una sopra la testa; testa 1,8×, gambe 0,62×.
L'obiettivo diventa "ABBATTI I TRE CUSTODI" e la partenza per la Zona 2 resta
bloccata finché non sono tutti a terra; poi il GPS riprende. Ricompense: 150,
175 e 200 crediti, più 4, 3 e 5 teste. Modelli in `art/kaykit_skeletons/`, arredi
delle arene in `art/kaykit_dungeon/`.

I custodi non aspettano in piedi: ognuno dorme finché non accendi l'esca del
braciere nella sua arena (E). Lo sceriffo, seduto sotto il portico con la
sigaretta, al primo incontro spiega che sei un traveler e che le teste si vendono
a 25 crediti l'una. La testa si stacca solo con un colpo d'ascia caricato al
collo; il braccio destro è modellato per intero nella visuale in prima persona.
Il prato usa erba, fiori e cespugli CC0 che ondeggiano con lo stesso vento, e i
palazzi di sfondo sono due invece di cinque.

## Licenze

Il 1 novembre 2026 sono stati rimossi i modelli estratti da SurrounDead e i
pacchetti Synty non acquistati. Il 6 e 7 novembre 2026 sono usciti anche il cast
Synty Generic, un coltello Synty rimasto sotto altro nome e tutti i kit senza
licenza, rifatti da zero con **tools/castle_kit**. Lo stato di ogni cartella è in
**docs/ART_LICENZE.md**, le attribuzioni in **docs/CREDITI.md**.

## Un solo bosco

La vegetazione usa un'unica famiglia di alberi: i **pini CC0** di
`art/nature/` e `art/kaykit_forest/`, con lo stesso shader delle foglie. Sono
esclusi gli alberi scheletrici e le chiome tonde del vecchio kit, sia dal
terreno della campagna (**world/campaign/terrain.gd**) sia dalle periferie del
rifugio (**world/zona1_rifugio/refuge_set.gd**). Cespugli e pietre restano come
sottobosco.

## Sopravvissuti

I giocatori usano **SM_ZX_Player** (`art/zx_player/`) con le sue skin, infetti,
boss e NPC i modelli di `art/zx_infected/`: tutti passano da
**art/survivor_visual.gd**. Se un modello manca, **art/placeholders.gd** costruisce
il manichino.

## Armi, mani e cadaveri

L'arma in prima persona (**player/first_person_weapon.gd**) è impugnata a una
mano: il manico passa nel tunnel delle dita calcolato dalle ossa della mano
(**ui/camp/source_hands.gd**, `grip_frame()`), non più al polso, con il filo
rivolto in avanti. L'ascia, il coltello e la pistola si agganciano tutti allo
stesso punto di presa; la pistola viene raddrizzata perché il modello ha la
canna inclinata. La visuale oscilla con il mouse, respira da ferma, oscilla
camminando e si inclina in corsa. Il colpo dell'ascia è guidato da tre
direzioni (riposo, carica sopra la spalla, discesa in avanti) invece che da
angoli euleriani: la lama resta nello schermo per tutta la discesa, con un
leggero ritardo che dà peso al colpo. Il coltello ha un fendente rapido e la
pistola rinculo e lampo di volata. La camera ha bob,
cedimento all'atterraggio, inclinazione laterale e FOV che si apre in scatto.
Il giocatore in terza persona muove bacino, ginocchia, braccia e busto in modo
coordinato, raccoglie le gambe in salto e si piega in attacco.
I cadaveri sono "gelatina" stile GTA: al decesso gli arti si abbandonano con
rimbalzi smorzati, il corpo si schiaccia e oscilla, e ogni nuovo colpo lo fa
sobbalzare di nuovo. Il collo reciso stacca la testa, il resto resta molle.

## Zaino a slot e armi a terra

Lo zaino funziona a **slot**: si parte con quattro posti e ogni arma ne occupa
uno. Dall'armeria si compra **+1 SLOT** (60 crediti il primo, poi 40 in più per
ogni slot aggiuntivo, fino a otto). Con lo zaino pieno non si comprano altre
armi finché non si libera un posto.

Con **X** si lascia a terra l'arma equipaggiata: resta lì, si può raccogliere con
**E** e nel frattempo si passa all'arma successiva. Non si può restare disarmati:
serve almeno un'arma. L'HUD mostra `SLOT n/max` accanto a teste e crediti. Lo
zaino viene salvato nel checkpoint insieme alle armi possedute.

Lo **sceriffo** ora è seduto di tre quarti, con una gamba sotto la sedia, il
braccio destro appoggiato al tavolo e la sigaretta vicino al viso; l'**armaiolo**
ha una posa diversa, in piedi dietro il banco con entrambi gli avambracci
appoggiati e la testa alzata verso chi arriva. L'ascia in prima persona ha una
lama forgiata a scure con filo lucido, occhio in acciaio e impugnatura in cuoio;
in prima persona si vede solo l'avambraccio, con manica conica, polsino in
cuoio, risvolto e guanto arrotondato (palmo e falangi a capsula), con un leggero
respiro nel movimento.

## Infetti nella 0.14

L'animazione degli infetti non usa più le clip umane. Ora la fanno le 21 clip di
**art/zombie_motion/zombie_motion.res**, applicate da **art/infected_motion.gd**
(vedi docs/BATCH_ZOMBIX.md, pacchetto 0.14). Prima la posa era procedurale. Camminavano curvi con un passo claudicante, una gamba
quasi rigida che trascina e le braccia penzolanti; l'attacco è un'artigliata
frontale con entrambe le braccia, non più un urto con il busto. Se vengono
colpiti alle gambe cadono e **strisciano** a pancia in giù tirandosi con le
braccia. I colpi sono localizzati: **collo** = testa staccata subito, **testa** =
danno pesante, **gambe** = strisciamento. Se muoiono con la testa ancora attaccata
si può staccarla con ascia o coltello e raccoglierla. Ci sono cinque collassi
diversi (indietro, avanti, rotolamento, in ginocchio, di fianco) più la posa da
strisciante. Quattro tipi: Errante, Corritore, Corazzato ed Elite, con vita,
velocità e corporatura diverse.

## HUD e dialoghi nella 0.19

Lo zaino ora è una **hotbar in basso al centro**: uno slot per arma (fino a otto),
icona disegnata per ascia, coltello e pistola, numero dello slot, arma in mano
con bordo dorato e slot vuoti con la crocetta. Il conteggio `ZAINO n / m` sta
sopra la barra, quindi la riga dei comandi non lo ripete più.

Vita e fiato hanno barre più spesse, arrotondate e **a segmenti**, con riflesso
superiore, numero grande a destra e bordo rosso pulsante sotto il 30% di vita;
il fiato usa l'oro dell'interfaccia. Le barre scendono con un breve ritardo e
mostrano una **scia rossa** del danno appena subito. Il mirino si apre con la
corsa e la carica, il radar ha nord, cono di vista e portata, e i prompt
compaiono su una targa scura larga quanto il testo, con il tasto **E** in un
badge dorato quando l'azione è un'interazione. In alto a destra scorre un
**feed degli abbattimenti** (arma usata, sfumatura in quattro secondi), la
scritta `VITA CRITICA` pulsa sotto il 30% e il fiato esaurito lampeggia. Con la
pistola a due colpi o meno il nome dell'arma diventa arancione.

L'HUD tattico usa pannelli smussati e una palette unica: **VITA** e **FIATO**
sono barre a segmenti inclinati con scia del danno, lo **ZAINO** ha slot con
cornice dorata e icone vettoriali, e la **minimappa** circolare mostra curve di
livello, punti cardinali, blip dei nemici e una ghiera metallica. Il prompt
d'azione separa il tasto **E** dal testo.

Il negozio dell'armaiolo usa lo stesso linguaggio visivo: sigillo AR, borsa in
testa, schede con nome, prezzo e descrizione dell'arma, scheda zaino e pulsante
di uscita; le schede non acquistabili si spengono da sole.

Il dialogo dello sceriffo è un pannello RPG in basso, con **ritratto vettoriale**
affiancato al testo. Il ritratto è disegnato proceduralmente in
**ui/sheriff_portrait.gd**: testa squadrata, occhiali scuri, capelli chiari,
cravatta e stella, senza texture. Il pannello è charcoal semitrasparente con
una lama d'ambra, nome, ruolo e quotazione delle teste. Sotto la battuta ci sono
tre risposte orizzontali con stati normal, hover ambra e pressed teal; si
selezionano col mouse oppure con **1–3**. `E` continua il discorso, `Esc` lo
chiude. Il pannello è in **ui/sheriff_dialogue.gd**, resta sopra il mondo e
lascia visibile il volto del modello 3D dello sceriffo. La cattura aggiornata è
**ZOMBIX-HEAD-0.16-Foto/19-sheriff-dialogo.png**.

## Interni corazzati

L'ufficio dello sceriffo e l'armeria hanno ricevuto un secondo passaggio di
arredo, sempre con geometria chunky, facce piatte e materiali a tinta unita.
Nell'ufficio la **cella** non è più una gabbia appoggiata al centro: è incassata
in una muratura a conci con malta scura, soglia, piedritti, architrave e chiave
d'arco. Una **finestra alta e sbarrata** nella pietra porta un fascio caldo nella
cella; il resto della stanza ha la scrivania rinforzata con angoli in ferro, una
**radio** con antenna e spie, mappe, documenti, due classificatori e quattro
manifesti dei ricercati (due per parete), senza testo.

Nell'armeria il banco è diventato un vero bancone corazzato: piano più spesso,
fronte a doghe, fasce in ferro, bulloni e stella geometrica. Le pareti hanno
rastrelliere con fucili e armi da mischia, due giubbotti tattici, casse di
munizioni impilate, un pannello attrezzi, travi e montanti rinforzati. Una striscia
neon ambra illumina la parete laterale. Le finestre
laterali hanno sbarre; nell'ufficio dello sceriffo una luce spot
disegna ombre profonde sul pavimento. L'armeria resta senza
fascio volumetrico e senza spot. L'occlusione ambientale è stata alzata a 1,4 m e
1,5 di intensità per far leggere gli incastri.

Le interazioni con sceriffo e armaiolo, il dialogo, i salvataggi, l'hotbar e le
collisioni esistenti non sono cambiati. Le catture sono in
**../screenshots/interiors-cutaway.png** (cutaway affiancato) e in
**../ZOMBIX-HEAD-0.16-Foto/** (viste in prima persona).

## Pulizia e strada nella 0.18

Sono sparite le cose che restavano sospese: le due lanterne a mezz'aria vicino
ai portici e i pali della luce con la testa luminosa staccata dal braccio. Le
lampade dei portici ora hanno asta e coperchio, quindi si vede da dove pendono.
Nelle arene i barili restano al loro posto; casse e stendardi sono arredi
laterali appoggiati a terra, non bauli al centro.

La strada è stata ricostruita come un nastro unico: niente più triangoli
mancanti o pezze di prato sull'asfalto, i lati seguono la curva con vertici
raccordati, la mezzeria sta sopra la carreggiata e lo sfondo è un asfalto scuro
esplicito invece del color crema dato dai soli vertex color sotto il sole caldo.
I rami locali nascono dal **ciglio** della statale, non dal centro, con uno
sbocco rastremato: non tagliano più l'erba con una toppa triangolare.

## Sceriffo, armeria ed elettricità

Lo sceriffo aspetta sotto il portico del suo ufficio, a est della strada, e paga
**25 crediti per ogni testa**. Avvicinati: il prompt mostra quante teste hai e
quanto vale il conto, E incassa tutto in una volta. Dall'altra parte della
strada l'armaiolo vende la **pistola compatta (125 CR)** e il **military knife
(50 CR)**. L'ascia è l'**axe_2handed** KayKit (CC0), impugnata a due mani; i
fendenti alternati sono schiacciata, diagonale e strisciata. Tasti 1/2/3 per
impugnare ascia, coltello o pistola, R per
ricaricare. Gli arredi di armeria e ufficio sono solidi: scaffale, casse, classificatori, rastrelliera e stufe non si attraversano. Solo questi due cortili hanno corrente: lampioni accesi, interni
illuminati, il resto del villaggio al buio.

Ogni ricambio raccolto alza l'allerta di un livello (massimo tre): arrivano più
infetti e con tipi più resistenti, mai dentro l'area illuminata.

## Strada per la Zona 2

Il primo tratto è una strada a tornanti con due **sbarramenti** presidiati:
avvicinarsi richiama gli infetti, eliminarli tutti e premere E apre il passaggio.
Il 4×4 può raggiungere la tappa successiva solo con entrambi gli sbarramenti
liberati. Il motore è nel bunker a est, indicato dalla colonna verde.

## Rifugio aggiornato nella 0.13

Due case a due stanze, arredate ed esplorabili, officina aperta e deposito carburante.
Batteria nella casa del guardiano, cinghia sul banco dell'officina, tanica sul pallet
nel deposito. Tre ambienti distinti da esplorare prima di riparare il 4×4.
Edifici e arredi sono segnaposto a blocchi generati da **art/placeholders.gd**,
pronti per i moduli CC0 definitivi.
Gli zombie non usano più le clip umane: li anima `art/infected_motion.gd` con le
21 clip di `art/zombie_motion/zombie_motion.res` (camminata trascinata, corsa, attacchi, colpi, morti, strisciamento).
Foto reali della scena in **ZOMBIX-HEAD-0.14-Foto/** (01 area, 02 sceriffo,
03 infetti, 04 teste, 05-07 strada, lago e curva, più le viste in prima persona
con ascia, coltello, pistola e colpo d'ascia). Dettagli in
**ZOMBIX_HEAD/docs/RIFUGIO_0_13.md**. Nessun plugin aggiunto.

## Nuova campagna di prova

Otto tappe GPS, sette collegamenti per circa 12,78 km di strada. Le distanze fra
tappe consecutive vanno da 1,45 a 2,09 km. Nel primo livello recupera batteria,
cinghia e carburante con **E**, poi ripara il 4×4 restando vicino per otto secondi.

E sale/scende da fermo. Il primo a salire guida con WASD. Gli altri tre occupano
i posti passeggeri. **G apre il GPS**. Raggiungete la prossima tappa e fermatevi
con tutta la squadra a bordo. Liberate il presidio dagli infetti e usate il relay
per rivelare la coordinata successiva. Le coordinate future rimangono bloccate.

A piedi: WASD, mouse, Shift per correre, Spazio per saltare, Ctrl per abbassarsi.
Click attacca; tieni premuto per caricare. Esc apre il menu. Il GPS non mette in
pausa il mondo e in cooperativa nemmeno il menu ferma la partita.

Controlli automatici sul progetto finale: `--verify-zombix` (42 controlli),
`--verify3` (22), `--verify-menu` (24) e `--verify-camp` (32). Tutti verdi.

Le sette zone successive sono presidi provvisori: temi, missioni e ambienti
specifici verranno progettati con l'utente. Non sono otto livelli già rifiniti.
## Edifici della Zona 1

L'ufficio dello sceriffo e l'armeria sono due modelli originali creati in
Blender 5.2 e caricati da `art/buildings/`. La struttura è più ricca: zoccolo
in pietra, doghe e listelli verticali, correnti e coprigiunti, tetto in
scandole sfalsate per lo sceriffo e lamiera costolata per l'armeria, travi a
vista, controventi del portico, lanterne appese; il retro di entrambi gli
edifici è una parete cieca, senza porte.

All'interno l'ufficio ha una **cella con sbarre** e branda, cassaforte,
bacheca dei ricercati, rastrelliera per fucili, tappeto e panca; l'armeria ha
rastrelliere con armi alle pareti, pannello attrezzi, stufa in ghisa con camino,
casse di munizioni e botti di polvere. La **scrivania**
ha cassetti, una credenza alle spalle e oggetti da ufficio; la **sedia dello
sceriffo** ha braccioli, doghe e sputacchiera. Il **banco del negozio** è contro la parete di fondo, con cassetti, cassa
e scaffali alle pareti; l'armaiolo resta tra il muro e il piano, così dall'ingresso si vede tutto il negozio. Le insegne
restano senza testo: grande emblema sulla falsa facciata e insegna sospesa
(stella per lo sceriffo, fucile e ascia incrociati per l'armeria).

La facciata verso la strada resta completamente aperta e attraversabile; le
collisioni coprono muri, pilastri e la cella. Misure: pianta 9,2 × 6,9 m,
pareti 2,9 m, origine a terra al centro. Sorgenti `.blend` e istruzioni in
**ZOMBIX_HEAD/art/buildings/README.md**; rigenerazione con
**tools/build_refuge_buildings.py**.

## Salvataggio

L'host salva un checkpoint in **user://save_slot_1.json** ogni volta che entra in
una nuova tappa o raccoglie un ricambio (**autoload/save_manager.gd**). Tiene
posizione, ricambi, tappa e zona, crediti, teste, armi, stato del 4×4,
sbarramenti e custodi. Nel menu principale, se esiste un salvataggio, compare
**CONTINUE**: riprende la partita dal checkpoint con tutta la squadra. In
cooperativa fa fede lo stato dell'host; una nuova partita senza CONTINUE
cancella il vecchio slot.

## Contenuti aggiunti

68 modelli Nature MegaKit nei settori del terreno. Le armi sono segnaposto
procedurali — ascia, coltello e pistola — con gli stessi marker di presa
(`GripMain`, `Muzzle`, `Magazine`); la pistola ha caricatore, ricarica e mani in
prima persona a 20 falangi. Archi, balestra, frecce, dardo e le animazioni
ritargettizzate sono stati rimossi insieme ai modelli protetti. Il bridge Tripo
per 3ds Max non serve al gioco e non è stato installato.

Menu al falò, personaggi e armi già sistemati nelle versioni precedenti conservati.
PROVA_MOVIMENTO_ZOMBIX_HEAD.cmd mantiene disponibile il campo di prova dei controlli.

Guida completa e limiti: **ZOMBIX_HEAD/docs/CAMPAGNA_0_12.md**.
Collegamento host/client: **ZOMBIX_HEAD/docs/ONLINE.md**.
Le prove con quattro processi sullo stesso PC non sostituiscono un test Internet.
