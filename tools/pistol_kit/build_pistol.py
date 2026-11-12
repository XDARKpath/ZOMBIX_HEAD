# Pistola compatta originale di ZOMBIX, fatta da zero. Riusa nomi e animazioni (Wep_Fire, Wep_Reload) del modello che
# sostituisce, così nessuno script cambia. Uso:
#   blender --background --python tools/pistol_kit/build_pistol.py -- entrata.glb uscita.glb
import sys
import bmesh
import bpy
from mathutils import Vector

src, dst = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
root = bpy.data.objects["SM_Wep_Pistol"]
slide = bpy.data.objects["SM_Wep_Pistol_Slide"]
mag = bpy.data.objects["SM_Wep_Pistol_Mag"]


def box_of(o):
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


bpy.context.view_layer.update()
for o in (root, slide, mag):
    print("VECCHIO", o.name, "origine", tuple(round(v, 4) for v in o.matrix_world.translation), "box", [tuple(round(v, 4) for v in b) for b in box_of(o)])
lo = Vector((min(box_of(o)[0].x for o in (root, slide, mag)), min(box_of(o)[0].y for o in (root, slide, mag)), min(box_of(o)[0].z for o in (root, slide, mag))))
hi = Vector((max(box_of(o)[1].x for o in (root, slide, mag)), max(box_of(o)[1].y for o in (root, slide, mag)), max(box_of(o)[1].z for o in (root, slide, mag))))
size = hi - lo
print("MISURE", tuple(round(v, 4) for v in size), "lo", tuple(round(v, 4) for v in lo))
# L'asse più lungo è la canna; l'altezza è Z (spazio di Blender).
long_axis = 0 if size.x >= size.y else 1
print("ASSE CANNA", "XY"[long_axis])
L = size[long_axis]
W = size[1 - long_axis]
H = size.z


def material(name, color, metal, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n = m.node_tree.nodes["Principled BSDF"]
    n.inputs["Base Color"].default_value = (*color, 1)
    n.inputs["Metallic"].default_value = metal
    n.inputs["Roughness"].default_value = rough
    return m


M_STEEL = material("M_Pistol_Acciaio", (0.16, 0.17, 0.18), 0.6, 0.38)
M_DARK = material("M_Pistol_Scuro", (0.05, 0.052, 0.056), 0.55, 0.42)
M_POLY = material("M_Pistol_Polimero", (0.06, 0.062, 0.06), 0.0, 0.7)
M_GRIP = material("M_Pistol_Zigrino", (0.036, 0.036, 0.035), 0.0, 0.9)
M_BRASS = material("M_Pistol_Ottone", (0.55, 0.4, 0.14), 0.9, 0.35)
M_DOT = material("M_Pistol_Tacche", (0.75, 0.74, 0.62), 0.0, 0.6)
MATS = [M_STEEL, M_DARK, M_POLY, M_GRIP, M_BRASS, M_DOT]


class Part:
    # Costruisce in coordinate pistola: u lungo la canna (+u = bocca), v di lato, w in alto. Lunghezze in frazioni di L.
    def __init__(self, obj, muzzle_sign, base):
        self.obj = obj
        self.sign = muzzle_sign
        self.base = base
        self.bm = bmesh.new()

    def to_world(self, u, v, w):
        d = [0.0, 0.0, 0.0]
        d[long_axis] = u * self.sign
        d[1 - long_axis] = v
        d[2] = w
        return self.base + Vector(d)

    def box(self, u0, u1, v, w0, w1, mat, taper=0.0, slant=0.0, chamfer=0.0):
        # Scatola con facoltativa rastremazione in alto, inclinazione lungo u e smusso superiore.
        rings = []
        heights = [w0, w1 - chamfer, w1] if chamfer > 0 else [w0, w1]
        for i, h in enumerate(heights):
            t = (h - w0) / max(w1 - w0, 1e-5)
            shrink = chamfer if (chamfer > 0 and i == 2) else 0.0
            vv = v * (1.0 - taper * t) - shrink
            du = slant * t
            ring = [self.bm.verts.new(self.to_world(u, s * vv, h)) for u, s in ((u0 + du, -1), (u1 + du, -1), (u1 + du, 1), (u0 + du, 1))]
            rings.append(ring)
        faces = []
        faces.append(self.bm.faces.new(list(reversed(rings[0]))))
        faces.append(self.bm.faces.new(rings[-1]))
        for a, b in zip(rings, rings[1:]):
            for i in range(4):
                faces.append(self.bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i])))
        for f in faces:
            f.material_index = MATS.index(mat)
        return faces

    def cylinder(self, u0, u1, v, w, radius, mat, sides=12):
        import math
        rings = []
        for u in (u0, u1):
            rings.append([self.bm.verts.new(self.to_world(u, v + math.cos(i * math.tau / sides) * radius, w + math.sin(i * math.tau / sides) * radius)) for i in range(sides)])
        faces = [self.bm.faces.new(list(reversed(rings[0]))), self.bm.faces.new(rings[1])]
        for i in range(sides):
            faces.append(self.bm.faces.new((rings[0][i], rings[0][(i + 1) % sides], rings[1][(i + 1) % sides], rings[1][i])))
        for f in faces:
            f.material_index = MATS.index(mat)

    def finish(self):
        bmesh.ops.recalc_face_normals(self.bm, faces=list(self.bm.faces))
        inv = self.obj.matrix_world.inverted()
        for v in self.bm.verts:
            v.co = inv @ v.co
        mesh = bpy.data.meshes.new(self.obj.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for m in MATS:
            mesh.materials.append(m)
        for p in mesh.polygons:
            p.use_smooth = False
        self.obj.data = mesh


# Da che parte è la bocca: il carrello sta verso la canna rispetto al caricatore.
slide_box = box_of(slide)
mag_box = box_of(mag)
mid_slide = (slide_box[0][long_axis] + slide_box[1][long_axis]) * 0.5
mid_mag = (mag_box[0][long_axis] + mag_box[1][long_axis]) * 0.5
muzzle_sign = 1.0 if mid_slide >= mid_mag else -1.0
tail_u = lo[long_axis] if muzzle_sign > 0 else hi[long_axis]
base = Vector((0.0, 0.0, 0.0))
base[long_axis] = tail_u
base[1 - long_axis] = (lo[1 - long_axis] + hi[1 - long_axis]) * 0.5
base.z = lo.z
hw = W * 0.5
slide_h = slide_box[0].z - lo.z
print("BOCCA", muzzle_sign, "alto carrello da", round(slide_h, 4))

# --- Carrello: parte che scorre.
s = Part(slide, muzzle_sign, base)
top = H
s_bot = H * 0.70
s.box(0.0, L, hw * 0.86, s_bot, top, M_STEEL, taper=0.14, chamfer=H * 0.018)
# Tacche posteriori e anteriori per armare.
for i in range(8):
    u = L * (0.035 + i * 0.033)
    s.box(u, u + L * 0.012, hw * 0.885, s_bot + H * 0.03, top - H * 0.07, M_DARK)
for i in range(4):
    u = L * (0.80 + i * 0.033)
    s.box(u, u + L * 0.012, hw * 0.885, s_bot + H * 0.03, top - H * 0.07, M_DARK)
# Finestra di espulsione con la canna che si vede dentro.
s.box(L * 0.46, L * 0.68, hw * 0.60, top - H * 0.03, top + H * 0.004, M_DARK)
s.box(L * 0.50, L * 0.66, hw * 0.28, top - H * 0.02, top + H * 0.009, M_BRASS)
# Mire con i tre puntini.
s.box(L * 0.05, L * 0.12, hw * 0.46, top, top + H * 0.05, M_DARK)
s.box(L * 0.09, L * 0.115, hw * 0.13, top + H * 0.052, top + H * 0.054, M_DOT)
s.box(L * 0.88, L * 0.95, hw * 0.13, top, top + H * 0.052, M_DARK)
s.box(L * 0.905, L * 0.93, hw * 0.07, top + H * 0.052, top + H * 0.054, M_DOT)
# Bocca: anello e foro.
s.cylinder(L * 0.995, L * 1.003, 0.0, s_bot + (top - s_bot) * 0.5, H * 0.075, M_DARK)
s.cylinder(L * 1.003, L * 1.005, 0.0, s_bot + (top - s_bot) * 0.5, H * 0.045, M_GRIP)
s.finish()

# --- Fusto e impugnatura.
f = Part(root, muzzle_sign, base)
f_top = s_bot
grip_u0, grip_u1 = L * 0.02, L * 0.40
f.box(0.0, L * 0.95, hw * 0.78, H * 0.53, f_top, M_POLY, chamfer=H * 0.01)
# Slitta sotto la canna: tre tagli.
for i in range(3):
    u = L * (0.70 + i * 0.075)
    f.box(u, u + L * 0.04, hw * 0.82, H * 0.53, H * 0.565, M_DARK)
# Impugnatura inclinata, con zigrino e dorso.
grip_slant = -L * 0.09
f.box(grip_u0 + L * 0.09, grip_u1 + L * 0.09, hw * 0.92, 0.0, H * 0.56, M_POLY, slant=grip_slant, taper=-0.06)
for i in range(7):
    w0 = H * (0.06 + i * 0.062)
    du = grip_slant * (w0 / (H * 0.56))
    f.box(grip_u0 + L * 0.105 + du, grip_u1 + L * 0.075 + du, hw * 0.975, w0, w0 + H * 0.035, M_GRIP)
# Coda sopra la mano.
f.box(-L * 0.02, L * 0.05, hw * 0.74, H * 0.53, H * 0.62, M_POLY, chamfer=H * 0.012)
# Ponticello del grilletto.
g0, g1 = L * 0.39, L * 0.60
gw = hw * 0.34
f.box(g0, g1, gw, H * 0.37, H * 0.40, M_POLY)
f.box(g1 - L * 0.025, g1, gw, H * 0.37, H * 0.55, M_POLY)
# Grilletto curvo in due pezzi.
f.box(L * 0.455, L * 0.485, gw * 0.55, H * 0.46, H * 0.55, M_DARK)
f.box(L * 0.475, L * 0.5, gw * 0.55, H * 0.42, H * 0.47, M_DARK)
# Leva della sicura e sgancio del caricatore.
f.box(L * 0.12, L * 0.26, hw * 1.03, H * 0.60, H * 0.645, M_DARK)
f.box(L * 0.37, L * 0.42, hw * 1.02, H * 0.44, H * 0.49, M_DARK)
# Cane in coda.
f.box(-L * 0.035, L * 0.005, hw * 0.28, H * 0.74, H * 0.87, M_DARK, slant=-L * 0.02)
f.finish()

# --- Caricatore: la parte che esce in ricarica.
m = Part(mag, muzzle_sign, base)
m.box(grip_u0 + L * 0.10, grip_u1 + L * 0.075, hw * 0.74, H * 0.03, H * 0.56, M_DARK, slant=grip_slant)
m.box(grip_u0 + L * 0.085, grip_u1 + L * 0.09, hw * 0.96, -H * 0.012, H * 0.05, M_POLY)
m.finish()

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_animations=True, export_force_sampling=False, export_apply=False)
print("FATTO", dst)
