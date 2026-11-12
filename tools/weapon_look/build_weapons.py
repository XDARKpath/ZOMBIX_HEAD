import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector, Euler
import kit, weapons2, weapons3  # noqa: F401  (weapons3 registers into weapons2.ASSETS)


def rest_pose(path, rest):
    """The exporter writes each part as the NLA tracks leave it at the current frame (crossbow bolt fired,
    scale 0.001). Put every moving part back on its pivot: Blender (x, y, z) -> glTF (x, z, -y), no rot/scale."""
    import json, struct
    b = open(path, 'rb').read()
    n = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + n])
    for node in j['nodes']:
        if node['name'] in rest:
            p = rest[node['name']]
            node['translation'] = [p.x, p.z, -p.y]
            node.pop('rotation', None)
            node.pop('scale', None)
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    rest_bytes = b[20 + n:]
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + len(rest_bytes)) + struct.pack('<II', len(js), 0x4E4F534A) + js + rest_bytes
    open(path, 'wb').write(out)


OUT = sys.argv[sys.argv.index('--') + 1]
names = sys.argv[sys.argv.index('--') + 2].split(',')
for name in names:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    kit._MATS.clear()
    mats = kit.materials(OUT + '/pal.png', OUT + '/emi.png')
    objs = kit.realize(name, weapons2.ASSETS[name](), mats)
    by = {o.name: o for o in objs}
    rests = {o.name: o.location.copy() for o in objs[1:]}
    anims = weapons2.PART_ANIMS.get(name, {})
    for aname, parts in anims.items():
        for pname, keys in parts.items():
            o = by[pname]; rest = o.location.copy()
            o.animation_data_create()
            act = bpy.data.actions.new(f'{pname}_{aname}')
            o.animation_data.action = act
            for key in keys:
                f, d, r = key[0], key[1], key[2]
                sc = key[3] if len(key) > 3 else 1.0
                o.location = rest + Vector(d); o.rotation_euler = Euler([math.radians(a) for a in r]); o.scale = (sc, sc, sc)
                for p in ('location', 'rotation_euler', 'scale'):
                    o.keyframe_insert(p, frame=f + 1)
            o.animation_data.action = None
            tr = o.animation_data.nla_tracks.new(); tr.name = aname
            tr.strips.new(aname, 1, act)
            o.location, o.rotation_euler, o.scale = rest, (0, 0, 0), (1, 1, 1)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=f'{OUT}/{name}.glb', export_format='GLB', use_selection=True, export_yup=True,
        export_apply=True, export_animations=bool(anims), export_animation_mode='NLA_TRACKS',
        export_force_sampling=True, export_vertex_color='ACTIVE', export_materials='EXPORT')
    rest_pose(f'{OUT}/{name}.glb', rests)
    print('BUILT', name, sum(kit.tris(o) for o in objs if o.type == 'MESH'))
