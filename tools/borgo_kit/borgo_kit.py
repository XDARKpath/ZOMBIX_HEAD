"""BORGO CENERE - kit originale (fatto da zero, nessun asset di terzi) per il villaggio di ZOMBIX HEAD.
Stile low-poly a colori piatti con atlas di palette (come gli altri asset ZX). Stesse misure e stessi punti d'origine
dei pezzi modulari che villaggio.gd usava prima, così il codice del villaggio resta uguale:
  muri 3 x 3 m (x 0..3, y 0..3, spessore centrato su z=0, esterno verso +Z), pavimento 3 x 3 (z -3..0),
  tetto a falde 3 x 10 m (x -3..0, z -9.5..0.5, colmo a z = -4.5), tetto piano 3 x 3, tettoie, porte, arredo, auto, tende...
Si scrive in coordinate Godot (Y su, Z verso l'esterno): push(rot=(90,0,0)) converte nello spazio di Blender (Z su).
Uscita: art/zx_borgo/SM_<nome>.glb"""
import sys, math, random, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
from mathutils import Vector
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
    'char': (38, 34, 32), 'char_light': (74, 66, 60), 'seat_cloth': (96, 92, 86), 'seat_cloth_dark': (66, 63, 60),
    'foam': (206, 190, 140),
    'plaster_ochre': (198, 164, 104), 'plaster_rose': (192, 146, 128), 'plaster_sage': (150, 160, 128),
    'shutter_green': (70, 104, 74), 'shutter_brown': (112, 74, 48), 'shutter_blue': (78, 104, 124),
}
for _k, _v in EXTRA.items():
    if _k not in lib.PALETTE:
        lib.PALETTE[_k] = _v
        lib.NAMES.append(_k)
assert len(lib.NAMES) <= 256, len(lib.NAMES)

# blender -b --factory-startup --python borgo_kit.py -- [SM_nome ...]   (senza nomi esporta tutti i pezzi)
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'art', 'zx_borgo'))
ONLY = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
kit._MATS.clear()
PAL = tempfile.mkdtemp()          # le palette finiscono dentro ogni glb: niente png sciolti nel progetto


def write_palettes(albedo, emission):
    """come kit.write_palettes, ma con le immagini di Blender (il Python di Blender non ha PIL)"""
    for path, only_emit in ((albedo, False), (emission, True)):
        im = bpy.data.images.new(os.path.basename(path), 256, 256)
        px = [1.0, 0.0, 1.0, 1.0] * (256 * 256) if not only_emit else [0.0, 0.0, 0.0, 1.0] * (256 * 256)
        for i, n in enumerate(lib.NAMES):
            if only_emit and n not in kit.EMISSIVE:
                continue
            c = [v / 255 for v in lib.PALETTE[n]]
            cx, cy = (i % 16) * 16, 255 - (i // 16) * 16        # le righe di Blender partono dal basso
            for y in range(16):
                for x in range(16):
                    j = ((cy - y) * 256 + cx + x) * 4
                    px[j:j + 3] = c
        im.pixels.foreach_set(px)
        im.filepath_raw = path
        im.file_format = 'PNG'
        im.save()
        bpy.data.images.remove(im)


write_palettes(f'{PAL}/T_Borgo_Palette.png', f'{PAL}/T_Borgo_Emission.png')
mats = kit.materials(f'{PAL}/T_Borgo_Palette.png', f'{PAL}/T_Borgo_Emission.png')
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
for (x, y, z, s) in ((-0.36, 0, -0.36, 0.72), (0.38, 0, -0.32, 0.68), (-0.3, 0, 0.4, 0.66), (0.0, 0.446, -0.1, 0.5)):       # la scatola in cima posa sulla prima (alta 0.72 * 0.62)
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


def arc(cz, cy, R, n=6, a0=0.0, a1=math.pi):
    """punti (y, z) di un arco di ruota: da z = cz + R*cos(a0) verso z decrescente"""
    return [(cy + R * math.sin(a0 + (a1 - a0) * i / n), cz + R * math.cos(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def pane(k, pts, broken=False, col='glass'):
    """lastra di vetro (materiale trasparente, doppia faccia); rotta = resta una scheggia nell'angolo basso"""
    if broken:
        a, b, d = Vector(pts[0]), Vector(pts[1]), Vector(pts[-1])
        pts = [tuple(a), tuple(a.lerp(b, 0.35)), tuple(a.lerp(d, 0.3))]
    k.face([k.vert(p) for p in pts], col)


def shards(k, r, s, z0, z1, n=3):
    """schegge di vetro a terra sotto un finestrino rotto: piccole e vicine alla fiancata (x e z da un solo campione)"""
    for i in range(n):
        x = s * r.uniform(0.94, 0.99)
        z = r.uniform(z0, z1)
        w, d = r.uniform(0.04, 0.09), r.uniform(0.04, 0.08)
        B(k, x - w / 2, 0.004, z - d / 2, x + w / 2, 0.009, z + d / 2, 'glass_dark')


def lip(k, s, x, cz, cy, R, col):
    """bordo del parafango lungo l'arco della ruota"""
    pts = arc(cz, cy, R + 0.02)
    for (y0, z0), (y1, z1) in zip(pts, pts[1:]):
        k.beam((x, y0, z0), (x, y1, z1), 0.05, 0.03, col, up=(s, 0, 0))


ZF, ZR, AR, AY, W = 1.42, -1.42, 0.40, 0.31, 0.92     # assi, raggio passaruota, mozzo, mezza larghezza


def car(name, body, cond, seed, police=False):
    """Relitto di berlina: muso verso +Z, lunga 4,8 m, larga 1,84 (2,0 con gli specchietti), origine a terra al centro.
    cond: 'looted' saccheggiata (porta del guidatore e una ruota tolte, baule e cofano aperti, sedili sventrati),
          'crashed' incidentata (muso accartocciato, cofano a tenda, parabrezza a ragnatela, ruota girata),
          'abandoned' lasciata a un posto di blocco, 'burnt' bruciata (niente gomme né vetri, poggia sui cerchi)."""
    k = mk(name, seed)
    r = k.rnd
    burnt = cond == 'burnt'
    paint = 'char' if burnt else body
    trim = 'char' if burnt else 'iron_dark'
    seat = 'char_light' if burnt else 'seat_cloth'
    nose = 1.98 if cond == 'crashed' else 2.36
    k.push((0, -0.1 if burnt else 0.0, 0))           # senza gomme la bruciata sta 10 cm più in basso
    # --- scocca: fiancata con i passaruota, cofano, baule e vano dell'abitacolo aperto in alto
    prof = [(0.32, nose - 0.04), (0.24, max(ZF + AR + 0.02, nose - 0.3)), (0.24, ZF + AR)]
    prof += arc(ZF, AY, AR) + [(0.24, ZF - AR), (0.24, ZR + AR)]
    prof += arc(ZR, AY, AR) + [(0.24, ZR - AR), (0.24, -2.05), (0.32, -2.33), (0.62, -2.37), (0.84, -2.31), (0.90, -2.05), (0.91, -1.45)]
    prof += [(0.78, -1.45), (0.78, -0.95), (0.50, -0.95), (0.50, 0.92), (0.90, 0.92)]
    if cond == 'crashed':
        prof += [(1.04, 1.45), (0.80, nose - 0.02), (0.56, nose)]
    else:
        prof += [(0.88, 1.40), (0.84, 2.22), (0.74, 2.35), (0.58, nose + 0.01)]
    k.prism_x(prof, -W, W, paint)
    # --- porte: pannelli di fiancata (via la porta del guidatore nella saccheggiata)
    door = 'paint_black' if police else paint
    for s in (-1, 1):
        if not (cond == 'looted' and s == 1):
            k.prism_x([(0.24, 0.95), (0.90, 0.95), (0.90, -0.25), (0.24, -0.25)], s * 0.84, s * (W + 0.004), door)
        k.prism_x([(0.24, -0.25), (0.90, -0.25), (0.90, -0.95), (0.24, -0.95)], s * 0.84, s * (W + 0.004), door)
        k.prism_x([(0.74, -0.95), (0.90, -0.95), (0.90, -1.45), (0.74, -1.45)], s * 0.84, s * (W + 0.004), paint)
        for z in (0.95, -0.25, -0.95):                                              # fessure delle porte
            B(k, s * W, 0.27, z - 0.008, s * (W + 0.008), 0.89, z + 0.008, trim)
        B(k, s * 0.84, 0.895, -1.45, s * (W + 0.005), 0.915, 0.95, trim)           # bordo del finestrino
        for z in (-0.15, -0.88):                                                     # maniglie
            if not (cond == 'looted' and s == 1 and z > -0.25):
                B(k, s * W, 0.76, z, s * (W + 0.022), 0.795, z + 0.12, 'steel' if not burnt else trim)
        lip(k, s, s * (W + 0.012), ZF, AY, AR, trim)
        lip(k, s, s * (W + 0.012), ZR, AY, AR, trim)
    # --- montanti, tetto, vetri
    for s in (-1, 1):
        k.beam((s * 0.86, 0.91, 0.92), (s * 0.75, 1.40, 0.27), 0.07, 0.06, paint, up=(s, 0, 0))     # A
        k.beam((s * 0.87, 0.91, -0.25), (s * 0.76, 1.40, -0.28), 0.10, 0.07, paint, up=(s, 0, 0))   # B
        k.beam((s * 0.86, 0.91, -1.40), (s * 0.75, 1.40, -0.97), 0.16, 0.07, paint, up=(s, 0, 0))   # C
    k.cbox((0, 1.42, -0.35), (1.56, 0.06, 1.34), paint, ch=0.02)
    if not burnt:
        B(k, -0.74, 1.383, -0.97, 0.74, 1.39, 0.27, 'seat_cloth_dark')                             # cielo interno

    def gx(y):
        return 0.885 - (y - 0.90) / 0.5 * 0.13

    broken = {'looted': {'FR', 'RL', 'rear'}, 'crashed': {'FL'}, 'abandoned': {'RR'}}.get(cond, set())
    if not burnt:
        pane(k, [(-0.80, 0.93, 0.90), (0.80, 0.93, 0.90), (0.70, 1.38, 0.29), (-0.70, 1.38, 0.29)])
        pane(k, [(0.80, 0.93, -1.40), (-0.80, 0.93, -1.40), (-0.70, 1.38, -0.99), (0.70, 1.38, -0.99)], 'rear' in broken)
        for s, tag in ((-1, 'R'), (1, 'L')):                     # guida a sinistra: il lato +X è quello del guidatore
            if not (cond == 'looted' and s == 1):
                f = [(0.93, 0.86), (1.37, 0.30), (1.37, -0.21), (0.93, -0.21)]
                pane(k, [(s * gx(y), y, z) for y, z in f], 'F' + tag in broken)
                if 'F' + tag in broken:
                    shards(k, r, s, -0.2, 0.8)
            f = [(0.93, -0.30), (1.37, -0.30), (1.37, -0.92), (0.93, -1.30)]
            pane(k, [(s * gx(y), y, z) for y, z in f], 'R' + tag in broken)
            if 'R' + tag in broken:
                shards(k, r, s, -1.2, -0.3)
    if cond == 'crashed':                                        # parabrezza a ragnatela
        c = Vector((0.32, 1.12, 0.64))
        n = Vector((0, 0.80, 0.59)) * 0.012
        for ang in range(0, 360, 60):
            d = Vector((math.cos(math.radians(ang)) * 0.75, math.sin(math.radians(ang)) * 0.59 * 0.6, -math.sin(math.radians(ang)) * 0.80 * 0.6))
            e = c + d * r.uniform(0.25, 0.4)
            e.x = max(-0.75, min(0.75, e.x))
            k.beam(tuple(c + n), tuple(e + n), 0.012, 0.004, 'concrete_light', up=(0, 0.80, 0.59))
    # --- interni: pianale, cruscotto, volante, sedili
    B(k, -0.84, 0.50, -0.95, 0.84, 0.506, 0.92, trim)
    B(k, -0.84, 0.62, 0.62, 0.84, 0.97, 0.93, trim)
    k.beam((0.40, 0.80, 0.70), (0.40, 0.98, 0.52), 0.05, 0.05, 'iron_dark' if not burnt else trim)
    k.cyl((0.40, 0.99, 0.51), (0.40, 1.01, 0.49), 0.17, 'iron_dark' if not burnt else trim, n=10)
    if cond == 'crashed':
        k.blob((0.40, 1.04, 0.42), (0.20, 0.10, 0.16), 'paint_white', r, n=6, rings=2)          # airbag sgonfio
    for sx in (-0.40, 0.40):
        if burnt:                                                                               # restano i telai
            k.beam((sx - 0.22, 0.55, -0.22), (sx - 0.22, 1.12, -0.34), 0.03, 0.03, seat)
            k.beam((sx + 0.22, 0.55, -0.22), (sx + 0.22, 1.12, -0.34), 0.03, 0.03, seat)
            k.beam((sx - 0.22, 1.12, -0.34), (sx + 0.22, 1.12, -0.34), 0.03, 0.03, seat)
            B(k, sx - 0.24, 0.50, -0.20, sx + 0.24, 0.56, 0.28, seat)
            continue
        B(k, sx - 0.25, 0.50, -0.20, sx + 0.25, 0.64, 0.30, seat)
        k.push((sx, 0.62, -0.25), (-12, 0, 0))
        k.box((0, 0.30, 0), (0.48, 0.60, 0.12), seat)
        k.box((0, 0.68, 0), (0.26, 0.16, 0.10), seat)
        if cond == 'looted':
            k.blob((0.05, 0.35, 0.07), (0.14, 0.12, 0.04), 'foam', r, n=5, rings=2)            # imbottitura strappata
        k.pop()
    B(k, -0.78, 0.50, -0.95, 0.78, 0.66 if not burnt else 0.56, -0.55, seat)
    if not burnt:
        k.push((0, 0.66, -0.98), (-15, 0, 0))
        k.box((0, 0.25, 0), (1.56, 0.50, 0.12), seat)
        k.pop()
    # --- muso: fari, frecce, griglia, paraurti, targa
    bump = 'iron' if not burnt else trim
    if cond == 'crashed':
        B(k, -0.80, 0.34, nose - 0.10, 0.80, 0.80, nose - 0.02, 'iron_dark')                     # radiatore schiacciato
        B(k, -0.84, 0.60, nose - 0.04, -0.58, 0.72, nose + 0.01, 'paint_cream')                # un faro rimasto
        k.beam((-0.90, 0.42, nose + 0.05), (0.86, 0.12, nose + 0.16), 0.16, 0.10, bump, up=(0, 1, 0))  # paraurti appeso
    else:
        for s in (-1, 1):
            B(k, s * 0.56, 0.60, nose - 0.02, s * 0.84, 0.72, nose + 0.012, 'paint_cream' if not burnt else trim)
            B(k, s * 0.84, 0.60, nose - 0.06, s * 0.90, 0.70, nose - 0.01, 'traffic_orange' if not burnt else trim)
        B(k, -0.46, 0.50, nose - 0.02, 0.46, 0.70, nose + 0.006, 'iron_dark')
        for y in (0.54, 0.60, 0.66):
            B(k, -0.44, y, nose + 0.006, 0.44, y + 0.02, nose + 0.016, bump)
        k.cbox((0, 0.40, nose + 0.02), (1.84, 0.17, 0.12), bump, ch=0.03)
        if not burnt:
            B(k, -0.24, 0.35, nose + 0.08, 0.24, 0.46, nose + 0.09, 'paint_white')
    # --- coda: fanali, paraurti, targa
    for s in (-1, 1):
        B(k, s * 0.55, 0.68, -2.385, s * 0.86, 0.80, -2.34, 'paint_red_dark' if not burnt else trim)
    k.cbox((0, 0.40, -2.38), (1.84, 0.17, 0.12), bump, ch=0.03)
    if not burnt:
        B(k, -0.24, 0.50, -2.39, 0.24, 0.61, -2.37, 'paint_white')
    # --- specchietti (uno rotto o mancante)
    for s in (-1, 1):
        if (cond == 'looted' and s == 1) or (cond == 'crashed' and s == -1):
            continue
        k.beam((s * 0.88, 0.93, 0.86), (s * 0.95, 0.97, 0.84), 0.04, 0.03, trim)
        B(k, s * 0.92, 0.92, 0.78, s * 1.0, 1.04, 0.86, paint)
    # --- condizioni
    if cond == 'looted':
        B(k, -0.78, 0.906, -2.22, 0.78, 0.914, -1.52, 'iron_dark')                              # baule vuoto aperto
        k.push((0, 0.92, -1.50), (68, 0, 0))
        k.box((0, 0.02, -0.40), (1.70, 0.04, 0.80), paint)
        k.pop()
        k.push((0, 0.90, 0.95), (-9, 0, 0))                                                     # cofano sollevato (batteria presa)
        k.box((0, 0.03, 0.66), (1.74, 0.04, 1.30), paint)
        k.pop()
    if police:
        B(k, -0.55, 1.45, -0.45, 0.55, 1.50, -0.25, 'iron_dark')                               # lampeggiante
        B(k, -0.52, 1.50, -0.43, -0.02, 1.58, -0.27, 'emit_red')
        B(k, 0.02, 1.50, -0.43, 0.52, 1.58, -0.27, 'emit_blue')
        for sx in (-0.38, 0.38):                                                                 # rostro
            k.beam((sx, 0.30, nose + 0.12), (sx, 0.74, nose + 0.08), 0.06, 0.06, 'iron_dark')
        for y in (0.42, 0.68):
            B(k, -0.42, y - 0.03, nose + 0.07, 0.42, y + 0.03, nose + 0.13, 'iron_dark')
        k.cyl((0.90, 1.02, 0.82), (0.90, 1.02, 0.95), 0.06, 'steel', n=6)                      # faro brandeggiabile
    # ruggine: solo in basso (sottoporta e coda) o a chiazze sulla bruciata; z da un solo campione
    spots = {'looted': 6, 'crashed': 1, 'abandoned': 2, 'burnt': 7}[cond]
    for i in range(spots):
        s = r.choice((-1, 1))
        z0, z1 = r.choice([(-0.92, 0.92), (-2.25, -1.86)] + ([(1.86, 2.2)] if cond != 'crashed' else []))
        zl = r.uniform(0.15, min(0.45, z1 - z0))
        z = r.uniform(z0, z1 - zl)
        y0 = r.uniform(0.27, 0.38)
        y1 = min(y0 + r.uniform(0.08, 0.2), 0.48 if not burnt else 0.85)
        B(k, s * (W + 0.002), y0, z, s * (W + 0.008), y1, z + zl, r.choice(['rust', 'rust_dark']) if not burnt else r.choice(['rust_dark', 'char_light', 'rust']))
    k.pop()
    # --- ruote (fuori dal push: la bruciata poggia sui cerchi)
    for s, z, tag in ((-1, ZF, 'FR'), (1, ZF, 'FL'), (-1, ZR, 'RR'), (1, ZR, 'RL')):
        if burnt:
            k.cyl((s * 0.72, 0.21, z), (s * 0.86, 0.21, z), 0.21, 'iron_dark', n=10)
            continue
        if cond == 'looted' and tag == 'RR':                                                    # ruota tolta: mozzo su due mattoni
            B(k, s * 0.62, 0.0, z - 0.14, s * 0.86, 0.14, z + 0.14, 'brick_borgo')
            B(k, s * 0.64, 0.14, z - 0.12, s * 0.84, 0.25, z + 0.12, 'concrete')
            k.cyl((s * 0.66, AY, z), (s * 0.80, AY, z), 0.14, 'rust_dark', n=8)
            continue
        flat = (cond == 'abandoned' and tag == 'RL') or (cond == 'looted' and tag == 'FL')
        y, rad = (0.26, 0.30) if flat else (AY, 0.32)
        yaw = 24 if (cond == 'crashed' and tag == 'FL') else 0
        k.push((s * 0.81, y, z), (0, yaw, 0))
        k.cyl((-s * 0.105, 0, 0), (s * 0.105, 0, 0), rad, 'tyre', n=12)
        k.cyl((s * 0.105, 0, 0), (s * 0.11, 0, 0), 0.19, 'steel' if cond != 'looted' else 'iron', n=10)
        k.cyl((s * 0.11, 0, 0), (s * 0.125, 0, 0), 0.06, 'iron_dark', n=6)
        k.pop()


car('Borgo_Car_Wreck', 'car_blue', 'looted', 36)
car('Borgo_Car_Wreck_Red', 'car_red', 'crashed', 37)
car('Borgo_Police_Wreck', 'police_white', 'abandoned', 38, police=True)
car('Borgo_Car_Wreck_Burnt', 'car_blue', 'burnt', 47)


def truck(name, seed):
    """Camion militare abbandonato: muso verso +Z, 7,1 x 2,6 x 2,6 m. Cabina con porte, finestrini e interni,
    parafanghi su tutte le ruote, telone strappato su un fianco con il carico in vista."""
    k = mk(name, seed)
    r = k.rnd
    MIL, DARK = 'military', 'military_dark'
    for s in (-1, 1):
        B(k, s * 0.40, 0.55, -3.45, s * 0.55, 0.80, 3.30, 'iron_dark')                         # longheroni
    # cabina, parte bassa con il passaruota anteriore
    FZ, FY, FR = 2.70, 0.50, 0.60
    a0 = math.asin((0.85 - FY) / FR)
    k.prism_x([(0.85, 3.42)] + arc(FZ, FY, FR, 6, a0, math.pi - a0) + [(0.85, 1.95), (1.55, 1.95), (1.55, 3.42)], -1.15, 1.15, MIL)
    B(k, -1.15, 1.55, 1.95, 1.15, 2.30, 2.04, MIL)                                               # parete posteriore
    k.cbox((0, 2.35, 2.69), (2.34, 0.10, 1.52), MIL, ch=0.03)                                    # tetto
    B(k, -1.15, 1.55, 3.34, 1.15, 1.62, 3.44, MIL)                                               # cornice parabrezza
    B(k, -1.15, 2.22, 3.34, 1.15, 2.30, 3.44, MIL)
    B(k, -0.04, 1.62, 3.37, 0.04, 2.22, 3.43, MIL)
    for s in (-1, 1):
        B(k, s * 1.06, 1.55, 3.28, s * 1.15, 2.30, 3.44, MIL)                                  # montante anteriore
        B(k, s * 1.06, 1.55, 1.95, s * 1.15, 2.30, 2.10, MIL)                                  # montante posteriore
        B(k, s * 1.07, 2.20, 2.05, s * 1.15, 2.30, 3.36, MIL)                                  # bordo alto della porta
        pane(k, [(s * 0.04, 1.62, 3.40), (s * 1.06, 1.62, 3.40), (s * 1.06, 2.22, 3.40), (s * 0.04, 2.22, 3.40)], s == -1)
        pane(k, [(s * 1.11, 1.56, 2.10), (s * 1.11, 2.20, 2.10), (s * 1.11, 2.20, 3.28), (s * 1.11, 1.56, 3.28)], s == 1)
        # porta: fessure, maniglia, gradino
        for z in (2.08, 3.30):
            B(k, s * 1.15, 1.12, z - 0.008, s * 1.156, 2.28, z + 0.008, 'iron_dark')
        B(k, s * 1.15, 1.10, 2.08, s * 1.156, 1.12, 3.30, 'iron_dark')
        B(k, s * 1.15, 1.48, 2.18, s * 1.175, 1.52, 2.34, 'iron')
        B(k, s * 0.95, 0.62, 1.95, s * 1.22, 0.68, 2.20, 'iron')
        # bordo del parafango anteriore e specchietto sul braccio
        pts = arc(FZ, FY, FR + 0.02, 6, a0, math.pi - a0)
        for (y0, z0), (y1, z1) in zip(pts, pts[1:]):
            k.beam((s * 1.165, y0, z0), (s * 1.165, y1, z1), 0.06, 0.03, 'iron_dark', up=(s, 0, 0))
        k.beam((s * 1.15, 2.00, 3.22), (s * 1.27, 2.04, 3.30), 0.03, 0.03, 'iron_dark')
        B(k, s * 1.25, 1.80, 3.27, s * 1.29, 2.12, 3.35, 'iron_dark')
        # sedili visti dai finestrini
        B(k, s * 0.25, 1.30, 2.06, s * 0.95, 2.02, 2.20, 'seat_cloth')
    B(k, -1.05, 1.40, 3.10, 1.05, 1.62, 3.38, 'iron_dark')                                       # cruscotto
    k.cyl((0.55, 1.75, 3.02), (0.55, 1.73, 3.05), 0.20, 'iron_dark', n=10)
    k.beam((0.55, 1.55, 3.25), (0.55, 1.74, 3.04), 0.05, 0.05, 'iron_dark')
    # muso: griglia, fari con protezione, frecce, paraurti, ganci
    B(k, -0.62, 0.95, 3.42, 0.62, 1.45, 3.46, 'iron_dark')
    for i in range(7):
        x = -0.54 + i * 0.18
        B(k, x - 0.025, 0.97, 3.46, x + 0.025, 1.43, 3.48, MIL)
    for s in (-1, 1):
        k.cyl((s * 0.86, 1.15, 3.42), (s * 0.86, 1.15, 3.50), 0.12, 'paint_cream' if s == 1 else 'iron_dark', n=8)
        k.cyl((s * 0.86, 1.15, 3.46), (s * 0.86, 1.15, 3.52), 0.145, 'iron_dark', n=8, cap=False)
        B(k, s * 0.80, 1.36, 3.42, s * 0.94, 1.44, 3.47, 'traffic_orange')
        B(k, s * 0.70, 0.40, 3.62, s * 0.80, 0.52, 3.68, 'iron')
    B(k, -1.22, 0.48, 3.42, 1.22, 0.72, 3.62, 'iron_dark')
    # serbatoio e scarico
    k.cyl((0.85, 0.74, 1.05), (0.85, 0.74, 1.80), 0.24, 'iron', n=10)
    k.cyl((-1.02, 1.55, 1.88), (-1.02, 2.55, 1.88), 0.06, 'iron_dark', n=6)
    # cassone
    B(k, -1.25, 1.0, -3.45, 1.25, 1.2, 1.80, DARK)
    B(k, -1.25, 1.2, 1.70, 1.25, 1.80, 1.80, MIL)
    B(k, -1.25, 1.2, -3.45, 1.25, 1.75, -3.39, MIL)
    for s in (-1, 1):
        B(k, s * 1.19, 1.2, -3.45, s * 1.25, 1.75, 1.70, MIL)
        for z in (-2.6, -1.4, -0.2, 1.0):
            B(k, s * 1.25, 1.2, z - 0.04, s * 1.27, 1.75, z + 0.04, DARK)                       # montanti delle sponde
    for s in (-1, 1):                                                                            # fanali dietro
        B(k, s * 0.85, 0.85, -3.47, s * 1.05, 0.95, -3.45, 'paint_red_dark')
    # archi e telone (strappato sul fianco +X)
    for z in (-3.30, -1.60, 0.05, 1.60):
        for s in (-1, 1):
            k.beam((s * 1.22, 1.75, z), (s * 1.22, 2.30, z), 0.05, 0.05, 'iron_dark')
            k.beam((s * 1.22, 2.30, z), (s * 0.92, 2.50, z), 0.05, 0.05, 'iron_dark')
        k.beam((-0.92, 2.50, z), (0.92, 2.50, z), 0.05, 0.05, 'iron_dark')
    B(k, -0.95, 2.50, -3.40, 0.95, 2.56, 1.65, 'tarp_green')
    for s in (-1, 1):
        k.push((s * 1.08, 2.41, -0.88), (0, 0, -34 * s))
        k.box((0, 0, 0), (0.38, 0.05, 5.05), 'tarp_green')
        k.pop()
    B(k, -1.25, 1.75, -3.40, -1.19, 2.32, 1.65, 'tarp_green_dark')
    B(k, 1.19, 1.75, -0.30, 1.25, 2.32, 1.65, 'tarp_green_dark')
    for i in range(5):                                                                           # brandelli che pendono
        z = -3.2 + i * 0.6 + r.uniform(-0.1, 0.1)
        k.beam((1.23, 2.32, z), (1.24, r.uniform(1.85, 2.1), z + r.uniform(-0.12, 0.12)), 0.16, 0.02, 'tarp_green_dark', up=(1, 0, 0))
    for (z, h) in ((-2.8, 0.55), (-2.1, 0.55), (-1.3, 0.45)):                                    # carico visibile
        B(k, 0.25, 1.2, z - 0.3, 0.95, 1.2 + h, z + 0.3, DARK)
    B(k, 0.5, 1.2, -0.75, 0.85, 1.65, -0.60, MIL)
    # ruggine sulle sponde e sulla cabina (pezzi corti, z da un solo campione)
    for i in range(5):
        s = r.choice((-1, 1))
        z = r.uniform(-3.2, 1.2)
        B(k, s * 1.27, 1.25, z, s * 1.276, r.uniform(1.35, 1.6), z + r.uniform(0.15, 0.4), r.choice(['rust', 'rust_dark']))
    # ruote: anteriore nel passaruota, doppie dietro con i parafanghi
    for s in (-1, 1):
        for z, front in ((FZ, True), (-0.6, False), (-2.4, False)):
            flat = (s == 1 and z == -2.4) or (s == -1 and front)
            y, rad = (0.44, 0.47) if flat else (0.5, 0.5)
            x0 = 0.86 if front else 0.66
            k.cyl((s * x0, y, z), (s * 1.12, y, z), rad, 'tyre', n=12)
            k.cyl((s * 1.12, y, z), (s * 1.13, y, z), 0.28, DARK, n=10)
            k.cyl((s * 1.13, y, z), (s * 1.15, y, z), 0.09, 'iron_dark', n=6)
            if not front:
                B(k, s * 0.66, 1.0, z - 0.62, s * 1.22, 1.04, z + 0.62, 'iron_dark')             # parafango
        B(k, s * 0.70, 0.30, -3.08, s * 1.16, 1.0, -3.06, 'tyre')                                # paraspruzzi


truck('Borgo_Truck_Wreck', 39)

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

# ============================================================== SAGOMA DEGLI EDIFICI (fase 2)
def prism_z(k, poly, z0, z1, col):
    """poligono convesso nel piano XY estruso lungo Z"""
    f = [k.vert((x, y, z0)) for x, y in poly]
    b = [k.vert((x, y, z1)) for x, y in poly]
    k.face(list(reversed(f)), col)
    k.face(b, col)
    for j in range(len(poly)):
        i = (j + 1) % len(poly)
        k.face([f[j], f[i], b[i], b[j]], col)


def roof_line(z):
    """quota della falda di Bld_Roof_01 (sopra il piano d'appoggio) a una z locale del modulo"""
    return -0.06 + (min(0.48 - z, z + 9.49) / 4.98) * 1.84


# tavola di bordo sul timpano: stessa origine di Bld_Roof_01 (z 0.6..-9.6), spessa 7 cm verso +X
k = mk('Bld_Roof_Verge_01', 50)
for z in (0.62, -9.62):
    k.beam((0.035, roof_line(z) - 0.03, z), (0.035, 1.75, -4.5), 0.3, 0.07, 'wood_dark', up=(1, 0, 0))
B(k, -0.01, 1.72, -4.66, 0.09, 2.04, -4.34, 'wood_dark')                          # puntale al colmo
for z in (0.62, -9.62):
    B(k, -0.01, roof_line(z) - 0.26, z - 0.05, 0.09, roof_line(z) + 0.1, z + 0.05, 'wood_dark')

# comignolo dal pavimento (origine a terra al centro della canna, camino verso +X), alto 5.27 m per le case basse
k = mk('Bld_Chimney_01', 51)
B(k, -0.35, 0, -0.35, 0.35, 3.0, 0.35, 'plaster_borgo')                           # in casa: intonaco come i muri
B(k, -0.35, 3.0, -0.35, 0.35, 5.0, 0.35, 'brick_borgo')                           # sopra il soffitto: mattoni
y = 3.3
while y < 4.9:
    B(k, -0.355, y, -0.355, 0.355, y + 0.025, 0.355, 'mortar_borgo')
    y += 0.3
B(k, -0.42, 4.8, -0.42, 0.42, 4.95, 0.42, 'concrete_light')                         # cornice
B(k, -0.3, 4.95, -0.3, 0.3, 5.0, 0.3, 'soot')                                      # bocca annerita
for sx in (-1, 1):
    for sz in (-1, 1):
        B(k, sx * 0.34 - 0.05, 4.95, sz * 0.34 - 0.05, sx * 0.34 + 0.05, 5.15, sz * 0.34 + 0.05, 'concrete')
B(k, -0.46, 5.15, -0.46, 0.46, 5.27, 0.46, 'concrete_dark')                         # cappello
B(k, 0.30, 0, -0.56, 0.46, 1.15, 0.56, 'stone_light')                               # camino: cornice in pietra
B(k, 0.30, 0.06, -0.3, 0.465, 0.78, 0.3, 'soot')                                    # bocca del fuoco
B(k, 0.30, 1.15, -0.64, 0.58, 1.23, 0.64, 'wood_dark')                              # mensola
B(k, 0.30, 0, -0.62, 0.78, 0.05, 0.62, 'stone')                                     # focolare

# portico: origine sulla faccia esterna del muro (z = 0), al centro della porta; pali a x ±1.45
k = mk('Bld_Porch_01', 52)
for sx in (-1.45, 1.45):
    k.cbox((sx, 0.07, 1.5), (0.3, 0.14, 0.3), 'stone', ch=0.03)
    B(k, sx - 0.075, 0.14, 1.425, sx + 0.075, 2.6, 1.575, 'wood')
    k.beam((sx, 2.2, 1.5), (sx * 0.8, 2.56, 1.5), 0.08, 0.08, 'wood_dark', up=(0, 0, 1))
    k.beam((sx, 2.2, 1.5), (sx, 2.56, 1.15), 0.08, 0.08, 'wood_dark', up=(1, 0, 0))
B(k, -1.62, 2.52, 1.42, 1.62, 2.68, 1.58, 'wood_dark')                              # trave
B(k, -1.72, 2.6, 0.0, 1.72, 2.78, 0.08, 'wood_dark')                                # corrente sul muro
for x in (-1.5, -0.5, 0.5, 1.5):
    k.beam((x, 2.74, 0.06), (x, 2.62, 1.72), 0.07, 0.1, 'wood', up=(1, 0, 0))
k.push((0, 2.74, 0.9), (math.degrees(math.atan2(0.2, 1.85)), 0, 0))
k.box((0, 0.06, 0), (3.6, 0.06, 1.92), 'roof_grey_dark')
for i in range(6):
    k.box((-1.5 + i * 0.6, 0.1, 0), (0.05, 0.03, 1.92), 'roof_grey')                    # nervature della lamiera
k.pop()
B(k, -1.8, 2.5, 1.82, 1.8, 2.66, 1.88, 'paint_cream')                               # tavola di gronda

# pensilina sopra la porta: origine sulla faccia del muro, alla cima dell'architrave
k = mk('Bld_Door_Canopy_01', 53)
for s in (-1, 1):
    k.push((s * 0.43, 0.18, 0.46), (0, 0, -s * 22))
    k.box((0, 0, 0), (0.98, 0.06, 0.96), 'roof_grey_dark')
    k.pop()
    k.beam((s * 0.88, 0.0, 0.94), (0, 0.36, 0.94), 0.12, 0.05, 'paint_cream', up=(0, 0, 1))   # tavola del frontoncino
    k.beam((s * 0.66, -0.45, 0.02), (s * 0.66, 0.08, 0.82), 0.06, 0.06, 'iron', up=(1, 0, 0))  # mensole
B(k, -0.9, 0.0, 0.0, 0.9, 0.12, 0.06, 'wood_dark')


# persiane aperte ai lati della finestra: stessa origine del modulo finestra (x 0..3), vano x 0.85..2.15, y 1.0..2.25
def shutters(name, col, seed):
    k = mk(name, seed)
    for x0, x1 in ((0.14, 0.76), (2.24, 2.86)):
        B(k, x0, 1.0, 0.19, x1, 2.25, 0.215, col)
        for (a, b) in ((x0, x0 + 0.06), (x1 - 0.06, x1)):
            B(k, a, 1.0, 0.215, b, 2.25, 0.235, col)
        y = 1.1
        while y < 2.17:
            B(k, x0 + 0.06, y, 0.215, x1 - 0.06, y + 0.04, 0.232, col)
            y += 0.1
        for y in (1.25, 2.0):
            hx = x1 - 0.02 if x0 < 1 else x0 - 0.02
            B(k, hx, y, 0.19, hx + 0.04, y + 0.06, 0.24, 'iron_dark')                 # cardini


shutters('Bld_Shutters_Green_01', 'shutter_green', 54)
shutters('Bld_Shutters_Brown_01', 'shutter_brown', 55)
shutters('Bld_Shutters_Blue_01', 'shutter_blue', 56)

# gradino di pietra davanti alla porta: origine sulla faccia del muro, sporge 0.6 m
k = mk('Bld_Step_01', 57)
k.cbox((0, 0.05, 0.3), (2.2, 0.1, 0.6), 'stone', ch=0.025)
B(k, -1.1, 0.0, 0.0, 1.1, 0.102, 0.08, 'stone_dark')

# saracinesca arrotolata dell'officina: stessa origine del modulo muro (vano x 0..3, alto 2.3)
k = mk('Bld_Roll_Shutter_01', 58)
k.cbox((1.5, 2.46, 0.34), (3.0, 0.32, 0.32), 'iron_dark', ch=0.04)
B(k, 0.06, 2.3, 0.5, 2.94, 2.42, 0.54, 'corrugated')                                # ultima stecca, tutta su (sotto resta 2.3 m)
for x in (0.0, 2.93):
    B(k, x, 0.0, 0.17, x + 0.07, 2.3, 0.27, 'iron')
B(k, 1.3, 2.32, 0.54, 1.7, 2.36, 0.58, 'steel')                                    # maniglia


# frontone finto dei negozi: origine sul filo alto della facciata (y = 3*hs), al centro; pilastri fino a terra (hs 1.15)
def shop_front(name, body, trim, shape, seed):
    k = mk(name, seed)
    H = 3.45
    for sx in (-1, 1):
        B(k, sx * 5.82, -H, -0.05, sx * 6.22, 0.0, 0.24, trim)                     # pilastro d'angolo
        B(k, sx * 5.78, -H, -0.05, sx * 6.26, -H + 0.5, 0.24, 'concrete_dark')      # zoccolo del pilastro
    B(k, -6.22, -0.2, 0.19, 6.22, 0.0, 0.26, trim)                                   # fascia sopra le vetrine
    if shape == 'step':
        parts = [(-6.2, 6.2, 0.0, 0.85), (-3.6, 3.6, 0.85, 1.4), (-1.8, 1.8, 1.4, 1.9)]
    elif shape == 'flat':
        parts = [(-6.2, 6.2, 0.0, 1.35)]
    else:
        parts = [(-6.2, 6.2, 0.0, 0.85)]
    for (x0, x1, y0, y1) in parts:
        B(k, x0, y0, -0.12, x1, y1, 0.26, body)
        B(k, x0 - 0.06, y1 - 0.06, -0.14, x1 + 0.06, y1 + 0.06, 0.32, trim)            # cornice
    if shape == 'gable':
        prism_z(k, [(-4.0, 0.85), (4.0, 0.85), (0.0, 2.05)], -0.12, 0.26, body)
        for s in (-1, 1):
            k.beam((s * 4.15, 0.83, 0.11), (0, 2.13, 0.11), 0.12, 0.44, trim, up=(0, 0, 1))
        k.cbox((0, 1.4, 0.28), (0.7, 0.7, 0.06), 'paint_cream', ch=0.05)           # tondo nel timpano
    if shape == 'arch':
        arch = [(-3.0, 0.85), (-2.6, 1.3), (-1.8, 1.6), (-0.9, 1.75), (0.9, 1.75), (1.8, 1.6), (2.6, 1.3), (3.0, 0.85)]
        prism_z(k, arch, -0.12, 0.26, body)
        for a, b in zip(arch, arch[1:]):
            k.beam((a[0], a[1] + 0.02, 0.11), (b[0], b[1] + 0.02, 0.11), 0.1, 0.44, trim, up=(0, 0, 1))
    if shape == 'flat':
        for i in range(24):
            x = -5.9 + i * 0.513
            B(k, x, 1.1, 0.26, x + 0.18, 1.23, 0.32, trim)                             # dentelli
    for sx in (-1, 1):
        k.cbox((sx * 6.02, parts[0][3] + 0.25, 0.08), (0.34, 0.38, 0.34), trim, ch=0.04)   # pinnacoli agli angoli


shop_front('Bld_Shop_Front_01', 'plaster_borgo', 'concrete_light', 'step', 59)
shop_front('Bld_Shop_Front_02', 'plaster_ochre', 'paint_cream', 'gable', 60)
shop_front('Bld_Shop_Front_03', 'plaster_sage', 'paint_cream', 'flat', 61)
shop_front('Bld_Shop_Front_04', 'plaster_rose', 'concrete_light', 'arch', 62)

# ============================================================== CHIESA (fase 3)
# Navata 11 x 20 m (x +-5.5, z +-10), facciata a capanna verso +Z con portale ad arco, campanile a parte.
# Origine a terra al centro della navata; pavimento a y 0.1 come le case, sagrato in pendenza verso la via.
CH_H = 6.5                          # muri della navata
CH_R = 10.8                         # colmo
CH_S = (CH_R - (CH_H - 0.1)) / 5.95  # pendenza delle falde (gronda a x +-5.95)


def arch_fill(k, x0, x1, ys, w0, w1, col, axis='x', n=8):
    """riempie gli angoli sopra un arco a tutto sesto (vano x0..x1 che imposta a ys): strisce verticali fino alla chiave"""
    R = (x1 - x0) / 2
    cx, top = (x0 + x1) / 2, ys + R
    pts = [(cx - R * math.cos(math.pi * i / n), ys + R * math.sin(math.pi * i / n)) for i in range(n + 1)]
    for (ua, ya), (ub, yb) in zip(pts, pts[1:]):
        poly = [(ua, ya), (ub, yb), (ub, top), (ua, top)]
        if axis == 'x':
            prism_z(k, poly, w0, w1, col)
        else:
            k.prism_x([(y, u) for u, y in poly], w0, w1, col)
    return pts


def arch_ring(k, pts, w, axis='x', col='stone', t=0.16):
    """cornice in pietra lungo l'arco, sporgente sulla faccia w"""
    for (ua, ya), (ub, yb) in zip(pts, pts[1:]):
        p0 = (ua, ya + 0.02, w) if axis == 'x' else (w, ya + 0.02, ua)
        p1 = (ub, yb + 0.02, w) if axis == 'x' else (w, yb + 0.02, ub)
        k.beam(p0, p1, t, 0.12, col, up=(0, 0, 1) if axis == 'x' else (1, 0, 0))


def church_wall(k, u0, u1, h, w0, w1, holes, axis, col):
    """muro pieno meno i vani (u0..u1 lungo il muro, w0..w1 spessore); i vani con 'ys' hanno l'arco"""
    rect = [(a, b, c, d) for (a, b, c, d, ys) in holes]
    for (a, b, c, d) in rects(u0, u1, 0, h, rect):
        if axis == 'x':
            B(k, a, c, w0, b, d, w1, col)
        else:
            B(k, w0, c, a, w1, d, b, col)
    out = []
    for (a, b, c, d, ys) in holes:
        if ys is not None:
            out.append(arch_fill(k, a, b, ys, w0, w1, col, axis))
    return out


k = mk('Bld_Church_Nave_01', 70)
# pavimento in lastre, sagrato in pendenza verso la via
B(k, -5.5, 0.0, -10.0, 5.5, 0.1, 10.0, 'stone_dark')
for i in range(10):
    B(k, -5.1, 0.1, -9.6 + i * 1.92 + 0.02, 5.1, 0.104, -9.6 + i * 1.92 + 0.06, 'stone')       # fughe
B(k, -0.9, 0.1, -6.2, 0.9, 0.104, 9.6, 'cloth_red')                                          # passatoia nella navata
k.prism_x([(0.0, 12.2), (0.1, 10.6), (0.1, 10.0), (0.0, 10.0)], -2.6, 2.6, 'stone')
# presbiterio rialzato, raccordato alla navata da uno scivolo (uno scalino di 12 cm ferma giocatore e infetti), altare
B(k, -5.1, 0.1, -9.6, 5.1, 0.34, -6.6, 'stone_light')
k.prism_x([(0.1, -5.4), (0.34, -6.6), (0.1, -6.6)], -5.1, 5.1, 'stone')
B(k, -1.3, 0.34, -8.7, 1.3, 1.25, -7.7, 'stone_light')
B(k, -1.45, 1.25, -8.85, 1.45, 1.36, -7.55, 'stone')
B(k, -1.0, 1.36, -8.5, 1.0, 1.37, -7.9, 'cloth_white')
# facciata (z 9.6..10.0) col portale ad arco; retro (z -10..-9.6) con una finestra alta
port = [(-1.3, 1.3, 0.0, 4.4, 3.1)]
for pts in church_wall(k, -5.5, 5.5, CH_H, 9.6, 10.0, port, 'x', 'stone_light'):
    arch_ring(k, pts, 10.06, 'x', 'stone', 0.22)
for sx in (-1, 1):
    B(k, sx * 1.3, 0.0, 10.0, sx * 1.62, 3.1, 10.14, 'stone')                                # stipiti
    B(k, sx * 1.3, 0.1, 9.53, sx * 2.6, 3.0, 9.6, 'wood_dark')                                # ante aperte contro il muro
B(k, -0.24, 4.28, 10.0, 0.24, 4.62, 10.2, 'stone')                                          # chiave dell'arco
back = [(-0.6, 0.6, 2.4, 5.6, 5.0)]
for pts in church_wall(k, -5.5, 5.5, CH_H, -10.0, -9.6, back, 'x', 'stone_light'):
    arch_ring(k, pts, -10.06, 'x', 'stone', 0.14)
k.face([k.vert(p) for p in [(-0.6, 2.4, -9.8), (0.6, 2.4, -9.8), (0.6, 5.0, -9.8), (0.0, 5.6, -9.8), (-0.6, 5.0, -9.8)]], 'glass_dark')
B(k, -0.7, 2.3, -9.62, 0.7, 2.4, -9.4, 'stone')                                              # davanzale
# croce di legno sul muro di fondo, sotto la finestra
B(k, -0.07, 0.34, -9.6, 0.07, 2.2, -9.48, 'wood_dark')
B(k, -0.5, 1.55, -9.6, 0.5, 1.69, -9.48, 'wood_dark')
# fianchi con quattro finestre ad arco per parte (vetro scuro dentro il vano), contrafforti fra le finestre
WZ = (-7.0, -3.0, 1.0, 5.0)
for sx in (-1, 1):
    w0, w1 = sorted((sx * 5.1, sx * 5.5))
    holes = [(z - 0.5, z + 0.5, 2.3, 5.1, 4.6) for z in WZ]
    for pts in church_wall(k, -10.0, 10.0, CH_H, w0, w1, holes, 'z', 'stone_light'):
        arch_ring(k, pts, sx * 5.56, 'z', 'stone', 0.12)
    for z in WZ:
        B(k, sx * 5.08, 2.2, z - 0.62, sx * 5.68, 2.3, z + 0.62, 'stone')                    # davanzale
        k.face([k.vert(p) for p in [(sx * 5.3, 2.3, z - 0.5), (sx * 5.3, 2.3, z + 0.5), (sx * 5.3, 4.6, z + 0.5), (sx * 5.3, 5.1, z), (sx * 5.3, 4.6, z - 0.5)]], 'glass_dark')
        B(k, sx * 5.27, 2.3, z - 0.03, sx * 5.33, 5.0, z + 0.03, 'iron_dark')                 # piombo
    for z in (-9.0, -5.0, -1.0, 3.0):
        k.cbox((sx * 5.75, 1.6, z), (0.5, 3.2, 0.7), 'stone', ch=0.05)                         # contrafforti
    B(k, sx * 5.5, 0.0, -10.05, sx * 5.62, 0.6, 10.05, 'stone_dark')                         # zoccolo
# zoccolo e lesene della facciata, cornicione
for sx in (-1, 1):
    B(k, sx * 1.62, 0.0, 10.0, sx * 5.5, 0.6, 10.1, 'stone_dark')
    k.cbox((sx * 5.45, CH_H / 2, 9.95), (0.7, CH_H, 0.5), 'stone', ch=0.05)
B(k, -5.8, CH_H - 0.12, 9.95, 5.8, CH_H + 0.1, 10.24, 'stone')
# timpani: sotto le falde, con il bordo un po' dentro la lastra (da dentro niente cielo)
yb = lambda x: CH_R - abs(x) * CH_S - 0.25 + 0.06
for z0, z1 in ((9.6, 10.0), (-10.0, -9.6)):
    prism_z(k, [(-5.5, CH_H - 0.1), (5.5, CH_H - 0.1), (5.5, yb(5.5)), (0.0, yb(0.0)), (-5.5, yb(5.5))], z0, z1, 'stone_light')
# rosone sul timpano della facciata, croce in cima
k.cyl((0, 8.15, 10.0), (0, 8.15, 10.18), 1.05, 'stone', n=12)
k.cyl((0, 8.15, 10.0), (0, 8.15, 10.22), 0.8, 'glass_dark', n=12)
for a in range(4):
    ang = a * math.pi / 4
    k.beam((-math.cos(ang) * 0.8, 8.15 - math.sin(ang) * 0.8, 10.24), (math.cos(ang) * 0.8, 8.15 + math.sin(ang) * 0.8, 10.24), 0.06, 0.04, 'iron_dark', up=(0, 0, 1))
B(k, -0.09, CH_R + 0.05, 9.75, 0.09, CH_R + 1.6, 9.93, 'iron_dark')
B(k, -0.5, CH_R + 1.0, 9.75, 0.5, CH_R + 1.16, 9.93, 'iron_dark')
# tetto: due falde di ardesia, colmo; capriate a vista dentro
for sx in (-1, 1):
    poly = [(0.0, CH_R), (0.0, CH_R - 0.25), (sx * 5.95, CH_R - 5.95 * CH_S - 0.25), (sx * 5.95, CH_R - 5.95 * CH_S)]
    prism_z(k, poly, -10.4, 10.4, 'slate_dark')
    for i in range(5):
        x = sx * (0.8 + i * 1.1)
        k.beam((x, CH_R - abs(x) * CH_S + 0.005, -10.4), (x, CH_R - abs(x) * CH_S + 0.005, 10.4), 0.06, 0.03, 'slate', up=(0, 1, 0))   # filari
    B(k, sx * 5.95 - 0.06, CH_R - 5.95 * CH_S - 0.4, -10.45, sx * 5.95 + 0.06, CH_R - 5.95 * CH_S - 0.05, 10.45, 'wood_dark')   # gronda
B(k, -0.18, CH_R - 0.08, -10.45, 0.18, CH_R + 0.1, 10.45, 'slate')
for z in (-6.0, -2.0, 2.0, 6.0):
    k.beam((-5.1, CH_H - 0.05, z), (5.1, CH_H - 0.05, z), 0.22, 0.26, 'wood_dark', up=(0, 1, 0))             # catena
    k.beam((0, CH_H - 0.05, z), (0, CH_R - 0.25, z), 0.18, 0.18, 'wood_dark', up=(0, 0, 1))               # monaco
    for sx in (-1, 1):
        k.beam((sx * 5.1, CH_H + 0.05, z), (sx * 0.1, CH_R - 0.3, z), 0.18, 0.22, 'wood_dark', up=(0, 0, 1))   # puntoni

# campanile: 4.2 x 4.2, cella campanaria con quattro arcate e parapetto, cuspide fino a 23 m. Origine a terra al centro.
k = mk('Bld_Church_Tower_01', 71)
TW = 2.1
for side in range(4):
    k.push((0, 0, 0), (0, side * 90, 0))
    holes = [(-0.75, 0.75, 12.0, 14.35, 13.6), (-0.18, 0.18, 6.0, 7.4, 7.22)]
    for pts in church_wall(k, -TW, TW, 15.5, TW - 0.4, TW, holes, 'x', 'stone_light'):
        arch_ring(k, pts, TW + 0.06, 'x', 'stone', 0.14)
    B(k, -0.18, 6.0, TW - 0.22, 0.18, 7.2, TW - 0.18, 'glass_dark')                            # feritoia
    B(k, -0.95, 11.9, TW - 0.45, 0.95, 12.0, TW + 0.15, 'stone')                                # davanzale delle arcate
    for y0, y1 in ((0.0, 0.7), (5.5, 5.7), (11.0, 11.25), (15.3, 15.6)):
        B(k, -TW - 0.1, y0, TW, TW + 0.1, y1, TW + 0.1, 'stone' if y0 > 0 else 'stone_dark')   # zoccolo e marcapiani
    k.pop()
B(k, -TW + 0.4, 11.0, -TW + 0.4, TW - 0.4, 11.2, TW - 0.4, 'wood_dark')                        # piano della cella
B(k, -TW + 0.4, 5.5, -TW + 0.4, TW - 0.4, 5.7, TW - 0.4, 'wood_dark')
B(k, -1.5, 14.1, -0.09, 1.5, 14.3, 0.09, 'wood_dark')                                          # trave della campana
B(k, -TW - 0.15, 15.5, -TW - 0.15, TW + 0.15, 15.7, TW + 0.15, 'stone')
apex = k.vert((0, 22.0, 0))
base = [k.vert(p) for p in [(-2.2, 15.7, -2.2), (2.2, 15.7, -2.2), (2.2, 15.7, 2.2), (-2.2, 15.7, 2.2)]]
for i in range(4):
    k.face([base[i], base[(i + 1) % 4], apex], 'slate_dark')
k.face(list(reversed(base)), 'slate_dark')
B(k, -0.07, 21.7, -0.07, 0.07, 23.4, 0.07, 'iron_dark')
B(k, -0.45, 22.75, -0.07, 0.45, 22.89, 0.07, 'iron_dark')

# panca della chiesa: 3.4 m, seduta verso -Z (l'altare), schienale dietro, fianchi pieni. Origine a terra al centro.
k = mk('Prop_Church_Pew_01', 72)
B(k, -1.7, 0.42, -0.25, 1.7, 0.47, 0.2, 'wood')
B(k, -1.7, 0.47, 0.16, 1.7, 0.95, 0.22, 'wood')
B(k, -1.7, 0.86, 0.12, 1.7, 0.95, 0.26, 'wood_dark')
for sx in (-1, 1):
    B(k, sx * 1.7 - 0.05, 0.0, -0.28, sx * 1.7 + 0.05, 0.98, 0.26, 'wood_dark')
B(k, -1.6, 0.1, 0.18, 1.6, 0.2, 0.22, 'wood_dark')

# ============================================================== export
for name, k in pieces.items():
    if ONLY and f'SM_{name}' not in ONLY:
        continue
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    ob = kit.build(k, f'SM_{name}', mats)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=f'{OUT}/SM_{name}.glb', export_format='GLB', use_selection=True, export_yup=True,
                              export_materials='EXPORT', export_vertex_color='NONE')
    print('piece', name, kit.tris(ob))
