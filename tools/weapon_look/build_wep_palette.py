"""Weapon surface atlas: same 16x16 cell layout as art/env/T_Env_Palette.png.
Writes art/env/materials/T_Wep_Palette.png (albedo, weapon tweaks) and T_Wep_Surface.png
(R roughness, G metallic, B grain: 0 none, 128 wood; 255 marks metal, unused by the shader). Cells are found by colour,
so the env palette stays the single source of the layout.
    python -I tools/weapon_look/build_wep_palette.py <project root>"""
import sys
from PIL import Image

# palette colour -> (name, roughness, metallic, grain)
WOOD, METAL = 128, 255
CELLS = {
    # painted / coated metal
    (40, 40, 43): ('gun_black', 0.50, 0.29, METAL), (34, 34, 36): ('paint_black', 0.48, 0.20, METAL),
    (52, 58, 70): ('gun_blued', 0.46, 0.45, METAL),
    (94, 100, 66): ('military', 0.62, 0.20, METAL), (72, 78, 50): ('military_dark', 0.62, 0.20, METAL),
    (124, 128, 88): ('military_light', 0.62, 0.20, METAL),
    (178, 50, 42): ('paint_red', 0.45, 0.10, 0), (134, 38, 32): ('paint_red_dark', 0.45, 0.10, 0),
    (224, 180, 50): ('paint_yellow', 0.45, 0.10, 0), (228, 224, 214): ('paint_white', 0.45, 0.07, 0),
    (230, 186, 40): ('hazard_yellow', 0.50, 0.07, 0),
    # anodised aluminium, light alloy
    (88, 92, 100): ('gun_grey', 0.53, 0.36, METAL), (70, 76, 88): ('gun_slate', 0.53, 0.36, METAL),
    (178, 182, 188): ('suit_grey', 0.48, 0.45, METAL), (128, 132, 140): ('alu_dark', 0.48, 0.49, METAL),
    # polymer, plastic, rubber
    (60, 62, 66): ('gun_dark', 0.72, 0.00, 0), (172, 150, 110): ('polymer_tan', 0.75, 0.00, 0),
    (150, 154, 156): ('plastic_grey', 0.60, 0.00, 0), (214, 216, 212): ('lab_white', 0.55, 0.00, 0),
    (122, 54, 44): ('ammo_red', 0.60, 0.00, 0),
    # bare metal
    (106, 110, 116): ('gun_metal', 0.43, 0.52, METAL), (172, 176, 180): ('steel', 0.38, 0.55, METAL),
    (72, 74, 78): ('iron', 0.63, 0.45, METAL), (48, 50, 54): ('iron_dark', 0.73, 0.39, METAL),
    (206, 212, 220): ('blade', 0.30, 0.59, METAL), (150, 156, 166): ('blade_dark', 0.43, 0.55, METAL),
    (238, 240, 242): ('hamon', 0.26, 0.59, METAL),
    (198, 160, 74): ('brass', 0.38, 0.62, 0), (206, 166, 82): ('ammo_brass', 0.38, 0.62, 0),
    (222, 178, 66): ('gold', 0.38, 0.62, 0), (178, 106, 66): ('copper', 0.43, 0.59, METAL),
    (152, 84, 48): ('rust', 0.95, 0.13, 0),
    # wood
    (126, 78, 46): ('gun_wood', 0.55, 0.00, WOOD), (94, 58, 34): ('gun_wood_dark', 0.55, 0.00, WOOD),
    (138, 98, 62): ('wood', 0.80, 0.00, WOOD), (168, 126, 82): ('wood_light', 0.80, 0.00, WOOD),
    (190, 156, 108): ('wood_raw', 0.85, 0.00, WOOD), (112, 54, 40): ('mahogany', 0.40, 0.00, WOOD),
    # leather, cord, lacquer
    (96, 62, 40): ('leather', 0.70, 0.00, 0), (70, 44, 28): ('leather_dark', 0.75, 0.00, 0),
    (178, 152, 104): ('rope', 0.95, 0.00, 0), (40, 42, 62): ('ito', 0.95, 0.00, 0),
    (222, 216, 198): ('samegawa', 0.80, 0.00, 0), (112, 62, 140): ('sageo', 0.90, 0.00, 0),
    (34, 26, 28): ('lacquer', 0.25, 0.00, 0),
    # the fun ones
    (208, 150, 78): ('bread', 0.90, 0.00, 0), (162, 104, 48): ('bread_dark', 0.90, 0.00, 0),
    (238, 210, 156): ('bread_cut', 0.95, 0.00, 0), (244, 212, 62): ('rubber_yellow', 0.50, 0.00, 0),
    (234, 130, 40): ('beak', 0.50, 0.00, 0), (214, 50, 44): ('comb', 0.50, 0.00, 0),
    (216, 130, 84): ('fish_top', 0.35, 0.00, 0), (178, 98, 62): ('fish_patch', 0.35, 0.00, 0),
    (242, 238, 228): ('fish_belly', 0.35, 0.00, 0), (192, 62, 52): ('gill', 0.40, 0.00, 0),
    (118, 26, 24): ('blood', 0.40, 0.00, 0),
}
# albedo tweaks for weapons only: coated black lifted so parts stay readable in shade
ALBEDO = {'gun_black': (52, 53, 57), 'paint_black': (46, 46, 49), 'steel': (148, 152, 158), 'blade': (184, 190, 198)}


# weapon-only swatches, appended after the env names (index 209+, same order as kit.WEP)
NEW = [('rubber', (34, 34, 36), .92, 0, 0), ('gun_black_worn', (96, 98, 102), .40, .50, METAL),
       ('gun_blued_worn', (108, 116, 126), .38, .55, METAL), ('gun_grey_worn', (132, 136, 142), .40, .55, METAL),
       ('gun_dark_worn', (84, 86, 90), .55, 0, 0), ('wood_worn', (152, 100, 62), .45, 0, WOOD)]
FIRST_NEW = 209


def main(root):
    pal = Image.open(root + '/art/env/T_Env_Palette.png').convert('RGB')
    alb = pal.copy()
    surf = Image.new('RGB', pal.size, (255, 0, 0))
    found = set()
    for cy in range(16):
        for cx in range(16):
            col = pal.getpixel((cx * 16 + 8, cy * 16 + 8))
            if col not in CELLS:
                continue
            name, r, m, g = CELLS[col]
            found.add(name)
            box = (cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16)
            surf.paste((round(r * 255), round(m * 255), g), box)
            if name in ALBEDO:
                alb.paste(ALBEDO[name], box)
    for i, (name, rgb, r, m, g) in enumerate(NEW):
        cx, cy = (FIRST_NEW + i) % 16, (FIRST_NEW + i) // 16
        assert pal.getpixel((cx * 16 + 8, cy * 16 + 8)) == (255, 0, 255), name
        box = (cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16)
        alb.paste(rgb, box)
        surf.paste((round(r * 255), round(m * 255), g), box)
    missing = {v[0] for v in CELLS.values()} - found
    assert not missing, missing
    alb.save(root + '/art/env/materials/T_Wep_Palette.png')
    surf.save(root + '/art/env/materials/T_Wep_Surface.png')
    print('cells', len(found))


if __name__ == '__main__':
    main(sys.argv[1])
