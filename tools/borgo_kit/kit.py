"""ZOMBIX HEAD environment kit: shared palette (survivor swatches first), prop primitives,
multi-material object builder (opaque palette + glass), text meshes."""
import sys, math, random
import bpy, bmesh
from mathutils import Vector, Matrix, Euler

sys.path.insert(0, '/home/claude/src/Survivor_Operative/source/blender_scripts')
import lib  # noqa: E402  (survivor builder: MB, palette, srgb helpers)
from lib import MB, OCT, BOX, HEX  # noqa: E402,F401

# ---------------------------------------------------------------- palette (appended after the survivor's 41 swatches)
ENV = {
    # wood
    'wood': (138, 98, 62), 'wood_dark': (104, 72, 46), 'wood_light': (168, 126, 82), 'wood_raw': (190, 156, 108),
    'oak': (128, 84, 50), 'oak_dark': (96, 62, 36), 'mahogany': (112, 54, 40), 'mahogany_dark': (84, 40, 30),
    'log': (122, 88, 58), 'log_dark': (94, 66, 42), 'log_end': (184, 148, 98),
    # masonry
    'plaster': (200, 188, 164), 'plaster_dark': (164, 152, 130), 'wallpaper': (120, 132, 110),
    'brick': (152, 76, 58), 'brick_dark': (120, 58, 44), 'mortar': (176, 168, 152),
    'concrete': (152, 152, 148), 'concrete_dark': (114, 114, 112), 'concrete_light': (184, 184, 178),
    'stone': (130, 126, 118), 'stone_dark': (98, 94, 88), 'stone_light': (158, 154, 144),
    # roofing
    'slate': (72, 80, 92), 'slate_dark': (54, 60, 70), 'slate_light': (92, 100, 112),
    'corrugated': (130, 136, 134), 'corrugated_dark': (96, 102, 102),
    'rust': (152, 84, 48), 'rust_dark': (112, 60, 36),
    # metals
    'iron': (72, 74, 78), 'iron_dark': (48, 50, 54), 'steel': (172, 176, 180), 'brass': (198, 160, 74),
    'gold': (222, 178, 66), 'copper': (178, 106, 66),
    # glass (rendered with the transparent material)
    'glass': (168, 212, 222), 'glass_dark': (110, 150, 162),
    # paint
    'paint_red': (178, 50, 42), 'paint_red_dark': (134, 38, 32), 'paint_white': (228, 224, 214),
    'paint_cream': (214, 200, 162), 'paint_black': (34, 34, 36), 'paint_yellow': (224, 180, 50),
    'paint_green': (76, 114, 66), 'paint_green_dark': (58, 88, 50), 'paint_blue': (62, 92, 138),
    'military': (94, 100, 66), 'military_dark': (72, 78, 50), 'military_light': (124, 128, 88),
    'plastic_green': (66, 130, 78), 'plastic_green_dark': (50, 102, 60), 'plastic_grey': (150, 154, 156),
    # fabric / paper
    'cloth_red': (152, 60, 52), 'cloth_white': (214, 208, 194), 'rag': (172, 124, 92), 'rope': (178, 152, 104),
    'paper': (228, 220, 198), 'paper_old': (206, 192, 152), 'cardboard': (172, 134, 90), 'cork': (178, 138, 92),
    'pegboard': (188, 158, 114), 'pegboard_hole': (92, 74, 52), 'felt': (54, 94, 64),
    # weapons
    'gun_black': (40, 40, 43), 'gun_dark': (60, 62, 66), 'gun_metal': (106, 110, 116), 'gun_blued': (52, 58, 70),
    'gun_wood': (126, 78, 46), 'gun_wood_dark': (94, 58, 34), 'polymer_tan': (172, 150, 110),
    'ammo_brass': (206, 166, 82), 'ammo_red': (122, 54, 44), 'ammo_blue': (56, 88, 114), 'oil_can': (178, 60, 46),
    # hazard / signage
    'hazard_yellow': (230, 186, 40), 'hazard_black': (36, 36, 36),
    # emissive (also written to the emission atlas)
    'emit_green': (70, 224, 96), 'emit_red': (238, 58, 50), 'emit_yellow': (252, 212, 96), 'emit_blue': (80, 170, 250),
    # ground
    'dirt': (118, 96, 72), 'grass': (100, 130, 66),
}
EMISSIVE = {'emit_green', 'emit_red', 'emit_yellow', 'emit_blue'}
for _k, _v in ENV.items():
    if _k not in lib.PALETTE:
        lib.PALETTE[_k] = _v
        lib.NAMES.append(_k)
assert len(lib.NAMES) <= 256
P = lib.PALETTE

# ---------------------------------------------------------------- character / infected swatches (appended; keep order)
ENV2 = {
    'skin_dark': (122, 82, 58), 'skin_dark_shadow': (98, 64, 44), 'lips_dark': (88, 54, 42),
    'skin_old': (214, 168, 140), 'skin_fem': (230, 182, 150),
    'hair_black': (30, 28, 28), 'hair_fade': (70, 58, 50), 'hair_grey': (168, 166, 160), 'hair_grey_dark': (132, 130, 126),
    'hair_auburn': (128, 62, 38), 'hair_auburn_dark': (96, 46, 30),
    'hoodie': (104, 108, 116), 'hoodie_dark': (80, 84, 92), 'denim': (74, 98, 134), 'denim_dark': (56, 76, 106),
    'fatigue': (110, 112, 80), 'fatigue_dark': (84, 86, 60),
    'leather': (96, 62, 40), 'leather_dark': (70, 44, 28), 'tweed': (110, 98, 82), 'tweed_dark': (84, 74, 62),
    'flannel': (156, 46, 40), 'flannel_dark': (70, 30, 30), 'tee': (214, 210, 200), 'overall': (66, 84, 104), 'overall_dark': (50, 64, 80),
    'work_glove': (176, 140, 92), 'canvas': (186, 170, 136), 'canvas_dark': (150, 136, 106),
    'zombie': (148, 164, 136), 'zombie_dark': (112, 128, 102), 'zombie_toxic': (156, 170, 92), 'zombie_cloth': (120, 112, 96),
    'zombie_cloth_dark': (90, 84, 72), 'eye_sunken': (46, 20, 20), 'blood': (118, 26, 24), 'blood_dark': (78, 18, 18),
    'bone': (222, 214, 188), 'flesh': (152, 72, 66), 'muscle': (170, 72, 66), 'muscle_dark': (124, 50, 46),
    'police_shirt': (178, 158, 112), 'police_dark': (120, 104, 72), 'police_pants': (82, 78, 72),
    'pale': (196, 190, 180), 'pale_dark': (158, 152, 144), 'lab_white': (214, 216, 212), 'scrubs': (102, 132, 140),
    'toxic_flesh': (112, 132, 80), 'toxic_flesh_dark': (82, 100, 58), 'toxic': (132, 200, 62),
}
for _k, _v in ENV2.items():
    if _k not in lib.PALETTE:
        lib.PALETTE[_k] = _v
        lib.NAMES.append(_k)
assert len(lib.NAMES) <= 256

ENV3 = {
    'alu': (178, 182, 188), 'alu_dark': (128, 132, 140), 'gun_grey': (88, 92, 100), 'gun_slate': (70, 76, 88),
    'blade': (206, 212, 220), 'hamon': (238, 240, 242), 'blade_dark': (150, 156, 166),
    'ito': (40, 42, 62), 'samegawa': (222, 216, 198), 'lacquer': (34, 26, 28), 'lacquer_red': (128, 32, 30), 'sageo': (112, 62, 140),
    'bread': (208, 150, 78), 'bread_dark': (162, 104, 48), 'bread_cut': (238, 210, 156),
    'rubber_yellow': (244, 212, 62), 'beak': (234, 130, 40), 'comb': (214, 50, 44),
    'fish_top': (216, 130, 84), 'fish_patch': (178, 98, 62), 'fish_belly': (242, 238, 228), 'gill': (192, 62, 52),
    'raincoat': (236, 196, 40), 'raincoat_dark': (196, 158, 24), 'wader': (64, 84, 62), 'hazmat': (232, 206, 52),
    'hazmat_dark': (182, 158, 34), 'suit_white': (232, 234, 236), 'suit_grey': (178, 182, 188), 'visor_gold': (214, 164, 60),
    'banana': (246, 220, 70), 'banana_dark': (206, 178, 40), 'banana_tip': (96, 74, 40), 'chicken_white': (240, 238, 232),
    'chicken_shadow': (206, 204, 196), 'mask_black': (36, 38, 40), 'filter_grey': (120, 124, 128),
}
for _k, _v in ENV3.items():
    if _k not in lib.PALETTE:
        lib.PALETTE[_k] = _v
        lib.NAMES.append(_k)
assert len(lib.NAMES) <= 256


def write_palettes(albedo_path, emission_path):
    from PIL import Image
    lib.write_palette(albedo_path)
    im = Image.new('RGB', (256, 256), (0, 0, 0))
    px = im.load()
    for i, n in enumerate(lib.NAMES):
        if n in EMISSIVE:
            cx, cy = (i % 16) * 16, (i // 16) * 16
            for x in range(16):
                for y in range(16):
                    px[cx + x, cy + y] = P[n]
    im.save(emission_path)


# ---------------------------------------------------------------- builder with a transform stack
def R(x=0, y=0, z=0):
    return Euler((math.radians(x), math.radians(y), math.radians(z)))


class K(MB):
    def __init__(self):
        super().__init__()
        self.M = Matrix.Identity(4)
        self._st = []

    def push(self, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
        self._st.append(self.M.copy())
        self.M = self.M @ Matrix.LocRotScale(Vector(loc), R(*rot), Vector(scale))
        return self

    def pop(self):
        self.M = self._st.pop()

    def __enter__(self):
        return self

    def __exit__(self, *a):
        self.pop()

    def at(self, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
        return self.push(loc, rot, scale)

    def vert(self, p, bones=()):
        self.v.append(self.M @ Vector(p))
        self.vb.append(())
        return len(self.v) - 1

    # ------------------------------------------------ primitives (local coordinates)
    def box(self, c, s, col, top=None, bottom=None):
        """Axis-aligned box. c=centre, s=full size (x, y, z)."""
        cx, cy, cz = c
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        p = [(cx + a * hx, cy + b * hy, cz + d * hz) for d in (-1, 1) for b in (-1, 1) for a in (-1, 1)]
        i = [self.vert(q) for q in p]
        self.face([i[0], i[2], i[3], i[1]], bottom or col)       # -z
        self.face([i[4], i[5], i[7], i[6]], top or col)          # +z
        self.face([i[0], i[1], i[5], i[4]], col)                 # -y
        self.face([i[2], i[6], i[7], i[3]], col)                 # +y
        self.face([i[0], i[4], i[6], i[2]], col)                 # -x
        self.face([i[1], i[3], i[7], i[5]], col)                 # +x
        return self

    def boxr(self, x0, y0, z0, x1, y1, z1, col, **kw):
        """Box from min/max corners."""
        return self.box(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), col, **kw)

    def cbox(self, c, s, col, ch=0.02, top=None):
        """Chamfered box (POLYGON-style bevel on every edge)."""
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        ch = min(ch, hx * .45, hy * .45, hz * .45)

        def prof(ix, iy):
            return [(ix, iy - ch), (ix - ch, iy), (-ix + ch, iy), (-ix, iy - ch),
                    (-ix, -iy + ch), (-ix + ch, -iy), (ix - ch, -iy), (ix, -iy + ch)]
        full = prof(hx, hy)
        inset = prof(hx - ch, hy - ch)
        cx, cy, cz = c
        rings = []
        for z, pr in ((-hz, inset), (-hz + ch, full), (hz - ch, full), (hz, inset)):
            rings.append([Vector((cx + a, cy + b, cz + z)) for a, b in pr])
        cols = [col, col, top or col]
        ids = [[self.vert(p) for p in r] for r in rings]
        for i in range(3):
            for j in range(8):
                k = (j + 1) % 8
                self.face([ids[i][j], ids[i][k], ids[i + 1][k], ids[i + 1][j]], cols[i] if i != 1 else col)
        self.face(list(reversed(ids[0])), col)
        self.face(ids[-1], top or col)
        return self

    def cyl(self, p0, p1, r, col, n=8, r1=None, cap=True, cap_col=None, rot=0.0):
        p0, p1 = Vector(p0), Vector(p1)
        ax = (p1 - p0).normalized()
        ref = Vector((0, 0, 1)) if abs(ax.z) < .9 else Vector((0, 1, 0))
        side = ax.cross(ref).normalized()
        up = side.cross(ax).normalized()
        r1 = r if r1 is None else r1
        rings = []
        for c, rr in ((p0, r), (p1, r1)):
            rings.append([c + (side * math.cos(2 * math.pi * (j + rot) / n) + up * math.sin(2 * math.pi * (j + rot) / n)) * rr
                          for j in range(n)])
        ids = [[self.vert(p) for p in rg] for rg in rings]
        for j in range(n):
            k = (j + 1) % n
            self.face([ids[0][j], ids[0][k], ids[1][k], ids[1][j]], col)
        if cap:
            self.face(list(reversed(ids[0])), cap_col or col)
            self.face(ids[1], cap_col or col)
        return self

    def lathe(self, prof, col, n=8, axis='z', cols=None, cap0=True, cap1=True):
        """prof: [(radius, height)] along the axis; revolved n-gon rings."""
        rings = []
        for r, h in prof:
            ring = []
            for j in range(n):
                a = 2 * math.pi * (j + .5) / n
                u, v = math.cos(a) * r, math.sin(a) * r
                ring.append({'z': (u, v, h), 'y': (u, h, v), 'x': (h, u, v)}[axis])
            rings.append(ring)
        ids = [[self.vert(p) for p in rg] for rg in rings]
        for i in range(len(rings) - 1):
            c = cols[i] if cols else col
            for j in range(n):
                k = (j + 1) % n
                self.face([ids[i][j], ids[i][k], ids[i + 1][k], ids[i + 1][j]], c)
        if cap0 and prof[0][0] > 1e-5:
            self.face(list(reversed(ids[0])), cols[0] if cols else col)
        if cap1 and prof[-1][0] > 1e-5:
            self.face(ids[-1], cols[-1] if cols else col)
        return self

    def prism(self, poly, y0, y1, col, side_col=None, back_col=None):
        """Extrude a 2D polygon given in the XZ plane (counter-clockwise seen from -Y) from y0 to y1."""
        f = [self.vert((x, y0, z)) for x, z in poly]
        b = [self.vert((x, y1, z)) for x, z in poly]
        n = len(poly)
        self.face(list(reversed(f)), col)
        self.face(b, back_col or col)
        for j in range(n):
            k = (j + 1) % n
            self.face([f[j], f[k], b[k], b[j]], side_col or col)
        return self

    def prism_x(self, poly, x0, x1, col, side_col=None):
        """Extrude a 2D polygon in the YZ plane along X."""
        f = [self.vert((x0, y, z)) for y, z in poly]
        b = [self.vert((x1, y, z)) for y, z in poly]
        n = len(poly)
        self.face(f, col)
        self.face(list(reversed(b)), col)
        for j in range(n):
            k = (j + 1) % n
            self.face([f[j], b[j], b[k], f[k]], side_col or col)
        return self

    def beam(self, p0, p1, w, h, col, up=(0, 0, 1)):
        """Rectangular bar between two points."""
        p0, p1 = Vector(p0), Vector(p1)
        ax = (p1 - p0).normalized()
        u = Vector(up)
        if abs(ax.dot(u.normalized())) > .95:
            u = Vector((1, 0, 0))
        side = ax.cross(u).normalized()
        upv = side.cross(ax).normalized()
        rings = [[c + side * a * w / 2 + upv * b * h / 2 for a, b in BOX] for c in (p0, p1)]
        ids = [[self.vert(p) for p in rg] for rg in rings]
        for j in range(4):
            k = (j + 1) % 4
            self.face([ids[0][j], ids[0][k], ids[1][k], ids[1][j]], col)
        self.face(list(reversed(ids[0])), col)
        self.face(ids[1], col)
        return self

    def blob(self, c, r, col, rnd, n=6, rings=3, squash=1.0):
        """Faceted low-poly lump (sandbag fill, rag, rubble)."""
        cx, cy, cz = c
        prof = []
        for i in range(rings + 2):
            t = i / (rings + 1)
            prof.append((math.sin(math.pi * t), -math.cos(math.pi * t)))
        rr = []
        for i, (s, h) in enumerate(prof):
            if i in (0, len(prof) - 1):
                rr.append([Vector((cx, cy, cz + h * r[2] * squash))])
                continue
            ring = []
            for j in range(n):
                a = 2 * math.pi * (j + .5 * (i % 2)) / n
                k = rnd.uniform(.85, 1.12)
                ring.append(Vector((cx + math.cos(a) * s * r[0] * k, cy + math.sin(a) * s * r[1] * k,
                                    cz + h * r[2] * squash * rnd.uniform(.9, 1.1))))
            rr.append(ring)
        bot = self.vert(rr[0][0])
        top = self.vert(rr[-1][0])
        mids = [[self.vert(p) for p in rg] for rg in rr[1:-1]]
        for j in range(n):
            k = (j + 1) % n
            self.face([bot, mids[0][k], mids[0][j]], col)
            self.face([top, mids[-1][j], mids[-1][k]], col)
        for i in range(len(mids) - 1):
            for j in range(n):
                k = (j + 1) % n
                self.face([mids[i][j], mids[i][k], mids[i + 1][k], mids[i + 1][j]], col)
        return self

    def text(self, s, size, depth, col, align='CENTER', side_col=None):
        """Low-poly extruded text, front face toward -Y, centred on the local origin, standing in XZ."""
        cu = bpy.data.curves.new('_txt', 'FONT')
        cu.body = s
        cu.size = size
        cu.extrude = depth / 2
        cu.resolution_u = 2
        cu.align_x = align
        cu.align_y = 'CENTER'
        cu.font = bpy.data.fonts.load('<builtin>', check_existing=True)
        ob = bpy.data.objects.new('_txt', cu)
        bpy.context.scene.collection.objects.link(ob)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1), verts=bm.verts, edges=bm.edges)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        # text lies in XY with +Z thickness; rotate to stand in XZ facing -Y
        rot = Matrix.Rotation(math.radians(90), 4, 'X')
        ids = {}
        for v in bm.verts:
            ids[v.index] = self.vert(rot @ v.co)
        for f in bm.faces:
            n = rot.to_3x3() @ f.normal
            c = col if n.y < -.5 else (side_col or col)
            self.face([ids[v.index] for v in f.verts], c)
        bm.free()
        bpy.data.objects.remove(ob)
        bpy.data.curves.remove(cu)
        bpy.data.meshes.remove(me)
        return self


# ---------------------------------------------------------------- materials & objects
_MATS = {}


def materials(albedo, emission):
    if _MATS:
        return _MATS
    img = bpy.data.images.load(albedo)
    eimg = bpy.data.images.load(emission)
    for name, alpha in (('M_Env_Palette', 1.0), ('M_Env_Glass', 0.35)):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes['Principled BSDF']
        bsdf.inputs['Roughness'].default_value = 0.9 if alpha == 1 else 0.1
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = img
        tex.interpolation = 'Closest'
        nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
        if alpha < 1:
            bsdf.inputs['Alpha'].default_value = alpha
            mat.surface_render_method = 'BLENDED'
        else:
            et = nt.nodes.new('ShaderNodeTexImage')
            et.image = eimg
            et.interpolation = 'Closest'
            nt.links.new(et.outputs['Color'], bsdf.inputs['Emission Color'])
            bsdf.inputs['Emission Strength'].default_value = 1.0
        _MATS[name] = mat
    return _MATS


def build(k, name, mats, origin=(0, 0, 0)):
    """K -> mesh object. Faces whose swatch starts with 'glass' use the glass material."""
    o = Vector(origin)
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v - o) for v in k.v], [], k.f)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    uv = me.uv_layers.new(name='UVMap')
    col = me.color_attributes.new('Col', 'BYTE_COLOR', 'CORNER')
    me.materials.append(mats['M_Env_Palette'])
    has_glass = any(c.startswith('glass') for c in k.fc)
    if has_glass:
        me.materials.append(mats['M_Env_Glass'])
    for p, cname in zip(me.polygons, k.fc):
        p.use_smooth = False
        p.material_index = 1 if (has_glass and cname.startswith('glass')) else 0
        u = lib.swatch_uv(cname)
        r, g, b = P[cname]
        for li in p.loop_indices:
            uv.data[li].uv = u
            col.data[li].color = (lib.srgb2lin(r), lib.srgb2lin(g), lib.srgb2lin(b), 1.0)
    ob = bpy.data.objects.new(name, me)
    ob.location = o
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tris(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def pick(rnd, *cols):
    return rnd.choice(cols)


def realize(name, r, mats):
    """Asset builder result -> list of objects (root first). r is a K, or a dict
    {part_name|None: (K|None, pivot)}; the None key is the root (K None -> empty root)."""
    if not isinstance(r, dict):
        return [build(r, name, mats)]
    items = list(r.items())
    (rk, rp) = r[None]
    if rk is None:
        root = bpy.data.objects.new(name, None)
        root.empty_display_size = .3
        bpy.context.scene.collection.objects.link(root)
    else:
        root = build(rk, name, mats, rp)
    out = [root]
    for pn, (k, pivot) in items:
        if pn is None:
            continue
        ob = build(k, pn, mats, pivot)
        ob.parent = root
        ob.location = Vector(pivot) - root.location
        out.append(ob)
    return out
