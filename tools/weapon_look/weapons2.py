"""Weapons v2: chunky, detailed, bevelled low-poly guns and blades (How to Fish style).
Gun frame = Survivor weapon_r socket: origin at the firing-hand grip, +Y muzzle, +Z top, +X right.
Blades are modelled in a blade frame (+Z blade, +Y edge, origin at the right hand) and tilted
-17 deg about X into the gun frame, so every weapon uses the same socket and the same Godot basis.
Moving parts are child meshes with their pivot on the motion axis; PART_ANIMS keys them (30 fps)."""
import math, random
from mathutils import Vector, Matrix
from kit import K, worn

GRIP_TILT = -17.0           # blade frame -> gun frame


def slot(k, x, y0, y1, z0, z1, col='gun_black', d=.0015):
    """Fake cut-out: thin dark plate standing just proud of an X-facing surface at x."""
    s = 1 if x >= 0 else -1
    k.boxr(x, y0, z0, x + s * d, y1, z1, col)


def screws(k, pts, r=.004, col='steel', axis='x'):
    for p in pts:
        p = Vector(p)
        d = Vector((.004 if p.x >= 0 else -.004, 0, 0)) if axis == 'x' else Vector((0, 0, .004))
        k.cyl(p, p + d, r, col, n=6)


def bore(k, y, z, r, x=0.0):
    """Dark disc on the muzzle face: the bore reads as an opening at game distance."""
    k.cyl((x, y, z), (x, y + .0012, z), r, 'paint_black', n=8)


def rail(k, y0, y1, z, w=.022, col='gun_black', pitch=.012):
    k.boxr(-w / 2, y0, z, w / 2, y1, z + .006, col)
    y = y0 + .003
    while y + .006 < y1:
        k.boxr(-w / 2 - .002, y, z + .006, w / 2 + .002, y + .006, z + .011, col)
        y += pitch


# ================================================================ assault rifle (M4 pattern)
def ar_body():
    k = K()
    G, D, M = 'gun_grey', 'gun_black', 'gun_metal'
    k.cbox((0, .035, .012), (.046, .19, .066), D, ch=.007)                          # lower receiver
    k.prism_x([(.06, -.02), (.135, -.02), (.135, -.035), (.06, -.035)], -.026, .026, D)   # magwell flare
    k.cbox((0, .05, .072), (.05, .27, .052), G, ch=.008)                            # upper receiver
    slot(k, .0251, .02, .1, .055, .085, D)                                          # ejection port
    k.boxr(.025, .02, .052, .03, .10, .058, M)                                      # port door hinge
    k.cyl((.026, -.02, .07), (.04, -.02, .07), .009, M, n=8)                        # forward assist
    k.cyl((-.023, .08, .03), (-.03, .08, .03), .008, M, n=6)                        # mag release
    k.cyl((-.023, -.01, .02), (-.034, -.01, .02), .007, M, n=6)                     # safety
    rail(k, -.08, .18, .098, col=D)
    # free-float M-LOK handguard (octagon) with slots
    k.push((0, .33, .07))
    k.lathe([(.0345, -.15), (.0345, .15)], G, n=8, axis='y')
    k.pop()
    for i in range(5):
        y = .21 + i * .05
        slot(k, .0326, y, y + .032, .058, .082, D)
        slot(k, -.0326, y, y + .032, .058, .082, D)
        k.boxr(-.01, y, .035, .01, y + .03, .0365, D)
    rail(k, .18, .48, .1, col=D)
    # barrel, gas block, compensator
    k.cyl((0, .48, .07), (0, .60, .07), .012, M, n=8)
    k.cbox((0, .505, .07), (.03, .03, .034), D, ch=.004)
    k.push((0, .64, .07))
    k.lathe([(.018, -.04), (.02, -.035), (.02, .035), (.017, .04)], D, n=8, axis='y')
    k.pop()
    bore(k, .68, .07, .007)
    for i in range(3):
        slot(k, .0201, .615 + i * .02, .627 + i * .02, .062, .078, 'gun_black')
        slot(k, -.0201, .615 + i * .02, .627 + i * .02, .062, .078, 'gun_black')
    # flip sights
    k.prism_x([(.44, .1), (.47, .1), (.465, .14), (.45, .14)], -.008, .008, D)
    k.prism_x([(-.07, .104), (-.04, .104), (-.045, .135), (-.065, .135)], -.012, .012, D)
    # red-dot optic
    k.cbox((0, .085, .118), (.034, .07, .03), D, ch=.005)
    k.push((0, .085, .148))
    k.lathe([(.02, -.035), (.024, -.03), (.024, .03), (.02, .035)], D, n=8, axis='y')
    k.pop()
    k.boxr(-.017, .118, .133, .017, .121, .163, 'glass')
    k.cbox((0, .09, .148), (.004, .004, .004), 'emit_red', ch=.001)
    k.cyl((.024, .085, .148), (.034, .085, .148), .008, M, n=6)
    # buffer tube + stock with cut-out
    k.cyl((0, -.08, .07), (0, -.24, .07), .016, M, n=8)
    k.cprism_x([(-.14, .093), (-.29, .098), (-.31, .08), (-.31, -.04), (-.27, -.04), (-.2, .028), (-.14, .046)], -.022, .022, D, ch=.005)
    slot(k, .0221, -.255, -.215, .02, .07, 'gun_slate')
    slot(k, -.0221, -.255, -.215, .02, .07, 'gun_slate')
    k.cbox((0, -.317, .029), (.048, .016, .142), 'gun_slate', ch=.004)
    # pistol grip with texture bands
    k.cprism_x([(.012, -.02), (-.035, -.02), (-.075, -.125), (-.032, -.13)], -.016, .016, D, ch=.004, edge=worn(D))
    for i in range(3):
        slot(k, .0161, -.045 - i * .012, -.035 - i * .012, -.04 - i * .028, -.03 - i * .028, 'gun_slate')
    # trigger guard
    k.boxr(-.006, -.0, -.052, .006, .06, -.045, D)
    k.boxr(-.006, .054, -.052, .006, .062, -.02, D)
    k.boxr(-.003, .022, -.04, .003, .03, -.018, M)
    # sling loop
    k.cbox((0, -.3, -.02), (.008, .02, .02), M, ch=.002)
    return k


def ar_mag():
    k = K()
    k.prism_x([(-.03, 0), (.036, 0), (.05, -.09), (.085, -.17), (.03, -.185), (.0, -.10)], -.015, .015, 'gun_dark')
    for i in range(4):
        z = -.03 - i * .035
        y = -.01 + i * .02
        slot(k, .0151, y, y + .03, z - .006, z, 'gun_black')
        slot(k, -.0151, y, y + .03, z - .006, z, 'gun_black')
    k.prism_x([(.028, -.178), (.09, -.163), (.095, -.185), (.033, -.2)], -.017, .017, 'gun_black')
    k.boxr(-.008, -.02, -.002, .008, .02, .006, 'ammo_brass')
    return k


def ar_charging():
    k = K()
    k.boxr(-.006, -.02, -.004, .006, .04, .006, 'gun_black')
    k.boxr(-.022, -.03, -.006, .022, -.018, .008, 'gun_black')
    return k


# ================================================================ pump shotgun (tactical)
def sg_body():
    """Pump gun, condition: heavily used. Anodised receiver with a real ejection port, polymer furniture,
    rubber butt pad, crowned muzzle with a bore. Wear only where hands and kit rub: receiver edges, grip, pump ribs."""
    k = K()
    D, G, M, P = 'gun_black', 'gun_grey', 'gun_metal', 'gun_dark'
    k.cbox((0, .06, .045), (.040, .23, .078), G, ch=.008, edge=worn(G))           # receiver core
    for y0, y1, z0, z1 in ((-.047, .167, .014, .045), (-.047, .167, .070, .076),
                           (.14, .167, .045, .070), (-.047, .07, .045, .070)):    # right wall around the port
        k.boxr(.019, y0, z0, .023, y1, z1, G)
    k.boxr(.0185, .07, .045, .0195, .14, .070, 'paint_black')                       # port: inside of the receiver
    k.boxr(.012, .07, .049, .0192, .082, .066, M)                                   # bolt face at the back of the port
    k.boxr(-.024, .08, .005, .024, .15, .012, D)                                    # loading port
    rail(k, -.03, .16, .084, w=.018, col=D)
    k.push((0, 0, .066))                                                            # barrel, crowned, with bore
    k.lathe([(.0135, .17), (.0135, .75), (.0095, .75), (.0095, .738)], M, n=8, axis='y',
            cols=[M, 'steel', 'paint_black'])
    k.pop()
    for i in range(7):                                                              # heat shield
        y = .2 + i * .065
        k.cbox((0, y + .025, .074), (.036, .05, .018), D, ch=.004)
        slot(k, .0181, y + .01, y + .04, .068, .078, 'gun_slate')
    k.cyl((0, .17, .032), (0, .65, .032), .0125, M, n=8)                            # mag tube
    k.cyl((0, .645, .032), (0, .665, .032), .017, D, n=8)
    k.cbox((0, .69, .05), (.028, .03, .05), D, ch=.004)                             # barrel clamp
    k.cbox((0, .74, .092), (.008, .008, .02), 'paint_red', ch=.002)                 # front sight (fibre)
    k.prism_x([(-.02, .084), (.01, .084), (.005, .11), (-.015, .11)], -.016, .016, D)   # ghost ring
    k.cyl((-.006, -.004, .102), (.006, -.004, .102), .008, D, n=8)
    # side saddle with shells
    k.cbox((-.03, .05, .04), (.016, .12, .05), D, ch=.003)
    for i in range(5):
        y = .005 + i * .023
        k.cyl((-.04, y, .018), (-.04, y, .064), .009, 'ammo_red', n=8, cap_col='ammo_red')
        k.cyl((-.04, y, .012), (-.04, y, .02), .0095, 'ammo_brass', n=8)
    # stock: slim wrist behind the grip, straight comb, toe line, rubber pad, sling stud
    k.cprism_x([(-.05, .076), (-.05, .006), (-.10, .002), (-.16, -.018), (-.42, -.085), (-.42, .045),
                (-.20, .060), (-.12, .062)], -.019, .019, P, ch=.006)
    k.cbox((0, -.428, -.02), (.042, .018, .138), 'rubber', ch=.005)
    k.cyl((0, -.36, -.068), (0, -.36, -.08), .004, 'steel', n=6)
    # pistol grip: rounded backstrap, the hand polishes its edges
    k.cprism_x([(.012, 0), (-.035, 0), (-.042, -.025), (-.076, -.108), (-.074, -.121), (-.030, -.124),
                (-.022, -.112), (-.008, -.035)], -.016, .016, P, ch=.004, edge=worn(P))
    k.boxr(-.006, -.01, -.03, .006, .055, -.023, D)                                 # trigger guard
    k.boxr(-.006, .049, -.03, .006, .057, .005, D)
    k.boxr(-.003, .012, -.02, .003, .02, .002, M)                                   # trigger
    return k


def sg_pump():
    k = K()
    k.push((0, 0, 0))
    k.lathe([(.022, -.08), (.03, -.068), (.03, .068), (.024, .08)], 'gun_dark', n=8, axis='y')
    k.pop()
    for i in range(6):
        y = -.06 + i * .023
        k.lathe([(.0318, y), (.0318, y + .009)], worn('gun_dark'), n=8, axis='y', cap0=False, cap1=False)
    k.boxr(-.005, -.05, .02, .005, .05, .034, 'gun_black')
    return k


# ================================================================ sniper (skeletal chassis, big scope)
def sn_body():
    k = K()
    A, AD, D, M = 'alu', 'alu_dark', 'gun_black', 'gun_metal'
    # chassis with lightening cut-outs
    k.cbox((0, .14, .03), (.05, .46, .055), A, ch=.008)
    for i in range(6):
        y = .0 + i * .06
        slot(k, .0251, y, y + .04, .015, .045, D)
        slot(k, -.0251, y, y + .04, .015, .045, D)
    k.cbox((0, .04, .07), (.044, .2, .04), 'gun_grey', ch=.006)          # action
    slot(k, .0221, .03, .11, .062, .085, D)
    rail(k, -.06, .2, .09, w=.022, col=D)
    k.cyl((0, .14, .07), (0, .86, .07), .016, D, n=8, r1=.013)           # fluted heavy barrel
    for a in range(4):
        r = math.radians(45 + a * 90)
        p0 = Vector((math.cos(r) * .0158, 0, .07 + math.sin(r) * .0158))
        k.boxr(p0.x - .002, .32, p0.z - .002, p0.x + .002, .78, p0.z + .002, 'gun_slate')
    k.push((0, .9, .07))                                                 # muzzle brake
    k.lathe([(.022, -.05), (.024, -.045), (.024, .045), (.02, .05)], D, n=8, axis='y')
    k.pop()
    bore(k, .95, .07, .008)
    for i in range(3):
        slot(k, .0241, .865 + i * .025, .88 + i * .025, .06, .08, 'gun_slate')
        slot(k, -.0241, .865 + i * .025, .88 + i * .025, .06, .08, 'gun_slate')
    # scope + rings
    k.push((0, .06, .14))
    k.lathe([(.028, -.2), (.03, -.17), (.02, -.13), (.019, .05), (.03, .1), (.034, .16), (.034, .2)], D, n=10, axis='y',
            cols=[D, D, D, 'gun_slate', D, D])
    k.pop()
    k.boxr(-.03, .255, .108, .03, .259, .172, 'glass')
    k.boxr(-.026, -.141, .114, .026, -.143, .166, 'glass')
    k.cyl((0, .06, .159), (0, .06, .182), .014, 'gun_slate', n=8)        # elevation turret
    k.cyl((.019, .06, .14), (.042, .06, .14), .014, 'gun_slate', n=8)    # windage
    k.cyl((-.019, .03, .14), (-.036, .03, .14), .01, D, n=8)             # parallax
    for y in (-.03, .12):
        k.cbox((0, y, .118), (.05, .022, .03), A, ch=.004)
        k.cbox((0, y, .143), (.07, .018, .05), A, ch=.008)
        screws(k, [(.034, y, .13), (-.034, y, .13)], col=D)
    # skeletal stock + cheek riser
    k.cprism_x([(-.06, .08), (-.06, -.0), (-.42, -.06), (-.46, -.06), (-.46, .1), (-.2, .1)], -.022, .022, A, ch=.005)
    for poly in ([(-.12, .07), (-.2, .065), (-.2, .015), (-.12, .03)], [(-.24, .065), (-.38, .06), (-.38, -.03), (-.24, .0)]):
        k.prism_x(poly, .0221, .0236, D)
        k.prism_x(poly, -.0236, -.0221, D)
    k.cbox((0, -.3, .115), (.034, .2, .03), AD, ch=.006)
    k.cyl((0, -.3, .1), (0, -.3, .068), .006, D, n=6)
    k.cbox((0, -.47, .02), (.05, .018, .17), 'gun_slate', ch=.005)
    k.cbox((0, -.4, -.075), (.03, .07, .03), AD, ch=.005)                # monopod
    # pistol grip
    k.cprism_x([(.012, -.0), (-.035, -.0), (-.075, -.125), (-.032, -.13)], -.017, .017, D, ch=.004, edge=worn(D))
    k.boxr(-.006, -.0, -.035, .006, .06, -.028, D)
    k.boxr(-.003, .022, -.028, .003, .028, -.005, M)
    # folded bipod
    k.cbox((0, .36, .0), (.03, .04, .03), D, ch=.004)
    for s in (1, -1):
        k.cbox((s * .014, .46, -.008), (.01, .2, .012), D, ch=.003)
        k.cbox((s * .014, .565, -.01), (.014, .02, .016), 'gun_slate', ch=.003)
    return k


def sn_bolt():
    """Bolt handle; pivot on the bore axis at the rear of the action."""
    k = K()
    k.cyl((0, -.02, 0), (0, .02, 0), .011, 'steel', n=8)
    k.beam((.008, 0, 0), (.055, -.012, -.022), .009, .009, 'steel')
    k.push((.06, -.014, -.026))
    k.lathe([(.0, -.015), (.012, -.01), (.012, .01), (.0, .015)], 'gun_black', n=8, axis='x')
    k.pop()
    return k


def sn_mag():
    k = K()
    k.cbox((0, .0, -.03), (.036, .07, .06), 'gun_black', ch=.006)
    k.boxr(-.012, -.02, -.002, .012, .02, .004, 'ammo_brass')
    return k


# ================================================================ revolver
def rv_body():
    k = K()
    S, D = 'steel', 'gun_slate'
    k.cbox((0, .03, .07), (.03, .12, .02), S, ch=.004)                     # top strap
    k.cbox((0, .035, .022), (.03, .11, .024), S, ch=.004)                  # bottom frame
    k.cbox((0, -.02, .045), (.03, .03, .07), S, ch=.005)                   # recoil shield
    k.cbox((0, .09, .046), (.03, .02, .07), S, ch=.004)
    k.cbox((0, .17, .052), (.026, .16, .036), S, ch=.006)                  # full-lug barrel
    k.boxr(-.007, .09, .072, .007, .25, .08, S)                            # vent rib
    for i in range(5):
        k.boxr(-.0072, .1 + i * .03, .073, .0072, .112 + i * .03, .078, D)
    k.cyl((0, .25, .06), (0, .254, .06), .008, 'gun_black', n=8)
    k.prism_x([(.235, .08), (.25, .08), (.248, .094), (.238, .094)], -.004, .004, 'paint_red')
    k.prism_x([(-.03, .08), (-.015, .08), (-.018, .09), (-.028, .09)], -.009, .009, D)
    slot(k, .0131, .1, .24, .036, .044, D)
    slot(k, -.0131, .1, .24, .036, .044, D)
    # wood grip with finger grooves + medallion
    k.cprism_x([(.0, .02), (-.03, .03), (-.04, .0), (-.065, -.05), (-.07, -.075), (-.04, -.08), (-.03, -.055), (-.01, -.02)],
               -.018, .018, 'gun_wood', ch=.004, edge=worn('gun_wood'))
    for i in range(3):
        slot(k, .0181, -.05 - i * .008, -.038 - i * .008, -.008 - i * .02, -.001 - i * .02, 'gun_wood_dark')
    k.cyl((.0181, -.042, -.03), (.0195, -.042, -.03), .007, 'gold', n=8)
    k.cyl((-.0181, -.042, -.03), (-.0195, -.042, -.03), .007, 'gold', n=8)
    k.boxr(-.005, .0, -.012, .005, .05, -.006, S)                          # trigger guard
    k.boxr(-.005, .044, -.012, .005, .05, .01, S)
    k.boxr(-.0025, .018, -.004, .0025, .024, .012, D)
    return k


def rv_cylinder():
    """Cylinder on its own axis (pivot = cylinder centre)."""
    k = K()
    k.lathe([(.016, -.026), (.024, -.022), (.024, .022), (.02, .026)], 'gun_metal', n=12, axis='y')
    for i in range(6):
        a = 2 * math.pi * i / 6
        x, z = math.cos(a) * .014, math.sin(a) * .014
        k.cyl((x, .0262, z), (x, .0272, z), .0045, 'gun_black', n=6)
        a2 = a + math.pi / 6
        x2, z2 = math.cos(a2) * .0235, math.sin(a2) * .0235
        k.boxr(x2 - .002, -.012, z2 - .002, x2 + .002, .012, z2 + .002, 'gun_slate')
    return k


def rv_hammer():
    k = K()
    k.prism_x([(.0, -.004), (.006, .012), (-.022, .03), (-.03, .024), (-.012, -.004)], -.005, .005, 'gun_slate')
    return k


# ================================================================ pistol
def ps_frame():
    k = K()
    D, S = 'gun_black', 'gun_slate'
    k.cbox((0, .065, .022), (.029, .17, .026), D, ch=.004)
    rail(k, .1, .15, .006, w=.02, col=D)
    k.prism_x([(.014, .012), (-.03, .016), (-.065, -.095), (-.022, -.1)], -.0155, .0155, D)
    for i in range(4):                                                       # grip stippling
        slot(k, .0156, -.035 - i * .009, -.02 - i * .009, -.01 - i * .02, -.003 - i * .02, S)
        slot(k, -.0156, -.035 - i * .009, -.02 - i * .009, -.01 - i * .02, -.003 - i * .02, S)
    k.boxr(-.006, .0, -.012, .006, .06, -.006, D)
    k.boxr(-.006, .054, -.012, .006, .06, .01, D)
    k.boxr(-.0025, .016, -.006, .0025, .022, .012, S)
    k.cyl((.0155, .07, .022), (.0175, .07, .022), .004, 'steel', n=6)        # slide stop
    return k


def ps_slide():
    k = K()
    k.cbox((0, .07, .052), (.028, .2, .034), 'gun_metal', ch=.005)
    for i in range(6):
        slot(k, .0141, -.02 + i * .008, -.016 + i * .008, .04, .066, 'gun_slate')
        slot(k, -.0141, -.02 + i * .008, -.016 + i * .008, .04, .066, 'gun_slate')
    slot(k, .0141, .06, .1, .055, .068, 'gun_black')
    k.boxr(-.004, .156, .069, .004, .164, .077, 'gun_black')
    k.cbox((0, .161, .077), (.003, .003, .003), 'emit_green', ch=.001)
    k.boxr(-.01, -.024, .069, .01, -.014, .078, 'gun_black')
    k.cyl((0, .17, .049), (0, .172, .049), .0065, 'gun_black', n=8)
    return k


def ps_mag():
    k = K()
    k.prism_x([(-.012, 0), (.012, 0), (-.012, -.1), (-.036, -.1)], -.011, .011, 'gun_dark')
    k.prism_x([(-.016, -.098), (-.008, -.098), (-.008, -.112), (-.042, -.112), (-.042, -.098)], -.013, .013, 'gun_black')
    k.boxr(-.005, -.01, -.002, .005, .01, .004, 'ammo_brass')
    return k


# ================================================================ SMG (MAC-10 pattern)
def smg_body():
    k = K()
    G, D = 'gun_grey', 'gun_black'
    k.cbox((0, .05, .04), (.05, .26, .06), G, ch=.008)
    slot(k, .0251, .07, .13, .03, .05, D)
    for i in range(4):
        slot(k, -.0251, .0 + i * .05, .03 + i * .05, .025, .055, 'gun_slate')
    k.boxr(-.004, -.06, .07, .004, .16, .074, D)                             # top slot for the bolt knob
    k.cbox((0, .195, .04), (.04, .04, .05), D, ch=.006)
    k.cyl((0, .21, .045), (0, .27, .045), .011, 'gun_metal', n=8)            # threaded barrel
    for i in range(4):
        k.cyl((0, .23 + i * .01, .045), (0, .235 + i * .01, .045), .0125, 'gun_slate', n=8)
    bore(k, .27, .045, .006)
    k.cbox((0, .215, .01), (.02, .02, .02), D, ch=.004)                      # strap loop
    k.boxr(-.004, .2, -.004, .004, .23, .004, 'gun_metal')
    # grip (mag goes inside)
    k.cprism_x([(.035, .012), (-.01, .012), (-.02, -.12), (.022, -.12)], -.017, .017, D, ch=.004, edge=worn(D))
    k.boxr(-.006, .03, -.025, .006, .1, -.018, D)
    k.boxr(-.006, .094, -.025, .006, .1, .01, D)
    k.boxr(-.0025, .052, -.018, .0025, .058, .006, 'gun_metal')
    # folded wire stock
    for s in (1, -1):
        k.cbox((s * .028, -.06, .02), (.006, .16, .008), 'gun_metal', ch=.002)
    k.cbox((0, -.14, .02), (.062, .01, .03), 'gun_black', ch=.003)
    # suppressor
    k.push((0, .38, .045))
    k.lathe([(.022, -.11), (.026, -.1), (.026, .1), (.02, .11)], D, n=10, axis='y')
    k.pop()
    k.push((0, 0, .045))
    for i in range(3):
        k.lathe([(.0265, .3 + i * .07), (.0265, .31 + i * .07)], 'gun_slate', n=10, axis='y', cap0=False, cap1=False)
    k.pop()
    return k


def smg_mag():
    k = K()
    k.cbox((0, .0, -.08), (.024, .03, .16), 'gun_dark', ch=.004)
    k.cbox((0, .0, -.163), (.03, .036, .012), 'gun_black', ch=.003)
    return k


def smg_knob():
    k = K()
    k.cyl((0, 0, 0), (0, 0, .018), .004, 'gun_metal', n=6)
    k.cyl((0, 0, .018), (0, 0, .028), .009, 'gun_black', n=8)
    return k


# ================================================================ blades
def tilt(k):
    """Enter the blade frame (call k.pop() afterwards)."""
    return k.push((0, 0, 0), (GRIP_TILT, 0, 0))


def curved(z, sori=.022, L=.74):
    t = max(0.0, z - .06) / L
    return -sori * 4 * (t * t * .9 + t * .1) * .5


def katana():
    k = K()
    tilt(k)
    rnd = random.Random(2)
    # tsuka (handle): alternating ito / samegawa rings form the diamond wrap
    zs = [-.24 + i * .026 for i in range(11)]
    prof = []
    for i, z in enumerate(zs):
        prof.append(((.0165 if i % 2 else .0135), z))
    k.push((0, 0, 0), (0, 0, 0))
    k.lathe([(.0145, -.245)] + prof + [(.015, .03)], 'ito', n=8, axis='z',
            cols=['lacquer'] + [('ito' if i % 2 else 'samegawa') for i in range(len(prof))])
    k.pop()
    k.lathe([(.0, -.262), (.016, -.258), (.017, -.244)], 'gun_slate', n=8, axis='z')        # kashira
    for z in (-.15, -.11):                                                                  # menuki
        k.cbox((.0172, .0, z), (.004, .012, .022), 'gold', ch=.002)
    k.lathe([(.0172, .03), (.0172, .04)], 'gold', n=8, axis='z')                           # fuchi
    k.lathe([(.019, .042), (.019, .046)], 'gold', n=10, axis='z')                           # seppa
    # tsuba with cut-outs
    k.lathe([(.04, .046), (.04, .054)], 'gun_slate', n=12, axis='z')
    for a in range(4):
        r = math.radians(45 + a * 90)
        x, y = math.cos(r) * .026, math.sin(r) * .026
        k.boxr(x - .006, y - .006, .0455, x + .006, y + .006, .0545, 'lacquer')
    k.lathe([(.019, .054), (.019, .058)], 'gold', n=10, axis='z')
    k.cbox((0, .0, .072), (.012, .036, .026), 'gold', ch=.003)                             # habaki
    # blade with hamon / shinogi faces
    L, W, T = .72, .032, .0072
    rings = []
    n = 14
    for i in range(n + 1):
        z = .085 + L * i / n
        w = W * (1 - .25 * i / n)
        yc = curved(z)
        rings.append((z, yc, w))
    ids = []
    for z, yc, w in rings:
        prof = [(0, yc + w / 2), (T * .55, yc + w * .18), (T, yc - w * .05), (T * .7, yc - w / 2),
                (-T * .7, yc - w / 2), (-T, yc - w * .05), (-T * .55, yc + w * .18)]
        ids.append([k.vert((x, y, z)) for x, y in prof])
    cols = ['hamon', 'blade', 'blade_dark', 'blade_dark', 'blade_dark', 'blade', 'hamon']
    for a, b in zip(ids[:-1], ids[1:]):
        for j in range(7):
            jj = (j + 1) % 7
            k.face([a[j], a[jj], b[jj], b[j]], cols[j])
    k.face(list(reversed(ids[0])), 'blade_dark')
    z, yc, w = rings[-1]
    tip = k.vert((0, yc - w * .3, z + .06))
    for j in range(7):
        k.face([ids[-1][j], ids[-1][(j + 1) % 7], tip], cols[j])
    k.pop()
    return k


def saya():
    """Scabbard (separate mesh in the same blade frame, so a sheathed katana lines up with it)."""
    k = K()
    tilt(k)
    L = .74
    rings = []
    for i in range(9):
        z = .06 + (L + .02) * i / 8
        rings.append((z, curved(z)))
    for (z0, y0), (z1, y1) in zip(rings[:-1], rings[1:]):
        k.push((0, (y0 + y1) / 2, (z0 + z1) / 2), (math.degrees(math.atan2(y1 - y0, z1 - z0)) * -1, 0, 0))
        k.cbox((0, 0, 0), (.022, .042, (z1 - z0) + .004), 'lacquer', ch=.006)
        k.pop()
    k.cbox((0, curved(.07), .07), (.026, .046, .03), 'samegawa', ch=.004)                   # koiguchi
    zt = .06 + L + .02
    k.cbox((0, curved(zt), zt), (.026, .046, .03), 'gun_slate', ch=.006)                    # kojiri
    k.cbox((.0, curved(.15) - .024, .15), (.012, .012, .03), 'samegawa', ch=.003)           # kurikata
    for i in range(5):                                                                     # sageo cord
        z = .13 + i * .022
        k.cbox((0, curved(z), z), (.026, .048, .01), 'sageo', ch=.003)
    k.beam((0, curved(.15) - .03, .15), (.0, -.06, .02), .01, .006, 'sageo')
    k.pop()
    return k


def longsword():
    k = K()
    tilt(k)
    # grip (hand-and-a-half) + pommel
    k.lathe([(.015, -.2)] + [((.017 if i % 2 else .015), -.19 + i * .02) for i in range(11)] + [(.016, .02)], 'leather', n=8,
            axis='z', cols=['leather'] + [('leather_dark' if i % 2 else 'leather') for i in range(12)])
    k.push((0, 0, -.225))
    k.lathe([(.0, -.024), (.022, -.016), (.028, .0), (.022, .016), (.0, .024)], 'iron', n=10, axis='x')
    k.pop()
    k.cyl((.022, 0, -.225), (.03, 0, -.225), .009, 'brass', n=8)
    k.cyl((-.022, 0, -.225), (-.03, 0, -.225), .009, 'brass', n=8)
    # crossguard with flared, down-turned quillons
    k.cbox((0, 0, .035), (.026, .2, .026), 'iron', ch=.006)
    for s in (1, -1):
        k.push((0, s * .1, .03), (s * 25, 0, 0))
        k.cbox((0, s * .02, -.0), (.024, .05, .022), 'iron', ch=.006)
        k.pop()
        k.cbox((0, s * .128, .012), (.03, .022, .03), 'iron', ch=.007)
    k.cbox((0, 0, .055), (.014, .05, .02), 'iron', ch=.004)
    # blade: diamond section, fuller, tapering to a point
    L, W, T = .86, .05, .0085
    n = 12
    ids = []
    for i in range(n + 1):
        z = .065 + L * i / n
        w = W * (1 - .62 * i / n)
        f = .3 if i < n * .65 else 0.0
        prof = [(0, w / 2), (T * .3, w * .25), (T * .5 - (.002 if f else 0), 0), (T * .3, -w * .25), (0, -w / 2),
                (-T * .3, -w * .25), (-T * .5 + (.002 if f else 0), 0), (-T * .3, w * .25)]
        ids.append([k.vert((x, y, z)) for x, y in prof])
    cols = ['hamon', 'blade', 'blade_dark', 'blade', 'hamon', 'blade', 'blade_dark', 'blade']
    for i, (a, b) in enumerate(zip(ids[:-1], ids[1:])):
        for j in range(8):
            c = cols[j]
            if i < n * .62 and j in (1, 2, 5, 6):
                c = 'gun_slate' if j in (2, 6) else 'blade_dark'                  # fuller groove
            k.face([a[j], a[(j + 1) % 8], b[(j + 1) % 8], b[j]], c)
    k.face(list(reversed(ids[0])), 'blade')
    tip = k.vert((0, 0, .065 + L + .07))
    for j in range(8):
        k.face([ids[-1][j], ids[-1][(j + 1) % 8], tip], cols[j])
    k.pop()
    return k


def scabbard():
    k = K()
    tilt(k)
    k.cbox((0, 0, .5), (.03, .066, .86), 'leather', ch=.008)
    k.cbox((0, 0, .1), (.036, .072, .08), 'brass', ch=.006)
    k.pyramid([Vector((-.018, -.036, .93)), Vector((.018, -.036, .93)), Vector((.018, .036, .93)), Vector((-.018, .036, .93))],
              Vector((0, 0, .99)), 'brass', ())
    for z in (.25, .45):
        k.cbox((0, 0, z), (.034, .07, .025), 'leather_dark', ch=.004)
    k.pop()
    return k


# ================================================================ funny melee
def trout():
    """Big floppy trout, held by the tail (a homage to How to Fish)."""
    k = K()
    tilt(k)
    k.lathe([(.012, -.06), (.016, .04)], 'fish_patch', n=6, axis='z')                       # tail wrist (grip)
    k.prism_x([(.0, .02), (.06, -.07), (.0, -.045), (-.06, -.07)], -.005, .005, 'fish_top')  # tail fin
    sec = [(.04, .018, .012), (.12, .045, .03), (.22, .07, .045), (.32, .078, .05), (.42, .068, .046), (.5, .045, .034), (.55, .02, .015)]
    ids = []
    for z, h, w in sec:
        ring = [(0, h), (w * .8, h * .6), (w, 0), (w * .8, -h * .6), (0, -h), (-w * .8, -h * .6), (-w, 0), (-w * .8, h * .6)]
        ids.append([k.vert((x, y, z)) for x, y in ring])
    for i, (a, b) in enumerate(zip(ids[:-1], ids[1:])):
        for j in range(8):
            c = 'fish_belly' if j in (3, 4) else ('fish_patch' if (i + j) % 3 == 0 else 'fish_top')
            if i == 4 and j in (1, 2, 5, 6, 7, 0):
                c = 'gill' if j in (2, 5) else c
            k.face([a[j], a[(j + 1) % 8], b[(j + 1) % 8], b[j]], c)
    nose = k.vert((0, .0, .58))
    for j in range(8):
        k.face([ids[-1][j], ids[-1][(j + 1) % 8], nose], 'fish_top' if j not in (3, 4) else 'fish_belly')
    k.face(list(reversed(ids[0])), 'fish_patch')
    for s in (1, -1):
        k.cyl((s * .036, .022, .49), (s * .041, .022, .49), .008, 'paint_black', n=6)        # eyes
        k.push((s * .045, -.03, .3), (0, s * 35, 0))
        k.prism_x([(-.0, -.02), (-.04, .04), (.0, .05)], -.003, .003, 'fish_patch')        # pectoral fins
        k.pop()
    k.prism_x([(.06, .18), (.105, .25), (.07, .32)], -.003, .003, 'fish_patch')             # dorsal fin
    k.boxr(-.012, -.014, .565, .012, -.006, .574, 'gill')                                     # mouth
    k.pop()
    return k


def baguette():
    k = K()
    tilt(k)
    k.lathe([(.0, -.12), (.022, -.11), (.03, -.06), (.032, .3), (.03, .5), (.02, .56), (.0, .58)], 'bread', n=8, axis='z',
            cols=['bread_dark', 'bread', 'bread', 'bread', 'bread', 'bread_dark'])
    for i in range(6):                                                                       # scored cuts
        z = -.02 + i * .095
        k.push((0, .0265, z + .03), (0, 35, 0))
        k.cbox((0, 0, 0), (.02, .005, .06), 'bread_cut', ch=.002)
        k.pop()
    k.pop()
    return k


def rubber_chicken():
    k = K()
    tilt(k)
    rnd = random.Random(4)
    for s in (1, -1):                                                                        # legs (grip)
        k.cyl((s * .008, 0, -.08), (s * .012, 0, .08), .008, 'beak', n=5)
        for a in (-30, 0, 30):
            r = math.radians(a)
            k.cyl((s * .008, 0, -.08), (s * .008 + math.sin(r) * .03, -.02, -.1 - math.cos(r) * .01), .004, 'beak', n=4)
    k.blob((0, 0, .17), (.05, .045, .1), 'rubber_yellow', rnd, n=8, rings=3)
    k.blob((0, 0, .33), (.018, .018, .08), 'rubber_yellow', rnd, n=6, rings=2)               # long neck
    k.blob((0, .01, .42), (.032, .035, .035), 'rubber_yellow', rnd, n=7, rings=2)            # head
    k.pyramid([Vector((-.012, .035, .425)), Vector((.012, .035, .425)), Vector((0, .035, .41))], Vector((0, .075, .418)), 'beak', ())
    for i in range(3):
        k.blob((0, -.005 + i * .015, .46 + (i % 2) * .008), (.006, .008, .014), 'comb', rnd, n=5, rings=1)
    k.blob((0, .04, .395), (.006, .006, .014), 'comb', rnd, n=5, rings=1)
    for s in (1, -1):
        k.cyl((s * .03, .022, .432), (s * .034, .022, .432), .006, 'paint_black', n=5)
        k.prism_x([(.0, .12), (.02, .2), (-.03, .24), (-.04, .15)], s * .045, s * .052, 'rubber_yellow')   # wings
    return k


# ================================================================ registry
def _p(fn):
    return lambda: fn()


ASSETS = {
    'SM_Wep_AssaultRifle': lambda: {None: (ar_body(), (0, 0, 0)), 'SM_Wep_AssaultRifle_Mag': (_at(ar_mag(), (0, .075, -.02)), (0, .075, -.02)),
                                    'SM_Wep_AssaultRifle_Charging': (_at(ar_charging(), (0, -.075, .086)), (0, -.075, .086))},
    'SM_Wep_PumpShotgun': lambda: {None: (sg_body(), (0, 0, 0)), 'SM_Wep_PumpShotgun_Pump': (_at(sg_pump(), (0, .25, .032)), (0, .25, .032))},
    'SM_Wep_SniperRifle': lambda: {None: (sn_body(), (0, 0, 0)), 'SM_Wep_SniperRifle_Bolt': (_at(sn_bolt(), (0, -.04, .07)), (0, -.04, .07)),
                                   'SM_Wep_SniperRifle_Mag': (_at(sn_mag(), (0, .07, .005)), (0, .07, .005))},
    'SM_Wep_Revolver': lambda: {None: (rv_body(), (0, 0, 0)), 'SM_Wep_Revolver_Cylinder': (_at(rv_cylinder(), (0, .055, .046)), (0, .055, .046)),
                                'SM_Wep_Revolver_Hammer': (_at(rv_hammer(), (0, -.035, .07)), (0, -.035, .07))},
    'SM_Wep_Pistol': lambda: {None: (ps_frame(), (0, 0, 0)), 'SM_Wep_Pistol_Slide': (ps_slide(), (0, 0, 0)),
                              'SM_Wep_Pistol_Mag': (_at(ps_mag(), (0, -.005, 0)), (0, -.005, 0))},
    'SM_Wep_SMG': lambda: {None: (smg_body(), (0, 0, 0)), 'SM_Wep_SMG_Mag': (_at(smg_mag(), (0, .0, -.0)), (0, .0, -.0)),
                           'SM_Wep_SMG_Knob': (_at(smg_knob(), (0, .12, .072)), (0, .12, .072))},
    'SM_Wep_Katana': katana,
    'SM_Wep_Katana_Saya': saya,
    'SM_Wep_Longsword': longsword,
    'SM_Wep_Longsword_Scabbard': scabbard,
    'SM_Wep_Fun_Trout': trout,
    'SM_Wep_Fun_Baguette': baguette,
    'SM_Wep_Fun_RubberChicken': rubber_chicken,
}


def _at(k, off):
    """Shift a part built around its own origin to its place in the gun frame."""
    o = Vector(off)
    k.v = [v + o for v in k.v]
    return k


# ---------------------------------------------------------------- part animations (frame, loc offset, rot deg[, scale])
H = 0.001  # hidden scale
PART_ANIMS = {
    'SM_Wep_AssaultRifle': {
        'Wep_Reload': {'SM_Wep_AssaultRifle_Mag': [(0, (0, 0, 0), (0, 0, 0)), (11, (0, 0, 0), (0, 0, 0)), (16, (-.03, .03, -.2), (10, 0, 0)),
                                                   (17, (-.03, .03, -.2), (10, 0, 0), H), (31, (-.02, .01, -.16), (0, 0, 0), H),
                                                   (32, (-.02, .01, -.16), (0, 0, 0)), (37, (0, 0, 0), (0, 0, 0)), (50, (0, 0, 0), (0, 0, 0))],
                       'SM_Wep_AssaultRifle_Charging': [(0, (0, 0, 0), (0, 0, 0)), (41, (0, 0, 0), (0, 0, 0)), (44, (0, -.065, 0), (0, 0, 0)),
                                                        (46, (0, 0, 0), (0, 0, 0)), (50, (0, 0, 0), (0, 0, 0))]},
        'Wep_Fire': {'SM_Wep_AssaultRifle_Charging': [(0, (0, 0, 0), (0, 0, 0)), (8, (0, 0, 0), (0, 0, 0))]},
    },
    'SM_Wep_PumpShotgun': {
        'Wep_Fire': {'SM_Wep_PumpShotgun_Pump': [(0, (0, 0, 0), (0, 0, 0)), (9, (0, 0, 0), (0, 0, 0)), (13, (0, -.07, 0), (0, 0, 0)),
                                                 (16, (0, -.07, 0), (0, 0, 0)), (20, (0, 0, 0), (0, 0, 0)), (30, (0, 0, 0), (0, 0, 0))]},
    },
    'SM_Wep_SniperRifle': {
        'Wep_Fire': {'SM_Wep_SniperRifle_Bolt': [(0, (0, 0, 0), (0, 0, 0)), (12, (0, 0, 0), (0, 0, 0)), (16, (0, 0, 0), (0, -70, 0)),
                                                 (20, (0, -.09, 0), (0, -70, 0)), (24, (0, -.09, 0), (0, -70, 0)), (28, (0, 0, 0), (0, -70, 0)),
                                                 (32, (0, 0, 0), (0, 0, 0)), (40, (0, 0, 0), (0, 0, 0))]},
        'Wep_Reload': {'SM_Wep_SniperRifle_Mag': [(0, (0, 0, 0), (0, 0, 0)), (11, (0, 0, 0), (0, 0, 0)), (16, (-.02, 0, -.15), (0, 0, 0)),
                                                  (17, (-.02, 0, -.15), (0, 0, 0), H), (31, (-.02, 0, -.12), (0, 0, 0), H),
                                                  (32, (-.02, 0, -.12), (0, 0, 0)), (37, (0, 0, 0), (0, 0, 0)), (50, (0, 0, 0), (0, 0, 0))]},
    },
    'SM_Wep_Revolver': {
        'Wep_Fire': {'SM_Wep_Revolver_Hammer': [(0, (0, 0, 0), (0, 0, 0)), (1, (0, 0, 0), (-30, 0, 0)), (2, (0, 0, 0), (0, 0, 0)), (12, (0, 0, 0), (0, 0, 0))],
                     'SM_Wep_Revolver_Cylinder': [(0, (0, 0, 0), (0, 0, 0)), (1, (0, 0, 0), (0, 60, 0)), (12, (0, 0, 0), (0, 60, 0))]},
        'Wep_Reload': {'SM_Wep_Revolver_Cylinder': [(0, (0, 0, 0), (0, 0, 0)), (8, (0, 0, 0), (0, 0, 0)), (12, (-.04, 0, -.02), (0, 0, 0)),
                                                    (48, (-.04, 0, -.02), (0, 0, 0)), (53, (0, 0, 0), (0, 0, 0)), (60, (0, 0, 0), (0, 0, 0))]},
    },
    'SM_Wep_Pistol': {
        'Wep_Fire': {'SM_Wep_Pistol_Slide': [(0, (0, 0, 0), (0, 0, 0)), (1, (0, -.035, 0), (0, 0, 0)), (3, (0, 0, 0), (0, 0, 0)), (8, (0, 0, 0), (0, 0, 0))]},
        'Wep_Reload': {'SM_Wep_Pistol_Mag': [(0, (0, 0, 0), (0, 0, 0)), (6, (0, 0, 0), (0, 0, 0)), (10, (-.01, -.02, -.16), (0, 0, 0)),
                                             (11, (-.01, -.02, -.16), (0, 0, 0), H), (23, (-.01, -.02, -.12), (0, 0, 0), H),
                                             (24, (-.01, -.02, -.12), (0, 0, 0)), (30, (0, 0, 0), (0, 0, 0)), (40, (0, 0, 0), (0, 0, 0))],
                       'SM_Wep_Pistol_Slide': [(0, (0, -.035, 0), (0, 0, 0)), (32, (0, -.035, 0), (0, 0, 0)), (34, (0, 0, 0), (0, 0, 0)), (40, (0, 0, 0), (0, 0, 0))]},
    },
    'SM_Wep_SMG': {
        'Wep_Fire': {'SM_Wep_SMG_Knob': [(0, (0, 0, 0), (0, 0, 0)), (1, (0, -.06, 0), (0, 0, 0)), (3, (0, 0, 0), (0, 0, 0)), (4, (0, 0, 0), (0, 0, 0))]},
        'Wep_Reload': {'SM_Wep_SMG_Mag': [(0, (0, 0, 0), (0, 0, 0)), (6, (0, 0, 0), (0, 0, 0)), (10, (0, -.01, -.2), (0, 0, 0)),
                                          (11, (0, -.01, -.2), (0, 0, 0), H), (23, (0, -.01, -.15), (0, 0, 0), H),
                                          (24, (0, -.01, -.15), (0, 0, 0)), (30, (0, 0, 0), (0, 0, 0)), (40, (0, 0, 0), (0, 0, 0))],
                       'SM_Wep_SMG_Knob': [(0, (0, 0, 0), (0, 0, 0)), (32, (0, 0, 0), (0, 0, 0)), (34, (0, -.06, 0), (0, 0, 0)),
                                           (36, (0, 0, 0), (0, 0, 0)), (40, (0, 0, 0), (0, 0, 0))]},
    },
}
