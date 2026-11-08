# ZOMBIX HEAD 0.9 — Fumo e fucile da precisione

La pistola del personaggio sul tronco è sostituita da un fucile da precisione originale,
con ottica, canna lunga, calcio, caricatore, leva dell'otturatore e bipiede ripiegato.
La mano sinistra sostiene la parte anteriore, la destra pulisce il calcio con il panno.
Durante la pausa il personaggio alza leggermente il fucile e lo osserva. Le dimensioni
e i bersagli delle mani sono adattati all'arma lunga, appoggiata davanti alle ginocchia.
È un accessorio della scena del menu, non una nuova arma giocabile.

Il fumo usa un nuovo shader: la luminosità della texture controlla la trasparenza,
eliminando la parte scura che prima poteva coprire il viso. Le particelle sono più piccole,
compaiono e svaniscono gradualmente e durano meno. L'espirazione dura 0,8 secondi,
parte dal riferimento della testa e si muove verso l'esterno invece di accumularsi sul volto.
Il filo di fumo dalla brace sale indipendentemente dalla rotazione del polso.
Anche il vapore del pollo utilizza la nuova trasparenza.

File principali: ui/camp/smoke.gdshader, camp_props.gd, camp_avatar.gd.
La texture Kenney conserva provenienza e licenza in art/camp/ATTRIBUTION.md.
Nessun nuovo plugin o asset esterno scaricato per questa revisione.

## Verifiche

19 controlli delle attività su tre skin e 28 campioni del ciclo; presa dell'arma lunga,
contatto del panno, emissione e direzione dell'espirazione inclusi. 24 controlli del menu.
43 controlli superati. Catture reali Vulkan e anteprima di 14 secondi a 10 fps.
Le verifiche dei punti dello scheletro non certificano ogni vertice delle mesh.
Il progetto mantiene lo stile low-poly. Campo, 4x4, pollo e katana della 0.8 conservati.
Log: VERIFICA_CAMP_0_9.txt. --verify-camp esegue camp09_checks.gd.
