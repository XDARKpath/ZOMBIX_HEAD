# Edifici della Zona 1

Modelli originali creati per ZOMBIX HEAD con Blender 5.2. Non provengono da
pacchetti esterni: nessuna attribuzione richiesta.

| File | Uso |
| --- | --- |
| `sheriff_office.gltf` + `.bin` | ufficio dello sceriffo, facciata aperta verso la strada |
| `armory.gltf` + `.bin` | armeria, portico con bancone e pensilina in lamiera |
| `*.blend` | sorgenti modificabili in Blender |

## Cosa contengono

- **Struttura**: zoccolo in pietra, pareti a doghe con rivestimento interno,
  listelli verticali, correnti, coprigiunti angolari, retro cieco senza porta.
- **Tetti**: scandole sfalsate e colmo tondo per lo sceriffo; lamiera costolata,
  macchie di ruggine e comignolo per l'armeria.
- **Portico**: pilastri con base, collarino e capitello, doppi controventi,
  pensilina, gradini con pilastrini laterali e lanterne appese.
- **Insegne**: senza testo, come il resto del gioco. Grande emblema sulla falsa
  facciata e insegna sospesa: stella per lo sceriffo, fucile e ascia incrociati
  per l'armeria.
- **Ufficio**: cella con sbarre e branda, cassaforte, bacheca dei ricercati,
  rastrelliera per fucili, tappeto, panca e cassa.
- **Armeria**: scaffali con fucili e casse, pannello attrezzi, banco display,
  stufa in ghisa con camino, munizioni, botti di polvere, incudine, mola a
  pedale e casse.

## Convenzioni

- 1 unità = 1 metro.
- Origine a terra al centro della piattaforma.
- Facciata aperta verso **+Z** di Godot (in Blender è **-Y**).
- Pianta 9,2 × 6,9 m, pareti 2,9 m, portico fino a z ≈ 9,9.
- Circa 14.100 facce l'ufficio e 13.000 l'armeria, con spigoli smussati.

## Rigenerazione

Dalla radice del progetto:

```bash
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" \
    -b --python tools/build_refuge_buildings.py
```

Lo script riscrive `.gltf`, `.bin` e `.blend`. Per un'anteprima Workbench:

```bash
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" \
    -b --python tools/render_buildings.py
```

## Caricamento in Godot

`world/zona1_rifugio/refuge_set.gd` legge i glTF a runtime con `GLTFDocument`
(`_load_gltf`) e crea collisioni per muri, pilastri e cella: il davanti resta
attraversabile. I file `.gltf`/`.bin` devono essere inclusi anche nell'export
del gioco, perché non passano dalla cache di import dell'editor.
