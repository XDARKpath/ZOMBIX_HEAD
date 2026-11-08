"""BORGO CENERE - kit originale (fatto da zero, nessun asset di terzi) per il villaggio di ZOMBIX HEAD.
Stile low-poly a colori piatti con atlas di palette (come gli altri asset ZX). Stesse misure e stessi punti d'origine
dei pezzi modulari che villaggio.gd usava prima, così il codice del villaggio resta uguale:
  muri 3 x 3 m (x 0..3, y 0..3, spessore centrato su z=0, esterno verso +Z), pavimento 3 x 3 (z -3..0),
  tetto a falde 3 x 10 m (x -3..0, z -9.5..0.5, colmo a z = -4.5), tetto piano 3 x 3, tettoie, porte, arredo, auto, tende...
Si scrive in coordinate Godot (Y su, Z verso l'esterno): push(rot=(90,0,0)) converte nello spazio di Blender (Z su).
Uscita: art/zx_borgo/SM_<nome>.glb"""
import sys, math, random
sys.path.insert(0, '/home/claude/zx')
sys.path.insert(0, '/home/claude/src/Survivor_Operative/source/blender_scripts')
import bpy
import lib
import kit

EXTRA = {
    'brick_borgo': (132, 74, 60), 'brick_borgo_dark': (108, 60, 50), 'brick_borgo_light': (150, 88, 70), 'mortar_borgo': (150, 140, 126),
    'brick_light': (172, 92, 70), 'brick_burnt': (84, 52, 44), 'soot': (44, 40, 38),
    'plaster_borgo': (196, 182, 150), 'plaster_borgo_dark': (160, 146, 118),
    'metal_tan': (182, 158, 118), 'metal_tan_dark': (146, 124, 90), 'metal_green': (96, 116, 100), 'metal_green_dark': (70, 88, 76),
    'roof_grey': (78, 78, 74), 'roof_grey_dark': (58, 58, 56), 'roof_grey_light': (98, 96, 90), 'tar': (40, 40, 40),
    'traffic_orange': (226, 110, 40), 'awning_red': (150, 56, 46), 'awning_cream': (214, 196, 156),
    'car_blue': (82, 104, 128), 'car_blue_dark': (60, 76, 94), 'car_red': (150, 62, 48), 'police_white': (210, 210, 204),
    'tyre': (30, 30, 32), 'tarp_green': (88, 104, 72), 'tarp_green_dark': (68, 82, 56), 'tent_orange': (190, 110, 52),
    'water_blue': (60, 110, 160), 'water_blue_dark': (44, 84, 124), 'puddle': (50, 62, 66),
}
for _k, _v in EXTRA.items():
    if _k not in lib.PALETTE:
        lib.PALETTE[_k] = _v
        lib.NAMES.append(_k)
assert len(lib.NAMES) <= 256, len(lib.NAMES)

OUT = '/home/claude/game/art/zx_borgo'
import os
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
kit._MATS.clear()
kit.write_palettes(f'{OUT}/T_Borgo_Palette.png', f'{OUT}/T_Borgo_Emission.png')
mats = kit.materials(f'{OUT}/T_Borgo_Palette.png', f'{OUT}/T_Borgo_Emission.png')
pieces = {}


def mk(name, seed=1):
    k = kit.K()
    k.push(rot=(90, 0, 0))          # da qui in poi: coordinate Godot
    k.rnd = random.Random(seed)
    pieces[name] = k
    return k


def B(k, x0, y0, z0, x1, y1, z1, col):
    k.boxr(min(x0, x1), min(y0, y1), min(z0, z1), max(x0, x1), max(y0, y1), max(z0, z1), col)


def rects(x0, x1, y0, y1, holes):
    """rettangolo meno i buchi -> lista di rettangoli (griglia sulle coordinate dei buchi)"""
    xs = sorted({x0, x1, *[h[0] for h in holes], *[h[1] for h in holes]})
    ys = sorted({y0, y1, *[h[2] for h in holes], *[h[3] for h in holes]})
    xs = [x for x in xs if x0 <= x <= x1]
    ys = [y for y in ys if y0 <= y <= y1]
    out = []
    for j in range(len(ys) - 1):
        row = []
        for i in range(len(xs) - 1):
            cx, cy = (xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2
            if any(h[0] <= cx <= h[1] and h[2] <= cy <= h[3] for h in holes):
                row.append(None)
            else:
                row.append((xs[i], xs[i + 1]))
        # unisci le celle vicine
        merged = []
        for c in row:
            if c and merged and merged[-1] and abs(merged[-1][1] - c[0]) < 1e-6:
                merged[-1] = (merged[-1][0], c[1])
            else:
                merged.append(c)
        for c in merged:
            if c:
                out.append((c[0], c[1], ys[j], ys[j + 1]))
    return out


# ============================================================== MURI (x 0..3, y 0..3)
WIN = (0.85, 2.15, 1.0, 2.25)
DOOR = (0.95, 2.05, 0.0, 2.3)


def brick_wall(name, hole=None, kind=None, seed=1, burnt=False):
    k = mk(name, seed)
    r = k.rnd
    holes = [hole] if hole else []
    ext = 'brick_burnt' if burnt else 'brick_borgo'
    # nucleo (intonaco dentro) e paramento in mattoni fuori
    for (a, b, c, d) in rects(0, 3, 0, 3, holes):
        B(k, a, c, -0.15, b, d, 0.10, 'plaster_borgo')
        B(k, a, c, 0.10, b, d, 0.16, ext)
    # filari: righe di malta leggermente in rilievo e mattoni sporgenti di colore diverso
    y = 0.55
    while y < 2.85:
        for (a, b, c, d) in rects(0, 3, y, y + 0.025, holes):
            B(k, a, c, 0.16, b, d, 0.165, 'mortar_borgo' if not burnt else 'soot')
        y += 0.3
    for i in range(9):
        bx, by = r.uniform(0.1, 2.5), r.uniform(0.5, 2.7)
        if hole and hole[0] - 0.45 < bx < hole[1] and hole[2] - 0.2 < by < hole[3] + 0.05:
            continue
        B(k, bx, by, 0.16, bx + 0.42, by + 0.14, 0.19, r.choice(['brick_borgo_dark', 'brick_borgo_light', 'brick_borgo_dark']) if not burnt else 'soot')
    # zoccolo e cornicione
    for (a, b, c, d) in rects(0, 3, 0, 0.42, holes):
        B(k, a, c, -0.16, b, d, 0.19, 'concrete_dark')
    B(k, 0, 2.86, -0.17, 3, 3.0, 0.19, 'concrete')
    # intonaco interno: battiscopa
    for (a, b, c, d) in rects(0, 3, 0, 0.12, holes):
        B(k, a, c, -0.17, b, d, -0.15, 'wood_dark')
    if burnt:
        for i in range(4):
            sx = r.uniform(0.2, 2.4)
            B(k, sx, r.uniform(1.6, 2.4), 0.165, sx + r.uniform(0.3, 0.6), 2.86, 0.172, 'soot')   # fuliggine sopra le finestre
    if kind == 'window':
        x0, x1, y0, y1 = hole
        for (a, b) in ((x0 - 0.08, x0), (x1, x1 + 0.08)):
            B(k, a, y0, -0.12, b, y1, 0.18, 'paint_cream')
        B(k, x0 - 0.08, y1, -0.12, x1 + 0.08, y1 + 0.1, 0.18, 'concrete_light')       # architrave
        B(k, x0 - 0.14, y0 - 0.09, -0.12, x1 + 0.14, y0, 0.28, 'concrete_light')       # davanzale
        mx = (x0 + x1) / 2
        B(k, mx - 0.03, y0, -0.03, mx + 0.03, y1, 0.03, 'paint_cream')                 # montante
        B(k, x0, (y0 + y1) / 2 - 0.03, -0.03, x1, (y0 + y1) / 2 + 0.03, 0.03, 'paint_cream')
        # vetri: uno rotto (manca un pezzo)
        B(k, x0, y0, -0.01, mx - 0.03, y1, 0.01, 'glass_dark')
        B(k, mx + 0.03, y0, -0.01, x1, (y0 + y1) / 2 - 0.03, 0.01, 'glass_dark')
        B(k, mx + 0.03, (y0 + y1) / 2 + 0.03, -0.01, x1 - 0.25, y1, 0.01, 'glass_dark')
    if kind == 'door':
        x0, x1, y0, y1 = hole
        for (a, b) in ((x0 - 0.1, x0), (x1, x1 + 0.1)):
            B(k, a, 0, -0.17, b, y1, 0.2, 'wood_dark')
        B(k, x0 - 0.18, y1, -0.17, x1 + 0.18, y1 + 0.2, 0.22, 'concrete_light')
        B(k, x0, 0, -0.17, x1, 0.05, 0.22, 'concrete')                                 # soglia


brick_wall('Bld_Wall_Brick_01', seed=11)
brick_wall('Bld_Wall_Brick_Window_01', WIN, 'window', seed=12)
brick_wall('Bld_Wall_Brick_Door_01', DOOR, 'door', seed=13)


def metal_wall(name, hole=None, seed=2):
    k = mk(name, seed)
    r = k.rnd
    holes = [hole] if hole else []
    col = r.choice(['metal_tan', 'metal_green'])
    dark = col + '_dark'
    for (a, b, c, d) in rects(0.08, 2.92, -0.05, 3.0, holes):
        B(k, a, c, 0.0, b, d, 0.05, col)
        B(k, a, c, -0.04, b, d, 0.0, 'plaster_borgo_dark')
    # onde della lamiera: costole verticali ogni 0.3 m
    x = 0.2
    while x < 2.85:
        for (a, b, c, d) in rects(x, x + 0.1, -0.05, 3.0, holes):
            B(k, a, c, 0.05, b, d, 0.1, dark)
        x += 0.3
    for i in range(3):
        rx = r.uniform(0.3, 2.5)
        if hole and hole[0] - 0.3 < rx < hole[1]:
            continue
        B(k, rx, r.uniform(-0.05, 0.6), 0.1, rx + 0.12, r.uniform(1.0, 2.2), 0.105, 'rust')        # colature di ruggine
    for x0 in (0.0, 2.92):
        B(k, x0, -0.13, -0.05, x0 + 0.08, 3.0, 0.16, 'iron')                                     # montanti
    B(k, 0, -0.13, -0.05, 3, 0.12, 0.17, 'iron_dark')
    B(k, 0, 2.9, -0.05, 3, 3.0, 0.17, 'iron_dark')
    if hole:
        x0, x1, y0, y1 = hole
        for (a, b) in ((x0 - 0.06, x0), (x1, x1 + 0.06)):
            B(k, a, y0, -0.05, b, y1, 0.14, 'iron')
        B(k, x0 - 0.06, y0 - 0.06, -0.05, x1 + 0.06, y0, 0.2, 'iron')
        B(k, x0 - 0.06, y1, -0.05, x1 + 0.06, y1 + 0.06, 0.14, 'iron')
        for i in range(3):
            bx = x0 + 0.2 + i * (x1 - x0 - 0.4) / 2
            B(k, bx - 0.02, y0, 0.05, bx + 0.02, y1, 0.09, 'iron_dark')                            # sbarre
        B(k, x0, y0, 0.0, x1, y1, 0.02, 'glass_dark')


metal_wall('Bld_Wall_Metal_01', seed=21)
metal_wall('Bld_Wall_Metal_Window_01', (0.9, 2.1, 1.0, 2.1), seed=22)

# porta di metallo (anta), cardine sull'origine, si estende verso -X
k = mk('Bld_Metal_Door_01', 3)
B(k, -1.0, 0, -0.03, 0, 2.2, 0.03, 'metal_green_dark')
for (y0, y1) in ((0.2, 1.0), (1.2, 2.0)):
    B(k, -0.88, y0, 0.03, -0.12, y1, 0.05, 'metal_green')
B(k, -0.92, 1.0, 0.03, -0.82, 1.08, 0.12, 'steel')
B(k, -0.92, 1.0, -0.12, -0.82, 1.08, -0.03, 'steel')
B(k, -0.3, 0.05, 0.05, -0.1, 0.6, 0.055, 'rust')

# ============================================================== PAVIMENTO E TETTI
k = mk('Bld_Floor_Ceiling_Wood_01', 4)
for i in range(6):
    z0 = -3 + i * 0.5
    B(k, 0, -0.06, z0 + 0.01, 3, 0.06, z0 + 0.49, k.rnd.choice(['wood', 'wood_dark', 'wood_light', 'wood']))
B(k, 0, -0.065, -3, 3, -0.04, 0, 'wood_dark')


def slope(k, z_eave, y_eave, z_ridge, y_ridge, x0, x1, cols, seed=0):
    """falda: lastre sovrapposte dalla gronda al colmo"""
    n = 6
    for i in range(n):
        t0, t1 = i / n, (i + 1.15) / n
        za, ya = z_eave + (z_ridge - z_eave) * t0, y_eave + (y_ridge - y_eave) * t0
        zb, yb = z_eave + (z_ridge - z_eave) * min(t1, 1.0), y_eave + (y_ridge - y_eave) * min(t1, 1.0)
        length = math.hypot(zb - za, yb - ya)
        ang = math.degrees(math.atan2(-(yb - ya), zb - za))
        k.push((0, (ya + yb) / 2, (za + zb) / 2), (ang, 0, 0))
        k.box(((x0 + x1) / 2, 0.06 + i * 0.004, 0), (x1 - x0, 0.1, length), cols[i % len(cols)])
        k.pop()


k = mk('Bld_Roof_01', 5)
slope(k, 0.48, -0.06, -4.5, 1.78, -3.0, 0.0, ['roof_grey', 'roof_grey_dark', 'roof_grey', 'roof_grey_light'])
slope(k, -9.49, -0.06, -4.5, 1.78, -3.0, 0.0, ['roof_grey', 'roof_grey_dark', 'roof_grey', 'roof_grey_light'])
B(k, -3.02, 1.74, -4.72, 0.02, 1.92, -4.28, 'roof_grey_dark')                    # colmo
for z in (0.42, -9.43):
    B(k, -3.0, -0.12, z - 0.06, 0.0, 0.08, z + 0.06, 'wood_dark')               # grondaia/frontalino
if True:
    r = k.rnd
    for i in range(2):                                                          # tegole mancanti (toppe scure)
        z = r.uniform(-3.5, -0.8)
        y = -0.06 + (z - 0.48) / (-4.5 - 0.48) * 1.84
        B(k, r.uniform(-2.6, -1.2), y + 0.1, z - 0.3, r.uniform(-1.0, -0.3), y + 0.17, z + 0.3, 'tar')

k = mk('Bld_Roof_Truss_01', 6)
k.beam((0, -0.45, 0.0), (0, 1.6, -4.5), 0.16, 0.18, 'wood_dark', up=(1, 0, 0))
k.beam((0, 1.6, -4.5), (0, -0.45, -9.0), 0.16, 0.18, 'wood_dark', up=(1, 0, 0))
k.beam((0, -0.4, 0.0), (0, -0.4, -9.0), 0.16, 0.16, 'wood', up=(1, 0, 0))
k.beam((0, -0.4, -4.5), (0, 1.55, -4.5), 0.12, 0.12, 'wood', up=(1, 0, 0))

k = mk('Bld_Roof_Flat_Closed_01', 7)
B(k, -0.19, 0, -3.19, 3.2, 0.2, 0.2, 'concrete_dark')
B(k, -0.19, 0.2, -3.19, 3.2, 0.22, 0.2, 'roof_grey_dark')
for i in range(3):
    x = k.rnd.uniform(0.0, 2.2)
    z = k.rnd.uniform(-2.8, -0.8)
    B(k, x, 0.22, z, x + k.rnd.uniform(0.4, 0.9), 0.235, z + k.rnd.uniform(0.3, 0.7), 'tar')

# tettoia: lamiera inclinata con due staffe (x -1.29..1.29, z 0..1.5)
k = mk('Bld_Exterior_Shade_01', 8)
k.push((0, 0.0, 0.75), (30, 0, 0))
for i in range(6):
    x0 = -1.29 + i * 0.43
    k.box((x0 + 0.215, 0.0, 0), (0.43, 0.05, 1.72), 'awning_red' if i % 2 == 0 else 'awning_cream')
k.box((0, -0.04, 0.86), (2.6, 0.18, 0.05), 'awning_red')
k.pop()
for sx in (-1.1, 1.1):
    k.beam((sx, 0.45, 0.02), (sx, -0.4, 1.45), 0.05, 0.05, 'iron', up=(1, 0, 0))
    k.beam((sx, -0.45, 0.02), (sx, -0.2, 1.0), 0.04, 0.04, 'iron', up=(1, 0, 0))

# ============================================================== ARREDO / OGGETTI
k = mk('Prop_Woodstack_01', 9)
for row in range(2):
    for i in range(3):
        x = -0.36 + i * 0.36 + (0.18 if row else 0)
        if x > 0.4:
            continue
        B(k, x - 0.16, 0.04 + row * 0.14, -2.4 + k.rnd.uniform(-0.05, 0.05), x + 0.16, 0.17 + row * 0.14, 2.35, k.rnd.choice(['wood_raw', 'wood', 'wood_light']))

k = mk('Prop_Papers_01', 10)
for i in range(6):
    k.push((k.rnd.uniform(-0.6, 0.6), 0.002 + i * 0.002, k.rnd.uniform(-0.3, 0.3)), (0, k.rnd.uniform(0, 180), 0))
    k.box((0, 0, 0), (0.3, 0.004, 0.42), k.rnd.choice(['paper', 'paper_old']))
    k.pop()

k = mk('Prop_GasCan_01', 11)
k.cbox((0, 0.22, 0), (0.38, 0.44, 0.13), 'paint_red', ch=0.02)
B(k, -0.12, 0.44, -0.03, 0.08, 0.5, 0.03, 'paint_red_dark')
k.cyl((0.13, 0.42, 0), (0.18, 0.5, 0), 0.025, 'paint_black', n=6)

k = mk('Prop_Bottle_01', 12)
k.cyl((0, 0, 0), (0, 0.19, 0), 0.05, 'plastic_green_dark', n=8)
k.cyl((0, 0.19, 0), (0, 0.24, 0), 0.05, 'plastic_green_dark', n=8, r1=0.02)
k.cyl((0, 0.24, 0), (0, 0.29, 0), 0.02, 'plastic_green', n=6)

k = mk('Prop_Warehouse_Venting_01', 13)
B(k, -3.0, -0.65, -0.3, -0.6, -0.1, 0.3, 'steel')
B(k, -0.8, -0.65, -0.45, 0.05, 0.55, 0.45, 'corrugated')
k.cyl((-0.38, 0.55, 0), (-0.38, 0.62, 0), 0.38, 'iron_dark', n=10)
for i in range(4):
    B(k, -3.0 + i * 0.7, -0.66, -0.32, -2.95 + i * 0.7, -0.09, 0.32, 'iron')

k = mk('Prop_Table_Metal_01', 14)
B(k, -1.12, 0.86, -0.44, 1.12, 0.92, 0.44, 'steel')
for sx in (-1.0, 1.0):
    for sz in (-0.36, 0.36):
        B(k, sx - 0.03, 0, sz - 0.03, sx + 0.03, 0.86, sz + 0.03, 'iron')
B(k, -1.0, 0.25, -0.36, 1.0, 0.28, 0.36, 'iron_dark')

k = mk('Prop_Sign_Danger_01', 15)
B(k, -0.22, 0.0, -0.01, 0.22, 0.14, 0.01, 'hazard_yellow')
for i in range(4):
    B(k, -0.2 + i * 0.11, 0.02, 0.01, -0.15 + i * 0.11, 0.12, 0.015, 'hazard_black')


def shelf(name, full, seed):
    k = mk(name, seed)
    for sx in (-0.58, 0.55):
        for sz in (-0.23, 0.2):
            B(k, sx, 0, sz, sx + 0.04, 1.93, sz + 0.04, 'iron')
    for i in range(4):
        y = 0.1 + i * 0.58
        B(k, -0.6, y, -0.25, 0.6, y + 0.04, 0.25, 'steel')
        if full:
            x = -0.5
            while x < 0.4:
                w = k.rnd.uniform(0.15, 0.32)
                h = k.rnd.uniform(0.15, 0.38)
                if k.rnd.random() < 0.75:
                    B(k, x, y + 0.04, -0.18, x + w, y + 0.04 + h, 0.16, k.rnd.choice(['cardboard', 'paint_cream', 'paint_blue', 'paint_red', 'cardboard']))
                x += w + 0.03


shelf('Prop_Shelf_Preset_01', True, 16)
shelf('Prop_Shelf_01', False, 17)

k = mk('Prop_Cabinets_01', 18)
B(k, -0.24, 0, -0.28, 0.24, 1.5, 0.28, 'metal_green')
B(k, -0.01, 0.05, 0.28, 0.01, 1.45, 0.29, 'metal_green_dark')
for y in (1.2, 1.25, 1.3):
    B(k, -0.18, y, 0.28, -0.04, y + 0.02, 0.295, 'metal_green_dark')
B(k, 0.04, 0.75, 0.28, 0.07, 0.9, 0.31, 'steel')

k = mk('Prop_Office_Desk_01', 19)
B(k, -1.09, 0.9, -0.46, 1.09, 0.95, 0.46, 'wood')
B(k, 0.5, 0, -0.42, 1.04, 0.9, 0.42, 'wood_dark')
B(k, -1.04, 0, -0.42, -0.98, 0.9, 0.42, 'wood_dark')
for y in (0.25, 0.55):
    B(k, 0.55, y, 0.42, 1.0, y + 0.25, 0.44, 'wood')
k.cbox((-0.4, 1.05, -0.1), (0.5, 0.18, 0.35), 'plastic_grey', ch=0.02)     # vecchio monitor
B(k, 0.0, 0.95, 0.05, 0.4, 0.97, 0.3, 'paper')

k = mk('Prop_Office_Shelf_01', 20)
B(k, -0.58, 0, -0.22, 0.58, 1.78, -0.2, 'wood_dark')
for sx in (-0.58, 0.54):
    B(k, sx, 0, -0.22, sx + 0.04, 1.78, 0.22, 'wood')
for i in range(4):
    y = i * 0.44
    B(k, -0.56, y, -0.22, 0.56, y + 0.04, 0.22, 'wood')
    if i < 3:
        x = -0.52
        while x < 0.45:
            w = k.rnd.uniform(0.04, 0.08)
            if k.rnd.random() < 0.8:
                B(k, x, y + 0.04, -0.15, x + w, y + 0.04 + k.rnd.uniform(0.22, 0.34), 0.12, k.rnd.choice(['cloth_red', 'paint_blue', 'paint_green', 'paper_old', 'mahogany']))
            x += w + 0.01

k = mk('Prop_Sink_01', 21)
B(k, -1.18, 0, -0.39, 1.18, 0.95, 0.36, 'paint_cream')
B(k, -1.18, 0.95, -0.39, 1.18, 1.0, 0.39, 'concrete_light')
B(k, -0.3, 0.9, -0.25, 0.3, 1.01, 0.25, 'steel')
B(k, -0.25, 0.92, -0.2, 0.25, 1.012, 0.2, 'iron_dark')
k.cyl((0, 1.0, -0.3), (0, 1.07, -0.3), 0.02, 'steel', n=6)
for x in (-0.8, 0.8):
    B(k, x - 0.33, 0.1, 0.36, x + 0.33, 0.85, 0.38, 'paint_cream')
    B(k, x - 0.05, 0.75, 0.38, x + 0.05, 0.78, 0.4, 'steel')

k = mk('Prop_Chair_01', 22)
B(k, -0.25, 0.44, -0.25, 0.25, 0.49, 0.25, 'wood')
B(k, -0.25, 0.49, -0.29, 0.25, 0.98, -0.25, 'wood')
for sx in (-0.22, 0.2):
    for sz in (-0.24, 0.2):
        B(k, sx, 0, sz, sx + 0.04, 0.44, sz + 0.04, 'wood_dark')


def puddle(name, rx, rz, seed):
    k = mk(name, seed)
    n = 14
    pts = []
    for i in range(n):
        a = i / n * math.tau
        s = k.rnd.uniform(0.7, 1.0)
        pts.append((math.cos(a) * rx * s, math.sin(a) * rz * s))
    c = k.vert((0, 0.002, 0))
    ring = [k.vert((x, 0.002, z)) for x, z in pts]
    for i in range(n):
        k.face([c, ring[(i + 1) % n], ring[i]], 'puddle')


puddle('Prop_Puddle_01', 2.3, 2.3, 23)
puddle('Prop_Puddle_02', 1.85, 1.7, 24)

k = mk('Prop_Powerbox_01', 25)
B(k, -0.6, 0, -0.6, 0.6, 0.15, 0.6, 'concrete')
B(k, -0.5, 0.15, -0.45, 0.5, 1.25, 0.45, 'plastic_grey')
B(k, -0.42, 0.25, 0.45, 0.42, 1.15, 0.47, 'corrugated')
B(k, -0.15, 0.85, 0.47, 0.15, 1.05, 0.48, 'hazard_yellow')

k = mk('Prop_Pot_01', 26)
k.cyl((0, 0, 0), (0, 0.24, 0), 0.22, 'iron', n=10)
k.cyl((0, 0.24, 0), (0, 0.27, 0), 0.23, 'iron_dark', n=10)
for sx in (-0.3, 0.26):
    B(k, sx, 0.18, -0.03, sx + 0.04, 0.22, 0.03, 'iron_dark')

k = mk('Prop_Pallet_01', 27)
for i in range(5):
    x = -0.7 + i * 0.335
    B(k, x, 0.19, -0.71, x + 0.25, 0.23, 0.71, 'wood_raw')
for z in (-0.68, -0.05, 0.58):
    B(k, -0.72, 0.04, z, 0.72, 0.19, z + 0.12, 'wood')
for i in range(3):
    x = -0.7 + i * 0.6
    B(k, x, 0, -0.71, x + 0.22, 0.04, 0.71, 'wood_raw')

k = mk('Prop_PaintCan_01', 28)
k.cyl((0, 0, 0), (0, 0.27, 0), 0.15, 'steel', n=10)
k.cyl((0, 0.15, 0), (0, 0.24, 0), 0.152, k.rnd.choice(['paint_blue', 'paint_red', 'paint_yellow']), n=10)
k.cyl((0, 0.27, 0), (0, 0.29, 0), 0.13, 'iron', n=10)

k = mk('Prop_Container_01', 29)
k.cbox((0, 0.18, 0), (0.39, 0.36, 0.22), 'plastic_green', ch=0.02)
B(k, -0.2, 0.36, -0.11, 0.2, 0.41, 0.11, 'plastic_green_dark')

k = mk('Prop_Cone_01', 30)
B(k, -0.15, -0.19, -0.15, 0.15, -0.16, 0.15, 'tyre')
k.cyl((0, -0.16, 0), (0, 0.19, 0), 0.11, 'traffic_orange', n=8, r1=0.02)
k.cyl((0, -0.02, 0), (0, 0.06, 0), 0.075, 'paint_white', n=8, r1=0.058)

k = mk('Prop_CardboardBox_Stack_01', 31)
for (x, y, z, s) in ((-0.36, 0, -0.36, 0.72), (0.38, 0, -0.32, 0.68), (-0.3, 0, 0.4, 0.66), (0.0, 0.7, -0.1, 0.5)):
    k.push((x, y, z), (0, k.rnd.uniform(-12, 12), 0))
    k.box((0, s * 0.62 / 2, 0), (s, s * 0.62, s), 'cardboard')
    k.box((0, s * 0.62 + 0.002, 0), (s * 0.15, 0.004, s * 1.002), 'paper_old')       # nastro
    k.pop()

k = mk('Prop_Book_Group_01', 32)
x = -0.44
while x < 0.4:
    w = k.rnd.uniform(0.05, 0.1)
    B(k, x, 0, -0.12, x + w, k.rnd.uniform(0.2, 0.29), 0.12, k.rnd.choice(['cloth_red', 'paint_blue', 'paint_green', 'paper_old', 'mahogany']))
    x += w + 0.005

k = mk('Prop_Barrel_Metal_01', 33)
k.cyl((0, 0, 0), (0, 1.04, 0), 0.35, 'military_dark', n=12)
for y in (0.3, 0.7):
    k.cyl((0, y, 0), (0, y + 0.05, 0), 0.36, 'rust', n=12)
k.cyl((0, 1.0, 0), (0, 1.05, 0), 0.36, 'iron_dark', n=12)

k = mk('Prop_Bag_01', 34)
k.blob((0, 0.035, 0), (0.045, 0.04, 0.035), 'rag', k.rnd, n=6, rings=3)
k.cyl((0, 0.07, 0), (0, 0.1, 0), 0.012, 'rope', n=5)

# ============================================================== AL POSTO DEI PEZZI SURROUNDEAD
k = mk('Borgo_Fence_Wood', 35)
for z in (-0.06, -2.44):
    B(k, -0.06, 0, z - 0.06, 0.06, 1.55, z + 0.06, 'wood_dark')
for y in (0.35, 1.1):
    B(k, -0.04, y, -2.5, 0.04, y + 0.1, 0.0, 'wood')
z = -2.38
while z < -0.1:
    h = k.rnd.uniform(1.2, 1.45)
    if k.rnd.random() < 0.9:
        B(k, 0.04, 0.05, z, 0.07, h, z + 0.16, k.rnd.choice(['wood', 'wood_light', 'wood_raw', 'wood']))
    z += 0.2


def car(name, body, dark, police=False, seed=36):
    """auto distrutta: lunghezza lungo Z (5 m), larghezza 1.9, ruote sgonfie, vetri rotti"""
    k = mk(name, seed)
    r = k.rnd
    k.cbox((0, 0.55, 0), (1.85, 0.5, 4.7), body, ch=0.06)                     # scocca
    k.cbox((0, 0.86, 2.0), (1.8, 0.14, 0.9), body, ch=0.04)                   # cofano
    k.cbox((0, 0.86, -1.9), (1.8, 0.14, 0.9), body, ch=0.04)                  # baule
    k.cbox((0, 1.12, -0.1), (1.7, 0.55, 2.4), body, ch=0.06)                  # abitacolo
    B(k, -0.86, 0.95, -1.2, 0.86, 1.33, 1.0, 'iron_dark')                     # interno scuro (finestrini vuoti)
    B(k, -0.7, 0.95, 1.05, 0.7, 1.32, 1.1, 'glass_dark')                      # parabrezza
    B(k, -0.93, 0.28, -2.36, 0.93, 0.42, -2.34, 'iron')                       # paraurti
    B(k, -0.93, 0.28, 2.34, 0.93, 0.42, 2.36, 'iron')
    for sx in (-0.7, 0.7):
        B(k, sx - 0.18, 0.5, 2.34, sx + 0.18, 0.62, 2.37, 'paint_cream')       # fari
    for i in range(5):
        x = r.choice([-0.93, 0.93])
        B(k, x - 0.01, r.uniform(0.35, 0.8), r.uniform(-2.0, 1.5), x + 0.01, r.uniform(0.8, 1.0), r.uniform(-1.5, 2.0), 'rust')
    for (sx, sz) in ((-0.82, 1.5), (0.82, 1.5), (-0.82, -1.5), (0.82, -1.5)):
        if r.random() < 0.2:
            continue                                                           # ruota mancante
        k.cyl((sx - 0.12 * (1 if sx > 0 else -1), 0.3, sz), (sx + 0.12 * (1 if sx > 0 else -1), 0.3, sz), 0.33, 'tyre', n=10)
        k.cyl((sx + 0.13 * (1 if sx > 0 else -1), 0.3, sz), (sx + 0.14 * (1 if sx > 0 else -1), 0.3, sz), 0.16, 'iron', n=8)
    if police:
        B(k, -0.93, 0.5, -0.8, 0.93, 0.8, 0.8, 'paint_black')                  # porte nere
        B(k, -0.5, 1.4, -0.2, 0.5, 1.5, 0.1, 'iron_dark')
        B(k, -0.48, 1.5, -0.18, -0.02, 1.58, 0.08, 'emit_red')
        B(k, 0.02, 1.5, -0.18, 0.48, 1.58, 0.08, 'emit_blue')
    # vetri a terra
    for i in range(4):
        B(k, r.uniform(-1.4, 1.4), 0.005, r.uniform(-2, 2), r.uniform(-1.4, 1.4) + 0.12, 0.01, r.uniform(-2, 2) + 0.1, 'glass_dark')


car('Borgo_Car_Wreck', 'car_blue', 'car_blue_dark', seed=36)
car('Borgo_Car_Wreck_Red', 'car_red', 'rust', seed=37)
car('Borgo_Police_Wreck', 'police_white', 'paint_black', police=True, seed=38)

k = mk('Borgo_Truck_Wreck', 39)
k.cbox((0, 0.7, 0), (2.4, 0.4, 7.0), 'iron_dark', ch=0.05)                    # telaio
k.cbox((0, 1.5, 2.7), (2.4, 1.4, 1.6), 'military', ch=0.08)                    # cabina
B(k, -1.0, 1.75, 3.5, 1.0, 2.1, 3.52, 'glass_dark')
k.cbox((0, 1.1, -1.0), (2.5, 0.25, 4.8), 'military_dark', ch=0.04)             # cassone
for sx in (-1.22, 1.22):
    B(k, sx - 0.04, 1.2, -3.4, sx + 0.04, 1.75, 1.4, 'military')
# telone: tetto e fianchi in tela, bordi smussati
B(k, -1.0, 2.5, -3.35, 1.0, 2.56, 1.35, 'tarp_green')
for sx in (-1, 1):
    B(k, sx * 1.22 - 0.03, 1.25, -3.35, sx * 1.22 + 0.03, 2.25, 1.35, 'tarp_green_dark')
    k.push((sx * 1.12, 2.4, -1.0), (0, 0, -45 * sx))
    k.box((0, 0, 0), (0.36, 0.05, 4.7), 'tarp_green')
    k.pop()
for z in (-3.0, -1.0, 1.0):
    B(k, -1.2, 2.45, z - 0.04, 1.2, 2.5, z + 0.04, 'iron_dark')     # archi
for sz in (2.7, -0.6, -2.4):
    for sx in (-1.15, 1.15):
        k.cyl((sx - 0.15, 0.5, sz), (sx + 0.15, 0.5, sz), 0.5, 'tyre', n=10)
B(k, -1.2, 0.3, 3.5, 1.2, 0.6, 3.6, 'iron')

def tent(name, col, seed):
    k = mk(name, seed)
    prof = [(1.25, 0.0), (1.15, 0.6), (0.9, 1.15), (0.5, 1.5), (0.0, 1.62)]
    k.lathe(prof, col, n=8, axis='y')
    B(k, -0.35, 0.0, 1.05, 0.35, 0.95, 1.2, 'iron_dark')                        # ingresso
    for a in range(4):
        ang = a * math.pi / 2 + 0.4
        k.beam((math.cos(ang) * 1.2, 0.05, math.sin(ang) * 1.2), (math.cos(ang) * 1.6, 0.02, math.sin(ang) * 1.6), 0.015, 0.015, 'rope', up=(0, 1, 0))


tent('Borgo_Tent_Dome', 'tarp_green', 40)
tent('Borgo_Tent_Dome_Orange', 'tent_orange', 45)
tent('Borgo_Tent_Dome_Blue', 'water_blue_dark', 46)


def water_barrel(name, opened, seed):
    k = mk(name, seed)
    k.cyl((0, 0, 0), (0, 0.98, 0), 0.38, 'water_blue', n=12)
    for y in (0.3, 0.65):
        k.cyl((0, y, 0), (0, y + 0.04, 0), 0.39, 'water_blue_dark', n=12)
    if opened:
        k.cyl((0, 0.93, 0), (0, 0.985, 0), 0.33, 'iron_dark', n=12)
    else:
        k.cyl((0, 0.98, 0), (0, 1.0, 0), 0.36, 'water_blue_dark', n=12)
        k.cyl((0.18, 1.0, 0), (0.18, 1.03, 0), 0.05, 'water_blue_dark', n=6)


water_barrel('Borgo_Barrel_Water', False, 41)
water_barrel('Borgo_Barrel_Water_Open', True, 42)

k = mk('Borgo_Log', 43)
k.cyl((0, 0, 1.3), (0, 0, -1.75), 0.22, 'log', n=8, cap_col='log_end')
k.cyl((0.05, 0.1, -0.4), (0.25, 0.32, -0.6), 0.05, 'log_dark', n=5)

k = mk('Borgo_Road_Barrier', 44)
B(k, -2.0, 0.85, -0.06, 2.0, 1.1, 0.06, 'paint_white')
for i in range(5):
    B(k, -1.9 + i * 0.85, 0.849, -0.065, -1.5 + i * 0.85, 1.101, 0.065, 'paint_red')
for sx in (-1.7, 1.7):
    for sz in (-0.4, 0.4):
        k.beam((sx, 0.0, sz), (sx, 0.95, 0), 0.07, 0.07, 'iron', up=(1, 0, 0))
B(k, -0.15, 1.1, -0.01, 0.15, 1.35, 0.01, 'hazard_yellow')

# ============================================================== export
for name, k in pieces.items():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    ob = kit.build(k, f'SM_{name}', mats)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=f'{OUT}/SM_{name}.glb', export_format='GLB', use_selection=True, export_yup=True,
                              export_materials='EXPORT', export_vertex_color='NONE')
    print('piece', name, kit.tris(ob))
