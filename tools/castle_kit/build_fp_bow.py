"""Arco in prima persona, arco e freccia fermi, gamba del calcio: originali, fatti da zero, tutte le clip calcolate qui.

blender --background --factory-startup --python tools/castle_kit/build_fp_bow.py -- <cartella ZOMBIX_HEAD>

Uscita: art/zx_fp/SM_FP_Bow.glb (braccia, arco, corda, freccia), art/env/weapons/SM_Wep_Bow.glb, SM_Wep_Arrows.glb,
art/zx_fp/SM_FP_Melee.glb (solo gamba e clip Kick). Occhio nell'origine, sguardo -Z, alto +Y (coordinate Godot).
"""
import math, os, sys
import bpy
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_castle_kit as K

PROJECT = K.PROJECT
FPS = 30
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))   # Godot -> Blender


def to_b_pos(v):
    return C @ Vector(v)


def to_b_quat(q):
    return (C @ q.to_matrix() @ C.transposed()).to_quaternion()


def look_quat(z_dir, up=(0, 1, 0)):
    """Rotazione (Godot) che porta il +Z locale su z_dir."""
    z = Vector(z_dir).normalized()
    x = Vector(up).cross(z)
    if x.length < 1e-4:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed().to_quaternion()


def bow_shape(p, grip=True):
    limb = [(-0.035, 0.0), (-0.03, 0.14), (-0.01, 0.3), (0.03, 0.45), (0.1, 0.56), (0.14, 0.6)]
    for s in (-1, 1):
        for i in range(len(limb) - 1):
            a, b = limb[i], limb[i + 1]
            w = 0.03 - i * 0.003
            t = 0.022 - i * 0.002
            pts = [(a[0] - t, s * a[1]), (a[0] + t, s * a[1]), (b[0] + t * 0.85, s * b[1]), (b[0] - t * 0.85, s * b[1])]
            p.side_prism(pts if s > 0 else list(reversed(pts)), -w, w, "wood" if i % 2 else "wood2")
    p.box(-0.032, -0.085, -0.066, 0.032, 0.085, -0.004, "leather")
    for s in (-1, 1):
        p.box(-0.02, s * 0.6 - 0.018, 0.12, 0.02, s * 0.6 + 0.018, 0.165, "bone")


def string_shape(p):
    for s in (-1, 1):
        y0, y1 = (0.0, 0.6) if s > 0 else (-0.6, 0.0)
        p.box(-0.0035, y0, 0.1395, 0.0035, y1, 0.1465, "white")


def arrow_shape(p, tip_axis="z"):
    """Freccia lungo -Z con la cocca a z = 0.14."""
    z0, z1 = 0.14, -0.72
    p.box(-0.005, -0.005, z1 + 0.03, 0.005, 0.005, z0, "plank")
    p.side_prism([(z1 + 0.05, -0.017), (z1 + 0.05, 0.017), (z1 - 0.03, 0.0)], -0.003, 0.003, "steel")
    p.side_prism([(z0 - 0.02, 0.0), (z0 - 0.04, 0.022), (z0 - 0.13, 0.022), (z0 - 0.16, 0.0)], -0.0012, 0.0012, "cloth_r")
    p.side_prism([(z0 - 0.02, -0.022), (z0 - 0.04, 0.0), (z0 - 0.16, 0.0), (z0 - 0.13, -0.022)], -0.0012, 0.0012, "cloth_r")
    p.box(-0.02, -0.0012, z0 - 0.13, 0.02, 0.0012, z0 - 0.04, "cloth_r")


def arm_shape(p, left):
    """Mano nell'origine, avambraccio lungo +Z locale."""
    s = -1 if left else 1
    p.box(-0.04, -0.038, 0.13, 0.04, 0.042, 1.1, "sleeve")
    p.box(-0.044, -0.042, 0.095, 0.044, 0.046, 0.14, "glove")
    p.box(-0.04, -0.038, 0.03, 0.04, 0.04, 0.1, "glove")
    if left:
        for i in range(4):
            y = -0.038 + i * 0.026
            p.box(-0.042, y, -0.03, 0.042, y + 0.022, 0.035, "skin")
            p.box(0.02, y, -0.078, 0.042, y + 0.022, -0.03, "skin")
        p.box(-0.042, 0.04, -0.05, -0.012, 0.062, 0.045, "skin")
    else:
        for i in range(3):
            y = -0.034 + i * 0.024
            p.box(-0.014, y, -0.03, 0.014, y + 0.02, 0.035, "skin")
        p.box(-0.018, 0.04, -0.012, 0.018, 0.056, 0.04, "skin")


def weight_all(ob, arm_ob, bone, predicate=None, other=None):
    groups = {bone: ob.vertex_groups.new(name=bone)}
    if other:
        groups[other] = ob.vertex_groups.new(name=other)
    for v in ob.data.vertices:
        name = other if (other and predicate(v.co)) else bone
        groups[name].add([v.index], 1.0, "REPLACE")
    ob.parent = arm_ob
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_ob


def armature(names):
    data = bpy.data.armatures.new("Rig")
    ob = bpy.data.objects.new("Rig", data)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for n in names:
        b = data.edit_bones.new(n)
        b.head = (0, 0, 0)
        b.tail = (0, 0.1, 0)
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    ob.animation_data_create()
    return ob


def key_clip(ob, clip, frames, fn):
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    ob.animation_data.action = action
    for f in range(frames + 1):
        for bone, (pos, quat) in fn(f / max(frames, 1), f).items():
            pb = ob.pose.bones[bone]
            pb.location = to_b_pos(pos)
            pb.rotation_quaternion = to_b_quat(quat)
            pb.keyframe_insert("location", frame=f, group=bone)
            pb.keyframe_insert("rotation_quaternion", frame=f, group=bone)
    track = ob.animation_data.nla_tracks.new()
    track.name = clip
    track.strips.new(clip, 0, action)
    track.mute = True
    ob.animation_data.action = None


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


REST = {"pos": Vector((-0.3, -0.27, -0.82)), "roll": 24.0, "pitch": 4.0, "yaw": 5.0, "pull": 0.0, "hand_off": Vector((0.0, 0.0, 0.0))}
AIM = {"pos": Vector((-0.17, -0.14, -0.86)), "roll": 8.0, "pitch": 1.0, "yaw": 2.0, "pull": 0.46, "hand_off": Vector((0.0, 0.0, 0.0))}
LOW = {"pos": Vector((-0.34, -0.42, -0.74)), "roll": 34.0, "pitch": 8.0, "yaw": 8.0, "pull": 0.0, "hand_off": Vector((0.34, -0.3, 0.12))}


def mix(a, b, t):
    return {k: (a[k].lerp(b[k], t) if isinstance(a[k], Vector) else a[k] + (b[k] - a[k]) * t) for k in a}


def bones_of(st, offset=(0, 0, 0)):
    q = Quaternion((0, 1, 0), math.radians(st["yaw"])) @ Quaternion((1, 0, 0), math.radians(st["pitch"])) @ Quaternion((0, 0, 1), math.radians(st["roll"]))
    pos = st["pos"] + Vector(offset)
    pull = Vector((0, 0, st["pull"]))
    string = pos + q @ pull
    hand_l = pos + q @ Vector((0, 0, -0.03))
    nock = pos + q @ (pull + Vector((0, 0, 0.14)))
    hand_r = nock + st["hand_off"]
    elbow_l = hand_l + Vector((-0.12, -0.42, 0.62))
    elbow_r = hand_r + Vector((0.46, -0.3, 0.3))
    q_l = look_quat(elbow_l - hand_l, q @ Vector((0, 1, 0)))
    q_r = look_quat(elbow_r - hand_r, q @ Vector((0, 1, 0)))
    return {"Bow": (pos, q), "String": (string, q), "Arrow": (string, q), "ArmL": (hand_l, q_l), "ArmR": (hand_r, q_r)}


def build_viewmodel():
    K.clean_scene()
    rig = armature(["Bow", "String", "Arrow", "ArmL", "ArmR"])
    def add(name, shape, bone, **kw):
        p = K.Piece(name)
        shape(p)
        ob = p.obj()
        weight_all(ob, rig, bone, **kw)
    add("arc", bow_shape, "Bow")
    # Blender: il centro della corda (y Godot = 0) è z Blender = 0.
    add("corde", string_shape, "Bow", predicate=lambda co: abs(co.z) < 0.02, other="String")
    add("fleche", arrow_shape, "Arrow")
    add("Arms_L", lambda p: arm_shape(p, True), "ArmL")
    add("Arms_R", lambda p: arm_shape(p, False), "ArmR")

    def loop(state, bob, sway, freq=1):
        def fn(t, f):
            a = t * math.tau * freq
            return bones_of(state, (math.sin(a) * sway, math.sin(a * 2) * bob, 0))
        return fn

    def bar(state):
        return lambda t, f: bones_of(state)

    def rest_without_arrow():
        s = dict(REST)
        s["hand_off"] = Vector((0.16, -0.2, 0.08))
        return s

    def fire(t, f):
        if t < 0.1:
            s = mix(AIM, dict(AIM, pull=0.0), t / 0.1)
        else:
            s = mix(dict(AIM, pull=0.0, pos=AIM["pos"] + Vector((0, 0.012, 0.02))), REST, ease((t - 0.1) / 0.9))
        return bones_of(s)

    def reload(t, f):
        if t < 0.35:
            s = mix(REST, LOW, ease(t / 0.35))
        elif t < 0.55:
            s = LOW
        else:
            s = mix(LOW, REST, ease((t - 0.55) / 0.45))
        return bones_of(s)

    empty = rest_without_arrow()
    clips = {
        "Bow_IDLE": (40, loop(REST, 0.004, 0.003)),
        "Bow_IDLE_NoArrow": (40, loop(empty, 0.004, 0.003)),
        "Bow_WALK": (40, loop(REST, 0.012, 0.012, 2)),
        "Bow_WALK_NoArrow": (40, loop(empty, 0.012, 0.012, 2)),
        "Bow_RUN": (20, loop(mix(REST, LOW, 0.45), 0.024, 0.026)),
        "Bow_RUN_NoArrow": (20, loop(mix(empty, LOW, 0.45), 0.024, 0.026)),
        "Bow_FALL": (20, bar(dict(REST, pos=REST["pos"] + Vector((0, 0.05, 0))))),
        "Bow_FALL_NoArrow": (20, bar(dict(empty, pos=empty["pos"] + Vector((0, 0.05, 0))))),
        "Bow_AIM": (24, lambda t, f: bones_of(mix(REST, AIM, ease(t)))),
        "Bow_AIM_IDLE": (40, loop(AIM, 0.0025, 0.002)),
        "Bow_FIRE": (18, fire),
        "Bow_RELOAD": (35, reload),
    }
    for name, (frames, fn) in clips.items():
        key_clip(rig, name, frames, fn)
    path = os.path.join(PROJECT, "art/zx_fp/SM_FP_Bow.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_def_bones=False, export_yup=True, export_apply=False, export_optimize_animation_size=False)
    print("SCRITTO", path, list(clips))


def build_stills():
    K.clean_scene()
    p = K.Piece("SM_Wep_Bow")
    bow_shape(p)
    string_shape(p)
    # Arco centrato: impugnatura nell'origine, lungo Y.
    m = K.MIS["singoli"]["SM_Wep_Bow"]
    a, b = p.bounds()
    half_z = (b[2] - a[2]) / 2
    p.fit([-0.03, m["min"][1], -half_z], [0.03, m["max"][1], half_z])
    p.obj()
    K.export(os.path.join(PROJECT, "art/env/weapons/SM_Wep_Bow.glb"))
    K.clean_scene()
    p = K.Piece("SM_Wep_Arrows")
    arrow_shape(p)
    # La freccia punta lungo +Y: da -Z a +Y.
    for v in p.bm.verts:
        x, y, z = v.co
        v.co = Vector((x, -z, y))
    m = K.MIS["singoli"]["SM_Wep_Arrows"]
    p.fit([-0.02, m["min"][1], -0.022], [0.02, m["max"][1], 0.022])
    p.obj()
    K.export(os.path.join(PROJECT, "art/env/weapons/SM_Wep_Arrows.glb"))


def build_leg():
    K.clean_scene()
    rig = armature(["Thigh", "Calf"])
    thigh = K.Piece("FP_Leg_Thigh")
    thigh.box(-0.075, -0.45, -0.09, 0.075, 0.0, 0.09, "sleeve")
    t = thigh.obj()
    weight_all(t, rig, "Thigh")
    calf = K.Piece("FP_Leg_Calf")
    calf.box(-0.06, -0.42, -0.07, 0.06, 0.0, 0.07, "sleeve")
    calf.box(-0.07, -0.5, -0.08, 0.07, -0.34, 0.08, "leather")
    calf.box(-0.07, -0.56, -0.24, 0.07, -0.5, 0.08, "leather")
    calf.box(-0.074, -0.59, -0.26, 0.074, -0.56, 0.09, "soot")
    c = calf.obj()
    weight_all(c, rig, "Calf")
    hip = Vector((0.12, -0.6, 0.02))

    def pose(hip_deg, knee_deg):
        qt = Quaternion((1, 0, 0), math.radians(hip_deg))
        qc = qt @ Quaternion((1, 0, 0), math.radians(-knee_deg))
        knee = hip + qt @ Vector((0, -0.45, 0))
        return {"Thigh": (hip, qt), "Calf": (knee, qc)}

    keys = [(0, 8, 30), (5, 62, 70), (8, 96, 6), (13, 88, 12), (18, 8, 30)]

    def kick(t, f):
        for (f0, h0, k0), (f1, h1, k1) in zip(keys, keys[1:]):
            if f <= f1:
                u = ease((f - f0) / (f1 - f0))
                return pose(h0 + (h1 - h0) * u, k0 + (k1 - k0) * u)
        return pose(*keys[-1][1:])

    key_clip(rig, "Kick", 18, kick)
    path = os.path.join(PROJECT, "art/zx_fp/SM_FP_Melee.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_def_bones=False, export_yup=True, export_apply=False, export_optimize_animation_size=False)
    print("SCRITTO", path)


bpy.context.scene.render.fps = FPS
bpy.context.scene.render.fps_base = 1.0
build_viewmodel()
build_stills()
build_leg()
print("FINE ARCO")
