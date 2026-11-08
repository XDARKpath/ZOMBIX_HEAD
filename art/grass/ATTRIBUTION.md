# Erba GPU — origine e licenza

Fonte: https://github.com/AndreVallestero/godot-grass-shader (ramo `main`)
Licenza: MIT, © 2022 Andre Vallestero — testo completo in `LICENSE.txt`.
La tecnica (particelle GPU disposte a griglia attorno alla camera) deriva dal tutorial
sull'erba di Bastiaan Olij, citato nello shader originale.

File presi:
- `grass-diffuse.png` → `grass_diffuse_1024.png`, ridotto da 4096 a 1024 px (stessa immagine, canale alfa conservato).
- `grass-particle.gdshader`, `grass-spatial.gdshader` → copie di riferimento `original_*.gdshader.txt` (Godot 3).

Aggiornamento: il ciuffo disegnato ora è `art/nature/Grass_Common_Short.gltf` (Quaternius, CC0)
con `world/grass/grass_lowpoly.gdshader`; la texture MIT resta per riferimento. La griglia GPU è sempre il porting MIT.

Porting a Godot 4 (`world/grass/`): lo shader particelle usa `process()` al posto di `vertex()`,
la posizione segue l'altezza reale del terreno (griglia di 8 m identica alla mesh di terrain.gd),
una maschera esclude strade, edifici, acqua e chiazze di terra; lo shader del filo aggiunge vento,
tinta per ciuffo e scurimento alla base. Il resto è codice nuovo di ZOMBIX HEAD.
