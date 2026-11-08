# Verifica Fase 1

Godot 4.5.1.stable.official.f62fdbde1 su Windows. Importazione completata senza errori.
29 controlli di integrazione passati nel motore, con simulazione fissata a 60 passi/s.
Questa impostazione rende le prove ripetibili: non misura il framerate ottenibile sul PC.

```
Godot Engine v4.5.1.stable.official.f62fdbde1 - https://godotengine.org

PASS  Il personaggio appoggia sul terreno
PASS  Vita iniziale piena
PASS  Cammino misurato: 3.67 m
PASS  Diagonale senza bonus velocità: 3.78 m
PASS  La corsa è più veloce: 5.94 m
PASS  La corsa consuma stamina
PASS  Stamina recuperata dopo la pausa
PASS  Esaurimento senza stamina negativa
PASS  Schivata negata se la stamina non basta
PASS  Input schivata e costo stamina
PASS  I-frame iniziali bloccano il danno
PASS  L'invulnerabilità termina prima del rotolamento
PASS  Danno nuovamente attivo dopo gli i-frame
PASS  Cooldown impedisce schivate consecutive immediate
PASS  Movimento relativo allo yaw della camera
PASS  Il muro posteriore della casa blocca il giocatore
PASS  SpringArm avvicina la camera davanti al muro: 1.95 m
PASS  La rampa permette di entrare sul portico senza salto
PASS  Il giocatore entra all'interno del rifugio
PASS  Il pontile è raggiungibile a piedi e sostiene il giocatore
PASS  La barra vita è dentro la finestra
PASS  Il menu dà il focus al pulsante Riprendi
PASS  La pausa blocca il movimento
PASS  La zona rossa infligge danni reali
PASS  Danni negativi rifiutati
PASS  La morte azzera la vita senza valori negativi
PASS  Respawn con vita e stamina ripristinate
PASS  Respawn nel punto previsto
PASS  Recupero dopo caduta fuori dal mondo
FASE 1: PASS — 0 errori

```

Rendering reale verificato con OpenGL 3.3 Compatibility su NVIDIA GeForce RTX 3050 Laptop GPU.
Immagini del mondo e del menu pausa catturate dal motore e ispezionate. La prima verifica
visiva ha rilevato barre HUD fuori schermo: gli ancoraggi sono stati corretti, ricontrollati
visivamente e inclusi nella verifica automatica della finestra.

Non sono stati provati un gamepad fisico, una sessione manuale prolungata, un'ora di stress
o PC medio-bassi. I binding gamepad sono configurati; questi controlli restano nella checklist utente.

Ripetizione: motore con `--headless --fixed-fps 60 --path <cartella TESTE> -- --verify`.
