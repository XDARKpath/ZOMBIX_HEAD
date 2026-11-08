"""Kit originale di ZOMBIX HEAD, fatto da zero: cripta, Rocca, arredi, torcia, transenna, ascia runica, spada corta.

blender --background --factory-startup --python tools/castle_kit/build_castle_kit.py -- <cartella ZOMBIX_HEAD> [gruppo]

Si scrive in coordinate Godot (Y su, -Z nord). misure.json contiene solo gli ingombri (min/max) che il codice del gioco
si aspetta: i pezzi hanno gli stessi nomi e le stesse misure, nessuna geometria viene da altri modelli.
Colori piatti da un'unica texture di palette; le fiamme hanno un materiale emissivo a parte.
Uscita: art/zx_dungeon/dungeon_modules.glb, art/zx_rocca/rocca_modules.glb, art/env/wood/SM_Wood_*.glb,
art/env/mine/SM_Mine_Torch_0.glb, art/zx_borgo/SM_Prop_RoadBarrier_Small.glb, art/env/weapons/SM_Wep_RunicAxe|SpartanSword.glb
"""
import json, math, os, random, sys
import bpy, bmesh
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
PROJECT = ARGS[0]
HERE = os.path.dirname(os.path.abspath(__file__))
MIS = json.load(open(os.path.join(HERE, "misure.json")))

PAL = {
    "stone": (106, 102, 94), "stone2": (92, 89, 84), "stone3": (120, 114, 102), "stone_d": (62, 60, 58), "floor": (84, 80, 74), "floor2": (72, 69, 65),
    "moss": (74, 88, 52), "wood": (116, 82, 52), "wood2": (96, 66, 42), "wood_d": (66, 46, 32), "plank": (138, 104, 70),
    "iron": (70, 72, 76), "iron_d": (44, 45, 48), "rust": (122, 72, 44), "rust2": (92, 56, 38), "steel": (168, 172, 174), "brass": (168, 132, 66),
    "paper": (206, 192, 158), "wax": (222, 212, 180), "bone": (206, 196, 168), "cloth_r": (122, 40, 36), "cloth_b": (46, 66, 104), "cloth_g": (58, 84, 56),
    "cloth": (128, 112, 84), "leather": (84, 58, 40), "clay": (154, 94, 62), "glass": (150, 186, 180), "potion_g": (84, 170, 72), "potion_r": (178, 44, 50),
    "blood": (84, 18, 20), "food": (178, 126, 70), "meat": (150, 62, 56), "soot": (34, 32, 31), "orange": (216, 104, 36), "white": (206, 204, 196), "leaf": (66, 98, 54),
    "skin": (217, 164, 131), "sleeve": (107, 115, 69), "glove": (141, 138, 98),
}
NAMES = list(PAL)
GRID = 8
CELL = 32
assert len(NAMES) <= GRID * GRID


def build_materials():
    img = bpy.data.images.new("T_ZX_Kit_Palette", GRID * CELL, GRID * CELL, alpha=False)
    px = [0.0] * (GRID * CELL * GRID * CELL * 4)
    # Immagine a 8 bit: i valori di pixels sono già sRGB, nessuna conversione.
    def lin(c):
        return c / 255.0
    for i, name in enumerate(NAMES):
        r, g, b = PAL[name]
        cx, cy = i % GRID, i // GRID
        for y in range(cy * CELL, (cy + 1) * CELL):
            for x in range(cx * CELL, (cx + 1) * CELL):
                o = (y * GRID * CELL + x) * 4
                px[o:o + 4] = [lin(r), lin(g), lin(b), 1.0]
    img.pixels.foreach_set(px)
    img.pack()
    img.file_format = "PNG"
    mat = bpy.data.materials.new("M_ZX_Kit_Palette")
    mat.use_nodes = True
    node = mat.node_tree.nodes["Principled BSDF"]
    node.inputs["Roughness"].default_value = 0.88
    node.inputs["Metallic"].default_value = 0.0
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], node.inputs["Base Color"])
    ember = bpy.data.materials.new("M_ZX_Kit_Ember")
    ember.use_nodes = True
    n = ember.node_tree.nodes["Principled BSDF"]
    n.inputs["Base Color"].default_value = (1.0, 0.42, 0.08, 1)
    n.inputs["Emission Color"].default_value = (1.0, 0.42, 0.08, 1)
    n.inputs["Emission Strength"].default_value = 1.4
    return mat, ember


MAT, EMBER = build_materials()


def uv_of(color):
    i = NAMES.index(color)
    return ((i % GRID + 0.5) / GRID, (i // GRID + 0.5) / GRID)


class Piece:
    def __init__(self, name, seed=None):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()
        self.cm = None
        self.rnd = random.Random(seed if seed is not None else sum(map(ord, name)))

    def _paint(self, verts, color, bm=None):
        if bm is not None and bm is not self.bm:
            return
        faces = set(f for v in verts for f in v.link_faces)
        ember = color == "ember"
        uv = uv_of("orange" if ember else color)
        for f in faces:
            f.smooth = False
            f.material_index = 1 if ember else 0
            for loop in f.loops:
                loop[self.uv].uv = uv

    def _colbm(self):
        if self.cm is None:
            self.cm = bmesh.new()
        return self.cm

    def box(self, x0, y0, z0, x1, y1, z1, color="stone", solid=False, visible=True):
        cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
        sx, sy, sz = max(abs(x1 - x0), 1e-3), max(abs(y1 - y0), 1e-3), max(abs(z1 - z0), 1e-3)
        m = Matrix.Translation((cx, cy, cz)) @ Matrix.Diagonal((sx, sy, sz, 1))
        if visible:
            self._paint(bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)["verts"], color)
        if solid:
            bmesh.ops.create_cube(self._colbm(), size=1.0, matrix=m)

    def solid(self, x0, y0, z0, x1, y1, z1):
        self.box(x0, y0, z0, x1, y1, z1, solid=True, visible=False)

    def cyl(self, x, y0, z, r, y1, color="wood", sides=8, r2=None, axis="y"):
        """Cilindro o tronco di cono da y0 a y1 lungo l'asse scelto: (x, y0, z) è il centro della base."""
        depth = max(abs(y1 - y0), 1e-3)
        r2 = r if r2 is None else r2
        if axis == "y":
            m = Matrix.Translation((x, (y0 + y1) / 2, z)) @ Matrix.Rotation(-math.pi / 2, 4, "X")
        elif axis == "x":
            m = Matrix.Translation(((y0 + y1) / 2, x, z)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
        else:
            m = Matrix.Translation((x, z, (y0 + y1) / 2))
        v = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=sides, radius1=r, radius2=r2, depth=depth, matrix=m)["verts"]
        self._paint(v, color)

    def ball(self, x, y, z, r, color="stone", sub=1, sy=1.0):
        m = Matrix.Translation((x, y, z)) @ Matrix.Diagonal((1, sy, 1, 1))
        v = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=r, matrix=m)["verts"]
        self._paint(v, color)

    def prism(self, pts, z0, z1, color="stone", solid=False, visible=True):
        """Poligono convesso nel piano XY estruso da z0 a z1."""
        for bm, paint in ((self.bm, True) if visible else (None, False), (self._colbm(), False) if solid else (None, False)):
            if bm is None:
                continue
            a = [bm.verts.new((x, y, z0)) for x, y in pts]
            b = [bm.verts.new((x, y, z1)) for x, y in pts]
            n = len(pts)
            bm.faces.new(list(reversed(a)))
            bm.faces.new(b)
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new([a[i], a[j], b[j], b[i]])
            if paint:
                self._paint(a + b, color)

    def side_prism(self, pts, x0, x1, color="stone", solid=False):
        """Poligono convesso nel piano ZY estruso da x0 a x1 (per scale e cunei)."""
        for bm, paint in ((self.bm, True), (self._colbm(), False) if solid else (None, False)):
            if bm is None:
                continue
            a = [bm.verts.new((x0, y, z)) for z, y in pts]
            b = [bm.verts.new((x1, y, z)) for z, y in pts]
            n = len(pts)
            bm.faces.new(a)
            bm.faces.new(list(reversed(b)))
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new([a[j], a[i], b[i], b[j]])
            if paint:
                self._paint(a + b, color)

    def bounds(self):
        vs = [v.co for v in self.bm.verts]
        return [min(v[k] for v in vs) for k in range(3)], [max(v[k] for v in vs) for k in range(3)]

    def fit(self, lo, hi):
        """Porta il pezzo esattamente sull'ingombro richiesto (anche non uniforme)."""
        a, b = self.bounds()
        s = [(hi[k] - lo[k]) / max(b[k] - a[k], 1e-5) for k in range(3)]
        for v in self.bm.verts:
            v.co = Vector(tuple(lo[k] + (v.co[k] - a[k]) * s[k] for k in range(3)))

    def obj(self, at=(0, 0, 0), collection=None):
        """Crea l'oggetto: da Godot (x, y, z) a Blender (x, -z, y)."""
        to_blender = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        def make(bm, name, mats):
            bmesh.ops.transform(bm, matrix=to_blender, verts=bm.verts)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            me = bpy.data.meshes.new(name)
            bm.to_mesh(me)
            bm.free()
            for m in mats:
                me.materials.append(m)
            ob = bpy.data.objects.new(name, me)
            (collection or bpy.context.scene.collection).objects.link(ob)
            return ob
        ob = make(self.bm, self.name, [MAT, EMBER])
        ob.location = (at[0], -at[2], at[1])
        if self.cm is not None:
            col = make(self.cm, self.name + "_col-colonly", [])
            col.parent = ob
        return ob


# ===================================================================== muratura
def masonry(p, x0, x1, y0, y1, z0, z1, holes=(), course=0.52, block=1.05, moss=0.0, broken=0.0):
    """Muro a blocchi sfalsati su piano XY con spessore z0..z1: una base scura e pietre leggermente in rilievo."""
    p.box(x0, y0, z0 + 0.012, x1, y1, z1 - 0.012, "stone_d")
    y = y0
    row = 0
    while y < y1 - 1e-3:
        top = min(y + course, y1)
        x = x0
        first = True
        while x < x1 - 1e-3:
            w = block * (0.5 if first and row % 2 else p.rnd.uniform(0.85, 1.15))
            first = False
            end = min(x + w, x1)
            if x1 - end < 0.25:
                end = x1
            hit = any(x < h[1] and end > h[0] and y < h[3] and top > h[2] for h in holes)
            if not hit and p.rnd.random() >= broken:
                c = p.rnd.choice(["stone", "stone", "stone2", "stone3"])
                if p.rnd.random() < moss:
                    c = "moss"
                d = p.rnd.uniform(0.0, 0.012)
                p.box(x + 0.012, y + 0.012, z0 + d, end - 0.012, top - 0.012, z1 - d, c)
            x = end
        y = top
        row += 1


def wall_piece(name, half, z0, thick, window=False, moss=0.0, broken=0.0, seed=None):
    p = Piece(name, seed)
    holes = [(-0.55, 0.55, 1.5, 3.3)] if window else []
    masonry(p, -half, half, -0.2, 4.98, z0, z0 + thick, holes=(), moss=moss, broken=broken) if not window else None
    if window:
        # Parapetto, sguinci e arco della finestra: la collisione resta un muro pieno.
        masonry(p, -half, -0.55, -0.2, 4.98, z0, z0 + thick, moss=moss)
        masonry(p, 0.55, half, -0.2, 4.98, z0, z0 + thick, moss=moss)
        masonry(p, -0.55, 0.55, -0.2, 1.5, z0, z0 + thick)
        masonry(p, -0.55, 0.55, 3.6, 4.98, z0, z0 + thick)
        p.prism([(-0.55, 3.0), (0.0, 3.6), (-0.55, 3.6)], z0, z0 + thick, "stone3")
        p.prism([(0.55, 3.0), (0.55, 3.6), (0.0, 3.6)], z0, z0 + thick, "stone3")
        p.box(-0.68, 1.38, z0 - 0.05, 0.68, 1.5, z0 + thick + 0.1, "stone3")
        # Fondo scuro: la finestra è cieca, dietro c'è solo buio.
        p.box(-0.56, 1.5, z0 + 0.005, 0.56, 3.6, z0 + 0.03, "soot")
        for x in (-0.28, 0.0, 0.28):
            p.box(x - 0.015, 1.5, z0 + 0.06, x + 0.015, 3.4, z0 + 0.09, "iron_d")
        for y in (2.1, 2.8):
            p.box(-0.55, y - 0.015, z0 + 0.06, 0.55, y + 0.015, z0 + 0.09, "iron_d")
    p.solid(-half, -0.2, z0, half, 4.98, z0 + thick)
    return p


ARCH = (0.95, 1.55, 2.3, 2.66)   # semilarghezza, imposta, chiave, sommità della ghiera


def passage(name, half, wood=False):
    p = Piece(name)
    t = 0.3
    w, spring, apex, top = ARCH
    masonry(p, -half, -w, -0.2, top, -t, t, moss=0.02)
    masonry(p, w, half, -0.2, top, -t, t, moss=0.02)
    masonry(p, -half, half, top, 4.98, -t, t, moss=0.02)
    for s in (-1, 1):
        pts = [(s * w, spring), (s * w, top), (0, top), (0, apex)]
        p.prism(pts if s > 0 else list(reversed(pts)), -t, t, "wood2" if wood else "stone3", solid=True)
    p.solid(-half, -0.2, -t, -w, top, t)
    p.solid(w, -0.2, -t, half, top, t)
    p.solid(-half, top, -t, half, 4.98, t)
    if wood:
        for s in (-1, 1):
            p.box(s * w - 0.14 * (s > 0) - 0.02, -0.2, -t - 0.04, s * w + 0.14 * (s < 0) + 0.02, spring + 0.1, t + 0.04, "wood_d")
        p.box(-w - 0.1, spring + 0.75, -t - 0.05, w + 0.1, spring + 0.95, t + 0.05, "wood_d")
        for s in (-1, 1):
            p.box(s * 1.45 - 0.05, 2.9, -t - 0.09, s * 1.45 + 0.05, 3.0, t + 0.09, "iron_d")
    else:
        for s in (-1, 1):
            p.box(s * w + (0.06 if s > 0 else -0.2), -0.2, -t - 0.03, s * w + (0.2 if s > 0 else -0.06), spring, t + 0.03, "stone3")
    return p


def floor_tiles(p, hx, hz, y0=-0.13, top=0.0, pad=1.0):
    p.box(-hx, y0, -hz, hx, top - 0.02, hz, "stone_d")
    x = -hx
    while x < hx - 1e-3:
        z = -hz
        while z < hz - 1e-3:
            c = p.rnd.choice(["floor", "floor", "floor2"])
            p.box(x + 0.012, top - 0.02, z + 0.012, min(x + pad, hx) - 0.012, top - p.rnd.uniform(0.0, 0.004), min(z + pad, hz) - 0.012, c)
            z += pad
        x += pad
    p.solid(-hx, y0, -hz, hx, top, hz)


def rib(p, x0, x1, y0, y1, z0, z1, color="wood_d"):
    p.box(x0, y0, z0, x1, y1, z1, color)


# ===================================================================== moduli architettonici
def m_floor_tile():
    p = Piece("M_FloorTile")
    floor_tiles(p, 2, 2)
    return p


def m_straight(name="M_Straight", z0=-2.0, z1=2.0):
    p = Piece(name)
    if z0 == -2.0:
        floor_tiles(p, 2, 2)
    else:
        p.box(-2, -0.13, z0, 2, 0.0, z1, "floor")
        p.solid(-2, -0.13, z0, 2, 0.0, z1)
    prof = [(-2.0, 3.2), (-1.0, 3.55), (0.0, 3.76)]
    for i in range(2):
        for s in (-1, 1):
            a, b = prof[i], prof[i + 1]
            pts = [(s * a[0], a[1]), (s * b[0], b[1]), (s * b[0], 4.12), (s * a[0], 4.12)]
            p.prism(pts if s < 0 else list(reversed(pts)), z0, z1, "stone2" if i else "stone", solid=True)
    for z in (z0, z1 - 0.26):
        for i in range(2):
            for s in (-1, 1):
                a, b = prof[i], prof[i + 1]
                pts = [(s * a[0], a[1] - 0.14), (s * b[0], b[1] - 0.14), (s * b[0], b[1]), (s * a[0], a[1])]
                p.prism(pts if s < 0 else list(reversed(pts)), z, z + 0.26, "stone3")
    return p


def vault(p, half, low, high, top, ribs=True):
    """Soffitto a padiglione: lastra in alto e cornice inclinata lungo i quattro lati."""
    p.box(-half, high, -half, half, top, half, "stone2", solid=True)
    m = half * 0.55
    for a, b in ((-half, -m), (m, half)):
        s = -1 if a < 0 else 1
        pts = [(a, low if s < 0 else high), (b, high if s < 0 else low), (b, top), (a, top)]
        p.prism(pts, -half, half, "stone", solid=True)
        pts2 = [(a, low if s < 0 else high), (b, high if s < 0 else low), (b, top), (a, top)]
        p.side_prism(list(reversed(pts2)), -half, half, "stone", solid=True)
    if ribs:
        p.box(-half, high - 0.16, -0.1, half, high, 0.1, "wood_d")
        p.box(-0.1, high - 0.16, -half, 0.1, high, half, "wood_d")
        p.box(-0.32, high - 0.22, -0.32, 0.32, high - 0.02, 0.32, "iron_d")


def m_crossing():
    p = Piece("M_Crossing")
    floor_tiles(p, 2, 2)
    vault(p, 2.0, 3.62, 3.92, 4.12)
    return p


def m_custom_center():
    p = Piece("M_CustomCenter")
    floor_tiles(p, 2, 2)
    vault(p, 2.0, 4.02, 4.26, 4.36)
    return p


def m_big():
    p = Piece("M_Big")
    floor_tiles(p, 4, 4, pad=1.33333)
    vault(p, 4.0, 4.06, 4.5, 4.69)
    return p


def m_pillar():
    p = Piece("M_Pillar")
    p.box(-0.405, -0.23, -0.405, 0.405, 0.1, 0.405, "stone3")
    p.box(-0.34, 0.1, -0.34, 0.34, 0.32, 0.34, "stone")
    p.box(-0.27, 0.32, -0.27, 0.27, 4.55, 0.27, "stone2")
    y = 0.6
    while y < 4.4:
        p.box(-0.285, y, -0.285, 0.285, y + 0.09, 0.285, "stone")
        y += 0.82
    p.box(-0.34, 4.55, -0.34, 0.34, 4.75, 0.34, "stone")
    p.box(-0.405, 4.75, -0.405, 0.405, 4.99, 0.405, "stone3")
    p.solid(-0.3, -0.23, -0.3, 0.3, 4.99, 0.3)
    return p


def m_stairs(name, base, bottom):
    p = Piece(name)
    n = 8
    for i in range(n):
        top = base + (i + 1) * 0.3125
        z1 = 2.0 - i * 0.5
        z0 = z1 - 0.5
        p.box(-2.0, bottom, z0, 2.0, top - 0.05, z1, "stone2", solid=True)
        p.box(-2.0, top - 0.05, z0, 2.0, top, z1 + 0.035, p.rnd.choice(["stone3", "stone"]))
        p.solid(-2.0, top - 0.05, z0, 2.0, top, z1)
    for s in (-1, 1):
        x0, x1 = (2.0, 2.1) if s > 0 else (-2.1, -2.0)
        p.side_prism([(2.05, bottom), (2.05, base + 0.34), (-2.05, base + 2.6), (-2.05, bottom)], x0, x1, "stone_d")
    return p


def m_steps():
    p = Piece("M_Steps")
    for i in range(3):
        top = (i + 1) / 3.0
        z1 = 0.86 - i * 0.62
        p.box(-1, 0, -1.0, 1, top, z1, "stone3" if i % 2 else "stone", solid=True)
    return p


def m_platform():
    p = Piece("M_StairsPlatform")
    for s in (-1, 1):
        for t in (-1, 1):
            p.box(s * 1.6 - 0.42, -0.02, t * 1.6 - 0.42, s * 1.6 + 0.42, 2.36, t * 1.6 + 0.42, "stone2")
    masonry(p, -2.07, 2.08, -0.02, 2.36, -2.08, -1.86)
    masonry(p, -2.07, 2.08, -0.02, 2.36, 1.86, 2.08)
    p.box(-2.0, -0.02, -1.9, -1.86, 2.36, 1.9, "stone")
    p.box(1.86, -0.02, -1.9, 2.0, 2.36, 1.9, "stone")
    p.box(-2.09, 2.36, -2.08, 2.06, 2.51, 2.08, "stone3")
    p.solid(-2.0, -0.02, -2.0, 2.0, 2.5, 2.0)
    return p


def m_staircase():
    """Chiocciola: i gradini seguono la rampa invisibile di rocca.gd (rotazione -90 gradi alla posa). Pianerottolo a 5 m su un quadrante."""
    p = Piece("M_Staircase")
    p.cyl(0, -0.23, 0, 0.42, 9.0, "stone", sides=10)
    p.cyl(0, 4.6, 0, 0.5, 5.0, "stone3", sides=10)
    a = 240.0
    while a < 810:
        h = min(5.0, max(0.0, 0.2 + (a - 270.0) * 0.0089))
        a0, a1 = math.radians(a - 1), math.radians(a + 11)
        pts = []
        for ang, r in ((a0, 0.4), (a0, 2.02), (a1, 2.02), (a1, 0.4)):
            pts.append((r * math.sin(ang), -r * math.cos(ang)))
        for bm_y0, bm_y1, col in ((h - 0.14, h, "stone3" if int(a) % 20 == 0 else "stone"), (h - 0.34, h - 0.14, "stone_d")):
            top = [p.bm.verts.new((x, bm_y1, z)) for x, z in pts]
            bot = [p.bm.verts.new((x, bm_y0, z)) for x, z in pts]
            p.bm.faces.new(top)
            p.bm.faces.new(list(reversed(bot)))
            for i in range(4):
                j = (i + 1) % 4
                p.bm.faces.new([top[j], top[i], bot[i], bot[j]])
            p._paint(top + bot, col)
        a += 10
    p.box(0.0, 4.84, 0.0, 2.05, 5.0, 2.05, "floor")
    p.box(0.0, 4.68, 0.0, 2.05, 4.84, 2.05, "stone_d")
    p.solid(0.0, 4.68, 0.0, 2.05, 5.0, 2.05)
    p.box(-2.08, 9.2, -2.04, 2.08, 9.8, 2.31, "stone2", solid=True)
    p.box(-0.1, 8.95, -2.04, 0.1, 9.2, 2.31, "wood_d")
    p.box(-2.08, 8.95, -0.1, 2.08, 9.2, 0.1, "wood_d")
    return p


def bars(p, x0, x1, y0, y1, z, step=0.25, r=0.016, color="iron_d", z_of=None):
    x = x0 + step / 2
    while x < x1:
        zz = z_of(x) if z_of else z
        p.box(x - r, y0, zz - r, x + r, y1, zz + r, color)
        x += step


def m_jail(name):
    p = Piece(name)
    gate = name != "M_JailWall"
    p.box(-2.0, -0.04, -0.08, 2.0, 0.12, 0.09, "stone3")
    p.box(-2.0, 2.98, -0.08, 2.0, 3.14, 0.09, "iron_d")
    p.box(-2.0, 1.5, -0.03, 2.0, 1.56, 0.03, "iron")
    if gate:
        for s in (-1, 1):
            a, b = (0.85, 2.0) if s > 0 else (-2.0, -0.85)
            bars(p, a, b, 0.1, 3.0, 0.0)
            p.box(s * 0.85 - 0.05, 0.0, -0.07, s * 0.85 + 0.05, 3.0, 0.07, "iron")
            p.solid(a, -0.04, -0.08, b, 3.14, 0.09)
        p.box(-0.85, 2.14, -0.06, 0.85, 2.22, 0.06, "iron")
        bars(p, -0.85, 0.85, 2.2, 3.0, 0.0)
        p.solid(-0.85, 2.14, -0.08, 0.85, 3.14, 0.09)
    else:
        bars(p, -2.0, 2.0, 0.1, 3.0, 0.0)
        p.solid(-2.0, -0.04, -0.08, 2.0, 3.14, 0.09)
    if name == "M_JailBroken":
        # Barre piegate e strappate verso la cella, appoggiate a terra.
        for i, (x, zz) in enumerate(((-0.55, 0.3), (-0.2, 0.55), (0.18, 0.72), (0.52, 0.42))):
            p.box(x - 0.018, -0.02, zz, x + 0.018, 0.02 + 0.14 * i, zz + 0.16, "rust")
            p.box(x - 0.016, 0.02, zz - 0.32, x + 0.016, 0.1, zz, "rust2")
        p.box(-0.72, -0.04, 0.74, 0.72, 0.03, 0.86, "iron_d")
    return p


def m_jail_door(name, side):
    p = Piece(name)
    lo, hi = (-0.06, 1.24) if side > 0 else (-1.24, 0.06)
    bars(p, lo + 0.08, hi - 0.08, 0.1, 2.14, 0.0, step=0.22)
    for y in (0.08, 1.05, 2.1):
        p.box(lo, y, -0.04, hi, y + 0.08, 0.05, "iron")
    p.box(lo, 0.06, -0.06, lo + 0.08, 2.18, 0.05, "iron")
    p.box(hi - 0.08, 0.06, -0.06, hi, 2.18, 0.05, "iron")
    p.solid(lo, 0.06, -0.06, hi, 2.18, 0.05)
    return p


def m_door_iron(name, side):
    p = Piece(name)
    lo, hi = (0.0, 1.34) if side > 0 else (-1.34, 0.0)
    p.box(lo, 0.05, 0.03, hi, 2.17, 0.13, "iron", solid=True)
    for y in (0.12, 0.72, 1.32, 1.92):
        p.box(lo, y, 0.0, hi, y + 0.14, 0.16, "iron_d")
        x = lo + 0.12
        while x < hi:
            p.box(x - 0.02, y + 0.05, -0.012, x + 0.02, y + 0.09, 0.172, "rust")
            x += 0.28
    hx = hi - 0.14 if side > 0 else lo + 0.14
    p.cyl(hx, 1.05, 0.16, 0.05, 1.05, "brass", axis="z")
    return p


def m_gate_wood(name, side):
    p = Piece(name)
    lo, hi = (-0.04, 1.69) if side > 0 else (-1.69, 0.04)
    x = lo
    while x < hi - 1e-3:
        e = min(x + 0.28, hi)
        p.box(x + 0.006, 0.01, -0.07, e - 0.006, 3.7, 0.09, p.rnd.choice(["wood", "wood2", "plank"]))
        x = e
    for y in (0.4, 1.6, 2.8):
        p.box(lo, y, -0.11, hi, y + 0.14, 0.24, "iron_d")
    p.solid(lo, 0.01, -0.07, hi, 3.7, 0.09)
    return p


def m_portcullis(name, half, color, tip):
    p = Piece(name)
    r = 0.045 if color != "iron_d" else 0.03
    x = -half + 0.2
    while x < half:
        p.box(x - r, 0.14, -r, x + r, 3.88, r, color)
        p.cyl(x, 0.01, 0, r, 0.14, tip, sides=4, r2=r)
        x += 0.42
    y = 0.5
    while y < 3.8:
        p.box(-half, y - r, -r * 0.8, half, y + r, r * 0.8, color)
        y += 0.6
    p.solid(-half, 0.01, -0.05, half, 3.89, 0.05)
    return p


def m_balcony():
    p = Piece("M_Balcony")
    x = -1.98
    while x < 1.97:
        e = min(x + 0.44, 1.98)
        p.box(x + 0.006, -0.08, -1.99, e - 0.006, 0.02, 1.99, p.rnd.choice(["wood", "wood2", "plank"]))
        x = e
    for z in (-1.4, 0.0, 1.4):
        p.box(-1.98, -0.23, z - 0.09, 1.98, -0.08, z + 0.09, "wood_d")
    p.solid(-1.98, -0.23, -1.99, 1.98, 0.0, 1.99)
    return p


def m_balcony_post():
    p = Piece("M_BalconyPost")
    p.box(-0.185, -0.23, -0.185, 0.185, 0.1, 0.185, "wood_d")
    p.box(-0.12, 0.1, -0.12, 0.12, 1.08, 0.12, "wood")
    p.box(-0.17, 1.08, -0.17, 0.17, 1.26, 0.17, "wood_d")
    p.solid(-0.12, -0.23, -0.12, 0.12, 1.26, 0.12)
    return p


def m_balcony_rail():
    p = Piece("M_BalconyRailing")
    p.box(-1.9, 0.8, -0.1, 1.9, 0.91, 0.1, "wood_d")
    p.box(-1.9, 0.09, -0.06, 1.9, 0.18, 0.06, "wood_d")
    x = -1.75
    while x < 1.8:
        p.box(x - 0.04, 0.18, -0.04, x + 0.04, 0.8, 0.04, "wood")
        x += 0.35
    p.solid(-1.9, 0.09, -0.1, 1.9, 0.91, 0.1)
    return p


# ===================================================================== oggetti (scritti nel cubo unitario, poi portati sull'ingombro)
def barrel(p, wood="wood", hoop="iron_d", open_top=False):
    p.cyl(0, 0, 0, 0.42, 0.12, wood, sides=10, r2=0.47)
    p.cyl(0, 0.12, 0, 0.47, 0.5, wood, sides=10, r2=0.5)
    p.cyl(0, 0.5, 0, 0.5, 0.88, wood, sides=10, r2=0.47)
    p.cyl(0, 0.88, 0, 0.47, 1.0, wood, sides=10, r2=0.42)
    for y, r in ((0.17, 0.485), (0.8, 0.49)):
        p.cyl(0, y, 0, r, y + 0.06, hoop, sides=10)
    if open_top:
        p.cyl(0, 0.9, 0, 0.36, 0.99, "soot", sides=10)
    else:
        p.cyl(0, 0.985, 0, 0.38, 1.0, "wood2", sides=10)


def legs(p, h, x=0.42, z=0.42, r=0.05, color="wood_d"):
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box(sx * x - r, 0, sz * z - r, sx * x + r, h, sz * z + r, color)


def chair(p, back=True, c="wood"):
    legs(p, 0.46, 0.42, 0.42, 0.05, "wood_d")
    p.box(-0.5, 0.46, -0.5, 0.5, 0.53, 0.5, c)
    if back:
        for x in (-0.42, 0.42):
            p.box(x - 0.05, 0.53, 0.37, x + 0.05, 1.0, 0.47, "wood_d")
        for y in (0.68, 0.83):
            p.box(-0.42, y, 0.39, 0.42, y + 0.09, 0.45, c)


def table(p, big=True):
    legs(p, 0.88, 0.44, 0.4, 0.045 if big else 0.06, "wood_d")
    n = 5 if big else 4
    w = 1.0 / n
    for i in range(n):
        p.box(-0.5 + i * w + 0.003, 0.88, -0.5, -0.5 + (i + 1) * w - 0.003, 1.0, 0.5, p.rnd.choice(["wood", "plank", "wood2"]))
    p.box(-0.44, 0.74, -0.03, 0.44, 0.8, 0.03, "wood_d")


def shelves(p, boards=4, depth=0.5, books=True):
    for s in (-1, 1):
        p.box(s * 0.5 - 0.035, 0, -depth, s * 0.5 + 0.035, 1, depth, "wood_d")
    for i in range(boards):
        y = 0.04 + i * (0.92 / (boards - 1))
        p.box(-0.5, y, -depth, 0.5, y + 0.03, depth, "wood")
        if books and i < boards - 1:
            x = -0.45
            while x < 0.3:
                w = p.rnd.uniform(0.05, 0.12)
                p.box(x, y + 0.03, -depth * 0.6, x + w, y + p.rnd.uniform(0.12, 0.2), depth * 0.6, p.rnd.choice(["cloth_r", "cloth_b", "cloth_g", "leather", "paper"]))
                x += w + 0.01
    p.box(-0.5, 0, depth - 0.03, 0.5, 1, depth, "wood2")


def crate(p, open_top=False):
    for y0, y1 in ((0, 0.1), (0.9, 1.0)):
        for x in (-0.46, 0.46):
            p.box(x - 0.05, y0, -0.5, x + 0.05, y1, 0.5, "wood_d")
        for z in (-0.46, 0.46):
            p.box(-0.5, y0, z - 0.05, 0.5, y1, z + 0.05, "wood_d")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.box(sx * 0.46 - 0.05, 0, sz * 0.46 - 0.05, sx * 0.46 + 0.05, 1, sz * 0.46 + 0.05, "wood_d")
    h = 0.82 if open_top else 0.98
    p.box(-0.44, 0.08, -0.44, 0.44, h, 0.44, "plank" if not open_top else "soot")
    if open_top:
        p.box(-0.5, 0.06, -0.46, 0.5, 0.72, -0.43, "plank")
        p.box(-0.5, 0.06, 0.43, 0.5, 0.72, 0.46, "plank")


def basket(p, r0=0.34, r1=0.5, handle=False):
    n = 4
    for i in range(n):
        y0, y1 = i / n * 0.78, (i + 1) / n * 0.78
        p.cyl(0, y0, 0, r0 + (r1 - r0) * i / n, y1, "wood2" if i % 2 else "plank", sides=8, r2=r0 + (r1 - r0) * (i + 1) / n)
    p.cyl(0, 0.68, 0, r1 * 0.86, 0.79, "soot", sides=8)
    if handle:
        for s in (-1, 1):
            p.box(s * r1 * 0.82 - 0.03, 0.72, -0.03, s * r1 * 0.82 + 0.03, 0.98, 0.03, "wood_d")
        p.box(-r1 * 0.82, 0.94, -0.03, r1 * 0.82, 1.0, 0.03, "wood_d")


def vessel(p, color, belly=0.5, neck=0.22, foot=0.3, lid=None):
    p.cyl(0, 0, 0, foot, 0.25, color, sides=8, r2=belly)
    p.cyl(0, 0.25, 0, belly, 0.55, color, sides=8, r2=belly * 0.92)
    p.cyl(0, 0.55, 0, belly * 0.92, 0.78, color, sides=8, r2=neck)
    p.cyl(0, 0.78, 0, neck, 1.0, color, sides=8, r2=neck * 1.2)
    if lid:
        p.cyl(0, 0.92, 0, neck * 0.9, 1.0, lid, sides=8)


def candle(p, x, z, y0, y1, r=0.05):
    p.cyl(x, y0, z, r, y1 - 0.08, "wax", sides=6)
    p.cyl(x, y1 - 0.08, z, r * 0.7, y1, "ember", sides=4, r2=0.001)


def flame_bowl(p, y):
    p.cyl(0, y, 0, 0.5, y + 0.1, "iron_d", sides=6, r2=0.7)
    p.cyl(0, y + 0.08, 0, 0.5, y + 0.26, "ember", sides=5, r2=0.02)


def cauldron(p, full=True):
    p.cyl(0, 0.05, 0, 0.26, 0.26, "iron_d", sides=10, r2=0.48)
    p.cyl(0, 0.26, 0, 0.48, 0.62, "iron", sides=10, r2=0.5)
    p.cyl(0, 0.62, 0, 0.42, 0.68, "iron_d", sides=10, r2=0.46)
    p.cyl(0, 0.6, 0, 0.42, 0.665, "potion_g" if full else "soot", sides=10)
    for s in (-1, 1):
        p.box(s * 0.5 - 0.02, 0.5, -0.06, s * 0.5 + 0.03, 0.66, 0.06, "iron_d")
    for a in (0.5, 2.6, 4.7):
        p.box(math.cos(a) * 0.3 - 0.04, 0, math.sin(a) * 0.3 - 0.04, math.cos(a) * 0.3 + 0.04, 0.2, math.sin(a) * 0.3 + 0.04, "iron_d")
    if full:
        p.box(0.28, 0.6, -0.04, 0.34, 1.0, 0.02, "wood")


def book(p, cover="leather", opened=True):
    if opened:
        for s in (-1, 1):
            a, b = (0.01, 0.5) if s > 0 else (-0.5, -0.01)
            p.box(a, 0, -0.5, b, 0.25, 0.5, cover)
            p.box(a + 0.01, 0.25, -0.46, b - 0.01, 1.0 if abs(a) < 0 else 0.8, 0.46, "paper")
    else:
        p.box(-0.5, 0, -0.5, 0.5, 1, 0.5, cover)
        p.box(-0.42, 0.04, -0.46, 0.5, 0.96, 0.46, "paper")
        p.box(-0.5, 0, -0.5, -0.38, 1, 0.5, cover)


def rack(p, tall):
    h = 1.0
    for s in (-1, 1):
        p.box(s * 0.46 - 0.04, 0, -0.5, s * 0.46 + 0.04, 0.08, 0.5, "wood_d")
        p.box(s * 0.46 - 0.04, 0, -0.04, s * 0.46 + 0.04, h, 0.04, "wood")
    p.box(-0.5, h * 0.82, -0.04, 0.5, h * 0.88, 0.04, "wood_d")
    p.box(-0.5, h * 0.35, -0.12, 0.5, h * 0.4, 0.12, "wood_d")
    for x in (-0.32, -0.12, 0.08, 0.28):
        p.box(x - 0.012, 0.08, -0.012, x + 0.012, h if tall else h * 0.92, 0.012, "wood2")
        p.box(x - 0.03, h * 0.86, -0.008, x + 0.03, h, 0.008, "steel")


def stove(p, fire=True):
    masonry(p, -0.5, 0.5, 0, 0.38, 0, 0.04, course=0.1, block=0.28)
    p.box(-0.5, 0, 0, -0.26, 0.4, 1.0, "stone")
    p.box(0.26, 0, 0, 0.5, 0.4, 1.0, "stone")
    p.box(-0.26, 0, 0.6, 0.26, 0.28, 1.0, "soot")
    p.box(-0.26, 0.28, 0, 0.26, 0.4, 1.0, "stone2")
    p.box(-0.54, 0.4, 0, 0.54, 0.46, 1.0, "stone3")
    p.box(-0.3, 0.46, 0.3, 0.3, 1.0, 0.92, "stone2")
    if fire:
        p.box(-0.18, 0, 0.45, 0.18, 0.04, 0.9, "wood_d")
        p.cyl(0, 0.03, 0.72, 0.13, 0.17, "ember", sides=5, r2=0.01)


def weapon_blade(p, n=1):
    p.box(-0.1, 0.0, -0.3, 0.1, 0.72, 0.3, "steel")
    p.box(-0.35, 0.72, -0.5, 0.35, 0.76, 0.5, "brass")
    p.box(-0.1, 0.76, -0.25, 0.1, 1.0, 0.25, "leather")


def wall_torch(p):
    p.box(-0.25, 0.4, 0, 0.25, 0.6, 0.12, "iron_d")
    p.box(-0.1, 0.45, 0.12, 0.1, 0.53, 0.75, "iron_d")
    p.cyl(0, 0.22, 0.72, 0.17, 0.76, "wood_d", sides=6, r2=0.25)
    p.cyl(0, 0.76, 0.72, 0.28, 1.0, "ember", sides=5, r2=0.03)


def post_torch(p):
    p.cyl(0, 0, 0, 0.09, 0.78, "wood_d", sides=6, r2=0.07)
    for s in (-1, 1):
        p.box(s * 0.11 - 0.03, 0.62, -0.03, s * 0.11 + 0.03, 0.74, 0.03, "iron_d")
    p.cyl(0, 0.72, 0, 0.11, 0.8, "iron_d", sides=6, r2=0.16)
    p.cyl(0, 0.79, 0, 0.14, 1.0, "ember", sides=5, r2=0.02)


def stairs_wood(p):
    for s in (-1, 1):
        p.side_prism([(0.52, 0), (0.46, 0), (-0.5, 0.96), (-0.5, 1.0)], s * 0.47 - 0.03, s * 0.47 + 0.03, "wood_d")
    for i in range(14):
        t = i / 13.0
        y = t * 0.97
        z = 0.48 - t * 0.97
        p.box(-0.45, y, z - 0.035, 0.45, y + 0.012, z + 0.035, p.rnd.choice(["wood", "plank", "wood2"]))


PROPS = {}


def prop(name):
    def deco(fn):
        PROPS[name] = fn
        return fn
    return deco


def define_props():
    def add(name, fn):
        PROPS[name] = fn

    add("P_BarrelClosed", lambda p: barrel(p))
    add("P_BarrelOpen", lambda p: barrel(p, open_top=True))

    def barrel_big(p):
        p.cyl(0, 0.2, 0, 0.42, 0.28, "wood", axis="x") if False else None
        for s in (-1, 1):
            p.box(-0.5, 0, s * 0.42 - 0.05, 0.5, 0.2, s * 0.42 + 0.05, "wood_d")
        n = 10
        for i in range(n):
            a0, a1 = i / n * math.tau, (i + 1) / n * math.tau
            r = 0.5
            cy = 0.55
            pts = [(r * 0.7 * math.cos(a0), cy + r * 0.8 * math.sin(a0)), (r * math.cos(a0), cy + r * 0.9 * math.sin(a0)),
                   (r * math.cos(a1), cy + r * 0.9 * math.sin(a1)), (r * 0.7 * math.cos(a1), cy + r * 0.8 * math.sin(a1))]
            p.prism(pts, -0.5, 0.5, "wood" if i % 2 else "wood2")
        p.cyl(0.55, -0.2, 0, 0.36, 0.5, "wood2", axis="z") if False else None
        p.box(-0.08, 0.5, 0.48, 0.08, 0.68, 0.5, "iron_d")
    add("P_BarrelBig", barrel_big)
    add("P_Bench", lambda p: (legs(p, 0.42, 0.44, 0.3, 0.04), p.box(-0.5, 0.42, -0.5, 0.5, 0.5, 0.5, "wood"), [p.box(x - 0.04, 0.5, 0.36, x + 0.04, 1.0, 0.46, "wood_d") for x in (-0.44, 0.44)], p.box(-0.5, 0.82, 0.38, 0.5, 0.94, 0.45, "wood")))
    add("P_Chair", lambda p: chair(p))
    add("P_Stool", lambda p: (p.cyl(0, 0.84, 0, 0.5, 1.0, "wood", sides=8), [p.box(math.cos(a) * 0.34 - 0.05, 0, math.sin(a) * 0.34 - 0.05, math.cos(a) * 0.34 + 0.05, 0.84, math.sin(a) * 0.34 + 0.05, "wood_d") for a in (0.6, 2.7, 4.8)]))
    add("P_StoolSquare", lambda p: (legs(p, 0.84, 0.4, 0.4, 0.06), p.box(-0.5, 0.84, -0.5, 0.5, 1.0, 0.5, "wood")))
    add("P_TableBig", lambda p: table(p, True))

    def table_small(p):
        table(p, False)
    add("P_TableSmall", table_small)

    def desk(p):
        p.box(-0.5, 0.0, -0.5, -0.28, 0.5, 0.5, "wood2")
        p.box(0.28, 0.0, -0.5, 0.5, 0.5, 0.5, "wood2")
        p.box(-0.5, 0.5, -0.5, 0.5, 0.56, 0.5, "wood")
        for y in (0.1, 0.28):
            p.box(0.31, y, 0.5, 0.47, y + 0.14, 0.52, "wood_d")
            p.box(-0.47, y, 0.5, -0.31, y + 0.14, 0.52, "wood_d")
        p.box(-0.5, 0.56, -0.5, 0.5, 1.0, -0.42, "wood_d")
        for y in (0.68, 0.84):
            p.box(-0.5, y, -0.5, 0.5, y + 0.02, -0.26, "wood2")
    add("P_Desk", desk)

    def throne(p):
        p.box(-0.5, 0, -0.5, 0.5, 0.1, 0.5, "stone3")
        p.box(-0.42, 0.1, -0.44, 0.42, 0.36, 0.42, "wood_d")
        p.box(-0.36, 0.36, -0.42, 0.36, 0.4, 0.34, "cloth_r")
        p.box(-0.42, 0.36, 0.34, 0.42, 1.0, 0.46, "wood_d")
        p.box(-0.3, 0.42, 0.32, 0.3, 0.86, 0.34, "cloth_r")
        for s in (-1, 1):
            p.box(s * 0.42 - 0.07, 0.36, -0.42, s * 0.42 + 0.07, 0.58, 0.34, "wood")
            p.box(s * 0.42 - 0.05, 0.88, 0.36, s * 0.42 + 0.05, 1.0, 0.46, "brass")
    add("P_Throne", throne)
    add("P_Shelf", lambda p: shelves(p, 4, 0.5, True))

    def shelf_wall(p):
        p.box(-0.5, 0.56, 0, 0.5, 0.66, 1.0, "wood")
        for x in (-0.4, 0.4):
            p.side_prism([(0, 0.0), (0, 0.56), (0.9, 0.56)], x - 0.03, x + 0.03, "wood_d")
        p.box(-0.42, 0.66, 0.2, -0.28, 0.98, 0.8, "cloth_r")
        p.box(-0.28, 0.66, 0.2, -0.16, 1.0, 0.8, "cloth_b")
        p.cyl(0.2, 0.66, 0.5, 0.1, 0.9, "clay", sides=6)
    add("P_ShelfWall", shelf_wall)
    add("P_Chest", lambda p: (p.box(-0.5, 0, -0.5, 0.5, 1, 0.5, "wood"), [p.box(x - 0.05, 0, -0.52, x + 0.05, 1, 0.52, "iron_d") for x in (-0.36, 0.36)], p.box(-0.5, 0.82, -0.52, 0.5, 1, 0.52, "iron")))

    def lid(p):
        p.box(-0.5, 0, 0, 0.5, 0.5, 1.0, "wood2")
        p.prism([(-0.5, 0.5), (0.5, 0.5), (0.5, 0.82), (0.26, 1.0), (-0.26, 1.0), (-0.5, 0.82)], 0, 1.0, "wood")
        for x in (-0.36, 0.36):
            p.box(x - 0.05, 0, -0.01, x + 0.05, 0.98, 1.01, "iron_d")
        p.box(-0.1, 0, 0.98, 0.1, 0.42, 1.03, "brass")
    add("P_ChestLid", lid)

    def chest_small(p):
        p.box(-0.5, 0, -0.5, 0.5, 0.6, 0.5, "wood")
        p.box(-0.5, 0.6, -0.5, 0.5, 1, 0.5, "wood2")
        p.box(-0.08, 0.4, 0.5, 0.08, 0.7, 0.53, "brass")
    add("P_ChestSmall", chest_small)
    add("P_Amphora", lambda p: (vessel(p, "clay", 0.5, 0.2, 0.2), p.box(-0.5, 0.62, -0.03, -0.38, 0.92, 0.03, "clay"), p.box(0.38, 0.62, -0.03, 0.5, 0.92, 0.03, "clay")))

    def amph_stand(p):
        for z in (-0.4, 0.4):
            p.box(-0.5, 0.82, z - 0.1, 0.5, 1.0, z + 0.1, "wood")
        for x in (-0.42, 0.0, 0.42):
            for z in (-0.4, 0.4):
                p.box(x - 0.03, 0, z - 0.06, x + 0.03, 0.82, z + 0.06, "wood_d")
    add("P_AmphoraStand", amph_stand)
    add("P_Bag", lambda p: (p.ball(0, 0.38, 0, 0.5, "cloth", sub=1, sy=0.78), p.cyl(0, 0.68, 0, 0.14, 0.86, "cloth", sides=6, r2=0.2), p.cyl(0, 0.84, 0, 0.1, 1.0, "leather", sides=6, r2=0.22)))
    add("P_Bone", lambda p: (p.box(-0.18, 0, -0.42, 0.18, 1, 0.42, "bone"), [p.ball(s * 0.2, 0.5, t * 0.44, 0.22, "bone", sub=1) for s in (-1, 1) for t in (-1, 1)]))
    add("P_Skull", lambda p: (p.ball(0, 0.62, 0.08, 0.5, "bone", sub=1), p.box(-0.25, 0, -0.5, 0.25, 0.35, 0.05, "bone"), p.box(-0.3, 0.42, -0.42, -0.08, 0.68, -0.32, "soot"), p.box(0.08, 0.42, -0.42, 0.3, 0.68, -0.32, "soot")))
    add("P_BookOpen", lambda p: book(p))
    add("P_BookOpenBig", lambda p: book(p, "cloth_r"))
    add("P_BookRed", lambda p: book(p, "cloth_r", False))
    add("P_Bucket", lambda p: (p.cyl(0, 0, 0, 0.38, 0.78, "wood", sides=8, r2=0.5), [p.cyl(0, y, 0, 0.42 + y * 0.09, y + 0.05, "iron_d", sides=8) for y in (0.1, 0.62)], p.cyl(0, 0.72, 0, 0.4, 0.785, "soot", sides=8), p.box(-0.46, 0.76, -0.02, -0.42, 1.0, 0.02, "iron_d"), p.box(0.42, 0.76, -0.02, 0.46, 1.0, 0.02, "iron_d"), p.box(-0.46, 0.96, -0.02, 0.46, 1.0, 0.02, "iron_d")))
    add("P_Candlestick", lambda p: (p.cyl(0, 0, 0, 0.5, 0.06, "iron_d", sides=8, r2=0.2), p.cyl(0, 0.06, 0, 0.08, 0.62, "iron_d", sides=6), p.cyl(0, 0.62, 0, 0.32, 0.68, "iron", sides=8), candle(p, 0, 0, 0.68, 1.0, 0.16)))
    add("P_CandleSmall", lambda p: (p.cyl(0, 0, 0, 0.5, 0.14, "iron", sides=8), candle(p, 0, 0, 0.14, 1.0, 0.24)))

    def triple(p):
        p.cyl(0, 0, 0, 0.26, 0.05, "iron_d", sides=8, r2=0.1)
        p.cyl(0, 0.05, 0, 0.04, 0.58, "iron_d", sides=6)
        p.box(-0.42, 0.58, -0.03, 0.42, 0.64, 0.03, "iron")
        for x in (-0.42, 0, 0.42):
            candle(p, x, 0, 0.64, 1.0, 0.07)
    add("P_CandleTriple", triple)
    add("P_CandleWall", lambda p: (p.box(-0.25, 0.2, 0, 0.25, 0.42, 0.1, "iron_d"), p.box(-0.08, 0.28, 0.1, 0.08, 0.34, 0.76, "iron_d"), p.cyl(0, 0.34, 0.76, 0.26, 0.4, "iron", sides=8), candle(p, 0, 0.76, 0.4, 1.0, 0.13)))

    def carpet(color):
        def fn(p):
            p.box(-0.5, 0, -0.5, 0.5, 1, 0.5, color)
            p.box(-0.46, 1, -0.46, 0.46, 1.0005, 0.46, "cloth")
            p.box(-0.42, 1.0005, -0.42, 0.42, 1.001, 0.42, color)
            for s in (-1, 1):
                x = -0.46
                while x < 0.46:
                    p.box(s * 0.5 - 0.012, 0, x, s * 0.5 + 0.012, 0.8, x + 0.02, "paper")
                    x += 0.05
        return fn
    add("P_CarpetGreen", carpet("cloth_g"))
    add("P_CarpetRed", carpet("cloth_r"))
    add("P_Cauldron", lambda p: cauldron(p))
    add("P_CauldronEmpty", lambda p: cauldron(p, False))
    add("P_CauldronSmall", lambda p: cauldron(p, False))

    def chandelier(p):
        p.box(-0.02, 0.72, -0.02, 0.02, 1.0, 0.02, "iron_d")
        n = 6
        for i in range(n):
            a0, a1 = i / n * math.tau, (i + 1) / n * math.tau
            mx, mz = math.cos((a0 + a1) / 2) * 0.46, math.sin((a0 + a1) / 2) * 0.46
            p.box(mx - 0.12, 0.2, mz - 0.12, mx + 0.12, 0.25, mz + 0.12, "iron_d")
            cx, cz = math.cos(a0) * 0.44, math.sin(a0) * 0.44
            candle(p, cx, cz, 0.25, 0.44, 0.03)
            p.box(cx * 0.1 - 0.01, 0.72, cz * 0.1 - 0.01, cx + 0.01, 0.75, cz + 0.01, "iron_d")
            p.box(cx - 0.01, 0.22, cz - 0.01, cx + 0.01, 0.75, cz + 0.01, "iron_d")
    add("P_Chandelier", chandelier)
    add("P_CrystalBall", lambda p: p.ball(0, 0.5, 0, 0.5, "glass", sub=2))
    add("P_CrystalBallStand", lambda p: (p.cyl(0, 0, 0, 0.5, 0.4, "brass", sides=8, r2=0.2), p.cyl(0, 0.4, 0, 0.2, 1.0, "iron_d", sides=8, r2=0.42)))

    def fireplace(p):
        stove(p, True)
    add("P_Fireplace", fireplace)
    add("P_Oven", lambda p: (stove(p, True), p.box(-0.26, 0.05, 0.98, 0.26, 0.26, 1.0, "iron_d")))
    add("P_Firewood", lambda p: (p.box(-0.5, 0, -0.5, 0.5, 1, 0.5, "wood2"), p.box(-0.32, 0.25, 0.5, 0.32, 0.75, 0.52, "plank"), p.box(-0.32, 0.25, -0.52, 0.32, 0.75, -0.5, "plank")))

    def wood_stack(p):
        n = 5
        for row in range(4):
            for i in range(n - row):
                x = -0.42 + (i + row * 0.5) * 0.21
                y = row * 0.24
                p.prism([(x - 0.08, y), (x + 0.08, y), (x + 0.1, y + 0.13), (x + 0.08, y + 0.25), (x - 0.08, y + 0.25), (x - 0.1, y + 0.13)], -0.5, 0.5, "wood2" if (i + row) % 2 else "wood")
    add("P_FirewoodStack", wood_stack)
    add("P_Jug", lambda p: (vessel(p, "clay", 0.5, 0.26, 0.32), p.box(0.42, 0.34, -0.04, 0.5, 0.82, 0.04, "clay")))
    add("P_Lever", lambda p: (p.box(-0.5, 0.2, 0, 0.5, 0.8, 0.28, "iron_d"), p.box(-0.08, 0.2, 0.26, 0.08, 0.6, 0.6, "iron"), p.box(-0.04, 0.5, 0.5, 0.04, 1.0, 0.68, "wood_d"), p.ball(0, 0.96, 0.82, 0.14, "cloth_r", sub=1)))

    def potion(color):
        def fn(p):
            vessel(p, color, 0.5, 0.2, 0.32)
            p.cyl(0, 0.92, 0, 0.17, 1.0, "wood_d", sides=6)
        return fn
    add("P_PotionGreen", potion("potion_g"))
    add("P_PotionRed", potion("potion_r"))
    add("P_Beaker", lambda p: (p.cyl(0, 0, 0, 0.48, 0.2, "glass", sides=8), p.cyl(0, 0.2, 0, 0.48, 0.55, "potion_g", sides=8, r2=0.16), p.cyl(0, 0.55, 0, 0.16, 1.0, "glass", sides=8)))
    add("P_Bottle", lambda p: (vessel(p, "leaf", 0.48, 0.14, 0.4), p.cyl(0, 0.94, 0, 0.1, 1.0, "wood_d", sides=6)))
    add("P_Flask", lambda p: (p.ball(0, 0.4, 0, 0.5, "potion_r", sub=1, sy=0.8), p.cyl(0, 0.72, 0, 0.16, 1.0, "glass", sides=6)))
    add("P_JarFull", lambda p: (p.cyl(0, 0, 0, 0.42, 0.78, "clay", sides=8, r2=0.5), p.cyl(0, 0.78, 0, 0.36, 1.0, "cloth", sides=8, r2=0.42)))
    add("P_Goblet", lambda p: (p.cyl(0, 0, 0, 0.42, 0.05, "brass", sides=8, r2=0.16), p.cyl(0, 0.05, 0, 0.1, 0.55, "brass", sides=6), p.cyl(0, 0.55, 0, 0.18, 1.0, "brass", sides=8, r2=0.5)))
    add("P_Wineglass", lambda p: (p.cyl(0, 0, 0, 0.42, 0.05, "glass", sides=8), p.cyl(0, 0.05, 0, 0.06, 0.55, "glass", sides=6), p.cyl(0, 0.55, 0, 0.2, 1.0, "potion_r", sides=8, r2=0.5)))
    add("P_Mug", lambda p: (p.cyl(0, 0, 0, 0.42, 1.0, "wood", sides=8), [p.cyl(0, y, 0, 0.44, y + 0.06, "iron_d", sides=8) for y in (0.12, 0.78)], p.box(0.38, 0.28, -0.05, 0.5, 0.72, 0.05, "wood_d")))
    add("P_Plate", lambda p: p.cyl(0, 0, 0, 0.32, 1.0, "wood2", sides=10, r2=0.5))
    add("P_BowlFull", lambda p: (p.cyl(0, 0, 0, 0.26, 0.74, "wood", sides=8, r2=0.5), p.cyl(0, 0.68, 0, 0.42, 1.0, "food", sides=8, r2=0.26)))
    add("P_Bread", lambda p: p.ball(0, 0.5, 0, 0.5, "food", sub=1))
    add("P_Meat", lambda p: (p.ball(0, 0.5, 0.1, 0.42, "meat", sub=1), p.box(-0.08, 0.4, -0.5, 0.08, 0.6, 0.0, "bone")))

    def scroll(p, x, y, z):
        p.cyl(x, -0.5 + z, y, 0.08, 0.5 + z, "paper", sides=6, axis="z") if False else None
        p.box(x - 0.07, y, z - 0.42, x + 0.07, y + 0.14, z + 0.42, "paper")
        p.box(x - 0.08, y, z - 0.05, x + 0.08, y + 0.15, z + 0.05, "cloth_r")

    def scroll_stack(p):
        for row, xs in enumerate(((-0.36, -0.12, 0.12, 0.36), (-0.24, 0.0, 0.24), (-0.12, 0.12))):
            for x in xs:
                scroll(p, x, row * 0.3, 0.0)
    add("P_ScrollStack", scroll_stack)
    add("P_ScrollOpen", lambda p: (p.box(-0.46, 0, -0.42, 0.46, 0.4, 0.42, "paper"), p.box(-0.5, 0, -0.5, 0.5, 1.0, -0.38, "paper"), p.box(-0.5, 0, 0.38, 0.5, 1.0, 0.5, "paper"), [p.box(-0.32, 0.4, z, 0.32, 0.5, z + 0.03, "soot") for z in (-0.2, -0.06, 0.08, 0.22)]))

    def shield(p):
        n = 8
        pts = [(0.5 * math.cos(i / n * math.tau + 0.39), 0.5 + 0.5 * math.sin(i / n * math.tau + 0.39)) for i in range(n)]
        p.prism(pts, -0.1, 0.25, "wood")
        pts2 = [(0.34 * math.cos(i / n * math.tau + 0.39), 0.5 + 0.34 * math.sin(i / n * math.tau + 0.39)) for i in range(n)]
        p.prism(pts2, 0.25, 0.3, "cloth_r")
        p.cyl(0.5, 0.25, 0, 0.1, 0.5, "iron", sides=6, axis="z") if False else None
        p.box(-0.1, 0.4, 0.3, 0.1, 0.6, 0.5, "iron_d")
    add("P_Shield", shield)
    add("P_Spear", lambda p: (p.box(-0.09, 0, -0.5, 0.09, 0.86, 0.5, "wood2"), p.prism([(-0.5, 0.86), (0.5, 0.86), (0, 1.0)], -0.5, 0.5, "steel")))
    add("P_Sword", lambda p: (p.box(-0.24, 0.0, -0.5, 0.24, 0.17, 0.5, "leather"), p.box(-0.5, 0.17, -0.5, 0.5, 0.21, 0.5, "brass"), p.prism([(-0.22, 0.21), (0.22, 0.21), (0.22, 0.9), (0, 1.0), (-0.22, 0.9)], -0.25, 0.25, "steel")))
    add("P_Torch", post_torch)
    add("P_TorchWall", wall_torch)
    add("P_WeaponRackBig", lambda p: rack(p, True))
    add("P_WeaponRackSmall", lambda p: rack(p, False))

    def weapon_wall(p):
        p.box(-0.5, 0.0, 0.0, 0.5, 1.0, 0.14, "wood2")
        p.box(-0.04, 0.05, 0.14, 0.04, 0.95, 0.42, "steel")
        p.prism([(-0.42, 0.05), (-0.34, 0.05), (0.42, 0.95), (0.34, 0.95)], 0.42, 0.6, "wood_d")
        p.prism([(0.34, 0.05), (0.42, 0.05), (-0.34, 0.95), (-0.42, 0.95)], 0.6, 0.78, "wood_d")
        p.box(-0.22, 0.38, 0.78, 0.22, 0.72, 1.0, "iron")
    add("P_WeaponWall", weapon_wall)

    def banner(color):
        def fn(p):
            p.box(-0.5, 0.96, 0, 0.5, 1.0, 1.0, "wood_d")
            p.prism([(-0.42, 0.97), (0.42, 0.97), (0.42, 0.14), (0, 0.0), (-0.42, 0.14)][::-1], 0.3, 0.72, color)
            p.prism([(-0.12, 0.8), (0.12, 0.8), (0.12, 0.3), (0, 0.22), (-0.12, 0.3)][::-1], 0.72, 0.78, "bone")
        return fn
    add("P_BannerBlue", banner("cloth_b"))
    add("P_BannerRed", banner("cloth_r"))
    add("P_BloodPool", lambda p: p.cyl(0, 0, 0, 0.5, 1.0, "blood", sides=9))
    add("P_CoatHook", lambda p: (p.box(-0.5, 0.82, 0.8, 0.5, 0.92, 1.0, "wood"), [p.box(x - 0.02, 0.7, 0.45, x + 0.02, 0.86, 0.8, "iron_d") for x in (-0.3, 0.0, 0.3)], p.box(-0.42, 0.05, 0.28, -0.14, 0.8, 0.5, "leather"), p.box(0.12, 0.25, 0.28, 0.46, 0.8, 0.5, "cloth")))

    def door_wood(side):
        def fn(p):
            lo, hi = (0.0, 1.0) if side > 0 else (-1.0, 0.0)
            x = lo
            while x < hi - 1e-3:
                p.box(x + 0.006, 0, 0, x + 0.2 - 0.006, 1, 0.32, p.rnd.choice(["wood", "plank", "wood2"]))
                x += 0.2
            for y in (0.16, 0.78):
                p.box(lo, y, -0.5, hi, y + 0.06, 0.5, "iron_d")
        return fn
    add("P_DoorWoodL", door_wood(1))
    add("P_DoorWoodR", door_wood(-1))
    add("P_Drinkinghorn", lambda p: (p.cyl(0, 0, 0.42, 0.05, 0.5, "bone", sides=6, r2=0.34), p.cyl(0, 0.5, 0.42, 0.34, 1.0, "bone", sides=6, r2=0.42), p.cyl(0, 0.9, 0.42, 0.44, 1.0, "brass", sides=6)))

    def cage(p):
        p.box(-0.02, 0.8, -0.02, 0.02, 1.0, 0.02, "iron_d")
        p.cyl(0, 0.0, 0, 0.5, 0.03, "iron_d", sides=8)
        p.cyl(0, 0.74, 0, 0.5, 0.8, "iron_d", sides=8, r2=0.1)
        for i in range(10):
            a = i / 10 * math.tau
            x, z = math.cos(a) * 0.47, math.sin(a) * 0.47
            p.box(x - 0.012, 0.03, z - 0.012, x + 0.012, 0.76, z + 0.012, "iron_d")
        p.ball(0.1, 0.09, 0.08, 0.1, "bone", sub=1)
    add("P_HangingCage", cage)

    def ivy(p):
        for i in range(26):
            x = p.rnd.uniform(-0.45, 0.45)
            z = -p.rnd.uniform(0.02, 0.98)
            p.box(x - 0.1, 0, z - 0.04, x + 0.1, p.rnd.uniform(0.4, 1.0), z + 0.04, p.rnd.choice(["leaf", "moss"]))
    add("P_Ivy", ivy)
    add("P_KeyRusty", lambda p: (p.box(-0.1, 0, -0.5, 0.1, 1, 0.3, "rust"), p.box(-0.5, 0, 0.1, 0.5, 1, 0.5, "rust"), p.box(0.1, 0, -0.5, 0.45, 1, -0.28, "rust2")))
    add("P_Lock", lambda p: (p.box(-0.5, 0, -0.5, 0.5, 0.6, 0.5, "iron"), p.box(-0.4, 0.6, -0.3, -0.2, 1.0, 0.3, "iron_d"), p.box(0.2, 0.6, -0.3, 0.4, 1.0, 0.3, "iron_d"), p.box(-0.4, 0.86, -0.3, 0.4, 1.0, 0.3, "iron_d")))
    add("P_RoofSlab", lambda p: (p.box(-0.5, 0, -0.5, 0.5, 0.6, 0.5, "stone2"), p.box(-0.5, 0.6, -0.5, 0.5, 1.0, 0.5, "stone_d")))

    def sarcophagus(p):
        p.box(-0.5, 0, -0.5, 0.5, 0.1, 0.5, "stone3")
        p.box(-0.44, 0.1, -0.46, 0.44, 0.66, 0.46, "stone")
        p.box(-0.5, 0.66, -0.5, 0.5, 0.76, 0.5, "stone3")
        p.prism([(-0.5, 0.76), (0.5, 0.76), (0.3, 1.0), (-0.3, 1.0)], -0.5, 0.5, "stone2")
        p.box(-0.06, 0.97, -0.3, 0.06, 1.01, 0.3, "stone3")
        p.box(-0.2, 0.97, -0.2, 0.2, 1.01, -0.14, "stone3")
        p.bm  # solo per chiarezza: nessuna collisione qui, la aggiunge rocca.gd
    add("P_Sarcophagus", sarcophagus)
    add("P_ScaffoldPost", lambda p: (p.box(-0.5, 0, -0.5, -0.4, 1, 0.5, "wood_d"), p.box(0.4, 0, -0.5, 0.5, 1, 0.5, "wood_d"), p.prism([(-0.48, 0.05), (-0.4, 0.05), (0.48, 0.92), (0.4, 0.92)], -0.2, 0.2, "wood"), p.box(-0.5, 0.92, -0.5, 0.5, 1, 0.5, "wood")))

    def scales(p):
        p.cyl(0, 0, 0, 0.16, 0.06, "brass", sides=8)
        p.box(-0.02, 0.06, -0.05, 0.02, 0.96, 0.05, "brass")
        p.box(-0.5, 0.92, -0.05, 0.5, 1.0, 0.05, "brass")
        for s in (-1, 1):
            p.box(s * 0.44 - 0.01, 0.34, -0.03, s * 0.44 + 0.01, 0.94, 0.03, "iron_d")
            p.cyl(s * 0.44, 0.26, 0, 0.1, 0.34, "brass", sides=8, r2=0.14)
    add("P_Scales", scales)

    def spike_rack(p):
        p.box(-0.5, 0, -0.5, 0.5, 0.14, 0.5, "wood_d")
        x = -0.44
        while x <= 0.45:
            p.cyl(x, 0.14, 0, 0.04, 1.0, "rust", sides=4, r2=0.002)
            x += 0.11
    add("P_SpikeRack", spike_rack)
    add("P_WoodStairs", stairs_wood)

    # ------------------------------------------------- arredi di legno
    add("SM_Wood_Barrel_A", lambda p: barrel(p))
    add("SM_Wood_Barrel_B_Static", lambda p: barrel(p, "wood2", "rust2", True))
    add("SM_Wood_Basket_D", lambda p: basket(p, 0.32, 0.5, True))
    add("SM_Wood_Basket_E", lambda p: basket(p, 0.3, 0.5))
    add("SM_Wood_Bench_B", lambda p: (legs(p, 0.74, 0.44, 0.38, 0.05), p.box(-0.5, 0.74, -0.5, 0.5, 0.86, 0.5, "plank"), p.box(-0.5, 0.86, 0.38, 0.5, 1.0, 0.5, "wood2")))
    add("SM_Wood_BookShelf_A", lambda p: shelves(p, 5, 0.5, True))

    def cabinet(p):
        p.box(-0.5, 0.02, -0.5, 0.5, 0.98, 0.5, "wood2")
        p.box(-0.5, 0.95, -0.5, 0.5, 1.0, 0.5, "wood")
        p.box(-0.5, 0, -0.5, 0.5, 0.04, 0.5, "wood_d")
        for s in (-1, 1):
            a, b = (0.01, 0.48) if s > 0 else (-0.48, -0.01)
            p.box(a, 0.08, 0.5, b, 0.92, 0.53, "wood")
            p.box(s * 0.08 - 0.02, 0.46, 0.53, s * 0.08 + 0.02, 0.56, 0.56, "iron_d")
    add("SM_Wood_Cabinet_A_Static", cabinet)
    add("SM_Wood_Chair_A", lambda p: chair(p))
    add("SM_Wood_Chair_B", lambda p: chair(p, True, "wood2"))

    def rocking(p):
        for s in (-1, 1):
            p.side_prism([(-0.5, 0.02), (-0.2, 0.0), (0.2, 0.0), (0.5, 0.05), (0.5, 0.08), (0.2, 0.05), (-0.2, 0.05), (-0.5, 0.07)], s * 0.42 - 0.03, s * 0.42 + 0.03, "wood_d")
            p.box(s * 0.42 - 0.03, 0.05, -0.18, s * 0.42 + 0.03, 0.34, -0.14, "wood_d")
            p.box(s * 0.42 - 0.03, 0.05, 0.22, s * 0.42 + 0.03, 1.0, 0.27, "wood_d")
            p.box(s * 0.42 - 0.04, 0.5, -0.22, s * 0.42 + 0.04, 0.54, 0.25, "wood")
        p.box(-0.42, 0.33, -0.22, 0.42, 0.38, 0.26, "wood")
        for y in (0.55, 0.72, 0.88):
            p.box(-0.42, y, 0.24, 0.42, y + 0.08, 0.28, "wood")
    add("SM_Wood_Chair_Rockign", rocking)
    add("SM_Wood_Crate_Open", lambda p: crate(p, True))
    add("SM_Wood_Crate_Static", lambda p: crate(p))
    add("SM_Wood_Kettle", lambda p: (p.cyl(0, 0, 0, 0.32, 0.55, "iron", sides=8, r2=0.32), p.cyl(0, 0.55, 0, 0.32, 0.7, "iron_d", sides=8, r2=0.18), p.box(0.3, 0.3, -0.03, 0.5, 0.56, 0.03, "iron_d"), p.box(-0.32, 0.72, -0.03, 0.22, 1.0, 0.03, "wood_d") if False else None, [p.box(x, 0.68, -0.02, x + 0.03, 1.0, 0.02, "iron_d") for x in (-0.22, 0.2)], p.box(-0.22, 0.96, -0.02, 0.23, 1.0, 0.02, "wood_d")))
    add("SM_Wood_Mug", lambda p: (p.cyl(0, 0, 0, 0.42, 1.0, "clay", sides=8), p.box(0.38, 0.28, -0.05, 0.5, 0.72, 0.05, "clay")))

    def wall_shelf_w(p):
        p.box(-0.5, 0.86, 0, 0.5, 1.0, 1.0, "wood")
        p.box(-0.5, 0.0, 0, 0.5, 0.14, 1.0, "wood")
        for x in (-0.44, 0.44):
            p.box(x - 0.03, 0, 0, x + 0.03, 1.0, 0.2, "wood_d")
    add("SM_Wood_Shelf_A", wall_shelf_w)
    add("SM_Wood_Shovel", lambda p: (p.box(-0.05, 0.3, -0.25, 0.05, 1.0, 0.25, "wood2"), p.box(-0.2, 0.93, -0.25, 0.2, 1.0, 0.25, "wood_d"), p.prism([(-0.5, 0.3), (0.5, 0.3), (0.42, 0.06), (0, 0.0), (-0.42, 0.06)][::-1], -0.3, 0.3, "iron")))
    add("SM_Wood_Stool_A", lambda p: (p.cyl(0, 0.86, 0, 0.5, 1.0, "wood", sides=8), legs(p, 0.86, 0.3, 0.3, 0.05)))

    def round_table(p):
        p.cyl(0, 0.92, 0, 0.5, 1.0, "wood", sides=12)
        p.cyl(0, 0.06, 0, 0.08, 0.92, "wood_d", sides=6)
        p.cyl(0, 0, 0, 0.32, 0.06, "wood_d", sides=8, r2=0.14)
    add("SM_Wood_Table_Round_A", round_table)
    def path_torch(p):
        # Palo piantato a terra con due traverse larghe: la fiamma resta piccola rispetto all'ingombro.
        p.cyl(0, 0, 0, 0.06, 0.82, "wood_d", sides=6, r2=0.05)
        for s in (-1, 1):
            p.prism([(0, 0.0), (s * 0.5, 0.0), (s * 0.5, 0.012), (0, 0.16)] if s > 0 else [(0, 0.16), (s * 0.5, 0.012), (s * 0.5, 0.0), (0, 0.0)], -0.04, 0.04, "wood_d")
        p.cyl(0, 0.8, 0, 0.08, 0.86, "iron_d", sides=6, r2=0.13)
        p.cyl(0, 0.85, 0, 0.11, 1.0, "ember", sides=5, r2=0.015)
    add("SM_Mine_Torch_0", path_torch)

    def barrier(p):
        p.box(-0.5, 0, -0.5, -0.42, 0.06, 0.5, "iron_d")
        p.box(0.42, 0, -0.5, 0.5, 0.06, 0.5, "iron_d")
        for x in (-0.46, 0.46):
            p.box(x - 0.04, 0.06, -0.04, x + 0.04, 0.96, 0.04, "white")
        x = -0.48
        i = 0
        for y0, y1 in ((0.72, 0.96), (0.32, 0.5)):
            for i in range(6):
                a = -0.5 + i / 6
                p.box(a, y0, -0.06, a + 1 / 6, y1, 0.06, "orange" if i % 2 else "white")
        p.cyl(0.46, 0.96, 0, 0.05, 1.0, "orange", sides=6)
    add("SM_Prop_RoadBarrier_Small", barrier)

    # ------------------------------------------------- armi (lama lungo +Y, filo verso -Z, origine sull'impugnatura)
    def runic_axe(p):
        p.box(-0.3, 0.0, 0.34, 0.3, 1.0, 0.44, "wood_d")
        for y in (0.08, 0.2, 0.32):
            p.box(-0.35, y, 0.32, 0.35, y + 0.06, 0.46, "leather")
        p.box(-0.5, 0.74, 0.3, 0.5, 0.94, 0.5, "iron_d")
        p.prism([(-0.28, 0.66), (0.28, 0.66), (0.28, 1.0), (-0.28, 1.0)][::-1], 0.36, 0.42, "iron")
        p.side_prism([(0.34, 0.74), (0.34, 0.94), (0.05, 1.0), (0.0, 0.62)], -0.12, 0.12, "steel")
        p.side_prism([(0.0, 0.62), (0.05, 1.0), (-0.02, 1.0), (-0.05, 0.6)], -0.04, 0.04, "white")
        p.side_prism([(0.42, 0.78), (0.42, 0.9), (0.72, 0.87), (0.72, 0.81)], -0.1, 0.1, "steel")
        for y in (0.74, 0.8, 0.86):
            p.box(-0.14, y, 0.14, 0.14, y + 0.02, 0.24, "ember")
    add("SM_Wep_RunicAxe", runic_axe)

    def short_sword(p):
        p.side_prism([(-0.28, 0.2), (0.28, 0.2), (0.34, 0.4), (0.38, 0.62), (0.0, 1.0), (-0.38, 0.62), (-0.34, 0.4)], -0.18, 0.18, "steel")
        p.side_prism([(-0.06, 0.2), (0.06, 0.2), (0.06, 0.86), (0.0, 0.96), (-0.06, 0.86)], -0.5, 0.5, "steel2" if False else "white")
        p.box(-0.3, 0.17, -0.5, 0.3, 0.21, 0.5, "brass")
        p.box(-0.24, 0.02, -0.16, 0.24, 0.17, 0.16, "leather")
        p.box(-0.3, 0.0, -0.22, 0.3, 0.03, 0.22, "brass")
    add("SM_Wep_SpartanSword", short_sword)


define_props()

MODULES = {
    "M_FloorTile": m_floor_tile,
    "M_Straight": m_straight,
    "M_StraightHalf": lambda: m_straight("M_StraightHalf", -1.2, 1.0),
    "M_Crossing": m_crossing,
    "M_CustomCenter": m_custom_center,
    "M_Big": m_big,
    "M_Pillar": m_pillar,
    "M_Wall1": lambda: wall_piece("M_Wall1", 2.0, -2.0, 0.17),
    "M_Wall2": lambda: wall_piece("M_Wall2", 2.0, -2.03, 0.2, moss=0.08, seed=7),
    "M_Wall3": lambda: wall_piece("M_Wall3", 2.0, -2.01, 0.2, broken=0.07, seed=11),
    "M_WallWindow": lambda: wall_piece("M_WallWindow", 2.0, -2.0, 0.2, window=True),
    "M_BigWall": lambda: wall_piece("M_BigWall", 4.0, -4.0, 0.21, moss=0.04),
    "M_BigWindow": lambda: wall_piece("M_BigWindow", 4.0, -4.0, 0.24, window=True),
    "M_Passage": lambda: passage("M_Passage", 2.0),
    "M_PassageWood": lambda: passage("M_PassageWood", 2.0, wood=True),
    "M_BigPassage": lambda: passage("M_BigPassage", 4.0),
    "M_JailWall": lambda: m_jail("M_JailWall"),
    "M_JailGate": lambda: m_jail("M_JailGate"),
    "M_JailBroken": lambda: m_jail("M_JailBroken"),
    "M_JailDoorL": lambda: m_jail_door("M_JailDoorL", 1),
    "M_JailDoorR": lambda: m_jail_door("M_JailDoorR", -1),
    "M_DoorIronL": lambda: m_door_iron("M_DoorIronL", 1),
    "M_DoorIronR": lambda: m_door_iron("M_DoorIronR", -1),
    "M_GateWoodL": lambda: m_gate_wood("M_GateWoodL", 1),
    "M_GateWoodR": lambda: m_gate_wood("M_GateWoodR", -1),
    "M_Portcullis": lambda: m_portcullis("M_Portcullis", 2.0, "iron_d", "iron"),
    "M_PortcullisWood": lambda: m_portcullis("M_PortcullisWood", 1.8, "wood_d", "iron_d"),
    "M_StairsLow": lambda: m_stairs("M_StairsLow", 0.0, -0.13),
    "M_StairsHigh": lambda: m_stairs("M_StairsHigh", 2.5, -0.02),
    "M_StairsPlatform": m_platform,
    "M_Steps": m_steps,
    "M_Staircase": m_staircase,
    "M_Balcony": m_balcony,
    "M_BalconyPost": m_balcony_post,
    "M_BalconyRailing": m_balcony_rail,
}


# ===================================================================== deserto (misure vere, niente adattamento agli ingombri)
def cactus_a(p):
    p.cyl(0, 0, 0, 0.26, 3.1, "leaf", sides=8, r2=0.2)
    p.ball(0, 3.1, 0, 0.2, "leaf", sub=1)
    for side, h, reach, top in ((1, 1.25, 0.75, 2.5), (-1, 1.7, 0.62, 2.75)):
        p.box(0, h - 0.13, -0.13, side * reach, h + 0.13, 0.13, "leaf") if side > 0 else p.box(side * reach, h - 0.13, -0.13, 0, h + 0.13, 0.13, "leaf")
        p.cyl(side * reach, h - 0.13, 0, 0.14, top, "leaf", sides=7, r2=0.11)
        p.ball(side * reach, top, 0, 0.11, "leaf", sub=1)
    for i in range(8):
        a = i / 8 * math.tau
        p.box(math.cos(a) * 0.24 - 0.012, 0.2, math.sin(a) * 0.24 - 0.012, math.cos(a) * 0.24 + 0.012, 2.95, math.sin(a) * 0.24 + 0.012, "moss")


def cactus_b(p):
    p.ball(0, 0.42, 0, 0.5, "leaf", sub=2, sy=0.95)
    p.ball(0.55, 0.26, 0.28, 0.3, "moss", sub=1)
    p.ball(-0.42, 0.22, -0.4, 0.26, "leaf", sub=1)
    p.ball(0, 0.96, 0, 0.1, "cloth_r", sub=1)


def cactus_c(p):
    p.cyl(0, 0, 0, 0.17, 1.6, "moss", sides=7, r2=0.13)
    p.ball(0, 1.6, 0, 0.13, "moss", sub=1)
    p.cyl(0.3, 0, 0.2, 0.13, 1.05, "leaf", sides=7, r2=0.1)
    p.ball(0.3, 1.05, 0.2, 0.1, "leaf", sub=1)
    p.cyl(-0.26, 0, 0.14, 0.11, 0.8, "leaf", sides=7, r2=0.08)


def rib(p):
    # Costola di balena: un arco spesso alla base e sottile in cima, piantato nella sabbia.
    n = 8
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        a0, a1 = t0 * 1.35, t1 * 1.35
        r = 6.2
        w0, w1 = 0.42 * (1.0 - t0 * 0.7), 0.42 * (1.0 - t1 * 0.7)
        x0, y0 = r - r * math.cos(a0), r * math.sin(a0)
        x1, y1 = r - r * math.cos(a1), r * math.sin(a1)
        p.prism([(x0 - w0 * 0.5, y0), (x0 + w0 * 0.5, y0), (x1 + w1 * 0.5, y1), (x1 - w1 * 0.5, y1)], -w0 * 0.55, w0 * 0.55, "bone")


DESERT_PIECES = {"SM_Cactus_A": cactus_a, "SM_Cactus_B": cactus_b, "SM_Cactus_C": cactus_c, "SM_Desert_Rib": rib}


def build_desert():
    for name, make in DESERT_PIECES.items():
        clean_scene()
        p = Piece(name)
        make(p)
        p.obj()
        export(os.path.join(PROJECT, "art/zx_desert", name + ".glb"))


def clean_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def make_prop(name, lo, hi):
    p = Piece(name)
    PROPS[name](p)
    lo2, hi2 = list(lo), list(hi)
    for k in range(3):
        if hi2[k] - lo2[k] < 0.004:
            hi2[k] = lo2[k] + 0.004
    p.fit(lo2, hi2)
    return p


def export(path, names_ok=True):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=False, export_animations=False, export_image_format="AUTO")
    print("SCRITTO", path, len(bpy.data.objects), "oggetti")


def build_modules(path, wanted):
    clean_scene()
    i = 0
    missing = []
    for name in wanted:
        at = (10.0 * (i % 12), 0, 12.0 * (i // 12))
        if name in MODULES:
            MODULES[name]().obj(at)
        elif name in PROPS:
            lo, hi = MIS["moduli"][name]["min"], MIS["moduli"][name]["max"]
            make_prop(name, lo, hi).obj(at)
        else:
            missing.append(name)
        i += 1
    if missing:
        print("MANCANO", missing)
    export(path)


def build_single(name, path, measure=None):
    clean_scene()
    m = MIS["singoli"][measure or name]
    make_prop(name, m["min"], m["max"]).obj((0, 0, 0))
    export(path)


if __name__ == "__main__":
    group = ARGS[1] if len(ARGS) > 1 else "tutto"
    names = sorted(MIS["moduli"])
    if group in ("tutto", "moduli"):
        build_modules(os.path.join(PROJECT, "art/zx_rocca/rocca_modules.glb"), names)
        build_modules(os.path.join(PROJECT, "art/zx_dungeon/dungeon_modules.glb"), names)
    if group in ("tutto", "singoli"):
        for name in sorted(k for k in PROPS if k.startswith("SM_Wood_")):
            build_single(name, os.path.join(PROJECT, "art/env/wood", name + ".glb"))
        build_single("SM_Mine_Torch_0", os.path.join(PROJECT, "art/env/mine/SM_Mine_Torch_0.glb"))
        build_single("SM_Prop_RoadBarrier_Small", os.path.join(PROJECT, "art/zx_borgo/SM_Prop_RoadBarrier_Small.glb"), "road_barrier")
        build_single("SM_Wep_RunicAxe", os.path.join(PROJECT, "art/env/weapons/SM_Wep_RunicAxe.glb"))
        build_single("SM_Wep_SpartanSword", os.path.join(PROJECT, "art/env/weapons/SM_Wep_SpartanSword.glb"))
    if group in ("tutto", "deserto"):
        build_desert()
    print("FINE KIT")
