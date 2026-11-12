"""Low-poly mesh builder: lofts, boxes, mirroring, palette UVs, vertex colours, skin weights."""
import bpy, bmesh, math, random
from mathutils import Vector

# ---------------------------------------------------------------- palette
PALETTE = {
    'skin': (224, 172, 135), 'skin_shadow': (196, 140, 105), 'lips': (164, 102, 88),
    'eye': (38, 30, 28), 'brow': (62, 44, 32), 'hair': (78, 56, 38), 'hair_dark': (56, 40, 28),
    'shirt': (56, 60, 64), 'shirt_dark': (44, 47, 50),
    'jacket': (152, 130, 90), 'jacket_dark': (116, 98, 66), 'jacket_lining': (84, 92, 72),
    'pants': (92, 96, 78), 'pants_dark': (72, 76, 61), 'kneepad': (42, 44, 46),
    'boot': (86, 60, 41), 'boot_dark': (62, 43, 30), 'sole': (36, 33, 31),
    'glove': (46, 46, 49), 'glove_pad': (78, 80, 84), 'strap': (122, 90, 56), 'strap_dark': (52, 52, 54),
    'metal': (156, 156, 160), 'metal_dark': (92, 94, 98),
    'vest': (100, 106, 74), 'vest_dark': (78, 84, 58), 'pouch': (114, 120, 86),
    'radio': (42, 42, 44), 'led': (222, 64, 44),
    'pack': (112, 94, 66), 'pack_dark': (86, 71, 49), 'bedroll': (68, 96, 122), 'bedroll_dark': (52, 74, 96),
    'holster': (38, 38, 41), 'cap': (88, 94, 72), 'cap_dark': (66, 71, 55),
    'nvg': (52, 54, 57), 'lens': (64, 176, 96),
}
NAMES = list(PALETTE)
GRID = 16  # 16x16 swatches of 16px on a 256 atlas


def swatch_uv(name):
    i = NAMES.index(name)
    return ((i % GRID + 0.5) / GRID, 1.0 - (i // GRID + 0.5) / GRID)


def write_palette(path):
    from PIL import Image
    im = Image.new('RGB', (256, 256), (255, 0, 255))
    px = im.load()
    for i, n in enumerate(NAMES):
        cx, cy = (i % GRID) * 16, (i // GRID) * 16
        for x in range(16):
            for y in range(16):
                px[cx + x, cy + y] = PALETTE[n]
    im.save(path)


# ---------------------------------------------------------------- profiles
OCT = [(1, .42), (.42, 1), (-.42, 1), (-1, .42), (-1, -.42), (-.42, -1), (.42, -1), (1, -.42)]
BOX = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
HEX = [(1, 0), (.5, .87), (-.5, .87), (-1, 0), (-.5, -.87), (.5, -.87)]


def frame(axis, up):
    axis = Vector(axis).normalized()
    side = axis.cross(Vector(up)).normalized()
    upv = side.cross(axis).normalized()
    return axis, side, upv


class MB:
    """Accumulates geometry. Each vertex carries candidate bones for skinning."""

    def __init__(self):
        self.v, self.vb, self.f, self.fc = [], [], [], []

    def vert(self, p, bones):
        self.v.append(Vector(p))
        self.vb.append(tuple(bones))
        return len(self.v) - 1

    def face(self, idx, col):
        self.f.append(list(idx))
        self.fc.append(col)

    # rings: list of lists of 3D points (same count)
    def loft(self, rings, col, bones, cap0=True, cap1=True, seg_cols=None):
        ids = [[self.vert(p, bones) for p in r] for r in rings]
        n = len(rings[0])
        for i in range(len(rings) - 1):
            c = seg_cols[i] if seg_cols else col
            for j in range(n):
                k = (j + 1) % n
                self.face([ids[i][j], ids[i][k], ids[i + 1][k], ids[i + 1][j]], c)
        if cap0:
            self.face(list(reversed(ids[0])), col if not seg_cols else seg_cols[0])
        if cap1:
            self.face(ids[-1], col if not seg_cols else seg_cols[-1])
        return ids

    def tube(self, pts, sizes, col, bones, prof=OCT, up=(0, 0, 1), cap0=True, cap1=True, seg_cols=None, axis=None):
        """pts: centre points; sizes: (half_side, half_up) per point."""
        rings = []
        for i, c in enumerate(pts):
            c = Vector(c)
            if axis is not None:
                ax = Vector(axis)
            else:
                a = Vector(pts[min(i + 1, len(pts) - 1)]) - Vector(pts[max(i - 1, 0)])
                ax = a
            _, side, upv = frame(ax, up)
            rw, rh = sizes[i][:2]
            ring = [c + side * a * rw + upv * b * rh for a, b in prof]
            rings.append(ring)
        return self.loft(rings, col, bones, cap0, cap1, seg_cols)

    def box(self, center, size, col, bones, axis=(0, 0, 1), up=(0, -1, 0)):
        c = Vector(center)
        _, side, upv = frame(axis, up)
        ax = Vector(axis).normalized()
        sx, sy, sz = size  # sx along side, sy along upv, sz along axis
        p0 = c - ax * sz / 2
        p1 = c + ax * sz / 2
        r0 = [p0 + side * a * sx / 2 + upv * b * sy / 2 for a, b in BOX]
        r1 = [p1 + side * a * sx / 2 + upv * b * sy / 2 for a, b in BOX]
        return self.loft([r0, r1], col, bones)

    def seg(self, p0, p1, w, h, col, bones, up=(0, 0, 1), prof=BOX, taper=1.0, cap0=True):
        return self.tube([p0, p1], [(w, h), (w * taper, h * taper)], col, bones, prof=prof, up=up, cap0=cap0)

    def pyramid(self, base, apex, col, bones):
        ids = [self.vert(p, bones) for p in base]
        a = self.vert(apex, bones)
        n = len(ids)
        for j in range(n):
            self.face([ids[j], ids[(j + 1) % n], a], col)
        self.face(list(reversed(ids)), col)

    def merge(self, other, mirror=False):
        off = len(self.v)
        for p, b in zip(other.v, other.vb):
            if mirror:
                p = Vector((-p.x, p.y, p.z))
                b = tuple(mirror_name(x) for x in b)
            self.v.append(p.copy())
            self.vb.append(b)
        for fidx, c in zip(other.f, other.fc):
            idx = [i + off for i in fidx]
            if mirror:
                idx = list(reversed(idx))
            self.f.append(idx)
            self.fc.append(c)

    def tris(self):
        return sum(len(f) - 2 for f in self.f)


def mirror_name(n):
    if n.endswith('_l'):
        return n[:-2] + '_r'
    if n.endswith('_r'):
        return n[:-2] + '_l'
    return n


def vring(z, rx, ryf, ryb, cx=0.0, yc=0.0, prof=OCT, zf=0.0, jitter=0.0, rnd=None):
    """Horizontal ring. b>0 is the FRONT (-Y). zf raises front points."""
    pts = []
    for a, b in prof:
        y = yc - b * (ryf if b > 0 else ryb)
        zz = z + (zf * b if b > 0 else 0)
        if jitter and rnd:
            zz += rnd.uniform(0, jitter)
        pts.append(Vector((cx + a * rx, y, zz)))
    return pts


def xring(x, ry, rz, zc, yc=0.0, prof=OCT, ryb=None):
    """Ring around the X axis (arms in T-pose). a>0 = front (-Y), b>0 = up."""
    ryb = ry if ryb is None else ryb
    return [Vector((x, yc - a * (ry if a > 0 else ryb), zc + b * rz)) for a, b in prof]


def yring(y, rx, rz, cx, zc, prof=OCT):
    """Ring around the Y axis (feet). a = x, b = up."""
    return [Vector((cx + a * rx, y, zc + b * rz)) for a, b in prof]


def c_profile(rx, ry, gap_deg, thick, k=9, yc=0.0, cx=0.0, z=0.0, ryb=None):
    """Closed C-shaped section (open jacket): outer arc + inner arc, gap at the front (-Y)."""
    ryb = ry if ryb is None else ryb
    g = math.radians(gap_deg)
    outer, inner = [], []
    for i in range(k + 1):
        phi = g + (2 * math.pi - 2 * g) * i / k
        s, c = math.sin(phi), -math.cos(phi)
        yy = c * (ry if c < 0 else ryb)
        outer.append(Vector((cx + s * rx, yc + yy, z)))
        f = 1 - thick / max(rx, 1e-4)
        inner.append(Vector((cx + s * rx * f, yc + yy * f, z)))
    return outer + list(reversed(inner))


# ---------------------------------------------------------------- object creation
def build_object(mb, name, mat):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in mb.v], [], mb.f)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    uv = me.uv_layers.new(name='UVMap')
    col = me.color_attributes.new('Col', 'BYTE_COLOR', 'CORNER')
    for p, cname in zip(me.polygons, mb.fc):
        u = swatch_uv(cname)
        r, g, b = PALETTE[cname]
        for li in p.loop_indices:
            uv.data[li].uv = u
            col.data[li].color = (srgb2lin(r), srgb2lin(g), srgb2lin(b), 1.0)
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def srgb2lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def make_material(img_path):
    mat = bpy.data.materials.new('M_Survivor_Palette')
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes['Principled BSDF']
    bsdf.inputs['Roughness'].default_value = 0.9
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(img_path)
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return mat


# ---------------------------------------------------------------- skinning
def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def skin(ob, mb, segments, power=4.0, keep=3):
    """segments: bone name -> (head, tail) Vector pair used as the influence segment."""
    for name in segments:
        if name not in ob.vertex_groups:
            ob.vertex_groups.new(name=name)
    for i, (p, cands) in enumerate(zip(mb.v, mb.vb)):
        if len(cands) == 1:
            ob.vertex_groups[cands[0]].add([i], 1.0, 'REPLACE')
            continue
        ws = []
        for c in cands:
            a, b = segments[c]
            d = seg_dist(p, a, b)
            ws.append((1.0 / (d + 0.012) ** power, c))
        ws.sort(reverse=True)
        ws = ws[:keep]
        tot = sum(w for w, _ in ws)
        for w, c in ws:
            if w / tot > 0.02:
                ob.vertex_groups[c].add([i], w / tot, 'REPLACE')
