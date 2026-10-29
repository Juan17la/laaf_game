"""Items pack: everything Alex picks up, carries, throws or fires across the three chapters.

Auto-loaded by build_assets._load_packs(); MODELS only (no place(): scripts spawn these at runtime).
Conventions (meters): pickups sit on the ground with origin at bottom centre, readable side +Y/+Z.
Weapons: origin = palm centre of the grip, barrel -Z, +Y up (muzzle points listed per model).
Round parts are smooth lathes; crisp() duplicates profile points so bands meet at hard edges.
"""
import math

import build_assets as B

mix, mul = B.mix, B.mul


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


# ============================================================== textures (64px unless noted)

def t_itm_grip(x, y, a, b, r):
    c = mul((0.36, 0.2, 0.1), 0.6 + 0.35 * a + 0.25 * math.sin(y * 0.5 + a * 7))
    return mul(c, 0.7) if (x + y) % 6 == 0 or (x - y) % 6 == 0 else c  # checkering


def t_itm_veneer(x, y, a, b, r):
    g = 0.5 + 0.5 * math.sin(y * 0.9 + a * 9 + math.sin(x * 0.08) * 2)
    return mul((0.4, 0.23, 0.12), 0.55 + 0.3 * g + 0.2 * a)


def t_itm_panel(x, y, a, b, r):
    return mul((0.1, 0.1, 0.105), 0.8 + 0.25 * a + (0.15 if y % 4 == 0 else 0))


def t_itm_grille(x, y, a, b, r):
    if x % 8 in (0, 1):
        return mul((0.55, 0.52, 0.45), 0.8 + 0.3 * a)  # chrome slats over the cloth
    return mul((0.36, 0.28, 0.16), (0.55 + 0.4 * a) * (0.8 if (x + y) % 2 else 1.0))


def t_itm_dial(x, y, a, b, r):
    c = mul((0.95, 0.78, 0.45), 0.8 + 0.2 * a)
    for band in (14, 32, 50):
        if y == band:
            return (0.2, 0.12, 0.05)
        if band - 5 < y < band and x % 4 == 0 or band - 7 < y < band and x % 16 == 2:
            return (0.25, 0.15, 0.06)
        if band + 2 < y < band + 6 and x % 16 in (5, 6, 8) and r > 0.3:
            return (0.35, 0.2, 0.08)  # the station numbers
    return mix(c, (0.5, 0.3, 0.12), 0.35) if b > 0.62 else c


def t_itm_bottle_label(x, y, a, b, r):
    c = mul((0.85, 0.78, 0.6), 0.75 + 0.25 * a)
    if ((x - 32) / 20) ** 2 + ((y - 26) / 14) ** 2 < 1 and not ((x - 32) / 17) ** 2 + ((y - 26) / 11) ** 2 < 1:
        return (0.55, 0.08, 0.06)
    if 20 < y < 32 and 22 < x < 42 and (x % 3) and r > 0.25:
        return (0.15, 0.1, 0.06)
    if y in (46, 50, 54) and 12 < x < 52:
        return (0.3, 0.22, 0.12)
    return mix(c, (0.35, 0.25, 0.1), 0.6) if b > 0.62 else c  # grease stains


def t_itm_ammo(x, y, a, b, r):
    if y < 22:
        c = (0.85, 0.65, 0.1)
    elif y < 42:
        c = (0.62, 0.08, 0.06)
        if 26 < y < 38 and 6 < x < 58 and x % 7 not in (0, 6) and r > 0.15:
            c = (0.9, 0.88, 0.8)  # ".38 SPL" block letters
    else:
        c = (0.82, 0.8, 0.72)
        if y in (48, 53) and 6 < x < 50:
            c = (0.2, 0.2, 0.2)
    return mul(c, 0.7 + 0.3 * a)


def t_itm_redcross(x, y, a, b, r):
    cross = (abs(x - 32) < 7 and abs(y - 32) < 20) or (abs(y - 32) < 7 and abs(x - 32) < 20)
    c = (0.7, 0.07, 0.05) if cross else (0.86, 0.85, 0.8)
    if b > 0.7 and not cross:
        c = mix(c, (0.35, 0.2, 0.12), 0.7)  # chipped enamel
    return mul(c, 0.75 + 0.25 * a)


def t_itm_gauze(x, y, a, b, r):
    return mul((0.93, 0.92, 0.88), 0.7 + 0.2 * a + (0.12 if (x % 3 == 0 or y % 3 == 0) else 0))


def t_itm_gauze_end(x, y, a, b, r):
    d = math.hypot(x - 31.5, y - 31.5)
    if d < 9:
        return (0.35, 0.3, 0.25)  # cardboard core hole
    ring = 0.5 + 0.5 * math.sin(d * 2.4 + math.atan2(y - 31.5, x - 31.5) * 0.4)
    return mul((0.93, 0.92, 0.88), 0.65 + 0.3 * ring)


def t_itm_flare(x, y, a, b, r):
    if 6 < y < 22:
        c = (0.9, 0.88, 0.8)
        if y in (11, 15, 18) and x % 5 and r > 0.2:
            c = (0.1, 0.1, 0.1)
    else:
        c = (0.72, 0.07, 0.05)
    return mul(c, 0.7 + 0.3 * a)


def t_itm_note(x, y, a, b, r):
    c = mul((0.88, 0.85, 0.74), 0.82 + 0.18 * a)
    if x == 9:
        return (0.7, 0.3, 0.3)
    if y % 6 == 0:
        c = mix(c, (0.45, 0.55, 0.75), 0.5)
    if y % 6 == 3 and 12 < x < 58 - (y * 7) % 20 and math.sin(x * 1.7 + y) > -0.3:
        c = (0.12, 0.12, 0.22)  # the handwriting
    if x in (31, 32):
        c = mul(c, 0.85)  # fold crease
    return mix(c, (0.6, 0.5, 0.35), 0.4) if b > 0.66 else c


def t_itm_pages(x, y, a, b, r):
    return mul((0.8, 0.74, 0.58), (0.65 + 0.25 * a) * (0.8 if y % 2 else 1.0))


def t_itm_leather(x, y, a, b, r):
    return mul((1, 1, 1), 0.55 + 0.35 * a + 0.1 * r - (0.15 if b > 0.6 else 0))


def t_itm_ledger_label(x, y, a, b, r):
    c = mul((0.33, 0.18, 0.1), 0.6 + 0.3 * a)
    if 16 < x < 48 and 12 < y < 30 and (x in (17, 47) or y in (13, 29)):
        return (0.7, 0.55, 0.2)
    if 20 < x < 44 and y in (19, 23) and x % 3:
        return (0.65, 0.5, 0.18)  # gilt title
    return c


def t_itm_photo(x, y, a, b, r):
    if x < 5 or x > 58 or y < 5 or y > 58:
        return mul((0.88, 0.84, 0.72), 0.85 + 0.15 * a)  # white border
    v = 0.55 + 0.25 * a
    face = ((x - 32) / 7) ** 2 + ((y - 25) / 9) ** 2 < 1
    hair = ((x - 32) / 11) ** 2 + ((y - 25) / 13) ** 2 < 1 and y < 37
    body = y > 34 and abs(x - 32) < 7 + (y - 34) * 0.9
    if face:
        v = 0.8 + 0.1 * a
        if y == 29 and abs(x - 32) < 3:
            v = 0.35  # the laugh
    elif hair:
        v = 0.2
    elif body:
        v = 0.3 + 0.15 * a  # choir robe
        if y < 40 and abs(x - 32) < 3:
            v = 0.85  # white collar
    v *= 1 - 0.5 * clamp(math.hypot((x - 32) / 30, (y - 32) / 30) - 0.6)
    return mul((1.0, 0.82, 0.58), v)


def t_itm_crayon(x, y, a, b, r):
    """Lily's drawing (128px): sky, sun, house, mum and a little girl in a yellow jacket."""
    gap = r < 0.18  # crayon doesn't fill the paper grain
    paper = mul((0.93, 0.91, 0.84), 0.9 + 0.1 * a)
    def ink(c):
        return paper if gap else mul(c, 0.85 + 0.2 * a)
    if y < 20 and (y + x // 3) % 5 < 3:
        return ink((0.25, 0.45, 0.9))
    sx, sy = x - 108, y - 20
    if math.hypot(sx, sy) < 11 or (math.hypot(sx, sy) < 20 and abs(math.atan2(sy, sx) * 8 / math.pi % 2 - 1) < 0.25):
        return ink((0.98, 0.8, 0.1))
    if y > 108 and (x + y) % 4 < 3:
        return ink((0.2, 0.65, 0.2))
    if 14 < x < 58 and 64 < y < 108:
        if 30 < x < 42 and y > 86:
            return ink((0.35, 0.2, 0.1))  # door
        if (18 < x < 28 or 46 < x < 56) and 72 < y < 82:
            return ink((0.3, 0.55, 0.95))
        return ink((0.85, 0.15, 0.1)) if (x + y) % 3 else paper
    if 64 >= y > 36 and abs(x - 36) < (y - 36) * 0.9:
        return ink((0.45, 0.25, 0.1))  # roof
    for fx, fy, s, coat in ((78, 60, 1.0, (0.55, 0.2, 0.6)), (98, 76, 0.7, (1.0, 0.85, 0.1))):
        if abs(math.hypot(x - fx, y - fy) - 7 * s) < 1.4:
            return ink((0.2, 0.15, 0.1))
        if fy + 7 * s < y < fy + 30 * s and abs(x - fx) < (y - fy - 7 * s) * 0.45:
            return ink(coat)  # dress / the yellow jacket
        legs = [(fx - 3 * s, fy + 30 * s, fx - 5 * s, fy + 44 * s), (fx + 3 * s, fy + 30 * s, fx + 5 * s, fy + 44 * s)]
        if any(B.seg_dist(x, y, *l) < 1.3 for l in legs):
            return ink((0.2, 0.15, 0.1))
    if B.seg_dist(x, y, 84, 72, 94, 84) < 1.4:
        return ink((0.2, 0.15, 0.1))  # holding hands
    return paper


def t_itm_batt(x, y, a, b, r):
    if y < 10 or y > 54:
        c = (0.1, 0.1, 0.11)
    elif y < 24:
        c = (0.85, 0.1, 0.06)
        if 14 < y < 20 and 8 < x < 56 and x % 6 not in (0, 5):
            c = (0.95, 0.95, 0.9)  # "HEAVY DUTY"
    else:
        c = (0.95, 0.72, 0.08)
        if 30 < y < 46 and 6 < x < 40 and x % 8 not in (0, 7) and r > 0.1:
            c = (0.08, 0.08, 0.08)
        if 44 < x < 58 and 30 < y < 48:
            c = (0.1, 0.1, 0.1) if abs(x - 51) < 1.5 or abs(y - 39) < 1.5 else c
    return mul(c, 0.75 + 0.25 * a)


def t_itm_cassette(x, y, a, b, r):
    c = (0.08, 0.08, 0.09)
    if 6 < y < 26 and 4 < x < 60:
        c = (0.85, 0.82, 0.7) if y > 10 else (0.8, 0.2, 0.1)
        if y in (15, 20) and 8 < x < 56:
            c = (0.2, 0.2, 0.4)  # "E. — ch.7" in biro
    for hx in (20, 44):
        d = math.hypot(x - hx, y - 40)
        if d < 10:
            c = (0.35, 0.2, 0.1) if d > 5 else (0.9, 0.9, 0.88) if d > 3 or (x + y) % 3 else c
    if 28 < y < 50 and 26 < x < 38:
        c = (0.12, 0.12, 0.14)
    return mul(c, 0.8 + 0.2 * a)


def t_itm_perf(x, y, a, b, r):
    return (0.05, 0.05, 0.05) if (x % 4 < 2 and y % 4 < 2) else mul((0.5, 0.5, 0.52), 0.8 + 0.2 * a)


def t_itm_map(x, y, a, b, r):
    c = mul((0.86, 0.8, 0.62), 0.8 + 0.2 * a)
    if b > 0.6:
        c = mix(c, (0.5, 0.65, 0.4), 0.5)  # forest
    if abs(y - 40 - 8 * math.sin(x * 0.12)) < 1.5:
        return (0.25, 0.4, 0.7)  # river
    if abs(x - 20 - y * 0.3) < 1 or abs(y - 14) < 1:
        return (0.6, 0.15, 0.1)  # roads
    if abs(math.hypot(x - 46, y - 24) - 5) < 1:
        return (0.85, 0.05, 0.05)  # circled in red
    if x % 16 == 0 or y % 16 == 0:
        return mul(c, 0.8)  # fold lines
    return c


def t_itm_file(x, y, a, b, r):
    c = mul((0.85, 0.72, 0.45), 0.8 + 0.2 * a)
    if 8 < x < 40 and 10 < y < 20 and (x in (9, 39) or y in (11, 19) or (x % 4 and 13 < y < 17)):
        return (0.7, 0.1, 0.1)  # CONFIDENTIAL stamp
    if 8 < x < 56 and y in (30, 34, 38) and r > 0.2:
        return (0.25, 0.2, 0.15)
    return c


def t_itm_tea(x, y, a, b, r):
    if 18 < y < 46 and 8 < x < 56:
        c = (0.88, 0.84, 0.7)
        if y in (26, 30) and 14 < x < 50 and x % 3:
            c = (0.15, 0.25, 0.12)  # "ELENA"
        if 34 < y < 42 and abs(x - 32) < 8 and (x + y) % 3:
            c = (0.7, 0.55, 0.2)  # moth motif
        return mul(c, 0.8 + 0.2 * a)
    c = (0.12, 0.3, 0.16)
    if y in (15, 49) or (y < 15 or y > 49) and (x + y) % 8 == 0:
        c = (0.75, 0.6, 0.2)  # gilt border
    return mul(c, 0.7 + 0.35 * a)


def t_itm_tin(x, y, a, b, r):
    """Faded biscuit-tin print: blue ground, gold border, cream oval with a red rose."""
    c = (0.15, 0.25, 0.45)
    if x < 5 or x > 58 or y < 5 or y > 58 or x in (8, 55) or y in (8, 55):
        c = (0.75, 0.6, 0.25)
    e = ((x - 32) / 20) ** 2 + ((y - 32) / 16) ** 2
    if e < 1:
        c = (0.85, 0.8, 0.65) if e > 0.85 or math.hypot(x - 32, y - 32) > 7 else (0.7, 0.12, 0.1)
        if 0.85 < e:
            c = (0.75, 0.6, 0.25)
        elif abs(y - 42) < 2 and abs(x - 32) < 10:
            c = (0.2, 0.45, 0.2)  # leaves
    c = mul(c, 0.6 + 0.35 * a)
    return mix(c, (0.35, 0.18, 0.08), clamp((b - 0.5) * 3))  # rust eating the print


def t_itm_tag(x, y, a, b, r):
    c = mul((0.85, 0.75, 0.5), 0.8 + 0.2 * a)
    if math.hypot(x - 10, y - 32) < 5:
        return (0.6, 0.55, 0.4) if math.hypot(x - 10, y - 32) > 3 else (0.1, 0.1, 0.1)
    if y in (20, 28, 36, 44) and 20 < x < 58 and r > 0.25:
        return (0.1, 0.1, 0.3)
    return c


def t_itm_band(x, y, a, b, r):
    c = (0.88, 0.88, 0.84)
    if 20 < y < 44 and x % 8 not in (0, 7) and r > 0.15:
        c = (0.1, 0.1, 0.1)  # stencil "SMOKE WHT"
    return mul(c, 0.75 + 0.25 * a)


def t_itm_strap(x, y, a, b, r):
    """Woven elastic headband: black, a yellow stripe along each edge, the weave showing (no lettering)."""
    if y < 9 or y > 54:
        return mul((0.85, 0.66, 0.1), 0.75 + 0.25 * a)
    if y < 12 or y > 51:
        return (0.05, 0.05, 0.05)
    return mul((0.09, 0.09, 0.085), 0.8 + 0.25 * a + (0.12 if (x + y) % 4 == 0 else 0.0))


B.TEXTURES.update({k[2:]: v for k, v in list(globals().items()) if k.startswith("t_itm_")})
B.TEX_SIZE["itm_crayon"] = 128


B.MATS.update({
    # metals
    "itm_gunmetal": B.M("metal", (0.62, 0.66, 0.74), 0.25, rough=0.3),
    "itm_blued": B.M("metal", (0.35, 0.38, 0.45), 0.25, rough=0.3),
    "itm_bore": B.M("plain", (0.01, 0.01, 0.012), 1),
    "itm_brass": B.M("plain", (0.78, 0.58, 0.24), 1, rough=0.3),
    "itm_copper": B.M("plain", (0.68, 0.36, 0.2), 1, rough=0.35),
    "itm_lead": B.M("plain", (0.36, 0.36, 0.38), 1, rough=0.5),
    "itm_chrome": B.M("plain", (0.75, 0.77, 0.8), 1, rough=0.15),
    "itm_steel": B.M("plain", (0.55, 0.57, 0.6), 1, rough=0.25),
    "itm_olive": B.M("metal", (0.6, 0.75, 0.42), 0.3, rough=0.6),
    "itm_galv": B.M("itm_leather", (0.62, 0.66, 0.68), 0.3, rough=0.35),
    "itm_rust_iron": B.M("rust", (1.0, 1.0, 1.0), 0.2),
    # plastics / rubber
    "itm_orange": B.M("plain", (0.95, 0.38, 0.06), 1, rough=0.5),
    "itm_orange_dk": B.M("plain", (0.68, 0.14, 0.04), 1, rough=0.6),
    "itm_black": B.M("plain", (0.04, 0.04, 0.045), 1, rough=0.55),
    "itm_bakelite": B.M("plain", (0.07, 0.045, 0.03), 1, rough=0.25),
    "itm_red": B.M("plain", (0.62, 0.06, 0.04), 1, rough=0.5),
    "itm_white": B.M("plain", (0.82, 0.82, 0.78), 1, rough=0.5),
    "itm_rubber": B.M("plain", (0.17, 0.19, 0.15), 1, rough=0.8),
    "itm_case": B.M("plain", (0.1, 0.1, 0.11), 1, rough=0.6),
    "itm_grey": B.M("plain", (0.2, 0.2, 0.21), 1, rough=0.5),
    # glass / lights
    "itm_glass": B.M("plain", (0.07, 0.26, 0.11), 1, rough=0.06),
    "itm_clear": B.M("plain", (0.62, 0.7, 0.7), 1, rough=0.05),
    "itm_lens": B.M("plain", (0.14, 0.2, 0.22), 1, rough=0.05),
    "itm_bulb_green": B.M("plain", (0.35, 1.0, 0.35), 1, emit=2.5),
    "itm_bulb_amber": B.M("plain", (1.0, 0.6, 0.15), 1, emit=3.0),
    "itm_serum": B.M("plain", (0.55, 1.0, 0.6), 1, emit=1.5),
    "itm_hot": B.M("plain", (1.0, 0.3, 0.08), 1, emit=3.0),
    # organic / paper
    "itm_grip": B.M("itm_grip", scale=0.05),
    "itm_veneer": B.M("itm_veneer", scale=0.35),
    "itm_leather": B.M("itm_leather", (0.35, 0.2, 0.12), 0.15),
    "itm_leather_lt": B.M("itm_leather", (0.5, 0.32, 0.18), 0.12),
    "itm_rag": B.M("fabric", (0.95, 0.9, 0.8), 0.12),
    "itm_cardboard": B.M("plain", (0.55, 0.42, 0.28), 1),
    "itm_paper": B.M("plain", (0.8, 0.77, 0.68), 1),
    "itm_cork": B.M("itm_leather", (0.75, 0.58, 0.4), 0.05),
    "itm_wood": B.M("planks", (0.85, 0.65, 0.5), 0.25),
    "itm_wax": B.M("plain", (0.55, 0.05, 0.05), 1, rough=0.3),
    "itm_lamp_lens": B.M("plain", (0.78, 0.8, 0.74), 1, rough=0.1),  # the headlamp's lens (lit by the game)
    # printed (fit = one copy per face / lathe band)
    **{"itm_" + k: B.M("itm_" + k, fit=True) for k in (
        "panel", "grille", "bottle_label", "ammo", "redcross", "gauze", "gauze_end", "flare", "note", "pages",
        "ledger_label", "photo", "crayon", "batt", "cassette", "perf", "map", "file", "tea", "tin", "tag", "band",
        "strap")},
})
B.MATS["itm_dial"] = B.M("itm_dial", fit=True, emit=0.7)
B.MATS["itm_gauze_roll"] = B.M("itm_gauze", scale=0.04)


# ============================================================== helpers

def crisp(prof):
    """Duplicate interior profile points: the lathe then creases there (flat caps, sharp collars)."""
    return [prof[0]] + [p for p in prof[1:-1] for _ in (0, 1)] + [prof[-1]]


def turn(m, mat, prof, pos=(0, 0, 0), rot=(0, 0, 0), seg=12, smooth=False, scale=(1, 1, 1)):
    m.lathe(mat, prof if smooth else crisp(prof), pos, rot, scale, seg)


def torus(m, mat, R, r, pos=(0, 0, 0), rot=(0, 0, 0), seg=12, sides=6, scale=(1, 1, 1)):
    prof = [(R + r * math.cos(2 * math.pi * k / sides - math.pi / 2), r * math.sin(2 * math.pi * k / sides - math.pi / 2))
            for k in range(sides + 1)]
    m.lathe(mat, prof, pos, rot, scale, seg)


def disc(m, mat, r, pos=(0, 0, 0), rot=(0, 0, 0), seg=12):
    """Flat polygon facing local +Y (fit materials map the whole texture onto it)."""
    with m.push(pos, rot):
        m.emit(mat, [(r * math.cos(2 * math.pi * i / seg), 0, -r * math.sin(2 * math.pi * i / seg)) for i in range(seg)],
               (0, -1, 0))


def rod(m, mat, a, b, r, seg=6, caps=True):
    d = B.v_sub(b, a)
    L = math.sqrt(B.v_dot(d, d))
    rx = math.degrees(math.acos(max(-1.0, min(1.0, d[1] / L))))
    ry = math.degrees(math.atan2(d[0], d[2]))
    m.cyl(mat, r, r, L, a, (rx, ry, 0), seg=seg, caps=caps)


def bar(m, mat, a, b, w, h=None):
    """Box from a to b, cross-section w x h."""
    d = B.v_sub(b, a)
    L = math.sqrt(B.v_dot(d, d))
    mid = tuple((a[i] + b[i]) / 2 for i in range(3))
    rx = math.degrees(math.atan2(-d[1], math.hypot(d[0], d[2])))
    m.box(mat, (w, h or w, L), mid, (rx, math.degrees(math.atan2(d[0], d[2])), 0))


def path(m, mat, pts, r, seg=5, closed=False):
    """Round wire through pts (straps, guards, rings)."""
    n = len(pts)
    for i in range(n if closed else n - 1):
        rod(m, mat, pts[i], pts[(i + 1) % n], r, seg, caps=not closed)


def sheet(m, mat, w, d, lift, nx=8, nz=6, crease=False, back="itm_paper", y0=0.001):
    """Paper lying flat, top faces +Y, image top toward -Z. lift(u, v) -> height, u/v in -1..1."""
    xs = [-w / 2 + w * j / nx for j in range(nx + 1)]
    if crease:
        xs = xs[:nx // 2 + 1] + xs[nx // 2:]
    rows = [[(x, y0 + lift(x / (w / 2), z / (d / 2)), z) for x in xs] for z in (d / 2 - d * i / nz for i in range(nz + 1))]
    m.surface(mat, rows, uv=lambda p: ((p[0] + w / 2) / w, (p[2] + d / 2) / d))
    m.surface(back, [[(x, y - 0.0006, z) for x, y, z in row] for row in rows[::-1]])


def tris(m):
    return sum(len(p[0]) for nd in m.nodes for p in nd["prims"].values()) // 3


# ============================================================== weapons

def m_revolver():
    """Origin = palm centre of the grip; barrel -Z; muzzle tip (0, 0.06, -0.24).
    Child node "cylinder" sits on the cylinder axis (0, 0.0465, -0.05): spin it about its local Z."""
    m = B.Model("item_revolver")
    G, D = "itm_gunmetal", "itm_bore"
    m.node("revolver")
    with m.push((0, 0, 0.004), (-16, 0, 0)):  # raked grip
        m.loft("itm_grip", [(-0.064, 0, 0, 0, 0.004), (-0.062, 0.012, 0.018, 0, 0.004), (-0.055, 0.0145, 0.021, 0, 0.003),
                            (-0.02, 0.015, 0.021), (0.015, 0.0135, 0.019, 0, -0.001), (0.04, 0.012, 0.017, 0, -0.003),
                            (0.042, 0, 0, 0, -0.003)], seg=12, power=3)
        m.box(G, (0.022, 0.006, 0.036), (0, -0.063, 0.004))
        m.cyl("itm_brass", 0.005, 0.005, 0.002, (0.0145, -0.012, 0), (0, 0, -90), seg=8)
        m.cyl("itm_brass", 0.005, 0.005, 0.002, (-0.0145, -0.012, 0), (0, 0, 90), seg=8)
    m.box(G, (0.021, 0.05, 0.05), (0, 0.059, 0.0))  # frame / backstrap
    m.tbox(G, (0.021, 0.05), (0.016, 0.02), 0.012, (0, 0.084, 0.0))
    m.box(G, (0.014, 0.008, 0.062), (0, 0.0715, -0.05))  # top strap
    m.box(D, (0.003, 0.0012, 0.05), (0, 0.0757, -0.045))  # sight groove
    m.box(G, (0.018, 0.014, 0.062), (0, 0.024, -0.05))  # lower frame
    m.box(G, (0.018, 0.058, 0.014), (0, 0.047, -0.083))  # barrel shank
    m.box(G, (0.004, 0.009, 0.013), (-0.011, 0.054, -0.012))  # cylinder latch
    # barrel with recessed bore, underlug, rib, front sight
    turn(m, G, [(0.0105, 0), (0.0105, 0.012), (0.009, 0.016), (0.009, 0.152), (0.0045, 0.152)], (0, 0.06, -0.088), (-90, 0, 0), 12)
    turn(m, D, [(0.0045, 0.152), (0.0045, 0.14), (0, 0.14)], (0, 0.06, -0.088), (-90, 0, 0), 8)
    turn(m, G, [(0.0055, 0), (0.0055, 0.075), (0.004, 0.08), (0, 0.08)], (0, 0.045, -0.088), (-90, 0, 0), 8)
    m.box(G, (0.008, 0.012, 0.075), (0, 0.052, -0.126))
    m.box(G, (0.005, 0.004, 0.148), (0, 0.0695, -0.164))
    m.tbox(G, (0.003, 0.014), (0.003, 0.006), 0.011, (0, 0.068, -0.23))
    # hammer, trigger, guard
    m.box(G, (0.008, 0.026, 0.012), (0, 0.086, 0.021), (25, 0, 0))
    m.box(G, (0.009, 0.005, 0.016), (0, 0.098, 0.031), (-12, 0, 0))
    path(m, G, [(0, 0.031, 0.0), (0, 0.004, -0.004), (0, -0.006, -0.02), (0, -0.004, -0.042), (0, 0.012, -0.058),
                (0, 0.024, -0.06)], 0.0025, 5)
    bar(m, G, (0, 0.022, -0.032), (0, 0.01, -0.03), 0.005, 0.004)
    bar(m, G, (0, 0.01, -0.03), (0, 0.0, -0.024), 0.005, 0.004)
    # six-shot cylinder (own node so it can spin)
    m.node("cylinder", "revolver", (0, 0.0465, -0.05))
    turn(m, G, [(0.004, -0.021), (0.017, -0.021), (0.0205, -0.017), (0.0205, 0.017), (0.017, 0.021), (0.004, 0.021)],
         (0, 0, 0), (-90, 0, 0), 12)
    for k in range(6):
        ang = math.radians(90 + 60 * k)
        c, s = math.cos(ang), math.sin(ang)
        disc(m, D, 0.0045, (0.0135 * c, 0.0135 * s, -0.0212), (-90, 0, 0), 6)
        disc(m, "itm_brass", 0.005, (0.0135 * c, 0.0135 * s, 0.0212), (90, 0, 0), 6)  # rims seen from behind
        a2 = ang + math.radians(30)
        m.box("itm_blued", (0.0022, 0.0045, 0.024), (0.0199 * math.cos(a2), 0.0199 * math.sin(a2), 0),
              (0, 0, math.degrees(a2)))  # flutes
    rod(m, G, (0, 0, -0.021), (0, 0, -0.03), 0.004, 6)  # ejector star / pin
    return m


def m_flare_gun():
    """Origin = palm centre; barrel -Z; muzzle (0, 0.06, -0.20). Child node "barrel" pivots on the breech hinge
    at (0, 0.035, -0.045): rotate its local X +40 deg to break it open."""
    m = B.Model("item_flare_gun")
    O, OD, K, D = "itm_orange", "itm_orange_dk", "itm_black", "itm_bore"
    m.node("flare_gun")
    with m.push((0, 0, 0.006), (-14, 0, 0)):
        m.loft(OD, [(-0.07, 0, 0, 0, 0.004), (-0.068, 0.014, 0.022, 0, 0.004), (-0.06, 0.017, 0.027, 0, 0.003),
                    (0.0, 0.018, 0.026), (0.035, 0.016, 0.024, 0, -0.002), (0.045, 0.0, 0.0, 0, -0.002)], seg=12, power=3.5)
        for y in (-0.045, -0.025, -0.005):
            m.box(K, (0.03, 0.006, 0.006), (0, y, -0.026))  # finger grooves
        for x in (-1, 1):
            for y in (-0.05, -0.03, -0.01, 0.01):
                m.box(K, (0.002, 0.012, 0.03), (x * 0.0175, y, 0.002))  # molded grip ribs
        m.box(K, (0.028, 0.008, 0.044), (0, -0.068, 0.004))
        rod(m, K, (0, -0.065, 0.024), (0, -0.065, 0.034), 0.005, 6)  # lanyard loop
    m.box(O, (0.032, 0.056, 0.07), (0, 0.06, -0.008))  # receiver
    m.tbox(O, (0.032, 0.05), (0.022, 0.03), 0.014, (0, 0.088, 0.0))
    m.box(K, (0.034, 0.012, 0.012), (0, 0.084, -0.038))  # barrel latch
    m.box(K, (0.012, 0.03, 0.014), (0, 0.093, 0.026), (30, 0, 0))  # hammer
    m.box(K, (0.014, 0.006, 0.016), (0, 0.108, 0.036), (-10, 0, 0))
    for x in (-1, 1):
        m.cyl(K, 0.004, 0.004, 0.002, (x * 0.016, 0.062, -0.01), (0, 0, -90 * x), seg=6)  # pins
    rod(m, K, (-0.019, 0.035, -0.045), (0.019, 0.035, -0.045), 0.0065, 8)  # hinge pin
    path(m, O, [(0, 0.032, 0.0), (0, 0.004, -0.004), (0, -0.01, -0.022), (0, -0.008, -0.05), (0, 0.012, -0.066),
                (0, 0.03, -0.062)], 0.0045, 6)  # fat guard
    bar(m, K, (0, 0.03, -0.034), (0, 0.012, -0.03), 0.007, 0.006)
    bar(m, K, (0, 0.012, -0.03), (0, 0.0, -0.022), 0.007, 0.006)
    m.node("barrel", "flare_gun", (0, 0.035, -0.045))
    turn(m, O, [(0.021, 0.0), (0.024, 0.004), (0.024, 0.016), (0.0215, 0.02), (0.0215, 0.13), (0.025, 0.134),
                (0.025, 0.155), (0.0175, 0.155)], (0, 0.025, 0), (-90, 0, 0), 14)
    turn(m, D, [(0.0175, 0.155), (0.0175, 0.1), (0, 0.1)], (0, 0.025, 0), (-90, 0, 0), 10)
    disc(m, D, 0.02, (0, 0.025, 0.0005), (90, 0, 0), 10)  # breech face
    m.box(O, (0.018, 0.024, 0.036), (0, 0.006, -0.02))  # hinge lug
    m.box(O, (0.006, 0.005, 0.12), (0, 0.048, -0.08))  # sight rib
    m.box(K, (0.006, 0.008, 0.006), (0, 0.052, -0.148))
    return m


# ============================================================== held / thrown

def m_bottle():
    """Origin bottom centre, 0.24 tall, r 0.04; rag stuffed in the neck."""
    m = B.Model("item_bottle")
    m.node("bottle")
    turn(m, "itm_glass", [(0, 0.003), (0.012, 0.0), (0.036, 0.0), (0.04, 0.005), (0.04, 0.13), (0.038, 0.15),
                          (0.024, 0.172), (0.0145, 0.188), (0.013, 0.214), (0.0155, 0.217), (0.0155, 0.224),
                          (0.011, 0.225), (0.011, 0.215)], seg=14, smooth=True)
    turn(m, "itm_bottle_label", [(0.0405, 0.045), (0.0405, 0.12)], seg=14)
    turn(m, "itm_bottle_label", [(0.015, 0.19), (0.015, 0.202)], seg=14)
    m.rock("itm_rag", 0.013, 0.03, (0, 0.212, 0), rot=(0, 0, 8), seg=6, rings=2, jit=0.35)
    m.tbox("itm_rag", (0.024, 0.005), (0.016, 0.004), 0.075, (0.012, 0.236, 0.004), (0, 20, -160))  # the dangling tail
    m.tbox("itm_rag", (0.014, 0.004), (0.008, 0.003), 0.03, (-0.008, 0.238, -0.004), (0, -30, 140))
    return m


def m_car_battery():
    """0.34 x 0.22 x 0.2 case centred on origin; terminals on top (+Y) at x=+0.1 (red +) and x=-0.1 (black -)."""
    m = B.Model("item_car_battery")
    C = "itm_case"
    m.node("battery")
    m.box(C, (0.34, 0.19, 0.2), (0, -0.015, 0), faces={"+z": "itm_batt"})
    m.box(C, (0.334, 0.03, 0.194), (0, 0.095, 0))  # lid
    m.box(C, (0.34, 0.006, 0.2), (0, 0.082, 0))  # lid seam lip
    for x in (-1, 1):
        for z in (-0.06, 0, 0.06):
            m.box(C, (0.006, 0.17, 0.012), (x * 0.172, -0.02, z))  # end ribs
        m.box("itm_black", (0.008, 0.03, 0.12), (x * 0.171, 0.05, 0))  # hand-hold lip
    for k in range(6):
        m.cyl("itm_grey", 0.011, 0.011, 0.006, (-0.0625 + k * 0.025, 0.11, 0.03), seg=8)  # cell caps
        m.box("itm_black", (0.012, 0.002, 0.002), (-0.0625 + k * 0.025, 0.117, 0.03))
    for x, mat in ((0.1, "itm_red"), (-0.1, "itm_black")):
        turn(m, mat, [(0.022, 0.108), (0.022, 0.118), (0.017, 0.124)], (x, 0, 0), seg=10)  # boot collar
        turn(m, "itm_lead", [(0.012, 0.12), (0.011, 0.145), (0.009, 0.15), (0, 0.15)], (x, 0, 0), seg=8)
    # + / - moulded on the lid
    m.box("itm_red", (0.024, 0.003, 0.006), (0.1, 0.1115, 0.06))
    m.box("itm_red", (0.006, 0.003, 0.024), (0.1, 0.1115, 0.06))
    m.box("itm_white", (0.024, 0.003, 0.006), (-0.1, 0.1115, 0.06))
    # fold-up carry strap along X
    pts = [(-0.15, 0.1, -0.06), (-0.14, 0.14, -0.06), (-0.1, 0.165, -0.06), (0.1, 0.165, -0.06), (0.14, 0.14, -0.06),
           (0.15, 0.1, -0.06)]
    for a, b in zip(pts, pts[1:]):
        bar(m, "itm_black", a, b, 0.004, 0.025)
    for x in (-0.155, 0.155):
        m.box("itm_black", (0.012, 0.02, 0.03), (x, 0.1, -0.06))
    m.cyl("itm_bulb_green", 0.008, 0.008, 0.003, (0.0, 0.11, 0.065), seg=8)  # charge eye
    return m


# ============================================================== pickups

def cartridge(m, pos, rot, loaded=True):
    """.38 round lying along local +Y: brass case then lead nose."""
    turn(m, "itm_brass", [(0, 0), (0.0048, 0), (0.0048, 0.0012), (0.0045, 0.0014), (0.0045, 0.029)], pos, rot, 8)
    if loaded:
        turn(m, "itm_lead", [(0.0045, 0.029), (0.0045, 0.033), (0.0035, 0.038), (0, 0.04)], pos, rot, 8, smooth=True)


def m_ammo_box():
    m = B.Model("item_ammo_box")
    m.node("ammo")
    w, h, d = 0.12, 0.042, 0.08
    m.box("itm_cardboard", (w, h, d), (0, h / 2, 0), faces={"+z": "itm_ammo", "-z": "itm_ammo", "+x": "itm_ammo"})
    m.box("itm_cardboard", (w - 0.008, 0.001, d - 0.008), (0, h + 0.0005, 0))
    for i in range(5):
        for j in range(3):  # cartridge heads in the tray: rims, primers
            x, z = -0.044 + i * 0.022, -0.022 + j * 0.022
            m.cyl("itm_brass", 0.0055, 0.0055, 0.004, (x, h, z), seg=8)
            m.cyl("itm_steel", 0.0018, 0.0018, 0.0045, (x, h, z), seg=5)
    with m.push((0, h, -d / 2), (-115, 0, 0)):  # lid hinged open at the back
        m.box("itm_cardboard", (w, 0.003, d), (0, 0.0015, d / 2), faces={"-y": "itm_ammo"})
        m.box("itm_cardboard", (w, 0.012, 0.003), (0, -0.006, d))
    cartridge(m, (0.08, 0.0048, 0.03), (0, 70, -90))
    cartridge(m, (0.075, 0.0048, -0.01), (0, 20, -90))
    cartridge(m, (-0.02, 0.0048, 0.07), (0, -35, -90))
    cartridge(m, (0.03, 0.0048, 0.075), (0, 140, -90), loaded=False)  # spent case
    return m


def m_bandage():
    m = B.Model("item_bandage")
    m.node("bandage")
    # first-aid tin with the red cross, lid resting slightly skewed
    m.box("itm_white", (0.12, 0.028, 0.085), (-0.05, 0.014, 0))
    m.box("itm_white", (0.124, 0.01, 0.089), (-0.05, 0.031, 0), (0, 4, 0), faces={"+y": "itm_redcross"})
    m.box("itm_steel", (0.02, 0.006, 0.004), (-0.05, 0.026, 0.046))  # clasp
    # gauze roll on its side, tail unrolled across the ground
    with m.push((0.06, 0.032, 0.0), (0, 30, 90)):
        m.cyl("itm_gauze_roll", 0.032, 0.032, 0.055, (0, -0.0275, 0), seg=14, caps=False)
        disc(m, "itm_gauze_end", 0.032, (0, 0.0275, 0), seg=14)
        disc(m, "itm_gauze_end", 0.032, (0, -0.0275, 0), (180, 0, 0), seg=14)
    with m.push((0.085, 0, 0.075), (0, 30, 0)):
        sheet(m, "itm_gauze", 0.05, 0.1, lambda u, v: 0.01 * max(0.0, -v) ** 2 + 0.002 * math.sin(v * 5), 2, 5,
              back="itm_gauze")
    return m


def road_flare(m, pos, yaw):
    with m.push(pos, (0, yaw, -90)):  # along +X
        turn(m, "itm_flare", [(0.016, -0.11), (0.016, 0.09)], seg=10, rot=(0, 90, 0))
        turn(m, "itm_red", [(0, -0.115), (0.013, -0.115), (0.016, -0.11)], seg=10)
        turn(m, "itm_black", [(0.0175, 0.085), (0.0175, 0.125), (0.014, 0.13), (0, 0.13)], seg=10)  # striker cap
        turn(m, "itm_white", [(0.0178, 0.1), (0.0178, 0.108)], seg=10)


def m_flares():
    m = B.Model("item_flares")
    m.node("flares")
    road_flare(m, (0, 0.016, 0.0165), 0)
    road_flare(m, (-0.01, 0.016, -0.0165), 0)
    road_flare(m, (0.012, 0.0445, 0.0), 0)
    for x in (-0.05, 0.045):  # black tape round the bundle
        m.cyl("itm_black", 0.036, 0.036, 0.018, (x, 0.027, 0), (0, 0, -90), seg=7, caps=False)
    return m


def filter_can(m, pos=(0, 0, 0), rot=(0, 0, 0), s=1.0):
    """Gas-mask filter canister standing on its intake, 40 mm thread up."""
    S = lambda p: [(r * s, y * s) for r, y in p]
    with m.push(pos, rot):
        turn(m, "itm_olive", S([(0, 0), (0.04, 0), (0.045, 0.004), (0.045, 0.012), (0.043, 0.014), (0.043, 0.046),
                                (0.045, 0.048), (0.045, 0.054), (0.03, 0.062), (0.021, 0.064)]), seg=16)
        turn(m, "itm_band", S([(0.0434, 0.02), (0.0434, 0.034)]), seg=16)
        thread = [(0.021, 0.064)]
        for k in range(4):  # threaded neck
            y = 0.064 + k * 0.004
            thread += [(0.0195, y + 0.002), (0.021, y + 0.004)]
        turn(m, "itm_steel", S(thread + [(0.015, 0.08), (0.015, 0.074), (0, 0.074)]), seg=12)
        for k in range(8):
            a = 2 * math.pi * k / 8
            m.box("itm_olive", (0.003 * s, 0.03 * s, 0.004 * s), (0.0455 * s * math.cos(a), 0.03 * s, 0.0455 * s * math.sin(a)),
                  (0, -math.degrees(a), 0))  # grip ribs


def m_mask_filter():
    m = B.Model("item_mask_filter")
    m.node("filter")
    filter_can(m)
    return m


def m_gas_mask():
    """Lying face-up; eye lenses and chin filter point +Y, forehead toward -Z, straps splayed on the ground."""
    m = B.Model("item_gas_mask")
    R = "itm_rubber"
    m.node("mask")
    with m.push((0, 0.058, 0.11), (-90, 0, 0)):  # modelled upright facing +Z, then laid down
        m.loft(R, [(0.0, 0.0, 0.0, 0, 0.02), (0.008, 0.045, 0.035, 0, 0.02), (0.04, 0.07, 0.05, 0, 0.02),
                   (0.08, 0.085, 0.055, 0, 0.014), (0.12, 0.09, 0.05, 0, 0.006), (0.17, 0.086, 0.046),
                   (0.2, 0.072, 0.04, 0, -0.002), (0.222, 0.042, 0.03, 0, -0.004), (0.23, 0, 0, 0, -0.004)],
               seg=16, power=2.4)
        for x in (-1, 1):
            with m.push((x * 0.04, 0.148, 0.041), (90, x * 14, 0)):
                turn(m, "itm_steel", [(0.024, -0.004), (0.031, 0.002), (0.031, 0.01), (0.025, 0.013)], seg=14)
                turn(m, "itm_lens", [(0.025, 0.009), (0.02, 0.011), (0, 0.012)], seg=14, smooth=True)
            m.box(R, (0.012, 0.03, 0.01), (x * 0.086, 0.12, -0.02))  # strap lugs
        filter_can(m, (0, 0.045, 0.058), (100, 0, 0), 0.72)
        turn(m, "itm_steel", [(0.028, 0), (0.028, 0.012), (0.03, 0.014)], (0, 0.045, 0.052), (100, 0, 0), 14)  # mount
        for x in (-1, 1):  # exhale valves
            turn(m, "itm_black", [(0.014, 0), (0.014, 0.01), (0.01, 0.014), (0, 0.015)], (x * 0.05, 0.04, 0.035),
                 (90, x * 45, 0), 10)
    # head harness splayed flat on the ground
    Y = 0.003
    for x0, z0, x1, z1 in ((-0.085, -0.02, -0.19, -0.1), (0.085, -0.02, 0.2, -0.08), (-0.08, 0.06, -0.17, 0.12),
                           (0.08, 0.06, 0.18, 0.13), (0, -0.115, 0.02, -0.24)):
        bar(m, "itm_rubber", (x0, Y, z0), (x1, Y, z1), 0.022, 0.003)
        m.box("itm_steel", (0.026, 0.004, 0.012), ((x0 + x1) / 2, Y + 0.002, (z0 + z1) / 2),
              (0, math.degrees(math.atan2(x1 - x0, z1 - z0)), 0))  # buckles
    m.box("itm_rubber", (0.2, 0.004, 0.06), (0, Y, -0.2))  # head pad
    return m


def m_smoke_can():
    """Standing M18-style smoke grenade: olive can, white band, spoon, pull ring."""
    m = B.Model("item_smoke_can")
    m.node("smoke")
    turn(m, "itm_olive", [(0, 0), (0.03, 0), (0.032, 0.003), (0.032, 0.112), (0.029, 0.115), (0.012, 0.117)], seg=14)
    turn(m, "itm_band", [(0.0325, 0.075), (0.0325, 0.1)], seg=14)
    for k in range(4):  # emission holes
        a = math.radians(45 + 90 * k)
        disc(m, "itm_bore", 0.004, (0.02 * math.cos(a), 0.1161, 0.02 * math.sin(a)), (0, 0, 0), 6)
    turn(m, "itm_steel", [(0.012, 0.117), (0.012, 0.13), (0.009, 0.134), (0, 0.135)], seg=10)  # fuse
    # spoon down the side
    bar(m, "itm_steel", (0.006, 0.134, 0), (0.028, 0.128, 0), 0.012, 0.002)
    bar(m, "itm_steel", (0.028, 0.128, 0), (0.0345, 0.11, 0), 0.012, 0.002)
    bar(m, "itm_steel", (0.0345, 0.11, 0), (0.035, 0.04, 0), 0.012, 0.002)
    rod(m, "itm_steel", (-0.012, 0.126, 0.0), (0.012, 0.126, 0.0), 0.0015, 4)  # pin
    torus(m, "itm_steel", 0.012, 0.0015, (-0.024, 0.128, 0), (0, 0, 80), 10, 4)
    return m


def m_key_part():
    """Ornate brass key fragment (bow + half the shank), broken, lying flat along X."""
    m = B.Model("item_key_part")
    Br = "itm_brass"
    m.node("key")
    y = 0.004
    with m.push((-0.02, 0, 0)):
        torus(m, Br, 0.017, 0.0035, (0, y, 0), seg=14, sides=5)
        for a in (90, 180, 270):  # trefoil lobes
            c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
            torus(m, Br, 0.007, 0.0028, (0.024 * c, y, 0.024 * s), seg=10, sides=4)
        m.cyl(Br, 0.004, 0.004, 0.006, (0, y - 0.003, 0), seg=8)  # centre boss
        turn(m, Br, [(0.0055, 0), (0.0055, 0.006), (0.0045, 0.008), (0.0045, 0.012), (0.006, 0.013), (0.006, 0.018),
                     (0.0042, 0.02), (0.0042, 0.06)], (0.018, y, 0), (0, 0, -90), 8)  # collars + shank
        # jagged break
        m.tbox(Br, (0.008, 0.008), (0.003, 0.004), 0.008, (0.078, y, 0), (0, 0, -90), shift=(0.002, 0.001))
        m.tbox("itm_copper", (0.006, 0.006), (0.001, 0.002), 0.005, (0.083, y, 0.001), (0, 0, -80))
    return m


def m_note():
    """Folded sheet lying half open, ink up; image top toward -Z."""
    m = B.Model("item_note")
    m.node("note")
    sheet(m, "itm_note", 0.15, 0.105,
          lambda u, v: 0.012 * (1 - abs(u)) ** 1.6 + 0.006 * abs(u) ** 4 + 0.003 * max(0.0, u * v), 8, 5, crease=True)
    return m


def m_ledger():
    """Thick bound register lying flat, spine to -X."""
    m = B.Model("item_ledger")
    L = "itm_leather"
    m.node("ledger")
    w, h, d = 0.22, 0.05, 0.3
    m.box(L, (w, 0.006, d), (0, 0.003, 0))
    m.box(L, (w, 0.006, d), (0, h - 0.003, 0), (0, 1.5, 0), faces={"+y": "itm_ledger_label"})
    m.box("itm_pages", (w - 0.014, h - 0.012, d - 0.012), (0.004, h / 2, 0), faces={"+y": "itm_paper", "-y": "itm_paper"})
    turn(m, L, [(0.026, -d / 2), (0.026, d / 2)], (-w / 2 + 0.006, h / 2, 0), (90, 0, 0), 10, scale=(0.75, 1, 1))
    for z in (-0.09, -0.03, 0.03, 0.09):  # raised bands
        m.cyl(L, 0.0275, 0.0275, 0.008, (-w / 2 + 0.006, h / 2, z - 0.004), (90, 0, 0), seg=10, caps=False)
    for x, z in ((1, 1), (1, -1)):  # brass corners
        m.tbox("itm_brass", (0.03, 0.03), (0.03, 0.03), 0.0015, (x * (w / 2 - 0.012), h, z * (d / 2 - 0.012)))
        m.tbox("itm_brass", (0.03, 0.03), (0.03, 0.03), 0.0015, (x * (w / 2 - 0.012), -0.0005, z * (d / 2 - 0.012)))
    m.box("itm_red", (0.01, 0.001, 0.07), (0.04, 0.0065, d / 2 + 0.03), (8, 10, 0))  # ribbon
    return m


def m_photo():
    """Small standing frame (kickstand behind), photo faces +Z, leaning back."""
    m = B.Model("item_photo")
    m.node("photo")
    fw, fh, t = 0.11, 0.145, 0.012
    with m.push((0, 0.0, 0.01), (-12, 0, 0)):
        m.box("itm_wood", (fw, fh, 0.006), (0, fh / 2, -0.004))  # back board
        m.decal("itm_photo", fw - 2 * t + 0.002, fh - 2 * t + 0.002, (0, fh / 2, 0.0))
        for x in (-1, 1):
            m.tbox("itm_wood", (t, 0.014), (t, 0.014), fh, (x * (fw - t) / 2, 0, 0.003))
        for y in (t / 2, fh - t / 2):
            m.box("itm_wood", (fw, t, 0.014), (0, y, 0.003))
        m.box("itm_brass", (fw - 0.004, 0.003, 0.003), (0, fh - t - 0.001, 0.009))  # gilt slip
        m.box("itm_brass", (fw - 0.004, 0.003, 0.003), (0, t + 0.001, 0.009))
    bar(m, "itm_wood", (0, 0.1, -0.012), (0, 0.001, -0.06), 0.025, 0.004)  # strut
    return m


def m_drawing():
    """Lily's crayon drawing, curled sheet with a dog-eared corner; image top toward -Z."""
    m = B.Model("item_drawing")
    m.node("drawing")
    sheet(m, "itm_crayon", 0.26, 0.19,
          lambda u, v: 0.01 * abs(v) ** 3 + 0.004 * u * u + (0.012 * (u + v - 1.4) / 0.6 if u + v > 1.4 else 0.0), 8, 6)
    return m


def m_recorder():
    """Portable cassette recorder lying flat: cassette well + reels, speaker, piano keys at +Z edge."""
    m = B.Model("item_recorder")
    P, K = "itm_case", "itm_black"
    m.node("recorder")
    w, h, d = 0.14, 0.045, 0.2
    m.loft(P, [(0, 0, 0), (0.0, w / 2, d / 2), (h - 0.004, w / 2, d / 2), (h, w / 2 - 0.004, d / 2 - 0.004), (h, 0, 0)],
           seg=16, power=6)
    # cassette well with a tape in it
    m.box(K, (0.11, 0.003, 0.072), (0, h + 0.0005, -0.045))
    m.box("itm_cassette", (0.1, 0.006, 0.064), (0, h + 0.003, -0.045), faces={"+y": "itm_cassette"})
    for x in (-0.024, 0.024):
        m.cyl("itm_white", 0.0055, 0.0055, 0.004, (x, h + 0.005, -0.04), seg=8)
        for k in range(3):
            m.box("itm_white", (0.009, 0.002, 0.0015), (x, h + 0.008, -0.04), (0, k * 60, 0))
    for x in (-0.056, 0.056):  # door hinge rails
        m.box("itm_chrome", (0.003, 0.004, 0.074), (x, h + 0.002, -0.045))
    # speaker grille
    m.box("itm_perf", (0.1, 0.002, 0.05), (0, h + 0.001, 0.04))
    # piano keys: play / rew / ff / stop / rec(red)
    for k, mat in enumerate(("itm_white", "itm_white", "itm_white", "itm_white", "itm_red")):
        x = -0.048 + k * 0.024
        down = k == 0
        m.box(mat, (0.02, 0.012, 0.03), (x, h - 0.004 - (0.004 if down else 0), d / 2 - 0.006), (-12, 0, 0))
    # side dials, mic, strap lugs, counter
    m.cyl("itm_grey", 0.012, 0.012, 0.008, (w / 2 - 0.002, 0.025, 0.02), (0, 0, -90), seg=12)
    m.cyl("itm_grey", 0.012, 0.012, 0.008, (w / 2 - 0.002, 0.025, -0.02), (0, 0, -90), seg=12)
    m.cyl("itm_perf", 0.006, 0.006, 0.002, (-0.05, h, 0.078), seg=8)
    for z in (-0.08, 0.08):
        m.box("itm_chrome", (0.01, 0.012, 0.012), (-w / 2 - 0.004, 0.03, z))
    path(m, "itm_leather_lt", [(-w / 2 - 0.006, 0.032, -0.08), (-w / 2 - 0.03, 0.004, -0.06), (-w / 2 - 0.04, 0.003, 0.0),
                               (-w / 2 - 0.03, 0.004, 0.06), (-w / 2 - 0.006, 0.032, 0.08)], 0.004, 5)
    return m


def m_lockpick():
    """Leather roll lying open: picks and a tension wrench tucked in their slots, the rolled end at -X."""
    m = B.Model("item_lockpick")
    m.node("lockpick")
    Lh = "itm_leather_lt"
    m.box(Lh, (0.15, 0.003, 0.1), (0.01, 0.0015, 0))
    turn(m, Lh, [(0.014, -0.05), (0.014, 0.05)], (-0.07, 0.014, 0), (90, 0, 0), 10)
    disc(m, Lh, 0.014, (-0.07, 0.014, 0.05), (90, 0, 0), 10)
    disc(m, Lh, 0.014, (-0.07, 0.014, -0.05), (-90, 0, 0), 10)
    for k in range(5):  # picks along X, handles under the strap, tips toward +X
        z = -0.03 + k * 0.013
        m.box("itm_black", (0.03, 0.002, 0.006), (-0.025, 0.0045, z))
        m.box("itm_steel", (0.1, 0.0012, 0.0035), (0.035, 0.0045, z))
        tip = 0.083
        if k == 0:  # hook
            m.box("itm_steel", (0.002, 0.0012, 0.006), (tip, 0.0045, z + 0.002))
        elif k == 1:  # rake
            for j in range(3):
                m.box("itm_steel", (0.003, 0.0012, 0.006), (tip - 0.003 - j * 0.006, 0.0045, z + 0.002), (0, 30, 0))
        elif k == 2:  # half diamond
            m.box("itm_steel", (0.005, 0.0012, 0.005), (tip, 0.0045, z + 0.001), (0, 45, 0))
        elif k == 3:  # ball
            m.cyl("itm_steel", 0.0028, 0.0028, 0.0012, (tip + 0.002, 0.0039, z), seg=6)
    m.box(Lh, (0.02, 0.002, 0.095), (-0.03, 0.0062, 0))  # strap over the handles
    bar(m, "itm_steel", (-0.03, 0.0045, 0.038), (0.05, 0.0045, 0.038), 0.005, 0.0015)  # tension wrench
    bar(m, "itm_steel", (0.05, 0.0045, 0.038), (0.05, 0.0045, 0.024), 0.005, 0.0015)
    path(m, Lh, [(-0.07, 0.028, 0.0), (-0.04, 0.004, 0.06), (0.02, 0.003, 0.07), (0.07, 0.003, 0.06)], 0.002, 4)  # tie
    return m


# ============================================================== story extras (currently box stand-ins in scenes)

def m_tea_tin():
    """Elena's tea: round caddy with lid, label faces all round. Origin bottom centre."""
    m = B.Model("item_tea_tin")
    m.node("tin")
    turn(m, "itm_tea", [(0.038, 0.003), (0.038, 0.085)], seg=14, rot=(0, 90, 0))
    turn(m, "itm_brass", [(0, 0), (0.036, 0), (0.038, 0.003)], seg=14)
    turn(m, "itm_brass", [(0.0385, 0.08), (0.04, 0.082), (0.04, 0.1), (0.036, 0.104), (0.012, 0.106), (0.012, 0.11),
                          (0, 0.11)], seg=14)
    return m


def m_tin_box():
    """Old rusted biscuit tin with hinged lid (Elena's stash, Tom's photo tin). 0.2 x 0.08 x 0.14."""
    m = B.Model("item_tin_box")
    m.node("tin")
    m.box("itm_tin", (0.2, 0.066, 0.14), (0, 0.033, 0))
    m.box("itm_tin", (0.204, 0.02, 0.144), (0, 0.074, 0))
    m.tbox("itm_tin", (0.204, 0.144), (0.19, 0.13), 0.004, (0, 0.084, 0))
    for x in (-0.06, 0.06):
        m.cyl("itm_steel", 0.003, 0.003, 0.02, (x, 0.068, -0.072), (0, 0, 90), seg=5)  # hinges
    m.box("itm_steel", (0.03, 0.012, 0.004), (0, 0.066, 0.073))  # clasp
    m.cyl("itm_wax", 0.012, 0.011, 0.003, (0.05, 0.084, 0.02), seg=9)  # wax seal
    return m


def m_file():
    """Manila folder lying flat (0.24 x 0.32), papers peeking out, clip and stamp. Tab at -Z."""
    m = B.Model("item_file")
    m.node("file")
    m.box("itm_file", (0.24, 0.002, 0.32), (0, 0.001, 0), faces={"+y": "itm_file"})
    m.box("itm_paper", (0.22, 0.004, 0.3), (0.006, 0.004, 0.004), (0, 2, 0))
    m.box("itm_note", (0.21, 0.001, 0.29), (-0.004, 0.0065, -0.004), (0, -3, 0), faces={"+y": "itm_note"})
    with m.push((-0.012, 0.007, 0.008), (0, 4, 0)):  # cover skewed: the papers peek out
        m.box("itm_file", (0.24, 0.002, 0.32), (0, 0.001, 0), faces={"+y": "itm_file"})
    m.box("itm_file", (0.07, 0.002, 0.018), (-0.05, 0.004, -0.168))  # tab
    m.box("itm_chrome", (0.008, 0.012, 0.035), (0.08, 0.005, -0.15))  # paper clip
    return m


def m_syringe():
    """Julian's syringe: origin at barrel centre, needle toward -Y, plunger +Y (0.16 overall)."""
    m = B.Model("item_syringe")
    m.node("syringe")
    turn(m, "itm_clear", [(0.0035, -0.048), (0.0035, -0.042), (0.008, -0.038)], seg=12)
    turn(m, "itm_serum", [(0.008, -0.038), (0.008, 0.016)], seg=12)  # the green dose, lit
    turn(m, "itm_clear", [(0.008, 0.016), (0.008, 0.04)], seg=12)
    for k in range(6):
        m.cyl("itm_bore", 0.0082, 0.0082, 0.0008, (0, -0.03 + k * 0.012, 0), seg=10, caps=False)  # graduations
    m.box("itm_clear", (0.03, 0.003, 0.012), (0, 0.041, 0))  # finger flange
    m.cyl("itm_rubber", 0.007, 0.007, 0.004, (0, 0.02, 0), seg=10)
    m.cyl("itm_clear", 0.002, 0.002, 0.05, (0, 0.02, 0), seg=5)
    m.cyl("itm_clear", 0.009, 0.009, 0.003, (0, 0.07, 0), seg=10)
    turn(m, "itm_steel", [(0.0006, -0.08), (0.0006, -0.048), (0.002, -0.048), (0, -0.047)], seg=5)
    return m


def m_map():
    """Elena's folded map lying half open: accordion panels; image top toward -Z."""
    m = B.Model("item_map")
    m.node("map")
    sheet(m, "itm_map", 0.3, 0.22, lambda u, v: 0.004 + 0.006 * abs(math.sin((u + 1) * math.pi)) + 0.004 * max(0.0, -v),
          8, 4, crease=True)
    return m


def key_bow_eye(m, mat, pos):
    torus(m, mat, 0.022, 0.005, pos, seg=14, sides=5, scale=(1.3, 1, 0.9))
    torus(m, mat, 0.008, 0.003, B.v_add(pos, (0, 0.001, 0)), seg=10, sides=4)
    m.cyl(mat, 0.004, 0.004, 0.006, B.v_add(pos, (0, -0.002, 0)), seg=8)


def m_chapel_key():
    """Heavy iron key lying flat along Z, eye cast in the bow at +Z, bit at -Z. 0.22 long."""
    m = B.Model("item_chapel_key")
    I = "itm_rust_iron"
    m.node("key")
    y = 0.006
    key_bow_eye(m, I, (0, y, 0.075))
    turn(m, I, [(0.007, 0.0), (0.007, 0.01), (0.0055, 0.012), (0.0055, 0.16), (0.007, 0.162), (0.007, 0.17),
                (0, 0.17)], (0, y, 0.05), (-90, 0, 0), 8)
    m.box(I, (0.03, 0.007, 0.03), (0.018, 0.0035, -0.098))  # bit with wards, lying flat
    for x, z in ((0.022, -0.106), (0.012, -0.092), (0.028, -0.09)):
        m.box("itm_bore", (0.004, 0.0072, 0.006), (x, 0.0036, z))
    return m


def m_keyring():
    """Shepherd's ring of old keys lying flat."""
    m = B.Model("item_keyring")
    m.node("keys")
    torus(m, "itm_steel", 0.024, 0.0018, (0, 0.002, 0), seg=14, sides=4)
    for k, (yaw, L, mat) in enumerate(((10, 0.07, "itm_brass"), (60, 0.055, "itm_rust_iron"), (-40, 0.065, "itm_steel"),
                                       (-100, 0.05, "itm_brass"))):
        with m.push((0, 0.003 + 0.0015 * k, 0), (0, yaw, 0)):
            torus(m, mat, 0.009, 0.0025, (0, 0, 0.03), seg=10, sides=4)
            m.box(mat, (0.006, 0.003, L), (0, 0, 0.039 + L / 2))
            m.box(mat, (0.004, 0.003, 0.012), (0.005, 0, 0.034 + L))
            m.box(mat, (0.003, 0.003, 0.006), (0.0045, 0, 0.026 + L))
    return m


def m_brand_iron():
    """Branding iron: origin at shaft centre, 0.7 along Z, glowing eye brand at z=-0.38 (node "Brand"), handle +Z."""
    m = B.Model("item_brand_iron")
    m.node("iron")
    rod(m, "itm_rust_iron", (0, 0, -0.36), (0, 0, 0.22), 0.007, 6)
    turn(m, "itm_wood", [(0.012, 0.0), (0.016, 0.02), (0.016, 0.12), (0.013, 0.13), (0, 0.13)], (0, 0, 0.21), (90, 0, 0), 8)
    torus(m, "itm_rust_iron", 0.012, 0.004, (0, 0, 0.345), (90, 0, 0), 8, 4)  # hanging ring
    m.node("Brand", "iron", (0, 0, -0.38))
    rod(m, "itm_rust_iron", (0, 0, 0.022), (0, 0, -0.005), 0.009, 6)
    for s in (-1, 1):  # almond eye outline
        pts = [(x, 0, s * 0.045 * math.cos(x / 0.07 * math.pi / 2)) for x in (-0.07, -0.035, 0, 0.035, 0.07)]
        for a, b in zip(pts, pts[1:]):
            bar(m, "itm_hot", a, b, 0.008, 0.012)
    m.cyl("itm_hot", 0.016, 0.016, 0.012, (0, -0.006, 0), seg=10)
    return m


def m_supply_box():
    """Grady's red metal flare kit (0.3 x 0.12 x 0.2): latches, handle, white label. Origin bottom centre."""
    m = B.Model("item_supply_box")
    m.node("box")
    m.box("itm_red", (0.3, 0.085, 0.2), (0, 0.0425, 0))
    m.box("itm_red", (0.305, 0.035, 0.205), (0, 0.1025, 0))
    m.box("itm_black", (0.306, 0.004, 0.206), (0, 0.086, 0))
    m.box("itm_white", (0.12, 0.05, 0.002), (0, 0.045, 0.101), faces={"+z": "itm_band"})
    for x in (-0.1, 0.1):
        m.box("itm_steel", (0.025, 0.03, 0.008), (x, 0.085, 0.104))  # latches
        m.box("itm_steel", (0.012, 0.012, 0.02), (x, 0.126, 0))  # handle posts
    rod(m, "itm_black", (-0.1, 0.135, 0), (0.1, 0.135, 0), 0.009, 8)
    return m


def m_toe_tag():
    """Morgue toe tag with its string, lying flat."""
    m = B.Model("item_toe_tag")
    m.node("tag")
    m.box("itm_tag", (0.1, 0.0015, 0.055), (0, 0.001, 0), (0, 12, 0), faces={"+y": "itm_tag"})
    path(m, "itm_white", [(-0.045, 0.002, -0.008), (-0.07, 0.002, 0.01), (-0.1, 0.002, -0.01), (-0.12, 0.002, 0.03),
                          (-0.09, 0.002, 0.05)], 0.001, 3)
    return m


def m_fishing_rod():
    """Old Tom's rod: origin at the middle of its 2.4 m, tip -Z, butt +Z, reel hanging below (-Y) near the butt."""
    m = B.Model("item_fishing_rod")
    m.node("rod")
    turn(m, "itm_black", [(0.012, 0), (0.009, 0.9), (0.006, 1.6), (0.003, 2.3), (0.002, 2.4)], (0, 0, 1.2), (-90, 0, 0), 6,
         smooth=True)
    turn(m, "itm_cork", [(0.015, 0.01), (0.017, 0.03), (0.017, 0.3), (0.013, 0.32)], (0, 0, 1.2), (-90, 0, 0), 8)
    turn(m, "itm_steel", [(0.013, 0.0), (0.013, 0.012), (0, 0.012)], (0, 0, 1.2), (-90, 0, 0), 8)
    for k, z in enumerate((0.75, 0.4, 0.05, -0.3, -0.6, -0.9, -1.15)):  # line guides
        r = 0.018 - k * 0.0016
        torus(m, "itm_chrome", r, 0.0012, (0, 0.01 + r, -z), (90, 0, 0), 8, 3)
    # spinning reel below the handle
    rod(m, "itm_steel", (0, -0.012, 0.95), (0, -0.05, 0.95), 0.004, 5)
    turn(m, "itm_grey", [(0.026, 0), (0.03, 0.005), (0.03, 0.035), (0.02, 0.045), (0, 0.045)], (0, -0.075, 0.97), (-90, 0, 0), 12)
    turn(m, "itm_bore", [(0.0305, 0.008), (0.0305, 0.03)], (0, -0.075, 0.97), (-90, 0, 0), 12)  # spooled line
    rod(m, "itm_grey", (0.03, -0.075, 0.955), (0.05, -0.075, 0.955), 0.003, 4)
    rod(m, "itm_black", (0.05, -0.075, 0.955), (0.05, -0.1, 0.955), 0.004, 5)  # crank knob
    path(m, "itm_white", [(0, -0.05, 0.93), (0, 0.02, 0.4), (0, 0.012, -1.2), (0, -0.4, -1.3)], 0.0007, 3)
    return m


def m_bucket():
    """Galvanised bait bucket, hollow with dark water, wire bail. Origin bottom centre, r 0.14 -> 0.17, h 0.32."""
    m = B.Model("item_bucket")
    m.node("bucket")
    turn(m, "itm_galv", [(0, 0), (0.14, 0), (0.142, 0.01), (0.15, 0.11), (0.153, 0.115), (0.16, 0.22), (0.163, 0.225),
                         (0.17, 0.315), (0.174, 0.32), (0.166, 0.32), (0.16, 0.31), (0.135, 0.02), (0, 0.02)], seg=16)
    disc(m, "water", 0.155, (0, 0.2, 0), seg=16)
    for s in (-1, 1):
        m.cyl("itm_galv", 0.015, 0.015, 0.006, (s * 0.17, 0.27, 0), (0, 0, -90 * s), seg=8)
    pts = [(0.17 * math.cos(a), 0.27 + 0.2 * math.sin(a), 0.0) for a in (math.radians(d) for d in range(0, 181, 20))]
    with m.push((0, 0.27, 0), (-60, 0, 0)):  # bail flopped to one side
        path(m, "itm_steel", [(x, y - 0.27, z) for x, y, z in pts], 0.0025, 4)
    return m


# ============================================================== melee / bow / long gun
# Same convention as the guns: origin = where the right hand grips, business end toward -Z, +Y up.
# The player's arms reach these grips with IK (scripts/humanoid_anim.gd), so the points below matter.

def m_axe():
    """Fire axe: right hand at the origin (above the butt knob), left hand at z -0.42, head at z -0.74:
    blade edge +Y, pick -Y."""
    m = B.Model("item_axe")
    m.node("axe")
    turn(m, "itm_wood", [(0.019, -0.07), (0.021, -0.06), (0.016, -0.04), (0.015, 0.25), (0.017, 0.6), (0.019, 0.8),
                         (0.012, 0.81)], (0, 0, 0), (-90, 0, 0), 8, smooth=True)
    turn(m, "itm_rubber", [(0.019, -0.045), (0.02, -0.04), (0.02, 0.11), (0.018, 0.115)], (0, 0, 0), (-90, 0, 0), 8)
    with m.push((0, 0, -0.74)):
        m.box("itm_red", (0.034, 0.075, 0.075), (0, 0, 0))  # eye / cheeks
        m.tbox("itm_red", (0.03, 0.075), (0.008, 0.19), 0.12, (0, 0.035, 0))  # blade flares toward the edge
        m.box("itm_steel", (0.01, 0.014, 0.19), (0, 0.16, 0))  # ground edge
        m.tbox("itm_red", (0.03, 0.06), (0.006, 0.012), 0.12, (0, -0.035, 0), (180, 0, 0))  # pick
        m.box("itm_steel", (0.007, 0.012, 0.012), (0, -0.155, 0))
        m.box("itm_white", (0.036, 0.02, 0.05), (0, 0.0, 0))  # stencil band
    return m


def m_bat():
    """Baseball bat wrapped in tape with nails through the barrel: right hand at the origin (above the knob),
    left hand at z -0.1, barrel toward -Z (tip z -0.86)."""
    m = B.Model("item_bat")
    m.node("bat")
    turn(m, "itm_wood", [(0.0, -0.04), (0.022, -0.04), (0.022, -0.028), (0.014, -0.02), (0.013, 0.2), (0.022, 0.45),
                         (0.032, 0.65), (0.034, 0.8), (0.03, 0.855), (0.0, 0.86)], (0, 0, 0), (-90, 0, 0), 10, smooth=True)
    turn(m, "itm_black", [(0.015, -0.018), (0.0155, -0.015), (0.0155, 0.16), (0.015, 0.165)], (0, 0, 0), (-90, 0, 0), 8)
    for k in range(7):  # nails through the barrel, heads proud on one side, points out the other
        z = -0.58 - 0.04 * k
        a = math.radians(k * 67)
        d = (0.07 * math.cos(a), 0.07 * math.sin(a), 0)
        rod(m, "itm_steel", (-d[0] * 0.4, -d[1] * 0.4, z), (d[0], d[1], z), 0.0018, 4)
        m.cyl("itm_steel", 0.005, 0.005, 0.002, (-d[0] * 0.43, -d[1] * 0.43, z), (0, 0, math.degrees(a) + 90), seg=6)
    return m


def m_bow():
    """Hunting recurve bow: origin = the left hand's grip, arrow shoots toward -Z, limbs along +-Y, the braced
    string lies in the plane x = 0 at z = +0.16 (limb tips at (0, +-0.62, 0.1)). The string itself is drawn by
    the game (it moves when drawn)."""
    m = B.Model("item_bow")
    m.node("bow")
    m.loft("itm_leather", [(-0.07, 0.016, 0.02), (-0.06, 0.018, 0.024), (0.06, 0.018, 0.024), (0.07, 0.016, 0.02)],
           seg=8, power=2.5)
    m.box("itm_wood", (0.012, 0.03, 0.02), (0.018, 0.08, -0.005))  # arrow shelf
    for s in (1, -1):
        pts = []
        for k in range(9):
            t = k / 8
            y = 0.07 + 0.55 * t
            z = -0.02 - 0.09 * math.sin(t * math.pi * 0.8) + 0.2 * max(t - 0.75, 0) ** 1.5 * 4
            pts.append((0, s * y, z))
        for (a, b), k in zip(zip(pts, pts[1:]), range(8)):
            w = 0.034 - 0.02 * k / 8
            bar(m, "itm_wood", a, b, w, 0.012)
        m.cyl("itm_bakelite", 0.006, 0.006, 0.02, (0.01, s * 0.62, 0.1), (0, 0, 90), seg=6)  # string nocks
    return m


def m_arrow():
    """Hunting arrow: origin at the nock, shaft toward -Z, broadhead tip at z -0.74."""
    m = B.Model("item_arrow")
    m.node("arrow")
    rod(m, "itm_wood", (0, 0, 0), (0, 0, -0.7), 0.0045, 5)
    m.cyl("itm_orange", 0.0055, 0.0055, 0.012, (0, 0, 0.005), (90, 0, 0), seg=5)  # nock
    with m.push((0, 0, -0.7)):
        m.tbox("itm_steel", (0.026, 0.004), (0.0, 0.001), 0.045, (0, 0, 0), (-90, 0, 0))
        m.tbox("itm_steel", (0.004, 0.026), (0.001, 0.0), 0.045, (0, 0, 0), (-90, 0, 0))
    for k in range(3):  # fletching
        a = math.radians(90 + 120 * k)
        c, s = math.cos(a), math.sin(a)
        with m.push((0, 0, -0.06), (0, 0, math.degrees(a))):
            m.tbox("itm_red" if k else "itm_white", (0.002, 0.07), (0.002, 0.03), 0.014, (0, 0.004, 0), shift=(0, 0.015))
    return m


def m_shotgun():
    """Double-barrel shotgun: origin = right hand on the wrist of the stock, barrels toward -Z (muzzles at
    (0, 0.045, -0.74)), left hand on the fore-end at (0, 0.02, -0.33), butt plate at z +0.34 (the shoulder)."""
    m = B.Model("item_shotgun")
    m.node("shotgun")
    G = "itm_blued"
    # stock: wrist in the hand, drops to the butt
    m.loft("itm_veneer", [(-0.02, 0.014, 0.018), (0.08, 0.016, 0.022, 0, 0.012), (0.2, 0.021, 0.05, 0, 0.035),
                          (0.33, 0.022, 0.062, 0, 0.045), (0.34, 0.021, 0.06, 0, 0.045)], (0, 0.012, 0), (90, 0, 0),
           seg=10, power=2.6)
    m.box("itm_black", (0.042, 0.12, 0.012), (0, -0.033, 0.346))  # recoil pad
    m.box(G, (0.04, 0.05, 0.1), (0, 0.035, -0.07))  # receiver
    m.box(G, (0.012, 0.018, 0.012), (0, 0.068, -0.02), (30, 0, 0))  # top lever
    for x in (-0.006, 0.006):  # twin hammers
        m.box(G, (0.006, 0.02, 0.012), (x, 0.066, -0.02), (-20, 0, 0))
    path(m, G, [(0, 0.012, -0.03), (0, -0.012, -0.045), (0, -0.012, -0.1), (0, 0.01, -0.115)], 0.003, 4)  # guard
    m.box(G, (0.006, 0.02, 0.006), (0, 0.0, -0.075))  # triggers
    for x in (-0.0105, 0.0105):
        turn(m, G, [(0.011, 0.0), (0.0105, 0.6), (0.0, 0.6)], (x, 0.045, -0.12), (-90, 0, 0), 10)
        disc(m, "itm_bore", 0.008, (x, 0.045, -0.721), (-90, 0, 0), 8)
    m.box(G, (0.006, 0.004, 0.6), (0, 0.058, -0.42))  # rib
    m.cyl("itm_brass", 0.002, 0.002, 0.004, (0, 0.06, -0.715), seg=5)  # bead sight
    m.loft("itm_veneer", [(-0.4, 0.02, 0.016), (-0.39, 0.024, 0.024), (-0.2, 0.024, 0.024), (-0.19, 0.02, 0.016)],
           (0, 0.02, -0.07), (90, 0, 0), seg=8, power=2.4)  # fore-end under the barrels
    return m


def m_shells():
    """Box of 12-gauge shells, flap open, three loose red hulls beside it. Origin bottom centre."""
    m = B.Model("item_shells")
    m.node("shells")
    m.box("itm_cardboard", (0.11, 0.06, 0.07), (0, 0.03, 0))
    m.box("itm_red", (0.112, 0.02, 0.072), (0, 0.035, 0))  # printed band
    with m.push((0, 0.06, -0.035), (-110, 0, 0)):
        m.box("itm_cardboard", (0.11, 0.003, 0.07), (0, 0, 0.035))
    for k in range(4):  # brass heads showing in the box
        disc(m, "itm_brass", 0.009, (-0.04 + 0.027 * k, 0.061, 0.0), (0, 0, 0), 8)
    for k, (x, z, yaw) in enumerate(((0.09, 0.02, 20), (0.1, -0.03, -35), (0.07, 0.06, 80))):
        with m.push((x, 0.011, z), (0, yaw, 0)):
            turn(m, "itm_red", [(0.011, 0.0), (0.011, 0.055), (0.0, 0.055)], (0, 0, 0.0), (90, 0, 0), 8)
            turn(m, "itm_brass", [(0.0115, -0.012), (0.0115, 0.0), (0.0, 0.0)], (0, 0, 0.0), (90, 0, 0), 8)
    return m


def m_room_key():
    """Motel room key on a big plastic tag with the room number: origin at the tag's centre, lying flat, the key
    toward -Z."""
    m = B.Model("item_room_key")
    m.node("key")
    m.box("itm_red", (0.045, 0.008, 0.075), (0, 0.004, 0.02))
    m.box("itm_white", (0.03, 0.009, 0.04), (0, 0.004, 0.025))  # the painted "6" plate
    m.box("itm_black", (0.004, 0.0095, 0.024), (0.004, 0.004, 0.025))
    torus(m, "itm_brass", 0.009, 0.0015, (0, 0.004, -0.024), (0, 0, 0), 8, 4)
    m.box("itm_brass", (0.014, 0.003, 0.012), (0, 0.004, -0.038))  # bow
    m.box("itm_brass", (0.004, 0.003, 0.04), (0, 0.004, -0.062))  # shank
    for k in range(3):
        m.box("itm_brass", (0.008, 0.003, 0.004), (0.004, 0.004, -0.07 + k * 0.009))  # bitting
    return m


def m_handmic():
    """Radio hand microphone on its coiled cord: origin at the grip centre, grille facing +Y, top toward -Z."""
    m = B.Model("item_handmic")
    m.node("mic")
    m.loft("itm_black", [(-0.045, 0.012, 0.022), (-0.04, 0.02, 0.028), (0.04, 0.02, 0.028), (0.05, 0.012, 0.02)],
           (0, 0, 0), (90, 0, 0), seg=8, power=3)
    m.box("itm_steel", (0.03, 0.004, 0.045), (0, 0.022, -0.015))  # grille
    for k in range(4):
        m.box("itm_black", (0.03, 0.005, 0.003), (0, 0.024, -0.03 + k * 0.01))
    m.box("itm_grey", (0.01, 0.01, 0.03), (0.022, 0.0, 0.0))  # push-to-talk
    pts = [(0.0, 0.0, 0.05)] + [(0.012 * math.cos(k * 1.3), 0.012 * math.sin(k * 1.3), 0.06 + k * 0.012) for k in range(12)]
    path(m, "itm_black", pts, 0.0025, 3)
    return m


# ============================================================== worn

# Alex's head (char_alex, Head joint space, origin at the top of the neck, face +Z). The band is fitted to his real
# head and hair (models_chars_a m_alex, its Head node), not to a guess at their size: they're sliced along the band's
# plane, tilted like a worn strap (low over the forehead, higher round the back of the skull), and the band runs
# round that outline, touching it, over the hair's blades. The lamp unit sits on its front, on the forehead.
HEADLAMP_Y = 0.215  # band centre height over the Head pivot, at the pivot's own z (above the brows, under the crown)
HEADLAMP_TILT = 10.0  # degrees: the band's plane drops toward the front
HEADLAMP_H, HEADLAMP_T = 0.024, 0.006  # band height and thickness
HEADLAMP_N = 28  # segments round the head


def _head_tris():
    """Alex's head and hair triangles, Head joint space (cached: the band and the lens both read them)."""
    if not hasattr(_head_tris, "cache"):
        import models_chars_a
        alex = models_chars_a.m_alex()
        nd = next(n for n in alex.nodes if n["name"] == "Head")
        tris = []
        for pos, _, _ in nd["prims"].values():
            tris += [tuple(pos[k:k + 3]) for k in range(0, len(pos) - 2, 3)]
        _head_tris.cache = tris
    return _head_tris.cache


def _band_frame():
    """The band's plane: origin, x (to Alex's left), f (forward and a touch down), n (its normal, up and back)."""
    t = math.radians(HEADLAMP_TILT)
    f = (0.0, -math.sin(t), math.cos(t))
    n = (0.0, math.cos(t), math.sin(t))
    return (0.0, HEADLAMP_Y, 0.0), (1.0, 0.0, 0.0), f, n


def _band_outline():
    """[(x, f)] in the band's plane: per direction round the head, how far out the head and hair reach over the
    band's height (three slices: its top, middle and bottom edge), from the outline's own centre."""
    o, ex, ef, en = _band_frame()
    dot = lambda a, b: a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
    sub = lambda a, b: (a[0] - b[0], a[1] - b[1], a[2] - b[2])
    segs = []
    for off in (-HEADLAMP_H / 2, 0.0, HEADLAMP_H / 2):
        for tri in _head_tris():
            d = [dot(sub(p, o), en) - off for p in tri]
            pts = []
            for k in range(3):
                a, b, da, db = tri[k], tri[(k + 1) % 3], d[k], d[(k + 1) % 3]
                if (da < 0) != (db < 0):
                    q = da / (da - db)
                    x = tuple(a[c] + (b[c] - a[c]) * q for c in range(3))
                    pts.append((dot(sub(x, o), ex), dot(sub(x, o), ef)))
            if len(pts) == 2:
                segs.append(pts)
    us = [p[0] for s_ in segs for p in s_]
    vs = [p[1] for s_ in segs for p in s_]
    cu, cv = (min(us) + max(us)) / 2, (min(vs) + max(vs)) / 2
    radii = []
    for k in range(HEADLAMP_N):
        a = 2 * math.pi * k / HEADLAMP_N
        du, dv = math.sin(a), math.cos(a)
        best = 0.0
        for (u0, v0), (u1, v1) in segs:  # the ray from the centre against every slice segment: the farthest hit
            ex_, ev = u1 - u0, v1 - v0
            den = du * ev - dv * ex_
            if abs(den) < 1e-12:
                continue
            wu, wv = u0 - cu, v0 - cv
            t_ = (wu * ev - wv * ex_) / den
            s2 = (wu * dv - wv * du) / den
            if t_ > 0 and 0.0 <= s2 <= 1.0:
                best = max(best, t_)
        radii.append(best)
    # the hair's blade tips make a ragged outline: the elastic presses them in a little (never more than 4 mm) and
    # runs smooth round them instead of kinking at each
    smooth = [max((radii[k - 1] + 2 * radii[k] + radii[(k + 1) % HEADLAMP_N]) / 4, radii[k] - 0.004)
              for k in range(HEADLAMP_N)]
    out = []
    for k, r in enumerate(smooth):
        a = 2 * math.pi * k / HEADLAMP_N
        r += HEADLAMP_T / 2 + 0.001  # its inside face on the hair, not in it
        out.append((cu + r * math.sin(a), cv + r * math.cos(a)))
    return out


def _band_point(u, v, up=0.0):
    """Head space point at (u, v) in the band's plane, `up` along its normal."""
    o, ex, ef, en = _band_frame()
    return tuple(o[c] + ex[c] * u + ef[c] * v + en[c] * up for c in range(3))


def headlamp_lens():
    """Centre of the lens face, Head space (scripts/headlamp.gd LENS must match: the beam starts there)."""
    pts = _band_outline()
    front = pts[0]
    o, ex, ef, en = _band_frame()
    at = _band_point(front[0], front[1] + HEADLAMP_T / 2 + 0.023)
    t = math.radians(6.0)  # the housing's own tilt down on its hinge, in the head's frame
    return (at[0], at[1] - 0.001 * math.cos(t) - 0.019 * math.sin(t), at[2] + 0.019 * math.cos(t) - 0.001 * math.sin(t))


def m_headlamp():
    """Work / camping headlamp worn on Alex's head (Head joint space, see above): a flat elastic band fitted round his
    head and hair, a small boxy lamp unit on the forehead with a tilt hinge and a top button, the lens in its own
    node ("lens") so the game can light it while the lamp is on. No markings."""
    m = B.Model("item_headlamp")
    m.node("headlamp")
    h, t = HEADLAMP_H, HEADLAMP_T
    o, ex, ef, en = _band_frame()
    pts = _band_outline()
    tilt = HEADLAMP_TILT
    for k in range(len(pts)):  # one flat panel per segment, standing square to the band's plane
        (u0, v0), (u1, v1) = pts[k], pts[(k + 1) % len(pts)]
        seg = math.hypot(u1 - u0, v1 - v0)
        yaw = math.degrees(math.atan2(u1 - u0, v1 - v0)) - 90
        with m.push(_band_point((u0 + u1) / 2, (v0 + v1) / 2), (tilt, 0, 0)):
            m.box("itm_strap", (seg + 0.004, h, t), (0, 0, 0), (0, yaw, 0))
    # lamp unit on the forehead: bracket on the band, the housing tilted a touch down on its hinge, a top button
    fu, fv = pts[0]
    zf = fv + t / 2
    with m.push(_band_point(fu, 0.0), (tilt, 0, 0)):
        m.box("itm_case", (0.05, 0.03, 0.008), (0, 0, zf + 0.004))
        m.cyl("itm_grey", 0.007, 0.007, 0.064, (-0.032, -0.004, zf + 0.01), (0, 0, -90), seg=6)  # hinge pin
    with m.push(_band_point(fu, zf + 0.023), (6, 0, 0)):
        m.box("itm_case", (0.068, 0.04, 0.03), (0, 0, 0))
        m.box("itm_grey", (0.072, 0.008, 0.032), (0, 0.016, 0))  # rim
        m.box("itm_orange_dk", (0.016, 0.006, 0.012), (0, 0.023, -0.002))  # switch
        m.box("itm_grey", (0.06, 0.032, 0.004), (0, -0.001, 0.016))  # bezel
    m.node("lens")
    with m.push(_band_point(fu, zf + 0.023), (6, 0, 0)):
        m.box("itm_lamp_lens", (0.046, 0.022, 0.004), (0, -0.001, 0.019))
    return m


# ============================================================== registry

MODELS = [m_revolver, m_flare_gun, m_bottle, m_car_battery, m_ammo_box, m_bandage, m_flares, m_mask_filter,
          m_gas_mask, m_smoke_can, m_key_part, m_note, m_ledger, m_photo, m_drawing, m_recorder, m_lockpick,
          m_tea_tin, m_tin_box, m_file, m_syringe, m_map, m_chapel_key, m_keyring, m_brand_iron, m_supply_box,
          m_toe_tag, m_fishing_rod, m_bucket, m_axe, m_bat, m_bow, m_arrow, m_shotgun, m_shells, m_room_key, m_handmic,
          m_headlamp]
