"""Weapons v3: 17 extra weapons for the 5 shop zones, same conventions as weapons2
(gun frame: origin at the firing-hand grip, +Y muzzle, +Z top; blades: tilt() blade frame, +Z blade, +Y edge).
Long guns keep the fore-end around y .22-.38 (left hand HL_RIFLE at y ~.30); axe-class two-handers keep the
left hand 0.36 below the right one. Registers into weapons2.ASSETS / weapons2.PART_ANIMS on import."""
import math, random
from mathutils import Vector
from kit import K, worn
import weapons2 as W2
from weapons2 import slot, screws, rail, tilt, _at, H, bore

D, G, M, S = 'gun_black', 'gun_grey', 'gun_metal', 'gun_slate'


def pistol_grip(k, col=D, x=.016, back=0.0):
    # bevelled, edges polished by the hand on worn finishes; same outline (grips measured in tool_motion.HOLDS)
    k.cprism_x([(.014 + back, .012), (-.03 + back, .016), (-.066 + back, -.098), (-.022 + back, -.104)], -x, x, col,
               ch=.004, edge=worn(col))


def trigger(k, y=0.0, z=0.0):
    k.boxr(-.006, y - .005, z - .03, .006, y + .06, z - .024, D)
    k.boxr(-.006, y + .054, z - .03, .006, y + .06, z + .002, D)
    k.boxr(-.0025, y + .016, z - .024, .0025, y + .022, z - .002, 'steel')


# ================================================================ ZONE 1 - Lago Cenere
def sawn_off():
    """Doppietta a canne mozze: break-action, wooden pistol stock with tape."""
    k = K()
    k.cbox((0, .03, .045), (.05, .1, .06), 'steel', ch=.006)                          # action
    slot(k, .0251, .0, .06, .03, .06, 'gun_metal')
    k.cyl((-.02, .0, .085), (-.02, .025, .085), .006, D, n=6)                          # hammers
    k.cyl((.02, .0, .085), (.02, .025, .085), .006, D, n=6)
    k.cprism_x([(-.02, .075), (-.02, .02), (-.075, -.095), (-.03, -.11), (.0, -.01), (.0, .02)], -.019, .019, 'gun_wood',
               ch=.004, edge=worn('gun_wood'))
    for i in range(3):
        k.boxr(-.0205, -.045 - i * .012, -.06 + i * .02, .0205, -.037 - i * .012, -.045 + i * .02, 'plastic_grey')
    trigger(k, y=-.01, z=.02)
    return k


def sawn_off_barrels():
    k = K()                                                                              # pivot = hinge pin
    for x in (-.0145, .0145):
        k.cyl((x, 0, .035), (x, .34, .035), .0145, M, n=8)
        k.cyl((x, .335, .035), (x, .345, .035), .016, D, n=8, cap_col='paint_black')
    k.boxr(-.004, .0, .049, .004, .34, .053, D)                                          # rib
    k.cbox((0, .1, .01), (.038, .14, .03), 'gun_wood', ch=.006)                         # fore-end
    slot(k, .0191, .05, .15, .0, .02, 'gun_wood_dark')
    return k


def flare_gun():
    """Pistola lanciarazzi: orange plastic, fat barrel breaks open."""
    k = K()
    O = 'paint_red'
    k.cbox((0, .02, .022), (.032, .06, .03), O, ch=.006)
    pistol_grip(k, O, x=.017)
    for i in range(3):
        slot(k, .0171, -.03 - i * .01, -.018 - i * .01, -.02 - i * .022, -.008 - i * .022, 'paint_red_dark')
    k.cyl((0, -.01, .045), (0, .01, .045), .008, D, n=6)                                # hammer
    trigger(k, y=-.005, z=.0)
    return k


def flare_barrel():
    k = K()
    k.cyl((0, 0, .02), (0, .17, .02), .022, 'paint_red', n=10)
    k.cyl((0, .165, .02), (0, .175, .02), .025, 'hazard_yellow', n=10, cap_col='paint_black')
    k.cbox((0, .01, .0), (.02, .03, .016), 'paint_red_dark', ch=.003)
    return k


def machete():
    k = K()
    tilt(k)
    k.lathe([(.0, -.075), (.016, -.07), (.018, -.04), (.015, .0), (.018, .05), (.016, .075), (.0, .08)], 'gun_black', n=8, axis='z')
    for z in (-.05, -.02, .01, .04):
        k.lathe([(.0185, z), (.0185, z + .008)], 'gun_dark', n=8, axis='z', cap0=False, cap1=False)
    k.cbox((0, .0, .085), (.012, .05, .012), 'iron_dark', ch=.002)
    blade = [(-.014, .09), (.022, .09), (.036, .3), (.05, .44), (.046, .52), (.022, .58), (-.004, .57), (-.016, .46), (-.016, .09)]
    k.prism_x(blade, -.0035, .0035, 'blade_dark')
    k.prism_x([(.022, .09), (.03, .09), (.044, .3), (.058, .44), (.054, .52), (.026, .585), (.022, .58), (.046, .52),
               (.05, .44), (.036, .3)], -.0015, .0015, 'blade')
    rnd = random.Random(5)
    for i in range(4):
        z = .15 + rnd.random() * .35
        k.boxr(-.0038, -.01, z, .0038, .012, z + .02, 'rust')
    k.pop()
    return k


def crowbar():
    """Piede di porco: red paint chipped off the ends."""
    k = K()
    tilt(k)
    k.cyl((0, 0, -.1), (0, 0, .5), .011, 'paint_red', n=6)
    k.cyl((0, 0, -.13), (0, 0, -.1), .011, 'iron', n=6, r1=.011)
    k.beam((0, 0, -.13), (0, .02, -.17), .02, .008, 'iron')                                # chisel
    pts = [(0, .5), (.0, .53), (-.02, .57), (-.05, .585), (-.08, .575), (-.095, .55)]   # gooseneck towards -Y
    for (y0, z0), (y1, z1) in zip(pts[:-1], pts[1:]):
        k.beam((0, y0, z0), (0, y1, z1), .022, .022, 'paint_red' if z0 < .56 else 'iron')
    k.beam((0, -.095, .55), (0, -.09, .535), .03, .008, 'iron')
    k.prism_x([(-.1, .54), (-.085, .53), (-.088, .55)], -.003, .003, 'gun_black')         # claw notch
    for z in (-.05, .0):
        k.lathe([(.0125, z), (.0125, z + .03)], 'plastic_grey', n=6, axis='z', cap0=False, cap1=False)   # grip tape
    k.pop()
    return k


def nail_bat():
    k = K()
    tilt(k)
    k.lathe([(.0, -.09), (.024, -.088), (.02, -.08), (.017, .0), (.021, .2), (.03, .4), (.036, .56), (.032, .62), (.0, .625)],
            'wood_light', n=8, axis='z', cols=['wood', 'wood_light', 'wood_light', 'wood_light', 'wood_light', 'wood_light', 'wood_light', 'wood_raw'])
    for z in (-.07, -.045, -.02, .005, .03):
        k.lathe([(.0185, z), (.0185, z + .02)], 'plastic_grey', n=8, axis='z', cap0=False, cap1=False)
    rnd = random.Random(11)
    for i in range(16):
        z = .38 + rnd.random() * .22
        a = rnd.random() * math.tau
        r = .03 + (z - .38) * .025
        p = Vector((math.cos(a) * r, math.sin(a) * r, z))
        d = Vector((math.cos(a), math.sin(a), rnd.uniform(-.3, .3))).normalized()
        k.cyl(p, p + d * .045, .0028, 'steel', n=4)
    k.lathe([(.036, .48), (.037, .5)], 'blood', n=8, axis='z', cap0=False, cap1=False)
    k.pop()
    return k


# ================================================================ ZONE 2 - Stazione Forestale / Cava Silente
def lever_rifle():
    """Fucile a leva: brass receiver, octagonal barrel, saddle ring."""
    k = K()
    k.cbox((0, .05, .045), (.036, .17, .07), 'brass', ch=.006)
    slot(k, .0181, .06, .12, .05, .07, D)
    k.cyl((0, .13, .068), (0, .72, .068), .012, 'gun_blued', n=8)                       # octagonal barrel
    k.cyl((0, .13, .042), (0, .6, .042), .009, 'gun_blued', n=8)                         # mag tube
    k.cbox((0, .3, .035), (.034, .2, .04), 'gun_wood', ch=.008)                          # fore-end
    k.cyl((0, .6, .042), (0, .62, .068), .012, 'gun_blued', n=6)
    k.cbox((0, .7, .086), (.006, .012, .012), 'brass', ch=.002)                          # front bead
    k.cbox((0, .2, .085), (.02, .01, .014), D, ch=.002)                                  # buckhorn sight
    k.cprism_x([(-.035, .075), (-.035, .015), (-.43, -.07), (-.44, -.07), (-.44, .06), (-.3, .07)], -.019, .019, 'gun_wood',
               ch=.005, edge=worn('gun_wood'))
    bore(k, .72, .068, .007)
    k.cbox((0, -.445, -.005), (.04, .015, .135), 'gun_wood_dark', ch=.004)
    k.cyl((.021, .02, .03), (.028, .02, .03), .012, 'steel', n=8, cap=False)            # saddle ring
    k.cyl((0, -.005, .088), (0, .015, .088), .006, D, n=6)                              # hammer
    return k


def lever_rifle_lever():
    k = K()                                                                              # pivot under the receiver
    k.beam((0, 0, 0), (0, -.02, -.025), .008, .008, 'gun_blued')
    k.beam((0, -.02, -.025), (0, -.1, -.03), .008, .008, 'gun_blued')
    k.beam((0, -.1, -.03), (0, -.11, -.09), .008, .008, 'gun_blued')
    k.beam((0, -.11, -.09), (0, -.04, -.08), .008, .008, 'gun_blued')
    k.beam((0, -.04, -.08), (0, -.02, -.025), .008, .008, 'gun_blued')
    return k


def crossbow():
    """Balestra: tan polymer stock, recurve prod, scope rail."""
    k = K()
    T = 'polymer_tan'
    k.cbox((0, .12, .045), (.04, .34, .05), T, ch=.008)
    k.boxr(-.006, -.04, .07, .006, .5, .078, 'gun_metal')                               # flight rail
    k.cbox((0, .3, .02), (.036, .16, .04), D, ch=.008)                                   # fore-grip
    for i in range(4):
        slot(k, .0181, .25 + i * .03, .26 + i * .03, .005, .035, S)
    pistol_grip(k, T)
    k.cprism_x([(-.04, .065), (-.04, .02), (-.36, -.04), (-.38, -.04), (-.38, .06), (-.25, .07)], -.016, .016, T, ch=.004)
    k.prism_x([(-.2, .03), (-.3, -.01), (-.3, .045)], -.0165, .0165, 'gun_black')        # stock cut-out
    k.cbox((0, -.385, .01), (.036, .014, .11), D, ch=.004)
    trigger(k)
    k.cbox((0, .5, .055), (.06, .05, .05), D, ch=.008)                                    # riser
    k.cyl((0, .53, .0), (0, .53, .055), .006, 'steel', n=6)                              # foot stirrup
    k.beam((-.05, .54, -.03), (.05, .54, -.03), .01, .008, 'steel')
    tips = []
    for s in (1, -1):
        pts = [(s * .03, .5), (s * .14, .47), (s * .25, .42), (s * .3, .44)]
        for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
            k.beam((x0, y0, .065), (x1, y1, .065), .026, .012, 'gun_black')
        k.cbox((s * .3, .44, .065), (.02, .02, .02), 'military_dark', ch=.004)
        tips.append((s * .3, .44, .065))
    for t in tips:
        k.beam(t, (0, .1, .078), .003, .003, 'rope')                                     # string (cocked)
    k.cbox((0, .17, .121), (.02, .06, .03), D, ch=.004)                                   # riser, behind the fletching
    k.cbox((0, .17, .15), (.026, .14, .03), D, ch=.006)                                   # red dot, clear of the bolt
    k.cyl((0, .245, .15), (0, .25, .15), .011, 'emit_red', n=8)
    return k


def crossbow_bolt():
    k = K()
    k.cyl((0, 0, 0), (0, .38, 0), .004, 'alu', n=6)
    k.cyl((0, .38, 0), (0, .42, 0), .006, 'steel', n=4, r1=.0005)
    for a in (0, 120, 240):
        r = math.radians(a)
        k.push((0, .02, 0), (0, a, 0))
        k.prism([(0, .0), (.018, .0), (.0, .05)], -.0006, .0006, 'paint_yellow' if a else 'paint_red')
        k.pop()
    return k


def pickaxe():
    k = K()
    tilt(k)
    k.lathe([(.0, -.56), (.02, -.555), (.021, -.52), (.016, -.45), (.015, .0), (.018, .25), (.02, .3), (.0, .305)], 'wood_raw', n=8, axis='z')
    for i in range(4):
        z = -.5 + i * .03
        k.lathe([(.0215, z), (.0215, z + .016)], 'leather_dark', n=8, axis='z', cap0=False, cap1=False)
    k.cbox((0, 0, .26), (.05, .07, .07), 'iron_dark', ch=.01)
    for s in (1, -1):                                                                     # curved double pick
        pts = [(s * .03, .275), (s * .14, .255), (s * .24, .215), (s * .3, .17)]
        w = [.04, .034, .022, .008]
        for i, ((y0, z0), (y1, z1)) in enumerate(zip(pts[:-1], pts[1:])):
            k.beam((0, y0, z0), (0, y1, z1), w[i], w[i] * 1.1, 'iron' if i < 2 else 'steel')
    k.lathe([(.025, .22), (.025, .3)], 'rust', n=8, axis='z', cap0=False, cap1=False)
    k.pop()
    return k


def sledgehammer():
    k = K()
    tilt(k)
    k.lathe([(.0, -.58), (.022, -.575), (.023, -.54), (.018, -.45), (.017, .0), (.02, .27), (.0, .28)], 'hazard_yellow', n=8, axis='z')
    for i in range(6):
        z = -.56 + i * .025
        k.lathe([(.0235, z), (.0235, z + .014)], 'gun_black', n=8, axis='z', cap0=False, cap1=False)
    k.cbox((0, 0, .3), (.085, .2, .085), 'iron_dark', ch=.012)                          # head
    for s in (1, -1):
        k.cbox((0, s * .103, .3), (.075, .01, .075), 'steel', ch=.008)                   # struck faces
    k.lathe([(.024, .25), (.03, .258)], 'iron', n=8, axis='z', cap0=False)
    k.pop()
    return k


# ================================================================ ZONE 3 - Borgo del Ripetitore
def frying_pan():
    """Padella della nonna, with a fried egg welded on by sheer heat."""
    k = K()
    tilt(k)
    k.lathe([(.0, -.08), (.016, -.075), (.015, .0), (.012, .12), (.0, .125)], 'gun_black', n=6, axis='z')
    k.cyl((0, -.006, .12), (0, -.006, .15), .01, 'iron_dark', n=6)
    k.cyl((0, -.022, .275), (0, .012, .275), .135, 'iron_dark', n=14, cap_col='iron')   # pan (flat face = +Y)
    k.cyl((0, .012, .275), (0, .016, .275), .12, 'iron', n=14)
    rnd = random.Random(4)
    k.blob((.01, .02, .27), (.06, .006, .05), 'paint_white', rnd, n=7, rings=1)          # egg white
    k.cyl((.015, .018, .28), (.015, .03, .28), .02, 'paint_yellow', n=8)                 # yolk
    k.pop()
    return k


def electric_guitar():
    """L'Assolo Finale: held by the neck like an axe. Body = the business end."""
    k = K()
    tilt(k)
    k.boxr(-.012, -.025, -.56, .012, .025, .2, 'mahogany')                              # neck
    k.boxr(-.0125, -.022, -.5, .0125, .022, .2, 'gun_black')                            # fretboard (X face)
    for i in range(10):
        z = -.48 + i * .065
        k.boxr(-.0128, -.022, z, .0128, .022, z + .004, 'steel')
    k.boxr(-.016, -.04, -.66, .016, .04, -.56, 'paint_red')                             # headstock
    for i in range(3):
        for s in (1, -1):
            k.cyl((s * .016, -.03 + i * .03, -.6 - i * .02), (s * .026, -.03 + i * .03, -.6 - i * .02), .006, 'steel', n=6)
    body = [(-.14, .18), (-.1, .14), (-.05, .19), (.0, .17), (.05, .19), (.13, .15), (.18, .22), (.16, .33),
            (.09, .38), (.12, .46), (.07, .52), (-.02, .5), (-.12, .43), (-.16, .32)]
    k.push((0, 0, 0), (0, 0, 90))                                                         # body plane = YZ (thin in X)
    k.prism([(x, z) for x, z in body], -.022, .022, 'paint_red', side_col='paint_white')
    k.pop()
    k.prism_x([(-.06, .22), (.06, .21), (.08, .34), (-.02, .4), (-.09, .33)], .0225, .0245, 'paint_white')   # pickguard
    for z in (.27, .34):
        k.boxr(.024, -.035, z, .029, .035, z + .025, 'gun_black')                       # pickups
    k.prism_x([(-.1, .43), (-.05, .4), (-.07, .38), (-.02, .33), (-.06, .34), (-.04, .3)], -.0245, -.0225, 'hazard_yellow')  # bolt sticker
    for i in range(4):
        y = -.009 + i * .006
        k.beam((.0135, y, -.56), (.0255, y, .44), .0012, .0012, 'steel')                  # strings
    k.pop()
    return k


def nailgun():
    """Sparachiodi: hardware-store yellow, nail strip magazine."""
    k = K()
    Y = 'hazard_yellow'
    k.cbox((0, .06, .05), (.05, .17, .07), Y, ch=.01, edge='gun_black_worn')
    k.cbox((0, .17, .02), (.03, .05, .1), D, ch=.006)                                    # nose
    k.cyl((0, .19, -.02), (0, .21, -.02), .012, 'steel', n=6)
    pistol_grip(k, D, x=.018, back=-.01)
    k.cbox((0, -.04, .05), (.054, .07, .06), D, ch=.008)                                 # motor housing
    for i in range(4):
        slot(k, .0271, -.065 + i * .015, -.058 + i * .015, .03, .07, 'gun_slate')
    k.cyl((0, -.08, .05), (0, -.1, .05), .02, 'emit_green', n=8, cap_col='gun_dark')    # battery LED
    trigger(k, y=-.015, z=.012)
    return k


def nailgun_mag():
    k = K()                                                                              # pivot at the nose base
    k.push((0, 0, 0), (35, 0, 0))
    k.boxr(-.012, -.2, -.02, .012, .0, .01, 'gun_dark')
    for i in range(9):
        y = -.19 + i * .021
        k.cyl((0, y, .01), (0, y, .024), .0025, 'steel', n=4)
    k.pop()
    return k


# ================================================================ ZONE 4 - Deposito Militare / Diga Nord
def lmg():
    """Mitragliatrice leggera: box mag, carry handle, folded bipod."""
    k = K()
    k.cbox((0, .08, .05), (.05, .3, .08), D, ch=.008, edge=worn(D))
    slot(k, .0251, .02, .16, .03, .07, S)
    # front sight tower: tall enough to meet the notch on the carry handle over the handle posts
    k.prism_x([(.715, .074), (.775, .074), (.757, .142), (.743, .142)], -.006, .006, D)
    k.cbox((0, .75, .147), (.004, .006, .012), D, ch=.0012)                              # front post, top z .153
    k.prism([(-.008, .144), (.008, .144), (.008, .157), (.003, .157), (.0, .151), (-.003, .157), (-.008, .157)],
            .15, .16, D)                                                               # rear notch on the handle
    rail(k, -.06, .1, .09, w=.022, col=D)
    k.cyl((0, .23, .06), (0, .8, .06), .015, M, n=8)
    for i in range(8):
        y = .26 + i * .05
        k.cyl((0, y, .06), (0, y + .025, .06), .02, D, n=8)
    k.cyl((0, .8, .06), (0, .85, .06), .02, D, n=6, cap_col='paint_black')              # flash hider
    k.cbox((0, .32, .03), (.046, .18, .05), 'military_dark', ch=.008)                    # handguard
    k.beam((0, .1, .14), (0, .22, .14), .012, .01, D)                                    # carry handle
    for y in (.1, .22):
        k.beam((0, y, .09), (0, y, .14), .012, .01, D)
    for s in (1, -1):                                                                    # bipod folded
        k.beam((s * .012, .62, .04), (s * .016, .38, .02), .008, .008, 'gun_dark')
    k.cyl((0, .64, .04), (0, .66, .04), .02, 'gun_dark', n=8)
    pistol_grip(k, D)
    k.cprism_x([(-.07, .085), (-.07, .02), (-.38, -.03), (-.39, -.03), (-.39, .085)], -.022, .022, D, ch=.005)
    k.cbox((0, -.395, .025), (.044, .014, .12), 'gun_slate', ch=.004)
    trigger(k)
    return k


def lmg_mag():
    k = K()
    k.cbox((-.03, 0, -.06), (.06, .11, .12), 'military', ch=.01)
    k.cbox((-.03, 0, -.06), (.062, .02, .08), 'military_dark', ch=.004)
    k.cyl((-.064, -.03, -.04), (-.064, .03, -.04), .006, 'gun_black', n=6)
    for i in range(4):
        k.cyl((-.005, -.03 + i * .02, .0), (.005, -.03 + i * .02, .0), .005, 'ammo_brass', n=6)
    return k


def lmg_cover():
    k = K()                                                                              # hinge at the rear of the feed cover
    k.cbox((0, .07, .012), (.052, .14, .024), D, ch=.005)
    k.boxr(-.004, .12, .024, .004, .14, .034, 'steel')
    return k


def combat_knife():
    k = K()
    tilt(k)
    k.lathe([(.0, -.06), (.017, -.055), (.014, -.02), (.016, .02), (.014, .06), (.0, .065)], 'gun_black', n=8, axis='z')
    for z in (-.04, -.02, .0, .02, .04):
        k.lathe([(.0165, z), (.0165, z + .006)], 'gun_dark', n=8, axis='z', cap0=False, cap1=False)
    k.cbox((0, .0, .068), (.014, .07, .01), 'steel', ch=.002)
    k.prism_x([(-.012, .075), (.016, .075), (.018, .2), (.004, .27), (-.006, .23), (-.012, .2)], -.003, .003, 'blade_dark')
    k.prism_x([(.016, .075), (.021, .075), (.023, .2), (.004, .275), (.004, .27), (.018, .2)], -.0013, .0013, 'blade')
    for i in range(5):                                                                    # spine serrations
        z = .09 + i * .018
        k.prism_x([(-.012, z), (-.018, z + .006), (-.012, z + .012)], -.0025, .0025, 'blade_dark')
    k.pop()
    return k


def grenade_launcher():
    """Lanciagranate a tamburo (6 colpi)."""
    k = K()
    k.cbox((0, .05, .05), (.05, .09, .08), D, ch=.008, edge=worn(D))
    k.cyl((0, .15, .05), (0, .5, .05), .03, 'military_dark', n=10)                     # tube
    k.cyl((0, .5, .05), (0, .52, .05), .034, D, n=10, cap_col='paint_black')
    k.beam((0, .02, .095), (0, .27, .095), .01, .01, D)                                 # top strap
    k.cbox((0, .4, .115), (.012, .03, .06), D, ch=.003)                                   # ladder sight, above the cylinder
    k.prism([(-.008, .099), (.008, .099), (.008, .145), (.003, .145), (.0, .138), (-.003, .145), (-.008, .145)],
            .04, .05, D)                                                               # rear notch on the top strap
    k.cbox((0, .32, .0), (.034, .08, .04), D, ch=.006)                                   # fore-grip
    k.cprism_x([(.0, .0), (-.02, .0), (-.03, -.1), (.0, -.105)], -.015, .015, D, ch=.004, edge=worn(D))
    pistol_grip(k, D)
    k.beam((0, -.02, .08), (0, -.32, .03), .012, .012, 'gun_dark')                      # folding wire stock
    k.beam((0, -.02, .0), (0, -.32, .0), .012, .012, 'gun_dark')
    k.cbox((0, -.33, .015), (.04, .02, .1), 'gun_black', ch=.004)
    trigger(k, y=-.005)
    return k


def gl_cylinder():
    k = K()
    k.cyl((0, -.06, 0), (0, .06, 0), .07, 'gun_metal', n=12)
    for i in range(6):
        a = math.radians(i * 60 + 30)
        x, z = math.cos(a) * .045, math.sin(a) * .045
        k.cyl((x, .06, z), (x, .062, z), .017, 'ammo_brass', n=8, cap_col='military_light')
        k.boxr(math.cos(a) * .072 - .004, -.04, math.sin(a) * .072 - .004, math.cos(a) * .072 + .004, .04, math.sin(a) * .072 + .004, D)
    return k


# ================================================================ ZONE 5 - Centro di Ricerca / Ultima Frequenza
def tesla_rifle():
    """Fucile Tesla prototipo: lab white shell, glowing coils, battery cell."""
    k = K()
    Wt = 'lab_white'
    k.cbox((0, .06, .05), (.06, .24, .09), Wt, ch=.012)
    slot(k, .0301, .0, .16, .03, .06, 'alu_dark')
    k.cyl((0, .18, .055), (0, .42, .055), .018, 'alu', n=8)
    for i in range(5):
        y = .21 + i * .04
        k.lathe([(.026, y), (.026, y + .02)], 'copper', n=8, axis='y', cap0=False, cap1=False)
    k.cbox((0, .3, .01), (.04, .14, .03), 'gun_black', ch=.006)                          # fore-grip
    k.cyl((-.04, -.03, .06), (-.04, .1, .06), .018, 'alu_dark', n=8)                   # battery cell
    k.cyl((-.04, .0, .06), (-.04, .07, .06), .0185, 'emit_green', n=8, cap=False)
    pistol_grip(k, 'gun_black')
    k.cprism_x([(-.06, .09), (-.06, .02), (-.34, -.02), (-.35, -.02), (-.35, .08), (-.22, .095)], -.02, .02, Wt, ch=.005)
    k.prism_x([(-.16, .05), (-.26, .02), (-.26, .07)], -.0205, .0205, 'gun_black')
    trigger(k)
    k.cbox((0, .08, .11), (.03, .1, .03), 'gun_black', ch=.006)
    k.cyl((0, .135, .11), (0, .14, .11), .01, 'emit_blue', n=8)
    k.cbox((.031, .05, .06), (.002, .04, .015), 'hazard_yellow', ch=.001)
    return k


def tesla_coil():
    k = K()                                                                              # spins around +Y
    k.cyl((0, -.01, 0), (0, .09, 0), .012, 'alu_dark', n=8)
    for i in range(3):
        a = math.radians(i * 120)
        p = Vector((math.cos(a) * .034, .04, math.sin(a) * .034))
        k.cyl(p - Vector((0, .04, 0)), p + Vector((0, .04, 0)), .007, 'emit_blue', n=6)
    k.lathe([(.042, .085), (.042, .095)], 'copper', n=10, axis='y')
    k.cyl((0, .095, 0), (0, .12, 0), .02, 'emit_blue', n=8, r1=.003)
    return k


def leaf_blower():
    """Soffiatore Spazzazombie: two-stroke engine, a very long tube and no regrets."""
    k = K()
    O, Y = 'paint_red', 'hazard_yellow'
    k.cbox((0, -.02, .06), (.12, .14, .12), O, ch=.016)                                   # engine shroud
    k.cbox((-.065, -.02, .06), (.02, .1, .09), 'gun_black', ch=.006)
    for i in range(4):
        slot(k, .0601, -.07 + i * .025, -.06 + i * .025, .02, .1, 'gun_dark')
    k.cbox((0, -.01, .135), (.05, .08, .03), 'gun_black', ch=.006)                       # fuel cap + pull cord
    k.cyl((.0, .02, .15), (.0, .02, .16), .012, Y, n=8)
    k.beam((.06, -.04, .1), (.09, -.08, .14), .006, .006, 'rope')
    k.cbox((.09, -.08, .14), (.03, .012, .012), 'gun_black', ch=.003)
    k.cyl((0, .06, .05), (0, .78, .06), .035, Y, n=10)                                    # tube
    k.cyl((0, .78, .06), (0, .84, .06), .035, Y, n=10, r1=.045, cap_col='gun_black')
    for y in (.25, .5):
        k.lathe([(.037, y), (.037, y + .02)], 'gun_black', n=10, axis='y', cap0=False, cap1=False)
    k.cbox((0, .32, .012), (.03, .06, .03), 'gun_black', ch=.006)                        # support handle
    pistol_grip(k, 'gun_black')
    trigger(k)
    k.cbox((.061, -.02, .06), (.002, .06, .03), 'paint_white', ch=.001)                  # sticker
    return k


def blower_fan():
    k = K()                                                                              # intake fan, spins around +Y
    k.cyl((0, -.006, 0), (0, .006, 0), .012, 'gun_dark', n=8)
    for i in range(6):
        k.push((0, 0, 0), (0, i * 60, 0))
        k.beam((0, 0, .012), (0, 0, .05), .016, .004, 'steel')
        k.pop()
    return k


# ================================================================ registry
NEW = {
    'SM_Wep_SawnOff': lambda: {None: (sawn_off(), (0, 0, 0)), 'SM_Wep_SawnOff_Barrels': (_at(sawn_off_barrels(), (0, .075, .03)), (0, .075, .03))},
    'SM_Wep_FlareGun': lambda: {None: (flare_gun(), (0, 0, 0)), 'SM_Wep_FlareGun_Barrel': (_at(flare_barrel(), (0, .045, .02)), (0, .045, .02))},
    'SM_Wep_Machete': machete,
    'SM_Wep_Crowbar': crowbar,
    'SM_Wep_NailBat': nail_bat,
    'SM_Wep_LeverRifle': lambda: {None: (lever_rifle(), (0, 0, 0)), 'SM_Wep_LeverRifle_Lever': (_at(lever_rifle_lever(), (0, .06, .01)), (0, .06, .01))},
    'SM_Wep_Crossbow': lambda: {None: (crossbow(), (0, 0, 0)), 'SM_Wep_Crossbow_Bolt': (_at(crossbow_bolt(), (0, .1, .082)), (0, .1, .082))},
    'SM_Wep_Pickaxe': pickaxe,
    'SM_Wep_Sledgehammer': sledgehammer,
    'SM_Wep_Fun_FryingPan': frying_pan,
    'SM_Wep_Fun_Guitar': electric_guitar,
    'SM_Wep_Nailgun': lambda: {None: (nailgun(), (0, 0, 0)), 'SM_Wep_Nailgun_Mag': (_at(nailgun_mag(), (0, .17, -.03)), (0, .17, -.03))},
    'SM_Wep_LMG': lambda: {None: (lmg(), (0, 0, 0)), 'SM_Wep_LMG_Mag': (_at(lmg_mag(), (0, .1, .01)), (0, .1, .01)),
                           'SM_Wep_LMG_Cover': (_at(lmg_cover(), (0, -.04, .09)), (0, -.04, .09))},
    'SM_Wep_CombatKnife': combat_knife,
    'SM_Wep_GrenadeLauncher': lambda: {None: (grenade_launcher(), (0, 0, 0)), 'SM_Wep_GrenadeLauncher_Cylinder': (_at(gl_cylinder(), (0, .16, .05)), (0, .16, .05))},
    'SM_Wep_TeslaRifle': lambda: {None: (tesla_rifle(), (0, 0, 0)), 'SM_Wep_TeslaRifle_Coil': (_at(tesla_coil(), (0, .43, .055)), (0, .43, .055))},
    'SM_Wep_Fun_LeafBlower': lambda: {None: (leaf_blower(), (0, 0, 0)), 'SM_Wep_Fun_LeafBlower_Fan': (_at(blower_fan(), (0, -.095, .06)), (0, -.095, .06))},
}

Z0 = (0, 0, 0)
NEW_ANIMS = {
    'SM_Wep_SawnOff': {'Wep_Reload': {'SM_Wep_SawnOff_Barrels': [(0, Z0, Z0), (8, Z0, Z0), (13, Z0, (-38, 0, 0)), (44, Z0, (-38, 0, 0)),
                                                                   (48, Z0, (2, 0, 0)), (50, Z0, Z0), (60, Z0, Z0)]}},
    'SM_Wep_FlareGun': {'Wep_Reload': {'SM_Wep_FlareGun_Barrel': [(0, Z0, Z0), (6, Z0, Z0), (10, Z0, (-40, 0, 0)), (30, Z0, (-40, 0, 0)),
                                                                   (34, Z0, Z0), (40, Z0, Z0)]}},
    'SM_Wep_LeverRifle': {'Wep_Fire': {'SM_Wep_LeverRifle_Lever': [(0, Z0, Z0), (10, Z0, Z0), (15, Z0, (48, 0, 0)), (18, Z0, (48, 0, 0)),
                                                                    (23, Z0, Z0), (40, Z0, Z0)]}},
    'SM_Wep_Crossbow': {'Wep_Fire': {'SM_Wep_Crossbow_Bolt': [(0, Z0, Z0), (1, (0, .3, 0), Z0, H), (30, (0, .3, 0), Z0, H)]},
                        'Wep_Reload': {'SM_Wep_Crossbow_Bolt': [(0, (0, .3, 0), Z0, H), (24, (0, .3, 0), Z0, H), (25, (-.03, -.1, .04), (0, 0, 10)),
                                                                (36, (0, -.02, .01), Z0), (42, Z0, Z0), (50, Z0, Z0)]}},
    'SM_Wep_Nailgun': {'Wep_Reload': {'SM_Wep_Nailgun_Mag': [(0, Z0, Z0), (6, Z0, Z0), (10, (0, -.03, -.12), Z0), (11, (0, -.03, -.12), Z0, H),
                                                              (23, (0, -.03, -.1), Z0, H), (24, (0, -.03, -.1), Z0), (30, Z0, Z0), (40, Z0, Z0)]}},
    'SM_Wep_LMG': {'Wep_Reload': {'SM_Wep_LMG_Cover': [(0, Z0, Z0), (8, Z0, Z0), (13, Z0, (70, 0, 0)), (40, Z0, (70, 0, 0)), (45, Z0, Z0), (60, Z0, Z0)],
                                  'SM_Wep_LMG_Mag': [(0, Z0, Z0), (14, Z0, Z0), (19, (-.03, 0, -.2), (0, 10, 0)), (20, (-.03, 0, -.2), Z0, H),
                                                     (31, (-.02, 0, -.15), Z0, H), (32, (-.02, 0, -.15), Z0), (38, Z0, Z0), (60, Z0, Z0)]}},
    'SM_Wep_GrenadeLauncher': {'Wep_Fire': {'SM_Wep_GrenadeLauncher_Cylinder': [(0, Z0, Z0), (6, Z0, Z0), (10, Z0, (0, 60, 0)), (20, Z0, (0, 60, 0))]}},
    'SM_Wep_TeslaRifle': {'Wep_Fire': {'SM_Wep_TeslaRifle_Coil': [(0, Z0, Z0), (3, Z0, (0, 120, 0)), (6, Z0, (0, 240, 0)), (9, Z0, (0, 360, 0))]}},
    'SM_Wep_Fun_LeafBlower': {'Wep_Fire': {'SM_Wep_Fun_LeafBlower_Fan': [(0, Z0, Z0), (2, Z0, (0, 120, 0)), (4, Z0, (0, 240, 0)), (6, Z0, (0, 360, 0))]}},
}

W2.ASSETS.update(NEW)
W2.PART_ANIMS.update(NEW_ANIMS)
