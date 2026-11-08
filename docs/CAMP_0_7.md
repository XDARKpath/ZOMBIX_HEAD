# ZOMBIX HEAD 0.7 — Quattro attività attorno al falò

Il gruppo forma un semicerchio aperto verso la camera: il centro resta libero e tutti e quattro
i personaggi sono leggibili. Nuova inquadratura, luce sui volti, riflessi del cielo sul metallo
e antialiasing temporale per rendere meno rumorose le ombre morbide.

- Fumatore in piedi, peso su una gamba, braccio che sale e scende, pausa ed espirazione.
- Katana: superstite su un ginocchio sul lato sinistro del fuoco. Inclina e ruota la lama,
  la sostiene con la seconda mano e la esamina con piccoli movimenti della testa.
- Cuoco seduto sullo sgabello: movimento circolare del cucchiaio nella pentola, mano libera
  vicino alla coscia, respiro e sguardo abbassato.
- Pistola: superstite seduto e chino sul tronco a destra. Passa un panno sulla parte superiore,
  si ferma, solleva e inclina l'arma per controllarla, poi riprende la pulizia.

Corretti il verso di flessione delle dita e i bersagli dei gomiti, prima troppo aperti.
Polsi orientati per ciascuna attività; movimenti sfasati e pause diverse.
Katana, pistola e panno sono oggetti originali creati nel progetto; in questa versione sono
accessori del menu, non nuove armi giocabili. Il gioco mantiene lo stile low-poly dei modelli.

## GitHub e fonti tecniche

Consultati i demo ufficiali Godot per l'uso di bersagli distinti per mani, polsi e gomiti:
https://github.com/godotengine/godot-demo-projects/blob/master/3d/ik/fabrik_ik.tscn
https://github.com/godotengine/godot-demo-projects/tree/master/3d/ik
Il riferimento FABRIK è stato studiato, non installato come addon. Il progetto continua
a utilizzare SkeletonIK3D nativo del motore 4.5.1 incluso. Nessun nuovo plugin aggiunto.
Riferimento per le riflessioni dell'ambiente:
https://docs.godotengine.org/en/4.5/classes/class_environment.html
La texture Kenney già introdotta nella 0.6 conserva licenza e provenienza in art/camp/ATTRIBUTION.md.

## File e verifica

ui/camp/camp.gd: composizione, sedute, camera e luci.
ui/camp/camp_avatar.gd: postura, polsi, dita e cicli delle quattro attività.
ui/camp/camp_props.gd: oggetti, lama curva della katana, pistola e fumo.
tests/camp07_checks.gd: 13 controlli, incluse tutte le skin e 24 campioni di animazione.
tests/menu05_checks.gd: 24 controlli aggiornati del menu, input, skin e apertura lobby.
37 controlli superati; errore massimo mano-bersaglio 3,3 mm, piedi sopra il terreno nei campioni.
La verifica dei bersagli non certifica l'assenza di ogni compenetrazione della mesh:
sono state controllate anche catture reali dei cicli nel renderer Vulkan.

Anteprima: 12 secondi acquisiti dal gioco, 120 fotogrammi a 10 fps, GIF ridotta a 800 x 500.
I log sono in VERIFICA_CAMP_0_7.txt. Le guide precedenti descrivono revisioni storiche.
Cooperativa, missione e combattimento non sono stati ampliati in questa revisione.
