"""Coltello da combattimento originale della prima persona, fatto da zero: art/zx_fp/SM_FP_CombatKnife.glb.

blender --background --factory-startup --python tools/build_fp_knife.py -- <cartella ZOMBIX_HEAD>

Convenzione glTF: lama +Y, filo +Z, origine alla guardia, misure in metri.
In Blender: lama +Z, filo -Y.
"""
import os
import sys
import bpy
import bmesh

PROJECT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(PROJECT, "art", "zx_fp", "SM_FP_CombatKnife.glb")

COLORS = {
    "Knife_Steel": (0.66, 0.70, 0.73),
    "Knife_Edge": (0.93, 0.95, 0.96),
    "Knife_Guard": (0.20, 0.21, 0.22),
    "Knife_Grip": (0.10, 0.10, 0.09),
    "Knife_Wrap": (0.31, 0.33, 0.20),
}
# Lama: z, dorso (+Y), filo (-Y), semispessore del dorso. L'ultima stazione è la punta.
BLADE = [
    (0.000, 0.015, -0.017, 0.0034),
    (0.040, 0.015, -0.019, 0.0034),
    (0.170, 0.015, -0.019, 0.0032),
    (0.225, 0.015, -0.016, 0.0028),
    (0.262, 0.009, -0.010, 0.0020),
    (0.300, 0.004, 0.004, 0.0),
]


def material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    node = mat.node_tree.nodes["Principled BSDF"]
    r, g, b = COLORS[name]
    node.inputs["Base Color"].default_value = (r, g, b, 1)
    node.inputs["Metallic"].default_value = 0.0
    node.inputs["Roughness"].default_value = 0.55
    return mat


bpy.ops.wm.read_factory_settings(use_empty=True)
mesh = bpy.data.meshes.new("SM_FP_CombatKnife")
obj = bpy.data.objects.new("SM_FP_CombatKnife", mesh)
bpy.context.scene.collection.objects.link(obj)
names = list(COLORS)
for name in names:
    mesh.materials.append(material(name))
index = {name: i for i, name in enumerate(names)}
bm = bmesh.new()


def face(points, mat):
    made = bm.faces.new(points)
    made.material_index = index[mat]
    made.smooth = False


def box(z0, z1, y0, y1, half_x, mat, top_scale=1.0):
    """Blocco da z0 a z1; la faccia alta può restringersi per dare forma all'impugnatura."""
    mid = (y0 + y1) / 2
    half_y = (y1 - y0) / 2
    low = [bm.verts.new((sx * half_x, mid + sy * half_y, z0)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    high = [bm.verts.new((sx * half_x * top_scale, mid + sy * half_y * top_scale, z1)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    face(list(reversed(low)), mat)
    face(high, mat)
    for i in range(4):
        j = (i + 1) % 4
        face([low[i], low[j], high[j], high[i]], mat)


# Lama: anello di 5 punti per stazione (dorso sx/dx, spalla dx, filo, spalla sx).
rings = []
for z, spine, edge, half in BLADE:
    if half == 0.0:
        rings.append(bm.verts.new((0, spine, z)))
        continue
    shoulder = edge + (spine - edge) * 0.42
    rings.append([bm.verts.new(p) for p in (
        (-half, spine, z), (half, spine, z), (half, shoulder, z), (0, edge, z), (-half, shoulder, z))])
for a, b in zip(rings[:-2], rings[1:-1]):
    for i in range(5):
        j = (i + 1) % 5
        face([a[i], a[j], b[j], b[i]], "Knife_Edge" if i in (2, 3) else "Knife_Steel")
last, tip = rings[-2], rings[-1]
for i in range(5):
    j = (i + 1) % 5
    face([last[i], last[j], tip], "Knife_Edge" if i in (2, 3) else "Knife_Steel")
face(list(reversed(rings[0])), "Knife_Steel")

# Guardia, impugnatura a tre fasce con legatura, pomolo.
box(-0.008, 0.0, -0.032, 0.026, 0.0085, "Knife_Guard")
box(-0.030, -0.008, -0.015, 0.015, 0.0115, "Knife_Grip")
box(-0.038, -0.030, -0.016, 0.016, 0.0125, "Knife_Wrap")
box(-0.060, -0.038, -0.015, 0.015, 0.0115, "Knife_Grip")
box(-0.068, -0.060, -0.016, 0.016, 0.0125, "Knife_Wrap")
box(-0.078, -0.068, -0.014, 0.014, 0.0105, "Knife_Grip")
box(-0.090, -0.078, -0.017, 0.017, 0.0130, "Knife_Guard", 0.75)

bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh)
bm.free()
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True)
print("SCRITTO", OUT, len(mesh.polygons), "facce")
